# Draft: Comprehensive Documentation Foundation

## User Requirements (Confirmed)

### Primary Goals
1. **Human Developer Onboarding** - Help new developers understand codebase quickly
2. **Full Verification** - Test every code example against actual runtime behavior
3. **Keep distributed but indexed** - Leave docs near code, create comprehensive index
4. **`claude.md` as primary entry point** that connects to a hierarchical AGENTS.md knowledge base

### Priority Systems (in order)
1. UI/DSL - Verify existing excellent docs
2. Physics - Verify existing good docs
3. Common Pitfalls - Consolidate scattered warnings into single reference
4. Combat/Wand - Verify extensive existing docs

### Secondary Systems (document/verify as time permits)
- Audio/Sound (minimal docs - needs expansion)
- Animations (minimal docs - needs expansion)
- Shaders (good individual docs, needs workflow documentation)
- Timer/Coroutines (good but has disabled warning)

---

## Current Documentation Inventory

### Root Level Docs
| File | Lines | Purpose | Status |
|------|-------|---------|--------|
| `claude.md` | 292 | AI agent guidance, architecture, common mistakes | VERIFY |
| `codex.md` | 58 | Lua bindings & scripts reference | VERIFY |
| `README.md` | 106 | Project overview, build commands | VERIFY |
| `USING_TRACY.md` | ? | Performance profiling | VERIFY |
| `BATCHED_ENTITY_RENDERING.md` | ? | Draw command batching | VERIFY |
| `DRAW_COMMAND_OPTIMIZATION.md` | ? | Rendering optimization | VERIFY |

### docs/api/ (33 files)
**UI & Layout:**
- `ui-dsl-reference.md` - DSL system (369 lines) - VERIFY
- `ui_helper_reference.md` - UI utilities - VERIFY
- `ui-validation.md` - Layout validation - VERIFY
- `sprite-panels.md` - Nine-patch panels - VERIFY
- `render-groups.md` - Batched rendering - VERIFY
- `z-order-rendering.md` - Z-ordering, DrawCommandSpace - VERIFY
- `inventory-grid.md`, `inventory-grid-quick-reference.md` - Grid system - VERIFY

**Entity & Physics:**
- `entity-builder.md` - Entity creation (87 lines) - VERIFY
- `child-builder.md` - Parent-child attachment - VERIFY
- `physics_docs.md` - Physics + steering (extensive) - VERIFY
- `lua_quadtree_api.md` - Spatial partitioning - VERIFY

**Events & Timing:**
- `signal_system.md` - Event system (150 lines) - VERIFY
- `timer_docs.md` - Timer API (disabled warning) - VERIFY
- `timer_chaining.md` - Timer chaining patterns - VERIFY

**Effects & Animation:**
- `text-builder.md` - Animated text - VERIFY
- `hitfx_doc.md` - Hit effects - VERIFY
- `particles_doc.md` - Particle system - VERIFY
- `popup.md` - Damage/heal numbers - VERIFY

**Shaders:**
- `shader-builder.md` - Attaching shaders - VERIFY
- `shader_draw_commands_doc.md` - Draw API - VERIFY

**Combat:**
- `combat-systems.md` - Combat mechanics - VERIFY
- `behaviors.md` - Enemy behavior composition - VERIFY

**Other:**
- `lua_api_reference.md` - Main Lua API reference - VERIFY
- `lua_camera_docs.md` - Camera system - VERIFY
- `localization.md` - i18n system - VERIFY
- `save-system.md` - Save/load - VERIFY
- `Q_reference.md` - Quick transform helpers - VERIFY
- `working_with_sol.md` - C++/Lua binding guide - VERIFY

### docs/guides/ (17 files)
**Critical:**
- `UI_PANEL_IMPLEMENTATION_GUIDE.md` - 1088 lines! Bulletproof patterns - VERIFY
- `SYSTEM_ARCHITECTURE.md` - Core architecture - VERIFY
- `entity-scripts.md` - Script initialization patterns - VERIFY
- `ERROR_HANDLING_POLICY.md` - Error handling - VERIFY

**Shaders:**
- `shaders/RAYLIB_SHADER_GUIDE.md` - Writing shaders - VERIFY
- `shaders/SHADER_SNIPPETS.md` - Reusable code - VERIFY
- Plus 4 more shader guides

**Other:**
- `TESTING_GUIDE.md` - Testing strategies - VERIFY
- `DEBUG_KEYS.md` - Debug key bindings - VERIFY
- `MEMORY_MANAGEMENT.md` - Memory patterns - VERIFY
- `OWNERSHIP_SYSTEM.md` - Game theft prevention - VERIFY

### docs/content-creation/ (8 files)
- `CONTENT_OVERVIEW.md` - Quick index
- `ADDING_CARDS.md`, `ADDING_ENEMIES.md`, `ADDING_JOKERS.md`
- `ADDING_PROJECTILES.md`, `ADDING_TRIGGERS.md`, `ADDING_AVATARS.md`
- `COMPLETE_GUIDE.md` - Comprehensive walkthrough

### docs/systems/ (multiple subdirs)
**combat/** (11 files):
- `ARCHITECTURE.md`, `README.md`, `QUICK_REFERENCE.md`
- `INTEGRATION_GUIDE.md`, `PROJECTILE_SYSTEM_DOCUMENTATION.md`
- `WAND_INTEGRATION_GUIDE.md`, `WAND_EXECUTION_ARCHITECTURE.md`
- Plus integration tutorials

**ai-behavior/** (4 files):
- `AI_README.md`, `AI_CAVEATS.md`
- `nodemap_README.md`, `monobehavior_readme.md`

**text-ui/** (2 files):
- `static_ui_text_system_doc.md`, `command_buffer_text.md`

**core/** (1 file):
- `entity_state_management_doc.md`

### Scattered System Docs (in src/)
- `src/systems/text/dynamic_text_documentation.md`
- `src/systems/text/static_ui_text_documentation.md`
- `src/systems/text/effects_documentation.md`
- `src/systems/spring/spring_lua.md`
- `src/systems/reflection/readme.md`
- `src/systems/physics/steering_readme.md`
- `src/systems/layer/tutorial.md`
- `src/systems/input/input_action_binding_usage.md`
- `src/systems/composable_mechanics/integration_notes.md`
- `src/core/game_init_cheatsheet.md`

---

## Identified Documentation Gaps

### 1. Common Pitfalls (Scattered - needs consolidation)
Currently in `claude.md`:
- Don't store data in GameObject component
- Don't call attach_ecs before assigning data
- Don't exceed LuaJIT's 200 local variable limit
- Don't forget ScreenSpaceCollisionMarker for UI elements
- Don't mix World and Screen DrawCommandSpace
- Don't use ChildBuilder.setOffset without RenewAlignment

In `UI_PANEL_IMPLEMENTATION_GUIDE.md`:
- 11 specific pitfalls with symptoms and fixes

Need to:
- Extract ALL pitfalls from all docs
- Organize by category (UI, Physics, Scripting, etc.)
- Create single `COMMON_PITFALLS.md` or section in `claude.md`

### 2. Audio/Sound System
Current state: Only API function list in `lua_api_reference.md`
Needs:
- Architecture overview
- Sound playback patterns
- Music/playlist management
- Filter effects usage
- Common audio patterns

### 3. Animation System
Current state: Minimal (`animation_WARNINGS.md` only)
Needs:
- `animation_system.createAnimatedObjectWithTransform` usage
- Animation state management
- Sprite atlas workflow
- Animation timing patterns

### 4. Shader Workflow
Current state: Good individual docs but no workflow
Needs:
- End-to-end shader creation workflow
- Shader pipeline setup patterns
- Common shader effects (flash, dissolve, glow)
- Web vs native shader differences

### 5. Index/Navigation
Current state: `docs/README.md` exists but:
- Not all docs are indexed
- No cross-referencing between related docs
- `claude.md` and `docs/README.md` partially overlap

---

## Architecture Decisions

### 1. Entry Point Structure
```
claude.md (PRIMARY - AI agent entry point)
├── Architecture Overview (keep)
├── Build Commands (keep)
├── Common Mistakes (EXPAND with consolidated pitfalls)
├── API Documentation Index (link to docs/README.md)
└── Link to AGENTS.md knowledge base

AGENTS.md (SECONDARY - hierarchical knowledge)
├── Links to deep-dive docs
├── System-specific guidance
└── Structured for /init-deep pattern
```

### 2. Verification Strategy
For each doc:
1. Extract all code examples
2. Create test script that runs examples
3. Capture actual output vs documented output
4. Flag discrepancies
5. Fix docs to match actual behavior

### 3. Index Strategy
- Keep `docs/README.md` as comprehensive index
- Add "See Also" sections to each doc
- Create cross-reference links
- Add search keywords/tags

---

## Test Infrastructure Assessment

### Current State
- GoogleTest for C++ tests in `tests/`
- Lua scripts can be tested via runtime
- No systematic doc verification tests

### Verification Approach
- Create Lua test scripts for each doc
- Run via `just build-debug && ./build/raylib-cpp-cmake-template`
- Capture output with timeout
- Compare against expected behavior

---

## Open Questions (Resolved)

1. ✅ Primary use case: Human Developer Onboarding
2. ✅ Verification level: Full verification
3. ✅ Documentation location: Keep distributed but indexed
4. ✅ Format: claude.md connects to AGENTS.md
5. ✅ Priority systems: UI, Physics, Common Pitfalls, Combat/Wand

---

## Next Steps

1. Consult Metis for gap analysis
2. Generate detailed work plan with TODOs
3. Organize into parallel execution waves
