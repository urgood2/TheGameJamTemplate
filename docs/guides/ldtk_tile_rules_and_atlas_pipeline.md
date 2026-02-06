# LDtk Tile Rules + Shared Atlas Pipeline

## Current engine behavior (important)

- Procedural LDtk rendering loads the tileset image directly from `tileset.relPath` in the `.ldtk` file (`src/systems/ldtk_loader/ldtk_combined.hpp`).
- Procedural collider generation for generated grids is exposed via `ldtk.build_colliders_from_grid(...)` (`src/systems/ldtk_loader/ldtk_lua_bindings.cpp`).
- The sprite atlas JSON (`assets/graphics/sprites-0.json`) is trimmed/packed per sprite frame, so it is not a stable grid tileset by default.

Result: LDtk auto-rules need a stable grid tileset image. A generic trimmed sprite atlas page is not directly compatible.

## Recommended pipeline (single source art, no duplicate authoring)

Use one tile source sheet as the art source for both systems:

1. Keep a dedicated fixed-grid tile sheet (for example 16x16 or 32x32) in your art source.
2. Export that sheet as PNG without trim/rotation.
3. Use that same PNG in LDtk as the tileset (`relPath` in `.ldtk`).
4. Also feed that same PNG into your game atlas build as an ordinary sprite asset (optional, for non-LDtk usages).

This gives one art source while keeping LDtk rules deterministic.

## How to create your own LDtk rules

1. Create an `IntGrid` layer (example: `Collisions`) with explicit values.
2. Add AutoLayers (example: `Default_floor`, `Wall_tops`) and set their source to the IntGrid layer.
3. In each AutoLayer, add rule groups and 3x3 patterns.
4. Place output tiles from your tileset for each matching pattern.
5. Keep collisions semantic:
   - `0` = empty/floor
   - `1` = solid wall (or your chosen solid values)
6. Save and test by toggling rule render in LDtk.

## Wiring in this repo

Runtime arena wiring now lives in:

- `assets/scripts/core/action_arena_ldtk.lua`
- `assets/scripts/core/gameplay.lua`
- `assets/scripts/core/procgen/ldtk_rules.lua`

The action-phase flow is:

1. Load LDtk defs.
2. Read level dims/cell size from LDtk.
3. Generate a procedural wall/floor grid.
4. Apply LDtk rules from `Collisions`.
5. Draw `Default_floor` + `Wall_tops`.
6. Build colliders from the same grid.

## Reusing your packed sprite atlas directly (what would be needed)

If you want LDtk to render from packed atlas JSON pages directly (instead of a grid tileset PNG), you need an engine extension:

1. Add an LDtk tile ID -> atlas frame mapping asset.
2. Change procedural draw path to resolve each tile through atlas frame rects.
3. Disable assumptions that tile IDs map to regular grid coordinates.

Without that extension, keep LDtk on a fixed-grid sheet and treat atlas packing as a downstream consumer of the same source art.
