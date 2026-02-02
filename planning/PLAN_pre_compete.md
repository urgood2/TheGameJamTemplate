# PLAN v0 — Demo Content Specification v3 Implementation

**Date:** 2026-02-02
**Source Spec:** [`planning/DEMO_CONTENT_SPEC_v3.md`](./DEMO_CONTENT_SPEC_v3.md)
**Interview:** [`planning/INTERVIEW_TRANSCRIPT.md`](./INTERVIEW_TRANSCRIPT.md)
**Status:** Initial Plan

---

## Executive Summary

Implement all systems from Demo Content Specification v3 with no scope cuts. Key technical decisions from interview:

| Decision | Choice |
|----------|--------|
| Melee arc | Line sweep queries (8-step) |
| Stack decay | StatusEngine (centralized) |
| Starter gear | Preview in god selection UI |
| Element lock | 3rd skill point triggers lock |
| Multi-trigger | ALL triggers required (same frame) |
| Form duration | Timed 30-60s (not permanent) |
| Wand acquisition | Shop only (25-50g) |

---

## Content Targets

| System | Count | Implementation |
|--------|-------|----------------|
| **Gods** | 4 | Pyr, Glah, Vix, Nil with blessings + passives |
| **Classes** | 2 | Channeler (melee), Seer (ranged) |
| **Skills** | 32 | 8 per element × 4 elements |
| **Wands** | 8 | 2 starter + 6 findable |
| **Cards** | ~40 | Modifiers (12) + Actions (16) |
| **Artifacts** | 15 | 5 common, 5 uncommon, 5 rare |
| **Equipment** | 12 | 4 chest + 4 gloves + 4 boots |
| **Status Effects** | 8 | Scorch, Freeze, Doom, Charge, Inflame + 4 forms |

---

## Phase 1: Core Combat Systems

**Goal:** Combat loop feels satisfying with both classes

### 1.1 Melee Arc System (Channeler)

**Files:**
- NEW: `assets/scripts/combat/melee_arc.lua`
- MODIFY: `assets/scripts/wand/wand_actions.lua`

**Implementation:**
```lua
-- ACTION_MELEE_SWING card definition
{
    id = "ACTION_MELEE_SWING",
    type = "action",
    mana_cost = 8,
    damage = 15,
    damage_type = "physical",
    arc_angle = 90,       -- degrees
    range = 60,           -- pixels
    duration = 0.15,      -- seconds
}

-- Line sweep implementation (8-step)
function executeMeleeArc(caster, config)
    local origin = Q.center(caster)
    local facing = getPlayerFacing()
    local steps = 8
    local stepAngle = config.arc_angle / steps
    local startAngle = facing - config.arc_angle / 2
    local hitEntities = {}

    for i = 0, steps do
        local angle = math.rad(startAngle + stepAngle * i)
        local endX = origin.x + math.cos(angle) * config.range
        local endY = origin.y + math.sin(angle) * config.range

        physics.segment_query(world, origin, {x=endX, y=endY}, function(shape)
            local entity = physics.entity_from_ptr(shape)
            if isEnemy(entity) and not hitEntities[entity] then
                hitEntities[entity] = true
                dealDamage(entity, config.damage, config.damage_type)
            end
        end)
    end
end
```

### 1.2 Status Decay System

**Files:**
- MODIFY: `assets/scripts/combat/combat_system.lua` (StatusEngine)
- MODIFY: `assets/scripts/data/status_effects.lua`

**Implementation:**
```lua
-- Add to StatusEngine
local STATUS_DECAY_RATES = {
    scorch  = { interval = 2.0, amount = 1 },
    freeze  = { interval = 3.0, amount = 1 },
    doom    = { interval = 4.0, amount = 1 },
    charge  = { interval = 2.0, amount = 1 },
    inflame = { interval = 3.0, amount = 1 },
}

-- In StatusEngine.update_entity()
function StatusEngine.update_entity(dt, entityId, statuses)
    for statusName, data in pairs(statuses) do
        local decay = STATUS_DECAY_RATES[statusName]
        if decay then
            data.decayTimer = (data.decayTimer or 0) + dt
            if data.decayTimer >= decay.interval then
                data.stacks = math.max(0, data.stacks - decay.amount)
                data.decayTimer = 0
                if data.stacks == 0 then
                    StatusEngine.remove(entityId, statusName)
                end
            end
        end
    end
end
```

### 1.3 Starter Wands

**Files:**
- MODIFY: `assets/scripts/core/card_eval_order_test.lua` (WandTemplates)
- NEW: `assets/scripts/data/starter_wands.lua`

**Void Edge (Channeler):**
```lua
WandTemplates.VOID_EDGE = {
    id = "VOID_EDGE",
    trigger_type = "every_N_seconds",
    trigger_interval = 0.3,
    mana_max = 40,
    mana_recharge_rate = 12,
    cast_block_size = 2,
    cast_delay = 100,
    recharge_time = 300,
    total_card_slots = 4,
    starting_cards = { "MOD_PIERCE", "ACTION_MELEE_SWING" },
}
```

**Sight Beam (Seer):**
```lua
WandTemplates.SIGHT_BEAM = {
    id = "SIGHT_BEAM",
    trigger_type = "every_N_seconds",
    trigger_interval = 1.0,
    mana_max = 80,
    mana_recharge_rate = 6,
    cast_block_size = 3,
    cast_delay = 50,
    recharge_time = 800,
    total_card_slots = 6,
    starting_cards = { "MOD_PIERCE", "MOD_HOMING", "ACTION_PROJECTILE_BOLT" },
}
```

---

## Phase 2: Gods & Classes

**Goal:** Player identity established at run start

### 2.1 God Definitions

**Files:**
- MODIFY: `assets/scripts/data/avatars.lua`

**Structure:**
```lua
Avatars.pyr = {
    id = "pyr",
    type = "god",
    name = "Pyr",
    element = "fire",
    blessing = {
        id = "inferno_burst",
        name = "Inferno Burst",
        description = "Deal Fire damage = 5 × total Scorch stacks on all enemies",
        cooldown = 30,
        effect = function(player)
            local totalScorch = sumAllEnemyStacks("scorch")
            local damage = totalScorch * 5
            dealAoEDamage(player, 9999, damage, "fire")
        end,
    },
    passive = {
        trigger = "on_hit",
        effect = function(target)
            StatusEngine.apply(target, "scorch", 1)
        end,
    },
    starter_equipment = "burning_gloves",
    starter_artifact = "flame_starter",
}
```

### 2.2 Class Definitions

**Files:**
- MODIFY: `assets/scripts/data/avatars.lua`

**Channeler:**
```lua
Avatars.channeler = {
    id = "channeler",
    type = "class",
    name = "Channeler",
    starter_wand = "VOID_EDGE",
    passive = {
        description = "+5% spell damage per enemy within close range (max +25%)",
        update = function(player)
            local nearby = countEnemiesInRange(player, 100)
            local bonus = math.min(nearby * 5, 25)
            player.spell_damage_bonus = bonus
        end,
    },
    triggered = {
        trigger = "on_hit",
        description = "Gain 1 Arcane Charge (max 10). At 10: +100% damage, reset",
        effect = function(player)
            player.arcane_charges = (player.arcane_charges or 0) + 1
            if player.arcane_charges >= 10 then
                player.next_spell_bonus = 100
                player.arcane_charges = 0
            end
        end,
    },
}
```

### 2.3 God Selection UI

**Files:**
- NEW: `assets/scripts/ui/god_select_panel.lua`
- MODIFY: `assets/scripts/core/main.lua`

**Requirements:**
- Grid of 4 god cards (Pyr, Glah, Vix, Nil)
- Each card shows: name, blessing, passive
- Below god: starter equipment + artifact preview
- Class selector (Channeler / Seer) separate
- Confirm button grants gear and starts run

---

## Phase 3: Skills System

**Goal:** 32 skills with element lock mechanic

### 3.1 Element Lock

**Files:**
- MODIFY: `assets/scripts/core/skill_system.lua`
- MODIFY: `assets/scripts/ui/skills_panel.lua`

**Implementation:**
```lua
function SkillSystem.learn_skill(player, skillId)
    local skill = Skills.get(skillId)
    local element = skill.element

    -- Track element investment
    player.elements_invested = player.elements_invested or {}
    if not player.elements_invested[element] then
        local count = table_size(player.elements_invested)
        if count >= 3 then
            -- 4th element locked
            return false, "Element locked"
        end
        player.elements_invested[element] = true
    end

    -- Existing learn logic...
end
```

### 3.2 Multi-Trigger Skills

**Files:**
- MODIFY: `assets/scripts/core/skill_system.lua`

**Implementation:**
```lua
-- Track events per frame
local frame_events = {}

function SkillSystem.on_event(event_type, event_data)
    frame_events[#frame_events + 1] = { type = event_type, data = event_data }
end

function SkillSystem.end_frame()
    for _, skill in pairs(active_skills) do
        if skill.triggers and #skill.triggers > 1 then
            -- Multi-trigger: ALL required
            local all_present = true
            for _, trigger in ipairs(skill.triggers) do
                local found = false
                for _, ev in ipairs(frame_events) do
                    if ev.type == trigger then found = true; break end
                end
                if not found then all_present = false; break end
            end
            if all_present then
                executeSkillEffect(skill, frame_events)
            end
        end
    end
    frame_events = {}
end
```

### 3.3 Skill Definitions (32)

**Files:**
- MODIFY: `assets/scripts/data/skills.lua`

**Fire Skills (8):**
| Skill | Cost | Triggers | Effect |
|-------|------|----------|--------|
| Kindle | 1 | on_hit | +2 Scorch |
| Pyrokinesis | 2 | on_hit | 30 Fire AoE |
| Fire Healing | 2 | on_fire_damage | Heal 3 |
| Combustion | 3 | enemy_killed | Explode for Scorch × 10 |
| Flame Familiar | 3 | on_wave_start | Summon Fire Sprite |
| Roil | 3 | on_hit + on_fire_damage | Heal 5, +2 Inflame, 15 self-damage |
| Scorch Master | 4 | passive | Immune to Scorch, Scorch never expires |
| Fire Form | 5 | on_threshold(100 Fire) | Gain Fireform (30-60s) |

*(Ice, Lightning, Void skills follow same pattern - see spec)*

---

## Phase 4: Transformation Forms

**Goal:** Timed power spikes with aura effects

### 4.1 Form Implementation

**Files:**
- MODIFY: `assets/scripts/data/status_effects.lua`
- NEW: `assets/scripts/combat/aura_system.lua`

**Fireform:**
```lua
StatusEffects.fireform = {
    id = "fireform",
    type = "buff",
    duration = 45,  -- seconds
    stat_mods = {
        fire_damage = { add = 0, mult = 0.30 },  -- +30% Fire
    },
    aura = {
        radius = 80,
        tick_interval = 0.5,
        damage = 10,
        damage_type = "fire",
        apply_status = "scorch",
        status_stacks = 1,
    },
    shader = "fireform_shader",
    particles = "flame_aura_particles",
    on_apply = function(entity)
        signal.emit("form_activated", entity, "fireform")
    end,
    on_remove = function(entity)
        signal.emit("form_expired", entity, "fireform")
        -- Reset threshold counter
        entity.fire_damage_threshold = 0
    end,
}
```

### 4.2 Aura Tick System

**Files:**
- NEW: `assets/scripts/combat/aura_system.lua`

```lua
AuraSystem = {}

function AuraSystem.update(dt)
    for entity, auras in pairs(active_auras) do
        for auraId, aura in pairs(auras) do
            aura.tickTimer = (aura.tickTimer or 0) + dt
            if aura.tickTimer >= aura.config.tick_interval then
                aura.tickTimer = 0
                AuraSystem.tick(entity, aura.config)
            end
        end
    end
end

function AuraSystem.tick(entity, config)
    local cx, cy = Q.center(entity)
    local enemies = physics.GetObjectsInArea(world,
        cx - config.radius, cy - config.radius,
        config.radius * 2, config.radius * 2)

    for _, enemy in ipairs(enemies) do
        if isEnemyEntity(enemy) then
            if config.damage then
                dealDamage(enemy, config.damage, config.damage_type)
            end
            if config.apply_status then
                StatusEngine.apply(enemy, config.apply_status, config.status_stacks)
            end
        end
    end
end
```

---

## Phase 5: Cards & Wands

**Goal:** Full card pool + findable wands

### 5.1 Modifier Cards (12)

**Files:**
- MODIFY: `assets/scripts/data/cards.lua`

| Card | Mana | Effect |
|------|------|--------|
| Chain 2 | 8 | Chain to 2 additional targets |
| Pierce | 5 | Pass through 2 enemies |
| Fork | 10 | Split into 3 at half damage |
| Homing | 6 | Seek nearest enemy |
| Larger AoE | 8 | AoE radius +50% |
| Concentrated | 6 | AoE -50%, damage +50% |
| Delayed | 5 | 1s delay, +30% power |
| Rapid | 10 | Cooldowns -20% |
| Empowered | 12 | +25% damage, +25% mana |
| Efficient | 5 | -25% mana, -15% damage |
| Lingering | 8 | DoT lasts 50% longer |
| Brittle | 6 | Frozen enemies +25% damage |

### 5.2 Action Cards (16)

**Files:**
- MODIFY: `assets/scripts/data/cards.lua`

*(4 Fire + 4 Ice + 4 Lightning + 4 Void - see spec for details)*

### 5.3 Findable Wands (6)

**Files:**
- MODIFY: `assets/scripts/core/card_eval_order_test.lua`

| Wand | Trigger | Price |
|------|---------|-------|
| Rage Fist | on_bump_enemy | 25g |
| Storm Walker | on_distance_traveled | 35g |
| Frost Anchor | on_stand_still | 40g |
| Soul Siphon | enemy_killed | 30g |
| Pain Echo | on_player_hit | 35g |
| Ember Pulse | every_N_seconds (0.5s) | 50g |

---

## Phase 6: Artifacts & Equipment

**Goal:** 15 artifacts + 12 equipment pieces

### 6.1 Artifacts

**Files:**
- MODIFY: `assets/scripts/data/artifacts.lua`

**Tiers:**
- Common (5): Burning Gloves, Frozen Heart, Rubber Boots, Lucky Coin, Healing Salve
- Uncommon (5): Scorch Ring, Glacial Shield, Storm Battery, Vampiric Pendant, Doom Shard
- Rare (5): Phoenix Feather, Elemental Convergence, Berserker's Rage, Prismatic Core, Chrono Lens

### 6.2 Equipment

**Files:**
- MODIFY: `assets/scripts/data/equipment.lua`

**Slots:**
- Chest (4): Flame Robes, Frost Plate, Storm Cloak, Void Vestments
- Gloves (4): Ignition Gauntlets, Glacier Grips, Surge Bracers, Reaper's Touch
- Boots (4): Ember Greaves, Frozen Treads, Lightning Striders, Death Walkers

---

## Phase 7: Economy & Progression

**Goal:** Balanced run pacing

### 7.1 Skill Points

| Level | Points | Cumulative |
|-------|--------|------------|
| Start | 0 | 0 |
| 2 | +2 | 2 |
| 3 | +2 | 4 |
| 4 | +2 | 6 |
| 5 | +2 | 8 |
| 6 | +2 | 10 |

### 7.2 Acquisition Timeline

| Stage | Shop Contents |
|-------|---------------|
| 1 | Equipment only |
| 2 | Equipment + Wand (1-2) |
| 3 | Equipment + Artifact (elite drop) |
| 4 | Equipment + Wand + Artifact |
| 5 | Boss |

---

## Implementation Order

```
Phase 1 (Combat Core)
├── 1.1 Melee Arc System
├── 1.2 Status Decay
└── 1.3 Starter Wands
    ↓
Phase 2 (Identity)
├── 2.1 God Definitions
├── 2.2 Class Definitions
└── 2.3 God Selection UI
    ↓
Phase 3 (Skills)
├── 3.1 Element Lock
├── 3.2 Multi-Trigger Logic
└── 3.3 Skill Definitions (32)
    ↓
Phase 4 (Forms)
├── 4.1 Form Buffs (timed)
└── 4.2 Aura Tick System
    ↓
Phase 5 (Cards)
├── 5.1 Modifier Cards (12)
├── 5.2 Action Cards (16)
└── 5.3 Findable Wands (6)
    ↓
Phase 6 (Items)
├── 6.1 Artifacts (15)
└── 6.2 Equipment (12)
    ↓
Phase 7 (Economy)
├── 7.1 Skill Point Grants
└── 7.2 Shop Wand Integration
```

---

## File Impact Summary

**New Files:**
- `assets/scripts/combat/melee_arc.lua`
- `assets/scripts/combat/aura_system.lua`
- `assets/scripts/data/starter_wands.lua`
- `assets/scripts/ui/god_select_panel.lua`

**Modified Files:**
- `assets/scripts/combat/combat_system.lua` (StatusEngine decay)
- `assets/scripts/data/status_effects.lua` (forms, decay rates)
- `assets/scripts/data/avatars.lua` (gods + classes)
- `assets/scripts/data/skills.lua` (32 skills)
- `assets/scripts/data/cards.lua` (modifiers + actions)
- `assets/scripts/data/artifacts.lua` (15 artifacts)
- `assets/scripts/data/equipment.lua` (12 equipment)
- `assets/scripts/core/skill_system.lua` (element lock, multi-trigger)
- `assets/scripts/core/card_eval_order_test.lua` (wand templates)
- `assets/scripts/ui/skills_panel.lua` (element lock UI)

---

## Next Steps

1. **Gap Analysis:** Launch subagents to compare spec vs existing code
2. **Task Creation:** Create implementation tasks for each phase
3. **Priority:** Start with Phase 1 (combat core) for immediate playability
4. **Testing:** Add tests for melee arc, status decay, element lock
