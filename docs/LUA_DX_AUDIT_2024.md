# Lua Developer Experience Audit

**Date:** December 2024
**Status:** In Progress

## Executive Summary

Comprehensive analysis of Lua codebase for usability, intuitiveness, and developer friction. Preference is for simplicity over verbose structure.

| Category | Files Analyzed | Major Issues Found | Quick Wins |
|----------|----------------|-------------------|------------|
| Core APIs | 6 files | 8 issues | 5 |
| Combat/Gameplay | 12+ files | 11 issues | 4 |
| AI/Behavior | 15+ files | 6 issues | 3 |
| Data Definitions | 8 files | 6 issues | 3 |
| Global Helpers | 5 files | 10 missing patterns | 6 |

---

## CRITICAL Issues (Fix First)

### 1. Q.lua is Dangerously Minimal (192+ occurrences of workaround)

**Current:** Only 3 methods (`move`, `center`, `offset`)

**The Problem:** Developers constantly write this:
```lua
-- EVERYWHERE in the codebase (192 times!)
local transform = component_cache.get(entity, Transform)
local x = transform.visualX + transform.visualW / 2
local y = transform.visualY + transform.visualH / 2
```

**Status:** ✅ FIXED - Extended Q.lua with:
- `Q.visualCenter(entity)` - Returns cx, cy from visual position
- `Q.size(entity)` - Returns width, height
- `Q.bounds(entity)` / `Q.visualBounds(entity)` - Get bounding box
- `Q.rotation(entity)` / `Q.setRotation(entity, rad)` / `Q.rotate(entity, delta)`
- `Q.isValid(entity)` / `Q.ensure(entity, context)` - Entity validation
- `Q.distance(e1, e2)` / `Q.distanceToPoint(entity, x, y)` - Spatial queries
- `Q.direction(e1, e2)` - Normalized direction vector
- `Q.isInRange(e1, e2, range)` - Range checking
- `Q.getTransform(entity)` / `Q.withTransform(entity, fn)` - Component access

---

### 2. Node Script Creation Boilerplate (39+ occurrences)

**Current Pattern (6-10 lines every time):**
```lua
local MyType = Node:extend()
local script = MyType {}
script.health = 100
script.damage = 10
script:attach_ecs { create_new = false, existing_entity = entity }
```

**The Footgun:** Data assigned AFTER `attach_ecs` is silently lost!

**Proposed Fix:**
```lua
-- One-liner for simple cases
local script = Node.quick(entity, { health = 100, damage = 10 })
```

**Status:** ✅ FIXED - Added Node.quick() and Node.create()

---

### 3. Timer API Has Split Personality (300+ timer usages)

**Current Problem - Two competing APIs:**
```lua
-- Positional API (hard to remember parameter order):
timer.every(delay, action, times, immediate, after, tag, group)  -- 7 params!

-- Options API (verbose but clear):
timer.every_opts({ delay = 0.5, action = fn, times = 10, tag = "update" })
```

**Proposed Fix:**
1. Deprecate positional variants
2. Promote `timer.sequence()` as THE primary API
3. Document clearly: "Use opts variant or sequences only"

**Status:** ✅ FIXED - Documented in CLAUDE.md with examples

---

### 4. Card Definitions Repeat Zero Values (80+ cards, 40% wasted lines)

**Current Pattern:**
```lua
Cards.FIREBALL = {
    id = "FIREBALL",
    spread_modifier = 0,              -- ALWAYS 0
    speed_modifier = 0,               -- ALWAYS 0
    lifetime_modifier = 0,            -- ALWAYS 0
    critical_hit_chance_modifier = 0, -- ALWAYS 0
    -- ...
}
```

**Proposed Fix:** Make defaults truly optional in content_defaults.lua

**Status:** ✅ FIXED - Removed 136 lines of redundant zeros from cards.lua

---

## High Priority Issues

### 5. Nested timer.after() Callback Hell

**Found in:** `gameplay.lua:1331-1527` (gold transition effect)

**Fix:** Use `timer.sequence()` which already exists

**Status:** 🔲 TODO

---

### 6. Dual Event Systems Cause Confusion

| System | Usage |
|--------|-------|
| `signal.emit()` | Gameplay events |
| `ctx.bus:emit()` | Combat internals |

**Proposed Fix:** Add scoped registration:
```lua
local signal_group = require("core.signal_group")
local handlers = signal_group.new("combat_ui")
handlers:on("enemy_killed", function(e) ... end)
handlers:cleanup()  -- Unregisters all at once
```

**Status:** ✅ FIXED - Created `core/signal_group.lua`

---

### 7. State Tag Management is Verbose (50+ occurrences)

**Current:**
```lua
clear_state_tags(entity)
add_state_tag(entity, PLANNING_STATE)
```

**Proposed:**
```lua
script:setState(PLANNING_STATE)  -- Auto-clears and sets
```

**Status:** ✅ FIXED - Added script:setState() and script:clearStateTags()

---

### 8. PhysicsBuilder tag/collideWith Semantics Unclear

**Proposed Fix:** Better naming:
```lua
:as("projectile")              -- "I am a projectile"
:collidesWith({ "enemy" })     -- "I collide with enemies"
```

**Status:** 🔲 TODO (may require backward compat aliases)

---

## Medium Priority Issues

### 9. Missing Popup Helpers (35+ occurrences)

**Proposed:**
```lua
popup.heal(entity, healAmount)
popup.damage(entity, damageAmount)
popup.above(entity, text, opts)
```

**Status:** ✅ FIXED - Created `core/popup.lua`

---

### 10. Enemy Behaviors are Code-Heavy

**Proposed - Declarative Composition:**
```lua
enemies.goblin = {
    behaviors = { "chase_player", { "dash_periodically", cooldown = 3.0 } }
}
```

**Status:** 🔲 TODO (larger refactor)

---

### 11. Joker calculate() Pattern is Deeply Nested

**Proposed:**
```lua
if self:matches(context, "on_spell_cast", { tags = {"Fire"} }) then
    return { damage_mod = 10 }
end
```

**Status:** 🔲 TODO

---

## Quick Wins Checklist

| # | Fix | Impact | Status |
|---|-----|--------|--------|
| 1 | Extend Q.lua | 192+ occurrences | ✅ DONE |
| 2 | Add popup helpers | 35+ occurrences | ✅ DONE |
| 3 | Fix duplicate playerX/Y (gameplay.lua:2543) | Bug fix | ✅ DONE |
| 4 | Rename `test_label` → `display_name` | Clarity | 🔲 TODO |
| 5 | Rename `weight` → `spawn_weight` | Clarity | 🔲 TODO |
| 6 | Document `timer.sequence()` | Discovery | ✅ DONE |
| 7 | Add `script:setState(state)` | 50+ occurrences | ✅ DONE |
| 8 | Make card modifiers optional | 40% smaller cards | ✅ DONE |
| 9 | Add signal_group for cleanup | Memory leak prevention | ✅ DONE |

---

## Implementation Progress

### Completed
- [x] Extended Q.lua with 15+ new helper methods
- [x] Created popup helpers module (`core/popup.lua`)
- [x] Added Node.quick() factory to prevent data-loss bugs
- [x] Added Node.create() shorthand
- [x] Added script:setState() convenience method
- [x] Added script:clearStateTags() convenience method
- [x] Made card modifier fields optional (removed 136 lines)
- [x] Fixed duplicate playerX/Y bug in gameplay.lua
- [x] Documented timer.sequence() in CLAUDE.md (with examples)
- [x] Created signal_group.lua for scoped handler cleanup
- [x] Updated CLAUDE.md with all new APIs

### Pending
- [ ] Rename `test_label` → `display_name` in cards
- [ ] Rename `weight` → `spawn_weight` in cards
- [ ] Extract declarative enemy behavior library
- [ ] Add joker event matching helper

---

## Files Modified

1. `assets/scripts/core/Q.lua` - Extended with 15+ new helpers:
   - `visualCenter()`, `size()`, `bounds()`, `visualBounds()`
   - `rotation()`, `setRotation()`, `rotate()`
   - `isValid()`, `ensure()`
   - `distance()`, `direction()`, `distanceToPoint()`, `isInRange()`
   - `getTransform()`, `withTransform()`

2. `assets/scripts/monobehavior/behavior_script_v2.lua` - Added:
   - `Node.quick(entity, data)` - Safe factory preventing data-loss bug
   - `Node.create(data)` - Shorthand for new entity creation
   - `script:setState(state)` - Clear+add state in one call
   - `script:clearStateTags()` - Clear all state tags

## Files Created

1. `assets/scripts/core/popup.lua` - Popup convenience helpers:
   - `popup.at(x, y, text, opts)` - Show at position
   - `popup.above(entity, text, opts)` - Show above entity
   - `popup.below(entity, text, opts)` - Show below entity
   - `popup.heal(entity, amount)` - Healing feedback
   - `popup.damage(entity, amount)` - Damage feedback
   - `popup.critical(entity, amount)` - Critical hit
   - `popup.mana()`, `popup.gold()`, `popup.xp()` - Resource changes
   - `popup.status()`, `popup.miss()`, `popup.blocked()` - Status feedback

2. `assets/scripts/core/signal_group.lua` - Scoped signal registration:
   - `signal_group.new(name)` - Create a new group
   - `handlers:on(event, fn)` - Register handler (tracked)
   - `handlers:off(event, fn)` - Remove specific handler
   - `handlers:cleanup()` - Remove ALL handlers in group
   - `handlers:count()` - Get handler count (debugging)

## Files Still To Modify

1. `assets/scripts/data/cards.lua` - Rename `test_label` → `display_name`
2. `assets/scripts/data/cards.lua` - Rename `weight` → `spawn_weight`
