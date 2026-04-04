# File: res://scripts/SpritesheetUtils.gd
extends Object
class_name SpritesheetUtils

static func load_image(path: String) -> Image:
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		push_error("SpritesheetUtils: Failed to load %s (err %d)" % [path, err])
		return null
	return img

# Heuristic: "does this image look like a spritesheet?"
static func looks_like_spritesheet(path: String) -> bool:
	var img := load_image(path)
	if img == null:
		return false

	var w := img.get_width()
	var h := img.get_height()
	if w <= 0 or h <= 0:
		return false

	var ratio := float(max(w, h)) / float(min(w, h))
	# Very wide or very tall is a good hint
	if ratio >= 2.0:
		return true

	# Also treat evenly divisible grids as "probably a sheet"
	for cols in range(2, 13):
		if w % cols == 0:
			return true
	for rows in range(2, 13):
		if h % rows == 0:
			return true

	return false

# Split sheet into equal cols x rows and save to out_dir_abs.
# Returns an Array[String] of file names (not full paths).
static func split_sheet_to_files(
	sheet_path: String,
	out_dir_abs: String,
	cols: int,
	rows: int,
	base_name: String = ""
) -> Array[String]:
	var result: Array[String] = []

	var img := load_image(sheet_path)
	if img == null:
		return result

	if cols <= 0 or rows <= 0:
		push_error("SpritesheetUtils: cols/rows must be > 0.")
		return result

	var sheet_w := img.get_width()
	var sheet_h := img.get_height()

	var frame_w := sheet_w / cols
	var frame_h := sheet_h / rows

	if base_name == "":
		base_name = sheet_path.get_file().get_basename()

	var idx := 0
	for row in range(rows):
		for col in range(cols):
			var rect := Rect2i(col * frame_w, row * frame_h, frame_w, frame_h)
			# Godot 4 way to get a sub-image:
			var frame_img := img.get_region(rect)

			var file_name := "%s_%02d.png" % [base_name, idx]
			var dst_abs := out_dir_abs.path_join(file_name)

			var err := frame_img.save_png(dst_abs)
			if err != OK:
				push_error("SpritesheetUtils: Failed to save %s (err %d)" % [dst_abs, err])
			else:
				result.append(file_name)

			idx += 1

	return result


static func detect_uniform_sheet_layout(path: String) -> Dictionary:
	var img := load_image(path)
	if img == null:
		return {"ok": false}

	var width := img.get_width()
	var height := img.get_height()
	if width <= 0 or height <= 0:
		return {"ok": false}

	var occupied_cols := _compute_occupied_columns(img)
	var occupied_rows := _compute_occupied_rows(img)
	var col_runs := _find_true_runs(occupied_cols)
	var row_runs := _find_true_runs(occupied_rows)

	var cols := _fit_run_count_to_divisor(width, col_runs.size())
	var rows := _fit_run_count_to_divisor(height, row_runs.size())

	if cols <= 1 and rows <= 1:
		var fallback := _score_grid_candidates(img)
		if fallback.get("ok", false):
			return fallback
		return {"ok": false}

	if cols <= 0:
		cols = 1
	if rows <= 0:
		rows = 1

	return {
		"ok": true,
		"cols": cols,
		"rows": rows
	}


static func _compute_occupied_columns(img: Image) -> Array[bool]:
	var occupied: Array[bool] = []
	var width := img.get_width()
	var height := img.get_height()

	for x in range(width):
		var has_foreground := false
		for y in range(height):
			if img.get_pixel(x, y).a > 0.05:
				has_foreground = true
				break
		occupied.append(has_foreground)

	return occupied


static func _compute_occupied_rows(img: Image) -> Array[bool]:
	var occupied: Array[bool] = []
	var width := img.get_width()
	var height := img.get_height()

	for y in range(height):
		var has_foreground := false
		for x in range(width):
			if img.get_pixel(x, y).a > 0.05:
				has_foreground = true
				break
		occupied.append(has_foreground)

	return occupied


static func _find_true_runs(values: Array[bool]) -> Array[Vector2i]:
	var runs: Array[Vector2i] = []
	var run_start := -1

	for i in range(values.size()):
		if values[i]:
			if run_start == -1:
				run_start = i
		elif run_start != -1:
			runs.append(Vector2i(run_start, i - 1))
			run_start = -1

	if run_start != -1:
		runs.append(Vector2i(run_start, values.size() - 1))

	return runs


static func _fit_run_count_to_divisor(total_size: int, run_count: int) -> int:
	if run_count <= 0:
		return 1
	if total_size % run_count == 0:
		return run_count

	var best_divisor := 1
	var best_distance := 999999
	for candidate in range(1, min(total_size, 64) + 1):
		if total_size % candidate != 0:
			continue
		var distance := absi(candidate - run_count)
		if distance < best_distance:
			best_distance = distance
			best_divisor = candidate
	return best_divisor


static func _score_grid_candidates(img: Image) -> Dictionary:
	var width := img.get_width()
	var height := img.get_height()
	var best_score := -1.0
	var best_cols := 1
	var best_rows := 1

	for cols in range(1, min(width, 16) + 1):
		if width % cols != 0:
			continue
		for rows in range(1, min(height, 16) + 1):
			if height % rows != 0:
				continue
			var score := _score_candidate_grid(img, cols, rows)
			if score > best_score:
				best_score = score
				best_cols = cols
				best_rows = rows

	if best_score <= 0.0:
		return {"ok": false}

	return {
		"ok": true,
		"cols": best_cols,
		"rows": best_rows
	}


static func _score_candidate_grid(img: Image, cols: int, rows: int) -> float:
	var width := img.get_width()
	var height := img.get_height()
	var cell_w := width / cols
	var cell_h := height / rows
	var occupied_cells := 0

	for row in range(rows):
		for col in range(cols):
			if _cell_has_foreground(img, Rect2i(col * cell_w, row * cell_h, cell_w, cell_h)):
				occupied_cells += 1

	if occupied_cells <= 1:
		return 0.0

	return float(occupied_cells) / float(cols * rows)


static func _cell_has_foreground(img: Image, rect: Rect2i) -> bool:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if img.get_pixel(x, y).a > 0.05:
				return true
	return false
