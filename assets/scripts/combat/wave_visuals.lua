-- assets/scripts/combat/wave_visuals.lua
-- Visual feedback handlers for wave system

local signal = require("external.hump.signal")
local timer = require("core.timer")
local entity_cache = require("core.entity_cache")
local component_cache = require("core.component_cache")
local Text = require("core.text")
local animation_system = _G.animation_system  -- C++ binding, exposed globally

local WaveVisuals = {}

--============================================
-- TEXT RECIPES (pre-defined for reuse)
--============================================

local waveAnnounceRecipe = Text.define()
    :content("%s")
    :size(32)
    :color("gold")
    :effects("wave")
    :anchor("center")
    :fade()
    :lifespan(1.5)
    :space("screen")

local eliteAnnounceRecipe = Text.define()
    :content("%s")
    :size(40)
    :color("red")
    :anchor("center")
    :fade()
    :lifespan(2.0)
    :space("screen")

local stageCompleteRecipe = Text.define()
    :content("%s")
    :size(36)
    :color("gold")
    :anchor("center")
    :fade()
    :lifespan(2.0)
    :space("screen")

local defaultTextRecipe = Text.define()
    :content("%s")
    :size(24)
    :color("white")
    :anchor("center")
    :fade()
    :lifespan(1.5)
    :space("screen")

--============================================
-- TELEGRAPH MARKER
--============================================

local active_telegraphs = {}

signal.register("spawn_telegraph", function(data)
    local x = data.x
    local y = data.y
    local duration = data.duration or 1.0
    local enemy_type = data.enemy_type

    -- Position and size constants
    local base_size = 48
    local spawn_x = x - base_size * 0.5
    local spawn_y = y - base_size * 0.5

    -- Create telegraph sprite at exact position (avoids first-frame pop)
    local marker = animation_system.createAnimatedObjectWithTransform(
        "spawn_telegraph.png",
        true,           -- forceSprite
        spawn_x,        -- x position
        spawn_y,        -- y position
        nil,            -- parent
        false           -- useRenderPosition
    )

    if not marker or not entity_cache.valid(marker) then
        print("[WaveVisuals] Failed to create telegraph marker")
        return
    end

    -- Ensure size is set correctly
    local transform = component_cache.get(marker, Transform)
    if transform then
        transform.actualW = base_size
        transform.actualH = base_size
    end

    -- Track for cleanup
    local telegraph_id = tostring(marker)
    active_telegraphs[telegraph_id] = {
        entity = marker,
        x = x,
        y = y,
        enemy_type = enemy_type,
        start_time = os.clock(),
        duration = duration,
    }

    -- Growing hollow circle animation
    local elapsed = 0
    local pulse_speed = 6
    local max_radius = 60
    local ring_thickness = 4
    local layers_ref = _G.layers

    timer.every_opts({
        delay = 0.016,
        action = function()
            if not entity_cache.valid(marker) then return false end
            elapsed = elapsed + 0.016

            if elapsed >= duration then
                -- Cleanup
                if registry and registry:valid(marker) then
                    registry:destroy(marker)
                end
                active_telegraphs[telegraph_id] = nil
                return false
            end

            -- Progress from 0 to 1
            local progress = elapsed / duration

            -- Pulse the sprite scale
            local pulse = 1.0 + math.sin(elapsed * pulse_speed) * 0.15
            local t = component_cache.get(marker, Transform)
            if t then
                t.actualW = base_size * pulse
                t.actualH = base_size * pulse
                -- Re-center after scale
                t.actualX = x - t.actualW * 0.5
                t.actualY = y - t.actualH * 0.5
            end

            -- Draw growing hollow circle
            if layers_ref and layers_ref.sprites and command_buffer then
                local current_radius = max_radius * progress
                -- Fade color as it grows (more visible at start)
                local alpha = math.floor(255 * (1 - progress * 0.7))
                local urgency = progress > 0.7 and 1 or 0
                local r = 255
                local g = math.floor(200 * (1 - urgency * 0.5))
                local b = math.floor(100 * (1 - urgency))

                command_buffer.queueDrawCircleLine(layers_ref.sprites, function(c)
                    c.x = x
                    c.y = y
                    c.innerRadius = math.max(0, current_radius - ring_thickness)
                    c.outerRadius = current_radius
                    c.startAngle = 0
                    c.endAngle = 360
                    c.segments = 48
                    c.color = Col(r, g, b, alpha)
                end, 100, layer.DrawCommandSpace.World)
            end
        end,
        tag = "telegraph_anim_" .. telegraph_id
    })
end)

--============================================
-- FLOATING TEXT
--============================================

-- Map style names to recipes
local styleRecipes = {
    wave_announce = waveAnnounceRecipe,
    elite_announce = eliteAnnounceRecipe,
    stage_complete = stageCompleteRecipe,
    default = defaultTextRecipe,
}

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

    -- Get the appropriate recipe for this style
    local recipe = styleRecipes[style] or styleRecipes.default

    -- Spawn the text using Text Builder
    recipe:spawn(text):at(x, y)
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
