# Lua Scripting Reference (Current Bindings)

Single-source reference for all Lua APIs exposed by the engine. Everything here is derived from the live bindings in `src/systems/scripting/scripting_functions.cpp` and the generated hints in `assets/scripts/chugget_code_definitions.lua`.

**Binding status**
- Timer/EventQueueSystem bindings are **disabled** (`timer::exposeToLua` commented). Use scheduler/coroutines until re-enabled.
- `chugget_code_definitions.lua` is the signature source of truth; regenerate after adding bindings.

---

## Table of Contents
1) [Setup & Globals](#setup--globals)  
1.5) [Quick Module Map](#quick-module-map)  
2) [Events & Tutorials](#events--tutorials)  
3) [Sound & Music](#sound--music)  
4) [Game State, AI, Logging](#game-state-ai-logging)  
5) [Input & Controller Navigation](#input--controller-navigation)  
6) [Transforms, Alignment, Camera](#transforms-alignment-camera)  
7) [UI & Layout](#ui--layout)  
8) [Text & Localization](#text--localization)  
9) [Rendering & Command Buffer](#rendering--command-buffer)  
10) [Shaders & Pipeline](#shaders--pipeline)  
11) [Particles & Random](#particles--random)  
12) [Physics, Steering, Collision](#physics-steering-collision)  
13) [Quadtree](#quadtree)  
14) [Disabled/Not Bound](#disablednot-bound)  

---

## Setup & Globals
- Script path is expanded to include `assets/scripts/**` by `initLuaMasterState`.
- Globals: `globals.isGamePaused`, `globals.screenWipe`, `globals.screenWidth/Height`, `globals.inputState`, `globals.camera` (temporary), `globals.gameWorldContainerEntity`, `globals.cursor`, `globalShaderUniforms`.
- Frame utilities: `GetFrameTime()`, `GetTime()`, `GetWorldToScreen2D(pos, cam)`, `GetScreenToWorld2D(pos, cam)`, `GetScreenWidth()`, `GetScreenHeight()`.
- Fullscreen shaders: `add_fullscreen_shader(name)`, `remove_fullscreen_shader(name)`.
- Registry helpers: `entt.registry` (`create/destroy/has/get/emplace/remove/add_script/runtime_view/clear/orphan`) and `ScriptComponent:add_task/count_tasks`.
- Entity aliases: `getEntityByAlias(alias)`, `setEntityAlias(alias, entity)`.
- ECS linking: components you emplace in Lua are the same C++ types (see `chugget_code_definitions.lua` for type IDs); scripts typically grab components via `registry:get(entity, ComponentType)` and mutate fields directly.
- Object helpers: the lightweight class helper in `assets/scripts/external/object.lua` is documented at `docs/external/object.md`.
- **Ordering nuance:** create/initialize your Lua object first (setting fields, methods, timers), then call `:attach_ecs{}` so queued `run_custom_func` calls and state tags run against a real entity. Avoid mutating `self._eid` before attach; `behavior_script_v2` defers queued work until the entity exists.

## Quick Module Map
- **Core engine bindings:** `entt`, `transform`, `camera`, `layer`, `command_buffer`, `physics`, `steering`, `particle`, `shaders`, `shader_pipeline`, `shader_draw_commands`, `localization`, `controller_nav`, `layer_order_system`, `ui.*`, `TextSystem`.
- **Scripting patterns:** MonoBehavior base (`monobehavior/behavior_script_v2.lua`), Lua timer (`core/timer.lua`), coroutine/task (`task/task.lua`), helper lookups (`core/component_cache.lua`, `core/entity_cache.lua`), `getScriptTableFromEntityID` in `util/util.lua`.
- **Gameplay DSL:** UI sugar in `ui/ui_syntax_sugar.lua`, wand/cards in `core/card_eval_order_test.lua`, combat scripts under `assets/scripts/combat/`.
- **External libs:** `lume`, `knife.chain`, `hump.signal`, `grid`, `graph`, `forma` utils, `object`.

**Example: basic startup hooks**
```lua
function _init()
  globals.isGamePaused = false
  setEntityAlias("player", registry:create())
end
```

## Events & Tutorials
- C++ events: `subscribeToCppEvent('player_jumped'|'player_died', fn)`, `publishCppEvent(eventType, payload)`, `resetListenersForCppEvent`, `clearAllListeners`.
- Lua events: `subscribeToLuaEvent(event, fn)`, `publishLuaEvent(event, table)`, `publishLuaEventNoArgs(event)`, `resetListenersForLuaEvent`, `getEventOccurred(event) -> occurred, payload`, `setEventOccurred(event, bool)`.
- Tutorials: `setTutorialModeActive`, `resetTutorialSystem`, `showTutorialWindow`, `showTutorialWindowWithOptions`, `startTutorial`, `lockControls`, `unlockControls`, `addGameAnnouncement`, `registerTutorialToEvent`, `displayIndicatorAroundEntity(entity[, indicatorTypeID])`.
- More: `docs/guides/examples/list_of_defined_events.md` lists predefined Lua events; tutorial flow is described in `docs/systems/tutorial/tutorial_system_v2.md` (if present).

**Example: listen for a Lua event once**
```lua
local function onLoot(data)
  print("Looted", data.item_name)
  resetListenersForLuaEvent("loot_drop")
end
subscribeToLuaEvent("loot_drop", onLoot)
```

**Example: ECS object + event**  
Gameplay scripts often create ECS entities and publish events together:
```lua
local e = registry:create()
registry:emplace(e, Transform, { x = 0, y = 0, w = 16, h = 16 })
setEntityAlias("pickup_" .. e, e)
publishLuaEvent("spawned_pickup", { entity = e })
```

## Sound & Music
- Effects: `playSoundEffect(category, soundName[, pitch])`.
- Filters: `toggleLowPassFilter(enabled)`, `toggleDelayEffect(enabled)`, `setLowPassTarget(strength)`, `setLowPassSpeed(speed)`.
- Music/playlist: `playMusic(name[, loop])`, `playPlaylist(tracks, loop)`, `queueMusic`, `clearPlaylist`, `stopAllMusic`.
- Volume/pitch: `setTrackVolume`, `getTrackVolume`, `setVolume`, `setMusicVolume`, `setCategoryVolume`, `setSoundPitch`, `fadeInMusic`, `fadeOutMusic`, `pauseMusic`, `resumeMusic`, `resetSoundSystem`.
- More: see `docs/systems/sound/` (if present) or the bindings in `src/systems/sound/sound_system.cpp` for parameter details.

**Example: simple playlist**
```lua
playPlaylist({"title_theme", "level_theme"}, true)
setMusicVolume(0.7)
```

## Game State, AI, Logging
- Logging: `log_debug([entity], ...)`, `log_error([entity], ...)`.
- GOAP world state: `setCurrentWorldStateValue/getCurrentWorldStateValue/clearCurrentWorldState`, and goal variants.
- Blackboard: `set/getBlackboardFloat|Vector2|Bool|Int|String`, `blackboardContains`.
- Pause/input helpers: `isKeyPressed(keyName)`, `pauseGame()`, `unpauseGame()`.
- Entity state tags: `activate_state`, `deactivate_state`, `clear_states`, `is_state_active`, `hasAnyTag/hasAllTags`, `add_state_tag`, `remove_state_tag`, `clear_state_tags`, `propagate_state_effects_to_ui_box`, `remove_default_state_tag`, `is_entity_active`.
- AI table: `pause_ai_system`, `resume_ai_system`, `get_entity_ai_def`, `set_worldstate/goal`, `patch_worldstate/goal`, `get_blackboard`, `create_ai_entity`, `force_interrupt`, `list_lua_files`.
- Scheduler: `size`, `empty`, `clear`, `attach`, `update`, `abort`.
- More: AI system overview in `docs/systems/ai-behavior/AI_README.md`; entity state tags in `docs/systems/core/entity_state_management_doc.md`.

**Example: mark a GOAP fact**
```lua
local e = getEntityByAlias("player")
setCurrentWorldStateValue(e, "has_weapon", true)
```

## Input & Controller Navigation
- Input state: `globals.inputState` with enums `KeyboardKey`, `MouseButton`, `GamepadButton`, etc.
- Controller navigation: `controller_nav.create_group/layer`, `add_group_to_layer`, `navigate`, `select_current`, `set_entity_enabled`, `set_group_callbacks`, `current_focus_group`, `debug_print_state`, `validate`.
- More: `docs/systems/advanced/controller_navigation.md` for patterns and pitfalls.

**Example: gamepad navigate**
```lua
controller_nav.create_group("main_menu")
controller_nav.add_group_to_layer("main_menu", "menus")
controller_nav.navigate("menus", "down")
```

## Transforms, Alignment, Camera
- Transform helpers: `transform.install_local_callback/remove_local_callback/has_local_callback/get_local_callback_info/set_local_callback_size/set_local_callback_after_pipeline`, `get_space/is_screen_space/set_space`, creation/hierarchy (`CreateOrEmplace`, `CreateGameWorldContainerEntity`, `AlignToMaster`, `AssignRole`, `MoveWithMaster`, `GetMaster`, `SyncPerfectlyToMaster`, `ConfigureAlignment`, `UpdateTransformSmoothingFactors`), motion (`InjectDynamicMotion`, `InjectDynamicMotionDefault`, `setJiggleOnHover`), queries (`FindTopEntityAtPoint`, `FindAllEntitiesAtPoint`, `DrawBoundingBoxAndDebugInfo`, `RemoveEntity`).
- Alignment flags: `Alignment` bitflags; builder `InheritedPropertiesBuilder:addRoleType/addMaster/addOffset/addLocationBond/addSizeBond/addRotationBond/addScaleBond/addAlignment/addAlignmentOffset/build`.
- Camera: `camera.Create/Exists/Remove/Get/Update/UpdateAll/Begin/End/with`; `GameCamera` methods for Move/Follow, smoothing, zoom/rotation/offset getters/setters, shake/flash/fade, deadzone.
- More: camera specifics in `docs/api/lua_camera_docs.md`; transform local rendering in `docs/api/transform_local_render_callback_doc.md`.

**Example: render override in local space**
```lua
transform.install_local_callback(e, function(c)
  c.no_recalc = true
  c.fn = function(w, h)
    command_buffer.executeDrawRectangle(layers.sprites, function(cmd)
      cmd.x, cmd.y, cmd.width, cmd.height = -w/2, -h/2, w, h
    end)
  end
end)
```

## UI & Layout
- Types: `UITypeEnum`, `UIElementComponent`, `UIBoxComponent`, `UIState`, `Tooltip`, `FocusArgs`, `SliderComponent`, `InventoryGridTileComponent`, `UIStylingType`.
- Builders: `UIConfigBuilder.create(...):addId/.../addNPatchSourceTexture/build`; `UIElementTemplateNodeBuilder.create(...):addType/addConfig/addChild/addChildren/build`.
- UI box helpers (`ui.box`): `Initialize`, `BuildUIElementTree`, `AddTemplateToUIBox`, `AssignStateTagsToUIBox/AddStateTagToUIBox/ClearStateTagsFromUIBox`, `set_draw_layer`, `placeUIElementsRecursively`, `placeNonContainerUIE`, `CalcTreeSizes`, `TreeCalcSubContainer/NonContainer`, `ClampDimensionsToMinimumsIfPresent`, `RenewAlignment`, `AssignLayerOrderComponents`, `Move/Drag/Recalculate`, `GetUIEByID`, `RemoveGroup/GetGroup/Remove`, `drawAllBoxes`, `buildUIBoxDrawList`.
- Layer ordering: `layer_order_system.assignZIndexToEntity`, `setToTopZIndex`, `putAOverB`, `updateLayerZIndexesAsNecessary`, `getZIndex`, `resetRunningZIndex`.
- More: UI system docs in `docs/systems/ui/` and the static text system in `docs/systems/text-ui/static_ui_text_system_doc.md`.

**Example: build a button with a template**
```lua
local btn = UIElementTemplateNodeBuilder
  .create()
  :addType(UITypeEnum.TEXT)
  :addConfig(UIConfigBuilder.create()
    :addText("Play")
    :addPadding(8)
    :addButtonCallback(function() publishLuaEvent("play_clicked", {}) end)
    :build())
  :build()

local box = ui.box.Initialize(registry, {x=0,y=0,w=200,h=60}, btn)
```

**Example: gameplay UI link (HP bar)**  
From `assets/scripts/core/entity_factory.lua`:
```lua
local rootDef = UIElementTemplateNodeBuilder
  .create()
  :addType(UITypeEnum.TEXT)
  :addConfig(UIConfigBuilder.create()
    :addId("hp_text")
    :addText(function()
      return localization.get("ui.colonistHPText", {
        hp = math.floor(getBlackboardFloat(colonist, "health")),
        maxHp = getBlackboardFloat(colonist, "max_health")
      })
    end)
    :build())
  :build()

globals.ui.colonist_ui[colonist].hp_ui_box = ui.box.Initialize({}, rootDef)
ui.box.AssignLayerOrderComponents(registry, globals.ui.colonist_ui[colonist].hp_ui_box)
layer_order_system.assignZIndexToEntity(globals.ui.colonist_ui[colonist].hp_ui_box, z_orders.ui_overlay)
```

**Example: controller nav binding (from `assets/scripts/core/gameplay.lua`)**
```lua
controller_nav.create_layer("planning-input-layer")
controller_nav.create_group("planning-phase")
controller_nav.add_group_to_layer("planning-input-layer", "planning-phase")
controller_nav.set_group_callbacks("planning-phase", {
  on_select = function(eid) controller_focused_entity = eid end,
})
controller_nav.navigate("planning-phase", "U")
```

## Text & Localization
- Text system: `TextSystem.Text`/`Character` accessors and `TextSystem.Builders.TextBuilder:setRawText/setFontData/setOnFinishedEffect/setFontSize/setWrapWidth/setAlignment/setWrapMode/setCreatedTime/setPopInEnabled/build`.
- Static UI text system: exposed via `static_ui_text_system` (see `docs/systems/text-ui/static_ui_text_system_doc.md`) for registering/drawing static text.
- Localization: `localization.loadLanguage(pathOrKey)`, `setFallbackLanguage(key)`, `getCurrentLanguage()`, `get(key)`; `localization.language` holds active key.
- More: `docs/api/particles_doc.md` for text effects interplay with particles, and `docs/systems/text-ui/static_ui_text_system_doc.md` for usage patterns.

**Example: localized label**
```lua
localization.loadLanguage("en")
local label = localization.get("menu.play")
```

## Rendering & Command Buffer
- The `command_buffer` table queues draw commands for a `Layer`, or executes them immediately.
- Queue: `command_buffer.queue<CmdName>(layer, init_fn, z, renderSpace?)` where `<CmdName>` matches a `layer.Cmd*` struct (e.g., `DrawRectangle`, `DrawText`, `SetShader`, `BeginOpenGLMode`, `DrawSpriteCentered`, etc.).
- Immediate: `command_buffer.execute<CmdName>(layer, init_fn)` executes without queuing.
- Scoped transform: `command_buffer.queueScopedTransformCompositeRender(layer, entity, fn, z, renderSpace?)`.
- Matrix helper: `command_buffer.pushEntityTransformsToMatrix(registry, entity, layer, zOrder)`.
- More: draw batching overview in `BATCHED_ENTITY_RENDERING.md` and `DRAW_COMMAND_BATCH_TESTING_GUIDE.md`.

**Example: queue a rounded rect with world-space z**
```lua
command_buffer.queueDrawGradientRectRoundedCentered(
  layers.sprites,
  function(c)
    c.cx, c.cy = 0, 0
    c.width, c.height = 64, 24
    c.roundness, c.segments = 0.2, 8
  end,
  z_orders.ui,
  layer.DrawCommandSpace.World
)
```

## Shaders & Pipeline
- Shader uniforms: `shaders.ShaderUniformComponent`/`ShaderUniformSet` (`set/get/registerEntityUniformCallback/applyToShaderForEntity`).
- Shader pipeline: `shader_pipeline` tables for `ShaderPass`, `OverlayInputSource`, `ShaderOverlayDraw`, `ShaderPipelineComponent`; helpers like `ShaderPipelineInit/Resize/ClearTextures/Swap/DebugDrawFront`.
- Batched shader commands: `shader_draw_commands.DrawCommandBatch` (`beginRecording/endRecording/addBeginShader/addEndShader/addDrawTexture/addCustomCommand/execute/optimize/clear/size`).
- Fullscreen shader helpers: `add_fullscreen_shader/remove_fullscreen_shader`.
- More: pipeline internals in `DRAW_COMMAND_OPTIMIZATION.md` and `docs/guides/shaders/` for shader patterns.

**Example: set a global uniform**
```lua
globalShaderUniforms.set("crt", "intensity", 0.5)
```

## Particles & Random
- Particles: `particle.CreateParticle`, `CreateParticleEmitter`, `AttachEmitter`, `EmitParticles`, `WipeTagged`, `WipeAll`; enums `ParticleRenderType`, `RenderSpace`, `ParticleAnimationConfig`.
- Random: `random_utils.set_seed/random_bool/random_float/random_int/random_normal/random_sign/random_uid/random_angle/random_biased/random_delay`.
- More: `docs/api/particles_doc.md` for detailed particle examples.

**Example: burst emitter**
```lua
local em = particle.CreateParticleEmitter("smoke", {x=0,y=0})
particle.EmitParticles(em, 10)
```

**Example: particle from gameplay (combat cleanup)**
```lua
particle.CreateParticle(
  {
    renderType = particle.ParticleRenderType.RECTANGLE_FILLED,
    color = {r=255,g=255,b=255,a=255},
    x = transform.actualX + (transform.actualW or 0) * 0.5,
    y = transform.actualY + (transform.actualH or 0) * 0.5,
    size = 4,
    lifeTime = 0.5,
  }
)
```

## Physics, Steering, Collision
- Physics masks/tags: `physics.set_collision_tags`, `enable/disable_collision_between` (single or `_many`), `enable/disable_trigger_between` (single or `_many`), `update_collision_masks_for`.
- Steering: `steering.make_steerable`, `seek_point`, `flee_point`, `wander`, `separate`, `align`, `cohesion`, `pursuit`, `evade`, `set_path`.
- Broad-phase collision: `collision.create_collider_for_entity`, `CheckCollisionBetweenTransforms`, `setCollisionCategory`, `setCollisionMask`, `resetCollisionCategory`; enums `ColliderType`, `CollisionFilter`.

**Example: simple steering**
```lua
steering.make_steerable(e)
steering.seek_point(e, {x=100,y=80})
```

**Example: projectile physics (from `assets/scripts/combat/projectile_system.lua`)**
```lua
physics.create_physics_for_transform(world, entity, transform, physics.Shape.Circle, params.radius or 4)
physics.SetBullet(world, entity, true)
physics.set_collision_tags(world, entity, ProjectileSystem.COLLISION_CATEGORY)
physics.enable_collision_between_many(world, ProjectileSystem.COLLISION_CATEGORY, { "enemy" })
```

## Utility Libraries (external/)
- `external/lume.lua`: general-purpose FP/data helpers (`lume.map`, `filter`, `reduce`, `shuffle`, `weights`, `vector`, etc.). Loaded in `core/main.lua` as `lume = require("external.lume")`.
- `external/knife/chain.lua`: chainable middleware; create with `local chain = require("external.knife.chain")` then `chain(fn1)(fn2)()(args)` to run a pipeline with optional async `continue`.
- `external/hump/signal.lua`: event emitter (`signal.register`, `signal.emit`, `signal.clear`), used in gameplay; see upstream docs or file header.
- `external/grid.lua`: simple 2D grid class (`Grid(w,h,fill)`, `:get/:set`, `:apply`, `:for_all`, `:find`); useful for tile/state boards.
- `external/graph.lua`: adjacency-list graph with helpers (`add_node`, `add_edge`, `for_all_nodes/edges`, `get_node_neighbors`, Floyd-Warshall precompute).
- `external/forma/**`: BSP/geometry utilities (see `docs/external/forma_README.md`) for procedural layout.
- `external/object.lua`: lightweight class/OOP helper (documented in `docs/external/object.md`), used by MonoBehavior scripts.
- `external/knife/*`, `external/forma/utils/*`: keep to their README/comment headers for niche utilities.
- `assets/scripts/util/util.lua`: gameplay helpers (camera smoothing, particle helpers, beam effects). Useful functions include `camera_smooth_pan_to`, `particle.spawnRadialParticles`, `spawnImageBurst`, `spawnRing`, `spawnRectAreaParticles`, `spawnDirectionalCone`, and `makePulsingBeam` (beam node using command_buffer + tweening).

**Example: using hump.signal**
```lua
local signal = require("external.hump.signal")
signal.register("card_drawn")
signal.addListener("card_drawn", function(card) print("Drew", card) end)
signal.emit("card_drawn", "fire_basic_bolt")
```

**Example: using knife.chain**
```lua
local chain = require("external.knife.chain")
local pipeline = chain(
  function(continue, ctx) ctx.log = {"start"}; continue(ctx) end,
  function(continue, ctx) table.insert(ctx.log, "middle"); continue(ctx) end,
  function(_, ctx) table.insert(ctx.log, "end") end
)
pipeline()({}) -- runs the chain with an empty context
```

**Example: grid helpers**
```lua
local Grid = require("external.grid")
local g = Grid(3, 3, 0)
g:set(2, 2, 1)
g:apply(function(grid, i, j) print(i, j, grid:get(i, j)) end)
```

**Example: util.lua camera + particles + beam**
```lua
camera_smooth_pan_to("main", 100, 200, { increments = 4, interval = 0.01 })
particle.spawnRing(0, 0, 12, 0.8, 40, { colors = { util.getColor("CYAN") } })
makePulsingBeam(player_entity, target_entity, { duration = 0.6, color = util.getColor("magenta") })
```

**Example: MonoBehavior lifecycle (from `monobehavior/behavior_script_v2.lua`)**
```lua
local Node = require("monobehavior.behavior_script_v2")

local Spinner = Node:extend()
function Spinner:init(args)
  self.speed = args.speed or 1
end
function Spinner:update(dt)
  local t = registry:get(self:handle(), Transform)
  t.visualR = t.visualR + dt * self.speed
end

Spinner {}:attach_ecs({ create_new = true })
```

**Example: Lua-only timer chain (from `core/gameplay.lua` transitions)**
```lua
timer.after(duration * 0.7, function()
  timer.tween_fields(duration * 0.3, self, { radius = 0 }, Easing.inOutCubic.f, nil, "transition_circle_shrink", "ui")
end, "transition_circle_shrink_delay", "ui")
```
## Quadtree
- `quadtree.box`, `WorldQuadtree:add/remove/query/find_all_intersections/get_bounds/clear`.

**Example: query overlaps**
```lua
for _, hit in ipairs(globals.quadtreeWorld:query(quadtree.box(0,0,32,32))) do
  print("Hit", hit.entity)
end
```

## Disabled/Not Bound
- Timer/EventQueueSystem: see `docs/api/timer_docs.md` and `timer_chaining.md` for future reference; not exposed until `timer::exposeToLua` is re-enabled. The gameplay scripts use the Lua-only timer in `assets/scripts/core/timer.lua` instead.

---

When adding new bindings: register in `initLuaMasterState`, record with `BindingRecorder`, regenerate `assets/scripts/chugget_code_definitions.lua`, and update examples here.
