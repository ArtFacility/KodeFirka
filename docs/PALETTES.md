# KodeFirka: Palette Guide

This document explains how to create and configure `Palette` resources in KodeFirka.

## 1. Overview

A `Palette` is a Godot `Resource` (`.tres`) that defines the visual character mapping for the brush engine. It uses a **Regional Dictionary** to map different brush stroke geometries to specific character sets.

## 2. The Regional Dictionary (`regional_palette`)

The `regional_palette` property is a `Dictionary` where keys represent geometric regions of a cell and values are **Arrays of Arrays** of characters.

### Available Regions
- `middle`: Characters used when the cell is fully inside a stroke (no gradient).
- `top`, `bottom`, `left`, `right`: Edge characters used when the stroke ends halfway through a cell.
- `top_left`, `top_right`, `bottom_left`, `bottom_right`: Corner characters.

### Intensity Levels
Each region contains an array of "Levels".
- **Level 1**: Used for low overall cell intensity (e.g., light feathering).
- **Level 2 / 3 / etc**: Used for higher intensities.

Example structure:
```json
{
  "top": [
    ["_", ".", ","],  // Level 1: Subtle top border
    ["m", "w", "v"],  // Level 2: Medium top border
    ["g", "p", "q"]   // Level 3: Thick top border
  ]
}
```

## 3. Character Resolution Logic

1. **Direction**: The engine calculates an "ink direction" vector. If you brush a line horizontally, the cells at the top of the line will have a strong `top` gradient.
2. **Selection**: It switches to the `top` palette array.
3. **Density**: It calculates the average lightness (0.0 to 1.0) of those 6 sub-pixels.
4. **Index**: If density is 0.5 and there are 3 levels, it picks Level 2.
5. **Dither**: It picks one of the characters in that level (e.g., "m", "w", or "v") based on a position-based hash to create a procedural texture.

## 4. Creating a New Palette

1. In the Godot Inspector, create a **New Resource** of type `Palette`.
2. Save it as `.tres` in `resources/`.
3. Fill the `regional_palette` dictionary following the structure above.
4. Add it to the **Palette OptionButton** in `scripts/main.gd`.

## 5. Unicode Support

KodeFirka supports any Unicode character (e.g., `█`, `░`, `▗`). 
> **Note**: Ensure the font used in `CanvasRenderer` supports the characters in your palette.
