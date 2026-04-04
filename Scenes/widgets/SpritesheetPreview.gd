extends Control
class_name SpritesheetPreview

const PREVIEW_BG := Color(0.768627, 0.745098, 0.733333, 1.0)
const PREVIEW_BORDER := Color(0.152941, 0.160784, 0.160784, 0.35)
const GRID_COLOR := Color(0.603922, 0.133333, 0.341176, 0.9)
const GRID_FILL := Color(0.603922, 0.133333, 0.341176, 0.08)

var _texture: Texture2D = null
var _cols: int = 1
var _rows: int = 1
var _image_size: Vector2 = Vector2.ONE


func set_preview_texture(texture: Texture2D, image_size: Vector2i) -> void:
	_texture = texture
	_image_size = Vector2(image_size.x, image_size.y)
	queue_redraw()


func set_grid(cols: int, rows: int) -> void:
	_cols = max(cols, 1)
	_rows = max(rows, 1)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, PREVIEW_BG, true)

	if _texture == null:
		return

	var image_rect := _get_image_draw_rect(rect)
	draw_texture_rect(_texture, image_rect, false)
	draw_rect(image_rect, PREVIEW_BORDER, false, 2.0)
	_draw_grid_overlay(image_rect)


func _get_image_draw_rect(bounds: Rect2) -> Rect2:
	var inset := 10.0
	var content_rect := bounds.grow(-inset)
	var tex_w = max(_image_size.x, 1.0)
	var tex_h = max(_image_size.y, 1.0)
	var scale_factor = min(content_rect.size.x / tex_w, content_rect.size.y / tex_h)
	var draw_size = Vector2(tex_w, tex_h) * scale_factor
	var draw_pos = content_rect.position + (content_rect.size - draw_size) * 0.5
	return Rect2(draw_pos, draw_size)


func _draw_grid_overlay(image_rect: Rect2) -> void:
	var cell_w := image_rect.size.x / float(max(_cols, 1))
	var cell_h := image_rect.size.y / float(max(_rows, 1))

	for row in range(_rows):
		for col in range(_cols):
			var cell_rect := Rect2(
				image_rect.position + Vector2(cell_w * col, cell_h * row),
				Vector2(cell_w, cell_h)
			)
			draw_rect(cell_rect, GRID_FILL, true)
			draw_rect(cell_rect, GRID_COLOR, false, 1.0)
