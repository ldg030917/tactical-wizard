@tool
class_name LootContainer
extends Node3D

signal search_started(container: LootContainer)
signal search_completed(container: LootContainer)
signal item_taken(item_id: String, amount: int)

@export_category("Container Identity")
@export var container_id: String = "wooden_crate"
@export var container_name: String = "Wooden Crate"
@export_multiline var interaction_text: String = "Search container"

@export_category("Loot")
@export var loot_table: LootTableData
@export_range(0.0, 1.0, 0.01) var activation_chance: float = 1.0
@export_range(1, 10, 1) var minimum_items: int = 1
@export_range(1, 12, 1) var maximum_items: int = 4
@export_range(0.1, 5.0, 0.05, "suffix:s") var search_duration: float = 0.75

@export_category("Lock")
@export var starts_locked: bool = false
@export var required_key_item: ItemData

@export_category("Visual State")
@export_enum("rotate_lid", "hide_lid", "unchanged") var opened_visual_state: String = "rotate_lid"
@export var searched_label_text: String = "SEARCHED"

var required_item_override: String = ""
var required_item: String:
	get:
		return required_key_item.item_id if required_key_item != null else required_item_override
	set(value):
		required_item_override = value

var contents: Dictionary = {}
var generated: bool = false
var searched: bool = false
var searching: bool = false
var rng := RandomNumberGenerator.new()
@onready var visual: Node3D = %Visual
@onready var lid: MeshInstance3D = %Lid
@onready var status_label: Label3D = %ContainerLabel
@onready var open_marker: Marker3D = %OpenMarker

func _ready() -> void:
	add_to_group("interactable")
	rng.randomize()
	status_label.text = container_name

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and status_label != null:
		status_label.text = container_name

func set_preset_loot(items: Dictionary) -> void:
	contents = items.duplicate(true)
	generated = true

func get_interaction_text(_player: PlayerController) -> String:
	if starts_locked and required_item.is_empty():
		return "%s (locked)" % container_name
	if not required_item.is_empty() and int(GameState.raid_inventory.get(required_item, 0)) <= 0 and int(GameState.raid_secure.get(required_item, 0)) <= 0:
		return "%s (requires %s)" % [container_name, ItemDB.display_name(required_item)]
	if searching:
		return "Searching..."
	if contents.is_empty() and searched:
		return "%s (empty)" % container_name
	return "%s: %s" % [interaction_text, container_name]

func interact(_player: PlayerController) -> void:
	if searching:
		return
	if starts_locked and required_item.is_empty():
		status_label.text = "LOCKED"
		return
	if not required_item.is_empty() and int(GameState.raid_inventory.get(required_item, 0)) <= 0 and int(GameState.raid_secure.get(required_item, 0)) <= 0:
		status_label.text = "LOCKED — %s" % ItemDB.display_name(required_item)
		return
	if not generated:
		generate_loot()
	searching = true
	search_started.emit(self)
	status_label.text = "SEARCHING..."
	await get_tree().create_timer(search_duration).timeout
	if not is_inside_tree():
		return
	searching = false
	searched = true
	if opened_visual_state == "rotate_lid":
		lid.rotation.x = -0.75
		lid.position = open_marker.position
	elif opened_visual_state == "hide_lid":
		lid.visible = false
	status_label.text = searched_label_text if not contents.is_empty() else "EMPTY"
	search_completed.emit(self)
	var raid: Node = _raid_scene()
	if raid.has_method("show_loot"):
		raid.show_loot(self)

func generate_loot() -> void:
	generated = true
	if loot_table != null:
		contents = loot_table.roll(rng)
	if container_name.contains("Sealed Signal"):
		contents["signal_core"] = 1
	_apply_regional_bias()

func _apply_regional_bias() -> void:
	var region := GameState.current_raid_region()
	if region == null or rng.randf() > 0.72:
		return
	var favored: Dictionary = {
		"fire":["fireball_page", "ember_dart_page", "flame_burst_page", "cinder_mortar_page", "wildfire_orb_page", "emberstream_page", "magma_basin_page", "searing_wall_page", "smoke_nova_page", "meteor_crown_page", "fire_dagger", "ash_essence"],
		"water":["water_bolt_page", "ice_spear_page", "frost_shard_page", "lightning_arc_page", "tidal_volley_page", "freezing_spray_page", "drowning_puddle_page", "ice_wall_page", "chain_lightning_page", "water_barrier_page", "water_dagger", "mana_crystal"],
		"grass":["thorn_shot_page", "root_spike_page", "poison_spore_page", "seed_barrage_page", "vine_orb_page", "binding_roots_page", "briar_wall_page", "spore_bloom_page", "timber_lance_page", "verdant_mine_page", "grass_dagger", "cloth"],
		"neutral":["arcane_bolt_page", "healing_circle_page", "arcane_missile_page", "gilt_barrage_page", "gravity_orb_page", "blink_sigil_page", "mana_spring_page", "aegis_dome_page", "cleanse_pulse_page", "repulsion_wave_page", "neutral_dagger", "arcane_dust"]
	}
	var pool: Array = favored.get(region.primary_element, favored.neutral)
	var item_id: String = str(pool[rng.randi_range(0, pool.size() - 1)])
	contents[item_id] = int(contents.get(item_id, 0)) + 1

func take_item(item_id: String) -> bool:
	if int(contents.get(item_id, 0)) <= 0:
		return false
	if not GameState.add_raid_item(item_id, 1):
		return false
	contents[item_id] = int(contents[item_id]) - 1
	if int(contents[item_id]) <= 0:
		contents.erase(item_id)
	status_label.text = "EMPTY" if contents.is_empty() else "OPEN"
	item_taken.emit(item_id, 1)
	return true

func _raid_scene() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node is RaidScene:
			return node
		node = node.get_parent()
	return get_parent()
