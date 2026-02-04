# Core Bindings

## Scope
- System focus: scripting utilities, globals table, registry module, and core Lua utilities.
- Primary sources: `src/systems/scripting/scripting_bindings.cpp`, `src/systems/scripting/scripting_functions.cpp`, `src/systems/scripting/registry_bond.cpp`.
- Lua module (non-Sol2, still core API): `assets/scripts/core/component_cache.lua`.
- Context reference: `src/core/globals.cpp` defines the backing globals used by the bindings.

## Binding Construction Patterns
- `lua.set_function("...")` for free functions.
- `lua["globals"]["..."] = ...` for globals table properties.
- `lua.new_usertype<...>("Type", ...)` for usertypes.
- `rec.bind_function(lua, {}, "...")` for helper functions with inline Lua docstrings.
- `lua.require("registry", sol::c_call<...>)` for the registry module.

Repro commands (exact):
- `rg -n "set_function\(|new_usertype<|bind_function\(" src/systems/scripting/scripting_functions.cpp src/systems/scripting/scripting_bindings.cpp`
- `rg -n "lua\[\"globals\"\]" src/systems/scripting/scripting_functions.cpp`
- `rg -n "open_registry|runtime_view|entt\.registry" src/systems/scripting/registry_bond.cpp`
- `rg -n "function component_cache\." assets/scripts/core/component_cache.lua`

## C++ Globals vs Lua Modules
- `globals` is a C++-bound table populated in `exposeGlobalsToLua`.
- `registry` is a C++ registry instance injected into Lua and supplemented by the `registry` module.
- `core.component_cache` is a Lua module that wraps registry access; it is not a Sol2 binding, but it is part of the core Lua-facing API.

## Binding List (Tier 0)
<!-- AUTOGEN:BEGIN binding_list -->
- `Entity` — (usertype) — `src/systems/scripting/scripting_functions.cpp:161`
- `Camera2D` — (usertype) — `src/systems/scripting/scripting_functions.cpp:551`
- `Camera2D.offset` — (property) — `src/systems/scripting/scripting_functions.cpp:559`
- `Camera2D.target` — (property) — `src/systems/scripting/scripting_functions.cpp:560`
- `Camera2D.rotation` — (property) — `src/systems/scripting/scripting_functions.cpp:561`
- `Camera2D.zoom` — (property) — `src/systems/scripting/scripting_functions.cpp:562`
- `OpenURL` — (function) — `src/systems/scripting/scripting_functions.cpp:456`
- `Vector2` — (function) — `src/systems/scripting/scripting_functions.cpp:489`
- `Vector3` — (function) — `src/systems/scripting/scripting_functions.cpp:503`
- `Vector4` — (function) — `src/systems/scripting/scripting_functions.cpp:518`
- `GetFrameTime` — (function) — `GetFrameTime() -> number` — `src/systems/scripting/scripting_functions.cpp:591`
- `GetTime` — (function) — `GetTime() -> number` — `src/systems/scripting/scripting_functions.cpp:596`
- `GetScreenWidth` — (function) — `GetScreenWidth() -> integer` — `src/systems/scripting/scripting_functions.cpp:601`
- `GetScreenHeight` — (function) — `GetScreenHeight() -> integer` — `src/systems/scripting/scripting_functions.cpp:602`
- `GetWorldToScreen2D` — (function) — `GetWorldToScreen2D(position: Vector2, camera: Camera2D) -> Vector2` — `src/systems/scripting/scripting_functions.cpp:603`
- `GetScreenToWorld2D` — (function) — `GetScreenToWorld2D(position: Vector2, camera: Camera2D) -> Vector2` — `src/systems/scripting/scripting_functions.cpp:607`
- `set_shader_texture_batching` — (function) — `src/systems/scripting/scripting_functions.cpp:613`
- `get_shader_texture_batching` — (function) — `src/systems/scripting/scripting_functions.cpp:618`
- `getSpriteFrameTextureInfo` — (function) — `src/systems/scripting/scripting_functions.cpp:670`
- `setPaletteTexture` — (function) — `src/systems/scripting/scripting_functions.cpp:702`
- `getEntityByAlias` — (function) — `src/systems/scripting/scripting_bindings.cpp:18`
- `setEntityAlias` — (function) — `src/systems/scripting/scripting_bindings.cpp:19`
- `log_debug` — (function) — `src/systems/scripting/scripting_bindings.cpp:31`
- `log_error` — (function) — `src/systems/scripting/scripting_bindings.cpp:94`
- `log_info` — (function) — `src/systems/scripting/scripting_bindings.cpp:158`
- `log_warn` — (function) — `src/systems/scripting/scripting_bindings.cpp:210`
- `pauseGame` — (function) — `src/systems/scripting/scripting_bindings.cpp:261`
- `unpauseGame` — (function) — `src/systems/scripting/scripting_bindings.cpp:262`
- `isKeyPressed` — (function) — `src/systems/scripting/scripting_bindings.cpp:271`
- `globals.isGamePaused` — (property) — `boolean` — `src/systems/scripting/scripting_functions.cpp:466`
- `globals.screenWipe` — (property) — `boolean` — `src/systems/scripting/scripting_functions.cpp:467`
- `globals.screenWidth` — (property) — `integer` — `src/systems/scripting/scripting_functions.cpp:468`
- `globals.screenHeight` — (property) — `integer` — `src/systems/scripting/scripting_functions.cpp:469`
- `globals.currentGameState` — (property) — `GameState` — `src/systems/scripting/scripting_functions.cpp:470`
- `globals.inputState` — (property) — `InputState` — `src/systems/scripting/scripting_functions.cpp:473`
- `globals.camera` — (property) — `src/systems/scripting/scripting_functions.cpp:652`
- `globals.gameWorldContainerEntity` — (property) — `Entity` — `src/systems/scripting/scripting_functions.cpp:657`
- `globals.cursor` — (property) — `Entity` — `src/systems/scripting/scripting_functions.cpp:660`
- `globalShaderUniforms` — (property) — `ShaderUniformComponent` — `src/systems/scripting/scripting_functions.cpp:663`
- `entt.registry` — (usertype) — `src/systems/scripting/scripting_system.cpp:263`
- `entt.registry.new` — (property) — `src/systems/scripting/registry_bond.cpp:170`
- `entt.registry.size` — (property) — `src/systems/scripting/registry_bond.cpp:171`
- `entt.registry.alive` — (property) — `src/systems/scripting/registry_bond.cpp:172`
- `entt.registry.valid` — (property) — `src/systems/scripting/registry_bond.cpp:173`
- `entt.registry.current` — (property) — `src/systems/scripting/registry_bond.cpp:174`
- `entt.registry.create` — (property) — `src/systems/scripting/registry_bond.cpp:175`
- `entt.registry.destroy` — (property) — `src/systems/scripting/registry_bond.cpp:176`
- `entt.registry.emplace` — (property) — `src/systems/scripting/registry_bond.cpp:177`
- `entt.registry.add_script` — (property) — `src/systems/scripting/registry_bond.cpp:178`
- `entt.registry.remove` — (property) — `src/systems/scripting/registry_bond.cpp:179`
- `entt.registry.has` — (property) — `src/systems/scripting/registry_bond.cpp:180`
- `entt.registry.any_of` — (property) — `src/systems/scripting/registry_bond.cpp:181`
- `entt.registry.get` — (property) — `src/systems/scripting/registry_bond.cpp:182`
- `entt.registry.clear` — (property) — `src/systems/scripting/registry_bond.cpp:183`
- `entt.registry.orphan` — (property) — `src/systems/scripting/registry_bond.cpp:184`
- `entt.registry.runtime_view` — (property) — `src/systems/scripting/registry_bond.cpp:185`
- `entt.runtime_view` — (usertype) — `src/systems/scripting/scripting_system.cpp:239`
- `entt.runtime_view.size_hint` — (property) — `src/systems/scripting/registry_bond.cpp:64`
- `entt.runtime_view.contains` — (property) — `src/systems/scripting/registry_bond.cpp:65`
- `entt.runtime_view.each` — (property) — `src/systems/scripting/registry_bond.cpp:66`
- `component_cache.get` — (function) — `component_cache.get(entity, component_type) -> table|nil` — `assets/scripts/core/component_cache.lua:198`
- `component_cache.invalidate` — (function) — `component_cache.invalidate(entity, component_type?) -> nil` — `assets/scripts/core/component_cache.lua:331`<!-- AUTOGEN:END binding_list -->

## Registry API (entt.registry)
**doc_id:** `sol2_usertype_entt_registry`
**Detail Tier:** 1
**Source:** `src/systems/scripting/registry_bond.cpp`

**Summary:** Lua-facing wrapper around the active EnTT registry. Methods are bound as properties on the usertype.

**Methods:**
| Binding | doc_id | Signature | Notes | Verified |
| --- | --- | --- | --- | --- |
| `entt.registry.new` | `sol2_property_entt_registry_new` | `registry.new() -> registry` | Constructs a new registry | No |
| `entt.registry.size` | `sol2_property_entt_registry_size` | `registry.size() -> integer` | Total entities | No |
| `entt.registry.alive` | `sol2_property_entt_registry_alive` | `registry.alive() -> integer` | Alive entities | No |
| `entt.registry.valid` | `sol2_property_entt_registry_valid` | `registry.valid(entity) -> boolean` | Validity check | No |
| `entt.registry.current` | `sol2_property_entt_registry_current` | `registry.current(entity) -> integer` | Version for entity | No |
| `entt.registry.create` | `sol2_property_entt_registry_create` | `registry.create() -> Entity` | Create entity | Yes — `core.registry.create.basic` |
| `entt.registry.destroy` | `sol2_property_entt_registry_destroy` | `registry.destroy(entity) -> integer` | Destroy entity, returns version | No |
| `entt.registry.emplace` | `sol2_property_entt_registry_emplace` | `registry.emplace(entity, comp_type) -> table|nil` | Adds component by meta type | Yes — `core.registry.emplace.basic` |
| `entt.registry.add_script` | `sol2_property_entt_registry_add_script` | `registry.add_script(entity, script_table) -> nil` | Attach ScriptComponent | No |
| `entt.registry.remove` | `sol2_property_entt_registry_remove` | `registry.remove(entity, type_or_id) -> integer` | Remove component | No |
| `entt.registry.has` | `sol2_property_entt_registry_has` | `registry.has(entity, type_or_id) -> boolean` | Component check | No |
| `entt.registry.any_of` | `sol2_property_entt_registry_any_of` | `registry.any_of(entity, ...) -> boolean` | Any-of check | No |
| `entt.registry.get` | `sol2_property_entt_registry_get` | `registry.get(entity, type_or_id) -> table|nil` | Get component | Yes — `core.registry.get.basic` |
| `entt.registry.clear` | `sol2_property_entt_registry_clear` | `registry.clear(type_or_id?) -> nil` | Clear registry or type | No |
| `entt.registry.orphan` | `sol2_property_entt_registry_orphan` | `registry.orphan(entity) -> boolean` | True if no components | No |
| `entt.registry.runtime_view` | `sol2_property_entt_registry_runtime_view` | `registry.runtime_view(...) -> runtime_view` | View over components | No |

## Runtime View (entt.runtime_view)
**doc_id:** `sol2_usertype_entt_runtime_view`
**Detail Tier:** 1
**Source:** `src/systems/scripting/registry_bond.cpp`

| Binding | doc_id | Signature | Notes |
| --- | --- | --- | --- |
| `entt.runtime_view.size_hint` | `sol2_property_entt_runtime_view_size_hint` | `runtime_view.size_hint() -> integer` | Entity count hint |
| `entt.runtime_view.contains` | `sol2_property_entt_runtime_view_contains` | `runtime_view.contains(entity) -> boolean` | Membership check |
| `entt.runtime_view.each` | `sol2_property_entt_runtime_view_each` | `runtime_view.each(callback)` | Iterate entities |

## Globals Table (C++ bound)
**doc_id:** `sol2_property_globals_*`
**Detail Tier:** 1
**Source:** `src/systems/scripting/scripting_functions.cpp`

| Property | doc_id | Type | Notes | Verified |
| --- | --- | --- | --- | --- |
| `globals.isGamePaused` | `sol2_property_globals_isgamepaused` | bool | Pause state | No |
| `globals.screenWipe` | `sol2_property_globals_screenwipe` | bool | Screen wipe flag | No |
| `globals.screenWidth` | `sol2_property_globals_screenwidth` | int | Virtual width | Yes — `core.globals.screen_dimensions` |
| `globals.screenHeight` | `sol2_property_globals_screenheight` | int | Virtual height | Yes — `core.globals.screen_dimensions` |
| `globals.currentGameState` | `sol2_property_globals_currentgamestate` | GameState | Current state enum | No |
| `globals.inputState` | `sol2_property_globals_inputstate` | InputState | Input state reference | No |
| `globals.camera` | `sol2_property_globals_camera` | Camera2D | Render camera | No |
| `globals.gameWorldContainerEntity` | `sol2_property_globals_gameworldcontainerentity` | Entity | Root game world entity | No |
| `globals.cursor` | `sol2_property_globals_cursor` | Entity | Cursor entity | No |

**Global singleton:**
- `globalShaderUniforms` — `sol2_property_globalshaderuniforms` — global shader uniform set used by `shader_pipeline`.

## Free Functions (C++ bound)
**Detail Tier:** 1
**Sources:** `src/systems/scripting/scripting_bindings.cpp`, `src/systems/scripting/scripting_functions.cpp`

### Logging + Alias Helpers
| Binding | doc_id | Signature | Notes |
| --- | --- | --- | --- |
| `getEntityByAlias` | `sol2_function_getentitybyalias` | `getEntityByAlias(alias) -> Entity|nil` | Lookup by alias |
| `setEntityAlias` | `sol2_function_setentityalias` | `setEntityAlias(alias, entity) -> nil` | Assign alias |
| `log_debug` | `sol2_function_log_debug` | `log_debug([entity], ...) -> nil` | Variadic debug log |
| `log_error` | `sol2_function_log_error` | `log_error([entity], ...) -> nil` | Variadic error log |
| `log_info` | `sol2_function_log_info` | `log_info([tag], ...) -> nil` | Tagged info log |
| `log_warn` | `sol2_function_log_warn` | `log_warn([tag], ...) -> nil` | Tagged warning log |

### Game State + Input
| Binding | doc_id | Signature | Notes |
| --- | --- | --- | --- |
| `pauseGame` | `sol2_function_pausegame` | `pauseGame() -> nil` | Sets pause flag |
| `unpauseGame` | `sol2_function_unpausegame` | `unpauseGame() -> nil` | Clears pause flag |
| `isKeyPressed` | `sol2_function_iskeypressed` | `isKeyPressed(key) -> boolean` | Key lookup with magic_enum |

### Core Utility Functions
| Binding | doc_id | Signature | Notes | Verified |
| --- | --- | --- | --- | --- |
| `OpenURL` | `sol2_function_openurl` | `OpenURL(url) -> nil` | Opens system browser | No |
| `Vector2` | `sol2_function_vector2` | `Vector2(x, y)` or `Vector2({x,y})` | Helper constructor | No |
| `Vector3` | `sol2_function_vector3` | `Vector3(x, y, z)` or `Vector3({x,y,z})` | Helper constructor | No |
| `Vector4` | `sol2_function_vector4` | `Vector4(x, y, z, w)` or `Vector4({x,y,z,w})` | Helper constructor | No |
| `GetFrameTime` | `sol2_function_getframetime` | `GetFrameTime() -> number` | Smoothed delta time | Yes — `core.globals.delta_time` |
| `GetTime` | `sol2_function_gettime` | `GetTime() -> number` | Elapsed time | No |
| `GetScreenWidth` | `sol2_function_getscreenwidth` | `GetScreenWidth() -> integer` | Virtual width | Yes — `core.globals.screen_dimensions` |
| `GetScreenHeight` | `sol2_function_getscreenheight` | `GetScreenHeight() -> integer` | Virtual height | Yes — `core.globals.screen_dimensions` |
| `GetWorldToScreen2D` | `sol2_function_getworldtoscreen2d` | `GetWorldToScreen2D(pos, cam) -> Vector2` | World to screen | No |
| `GetScreenToWorld2D` | `sol2_function_getscreentoworld2d` | `GetScreenToWorld2D(pos, cam) -> Vector2` | Screen to world | No |
| `set_shader_texture_batching` | `sol2_function_set_shader_texture_batching` | `set_shader_texture_batching(enabled) -> nil` | Shader batching toggle | No |
| `get_shader_texture_batching` | `sol2_function_get_shader_texture_batching` | `get_shader_texture_batching() -> boolean` | Shader batching state | No |
| `getSpriteFrameTextureInfo` | `sol2_function_getspriteframetextureinfo` | `getSpriteFrameTextureInfo(id) -> table|nil` | Atlas/frame lookup | No |
| `setPaletteTexture` | `sol2_function_setpalettetexture` | `setPaletteTexture(shaderName, filePath) -> boolean` | Loads palette texture | No |

## Lua Module: component_cache (non-Sol2)
**doc_id:** `sol2_function_component_cache_get`, `sol2_function_component_cache_invalidate`
**Detail Tier:** 1
**Source:** `assets/scripts/core/component_cache.lua`

| Binding | doc_id | Signature | Notes | Verified |
| --- | --- | --- | --- | --- |
| `component_cache.get` | `sol2_function_component_cache_get` | `component_cache.get(entity, comp) -> table|nil` | Per-frame cache | Yes — `core.component_cache.get.basic` |
| `component_cache.invalidate` | `sol2_function_component_cache_invalidate` | `component_cache.invalidate(entity, comp?) -> nil` | Cache clear | Yes — `core.component_cache.invalidate.on_destroy` |

## Extractor Gaps
Items not captured by `scripts/extract_sol2_bindings.py` but present in the bindings:
- `globals.isGamePaused`, `globals.screenWipe`, `globals.screenWidth`, `globals.screenHeight`, `globals.currentGameState`, `globals.inputState`, `globals.gameWorldContainerEntity`, `globals.cursor`
- `GetFrameTime`, `GetTime`, `GetScreenWidth`, `GetScreenHeight`, `GetWorldToScreen2D`, `GetScreenToWorld2D`
- `globalShaderUniforms`
- `component_cache.get`, `component_cache.invalidate` (Lua module, not Sol2)

## Usage Frequency (selected)
Commands used:
- `rg -n 'registry\.create' assets/scripts`
- `rg -n 'registry\.emplace' assets/scripts`
- `rg -n 'registry\.get' assets/scripts`
- `rg -n 'component_cache\.get' assets/scripts`
- `rg -n 'globals\.screenWidth' assets/scripts`
- `rg -n 'GetScreenWidth' assets/scripts`
- `rg -n 'log_info' assets/scripts`

Results (files_with_match / total_occurrences, raw `rg` without comment filtering):
- `registry.create`: 3 / 5
- `registry.emplace`: 2 / 4
- `registry.get`: 4 / 8
- `component_cache.get`: 99 / 808
- `globals.screenWidth`: 58 / 188
- `GetScreenWidth`: 11 / 22
- `log_info`: 14 / 57

## CM Candidates (draft)
- **cm:core.registry.cache_component_access** — doc_id: `cm:core.registry.cache_component_access` — Test: `core.component_cache.get.basic`
  - Prefer `component_cache.get` for repeated per-frame access to avoid repeated `registry.get` calls.
- **cm:core.globals.use_getframetime** — doc_id: `cm:core.globals.use_getframetime` — Test: `core.globals.delta_time`
  - Use `GetFrameTime()` for smoothed delta time instead of tracking your own timer in Lua.
