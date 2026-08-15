class_name EnemyController
extends CharacterBody3D

enum State { IDLE, PATROL, SUSPICIOUS, INVESTIGATE, CHASE, REPOSITION, ATTACK, CAST, SEARCH, DEAD }

@export_category("Enemy Configuration")
@export var enemy_data: EnemyData
@export_enum("monster", "mage", "construct", "boss", "scavenger", "creature", "guard") var enemy_type: String = "monster"
@export_category("Patrol")
@export_range(0.0, 30.0, 0.5, "suffix:m") var patrol_radius: float = 5.0
@export_range(1.0, 20.0, 0.5, "suffix:s") var lost_target_timeout_seconds: float = 3.8

var state: State = State.IDLE
var health: float = 55.0
var max_health: float = 55.0
var move_speed: float = 2.6
var detection_range: float = 12.0
var attack_range: float = 9.0
var damage: float = 9.0
var hearing_range: float = 16.0
var attack_interval: float = 1.2
var attack_cooldown: float = 0.0
var state_time: float = 0.0
var lost_time: float = 0.0
var patrol_origin: Vector3
var target_position: Vector3
var last_known_position: Vector3
var player: PlayerController
var dead: bool = false
var dropped: bool = false
var fire_resistance: float = 0.0
var ice_resistance: float = 0.0
var burn_remaining: float = 0.0
var burn_damage_per_second: float = 0.0
var slow_remaining: float = 0.0
var slow_multiplier: float = 1.0
var water_vulnerable_remaining: float = 0.0
var water_vulnerability: float = 0.0
var poison_remaining: float = 0.0
var poison_damage_per_second: float = 0.0
var knockback_velocity: Vector3 = Vector3.ZERO
var primary_element: String = "neutral"
var elemental_resistance: float = 0.0
var last_weakness_triggered: bool = false
var aggroed: bool = false
var network_enemy_id := ""
var network_replica := false

@onready var visual: Node3D = %Visual
@onready var health_bar: Label3D = %HealthBar
@onready var navigation_agent: NavigationAgent3D = %NavigationAgent3D
@onready var cast_marker: Marker3D = %CastOrigin
@onready var cast_glow: MeshInstance3D = %CastGlow
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	rng.randomize()
	_configure_variant()
	if network_replica:
		return
	patrol_origin = global_position
	target_position = _random_patrol_point()
	state = State.PATROL
	call_deferred("_find_player")

func _configure_variant() -> void:
	if enemy_data != null:
		enemy_type = enemy_data.behavior_type
		health = enemy_data.maximum_health
		move_speed = enemy_data.movement_speed
		detection_range = enemy_data.detection_range_meters
		hearing_range = enemy_data.hearing_range_meters
		attack_range = enemy_data.attack_range_meters
		damage = enemy_data.attack_damage
		attack_interval = enemy_data.attack_interval_seconds
		primary_element = enemy_data.primary_element
		fire_resistance = enemy_data.fire_resistance
		ice_resistance = enemy_data.ice_resistance
		elemental_resistance = enemy_data.elemental_resistance
		max_health = health
		if enemy_type in ["monster", "creature"]:
			detection_range = maxf(detection_range, 16.0)
		return
	if enemy_type in ["monster", "creature"]:
		primary_element = "grass"
		health = 52.0
		move_speed = 4.3
		detection_range = 11.0
		attack_range = 1.55
		damage = 14.0
	else:
		health = 78.0
		move_speed = 2.75
		detection_range = 16.0
		attack_range = 12.5
		damage = 18.0
	max_health = health

func _find_player() -> void:
	var closest_player: PlayerController
	var closest_distance := INF
	var own_raid := _raid_scene()
	for candidate: Node in get_tree().get_nodes_in_group("player"):
		if not candidate is PlayerController:
			continue
		var candidate_player := candidate as PlayerController
		if candidate_player.dead or candidate_player._gameplay_area() != own_raid:
			continue
		var distance := global_position.distance_squared_to(candidate_player.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_player = candidate_player
	player = closest_player

func _physics_process(delta: float) -> void:
	if network_replica:
		return
	if dead:
		return
	_update_status(delta)
	if dead:
		return
	if player == null or not is_instance_valid(player):
		_find_player()
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	state_time += delta
	var distance: float = global_position.distance_to(player.global_position)
	var can_see: bool = _can_detect_player(distance)
	var melee_enemy: bool = enemy_type in ["monster", "creature"]
	if can_see:
		aggroed = true
		last_known_position = player.global_position
		lost_time = 0.0
		if melee_enemy:
			state = State.ATTACK if distance <= attack_range + 0.2 else State.CHASE
		elif enemy_type == "mage" and distance < attack_range * 0.46:
			state = State.REPOSITION
		elif distance <= attack_range:
			state = State.ATTACK
		else:
			state = State.CHASE
	elif melee_enemy and aggroed:
		# Once sighted, melee enemies keep tracing the live player position through
		# navigation so briefly breaking line of sight does not cancel pursuit.
		last_known_position = player.global_position
		lost_time = 0.0
		state = State.ATTACK if distance <= attack_range + 0.2 else State.CHASE
	elif state in [State.CHASE, State.REPOSITION, State.ATTACK, State.CAST]:
		lost_time += delta
		if lost_time > lost_target_timeout_seconds:
			state = State.SEARCH
			target_position = last_known_position
			state_time = 0.0
	_update_state(delta, distance)
	if knockback_velocity.length_squared() > 0.05:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, delta * 14.0)
	move_and_slide()

func _can_detect_player(distance: float) -> bool:
	var range_multiplier: float = 1.0
	if player.is_crouching:
		range_multiplier *= 0.58
	elif player.is_sprinting:
		range_multiplier *= 1.35
	var raid: Node = _raid_scene()
	if raid != null and raid.has_method("detection_multiplier"):
		range_multiplier *= float(raid.detection_multiplier())
	if distance > detection_range * range_multiplier:
		return false
	if raid != null and raid.has_method("has_clear_line"):
		return bool(raid.has_clear_line(global_position + Vector3.UP, player.global_position + Vector3.UP, [get_rid(), player.get_rid()]))
	return true

func _update_state(delta: float, distance: float) -> void:
	match state:
		State.PATROL:
			_move_toward_target(target_position, move_speed * 0.55)
			if global_position.distance_to(target_position) < 0.8 or state_time > 7.0:
				target_position = _random_patrol_point()
				state_time = 0.0
		State.SUSPICIOUS, State.INVESTIGATE:
			_move_toward_target(target_position, move_speed * 0.75)
			if global_position.distance_to(target_position) < 1.0 or state_time > 6.0:
				state = State.SEARCH
				state_time = 0.0
		State.CHASE:
			_move_toward_target(last_known_position, move_speed * slow_multiplier)
		State.REPOSITION:
			var retreat: Vector3 = global_position + (global_position - player.global_position).normalized() * 5.0
			_move_toward_target(retreat, move_speed * 1.12 * slow_multiplier)
			if distance >= attack_range * 0.62:
				state = State.ATTACK
		State.ATTACK:
			_face_target(player.global_position)
			velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
			velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
			if attack_cooldown <= 0.0:
				_attack(distance)
		State.SEARCH:
			_move_toward_target(target_position, move_speed * 0.5 * slow_multiplier)
			if state_time > 5.0:
				state = State.PATROL
				target_position = _random_patrol_point()
				state_time = 0.0
		_:
			velocity.x = move_toward(velocity.x, 0.0, delta * 5.0)
			velocity.z = move_toward(velocity.z, 0.0, delta * 5.0)

func _move_toward_target(target: Vector3, speed: float) -> void:
	navigation_agent.target_position = target
	var navigation_target: Vector3 = navigation_agent.get_next_path_position()
	var direction: Vector3 = navigation_target - global_position
	direction.y = 0.0
	# Navigation may return the current polygon point first. Compare on the
	# movement plane so an agent height offset cannot deadlock pursuit.
	if navigation_target.is_equal_approx(Vector3.ZERO) or direction.length_squared() < 0.01:
		direction = target - global_position
		direction.y = 0.0
	if direction.length_squared() < 0.0025:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	_face_target(target)

func _face_target(target: Vector3) -> void:
	var flat: Vector3 = target - global_position
	flat.y = 0.0
	if flat.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), 0.18)

func _attack(distance: float) -> void:
	if player.dead:
		return
	if enemy_type in ["monster", "creature"]:
		if distance <= attack_range + 0.35:
			var source_label := "enemy:%s#%s distance=%.2f range=%.2f" % [enemy_type, network_enemy_id if not network_enemy_id.is_empty() else str(get_instance_id()), distance, attack_range]
			player.take_damage(damage, global_position, 0.24, primary_element, source_label)
		attack_cooldown = attack_interval
		return
	var raid: Node = _raid_scene()
	if raid != null and raid.has_method("spawn_enemy_spell"):
		cast_glow.visible = true
		var spell: BaseSpellData = enemy_data.prepared_spell if enemy_data != null else ContentRegistry.spells().get("fireball") as BaseSpellData
		print("[ENEMY] cast enemy=%s magic=%s target=%d" % [network_enemy_id if not network_enemy_id.is_empty() else str(get_instance_id()), spell.spell_id if spell != null else "unknown", player.network_peer_id])
		raid.spawn_enemy_spell(self, spell, cast_marker.global_position, player.global_position, damage)
		if enemy_type == "boss" and raid.has_method("notify_spell_cast"):
			raid.notify_spell_cast(global_position, 34.0)
		get_tree().create_timer(0.16).timeout.connect(func() -> void: if is_instance_valid(cast_glow): cast_glow.visible = false)
	attack_cooldown = attack_interval

func hear_spell(position: Vector3, radius: float) -> void:
	if dead or global_position.distance_to(position) > minf(radius, hearing_range):
		return
	if state in [State.PATROL, State.IDLE, State.SEARCH]:
		state = State.INVESTIGATE
		target_position = position
		last_known_position = position
		state_time = 0.0

func take_damage(amount: float, source: Vector3 = Vector3.ZERO, _bleed_chance: float = 0.0, element: String = "physical") -> void:
	if dead:
		return
	var attack_element := ElementSystem.normalize_primary(element)
	var resistance: float = elemental_resistance
	if attack_element == "fire":
		resistance = maxf(resistance, fire_resistance)
	elif attack_element == "water":
		resistance = maxf(resistance, ice_resistance)
	var relationship := ElementSystem.multiplier(attack_element, primary_element)
	var final_damage := ElementSystem.damage_after_resistance(amount, attack_element, primary_element, resistance)
	if attack_element == "water" and water_vulnerable_remaining > 0.0:
		final_damage *= 1.0 + water_vulnerability
	last_weakness_triggered = relationship > 1.0
	health = maxf(0.0, health - final_damage)
	if last_weakness_triggered:
		var raid := _raid_scene()
		if raid != null and raid.has_method("show_message"):
			raid.show_message("WEAKNESS! %s defeats %s" % [attack_element.to_upper(), primary_element.to_upper()])
	health_bar.text = "%d / %d" % [int(ceil(health)), int(max_health)]
	health_bar.visible = true
	state = State.CHASE
	last_known_position = source
	lost_time = 0.0
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3(1.15, 0.86, 1.15), 0.05)
	tween.tween_property(visual, "scale", Vector3.ONE, 0.11)
	if health <= 0.0:
		_die()

func take_explosion_damage(amount: float, source: Vector3) -> void:
	if dead:
		return
	# Explosion's stated 500 damage is absolute: armor, elemental resistance,
	# and regional affinity do not reduce this cataclysmic hit.
	health = maxf(0.0, health - amount)
	health_bar.text = "%d / %d" % [int(ceil(health)), int(max_health)]
	health_bar.visible = true
	state = State.CHASE
	last_known_position = source
	if health <= 0.0:
		_die()

func apply_status(status_id: String, duration: float, power: float) -> void:
	if status_id == "burn":
		burn_remaining = maxf(burn_remaining, duration)
		burn_damage_per_second = maxf(burn_damage_per_second, power * (1.0 - fire_resistance))
	elif status_id == "slow":
		slow_remaining = maxf(slow_remaining, duration)
		slow_multiplier = clampf(1.0 - power * (1.0 - ice_resistance), 0.35, 1.0)
	elif status_id == "poison":
		poison_remaining = maxf(poison_remaining, duration)
		poison_damage_per_second = maxf(poison_damage_per_second, power)
	elif status_id == "water_vulnerable":
		water_vulnerable_remaining = maxf(water_vulnerable_remaining, duration)
		water_vulnerability = maxf(water_vulnerability, power)

func apply_knockback(force: Vector3) -> void:
	if enemy_type in ["monster", "creature"]:
		knockback_velocity += force


func configure_network_replica(enemy_id: String) -> void:
	network_enemy_id = enemy_id
	network_replica = true


func receive_network_snapshot(snapshot: Dictionary) -> void:
	if not network_replica:
		return
	var snapshot_position: Vector3 = snapshot.get("position", global_position)
	global_position = global_position.lerp(snapshot_position, 0.55)
	rotation.y = lerp_angle(rotation.y, float(snapshot.get("rotation_y", rotation.y)), 0.55)
	health = float(snapshot.get("health", health))
	dead = bool(snapshot.get("dead", dead))
	health_bar.text = "%d / %d" % [int(ceil(health)), int(max_health)]
	visible = not dead

func _update_status(delta: float) -> void:
	if burn_remaining > 0.0:
		burn_remaining -= delta
		health = maxf(0.0, health - burn_damage_per_second * delta)
		health_bar.text = "%d / %d" % [int(ceil(health)), int(max_health)]
		if health <= 0.0:
			_die()
	else:
		burn_damage_per_second = 0.0
	if slow_remaining > 0.0:
		slow_remaining -= delta
	else:
		slow_multiplier = 1.0
	if poison_remaining > 0.0:
		poison_remaining -= delta
		health = maxf(0.0, health - poison_damage_per_second * delta)
		health_bar.text = "%d / %d" % [int(ceil(health)), int(max_health)]
		if health <= 0.0:
			_die()
	else:
		poison_damage_per_second = 0.0
	if water_vulnerable_remaining > 0.0:
		water_vulnerable_remaining -= delta
	else:
		water_vulnerability = 0.0

func _die() -> void:
	if dead:
		return
	dead = true
	state = State.DEAD
	velocity = Vector3.ZERO
	remove_from_group("enemies")
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(visual, "rotation:z", 1.45, 0.35)
	tween.parallel().tween_property(visual, "scale", Vector3(1.0, 0.32, 1.0), 0.35)
	var raid: Node = _raid_scene()
	if not dropped and raid != null and raid.has_method("enemy_defeated"):
		dropped = true
		raid.enemy_defeated(enemy_type, global_position)

func _raid_scene() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node is RaidScene:
			return node
		node = node.get_parent()
	return null

func _random_patrol_point() -> Vector3:
	var angle: float = rng.randf_range(0.0, TAU)
	var distance: float = rng.randf_range(1.5, maxf(1.5, patrol_radius))
	return patrol_origin + Vector3(cos(angle), 0, sin(angle)) * distance
