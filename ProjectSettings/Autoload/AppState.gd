# autoloads/AppState.gd
extends Node

const MAX_RECENTS  := 12
const DEFAULT_UI_SCALE := 1.0
const MIN_UI_SCALE := 0.75
const MAX_UI_SCALE := 1.75

const CONFIG_PATH := "user://settings.cfg"
const AnimationProjectSchema = preload("res://ProjectSettings/AnimationProjectSchema.gd")

signal ui_scale_changed(ui_scale: float)

var recents: Array[String] = []
var last_project_dir: String = ""   # absolute dir that holds .aam files
var ui_scale: float = DEFAULT_UI_SCALE

func _ready() -> void:
	_load_settings()

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(CONFIG_PATH)
	if err == OK:
		recents = _normalize_string_array(cfg.get_value("general", "recents", []))
		last_project_dir = String(cfg.get_value("general", "last_project_dir", ""))
		ui_scale = _sanitize_ui_scale(float(cfg.get_value("general", "ui_scale", DEFAULT_UI_SCALE)))
	else:
		recents = []
		last_project_dir = ""
		ui_scale = DEFAULT_UI_SCALE

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "recents", recents)
	cfg.set_value("general", "last_project_dir", last_project_dir)
	cfg.set_value("general", "ui_scale", ui_scale)
	cfg.save(CONFIG_PATH)

func get_recents() -> Array[String]:
	return recents.duplicate()

func add_recent(path: String) -> void:
	path = ProjectSettings.globalize_path(path)
	if recents.has(path):
		recents.erase(path)
	recents.push_front(path)
	if recents.size() > MAX_RECENTS:
		recents.resize(MAX_RECENTS)
	_save_settings()

func remove_recent(path: String) -> void:
	path = ProjectSettings.globalize_path(path)
	if recents.has(path):
		recents.erase(path)
	_save_settings()

func set_last_project_dir(dir: String) -> void:
	if dir == "":
		return
	# Normalize so it's always absolute
	last_project_dir = ProjectSettings.globalize_path(dir)
	_save_settings()

func get_last_project_dir() -> String:
	return last_project_dir

func get_ui_scale() -> float:
	return ui_scale

func set_ui_scale(value: float) -> void:
	var sanitized := _sanitize_ui_scale(value)
	if is_equal_approx(ui_scale, sanitized):
		return
	ui_scale = sanitized
	_save_settings()
	ui_scale_changed.emit(ui_scale)

func create_new_project(path: String) -> Error:
	var data := AnimationProjectSchema.create_empty_project(path.get_file().get_basename())

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
	return AnimationProjectSchema.is_valid_project_data(parsed)

func _normalize_string_array(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if raw is Array or raw is PackedStringArray:
		for value in raw:
			if value is String:
				out.append(value)
	return out

func _sanitize_ui_scale(value: float) -> float:
	return snappedf(clampf(value, MIN_UI_SCALE, MAX_UI_SCALE), 0.05)
