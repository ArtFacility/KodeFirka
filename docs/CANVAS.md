# KodeFirka: Canvas Deep Dive

This document provides a technical explanation of how the KodeFirka canvas works, from the sub-pixel level to the final ASCII display.

## 1. The Sub-Pixel Grid (2x3)

The core innovation of KodeFirka is that each visible ASCII character is backed by a **2x3 grid of sub-pixels**.

```text
Cell Layout (2x3 Sub-Pixels):
+---+---+
| 0 | 1 |  (Sub-row 0)
+---+---+
| 2 | 3 |  (Sub-row 1)
+---+---+
| 4 | 5 |  (Sub-row 2)
+---+---+
```

- **Intensity**: Each sub-pixel stores a `float` (0.0 to 1.0).
- **Color**: Each sub-pixel stores a `Color` value.
- **Why 2x3?**: Terminal characters are typically twice as tall as they are wide. A 2x3 ratio matches the aspect ratio of most monospace fonts.

## 2. Brush and Intensity

To control the painting experience, the following parameters are used:
- **Brush Size**: The radius of the affected area in sub-pixels.
- **Opacity**: The maximum intensity change per stroke (0.0 to 1.0).
- **Feathering**: The softness of the brush edge (0.0 to 1.0), implemented with a `smoothstep` falloff to avoid harsh edges.

## 3. The Translation Process

When a cell is modified, it is marked as `dirty`. The translation layer (`CanvasData._translate_cell`) then performs a geometric analysis:

1. **Regional Averaging**: It calculates the average intensity for the **Top, Bottom, Left, and Right** halves of the 2x3 grid.
2. **Gradient Vector**: It derives a vector `(Right - Left, Bottom - Top)`. The magnitude of this vector represents the "edge strength" (how concentrated the ink is on one side).
3. **Region Decoding**:
    - If the gradient magnitude is low (< 0.15), the cell is classified as **`middle`**.
    - If the magnitude is high, the vector's angle is used to classify the cell into one of 8 regions: **`top`, `bottom`, `left`, `right`, `top_left`, `top_right`, `bottom_left`, `bottom_right`**.
4. **Intensity Leveling**: The total average intensity of all 6 sub-pixels is mapped to an index in the selected region's character array (e.g., Level 1, 2, 3...).
5. **Pseudo-Randomization**: If a level contains multiple characters, a position-based hash ensures consistent dithering without flickering.

## 4. Color Resolution

Currently, KodeFirka implements a **dominant color** logic:
- The engine averages the colors of all "ON" sub-pixels in a cell.
- This average becomes the **foreground color** (`fg_colors`).
- If no sub-pixels are "ON", the foreground defaults to White.
- (Future refinement will include background color support and perceptual color matching).

## 5. Performance: Dirty-Cell System

To ensure smooth performance at high resolutions:
- Instead of re-translating and re-drawing the entire canvas every frame, KodeFirka uses a **Dirty-Cell System**.
- **`dirty` flag**: Marks cells whose sub-pixels have changed. Only these are re-translated.
- **`render_dirty` flag**: Marks cells that need to be re-drawn to the screen.
- This allows for large canvases (e.g., 200x200+) to remain responsive even during rapid painting.

## 6. Rendering Details

The `CanvasRenderer` uses Godot's `draw_string` method.
- **Font**: Uses a `SystemFont` with common monospace fallbacks (`Consolas`, `Courier New`, `DejaVu Sans Mono`).
- **Positioning**: Characters are drawn with a baseline offset to ensure they fit correctly within the defined `cell_size`.
- **Zoom/Pan**: Handled via a `SubViewportContainer` which isolates the high-resolution canvas rendering from the UI controls.
