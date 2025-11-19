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

# --- Node refs (adjust paths if your names differ) ---
@onready var vs_main_assets: VSplitContainer       = %VS_Main_Assets
@onready var hs_edit_sidebar: HSplitContainer      = %HS_Edit_Sidebar
@onready var vs_preview_inspector: VSplitContainer = %VS_Preview_Inspector
@onready var assets_tabs_split: HSplitContainer    = %AssetTabSplit

@onready var builder_panel: Control   = %BuilderPanel
@onready var preview_panel: Control   = %PreviewPanel
@onready var inspector_panel: Control = %InspectorPanel
@onready var assets_tabbar: Control   = %AssetsTabBar
@onready var assets_tabs: Control     = %AssetsTab

# --- Assets vertical tabs (Sprites / Sound) ---
@onready var tab_sprites_btn: TextureButton   = %Tab_Sprites
@onready var tab_sound_btn: TextureButton     = %Tab_Sound
@onready var tab_buttons: Array[TextureButton] = []

# Sprites UI
@onready var list_sprites: ItemList    = %List_Sprites
@onready var btn_import_sprites: Button = %Btn_ImportSprites
@onready var fd_import_sprites: FileDialog = $FD_Import_Sprites

@onready var builder_view: Node = %BuilderView
@onready var preview_sprite: AnimatedSprite2D = %PreviewSprite

@onready var btn_builder_settings: TextureButton = %Btn_BuilderSettings
@onready var settings_window: Window = %SettingsWindow

#@onready var le_repo_path: LineEdit = %LineEdit_RepoPath # Change this one
@onready var le_anim_name: LineEdit = %LineEdit_AnimName

@onready var rb_json: CheckBox = %CheckBox
@onready var rb_tres: CheckBox = %CheckBox2
@onready var rb_tscn: CheckBox = %CheckBox3

@onready var cb_trim: CheckBox = %CheckBox_Trim
@onready var cb_rename: CheckBox = %CheckBox_Rename
@onready var cb_overwrite: CheckBox = %CheckBox_Overwrite
#@onready var cb_open: CheckBox = $RootVBox/.../ExportTab/Section_Options/CheckBox_OpenFolder

@onready var btn_export: Button = %Btn_Export
@onready var lbl_export_status: Label = %Label_Export_Status

@onready var drag_indicator_lable: Label = %DragIndicatorLabel

var preview_fps: float = 8.0
var export_repo_path: String = ""   # Godot project / destination repo

@export var sprite_icon_size: int = 96   # size of sprite thumbnails in the list
@export var sprite_label_font_size: int = 14


func _ready() -> void:
	# Let the root fill the window, but DO NOT touch child mins or splits
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# REMOVE / COMMENT OUT:
	# _force_expand_and_minimums()
	# call_deferred("_apply_responsive_splits_deferred()")
	# get_window().size_changed.connect(...)
	# get_viewport().size_changed.connect(...)

	tab_buttons = [tab_sprites_btn, tab_sound_btn]
	_connect_asset_tabs()
	_select_asset_tab(0)

	_wire_sprite_import_ui()
	_refresh_sprite_list()

	var win := get_window()
	if win:
		win.files_dropped.connect(_on_os_files_dropped)

	_setup_sprite_list()
	_refresh_sprite_list()

	if builder_view:
		builder_view.sequences_changed.connect(_on_builder_sequences_changed)
		_on_builder_sequences_changed(builder_view.get_row_sequences())

	if btn_builder_settings:
		btn_builder_settings.pressed.connect(_on_builder_settings_pressed)

	if settings_window:
		settings_window.settings_applied.connect(_on_settings_applied)

	if btn_export:
		btn_export.pressed.connect(_on_export_pressed)	

func _on_os_files_dropped(files: PackedStringArray) -> void:
	var imgs: Array[String] = []
	for f in files:
		var ext := f.get_extension().to_lower()
		if ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "webp":
			imgs.append(f)
	if imgs.is_empty():
		print("Dropped files, but none were images:", files)
		return

	var err := ProjectModel.import_sprites(imgs)
	if err != OK:
		_notify("Failed to import some sprites from OS drop (code %d)." % err)

	_refresh_sprite_list()

#func _apply_responsive_splits_deferred() -> void:
	## Wait one more frame to ensure sizes are final during resize drags on some platforms
	#await get_tree().process_frame
	#_apply_responsive_splits()

#func _force_expand_and_minimums() -> void:
	## Root fills window
	#set_anchors_preset(Control.PRESET_FULL_RECT)
#
	## All main containers expand
	#for p in [
		#"RootVBox/VS_Main_Assets",
		#"RootVBox/VS_Main_Assets/HS_Edit_Sidebar",
		#"RootVBox/VS_Main_Assets/HS_Edit_Sidebar/VS_Preview_Inspector",
		#"RootVBox/VS_Main_Assets/AssetsPanel/HSplitContainer"
	#]:
		#var n := get_node_or_null(p) as Control
		#if n:
			#n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			#n.size_flags_vertical   = Control.SIZE_EXPAND_FILL
#
	## Panels expand + fallback mins to avoid zeros
	#_set_min(builder_panel,   FALLBACK_MIN_BUILDER)
	#_set_min(preview_panel,   FALLBACK_MIN_PREVIEW)
	#_set_min(inspector_panel, FALLBACK_MIN_INSPECTOR)
	#_set_min(assets_tabs,     FALLBACK_MIN_ASSETS)
	## sidebar width hint
	#if assets_tabbar:
		#if assets_tabbar.custom_minimum_size.x < ASSETS_TABBAR_MIN:
			#var cms := assets_tabbar.custom_minimum_size
			#cms.x = ASSETS_TABBAR_MIN
			#assets_tabbar.custom_minimum_size = cms

#func _set_min(ctrl: Control, fallback: Vector2i) -> void:
	#if ctrl == null:
		#return
	#var min := ctrl.get_combined_minimum_size()
	#var cms := ctrl.custom_minimum_size
	#if min.x <= 0 and cms.x <= 0:
		#cms.x = fallback.x
	#if min.y <= 0 and cms.y <= 0:
		#cms.y = fallback.y
	#ctrl.custom_minimum_size = cms
	#ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	#ctrl.size_flags_vertical   = Control.SIZE_EXPAND_FILL

#func _apply_responsive_splits() -> void:
	## Sanity: SplitContainers must have exactly two children
	#_assert_two_children(vs_main_assets)
	#_assert_two_children(hs_edit_sidebar)
	#_assert_two_children(vs_preview_inspector)
	#_assert_two_children(assets_tabs_split)
#
	## Guard zero sizes (can happen during initial layout)
	#if vs_main_assets.size.y <= 0 or hs_edit_sidebar.size.x <= 0 or vs_preview_inspector.size.y <= 0:
		#return
#
	## Top vs bottom
	#_fit_vsplit(
		#vs_main_assets,
		#MAIN_VS_FRACTION_TOP,
		#_min_h(vs_main_assets, true),
		#_min_h(vs_main_assets, false)
	#)
#
	## Builder vs right stack
	#_fit_hsplit(
		#hs_edit_sidebar,
		#HS_FRACTION_LEFT,
		#_min_w(hs_edit_sidebar, true),
		#_min_w(hs_edit_sidebar, false)
	#)
#
	## Preview vs inspector
	#_fit_vsplit(
		#vs_preview_inspector,
		#RIGHT_VS_FRACTION_TOP,
		#_min_h(vs_preview_inspector, true),
		#_min_h(vs_preview_inspector, false)
	#)
#
	## Assets: left vertical tab bar vs tab content
	#if assets_tabs_split.size.x > 0:
		#var total_w: float = assets_tabs_split.size.x
		#var left_min: float = max(ASSETS_TABBAR_MIN, _min_w(assets_tabs_split, true))
		#var right_min: float = _min_w(assets_tabs_split, false)
		## ~18% or min; also ensure right side gets its minimum
		#var desired_left: int = max(int(total_w * 0.18), int(left_min))
		#var max_left: int = int(total_w) - int(right_min)
		#assets_tabs_split.split_offset = clamp(desired_left, int(left_min), max_left)

# --- Helpers (assume exactly two children) ---
func _child_ctrl(split: SplitContainer, idx: int) -> Control:
	var c := split.get_child(idx)
	return c as Control

#func _min_w(split: SplitContainer, left_or_top: bool) -> float:
	#var idx: int = 0 if left_or_top else 1
	#var target: Control = _child_ctrl(split, idx)
	#if target == null:
		#return 0.0
	#return max(1.0, target.get_combined_minimum_size().x)
#
#func _min_h(split: SplitContainer, left_or_top: bool) -> float:
	#var idx: int = 0 if left_or_top else 1
	#var target: Control = _child_ctrl(split, idx)
	#if target == null:
		#return 0.0
	#return max(1.0, target.get_combined_minimum_size().y)
#
#func _fit_hsplit(split: HSplitContainer, fraction_left: float, min_left: float, min_right: float) -> void:
	#var total: float = max(1.0, split.size.x)
	#var desired: int = int(total * clamp(fraction_left, 0.0, 1.0))
	#var min_off: int = int(min_left)
	#var max_off: int = int(total - min_right)
	#split.split_offset = clamp(desired, min_off, max_off)
#
#func _fit_vsplit(split: VSplitContainer, fraction_top: float, min_top: float, min_bottom: float) -> void:
	#var total: float = max(1.0, split.size.y)
	#var desired: int = int(total * clamp(fraction_top, 0.0, 1.0))
	#var min_off: int = int(min_top)
	#var max_off: int = int(total - min_bottom)
	#split.split_offset = clamp(desired, min_off, max_off)

#func _assert_two_children(split: SplitContainer) -> void:
	#if split == null: return
	#if split.get_child_count() != 2:
		#push_warning("%s should have exactly 2 children, has %d" % [split.name, split.get_child_count()])

func _on_builder_settings_pressed() -> void:
	print("Pressed settings button")
	if settings_window:
		if builder_view:
			settings_window.set_current_values(builder_view.cell_size, preview_fps, export_repo_path)
		settings_window.popup_centered()

func _on_settings_applied(grid_cell_size: int, preview_fps_new: float, repo_path: String) -> void:
	# Save repo path (even if empty)
	export_repo_path = repo_path

	if builder_view:
		builder_view.cell_size = grid_cell_size
		builder_view._update_grid_dims()
		builder_view.queue_redraw()
		# No _emit_sequences() here

	# Apply to preview
	preview_fps = preview_fps_new
	_on_builder_sequences_changed(builder_view.get_row_sequences())

	# Optional: persist in ProjectModel (see next section)
	if repo_path != "":
		ProjectModel.set_export_repo(repo_path)


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

func _on_files_dropped(files: PackedStringArray) -> void:
	var imgs: Array[String] = []
	for f in files:
		var ext := f.get_extension().to_lower()
		if ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "webp":
			imgs.append(f)
	if imgs.is_empty():
		return
	var ok := ProjectModel.import_sprites(imgs)
	if ok != OK:
		_notify("Failed to import some sprites (code %d)." % ok)
	_refresh_sprite_list()

func _setup_sprite_list() -> void:
	if list_sprites == null:
		return
	# Nice grid of thumbnails:
	list_sprites.icon_mode = ItemList.ICON_MODE_TOP       # icon above text
	list_sprites.same_column_width = true
	list_sprites.fixed_icon_size = Vector2i(sprite_icon_size, sprite_icon_size)
	list_sprites.max_columns = 0                           # auto columns
	list_sprites.allow_reselect = true


func _refresh_sprite_list() -> void:
	if list_sprites == null: return
	list_sprites.clear()

	if ProjectModel.project_dir == "":
		push_warning("No project open; cannot list sprites.")
		return

	var rel_paths: Array[String] = ProjectModel.get_sprites()
	if rel_paths.is_empty():
		drag_indicator_lable.show()
		#list_sprites.add_item("(no sprites yet)")
		return
	else:
		drag_indicator_lable.hide()

	for rel in rel_paths:
		var abs := ProjectModel.project_dir.path_join(rel)
		var tex := _thumb_from_path(abs, sprite_icon_size)
		var label := rel.get_file()
		var idx := list_sprites.add_item(label)
		list_sprites.set_item_metadata(idx, rel)   # <-- this line is essential
		if tex != null:
			list_sprites.set_item_icon(idx, tex)
			
func _sprite_abs_path(rel: String) -> String:
	# rel e.g. "assets/sprites/hero_idle.png"
	return ProjectModel.project_dir.path_join(rel)

func _thumb_from_path(abs: String, box: int) -> Texture2D:
	var img := Image.new()
	var err: int = img.load(abs)
	if err != OK:
		return null

	# Keep aspect; fit longest side into 'box'
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
	# lightweight notification; wire to an AcceptDialog if you already have one
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
	frames.set_animation_speed(anim_name, preview_fps)  # or 8.0
	frames.set_animation_loop(anim_name, true)

	for rel in first_seq:
		var tex: Texture2D = _texture_from_sprite_rel(String(rel))
		if tex != null:
			frames.add_frame(anim_name, tex)

	preview_sprite.sprite_frames = frames
	preview_sprite.animation = anim_name
	preview_sprite.play()
	# IMPORTANT: do NOT call ProjectModel.set_sequences_from_builder(sequences) here
	
	
func _texture_from_sprite_rel(rel: String) -> Texture2D:
	var abs: String = ProjectModel.project_dir.path_join(rel)
	var img := Image.new()
	var err: int = img.load(abs)
	if err != OK:
		return null
	return ImageTexture.create_from_image(img)
	
func _on_export_pressed() -> void:
	# --- 1) Ensure repo path is set ---
	var repo := export_repo_path

	if repo == "":
		var msg := "Export failed: Please set a Godot project folder (repo path) in Settings before exporting."
		_notify(msg)
		if lbl_export_status:
			lbl_export_status.text = msg
		return

	# Persist into ProjectModel
	ProjectModel.set_export_repo(repo)

	# --- 2) Determine animation name ---
	var anim_name = ProjectModel.data.get("current_animation", "")
	if anim_name == "":
		if le_anim_name:
			anim_name = le_anim_name.text.strip_edges()
		if anim_name == "":
			anim_name = "default"

	# --- 3) Build animation data from the grid (BuilderView) ---
	if builder_view == null:
		var msg2 := "Export failed: BuilderView is missing."
		_notify(msg2)
		if lbl_export_status:
			lbl_export_status.text = msg2
		return

	# BuilderView.gd must have:
	# func build_animation_data() -> Dictionary:
	#     return {"sequences": get_row_sequences()}
	var anim_data = builder_view.build_animation_data()
	anim_data["name"] = anim_name

	# If there are literally no frames, fail early with a clear message
	var seqs: Array = anim_data.get("sequences", [])
	if seqs.is_empty():
		var msg3 := "Export failed: current grid has no sequences/frames to export."
		_notify(msg3)
		if lbl_export_status:
			lbl_export_status.text = msg3
		return

	# --- 4) Update ProjectModel with this animation and mark it current ---
	ProjectModel.set_animation(anim_name, anim_data)

	# --- 5) Run the exporter ---
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
