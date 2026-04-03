# Godot Animation Manager

Godot Animation Manager is a standalone Godot 4 desktop tool for building 2D sprite animations with synchronized sound effects, then exporting that authored content into a separate Godot game project with as little receiving-project setup as possible.

The core idea is simple:

- Non-programmers should be able to assemble animations visually.
- The authored result should be portable into another Godot project.
- The receiving project should need minimal custom wiring beyond loading and playing exported animation data.

![Godot Animation Manager screenshot](https://github.com/user-attachments/assets/69f1b52a-7e63-4285-bf4f-74c0de979df7)

## Product Goal

This tool is meant for artists, designers, and mixed-discipline teams who want to author animation content without writing gameplay code.

Instead of building animation behavior directly inside a game scene, the workflow is:

1. Create or open an `.aam` animation project.
2. Import sprite and audio assets.
3. Arrange frames visually in the editor.
4. Preview timing and SFX together.
5. Export data that a separate Godot project can consume.

The long-term design goal is for the authored output to be easy to drop into a receiving Godot project, with only a thin integration layer on the game side.

## Design Principles

- Non-programmer-first authoring workflow.
- Visual editing over hand-authored data files.
- Low integration burden for the receiving Godot project.
- Export formats should be practical and easy for gameplay code to load.
- The editor should remain useful even if the receiving project has custom runtime needs.

## Color Scheme

Use this classic Game Boy-inspired palette for UI and branding decisions across the project:

- `#c4bebb` -> `RGB(196, 190, 187)` : dominant color
- `#272929` -> `RGB(39, 41, 41)` : primarily for borders
- `#494786` -> `RGB(73, 71, 134)` : accent color
- `#9a2257` -> `RGB(154, 34, 87)` : accent color

## What The Tool Currently Does

- Creates and opens `.aam` project files.
- Imports sprites into project-local asset folders.
- Imports audio for per-frame or per-cell use in animations.
- Supports spritesheet splitting during import.
- Lets users build animations in a grid-based editor.
- Supports drag-and-drop placement and repositioning of sprites and sounds.
- Previews animation playback with audio.
- Supports animation naming, switching, and dirty-state handling.
- Supports tagging and filtering sprite assets.
- Stores editor-side state alongside the project.
- Includes export-related UI and linked-repository settings.

## Intended Export / Integration Model

The intended receiving-project experience is:

- Import or copy authored animation assets and data into a Godot project.
- Load exported animation definitions through a lightweight runtime adapter.
- Play animations and synchronized SFX without requiring the game team to recreate the authored setup manually.

The receiving game project may still need some wiring, for example:

- A loader for the exported animation format.
- A runtime node or helper that maps exported data to `AnimatedSprite2D`, `SpriteFrames`, `AudioStreamPlayer`, or a custom animation system.
- Optional asset-path remapping if the receiving project organizes assets differently.

The important constraint is that the game-side integration should stay thin. The heavy lifting should happen in the authoring tool, not in the receiving game project.

## Current Project Structure

High-level entry points:

- [project.godot](project.godot): Godot project configuration. Main scene is `Scenes/MainMenu.tscn`.
- [Scenes/MainMenu.tscn](Scenes/MainMenu.tscn): Startup UI for creating and opening `.aam` projects.
- [Scenes/workspace.tscn](Scenes/workspace.tscn): Main authoring workspace.

Important scripts:

- [ProjectSettings/Autoload/AppState.gd](ProjectSettings/Autoload/AppState.gd): App-level state such as recents and last-used directories.
- [ProjectSettings/Autoload/ProjectModel.gd](ProjectSettings/Autoload/ProjectModel.gd): Core project data loading, saving, asset import, tag persistence, and export-path persistence.
- [Scenes/workspace.gd](Scenes/workspace.gd): Main workspace controller. Currently handles a large amount of UI and editor behavior.
- [Scenes/BuilderView.gd](Scenes/BuilderView.gd): Grid editing surface for placing sprites and sounds.
- [Scenes/BuilderOverlay.gd](Scenes/BuilderOverlay.gd): Animation switching, save behavior, dirty tracking, and editor-state coordination.
- [Scenes/SettingsWindow.gd](Scenes/SettingsWindow.gd): Workspace settings UI.
- [Scenes/SpritesheetDialog.gd](Scenes/SpritesheetDialog.gd): Spritesheet import dialog.
- [SpritesheetUtils.gd](SpritesheetUtils.gd): Spritesheet detection and splitting helpers.

Asset folders:

- [`Assets/`](Assets/): Editor UI assets and sample content used by this tool.
- Project-authored content is stored relative to each `.aam` project, typically under `assets/sprites` and `assets/audio`.

UI/theme structure:

- [`Assets/theme_1.tres`](Assets/theme_1.tres): shared workspace/popup theme for most editor UI.
- [`Assets/mm_theme.tres`](Assets/mm_theme.tres): main-menu-specific theme and button styling.
- [`ProjectSettings/UiTokens.gd`](ProjectSettings/UiTokens.gd): shared palette and spacing tokens for GDScript when values are needed in code.

## Current Architecture Notes

Right now, the workspace is functional but not yet strongly modular.

Known architectural traits:

- `workspace.gd` currently coordinates many concerns at once: asset import, preview, tag UI, settings, export UI, and editor-state persistence.
- `ProjectModel.gd` acts as the main persistence and project-data service.
- `BuilderView.gd` mixes view concerns and grid-state behavior.
- `BuilderOverlay.gd` manages animation-level state separately from the main project model.

This is why refactoring toward clearer modules and services is a good next step.

## Guidance For Future Agents

If you are starting work in a new thread, assume this project is:

- A Godot-based animation authoring tool, not a runtime game system.
- Primarily intended for non-programmers.
- Meant to export animation data and related assets into another Godot project.
- Optimizing for minimal receiving-project setup.

When making changes, keep these priorities in mind:

- Preserve the non-programmer workflow.
- Avoid pushing complexity into the receiving game project unless necessary.
- Prefer explicit, stable data formats over editor-only assumptions.
- Favor modularization that separates authoring UI, project persistence, preview logic, and export/runtime integration concerns.

When evaluating new export behavior, ask:

- Can a separate Godot project consume this without adopting large parts of this editor?
- Does this reduce or increase required game-side wiring?
- Is the exported representation understandable and robust enough for future tooling?

## Development Notes

- Engine target: Godot 4.x.
- Language: GDScript.
- Main scene: `res://Scenes/MainMenu.tscn`.
- Autoload singletons: `AppState` and `ProjectModel`.
- `.godot/` and `.DS_Store` are ignored in git.

## UI Architecture Notes

The UI system should now follow these rules:

- Prefer putting shared visual decisions in [`Assets/theme_1.tres`](Assets/theme_1.tres) or [`Assets/mm_theme.tres`](Assets/mm_theme.tres) instead of scene-local overrides.
- Use scene-level `theme_override_*` values only for intentional exceptions, not as the default way to size text or style controls.
- For popup windows, use the pattern `Window -> MarginContainer -> themed content container`.
- For script-side color or spacing values, use [`ProjectSettings/UiTokens.gd`](ProjectSettings/UiTokens.gd) instead of scattering raw color literals through multiple files.
- Keep layout containers responsible for positioning, and keep controller scripts focused on behavior rather than pixel coordinates whenever possible.

## Near-Term Refactor Direction

The most likely next improvement is to split the workspace into clearer modules, such as:

- asset import and asset-list management
- preview playback
- tag management
- export settings and export flow
- animation/grid state management

That refactor should support the larger product goal: a clean authoring pipeline that exports content into a game project with minimal receiving-side friction.
