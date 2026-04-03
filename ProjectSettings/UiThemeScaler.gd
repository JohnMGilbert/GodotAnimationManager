extends RefCounted
class_name UiThemeScaler

const FONT_SIZE_TARGETS := [
	{"type": "Button", "name": "font_size"},
	{"type": "CheckBox", "name": "font_size"},
	{"type": "ItemList", "name": "font_size"},
	{"type": "Label", "name": "font_size"},
	{"type": "LineEdit", "name": "font_size"},
	{"type": "OptionButton", "name": "font_size"},
	{"type": "PopupMenu", "name": "font_size"},
	{"type": "SpinBox", "name": "font_size"},
	{"type": "TabBar", "name": "font_size"},
	{"type": "TabContainer", "name": "font_size"},
	{"type": "TextEdit", "name": "font_size"},
]

const CONSTANT_TARGETS := [
	{"type": "HBoxContainer", "name": "separation"},
	{"type": "MarginContainer", "name": "margin_left"},
	{"type": "MarginContainer", "name": "margin_top"},
	{"type": "MarginContainer", "name": "margin_right"},
	{"type": "MarginContainer", "name": "margin_bottom"},
	{"type": "TabBar", "name": "h_separation"},
	{"type": "TabContainer", "name": "side_margin"},
	{"type": "VBoxContainer", "name": "separation"},
]

const STYLEBOX_TARGETS := [
	{"type": "Button", "name": "hover"},
	{"type": "Button", "name": "normal"},
	{"type": "Button", "name": "pressed"},
	{"type": "ItemList", "name": "panel"},
	{"type": "LineEdit", "name": "focus"},
	{"type": "LineEdit", "name": "normal"},
	{"type": "Panel", "name": "panel"},
	{"type": "PanelContainer", "name": "panel"},
	{"type": "PopupMenu", "name": "panel"},
	{"type": "SpinBox", "name": "focus"},
	{"type": "SpinBox", "name": "normal"},
	{"type": "TabBar", "name": "tab_selected"},
	{"type": "TabContainer", "name": "panel"},
	{"type": "TabContainer", "name": "tab_focus"},
	{"type": "TabContainer", "name": "tab_hovered"},
	{"type": "TabContainer", "name": "tab_selected"},
	{"type": "TabContainer", "name": "tab_unselected"},
	{"type": "TabContainer", "name": "tabbar_background"},
	{"type": "TextEdit", "name": "focus"},
	{"type": "TextEdit", "name": "normal"},
	{"type": "Window", "name": "panel"},
]

static func build_scaled_theme(base_theme: Theme, ui_scale: float) -> Theme:
	if base_theme == null:
		return null

	var scaled_theme := base_theme.duplicate(true) as Theme
	var clamped_scale := maxf(ui_scale, 0.5)

	for target in FONT_SIZE_TARGETS:
		var item_type := String(target["type"])
		var item_name := String(target["name"])
		if not base_theme.has_font_size(item_name, item_type):
			continue
		var base_size := base_theme.get_font_size(item_name, item_type)
		scaled_theme.set_font_size(item_name, item_type, max(1, int(round(float(base_size) * clamped_scale))))

	for target in CONSTANT_TARGETS:
		var item_type := String(target["type"])
		var item_name := String(target["name"])
		if not base_theme.has_constant(item_name, item_type):
			continue
		var base_value := base_theme.get_constant(item_name, item_type)
		scaled_theme.set_constant(item_name, item_type, max(1, int(round(float(base_value) * clamped_scale))))

	for target in STYLEBOX_TARGETS:
		var item_type := String(target["type"])
		var item_name := String(target["name"])
		if not base_theme.has_stylebox(item_name, item_type):
			continue
		var base_stylebox := base_theme.get_stylebox(item_name, item_type)
		var scaled_stylebox := _scale_stylebox(base_stylebox, clamped_scale)
		if scaled_stylebox:
			scaled_theme.set_stylebox(item_name, item_type, scaled_stylebox)

	return scaled_theme

static func _scale_stylebox(stylebox: StyleBox, ui_scale: float) -> StyleBox:
	if stylebox == null:
		return null

	var scaled := stylebox.duplicate(true)
	if scaled is StyleBoxFlat:
		var flat := scaled as StyleBoxFlat
		flat.border_width_left = _scale_positive_int(flat.border_width_left, ui_scale)
		flat.border_width_top = _scale_positive_int(flat.border_width_top, ui_scale)
		flat.border_width_right = _scale_positive_int(flat.border_width_right, ui_scale)
		flat.border_width_bottom = _scale_positive_int(flat.border_width_bottom, ui_scale)

		flat.corner_radius_top_left = _scale_positive_int(flat.corner_radius_top_left, ui_scale)
		flat.corner_radius_top_right = _scale_positive_int(flat.corner_radius_top_right, ui_scale)
		flat.corner_radius_bottom_right = _scale_positive_int(flat.corner_radius_bottom_right, ui_scale)
		flat.corner_radius_bottom_left = _scale_positive_int(flat.corner_radius_bottom_left, ui_scale)

		flat.shadow_size = _scale_positive_int(flat.shadow_size, ui_scale)
		flat.shadow_offset = flat.shadow_offset * ui_scale

		flat.content_margin_left = flat.content_margin_left * ui_scale
		flat.content_margin_top = flat.content_margin_top * ui_scale
		flat.content_margin_right = flat.content_margin_right * ui_scale
		flat.content_margin_bottom = flat.content_margin_bottom * ui_scale

	return scaled

static func _scale_positive_int(value: int, ui_scale: float) -> int:
	if value <= 0:
		return value
	return max(1, int(round(float(value) * ui_scale)))
