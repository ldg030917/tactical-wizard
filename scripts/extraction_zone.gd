@tool
class_name ExtractionZone
extends Node3D

signal extraction_started(extraction_id: String)
signal extraction_cancelled(extraction_id: String)
signal extraction_completed(extraction_id: String)

@export_category("Extraction Identity")
@export var extraction_id: String = "old_footbridge"
@export var extraction_name: String = "Old Footbridge"
@export var destination_scene: String = "res://scenes/base/base.tscn"

@export_category("Availability")
@export var always_available: bool = true
@export var required_key_item: ItemData
@export var required_quest_id: String = ""
@export_range(0, 5000, 1) var currency_cost: int = 0

@export_category("Countdown")
@export_range(1.0, 15.0, 0.25, "suffix:s") var countdown_duration: float = 6.0
@export_range(0.5, 10.0, 0.1, "suffix:m") var radius: float = 3.0
@export var damage_interrupts: bool = true
@export var one_time_use: bool = true

@export_category("Editor Visualization")
@export var debug_color: Color = Color(0.2, 0.85, 0.68, 0.38)

var required_item_override: String = ""
var required_item: String:
	get:
		return required_key_item.item_id if required_key_item != null else required_item_override
	set(value):
		required_item_override = value

var countdown: float = 0.0
var player_inside: bool = false
var completed: bool = false
@onready var visual: Node3D = %Visual
@onready var ring: MeshInstance3D = %ExtractionRadius
@onready var zone_shape: CollisionShape3D = %ZoneCollision
@onready var zone_label: Label3D = %ExtractionLabel

func _ready() -> void:
	add_to_group("extractions")
	zone_label.text = extraction_name
	var shape := zone_shape.shape as CylinderShape3D
	if shape != null:
		shape.radius = radius
	ring.scale = Vector3(radius / 3.0, 1.0, radius / 3.0)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if zone_label != null:
			zone_label.text = extraction_name
		if ring != null:
			ring.scale = Vector3(radius / 3.0, 1.0, radius / 3.0)
		return
	if completed:
		return
	# Extraction UI/countdown is local-client presentation. The dedicated server
	# validates the final request against its authoritative player transform.
	if NetworkManager.is_network_game() and multiplayer.is_server():
		return
	var player := _active_local_player()
	if player == null or player.dead:
		return
	player_inside = global_position.distance_to(player.global_position) <= radius
	var raid: Node = _raid_scene()
	if not player_inside:
		if countdown > 0.0:
			countdown = 0.0
			extraction_cancelled.emit(extraction_id)
			if raid.has_method("set_extraction_status"):
				raid.set_extraction_status("")
		return
	var has_key: bool = required_item.is_empty() or int(GameState.raid_inventory.get(required_item, 0)) > 0 or int(GameState.raid_secure.get(required_item, 0)) > 0
	var has_quest: bool = required_quest_id.is_empty() or _quest_condition_met()
	var has_currency: bool = GameState.currency >= currency_cost
	var has_requirement: bool = (always_available or not required_item.is_empty() or not required_quest_id.is_empty() or currency_cost > 0) and has_key and has_quest and has_currency
	if not has_requirement:
		if raid.has_method("set_extraction_status"):
			var requirement_text: String = ItemDB.display_name(required_item) if not required_item.is_empty() else ("contract %s" % required_quest_id if not required_quest_id.is_empty() else "%d crowns" % currency_cost)
			raid.set_extraction_status("%s — requires %s" % [extraction_name, requirement_text])
		return
	if countdown <= 0.0:
		countdown = countdown_duration
		extraction_started.emit(extraction_id)
	countdown -= delta
	var now: float = Time.get_ticks_msec() / 1000.0
	if damage_interrupts and now - player.last_damage_time < 0.25:
		countdown = countdown_duration
	if raid.has_method("set_extraction_status"):
		raid.set_extraction_status("EXTRACTING: %s  %.1fs" % [extraction_name, maxf(0.0, countdown)])
	if countdown <= 0.0:
		completed = true
		if currency_cost > 0:
			GameState.currency -= currency_cost
		extraction_completed.emit(extraction_id)
		if raid.has_method("complete_extraction"):
			raid.complete_extraction(extraction_name)

func _raid_scene() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node is RaidScene:
			return node
		node = node.get_parent()
	return get_parent()


func _active_local_player() -> PlayerController:
	for node: Node in get_tree().get_nodes_in_group("player"):
		if not node is PlayerController:
			continue
		var candidate := node as PlayerController
		if not NetworkManager.is_network_game() or candidate.is_local_network_player():
			return candidate
	return null

func _quest_condition_met() -> bool:
	for quest: Dictionary in GameState.quests:
		if str(quest.get("id", "")) == required_quest_id:
			return str(quest.get("state", "")) in ["complete", "claimed"]
	return false
