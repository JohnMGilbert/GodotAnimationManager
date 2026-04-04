extends Control
const PreviewControllerScript = preload("res://Scenes/PreviewController.gd")
const WorkspaceTheme = preload("res://Assets/theme_1.tres")
const UiThemeScalerScript = preload("res://ProjectSettings/UiThemeScaler.gd")

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

const ASSET_TAB_BORDER_RAISED := Color(1, 1, 1, 0.34)
const ASSET_TAB_BORDER_PRESSED := Color(0, 0, 0, 0.28)
const ASSET_TAB_SHADOW_RAISED := Color(0, 0, 0, 0.14)
const ASSET_TAB_SHADOW_PRESSED := Color(0, 0, 0, 0.08)
const ASSET_TAB_BASE_PLATE := Color(0.278431, 0.0431373, 0.145098, 1)
const ASSET_TAB_BASE_PLATE_BORDER := Color(0, 0, 0, 0.32)
const ASSET_TAB_ICON_RAISED := Color(0.152941, 0.160784, 0.160784, 1)
const ASSET_TAB_ICON_PRESSED := Color(0.152941, 0.160784, 0.160784, 0.70)
const SPRITE_CONTEXT_DELETE_ID := 1

# Editor-state file (lives alongside the .aam in the project dir)
const EDITOR_STATE_FILE := ".aam_editor.json"

@export_range(32.0, 240.0, 1.0) var asset_tab_width: float = 58.0
@export_range(32.0, 240.0, 1.0) var asset_tab_height: float = 64.0
@export_range(4.0, 24.0, 1.0) var asset_tab_depth_released: float = 8.0
@export_range(1.0, 24.0, 1.0) var asset_tab_depth_pressed: float = 4.0

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
@onready var tab_sprites_shell: Control = %TabShell_Sprites
@onready var tab_sound_shell: Control = %TabShell_Sound
@onready var tab_sprites_shadow: Panel = %PanelShadow_Sprites
@onready var tab_sound_shadow: Panel = %PanelShadow_Sound
@onready var tab_sprites_panel: PanelContainer = %PanelContainer_SpritesTab
@onready var tab_sound_panel: PanelContainer = %PanelContainer_SoundTab
@onready var tab_sprites_btn: TextureButton   = %Tab_Sprites
@onready var tab_sound_btn: TextureButton     = %Tab_Sound
@onready var tab_buttons: Array[TextureButton] = []
@onready var tab_shells: Array[Control] = []
@onready var tab_shadows: Array[Panel] = []
@onready var tab_panels: Array[PanelContainer] = []
var _asset_tab_style_raised: StyleBoxFlat
var _asset_tab_style_pressed: StyleBoxFlat
var _asset_tab_shadow_style: StyleBoxFlat

# Sprites UI
@onready var list_sprites: ItemList      = %List_Sprites
@onready var btn_import_sprites: Button  = %Btn_ImportSprites
@onready var fd_import_sprites: FileDialog = $FD_Import_Sprites
@onready var drag_indicator_lable: Label = %DragIndicatorLabel
@onready var sprite_asset_context_menu: PopupMenu = %SpriteAssetContextMenu
@onready var win_delete_sprite_confirm: Window = %DeleteSpriteConfirm
@onready var lbl_delete_sprite_message: Label = %Label_Message
@onready var btn_delete_sprite_cancel: Button = %Btn_DeleteSpriteCancel
@onready var btn_delete_sprite_confirm: Button = %Btn_DeleteSpriteConfirm

# --- SOUND UI (mirrors sprite tab) ---
@onready var list_sound: ItemList        = %List_Sound
@onready var btn_import_sound: Button    = %Btn_ImportSound
@onready var fd_import_sound: FileDialog = $FD_Import_Sound
@onready var drag_indicator_sound_label: Label = %DragIndicatorLabel_Sound

@onready var builder_view: Node = %BuilderView          # Should be a BuilderGrid
@onready var preview_view: Control = %PreviewView
@onready var preview_sprite: AnimatedSprite2D = %PreviewSprite

@onready var btn_builder_settings: TextureButton = %Btn_BuilderSettings
@onready var settings_window: SettingsWindow = %SettingsWindow

@onready var le_anim_name: LineEdit = %LineEdit_AnimName

@onready var rb_json: CheckBox = %CheckBox
@onready var rb_tres: CheckBox = %CheckBox2
@onready var rb_tscn: CheckBox = %CheckBox3

@onready var cb_trim: CheckBox = %CheckBox_Trim
@onready var cb_rename: CheckBox = %CheckBox_Rename
@onready var cb_overwrite: CheckBox = %CheckBox_Overwrite

@onready var btn_export: Button = %Btn_Export
@onready var lbl_export_status: Label = %Label_Export_Status
@onready var inspector_section_animation_info: Button = %SectionButton_AnimationInfo
@onready var inspector_section_playback: Button = %SectionButton_PlaybackSettings
@onready var inspector_section_sound: Button = %SectionButton_SoundSettings
@onready var inspector_section_metadata: Button = %SectionButton_Metadata
@onready var inspector_section_destination: Button = %SectionButton_Destination
@onready var inspector_section_anim_name: Button = %SectionButton_AnimName
@onready var inspector_section_format: Button = %SectionButton_Format
@onready var inspector_section_options: Button = %SectionButton_Options

@onready var inspector_content_animation_info: Control = %SectionContent_AnimationInfo
@onready var inspector_content_playback: Control = %SectionContent_PlaybackSettings
@onready var inspector_content_sound: Control = %SectionContent_SoundSettings
@onready var inspector_content_metadata: Control = %SectionContent_Metadata
@onready var inspector_content_destination: Control = %SectionContent_Destination
@onready var inspector_content_anim_name: Control = %SectionContent_AnimName
@onready var inspector_content_format: Control = %SectionContent_Format
@onready var inspector_content_options: Control = %SectionContent_Options

var preview_fps: float = 8.0
var export_repo_path: String = ""   # Godot project / destination repo

@export var sprite_icon_size: int = 96   # size of sprite thumbnails in the list
@export var sprite_label_font_size: int = 14
@export_range(4, 64, 1) var delete_sprite_name_max_length: int = 24

@onready var btn_eraser: TextureButton = %EraseBtn
var eraser_active: bool = false

@onready var builder_overlay: BuilderOverlay = %BuilderOverlay

# AUDIO STUFF
@onready var preview_audio: AudioStreamPlayer = %PreviewAudio
@onready var btn_preview_playpause: TextureButton = %Btn_PreviewPlayPause
@onready var btn_preview_loop: TextureButton = %Btn_PreviewLoop
const SpritesheetUtils = preload("res://SpritesheetUtils.gd")
var preview_controller: PreviewController = null

@onready var dlg_sheet: SpritesheetDialog = %SpritesheetDialog

# Sprite tag filter + tag editing
@onready var filter_sprites: OptionButton = %Filter_Sprites
@onready var btn_add_tags: Button         = %Btn_AddTags
@onready var opt_existing_tags: OptionButton = %Option_ExistingTags

@onready var win_add_tag: Window          = %Win_AddTag
@onready var edit_tag_name: LineEdit      = %LineEdit_TagName
@onready var lbl_tag_exists: Label        = %Label_TagExists
@onready var btn_tag_submit: Button       = %Btn_TagSubmit
@onready var btn_tag_cancel: Button       = %Btn_TagCancel
var current_sprite_tag_filter: String = ""      # "" = no filter / All
var _pending_tag_asset_ids: PackedStringArray = PackedStringArray()
var _pending_delete_sprite_asset_ids: PackedStringArray = PackedStringArray()
var _base_workspace_theme: Theme
var _scaled_workspace_theme: Theme

func _ready() -> void:
	# Let the root fill the window, but DO NOT touch child mins or splits
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(_on_workspace_resized)
	call_deferred("_apply_workspace_window_mode")
	_base_workspace_theme = WorkspaceTheme
	_apply_ui_scale(AppState.get_ui_scale())

	tab_buttons = [tab_sprites_btn, tab_sound_btn]
	tab_shells = [tab_sprites_shell, tab_sound_shell]
	tab_shadows = [tab_sprites_shadow, tab_sound_shadow]
	tab_panels = [tab_sprites_panel, tab_sound_panel]
	_build_asset_tab_styles()
	_apply_asset_tab_depth()
	_connect_asset_tabs()
	_select_asset_tab(0)

	_wire_sprite_import_ui()
	_wire_sound_import_ui()
	_setup_inspector_dropdowns()

	_setup_sprite_list()
	_setup_sound_list()
	_setup_sprite_asset_context_menu()

	_refresh_sprite_list()
	_refresh_sound_list()

	_setup_sprite_list()
	_setup_sound_list()

	_refresh_sprite_list()
	_refresh_sound_list()

	if filter_sprites:
		filter_sprites.item_selected.connect(_on_Filter_Sprites_item_selected)
		_refresh_sprite_tag_filter_options()

	if btn_add_tags:
		btn_add_tags.pressed.connect(_on_Btn_AddTags_pressed)

	if btn_tag_cancel:
		btn_tag_cancel.pressed.connect(func() -> void:
			win_add_tag.hide()
		)

	if win_add_tag:
		win_add_tag.close_requested.connect(func() -> void:
			win_add_tag.hide()
		)

	if btn_tag_submit:
		btn_tag_submit.pressed.connect(_on_Btn_TagSubmit_pressed)

	if list_sprites:
		list_sprites.gui_input.connect(_on_list_sprites_gui_input)

	if edit_tag_name:
		edit_tag_name.text_changed.connect(_on_TagName_text_changed)
	
	if dlg_sheet:
		dlg_sheet.decided.connect(_on_spritesheet_decided)

	var win := get_window()
	if win:
		win.files_dropped.connect(_on_os_files_dropped)

	if builder_view:
		preview_controller = PreviewControllerScript.new()
		preview_controller.setup(preview_view, preview_sprite, preview_audio, builder_view as BuilderGrid)
		builder_view.sequences_changed.connect(_on_builder_sequences_changed)
		_on_builder_sequences_changed(builder_view.get_row_sequences())

	if btn_builder_settings:
		btn_builder_settings.pressed.connect(_on_builder_settings_pressed)

	if settings_window:
		settings_window.settings_applied.connect(_on_settings_applied)
		settings_window.theme = _scaled_workspace_theme

	if btn_export:
		btn_export.pressed.connect(_on_export_pressed)

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
		
	if opt_existing_tags:
		opt_existing_tags.item_selected.connect(_on_ExistingTag_item_selected)

	if sprite_asset_context_menu:
		sprite_asset_context_menu.id_pressed.connect(_on_sprite_asset_context_menu_id_pressed)

	if btn_delete_sprite_cancel:
		btn_delete_sprite_cancel.pressed.connect(_on_delete_sprite_cancel_pressed)

	if btn_delete_sprite_confirm:
		btn_delete_sprite_confirm.pressed.connect(_on_delete_sprite_confirm_pressed)

	if win_delete_sprite_confirm:
		win_delete_sprite_confirm.close_requested.connect(_on_delete_sprite_cancel_pressed)
	# Load editor state (animations + settings) from the editor-state file
	_load_editor_state()
	call_deferred("_apply_workspace_layout")
	if not AppState.ui_scale_changed.is_connected(_on_app_ui_scale_changed):
		AppState.ui_scale_changed.connect(_on_app_ui_scale_changed)
	
		## FORCE-ENABLE MASTER BUS FOR DEBUG
	#var master_idx := AudioServer.get_bus_index("Master")
	#if master_idx >= 0:
		#AudioServer.set_bus_mute(master_idx, false)
		#AudioServer.set_bus_volume_db(master_idx, 0.0)
		#print("[AUDIO DEBUG] Master bus forced to 0 dB and unmuted.")


func _on_workspace_resized() -> void:
	call_deferred("_apply_workspace_layout")


func _setup_inspector_dropdowns() -> void:
	var sections: Array[Array] = [
		[inspector_section_animation_info, inspector_content_animation_info, "Animation Info"],
		[inspector_section_playback, inspector_content_playback, "Playback Settings"],
		[inspector_section_sound, inspector_content_sound, "Sound Settings"],
		[inspector_section_metadata, inspector_content_metadata, "Metadata"],
		[inspector_section_destination, inspector_content_destination, "Destination"],
		[inspector_section_anim_name, inspector_content_anim_name, "Animation Name"],
		[inspector_section_format, inspector_content_format, "Export Format"],
		[inspector_section_options, inspector_content_options, "Options"],
	]

	for section in sections:
		var button := section[0] as Button
		var content := section[1] as Control
		var label := String(section[2])
		if button == null or content == null:
			continue

		button.toggle_mode = true
		button.button_pressed = false
		var toggle_callable := Callable(self, "_on_inspector_section_toggled").bind(button, content, label)
		if not button.toggled.is_connected(toggle_callable):
			button.toggled.connect(toggle_callable)
		_set_inspector_section_state(button, content, label, false)


func _on_inspector_section_toggled(pressed: bool, button: Button, content: Control, label: String) -> void:
	_set_inspector_section_state(button, content, label, pressed)


func _set_inspector_section_state(button: Button, content: Control, label: String, is_open: bool) -> void:
	if button == null or content == null:
		return
	button.text = "%s %s" % ["v" if is_open else ">", label]
	content.visible = is_open


func _apply_workspace_window_mode() -> void:
	var window := get_window()
	if window == null:
		return
	window.mode = Window.MODE_MAXIMIZED


func _apply_workspace_layout() -> void:
	_apply_split_fraction(vs_main_assets, MAIN_VS_FRACTION_TOP)
	_apply_split_fraction(hs_edit_sidebar, HS_FRACTION_LEFT)
	_apply_split_fraction(vs_preview_inspector, RIGHT_VS_FRACTION_TOP)

	if assets_tabbar:
		assets_tabbar.custom_minimum_size.x = ASSETS_TABBAR_MIN


func _apply_split_fraction(split: SplitContainer, fraction: float) -> void:
	if split == null:
		return

	var axis_size := split.size.x if split is HSplitContainer else split.size.y
	if axis_size <= 0.0:
		return

	var clamped_fraction := clampf(fraction, 0.1, 0.9)
	var target := int(round(axis_size * clamped_fraction))
	split.split_offset = target - int(round(axis_size * 0.5))


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
	var sounds: Array[String] = []

	for f in files:
		var ext := f.get_extension().to_lower()
		match ext:
			"png", "jpg", "jpeg", "webp":
				# Detect if this looks like a spritesheet
				if SpritesheetUtils.looks_like_spritesheet(f):
					# Ask the user if/how to split it
					_prompt_spritesheet_import(f)
				else:
					# Normal single-image import
					var err_img := ProjectModel.import_sprites([f])
					if err_img != OK:
						_notify("Failed to import sprite %s (code %d)." % [f, err_img])

			"wav", "ogg", "mp3", "flac":
				sounds.append(f)

			_:
				pass

	# Import audio as before
	if not sounds.is_empty():
		var err_snd := ProjectModel.import_audio(sounds)
		if err_snd != OK:
			_notify("Failed to import some audio files from OS drop (code %d)." % err_snd)

	_refresh_sprite_list()
	_refresh_sound_list()


# --- Helpers (assume exactly two children) ---
func _child_ctrl(split: SplitContainer, idx: int) -> Control:
	var c := split.get_child(idx)
	return c as Control


func _on_builder_settings_pressed() -> void:
	print("Pressed settings button")
	if settings_window:
		if builder_view:
			settings_window.set_current_values(builder_view.cell_size, preview_fps, export_repo_path, AppState.get_ui_scale())
		settings_window.popup_centered()

func _on_eraser_pressed() -> void:
	eraser_active = btn_eraser.button_pressed

	var grid := builder_view as BuilderGrid
	if grid:
		grid.set_erase_mode(eraser_active)

func _on_preview_playpause_pressed() -> void:
	if preview_controller:
		preview_controller.set_playing(btn_preview_playpause.button_pressed)


func _on_preview_loop_pressed() -> void:
	if preview_controller:
		preview_controller.set_loop_enabled(btn_preview_loop.button_pressed)
	ProjectModel.set_export_playback(preview_fps, btn_preview_loop.button_pressed if btn_preview_loop else true)


func _on_settings_applied(grid_cell_size: int, preview_fps_new: float, repo_path: String, ui_scale: float) -> void:
	# Save repo path (even if empty)
	export_repo_path = repo_path

	if builder_view:
		builder_view.cell_size = grid_cell_size
		builder_view._update_grid_dims()
		builder_view.queue_redraw()

	# Apply to preview
	preview_fps = preview_fps_new
	if preview_controller:
		preview_controller.set_preview_fps(preview_fps)
	_on_builder_sequences_changed(builder_view.get_row_sequences())
	ProjectModel.set_export_playback(preview_fps, btn_preview_loop.button_pressed if btn_preview_loop else true)

	# Persist export repo in ProjectModel
	if repo_path != "":
		ProjectModel.set_export_repo(repo_path)

	AppState.set_ui_scale(ui_scale)

	save_editor_state()

func _on_app_ui_scale_changed(ui_scale: float) -> void:
	_apply_ui_scale(ui_scale)

func _apply_ui_scale(ui_scale: float) -> void:
	_scaled_workspace_theme = UiThemeScalerScript.build_scaled_theme(_base_workspace_theme, ui_scale)
	if _scaled_workspace_theme == null:
		return
	theme = _scaled_workspace_theme
	_apply_scaled_theme_to_subtree(self)
	if settings_window:
		settings_window.theme = _scaled_workspace_theme
		if settings_window.fd_repo_dir:
			settings_window.fd_repo_dir.theme = _scaled_workspace_theme

func _apply_scaled_theme_to_subtree(node: Node) -> void:
	if node == null:
		return

	if node is Control:
		var control := node as Control
		control.theme = _scaled_workspace_theme
	elif node is Window:
		var window := node as Window
		window.theme = _scaled_workspace_theme

	for child in node.get_children():
		_apply_scaled_theme_to_subtree(child)

func _prompt_spritesheet_import(path: String) -> void:
	var img := Image.new()
	if img.load(path) != OK:
		# fallback: plain import
		var err := ProjectModel.import_sprites([path])
		if err != OK:
			_notify("Failed to import sprite %s (code %d)" % [path, err])
		_refresh_sprite_list()
		return

	dlg_sheet.popup_for_sheet(path, img.get_width(), img.get_height())


func _on_spritesheet_decided(sheet_path: String, split: bool, cols: int, rows: int, tag_all: String) -> void:
	if sheet_path == "":
		return

	if split:
		var err := ProjectModel.import_sprites_from_sheet(sheet_path, cols, rows, tag_all)
		if err != OK:
			_notify("Spritesheet import failed (code %d)" % err)
	else:
		var err2 := ProjectModel.import_sprites([sheet_path])
		if err2 != OK:
			_notify("Image import failed (code %d)" % err2)

	_refresh_sprite_list()

func _connect_asset_tabs() -> void:
	for i in tab_buttons.size():
		var b: TextureButton = tab_buttons[i]
		b.toggle_mode = true
		b.button_pressed = false
		b.pressed.connect(func(idx := i) -> void:
			_select_asset_tab(idx))

	for i in tab_panels.size():
		var panel: PanelContainer = tab_panels[i]
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.gui_input.connect(func(event: InputEvent, idx := i) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_select_asset_tab(idx))

	for i in tab_shells.size():
		var shell: Control = tab_shells[i]
		shell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		shell.gui_input.connect(func(event: InputEvent, idx := i) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_select_asset_tab(idx))


func _build_asset_tab_styles() -> void:
	var base_style := tab_sprites_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if base_style == null:
		base_style = StyleBoxFlat.new()

	_asset_tab_style_raised = _make_asset_tab_style(base_style, false)
	_asset_tab_style_pressed = _make_asset_tab_style(base_style, true)
	_asset_tab_shadow_style = _make_asset_tab_shadow_style(base_style)


func _apply_asset_tab_depth() -> void:
	var released_depth_y := asset_tab_depth_released
	var released_depth_x = round(asset_tab_depth_released * 0.75)
	var pressed_depth_y = min(asset_tab_depth_pressed, asset_tab_depth_released)
	var pressed_depth_x = round(pressed_depth_y * 0.75)
	var max_depth_y = max(released_depth_y, pressed_depth_y)
	var max_depth_x = max(released_depth_x, pressed_depth_x)

	for shell in tab_shells:
		shell.custom_minimum_size = Vector2(
			asset_tab_width + max_depth_x,
			asset_tab_height + max_depth_y
		)


func _make_asset_tab_style(base_style: StyleBoxFlat, is_selected: bool) -> StyleBoxFlat:
	var style := base_style.duplicate() as StyleBoxFlat
	if style == null:
		style = StyleBoxFlat.new()

	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2

	if is_selected:
		style.bg_color = base_style.bg_color.lightened(0.16)
		style.border_color = ASSET_TAB_BORDER_RAISED
		style.shadow_color = ASSET_TAB_SHADOW_RAISED
		style.shadow_size = 2
		style.shadow_offset = Vector2(1, 1)
		style.content_margin_left = 1
		style.content_margin_top = 0
		style.content_margin_right = 0
		style.content_margin_bottom = 2
	else:
		style.bg_color = base_style.bg_color.darkened(0.18)
		style.border_color = ASSET_TAB_BORDER_PRESSED
		style.shadow_color = ASSET_TAB_SHADOW_PRESSED
		style.shadow_size = 0
		style.shadow_offset = Vector2.ZERO
		style.content_margin_left = 0
		style.content_margin_top = 2
		style.content_margin_right = 1
		style.content_margin_bottom = 0

	return style


func _make_asset_tab_shadow_style(base_style: StyleBoxFlat) -> StyleBoxFlat:
	var style := base_style.duplicate() as StyleBoxFlat
	if style == null:
		style = StyleBoxFlat.new()

	style.bg_color = ASSET_TAB_BASE_PLATE
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = ASSET_TAB_BASE_PLATE_BORDER
	style.shadow_color = Color(0, 0, 0, 0)
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	return style


func _select_asset_tab(index: int) -> void:
	var max_index: int = assets_tabs.get_tab_count() - 1
	index = clamp(index, 0, max_index)
	var released_depth_y := asset_tab_depth_released
	var released_depth_x = round(asset_tab_depth_released * 0.75)
	var pressed_depth_y = min(asset_tab_depth_pressed, asset_tab_depth_released)
	var pressed_depth_x = round(pressed_depth_y * 0.75)
	var max_depth_y = max(released_depth_y, pressed_depth_y)
	var max_depth_x = max(released_depth_x, pressed_depth_x)

	for j in tab_buttons.size():
		var btn := tab_buttons[j]
		btn.button_pressed = (j == index)
		btn.modulate = ASSET_TAB_ICON_PRESSED if j == index else ASSET_TAB_ICON_RAISED

		var tab_panel := tab_panels[j] if j < tab_panels.size() else btn.get_parent() as PanelContainer
		if tab_panel:
			if j == index:
				_set_asset_tab_face_depth(tab_panel, max_depth_x, max_depth_y, pressed_depth_x, pressed_depth_y)
				tab_panel.add_theme_stylebox_override("panel", _asset_tab_style_pressed)
			else:
				_set_asset_tab_face_depth(tab_panel, max_depth_x, max_depth_y, released_depth_x, released_depth_y)
				tab_panel.add_theme_stylebox_override("panel", _asset_tab_style_raised)

		if j < tab_shadows.size():
			tab_shadows[j].add_theme_stylebox_override("panel", _asset_tab_shadow_style)
			_set_asset_tab_shadow_depth(tab_shadows[j], released_depth_x, released_depth_y)

	assets_tabs.current_tab = index
	print("Index for asset tab is: ", index)


func _set_asset_tab_shadow_depth(shadow: Panel, depth_x: float, depth_y: float) -> void:
	shadow.offset_left = 0.0
	shadow.offset_top = 0.0
	shadow.offset_right = -depth_x
	shadow.offset_bottom = -depth_y


func _set_asset_tab_face_depth(tab_panel: PanelContainer, max_depth_x: float, max_depth_y: float, face_depth_x: float, face_depth_y: float) -> void:
	tab_panel.offset_left = -face_depth_x
	tab_panel.offset_top = -face_depth_y
	tab_panel.offset_right = -(max_depth_x + face_depth_x)
	tab_panel.offset_bottom = -(max_depth_y + face_depth_y)

# TAGS
func _normalize_tag_input(raw: String) -> String:
	var t := raw.strip_edges().to_lower()
	if t == "":
		return ""
	# collapse multiple spaces
	var parts := t.split(" ", true, 0)
	var filtered: Array = []
	for p in parts:
		if p.strip_edges() != "":
			filtered.append(p)
	return " ".join(filtered)

func _refresh_existing_tags_option_button() -> void:
	if opt_existing_tags == null:
		return

	opt_existing_tags.clear()
	opt_existing_tags.add_item("Use existing tag...")  # index 0

	var tags := ProjectModel.get_all_tags()
	for t in tags:
		opt_existing_tags.add_item(t)

	opt_existing_tags.select(0)
	
func _on_ExistingTag_item_selected(index: int) -> void:
	if opt_existing_tags == null:
		return

	if index <= 0:
		return  # "Use existing tag..." placeholder

	var tag_text := opt_existing_tags.get_item_text(index)
	edit_tag_name.text = tag_text
	_update_tag_name_feedback(tag_text)


func _get_selected_sprite_asset_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	if list_sprites == null:
		return ids

	var selected := list_sprites.get_selected_items()
	for idx in selected:
		var meta = list_sprites.get_item_metadata(idx)
		var asset_id := String(meta)
		if asset_id != "":
			ids.append(asset_id)
	return ids
	
func _refresh_sprite_tag_filter_options() -> void:
	if filter_sprites == null:
		return

	var prev := current_sprite_tag_filter

	filter_sprites.clear()
	filter_sprites.add_item("All sprites")  # index 0

	var tags := ProjectModel.get_all_tags()
	for t in tags:
		filter_sprites.add_item(t)

	# try to preserve selection if possible
	var selected_index := 0
	if prev != "":
		for i in range(1, filter_sprites.item_count):
			if filter_sprites.get_item_text(i) == prev:
				selected_index = i
				break

	filter_sprites.select(selected_index)
	if selected_index == 0:
		current_sprite_tag_filter = ""
	else:
		current_sprite_tag_filter = filter_sprites.get_item_text(selected_index)
	
func _on_Filter_Sprites_item_selected(index: int) -> void:
	if filter_sprites == null:
		return

	if index == 0:
		current_sprite_tag_filter = ""
	else:
		current_sprite_tag_filter = filter_sprites.get_item_text(index)

	_refresh_sprite_list()
	
	
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
	for f in files:
		if SpritesheetUtils.looks_like_spritesheet(f):
			# Show the spritesheet dialog for this file
			_prompt_spritesheet_import(f)
		else:
			# Regular image import
			var ok := ProjectModel.import_sprites([f])
			if ok != OK:
				_notify("Failed to import sprite %s (code %d)." % [f, ok])

	_refresh_sprite_list()


func _setup_sprite_list() -> void:
	if list_sprites == null:
		return
	list_sprites.icon_mode = ItemList.ICON_MODE_TOP
	list_sprites.same_column_width = true
	list_sprites.fixed_icon_size = Vector2i(sprite_icon_size, sprite_icon_size)
	list_sprites.max_columns = 0
	list_sprites.allow_reselect = true
	list_sprites.add_theme_font_size_override("font_size", sprite_label_font_size)


func _setup_sprite_asset_context_menu() -> void:
	if sprite_asset_context_menu == null:
		return

	sprite_asset_context_menu.clear()
	sprite_asset_context_menu.add_item("Delete", SPRITE_CONTEXT_DELETE_ID)


func _refresh_sprite_list() -> void:
	if list_sprites == null:
		return

	list_sprites.clear()

	if ProjectModel.project_dir == "":
		push_warning("No project open; cannot list sprites.")
		if drag_indicator_lable:
			drag_indicator_lable.show()
		return

	var rel_paths: Array[String] = ProjectModel.get_sprites()
	var shown := 0

	for rel in rel_paths:
		var asset_id := rel   # relative path is the tag key

		# Filter by tag if one is selected
		if current_sprite_tag_filter != "":
			var tags := ProjectModel.get_asset_tags(asset_id)
			if not tags.has(current_sprite_tag_filter):
				continue

		var abs := ProjectModel.project_dir.path_join(rel)
		var tex := _thumb_from_path(abs, sprite_icon_size)
		var label := rel.get_file()
		var idx := list_sprites.add_item(label)
		list_sprites.set_item_metadata(idx, asset_id)
		if tex != null:
			list_sprites.set_item_icon(idx, tex)
		shown += 1

	if drag_indicator_lable:
		if shown == 0:
			drag_indicator_lable.show()
		else:
			drag_indicator_lable.hide()


func _on_list_sprites_gui_input(event: InputEvent) -> void:
	if list_sprites == null or sprite_asset_context_menu == null:
		return
	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_RIGHT or not mouse_event.pressed:
		return

	var item_index := list_sprites.get_item_at_position(mouse_event.position, true)
	if item_index < 0:
		return

	var asset_id := String(list_sprites.get_item_metadata(item_index))
	if asset_id == "":
		return

	var selected_asset_ids := _get_selected_sprite_asset_ids()
	if selected_asset_ids.is_empty() or not list_sprites.is_selected(item_index):
		list_sprites.deselect_all()
		list_sprites.select(item_index)
		selected_asset_ids = PackedStringArray([asset_id])

	_pending_delete_sprite_asset_ids = selected_asset_ids
	sprite_asset_context_menu.position = Vector2i(mouse_event.global_position)
	sprite_asset_context_menu.popup()


func _on_sprite_asset_context_menu_id_pressed(id: int) -> void:
	if id != SPRITE_CONTEXT_DELETE_ID:
		return
	if _pending_delete_sprite_asset_ids.is_empty():
		return

	if lbl_delete_sprite_message:
		if _pending_delete_sprite_asset_ids.size() > 1:
			lbl_delete_sprite_message.text = "Delete \"Multiple sprites\"?\n\nThese assets will be removed from the entire project."
		else:
			var asset_name := _truncate_display_name(_pending_delete_sprite_asset_ids[0].get_file())
			lbl_delete_sprite_message.text = "Delete \"%s\"?\n\nThis asset will be removed from the entire project." % asset_name

	if win_delete_sprite_confirm:
		win_delete_sprite_confirm.popup_centered()


func _on_delete_sprite_cancel_pressed() -> void:
	if win_delete_sprite_confirm:
		win_delete_sprite_confirm.hide()
	_pending_delete_sprite_asset_ids = PackedStringArray()


func _on_delete_sprite_confirm_pressed() -> void:
	if _pending_delete_sprite_asset_ids.is_empty():
		_on_delete_sprite_cancel_pressed()
		return

	var failed_asset_id := ""
	var failed_err := OK
	for asset_id in _pending_delete_sprite_asset_ids:
		var err := ProjectModel.delete_sprite_asset(asset_id)
		if err != OK:
			failed_asset_id = asset_id
			failed_err = err
			break

		if builder_overlay:
			builder_overlay.remove_sprite_asset_references(asset_id)

	if failed_err != OK:
		_notify("Failed to delete sprite %s (code %d)." % [failed_asset_id, failed_err])
		return

	_refresh_sprite_tag_filter_options()
	_refresh_sprite_list()

	if builder_view:
		_on_builder_sequences_changed(builder_view.get_row_sequences())

	save_editor_state()
	_on_delete_sprite_cancel_pressed()


func _truncate_display_name(name: String) -> String:
	var max_length := maxi(delete_sprite_name_max_length, 4)
	if name.length() <= max_length:
		return name
	return name.substr(0, max_length - 3) + "..."

func _on_Btn_AddTags_pressed() -> void:
	var asset_ids := _get_selected_sprite_asset_ids()
	if asset_ids.is_empty():
		_notify("Select one or more sprites first to add a tag.")
		return

	_pending_tag_asset_ids = asset_ids
	edit_tag_name.text = ""
	_update_tag_name_feedback("")
	_refresh_existing_tags_option_button()

	# Optional: update window title to show count
	if _pending_tag_asset_ids.size() == 1:
		win_add_tag.title = "Add Tag"
	else:
		win_add_tag.title = "Add Tag to %d sprites" % _pending_tag_asset_ids.size()

	win_add_tag.popup_centered()
	edit_tag_name.grab_focus()
	
func _on_TagName_text_changed(new_text: String) -> void:
	_update_tag_name_feedback(new_text)

func _update_tag_name_feedback(raw: String) -> void:
	if lbl_tag_exists == null or edit_tag_name == null:
		return

	var norm := _normalize_tag_input(raw)
	if norm == "":
		lbl_tag_exists.hide()
		edit_tag_name.remove_theme_color_override("font_color")
		return

	var all_tags := ProjectModel.get_all_tags()
	var exists := all_tags.has(norm)

	if exists:
		lbl_tag_exists.text = "Tag already exists"
		lbl_tag_exists.show()
		edit_tag_name.add_theme_color_override("font_color", Color.RED)
	else:
		lbl_tag_exists.hide()
		edit_tag_name.remove_theme_color_override("font_color")
		
func _on_Btn_TagSubmit_pressed() -> void:
	if _pending_tag_asset_ids.is_empty():
		win_add_tag.hide()
		return

	var norm := _normalize_tag_input(edit_tag_name.text)
	if norm == "":
		win_add_tag.hide()
		return

	var tag_arr := PackedStringArray([norm])

	for asset_id in _pending_tag_asset_ids:
		ProjectModel.add_asset_tags(asset_id, tag_arr)

	_refresh_sprite_tag_filter_options()
	_refresh_sprite_list()

	win_add_tag.hide()
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

func _on_sound_files_selected(files: PackedStringArray) -> void:
	# NOTE: implement ProjectModel.import_audio(files) similar to import_sprites
	var ok = ProjectModel.import_audio(files)
	if ok != OK:
		_notify("Failed to import some audio files (code %d)." % ok)
	_refresh_sound_list()

func _setup_sound_list() -> void:
	if list_sound == null:
		return
	list_sound.icon_mode = ItemList.ICON_MODE_LEFT
	list_sound.same_column_width = false
	list_sound.allow_reselect = true
	list_sound.select_mode = ItemList.SELECT_SINGLE
	list_sound.fixed_icon_size = Vector2i(20, 20)
	list_sound.add_theme_font_size_override("font_size", 13)


func _refresh_sound_list() -> void:
	if list_sound == null:
		return
	list_sound.clear()

	if ProjectModel.project_dir == "":
		push_warning("No project open; cannot list audio.")
		if drag_indicator_sound_label:
			drag_indicator_sound_label.show()
		return

	# NOTE: implement ProjectModel.get_audio() -> Array[String]
	var rel_paths: Array[String] = ProjectModel.get_audio()
	if rel_paths.is_empty():
		if drag_indicator_sound_label:
			drag_indicator_sound_label.show()
		return

	for rel in rel_paths:
		var label := rel.get_file()
		var idx := list_sound.add_item(label)
		list_sound.set_item_metadata(idx, rel)
		# Optional: you could set an icon here (e.g. a generic speaker icon)

	if drag_indicator_sound_label:
		drag_indicator_sound_label.hide()


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
	if preview_controller:
		preview_controller.apply_sequence_preview(sequences)


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
	ProjectModel.set_export_playback(preview_fps, btn_preview_loop.button_pressed if btn_preview_loop else true)

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
	data["preview_loop_enabled"] = btn_preview_loop.button_pressed if btn_preview_loop else true
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
	var preview_loop_enabled := bool(data.get("preview_loop_enabled", true))
	if btn_preview_loop:
		btn_preview_loop.button_pressed = preview_loop_enabled
	if preview_controller:
		preview_controller.set_preview_fps(preview_fps)
		preview_controller.set_playing(btn_preview_playpause.button_pressed if btn_preview_playpause else true)
		preview_controller.set_loop_enabled(preview_loop_enabled)
	ProjectModel.set_export_playback(preview_fps, preview_loop_enabled)

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
