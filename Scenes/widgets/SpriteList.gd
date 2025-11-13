extends ItemList
class_name SpriteList

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP  # ensure we receive input

func _get_drag_data(at_position: Vector2) -> Variant:
	print("get_drag_data called at:", at_position)
	# Loose hit test so dragging anywhere on the row works
	var idx: int = get_item_at_position(at_position, false)
	if idx == -1:
		return null

	var rel: String = str(get_item_metadata(idx))
	if rel == "":
		return null

	# Optional: show icon as drag preview
	var icon: Texture2D = get_item_icon(idx)
	if icon != null:
		var preview := TextureRect.new()
		preview.texture = icon
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		set_drag_preview(preview)

	print("Dragging:", rel)  # debug: you should see this when you drag
	return {"type": "sprite", "rel": rel}
