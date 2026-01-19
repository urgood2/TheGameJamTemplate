


- 10/10/2025
  - tweak CRT shader vignette intensity to be more subtle
  - add "Start Action Phase" button to UI (non-functional for now)
  - start fleshing out TODO_prototype.md with more specific tasks and note
  - Did some ideation for how to vary triggers, with activation chance for instance.
  - Tested entity state switching between planning and action phases. Seems to work fine.
  - Tweaked BASE_SHADOW_EXAGGERATION to 1.8 from 3
  
- 10/11/2025
  - Fixed bug in transform system where offset in AssignRole was not being applied correctly.
  - Added border color property to CardArea component to allow different colored borders for different card areas.
  - Added "Trigger Card" and "Action/Modifier Cards" labels above the respective card areas.
  - Moved trigger card area to y=150 to make space for the new label.
  - Updated TODO_prototype.md with more specific tasks and notes.
  - Added basic trigger, action, and modifier cards to the game (visual placeholders).
  - Implemented basic drag-and-drop functionality for cards between different card areas.
  
10/12/2025
  - nothing, too busy with checking work for weekend
  
10/13/2025
  - Card stacks can be moved to and from card areas and behave like normal cards.
  - Card stacks can be unstacked by dragging the root card into the "free card" field.
  - Timer trigger now pulses when placed in the trigger slot.
  - Added some basic triggers and actions and modifiers as data.
  - Only modifiers can stack on top of actions now.
  - Actions pulse when triggered.

10/14/2025
  - Added SFX for triggers & cards.
  - Added shoot bullet action.
  - Added strength bonus action.
  - Added trap action (stationary AoE damage zone).
  - Added basic enemies that spawn randomly in and move toward the player.
  - Added the "double_effect" modifier that makes actions happen twice.

10/16/2025
  - Got sidetracked with fixing ImGui integration with lua. It was a bit involved since I had to make sure that imgui could be called anywhere, even in the update loop, rather than just in the render loop.
  - changed player velocity setting to use physics.SetVelocity instead of changing transform directly. 
  - Made three clear game states and enabled switching between them. Have to figure out a way to display the cards active while in the action phase.
  
10/17/2025
  - Patched a fix for card dealing, making them not overlap.
  - Added a deal card sound.
  - Noted some bugs.
  - Refactored some code, redid the layout to allow multiple triggers.
  - Fixed a collision bug.
  - Got every trigger slot working.
  - Got camera to follow player.
  
10/18/2025
  - Tested slowing time.
  - Added animatino for death.
  - Added animation for shooting projectiles.
  
10/19/2025
  - Fixed main loop bug that caused stutter when slowing time.
  - Added lua script hot reloading system with ImGui interface.
  - Added "Reload Game from Scratch" button to lua hot reload ImGui window.
  - Need to finish reInitializeGame function to reset game state when reloading.
  
10/20/2025 
  - Added gradient rectangle drawing commands to layer system, for things like rotating highlights, loot drop indicators, etc.
  - Finished implementing reInitializeGame function to reset game state.
  - player-enemy collision detection working.
  - Added camera shake on hit, with slow & flash.
  - Added walls.
  - Debugging and tesing for collision detection with walls & enemies.
  - Got gradient rounded rect rendering working. Took way too long imo to debug this.
  
10/21/2025
  - Found a lot of potential and answers to my own design questions in Noita's wand system. I'm going to try to yoink it and adapt it to my game.
  - Prototyped a basic wand evaluation algorithm using Noita's wand system as reference.
  
10/22/2025
  - Continued prototyping wand evaluation system.
  - Added card weight property to influence evaluation order.
  - Updated card evaluation test script with weights for different card types.
  - Removed card stacking behavior for now.
  - Recursion & always cast flexibility added. Seems to be working as intended.
  
10/23/2025
  - Changed ui to facilitate wand building.
  - Chose which cards to implement for a vertical slice.
  - Tinkered with rendering a bit to clearly show debug info.
  - Need to now link up wand evaluation with gameplay.
  - Did some profiling. Removing imgui and making sure I don't give every lua object an update method that runs every frame seems to help performance a lot.
  
10/24/2025
  - Linked up stat system so enemies deal damage on bump.
  - Player can now gather orbs to level up.
  - Added HP and XP bars to UI.
  - Player can now dash.

10/25/2025
  - Integrated controller input, though there isn't any smart card selection or ui navigation yet. only movement & dashing.
  - Added board set cycling to allow for multiple triggers, and a dedicated trigger inventory.
  - Tooltips to indicate stats for hovered cards & wand.
  - Separated trigger cards to be their own thing.
  - Several more card defs so I can play around with them.
  - ran into some serious performance issues. tried moving timer and object updates to lua instead of c++. Not sure yet if it helped.
  
10/26/2025
  - Explored some performance optimizations. Also, full day of work, so not much progress.
  
10/27/2025
  - Added tracy to lua, allowing profiling of lua code.
  - Robust controller navigation system added, allowing seamless navigation of UI with controller.
- Controller navigation system exposed to lua for easy integration with lua-based UIs.
  - Lua profiling doesn't work with tracy, so I added a different one.
  - Figureing out some main loop structure issuse that might be causing performance issues.
  
10/28/2025
  - Fixed main loop structure issues causing performance problems.
  - Also, strange rubber banding with physics and dashing. I fixed it by changing only the velocity of the player during dash, not resetting it to 0 manually, and also not altering damping during it.
  
10/29/2025
  - Started putting controller navigation into use. Cards can now be selected.
  - Added visual indicators for selected cards.
  - Some debugging and polish.
  
10/30/2025
  - Added some basic music to battle scene & planning scene.
  - Some sound effects, ironing out controller navigation bugs.
  - Added a transition effect I can reuse.
  
10/31/2025
  - UI syntax sugar to make defining UIs in lua easier.
  - Added font offset and spacing support from json.
  - State management broken.
  - Updated particles to be easier to use from lua.
  
11/1/2025
  - Full day of work.
  - Got some more assets, sound and art. Maybe I'll use some of them.
  
11/2 - 11/4/2025
  - Trip, almost no work, but did organize assets (sound and graphics), worked on some bugs.
  
11/5/2025
  - Fixed UI state management bugs.
  - Fixed jerky player movement, but not sure if it's perfect yet.
  
11/6/2025
  - Stuck in... optimization hell?
  
11/7/2025
  - More optimization work.
  - Got spawn markers working again.
  - Added more sfx.
  - Tweaked some particle effects.
  - Tweaked tooltips.
  
11/8-9/2025
  - Weekend, little work, lots of translation work.
  
11/10/2025
  - Added some new sfx.
  - Added a scrolling background.
  - Tweaked some particle effects.
  - New particle effect: circle with expanding center.
  - Got started using stencils for a new particle effect, bug fixing almost done.
  - Stencil fixed, textures did not have stencil buffer.
  - Elongated ellipses that are radial and point outwards.
  
11/11/2025
  - Added direction-facing line particle effect.
  - Added circle outline vfx with dots that twirl inward. Needs some fine tuning later.
  - Added rectantle area that wipes in the direction it is going.
  - Added crecent particle effect that faces the direction it is going.
  - Added cross diamond shaped streaks for impact that thin out over time.
  - Added method that adds trail to entity over x duration.
  - circle area with dashed rotating border
  - beam attack with pulsating circles on either end
  - Added player stretch/squash when dashing.
  
11/12/2025
  - I was despairing about performance, but RelWithDebugInfo and LuaJIT just did some magic. Okay... feeling pretty good .
  - Added in SMILETRON music as a tester.
  - Added low-pass.
  - Luajit works, but right now it causes some subtle bugs in the graphics for some reason.
  
11/13/2025
  - Started working on web build automation with github actions. Cache service is down, so I'll continue later.
  - Pickups now gravitate to player when in range.

11/14/2025
  - Updated shader system to accept integer uniforms.
  - Sol integrated into files, isntead of using cmake to fetch it.
  - Working on web build automation again... brain numbing.
  
11/15/2025
  - Web build automation mostly working. Need to test more, but hitting rate limits?
  - Juice for exp and hp bars. 
  - Made enemies blink when entering the map.

11/16/2025
  - Web build works now. Automation hits some snags with usage, but on PC I can build fine. Just some wee errors and shaders to work out on web.
  - Added fullscreen/window resizing while maintaining collision accuracy
  - Started work on card eval analysis.

11/17/2025
  - Mysterious lua crash?
  - Added drop shadows instead of the usual sprite shadows. > reverted because of crash 
  - Added indiviudal layer setting to ui boxes, option to disable deceleration for steering, worked on letter boxing being broken > reverted because of crash.
  - Encountering various crashes for some reason when using texture pipeline.
  - all kinds of memory errors happening, and I have no idea why. Turning on pipeline rendering seems to be the root of it.

11/18/2025
  - Stability issues & crashing is fixed, but there are some quirks to work out that have been introduced into the rendering. (sometimes camera stops working, and entities no longer match their collision boxes (I need to know when that happens, but how?). Player still doesn't show up when using pipeline, only when 1 shader pass is added. Also player will sometimes render in completely the wrong position for some reason.)
  - single pass issue also fixed, but the sprites render incorrectly position wise.

11/19/2025 
  - still stuck with shader pipeline bug/.
  - bug seems fixed, and shadows are rendering properly again. goddamn it. 
  
11/20/2025
  - Pretty bummed out, about life in general (when do I get to retire?) and about this code that's constantly miring me in bugs.
  - Added a physics mask to the player
  - Made sure screen shake works
  - Added bottom shadows instead of drop shadows back in
  - Added ui-box specific layer settings back in.
  - Trimmed tooltips a little. Added font size option, but not working at the moment.
  
11/21/2025
  - started using claude code for faster workflow.
  - projectile system, needs soem work.
  - mass-converted some shaders I was planning to add.
  - fixed some nagging bugs.
  
11/22/2025
  - Code refactoring work, I had some IRL work so not much done today.
  - Banned from Claude Code. Not sure why, petitioned.
  
11/23-24/2025
  - More refactoring. Started using Codex instead.
  - Globals, general updates to code structure, docs, etc.
  - Still ongoing, but I should be basically set to focus on gameplay again starting tomorrow. It's not perfect, but will it ever be?
  - Got some basic systems done for gameplay I'll need to test.
  
11/25/2025
  - Build errors stomping progress. 
  - Projectile system overhauls: cached script lookup, collision tag registration, center-based spawning via `positionIsCenter`, and wall collision test/docs updated.
  - Added world bounds refresh using `SCREEN_BOUND_*` + `SCREEN_BOUND_THICKNESS`, culling/bouncing projectiles that leave play area, and better homing/orbital velocity init.
  - Fixed crash on quit by clearing Lua-driven callbacks (controller nav, localization, shader uniforms), dropping scripting refs, and resetting physics worlds before teardown.
  - Game flow/UI polish: start in planning state by default, shared phase transition helper, stamina bars anchored to visual bounds, tooltips padding/no-shadow options, AI blackboard getter now warns and can return nil.

11/26/2025
 - Tag pattern/discovery system landed: Cast Feed UI now surfaces spell type/tag discoveries, added discovery journal + tag-reactive jokers, docs, and tests for the pattern matcher.
  - PostHog telemetry integrated end-to-end with session IDs (exposed to Lua), crash-reporter/init hooks, and phase/menu events emitting with platform/build metadata; web builds default telemetry on.
  - Web telemetry hardened with lifecycle hooks (session end, visibility change, client errors), sendBeacon/fetch beacons, visibility-change events, and optional on-page debug overlay for web debugging.
  - Build pipeline now strips Lua comments for release/web asset copies when enabled, using a new Python helper wired into CMake to shrink payloads.
  - Testing/gameplay polish: Cast Feed headless + UI test runners and wand examples, projectile system fixes, lighter mask physics with walking dust VFX, and gamepad button press/release events now published on the event bus with coverage.

11/27/2025
  - PostHog client now queues and sends events asynchronously (with flush waiting) to eliminate native telemetry stalls.
  - Web build hooks auto-pause/resume gameplay and the main loop on focus/visibility changes (Emscripten glue in main loop), plus Cast Feed integration guide expanded with projectile lifecycle/validation notes.
  - CMake defaults unit tests off; Catch2 is only fetched when `ENABLE_UNIT_TESTS=ON`.
  - Reverted to commit 70fcf324 to unwind later experimental changes and regen UUID metadata; minor telemetry/test toggles refreshed after the revert.

11/28/2025
  - Cast UI pass: Cast Feed finally renders in-game, added springy execution graph preview plus a cast-block flash overlay for last cast blocks, and continued wand→UI hooking.
  - Implemented buffered dash mechanics (coyote/buffer window, mid-dash retarget) with impulse-based movement, VFX/SFX, and wand trigger emission.
  - Added floating damage numbers with fade/arc motion and brief enemy health bar reveals on hit.
  - Stabilized web builds: fixed a focus regression and restored the reverted web build files/tagging step.

11/29/2025
  - Added a wand cooldown UI: left-edge cards show per-wand cooldown pies, cast progress/overheat status, labels, and mana readouts pulled from the executor.
  - Refactored wand executor/triggers: queued child sub-casts with metadata, started piping player stats into modifier aggregates, and improved projectile action execution and trigger subscriptions.
  - Polished CastBlockFlash UI (force fade-out controls, jiggle/alpha tweaks) so cast block flashes render and expire more reliably.
  - Instrumentation/build toggles: Tracy instrumentation re-enabled (forced off on Web), telemetry build flag defaults to off, and Emscripten main loop now pauses/resumes on focus/visibility changes.
  - Docs/planning updates: wand gap report expanded around upgrades/stat merging and trigger coverage; TODO_prototype gained visibility/shop/UX notes.

11/30/2025
  - Planning/UX polish: fixed card ID assignment, added rarity-aware tooltips, improved execution graph hover handling, and continued planning UI cleanup.
  - Avatar unlock and messaging: implemented unlock tracker + discovery toasts, added avatar debug UI, wired message queue signals into gameplay, and lifted inventory cards with a Send Up flow plus tag evaluation hooks.
  - Shop and wand systems: expanded shop window/offers, piped card upgrade behaviors into projectile execution with stat snapshots and explosion scaling, and added a subcast debug overlay gated by DEBUG_SUBCAST.
  - Stability/coverage: paused web builds on tab visibility changes, broadened ASAN/unit coverage (controller nav, shader/uniform skip logic, sound, telemetry/localization), and refreshed tests/stubs for message queue/avatars.

12/01/2025
  - Shop flow landed: card purchasing plus avatar unlocking, card spawner + debug UI, and gold interest transitions/currency+tag synergy UI updates.
  - UI/engine plumbing: added AvatarJokerStrip UI to gameplay, refactored Tracy integration with canvas rendering tweaks, and hardened web telemetry serialization.

12/02/2025
  - Broad UI/functionality sweep across scripts with incremental polish and fixes.

12/03/2025
  - Input/aiming: added auto-aim with spring smoothing, projectile recoil/launch feedback, a world-space aim indicator that swaps mouse/pad inputs, and an F/joker prompt for toggling auto-aim.
  - Action onboarding: built an action-phase tutorial overlay that renders contextual move/dash cues with controller/keyboard art while the action timer runs.
  - UI polish: tag synergy panel now caches layout for hover detection and lists tag breakpoints/remaining counts in tooltips; continued tooltip/particle tuning.
  - Rendering: added a brushed `material_card_overlay` shader pass wired for native/web, fed per-entity rotation into the pipeline, and started a new render path for card transforms.

12/04/2025
  - Prototyping a `material_card_overlay_new_dissolve` pass (native + web) with dissolve/burn controls, default uniform registration, rotation support, and initial shader draw command batching helpers; card pipeline can be pointed at the new pass for testing.

12/05/2025
  - Added a suite of 3D skew card shaders (hologram, foil, negative shine, polychrome, voucher, gold seal) with new uniform controls.
  - Aligned dissolve shader parameters with the Godot reference, improved shadow lift during drag, and merged material + skew shading updates.
  - Fixed sticker rendering issues.

12/06/2025
  - Polished the skew pipeline: refined polychrome handling, added gold-seal variants, and refreshed projectile VFX.
  - Added outlines to health and experience bars for better combat readability.
  - Cleaned up tooltip padding/player stats tooltip logic and main menu UI draw layers.

12/07/2025
  - Combat plumbing: player attack signals, low-health tracking, and equipped avatar retrieval now available.
  - Start-game button now uses layer shaders; main menu flow and shader uniform retrieval got performance cleanups.
  - Simplified shader angle calculations and main-loop timer updates.

12/08/2025
  - Expanded the 3D skew shader set with additional variants/web versions and smoother overlay/glitch gating.
  - Improved the tooltip system (font management, spacing fixes), addressed review feedback, and refactored code for readability.
  - Updated Claude Code review/PR assistant workflows.

12/09/2025
  - Shipped a UI asset pack system: manifest parser, asset pack registry, SPRITE styling with scale modes, Lua bindings, tests, and an ImGui pack editor.
  - Added a shader preset registry with Lua loading/startup presets, integration tests, and design docs.
  - Unified tooltips onto the DSL with new simple tooltip APIs, cache/lifecycle helpers, coded/font options, and migrated existing UIs.
  - Implemented ownership/tamper detection (build IDs/signatures, validation state, warning overlay, Lua bindings) with docs and improved web distribution/automation.
  - Delivered a text effects system with a registry, extensive effect set, demo script, and performance guidance.
  - Extended LDTK Lua integration: design doc, field extraction/queries, procedural rule runner with signals, and command-buffer tile rendering including filtered/Y-sorted paths.

12/10/2025
  - Merged the LDTK integration work and added exception-handling/thread-safety notes.
  - Updated Emscripten linker flags for better exception support and fixed web serve commands for cross-platform use.
  - Landed the text effects branch and synced master.
  - Fixed intermittent render flicker by adding batch flushes around manual render-target switches in layer/shader pipeline.
  - Improved web build CI: conditional emsdk sourcing, LFS asset fetching, HTML injection patching, and itch.io packaging tweaks.
  - Enhanced tooltips with better padding, visibility, and readability; added card descriptions and trigger types.

12/11/2025
  - Shop UI implementation: card entity tracking, createShopCard with shop-specific properties, populateShopBoard rendering, hover behavior with scale/dissolve animations, buy button integration, control bar with lock/reroll buttons, and currency display.
  - Refactored shader uniform defaults; updated grille size and scanline density for improved CRT effects.
  - Added tooltip customization for avatar/joker strip with hover functionality and drop shadows for UI depth.
  - Enhanced transform functions to support screen and world space conversions.
  - Added web build post-processing and deployment scripts with parallelism controls.
  - Gameplay code refactoring and localization string updates.

12/12/2025
  - Added unified copy_assets.py script for CMake/justfile parity with proper exclusions and Lua stripping for web builds.
  - Reverted web build to pre-regression baseline to stabilize deployment pipeline.
  - Added publish-web just command with helper script and auto-detection of butler in itch.io install locations.
  - Designed web loading screen and error handling documentation.

12/13/2025
  - Implemented ShaderBuilder fluent API for shader composition with family registry (3d_skew, liquid), convention-based prefix detection, and automatic uniform injection.
  - Added draw.lua with table-based command buffer wrappers (textPro, rectangle, texturePro, etc.) and render presets for common configurations.
  - Completed EmmyLua binding annotations for 100% coverage across 1102 C++ → Lua bindings, enabling full autocomplete and type checking.
  - Added Aseprite to TexturePacker automation workflow with justfile recipes for export, rebuild, watch, and clean operations.
  - Added sprite atlas workflow documentation and fixed Emscripten link flags for WebGL compatibility.
  - Added comprehensive integration tests for shader ergonomics.

12/14/2025
  - Cleaned up temporary visual test hooks from draw module and shader integration work.
  - Implemented Balatro-style web loading screen with CRT scanlines, pulsing progress bar, dev console overlay (backtick toggle), and two-phase loading (download + game init).
  - Added local dev server script (serve_web.py) with itch.io-identical headers for WASM/SharedArrayBuffer support.
  - Added web debug modal with copy/download/report actions and persistent debug button.
  - Implemented spawn system with Combat Debug Panel for enemy spawning and testing.
  - Added console commands for fast iteration: spawn, stat, heal, gold, joker.
  - Added Cards tab to Content Debug Panel with sprite preview, sort/filter, and test cast functionality.
  - Fixed UI alignment flag handling to be deterministic; added effectivePadding() method and conflict detection tests.
  - Added VS Code auto-start for sprite watcher on workspace open.
  - Expanded Lua cookbook with EntityBuilder, PhysicsBuilder, imports APIs, and PDF generation recipe.

12/15/2025
  - Expanded Lua cookbook with 12 new sections: Spawn System, Shop System, Stat System, LDtk Integration, Loot System, Animation System, Physics Manager, AI Blackboard, Card Discovery, Input System, Screen/Camera Globals, Game Control, Entity Alias System, Avatar System, and Combat State Machine.
  - Added optional sprite field to cards, jokers, and avatars for custom sprite assignment with fallback defaults.
  - Created 26 custom card sprite images (12 action, 10 modifier, 4 trigger) and assigned them to card definitions.
  - Updated createNewCard to check both card_defs and trigger_card_defs and hide text overlay/sticker for cards with custom sprites.
  - Fixed wave system integration: enemy factory infrastructure, physics manager reference, sprite definitions, and combat system hookup.

12/16/2025
  - Refactored C++ UI system: split UIConfig into focused components (Style, Layout, Interaction, Content) with handler architecture for type-specific rendering.
  - Implemented console improvements: level/tag filtering, bookmark navigation, entity ID detection/highlighting, copy filtered logs, filter state persistence.
  - Built particle builder fluent API with TDD: Recipe.define(), shape/size/color/velocity/behavior methods, emission modes, positioning (inCircle, inRect, from/toward), shader support.
  - Added LuaLS type annotations to entity_builder, timer, enemy_factory, physics_builder for IDE autocomplete.
  - Added API documentation headers to wave_helpers, enemy_factory, and ui_syntax_sugar modules.

12/17/2025
  - Implemented Text Builder fluent API: Recipe configuration, spawner basics (:spawn/:at), lifecycle management with lifespan expiration, entity-relative positioning with follow mode.
  - Extended Text Builder with tags, bulk operations, content/position update methods, and stream mode for deferred spawning.
  - Added performance instrumentation: draw call counter, state-aware batching with feature flag, shader hot-reload throttling to 500ms.
  - Created Lua convenience modules: Schema validation, TimerScope for auto-cancel, CardFactory DSL for card definition.
  - Enhanced particle system with entity returns from spawn, custom drawCommand support, and shader rendering tests.

12/18/2025
  - Built comprehensive performance audit infrastructure: benchmark tests, Lua/C++ boundary profiler, GC pause measurement, allocation profiler, draw call source tracking.
  - Implemented HoverRegistry module for immediate-mode UI hover regions and integrated into tag synergy panel with proper cleanup.
  - Fixed shader text rendering: hide base sprite, correct entity bounds for pipeline, make overlay patterns respond to card_rotation uniform.
  - Refactored codebase: migrated registry:get calls to component_cache.get across gameplay, ui_defs, and entity_factory.
  - Added Q.lua convenience module for transform operations (move, center, offset) with single-letter import.
  - Fixed auto-aim targeting, enemy corner-sticking prevention, tooltip white blocks from outlineThickness, and timer cleanup in entity cleanup flow.

12/19/2025
  - Implemented wave visual feedback: Text Builder rendering for wave/elite/stage announcements, spawn telegraph sprite with growing hollow circle effect.
  - Fixed telegraph-to-spawn timing: spawn now explicitly waits for telegraph duration plus 0.1s buffer instead of hardcoded delay.
  - Fixed execution graph UI: tooltip lookup, tween-from-zero animation prevention, settings and hover handling improvements.
  - Added enemy physics friction(0) to prevent wall sticking, fixed collision tag to use PROJECTILE instead of BULLET.
  - Cleaned up UI state transitions: guard planning timer with state check, clear execution graph and block flash UI before action phase.

12/20/2025
  - Implemented multi-size font cache infrastructure: FontData now stores fonts at multiple sizes (13, 16, 20, 22, 32) with automatic size selection for pixel-perfect Korean text rendering.
  - Added sliding UI panels: synergy panel and execution graph now slide in/out with toggle buttons, click-outside-to-dismiss behavior, and proper visual feedback.
  - Completed card tooltip and detailed stats localization for English and Korean with derived stat calculations.
  - Fixed font rendering crispness: switched to TEXTURE_FILTER_POINT, render text at native font sizes, and properly account for globalUIScaleFactor in layout measurement.

12/21/2025
  - Implemented styled localization system: new `getStyled()` function parses `{param|color}` syntax in JSON strings and outputs rich-text markup for color-coded tooltips.
  - Added `makeLocalizedTooltip` helper for streamlined styled tooltip creation with automatic parameter substitution.
  - Fixed CRT post-processing text pixelation by snapping UI text coordinates and adjusting resolution handling.
  - Reverted font textures to point filtering to eliminate text blur artifacts.

12/22/2025
  - Added color-coded elemental damage stats in tooltips: Fire, Cold, Lightning, Acid, etc. now display with their corresponding element colors.
  - Fixed rich-text spacing issues: improved single-segment optimization and ensured coded parsing only activates for labels with actual markup.
  - Updated Lua cookbook with styled localization and event bridge recipes; added Text Builder pop animation design documentation.
  - Implemented Text Builder pop-in entrance and fade-out animations with independent control via :pop() and :fadeOut() methods.
  - Added declarative enemy behavior library: composable behaviors (chase, wander, flee, dash, etc.) with auto-cleanup and config resolution from context fields.
  - Completed Lua Developer Experience audit improvements including EntityBuilder.validated(), EmmyLua type stubs, and documentation generator.

12/23/2025
  - Added Chain Lightning action card with cascading arcs that chain between up to 3 enemies, jagged lightning visuals, and modifier support for damage/heal/crit.
  - Major C++ safety hardening pass: replaced 15+ assertion/crash points with runtime guards for animation bounds, JSON parsing, Sol2 conversions, map access, and physics shapes.
  - Refactored scripting system: decomposed monolithic scripting_functions.cpp into modular binding files for physics, sound, and AI.
  - Build improvements: expanded precompiled header with entt/sol2/raylib for faster compiles, auto-scaled parallelism, and opt-in shader/texture batching for draw commands.
  - Added performance optimization: replaced std::vector<bool> with std::vector<uint8_t> to avoid proxy object overhead.

12/24/2025
  - Fixed alpha blending for transparent sprites and layers: separated RGB and alpha multiplication in 64 shaders and added BLEND_ALPHA_PREMULTIPLY for layer compositing to prevent fade-to-dark artifacts.
  - Implemented trigger strip UI with cooldown pie shader: wand buttons show active triggers, cooldown visualization, wave interaction feedback, and dual tooltips for card/wand info.
  - Added card UI enhancements: Alt-preview shows card destination on hover, right-click quick-transfer between boards, improved trigger board capacity checks.
  - Created tooltip registry module for centralized tooltip lifecycle management with cache key storage for efficient hide/show.

12/25/2025
  - Shipped cross-platform save system: C++ save_io with async writes and atomic file operations, Lua SaveManager with collector pattern, Statistics module example, IDBFS web persistence, migrations scaffold, and ImGui debug tab.
  - Major performance optimization pass: eliminated O(n) collision clearing in physics PostUpdate, removed duplicate transform cache storage, cached UIBoxComponent view for hot-path queries, replaced O(n) vector erase with O(1) unordered_set.
  - Added performance profiling overlay (F12): real-time FPS, frame time, draw calls, entity counts with configurable display options.
  - Extended Lua DSL with button, progressBar, and layout helper functions for more expressive UI definitions.
  - Improved shader system: per-entity uniform support for flash effects, fixed 3D skew tilt to follow mouse position relative to sprite center.
  - Added entity validation helpers: safe_script_get and script_field functions for defensive script table access with fallback defaults.
  - Refactored event system: added dual-emission helper for combat bus→signal bridging, signal system architecture tests, and RenderStackError exception class for better error context.
  - Implemented lightning system foundation: status effects and marks data registry, status indicator system with floating icons and condensed bar for 3+ effects, shader integration for visual feedback.
  - Added mark system for detonatable combo mechanics: Static Charge/Static Shield cards, mark application on projectile hits, bonus damage via ActionAPI.
  - Added lightning-themed content: Storm Caller origin, Thunderclap prayer, Conductor/Storm Battery/Arc Reactor jokers, enhanced Stormlord avatar with mark and chain synergies.

12/26/2025
  - Implemented avatar proc effects system: PROC_EFFECTS registry (heal, barrier, poison), TRIGGER_HANDLERS (on_kill, on_cast_4th, distance_moved_5m), stat_buff effect application, register/cleanup lifecycle for equipped avatars.
  - Added Avatar of the Conduit: tracks chain lightning propagations for unlock, conduit_charge proc effect with decay timer, on_physical_damage_taken trigger, auto-equip and avatar strip sync.
  - Added extensible joker effect system with Lightning Rod implementation and integration flow documentation.
  - Implemented full death flow: player death animation with dissolve and blood particles, death screen UI with Text Builder, game reset function, signal emission from combat state machine, keyboard/click restart support.
  - Built wand resource bar: mana cost calculation, bar rendering integrated with planning phase, positioned above action board with proper z-level.
  - Fixed defensive marks to trigger when player is hit, HP reset and deck repopulation on game reset, WaveDirector cleanup.

12/27/2025
  - Implemented render_groups system: core group/entity management, CmdDrawRenderGroup command type, ExecuteDrawRenderGroup with z-sorting and lazy cleanup, Lua bindings exposed at startup.
  - Added executeEntityWithShaders function to render any entity with arbitrary shader list, enabling 3d_skew shader support with proper uniform setup.
  - Refactored resource bar from DSL to direct rendering for better control and performance.

12/28/2025
  - Fixed execution graph UI animation: SnapVisualTransformValues eliminates spring velocity to make graph appear instantly without lag or freeze.
  - Repositioned resource bar above action board with lowered z-level for cleaner visual hierarchy.
  - Fixed death flow: inventory cards now re-spawn with sequential animation on game reset.

12/29/2025
  - Added on-kill trigger card for wand system with documentation for trigger implementation patterns.
  - Implemented unified cast origin resolution system for consistent projectile spawning across different trigger types.
  - Comprehensive UI improvements for planning and action phases: better visual feedback, state transitions, and layout polish.
  - Standardized corner rounding in Lua to match C++ util::getCornerSizeForRect for consistent UI appearance.

12/30/2025
  - Expanded enemy behavior system with ranged attacks, behavior composition, and 8+ new enemy archetypes (skirmisher, bomber, summoner, etc.) plus comprehensive documentation.
  - Built configurable tutorial dialogue system: speaker sprites with shaders, typewriter text, input prompts, spotlight effect, and action queue for scripted sequences.
  - Added stencil-masked particle rendering for shader pipeline with sprite-shape masking instead of bounding rect.
  - Added outline shader pass to card rendering pipeline with toggleable preset.
  - Fixed stepped rounded rectangle rendering to use RL_TRIANGLES for proper fill display.
  - Fixed mini card progress shader and activation pulse timing in trigger strip UI.
  - Implemented render_groups for SpecialItem shader rendering with proper screen-space entity handling.

12/31/2025
  - Added sound effects to combat events: enemy spawn, wave start, elite spawn, stage complete, and random tutorial dialogue voices (6 variations).
  - Implemented tooltip enhancements: dynamic title effects (shimmer, glow), compact styling, and card descriptions with localized text.
  - Improved tutorial dialogue system: spotlight shader refinements, speaker animation states, and timer chain fixes.
  - Fixed queueDrawSprite API and prevented duplicate dialogue spawning.
  - Added demo polish features specification document outlining remaining work for vertical slice.
  - Implemented stats panel UI with Sol2 crash protection for safe property access.

01/01/2026
  - Implemented dynamic multi-light layer shader system: support for up to 16 simultaneous point/spot lights per layer with subtractive/additive blend modes.
  - Added lighting.lua fluent builder API with entity attachment for lights that follow movement, plus camera-aware UV conversion.
  - Created interactive lighting demo with 6 test scenarios showcasing different light types and effects.
  - Fixed integer uniform handling in ShaderUniformSet that was silently dropping int values.
  - Fixed scroll pane collision detection and timer API issues.

01/02/2026
  - Added patch notes modal accessible from main menu with DSL button for proper click handling.
  - Implemented planning phase sepia shader as fullscreen effect during PLANNING_STATE for visual phase differentiation.
  - Added outline support to 3d_skew shader family with configurable color and thickness uniforms.
  - Fixed MOD_CAST_FROM_EVENT + TRIGGER_ON_KILL to spawn projectiles at enemy death position instead of player position.
  - Added rightClick callback support to EntityBuilder for card context menus.
  - Updated critical hit damage numbers to display gold color instead of orange.
  - Fixed Y-flip in lighting shader for proper RenderTexture coordinate handling.
  - Synced Lua cookbook with codebase, adding 6 new recipes.

01/03/2026
  - Implemented C++ backend for rightClick callback in EntityBuilder, enabling proper mouse button detection for card interactions.
  - Fixed patch notes asset path resolution using util.getRawAssetPathNoUUID.

01/04/2026
  - Implemented Tooltip V2 system with 3-box vertical stack architecture (name, description, info boxes).
  - Added tooltip positioning cascade (RIGHT → LEFT → ABOVE → BELOW) with pop entrance animation.
  - Improved tooltip display: stats grid with colored tag pills, rich text markup, full caching with language change invalidation.
  - Added rarity-based text effects to tooltip titles and improved overall positioning logic.
  - Fixed shadow uniform type mismatch across shaders and improved outline rendering consistency.

01/05/2026
  - Added ChildBuilder fluent API for attaching child entities to parents with offset, rotation inheritance, and orbit animations.
  - Added EntityLinks module for horizontal entity dependencies ("die when target dies" patterns).
  - Improved card board layout algorithm with preferredGap (24px) and graceful overlap when needed.
  - Fixed shadow uniform from boolean to float comparison across 40+ shaders for WebGL compatibility.
  - Added performance optimizations inspired by Godot Engine: LTO for 18% binary size reduction, MinSizeRel configuration, and compile-time module toggles.
  - Added StringId system for O(1) string comparisons with compile-time FNV-1a hashing.
  - Implemented tab UI system with ReplaceChildren for efficient DOM-style updates.
  - Converted stats panel to use new tab system for organized stat display.
  - Eliminated shared_ptr ref-counting on render hot path with Layer* overloads for 25-40% render dispatch improvement.
  - Fixed sprite lookup race condition by deferring to prevent atlas loading issues.
  - Updated cookbook with TooltipV2 and TooltipEffects recipes.
  - Fixed UI cycle detection to prevent infinite recursion during element removal.
  - Hardened UI click propagation and crash reporting with 50-frame stack traces.
  - Improved tooltip text wrapping with proper container layout and standardized font hierarchy.
  - Enhanced card board layout to spread cards with variable gap (24-60px) when extra space available.
  - Added continuous highlight sweep animation to tooltip card names based on rarity.

01/06/2026
  - Fixed dynamic text entry binding to pass function instead of string, preventing crashes on card hover.
  - Replaced missing wand icon sprites with placeholder assets.

01/07/2026
  - Implemented inventory grid UI with drag-drop, sort buttons, tab switching, and slot snapping functionality.
  - Fixed screen-space collision for UI cards by combining ObjectAttachedToUITag with transform.set_space('screen') to resolve camera zoom coordinate mismatch.
  - Enhanced animation system with advanced playback controls including reverse, pause, resume, and frame callbacks.
  - Added equipment system design document outlining gear slots, stats, and upgrade mechanics.
  - Added annotation review system for Claude Code code review workflows.
  - Synced Lua cookbook with 3 new data definition recipes.

01/08/2026
  - Implemented custom sprite panel system with nine-patch stretching, decorations API, hover overlays, and comprehensive demo.
  - Major C++ refactoring: migrated 15+ systems from globals::getRegistry() to explicit registry parameters for better testability.
  - Added SystemRegistry for self-registering systems with priority-based initialization.
  - Added multi-tab grid switching to inventory demo with proper item visibility management during tab transitions.
  - Added forward declaration headers and removed duplicate includes to improve compile times.
  - Documented sprite panels/decorations API and Tiny Rogues design reference.

01/09/2026
  - Major C++ architectural refactoring with TDD: registry consolidation tests, Blackboard class extraction, GOAP utility extraction, Result<T,E> error handling tests.
  - Migrated enemies and clickedEntity from globals to EngineContext pattern (Phase 3.5).
  - Deprecated 19 unused JSON blobs identified in globals audit.
  - Added runtime validation for legacy registry access with deprecation warnings.
  - Updated inventory grid API with improved documentation and demo.
  - Added modal system infrastructure and Lua analysis reports.
  - Documented debug key mappings/conflicts, RAII patterns, and memory management guidelines.

01/10/2026
  - Continued C++ refactoring: extracted LDTK field converters, added binding_helpers.hpp with common Lua conversion utilities, and completed Phase 1 quick wins for code quality.
  - Fixed Lua type definitions (scaleX/scaleY → scale) for proper transform consistency.
  - Updated refactoring plan documentation with implementation status.

01/11/2026
  - Implemented card inventory panel with 4-tab grid system (Equipment, Wands, Triggers, Actions) supporting drag-drop, hover tooltips, sort/filter, and lock functionality.
  - Added localization keys (EN/KR) for inventory UI strings.
  - Synced Lua cookbook with Modal and Inventory Grid API recipes.

01/12/2026
  - Implemented Phase 1-2 of player inventory: infrastructure with open/close/toggle API, card space converter for screen/world transforms, and inventory-board drag-drop bridge.
  - Built visible inventory panel with header, tabs, footer, and grid area using dsl.inventoryGrid with proper tab switching and cleanup.
  - Moved inventory to world-space and repositioned tab demo panel.

01/13/2026
  - Implemented wand loadout panel with 2x4 action grid and trigger slot, E-key toggle, and click-outside-to-close behavior.
  - Added drag-drop functionality with z-order elevation during drag and snap-back on invalid drops.
  - Implemented right-click quick equip for inventory cards to wand slots.
  - Built atomic cross-grid transfer module with rollback safety for moving cards between inventory and loadout.
  - Added item location registry for tracking card positions across multiple grids.
  - Implemented grid inventory save/load with slot positions using SaveManager collectors.
  - Integrated wand grid adapter sync with combat system for proper wand loading before action phase.
  - Added invalid drag target visual feedback (red flash) when dropping cards on incompatible slots.

01/14/2026
  - Built comprehensive Lua test infrastructure: describe/it structure, expect() fluent matcher API, standalone test execution for CI.
  - Implemented schema validation system with typo detection using string similarity for helpful error messages.
  - Added dsl.strict.* API for opt-in validation of UI components at construction time.
  - Created showcase gallery viewer with browsable UI examples for primitives, layouts, and patterns.
  - Migrated UI handler system: extracted handlers for containers, text, objects, and scroll panes.
  - Fixed inventory z-order bugs preventing cards from rendering above panel backgrounds.
  - Added comprehensive documentation: LuaDoc API reference, deprecation notices, and 30-day conversation retrospective.

01/15/2026
  - Implemented UIValidator module with 7 validation rules: containment, window bounds, sibling overlap, z-order hierarchy, global overlap, z-order occlusion, and edge proximity.
  - Migrated all core UI files to dsl.strict across 4 phases for consistent validation coverage.
  - Split layer.cpp into focused files for faster compilation and better maintainability.
  - Fixed critical C++ crash prevention issues and cleaned up code quality.
  - Resolved signal handlers initialization and fixed remaining bare module references.

01/16/2026
  - Fixed critical bugs in box.cpp layout system causing incorrect element positioning.
  - Added global_overlap and z_order_occlusion validation rules with skip option for intentionally layered elements.
  - Implemented standalone inventory tab marker sprite for visual feedback.
  - Added close button positioning fixes with edge_proximity validation.
  - Created AUTO_EXIT_AFTER_TEST for clean test process termination.

01/17/2026
  - Implemented comprehensive UI filler system with flexbox-like behavior: proportional space distribution, flex weights, and maxFill constraints.
  - Fixed gallery viewer scroll issues and updated UI showcase demos.
  - Added UI layout refactor safeguards with proper validation.
  - Fixed inventory tab marker anchoring for consistent positioning.
  - Added Q module enhancements and improved timer API with Lua type definitions.

01/19/2026
  - Trimmed CLAUDE.md by 80% and extracted detailed API documentation to docs/api/ for better organization.
  - Updated inventory assets and UI with new sprite backgrounds.
  - Added documentation plans for inventory sprite background and right-click context menu fixes.
  - Expanded inventory plan with drag-drop sorting and auto-categorize task specifications.
  - Added tool call chunking rules to prevent AI implementation hanging on large files.
