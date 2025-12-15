# Wave System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a generic wave system with configurable stages, enemy behaviors, elite modifiers, and shop/reward transitions.

**Architecture:** StageProvider produces stage configs → WaveDirector orchestrates waves with spawn telegraphing → EnemyFactory creates enemies with timer-based behaviors. All communication via signals.

**Tech Stack:** Lua, timer system, signal (hump.signal), existing ECS/physics/animation systems.

---

## Task 1: Wave Helpers - Movement Functions

**Files:**
- Create: `assets/scripts/combat/wave_helpers.lua`

**Step 1: Create wave_helpers.lua with movement functions**

```lua
-- assets/scripts/combat/wave_helpers.lua
-- Helper functions for enemy movement, combat, and visuals

local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
local timer = require("core.timer")

local WaveHelpers = {}

--============================================
-- ENEMY CONTEXT STORAGE
--============================================

local enemy_contexts = setmetatable({}, { __mode = "k" })

function WaveHelpers.set_enemy_ctx(e, ctx)
    enemy_contexts[e] = ctx
end

function WaveHelpers.get_enemy_ctx(e)
    return enemy_contexts[e]
end

--============================================
-- MOVEMENT HELPERS
--============================================

function WaveHelpers.get_player_position()
    if not survivorEntity or not entity_cache.valid(survivorEntity) then
        return { x = 0, y = 0 }
    end
    local transform = component_cache.get(survivorEntity, Transform)
    if not transform then return { x = 0, y = 0 } end
    return { x = transform.actualX, y = transform.actualY }
end

function WaveHelpers.get_entity_position(e)
    local transform = component_cache.get(e, Transform)
    if not transform then return nil end
    return { x = transform.actualX, y = transform.actualY }
end

function WaveHelpers.move_toward_player(e, speed)
    if not entity_cache.valid(e) then return end
    local transform = component_cache.get(e, Transform)
    if not transform then return end

    local player_pos = WaveHelpers.get_player_position()
    local dx = player_pos.x - transform.actualX
    local dy = player_pos.y - transform.actualY
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > 1 then
        local dt = GetFrameTime()
        transform.actualX = transform.actualX + (dx / dist) * speed * dt
        transform.actualY = transform.actualY + (dy / dist) * speed * dt
    end
end

function WaveHelpers.flee_from_player(e, speed, min_distance)
    if not entity_cache.valid(e) then return end
    local transform = component_cache.get(e, Transform)
    if not transform then return end

    local player_pos = WaveHelpers.get_player_position()
    local dx = transform.actualX - player_pos.x
    local dy = transform.actualY - player_pos.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < min_distance and dist > 1 then
        local dt = GetFrameTime()
        transform.actualX = transform.actualX + (dx / dist) * speed * dt
        transform.actualY = transform.actualY + (dy / dist) * speed * dt
    end
end

function WaveHelpers.kite_from_player(e, speed, preferred_distance)
    if not entity_cache.valid(e) then return end
    local transform = component_cache.get(e, Transform)
    if not transform then return end

    local player_pos = WaveHelpers.get_player_position()
    local dx = transform.actualX - player_pos.x
    local dy = transform.actualY - player_pos.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < 1 then return end

    local dt = GetFrameTime()
    local tolerance = 20

    if dist < preferred_distance - tolerance then
        -- Too close, move away
        transform.actualX = transform.actualX + (dx / dist) * speed * dt
        transform.actualY = transform.actualY + (dy / dist) * speed * dt
    elseif dist > preferred_distance + tolerance then
        -- Too far, move closer
        transform.actualX = transform.actualX - (dx / dist) * speed * dt
        transform.actualY = transform.actualY - (dy / dist) * speed * dt
    end
end

-- Wander state per entity
local wander_directions = setmetatable({}, { __mode = "k" })

function WaveHelpers.wander(e, speed)
    if not entity_cache.valid(e) then return end
    local transform = component_cache.get(e, Transform)
    if not transform then return end

    -- Initialize or change direction randomly
    if not wander_directions[e] or math.random() < 0.02 then
        local angle = math.random() * math.pi * 2
        wander_directions[e] = { x = math.cos(angle), y = math.sin(angle) }
    end

    local dir = wander_directions[e]
    local dt = GetFrameTime()
    transform.actualX = transform.actualX + dir.x * speed * dt
    transform.actualY = transform.actualY + dir.y * speed * dt
end

function WaveHelpers.dash_toward_player(e, dash_speed, duration)
    if not entity_cache.valid(e) then return end
    local transform = component_cache.get(e, Transform)
    if not transform then return end

    -- Lock direction at start of dash
    local player_pos = WaveHelpers.get_player_position()
    local dx = player_pos.x - transform.actualX
    local dy = player_pos.y - transform.actualY
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < 1 then return end

    local dir_x = dx / dist
    local dir_y = dy / dist

    -- Dash over duration
    local elapsed = 0
    local tag = "dash_" .. e .. "_" .. tostring(math.random(10000))

    timer.every(0.016, function()
        if not entity_cache.valid(e) then return false end
        elapsed = elapsed + 0.016
        if elapsed >= duration then return false end

        local t = component_cache.get(e, Transform)
        if t then
            t.actualX = t.actualX + dir_x * dash_speed * 0.016
            t.actualY = t.actualY + dir_y * dash_speed * 0.016
        end
    end, tag)
end

return WaveHelpers
```

**Step 2: Verify file created**

Run: `ls -la assets/scripts/combat/wave_helpers.lua`
Expected: File exists

**Step 3: Commit**

```bash
git add assets/scripts/combat/wave_helpers.lua
git commit -m "feat(wave): add wave_helpers with movement functions"
```

---

## Task 2: Wave Helpers - Combat & Visual Functions

**Files:**
- Modify: `assets/scripts/combat/wave_helpers.lua`

**Step 1: Add combat and visual helper functions**

Append to `wave_helpers.lua` before the `return WaveHelpers`:

```lua
--============================================
-- COMBAT HELPERS
--============================================

function WaveHelpers.deal_damage_to_player(damage)
    if not survivorEntity or not entity_cache.valid(survivorEntity) then return end
    -- Route through combat system
    local signal = require("external.hump.signal")
    signal.emit("damage_player", damage)
end

function WaveHelpers.heal_enemy(e, amount)
    local ctx = WaveHelpers.get_enemy_ctx(e)
    if ctx then
        ctx.hp = math.min(ctx.hp + amount, ctx.max_hp)
    end
end

function WaveHelpers.kill_enemy(e)
    local ctx = WaveHelpers.get_enemy_ctx(e)
    if ctx then
        ctx.hp = 0
        local signal = require("external.hump.signal")
        signal.emit("on_entity_death", e, { killer = nil, damage_type = "instant", overkill = 0 })
    end
end

function WaveHelpers.get_hp_percent(e)
    local ctx = WaveHelpers.get_enemy_ctx(e)
    if ctx and ctx.max_hp > 0 then
        return ctx.hp / ctx.max_hp
    end
    return 1.0
end

function WaveHelpers.set_invulnerable(e, invulnerable)
    local ctx = WaveHelpers.get_enemy_ctx(e)
    if ctx then
        ctx.invulnerable = invulnerable
    end
end

--============================================
-- SPAWNING HELPERS
--============================================

function WaveHelpers.drop_trap(e, damage, lifetime)
    if not entity_cache.valid(e) then return end
    local pos = WaveHelpers.get_entity_position(e)
    if not pos then return end

    -- Create trap entity (simplified - expand based on your entity creation patterns)
    local signal = require("external.hump.signal")
    signal.emit("spawn_trap", { x = pos.x, y = pos.y, damage = damage, lifetime = lifetime })
end

function WaveHelpers.summon_enemies(e, enemy_type, count)
    if not entity_cache.valid(e) then return end
    local pos = WaveHelpers.get_entity_position(e)
    if not pos then return end

    local signal = require("external.hump.signal")
    for i = 1, count do
        local offset_x = (math.random() - 0.5) * 60
        local offset_y = (math.random() - 0.5) * 60
        signal.emit("summon_enemy", {
            type = enemy_type,
            x = pos.x + offset_x,
            y = pos.y + offset_y,
            summoner = e
        })
    end
end

function WaveHelpers.explode(e, radius, damage)
    local pos = WaveHelpers.get_entity_position(e)
    if not pos then return end

    local signal = require("external.hump.signal")
    signal.emit("explosion", { x = pos.x, y = pos.y, radius = radius, damage = damage, source = e })
end

--============================================
-- VISUAL HELPERS
--============================================

function WaveHelpers.spawn_telegraph(position, enemy_type, duration)
    duration = duration or 1.0
    local signal = require("external.hump.signal")
    signal.emit("spawn_telegraph", { x = position.x, y = position.y, enemy_type = enemy_type, duration = duration })
end

function WaveHelpers.show_floating_text(text, opts)
    opts = opts or {}
    local signal = require("external.hump.signal")
    signal.emit("show_floating_text", { text = text, style = opts.style, x = opts.x, y = opts.y })
end

function WaveHelpers.spawn_particles(effect_name, e_or_position)
    local pos
    if type(e_or_position) == "table" then
        pos = e_or_position
    else
        pos = WaveHelpers.get_entity_position(e_or_position)
    end
    if not pos then return end

    local signal = require("external.hump.signal")
    signal.emit("spawn_particles", { effect = effect_name, x = pos.x, y = pos.y })
end

function WaveHelpers.screen_shake(duration, intensity)
    local signal = require("external.hump.signal")
    signal.emit("screen_shake", { duration = duration, intensity = intensity })
end

--============================================
-- SHADER HELPERS
--============================================

function WaveHelpers.set_shader(e, shader_name)
    -- Use existing ShaderBuilder if available
    local ok, ShaderBuilder = pcall(require, "core.shader_builder")
    if ok and ShaderBuilder then
        ShaderBuilder.for_entity(e):add(shader_name):apply()
    end
end

function WaveHelpers.clear_shader(e, shader_name)
    local ok, ShaderBuilder = pcall(require, "core.shader_builder")
    if ok and ShaderBuilder then
        ShaderBuilder.for_entity(e):clear():apply()
    end
end

--============================================
-- SPAWN POSITION HELPERS
--============================================

function WaveHelpers.get_spawn_positions(spawn_config, count)
    local positions = {}
    local config = spawn_config

    -- Handle shorthand
    if type(spawn_config) == "string" then
        config = { type = spawn_config }
    end

    config.type = config.type or "around_player"

    local player_pos = WaveHelpers.get_player_position()

    if config.type == "around_player" then
        local min_r = config.min_radius or 150
        local max_r = config.max_radius or 250

        for i = 1, count do
            local angle = (i / count) * math.pi * 2 + math.random() * 0.5
            local radius = min_r + math.random() * (max_r - min_r)
            table.insert(positions, {
                x = player_pos.x + math.cos(angle) * radius,
                y = player_pos.y + math.sin(angle) * radius
            })
        end

    elseif config.type == "random_area" then
        local area = config.area or { x = 0, y = 0, w = 800, h = 600 }
        for i = 1, count do
            table.insert(positions, {
                x = area.x + math.random() * area.w,
                y = area.y + math.random() * area.h
            })
        end

    elseif config.type == "fixed_points" then
        local points = config.points or {}
        for i = 1, count do
            local pt = points[((i - 1) % #points) + 1] or { 0, 0 }
            table.insert(positions, { x = pt[1], y = pt[2] })
        end

    elseif config.type == "off_screen" then
        local padding = config.padding or 50
        local screen_w = globals.screenWidth or 800
        local screen_h = globals.screenHeight or 600

        for i = 1, count do
            local side = math.random(1, 4)
            local pos = { x = 0, y = 0 }
            if side == 1 then -- top
                pos.x = math.random() * screen_w
                pos.y = -padding
            elseif side == 2 then -- bottom
                pos.x = math.random() * screen_w
                pos.y = screen_h + padding
            elseif side == 3 then -- left
                pos.x = -padding
                pos.y = math.random() * screen_h
            else -- right
                pos.x = screen_w + padding
                pos.y = math.random() * screen_h
            end
            table.insert(positions, pos)
        end
    end

    return positions
end
```

**Step 2: Verify changes**

Run: `wc -l assets/scripts/combat/wave_helpers.lua`
Expected: ~300+ lines

**Step 3: Commit**

```bash
git add assets/scripts/combat/wave_helpers.lua
git commit -m "feat(wave): add combat, visual, and spawn position helpers"
```

---

## Task 3: Enemy Definitions Data File

**Files:**
- Create: `assets/scripts/data/enemies.lua`

**Step 1: Create enemies.lua with all 7 enemy types**

```lua
-- assets/scripts/data/enemies.lua
-- Enemy definitions with inline timer-based behaviors

local entity_cache = require("core.entity_cache")
local timer = require("core.timer")

local enemies = {}

--============================================
-- GOBLIN - Basic chaser
--============================================

enemies.goblin = {
    sprite = "goblin_idle",
    hp = 30,
    speed = 60,
    damage = 5,
    size = { 32, 32 },

    on_spawn = function(e, ctx, helpers)
        timer.every(0.5, function()
            if not entity_cache.valid(e) then return false end
            helpers.move_toward_player(e, ctx.speed)
        end, "enemy_" .. e)
    end,

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("enemy_death", e)
    end,
}

--============================================
-- ARCHER - Kites from player (ranged placeholder)
--============================================

enemies.archer = {
    sprite = "archer_idle",
    hp = 20,
    speed = 40,
    damage = 8,
    range = 200,
    size = { 32, 32 },

    on_spawn = function(e, ctx, helpers)
        timer.every(0.5, function()
            if not entity_cache.valid(e) then return false end
            helpers.kite_from_player(e, ctx.speed, ctx.range)
        end, "enemy_" .. e)

        -- Ranged attack placeholder (projectiles handled by parallel work)
        -- timer.every(2.0, function() ... end)
    end,

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("enemy_death", e)
    end,
}

--============================================
-- DASHER - Wanders then periodically dashes at player
--============================================

enemies.dasher = {
    sprite = "dasher_idle",
    hp = 25,
    speed = 50,
    dash_speed = 300,
    dash_cooldown = 3.0,
    damage = 12,
    size = { 32, 32 },

    on_spawn = function(e, ctx, helpers)
        -- Wander between dashes
        timer.every(0.5, function()
            if not entity_cache.valid(e) then return false end
            helpers.wander(e, ctx.speed)
        end, "enemy_" .. e)

        -- Periodic dash attack
        timer.every(ctx.dash_cooldown, function()
            if not entity_cache.valid(e) then return false end
            helpers.dash_toward_player(e, ctx.dash_speed, 0.3)
        end, "enemy_" .. e .. "_dash")
    end,

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("enemy_death", e)
    end,
}

--============================================
-- TRAPPER - Wanders and drops traps
--============================================

enemies.trapper = {
    sprite = "trapper_idle",
    hp = 35,
    speed = 30,
    trap_cooldown = 4.0,
    trap_damage = 15,
    trap_lifetime = 10.0,
    damage = 3,
    size = { 32, 32 },

    on_spawn = function(e, ctx, helpers)
        -- Slow wander
        timer.every(0.5, function()
            if not entity_cache.valid(e) then return false end
            helpers.wander(e, ctx.speed)
        end, "enemy_" .. e)

        -- Drop traps
        timer.every(ctx.trap_cooldown, function()
            if not entity_cache.valid(e) then return false end
            helpers.drop_trap(e, ctx.trap_damage, ctx.trap_lifetime)
        end, "enemy_" .. e .. "_trap")
    end,

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("enemy_death", e)
    end,
}

--============================================
-- SUMMONER - Flees and summons minions
--============================================

enemies.summoner = {
    sprite = "summoner_idle",
    hp = 50,
    speed = 25,
    summon_cooldown = 5.0,
    summon_type = "goblin",
    summon_count = 2,
    damage = 2,
    size = { 40, 40 },

    on_spawn = function(e, ctx, helpers)
        -- Flee from player
        timer.every(0.5, function()
            if not entity_cache.valid(e) then return false end
            helpers.flee_from_player(e, ctx.speed, 150)
        end, "enemy_" .. e)

        -- Summon minions
        timer.every(ctx.summon_cooldown, function()
            if not entity_cache.valid(e) then return false end
            helpers.summon_enemies(e, ctx.summon_type, ctx.summon_count)
        end, "enemy_" .. e .. "_summon")
    end,

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("summoner_death", e)
    end,
}

--============================================
-- EXPLODER - Rushes player, explodes on death/contact
--============================================

enemies.exploder = {
    sprite = "exploder_idle",
    hp = 15,
    speed = 80,
    explosion_radius = 60,
    explosion_damage = 25,
    damage = 0, -- no contact damage, only explosion
    size = { 28, 28 },

    on_spawn = function(e, ctx, helpers)
        -- Rush player
        timer.every(0.3, function()
            if not entity_cache.valid(e) then return false end
            helpers.move_toward_player(e, ctx.speed)
        end, "enemy_" .. e)
    end,

    on_death = function(e, ctx, helpers)
        helpers.explode(e, ctx.explosion_radius, ctx.explosion_damage)
        helpers.screen_shake(0.2, 5)
    end,

    on_contact_player = function(e, ctx, helpers)
        helpers.kill_enemy(e) -- triggers on_death -> explode
    end,
}

--============================================
-- WANDERER - Basic fodder, random movement only
--============================================

enemies.wanderer = {
    sprite = "wanderer_idle",
    hp = 20,
    speed = 35,
    damage = 3,
    size = { 28, 28 },

    on_spawn = function(e, ctx, helpers)
        timer.every(0.5, function()
            if not entity_cache.valid(e) then return false end
            helpers.wander(e, ctx.speed)
        end, "enemy_" .. e)
    end,

    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("enemy_death", e)
    end,
}

return enemies
```

**Step 2: Verify file created**

Run: `ls -la assets/scripts/data/enemies.lua`
Expected: File exists

**Step 3: Commit**

```bash
git add assets/scripts/data/enemies.lua
git commit -m "feat(wave): add enemy definitions with timer-based behaviors"
```

---

## Task 4: Elite Modifiers Data File

**Files:**
- Create: `assets/scripts/data/elite_modifiers.lua`

**Step 1: Create elite_modifiers.lua**

```lua
-- assets/scripts/data/elite_modifiers.lua
-- Elite modifier definitions

local entity_cache = require("core.entity_cache")
local timer = require("core.timer")

local modifiers = {}

--============================================
-- STAT MODIFIERS
--============================================

modifiers.tanky = {
    description = "Double HP, larger",
    hp_mult = 2.0,
    size_mult = 1.3,
}

modifiers.fast = {
    description = "50% faster",
    speed_mult = 1.5,
}

modifiers.deadly = {
    description = "75% more damage",
    damage_mult = 1.75,
}

modifiers.armored = {
    description = "Takes 50% less damage",
    damage_reduction = 0.5,
}

--============================================
-- BEHAVIOR MODIFIERS
--============================================

modifiers.vampiric = {
    description = "Heals on hit",
    on_apply = function(e, ctx, helpers)
        local original_on_hit_player = ctx.on_hit_player
        ctx.on_hit_player = function(e, ctx, hit_info, helpers)
            if original_on_hit_player then original_on_hit_player(e, ctx, hit_info, helpers) end
            helpers.heal_enemy(e, ctx.damage * 0.5)
            helpers.spawn_particles("vampiric_heal", e)
        end
    end,
}

modifiers.explosive_death = {
    description = "Explodes on death",
    on_apply = function(e, ctx, helpers)
        local original_on_death = ctx.on_death
        ctx.on_death = function(e, ctx, death_info, helpers)
            if original_on_death then original_on_death(e, ctx, death_info, helpers) end
            helpers.explode(e, 50, 15)
        end
    end,
}

modifiers.summoner_mod = {
    description = "Spawns minions periodically",
    on_apply = function(e, ctx, helpers)
        timer.every(6.0, function()
            if not entity_cache.valid(e) then return false end
            helpers.summon_enemies(e, "goblin", 1)
        end, "elite_" .. e .. "_summon")
    end,
}

modifiers.enraged = {
    description = "Gets faster and stronger at low HP",
    on_apply = function(e, ctx, helpers)
        local triggered = false
        timer.every(0.5, function()
            if not entity_cache.valid(e) then return false end
            if not triggered and helpers.get_hp_percent(e) < 0.3 then
                triggered = true
                ctx.speed = ctx.speed * 1.5
                ctx.damage = ctx.damage * 1.5
                helpers.set_shader(e, "rage_glow")
                helpers.spawn_particles("enrage", e)
            end
        end, "elite_" .. e .. "_enrage")
    end,
}

modifiers.shielded = {
    description = "Immune to damage for first 3 seconds",
    on_apply = function(e, ctx, helpers)
        helpers.set_invulnerable(e, true)
        helpers.set_shader(e, "shield_bubble")
        timer.after(3.0, function()
            if entity_cache.valid(e) then
                helpers.set_invulnerable(e, false)
                helpers.clear_shader(e, "shield_bubble")
            end
        end, "elite_" .. e .. "_shield")
    end,
}

modifiers.regenerating = {
    description = "Slowly regenerates health",
    on_apply = function(e, ctx, helpers)
        timer.every(1.0, function()
            if not entity_cache.valid(e) then return false end
            helpers.heal_enemy(e, ctx.max_hp * 0.02) -- 2% per second
        end, "elite_" .. e .. "_regen")
    end,
}

modifiers.teleporter = {
    description = "Occasionally teleports near player",
    on_apply = function(e, ctx, helpers)
        timer.every(5.0, function()
            if not entity_cache.valid(e) then return false end
            local player_pos = helpers.get_player_position()
            local angle = math.random() * math.pi * 2
            local dist = 80 + math.random() * 40

            local transform = require("core.component_cache").get(e, Transform)
            if transform then
                helpers.spawn_particles("teleport_out", e)
                transform.actualX = player_pos.x + math.cos(angle) * dist
                transform.actualY = player_pos.y + math.sin(angle) * dist
                helpers.spawn_particles("teleport_in", e)
            end
        end, "elite_" .. e .. "_teleport")
    end,
}

--============================================
-- MODIFIER UTILITIES
--============================================

-- Get list of all modifier names
function modifiers.get_all_names()
    local names = {}
    for name, _ in pairs(modifiers) do
        if type(modifiers[name]) == "table" and modifiers[name].description then
            table.insert(names, name)
        end
    end
    return names
end

-- Roll random modifiers
function modifiers.roll_random(count)
    local all = modifiers.get_all_names()
    local result = {}
    local used = {}

    for i = 1, math.min(count, #all) do
        local idx
        repeat
            idx = math.random(1, #all)
        until not used[idx]

        used[idx] = true
        table.insert(result, all[idx])
    end

    return result
end

return modifiers
```

**Step 2: Verify file created**

Run: `ls -la assets/scripts/data/elite_modifiers.lua`
Expected: File exists

**Step 3: Commit**

```bash
git add assets/scripts/data/elite_modifiers.lua
git commit -m "feat(wave): add elite modifier definitions"
```

---

## Task 5: Enemy Factory

**Files:**
- Create: `assets/scripts/combat/enemy_factory.lua`

**Step 1: Create enemy_factory.lua**

```lua
-- assets/scripts/combat/enemy_factory.lua
-- Creates enemies from definitions and wires up callbacks

local signal = require("external.hump.signal")
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
local timer = require("core.timer")
local animation_system = require("core.animation_system")

local WaveHelpers = require("combat.wave_helpers")
local enemies = require("data.enemies")
local elite_modifiers = require("data.elite_modifiers")

local EnemyFactory = {}

--============================================
-- ENEMY CREATION
--============================================

function EnemyFactory.spawn(enemy_type, position, modifiers)
    modifiers = modifiers or {}

    local def = enemies[enemy_type]
    if not def then
        log_warn("Unknown enemy type: " .. tostring(enemy_type))
        return nil, nil
    end

    -- Create entity with sprite
    local e = animation_system.createAnimatedObjectWithTransform(
        def.sprite or "enemy_default",
        true
    )

    if not e or not entity_cache.valid(e) then
        log_warn("Failed to create enemy entity for: " .. enemy_type)
        return nil, nil
    end

    -- Build context from definition
    local ctx = {
        type = enemy_type,
        hp = def.hp,
        max_hp = def.hp,
        speed = def.speed,
        damage = def.damage or 0,
        size = def.size or { 32, 32 },

        entity = e,
        is_elite = #modifiers > 0,
        modifiers = modifiers,
        invulnerable = false,

        -- Copy callbacks (can be wrapped by modifiers)
        on_death = def.on_death,
        on_hit = def.on_hit,
        on_hit_player = def.on_hit_player,
        on_contact_player = def.on_contact_player,
    }

    -- Copy any extra fields from definition
    for k, v in pairs(def) do
        if ctx[k] == nil and type(v) ~= "function" then
            ctx[k] = v
        end
    end

    -- Apply elite modifiers
    for _, mod_name in ipairs(modifiers) do
        local mod = elite_modifiers[mod_name]
        if mod then
            if mod.hp_mult then ctx.hp = ctx.hp * mod.hp_mult; ctx.max_hp = ctx.hp end
            if mod.speed_mult then ctx.speed = ctx.speed * mod.speed_mult end
            if mod.damage_mult then ctx.damage = ctx.damage * mod.damage_mult end
            if mod.size_mult then
                ctx.size = { ctx.size[1] * mod.size_mult, ctx.size[2] * mod.size_mult }
            end
            if mod.damage_reduction then ctx.damage_reduction = mod.damage_reduction end
            if mod.on_apply then mod.on_apply(e, ctx, WaveHelpers) end
        end
    end

    -- Store context
    WaveHelpers.set_enemy_ctx(e, ctx)

    -- Set position
    local transform = component_cache.get(e, Transform)
    if transform then
        transform.actualX = position.x
        transform.actualY = position.y
        transform.actualW = ctx.size[1]
        transform.actualH = ctx.size[2]
    end

    -- Resize animation
    animation_system.resizeAnimationObjectsInEntityToFit(e, ctx.size[1], ctx.size[2])

    -- Setup collision callbacks
    EnemyFactory.setup_collision(e, ctx)

    -- Setup signal listeners for this enemy
    EnemyFactory.setup_signals(e, ctx)

    -- Apply elite visual if needed
    if ctx.is_elite then
        WaveHelpers.set_shader(e, "elite_glow")
    end

    -- Run on_spawn
    if def.on_spawn then
        def.on_spawn(e, ctx, WaveHelpers)
    end

    -- Emit spawned event
    signal.emit("enemy_spawned", e, ctx)

    return e, ctx
end

--============================================
-- COLLISION SETUP
--============================================

function EnemyFactory.setup_collision(e, ctx)
    local gameObj = registry:get(e, GameObject)
    if not gameObj then return end

    gameObj.state.collisionEnabled = true

    gameObj.methods.onCollision = function(other_entity)
        if other_entity ~= survivorEntity then return end
        if not entity_cache.valid(e) then return end

        -- Call on_contact_player if defined
        if ctx.on_contact_player then
            ctx.on_contact_player(e, ctx, WaveHelpers)
        end

        -- Deal contact damage
        if ctx.damage and ctx.damage > 0 then
            WaveHelpers.deal_damage_to_player(ctx.damage)

            if ctx.on_hit_player then
                ctx.on_hit_player(e, ctx, { damage = ctx.damage, target = survivorEntity }, WaveHelpers)
            end
        end
    end
end

--============================================
-- SIGNAL SETUP
--============================================

function EnemyFactory.setup_signals(e, ctx)
    -- Listen for damage to this enemy
    local damage_handler = function(target, hit_info)
        if target ~= e then return end
        if not entity_cache.valid(e) then return end
        if ctx.invulnerable then return end

        -- Apply damage reduction if any
        local damage = hit_info.damage
        if ctx.damage_reduction then
            damage = damage * (1 - ctx.damage_reduction)
        end

        -- Update HP
        ctx.hp = ctx.hp - damage

        -- Call on_hit callback
        if ctx.on_hit then
            ctx.on_hit(e, ctx, hit_info, WaveHelpers)
        end

        -- Check for death
        if ctx.hp <= 0 then
            EnemyFactory.kill(e, ctx, hit_info)
        end
    end

    -- Register with unique key so we can unregister later
    signal.register("on_entity_damaged", damage_handler)
    ctx._damage_handler = damage_handler
end

--============================================
-- ENEMY DEATH
--============================================

function EnemyFactory.kill(e, ctx, hit_info)
    if not entity_cache.valid(e) then return end

    local death_info = {
        killer = hit_info and hit_info.source or nil,
        damage_type = hit_info and hit_info.damage_type or "unknown",
        overkill = math.abs(ctx.hp),
    }

    -- Call on_death callback
    if ctx.on_death then
        ctx.on_death(e, ctx, death_info, WaveHelpers)
    end

    -- Cleanup timers tagged with this entity
    timer.cancel("enemy_" .. e)
    timer.cancel("enemy_" .. e .. "_dash")
    timer.cancel("enemy_" .. e .. "_trap")
    timer.cancel("enemy_" .. e .. "_summon")
    timer.cancel("elite_" .. e .. "_summon")
    timer.cancel("elite_" .. e .. "_enrage")
    timer.cancel("elite_" .. e .. "_shield")
    timer.cancel("elite_" .. e .. "_regen")
    timer.cancel("elite_" .. e .. "_teleport")

    -- Unregister signal handler
    if ctx._damage_handler then
        signal.remove("on_entity_damaged", ctx._damage_handler)
    end

    -- Emit death signal
    signal.emit("enemy_killed", e, ctx)

    -- Destroy entity
    if entity_cache.valid(e) then
        registry:destroy(e)
    end
end

return EnemyFactory
```

**Step 2: Verify file created**

Run: `ls -la assets/scripts/combat/enemy_factory.lua`
Expected: File exists

**Step 3: Commit**

```bash
git add assets/scripts/combat/enemy_factory.lua
git commit -m "feat(wave): add enemy factory with callback wiring"
```

---

## Task 6: Wave Generators

**Files:**
- Create: `assets/scripts/combat/wave_generators.lua`

**Step 1: Create wave_generators.lua**

```lua
-- assets/scripts/combat/wave_generators.lua
-- Generate waves from configuration

local generators = {}

--============================================
-- NORMALIZE WAVE FORMAT
--============================================

-- Ensure wave is in standard format: { "type", "type", ... } or { enemies = {...}, delay_between = N }
function generators.normalize_wave(wave)
    if not wave then return {} end

    -- Already a table with enemies key
    if wave.enemies then
        return wave
    end

    -- Simple list of enemy names
    local enemies = {}
    local delay_between = nil

    for k, v in pairs(wave) do
        if type(k) == "number" then
            table.insert(enemies, v)
        elseif k == "delay_between" then
            delay_between = v
        end
    end

    return {
        enemies = enemies,
        delay_between = delay_between
    }
end

--============================================
-- BUDGET-BASED GENERATION
--============================================

function generators.from_budget(config)
    local waves = {}
    local count = config.count or 3
    local pool = config.enemy_pool or {}
    local budget_config = config.budget or { base = 5, per_wave = 2 }
    local min_enemies = config.min_enemies or 2
    local max_enemies = config.max_enemies or 10
    local guaranteed = config.guaranteed or {}

    -- Build weighted selection table
    local total_weight = 0
    for _, entry in ipairs(pool) do
        total_weight = total_weight + (entry.weight or 1)
    end

    local function pick_enemy()
        local roll = math.random() * total_weight
        local cumulative = 0
        for _, entry in ipairs(pool) do
            cumulative = cumulative + (entry.weight or 1)
            if roll <= cumulative then
                return entry.type, entry.cost or 1
            end
        end
        return pool[1].type, pool[1].cost or 1
    end

    for wave_num = 1, count do
        -- Calculate budget for this wave
        local budget
        if type(budget_config) == "table" then
            if budget_config[wave_num] then
                budget = budget_config[wave_num]
            else
                budget = (budget_config.base or 5) + (wave_num - 1) * (budget_config.per_wave or 2)
            end
        elseif type(budget_config) == "function" then
            budget = budget_config(wave_num)
        else
            budget = budget_config
        end

        local enemies = {}
        local remaining = budget

        -- Add guaranteed enemies first
        if guaranteed[wave_num] then
            for _, enemy_type in ipairs(guaranteed[wave_num]) do
                table.insert(enemies, enemy_type)
                -- Deduct cost
                for _, entry in ipairs(pool) do
                    if entry.type == enemy_type then
                        remaining = remaining - (entry.cost or 1)
                        break
                    end
                end
            end
        end

        -- Fill remaining budget
        local safety = 100
        while remaining > 0 and #enemies < max_enemies and safety > 0 do
            safety = safety - 1
            local enemy_type, cost = pick_enemy()
            if cost <= remaining then
                table.insert(enemies, enemy_type)
                remaining = remaining - cost
            else
                -- Try to find cheaper enemy
                local found = false
                for _, entry in ipairs(pool) do
                    if (entry.cost or 1) <= remaining then
                        table.insert(enemies, entry.type)
                        remaining = remaining - (entry.cost or 1)
                        found = true
                        break
                    end
                end
                if not found then break end
            end
        end

        -- Ensure minimum enemies
        while #enemies < min_enemies do
            local enemy_type = pick_enemy()
            table.insert(enemies, enemy_type)
        end

        table.insert(waves, { enemies = enemies })
    end

    return waves
end

--============================================
-- SHORTHAND GENERATORS
--============================================

-- Quick escalating waves
function generators.escalating(config)
    local enemies = config.enemies or { "goblin" }
    local start = config.start or 3
    local add = config.add or 1
    local count = config.count or 4

    local waves = {}
    for wave_num = 1, count do
        local wave_enemies = {}
        local enemy_count = start + (wave_num - 1) * add

        for i = 1, enemy_count do
            local enemy_type = enemies[math.random(1, #enemies)]
            table.insert(wave_enemies, enemy_type)
        end

        table.insert(waves, { enemies = wave_enemies })
    end

    return waves
end

-- Budget shorthand with simpler config
function generators.budget(config)
    local pool_input = config.pool or { goblin = 1 }
    local budget_input = config.budget or "5+2n"
    local count = config.count or 4

    -- Convert pool format: { goblin = 3, archer = 2 } -> standard format
    local pool = {}
    for enemy_type, weight in pairs(pool_input) do
        table.insert(pool, { type = enemy_type, weight = weight, cost = 1 })
    end

    -- Parse budget string like "5+2n"
    local budget_config
    if type(budget_input) == "string" then
        local base, per = budget_input:match("(%d+)%+(%d+)n")
        if base and per then
            budget_config = { base = tonumber(base), per_wave = tonumber(per) }
        else
            budget_config = { base = tonumber(budget_input) or 5, per_wave = 0 }
        end
    elseif type(budget_input) == "table" then
        budget_config = budget_input
    else
        budget_config = { base = budget_input, per_wave = 0 }
    end

    return generators.from_budget({
        count = count,
        enemy_pool = pool,
        budget = budget_config,
    })
end

return generators
```

**Step 2: Verify file created**

Run: `ls -la assets/scripts/combat/wave_generators.lua`
Expected: File exists

**Step 3: Commit**

```bash
git add assets/scripts/combat/wave_generators.lua
git commit -m "feat(wave): add wave generators (budget, escalating)"
```

---

## Task 7: Stage Providers

**Files:**
- Create: `assets/scripts/combat/stage_providers.lua`

**Step 1: Create stage_providers.lua**

```lua
-- assets/scripts/combat/stage_providers.lua
-- Stage providers: sequence, endless, hybrid

local generators = require("combat.wave_generators")

local providers = {}

--============================================
-- SEQUENCE PROVIDER (hand-crafted stages)
--============================================

function providers.sequence(stages)
    local index = 0

    return {
        next = function()
            index = index + 1
            return stages[index]
        end,

        get = function(id)
            for _, stage in ipairs(stages) do
                if stage.id == id then return stage end
            end
            return nil
        end,

        reset = function()
            index = 0
        end,

        current_index = function()
            return index
        end,

        peek = function()
            return stages[index + 1]
        end,
    }
end

--============================================
-- ENDLESS PROVIDER (procedural generation)
--============================================

function providers.endless(config)
    local stage_num = 0

    -- Defaults
    local cfg = {
        base_waves = config.base_waves or 3,
        wave_scaling = config.wave_scaling or function(n) return 3 + math.floor(n / 3) end,
        elite_every = config.elite_every or 3,
        shop_every = config.shop_every or 1,
        reward_every = config.reward_every or 5,

        enemy_pool = config.enemy_pool or {
            { type = "goblin", weight = 5, cost = 1 },
            { type = "archer", weight = 3, cost = 2 },
            { type = "dasher", weight = 2, cost = 3 },
        },

        budget_base = config.budget_base or 8,
        budget_per_stage = config.budget_per_stage or 3,
        budget_per_wave = config.budget_per_wave or 2,

        elite_pool = config.elite_pool or { "goblin", "archer", "dasher" },
        elite_modifier_count = config.elite_modifier_count or 2,

        spawn = config.spawn or "around_player",
    }

    return {
        next = function()
            stage_num = stage_num + 1

            local wave_count = cfg.wave_scaling(stage_num)
            local has_elite = (stage_num % cfg.elite_every == 0)
            local goes_to_shop = (stage_num % cfg.shop_every == 0)
            local shows_reward = (stage_num % cfg.reward_every == 0)

            -- Generate waves
            local stage_budget = cfg.budget_base + (stage_num - 1) * cfg.budget_per_stage

            local waves = generators.from_budget({
                count = wave_count,
                enemy_pool = cfg.enemy_pool,
                budget = {
                    base = stage_budget,
                    per_wave = cfg.budget_per_wave,
                },
            })

            -- Build stage config
            local stage = {
                id = "endless_" .. stage_num,
                waves = waves,
                spawn = cfg.spawn,
                difficulty_scale = 1.0 + (stage_num - 1) * 0.1,
            }

            -- Elite?
            if has_elite then
                local elite_base = cfg.elite_pool[math.random(#cfg.elite_pool)]
                local elite_modifiers = require("data.elite_modifiers")
                stage.elite = {
                    base = elite_base,
                    modifiers = elite_modifiers.roll_random(cfg.elite_modifier_count),
                }
            end

            -- Transition
            if shows_reward then
                stage.show_reward = true
            end

            if goes_to_shop then
                stage.next = "shop"
            end

            return stage
        end,

        get = function(id)
            return nil -- endless doesn't support random access
        end,

        reset = function()
            stage_num = 0
        end,

        current_index = function()
            return stage_num
        end,

        peek = function()
            return nil -- can't peek endless
        end,
    }
end

--============================================
-- HYBRID PROVIDER (hand-crafted then endless)
--============================================

function providers.hybrid(crafted_stages, endless_config)
    local sequence = providers.sequence(crafted_stages)
    local endless = providers.endless(endless_config)
    local in_endless = false

    return {
        next = function()
            if not in_endless then
                local stage = sequence.next()
                if stage then
                    return stage
                else
                    in_endless = true
                end
            end
            return endless.next()
        end,

        get = function(id)
            return sequence.get(id)
        end,

        reset = function()
            in_endless = false
            sequence.reset()
            endless.reset()
        end,

        current_index = function()
            if in_endless then
                return #crafted_stages + endless.current_index()
            end
            return sequence.current_index()
        end,

        is_endless = function()
            return in_endless
        end,
    }
end

return providers
```

**Step 2: Verify file created**

Run: `ls -la assets/scripts/combat/stage_providers.lua`
Expected: File exists

**Step 3: Commit**

```bash
git add assets/scripts/combat/stage_providers.lua
git commit -m "feat(wave): add stage providers (sequence, endless, hybrid)"
```

---

## Task 8: Wave Director - Core Logic

**Files:**
- Create: `assets/scripts/combat/wave_director.lua`

**Step 1: Create wave_director.lua**

```lua
-- assets/scripts/combat/wave_director.lua
-- Core orchestrator for wave-based gameplay

local signal = require("external.hump.signal")
local timer = require("core.timer")
local entity_cache = require("core.entity_cache")

local WaveHelpers = require("combat.wave_helpers")
local EnemyFactory = require("combat.enemy_factory")
local generators = require("combat.wave_generators")
local elite_modifiers = require("data.elite_modifiers")

local WaveDirector = {}

--============================================
-- STATE
--============================================

local state = {
    current_stage = nil,
    current_wave_index = 0,
    waves = {},
    alive_enemies = {},
    spawning_complete = false,
    stage_complete = false,
    paused = false,
}

-- External reference to stage provider (set by game code)
WaveDirector.stage_provider = nil

--============================================
-- PUBLIC API
--============================================

function WaveDirector.start_stage(stage_config)
    if not stage_config then
        log_warn("WaveDirector.start_stage called with nil config")
        return
    end

    state.current_stage = stage_config
    state.current_wave_index = 0
    state.alive_enemies = {}
    state.spawning_complete = false
    state.stage_complete = false
    state.paused = false

    -- Generate waves if using wave_generator
    if stage_config.wave_generator then
        state.waves = generators.from_budget(stage_config.wave_generator)
    elseif stage_config.waves then
        state.waves = {}
        for _, wave in ipairs(stage_config.waves) do
            table.insert(state.waves, generators.normalize_wave(wave))
        end
    else
        state.waves = {}
    end

    signal.emit("stage_started", stage_config)
    WaveDirector.start_next_wave()
end

function WaveDirector.start_next_wave()
    if state.paused then return end

    state.current_wave_index = state.current_wave_index + 1
    state.spawning_complete = false

    local wave = state.waves[state.current_wave_index]

    if not wave then
        -- All waves done, spawn elite if configured
        if state.current_stage.elite then
            WaveDirector.spawn_elite()
        else
            WaveDirector.complete_stage()
        end
        return
    end

    -- Announce wave
    WaveHelpers.show_floating_text("Wave " .. state.current_wave_index, { style = "wave_announce" })
    signal.emit("wave_started", state.current_wave_index, wave)

    -- Get spawn positions
    local spawn_config = state.current_stage.spawn or "around_player"
    local enemies = wave.enemies or {}
    local positions = WaveHelpers.get_spawn_positions(spawn_config, #enemies)

    -- Telegraph then spawn each enemy
    local delay_between = wave.delay_between or 0.5

    for i, enemy_type in ipairs(enemies) do
        local pos = positions[i]
        local spawn_delay = (i - 1) * delay_between

        -- Telegraph (1 second before spawn)
        timer.after(spawn_delay, function()
            if state.paused then return end
            WaveHelpers.spawn_telegraph(pos, enemy_type, 1.0)
        end, "wave_telegraph_" .. i)

        -- Actual spawn (1 second after telegraph)
        timer.after(spawn_delay + 1.0, function()
            if state.paused then return end
            WaveDirector.spawn_enemy(enemy_type, pos)
        end, "wave_spawn_" .. i)
    end

    -- Mark spawning complete after last enemy
    local total_spawn_time = (#enemies - 1) * delay_between + 1.0
    timer.after(total_spawn_time + 0.1, function()
        state.spawning_complete = true
        WaveDirector.check_wave_complete()
    end, "wave_spawn_complete")
end

function WaveDirector.spawn_enemy(enemy_type, position, modifiers)
    modifiers = modifiers or {}
    local e, ctx = EnemyFactory.spawn(enemy_type, position, modifiers)
    if e and ctx then
        state.alive_enemies[e] = ctx
    end
    return e, ctx
end

function WaveDirector.spawn_elite()
    WaveHelpers.show_floating_text("Elite Incoming!", { style = "elite_announce" })

    local elite_config = state.current_stage.elite
    local pos = WaveHelpers.get_spawn_positions("around_player", 1)[1]

    -- Telegraph elite (longer warning)
    WaveHelpers.spawn_telegraph(pos, "elite", 1.5)

    timer.after(1.5, function()
        if state.paused then return end

        local enemy_type, modifiers

        if type(elite_config) == "string" then
            -- Unique elite type
            enemy_type = elite_config
            modifiers = {}
        elseif elite_config.base then
            -- Modified regular enemy
            enemy_type = elite_config.base
            if elite_config.modifiers then
                modifiers = elite_config.modifiers
            elseif elite_config.modifier_count then
                modifiers = elite_modifiers.roll_random(elite_config.modifier_count)
            else
                modifiers = elite_modifiers.roll_random(2)
            end
        else
            log_warn("Invalid elite config")
            WaveDirector.complete_stage()
            return
        end

        local e, ctx = WaveDirector.spawn_enemy(enemy_type, pos, modifiers)
        state.spawning_complete = true

        if e and ctx then
            signal.emit("elite_spawned", e, ctx)
        end
    end, "elite_spawn")
end

function WaveDirector.on_enemy_killed(e)
    if not state.alive_enemies[e] then return end

    state.alive_enemies[e] = nil
    WaveDirector.check_wave_complete()
end

function WaveDirector.check_wave_complete()
    if state.paused then return end
    if not state.spawning_complete then return end
    if next(state.alive_enemies) ~= nil then return end -- still enemies alive

    -- Check if we just finished the elite (last thing in stage)
    if state.current_wave_index >= #state.waves then
        -- All waves done
        if state.current_stage.elite then
            -- Elite was spawned and killed
            WaveDirector.complete_stage()
        else
            WaveDirector.complete_stage()
        end
    else
        -- More waves to go
        signal.emit("wave_cleared", state.current_wave_index)

        local wave_advance = state.current_stage.wave_advance or "on_clear"
        local delay = 1.0

        if type(wave_advance) == "number" then
            delay = wave_advance
        elseif wave_advance == "on_spawn_complete" then
            delay = 0.1
        end

        timer.after(delay, function()
            WaveDirector.start_next_wave()
        end, "wave_advance")
    end
end

function WaveDirector.complete_stage()
    if state.stage_complete then return end
    state.stage_complete = true

    WaveHelpers.show_floating_text("Stage Complete!", { style = "stage_complete" })

    local results = {
        stage = state.current_stage.id,
        waves_completed = state.current_wave_index,
    }

    signal.emit("stage_completed", results)

    -- Handle transition after delay
    timer.after(1.5, function()
        WaveDirector.handle_transition(results)
    end, "stage_transition")
end

function WaveDirector.handle_transition(results)
    local stage = state.current_stage

    if stage.on_complete then
        -- Custom callback
        stage.on_complete(results)
    elseif stage.show_reward then
        -- Show reward then continue
        signal.emit("show_rewards", results, function()
            if stage.next then
                WaveDirector.goto(stage.next)
            elseif WaveDirector.stage_provider then
                local next_stage = WaveDirector.stage_provider.next()
                if next_stage then
                    WaveDirector.start_stage(next_stage)
                else
                    signal.emit("run_complete")
                end
            end
        end)
    elseif stage.next then
        WaveDirector.goto(stage.next)
    elseif WaveDirector.stage_provider then
        local next_stage = WaveDirector.stage_provider.next()
        if next_stage then
            WaveDirector.start_stage(next_stage)
        else
            signal.emit("run_complete")
        end
    else
        signal.emit("run_complete")
    end
end

function WaveDirector.goto(target)
    if target == "shop" then
        signal.emit("goto_shop")
    elseif target == "rewards" then
        signal.emit("goto_rewards")
    else
        -- Assume it's a stage ID
        if WaveDirector.stage_provider then
            local stage = WaveDirector.stage_provider.get(target)
            if stage then
                WaveDirector.start_stage(stage)
                return
            end
        end
        log_warn("Unknown goto target: " .. tostring(target))
    end
end

function WaveDirector.pause()
    state.paused = true
end

function WaveDirector.resume()
    state.paused = false
end

function WaveDirector.get_alive_count()
    local count = 0
    for _ in pairs(state.alive_enemies) do
        count = count + 1
    end
    return count
end

function WaveDirector.get_state()
    return {
        stage_id = state.current_stage and state.current_stage.id,
        wave_index = state.current_wave_index,
        total_waves = #state.waves,
        alive_enemies = WaveDirector.get_alive_count(),
        spawning_complete = state.spawning_complete,
        stage_complete = state.stage_complete,
        paused = state.paused,
    }
end

function WaveDirector.cleanup()
    -- Kill all remaining enemies
    for e, _ in pairs(state.alive_enemies) do
        if entity_cache.valid(e) then
            registry:destroy(e)
        end
    end
    state.alive_enemies = {}

    -- Cancel all wave timers
    for i = 1, 50 do
        timer.cancel("wave_telegraph_" .. i)
        timer.cancel("wave_spawn_" .. i)
    end
    timer.cancel("wave_spawn_complete")
    timer.cancel("wave_advance")
    timer.cancel("elite_spawn")
    timer.cancel("stage_transition")
end

--============================================
-- SIGNAL LISTENERS
--============================================

signal.register("enemy_killed", function(e, ctx)
    WaveDirector.on_enemy_killed(e)
end)

-- Handle summoned enemies (add to tracking)
signal.register("summon_enemy", function(data)
    local e, ctx = WaveDirector.spawn_enemy(data.type, { x = data.x, y = data.y })
    -- Summoned enemies are tracked just like regular enemies
end)

return WaveDirector
```

**Step 2: Verify file created**

Run: `ls -la assets/scripts/combat/wave_director.lua`
Expected: File exists

**Step 3: Commit**

```bash
git add assets/scripts/combat/wave_director.lua
git commit -m "feat(wave): add wave director orchestrator"
```

---

## Task 9: Wave System Entry Point

**Files:**
- Create: `assets/scripts/combat/wave_system.lua`

**Step 1: Create wave_system.lua as the main entry point**

```lua
-- assets/scripts/combat/wave_system.lua
-- Main entry point for wave system

local signal = require("external.hump.signal")

local WaveDirector = require("combat.wave_director")
local providers = require("combat.stage_providers")
local generators = require("combat.wave_generators")
local WaveHelpers = require("combat.wave_helpers")
local EnemyFactory = require("combat.enemy_factory")

local WaveSystem = {}

-- Re-export submodules for convenience
WaveSystem.director = WaveDirector
WaveSystem.providers = providers
WaveSystem.generators = generators
WaveSystem.helpers = WaveHelpers
WaveSystem.factory = EnemyFactory

--============================================
-- QUICK START API
--============================================

--- Start a run with the given stage provider
-- @param provider A stage provider (from providers.sequence, providers.endless, or providers.hybrid)
function WaveSystem.start_run(provider)
    WaveDirector.stage_provider = provider
    provider.reset()

    local first_stage = provider.next()
    if first_stage then
        WaveDirector.start_stage(first_stage)
    else
        log_warn("WaveSystem.start_run: provider returned no stages")
    end
end

--- Start a quick test with minimal configuration
-- @param stages Array of stage configs (or single stage config)
function WaveSystem.quick_test(stages)
    if stages.waves then
        -- Single stage passed
        stages = { stages }
    end

    local provider = providers.sequence(stages)
    WaveSystem.start_run(provider)
end

--- Start endless mode
-- @param config Optional endless config overrides
function WaveSystem.start_endless(config)
    config = config or {}
    local provider = providers.endless(config)
    WaveSystem.start_run(provider)
end

--- Continue from shop to next stage
function WaveSystem.continue_from_shop()
    if not WaveDirector.stage_provider then
        log_warn("WaveSystem.continue_from_shop: no stage provider set")
        return
    end

    local next_stage = WaveDirector.stage_provider.next()
    if next_stage then
        WaveDirector.start_stage(next_stage)
    else
        signal.emit("run_complete")
    end
end

--============================================
-- CONVENIENCE ACCESSORS
--============================================

function WaveSystem.get_state()
    return WaveDirector.get_state()
end

function WaveSystem.pause()
    WaveDirector.pause()
end

function WaveSystem.resume()
    WaveDirector.resume()
end

function WaveSystem.cleanup()
    WaveDirector.cleanup()
end

function WaveSystem.goto(target)
    WaveDirector.goto(target)
end

--============================================
-- EXAMPLE STAGE CONFIGS
--============================================

WaveSystem.examples = {}

-- Minimal test stage
WaveSystem.examples.minimal = {
    waves = {
        { "goblin", "goblin", "goblin" },
        { "goblin", "goblin", "archer" },
    },
    next = "shop",
}

-- Stage with elite
WaveSystem.examples.with_elite = {
    waves = {
        { "goblin", "goblin", "dasher" },
        { "archer", "archer", "trapper" },
    },
    elite = { base = "goblin", modifiers = { "tanky", "fast" } },
    next = "shop",
}

-- Endless mode config
WaveSystem.examples.endless_config = {
    enemy_pool = {
        { type = "goblin", weight = 5, cost = 1 },
        { type = "archer", weight = 3, cost = 2 },
        { type = "dasher", weight = 2, cost = 3 },
        { type = "trapper", weight = 2, cost = 3 },
        { type = "summoner", weight = 1, cost = 5 },
        { type = "exploder", weight = 2, cost = 2 },
    },
    elite_every = 3,
    shop_every = 1,
    reward_every = 5,
}

return WaveSystem
```

**Step 2: Verify file created**

Run: `ls -la assets/scripts/combat/wave_system.lua`
Expected: File exists

**Step 3: Commit**

```bash
git add assets/scripts/combat/wave_system.lua
git commit -m "feat(wave): add wave_system entry point with quick start API"
```

---

## Task 10: Integration - Signal Handlers for Visual Feedback

**Files:**
- Create: `assets/scripts/combat/wave_visuals.lua`

**Step 1: Create wave_visuals.lua for telegraph and floating text**

```lua
-- assets/scripts/combat/wave_visuals.lua
-- Visual feedback handlers for wave system

local signal = require("external.hump.signal")
local timer = require("core.timer")
local entity_cache = require("core.entity_cache")
local component_cache = require("core.component_cache")
local animation_system = require("core.animation_system")

local WaveVisuals = {}

--============================================
-- TELEGRAPH MARKER
--============================================

local active_telegraphs = {}

signal.register("spawn_telegraph", function(data)
    local x = data.x
    local y = data.y
    local duration = data.duration or 1.0
    local enemy_type = data.enemy_type

    -- Create a simple pulsing circle entity
    -- Using a generic marker sprite (replace with your actual asset)
    local marker = animation_system.createAnimatedObjectWithTransform(
        "telegraph_marker",  -- Replace with actual sprite name
        true
    )

    if not marker or not entity_cache.valid(marker) then
        -- Fallback: just log it
        log_info("Telegraph at " .. x .. ", " .. y .. " for " .. tostring(enemy_type))
        return
    end

    -- Position
    local transform = component_cache.get(marker, Transform)
    if transform then
        transform.actualX = x
        transform.actualY = y
        transform.actualW = 40
        transform.actualH = 40
    end

    -- Pulse animation via scale
    local elapsed = 0
    local pulse_speed = 8

    timer.every(0.016, function()
        if not entity_cache.valid(marker) then return false end
        elapsed = elapsed + 0.016

        if elapsed >= duration then
            registry:destroy(marker)
            return false
        end

        -- Pulse scale
        local scale = 1.0 + math.sin(elapsed * pulse_speed) * 0.2
        local t = component_cache.get(marker, Transform)
        if t then
            t.actualW = 40 * scale
            t.actualH = 40 * scale
        end

        -- Fade in urgency near end
        -- Could add shader/color change here
    end, "telegraph_pulse_" .. marker)

    active_telegraphs[marker] = true
end)

--============================================
-- FLOATING TEXT
--============================================

signal.register("show_floating_text", function(data)
    local text = data.text
    local style = data.style or "default"
    local x = data.x
    local y = data.y

    -- Default position: center of screen
    if not x then
        x = (globals.screenWidth or 800) / 2
    end
    if not y then
        y = (globals.screenHeight or 600) / 3
    end

    -- Style configurations
    local styles = {
        wave_announce = { fontSize = 32, color = "white", duration = 1.5, rise = 30 },
        elite_announce = { fontSize = 40, color = "red", duration = 2.0, rise = 20 },
        stage_complete = { fontSize = 36, color = "gold", duration = 2.0, rise = 40 },
        default = { fontSize = 24, color = "white", duration = 1.5, rise = 20 },
    }

    local cfg = styles[style] or styles.default

    -- Create text entity (simplified - adapt to your UI system)
    -- This is a placeholder - integrate with your actual text rendering
    log_info("[FLOATING TEXT] " .. text .. " (style: " .. style .. ")")

    -- If you have a UI text system, use it here:
    -- local textEntity = ui.createFloatingText(text, x, y, cfg)

    -- For now, emit a signal that UI layer can handle
    signal.emit("ui_floating_text", {
        text = text,
        x = x,
        y = y,
        fontSize = cfg.fontSize,
        color = cfg.color,
        duration = cfg.duration,
        rise = cfg.rise,
    })
end)

--============================================
-- PARTICLES (placeholder)
--============================================

signal.register("spawn_particles", function(data)
    local effect = data.effect
    local x = data.x
    local y = data.y

    -- Integrate with your particle system
    log_info("[PARTICLES] " .. effect .. " at " .. x .. ", " .. y)

    -- Example: signal.emit("create_particle_effect", effect, x, y)
end)

--============================================
-- SCREEN SHAKE (placeholder)
--============================================

signal.register("screen_shake", function(data)
    local duration = data.duration or 0.3
    local intensity = data.intensity or 5

    -- Integrate with your camera system
    log_info("[SCREEN SHAKE] duration=" .. duration .. " intensity=" .. intensity)

    -- Example: camera.shake(duration, intensity)
end)

--============================================
-- EXPLOSION VISUAL (placeholder)
--============================================

signal.register("explosion", function(data)
    local x = data.x
    local y = data.y
    local radius = data.radius
    local damage = data.damage

    -- Visual effect
    signal.emit("spawn_particles", { effect = "explosion", x = x, y = y })
    signal.emit("screen_shake", { duration = 0.2, intensity = radius / 20 })

    -- Damage to player if in range
    if survivorEntity and entity_cache.valid(survivorEntity) then
        local transform = component_cache.get(survivorEntity, Transform)
        if transform then
            local dx = transform.actualX - x
            local dy = transform.actualY - y
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist <= radius then
                signal.emit("damage_player", damage)
            end
        end
    end
end)

--============================================
-- TRAP SPAWN (placeholder)
--============================================

signal.register("spawn_trap", function(data)
    local x = data.x
    local y = data.y
    local damage = data.damage
    local lifetime = data.lifetime

    -- Create trap entity (simplified)
    log_info("[TRAP] spawned at " .. x .. ", " .. y .. " (damage=" .. damage .. ", lifetime=" .. lifetime .. ")")

    -- Implement trap entity creation based on your entity system
    -- Should have collision with player, deal damage on contact, despawn after lifetime
end)

--============================================
-- INIT
--============================================

function WaveVisuals.init()
    -- Any initialization needed
    log_info("WaveVisuals initialized")
end

return WaveVisuals
```

**Step 2: Verify file created**

Run: `ls -la assets/scripts/combat/wave_visuals.lua`
Expected: File exists

**Step 3: Commit**

```bash
git add assets/scripts/combat/wave_visuals.lua
git commit -m "feat(wave): add wave_visuals signal handlers for UI feedback"
```

---

## Task 11: Documentation - Usage Examples File

**Files:**
- Create: `assets/scripts/combat/wave_examples.lua`

**Step 1: Create comprehensive examples file**

```lua
-- assets/scripts/combat/wave_examples.lua
-- Copy/paste examples for common wave system usage patterns

local WaveSystem = require("combat.wave_system")
local providers = WaveSystem.providers
local signal = require("external.hump.signal")

local examples = {}

--============================================
-- EXAMPLE 1: Quick Test (minimal setup)
--============================================

function examples.quick_test()
    WaveSystem.quick_test({
        waves = {
            { "goblin", "goblin", "goblin" },
            { "goblin", "goblin", "archer" },
        },
        next = "shop",
    })
end

--============================================
-- EXAMPLE 2: Hand-Crafted Campaign
--============================================

function examples.campaign()
    local campaign_stages = {
        -- Stage 1: Tutorial, easy
        {
            id = "stage_1",
            waves = {
                { "goblin", "goblin" },
                { "goblin", "goblin", "goblin" },
            },
            spawn = "around_player",
            next = "stage_2",
        },

        -- Stage 2: Introduce archer
        {
            id = "stage_2",
            waves = {
                { "goblin", "goblin", "archer" },
                { "goblin", "archer", "archer" },
            },
            next = "shop",
        },

        -- Stage 3: First elite
        {
            id = "stage_3",
            waves = {
                { "goblin", "goblin", "dasher" },
                { "archer", "archer", "dasher" },
            },
            elite = { base = "goblin", modifiers = { "tanky", "fast" } },
            next = "shop",
        },

        -- Stage 4: With reward
        {
            id = "stage_4",
            waves = {
                { "dasher", "dasher", "trapper" },
                { "archer", "trapper", "summoner" },
            },
            elite = "goblin_chief",  -- unique elite type (define in enemies.lua)
            show_reward = true,
            next = "shop",
        },
    }

    WaveSystem.start_run(providers.sequence(campaign_stages))
end

--============================================
-- EXAMPLE 3: Endless Mode
--============================================

function examples.endless()
    WaveSystem.start_endless({
        -- Enemy pool with weights and costs
        enemy_pool = {
            { type = "goblin",   weight = 5, cost = 1 },
            { type = "archer",   weight = 3, cost = 2 },
            { type = "dasher",   weight = 2, cost = 3 },
            { type = "trapper",  weight = 2, cost = 3 },
            { type = "summoner", weight = 1, cost = 5 },
            { type = "exploder", weight = 2, cost = 2 },
        },

        -- Scaling
        budget_base = 8,
        budget_per_stage = 3,
        budget_per_wave = 2,

        -- Pacing
        elite_every = 3,
        shop_every = 1,
        reward_every = 5,
    })
end

--============================================
-- EXAMPLE 4: Hybrid (Story + Endless)
--============================================

function examples.hybrid()
    local story_stages = {
        {
            id = "intro",
            waves = { { "goblin", "goblin" } },
            on_complete = function(results)
                -- Show dialogue, then continue
                signal.emit("show_dialogue", "Welcome!", function()
                    WaveSystem.goto("stage_1")
                end)
            end,
        },
        {
            id = "stage_1",
            waves = {
                { "goblin", "goblin", "goblin" },
                { "goblin", "archer" },
            },
            next = "shop",
        },
        {
            id = "boss_1",
            waves = {
                { "goblin", "goblin", "archer", "archer" },
            },
            elite = "first_boss",
            show_reward = true,
            next = "shop",
        },
    }

    WaveSystem.start_run(providers.hybrid(story_stages, {
        elite_every = 3,
        budget_base = 12,  -- Harder after story
    }))
end

--============================================
-- EXAMPLE 5: Setup Event Listeners
--============================================

function examples.setup_listeners()
    signal.register("stage_started", function(stage_config)
        log_info("Stage started: " .. (stage_config.id or "unknown"))
    end)

    signal.register("wave_started", function(wave_num, wave)
        log_info("Wave " .. wave_num .. " started")
    end)

    signal.register("wave_cleared", function(wave_num)
        log_info("Wave " .. wave_num .. " cleared!")
    end)

    signal.register("elite_spawned", function(e, ctx)
        log_info("Elite spawned: " .. ctx.type)
    end)

    signal.register("stage_completed", function(results)
        log_info("Stage complete: " .. (results.stage or "unknown"))
    end)

    signal.register("enemy_spawned", function(e, ctx)
        -- Track spawns
    end)

    signal.register("enemy_killed", function(e, ctx)
        -- Award XP, drop loot, etc.
    end)

    signal.register("run_complete", function()
        log_info("Run complete - victory!")
    end)

    signal.register("goto_shop", function()
        -- Transition to shop state
        log_info("Going to shop...")
        -- activate_state(SHOP_STATE)
    end)

    signal.register("goto_rewards", function()
        -- Show reward picker
        log_info("Showing rewards...")
        -- activate_state(REWARD_OPENING_STATE)
    end)
end

--============================================
-- EXAMPLE 6: Continue from Shop
--============================================

function examples.on_shop_done()
    -- Call this when player finishes shopping
    WaveSystem.continue_from_shop()
end

--============================================
-- EXAMPLE 7: Debug - Print State
--============================================

function examples.print_state()
    local state = WaveSystem.get_state()
    log_info("=== Wave System State ===")
    log_info("Stage: " .. tostring(state.stage_id))
    log_info("Wave: " .. state.wave_index .. "/" .. state.total_waves)
    log_info("Alive enemies: " .. state.alive_enemies)
    log_info("Spawning complete: " .. tostring(state.spawning_complete))
    log_info("Stage complete: " .. tostring(state.stage_complete))
    log_info("Paused: " .. tostring(state.paused))
end

return examples
```

**Step 2: Verify file created**

Run: `ls -la assets/scripts/combat/wave_examples.lua`
Expected: File exists

**Step 3: Commit**

```bash
git add assets/scripts/combat/wave_examples.lua
git commit -m "docs(wave): add wave_examples.lua with usage patterns"
```

---

## Task 12: Final Verification

**Step 1: List all created files**

Run:
```bash
ls -la assets/scripts/combat/wave*.lua assets/scripts/data/enemies.lua assets/scripts/data/elite_modifiers.lua
```

Expected output should show:
- `wave_helpers.lua`
- `wave_generators.lua`
- `wave_director.lua`
- `wave_system.lua`
- `wave_visuals.lua`
- `wave_examples.lua`
- `enemies.lua`
- `elite_modifiers.lua`

**Step 2: Run Lua syntax check on all files**

Run:
```bash
for file in assets/scripts/combat/wave*.lua assets/scripts/data/enemies.lua assets/scripts/data/elite_modifiers.lua; do
    echo "Checking $file..."
    luac -p "$file" && echo "  OK" || echo "  SYNTAX ERROR"
done
```

Expected: All files show "OK"

**Step 3: Final commit with all files**

```bash
git status
git log --oneline -10
```

Expected: Clean working tree, 11 commits for the feature

---

## Summary

| Task | Files | Purpose |
|------|-------|---------|
| 1-2 | `wave_helpers.lua` | Movement, combat, visual, spawn position helpers |
| 3 | `enemies.lua` | 7 enemy definitions with timer-based behaviors |
| 4 | `elite_modifiers.lua` | 8 elite modifiers (stat + behavior) |
| 5 | `enemy_factory.lua` | Enemy creation and callback wiring |
| 6 | `wave_generators.lua` | Budget and escalating wave generation |
| 7 | `stage_providers.lua` | Sequence, endless, hybrid providers |
| 8 | `wave_director.lua` | Core orchestrator |
| 9 | `wave_system.lua` | Entry point with quick start API |
| 10 | `wave_visuals.lua` | Signal handlers for UI feedback |
| 11 | `wave_examples.lua` | Documentation and usage examples |
| 12 | - | Verification |
