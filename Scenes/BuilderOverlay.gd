@tool
extends CanvasLayer
class_name BuilderOverlay

signal current_animation_dirty_changed(is_dirty: bool)

# --- Node refs ---
var _button_bar_scale: float = 1.0

@export_range(0.25, 4.0, 0.05) var button_bar_scale: float:
	get:
		return _button_bar_scale
	set(value):
		_button_bar_scale = max(value, 0.01)
		_apply_button_bar_scale()
		_position_overlay_controls()

@onready var button_bar: Control = %ButtonBar
@onready var builder_grid: BuilderGrid = %BuilderView
@onready var zoom_controls: Control = %ZoomControls
@onready var btn_zoom_out: Button = %Btn_ZoomOut
@onready var btn_zoom_in: Button = %Btn_ZoomIn
@onready var btn_change_anim: BaseButton = %ChangeAnimation
@onready var popup_anim_switch: PopupMenu = %AnimationSwitcherPopup
@onready var btn_save_anim: BaseButton = %SaveAnimation
@onready var dlg_save_anim: AcceptDialog = %UnsavedAnimationDialogue
@onready var edit_anim_name: LineEdit = %NewAnimName

# Per-animation metadata keys
const KEY_DATA := "data"          # Dictionary from BuilderGrid.build_animation_data()
const KEY_DIRTY := "dirty"
const KEY_SAVED_ONCE := "saved_once"

# Special id for "New Animation..." entry in the popup
const NEW_ANIMATION_ID := 99999

var animations: Dictionary = {}          # name: String -> { data, dirty, saved_once }
var animation_order: Array[String] = []  # ordered list of animation names
var current_animation_idx: int = -1


func _ready() -> void:
	_apply_button_bar_scale()
	call_deferred("_position_overlay_controls")

	if not builder_grid:
		push_warning("BuilderOverlay: BuilderView (BuilderGrid) not found. Check %BuilderView reference.")

	if btn_change_anim:
		btn_change_anim.pressed.connect(_on_change_animation_pressed)

	if btn_zoom_out:
		btn_zoom_out.pressed.connect(_on_zoom_out_pressed)

	if btn_zoom_in:
		btn_zoom_in.pressed.connect(_on_zoom_in_pressed)

	if popup_anim_switch:
		popup_anim_switch.id_pressed.connect(_on_animation_switcher_id_pressed)

	if btn_save_anim:
		btn_save_anim.pressed.connect(_on_save_animation_pressed)

	if dlg_save_anim:
		dlg_save_anim.confirmed.connect(_on_save_dialog_confirmed)

	if builder_grid:
		builder_grid.sequences_changed.connect(_on_grid_sequences_changed)
		builder_grid.resized.connect(_position_overlay_controls)

	_ensure_default_animation()
	_update_save_icon_state()
	_rebuild_animation_switcher_menu()


func _apply_button_bar_scale() -> void:
	var target := button_bar if button_bar else get_node_or_null("%ButtonBar") as Control
	if target == null:
		return

	target.pivot_offset = Vector2.ZERO
	target.scale = Vector2.ONE * _button_bar_scale


func _position_overlay_controls() -> void:
	if builder_grid == null:
		return

	var grid_rect := builder_grid.get_global_rect()

	if button_bar:
		button_bar.position = grid_rect.position + Vector2(15.0, 14.0)

	if zoom_controls:
		var zoom_size := zoom_controls.size
		if zoom_size == Vector2.ZERO:
			zoom_size = zoom_controls.get_combined_minimum_size()
		zoom_controls.position = Vector2(
			grid_rect.end.x - zoom_size.x - 14.0,
			grid_rect.position.y + 14.0
		)


func _on_zoom_out_pressed() -> void:
	if builder_grid:
		builder_grid.zoom_out()


func _on_zoom_in_pressed() -> void:
	if builder_grid:
		builder_grid.zoom_in()


# -------------------------------------------------------------------
# Helpers for per-animation dictionary
# -------------------------------------------------------------------
func _ensure_anim_entry(name: String) -> Dictionary:
	var d: Dictionary = animations.get(name, {})

	if not d.has(KEY_DATA):
		d[KEY_DATA] = {
			"cells": [],
			"sequences": [],
		}
	if not d.has(KEY_DIRTY):
		d[KEY_DIRTY] = false
	if not d.has(KEY_SAVED_ONCE):
		d[KEY_SAVED_ONCE] = false

	animations[name] = d
	return d


func _get_current_anim_name() -> String:
	if current_animation_idx < 0 or current_animation_idx >= animation_order.size():
		return ""
	return animation_order[current_animation_idx]


func _is_current_animation_dirty() -> bool:
	var name := _get_current_anim_name()
	if name == "":
		return false
	var data: Dictionary = animations.get(name, {})
	return bool(data.get(KEY_DIRTY, false))


func _update_save_icon_state() -> void:
	if not btn_save_anim:
		return

	if _is_current_animation_dirty():
		btn_save_anim.modulate = Color(1.0, 0.9, 0.9)  # unsaved
	else:
		btn_save_anim.modulate = Color(1.0, 1.0, 1.0)  # clean


func _get_unique_animation_name(base_name: String, ignore_name: String = "") -> String:
	var name := base_name.strip_edges()
	if name == "":
		name = "Animation"

	var suffix := 1
	while animations.has(name) and name != ignore_name:
		name = "%s_%d" % [base_name, suffix]
		suffix += 1
	return name


# Save current animation's layout into memory (no dialogs)
func _save_current_state_to_memory() -> void:
	var name := _get_current_anim_name()
	if name == "" or not builder_grid:
		return

	var data := _ensure_anim_entry(name)
	data[KEY_DATA] = builder_grid.build_animation_data()
	animations[name] = data


# -------------------------------------------------------------------
# Initialization / default animation
# -------------------------------------------------------------------
func _ensure_default_animation() -> void:
	if animation_order.is_empty():
		var name := "Animation_1"
		var empty_data := {
			"cells": [],
			"sequences": [],
		}
		var d: Dictionary = {
			KEY_DATA: empty_data,
			KEY_DIRTY: false,
			KEY_SAVED_ONCE: false,
		}
		animations[name] = d
		animation_order.append(name)
		current_animation_idx = 0

		if builder_grid:
			builder_grid.load_from_animation_data(empty_data)


# -------------------------------------------------------------------
# Grid change → mark current anim dirty & store full data
# -------------------------------------------------------------------
func _on_grid_sequences_changed(_seqs: Array) -> void:
	var name := _get_current_anim_name()
	if name == "":
		return

	var data := _ensure_anim_entry(name)

	# Always store the full layout+sequences on any change
	if builder_grid:
		data[KEY_DATA] = builder_grid.build_animation_data()

	var was_dirty: bool = data[KEY_DIRTY]
	data[KEY_DIRTY] = true
	animations[name] = data

	if not was_dirty:
		current_animation_dirty_changed.emit(true)
	_update_save_icon_state()


# -------------------------------------------------------------------
# Save Animation behavior
# -------------------------------------------------------------------
func _on_save_animation_pressed() -> void:
	var name := _get_current_anim_name()
	if name == "":
		return

	var data := _ensure_anim_entry(name)

	# First ever save for this animation: ask for a name
	if not data[KEY_SAVED_ONCE]:
		if dlg_save_anim and edit_anim_name:
			edit_anim_name.text = name
			dlg_save_anim.popup_centered()
		return

	# Already saved once: just overwrite in place
	_perform_save_for_animation(name)


func _on_save_dialog_confirmed() -> void:
	var old_name := _get_current_anim_name()
	if old_name == "":
		return
	if not edit_anim_name:
		return

	var base_name := edit_anim_name.text
	var final_name := _get_unique_animation_name(base_name, old_name)

	if final_name != old_name:
		_rename_animation_internal(old_name, final_name)

	_perform_save_for_animation(final_name)


func _perform_save_for_animation(name: String) -> void:
	var data := _ensure_anim_entry(name)

	if builder_grid:
		data[KEY_DATA] = builder_grid.build_animation_data()

	data[KEY_SAVED_ONCE] = true
	data[KEY_DIRTY] = false
	animations[name] = data

	current_animation_dirty_changed.emit(false)
	_update_save_icon_state()
	_rebuild_animation_switcher_menu()

	#  NEW: ask Workspace to write .aam_editor.json
	_request_editor_state_save()

func _request_editor_state_save() -> void:
	# Find the Workspace node and call its save_editor_state() if it exists
	var ws := get_tree().root.find_child("Workspace", true, false)
	if ws and ws.has_method("save_editor_state"):
		ws.call("save_editor_state")
	else:
		print("[BuilderOverlay] Workspace with save_editor_state() not found")

# -------------------------------------------------------------------
# Popup animation switcher
# -------------------------------------------------------------------
func _on_change_animation_pressed() -> void:
	if not popup_anim_switch or not btn_change_anim:
		return
	_rebuild_animation_switcher_menu()

	var button_rect := btn_change_anim.get_global_rect()
	var popup_position := Vector2i(
		int(round(button_rect.end.x)),
		int(round(button_rect.position.y))
	)

	var window := get_window()
	if window != null:
		popup_anim_switch.reset_size()
		var popup_size := popup_anim_switch.size
		var max_x := window.position.x + window.size.x - popup_size.x
		var max_y := window.position.y + window.size.y - popup_size.y
		popup_position.x = clampi(popup_position.x, window.position.x, max_x)
		popup_position.y = clampi(popup_position.y, window.position.y, max_y)

	popup_anim_switch.position = popup_position
	popup_anim_switch.popup()


func _rebuild_animation_switcher_menu() -> void:
	if not popup_anim_switch:
		return

	popup_anim_switch.clear()

	# Existing animations
	for i in range(animation_order.size()):
		var name := animation_order[i]
		var label := name
		if i == current_animation_idx:
			label = "• " + label
		popup_anim_switch.add_item(label, i)

	# Separator + "New Animation..." entry
	popup_anim_switch.add_separator()
	popup_anim_switch.add_item("New Animation...", NEW_ANIMATION_ID)


func _on_animation_switcher_id_pressed(id: int) -> void:
	print("\n[DEBUG] AnimationSwitcher pressed. id =", id)

	if id == NEW_ANIMATION_ID:
		print("[DEBUG] New Animation option selected.")
		
		# Save current animation state
		_save_current_state_to_memory()
		print("[DEBUG] Current animation saved to memory.")

		# Create new animation
		var base := "Animation_%d" % (animation_order.size() + 1)
		var final_name := _get_unique_animation_name(base)
		print("[DEBUG] Creating new animation:", final_name)

		_create_and_switch_to_new_animation(final_name)
	else:
		print("[DEBUG] Switching to animation index:", id)
		_switch_to_animation_index(id)

# -------------------------------------------------------------------
# Switching animations
# -------------------------------------------------------------------
func _switch_to_animation_index(idx: int) -> void:
	if idx < 0 or idx >= animation_order.size():
		return
	if not builder_grid:
		return

	# Save current state before switching
	_save_current_state_to_memory()

	current_animation_idx = idx
	var name := animation_order[idx]
	var data := _ensure_anim_entry(name)

	var anim_data: Dictionary = data[KEY_DATA]
	builder_grid.load_from_animation_data(anim_data)

	current_animation_dirty_changed.emit(bool(data[KEY_DIRTY]))
	_update_save_icon_state()


# -------------------------------------------------------------------
# Creating / renaming animations
# -------------------------------------------------------------------
func _create_and_switch_to_new_animation(name: String) -> void:
	print("[DEBUG] ENTER _create_and_switch_to_new_animation with name:", name)

	var empty_data := {
		"cells": [],
		"sequences": [],
	}

	var d: Dictionary = {
		KEY_DATA: empty_data,
		KEY_DIRTY: false,
		KEY_SAVED_ONCE: false,
	}
	animations[name] = d
	animation_order.append(name)

	current_animation_idx = animation_order.size() - 1
	print("[DEBUG] Switched current_animation_idx to:", current_animation_idx)

	if builder_grid:
		print("[DEBUG] Calling builder_grid.load_from_animation_data(empty_data). BuilderGrid node =", builder_grid)
		builder_grid.load_from_animation_data(empty_data)
	else:
		print("[DEBUG] ERROR: builder_grid is NULL!")
		

func create_new_animation(name: String) -> void:
	# Public helper if you want to create from somewhere else
	if animations.has(name):
		push_warning("Animation '%s' already exists." % name)
		return
	_create_and_switch_to_new_animation(name)


func rename_current_animation(new_name: String) -> void:
	var old_name := _get_current_anim_name()
	if old_name == "":
		return

	var final_name := _get_unique_animation_name(new_name, old_name)
	if final_name == old_name:
		return

	_rename_animation_internal(old_name, final_name)
	_rebuild_animation_switcher_menu()
	_update_save_icon_state()


func _rename_animation_internal(old_name: String, new_name: String) -> void:
	if not animations.has(old_name):
		return

	var data := _ensure_anim_entry(old_name)
	animations.erase(old_name)
	animations[new_name] = data

	var idx := animation_order.find(old_name)
	if idx >= 0:
		animation_order[idx] = new_name

	if current_animation_idx == idx:
		current_animation_idx = idx


# -------------------------------------------------------------------
# Project save/load
# -------------------------------------------------------------------
func build_all_animation_data() -> Dictionary:
	var cur_name := _get_current_anim_name()
	if cur_name != "" and builder_grid:
		var cur_data := _ensure_anim_entry(cur_name)
		cur_data[KEY_DATA] = builder_grid.build_animation_data()
		animations[cur_name] = cur_data

	var stored := {}
	for name in animations.keys():
		var data := _ensure_anim_entry(name)
		stored[name] = data[KEY_DATA]

	return { "animations": stored }


func remove_sprite_asset_references(asset_id: String) -> void:
	if asset_id == "":
		return

	for name in animation_order:
		var data := _ensure_anim_entry(name)
		data[KEY_DATA] = _remove_sprite_from_animation_data(data.get(KEY_DATA, {}), asset_id)
		animations[name] = data

	var current_name := _get_current_anim_name()
	if current_name != "" and builder_grid:
		var current_data := _ensure_anim_entry(current_name)
		builder_grid.load_from_animation_data(current_data.get(KEY_DATA, {}))

	current_animation_dirty_changed.emit(_is_current_animation_dirty())
	_update_save_icon_state()


func load_all_animation_data(project_data: Dictionary) -> void:
	animations.clear()
	animation_order.clear()
	current_animation_idx = -1

	if project_data.has("animations"):
		var src := project_data["animations"] as Dictionary
		for name in src.keys():
			var anim_data: Dictionary = src[name]
			animations[name] = {
				KEY_DATA: anim_data,
				KEY_DIRTY: false,
				KEY_SAVED_ONCE: true,
			}
		var new_order: Array[String] = []
		for k in animations.keys():
			new_order.append(String(k))
		animation_order = new_order
		animation_order.sort()

	if animation_order.is_empty():
		_ensure_default_animation()
	else:
		_switch_to_animation_index(0)

	_rebuild_animation_switcher_menu()
	_update_save_icon_state()


func _remove_sprite_from_animation_data(anim: Dictionary, asset_id: String) -> Dictionary:
	var cleaned := anim.duplicate(true)

	if cleaned.has("cells"):
		var kept_cells: Array = []
		var raw_cells = cleaned.get("cells", [])
		if raw_cells is Array:
			for cell in raw_cells:
				if not (cell is Dictionary):
					continue
				var cell_dict := cell as Dictionary
				if String(cell_dict.get("rel", "")) != asset_id:
					kept_cells.append(cell_dict)
		cleaned["cells"] = kept_cells

	if cleaned.has("sequences"):
		var kept_sequences: Array = []
		var raw_sequences = cleaned.get("sequences", [])
		if raw_sequences is Array:
			for seq in raw_sequences:
				if not (seq is Array):
					continue
				var kept_seq: Array = []
				for rel in seq:
					var rel_str := String(rel)
					if rel_str != asset_id:
						kept_seq.append(rel_str)
				if not kept_seq.is_empty():
					kept_sequences.append(kept_seq)
		cleaned["sequences"] = kept_sequences

	return cleaned
