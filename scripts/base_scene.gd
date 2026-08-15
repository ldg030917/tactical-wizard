class_name BaseScene
extends Node3D

const ELEMENTAL_SPELL_FIELD := preload("res://scenes/spells/elemental_spell_field.tscn")

@export_category("Runtime Scenes")
@export var player_scene: PackedScene
var local_lobby := false

@export_category("Station Access")
@export_range(1.5, 6.0, 0.1, "suffix:m") var station_access_radius: float = 3.1

@onready var player_spawn: PlayerSpawnPoint = %PlayerSpawn_Default
@onready var runtime_actors: Node3D = %RuntimeActors
@onready var base_ui: BaseUI = %BaseUI
@onready var temporary_effects: Node3D = %TemporaryEffects
@onready var base_mana_gauge: ProgressBar = %BaseManaGauge
@onready var base_spell_slots: HBoxContainer = %BaseSpellSlots

var player: PlayerController
var active_station: BaseStation
var base_spell_buttons: Array[Button] = []
var players_by_peer: Dictionary = {}
var _snapshot_elapsed := 0.0

func _ready() -> void:
	if NetworkManager.is_network_game() and not local_lobby:
		_setup_network_world()
		return
	_spawn_player()
	_build_base_spell_hotbar()
	GameState.state_changed.connect(_sync_station_levels)
	_sync_station_levels()
	base_ui.close_station()

func _process(_delta: float) -> void:
	if NetworkManager.is_network_game() and not local_lobby:
		_process_network_world(_delta)
		return
	if player == null:
		return
	base_mana_gauge.max_value = player.max_mana
	base_mana_gauge.value = player.mana
	_update_base_spell_hotbar()
	var nearest: BaseStation
	var nearest_distance: float = station_access_radius
	for node: Node in get_tree().get_nodes_in_group("interactable"):
		if not node is BaseStation or not is_ancestor_of(node):
			continue
		var station := node as BaseStation
		if station.station_id == "deploy":
			continue
		var distance: float = player.global_position.distance_to(station.global_position)
		if distance < nearest_distance:
			nearest = station
			nearest_distance = distance
	if nearest == active_station:
		return
	active_station = nearest
	if active_station == null:
		base_ui.close_station()
	else:
		base_ui.show_station(active_station.station_id, active_station.display_name)

func _build_base_spell_hotbar() -> void:
	for index: int in range(3):
		var button := Button.new()
		button.custom_minimum_size = Vector2(82, 82)
		button.expand_icon = true
		button.pressed.connect(player.select_spell_page.bind(index))
		base_spell_slots.add_child(button)
		base_spell_buttons.append(button)
	_update_base_spell_hotbar()

func _update_base_spell_hotbar() -> void:
	if player == null or base_spell_buttons.size() != 3:
		return
	for index: int in range(3):
		var config: RuntimeSpellConfig = player.page_configs[index] if index < player.page_configs.size() else null
		var spell: BaseSpellData = config.base_spell if config != null and config.valid else null
		var button := base_spell_buttons[index]
		button.icon = UIIconFactory.spell_icon(spell, 96) if spell != null else UIIconFactory.icon("?", "neutral", 96)
		button.text = str(index + 1)
		button.tooltip_text = "%s\nMana %.0f — click the world to cast" % [spell.display_name if spell != null else "Empty", config.mana_cost if config != null else 0.0]
		button.disabled = spell == null
		button.modulate = Color.WHITE if player.selected_page == index else Color(0.58, 0.58, 0.66, 0.9)

func _spawn_player() -> void:
	player = player_scene.instantiate() as PlayerController
	player.in_raid = false
	player.position = runtime_actors.to_local(player_spawn.global_position)
	player.rotation_degrees.y = player_spawn.facing_direction_degrees
	runtime_actors.add_child(player)


func _setup_network_world() -> void:
	# The dedicated server is the sole source of player instances and snapshots.
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_network_peer_connected)
		multiplayer.peer_disconnected.connect(_on_network_peer_disconnected)
		_create_network_player(1, player_spawn.global_position, deg_to_rad(player_spawn.facing_direction_degrees))
	else:
		request_initial_players.rpc_id(1)


func _process_network_world(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_snapshot_elapsed += delta
	if _snapshot_elapsed < 1.0 / 20.0:
		return
	_snapshot_elapsed = 0.0
	var states: Array[Dictionary] = []
	for peer_id: int in players_by_peer:
		var network_player := players_by_peer[peer_id] as PlayerController
		if not is_instance_valid(network_player):
			continue
		states.append({
			"peer_id": peer_id,
			"position": network_player.global_position,
			"rotation_y": network_player.rotation.y,
			"health": network_player.health,
			"mana": network_player.mana
		})
	receive_player_snapshots.rpc(states)


func _on_network_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var position := player_spawn.global_position + Vector3(float(players_by_peer.size() % 3) * 1.25, 0.0, float(players_by_peer.size() / 3) * 1.25)
	_create_network_player(peer_id, position, deg_to_rad(player_spawn.facing_direction_degrees))
	spawn_network_player.rpc(peer_id, position, deg_to_rad(player_spawn.facing_direction_degrees))


func _on_network_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_remove_network_player(peer_id)
	remove_network_player.rpc(peer_id)


func _create_network_player(peer_id: int, spawn_position: Vector3, spawn_rotation_y: float) -> PlayerController:
	if players_by_peer.has(peer_id):
		return players_by_peer[peer_id] as PlayerController
	var network_player := player_scene.instantiate() as PlayerController
	network_player.name = "Player_%d" % peer_id
	network_player.in_raid = false
	network_player.configure_network(peer_id)
	runtime_actors.add_child(network_player)
	network_player.global_position = spawn_position
	network_player.rotation.y = spawn_rotation_y
	players_by_peer[peer_id] = network_player
	if not multiplayer.is_server() and peer_id == multiplayer.get_unique_id():
		player = network_player
		_build_base_spell_hotbar()
		base_ui.close_station()
	return network_player


func _remove_network_player(peer_id: int) -> void:
	var network_player := players_by_peer.get(peer_id) as PlayerController
	players_by_peer.erase(peer_id)
	if is_instance_valid(network_player):
		network_player.queue_free()
	if player == network_player:
		player = null


@rpc("any_peer", "call_remote", "reliable")
func request_initial_players() -> void:
	if not multiplayer.is_server():
		return
	var requesting_peer := multiplayer.get_remote_sender_id()
	if requesting_peer <= 0:
		return
	for peer_id: int in players_by_peer:
		var network_player := players_by_peer[peer_id] as PlayerController
		if is_instance_valid(network_player):
			spawn_network_player.rpc_id(requesting_peer, peer_id, network_player.global_position, network_player.rotation.y)


@rpc("authority", "call_remote", "reliable")
func spawn_network_player(peer_id: int, spawn_position: Vector3, spawn_rotation_y: float) -> void:
	if not multiplayer.is_server():
		_create_network_player(peer_id, spawn_position, spawn_rotation_y)


@rpc("authority", "call_remote", "reliable")
func remove_network_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		_remove_network_player(peer_id)


@rpc("authority", "call_remote", "unreliable", 1)
func receive_player_snapshots(states: Array[Dictionary]) -> void:
	if multiplayer.is_server():
		return
	for state: Dictionary in states:
		var peer_id := int(state.get("peer_id", 0))
		var network_player := players_by_peer.get(peer_id) as PlayerController
		if is_instance_valid(network_player):
			network_player.receive_network_snapshot(state)

func open_tab(tab: String) -> void:
	if tab == "deploy":
		_deploy()
		return
	base_ui.show_station(tab, "Refuge Facility")

func spawn_player_spell(caster: PlayerController, config: RuntimeSpellConfig, start: Vector3, direction: Vector3, target: Vector3 = Vector3.ZERO) -> SpellProjectile:
	if config == null or config.base_spell == null or config.base_spell.projectile_scene == null:
		return null
	var projectile := config.base_spell.projectile_scene.instantiate() as SpellProjectile
	temporary_effects.add_child(projectile)
	projectile.global_position = start
	projectile.configure(caster, config, direction, "player", target)
	return projectile

func spawn_healing_circle(caster: PlayerController, config: RuntimeSpellConfig, at: Vector3) -> HealingCircle:
	if config == null or config.base_spell == null or config.base_spell.area_scene == null:
		return null
	var circle := config.base_spell.area_scene.instantiate() as HealingCircle
	temporary_effects.add_child(circle)
	circle.global_position = at
	circle.configure(caster, config)
	return circle

func cast_special_spell(caster: PlayerController, config: RuntimeSpellConfig, start: Vector3, target: Vector3, direction: Vector3, behavior_override: String = "") -> Node:
	var behavior: String = behavior_override if not behavior_override.is_empty() else config.behavior_type
	if behavior in ["damage_zone", "slow_zone", "root_field", "puddle", "wall", "barrier", "mine"]:
		var field := ELEMENTAL_SPELL_FIELD.instantiate() as ElementalSpellField
		temporary_effects.add_child(field)
		field.global_position = Vector3(target.x, 0.08, target.z)
		field.rotation.y = caster.rotation.y
		field.configure(caster, config)
		return field
	if behavior == "teleport":
		caster.global_position = target + Vector3(0, 0.05, 0)
	elif behavior == "mana_restore":
		caster.restore_mana(maxf(config.damage_or_healing, config.secondary_power))
	elif behavior == "cleanse":
		caster.cleanse_statuses()
		caster.restore_health(config.damage_or_healing * 0.35)
	elif behavior == "shield":
		caster.add_ward(config.damage_or_healing)
	elif behavior in ["cone", "chain", "beam", "knockback"]:
		for step: int in range(1, 7):
			var effect_point: Vector3 = start.lerp(target, float(step) / 6.0)
			spawn_spell_impact(effect_point, config.base_spell.debug_color, 0.35 + step * 0.1, config.base_spell.primary_element, float(step))
	spawn_spell_impact(target, config.base_spell.debug_color, maxf(0.7, config.area_radius), config.base_spell.primary_element, 4.0)
	return null

func spawn_cast_release(at: Vector3, primary_element: String, color: Color, variant_seed: float = 0.0) -> void:
	spawn_spell_impact(at, color, 0.8, primary_element, variant_seed)

func spawn_spell_impact(at: Vector3, color: Color, radius: float, primary_element: String = "neutral", variant_seed: float = 0.0) -> void:
	var effect := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	sphere.material = VisualFactory.elemental_spell_material(primary_element, color, 4.5, variant_seed)
	effect.mesh = sphere
	temporary_effects.add_child(effect)
	effect.global_position = at
	effect.scale = Vector3.ONE * 0.15
	var tween := effect.create_tween()
	tween.tween_property(effect, "scale", Vector3.ONE * radius * 2.0, 0.22)
	tween.parallel().tween_property(effect, "transparency", 1.0, 0.3)
	tween.tween_callback(effect.queue_free)

func schedule_spell_echo(config: RuntimeSpellConfig, at: Vector3) -> void:
	get_tree().create_timer(0.75).timeout.connect(func() -> void:
		spawn_spell_impact(at, config.base_spell.debug_color, maxf(0.8, config.area_radius), config.base_spell.primary_element, 17.0)
	)

func notify_spell_cast(_position: Vector3, _radius: float) -> void:
	pass

func show_message(text: String) -> void:
	base_ui.show_feedback(text)

func _sync_station_levels() -> void:
	for station: Node in get_tree().get_nodes_in_group("interactable"):
		if not station is BaseStation:
			continue
		var base_station := station as BaseStation
		if base_station.linked_upgrade != null:
			base_station.level = int(GameState.base_upgrades.get(base_station.linked_upgrade.upgrade_id, 1))
			base_station.level_two_module.visible = base_station.level >= 2
			base_station.level_three_module.visible = base_station.level >= 3

func _deploy() -> void:
	var main: Node = get_tree().current_scene
	if main.has_method("start_raid"):
		main.start_raid()
