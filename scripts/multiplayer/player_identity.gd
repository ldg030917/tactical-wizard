extends Node

## Development-only persistent identity. This UUID is not authentication or a
## credential; a future Steam/login adapter should replace only this boundary.

const IDENTITY_PATH := "user://player_identity.json"

var user_id: String = ""


func _ready() -> void:
	if _is_dedicated_server_launch():
		return
	user_id = load_or_create_identity()


func load_or_create_identity(path: String = IDENTITY_PATH) -> String:
	if FileAccess.file_exists(path):
		var read_file := FileAccess.open(path, FileAccess.READ)
		if read_file != null:
			var parsed: Variant = JSON.parse_string(read_file.get_as_text())
			if parsed is Dictionary:
				var stored_id := str((parsed as Dictionary).get("user_id", "")).to_lower()
				if PlayerProfileStorage._is_safe_uuid(stored_id):
					return stored_id
		push_warning("[IDENTITY] invalid local identity; generating a replacement")
	var generated_id := _generate_uuid_v4()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[IDENTITY] failed to save local identity error=%s" % error_string(FileAccess.get_open_error()))
	else:
		file.store_string(JSON.stringify({"user_id": generated_id}, "\t"))
		print("[IDENTITY] created local development user_id=%s" % generated_id)
	return generated_id


func _generate_uuid_v4() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	if bytes.size() != 16:
		push_error("[IDENTITY] secure random UUID generation failed")
		return "00000000-0000-4000-8000-%012x" % Time.get_ticks_usec()
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := ""
	for value: int in bytes:
		hex += "%02x" % value
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]


func _is_dedicated_server_launch() -> bool:
	var arguments := PackedStringArray()
	arguments.append_array(OS.get_cmdline_user_args())
	arguments.append_array(OS.get_cmdline_args())
	return "--server" in arguments
