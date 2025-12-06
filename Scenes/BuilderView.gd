extends Control
class_name BuilderGrid

signal sequences_changed(sequences: Array)  # Array[Array[String]] of rel paths

# --- Config ---
@export var cell_size: int = 64
@export var grid_color: Color = Color(0.22, 0.22, 0.25, 0.3)
@export var major_line_every: int = 4
@export var major_grid_color: Color = Color(0.35, 0.35, 0.40, 1.0)
@export var drop_highlight: Color = Color(0.2, 0.6, 1.0, 0.35)

var placed: Dictionary = {}       # keys: Vector2i, values: String (relative path)
var _tex_cache: Dictionary = {}   # keys: String (abs path), values: Texture2D

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
	_update_grid_dims()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_grid_dims()
		queue_redraw()


func _update_grid_dims() -> void:
	_cols = max(1, int(floor(size.x / float(cell_size))))
	_rows = max(1, int(floor(size.y / float(cell_size))))


func _to_cell(p: Vector2) -> Vector2i:
	var c: int = int(floor(p.x / float(cell_size)))
	var r: int = int(floor(p.y / float(cell_size)))
	return Vector2i(clamp(c, 0, _cols - 1), clamp(r, 0, _rows - 1))


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell.x * cell_size, cell.y * cell_size), Vector2(cell_size, cell_size))

# ----------------------------------------------------
# Drag & Drop from assets
# ----------------------------------------------------
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	_hover_cell = Vector2i(-1, -1)
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = data
	if not d.has("type") or String(d["type"]) != "sprite":
		return false
	if not d.has("rel"):
		return false
	_hover_cell = _to_cell(at_position)
	queue_redraw()
	return true


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position, data):
		return
	var rel: String = String((data as Dictionary)["rel"])
	var cell: Vector2i = _to_cell(at_position)
	placed[cell] = rel
	_hover_cell = Vector2i(-1, -1)
	queue_redraw()
	_emit_sequences()

# ----------------------------------------------------
# Mouse input (move existing sprites, delete, etc.)
# ----------------------------------------------------
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		# Right click: delete cell content
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var cell: Vector2i = _to_cell(mb.position)
			if placed.has(cell):
				placed.erase(cell)
				queue_redraw()
				_emit_sequences()
			return

		# Left click: start / end drag of existing sprite
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var start_cell: Vector2i = _to_cell(mb.position)
				if placed.has(start_cell):
					_dragging = true
					_drag_origin_cell = start_cell
					_drag_current_cell = start_cell
					_drag_rel = String(placed[start_cell])
					_hover_cell = start_cell
					queue_redraw()
			else:
				if _dragging:
					var target_cell: Vector2i = _to_cell(mb.position)
					_finish_drag(target_cell)
			return

	elif event is InputEventMouseMotion:
		if _dragging:
			var mm := event as InputEventMouseMotion
			var cell: Vector2i = _to_cell(mm.position)
			if cell != _drag_current_cell:
				_drag_current_cell = cell
				_hover_cell = cell
				queue_redraw()


func _finish_drag(target_cell: Vector2i) -> void:
	if not _dragging:
		return

	_dragging = false

	if placed.has(_drag_origin_cell):
		placed.erase(_drag_origin_cell)

	if _drag_rel != "":
		placed[target_cell] = _drag_rel

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
	for x in range(0, _cols + 1):
		var xi: float = float(x * cell_size)
		var col: Color = major_grid_color if (x % major_line_every) == 0 else grid_color
		draw_line(Vector2(xi, 0.0), Vector2(xi, h), col, 1.0)
	for y in range(0, _rows + 1):
		var yi: float = float(y * cell_size)
		var col2: Color = major_grid_color if (y % major_line_every) == 0 else grid_color
		draw_line(Vector2(0.0, yi), Vector2(w, yi), col2, 1.0)

	if _hover_cell.x >= 0:
		var hr: Rect2 = _cell_rect(_hover_cell)
		draw_rect(hr, drop_highlight, true)

	for k in placed.keys():
		var cell: Vector2i = k as Vector2i
		var rel: String = String(placed[cell])
		var abs: String = ProjectModel.project_dir.path_join(rel)
		var tex: Texture2D = _get_texture(abs)
		if tex == null:
			continue

		var rect: Rect2 = _cell_rect(cell)
		var tw: int = tex.get_width()
		var th: int = tex.get_height()
		if tw <= 0 or th <= 0:
			continue

		var scale_factor: float = min(rect.size.x / float(tw), rect.size.y / float(th))
		var dst_size: Vector2 = Vector2(float(tw), float(th)) * scale_factor
		var dst_pos: Vector2 = rect.position + (rect.size - dst_size) * 0.5
		draw_texture_rect(tex, Rect2(dst_pos, dst_size), false)


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

	_dragging = false
	_drag_origin_cell = Vector2i(-1, -1)
	_drag_current_cell = Vector2i(-1, -1)
	_drag_rel = ""
	_hover_cell = Vector2i(-1, -1)

	queue_redraw()
	_emit_sequences()

	print("[DEBUG][BuilderGrid] clear_grid() finished. placed size now =", placed.size())


func load_from_animation_data(anim: Dictionary) -> void:
	print("\n[DEBUG][BuilderGrid] load_from_animation_data called with anim =", anim)

	clear_grid()

	if anim.is_empty():
		print("[DEBUG][BuilderGrid] anim was empty, returning after clearing.\n")
		return

	if anim.has("cells") and anim["cells"] is Array:
		print("[DEBUG][BuilderGrid] Loading explicit cell placement, count =", anim["cells"].size())

	if anim.is_empty():
		return

	# NEW FORMAT: use explicit cell positions if available
	if anim.has("cells") and anim["cells"] is Array:
		for entry in anim["cells"]:
			if not (entry is Dictionary):
				continue
			var x := int(entry.get("x", 0))
			var y := int(entry.get("y", 0))
			var rel := String(entry.get("rel", ""))
			if rel == "":
				continue
			var cell := Vector2i(x, y)
			placed[cell] = rel
		queue_redraw()
		return

	# BACKWARDS COMPAT: old format used only sequences → pack rows
	if not anim.has("sequences"):
		return

	var sequences: Array = anim["sequences"]  # Array[Array[String]]
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

	queue_redraw()
	# DO NOT call _emit_sequences() here


func build_animation_data() -> Dictionary:
	# Returns a structure with both exact cells and derived sequences.
	var cells: Array = []

	for k in placed.keys():
		var cell: Vector2i = k as Vector2i
		var rel: String = String(placed[cell])
		cells.append({
			"x": cell.x,
			"y": cell.y,
			"rel": rel,
		})

	return {
		"cells": cells,
		"sequences": get_row_sequences(),
	}
