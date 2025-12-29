--[[
================================================================================
WAVE HELPERS - Enemy AI Helper Functions
================================================================================
Provides reusable movement, combat, spawning, and visual effects for enemy AI.
Used by enemy definitions in data/enemies.lua.

MOVEMENT HELPERS:
    move_toward_player(e, speed)
        - Chase player at constant speed
        - Auto-normalizes direction vector
        - Parameters: e (entity), speed (pixels/sec)

    flee_from_player(e, speed, min_distance)
        - Run away from player when too close
        - Stops fleeing beyond min_distance
        - Parameters: e (entity), speed (pixels/sec), min_distance (pixels)

    kite_from_player(e, speed, preferred_distance)
        - Maintain distance from player (ranged enemy behavior)
        - Moves closer/away to stay at preferred_distance ± tolerance
        - Parameters: e (entity), speed (pixels/sec), preferred_distance (pixels)

    wander(e, speed)
        - Random wandering movement
        - Changes direction randomly every ~50 frames
        - Parameters: e (entity), speed (pixels/sec)

    dash_toward_player(e, dash_speed, duration)
        - High-speed dash toward player's current position
        - Direction locked at dash start (won't track player)
        - Parameters: e (entity), dash_speed (pixels/sec), duration (seconds)

POSITION HELPERS:
    get_player_position()
        - Returns player position as { x, y }
        - Safe: returns { x = 0, y = 0 } if player invalid

    get_entity_position(e)
        - Returns entity position as { x, y }
        - Returns nil if entity invalid or missing Transform

    get_spawn_positions(spawn_config, count)
        - Generate spawn positions based on pattern
        - spawn_config types:
            * "around_player" - Circle around player (min_radius, max_radius)
            * "random_area" - Random within area { x, y, w, h }
            * "fixed_points" - Cycle through points = { {x,y}, {x,y}, ... }
            * "off_screen" - Just outside screen bounds (padding)
        - Returns: array of { x, y } positions

COMBAT HELPERS:
    deal_damage_to_player(damage)
        - Emit damage signal to player
        - Routes through combat system

    heal_enemy(e, amount)
        - Heal enemy (capped at max_hp)
        - Modifies enemy context hp

    kill_enemy(e)
        - Instantly kill enemy
        - Sets hp = 0 and emits death event

    get_hp_percent(e)
        - Returns hp / max_hp ratio (0.0 to 1.0)
        - Returns 1.0 if no context found

    set_invulnerable(e, invulnerable)
        - Toggle invulnerability flag
        - Modifies enemy context

SPAWNING HELPERS:
    drop_trap(e, damage, lifetime)
        - Emit spawn_trap event at entity position
        - Parameters: e (entity), damage (number), lifetime (seconds)

    summon_enemies(e, enemy_type, count)
        - Spawn multiple enemies near entity
        - Random offset ±30 pixels
        - Parameters: e (entity), enemy_type (string), count (number)

    explode(e, radius, damage)
        - Emit explosion event at entity position
        - Parameters: e (entity), radius (pixels), damage (number)

VISUAL HELPERS:
    spawn_telegraph(position, enemy_type, duration)
        - Show spawn telegraph at position
        - Parameters: position { x, y }, enemy_type (string), duration (seconds, default 1.0)

    show_floating_text(text, opts)
        - Display floating damage/status text
        - opts: { style, x, y }

    spawn_particles(effect_name, e_or_position)
        - Spawn particle effect
        - Accepts entity or { x, y } position
        - Parameters: effect_name (string), e_or_position

    screen_shake(duration, intensity)
        - Trigger camera shake
        - Parameters: duration (seconds), intensity (number)

SHADER HELPERS:
    set_shader(e, shader_name)
        - Apply shader to entity using ShaderBuilder
        - Parameters: e (entity), shader_name (string)

    clear_shader(e)
        - Remove all shaders from entity
        - Parameters: e (entity)

CONTEXT STORAGE:
    set_enemy_ctx(e, ctx)
        - Store enemy context (hp, max_hp, invulnerable, etc.)
        - Uses weak table (auto-cleanup on entity destroy)

    get_enemy_ctx(e)
        - Retrieve enemy context
        - Returns nil if not found

USAGE EXAMPLE (from data/enemies.lua):
    enemies.goblin = {
        sprite = "b1060.png",
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

Dependencies:
    - core.component_cache
    - core.entity_cache
    - core.timer
    - external.hump.signal
    - core.shader_builder (optional, for shader helpers)
]]

local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
local timer = require("core.timer")
local signal = require("external.hump.signal")

local GetFrameTime = _G.GetFrameTime

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
    -- Note: survivorEntity is a global that can change, so we access it directly each time
    if not _G.survivorEntity or not entity_cache.valid(_G.survivorEntity) then
        return { x = 0, y = 0 }
    end
    local transform = component_cache.get(_G.survivorEntity, Transform)
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
    local tag = "dash_" .. tostring(e) .. "_" .. tostring(math.random(10000))

    timer.every_opts({
        delay = 0.016,
        action = function()
            if not entity_cache.valid(e) then return false end
            elapsed = elapsed + 0.016
            if elapsed >= duration then return false end

            local t = component_cache.get(e, Transform)
            if t then
                t.actualX = t.actualX + dir_x * dash_speed * 0.016
                t.actualY = t.actualY + dir_y * dash_speed * 0.016
            end
        end,
        tag = tag
    })
end

--============================================
-- DISTANCE & RANGE HELPERS
--============================================

--- Get distance from entity to player
--- @param e number Entity ID
--- @return number Distance in pixels (math.huge if invalid)
function WaveHelpers.distance_to_player(e)
    local pos = WaveHelpers.get_entity_position(e)
    if not pos then return math.huge end
    local player = WaveHelpers.get_player_position()
    local dx = pos.x - player.x
    local dy = pos.y - player.y
    return math.sqrt(dx * dx + dy * dy)
end

--- Get distance between two entities
--- @param e1 number First entity ID
--- @param e2 number Second entity ID
--- @return number Distance in pixels (math.huge if invalid)
function WaveHelpers.distance_between(e1, e2)
    local pos1 = WaveHelpers.get_entity_position(e1)
    local pos2 = WaveHelpers.get_entity_position(e2)
    if not pos1 or not pos2 then return math.huge end
    local dx = pos1.x - pos2.x
    local dy = pos1.y - pos2.y
    return math.sqrt(dx * dx + dy * dy)
end

--- Check if entity is within range of player
--- @param e number Entity ID
--- @param range number Range in pixels
--- @return boolean True if within range
function WaveHelpers.is_in_range(e, range)
    return WaveHelpers.distance_to_player(e) <= range
end

--- Get direction vector from entity to player (normalized)
--- @param e number Entity ID
--- @return table|nil { x, y } normalized direction or nil
function WaveHelpers.direction_to_player(e)
    local pos = WaveHelpers.get_entity_position(e)
    if not pos then return nil end
    local player = WaveHelpers.get_player_position()
    local dx = player.x - pos.x
    local dy = player.y - pos.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 1 then return { x = 0, y = 0 } end
    return { x = dx / dist, y = dy / dist }
end

--- Get angle from entity to player in radians
--- @param e number Entity ID
--- @return number Angle in radians (0 if invalid)
function WaveHelpers.angle_to_player(e)
    local pos = WaveHelpers.get_entity_position(e)
    if not pos then return 0 end
    local player = WaveHelpers.get_player_position()
    return math.atan2(player.y - pos.y, player.x - pos.x)
end

--============================================
-- ADVANCED MOVEMENT HELPERS
--============================================

--- Move entity toward a specific point
--- @param e number Entity ID
--- @param target_x number Target X coordinate
--- @param target_y number Target Y coordinate
--- @param speed number Movement speed (pixels/sec)
function WaveHelpers.move_toward_point(e, target_x, target_y, speed)
    if not entity_cache.valid(e) then return end
    local transform = component_cache.get(e, Transform)
    if not transform then return end

    local dx = target_x - transform.actualX
    local dy = target_y - transform.actualY
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > 1 then
        local dt = GetFrameTime()
        local move_dist = math.min(speed * dt, dist)  -- Don't overshoot
        transform.actualX = transform.actualX + (dx / dist) * move_dist
        transform.actualY = transform.actualY + (dy / dist) * move_dist
    end
end

--- Move entity in a direction (angle-based)
--- @param e number Entity ID
--- @param angle number Angle in radians
--- @param speed number Movement speed (pixels/sec)
function WaveHelpers.move_in_direction(e, angle, speed)
    if not entity_cache.valid(e) then return end
    local transform = component_cache.get(e, Transform)
    if not transform then return end

    local dt = GetFrameTime()
    transform.actualX = transform.actualX + math.cos(angle) * speed * dt
    transform.actualY = transform.actualY + math.sin(angle) * speed * dt
end

--- Strafe perpendicular to player (for dodging/orbiting)
--- @param e number Entity ID
--- @param speed number Movement speed (pixels/sec)
--- @param direction number 1 for clockwise, -1 for counter-clockwise
function WaveHelpers.strafe_around_player(e, speed, direction)
    if not entity_cache.valid(e) then return end
    local angle = WaveHelpers.angle_to_player(e)
    -- Add 90 degrees perpendicular
    local strafe_angle = angle + (math.pi / 2) * (direction or 1)
    WaveHelpers.move_in_direction(e, strafe_angle, speed)
end

--============================================
-- PROJECTILE HELPERS
--============================================

--- Fire a projectile from entity toward player
--- @param e number Entity ID (source)
--- @param preset string Projectile preset name
--- @param damage number Damage value
--- @param opts table|nil Optional: { speed, size, piercing, homing }
function WaveHelpers.fire_projectile(e, preset, damage, opts)
    if not entity_cache.valid(e) then return end
    local pos = WaveHelpers.get_entity_position(e)
    if not pos then return end

    opts = opts or {}
    local signal = require("external.hump.signal")
    
    -- Calculate direction to player
    local dir = WaveHelpers.direction_to_player(e)
    if not dir then return end

    signal.emit("spawn_enemy_projectile", {
        x = pos.x,
        y = pos.y,
        dir_x = dir.x,
        dir_y = dir.y,
        preset = preset or "enemy_basic_shot",
        damage = damage or 10,
        speed = opts.speed,
        size = opts.size,
        piercing = opts.piercing,
        homing = opts.homing,
        source = e,
    })
end

--- Fire a projectile with leading (predict player movement)
--- @param e number Entity ID (source)
--- @param preset string Projectile preset name
--- @param damage number Damage value
--- @param projectile_speed number Speed of projectile (for prediction)
function WaveHelpers.fire_projectile_leading(e, preset, damage, projectile_speed)
    if not entity_cache.valid(e) then return end
    local pos = WaveHelpers.get_entity_position(e)
    if not pos then return end

    local player_pos = WaveHelpers.get_player_position()
    local player_vel = WaveHelpers.get_player_velocity()
    
    -- Simple leading: predict where player will be
    local dist = WaveHelpers.distance_to_player(e)
    local flight_time = dist / (projectile_speed or 200)
    
    local predicted_x = player_pos.x + (player_vel.x or 0) * flight_time
    local predicted_y = player_pos.y + (player_vel.y or 0) * flight_time
    
    local dx = predicted_x - pos.x
    local dy = predicted_y - pos.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then return end

    signal.emit("spawn_enemy_projectile", {
        x = pos.x,
        y = pos.y,
        dir_x = dx / len,
        dir_y = dy / len,
        preset = preset or "enemy_basic_shot",
        damage = damage or 10,
        speed = projectile_speed,
        source = e,
    })
end

--- Fire projectiles in a spread pattern
--- @param e number Entity ID (source)
--- @param preset string Projectile preset name
--- @param damage number Damage per projectile
--- @param count number Number of projectiles
--- @param spread_angle number Total spread angle in radians
function WaveHelpers.fire_projectile_spread(e, preset, damage, count, spread_angle)
    if not entity_cache.valid(e) then return end
    local pos = WaveHelpers.get_entity_position(e)
    if not pos then return end

    count = count or 3
    spread_angle = spread_angle or (math.pi / 4)  -- 45 degrees default

    local base_angle = WaveHelpers.angle_to_player(e)
    local start_angle = base_angle - spread_angle / 2
    local angle_step = count > 1 and (spread_angle / (count - 1)) or 0

    local signal = require("external.hump.signal")
    for i = 0, count - 1 do
        local angle = start_angle + angle_step * i
        signal.emit("spawn_enemy_projectile", {
            x = pos.x,
            y = pos.y,
            dir_x = math.cos(angle),
            dir_y = math.sin(angle),
            preset = preset or "enemy_basic_shot",
            damage = damage or 10,
            source = e,
        })
    end
end

--- Fire projectiles in a ring pattern (360 degrees)
--- @param e number Entity ID (source)
--- @param preset string Projectile preset name
--- @param damage number Damage per projectile
--- @param count number Number of projectiles
function WaveHelpers.fire_projectile_ring(e, preset, damage, count)
    if not entity_cache.valid(e) then return end
    local pos = WaveHelpers.get_entity_position(e)
    if not pos then return end

    count = count or 8
    local angle_step = (math.pi * 2) / count

    local signal = require("external.hump.signal")
    for i = 0, count - 1 do
        local angle = angle_step * i
        signal.emit("spawn_enemy_projectile", {
            x = pos.x,
            y = pos.y,
            dir_x = math.cos(angle),
            dir_y = math.sin(angle),
            preset = preset or "enemy_basic_shot",
            damage = damage or 10,
            source = e,
        })
    end
end

--- Get player velocity (for leading shots)
--- @return table { x, y } velocity or { x = 0, y = 0 }
function WaveHelpers.get_player_velocity()
    if not _G.survivorEntity or not entity_cache.valid(_G.survivorEntity) then
        return { x = 0, y = 0 }
    end
    -- Try to get velocity from physics body
    local vel = { x = 0, y = 0 }
    if physics and physics.get_velocity then
        local vx, vy = physics.get_velocity(_G.survivorEntity)
        if vx and vy then
            vel.x, vel.y = vx, vy
        end
    end
    return vel
end

--============================================
-- COMBAT HELPERS
--============================================

function WaveHelpers.deal_damage_to_player(damage)
    if not _G.survivorEntity or not entity_cache.valid(_G.survivorEntity) then return end
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

    signal.emit("explosion", { x = pos.x, y = pos.y, radius = radius, damage = damage, source = e })
end

--============================================
-- VISUAL HELPERS
--============================================

function WaveHelpers.spawn_telegraph(position, enemy_type, duration)
    duration = duration or 1.0
    signal.emit("spawn_telegraph", { x = position.x, y = position.y, enemy_type = enemy_type, duration = duration })
end

function WaveHelpers.show_floating_text(text, opts)
    opts = opts or {}
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

    signal.emit("spawn_particles", { effect = effect_name, x = pos.x, y = pos.y })
end

function WaveHelpers.screen_shake(duration, intensity)
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

function WaveHelpers.clear_shader(e)
    local ok, ShaderBuilder = pcall(require, "core.shader_builder")
    if ok and ShaderBuilder then
        ShaderBuilder.for_entity(e):clear():apply()
    end
end

--============================================
-- SPAWN POSITION HELPERS
--============================================

local function get_arena_bounds()
    local margin = 30
    return {
        left = (rawget(_G, "SCREEN_BOUND_LEFT") or 0) + margin,
        top = (rawget(_G, "SCREEN_BOUND_TOP") or 0) + margin,
        right = (rawget(_G, "SCREEN_BOUND_RIGHT") or 1280) - margin,
        bottom = (rawget(_G, "SCREEN_BOUND_BOTTOM") or 720) - margin
    }
end

local function clamp_to_arena(pos)
    local bounds = get_arena_bounds()
    return {
        x = math.max(bounds.left, math.min(bounds.right, pos.x)),
        y = math.max(bounds.top, math.min(bounds.bottom, pos.y))
    }
end

function WaveHelpers.get_spawn_positions(spawn_config, count)
    local positions = {}
    local config = spawn_config

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
            local pos = {
                x = player_pos.x + math.cos(angle) * radius,
                y = player_pos.y + math.sin(angle) * radius
            }
            table.insert(positions, clamp_to_arena(pos))
        end

    elseif config.type == "random_area" then
        local bounds = get_arena_bounds()
        local area = config.area or { x = bounds.left, y = bounds.top, w = bounds.right - bounds.left, h = bounds.bottom - bounds.top }
        for i = 1, count do
            local pos = {
                x = area.x + math.random() * area.w,
                y = area.y + math.random() * area.h
            }
            table.insert(positions, clamp_to_arena(pos))
        end

    elseif config.type == "fixed_points" then
        local points = config.points or {}
        for i = 1, count do
            local pt = points[((i - 1) % #points) + 1] or { 0, 0 }
            table.insert(positions, clamp_to_arena({ x = pt[1], y = pt[2] }))
        end

    elseif config.type == "off_screen" then
        local bounds = get_arena_bounds()
        local padding = config.padding or 50
        
        for i = 1, count do
            local side = math.random(1, 4)
            local pos = { x = 0, y = 0 }
            if side == 1 then
                pos.x = bounds.left + math.random() * (bounds.right - bounds.left)
                pos.y = bounds.top
            elseif side == 2 then
                pos.x = bounds.left + math.random() * (bounds.right - bounds.left)
                pos.y = bounds.bottom
            elseif side == 3 then
                pos.x = bounds.left
                pos.y = bounds.top + math.random() * (bounds.bottom - bounds.top)
            else
                pos.x = bounds.right
                pos.y = bounds.top + math.random() * (bounds.bottom - bounds.top)
            end
            table.insert(positions, pos)
        end
    end

    return positions
end

return WaveHelpers
