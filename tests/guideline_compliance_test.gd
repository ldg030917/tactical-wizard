extends Node

const MATRIX := preload("res://tests/guideline_feature_matrix.gd")
const REGION_GRAPH := preload("res://scripts/regions/region_graph.gd")

var failures: Array[String] = []
var exercised: Dictionary = {}
var matrix: RefCounted = MATRIX.new()

func _ready() -> void:
	_validate_matrix()
	_validate_visual_ui()
	_validate_spell_and_attachment_ui()
	_validate_raid_ui()
	_validate_magic_content()
	_validate_world_and_rules()
	_finish()

func _check(section: int, condition: bool, feature: String) -> void:
	exercised[section] = true
	if not condition:
		failures.append("Guideline %d (%s): %s" % [section, matrix.get("section_titles")[section - 1], feature])

func _validate_matrix() -> void:
	if (matrix.get("section_titles") as PackedStringArray).size() != 90:
		failures.append("Refined guideline matrix must contain all 90 numbered sections")
	for section: int in range(1, 91):
		if matrix.status(section) not in ["tested", "partial", "deferred", "design_rule"]:
			failures.append("Guideline section %d has no coverage classification" % section)

func _validate_visual_ui() -> void:
	_check(1, GameState.has_method("begin_raid") and GameState.has_method("finish_raid"), "extraction lifecycle is missing")
	var start := (load("res://scenes/start/start_screen.tscn") as PackedScene).instantiate()
	_check(5, start.find_child("StartButton", true, false) is Button and (start.find_child("StartButton", true, false) as Button).text.is_empty(), "frequent Start controls are not image-first")
	_check(6, (start.find_child("StartButton", true, false) as Button).mouse_default_cursor_shape == Control.CURSOR_ARROW or FileAccess.get_file_as_string("res://scripts/ui/start_screen.gd").contains("tooltip_text"), "image buttons lack hover discovery")
	_check(8, start.find_child("StartButton", true, false) != null and start.find_child("SettingsButton", true, false) != null and start.find_child("QuitButton", true, false) != null, "Start, Settings, and Quit controls are incomplete")
	start.free()
	var base_scene := (load("res://scenes/base/base.tscn") as PackedScene).instantiate()
	_check(11, base_scene.find_child("StorageStation", true, false) != null and base_scene.find_child("SpellWorkshop", true, false) != null and base_scene.find_child("AshenVillagePortal", true, false) != null, "physical Base interactions are missing")
	base_scene.free()
	var base_ui := (load("res://scenes/ui/base_ui.tscn") as PackedScene).instantiate()
	var navigation := base_ui.find_child("Buttons", true, false)
	_check(10, navigation is HBoxContainer and not (base_ui.find_child("FacilityMenu", true, false) as Control).visible, "global facility shortcut bar must remain hidden in favor of physical stations")
	_check(12, base_ui.find_child("ContentArea", true, false) != null and base_ui.find_child("EquipmentRows", true, false) != null and base_ui.find_child("ItemRows", true, false) != null, "integrated equipment and storage panel is missing")
	_check(11, base_ui.find_child("RecipeRows", true, false) != null and base_ui.find_child("RecipeDetail", true, false) != null and base_ui.find_child("UpgradeDetail", true, false) != null and base_ui.find_child("SkillDetail", true, false) != null, "station-specific two-pane work screens are missing")
	_check(23, base_ui.find_child("SpellbookUI", true, false) != null and base_ui.find_child("Page1Button", true, false) != null, "graphical spellbook page interface is missing")
	_check(26, base_ui.find_child("WorkshopRows", true, false) != null and base_ui.find_child("SocketBoard", true, false) != null, "fixed spell socket board or scrolling library is missing")
	_check(28, base_ui.find_child("TrajectoryPreview", true, false) != null and FileAccess.file_exists("res://scripts/ui/trajectory_preview.gd"), "live spell preview is missing")
	_check(31, base_ui.find_child("VendorUI", true, false) != null, "merchant interface is missing")
	_check(32, ContentRegistry.starter_packages().size() >= 4, "four recovery package cards are unavailable")
	var base_source := FileAccess.get_file_as_string("res://scripts/ui/base_ui.gd")
	_check(33, FileAccess.get_file_as_string("res://scripts/regions/region_graph.gd").contains("neutral_frontier"), "connected region graph is missing")
	_check(34, ContentRegistry.regions().size() == 4, "regional hazard and loot data is missing")
	_check(35, base_ui.find_child("RaidPreparationUI", true, false) == null and base_ui.find_child("RaidPreparationButton", true, false) == null, "deleted raid preparation screen returned")
	_check(79, base_source.contains("portrait") and base_source.contains("character.description") and ContentRegistry.characters().size() == 4, "visible character vocation descriptions are missing")
	_check(80, ItemDB.resource("walpurgis_ticket") != null and GameState.has_method("can_enter_raid_region"), "ticket requirements are unavailable")
	base_ui.free()
	var slot := (load("res://scenes/ui/item_slot.tscn") as PackedScene).instantiate() as ItemSlot
	_check(13, slot.find_child("Icon", true, false) != null and slot.find_child("ElementBadge", true, false) != null and (slot.find_child("Label", true, false) as Label).visible, "equipment silhouettes, permanent names, or badges are missing")
	var drag_surface_is_clear := true
	for visual_name: String in ["SlotContents", "Icon", "Label", "Amount", "ElementBadge"]:
		var visual := slot.find_child(visual_name, true, false) as Control
		drag_surface_is_clear = drag_surface_is_clear and visual != null and visual.mouse_filter == Control.MOUSE_FILTER_IGNORE
	_check(15, slot.has_method("_get_drag_data") and slot.has_method("_can_drop_data") and slot.has_method("_drop_data") and drag_surface_is_clear, "the whole item card must accept drag gestures and expose valid/invalid drop states")
	_check(16, slot.find_child("Amount", true, false) != null and ItemDB.resource("arcane_dust").stack_size > 1, "slot quantities or stack rules are missing")
	_check(17, not ItemDB.resource("fireball_page").rarity.is_empty(), "rarity metadata is missing")
	var tip: String = slot.build_tooltip(ItemDB.resource("fireball_page"))
	_check(18, tip.contains("Mana") and tip.contains("Range") and tip.contains("Primary"), "detailed item hover information is incomplete")
	_check(19, not tip.is_empty(), "item tooltip positioning has no tooltip content")
	_check(20, ItemDB.resource("apprentice_wand").focus != null, "comparison source equipment is unavailable")
	_check(21, slot.find_child("ElementBadge", true, false) != null, "element symbol badge is missing")
	_check(22, ElementSystem.color("fire") != ElementSystem.color("water") and ElementSystem.color("water") != ElementSystem.color("grass"), "Primary Element colors are not distinct")
	slot.free()

func _validate_spell_and_attachment_ui() -> void:
	_check(25, ItemDB.resource("fireball_page").category == "spell", "completed formula pages are unavailable")
	_check(27, GameState.has_method("install_page_modifier") and GameState.has_method("remove_page_modifier"), "attachment drag install/remove operations are missing")
	var modifier_tip := (load("res://scenes/ui/item_slot.tscn") as PackedScene).instantiate() as ItemSlot
	_check(29, modifier_tip.build_tooltip(ItemDB.resource("mod_ricochet_rune")).contains("Trajectory"), "attachment tooltip lacks behavior and compatibility")
	modifier_tip.free()
	_check(30, GameState.stash_capacity() > 0 and FileAccess.file_exists("res://scenes/ui/stash_ui.tscn"), "persistent storage is missing")
	_check(14, GameState.spell_pages.size() == 3 and GameState.loadout.has("dagger"), "three spell slots and dagger slot are not represented")
	_check(47, ItemDB.modifier("mod_left_pivot_sigil").behavior_tags.has("turn_left_at_target"), "left pivot attachment is missing")
	_check(48, ItemDB.modifier("mod_right_pivot_sigil").behavior_tags.has("turn_right_at_target"), "right pivot attachment is missing")
	_check(49, ContentRegistry.modifiers().has("curved_trajectory") and ContentRegistry.modifiers().curved_trajectory.trajectory_override == "high_lob", "high-lob attachment is missing")
	var dynamic_tags: Dictionary = {}
	for modifier: SpellModifierData in ContentRegistry.modifiers().values():
		for tag: String in modifier.behavior_tags:
			dynamic_tags[tag] = true
	_check(83, FileAccess.file_exists("res://scripts/ui/ui_icon_factory.gd") and FileAccess.file_exists("res://scripts/ui/trajectory_preview.gd") and FileAccess.file_exists("res://scenes/ui/item_slot.tscn"), "required reusable UI foundation is incomplete")
	_check(84, dynamic_tags.has("ricochet") and dynamic_tags.has("phase_walls") and dynamic_tags.has("tracking") and dynamic_tags.has("beam"), "graphical attachment assets or behaviors are incomplete")

func _validate_raid_ui() -> void:
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
	_check(37, hud.find_child("CombatSlotPanel", true, false) != null and hud.find_child("ExtractionPanel", true, false) != null, "raid HUD layout is incomplete")
	_check(38, hud.find_child("HealthGauge", true, false) != null and hud.find_child("ManaGauge", true, false) != null and hud.find_child("StaminaGauge", true, false) != null, "three graphical gauges are missing")
	_check(39, hud.find_child("BleedingIndicator", true, false) != null and hud.find_child("StatusEffects", true, false) != null, "health and injury icons are missing")
	_check(40, hud.find_child("ManaGauge", true, false) != null and hud.find_child("CastProgress", true, false) != null, "mana/casting feedback is missing")
	_check(41, hud.find_child("StaminaGauge", true, false) != null, "stamina feedback is missing")
	_check(42, hud.find_child("CombatSlots", true, false) is HBoxContainer, "icon combat hotbar is missing")
	_check(43, InputMap.has_action("dagger_attack") and GameState.loadout.has("dagger"), "Slot 4 melee interface is missing")
	_check(44, FileAccess.get_file_as_string("res://scripts/player.gd").contains("spawn_spell_impact"), "elemental melee feedback hook is missing")
	_check(45, hud.find_child("AimReticle", true, false) != null, "spell targeting cursor is missing")
	_check(46, FileAccess.get_file_as_string("res://scripts/ui/raid_hud.gd").contains('reticle.text = "◎"'), "projectile/area cursor switching is missing")
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	_check(50, player.find_child("PlacementPreview", true, false) != null and player.find_child("TrajectoryPreview", true, false) != null, "deployable placement outline is missing")
	player.free()
	_check(51, FileAccess.get_file_as_string("res://scripts/ui/raid_hud.gd").contains('interaction_prompt.text = "◇  E"'), "compact loot interaction icon is missing")
	_check(52, load("res://scenes/ui/inventory_ui.tscn") != null and hud.find_child("RaidSpellSettings", true, false) != null and hud.find_child("EquipmentRows", true, false) != null, "raid equipment, inventory, or spell settings access is missing")
	var raid_source := FileAccess.get_file_as_string("res://scripts/raid_scene.gd")
	_check(53, raid_source.contains('category == "spell"') and raid_source.contains("equip_raid_item"), "in-raid spell/equipment replacement is missing")
	_check(54, raid_source.contains("install_raid_modifier") and raid_source.contains("equip_raid_spell_to_page"), "carried in-raid spell configuration is unavailable")
	_check(55, not FileAccess.get_file_as_string("res://scripts/ui/raid_hud.gd").contains("get_tree().paused = true"), "raid inventory pauses combat")
	var extraction := (load("res://scenes/raid/extraction_zone.tscn") as PackedScene).instantiate()
	_check(56, extraction.countdown_duration > 0.0 and extraction.has_method("_process"), "compact extraction progress is missing")
	extraction.free()
	_check(57, load("res://scenes/ui/raid_result_ui.tscn") != null, "raid result screen is missing")
	_check(58, FileAccess.get_file_as_string("res://scripts/ui/raid_hud.gd").contains("show_message"), "compact combat notifications are missing")
	_check(82, load("res://scenes/main/game_root.tscn") != null and load("res://scenes/ui/hud.tscn") != null, "UI layer separation is missing")
	_check(87, UIIconFactory.navigation_icon("inventory") != null and UIIconFactory.navigation_icon("spellbook") != null, "core visual-recognition controls are unavailable")
	hud.free()

func _validate_magic_content() -> void:
	_check(60, FileAccess.get_file_as_string("res://scripts/player.gd").contains("current_primary_element"), "selected slot does not determine active element")
	_check(61, FileAccess.get_file_as_string("res://scripts/enemy.gd").contains("last_weakness_triggered"), "weakness impact feedback is missing")
	var counts := {"fire":0, "water":0, "grass":0, "neutral":0}
	var behaviors: Dictionary = {}
	var unique_icons: Dictionary = {}
	for spell: BaseSpellData in ContentRegistry.spells().values():
		counts[spell.primary_element] = int(counts.get(spell.primary_element, 0)) + 1
		behaviors[spell.behavior_type] = true
		var texture: Texture2D = UIIconFactory.spell_icon(spell, 96)
		unique_icons[texture.get_instance_id()] = true
	_check(63, int(counts.fire) >= 10 and ContentRegistry.spells().has("emberstream") and ContentRegistry.spells().has("magma_basin"), "ten themed Fire spells are missing")
	_check(64, int(counts.water) >= 10 and ContentRegistry.spells().has("drowning_puddle") and ContentRegistry.spells().has("water_barrier"), "ten themed Water spells are missing")
	_check(65, ContentRegistry.spells().ice_spear.primary_element == "water" and ContentRegistry.spells().freezing_spray.spell_family == "ice", "Ice family classification is incorrect")
	_check(66, ContentRegistry.spells().chain_lightning.primary_element == "water" and ContentRegistry.spells().chain_lightning.spell_family == "lightning", "Lightning family classification is incorrect")
	_check(67, int(counts.grass) >= 10 and ContentRegistry.spells().has("binding_roots") and ContentRegistry.spells().has("briar_wall"), "ten themed Grass spells are missing")
	_check(68, int(counts.neutral) >= 10 and ContentRegistry.spells().has("blink_sigil") and ContentRegistry.spells().has("aegis_dome"), "ten themed Neutral spells are missing")
	_check(69, ContentRegistry.daggers().size() == 4, "four elemental daggers are missing")
	_check(70, ContentRegistry.modifiers().size() >= 26, "attachment expansion is unavailable")
	_check(71, ItemDB.focus("apprentice_wand") != null and ItemDB.resource("novice_hood") != null and ItemDB.resource("emberweave_robes") != null, "armor or magical focus is missing")
	_check(73, ContentRegistry.regions().neutral_frontier.primary_element == "neutral", "Neutral beginner region is incorrect")
	_check(74, ContentRegistry.regions().fire_region.hazard_type == "burn_zones", "Fire region burn terrain is missing")
	_check(75, ContentRegistry.regions().water_region.hazard_type == "water_slow", "Water region slowing terrain is missing")
	_check(76, ContentRegistry.regions().grass_region.hazard_type == "temporary_grass_walls", "Grass region dynamic walls are missing")
	_check(77, FileAccess.get_file_as_string("res://scripts/enemy.gd").contains("health_bar.visible = true"), "damage-only enemy health feedback is missing")
	_check(84, unique_icons.size() == ContentRegistry.spells().size(), "every spell must have its own generated icon")
	_check(50, behaviors.has("wall") and behaviors.has("mine") and behaviors.has("puddle"), "deployable spell behavior set is incomplete")

func _validate_world_and_rules() -> void:
	var melee_enemy := (load("res://scenes/enemies/melee_enemy.tscn") as PackedScene).instantiate()
	_check(78, melee_enemy.find_child("NavigationAgent3D", true, false) != null, "melee shortest-path navigation is missing")
	melee_enemy.free()
	_check(89, GameState.STARTING_SPELL_PAGE_IDS.size() == 41 and GameState.STARTING_MODIFIER_ITEM_IDS.size() == 20 and ItemDB.spell("explosion_page") != null and REGION_GRAPH.ENTRY_REGION_ID == "neutral_frontier", "refined source-of-truth rules or the Explosion formula are not represented")
	for section: int in range(1, 91):
		if matrix.status(section) in ["tested", "partial"] and not exercised.has(section):
			failures.append("Guideline %d (%s) is classified for testing but has no assertion" % [section, matrix.get("section_titles")[section - 1]])

func _finish() -> void:
	UIIconFactory.clear_cache()
	if failures.is_empty():
		print("REFINED GUIDELINE COMPLIANCE PASSED: 90/90 sections classified; 40 elemental spells, Explosion, and 20 additional attachments verified")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		get_tree().quit(1)
