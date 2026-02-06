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
- `AnimationQueueComponent` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:93`
- `Blackboard` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1573`
- `Box.height` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/core/game.cpp:343`
- `Box.left` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/core/game.cpp:340`
- `Box.top` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/core/game.cpp:341`
- `Box.width` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/core/game.cpp:342`
- `Box` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/core/game.cpp:337`
- `GetLayer` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/core/game.cpp:834`
- `L.WorldQuadtree` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/core/game.cpp:280`
- `WorldQuadtree` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/core/game.cpp:336`
- `add_layer_shader` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/core/game.cpp:849`
- `ai.clear_trace` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1886`
- `ai.dump_blackboard` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:2086`
- `ai.dump_plan` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:2030`
- `ai.dump_worldstate` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:2014`
- `ai.force_interrupt` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1644`
- `ai.get_all_atoms` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:2049`
- `ai.get_blackboard` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1590`
- `ai.get_entity_ai_def` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1080`
- `ai.get_goap_state` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1921`
- `ai.get_trace_events` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1845`
- `ai.get_worldstate` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1120`
- `ai.has_plan` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:2070`
- `ai.list_goap_entities` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1902`
- `ai.list_lua_files` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1647`
- `ai.patch_goal` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1154`
- `ai.patch_worldstate` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1147`
- `ai.pause_ai_system` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1088`
- `ai.report_goal_selection` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1798`
- `ai.resume_ai_system` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1101`
- `ai.set_goal` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1138`
- `ai.set_worldstate` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1114`
- `ai` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1072`
- `animation_system` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:91`
- `bb.clear` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1299`
- `bb.decay` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1381`
- `bb.get_vec2` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1326`
- `bb.get` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1212`
- `bb.has` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1286`
- `bb.inc` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1352`
- `bb.set_vec2` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1312`
- `bb.set` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1165`
- `clearCallbacks` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:399`
- `clear_layer_shaders` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/core/game.cpp:851`
- `createAnimatedObjectWithTransform` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:137`
- `createStillAnimationFromSpriteUUID` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:233`
- `create_ai_entity_with_overrides` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1630`
- `create_ai_entity` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1607`
- `getCurrentFrame` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:284`
- `getFrameCount` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:291`
- `getNinepatchUIBorderInfo` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:116`
- `getProgress` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:305`
- `harness.assert_no_log_level` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/testing/test_harness_lua.cpp:573`
- `harness.clear_logs` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/testing/test_harness_lua.cpp:530`
- `harness.exit` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/testing/test_harness_lua.cpp:414`
- `harness.find_log` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/testing/test_harness_lua.cpp:535`
- `harness.get_attempt` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/testing/test_harness_lua.cpp:419`
- `harness.get_determinism_violations` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/testing/test_harness_lua.cpp:421`
- `harness.has_snapshot` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/testing/test_harness_lua.cpp:498`
- `harness.log_mark` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/testing/test_harness_lua.cpp:524`
- `harness.now_frame` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/testing/test_harness_lua.cpp:412`
- `harness.snapshot_create` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/testing/test_harness_lua.cpp:445`
- `harness.snapshot_delete` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/testing/test_harness_lua.cpp:487`
- `harness.snapshot_restore` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/testing/test_harness_lua.cpp:466`
- `io.open` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/testing/lua_sandbox.cpp:123`
- `io.popen` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/testing/lua_sandbox.cpp:144`
- `isPlaying` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:298`
- `layers` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/core/game.cpp:824`
- `math.random` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/testing/lua_sandbox.cpp:247`
- `math.randomseed` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/testing/lua_sandbox.cpp:271`
- `onAnimationEnd` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:391`
- `onFrameChange` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:375`
- `onLoopComplete` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:383`
- `os.clock` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/testing/lua_sandbox.cpp:227`
- `os.difftime` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/testing/lua_sandbox.cpp:230`
- `os.execute` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/testing/lua_sandbox.cpp:116`
- `os.time` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/testing/lua_sandbox.cpp:223`
- `ownership_table.getBuildId` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/core/ownership.cpp:61`
- `ownership_table.getBuildSignature` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/core/ownership.cpp:65`
- `ownership_table.getDiscordLink` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/core/ownership.cpp:53`
- `ownership_table.getItchLink` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/core/ownership.cpp:57`
- `ownership_table.validate` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/core/ownership.cpp:70`
- `pause` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:319`
- `play` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:312`
- `qmod.box` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/core/game.cpp:324`
- `quadtree` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/core/game.cpp:352`
- `remove_layer_shader` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/core/game.cpp:850`
- `replaceAnimatedObjectOnEntity` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:165`
- `require` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/testing/lua_sandbox.cpp:172`
- `resetAnimationUIRenderScale` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:267`
- `resizeAnimationObjectToFit` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:275`
- `resizeAnimationObjectsInEntityToFitAndCenterUI` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:254`
- `resizeAnimationObjectsInEntityToFit` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:242`
- `seekFrame` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:341`
- `sense.all_in_range` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1509`
- `sense.distance` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1424`
- `sense.nearest` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1436`
- `sense.position` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ai/ai_system.cpp:1411`
- `setDirection` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:359`
- `setFGColorForAllAnimationObjects` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:124`
- `setLoopCount` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:367`
- `setSpeed` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:333`
- `set_flip` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:215`
- `set_horizontal_flip` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:102`
- `setupAnimatedObjectOnEntity` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:201`
- `stop` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:326`
- `tiled.active_map` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:502`
- `tiled.active_map` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:734`
- `tiled.apply_rules` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:623`
- `tiled.apply_rules` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:752`
- `tiled.build_colliders_from_grid` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:633`
- `tiled.build_colliders_from_grid` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:753`
- `tiled.cleanup_procedural` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:723`
- `tiled.cleanup_procedural` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:758`
- `tiled.clear_draw_cache` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:539`
- `tiled.clear_draw_cache` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:742`
- `tiled.clear_generated_colliders` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:715`
- `tiled.clear_generated_colliders` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:755`
- `tiled.clear_maps` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:506`
- `tiled.clear_maps` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:735`
- `tiled.clear_rule_defs` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:619`
- `tiled.clear_rule_defs` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:751`
- `tiled.clear_spawner` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:602`
- `tiled.clear_spawner` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:748`
- `tiled.draw_all_layers_ysorted` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:517`
- `tiled.draw_all_layers_ysorted` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:737`
- `tiled.draw_all_layers` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:511`
- `tiled.draw_all_layers` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:736`
- `tiled.draw_layer_ysorted` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:531`
- `tiled.draw_layer_ysorted` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:740`
- `tiled.draw_layer` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:523`
- `tiled.draw_layer` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:739`
- `tiled.each_object` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:568`
- `tiled.each_object` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:745`
- `tiled.get_objects` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:550`
- `tiled.get_objects` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:744`
- `tiled.get_tile_grid` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:719`
- `tiled.get_tile_grid` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:757`
- `tiled.has_active_map` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:498`
- `tiled.has_active_map` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:733`
- `tiled.load_map` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:479`
- `tiled.load_map` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:730`
- `tiled.load_rule_defs` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:606`
- `tiled.load_rule_defs` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:749`
- `tiled.loaded_maps` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:488`
- `tiled.loaded_maps` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:731`
- `tiled.loaded_rulesets` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:615`
- `tiled.loaded_rulesets` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:750`
- `tiled.object_count` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:543`
- `tiled.object_count` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:743`
- `tiled.set_active_map` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:492`
- `tiled.set_active_map` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:732`
- `tiled.set_spawner` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:580`
- `tiled.set_spawner` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:746`
- `tiled.spawn_objects` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:584`
- `tiled.spawn_objects` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/tiled_loader/tiled_lua_bindings.cpp:747`
- `toggle_flip` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:224`
- `update` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/anim_system.cpp:109`
<!-- AUTOGEN:END binding_list -->

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
