extends RefCounted
class_name PreviewController

var preview_fps: float = 8.0
var is_playing: bool = true
var loop_enabled: bool = true

var _preview_view: Control = null
var _preview_sprite: AnimatedSprite2D = null
var _preview_audio: AudioStreamPlayer = null
var _builder_grid: BuilderGrid = null
var _frame_sounds: Array = []
var _audio_cache: Dictionary = {}

func setup(preview_view: Control, preview_sprite: AnimatedSprite2D, preview_audio: AudioStreamPlayer, builder_grid: BuilderGrid) -> void:
	_preview_view = preview_view
	_preview_sprite = preview_sprite
	_preview_audio = preview_audio
	_builder_grid = builder_grid

	if _preview_view:
		_preview_view.resized.connect(_position_preview_sprite)

	if _preview_sprite:
		_preview_sprite.frame_changed.connect(_on_preview_frame_changed)
		_position_preview_sprite()


func apply_sequence_preview(sequences: Array) -> void:
	if _preview_sprite == null:
		return

	if sequences.is_empty():
		_preview_sprite.sprite_frames = null
		_frame_sounds.clear()
		return

	var first_seq: Array = sequences[0]
	if first_seq.is_empty():
		_preview_sprite.sprite_frames = null
		_frame_sounds.clear()
		return

	var frames := SpriteFrames.new()
	var anim_name := "preview"
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, preview_fps)
	frames.set_animation_loop(anim_name, loop_enabled)

	for rel in first_seq:
		var tex := _texture_from_sprite_rel(String(rel))
		if tex != null:
			frames.add_frame(anim_name, tex)

	if frames.get_frame_count(anim_name) == 0:
		_preview_sprite.sprite_frames = null
		_frame_sounds.clear()
		return

	_preview_sprite.sprite_frames = frames
	_preview_sprite.animation = anim_name
	_position_preview_sprite()

	if is_playing:
		_preview_sprite.play()
	else:
		_preview_sprite.stop()

	_rebuild_sound_timeline()


func set_playing(enabled: bool) -> void:
	is_playing = enabled

	if _preview_sprite == null:
		return

	var frames := _preview_sprite.sprite_frames
	if frames == null or not frames.has_animation("preview") or frames.get_frame_count("preview") == 0:
		if not is_playing and _preview_audio:
			_preview_audio.stop()
		return

	if is_playing:
		_preview_sprite.play()
	else:
		_preview_sprite.stop()
		if _preview_audio:
			_preview_audio.stop()


func set_loop_enabled(enabled: bool) -> void:
	loop_enabled = enabled

	if _preview_sprite == null:
		return

	var frames := _preview_sprite.sprite_frames
	if frames == null:
		return

	var anim_name := "preview"
	if frames.has_animation(anim_name):
		frames.set_animation_loop(anim_name, loop_enabled)


func set_preview_fps(value: float) -> void:
	preview_fps = value

	if _preview_sprite == null:
		return

	var frames := _preview_sprite.sprite_frames
	if frames == null:
		return

	var anim_name := "preview"
	if frames.has_animation(anim_name):
		frames.set_animation_speed(anim_name, preview_fps)


func clear_audio_cache() -> void:
	_audio_cache.clear()


func _position_preview_sprite() -> void:
	if _preview_view == null or _preview_sprite == null:
		return

	_preview_sprite.position = _preview_view.size * 0.5


func _rebuild_sound_timeline() -> void:
	_frame_sounds.clear()

	if _builder_grid == null:
		return

	var xs: Array = _builder_grid.get_preview_frame_x_positions()
	var by_x: Dictionary = _builder_grid.get_sounds_by_x()

	for i in xs.size():
		var x = xs[i]
		var sounds_for_x: Array = by_x.get(x, [])
		var list: Array = []
		for s in sounds_for_x:
			list.append(String(s))
		_frame_sounds.append(list)


func _on_preview_frame_changed() -> void:
	if _preview_sprite == null:
		return

	var frame_index := _preview_sprite.frame
	if frame_index < 0 or frame_index >= _frame_sounds.size():
		return

	var sounds: Array = _frame_sounds[frame_index]
	for rel in sounds:
		_play_preview_sound(String(rel))


func _play_preview_sound(rel: String) -> void:
	if _preview_audio == null:
		return

	var stream: AudioStream = null
	if _audio_cache.has(rel):
		stream = _audio_cache[rel] as AudioStream
	else:
		var res_path := "res://%s" % rel
		if not ResourceLoader.exists(res_path):
			return

		var res := ResourceLoader.load(res_path)
		if res == null or not (res is AudioStream):
			return

		stream = res as AudioStream
		_audio_cache[rel] = stream

	if stream == null:
		return

	_preview_audio.stream = stream
	_preview_audio.play()


func _texture_from_sprite_rel(rel: String) -> Texture2D:
	var abs: String = ProjectModel.project_dir.path_join(rel)
	if not FileAccess.file_exists(abs):
		return null

	var img := Image.new()
	var err: int = img.load(abs)
	if err != OK:
		return null

	return ImageTexture.create_from_image(img)
