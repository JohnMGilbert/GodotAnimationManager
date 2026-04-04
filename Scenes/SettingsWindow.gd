extends Window
class_name SettingsWindow

signal settings_applied(grid_cell_size: int, preview_fps: float, repo_path: String, ui_scale: float)

@onready var header: Control = get_node_or_null("MarginContainer/PanelContainer/VBoxContainer/Header")
@onready var btn_close: Button = get_node_or_null("MarginContainer/PanelContainer/VBoxContainer/Header/HeaderHBox/Btn_Close")
@onready var spin_cell_size: SpinBox = get_node_or_null("MarginContainer/PanelContainer/VBoxContainer/HBoxContainer/Spin_CellSize")
@onready var spin_preview_fps: SpinBox = get_node_or_null("MarginContainer/PanelContainer/VBoxContainer/HBoxContainer2/Spin_PreviewFPS")
@onready var spin_ui_scale: SpinBox = get_node_or_null("MarginContainer/PanelContainer/VBoxContainer/HBoxContainerUIScale/Spin_UIScale")
@onready var content_vbox: VBoxContainer = get_node_or_null("MarginContainer/PanelContainer/VBoxContainer")
@onready var repo_row: HBoxContainer = get_node_or_null("MarginContainer/PanelContainer/VBoxContainer/HBoxContainerRepo")
@onready var line_repo_path: LineEdit = get_node_or_null("MarginContainer/PanelContainer/VBoxContainer/HBoxContainerRepo/LineEdit_RepoPath")
@onready var btn_browse_repo: Button = get_node_or_null("MarginContainer/PanelContainer/VBoxContainer/HBoxContainerRepo/Btn_BrowseRepo")

@onready var btn_cancel: Button = get_node_or_null("MarginContainer/PanelContainer/VBoxContainer/HBoxContainer3/Btn_SettingsCancel")
@onready var btn_apply: Button = get_node_or_null("MarginContainer/PanelContainer/VBoxContainer/HBoxContainer3/Btn_SettingsApply")
@onready var fd_repo_dir: FileDialog = $FD_RepoDir

var _dragging_window: bool = false
var _drag_offset: Vector2i = Vector2i.ZERO

func _ready() -> void:
	_ensure_ui_scale_row()
	call_deferred("_fit_to_contents")

	fd_repo_dir.theme = theme
	if header:
		header.gui_input.connect(_on_header_gui_input)
	if btn_close:
		btn_close.pressed.connect(_on_cancel_pressed)
	if btn_cancel:
		btn_cancel.pressed.connect(_on_cancel_pressed)
	if btn_apply:
		btn_apply.pressed.connect(_on_apply_pressed)
	close_requested.connect(_on_cancel_pressed)

	# Browse for repo folder
	if btn_browse_repo:
		btn_browse_repo.pressed.connect(func() -> void:
			fd_repo_dir.file_mode = FileDialog.FILE_MODE_OPEN_DIR
			fd_repo_dir.access = FileDialog.ACCESS_FILESYSTEM
			if line_repo_path and line_repo_path.text != "":
				fd_repo_dir.current_dir = line_repo_path.text
			else:
				OS.get_environment("HOME")
			fd_repo_dir.popup_centered_ratio(0.75)
		)

	fd_repo_dir.dir_selected.connect(func(path: String) -> void:
		line_repo_path.text = path
	)

func _on_cancel_pressed() -> void:
	hide()

func _on_apply_pressed() -> void:
	var cell_size: int = int(spin_cell_size.value) if spin_cell_size else 0
	var fps: float = float(spin_preview_fps.value) if spin_preview_fps else 0.0
	var repo: String = line_repo_path.text.strip_edges() if line_repo_path else ""
	var ui_scale: float = float(spin_ui_scale.value) if spin_ui_scale else AppState.get_ui_scale()
	settings_applied.emit(cell_size, fps, repo, ui_scale)
	hide()

func set_current_values(grid_cell_size: int, preview_fps: float, repo_path: String, ui_scale: float) -> void:
	if spin_cell_size:
		spin_cell_size.value = grid_cell_size
	if spin_preview_fps:
		spin_preview_fps.value = preview_fps
	if line_repo_path:
		line_repo_path.text = repo_path
	if spin_ui_scale:
		spin_ui_scale.value = ui_scale

func _ensure_ui_scale_row() -> void:
	if spin_ui_scale != null:
		return
	if content_vbox == null:
		push_warning("SettingsWindow is missing its content VBoxContainer; UI scale control could not be created.")
		return

	var row := HBoxContainer.new()
	row.name = "HBoxContainerUIScale"

	var label := Label.new()
	label.name = "LabelUIScale"
	label.text = "UI Scale"
	row.add_child(label)

	spin_ui_scale = SpinBox.new()
	spin_ui_scale.name = "Spin_UIScale"
	spin_ui_scale.custom_minimum_size = Vector2(120, 0)
	spin_ui_scale.min_value = 0.75
	spin_ui_scale.max_value = 1.75
	spin_ui_scale.step = 0.05
	spin_ui_scale.value = AppState.get_ui_scale()
	row.add_child(spin_ui_scale)

	var hint := Label.new()
	hint.name = "LabelUIScaleHint"
	hint.text = "1.0 = default"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hint)

	if repo_row and repo_row.get_parent() == content_vbox:
		var repo_index := repo_row.get_index()
		content_vbox.add_child(row)
		content_vbox.move_child(row, repo_index)
	else:
		content_vbox.add_child(row)

func _fit_to_contents() -> void:
	if content_vbox == null:
		return
	content_vbox.reset_size()
	var min_size := content_vbox.get_combined_minimum_size()
	size.x = max(size.x, int(ceil(min_size.x)) + 56)
	size.y = max(size.y, int(ceil(min_size.y)) + 96)


func _on_header_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_dragging_window = true
			_drag_offset = DisplayServer.mouse_get_position() - position
		else:
			_dragging_window = false
		return

	if event is InputEventMouseMotion and _dragging_window:
		position = DisplayServer.mouse_get_position() - _drag_offset
