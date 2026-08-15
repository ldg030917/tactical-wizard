class_name SpellProjectile
extends Area3D

signal projectile_resolved(magic_id: String, reason: String)

@export_category("Projectile Defaults")
@export_range(1.0, 50.0, 0.5, "suffix:m/s") var default_speed: float = 14.0
@export_range(0.1, 10.0, 0.1, "suffix:s") var maximum_lifetime_seconds: float = 4.0
@export_range(0.0, 5.0, 0.1, "suffix:m") var curved_arc_height: float = 2.2
@export_range(1.0, 12.0, 0.25, "suffix:m") var high_lob_arc_height: float = 6.5

@onready var visual: Node3D = %Visual
@onready var spell_mesh: MeshInstance3D = %SpellMesh
@onready var trail: GPUParticles3D = %Trail
@onready var orbit_ring_a: MeshInstance3D = %OrbitRingA
@onready var orbit_ring_b: MeshInstance3D = %OrbitRingB
@onready var spell_light: OmniLight3D = %Light

var caster: Node3D
var config: RuntimeSpellConfig
var direction: Vector3 = Vector3.FORWARD
var source_team: String = "player"
var speed: float = 14.0
var lifetime: float = 0.0
var travelled: float = 0.0
var start_y: float = 0.0
var resolved: bool = false
var start_position: Vector3 = Vector3.ZERO
var destination: Vector3 = Vector3.ZERO
var path_length: float = 1.0
var vfx_time: float = 0.0
var vfx_seed: float = 0.0
var base_visual_size: float = 1.0
var primary_element: String = "neutral"
var pierce_remaining: int = 0
var ricochet_remaining: int = 0
var pivot_completed: bool = false
var hit_target_ids: Dictionary = {}
var network_magic_id := ""
var network_visual_replica := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if config == null:
		return
	_apply_presentation()

func configure(owner_node: Node3D, spell_config: RuntimeSpellConfig, travel_direction: Vector3, team: String, target_position: Vector3 = Vector3.ZERO) -> void:
	caster = owner_node
	config = spell_config
	direction = travel_direction.normalized()
	source_team = team
	speed = config.projectile_speed if config != null else default_speed
	collision_layer = 8
	collision_mask = 1 | (4 if source_team == "player" else 2)
	start_y = global_position.y
	start_position = global_position
	destination = target_position
	if destination.is_equal_approx(Vector3.ZERO):
		destination = start_position + direction * config.range_meters
	path_length = maxf(0.1, start_position.distance_to(destination))
	pierce_remaining = config.pierce_count
	ricochet_remaining = config.ricochet_count
	if is_node_ready():
		_apply_presentation()


func configure_network_visual(magic_id: String, spell_config: RuntimeSpellConfig, travel_direction: Vector3, team: String, target_position: Vector3) -> void:
	network_magic_id = magic_id
	network_visual_replica = true
	configure(null, spell_config, travel_direction, team, target_position)
	monitoring = false
	monitorable = false

func _physics_process(delta: float) -> void:
	if resolved or config == null:
		return
	lifetime += delta
	var step: float = speed * delta
	if "tracking" in config.behavior_tags:
		var tracked: Node3D = _nearest_unhit_enemy(destination, 6.0)
		if tracked != null:
			destination = destination.lerp(tracked.global_position + Vector3(0, start_y - tracked.global_position.y, 0), minf(1.0, delta * 5.5))
			direction = (destination - global_position).normalized()
	travelled += step
	var progress: float = clampf(travelled / path_length, 0.0, 1.0)
	match config.trajectory:
		"left_turn", "right_turn":
			var side: float = -1.0 if config.trajectory == "left_turn" else 1.0
			var lateral := direction.cross(Vector3.UP).normalized() * side
			var control := start_position + direction * path_length * 0.46 + lateral * minf(5.0, path_length * 0.38)
			global_position = _quadratic_bezier(start_position, control, destination, progress)
		"high_lob":
			global_position = start_position.lerp(destination, progress)
			global_position.y = start_y + sin(progress * PI) * high_lob_arc_height
		_:
			global_position = start_position.lerp(destination, progress)
	_animate_visual(delta, progress)
	if progress >= 1.0 and not pivot_completed and ("turn_left_at_target" in config.behavior_tags or "turn_right_at_target" in config.behavior_tags):
		pivot_completed = true
		var turn_sign: float = -1.0 if "turn_left_at_target" in config.behavior_tags else 1.0
		direction = direction.rotated(Vector3.UP, turn_sign * PI * 0.5).normalized()
		start_position = global_position
		destination = start_position + direction * maxf(4.0, config.range_meters * 0.65)
		path_length = start_position.distance_to(destination)
		travelled = 0.0
		return
	if lifetime >= maximum_lifetime_seconds or progress >= 1.0 or travelled >= config.range_meters:
		_resolve_impact(global_position)

func _quadratic_bezier(a: Vector3, control: Vector3, b: Vector3, t: float) -> Vector3:
	var inverse := 1.0 - t
	return inverse * inverse * a + 2.0 * inverse * t * control + t * t * b

func _on_body_entered(body: Node3D) -> void:
	if network_visual_replica or resolved or body == caster:
		return
	if source_team == "player" and body.is_in_group("enemies"):
		if hit_target_ids.has(body.get_instance_id()):
			return
		if pierce_remaining > 0:
			hit_target_ids[body.get_instance_id()] = true
			_apply_spell_to_target(body)
			pierce_remaining -= 1
		else:
			_resolve_impact(body.global_position, body)
	elif source_team == "enemy" and body.is_in_group("player"):
		_resolve_impact(body.global_position, body)
	elif body.collision_layer & 1:
		if "phase_walls" in config.behavior_tags:
			return
		if ricochet_remaining > 0:
			ricochet_remaining -= 1
			_redirect_after_ricochet()
		else:
			_resolve_impact(global_position)

func _resolve_impact(at: Vector3, direct_target: Node = null) -> void:
	if resolved:
		return
	resolved = true
	set_deferred("monitoring", false)
	visible = false
	if network_visual_replica:
		projectile_resolved.emit(network_magic_id, "visual_complete")
		queue_free()
		return
	var targets: Array[Node] = get_tree().get_nodes_in_group("enemies") if source_team == "player" else get_tree().get_nodes_in_group("player")
	for target: Node in targets:
		if not target is Node3D or not target.has_method("take_damage"):
			continue
		var target_offset: Vector3 = (target as Node3D).global_position - at
		target_offset.y = 0.0
		var distance: float = target_offset.length()
		if target != direct_target and distance > config.area_radius:
			continue
		_apply_spell_to_target(target)
		if "gravity_pull" in config.behavior_tags and target.has_method("apply_knockback"):
			var pull: Vector3 = at - (target as Node3D).global_position
			pull.y = 0.0
			target.apply_knockback(pull.normalized() * 7.0)
	var raid: Node = _raid_scene()
	if raid != null and raid.has_method("spawn_spell_impact"):
		raid.spawn_spell_impact(at, config.base_spell.debug_color, maxf(0.35, config.area_radius), primary_element, vfx_seed)
	if "delayed_echo" in config.behavior_tags and raid != null and raid.has_method("schedule_spell_echo"):
		raid.schedule_spell_echo(config, at)
	projectile_resolved.emit(network_magic_id, "impact")
	queue_free()


func receive_network_snapshot(snapshot: Dictionary) -> void:
	if not network_visual_replica or resolved:
		return
	var authoritative_position: Vector3 = snapshot.get("position", global_position)
	global_position = global_position.lerp(authoritative_position, 0.65)

func _apply_spell_to_target(target: Node) -> void:
	if not target.has_method("take_damage"):
		return
	var target_name := target.name
	if target is PlayerController:
		var source_label := "magic:%s" % network_magic_id if not network_magic_id.is_empty() else "magic:untracked"
		(target as PlayerController).take_damage(config.damage_or_healing, global_position, 0.0, config.base_spell.primary_element, source_label)
	else:
		target.take_damage(config.damage_or_healing, global_position, 0.0, config.base_spell.primary_element)
	if not network_magic_id.is_empty():
		print("[PROJECTILE] hit id=%s target=%s projectile_instance=%d" % [network_magic_id, target_name, get_instance_id()])
	if config.status_effect == "burn" and target.has_method("apply_status"):
		target.apply_status("burn", maxf(config.effect_duration, config.base_spell.effect_duration_seconds), maxf(config.effect_power, config.base_spell.effect_power))
	elif config.status_effect in ["slow", "chill"] and target.has_method("apply_status"):
		target.apply_status("slow", maxf(config.effect_duration, config.base_spell.effect_duration_seconds), maxf(config.effect_power, config.base_spell.effect_power))
	elif config.status_effect == "poison" and target.has_method("apply_status"):
		target.apply_status("poison", maxf(config.effect_duration, config.base_spell.effect_duration_seconds), maxf(config.effect_power, config.base_spell.effect_power))

func _redirect_after_ricochet() -> void:
	var next_target: Node3D = _nearest_unhit_enemy(global_position, 11.0)
	if next_target != null:
		direction = (next_target.global_position - global_position).normalized()
	else:
		direction = direction.rotated(Vector3.UP, PI * (0.62 if ricochet_remaining % 2 == 0 else -0.62)).normalized()
	start_position = global_position
	destination = start_position + direction * maxf(4.0, config.range_meters * 0.55)
	start_y = global_position.y
	path_length = start_position.distance_to(destination)
	travelled = 0.0

func _nearest_unhit_enemy(around: Vector3, radius: float) -> Node3D:
	var best: Node3D
	var best_distance: float = radius
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if not node is Node3D or hit_target_ids.has(node.get_instance_id()):
			continue
		var distance: float = (node as Node3D).global_position.distance_to(around)
		if distance < best_distance:
			best = node as Node3D
			best_distance = distance
	return best

func _apply_presentation() -> void:
	if config == null or config.base_spell == null or spell_mesh == null:
		return
	primary_element = ElementSystem.normalize_primary(config.base_spell.primary_element)
	vfx_seed = float(posmod(config.base_spell.spell_id.hash(), 1000)) / 67.0
	base_visual_size = 0.65 + config.area_radius * 0.22 + minf(0.24, config.damage_or_healing / 220.0)
	_configure_family_mesh(config.base_spell.spell_family)
	spell_mesh.material_override = VisualFactory.elemental_spell_material(primary_element, config.base_spell.debug_color, 4.2, vfx_seed)
	orbit_ring_a.material_override = VisualFactory.elemental_spell_material(primary_element, config.base_spell.debug_color, 3.2, vfx_seed + 2.0)
	orbit_ring_b.material_override = VisualFactory.elemental_spell_material(primary_element, config.base_spell.debug_color, 2.7, vfx_seed + 4.0)
	var trail_mesh := trail.draw_pass_1.duplicate() as PrimitiveMesh
	trail_mesh.material = VisualFactory.elemental_spell_material(primary_element, config.base_spell.debug_color, 3.6, vfx_seed + 6.0)
	trail.draw_pass_1 = trail_mesh
	var trail_process := trail.process_material.duplicate() as ParticleProcessMaterial
	trail_process.color = VisualFactory.spell_accent_color(primary_element)
	trail_process.initial_velocity_min = 0.35
	trail_process.initial_velocity_max = 1.3
	trail_process.gravity = Vector3(0, 0.9, 0) if primary_element == "fire" else Vector3(0, -0.25, 0) if primary_element == "water" else Vector3(0, 0.25, 0) if primary_element == "grass" else Vector3.ZERO
	trail.process_material = trail_process
	trail.amount = 42 if primary_element == "fire" else 36 if primary_element == "water" else 34
	trail.lifetime = 0.7 if primary_element in ["fire", "grass"] else 0.58
	trail.emitting = true
	spell_light.light_color = VisualFactory.spell_core_color(primary_element)
	spell_light.light_energy = 2.2 + minf(1.8, config.damage_or_healing / 35.0)
	spell_light.omni_range = 2.8 + config.area_radius * 0.75
	_animate_visual(0.0, 0.0)

func _configure_family_mesh(family: String) -> void:
	spell_mesh.rotation = Vector3.ZERO
	match family:
		"ice", "thorn", "wood":
			var lance := CylinderMesh.new()
			lance.top_radius = 0.035
			lance.bottom_radius = 0.22
			lance.height = 1.05
			lance.radial_segments = 7
			spell_mesh.mesh = lance
			spell_mesh.rotation_degrees.x = 90.0
			base_visual_size *= 0.9
		"lightning", "force":
			var shard := BoxMesh.new()
			shard.size = Vector3(0.16, 0.16, 1.25)
			spell_mesh.mesh = shard
			base_visual_size *= 0.82
		"vine", "root":
			var seed := SphereMesh.new()
			seed.radius = 0.3
			seed.height = 0.42
			seed.radial_segments = 8
			seed.rings = 4
			spell_mesh.mesh = seed
			spell_mesh.scale = Vector3(0.72, 1.15, 0.72)
		"arcane", "space", "ward":
			var sigil := TorusMesh.new()
			sigil.inner_radius = 0.12
			sigil.outer_radius = 0.34
			sigil.rings = 18
			sigil.ring_segments = 8
			spell_mesh.mesh = sigil
			spell_mesh.rotation_degrees.x = 90.0
		"poison", "spore", "seed":
			var pod := SphereMesh.new()
			pod.radius = 0.31
			pod.height = 0.62
			pod.radial_segments = 7
			pod.rings = 5
			spell_mesh.mesh = pod
		"water":
			var droplet := SphereMesh.new()
			droplet.radius = 0.25
			droplet.height = 0.72
			droplet.radial_segments = 12
			droplet.rings = 6
			spell_mesh.mesh = droplet
			spell_mesh.rotation_degrees.x = 90.0
		_:
			var orb := SphereMesh.new()
			orb.radius = 0.28
			orb.height = 0.56
			orb.radial_segments = 12
			orb.rings = 7
			spell_mesh.mesh = orb

func _animate_visual(delta: float, progress: float) -> void:
	if config == null or spell_mesh == null:
		return
	vfx_time += delta
	var pulse: float = 1.0 + sin(vfx_time * (10.0 if primary_element == "fire" else 6.0) + vfx_seed) * 0.1
	spell_mesh.scale = Vector3.ONE * base_visual_size * pulse
	orbit_ring_a.scale = Vector3.ONE * base_visual_size * (1.15 + sin(vfx_time * 7.0 + vfx_seed) * 0.12)
	orbit_ring_b.scale = Vector3.ONE * base_visual_size * (1.35 + cos(vfx_time * 5.0 + vfx_seed) * 0.1)
	orbit_ring_a.rotation.y += delta * (7.0 if primary_element == "fire" else 4.5)
	orbit_ring_b.rotation.x += delta * 3.2
	orbit_ring_b.rotation.z -= delta * (5.5 if primary_element in ["water", "neutral"] else 3.8)
	match primary_element:
		"fire":
			visual.position.y = sin(vfx_time * 13.0 + vfx_seed) * 0.055
			visual.scale = Vector3(0.9, 1.0 + sin(vfx_time * 11.0) * 0.18, 0.9)
		"water":
			visual.position.y = sin(vfx_time * 5.0 + progress * TAU) * 0.08
			visual.rotation.z += delta * 2.8
		"grass":
			visual.position.y = sin(vfx_time * 4.0) * 0.045
			visual.rotation.y += delta * 4.2
		"neutral":
			visual.position.y = sin(vfx_time * 6.0 + vfx_seed) * 0.035
			visual.rotation.y += delta * 2.4
	match config.base_spell.spell_family:
		"lightning":
			visual.position.x = sin(vfx_time * 38.0 + vfx_seed) * 0.07
			visual.rotation.z += delta * 15.0
		"ice", "thorn", "wood":
			visual.rotation.z = sin(vfx_time * 4.0 + vfx_seed) * 0.12
		"vine", "root", "seed", "spore", "poison":
			visual.rotation.z += delta * 5.5
			visual.position.x = sin(vfx_time * 7.0 + progress * TAU) * 0.04
		"arcane", "space":
			spell_mesh.rotation.y += delta * 8.0
	spell_light.light_energy = 3.0 + sin(vfx_time * 9.0 + vfx_seed) * 0.8

func _raid_scene() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node is RaidScene or node is BaseScene:
			return node
		node = node.get_parent()
	return null
