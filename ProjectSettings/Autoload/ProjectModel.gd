# autoloads/ProjectModel.gd
extends Node

const SPRITES_DIR := "assets/sprites"

var project_path: String = ""                 # absolute path to .aam
var project_dir: String = ""                  # absolute dir of the project
var data: Dictionary = {}                     # in-memory .aam json

var export_repo_path: String = ""  # absolute path to linked Godot project (optional)

func open(path: String) -> Error:
	# absolute path preferred
	project_path = ProjectSettings.globalize_path(path)
	project_dir = project_path.get_base_dir()
	if not FileAccess.file_exists(project_path):
		return ERR_FILE_NOT_FOUND
	var txt: String = FileAccess.get_file_as_string(project_path)
	var parsed: Variant = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		return ERR_PARSE_ERROR
	data = parsed as Dictionary
	if not data.has("assets"):
		data["assets"] = {}
	if not (data["assets"] is Dictionary):
		data["assets"] = {}
	if not (data["assets"].has("sprites")):
		data["assets"]["sprites"] = []
	
		# after data has been filled from JSON
	var export_dict: Dictionary = {}
	if data.has("export") and data["export"] is Dictionary:
		export_dict = data["export"]
	var repo_val: Variant = export_dict.get("repo_path", "")
	if repo_val is String:
		export_repo_path = repo_val
	else:
		export_repo_path = ""
		
	return OK

func save() -> Error:
	if project_path == "":
		return ERR_INVALID_DATA
	var file := FileAccess.open(project_path, FileAccess.WRITE)
	if file == null:
		return ERR_CANT_OPEN
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return OK

func get_sprites() -> Array[String]:
	var arr: Array = data.get("assets", {}).get("sprites", []) as Array
	var out: Array[String] = []
	for v in arr:
		if v is String:
			out.append(v)
	return out

func import_sprites(paths: Array[String]) -> Error:
	if project_dir == "":
		return ERR_INVALID_DATA
	# ensure target directory exists
	var dst_dir_abs: String = project_dir.path_join(SPRITES_DIR)
	if not DirAccess.dir_exists_absolute(dst_dir_abs):
		var mk: int = DirAccess.make_dir_recursive_absolute(dst_dir_abs)
		if mk != OK:
			return mk

	# copy files and register relative paths into .aam
	var sprites: Array[String] = get_sprites()
	for src in paths:
		if src == "" or not FileAccess.file_exists(src):
			continue
		var ext: String = src.get_extension().to_lower()
		if ext != "png" and ext != "jpg" and ext != "jpeg" and ext != "webp":
			continue  # ignore non-image
		var base: String = src.get_file()
		var dst_abs: String = dst_dir_abs.path_join(base)
		# de-duplicate filename
		var name_only: String = base.get_basename()
		var ext_dot: String = "." + ext
		var i: int = 1
		while FileAccess.file_exists(dst_abs):
			var alt: String = "%s_%d%s" % [name_only, i, ext_dot]
			dst_abs = dst_dir_abs.path_join(alt)
			i += 1
		# perform copy
		var read := FileAccess.open(src, FileAccess.READ)
		if read == null:
			continue
		var buf: PackedByteArray = read.get_buffer(read.get_length())
		read.close()
		var write := FileAccess.open(dst_abs, FileAccess.WRITE)
		if write == null:
			continue
		write.store_buffer(buf)
		write.close()
		# store relative path into .aam (POSIX-like)
		var rel: String = SPRITES_DIR.path_join(dst_abs.get_file())
		if not sprites.has(rel):
			sprites.append(rel)

	# write back and save
	data["assets"]["sprites"] = sprites
	return save()


func set_sequences_from_builder(seq_rows: Array) -> void:
	# seq_rows: Array[Array[String]] of relative sprite paths
	if not data.has("animation"):
		data["animation"] = {}
	data["animation"]["sequences"] = seq_rows
	save()
	
	
func set_export_repo(path: String) -> void:
	export_repo_path = path
	if data.is_empty():
		return
	if not data.has("export") or not (data["export"] is Dictionary):
		data["export"] = {}
	var export_dict: Dictionary = data["export"]
	export_dict["repo_path"] = path
	data["export"] = export_dict
	save()
