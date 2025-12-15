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
