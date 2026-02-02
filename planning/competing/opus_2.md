# Demo Content Specification v3 Implementation Plan

## Executive Summary (TL;DR)

This plan implements 4 gods, 2 classes, 32 skills, 8 wands, ~40 cards, 15 artifacts, and 12 equipment pieces for the demo. The critical path runs through: **Melee Arc → Status Decay → Starter Wands → God/Class Selection → Skills with Element Lock → Cards → Items**.

**MVP Milestone (Playable in ~40% of effort):** Phase 1 + Phase 2 delivers a working combat loop with both classes, god selection, and starter gear. Everything after is content layering.

**Key Technical Decisions:**
- Melee arc uses 8-step line sweep queries (not shape cast)
- Status decay centralized in StatusEngine (not per-effect timers)
- Forms are timed buffs (30-60s) with aura tick system
- Multi-trigger skills require ALL triggers in same frame
- Element lock triggers at 3rd skill point investment

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        GAME SYSTEMS                              │
├─────────────────────────────────────────────────────────────────┤
│  God Selection UI ──► Player Identity ──► Combat Loop           │
│       │                    │                   │                │
│       ▼                    ▼                   ▼                │
│  ┌─────────┐        ┌───────────┐      ┌─────────────┐         │
│  │ Avatars │        │  Skills   │      │ StatusEngine│         │
│  │  .lua   │───────►│ System    │◄────►│  (Decay)    │         │
│  └─────────┘        └───────────┘      └─────────────┘         │
│       │                    │                   ▲                │
│       ▼                    ▼                   │                │
│  ┌─────────┐        ┌───────────┐      ┌─────────────┐         │
│  │ Starter │        │ Aura Tick │      │  Melee Arc  │         │
│  │  Wands  │        │  System   │      │   System    │         │
│  └─────────┘        └───────────┘      └─────────────┘         │
│       │                    │                   │                │
│       └────────────────────┴───────────────────┘                │
│                            │                                    │
│                            ▼                                    │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐  ┌──────────┐      │
│  │  Cards   │  │Artifacts │  │ Equipment │  │  Wands   │      │
│  │(28+12)   │  │  (15)    │  │   (12)    │  │   (8)    │      │
│  └──────────┘  └──────────┘  └───────────┘  └──────────┘      │
└─────────────────────────────────────────────────────────────────┘
```

**Data Flow:**
1. Player selects God + Class → grants starter wand, equipment, artifact
2. Combat triggers → StatusEngine applies/decays stacks
3. Melee arc (Channeler) or projectiles (Seer) deal damage
4. Skills check triggers per frame → execute effects
5. Forms activate via damage thresholds → Aura system ticks
6. Cards modify wand behavior during cast evaluation

---

## Phase 1: Core Combat Systems
**Goal:** Combat loop feels satisfying with both classes  
**Estimated Duration:** Parallelizable tasks

### Task 1.1: Melee Arc System [Size: M]

**Files:**
- NEW: `assets/scripts/combat/melee_arc.lua`
- MODIFY: `assets/scripts/wand/wand_actions.lua`
- MODIFY: `assets/scripts/data/cards.lua` (add ACTION_MELEE_SWING)

**Implementation Details:**

```lua
-- assets/scripts/combat/melee_arc.lua
local MeleeArc = {}

local SWEEP_STEPS = 8  -- Configurable, 8 is good balance

function MeleeArc.execute(caster, config)
    local origin = Q.center(caster)
    local facing = MeleeArc.get_facing(caster)
    local halfArc = math.rad(config.arc_angle / 2)
    local stepAngle = math.rad(config.arc_angle) / SWEEP_STEPS
    local startAngle = facing - halfArc
    
    local hitEntities = {}
    local hitCount = 0
    
    for i = 0, SWEEP_STEPS do
        local angle = startAngle + (stepAngle * i)
        local endPoint = {
            x = origin.x + math.cos(angle) * config.range,
            y = origin.y + math.sin(angle) * config.range
        }
        
        physics.segment_query(world, origin, endPoint, function(shape)
            local entity = physics.entity_from_ptr(shape)
            if MeleeArc.is_valid_target(entity, caster) and not hitEntities[entity] then
                hitEntities[entity] = true
                hitCount = hitCount + 1
                MeleeArc.apply_hit(caster, entity, config)
            end
        end)
    end
    
    -- Visual feedback
    MeleeArc.spawn_arc_vfx(origin, facing, config)
    
    return hitCount, hitEntities
end

function MeleeArc.get_facing(caster)
    -- Use mouse direction or last movement direction
    local pos = Q.center(caster)
    local mouse = globals.mouse_world_pos
    return math.atan2(mouse.y - pos.y, mouse.x - pos.x)
end

function MeleeArc.is_valid_target(entity, caster)
    if not ensure_entity(entity) then return false end
    if entity == caster then return false end
    return registry:has(entity, EnemyTag) or registry:has(entity, DestructibleTag)
end

function MeleeArc.apply_hit(caster, target, config)
    local damage = config.damage
    -- Apply caster bonuses (spell_damage_bonus from Channeler passive)
    local script = safe_script_get(caster)
    if script and script.spell_damage_bonus then
        damage = damage * (1 + script.spell_damage_bonus / 100)
    end
    
    dealDamage(target, damage, config.damage_type or "physical")
    signal.emit("player_hit_enemy", caster, target, damage)
end

function MeleeArc.spawn_arc_vfx(origin, facing, config)
    -- Queue arc slash visual on combat layer
    command_buffer.queueDraw(layers.combat_vfx, function()
        -- Draw arc slash effect
    end, z_orders.COMBAT_VFX, layer.DrawCommandSpace.World)
end

return MeleeArc
```

**Card Definition:**
```lua
-- In assets/scripts/data/cards.lua
Cards.ACTION_MELEE_SWING = {
    id = "ACTION_MELEE_SWING",
    name = "Melee Swing",
    type = "action",
    mana_cost = 8,
    damage = 15,
    damage_type = "physical",
    arc_angle = 90,
    range = 60,
    duration = 0.15,
    execute = function(context)
        local MeleeArc = require("combat.melee_arc")
        return MeleeArc.execute(context.caster, context.card)
    end,
}
```

**Acceptance Criteria:**
- [ ] Arc sweeps 90° in front of player
- [ ] Each enemy hit exactly once per swing
- [ ] Damage applies caster bonuses
- [ ] Visual feedback shows arc slash
- [ ] `player_hit_enemy` signal fires per hit

**Test:**
```lua
-- Test melee arc hits multiple enemies
local test_enemies = spawn_test_enemies_in_arc(3)
local hits, _ = MeleeArc.execute(player, {arc_angle=90, range=60, damage=10})
assert(hits == 3, "Should hit all 3 enemies in arc")
```

---

### Task 1.2: Status Decay System [Size: S]

**Files:**
- MODIFY: `assets/scripts/combat/combat_system.lua`
- MODIFY: `assets/scripts/data/status_effects.lua`

**Implementation Details:**

```lua
-- Add to StatusEngine in combat_system.lua

local STATUS_DECAY_CONFIG = {
    scorch  = { interval = 2.0, amount = 1, min_stacks = 0 },
    freeze  = { interval = 3.0, amount = 1, min_stacks = 0 },
    doom    = { interval = 4.0, amount = 1, min_stacks = 0 },
    charge  = { interval = 2.0, amount = 1, min_stacks = 0 },
    inflame = { interval = 3.0, amount = 1, min_stacks = 0 },
}

function StatusEngine.update(dt)
    for entityId, statuses in pairs(StatusEngine.active_statuses) do
        if ensure_entity(entityId) then
            StatusEngine.update_entity(dt, entityId, statuses)
        else
            StatusEngine.active_statuses[entityId] = nil
        end
    end
end

function StatusEngine.update_entity(dt, entityId, statuses)
    local to_remove = {}
    
    for statusName, data in pairs(statuses) do
        -- Run existing tick effects (DoT, etc.)
        StatusEngine.tick_effect(dt, entityId, statusName, data)
        
        -- Handle stack decay
        local decay = STATUS_DECAY_CONFIG[statusName]
        if decay then
            data.decayTimer = (data.decayTimer or 0) + dt
            if data.decayTimer >= decay.interval then
                data.decayTimer = data.decayTimer - decay.interval
                local oldStacks = data.stacks
                data.stacks = math.max(decay.min_stacks, data.stacks - decay.amount)
                
                if data.stacks ~= oldStacks then
                    signal.emit("status_stack_changed", entityId, statusName, data.stacks, oldStacks)
                end
                
                if data.stacks <= 0 then
                    to_remove[#to_remove + 1] = statusName
                end
            end
        end
    end
    
    for _, statusName in ipairs(to_remove) do
        StatusEngine.remove(entityId, statusName)
    end
end

-- Allow skills to modify decay (e.g., "Scorch Master" prevents decay)
function StatusEngine.set_decay_immunity(entityId, statusName, immune)
    local statuses = StatusEngine.active_statuses[entityId]
    if statuses and statuses[statusName] then
        statuses[statusName].decayImmune = immune
    end
end
```

**Acceptance Criteria:**
- [ ] Scorch decays 1 stack every 2s
- [ ] Freeze decays 1 stack every 3s
- [ ] Status removed when stacks reach 0
- [ ] `status_stack_changed` signal fires on decay
- [ ] Decay immunity can be set per-entity per-status

**Test:**
```lua
-- Test scorch decay
StatusEngine.apply(enemy, "scorch", 3)
simulate_time(2.0)
assert(StatusEngine.get_stacks(enemy, "scorch") == 2)
simulate_time(4.0)
assert(StatusEngine.get_stacks(enemy, "scorch") == 0)
assert(not StatusEngine.has(enemy, "scorch"))
```

---

### Task 1.3: Starter Wands [Size: S]

**Files:**
- MODIFY: `assets/scripts/core/card_eval_order_test.lua` (WandTemplates)
- NEW: `assets/scripts/data/starter_wands.lua`

**Implementation Details:**

```lua
-- assets/scripts/data/starter_wands.lua
local StarterWands = {}

StarterWands.VOID_EDGE = {
    id = "VOID_EDGE",
    name = "Void Edge",
    description = "Fast melee wand for aggressive combat",
    sprite = "wand_void_edge",
    
    -- Trigger: every 0.3s while held
    trigger_type = "every_N_seconds",
    trigger_interval = 0.3,
    
    -- Mana
    mana_max = 40,
    mana_recharge_rate = 12,  -- per second
    
    -- Casting
    cast_block_size = 2,
    cast_delay = 100,  -- ms
    recharge_time = 300,  -- ms
    
    -- Slots
    total_card_slots = 4,
    starting_cards = {
        { slot = 1, card_id = "MOD_PIERCE" },
        { slot = 2, card_id = "ACTION_MELEE_SWING" },
    },
    
    -- Class restriction
    class_restriction = "channeler",
}

StarterWands.SIGHT_BEAM = {
    id = "SIGHT_BEAM",
    name = "Sight Beam",
    description = "Precision ranged wand for calculated strikes",
    sprite = "wand_sight_beam",
    
    -- Trigger: every 1.0s while held
    trigger_type = "every_N_seconds",
    trigger_interval = 1.0,
    
    -- Mana
    mana_max = 80,
    mana_recharge_rate = 6,
    
    -- Casting
    cast_block_size = 3,
    cast_delay = 50,
    recharge_time = 800,
    
    -- Slots
    total_card_slots = 6,
    starting_cards = {
        { slot = 1, card_id = "MOD_PIERCE" },
        { slot = 2, card_id = "MOD_HOMING" },
        { slot = 3, card_id = "ACTION_PROJECTILE_BOLT" },
    },
    
    class_restriction = "seer",
}

function StarterWands.create_for_class(classId)
    if classId == "channeler" then
        return StarterWands.instantiate("VOID_EDGE")
    elseif classId == "seer" then
        return StarterWands.instantiate("SIGHT_BEAM")
    end
    error("Unknown class: " .. tostring(classId))
end

function StarterWands.instantiate(wandId)
    local template = StarterWands[wandId]
    if not template then
        error("Unknown wand template: " .. tostring(wandId))
    end
    
    local wand = table.deep_copy(template)
    wand.current_mana = wand.mana_max
    wand.cards = {}
    
    for _, cardDef in ipairs(template.starting_cards) do
        wand.cards[cardDef.slot] = Cards.instantiate(cardDef.card_id)
    end
    
    return wand
end

return StarterWands
```

**Acceptance Criteria:**
- [ ] Void Edge fires every 0.3s when held
- [ ] Sight Beam fires every 1.0s when held
- [ ] Starting cards pre-loaded in correct slots
- [ ] Mana pool and recharge rates differ per wand
- [ ] Class restriction enforced

---

## Phase 2: Gods & Classes
**Goal:** Player identity established at run start  
**Dependencies:** Phase 1 (starter wands)

### Task 2.1: God Definitions [Size: M]

**Files:**
- MODIFY: `assets/scripts/data/avatars.lua`

**Implementation Details:**

```lua
-- assets/scripts/data/avatars.lua
local Avatars = Avatars or {}

-- ═══════════════════════════════════════════════════════════
-- GODS
-- ═══════════════════════════════════════════════════════════

Avatars.gods = {}

Avatars.gods.pyr = {
    id = "pyr",
    name = "Pyr",
    element = "fire",
    description = "God of consuming flame",
    sprite = "god_pyr",
    
    blessing = {
        id = "inferno_burst",
        name = "Inferno Burst",
        description = "Deal Fire damage equal to 5× total Scorch stacks on all enemies",
        cooldown = 30,
        icon = "blessing_inferno",
        
        can_activate = function(player)
            return sumAllEnemyStacks("scorch") > 0
        end,
        
        execute = function(player)
            local totalScorch = sumAllEnemyStacks("scorch")
            local damage = totalScorch * 5
            
            for _, enemy in ipairs(getAllEnemies()) do
                dealDamage(enemy, damage, "fire")
                -- Consume scorch stacks
                StatusEngine.remove(enemy, "scorch")
            end
            
            -- VFX
            spawn_blessing_vfx("inferno_burst", Q.center(player))
            signal.emit("blessing_activated", player, "inferno_burst", damage)
        end,
    },
    
    passive = {
        id = "flame_touch",
        name = "Flame Touch",
        description = "All hits apply 1 Scorch",
        trigger = "on_player_hit_enemy",
        
        effect = function(player, target, damage)
            StatusEngine.apply(target, "scorch", 1)
        end,
    },
    
    starter_equipment = "burning_gloves",
    starter_artifact = "flame_starter",
}

Avatars.gods.glah = {
    id = "glah",
    name = "Glah",
    element = "ice",
    description = "God of eternal frost",
    sprite = "god_glah",
    
    blessing = {
        id = "absolute_zero",
        name = "Absolute Zero",
        description = "Freeze all enemies for 3s. Frozen enemies take +50% damage",
        cooldown = 45,
        icon = "blessing_freeze",
        
        execute = function(player)
            for _, enemy in ipairs(getAllEnemies()) do
                StatusEngine.apply(enemy, "frozen", 3)  -- 3 second freeze
            end
            spawn_blessing_vfx("absolute_zero", Q.center(player))
        end,
    },
    
    passive = {
        id = "frost_touch",
        name = "Frost Touch", 
        description = "All hits apply 1 Freeze stack",
        trigger = "on_player_hit_enemy",
        
        effect = function(player, target, damage)
            StatusEngine.apply(target, "freeze", 1)
        end,
    },
    
    starter_equipment = "frost_plate",
    starter_artifact = "frozen_heart",
}

Avatars.gods.vix = {
    id = "vix",
    name = "Vix",
    element = "lightning",
    description = "God of the storm",
    sprite = "god_vix",
    
    blessing = {
        id = "chain_lightning",
        name = "Chain Lightning",
        description = "Lightning strikes all enemies, damage = 10 × your Charge stacks",
        cooldown = 25,
        icon = "blessing_chain",
        
        execute = function(player)
            local chargeStacks = StatusEngine.get_stacks(player, "charge") or 0
            local damage = math.max(10, chargeStacks * 10)
            
            local enemies = getAllEnemies()
            for i, enemy in ipairs(enemies) do
                -- Slight delay per enemy for visual chain effect
                Timer.after(i * 0.05, function()
                    if ensure_entity(enemy) then
                        dealDamage(enemy, damage, "lightning")
                        spawn_lightning_strike(Q.center(enemy))
                    end
                end)
            end
        end,
    },
    
    passive = {
        id = "static_touch",
        name = "Static Touch",
        description = "All hits apply 1 Charge stack to self",
        trigger = "on_player_hit_enemy",
        
        effect = function(player, target, damage)
            StatusEngine.apply(player, "charge", 1)
        end,
    },
    
    starter_equipment = "storm_cloak",
    starter_artifact = "storm_battery",
}

Avatars.gods.nil_ = {  -- 'nil' is reserved in Lua
    id = "nil",
    name = "Nil",
    element = "void",
    description = "God of the endless dark",
    sprite = "god_nil",
    
    blessing = {
        id = "doom_harvest",
        name = "Doom Harvest",
        description = "Execute all enemies below 20% HP. Gain 5 HP per kill",
        cooldown = 40,
        icon = "blessing_doom",
        
        execute = function(player)
            local kills = 0
            for _, enemy in ipairs(getAllEnemies()) do
                local hp = getHealth(enemy)
                local maxHp = getMaxHealth(enemy)
                if hp / maxHp <= 0.20 then
                    killEntity(enemy)
                    kills = kills + 1
                end
            end
            
            if kills > 0 then
                healEntity(player, kills * 5)
                spawn_blessing_vfx("doom_harvest", Q.center(player))
            end
        end,
    },
    
    passive = {
        id = "death_touch",
        name = "Death Touch",
        description = "All hits apply 1 Doom stack",
        trigger = "on_player_hit_enemy",
        
        effect = function(player, target, damage)
            StatusEngine.apply(target, "doom", 1)
        end,
    },
    
    starter_equipment = "void_vestments",
    starter_artifact = "doom_shard",
}
```

**Acceptance Criteria:**
- [ ] 4 gods defined with unique blessings
- [ ] Each god has passive that applies element status
- [ ] Blessings have cooldowns and VFX
- [ ] Starter gear references valid equipment/artifacts
- [ ] `blessing_activated` signal fires

---

### Task 2.2: Class Definitions [Size: M]

**Files:**
- MODIFY: `assets/scripts/data/avatars.lua`

**Implementation Details:**

```lua
-- Add to assets/scripts/data/avatars.lua

Avatars.classes = {}

Avatars.classes.channeler = {
    id = "channeler",
    name = "Channeler",
    description = "Melee combat specialist who channels power through proximity",
    sprite = "class_channeler",
    
    starter_wand = "VOID_EDGE",
    
    -- Passive: constant effect
    passive = {
        id = "proximity_power",
        name = "Proximity Power",
        description = "+5% spell damage per enemy within melee range (max +25%)",
        
        update = function(player, dt)
            local nearby = countEnemiesInRange(player, 100)  -- melee range
            local bonus = math.min(nearby * 5, 25)
            
            local script = safe_script_get(player)
            if script then
                script.spell_damage_bonus = bonus
            end
        end,
    },
    
    -- Triggered ability
    triggered = {
        id = "arcane_charge",
        name = "Arcane Charge",
        description = "Gain 1 Arcane Charge on hit (max 10). At 10: next spell +100% damage, reset",
        trigger = "on_player_hit_enemy",
        
        effect = function(player, target, damage)
            local script = safe_script_get(player)
            if not script then return end
            
            script.arcane_charges = (script.arcane_charges or 0) + 1
            signal.emit("arcane_charge_gained", player, script.arcane_charges)
            
            if script.arcane_charges >= 10 then
                script.next_spell_damage_bonus = 100
                script.arcane_charges = 0
                signal.emit("arcane_charge_consumed", player)
                -- VFX for charged state
                spawn_charge_ready_vfx(player)
            end
        end,
    },
    
    -- Stats
    base_stats = {
        max_health = 100,
        move_speed = 200,
        armor = 5,
    },
}

Avatars.classes.seer = {
    id = "seer",
    name = "Seer",
    description = "Ranged specialist who gains power through perfect accuracy",
    sprite = "class_seer",
    
    starter_wand = "SIGHT_BEAM",
    
    passive = {
        id = "precision_sight",
        name = "Precision Sight",
        description = "+2% crit chance per consecutive hit (max +20%). Reset on miss",
        
        -- Track in player script data
        on_hit = function(player, target)
            local script = safe_script_get(player)
            if not script then return end
            
            script.consecutive_hits = (script.consecutive_hits or 0) + 1
            script.crit_bonus = math.min(script.consecutive_hits * 2, 20)
        end,
        
        on_miss = function(player)
            local script = safe_script_get(player)
            if script then
                script.consecutive_hits = 0
                script.crit_bonus = 0
            end
        end,
    },
    
    triggered = {
        id = "marked_for_death",
        name = "Marked for Death",
        description = "Every 5th hit marks enemy for 3s. Marked enemies take +25% damage",
        trigger = "on_player_hit_enemy",
        
        effect = function(player, target, damage)
            local script = safe_script_get(player)
            if not script then return end
            
            script.hit_counter = (script.hit_counter or 0) + 1
            if script.hit_counter >= 5 then
                script.hit_counter = 0
                StatusEngine.apply(target, "marked", 3)  -- 3 second mark
                spawn_mark_vfx(target)
            end
        end,
    },
    
    base_stats = {
        max_health = 80,
        move_speed = 220,
        armor = 2,
    },
}

-- Helper to apply class to player
function Avatars.apply_class(player, classId)
    local class = Avatars.classes[classId]
    if not class then
        error("Unknown class: " .. tostring(classId))
    end
    
    local script = safe_script_get(player)
    script.class = class
    script.class_id = classId
    
    -- Apply base stats
    for stat, value in pairs(class.base_stats) do
        script[stat] = value
    end
    
    -- Register passive update if exists
    if class.passive and class.passive.update then
        Timer.every(0.1, function()
            if ensure_entity(player) then
                class.passive.update(player, 0.1)
                return true
            end
            return false  -- stop timer
        end)
    end
    
    -- Register triggered ability
    if class.triggered then
        signal.on(class.triggered.trigger, function(p, target, damage)
            if p == player then
                class.triggered.effect(player, target, damage)
            end
        end)
    end
end
```

**Acceptance Criteria:**
- [ ] Channeler passive updates every 0.1s
- [ ] Channeler arcane charge builds and consumes correctly
- [ ] Seer crit bonus tracks consecutive hits
- [ ] Seer marked status applies every 5th hit
- [ ] Base stats differ between classes

---

### Task 2.3: God Selection UI [Size: L]

**Files:**
- NEW: `assets/scripts/ui/god_select_panel.lua`
- MODIFY: `assets/scripts/core/main.lua` (add flow state)
- MODIFY: `assets/scripts/ui/main_menu.lua` (add entry point)

**Implementation Details:**

```lua
-- assets/scripts/ui/god_select_panel.lua
local dsl = require("ui.ui_syntax_sugar")
local ui = require("ui.ui_utils")
local Avatars = require("data.avatars")
local StarterWands = require("data.starter_wands")

local GodSelectPanel = {}

local STATE = {
    selected_god = nil,
    selected_class = nil,
}

function GodSelectPanel.create()
    local root = dsl.root {
        layout = "vertical",
        spacing = 20,
        padding = 40,
        background = "panel_dark",
        
        children = {
            -- Title
            dsl.label {
                text = "Choose Your Path",
                font_size = 32,
                color = {1, 1, 1, 1},
            },
            
            -- God Grid (2x2)
            dsl.grid {
                id = "god_grid",
                columns = 2,
                spacing = 20,
                children = GodSelectPanel.create_god_cards(),
            },
            
            -- Class Selector
            dsl.row {
                id = "class_row",
                spacing = 20,
                children = GodSelectPanel.create_class_buttons(),
            },
            
            -- Preview Panel
            dsl.panel {
                id = "preview_panel",
                width = 400,
                height = 200,
                children = {
                    dsl.label { id = "preview_title", text = "Select a god and class" },
                    dsl.row {
                        id = "preview_gear",
                        children = {},  -- Populated dynamically
                    },
                },
            },
            
            -- Confirm Button
            dsl.button {
                id = "confirm_btn",
                text = "Begin Journey",
                enabled = false,
                on_click = GodSelectPanel.on_confirm,
            },
        },
    }
    
    return root
end

function GodSelectPanel.create_god_cards()
    local cards = {}
    local gods = { "pyr", "glah", "vix", "nil_" }
    
    for _, godId in ipairs(gods) do
        local god = Avatars.gods[godId]
        local actualId = godId == "nil_" and "nil" or godId
        
        cards[#cards + 1] = dsl.button {
            id = "god_" .. actualId,
            width = 180,
            height = 220,
            
            children = {
                dsl.sprite { sprite = god.sprite, scale = 2 },
                dsl.label { text = god.name, font_size = 18 },
                dsl.label { 
                    text = god.blessing.name, 
                    font_size = 12, 
                    color = GodSelectPanel.element_color(god.element),
                },
                dsl.label { 
                    text = god.passive.description, 
                    font_size = 10,
                    wrap = true,
                    max_width = 160,
                },
            },
            
            on_click = function()
                GodSelectPanel.select_god(actualId)
            end,
        }
    end
    
    return cards
end

function GodSelectPanel.create_class_buttons()
    return {
        dsl.toggle_button {
            id = "class_channeler",
            text = "Channeler",
            group = "class",
            on_select = function() GodSelectPanel.select_class("channeler") end,
        },
        dsl.toggle_button {
            id = "class_seer",
            text = "Seer",
            group = "class",
            on_select = function() GodSelectPanel.select_class("seer") end,
        },
    }
end

function GodSelectPanel.select_god(godId)
    STATE.selected_god = godId
    GodSelectPanel.update_preview()
    GodSelectPanel.update_confirm_button()
    
    -- Visual selection feedback
    for _, g in ipairs({"pyr", "glah", "vix", "nil"}) do
        local btn = ui.find("god_" .. g)
        ui.set_selected(btn, g == godId)
    end
end

function GodSelectPanel.select_class(classId)
    STATE.selected_class = classId
    GodSelectPanel.update_preview()
    GodSelectPanel.update_confirm_button()
end

function GodSelectPanel.update_preview()
    local preview = ui.find("preview_panel")
    if not STATE.selected_god or not STATE.selected_class then
        return
    end
    
    local god = Avatars.gods[STATE.selected_god == "nil" and "nil_" or STATE.selected_god]
    local class = Avatars.classes[STATE.selected_class]
    local wand = StarterWands[class.starter_wand]
    
    -- Update preview content
    ui.set_text(ui.find("preview_title"), 
        string.format("%s %s", god.name, class.name))
    
    local gearRow = ui.find("preview_gear")
    ui.clear_children(gearRow)
    
    -- Show starter gear
    ui.add_child(gearRow, dsl.sprite_tooltip {
        sprite = wand.sprite,
        tooltip = wand.name .. ": " .. wand.description,
    })
    
    ui.add_child(gearRow, dsl.sprite_tooltip {
        sprite = "equip_" .. god.starter_equipment,
        tooltip = Equipment[god.starter_equipment].name,
    })
    
    ui.add_child(gearRow, dsl.sprite_tooltip {
        sprite = "artifact_" .. god.starter_artifact,
        tooltip = Artifacts[god.starter_artifact].name,
    })
    
    ui.box.RenewAlignment(registry, gearRow)
end

function GodSelectPanel.update_confirm_button()
    local btn = ui.find("confirm_btn")
    local canConfirm = STATE.selected_god ~= nil and STATE.selected_class ~= nil
    ui.set_enabled(btn, canConfirm)
end

function GodSelectPanel.on_confirm()
    if not STATE.selected_god or not STATE.selected_class then
        return
    end
    
    -- Apply selections to player
    local player = globals.player_entity
    
    Avatars.apply_god(player, STATE.selected_god)
    Avatars.apply_class(player, STATE.selected_class)
    
    -- Grant starter gear
    local god = Avatars.gods[STATE.selected_god == "nil" and "nil_" or STATE.selected_god]
    local class = Avatars.classes[STATE.selected_class]
    
    InventorySystem.grant_wand(player, class.starter_wand)
    InventorySystem.grant_equipment(player, god.starter_equipment)
    InventorySystem.grant_artifact(player, god.starter_artifact)
    
    -- Transition to gameplay
    signal.emit("god_selection_complete", STATE.selected_god, STATE.selected_class)
    GodSelectPanel.close()
    GameState.transition("gameplay")
end

function GodSelectPanel.element_color(element)
    local colors = {
        fire = {1, 0.4, 0.2, 1},
        ice = {0.4, 0.8, 1, 1},
        lightning = {1, 1, 0.4, 1},
        void = {0.6, 0.2, 0.8, 1},
    }
    return colors[element] or {1, 1, 1, 1}
end

return GodSelectPanel
```

**Acceptance Criteria:**
- [ ] 2×2 grid displays all 4 gods
- [ ] Class toggle buttons (Channeler/Seer)
- [ ] Preview panel shows starter gear on selection
- [ ] Confirm button disabled until both selected
- [ ] Grants correct gear on confirm
- [ ] Transitions to gameplay state

---

## Phase 3: Skills System
**Goal:** 32 skills with element lock mechanic  
**Dependencies:** Phase 2 (god/class system)

### Task 3.1: Element Lock System [Size: M]

**Files:**
- MODIFY: `assets/scripts/core/skill_system.lua`
- MODIFY: `assets/scripts/ui/skills_panel.lua`

**Implementation Details:**

```lua
-- Add to assets/scripts/core/skill_system.lua

local MAX_ELEMENTS = 3
local LOCK_THRESHOLD = 3  -- Lock triggers at 3rd skill point in an element

function SkillSystem.can_learn(player, skillId)
    local skill = Skills.get(skillId)
    if not skill then
        return false, "Skill not found"
    end
    
    local script = safe_script_get(player)
    if not script then
        return false, "Invalid player"
    end
    
    -- Check skill points
    if (script.skill_points or 0) < skill.cost then
        return false, "Not enough skill points"
    end
    
    -- Check prerequisites
    if skill.requires then
        for _, reqId in ipairs(skill.requires) do
            if not SkillSystem.has_skill(player, reqId) then
                return false, "Missing prerequisite: " .. reqId
            end
        end
    end
    
    -- Check element lock
    local element = skill.element
    script.element_investment = script.element_investment or {}
    
    if not script.element_investment[element] then
        -- New element - check if we can add more
        local elementCount = table_size(script.element_investment)
        if elementCount >= MAX_ELEMENTS then
            return false, "Element locked (max " .. MAX_ELEMENTS .. " elements)"
        end
    end
    
    return true, nil
end

function SkillSystem.learn(player, skillId)
    local canLearn, reason = SkillSystem.can_learn(player, skillId)
    if not canLearn then
        return false, reason
    end
    
    local skill = Skills.get(skillId)
    local script = safe_script_get(player)
    
    -- Deduct skill points
    script.skill_points = script.skill_points - skill.cost
    
    -- Track element investment
    local element = skill.element
    script.element_investment = script.element_investment or {}
    script.element_investment[element] = (script.element_investment[element] or 0) + skill.cost
    
    -- Check for element lock trigger
    local totalInvested = 0
    for _, points in pairs(script.element_investment) do
        totalInvested = totalInvested + points
    end
    
    if totalInvested >= LOCK_THRESHOLD and not script.elements_locked then
        script.elements_locked = true
        local lockedElements = {}
        for elem, _ in pairs(script.element_investment) do
            lockedElements[#lockedElements + 1] = elem
        end
        signal.emit("elements_locked", player, lockedElements)
    end
    
    -- Add skill to player
    script.learned_skills = script.learned_skills or {}
    script.learned_skills[skillId] = {
        id = skillId,
        level = 1,
        learned_at = os.time(),
    }
    
    -- Register skill triggers
    SkillSystem.register_triggers(player, skill)
    
    signal.emit("skill_learned", player, skillId)
    return true, nil
end

function SkillSystem.get_available_elements(player)
    local script = safe_script_get(player)
    if not script then return {} end
    
    script.element_investment = script.element_investment or {}
    
    if script.elements_locked then
        -- Return only invested elements
        local available = {}
        for elem, _ in pairs(script.element_investment) do
            available[#available + 1] = elem
        end
        return available
    else
        -- All elements still available
        return {"fire", "ice", "lightning", "void"}
    end
end

function SkillSystem.is_element_available(player, element)
    local available = SkillSystem.get_available_elements(player)
    for _, e in ipairs(available) do
        if e == element then return true end
    end
    return false
end
```

**Acceptance Criteria:**
- [ ] Max 3 elements can receive investment
- [ ] Lock triggers at 3rd skill point total
- [ ] `elements_locked` signal fires once
- [ ] Locked elements shown in UI
- [ ] Can still learn skills in invested elements after lock

**Test:**
```lua
-- Test element lock
SkillSystem.learn(player, "kindle")      -- fire, 1 point
SkillSystem.learn(player, "chill")       -- ice, 1 point  
SkillSystem.learn(player, "spark")       -- lightning, 1 point -> LOCK
assert(script.elements_locked == true)

local ok, reason = SkillSystem.can_learn(player, "doom_mark")  -- void
assert(not ok)
assert(reason:match("locked"))
```

---

### Task 3.2: Multi-Trigger Skill Logic [Size: M]

**Files:**
- MODIFY: `assets/scripts/core/skill_system.lua`

**Implementation Details:**

```lua
-- Add to skill_system.lua

local frame_events = {}
local multi_trigger_skills = {}

function SkillSystem.register_triggers(player, skill)
    if skill.triggers and #skill.triggers > 1 then
        -- Multi-trigger skill
        multi_trigger_skills[skill.id] = {
            skill = skill,
            player = player,
            triggers = skill.triggers,
        }
    elseif skill.trigger then
        -- Single trigger skill (existing logic)
        signal.on(skill.trigger, function(...)
            SkillSystem.try_execute(player, skill, {...})
        end)
    end
end

function SkillSystem.on_event(event_type, event_data)
    frame_events[#frame_events + 1] = {
        type = event_type,
        data = event_data,
        timestamp = globals.frame_number,
    }
end

function SkillSystem.end_frame()
    -- Check multi-trigger skills
    for skillId, entry in pairs(multi_trigger_skills) do
        local skill = entry.skill
        local triggers = entry.triggers
        
        -- ALL triggers must be present in this frame's events
        local all_present = true
        local matched_events = {}
        
        for _, trigger in ipairs(triggers) do
            local found = false
            for _, ev in ipairs(frame_events) do
                if ev.type == trigger then
                    found = true
                    matched_events[trigger] = ev.data
                    break
                end
            end
            if not found then
                all_present = false
                break
            end
        end
        
        if all_present then
            SkillSystem.try_execute(entry.player, skill, matched_events)
        end
    end
    
    -- Clear frame events
    frame_events = {}
end

function SkillSystem.try_execute(player, skill, event_data)
    -- Check cooldown
    local script = safe_script_get(player)
    local skillData = script.learned_skills[skill.id]
    
    if skillData.cooldown_until and skillData.cooldown_until > os.clock() then
        return false  -- On cooldown
    end
    
    -- Execute skill effect
    local success = skill.effect(player, event_data)
    
    if success ~= false and skill.cooldown then
        skillData.cooldown_until = os.clock() + skill.cooldown
    end
    
    signal.emit("skill_triggered", player, skill.id)
    return true
end

-- Hook into game loop
signal.on("frame_end", function()
    SkillSystem.end_frame()
end)

-- Register event forwarders
local TRACKED_EVENTS = {
    "on_player_hit_enemy",
    "on_fire_damage",
    "on_ice_damage", 
    "on_lightning_damage",
    "on_void_damage",
    "enemy_killed",
    "on_player_damaged",
    "on_status_applied",
}

for _, event in ipairs(TRACKED_EVENTS) do
    signal.on(event, function(...)
        SkillSystem.on_event(event, {...})
    end)
end
```

**Acceptance Criteria:**
- [ ] Single-trigger skills work as before
- [ ] Multi-trigger requires ALL triggers in same frame
- [ ] Event data from all triggers passed to effect
- [ ] Cooldowns respected
- [ ] `skill_triggered` signal fires

**Test:**
```lua
-- Test multi-trigger skill "Roil" (on_hit + on_fire_damage)
-- Both events same frame -> triggers
signal.emit("on_player_hit_enemy", player, enemy, 10)
signal.emit("on_fire_damage", enemy, 10)
SkillSystem.end_frame()
assert(roil_triggered == true)

-- Only one event -> does not trigger
signal.emit("on_player_hit_enemy", player, enemy, 10)
SkillSystem.end_frame()
assert(roil_triggered == false)
```

---

### Task 3.3: Skill Definitions (32 skills) [Size: L]

**Files:**
- MODIFY: `assets/scripts/data/skills.lua`

**This is parallelizable - each element (8 skills) can be done independently.**

**Fire Skills (8):**

```lua
-- assets/scripts/data/skills.lua

Skills.fire = {}

Skills.fire.kindle = {
    id = "kindle",
    name = "Kindle",
    element = "fire",
    cost = 1,
    trigger = "on_player_hit_enemy",
    description = "Hits apply +2 Scorch stacks",
    
    effect = function(player, data)
        local target = data[2]
        StatusEngine.apply(target, "scorch", 2)
    end,
}

Skills.fire.pyrokinesis = {
    id = "pyrokinesis",
    name = "Pyrokinesis",
    element = "fire",
    cost = 2,
    trigger = "on_player_hit_enemy",
    cooldown = 3.0,
    description = "Hits cause 30 Fire AoE explosion",
    
    effect = function(player, data)
        local target = data[2]
        local pos = Q.center(target)
        dealAoEDamage(pos, 80, 30, "fire")
        spawn_explosion_vfx(pos, "fire")
    end,
}

Skills.fire.fire_healing = {
    id = "fire_healing",
    name = "Fire Healing",
    element = "fire",
    cost = 2,
    trigger = "on_fire_damage",
    description = "Dealing Fire damage heals 3 HP",
    
    effect = function(player, data)
        healEntity(player, 3)
    end,
}

Skills.fire.combustion = {
    id = "combustion",
    name = "Combustion",
    element = "fire",
    cost = 3,
    trigger = "enemy_killed",
    description = "Killed enemies explode for Scorch × 10 damage",
    
    effect = function(player, data)
        local enemy = data[1]
        local scorchStacks = StatusEngine.get_stacks(enemy, "scorch") or 0
        if scorchStacks > 0 then
            local pos = Q.center(enemy)
            local damage = scorchStacks * 10
            dealAoEDamage(pos, 100, damage, "fire")
            spawn_explosion_vfx(pos, "combustion")
        end
    end,
}

Skills.fire.flame_familiar = {
    id = "flame_familiar",
    name = "Flame Familiar",
    element = "fire",
    cost = 3,
    trigger = "on_wave_start",
    description = "Summon a Fire Sprite ally at wave start",
    
    effect = function(player, data)
        local pos = Q.center(player)
        pos.x = pos.x + math.random(-50, 50)
        pos.y = pos.y + math.random(-50, 50)
        Summons.spawn("fire_sprite", pos, player)
    end,
}

Skills.fire.roil = {
    id = "roil",
    name = "Roil",
    element = "fire",
    cost = 3,
    triggers = {"on_player_hit_enemy", "on_fire_damage"},  -- MULTI-TRIGGER
    description = "When hitting AND dealing Fire: heal 5, +2 Inflame, take 15 self-damage",
    
    effect = function(player, data)
        healEntity(player, 5)
        StatusEngine.apply(player, "inflame", 2)
        dealDamage(player, 15, "fire", {self_inflicted = true})
    end,
}

Skills.fire.scorch_master = {
    id = "scorch_master",
    name = "Scorch Master",
    element = "fire",
    cost = 4,
    type = "passive",
    description = "Immune to Scorch. Your Scorch never decays on enemies",
    
    on_learn = function(player)
        -- Immunity
        StatusEngine.set_immunity(player, "scorch", true)
        -- Disable decay for player-applied scorch
        signal.on("status_applied", function(target, statusName, stacks, source)
            if source == player and statusName == "scorch" then
                StatusEngine.set_decay_immunity(target, "scorch", true)
            end
        end)
    end,
}

Skills.fire.fire_form = {
    id = "fire_form",
    name = "Fire Form",
    element = "fire",
    cost = 5,
    type = "threshold",
    threshold_stat = "fire_damage_dealt",
    threshold_amount = 100,
    description = "After dealing 100 Fire damage, gain Fireform for 45s",
    
    effect = function(player, data)
        StatusEngine.apply(player, "fireform", 45)
        -- Reset threshold counter
        local script = safe_script_get(player)
        script.fire_damage_dealt = 0
    end,
}
```

**Ice, Lightning, Void skills follow same pattern (see spec for full definitions)**

**Acceptance Criteria:**
- [ ] 8 Fire skills with correct triggers
- [ ] 8 Ice skills with correct triggers  
- [ ] 8 Lightning skills with correct triggers
- [ ] 8 Void skills with correct triggers
- [ ] Multi-trigger skills (Roil, Tempest, etc.) work correctly
- [ ] Threshold skills track damage and trigger forms
- [ ] Passive skills apply on learn

---

## Phase 4: Transformation Forms
**Goal:** Timed power spikes with aura effects  
**Dependencies:** Phase 3 (skills), Phase 1 (status system)

### Task 4.1: Form Status Definitions [Size: M]

**Files:**
- MODIFY: `assets/scripts/data/status_effects.lua`

**Implementation Details:**

```lua
-- Add to status_effects.lua

StatusEffects.fireform = {
    id = "fireform",
    name = "Fireform",
    type = "transformation",
    duration = 45,  -- seconds (timed, not permanent)
    
    stat_mods = {
        fire_damage = { mult = 0.30 },  -- +30% Fire damage
    },
    
    aura = {
        id = "fire_aura",
        radius = 80,
        tick_interval = 0.5,
        tick_damage = 10,
        tick_damage_type = "fire",
        tick_status = "scorch",
        tick_status_stacks = 1,
    },
    
    visuals = {
        shader = "fireform_shader",
        particles = "flame_aura",
        tint = {1.0, 0.6, 0.3, 1.0},
    },
    
    on_apply = function(entity)
        -- Start aura
        AuraSystem.add(entity, StatusEffects.fireform.aura)
        -- Apply shader
        ShaderBuilder.new(entity)
            :add("fireform_shader")
            :build()
        -- Emit particles
        ParticleSystem.attach(entity, "flame_aura")
        
        signal.emit("form_activated", entity, "fireform")
    end,
    
    on_remove = function(entity)
        AuraSystem.remove(entity, "fire_aura")
        ShaderBuilder.remove(entity, "fireform_shader")
        ParticleSystem.detach(entity, "flame_aura")
        
        signal.emit("form_expired", entity, "fireform")
    end,
}

StatusEffects.iceform = {
    id = "iceform",
    name = "Iceform",
    type = "transformation",
    duration = 60,
    
    stat_mods = {
        ice_damage = { mult = 0.30 },
        damage_taken = { mult = -0.25 },  -- -25% damage taken
    },
    
    aura = {
        id = "ice_aura",
        radius = 100,
        tick_interval = 0.5,
        tick_status = "freeze",
        tick_status_stacks = 1,
        tick_slow = 0.30,  -- 30% slow
    },
    
    visuals = {
        shader = "iceform_shader",
        particles = "frost_aura",
        tint = {0.6, 0.9, 1.0, 1.0},
    },
    
    on_apply = function(entity)
        AuraSystem.add(entity, StatusEffects.iceform.aura)
        ShaderBuilder.new(entity):add("iceform_shader"):build()
        ParticleSystem.attach(entity, "frost_aura")
        signal.emit("form_activated", entity, "iceform")
    end,
    
    on_remove = function(entity)
        AuraSystem.remove(entity, "ice_aura")
        ShaderBuilder.remove(entity, "iceform_shader")
        ParticleSystem.detach(entity, "frost_aura")
        signal.emit("form_expired", entity, "iceform")
    end,
}

StatusEffects.stormform = {
    id = "stormform",
    name = "Stormform",
    type = "transformation",
    duration = 30,
    
    stat_mods = {
        lightning_damage = { mult = 0.50 },  -- +50% Lightning
        move_speed = { mult = 0.25 },  -- +25% move speed
    },
    
    aura = {
        id = "storm_aura",
        radius = 120,
        tick_interval = 0.3,
        tick_damage = 5,
        tick_damage_type = "lightning",
        chain_count = 2,  -- Chains to nearby enemies
    },
    
    on_apply = function(entity)
        AuraSystem.add(entity, StatusEffects.stormform.aura)
        ShaderBuilder.new(entity):add("stormform_shader"):build()
        ParticleSystem.attach(entity, "lightning_aura")
        signal.emit("form_activated", entity, "stormform")
    end,
    
    on_remove = function(entity)
        AuraSystem.remove(entity, "storm_aura")
        ShaderBuilder.remove(entity, "stormform_shader")
        ParticleSystem.detach(entity, "lightning_aura")
        signal.emit("form_expired", entity, "stormform")
    end,
}

StatusEffects.voidform = {
    id = "voidform",
    name = "Voidform",
    type = "transformation",
    duration = 45,
    
    stat_mods = {
        void_damage = { mult = 0.40 },
        lifesteal = { add = 0.10 },  -- 10% lifesteal
    },
    
    aura = {
        id = "void_aura",
        radius = 90,
        tick_interval = 1.0,
        tick_status = "doom",
        tick_status_stacks = 2,
        execute_threshold = 0.15,  -- Execute enemies below 15% HP
    },
    
    on_apply = function(entity)
        AuraSystem.add(entity, StatusEffects.voidform.aura)
        ShaderBuilder.new(entity):add("voidform_shader"):build()
        ParticleSystem.attach(entity, "void_aura")
        signal.emit("form_activated", entity, "voidform")
    end,
    
    on_remove = function(entity)
        AuraSystem.remove(entity, "void_aura")
        ShaderBuilder.remove(entity, "voidform_shader")
        ParticleSystem.detach(entity, "void_aura")
        signal.emit("form_expired", entity, "voidform")
    end,
}
```

**Acceptance Criteria:**
- [ ] All 4 forms have stat modifiers
- [ ] Forms have timed duration (30-60s)
- [ ] Aura configs defined per form
- [ ] Visual effects (shader, particles, tint)
- [ ] on_apply/on_remove cleanup properly

---

### Task 4.2: Aura Tick System [Size: M]

**Files:**
- NEW: `assets/scripts/combat/aura_system.lua`

**Implementation Details:**

```lua
-- assets/scripts/combat/aura_system.lua
local AuraSystem = {}

local active_auras = {}  -- entity -> { aura_id -> aura_data }

function AuraSystem.add(entity, auraConfig)
    if not ensure_entity(entity) then return end
    
    active_auras[entity] = active_auras[entity] or {}
    active_auras[entity][auraConfig.id] = {
        config = auraConfig,
        tickTimer = 0,
        owner = entity,
    }
    
    signal.emit("aura_added", entity, auraConfig.id)
end

function AuraSystem.remove(entity, auraId)
    if active_auras[entity] then
        active_auras[entity][auraId] = nil
        if next(active_auras[entity]) == nil then
            active_auras[entity] = nil
        end
    end
    
    signal.emit("aura_removed", entity, auraId)
end

function AuraSystem.update(dt)
    local entities_to_clean = {}
    
    for entity, auras in pairs(active_auras) do
        if not ensure_entity(entity) then
            entities_to_clean[#entities_to_clean + 1] = entity
        else
            for auraId, aura in pairs(auras) do
                aura.tickTimer = aura.tickTimer + dt
                if aura.tickTimer >= aura.config.tick_interval then
                    aura.tickTimer = aura.tickTimer - aura.config.tick_interval
                    AuraSystem.tick(entity, aura.config)
                end
            end
        end
    end
    
    -- Cleanup dead entities
    for _, entity in ipairs(entities_to_clean) do
        active_auras[entity] = nil
    end
end

function AuraSystem.tick(entity, config)
    local pos = Q.center(entity)
    local radius = config.radius
    
    -- Get enemies in radius using physics query
    local enemies = AuraSystem.get_enemies_in_radius(pos, radius)
    
    for _, enemy in ipairs(enemies) do
        -- Apply damage
        if config.tick_damage then
            local damage = config.tick_damage
            dealDamage(enemy, damage, config.tick_damage_type or "magic")
            
            -- Chain lightning for stormform
            if config.chain_count and config.chain_count > 0 then
                AuraSystem.chain_damage(enemy, config, config.chain_count)
            end
        end
        
        -- Apply status
        if config.tick_status then
            StatusEngine.apply(enemy, config.tick_status, config.tick_status_stacks or 1)
        end
        
        -- Apply slow
        if config.tick_slow then
            StatusEngine.apply(enemy, "slowed", {
                duration = config.tick_interval * 1.5,
                amount = config.tick_slow,
            })
        end
        
        -- Execute threshold (voidform)
        if config.execute_threshold then
            local hp = getHealth(enemy)
            local maxHp = getMaxHealth(enemy)
            if hp / maxHp <= config.execute_threshold then
                killEntity(enemy)
                signal.emit("aura_execute", entity, enemy)
            end
        end
    end
end

function AuraSystem.chain_damage(source, config, remaining)
    if remaining <= 0 then return end
    
    local sourcePos = Q.center(source)
    local chainRange = 100
    local enemies = AuraSystem.get_enemies_in_radius(sourcePos, chainRange)
    
    local nextTarget = nil
    local minDist = math.huge
    
    for _, enemy in ipairs(enemies) do
        if enemy ~= source then
            local dist = Q.distance(sourcePos, Q.center(enemy))
            if dist < minDist then
                minDist = dist
                nextTarget = enemy
            end
        end
    end
    
    if nextTarget then
        -- Visual chain effect
        spawn_lightning_chain(sourcePos, Q.center(nextTarget))
        
        -- Chain damage (reduced)
        local chainDamage = config.tick_damage * 0.5
        dealDamage(nextTarget, chainDamage, "lightning")
        
        -- Continue chain
        Timer.after(0.05, function()
            AuraSystem.chain_damage(nextTarget, config, remaining - 1)
        end)
    end
end

function AuraSystem.get_enemies_in_radius(pos, radius)
    local enemies = {}
    local results = physics.GetObjectsInArea(world,
        pos.x - radius, pos.y - radius,
        radius * 2, radius * 2)
    
    for _, entity in ipairs(results) do
        if ensure_entity(entity) and registry:has(entity, EnemyTag) then
            local dist = Q.distance(pos, Q.center(entity))
            if dist <= radius then
                enemies[#enemies + 1] = entity
            end
        end
    end
    
    return enemies
end

-- Register with game loop
signal.on("update", function(dt)
    AuraSystem.update(dt)
end)

return AuraSystem
```

**Acceptance Criteria:**
- [ ] Auras tick at configured intervals
- [ ] Damage/status applied to enemies in radius
- [ ] Chain lightning works for stormform
- [ ] Execute threshold kills low-HP enemies
- [ ] Dead entities cleaned up automatically
- [ ] VFX spawned for aura effects

---

## Phase 5: Cards & Wands
**Goal:** Full card pool + findable wands  
**Dependencies:** Phase 1 (combat basics)

### Task 5.1: Modifier Cards (12) [Size: M]

**Files:**
- MODIFY: `assets/scripts/data/cards.lua`

**Implementation Details:**

```lua
-- Add to cards.lua - Modifier cards

Cards.MOD_CHAIN_2 = {
    id = "MOD_CHAIN_2",
    name = "Chain 2",
    type = "modifier",
    mana_cost = 8,
    icon = "card_chain",
    description = "Spell chains to 2 additional targets",
    
    modify = function(context)
        context.chain_count = (context.chain_count or 0) + 2
    end,
}

Cards.MOD_PIERCE = {
    id = "MOD_PIERCE",
    name = "Pierce",
    type = "modifier",
    mana_cost = 5,
    icon = "card_pierce",
    description = "Spell passes through 2 enemies",
    
    modify = function(context)
        context.pierce_count = (context.pierce_count or 0) + 2
    end,
}

Cards.MOD_FORK = {
    id = "MOD_FORK",
    name = "Fork",
    type = "modifier",
    mana_cost = 10,
    icon = "card_fork",
    description = "Split into 3 projectiles at half damage",
    
    modify = function(context)
        context.fork_count = 3
        context.damage = (context.damage or 0) * 0.5
    end,
}

Cards.MOD_HOMING = {
    id = "MOD_HOMING",
    name = "Homing",
    type = "modifier",
    mana_cost = 6,
    icon = "card_homing",
    description = "Projectile seeks nearest enemy",
    
    modify = function(context)
        context.homing = true
        context.homing_strength = 0.8
    end,
}

Cards.MOD_LARGER_AOE = {
    id = "MOD_LARGER_AOE",
    name = "Larger AoE",
    type = "modifier",
    mana_cost = 8,
    icon = "card_aoe_large",
    description = "AoE radius +50%",
    
    modify = function(context)
        context.aoe_radius_mult = (context.aoe_radius_mult or 1) * 1.5
    end,
}

Cards.MOD_CONCENTRATED = {
    id = "MOD_CONCENTRATED",
    name = "Concentrated",
    type = "modifier",
    mana_cost = 6,
    icon = "card_concentrated",
    description = "AoE -50%, damage +50%",
    
    modify = function(context)
        context.aoe_radius_mult = (context.aoe_radius_mult or 1) * 0.5
        context.damage = (context.damage or 0) * 1.5
    end,
}

Cards.MOD_DELAYED = {
    id = "MOD_DELAYED",
    name = "Delayed",
    type = "modifier",
    mana_cost = 5,
    icon = "card_delayed",
    description = "1s delay, +30% power",
    
    modify = function(context)
        context.delay = (context.delay or 0) + 1.0
        context.damage = (context.damage or 0) * 1.3
    end,
}

Cards.MOD_RAPID = {
    id = "MOD_RAPID",
    name = "Rapid",
    type = "modifier",
    mana_cost = 10,
    icon = "card_rapid",
    description = "Cooldowns -20%",
    
    modify = function(context)
        context.cooldown_mult = (context.cooldown_mult or 1) * 0.8
    end,
}

Cards.MOD_EMPOWERED = {
    id = "MOD_EMPOWERED",
    name = "Empowered",
    type = "modifier",
    mana_cost = 12,
    icon = "card_empowered",
    description = "+25% damage, +25% mana cost",
    
    modify = function(context)
        context.damage = (context.damage or 0) * 1.25
        context.mana_cost = (context.mana_cost or 0) * 1.25
    end,
}

Cards.MOD_EFFICIENT = {
    id = "MOD_EFFICIENT",
    name = "Efficient",
    type = "modifier",
    mana_cost = 5,
    icon = "card_efficient",
    description = "-25% mana, -15% damage",
    
    modify = function(context)
        context.mana_cost = (context.mana_cost or 0) * 0.75
        context.damage = (context.damage or 0) * 0.85
    end,
}

Cards.MOD_LINGERING = {
    id = "MOD_LINGERING",
    name = "Lingering",
    type = "modifier",
    mana_cost = 8,
    icon = "card_lingering",
    description = "DoT effects last 50% longer",
    
    modify = function(context)
        context.dot_duration_mult = (context.dot_duration_mult or 1) * 1.5
    end,
}

Cards.MOD_BRITTLE = {
    id = "MOD_BRITTLE",
    name = "Brittle",
    type = "modifier",
    mana_cost = 6,
    icon = "card_brittle",
    description = "Frozen enemies take +25% damage",
    
    modify = function(context)
        context.frozen_bonus_damage = 0.25
    end,
}
```

**Acceptance Criteria:**
- [ ] All 12 modifiers defined
- [ ] modify() functions update context correctly
- [ ] Mana costs balanced per spec
- [ ] Icons assigned

---

### Task 5.2: Action Cards (16) [Size: L]

**Files:**
- MODIFY: `assets/scripts/data/cards.lua`

**Fire Actions (4):**
```lua
Cards.ACTION_FIREBALL = {
    id = "ACTION_FIREBALL",
    name = "Fireball",
    type = "action",
    element = "fire",
    mana_cost = 15,
    damage = 25,
    damage_type = "fire",
    aoe_radius = 60,
    icon = "card_fireball",
    description = "Exploding fire projectile",
    
    execute = function(context)
        local proj = Projectiles.spawn("fireball", context)
        proj.on_hit = function(target)
            dealAoEDamage(Q.center(target), context.aoe_radius, context.damage, "fire")
            spawn_explosion_vfx(Q.center(target), "fire")
        end
    end,
}

Cards.ACTION_FLAME_LANCE = {
    id = "ACTION_FLAME_LANCE",
    name = "Flame Lance",
    type = "action",
    element = "fire",
    mana_cost = 20,
    damage = 40,
    damage_type = "fire",
    icon = "card_flame_lance",
    description = "High-damage piercing flame",
    
    execute = function(context)
        context.pierce_count = (context.pierce_count or 0) + 3
        Projectiles.spawn("flame_lance", context)
    end,
}

Cards.ACTION_SCORCH_BOLT = {
    id = "ACTION_SCORCH_BOLT",
    name = "Scorch Bolt",
    type = "action",
    element = "fire",
    mana_cost = 10,
    damage = 12,
    damage_type = "fire",
    status_apply = "scorch",
    status_stacks = 3,
    icon = "card_scorch",
    description = "Applies 3 Scorch stacks",
    
    execute = function(context)
        local proj = Projectiles.spawn("scorch_bolt", context)
        proj.on_hit = function(target)
            dealDamage(target, context.damage, "fire")
            StatusEngine.apply(target, "scorch", 3)
        end
    end,
}

Cards.ACTION_MELEE_SWING = {
    id = "ACTION_MELEE_SWING",
    name = "Melee Swing",
    type = "action",
    mana_cost = 8,
    damage = 15,
    damage_type = "physical",
    arc_angle = 90,
    range = 60,
    icon = "card_melee",
    description = "90° melee arc attack",
    
    execute = function(context)
        local MeleeArc = require("combat.melee_arc")
        return MeleeArc.execute(context.caster, context)
    end,
}
```

**Ice Actions (4):**
```lua
Cards.ACTION_ICE_SHARD = {
    id = "ACTION_ICE_SHARD",
    name = "Ice Shard",
    type = "action",
    element = "ice",
    mana_cost = 12,
    damage = 18,
    damage_type = "ice",
    status_apply = "freeze",
    status_stacks = 2,
    icon = "card_ice_shard",
    
    execute = function(context)
        local proj = Projectiles.spawn("ice_shard", context)
        proj.on_hit = function(target)
            dealDamage(target, context.damage, "ice")
            StatusEngine.apply(target, "freeze", 2)
        end
    end,
}

Cards.ACTION_FROST_NOVA = {
    id = "ACTION_FROST_NOVA",
    name = "Frost Nova",
    type = "action",
    element = "ice",
    mana_cost = 25,
    damage = 20,
    damage_type = "ice",
    aoe_radius = 100,
    icon = "card_frost_nova",
    
    execute = function(context)
        local pos = Q.center(context.caster)
        dealAoEDamage(pos, 100, 20, "ice")
        applyStatusAoE(pos, 100, "freeze", 3)
        spawn_frost_nova_vfx(pos)
    end,
}

Cards.ACTION_GLACIAL_SPIKE = {
    id = "ACTION_GLACIAL_SPIKE",
    name = "Glacial Spike",
    type = "action",
    element = "ice",
    mana_cost = 18,
    damage = 30,
    damage_type = "ice",
    icon = "card_glacial_spike",
    
    execute = function(context)
        Projectiles.spawn("glacial_spike", context)
    end,
}

Cards.ACTION_BLIZZARD = {
    id = "ACTION_BLIZZARD",
    name = "Blizzard",
    type = "action",
    element = "ice",
    mana_cost = 35,
    damage = 8,
    damage_type = "ice",
    aoe_radius = 120,
    duration = 4.0,
    tick_interval = 0.5,
    icon = "card_blizzard",
    
    execute = function(context)
        local targetPos = context.target_pos or context.aim_direction * 150 + Q.center(context.caster)
        spawn_ground_effect("blizzard", targetPos, {
            radius = 120,
            duration = 4.0,
            tick_interval = 0.5,
            tick_damage = 8,
            tick_status = "freeze",
            tick_status_stacks = 1,
        })
    end,
}
```

**Lightning Actions (4):**
```lua
Cards.ACTION_LIGHTNING_BOLT = {
    id = "ACTION_LIGHTNING_BOLT",
    name = "Lightning Bolt",
    type = "action",
    element = "lightning",
    mana_cost = 14,
    damage = 22,
    damage_type = "lightning",
    chain_count = 2,
    icon = "card_lightning_bolt",
    
    execute = function(context)
        local proj = Projectiles.spawn("lightning_bolt", context)
        proj.on_hit = function(target)
            dealDamage(target, context.damage, "lightning")
            chainLightning(target, context.chain_count, context.damage * 0.5)
        end
    end,
}

Cards.ACTION_SHOCK_WAVE = {
    id = "ACTION_SHOCK_WAVE",
    name = "Shock Wave",
    type = "action",
    element = "lightning",
    mana_cost = 20,
    damage = 15,
    damage_type = "lightning",
    width = 40,
    range = 200,
    icon = "card_shock_wave",
    
    execute = function(context)
        spawnShockWave(context.caster, context.aim_direction, {
            width = 40,
            range = 200,
            damage = 15,
            damage_type = "lightning",
        })
    end,
}

Cards.ACTION_THUNDERSTRIKE = {
    id = "ACTION_THUNDERSTRIKE",
    name = "Thunderstrike",
    type = "action",
    element = "lightning",
    mana_cost = 28,
    damage = 45,
    damage_type = "lightning",
    delay = 0.5,
    icon = "card_thunderstrike",
    
    execute = function(context)
        local targetPos = context.target_pos or context.aim_position
        -- Indicator
        spawn_lightning_indicator(targetPos, 0.5)
        Timer.after(0.5, function()
            dealAoEDamage(targetPos, 50, 45, "lightning")
            spawn_thunderstrike_vfx(targetPos)
        end)
    end,
}

Cards.ACTION_STATIC_FIELD = {
    id = "ACTION_STATIC_FIELD",
    name = "Static Field",
    type = "action",
    element = "lightning",
    mana_cost = 22,
    damage = 6,
    damage_type = "lightning",
    duration = 3.0,
    icon = "card_static_field",
    
    execute = function(context)
        spawn_ground_effect("static_field", Q.center(context.caster), {
            radius = 100,
            duration = 3.0,
            tick_interval = 0.3,
            tick_damage = 6,
            tick_status = "charge",
            tick_status_stacks = 1,
            tick_status_target = context.caster,  -- Charge goes to player
        })
    end,
}
```

**Void Actions (4):**
```lua
Cards.ACTION_VOID_BOLT = {
    id = "ACTION_VOID_BOLT",
    name = "Void Bolt",
    type = "action",
    element = "void",
    mana_cost = 16,
    damage = 20,
    damage_type = "void",
    status_apply = "doom",
    status_stacks = 2,
    icon = "card_void_bolt",
    
    execute = function(context)
        local proj = Projectiles.spawn("void_bolt", context)
        proj.on_hit = function(target)
            dealDamage(target, context.damage, "void")
            StatusEngine.apply(target, "doom", 2)
        end
    end,
}

Cards.ACTION_SOUL_DRAIN = {
    id = "ACTION_SOUL_DRAIN",
    name = "Soul Drain",
    type = "action",
    element = "void",
    mana_cost = 20,
    damage = 15,
    damage_type = "void",
    lifesteal = 1.0,  -- 100% of damage as heal
    icon = "card_soul_drain",
    
    execute = function(context)
        local proj = Projectiles.spawn("soul_drain", context)
        proj.on_hit = function(target)
            local dmg = dealDamage(target, context.damage, "void")
            healEntity(context.caster, dmg)
            spawn_lifesteal_vfx(target, context.caster)
        end
    end,
}

Cards.ACTION_DEATH_MARK = {
    id = "ACTION_DEATH_MARK",
    name = "Death Mark",
    type = "action",
    element = "void",
    mana_cost = 25,
    execute_threshold = 0.25,  -- Execute below 25% HP
    icon = "card_death_mark",
    
    execute = function(context)
        local proj = Projectiles.spawn("death_mark", context)
        proj.on_hit = function(target)
            local hp = getHealth(target)
            local maxHp = getMaxHealth(target)
            if hp / maxHp <= 0.25 then
                killEntity(target)
                signal.emit("execute_kill", context.caster, target)
            else
                dealDamage(target, 10, "void")
                StatusEngine.apply(target, "doom", 5)
            end
        end
    end,
}

Cards.ACTION_VOID_RIFT = {
    id = "ACTION_VOID_RIFT",
    name = "Void Rift",
    type = "action",
    element = "void",
    mana_cost = 30,
    damage = 10,
    damage_type = "void",
    duration = 5.0,
    pull_strength = 150,
    icon = "card_void_rift",
    
    execute = function(context)
        local targetPos = context.target_pos or context.aim_position
        spawn_ground_effect("void_rift", targetPos, {
            radius = 80,
            duration = 5.0,
            tick_interval = 0.5,
            tick_damage = 10,
            tick_status = "doom",
            tick_status_stacks = 1,
            pull_strength = 150,  -- Pulls enemies toward center
        })
    end,
}
```

**Acceptance Criteria:**
- [ ] All 16 action cards defined
- [ ] Each element has 4 unique actions
- [ ] Projectile/AoE/ground effect patterns covered
- [ ] Status applications correct

---

### Task 5.3: Findable Wands (6) [Size: M]

**Files:**
- MODIFY: `assets/scripts/core/card_eval_order_test.lua`
- MODIFY: `assets/scripts/data/shop_items.lua`

**Implementation Details:**

```lua
-- Add to WandTemplates

WandTemplates.RAGE_FIST = {
    id = "RAGE_FIST",
    name = "Rage Fist",
    description = "Triggers when you bump into enemies",
    sprite = "wand_rage_fist",
    
    trigger_type = "on_bump_enemy",
    
    mana_max = 30,
    mana_recharge_rate = 15,
    
    cast_block_size = 1,
    cast_delay = 50,
    recharge_time = 200,
    
    total_card_slots = 3,
    starting_cards = {},
    
    shop_price = 25,
    shop_tier = 2,
}

WandTemplates.STORM_WALKER = {
    id = "STORM_WALKER",
    name = "Storm Walker",
    description = "Triggers every 100 pixels traveled",
    sprite = "wand_storm_walker",
    
    trigger_type = "on_distance_traveled",
    trigger_distance = 100,
    
    mana_max = 50,
    mana_recharge_rate = 8,
    
    cast_block_size = 2,
    cast_delay = 100,
    recharge_time = 400,
    
    total_card_slots = 4,
    starting_cards = {},
    
    shop_price = 35,
    shop_tier = 2,
}

WandTemplates.FROST_ANCHOR = {
    id = "FROST_ANCHOR",
    name = "Frost Anchor",
    description = "Triggers while standing still (1s)",
    sprite = "wand_frost_anchor",
    
    trigger_type = "on_stand_still",
    trigger_duration = 1.0,
    
    mana_max = 100,
    mana_recharge_rate = 5,
    
    cast_block_size = 4,
    cast_delay = 0,
    recharge_time = 1000,
    
    total_card_slots = 6,
    starting_cards = {},
    
    shop_price = 40,
    shop_tier = 3,
}

WandTemplates.SOUL_SIPHON = {
    id = "SOUL_SIPHON",
    name = "Soul Siphon",
    description = "Triggers on enemy kill",
    sprite = "wand_soul_siphon",
    
    trigger_type = "on_enemy_killed",
    
    mana_max = 60,
    mana_recharge_rate = 0,  -- Only recharges on kill
    mana_per_kill = 20,
    
    cast_block_size = 2,
    cast_delay = 50,
    recharge_time = 100,
    
    total_card_slots = 4,
    starting_cards = {},
    
    shop_price = 30,
    shop_tier = 2,
}

WandTemplates.PAIN_ECHO = {
    id = "PAIN_ECHO",
    name = "Pain Echo",
    description = "Triggers when you take damage",
    sprite = "wand_pain_echo",
    
    trigger_type = "on_player_hit",
    
    mana_max = 40,
    mana_recharge_rate = 10,
    
    cast_block_size = 3,
    cast_delay = 0,  -- Instant response
    recharge_time = 500,
    
    total_card_slots = 5,
    starting_cards = {},
    
    shop_price = 35,
    shop_tier = 3,
}

WandTemplates.EMBER_PULSE = {
    id = "EMBER_PULSE",
    name = "Ember Pulse",
    description = "Fast auto-trigger (0.5s interval)",
    sprite = "wand_ember_pulse",
    
    trigger_type = "every_N_seconds",
    trigger_interval = 0.5,
    
    mana_max = 100,
    mana_recharge_rate = 20,
    
    cast_block_size = 1,
    cast_delay = 0,
    recharge_time = 0,
    
    total_card_slots = 2,
    starting_cards = {},
    
    shop_price = 50,
    shop_tier = 4,
}

-- Wand trigger implementations
WandTriggers = {}

WandTriggers.on_bump_enemy = {
    register = function(wand, player)
        signal.on("player_collision_enemy", function(p, enemy)
            if p == player then
                WandSystem.try_fire(wand)
            end
        end)
    end,
}

WandTriggers.on_distance_traveled = {
    register = function(wand, player)
        local distanceAccum = 0
        local lastPos = Q.center(player)
        
        Timer.every(0.05, function()
            if not ensure_entity(player) then return false end
            local currentPos = Q.center(player)
            distanceAccum = distanceAccum + Q.distance(lastPos, currentPos)
            lastPos = currentPos
            
            if distanceAccum >= wand.trigger_distance then
                distanceAccum = distanceAccum - wand.trigger_distance
                WandSystem.try_fire(wand)
            end
            return true
        end)
    end,
}

WandTriggers.on_stand_still = {
    register = function(wand, player)
        local standTimer = 0
        local lastPos = Q.center(player)
        
        Timer.every(0.1, function()
            if not ensure_entity(player) then return false end
            local currentPos = Q.center(player)
            local moved = Q.distance(lastPos, currentPos) > 1
            lastPos = currentPos
            
            if moved then
                standTimer = 0
            else
                standTimer = standTimer + 0.1
                if standTimer >= wand.trigger_duration then
                    standTimer = 0
                    WandSystem.try_fire(wand)
                end
            end
            return true
        end)
    end,
}

WandTriggers.on_enemy_killed = {
    register = function(wand, player)
        signal.on("enemy_killed", function(enemy, killer)
            if killer == player then
                wand.current_mana = math.min(wand.mana_max, 
                    wand.current_mana + (wand.mana_per_kill or 0))
                WandSystem.try_fire(wand)
            end
        end)
    end,
}

WandTriggers.on_player_hit = {
    register = function(wand, player)
        signal.on("player_damaged", function(p, damage, source)
            if p == player then
                WandSystem.try_fire(wand)
            end
        end)
    end,
}
```

**Acceptance Criteria:**
- [ ] All 6 wands defined with unique triggers
- [ ] Trigger implementations work correctly
- [ ] Shop prices set per spec (25-50g)
- [ ] Wands appear in appropriate shop tiers

---

## Phase 6: Artifacts & Equipment
**Goal:** 15 artifacts + 12 equipment pieces  
**Dependencies:** None (data-only)

### Task 6.1: Artifacts (15) [Size: M]

**Files:**
- MODIFY: `assets/scripts/data/artifacts.lua`

**Common Artifacts (5):**
```lua
Artifacts.burning_gloves = {
    id = "burning_gloves",
    name = "Burning Gloves",
    rarity = "common",
    description = "+10% Fire damage",
    icon = "artifact_burning_gloves",
    
    stat_mods = {
        fire_damage = { mult = 0.10 },
    },
}

Artifacts.frozen_heart = {
    id = "frozen_heart",
    name = "Frozen Heart",
    rarity = "common",
    description = "+10% Ice damage, -5% damage taken",
    icon = "artifact_frozen_heart",
    
    stat_mods = {
        ice_damage = { mult = 0.10 },
        damage_taken = { mult = -0.05 },
    },
}

Artifacts.rubber_boots = {
    id = "rubber_boots",
    name = "Rubber Boots",
    rarity = "common",
    description = "Immune to Lightning damage from self",
    icon = "artifact_rubber_boots",
    
    on_equip = function(player)
        StatusEngine.set_immunity(player, "self_lightning", true)
    end,
}

Artifacts.lucky_coin = {
    id = "lucky_coin",
    name = "Lucky Coin",
    rarity = "common",
    description = "+5% crit chance",
    icon = "artifact_lucky_coin",
    
    stat_mods = {
        crit_chance = { add = 5 },
    },
}

Artifacts.healing_salve = {
    id = "healing_salve",
    name = "Healing Salve",
    rarity = "common",
    description = "Regenerate 1 HP every 3s",
    icon = "artifact_healing_salve",
    
    on_equip = function(player)
        Timer.every(3.0, function()
            if ensure_entity(player) then
                healEntity(player, 1)
                return true
            end
            return false
        end)
    end,
}
```

**Uncommon Artifacts (5):**
```lua
Artifacts.scorch_ring = {
    id = "scorch_ring",
    name = "Scorch Ring",
    rarity = "uncommon",
    description = "Scorch deals +50% damage per tick",
    icon = "artifact_scorch_ring",
    
    on_equip = function(player)
        signal.on("status_tick_damage", function(target, status, baseDamage)
            if status == "scorch" then
                return baseDamage * 1.5
            end
        end)
    end,
}

Artifacts.glacial_shield = {
    id = "glacial_shield",
    name = "Glacial Shield",
    rarity = "uncommon",
    description = "When hit, 25% chance to Freeze attacker",
    icon = "artifact_glacial_shield",
    
    on_equip = function(player)
        signal.on("player_damaged", function(p, damage, source)
            if p == player and ensure_entity(source) then
                if math.random() < 0.25 then
                    StatusEngine.apply(source, "freeze", 3)
                end
            end
        end)
    end,
}

Artifacts.storm_battery = {
    id = "storm_battery",
    name = "Storm Battery",
    rarity = "uncommon",
    description = "Charge stacks grant +2% damage each (max +30%)",
    icon = "artifact_storm_battery",
    
    stat_mods = {
        charge_damage_per_stack = { add = 2 },
        charge_damage_max = { add = 30 },
    },
}

Artifacts.vampiric_pendant = {
    id = "vampiric_pendant",
    name = "Vampiric Pendant",
    rarity = "uncommon",
    description = "5% of damage dealt heals you",
    icon = "artifact_vampiric_pendant",
    
    stat_mods = {
        lifesteal = { add = 0.05 },
    },
}

Artifacts.doom_shard = {
    id = "doom_shard",
    name = "Doom Shard",
    rarity = "uncommon",
    description = "Doom instantly kills at 10 stacks",
    icon = "artifact_doom_shard",
    
    on_equip = function(player)
        signal.on("status_stack_changed", function(target, status, newStacks, oldStacks)
            if status == "doom" and newStacks >= 10 then
                killEntity(target)
                StatusEngine.remove(target, "doom")
            end
        end)
    end,
}
```

**Rare Artifacts (5):**
```lua
Artifacts.phoenix_feather = {
    id = "phoenix_feather",
    name = "Phoenix Feather",
    rarity = "rare",
    description = "Once per run: Revive with 50% HP on death",
    icon = "artifact_phoenix_feather",
    consumed = false,
    
    on_equip = function(player)
        signal.on("player_death", function(p)
            if p == player and not Artifacts.phoenix_feather.consumed then
                Artifacts.phoenix_feather.consumed = true
                local maxHp = getMaxHealth(player)
                setHealth(player, maxHp * 0.5)
                spawn_phoenix_revive_vfx(player)
                return true  -- Cancel death
            end
        end)
    end,
}

Artifacts.elemental_convergence = {
    id = "elemental_convergence",
    name = "Elemental Convergence",
    rarity = "rare",
    description = "Dealing 3+ element types in 5s grants +50% damage for 3s",
    icon = "artifact_elemental_convergence",
    
    on_equip = function(player)
        local recentElements = {}
        local buffActive = false
        
        signal.on("damage_dealt", function(target, damage, element)
            if element then
                recentElements[element] = os.clock()
            end
            
            -- Clean old entries
            local now = os.clock()
            local count = 0
            for elem, time in pairs(recentElements) do
                if now - time > 5 then
                    recentElements[elem] = nil
                else
                    count = count + 1
                end
            end
            
            if count >= 3 and not buffActive then
                buffActive = true
                StatusEngine.apply(player, "convergence_buff", 3)
                Timer.after(3, function()
                    buffActive = false
                end)
            end
        end)
    end,
}

Artifacts.berserkers_rage = {
    id = "berserkers_rage",
    name = "Berserker's Rage",
    rarity = "rare",
    description = "+1% damage per 1% missing HP",
    icon = "artifact_berserkers_rage",
    
    on_equip = function(player)
        Timer.every(0.1, function()
            if not ensure_entity(player) then return false end
            local hp = getHealth(player)
            local maxHp = getMaxHealth(player)
            local missingPercent = (1 - hp/maxHp) * 100
            local script = safe_script_get(player)
            script.berserker_bonus = missingPercent
            return true
        end)
    end,
}

Artifacts.prismatic_core = {
    id = "prismatic_core",
    name = "Prismatic Core",
    rarity = "rare",
    description = "Skills cost -1 point in your primary element",
    icon = "artifact_prismatic_core",
    
    on_equip = function(player)
        local script = safe_script_get(player)
        -- Find primary element (most invested)
        local maxInvest = 0
        local primaryElement = nil
        for elem, points in pairs(script.element_investment or {}) do
            if points > maxInvest then
                maxInvest = points
                primaryElement = elem
            end
        end
        script.skill_cost_reduction = { [primaryElement] = 1 }
    end,
}

Artifacts.chrono_lens = {
    id = "chrono_lens",
    name = "Chrono Lens",
    rarity = "rare",
    description = "Blessings cooldown 25% faster",
    icon = "artifact_chrono_lens",
    
    stat_mods = {
        blessing_cooldown = { mult = -0.25 },
    },
}
```

**Acceptance Criteria:**
- [ ] 5 common artifacts
- [ ] 5 uncommon artifacts
- [ ] 5 rare artifacts
- [ ] All stat mods and effects implemented
- [ ] Icons assigned

---

### Task 6.2: Equipment (12) [Size: M]

**Files:**
- MODIFY: `assets/scripts/data/equipment.lua`

**Chest Armor (4):**
```lua
Equipment.flame_robes = {
    id = "flame_robes",
    name = "Flame Robes",
    slot = "chest",
    description = "+15% Fire damage, +10 max HP",
    icon = "equip_flame_robes",
    
    stat_mods = {
        fire_damage = { mult = 0.15 },
        max_health = { add = 10 },
    },
}

Equipment.frost_plate = {
    id = "frost_plate",
    name = "Frost Plate",
    slot = "chest",
    description = "+15% Ice damage, +20% armor",
    icon = "equip_frost_plate",
    
    stat_mods = {
        ice_damage = { mult = 0.15 },
        armor = { mult = 0.20 },
    },
}

Equipment.storm_cloak = {
    id = "storm_cloak",
    name = "Storm Cloak",
    slot = "chest",
    description = "+15% Lightning damage, +10% move speed",
    icon = "equip_storm_cloak",
    
    stat_mods = {
        lightning_damage = { mult = 0.15 },
        move_speed = { mult = 0.10 },
    },
}

Equipment.void_vestments = {
    id = "void_vestments",
    name = "Void Vestments",
    slot = "chest",
    description = "+15% Void damage, +5% lifesteal",
    icon = "equip_void_vestments",
    
    stat_mods = {
        void_damage = { mult = 0.15 },
        lifesteal = { add = 0.05 },
    },
}
```

**Gloves (4):**
```lua
Equipment.ignition_gauntlets = {
    id = "ignition_gauntlets",
    name = "Ignition Gauntlets",
    slot = "gloves",
    description = "Melee hits apply +1 Scorch",
    icon = "equip_ignition_gauntlets",
    
    on_equip = function(player)
        signal.on("player_melee_hit", function(p, target)
            if p == player then
                StatusEngine.apply(target, "scorch", 1)
            end
        end)
    end,
}

Equipment.glacier_grips = {
    id = "glacier_grips",
    name = "Glacier Grips",
    slot = "gloves",
    description = "Ranged hits apply +1 Freeze",
    icon = "equip_glacier_grips",
    
    on_equip = function(player)
        signal.on("player_ranged_hit", function(p, target)
            if p == player then
                StatusEngine.apply(target, "freeze", 1)
            end
        end)
    end,
}

Equipment.surge_bracers = {
    id = "surge_bracers",
    name = "Surge Bracers",
    slot = "gloves",
    description = "+20% cast speed",
    icon = "equip_surge_bracers",
    
    stat_mods = {
        cast_speed = { mult = 0.20 },
    },
}

Equipment.reapers_touch = {
    id = "reapers_touch",
    name = "Reaper's Touch",
    slot = "gloves",
    description = "Hits apply +1 Doom",
    icon = "equip_reapers_touch",
    
    on_equip = function(player)
        signal.on("player_hit_enemy", function(p, target)
            if p == player then
                StatusEngine.apply(target, "doom", 1)
            end
        end)
    end,
}
```

**Boots (4):**
```lua
Equipment.ember_greaves = {
    id = "ember_greaves",
    name = "Ember Greaves",
    slot = "boots",
    description = "Leave fire trail while moving (5 damage/s)",
    icon = "equip_ember_greaves",
    
    on_equip = function(player)
        local lastTrailPos = nil
        Timer.every(0.2, function()
            if not ensure_entity(player) then return false end
            local pos = Q.center(player)
            if lastTrailPos and Q.distance(pos, lastTrailPos) > 20 then
                spawn_ground_effect("fire_trail", lastTrailPos, {
                    radius = 20,
                    duration = 2.0,
                    tick_interval = 1.0,
                    tick_damage = 5,
                    damage_type = "fire",
                })
            end
            lastTrailPos = pos
            return true
        end)
    end,
}

Equipment.frozen_treads = {
    id = "frozen_treads",
    name = "Frozen Treads",
    slot = "boots",
    description = "Nearby enemies slowed 20%",
    icon = "equip_frozen_treads",
    
    on_equip = function(player)
        Timer.every(0.5, function()
            if not ensure_entity(player) then return false end
            local pos = Q.center(player)
            local enemies = AuraSystem.get_enemies_in_radius(pos, 80)
            for _, enemy in ipairs(enemies) do
                StatusEngine.apply(enemy, "slowed", {
                    duration = 0.6,
                    amount = 0.20,
                })
            end
            return true
        end)
    end,
}

Equipment.lightning_striders = {
    id = "lightning_striders",
    name = "Lightning Striders",
    slot = "boots",
    description = "+25% move speed",
    icon = "equip_lightning_striders",
    
    stat_mods = {
        move_speed = { mult = 0.25 },
    },
}

Equipment.death_walkers = {
    id = "death_walkers",
    name = "Death Walkers",
    slot = "boots",
    description = "Walking through enemies deals 10 Void damage",
    icon = "equip_death_walkers",
    
    on_equip = function(player)
        local hitCooldowns = {}
        signal.on("player_collision_enemy", function(p, enemy)
            if p == player then
                local now = os.clock()
                if not hitCooldowns[enemy] or now - hitCooldowns[enemy] > 0.5 then
                    hitCooldowns[enemy] = now
                    dealDamage(enemy, 10, "void")
                end
            end
        end)
    end,
}
```

**Acceptance Criteria:**
- [ ] 4 chest armor pieces
- [ ] 4 gloves
- [ ] 4 boots
- [ ] All stat mods and effects work
- [ ] Equipment slot system enforced

---

## Phase 7: Economy & Progression
**Goal:** Balanced run pacing  
**Dependencies:** Phase 6 (items for shop)

### Task 7.1: Skill Point Grants [Size: S]

**Files:**
- MODIFY: `assets/scripts/core/progression.lua`
- MODIFY: `assets/scripts/core/player.lua`

**Implementation Details:**

```lua
-- assets/scripts/core/progression.lua
local Progression = {}

local SKILL_POINTS_PER_LEVEL = {
    [1] = 0,  -- Start
    [2] = 2,
    [3] = 2,
    [4] = 2,
    [5] = 2,
    [6] = 2,
}

local XP_PER_LEVEL = {
    [1] = 0,
    [2] = 100,
    [3] = 250,
    [4] = 450,
    [5] = 700,
    [6] = 1000,
}

function Progression.init(player)
    local script = safe_script_get(player)
    script.level = 1
    script.xp = 0
    script.skill_points = 0
end

function Progression.grant_xp(player, amount)
    local script = safe_script_get(player)
    script.xp = script.xp + amount
    
    -- Check for level up
    local nextLevel = script.level + 1
    local threshold = XP_PER_LEVEL[nextLevel]
    
    if threshold and script.xp >= threshold then
        Progression.level_up(player)
    end
    
    signal.emit("xp_gained", player, amount, script.xp)
end

function Progression.level_up(player)
    local script = safe_script_get(player)
    script.level = script.level + 1
    
    local pointsGained = SKILL_POINTS_PER_LEVEL[script.level] or 2
    script.skill_points = script.skill_points + pointsGained
    
    signal.emit("level_up", player, script.level, pointsGained)
    
    -- VFX
    spawn_level_up_vfx(player)
end

function Progression.get_skill_points(player)
    local script = safe_script_get(player)
    return script.skill_points or 0
end

return Progression
```

**Acceptance Criteria:**
- [ ] Players gain 2 skill points per level
- [ ] XP thresholds correct per spec
- [ ] Level up signal fires
- [ ] `level_up` VFX spawns

---

### Task 7.2: Shop Wand Integration [Size: M]

**Files:**
- MODIFY: `assets/scripts/ui/shop_panel.lua`
- MODIFY: `assets/scripts/data/shop_config.lua`

**Implementation Details:**

```lua
-- assets/scripts/data/shop_config.lua
local ShopConfig = {}

ShopConfig.stage_contents = {
    [1] = {
        equipment_slots = 3,
        wand_slots = 0,
        artifact_chance = 0,
    },
    [2] = {
        equipment_slots = 3,
        wand_slots = 1,  -- 1-2 wands
        wand_slots_max = 2,
        artifact_chance = 0,
    },
    [3] = {
        equipment_slots = 2,
        wand_slots = 1,
        artifact_chance = 0.5,  -- Elite drop
    },
    [4] = {
        equipment_slots = 2,
        wand_slots = 1,
        wand_slots_max = 2,
        artifact_chance = 1.0,
    },
    [5] = {
        -- Boss stage - no shop
        equipment_slots = 0,
        wand_slots = 0,
        artifact_chance = 0,
    },
}

ShopConfig.wand_pool = {
    [2] = {"RAGE_FIST", "SOUL_SIPHON"},
    [3] = {"STORM_WALKER", "FROST_ANCHOR", "PAIN_ECHO"},
    [4] = {"EMBER_PULSE"},
}

function ShopConfig.generate_shop(stage)
    local config = ShopConfig.stage_contents[stage]
    if not config then return {} end
    
    local items = {}
    
    -- Add equipment
    local equipPool = Equipment.get_available_pool()
    for i = 1, config.equipment_slots do
        local equip = table.remove(equipPool, math.random(#equipPool))
        if equip then
            items[#items + 1] = {
                type = "equipment",
                id = equip.id,
                price = equip.shop_price or 20,
            }
        end
    end
    
    -- Add wands (stage 2+)
    if config.wand_slots > 0 then
        local wandCount = math.random(config.wand_slots, config.wand_slots_max or config.wand_slots)
        local wandPool = {}
        for tier = 2, stage do
            for _, wandId in ipairs(ShopConfig.wand_pool[tier] or {}) do
                wandPool[#wandPool + 1] = wandId
            end
        end
        
        for i = 1, wandCount do
            if #wandPool > 0 then
                local wandId = table.remove(wandPool, math.random(#wandPool))
                local wand = WandTemplates[wandId]
                items[#items + 1] = {
                    type = "wand",
                    id = wandId,
                    price = wand.shop_price,
                }
            end
        end
    end
    
    -- Add artifact (chance-based)
    if math.random() < config.artifact_chance then
        local artifact = Artifacts.get_random_by_stage(stage)
        if artifact then
            items[#items + 1] = {
                type = "artifact",
                id = artifact.id,
                price = artifact.shop_price or 30,
            }
        end
    end
    
    return items
end

return ShopConfig
```

**Acceptance Criteria:**
- [ ] Stage 1: Equipment only
- [ ] Stage 2: Equipment + 1-2 wands
- [ ] Stage 3: Equipment + elite artifact chance
- [ ] Stage 4: Equipment + wands + guaranteed artifact
- [ ] Wand prices 25-50g range
- [ ] Wand pool expands by stage

---

## Critical Path and Dependencies

```
┌────────────────────────────────────────────────────────────────┐
│                        CRITICAL PATH                            │
│                                                                  │
│  Phase 1.1 ──┐                                                  │
│  (Melee Arc) │                                                  │
│              ├──► Phase 2.2 ──► Phase 2.3 ──► Phase 3.1        │
│  Phase 1.2 ──┤    (Classes)    (God UI)      (Element Lock)    │
│  (Decay)     │                                                  │
│              │                      │                           │
│  Phase 1.3 ──┘                      ▼                           │
│  (Wands)                       Phase 3.3                        │
│                                (32 Skills)                      │
│                                     │                           │
│                                     ▼                           │
│                               Phase 4.1-4.2                     │
│                               (Forms + Auras)                   │
│                                     │                           │
│                                     ▼                           │
│                               Phase 5.1-5.3                     │
│                               (Cards + Wands)                   │
│                                     │                           │
│                                     ▼                           │
│                                   MVP                           │
└────────────────────────────────────────────────────────────────┘

PARALLEL TRACKS:
- Phase 2.1 (God Definitions) can run parallel to Phase 1
- Phase 6.1-6.2 (Items) can run parallel to Phase 3-5
- Phase 7 can run parallel to Phase 6
- Skill definitions (3.3) can be split 4 ways by element
```

**Minimum Viable Playable:**
1. Phase 1 (Melee + Status + Starter Wands)
2. Phase 2.1-2.2 (Gods + Classes, skip UI temporarily)
3. Hardcode god/class selection for testing
4. Phase 5.2 (Action Cards - minimum set)

This gets combat loop playable with ~25% of total effort.

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Physics segment_query performance | Profile with 8 steps; reduce if needed |
| Status decay timing drift | Use accumulator pattern, not absolute time |
| Multi-trigger skill complexity | Comprehensive unit tests before integration |
| Form visual effects overwhelming | Optional particle density setting |
| 32 skills balance | Start with placeholder values, tune in playtesting |
| Shop economy broken | Log all gold gains/spends, analyze runs |

---

## Parallelization Guide

**4 parallel agent assignments:**

1. **Combat Agent**: Tasks 1.1, 1.2, 4.1, 4.2
2. **Identity Agent**: Tasks 2.1, 2.2, 2.3, 3.1
3. **Skills Agent**: Tasks 3.2, 3.3 (Fire + Ice skills)
4. **Content Agent**: Tasks 3.3 (Lightning + Void skills), 5.1, 5.2, 5.3, 6.1, 6.2

**Handoff points:**
- Combat Agent completes 1.1 → Identity Agent needs it for testing classes
- Identity Agent completes 3.1 → Skills Agent needs element lock for skill definitions
- Combat Agent completes 4.1 → Skills Agent needs forms for threshold skills

---

## Acceptance Testing Checklist

### MVP Milestone
- [ ] Channeler can melee arc, hits multiple enemies
- [ ] Seer can fire projectiles, homing works
- [ ] God passive applies element status on hit
- [ ] Class passive (Channeler proximity, Seer crit) functions
- [ ] Starter wand triggers correctly for each class
- [ ] Status stacks decay over time

### Full Demo
- [ ] All 4 gods selectable with preview
- [ ] Both classes playable with distinct feel
- [ ] Element lock activates at 3 skill points
- [ ] All 32 skills learnable and functional
- [ ] All 4 forms activate and expire correctly
- [ ] All 28+ cards function in wand evaluation
- [ ] All 8 wands acquirable and triggering
- [ ] All 15 artifacts provide correct bonuses
- [ ] All 12 equipment pieces equippable
- [ ] Shop contents scale by stage
