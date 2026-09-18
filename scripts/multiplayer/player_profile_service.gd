extends Node

## Server-owned identity/session/profile boundary. Network code asks this service
## for profiles; only PlayerProfileStorage knows that persistence is currently JSON.

var sessions_by_peer: Dictionary = {}
var peer_by_user_id: Dictionary = {}
var profiles: Dictionary = {}
var storage: PlayerProfileStorage

const VENDOR_PRICES := {
	"health_potion":72,
	"mana_potion":80,
	"apprentice_grimoire":190,
	"apprentice_wand":150,
	"novice_hood":175,
	"small_pack":170,
	"arcane_dust":28
}


func _ready() -> void:
	storage = PlayerProfileStorage.new()


func register_peer(peer_id: int, user_id: String) -> Dictionary:
	var normalized_id := user_id.strip_edges().to_lower()
	if peer_id <= 1 or not PlayerProfileStorage._is_safe_uuid(normalized_id):
		return {"ok": false, "reason": "invalid_user_id"}
	if sessions_by_peer.has(peer_id):
		return {"ok": false, "reason": "peer_already_registered"}
	var existing_peer := int(peer_by_user_id.get(normalized_id, 0))
	if existing_peer > 0 and existing_peer != peer_id and sessions_by_peer.has(existing_peer):
		print("[IDENTITY] duplicate rejected peer=%d user_id=%s active_peer=%d" % [peer_id, normalized_id, existing_peer])
		return {"ok": false, "reason": "user_already_connected"}
	print("[IDENTITY] peer=%d submitted user_id=%s" % [peer_id, normalized_id])
	var profile := load_player_profile(normalized_id)
	if profile == null:
		return {"ok": false, "reason": "profile_load_failed"}
	var session := PlayerSession.new(peer_id, normalized_id)
	session.connection_state = "MULTIPLAYER_LOBBY"
	session.profile_loaded = true
	sessions_by_peer[peer_id] = session
	peer_by_user_id[normalized_id] = peer_id
	print("[SESSION] created peer=%d user_id=%s" % [peer_id, normalized_id])
	return {"ok": true, "session": session, "profile": profile}


func remove_peer(peer_id: int) -> void:
	var session := sessions_by_peer.get(peer_id) as PlayerSession
	if session == null:
		return
	save_player_profile(session.user_id)
	sessions_by_peer.erase(peer_id)
	if int(peer_by_user_id.get(session.user_id, 0)) == peer_id:
		peer_by_user_id.erase(session.user_id)
	print("[SESSION] removed peer=%d user_id=%s" % [peer_id, session.user_id])


func has_session(peer_id: int) -> bool:
	return sessions_by_peer.has(peer_id)


func get_session(peer_id: int) -> PlayerSession:
	return sessions_by_peer.get(peer_id) as PlayerSession


func set_raid_session(peer_id: int, raid_session_id: String) -> void:
	var session := get_session(peer_id)
	if session != null:
		session.raid_session_id = raid_session_id
		session.connection_state = "IN_RAID" if not raid_session_id.is_empty() else "MULTIPLAYER_LOBBY"


func load_player_profile(user_id: String) -> PlayerProfile:
	if not PlayerProfileStorage._is_safe_uuid(user_id):
		return null
	if profiles.has(user_id):
		return profiles[user_id] as PlayerProfile
	print("[PROFILE] loading user_id=%s" % user_id)
	var stored := storage.load_profile_data(user_id)
	var profile: PlayerProfile
	if stored.is_empty():
		profile = create_default_profile(user_id)
	else:
		profile = PlayerProfile.from_dictionary(stored, user_id)
		profiles[user_id] = profile
		print("[PROFILE] loaded user_id=%s" % user_id)
	return profile


func create_default_profile(user_id: String) -> PlayerProfile:
	if not PlayerProfileStorage._is_safe_uuid(user_id):
		return null
	var profile := PlayerProfile.create_default(user_id, GameState.default_profile_data())
	profiles[user_id] = profile
	if not save_player_profile(user_id):
		profiles.erase(user_id)
		return null
	print("[PROFILE] created default profile user_id=%s" % user_id)
	return profile


func save_player_profile(user_id: String) -> bool:
	var profile := profiles.get(user_id) as PlayerProfile
	if profile == null:
		return false
	var saved := storage.save_profile_data(user_id, profile.to_dictionary())
	if saved:
		print("[PROFILE] saved user_id=%s" % user_id)
	return saved


func profile_for_peer(peer_id: int) -> PlayerProfile:
	var session := get_session(peer_id)
	return profiles.get(session.user_id) as PlayerProfile if session != null else null


func profile_snapshot_for_peer(peer_id: int) -> Dictionary:
	var profile := profile_for_peer(peer_id)
	return profile.client_snapshot() if profile != null else {}


func gameplay_profile_for_peer(peer_id: int) -> Dictionary:
	var profile := profile_for_peer(peer_id)
	if profile == null:
		return {}
	return {
		"loadout": profile.loadout.duplicate(true),
		"spell_pages": profile.spell_pages.duplicate(true),
		"selected_character_id": profile.selected_character_id,
		"skills": profile.skills.duplicate(true),
		"stash": profile.stash.duplicate(true),
		"currency": profile.currency,
		"visited_regions": ["neutral_frontier"]
	}


func apply_lobby_action(peer_id: int, action: String, payload: Dictionary) -> Dictionary:
	var profile := profile_for_peer(peer_id)
	if profile == null:
		return {"ok":false, "reason":"profile_not_loaded"}
	var before := profile.to_dictionary()
	var changed := false
	match action:
		"select_character": changed = _select_character(profile, str(payload.get("character_id", "")))
		"equip_auto": changed = _equip_auto(profile, str(payload.get("item_id", "")))
		"equip_slot": changed = _equip_slot(profile, str(payload.get("item_id", "")), str(payload.get("slot", "")))
		"unequip": changed = _unequip(profile, str(payload.get("slot", "")))
		"install_spell": changed = _install_spell(profile, int(payload.get("page_index", -1)), str(payload.get("item_id", "")))
		"install_modifier": changed = _install_modifier(profile, int(payload.get("page_index", -1)), str(payload.get("item_id", "")))
		"remove_modifier": changed = _remove_modifier(profile, int(payload.get("page_index", -1)), int(payload.get("modifier_index", -1)))
		"sell": changed = _sell_item(profile, str(payload.get("item_id", "")))
		"buy": changed = _buy_item(profile, str(payload.get("item_id", "")))
		"buy_package": changed = _buy_package(profile, str(payload.get("package_id", "")))
		"craft": changed = _craft(profile, str(payload.get("recipe_id", "")))
		"upgrade": changed = _purchase_upgrade(profile, str(payload.get("upgrade_id", "")))
		"purchase_skill": changed = _purchase_skill(profile, str(payload.get("skill_id", "")))
		"accept_quest": changed = _accept_quest(profile, str(payload.get("quest_id", "")))
		"claim_quest": changed = _claim_quest(profile, str(payload.get("quest_id", "")))
		_: return {"ok":false, "reason":"unknown_action"}
	if not changed:
		return {"ok":false, "reason":"requirements_not_met", "snapshot":profile.client_snapshot()}
	if not save_player_profile(profile.user_id):
		profiles[profile.user_id] = PlayerProfile.from_dictionary(before, profile.user_id)
		return {"ok":false, "reason":"save_failed", "snapshot":profile_snapshot_for_peer(peer_id)}
	print("[PROFILE] lobby action peer=%d user_id=%s action=%s" % [peer_id, profile.user_id, action])
	return {
		"ok":true,
		"snapshot":profile.client_snapshot(),
		"gameplay_profile":gameplay_profile_for_peer(peer_id)
	}


func _select_character(profile: PlayerProfile, character_id: String) -> bool:
	if not ContentRegistry.characters().has(character_id):
		return false
	profile.selected_character_id = character_id
	return true


func _equip_auto(profile: PlayerProfile, item_id: String) -> bool:
	var category := str(ItemDB.get_item(item_id).get("category", ""))
	var slot := ""
	match category:
		"spellbook": slot = "spellbook"
		"focus": slot = "focus"
		"dagger", "melee": slot = "dagger"
		"armor_head": slot = "head"
		"armor_chest", "armor": slot = "chest"
		"accessory": slot = "accessory_1" if str(profile.loadout.get("accessory_1", "")).is_empty() else "accessory_2"
		"backpack": slot = "backpack"
		"medical", "mana_consumable", "food", "drink": slot = "consumable_1" if str(profile.loadout.get("consumable_1", "")).is_empty() else "consumable_2"
		_: return false
	return _equip_slot(profile, item_id, slot)


func _equip_slot(profile: PlayerProfile, item_id: String, slot: String) -> bool:
	var accepted := {
		"spellbook":["spellbook"], "focus":["focus"], "dagger":["dagger", "melee"],
		"head":["armor_head"], "chest":["armor_chest", "armor"],
		"accessory_1":["accessory"], "accessory_2":["accessory"], "backpack":["backpack"],
		"consumable_1":["medical", "mana_consumable", "food", "drink"],
		"consumable_2":["medical", "mana_consumable", "food", "drink"]
	}
	var category := str(ItemDB.get_item(item_id).get("category", ""))
	if category not in accepted.get(slot, []) or not _remove_item(profile.stash, item_id):
		return false
	_add_item(profile.stash, str(profile.loadout.get(slot, "")))
	profile.loadout[slot] = item_id
	return true


func _unequip(profile: PlayerProfile, slot: String) -> bool:
	if slot not in ["spellbook", "focus", "dagger", "head", "chest", "accessory_1", "accessory_2", "backpack", "consumable_1", "consumable_2"]:
		return false
	var item_id := str(profile.loadout.get(slot, ""))
	if item_id.is_empty():
		return false
	_add_item(profile.stash, item_id)
	profile.loadout[slot] = ""
	return true


func _install_spell(profile: PlayerProfile, page_index: int, item_id: String) -> bool:
	if page_index < 0 or page_index >= profile.spell_pages.size() or ItemDB.spell(item_id) == null or not _remove_item(profile.stash, item_id):
		return false
	var page: Dictionary = profile.spell_pages[page_index]
	_add_item(profile.stash, str(page.get("spell_item", "")))
	for modifier_id: Variant in page.get("modifiers", []):
		_add_item(profile.stash, str(modifier_id))
	profile.spell_pages[page_index] = {"spell_item":item_id, "modifiers":[]}
	return true


func _install_modifier(profile: PlayerProfile, page_index: int, item_id: String) -> bool:
	if page_index < 0 or page_index >= profile.spell_pages.size():
		return false
	var page: Dictionary = profile.spell_pages[page_index]
	var spell := ItemDB.spell(str(page.get("spell_item", "")))
	var modifier := ItemDB.modifier(item_id)
	var book := ItemDB.spellbook(str(profile.loadout.get("spellbook", "")))
	var installed: Array = page.get("modifiers", [])
	if modifier == null or not modifier.is_compatible(spell) or book == null or installed.size() >= book.maximum_modifiers_per_page or item_id in installed:
		return false
	if not _remove_item(profile.stash, item_id):
		return false
	installed.append(item_id)
	page["modifiers"] = installed
	profile.spell_pages[page_index] = page
	return true


func _remove_modifier(profile: PlayerProfile, page_index: int, modifier_index: int) -> bool:
	if page_index < 0 or page_index >= profile.spell_pages.size():
		return false
	var page: Dictionary = profile.spell_pages[page_index]
	var installed: Array = page.get("modifiers", [])
	if modifier_index < 0 or modifier_index >= installed.size():
		return false
	_add_item(profile.stash, str(installed[modifier_index]))
	installed.remove_at(modifier_index)
	page["modifiers"] = installed
	profile.spell_pages[page_index] = page
	return true


func _sell_item(profile: PlayerProfile, item_id: String) -> bool:
	var item := ItemDB.get_item(item_id)
	if item.is_empty() or not _remove_item(profile.stash, item_id):
		return false
	profile.currency += maxi(0, int(item.get("value", 0)))
	return true


func _buy_item(profile: PlayerProfile, item_id: String) -> bool:
	if not VENDOR_PRICES.has(item_id) or ItemDB.get_item(item_id).is_empty():
		return false
	var price := int(VENDOR_PRICES[item_id])
	var candidate := profile.stash.duplicate(true)
	_add_item(candidate, item_id)
	if profile.currency < price or GameState.inventory_slots(candidate) > _stash_capacity(profile):
		return false
	profile.currency -= price
	profile.stash = candidate
	return true


func _buy_package(profile: PlayerProfile, package_id: String) -> bool:
	var package := ContentRegistry.starter_packages().get(package_id) as StarterPackageData
	if package == null or profile.currency < package.currency_cost:
		return false
	var candidate := profile.stash.duplicate(true)
	for item_id: String in package.contents():
		_add_item(candidate, item_id, int(package.contents()[item_id]))
	if GameState.inventory_slots(candidate) > _stash_capacity(profile):
		return false
	profile.currency -= package.currency_cost
	profile.stash = candidate
	return true


func _craft(profile: PlayerProfile, recipe_id: String) -> bool:
	var recipe := ContentRegistry.recipes().get(recipe_id) as CraftingRecipeData
	if recipe == null or recipe.output_item == null or int(profile.base_upgrades.get("workbench", 1)) < recipe.required_workbench_level or profile.currency < recipe.currency_cost:
		return false
	for ingredient: CraftIngredientData in recipe.ingredients:
		if ingredient == null or ingredient.item == null or int(profile.stash.get(ingredient.item.item_id, 0)) < ingredient.quantity:
			return false
	var candidate := profile.stash.duplicate(true)
	for ingredient: CraftIngredientData in recipe.ingredients:
		_remove_item(candidate, ingredient.item.item_id, ingredient.quantity)
	_add_item(candidate, recipe.output_item.item_id, recipe.output_quantity)
	if GameState.inventory_slots(candidate) > _stash_capacity(profile):
		return false
	profile.stash = candidate
	profile.currency -= recipe.currency_cost
	return true


func _purchase_upgrade(profile: PlayerProfile, upgrade_id: String) -> bool:
	var upgrade := ContentRegistry.upgrades().get(upgrade_id) as BaseUpgradeData
	if upgrade == null:
		return false
	var level := int(profile.base_upgrades.get(upgrade_id, 1))
	var cost := upgrade.currency_cost_per_level * level
	var material_cost := upgrade.material_cost_per_level * level
	var material_id := upgrade.material_item.item_id if upgrade.material_item != null else "arcane_dust"
	if level >= upgrade.maximum_level or profile.currency < cost or int(profile.stash.get(material_id, 0)) < material_cost:
		return false
	profile.currency -= cost
	_remove_item(profile.stash, material_id, material_cost)
	profile.base_upgrades[upgrade_id] = level + 1
	return true


func _purchase_skill(profile: PlayerProfile, skill_id: String) -> bool:
	var skill := ContentRegistry.skills().get(skill_id) as SkillData
	var rank := int(profile.skills.get(skill_id, 0))
	if skill == null or profile.skill_points <= 0 or rank >= skill.maximum_rank:
		return false
	profile.skills[skill_id] = rank + 1
	profile.skill_points -= 1
	return true


func _accept_quest(profile: PlayerProfile, quest_id: String) -> bool:
	for quest: Dictionary in profile.quests:
		if str(quest.get("id", "")) == quest_id and str(quest.get("state", "")) == "available":
			quest["state"] = "active"
			return true
	return false


func _claim_quest(profile: PlayerProfile, quest_id: String) -> bool:
	for index: int in range(profile.quests.size()):
		var quest: Dictionary = profile.quests[index]
		if str(quest.get("id", "")) != quest_id or str(quest.get("state", "")) != "complete":
			continue
		quest["state"] = "claimed"
		profile.currency += int(quest.get("reward_currency", 0))
		_add_item(profile.stash, str(quest.get("reward_item", "")))
		profile.skill_points += int(quest.get("reward_skill_points", 1))
		if index + 1 < profile.quests.size() and str(profile.quests[index + 1].get("state", "")) == "locked":
			profile.quests[index + 1]["state"] = "available"
		return true
	return false


func _advance_quest(profile: PlayerProfile, kind: String, target: String, amount: int) -> void:
	for quest: Dictionary in profile.quests:
		if str(quest.get("state", "")) != "active" or str(quest.get("type", "")) != kind or str(quest.get("target", "")) != target:
			continue
		quest["progress"] = mini(int(quest.get("needed", 0)), int(quest.get("progress", 0)) + amount)
		if int(quest.get("progress", 0)) >= int(quest.get("needed", 0)):
			quest["state"] = "complete"


func _stash_capacity(profile: PlayerProfile) -> int:
	var storage_data := ContentRegistry.upgrades().get("storage") as BaseUpgradeData
	var per_level := int(storage_data.benefit_per_level) if storage_data != null else 20
	return 120 + (int(profile.base_upgrades.get("storage", 1)) - 1) * per_level


func apply_raid_result(peer_id: int, success: bool, authoritative_loadout: Dictionary, authoritative_pages: Array, raid_inventory: Dictionary, secure_inventory: Dictionary, raid_kills: Dictionary = {}) -> bool:
	var profile := profile_for_peer(peer_id)
	if profile == null:
		return false
	if success:
		profile.loadout = authoritative_loadout.duplicate(true)
		profile.spell_pages = authoritative_pages.duplicate(true)
		profile.skill_points += 1
		_advance_quest(profile, "extract", "success", 1)
		for source: Dictionary in [raid_inventory, secure_inventory]:
			for item_id: String in source:
				_add_item(profile.stash, item_id, int(source[item_id]))
				_advance_quest(profile, "item", item_id, int(source[item_id]))
	else:
		for item_id: String in secure_inventory:
			_add_item(profile.stash, item_id, int(secure_inventory[item_id]))
		var failed_loadout := authoritative_loadout.duplicate(true)
		for slot: String in ["spellbook", "focus", "dagger", "head", "chest", "accessory_1", "accessory_2", "backpack"]:
			failed_loadout[slot] = ""
		failed_loadout["spellbook"] = "apprentice_grimoire"
		failed_loadout["focus"] = "apprentice_wand"
		failed_loadout["dagger"] = "neutral_dagger"
		profile.loadout = failed_loadout
		profile.spell_pages = GameState.default_profile_data().get("spell_pages", []).duplicate(true)
	for enemy_type: String in raid_kills:
		_advance_quest(profile, "kill", enemy_type, int(raid_kills[enemy_type]))
	return save_player_profile(profile.user_id)


func give_currency(user_id: String, amount: int) -> bool:
	var profile := load_player_profile(user_id)
	if profile == null or amount <= 0:
		return false
	profile.currency += amount
	return save_player_profile(user_id)


func add_item(user_id: String, item_id: String, amount: int = 1) -> bool:
	var profile := load_player_profile(user_id)
	if profile == null or amount <= 0 or ItemDB.get_item(item_id).is_empty():
		return false
	_add_item(profile.stash, item_id, amount)
	return save_player_profile(user_id)


func learn_rune(user_id: String, rune_id: String) -> bool:
	var profile := load_player_profile(user_id)
	if profile == null or ItemDB.modifier(rune_id) == null:
		return false
	if rune_id not in profile.learned_runes:
		profile.learned_runes.append(rune_id)
	return save_player_profile(user_id)


func _add_item(items: Dictionary, item_id: String, amount: int = 1) -> void:
	if item_id.is_empty() or amount <= 0:
		return
	items[item_id] = int(items.get(item_id, 0)) + amount


func _remove_item(items: Dictionary, item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or int(items.get(item_id, 0)) < amount:
		return false
	items[item_id] = int(items[item_id]) - amount
	if int(items[item_id]) <= 0:
		items.erase(item_id)
	return true
