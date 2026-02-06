# Tiled Support Implementation Plan

**Date:** 2026-02-06  
**Status:** In Progress  
**Primary Goal:** Add first-class Tiled map support (alongside LDtk), including physics, entity spawning/rendering, optional vertical sprite sorting, and programmatic autotiling for procedural maps.

## Implementation Progress (2026-02-06)

Completed in code:

- Tiled parser scaffold (`.tmj/.tsj`) with GID decode, chunk/layer/object/property parsing.
- Runtime autotile evaluator (`tiled.apply_rules`) with deterministic bitmask-rule selection.
- Runtime ruleset loading from `rules.txt` via `runtime_json` references.
- Lua object APIs:
  - `tiled.object_count`
  - `tiled.get_objects`
  - `tiled.each_object`
  - `tiled.set_spawner` / `tiled.spawn_objects`
- Procedural physics bridge:
  - `tiled.build_colliders_from_grid`
  - `tiled.clear_generated_colliders`
  - `tiled.cleanup_procedural` now also clears generated colliders.
- Lua procgen integration + demo scaffolding:
  - `assets/scripts/core/procgen/tiled_bridge.lua`
  - `assets/scripts/examples/tiled_quickstart.lua`
  - `assets/scripts/tests/test_procgen_tiled_bridge.lua`
- Full-capability demo orchestration:
  - `assets/scripts/examples/tiled_capability_demo.lua`
  - exercises map draw, layer draw, y-sort, object read/spawn, procedural rules, and collider build in one run.
- Demo regression checklist:
  - `docs/plans/2026-02-06-tiled-capability-demo-checklist.md`
- Tiled render binding compile fix:
  - `src/systems/tiled_loader/tiled_lua_bindings.cpp` now includes `layer_command_buffer.hpp`
  - added internal forward declaration for `ResolveMapIdOrThrow(...)`
- Required asset-wall coverage artifacts:
  - Runtime wall rulesets for `dungeon_mode` and `dungeon_437`.
  - Coverage validator script + tests + generated report (`wall_rule_coverage_report.json`).

Validation run for this slice:

- Focused C++ compile checks for updated Tiled sources (`tiled_loader.cpp`, `tiled_lua_bindings.cpp`, `test_tiled_loader.cpp`).
- Standalone C++ smoke tests for runtime rules and object traversal passed.
- Python tests passed:
  - `scripts/tests/test_tiled_asset_inventory.py`
  - `scripts/tests/test_tiled_wall_rule_coverage.py`
- Lua wrapper test passed:
  - `assets/scripts/tests/test_procgen_tiled_bridge.lua`
- Lua capability demo flow test passed:
  - `assets/scripts/tests/test_tiled_capability_demo.lua`

---

## 1. Why This Plan Exists

The engine already has a strong LDtk integration, but many marketplace environment packs ship with Tiled rules/maps and are intended to be dropped in quickly (for example, packs that include `.tmj/.tsj`, automap rules, and Tiled-authored layer/object metadata).

This plan adds a parallel `tiled_loader` pipeline so Tiled content can be used without breaking the current LDtk workflow.

---

## 2. Current Integration Anchors (What We Reuse)

These are the code paths we should mirror or hook into:

- LDtk map draw path:
  - `src/systems/ldtk_loader/ldtk_combined.hpp:439` (`DrawAllLayers`)
  - `src/core/game.cpp:2185` (calls `ldtk_loader::DrawAllLayers(...)` in world draw)
- Existing active map lifecycle:
  - `src/systems/ldtk_loader/ldtk_combined.hpp:621` (`SetActiveLevel`)
- Existing procedural Y-sort rendering pattern:
  - `src/systems/ldtk_loader/ldtk_combined.hpp:1390` (`DrawProceduralLayerYSorted`)
- Existing programmatic rule pipeline pattern to mirror:
  - `src/systems/ldtk_loader/ldtk_lua_bindings.cpp:307` (`ldtk.apply_rules`)
  - `src/systems/ldtk_loader/ldtk_lua_bindings.cpp:559` (`draw_procedural_layer_ysorted`)
  - `assets/scripts/core/procgen/ldtk_rules.lua:192` (`Rules.apply_rules`)
- Entity z-order path:
  - `src/core/game.cpp:2107` / `src/core/game.cpp:2153` (`LayerOrderComponent.zIndex`)
  - `src/systems/layer/layer_command_buffer.cpp:27` (stable sort by z/space)
- Physics world tagging + routing:
  - `src/systems/physics/physics_components.hpp:23` (`PhysicsLayer`)
  - `src/systems/physics/physics_components.hpp:31` (`PhysicsWorldRef`)
- Existing tilemap contour collider helper:
  - `src/systems/physics/physics_world.cpp:2182` (`CreateTilemapColliders`)
  - `src/systems/physics/physics_lua_bindings.cpp:1540` (`create_tilemap_colliders`)
- Existing merged-rect collider path from grid:
  - `src/systems/ldtk_loader/ldtk_lua_bindings.cpp:366` (`build_colliders_from_grid`)

---

## 3. Definition Of “Fully Supported Tiled”

Minimum bar for “fully supported” in this engine:

1. Load Tiled map JSON (`.tmj`) and external tilesets (`.tsj`).
2. Render tile layers with correct tile flips/rotations and layer ordering.
3. Build static colliders from map data with configurable physics tags/world.
4. Spawn entities from object layers (tile and shape objects) via callback API.
5. Support vertical sprite sorting for top-down maps.
6. Use Tiled autotiling rules programmatically against procedural grids at runtime.
7. Keep LDtk support intact and selectable per map/content pipeline.
8. Fully analyze and cover the two required asset sets (no omissions), then ship a demo that exercises all Tiled capabilities in this plan.

Nice-to-have in first release:

1. Authoring conventions for Tiled Automapping outputs.
2. Conversion utility for `.tmx -> .tmj` at import time (optional).

---

## 4. Scope And Non-Goals

In scope:

- Runtime support for Tiled JSON map format.
- Runtime support for Tiled tileset JSON references.
- Runtime API to apply Tiled-authored autotile rules to procedural grid input.
- Layer/object properties mapped to engine concepts.
- Physics and navmesh dirtying integration.
- Full coverage audit and rule-authoring workflow for:
  - `/Users/joshuashin/Projects/TheGameJamTemplate/assets/graphics/pre-packing-files_globbed/dungeon_mode`
  - `/Users/joshuashin/Projects/TheGameJamTemplate/assets/graphics/pre-packing-files_globbed/dungeon_437`

Out of scope for v1:

- Runtime XML `.tmx` parser (prefer offline conversion first).
- Full Tiled editor embedding in engine tools.
- Hex/iso/staggered map rendering (orthogonal first).
- Full parity with every Tiled Automapping edge feature in v1 (ship a well-defined supported subset first).

---

## 5. Architecture Decision

Implement a **parallel loader**:

- New subsystem: `src/systems/tiled_loader/`
- Keep LDtk code untouched except for a small draw/lifecycle routing point in `game.cpp`.
- Mirror LDtk-facing API shape to lower script learning cost.

Proposed API shape:

- C++:
  - `tiled_loader::LoadConfig(...)` or `LoadMap(...)`
  - `tiled_loader::HasActiveMap()`
  - `tiled_loader::SetActiveMap(mapName, worldName, rebuildColliders, spawnEntities, physicsTag)`
  - `tiled_loader::DrawAllLayers(layerPtr, mapName, scale, baseZ, viewOpt)`
  - `tiled_loader::ClearColliders(...)`
  - `tiled_loader::SpawnObjects(...)`
  - `tiled_loader::LoadRuleDefs(...)`
  - `tiled_loader::ApplyRules(grid, rulesetId, options)`
- Lua (module `tiled`):
  - `tiled.load_config(...)` / `tiled.load_map(...)`
  - `tiled.set_active_map(...)`
  - `tiled.draw_all_layers(...)`
  - `tiled.each_object(...)`
  - `tiled.set_spawner(...)`
  - `tiled.build_colliders(...)`
  - `tiled.load_rule_defs(...)`
  - `tiled.apply_rules(grid, ruleset, opts?)`
  - `tiled.draw_procedural_layer(...)`
  - `tiled.draw_procedural_layer_ysorted(...)`
  - `tiled.cleanup_procedural()`
  - `tiled.has_active_map()` / `tiled.active_map()`

---

## 6. Data Contract For Plug-And-Play Tiled Assets

### 6.1 Supported Tiled file setup (v1)

- Map: `.tmj`
- Tilesets: `.tsj` and image sheets
- Orientation: `orthogonal`
- Tile size: derive from map/tileset values (with strict validation)

### 6.2 Property conventions (engine contract)

Layer properties:

- `collider = true|false`
- `physics_world = "world"` (optional)
- `physics_tag = "WORLD"` (optional)
- `nav_obstacle = true|false` (optional)
- `render = true|false` (optional)
- `z_base = <int>` (optional)
- `y_sort = true|false` (optional per layer)

Object properties:

- `spawn_type = "<prefab_or_script_key>"`
- `physics_tag = "<tag>"`
- `physics_world = "<world>"`
- `z_mode = "fixed" | "y_sort"`
- `z_index = <int>`

Tileset/tile properties:

- `collider = true|false`
- `material = "<string>"` (future use)

If properties are missing, defaults should preserve current engine behavior and never hard-fail map load unless data is invalid.

### 6.3 Programmatic autotiling contract (procedural input)

Input grid contract (Lua):

- `width`: integer
- `height`: integer
- `cells`: row-major 1D array (`idx = y * width + x + 1`) of terrain/material ids

Ruleset sources (v1):

- Primary: Tiled Automapping assets (`rules.txt` + referenced rule maps/tilesets)
- Fallback mode: simplified bitmask rules declared in JSON for packs without automapping files

Runtime output contract:

- Tile result table equivalent to LDtk-style flow:
  - `width`, `height`, `cells[]`
  - each cell has one or more tiles:
    - `tile_id`, `flip_x`, `flip_y`, `rotation`, `offset_x`, `offset_y`, `opacity`

Determinism:

- `tiled.apply_rules(...)` must be deterministic for the same `(grid, ruleset, seed/options)`.
- Tie-break behavior (when multiple rules match) must be documented and test-covered.

### 6.4 Required asset coverage contract (mandatory)

Target sources:

- `/Users/joshuashin/Projects/TheGameJamTemplate/assets/graphics/pre-packing-files_globbed/dungeon_mode` (256 files)
- `/Users/joshuashin/Projects/TheGameJamTemplate/assets/graphics/pre-packing-files_globbed/dungeon_437` (256 files)

Coverage requirements:

- Build an inventory manifest for every tile/sprite in both folders (no missing files).
- Classify assets into authoring groups (at minimum: walls, floors, liquids, doors/gates, stairs/ladders, hazards/traps, props/decoration, UI/symbols, entities/items).
- Produce autotiling rule definitions for map-geometry-relevant groups, especially walls (plus floors/liquids where applicable).
- Explicitly mark non-autotile assets (for object placement, UI, entities, pickup icons, etc.) so omissions are intentional and documented.
- Add a coverage check that fails if any source asset is uncategorized.

---

## 7. Implementation Phases

## Phase 0: Contract + Fixtures

Deliverables:

- Add 2-3 Tiled fixture maps in `assets` (small, medium, infinite/chunked).
- Add 2 procedural fixture grids with expected autotile outputs.
- Build a machine-readable asset inventory + taxonomy for both required folders.
- Add a short Tiled authoring guide draft with required property names.
- Freeze v1 parser/render support matrix.

Exit criteria:

- Fixtures load in parser smoke tests.
- Team agrees on property naming contract.
- Team agrees on supported Automapping subset for runtime rule execution.
- Coverage report shows 100% of files in both required folders accounted for.

## Phase 1: Core Parser (`.tmj/.tsj`)

Deliverables:

- JSON deserialization for maps, tilesets, layers, chunks, objects, properties.
- Asset path resolution for external tilesets and images.
- Correct global tile ID decode (`firstgid` and flip/rotation flag bits).
- Parse and index automapping artifacts (`rules.txt`, rule maps, source layers, output layers).
- Normalized in-memory structs similar to existing loader patterns.

Acceptance criteria:

- Unit tests for:
  - GID decode with all flag combinations.
  - Multiple tilesets with mixed `firstgid`.
  - Infinite map chunk coordinates (including negatives).
  - Property type conversion (bool/int/float/string/color).
  - `rules.txt` parsing and rule-map reference resolution.

## Phase 1B: Programmatic Autotiling Runtime

Deliverables:

- Rules compiler that converts supported Tiled automap rules into an engine runtime representation.
- Grid matcher/evaluator that applies compiled rules to procedural input grids.
- Lua API parity with existing LDtk pattern:
  - `tiled.load_rule_defs(...)`
  - `tiled.apply_rules(grid, ruleset, opts?)`
  - `tiled.get_tile_grid(...)` for custom rendering/filtering
- Author rule sets derived from required asset taxonomy:
  - wall-focused rules (mandatory),
  - additional terrain rules where relevant (floors/liquids/edges/transitions).
- Optional debug tooling:
  - per-cell match trace
  - rule hit counters

Acceptance criteria:

- Procedural grid can be autotiled using a Tiled-authored ruleset with no manual rule translation.
- Output is deterministic and matches expected fixtures.
- Runtime cost is acceptable for target map sizes (documented budget + benchmark case).
- Wall autotiling demonstrates complete variant coverage from required asset sets (corners, junctions, edges, transitions where present).

## Phase 2: Rendering Integration

Deliverables:

- Tile layer draw function that queues `CmdTexturePro`.
- Camera culling equivalent to LDtk flow.
- Per-layer visibility/opacity/parallax support.
- Draw support for procedural autotile output (`tiled.draw_procedural_layer*`).
- Draw routing in `src/core/game.cpp` to choose LDtk or Tiled active content.

Acceptance criteria:

- Tiled layers render in correct order.
- Flip/rotation visually match Tiled preview.
- No regression in LDtk render path.

## Phase 3: Physics + Navmesh Integration

Deliverables:

- Collider build from:
  - dedicated collision tile layer(s), and/or
  - object layers with shapes/rect/polygon/polyline.
- Use `PhysicsWorldRef` + `PhysicsLayer` on generated entities.
- Mark navmesh dirty when colliders change.
- Collision generation mode toggle:
  - merged rectangles (grid-based),
  - contour segments (`CreateTilemapColliders`) for smoother boundaries.

Acceptance criteria:

- World geometry collides correctly with player/projectiles in fixture maps.
- Switching active maps clears old map colliders safely.
- Navmesh updates on map load and collider rebuild.

## Phase 4: Object Layer Entity Spawning

Deliverables:

- `tiled.set_spawner(callback)` API parity with `ldtk.set_spawner(...)`.
- Callback includes:
  - object name/type/class,
  - world coordinates,
  - layer name,
  - tile ID (if tile object),
  - custom properties table.
- Support tile object and geometric object primitives.

Acceptance criteria:

- Spawn callback can recreate existing LDtk-style content patterns.
- Object fields are accessible in Lua without custom parser glue per map.

## Phase 5: Vertical Sprite Sorting

Deliverables:

- Two compatible modes:
  - `tile-layer y-sort`: per-row z increment when drawing tile layers.
  - `entity y-sort`: optional system that updates `LayerOrderComponent.zIndex` from world y.
- Configurable formula and offsets to avoid fighting UI or fixed-z entities.

Acceptance criteria:

- Top-down character movement correctly passes behind/in front of props by y.
- Stable ordering with existing command buffer sort (`layer_command_buffer.cpp:27`).

## Phase 6: Tiled Automapping Authoring + Import Workflow

Deliverables:

- Documentation for using Tiled automapping outputs with engine layer/property conventions.
- Optional import helper script:
  - validate map conventions,
  - validate runtime-supported automapping subset and warn on unsupported constructs,
  - validate required asset coverage manifest (fail on uncategorized/missing assets),
  - convert `.tmx -> .tmj`,
  - copy/normalize referenced assets.

Acceptance criteria:

- A marketplace-style pack can be dropped in with minimal manual edits.
- Validation script reports actionable errors (missing tileset, bad property types, etc.).
- Procedural autotiling from those same packs can run through `tiled.apply_rules(...)`.

## Phase 7: Hardening + Docs + Rollout

Deliverables:

- Integration tests parallel to existing LDtk test style:
  - `assets/scripts/tests/ldtk_integration_test.lua` pattern as template.
- User docs:
  - “LDtk vs Tiled selection guide”
  - “Tiled map setup checklist”
- Performance pass on large maps and chunked maps.
- Create a Tiled capability demo scene/map that uses all implemented features:
  - static + procedural autotiling,
  - collider generation,
  - object spawning,
  - vertical sorting,
  - representative assets from both required folders.

Acceptance criteria:

- Stable map load/unload cycles (no collider leaks).
- Render and physics performance within acceptable frame budget on target map sizes.
- Demo scene validates end-to-end feature coverage and can be run as a regression scenario.

---

## 8. Risk Register (High-Value Pitfalls)

1. Tiled GID flag handling is easy to get wrong; must clear high-bit flags before `firstgid` lookup.
2. Infinite map chunks can have negative chunk coordinates; world-space placement must be exact.
3. Tile object origin/alignment differs from plain tile layer cells; object spawn placement can be off by tile height.
4. Property schema drift (`type` vs `class`, version-specific keys) must be normalized.
5. Layer blend modes/tint/opacity mismatches can cause visual differences from Tiled editor.
6. Collider duplication on map reload if cleanup lifecycle is not symmetric.
7. Tiled automapping feature breadth is large; unsupported rule constructs must fail clearly during validation.
8. Asset set breadth (512 files total) can cause accidental blind spots without strict inventory validation.

---

## 9. Test Strategy

Automated:

- Parser unit tests (format correctness and edge cases).
- Integration tests for:
  - map load/activate/deactivate cycles,
  - collider counts and collision behavior,
  - object spawn callbacks with properties,
  - y-sort ordering correctness,
  - programmatic autotiling parity (input grid -> expected tile output).
- Asset coverage tests:
  - taxonomy covers all files in required folders,
  - rule coverage checks for mandatory wall autotile variants.

Manual:

- Visual parity checks against Tiled editor screenshot for fixture maps.
- Physics debug draw verification for collision layers/object colliders.
- Playtest pass with one external Tiled asset pack.
- Procedural map generation pass using the same external ruleset via `tiled.apply_rules(...)`.
- Demo playthrough checklist confirming each implemented capability is exercised in one run.

---

## 10. Suggested Execution Order (Practical)

1. Build parser + fixtures first (Phases 0-1).
2. Implement programmatic autotile runtime API (Phase 1B).
3. Wire render path and get visual output (Phase 2).
4. Add colliders and navmesh updates (Phase 3).
5. Add object spawning API (Phase 4).
6. Add y-sort controls (Phase 5).
7. Finish drop-in workflow + docs + tests (Phases 6-7).

This ordering gives early visible progress and avoids blocking on advanced workflow features.

---

## 11. Immediate Next Tasks (First Work Session)

1. Scaffold `src/systems/tiled_loader/` with parser data structs and `LoadMap`.
2. Add a tiny `.tmj + .tsj` fixture and a parser smoke test target.
3. Implement and test GID decode utility (with flag-bit stripping).
4. Add inventory script/check that scans both required asset folders and outputs taxonomy coverage.
5. Add `rules.txt` parser scaffold + one compiled-rule fixture test.
6. Stub Lua API: `tiled.load_rule_defs(...)` and `tiled.apply_rules(...)` (returning empty result initially).
7. Add minimal draw of one tile layer into existing `sprites` layer.
8. Add feature flag/config switch to toggle LDtk vs Tiled active map path.
9. Create a running checklist for the final “all capabilities” Tiled demo scene.
