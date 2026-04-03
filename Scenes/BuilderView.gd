extends Control
class_name BuilderGrid

signal sequences_changed(sequences: Array)  # Array[Array[String]] of rel paths
signal zoom_changed(zoom: float)

# --- Config ---
var _cell_size: int = 64

@export var cell_size: int:
	get:
		return _cell_size
	set(value):
		_cell_size = max(8, value)
		_base_cell_size = _cell_size
		_apply_zoom()
@export var grid_color: Color = Color(0.22, 0.22, 0.25, 0.3)
@export var major_line_every: int = 4
@export var major_grid_color: Color = Color(0.35, 0.35, 0.40, 1.0)
@export var drop_highlight: Color = Color(0.2, 0.6, 1.0, 0.35)
@export var sound_icon: Texture2D = null   # icon to draw where sounds are placed
@export_range(0.5, 4.0, 0.05) var zoom_step: float = 0.15
@export_range(0.25, 4.0, 0.05) var min_zoom: float = 0.5
@export_range(1.0, 8.0, 0.05) var max_zoom: float = 3.0
@export_range(0.1, 10.0, 0.05) var pan_gesture_speed: float = 1.0

var placed: Dictionary = {}       # keys: Vector2i, values: String (relative path)
var _tex_cache: Dictionary = {}   # keys: String (abs path), values: Texture2D
var placed_sounds: Dictionary = {}  # keys: Vector2i, values: Array[String] of rel paths

var erase_mode: bool = false  # true when eraser tool is active
var _base_cell_size: int = 64
var _zoom: float = 1.0
var _view_offset: Vector2 = Vector2.ZERO


var _cols: int = 0
var _rows: int = 0
var _hover_cell: Vector2i = Vector2i(-1, -1)

# --- drag state for moving sprites ---
var _dragging: bool = false
var _drag_origin_cell: Vector2i = Vector2i(-1, -1)
var _drag_current_cell: Vector2i = Vector2i(-1, -1)
var _drag_rel: String = ""


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_base_cell_size = max(8, cell_size)
	_apply_zoom()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_grid_dims()
		queue_redraw()


func _update_grid_dims() -> void:
	_cols = max(1, int(floor(size.x / float(cell_size))))
	_rows = max(1, int(floor(size.y / float(cell_size))))


func _apply_zoom() -> void:
	var scaled_cell_size := int(round(float(_base_cell_size) * _zoom))
	_cell_size = max(8, scaled_cell_size)
	_update_grid_dims()
	queue_redraw()
	zoom_changed.emit(_zoom)


func get_zoom() -> float:
	return _zoom


func set_zoom(value: float) -> void:
	_zoom = clampf(value, min_zoom, max_zoom)
	_apply_zoom()


func zoom_in() -> void:
	set_zoom(_zoom + zoom_step)


func zoom_out() -> void:
	set_zoom(_zoom - zoom_step)


func _to_cell(p: Vector2) -> Vector2i:
	var world_pos := p + _view_offset
	var c: int = int(floor(world_pos.x / float(cell_size)))
	var r: int = int(floor(world_pos.y / float(cell_size)))
	return Vector2i(c, r)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(
		Vector2(cell.x * cell_size, cell.y * cell_size) - _view_offset,
		Vector2(cell_size, cell_size)
	)


func pan_by(delta: Vector2) -> void:
	_view_offset -= delta
	queue_redraw()

# ----------------------------------------------------
# Drag & Drop from assets
# ----------------------------------------------------
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	_hover_cell = Vector2i(-1, -1)

	if typeof(data) != TYPE_DICTIONARY:
		return false

	var d: Dictionary = data
	if not d.has("type") or not d.has("rel"):
		return false

	var t := String(d["type"])
	if t != "sprite" and t != "sound":
		return false

	_hover_cell = _to_cell(at_position)
	queue_redraw()
	return true


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position, data):
		return

	var d: Dictionary = data
	var rel: String = String(d["rel"])
	var t: String = String(d["type"])
	var cell: Vector2i = _to_cell(at_position)

	if t == "sprite":
		# Place / move sprite
		placed[cell] = rel

	elif t == "sound":
		# Attach sound to this cell (multiple sounds allowed)
		_add_sound_to_cell(cell, rel)

	_hover_cell = Vector2i(-1, -1)
	queue_redraw()
	_emit_sequences()  # sequences only depend on sprites, but we still emit for “grid changed”
	
func _add_sound_to_cell(cell: Vector2i, rel: String) -> void:
	var arr: Array = []
	if placed_sounds.has(cell):
		arr = placed_sounds[cell]
	if not arr.has(rel):
		arr.append(rel)
	placed_sounds[cell] = arr

func set_erase_mode(enabled: bool) -> void:
	erase_mode = enabled
	
func _erase_cell(cell: Vector2i) -> bool:
	var changed := false

	if placed.has(cell):
		placed.erase(cell)
		changed = true

	if placed_sounds.has(cell):
		placed_sounds.erase(cell)
		changed = true

	if changed:
		queue_redraw()
		_emit_sequences()

	return changed

# ----------------------------------------------------
# Mouse input (move existing sprites, delete, etc.)
# ----------------------------------------------------
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture:
		var gesture := event as InputEventMagnifyGesture
		set_zoom(_zoom * gesture.factor)
		accept_event()
		return

	if event is InputEventPanGesture:
		var pan := event as InputEventPanGesture
		pan_by(pan.delta * pan_gesture_speed)
		accept_event()
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var cell: Vector2i = _to_cell(mb.position)

		if mb.pressed and Input.is_key_pressed(KEY_CTRL):
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_in()
				accept_event()
				return
			if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_out()
				accept_event()
				return

		# --- LEFT BUTTON ---
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# Erase if eraser mode is on OR Shift is held
				var erase_click := erase_mode or Input.is_key_pressed(KEY_SHIFT)
				if erase_click:
					_erase_cell(cell)
					return

				# Otherwise, start dragging whatever is in this cell
				_start_drag(cell)
				return
			else:
				# Button released – if we were dragging, finish the move
				if _dragging:
					_finish_drag(cell)
					return

		# --- RIGHT BUTTON: always erase entire cell (sprite + sounds) ---
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_erase_cell(cell)
			return

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging:
			var cell := _to_cell(mm.position)
			if cell != _drag_current_cell:
				_drag_current_cell = cell
				_hover_cell = cell
				queue_redraw()

func _start_drag(cell: Vector2i) -> void:
	# Only start dragging if there is something in this cell:
	# either a sprite, or one or more sounds.
	if not placed.has(cell) and not placed_sounds.has(cell):
		return

	_dragging = true
	_drag_origin_cell = cell
	_drag_current_cell = cell
	_drag_rel = placed.get(cell, "")  # may be "" if only sounds
	_hover_cell = cell

	queue_redraw()

func _finish_drag(target_cell: Vector2i) -> void:
	if not _dragging:
		return

	_dragging = false

	# --- Move sprite (if any) ---
	if placed.has(_drag_origin_cell):
		placed.erase(_drag_origin_cell)

	if _drag_rel != "":
		placed[target_cell] = _drag_rel

	# --- Move any sounds attached to the origin cell ---
	if placed_sounds.has(_drag_origin_cell):
		var moved_sounds: Array = placed_sounds[_drag_origin_cell]
		placed_sounds.erase(_drag_origin_cell)

		var dest_sounds: Array = []
		if placed_sounds.has(target_cell):
			dest_sounds = placed_sounds[target_cell]

		for rel in moved_sounds:
			var rel_str := String(rel)
			if not dest_sounds.has(rel_str):
				dest_sounds.append(rel_str)

		if not dest_sounds.is_empty():
			placed_sounds[target_cell] = dest_sounds

	# Reset drag state
	_drag_origin_cell = Vector2i(-1, -1)
	_drag_current_cell = Vector2i(-1, -1)
	_drag_rel = ""
	_hover_cell = Vector2i(-1, -1)

	queue_redraw()
	_emit_sequences()

# ----------------------------------------------------
# Compute sequences (x-based, top sprite wins)
# ----------------------------------------------------
# Rule now:
#   - Animation is driven by X (columns).
#   - If multiple sprites share the same X, use the TOP one (smallest Y).
#   - Frames ordered by ascending X.
#   - Returns Array[Array[String]] for compatibility; currently a single sequence.
func get_row_sequences() -> Array:
	var column_best: Dictionary = {}  # x -> { "cell": Vector2i, "rel": String }

	for k in placed.keys():
		var cell: Vector2i = k as Vector2i
		var rel: String = String(placed[cell])

		if not column_best.has(cell.x):
			column_best[cell.x] = {"cell": cell, "rel": rel}
		else:
			var current: Dictionary = column_best[cell.x]
			var current_cell: Vector2i = current["cell"]
			if cell.y < current_cell.y:
				column_best[cell.x] = {"cell": cell, "rel": rel}

	var xs: Array = column_best.keys()
	xs.sort()

	var seq: Array = []
	for x in xs:
		var entry: Dictionary = column_best[x]
		seq.append(entry["rel"])

	if seq.is_empty():
		return []
	return [seq]


func _emit_sequences() -> void:
	var seqs: Array = get_row_sequences()
	sequences_changed.emit(seqs)

# ----------------------------------------------------
# Drawing
# ----------------------------------------------------
func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var start_col := int(floor(_view_offset.x / float(cell_size)))
	var end_col := int(ceil((_view_offset.x + w) / float(cell_size)))
	for x in range(start_col, end_col + 1):
		var xi: float = float(x * cell_size) - _view_offset.x
		var col: Color = major_grid_color if (x % major_line_every) == 0 else grid_color
		draw_line(Vector2(xi, 0.0), Vector2(xi, h), col, 1.0)
	var start_row := int(floor(_view_offset.y / float(cell_size)))
	var end_row := int(ceil((_view_offset.y + h) / float(cell_size)))
	for y in range(start_row, end_row + 1):
		var yi: float = float(y * cell_size) - _view_offset.y
		var col2: Color = major_grid_color if (y % major_line_every) == 0 else grid_color
		draw_line(Vector2(0.0, yi), Vector2(w, yi), col2, 1.0)

	if _hover_cell.x >= 0:
		var hr: Rect2 = _cell_rect(_hover_cell)
		if hr.intersects(Rect2(Vector2.ZERO, size)):
			draw_rect(hr, drop_highlight, true)

	# --- Draw sprites ---
	for k in placed.keys():
		var cell: Vector2i = k as Vector2i
		var rel: String = String(placed[cell])
		var abs: String = ProjectModel.project_dir.path_join(rel)
		var tex: Texture2D = _get_texture(abs)
		if tex == null:
			continue

		var rect: Rect2 = _cell_rect(cell)
		if not rect.intersects(Rect2(Vector2.ZERO, size)):
			continue
		var tw: int = tex.get_width()
		var th: int = tex.get_height()
		if tw <= 0 or th <= 0:
			continue

		var scale_factor: float = min(rect.size.x / float(tw), rect.size.y / float(th))
		var dst_size: Vector2 = Vector2(float(tw), float(th)) * scale_factor
		var dst_pos: Vector2 = rect.position + (rect.size - dst_size) * 0.5
		draw_texture_rect(tex, Rect2(dst_pos, dst_size), false)

	# --- Draw sound icons on any cell that has sounds ---
	if sound_icon != null:
		for k in placed_sounds.keys():
			var cell: Vector2i = k as Vector2i
			var rect: Rect2 = _cell_rect(cell)
			if not rect.intersects(Rect2(Vector2.ZERO, size)):
				continue

			# Make the icon smaller than the cell, e.g. 40% of cell size
			var icon_size := rect.size * 0.5
			var dst_pos := rect.position + rect.size - icon_size - Vector2(4.0, 4.0)  # bottom-right with small margin

			draw_texture_rect(sound_icon, Rect2(dst_pos, icon_size), false)

func _get_texture(abs_path: String) -> Texture2D:
	if _tex_cache.has(abs_path):
		return _tex_cache[abs_path] as Texture2D
	var img := Image.new()
	var err: int = img.load(abs_path)
	if err != OK:
		return null
	var tex: Texture2D = ImageTexture.create_from_image(img)
	_tex_cache[abs_path] = tex
	return tex


# ----------------------------------------------------
# Helpers for external use
# ----------------------------------------------------
func clear_grid() -> void:
	print("[DEBUG][BuilderGrid] clear_grid() called. Current placed size =", placed.size())

	placed.clear()
	placed_sounds.clear()

	_dragging = false
	_drag_origin_cell = Vector2i(-1, -1)
	_drag_current_cell = Vector2i(-1, -1)
	_drag_rel = ""
	_hover_cell = Vector2i(-1, -1)

	queue_redraw()
	_emit_sequences()

	print("[DEBUG][BuilderGrid] clear_grid() finished. placed size now =", placed.size())


func load_from_animation_data(anim: Dictionary) -> void:
	clear_grid()

	if anim.is_empty():
		return

	# --- Sprites ---
	if anim.has("cells"):
		var sprite_cells: Array = anim["cells"]
		for c in sprite_cells:
			if not (c is Dictionary):
				continue
			var cd := c as Dictionary
			if not (cd.has("x") and cd.has("y") and cd.has("rel")):
				continue
			var cell := Vector2i(int(cd["x"]), int(cd["y"]))
			var rel := String(cd["rel"])
			placed[cell] = rel
	else:
		# Backwards compatibility: if only sequences, place them top-down, left-right
		if anim.has("sequences"):
			var sequences: Array = anim["sequences"]
			var row_idx: int = 0
			for seq in sequences:
				if not (seq is Array):
					continue
				var col_idx: int = 0
				for rel in seq:
					var rel_str := String(rel)
					var cell := Vector2i(col_idx, row_idx)
					placed[cell] = rel_str
					col_idx += 1
				row_idx += 1

	# --- Sounds ---
	if anim.has("sound_cells"):
		var sound_cells: Array = anim["sound_cells"]
		for c in sound_cells:
			if not (c is Dictionary):
				continue
			var cd := c as Dictionary
			if not (cd.has("x") and cd.has("y") and cd.has("rel")):
				continue
			var cell := Vector2i(int(cd["x"]), int(cd["y"]))
			var rel := String(cd["rel"])
			var arr: Array = placed_sounds.get(cell, [])
			arr.append(rel)
			placed_sounds[cell] = arr

	queue_redraw()
	# DO NOT call _emit_sequences() here


func build_animation_data() -> Dictionary:
	# Sprites: save exact cell layout
	var sprite_cells: Array = []
	for k in placed.keys():
		var cell: Vector2i = k as Vector2i
		var rel: String = String(placed[cell])
		sprite_cells.append({
			"x": cell.x,
			"y": cell.y,
			"rel": rel,
		})

	# Sounds: save exact cell + rel
	var sound_cells: Array = []
	for k in placed_sounds.keys():
		var cell: Vector2i = k as Vector2i
		var arr: Array = placed_sounds[cell]
		for rel in arr:
			sound_cells.append({
				"x": cell.x,
				"y": cell.y,
				"rel": String(rel),
			})

	return {
		"cells": sprite_cells,
		"sound_cells": sound_cells,
		"sequences": get_row_sequences(),
	}
	
# Returns Array[int]: X positions of frames in the first preview sequence (left-to-right)
func get_preview_frame_x_positions() -> Array:
	var xs: Array = []

	# We take the first row/run used for preview; that’s what _on_builder_sequences_changed uses.
	# Rebuild the row sequences just like get_row_sequences, but we only care about Xs.
	var by_row: Dictionary = {}
	for k in placed.keys():
		var cell: Vector2i = k as Vector2i
		if not by_row.has(cell.y):
			by_row[cell.y] = []
		(by_row[cell.y] as Array).append(cell)

	var row_keys: Array = by_row.keys()
	row_keys.sort()  # top to bottom

	if row_keys.is_empty():
		return xs

	var first_row := int(row_keys[0])
	var cells: Array = by_row[first_row]
	cells.sort_custom(func(a, b): return (a as Vector2i).x < (b as Vector2i).x)

	for c in cells:
		var cell: Vector2i = c
		xs.append(cell.x)

	return xs


# Returns Dictionary: x (int) -> Array[String] of sound rel paths
func get_sounds_by_x() -> Dictionary:
	var result: Dictionary = {}

	for k in placed_sounds.keys():
		var cell: Vector2i = k as Vector2i
		var x := cell.x

		var existing: Array = result.get(x, [])
		var sounds_here: Array = placed_sounds[cell]

		for rel in sounds_here:
			var rel_str := String(rel)
			if not existing.has(rel_str):
				existing.append(rel_str)

		result[x] = existing

	return result
