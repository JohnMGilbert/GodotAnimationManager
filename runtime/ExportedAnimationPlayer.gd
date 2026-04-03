extends Node2D
class_name ExportedAnimationPlayer

const SUPPORTED_SCHEMA := "gam_export.v1"

@export_file("*.json") var manifest_path: String = ""
@export var autoplay: bool = true
@export_range(1, 16, 1) var audio_player_count: int = 4

var _sprite: AnimatedSprite2D = null
var _audio_players: Array[AudioStreamPlayer] = []
var _audio_cache: Dictionary = {}
var _frame_sounds: Array = []
var _manifest: Dictionary = {}
var _loaded_animation_name: String = ""
var _next_audio_player_index: int = 0


func _ready() -> void:
	_ensure_runtime_nodes()
	if _sprite and not _sprite.frame_changed.is_connected(_on_sprite_frame_changed):
		_sprite.frame_changed.connect(_on_sprite_frame_changed)
	if manifest_path != "":
		load_manifest(manifest_path)
		if autoplay:
			play_animation()


func load_manifest(path: String = manifest_path) -> Error:
	if path.strip_edges() == "":
		push_error("ExportedAnimationPlayer: manifest_path is empty.")
		return ERR_INVALID_PARAMETER

	var resolved_path := path.strip_edges()
	var file := FileAccess.open(resolved_path, FileAccess.READ)
	if file == null:
		push_error("ExportedAnimationPlayer: failed to open manifest: %s" % resolved_path)
		return ERR_CANT_OPEN

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		push_error("ExportedAnimationPlayer: manifest is not a dictionary: %s" % resolved_path)
		return ERR_PARSE_ERROR

	var manifest := parsed as Dictionary
	var schema := String(manifest.get("schema", ""))
	if schema != SUPPORTED_SCHEMA:
		push_error("ExportedAnimationPlayer: unsupported schema '%s' in %s" % [schema, resolved_path])
		return ERR_FILE_UNRECOGNIZED

	var err := _apply_manifest(manifest)
	if err == OK:
		manifest_path = resolved_path
	return err


func play_animation(animation_name: String = "") -> void:
	if _sprite == null:
		return

	var target_name := animation_name if animation_name != "" else _loaded_animation_name
	if target_name == "":
		return
	if _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation(target_name):
		return

	_sprite.play(target_name)


func stop_animation() -> void:
	if _sprite:
		_sprite.stop()
	for player in _audio_players:
		player.stop()


func get_manifest() -> Dictionary:
	return _manifest.duplicate(true)


func get_loaded_animation_name() -> String:
	return _loaded_animation_name


func _apply_manifest(manifest: Dictionary) -> Error:
	_ensure_runtime_nodes()
	if _sprite == null:
		return ERR_CANT_CREATE

	var animation_name := String(manifest.get("animation_name", ""))
	if animation_name == "":
		push_error("ExportedAnimationPlayer: manifest is missing animation_name.")
		return ERR_INVALID_DATA

	var assets_raw: Variant = manifest.get("assets", {})
	if not (assets_raw is Dictionary):
		push_error("ExportedAnimationPlayer: manifest assets block is invalid.")
		return ERR_INVALID_DATA
	var assets := assets_raw as Dictionary

	var playback_raw: Variant = manifest.get("playback", {})
	if not (playback_raw is Dictionary):
		push_error("ExportedAnimationPlayer: manifest playback block is invalid.")
		return ERR_INVALID_DATA
	var playback := playback_raw as Dictionary

	var frames_raw: Variant = manifest.get("frames", [])
	if not (frames_raw is Array):
		push_error("ExportedAnimationPlayer: manifest frames block is invalid.")
		return ERR_INVALID_DATA
	var frames_data := frames_raw as Array
	if frames_data.is_empty():
		push_error("ExportedAnimationPlayer: manifest contains no frames.")
		return ERR_INVALID_DATA

	var sprites_dir := _normalize_res_path(String(assets.get("sprites_dir", "")))
	var audio_dir := _normalize_res_path(String(assets.get("audio_dir", "")))
	if sprites_dir == "" or audio_dir == "":
		push_error("ExportedAnimationPlayer: manifest asset directories are missing.")
		return ERR_INVALID_DATA

	var fps := float(playback.get("fps", 8.0))
	var loop_enabled := bool(playback.get("loop", true))

	var sprite_frames := SpriteFrames.new()
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_speed(animation_name, fps)
	sprite_frames.set_animation_loop(animation_name, loop_enabled)

	var frame_sounds: Array = []
	for frame_entry in frames_data:
		if not (frame_entry is Dictionary):
			continue
		var frame_dict := frame_entry as Dictionary
		var image_name := String(frame_dict.get("image", ""))
		if image_name == "":
			continue

		var image_path := sprites_dir.path_join(image_name)
		var texture := load(image_path) as Texture2D
		if texture == null:
			push_error("ExportedAnimationPlayer: failed to load texture: %s" % image_path)
			return ERR_FILE_NOT_FOUND

		sprite_frames.add_frame(animation_name, texture)

		var sounds_for_frame: Array = []
		var sounds_raw: Variant = frame_dict.get("sounds", [])
		if sounds_raw is Array:
			for sound_name in sounds_raw:
				var sound_file := String(sound_name)
				if sound_file == "":
					continue
				sounds_for_frame.append(audio_dir.path_join(sound_file))
		frame_sounds.append(sounds_for_frame)

	_sprite.sprite_frames = sprite_frames
	_sprite.animation = animation_name
	_frame_sounds = frame_sounds
	_manifest = manifest.duplicate(true)
	_loaded_animation_name = animation_name
	_preload_audio_paths(frame_sounds)
	return OK


func _ensure_runtime_nodes() -> void:
	if _sprite == null:
		_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if _sprite == null:
			_sprite = AnimatedSprite2D.new()
			_sprite.name = "AnimatedSprite2D"
			add_child(_sprite)

	while _audio_players.size() < audio_player_count:
		var player := AudioStreamPlayer.new()
		player.name = "AudioStreamPlayer_%d" % _audio_players.size()
		add_child(player)
		_audio_players.append(player)


func _on_sprite_frame_changed() -> void:
	if _sprite == null:
		return

	var frame_index := _sprite.frame
	if frame_index < 0 or frame_index >= _frame_sounds.size():
		return

	var sounds: Array = _frame_sounds[frame_index]
	for sound_path in sounds:
		_play_sound_path(String(sound_path))


func _play_sound_path(sound_path: String) -> void:
	if sound_path == "":
		return
	var stream := _load_audio_stream(sound_path)
	if stream == null:
		return
	if _audio_players.is_empty():
		return

	var player := _audio_players[_next_audio_player_index]
	_next_audio_player_index = (_next_audio_player_index + 1) % _audio_players.size()
	player.stream = stream
	player.play()


func _preload_audio_paths(frame_sounds: Array) -> void:
	for sounds in frame_sounds:
		if not (sounds is Array):
			continue
		for sound_path in sounds:
			_load_audio_stream(String(sound_path))


func _load_audio_stream(sound_path: String) -> AudioStream:
	if _audio_cache.has(sound_path):
		return _audio_cache[sound_path] as AudioStream

	var stream := load(sound_path) as AudioStream
	if stream == null:
		push_warning("ExportedAnimationPlayer: failed to load audio stream: %s" % sound_path)
		return null

	_audio_cache[sound_path] = stream
	return stream


func _normalize_res_path(path: String) -> String:
	var trimmed := path.strip_edges()
	if trimmed == "":
		return ""
	if trimmed.begins_with("res://"):
		return trimmed
	return "res://%s" % trimmed.trim_prefix("/")
