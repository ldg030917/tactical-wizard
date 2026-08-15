extends Node

const REGION_GRAPH := preload("res://scripts/regions/region_graph.gd")

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

var active_area: Node
var start_screen: StartScreen

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
		result_ui.visible = false
		pause_menu.visible = false
		print("Main started in dedicated server mode.")
		return

	connect_button.pressed.connect(_connect_to_server)
	server_address_input.text_submitted.connect(func(_text: String) -> void: _connect_to_server())
	NetworkManager.connection_status_changed.connect(_set_connection_status)
	NetworkManager.client_connected.connect(_on_client_connected)
	NetworkManager.client_connection_failed.connect(_on_client_connection_failed)
	(result_ui.get_node("%ReturnButton") as Button).pressed.connect(_return_from_result)
	(pause_menu.get_node("%ResumeButton") as Button).pressed.connect(toggle_pause)
	pause_menu.get_node("Panel/Layout/ReturnButton").pressed.connect(_abandon_to_base)
	show_start()


func _connect_to_server() -> void:
	connect_button.disabled = true
	var error := NetworkManager.connect_to_server(server_address_input.text)
	if error != OK:
		connect_button.disabled = false


func _set_connection_status(message: String) -> void:
	connection_status_label.text = message


func _on_client_connected() -> void:
	network_panel.visible = false


func _on_client_connection_failed(_message: String) -> void:
	connect_button.disabled = false

func show_start() -> void:
	get_tree().paused = false
	result_ui.visible = false
	pause_menu.visible = false
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
	get_tree().paused = false
	result_ui.visible = false
	pause_menu.visible = false
	_clear_active()
	active_area = base_scene.instantiate()
	world_container.add_child(active_area)

func start_raid() -> void:
	if not GameState.begin_raid():
		return
	result_ui.visible = false
	_clear_active()
	var region := ContentRegistry.regions().get(REGION_GRAPH.ENTRY_REGION_ID) as RegionData
	var selected_scene: PackedScene = region.scene if region != null and region.scene != null else raid_scene
	active_area = selected_scene.instantiate()
	world_container.add_child(active_area)

func travel_to_region(region_id: String) -> bool:
	if not active_area is RaidScene:
		return false
	var departing_raid := active_area as RaidScene
	departing_raid.capture_region_travel_state()
	if not GameState.enter_raid_region(region_id):
		departing_raid.player.set_physics_process(true)
		departing_raid.show_message("That elemental region is not connected or its entry requirement is missing.")
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
	result_ui.visible = true
	var title := result_ui.get_node("%ResultTitle") as Label
	title.text = "EXTRACTION COMPLETE" if bool(summary.success) else "EXPEDITION LOST"
	title.modulate = Color("7ee1b2") if bool(summary.success) else Color("e06d66")
	var detail := result_ui.get_node("%ResultDetails") as Label
	detail.text = "Expedition time: %s  |  Foes defeated: %d\n%s\n\n%s" % [_format_time(int(summary.duration)), int(summary.kills), "Recovered value: %d crowns" % int(summary.value) if bool(summary.success) else "Unsecured magical equipment and expedition loot were lost.", _summary_items(summary.recovered if bool(summary.success) else summary.lost)]
	(result_ui.get_node("%QuestProgress") as Label).text = "Expedition: " + GameState.active_quest_text()

func toggle_pause() -> void:
	if result_ui.visible:
		return
	get_tree().paused = not get_tree().paused
	pause_menu.visible = get_tree().paused

func _return_from_result() -> void:
	result_ui.visible = false
	show_base()

func _abandon_to_base() -> void:
	get_tree().paused = false
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
		return "No items"
	var lines: PackedStringArray = []
	for item_id: String in items.keys():
		lines.append("%s x%d" % [ItemDB.display_name(item_id), int(items[item_id])])
	return "\n".join(lines)

func _format_time(seconds: int) -> String:
	return "%02d:%02d" % [seconds / 60, seconds % 60]
