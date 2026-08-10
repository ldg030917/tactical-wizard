extends Node

const REGION_GRAPH := preload("res://scripts/regions/region_graph.gd")

signal state_changed
signal raid_started
signal raid_ended(success: bool, summary: Dictionary)
signal spellbook_changed

const SAVE_PATH := "user://tactical_wizard_save.json"
const STARTING_SPELL_CATALOG_VERSION := 4
const STARTING_SPELL_PAGE_IDS: Array[String] = [
	"fireball_page", "ember_dart_page", "flame_burst_page", "cinder_mortar_page", "wildfire_orb_page",
	"water_bolt_page", "ice_spear_page", "frost_shard_page", "lightning_arc_page", "tidal_volley_page",
	"thorn_shot_page", "root_spike_page", "poison_spore_page", "seed_barrage_page", "vine_orb_page",
	"arcane_bolt_page", "healing_circle_page", "arcane_missile_page", "gilt_barrage_page", "gravity_orb_page",
	"emberstream_page", "magma_basin_page", "searing_wall_page", "smoke_nova_page", "meteor_crown_page",
	"freezing_spray_page", "drowning_puddle_page", "ice_wall_page", "chain_lightning_page", "water_barrier_page",
	"binding_roots_page", "briar_wall_page", "spore_bloom_page", "timber_lance_page", "verdant_mine_page",
	"blink_sigil_page", "mana_spring_page", "aegis_dome_page", "cleanse_pulse_page", "repulsion_wave_page",
	"explosion_page"
]
const STARTING_MODIFIER_ITEM_IDS: Array[String] = [
	"mod_ricochet_rune", "mod_left_pivot_sigil", "mod_right_pivot_sigil", "mod_ghostglass_rune", "mod_seeker_thread",
	"mod_prism_beam", "mod_piercing_needle", "mod_twin_echo", "mod_triple_echo", "mod_volatile_core",
	"mod_frugal_glyph", "mod_quickcast_knot", "mod_farstep_lens", "mod_heavy_comet", "mod_lingering_script",
	"mod_searing_brand", "mod_rime_seal", "mod_venom_script", "mod_gravitic_well", "mod_delayed_echo"
]

var stash: Dictionary = {}
var currency: int = 0
var loadout: Dictionary = {}
var spell_pages: Array = []
var attachments: Dictionary = {}
var base_upgrades: Dictionary = {}
var skills: Dictionary = {}
var skill_points: int = 0
var quests: Array = []
var raid_inventory: Dictionary = {}
var raid_secure: Dictionary = {}
var raid_kills: Dictionary = {}
var raid_start_time: int = 0
var in_raid: bool = false
var last_summary: Dictionary = {}
var selected_character_id: String = "mana_specialist"
var current_raid_region_id: String = ""
var raid_visited_regions: Array[String] = []
var raid_player_state: Dictionary = {}
var explosion_used_this_raid: bool = false
var spell_catalog_version: int = STARTING_SPELL_CATALOG_VERSION

func _ready() -> void:
	_setup_input_actions()
	load_game()

func _default_data() -> Dictionary:
	return {
		"stash": {
			"health_potion":2, "mana_potion":2, "fireball_page":1, "ice_spear_page":1,
			"healing_circle_page":1, "water_bolt_page":1, "thorn_shot_page":1, "arcane_bolt_page":1,
			"ember_dart_page":1, "flame_burst_page":1, "cinder_mortar_page":1, "wildfire_orb_page":1,
			"frost_shard_page":1, "lightning_arc_page":1, "tidal_volley_page":1,
			"root_spike_page":1, "poison_spore_page":1, "seed_barrage_page":1, "vine_orb_page":1,
			"arcane_missile_page":1, "gilt_barrage_page":1, "gravity_orb_page":1,
			"emberstream_page":1, "magma_basin_page":1, "searing_wall_page":1, "smoke_nova_page":1, "meteor_crown_page":1,
			"freezing_spray_page":1, "drowning_puddle_page":1, "ice_wall_page":1, "chain_lightning_page":1, "water_barrier_page":1,
			"binding_roots_page":1, "briar_wall_page":1, "spore_bloom_page":1, "timber_lance_page":1, "verdant_mine_page":1,
			"blink_sigil_page":1, "mana_spring_page":1, "aegis_dome_page":1, "cleanse_pulse_page":1, "repulsion_wave_page":1,
			"explosion_page":1,
			"mod_increased_range":1, "mod_curved_trajectory":1,
			"mod_ricochet_rune":1, "mod_left_pivot_sigil":1, "mod_right_pivot_sigil":1, "mod_ghostglass_rune":1, "mod_seeker_thread":1,
			"mod_prism_beam":1, "mod_piercing_needle":1, "mod_twin_echo":1, "mod_triple_echo":1, "mod_volatile_core":1,
			"mod_frugal_glyph":1, "mod_quickcast_knot":1, "mod_farstep_lens":1, "mod_heavy_comet":1, "mod_lingering_script":1,
			"mod_searing_brand":1, "mod_rime_seal":1, "mod_venom_script":1, "mod_gravitic_well":1, "mod_delayed_echo":1,
			"arcane_dust":8, "mana_crystal":5, "ash_essence":3, "small_pack":1,
			"novice_hood":1, "emberweave_robes":1, "neutral_dagger":1
		},
		"currency":420,
		"loadout": {
			"spellbook":"apprentice_grimoire", "focus":"apprentice_wand", "dagger":"neutral_dagger",
			"head":"", "chest":"", "accessory_1":"", "accessory_2":"", "backpack":"",
			"consumable_1":"health_potion", "consumable_2":"mana_potion"
		},
		"spell_pages": _default_spell_pages(),
		"attachments": {},
		"base_upgrades": {"storage":1, "workbench":1, "medical":1},
		"skills": _default_skills(),
		"skill_points":1,
		"quests": _default_quests(),
		"selected_character_id":"mana_specialist",
		"spell_catalog_version":STARTING_SPELL_CATALOG_VERSION
	}

func _default_spell_pages() -> Array:
	return [
		{"spell_item":"fireball_page", "modifiers":["mod_increased_range"]},
		{"spell_item":"ice_spear_page", "modifiers":[]},
		{"spell_item":"healing_circle_page", "modifiers":[]}
	]

func _default_quests() -> Array:
	var result: Array = []
	var quest_resources: Array[QuestData] = ContentRegistry.quests()
	for index: int in range(quest_resources.size()):
		result.append(quest_resources[index].to_runtime_dictionary(index == 0))
	return result

func _default_skills() -> Dictionary:
	var result: Dictionary = {}
	for skill_id: String in ContentRegistry.skills().keys():
		result[skill_id] = 0
	return result

func load_game() -> void:
	var data: Dictionary = _default_data()
	var stored_catalog_version: int = STARTING_SPELL_CATALOG_VERSION
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				stored_catalog_version = int(parsed.get("spell_catalog_version", 0))
				for key: String in data.keys():
					if parsed.has(key):
						data[key] = parsed[key]
	stash = data.stash.duplicate(true)
	currency = int(data.currency)
	loadout = data.loadout.duplicate(true)
	spell_pages = data.spell_pages.duplicate(true)
	attachments = data.attachments.duplicate(true)
	base_upgrades = data.base_upgrades.duplicate(true)
	skills = data.skills.duplicate(true)
	skill_points = int(data.skill_points)
	quests = data.quests.duplicate(true)
	selected_character_id = str(data.get("selected_character_id", "mana_specialist"))
	spell_catalog_version = stored_catalog_version
	_sanitize_data()
	if spell_catalog_version < STARTING_SPELL_CATALOG_VERSION:
		_grant_starting_spell_catalog()
		spell_catalog_version = STARTING_SPELL_CATALOG_VERSION
		save_game()

func _sanitize_data() -> void:
	var old_layout: bool = loadout.has("slot1") and not loadout.has("spellbook")
	var defaults: Dictionary = _default_data().loadout
	if loadout.has("accessory") and not loadout.has("accessory_1"):
		loadout.accessory_1 = loadout.accessory
		loadout.erase("accessory")
	for slot: String in ["spellbook", "focus", "dagger", "head", "chest", "accessory_1", "accessory_2", "backpack", "consumable_1", "consumable_2"]:
		if not loadout.has(slot):
			loadout[slot] = defaults.get(slot, "") if old_layout or slot == "dagger" else ""
	if old_layout:
		for old_slot: String in ["slot1", "slot2", "melee", "armor"]:
			loadout.erase(old_slot)
	if spell_pages.size() != 3:
		spell_pages = _default_spell_pages()
	for index: int in range(spell_pages.size()):
		if not spell_pages[index] is Dictionary:
			spell_pages[index] = _default_spell_pages()[index]
		if not spell_pages[index].has("spell_item"):
			spell_pages[index].spell_item = ""
		if not spell_pages[index].has("modifiers") or not spell_pages[index].modifiers is Array:
			spell_pages[index].modifiers = []
	for key: String in ["storage", "workbench", "medical"]:
		if not base_upgrades.has(key):
			base_upgrades[key] = 1
	for key: String in ContentRegistry.skills().keys():
		if not skills.has(key):
			skills[key] = 0
	if not ContentRegistry.characters().has(selected_character_id):
		selected_character_id = "mana_specialist"

func save_game() -> void:
	var data := {
		"stash":stash, "currency":currency, "loadout":loadout, "spell_pages":spell_pages,
		"attachments":attachments, "base_upgrades":base_upgrades, "skills":skills,
		"skill_points":skill_points, "quests":quests,
		"selected_character_id":selected_character_id,
		"spell_catalog_version":spell_catalog_version
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))

func reset_save_for_debug() -> void:
	var data := _default_data()
	stash = data.stash.duplicate(true)
	currency = int(data.currency)
	loadout = data.loadout.duplicate(true)
	spell_pages = data.spell_pages.duplicate(true)
	attachments = {}
	base_upgrades = data.base_upgrades.duplicate(true)
	skills = data.skills.duplicate(true)
	skill_points = int(data.skill_points)
	quests = data.quests.duplicate(true)
	selected_character_id = str(data.selected_character_id)
	spell_catalog_version = int(data.spell_catalog_version)
	save_game()
	state_changed.emit()
	spellbook_changed.emit()

func add_to_stash(item_id: String, amount: int = 1) -> void:
	if amount > 0:
		stash[item_id] = int(stash.get(item_id, 0)) + amount

func _grant_starting_spell_catalog() -> void:
	_grant_missing_starting_spell_pages(stash, spell_pages)
	for item_id: String in STARTING_MODIFIER_ITEM_IDS:
		if int(stash.get(item_id, 0)) <= 0:
			stash[item_id] = 1

static func _grant_missing_starting_spell_pages(profile_stash: Dictionary, profile_pages: Array) -> int:
	var installed_pages: Dictionary = {}
	for page: Dictionary in profile_pages:
		installed_pages[str(page.get("spell_item", ""))] = true
	var granted: int = 0
	for item_id: String in STARTING_SPELL_PAGE_IDS:
		if not installed_pages.has(item_id) and int(profile_stash.get(item_id, 0)) <= 0:
			profile_stash[item_id] = 1
			granted += 1
	return granted

func content_parity_snapshot() -> Dictionary:
	var missing_page_resources: Array[String] = []
	var missing_spell_resources: Array[String] = []
	var missing_from_new_profile: Array[String] = []
	var missing_from_current_profile: Array[String] = []
	var missing_modifier_resources: Array[String] = []
	var unique_spell_ids: Dictionary = {}
	var defaults: Dictionary = _default_data()
	var default_stash: Dictionary = defaults.stash
	var default_installed: Dictionary = {}
	for page: Dictionary in defaults.spell_pages:
		default_installed[str(page.get("spell_item", ""))] = true
	for item_id: String in STARTING_SPELL_PAGE_IDS:
		var item_resource: ItemData = ItemDB.resource(item_id)
		if item_resource == null:
			missing_page_resources.append(item_id)
			continue
		var spell: BaseSpellData = item_resource.base_spell
		if spell == null:
			missing_spell_resources.append(item_id)
		else:
			unique_spell_ids[spell.spell_id] = true
		if not default_installed.has(item_id) and int(default_stash.get(item_id, 0)) <= 0:
			missing_from_new_profile.append(item_id)
	for item_id: String in STARTING_MODIFIER_ITEM_IDS:
		if ItemDB.modifier(item_id) == null:
			missing_modifier_resources.append(item_id)
	var registered_spells: Dictionary = ContentRegistry.spells()
	for spell_id: String in unique_spell_ids.keys():
		if not registered_spells.has(spell_id):
			missing_spell_resources.append(spell_id)
	var currently_installed: Dictionary = {}
	for page: Dictionary in spell_pages:
		currently_installed[str(page.get("spell_item", ""))] = true
	for item_id: String in STARTING_SPELL_PAGE_IDS:
		if not currently_installed.has(item_id) and int(stash.get(item_id, 0)) <= 0:
			missing_from_current_profile.append(item_id)
	var legacy_stash: Dictionary = {"fireball_page":1}
	var legacy_pages: Array = _default_spell_pages()
	var legacy_granted_count: int = _grant_missing_starting_spell_pages(legacy_stash, legacy_pages)
	var legacy_available: Dictionary = {}
	for page: Dictionary in legacy_pages:
		legacy_available[str(page.get("spell_item", ""))] = true
	for item_id: String in legacy_stash.keys():
		if int(legacy_stash[item_id]) > 0:
			legacy_available[item_id] = true
	var ok: bool = STARTING_SPELL_PAGE_IDS.size() == 41 \
		and unique_spell_ids.size() == 41 \
		and STARTING_MODIFIER_ITEM_IDS.size() == 20 \
		and missing_page_resources.is_empty() \
		and missing_spell_resources.is_empty() \
		and missing_modifier_resources.is_empty() \
		and missing_from_new_profile.is_empty() \
		and legacy_available.size() == 41
	return {
		"ok":ok,
		"starting_page_count":STARTING_SPELL_PAGE_IDS.size(),
		"starting_spell_count":unique_spell_ids.size(),
		"registered_spell_count":registered_spells.size(),
		"missing_page_resources":missing_page_resources,
		"missing_spell_resources":missing_spell_resources,
		"missing_modifier_resources":missing_modifier_resources,
		"additional_modifier_count":STARTING_MODIFIER_ITEM_IDS.size(),
		"missing_from_new_profile":missing_from_new_profile,
		"missing_from_current_profile":missing_from_current_profile,
		"catalog_version":STARTING_SPELL_CATALOG_VERSION,
		"profile_catalog_version":spell_catalog_version,
		"legacy_migration_available_count":legacy_available.size(),
		"legacy_migration_granted_count":legacy_granted_count,
		"resolved_save_path":ProjectSettings.globalize_path(SAVE_PATH)
	}

func remove_from_stash(item_id: String, amount: int = 1) -> bool:
	if int(stash.get(item_id, 0)) < amount:
		return false
	stash[item_id] = int(stash.get(item_id, 0)) - amount
	if int(stash[item_id]) <= 0:
		stash.erase(item_id)
	return true

func stash_capacity() -> int:
	var storage_data: BaseUpgradeData = ContentRegistry.upgrades().get("storage") as BaseUpgradeData
	var per_level: int = int(storage_data.benefit_per_level) if storage_data != null else 20
	# The starting collection now contains every formula and attachment, so a fresh
	# profile must never begin over capacity.
	return 120 + (int(base_upgrades.get("storage", 1)) - 1) * per_level

func raid_capacity() -> int:
	var result: int = 10 + int(skill_bonus("capacity"))
	var character := selected_character()
	if character != null:
		result += character.carrying_capacity_bonus
	var pack_id: String = str(loadout.get("backpack", ""))
	if not pack_id.is_empty():
		result += int(ItemDB.get_item(pack_id).get("capacity", 0))
	return result

func skill_bonus(skill_id: String) -> float:
	var skill := ContentRegistry.skills().get(skill_id) as SkillData
	if skill == null:
		return 0.0
	var value: float = float(skills.get(skill_id, 0)) * skill.benefit_per_rank
	return value / 100.0 if skill.benefit_mode == "percent" else value

func selected_character() -> CharacterData:
	return ContentRegistry.characters().get(selected_character_id) as CharacterData

func current_raid_region() -> RegionData:
	var region_id: String = current_raid_region_id if in_raid and not current_raid_region_id.is_empty() else REGION_GRAPH.ENTRY_REGION_ID
	return ContentRegistry.regions().get(region_id) as RegionData

func select_character(character_id: String) -> bool:
	if not ContentRegistry.characters().has(character_id):
		return false
	selected_character_id = character_id
	save_game()
	state_changed.emit()
	return true

func inventory_slots(items: Dictionary) -> int:
	var total: int = 0
	for item_id: String in items.keys():
		var info: Dictionary = ItemDB.get_item(item_id)
		var amount: int = int(items[item_id])
		var stack_size: int = maxi(1, int(info.get("stack", 1)))
		total += int(info.get("slots", 1)) * int(ceil(float(amount) / float(stack_size)))
	return total

func inventory_weight(items: Dictionary) -> float:
	var total: float = 0.0
	for item_id: String in items.keys():
		total += float(ItemDB.get_item(item_id).get("weight", 0.0)) * int(items[item_id])
	return total

func can_add_raid_item(item_id: String, amount: int = 1) -> bool:
	var copy: Dictionary = raid_inventory.duplicate()
	copy[item_id] = int(copy.get(item_id, 0)) + amount
	return inventory_slots(copy) <= raid_capacity()

func add_raid_item(item_id: String, amount: int = 1) -> bool:
	if not can_add_raid_item(item_id, amount):
		return false
	raid_inventory[item_id] = int(raid_inventory.get(item_id, 0)) + amount
	state_changed.emit()
	return true

func remove_raid_item(item_id: String, amount: int = 1) -> bool:
	if int(raid_inventory.get(item_id, 0)) < amount:
		return false
	raid_inventory[item_id] = int(raid_inventory[item_id]) - amount
	if int(raid_inventory[item_id]) <= 0:
		raid_inventory.erase(item_id)
	state_changed.emit()
	return true

func secure_item(item_id: String) -> bool:
	if not raid_inventory.has(item_id) or inventory_slots(raid_secure) >= 2:
		return false
	var info: Dictionary = ItemDB.get_item(item_id)
	if int(info.get("slots", 1)) > 2 or not bool(info.get("secure_eligible", true)):
		return false
	remove_raid_item(item_id, 1)
	raid_secure[item_id] = int(raid_secure.get(item_id, 0)) + 1
	state_changed.emit()
	return true

func equipped_spellbook() -> SpellbookData:
	return ItemDB.spellbook(str(loadout.get("spellbook", "")))

func equipped_focus() -> FocusData:
	return ItemDB.focus(str(loadout.get("focus", "")))

func spell_config(page_index: int) -> RuntimeSpellConfig:
	if page_index < 0 or page_index >= spell_pages.size():
		return RuntimeSpellConfig.build(null, [], equipped_spellbook(), equipped_focus())
	var page: Dictionary = spell_pages[page_index]
	var spell: BaseSpellData = ItemDB.spell(str(page.get("spell_item", "")))
	var modifiers: Array[SpellModifierData] = []
	for modifier_item_id: Variant in page.get("modifiers", []):
		var modifier: SpellModifierData = ItemDB.modifier(str(modifier_item_id))
		if modifier != null:
			modifiers.append(modifier)
	var config := RuntimeSpellConfig.build(spell, modifiers, equipped_spellbook(), equipped_focus(), true)
	if config.valid:
		config.cast_time *= 1.0 - skill_bonus("casting_speed")
		config.damage_or_healing *= 1.0 + skill_bonus("accuracy")
	return config

func install_page_spell(page_index: int, spell_item_id: String) -> bool:
	if in_raid:
		return false
	if page_index < 0 or page_index >= spell_pages.size() or ItemDB.spell(spell_item_id) == null:
		return false
	if not remove_from_stash(spell_item_id, 1):
		return false
	var old: String = str(spell_pages[page_index].get("spell_item", ""))
	if not old.is_empty():
		add_to_stash(old, 1)
	for modifier_item_id: Variant in spell_pages[page_index].get("modifiers", []):
		add_to_stash(str(modifier_item_id), 1)
	spell_pages[page_index] = {"spell_item":spell_item_id, "modifiers":[]}
	_save_spellbook_change()
	return true

func install_page_modifier(page_index: int, modifier_item_id: String) -> Dictionary:
	if in_raid:
		return {"success":false, "message":"Full spell attachment rebuilding is only available at the Base."}
	if page_index < 0 or page_index >= spell_pages.size():
		return {"success":false, "message":"Invalid spell page."}
	var spell: BaseSpellData = ItemDB.spell(str(spell_pages[page_index].get("spell_item", "")))
	var modifier: SpellModifierData = ItemDB.modifier(modifier_item_id)
	if modifier == null:
		return {"success":false, "message":"That item is not a spell modifier."}
	if not modifier.is_compatible(spell):
		return {"success":false, "message":modifier.incompatibility_reason(spell)}
	var book: SpellbookData = equipped_spellbook()
	var installed: Array = spell_pages[page_index].get("modifiers", [])
	if book == null or installed.size() >= book.maximum_modifiers_per_page:
		return {"success":false, "message":"This page has no remaining modifier sockets."}
	if modifier_item_id in installed:
		return {"success":false, "message":"That modifier is already installed."}
	if not remove_from_stash(modifier_item_id, 1):
		return {"success":false, "message":"The modifier is not in the stash."}
	installed.append(modifier_item_id)
	spell_pages[page_index].modifiers = installed
	_save_spellbook_change()
	return {"success":true, "message":"Installed %s." % modifier.display_name}

func remove_page_modifier(page_index: int, modifier_index: int) -> bool:
	if in_raid:
		return false
	if page_index < 0 or page_index >= spell_pages.size():
		return false
	var installed: Array = spell_pages[page_index].get("modifiers", [])
	if modifier_index < 0 or modifier_index >= installed.size():
		return false
	add_to_stash(str(installed[modifier_index]), 1)
	installed.remove_at(modifier_index)
	spell_pages[page_index].modifiers = installed
	_save_spellbook_change()
	return true

func _save_spellbook_change() -> void:
	save_game()
	state_changed.emit()
	spellbook_changed.emit()

func begin_raid() -> bool:
	if str(loadout.get("spellbook", "")).is_empty():
		loadout.spellbook = "apprentice_grimoire"
	if str(loadout.get("focus", "")).is_empty():
		loadout.focus = "apprentice_wand"
	if str(loadout.get("dagger", "")).is_empty():
		loadout.dagger = "neutral_dagger"
	raid_inventory.clear()
	raid_secure.clear()
	raid_kills = {"monster":0, "mage":0, "construct":0, "boss":0}
	raid_player_state.clear()
	explosion_used_this_raid = false
	current_raid_region_id = REGION_GRAPH.ENTRY_REGION_ID
	raid_visited_regions = [REGION_GRAPH.ENTRY_REGION_ID]
	for slot: String in ["consumable_1", "consumable_2"]:
		var item_id: String = str(loadout.get(slot, ""))
		if not item_id.is_empty():
			raid_inventory[item_id] = int(raid_inventory.get(item_id, 0)) + 1
			loadout[slot] = ""
	raid_start_time = Time.get_ticks_msec()
	in_raid = true
	save_game()
	raid_started.emit()
	return true

func can_use_explosion() -> bool:
	return in_raid and not explosion_used_this_raid

func consume_explosion_use() -> bool:
	if not can_use_explosion():
		return false
	explosion_used_this_raid = true
	state_changed.emit()
	return true

func can_enter_raid_region(region_id: String) -> bool:
	if not in_raid or not ContentRegistry.regions().has(region_id):
		return false
	if region_id in raid_visited_regions:
		return true
	var region := ContentRegistry.regions()[region_id] as RegionData
	return currency >= region.entry_cost and (region.required_ticket_id.is_empty() or int(stash.get(region.required_ticket_id, 0)) > 0 or int(raid_inventory.get(region.required_ticket_id, 0)) > 0)

func enter_raid_region(region_id: String) -> bool:
	if not REGION_GRAPH.are_connected(current_raid_region_id, region_id) or not can_enter_raid_region(region_id):
		return false
	if region_id not in raid_visited_regions:
		var region := ContentRegistry.regions()[region_id] as RegionData
		if region.entry_cost > 0:
			currency -= region.entry_cost
		if not region.required_ticket_id.is_empty():
			if not remove_raid_item(region.required_ticket_id, 1):
				remove_from_stash(region.required_ticket_id, 1)
		raid_visited_regions.append(region_id)
	current_raid_region_id = region_id
	state_changed.emit()
	return true

func finish_raid(success: bool, kills: Dictionary, extraction_name: String = "") -> Dictionary:
	for enemy_type: String in kills.keys():
		raid_kills[enemy_type] = maxi(int(raid_kills.get(enemy_type, 0)), int(kills[enemy_type]))
	kills = raid_kills.duplicate(true)
	var duration: int = maxi(1, int((Time.get_ticks_msec() - raid_start_time) / 1000.0))
	var recovered: Dictionary = {}
	var lost: Dictionary = {}
	var value: int = 0
	if success:
		for source: Dictionary in [raid_inventory, raid_secure]:
			for item_id: String in source.keys():
				var amount: int = int(source[item_id])
				add_to_stash(item_id, amount)
				recovered[item_id] = int(recovered.get(item_id, 0)) + amount
				value += int(ItemDB.get_item(item_id).get("value", 0)) * amount
		skill_points += 1
		advance_quest("extract", "success", 1)
		for item_id: String in recovered.keys():
			advance_quest("item", item_id, int(recovered[item_id]))
	else:
		lost = raid_inventory.duplicate(true)
		for slot: String in ["spellbook", "focus", "dagger", "head", "chest", "accessory_1", "accessory_2", "backpack"]:
			var equipped_id: String = str(loadout.get(slot, ""))
			if not equipped_id.is_empty():
				lost[equipped_id] = int(lost.get(equipped_id, 0)) + 1
			loadout[slot] = ""
		for item_id: String in raid_secure.keys():
			add_to_stash(item_id, int(raid_secure[item_id]))
		loadout.spellbook = "apprentice_grimoire"
		loadout.focus = "apprentice_wand"
		loadout.dagger = "neutral_dagger"
		spell_pages = _default_spell_pages()
	for enemy_type: String in kills.keys():
		advance_quest("kill", enemy_type, int(kills[enemy_type]))
	var total_kills: int = 0
	for count: Variant in kills.values():
		total_kills += int(count)
	last_summary = {
		"success":success, "recovered":recovered, "lost":lost, "value":value,
		"kills":total_kills, "duration":duration, "extraction":extraction_name
	}
	raid_inventory.clear()
	raid_secure.clear()
	raid_player_state.clear()
	explosion_used_this_raid = false
	raid_visited_regions.clear()
	current_raid_region_id = ""
	in_raid = false
	save_game()
	state_changed.emit()
	raid_ended.emit(success, last_summary)
	return last_summary

func equip_from_stash(item_id: String) -> bool:
	var category: String = str(ItemDB.get_item(item_id).get("category", ""))
	var slot: String = ""
	match category:
		"spellbook": slot = "spellbook"
		"focus": slot = "focus"
		"dagger", "melee": slot = "dagger"
		"armor_head": slot = "head"
		"armor_chest", "armor": slot = "chest"
		"accessory": slot = "accessory_1" if str(loadout.get("accessory_1", "")).is_empty() else "accessory_2"
		"backpack": slot = "backpack"
		"medical", "mana_consumable": slot = "consumable_1" if str(loadout.get("consumable_1", "")).is_empty() else "consumable_2"
		_: return false
	if not remove_from_stash(item_id, 1):
		return false
	var old: String = str(loadout.get(slot, ""))
	if not old.is_empty():
		add_to_stash(old, 1)
	loadout[slot] = item_id
	save_game()
	state_changed.emit()
	if slot in ["spellbook", "focus"]:
		spellbook_changed.emit()
	return true

func equip_from_stash_to_slot(item_id: String, slot: String) -> bool:
	var category: String = str(ItemDB.get_item(item_id).get("category", ""))
	var accepted: Dictionary = {
		"spellbook":["spellbook"], "focus":["focus"], "dagger":["dagger", "melee"],
		"head":["armor_head"], "chest":["armor_chest", "armor"],
		"accessory_1":["accessory"], "accessory_2":["accessory"], "backpack":["backpack"],
		"consumable_1":["medical", "mana_consumable", "food", "drink"],
		"consumable_2":["medical", "mana_consumable", "food", "drink"]
	}
	var allowed_categories: Array = accepted.get(slot, [])
	if category not in allowed_categories:
		return false
	if not remove_from_stash(item_id, 1):
		return false
	var old: String = str(loadout.get(slot, ""))
	if not old.is_empty():
		add_to_stash(old, 1)
	loadout[slot] = item_id
	save_game()
	state_changed.emit()
	if slot in ["spellbook", "focus"]:
		spellbook_changed.emit()
	return true

func unequip(slot: String) -> bool:
	var item_id: String = str(loadout.get(slot, ""))
	if item_id.is_empty():
		return false
	add_to_stash(item_id, 1)
	loadout[slot] = ""
	save_game()
	state_changed.emit()
	return true

func purchase_starter_package(package_id: String = "neutral_recovery") -> bool:
	var package := ContentRegistry.starter_packages().get(package_id) as StarterPackageData
	if package == null or currency < package.currency_cost:
		return false
	currency -= package.currency_cost
	for item_id: String in package.contents().keys():
		add_to_stash(item_id, int(package.contents()[item_id]))
	save_game()
	state_changed.emit()
	return true

func sell_item(item_id: String) -> bool:
	if not remove_from_stash(item_id, 1):
		return false
	currency += int(ItemDB.get_item(item_id).get("value", 0))
	save_game()
	state_changed.emit()
	return true

func buy_item(item_id: String, price: int) -> bool:
	if currency < price or inventory_slots(stash) >= stash_capacity():
		return false
	currency -= price
	add_to_stash(item_id, 1)
	save_game()
	state_changed.emit()
	return true

func craft(recipe_id: String) -> bool:
	var recipe := ContentRegistry.recipes().get(recipe_id) as CraftingRecipeData
	if recipe == null or int(base_upgrades.get("workbench", 1)) < recipe.required_workbench_level or currency < recipe.currency_cost:
		return false
	for ingredient: CraftIngredientData in recipe.ingredients:
		if ingredient == null or ingredient.item == null or int(stash.get(ingredient.item.item_id, 0)) < ingredient.quantity:
			return false
	for ingredient: CraftIngredientData in recipe.ingredients:
		remove_from_stash(ingredient.item.item_id, ingredient.quantity)
	if recipe.output_item == null:
		return false
	add_to_stash(recipe.output_item.item_id, recipe.output_quantity)
	currency -= recipe.currency_cost
	save_game()
	state_changed.emit()
	return true

func purchase_base_upgrade(upgrade_id: String) -> bool:
	var upgrade := ContentRegistry.upgrades().get(upgrade_id) as BaseUpgradeData
	if upgrade == null:
		return false
	var level: int = int(base_upgrades.get(upgrade_id, 1))
	if level >= upgrade.maximum_level:
		return false
	var cost: int = upgrade.currency_cost_per_level * level
	var material_cost: int = upgrade.material_cost_per_level * level
	var material_id: String = upgrade.material_item.item_id if upgrade.material_item != null else "arcane_dust"
	if currency < cost or int(stash.get(material_id, 0)) < material_cost:
		return false
	currency -= cost
	remove_from_stash(material_id, material_cost)
	base_upgrades[upgrade_id] = level + 1
	save_game()
	state_changed.emit()
	return true

func purchase_skill(skill_id: String) -> bool:
	var skill := ContentRegistry.skills().get(skill_id) as SkillData
	if skill_points <= 0 or skill == null:
		return false
	var rank: int = int(skills.get(skill_id, 0))
	if rank >= skill.maximum_rank:
		return false
	skills[skill_id] = rank + 1
	skill_points -= 1
	save_game()
	state_changed.emit()
	return true

func accept_quest(quest_id: String) -> void:
	for quest: Dictionary in quests:
		if str(quest.id) == quest_id and str(quest.state) == "available":
			quest.state = "active"
			save_game()
			state_changed.emit()
			return

func advance_quest(kind: String, target: String, amount: int) -> void:
	for quest: Dictionary in quests:
		if str(quest.state) != "active" or str(quest.type) != kind or str(quest.target) != target:
			continue
		quest.progress = mini(int(quest.needed), int(quest.progress) + amount)
		if int(quest.progress) >= int(quest.needed):
			quest.state = "complete"

func claim_quest(quest_id: String) -> bool:
	for index: int in range(quests.size()):
		var quest: Dictionary = quests[index]
		if str(quest.id) != quest_id or str(quest.state) != "complete":
			continue
		quest.state = "claimed"
		currency += int(quest.reward_currency)
		if not str(quest.reward_item).is_empty():
			add_to_stash(str(quest.reward_item), 1)
		skill_points += int(quest.get("reward_skill_points", 1))
		if index + 1 < quests.size() and str(quests[index + 1].state) == "locked":
			quests[index + 1].state = "available"
		save_game()
		state_changed.emit()
		return true
	return false

func active_quest_text() -> String:
	for quest: Dictionary in quests:
		if str(quest.state) == "active":
			return "%s: %d/%d" % [str(quest.name), int(quest.progress), int(quest.needed)]
	return "No active expedition"

func _setup_input_actions() -> void:
	_add_key_action("move_up", KEY_W)
	_add_key_action("move_down", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("interact", KEY_E)
	_add_key_action("heal", KEY_F)
	_add_key_action("inventory", KEY_TAB)
	_add_key_action("inventory", KEY_I)
	_add_key_action("spell_page_1", KEY_1)
	_add_key_action("spell_page_2", KEY_2)
	_add_key_action("spell_page_3", KEY_3)
	_add_key_action("dagger_slot", KEY_4)
	_add_key_action("dagger_attack", KEY_SPACE)
	_add_key_action("quick_item_1", KEY_F)
	_add_key_action("quick_item_2", KEY_G)
	_add_key_action("sprint", KEY_SHIFT)
	_add_key_action("crouch", KEY_C)
	_add_key_action("crouch", KEY_CTRL)
	_add_key_action("pause_game", KEY_ESCAPE)
	_add_mouse_action("cast_spell", MOUSE_BUTTON_LEFT)
	_add_mouse_action("cancel_cast", MOUSE_BUTTON_RIGHT)
func _add_key_action(action: StringName, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing: InputEvent in InputMap.action_get_events(action):
		if existing is InputEventKey and (existing as InputEventKey).physical_keycode == key:
			return
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)

func _add_mouse_action(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing: InputEvent in InputMap.action_get_events(action):
		if existing is InputEventMouseButton and (existing as InputEventMouseButton).button_index == button:
			return
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
