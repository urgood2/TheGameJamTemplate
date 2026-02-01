# Pitfalls Inventory

**Generated**: 2026-01-30
**Purpose**: Raw inventory of all pitfalls, gotchas, and warnings from project documentation
**Plan**: documentation-foundation (Task 3 of 15)

## Summary

| Category | Count |
|----------|-------|
| UI/DSL | 28 |
| Physics | 15 |
| Scripting/Lua | 42 |
| Content Creation | 35 |
| Combat/Wand | 8 |
| Rendering/Shaders | 18 |
| Timers | 12 |
| General | 25 |
| **TOTAL** | **183** |

---

## UI/DSL Pitfalls

| # | Source File | Pitfall Description | Verified |
|---|-------------|---------------------|----------|
| 1 | docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md:999 | 11 documented pitfalls table - comprehensive UI panel issues | Pending |
| 2 | docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md:1008 | Skipping `CardUIPolicy.setupForScreenSpace` - Wrong collision, wrong z-order, invisible | Pending |
| 3 | docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md:1010 | Using wrong z-order values - Cards hidden behind panel/grid | Pending |
| 4 | docs/ui/getting-started-with-strict.md:51 | Common mistakes caught by strict mode (type errors, missing fields) | Pending |
| 5 | docs/ui/getting-started-with-strict.md:224 | Wrong type errors - field 'X' expected Y, got Z | Pending |
| 6 | docs/ui/writing-ui-tests.md:162 | Wrong case in dsl.strict.text - fontsize vs fontSize | Pending |
| 7 | docs/analysis/claude-md-additions.md:35 | Forgetting ScreenSpaceCollisionMarker for UI elements - won't receive clicks | Pending |
| 8 | docs/analysis/claude-md-additions.md:49 | Mixing World and Screen DrawCommandSpace - HUD follows camera | Pending |
| 9 | docs/analysis/conversation-retrospective-2026-01.md:63 | Cards don't drop into inventory slots - drag/drop never registers | Pending |
| 10 | docs/analysis/conversation-retrospective-2026-01.md:129 | Wrong DrawCommandSpace causes position miscalculation | Pending |
| 11 | docs/skills/debug-ui-click.md:97 | Wrong position - Check DrawCommandSpace World/Screen | Pending |
| 12 | docs/TROUBLESHOOTING.md:13 | Wrong z-order - entity behind other entities | Pending |
| 13 | docs/TROUBLESHOOTING.md:240 | Wrong rendering layer | Pending |
| 14 | docs/TROUBLESHOOTING.md:276 | Wrong Layer / Z-Order - renders at wrong depth | Pending |
| 15 | docs/api/z-order-rendering.md | Z-order assignment issues | Pending |
| 16 | docs/api/ui-dsl-reference.md | DSL config structure requirements | Pending |
| 17 | docs/api/ui_helper_reference.md | UI helper usage patterns | Pending |
| 18 | docs/api/sprite-panels.md | Sprite panel setup requirements | Pending |
| 19 | docs/api/inventory-grid.md | Inventory grid configuration | Pending |
| 20 | claude.md:156 | Missing ScreenSpaceCollisionMarker - UI element won't receive clicks | Pending |
| 21 | claude.md:163 | Wrong DrawCommandSpace - HUD element follows camera incorrectly | Pending |
| 22 | docs/lua-cookbook/cookbook.md:1552 | Data assigned BEFORE attach_ecs automatically | Pending |
| 23 | docs/lua-cookbook/cookbook.md:1554 | Script return value only present if data option passed | Pending |
| 24 | docs/guides/entity-scripts.md:98 | Entity won't respect game phase visibility | Pending |
| 25 | docs/api/entity-builder.md:65 | Data lost - wrong attach order | Pending |
| 26 | docs/api/lua-cpp-documentation-guide.md:198 | Data assigned after attach_ecs - WRONG | Pending |
| 27 | docs/PRISM_MIGRATION_PLAN.md:1069 | gridPos lost after attach_ecs | Pending |
| 28 | docs/analysis/proposed-skills/debug-ui-collision.md:3 | UI elements don't respond to clicks diagnostic | Pending |

---

## Physics Pitfalls

| # | Source File | Pitfall Description | Verified |
|---|-------------|---------------------|----------|
| 29 | docs/api/physics_docs.md:42 | Gotchas & FAQs section | Pending |
| 30 | docs/api/physics_docs.md:428 | Arbiter Caveats - important when working with physics.Arbiter | Pending |
| 31 | docs/api/physics_docs.md:473 | Wrong parameter order in properties - userdata errors | Pending |
| 32 | docs/api/physics_docs.md:475 | Expected userdata, got no value - bound C++ function order issue | Pending |
| 33 | docs/api/physics_docs.md:795 | Physics Gotchas & FAQs comprehensive list | Pending |
| 34 | docs/TROUBLESHOOTING.md:134 | Wrong collision tags | Pending |
| 35 | docs/TROUBLESHOOTING.md:136 | Bodies on wrong physics world | Pending |
| 36 | docs/TROUBLESHOOTING.md:178 | Physics system not initialized, or wrong world name | Pending |
| 37 | docs/TROUBLESHOOTING.md:183 | Using old globals.physicsWorld pattern - WRONG | Pending |
| 38 | src/systems/physics/steering_readme.md | Steering behavior pitfalls | Pending |
| 39 | docs/api/lua_quadtree_api.md | Quadtree query pitfalls | Pending |
| 40 | docs/guides/implementation-summaries/PROJECTILE_PHYSICS_INTEGRATION.md | Projectile physics integration issues | Pending |
| 41 | docs/content-creation/ADDING_PROJECTILES.md:365 | Homing without strength - WRONG | Pending |
| 42 | docs/content-creation/ADDING_PROJECTILES.md:383 | Forgetting lifetime - Projectile may never despawn | Pending |
| 43 | docs/content-creation/ADDING_PROJECTILES.md:385 | Lives forever if it misses - WRONG | Pending |

---

## Scripting/Lua Pitfalls

| # | Source File | Pitfall Description | Verified |
|---|-------------|---------------------|----------|
| 44 | docs/analysis/claude-md-additions.md:14 | Exceed LuaJIT's 200 local variable limit | Pending |
| 45 | docs/analysis/claude-md-additions.md:17 | File-scope locals accumulate in large files - WRONG | Pending |
| 46 | docs/analysis/conversation-retrospective-2026-01.md:108 | Lua expects table structures that don't match C++ userdata | Pending |
| 47 | docs/analysis/conversation-retrospective-2026-01.md:228 | LuaJIT local variable limit warning needed | Pending |
| 48 | docs/api/working_with_sol.md | Sol2 integration patterns and pitfalls | Pending |
| 49 | docs/api/lua-cpp-documentation-guide.md:3 | C++/Lua binding common pitfalls | Pending |
| 50 | docs/api/lua-cpp-documentation-guide.md:191 | Common Pitfalls & Fixes section | Pending |
| 51 | docs/api/lua-cpp-documentation-guide.md:216 | May cause unexpected behavior - WRONG | Pending |
| 52 | docs/api/lua-cpp-documentation-guide.md:276 | C++ expects specific callback signatures; Lua provides wrong params | Pending |
| 53 | docs/api/lua-cpp-documentation-guide.md:280 | Missing parameters - WRONG | Pending |
| 54 | docs/api/lua-cpp-documentation-guide.md:293 | Timer Callback in Wrong Lua State | Pending |
| 55 | docs/api/lua-cpp-documentation-guide.md:313 | Creates a table, not a Color - WRONG | Pending |
| 56 | docs/TROUBLESHOOTING.md:60 | This will fail - WRONG | Pending |
| 57 | docs/TROUBLESHOOTING.md:352 | Component doesn't exist - WRONG | Pending |
| 58 | docs/TROUBLESHOOTING.md:362 | Script table not initialized - WRONG | Pending |
| 59 | docs/TROUBLESHOOTING.md:375 | Module not available - WRONG | Pending |
| 60 | docs/TROUBLESHOOTING.md:391 | Function doesn't exist on object - WRONG | Pending |
| 61 | docs/TROUBLESHOOTING.md:399 | Global function not defined - WRONG | Pending |
| 62 | docs/TROUBLESHOOTING.md:407 | Module function doesn't exist - WRONG | Pending |
| 63 | docs/TROUBLESHOOTING.md:432 | Infinite signal loop - WRONG | Pending |
| 64 | docs/TROUBLESHOOTING.md:446 | Creating entities during view iteration - WRONG | Pending |
| 65 | docs/TROUBLESHOOTING.md:72 | Assign data BEFORE attach_ecs - CRITICAL | Pending |
| 66 | docs/lua-cookbook/cookbook.md:185 | Don't use require("assets.scripts.core.timer") - wrong paths | Pending |
| 67 | docs/lua-cookbook/cookbook.md:243 | Import bundles return values in fixed order | Pending |
| 68 | docs/lua-cookbook/cookbook.md:245 | PhysicsManager may be nil in certain contexts | Pending |
| 69 | docs/lua-cookbook/cookbook.md:283 | Always validate in callbacks - entity may be destroyed | Pending |
| 70 | docs/lua-cookbook/cookbook.md:327 | Component names are globals - don't quote them | Pending |
| 71 | docs/lua-cookbook/cookbook.md:658 | Use signal.emit() NOT publishLuaEvent() (deprecated) | Pending |
| 72 | docs/lua-cookbook/cookbook.md:721 | Bridge is one-way (bus → signal) to avoid loops | Pending |
| 73 | docs/lua-cookbook/cookbook.md:723 | Only explicitly listed events are bridged | Pending |
| 74 | docs/lua-cookbook/cookbook.md:791 | After cleanup(), group will warn on new handlers | Pending |
| 75 | docs/lua-cookbook/cookbook.md:1046 | Effect lags behind fast-moving entity - WRONG | Pending |
| 76 | docs/lua-cookbook/cookbook.md:1092 | Functions return false/nil if entity has no Transform | Pending |
| 77 | docs/lua-cookbook/cookbook.md:1156 | Constants are lowercase strings internally | Pending |
| 78 | docs/lua-cookbook/cookbook.md:1158 | Use C.States.ACTION instead of internal strings | Pending |
| 79 | docs/lua-cookbook/cookbook.md:1232 | FSM state names independent of global constants | Pending |
| 80 | docs/lua-cookbook/cookbook.md:1394 | Always call release() when done with pooled object | Pending |
| 81 | docs/lua-cookbook/cookbook.md:1396 | acquire() returns nil if pool at max capacity | Pending |
| 82 | docs/lua-cookbook/cookbook.md:1444 | Set Debug.enabled = false in production | Pending |
| 83 | docs/lua-cookbook/cookbook.md:1511 | Max 16 lights per layer (shader limit) | Pending |
| 84 | docs/lua-cookbook/cookbook.md:1628 | Escape hatches return raw objects - mix freely | Pending |
| 85 | docs/external/color_README.md:167 | Color strictness & pitfalls | Pending |

---

## Content Creation Pitfalls

| # | Source File | Pitfall Description | Verified |
|---|-------------|---------------------|----------|
| 86 | docs/content-creation/ADDING_AVATARS.md:523 | Common Mistakes section | Pending |
| 87 | docs/content-creation/ADDING_AVATARS.md:525 | Missing unlock conditions - Avatar can never be unlocked | Pending |
| 88 | docs/content-creation/ADDING_AVATARS.md:527 | No unlock - WRONG | Pending |
| 89 | docs/content-creation/ADDING_AVATARS.md:554 | Typo - WRONG | Pending |
| 90 | docs/content-creation/ADDING_AVATARS.md:561 | Wrong OR_ prefix format - Alternative path doesn't work | Pending |
| 91 | docs/content-creation/ADDING_TRIGGERS.md:439 | Common Mistakes section | Pending |
| 92 | docs/content-creation/ADDING_TRIGGERS.md:442 | Signal never emitted - Verify signal.emit() called | Pending |
| 93 | docs/content-creation/ADDING_TRIGGERS.md:443 | Wrong event name - case-sensitive | Pending |
| 94 | docs/content-creation/ADDING_CARDS.md:243 | Common Mistakes section | Pending |
| 95 | docs/content-creation/ADDING_CARDS.md:247 | Missing required fields - WRONG | Pending |
| 96 | docs/content-creation/ADDING_CARDS.md:256 | No tags - WRONG | Pending |
| 97 | docs/content-creation/ADDING_CARDS.md:265 | Typo - WRONG | Pending |
| 98 | docs/content-creation/ADDING_CARDS.md:272 | Wrong type - Modifiers with damage, actions with multicast | Pending |
| 99 | docs/content-creation/ADDING_CARDS.md:274 | Modifier shouldn't have base damage - WRONG | Pending |
| 100 | docs/content-creation/ADDING_PROJECTILES.md:341 | Common Mistakes section | Pending |
| 101 | docs/content-creation/ADDING_PROJECTILES.md:345 | Missing required config - WRONG | Pending |
| 102 | docs/content-creation/ADDING_PROJECTILES.md:355 | Invalid sprite reference - WRONG | Pending |
| 103 | docs/content-creation/ADDING_PROJECTILES.md:376 | Wrong collision setup - WRONG | Pending |
| 104 | docs/content-creation/ADDING_JOKERS.md:312 | Common Mistakes section | Pending |
| 105 | docs/content-creation/ADDING_JOKERS.md:316 | No return - WRONG | Pending |
| 106 | docs/content-creation/ADDING_JOKERS.md:334 | Crashes if tags is nil - WRONG | Pending |
| 107 | docs/content-creation/ADDING_JOKERS.md:341 | Wrong event name - case-sensitive | Pending |
| 108 | docs/content-creation/ADDING_JOKERS.md:343 | Event name case mismatch - WRONG | Pending |
| 109 | docs/content-creation/ADDING_JOKERS.md:352 | Removes all damage - WRONG | Pending |
| 110 | docs/content-creation/ADDING_JOKERS.md:361 | Wrong multiplier logic - WRONG | Pending |
| 111 | docs/content-creation/ADDING_JOKERS.md:461 | Unknown tags validation - add to known list | Pending |
| 112 | docs/content-creation/CONTENT_OVERVIEW.md:74 | Table key should match id field to avoid warnings | Pending |
| 113 | docs/content-creation/ADDING_ENEMIES.md | Enemy configuration pitfalls | Pending |
| 114 | docs/content-creation/COMPLETE_GUIDE.md:676 | Draw outer warning circle pattern | Pending |
| 115 | docs/guides/entity-scripts.md:3 | Initialization pattern - getting wrong causes data loss | Pending |
| 116 | docs/api/behaviors.md | Behavior configuration requirements | Pending |
| 117 | docs/api/combat-systems.md | Combat system setup issues | Pending |
| 118 | docs/api/signal_system.md | Signal emission requirements | Pending |
| 119 | docs/api/localization.md | Localization key formatting | Pending |
| 120 | docs/api/save-system.md | Save system data requirements | Pending |

---

## Combat/Wand Pitfalls

| # | Source File | Pitfall Description | Verified |
|---|-------------|---------------------|----------|
| 121 | docs/systems/combat/wand_README.md | Wand system overview pitfalls | Pending |
| 122 | docs/systems/combat/WAND_INTEGRATION_GUIDE.md | Wand integration requirements | Pending |
| 123 | docs/systems/combat/WAND_EXECUTION_ARCHITECTURE.md | Wand execution order issues | Pending |
| 124 | docs/systems/combat/PROJECTILE_SYSTEM_DOCUMENTATION.md | Projectile system requirements | Pending |
| 125 | docs/systems/combat/PROJECTILE_ARCHITECTURE.md | Projectile architecture constraints | Pending |
| 126 | docs/systems/combat/QUICK_REFERENCE.md | Combat API quick reference caveats | Pending |
| 127 | docs/systems/combat/ARCHITECTURE.md | Combat architecture constraints | Pending |
| 128 | docs/systems/combat/integration_tutorial_WIP.md | Integration tutorial caveats | Pending |

---

## Rendering/Shader Pitfalls

| # | Source File | Pitfall Description | Verified |
|---|-------------|---------------------|----------|
| 129 | docs/analysis/proposed-skills/debug-shader-coordinates.md:12 | Shader positions don't match screen positions | Pending |
| 130 | docs/analysis/proposed-skills/debug-shader-coordinates.md:54 | WRONG ORDER in shader | Pending |
| 131 | docs/analysis/claude-md-additions.md:88 | rotate2d used before definition - WRONG | Pending |
| 132 | docs/analysis/conversation-retrospective-2026-01.md:44 | SHADER Failed to compile - WARNING | Pending |
| 133 | docs/guides/shaders/RAYLIB_SHADER_GUIDE.md:280 | Colors look wrong | Pending |
| 134 | docs/guides/implementation-summaries/PIPELINE_DIAGNOSTICS_ADDED.md:50 | Player renders in completely wrong position | Pending |
| 135 | docs/guides/implementation-summaries/PIPELINE_DIAGNOSTICS_ADDED.md:129 | Wrong Position Rendering issue | Pending |
| 136 | docs/guides/implementation-summaries/PIPELINE_QUIRKS_FIXED.md:7 | Player renders in wrong position sometimes | Pending |
| 137 | docs/guides/implementation-summaries/PIPELINE_QUIRKS_FIXED.md:18 | Using wrong RenderTextureCache - WRONG | Pending |
| 138 | docs/guides/implementation-summaries/PIPELINE_QUIRKS_FIXED.md:113 | Detecting Wrong Position Rendering | Pending |
| 139 | docs/guides/implementation-summaries/PIPELINE_QUIRKS_FIXED.md:129 | Render stack issues - drawing to wrong target | Pending |
| 140 | docs/guides/implementation-summaries/PIPELINE_QUIRKS_FIXED.md:165 | If Wrong Position Still Occurs | Pending |
| 141 | docs/guides/implementation-summaries/PIPELINE_CAMERA_FIX_V2.md:18 | Child draws appear in wrong positions | Pending |
| 142 | docs/api/shader-builder.md:51 | Shader builder WRONG example | Pending |
| 143 | docs/api/shader_draw_commands_doc.md | Shader draw command requirements | Pending |
| 144 | docs/api/render-groups.md | Render group configuration | Pending |
| 145 | docs/guides/shaders/SHADER_SNIPPETS.md | Shader snippet usage patterns | Pending |
| 146 | docs/guides/shaders/shader_web_error_msgs.md | WebGL shader error handling | Pending |

---

## Timer Pitfalls

| # | Source File | Pitfall Description | Verified |
|---|-------------|---------------------|----------|
| 147 | docs/api/timer_docs.md:40 | Migration Notes & Gotchas section | Pending |
| 148 | docs/api/timer_docs.md:492 | Timer migration gotchas comprehensive | Pending |
| 149 | docs/api/timer_chaining.md | Timer chaining patterns | Pending |
| 150 | docs/lua-cookbook/cookbook.md:430 | If times is 0 or nil, timer runs forever | Pending |
| 151 | docs/lua-cookbook/cookbook.md:459 | Physics step timers separate - use cancel_physics_step() | Pending |
| 152 | docs/lua-cookbook/cookbook.md:530 | Call :start() to execute - chain does nothing until started | Pending |
| 153 | docs/lua-cookbook/cookbook.md:532 | Steps execute sequentially. Use :fork() for parallel | Pending |
| 154 | docs/lua-cookbook/cookbook.md:578 | After scope:destroy(), cannot accept new timers | Pending |
| 155 | docs/lua-cookbook/cookbook.md:1286 | Don't forget to call :start() on tweens | Pending |
| 156 | docs/lua-cookbook/cookbook.md:1288 | Tweens use timer internally - use :tag() to cancel | Pending |
| 157 | docs/lua-cookbook/cookbook.md:1338 | Call :go() to execute chain - nothing happens without it | Pending |
| 158 | docs/lua-cookbook/cookbook.md:977 | Options API uses table syntax - don't forget curly braces | Pending |

---

## General Pitfalls

| # | Source File | Pitfall Description | Verified |
|---|-------------|---------------------|----------|
| 159 | claude.md | Common Mistakes to Avoid section (lines 132-198) | Pending |
| 160 | docs/README.md:53 | AI Caveats - Known issues and workarounds | Pending |
| 161 | docs/README.md:120 | Animation Warnings - Animation gotchas | Pending |
| 162 | docs/PROFILING_GUIDE.md:70 | debug.sethook adds 10-100x overhead WARNING | Pending |
| 163 | docs/IMPLEMENTATION_PLAN_BatchRenderingImprovements.md:762 | Migration warnings when using old API | Pending |
| 164 | docs/guides/OWNERSHIP_SYSTEM.md:554 | Don't modify ownership links - WRONG | Pending |
| 165 | docs/guides/LUA_USABILITY_MODULES.md:38 | Wrong types issues | Pending |
| 166 | docs/guides/implementation-summaries/TASK_5_BUG_FIXES_REPORT.md:192 | Rotation sync logic checks wrong flag | Pending |
| 167 | docs/PRISM_MIGRATION_PLAN.md:1409 | Document any gotchas in plan | Pending |
| 168 | docs/api/lua_camera_docs.md:3 | Camera gotchas and quick reference | Pending |
| 169 | docs/api/lua_camera_docs.md:295 | Gotchas & Best Practices section | Pending |
| 170 | docs/api/lua_api_reference.md:111 | Controller navigation patterns and pitfalls | Pending |
| 171 | docs/api/particles_doc.md:222 | API Details & Gotchas | Pending |
| 172 | docs/skills/ui-design.md:146 | Gotchas, tips, references section | Pending |
| 173 | docs/WEB_PROFILING_QUICK_REF.md:97 | Frame times seem wrong | Pending |
| 174 | docs/systems/ai-behavior/AI_CAVEATS.md | AI system known issues | Pending |
| 175 | docs/systems/ai-behavior/AI_README.md | AI system overview caveats | Pending |
| 176 | docs/assets/animation_WARNINGS.md | Animation system warnings | Pending |
| 177 | docs/assets/BABEL_EDIT_WARNING.md | Localization tool warnings | Pending |
| 178 | docs/assets/LOCALIZATION_NOTES.md | Localization notes and issues | Pending |
| 179 | docs/lua-cookbook/cookbook.md:865 | Uses Q.visualCenter() internally | Pending |
| 180 | docs/lua-cookbook/cookbook.md:979 | Convenience wrappers - fall back to positional versions | Pending |
| 181 | docs/tools/DEBUGGING_LUA.md | Lua debugging pitfalls | Pending |
| 182 | docs/guides/MEMORY_MANAGEMENT.md | Memory management pitfalls | Pending |
| 183 | docs/guides/ERROR_HANDLING_POLICY.md | Error handling requirements | Pending |

---

## Notes

- Total pitfalls captured: 183
- Source: grep search for "don't|WRONG|pitfall|gotcha|caveat|WARNING|CRITICAL|mistake|avoid|never"
- Excludes: docs/plans/, docs/project-management/, docs/specs/, research docs (dcss, poa, snkrx, vampire, magicraft)
- Priority categories for consolidation: UI/DSL, Physics, Scripting/Lua
- Reference format for COMMON_PITFALLS.md: see docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md:999-1013
