# Rendering Architecture: Viewport Culling

This document outlines the core logic and technical implementations deployed inside KodeFirka to ensure highly performant handling of massive Godot canvas systems.

## The Problem Let Loose
Prior to `v0.1 Stable`, creating large canvases (such as 500x500 character grids) would result in complete operating system freezing. Godot's GDScript struggled to linearly loop over 250,000 subpixel instructions (`y * x`) inside standard `_draw()` loops simply because a user moved their mouse. 

Furthermore, loading this entire loop sequence inside a `SubViewport` component forced Godot's 2D Rendering Engine to allocate an actual off-screen memory texture size exceeding ~6000x12000 pixels on demand, murdering VRAM stability.

## The Viewport Culling Solution

To solve this we rely on a strict architectural rule: **Never calculate or render character grids outside the physical perimeter of the user's viewport.**

### 1. Dual-Node Drawing System
Code responsible for tracking user input overlays (like the tool block cursor, text selector, and brush circular previews) has been stripped entirely out of `CanvasRenderer`. 

By instantiating a custom `.new()` lightweight `Control` called `cursor_overlay` mathematically placed on top of the native canvas, mouse movements simply fire a local `queue_redraw()` to that empty layer. The heavy iteration loop inside the core canvas never recalculates until a pixel changes color.

### 2. Affine Transform Culling
When a sub-pixel block *is* manipulated, the massive recalculation function still runs, but is aggressively chained by Viewport Affine Transforms.

```gdscript
var screen_rect = get_viewport_rect()
var global_transform = get_global_transform()
var local_top_left = global_transform.affine_inverse() * Vector2.ZERO
var local_bottom_right = global_transform.affine_inverse() * screen_rect.size
```

Instead of looping from `0` to `500` columns and rows, `CanvasRenderer` translates Godot's internal physical window dimensions and global scroll bar positioning into inverse coordinates. It identifies exactly which Grid Array indexes represent the visual "top left" and "bottom right" of your currently visible monitor setup. 

```gdscript
var start_x = clampi(int(local_top_left.x / cell_size.x) - 1, 0, canvas_width)
var end_x = clampi(int(local_bottom_right.x / cell_size.x) + 2, 0, canvas_width)
```

The nested loop matrix then completely clips all execution falling outside of the integers bounds. This mathematical slice brings calculation stress downwards of 99%, making 500x500 grid operations visually indistinguishable from 10x10 grids.
