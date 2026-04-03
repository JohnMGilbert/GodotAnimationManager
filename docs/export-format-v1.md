# Export Format v1

This document defines the first stable transfer format for moving authored animations from Godot Animation Manager into a separate Godot project.

## Goals

- Keep the receiving-project integration thin.
- Export enough data to reproduce authored playback faithfully.
- Use paths and naming conventions that are stable and easy to inspect.
- Version the format so future changes can be introduced safely.

## Export Package Layout

Each exported animation should create the following files under the receiving Godot project:

- `art/animations/<animation_name>.json`
- `art/sprites/<animation_name>/...`
- `art/audio/<animation_name>/...`

This keeps each animation self-contained and avoids mixing exported content with unrelated game assets.

## Manifest Shape

The exported manifest is JSON with the following structure:

```json
{
  "schema": "gam_export.v1",
  "animation_name": "run",
  "source_project": {
	"name": "player_moves",
	"schema": "aam.v1"
  },
  "playback": {
	"fps": 8.0,
	"loop": true
  },
  "assets": {
	"sprites_dir": "art/sprites/run",
	"audio_dir": "art/audio/run"
  },
  "frames": [
	{
	  "index": 0,
	  "image": "run_01.png",
	  "source_rel": "assets/sprites/run_01.png",
	  "x": 0,
	  "y": 0,
	  "sounds": [
		"step_01.wav"
	  ]
	}
  ]
}
```

## Required Fields

### `schema`

- Type: `String`
- Initial value: `gam_export.v1`
- Purpose: lets the receiving project validate compatibility before loading.

### `animation_name`

- Type: `String`
- Purpose: the public animation identifier the receiving project will play.

### `source_project`

- Type: `Dictionary`
- Required fields:
  - `name: String`
  - `schema: String`
- Purpose: keeps traceability back to the authoring project.

### `playback`

- Type: `Dictionary`
- Required fields:
  - `fps: float`
  - `loop: bool`
- Purpose: preserves authoring-time playback settings so the receiving project does not have to guess timing.

### `assets`

- Type: `Dictionary`
- Required fields:
  - `sprites_dir: String`
  - `audio_dir: String`
- Purpose: gives the runtime adapter stable base paths for loading files.

### `frames`

- Type: `Array`
- Ordered in playback order.
- Each item contains:
  - `index: int`
  - `image: String`
  - `source_rel: String`
  - `x: int`
  - `y: int`
  - `sounds: Array[String]`

`frames` is the most important part of the contract. It gives the receiving project one canonical playback list instead of forcing it to reconstruct timing from editor-only structures.

## Why This Shape

This format matches the current authoring model reasonably well:

- `BuilderView.build_animation_data()` already produces ordered frame data indirectly through `sequences` and also stores exact cell positions through `cells`.
- `sound_cells` can be converted into frame-linked `sounds` arrays during export.
- `PreviewController` already uses project-level `fps` and `loop` concepts, which belong in the exported playback contract.

## Intentional Non-Goals For v1

These are useful later, but should not block the first complete transfer pipeline:

- Multiple named sequences inside one exported animation file
- Blend trees or state-machine behavior
- Per-frame durations that differ from project fps
- Arbitrary receiving-project asset remapping
- Packed `.pck`, `.zip`, or custom binary packaging

## Export Rules

- Export only assets referenced by the selected animation.
- Copy sprite files into `art/sprites/<animation_name>/`.
- Copy audio files into `art/audio/<animation_name>/`.
- Preserve original filenames when possible.
- If a filename collision occurs, the exporter must rename deterministically and reflect the final filename in the manifest.
- Frames must be emitted in the exact playback order used by preview/export.
- Sounds attached to a frame must be listed on that frame's `sounds` array.

## Receiving-Project Expectations

The runtime adapter should be able to:

- load one JSON file
- build `SpriteFrames` from `frames`
- assign `playback.fps`
- assign `playback.loop`
- load and play the filenames listed in each frame's `sounds`

If the receiving project can do that, transfer is working as intended.

## Open Questions

- Where should `fps` and `loop` live in authoring data so export can read them directly?
- Should we support exporting all animations in one pass after the single-animation path is stable?
- Do we want a second export target later that writes native Godot resources such as `.tres` in addition to JSON?
