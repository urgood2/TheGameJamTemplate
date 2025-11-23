# LDtk Integration Notes

Status: **Implemented and wired to Lua**, lightly exercised, not yet fully tested in-game.

## What Landed
- Combined `LDtkLoader` (render-ready project/level/entity access) and `ldtkimport` (auto-layer rule runner) into `src/systems/ldtk_loader/ldtk_combined.hpp`.
- Added config-driven project loading (`assets/ldtk_config.json`) plus caching for tilesets/backgrounds.
- Lua surface area (see `src/systems/scripting/scripting_functions.cpp`): `ldtk.load_config`, `set_spawner`, `spawn_entities`, `prefab_for`, `each_intgrid`, `collider_layers`, `build_colliders`, `clear_colliders`, `set_active_level`, `active_level`, `has_active_level`.
- Rendering hook in `src/core/game.cpp` draws the active LDtk level every frame (with camera culling).
- Physics helpers build static colliders from IntGrid layers and keep navmesh dirtiness in sync with `PhysicsManager`.

## Quick Start (Lua)
```lua
-- 1) Point at your LDtk project/config (path is relative to assets/)
ldtk.load_config("ldtk_config.json")

-- 2) (Optional) map LDtk entities to your prefab ids
local function spawn(name, px, py, layer, gx, gy, tags)
  local prefab = ldtk.prefab_for(name)  -- looks up config.entity_prefabs[name]
  if prefab ~= "" then
    prefab.spawn(prefab, px, py)
  end
end
ldtk.set_spawner(spawn)

-- 3) Choose a level + physics world (default world name is "world")
ldtk.set_active_level("Level_0", "world", true, true, "WORLD")
```

`set_active_level` will clear old LDtk colliders, rebuild IntGrid colliders for the new level, optionally spawn entities via your spawner, and update the active level so `game.cpp` renders it.

## Config File (`assets/ldtk_config.json`)
- `project_path` (required): relative path to the `.ldtk` file.
- `asset_dir`: prefix for tileset/background images inside the LDtk project.
- `collider_layers`: names of **IntGrid** layers to convert to static colliders.
- `entity_prefabs`: optional map of `ldtkEntityName -> prefabId` for use inside Lua.

Example:
```json
{
  "project_path": "world.ldtk",
  "asset_dir": "assets",
  "collider_layers": ["TileLayer"],
  "entity_prefabs": { "PlayerSpawn": "player_prefab" }
}
```

Sample script: `require("examples.ldtk_quickstart").run({ level = "Level_0" })` will load `assets/ldtk_config.json`, bind a simple spawner, build colliders in physics world `"world"`, and render the level.

## Runtime Behavior Highlights
- **Rendering:** `ldtk_loader::DrawAllLayers` draws background (color + image with scissoring) then layers back-to-front. `game.cpp` calls it automatically when an active level exists; you can pass a camera culling rect via `CameraViewRect`.
- **Entities:** `ForEachEntity`/`SpawnEntities` iterate all entities per layer. `set_spawner` installs a Lua callback that receives `(name, px, py, layer, gx, gy, tagsTable)`.
- **IntGrid access:** `each_intgrid(level, layer, cb)` lets Lua inspect raw int values for custom logic (AI, nav, decorations).
- **Colliders:** `build_colliders(level, worldName, tag)` turns non-zero IntGrid cells from configured `collider_layers` into horizontal rectangles per row, tags them with `PhysicsWorldRef`, `PhysicsLayer`, and an `LDTKColliderTag` (level/layer), and marks the navmesh dirty via `PhysicsManager`.
- **Active level lifecycle:** `set_active_level` clears colliders from the previous level (if any), records the active physics world name for cleanup, then rebuilds/spawns as requested. `clear_colliders` is available for manual cleanup.
- **Caching/unload:** Tilesets/backgrounds are cached; `ReloadProject` calls `Unload` first to free textures and reset state.

## Older Rule-Import Path
The `ldtk_rule_import` namespace (auto-layer rule runner) remains available for procedural generation/debug draws, but it is not yet connected to the new Lua helpers. Use `SetLevel`, `LoadDefinitions`, `RunRules`, and `DrawGridLayer` directly if you need that flow.

## Gaps / Next Steps
- No automated tests or sample Lua script exercising the full loop yet; only light manual use.
- Collider generation supports IntGrid-only; no entity shapes or custom metadata yet.
- Prefab lookup is config-only—spawning logic still comes from your `set_spawner` callback.
- Multi-world LDtk projects are not handled; assumes a single world and uses the engine’s physics world name (default `"world"`).
