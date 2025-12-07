# File: res://ui/SpritesheetDialog.gd
extends Window
class_name SpritesheetDialog

signal decided(sheet_path: String, split: bool, cols: int, rows: int)

@onready var label_info: Label = %Label_Info
@onready var spin_cols: SpinBox = %Spin_Cols
@onready var spin_rows: SpinBox = %Spin_Rows
@onready var check_split: CheckBox = %Check_Split
@onready var btn_cancel: Button = %Btn_Cancel
@onready var btn_ok: Button = %Btn_OK

var _sheet_path: String = ""

func _ready() -> void:
	btn_cancel.pressed.connect(func() -> void:
		hide()
		emit_signal("decided", _sheet_path, false, 1, 1)
	)
	btn_ok.pressed.connect(_on_ok_pressed)

func popup_for_sheet(path: String, img_w: int, img_h: int) -> void:
	_sheet_path = path
	title = "Import spritesheet?"
	label_info.text = "File: %s\nSize: %dx%d" % [path.get_file(), img_w, img_h]
	check_split.button_pressed = true
	popup_centered()

func _on_ok_pressed() -> void:
	var split := check_split.button_pressed
	var cols := int(max(1, spin_cols.value))
	var rows := int(max(1, spin_rows.value))
	hide()
	emit_signal("decided", _sheet_path, split, cols, rows)
