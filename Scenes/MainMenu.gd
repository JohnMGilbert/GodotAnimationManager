# scenes/MainMenu.gd
extends Control

@onready var title_label: Label      = %Title
@onready var recent_list: ItemList   = %RecentList
@onready var new_button: Button      = %NewProject
@onready var open_button: Button     = %OpenProject
@onready var remove_button: Button   = %Remove
@onready var quit_button: Button     = %Quit
@onready var new_dialog: FileDialog  = %NewDialog
@onready var open_dialog: FileDialog = %OpenDialog
@onready var notice: AcceptDialog    = %NoticeDialog

func _ready() -> void:
	title_label.text = "Animation Manager"
	_populate_recents()

	# Configure dialogs
	new_dialog.access = FileDialog.ACCESS_FILESYSTEM
	new_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	new_dialog.current_file = "new_project.aam"
	new_dialog.filters = PackedStringArray(["*.aam ; Animation Manager Project"])

	open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_dialog.filters = PackedStringArray(["*.aam ; Animation Manager Project"])

	# >>> Use last stored project dir if we have one
	var last_dir := AppState.get_last_project_dir()
	if last_dir != "":
		new_dialog.current_dir = last_dir
		open_dialog.current_dir = last_dir

	# Connect UI
	new_button.pressed.connect(_on_new_pressed)
	open_button.pressed.connect(_on_open_pressed)
	remove_button.pressed.connect(_on_remove_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	new_dialog.file_selected.connect(_on_new_file_selected)
	open_dialog.file_selected.connect(_on_open_file_selected)

	recent_list.item_activated.connect(_on_recent_activated)
	recent_list.item_selected.connect(_on_recent_selected)

func debug_print_cwd():
	var dir := DirAccess.open(".")
	if dir:
		print("CWD:", dir.get_current_dir())
	else:
		print("Could not open CWD")

func _populate_recents() -> void:
	recent_list.clear()
	for p in AppState.get_recents():
		var display := p
		# Nice short path view
		if OS.has_feature("editor"):
			display = p
		recent_list.add_item(display)
		recent_list.set_item_metadata(recent_list.item_count - 1, p)
	remove_button.disabled = true

func _on_new_pressed() -> void:
	new_dialog.popup_centered_ratio(0.7)

func _on_open_pressed() -> void:
	open_dialog.popup_centered_ratio(0.7)

func _on_remove_pressed() -> void:
	var idx := recent_list.get_selected_items()
	if idx.is_empty():
		return
	var meta := recent_list.get_item_metadata(idx[0]) as String
	AppState.remove_recent(meta)
	_populate_recents()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_new_file_selected(path: String) -> void:
	var err := AppState.create_new_project(path)
	if err != OK:
		_alert("Could not create project:\n%s" % path)
		return

	# Remember the directory for next launch
	AppState.set_last_project_dir(path.get_base_dir())

	_goto_project(path)

func _on_open_file_selected(path: String) -> void:
	if not AppState.validate_project_file(path):
		_alert("Not a valid Animation Manager project:\n%s" % path)
		return

	AppState.add_recent(path)
	AppState.set_last_project_dir(path.get_base_dir())

	_goto_project(path)

func _on_recent_selected(index: int) -> void:
	remove_button.disabled = false

func _on_recent_activated(index: int) -> void:
	var path := recent_list.get_item_metadata(index) as String
	if not AppState.validate_project_file(path):
		_alert("Project missing or invalid, removing from Recents:\n%s" % path)
		AppState.remove_recent(path)
		_populate_recents()
		return

	# Also update last dir from this project
	AppState.set_last_project_dir(path.get_base_dir())

	_goto_project(path)

func _goto_project(path: String) -> void:
	# Normalize to absolute, open the .aam
	var abs: String = ProjectSettings.globalize_path(path)
	var err: int = ProjectModel.open(abs)
	if err != OK:
		_alert("Could not open project:\n%s\n\nError: %s" % [abs, error_string(err)])
		return

	# Close any open modal to avoid blocking the scene change
	if is_instance_valid($CenterContainer/Panel/MarginContainer/VBoxContainer/NoticeDialog) and $CenterContainer/Panel/MarginContainer/VBoxContainer/NoticeDialog.visible:
		$CenterContainer/Panel/MarginContainer/VBoxContainer/NoticeDialog.hide()

	# Change to workspace
	var scene_err := get_tree().change_scene_to_file("res://Scenes/workspace.tscn")
	if scene_err != OK:
		_alert("Failed to load Workspace.tscn\nError: %s" % error_string(scene_err))

func _alert(msg: String) -> void:
	notice.title = "Notice"
	notice.dialog_text = msg
	notice.popup_centered()
