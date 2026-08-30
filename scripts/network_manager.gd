extends Node

## Owns ENet connection state and RPC routing. MatchmakingManager owns queue
## batching; SessionManager owns the logical RaidSession lifecycle.
signal connection_status_changed(message: String)
signal session_state_changed(state: String)
signal matchmaking_status_changed(message: String)
signal client_connected
signal client_connection_failed(message: String)
signal server_started
signal ping_updated(milliseconds: int)
signal raid_session_world_requested(session_id: String)
signal load_raid_requested(session_id: String)
signal raid_session_clients_ready(session_id: String, members: Array[int])
signal raid_extraction_requested(peer_id: int, extraction_name: String, session_id: String)
signal return_to_lobby_requested

const DEFAULT_PORT := 7000
const DEFAULT_SERVER_ADDRESS := "158.180.84.54"
const MAX_CLIENTS := 32
const PING_INTERVAL_SECONDS := 1.0

enum PeerRaidState { MULTIPLAYER_LOBBY, MATCHMAKING, MATCHED_WAITING_WORLD, LOADING_RAID, IN_RAID, RETURNING_TO_LOBBY, DISCONNECTED }

var is_server_mode := false
var is_connecting := false
var ping_ms := -1
var _ping_elapsed := 0.0
var connected_peer_ids: Dictionary = {}
var peer_raid_states: Dictionary = {}
var client_raid_session_id := ""


func _ready() -> void:
	var launch_args := PackedStringArray()
	launch_args.append_array(OS.get_cmdline_user_args())
	launch_args.append_array(OS.get_cmdline_args())
	is_server_mode = "--server" in launch_args
	if is_server_mode:
		print("[SERVER] boot build=session-boundary-v1 args=%s" % str(launch_args))
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	if is_server_mode:
		MatchmakingManager.match_ready.connect(_on_match_ready)
		MatchmakingManager.queue_changed.connect(_on_matchmaking_queue_changed)
		SessionManager.world_requested.connect(_on_session_world_requested)
		SessionManager.members_loaded.connect(_on_session_members_loaded)
	if is_server_mode:
		call_deferred("start_server")


func _process(delta: float) -> void:
	if is_server_mode or not is_connected_to_server():
		return
	_ping_elapsed += delta
	if _ping_elapsed >= PING_INTERVAL_SECONDS:
		_ping_elapsed = 0.0
		_ping_server.rpc_id(1, Time.get_ticks_msec())


func start_server(port: int = DEFAULT_PORT, max_clients: int = MAX_CLIENTS) -> Error:
	if not is_server_mode:
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
	print("[SERVER] multiplayer peer created")
	print("[SERVER] listening udp=%d" % port)
	connection_status_changed.emit("Dedicated server listening on UDP port %d" % port)
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
	connection_status_changed.emit("Connecting to %s:%d..." % [host, port])
	session_state_changed.emit("CONNECTING")
	return OK


func is_connected_to_server() -> bool:
	return not is_server_mode and multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_network_game() -> bool:
	return is_server_mode or is_connected_to_server()


func request_matchmaking() -> void:
	if is_connected_to_server():
		_request_matchmaking.rpc_id(1)


func cancel_matchmaking() -> void:
	if is_connected_to_server():
		_cancel_matchmaking.rpc_id(1)


func request_test_raid() -> void:
	if is_connected_to_server():
		_request_test_raid.rpc_id(1)


## Compatibility entry point for existing deployment station interactions.
func request_raid_start() -> void:
	request_matchmaking()


func client_raid_scene_ready(session_id: String) -> void:
	if is_connected_to_server() and session_id == client_raid_session_id:
		_client_raid_loaded.rpc_id(1, session_id)


func request_raid_extraction(extraction_name: String) -> void:
	if is_connected_to_server():
		_request_raid_extraction.rpc_id(1, extraction_name)


func get_session_members(session_id: String) -> Array[int]:
	return SessionManager.get_session_members(session_id)


func get_peer_session_id(peer_id: int) -> String:
	return SessionManager.get_player_session(peer_id)


func server_complete_raid_extraction(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var session_id := get_peer_session_id(peer_id)
	if session_id.is_empty():
		return
	print("[RAID %s] extracted peer=%d" % [session_id, peer_id])
	SessionManager.remove_player(peer_id, "extracted")
	peer_raid_states[peer_id] = PeerRaidState.RETURNING_TO_LOBBY
	_load_lobby_on_client.rpc_id(peer_id)
	peer_raid_states[peer_id] = PeerRaidState.MULTIPLAYER_LOBBY


func _queue_peer(peer_id: int) -> void:
	if not connected_peer_ids.has(peer_id) or int(peer_raid_states.get(peer_id, PeerRaidState.DISCONNECTED)) != PeerRaidState.MULTIPLAYER_LOBBY:
		return
	if MatchmakingManager.contains(peer_id):
		_send_matchmaking_status(peer_id, "MATCHMAKING  %d / %d" % [MatchmakingManager.size(), MatchmakingManager.MAX_MATCH_PLAYERS])
		return
	peer_raid_states[peer_id] = PeerRaidState.MATCHMAKING
	MatchmakingManager.enqueue(peer_id)


func _cancel_queued_peer(peer_id: int, reason: String = "cancelled") -> void:
	if not MatchmakingManager.remove(peer_id, reason):
		return
	if connected_peer_ids.has(peer_id):
		peer_raid_states[peer_id] = PeerRaidState.MULTIPLAYER_LOBBY
		_send_matchmaking_status(peer_id, "LOBBY")


func _create_raid_session(requested_members: Array[int], is_test_session: bool) -> void:
	var members: Array[int] = []
	for peer_id: int in requested_members:
		if connected_peer_ids.has(peer_id) and get_peer_session_id(peer_id).is_empty():
			members.append(peer_id)
	if members.is_empty() or (not is_test_session and members.size() < MatchmakingManager.MIN_MATCH_PLAYERS):
		for peer_id: int in members:
			peer_raid_states[peer_id] = PeerRaidState.MULTIPLAYER_LOBBY
			_queue_peer(peer_id)
		return
	var session_id := SessionManager.create_session(members, is_test_session)
	if session_id.is_empty():
		return
	var session := SessionManager.get_session(session_id)
	var starts_now := int(session.get("state", SessionManager.State.CLOSED)) == SessionManager.State.PREPARING_WORLD
	for peer_id: int in members:
		peer_raid_states[peer_id] = PeerRaidState.LOADING_RAID if starts_now else PeerRaidState.MATCHED_WAITING_WORLD
		_send_matchmaking_status(peer_id, "MATCH FOUND  %d Players" % members.size())
	if starts_now:
		SessionManager.activate_session(session_id)


func server_begin_session_loading(session_id: String) -> void:
	if not multiplayer.is_server() or not SessionManager.begin_loading(session_id):
		return
	for peer_id: int in get_session_members(session_id):
		if connected_peer_ids.has(peer_id):
			peer_raid_states[peer_id] = PeerRaidState.LOADING_RAID
			print("[RAID %s] sending load peer=%d" % [session_id, peer_id])
			_load_raid_on_clients.rpc_id(peer_id, session_id)
		else:
			SessionManager.remove_player(peer_id, "disconnected_before_load")


func _on_match_ready(members: Array[int]) -> void:
	_create_raid_session(members, false)


func _on_matchmaking_queue_changed(queue: Array[int]) -> void:
	for peer_id: int in queue:
		if connected_peer_ids.has(peer_id):
			_send_matchmaking_status(peer_id, "MATCHMAKING  %d / %d" % [queue.size(), MatchmakingManager.MAX_MATCH_PLAYERS])


func _on_session_world_requested(session_id: String) -> void:
	for peer_id: int in get_session_members(session_id):
		peer_raid_states[peer_id] = PeerRaidState.LOADING_RAID
	raid_session_world_requested.emit(session_id)


func _on_session_members_loaded(session_id: String, members: Array[int]) -> void:
	for peer_id: int in members:
		peer_raid_states[peer_id] = PeerRaidState.IN_RAID
	print("[RAID %s] all members loaded; spawning players" % session_id)
	raid_session_clients_ready.emit(session_id, members)


func _send_matchmaking_status(peer_id: int, text: String) -> void:
	if multiplayer.is_server() and connected_peer_ids.has(peer_id):
		_matchmaking_status.rpc_id(peer_id, text)


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
	if not is_server_mode:
		return
	var session_id := get_peer_session_id(peer_id)
	_cancel_queued_peer(peer_id, "disconnected")
	connected_peer_ids.erase(peer_id)
	if not session_id.is_empty():
		print("[RAID %s] disconnected peer=%d" % [session_id, peer_id])
		SessionManager.remove_player(peer_id, "disconnected")
	peer_raid_states.erase(peer_id)
	print("[NETWORK] peer_disconnected=%d peers=%s" % [peer_id, str(connected_peer_ids.keys())])


func _on_connected_to_server() -> void:
	is_connecting = false
	connection_status_changed.emit("Connected to server.")
	session_state_changed.emit("ONLINE")
	client_connected.emit()


func _on_connection_failed() -> void:
	is_connecting = false
	var message := "Connection failed. Check server IP, UDP port, and firewall."
	connection_status_changed.emit(message)
	session_state_changed.emit("OFFLINE")
	client_connection_failed.emit(message)
	_stop_current_peer()


func _on_server_disconnected() -> void:
	is_connecting = false
	connection_status_changed.emit("Disconnected from server.")
	session_state_changed.emit("OFFLINE")
	_stop_current_peer()


@rpc("any_peer", "call_remote", "reliable")
func _request_matchmaking() -> void:
	if multiplayer.is_server():
		_queue_peer(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func _cancel_matchmaking() -> void:
	if multiplayer.is_server():
		_cancel_queued_peer(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func _request_test_raid() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if connected_peer_ids.has(peer_id) and int(peer_raid_states.get(peer_id, -1)) == PeerRaidState.MULTIPLAYER_LOBBY:
		_create_raid_session([peer_id], true)


@rpc("authority", "call_remote", "reliable")
func _load_raid_on_clients(session_id: String) -> void:
	if is_connected_to_server():
		client_raid_session_id = session_id
		print("[RAID %s] load request received peer=%d" % [session_id, multiplayer.get_unique_id()])
		load_raid_requested.emit(session_id)


@rpc("any_peer", "call_remote", "reliable")
func _client_raid_loaded(session_id: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if get_peer_session_id(peer_id) != session_id:
		print("[RAID %s] ignored ready peer=%d" % [session_id, peer_id])
		return
	SessionManager.mark_player_loaded(session_id, peer_id)


@rpc("any_peer", "call_remote", "reliable")
func _request_raid_extraction(extraction_name: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var session_id := get_peer_session_id(peer_id)
	if not session_id.is_empty() and int(peer_raid_states.get(peer_id, -1)) == PeerRaidState.IN_RAID:
		raid_extraction_requested.emit(peer_id, extraction_name, session_id)


@rpc("authority", "call_remote", "reliable")
func _load_lobby_on_client() -> void:
	if is_connected_to_server():
		client_raid_session_id = ""
		return_to_lobby_requested.emit()


@rpc("authority", "call_remote", "reliable")
func _matchmaking_status(text: String) -> void:
	if is_connected_to_server():
		matchmaking_status_changed.emit(text)


@rpc("any_peer", "call_remote", "unreliable")
func _ping_server(sent_at_ms: int) -> void:
	if multiplayer.is_server():
		_pong_client.rpc_id(multiplayer.get_remote_sender_id(), sent_at_ms)


@rpc("authority", "call_remote", "unreliable")
func _pong_client(sent_at_ms: int) -> void:
	if is_connected_to_server():
		ping_ms = maxi(0, Time.get_ticks_msec() - sent_at_ms)
