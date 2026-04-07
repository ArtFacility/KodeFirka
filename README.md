# KodeFirka

A sub-pixel ASCII art editor built with Godot 4.6.2. 

> "This is just a toy I made for myself, don't expect much but I may update it occasionally"

## What is this?

Instead of typical ASCII editors where you place characters one by one, **KodeFirka** lets you paint intensity values into a high-resolution grid (2x3 sub-pixels per character cell). The engine then automatically selects the best matching character in real-time.

## Features

### Core Art Engine
- **Sub-Pixel Painting**: High-resolution painting onto character cells.
- **Gradient-Aware Translation**: The engine analyzes ink flow to pick characters that match boundaries and corners (e.g., curves and edges).
- **Intensity-Based Shading**: Smooth gradients through multi-level character sets.

### Tools
- **Brush**: Configurable size, opacity, and feathering for soft-edge painting.
- **Eraser**: Subtractive painting to refine your art.
- **Palette Picker**: Switch between different character sets (Standard ASCII, Unicode Blocks, etc.) on the fly.

## Getting Started
Download from the releases or:

1. Clone the repo.
2. Open the project in **Godot 4.6.2** (At least thats what I made it in).
3. Run `main.tscn`.
4. Start painting!

## License

This project is licensed under the **Apache License 2.0**. See the [LICENSE](LICENSE) file for details.

---
Have fun artists!