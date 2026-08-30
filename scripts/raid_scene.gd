class_name RaidScene
extends Node3D

const REGION_GRAPH := preload("res://scripts/regions/region_graph.gd")
const ELEMENTAL_SPELL_FIELD := preload("res://scenes/spells/elemental_spell_field.tscn")
const EXPLOSION_CUTSCENE: VideoStream = preload("res://assets/cutscenes/explosion.ogv")
const EXPLOSION_SCREEN_SHADER: Shader = preload("res://shaders/explosion_screen.gdshader")

@export_category("Runtime Scenes")
@export var player_scene: PackedScene
@export var enemy_drop_container_scene: PackedScene
@export var elemental_hazard_scene: PackedScene
@export var temporary_grass_wall_scene: PackedScene

@export_category("Elemental Region")
@export var region_id: String = "fire_region"
@export var region_display_name: String = "Ashen Caldera"
@export_enum("fire", "water", "grass", "neutral") var region_primary_element: String = "fire"
@export_enum("none", "burn_zones", "water_slow", "temporary_grass_walls") var hazard_type: String = "burn_zones"
@export var region_tint: Color = Color("f0522d")

@export_category("Magical Enemy Drop Tables")
@export var monster_drop_table: LootTableData
@export var mage_drop_table: LootTableData
@export var boss_drop_table: LootTableData

@export_category("Raid Randomization")
@export var weather_options: Array[String] = ["Clear", "Rain haze", "Dusk"]
@export_range(5.0, 40.0, 0.5, "suffix:m") var clear_vision_radius: float = 17.0
@export_range(5.0, 40.0, 0.5, "suffix:m") var fog_vision_radius: float = 13.5
@export_range(5.0, 40.0, 0.5, "suffix:m") var dusk_vision_radius: float = 15.0

@export_category("Grass Region Living Walls")
@export_range(1.0, 30.0, 0.5, "suffix:s") var grass_wall_refresh_seconds: float = 5.0
@export_range(1, 4, 1) var grass_wall_count: int = 2

@onready var player_spawn: PlayerSpawnPoint = %PlayerSpawn_Default
@onready var enemy_spawns: Node3D = %EnemySpawns
@onready var loot_spawns: Node3D = %LootSpawns
@onready var loot_containers: Node3D = %LootContainers
@onready var runtime_actors: Node3D = %RuntimeActors
@onready var temporary_effects: Node3D = %TemporaryEffects
@onready var world_environment: WorldEnvironment = %WorldEnvironment
@onready var sun: DirectionalLight3D = %Sun
@onready var hud: RaidHUD = %HUD
@onready var extraction_zones: Node3D = $ExtractionZones
@onready var destructible_buildings: Node3D = $Environment/Buildings
@onready var destructible_cover: Node3D = $Environment/Cover
@onready var outer_boundaries: Node3D = $Environment/Boundaries

var player: PlayerController
var rng := RandomNumberGenerator.new()
var kills: Dictionary = {"monster":0, "mage":0}
var weather: String = "Clear"
var vision_radius: float = 17.0
var enemy_detection_multiplier: float = 1.0
var raid_complete: bool = false
var grass_wall_refresh_remaining: float = 0.0
var grass_wall_generation: int = 0
var explosion_devastated: bool = false
var network_players: Dictionary = {}
var network_enemies: Dictionary = {}
var network_projectiles: Dictionary = {}
var network_projectile_spawn_data: Dictionary = {}
var network_snapshot_elapsed := 0.0
var network_raid_active := false
## Assigned by Main before the scene enters the tree. All network fan-out for
## this world is scoped to this session rather than connected peers globally.
var raid_session_id := ""
var _next_network_enemy_id := 1
var _next_network_magic_id := 1

const GRASS_WALL_PLACEMENTS: Array[Dictionary] = [
	{"position":Vector3(-12, 1.4, -4), "rotation":0.0},
	{"position":Vector3(-8, 1.4, 10), "rotation":90.0},
	{"position":Vector3(-2, 1.4, 5), "rotation":35.0},
	{"position":Vector3(6, 1.4, -8), "rotation":90.0},
	{"position":Vector3(11, 1.4, 5), "rotation":-30.0},
	{"position":Vector3(3, 1.4, 12), "rotation":0.0}
]

func _ready() -> void:
	rng.randomize()
	kills = GameState.raid_kills
	_configure_weather()
	_configure_region()
	if NetworkManager.is_network_game():
		_setup_network_raid()
		return
	_spawn_player()
	_activate_containers()
	_spawn_editor_placed_loot()
	_spawn_editor_placed_enemies()
	hud.configure(self, player, weather)
	if region_id != REGION_GRAPH.ENTRY_REGION_ID:
		hud.set_extraction_status("RETURN TO THE NEUTRAL REGION TO EXTRACT")


func _setup_network_raid() -> void:
	# Clients load the same static raid scene, but only the server simulates
	# actors and creates player characters after every client reports ready.
	hud.visible = false
	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_on_network_raid_peer_disconnected)
		_spawn_editor_placed_loot()
		_spawn_editor_placed_enemies()


func spawn_network_raid_member(peer_id: int) -> void:
	if not multiplayer.is_server() or network_players.has(peer_id):
		return
	# The joining peer has its Raid Scene loaded at this point. Replay the
	# persistent world first, then announce the new player to active members.
	network_raid_active = true
	_sync_network_world_to_peer(peer_id)
	var offset_index := network_players.size()
	var spawn_position := player_spawn.global_position + Vector3(float(offset_index % 3) * 1.25, 0.0, float(offset_index / 3) * 1.25)
	_create_network_raid_player(peer_id, spawn_position, deg_to_rad(player_spawn.facing_direction_degrees))
	for target_peer: int in NetworkManager.get_session_members(raid_session_id):
		spawn_network_raid_player.rpc_id(target_peer, peer_id, spawn_position, deg_to_rad(player_spawn.facing_direction_degrees))
	print("[PLAYER %s] spawn peer=%d players=%s" % [raid_session_id, peer_id, str(network_players.keys())])


func _sync_network_world_to_peer(peer_id: int) -> void:
	for existing_peer: int in network_players:
		var existing_player := network_players[existing_peer] as PlayerController
		if is_instance_valid(existing_player):
			spawn_network_raid_player.rpc_id(peer_id, existing_peer, existing_player.global_position, existing_player.rotation.y)
	for enemy_id: String in network_enemies:
		var enemy := network_enemies[enemy_id] as EnemyController
		if is_instance_valid(enemy):
			spawn_network_enemy.rpc_id(peer_id, _network_enemy_spawn_data(enemy))
	for magic_id: String in network_projectile_spawn_data:
		var projectile_ref: Variant = network_projectiles.get(magic_id)
		if is_instance_valid(projectile_ref):
			spawn_network_projectile.rpc_id(peer_id, network_projectile_spawn_data[magic_id])


func _process(delta: float) -> void:
	if NetworkManager.is_network_game():
		_process_network_raid(delta)
		return
	_update_grass_wall_cycle(delta)
	if player != null:
		_update_visibility()


func _process_network_raid(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_update_grass_wall_cycle(delta)
	network_snapshot_elapsed += delta
	if network_snapshot_elapsed < 1.0 / 20.0:
		return
	network_snapshot_elapsed = 0.0
	var states: Array[Dictionary] = []
	for peer_id: int in network_players:
		var network_player := network_players[peer_id] as PlayerController
		if is_instance_valid(network_player):
			states.append({"peer_id": peer_id, "position": network_player.global_position, "rotation_y": network_player.rotation.y, "aim_pitch": network_player._network_aim_pitch, "health": network_player.health, "mana": network_player.mana, "cooldowns": network_player.page_cooldowns.duplicate(), "dead": network_player.dead})
	for target_peer: int in NetworkManager.get_session_members(raid_session_id):
		receive_network_raid_snapshots.rpc_id(target_peer, states)
	var enemy_states: Array[Dictionary] = []
	for enemy_id: String in network_enemies:
		var enemy := network_enemies[enemy_id] as EnemyController
		if is_instance_valid(enemy):
			enemy_states.append({"enemy_id": enemy_id, "position": enemy.global_position, "rotation_y": enemy.rotation.y, "health": enemy.health, "dead": enemy.dead})
	for target_peer: int in NetworkManager.get_session_members(raid_session_id):
		receive_network_enemy_snapshots.rpc_id(target_peer, enemy_states)
	var projectile_states: Array[Dictionary] = []
	var expired_magic_ids: Array[String] = []
	for magic_id: String in network_projectiles:
		var projectile_ref: Variant = network_projectiles.get(magic_id)
		if is_instance_valid(projectile_ref) and not (projectile_ref as SpellProjectile).resolved:
			var projectile := projectile_ref as SpellProjectile
			projectile_states.append({"magic_id": magic_id, "position": projectile.global_position})
		else:
			expired_magic_ids.append(magic_id)
	for magic_id: String in expired_magic_ids:
		network_projectiles.erase(magic_id)
		network_projectile_spawn_data.erase(magic_id)
	for target_peer: int in NetworkManager.get_session_members(raid_session_id):
		receive_network_projectile_snapshots.rpc_id(target_peer, projectile_states)


func _create_network_raid_player(peer_id: int, spawn_position: Vector3, spawn_rotation_y: float) -> PlayerController:
	if network_players.has(peer_id):
		print("[PLAYER] Duplicate spawn ignored peer=%d" % peer_id)
		return network_players[peer_id] as PlayerController
	var network_player := player_scene.instantiate() as PlayerController
	network_player.name = "Player_%d" % peer_id
	network_player.in_raid = true
	network_player.configure_network(peer_id)
	runtime_actors.add_child(network_player)
	network_player.global_position = spawn_position
	network_player.rotation.y = spawn_rotation_y
	network_players[peer_id] = network_player
	var local_peer := multiplayer.get_unique_id()
	var is_local := not multiplayer.is_server() and peer_id == local_peer
	print("[PLAYER] init peer=%d local_peer=%d local=%s position=%s" % [peer_id, local_peer, str(is_local), str(spawn_position)])
	if not multiplayer.is_server() and peer_id == multiplayer.get_unique_id():
		player = network_player
		hud.visible = true
		hud.configure(self, player, weather)
		print("[PLAYER] Local player initialized peer=%d" % peer_id)
	return network_player


func _network_enemy_spawn_data(enemy: EnemyController) -> Dictionary:
	return {
		"enemy_id": enemy.network_enemy_id,
		"scene_path": enemy.scene_file_path,
		"enemy_data_path": enemy.enemy_data.resource_path if enemy.enemy_data != null else "",
		"enemy_type": enemy.enemy_type,
		"primary_element": enemy.primary_element,
		"patrol_radius": enemy.patrol_radius,
		"position": enemy.global_position,
		"rotation_y": enemy.rotation.y
	}


func _register_network_enemy(enemy: EnemyController) -> void:
	if not multiplayer.is_server() or enemy == null:
		return
	enemy.network_enemy_id = "enemy_%d" % _next_network_enemy_id
	_next_network_enemy_id += 1
	network_enemies[enemy.network_enemy_id] = enemy
	print("[ENEMY] spawn id=%s type=%s position=%s" % [enemy.network_enemy_id, enemy.enemy_type, str(enemy.global_position)])


func _serialize_spell_config(config: RuntimeSpellConfig) -> Dictionary:
	return {
		"spell_id": config.base_spell.spell_id,
		"damage": config.damage_or_healing,
		"range": config.range_meters,
		"speed": config.projectile_speed,
		"radius": config.area_radius,
		"trajectory": config.trajectory,
		"tags": config.behavior_tags,
		"pierce": config.pierce_count,
		"ricochet": config.ricochet_count
	}


func _deserialize_spell_config(data: Dictionary) -> RuntimeSpellConfig:
	var spell := ContentRegistry.spells().get(str(data.get("spell_id", ""))) as BaseSpellData
	if spell == null:
		return null
	var config := RuntimeSpellConfig.build(spell, [], null, null)
	config.damage_or_healing = float(data.get("damage", config.damage_or_healing))
	config.range_meters = float(data.get("range", config.range_meters))
	config.projectile_speed = float(data.get("speed", config.projectile_speed))
	config.area_radius = float(data.get("radius", config.area_radius))
	config.trajectory = str(data.get("trajectory", config.trajectory))
	config.pierce_count = int(data.get("pierce", config.pierce_count))
	config.ricochet_count = int(data.get("ricochet", config.ricochet_count))
	config.behavior_tags.clear()
	for tag: Variant in data.get("tags", []):
		config.behavior_tags.append(str(tag))
	return config


func _register_network_projectile(projectile: SpellProjectile, config: RuntimeSpellConfig, start: Vector3, direction: Vector3, team: String, target: Vector3, caster_label: String) -> void:
	if not multiplayer.is_server() or projectile == null:
		return
	var magic_id := "magic_%d" % _next_network_magic_id
	_next_network_magic_id += 1
	projectile.network_magic_id = magic_id
	network_projectiles[magic_id] = projectile
	projectile.projectile_resolved.connect(_on_network_projectile_resolved)
	var spawn_data := {
		"magic_id": magic_id,
		"scene_path": projectile.scene_file_path,
		"config": _serialize_spell_config(config),
		"start": start,
		"direction": direction,
		"team": team,
		"target": target,
		"caster": caster_label
	}
	network_projectile_spawn_data[magic_id] = spawn_data
	print("[MAGIC] server spawn id=%s caster=%s type=%s position=%s" % [magic_id, caster_label, config.base_spell.spell_id, str(start)])
	for peer_id: int in NetworkManager.get_session_members(raid_session_id):
		spawn_network_projectile.rpc_id(peer_id, spawn_data)


func _on_network_projectile_resolved(magic_id: String, reason: String) -> void:
	if not multiplayer.is_server() or not network_projectiles.has(magic_id):
		return
	network_projectiles.erase(magic_id)
	network_projectile_spawn_data.erase(magic_id)
	print("[PROJECTILE] despawn id=%s reason=%s" % [magic_id, reason])
	for peer_id: int in NetworkManager.get_session_members(raid_session_id):
		despawn_network_projectile.rpc_id(peer_id, magic_id, reason)


func _on_network_raid_peer_disconnected(peer_id: int) -> void:
	var network_player := network_players.get(peer_id) as PlayerController
	network_players.erase(peer_id)
	if is_instance_valid(network_player):
		network_player.queue_free()
	for target_peer: int in NetworkManager.get_session_members(raid_session_id):
		remove_network_raid_player.rpc_id(target_peer, peer_id)


@rpc("authority", "call_remote", "reliable")
func spawn_network_raid_player(peer_id: int, spawn_position: Vector3, spawn_rotation_y: float) -> void:
	if not multiplayer.is_server():
		_create_network_raid_player(peer_id, spawn_position, spawn_rotation_y)


@rpc("authority", "call_remote", "reliable")
func spawn_network_enemy(spawn_data: Dictionary) -> void:
	if multiplayer.is_server():
		return
	var enemy_id := str(spawn_data.get("enemy_id", ""))
	if enemy_id.is_empty() or network_enemies.has(enemy_id):
		return
	var scene_path := str(spawn_data.get("scene_path", ""))
	var scene := load(scene_path) as PackedScene
	if scene == null:
		push_error("[ENEMY] replication failed id=%s scene=%s" % [enemy_id, scene_path])
		return
	var enemy := scene.instantiate() as EnemyController
	if enemy == null:
		return
	var data_path := str(spawn_data.get("enemy_data_path", ""))
	if not data_path.is_empty():
		enemy.enemy_data = load(data_path) as EnemyData
	enemy.enemy_type = str(spawn_data.get("enemy_type", enemy.enemy_type))
	enemy.primary_element = str(spawn_data.get("primary_element", enemy.primary_element))
	enemy.patrol_radius = float(spawn_data.get("patrol_radius", enemy.patrol_radius))
	enemy.configure_network_replica(enemy_id)
	runtime_actors.add_child(enemy)
	var spawn_position: Vector3 = spawn_data.get("position", Vector3.ZERO)
	enemy.global_position = spawn_position
	enemy.rotation.y = float(spawn_data.get("rotation_y", 0.0))
	network_enemies[enemy_id] = enemy
	print("[ENEMY] replicated id=%s local_peer=%d position=%s" % [enemy_id, multiplayer.get_unique_id(), str(spawn_position)])


@rpc("authority", "call_remote", "reliable")
func spawn_network_projectile(spawn_data: Dictionary) -> void:
	if multiplayer.is_server():
		return
	var magic_id := str(spawn_data.get("magic_id", ""))
	if magic_id.is_empty():
		return
	var existing: Variant = network_projectiles.get(magic_id)
	if is_instance_valid(existing):
		return
	network_projectiles.erase(magic_id)
	var scene := load(str(spawn_data.get("scene_path", ""))) as PackedScene
	var config: RuntimeSpellConfig = _deserialize_spell_config(spawn_data.get("config", {}))
	if scene == null or config == null:
		push_error("[MAGIC] replication failed id=%s" % magic_id)
		return
	var projectile := scene.instantiate() as SpellProjectile
	if projectile == null:
		return
	var start: Vector3 = spawn_data.get("start", Vector3.ZERO)
	var direction: Vector3 = spawn_data.get("direction", Vector3.FORWARD)
	var target: Vector3 = spawn_data.get("target", Vector3.ZERO)
	temporary_effects.add_child(projectile)
	projectile.global_position = start
	projectile.configure_network_visual(magic_id, config, direction, str(spawn_data.get("team", "player")), target)
	network_projectiles[magic_id] = projectile
	projectile.projectile_resolved.connect(_on_network_projectile_replica_resolved)
	print("[MAGIC] client replicated id=%s local_peer=%d type=%s position=%s" % [magic_id, multiplayer.get_unique_id(), config.base_spell.spell_id, str(start)])


func _on_network_projectile_replica_resolved(magic_id: String, _reason: String) -> void:
	network_projectiles.erase(magic_id)


@rpc("authority", "call_remote", "reliable")
func despawn_network_projectile(magic_id: String, reason: String) -> void:
	if multiplayer.is_server():
		return
	var projectile_ref: Variant = network_projectiles.get(magic_id)
	network_projectiles.erase(magic_id)
	if is_instance_valid(projectile_ref):
		(projectile_ref as SpellProjectile).queue_free()
	print("[PROJECTILE] despawn id=%s reason=%s" % [magic_id, reason])


@rpc("authority", "call_remote", "reliable")
func remove_network_raid_player(peer_id: int) -> void:
	if multiplayer.is_server():
		return
	var network_player := network_players.get(peer_id) as PlayerController
	network_players.erase(peer_id)
	if is_instance_valid(network_player):
		network_player.queue_free()


@rpc("authority", "call_remote", "unreliable", 1)
func receive_network_enemy_snapshots(states: Array[Dictionary]) -> void:
	if multiplayer.is_server():
		return
	for state: Dictionary in states:
		var enemy := network_enemies.get(str(state.get("enemy_id", ""))) as EnemyController
		if is_instance_valid(enemy):
			enemy.receive_network_snapshot(state)


@rpc("authority", "call_remote", "unreliable", 1)
func receive_network_projectile_snapshots(states: Array[Dictionary]) -> void:
	if multiplayer.is_server():
		return
	for state: Dictionary in states:
		var projectile_ref: Variant = network_projectiles.get(str(state.get("magic_id", "")))
		if is_instance_valid(projectile_ref):
			(projectile_ref as SpellProjectile).receive_network_snapshot(state)


@rpc("authority", "call_remote", "unreliable", 1)
func receive_network_raid_snapshots(states: Array[Dictionary]) -> void:
	if multiplayer.is_server():
		return
	for state: Dictionary in states:
		var network_player := network_players.get(int(state.get("peer_id", 0))) as PlayerController
		if is_instance_valid(network_player):
			network_player.receive_network_snapshot(state)

func _configure_region() -> void:
	var environment := world_environment.environment.duplicate() as Environment
	world_environment.environment = environment
	environment.background_color = environment.background_color.lerp(region_tint, 0.28)
	environment.ambient_light_color = environment.ambient_light_color.lerp(region_tint, 0.22)
	if region_id != REGION_GRAPH.ENTRY_REGION_ID:
		for extraction: Node in extraction_zones.get_children():
			extraction.visible = false
			extraction.process_mode = Node.PROCESS_MODE_DISABLED
	_spawn_region_hazards()

func _spawn_region_hazards() -> void:
	if hazard_type in ["burn_zones", "water_slow"] and elemental_hazard_scene != null:
		var hazard_positions: Array[Vector3] = [Vector3(-8, 0.05, -2), Vector3(7, 0.05, 8), Vector3(11, 0.05, -11)]
		if hazard_type == "water_slow":
			hazard_positions = [
				Vector3(-12, 0.05, -3), Vector3(-7, 0.05, 9), Vector3(0, 0.05, 5),
				Vector3(8, 0.05, 10), Vector3(13, 0.05, -7), Vector3(-14, 0.05, -12),
				Vector3(2, 0.05, -14)
			]
		for position: Vector3 in hazard_positions:
			var hazard := elemental_hazard_scene.instantiate() as ElementalHazardZone
			hazard.hazard_element = "fire" if hazard_type == "burn_zones" else "water"
			hazard.power_per_second = 7.0
			hazard.water_slow_multiplier = 0.5
			hazard.radius = 4.0 if hazard_type == "water_slow" else 3.0
			temporary_effects.add_child(hazard)
			hazard.global_position = position
	elif hazard_type == "temporary_grass_walls" and temporary_grass_wall_scene != null:
		grass_wall_refresh_remaining = grass_wall_refresh_seconds
		_refresh_grass_walls()

func _update_grass_wall_cycle(delta: float) -> void:
	if explosion_devastated or hazard_type != "temporary_grass_walls" or temporary_grass_wall_scene == null:
		return
	grass_wall_refresh_remaining -= delta
	if grass_wall_refresh_remaining > 0.0:
		return
	grass_wall_refresh_remaining = grass_wall_refresh_seconds
	_refresh_grass_walls()

func _refresh_grass_walls() -> void:
	for child: Node in temporary_effects.get_children():
		if child is TemporaryGrassWall:
			temporary_effects.remove_child(child)
			child.queue_free()
	var available: Array[Dictionary] = GRASS_WALL_PLACEMENTS.duplicate(true)
	for index: int in range(available.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var held: Dictionary = available[index]
		available[index] = available[swap_index]
		available[swap_index] = held
	for index: int in range(mini(grass_wall_count, available.size())):
		var placement: Dictionary = available[index]
		var wall := temporary_grass_wall_scene.instantiate() as TemporaryGrassWall
		temporary_effects.add_child(wall)
		wall.global_position = placement.position
		wall.rotation_degrees.y = float(placement.rotation) + rng.randf_range(-12.0, 12.0)
	grass_wall_generation += 1

func _configure_weather() -> void:
	weather = weather_options[rng.randi_range(0, weather_options.size() - 1)] if not weather_options.is_empty() else "Clear"
	var environment := world_environment.environment.duplicate() as Environment
	world_environment.environment = environment
	match weather:
		"Rain haze":
			environment.background_color = Color("4d5f63")
			environment.ambient_light_color = Color("82989b")
			environment.ambient_light_energy = 0.72
			vision_radius = fog_vision_radius
			enemy_detection_multiplier = 0.82
			sun.light_energy = 0.58
		"Dusk":
			environment.background_color = Color("332f43")
			environment.ambient_light_color = Color("68627d")
			environment.ambient_light_energy = 0.52
			vision_radius = dusk_vision_radius
			enemy_detection_multiplier = 0.9
			sun.light_energy = 0.58
		_:
			vision_radius = clear_vision_radius
			enemy_detection_multiplier = 1.0
			sun.light_energy = 1.0

func _spawn_player() -> void:
	player = player_scene.instantiate() as PlayerController
	player.in_raid = true
	player.position = runtime_actors.to_local(player_spawn.global_position)
	player.rotation_degrees.y = player_spawn.facing_direction_degrees
	runtime_actors.add_child(player)
	player.restore_raid_state(GameState.raid_player_state)

func capture_region_travel_state() -> void:
	if player != null and is_instance_valid(player):
		GameState.raid_player_state = player.capture_raid_state()
	GameState.raid_kills = kills.duplicate(true)

func _activate_containers() -> void:
	for child: Node in loot_containers.get_children():
		if not child is LootContainer:
			continue
		var container := child as LootContainer
		if rng.randf() > container.activation_chance:
			container.visible = false
			container.process_mode = Node.PROCESS_MODE_DISABLED
			container.remove_from_group("interactable")

func _spawn_editor_placed_enemies() -> void:
	for child: Node in enemy_spawns.get_children():
		if child is EnemySpawnPoint:
			var spawned := (child as EnemySpawnPoint).spawn_enemies(runtime_actors, rng)
			for enemy: EnemyController in spawned:
				enemy.primary_element = region_primary_element
				if NetworkManager.is_network_game() and multiplayer.is_server():
					_register_network_enemy(enemy)

func _spawn_editor_placed_loot() -> void:
	for child: Node in loot_spawns.get_children():
		if child is LootSpawnPoint:
			(child as LootSpawnPoint).spawn_loot(loot_containers, rng)

func _update_visibility() -> void:
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if node is EnemyController:
			var enemy := node as EnemyController
			if not is_ancestor_of(enemy):
				continue
			var distance: float = player.global_position.distance_to(enemy.global_position)
			enemy.visible = distance < 3.2 or (distance <= vision_radius and has_clear_line(player.global_position + Vector3.UP, enemy.global_position + Vector3.UP, [player.get_rid(), enemy.get_rid()]))

func toggle_inventory() -> void:
	hud.toggle_inventory()


func is_aim_ui_open() -> bool:
	return hud != null and hud.is_aim_ui_open()

func show_loot(container: LootContainer) -> void:
	hud.show_loot(container)

func equip_raid_item(item_id: String) -> void:
	var category: String = str(ItemDB.get_item(item_id).get("category", ""))
	if category == "spell":
		equip_raid_spell_to_page(item_id, clampi(player.selected_page, 0, 2))
		return
	var slot: String = ""
	match category:
		"spellbook": slot = "spellbook"
		"focus": slot = "focus"
		"armor_head": slot = "head"
		"armor_chest", "armor": slot = "chest"
		"accessory": slot = "accessory_1" if str(GameState.loadout.get("accessory_1", "")).is_empty() else "accessory_2"
		"backpack": slot = "backpack"
		"dagger", "melee": slot = "dagger"
	equip_raid_item_to_slot(item_id, slot)

func equip_raid_spell_to_page(item_id: String, page_index: int) -> bool:
	if page_index < 0 or page_index >= GameState.spell_pages.size() or ItemDB.spell(item_id) == null or not GameState.remove_raid_item(item_id, 1):
		return false
	var old_spell: String = str(GameState.spell_pages[page_index].get("spell_item", ""))
	if not old_spell.is_empty():
		GameState.add_raid_item(old_spell, 1)
	for modifier_id: Variant in GameState.spell_pages[page_index].get("modifiers", []):
		GameState.add_raid_item(str(modifier_id), 1)
	GameState.spell_pages[page_index] = {"spell_item":item_id, "modifiers":[]}
	GameState._save_spellbook_change()
	player._rebuild_spell_pages()
	hud.refresh_inventory()
	hud.refresh_spell_settings()
	return true

func equip_raid_item_to_slot(item_id: String, slot: String) -> bool:
	var category: String = str(ItemDB.get_item(item_id).get("category", ""))
	var accepted: Array = {
		"spellbook":["spellbook"], "focus":["focus"], "dagger":["dagger", "melee"],
		"head":["armor_head"], "chest":["armor_chest", "armor"],
		"accessory_1":["accessory"], "accessory_2":["accessory"], "backpack":["backpack"]
	}.get(slot, [])
	if slot.is_empty() or category not in accepted or not GameState.remove_raid_item(item_id, 1):
		return false
	var old: String = str(GameState.loadout.get(slot, ""))
	if not old.is_empty():
		GameState.add_raid_item(old, 1)
	GameState.loadout[slot] = item_id
	player._configure_equipment_stats()
	player._rebuild_spell_pages()
	hud.refresh_inventory()
	return true

func unequip_raid_slot(slot: String) -> bool:
	var item_id: String = str(GameState.loadout.get(slot, ""))
	if item_id.is_empty() or not GameState.can_add_raid_item(item_id, 1):
		return false
	GameState.loadout[slot] = ""
	GameState.add_raid_item(item_id, 1)
	player._configure_equipment_stats()
	player._rebuild_spell_pages()
	hud.refresh_inventory()
	return true

func install_raid_modifier(page_index: int, item_id: String) -> Dictionary:
	if page_index < 0 or page_index >= GameState.spell_pages.size():
		return {"success":false, "message":"Invalid spell page."}
	var modifier := ItemDB.modifier(item_id)
	var spell := ItemDB.spell(str(GameState.spell_pages[page_index].get("spell_item", "")))
	if modifier == null or not modifier.is_compatible(spell):
		return {"success":false, "message":"That rune is incompatible with this formula."}
	var installed: Array = GameState.spell_pages[page_index].get("modifiers", [])
	var book := GameState.equipped_spellbook()
	if book == null or installed.size() >= book.maximum_modifiers_per_page or item_id in installed:
		return {"success":false, "message":"No compatible open rune socket."}
	if not GameState.remove_raid_item(item_id, 1):
		return {"success":false, "message":"The rune is not in the field pack."}
	installed.append(item_id)
	GameState.spell_pages[page_index].modifiers = installed
	GameState._save_spellbook_change()
	player._rebuild_spell_pages()
	hud.refresh_inventory()
	hud.refresh_spell_settings()
	return {"success":true, "message":"Rune installed."}

func remove_raid_modifier(page_index: int, modifier_index: int) -> bool:
	if page_index < 0 or page_index >= GameState.spell_pages.size():
		return false
	var installed: Array = GameState.spell_pages[page_index].get("modifiers", [])
	if modifier_index < 0 or modifier_index >= installed.size():
		return false
	var item_id: String = str(installed[modifier_index])
	if not GameState.can_add_raid_item(item_id, 1):
		return false
	installed.remove_at(modifier_index)
	GameState.spell_pages[page_index].modifiers = installed
	GameState.add_raid_item(item_id, 1)
	GameState._save_spellbook_change()
	player._rebuild_spell_pages()
	hud.refresh_inventory()
	hud.refresh_spell_settings()
	return true

func enemy_defeated(enemy_type: String, at: Vector3) -> void:
	kills[enemy_type] = int(kills.get(enemy_type, 0)) + 1
	GameState.raid_kills[enemy_type] = int(kills[enemy_type])
	var table: LootTableData = boss_drop_table if enemy_type == "boss" else mage_drop_table if enemy_type in ["mage", "construct"] else monster_drop_table
	var items: Dictionary = table.roll(rng) if table != null else {"arcane_dust":1}
	var drop := enemy_drop_container_scene.instantiate() as LootContainer
	drop.container_id = "enemy_remains"
	drop.container_name = "%s remains" % enemy_type.capitalize()
	drop.search_duration = 0.25
	drop.set_preset_loot(items)
	runtime_actors.add_child(drop)
	drop.global_position = at

func notify_spell_cast(position: Vector3, radius: float) -> void:
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if is_ancestor_of(node) and node.has_method("hear_spell"):
			node.hear_spell(position, radius)

func spawn_player_spell(caster: PlayerController, config: RuntimeSpellConfig, start: Vector3, direction: Vector3, target: Vector3 = Vector3.ZERO) -> SpellProjectile:
	if config == null or config.base_spell == null or config.base_spell.projectile_scene == null:
		return null
	var projectile := config.base_spell.projectile_scene.instantiate() as SpellProjectile
	temporary_effects.add_child(projectile)
	projectile.global_position = start
	projectile.configure(caster, config, direction, "player", target)
	if NetworkManager.is_network_game() and multiplayer.is_server():
		_register_network_projectile(projectile, config, start, direction, "player", target, "peer:%d" % caster.network_peer_id)
	return projectile

func spawn_enemy_spell(caster: EnemyController, spell: BaseSpellData, start: Vector3, target: Vector3, attack_damage: float) -> SpellProjectile:
	if spell == null or spell.projectile_scene == null:
		return null
	var config := RuntimeSpellConfig.build(spell, [], null, null)
	config.damage_or_healing = attack_damage
	config.area_radius = minf(config.area_radius, 0.75)
	spawn_cast_release(start, spell.primary_element, spell.debug_color, float(_next_network_magic_id))
	var projectile := spell.projectile_scene.instantiate() as SpellProjectile
	temporary_effects.add_child(projectile)
	projectile.global_position = start
	var direction: Vector3 = target + Vector3(0, 0.8, 0) - start
	direction.y = 0.0
	projectile.configure(caster, config, direction.normalized(), "enemy", target)
	if NetworkManager.is_network_game() and multiplayer.is_server():
		_register_network_projectile(projectile, config, start, direction.normalized(), "enemy", target, "enemy:%s" % caster.network_enemy_id)
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
		field.global_position = target
		field.global_position.y = 0.08
		field.rotation.y = caster.rotation.y
		field.configure(caster, config)
		return field
	if behavior == "cone":
		_cast_cone(config, start, direction)
	elif behavior == "chain":
		_cast_chain(config, start, target)
	elif behavior == "beam":
		_cast_beam(config, start, target)
	elif behavior == "teleport":
		caster.global_position = target + Vector3(0, 0.05, 0)
		spawn_spell_impact(target, config.base_spell.debug_color, 1.2, config.base_spell.primary_element, 4.0)
	elif behavior == "mana_restore":
		caster.restore_mana(maxf(config.damage_or_healing, config.secondary_power))
		spawn_spell_impact(caster.global_position, config.base_spell.debug_color, 1.4, "neutral", 6.0)
	elif behavior == "cleanse":
		caster.cleanse_statuses()
		caster.restore_health(config.damage_or_healing * 0.35)
		spawn_spell_impact(caster.global_position, config.base_spell.debug_color, 1.8, "neutral", 8.0)
	elif behavior == "shield":
		caster.add_ward(config.damage_or_healing)
		spawn_spell_impact(caster.global_position, config.base_spell.debug_color, 2.0, "neutral", 11.0)
	elif behavior == "knockback":
		for node: Node in get_tree().get_nodes_in_group("enemies"):
			if node is EnemyController and is_ancestor_of(node):
				var offset: Vector3 = (node as Node3D).global_position - caster.global_position
				offset.y = 0.0
				if offset.length() <= config.area_radius:
					node.take_damage(config.damage_or_healing, caster.global_position, 0.0, "neutral")
					node.apply_knockback(offset.normalized() * maxf(5.0, config.effect_power))
		spawn_spell_impact(caster.global_position, config.base_spell.debug_color, config.area_radius, "neutral", 13.0)
	return null

func play_explosion_sequence(caster: PlayerController) -> bool:
	if caster == null or not is_instance_valid(caster) or not GameState.consume_explosion_use():
		show_message("Explosion has already been consumed during this expedition.")
		return false
	var cutscene_layer := CanvasLayer.new()
	cutscene_layer.name = "ExplosionCutscene"
	cutscene_layer.layer = 300
	cutscene_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cutscene_layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cutscene_layer.add_child(backdrop)
	var video := VideoStreamPlayer.new()
	video.name = "ExplosionVideo"
	video.stream = EXPLOSION_CUTSCENE
	video.expand = true
	video.volume_db = 0.0
	video.process_mode = Node.PROCESS_MODE_ALWAYS
	video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cutscene_layer.add_child(video)
	var previous_pause: bool = get_tree().paused
	get_tree().paused = true
	video.play()
	await video.finished
	get_tree().paused = previous_pause
	if is_instance_valid(cutscene_layer):
		cutscene_layer.queue_free()
	if not is_inside_tree() or caster == null or not is_instance_valid(caster):
		return false
	apply_explosion_effects(caster)
	return true

func apply_explosion_effects(caster: PlayerController) -> Dictionary:
	var result := {"enemies_hit":0, "structures_destroyed":0, "loot_destroyed":0}
	if caster == null or not is_instance_valid(caster):
		return result
	_spawn_fullscreen_explosion()
	explosion_devastated = true
	var facing: Vector3 = -caster.global_transform.basis.z
	facing.y = 0.0
	facing = facing.normalized()
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if not node is EnemyController or not is_ancestor_of(node):
			continue
		var offset: Vector3 = (node as Node3D).global_position - caster.global_position
		offset.y = 0.0
		if offset.length_squared() <= 0.001 or facing.dot(offset.normalized()) <= 0.0:
			continue
		(node as EnemyController).take_explosion_damage(500.0, caster.global_position)
		result.enemies_hit = int(result.enemies_hit) + 1
	for root: Node3D in [destructible_buildings, destructible_cover]:
		for structure: Node in root.get_children():
			structure.queue_free()
			result.structures_destroyed = int(result.structures_destroyed) + 1
	for effect: Node in temporary_effects.get_children():
		var is_wall: bool = effect is TemporaryGrassWall
		if effect is ElementalSpellField:
			var field := effect as ElementalSpellField
			is_wall = field.config != null and field.config.behavior_type in ["wall", "barrier"]
		if is_wall:
			effect.queue_free()
			result.structures_destroyed = int(result.structures_destroyed) + 1
	# Search the whole active region so editor-placed chests, spawned containers,
	# inactive boxes, and enemy remains created by the blast are all removed.
	for descendant: Node in find_children("*", "", true, false):
		if descendant is LootContainer and not descendant.is_queued_for_deletion():
			descendant.queue_free()
			result.loot_destroyed = int(result.loot_destroyed) + 1
	if hud != null:
		hud.dismiss_loot()
	caster.apply_exhaustion(3.0)
	for ring_index: int in range(20):
		var angle: float = TAU * float(ring_index) / 20.0
		var distance: float = 3.0 + float(ring_index % 5) * 3.8
		spawn_spell_impact(caster.global_position + Vector3(cos(angle), 0.25, sin(angle)) * distance, Color("ff3208"), 2.4 + float(ring_index % 4), "fire", float(ring_index) * 1.7)
	show_message("EXPLOSION - the region is devastated. You are exhausted.")
	return result

func _spawn_fullscreen_explosion() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ExplosionScreenEffect"
	layer.layer = 250
	add_child(layer)
	var blast := ColorRect.new()
	blast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blast.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = EXPLOSION_SCREEN_SHADER
	material.set_shader_parameter("blast_progress", 0.0)
	blast.material = material
	layer.add_child(blast)
	var tween := blast.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(func(progress: float) -> void: material.set_shader_parameter("blast_progress", progress), 0.0, 1.0, 1.65)
	tween.tween_callback(layer.queue_free)

func _cast_cone(config: RuntimeSpellConfig, start: Vector3, direction: Vector3) -> void:
	for step: int in range(1, 7):
		spawn_spell_impact(start + direction * (float(step) * config.range_meters / 6.0), config.base_spell.debug_color, 0.35 + step * 0.13, config.base_spell.primary_element, float(step))
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if not node is EnemyController or not is_ancestor_of(node):
			continue
		var offset: Vector3 = (node as Node3D).global_position - start
		offset.y = 0.0
		if offset.length() <= config.range_meters and direction.angle_to(offset.normalized()) <= deg_to_rad(34.0):
			node.take_damage(config.damage_or_healing, start, 0.0, config.base_spell.primary_element)
			if not config.status_effect.is_empty():
				node.apply_status(config.status_effect, maxf(1.0, config.effect_duration), maxf(0.35, config.effect_power))

func _cast_chain(config: RuntimeSpellConfig, start: Vector3, target: Vector3) -> void:
	var candidates: Array[EnemyController] = []
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if node is EnemyController and is_ancestor_of(node) and (node as Node3D).global_position.distance_to(target) <= config.range_meters:
			candidates.append(node as EnemyController)
	candidates.sort_custom(func(a: EnemyController, b: EnemyController) -> bool: return a.global_position.distance_to(target) < b.global_position.distance_to(target))
	var from: Vector3 = start
	for index: int in range(mini(candidates.size(), maxi(3, config.projectile_count + 2))):
		var enemy: EnemyController = candidates[index]
		spawn_shot_tracer(from, enemy.global_position + Vector3.UP, VisualFactory.spell_accent_color(config.base_spell.primary_element))
		enemy.take_damage(config.damage_or_healing * pow(0.82, index), start, 0.0, config.base_spell.primary_element)
		from = enemy.global_position + Vector3.UP

func _cast_beam(config: RuntimeSpellConfig, start: Vector3, target: Vector3) -> void:
	spawn_shot_tracer(start, target, VisualFactory.spell_accent_color(config.base_spell.primary_element))
	var segment: Vector3 = target - start
	var segment_length_sq: float = maxf(0.01, segment.length_squared())
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if not node is EnemyController or not is_ancestor_of(node):
			continue
		var point: Vector3 = (node as Node3D).global_position + Vector3.UP * 0.5
		var t: float = clampf((point - start).dot(segment) / segment_length_sq, 0.0, 1.0)
		if point.distance_to(start + segment * t) <= maxf(0.65, config.area_radius):
			node.take_damage(config.damage_or_healing, start, 0.0, config.base_spell.primary_element)

func spawn_spell_impact(at: Vector3, color: Color, radius: float, primary_element: String = "neutral", variant_seed: float = 0.0) -> void:
	if NetworkManager.is_network_game() and multiplayer.is_server():
		for peer_id: int in NetworkManager.get_session_members(raid_session_id):
			show_network_spell_impact.rpc_id(peer_id, at, color, radius, primary_element, variant_seed)
		return
	var impact_root := Node3D.new()
	impact_root.name = "SpellImpactEffect"
	temporary_effects.add_child(impact_root)
	impact_root.global_position = at
	var impact := MeshInstance3D.new()
	impact_root.add_child(impact)
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.material = VisualFactory.elemental_spell_material(primary_element, color, 5.0, variant_seed)
	impact.mesh = sphere
	impact.scale = Vector3.ONE * 0.15
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.38
	torus.outer_radius = 0.5
	torus.rings = 24
	torus.ring_segments = 10
	torus.material = VisualFactory.elemental_spell_material(primary_element, color, 4.2, variant_seed + 3.0)
	ring.mesh = torus
	ring.rotation_degrees.x = 90.0
	ring.scale = Vector3.ONE * 0.12
	impact_root.add_child(ring)
	var particles := GPUParticles3D.new()
	particles.amount = 36
	particles.lifetime = 0.7
	particles.one_shot = true
	particles.explosiveness = 0.95
	var particle_process := ParticleProcessMaterial.new()
	particle_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_process.emission_sphere_radius = maxf(0.12, radius * 0.12)
	particle_process.direction = Vector3(0, 1, 0)
	particle_process.spread = 180.0
	particle_process.initial_velocity_min = 2.5
	particle_process.initial_velocity_max = 6.5
	particle_process.gravity = Vector3(0, 2.0, 0) if primary_element == "fire" else Vector3(0, -1.8, 0) if primary_element == "water" else Vector3(0, 0.8, 0)
	particle_process.scale_min = 0.05
	particle_process.scale_max = 0.14
	particle_process.color = VisualFactory.spell_accent_color(primary_element)
	particles.process_material = particle_process
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.045
	particle_mesh.height = 0.09
	particle_mesh.material = VisualFactory.elemental_spell_material(primary_element, color, 4.8, variant_seed + 6.0)
	particles.draw_pass_1 = particle_mesh
	impact_root.add_child(particles)
	particles.emitting = true
	var tween := impact.create_tween()
	tween.tween_property(impact, "scale", Vector3.ONE * radius * 2.0, 0.14)
	tween.parallel().tween_property(impact, "transparency", 1.0, 0.18)
	var ring_tween := ring.create_tween()
	ring_tween.tween_property(ring, "scale", Vector3.ONE * radius * 3.0, 0.28).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	ring_tween.parallel().tween_property(ring, "rotation_degrees:y", 180.0, 0.34)
	ring_tween.parallel().tween_property(ring, "transparency", 1.0, 0.34)
	get_tree().create_timer(0.85).timeout.connect(func() -> void: if is_instance_valid(impact_root): impact_root.queue_free())


@rpc("authority", "call_remote", "reliable")
func show_network_spell_impact(at: Vector3, color: Color, radius: float, primary_element: String, variant_seed: float) -> void:
	if not multiplayer.is_server():
		spawn_spell_impact(at, color, radius, primary_element, variant_seed)

func spawn_cast_release(at: Vector3, primary_element: String, color: Color, variant_seed: float = 0.0) -> void:
	if NetworkManager.is_network_game() and multiplayer.is_server():
		for peer_id: int in NetworkManager.get_session_members(raid_session_id):
			show_network_cast_release.rpc_id(peer_id, at, primary_element, color, variant_seed)
		return
	var release := MeshInstance3D.new()
	release.name = "SpellCastRelease"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.18
	torus.outer_radius = 0.28
	torus.rings = 20
	torus.ring_segments = 9
	torus.material = VisualFactory.elemental_spell_material(primary_element, color, 4.6, variant_seed + 8.0)
	release.mesh = torus
	release.rotation_degrees.x = 90.0
	temporary_effects.add_child(release)
	release.global_position = at
	release.scale = Vector3.ONE * 0.2
	var tween := release.create_tween()
	tween.tween_property(release, "scale", Vector3.ONE * 2.1, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(release, "rotation_degrees:y", 150.0, 0.25)
	tween.parallel().tween_property(release, "transparency", 1.0, 0.28)
	tween.tween_callback(release.queue_free)


@rpc("authority", "call_remote", "reliable")
func show_network_cast_release(at: Vector3, primary_element: String, color: Color, variant_seed: float) -> void:
	if not multiplayer.is_server():
		spawn_cast_release(at, primary_element, color, variant_seed)

func schedule_spell_echo(config: RuntimeSpellConfig, at: Vector3) -> void:
	get_tree().create_timer(0.75).timeout.connect(func() -> void:
		spawn_spell_impact(at, config.base_spell.debug_color, maxf(0.8, config.area_radius), config.base_spell.primary_element, 17.0)
		for target: Node in get_tree().get_nodes_in_group("enemies"):
			if target is Node3D and is_ancestor_of(target):
				var offset: Vector3 = (target as Node3D).global_position - at
				offset.y = 0.0
				if offset.length() <= maxf(0.8, config.area_radius):
					target.take_damage(config.damage_or_healing * 0.55, at, 0.0, config.base_spell.primary_element)
	)

func spawn_shot_tracer(start: Vector3, end: Vector3, color: Color) -> void:
	if NetworkManager.is_network_game() and multiplayer.is_server():
		for peer_id: int in NetworkManager.get_session_members(raid_session_id):
			show_network_shot_tracer.rpc_id(peer_id, start, end, color)
		return
	var tracer := MeshInstance3D.new()
	tracer.name = "TracerEffect"
	var box := BoxMesh.new()
	var length: float = start.distance_to(end)
	box.size = Vector3(0.035, 0.035, length)
	box.material = VisualFactory.material(color, 2.2)
	tracer.mesh = box
	temporary_effects.add_child(tracer)
	tracer.global_position = (start + end) * 0.5
	tracer.look_at(end, Vector3.UP)
	var tween := tracer.create_tween()
	tween.tween_property(tracer, "scale", Vector3(1, 1, 0.1), 0.07)
	tween.tween_callback(tracer.queue_free)


@rpc("authority", "call_remote", "reliable")
func show_network_shot_tracer(start: Vector3, end: Vector3, color: Color) -> void:
	if not multiplayer.is_server():
		spawn_shot_tracer(start, end, color)

func has_clear_line(from: Vector3, to: Vector3, exclude: Array) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = exclude
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func detection_multiplier() -> float:
	return enemy_detection_multiplier

func set_extraction_status(text: String) -> void:
	hud.set_extraction_status(text)

func complete_extraction(extraction_name: String) -> void:
	if raid_complete:
		return
	if NetworkManager.is_connected_to_server():
		raid_complete = true
		hud.set_extraction_status("EXTRACTION CONFIRMED")
		NetworkManager.request_raid_extraction(extraction_name)
		return
	raid_complete = true
	var summary: Dictionary = GameState.finish_raid(true, kills, extraction_name)
	var main: Node = get_tree().current_scene
	if main.has_method("show_end_screen"):
		main.show_end_screen(summary)


func extract_network_player(peer_id: int, extraction_name: String) -> bool:
	if not multiplayer.is_server():
		return false
	var network_player := network_players.get(peer_id) as PlayerController
	if not is_instance_valid(network_player):
		return false
	if not _can_extract_network_player(network_player, extraction_name):
		print("[RAID] rejected extraction peer=%d reason=outside_zone" % peer_id)
		return false
	network_players.erase(peer_id)
	network_player.queue_free()
	for target_peer: int in NetworkManager.get_session_members(raid_session_id):
		remove_network_raid_player.rpc_id(target_peer, peer_id)
	print("[RAID %s] extracted peer=%d via=%s" % [raid_session_id, peer_id, extraction_name])
	return true


func _can_extract_network_player(network_player: PlayerController, extraction_name: String) -> bool:
	for zone: Node in extraction_zones.get_children():
		if not zone is ExtractionZone:
			continue
		var extraction := zone as ExtractionZone
		if extraction.extraction_name != extraction_name:
			continue
		return extraction.global_position.distance_to(network_player.global_position) <= extraction.radius + 0.25
	return false

func on_player_died() -> void:
	if raid_complete:
		return
	raid_complete = true
	hud.set_extraction_status("YOUR SPELLBOOK FALLS SILENT")
	await get_tree().create_timer(1.2).timeout
	var summary: Dictionary = GameState.finish_raid(false, kills)
	var main: Node = get_tree().current_scene
	if main.has_method("show_end_screen"):
		main.show_end_screen(summary)

func show_message(text: String) -> void:
	hud.show_message(text)
