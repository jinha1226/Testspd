extends RefCounted
## Versioned Godot-side saves. Original Java Bundle save import is out of scope.

const FORMAT_VERSION := 1
const SLOT_COUNT := 6
const MAX_FILE_BYTES := 524288


static func slot_path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot if slot >= 1 and slot <= SLOT_COUNT else ""


static func exists(slot: int) -> bool:
	var path := slot_path(slot)
	return not path.is_empty() and FileAccess.file_exists(path)


static func save(run, slot: int) -> bool:
	var path := slot_path(slot)
	if path.is_empty():
		return false
	var content := JSON.stringify({"version": FORMAT_VERSION, "run": run.snapshot()})
	if content.to_utf8_buffer().size() > MAX_FILE_BYTES:
		return false
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.flush()
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),
		ProjectSettings.globalize_path(path)) == OK


static func load(run, slot: int) -> bool:
	var path := slot_path(slot)
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_FILE_BYTES:
		return false
	var content := file.get_as_text()
	file.close()
	return restore_text(run, content)


static func restore_text(run, content: String) -> bool:
	if content.to_utf8_buffer().size() > MAX_FILE_BYTES:
		return false
	var document = JSON.parse_string(content)
	if typeof(document) != TYPE_DICTIONARY or document.get("version") != FORMAT_VERSION \
			or typeof(document.get("run")) != TYPE_DICTIONARY:
		return false
	return run.restore_snapshot(document["run"])


static func export_text(slot: int) -> String:
	var path := slot_path(slot)
	if path.is_empty() or not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_FILE_BYTES:
		return ""
	var content := file.get_as_text()
	file.close()
	return content
