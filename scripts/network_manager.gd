extends Node

## Owns ENet connection state and RPC routing. MatchmakingManager owns queue
## batching; SessionManager owns the logical RaidSession lifecycle.
signal connection_status_changed(message: String)
signal session_state_changed(state: String)
signal matchmaking_status_changed(message: String)
signal client_connected
signal client_connection_failed(message: String)
signal server_started
signal ping_updated(milliseconds: int)
signal raid_session_world_requested(session_id: String)
signal load_raid_requested(session_id: String)
signal raid_session_clients_ready(session_id: String, members: Array[int])
signal raid_extraction_requested(peer_id: int, extraction_name: String, session_id: String)
signal raid_completed(success: bool, result: Dictionary)
signal raid_region_world_requested(session_id: String, region_id: String)
signal load_raid_region_requested(session_id: String, region_id: String)
signal raid_region_clients_ready(session_id: String, members: Array[int])

const DEFAULT_PORT := 7000
const DEFAULT_SERVER_ADDRESS := "158.180.84.54"
const MAX_CLIENTS := 32
const PING_INTERVAL_SECONDS := 1.0

enum PeerRaidState { MULTIPLAYER_LOBBY, MATCHMAKING, MATCHED_WAITING_WORLD, LOADING_RAID, IN_RAID, RETURNING_TO_LOBBY, DISCONNECTED, IDENTITY_PENDING }

var is_server_mode := false
var is_connecting := false
var ping_ms := -1
var _ping_elapsed := 0.0
var connected_peer_ids: Dictionary = {}
var peer_raid_states: Dictionary = {}
## Server-owned lobby selections. RaidScene reads this only on the server when
## constructing a Player for a peer; cast RPCs never carry a spell identifier.
var peer_loadouts: Dictionary = {}
var client_raid_session_id := ""
var _region_transitions: Dictionary = {}


func _ready() -> void:
	var launch_args := PackedStringArray()
	launch_args.append_array(OS.get_cmdline_user_args())
	launch_args.append_array(OS.get_cmdline_args())
	is_server_mode = "--server" in launch_args
	if is_server_mode:
		print("[SERVER] boot build=session-boundary-v1 args=%s" % str(launch_args))
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	if is_server_mode:
		MatchmakingManager.match_ready.connect(_on_match_ready)
		MatchmakingManager.queue_changed.connect(_on_matchmaking_queue_changed)
		SessionManager.world_requested.connect(_on_session_world_requested)
		SessionManager.members_loaded.connect(_on_session_members_loaded)
	if is_server_mode:
		call_deferred("start_server")


func _process(delta: float) -> void:
	if is_server_mode or not is_connected_to_server():
		return
	_ping_elapsed += delta
	if _ping_elapsed >= PING_INTERVAL_SECONDS:
		_ping_elapsed = 0.0
		_ping_server.rpc_id(1, Time.get_ticks_msec())


func start_server(port: int = DEFAULT_PORT, max_clients: int = MAX_CLIENTS) -> Error:
	if not is_server_mode:
		return ERR_UNAUTHORIZED
	_stop_current_peer()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, max_clients)
	if error != OK:
		var failure := "Server start failed (port %d): %s" % [port, error_string(error)]
		print(failure)
		connection_status_changed.emit(failure)
		return error
	multiplayer.multiplayer_peer = peer
	print("[SERVER] multiplayer peer created")
	print("[SERVER] listening udp=%d" % port)
	connection_status_changed.emit("Dedicated server listening on UDP port %d" % port)
	session_state_changed.emit("SERVER")
	server_started.emit()
	return OK


func connect_to_default_server() -> Error:
	return connect_to_server(DEFAULT_SERVER_ADDRESS)


func connect_to_server(address: String = DEFAULT_SERVER_ADDRESS, port: int = DEFAULT_PORT) -> Error:
	if is_server_mode:
		return ERR_UNAUTHORIZED
	var host := address.strip_edges()
	if host.is_empty():
		return _report_connect_setup_failure("Server IP address is required.", ERR_INVALID_PARAMETER)
	_stop_current_peer()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(host, port)
	if error != OK:
		return _report_connect_setup_failure("Connection setup failed: %s" % error_string(error), error)
	multiplayer.multiplayer_peer = peer
	is_connecting = true
	connection_status_changed.emit("Connecting to %s:%d..." % [host, port])
	session_state_changed.emit("CONNECTING")
	return OK


func is_connected_to_server() -> bool:
	var peer := multiplayer.multiplayer_peer
	return not is_server_mode and peer is ENetMultiplayerPeer and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_network_game() -> bool:
	return is_server_mode or is_connected_to_server()


func request_matchmaking() -> void:
	if is_connected_to_server():
		submit_local_loadout()
		_request_matchmaking.rpc_id(1)


func cancel_matchmaking() -> void:
	if is_connected_to_server():
		_cancel_matchmaking.rpc_id(1)


func request_test_raid() -> void:
	if is_connected_to_server():
		submit_local_loadout()
		_request_test_raid.rpc_id(1)


func submit_local_loadout() -> void:
	if not is_connected_to_server():
		return
	var loadout := GameState.loadout.duplicate(true)
	if str(loadout.get("spellbook", "")).is_empty():
		loadout["spellbook"] = "apprentice_grimoire"
	if str(loadout.get("focus", "")).is_empty():
		loadout["focus"] = "apprentice_wand"
	if str(loadout.get("dagger", "")).is_empty():
		loadout["dagger"] = "neutral_dagger"
	_submit_loadout.rpc_id(1, {
		"loadout": loadout,
		"spell_pages": GameState.spell_pages.duplicate(true),
		"selected_character_id": GameState.selected_character_id
	})


func get_peer_loadout(peer_id: int) -> Dictionary:
	return peer_loadouts.get(peer_id, {}).duplicate(true)


func update_peer_profile(peer_id: int, profile: Dictionary) -> void:
	if multiplayer.is_server() and connected_peer_ids.has(peer_id):
		peer_loadouts[peer_id] = profile.duplicate(true)


func server_sync_client_profile(peer_id: int, raid_inventory: Dictionary) -> void:
	if not multiplayer.is_server() or not PlayerProfileService.has_session(peer_id):
		return
	_sync_client_profile.rpc_id(peer_id, PlayerProfileService.profile_snapshot_for_peer(peer_id), raid_inventory)


func server_apply_raid_result(peer_id: int, success: bool, authoritative_loadout: Dictionary, authoritative_pages: Array, raid_inventory: Dictionary, secure_inventory: Dictionary) -> bool:
	if not multiplayer.is_server() or not PlayerProfileService.has_session(peer_id):
		return false
	return PlayerProfileService.apply_raid_result(peer_id, success, authoritative_loadout, authoritative_pages, raid_inventory, secure_inventory)


func is_region_transitioning(session_id: String) -> bool:
	return _region_transitions.has(session_id)


## Compatibility entry point for existing deployment station interactions.
func request_raid_start() -> void:
	request_matchmaking()


func client_raid_scene_ready(session_id: String) -> void:
	if is_connected_to_server() and session_id == client_raid_session_id:
		_client_raid_loaded.rpc_id(1, session_id)


func request_raid_extraction(extraction_name: String) -> void:
	if is_connected_to_server():
		_request_raid_extraction.rpc_id(1, extraction_name)


func server_begin_region_transition(session_id: String, region_id: String) -> bool:
	if not multiplayer.is_server() or _region_transitions.has(session_id):
		return false
	var members := get_session_members(session_id)
	if members.is_empty():
		return false
	_region_transitions[session_id] = {"region_id":region_id, "loaded":{}}
	raid_region_world_requested.emit(session_id, region_id)
	for peer_id: int in members:
		_load_raid_region_on_clients.rpc_id(peer_id, session_id, region_id)
	return true


func client_raid_region_ready(session_id: String, region_id: String) -> void:
	if is_connected_to_server() and session_id == client_raid_session_id:
		_client_raid_region_loaded.rpc_id(1, session_id, region_id)


func get_session_members(session_id: String) -> Array[int]:
	return SessionManager.get_session_members(session_id)


func get_peer_session_id(peer_id: int) -> String:
	return SessionManager.get_player_session(peer_id)


func server_complete_raid_extraction(peer_id: int, success: bool = true, result: Dictionary = {}) -> void:
	if not multiplayer.is_server():
		return
	var session_id := get_peer_session_id(peer_id)
	if session_id.is_empty():
		return
	print("[RAID %s] completed peer=%d success=%s" % [session_id, peer_id, str(success)])
	SessionManager.remove_player(peer_id, "extracted")
	PlayerProfileService.set_raid_session(peer_id, "")
	peer_raid_states[peer_id] = PeerRaidState.RETURNING_TO_LOBBY
	var authoritative_result := result.duplicate(true)
	authoritative_result["profile_snapshot"] = PlayerProfileService.profile_snapshot_for_peer(peer_id)
	_raid_completed_on_client.rpc_id(peer_id, success, authoritative_result)
	peer_raid_states[peer_id] = PeerRaidState.MULTIPLAYER_LOBBY


func _queue_peer(peer_id: int) -> void:
	if not connected_peer_ids.has(peer_id) or not PlayerProfileService.has_session(peer_id) or int(peer_raid_states.get(peer_id, PeerRaidState.DISCONNECTED)) != PeerRaidState.MULTIPLAYER_LOBBY:
		return
	if not peer_loadouts.has(peer_id):
		_send_matchmaking_status(peer_id, "LOADOUT SYNCING")
		return
	if MatchmakingManager.contains(peer_id):
		_send_matchmaking_status(peer_id, "MATCHMAKING  %d / %d" % [MatchmakingManager.size(), MatchmakingManager.MAX_MATCH_PLAYERS])
		return
	peer_raid_states[peer_id] = PeerRaidState.MATCHMAKING
	MatchmakingManager.enqueue(peer_id)


func _cancel_queued_peer(peer_id: int, reason: String = "cancelled") -> void:
	if not MatchmakingManager.remove(peer_id, reason):
		return
	if connected_peer_ids.has(peer_id):
		peer_raid_states[peer_id] = PeerRaidState.MULTIPLAYER_LOBBY
		_send_matchmaking_status(peer_id, "LOBBY")


func _create_raid_session(requested_members: Array[int], is_test_session: bool) -> void:
	var members: Array[int] = []
	for peer_id: int in requested_members:
		if connected_peer_ids.has(peer_id) and get_peer_session_id(peer_id).is_empty():
			members.append(peer_id)
	if members.is_empty() or (not is_test_session and members.size() < MatchmakingManager.MIN_MATCH_PLAYERS):
		for peer_id: int in members:
			peer_raid_states[peer_id] = PeerRaidState.MULTIPLAYER_LOBBY
			_queue_peer(peer_id)
		return
	var session_id := SessionManager.create_session(members, is_test_session)
	if session_id.is_empty():
		return
	var session := SessionManager.get_session(session_id)
	var starts_now := int(session.get("state", SessionManager.State.CLOSED)) == SessionManager.State.PREPARING_WORLD
	for peer_id: int in members:
		PlayerProfileService.set_raid_session(peer_id, session_id)
		peer_raid_states[peer_id] = PeerRaidState.LOADING_RAID if starts_now else PeerRaidState.MATCHED_WAITING_WORLD
		_send_matchmaking_status(peer_id, "MATCH FOUND  %d Players" % members.size())
	if starts_now:
		SessionManager.activate_session(session_id)


func server_begin_session_loading(session_id: String) -> void:
	if not multiplayer.is_server() or not SessionManager.begin_loading(session_id):
		return
	for peer_id: int in get_session_members(session_id):
		if connected_peer_ids.has(peer_id):
			peer_raid_states[peer_id] = PeerRaidState.LOADING_RAID
			print("[RAID %s] sending load peer=%d" % [session_id, peer_id])
			_load_raid_on_clients.rpc_id(peer_id, session_id)
		else:
			SessionManager.remove_player(peer_id, "disconnected_before_load")


func _on_match_ready(members: Array[int]) -> void:
	_create_raid_session(members, false)


func _on_matchmaking_queue_changed(queue: Array[int]) -> void:
	for peer_id: int in queue:
		if connected_peer_ids.has(peer_id):
			_send_matchmaking_status(peer_id, "MATCHMAKING  %d / %d" % [queue.size(), MatchmakingManager.MAX_MATCH_PLAYERS])


func _on_session_world_requested(session_id: String) -> void:
	for peer_id: int in get_session_members(session_id):
		peer_raid_states[peer_id] = PeerRaidState.LOADING_RAID
	raid_session_world_requested.emit(session_id)


func _on_session_members_loaded(session_id: String, members: Array[int]) -> void:
	for peer_id: int in members:
		peer_raid_states[peer_id] = PeerRaidState.IN_RAID
	print("[RAID %s] all members loaded; spawning players" % session_id)
	raid_session_clients_ready.emit(session_id, members)


func _send_matchmaking_status(peer_id: int, text: String) -> void:
	if multiplayer.is_server() and connected_peer_ids.has(peer_id):
		_matchmaking_status.rpc_id(peer_id, text)


func _report_connect_setup_failure(message: String, error: Error) -> Error:
	print(message)
	connection_status_changed.emit(message)
	session_state_changed.emit("OFFLINE")
	client_connection_failed.emit(message)
	return error


func _stop_current_peer() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	is_connecting = false
	ping_ms = -1
	_ping_elapsed = 0.0


func _on_peer_connected(peer_id: int) -> void:
	if is_server_mode:
		connected_peer_ids[peer_id] = true
		peer_raid_states[peer_id] = PeerRaidState.IDENTITY_PENDING
		print("[IDENTITY] awaiting user_id peer=%d" % peer_id)
		print("[NETWORK] peer_connected=%d peers=%s" % [peer_id, str(connected_peer_ids.keys())])


func _on_peer_disconnected(peer_id: int) -> void:
	if not is_server_mode:
		return
	var session_id := get_peer_session_id(peer_id)
	_cancel_queued_peer(peer_id, "disconnected")
	PlayerProfileService.remove_peer(peer_id)
	connected_peer_ids.erase(peer_id)
	peer_loadouts.erase(peer_id)
	if not session_id.is_empty():
		print("[RAID %s] disconnected peer=%d" % [session_id, peer_id])
		SessionManager.remove_player(peer_id, "disconnected")
		_try_finish_region_transition(session_id)
	peer_raid_states.erase(peer_id)
	print("[NETWORK] peer_disconnected=%d peers=%s" % [peer_id, str(connected_peer_ids.keys())])


func _on_connected_to_server() -> void:
	is_connecting = false
	connection_status_changed.emit("Connected. Registering development identity...")
	session_state_changed.emit("IDENTIFYING")
	_submit_identity.rpc_id(1, PlayerIdentity.user_id)


func _on_connection_failed() -> void:
	is_connecting = false
	var message := "Connection failed. Check server IP, UDP port, and firewall."
	connection_status_changed.emit(message)
	session_state_changed.emit("OFFLINE")
	client_connection_failed.emit(message)
	_stop_current_peer()


func _on_server_disconnected() -> void:
	is_connecting = false
	connection_status_changed.emit("Disconnected from server.")
	session_state_changed.emit("OFFLINE")
	_stop_current_peer()


@rpc("any_peer", "call_remote", "reliable")
func _submit_identity(user_id: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not connected_peer_ids.has(peer_id) or int(peer_raid_states.get(peer_id, -1)) != PeerRaidState.IDENTITY_PENDING:
		return
	var registration: Dictionary = PlayerProfileService.register_peer(peer_id, user_id)
	if not bool(registration.get("ok", false)):
		var reason := str(registration.get("reason", "identity_rejected"))
		print("[IDENTITY] rejected peer=%d reason=%s" % [peer_id, reason])
		_identity_rejected.rpc_id(peer_id, reason)
		return
	peer_raid_states[peer_id] = PeerRaidState.MULTIPLAYER_LOBBY
	peer_loadouts[peer_id] = PlayerProfileService.gameplay_profile_for_peer(peer_id)
	print("[IDENTITY] accepted peer=%d user_id=%s" % [peer_id, user_id])
	_identity_accepted.rpc_id(peer_id, PlayerProfileService.profile_snapshot_for_peer(peer_id))


@rpc("authority", "call_remote", "reliable")
func _identity_accepted(profile_snapshot: Dictionary) -> void:
	if not is_connected_to_server():
		return
	GameState.apply_server_profile_snapshot(profile_snapshot)
	connection_status_changed.emit("Connected to server.")
	session_state_changed.emit("ONLINE")
	submit_local_loadout()
	client_connected.emit()


@rpc("authority", "call_remote", "reliable")
func _identity_rejected(reason: String) -> void:
	if not is_connected_to_server():
		return
	var message := "Identity rejected by server: %s" % reason
	connection_status_changed.emit(message)
	session_state_changed.emit("OFFLINE")
	client_connection_failed.emit(message)
	_stop_current_peer()


@rpc("any_peer", "call_remote", "reliable")
func _request_matchmaking() -> void:
	if multiplayer.is_server():
		var peer_id := multiplayer.get_remote_sender_id()
		if PlayerProfileService.has_session(peer_id):
			_queue_peer(peer_id)


@rpc("any_peer", "call_remote", "reliable")
func _submit_loadout(snapshot: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not connected_peer_ids.has(peer_id) or not PlayerProfileService.has_session(peer_id):
		return
	var normalized := _normalize_loadout_snapshot(snapshot)
	if normalized.is_empty():
		print("[LOADOUT] rejected peer=%d" % peer_id)
		return
	var result: Dictionary = PlayerProfileService.apply_loadout_selection(peer_id, normalized)
	if not bool(result.get("ok", false)):
		print("[LOADOUT] rejected peer=%d reason=%s item=%s" % [peer_id, str(result.get("reason", "unknown")), str(result.get("item_id", ""))])
		_sync_client_profile.rpc_id(peer_id, PlayerProfileService.profile_snapshot_for_peer(peer_id), {})
		return
	var previous_regions: Array = peer_loadouts.get(peer_id, {}).get("visited_regions", ["neutral_frontier"]).duplicate()
	peer_loadouts[peer_id] = result.get("gameplay_profile", {}).duplicate(true)
	peer_loadouts[peer_id]["visited_regions"] = previous_regions
	_sync_client_profile.rpc_id(peer_id, result.get("snapshot", {}), {})
	print("[LOADOUT] accepted peer=%d pages=%s source=server_profile" % [peer_id, str(normalized.spell_pages)])


func _normalize_loadout_snapshot(snapshot: Dictionary) -> Dictionary:
	var raw_loadout: Variant = snapshot.get("loadout", {})
	var raw_pages: Variant = snapshot.get("spell_pages", [])
	if not raw_loadout is Dictionary or not raw_pages is Array or raw_pages.size() != 3:
		return {}
	var accepted_categories := {
		"spellbook":["spellbook"], "focus":["focus"], "dagger":["dagger", "melee"],
		"head":["armor_head"], "chest":["armor_chest", "armor"],
		"accessory_1":["accessory"], "accessory_2":["accessory"], "backpack":["backpack"],
		"consumable_1":["medical", "mana_consumable"], "consumable_2":["medical", "mana_consumable"]
	}
	var loadout: Dictionary = {}
	for slot: String in accepted_categories:
		var selected_item := str((raw_loadout as Dictionary).get(slot, ""))
		if not selected_item.is_empty():
			var item_info := ItemDB.get_item(selected_item)
			if item_info.is_empty() or str(item_info.get("category", "")) not in accepted_categories[slot]:
				return {}
		loadout[slot] = selected_item
	var pages: Array = []
	var book := ItemDB.spellbook(str(loadout.get("spellbook", "")))
	for raw_page: Variant in raw_pages:
		if not raw_page is Dictionary:
			return {}
		var page: Dictionary = raw_page
		var spell_id := str(page.get("spell_item", ""))
		var spell := ItemDB.spell(spell_id)
		if spell == null:
			return {}
		var modifiers: Array = []
		for raw_modifier: Variant in page.get("modifiers", []):
			var modifier_id := str(raw_modifier)
			var modifier := ItemDB.modifier(modifier_id)
			if modifier == null or not modifier.is_compatible(spell):
				return {}
			modifiers.append(modifier_id)
		if book == null or modifiers.size() > book.maximum_modifiers_per_page:
			return {}
		pages.append({"spell_item": spell_id, "modifiers": modifiers})
	var character_id := str(snapshot.get("selected_character_id", "mana_specialist"))
	if not ContentRegistry.characters().has(character_id):
		return {}
	return {
		"loadout": loadout, "spell_pages": pages, "selected_character_id": character_id
	}


@rpc("any_peer", "call_remote", "reliable")
func _cancel_matchmaking() -> void:
	if multiplayer.is_server():
		var peer_id := multiplayer.get_remote_sender_id()
		if PlayerProfileService.has_session(peer_id):
			_cancel_queued_peer(peer_id)


@rpc("any_peer", "call_remote", "reliable")
func _request_test_raid() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if connected_peer_ids.has(peer_id) and PlayerProfileService.has_session(peer_id) and int(peer_raid_states.get(peer_id, -1)) == PeerRaidState.MULTIPLAYER_LOBBY:
		_create_raid_session([peer_id], true)


@rpc("authority", "call_remote", "reliable")
func _load_raid_on_clients(session_id: String) -> void:
	if is_connected_to_server():
		client_raid_session_id = session_id
		print("[RAID %s] load request received peer=%d" % [session_id, multiplayer.get_unique_id()])
		load_raid_requested.emit(session_id)


@rpc("any_peer", "call_remote", "reliable")
func _client_raid_loaded(session_id: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if get_peer_session_id(peer_id) != session_id:
		print("[RAID %s] ignored ready peer=%d" % [session_id, peer_id])
		return
	SessionManager.mark_player_loaded(session_id, peer_id)


@rpc("any_peer", "call_remote", "reliable")
func _request_raid_extraction(extraction_name: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var session_id := get_peer_session_id(peer_id)
	if PlayerProfileService.has_session(peer_id) and not session_id.is_empty() and int(peer_raid_states.get(peer_id, -1)) == PeerRaidState.IN_RAID:
		raid_extraction_requested.emit(peer_id, extraction_name, session_id)


@rpc("authority", "call_remote", "reliable")
func _raid_completed_on_client(success: bool, result: Dictionary) -> void:
	if is_connected_to_server():
		client_raid_session_id = ""
		raid_completed.emit(success, result)


@rpc("authority", "call_remote", "reliable")
func _load_raid_region_on_clients(session_id: String, region_id: String) -> void:
	if is_connected_to_server() and session_id == client_raid_session_id:
		load_raid_region_requested.emit(session_id, region_id)


@rpc("any_peer", "call_remote", "reliable")
func _client_raid_region_loaded(session_id: String, region_id: String) -> void:
	if not multiplayer.is_server() or not _region_transitions.has(session_id):
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if get_peer_session_id(peer_id) != session_id:
		return
	var transition: Dictionary = _region_transitions[session_id]
	if str(transition.get("region_id", "")) != region_id:
		return
	var loaded: Dictionary = transition.get("loaded", {})
	loaded[peer_id] = true
	transition["loaded"] = loaded
	_region_transitions[session_id] = transition
	_try_finish_region_transition(session_id)


func _try_finish_region_transition(session_id: String) -> void:
	if not _region_transitions.has(session_id):
		return
	var transition: Dictionary = _region_transitions[session_id]
	var loaded: Dictionary = transition.get("loaded", {})
	var members := get_session_members(session_id)
	if members.is_empty():
		_region_transitions.erase(session_id)
		return
	for loaded_peer: Variant in loaded.keys():
		if int(loaded_peer) not in members:
			loaded.erase(loaded_peer)
	if loaded.size() == members.size():
		_region_transitions.erase(session_id)
		raid_region_clients_ready.emit(session_id, members)


@rpc("authority", "call_remote", "reliable")
func _matchmaking_status(text: String) -> void:
	if is_connected_to_server():
		matchmaking_status_changed.emit(text)


@rpc("any_peer", "call_remote", "unreliable")
func _ping_server(sent_at_ms: int) -> void:
	if multiplayer.is_server():
		_pong_client.rpc_id(multiplayer.get_remote_sender_id(), sent_at_ms)


@rpc("authority", "call_remote", "unreliable")
func _pong_client(sent_at_ms: int) -> void:
	if is_connected_to_server():
		ping_ms = maxi(0, Time.get_ticks_msec() - sent_at_ms)


@rpc("authority", "call_remote", "reliable")
func _sync_client_profile(profile_snapshot: Dictionary, raid_inventory: Dictionary) -> void:
	if not is_connected_to_server():
		return
	GameState.apply_server_profile_snapshot(profile_snapshot)
	GameState.raid_inventory = raid_inventory.duplicate(true)
