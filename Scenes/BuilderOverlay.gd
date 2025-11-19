# ui/BuilderOverlay.gd
extends CanvasLayer

@onready var _animation_menu_button: TextureButton = %ChangeAnimation
@onready var _animation_menu: PopupMenu = %AniationSwitcherPopup
@onready var _save_button: TextureButton = %SaveButton
@onready var _timeline: BuilderGrid = %BuilderView

var _current_animation_name: String = ""


func _ready() -> void:
	# Connect to ProjectModel signals
	ProjectModel.project_loaded.connect(_on_project_loaded)
	ProjectModel.animation_list_changed.connect(_refresh_animation_list)
	ProjectModel.animation_changed.connect(_on_animation_changed)

	# Connect UI signals
	_animation_menu_button.pressed.connect(_on_animation_menu_button_pressed)
	_animation_menu.index_pressed.connect(_on_animation_selected)
	_save_button.pressed.connect(_on_save_pressed)

	# Connect timeline → ProjectModel
	_timeline.sequences_changed.connect(_on_sequences_changed)

	# Initial load
	_refresh_animation_list()
	var current = ProjectModel.data.get("current_animation", "")
	if current != "":
		_load_animation_into_ui(current)


# -------------------------------------------------------
# PROJECT MODEL → UI
# -------------------------------------------------------

func _on_project_loaded() -> void:
	_refresh_animation_list()
	var current = ProjectModel.data.get("current_animation", "")
	if current != "":
		_load_animation_into_ui(current)


func _on_animation_changed(animation_name: String) -> void:
	if animation_name == "":
		_current_animation_name = ""
		_timeline.load_from_animation_data({})
		return

	_current_animation_name = animation_name
	_load_animation_into_ui(animation_name)


func _refresh_animation_list() -> void:
	_animation_menu.clear()

	var names := ProjectModel.get_animation_names()
	for i in range(names.size()):
		_animation_menu.add_item(names[i], i)

	if names.size() > 0:
		var current = ProjectModel.data.get("current_animation", names[0])
		_load_animation_into_ui(current)


# -------------------------------------------------------
# TIMELINE (GRID) → PROJECT MODEL
# -------------------------------------------------------

func _on_sequences_changed(seqs: Array) -> void:
	# If nothing is selected yet, don't try to save
	if _current_animation_name == "":
		return

	ProjectModel.set_sequences_from_builder(seqs)


# -------------------------------------------------------
# UI BUTTON HANDLERS
# -------------------------------------------------------

func _on_animation_menu_button_pressed() -> void:
	# Open popup at the button’s position
	_animation_menu.popup()


func _on_animation_selected(index: int) -> void:
	var names := ProjectModel.get_animation_names()
	if index >= 0 and index < names.size():
		var name := names[index]
		ProjectModel.data["current_animation"] = name
		_load_animation_into_ui(name)


func _on_save_pressed() -> void:
	if _current_animation_name == "":
		push_warning("BuilderOverlay: No animation selected to save.")
		return

	# Collect updated timeline data
	var anim_data = _timeline.build_animation_data()

	# Save to project model
	ProjectModel.set_animation(_current_animation_name, anim_data)
	var err := ProjectModel.save()

	if err != OK:
		push_error("BuilderOverlay: Failed to save project (err %d)." % err)


# -------------------------------------------------------
# INTERNAL HELPERS
# -------------------------------------------------------

func _load_animation_into_ui(name: String) -> void:
	_current_animation_name = name
	var anim_data := ProjectModel.get_animation(name)
	_timeline.load_from_animation_data(anim_data)
