# autoloads/ProjectModel.gd
extends Node

const PROJECTS_ROOT := "user://projects"  # where all animation projects live

var project_dir: String = ""  # current project dir (user://projects/MyProject)

const SPRITES_DIR := "assets/sprites"

var project_path: String = ""                 # absolute path to .aam

var export_repo_path: String = ""  # absolute path to linked Godot project (optional)

# DATA STORAGE


signal project_loaded
signal project_saved
signal animation_list_changed
signal animation_changed(animation_name: String)

var data: Dictionary = {
	"animations": {},
	"current_animation": ""
}


func get_animation_names() -> PackedStringArray:
	var anims = data.get("animations", {})
	return PackedStringArray(anims.keys())


func get_animation(name: String) -> Dictionary:
	return data.get("animations", {}).get(name, {})


func set_animation(name: String, anim: Dictionary) -> void:
	if not data.has("animations"):
		data["animations"] = {}
	anim["name"] = name
	data["animations"][name] = anim
	data["current_animation"] = name
	emit_signal("animation_changed", name)
	emit_signal("animation_list_changed")


func delete_animation(name: String) -> void:
	if data.get("animations", {}).has(name):
		data["animations"].erase(name)
		emit_signal("animation_list_changed")
		if data.get("current_animation", "") == name:
			data["current_animation"] = ""
			emit_signal("animation_changed", "")


func _ready() -> void:
	var da := DirAccess.open("user://")
	if da == null:
		push_error("ProjectModel: Cannot open user:// directory.")
		return

	if not da.dir_exists("projects"):
		var err := da.make_dir("projects")
		if err != OK:
			push_error("ProjectModel: Could not create 'projects' dir (code %d)." % err)

func create_project(name: String) -> int:
	var safe_name := name.strip_edges()
	if safe_name == "":
		return ERR_INVALID_PARAMETER

	# Ensure projects root exists (defensive, even though _ready() handles it)
	var root_da := DirAccess.open("user://")
	if root_da == null:
		return ERR_CANT_OPEN
	if not root_da.dir_exists("projects"):
		var mk_root := root_da.make_dir("projects")
		if mk_root != OK:
			return mk_root

	# e.g. user://projects/MyNewProject
	var proj_path := PROJECTS_ROOT.path_join(safe_name)

	var da := DirAccess.open(PROJECTS_ROOT)
	if da == null:
		return ERR_CANT_OPEN

	if not da.dir_exists(safe_name):
		var err := da.make_dir(safe_name)
		if err != OK:
			return err

	project_dir = proj_path
	project_path = project_dir.path_join("%s.aam" % safe_name)

	# Initialize default project data
	data = {
		"animations": {},
		"current_animation": "",
		"assets": {
			"sprites": []
		},
		"export": {}
	}

	var save_err := save()
	if save_err != OK:
		return save_err

	emit_signal("project_loaded")
	emit_signal("animation_list_changed")
	emit_signal("animation_changed", "")

	return OK

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

	# Normalize assets block
	if not data.has("assets") or not (data["assets"] is Dictionary):
		data["assets"] = {}
	if not data["assets"].has("sprites"):
		data["assets"]["sprites"] = []

	# Normalize export block + export_repo_path
	if not data.has("export") or not (data["export"] is Dictionary):
		data["export"] = {}
	var export_dict: Dictionary = data["export"]
	var repo_val: Variant = export_dict.get("repo_path", "")
	if repo_val is String:
		export_repo_path = repo_val
	else:
		export_repo_path = ""

	# Normalize animations structure
	if not data.has("animations") or not (data["animations"] is Dictionary):
		data["animations"] = {}
	if not data.has("current_animation") or not (data["current_animation"] is String):
		data["current_animation"] = ""

	emit_signal("project_loaded")
	emit_signal("animation_list_changed")
	emit_signal("animation_changed", data.get("current_animation", ""))

	return OK

func save() -> Error:
	if project_path == "":
		return ERR_INVALID_DATA

	var file := FileAccess.open(project_path, FileAccess.WRITE)
	if file == null:
		return ERR_CANT_OPEN

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	emit_signal("project_saved")
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
	var current_name: String = data.get("current_animation", "")
	if current_name == "":
		push_warning("ProjectModel.set_sequences_from_builder: no current animation selected.")
		return

	# Update the current animation in the animations dict
	var anim: Dictionary = get_animation(current_name)
	if anim.is_empty():
		anim = {"name": current_name}

	anim["sequences"] = seq_rows
	set_animation(current_name, anim)  # updates data + emits signals

	# Mirror into legacy data["animation"] block for export_animation() compatibility
	if not data.has("animation") or not (data["animation"] is Dictionary):
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
	
const ERR_NO_PROJECT        := 1001
const ERR_NO_REPO           := 1002
const ERR_NO_SEQUENCES      := 1003
const ERR_COPY_FAILED       := 1004
const ERR_MANIFEST_FAILED   := 1005

func export_animation() -> int:
	# 1) Basic validation
	if project_dir == "":
		push_error("ProjectModel.export_animation: no project open.")
		return ERR_NO_PROJECT

	if export_repo_path == "":
		push_error("ProjectModel.export_animation: no export repo path set.")
		return ERR_NO_REPO

	if not data.has("animation"):
		push_error("ProjectModel.export_animation: no 'animation' block in data.")
		return ERR_NO_SEQUENCES

	var anim_block = data["animation"]
	if not (anim_block is Dictionary) or not anim_block.has("sequences"):
		push_error("ProjectModel.export_animation: no 'sequences' in animation block.")
		return ERR_NO_SEQUENCES

	var sequences: Array = anim_block["sequences"]
	if sequences.is_empty():
		push_error("ProjectModel.export_animation: sequences array is empty.")
		return ERR_NO_SEQUENCES

	# 2) Decide export layout under the game repo
	var repo_root := export_repo_path.rstrip("/")  # absolute dir
	# Use the builder project folder name as animation name
	var anim_name := project_dir.get_file()  # e.g., "GoblinWalkProject"

	var frames_rel_dir := "art/sprites/%s" % anim_name
	var frames_abs_dir := repo_root.path_join(frames_rel_dir)

	var manifest_rel_path := "art/animations/%s.json" % anim_name
	var manifest_abs_path := repo_root.path_join(manifest_rel_path)

	# 3) Create directories
	var err := DirAccess.make_dir_recursive_absolute(frames_abs_dir)
	if err != OK:
		push_error("export_animation: failed to create frames dir: %s (err %d)" % [frames_abs_dir, err])
		return ERR_COPY_FAILED

	err = DirAccess.make_dir_recursive_absolute(manifest_abs_path.get_base_dir())
	if err != OK:
		push_error("export_animation: failed to create manifest dir: %s (err %d)" % [manifest_abs_path.get_base_dir(), err])
		return ERR_MANIFEST_FAILED

	# 4) Copy all referenced sprite files into frames_abs_dir
	var copied: Dictionary = {}  # src_abs -> dst_filename (to avoid duplicate copies)
	var sequences_filenames: Array = []  # Array[Array[String]] of filenames only

	for seq in sequences:
		if not (seq is Array):
			continue
		var seq_names: Array = []
		for rel in seq:
			var rel_str := String(rel)
			var src_abs := project_dir.path_join(rel_str)
			var file_name := rel_str.get_file()
			var dst_abs := frames_abs_dir.path_join(file_name)

			if not copied.has(src_abs):
				# Copy if not already done
				var copy_err := DirAccess.copy_absolute(src_abs, dst_abs)
				if copy_err != OK:
					push_error("export_animation: failed to copy %s -> %s (err %d)" % [src_abs, dst_abs, copy_err])
					return ERR_COPY_FAILED
				copied[src_abs] = file_name

			seq_names.append(file_name)
		if not seq_names.is_empty():
			sequences_filenames.append(seq_names)

	if sequences_filenames.is_empty():
		push_error("export_animation: no usable frames after processing sequences.")
		return ERR_NO_SEQUENCES

	# 5) Write a simple JSON manifest
	var manifest: Dictionary = {
		"name": anim_name,
		"frames_dir": frames_rel_dir,          # e.g., "art/sprites/GoblinWalkProject"
		"sequences": sequences_filenames      # e.g., [["idle_1.png", "idle_2.png"], ["run_1.png", ...]]
	}

	var file := FileAccess.open(manifest_abs_path, FileAccess.WRITE)
	if file == null:
		push_error("export_animation: could not open manifest for writing: %s" % manifest_abs_path)
		return ERR_MANIFEST_FAILED

	var json_str := JSON.stringify(manifest, "\t")
	file.store_string(json_str)
	file.close()

	print("Exported animation manifest to: ", manifest_abs_path)
	print("Frames directory: ", frames_abs_dir)
	return OK
