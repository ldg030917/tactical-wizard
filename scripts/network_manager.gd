extends Node

## ENet dedicated server/client bootstrap shared by every scene.
signal connection_status_changed(message: String)
signal client_connected
signal client_connection_failed(message: String)

const DEFAULT_PORT := 7000
const MAX_CLIENTS := 32

var is_server_mode := false
var is_connecting := false


func _ready() -> void:
	is_server_mode = "--server" in OS.get_cmdline_user_args()

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	if is_server_mode:
		call_deferred("start_server")


func start_server(port: int = DEFAULT_PORT, max_clients: int = MAX_CLIENTS) -> Error:
	if not is_server_mode:
		push_warning("start_server() is reserved for --server mode.")
		return ERR_UNAUTHORIZED

	_stop_current_peer()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, max_clients)
	if error != OK:
		var message := "Server start failed (port %d): %s" % [port, error_string(error)]
		print(message)
		connection_status_changed.emit(message)
		return error

	multiplayer.multiplayer_peer = peer
	var message := "Dedicated server listening on UDP port %d" % port
	print(message)
	connection_status_changed.emit(message)
	return OK


func connect_to_server(address: String, port: int = DEFAULT_PORT) -> Error:
	if is_server_mode:
		return ERR_UNAUTHORIZED

	var host := address.strip_edges()
	if host.is_empty():
		var empty_address_message := "서버 IP 주소를 입력하세요."
		print(empty_address_message)
		connection_status_changed.emit(empty_address_message)
		client_connection_failed.emit(empty_address_message)
		return ERR_INVALID_PARAMETER

	_stop_current_peer()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(host, port)
	if error != OK:
		var failed_message := "접속 준비 실패: %s" % error_string(error)
		print(failed_message)
		connection_status_changed.emit(failed_message)
		client_connection_failed.emit(failed_message)
		return error

	multiplayer.multiplayer_peer = peer
	is_connecting = true
	var message := "%s:%d 서버에 접속 중..." % [host, port]
	print(message)
	connection_status_changed.emit(message)
	return OK


func _stop_current_peer() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	is_connecting = false


func _on_peer_connected(peer_id: int) -> void:
	if is_server_mode:
		print("Client connected. ID: %d" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if is_server_mode:
		print("Client disconnected. ID: %d" % peer_id)


func _on_connected_to_server() -> void:
	is_connecting = false
	var message := "서버 접속 성공"
	print(message)
	connection_status_changed.emit(message)
	client_connected.emit()


func _on_connection_failed() -> void:
	is_connecting = false
	var message := "서버 접속 실패: IP, 포트, 방화벽을 확인하세요."
	print(message)
	connection_status_changed.emit(message)
	client_connection_failed.emit(message)
	_stop_current_peer()


func _on_server_disconnected() -> void:
	is_connecting = false
	var message := "서버와의 연결이 끊어졌습니다."
	print(message)
	connection_status_changed.emit(message)
	_stop_current_peer()
