-- assets/scripts/combat/wave_visuals.lua
-- Visual feedback handlers for wave system

local signal = require("external.hump.signal")
local timer = require("core.timer")
local entity_cache = require("core.entity_cache")
local component_cache = require("core.component_cache")
local animation_system = _G.animation_system  -- C++ binding, exposed globally

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
    -- Try to create sprite, fallback gracefully if it doesn't exist
    local success, marker = pcall(function()
        if animation_system then
            return animation_system.createAnimatedObjectWithTransform(
                "telegraph_marker",  -- TODO: Replace with actual sprite name
                true
            )
        end
        return nil
    end)

    if not success or not marker or not entity_cache.valid(marker) then
        -- Fallback: just log it (sprite doesn't exist yet)
        print("[WaveVisuals] Telegraph at " .. x .. ", " .. y .. " for " .. tostring(enemy_type) .. " (no sprite)")
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
        local sw = globals.screenWidth and globals.screenWidth() or 800
        x = sw / 2
    end
    if not y then
        local sh = globals.screenHeight and globals.screenHeight() or 600
        y = sh / 3
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
    print("[FLOATING TEXT] " .. text .. " (style: " .. style .. ")")

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
    print("[PARTICLES] " .. effect .. " at " .. x .. ", " .. y)

    -- Example: signal.emit("create_particle_effect", effect, x, y)
end)

--============================================
-- SCREEN SHAKE (placeholder)
--============================================

signal.register("screen_shake", function(data)
    local duration = data.duration or 0.3
    local intensity = data.intensity or 5

    -- Integrate with your camera system
    print("[SCREEN SHAKE] duration=" .. duration .. " intensity=" .. intensity)

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
    print("[TRAP] spawned at " .. x .. ", " .. y .. " (damage=" .. damage .. ", lifetime=" .. lifetime .. ")")

    -- Implement trap entity creation based on your entity system
    -- Should have collision with player, deal damage on contact, despawn after lifetime
end)

--============================================
-- INIT
--============================================

function WaveVisuals.init()
    -- Any initialization needed
    print("WaveVisuals initialized")
end

return WaveVisuals
