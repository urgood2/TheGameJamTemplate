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

GAMESTATE = {
    MAIN_MENU = 0,
    IN_GAME = 1
}

local currentGameState = GAMESTATE.MAIN_MENU -- Set the initial game state to IN_GAME

local mainMenuEntities = {
}

function initMainMenu()
    currentGameState = GAMESTATE.MAIN_MENU -- Set the game state to MAIN_MENU
    
    setCategoryVolume("effects", 0.2) -- Set the effects volume to 0.5
    -- change the background by setting a shader transform
    -- u_noisiness to -3
    -- gray_amount to 1.92
    
    playMusic("main-menu", true) -- Play the main menu music

    timer.tween(
        5,      -- duration in seconds
        function() return globalShaderUniforms:get("outer_space_donuts_bg", "grayAmount") end, -- getter
        function(v) globalShaderUniforms:set("outer_space_donuts_bg", "grayAmount", v) end,    -- setter
        1.92, -- target_value
        "outer_space_donuts_bg_gray" -- unique tag for this tween
    )
    timer.tween(
        5,      -- duration in seconds
        function() return globalShaderUniforms:get("outer_space_donuts_bg", "u_noisiness") end, -- getter
        function(v) globalShaderUniforms:set("outer_space_donuts_bg", "u_noisiness", v) end,    -- setter
        1.92, -- target_value
        "outer_space_donuts_bg_noise" -- unique tag for this tween
    )
    
    
    -- create start game button
    mainMenuEntities.logoText = ui.definitions.getNewDynamicTextEntry(
        localization.get("ui.start_game_logo"),  -- initial text
        40.0,                                 -- font size
        nil,                                  -- no style override
        "pulse=0.9,1.1"                       -- animation spec
    ).config.object
    
    local logoTextTransform = registry:get(mainMenuEntities.logoText, Transform)
    logoTextTransform.actualX = globals.screenWidth() / 2 - logoTextTransform.actualW / 2
    logoTextTransform.actualY = globals.screenHeight() / 2 - logoTextTransform.actualH / 2 - 200
    
    local tiltDirection = 1 -- 1 for right, -1 for left
    timer.every(
        3.0, -- every 0.5 seconds
        function()
             -- set rotation to 30 degrees to the right or left
            local rotation = tiltDirection * 2
            local transformComp = registry:get(mainMenuEntities.logoText, Transform)
            transformComp.actualR = rotation
            -- toggle the direction
            tiltDirection = -tiltDirection
        end,
        0, -- infinite repetitions
        true, -- start immediately
        nil, -- no "after" callback
        "logo_text_update"
    )
    
    timer.every(
        0.1, -- every 0.5 seconds
        function()
            -- make the text move up and down (bob)
            local transformComp = registry:get(mainMenuEntities.logoText, Transform)
            local bobHeight = 10 -- height of the bob
            local time = os.clock() -- get the current time
            local bobOffset = math.sin(time * 2) * bobHeight -- calculate the offset
            transformComp.actualY = globals.screenHeight() / 2 - transformComp.actualH / 2 - 200 + bobOffset -- apply the offset to the Y position
            
        end,
        0, -- infinite repetitions
        true, -- start immediately
        nil, -- no "after" callback
        "logo_text_pulse"
    )
    
    
    local startButtonText = ui.definitions.getNewDynamicTextEntry(
        localization.get("ui.start_game_button"),  -- initial text
        30.0,                                 -- font size
        nil,                                  -- no style override
        "pulse=0.9,1.1"                       -- animation spec
    )
    local startButtonTemplate = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("green_persian"))
                :addEmboss(2.0)
                :addShadow(true)
                :addHover(true) -- needed for button effect
                :addButtonCallback(function ()
                    playSoundEffect("effects", "button-click") -- play button click sound
                    startGameButtonCallback() -- callback for the start game button
                end)
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(startButtonText)
        :build()
        
    --
    local feedbackText = ui.definitions.getNewDynamicTextEntry(
        localization.get("ui.start_game_feedback"),  -- initial text
        15,                                 -- font size
        nil,                                  -- no style override
        "rainbow"                       -- animation spec
    )
    
    local discordIcon = animation_system.createAnimatedObjectWithTransform(
        "discord_icon_anim", -- animation ID
        false             -- use animation, not sprite id
    )    
    animation_system.resizeAnimationObjectsInEntityToFit(
        discordIcon,
        32,   -- width
        32    -- height
    )
    local discordIconTemplate = ui.definitions.wrapEntityInsideObjectElement(discordIcon)
    
    local discordRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("green_persian"))
                :addEmboss(2.0)
                :addButtonCallback(function ()
                    playSoundEffect("effects", "button-click") -- play button click sound
                    -- Open the Discord link
                    OpenURL("https://discord.gg/urpjVuPwjW") 
                end)
                :addShadow(true)
                :addHover(true) -- needed for button effect
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
                :build()
        )
        :addChild(discordIconTemplate)
        :addChild(feedbackText)
        :build()
        
    -- bluesky row
    local blueskyIcon = animation_system.createAnimatedObjectWithTransform(
        "bluesky_icon_anim", -- animation ID
        false             -- use animation, not sprite id
    )
    local blueskyIconTemplate = ui.definitions.wrapEntityInsideObjectElement(blueskyIcon)
    animation_system.resizeAnimationObjectsInEntityToFit(
        blueskyIcon,
        32,   -- width
        32    -- height
    )
    
    local blueskyText = ui.definitions.getNewDynamicTextEntry(
        localization.get("ui.start_game_follow"),  -- initial text
        15,                                 -- font size
        nil,                                  -- no style override
        "pulse=0.9,1.1"                       -- animation spec
    )
    
    local blueskyRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("green_persian"))
                :addEmboss(2.0)
                :addButtonCallback(function ()
                    playSoundEffect("effects", "button-click") -- play button click sound
                    -- Open the Bluesky link
                    OpenURL("https://bsky.app/profile/chugget.itch.io") 
                end)
                :addShadow(true)
                :addHover(true) -- needed for button effect
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
                :build()
        )
        :addChild(blueskyText)
        :addChild(blueskyIconTemplate)
        :build()
        
        
    
    -- TODO: call OpenURL(link) when clicked
        
    -- create animation entity for discord
    --TODO:
        
    local startMenuRoot = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.ROOT)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("lapi_lazuli"))
            :addShadow(true)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(startButtonTemplate)
    :addChild(discordRow)
    :addChild(blueskyRow)
    :build()
    
    
    -- new uibox for the main menu
    mainMenuEntities.main_menu_uibox = ui.box.Initialize({x = 350, y = globals.screenHeight()}, startMenuRoot)
    
    -- center the ui box X-axi
    local mainMenuTransform = registry:get(mainMenuEntities.main_menu_uibox, Transform)
    mainMenuTransform.actualX = globals.screenWidth() / 2 - mainMenuTransform.actualW / 2
    mainMenuTransform.actualY = globals.screenHeight() / 2 
end

function startGameButtonCallback()
    clearMainMenu() -- clear the main menu
                    
    -- TODO: tween the shader transforms to their real values
    
    timer.tween(
        2,      -- duration in seconds
        function() return globalShaderUniforms:get("outer_space_donuts_bg", "grayAmount") end, -- getter
        function(v) globalShaderUniforms:set("outer_space_donuts_bg", "grayAmount", v) end,    -- setter
        0.77, -- target_value
        "outer_space_donuts_bg_gray" -- unique tag for this tween
    )
    timer.tween(
        2,      -- duration in seconds
        function() return globalShaderUniforms:get("outer_space_donuts_bg", "u_noisiness") end, -- getter
        function(v) globalShaderUniforms:set("outer_space_donuts_bg", "u_noisiness", v) end,    -- setter
        0.22, -- target_value
        "outer_space_donuts_bg_noise" -- unique tag for this tween
    )
    
    
    --TODO: add full screeen transition shader, tween the value of that
    add_fullscreen_shader("screen_tone_transition") -- Add the fade out shader
    
    fadeOutMusic("main-menu", 1.0) -- Fade out the main menu music over 1 second
    
    -- 0 is dark, 1 is light
    globalShaderUniforms:set("screen_tone_transition", "position", 1)
    
    timer.tween(
        1.0, -- duration in seconds
        function() return globalShaderUniforms:get("screen_tone_transition", "position") end, -- getter
        function(v) globalShaderUniforms:set("screen_tone_transition", "position", v) end, -- setter
        0 -- target value
    )
    
    --TODO: change to main game state
    timer.after(
        2.0, -- delay in seconds
        function()
            debug("Changing game state to IN_GAME") -- Debug message to indicate the game state change
            timer.tween(
                1.0, -- duration in seconds
                function() return globalShaderUniforms:get("screen_tone_transition", "position") end, -- getter
                function(v) globalShaderUniforms:set("screen_tone_transition", "position", v) end, -- setter
                1 -- target value
                
            )
            
        end
    )
    timer.after(
        3.2, -- delay in seconds
        function()
            remove_fullscreen_shader("screen_tone_transition") -- Remove the fade out shader
            changeGameState(GAMESTATE.IN_GAME) -- Change the game state to IN_GAME
        end,
        "main_menu_to_game_state_change" -- unique tag for this timer
    )
    
end
function clearMainMenu() 
    --TODO:
    -- for each entity in mainMenuEntities, push it down out of view
    for _, entity in pairs(mainMenuEntities) do
        if registry:has(entity, Transform) then
            local transform = registry:get(entity, Transform)
            transform.actualY = globals.screenHeight() + 500 -- push it down out of view
        end
    end
    
    
    -- delete tiemrs
    timer.cancel("logo_text_update") -- cancel the logo text update timer
    timer.cancel("logo_text_pulse") -- cancel the logo text pulse timer
end

function initMainGame()
    debug("Initializing main game...") -- Debug message to indicate the game is starting
    currentGameState = GAMESTATE.IN_GAME -- Set the game state to IN_GAME
    
    playMusic("main-game", true) -- Play the main game music
    playMusic("whale-song", true) -- Play the whale song music, but mute it
    setTrackVolume("whale-song", 0.0) -- Mute the whale song music
    
    
    
    -- Set the background shader to the main game background
    
    
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
        globals.gravity_wave_count = globals.gravity_wave_count + 1 -- increment the gravity wave count
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
        
        -- play black hole sound
        timer.after(
            0.5, -- delay in seconds
            function()
                playSoundEffect("effects", "black-hole-after") -- play the black hole sound
            end
        )
        
        -- play lead-up sound 4 seconds before the shockwave
        timer.after(
            globals.gravityWaveSeconds - 4, -- delay in seconds
            function()
                playSoundEffect("effects", "black-hole-before") -- play the lead-up sound
            end
        )
        
        -- 3 seconds later, call the whale's onclick method
        timer.after(
            3.0, -- delay in seconds
            function()
                
                -- for each whale in globals.entities.whales
                for _, bowser in ipairs(globals.entities.whales) do
                    
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
                        1.1, -- delay in seconds
                        function()
                            local whaleGameObject = registry:get(bowser, GameObject)
                            if whaleGameObject.methods.onClick then
                                whaleGameObject.methods.onClick(registry, bowser)
                            end
                        end
                    )
                    timer.after(
                        1.2, -- delay in seconds
                        function()
                            local whaleGameObject = registry:get(bowser, GameObject)
                            if whaleGameObject.methods.onClick then
                                whaleGameObject.methods.onClick(registry, bowser)
                            end
                        end
                    )
                    timer.after(
                        1.3, -- delay in seconds
                        function()
                            local whaleGameObject = registry:get(bowser, GameObject)
                            if whaleGameObject.methods.onClick then
                                whaleGameObject.methods.onClick(registry, bowser)
                            end
                        end
                    )
                    timer.after(
                        1.4, -- delay in seconds
                        function()
                            local whaleGameObject = registry:get(bowser, GameObject)
                            if whaleGameObject.methods.onClick then
                                whaleGameObject.methods.onClick(registry, bowser)
                            end
                        end
                    )
                    timer.after(
                        1.5, -- delay in seconds
                        function()
                            local whaleGameObject = registry:get(bowser, GameObject)
                            if whaleGameObject.methods.onClick then
                                whaleGameObject.methods.onClick(registry, bowser)
                            end
                        end
                    )
                    timer.after(
                        1.6, -- delay in seconds
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
    -- timer.every(
    --     1.0, -- every 1 second
    --     function()
    --         globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + 100 -- increment the target by 1
    --     end,
    --     0,
    --     true, -- start immediately
    --     nil,
    --     "testing"
    -- )
    
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
        5.0, -- every 1 second
        function()
            updateConverters()
            updateBuildings()
        end,
        0,
        false, -- don't start right away
        nil,
        "building_currency_production"
    )
    
    --FIXME: remove this timer after testing
    -- timer.every(
    --     3,
    --     function()
    --         -- update all currencies by 40
    --         for currencyName, currency in pairs(globals.currencies) do
    --             globals.currencies[currencyName].target = globals.currencies[currencyName].target + 40 -- increment the target by 1
    --         end
    --     end,
    --     0,
    --     false, -- don't start right away
    --     nil,
    --     "currency_bugfixing_update"
    -- )
    
    timer.every(
        4,
        function()
            
            -- looop through global achievements table
            for _, achievement in pairs(globals.achievements) do
                if not achievement.unlocked then
                    -- check if the achievement is unlocked
                    if achievement.require_check() then 
                        --TODO: new achievement unlocked. do a new window thing, play sounds, make particles, etc.
                        
                        achievement.unlocked = true -- mark the achievement as unlocked
                        achievement.rewardFunc(globals.screenWidth() / 2, globals.screenHeight() / 2 + 300) -- call the reward function with the screen center as the position
                        
                        --TODO: update the achievement UI window with the right animation
                        animation_system.replaceAnimatedObjectOnEntity(
                            achievement.anim_entity,
                            achievement.anim,
                            false,
                            nil,   -- shader_prepass, -- Optional shader pass config function
                            true   -- Enable shadow
                        )
                        animation_system.resizeAnimationObjectsInEntityToFit(
                            achievement.anim_entity,
                            48,   -- width
                            48    -- height
                        )
                        
                        showNewAchievementPopup(achievement.id)
                    else
                        
                    end
                end
            end
        end,
        0,
        true, -- start immediately
        nil,
        "achievement_check"
    )
    

    -- add a task to the scheduler that will fade out the screen for 5 seconds
    local p1 = {
        update = function(self, dt)
            -- debug("Fade out screen")
            -- -- fadeOutScreen(0.1)
            -- add_fullscreen_shader("screen_tone_transition") -- Add the fade out shader
            -- globalShaderUniforms:set("screen_tone_transition", "position", 0) -- Set initial value to 1.0 (dark)
            -- -- timer tween
            -- timer.tween(
            --     2.0, -- duration in seconds
            --     function() return globalShaderUniforms:get("screen_tone_transition", "position") end, -- getter
            --     function(v) globalShaderUniforms:set("screen_tone_transition", "position", v) end, -- setter
            --     1.0 -- target value
            -- )
            -- task.wait(5.0)
        end
    }

    local p2 = {
        update = function(self, dt)
            -- fadeInScreen(1)
            -- remove_fullscreen_shader("screen_tone_transition") -- Remove the fade out shader
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

function changeGameState(newState)
    -- Check if the new state is different from the current state
    if newState == GAMESTATE.MAIN_MENU then
        initMainMenu()
    elseif newState == GAMESTATE.IN_GAME then
        initMainGame()
    else
        error("Invalid game state: " .. tostring(newState))
    end
    currentGameState = newState -- Update the current game state
end
  
function main.init()
    
    timer.every(1, function()
        if registry:valid(globals.inputState.cursor_hovering_target) == false or globals.inputState.cursor_hovering_target == globals.gameWorldContainerEntity()  then
            hideTooltip() -- Hide the tooltip if the cursor is not hovering over any target
        end
    end,
    0, -- start immediately)
    true,
    nil, -- no "after" callback
    "tooltip_hide_timer" -- unique tag for this timer
    )
    
    changeGameState(GAMESTATE.MAIN_MENU) -- Initialize the game in the IN_GAME state
end

function main.update(dt)
    if (currentGameState == GAMESTATE.MAIN_MENU) then
        globals.main_menu_elapsed_time = globals.main_menu_elapsed_time + dt
    end
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
