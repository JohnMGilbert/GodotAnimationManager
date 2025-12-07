extends Control

# Target proportions
const MAIN_VS_FRACTION_TOP := 0.70
const HS_FRACTION_LEFT      := 0.68
const RIGHT_VS_FRACTION_TOP := 0.40

# Sidebar (vertical tabs) desired minimum width
const ASSETS_TABBAR_MIN := 160

# Fallback mins if any pane reports 0 (prevents collapse)
const FALLBACK_MIN_BUILDER   := Vector2i(600, 360)
const FALLBACK_MIN_PREVIEW   := Vector2i(320, 200)
const FALLBACK_MIN_INSPECTOR := Vector2i(320, 280)
const FALLBACK_MIN_ASSETS    := Vector2i(400, 180)

const TAB_BG_NORMAL  := Color("#3D3D3D")    # Dark grey
const TAB_BG_ACTIVE  := Color("#666666")    # Blue-ish highlight

# Editor-state file (lives alongside the .aam in the project dir)
const EDITOR_STATE_FILE := ".aam_editor.json"

# --- Node refs (adjust paths if your names differ) ---
@onready var vs_main_assets: VSplitContainer       = %VS_Main_Assets
@onready var hs_edit_sidebar: HSplitContainer      = %HS_Edit_Sidebar
@onready var vs_preview_inspector: VSplitContainer = %VS_Preview_Inspector
@onready var assets_tabs_split: HSplitContainer    = %AssetTabSplit

@onready var builder_panel: Control   = %BuilderPanel
@onready var preview_panel: Control   = %PreviewPanel
@onready var inspector_panel: Control = %InspectorPanel
@onready var assets_tabbar: Control   = %AssetsTabBar
@onready var assets_tabs: TabContainer = %AssetsTab

# --- Assets vertical tabs (Sprites / Sound) ---
@onready var tab_sprites_btn: TextureButton   = %Tab_Sprites
@onready var tab_sound_btn: TextureButton     = %Tab_Sound
@onready var tab_buttons: Array[TextureButton] = []

# Sprites UI
@onready var list_sprites: ItemList      = %List_Sprites
@onready var btn_import_sprites: Button  = %Btn_ImportSprites
@onready var fd_import_sprites: FileDialog = $FD_Import_Sprites
@onready var drag_indicator_lable: Label = %DragIndicatorLabel

# --- SOUND UI (mirrors sprite tab) ---
@onready var list_sound: ItemList        = %List_Sound
@onready var btn_import_sound: Button    = %Btn_ImportSound
@onready var fd_import_sound: FileDialog = $FD_Import_Sound

@onready var builder_view: Node = %BuilderView          # Should be a BuilderGrid
@onready var preview_sprite: AnimatedSprite2D = %PreviewSprite

@onready var btn_builder_settings: TextureButton = %Btn_BuilderSettings
@onready var settings_window: Window = %SettingsWindow

@onready var le_anim_name: LineEdit = %LineEdit_AnimName

@onready var rb_json: CheckBox = %CheckBox
@onready var rb_tres: CheckBox = %CheckBox2
@onready var rb_tscn: CheckBox = %CheckBox3

@onready var cb_trim: CheckBox = %CheckBox_Trim
@onready var cb_rename: CheckBox = %CheckBox_Rename
@onready var cb_overwrite: CheckBox = %CheckBox_Overwrite

@onready var btn_export: Button = %Btn_Export
@onready var lbl_export_status: Label = %Label_Export_Status

var preview_fps: float = 8.0
var export_repo_path: String = ""   # Godot project / destination repo

@export var sprite_icon_size: int = 96   # size of sprite thumbnails in the list
@export var sprite_label_font_size: int = 14

@onready var btn_eraser: TextureButton = %EraseBtn
var eraser_active: bool = false

@onready var builder_overlay: BuilderOverlay = %BuilderOverlay

# AUDIO STUFF
@onready var preview_audio: AudioStreamPlayer = %PreviewAudio
var _frame_sounds: Array = []          # index = frame index, value = Array[String] rel paths
var _audio_cache: Dictionary = {}      # rel -> AudioStream
@onready var btn_preview_playpause: TextureButton = %Btn_PreviewPlayPause
@onready var btn_preview_loop: TextureButton = %Btn_PreviewLoop
var preview_is_playing: bool = true
var preview_loop_enabled: bool = true

func _ready() -> void:
	# Let the root fill the window, but DO NOT touch child mins or splits
	set_anchors_preset(Control.PRESET_FULL_RECT)

	tab_buttons = [tab_sprites_btn, tab_sound_btn]
	_connect_asset_tabs()
	_select_asset_tab(0)

	_wire_sprite_import_ui()
	_wire_sound_import_ui()

	_setup_sprite_list()
	_setup_sound_list()

	_refresh_sprite_list()
	_refresh_sound_list()

	var win := get_window()
	if win:
		win.files_dropped.connect(_on_os_files_dropped)

	if builder_view:
		builder_view.sequences_changed.connect(_on_builder_sequences_changed)
		_on_builder_sequences_changed(builder_view.get_row_sequences())

	if btn_builder_settings:
		btn_builder_settings.pressed.connect(_on_builder_settings_pressed)

	if settings_window:
		settings_window.settings_applied.connect(_on_settings_applied)

	if btn_export:
		btn_export.pressed.connect(_on_export_pressed)
		
	if preview_sprite:
		preview_sprite.frame_changed.connect(_on_preview_frame_changed)

	if btn_preview_playpause:
		btn_preview_playpause.toggle_mode = true
		btn_preview_playpause.button_pressed = true  # start in “playing” state
		btn_preview_playpause.pressed.connect(_on_preview_playpause_pressed)

	if btn_preview_loop:
		btn_preview_loop.toggle_mode = true
		btn_preview_loop.button_pressed = true  # start with looping enabled
		btn_preview_loop.pressed.connect(_on_preview_loop_pressed)
	
	if btn_eraser:
		btn_eraser.toggle_mode = true
		btn_eraser.button_pressed = false
		btn_eraser.pressed.connect(_on_eraser_pressed)
		
	# Load editor state (animations + settings) from the editor-state file
	_load_editor_state()
	
		## FORCE-ENABLE MASTER BUS FOR DEBUG
	#var master_idx := AudioServer.get_bus_index("Master")
	#if master_idx >= 0:
		#AudioServer.set_bus_mute(master_idx, false)
		#AudioServer.set_bus_volume_db(master_idx, 0.0)
		#print("[AUDIO DEBUG] Master bus forced to 0 dB and unmuted.")


func _debug_test_sound_once() -> void:
	print("================= AUDIO TEST START =================")

	if preview_audio == null:
		print("[AUDIO DEBUG] preview_audio is null; cannot run test.")
		return

	print("[AUDIO DEBUG] preview_audio =", preview_audio)
	print("[AUDIO DEBUG] preview_audio path =", preview_audio.get_path())
	print("[AUDIO DEBUG] preview_audio.bus =", preview_audio.bus)
	print("[AUDIO DEBUG] preview_audio.volume_db (before) =", preview_audio.volume_db)

	var rel := "assets/audio/smb_jump-small.mp3"  # adjust if your rel is different
	var res_path := "res://%s" % rel
	print("[AUDIO DEBUG] Test sound path:", res_path)

	var exists := ResourceLoader.exists(res_path)
	print("[AUDIO DEBUG] ResourceLoader.exists(res_path) =", exists)

	if not exists:
		print("[AUDIO DEBUG] Resource does NOT exist at that path in THIS project.")
		return

	var res := ResourceLoader.load(res_path)
	print("[AUDIO DEBUG] ResourceLoader.load(...) returned:", res)

	if res == null:
		print("[AUDIO DEBUG] Loaded resource is NULL, aborting.")
		return

	if not (res is AudioStream):
		print("[AUDIO DEBUG] Loaded resource is NOT AudioStream. Type =", res.get_class())
		return

	var stream := res as AudioStream
	preview_audio.stream = stream
	print("[AUDIO DEBUG] After assignment preview_audio.stream =", preview_audio.stream)

	# Make sure it's loud enough
	preview_audio.volume_db = 0.0

	print("[AUDIO DEBUG] About to play...")
	preview_audio.play()
	print("[AUDIO DEBUG] preview_audio.playing =", preview_audio.playing)
	print("================= AUDIO TEST END =================")


func _on_os_files_dropped(files: PackedStringArray) -> void:
	var imgs: Array[String] = []
	var sounds: Array[String] = []

	for f in files:
		var ext := f.get_extension().to_lower()
		match ext:
			"png", "jpg", "jpeg", "webp":
				imgs.append(f)
			"wav", "ogg", "mp3", "flac":
				sounds.append(f)
			_:
				pass

	if not imgs.is_empty():
		var err_img := ProjectModel.import_sprites(imgs)
		if err_img != OK:
			_notify("Failed to import some sprites from OS drop (code %d)." % err_img)
		_refresh_sprite_list()

	if not sounds.is_empty():
		# NOTE: implement ProjectModel.import_audio(files) similar to import_sprites
		var err_snd = ProjectModel.import_audio(sounds)
		if err_snd != OK:
			_notify("Failed to import some audio files from OS drop (code %d)." % err_snd)
		_refresh_sound_list()


# --- Helpers (assume exactly two children) ---
func _child_ctrl(split: SplitContainer, idx: int) -> Control:
	var c := split.get_child(idx)
	return c as Control


func _on_builder_settings_pressed() -> void:
	print("Pressed settings button")
	if settings_window:
		if builder_view:
			settings_window.set_current_values(builder_view.cell_size, preview_fps, export_repo_path)
		settings_window.popup_centered()

func _on_eraser_pressed() -> void:
	eraser_active = btn_eraser.button_pressed

	var grid := builder_view as BuilderGrid
	if grid:
		grid.set_erase_mode(eraser_active)

func _on_preview_playpause_pressed() -> void:
	preview_is_playing = btn_preview_playpause.button_pressed

	if preview_sprite == null:
		return

	if preview_is_playing:
		preview_sprite.play()
	else:
		preview_sprite.stop()
		# Optional: also stop any playing audio
		if preview_audio:
			preview_audio.stop()


func _on_preview_loop_pressed() -> void:
	preview_loop_enabled = btn_preview_loop.button_pressed

	if preview_sprite == null:
		return

	var frames := preview_sprite.sprite_frames
	if frames == null:
		return

	var anim_name := "preview"
	if frames.has_animation(anim_name):
		frames.set_animation_loop(anim_name, preview_loop_enabled)


func _on_settings_applied(grid_cell_size: int, preview_fps_new: float, repo_path: String) -> void:
	# Save repo path (even if empty)
	export_repo_path = repo_path

	if builder_view:
		builder_view.cell_size = grid_cell_size
		builder_view._update_grid_dims()
		builder_view.queue_redraw()

	# Apply to preview
	preview_fps = preview_fps_new
	_on_builder_sequences_changed(builder_view.get_row_sequences())

	# Persist export repo in ProjectModel
	if repo_path != "":
		ProjectModel.set_export_repo(repo_path)

	save_editor_state()


func _connect_asset_tabs() -> void:
	for i in tab_buttons.size():
		var b: TextureButton = tab_buttons[i]
		b.toggle_mode = true
		b.button_pressed = false
		b.pressed.connect(func(idx := i) -> void:
			_select_asset_tab(idx))


func _select_asset_tab(index: int) -> void:
	var max_index: int = assets_tabs.get_tab_count() - 1
	index = clamp(index, 0, max_index)

	for j in tab_buttons.size():
		var btn := tab_buttons[j]
		btn.button_pressed = (j == index)

		var tab_panel := btn.get_parent() as PanelContainer
		if tab_panel:
			if j == index:
				tab_panel.add_theme_color_override("panel", TAB_BG_ACTIVE)
			else:
				tab_panel.remove_theme_color_override("panel")

	assets_tabs.current_tab = index
	print("Index for asset tab is: ", index)


# -------------------------------------------------------------------
# SPRITE IMPORT / LIST
# -------------------------------------------------------------------

func _wire_sprite_import_ui() -> void:
	if btn_import_sprites:
		btn_import_sprites.pressed.connect(func() -> void:
			if fd_import_sprites:
				fd_import_sprites.access = FileDialog.ACCESS_FILESYSTEM
				fd_import_sprites.file_mode = FileDialog.FILE_MODE_OPEN_FILES
				fd_import_sprites.filters = PackedStringArray([
					"*.png ; PNG Images",
					"*.jpg, *.jpeg ; JPEG Images",
					"*.webp ; WebP Images"
				])
				fd_import_sprites.popup_centered_ratio(0.75)
		)

	if fd_import_sprites:
		fd_import_sprites.files_selected.connect(_on_sprite_files_selected)


func _on_sprite_files_selected(files: PackedStringArray) -> void:
	var ok := ProjectModel.import_sprites(files)
	if ok != OK:
		_notify("Failed to import some sprites (code %d)." % ok)
	_refresh_sprite_list()


func _setup_sprite_list() -> void:
	if list_sprites == null:
		return
	list_sprites.icon_mode = ItemList.ICON_MODE_TOP
	list_sprites.same_column_width = true
	list_sprites.fixed_icon_size = Vector2i(sprite_icon_size, sprite_icon_size)
	list_sprites.max_columns = 0
	list_sprites.allow_reselect = true


func _refresh_sprite_list() -> void:
	if list_sprites == null:
		return
	list_sprites.clear()

	if ProjectModel.project_dir == "":
		push_warning("No project open; cannot list sprites.")
		return

	var rel_paths: Array[String] = ProjectModel.get_sprites()
	if rel_paths.is_empty():
		if drag_indicator_lable:
			drag_indicator_lable.show()
		return
	else:
		if drag_indicator_lable:
			drag_indicator_lable.hide()

	for rel in rel_paths:
		var abs := ProjectModel.project_dir.path_join(rel)
		var tex := _thumb_from_path(abs, sprite_icon_size)
		var label := rel.get_file()
		var idx := list_sprites.add_item(label)
		list_sprites.set_item_metadata(idx, rel)
		if tex != null:
			list_sprites.set_item_icon(idx, tex)


# -------------------------------------------------------------------
# SOUND IMPORT / LIST  (parallel to sprites)
# -------------------------------------------------------------------

func _wire_sound_import_ui() -> void:
	if btn_import_sound:
		btn_import_sound.pressed.connect(func() -> void:
			if fd_import_sound:
				fd_import_sound.access = FileDialog.ACCESS_FILESYSTEM
				fd_import_sound.file_mode = FileDialog.FILE_MODE_OPEN_FILES
				fd_import_sound.filters = PackedStringArray([
					"*.wav ; WAV Audio",
					"*.ogg ; Ogg Vorbis",
					"*.mp3 ; MP3 Audio",
					"*.flac ; FLAC Audio"
				])
				fd_import_sound.popup_centered_ratio(0.75)
		)

	if fd_import_sound:
		fd_import_sound.files_selected.connect(_on_sound_files_selected)

func _rebuild_sound_timeline() -> void:
	_frame_sounds.clear()

	var grid := builder_view as BuilderGrid
	if grid == null:
		print("[SOUND] No BuilderGrid, cannot rebuild sound timeline.")
		return

	# X positions for the frames used in the preview
	var xs: Array = grid.get_preview_frame_x_positions()
	var by_x: Dictionary = grid.get_sounds_by_x()

	print("[SOUND] Rebuild timeline: xs =", xs, "sounds_by_x =", by_x)

	if xs.is_empty():
		print("[SOUND] No preview frame X positions; no sounds will play.")
		return

	for i in xs.size():
		var x = xs[i]
		var sounds_for_x: Array = by_x.get(x, [])
		var list: Array = []
		for s in sounds_for_x:
			list.append(String(s))
		_frame_sounds.append(list)

	print("[SOUND] _frame_sounds size =", _frame_sounds.size(), "contents =", _frame_sounds)

func _on_sound_files_selected(files: PackedStringArray) -> void:
	# NOTE: implement ProjectModel.import_audio(files) similar to import_sprites
	var ok = ProjectModel.import_audio(files)
	if ok != OK:
		_notify("Failed to import some audio files (code %d)." % ok)
	_refresh_sound_list()

func _on_preview_frame_changed() -> void:
	if preview_sprite == null:
		return

	var frame_index := preview_sprite.frame
	print("[SOUND] Frame changed: index =", frame_index, "timeline size =", _frame_sounds.size())

	if frame_index < 0 or frame_index >= _frame_sounds.size():
		print("[SOUND] No sound entries for this frame.")
		return

	var sounds: Array = _frame_sounds[frame_index]
	print("[SOUND] Sounds for frame", frame_index, "=", sounds)

	for rel in sounds:
		_play_preview_sound(String(rel))
		
		
func _play_preview_sound(rel: String) -> void:
	if preview_audio == null:
		print("[SOUND] preview_audio is null; cannot play", rel)
		return

	var stream: AudioStream = null

	# Cache hit
	if _audio_cache.has(rel):
		stream = _audio_cache[rel] as AudioStream
		print("[SOUND] Using cached stream for", rel)
	else:
		# rel looks like "assets/audio/smb_jump-small.wav"
		var res_path := "res://%s" % rel
		print("[SOUND] Loading stream for rel =", rel, "res_path =", res_path)

		if not ResourceLoader.exists(res_path):
			print("[SOUND] ResourceLoader.exists == false for", res_path)
			return

		var res := ResourceLoader.load(res_path)
		if res == null:
			print("[SOUND] ResourceLoader.load returned null for", res_path)
			return

		if res is AudioStream:
			stream = res as AudioStream
			_audio_cache[rel] = stream
			print("[SOUND] Loaded AudioStream for", res_path)
		else:
			print("[SOUND] Loaded resource is not AudioStream:", res)
			return

	if stream == null:
		print("[SOUND] stream is null after loading for", rel)
		return

	preview_audio.stream = stream
	preview_audio.play()
	print("[SOUND] Playing", rel, "on bus =", preview_audio.bus, "volume_db =", preview_audio.volume_db)


func _setup_sound_list() -> void:
	if list_sound == null:
		return
	list_sound.icon_mode = ItemList.ICON_MODE_LEFT
	list_sound.same_column_width = false
	list_sound.allow_reselect = true
	list_sound.select_mode = ItemList.SELECT_SINGLE


func _refresh_sound_list() -> void:
	if list_sound == null:
		return
	list_sound.clear()

	if ProjectModel.project_dir == "":
		push_warning("No project open; cannot list audio.")
		return

	# NOTE: implement ProjectModel.get_audio() -> Array[String]
	var rel_paths: Array[String] = ProjectModel.get_audio()
	if rel_paths.is_empty():
		return

	for rel in rel_paths:
		var label := rel.get_file()
		var idx := list_sound.add_item(label)
		list_sound.set_item_metadata(idx, rel)
		# Optional: you could set an icon here (e.g. a generic speaker icon)


# -------------------------------------------------------------------
# Shared helpers
# -------------------------------------------------------------------

func _sprite_abs_path(rel: String) -> String:
	return ProjectModel.project_dir.path_join(rel)


func _thumb_from_path(abs: String, box: int) -> Texture2D:
	# Avoid engine error spam if file is missing
	if not FileAccess.file_exists(abs):
		push_warning("Sprite file missing, skipping thumb: %s" % abs)
		return null

	var img := Image.new()
	var err: int = img.load(abs)
	if err != OK:
		return null

	var w: int = img.get_width()
	var h: int = img.get_height()
	var longest: float = float(max(w, h))
	if longest > float(box):
		var scale := float(box) / longest
		var nw := int(round(w * scale))
		var nh := int(round(h * scale))
		img.resize(nw, nh, Image.INTERPOLATE_LANCZOS)

	return ImageTexture.create_from_image(img)


func _notify(msg: String) -> void:
	print(msg)


func _on_builder_sequences_changed(sequences: Array) -> void:
	if preview_sprite == null:
		return

	if sequences.is_empty():
		preview_sprite.sprite_frames = null
		return

	var first_seq: Array = sequences[0]  # use the first row/run as the preview
	if first_seq.is_empty():
		preview_sprite.sprite_frames = null
		return

	var frames := SpriteFrames.new()
	var anim_name := "preview"
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, preview_fps)
	frames.set_animation_loop(anim_name, preview_loop_enabled)

	for rel in first_seq:
		var tex: Texture2D = _texture_from_sprite_rel(String(rel))
		if tex != null:
			frames.add_frame(anim_name, tex)

	preview_sprite.sprite_frames = frames
	preview_sprite.animation = anim_name

	# Respect current play/pause state
	if preview_is_playing:
		preview_sprite.play()
	else:
		preview_sprite.stop()

	# Rebuild sound timeline so audio still lines up
	_rebuild_sound_timeline()


func _texture_from_sprite_rel(rel: String) -> Texture2D:
	var abs: String = ProjectModel.project_dir.path_join(rel)
	if not FileAccess.file_exists(abs):
		return null
	var img := Image.new()
	var err: int = img.load(abs)
	if err != OK:
		return null
	return ImageTexture.create_from_image(img)


func _on_export_pressed() -> void:
	var repo := export_repo_path

	if repo == "":
		var msg := "Export failed: Please set a Godot project folder (repo path) in Settings before exporting."
		_notify(msg)
		if lbl_export_status:
			lbl_export_status.text = msg
		return

	ProjectModel.set_export_repo(repo)

	var anim_name = ProjectModel.data.get("current_animation", "")
	if anim_name == "":
		if le_anim_name:
			anim_name = le_anim_name.text.strip_edges()
		if anim_name == "":
			anim_name = "default"

	if builder_view == null:
		var msg2 := "Export failed: BuilderView is missing."
		_notify(msg2)
		if lbl_export_status:
			lbl_export_status.text = msg2
		return

	var anim_data = builder_view.build_animation_data()
	anim_data["name"] = anim_name

	var seqs: Array = anim_data.get("sequences", [])
	if seqs.is_empty():
		var msg3 := "Export failed: current grid has no sequences/frames to export."
		_notify(msg3)
		if lbl_export_status:
			lbl_export_status.text = msg3
		return

	ProjectModel.set_animation(anim_name, anim_data)

	var err := ProjectModel.export_animation()
	if err != OK:
		var msg4 := "Export failed (code %d)." % err
		_notify(msg4)
		if lbl_export_status:
			lbl_export_status.text = msg4
	else:
		var msg_ok := "Export complete."
		_notify(msg_ok)
		if lbl_export_status:
			lbl_export_status.text = msg_ok

	save_editor_state()


# -------------------------------------------------------------------
# Editor state persistence (separate from the .aam game file)
# -------------------------------------------------------------------

func save_editor_state() -> void:
	if ProjectModel.project_dir == "":
		print("[EDITOR_STATE] Not saving, ProjectModel.project_dir is empty")
		return

	print("[EDITOR_STATE] Saving editor state for project_dir:", ProjectModel.project_dir)

	var data: Dictionary = {}

	data["preview_fps"] = preview_fps
	data["export_repo_path"] = export_repo_path
	if builder_view:
		data["grid_cell_size"] = builder_view.cell_size

	if builder_overlay:
		var bundle: Dictionary = builder_overlay.build_all_animation_data()
		data["builder_animations"] = bundle.get("animations", {})

	var path := ProjectModel.project_dir.path_join(EDITOR_STATE_FILE)
	print("[EDITOR_STATE] Writing to:", path)

	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Failed to open editor state file for writing: %s" % path)
		return

	f.store_string(JSON.stringify(data, "\t"))
	f.flush()
	f.close()


func _load_editor_state() -> void:
	if ProjectModel.project_dir == "":
		return

	var path := ProjectModel.project_dir.path_join(EDITOR_STATE_FILE)
	if not FileAccess.file_exists(path):
		return

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("Failed to open editor state file for reading: %s" % path)
		return

	var text := f.get_as_text()
	f.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Editor state file is malformed at: %s" % path)
		return

	var data := parsed as Dictionary

	preview_fps = float(data.get("preview_fps", preview_fps))
	export_repo_path = String(data.get("export_repo_path", export_repo_path))

	if builder_view:
		var cell_size_val := int(data.get("grid_cell_size", builder_view.cell_size))
		builder_view.cell_size = cell_size_val
		builder_view._update_grid_dims()
		builder_view.queue_redraw()

	if builder_overlay and data.has("builder_animations"):
		var anims_dict: Dictionary = data.get("builder_animations", {})
		builder_overlay.load_all_animation_data({ "animations": anims_dict })

	if builder_view:
		_on_builder_sequences_changed(builder_view.get_row_sequences())
