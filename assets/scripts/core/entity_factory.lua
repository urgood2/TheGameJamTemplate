
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
            nil -- animation config
        )
    end
end

function spawnCurrencyAutoCollect(x, y, currencyName)
    local e = animation_system.createAnimatedObjectWithTransform(
        globals.currencies[currencyName].anim,
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
    
    local gameObjectState = nodeComp.state
    
    -- jigglle on spawn
    transform.InjectDynamicMotionDefault(e)
    
    log_debug("currency", currencyName, "clicked")
    -- Get the Transform component you use to track visual X/Y and size:
    local tc = registry:get(e, Transform)  -- or whatever its name is

    -- Compute the true on-screen center:
    local centerX = tc.visualX + tc.visualW * 0.5
    local centerY = tc.visualY + tc.visualH * 0.5
    -- spawn a growing circle particle
    
    local gameObjectComp = registry:get(e, GameObject)
    -- remove the click and hover enabled state
    
    transform.InjectDynamicMotion(e, 1, 50)
    
    timer.after(0.2, function()
        local transformComp = registry:get(e, Transform)
        -- send it to the top right corner of the screen
        -- local transformComp = registry:get(e, Transform)
        local targetTransform = registry:get(globals.currencies[currencyName].ui_icon_entity, Transform)
        
        transformComp.scale = 0.8
        transformComp.actualX = targetTransform.actualX
        transformComp.actualY = targetTransform.actualY
        
    end)
    
    log_debug("currency", currencyName, "remove timer added")
    -- remove some time later
    timer.after(0.8, function()
        local transformComp = registry:get(e, Transform)
        if (registry:valid(e) == true) then
            registry:destroy(e)
        end
        
        globals.currencies[currencyName].target = globals.currencies[currencyName].target + 1 -- increment the target amount
        
        -- make the target jiibble
        transform.InjectDynamicMotion(globals.currencies[currencyName].ui_icon_entity, 1, 50)

        -- tween the value of globals.whale_dust_amount from its current value to its current value + 1
        timer.tween(
            0.5, -- duration in seconds
            function() return globals.currencies[currencyName].amount end, -- getter
            function(v) globals.currencies[currencyName].amount = v end, -- setter
            globals.currencies[currencyName].target -- target value
        )
        
        local soundEffects = {
            "currency-click-1",
            "currency-click-2",
            "currency-click-3",
            "currency-click-4"
        }
        playSoundEffect("effects", random_utils.random_element_string(soundEffects)) -- play a random currency click sound effect
        
    end)
end

function spawnCurrency(x, y, currencyName)
    
    e = animation_system.createAnimatedObjectWithTransform(
        globals.currencies[currencyName].anim,
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
    
    playSoundEffect("effects", "item-drop") -- play the currency spawn sound effect
    
    table.insert(globals.currencies_not_picked_up[currencyName], e) -- add to the list of entities for this currency
    log_debug("currency", currencyName, "spawned at", x, y)
    gameObjectMethods.onClick = function(registry, e)
        
        log_debug("currency", currencyName, "clicked")
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
        
        log_debug("currency", currencyName, "motion injected")
        -- jiggle
        transform.InjectDynamicMotion(e, 1, 50)
        
        local transformComp = registry:get(e, Transform)
        transformComp.scale = 3 -- make it bigger
        spawnCircularBurstParticles(centerX, centerY, 10, 1.0)
        
        playSoundEffect("effects", "button-click") -- play a random currency click sound effect
            
        
        
        timer.after(0.2, function()
            -- send it to the top right corner of the screen
            -- local transformComp = registry:get(e, Transform)
            targetTransform = registry:get(globals.currencies[currencyName].ui_icon_entity, Transform)
            
            transformComp.scale = 0.8
            transformComp.actualX = targetTransform.actualX
            transformComp.actualY = targetTransform.actualY
            
        end)
        
        log_debug("currency", currencyName, "remove timer added")
        -- remove some time later
        timer.after(0.8, function()
            if (registry:valid(e) == true) then
                registry:destroy(e)
            end
            removeValueFromTable(globals.currencies_not_picked_up[currencyName], e) -- remove from the list of entities for this currency
            log_debug("currency", currencyName, "removed from not picked up list")
            
            globals.currencies[currencyName].target = globals.currencies[currencyName].target + 1 -- increment the target amount
            
            -- make the target jiibble
            transform.InjectDynamicMotion(globals.currencies[currencyName].ui_icon_entity, 1, 50)

            -- tween the value of globals.whale_dust_amount from its current value to its current value + 1
            timer.tween(
                0.5, -- duration in seconds
                function() return globals.currencies[currencyName].amount end, -- getter
                function(v) globals.currencies[currencyName].amount = v end, -- setter
                globals.currencies[currencyName].target, -- target value
                "whale_dust_increment"
            )
            
            
            
            local soundEffects = {
                "currency-click-1",
                "currency-click-2",
                "currency-click-3",
                "currency-click-4"
            }
            playSoundEffect("effects", random_utils.random_element_string(soundEffects)) -- play a random currency click sound effect
            
            
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

function spawnNewKrillAtLocation(x, y)
    local krill = spawnNewKrill() -- spawn a new krill
    local transform = registry:get(krill, Transform) -- get the transform component of the
    transform.actualX = x
    transform.actualY = y -- set its position to the given x and y
end

function spawnNewKrill()
    
    -- 1) Spawn a new kobold AI entity
    local kr = create_ai_entity("kobold")
    
    playSoundEffect("effects", "krill-spawn") -- play the krill spawn sound effect

    globals.entities.krill[#globals.entities.krill+1] = kr -- add to the global krill list

    local anim = random_utils.random_element_string({
        "krill_1_anim",
        "krill_2_anim",
        "krill_3_anim",
        "krill_4_anim"
    })

    -- 2) Set up its animation & sizing
    animation_system.setupAnimatedObjectOnEntity(
        kr,
        anim,
        false,
        nil,
        true
    )
    animation_system.resizeAnimationObjectsInEntityToFit(
        kr,
        30,
        30
    )
    
    -- make them hoverable
    local nodeComp = registry:get(kr, GameObject)
    local gameObjectState = nodeComp.state
    gameObjectState.hoverEnabled = true
    gameObjectState.collisionEnabled = true
    nodeComp.methods.onHover = function()
        -- log_debug("krill hovered!")
        showTooltip(
            localization.get("ui.space_krill_title"), 
            localization.get("ui.space_krill_body")
        )
    end
    -- nodeComp.methods.onStopHover = function()
    --     -- log_debug("krill stopped hovering!")
    --     -- reset the tooltip text
    --     hideTooltip()
    -- end
    
    -- kril shaders
    shaderPipelineComp = registry:emplace(kr, shader_pipeline.ShaderPipelineComponent)

    shaderPipelineComp:addPass("random_displacement_anim")

    -- 3) Randomize its start position
    local tr = registry:get(kr, Transform)
    tr.actualX = random_utils.random_int(200, globals.screenWidth() - 200)
    tr.actualY = random_utils.random_int(200, globals.screenHeight() - 200)

    -- 4) Schedule its own movement timer, with a tag unique to this instance
    timer.every(
        random_utils.random_float(0.5, 1.5), -- randomize the delay between 0.5 and 1.5 seconds
        function()
            -- get random whale from globals.entities.whales
            local whales = globals.entities.whales
            if #whales == 0 then
                return -- no whales to follow
            end
            local i = random_utils.random_int(1, #whales)
            local bowser = whales[i] -- get a random whale
            -- make the krill move a litlte toward the whale
            local whaleTransform = registry:get(bowser, Transform)
            local krillTransform = registry:get(kr, Transform)
            local directionX = whaleTransform.actualX - krillTransform.actualX
            local directionY = whaleTransform.actualY - krillTransform.actualY
            -- normalize manually with x and y comps
            local length = math.sqrt(directionX^2 + directionX^2)
            if length > 0 then
                directionX = directionX / length
                directionY = directionY / length
            end
            -- move the krill towards the whale
            krillTransform.actualX = krillTransform.actualX + directionX * 10 -- move 10 pixels towards the whale
            krillTransform.actualY = krillTransform.actualY + directionY * 10 -- move 10 pixels towards the whale
            
            -- if krill is close enough to the whale based onthe centers of both, call its onClick method
            whaleLoc = {
                x = whaleTransform.actualX + whaleTransform.visualW * 0.5,
                y = whaleTransform.actualY + whaleTransform.visualH * 0.5
            }
            krillLoc = {
                x = krillTransform.actualX + krillTransform.visualW * 0.5,
                y = krillTransform.actualY + krillTransform.visualH * 0.5
            }
            local distance = math.sqrt(
                (whaleLoc.x - krillLoc.x)^2 + (whaleLoc.y - krillLoc.y)^2
            )
            if distance < globals.krill_tickle_distance then
                -- call the onClick method of the whale
                local gameObjectComp = registry:get(bowser, GameObject)
                if gameObjectComp and gameObjectComp.methods and gameObjectComp.methods.onClick then
                    gameObjectComp.methods.onClick(registry, kr)
                end
                -- inject dynamic motion to the krill
                transform.InjectDynamicMotion(kr, 0.4, 15) -- add dynamic
                
                playSoundEffect("effects", "krill-hit") -- play the krill tickle sound effect
            end
            
        end,
        0,               -- infinite repetitions
        true,            -- start immediately
        nil,             -- no “after” callback
        "krill_move_timer_" .. #globals.entities.krill -- unique tag per krill
    )
    
    return kr
end



--------------------------------------------------------------------
-- 1. Define the script table that will live inside ScriptComponent
--------------------------------------------------------------------
local PlayerLogic = {
    -- Custom data carried by this table
    speed        = 150, -- pixels / second
    hp           = 10,

    -- Called once, right after the component is attached.
    init         = function(self)
        print("[player] init, entity-id =", self.id)
        self.x, self.y = 0, 0 -- give the table some state
    end,

    -- Called every frame by script_system_update()
    update       = function(self, dt)
        -- Simple movement example
        self.x = self.x + self.speed * dt
        -- print("[player] update; entity-id =", self.id, "position:", self.x, self.y)
        -- You still have full registry access through self.owner
        -- (e.g., self.owner:get(self.id, Transform).x = self.x)

        -- if not self._has_spawned_task then
        --     task.run_named_task(self, "blinker1", function()
        --         task.wait(5.0)
        --     end)

        --     task.run_named_task(self, "blinker2", function()
        --         task.wait(6.0)
        --     end)

        --     task.run_named_task(self, "blinker3", function()
        --         task.wait(7.0)
        --     end)

        --     self._has_spawned_task = true
        -- end

        -- if not self._spawned then
        --     for i, delay in ipairs({10, 20, 30}) do
        --       task.run_named_task(self, "t" .. i, function()
        --         print("▶︎ Task " .. i .. " start @ " .. tostring(os.clock()))
        --         --  os clock is imprecise, but the wait works as expected.
        --         task.wait(delay)
        --         print("✔︎ Task " .. i .. "  end @ " .. tostring(os.clock()))
        --       end)
        --     end
        --     self._spawned = true
        --   end
    end,

    on_collision = function(self, other)
        -- Called when this entity collides with another entity
        -- other is the other entity's id
        -- print("[player] on_collision; entity-id =", self.id, "collided with", other)
    end,

    -- Called just before the entity is destroyed
    destroy      = function(self)
        print("[player] destroy; final position:", self.x, self.y)
    end
}

function spawnNewWhale() 
    
    bowser = create_ai_entity("kobold")      -- Create a new entity of ai type kobold
    
    globals.entities.whales[#globals.entities.whales+1] = bowser -- add to the global whales list

    registry:add_script(bowser, PlayerLogic) -- Attach the script to the entity

    animation_system.setupAnimatedObjectOnEntity(
        bowser,
        "blue_whale_anim", -- Default animation ID
        false,             -- ? generate a new still animation from sprite, don't set to true, causes bug
        nil,               -- shader_prepass, -- Optional shader pass config function
        true               -- Enable shadow
    )

    animation_system.resizeAnimationObjectsInEntityToFit(
        bowser,
        120, -- Width
        120  -- Height
    ) 
    
    local collider = collision.create_collider_for_entity(bowser, {width = 50, height = 50, alignment = AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_BOTTOM})
    
    collision.resetCollisionCategory(collider, "playerColliderTest")
    collision.setCollisionMask(collider, "enemy") -- there is no enemy
    
    -- give it a ScriptComponent with an onCollision method
    local ColliderLogic = {
        -- Custom data carried by this table
        speed        = 150, -- pixels / second
        hp           = 10,
        selfEntityHandle = bowser, -- reference to the  entity

        -- Called once, right after the component is attached.
        init         = function(self)
        end,

        -- Called every frame by script_system_update()
        update       = function(self, dt)
        end,

        on_collision = function(self, other)
            log_debug("whale", bowser, "collided with", other)
        end,

        -- Called just before the entity is destroyed
        destroy      = function(self)
        end
    }
    registry:add_script(collider, ColliderLogic) -- Attach the script to the entity

    transformComp = registry:get(bowser, Transform)
    nodeComp = registry:get(bowser, GameObject)
    
    gameObjectState = nodeComp.state
    gameObjectState.clickEnabled = true
    gameObjectState.hoverEnabled = true
    -- gameObjectState.dragEnabled = true
    gameObjectState.collisionEnabled = true
    
    local methods = nodeComp.methods
    
    -- log_debug(methods)
    
    methods.onHover = function()
        -- log_debug("whale hovered!")
        showTooltip(
            localization.get("ui.whale_title"), 
            localization.get("ui.whale_body")
        )
        
    end
    -- methods.onStopHover = function()
    --     -- log_debug("whale stopped hovering!")
    --     -- reset the tooltip text
        
    --     -- hide the tooltip UI box
        
    --     hideTooltip()
    -- end
    methods.onClick = function(registry, e) 
        log_debug("whale clicked!")
        
        transform.InjectDynamicMotion(e, 0.4, 15) -- add dynamic motion to the whale
        
        playSoundEffect("effects", "whale-click") -- play the whale hit sound effect
        
        local transformComp = registry:get(e, Transform)
        
        spawnCurrency(transformComp.actualX + random_utils.random_int(50, 100),
                        transformComp.actualY + random_utils.random_int(50, 100),
                        "whale_dust")
    end

    shaderPipelineComp = registry:emplace(bowser, shader_pipeline.ShaderPipelineComponent)
    
    -- shaderPipelineComp:addPass("flash")
    -- shaderPipelineComp:addPass("random_displacement_anim")
    -- shaderPipelineComp:addPass("negative_shine")

    transformComp.actualX = 800
    transformComp.actualY = 800
    -- transformComp.actualW = 100
    -- transformComp.actualH = 100
    
    -- ===================================================================
-- 1. Configuration Parameters (Tweak these to change the effect!)
-- ===================================================================

    -- Define the center of the orbit (e.g., the center of the screen)
    -- NOTE: Replace 800 and 600 with your actual screen dimensions!
    local centerX = globals.screenWidth() / 2
    local centerY = globals.screenHeight() / 2

    -- Orbit properties
    local orbitRadius = 200.0  -- How far from the center to orbit, in pixels.
    local baseSpeed = 0.1      -- The average speed of the orbit (in radians per second).

    -- Speed fluctuation properties
    local speedFluctuationAmount = 0.8 -- How much the speed varies. 0 is constant, 1 is drastic.
    local speedFluctuationFrequency = 0.5 -- How quickly the speed oscillates. Higher is faster.

    -- ===================================================================
    -- 2. State Variables (Do not change these)
    -- ===================================================================
    -- We define these outside the timer's function so they "remember" their
    -- values between each call.
    local orbitAngle = 0.0     -- The current angle on the circle, in radians.
    local elapsedTime = 0.0    -- A simple clock to drive the speed fluctuation.
    local currentSpeed = baseSpeed
    
    local loopDelta = 0.01 -- How often to update the position, in seconds.
    -- use a timer to update the position of Bowser every second
    timer.every(loopDelta, function()
        
        local transformComp = registry:get(bowser, Transform)
       
        -- Step A: Update the total elapsed time for this effect
        elapsedTime = elapsedTime + loopDelta

        -- Step B: Calculate the speed fluctuation using a sine wave
        -- This creates a smooth "breathing" or "pulsing" effect for the speed.
        local speedModifier = math.sin(elapsedTime * speedFluctuationFrequency)
        currentSpeed = baseSpeed + (speedFluctuationAmount * speedModifier)
        
        -- Step C: Update the orbit angle based on the current speed
        -- We multiply by dt to ensure the speed is consistent regardless of the timer interval.
        orbitAngle = orbitAngle + (currentSpeed * loopDelta)
        
        -- Step D: Calculate the new X and Y position on the circle using trigonometry
        local newX = centerX + orbitRadius * math.cos(orbitAngle)
        local newY = centerY + orbitRadius * math.sin(orbitAngle)
        
        -- Step E: Apply the new position directly to the transform component
        transformComp.actualX = newX
        transformComp.actualY = newY        
        end, 0, true, nil, "bowser_timer")
    
    -- every now and then, make the whale sing.
    
    timer.every(
    --TODO: the dealy should be configurable 
        random_utils.random_float(20, 30),
        function()
            
            -- timer after to rotate the whale
            timer.after(
                0.5, -- delay in seconds
                function()
                    local transform = registry:get(bowser, Transform)
                    transform.rotation = transform.rotation - 30
                    
                    timer.tween(
                        0.5, -- duration in seconds
                        function() return getTrackVolume("whale-song") end, -- getter
                        function(v) setTrackVolume("whale-song", v) end, -- setter
                        1 -- target value
                    )
                
                end,
                "whale_rotate_after"
            )
            
            timer.after(
                0.8, -- delay in seconds
                function()
                    
                    
                    -- spawn particles 
                    timer.after(
                        0.1, -- delay in seconds
                        function()
                            local transform = registry:get(bowser, Transform)
                            -- spawn particles 
                            spawnCircularBurstParticles(
                                transform.actualX +transform.actualW / 2 ,
                                transform.actualY + transform.actualH / 2 ,
                                40, -- number of particles
                                1 
                            )
                        end,
                        nil
                    )
                    
                    timer.after(
                        0.2, -- delay in seconds
                        function()
                            local transform = registry:get(bowser, Transform)
                            -- spawn particles 
                            spawnCircularBurstParticles(
                                transform.actualX + transform.actualW / 2 ,
                                transform.actualY + transform.actualH / 2 ,
                                40, -- number of particles
                                0.3 
                            )
                        end,
                        nil
                    )
                    
                    timer.after(
                        0.3, -- delay in seconds
                        function()
                            local transform = registry:get(bowser, Transform)
                            -- spawn particles 
                            spawnCircularBurstParticles(
                                transform.actualX + transform.actualW / 2 ,
                                transform.actualY + transform.actualH / 2 ,
                                40, -- number of particles
                                1.5 
                            )
                        end,
                        nil
                    )
                    
                    timer.after(
                        0.9, -- delay in seconds
                        function()
                            local transform = registry:get(bowser, Transform)
                            -- spawn particles 
                            spawnGrowingCircleParticle(
                                transform.actualX,
                                transform.actualY,
                                100, -- width
                                100, -- height
                                1 -- seconds to grow
                            )
                        end,
                        nil
                    )
                    
                    timer.after(
                        1.5, -- delay in seconds
                        function()
                            local transform = registry:get(bowser, Transform)
                            -- spawn particles 
                            spawnCircularBurstParticles(
                                transform.actualX + transform.actualW / 2 ,
                                transform.actualY + transform.actualH / 2 ,
                                40, -- number of particles
                                1.5 
                            )
                        end,
                        nil
                    )
                    
                    timer.after(
                        2.1, -- delay in seconds
                        function()
                            local transform = registry:get(bowser, Transform)
                            -- spawn particles 
                            spawnCircularBurstParticles(
                                transform.actualX + transform.actualW / 2 ,
                                transform.actualY + transform.actualH / 2 ,
                                40, -- number of particles
                                1.5 
                            )
                        end,
                        nil
                    )
                    
                    timer.after(
                        2.9, -- delay in seconds
                        function()
                            local transform = registry:get(bowser, Transform)
                            -- spawn particles 
                            spawnCircularBurstParticles(
                                transform.actualX + transform.actualW / 2 ,
                                transform.actualY + transform.actualH / 2 ,
                                40, -- number of particles
                                1.5 
                            )
                        end,
                        nil
                    )
                    timer.after(
                        3.5, -- delay in seconds
                        function()
                            local transform = registry:get(bowser, Transform)
                            -- spawn particles 
                            spawnGrowingCircleParticle(
                                transform.actualX,
                                transform.actualY,
                                100, -- width
                                100, -- height
                                1 -- seconds to grow
                            )
                        end,
                        nil
                    )
                    timer.after(
                        3.9, -- delay in seconds
                        function()
                            local transform = registry:get(bowser, Transform)
                            -- spawn particles 
                            spawnCircularBurstParticles(
                                transform.actualX + transform.actualW / 2 ,
                                transform.actualY + transform.actualH / 2 ,
                                40, -- number of particles
                                1.5 
                            )
                        end,
                        nil
                    )
                    timer.after(
                        4.0, -- delay in seconds
                        function()
                            local transform = registry:get(bowser, Transform)
                            -- spawn particles 
                            spawnCircularBurstParticles(
                                transform.actualX + transform.actualW / 2 ,
                                transform.actualY + transform.actualH / 2 ,
                                40, -- number of particles
                                1.5 
                            )
                        end,
                        nil
                    )
                    timer.after(
                        4.3, -- delay in seconds
                        function()
                            local transform = registry:get(bowser, Transform)
                            -- spawn particles 
                            spawnCircularBurstParticles(
                                transform.actualX + transform.actualW / 2 ,
                                transform.actualY + transform.actualH / 2 ,
                                40, -- number of particles
                                1.5 
                            )
                        end,
                        nil
                    )
                    timer.after(
                        4.4, -- delay in seconds
                        function()
                            local transform = registry:get(bowser, Transform)
                            -- spawn particles 
                            spawnCircularBurstParticles(
                                transform.actualX + transform.actualW / 2 ,
                                transform.actualY + transform.actualH / 2 ,
                                40, -- number of particles
                                1.5 
                            )
                        end,
                        nil
                    )
                end,
                "whale_particles"
            )
            
            timer.after(
                5.0, -- delay in seconds
                function()
                    local transformComp = registry:get(bowser, Transform)
                    transformComp.rotation = 0 -- reset rotation
                    
                    timer.tween(
                        2.0, -- duration in seconds
                        function() return getTrackVolume("whale-song") end, -- getter
                        function(v) setTrackVolume("whale-song", v) end, -- setter
                        0 -- target value
                    )
                    
                    -- are there any song collectors?
                    if globals.buildings.whale_song_gatherer then
                        -- for each whale song gatherer
                        for _, whaleSongGatherer in ipairs(globals.buildings.whale_song_gatherer) do
                            -- call the whale song gatherer's onClick method
                            
                            -- jiggle and add a currency
                            transform.InjectDynamicMotion(whaleSongGatherer, 0.9, 1)
                            
                            local whalesonggathererTransform = registry:get(whaleSongGatherer, Transform)
                            
                            spawnCurrencyAutoCollect(whalesonggathererTransform.actualX, whalesonggathererTransform.actualY,
                             "song_essence")
                            
                        end
                        
                    end
                end,
                "whale_rotate_after_particles"
            )
            
            -- tween volume of whale sound
            -- TODO:
        end,
        0,               -- infinite repetitions
        true,            -- start immediately
        nil,             -- no “after” callback
        "whale_move_timer" -- unique tag per krill
    )
    
    
end