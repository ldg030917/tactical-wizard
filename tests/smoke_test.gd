extends Node

var failures: Array[String] = []

func _ready() -> void:
	_run()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("MAGIC SMOKE TEST: " + message)

func _run() -> void:
	GameState.reset_save_for_debug()
	var available_starting_pages: Dictionary = {}
	for page: Dictionary in GameState.spell_pages:
		available_starting_pages[str(page.get("spell_item", ""))] = true
	for item_id: String in GameState.stash.keys():
		if ItemDB.spell(item_id) != null:
			available_starting_pages[item_id] = true
	_check(available_starting_pages.size() >= 41 and GameState.STARTING_SPELL_PAGE_IDS.size() == 41, "The 40 elemental formulas and Explosion were not granted to the starting catalog")
	var all_starting_spells_compile: bool = true
	var all_starting_spells_have_vfx: bool = true
	for item_id: String in GameState.STARTING_SPELL_PAGE_IDS:
		var starting_spell: BaseSpellData = ItemDB.spell(item_id)
		var starting_config := RuntimeSpellConfig.build(starting_spell, [], GameState.equipped_spellbook(), ItemDB.focus(str(GameState.loadout.focus)), true)
		all_starting_spells_compile = all_starting_spells_compile and starting_config.valid and ((starting_spell.behavior_type == "projectile" and starting_spell.projectile_scene != null) or starting_spell.behavior_type != "projectile" or starting_spell.spell_id == "healing_circle")
		var starting_vfx := VisualFactory.elemental_spell_material(starting_spell.primary_element, starting_spell.debug_color, 3.0, 1.0)
		all_starting_spells_have_vfx = all_starting_spells_have_vfx and starting_vfx.shader != null
	_check(all_starting_spells_compile, "A starting spell formula could not compile into a playable runtime spell")
	_check(all_starting_spells_have_vfx, "A starting spell did not receive its Primary Element shader")
	var all_additional_modifiers_compile: bool = true
	for modifier_item_id: String in GameState.STARTING_MODIFIER_ITEM_IDS:
		var modifier: SpellModifierData = ItemDB.modifier(modifier_item_id)
		var compatible_spell: BaseSpellData
		for spell: BaseSpellData in ContentRegistry.spells().values():
			if modifier != null and modifier.is_compatible(spell):
				compatible_spell = spell
				break
		if modifier == null or compatible_spell == null:
			all_additional_modifiers_compile = false
			continue
		var configured_modifiers: Array[SpellModifierData] = [modifier]
		var modified_config := RuntimeSpellConfig.build(compatible_spell, configured_modifiers, GameState.equipped_spellbook(), ItemDB.focus(str(GameState.loadout.focus)), true)
		all_additional_modifiers_compile = all_additional_modifiers_compile and modified_config.valid
	_check(all_additional_modifiers_compile, "An additional attachment had no compatible playable spell or failed runtime compilation")
	var fireball_item: ItemData = ItemDB.resource("fireball_page")
	var range_item: ItemData = ItemDB.resource("mod_increased_range")
	var grimoire_item: ItemData = ItemDB.resource("apprentice_grimoire")
	var wand_item: ItemData = ItemDB.resource("apprentice_wand")
	_check(ItemDB.all_items().size() >= 40, "Static item catalog is incomplete")
	_check(fireball_item != null and fireball_item.base_spell != null, "Fireball item lost its spell resource reference")
	_check(range_item != null and range_item.spell_modifier != null, "Range item lost its modifier resource reference")
	_check(grimoire_item != null and grimoire_item.spellbook != null, "Grimoire item lost its spellbook resource reference")
	_check(wand_item != null and wand_item.focus != null, "Wand item lost its focus resource reference")
	_check(ContentRegistry.spells().size() >= 40 and ContentRegistry.modifiers().size() >= 26, "Expanded magic catalog is incomplete")
	_check(ContentRegistry.characters().size() == 4 and ContentRegistry.regions().size() == 4, "Character or elemental-region catalog is incomplete")
	_check(ContentRegistry.daggers().size() == 4, "Four primary-element daggers are required")
	_check(ElementSystem.beats("fire", "grass") and ElementSystem.beats("grass", "water") and ElementSystem.beats("water", "fire"), "Primary-element weakness triangle is incorrect")
	_check(ElementSystem.normalize_primary("ice") == "water" and ElementSystem.normalize_primary("lightning") == "water", "Derived Water families became primary elements")
	_check(range_item.spell_modifier.range_multiplier > 1.0, "Range modifier multiplier was not imported")
	_check(range_item.spell_modifier.is_compatible(fireball_item.base_spell), "Range modifier compatibility data was not imported")
	var initial_config: RuntimeSpellConfig = GameState.spell_config(0)
	_check(initial_config.valid, "Initial spell compile warning: " + initial_config.warning)
	var carried_book: String = str(GameState.loadout.spellbook)
	GameState.loadout.spellbook = ""
	_check(not GameState.spell_config(0).valid, "A spell cast without its physically carried spellbook")
	GameState.loadout.spellbook = carried_book
	_check(ElementSystem.damage_after_resistance(10.0, "fire", "grass", 0.65) > 10.0, "Equipment resistance erased elemental weakness")
	var main: Node = (load("res://scenes/main/game_root.tscn") as PackedScene).instantiate()
	await get_tree().process_frame
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	_check(main.start_screen != null and main.start_screen.visible, "Start screen did not appear first")
	main.start_game()
	for _i: int in range(6):
		await get_tree().process_frame
	_check(main.active_area is BaseScene, "Starfall Refuge did not load")
	_check(GameState.loadout.spellbook == "apprentice_grimoire", "Initial grimoire loadout missing")
	_check(GameState.loadout.focus == "apprentice_wand", "Initial wand loadout missing")
	var refuge := main.active_area as BaseScene
	_check(not refuge.base_ui.visible, "Base facility UI was globally open without approaching a station")
	var storage_station := refuge.get_node("Interactables/StorageStation") as BaseStation
	refuge.player.global_position = storage_station.global_position + Vector3(0, 0, 1.7)
	for _i: int in range(3):
		await get_tree().process_frame
	_check(refuge.base_ui.visible and refuge.base_ui.current_tab == "stash", "Approaching storage did not open the integrated equipment and stash screen")
	refuge.player.global_position = Vector3.ZERO
	for _i: int in range(3):
		await get_tree().process_frame
	_check(not refuge.base_ui.visible, "Base station screen did not disappear after walking away")
	refuge.base_ui.show_station("spellbook", "Runesmith's Spell Workshop")
	await get_tree().process_frame
	_check(refuge.base_ui.current_tab == "spellbook" and refuge.base_ui.panels.spellbook.visible, "Spell Workshop UI could not open")
	_check(refuge.base_ui.panels.spellbook.find_child("SocketBoard", true, false) != null, "Spell attachment sockets are not fixed above the scrolling library")
	GameState.add_to_stash("mod_left_turn", 1)
	var left_install: Dictionary = GameState.install_page_modifier(0, "mod_left_turn")
	_check(bool(left_install.success), "Attachment could not be installed for removal test")
	var left_stash_before_remove: int = int(GameState.stash.get("mod_left_turn", 0))
	refuge.base_ui._on_item_slot_drop({"kind":"item", "item_id":"mod_left_turn", "source_context":"spell_attachment", "source_slot":"0:1"}, "attachment_storage", "return_to_storage")
	_check("mod_left_turn" not in GameState.spell_pages[0].modifiers, "Dragging an attachment to storage did not unequip it")
	_check(int(GameState.stash.get("mod_left_turn", 0)) == left_stash_before_remove + 1, "Unequipped attachment did not return to storage")
	refuge.base_ui.open_tab("stash")
	refuge.player.select_spell_page(0)
	var base_cast_config := refuge.player.current_spell_config()
	refuge.player.mana = minf(refuge.player.max_mana - 20.0, base_cast_config.mana_cost + 5.0)
	var partial_mana_before: float = refuge.player.mana
	_check(refuge.player.cast_selected_spell_immediate(refuge.player.global_position + Vector3(0, 0, -5)), "A spell could not be cast in the Base with sufficient partial mana")
	_check(refuge.player.mana < partial_mana_before and partial_mana_before < refuge.player.max_mana, "Casting still required a completely full mana gauge")
	var fire_config := GameState.spell_config(0)
	_check(fire_config.valid and fire_config.base_spell.spell_id == "fireball", "Cinder Orb page did not compile")
	_check(fire_config.range_meters > fire_config.base_spell.base_range_meters, "Far-Reach modifier did not affect range")
	var invalid_result: Dictionary = GameState.install_page_modifier(1, "mod_increased_area")
	_check(not bool(invalid_result.success), "Incompatible area modifier was accepted by Rime Lance")
	GameState.add_to_stash("mod_projectile_split", 1)
	var split_result: Dictionary = GameState.install_page_modifier(1, "mod_projectile_split")
	_check(bool(split_result.success), "Compatible split modifier could not be installed")
	_check(GameState.spell_config(1).projectile_count == 3, "Split modifier did not create three projectiles")
	GameState.save_game()
	GameState.spell_pages[1].modifiers = []
	GameState.load_game()
	_check(GameState.spell_config(1).projectile_count == 3, "Configured spellbook pages did not persist")
	var mana_potions_before: int = int(GameState.stash.get("mana_potion", 0))
	_check(GameState.craft("mana_tonic"), "Mana tonic recipe failed")
	_check(int(GameState.stash.get("mana_potion", 0)) == mana_potions_before + 2, "Mana tonic craft output was incorrect")
	_check(GameState.purchase_starter_package(), "Recovery package purchase failed")
	GameState.accept_quest("ember_sample")
	_check(str(GameState.quests[0].state) == "active", "First magical expedition could not be accepted")
	main.start_raid()
	for _i: int in range(16):
		await get_tree().physics_frame
	_check(main.active_area is RaidScene, "Ashen Village did not load")
	var raid := main.active_area as RaidScene
	_check(raid.player != null, "Raid mage player missing")
	raid.toggle_inventory()
	_check(raid.hud.inventory_panel.visible and raid.hud.equipment_rows != null, "Raid inventory did not expose real-time equipment and field pack")
	raid.hud._show_spell_settings()
	_check(raid.hud.spell_settings_panel.visible and raid.hud.raid_fixed_sockets != null, "Raid spell settings could not be opened")
	raid.hud._close_access_panels()
	GameState.add_raid_item("mod_ricochet_rune", 1)
	var raid_modifier_result: Dictionary = raid.install_raid_modifier(0, "mod_ricochet_rune")
	_check(bool(raid_modifier_result.success), "A carried compatible rune could not be installed from raid spell settings")
	_check(raid.remove_raid_modifier(0, GameState.spell_pages[0].modifiers.size() - 1), "An installed raid rune could not return to the field pack")
	_check(raid.region_id == "neutral_frontier" and GameState.current_raid_region_id == "neutral_frontier", "Raid did not spawn in the fixed Neutral entry region")
	raid.player.health = 83.0
	raid.player.mana = 77.0
	GameState.add_raid_item("arcane_dust", 1)
	_check(main.travel_to_region("fire_region"), "Neutral gateway could not reach the connected Fire region")
	for _i: int in range(4):
		await get_tree().process_frame
	raid = main.active_area as RaidScene
	_check(raid.region_id == "fire_region" and is_equal_approx(raid.player.health, 83.0) and raid.player.mana >= 77.0 and raid.player.mana < 78.0, "Player state did not persist through regional travel")
	for extraction: Node in raid.get_node("ExtractionZones").get_children():
		_check(extraction.process_mode == Node.PROCESS_MODE_DISABLED and not extraction.visible, "Extraction remained active outside the Neutral region")
	_check(int(GameState.raid_inventory.get("arcane_dust", 0)) >= 1, "Raid inventory did not persist through regional travel")
	_check(main.travel_to_region("water_region"), "Fire region was not connected to Water")
	for _i: int in range(4):
		await get_tree().process_frame
	raid = main.active_area as RaidScene
	var water_hazards: Array[ElementalHazardZone] = []
	for effect: Node in raid.temporary_effects.get_children():
		if effect is ElementalHazardZone and (effect as ElementalHazardZone).hazard_element == "water":
			water_hazards.append(effect as ElementalHazardZone)
	_check(water_hazards.size() >= 7, "Water region did not place enough movement-reduction areas")
	var water_slow_correct: bool = not water_hazards.is_empty()
	for hazard: ElementalHazardZone in water_hazards:
		water_slow_correct = water_slow_correct and is_equal_approx(hazard.water_slow_multiplier, 0.5) and hazard.radius >= 4.0
	_check(water_slow_correct, "Water pools do not reduce movement speed by exactly 50 percent")
	if not water_hazards.is_empty():
		raid.player.slow_remaining = 0.0
		raid.player.slow_multiplier = 1.0
		water_hazards[0]._on_body_entered(raid.player)
		water_hazards[0]._physics_process(0.1)
		_check(is_equal_approx(raid.player.slow_multiplier, 0.5), "Water hazard did not apply its 50 percent slow to the player")
		water_hazards[0]._on_body_exited(raid.player)
		raid.player.slow_remaining = 0.0
		raid.player.slow_multiplier = 1.0
	_check(main.travel_to_region("grass_region"), "Water region was not connected to Grass")
	for _i: int in range(4):
		await get_tree().process_frame
	raid = main.active_area as RaidScene
	var wall_generation_before: int = raid.grass_wall_generation
	var first_wall_ids: Array[int] = []
	for effect: Node in raid.temporary_effects.get_children():
		if effect is TemporaryGrassWall:
			first_wall_ids.append(effect.get_instance_id())
	_check(is_equal_approx(raid.grass_wall_refresh_seconds, 5.0) and first_wall_ids.size() == raid.grass_wall_count, "Grass region did not create its five-second randomized living-wall set")
	raid.grass_wall_refresh_remaining = 5.0
	raid._update_grass_wall_cycle(4.9)
	_check(raid.grass_wall_generation == wall_generation_before, "Grass walls renewed before five seconds elapsed")
	raid._update_grass_wall_cycle(0.11)
	var renewed_wall_ids: Array[int] = []
	for effect: Node in raid.temporary_effects.get_children():
		if effect is TemporaryGrassWall:
			renewed_wall_ids.append(effect.get_instance_id())
	_check(raid.grass_wall_generation == wall_generation_before + 1 and renewed_wall_ids.size() == raid.grass_wall_count and renewed_wall_ids != first_wall_ids, "Grass walls were not replaced after the five-second cycle")
	_check(main.travel_to_region("neutral_frontier"), "Grass region could not return to Neutral")
	for _i: int in range(4):
		await get_tree().process_frame
	raid = main.active_area as RaidScene
	_check(raid.region_id == "neutral_frontier", "Regional travel did not return to the Neutral extraction region")
	_check(raid.player.equipped_dagger() != null, "Slot 4 dagger missing")
	raid.player.select_combat_slot(3)
	_check(raid.player.current_primary_element() == "neutral", "Dagger did not determine current Primary Element")
	raid.player.select_spell_page(0)
	_check(not bool(GameState.install_page_modifier(0, "mod_left_turn").success), "Raid inventory allowed full attachment rebuilding")
	var start_position: Vector3 = raid.player.global_position
	Input.action_press("move_up")
	for _i: int in range(5):
		await get_tree().physics_frame
	Input.action_release("move_up")
	_check(raid.player.global_position.distance_to(start_position) > 0.05, "Mage movement input failed")
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	_check(enemies.size() >= 6, "Magical enemy population missing")
	var enemy_types: Dictionary = {}
	for node: Node in enemies:
		if raid.is_ancestor_of(node):
			enemy_types[(node as EnemyController).enemy_type] = true
	_check(enemy_types.has("monster") and enemy_types.has("mage"), "Both monster and mage variants were not spawned")
	var melee_enemy: EnemyController
	for node: Node in enemies:
		if raid.is_ancestor_of(node) and (node as EnemyController).enemy_type in ["monster", "creature"]:
			melee_enemy = node as EnemyController
			break
	_check(melee_enemy != null, "No melee enemy was available for pursuit validation")
	if melee_enemy != null:
		for node: Node in enemies:
			if raid.is_ancestor_of(node) and node != melee_enemy:
				node.set_physics_process(false)
		raid.player.health = raid.player.max_health
		raid.player.bleeding = false
		raid.player.burn_remaining = 0.0
		raid.player.burn_damage_per_second = 0.0
		raid.player.poison_remaining = 0.0
		raid.player.poison_damage_per_second = 0.0
		for effect: Node in raid.temporary_effects.get_children():
			if effect is SpellProjectile:
				effect.queue_free()
		await get_tree().process_frame
		melee_enemy.player = raid.player
		melee_enemy.global_position = raid.player.global_position + Vector3(0, 0, -7)
		melee_enemy.detection_range = 16.0
		melee_enemy.damage = 2.0
		melee_enemy.attack_interval = 0.25
		melee_enemy.aggroed = false
		melee_enemy.state = EnemyController.State.PATROL
		var chase_distance_before: float = melee_enemy.global_position.distance_to(raid.player.global_position)
		_check(melee_enemy._can_detect_player(chase_distance_before), "Melee enemy could not spot the player in clear sight")
		for _i: int in range(100):
			await get_tree().physics_frame
		var chase_distance_after: float = melee_enemy.global_position.distance_to(raid.player.global_position)
		_check(melee_enemy.aggroed and chase_distance_after < chase_distance_before * 0.55, "Melee enemy did not trace and close on the sighted player")
		_check(raid.player.health < raid.player.max_health, "Melee enemy reached the player but did not attack")
		melee_enemy.set_physics_process(false)
		melee_enemy.global_position = raid.player.global_position + Vector3(12, 0, 0)
	var container: LootContainer
	for node: Node in get_tree().get_nodes_in_group("interactable"):
		if node is LootContainer and raid.is_ancestor_of(node):
			container = node as LootContainer
			break
	_check(container != null, "No searchable magical container")
	if container != null:
		container.generate_loot()
		_check(not container.contents.is_empty(), "Magical loot table generated no items")
		var first_item: String = str(container.contents.keys()[0])
		_check(container.take_item(first_item), "Magical loot could not enter the field pack")
	var target := enemies[0] as EnemyController
	target.set_physics_process(false)
	target.global_position = raid.player.global_position + Vector3(0, 0, -4.5)
	var mana_before: float = raid.player.mana
	_check(raid.player.cast_selected_spell_immediate(target.global_position), "Cinder Orb cast could not execute")
	_check(raid.player.mana < mana_before, "Casting did not consume mana")
	for _i: int in range(45):
		await get_tree().physics_frame
	_check(target.health < target.max_health, "Spell projectile did not damage its target")
	target.global_position = raid.player.global_position + Vector3(0, 0, -1.3)
	raid.player.select_combat_slot(3)
	var dagger_health_before: float = target.health
	var stamina_before: float = raid.player.stamina
	_check(raid.player.dagger_attack(), "Space-bar dagger attack could not execute")
	_check(target.health < dagger_health_before and raid.player.stamina < stamina_before, "Dagger did not deal damage and spend stamina")
	raid.player.select_spell_page(2)
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if raid.is_ancestor_of(enemy):
			enemy.set_physics_process(false)
	raid.player.burn_remaining = 0.0
	raid.player.poison_remaining = 0.0
	raid.player.bleeding = false
	raid.player.health = 45.0
	var health_before: float = raid.player.health
	_check(raid.player.cast_selected_spell_immediate(raid.player.global_position), "Verdant Refuge placement failed")
	for _i: int in range(70):
		await get_tree().physics_frame
	_check(raid.player.health > health_before, "Healing circle did not restore health")
	# Exercise every new non-projectile runtime family, not merely its resource data.
	target.health = target.max_health
	target.burn_remaining = 0.0
	target.global_position = raid.player.global_position + Vector3(0, 0, -3.0)
	var emberstream := _config_for("emberstream_page")
	var cone_health_before: float = target.health
	raid.cast_special_spell(raid.player, emberstream, raid.player.global_position, target.global_position, Vector3.FORWARD)
	_check(target.health < cone_health_before, "Flamethrower cone did not damage a visible enemy")
	var magma := _config_for("magma_basin_page")
	var magma_field := raid.cast_special_spell(raid.player, magma, raid.player.global_position, target.global_position, Vector3.FORWARD) as ElementalSpellField
	var magma_health_before: float = target.health
	magma_field._apply_tick()
	_check(target.health < magma_health_before and target.burn_remaining > 0.0, "Magma area did not inflict persistent burn damage")
	var puddle := _config_for("drowning_puddle_page")
	var puddle_field := raid.cast_special_spell(raid.player, puddle, raid.player.global_position, target.global_position, Vector3.FORWARD) as ElementalSpellField
	target.slow_multiplier = 1.0
	target.water_vulnerable_remaining = 0.0
	puddle_field._apply_tick()
	_check(is_equal_approx(target.slow_multiplier, 0.5) and target.water_vulnerable_remaining > 0.0, "Drowning Puddle did not apply 50 percent slow and Water vulnerability")
	var roots := _config_for("binding_roots_page")
	var roots_field := raid.cast_special_spell(raid.player, roots, raid.player.global_position, target.global_position, Vector3.FORWARD) as ElementalSpellField
	target.slow_multiplier = 1.0
	roots_field._apply_tick()
	_check(target.slow_multiplier <= 0.45, "Binding Roots did not bind an enemy in its field")
	var wall := _config_for("briar_wall_page")
	var wall_field := raid.cast_special_spell(raid.player, wall, raid.player.global_position, target.global_position + Vector3.RIGHT * 3.0, Vector3.FORWARD) as ElementalSpellField
	_check(wall_field.get_node_or_null("SpellWallCollision") is StaticBody3D, "Plant Wall did not create solid temporary cover")
	var position_before_blink: Vector3 = raid.player.global_position
	var blink_target: Vector3 = position_before_blink + Vector3.RIGHT * 3.0
	raid.cast_special_spell(raid.player, _config_for("blink_sigil_page"), position_before_blink, blink_target, Vector3.RIGHT)
	_check(raid.player.global_position.distance_to(blink_target) < 0.2, "Blink Sigil did not relocate the player")
	raid.player.global_position = position_before_blink
	var ward_before: float = raid.player.ward
	raid.cast_special_spell(raid.player, _config_for("aegis_dome_page"), position_before_blink, position_before_blink, Vector3.FORWARD)
	_check(raid.player.ward > ward_before, "Aegis Dome did not grant a damage-absorbing ward")
	target.take_damage(999.0, raid.player.global_position, 0.0, "arcane")
	await get_tree().process_frame
	_check(int(raid.kills.get(target.enemy_type, 0)) == 1, "Magical enemy defeat did not register")
	GameState.add_raid_item("ash_essence", 1)
	GameState.add_raid_item("walpurgis_ticket", 1)
	_check(GameState.secure_item("walpurgis_ticket"), "Walpurgis Ticket could not use secure storage")
	var zones: Array[Node] = get_tree().get_nodes_in_group("extractions")
	_check(zones.size() >= 1, "Ashen Waygate extraction missing")
	var zone := zones[0] as ExtractionZone
	zone.global_position = raid.player.global_position
	zone.countdown_duration = 0.05
	for _i: int in range(12):
		await get_tree().process_frame
	var summary: Dictionary = GameState.last_summary
	_check(bool(summary.success), "Successful magical extraction summary invalid")
	_check(int(GameState.stash.get("ash_essence", 0)) >= 1, "Extracted ash essence did not reach stash")
	_check(int(GameState.stash.get("walpurgis_ticket", 0)) >= 1, "Secure ticket did not reach stash")
	_check(str(GameState.quests[0].state) == "complete", "Recovered quest item did not complete expedition")
	main.start_raid()
	for _i: int in range(10):
		await get_tree().physics_frame
	var death_raid := main.active_area as RaidScene
	GameState.add_raid_item("mana_crystal", 1)
	_check(GameState.secure_item("mana_crystal"), "Mana crystal secure test failed")
	var area_mod_before_death: int = int(GameState.stash.get("mod_increased_area", 0))
	GameState.add_raid_item("mod_increased_area", 1)
	death_raid.player.take_damage(999.0, Vector3.ZERO, 0.0, "arcane")
	await get_tree().create_timer(1.5).timeout
	var death_summary: Dictionary = GameState.last_summary
	_check(not bool(death_summary.success), "Death summary invalid")
	_check(int(GameState.stash.get("mana_crystal", 0)) >= 1, "Secure magical item was lost on death")
	_check(int(GameState.stash.get("mod_increased_area", 0)) == area_mod_before_death, "Unsecured raid modifier was retained after death")
	_check(GameState.loadout.spellbook == "apprentice_grimoire" and GameState.loadout.focus == "apprentice_wand", "Fallback magical loadout was not restored")
	GameState.add_to_stash("arcane_dust", 2)
	GameState.save_game()
	GameState.stash.erase("arcane_dust")
	GameState.load_game()
	_check(int(GameState.stash.get("arcane_dust", 0)) >= 2, "Save reload did not restore magical stash")
	GameState.reset_save_for_debug()
	if failures.is_empty():
		print("MAGIC SMOKE TEST PASSED: 40 uniquely iconized elemental spells plus Explosion, 20 dynamic attachments, Water pools, melee pursuit, regions, combat, loot, extraction, and persistence")
		get_tree().quit(0)
	else:
		print("MAGIC SMOKE TEST FAILED: ", failures)
		get_tree().quit(1)

func _config_for(item_id: String) -> RuntimeSpellConfig:
	return RuntimeSpellConfig.build(ItemDB.spell(item_id), [], GameState.equipped_spellbook(), ItemDB.focus(str(GameState.loadout.focus)), true)
