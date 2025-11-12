# autoloads/AppState.gd
extends Node

const RECENTS_FILE := "user://recents.cfg"
const MAX_RECENTS  := 12

var recents: Array[String] = []

func _ready() -> void:
	_load_recents()

func _load_recents() -> void:
	var cfg := ConfigFile.new()
	var err: int = cfg.load(RECENTS_FILE)
	if err == OK:
		# get_value() returns Variant; normalize to Array[String]
		var raw_any: Array = cfg.get_value("projects", "recents", []) as Array
		var list: Array[String] = []
		for p in raw_any:
			if p is String:
				list.append(p)
		recents = list
	else:
		recents = []

func _save_recents() -> void:
	var cfg := ConfigFile.new()
	var list: Array = []          # plain Array for ConfigFile storage
	for p in recents:
		list.append(p)
	cfg.set_value("projects", "recents", list)
	cfg.save(RECENTS_FILE)

func add_recent(path: String) -> void:
	var abs: String = ProjectSettings.globalize_path(path)
	recents.erase(abs)
	recents.push_front(abs)
	if recents.size() > MAX_RECENTS:
		recents.resize(MAX_RECENTS)
	_save_recents()

func remove_recent(path: String) -> void:
	var abs: String = ProjectSettings.globalize_path(path)
	recents.erase(abs)
	_save_recents()

func get_recents() -> Array[String]:
	return recents.duplicate() as Array[String]

func create_new_project(path: String) -> Error:
	var data: Dictionary = {
		"schema": "aam.v1",
		"name": path.get_file().get_basename(),
		"created_at": Time.get_datetime_string_from_system(true),
		"assets": {
			"sprites": [],
			"audio": []
		},
		"animations": [],
		"tags": []
	}

	var dir: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var mk: int = DirAccess.make_dir_recursive_absolute(dir)
		if mk != OK:
			return mk

	var file := FileAccess.open(path, FileAccess.WRITE) # FileAccess or null
	if file == null:
		return ERR_CANT_OPEN
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	add_recent(path)
	return OK

func validate_project_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false

	var txt: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)  # Variant by design
	if not (parsed is Dictionary):
		return false

	var dict: Dictionary = parsed as Dictionary
	var schema_val: Variant = dict.get("schema", "")
	if not (schema_val is String):
		return false

	var schema: String = schema_val as String
	return schema.begins_with("aam.v")
