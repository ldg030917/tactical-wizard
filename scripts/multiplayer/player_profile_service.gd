extends Node

## Server-owned identity/session/profile boundary. Network code asks this service
## for profiles; only PlayerProfileStorage knows that persistence is currently JSON.

var sessions_by_peer: Dictionary = {}
var peer_by_user_id: Dictionary = {}
var profiles: Dictionary = {}
var storage: PlayerProfileStorage


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


func apply_loadout_selection(peer_id: int, selection: Dictionary) -> Dictionary:
	var profile := profile_for_peer(peer_id)
	if profile == null:
		return {"ok": false, "reason": "profile_not_loaded"}
	var requested_loadout: Dictionary = selection.get("loadout", {}).duplicate(true)
	var requested_pages: Array = selection.get("spell_pages", []).duplicate(true)
	var owned := _owned_item_pool(profile)
	var required: Dictionary = {}
	for item_id: Variant in requested_loadout.values():
		_add_item(required, str(item_id))
	for page: Dictionary in requested_pages:
		_add_item(required, str(page.get("spell_item", "")))
		for modifier_id: Variant in page.get("modifiers", []):
			_add_item(required, str(modifier_id))
	for item_id: String in required:
		if int(required[item_id]) > int(owned.get(item_id, 0)):
			return {"ok": false, "reason": "item_not_owned", "item_id": item_id}
	var updated_stash := owned.duplicate(true)
	for item_id: String in required:
		updated_stash[item_id] = int(updated_stash.get(item_id, 0)) - int(required[item_id])
		if int(updated_stash[item_id]) <= 0:
			updated_stash.erase(item_id)
	profile.stash = updated_stash
	profile.loadout = requested_loadout
	profile.spell_pages = requested_pages
	profile.selected_character_id = str(selection.get("selected_character_id", profile.selected_character_id))
	if not save_player_profile(profile.user_id):
		return {"ok": false, "reason": "save_failed"}
	return {"ok": true, "snapshot": profile.client_snapshot(), "gameplay_profile": gameplay_profile_for_peer(peer_id)}


func apply_raid_result(peer_id: int, success: bool, authoritative_loadout: Dictionary, authoritative_pages: Array, raid_inventory: Dictionary, secure_inventory: Dictionary) -> bool:
	var profile := profile_for_peer(peer_id)
	if profile == null:
		return false
	if success:
		profile.loadout = authoritative_loadout.duplicate(true)
		profile.spell_pages = authoritative_pages.duplicate(true)
		profile.skill_points += 1
		for source: Dictionary in [raid_inventory, secure_inventory]:
			for item_id: String in source:
				_add_item(profile.stash, item_id, int(source[item_id]))
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


func _owned_item_pool(profile: PlayerProfile) -> Dictionary:
	var owned := profile.stash.duplicate(true)
	for item_id: Variant in profile.loadout.values():
		_add_item(owned, str(item_id))
	for page: Dictionary in profile.spell_pages:
		_add_item(owned, str(page.get("spell_item", "")))
		for modifier_id: Variant in page.get("modifiers", []):
			_add_item(owned, str(modifier_id))
	return owned


func _add_item(items: Dictionary, item_id: String, amount: int = 1) -> void:
	if item_id.is_empty() or amount <= 0:
		return
	items[item_id] = int(items.get(item_id, 0)) + amount
