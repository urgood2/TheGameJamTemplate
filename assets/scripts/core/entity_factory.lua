
function spawnCircularBurstParticles(x, y, count, seconds)
    local initialSize   = 10             -- starting diameter of each circle
    local burstSpeed    = 200           -- pixels per second
    local growRate      = 20            -- how fast scale increases (same as your other function)
    local rotationSpeed = 460           -- same rotation speed

    for i = 1, count do
        -- random angle in [0,2π)
        local angle = math.random() * (2 * math.pi)
        local vx    = math.cos(angle) * burstSpeed
        local vy    = math.sin(angle) * burstSpeed

        particle.CreateParticle(
            Vec2(x, y),                 -- start at the center
            Vec2(initialSize, initialSize),
            {
                renderType     = particle.ParticleRenderType.RECTANGLE_FILLED,
                velocity       = Vec2(vx, vy),
                acceleration   = 0,      -- no gravity
                lifespan       = seconds,
                startColor     = util.getColor("WHITE"),
                endColor       = util.getColor("WHITE"),
                rotationSpeed  = rotationSpeed,
                onUpdateCallback = function(comp, dt)
                end,
            },
            nil -- no animation
        )
    end
end

function spawnWhaleDust(x, y)
    e = animation_system.createAnimatedObjectWithTransform(
        "whale_dust_anim",
        false,
        x, 
        y, 
        nil, -- shader pass
        true -- shadow
    )
    
    animation_system.resizeAnimationObjectsInEntityToFit(
        e,
        40, -- Width
        40  -- Height
    ) 
    
    -- jigglle on spawn
    transform.InjectDynamicMotionDefault(e)
    
    nodeComp = registry:get(e, GameObject)
    
    gameObjectState = nodeComp.state
    gameObjectState.clickEnabled = true
    gameObjectState.hoverEnabled = true
    gameObjectState.collisionEnabled = true
    
    gameObjectMethods = nodeComp.methods
    gameObjectMethods.onClick = function(registry, e)
        
        debug("whale dust clicked")
        -- Get the Transform component you use to track visual X/Y and size:
        local tc = registry:get(e, Transform)  -- or whatever its name is

        -- Compute the true on-screen center:
        local centerX = tc.visualX + tc.visualW * 0.5
        local centerY = tc.visualY + tc.visualH * 0.5
        -- spawn a growing circle particle
        
        local gameObjectComp = registry:get(e, GameObject)
        -- remove the click and hover enabled state
        gameObjectComp.state.clickEnabled = false
        gameObjectComp.state.hoverEnabled = false
        gameObjectComp.state.collisionEnabled = false
        
        spawnGrowingCircleParticle(centerX, centerY, 100, 100, 0.2)
        
        debug("whale dust motion injected")
        -- jiggle
        transform.InjectDynamicMotion(e, 1, 50)
        
        local transformComp = registry:get(e, Transform)
        transformComp.scale = 3 -- make it bigger
        spawnCircularBurstParticles(centerX, centerY, 10, 1.0)
        
        
        timer.after(0.8, function()
            -- send it to the top right corner of the screen
            -- local transformComp = registry:get(e, Transform)
            targetTransform = registry:get(globals.currencyIconForText, Transform)
            
            transformComp.scale = 0.8
            transformComp.actualX = targetTransform.actualX
            transformComp.actualY = targetTransform.actualY
            
        end)
        
        debug("whale dust remove timer added")
        -- remove some time later
        timer.after(1.5, function()
            if (registry:valid(e) == true) then
                registry:destroy(e)
            end
            
            -- make the target jiibble
            transform.InjectDynamicMotion(globals.currencyIconForText, 1, 50)
            
            -- tween the value of globals.whale_dust_amount from its current value to its current value + 1
            globals.whale_dust_target = (globals.whale_dust_target or 0) + 1
            local targetAmount = globals.whale_dust_target
            timer.tween(
                0.5, -- duration in seconds
                function() return globals.whale_dust_amount end, -- getter
                function(v) globals.whale_dust_amount = v end, -- setter
                globals.whale_dust_target, -- target value
                "whale_dust_increment"
            )
            
        end)
    end
end


function spawnGrowingCircleParticle(centerX, centerY, w, h, seconds)
    -- Compute top-left so that the internal DrawCircle(x + w*0.5, y + h*0.5, ...)
    -- will end up at (centerX, centerY)
    local halfW, halfH = w * 0.5, h * 0.5
    local p = particle.CreateParticle(
        Vec2(centerX - halfW, centerY - halfH),  -- world position = top-left
        Vec2(w, h),                               -- render size
        {
            renderType = particle.ParticleRenderType.CIRCLE_LINE,
            velocity      = Vec2(0,0), 
            acceleration  = 0,
            lifespan      = seconds,
            startColor    = util.getColor("WHITE"),
            endColor      = util.getColor("WHITE"),
            rotationSpeed = 460,
            onUpdateCallback = function(particleComp, dt)
                particleComp.scale = particleComp.scale + (dt * 10) 
            end,
        },
        nil
    )
    return p
end
