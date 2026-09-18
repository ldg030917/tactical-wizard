class_name PlayerProfileStorage
extends RefCounted

## Replace this class (not gameplay code) when moving JSON persistence to a DB.

const DEFAULT_PROFILE_DIRECTORY := "user://player_profiles"

var profile_directory: String


func _init(directory: String = DEFAULT_PROFILE_DIRECTORY) -> void:
	profile_directory = directory.trim_suffix("/")


func load_profile_data(user_id: String) -> Dictionary:
	var path := _profile_path(user_id)
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[PROFILE] read failed user_id=%s error=%s" % [user_id, error_string(FileAccess.get_open_error())])
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("[PROFILE] invalid JSON user_id=%s path=%s" % [user_id, path])
		return {}
	return (parsed as Dictionary).duplicate(true)


func save_profile_data(user_id: String, data: Dictionary) -> bool:
	var path := _profile_path(user_id)
	if path.is_empty() or not _ensure_directory():
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[PROFILE] write failed user_id=%s error=%s" % [user_id, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


func _ensure_directory() -> bool:
	var absolute_path := ProjectSettings.globalize_path(profile_directory)
	var error := DirAccess.make_dir_recursive_absolute(absolute_path)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("[PROFILE] directory creation failed path=%s error=%s" % [absolute_path, error_string(error)])
		return false
	return true


func _profile_path(user_id: String) -> String:
	if not _is_safe_uuid(user_id):
		push_error("[PROFILE] unsafe user_id rejected")
		return ""
	return "%s/%s.json" % [profile_directory, user_id]


static func _is_safe_uuid(value: String) -> bool:
	if value.length() != 36:
		return false
	for index: int in range(value.length()):
		var character := value.substr(index, 1)
		if index in [8, 13, 18, 23]:
			if character != "-":
				return false
		elif character not in "0123456789abcdef":
			return false
	return true
