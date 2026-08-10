@tool
class_name PlayerSpawnPoint
extends Marker3D

@export_category("Spawn Identity")
@export var spawn_id: String = "default"
@export var is_default_spawn: bool = true
@export_enum("base", "raid", "return") var spawn_role: String = "raid"
@export var facing_direction_degrees: float = 0.0
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
		visual.rotation_degrees.y = facing_direction_degrees
	if label != null:
		label.visible = show_debug_visual
		label.text = "PLAYER SPAWN\n%s (%s)" % [spawn_id, spawn_role]
