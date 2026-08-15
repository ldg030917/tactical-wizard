extends Node

## Owns the ENet transport. World-specific spawning and simulation live in scenes.
signal connection_status_changed(message: String)
signal session_state_changed(state: String)
signal client_connected
signal client_connection_failed(message: String)
signal server_started
signal ping_updated(milliseconds: int)

const DEFAULT_PORT := 7000
const MAX_CLIENTS := 32
const PING_INTERVAL_SECONDS := 1.0

var is_server_mode := false
var is_connecting := false
var ping_ms := -1
var _ping_elapsed := 0.0


func _ready() -> void:
	# get_cmdline_user_args() is the documented form (-- --server). Reading the
	# remaining engine arguments too makes exported Linux service commands robust.
	var launch_args := PackedStringArray()
	launch_args.append_array(OS.get_cmdline_user_args())
	launch_args.append_array(OS.get_cmdline_args())
	is_server_mode = "--server" in launch_args

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
	print(message)
	connection_status_changed.emit(message)
	session_state_changed.emit("SERVER")
	server_started.emit()
	return OK


func connect_to_server(address: String, port: int = DEFAULT_PORT) -> Error:
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
		print("Client connected. ID: %d" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if is_server_mode:
		print("Client disconnected. ID: %d" % peer_id)


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


@rpc("any_peer", "call_remote", "unreliable")
func _ping_server(sent_at_ms: int) -> void:
	if multiplayer.is_server():
		_pong_client.rpc_id(multiplayer.get_remote_sender_id(), sent_at_ms)


@rpc("authority", "call_remote", "unreliable")
func _pong_client(sent_at_ms: int) -> void:
	if is_connected_to_server():
		ping_ms = maxi(0, Time.get_ticks_msec() - sent_at_ms)
		ping_updated.emit(ping_ms)
