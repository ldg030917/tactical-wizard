class_name PlayerSession
extends RefCounted

## Runtime-only connection state. peer_id is never used as a persistence key.

var peer_id: int
var user_id: String
var raid_session_id: String = ""
var connection_state: String = "IDENTITY_PENDING"
var profile_loaded: bool = false


func _init(current_peer_id: int, persistent_user_id: String) -> void:
	peer_id = current_peer_id
	user_id = persistent_user_id


func to_debug_dictionary() -> Dictionary:
	return {
		"peer_id": peer_id,
		"user_id": user_id,
		"raid_session_id": raid_session_id,
		"connection_state": connection_state,
		"profile_loaded": profile_loaded
	}
