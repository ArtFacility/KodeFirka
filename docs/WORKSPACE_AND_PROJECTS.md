# Project Management & User Context

This document outlines the architecture and implementation details for how KodeFirka handles project sessions, UI boot sequences, settings persistence, and file management across operating systems.

## 1. Project Picker Boot Screen
**Scene:** `scenes/project_picker.tscn`  
**Controller:** `scripts/project_picker.gd`

KodeFirka no longer boots directly into an empty IDE canvas. Instead, the entry point (`run/main_scene`) is the Project Picker.

### Key Capabilities
- **Splash Art & Versioning:** Reads an ASCII art file (`res://splashart.txt`) and dynamically parses the engine version from `ProjectSettings` (`application/config/version`) to remove hardcoded metadata UI. 
- **Recent Projects UI:** Generates memory-based quick-launch buttons pointing directly to `user://` indexed files, alongside mechanisms to purge cache items.
- **Boot Delegation:** Prepares a `startup_action` object. Rather than instancing the `main.tscn` heavily configured, it sets the parameters of what the IDE should build into the `UserSettings` autoload, allowing `main.gd` a clean initiation before interpreting start instructions (New Vs Open).

---

## 2. Dynamic ASCII Reveal Component
**Component:** `scripts/ascii_reveal_label.gd`

To create a cohesive "hacking terminal" visual feel upon booting, the text labels on the Splash Screen utilize a custom animation component.

### Architecture
- **Inheritance:** Extends standard Godot `Label`.
- **Matrix Style Wave:** Uses `_process(delta)` to march a "revealed" boundary left-to-right across columns.
- **Visual Integrity:** Checks against white spacing `[' ', '\n', '\t', '\r']` so the image's bounding silhouette handles the noise transition cleanly. Any valid character forward of the wave cycles rapidly through `.,-=*+:%$#@`.
- **Usage Example:**
```gdscript
var splash_label = AsciiRevealLabel.new()
# Inject random scrambling config if needed
splash_label.scramble_chars = "#*+0101" 
splash_label.reveal_speed = 35.0
splash_label.start_reveal(file.get_as_text())
```

---

## 3. Persistent User Settings
**Autoload Singleton:** `UserSettings` (`scripts/user_settings.gd`)  
**Storage Location:** `user://settings.cfg`

Provides global access for configuration that outlives single runtime sessions. By sticking strictly to the ConfigFile format on the `user://` abstraction layer, Godot ensures that user profiles bridge natively whether on Linux Flatpak ecosystems or raw Windows architectures.

### Tracked Memory
- **History Limits:** Constrains recent launches `.kfirka` lists to `10` maximum items.
- **Deferred Launch Contexts:** Maintains `startup_action: Dictionary` acting as a single-use instruction packet for scenes bootstrapping into one another.

---

## 4. Workspaces & .kfirka Enhancements
**Handler:** `scripts/project_file.gd`

KodeFirka projects are packed as zipped structures representing binary sub-pixel arrays and metadata maps. 

### Custom Background Support
- `manifest.json` now records a `bg_color` configuration mapped from user UI choices.
- In `main.tscn`, an added `ColorPickerButton` synchronizes this variable immediately to `CanvasRenderer.canvas_bg_color`, firing an un-stacked queue redraw. 
- On `load_project()`, missing definitions seamlessly fall back to dark-gray defaults `#0d0d0f`, ensuring old `.kfirka` formats don't brick the renderer.
