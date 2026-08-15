class_name PlayerController
extends CharacterBody3D

signal health_changed
signal mana_changed
signal died
signal spell_cast(position: Vector3, noise_radius: float, spell_id: String)
signal active_element_changed(primary_element: String)
signal injury_changed(body_part: String, severity: float)

@export var in_raid: bool = true

## Set by the authoritative world before the node enters the scene tree.
var network_enabled := false
var network_peer_id := 1
var _network_move_input := Vector2.ZERO
var _network_sprint := false
var _network_crouch := false
var _network_focus := false
var _network_rotation_y := 0.0
var _network_send_elapsed := 0.0
var _snapshot_buffer: Array[Dictionary] = []

@export_category("Movement")
@export_range(0.1, 20.0, 0.1, "suffix:m/s") var base_move_speed: float = 5.2
@export_range(1.0, 3.0, 0.05) var sprint_speed_multiplier: float = 1.55
@export_range(0.1, 1.0, 0.05) var crouch_speed_multiplier: float = 0.48
@export_range(1.0, 100.0, 1.0, "suffix:stamina/s") var sprint_stamina_cost: float = 24.0

@export_category("Vitals")
@export_range(10.0, 300.0, 1.0) var base_max_health: float = 100.0
@export_range(10.0, 300.0, 1.0) var base_max_mana: float = 120.0
@export_range(0.1, 50.0, 0.1, "suffix:mana/s") var base_mana_regeneration: float = 12.0
@export_range(0.0, 10.0, 0.1, "suffix:s") var mana_regeneration_delay_seconds: float = 1.8
@export_range(10.0, 300.0, 1.0) var base_max_stamina: float = 100.0

@export_category("Dagger Combat")
@export_range(0.0, 2.0, 0.05, "suffix:s") var dagger_windup_seconds: float = 0.12
@export_range(0.0, 1.0, 0.01) var base_injury_chance: float = 0.14

@export_category("Camera and Aim")
@export_range(5.0, 30.0, 0.5, "suffix:m") var camera_height: float = 15.0
@export_range(2.0, 25.0, 0.5, "suffix:m") var camera_distance: float = 11.0
@export_range(0.0, 1.0, 0.05) var aim_look_ahead: float = 0.28

@export_category("Scene Node References")
@export_node_path("Node3D") var visual_root_path: NodePath = ^"Visual"
@export_node_path("Node3D") var wand_socket_path: NodePath = ^"WandSocket"
@export_node_path("Node3D") var spellbook_socket_path: NodePath = ^"SpellbookSocket"
@export_node_path("Marker3D") var cast_origin_path: NodePath = ^"WandSocket/CastOrigin"
@export_node_path("MeshInstance3D") var cast_glow_path: NodePath = ^"WandSocket/CastGlow"
@export_node_path("MeshInstance3D") var placement_preview_path: NodePath = ^"PlacementPreview"
@export_node_path("MeshInstance3D") var trajectory_preview_path: NodePath = ^"TrajectoryPreview"
@export_node_path("Camera3D") var camera_path: NodePath = ^"CameraRig/TopDownCamera"

var max_health: float = 100.0
var health: float = 100.0
var max_mana: float = 120.0
var mana: float = 120.0
var ward: float = 0.0
var mana_regeneration: float = 12.0
var max_stamina: float = 100.0
var stamina: float = 100.0
var armor: float = 0.0
var fire_resistance: float = 0.0
var ice_resistance: float = 0.0
var elemental_resistances: Dictionary = {"fire":0.0, "water":0.0, "grass":0.0, "neutral":0.0}
var bleeding: bool = false
var bleed_tick: float = 0.0
var selected_page: int = 0
var active_combat_slot: int = 0
var page_configs: Array[RuntimeSpellConfig] = []
var page_cooldowns: Array[float] = [0.0, 0.0, 0.0]
var casting: bool = false
var cast_elapsed: float = 0.0
var cast_duration: float = 0.0
var cast_target: Vector3 = Vector3.ZERO
var mana_regen_delay: float = 0.0
var dagger_cooldown: float = 0.0
var aim_point: Vector3 = Vector3.ZERO
var is_focused: bool = false
var is_sprinting: bool = false
var is_crouching: bool = false
var dead: bool = false
var last_damage_time: float = -100.0
var nearby_interaction: String = ""
var active_healing_circle: HealingCircle
var burn_remaining: float = 0.0
var burn_damage_per_second: float = 0.0
var slow_remaining: float = 0.0
var slow_multiplier: float = 1.0
var poison_remaining: float = 0.0
var poison_damage_per_second: float = 0.0
var exhaustion_remaining: float = 0.0
var walk_time: float = 0.0
var recoil_amount: float = 0.0
var injuries: Dictionary = {"head":0.0, "torso":0.0, "left_arm":0.0, "right_arm":0.0, "left_leg":0.0, "right_leg":0.0}
var last_element_feedback: String = ""

@onready var visual: Node3D = get_node(visual_root_path) as Node3D
@onready var wand_socket: Node3D = get_node(wand_socket_path) as Node3D
@onready var spellbook_socket: Node3D = get_node(spellbook_socket_path) as Node3D
@onready var cast_origin: Marker3D = get_node(cast_origin_path) as Marker3D
@onready var cast_glow: MeshInstance3D = get_node(cast_glow_path) as MeshInstance3D
@onready var placement_preview: MeshInstance3D = get_node(placement_preview_path) as MeshInstance3D
@onready var trajectory_preview: MeshInstance3D = get_node(trajectory_preview_path) as MeshInstance3D
@onready var camera: Camera3D = get_node(camera_path) as Camera3D
var wand_socket_base_position: Vector3
var cast_vfx_seed: float = 0.0

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4
	max_health = base_max_health + GameState.skill_bonus("health")
	max_mana = base_max_mana
	max_stamina = base_max_stamina + GameState.skill_bonus("stamina")
	var character := GameState.selected_character()
	if character != null:
		max_health *= character.health_multiplier
		max_mana *= character.mana_multiplier
		max_stamina *= character.stamina_multiplier
		base_move_speed *= character.movement_multiplier
		base_mana_regeneration *= character.mana_regeneration_multiplier
	health = max_health
	mana = max_mana
	stamina = max_stamina
	mana_regeneration = base_mana_regeneration
	_configure_equipment_stats()
	_rebuild_spell_pages()
	if not GameState.spellbook_changed.is_connected(_rebuild_spell_pages):
		GameState.spellbook_changed.connect(_rebuild_spell_pages)
	wand_socket_base_position = wand_socket.position
	camera.top_level = true
	camera.current = true
	camera.global_position = global_position + Vector3(0, camera_height, camera_distance)
	camera.look_at(global_position + Vector3(0, 0.5, 0))
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if network_enabled:
		set_multiplayer_authority(network_peer_id)
		_configure_network_presentation()


func configure_network(peer_id: int) -> void:
	network_enabled = true
	network_peer_id = peer_id


func is_local_network_player() -> bool:
	return network_enabled and not multiplayer.is_server() and network_peer_id == multiplayer.get_unique_id()


func _configure_network_presentation() -> void:
	if multiplayer.is_server() or not is_local_network_player():
		camera.current = false
		placement_preview.visible = false
		trajectory_preview.visible = false
	if multiplayer.is_server():
		visual.visible = false

func _physics_process(delta: float) -> void:
	if network_enabled:
		_network_physics_process(delta)
		return
	if dead:
		velocity = velocity.move_toward(Vector3.ZERO, delta * 8.0)
		move_and_slide()
		return
	_update_aim()
	_update_movement(delta)
	_update_camera(delta)
	_update_casting(delta)
	_update_status(delta)
	_update_interaction()
	_update_visuals(delta)

func _unhandled_input(event: InputEvent) -> void:
	if network_enabled:
		_handle_network_input(event)
		return
	if dead:
		return
	if event.is_action_pressed("spell_page_1"):
		select_spell_page(0)
	elif event.is_action_pressed("spell_page_2"):
		select_spell_page(1)
	elif event.is_action_pressed("spell_page_3"):
		select_spell_page(2)
	elif event.is_action_pressed("dagger_slot"):
		select_combat_slot(3)
	elif event.is_action_pressed("cast_spell"):
		if active_combat_slot == 3:
			if in_raid:
				dagger_attack()
		else:
			begin_cast()
	elif event.is_action_pressed("cancel_cast") and casting:
		cancel_cast()
	elif event.is_action_pressed("dagger_attack") and in_raid:
		dagger_attack()
	elif (event.is_action_pressed("heal") or event.is_action_pressed("quick_item_1")) and in_raid:
		quick_heal()
	elif event.is_action_pressed("quick_item_2") and in_raid:
		use_mana_consumable()
	elif event.is_action_pressed("inventory") and in_raid:
		var raid: Node = _gameplay_area()
		if raid.has_method("toggle_inventory"):
			raid.toggle_inventory()
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("pause_game"):
		var root: Node = get_tree().current_scene
		if root.has_method("toggle_pause"):
			root.toggle_pause()


func _network_physics_process(delta: float) -> void:
	if multiplayer.is_server():
		rotation.y = _network_rotation_y
		if dead:
			velocity = velocity.move_toward(Vector3.ZERO, delta * 8.0)
			move_and_slide()
			return
		_apply_movement_input(_network_move_input, _network_sprint, _network_crouch, _network_focus, delta)
		_update_status(delta)
		return
	if is_local_network_player():
		if dead:
			return
		_update_aim()
		_update_movement(delta) # local prediction; server snapshots reconcile it.
		_update_camera(delta)
		_update_visuals(delta)
		_network_send_elapsed += delta
		if _network_send_elapsed >= 1.0 / 30.0:
			_network_send_elapsed = 0.0
			submit_movement_input.rpc_id(1, Input.get_vector("move_left", "move_right", "move_up", "move_down"), rotation.y, Input.is_action_pressed("sprint"), Input.is_action_pressed("crouch"), Input.is_action_pressed("cancel_cast"))
		return
	_apply_remote_snapshot(delta)
	_update_visuals(delta)


func _handle_network_input(event: InputEvent) -> void:
	if dead or not is_local_network_player():
		return
	if event.is_action_pressed("spell_page_1"):
		select_spell_page(0)
	elif event.is_action_pressed("spell_page_2"):
		select_spell_page(1)
	elif event.is_action_pressed("spell_page_3"):
		select_spell_page(2)
	elif event.is_action_pressed("dagger_slot"):
		select_combat_slot(3)
	elif event.is_action_pressed("cast_spell"):
		if active_combat_slot == 3:
			request_dagger_attack.rpc_id(1)
		else:
			request_spell_cast.rpc_id(1, selected_page, aim_point)
	elif event.is_action_pressed("dagger_attack"):
		request_dagger_attack.rpc_id(1)


@rpc("any_peer", "call_remote", "unreliable", 1)
func submit_movement_input(input: Vector2, rotation_y: float, sprint_pressed: bool, crouch_pressed: bool, focus_pressed: bool) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != network_peer_id:
		return
	_network_move_input = input.limit_length(1.0)
	_network_rotation_y = rotation_y
	_network_sprint = sprint_pressed
	_network_crouch = crouch_pressed
	_network_focus = focus_pressed


@rpc("any_peer", "call_remote", "reliable")
func request_dagger_attack() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == network_peer_id and in_raid:
		dagger_attack()


@rpc("any_peer", "call_remote", "reliable")
func request_spell_cast(page_index: int, requested_target: Vector3) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != network_peer_id:
		return
	if page_index < 0 or page_index >= page_configs.size():
		return
	select_spell_page(page_index)
	var config := current_spell_config()
	if config == null or not config.valid:
		return
	var offset := requested_target - global_position
	offset.y = 0.0
	if offset.length() > config.range_meters:
		requested_target = global_position + offset.normalized() * config.range_meters
	cast_selected_spell_immediate(requested_target)


func receive_network_snapshot(snapshot: Dictionary) -> void:
	if multiplayer.is_server():
		return
	if is_local_network_player():
		var authoritative_position: Vector3 = snapshot.get("position", global_position)
		global_position = global_position.lerp(authoritative_position, 0.35)
		rotation.y = lerp_angle(rotation.y, float(snapshot.get("rotation_y", rotation.y)), 0.35)
		health = float(snapshot.get("health", health))
		mana = float(snapshot.get("mana", mana))
		return
	_snapshot_buffer.append({
		"received_at": Time.get_ticks_msec() / 1000.0,
		"position": snapshot.get("position", global_position),
		"rotation_y": snapshot.get("rotation_y", rotation.y),
		"health": snapshot.get("health", health),
		"mana": snapshot.get("mana", mana)
	})
	while _snapshot_buffer.size() > 12:
		_snapshot_buffer.pop_front()


func _apply_remote_snapshot(_delta: float) -> void:
	if _snapshot_buffer.is_empty():
		return
	var render_time := Time.get_ticks_msec() / 1000.0 - 0.10
	while _snapshot_buffer.size() > 1 and float(_snapshot_buffer[1].received_at) <= render_time:
		_snapshot_buffer.pop_front()
	var first: Dictionary = _snapshot_buffer[0]
	var second: Dictionary = _snapshot_buffer[1] if _snapshot_buffer.size() > 1 else first
	var duration := maxf(0.001, float(second.received_at) - float(first.received_at))
	var alpha := clampf((render_time - float(first.received_at)) / duration, 0.0, 1.0)
	var first_position: Vector3 = first.position
	var second_position: Vector3 = second.position
	global_position = first_position.lerp(second_position, alpha)
	rotation.y = lerp_angle(float(first.rotation_y), float(second.rotation_y), alpha)
	health = lerpf(float(first.health), float(second.health), alpha)
	mana = lerpf(float(first.mana), float(second.mana), alpha)

func _configure_equipment_stats() -> void:
	armor = 0.0
	elemental_resistances = {"fire":0.0, "water":0.0, "grass":0.0, "neutral":0.0}
	var regen_multiplier: float = 1.0
	for slot: String in ["head", "chest", "accessory_1", "accessory_2"]:
		var info: Dictionary = ItemDB.get_item(str(GameState.loadout.get(slot, "")))
		armor += float(info.get("armor", 0.0))
		elemental_resistances.fire += float(info.get("fire_resist", 0.0))
		elemental_resistances.water += float(info.get("ice_resist", 0.0))
		regen_multiplier *= float(info.get("mana_regen_mult", 1.0))
	for element: String in elemental_resistances.keys():
		elemental_resistances[element] = clampf(float(elemental_resistances[element]), 0.0, 0.65)
	fire_resistance = float(elemental_resistances.fire)
	ice_resistance = float(elemental_resistances.water)
	mana_regeneration = base_mana_regeneration * regen_multiplier

func _rebuild_spell_pages() -> void:
	page_configs.clear()
	for index: int in range(3):
		page_configs.append(GameState.spell_config(index))
	if selected_page >= page_configs.size():
		selected_page = 0
	_update_preview()

func select_spell_page(page_index: int) -> void:
	if page_index < 0 or page_index >= page_configs.size():
		return
	cancel_cast()
	selected_page = page_index
	active_combat_slot = page_index
	active_element_changed.emit(current_primary_element())
	_update_preview()

func select_combat_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index > 3:
		return
	if slot_index < 3:
		select_spell_page(slot_index)
		return
	cancel_cast()
	active_combat_slot = 3
	active_element_changed.emit(current_primary_element())
	_update_preview()

func equipped_dagger() -> DaggerData:
	return ItemDB.dagger(str(GameState.loadout.get("dagger", "")))

func current_primary_element() -> String:
	if active_combat_slot == 3:
		var dagger := equipped_dagger()
		return dagger.primary_element if dagger != null else ElementSystem.NEUTRAL
	var config := current_spell_config()
	return config.base_spell.primary_element if config != null and config.valid else ElementSystem.NEUTRAL

func current_spell_config() -> RuntimeSpellConfig:
	if selected_page < 0 or selected_page >= page_configs.size():
		return null
	return page_configs[selected_page]

func current_spell_name() -> String:
	var config := current_spell_config()
	return config.base_spell.display_name if config != null and config.valid else "Empty Page"

func current_spellbook_name() -> String:
	var book: SpellbookData = GameState.equipped_spellbook()
	return book.display_name if book != null else "No Spellbook"

func cooldown_remaining() -> float:
	return page_cooldowns[selected_page] if selected_page < page_cooldowns.size() else 0.0

func cast_progress_ratio() -> float:
	return clampf(cast_elapsed / maxf(0.01, cast_duration), 0.0, 1.0) if casting else 0.0

func _update_movement(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_apply_movement_input(input, Input.is_action_pressed("sprint"), Input.is_action_pressed("crouch"), Input.is_action_pressed("cancel_cast"), delta)


func _apply_movement_input(input: Vector2, sprint_pressed: bool, crouch_pressed: bool, focus_pressed: bool, delta: float) -> void:
	var direction := Vector3(input.x, 0, input.y)
	if exhaustion_remaining > 0.0:
		direction = Vector3.ZERO
	is_focused = focus_pressed and not casting
	is_crouching = crouch_pressed
	is_sprinting = exhaustion_remaining <= 0.0 and sprint_pressed and stamina > 0.5 and input.length() > 0.1 and not casting and not is_focused and not is_crouching
	var speed: float = base_move_speed * slow_multiplier
	var leg_injury: float = maxf(float(injuries.left_leg), float(injuries.right_leg))
	speed *= 1.0 - leg_injury * 0.35
	if exhaustion_remaining > 0.0:
		stamina = 0.0
		speed = 0.0
	elif is_sprinting:
		speed *= sprint_speed_multiplier
		stamina = maxf(0.0, stamina - sprint_stamina_cost * delta)
	elif is_crouching:
		speed *= crouch_speed_multiplier
		stamina = minf(max_stamina, stamina + 15.0 * delta)
	else:
		stamina = minf(max_stamina, stamina + 18.0 * delta)
	if casting or is_focused:
		speed *= 0.58
	velocity.x = move_toward(velocity.x, direction.x * speed, 24.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 24.0 * delta)
	velocity.y = 0.0
	move_and_slide()
	if direction.length() > 0.1:
		walk_time += delta * speed

func _update_aim() -> void:
	if camera == null:
		return
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var origin: Vector3 = camera.project_ray_origin(mouse)
	var direction: Vector3 = camera.project_ray_normal(mouse)
	if absf(direction.y) > 0.001:
		var distance: float = -origin.y / direction.y
		aim_point = origin + direction * distance
	var flat: Vector3 = aim_point - global_position
	flat.y = 0.0
	if flat.length_squared() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), 0.32)
	_update_preview()

func _update_camera(delta: float) -> void:
	var look_offset: Vector3 = aim_point - global_position
	look_offset.y = 0.0
	look_offset = look_offset.limit_length(3.0) * aim_look_ahead
	var desired: Vector3 = global_position + Vector3(0, camera_height, camera_distance) + look_offset
	camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-delta * 6.5))
	camera.look_at(global_position + Vector3(0, 0.55, 0) + look_offset)

func begin_cast() -> bool:
	var config := current_spell_config()
	if active_combat_slot == 3 or casting or config == null or not config.valid or cooldown_remaining() > 0.0:
		return false
	var is_explosion: bool = config.base_spell.spell_id == "explosion"
	if is_explosion and not in_raid:
		_show_message("Explosion can only be invoked during an expedition.")
		return false
	if is_explosion and not GameState.can_use_explosion():
		_show_message("Explosion has already been used during this expedition.")
		return false
	if is_explosion and mana + 0.001 < max_mana:
		_show_message("Explosion requires a completely full mana reserve.")
		return false
	if not is_explosion and mana + 0.001 < config.mana_cost:
		_show_message("Insufficient mana — use an Azure Tonic or wait for regeneration.")
		return false
	casting = true
	cast_elapsed = 0.0
	var arm_injury: float = maxf(float(injuries.left_arm), float(injuries.right_arm))
	cast_duration = 1.0 if is_explosion else maxf(0.05, config.cast_time * (1.0 + arm_injury * 0.5 + float(injuries.head) * 0.2))
	cast_target = _limited_aim_target(config.range_meters)
	cast_glow.visible = true
	cast_vfx_seed = float(posmod(config.base_spell.spell_id.hash(), 1000)) / 67.0
	cast_glow.material_override = VisualFactory.elemental_spell_material(config.base_spell.primary_element, config.base_spell.debug_color, 5.0, cast_vfx_seed)
	cast_glow.scale = Vector3.ONE * 0.55
	cast_glow.rotation = Vector3.ZERO
	return true

func cancel_cast() -> void:
	casting = false
	cast_elapsed = 0.0
	cast_glow.visible = false
	cast_glow.scale = Vector3.ONE

func _update_casting(delta: float) -> void:
	for index: int in range(page_cooldowns.size()):
		page_cooldowns[index] = maxf(0.0, page_cooldowns[index] - delta)
	dagger_cooldown = maxf(0.0, dagger_cooldown - delta)
	if not casting:
		return
	cast_elapsed += delta
	cast_target = _limited_aim_target(current_spell_config().range_meters)
	var charge: float = cast_progress_ratio()
	var cast_pulse: float = 1.0 + sin(Time.get_ticks_msec() * 0.018 + cast_vfx_seed) * 0.13
	cast_glow.scale = Vector3.ONE * lerpf(0.55, 1.75, charge) * cast_pulse
	cast_glow.rotation.y += delta * 7.5
	cast_glow.rotation.z -= delta * 4.0
	if cast_elapsed >= cast_duration:
		complete_cast()

func complete_cast() -> bool:
	var config := current_spell_config()
	if not casting or config == null:
		cancel_cast()
		return false
	var is_explosion: bool = config.base_spell.spell_id == "explosion"
	if (is_explosion and (mana + 0.001 < max_mana or not GameState.can_use_explosion())) or (not is_explosion and mana + 0.001 < config.mana_cost):
		cancel_cast()
		return false
	casting = false
	cast_glow.visible = false
	mana = 0.0 if is_explosion else maxf(0.0, mana - config.mana_cost)
	mana_regen_delay = mana_regeneration_delay_seconds
	page_cooldowns[selected_page] = config.cooldown
	mana_changed.emit()
	var raid: Node = _gameplay_area()
	if raid.has_method("spawn_cast_release"):
		raid.spawn_cast_release(cast_origin.global_position, config.base_spell.primary_element, config.base_spell.debug_color, cast_vfx_seed)
	if is_explosion:
		if raid.has_method("play_explosion_sequence"):
			raid.play_explosion_sequence(self)
	elif config.base_spell.spell_id == "healing_circle":
		if active_healing_circle != null and is_instance_valid(active_healing_circle):
			active_healing_circle.queue_free()
		if raid.has_method("spawn_healing_circle"):
			active_healing_circle = raid.spawn_healing_circle(self, config, cast_target)
	elif config.behavior_type == "projectile":
		var base_direction: Vector3 = cast_target - cast_origin.global_position
		base_direction.y = 0.0
		base_direction = base_direction.normalized()
		if "beam" in config.behavior_tags and raid.has_method("cast_special_spell"):
			raid.cast_special_spell(self, config, cast_origin.global_position, cast_target, base_direction, "beam")
		else:
			for projectile_index: int in range(config.projectile_count):
				var offset: float = float(projectile_index) - float(config.projectile_count - 1) * 0.5
				var direction: Vector3 = base_direction.rotated(Vector3.UP, deg_to_rad(offset * 8.0))
				if raid.has_method("spawn_player_spell"):
					raid.spawn_player_spell(self, config, cast_origin.global_position, direction, cast_target)
	elif raid.has_method("cast_special_spell"):
		var base_direction: Vector3 = cast_target - cast_origin.global_position
		base_direction.y = 0.0
		base_direction = base_direction.normalized()
		raid.cast_special_spell(self, config, cast_origin.global_position, cast_target, base_direction)
	spell_cast.emit(global_position, 15.0, config.base_spell.spell_id)
	if raid.has_method("notify_spell_cast"):
		raid.notify_spell_cast(global_position, 15.0)
	recoil_amount = 0.22
	return true

func cast_selected_spell_immediate(target: Vector3) -> bool:
	aim_point = target
	if not begin_cast():
		return false
	cast_elapsed = cast_duration
	return complete_cast()

func dagger_attack() -> bool:
	if active_combat_slot != 3:
		select_combat_slot(3)
	var dagger := equipped_dagger()
	if dagger == null or dagger_cooldown > 0.0 or stamina < dagger.stamina_cost:
		return false
	dagger_cooldown = 1.0 / maxf(0.1, dagger.attack_speed)
	stamina = maxf(0.0, stamina - dagger.stamina_cost)
	var hit_any: bool = false
	for target: Node in get_tree().get_nodes_in_group("enemies"):
		if not target is Node3D:
			continue
		var offset: Vector3 = (target as Node3D).global_position - global_position
		offset.y = 0.0
		if offset.length() > dagger.attack_range:
			continue
		var facing := -global_transform.basis.z
		if rad_to_deg(facing.angle_to(offset.normalized())) > dagger.attack_arc_degrees * 0.5:
			continue
		var arm_injury: float = maxf(float(injuries.left_arm), float(injuries.right_arm))
		target.take_damage(dagger.damage * (1.0 - arm_injury * 0.35), global_position, 0.0, dagger.primary_element)
		if not dagger.status_effect.is_empty() and target.has_method("apply_status"):
			target.apply_status(dagger.status_effect, 2.0, dagger.damage * 0.08)
		hit_any = true
	var raid: Node = _gameplay_area()
	if raid.has_method("spawn_spell_impact"):
		raid.spawn_spell_impact(global_position + -global_transform.basis.z * 1.1 + Vector3(0, 0.5, 0), dagger.debug_color, dagger.attack_range * 0.65)
	return hit_any

func take_damage(amount: float, source: Vector3 = Vector3.ZERO, bleed_chance: float = 0.15, element: String = "physical") -> void:
	if dead:
		return
	var attack_element := ElementSystem.normalize_primary(element)
	var defense_element := current_primary_element()
	var relationship := ElementSystem.multiplier(attack_element, defense_element)
	var resistance: float = float(elemental_resistances.get(attack_element, 0.0))
	var reduced: float = ElementSystem.damage_after_resistance(amount, attack_element, defense_element, resistance) * (100.0 / (100.0 + armor))
	if ward > 0.0:
		var absorbed: float = minf(ward, reduced)
		ward -= absorbed
		reduced -= absorbed
	last_element_feedback = "WEAKNESS" if relationship > 1.0 else "RESISTED" if relationship < 1.0 else ""
	if relationship > 1.0:
		_show_message("ELEMENTAL WEAKNESS: %s overcomes %s" % [attack_element.to_upper(), defense_element.to_upper()])
	health = maxf(0.0, health - reduced)
	last_damage_time = Time.get_ticks_msec() / 1000.0
	mana_regen_delay = maxf(mana_regen_delay, 3.0)
	if element == "physical" and randf() < bleed_chance:
		bleeding = true
	if randf() < base_injury_chance * clampf(reduced / 25.0, 0.25, 2.0):
		_apply_random_injury(clampf(reduced / maxf(1.0, max_health), 0.08, 0.45))
	health_changed.emit()
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3(1.12, 0.88, 1.12), 0.05)
	tween.tween_property(visual, "scale", Vector3.ONE, 0.12)
	if health <= 0.0:
		_die()

func apply_status(status_id: String, duration: float, power: float) -> void:
	if status_id == "burn":
		burn_remaining = maxf(burn_remaining, duration)
		burn_damage_per_second = maxf(burn_damage_per_second, power * (1.0 - fire_resistance))
	elif status_id == "slow":
		slow_remaining = maxf(slow_remaining, duration)
		slow_multiplier = clampf(1.0 - power * (1.0 - ice_resistance), 0.45, 1.0)
	elif status_id == "poison":
		poison_remaining = maxf(poison_remaining, duration)
		poison_damage_per_second = maxf(poison_damage_per_second, power)

func _apply_random_injury(severity: float) -> void:
	var body_parts: Array = injuries.keys()
	var body_part: String = str(body_parts[randi() % body_parts.size()])
	injuries[body_part] = clampf(float(injuries[body_part]) + severity, 0.0, 1.0)
	injury_changed.emit(body_part, float(injuries[body_part]))

func restore_health(amount: float) -> void:
	health = minf(max_health, health + amount * (1.0 + GameState.skill_bonus("healing")))
	health_changed.emit()

func restore_mana(amount: float) -> void:
	mana = minf(max_mana, mana + amount)
	mana_changed.emit()

func add_ward(amount: float) -> void:
	ward = minf(max_health, ward + amount)

func cleanse_statuses() -> void:
	bleeding = false
	burn_remaining = 0.0
	burn_damage_per_second = 0.0
	poison_remaining = 0.0
	poison_damage_per_second = 0.0
	slow_remaining = 0.0
	slow_multiplier = 1.0

func quick_heal() -> void:
	var item_id: String = "health_potion"
	if int(GameState.raid_inventory.get(item_id, 0)) <= 0:
		item_id = "bandage" if int(GameState.raid_inventory.get("bandage", 0)) > 0 else "medkit"
	if int(GameState.raid_inventory.get(item_id, 0)) <= 0:
		_show_message("No restorative potion equipped.")
		return
	GameState.remove_raid_item(item_id, 1)
	var info: Dictionary = ItemDB.get_item(item_id)
	restore_health(float(info.get("heal", 0.0)))
	if bool(info.get("stops_bleed", false)):
		bleeding = false
		for body_part: String in injuries.keys():
			injuries[body_part] = maxf(0.0, float(injuries[body_part]) - 0.2)
			injury_changed.emit(body_part, float(injuries[body_part]))

func use_mana_consumable(item_id: String = "mana_potion") -> bool:
	if int(GameState.raid_inventory.get(item_id, 0)) <= 0:
		return false
	GameState.remove_raid_item(item_id, 1)
	restore_mana(float(ItemDB.get_item(item_id).get("mana_restore", 0.0)))
	return true

func capture_raid_state() -> Dictionary:
	return {
		"health":health, "mana":mana, "stamina":stamina,
		"injuries":injuries.duplicate(true), "bleeding":bleeding,
		"bleed_tick":bleed_tick, "mana_regen_delay":mana_regen_delay,
		"page_cooldowns":page_cooldowns.duplicate(), "dagger_cooldown":dagger_cooldown,
		"burn_remaining":burn_remaining, "burn_damage_per_second":burn_damage_per_second,
		"slow_remaining":slow_remaining, "slow_multiplier":slow_multiplier,
		"poison_remaining":poison_remaining, "poison_damage_per_second":poison_damage_per_second,
		"exhaustion_remaining":exhaustion_remaining,
		"active_combat_slot":active_combat_slot, "selected_page":selected_page
	}

func restore_raid_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	health = clampf(float(state.get("health", max_health)), 0.0, max_health)
	mana = clampf(float(state.get("mana", max_mana)), 0.0, max_mana)
	stamina = clampf(float(state.get("stamina", max_stamina)), 0.0, max_stamina)
	var saved_injuries: Variant = state.get("injuries", {})
	if saved_injuries is Dictionary:
		for body_part: String in injuries.keys():
			injuries[body_part] = clampf(float(saved_injuries.get(body_part, 0.0)), 0.0, 1.0)
	bleeding = bool(state.get("bleeding", false))
	bleed_tick = maxf(0.0, float(state.get("bleed_tick", 0.0)))
	mana_regen_delay = maxf(0.0, float(state.get("mana_regen_delay", 0.0)))
	var saved_cooldowns: Variant = state.get("page_cooldowns", [])
	if saved_cooldowns is Array:
		for index: int in range(mini(page_cooldowns.size(), saved_cooldowns.size())):
			page_cooldowns[index] = maxf(0.0, float(saved_cooldowns[index]))
	dagger_cooldown = maxf(0.0, float(state.get("dagger_cooldown", 0.0)))
	burn_remaining = maxf(0.0, float(state.get("burn_remaining", 0.0)))
	burn_damage_per_second = maxf(0.0, float(state.get("burn_damage_per_second", 0.0)))
	slow_remaining = maxf(0.0, float(state.get("slow_remaining", 0.0)))
	slow_multiplier = clampf(float(state.get("slow_multiplier", 1.0)), 0.45, 1.0)
	poison_remaining = maxf(0.0, float(state.get("poison_remaining", 0.0)))
	poison_damage_per_second = maxf(0.0, float(state.get("poison_damage_per_second", 0.0)))
	exhaustion_remaining = maxf(0.0, float(state.get("exhaustion_remaining", 0.0)))
	selected_page = clampi(int(state.get("selected_page", 0)), 0, 2)
	active_combat_slot = clampi(int(state.get("active_combat_slot", selected_page)), 0, 3)
	health_changed.emit()
	mana_changed.emit()
	active_element_changed.emit(current_primary_element())

func _update_status(delta: float) -> void:
	if exhaustion_remaining > 0.0:
		exhaustion_remaining = maxf(0.0, exhaustion_remaining - delta)
		stamina = 0.0
	if mana_regen_delay > 0.0:
		mana_regen_delay -= delta
	elif mana < max_mana:
		var combat_age: float = Time.get_ticks_msec() / 1000.0 - last_damage_time
		var combat_multiplier: float = 0.55 if combat_age < 5.0 else 1.0
		mana = minf(max_mana, mana + mana_regeneration * combat_multiplier * delta)
		mana_changed.emit()
	if bleeding:
		bleed_tick += delta
		if bleed_tick >= 2.0:
			bleed_tick = 0.0
			take_damage(2.0, Vector3.ZERO, 0.0)
	if burn_remaining > 0.0:
		burn_remaining -= delta
		health = maxf(0.0, health - burn_damage_per_second * delta)
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
		if health <= 0.0:
			_die()
	else:
		poison_damage_per_second = 0.0

func apply_exhaustion(duration: float = 3.0) -> void:
	exhaustion_remaining = maxf(exhaustion_remaining, duration)
	stamina = 0.0
	velocity = Vector3.ZERO
	_show_message("EXHAUSTED - movement disabled for 3 seconds.")

func _limited_aim_target(max_range: float) -> Vector3:
	var flat: Vector3 = aim_point - global_position
	flat.y = 0.0
	return global_position + flat.limit_length(max_range)

func _update_preview() -> void:
	if placement_preview == null or page_configs.is_empty():
		return
	var config := current_spell_config()
	var show: bool = in_raid and active_combat_slot < 3 and config != null and config.valid and config.base_spell.spell_form == "area"
	placement_preview.visible = show
	if show:
		placement_preview.global_position = _limited_aim_target(config.range_meters) + Vector3(0, 0.06, 0)
		placement_preview.scale = Vector3(config.area_radius * 2.0, 0.05, config.area_radius * 2.0)
		placement_preview.material_override = VisualFactory.elemental_spell_material(config.base_spell.primary_element, config.base_spell.debug_color, 1.7, float(posmod(config.base_spell.spell_id.hash(), 1000)) / 67.0)
	_update_trajectory_preview(config)

func _update_trajectory_preview(config: RuntimeSpellConfig) -> void:
	if trajectory_preview == null:
		return
	var show: bool = in_raid and active_combat_slot < 3 and config != null and config.valid and config.base_spell.spell_form == "projectile"
	trajectory_preview.visible = show
	if not show:
		return
	var immediate := trajectory_preview.mesh as ImmediateMesh
	if immediate == null:
		immediate = ImmediateMesh.new()
		trajectory_preview.mesh = immediate
	immediate.clear_surfaces()
	immediate.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, VisualFactory.elemental_spell_material(config.base_spell.primary_element, config.base_spell.debug_color, 2.8, float(posmod(config.base_spell.spell_id.hash(), 1000)) / 67.0))
	var start := to_local(cast_origin.global_position)
	var target := to_local(_limited_aim_target(config.range_meters))
	var forward := target - start
	forward.y = 0.0
	var distance := maxf(0.1, forward.length())
	forward = forward.normalized()
	for index: int in range(17):
		var progress := float(index) / 16.0
		var point := start.lerp(target, progress)
		if config.trajectory in ["left_turn", "right_turn"]:
			var side: float = -1.0 if config.trajectory == "left_turn" else 1.0
			var control := start + forward * distance * 0.46 + forward.cross(Vector3.UP).normalized() * side * minf(5.0, distance * 0.38)
			var inverse := 1.0 - progress
			point = inverse * inverse * start + 2.0 * inverse * progress * control + progress * progress * target
		elif config.trajectory == "high_lob":
			point.y += sin(progress * PI) * 6.5
		immediate.surface_add_vertex(point)
	immediate.surface_end()

func _update_interaction() -> void:
	nearby_interaction = ""
	var best_distance: float = 2.5
	for node: Node in get_tree().get_nodes_in_group("interactable"):
		if node is Node3D:
			var distance: float = global_position.distance_to((node as Node3D).global_position)
			if distance < best_distance:
				best_distance = distance
				nearby_interaction = "[E] " + str(node.call("get_interaction_text", self))

func _interact() -> void:
	var closest: Node3D
	var best_distance: float = 2.5
	for node: Node in get_tree().get_nodes_in_group("interactable"):
		if node is Node3D:
			var distance: float = global_position.distance_to((node as Node3D).global_position)
			if distance < best_distance:
				best_distance = distance
				closest = node as Node3D
	if closest != null and closest.has_method("interact"):
		closest.interact(self)

func _update_visuals(delta: float) -> void:
	var moving: bool = Vector2(velocity.x, velocity.z).length() > 0.2
	var bob: float = sin(walk_time * 2.4) * 0.045 if moving else 0.0
	visual.position.y = lerpf(visual.position.y, bob, 0.25)
	recoil_amount = move_toward(recoil_amount, 0.0, delta * 1.8)
	wand_socket.position.z = wand_socket_base_position.z - recoil_amount

func _show_message(text: String) -> void:
	var raid: Node = _gameplay_area()
	if raid.has_method("show_message"):
		raid.show_message(text)

func _die() -> void:
	if dead:
		return
	dead = true
	velocity = Vector3.ZERO
	var tween := create_tween()
	tween.tween_property(visual, "rotation:z", 1.42, 0.48)
	tween.parallel().tween_property(visual, "scale", Vector3(1.15, 0.35, 1.15), 0.48)
	died.emit()
	var raid: Node = _gameplay_area()
	if raid.has_method("on_player_died"):
		raid.on_player_died()

func _gameplay_area() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node is RaidScene or node is BaseScene:
			return node
		node = node.get_parent()
	return get_parent()
