# Runtime Adapter

`runtime/ExportedAnimationPlayer.gd` is the first receiving-project adapter for exported animations.

## What It Does

The adapter reads a `gam_export.v1` manifest and turns it into runtime playback inside a Godot project.

It:

- loads the JSON manifest
- builds a `SpriteFrames` animation from exported frame images
- applies exported `fps` and `loop` settings
- plays frame-linked sounds when the animated sprite changes frame

## Expected Export Layout

The receiving project should contain:

- `art/animations/<animation_name>.json`
- `art/sprites/<animation_name>/...`
- `art/audio/<animation_name>/...`

These paths match the current exporter.

## Basic Usage

1. Copy [runtime/ExportedAnimationPlayer.gd](/Users/johngilbert/Desktop/GameDev/DevTools/GodotAnimationManager/runtime/ExportedAnimationPlayer.gd) into the receiving Godot project.
2. Add a `Node2D` to a scene and attach the script.
3. Set `manifest_path` to an exported manifest such as `res://art/animations/run.json`.
4. Run the scene.

The script auto-creates:

- an `AnimatedSprite2D`
- a small pool of `AudioStreamPlayer` nodes for overlapping sound playback

## Example

```gdscript
var player := ExportedAnimationPlayer.new()
player.manifest_path = "res://art/animations/run.json"
add_child(player)
player.load_manifest()
player.play_animation()
```

## Public API

- `load_manifest(path: String = manifest_path) -> Error`
- `play_animation(animation_name: String = "") -> void`
- `stop_animation() -> void`
- `get_manifest() -> Dictionary`
- `get_loaded_animation_name() -> String`

## Notes

- The adapter currently supports one exported animation per manifest file.
- It expects the exported schema to be exactly `gam_export.v1`.
- Audio is cached after first load.
- Overlapping sounds are supported through a round-robin pool of `AudioStreamPlayer` nodes.

## Good Next Improvements

- Add a reusable `.tscn` scene wrapper for easier drag-and-drop setup.
- Add global asset caching if many instances use the same exported animation.
- Add stronger validation errors for malformed manifests.
- Add support for swapping manifests at runtime.
