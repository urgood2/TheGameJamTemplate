# Changelog

Generated from commit history (initial commit 2025-03-26 → latest 2025-11-23).

## 2025-11
- Added draw-command/shader batching system with docs, test suite, and integration guides; expanded batched entity rendering in the layer queue.
- Converted large shader set (Godot SCREEN_TEXTURE + Unity UIEffect) to Raylib, added download tool and documentation for shader workflows.
- Fixed HP/EXP bar delayed indicators, EXP pickup physics (sensor-based), tooltip font-size trimming, TEXT element font-size application, and camera positioning edge cases.
- Began globals/system refactor and layer management cleanup; added BindingRecorder Lua syntax fixes.
- Web build reliability and virtual-resolution support improvements; optional Tracy at compile time.
- Documentation reorganization and comprehensive doc index/API reference.
- Error-handling sweep: wrapped remaining Lua entry points (`safeLuaCall` across AI start/finish/abort hooks, timers, nav callbacks, camera.with, layer queue/exec, physics collisions, text waiters), guarded sound loading, and added regression tests/docs for the safety helpers.

## 2025-10
- Major card-system overhaul: trigger/action/modifier boards, always-cast flow, Noita-style wand logic, stacking/unstacking, z-order and collision fixes, and refactored card creation/selection.
- Gameplay updates: enemy contact damage, dash, EXP pickups, reload/slow-time features, wand reload fixes, and camera/controller navigation polish.
- Performance/profiling: Tracy instrumentation in Lua and engine, profiling passes, decoupled physics, and frame-rate investigations.
- UI/audio polish: transitions, outlines, controller navigation fixes, added music/SFX, and UI syntax sugar.
- Stability passes on rendering/shaders and numerous bug-fix “flush” iterations.

## 2025-09
- Physics and collision push: sensor/presolve/postsolve fixes, rotation/transform sync, registry cleanup, collider component stability, and broad testing.
- Binding and doc updates for physics/camera/monobehavior systems; improved wiring manager and timer docs.
- UI/tasking: scroll pane/scrollbar fixes, taskboard system, static text IDs, and input binding tweaks.
- Content/assets: LDTK loader fixes, sprite-sheet updates (one-bit/ascii), navmesh/particle tweaks, and demo additions.
- Windows build fixes and build-speed experiments.

## 2025-08
- Large ARPG-style systems: skills/skill tree, devotion-like procs with ICD/filters, auras (toggle/reservation/pulses), channeling/charges, pets, item sets, mutators, level curves, and stat dumps.
- Combat/demo polish: casting demos, typed retaliation/damage ticks, resistance/armor pen, overheat fixes, pet bugs, and weighted choice fixes.
- UI/UX: scroll panes with scissor/clipping, text input component and activation handling, timer chaining/overloads, cursor change on hover, drawCommandSpace exposure.
- Camera upgrades (shake, custom camera with springs) and tile/LDtk rendering localization with background/intgrid fixes.
- Rendering primitives and SFX/polish passes for demos.

## 2025-07
- Shader pipeline focus: multi-pass pipeline debugging, y-flip fixes, immediate UI rendering with pipeline component, and shader pass experiments.
- Camera module integration and debugging; collisions + camera-aware command system; Lua debugging improvements.
- Localization and UI: language switcher, tooltip fixes, typing tag speed, timer error handling, tooltip hover cancel; integrated Lume/Chain helpers.
- Web build efforts: loading bar, WASM size tweaks/gzip, Objective-C Chipmunk port, and pipeline rendering stability.
- Colony/rellic prototype work: colonist behaviors (death, duplicator movement), weather effects (acid rain, snow/rain), relic UI/strings, SFX/ambience, and currency/shop hooks.

## 2025-06
- Large Lua exposure push: UI/transform/scripting bindings, auto-generated definitions, scheduler/coroutines/wait(), GOAP AI wiring, and monobehavior hooks.
- UI layering/z-index and localization (including Korean); object pool cleanup; timer docs; text rendering layer order.
- Shader/pipeline: fullscreen shader injection, shader passes/uniforms from Lua, multi-pass pipeline, pixelation/ripple/palette/jitter shaders, overlay/palette quantizer work.
- Particle and rendering fixes (shadow issues, atlas bugs) and web rendering/debug/memory fixes; background shader updates.
- Whale/krill builder prototype: achievements/main menu, converters/dust collectors, building placement UI, unlocks/costs, SFX/music (whale songs), help window, and final build polish.
- Final-week polish: alignment fixes, jitter/compositing overlays, Windows fixes, and spotlight/polychrome shaders.

## 2025-05
- UI scaling/localization: global UI scale applied to animations/text, dynamic text resizing, localization system and IDs, keyboard input speed tweaks.
- Widgets and controls: checkboxes, progress bars, sliders, controller button pip, and input refactor.
- Rendering pipeline improvements: draw-command batching per layer, optimized layer system, and profiling/Tracy integration.
- Inventory/tooltips: drag-and-drop inventory fixes, recentering/resizing, tooltips/alerts groundwork.
- Collision/broadphase: quadtree integration, broadphase/layer order planning, and collision refactors.

## 2025-04
- Inventory groundwork with draggable items and swap logic; static UI text system and parse-text scaling work.
- Text rendering improvements: render-scale syncing, resize-to-fit iterations, animation integration, and fancy text in UI.
- Shader/pipeline experiments: multi-pass shader tests, renderstack for texture-mode overlap avoidance, spectrum shader set, and pipeline debugging.
- UI components: tabs, borders, radio buttons, N-patch buttons, tab groups, and added UI assets.
- Sprite handling: multi-atlas sprite loading, rotation fixes, and npatch bug fixes.

## 2025-03
- Project start and initial systems: early shaders/effects (polychrome, holo, transitions, pixelate), movement randomness/background work.
- Main loop and transform stability passes; fixture/uniform fixes.
- Established UI ordering rules and alignment groundwork.
