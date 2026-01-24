# Lua API Usability Improvements & Feature Upgrades

> **Vision**: Make the Lua API so intuitive that "future amnesiac self" can write correct code without looking up documentation.
>
> **Inspiration**: Love2D's simplicity - minimal boilerplate, straightforward APIs.
>
> **Success Metric**: Less time spent checking docs, more time building.

---

## Scope & Current State (Reality Check)

This doc is written for this repo layout:
- Lua gameplay code: `assets/scripts/**`
- LuaLS stubs:
  - Generated bindings: `assets/scripts/chugget_code_definitions.lua` (generated; treat as read-only)
  - Handwritten DX stubs: `assets/scripts/types/**` (stable, curated)

Already present in the codebase (so this doc should not propose re-inventing them):
- **Options-table timer APIs** (`*_opts`) already exist in `assets/scripts/core/timer.lua`.
- A **constants module** already exists at `assets/scripts/core/constants.lua` (expand it; don’t create a second one).
- `component_cache.safe_get(eid, Comp)` already exists (improve error quality if needed; don’t add a competing `safe_get` global).

---

## Guiding Principles

1. **Self-documenting over documented** - APIs should be obvious from their signature
2. **No magic strings** - Use enums, constants, or typed tables instead of arbitrary strings
3. **No verbose boilerplate** - One line to do the thing, not ten lines of setup
4. **Escape hatches everywhere** - Builders return raw objects, never trap users in abstractions
5. **Debug-only safety** - Helpful errors in debug builds, zero overhead in release

---

## Priority 1: LSP & Autocomplete (HIGH)

### Problem
Autocomplete is unreliable - shows "garbage mixed in", doesn't scope properly when typing `module.`. This forces constant doc lookups.

### Root Causes Identified
1. **Config issue**: `chugget_code_definitions.lua` not in `workspace.library` path
2. **C++ bindings invisible**: Sol2-bound types have no Lua-side type info
3. **Module shape unknown**: `require()` returns aren't typed, so LSP can't infer

### Solutions

#### 1.1 Fix `.luarc.json` Configuration

**Important:** Don’t mix `Lua.*` keys (VSCode settings) with non-prefixed keys (LuaLS config file). Use **one** style consistently.

Use this in `.luarc.json` (repo root):
```json
{
  "workspace.library": [
    "assets/scripts/types",
    "assets/scripts"
  ],
  "workspace.ignoreDir": [
    ".worktrees",
    "build",
    "build-*"
  ],
  "runtime.version": "Lua 5.4",
  "runtime.path": [
    "assets/scripts/?.lua",
    "assets/scripts/?/init.lua"
  ]
}
```

If you instead configure via VSCode workspace settings (`.vscode/settings.json`), then the same keys must be prefixed:
- `Lua.workspace.library`
- `Lua.workspace.ignoreDir`
- `Lua.runtime.version`
- `Lua.runtime.path`

#### 1.2 Consolidate Type Definitions
Keep **generated** definitions (`chugget_code_definitions.lua`) as the source-of-truth for raw binding signatures, and keep **handwritten** definitions in `assets/scripts/types/` focused on:
- Better names, docs, and ergonomic aliases
- Module return types (`require()` typing)
- “Glue” globals that exist at runtime but are hard for LuaLS to infer

Split the handwritten stubs into focused files (so they’re maintainable):
- `assets/scripts/types/globals.lua` - C++ globals (`registry`, `command_buffer`, `layers`, `globals`, etc.)
- `assets/scripts/types/components.generated.lua` - generated component types (see 1.4)
- `assets/scripts/types/modules.lua` - Lua module return types (`core.timer`, `core.component_cache`, etc.)
- `assets/scripts/types/builders.lua` - builder APIs

Keep `assets/scripts/types/init.lua` as a tiny entrypoint that `require()`s the others (or simply exists as the “workspace.library anchor”).

#### 1.3 Add Missing Type Annotations
Priority files needing full annotation coverage:
- [ ] `core/Q.lua` - Already has types, verify completeness
- [ ] `core/timer.lua` - Expand options types
- [ ] `core/entity_builder.lua` - Full options typing
- [ ] `core/behaviors.lua` - Behavior definition types
- [ ] `ui/ui_syntax_sugar.lua` - UI DSL element types

#### 1.4 Generate Component Types from C++
Create a script to extract component definitions from `components.hpp` and generate:
```lua
---@class Transform
---@field x number
---@field y number
---@field scaleX number
---@field scaleY number
---@field rotation number
---@type Transform
Transform = {}
```

Implementation notes:
- Output to `assets/scripts/types/components.generated.lua` (checked in, deterministic output).
- Keep generation deterministic (stable ordering) to avoid noisy diffs.
- Prefer “data-only” fields; avoid trying to mirror methods/metamethods unless they’re stable.
- Treat this as **autocomplete + signatures**, not runtime behavior.

---

## Priority 2: Options-Table APIs

### Problem
Functions with 5+ positional parameters are impossible to remember:
```lua
-- What is position 3? position 7? Who knows!
makeDirectionalWipeWithTimer(entity, "left", 0.5, true, nil, "ease_out", 1.0, callback, "wipe_tag", layer, z)
```

### Solution: Prefer “Dual Signature” (Table OR Positional)

For usability, the lowest-friction pattern is: **the same function accepts either**:
1) the legacy positional signature, or
2) a single options table.

This avoids forcing callers to remember suffixes like `_opts` while remaining backwards compatible.

If you do introduce `_opts` variants, treat them as transitional wrappers (or as internal helpers), not the “main” UX.

```lua
-- OLD (keep for compat)
timer.after(0.5, callback, "my_tag")

-- NEW (preferred; dual signature)
timer.after {
    delay = 0.5,
    action = callback,
    tag = "my_tag"
}
```

Note: today, `timer.after_opts{...}` exists; making `timer.after{...}` work would be a small wrapper change (and should remain backwards compatible).

### Target Functions for `_opts` Variants

#### Core APIs
| Function | Params | New Signature |
|----------|--------|---------------|
| `timer.after` | 3+ | `timer.after { delay, action, tag?, group? }` (or `_opts`) |
| `timer.every` | 3+ | `timer.every { delay, action, tag?, times?, immediate?, after?, group? }` |
| `timer.cooldown` | 7+ | `timer.cooldown { delay, condition, action, times?, after?, tag?, group? }` |
| `timer.for_time` | 5 | `timer.for_time { duration, action, after?, tag?, group? }` |
| `timer.tween_fields` | 7 | `timer.tween_fields { delay, target, source, method?, after?, tag?, group? }` |

#### UI/Rendering
| Function | Params | New Signature |
|----------|--------|---------------|
| `draw.textPro` | 4+ | Already uses options table ✓ |
| `command_buffer.queueDraw*` | 3–5 | `command_buffer.queue { layer, fn, z?, space? }` (wrapper) |

#### Entity/Physics
| Function | Params | New Signature |
|----------|--------|---------------|
| `EntityBuilder.create` | varies | Already uses options table ✓ |
| `physics.create_physics_for_transform` | 5+ | `PhysicsBuilder` handles this ✓ |

#### High-Param Functions to Audit
Create a tiny audit script (don’t rely on brittle regexes) to list Lua functions with “too many” parameters. Then prioritize by call-sites (what’s actually used).

If you do a quick-and-dirty grep, prefer ripgrep and a conservative heuristic:
```bash
rg -n "function\\s+\\w+\\([^\\)]*,[^\\)]*,[^\\)]*,[^\\)]*,[^\\)]*," assets/scripts --glob="*.lua"
```

### Type Annotations for Options
```lua
---@class TimerAfterOpts
---@field delay number Delay in seconds
---@field action fun() Callback function
---@field tag? string Optional cancellation tag

---@param opts TimerAfterOpts
function timer.after_opts(opts) end
```

---

## Priority 3: GOAP In-Game Debugger

### Problem
Full GOAP planner is opaque. Can't see:
- What **goal** the AI is pursuing
- Why specific **action** was chosen over alternatives
- Where in the **plan sequence** execution is
- The **world state** driving decisions

Multi-behavior interactions (steering behaviors that blend) are also hard to trace.

### Solution: In-Game Debug Overlay

#### 3.1 GOAP State Display (Per-Entity)
When debug mode is active and entity is selected, show overlay:

```
┌─────────────────────────────────────┐
│ 🎯 GOAL: KillPlayer (priority: 0.9) │
├─────────────────────────────────────┤
│ 📋 PLAN:                            │
│   1. ✓ FindWeapon                   │
│   2. ✓ ApproachTarget               │
│   3. → AttackMelee  ← CURRENT       │
│   4. ○ Retreat                      │
├─────────────────────────────────────┤
│ 🌍 WORLD STATE:                     │
│   has_weapon: true                  │
│   target_in_range: true             │
│   health: 45/100                    │
│   ammo: 0                           │
├─────────────────────────────────────┤
│ ❌ REJECTED ACTIONS:                │
│   RangedAttack: ammo = 0 (need > 0) │
│   Flee: health > 30                 │
└─────────────────────────────────────┘
```

#### 3.2 Action Selection Breakdown
Show WHY current action was chosen:
- Preconditions met (✓/✗ for each)
- Cost calculation
- Competing actions and why they lost

#### 3.3 Steering Behavior Blend Visualization
For blended steering (flee + attack), show force vectors:
- Arrow for each active behavior's contribution
- Final blended vector
- Weights/priorities

#### 3.4 Implementation Approach
- Use existing ImGui integration (if available) or custom draw commands
- Toggle with debug key (e.g., F3)
- Click entity to select for detailed view
- Minimal overhead when disabled

### API for GOAP Debug Integration
```lua
-- In GOAP system, emit debug info
goap_debug.set_current_goal(entity, goal_name, priority)
goap_debug.set_plan(entity, { "FindWeapon", "ApproachTarget", "AttackMelee" })
goap_debug.set_plan_index(entity, 3)  -- Currently on step 3
goap_debug.set_world_state(entity, { has_weapon = true, ... })
goap_debug.add_rejected_action(entity, "RangedAttack", "ammo = 0 (need > 0)")
```

Implementation notes:
- Provide `goap_debug` as a module/global that is **a no-op in release** (and allocates nothing when disabled).
- Prefer storing strings and small tables per entity only while the overlay is active.
- Make “rejected actions” bounded (ring buffer) to prevent unbounded growth.

---

## Priority 4: Procedural Generation DSL

### Problem
No declarative way to define procedural content. Currently requires imperative Lua code for:
- Enemy wave compositions
- Loot/reward tables
- Level layouts
- Stat scaling

### Solution: Declarative Procgen DSL

#### 4.1 Enemy Waves DSL
```lua
local waves = procgen.waves {
    -- Wave 1: Tutorial
    {
        enemies = { "slime", "slime" },
        spawn_delay = 1.0,
        spawn_pattern = "sequential"  -- or "simultaneous", "random_interval"
    },

    -- Wave 2: Introduces ranged
    {
        enemies = { "slime", "archer", "slime" },
        spawn_delay = 0.8,
        spawn_pattern = "random_interval",
        min_interval = 0.5,
        max_interval = 1.5
    },

    -- Dynamic wave based on difficulty
    {
        enemies = procgen.scaled {
            base = { "slime", "archer" },
            per_difficulty = { "knight" },  -- Add 1 knight per difficulty level
            max_enemies = 8
        },
        spawn_delay = procgen.curve("difficulty", 1.0, 0.3)  -- 1.0s at diff 1, 0.3s at diff 10
    }
}
```

#### 4.2 Loot Tables DSL
```lua
local chest_loot = procgen.loot {
    -- Weighted random selection
    { item = "gold", weight = 50, amount = procgen.range(10, 50) },
    { item = "health_potion", weight = 30 },
    -- Avoid string-eval conditions; use a predicate for safety + tooling.
    { item = "rare_sword", weight = 5, condition = function(ctx) return ctx.player.level >= 5 end },

    -- Guaranteed drops
    guaranteed = {
        { item = "key", condition = function(ctx) return not ctx.player.has_key end }
    },

    -- Drop count
    picks = procgen.range(1, 3)  -- 1-3 items from the table
}

-- Usage
local items = chest_loot:roll({ player = player, rng = rng })
```

#### 4.3 Level Layout DSL
```lua
local dungeon = procgen.layout {
    type = "rooms_and_corridors",

    rooms = {
        count = procgen.range(5, 10),
        size = { min = {4, 4}, max = {8, 8} },
        types = {
            { type = "combat", weight = 50 },
            { type = "treasure", weight = 20 },
            { type = "boss", weight = 5, max = 1 }
        }
    },

    corridors = {
        width = 2,
        style = "straight"  -- or "winding", "organic"
    },

    constraints = {
        "boss room must be furthest from start",
        "treasure rooms need adjacent combat rooms"
    }
}
```

#### 4.4 Stat Scaling DSL
```lua
local enemy_stats = procgen.stats {
    base = {
        health = 100,
        damage = 10,
        speed = 50
    },

    scaling = {
        -- Per difficulty level
        -- Prefer functions (or a safe, precompiled expression format) over string formulas.
        health = function(ctx) return ctx.base * (1 + ctx.difficulty * 0.2) end,
        damage = function(ctx) return ctx.base * (1 + ctx.difficulty * 0.1) end,
        speed = procgen.constant()  -- Doesn't scale
    },

    -- Per enemy type multipliers
    variants = {
        elite = { health = 2.0, damage = 1.5 },
        boss = { health = 5.0, damage = 2.0, speed = 0.8 }
    }
}

-- Usage
local stats = enemy_stats:generate({ variant = "elite", difficulty = difficulty_level, rng = rng })
```

### Implementation Notes
- DSL returns plain Lua tables for inspection/modification
- `procgen.roll()` / `procgen.generate()` for execution
- Seed support for deterministic generation
- Debug mode shows roll probabilities

---

## Additional Improvements

### 5. Constants System Adoption
Replace magic numbers with centralized constants:
```lua
-- BAD
timer.after(0.5, ...)
entity.health = 100

-- GOOD
local C = require("core.constants")
timer.after(C.Timing.ATTACK_COOLDOWN, ...)
entity.health = C.Stats.BASE_HEALTH
```

`core/constants.lua` already exists. Extend it with categories that reduce “magic numbers”:
- `Constants.Timing` - Delays, cooldowns, durations
- `Constants.Stats` - Health, damage, speed base values
- `Constants.UI` - Sizes, margins, z-orders
- `Constants.Colors` - Named color palette

Goal: the most-common “numbers you always type” should have a home.

### 6. Safe Component Accessors (Debug-Only)
```lua
-- Prefer improving component_cache.safe_get (already exists) with better context.
local transform, ok = component_cache.safe_get(entity, Transform)
-- If not ok: "Transform component not found on entity 42 (alias: 'boss')"

-- In tight loops, still use component_cache.get directly once you’re sure.
```

Implementation notes:
- Prefer returning `(value, ok)` for non-fatal flows; reserve `error()` for truly exceptional cases.
- When producing errors, don’t rely on `tostring(component_type)` (it often becomes `table: 0x...`). Prefer a stable name (e.g., `component_type.__name` in stubs, or an engine-provided lookup).

### 7. API Naming Consistency
Establish and document conventions:
- **Functions**: `snake_case` (e.g., `create_entity`, `get_component`)
- **Classes/Types**: `PascalCase` (e.g., `EntityBuilder`, `Transform`)
- **Constants**: `SCREAMING_SNAKE` (e.g., `TIMING.ATTACK_DELAY`)
- **Entity parameters**: Always `entity` not `e`, `eid`, `id`
- **Callback parameters**: `fn`, `callback`, or `action` (pick one, be consistent)

---

## Constraints & Compatibility

| Constraint | Impact |
|------------|--------|
| **LuaJIT compatibility** | Max 200 locals per scope, use `bit.*` for bitwise |
| **Web build support** | No LuaJIT on Emscripten, test both backends |
| **Hot reload** | New APIs must not break reload system |
| **Backwards compat** | Don’t remove existing positional signatures; add table/`_opts` variants alongside |

---

## Implementation Phases

### Phase 1: Foundation (Immediate Impact)
- [ ] Fix `.luarc.json` configuration
- [ ] Consolidate type definitions in `types/`
- [ ] Add “dual signature” (table OR positional) to top 5 most-used multi-param functions
- [ ] Document naming conventions

### Phase 2: Developer Experience
- [ ] Generate component types from C++
- [ ] Add safe component accessors (debug-only)
- [ ] Create constants system and migrate magic numbers
- [ ] Full type annotation coverage for core modules

### Phase 3: New Capabilities
- [ ] GOAP debug overlay - basic goal/plan display
- [ ] GOAP debug overlay - action selection breakdown
- [ ] Procedural generation DSL - waves
- [ ] Procedural generation DSL - loot tables

### Phase 4: Polish
- [ ] Procgen DSL - layouts and stats
- [ ] Steering behavior visualization
- [ ] Interactive API explorer (in-game?)
- [ ] Migration guide for legacy code

---

## Implementation Checklist (Concrete, PR-Sized)

### LSP / LuaLS
- [ ] Update `.luarc.json` to use a single key style (either all `workspace.*` or all `Lua.workspace.*`; don’t mix).
- [ ] Ensure `workspace.library` includes both `assets/scripts/types` and `assets/scripts` (so generated `chugget_code_definitions.lua` is indexed).
- [ ] Expand `diagnostics.globals` to include the common engine globals you actually use (`command_buffer`, `layers`, `globals`, etc.) so LuaLS stops flagging them.
- [ ] Acceptance: typing `registry:` / `timer.` / `component_cache.` and `require("core.timer")` shows correct completion, no “garbage mixed in”.

### Type Stubs Organization
- [ ] Split `assets/scripts/types/init.lua` into `globals.lua`, `modules.lua`, `builders.lua` (keep `init.lua` as a minimal entrypoint).
- [ ] Add `assets/scripts/types/components.generated.lua` and make it obvious it’s generated.
- [ ] Acceptance: component instances show field completions (e.g., `transform.x`, `sprite.visible`).

### Component Type Generation
- [ ] Add a generator script (e.g., `tools/generate_component_types.py`) that parses `src/components/components.hpp` and writes `assets/scripts/types/components.generated.lua`.
- [ ] Make output deterministic (stable ordering; stable formatting).
- [ ] Acceptance: re-running the generator with no source changes produces a clean diff.

### Options-Table / Dual Signature APIs
- [ ] For the most-called “too many params” APIs, accept `{ ... }` as the first argument and map it to the legacy signature internally.
- [ ] Keep existing positional calls working 1:1.
- [ ] Acceptance: old call sites run unchanged; new call sites are readable without docs.

### GOAP Debug Overlay (Minimal First Slice)
- [ ] Implement `goap_debug` as no-op when disabled/release.
- [ ] Plumb only: current goal name + plan list + plan index + a bounded rejected-actions list.
- [ ] Render via ImGui (preferred) or draw commands; gate by debug flag.
- [ ] Acceptance: selecting an entity shows its goal/plan live; no measurable perf cost when off.

### Procgen DSL (Minimal First Slice)
- [ ] Implement `procgen.range`, `procgen.loot`, and `:roll(ctx)` with deterministic RNG injection.
- [ ] Avoid string-eval formulas/conditions; use Lua predicates/functions (or a safe precompiled expression format).
- [ ] Acceptance: seed produces repeatable results; debug output can explain the roll.

## Anti-Patterns to Actively Avoid

| Anti-Pattern | Why It's Bad | Do This Instead |
|--------------|--------------|-----------------|
| Magic strings | No validation, no autocomplete | Enums, constants, typed tables |
| Verbose boilerplate | Slows down prototyping | One-liner defaults, builder patterns |
| Callback hell | Hard to follow flow | `timer.sequence()`, promises, or coroutines |
| Implicit registration | Spooky action at distance | Explicit `register()`, `attach()` calls |
| Global mutation | State confusion | Localized state, explicit getters/setters |

---

## Success Criteria

The improvements succeed when:

1. **Primary**: Can write correct API calls without checking documentation
2. **Secondary**: Time from idea to working prototype is shorter
3. **Tertiary**: Fewer nil-access bugs in debug builds

---

## Notes from Interview

### What's NOT a Priority
- **Splitting god objects** (gameplay.lua, combat_system.lua) - These are "actually manageable" since you know them well. Don't invest effort here.
- **Complex safety middleware** - Stack traces work fine for debugging; focus on preventing issues upstream instead.

### Key Insights
- The REAL blocker is **calling APIs exactly right** - autocomplete doesn't help, so you look things up
- **GOAP debugging** is about seeing decisions in real-time, not content authoring
- Current builder escape hatches are **fine** - don't over-engineer them
- You prefer **Love2D simplicity** - minimal boilerplate, straightforward

---

*Generated from interview session - captures vision and priorities for Lua API improvements.*
*Updated: 2026-01-22*
