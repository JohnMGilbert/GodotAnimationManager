extends ItemList
class_name SoundList

@export var audio_icon: Texture2D   # assign in Inspector (e.g. a little speaker/note icon)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP  # ensure we receive input

func _get_drag_data(at_position: Vector2) -> Variant:
	print("sound get_drag_data at:", at_position)
	var idx: int = get_item_at_position(at_position, false)
	if idx == -1:
		return null

	var rel: String = str(get_item_metadata(idx))
	if rel == "":
		return null

	# Drag preview: small, half-opacity icon
	if audio_icon != null:
		var preview := TextureRect.new()
		preview.texture = audio_icon
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		# Make it smaller (e.g. 24×24). Adjust if you want slightly larger.
		preview.custom_minimum_size = Vector2(24, 24)

		# Half opacity
		preview.modulate = Color(1.0, 1.0, 1.0, 0.5)
		preview.size = preview.size *.02

		set_drag_preview(preview)
	else:
		var label := Label.new()
		label.text = rel.get_file()
		label.modulate = Color(1.0, 1.0, 1.0, 0.5)
		set_drag_preview(label)

	print("Dragging sound:", rel)
	return {
		"type": "sound",
		"rel": rel,  # e.g. "assets/audio/my_sound.wav"
	}
