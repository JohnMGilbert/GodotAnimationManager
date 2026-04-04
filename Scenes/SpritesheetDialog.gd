extends Window
class_name SpritesheetDialog

signal decided(sheet_path: String, split: bool, cols: int, rows: int, tag_all: String)

@onready var content: SpritesheetDialogContent = $Content

var _sheet_path: String = ""


func _ready() -> void:
	if content:
		content.submitted.connect(_on_content_submitted)
		content.cancelled.connect(_on_content_cancelled)
	close_requested.connect(_on_content_cancelled)


func popup_for_sheet(path: String, img_w: int, img_h: int) -> void:
	_sheet_path = path
	title = "Import Spritesheet"
	if content:
		content.configure_for_sheet(path, img_w, img_h)
	_resize_to_contents()
	popup_centered()


func _resize_to_contents() -> void:
	if content == null:
		return

	var content_min := content.get_combined_minimum_size().ceil()
	var target_width := int(content_min.x)
	var target_height := int(content_min.y)
	min_size = Vector2i(target_width, target_height)
	size = min_size


func _on_content_cancelled() -> void:
	hide()
	decided.emit(_sheet_path, false, 1, 1, "")


func _on_content_submitted(split: bool, cols: int, rows: int, tag_all: String) -> void:
	hide()
	decided.emit(_sheet_path, split, cols, rows, tag_all)
