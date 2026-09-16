extends Node

const REGION_GRAPH := preload("res://scripts/regions/region_graph.gd")

enum SessionPhase { MAIN_MENU, SOLO_LOBBY, MULTIPLAYER_LOBBY, LOADING_RAID, IN_RAID, RETURNING_TO_LOBBY }

@export_category("Area Scenes")
@export var base_scene: PackedScene
@export var raid_scene: PackedScene
@export var start_screen_scene: PackedScene

@onready var world_container: Node = %WorldContainer
@onready var result_ui: Control = %RaidResultUI
@onready var pause_menu: Control = %PauseMenu
@onready var network_panel: Control = %NetworkPanel
@onready var server_address_input: LineEdit = %ServerAddressInput
@onready var connect_button: Button = %ConnectButton
@onready var connection_status_label: Label = %ConnectionStatusLabel
@onready var network_status_label: Label = %NetworkStatusLabel
@onready var matchmaking_panel: Control = %MatchmakingPanel
@onready var matchmaking_status_label: Label = %MatchmakingStatusLabel
@onready var find_match_button: Button = %FindMatchButton
@onready var cancel_match_button: Button = %CancelMatchButton
@onready var test_raid_button: Button = %TestRaidButton

var active_area: Node
var start_screen: StartScreen
var local_menu_open := false
var session_phase := SessionPhase.MAIN_MENU
var _pending_network_region_state: Dictionary = {}

func _ready() -> void:
	if "--content-parity-check" in OS.get_cmdline_user_args():
		var snapshot: Dictionary = GameState.content_parity_snapshot()
		print("CONTENT PARITY SNAPSHOT: " + JSON.stringify(snapshot))
		if bool(snapshot.ok):
			print("CONTENT PARITY CHECK PASSED")
			get_tree().quit(0)
		else:
			push_error("CONTENT PARITY CHECK FAILED")
			get_tree().quit(1)
		return
	if NetworkManager.is_server_mode:
		# A headless export has no renderer, and this also keeps normal --server
		# launches from displaying any game UI.
		network_panel.visible = false
		matchmaking_panel.visible = false
		result_ui.visible = false
		pause_menu.visible = false
		network_status_label.visible = false
		print("Main started in dedicated server mode.")
		NetworkManager.raid_session_world_requested.connect(_on_server_raid_session_world_requested)
		NetworkManager.raid_session_clients_ready.connect(_on_server_raid_session_clients_ready)
		NetworkManager.raid_extraction_requested.connect(_on_server_raid_extraction_requested)
		NetworkManager.raid_region_world_requested.connect(_on_server_raid_region_world_requested)
		NetworkManager.raid_region_clients_ready.connect(_on_server_raid_region_clients_ready)
		return

	connect_button.pressed.connect(_connect_to_server)
	find_match_button.pressed.connect(_find_match)
	cancel_match_button.pressed.connect(_cancel_matchmaking)
	test_raid_button.pressed.connect(_start_test_raid)
	# Prototype clients always use NetworkManager.DEFAULT_SERVER_ADDRESS. Keep the
	# field out of the normal flow so stale UI text can never alter the endpoint.
	server_address_input.visible = false
	NetworkManager.connection_status_changed.connect(_set_connection_status)
	NetworkManager.client_connected.connect(_on_client_connected)
	NetworkManager.client_connection_failed.connect(_on_client_connection_failed)
	NetworkManager.session_state_changed.connect(_on_session_state_changed)
	NetworkManager.ping_updated.connect(_on_ping_updated)
	NetworkManager.matchmaking_status_changed.connect(_on_matchmaking_status_changed)
	NetworkManager.load_raid_requested.connect(_on_client_load_raid_requested)
	NetworkManager.load_raid_region_requested.connect(_on_client_load_raid_region_requested)
	NetworkManager.raid_completed.connect(_on_client_raid_completed)
	(result_ui.get_node("%ReturnButton") as Button).pressed.connect(_return_from_result)
	(pause_menu.get_node("%ResumeButton") as Button).pressed.connect(toggle_pause)
	pause_menu.get_node("Panel/Layout/ReturnButton").pressed.connect(_abandon_to_base)
	show_start()


func _input(event: InputEvent) -> void:
	# Multiplayer pause/menu input belongs to the persistent client root. Handling
	# Escape here (before Control nodes and Player._unhandled_input) prevents UI
	# focus from swallowing the event or leaving menu and gameplay state inverted.
	if not NetworkManager.is_connected_to_server() or session_phase != SessionPhase.IN_RAID:
		return
	if event.is_action_pressed("pause_game"):
		print("[INPUT_EVENT] peer=%d action=pause_game pressed=true handled_by=Main" % multiplayer.get_unique_id())
		toggle_pause("escape")
		get_viewport().set_input_as_handled()


func _connect_to_server() -> void:
	connect_button.disabled = true
	var error := NetworkManager.connect_to_default_server()
	if error != OK:
		connect_button.disabled = false


func _set_connection_status(message: String) -> void:
	connection_status_label.text = message


func _on_client_connected() -> void:
	network_panel.visible = false
	if start_screen != null:
		start_screen.visible = false
	show_base()


func _on_client_connection_failed(_message: String) -> void:
	connect_button.disabled = false


func _on_session_state_changed(state: String) -> void:
	match state:
		"ONLINE":
			network_status_label.text = "ONLINE\nPing: measuring...\nPeer: %d" % multiplayer.get_unique_id()
		"CONNECTING":
			network_status_label.text = "CONNECTING..."
		_:
			network_status_label.text = "OFFLINE"


func _on_ping_updated(milliseconds: int) -> void:
	network_status_label.text = "ONLINE\nPing: %d ms\nPeer: %d" % [milliseconds, multiplayer.get_unique_id()]

func show_start() -> void:
	session_phase = SessionPhase.MAIN_MENU
	get_tree().paused = false
	result_ui.visible = false
	pause_menu.visible = false
	matchmaking_panel.visible = false
	_clear_active()
	if start_screen == null or not is_instance_valid(start_screen):
		start_screen = start_screen_scene.instantiate() as StartScreen
		add_child(start_screen)
		start_screen.start_requested.connect(start_game)
	start_screen.visible = true

func start_game() -> void:
	if start_screen != null:
		start_screen.visible = false
	show_base()

func show_base() -> void:
	session_phase = SessionPhase.MULTIPLAYER_LOBBY if NetworkManager.is_connected_to_server() else SessionPhase.SOLO_LOBBY
	get_tree().paused = false
	result_ui.visible = false
	pause_menu.visible = false
	matchmaking_panel.visible = NetworkManager.is_connected_to_server()
	if NetworkManager.is_connected_to_server():
		matchmaking_status_label.text = "LOBBY"
		find_match_button.disabled = false
		cancel_match_button.disabled = true
		test_raid_button.disabled = false
	_clear_active()
	active_area = base_scene.instantiate()
	if active_area is BaseScene and NetworkManager.is_connected_to_server():
		(active_area as BaseScene).local_lobby = true
		print("[LOBBY] Enter multiplayer lobby peer=%d" % multiplayer.get_unique_id())
	else:
		print("[LOBBY] Enter solo lobby")
	world_container.add_child(active_area)

func start_raid() -> void:
	if NetworkManager.is_connected_to_server():
		NetworkManager.request_raid_start()
		return
	_start_raid_scene()


func _find_match() -> void:
	NetworkManager.request_matchmaking()


func _cancel_matchmaking() -> void:
	NetworkManager.cancel_matchmaking()


func _start_test_raid() -> void:
	NetworkManager.request_test_raid()


func _start_raid_scene(session_id: String = "") -> void:
	session_phase = SessionPhase.LOADING_RAID
	local_menu_open = false
	pause_menu.visible = false
	matchmaking_panel.visible = false
	if not GameState.begin_raid():
		return
	result_ui.visible = false
	_clear_active()
	var region := ContentRegistry.regions().get(REGION_GRAPH.ENTRY_REGION_ID) as RegionData
	var selected_scene: PackedScene = region.scene if region != null and region.scene != null else raid_scene
	active_area = selected_scene.instantiate()
	if active_area is RaidScene:
		(active_area as RaidScene).raid_session_id = session_id
	world_container.add_child(active_area)
	session_phase = SessionPhase.IN_RAID
	if NetworkManager.is_connected_to_server():
		refresh_local_input_state("raid_start")


func _on_server_raid_session_world_requested(session_id: String) -> void:
	if active_area == null or not active_area is RaidScene or (active_area as RaidScene).raid_session_id != session_id:
		_create_local_server_raid_world(session_id)
	NetworkManager.server_begin_session_loading(session_id)


## The current SessionManager allocates one local world slot. Keeping that
## implementation here means a later external raid-server allocator changes the
## SessionManager boundary rather than gameplay systems or client transitions.
func _create_local_server_raid_world(session_id: String) -> void:
	_start_raid_scene(session_id)
	print("[RAID %s] Server created local raid world" % session_id)


func _on_client_load_raid_requested(session_id: String) -> void:
	print("[RAID %s] Client loading raid scene" % session_id)
	_start_raid_scene(session_id)
	NetworkManager.client_raid_scene_ready(session_id)


func _on_server_raid_session_clients_ready(session_id: String, members: Array[int]) -> void:
	if active_area is RaidScene and (active_area as RaidScene).raid_session_id == session_id:
		for peer_id: int in members:
			(active_area as RaidScene).spawn_network_raid_member(peer_id)


func begin_network_region_transition(region_id: String) -> bool:
	if not multiplayer.is_server() or not active_area is RaidScene:
		return false
	var raid := active_area as RaidScene
	_pending_network_region_state = raid.capture_network_travel_state()
	return NetworkManager.server_begin_region_transition(raid.raid_session_id, region_id)


func _on_server_raid_region_world_requested(session_id: String, region_id: String) -> void:
	_replace_with_network_region(session_id, region_id, _pending_network_region_state)
	_pending_network_region_state = {}


func _on_client_load_raid_region_requested(session_id: String, region_id: String) -> void:
	GameState.current_raid_region_id = region_id
	if region_id not in GameState.raid_visited_regions:
		GameState.raid_visited_regions.append(region_id)
	_replace_with_network_region(session_id, region_id)
	NetworkManager.client_raid_region_ready(session_id, region_id)


func _on_server_raid_region_clients_ready(session_id: String, members: Array[int]) -> void:
	if active_area is RaidScene and (active_area as RaidScene).raid_session_id == session_id:
		for peer_id: int in members:
			(active_area as RaidScene).spawn_network_raid_member(peer_id)


func _replace_with_network_region(session_id: String, region_id: String, restore_state: Dictionary = {}) -> void:
	session_phase = SessionPhase.LOADING_RAID
	pause_menu.visible = false
	matchmaking_panel.visible = false
	_clear_active()
	var region := ContentRegistry.regions().get(region_id) as RegionData
	var selected_scene: PackedScene = region.scene if region != null and region.scene != null else raid_scene
	active_area = selected_scene.instantiate()
	if active_area is RaidScene:
		var new_raid := active_area as RaidScene
		new_raid.raid_session_id = session_id
		new_raid.network_restore_states = restore_state.get("players", {}).duplicate(true)
		new_raid.network_restored_kills = restore_state.get("kills", {}).duplicate(true)
	world_container.add_child(active_area)
	session_phase = SessionPhase.IN_RAID


func _on_server_raid_extraction_requested(peer_id: int, extraction_name: String, session_id: String) -> void:
	if active_area is RaidScene and (active_area as RaidScene).raid_session_id == session_id:
		var raid := active_area as RaidScene
		var success := extraction_name != "abandoned"
		if raid.extract_network_player(peer_id, extraction_name):
			NetworkManager.server_complete_raid_extraction(peer_id, success, raid.network_raid_result(extraction_name))


func _on_client_raid_completed(success: bool, server_result: Dictionary) -> void:
	local_menu_open = false
	pause_menu.visible = false
	get_tree().paused = false
	if active_area is RaidScene:
		var result_kills: Dictionary = server_result.get("kills", (active_area as RaidScene).kills)
		var summary: Dictionary = GameState.finish_raid(success, result_kills, str(server_result.get("extraction", "")))
		show_end_screen(summary)


func _on_matchmaking_status_changed(message: String) -> void:
	network_status_label.text = "ONLINE\n%s\nPeer: %d" % [message, multiplayer.get_unique_id()]
	matchmaking_status_label.text = message
	var is_queuing := message.begins_with("MATCHMAKING")
	find_match_button.disabled = is_queuing or message.begins_with("MATCH FOUND")
	cancel_match_button.disabled = not is_queuing
	test_raid_button.disabled = is_queuing or message.begins_with("MATCH FOUND")

func travel_to_region(region_id: String) -> bool:
	if not active_area is RaidScene:
		return false
	var departing_raid := active_area as RaidScene
	departing_raid.capture_region_travel_state()
	if not GameState.enter_raid_region(region_id):
		departing_raid.player.set_physics_process(true)
		departing_raid.show_message("해당 원소 지역이 연결되지 않았거나 입장 조건을 충족하지 못했습니다.")
		return false
	var region := GameState.current_raid_region()
	if region == null or region.scene == null:
		departing_raid.player.set_physics_process(true)
		return false
	_clear_active()
	active_area = region.scene.instantiate()
	world_container.add_child(active_area)
	return true

func show_end_screen(summary: Dictionary) -> void:
	local_menu_open = false
	pause_menu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	result_ui.visible = true
	var title := result_ui.get_node("%ResultTitle") as Label
	title.text = "탈출 완료" if bool(summary.success) else "원정 실패"
	title.modulate = Color("7ee1b2") if bool(summary.success) else Color("e06d66")
	var detail := result_ui.get_node("%ResultDetails") as Label
	detail.text = "원정 시간: %s  |  처치한 적: %d\n%s\n\n%s" % [_format_time(int(summary.duration)), int(summary.kills), "회수 가치: %d 크라운" % int(summary.value) if bool(summary.success) else "보호하지 않은 마법 장비와 원정 전리품을 잃었습니다.", _summary_items(summary.recovered if bool(summary.success) else summary.lost)]
	(result_ui.get_node("%QuestProgress") as Label).text = "원정: " + GameState.active_quest_text()

func toggle_pause(source: String = "toggle_pause") -> void:
	if result_ui.visible:
		return
	if NetworkManager.is_connected_to_server():
		_set_network_menu_open(not local_menu_open, source)
		return
	get_tree().paused = not get_tree().paused
	pause_menu.visible = get_tree().paused


func _set_network_menu_open(open: bool, source: String) -> void:
	local_menu_open = open
	pause_menu.visible = open
	refresh_local_input_state(source)


func refresh_local_input_state(source: String = "external") -> void:
	if not NetworkManager.is_connected_to_server():
		# Preserve main's visible, absolute mouse aiming in solo play.
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	var raid_ui_open := active_area is RaidScene and (active_area as RaidScene).is_aim_ui_open()
	var gameplay_blocked := local_menu_open or raid_ui_open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if gameplay_blocked else Input.MOUSE_MODE_CAPTURED
	print("[INPUT_STATE] peer=%d source=%s menu_open=%s pause_visible=%s raid_ui_open=%s gameplay_blocked=%s mouse_mode=%d" % [
		multiplayer.get_unique_id(), source, str(local_menu_open), str(pause_menu.visible),
		str(raid_ui_open), str(gameplay_blocked), Input.mouse_mode
	])


func is_local_ui_open() -> bool:
	return local_menu_open

func _return_from_result() -> void:
	session_phase = SessionPhase.RETURNING_TO_LOBBY
	result_ui.visible = false
	show_base()

func _abandon_to_base() -> void:
	get_tree().paused = false
	if NetworkManager.is_connected_to_server() and active_area is RaidScene:
		pause_menu.visible = false
		NetworkManager.request_raid_extraction("abandoned")
		return
	if GameState.in_raid:
		GameState.finish_raid(false, GameState.raid_kills)
	pause_menu.visible = false
	show_base()

func _clear_active() -> void:
	if active_area != null and is_instance_valid(active_area):
		world_container.remove_child(active_area)
		active_area.queue_free()
	active_area = null

func _summary_items(items: Dictionary) -> String:
	if items.is_empty():
		return "아이템 없음"
	var lines: PackedStringArray = []
	for item_id: String in items.keys():
		lines.append("%s x%d" % [ItemDB.display_name(item_id), int(items[item_id])])
	return "\n".join(lines)

func _format_time(seconds: int) -> String:
	return "%02d:%02d" % [seconds / 60, seconds % 60]
