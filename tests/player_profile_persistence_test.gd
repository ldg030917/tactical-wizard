extends Node

const USER_A := "11111111-1111-4111-8111-111111111111"
const USER_B := "22222222-2222-4222-8222-222222222222"
const IDENTITY_TEST_PATH := "user://player_identity_test.json"

var failures: Array[String] = []
var test_profile_directory: String


func _ready() -> void:
	test_profile_directory = "user://player_profile_tests/run_%d" % Time.get_ticks_usec()
	_test_identity_persistence()
	_test_profile_persistence_and_session_mapping()
	if failures.is_empty():
		print("[TEST] player identity/profile persistence PASS")
		await get_tree().create_timer(2.0).timeout
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("[TEST] %s" % failure)
	await get_tree().create_timer(2.0).timeout
	get_tree().quit(1)


func _test_identity_persistence() -> void:
	var first := PlayerIdentity.load_or_create_identity(IDENTITY_TEST_PATH)
	var second := PlayerIdentity.load_or_create_identity(IDENTITY_TEST_PATH)
	_expect(PlayerProfileStorage._is_safe_uuid(first), "generated identity is not a valid UUID")
	_expect(first == second, "identity changed between consecutive loads")


func _test_profile_persistence_and_session_mapping() -> void:
	var first_service: Variant = _new_service()
	var first_registration: Dictionary = first_service.register_peer(101, USER_A)
	_expect(bool(first_registration.get("ok", false)), "first user registration failed")
	var profile := first_service.profile_for_peer(101) as PlayerProfile
	_expect(profile != null, "registered peer has no profile")
	if profile == null:
		return
	profile.currency = 987
	profile.learned_runes = ["mod_ricochet_rune"]
	_expect(first_service.save_player_profile(USER_A), "profile save failed")
	first_service.remove_peer(101)

	# A new service instance represents a server restart: memory is empty and the
	# profile must be recovered from the JSON storage boundary.
	var restarted_service: Variant = _new_service()
	var restored_registration: Dictionary = restarted_service.register_peer(202, USER_A)
	_expect(bool(restored_registration.get("ok", false)), "registration after simulated restart failed")
	var restored := restarted_service.profile_for_peer(202) as PlayerProfile
	_expect(restored != null and restored.currency == 987, "currency did not survive server restart")
	_expect(restored != null and "mod_ricochet_rune" in restored.learned_runes, "learned runes did not survive server restart")
	_expect(restarted_service.get_session(202).user_id == USER_A, "peer to user mapping is incorrect")

	var second_registration: Dictionary = restarted_service.register_peer(303, USER_B)
	_expect(bool(second_registration.get("ok", false)), "independent second user registration failed")
	_expect(restarted_service.profile_for_peer(303) != restored, "different users share a profile object")
	var duplicate_registration: Dictionary = restarted_service.register_peer(404, USER_A)
	_expect(not bool(duplicate_registration.get("ok", false)) and duplicate_registration.get("reason") == "user_already_connected", "duplicate user_id was not rejected")
	var invalid: Dictionary = restarted_service.register_peer(505, "../unsafe")
	_expect(not bool(invalid.get("ok", false)), "unsafe user_id was accepted")

	var tampered_selection := {
		"loadout": {"spellbook":"not_owned_item"},
		"spell_pages": restored.spell_pages.duplicate(true),
		"selected_character_id": restored.selected_character_id
	}
	var tampered_result: Dictionary = restarted_service.apply_loadout_selection(202, tampered_selection)
	_expect(not bool(tampered_result.get("ok", false)), "server accepted a client-selected unowned item")
	restarted_service.remove_peer(202)
	restarted_service.remove_peer(303)


func _new_service() -> Variant:
	var service: Variant = load("res://scripts/multiplayer/player_profile_service.gd").new()
	service.storage = PlayerProfileStorage.new(test_profile_directory)
	return service


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
