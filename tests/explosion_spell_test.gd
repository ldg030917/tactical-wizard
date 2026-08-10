extends Node

var failures: Array[String] = []

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("EXPLOSION TEST: " + message)

func _ready() -> void:
	GameState.reset_save_for_debug()
	var spell := ItemDB.spell("explosion_page")
	_check(spell != null and spell.spell_id == "explosion" and spell.primary_element == "fire", "Explosion is not a registered fire spell")
	_check(spell != null and spell.compatible_modifier_categories.is_empty(), "Explosion exposes attachment categories")
	var any_compatible_modifier := false
	for modifier: SpellModifierData in ContentRegistry.modifiers().values():
		any_compatible_modifier = any_compatible_modifier or modifier.is_compatible(spell)
	_check(not any_compatible_modifier, "A rune can still attach to Explosion")
	_check(FileAccess.file_exists("res://assets/cutscenes/explosion.ogv") and load("res://assets/cutscenes/explosion.ogv") is VideoStream, "The exported-compatible Explosion cutscene is missing")
	var playback_probe := VideoStreamPlayer.new()
	playback_probe.stream = load("res://assets/cutscenes/explosion.ogv") as VideoStream
	playback_probe.process_mode = Node.PROCESS_MODE_ALWAYS
	playback_probe.volume_db = -80.0
	add_child(playback_probe)
	get_tree().paused = true
	playback_probe.play()
	await get_tree().create_timer(0.25, true).timeout
	_check(playback_probe.is_playing() and playback_probe.stream_position > 0.0, "The cutscene does not advance while gameplay is paused")
	playback_probe.stop()
	playback_probe.queue_free()
	get_tree().paused = false
	_check(FileAccess.file_exists("res://shaders/explosion_screen.gdshader"), "The full-screen explosion shader is missing")
	_check(int(GameState.stash.get("explosion_page", 0)) == 1, "Explosion is unavailable to a starting profile")

	GameState.spell_pages[0] = {"spell_item":"explosion_page", "modifiers":[]}
	GameState.begin_raid()
	var raid := (load("res://scenes/raid/raid_map.tscn") as PackedScene).instantiate() as RaidScene
	add_child(raid)
	await get_tree().process_frame
	await get_tree().process_frame
	var player := raid.player
	player._rebuild_spell_pages()
	player.select_spell_page(0)
	player.mana = player.max_mana - 0.5
	_check(not player.begin_cast(), "Explosion began casting without 100 percent mana")
	player.mana = player.max_mana
	_check(player.begin_cast() and is_equal_approx(player.cast_duration, 1.0), "Explosion does not use an exact one-second cast")
	player.cancel_cast()
	_check(GameState.consume_explosion_use(), "Explosion could not consume its expedition use")
	_check(not GameState.can_use_explosion() and not GameState.consume_explosion_use(), "Explosion can be used more than once per expedition")

	var enemy_scene := load("res://scenes/enemies/melee_enemy.tscn") as PackedScene
	var front_enemy := enemy_scene.instantiate() as EnemyController
	var rear_enemy := enemy_scene.instantiate() as EnemyController
	raid.runtime_actors.add_child(front_enemy)
	raid.runtime_actors.add_child(rear_enemy)
	front_enemy.set_physics_process(false)
	rear_enemy.set_physics_process(false)
	front_enemy.health = 1000.0
	front_enemy.max_health = 1000.0
	rear_enemy.health = 1000.0
	rear_enemy.max_health = 1000.0
	var facing: Vector3 = -player.global_transform.basis.z
	facing.y = 0.0
	facing = facing.normalized()
	front_enemy.global_position = player.global_position + facing * 5.0
	rear_enemy.global_position = player.global_position - facing * 5.0
	var boundary_count: int = raid.outer_boundaries.get_child_count()
	var structure_count: int = raid.destructible_buildings.get_child_count() + raid.destructible_cover.get_child_count()
	var existing_loot: int = 0
	for node: Node in raid.find_children("*", "", true, false):
		if node is LootContainer:
			existing_loot += 1
	var result: Dictionary = raid.apply_explosion_effects(player)
	_check(int(result.enemies_hit) >= 1 and is_equal_approx(front_enemy.health, 500.0), "Enemies in front did not receive exactly 500 damage")
	_check(is_equal_approx(rear_enemy.health, 1000.0), "An enemy behind the player was damaged")
	_check(int(result.structures_destroyed) >= structure_count and structure_count > 0 and raid.explosion_devastated, "Buildings and interior walls were not targeted for destruction")
	_check(int(result.loot_destroyed) >= existing_loot and existing_loot > 0, "Existing lootboxes were not targeted for deletion")
	_check(raid.outer_boundaries.get_child_count() == boundary_count and boundary_count == 4, "The map's outermost walls were destroyed")
	_check(raid.find_child("ExplosionScreenEffect", true, false) != null, "The whole-screen explosion effect did not appear")
	_check(player.stamina == 0.0 and player.exhaustion_remaining > 2.9, "Explosion did not begin a three-second zero-stamina exhaustion")
	player._update_status(2.9)
	_check(player.exhaustion_remaining > 0.0 and player.stamina == 0.0, "Exhaustion ended before three seconds")
	player._update_status(0.2)
	_check(is_zero_approx(player.exhaustion_remaining), "Exhaustion did not end after three seconds")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(raid.destructible_buildings.get_child_count() == 0 and raid.destructible_cover.get_child_count() == 0, "Destroyed structures remained in the region")
	var remaining_loot: int = 0
	for node: Node in raid.find_children("*", "", true, false):
		if node is LootContainer:
			remaining_loot += 1
	_check(remaining_loot == 0, "A lootbox survived Explosion")

	GameState.in_raid = false
	GameState.explosion_used_this_raid = false
	raid.queue_free()
	if failures.is_empty():
		print("EXPLOSION SPELL TEST PASSED: every requested mechanic verified")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
