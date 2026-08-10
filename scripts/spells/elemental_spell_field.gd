class_name ElementalSpellField
extends Area3D

var caster: PlayerController
var config: RuntimeSpellConfig
var elapsed: float = 0.0
var tick_remaining: float = 0.0
var detonated: bool = false

@onready var collision_shape: CollisionShape3D = %CollisionShape3D
@onready var field_mesh: MeshInstance3D = %FieldMesh
@onready var rune_ring: MeshInstance3D = %RuneRing

func configure(owner_node: PlayerController, spell_config: RuntimeSpellConfig) -> void:
	caster = owner_node
	config = spell_config
	if is_node_ready():
		_apply_configuration()

func _ready() -> void:
	if config != null:
		_apply_configuration()

func _apply_configuration() -> void:
	var radius: float = maxf(0.8, config.area_radius)
	(collision_shape.shape as SphereShape3D).radius = radius
	var cylinder := field_mesh.mesh as CylinderMesh
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.08
	field_mesh.material_override = VisualFactory.elemental_spell_material(config.base_spell.primary_element, config.base_spell.debug_color, 2.7, 1.0)
	rune_ring.material_override = VisualFactory.elemental_spell_material(config.base_spell.primary_element, config.base_spell.debug_color, 3.5, 5.0)
	rune_ring.scale = Vector3.ONE * radius
	if config.behavior_type in ["wall", "barrier"]:
		_build_wall(radius)
		collision_shape.disabled = true
	if config.behavior_type == "mine":
		field_mesh.scale = Vector3.ONE * 0.42
		rune_ring.scale = Vector3.ONE * minf(radius, 1.1)

func _physics_process(delta: float) -> void:
	if config == null:
		return
	elapsed += delta
	tick_remaining -= delta
	rune_ring.rotation.y += delta * 1.8
	rune_ring.scale.y = 1.0 + sin(elapsed * 4.0) * 0.08
	if tick_remaining <= 0.0:
		tick_remaining = 0.45
		_apply_tick()
	if elapsed >= maxf(0.8, config.effect_duration):
		queue_free()

func _apply_tick() -> void:
	if config.behavior_type in ["wall", "barrier"]:
		return
	for target: Node in get_tree().get_nodes_in_group("enemies"):
		if not target is Node3D:
			continue
		var offset: Vector3 = (target as Node3D).global_position - global_position
		offset.y = 0.0
		if offset.length() > config.area_radius:
			continue
		if config.behavior_type == "mine":
			if not detonated:
				detonated = true
				_damage_target(target, config.damage_or_healing)
				var raid: Node = _raid_scene()
				if raid != null:
					raid.spawn_spell_impact(global_position, config.base_spell.debug_color, config.area_radius, config.base_spell.primary_element, 9.0)
				queue_free()
			return
		_damage_target(target, config.damage_or_healing * 0.18)
		match config.behavior_type:
			"damage_zone": target.apply_status("burn", 1.0, maxf(2.0, config.effect_power))
			"slow_zone": target.apply_status("slow", 0.9, maxf(0.35, config.effect_power))
			"root_field": target.apply_status("slow", 1.0, maxf(0.55, config.effect_power))
			"puddle":
				target.apply_status("slow", 1.0, 0.5)
				target.apply_status("water_vulnerable", 1.2, maxf(0.25, config.effect_power))

func _damage_target(target: Node, amount: float) -> void:
	if target.has_method("take_damage"):
		target.take_damage(amount, global_position, 0.0, config.base_spell.primary_element)

func _build_wall(radius: float) -> void:
	var wall := StaticBody3D.new()
	wall.name = "SpellWallCollision"
	wall.collision_layer = 1
	wall.collision_mask = 0
	add_child(wall)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(radius * 2.0, 2.2, 0.55)
	shape_node.shape = shape
	shape_node.position.y = 1.05
	wall.add_child(shape_node)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	mesh.material = VisualFactory.elemental_spell_material(config.base_spell.primary_element, config.base_spell.debug_color, 2.2, 7.0)
	mesh_node.mesh = mesh
	mesh_node.position.y = 1.05
	wall.add_child(mesh_node)
	field_mesh.visible = false

func _raid_scene() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node is RaidScene or node is BaseScene:
			return node
		node = node.get_parent()
	return null
