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
