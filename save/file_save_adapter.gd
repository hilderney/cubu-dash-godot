class_name FileSaveAdapter
extends SavePort

const SAVE_PATH := "user://save.json"


func save_data(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data, "\t"))


func load_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Could not read save file: %s" % FileAccess.get_open_error())
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}
