@tool
class_name EnemySpawnPoint
extends Marker3D

@export_category("Spawn Identity")
@export var spawn_id: String = "enemy_spawn"
@export var allowed_enemy_scenes: Array[PackedScene] = []
@export var allowed_enemy_resources: Array[EnemyData] = []

@export_category("Spawn Rules")
@export_range(0.0, 1.0, 0.01) var spawn_chance: float = 0.85
@export_range(1, 5, 1) var minimum_count: int = 1
@export_range(1, 5, 1) var maximum_count: int = 1
@export_range(0.0, 30.0, 0.5, "suffix:m") var patrol_radius: float = 5.0
@export var guards_high_value_area: bool = false
@export var respawn_enabled: bool = false
@export_range(1.0, 300.0, 1.0, "suffix:s") var respawn_delay_seconds: float = 60.0
@export_range(1, 5, 1) var difficulty_tier: int = 1

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
		visual.scale = Vector3(maxf(0.2, patrol_radius / 5.0), 1.0, maxf(0.2, patrol_radius / 5.0))
	if label != null:
		label.visible = show_debug_visual
		label.text = "ENEMY SPAWN\n%s • Tier %d" % [spawn_id, difficulty_tier]

func spawn_enemies(parent: Node3D, rng: RandomNumberGenerator) -> Array[EnemyController]:
	var spawned: Array[EnemyController] = []
	if allowed_enemy_scenes.is_empty() or rng.randf() > spawn_chance:
		return spawned
	var count: int = rng.randi_range(minimum_count, maxi(minimum_count, maximum_count))
	for index: int in range(count):
		var selection: int = rng.randi_range(0, allowed_enemy_scenes.size() - 1)
		var scene: PackedScene = allowed_enemy_scenes[selection]
		var enemy := scene.instantiate() as EnemyController
		if enemy == null:
			continue
		if selection < allowed_enemy_resources.size() and allowed_enemy_resources[selection] != null:
			enemy.enemy_data = allowed_enemy_resources[selection]
		enemy.patrol_radius = patrol_radius
		var spawn_position: Vector3 = global_position + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
		enemy.position = parent.to_local(spawn_position)
		parent.add_child(enemy)
		spawned.append(enemy)
	return spawned
