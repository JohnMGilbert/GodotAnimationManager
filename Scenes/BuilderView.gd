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

# ---------- Drag & Drop ----------
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

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var cell: Vector2i = _to_cell(mb.position)
			if placed.has(cell):
				placed.erase(cell)
				queue_redraw()
				_emit_sequences()

# ---------- Compute sequences ----------
# Rule: frames placed side-by-side (same row, x increasing by 1) form a sequence.
# Multiple rows -> multiple sequences (top row first). Gaps in a row split into multiple sequences.
func get_row_sequences() -> Array:
	var by_row: Dictionary = {}  # row(int) -> Array[Vector2i]

	for k in placed.keys():
		var cell: Vector2i = k as Vector2i
		if not by_row.has(cell.y):
			by_row[cell.y] = []
		(by_row[cell.y] as Array).append(cell)

	var row_keys: Array = by_row.keys()
	row_keys.sort()  # top to bottom

	var sequences: Array = []  # Array[Array[String]]
	for y in row_keys:
		var cells: Array = by_row[y]
		cells.sort_custom(func(a, b): return (a as Vector2i).x < (b as Vector2i).x)

		var run: Array = []  # Array[String]
		var last_x: int = -9999

		for c in cells:
			var cell: Vector2i = c
			if run.is_empty():
				run.append(placed[cell])
				last_x = cell.x
			else:
				if cell.x == last_x + 1:
					run.append(placed[cell])
					last_x = cell.x
				else:
					if not run.is_empty():
						sequences.append(run.duplicate())
					run.clear()
					run.append(placed[cell])
					last_x = cell.x

		if not run.is_empty():
			sequences.append(run.duplicate())

	return sequences  # e.g. [[rel1, rel2, rel3], [relA, relB]]

func _emit_sequences() -> void:
	var seqs: Array = get_row_sequences()
	sequences_changed.emit(seqs)

# ---------- Drawing ----------
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
	
func clear_grid() -> void:
	placed.clear()
	queue_redraw()
	_emit_sequences()
	
func load_from_animation_data(anim: Dictionary) -> void:
	# Called by BuilderOverlay when switching animations
	clear_grid()

	if anim.is_empty():
		return
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
	# Called by workspace when saving/exporting.
	# Packs the current grid into a simple animation dictionary.
	return {
		"sequences": get_row_sequences()
	}
