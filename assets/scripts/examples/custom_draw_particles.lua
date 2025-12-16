-- assets/scripts/examples/custom_draw_particles.lua
--[[
Example: Custom Draw Commands for Particles

This demonstrates Task 17 - storing custom draw commands in particle recipes.
The actual rendering integration will be completed in Task 18.

Usage in game code:

    local Particles = require("core.particles")
    local draw = require("core.draw")

    -- Example 1: Text particles (damage numbers)
    local damageText = Particles.define()
        :size(16)
        :lifespan(1)
        :velocity(0, -50)
        :fade()
        :drawCommand(function(particle, props)
            draw.textPro(props.layer, {
                text = "+1",
                x = particle.x,
                y = particle.y,
                fontSize = particle.size,
                color = { particle.r, particle.g, particle.b, particle.alpha }
            }, props.z, props.space)
        end)

    -- Spawn text particle
    damageText:burst(1):at(playerX, playerY)

    -- Example 2: Custom shape particles
    local starParticle = Particles.define()
        :size(8, 16)
        :lifespan(0.5)
        :velocity(100, 200)
        :fade()
        :spin(180)
        :drawCommand(function(particle, props)
            -- Draw a star shape
            local points = 5
            for i = 0, points * 2 - 1 do
                local angle = (i * math.pi) / points
                local radius = (i % 2 == 0) and particle.size or particle.size * 0.5
                local x = particle.x + math.cos(angle) * radius
                local y = particle.y + math.sin(angle) * radius
                -- Would use draw commands here
            end
        end)

    -- Example 3: Sprite particles (using animation system)
    local coinParticle = Particles.define()
        :size(16)
        :lifespan(2)
        :velocity(50, 150)
        :gravity(200)
        :bounce(0.5)
        :drawCommand(function(particle, props)
            -- Draw animated coin sprite at particle position
            draw.sprite(props.layer, {
                spriteId = "coin",
                x = particle.x,
                y = particle.y,
                scale = particle.scale or 1.0,
                alpha = particle.alpha
            }, props.z, props.space)
        end)

    -- Example 4: Emoji particles
    local emojiParticle = Particles.define()
        :size(24)
        :lifespan(1.5)
        :velocity(0, -30)
        :fade()
        :drawCommand(function(particle, props)
            local emoji = particle.emoji or "❤️"
            draw.textPro(props.layer, {
                text = emoji,
                x = particle.x,
                y = particle.y,
                fontSize = particle.size,
                color = { 255, 255, 255, particle.alpha }
            }, props.z, props.space)
        end)

    -- Spawn different emojis using each()
    emojiParticle:burst(5):each(function(i, total)
        local emojis = { "❤️", "⭐", "💥", "✨", "🔥" }
        return { emoji = emojis[i] }
    end):at(x, y)

Note: The particle table passed to drawCommand includes:
    - x, y: position
    - size: current size (accounting for grow/shrink)
    - r, g, b, alpha: current color values
    - scale: scale factor (if using grow())
    - rotation: current rotation (if using spin())
    - age: lifetime progress (0-1)
    - velocity: { x, y }

The props table includes:
    - layer: rendering layer
    - z: draw order
    - space: coordinate space ("world" or "screen")
]]

-- This is just documentation - no executable code needed
return {}
