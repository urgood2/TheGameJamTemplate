# Implementation Plan: Demo Content Specification v3

## Executive Summary

This plan implements the complete Demo Content Spec v3 across 7 phases, delivering 4 gods, 2 classes, 32 skills, 8 wands, ~40 cards, 15 artifacts, and 12 equipment pieces. The architecture centers on extending existing systems (StatusEngine, WandTemplates, SkillSystem) rather than building from scratch.

**Critical Path:** Phase 1 (Combat Core) → Phase 2 (Identity) → Phase 3 (Skills) → Phase 4 (Forms) → Phase 5 (Cards) → Phase 6 (Items) → Phase 7 (Economy)

**Estimated Total:** 45-60 tasks across 7 phases
**Parallelization:** Phases 5 and 6 can run concurrently after Phase 4 completes

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         RUN START FLOW                               │
├─────────────────────────────────────────────────────────────────────┤
│  God Selection UI → Class Selection → Starter Gear Grant → Combat   │
└─────────────────────────────────────────────────────────────────────┘
                                    │
         ┌──────────────────────────┼──────────────────────────┐
         ▼                          ▼                          ▼
┌─────────────────┐     ┌─────────────────────┐     ┌─────────────────┐
│   COMBAT CORE   │     │   PROGRESSION       │     │   ECONOMY       │
├─────────────────┤     ├─────────────────────┤     ├─────────────────┤
│ • Melee Arc     │     │ • Skill System      │     │ • Shop System   │
│ • StatusEngine  │     │ • Element Lock      │     │ • Gold Drops    │
│ • Aura System   │     │ • Forms (timed)     │     │ • Wand Prices   │
│ • Wand Triggers │     │ • Multi-Trigger     │     │ • Stage Gating  │
└─────────────────┘     └─────────────────────┘     └─────────────────┘
         │                          │                          │
         └──────────────────────────┴──────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          DATA DEFINITIONS                            │
├─────────────────────────────────────────────────────────────────────┤
│  Gods (4) │ Classes (2) │ Skills (32) │ Wands (8) │ Cards (~40)     │
│  Artifacts (15) │ Equipment (12) │ Status Effects (8)               │
└─────────────────────────────────────────────────────────────────────┘
```

### Key Integration Points

| System | File | Integration |
|--------|------|-------------|
| StatusEngine | `combat/combat_system.lua` | Add decay rates, form buffs |
| WandTemplates | `core/card_eval_order_test.lua` | Add new trigger types |
| SkillSystem | `core/skill_system.lua` | Add element lock, multi-trigger |
| CardSystem | `data/cards.lua` | Add modifier/action cards |
| AvatarSystem | `data/avatars.lua` | Add gods + classes |

---

## Phase 1: Combat Core Systems

**Goal:** Combat loop feels satisfying with both classes
**Dependencies:** None (foundation)
**Parallel Capacity:** Tasks 1.1, 1.2, 1.3 can run in parallel after 1.0

### Task 1.0: Combat System Audit [S]
**File:** `assets/scripts/combat/combat_system.lua`
**Action:** READ ONLY - Document existing StatusEngine API

**Acceptance Criteria:**
- [ ] Document `StatusEngine.apply(entity, status, stacks)` signature
- [ ] Document `StatusEngine.remove(entity, status)` signature
- [ ] Document existing status effects structure in `data/status_effects.lua`
- [ ] Identify where per-frame updates occur

---

### Task 1.1: Melee Arc System [M]
**Files:**
- NEW: `assets/scripts/combat/melee_arc.lua`
- MODIFY: `assets/scripts/wand/wand_actions.lua` (add ACTION_MELEE_SWING handler)

**Implementation:**

```lua
-- melee_arc.lua
local MeleeArc = {}

--- Execute line-sweep arc query (8-step)
-- @param caster entity performing the swing
-- @param config table { arc_angle, range, damage, damage_type }
-- @return table of hit entities
function MeleeArc.execute(caster, config)
    local origin = Q.center(caster)
    local facing = MeleeArc.get_facing(caster)
    local STEPS = 8
    local step_angle = config.arc_angle / STEPS
    local start_angle = facing - config.arc_angle / 2
    local hit_entities = {}

    for i = 0, STEPS do
        local angle = math.rad(start_angle + step_angle * i)
        local end_x = origin.x + math.cos(angle) * config.range
        local end_y = origin.y + math.sin(angle) * config.range

        physics.segment_query(world, origin, {x = end_x, y = end_y}, function(shape)
            local entity = physics.entity_from_ptr(shape)
            if MeleeArc.is_valid_target(entity) and not hit_entities[entity] then
                hit_entities[entity] = true
            end
        end)
    end

    return hit_entities
end

function MeleeArc.get_facing(entity)
    -- Use PlayerFacing component or input direction
    local facing = component_cache.get(entity, PlayerFacing)
    if facing then return facing.angle end
    return 0  -- Default right
end

function MeleeArc.is_valid_target(entity)
    return entity and ensure_entity(entity) and 
           component_cache.get(entity, EnemyTag) ~= nil
end

return MeleeArc
```

**Acceptance Criteria:**
- [ ] Line sweep queries 8 points across arc
- [ ] Deduplicates hits (entity hit once per swing)
- [ ] Respects physics collision layers
- [ ] Returns hit entities for damage application
- [ ] Uses `PlayerFacing` component for direction

**Edge Cases:**
- No enemies in range → return empty table
- Entity destroyed mid-sweep → skip via `ensure_entity`
- Multiple enemies at same position → both hit

---

### Task 1.2: Status Decay System [M]
**File:** MODIFY `assets/scripts/combat/combat_system.lua`

**Implementation:**

```lua
-- Add to StatusEngine module
local STATUS_DECAY_CONFIG = {
    scorch  = { interval = 2.0, amount = 1 },
    freeze  = { interval = 3.0, amount = 1 },
    doom    = { interval = 4.0, amount = 1 },
    charge  = { interval = 2.0, amount = 1 },
    inflame = { interval = 3.0, amount = 1 },
}

-- Add decay_timer field to status data structure
-- Modify StatusEngine.update() to call this per entity
function StatusEngine.process_decay(dt, entity_id, status_name, status_data)
    local decay = STATUS_DECAY_CONFIG[status_name]
    if not decay then return end  -- No decay for this status

    status_data.decay_timer = (status_data.decay_timer or 0) + dt
    if status_data.decay_timer >= decay.interval then
        status_data.decay_timer = 0
        status_data.stacks = math.max(0, status_data.stacks - decay.amount)
        
        if status_data.stacks == 0 then
            StatusEngine.remove(entity_id, status_name)
        end
    end
end
```

**Acceptance Criteria:**
- [ ] Each status type has configurable decay interval
- [ ] Decay timer persists across frames
- [ ] Status auto-removes at 0 stacks
- [ ] Decay can be disabled per-status (nil config)
- [ ] Respects immunity flags (Scorch Master skill)

**Edge Cases:**
- Status applied while decaying → stacks add, timer continues
- Entity dies while status active → cleanup handled by entity destruction
- Form buffs don't decay (special handling in Task 4.1)

---

### Task 1.3: Starter Wands [M]
**Files:**
- MODIFY: `assets/scripts/core/card_eval_order_test.lua` (add to WandTemplates)
- NEW: `assets/scripts/data/starter_wands.lua` (definitions)

**Implementation:**

```lua
-- starter_wands.lua
local StarterWands = {}

StarterWands.VOID_EDGE = {
    id = "VOID_EDGE",
    display_name = "Void Edge",
    description = "Close-range channeling blade",
    
    -- Trigger config
    trigger_type = "every_N_seconds",
    trigger_interval = 0.3,
    
    -- Mana stats
    mana_max = 40,
    mana_recharge_rate = 12,  -- per second
    
    -- Cast config
    cast_block_size = 2,
    cast_delay = 100,        -- ms
    recharge_time = 300,     -- ms
    
    -- Slots
    total_card_slots = 4,
    starting_cards = { "MOD_PIERCE", "ACTION_MELEE_SWING" },
}

StarterWands.SIGHT_BEAM = {
    id = "SIGHT_BEAM",
    display_name = "Sight Beam",
    description = "Long-range precision staff",
    
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

return StarterWands
```

**Acceptance Criteria:**
- [ ] VOID_EDGE: 0.3s trigger, 40 mana, 4 slots, melee-focused
- [ ] SIGHT_BEAM: 1.0s trigger, 80 mana, 6 slots, projectile-focused
- [ ] Both wands equippable in god selection flow
- [ ] Starting cards auto-populate when wand equipped
- [ ] Wand stats display in UI

---

### Task 1.4: ACTION_MELEE_SWING Card [S]
**File:** MODIFY `assets/scripts/data/cards.lua`

```lua
Cards.ACTION_MELEE_SWING = {
    id = "ACTION_MELEE_SWING",
    type = "action",
    element = "physical",
    display_name = "Melee Swing",
    description = "Sweep nearby enemies in an arc",
    
    mana_cost = 8,
    damage = 15,
    damage_type = "physical",
    
    -- Arc config (used by melee_arc.lua)
    arc_angle = 90,       -- degrees
    range = 60,           -- pixels
    duration = 0.15,      -- animation duration
}
```

**Acceptance Criteria:**
- [ ] Card integrates with wand cast system
- [ ] Calls `MeleeArc.execute()` on trigger
- [ ] Applies damage to all hit entities
- [ ] Triggers hit VFX and sound

---

## Phase 2: Gods & Classes

**Goal:** Player identity established at run start
**Dependencies:** Phase 1 complete (starter wands exist)
**Parallel Capacity:** Tasks 2.1 and 2.2 can run in parallel

### Task 2.1: God Definitions [M]
**File:** MODIFY `assets/scripts/data/avatars.lua`

**Structure per god:**

```lua
Avatars.pyr = {
    id = "pyr",
    type = "god",
    display_name = "Pyr",
    element = "fire",
    
    blessing = {
        id = "inferno_burst",
        display_name = "Inferno Burst",
        description = "Deal Fire damage equal to 5× total Scorch stacks on all enemies",
        cooldown = 30,  -- seconds
        icon = "blessing_inferno_burst",
        
        execute = function(player)
            local total_scorch = StatusEngine.sum_all_enemy_stacks("scorch")
            local damage = total_scorch * 5
            Combat.deal_aoe_damage(player, 9999, damage, "fire")
            signal.emit("blessing_used", player, "inferno_burst")
        end,
    },
    
    passive = {
        id = "scorch_touch",
        description = "Your hits apply 1 Scorch",
        trigger = "on_hit",
        
        on_trigger = function(player, target, damage_info)
            if target and ensure_entity(target) then
                StatusEngine.apply(target, "scorch", 1)
            end
        end,
    },
    
    starter_equipment = "burning_gloves",
    starter_artifact = "flame_starter",
}
```

**All 4 Gods:**

| God | Element | Blessing | Passive |
|-----|---------|----------|---------|
| Pyr | Fire | Inferno Burst (5× Scorch AoE) | Hits apply 1 Scorch |
| Glah | Ice | Glacial Cascade (10× Freeze AoE + Shatter) | Hits apply 1 Freeze |
| Vix | Lightning | Storm Call (3× Charge chain) | Hits apply 1 Charge |
| Nil | Void | Death Knell (8× Doom execute) | Hits apply 1 Doom |

**Acceptance Criteria:**
- [ ] 4 gods defined with unique blessings
- [ ] Each blessing has 30s cooldown
- [ ] Passive triggers on appropriate event
- [ ] Starter equipment/artifact references valid items

---

### Task 2.2: Class Definitions [M]
**File:** MODIFY `assets/scripts/data/avatars.lua`

**Channeler:**
```lua
Avatars.channeler = {
    id = "channeler",
    type = "class",
    display_name = "Channeler",
    description = "Melee-focused spellcaster",
    
    starter_wand = "VOID_EDGE",
    
    passive = {
        id = "proximity_power",
        description = "+5% spell damage per enemy within close range (max +25%)",
        
        update = function(player, dt)
            local nearby = physics.count_enemies_in_radius(player, 100)
            local bonus = math.min(nearby * 5, 25) / 100
            player.spell_damage_mult = 1.0 + bonus
        end,
    },
    
    triggered = {
        id = "arcane_buildup",
        description = "Gain 1 Arcane Charge on hit (max 10). At 10: +100% damage next spell, reset",
        trigger = "on_hit",
        
        on_trigger = function(player, target, damage_info)
            player.arcane_charges = (player.arcane_charges or 0) + 1
            if player.arcane_charges >= 10 then
                player.next_spell_damage_bonus = 1.0  -- +100%
                player.arcane_charges = 0
                signal.emit("arcane_charges_consumed", player)
            end
        end,
    },
}
```

**Seer:**
```lua
Avatars.seer = {
    id = "seer",
    type = "class",
    display_name = "Seer",
    description = "Long-range precision caster",
    
    starter_wand = "SIGHT_BEAM",
    
    passive = {
        id = "distant_sight",
        description = "+3% spell damage per 50px from target (max +30%)",
        
        on_damage_calc = function(player, target, base_damage)
            local dist = Q.distance(player, target)
            local bonus = math.min(math.floor(dist / 50) * 3, 30) / 100
            return base_damage * (1.0 + bonus)
        end,
    },
    
    triggered = {
        id = "focus_fire",
        description = "Hitting same enemy 3× in 2s: +50% damage next hit",
        trigger = "on_hit",
        
        on_trigger = function(player, target, damage_info)
            player.focus_targets = player.focus_targets or {}
            local now = globals.game_time
            local key = tostring(target)
            
            player.focus_targets[key] = player.focus_targets[key] or {}
            table.insert(player.focus_targets[key], now)
            
            -- Clean old hits
            local recent = {}
            for _, t in ipairs(player.focus_targets[key]) do
                if now - t < 2.0 then table.insert(recent, t) end
            end
            player.focus_targets[key] = recent
            
            if #recent >= 3 then
                player.next_hit_bonus = 0.5  -- +50%
                player.focus_targets[key] = {}
            end
        end,
    },
}
```

**Acceptance Criteria:**
- [ ] Channeler gets VOID_EDGE wand
- [ ] Seer gets SIGHT_BEAM wand
- [ ] Passives update each frame or on event
- [ ] Triggered abilities fire correctly

---

### Task 2.3: God Selection UI [L]
**Files:**
- NEW: `assets/scripts/ui/god_select_panel.lua`
- MODIFY: `assets/scripts/core/main.lua` (hook into game start)

**Requirements:**

```lua
-- god_select_panel.lua structure
local GodSelectPanel = {}

function GodSelectPanel.create()
    local panel = EntityBuilder.new()
        :addUIBox({ width = 800, height = 600 })
        :addTag("GodSelectPanel")
        :build()
    
    -- God cards grid (2x2)
    GodSelectPanel.create_god_cards(panel)
    
    -- Class selector (below gods)
    GodSelectPanel.create_class_selector(panel)
    
    -- Preview panel (right side)
    GodSelectPanel.create_preview_panel(panel)
    
    -- Confirm button
    GodSelectPanel.create_confirm_button(panel)
    
    return panel
end

function GodSelectPanel.create_god_cards(parent)
    local gods = { "pyr", "glah", "vix", "nil" }
    local positions = {
        {x = 100, y = 100}, {x = 300, y = 100},
        {x = 100, y = 300}, {x = 300, y = 300},
    }
    
    for i, god_id in ipairs(gods) do
        local god = Avatars[god_id]
        local card = GodSelectPanel.create_god_card(god, positions[i])
        ChildBuilder.attach(card, parent)
    end
end

function GodSelectPanel.on_god_selected(god_id)
    GodSelectPanel.selected_god = god_id
    GodSelectPanel.update_preview()
end

function GodSelectPanel.on_confirm()
    local god = Avatars[GodSelectPanel.selected_god]
    local class = Avatars[GodSelectPanel.selected_class]
    
    -- Grant starter gear
    Inventory.add_equipment(god.starter_equipment)
    Inventory.add_artifact(god.starter_artifact)
    Inventory.equip_wand(class.starter_wand)
    
    -- Apply god passive
    PlayerManager.set_god(god)
    PlayerManager.set_class(class)
    
    -- Start run
    signal.emit("run_started")
end

return GodSelectPanel
```

**UI Layout:**
```
┌─────────────────────────────────────────────────────────┐
│                    SELECT YOUR PATH                      │
├───────────────────────────────┬─────────────────────────┤
│  ┌─────┐  ┌─────┐            │     PREVIEW             │
│  │ PYR │  │GLAH │            │ ─────────────────────   │
│  └─────┘  └─────┘            │ Blessing: [name]        │
│  ┌─────┐  ┌─────┐            │ [description]           │
│  │ VIX │  │ NIL │            │                         │
│  └─────┘  └─────┘            │ Passive: [name]         │
│                              │ [description]           │
│  CLASS: [Channeler] [Seer]   │                         │
│                              │ Starter Gear:           │
│                              │ [equipment icon]        │
│                              │ [artifact icon]         │
│                              │ [wand preview]          │
├───────────────────────────────┴─────────────────────────┤
│              [ CONFIRM ]                                 │
└─────────────────────────────────────────────────────────┘
```

**Acceptance Criteria:**
- [ ] 4 god cards displayed in grid
- [ ] Clicking god highlights and updates preview
- [ ] Class selector shows 2 options
- [ ] Preview shows blessing, passive, starter gear
- [ ] Confirm button grants gear and starts run
- [ ] ESC closes panel (if applicable)

**Edge Cases:**
- No selection → Confirm disabled
- Rapid clicking → debounce selection
- UI scaling → use `ui_scale.SPRITE_SCALE`

---

## Phase 3: Skills System

**Goal:** 32 skills with element lock mechanic
**Dependencies:** Phase 2 complete (gods/classes exist)
**Parallel Capacity:** Tasks 3.1 and 3.2 independent; 3.3 depends on both

### Task 3.1: Element Lock Mechanic [M]
**File:** MODIFY `assets/scripts/core/skill_system.lua`

```lua
-- Add to SkillSystem
local MAX_ELEMENTS = 3

function SkillSystem.can_learn(player, skill_id)
    local skill = Skills.get(skill_id)
    if not skill then return false, "Invalid skill" end
    
    local element = skill.element
    local invested = player.elements_invested or {}
    
    -- Already have this element
    if invested[element] then
        return true
    end
    
    -- Check element count
    local count = 0
    for _ in pairs(invested) do count = count + 1 end
    
    if count >= MAX_ELEMENTS then
        return false, "Element locked (max 3 elements)"
    end
    
    return true
end

function SkillSystem.learn(player, skill_id)
    local can, reason = SkillSystem.can_learn(player, skill_id)
    if not can then
        signal.emit("skill_learn_failed", player, skill_id, reason)
        return false
    end
    
    local skill = Skills.get(skill_id)
    
    -- Track element investment
    player.elements_invested = player.elements_invested or {}
    player.elements_invested[skill.element] = true
    
    -- Add skill
    player.learned_skills = player.learned_skills or {}
    player.learned_skills[skill_id] = {
        level = 1,
        cooldown_remaining = 0,
    }
    
    -- Register triggers
    SkillSystem.register_triggers(player, skill)
    
    signal.emit("skill_learned", player, skill_id)
    return true
end
```

**Acceptance Criteria:**
- [ ] Player can invest in max 3 elements
- [ ] 4th element blocked with clear feedback
- [ ] Element tracked on first skill of that element
- [ ] Unlocking triggers UI update
- [ ] Skills UI shows locked elements

---

### Task 3.2: Multi-Trigger Logic [M]
**File:** MODIFY `assets/scripts/core/skill_system.lua`

```lua
-- Frame event tracking
local frame_events = {}
local frame_event_data = {}

function SkillSystem.on_event(event_type, event_data)
    frame_events[event_type] = true
    frame_event_data[event_type] = event_data
end

function SkillSystem.end_frame(player)
    for skill_id, skill_data in pairs(player.learned_skills) do
        local skill = Skills.get(skill_id)
        
        if skill.triggers and #skill.triggers > 1 then
            -- Multi-trigger: ALL required in same frame
            local all_present = true
            local combined_data = {}
            
            for _, trigger in ipairs(skill.triggers) do
                if not frame_events[trigger] then
                    all_present = false
                    break
                end
                combined_data[trigger] = frame_event_data[trigger]
            end
            
            if all_present then
                SkillSystem.execute_skill(player, skill, combined_data)
            end
        elseif skill.triggers then
            -- Single trigger
            local trigger = skill.triggers[1]
            if frame_events[trigger] then
                SkillSystem.execute_skill(player, skill, frame_event_data[trigger])
            end
        end
    end
    
    -- Clear for next frame
    frame_events = {}
    frame_event_data = {}
end
```

**Acceptance Criteria:**
- [ ] Events collected per-frame
- [ ] Multi-trigger skills require ALL triggers same frame
- [ ] Single-trigger skills fire normally
- [ ] Event data passed to skill execution
- [ ] Frame cleared after processing

---

### Task 3.3: Skill Definitions (32 Total) [L]
**File:** MODIFY `assets/scripts/data/skills.lua`

**Fire Skills (8):**

```lua
Skills.kindle = {
    id = "kindle",
    element = "fire",
    cost = 1,
    display_name = "Kindle",
    description = "+2 Scorch on hit",
    triggers = { "on_hit" },
    
    execute = function(player, target, data)
        StatusEngine.apply(target, "scorch", 2)
    end,
}

Skills.pyrokinesis = {
    id = "pyrokinesis",
    element = "fire",
    cost = 2,
    display_name = "Pyrokinesis",
    description = "Hits deal 30 Fire AoE",
    triggers = { "on_hit" },
    
    execute = function(player, target, data)
        local pos = Q.center(target)
        Combat.deal_aoe_damage(pos, 80, 30, "fire")
    end,
}

Skills.fire_healing = {
    id = "fire_healing",
    element = "fire",
    cost = 2,
    display_name = "Fire Healing",
    description = "Heal 3 when you deal Fire damage",
    triggers = { "on_fire_damage" },
    
    execute = function(player, target, data)
        PlayerManager.heal(player, 3)
    end,
}

Skills.combustion = {
    id = "combustion",
    element = "fire",
    cost = 3,
    display_name = "Combustion",
    description = "Killed enemies explode for Scorch × 10 damage",
    triggers = { "enemy_killed" },
    
    execute = function(player, target, data)
        local stacks = StatusEngine.get_stacks(target, "scorch")
        local damage = stacks * 10
        local pos = Q.center(target)
        Combat.deal_aoe_damage(pos, 100, damage, "fire")
    end,
}

Skills.flame_familiar = {
    id = "flame_familiar",
    element = "fire",
    cost = 3,
    display_name = "Flame Familiar",
    description = "Summon Fire Sprite at wave start",
    triggers = { "on_wave_start" },
    
    execute = function(player, target, data)
        Summons.spawn("fire_sprite", player)
    end,
}

Skills.roil = {
    id = "roil",
    element = "fire",
    cost = 3,
    display_name = "Roil",
    description = "On hit + fire damage: Heal 5, +2 Inflame, 15 self-damage",
    triggers = { "on_hit", "on_fire_damage" },  -- Multi-trigger
    
    execute = function(player, target, data)
        PlayerManager.heal(player, 5)
        StatusEngine.apply(player, "inflame", 2)
        PlayerManager.damage(player, 15, "fire", { source = "self" })
    end,
}

Skills.scorch_master = {
    id = "scorch_master",
    element = "fire",
    cost = 4,
    display_name = "Scorch Master",
    description = "Immune to Scorch. Your Scorch never expires on enemies",
    triggers = {},  -- Passive
    
    on_learn = function(player)
        player.scorch_immunity = true
        player.scorch_no_decay = true
    end,
}

Skills.fire_form = {
    id = "fire_form",
    element = "fire",
    cost = 5,
    display_name = "Fire Form",
    description = "At 100 Fire damage dealt: Gain Fireform (45s)",
    triggers = { "on_fire_damage" },
    threshold = 100,
    
    execute = function(player, target, data)
        player.fire_damage_dealt = (player.fire_damage_dealt or 0) + data.damage
        if player.fire_damage_dealt >= 100 then
            StatusEngine.apply(player, "fireform", 1, { duration = 45 })
            player.fire_damage_dealt = 0
        end
    end,
}
```

**Ice Skills (8):** Freeze-focused (same pattern)
**Lightning Skills (8):** Charge-focused (same pattern)
**Void Skills (8):** Doom-focused (same pattern)

**Acceptance Criteria:**
- [ ] 8 skills per element (32 total)
- [ ] Costs range 1-5 per spec
- [ ] Multi-trigger skills use array triggers
- [ ] Form skills track threshold damage
- [ ] Passive skills use `on_learn` callback

---

## Phase 4: Transformation Forms

**Goal:** Timed power spikes with aura effects
**Dependencies:** Phase 3 complete (form skills exist)
**Parallel Capacity:** 4.1 and 4.2 can run in parallel

### Task 4.1: Form Status Effects [M]
**File:** MODIFY `assets/scripts/data/status_effects.lua`

```lua
StatusEffects.fireform = {
    id = "fireform",
    type = "form",
    display_name = "Fireform",
    description = "Burning incarnation",
    
    -- Timed duration (not permanent)
    duration = 45,
    decay_immune = true,  -- Forms don't stack-decay
    
    stat_modifiers = {
        fire_damage = { mult = 0.30 },  -- +30% Fire damage
    },
    
    aura = {
        enabled = true,
        radius = 80,
        tick_interval = 0.5,
        effects = {
            { type = "damage", amount = 10, damage_type = "fire" },
            { type = "status", status = "scorch", stacks = 1 },
        },
    },
    
    visuals = {
        shader = "fireform_shader",
        particles = "flame_aura_particles",
        tint = { r = 1.0, g = 0.5, b = 0.2 },
    },
    
    on_apply = function(entity)
        signal.emit("form_activated", entity, "fireform")
    end,
    
    on_expire = function(entity)
        signal.emit("form_expired", entity, "fireform")
    end,
}

-- Similar for iceform, stormform, voidform
```

**All 4 Forms:**

| Form | Duration | Damage Bonus | Aura Effect |
|------|----------|--------------|-------------|
| Fireform | 45s | +30% Fire | 10 Fire/0.5s, +1 Scorch |
| Iceform | 45s | +30% Ice | 10 Ice/0.5s, +1 Freeze |
| Stormform | 45s | +30% Lightning | 15 Lightning/0.5s, +1 Charge |
| Voidform | 45s | +30% Void | 8 Void/0.5s, +1 Doom |

**Acceptance Criteria:**
- [ ] 4 forms defined with stat bonuses
- [ ] Forms have 30-60s duration (configurable)
- [ ] Forms don't decay via StatusEngine
- [ ] Aura config attached to form
- [ ] Visual effects specified

---

### Task 4.2: Aura Tick System [M]
**Files:**
- NEW: `assets/scripts/combat/aura_system.lua`
- MODIFY: `assets/scripts/core/main.lua` (register update)

```lua
-- aura_system.lua
local AuraSystem = {}

local active_auras = {}  -- entity -> { aura_id -> data }

function AuraSystem.register(entity, aura_config)
    active_auras[entity] = active_auras[entity] or {}
    active_auras[entity][aura_config.id] = {
        config = aura_config,
        tick_timer = 0,
    }
end

function AuraSystem.unregister(entity, aura_id)
    if active_auras[entity] then
        active_auras[entity][aura_id] = nil
    end
end

function AuraSystem.update(dt)
    for entity, auras in pairs(active_auras) do
        if not ensure_entity(entity) then
            active_auras[entity] = nil
        else
            for aura_id, data in pairs(auras) do
                data.tick_timer = data.tick_timer + dt
                if data.tick_timer >= data.config.tick_interval then
                    data.tick_timer = 0
                    AuraSystem.tick(entity, data.config)
                end
            end
        end
    end
end

function AuraSystem.tick(entity, config)
    local cx, cy = Q.center(entity)
    local enemies = physics.query_circle(world, cx, cy, config.radius, "enemy")
    
    for _, enemy in ipairs(enemies) do
        if ensure_entity(enemy) then
            for _, effect in ipairs(config.effects) do
                if effect.type == "damage" then
                    Combat.deal_damage(enemy, effect.amount, effect.damage_type, { source = entity })
                elseif effect.type == "status" then
                    StatusEngine.apply(enemy, effect.status, effect.stacks)
                end
            end
        end
    end
end

-- Hook into form activation
signal.register("form_activated", function(entity, form_id)
    local form = StatusEffects[form_id]
    if form and form.aura and form.aura.enabled then
        AuraSystem.register(entity, {
            id = form_id .. "_aura",
            radius = form.aura.radius,
            tick_interval = form.aura.tick_interval,
            effects = form.aura.effects,
        })
    end
end)

signal.register("form_expired", function(entity, form_id)
    AuraSystem.unregister(entity, form_id .. "_aura")
end)

return AuraSystem
```

**Acceptance Criteria:**
- [ ] Auras tick at configurable intervals
- [ ] Radius-based enemy detection
- [ ] Multiple effects per tick supported
- [ ] Auras auto-register on form activation
- [ ] Auras auto-unregister on form expiry
- [ ] Dead entities cleaned up

---

## Phase 5: Cards & Wands

**Goal:** Full card pool + findable wands
**Dependencies:** Phase 1 complete (card system exists)
**Parallel Capacity:** Tasks 5.1, 5.2, 5.3 can all run in parallel

### Task 5.1: Modifier Cards (12) [M]
**File:** MODIFY `assets/scripts/data/cards.lua`

```lua
-- Chain modifier
Cards.MOD_CHAIN_2 = {
    id = "MOD_CHAIN_2",
    type = "modifier",
    display_name = "Chain 2",
    description = "Chain to 2 additional targets",
    mana_cost = 8,
    
    modify = function(spell)
        spell.chain_count = (spell.chain_count or 0) + 2
    end,
}

-- Pierce modifier
Cards.MOD_PIERCE = {
    id = "MOD_PIERCE",
    type = "modifier",
    display_name = "Pierce",
    description = "Pass through 2 enemies",
    mana_cost = 5,
    
    modify = function(spell)
        spell.pierce_count = (spell.pierce_count or 0) + 2
    end,
}

-- Fork modifier
Cards.MOD_FORK = {
    id = "MOD_FORK",
    type = "modifier",
    display_name = "Fork",
    description = "Split into 3 projectiles at half damage",
    mana_cost = 10,
    
    modify = function(spell)
        spell.fork_count = 3
        spell.damage = spell.damage * 0.5
    end,
}

-- Continue for all 12...
```

**Full Modifier List:**

| Card | Mana | Effect |
|------|------|--------|
| Chain 2 | 8 | +2 chain targets |
| Pierce | 5 | +2 pierce |
| Fork | 10 | Split 3×, ½ damage |
| Homing | 6 | Seek nearest |
| Larger AoE | 8 | AoE +50% |
| Concentrated | 6 | AoE -50%, damage +50% |
| Delayed | 5 | 1s delay, +30% power |
| Rapid | 10 | Cooldowns -20% |
| Empowered | 12 | +25% damage, +25% mana |
| Efficient | 5 | -25% mana, -15% damage |
| Lingering | 8 | DoT +50% duration |
| Brittle | 6 | Frozen targets +25% damage |

**Acceptance Criteria:**
- [ ] 12 modifier cards defined
- [ ] Each modifies spell table correctly
- [ ] Mana costs balanced per spec
- [ ] Modifiers stack appropriately

---

### Task 5.2: Action Cards (16) [M]
**File:** MODIFY `assets/scripts/data/cards.lua`

**Fire Actions (4):**
```lua
Cards.ACTION_FIREBALL = {
    id = "ACTION_FIREBALL",
    type = "action",
    element = "fire",
    display_name = "Fireball",
    description = "Explosive fire projectile",
    mana_cost = 15,
    
    damage = 25,
    damage_type = "fire",
    projectile_speed = 400,
    aoe_radius = 60,
    
    on_cast = function(caster, spell)
        Projectiles.spawn("fireball", caster, spell)
    end,
    
    on_hit = function(target, spell)
        StatusEngine.apply(target, "scorch", 2)
    end,
}
```

**Full Action List (4 per element):**

| Element | Actions |
|---------|---------|
| Fire | Fireball, Flame Wave, Ignite, Combustion Blast |
| Ice | Ice Bolt, Frost Nova, Glacial Spike, Blizzard |
| Lightning | Lightning Bolt, Chain Lightning, Thunder Strike, Storm Pulse |
| Void | Void Orb, Death Ray, Shadow Blast, Annihilate |

**Acceptance Criteria:**
- [ ] 16 action cards (4 per element)
- [ ] Each spawns appropriate projectile/effect
- [ ] Status effects applied on hit
- [ ] Mana costs vary by power

---

### Task 5.3: Findable Wands (6) [M]
**File:** MODIFY `assets/scripts/core/card_eval_order_test.lua`

```lua
WandTemplates.RAGE_FIST = {
    id = "RAGE_FIST",
    display_name = "Rage Fist",
    description = "Triggers when you bump into enemies",
    
    trigger_type = "on_bump_enemy",
    trigger_data = { cooldown = 0.5 },
    
    mana_max = 30,
    mana_recharge_rate = 15,
    cast_block_size = 2,
    total_card_slots = 4,
    
    shop_price = 25,
    shop_stages = { 2, 3, 4 },  -- Available in these stages
}

WandTemplates.STORM_WALKER = {
    id = "STORM_WALKER",
    display_name = "Storm Walker",
    description = "Triggers after walking distance",
    
    trigger_type = "on_distance_traveled",
    trigger_data = { distance = 200 },  -- pixels
    
    mana_max = 60,
    mana_recharge_rate = 8,
    cast_block_size = 3,
    total_card_slots = 5,
    
    shop_price = 35,
    shop_stages = { 2, 3, 4 },
}

-- Continue for all 6 findable wands...
```

**Full Wand List:**

| Wand | Trigger | Price | Stages |
|------|---------|-------|--------|
| Rage Fist | on_bump_enemy | 25g | 2-4 |
| Storm Walker | on_distance_traveled(200px) | 35g | 2-4 |
| Frost Anchor | on_stand_still(2s) | 40g | 2-4 |
| Soul Siphon | enemy_killed | 30g | 2-4 |
| Pain Echo | on_player_hit | 35g | 2-4 |
| Ember Pulse | every_N_seconds(0.5s) | 50g | 2-4 |

**Acceptance Criteria:**
- [ ] 6 wands with unique triggers
- [ ] Triggers implemented in wand system
- [ ] Shop prices set correctly
- [ ] Stage availability configured

---

## Phase 6: Artifacts & Equipment

**Goal:** 15 artifacts + 12 equipment pieces
**Dependencies:** Phase 2 complete (equipment system exists)
**Parallel Capacity:** Tasks 6.1 and 6.2 can run in parallel

### Task 6.1: Artifacts (15) [M]
**File:** MODIFY `assets/scripts/data/artifacts.lua`

```lua
-- Common (5)
Artifacts.burning_gloves = {
    id = "burning_gloves",
    rarity = "common",
    display_name = "Burning Gloves",
    description = "+10% Fire damage",
    
    stat_modifiers = {
        fire_damage = { mult = 0.10 },
    },
}

Artifacts.frozen_heart = {
    id = "frozen_heart",
    rarity = "common",
    display_name = "Frozen Heart",
    description = "+10% Ice damage",
    
    stat_modifiers = {
        ice_damage = { mult = 0.10 },
    },
}

-- Uncommon (5)
Artifacts.scorch_ring = {
    id = "scorch_ring",
    rarity = "uncommon",
    display_name = "Scorch Ring",
    description = "Scorch deals +5 damage per stack",
    
    on_scorch_tick = function(entity, stacks)
        Combat.deal_damage(entity, stacks * 5, "fire")
    end,
}

-- Rare (5)
Artifacts.phoenix_feather = {
    id = "phoenix_feather",
    rarity = "rare",
    display_name = "Phoenix Feather",
    description = "Revive once at 50% HP. Gain Fireform on revive",
    
    on_death = function(player)
        if not player.phoenix_used then
            player.phoenix_used = true
            PlayerManager.revive(player, 0.5)
            StatusEngine.apply(player, "fireform", 1, { duration = 45 })
            return true  -- Prevent death
        end
        return false
    end,
}
```

**Full Artifact List:**

| Tier | Artifacts |
|------|-----------|
| Common | Burning Gloves, Frozen Heart, Rubber Boots, Lucky Coin, Healing Salve |
| Uncommon | Scorch Ring, Glacial Shield, Storm Battery, Vampiric Pendant, Doom Shard |
| Rare | Phoenix Feather, Elemental Convergence, Berserker's Rage, Prismatic Core, Chrono Lens |

**Acceptance Criteria:**
- [ ] 15 artifacts across 3 tiers
- [ ] Stat modifiers apply correctly
- [ ] Triggered effects fire on event
- [ ] Rarity affects drop rates

---

### Task 6.2: Equipment (12) [M]
**File:** MODIFY `assets/scripts/data/equipment.lua`

```lua
-- Chest pieces (4)
Equipment.flame_robes = {
    id = "flame_robes",
    slot = "chest",
    display_name = "Flame Robes",
    description = "+15% Fire damage, -10% Ice damage",
    
    stat_modifiers = {
        fire_damage = { mult = 0.15 },
        ice_damage = { mult = -0.10 },
    },
}

-- Gloves (4)
Equipment.ignition_gauntlets = {
    id = "ignition_gauntlets",
    slot = "gloves",
    display_name = "Ignition Gauntlets",
    description = "Melee attacks apply +1 Scorch",
    
    on_melee_hit = function(target)
        StatusEngine.apply(target, "scorch", 1)
    end,
}

-- Boots (4)
Equipment.ember_greaves = {
    id = "ember_greaves",
    slot = "boots",
    display_name = "Ember Greaves",
    description = "+10% move speed, leave fire trail",
    
    stat_modifiers = {
        move_speed = { mult = 0.10 },
    },
    
    on_move = function(player, position)
        if math.random() < 0.3 then
            Hazards.spawn("fire_trail", position)
        end
    end,
}
```

**Full Equipment List:**

| Slot | Items |
|------|-------|
| Chest | Flame Robes, Frost Plate, Storm Cloak, Void Vestments |
| Gloves | Ignition Gauntlets, Glacier Grips, Surge Bracers, Reaper's Touch |
| Boots | Ember Greaves, Frozen Treads, Lightning Striders, Death Walkers |

**Acceptance Criteria:**
- [ ] 12 equipment pieces (4 per slot)
- [ ] Slot restrictions enforced
- [ ] Stat modifiers apply
- [ ] Triggered effects work

---

## Phase 7: Economy & Progression

**Goal:** Balanced run pacing
**Dependencies:** Phases 5 and 6 complete
**Parallel Capacity:** Tasks 7.1 and 7.2 independent

### Task 7.1: Skill Point Grants [S]
**File:** MODIFY `assets/scripts/core/progression.lua`

```lua
local SKILL_POINTS_PER_LEVEL = {
    [1] = 0,   -- Start
    [2] = 2,
    [3] = 2,
    [4] = 2,
    [5] = 2,
    [6] = 2,
}

function Progression.on_level_up(player, new_level)
    local points = SKILL_POINTS_PER_LEVEL[new_level] or 2
    player.skill_points = (player.skill_points or 0) + points
    signal.emit("skill_points_gained", player, points)
end
```

**Acceptance Criteria:**
- [ ] 0 points at level 1
- [ ] +2 points per level (levels 2-6)
- [ ] 10 total points by max level
- [ ] UI shows available points

---

### Task 7.2: Shop Wand Integration [M]
**File:** MODIFY `assets/scripts/ui/shop_panel.lua`

```lua
function ShopPanel.generate_inventory(stage)
    local inventory = {}
    
    -- Equipment always available
    inventory.equipment = ShopPanel.roll_equipment(stage)
    
    -- Wands available stage 2+
    if stage >= 2 then
        local available_wands = {}
        for id, wand in pairs(WandTemplates) do
            if wand.shop_price and table_contains(wand.shop_stages, stage) then
                table.insert(available_wands, wand)
            end
        end
        
        -- Roll 1-2 wands
        local count = math.random(1, 2)
        inventory.wands = ShopPanel.roll_from(available_wands, count)
    end
    
    -- Artifacts from elite drops stage 3+
    if stage >= 3 then
        inventory.artifacts = ShopPanel.roll_artifacts(stage)
    end
    
    return inventory
end
```

**Stage Contents:**

| Stage | Shop Contents |
|-------|---------------|
| 1 | Equipment only |
| 2 | Equipment + 1-2 Wands |
| 3 | Equipment + 1-2 Wands + Artifact (elite drop) |
| 4 | Equipment + 1-2 Wands + Artifact |
| 5 | Boss (no shop) |

**Acceptance Criteria:**
- [ ] Stage 1: equipment only
- [ ] Stage 2+: wands appear in shop
- [ ] Stage 3+: artifacts appear
- [ ] Prices display correctly
- [ ] Purchase deducts gold

---

## Critical Path & Dependencies

```
              ┌─────────────────────────────────────────────────────┐
              │                    CRITICAL PATH                      │
              └─────────────────────────────────────────────────────┘

 Phase 1                Phase 2              Phase 3              Phase 4
┌────────┐            ┌────────┐           ┌────────┐           ┌────────┐
│ Combat │──────────▶│Identity│─────────▶│ Skills │─────────▶│ Forms  │
│  Core  │            │Gods/Cls│           │  (32)  │           │ (Timed)│
└────────┘            └────────┘           └────────┘           └────────┘
   │                                           │                     │
   │                                           │                     │
   │                                           ▼                     ▼
   │                                      ┌────────┐           ┌────────┐
   └──────────────────────────────────────│ Cards  │◀──────────│Economy │
                                          │ & Wands│           │Progres.│
                                          └────────┘           └────────┘
                                               ▲                     ▲
                                               │                     │
                                          ┌────────┐                 │
                                          │Artifact│─────────────────┘
                                          │& Equip │
                                          └────────┘

PARALLEL OPPORTUNITIES:
- Phase 5 (Cards) and Phase 6 (Items) can run concurrently after Phase 4
- Within Phase 1: Tasks 1.1, 1.2, 1.3 can run in parallel after 1.0
- Within Phase 3: Task 3.3 (skill defs) is data-entry parallelizable by element
- Within Phase 5: Tasks 5.1, 5.2, 5.3 are fully independent
- Within Phase 6: Tasks 6.1 and 6.2 are fully independent
```

---

## Risk Mitigation

### R1: Physics Query Performance (Melee Arc)
**Risk:** 8-step line sweep may be slow with many entities
**Mitigation:** 
- Use spatial hash for broad phase
- Cap enemies per sweep (8-10 max)
- Profile and optimize if needed

### R2: StatusEngine Complexity
**Risk:** Decay system may conflict with existing status logic
**Mitigation:**
- Add `decay_immune` flag for forms
- Test status stacking thoroughly
- Add StatusEngine.debug_dump() for troubleshooting

### R3: Multi-Trigger Frame Timing
**Risk:** Events from different systems may not fire same frame
**Mitigation:**
- Document expected frame order
- Add 1-frame buffer option if needed
- Test with intentional lag injection

### R4: God Selection UI Complexity
**Risk:** Complex UI with many interactions
**Mitigation:**
- Follow UI Panel Implementation Guide exactly
- Reuse existing panel patterns from `player_inventory.lua`
- Test on multiple resolutions

### R5: Balance Cascades
**Risk:** 32 skills + 40 cards = 1280+ combinations
**Mitigation:**
- Implement analytics hooks for playtesting
- Flag obviously broken combos for review
- Design skills to fail gracefully when interactions unclear

---

## Acceptance Criteria Summary

| Phase | Tasks | Acceptance Gate |
|-------|-------|-----------------|
| 1 | 4 | Channeler melee swing damages enemies; statuses decay |
| 2 | 3 | God select grants starter gear; classes have unique passives |
| 3 | 3 | 32 skills learnable; element lock at 3rd element |
| 4 | 2 | Forms last 30-60s; auras tick and damage |
| 5 | 3 | 28 cards castable; 6 wands purchasable |
| 6 | 2 | 15 artifacts + 12 equipment equippable |
| 7 | 2 | Skill points granted on level; shop has wands stage 2+ |

**Final Integration Test:** Complete a full run selecting each god/class combination, purchasing wands, learning skills across 3 elements, and triggering at least one form transformation.

---

`★ Insight ─────────────────────────────────────`
**Architecture Decisions:**
1. StatusEngine centralization allows decay, immunity, and form buffs to coexist without scattered logic
2. Multi-trigger skills use frame-collected events rather than callback chaining, making timing deterministic
3. Forms as timed statuses (not permanent) creates meaningful power spikes without balance-breaking sustain
`─────────────────────────────────────────────────`
