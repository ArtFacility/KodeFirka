# KodeFirka: Architecture Overview

This document describes the high-level architecture of KodeFirka, including its folder structure and the roles of its core components.

## Folder Structure

| Directory | Purpose |
| :--- | :--- |
| `scenes/` | Godot Scenes (`.tscn`). Contains the main UI and renderer setup. |
| `scripts/` | GDScript logic files. Core data processing and rendering logic. |
| `resources/` | Project assets and custom resources like `Palette` and `Theme`. |
| `docs/` | Project documentation and design specifications. |
| `assets/` | Static assets like icons or reference images. |

## Core Components & Responsibilities

### 1. `CanvasData` (`scripts/canvas_data.gd`)
- **Role**: The pure-logic data model for the ASCII canvas.
- **Responsibilities**:
    - Manages the **Sub-Pixel Grid** (intensity and color).
    - Handles **Dirty-Cell Tracking** to optimize rendering.
    - Implements the **Translation Layer** which maps 6-bit sub-pixel states into ASCII character indices.
    - Decoupled from the Godot scene tree for performance and modularity.

### 2. `CanvasRenderer` (`scripts/canvas_renderer.gd`)
- **Role**: The visual representation of the canvas.
- **Responsibilities**:
    - Inherits from `Control` and overrides `_draw()` to render characters using `draw_string`.
    - Handles **Input Routing**: Translates mouse positions into sub-pixel coordinates.
    - Implements **Brush and Eraser** logic.
    - Manages the `SubViewport` container for free zoom and panning.

### 3. `Palette` (`scripts/palette.gd`)
- **Role**: A custom `Resource` defining character sets.
- **Responsibilities**:
    - Stores the available character pool.
    - Contains a **Regional Dictionary** for gradient-based mapping (edges, corners, middle).
    - Can be swapped at runtime via the **Palette Picker** to change the visual "feel" of the art.

### 4. `Main` (`scripts/main.gd`)
- **Role**: UI Controller.
- **Responsibilities**:
    - Connects UI elements (sliders, buttons) to the `CanvasRenderer`.
    - Manages high-level project state (though currently minimal).

## Data Flow

1. **Input**: `CanvasRenderer` receives `_gui_input` -> calculates affected sub-pixels.
2. **Modification**: `CanvasData` updates its `intensity` array -> marks affected cells as `dirty`.
3. **Translation**: `CanvasData.translate_dirty()` calculates the **Intensity Gradient Vector** and **Average Density** for each cell. It maps these values to the active `Palette`'s regional entries.
4. **Rendering**: `CanvasRenderer.queue_redraw()` triggers `_draw()` -> only `render_dirty` cells are re-drawn.
