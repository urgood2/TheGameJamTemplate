# Common Pitfalls Reference

**Last Verified**: 2026-01-30  
**Purpose**: Consolidated reference of the most critical pitfalls, gotchas, and warnings across the codebase  
**Source**: Top 78 pitfalls consolidated from 183 documented across 156 files (full inventory: `.sisyphus/evidence/pitfalls-inventory.md`)

---

## Quick Navigation

- [UI/DSL Pitfalls](#uidsl-pitfalls) - Screen space, z-order, collision, DSL config
- [Physics Pitfalls](#physics-pitfalls) - Collision, steering, arbiter caveats
- [Scripting/Lua Pitfalls](#scriptinglua-pitfalls) - Sol2 bindings, callbacks, signals, timers
- [Content Creation Pitfalls](#content-creation-pitfalls) - Cards, jokers, projectiles, avatars, triggers
- [Combat/Wand Pitfalls](#combatwand-pitfalls) - Wand execution, projectile setup
- [Rendering/Shader Pitfalls](#renderingshader-pitfalls) - Coordinates, pipeline, wrong position
- [Timer Pitfalls](#timer-pitfalls) - Chaining, scopes, physics step timers
- [General Pitfalls](#general-pitfalls) - Camera, particles, profiling, memory

---

## UI/DSL Pitfalls

| # | Pitfall | Symptom | Fix | Source |
|---|---------|---------|-----|--------|
| 1 | Missing `ScreenSpaceCollisionMarker` for UI elements | UI element won't receive clicks | Add `ScreenSpaceCollisionMarker` component to clickable UI entities | claude.md:156 |
| 2 | Wrong `DrawCommandSpace` (World vs Screen) | HUD element follows camera incorrectly | Use `DrawCommandSpace.Screen` for HUD, `DrawCommandSpace.World` for game objects | claude.md:163 |
| 3 | Skipping `CardUIPolicy.setupForScreenSpace` | Wrong collision, wrong z-order, invisible | Always call when adding items to inventory | UI_PANEL_IMPLEMENTATION_GUIDE.md:1008 |
| 4 | Using wrong z-order values | Cards hidden behind panel/grid | Use hierarchy: `PANEL_Z=800`, `GRID_Z=850`, `UI_CARD_Z=z_orders.ui_tooltips+100`, `DRAG_Z=z_orders.ui_tooltips+500` | UI_PANEL_IMPLEMENTATION_GUIDE.md:1010 |
| 5 | Adding `ObjectAttachedToUITag` to standalone UI elements | Elements excluded from all rendering passes | Only use for child objects rendered by parent; standalone UI elements with shaders must NOT have this tag | UI_PANEL_IMPLEMENTATION_GUIDE.md:1003 |
| 6 | Forgetting `default_state` tag | UI elements exist but don't render | Call `ui.box.AddStateTagToUIBox` after spawn AND after `ReplaceChildren` | UI_PANEL_IMPLEMENTATION_GUIDE.md:1004 |
| 7 | Not moving `UIBoxComponent.uiRoot` | Visual moves but clicks don't work | Always move BOTH entity Transform AND uiRoot Transform | UI_PANEL_IMPLEMENTATION_GUIDE.md:1005 |
| 8 | Skipping `ui.box.RenewAlignment` | Injected grids overlap/misaligned | Call after ANY `ReplaceChildren` operation | UI_PANEL_IMPLEMENTATION_GUIDE.md:1006 |
| 9 | Not calling `InventoryGridInit.initializeIfGrid` | Grid looks correct but drag-drop fails | Always call after grid injection | UI_PANEL_IMPLEMENTATION_GUIDE.md:1007 |
| 10 | Not cleaning all 3 registries | Memory leaks, stale drag state, duplication | Must clear: `itemRegistry`, `grid`, `dsl.cleanupGrid` | UI_PANEL_IMPLEMENTATION_GUIDE.md:1009 |
| 11 | Wrong case in DSL strict mode | Type errors at runtime | Use `fontSize` not `fontsize` - strict mode is case-sensitive | writing-ui-tests.md:162 |
| 12 | Cards don't drop into inventory slots | Drag/drop never registers | Check collision setup and screen space markers | conversation-retrospective-2026-01.md:63 |

---

## Physics Pitfalls

| # | Pitfall | Symptom | Fix | Source |
|---|---------|---------|-----|--------|
| 1 | Wrong parameter order in Chipmunk properties | Userdata errors, unexpected behavior | Check C++ binding signature - bound functions have specific parameter order | physics_docs.md:473 |
| 2 | Using old `globals.physicsWorld` pattern | Physics not working, nil errors | Use `PhysicsManager:getWorld("world_name")` instead | TROUBLESHOOTING.md:183 |
| 3 | Bodies on wrong physics world | Collisions not detected | Verify world name matches when creating bodies | TROUBLESHOOTING.md:136 |
| 4 | Wrong collision tags | Objects pass through each other | Check collision filtering and category/mask setup | TROUBLESHOOTING.md:134 |
| 5 | Arbiter caveats - accessing post-callback | Undefined behavior, crashes | Arbiter data only valid during collision callback | physics_docs.md:428 |
| 6 | Homing projectiles without strength | Projectile ignores targets | Set `homing_strength` > 0 when using homing | ADDING_PROJECTILES.md:365 |
| 7 | Forgetting projectile lifetime | Projectile never despawns | Always set `lifetime` - projectiles live forever if they miss | ADDING_PROJECTILES.md:382-385 |
| 8 | Wrong collision setup for projectiles | Projectiles don't hit anything | Verify collision categories and masks match target types | ADDING_PROJECTILES.md:376 |
| 9 | Physics system not initialized | Physics calls fail silently | Ensure physics world created before using physics APIs | TROUBLESHOOTING.md:178 |

---

## Scripting/Lua Pitfalls

| # | Pitfall | Symptom | Fix | Source |
|---|---------|---------|-----|--------|
| 1 | Exceeding LuaJIT's 200 local variable limit | Cryptic compiler errors | Split large files, use tables for related locals | claude-md-additions.md:14 |
| 2 | File-scope locals accumulate in large files | Silent local limit exceeded | Group related locals in tables: `local M = {}` | claude-md-additions.md:17 |
| 3 | Data assigned AFTER `attach_ecs` | Data lost, component values nil | Assign ALL data to entity BEFORE calling `attach_ecs()` | cookbook.md:1552, claude.md:72 |
| 4 | Using wrong `require` paths | Module not found errors | Don't use `require("assets.scripts.core.timer")` - use correct module paths | cookbook.md:185 |
| 5 | Component names are globals - quoting them | Nil component returned | Use `Transform` not `"Transform"` - components are global variables | cookbook.md:327 |
| 6 | Not validating entity in callbacks | Crashes when entity destroyed | Always check `entity:valid()` in timer/signal callbacks | cookbook.md:283 |
| 7 | Using `publishLuaEvent()` (deprecated) | Warnings, inconsistent behavior | Use `signal.emit()` for all event emission | cookbook.md:658 |
| 8 | Signal bridge is one-way (bus → signal) | Events not received | Only bus→signal bridging exists to avoid loops | cookbook.md:721 |
| 9 | After `scope:destroy()`, creating new timers | Warnings, undefined behavior | Cannot add timers to destroyed scope | cookbook.md:578 |
| 10 | Creating entities during view iteration | Crash or undefined behavior | Defer entity creation until after view iteration completes | TROUBLESHOOTING.md:446 |
| 11 | Infinite signal loops | Stack overflow, freeze | Avoid signal handlers that emit signals they listen to | TROUBLESHOOTING.md:432 |
| 12 | C++ expects specific callback signatures | Callback not called or crashes | Match Lua callback signature exactly to C++ expectation | lua-cpp-documentation-guide.md:276 |
| 13 | Creating Lua table instead of C++ Color | Wrong type errors | Use `Color:new(r,g,b,a)` not `{r=r, g=g, b=b, a=a}` | lua-cpp-documentation-guide.md:313 |
| 14 | Timer callback in wrong Lua state | Timer fires but callback crashes | Ensure timer created in same Lua state as callback | lua-cpp-documentation-guide.md:293 |

---

## Content Creation Pitfalls

### Cards

| # | Pitfall | Symptom | Fix | Source |
|---|---------|---------|-----|--------|
| 1 | Missing required card fields | Card not created, errors at load | Include all required fields: `id`, `name`, `type`, `description` | ADDING_CARDS.md:247 |
| 2 | No tags on card | Card hard to find, filter fails | Always add relevant tags: `["spell", "fire", "damage"]` | ADDING_CARDS.md:256 |
| 3 | Typo in card id | Card not found, references fail | Match id exactly in all references | ADDING_CARDS.md:265 |
| 4 | Modifier card with base damage | Wrong card behavior | Modifiers shouldn't have damage - use for multicast, triggers | ADDING_CARDS.md:272-274 |

### Jokers

| # | Pitfall | Symptom | Fix | Source |
|---|---------|---------|-----|--------|
| 1 | Joker effect function returns nothing | Effect silently doesn't apply | Always return modified value from effect function | ADDING_JOKERS.md:316 |
| 2 | Not checking if tags is nil | Crash when checking tags | Guard with `if tags and tags.fire then` | ADDING_JOKERS.md:334 |
| 3 | Wrong event name (case-sensitive) | Joker never triggers | Event names are exact match - `"onDamageDealt"` not `"ondamagedealt"` | ADDING_JOKERS.md:341-343 |
| 4 | Multiplier removes all damage | Deals 0 damage | Use `damage * multiplier` not `damage = multiplier` | ADDING_JOKERS.md:352 |

### Projectiles

| # | Pitfall | Symptom | Fix | Source |
|---|---------|---------|-----|--------|
| 1 | Missing required projectile config | Projectile not created | Include: `speed`, `damage`, `sprite` at minimum | ADDING_PROJECTILES.md:345 |
| 2 | Invalid sprite reference | Invisible projectile | Verify sprite exists in atlas and name matches | ADDING_PROJECTILES.md:355 |

### Avatars & Triggers

| # | Pitfall | Symptom | Fix | Source |
|---|---------|---------|-----|--------|
| 1 | Missing unlock conditions | Avatar can never be unlocked | Define unlock criteria in avatar config | ADDING_AVATARS.md:525-527 |
| 2 | Wrong `OR_` prefix format | Alternative unlock path doesn't work | Format: `OR_condition_name` with underscore | ADDING_AVATARS.md:561 |
| 3 | Signal never emitted | Trigger doesn't fire | Verify `signal.emit()` called with correct event name | ADDING_TRIGGERS.md:442 |
| 4 | Table key doesn't match id field | Warning at load time | Keep table key and `id` field synchronized | CONTENT_OVERVIEW.md:74 |

---

## Combat/Wand Pitfalls

| # | Pitfall | Symptom | Fix | Source |
|---|---------|---------|-----|--------|
| 1 | Wand execution order dependency | Spells cast in wrong order | Understand wand execution architecture - modifiers before actions | WAND_EXECUTION_ARCHITECTURE.md |
| 2 | Wrong projectile system setup | Projectiles don't spawn or collide | Follow PROJECTILE_SYSTEM_DOCUMENTATION.md setup | PROJECTILE_SYSTEM_DOCUMENTATION.md |
| 3 | Combat integration missing initialization | Combat system not responding | Call combat system init during game setup | INTEGRATION_GUIDE.md |

---

## Rendering/Shader Pitfalls

| # | Pitfall | Symptom | Fix | Source |
|---|---------|---------|-----|--------|
| 1 | `rotate2d` used before definition in shader | Shader compile error | Define helper functions before use in GLSL | claude-md-additions.md:88 |
| 2 | Shader positions don't match screen positions | Effects appear offset | Check coordinate space - normalize properly | debug-shader-coordinates.md:12 |
| 3 | Wrong order in shader uniforms | Shader produces garbage | Match uniform order to C++ binding order | debug-shader-coordinates.md:54 |
| 4 | Using wrong `RenderTextureCache` | Draws to wrong target | Verify render target matches intended destination | PIPELINE_QUIRKS_FIXED.md:137 |
| 5 | Player renders in wrong position | Character offset from where it should be | Check pipeline state, camera matrix, DrawCommandSpace | PIPELINE_QUIRKS_FIXED.md:7, PIPELINE_DIAGNOSTICS_ADDED.md:50 |
| 6 | Child draws appear in wrong positions | UI children offset | Parent transform must be applied correctly | PIPELINE_CAMERA_FIX_V2.md:18 |
| 7 | Colors look wrong in shader | Washed out or oversaturated | Check color space - Raylib uses 0-255, shaders use 0-1 | RAYLIB_SHADER_GUIDE.md:280 |
| 8 | WebGL shader error | Works native, fails web | Check shader_web_error_msgs.md for common WebGL issues | shader_web_error_msgs.md |

---

## Timer Pitfalls

| # | Pitfall | Symptom | Fix | Source |
|---|---------|---------|-----|--------|
| 1 | Timer `times` is 0 or nil | Timer runs forever | Set explicit repeat count or use `times=1` for one-shot | cookbook.md:430 |
| 2 | Physics step timers not cancelled | Old physics timers keep running | Use `cancel_physics_step()` for physics timers | cookbook.md:459 |
| 3 | Timer chain not started | Chain defined but nothing happens | Call `:start()` to begin chain execution | cookbook.md:530 |
| 4 | Using sequential when parallel needed | Effects happen one-by-one | Use `:fork()` for parallel execution in chains | cookbook.md:532 |
| 5 | Tween not started | Tween created but never runs | Call `:start()` on tween objects | cookbook.md:1286 |
| 6 | Can't cancel tween | Tween runs to completion despite cancel | Use `:tag()` on tween, then `timer.cancel_by_tag()` | cookbook.md:1288 |
| 7 | Chain doesn't execute | ActionChain defined but nothing happens | Call `:go()` to execute action chain | cookbook.md:1337 |
| 8 | Not using timer groups | Timers keep running after entity destroy | Always use `TIMER_GROUP` and `timer.kill_group()` on cleanup | UI_PANEL_IMPLEMENTATION_GUIDE.md:1011 |

---

## General Pitfalls

| # | Pitfall | Symptom | Fix | Source |
|---|---------|---------|-----|--------|
| 1 | `debug.sethook` in production | 10-100x performance overhead | Set `Debug.enabled = false` in production | PROFILING_GUIDE.md:70, cookbook.md:1444 |
| 2 | Max 16 lights per layer | Lights beyond 16 ignored | Shader limit - consolidate lights or use multiple layers | cookbook.md:1511 |
| 3 | Effect lags behind fast-moving entity | Visual desync | Use `Q.visualCenter()` for position tracking | cookbook.md:1046 |
| 4 | Functions return false/nil if entity has no Transform | Unexpected nil results | Check entity has Transform before position functions | cookbook.md:1092 |
| 5 | Constants are lowercase strings internally | String comparison fails | Use `C.States.ACTION` not raw strings | cookbook.md:1156-1158 |
| 6 | Pool `acquire()` returns nil at max capacity | Nil reference crash | Check return value of pool acquire | cookbook.md:1396 |
| 7 | Pooled object not released | Pool exhaustion | Always call `release()` when done with pooled objects | cookbook.md:1394 |
| 8 | Entity won't respect game phase visibility | Entity visible when should be hidden | Check phase tags and visibility system | entity-scripts.md:98 |
| 9 | Signal handler leak on reinit | Handlers accumulate, fire multiple times | Track handlers and call `signal.remove()` on cleanup | UI_PANEL_IMPLEMENTATION_GUIDE.md:1012 |
| 10 | Don't modify ownership links directly | Ownership system breaks | Use ownership API, never modify links manually | OWNERSHIP_SYSTEM.md:554 |

---

## Quick Diagnostic Checklist

When something doesn't work, check in this order:

### UI Not Responding to Clicks
1. Has `ScreenSpaceCollisionMarker`?
2. Correct `DrawCommandSpace`?
3. Z-order not hidden behind something?
4. UIRoot transform matches entity transform?

### Entity Data is Nil
1. Data assigned BEFORE `attach_ecs()`?
2. Using correct component name (global, not string)?
3. Entity still valid?

### Physics Not Working
1. Using `PhysicsManager:getWorld()` (not old globals)?
2. Bodies on same physics world?
3. Collision categories/masks match?
4. Physics system initialized?

### Timer/Callback Not Firing
1. Chain/tween started with `:start()` or `:go()`?
2. Timer scope not destroyed?
3. Entity still valid in callback?
4. Callback signature matches C++ expectation?

### Shader Looks Wrong
1. Functions defined before use?
2. Uniform order matches C++ bindings?
3. Color space correct (0-255 vs 0-1)?
4. DrawCommandSpace correct?

---

## See Also

- [claude.md](../../claude.md) - AI assistant coding guidelines (includes top mistakes)
- [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) - Detailed troubleshooting guide
- [Lua Cookbook](../lua-cookbook/cookbook.md) - Comprehensive Lua patterns
- [UI Panel Implementation Guide](UI_PANEL_IMPLEMENTATION_GUIDE.md) - Detailed UI pitfalls

---

**Pitfalls in this Reference**: 78 (most critical)  
**Total Pitfalls Inventoried**: 183  
**Categories**: 8  
**Sources**: 156 documentation files

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
