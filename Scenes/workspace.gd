extends Control

# Target proportions
const MAIN_VS_FRACTION_TOP := 0.70
const HS_FRACTION_LEFT      := 0.68
const RIGHT_VS_FRACTION_TOP := 0.40

# Sidebar (vertical tabs) desired minimum width
const ASSETS_TABBAR_MIN := 160

# Fallback mins if any pane reports 0 (prevents collapse)
const FALLBACK_MIN_BUILDER   := Vector2i(600, 360)
const FALLBACK_MIN_PREVIEW   := Vector2i(320, 200)
const FALLBACK_MIN_INSPECTOR := Vector2i(320, 280)
const FALLBACK_MIN_ASSETS    := Vector2i(400, 180)

# --- Node refs (adjust paths if your names differ) ---
@onready var vs_main_assets: VSplitContainer       = $RootVBox/VS_Main_Assets
@onready var hs_edit_sidebar: HSplitContainer      = $RootVBox/VS_Main_Assets/HS_Edit_Sidebar
@onready var vs_preview_inspector: VSplitContainer = $RootVBox/VS_Main_Assets/HS_Edit_Sidebar/VS_Preview_Inspector
@onready var assets_tabs_split: HSplitContainer    = $RootVBox/VS_Main_Assets/AssetsPanel/HSplitContainer

@onready var builder_panel: Control   = $RootVBox/VS_Main_Assets/HS_Edit_Sidebar/BuilderPanel
@onready var preview_panel: Control   = $RootVBox/VS_Main_Assets/HS_Edit_Sidebar/VS_Preview_Inspector/PreviewPanel
@onready var inspector_panel: Control = $RootVBox/VS_Main_Assets/HS_Edit_Sidebar/VS_Preview_Inspector/InspectorPanel
@onready var assets_tabbar: Control   = $RootVBox/VS_Main_Assets/AssetsPanel/HSplitContainer/AssetsTabBar
@onready var assets_tabs: Control     = $RootVBox/VS_Main_Assets/AssetsPanel/HSplitContainer/AssetsTab  # If yours is "AssetsTabs", change here.

func _ready() -> void:

	# 1) Make sure everything can expand
	_force_expand_and_minimums()

	# 2) Apply after layout settles (defer twice)
	call_deferred("_apply_responsive_splits_deferred")

	# 3) Refit on window/viewport resize (deferred)
	get_window().size_changed.connect(func(): call_deferred("_apply_responsive_splits_deferred"))
	get_viewport().size_changed.connect(func(): call_deferred("_apply_responsive_splits_deferred"))

func _apply_responsive_splits_deferred() -> void:
	# Wait one more frame to ensure sizes are final during resize drags on some platforms
	await get_tree().process_frame
	_apply_responsive_splits()

func _force_expand_and_minimums() -> void:
	# Root fills window
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# All main containers expand
	for p in [
		"RootVBox/VS_Main_Assets",
		"RootVBox/VS_Main_Assets/HS_Edit_Sidebar",
		"RootVBox/VS_Main_Assets/HS_Edit_Sidebar/VS_Preview_Inspector",
		"RootVBox/VS_Main_Assets/AssetsPanel/HSplitContainer"
	]:
		var n := get_node_or_null(p) as Control
		if n:
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			n.size_flags_vertical   = Control.SIZE_EXPAND_FILL

	# Panels expand + fallback mins to avoid zeros
	_set_min(builder_panel,   FALLBACK_MIN_BUILDER)
	_set_min(preview_panel,   FALLBACK_MIN_PREVIEW)
	_set_min(inspector_panel, FALLBACK_MIN_INSPECTOR)
	_set_min(assets_tabs,     FALLBACK_MIN_ASSETS)
	# sidebar width hint
	if assets_tabbar:
		if assets_tabbar.custom_minimum_size.x < ASSETS_TABBAR_MIN:
			var cms := assets_tabbar.custom_minimum_size
			cms.x = ASSETS_TABBAR_MIN
			assets_tabbar.custom_minimum_size = cms

func _set_min(ctrl: Control, fallback: Vector2i) -> void:
	if ctrl == null:
		return
	var min := ctrl.get_combined_minimum_size()
	var cms := ctrl.custom_minimum_size
	if min.x <= 0 and cms.x <= 0:
		cms.x = fallback.x
	if min.y <= 0 and cms.y <= 0:
		cms.y = fallback.y
	ctrl.custom_minimum_size = cms
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctrl.size_flags_vertical   = Control.SIZE_EXPAND_FILL

func _apply_responsive_splits() -> void:
	# Sanity: SplitContainers must have exactly two children
	_assert_two_children(vs_main_assets)
	_assert_two_children(hs_edit_sidebar)
	_assert_two_children(vs_preview_inspector)
	_assert_two_children(assets_tabs_split)

	# Guard zero sizes (can happen during initial layout)
	if vs_main_assets.size.y <= 0 or hs_edit_sidebar.size.x <= 0 or vs_preview_inspector.size.y <= 0:
		return

	# Top vs bottom
	_fit_vsplit(
		vs_main_assets,
		MAIN_VS_FRACTION_TOP,
		_min_h(vs_main_assets, true),
		_min_h(vs_main_assets, false)
	)

	# Builder vs right stack
	_fit_hsplit(
		hs_edit_sidebar,
		HS_FRACTION_LEFT,
		_min_w(hs_edit_sidebar, true),
		_min_w(hs_edit_sidebar, false)
	)

	# Preview vs inspector
	_fit_vsplit(
		vs_preview_inspector,
		RIGHT_VS_FRACTION_TOP,
		_min_h(vs_preview_inspector, true),
		_min_h(vs_preview_inspector, false)
	)

	# Assets: left vertical tab bar vs tab content
	if assets_tabs_split.size.x > 0:
		var total_w: float = assets_tabs_split.size.x
		var left_min: float = max(ASSETS_TABBAR_MIN, _min_w(assets_tabs_split, true))
		var right_min: float = _min_w(assets_tabs_split, false)
		# ~18% or min; also ensure right side gets its minimum
		var desired_left: int = max(int(total_w * 0.18), int(left_min))
		var max_left: int = int(total_w) - int(right_min)
		assets_tabs_split.split_offset = clamp(desired_left, int(left_min), max_left)

# --- Helpers (assume exactly two children) ---
func _child_ctrl(split: SplitContainer, idx: int) -> Control:
	var c := split.get_child(idx)
	return c as Control

func _min_w(split: SplitContainer, left_or_top: bool) -> float:
	var idx: int = 0 if left_or_top else 1
	var target: Control = _child_ctrl(split, idx)
	if target == null:
		return 0.0
	return max(1.0, target.get_combined_minimum_size().x)

func _min_h(split: SplitContainer, left_or_top: bool) -> float:
	var idx: int = 0 if left_or_top else 1
	var target: Control = _child_ctrl(split, idx)
	if target == null:
		return 0.0
	return max(1.0, target.get_combined_minimum_size().y)

func _fit_hsplit(split: HSplitContainer, fraction_left: float, min_left: float, min_right: float) -> void:
	var total: float = max(1.0, split.size.x)
	var desired: int = int(total * clamp(fraction_left, 0.0, 1.0))
	var min_off: int = int(min_left)
	var max_off: int = int(total - min_right)
	split.split_offset = clamp(desired, min_off, max_off)

func _fit_vsplit(split: VSplitContainer, fraction_top: float, min_top: float, min_bottom: float) -> void:
	var total: float = max(1.0, split.size.y)
	var desired: int = int(total * clamp(fraction_top, 0.0, 1.0))
	var min_off: int = int(min_top)
	var max_off: int = int(total - min_bottom)
	split.split_offset = clamp(desired, min_off, max_off)

func _assert_two_children(split: SplitContainer) -> void:
	if split == null: return
	if split.get_child_count() != 2:
		push_warning("%s should have exactly 2 children, has %d" % [split.name, split.get_child_count()])
