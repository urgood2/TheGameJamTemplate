require("core.globals")
require("registry")
require("ai.init") -- Read in ai scripts and populate the ai table
require("util.util")
require("ui.ui_defs")
require("core.entity_factory")

local shader_prepass = require("shaders.prepass_example")
require("core.entity_factory")
local Chain = require("external.knife.chain")
lume = require("external.lume")
local camera, methods = require("external.hump.camera")
-- Represents game loop main module
main = {}

-- Game state (used only in lua)
GAMESTATE = {
    MAIN_MENU = 0,
    IN_GAME = 1
}

local testCamera = camera.new(0, 0, 1, 0, camera.smooth.damped(0.1)) -- Create a new camera instance with damping
-- testCamera:move(400,400)

local currentGameState = GAMESTATE.MAIN_MENU -- Set the initial game state to IN_GAME

local mainMenuEntities = {
}

function myCustomCallback()
    -- a test to see if the callback works for text typing
    wait(5)
    return true
end

function initMainMenu()
    globals.currentGameState = GAMESTATE.MAIN_MENU -- Set the game state to MAIN_MENU
    setCategoryVolume("effects", 0.2)
    -- create start game button
    mainMenuEntities.logoText = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.start_game_logo") end,  -- initial text
        40.0,                                 -- font size
        "pulse=0.9,1.1"                       -- animation spec
    ).config.object
    
    local logoTextTransform = registry:get(mainMenuEntities.logoText, Transform)
    logoTextTransform.actualX = globals.screenWidth() / 2 - logoTextTransform.actualW / 2
    logoTextTransform.actualY = globals.screenHeight() / 2 - logoTextTransform.actualH / 2 - 200
    
    
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
        function() return localization.get("ui.start_game_button") end,  -- initial text
        30.0,                                 -- font size
        "pulse=0.9,1.1"                       -- animation spec
    )
    local startButtonTemplate = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("taupe_warm"))
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
        function() return localization.get("ui.start_game_feedback") end,  -- initial text
        15,                                 -- font size
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
                :addColor(util.getColor("taupe_warm"))
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
        function() return localization.get("ui.start_game_follow") end,  -- initial text
        15,                                 -- font size
        "pulse=0.9,1.1"                       -- animation spec
    )
    
    local blueskyRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("taupe_warm"))
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
            :addColor(util.getColor("mauve_shadow"))
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
    
    -- button text
    local languageText = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.switch_language") end,  -- initial text
        15.0,                                 -- font size
        "pulse=0.9,1.1"                       -- animation spec
    )
    local languageButtonTemplate = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("taupe_warm"))
                :addEmboss(2.0)
                :addShadow(true)
                :addHover(true) -- needed for button effect
                :addButtonCallback(function ()
                    playSoundEffect("effects", "button-click") -- play button click sound
                    -- Switch the language
                    if (localization.getCurrentLanguage() == "en_us") then
                        localization.setCurrentLanguage("ko_kr")
                    else
                        localization.setCurrentLanguage("en_us")
                    end
                end)
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
                :build()
        )
        :addChild(languageText)
        :build()
        
    -- new root
    local languageButtonRoot = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.ROOT)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("dusty_rose"))
                :addShadow(true)
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(languageButtonTemplate)
        :build()
    -- new uibox for the language button
    mainMenuEntities.language_button_uibox = ui.box.Initialize({x = 350, y = globals.screenHeight()}, languageButtonRoot)
    
    -- put in the bottom right corner
    local languageButtonTransform = registry:get(mainMenuEntities.language_button_uibox, Transform)
    languageButtonTransform.actualX = globals.screenWidth() - languageButtonTransform.actualW - 20
    languageButtonTransform.actualY = globals.screenHeight() - languageButtonTransform.actualH - 20
    
end

function startGameButtonCallback()
    clearMainMenu() -- clear the main menu
                    
    
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
        1.0, -- delay in seconds
        function()
            log_debug("Changing game state to IN_GAME") -- Debug message to indicate the game state change
            timer.tween(
                1.0, -- duration in seconds
                function() return globalShaderUniforms:get("screen_tone_transition", "position") end, -- getter
                function(v) globalShaderUniforms:set("screen_tone_transition", "position", v) end, -- setter
                1 -- target value
                
            )
            changeGameState(GAMESTATE.IN_GAME) -- Change the game state to IN_GAME
            
        end
    )
    timer.after(
        2.2, -- delay in seconds
        function()
            remove_fullscreen_shader("screen_tone_transition") -- Remove the fade out shader
            
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
    log_debug("Initializing main game...") -- Debug message to indicate the game is starting
    currentGameState = GAMESTATE.IN_GAME -- Set the game state to IN_GAME
    
    -- playMusic("main-game", true) -- Play the main game music
    -- playMusic("whale-song", true) -- Play the whale song music, but mute it
    -- setTrackVolume("whale-song", 0.0) -- Mute the whale song music
    
    -- add_fullscreen_shader("shockwave")
    -- add_fullscreen_shader("tile_grid_overlay") -- to show tile griddonuts background
    
    
    
    -- generate some random grass and place them around the map, tiled
    local grassSprites = {
        "3253-TheRoguelike_1_10_alpha_46.png",
        "3254-TheRoguelike_1_10_alpha_47.png",
        "3255-TheRoguelike_1_10_alpha_48.png",
        "3256-TheRoguelike_1_10_alpha_49.png",
        "3257-TheRoguelike_1_10_alpha_50.png",
        "3258-TheRoguelike_1_10_alpha_51.png",
        "3259-TheRoguelike_1_10_alpha_52.png",
        "3260-TheRoguelike_1_10_alpha_53.png",
        "3261-TheRoguelike_1_10_alpha_54.png",
        "3262-TheRoguelike_1_10_alpha_55.png"
    }
    
    
    for i = 1, 30 do
        local grassEntity =  animation_system.createAnimatedObjectWithTransform(
            random_utils.random_element_string(grassSprites), -- animation ID
            true             -- use animation, not sprite identifier, if false
        )
        animation_system.resizeAnimationObjectsInEntityToFit(
            grassEntity,
            globals.tileSize,   -- width
            globals.tileSize    -- height
        )
        
        -- place within the screen bounds, but make sure it respects tiles
        local transformComp = registry:get(grassEntity, Transform)
        transformComp.actualX = random_utils.random_int(0, math.floor(globals.screenWidth() / globals.tileSize) - 1) * globals.tileSize
        transformComp.actualY = random_utils.random_int(0, math.floor(globals.screenHeight() / globals.tileSize) - 1) * globals.tileSize
        transformComp.visualW = transformComp.actualW
        transformComp.visualH = transformComp.actualH   
        
    end
    
    
    ui_defs.generateTooltipUI()
    ui_defs.generateUI()
    
    -- generate ai entities which will move around the map
    for i = 1, 1 do
        spawnNewColonist()
    end
    
    
    -- function destroyRainAndSpawnNew()
    --     -- destroy the rain entity
    --     if globals.rainEntity and registry:valid(globals.rainEntity) then
    --         registry:destroy(globals.rainEntity)
    --     end

    --     local delay = random_utils.random_int(5, 15) -- delay in seconds
    --     -- start another timer with 10-30 delay
    --     timer.after(
    --         delay - 5, -- delay in seconds
    --         function()
    --             newTextPopup(
    --                 "Rain is coming!", -- text to display
    --                 0, -- bottom left
    --                 globals.screenHeight() - 100, -- position at the bottom left,
    --                 5
    --             )
    --         end
    --     )
    --     timer.after(
    --         delay, -- delay in seconds
    --         function()
    --             spawnRainEntity() -- spawn a new rain entity
    --             timer.after(
    --                 3.5, -- delay in seconds
    --                 function()
    --                     -- make the rain entity blink
    --                     -- animation_system.setFGColorForAllAnimationObjects(
    --                     --     globals.rainEntity,
    --                     --     util.getColor("white") -- set the foreground color to white
    --                     -- )
    --                     timer.every(
    --                         0.1, -- every 0.5 seconds
    --                         function()
    --                             -- toggle the visibility of the rain entity
    --                             if (registry:valid(globals.rainEntity) == false) then
    --                                 log_debug("Rain entity is not valid, skipping blinking") -- Debug message
    --                                 return -- if the rain entity is not valid, do nothing
    --                             end
    --                             local rainComp = registry:get(globals.rainEntity, AnimationQueueComponent)
    --                             rainComp.noDraw = not rainComp.noDraw
    --                         end,
    --                         5, -- 5 repetitions
    --                         true, -- start immediately
    --                         function()
    --                             if (registry:valid(globals.rainEntity) == false) then
    --                                 log_debug("Rain entity is not valid, skipping blinking") -- Debug message
    --                                 return -- if the rain entity is not valid, do nothing
    --                             end
    --                             -- after 5 repetitions, stop the blinking
    --                             local rainComp = registry:get(globals.rainEntity, AnimationQueueComponent)
    --                             rainComp.noDraw = false
    --                         end,
    --                         "rain_entity_blinking" -- unique tag for this timer
    --                     )
    --                 end
    --             )
    --         end
    --     )
        
    --     timer.after(
    --         delay + 4, -- delete after three seconds
    --         function()
    --             destroyRainAndSpawnNew() -- recursively call this function to spawn a new rain entity
    --         end
    --     )
    -- end
    
    -- -- add a timer that activates in 10 seconds to spawn a rain transform entity
    -- timer.after(
    --     10.0, -- delay in seconds
    --     function()
    --         spawnRainEntity() 
    --     end
    -- )
    -- timer.after(
    --     13, -- delete after three seconds
    --     function()
    --         destroyRainAndSpawnNew()
    --     end
    -- )
    

    -- scheduler example

    -- local p1 = {
    --     update = function(self, dt)
    --         log_debug("Task 1 Start")
    --         task.wait(5.0)
    --         log_debug("Task 1 End after 5s")
    --     end
    -- }

    -- local p2 = {
    --     update = function(self, dt)
    --         log_debug("Task 2 Start")
    --         task.wait(5.0)
    --         log_debug("Task 2 End after 5s")
    --     end
    -- }

    -- local p3 = {
    --     update = function(self, dt)
    --         log_debug("Task 3 Start")
    --         task.wait(10.0)
    --         log_debug("Task 3 End after 10s")
    --     end
    -- }
    -- scheduler:attach(p1, p2, p3)
end

-- overwrites the global rain entity, always delete the previous one
function spawnRainEntity() 
    -- create a rain transform entity
    globals.rainEntity = create_ai_entity("kobold")
            
    local transformComp = registry:get(globals.rainEntity, Transform)
    
    -- give animation
    animation_system.setupAnimatedObjectOnEntity(
        globals.rainEntity,
        "3408-TheRoguelike_1_10_alpha_201.png", -- animation ID
        true,        
        nil,         -- no animation speed
        true         -- loop the animation
    )
    
    -- size
    animation_system.resizeAnimationObjectsInEntityToFit(
        globals.rainEntity,
        random_utils.random_int(300, math.floor(globals.screenWidth() / 2)),   -- width
        random_utils.random_int(300, math.floor(globals.screenHeight() / 2))    -- height
    )
    
    -- random location within the screen bounds
    transformComp.actualX = random_utils.random_int(0, math.floor(globals.screenWidth() - transformComp.actualW))
    transformComp.actualY = random_utils.random_int(0, math.floor(globals.screenHeight() - transformComp.actualH))
    transformComp.visualW = transformComp.actualW
    transformComp.visualH = transformComp.actualH
    
    -- game object component
    local gameObjectComp = registry:get(globals.rainEntity, GameObject)
    -- gameObjectComp.state.hoverEnabled = true
    gameObjectComp.state.collisionEnabled = true
    
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
    globals.currentGameState = newState -- Update the current game state
end
  
-- Main function to initialize the game. Called at the start of the game.
function main.init()
    
    -- enable debug mode if the environment variable is set
    if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
        require("lldebugger").start()
    end
    
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
    
    timer.every(1.0, function()
        -- if a weather event is active, update the weather event
        if (globals.current_weather_event == "acid_rain") then
            -- TODO: spawn green particles everywhere
        
            timer.every(
                0.1, -- every 0.1 seconds
                function()
                    spawnRainPlopAtRandomLocation()
                end,
                5, -- repeat 10 times
                true, -- start immediately
                nil, -- no "after" callback
                "acid_rain_particle_spawn"
            )
            
            -- choose a random colonist with 50% chance
            if random_utils.random_int(0, 1) == 0 then
                local acid_rain_def = findInTable(
                    globals.weather_event_defs, "id", "acid_rain"
                )
                
                -- choose a random colonist
                local colonist = globals.colonists[random_utils.random_int(1, #globals.colonists)]
                
                log_debug("Acid rain event: applying damage to colonist:", colonist)
                
                -- set the blackboard health value (reduce health by 1)
                if colonist and registry:valid(colonist) then
                    
                    local damage_done = random_utils.random_int(1, acid_rain_def.base_damage) -- random damage between 1 and base damage
                    
                    setBlackboardFloat(colonist, "health", getBlackboardFloat(colonist, "health") - damage_done)  
                    
                    --TODO: damage mitigatoin through relics
                    
                    -- show a text popup above the colonist
                    local colonistTransform = registry:get(colonist, Transform)
                    newTextPopup(
                        localization.get("ui.acid_rain_damage_text", {damage = damage_done}), -- text to display
                        colonistTransform.actualX + colonistTransform.visualW / 2, -- position at the center of the colonist
                        colonistTransform.actualY - 50, -- position above the colonist
                        5 -- duration in seconds
                    )
                end
            end
        end
    end,
    0, -- start immediately
    true,
    nil, -- no "after" callback
    "weather_event_timer" -- unique tag for this timer
    )
    
    
    -- every 1 second, check every colonist
    timer.every(1.0, function()
        for _, colonist in pairs(globals.colonists) do
            if registry:valid(colonist) then
                -- check if the colonist is dead
                if getBlackboardFloat(colonist, "health") <= 0 then
                    -- show a text popup above the colonist
                    local colonistTransform = registry:get(colonist, Transform)
                    newTextPopup(
                        localization.get("ui.colonist_dead_text"), -- text to display
                        colonistTransform.actualX + colonistTransform.visualW / 2, -- position at the center of the colonist
                        colonistTransform.actualY - 50, -- position above the colonist
                        5 -- duration in seconds
                    )
                    
                    -- show particles
                    spawnCircularBurstParticles(
                        colonistTransform.actualX + colonistTransform.visualW / 2, -- position at the center of the colonist
                        colonistTransform.actualY + colonistTransform.visualH / 2, -- position at the center of the colonist
                        50, -- count
                        10, -- duration
                        util.getColor("red"), -- start
                        util.getColor("black") -- end color
                    )
                    
                    -- remove the colonist from the globals.colonists table
                    globals.colonists[colonist] = nil
                    
                    -- remove colonist's text ui
                    registry:destroy(globals.ui.colonist_ui[colonist].hp_ui_text)
                    globals.ui.colonist_ui[colonist] = nil
                    
                    -- destroy the colonist entity
                    registry:destroy(colonist)
                end
            end
        end
    end,
    1.0, -- every 1 second
    true, -- start immediately
    nil, -- no "after" callback
    "colonist_health_check" -- unique tag for this timer
    )
    
    changeGameState(GAMESTATE.MAIN_MENU) -- Initialize the game in the IN_GAME state
end

function main.update(dt)
    
    if (globals.gamePaused) then
        return -- If the game is paused, do not update anything
    end
    
    if (currentGameState == GAMESTATE.MAIN_MENU) then
        globals.main_menu_elapsed_time = globals.main_menu_elapsed_time + dt
    end
    
    -- Update the game time
    -- how many game‐seconds should pass per real second
    local gameTimeSpeedUpFactor = 2000

    -- convert dt (real seconds) into game seconds
    local gameSeconds = dt * gameTimeSpeedUpFactor

    -- add to an explicit seconds counter (for precision)
    globals.game_time.seconds = (globals.game_time.seconds or 0) + gameSeconds

    -- roll up into minutes
    if globals.game_time.seconds >= 60 then
        local extraMin = math.floor(globals.game_time.seconds / 60)
        globals.game_time.seconds = globals.game_time.seconds % 60
        globals.game_time.minutes = globals.game_time.minutes + extraMin
    end

    -- roll up into hours
    if globals.game_time.minutes >= 60 then
        local extraHr = math.floor(globals.game_time.minutes / 60)
        globals.game_time.minutes = globals.game_time.minutes % 60
        globals.game_time.hours   = globals.game_time.hours + extraHr
    end

    -- roll up into days
    if globals.game_time.hours >= 24 then
        local extraDay = math.floor(globals.game_time.hours / 24)
        globals.game_time.hours = globals.game_time.hours % 24
        globals.game_time.days  = globals.game_time.days + extraDay
        
        -- new day has dawned. pause the game and show the new day message
        
        handleNewDay()
        
    end
    -- log_debug("time:", globals.game_time.hours, ":", globals.game_time.minutes, "days:", globals.game_time.days)
    
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
   
end
