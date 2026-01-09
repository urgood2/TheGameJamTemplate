# Lua Codebase Analysis Report
> TheGameJamTemplate • Generated Jan 9, 2026 • 8 agents deployed

## Executive Summary

| Category | Key Metric | Severity |
|----------|------------|----------|
| God Objects | gameplay.lua: 11,359 lines | 🔴 CRITICAL |
| Magic Numbers | 2,702 hardcoded values | 🔴 HIGH |
| Unsafe Access | 527 unguarded component gets | 🟠 HIGH |
| Code Duplication | 68 distance calcs, 377 component guards | 🟠 HIGH |
| Hot-Path Allocations | 3-50 tables/frame in card batching | 🔴 CRITICAL |
| Dead Code | ~4,500 lines removable | 🟡 MEDIUM |

---

## P0 – Critical (Do This Week)

### 1. Unify Movement AI Functions
**File:** `combat/wave_helpers.lua:194-272`
**Effort:** 1-4 hours | **Impact:** Maintainability + bug fixes

4 nearly-identical functions with only direction logic differing:
- `move_toward_player` (lines 194-209)
- `flee_from_player` (lines 211-226)
- `kite_from_player` (lines 228-252)
- `wander` (lines 257-272)

**Fix:** Extract to `_apply_movement(entity, dx, dy, speed)` helper or refactor to behavior composition pattern (core/behaviors.lua).

---

### 2. Eliminate Hot-Path Allocations
**Effort:** 2-4 hours | **Impact:** 15-25% GC reduction

| Location | Issue | Allocs/Frame |
|----------|-------|--------------|
| `gameplay.lua:2139` | Card batching tables | 3-50 tables |
| `lighting.lua:886` | Visible lights array | 1 + 32 inserts |
| `lighting.lua:916` | Uniform name strings | 256 strings |
| `command_buffer_text.lua:533` | ipairs closure | 1000 closures |

**Fix:** Pre-allocate module-level tables and clear them each frame instead of recreating:
```lua
local _buckets = {}
local _cache = {}

function draw()
    for k in pairs(_buckets) do _buckets[k] = nil end
    -- reuse _buckets
end
```

---

### 3. Split God Objects
**Effort:** 1-2 days | **Impact:** Unlocks all future refactors

| File | Lines | Issue |
|------|-------|-------|
| `gameplay.lua` | 11,359 | Handles UI, combat, cards, tooltips, state, rendering |
| `combat_system.lua` | 6,210 | Monolithic combat logic mixing multiple concerns |
| `util.lua` | 4,114 | Classic utility dumping ground |

**Proposed split for gameplay.lua:**
- `game_loop.lua` (init, update, draw)
- `player_controller.lua` (input, movement)
- `ui_orchestration.lua` (UI lifecycle)
- `event_handlers.lua` (signal registrations)

---

### 4. Replace Unsafe Component Access
**Effort:** 1 day | **Impact:** Prevents nil crashes

527 instances of `component_cache.get()` without nil checks. 1,288 direct `.actualX/.actualY` mutations.

**Current (unsafe):**
```lua
local transform = component_cache.get(entity, Transform)
transform.actualX = x  -- CRASH if nil!
```

**Safe pattern:**
```lua
local transform = component_cache.get(entity, Transform)
if not transform then return end
transform.actualX = x
```

**Better:** Use Q helpers: `Q.move(entity, x, y)`

---

### 5. Migrate Timer Chains to timer.sequence()
**Effort:** 4-6 hours | **Impact:** Prevents memory leaks

196 timer.after/every calls create orphan timers.

**Current (callback hell):**
```lua
timer.after(0.2, function()
    timer.after(0.5, function()
        timer.after(0.3, function()
            -- nested
        end)
    end)
end)
```

**Better:**
```lua
timer.sequence("anim")
    :wait(0.2)
    :do_now(fn1)
    :wait(0.5)
    :do_now(fn2)
    :start()
```

---

## P1 – High (This Month)

### Split util.lua (4,114 lines)
Split into: `math_helpers.lua`, `entity_utils.lua`, `ui_helpers.lua`, `fx_utils.lua`

### Consolidate Global State
84 assignments to `globals.*` scattered across 9 files:
- globals.currency modified in 6 files
- globals.shopState mutated in 4 files
- globals.isShopOpen toggled in 3 files

**Fix:** Centralize with explicit setters via state manager.

### Codemod for Q.distance() Adoption
Replace 68 `math.sqrt(dx*dx + dy*dy)` instances with `Q.distance()`

### Refactor Parameter Explosion
Top offenders:
- `makeDirectionalWipeWithTimer` — 11 params
- `spawnCircularBurstParticles` — 8 params
- `makeSwirlEmitter` — 6 params

**Fix:** Convert to table-based options.

---

## P2 – Medium (This Quarter)

| Task | Details |
|------|---------|
| Magic Numbers → Constants | 2,702 hardcoded numbers → create constants module |
| Naming Consistency | Mixed camelCase/snake_case → draft naming guide |
| Object Pooling Adoption | Extend pool.lua to card batching, lighting, FX |
| CI Metrics Tooling | Script to flag raw component_cache usage |

---

## P3 – Low (Backlog)

- Localize frequently-used functions per module
- table.concat adoption in string-heavy systems
- signal_group adoption to prevent event handler leaks
- Document Node.quick() vs manual attach patterns

---

## Code Duplication Details

### Distance Calculation (68 instances)
Pattern: `math.sqrt(dx * dx + dy * dy)` across 22 files
- `combat/wave_helpers.lua` (9 instances)
- `combat/projectile_system.lua` (16 instances)
- `core/gameplay.lua` (8 instances)

**Use instead:** `Q.distance(e1, e2)`

### Component Access Guards (377 instances)
Pattern: `component_cache.get(entity, Transform)` with repeated validation

**Use instead:** `Q.withTransform(entity, fn)` or `Q.move(entity, x, y)`

### Timer Chains (196 instances)
Sequential `timer.after()` calls in:
- `core/gameplay.lua` (80+ calls)
- `core/entity_factory.lua` (30+ calls)
- `combat/wave_director.lua` (15+ calls)

**Use instead:** `timer.sequence()`

---

## Module Organization Issues

### Circular Dependencies
```
core/gameplay.lua → wand/* → combat/projectile_system.lua
                  ↑_______________________________↓
```
Cannot use core without wand, cannot test wand in isolation.

### Hierarchy Violations
- `core/main.lua` requires gameplay.lua directly
- `data/cards.lua` requires core modules (data should be pure config)
- `combat/projectile_system.lua` requires util.util

### Orphaned Files (move to proper locations)
- `test_draw_batching.lua` → `tests/`
- `test_projectiles.lua` → `tests/`
- `AI_TABLE_CONTENT_EXAMPLE.lua` → `examples/`
- `chugget_code_definitions.lua` — unclear purpose (12,776 lines)

---

## Dead Code (~4,500 lines removable)

### High Confidence Deletions
| File | Lines | Description |
|------|-------|-------------|
| `util/util.lua:2143-2224` | ~80 | Particle test functions never called |
| `util/util.lua:2341-3922` | ~1580 | Old game jam shop/building system |
| `core/shader_uniforms.lua` | 1558 | Module never wired into main.lua |
| `core/entity_factory.lua` | ~200 | Old spawn functions (spawnNewKrill, etc.) |

### TODO/FIXME Comments (30 instances)
- `combat/combat_system.lua:3911` — TODO for respec (never implemented)
- `core/gameplay.lua:3244` — TODO for cooldown handling
- `data/shader_presets.lua:99` — Disabled presets (shader compile failure)

---

## Performance Optimization Priority

| Issue | Location | Impact | Priority |
|-------|----------|--------|----------|
| Card batching tables | `gameplay.lua:2139` | CRITICAL | P0 |
| Lighting visible list | `lighting.lua:886` | HIGH | P0 |
| Uniform name strings | `lighting.lua:916` | HIGH | P1 |
| Text character iteration | `command_buffer_text.lua:533` | MEDIUM | P1 |
| Projectile removal list | `projectile_system.lua:1054` | MEDIUM | P2 |
| Wand table copying | `wand_executor.lua:96` | MEDIUM | P2 |

**Expected gains after Phase 1:** 15-25% GC reduction, 5-10% FPS improvement

---

## ⚠️ Refactors to AVOID

1. **Full rewrite of gameplay.lua** without phased extraction — destabilizes core gameplay
2. **Replacing globals.* infrastructure** before P1 cleanup — too risky without owning modules clarified
3. **Automatic renaming of versioned files** (tooltip_v2) without fallback aliases — breaks Lua requires

---

## Naming Conventions (Recommended)

| Element | Convention | Example |
|---------|------------|---------|
| Module files | `snake_case.lua` | `entity_builder.lua` |
| Module tables | `PascalCase` | `EntityBuilder` |
| Public functions | `camelCase` | `EntityBuilder.create()` |
| Private functions | `snake_case` | `local function setup_tooltip()` |
| Constants | `SCREAMING_SNAKE` | `PLANNING_STATE` |
| Callbacks | `on_*` prefix | `on_spawn`, `on_death` |

### Issues Found
- timer.lua has inconsistent `_opts` suffix pattern
- Version suffix inconsistency (tooltip_v2.lua) with no deprecation strategy
- Ambiguous parameter names (`e` should be `entity`)
