# KodeFirka: Architecture Overview

This document describes the high-level architecture of KodeFirka, including its folder structure and the roles of its core components.

## Folder Structure

| Directory | Purpose |
| :--- | :--- |
| `scenes/` | Godot Scenes (`.tscn`). Contains the main UI and renderer setup. |
| `scripts/` | GDScript logic files. Core data processing, rendering, undo, tools, and file I/O. |
| `resources/` | Project assets and custom resources like `Palette` and `Theme`. |
| `docs/` | Project documentation and design specifications. |
| `assets/` | Static assets like icons or reference images. |
| `shaders/` | GLSL shaders for brush preview and visual effects. |

## Core Components & Responsibilities

### 1. `CanvasData` (`scripts/canvas_data.gd`)
- **Role**: The pure-logic data model for the ASCII canvas.
- **Responsibilities**:
    - Manages the **Sub-Pixel Grid** (intensity and color).
    - Handles **Dirty-Cell Tracking** to optimize rendering.
    - Implements the **Translation Layer** which maps 6-bit sub-pixel states into ASCII character indices.
    - Stores **Override Characters** (`PackedInt32Array` of Unicode codepoints) for hand-placed text.
    - Decoupled from the Godot scene tree for performance and modularity.

### 2. `CanvasRenderer` (`scripts/canvas_renderer.gd`)
- **Role**: The visual representation of the canvas + input handler.
- **Responsibilities**:
    - Inherits from `Control` and overrides `_draw()` to render characters using `draw_string`.
    - Handles **Input Routing**: Translates mouse positions into sub-pixel coordinates.
    - Implements **Tool System** via `enum Tool { BRUSH, ERASER, BLUR, TEXT, COLOR }`.
    - **Brush**: Paints intensity + color onto sub-pixel grid with feathering and stroke memory.
    - **Eraser**: Subtracts intensity and clears override characters.
    - **Blur/Softener**: Localized 3×3 kernel averaging on the intensity grid.
    - **Color**: Blends colors onto existing painted sub-pixels without modifying intensity. Supports `Mix`, `Add`, and `Multiply` blend modes.
    - **Text Insertion**: Click-to-place cursor, keyboard input writes Unicode codepoints to `override_char`, arrow key navigation, backspace/delete, line wrapping, and static block highlight cursor.
    - Manages **Zooming**: Dynamically scales `cell_size` and font size based on `zoom_level`.
    - Renders override character indicators (subtle bottom-border tint).
    - Manages `brush_color` and `blend_mode` for colored painting.

### 3. `Palette` (`scripts/palette.gd`)
- **Role**: A custom `Resource` defining character sets.
- **Responsibilities**:
    - Stores the available character pool.
    - Contains a **Regional Dictionary** for gradient-based mapping (edges, corners, middle).
    - Can be swapped at runtime via the **Palette Picker** to change the visual "feel" of the art.

### 4. `UndoManager` (`scripts/undo_manager.gd`)
- **Role**: Command-pattern undo/redo system.
- **Responsibilities**:
    - Maintains undo and redo stacks capped at 100 actions.
    - `push_action()`, `undo()`, `redo()` operations.
    - Each `UndoAction` stores only the sub-pixels and cells that actually changed (delta-based).

### 5. `UndoAction` (`scripts/undo_action.gd`)
- **Role**: Represents a single undoable action.
- **Responsibilities**:
    - Stores `intensity_changes: Dictionary` (sub-pixel index → old/new float values).
    - Stores `override_changes: Dictionary` (cell index → old/new codepoints).
    - `apply_undo()` / `apply_redo()` methods that restore values and mark affected cells dirty.

### 6. `ProjectFile` (`scripts/core/project_file.gd`)
- **Role**: Handles `.kfirka` save/load (ZIP archive format).
- **Responsibilities**:
    - `save_project()`: Packs `manifest.json` + binary frame data into a ZIP.
    - `load_project()`: Reads ZIP, parses manifest, reconstructs `CanvasData` from binary.
    - Binary format stores: intensity (float32), color (RGBA float32×4), override_char (int32).

### 7. `Exporter` (`scripts/core/exporter.gd`)
- **Role**: Utility class for handling output formats.
- **Responsibilities**:
    - Transforms `CanvasData` into standard terminal string structures.
    - Exports to `.txt`, `.ans` (with True Color / 256 / 16 color fallbacks), Neofetch maps, and async `.png` rendering.

### 8. `NewProjectDialog` (`scripts/ui/new_project_dialog.gd`)
- **Role**: Handles the creation of fresh projects.
- **Responsibilities**:
    - Provides a UI for setting canvas width and height.
    - Allows selecting the initial palette.
    - Emits a signal to `Main` to initialize a new canvas.

### 8. `Main` (`scripts/main.gd`)
- **Role**: UI Controller and keyboard shortcut hub.
- **Responsibilities**:
    - Connects UI elements (sliders, buttons, color picker, zoom slider) to the `CanvasRenderer`.
    - Manages **File Menu**: New Project, Save Project, Open Project, Export as .txt.
    - Handles **Keyboard Shortcuts**: `Ctrl+N` (new), `Ctrl+Z`/`Ctrl+Shift+Z` (undo/redo), `Ctrl+S`/`Ctrl+O` (save/open), `B`/`E`/`S`/`T` (tool switching).
    - Manages **Scroll Performance**: Resizes the `SubViewport` and `ScrollContainer` to hide lag and handle huge canvases.
    - Loads `ColorPickerButton` from a standalone scene.
    - Manages palette switching and high-level project state.

## Data Flow

1. **Input**: `CanvasRenderer` receives `_gui_input` → routes based on active tool.
2. **Modification**: `CanvasData` updates its `intensity`/`color`/`override_char` arrays → marks affected cells as `dirty`.
3. **Translation**: `CanvasData.translate_dirty()` calculates the **Intensity Gradient Vector** and **Average Density** for each cell. Maps to the active `Palette`'s regional entries. Cells with `override_char` skip translation.
4. **Rendering**: `CanvasRenderer.queue_redraw()` triggers `_draw()` → characters rendered with resolved foreground colors. Override chars shown with subtle indicator.
5. **Undo**: On stroke end, `CanvasRenderer` diffs pre/post intensity → builds `UndoAction` → pushes to `UndoManager`. Text insertions push per-keystroke undo actions.

## Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `B` | Brush tool |
| `E` | Eraser tool |
| `C` | Color tool |
| `S` | Blur/Softener tool |
| `T` | Text insertion mode |
| `Escape` | Exit text mode → Brush |
| `Ctrl+N` | New project |
| `Ctrl+Z` | Undo |
| `Ctrl+Shift+Z` / `Ctrl+Y` | Redo |
| `Ctrl+S` | Save project |
| `Ctrl+O` | Open project |

## File Format: `.kfirka`

A `.kfirka` file is a ZIP archive containing:

| Path | Purpose |
| :--- | :--- |
| `manifest.json` | Canvas size, palette name, version metadata |
| `data/frame_0.bin` | Raw binary data: intensity + color + override_char arrays |
