extends MarginContainer
class_name SpritesheetDialogContent

signal submitted(split: bool, cols: int, rows: int, tag_all: String)
signal cancelled

const PREVIEW_BOX_SIZE := Vector2i(280, 190)

@onready var label_info: Label = %Label_Info
@onready var label_detect_status: Label = %Label_DetectStatus
@onready var spin_cols: SpinBox = %Spin_Cols
@onready var spin_rows: SpinBox = %Spin_Rows
@onready var check_split: CheckBox = %Check_Split
@onready var btn_auto_detect: Button = %Btn_AutoDetect
@onready var check_tag_all: CheckBox = %Check_TagAll
@onready var edit_tag_all: LineEdit = %Line_TagAll
@onready var preview_column: VBoxContainer = get_node_or_null("Panel/HBoxContainer_Main/VBoxContainer_Preview")
@onready var preview_frame: PanelContainer = get_node_or_null("Panel/HBoxContainer_Main/VBoxContainer_Preview/PreviewFrame")
@onready var preview: SpritesheetPreview = %SpritesheetPreview
@onready var btn_cancel: Button = %Btn_Cancel
@onready var btn_ok: Button = %Btn_OK

var _sheet_path: String = ""
var _loaded_image: Image = null


func _ready() -> void:
	_apply_fixed_preview_size()
	btn_cancel.pressed.connect(_on_cancel_pressed)
	btn_ok.pressed.connect(_on_ok_pressed)
	btn_auto_detect.pressed.connect(_on_auto_detect_pressed)
	spin_cols.value_changed.connect(_on_grid_value_changed)
	spin_rows.value_changed.connect(_on_grid_value_changed)


func configure_for_sheet(path: String, img_w: int, img_h: int) -> void:
	_sheet_path = path
	label_info.text = "File: %s\nSize: %dx%d" % [path.get_file(), img_w, img_h]
	_loaded_image = SpritesheetUtils.load_image(path)

	check_split.button_pressed = true
	check_tag_all.button_pressed = false
	edit_tag_all.text = ""
	spin_cols.value = 1
	spin_rows.value = 1

	if _loaded_image != null and preview != null:
		var texture := ImageTexture.create_from_image(_loaded_image)
		preview.set_preview_texture(texture, Vector2i(_loaded_image.get_width(), _loaded_image.get_height()))

	_apply_detected_layout(SpritesheetUtils.detect_uniform_sheet_layout(path))
	_refresh_preview()


func _on_cancel_pressed() -> void:
	cancelled.emit()


func _on_ok_pressed() -> void:
	var split := check_split.button_pressed
	var cols := int(max(1, spin_cols.value))
	var rows := int(max(1, spin_rows.value))
	var tag_all := ""
	if check_tag_all.button_pressed:
		tag_all = edit_tag_all.text
	submitted.emit(split, cols, rows, tag_all)


func _on_auto_detect_pressed() -> void:
	_apply_detected_layout(SpritesheetUtils.detect_uniform_sheet_layout(_sheet_path))
	_refresh_preview()


func _on_grid_value_changed(_value: float) -> void:
	_refresh_preview()


func _apply_detected_layout(result: Dictionary) -> void:
	if result.get("ok", false):
		var detected_cols = max(int(result.get("cols", 1)), 1)
		var detected_rows = max(int(result.get("rows", 1)), 1)
		spin_cols.value = detected_cols
		spin_rows.value = detected_rows
		if label_detect_status:
			label_detect_status.text = "Detected %d columns x %d rows (%d frames)." % [
				detected_cols,
				detected_rows,
				detected_cols * detected_rows
			]
	else:
		if label_detect_status:
			label_detect_status.text = "Could not confidently detect frames. Adjust rows and columns manually."


func _refresh_preview() -> void:
	if preview == null:
		return
	preview.set_grid(int(max(spin_cols.value, 1.0)), int(max(spin_rows.value, 1.0)))


func _apply_fixed_preview_size() -> void:
	if preview_column:
		preview_column.custom_minimum_size = Vector2(PREVIEW_BOX_SIZE.x, PREVIEW_BOX_SIZE.y + 24)
		preview_column.size_flags_horizontal = 0
		preview_column.size_flags_vertical = 0

	if preview_frame:
		preview_frame.custom_minimum_size = PREVIEW_BOX_SIZE
		preview_frame.size = Vector2(PREVIEW_BOX_SIZE)
		preview_frame.size_flags_horizontal = 0
		preview_frame.size_flags_vertical = 0

	if preview:
		preview.custom_minimum_size = PREVIEW_BOX_SIZE
		preview.size = Vector2(PREVIEW_BOX_SIZE)
		preview.size_flags_horizontal = 0
		preview.size_flags_vertical = 0
