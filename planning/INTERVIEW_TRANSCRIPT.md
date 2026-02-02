# Interview Transcript — Demo Content Specification v3

**Date:** 2026-02-02
**Interviewer:** Claude (Opus 4.5)
**Subject:** Demo Implementation Decisions
**Source Spec:** Demo Content Specification v3

---

## Context

Interview conducted to clarify implementation decisions for the Demo Content Specification v3, which defines:

| System | Count | Notes |
|--------|-------|-------|
| **Gods** | 4 | Pyr (Fire), Glah (Ice), Vix (Lightning), Nil (Void) |
| **Classes** | 2 | Channeler (melee), Seer (ranged) |
| **Skills** | 32 | 8 per element × 4 elements |
| **Wands** | 8 | 2 starter + 6 findable |
| **Cards** | ~40 | Modifiers + Actions (NOT trigger cards) |
| **Artifacts** | 15 | 5 common, 5 uncommon, 5 rare |
| **Equipment** | 12 | 4 per slot × 3 slots |

---

## Round 1: Core Implementation Priorities

### Q1: System Priority

**Question:** The spec has 10+ systems (Gods, Classes, Skills, Wands, Cards, Artifacts, Equipment, Status Effects, Economy, Triggers). Which 3 systems are most critical to have working first for a playable demo loop?

**Answer:** All things in the spec must be complete.

**Implication:** No scope cuts. Full implementation of all systems required for demo release.

---

### Q2: Melee Arc Implementation

**Question:** For melee combat (Channeler's Void Edge + Melee Swing), the spec suggests 3 implementation options. Which approach do you prefer?

**Options:**
1. Line Sweep queries (Recommended) — 8-step arc sweep with physics.segment_query
2. Chipmunk polygon sector — Native collision shape
3. Animated hitbox sprite — Sprite-based collision

**Answer:** Line Sweep queries (Recommended)

**Implementation:**
```lua
function createMeleeArc(origin, facing, arcAngle, range, duration)
    local steps = 8
    local stepAngle = arcAngle / steps
    local startAngle = facing - arcAngle / 2

    for i = 0, steps do
        local angle = startAngle + stepAngle * i
        local endX = origin.x + math.cos(angle) * range
        local endY = origin.y + math.sin(angle) * range
        physics.segment_query(world, origin, {x=endX, y=endY}, function(shape, point)
            local entity = physics.entity_from_ptr(shape)
            if isEnemy(entity) then
                dealDamage(entity, damage)
            end
        end)
    end
end
```

---

### Q3: Stack Decay Location

**Question:** The spec introduces stack decay for Scorch/Freeze/Doom. Should decay happen server-side (in combat_system) or client-side (in status_effects)?

**Options:**
1. StatusEngine (combat_system) — Centralized with other status logic
2. Dedicated status_decay.lua — Separate module
3. Per-entity timers — Decentralized

**Answer:** StatusEngine (combat_system)

**Implementation:** Add decay logic to `StatusEngine.update_entity()` in `assets/scripts/combat/combat_system.lua`:

```lua
local STATUS_DECAY_RATES = {
    scorch = { interval = 2.0, amount = 1 },
    freeze = { interval = 3.0, amount = 1 },
    doom   = { interval = 4.0, amount = 1 },
    charge = { interval = 2.0, amount = 1 },
    inflame = { interval = 3.0, amount = 1 },
}
```

---

### Q4: Starter Gear Flow

**Question:** God starter gear (Equipment + Artifact) needs to be given at run start. How should this work with the existing character creation flow?

**Options:**
1. Auto-equip on god select — Silent equip
2. Show gear preview in select — Display before confirming
3. Grant after first wave — Tutorial-style reveal

**Answer:** Show gear preview in select

**Implementation:** God selection UI must display:
- God name, blessing description, passive
- Starter equipment piece with stats preview
- Starter artifact with effect preview
- Visual preview of all items before confirming choice

---

## Round 2: Technical Details & Edge Cases

### Q5: Element Lock Timing

**Question:** The spec mentions Element Lock (players pick 3 of 4 elements). When exactly should this lock trigger?

**Options:**
1. Lock on 3rd skill point spent — First 3 elements become permanent
2. Lock after first shop — Exploration time before committing
3. Soft lock with respec cost — Can change but costs resources
4. No lock for demo — Defer complexity

**Answer:** Lock on 3rd skill point spent

**Implementation:**
```lua
-- Track invested elements on player state
player.elements_invested = {}  -- Set of element names

function onSkillLearned(player, skill)
    local element = skill.element
    if not player.elements_invested[element] then
        player.elements_invested[element] = true
        local count = table_size(player.elements_invested)
        if count >= 3 then
            -- Lock 4th element
            player.element_locked = true
            -- Find which element is NOT in the set
            for _, e in ipairs({"fire", "ice", "lightning", "void"}) do
                if not player.elements_invested[e] then
                    player.locked_element = e
                    break
                end
            end
        end
    end
end
```

UI: Show lock icon on 4th element in skills panel with tooltip.

---

### Q6: Multi-Trigger Skill Behavior

**Question:** Multi-trigger skills (e.g., Roil: on_hit + on_fire_damage) — should both triggers need to fire in the same frame, or either trigger independently?

**Options:**
1. ANY trigger fires skill — More forgiving
2. ALL triggers required — Both must fire together
3. Per-skill configuration — Most flexible

**Answer:** ALL triggers required

**Implementation:**
```lua
-- Multi-trigger: ALL must fire in same frame
function checkMultiTriggerSkill(skill, events_this_frame)
    for _, required_trigger in ipairs(skill.triggers) do
        local found = false
        for _, event in ipairs(events_this_frame) do
            if event.type == required_trigger then
                found = true
                break
            end
        end
        if not found then
            return false  -- Missing a required trigger
        end
    end
    return true  -- All triggers present
end
```

This means Roil only fires when both `on_hit` AND `on_fire_damage` occur in the same action.

---

### Q7: Transformation Form Duration

**Question:** Transformation buffs (Fireform, Iceform, etc.) trigger at thresholds. Should these be permanent for the run or timed buffs?

**Options:**
1. Permanent until death — Power spike reward
2. Timed (30-60s) — Temporary, must re-trigger
3. Maintained by element use — Decays unless kept active

**Answer:** Timed (30-60s)

**Implementation:**
- Forms are powerful temporary buffs, not permanent upgrades
- Duration: 30-60 seconds (exact values TBD during balance)
- Threshold counter resets after form expires
- Visual: Timer bar above player health showing form duration
- Audio: Sound cue when form activates and 5s warning before expiry
- Form effects (aura damage, stat bonuses) only active during duration

---

### Q8: Wand Acquisition

**Question:** The spec has 8 findable wands but players find '1-2 per run'. How should wand acquisition work?

**Options:**
1. Shop only (25-50g) — Predictable progression
2. Elite/boss drops — Reward skill
3. Random world drops — Excitement factor
4. Choice of 3 at shop — Player agency

**Answer:** Shop only (25-50g)

**Implementation:**
- Wands appear in shop at stages 2 and 4 (per acquisition timeline)
- Price range: 25-50g depending on wand power tier
- Shop offers 1-2 wands per appearance (randomized from findable pool)
- No random enemy drops — deterministic progression
- Player can skip wand purchase to save gold for equipment/artifacts

---

## Decision Summary

| Decision | Choice | Key Detail |
|----------|--------|------------|
| **Scope** | Full spec required | No cuts allowed |
| **Melee arc** | Line sweep queries | 8-step segment_query |
| **Stack decay** | StatusEngine | Centralized in combat_system.lua |
| **Starter gear** | Preview in select | UI shows equipment + artifact before confirm |
| **Element lock** | 3rd skill point | Track invested elements, lock 4th |
| **Multi-trigger** | ALL required | Both triggers must fire same frame |
| **Form duration** | Timed 30-60s | Temporary buff, threshold resets |
| **Wand drops** | Shop only | 25-50g at stages 2 and 4 |

---

## Spec Systems Requiring Implementation

Based on Demo Content Specification v3:

### Gods (4)
- Pyr: Fire blessing (Scorch × 5 damage), On hit: +1 Scorch
- Glah: Shatter blessing (Freeze × 10 damage), On hit: +1 Freeze
- Vix: Lightning step blessing (Speed × 2 damage), On kill: Chain Lightning
- Nil: Doom execute blessing (Doom × 10 damage), On death: +2 Doom nearby

### Classes (2)
- **Channeler:** Void Edge wand (0.3s timer), +5% spell dmg per nearby enemy, Arcane Charge system
- **Seer:** Sight Beam wand (1.0s timer), +10% far/-10% close damage, Focused buff system

### Core Systems
- Melee arc combat (Channeler)
- Status decay (Scorch/Freeze/Doom/Charge/Inflame)
- Element lock (3 of 4)
- Multi-trigger skills (ALL logic)
- Transformation forms (timed 30-60s)
- Aura system (damage ticks around player)
- God selection with gear preview
- Shop wand purchasing

---

## Next Steps

1. Create PLAN_v0.md with phased implementation
2. Launch subagents to analyze codebase vs spec requirements
3. Identify existing system coverage and gaps
4. Build implementation task list with dependencies
