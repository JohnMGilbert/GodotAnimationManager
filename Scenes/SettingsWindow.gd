extends Window
class_name SettingsWindow

signal settings_applied(grid_cell_size: int, preview_fps: float, repo_path: String)

@onready var spin_cell_size: SpinBox = %Spin_CellSize
@onready var spin_preview_fps: SpinBox = %Spin_PreviewFPS
@onready var line_repo_path: LineEdit = %LineEdit_RepoPath
@onready var btn_browse_repo: Button = %Btn_BrowseRepo

@onready var btn_cancel: Button = %Btn_SettingsCancel
@onready var btn_apply: Button = %Btn_SettingsApply
@onready var fd_repo_dir: FileDialog = $FD_RepoDir

func _ready() -> void:
	var root := get_tree().root
	#content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	#content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	#content_scale_factor = root.content_scale_factor
	
	btn_cancel.pressed.connect(func() -> void:
		hide()
	)
	btn_apply.pressed.connect(_on_apply_pressed)

	# Browse for repo folder
	btn_browse_repo.pressed.connect(func() -> void:
		fd_repo_dir.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		fd_repo_dir.access = FileDialog.ACCESS_FILESYSTEM
		if line_repo_path.text != "":
			fd_repo_dir.current_dir = line_repo_path.text
		else:
			OS.get_environment("HOME")
		fd_repo_dir.popup_centered_ratio(0.75)
	)

	fd_repo_dir.dir_selected.connect(func(path: String) -> void:
		line_repo_path.text = path
	)

func _on_apply_pressed() -> void:
	var cell_size: int = int(spin_cell_size.value)
	var fps: float = float(spin_preview_fps.value)
	var repo: String = line_repo_path.text.strip_edges()
	settings_applied.emit(cell_size, fps, repo)
	hide()

func set_current_values(grid_cell_size: int, preview_fps: float, repo_path: String) -> void:
	spin_cell_size.value = grid_cell_size
	spin_preview_fps.value = preview_fps
	line_repo_path.text = repo_path
