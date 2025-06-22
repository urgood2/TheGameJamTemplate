require("init.globals")
require("registry")
local task = require("task.task")
require("ai.init") -- Read in ai scripts and populate the ai table
require("util.util")
require("ui.ui_defs")
local shader_prepass = require("shaders.prepass_example")
require("core.entity_factory")
-- Represents game loop main module
main = {}



  
function main.init()
    
    spawnNewWhale() -- spawn a new whale entity
    
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
    black_hole_transform.actualX = globals.screenWidth() / 2 - black_hole_transform.actualW / 2
    black_hole_transform.actualY = globals.screenHeight() / 2 - black_hole_transform.actualH / 2
    
    
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
    

    -- add optional fullscreen shader which will be applied to the whole screen, can be removed later
    -- add_fullscreen_shader("flash")
    add_fullscreen_shader("shockwave")
    add_fullscreen_shader("tile_grid_overlay") -- to show tile grid
    

    -- add shader to specific layer

    debug(layers)
    debug(layers.sprites)
    
    -- layers.sprites:addPostProcessShader("flash")

    -- shader uniform manipulation example
    debug(globals.gravityWaveSeconds)
    timer.every(globals.gravityWaveSeconds, function()
        globals.timeUntilNextGravityWave = globals.gravityWaveSeconds -- reset the timer for the next gravity wave
        -- spawn a new timer that tweens the shader uniform
        -- Example 1: fixed 2-second tween
        globalShaderUniforms:set("shockwave", "radius", 0)
        timer.tween(
            5,      -- duration in seconds
            function() return globalShaderUniforms:get("shockwave", "radius") end, -- getter
            function(v) globalShaderUniforms:set("shockwave", "radius", v) end,    -- setter
            2, -- target_value
            "shockwave_tween_radius" -- unique tag for this tween
        )
        
        -- 4 seconds later, call the whale's onclick method
        timer.after(
            4.0, -- delay in seconds
            function()
                
                -- for each whale in globals.entities.whales
                for _, bowser in ipairs(globals.entities.whales) do
                    --TODO: add flash pass to the whale, remove it 4 seconds later
                    local whaleShaderPipeline = registry:get(bowser, shader_pipeline.ShaderPipelineComponent)
                    whaleShaderPipeline:addPass("flash") -- add the shockwave pass to the whale
                    
                    -- run something 3 times in a row
                    timer.after(
                        0.5, -- delay in seconds
                        function()
                            -- call the whale's onclick method
                            local whaleGameObject = registry:get(bowser, GameObject)
                            if whaleGameObject.methods.onClick then
                                whaleGameObject.methods.onClick(registry, bowser)
                            end
                        end
                    )
                    timer.after(
                        1.0, -- delay in seconds
                        function()
                            local whaleGameObject = registry:get(bowser, GameObject)
                            if whaleGameObject.methods.onClick then
                                whaleGameObject.methods.onClick(registry, bowser)
                            end
                        end
                    )
                    timer.after(
                        1.9, -- delay in seconds
                        function()
                            local whaleGameObject = registry:get(bowser, GameObject)
                            if whaleGameObject.methods.onClick then
                                whaleGameObject.methods.onClick(registry, bowser)
                            end
                        end
                    )
                    
                    timer.after(
                        6.0, -- delay in seconds
                        function()
                            local whaleShaderPipeline = registry:get(bowser, shader_pipeline.ShaderPipelineComponent)
                            whaleShaderPipeline:removePass("flash") -- remove the shockwave pass from the whale
                        end,
                        "whale_flash_after"
                    )
                end
                
                
                
            end,
            "whale_on_click_after"
        )
    end, 0, true, nil, "shockwave_uniform_tween")
    
    
    ui_defs.generateUI() -- generate the UI for the game
    
    --FIXME: inject more whale dust for testing
    timer.every(
        1.0, -- every 1 second
        function()
            globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + 100 -- increment the target by 1
        end,
        0,
        true, -- start immediately
        nil,
        "testing"
    )
    
    -- for each currency type
    timer.every(
        1.0, -- every 1 second
        function()
            for currencyName, currency in pairs(globals.currencies) do
                timer.tween(
                    0.5, -- duration in seconds
                    function() return globals.currencies[currencyName].amount end, -- getter
                    function(v) globals.currencies[currencyName].amount = v end, -- setter
                    globals.currencies[currencyName].target, -- target value
                    "increment" .. currencyName -- unique tag for this tween
                )
            end
        end,
        0,
        true, -- start immediately
        nil,
        "currency_target_increment_global"
    )
    
    -- TODO: now let's make each building & converter do something
    timer.every(
        1.0, -- every 1 second
        function()
            updateConverters()
        end,
        0,
        false, -- don't start right away
        nil,
        "building_currency_production"
    )
    

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
    globals.timeUntilNextGravityWave = globals.timeUntilNextGravityWave - dt
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
