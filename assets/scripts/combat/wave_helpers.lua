-- assets/scripts/combat/wave_helpers.lua
-- Helper functions for enemy movement, combat, and visuals

local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
local timer = require("core.timer")

-- Localize globals for performance
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
        local screen_w = globals.screenWidth and globals.screenWidth() or 800
        local screen_h = globals.screenHeight and globals.screenHeight() or 600

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

return WaveHelpers
