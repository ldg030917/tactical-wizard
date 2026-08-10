extends Node

const REGION_GRAPH := preload("res://scripts/regions/region_graph.gd")

var failures: Array[String] = []

func _ready() -> void:
	_validate_resources()
	_validate_saved_scenes()
	if failures.is_empty():
		print("MAGIC EDITOR STRUCTURE TEST PASSED")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		get_tree().quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _validate_resources() -> void:
	_check(ItemDB.all_items().size() >= 40, "Item resources were not discoverable")
	_check(ContentRegistry.spells().size() >= 40, "Forty starting spell resources were not discoverable")
	var parity_snapshot: Dictionary = GameState.content_parity_snapshot()
	_check(bool(parity_snapshot.ok), "The editor/runtime starting spell catalog is incomplete: " + JSON.stringify(parity_snapshot))
	var manifest: Resource = load("res://resources/content_manifest.tres")
	var expanded_manifest: Resource = load("res://resources/expanded_catalog.tres")
	var manifest_item_ids: Dictionary = {}
	for item: ItemData in manifest.get("items"):
		manifest_item_ids[item.item_id] = true
	for item: ItemData in expanded_manifest.get("items"):
		manifest_item_ids[item.item_id] = true
	var manifest_spell_ids: Dictionary = {}
	for spell: BaseSpellData in manifest.get("base_spells"):
		manifest_spell_ids[spell.spell_id] = true
	for spell: BaseSpellData in expanded_manifest.get("spells"):
		manifest_spell_ids[spell.spell_id] = true
	for spell_item_id: String in GameState.STARTING_SPELL_PAGE_IDS:
		_check(manifest_item_ids.has(spell_item_id), "Starting spell page is absent from the export manifest: " + spell_item_id)
		var page_spell: BaseSpellData = ItemDB.spell(spell_item_id)
		_check(page_spell != null and manifest_spell_ids.has(page_spell.spell_id), "Starting spell is absent from the export manifest: " + spell_item_id)
	var elemental_spell_counts := {"fire":0, "water":0, "grass":0, "neutral":0}
	for spell: BaseSpellData in ContentRegistry.spells().values():
		elemental_spell_counts[spell.primary_element] = int(elemental_spell_counts.get(spell.primary_element, 0)) + 1
	for element: String in ElementSystem.PRIMARY_ELEMENTS:
		_check(int(elemental_spell_counts[element]) >= 10, "%s does not have ten starting spells" % element.capitalize())
	_check(ContentRegistry.modifiers().size() >= 26 and GameState.STARTING_MODIFIER_ITEM_IDS.size() == 20, "Twenty additional spell modifier resources were not discoverable")
	for shader_path: String in ["res://shaders/spells/fire_spell.gdshader", "res://shaders/spells/water_spell.gdshader", "res://shaders/spells/grass_spell.gdshader", "res://shaders/spells/neutral_spell.gdshader"]:
		_check(load(shader_path) is Shader, "Element spell shader failed to load: " + shader_path)
	_check(ContentRegistry.characters().size() == 4, "Four character specializations were not discoverable")
	_check(ContentRegistry.regions().size() == 4, "Four elemental regions were not discoverable")
	_check(ContentRegistry.daggers().size() == 4, "Four elemental daggers were not discoverable")
	_check(REGION_GRAPH.ENTRY_REGION_ID == "neutral_frontier", "Neutral is not the fixed raid entry region")
	for from_region: String in REGION_GRAPH.CONNECTIONS.keys():
		_check(REGION_GRAPH.connected_regions(from_region).size() == 3, "%s is not connected to every other elemental region" % from_region)
	_check(ContentRegistry.spellbooks().size() >= 2, "Spellbook resources were not discoverable")
	_check(ContentRegistry.foci().size() >= 1, "Focus resources were not discoverable")
	_check(ContentRegistry.starter_packages().size() >= 1, "Starter package resource was not discoverable")
	_check(ContentRegistry.recipes().size() >= 8, "Crafting recipe resources were not discoverable")
	_check(ContentRegistry.quests().size() >= 3, "Quest resources were not discoverable")
	var fireball := ContentRegistry.spells().get("fireball") as BaseSpellData
	var area := ContentRegistry.modifiers().get("increased_area") as SpellModifierData
	var ice := ContentRegistry.spells().get("ice_spear") as BaseSpellData
	_check(area.is_compatible(fireball), "Fireball area compatibility is incorrect")
	_check(not area.is_compatible(ice), "Ice Spear incorrectly accepts Increased Area")
	var curve := ContentRegistry.modifiers().get("curved_trajectory") as SpellModifierData
	var curve_modifiers: Array[SpellModifierData] = [curve]
	var curved_config := RuntimeSpellConfig.build(fireball, curve_modifiers, ContentRegistry.spellbooks().get("apprentice_grimoire") as SpellbookData, ContentRegistry.foci().get("apprentice_wand") as FocusData)
	_check(curved_config.valid and curved_config.trajectory == "high_lob", "High-lob trajectory modifier did not compile")
	var navigation := load("res://resources/navigation/raid_navigation.tres") as NavigationMesh
	_check(navigation != null and navigation.get_polygon_count() > 0, "Saved Ashen Village navigation mesh is empty")
	for folder: String in ["res://resources/spells", "res://resources/modifiers", "res://resources/spellbooks", "res://resources/equipment", "res://resources/starter_packages", "res://resources/items", "res://resources/enemies", "res://resources/loot_tables", "res://resources/quests", "res://resources/crafting", "res://resources/upgrades"]:
		for file_name: String in DirAccess.get_files_at(folder):
			if file_name.get_extension() == "tres":
				_check(load(folder.path_join(file_name)) != null, "Resource failed to load: " + folder.path_join(file_name))

func _validate_saved_scenes() -> void:
	var base := (load("res://scenes/base/base.tscn") as PackedScene).instantiate()
	_check(base.find_child("Environment", true, false) != null, "Base Environment hierarchy missing")
	_check(base.find_child("Interactables", true, false) != null, "Base Interactables hierarchy missing")
	_check(base.find_child("PlayerSpawn_Default", true, false) != null, "Base player spawn missing")
	_check(base.find_child("SpellWorkshop", true, false) != null, "Saved Spell Workshop missing")
	_check(base.find_child("RefugeQuartermaster", true, false) != null, "Saved magical merchant missing")
	_check(base.find_child("AshenVillagePortal", true, false) != null, "Saved deployment portal missing")
	_check(base.find_child("BaseUI", true, false) != null, "Saved Base UI missing")
	var base_ui: Node = base.find_child("BaseUI", true, false)
	_check(base_ui.find_child("RegionButton", true, false) == null and base_ui.find_child("RegionUI", true, false) == null, "Obsolete Base region-selection screen still exists")
	base.free()
	var raid := (load("res://scenes/raid/raid_map.tscn") as PackedScene).instantiate()
	_check(raid.find_child("Buildings", true, false) != null, "Ashen Village buildings hierarchy missing")
	_check(raid.find_child("EnemySpawns", true, false).get_child_count() >= 8, "Editor enemy spawn points missing")
	_check(raid.find_child("LootContainers", true, false).get_child_count() >= 7, "Editor magical loot containers missing")
	_check(raid.find_child("ExtractionZones", true, false).get_child_count() == 1, "Ashen Village should expose one extraction zone")
	_check(raid.find_child("HighValueArcaneCase_EmberSanctum", true, false) != null, "High-value arcane case missing")
	_check(raid.find_child("HUD", true, false) != null, "Saved magical Raid HUD missing")
	raid.free()
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	_check(player.find_child("ManaComponent", true, false) != null, "Player ManaComponent missing")
	_check(player.find_child("SpellCaster", true, false) != null, "Player SpellCaster missing")
	_check(player.find_child("WandSocket", true, false) != null, "Player WandSocket missing")
	_check(player.find_child("SpellbookSocket", true, false) != null, "Player SpellbookSocket missing")
	_check(player.find_child("TrajectoryPreview", true, false) != null, "Trajectory preview missing")
	player.free()
	var spell_projectile := (load("res://scenes/spells/spell_projectile.tscn") as PackedScene).instantiate()
	_check(spell_projectile.find_child("OrbitRingA", true, false) != null and spell_projectile.find_child("OrbitRingB", true, false) != null, "Animated spell orbit rings are missing")
	_check(spell_projectile.find_child("Trail", true, false) != null and spell_projectile.find_child("Light", true, false) != null, "Spell trail particles or dynamic light are missing")
	spell_projectile.free()
	for region_scene_path: String in ["res://scenes/regions/neutral_region.tscn", "res://scenes/regions/fire_region.tscn", "res://scenes/regions/water_region.tscn", "res://scenes/regions/grass_region.tscn"]:
		var region_scene := (load(region_scene_path) as PackedScene).instantiate()
		var gateways: Array[Node] = region_scene.find_children("GatewayTo*", "Node3D", true, false)
		_check(gateways.size() == 3, "%s does not expose three connected elemental waygates" % region_scene_path)
		if region_scene_path.ends_with("grass_region.tscn"):
			_check(is_equal_approx(float(region_scene.grass_wall_refresh_seconds), 5.0), "Grass living walls are not configured for a five-second refresh")
			_check((region_scene.GRASS_WALL_PLACEMENTS as Array).size() >= 6, "Grass wall cycle lacks enough safe randomized placements")
		region_scene.free()
	var living_wall := (load("res://scenes/regions/temporary_grass_wall.tscn") as PackedScene).instantiate() as TemporaryGrassWall
	_check(living_wall.managed_by_region_cycle and living_wall.find_child("NavigationObstacle3D", true, false) != null, "Grass wall is not managed by the region cycle or navigation-aware")
	living_wall.free()
	for scene_path: String in [
		"res://scenes/enemies/monster_enemy.tscn", "res://scenes/enemies/mage_enemy.tscn",
		"res://scenes/spells/spell_projectile.tscn", "res://scenes/spells/healing_circle.tscn",
		"res://scenes/base/spell_workshop.tscn", "res://scenes/base/merchant.tscn",
		"res://scenes/base/deployment_portal.tscn", "res://scenes/ui/spellbook_ui.tscn",
		"res://scenes/ui/hud.tscn", "res://scenes/ui/inventory_ui.tscn",
		"res://scenes/ui/stash_ui.tscn", "res://scenes/ui/vendor_ui.tscn",
		"res://scenes/ui/crafting_ui.tscn", "res://scenes/ui/quest_ui.tscn",
		"res://scenes/ui/raid_result_ui.tscn", "res://scenes/ui/pause_menu.tscn",
		"res://scenes/start/start_screen.tscn", "res://scenes/ui/item_slot.tscn",
		"res://tests/guideline_compliance_test.tscn",
		"res://scenes/regions/neutral_region.tscn", "res://scenes/regions/fire_region.tscn",
		"res://scenes/regions/water_region.tscn", "res://scenes/regions/grass_region.tscn"
	]:
		var packed := load(scene_path) as PackedScene
		_check(packed != null, "Scene failed to load: " + scene_path)
		if packed != null:
			var instance := packed.instantiate()
			_check(instance != null, "Scene failed to instantiate: " + scene_path)
			instance.free()
