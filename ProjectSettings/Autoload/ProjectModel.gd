# autoloads/ProjectModel.gd
extends Node

const PROJECTS_ROOT := "user://projects"  # where all animation projects live
const AnimationProjectSchema = preload("res://ProjectSettings/AnimationProjectSchema.gd")

var project_dir: String = ""  # current project dir (user://projects/MyProject)

const SPRITES_DIR := "assets/sprites"
const AUDIO_SUBDIR := "assets/audio"
const SpritesheetUtils = preload("res://SpritesheetUtils.gd")
var project_path: String = ""                 # absolute path to .aam

var export_repo_path: String = ""  # absolute path to linked Godot project (optional)

# DATA STORAGE


signal project_loaded
signal project_saved
signal animation_list_changed
signal animation_changed(animation_name: String)

var data: Dictionary = {
	"schema": AnimationProjectSchema.SCHEMA_VERSION,
	"name": "",
	"created_at": "",
	"animations": {},
	"current_animation": "",
	"assets": {
		"sprites": [],
		"audio": []
	},
	"export": {},
	"asset_tags": {}
}

const EXPORT_SCHEMA_VERSION := "gam_export.v1"


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
	data = AnimationProjectSchema.create_empty_project(safe_name)

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

	data = AnimationProjectSchema.normalize_project_data(parsed)

	# Normalize export block + export_repo_path
	var export_dict: Dictionary = data["export"]
	var repo_val: Variant = export_dict.get("repo_path", "")
	if repo_val is String:
		export_repo_path = repo_val
	else:
		export_repo_path = ""

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


func get_audio() -> Array[String]:
	# Robust: list sounds directly from the assets/audio folder.
	var result: Array[String] = []

	if project_dir == "":
		return result

	var audio_dir := project_dir.path_join(AUDIO_SUBDIR)
	var dir := DirAccess.open(audio_dir)
	if dir == null:
		# No audio directory yet – that's fine.
		return result

	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if dir.current_is_dir():
			continue

		var ext := name.get_extension().to_lower()
		if ext == "wav" or ext == "ogg" or ext == "mp3" or ext == "flac":
			# Store as a project-relative path, e.g. "assets/audio/foo.wav"
			result.append("%s/%s" % [AUDIO_SUBDIR, name])
	dir.list_dir_end()

	return result


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


func import_sprites_from_sheet(
	sheet_path: String,
	cols: int,
	rows: int,
	tag_for_all: String = ""
) -> Error:
	if project_dir == "":
		return ERR_INVALID_DATA

	var dst_dir_abs: String = project_dir.path_join(SPRITES_DIR)
	if not DirAccess.dir_exists_absolute(dst_dir_abs):
		var mk: int = DirAccess.make_dir_recursive_absolute(dst_dir_abs)
		if mk != OK:
			return mk

	var sheet_name := sheet_path.get_file().get_basename()
	var frame_files: Array[String] = SpritesheetUtils.split_sheet_to_files(
		sheet_path,
		dst_dir_abs,
		cols,
		rows,
		sheet_name
	)

	if frame_files.is_empty():
		return ERR_CANT_OPEN

	var sprites: Array[String] = get_sprites()
	var normalized_tag := _normalize_single_tag(tag_for_all) if tag_for_all != "" else ""

	for fname in frame_files:
		var rel := SPRITES_DIR.path_join(fname)  # e.g. "assets/sprites/foo_00.png"
		if not sprites.has(rel):
			sprites.append(rel)

		# If a tag was requested, apply it to each frame
		if normalized_tag != "":
			add_asset_tags(rel, PackedStringArray([normalized_tag]))

	data["assets"]["sprites"] = sprites
	return save()


func delete_sprite_asset(asset_id: String) -> Error:
	if project_dir == "":
		return ERR_INVALID_DATA

	var normalized_asset_id := String(asset_id).strip_edges()
	if normalized_asset_id == "":
		return ERR_INVALID_PARAMETER

	var sprites: Array[String] = get_sprites()
	if sprites.has(normalized_asset_id):
		sprites.erase(normalized_asset_id)
	data["assets"]["sprites"] = sprites

	var tags_dict := _get_asset_tags_dict()
	if tags_dict.has(normalized_asset_id):
		tags_dict.erase(normalized_asset_id)
	data["asset_tags"] = tags_dict

	var animations = data.get("animations", {})
	if animations is Dictionary:
		for anim_name in animations.keys():
			var anim_data = animations[anim_name]
			if anim_data is Dictionary:
				animations[anim_name] = _remove_sprite_from_animation_data(anim_data as Dictionary, normalized_asset_id)
		data["animations"] = animations

	var abs_path := project_dir.path_join(normalized_asset_id)
	if FileAccess.file_exists(abs_path):
		var remove_err := DirAccess.remove_absolute(abs_path)
		if remove_err != OK:
			return remove_err

	return save()

func import_audio(files: PackedStringArray) -> int:
	if project_dir == "":
		return ERR_CANT_OPEN

	if not (data is Dictionary):
		data = {}

	var assets = data.get("assets", {})
	if typeof(assets) != TYPE_DICTIONARY:
		assets = {}

	var audio = assets.get("audio", [])
	if typeof(audio) != TYPE_ARRAY:
		audio = []

	# 1) Game repo audio dir (external project_dir)
	var game_audio_dir_abs := project_dir.path_join(AUDIO_SUBDIR)
	DirAccess.make_dir_recursive_absolute(game_audio_dir_abs)

	# 2) Animation manager project audio dir (this project's res://)
	var editor_root_abs := ProjectSettings.globalize_path("res://")
	var editor_audio_dir_abs := editor_root_abs.path_join(AUDIO_SUBDIR)
	DirAccess.make_dir_recursive_absolute(editor_audio_dir_abs)

	var last_err := OK

	for src in files:
		var src_path := String(src)
		var fname := src_path.get_file()
		var dst_rel := AUDIO_SUBDIR.path_join(fname)   # "assets/audio/foo.wav"

		var game_dst_abs := project_dir.path_join(dst_rel)
		var editor_dst_abs := editor_root_abs.path_join(dst_rel)

		# Copy into game repo
		var err := DirAccess.copy_absolute(src_path, game_dst_abs)
		if err != OK:
			last_err = err
			continue

		# Copy into animation manager project so res://assets/audio/... exists
		err = DirAccess.copy_absolute(src_path, editor_dst_abs)
		if err != OK:
			last_err = err
			# We still continue so at least game repo has it

		if not audio.has(dst_rel):
			audio.append(dst_rel)

	assets["audio"] = audio
	data["assets"] = assets

	return last_err


func set_sequences_from_builder(seq_rows: Array) -> void:
	# seq_rows: Array[Array[String]] of relative sprite paths
	var current_name: String = data.get("current_animation", "")
	if current_name == "":
		# No current animation yet; nothing to update
		return

	# Ensure animations dictionary exists
	if not data.has("animations") or not (data["animations"] is Dictionary):
		data["animations"] = {}

	# Get or create animation entry
	var anim: Dictionary = data["animations"].get(current_name, {"name": current_name})
	anim["sequences"] = seq_rows
	data["animations"][current_name] = anim

	# OPTIONAL: keep legacy block in sync for older code paths
	if not data.has("animation") or not (data["animation"] is Dictionary):
		data["animation"] = {}
	data["animation"]["sequences"] = seq_rows

	# IMPORTANT: do NOT call set_animation() here (no signals)
	save()
	
func set_export_repo(path: String) -> void:
	export_repo_path = path
	if data.is_empty():
		return
	var export_dict := _get_export_dict()
	export_dict["repo_path"] = path
	data["export"] = export_dict
	save()


func set_export_playback(fps: float, loop_enabled: bool) -> void:
	if data.is_empty():
		return
	var export_dict := _get_export_dict()
	export_dict["playback"] = {
		"fps": fps,
		"loop": loop_enabled,
	}
	data["export"] = export_dict
	save()


func get_export_playback() -> Dictionary:
	var export_dict := _get_export_dict()
	var playback_raw: Variant = export_dict.get("playback", {})
	if playback_raw is Dictionary:
		var playback_dict := playback_raw as Dictionary
		return {
			"fps": float(playback_dict.get("fps", 8.0)),
			"loop": bool(playback_dict.get("loop", true)),
		}
	return {
		"fps": 8.0,
		"loop": true,
	}


func _get_export_dict() -> Dictionary:
	if not data.has("export") or not (data["export"] is Dictionary):
		data["export"] = {}
	return data["export"]
	
# ----------------------------------------------------
# Asset tag system (project-wide)
# ----------------------------------------------------

func _get_asset_tags_dict() -> Dictionary:
	# Ensure the sub-dictionary exists
	if not data.has("asset_tags") or not (data["asset_tags"] is Dictionary):
		data["asset_tags"] = {}
	return data["asset_tags"]


func get_asset_tags(asset_id: String) -> PackedStringArray:
	var tags_dict := _get_asset_tags_dict()
	if not tags_dict.has(asset_id):
		return PackedStringArray()

	var raw = tags_dict[asset_id]
	var out: Array = []

	if raw is Array or raw is PackedStringArray:
		for v in raw:
			if v is String:
				var t := _normalize_single_tag(v)
				if t != "" and not out.has(t):
					out.append(t)
	elif raw is String:
		var t := _normalize_single_tag(raw)
		if t != "" and not out.has(t):
			out.append(t)

	return PackedStringArray(out)


func set_asset_tags(asset_id: String, tags: PackedStringArray) -> void:
	var tags_dict := _get_asset_tags_dict()
	var cleaned := _normalize_tags(tags)

	if cleaned.is_empty():
		tags_dict.erase(asset_id)
	else:
		tags_dict[asset_id] = cleaned

	data["asset_tags"] = tags_dict
	save()  # IMPORTANT: persist tags immediately


func add_asset_tags(asset_id: String, tags_to_add: PackedStringArray) -> void:
	var existing := get_asset_tags(asset_id)
	var merged: Array = existing.duplicate()

	for t in tags_to_add:
		var norm := _normalize_single_tag(t)
		if norm != "" and not merged.has(norm):
			merged.append(norm)

	set_asset_tags(asset_id, PackedStringArray(merged))


func remove_asset_tags(asset_id: String, tags_to_remove: PackedStringArray) -> void:
	var existing := get_asset_tags(asset_id)
	if existing.is_empty():
		return

	var arr: Array = existing.duplicate()
	for t in tags_to_remove:
		var norm := _normalize_single_tag(t)
		arr.erase(norm)

	set_asset_tags(asset_id, PackedStringArray(arr))


func get_all_tags() -> PackedStringArray:
	var tags_dict := _get_asset_tags_dict()
	var seen: Dictionary = {}  # acts as a set

	for asset_id in tags_dict.keys():
		var ts: PackedStringArray = get_asset_tags(asset_id)
		for t in ts:
			seen[t] = true

	var out: Array = []
	for k in seen.keys():
		out.append(String(k))

	out.sort()
	return PackedStringArray(out)


func get_assets_with_tag(tag: String) -> Array:
	var tags_dict := _get_asset_tags_dict()
	var normalized := _normalize_single_tag(tag)
	if normalized == "":
		return []

	var results: Array = []
	for asset_id in tags_dict.keys():
		var ts: PackedStringArray = get_asset_tags(asset_id)
		if ts.has(normalized):
			results.append(asset_id)
	return results


func _normalize_tags(tags: PackedStringArray) -> PackedStringArray:
	var out: Array = []
	for raw in tags:
		var t := _normalize_single_tag(raw)
		if t != "" and not out.has(t):
			out.append(t)
	return PackedStringArray(out)


func _normalize_single_tag(raw: String) -> String:
	var t := raw.strip_edges()
	if t == "":
		return ""

	t = t.to_lower()

	# Collapse all whitespace sequences into a single space
	var parts := t.split(" ", true, 0)  # split by ANY number of spaces
	var filtered: Array = []
	for p in parts:
		if p.strip_edges() != "":
			filtered.append(p)

	# Join with a single space
	return " ".join(filtered)


func _remove_sprite_from_animation_data(anim: Dictionary, asset_id: String) -> Dictionary:
	var cleaned := anim.duplicate(true)

	if cleaned.has("cells"):
		var kept_cells: Array = []
		var raw_cells = cleaned.get("cells", [])
		if raw_cells is Array:
			for cell in raw_cells:
				if not (cell is Dictionary):
					continue
				var cell_dict := cell as Dictionary
				if String(cell_dict.get("rel", "")) != asset_id:
					kept_cells.append(cell_dict)
		cleaned["cells"] = kept_cells

	if cleaned.has("sequences"):
		var kept_sequences: Array = []
		var raw_sequences = cleaned.get("sequences", [])
		if raw_sequences is Array:
			for seq in raw_sequences:
				if not (seq is Array):
					continue
				var kept_seq: Array = []
				for rel in seq:
					var rel_str := String(rel)
					if rel_str != asset_id:
						kept_seq.append(rel_str)
				if not kept_seq.is_empty():
					kept_sequences.append(kept_seq)
		cleaned["sequences"] = kept_sequences

	return cleaned
	
	
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

	var current_name: String = data.get("current_animation", "")
	if current_name == "":
		push_error("ProjectModel.export_animation: no current animation selected.")
		return ERR_NO_SEQUENCES

	var anim: Dictionary = get_animation(current_name)
	if anim.is_empty():
		push_error("ProjectModel.export_animation: current animation '%s' has no data." % current_name)
		return ERR_NO_SEQUENCES

	if not anim.has("sequences"):
		push_error("ProjectModel.export_animation: animation '%s' has no 'sequences' field." % current_name)
		return ERR_NO_SEQUENCES

	var sequences: Array = anim["sequences"]
	if sequences.is_empty():
		push_error("ProjectModel.export_animation: sequences array is empty for '%s'." % current_name)
		return ERR_NO_SEQUENCES

	var frame_entries := _build_export_frame_entries(anim)
	if frame_entries.is_empty():
		push_error("ProjectModel.export_animation: no usable frame entries for '%s'." % current_name)
		return ERR_NO_SEQUENCES

	var export_playback := get_export_playback()

	# 2) Decide export layout under the game repo
	var repo_root := export_repo_path.rstrip("/")  # absolute dir

	# Use the animation name as the export name (not the project folder name)
	var anim_name := current_name

	var frames_rel_dir := "art/sprites/%s" % anim_name
	var frames_abs_dir := repo_root.path_join(frames_rel_dir)
	var audio_rel_dir := "art/audio/%s" % anim_name
	var audio_abs_dir := repo_root.path_join(audio_rel_dir)

	var manifest_rel_path := "art/animations/%s.json" % anim_name
	var manifest_abs_path := repo_root.path_join(manifest_rel_path)

	# 3) Create directories
	var err := DirAccess.make_dir_recursive_absolute(frames_abs_dir)
	if err != OK:
		push_error("export_animation: failed to create frames dir: %s (err %d)" % [frames_abs_dir, err])
		return ERR_COPY_FAILED

	err = DirAccess.make_dir_recursive_absolute(audio_abs_dir)
	if err != OK:
		push_error("export_animation: failed to create audio dir: %s (err %d)" % [audio_abs_dir, err])
		return ERR_COPY_FAILED

	err = DirAccess.make_dir_recursive_absolute(manifest_abs_path.get_base_dir())
	if err != OK:
		push_error("export_animation: failed to create manifest dir: %s (err %d)" % [manifest_abs_path.get_base_dir(), err])
		return ERR_MANIFEST_FAILED

	# 4) Copy referenced sprite + audio assets and build manifest frame entries
	var copied_sprites: Dictionary = {}  # src_abs -> dst_filename
	var copied_audio: Dictionary = {}  # src_abs -> dst_filename
	var manifest_frames: Array = []

	for i in range(frame_entries.size()):
		var entry: Dictionary = frame_entries[i]
		var sprite_rel := String(entry.get("rel", ""))
		var sprite_src_abs := project_dir.path_join(sprite_rel)
		var sprite_dst_name := _copy_export_asset(sprite_src_abs, frames_abs_dir, copied_sprites)
		if sprite_dst_name == "":
			push_error("export_animation: failed to export sprite asset %s" % sprite_src_abs)
			return ERR_COPY_FAILED

		var exported_sounds: Array = []
		var sounds: Array = entry.get("sounds", [])
		for sound_rel in sounds:
			var sound_rel_str := String(sound_rel)
			var sound_src_abs := project_dir.path_join(sound_rel_str)
			var sound_dst_name := _copy_export_asset(sound_src_abs, audio_abs_dir, copied_audio)
			if sound_dst_name == "":
				push_error("export_animation: failed to export audio asset %s" % sound_src_abs)
				return ERR_COPY_FAILED
			exported_sounds.append(sound_dst_name)

		manifest_frames.append({
			"index": i,
			"image": sprite_dst_name,
			"source_rel": sprite_rel,
			"x": int(entry.get("x", 0)),
			"y": int(entry.get("y", 0)),
			"sounds": exported_sounds,
		})

	if manifest_frames.is_empty():
		push_error("export_animation: no usable manifest frames for '%s'." % current_name)
		return ERR_NO_SEQUENCES

	# 5) Write manifest
	var manifest: Dictionary = {
		"schema": EXPORT_SCHEMA_VERSION,
		"animation_name": anim_name,
		"source_project": {
			"name": String(data.get("name", "")),
			"schema": String(data.get("schema", AnimationProjectSchema.SCHEMA_VERSION)),
		},
		"playback": export_playback,
		"assets": {
			"sprites_dir": frames_rel_dir,
			"audio_dir": audio_rel_dir,
		},
		"frames": manifest_frames,
	}

	var file := FileAccess.open(manifest_abs_path, FileAccess.WRITE)
	if file == null:
		push_error("export_animation: could not open manifest for writing: %s" % manifest_abs_path)
		return ERR_MANIFEST_FAILED

	var json_str := JSON.stringify(manifest, "\t")
	file.store_string(json_str)
	file.close()

	print("Exported animation '%s' manifest to: %s" % [anim_name, manifest_abs_path])
	print("Frames directory: ", frames_abs_dir)
	return OK


func _build_export_frame_entries(anim: Dictionary) -> Array:
	var cells_raw: Variant = anim.get("cells", [])
	var sound_cells_raw: Variant = anim.get("sound_cells", [])

	var top_by_x: Dictionary = {}
	if cells_raw is Array:
		for cell_entry in cells_raw:
			if not (cell_entry is Dictionary):
				continue
			var cell_dict := cell_entry as Dictionary
			var rel := String(cell_dict.get("rel", ""))
			if rel == "":
				continue
			var x := int(cell_dict.get("x", 0))
			var y := int(cell_dict.get("y", 0))

			if not top_by_x.has(x):
				top_by_x[x] = {
					"x": x,
					"y": y,
					"rel": rel,
				}
				continue

			var existing: Dictionary = top_by_x[x]
			if y < int(existing.get("y", 0)):
				top_by_x[x] = {
					"x": x,
					"y": y,
					"rel": rel,
				}

	var sounds_by_x: Dictionary = {}
	if sound_cells_raw is Array:
		for sound_entry in sound_cells_raw:
			if not (sound_entry is Dictionary):
				continue
			var sound_dict := sound_entry as Dictionary
			var sound_rel := String(sound_dict.get("rel", ""))
			if sound_rel == "":
				continue
			var sound_x := int(sound_dict.get("x", 0))
			var sound_list: Array = sounds_by_x.get(sound_x, [])
			if not sound_list.has(sound_rel):
				sound_list.append(sound_rel)
			sounds_by_x[sound_x] = sound_list

	var xs: Array = top_by_x.keys()
	xs.sort()

	var frames: Array = []
	for x_value in xs:
		var frame_entry: Dictionary = top_by_x[x_value]
		frames.append({
			"x": int(frame_entry.get("x", 0)),
			"y": int(frame_entry.get("y", 0)),
			"rel": String(frame_entry.get("rel", "")),
			"sounds": sounds_by_x.get(int(x_value), []).duplicate(),
		})

	return frames


func _copy_export_asset(src_abs: String, dst_dir_abs: String, copied_map: Dictionary) -> String:
	if src_abs == "":
		return ""
	if not FileAccess.file_exists(src_abs):
		return ""
	if copied_map.has(src_abs):
		return String(copied_map[src_abs])

	var original_name := src_abs.get_file()
	var resolved_name := _resolve_export_filename(dst_dir_abs, original_name, copied_map)
	if resolved_name == "":
		return ""

	var dst_abs := dst_dir_abs.path_join(resolved_name)
	var copy_err := DirAccess.copy_absolute(src_abs, dst_abs)
	if copy_err != OK:
		return ""

	copied_map[src_abs] = resolved_name
	return resolved_name


func _resolve_export_filename(dst_dir_abs: String, file_name: String, copied_map: Dictionary) -> String:
	var used_names: Dictionary = {}
	for existing_name in copied_map.values():
		used_names[String(existing_name)] = true

	if not used_names.has(file_name) and not FileAccess.file_exists(dst_dir_abs.path_join(file_name)):
		return file_name

	var basename := file_name.get_basename()
	var extension := file_name.get_extension()
	var suffix := 1
	while true:
		var candidate := "%s_%d" % [basename, suffix]
		if extension != "":
			candidate += ".%s" % extension
		if not used_names.has(candidate) and not FileAccess.file_exists(dst_dir_abs.path_join(candidate)):
			return candidate
		suffix += 1

	return ""
