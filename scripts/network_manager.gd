extends Node

## Owns the ENet transport. World-specific spawning and simulation live in scenes.
signal connection_status_changed(message: String)
signal session_state_changed(state: String)
signal client_connected
signal client_connection_failed(message: String)
signal server_started
signal ping_updated(milliseconds: int)
signal raid_join_requested(peer_id: int)
signal load_raid_requested
signal raid_client_loaded(peer_id: int)
signal raid_extraction_requested(peer_id: int, extraction_name: String)
signal return_to_lobby_requested

const DEFAULT_PORT := 7000
const DEFAULT_SERVER_ADDRESS := "158.180.84.54"
const MAX_CLIENTS := 32
const PING_INTERVAL_SECONDS := 1.0

enum RaidLifecycle { LOBBY, LOADING, IN_RAID }
enum PeerRaidState { MULTIPLAYER_LOBBY, LOADING_RAID, IN_RAID, RETURNING_TO_LOBBY }

var is_server_mode := false
var is_connecting := false
var ping_ms := -1
var _ping_elapsed := 0.0
var connected_peer_ids: Dictionary = {}
var raid_members: Dictionary = {}
var peer_raid_states: Dictionary = {}
var _raid_loading_peers: Dictionary = {}
var raid_lifecycle := RaidLifecycle.LOBBY


func _ready() -> void:
	# get_cmdline_user_args() is the documented form (-- --server). Reading the
	# remaining engine arguments too makes exported Linux service commands robust.
	var launch_args := PackedStringArray()
	launch_args.append_array(OS.get_cmdline_user_args())
	launch_args.append_array(OS.get_cmdline_args())
	is_server_mode = "--server" in launch_args

	if is_server_mode:
		print("[SERVER] boot build=free-aim-rpc-v3 args=%s" % str(launch_args))

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	if is_server_mode:
		call_deferred("start_server")


func _process(delta: float) -> void:
	if is_server_mode or not is_connected_to_server():
		return
	_ping_elapsed += delta
	if _ping_elapsed < PING_INTERVAL_SECONDS:
		return
	_ping_elapsed = 0.0
	_ping_server.rpc_id(1, Time.get_ticks_msec())


func start_server(port: int = DEFAULT_PORT, max_clients: int = MAX_CLIENTS) -> Error:
	if not is_server_mode:
		push_warning("start_server() is reserved for --server mode.")
		return ERR_UNAUTHORIZED

	_stop_current_peer()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, max_clients)
	if error != OK:
		var failure := "Server start failed (port %d): %s" % [port, error_string(error)]
		print(failure)
		connection_status_changed.emit(failure)
		return error

	multiplayer.multiplayer_peer = peer
	var message := "Dedicated server listening on UDP port %d" % port
	print("[SERVER] multiplayer peer created")
	print("[SERVER] listening udp=%d" % port)
	print("[STATE] server raid_lifecycle=LOBBY")
	connection_status_changed.emit(message)
	session_state_changed.emit("SERVER")
	server_started.emit()
	return OK


func connect_to_default_server() -> Error:
	return connect_to_server(DEFAULT_SERVER_ADDRESS)


func connect_to_server(address: String = DEFAULT_SERVER_ADDRESS, port: int = DEFAULT_PORT) -> Error:
	if is_server_mode:
		return ERR_UNAUTHORIZED

	var host := address.strip_edges()
	if host.is_empty():
		return _report_connect_setup_failure("Server IP address is required.", ERR_INVALID_PARAMETER)

	_stop_current_peer()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(host, port)
	if error != OK:
		return _report_connect_setup_failure("Connection setup failed: %s" % error_string(error), error)

	multiplayer.multiplayer_peer = peer
	is_connecting = true
	var message := "Connecting to %s:%d..." % [host, port]
	print(message)
	connection_status_changed.emit(message)
	session_state_changed.emit("CONNECTING")
	return OK


func is_connected_to_server() -> bool:
	return not is_server_mode and multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_network_game() -> bool:
	return is_server_mode or is_connected_to_server()


func request_raid_start() -> void:
	if is_connected_to_server():
		print("[RAID] Start requested by peer=%d" % multiplayer.get_unique_id())
		_request_raid_start.rpc_id(1)


func server_begin_raid_join(peer_id: int) -> void:
	if not multiplayer.is_server() or not connected_peer_ids.has(peer_id):
		return
	var peer_state := int(peer_raid_states.get(peer_id, PeerRaidState.MULTIPLAYER_LOBBY))
	if peer_state != PeerRaidState.MULTIPLAYER_LOBBY:
		print("[RAID] ignored join peer=%d state=%d" % [peer_id, peer_state])
		return
	print("[RAID] join requested peer=%d" % peer_id)
	print("[RAID] members before=%s" % str(raid_members.keys()))
	raid_members[peer_id] = true
	peer_raid_states[peer_id] = PeerRaidState.LOADING_RAID
	_raid_loading_peers[peer_id] = true
	if raid_lifecycle == RaidLifecycle.LOBBY:
		raid_lifecycle = RaidLifecycle.LOADING
		print("[STATE] server raid_lifecycle=LOADING")
	print("[RAID] members after=%s" % str(raid_members.keys()))
	print("[RAID] sending load request peer=%d" % peer_id)
	_load_raid_on_clients.rpc_id(peer_id)


func client_raid_scene_ready() -> void:
	if is_connected_to_server():
		print("[RAID] Client loaded scene peer=%d" % multiplayer.get_unique_id())
		_client_raid_loaded.rpc_id(1)


func request_raid_extraction(extraction_name: String) -> void:
	if is_connected_to_server():
		_request_raid_extraction.rpc_id(1, extraction_name)


func server_complete_raid_extraction(peer_id: int) -> void:
	if not multiplayer.is_server() or not raid_members.has(peer_id):
		return
	peer_raid_states[peer_id] = PeerRaidState.RETURNING_TO_LOBBY
	raid_members.erase(peer_id)
	_raid_loading_peers.erase(peer_id)
	print("[RAID] extracted peer=%d members=%s" % [peer_id, str(raid_members.keys())])
	_load_lobby_on_client.rpc_id(peer_id)
	peer_raid_states[peer_id] = PeerRaidState.MULTIPLAYER_LOBBY
	if raid_members.is_empty():
		raid_lifecycle = RaidLifecycle.LOBBY
		print("[STATE] server raid_lifecycle=LOBBY")


func server_mark_raid_started() -> void:
	if multiplayer.is_server():
		raid_lifecycle = RaidLifecycle.IN_RAID
		print("[STATE] server raid_lifecycle=IN_RAID")


func _report_connect_setup_failure(message: String, error: Error) -> Error:
	print(message)
	connection_status_changed.emit(message)
	session_state_changed.emit("OFFLINE")
	client_connection_failed.emit(message)
	return error


func _stop_current_peer() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	is_connecting = false
	ping_ms = -1
	_ping_elapsed = 0.0


func _on_peer_connected(peer_id: int) -> void:
	if is_server_mode:
		connected_peer_ids[peer_id] = true
		peer_raid_states[peer_id] = PeerRaidState.MULTIPLAYER_LOBBY
		print("[NETWORK] peer_connected=%d peers=%s" % [peer_id, str(connected_peer_ids.keys())])


func _on_peer_disconnected(peer_id: int) -> void:
	if is_server_mode:
		connected_peer_ids.erase(peer_id)
		peer_raid_states.erase(peer_id)
		raid_members.erase(peer_id)
		print("[NETWORK] peer_disconnected=%d peers=%s" % [peer_id, str(connected_peer_ids.keys())])
		if raid_lifecycle == RaidLifecycle.LOADING and _raid_loading_peers.erase(peer_id):
			print("[RAID] peer=%d disconnected while loading; ready=%d/%d" % [peer_id, raid_members.size() - _raid_loading_peers.size(), raid_members.size()])
		if raid_members.is_empty():
			raid_lifecycle = RaidLifecycle.LOBBY


func _on_connected_to_server() -> void:
	is_connecting = false
	var message := "Connected to server."
	print(message)
	connection_status_changed.emit(message)
	session_state_changed.emit("ONLINE")
	client_connected.emit()


func _on_connection_failed() -> void:
	is_connecting = false
	var message := "Connection failed. Check server IP, UDP port, and firewall."
	print(message)
	connection_status_changed.emit(message)
	session_state_changed.emit("OFFLINE")
	client_connection_failed.emit(message)
	_stop_current_peer()


func _on_server_disconnected() -> void:
	is_connecting = false
	var message := "Disconnected from server."
	print(message)
	connection_status_changed.emit(message)
	session_state_changed.emit("OFFLINE")
	_stop_current_peer()


@rpc("any_peer", "call_remote", "reliable")
func _request_raid_start() -> void:
	if not multiplayer.is_server():
		return
	var requester := multiplayer.get_remote_sender_id()
	if requester in connected_peer_ids:
		var peer_state := int(peer_raid_states.get(requester, PeerRaidState.MULTIPLAYER_LOBBY))
		if peer_state != PeerRaidState.MULTIPLAYER_LOBBY:
			print("[RAID] ignored join request peer=%d state=%d" % [requester, peer_state])
			return
		raid_join_requested.emit(requester)


@rpc("authority", "call_remote", "reliable")
func _load_raid_on_clients() -> void:
	if is_connected_to_server():
		print("[RAID] load request received peer=%d" % multiplayer.get_unique_id())
		load_raid_requested.emit()


@rpc("any_peer", "call_remote", "reliable")
func _client_raid_loaded() -> void:
	if not multiplayer.is_server():
		return
	var loaded_peer := multiplayer.get_remote_sender_id()
	if not _raid_loading_peers.has(loaded_peer):
		print("[RAID] ignored unexpected ready peer=%d" % loaded_peer)
		return
	_raid_loading_peers.erase(loaded_peer)
	peer_raid_states[loaded_peer] = PeerRaidState.IN_RAID
	raid_lifecycle = RaidLifecycle.IN_RAID
	print("[RAID] peer=%d loaded; state=IN_RAID members=%s" % [loaded_peer, str(raid_members.keys())])
	print("[STATE] server raid_lifecycle=IN_RAID")
	raid_client_loaded.emit(loaded_peer)


@rpc("any_peer", "call_remote", "reliable")
func _request_raid_extraction(extraction_name: String) -> void:
	if multiplayer.is_server():
		var peer_id := multiplayer.get_remote_sender_id()
		if int(peer_raid_states.get(peer_id, PeerRaidState.MULTIPLAYER_LOBBY)) == PeerRaidState.IN_RAID:
			raid_extraction_requested.emit(peer_id, extraction_name)


@rpc("authority", "call_remote", "reliable")
func _load_lobby_on_client() -> void:
	if is_connected_to_server():
		return_to_lobby_requested.emit()


@rpc("any_peer", "call_remote", "unreliable")
func _ping_server(sent_at_ms: int) -> void:
	if multiplayer.is_server():
		_pong_client.rpc_id(multiplayer.get_remote_sender_id(), sent_at_ms)


@rpc("authority", "call_remote", "unreliable")
func _pong_client(sent_at_ms: int) -> void:
	if is_connected_to_server():
		ping_ms = maxi(0, Time.get_ticks_msec() - sent_at_ms)
		ping_updated.emit(ping_ms)
