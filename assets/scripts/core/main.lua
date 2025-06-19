local globals = require("init.globals")
require("registry")
local task = require("task.task")
require("ai.init") -- Read in ai scripts and populate the ai table
require("util.util")
local shader_prepass = require("shaders.prepass_example")
require("core.entity_factory")
-- Represents game loop main module
main = {}


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

-- Wraps v into the interval [−size, limit]
local function wrap(v, size, limit)
    if v > limit          then return -size end
    if v < -size           then return limit end
    return v
  end
  
function main.init()
    
    -- Add black hole to the center of the screen
    black_hole = create_ai_entity("kobold")
    
    animation_system.setupAnimatedObjectOnEntity(
        black_hole,
        "black_hole_anim", -- Default animation ID
        false,             -- ? generate a new still animation from sprite, don't set to true, causes bug
        nil,               -- shader_prepass, -- Optional shader pass config function
        true               -- Enable shadow
    )
    
    blackholePipeline = registry:emplace(black_hole, shader_pipeline.ShaderPipelineComponent)
    blackHoleAnimPass = blackholePipeline:addPass("random_displacement_anim", true)-- inject atlas uniforms into the shader pass to allow it to be atlas aware
    
    -- make it spin
    timer.every(
        0.1, -- every 0.1 seconds
        function()
            local transform = registry:get(black_hole, Transform)
            transform.rotation = transform.rotation + 10 -- rotate by 10 degrees
        end,
        0, -- infinite repetitions
        true, -- start immediately
        nil, -- no "after" callback
        "black_hole_spin"
    )
    
    black_hole_transform = registry:get(black_hole, Transform)
    black_hole_transform.actualX = globals.screenWidth / 2 - black_hole_transform.actualW / 2
    black_hole_transform.actualY = globals.screenHeight / 2 - black_hole_transform.actualH / 2
    
    
    -- TODO: not working, need to debug why texture particle not showing
    -- local black_hole_particle = particle.CreateParticle(
    --     Vec2(black_hole_transform.actualX,black_hole_transform.actualY),             -- world position
    --     Vec2(300,300),                 -- render size
    --     {
    --         renderType = particle.ParticleRenderType.RECTANGLE_LINE,
    --         velocity   = Vec2(0,0),
    --         acceleration = 0, 
    --         lifespan   = -1, -- lives forever
    --         color = util.getColor("WHITE"),
    --         rotationSpeed = 360,
    --         onUpdateCallback = function(particleComp, dt)
    --             -- make the rotation speed undulate over time
    --             local frequency = 2.0 -- controls how fast the undulation happens
    --             local amplitude = 50  -- controls the range of speed variation
    --             particleComp.rotationSpeed = 360 + math.sin(os.clock() * frequency) * amplitude
    --             particleComp.scale = 1.0 + math.sin(os.clock() * frequency) * 0.1 -- make it pulse
                
    --         end,
    --     },
    --     {animationName = "black_hole_particle_anim"} -- optional animation info
    -- )
    
    -- -- create whale
    bowser = create_ai_entity("kobold")      -- Create a new entity of ai type kobold

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

    -- create some krill entities
    local num_krill = 10
    local krill_entities = {}

    for i = 1, num_krill do
        -- 1) Spawn a new kobold AI entity
        local kr = create_ai_entity("kobold")
        krill_entities[#krill_entities + 1] = kr

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
        
        -- kril shaders
        shaderPipelineComp = registry:emplace(kr, shader_pipeline.ShaderPipelineComponent)
    
        shaderPipelineComp:addPass("random_displacement_anim")

        -- 3) Randomize its start position
        local tr = registry:get(kr, Transform)
        tr.actualX = random_utils.random_int(200, globals.screenWidth - 200)
        tr.actualY = random_utils.random_int(200, globals.screenHeight - 200)

        -- 4) Schedule its own movement timer, with a tag unique to this instance
        timer.every(
            random_utils.random_float(0.5, 1.5), -- randomize the delay between 0.5 and 1.5 seconds
            function()
                -- re-grab its transform each tick (in case component moved or was removed)
                local t = registry:get(kr, Transform)
                t.actualX = t.actualX + random_utils.random_int(-30, 30)
                t.actualY = t.actualY + random_utils.random_int(-30, 30)
            end,
            0,               -- infinite repetitions
            true,            -- start immediately
            nil,             -- no “after” callback
            "krill_move_timer_" .. i -- unique tag per krill
        )
    end



    -- add optional fullscreen shader which will be applied to the whole screen, can be removed later
    -- add_fullscreen_shader("flash")
    add_fullscreen_shader("shockwave")
    add_fullscreen_shader("tile_grid_overlay") -- to show tile grid
    

    -- add shader to specific layer

    debug(layers)
    debug(layers.sprites)
    
    -- layers.sprites:addPostProcessShader("flash")

    -- shader uniform manipulation example

    timer.every(5.0, function()
        -- spawn a new timer that tweens the shader uniform
        -- Example 1: fixed 2-second tween
        globalShaderUniforms:set("shockwave", "radius", 0)
        timer.tween(
            5,                                                                     -- duration in seconds
            function() return globalShaderUniforms:get("shockwave", "radius") end, -- getter
            function(v) globalShaderUniforms:set("shockwave", "radius", v) end,    -- setter
            2.0                                                                    -- target_value
        )
    end, 0, true, nil, "shockwave_uniform_tween")
    
    local p = particle.CreateParticle(
        Vec2(200,200),             -- world position
        Vec2(30,30),                 -- render size
        {
            renderType = particle.ParticleRenderType.RECTANGLE_FILLED,
            -- velocity   = Vec2(0,-10), random
            acceleration = 3.0, -- gravity effect
            lifespan   = 30.0,
            startColor = util.getColor("BLUE"),
            endColor   = util.getColor("RED"),
            rotationSpeed = 360,
            onUpdateCallback = function(particleComp, dt)
                
                --  make size smaller over time
                particleComp.scale = particleComp.scale - (dt * 0.1)
                
                if particleComp.scale < 0.1 then
                    particleComp.scale = 0.0 -- prevent it from going too small
                end
                
                -- debug("particleComp.scale = ", particleComp.scale)
                
                -- spin faster over time
                particleComp.rotationSpeed = particleComp.rotationSpeed + (dt * 20)
                
            end,
        },
        nil -- optional animation info
    )
    
    -- ui
    
    local sliderTextMoving = ui.definitions.getNewDynamicTextEntry(
        localization.get("ui.slider_text"),  -- initial text
        20.0,                                 -- font size
        nil,                                  -- no style override
        "pulse=0.9,1.1"                       -- animation spec
    )
    
    sliderTextMoving.config.initFunc = function(registry, entity)
        localization.onLanguageChanged(function(newLang)
            TextSystem.Functions.setText(entity, localization.get("ui.slider_text"))
        end)
    end
    
    local sliderTemplate = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("GRAY"))
            :addProgressBarMaxValue(100.0)
            :addMinHeight(50)
            :addNoMovementWhenDragged(true)
            :addMinWidth(500)
            :addProgressBar(true)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addProgressBarEmptyColor(util.getColor("WHITE"))
            :addProgressBarFullColor(util.getColor("BLUE"))
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(sliderTextMoving)
    :build()
    
    local newRoot =  UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.ROOT)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("GRAY"))
            :addMinHeight(50)
            :addMinWidth(500)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(sliderTemplate)
    :build()
    
    
    -- dump(ui.box)
    debug(ui)
    debug(ui.element)
    -- dump(newRoot)
    
    local newUIBox = ui.box.Initialize({x = 600, y = 10}, newRoot)
    

    -- manipulate the transformComp
    transformComp = registry:get(bowser, Transform)
    nodeComp = registry:get(bowser, GameObject)
    
    gameObjectState = nodeComp.state
    gameObjectState.clickEnabled = true
    gameObjectState.hoverEnabled = true
    -- gameObjectState.dragEnabled = true
    gameObjectState.collisionEnabled = true
    
    local methods = nodeComp.methods
    
    debug (methods)
    methods.onClick = function(registry, e) 
        debug("whale clicked!")
        
        transform.InjectDynamicMotion(e, 1, 90) -- add dynamic motion to the whale
        
        local transformComp = registry:get(e, Transform)
        
        spawnWhaleDust(transformComp.actualX + random_utils.random_int(50, 100),
                        transformComp.actualY + random_utils.random_int(50, 100))
    end

    shaderPipelineComp = registry:emplace(bowser, shader_pipeline.ShaderPipelineComponent)
    
    shaderPipelineComp:addPass("flash")
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
    local centerX = globals.screenWidth / 2
    local centerY = globals.screenHeight / 2

    -- Orbit properties
    local orbitRadius = 300.0  -- How far from the center to orbit, in pixels.
    local baseSpeed = 0.1      -- The average speed of the orbit (in radians per second).

    -- Speed fluctuation properties
    local speedFluctuationAmount = 0.5 -- How much the speed varies. 0 is constant, 1 is drastic.
    local speedFluctuationFrequency = 1.0 -- How quickly the speed oscillates. Higher is faster.

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

    -- add a task to the scheduler that will fade out the screen for 5 seconds
    local p1 = {
        update = function(self, dt)
            debug("Fade out screen")
            -- fadeOutScreen(0.1)
            add_fullscreen_shader("screen_tone_transition") -- Add the fade out shader
            globalShaderUniforms:set("screen_tone_transition", "position", 0) -- Set initial value to 1.0 (dark)
            -- timer tween
            timer.tween(
                2.0, -- duration in seconds
                function() return globalShaderUniforms:get("screen_tone_transition", "position") end, -- getter
                function(v) globalShaderUniforms:set("screen_tone_transition", "position", v) end, -- setter
                1.0 -- target value
            )
            task.wait(5.0)
        end
    }

    local p2 = {
        update = function(self, dt)
            -- fadeInScreen(1)
            remove_fullscreen_shader("screen_tone_transition") -- Remove the fade out shader
        end
    }

    scheduler:attach(p1, p2)


    -- assert(registry:has(bowser, Transform))


    -- assert(not registry:any_of(bowser, -1, -2))

    -- transform = registry:get(bowser, Transform)
    -- transform.actualX = 10
    -- print('Bowser position = ' .. transform.actualX .. ', ' .. transform.actualY)

    -- testing


    -- dump(ai)

    -- print("DEBUG: ActionResult.SUCCESS is", type(ActionResult.SUCCESS), ActionResult.SUCCESS)


    -- scheduler example

    local p1 = {
        update = function(self, dt)
            debug("Task 1 Start")
            task.wait(5.0)
            debug("Task 1 End after 5s")
        end
    }

    local p2 = {
        update = function(self, dt)
            debug("Task 2 Start")
            task.wait(5.0)
            debug("Task 2 End after 5s")
        end
    }

    local p3 = {
        update = function(self, dt)
            debug("Task 3 Start")
            task.wait(10.0)
            debug("Task 3 End after 10s")
        end
    }
    scheduler:attach(p1, p2, p3)
end

function main.update(dt)
    -- entity iteration example
    -- local view = registry:runtime_view(Transform)
    -- assert(view:size_hint() > 0)

    -- -- local koopa = registry:create()
    -- registry:emplace(koopa, Transform(100, -200))
    -- transform = registry:get(koopa, Transform)
    -- print('Koopa position = ' .. tostring(transform))

    -- assert(view:size_hint() == 2)

    -- view:each(function(entity)
    --     print('Iterating Transform entity: ' .. entity)
    --     -- registry:remove(entity, Transform)
    -- end)

    -- -- assert(view:size_hint() == 0)
    -- print ('All Transform entities processed, view size: ' .. view:size_hint())
end

function main.draw(dt)
    -- This is where you would handle rendering logic
    -- For now, we just print a message
    -- print("Drawing frame with dt: " .. dt)
end
