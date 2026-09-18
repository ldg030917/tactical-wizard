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

	var tampered_result: Dictionary = restarted_service.apply_lobby_action(202, "equip_slot", {"item_id":"not_owned_item", "slot":"spellbook"})
	_expect(not bool(tampered_result.get("ok", false)), "server accepted a client-selected unowned item")
	var sold_before := int(restored.stash.get("health_potion", 0))
	var currency_before := restored.currency
	var sale_result: Dictionary = restarted_service.apply_lobby_action(202, "sell", {"item_id":"health_potion"})
	_expect(bool(sale_result.get("ok", false)), "server-authoritative lobby sale failed")
	_expect(int(restored.stash.get("health_potion", 0)) == sold_before - 1, "sale did not remove the sold item")
	_expect(restored.currency == currency_before + int(ItemDB.get_item("health_potion").get("value", 0)), "sale did not credit authoritative currency")
	var dust_before := int(restored.stash.get("arcane_dust", 0))
	var buy_currency_before := restored.currency
	var buy_result: Dictionary = restarted_service.apply_lobby_action(202, "buy", {"item_id":"arcane_dust", "price":1})
	_expect(bool(buy_result.get("ok", false)), "server-authoritative vendor purchase failed")
	_expect(int(restored.stash.get("arcane_dust", 0)) == dust_before + 1, "vendor purchase did not add the item")
	_expect(restored.currency == buy_currency_before - int(restarted_service.VENDOR_PRICES["arcane_dust"]), "server trusted a client-provided vendor price")
	var equip_result: Dictionary = restarted_service.apply_lobby_action(202, "equip_slot", {"item_id":"novice_hood", "slot":"head"})
	_expect(bool(equip_result.get("ok", false)) and restored.loadout.get("head", "") == "novice_hood", "server-authoritative equipment change failed")
	_expect(bool(restarted_service.apply_lobby_action(202, "unequip", {"slot":"head"}).get("ok", false)), "server-authoritative unequip failed")
	var accepted_quest_id := ""
	for quest: Dictionary in restored.quests:
		if str(quest.get("state", "")) == "available":
			accepted_quest_id = str(quest.get("id", ""))
			break
	_expect(not accepted_quest_id.is_empty() and bool(restarted_service.apply_lobby_action(202, "accept_quest", {"quest_id":accepted_quest_id}).get("ok", false)), "server-authoritative quest acceptance failed")
	restarted_service.remove_peer(202)
	restarted_service.remove_peer(303)
	var sale_reload_service: Variant = _new_service()
	_expect(bool(sale_reload_service.register_peer(606, USER_A).get("ok", false)), "sale profile reload failed")
	var sale_reloaded := sale_reload_service.profile_for_peer(606) as PlayerProfile
	_expect(sale_reloaded != null and sale_reloaded.currency == restored.currency, "lobby sale currency did not persist")
	_expect(sale_reloaded != null and int(sale_reloaded.stash.get("health_potion", 0)) == sold_before - 1, "lobby sale inventory did not persist")
	_expect(sale_reloaded != null and sale_reloaded.loadout.get("head", "") == "", "lobby equipment changes did not persist")
	if sale_reloaded != null and not accepted_quest_id.is_empty():
		var persisted_quest_state := ""
		for quest: Dictionary in sale_reloaded.quests:
			if str(quest.get("id", "")) == accepted_quest_id:
				persisted_quest_state = str(quest.get("state", ""))
				break
		_expect(persisted_quest_state == "active", "lobby quest acceptance did not persist")
	sale_reload_service.remove_peer(606)


func _new_service() -> Variant:
	var service: Variant = load("res://scripts/multiplayer/player_profile_service.gd").new()
	service.storage = PlayerProfileStorage.new(test_profile_directory)
	return service


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
