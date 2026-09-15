extends Node

## Owns only queue batching. NetworkManager validates connection/player state,
## then creates a session from the match selected here.
signal match_ready(members: Array[int])
signal queue_changed(queue: Array[int])

const MIN_MATCH_PLAYERS := 2
const MAX_MATCH_PLAYERS := 4

var _queue: Array[int] = []


func enqueue(peer_id: int) -> bool:
	if peer_id <= 0 or _queue.has(peer_id):
		return false
	_queue.append(peer_id)
	print("[MATCH] queued peer=%d queue=%s" % [peer_id, str(_queue)])
	queue_changed.emit(_queue.duplicate())
	_try_create_matches()
	return true


func remove(peer_id: int, reason: String = "cancelled") -> bool:
	if not _queue.has(peer_id):
		return false
	_queue.erase(peer_id)
	print("[MATCH] queue leave peer=%d reason=%s queue=%s" % [peer_id, reason, str(_queue)])
	queue_changed.emit(_queue.duplicate())
	return true


func remove_invalid(valid_peers: Dictionary) -> void:
	var filtered: Array[int] = []
	for peer_id: int in _queue:
		if valid_peers.has(peer_id):
			filtered.append(peer_id)
	if filtered == _queue:
		return
	_queue = filtered
	queue_changed.emit(_queue.duplicate())


func contains(peer_id: int) -> bool:
	return _queue.has(peer_id)


func size() -> int:
	return _queue.size()


func members() -> Array[int]:
	return _queue.duplicate()


func _try_create_matches() -> void:
	while _queue.size() >= MIN_MATCH_PLAYERS:
		var members: Array[int] = []
		while not _queue.is_empty() and members.size() < MAX_MATCH_PLAYERS:
			members.append(_queue.pop_front())
		print("[MATCH] selected members=%s" % str(members))
		match_ready.emit(members)
		queue_changed.emit(_queue.duplicate())
