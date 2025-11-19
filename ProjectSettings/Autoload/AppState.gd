# autoloads/AppState.gd
extends Node

const RECENTS_FILE := "user://recents.cfg"
const MAX_RECENTS  := 12

const CONFIG_PATH := "user://settings.cfg"

var _recents: Array[String] = []
var last_project_dir: String = ""   # absolute dir that holds .aam files

var recents: Array[String] = []

func _ready() -> void:
	_load_recents()
	_load_settings()

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

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(CONFIG_PATH)
	if err == OK:
		_recents = cfg.get_value("general", "recents", []) as Array
		last_project_dir = String(cfg.get_value("general", "last_project_dir", ""))
	else:
		_recents = []
		last_project_dir = ""

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "recents", _recents)
	cfg.set_value("general", "last_project_dir", last_project_dir)
	cfg.save(CONFIG_PATH)

func _save_recents() -> void:
	var cfg := ConfigFile.new()
	var list: Array = []          # plain Array for ConfigFile storage
	for p in recents:
		list.append(p)
	cfg.set_value("projects", "recents", list)
	cfg.save(RECENTS_FILE)

func get_recents() -> Array[String]:
	return _recents.duplicate()

func add_recent(path: String) -> void:
	path = ProjectSettings.globalize_path(path)
	if _recents.has(path):
		_recents.erase(path)
	_recents.push_front(path)
	_save_settings()

func remove_recent(path: String) -> void:
	path = ProjectSettings.globalize_path(path)
	if _recents.has(path):
		_recents.erase(path)
	_save_settings()

func set_last_project_dir(dir: String) -> void:
	if dir == "":
		return
	# Normalize so it's always absolute
	last_project_dir = ProjectSettings.globalize_path(dir)
	_save_settings()

func get_last_project_dir() -> String:
	return last_project_dir

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
