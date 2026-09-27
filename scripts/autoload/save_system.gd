extends Node
## Local-only save/load for SaveData (no cloud sync in v1).
## The .tres file is the source of truth; JSON export is for debugging only.

signal saved
signal loaded(data: SaveData)

const SAVE_PATH := "user://save.tres"
const DEBUG_JSON_PATH := "user://save_debug.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save(data: SaveData) -> bool:
	data.save_version = SaveData.CURRENT_VERSION
	var err := ResourceSaver.save(data, SAVE_PATH)
	if err != OK:
		push_error("SaveSystem: failed to save (%s)" % error_string(err))
		return false
	saved.emit()
	return true


## Returns the stored save (migrated to the current version) or a fresh one.
func load_save() -> SaveData:
	var data: SaveData = null
	if has_save():
		var res = ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res is SaveData:
			data = res
		else:
			push_warning("SaveSystem: save file unreadable, starting fresh")
	if data == null:
		data = SaveData.new()
	elif data.save_version < SaveData.CURRENT_VERSION:
		data = migrate_old_save(data)
	loaded.emit(data)
	return data


## Upgrades an old save one version at a time. Add a `match` branch per bump,
## e.g. `1: data.new_field = default`, never edit an old branch.
func migrate_old_save(data: SaveData) -> SaveData:
	while data.save_version < SaveData.CURRENT_VERSION:
		match data.save_version:
			_:
				pass
		data.save_version += 1
	return data


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func export_json(data: SaveData, path: String = DEBUG_JSON_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data.to_dict(), "\t"))
	return true


func import_json(path: String = DEBUG_JSON_PATH) -> SaveData:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return migrate_old_save(SaveData.from_dict(parsed))
