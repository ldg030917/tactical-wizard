class_name PlayerProfile
extends RefCounted

## Server-authoritative persistent data. Raid HP, position, velocity, effects,
## temporary raid inventory and combat state deliberately do not live here.

const SCHEMA_VERSION := 1

var user_id: String = ""
var display_name: String = "Player"
var currency: int = 0
var stash: Dictionary = {}
var loadout: Dictionary = {}
var learned_runes: Array = []

# Existing persistent prototype progression retained during the migration.
var spell_pages: Array = []
var attachments: Dictionary = {}
var base_upgrades: Dictionary = {}
var skills: Dictionary = {}
var skill_points: int = 0
var quests: Array = []
var selected_character_id: String = "mana_specialist"
var spell_catalog_version: int = 0


static func create_default(persistent_user_id: String, defaults: Dictionary) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.user_id = persistent_user_id
	profile.display_name = "Player-%s" % persistent_user_id.left(8)
	profile._apply_persistent_data(defaults)
	return profile


static func from_dictionary(data: Dictionary, expected_user_id: String) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.user_id = expected_user_id
	profile.display_name = str(data.get("display_name", "Player-%s" % expected_user_id.left(8))).strip_edges().left(32)
	if profile.display_name.is_empty():
		profile.display_name = "Player-%s" % expected_user_id.left(8)
	profile.learned_runes = data.get("learned_runes", []).duplicate(true) if data.get("learned_runes", []) is Array else []
	profile._apply_persistent_data(data)
	return profile


func _apply_persistent_data(data: Dictionary) -> void:
	currency = maxi(0, int(data.get("currency", currency)))
	stash = data.get("stash", {}).duplicate(true) if data.get("stash", {}) is Dictionary else {}
	loadout = data.get("loadout", {}).duplicate(true) if data.get("loadout", {}) is Dictionary else {}
	spell_pages = data.get("spell_pages", []).duplicate(true) if data.get("spell_pages", []) is Array else []
	attachments = data.get("attachments", {}).duplicate(true) if data.get("attachments", {}) is Dictionary else {}
	base_upgrades = data.get("base_upgrades", {}).duplicate(true) if data.get("base_upgrades", {}) is Dictionary else {}
	skills = data.get("skills", {}).duplicate(true) if data.get("skills", {}) is Dictionary else {}
	skill_points = maxi(0, int(data.get("skill_points", skill_points)))
	quests = data.get("quests", []).duplicate(true) if data.get("quests", []) is Array else []
	selected_character_id = str(data.get("selected_character_id", selected_character_id))
	spell_catalog_version = maxi(0, int(data.get("spell_catalog_version", spell_catalog_version)))


func to_dictionary() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"user_id": user_id,
		"display_name": display_name,
		"currency": currency,
		"stash": stash.duplicate(true),
		"loadout": loadout.duplicate(true),
		"learned_runes": learned_runes.duplicate(true),
		"spell_pages": spell_pages.duplicate(true),
		"attachments": attachments.duplicate(true),
		"base_upgrades": base_upgrades.duplicate(true),
		"skills": skills.duplicate(true),
		"skill_points": skill_points,
		"quests": quests.duplicate(true),
		"selected_character_id": selected_character_id,
		"spell_catalog_version": spell_catalog_version
	}


func client_snapshot() -> Dictionary:
	# A detached value snapshot prevents clients from ever receiving the server's
	# in-memory PlayerProfile object itself.
	return to_dictionary()
