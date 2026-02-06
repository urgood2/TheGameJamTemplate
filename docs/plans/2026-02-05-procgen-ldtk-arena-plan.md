# Procgen + LDtk Arena Plan (2026-02-05)

## Goal
Replace the rounded-rect arena with a procedurally generated arena that is auto-tiled using LDtk rules, with colliders, lightweight destructibles, and torch lighting.

## Source LDtk Example (reference)
- Sample file: /Applications/LDtk.app/Contents/extraFiles/samples/Typical_TopDown_example.ldtk
- Rule layers with auto-rules: Default_floor (AutoLayer), Wall_tops (AutoLayer), Collisions (IntGrid)
- AutoLayers are sourced from Collisions IntGrid.

## Rendering Plan
1) Load LDtk rule definitions for the rule runner (procedural auto-tiling).
2) Generate a procedural grid (0 = floor, 1 = wall).
3) Apply LDtk rules once to populate the procedural tile grids.
4) Draw selected rule layers every frame during ACTION_STATE.
   - Default: render Default_floor + Wall_tops.
   - Collisions layer is not rendered unless debugging.

## Collider Plan
- Build colliders from the procedural grid using LDtk collider merging.
- Solid value set: {1}.
- Cell size derived from rule layer tileset (fallback: defaultGridSize).
- Track/cleanup colliders when regenerating.

## Arena Bounds
- Use level dimensions from the LDtk file for grid size and bounds.
- Compute bounds = tiles_w * cell_size, tiles_h * cell_size.
- Set SCREEN_BOUND_LEFT/TOP/RIGHT/BOTTOM from these bounds so camera clamp and spawns follow.

## Destructibles (Lightweight Path)
- Spawn destructible entities separately (not via combat actors).
- Ensure they have GameObject + physics (PhysicsBuilder) so projectiles collide.
- Listen for projectile_hit and subtract HP manually.
- Destroy entity when HP <= 0; play sound and spawn debris.

## Lighting (Torches)
- Torch entities spawn point lights attached to the entity.
- Flicker via timer (intensity + radius jitter).

## Implemented Utilities
- ldtk.load_rule_defs(defPath, assetDir?) binding (Lua).
- ldtk.build_colliders_from_grid now supports solidValues + cellSize.
- New helper module: core.procgen.ldtk_rules
  - load(defPath, assetDir)
  - get_level_dims(level_name?)
  - get_cell_size(rule_layer?)
  - apply_rules(grid, {rule_layer})
  - draw({layers, target_layer, offsets, base_z})
  - build_colliders(grid, {solidValues, cellSize, worldName, physicsTag})

## Open Decisions
- Which rule layer should be used as the primary rule layer for apply_rules?
- Which render layers are enabled by default (Default_floor, Wall_tops)?
- Level identifier to use when deriving arena size (default: first level in file).

## Progress Update (2026-02-06)
- Added `assets/scripts/core/action_arena_ldtk.lua` to manage action-phase arena init/draw/cleanup via LDtk rules.
- Wired action-phase startup in `assets/scripts/core/gameplay.lua` to initialize procedural LDtk arena and set `SCREEN_BOUND_*` from map bounds.
- Replaced the per-frame rounded-rectangle arena draw with LDtk layer drawing (kept rounded fallback if LDtk init fails).
- Added action-to-planning cleanup hook for procedural LDtk arena content.
- Updated `ldtk.build_colliders_from_grid` lifecycle so regenerated colliders are cleaned up correctly.
- Added parser hardening for LDtk def import null strings (`src/third_party/ldtkimport/include/ldtkimport/LdtkDefFile.cpp`) to prevent null `std::string` assignments from malformed/nullable fields.
- Added debug stress loop envs for repeated planning/action transitions:
  - `AUTO_PHASE_LOOP=1`
  - `AUTO_PHASE_LOOP_INTERVAL=1.0`
  - `AUTO_PHASE_LOOP_MAX_TRANSITIONS=20`
