extends Node

## Owns logical raid sessions. The current implementation hosts a session world
## inside this Godot process; callers only use this API, so allocation can later
## be replaced by an external raid-server handoff.
signal world_requested(session_id: String)
signal members_loaded(session_id: String, members: Array[int])
signal member_removed(session_id: String, peer_id: int, reason: String, remaining: Array[int])
signal session_closed(session_id: String)

const MAX_ACTIVE_SESSIONS := 1

enum State { WAITING_FOR_WORLD, PREPARING_WORLD, LOADING, IN_RAID, CLOSED }

var _sessions: Dictionary = {}
var _player_sessions: Dictionary = {}
var _active_world_sessions: Dictionary = {}
var _next_session_number := 1


func create_session(requested_members: Array[int], is_test_session: bool = false) -> String:
	var members := _unique_members(requested_members)
	if members.is_empty():
		return ""
	var session_id := "raid_%d" % _next_session_number
	_next_session_number += 1
	var starts_now := _active_world_sessions.size() < MAX_ACTIVE_SESSIONS
	_sessions[session_id] = {
		"session_id": session_id,
		"state": State.PREPARING_WORLD if starts_now else State.WAITING_FOR_WORLD,
		"members": members,
		"loaded_members": {},
		"is_test": is_test_session
	}
	for peer_id: int in members:
		_player_sessions[peer_id] = session_id
	print("[SESSION] created id=%s members=%s test=%s" % [session_id, str(members), str(is_test_session)])
	if not starts_now:
		print("[SESSION %s] waiting for a local world slot" % session_id)
	return session_id


func get_session(session_id: String) -> Dictionary:
	return _sessions.get(session_id, {}).duplicate(true)


func get_session_members(session_id: String) -> Array[int]:
	var members: Array[int] = []
	for raw_peer: Variant in _sessions.get(session_id, {}).get("members", []):
		members.append(int(raw_peer))
	return members


func get_player_session(peer_id: int) -> String:
	return str(_player_sessions.get(peer_id, ""))


func activate_session(session_id: String) -> bool:
	if not _sessions.has(session_id) or _active_world_sessions.size() >= MAX_ACTIVE_SESSIONS:
		return false
	var session: Dictionary = _sessions[session_id]
	if int(session.get("state", State.CLOSED)) != State.PREPARING_WORLD:
		return false
	_active_world_sessions[session_id] = true
	world_requested.emit(session_id)
	return true


func begin_loading(session_id: String) -> bool:
	if not _sessions.has(session_id):
		return false
	var session: Dictionary = _sessions[session_id]
	if int(session.get("state", State.CLOSED)) != State.PREPARING_WORLD:
		return false
	session["state"] = State.LOADING
	session["loaded_members"] = {}
	_sessions[session_id] = session
	return true


func mark_player_loaded(session_id: String, peer_id: int) -> bool:
	if get_player_session(peer_id) != session_id or not _sessions.has(session_id):
		return false
	var session: Dictionary = _sessions[session_id]
	if int(session.get("state", State.CLOSED)) != State.LOADING:
		return false
	var loaded: Dictionary = session.get("loaded_members", {})
	loaded[peer_id] = true
	session["loaded_members"] = loaded
	_sessions[session_id] = session
	print("[SESSION %s] loaded peer=%d ready=%d/%d" % [session_id, peer_id, loaded.size(), get_session_members(session_id).size()])
	_try_finish_loading(session_id)
	return true


func remove_player(peer_id: int, reason: String) -> String:
	var session_id := get_player_session(peer_id)
	if session_id.is_empty() or not _sessions.has(session_id):
		_player_sessions.erase(peer_id)
		return ""
	var session: Dictionary = _sessions[session_id]
	var members: Array = session.get("members", [])
	members.erase(peer_id)
	session["members"] = members
	var loaded: Dictionary = session.get("loaded_members", {})
	loaded.erase(peer_id)
	session["loaded_members"] = loaded
	_sessions[session_id] = session
	_player_sessions.erase(peer_id)
	print("[SESSION %s] member remove peer=%d reason=%s remaining=%s" % [session_id, peer_id, reason, str(members)])
	member_removed.emit(session_id, peer_id, reason, members.duplicate())
	if members.is_empty():
		_close_session(session_id)
	elif int(session.get("state", State.CLOSED)) == State.LOADING:
		_try_finish_loading(session_id)
	return session_id


func _try_finish_loading(session_id: String) -> void:
	if not _sessions.has(session_id):
		return
	var session: Dictionary = _sessions[session_id]
	if int(session.get("state", State.CLOSED)) != State.LOADING:
		return
	var members := get_session_members(session_id)
	var loaded: Dictionary = session.get("loaded_members", {})
	if members.is_empty() or loaded.size() != members.size():
		return
	session["state"] = State.IN_RAID
	_sessions[session_id] = session
	print("[SESSION %s] all members loaded" % session_id)
	members_loaded.emit(session_id, members)


func _close_session(session_id: String) -> void:
	if not _sessions.has(session_id):
		return
	print("[SESSION %s] closing empty session" % session_id)
	_sessions.erase(session_id)
	_active_world_sessions.erase(session_id)
	session_closed.emit(session_id)
	_start_waiting_session_if_possible()


func _start_waiting_session_if_possible() -> void:
	if _active_world_sessions.size() >= MAX_ACTIVE_SESSIONS:
		return
	for session_id: String in _sessions:
		var session: Dictionary = _sessions[session_id]
		if int(session.get("state", State.CLOSED)) != State.WAITING_FOR_WORLD:
			continue
		session["state"] = State.PREPARING_WORLD
		_sessions[session_id] = session
		_active_world_sessions[session_id] = true
		world_requested.emit(session_id)
		return


func _unique_members(requested_members: Array[int]) -> Array[int]:
	var members: Array[int] = []
	for peer_id: int in requested_members:
		if peer_id > 0 and not members.has(peer_id) and get_player_session(peer_id).is_empty():
			members.append(peer_id)
	return members
