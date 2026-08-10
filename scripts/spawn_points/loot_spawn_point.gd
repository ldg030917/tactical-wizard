@tool
class_name LootSpawnPoint
extends Marker3D

@export_category("Loot Spawn")
@export var spawn_id: String = "loot_spawn"
@export var loot_table: LootTableData
@export_range(0.0, 1.0, 0.01) var activation_chance: float = 0.75
@export var container_scene: PackedScene
@export var loose_loot_mode: bool = false
@export_range(1, 10, 1) var minimum_item_count: int = 1
@export_range(1, 12, 1) var maximum_item_count: int = 4
@export_range(0.1, 5.0, 0.1) var rare_loot_multiplier: float = 1.0
@export_category("Editor Visualization")
@export var show_debug_visual: bool = true
@export var show_debug_in_game: bool = false

func _ready() -> void:
	if not Engine.is_editor_hint():
		$DebugVisual.visible = show_debug_in_game
		$SpawnLabel.visible = show_debug_in_game

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	var visual := get_node_or_null("DebugVisual") as Node3D
	var label := get_node_or_null("SpawnLabel") as Label3D
	if visual != null:
		visual.visible = show_debug_visual
	if label != null:
		label.visible = show_debug_visual
		label.text = "LOOT SPAWN\n%s" % spawn_id

func spawn_loot(parent: Node3D, rng: RandomNumberGenerator) -> LootContainer:
	if container_scene == null or rng.randf() > activation_chance:
		return null
	var container := container_scene.instantiate() as LootContainer
	if container == null:
		return null
	container.container_id = spawn_id
	container.container_name = "Loose Field Cache" if loose_loot_mode else "Randomized Field Container"
	container.loot_table = loot_table
	container.activation_chance = 1.0
	container.minimum_items = minimum_item_count
	container.maximum_items = maximum_item_count
	parent.add_child(container)
	container.global_position = global_position
	return container
