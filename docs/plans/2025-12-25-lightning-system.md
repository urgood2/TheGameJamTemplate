# Lightning System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Status Effects with visual indicators, Mark/Combo system, and Defensive/Counter mechanics using Chain Lightning as testbed.

**Architecture:** Three interconnected systems - StatusEffects define DoTs and marks with flat key-value configs, StatusIndicatorSystem renders visual feedback (icons + shaders + particles), and the damage pipeline checks for mark detonation triggers.

**Tech Stack:** Lua (Sol2), existing ActionAPI for combat, signal system for events, shader pipeline for visual effects.

---

## Task 1: Create Status Effects Data File

**Files:**
- Create: `assets/scripts/data/status_effects.lua`

**Step 1: Create the status effects registry**

```lua
--[[
================================================================================
STATUS EFFECTS & MARKS DEFINITIONS
================================================================================
Centralized registry for DoTs, buffs, debuffs, and detonatable marks.

Status types:
- dot_type = true: Damage over time (burn, electrocute, poison)
- is_mark = true: Detonatable mark (static_charge, exposed)
- Neither: Simple buff/debuff (slowed, stunned)

Trigger options for marks:
- "lightning", "fire", etc.: Damage type triggers detonation
- "any": Any damage triggers detonation
- "on_damaged": Triggers when THIS entity takes damage (defensive marks)
- { "fire", "lightning" }: Array of damage types
- function(hit): Custom function returning true to detonate
]]

local Particles = require("core.particles")

local StatusEffects = {}

--------------------------------------------------------------------------------
-- DOT STATUS EFFECTS
--------------------------------------------------------------------------------

StatusEffects.electrocute = {
    id = "electrocute",
    dot_type = true,

    -- Visual indicator
    icon = "status-electrocute.png",
    icon_position = "above",
    icon_offset = { x = 0, y = -12 },
    icon_scale = 0.5,
    icon_bob = true,

    -- Shader effect on entity
    shader = "electric_crackle",
    shader_uniforms = { intensity = 0.6 },

    -- Looping particles
    particles = function()
        return Particles.define()
            :shape("line")
            :size(2, 4)
            :color("cyan", "white")
            :velocity(30, 60)
            :lifespan(0.15, 0.25)
            :fade()
    end,
    particle_rate = 0.1,
    particle_orbit = true,
}

StatusEffects.burning = {
    id = "burning",
    dot_type = true,
    icon = "status-burn.png",
    icon_position = "above",
    shader = "fire_tint",
    shader_uniforms = { intensity = 0.4 },
}

StatusEffects.frozen = {
    id = "frozen",
    dot_type = false,
    icon = "status-frozen.png",
    icon_position = "above",
    shader = "ice_tint",
    shader_uniforms = { intensity = 0.7 },
}

--------------------------------------------------------------------------------
-- DETONATABLE MARKS
--------------------------------------------------------------------------------

StatusEffects.static_charge = {
    id = "static_charge",
    is_mark = true,

    -- What triggers detonation
    trigger = "lightning",

    -- Passive effects while marked
    vulnerable = 15,              -- +15% damage taken

    -- Effects on detonation
    damage = 25,                  -- Bonus damage per stack
    chain = 150,                  -- Chain to other marked enemies in range

    -- Meta
    max_stacks = 3,
    duration = 8,

    -- Visual
    icon = "mark-static-charge.png",
    icon_position = "above",
    show_stacks = true,
    shader = "static_buildup",
    shader_uniforms_per_stack = {
        { intensity = 0.2 },
        { intensity = 0.4 },
        { intensity = 0.7 },
    },
}

StatusEffects.exposed = {
    id = "exposed",
    is_mark = true,
    trigger = "any",
    vulnerable = 30,
    duration = 5,
    max_stacks = 1,
    icon = "mark-exposed.png",
    icon_position = "above",
}

StatusEffects.heat_buildup = {
    id = "heat_buildup",
    is_mark = true,
    trigger = "ice",
    vulnerable = 25,
    damage = 40,
    radius = 60,
    duration = 6,
    max_stacks = 1,
    icon = "mark-heat.png",
    icon_position = "above",
}

StatusEffects.oil_slick = {
    id = "oil_slick",
    is_mark = true,
    trigger = "fire",
    slow = 40,
    damage = 50,
    apply = "burning",
    radius = 80,
    duration = 10,
    max_stacks = 1,
    icon = "mark-oil.png",
    icon_position = "above",
}

--------------------------------------------------------------------------------
-- DEFENSIVE MARKS (trigger on_damaged)
--------------------------------------------------------------------------------

StatusEffects.static_shield = {
    id = "static_shield",
    is_mark = true,
    trigger = "on_damaged",

    -- Passive while active
    block = 15,

    -- On trigger (when hit)
    damage = 25,
    chain = 120,
    apply = "static_charge",

    -- Meta
    max_stacks = 1,
    duration = 6,
    uses = 3,

    icon = "mark-static-shield.png",
    icon_position = "above",
    shader = "lightning_shield",
    shader_uniforms = { intensity = 0.5 },
}

StatusEffects.mirror_ward = {
    id = "mirror_ward",
    is_mark = true,
    trigger = "on_damaged",
    reflect = 50,
    duration = 4,
    uses = -1,
    max_stacks = 1,
    icon = "mark-mirror.png",
    icon_position = "above",
}

StatusEffects.mana_barrier = {
    id = "mana_barrier",
    is_mark = true,
    trigger = "on_damaged",
    absorb_to_mana = 0.5,
    block = 10,
    duration = 5,
    uses = -1,
    max_stacks = 1,
    icon = "mark-mana-barrier.png",
    icon_position = "above",
}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

--- Check if a status effect should be triggered by given damage
--- @param status_def table Status effect definition
--- @param damage_type string Damage type that was dealt
--- @param tags table|nil Tags from the damage source
--- @return boolean
function StatusEffects.shouldTrigger(status_def, damage_type, tags)
    local trigger = status_def.trigger
    if not trigger then return false end

    -- Function trigger
    if type(trigger) == "function" then
        return trigger({ damage_type = damage_type, tags = tags })
    end

    -- "any" trigger
    if trigger == "any" then
        return true
    end

    -- "on_damaged" triggers handled separately
    if trigger == "on_damaged" then
        return false
    end

    -- Array of damage types
    if type(trigger) == "table" then
        for _, t in ipairs(trigger) do
            if t == damage_type then return true end
        end
        return false
    end

    -- Single damage type string
    return trigger == damage_type
end

--- Check if a status is a defensive mark (triggers on_damaged)
--- @param status_def table Status effect definition
--- @return boolean
function StatusEffects.isDefensiveMark(status_def)
    return status_def.trigger == "on_damaged"
end

--- Get status effect by ID
--- @param id string Status effect ID
--- @return table|nil
function StatusEffects.get(id)
    return StatusEffects[id]
end

return StatusEffects
```

**Step 2: Verify file loads without syntax errors**

Run in game or:
```bash
cd /Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/.worktrees/lightning-system
luac -p assets/scripts/data/status_effects.lua && echo "Syntax OK"
```

Expected: `Syntax OK`

**Step 3: Commit**

```bash
git add assets/scripts/data/status_effects.lua
git commit -m "feat(status): add status effects and marks data registry"
```

---

## Task 2: Create Status Indicator System

**Files:**
- Create: `assets/scripts/systems/status_indicator_system.lua`

**Step 1: Create the indicator system**

```lua
--[[
================================================================================
STATUS INDICATOR SYSTEM
================================================================================
Renders visual feedback for status effects and marks on entities.

Features:
- Floating icon sprites above entities
- Condensed status bar when 3+ statuses active
- Shader effects on entities
- Looping particle emitters
- Stack count display on marks

Usage:
    local StatusIndicatorSystem = require("systems.status_indicator_system")
    StatusIndicatorSystem.show(entity, "electrocute", 3.0)  -- Show for 3 seconds
    StatusIndicatorSystem.hide(entity, "electrocute")       -- Manual hide
    StatusIndicatorSystem.update(dt)                        -- Call in game loop
]]

local timer = require("core.timer")
local signal = require("external.hump.signal")
local z_orders = require("core.z_orders")
local StatusEffects = require("data.status_effects")

local StatusIndicatorSystem = {
    -- { [entity_id] = { [status_id] = indicator_data } }
    active_indicators = {},

    -- Config
    MAX_FLOATING_ICONS = 2,
    ICON_BOB_SPEED = 2.0,
    ICON_BOB_AMPLITUDE = 3.0,
    BAR_ICON_SIZE = 12,
    BAR_SPACING = 2,
    BAR_OFFSET_Y = -24,
}

--- Internal: Create indicator data for a status
local function createIndicatorData(entity, status_id, duration, stacks)
    local def = StatusEffects.get(status_id)
    if not def then return nil end

    local data = {
        status_id = status_id,
        entity = entity,
        stacks = stacks or 1,
        start_time = os.clock(),
        duration = duration,
        expires_at = duration and (os.clock() + duration) or nil,
        bob_phase = math.random() * math.pi * 2,

        -- Visual entities (created lazily)
        icon_entity = nil,
        particle_timer_tag = nil,
    }

    return data
end

--- Show a status indicator on an entity
--- @param entity number Entity ID
--- @param status_id string Status effect ID
--- @param duration number|nil Duration in seconds (nil = permanent until hide)
--- @param stacks number|nil Stack count (default 1)
function StatusIndicatorSystem.show(entity, status_id, duration, stacks)
    if not entity or entity == entt_null then return end

    local def = StatusEffects.get(status_id)
    if not def then
        print("[StatusIndicator] Unknown status:", status_id)
        return
    end

    -- Initialize entity's indicator table
    if not StatusIndicatorSystem.active_indicators[entity] then
        StatusIndicatorSystem.active_indicators[entity] = {}
    end

    local indicators = StatusIndicatorSystem.active_indicators[entity]

    -- Update existing or create new
    if indicators[status_id] then
        -- Update stacks and duration
        local data = indicators[status_id]
        data.stacks = stacks or data.stacks
        if duration then
            data.expires_at = os.clock() + duration
            data.duration = duration
        end
    else
        -- Create new indicator
        indicators[status_id] = createIndicatorData(entity, status_id, duration, stacks)

        -- Apply shader if defined
        if def.shader then
            StatusIndicatorSystem.applyShader(entity, status_id, def, stacks or 1)
        end

        -- Start particles if defined
        if def.particles then
            StatusIndicatorSystem.startParticles(entity, status_id, def)
        end
    end

    -- Update display mode (floating vs bar)
    StatusIndicatorSystem.updateDisplayMode(entity)
end

--- Hide a status indicator
--- @param entity number Entity ID
--- @param status_id string Status effect ID
function StatusIndicatorSystem.hide(entity, status_id)
    if not StatusIndicatorSystem.active_indicators[entity] then return end

    local indicators = StatusIndicatorSystem.active_indicators[entity]
    local data = indicators[status_id]

    if data then
        -- Cleanup icon entity
        if data.icon_entity and registry:valid(data.icon_entity) then
            registry:destroy(data.icon_entity)
        end

        -- Stop particles
        if data.particle_timer_tag then
            timer.cancel(data.particle_timer_tag)
        end

        -- Remove shader
        local def = StatusEffects.get(status_id)
        if def and def.shader then
            StatusIndicatorSystem.removeShader(entity, status_id)
        end

        indicators[status_id] = nil
    end

    -- Update display mode
    StatusIndicatorSystem.updateDisplayMode(entity)

    -- Cleanup empty entity entry
    if next(indicators) == nil then
        StatusIndicatorSystem.active_indicators[entity] = nil
    end
end

--- Hide all indicators for an entity
--- @param entity number Entity ID
function StatusIndicatorSystem.hideAll(entity)
    if not StatusIndicatorSystem.active_indicators[entity] then return end

    for status_id, _ in pairs(StatusIndicatorSystem.active_indicators[entity]) do
        StatusIndicatorSystem.hide(entity, status_id)
    end
end

--- Update stack count for an indicator
--- @param entity number Entity ID
--- @param status_id string Status effect ID
--- @param stacks number New stack count
function StatusIndicatorSystem.setStacks(entity, status_id, stacks)
    if not StatusIndicatorSystem.active_indicators[entity] then return end

    local data = StatusIndicatorSystem.active_indicators[entity][status_id]
    if data then
        data.stacks = stacks
        local def = StatusEffects.get(status_id)
        if def and def.shader_uniforms_per_stack then
            StatusIndicatorSystem.updateShaderForStacks(entity, status_id, def, stacks)
        end
    end
end

--- Get current stacks for a status on entity
--- @param entity number Entity ID
--- @param status_id string Status effect ID
--- @return number Stack count (0 if not present)
function StatusIndicatorSystem.getStacks(entity, status_id)
    if not StatusIndicatorSystem.active_indicators[entity] then return 0 end
    local data = StatusIndicatorSystem.active_indicators[entity][status_id]
    return data and data.stacks or 0
end

--- Check if entity has a specific status
--- @param entity number Entity ID
--- @param status_id string Status effect ID
--- @return boolean
function StatusIndicatorSystem.hasStatus(entity, status_id)
    if not StatusIndicatorSystem.active_indicators[entity] then return false end
    return StatusIndicatorSystem.active_indicators[entity][status_id] ~= nil
end

--- Get all active statuses on entity
--- @param entity number Entity ID
--- @return table Array of status IDs
function StatusIndicatorSystem.getStatuses(entity)
    local result = {}
    if StatusIndicatorSystem.active_indicators[entity] then
        for status_id, _ in pairs(StatusIndicatorSystem.active_indicators[entity]) do
            table.insert(result, status_id)
        end
    end
    return result
end

--- Update display mode based on status count
--- @param entity number Entity ID
function StatusIndicatorSystem.updateDisplayMode(entity)
    if not StatusIndicatorSystem.active_indicators[entity] then return end

    local indicators = StatusIndicatorSystem.active_indicators[entity]
    local count = 0
    for _ in pairs(indicators) do count = count + 1 end

    if count <= StatusIndicatorSystem.MAX_FLOATING_ICONS then
        StatusIndicatorSystem.showFloatingIcons(entity, indicators)
    else
        StatusIndicatorSystem.showStatusBar(entity, indicators)
    end
end

--- Show floating icons (1-2 statuses)
function StatusIndicatorSystem.showFloatingIcons(entity, indicators)
    -- TODO: Implement floating icon rendering
    -- This will create/update icon entities positioned above the target entity
end

--- Show condensed status bar (3+ statuses)
function StatusIndicatorSystem.showStatusBar(entity, indicators)
    -- TODO: Implement status bar rendering
    -- This will render a horizontal strip of mini-icons
end

--- Apply shader effect to entity
function StatusIndicatorSystem.applyShader(entity, status_id, def, stacks)
    -- TODO: Integrate with ShaderBuilder
    -- ShaderBuilder.for_entity(entity):add(def.shader, def.shader_uniforms):apply()
end

--- Remove shader effect from entity
function StatusIndicatorSystem.removeShader(entity, status_id)
    -- TODO: Remove shader from entity's shader stack
end

--- Update shader uniforms based on stacks
function StatusIndicatorSystem.updateShaderForStacks(entity, status_id, def, stacks)
    local uniforms = def.shader_uniforms_per_stack
    if uniforms then
        local idx = math.min(stacks, #uniforms)
        -- TODO: Update shader uniforms
    end
end

--- Start particle emitter for status
function StatusIndicatorSystem.startParticles(entity, status_id, def)
    if not def.particles then return end

    local tag = string.format("status_particles_%d_%s", entity, status_id)
    local rate = def.particle_rate or 0.1

    timer.every(rate, function()
        if not StatusIndicatorSystem.hasStatus(entity, status_id) then
            return false  -- Stop timer
        end

        local transform = component_cache.get(entity, Transform)
        if not transform then return end

        local cx = transform.actualX + (transform.actualW or 0) * 0.5
        local cy = transform.actualY + (transform.actualH or 0) * 0.5

        local particleDef = def.particles()
        if def.particle_orbit then
            -- Spawn in orbit pattern
            local angle = os.clock() * 3 + math.random() * 0.5
            local radius = 20
            particleDef:at(cx + math.cos(angle) * radius, cy + math.sin(angle) * radius)
        else
            particleDef:at(cx, cy)
        end
        particleDef:spawn()
    end, -1, false, nil, tag)

    -- Store tag for cleanup
    local data = StatusIndicatorSystem.active_indicators[entity][status_id]
    if data then
        data.particle_timer_tag = tag
    end
end

--- Main update function - call in game loop
--- @param dt number Delta time
function StatusIndicatorSystem.update(dt)
    local now = os.clock()
    local to_remove = {}

    for entity, indicators in pairs(StatusIndicatorSystem.active_indicators) do
        -- Check if entity still exists
        if not registry:valid(entity) then
            table.insert(to_remove, { entity = entity })
        else
            for status_id, data in pairs(indicators) do
                -- Check expiration
                if data.expires_at and now >= data.expires_at then
                    table.insert(to_remove, { entity = entity, status_id = status_id })
                else
                    -- Update bob animation
                    data.bob_phase = data.bob_phase + dt * StatusIndicatorSystem.ICON_BOB_SPEED
                end
            end
        end
    end

    -- Process removals
    for _, removal in ipairs(to_remove) do
        if removal.status_id then
            StatusIndicatorSystem.hide(removal.entity, removal.status_id)
        else
            StatusIndicatorSystem.hideAll(removal.entity)
        end
    end
end

--- Cleanup all indicators (call on scene unload)
function StatusIndicatorSystem.cleanup()
    for entity, _ in pairs(StatusIndicatorSystem.active_indicators) do
        StatusIndicatorSystem.hideAll(entity)
    end
    StatusIndicatorSystem.active_indicators = {}
end

-- Register for entity destruction events
signal.register("entity_destroyed", function(entity)
    StatusIndicatorSystem.hideAll(entity)
end)

return StatusIndicatorSystem
```

**Step 2: Verify syntax**

```bash
luac -p assets/scripts/systems/status_indicator_system.lua && echo "Syntax OK"
```

**Step 3: Commit**

```bash
git add assets/scripts/systems/status_indicator_system.lua
git commit -m "feat(status): add status indicator system for visual feedback"
```

---

## Task 3: Create Mark System

**Files:**
- Create: `assets/scripts/systems/mark_system.lua`

**Step 1: Create the mark system**

```lua
--[[
================================================================================
MARK SYSTEM
================================================================================
Manages detonatable marks on entities - the "setup + payoff" combo system.

Marks are applied via cards/abilities and detonated when specific damage types hit.

Usage:
    local MarkSystem = require("systems.mark_system")
    MarkSystem.apply(entity, "static_charge", { stacks = 1, duration = 8 })
    local result = MarkSystem.checkDetonation(entity, "lightning", damage, source)
    -- result.bonus_damage, result.effects, etc.
]]

local signal = require("external.hump.signal")
local StatusEffects = require("data.status_effects")
local StatusIndicatorSystem = require("systems.status_indicator_system")

local MarkSystem = {
    -- { [entity_id] = { [mark_id] = mark_data } }
    active_marks = {},
}

--- Apply a mark to an entity
--- @param entity number Target entity ID
--- @param mark_id string Mark ID (from status_effects.lua)
--- @param opts table|nil { stacks = 1, duration = nil, source = nil }
--- @return boolean Success
function MarkSystem.apply(entity, mark_id, opts)
    opts = opts or {}
    local def = StatusEffects.get(mark_id)

    if not def or not def.is_mark then
        print("[MarkSystem] Not a valid mark:", mark_id)
        return false
    end

    if not entity or entity == entt_null or not registry:valid(entity) then
        return false
    end

    -- Initialize entity's mark table
    if not MarkSystem.active_marks[entity] then
        MarkSystem.active_marks[entity] = {}
    end

    local marks = MarkSystem.active_marks[entity]
    local stacks = opts.stacks or 1
    local duration = opts.duration or def.duration
    local max_stacks = def.max_stacks or 1

    if marks[mark_id] then
        -- Add stacks (up to max)
        local current = marks[mark_id]
        current.stacks = math.min(current.stacks + stacks, max_stacks)
        current.expires_at = duration and (os.clock() + duration) or nil
        current.uses = def.uses or -1

        -- Update indicator
        StatusIndicatorSystem.setStacks(entity, mark_id, current.stacks)
    else
        -- Create new mark
        marks[mark_id] = {
            mark_id = mark_id,
            stacks = math.min(stacks, max_stacks),
            source = opts.source,
            expires_at = duration and (os.clock() + duration) or nil,
            uses = def.uses or -1,
        }

        -- Show indicator
        StatusIndicatorSystem.show(entity, mark_id, duration, marks[mark_id].stacks)
    end

    signal.emit("mark_applied", entity, mark_id, marks[mark_id].stacks)
    return true
end

--- Remove a mark from an entity
--- @param entity number Target entity ID
--- @param mark_id string Mark ID
function MarkSystem.remove(entity, mark_id)
    if not MarkSystem.active_marks[entity] then return end

    if MarkSystem.active_marks[entity][mark_id] then
        MarkSystem.active_marks[entity][mark_id] = nil
        StatusIndicatorSystem.hide(entity, mark_id)
        signal.emit("mark_removed", entity, mark_id)
    end

    -- Cleanup empty
    if next(MarkSystem.active_marks[entity]) == nil then
        MarkSystem.active_marks[entity] = nil
    end
end

--- Remove all marks from an entity
--- @param entity number Target entity ID
function MarkSystem.removeAll(entity)
    if not MarkSystem.active_marks[entity] then return end

    for mark_id, _ in pairs(MarkSystem.active_marks[entity]) do
        StatusIndicatorSystem.hide(entity, mark_id)
        signal.emit("mark_removed", entity, mark_id)
    end

    MarkSystem.active_marks[entity] = nil
end

--- Check if entity has a specific mark
--- @param entity number Target entity ID
--- @param mark_id string Mark ID
--- @return boolean
function MarkSystem.has(entity, mark_id)
    if not MarkSystem.active_marks[entity] then return false end
    return MarkSystem.active_marks[entity][mark_id] ~= nil
end

--- Get stacks of a mark on entity
--- @param entity number Target entity ID
--- @param mark_id string Mark ID
--- @return number Stack count (0 if not present)
function MarkSystem.getStacks(entity, mark_id)
    if not MarkSystem.active_marks[entity] then return 0 end
    local data = MarkSystem.active_marks[entity][mark_id]
    return data and data.stacks or 0
end

--- Get all marks on an entity
--- @param entity number Target entity ID
--- @return table { [mark_id] = { stacks, source, ... } }
function MarkSystem.getAll(entity)
    return MarkSystem.active_marks[entity] or {}
end

--- Check and process mark detonation when damage is dealt
--- @param entity number Target entity that was hit
--- @param damage_type string Type of damage dealt
--- @param base_damage number Original damage amount
--- @param source number|nil Source entity
--- @param tags table|nil Tags from damage source
--- @return table { bonus_damage, effects, detonated_marks }
function MarkSystem.checkDetonation(entity, damage_type, base_damage, source, tags)
    local result = {
        bonus_damage = 0,
        damage_mult = 1.0,
        effects = {},
        detonated_marks = {},
    }

    if not MarkSystem.active_marks[entity] then
        return result
    end

    local marks = MarkSystem.active_marks[entity]
    local to_consume = {}

    for mark_id, mark_data in pairs(marks) do
        local def = StatusEffects.get(mark_id)
        if def and StatusEffects.shouldTrigger(def, damage_type, tags) then
            local stacks = mark_data.stacks

            -- Apply vulnerable (damage taken multiplier)
            if def.vulnerable then
                result.damage_mult = result.damage_mult * (1 + def.vulnerable / 100)
            end

            -- Apply bonus damage
            if def.damage then
                result.bonus_damage = result.bonus_damage + (def.damage * stacks)
            end

            -- Collect effects to apply
            if def.stun and def.stun > 0 then
                table.insert(result.effects, { type = "stun", duration = def.stun })
            end
            if def.apply then
                table.insert(result.effects, { type = "apply_status", status = def.apply })
            end
            if def.chain and def.chain > 0 then
                table.insert(result.effects, { type = "chain_to_marked", range = def.chain, mark_id = mark_id })
            end
            if def.radius and def.radius > 0 then
                table.insert(result.effects, { type = "aoe", radius = def.radius })
            end

            -- Run custom callback
            if def.on_pop then
                local custom_result = def.on_pop(entity, stacks, source, {
                    damage_type = damage_type,
                    base_damage = base_damage,
                    tags = tags,
                })
                if custom_result then
                    if custom_result.bonus_damage then
                        result.bonus_damage = result.bonus_damage + custom_result.bonus_damage
                    end
                    if custom_result.effects then
                        for _, eff in ipairs(custom_result.effects) do
                            table.insert(result.effects, eff)
                        end
                    end
                end
            end

            -- Track detonation
            table.insert(result.detonated_marks, { mark_id = mark_id, stacks = stacks })

            -- Handle uses
            if mark_data.uses > 0 then
                mark_data.uses = mark_data.uses - 1
                if mark_data.uses <= 0 then
                    table.insert(to_consume, mark_id)
                end
            elseif mark_data.uses == -1 then
                -- Unlimited uses, don't consume
            else
                -- uses == 0 means consume on first trigger
                table.insert(to_consume, mark_id)
            end

            signal.emit("mark_detonated", entity, mark_id, stacks, source)
        end
    end

    -- Consume marks that should be removed
    for _, mark_id in ipairs(to_consume) do
        MarkSystem.remove(entity, mark_id)
    end

    return result
end

--- Check and process defensive marks when entity takes damage
--- @param entity number Entity that was damaged
--- @param damage_type string Type of damage taken
--- @param incoming_damage number Damage amount before mitigation
--- @param attacker number|nil Attacker entity
--- @return table { block, reflect, counter_damage, effects }
function MarkSystem.checkDefensiveMarks(entity, damage_type, incoming_damage, attacker)
    local result = {
        block = 0,
        reflect = 0,
        counter_damage = 0,
        absorb_to_mana = 0,
        effects = {},
    }

    if not MarkSystem.active_marks[entity] then
        return result
    end

    local marks = MarkSystem.active_marks[entity]
    local to_consume = {}

    for mark_id, mark_data in pairs(marks) do
        local def = StatusEffects.get(mark_id)
        if def and StatusEffects.isDefensiveMark(def) then
            local stacks = mark_data.stacks

            -- Block damage
            if def.block then
                result.block = result.block + def.block
            end

            -- Reflect damage
            if def.reflect then
                result.reflect = result.reflect + (incoming_damage * def.reflect / 100)
            end

            -- Counter-attack damage
            if def.damage then
                result.counter_damage = result.counter_damage + (def.damage * stacks)
            end

            -- Absorb to mana
            if def.absorb_to_mana then
                result.absorb_to_mana = result.absorb_to_mana + def.absorb_to_mana
            end

            -- Chain counter
            if def.chain and def.chain > 0 then
                table.insert(result.effects, { type = "chain", range = def.chain, damage = def.damage or 0 })
            end

            -- Apply mark to attacker
            if def.apply and attacker then
                table.insert(result.effects, { type = "apply_to_attacker", status = def.apply, target = attacker })
            end

            -- Handle uses
            if mark_data.uses > 0 then
                mark_data.uses = mark_data.uses - 1
                StatusIndicatorSystem.show(entity, mark_id, nil, mark_data.uses)  -- Update visual
                if mark_data.uses <= 0 then
                    table.insert(to_consume, mark_id)
                end
            end

            signal.emit("defensive_mark_triggered", entity, mark_id, stacks, attacker)
        end
    end

    -- Consume expired marks
    for _, mark_id in ipairs(to_consume) do
        MarkSystem.remove(entity, mark_id)
    end

    return result
end

--- Count total stacks of a specific mark across all enemies
--- @param mark_id string Mark ID to count
--- @return number Total stacks
function MarkSystem.countAllStacks(mark_id)
    local total = 0
    for entity, marks in pairs(MarkSystem.active_marks) do
        if marks[mark_id] then
            total = total + marks[mark_id].stacks
        end
    end
    return total
end

--- Find all entities with a specific mark in range
--- @param center_x number Center X position
--- @param center_y number Center Y position
--- @param range number Search radius
--- @param mark_id string Mark ID to find
--- @param exclude table|nil Entities to exclude
--- @return table Array of { entity, stacks, x, y, distance }
function MarkSystem.findMarkedInRange(center_x, center_y, range, mark_id, exclude)
    local results = {}
    exclude = exclude or {}

    for entity, marks in pairs(MarkSystem.active_marks) do
        if marks[mark_id] and not exclude[entity] then
            local transform = component_cache.get(entity, Transform)
            if transform then
                local ex = transform.actualX + (transform.actualW or 0) * 0.5
                local ey = transform.actualY + (transform.actualH or 0) * 0.5
                local dx, dy = ex - center_x, ey - center_y
                local dist = math.sqrt(dx * dx + dy * dy)

                if dist <= range then
                    table.insert(results, {
                        entity = entity,
                        stacks = marks[mark_id].stacks,
                        x = ex,
                        y = ey,
                        distance = dist,
                    })
                end
            end
        end
    end

    -- Sort by distance
    table.sort(results, function(a, b) return a.distance < b.distance end)
    return results
end

--- Update - check expirations
--- @param dt number Delta time
function MarkSystem.update(dt)
    local now = os.clock()
    local to_remove = {}

    for entity, marks in pairs(MarkSystem.active_marks) do
        if not registry:valid(entity) then
            table.insert(to_remove, { entity = entity })
        else
            for mark_id, data in pairs(marks) do
                if data.expires_at and now >= data.expires_at then
                    table.insert(to_remove, { entity = entity, mark_id = mark_id })
                end
            end
        end
    end

    for _, removal in ipairs(to_remove) do
        if removal.mark_id then
            MarkSystem.remove(removal.entity, removal.mark_id)
        else
            MarkSystem.removeAll(removal.entity)
        end
    end
end

--- Cleanup all marks
function MarkSystem.cleanup()
    for entity, _ in pairs(MarkSystem.active_marks) do
        MarkSystem.removeAll(entity)
    end
    MarkSystem.active_marks = {}
end

-- Register for entity destruction
signal.register("entity_destroyed", function(entity)
    MarkSystem.removeAll(entity)
end)

return MarkSystem
```

**Step 2: Verify syntax**

```bash
luac -p assets/scripts/systems/mark_system.lua && echo "Syntax OK"
```

**Step 3: Commit**

```bash
git add assets/scripts/systems/mark_system.lua
git commit -m "feat(marks): add mark system for detonatable combo mechanics"
```

---

## Task 4: Add Lightning Cards

**Files:**
- Modify: `assets/scripts/data/cards.lua`

**Step 1: Add new card definitions**

Add after the existing `Cards.ACTION_CHAIN_LIGHTNING` definition (around line 211):

```lua
-- Setup card: applies static_charge mark
Cards.ACTION_STATIC_CHARGE = {
    id = "ACTION_STATIC_CHARGE",
    type = "action",
    mana_cost = 4,
    damage = 5,
    damage_type = "lightning",
    projectile_speed = 600,
    lifetime = 1500,
    cast_delay = 80,

    -- Mark application
    apply_mark = "static_charge",
    mark_stacks = 1,

    tags = { "Lightning", "Debuff" },
    test_label = "STATIC\nCHARGE",
    sprite = "action-static-charge.png",
}

-- Defensive counter: applies shield mark to self
Cards.ACTION_STATIC_SHIELD = {
    id = "ACTION_STATIC_SHIELD",
    type = "action",
    mana_cost = 8,
    cast_delay = 50,

    -- Self-applied defensive mark
    apply_mark = "static_shield",
    apply_to_self = true,

    tags = { "Lightning", "Defense" },
    test_label = "STATIC\nSHIELD",
    sprite = "action-static-shield.png",
}
```

**Step 2: Update existing chain lightning to apply electrocute**

Find `Cards.ACTION_CHAIN_LIGHTNING` and add after `damage_type = "lightning",`:

```lua
    -- Status effect application
    apply_status = "electrocute",
    status_duration = 3,
    status_dps = 5,
```

**Step 3: Verify syntax**

```bash
luac -p assets/scripts/data/cards.lua && echo "Syntax OK"
```

**Step 4: Commit**

```bash
git add assets/scripts/data/cards.lua
git commit -m "feat(cards): add Static Charge and Static Shield lightning cards"
```

---

## Task 5: Add Lightning Jokers

**Files:**
- Modify: `assets/scripts/data/jokers.lua`

**Step 1: Add joker definitions**

Add before the closing `return Jokers`:

```lua
    --===========================================================================
    -- LIGHTNING JOKERS
    --===========================================================================

    conductor = {
        id = "conductor",
        name = "The Conductor",
        description = "Chain lightning applies Static Charge. Mark detonations chain to other marked enemies.",
        rarity = "Rare",
        sprite = "joker-conductor.png",

        calculate = function(self, context)
            -- Chain hits apply static_charge
            if context.event == "on_chain_hit" and context.damage_type == "lightning" then
                return {
                    apply_mark = { mark_id = "static_charge", stacks = 1 },
                    message = "Charged!"
                }
            end

            -- Detonations chain to other marked
            if context.event == "on_mark_detonated" then
                return {
                    chain_to_marked = { range = 200, mark_id = context.mark_id },
                    message = "Conducted!"
                }
            end
        end
    },

    storm_battery = {
        id = "storm_battery",
        name = "Storm Battery",
        description = "+5% lightning damage per Static Charge stack on any enemy.",
        rarity = "Uncommon",
        sprite = "joker-storm-battery.png",

        calculate = function(self, context)
            if context.event == "calculate_damage" and context.damage_type == "lightning" then
                local MarkSystem = require("systems.mark_system")
                local total_stacks = MarkSystem.countAllStacks("static_charge")
                if total_stacks > 0 then
                    return {
                        damage_mult = 1 + (total_stacks * 0.05),
                        message = string.format("Battery +%d%%", total_stacks * 5)
                    }
                end
            end
        end
    },

    arc_reactor = {
        id = "arc_reactor",
        name = "Arc Reactor",
        description = "Electrocute heals you for 2 HP per tick.",
        rarity = "Rare",
        sprite = "joker-arc-reactor.png",

        calculate = function(self, context)
            if context.event == "on_dot_tick" and context.dot_type == "electrocute" then
                return {
                    heal_player = 2,
                    message = "Arc Heal!"
                }
            end
        end
    },
```

**Step 2: Verify syntax**

```bash
luac -p assets/scripts/data/jokers.lua && echo "Syntax OK"
```

**Step 3: Commit**

```bash
git add assets/scripts/data/jokers.lua
git commit -m "feat(jokers): add Conductor, Storm Battery, and Arc Reactor lightning jokers"
```

---

## Task 6: Add Storm Caller Origin

**Files:**
- Modify: `assets/scripts/data/origins.lua`

**Step 1: Add origin definition**

Add before the closing `return Origins`:

```lua
    storm_caller = {
        name = "Storm Caller",
        description = "Born in the heart of the tempest.",
        tags = { "Lightning", "Arcane" },

        passive_stats = {
            lightning_modifier_pct = 15,
            chain_count_bonus = 1,
            electrocute_duration_pct = 20,
        },

        prayer = "thunderclap",

        tag_weights = {
            Lightning = 1.5,
            Arcane = 1.2,
        },

        starting_cards = {
            "ACTION_CHAIN_LIGHTNING",
            "ACTION_STATIC_CHARGE",
        },
    },
```

**Step 2: Verify syntax**

```bash
luac -p assets/scripts/data/origins.lua && echo "Syntax OK"
```

**Step 3: Commit**

```bash
git add assets/scripts/data/origins.lua
git commit -m "feat(origins): add Storm Caller lightning origin"
```

---

## Task 7: Add Thunderclap Prayer

**Files:**
- Create: `assets/scripts/data/prayers.lua` (if doesn't exist, otherwise modify)

**Step 1: Create or update prayers file**

```lua
--[[
================================================================================
PRAYER DEFINITIONS
================================================================================
Prayers are active abilities tied to Origins.
]]

local Prayers = {}

Prayers.thunderclap = {
    id = "thunderclap",
    name = "Thunderclap",
    description = "Stun all nearby enemies for 1.5s and apply Static Charge.",
    cooldown = 15,
    range = 150,

    on_cast = function(ctx, caster)
        local MarkSystem = require("systems.mark_system")
        local caster_transform = component_cache.get(caster, Transform)
        if not caster_transform then return end

        local cx = caster_transform.actualX + (caster_transform.actualW or 0) * 0.5
        local cy = caster_transform.actualY + (caster_transform.actualH or 0) * 0.5

        -- Find nearby enemies
        local nearby = findEnemiesInRange({ x = cx, y = cy }, 150, {}, 999)

        for _, info in ipairs(nearby) do
            local enemy = info.entity
            -- Apply stun
            if ActionAPI then
                ActionAPI.apply_stun(ctx, enemy, 1.5)
            end
            -- Apply static_charge mark
            MarkSystem.apply(enemy, "static_charge", { stacks = 1, source = caster })
        end

        -- Play sound
        playSoundEffect("effects", "thunderclap")

        -- Visual effect
        if particle and particle.spawnRadialBurst then
            particle.spawnRadialBurst({
                x = cx, y = cy,
                count = 20,
                color1 = "cyan",
                color2 = "white",
                speed = 200,
                lifespan = 0.3,
            })
        end
    end
}

-- Add other existing prayers here...

return Prayers
```

**Step 2: Verify syntax**

```bash
luac -p assets/scripts/data/prayers.lua && echo "Syntax OK"
```

**Step 3: Commit**

```bash
git add assets/scripts/data/prayers.lua
git commit -m "feat(prayers): add Thunderclap prayer for Storm Caller origin"
```

---

## Task 8: Enhance Stormlord Avatar

**Files:**
- Modify: `assets/scripts/data/avatars.lua`

**Step 1: Update stormlord definition**

Replace the existing `stormlord` entry:

```lua
    stormlord = {
        name = "Avatar of the Storm",
        description = "Ride the lightning.",

        unlock = {
            electrocute_kills = 50,
            OR_lightning_tags = 7,
        },

        effects = {
            {
                type = "rule_change",
                rule = "crit_chains",
                desc = "Critical hits always Chain to a nearby enemy."
            },
            {
                type = "rule_change",
                rule = "chain_applies_marks",
                desc = "All chain effects apply Static Charge."
            },
            {
                type = "stat_buff",
                stat = "chain_count_bonus",
                value = 2
            },
            {
                type = "proc",
                trigger = "on_mark_detonated",
                effect = "electrocute_nearby",
                radius = 100
            }
        }
    },
```

**Step 2: Verify syntax**

```bash
luac -p assets/scripts/data/avatars.lua && echo "Syntax OK"
```

**Step 3: Commit**

```bash
git add assets/scripts/data/avatars.lua
git commit -m "feat(avatars): enhance Stormlord with mark and chain synergies"
```

---

## Task 9: Integrate with Wand Actions

**Files:**
- Modify: `assets/scripts/wand/wand_actions.lua`

**Step 1: Add requires at top of file**

Add after existing requires (around line 10):

```lua
local StatusIndicatorSystem = require("systems.status_indicator_system")
local MarkSystem = require("systems.mark_system")
local StatusEffects = require("data.status_effects")
```

**Step 2: Integrate electrocute application in spawnChainLightning**

Find the `spawnChainLightning` function (around line 1041). After the damage is applied (around line 1128-1129), add:

```lua
                -- Apply electrocute DoT if action card specifies it
                if actionCard and actionCard.apply_status then
                    local status = actionCard.apply_status
                    local duration = actionCard.status_duration or 3
                    local dps = actionCard.status_dps or 5
                    ActionAPI.apply_dot(ctx, ownerActor, targetActor, status, dps, duration, 1.0)
                    StatusIndicatorSystem.show(targetEntity, status, duration)
                end
```

**Step 3: Integrate mark application in handleProjectileHit**

Find `handleProjectileHit` function (around line 520). After the damage section, add mark handling:

```lua
    -- Apply mark if action card specifies
    if actionCard and actionCard.apply_mark then
        local mark_id = actionCard.apply_mark
        local stacks = actionCard.mark_stacks or 1
        MarkSystem.apply(target, mark_id, { stacks = stacks, source = hitData.owner })
    end

    -- Check for mark detonation
    local damage_type = actionCard and actionCard.damage_type or "physical"
    local detonation = MarkSystem.checkDetonation(target, damage_type, hitData.damage, hitData.owner)

    -- Apply bonus damage from detonation
    if detonation.bonus_damage > 0 then
        -- Add to the damage or deal separately
        signal.emit("mark_bonus_damage", target, detonation.bonus_damage)
    end

    -- Process detonation effects
    for _, effect in ipairs(detonation.effects) do
        if effect.type == "stun" then
            local targetScript = getScriptTableFromEntityID(target)
            local targetActor = targetScript and targetScript.combatTable
            if targetActor and ActionAPI then
                ActionAPI.apply_stun(ctx, targetActor, effect.duration)
            end
        elseif effect.type == "chain_to_marked" then
            -- Find other marked enemies and chain to them
            local sourceTransform = component_cache.get(target, Transform)
            if sourceTransform then
                local sx = sourceTransform.actualX + (sourceTransform.actualW or 0) * 0.5
                local sy = sourceTransform.actualY + (sourceTransform.actualH or 0) * 0.5
                local marked = MarkSystem.findMarkedInRange(sx, sy, effect.range, effect.mark_id, { [target] = true })
                for _, m in ipairs(marked) do
                    -- Chain detonation to other marked enemies
                    MarkSystem.checkDetonation(m.entity, damage_type, hitData.damage * 0.5, hitData.owner)
                end
            end
        end
    end
```

**Step 4: Verify syntax**

```bash
luac -p assets/scripts/wand/wand_actions.lua && echo "Syntax OK"
```

**Step 5: Commit**

```bash
git add assets/scripts/wand/wand_actions.lua
git commit -m "feat(wand): integrate status indicators and mark system into projectile hits"
```

---

## Task 10: Add System Updates to Game Loop

**Files:**
- Modify: `assets/scripts/core/gameplay.lua`

**Step 1: Add requires**

Find the requires section at the top and add:

```lua
local StatusIndicatorSystem = require("systems.status_indicator_system")
local MarkSystem = require("systems.mark_system")
```

**Step 2: Add update calls**

Find the main update function (search for `function.*update.*dt`) and add:

```lua
    -- Update status indicators
    StatusIndicatorSystem.update(dt)

    -- Update mark system
    MarkSystem.update(dt)
```

**Step 3: Add cleanup on scene unload**

Find scene cleanup or destroy function and add:

```lua
    StatusIndicatorSystem.cleanup()
    MarkSystem.cleanup()
```

**Step 4: Verify syntax**

```bash
luac -p assets/scripts/core/gameplay.lua && echo "Syntax OK"
```

**Step 5: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(gameplay): add status indicator and mark system updates to game loop"
```

---

## Task 11: Create Placeholder Assets

**Files:**
- Create placeholder sprites in `assets/graphics/auto-exported-sprites-from-aseprite/`

**Step 1: Note required assets**

Create a tracking file:

```bash
cat > assets/graphics/TODO_LIGHTNING_SPRITES.md << 'EOF'
# Lightning System Required Sprites

## Status Icons (16x16 or 24x24)
- [ ] status-electrocute.png
- [ ] status-burn.png
- [ ] status-frozen.png

## Mark Icons (16x16 or 24x24)
- [ ] mark-static-charge.png
- [ ] mark-static-shield.png
- [ ] mark-exposed.png
- [ ] mark-heat.png
- [ ] mark-oil.png
- [ ] mark-mirror.png
- [ ] mark-mana-barrier.png

## Card Sprites (standard card size)
- [ ] action-static-charge.png
- [ ] action-static-shield.png

## Joker Sprites (standard joker size)
- [ ] joker-conductor.png
- [ ] joker-storm-battery.png
- [ ] joker-arc-reactor.png
EOF
```

**Step 2: Commit asset tracking**

```bash
git add assets/graphics/TODO_LIGHTNING_SPRITES.md
git commit -m "docs: add sprite asset checklist for lightning system"
```

---

## Task 12: Final Integration Test

**Step 1: Build the project**

```bash
just build-debug
```

**Step 2: Run and verify**

Launch game and test:
1. Chain lightning applies electrocute (visual indicator should appear)
2. Static Charge card applies mark
3. Lightning damage on marked enemy shows bonus damage
4. Static Shield triggers counter-attack when player hit
5. Conductor joker (if equipped) applies marks on chain hits

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat: complete lightning system with status effects, marks, and counters"
```

---

## Summary

| Task | Description | Est. Time |
|------|-------------|-----------|
| 1 | Status Effects data file | 5 min |
| 2 | Status Indicator System | 10 min |
| 3 | Mark System | 10 min |
| 4 | Lightning Cards | 3 min |
| 5 | Lightning Jokers | 5 min |
| 6 | Storm Caller Origin | 3 min |
| 7 | Thunderclap Prayer | 5 min |
| 8 | Stormlord Avatar enhancement | 3 min |
| 9 | Wand Actions integration | 10 min |
| 10 | Game loop integration | 5 min |
| 11 | Asset placeholders | 2 min |
| 12 | Integration test | 10 min |

**Total: ~70 minutes**

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
