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
    playMusic("main-menu", true) -- Play the main menu music
    -- create start game button
    
    
    -- create main logo
    globals.ui.logo = animation_system.createAnimatedObjectWithTransform(
        "logo.png", -- animation ID
        true             -- use animation, not sprite identifier, if false
    )
    animation_system.resizeAnimationObjectsInEntityToFit(
        globals.ui.logo,
        128 * 5,   -- width
        64 * 5    -- height
    )
    -- center
    local logoTransform = registry:get(globals.ui.logo, Transform)
    logoTransform.actualX = globals.screenWidth() / 2 - logoTransform.actualW / 2
    logoTransform.actualY = globals.screenHeight() / 2 - logoTransform.actualH / 2 - 400 -- move it up a bit
    
    timer.every(
        0.1, -- every 0.5 seconds
        function()
            -- make the text move up and down (bob)
            local transformComp = registry:get(globals.ui.logo, Transform)
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
        "color=fuchsia"                       -- animation spec
    )
    local startButtonTemplate = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("taupe_warm"))
                :addEmboss(2.0)
                :addMinWidth(500) -- minimum width of the button
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
        30,                                 -- font size
        "color=apricot_cream"                       -- animation spec
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
                :addMinWidth(500) -- minimum width of the button
                :addButtonCallback(function ()
                    playSoundEffect("effects", "button-click") -- play button click sound
                    -- Open the Discord link
                    OpenURL("https://discord.gg/urpjVuPwjW") 
                end)
                :addShadow(true)
                :addMinWidth(500) -- minimum width of the button
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
        30,                                 -- font size
        "color=pastel_pink"                       -- animation spec
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
            
            add_fullscreen_shader("palette_quantize")
            
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
    
    -- move global.ui.logo out of view
    local logoTransform = registry:get(globals.ui.logo, Transform)
    logoTransform.actualY = globals.screenHeight() + 500 -- push it down out of view
    
    
    -- delete tiemrs
    timer.cancel("logo_text_update") -- cancel the logo text update timer
    timer.cancel("logo_text_pulse") -- cancel the logo text pulse timer
end

function initMainGame()
    -- pauseMusic("main-menu") -- Pause the main menu music
    setTrackVolume("main-menu", 0.0)
    
    --     "snow-ambiance": "Snow Ambience.wav",
    --     "regular-ambiance": "Regular Ambience.wav",
    --     "rain-ambiance": "Rain Ambience.wav",
    --     "fair_weather": "Difficulty 1 Fair Weather.wav",
    --     "acid_rain": "Difficulty 3 Acid Rain.wav",
    --     "radioactive_snow": "Difficulty 4 Radioactive Snow.wav"
    
    -- play everything, but set to 0 volume
    playMusic("snow-ambiance", true) -- Play the snow ambiance music
    setTrackVolume("snow-ambiance", 0.0) -- Mute the snow ambiance music
    playMusic("regular-ambiance", true) -- Play the regular ambiance music
    -- setTrackVolume("regular-ambiance", 0.0) -- Mute the regular ambiance music
    playMusic("rain-ambiance", true) -- Play the rain ambiance music
    setTrackVolume("rain-ambiance", 0.0) -- Mute the rain ambiance music
    playMusic("fair_weather", true) -- Play the fair weather music
    -- setTrackVolume("fair_weather", 0.0) -- Mute the fair weather music
    playMusic("acid_rain", true) -- Play the acid rain music
    setTrackVolume("acid_rain", 0.0) -- Mute the acid rain music
    playMusic("radioactive_snow", true) -- Play the radioactive snow music
    setTrackVolume("radioactive_snow", 0.0) -- Mute the radioactive snow music
    
    -- timer.tween(
    --     0.5, -- duration in seconds
    --     function() return getTrackVolume("whale-song") end, -- getter
    --     function(v) setTrackVolume("whale-song", v) end, -- setter
    --     1 -- target value
    -- )
    log_debug("Initializing main game...") -- Debug message to indicate the game is starting
    currentGameState = GAMESTATE.IN_GAME -- Set the game state to IN_GAME
    
    -- playMusic("main-game", true) -- Play the main game music
    -- playMusic("whale-song", true) -- Play the whale song music, but mute it
    -- setTrackVolume("whale-song", 0.0) -- Mute the whale song music
    
    
    
    
    
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
        
        layer_order_system.assignZIndexToEntity(
            grassEntity,
            0 -- assign a z-index based on the iteration
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
    
    
    timer.every(2.0 , function()
        -- every 2 seconds, check if the game is paused
        if globals.gamePaused then
            return -- If the game is paused, do not update the game state
        end
        
        -- if there are no colonists, game over
        if (#globals.colonists == 0 and not globals.gameOver) or (globals.currency < 0) then
            log_debug("No colonists left, game over") -- Debug message to indicate game over
            globals.gameOver = true -- Set the game over flag, disable resuming
            globals.gamePaused = true -- Set the game over flag
            
            -- create game over text
            local gameOverText = ui.definitions.getNewDynamicTextEntry(
                function() return "GAME OVER" end,  -- initial text
                80.0,                                 -- font size
                "rainbow"                       -- animation spec
            )
            
            -- get transformComp
            local gameOverTransform = registry:get(gameOverText.config.object, Transform)
            
            -- center the text in the middle of the screen
            gameOverTransform.actualX = globals.screenWidth() / 2 - gameOverTransform.actualX / 2
            gameOverTransform.actualY = globals.screenHeight() / 2 - gameOverTransform.actualH / 2  
            gameOverTransform.visualW = gameOverTransform.actualW
            gameOverTransform.visualH = gameOverTransform.actualH
            
            -- set z order to be on top of everything
            layer_order_system.assignZIndexToEntity(
                gameOverText.config.object,
                30000 -- a very high z-index to ensure it is on top of everything
            )
            return -- Exit the function
        end
        
    end)
    
    
    -- -- set game to paused
    togglePausedState(true) -- Set the game to paused state
    
    -- -- now we will show a series of tutorials
    
    -- "tutorial_duplicate": "<typing,speed=0.8>Hey there! Let me teach you the ropes with a quick tutorial.\nDrag & drop a colonist into the window on the left side to duplicate it.\nThis will spawn clones, each with a specific function.",
	-- 	"tutorial_game_goal": "<typing,speed=0.8>Your goal is to survive the acid rains and radioactive snows by using the clones you create.\nYou must keep colonists alive, and keep your gold balance above 0, to keep playing.\nYou may want to build some colonist homes to help with gold production.",
	-- 	"tutorial_advanced": "<typing,speed=0.8>As you progress, you will be able to buy relics from the end-of-day shop.\nThey will help your colonists survive the harsh weather.\nNote that the weather will only get worse as you progress.",
	-- 	"tutorial_end": "<typing,speed=0.8>That's it for the tutorial!\nRefer ot the tooltips if you need more info.\nGood luck, and have fun!\nLet's see 'weather or not' you can survive!",
    
    -- globals.tutorials = {
    --     "ui.tutorial_duplicate",
    --     "ui.tutorial_game_goal",
    --     "ui.tutorial_advanced",
    --     "ui.tutorial_end"
    -- }
    
    -- globals.currentTutorialIndex = 1 -- Start with the first tutorial
    
    -- -- first, make a row with a text entity and a close button
    -- globals.ui.tutorialText = ui.definitions.getNewDynamicTextEntry(
    --     function() return localization.get(globals.tutorials[globals.currentTutorialIndex]) end,  -- initial text
    --     30.0,                                 -- font size
    --     "color=forest_slate"                       -- animation spec
    -- )
    
    -- local rowDef = UIElementTemplateNodeBuilder.create()
    --     :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    --     :addConfig(
    --         UIConfigBuilder.create()
    --             :addColor(util.getColor("taupe_warm"))
    --             :addEmboss(2.0)
    --             -- :addMinWidth(500) -- minimum width of the button
    --             -- :addShadow(true)
    --             -- :addHover(true) -- needed for button effect
    --             :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
    --             :build()
    --     )
    --     :addChild(globals.ui.tutorialText)
    --     :build()
        
    -- local closeButtonText = ui.definitions.getNewDynamicTextEntry(
    --     function() return localization.get("ui.next_tutorial_text") end,  -- initial text
    --     30.0,                                 -- font size
    --     "color=apricot_cream"                       -- animation spec
    -- )
    
    -- local closeButtonTemplate = UIElementTemplateNodeBuilder.create()
    --     :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    --     :addConfig(
    --         UIConfigBuilder.create()
    --             :addColor(util.getColor("taupe_warm"))
    --             :addEmboss(2.0)
    --             :addMinWidth(500) -- minimum width of the button
    --             :addButtonCallback(function ()
    --                 nextTutorialCallback()
    --             end)
    --             :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
    --             :build()
    --     )
    --     :addChild(closeButtonText)
    --     :build()
        
    -- -- new root
    -- local tutorialRoot = UIElementTemplateNodeBuilder.create()
    --     :addType(UITypeEnum.ROOT)
    --     :addConfig(
    --         UIConfigBuilder.create()
    --             :addColor(util.getColor("mauve_shadow"))
    --             :addShadow(true)
    --             :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
    --             :addInitFunc(function(registry, entity)
    --                 -- something init-related here
    --             end)
    --             :build()
    --     )
    --     :addChild(rowDef)
    --     :addChild(closeButtonTemplate)
    --     :build()
        
    -- -- new uibox for the tutorial
    -- globals.ui.tutorial_uibox = ui.box.Initialize({x = 350, y = globals.screenHeight()}, tutorialRoot)
    -- -- center the uibox
    -- local tutorialTransform = registry:get(globals.ui.tutorial_uibox, Transform)
    -- tutorialTransform.actualX = globals.screenWidth() / 2 - tutorialTransform.actualW / 2
    -- -- snap x
    -- tutorialTransform.visualX = tutorialTransform.actualX
    -- tutorialTransform.actualY = globals.screenHeight() / 2 - tutorialTransform.actualH / 2
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

function nextTutorialCallback()
    -- Increment the tutorial index
    globals.currentTutorialIndex = globals.currentTutorialIndex + 1
    
    -- Check if there are more tutorials
    if globals.currentTutorialIndex > #globals.tutorials then
        -- If no more tutorials, close the tutorial UI
        local transformComp = registry:get(globals.ui.tutorial_uibox, Transform)
        transformComp.actualY = globals.screenHeight() + 500 -- push it down out of view
        togglePausedState(false) -- Unpause the game
        return
    end
    
    -- Update the tutorial text with the next tutorial
    
    -- get ui element
    local uie = ui.box.GetUIEByID(registry, globals.ui.tutorial_uibox, "tutorial_text_row")
    -- get uiconfig
    local uiconfig = registry:get(uie, UIConfig)
    -- set text 
    uiconfig.text = localization.get(globals.tutorials[globals.currentTutorialIndex])
    
    -- renew alignment of uibox
    ui.box.RenewAlignment(registry, globals.ui.tutorial_uibox)
    
    -- recenter
    local tutorialTransform = registry:get(globals.ui.tutorial_uibox, Transform)
    tutorialTransform.actualX = globals.screenWidth() / 2 - tutorialTransform.actualW / 2
    tutorialTransform.actualY = globals.screenHeight() / 2 - tutorialTransform.actualH / 2
    -- snap x
    tutorialTransform.visualX = tutorialTransform.actualX
    tutorialTransform.visualY = tutorialTransform.actualY
    
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
    
    timer.every(0.2, function()
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
        
        -- globalDamageReductionCallback 
        --   acidDamageReductionCallback
        --   coldDamageReductionCallback 
        --   dodgeChanceCallback
        --   damageTakenMultiplierCallback 
        
        -- onHitCallback = function(entity, damage)
        -- onDodgeCallback 
        
        -- calculcate some stats based on current owned relics
        
        local totalGlobalDamageReduction = 0
        local totalAcidDamageReduction = 0
        local totalColdDamageReduction = 0
        local totalDodgeChance = 0
        local totalDamageTakenMultiplier = 1.0 -- default multiplier is 1.0 (no damage taken)
        
        local onHitCallbacks = {}
        local onDodgeCallbacks = {}
        
        for _, relic in ipairs(globals.ownedRelics) do
            
            
            local id = relic.id
            local relicDef = findInTable(globals.relicDefs, "id", id)
            
            
            
            if relicDef.globalDamageReductionCallback then
                totalGlobalDamageReduction = totalGlobalDamageReduction + relicDef.globalDamageReductionCallback()
            end
            
            if relicDef.acidDamageReductionCallback then
                totalAcidDamageReduction = totalAcidDamageReduction + relicDef.acidDamageReductionCallback()
            end
            
            if relicDef.coldDamageReductionCallback then
                totalColdDamageReduction = totalColdDamageReduction + relicDef.coldDamageReductionCallback()
            end
            
            if relicDef.dodgeChanceCallback then
                totalDodgeChance = totalDodgeChance + relicDef.dodgeChanceCallback()
            end
            
            if relicDef.damageTakenMultiplierCallback then
                totalDamageTakenMultiplier = totalDamageTakenMultiplier * relicDef.damageTakenMultiplierCallback()
            end
            
            if relicDef.onHitCallback then
                table.insert(onHitCallbacks, relicDef.onHitCallback)
            end
            
            if relicDef.onDodgeCallback then
                table.insert(onDodgeCallbacks, relicDef.onDodgeCallback)
            end
        end
        
        
        
        -- debug print the stats
        log_debug("Total Global Damage Reduction:", totalGlobalDamageReduction)
        log_debug("Total Acid Damage Reduction:", totalAcidDamageReduction)
        log_debug("Total Cold Damage Reduction:", totalColdDamageReduction)
        log_debug("Total Dodge Chance:", totalDodgeChance)
        log_debug("Total Damage Taken Multiplier:", totalDamageTakenMultiplier)
        log_debug("Total On Hit Callbacks:", #onHitCallbacks)
        log_debug("Total On Dodge Callbacks:", #onDodgeCallbacks)
        
        function convenientTrackFadeOut(trackName, duration)
            -- convenience function to fade out a track
            if getTrackVolume(trackName) > 0 then
                timer.tween(
                    duration, -- duration in seconds
                    function() return getTrackVolume(trackName) end, -- getter
                    function(v) setTrackVolume(trackName, v) end, -- setter
                    0 -- target value
                )
            end
        end
        
        function convenientTrackFadeIn(trackName, duration)
            -- convenience function to fade in a track
            timer.tween(
                duration, -- duration in seconds
                function() return getTrackVolume(trackName) end, -- getter
                function(v) setTrackVolume(trackName, v) end, -- setter
                1 -- target value
            )
        end
        if (globals.current_weather_event == nil) then
            
            -- fair weather.
            if globals.previous_weather_event ~= globals.current_weather_event then
                -- if the previous weather event was not acid rain, then queue the music
                
                -- fade out everything, if it is not already at 0 volume
                convenientTrackFadeOut("snow-ambiance", 0.5) -- Fade out the snow ambiance music
                convenientTrackFadeOut("regular-ambiance", 0.5) -- Fade out the regular ambiance music
                convenientTrackFadeOut("rain-ambiance", 0.5) -- Fade out the rain ambiance music
                convenientTrackFadeOut("fair_weather", 0.5) --  
                convenientTrackFadeOut("acid_rain", 0.5) -- Fade out the acid rain music
                convenientTrackFadeOut("radioactive_snow", 0.5) -- Fade out
                
                -- fade in the acid rain music & ambiance
                convenientTrackFadeIn("fair_weather", 0.5) -- Fade in the fair weather music
                convenientTrackFadeIn("regular-ambiance", 0.5)
                
            end
            
            globals.previous_weather_event = globals.current_weather_event -- update the previous weather event
        
        elseif (globals.current_weather_event == "acid_rain") then
            -- TODO: spawn green particles everywhere
            
            if globals.previous_weather_event ~= globals.current_weather_event then
                -- if the previous weather event was not acid rain, then queue the music
                
                -- fade out everything, if it is not already at 0 volume
                convenientTrackFadeOut("snow-ambiance", 0.5) -- Fade out the snow ambiance music
                convenientTrackFadeOut("regular-ambiance", 0.5) -- Fade out the regular ambiance music
                convenientTrackFadeOut("rain-ambiance", 0.5) -- Fade out the rain ambiance music
                convenientTrackFadeOut("fair_weather", 0.5) --  
                convenientTrackFadeOut("acid_rain", 0.5) -- Fade out the acid rain music
                convenientTrackFadeOut("radioactive_snow", 0.5) -- Fade out
                
                -- -- fade in the acid rain music & ambiance
                -- convenientTrackFadeIn("acid_rain", 0.5) -- Fade in the acid rain music
                -- convenientTrackFadeIn("rain-ambiance", 0.5) 
                setTrackVolume("acid_rain", 0.3) -- set the acid rain music to 1.0 volume
                setTrackVolume("rain-ambiance", 1.0) -- set the rain
                
            end
            
            globals.previous_weather_event = globals.current_weather_event -- update the previous weather event
        
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
            
            -- only do damage if game isn't paused
            if globals.gamePaused then
                return -- If the game is paused, do not apply damage
            end
            
            -- choose a random colonist with 50% chance
            if random_utils.random_int(0, 1) == 0 then
                local acid_rain_def = findInTable(
                    globals.weather_event_defs, "id", "acid_rain"
                )
                
                local colonist = nil
                
                -- if there are damage cushions, then choose them as a priority
                if globals.damage_cushions and #globals.damage_cushions > 0 then
                    -- choose a random damage cushion
                    local index = random_utils.random_int(1, #globals.damage_cushions)
                    colonist = globals.damage_cushions[index]
                    
                    log_debug("got damage cushion at index",index)
                    
                    log_debug("Acid rain event: applying damage to damage cushion:", colonist)
                    
                    
                    if not registry:valid(colonist) then
                        log_debug("Damage cushion is not valid, skipping damage application")
                        globals.damage_cushions[index] = nil -- remove the invalid damage cushion
                        return -- If the damage cushion is not valid, do not apply damage
                    end
                    
                else 
                    -- if there are no damage cushions, then choose a random colonist
                    
                    local fullColonistList = {}
                    -- add all colonists to the fullColonistList
                    lume.extend(fullColonistList, globals.colonists)
                    lume.extend(fullColonistList, globals.healers)
                    lume.extend(fullColonistList, globals.gold_diggers)
                    
                    -- choose a random colonist from the fullColonistList
                    if #fullColonistList > 0 then
                        colonist = fullColonistList[random_utils.random_int(1, #fullColonistList)]
                    else
                        log_debug("No colonists available to apply acid rain damage to.")
                        return -- If there are no colonists, do not apply damage
                    end
                end
                -- choose a random colonist
                
                log_debug("Acid rain event: applying damage to colonist:", colonist)
                
                if not registry:valid(colonist) or colonist == entt_null then
                    log_debug("Colonist is not valid, skipping damage application")
                    lume.remove(globals.colonists, colonist) -- remove the invalid colonist from the list
                    lume.remove(globals.healers, colonist) -- remove the invalid colonist from the list
                    lume.remove(globals.gold_diggers, colonist) -- remove the invalid colonist_ui
                    return -- If the colonist is not valid, do not apply damage
                end
                
                -- chance to dodge the damage
                if random_utils.random_float(0, 1.0) < totalDodgeChance then
                    log_debug("Colonist dodged the acid rain damage")
                    playSoundEffect("effects", "dodge") -- play dodge sound effect
                    -- call all onDodgeCallbacks
                    for _, callback in ipairs(onDodgeCallbacks) do
                        callback(colonist)
                    end
                    local colonistTransform = registry:get(colonist, Transform)
                    newTextPopup(
                        localization.get("ui.dodgedText"), -- text to display
                        colonistTransform.actualX + colonistTransform.visualW / 2, -- position at the center of the colonist
                        colonistTransform.actualY - 50, -- position above the colonist
                        5 -- duration in seconds
                    )
                    return -- If the colonist dodged, do not apply damage
                end
                
                -- set the blackboard health value (reduce health by 1)
                if colonist and registry:valid(colonist) then
                    
                    local damage_done = random_utils.random_float(1, globals.current_weather_event_base_damage) -- random damage between 1 and base damage
                    
                    if (totalGlobalDamageReduction > 0) then
                        damage_done = damage_done - totalGlobalDamageReduction -- reduce damage by global damage reduction
                        log_debug("Acid rain event: applying global damage reduction:", totalGlobalDamageReduction, "to damage:", damage_done)
                        -- make sure damage is not negative
                        if damage_done < 0 then
                            damage_done = 0 
                        end
                    end
                    
                    if (totalAcidDamageReduction > 0) then
                        damage_done = damage_done - totalAcidDamageReduction -- reduce damage by acid damage reduction
                        log_debug("Acid rain event: applying acid damage reduction:", totalAcidDamageReduction, "to damage:", damage_done)
                        -- make sure damage is not negative
                        if damage_done < 0 then
                            damage_done = 0 
                        end
                    end
                    
                    if totalDamageTakenMultiplier ~= 1.0 then
                        damage_done = damage_done * totalDamageTakenMultiplier -- apply damage taken multiplier
                        log_debug("Acid rain event: applying damage taken multiplier:", totalDamageTakenMultiplier, "to damage:", damage_done)
                    end
                    
                    log_debug("Acid rain event: applying damage:", damage_done, "to colonist:", colonist)
                    
                    setBlackboardFloat(colonist, "health", getBlackboardFloat(colonist, "health") - damage_done)  
                    
                    -- show a text popup above the colonist
                    local colonistTransform = registry:get(colonist, Transform)
                    newTextPopup(
                        localization.get("ui.acid_rain_damage_text", {damage = damage_done}), -- text to display
                        colonistTransform.actualX + colonistTransform.visualW / 2, -- position at the center of the colonist
                        colonistTransform.actualY - 50, -- position above the colonist
                        5 -- duration in seconds
                    )
                    
                    playSoundEffect("effects", "damage-tick") -- play acid rain damage sound effect
                    
                    -- call all onHitCallbacks
                    for _, callback in ipairs(onHitCallbacks) do
                        callback(colonist, damage_done) -- pass the colonist and damage done to the callback
                    end
                end
            end
        elseif (globals.current_weather_event == "snow") then
            if globals.previous_weather_event ~= globals.current_weather_event then
                -- if the previous weather event was not acid rain, then queue the music
                
                -- fade out everything, if it is not already at 0 volume
                convenientTrackFadeOut("snow-ambiance", 0.5) -- Fade out the snow ambiance music
                convenientTrackFadeOut("regular-ambiance", 0.5) -- Fade out the regular ambiance music
                convenientTrackFadeOut("rain-ambiance", 0.5) -- Fade out the rain ambiance music
                convenientTrackFadeOut("fair_weather", 0.5) --  
                convenientTrackFadeOut("acid_rain", 0.5) -- Fade out the acid rain music
                convenientTrackFadeOut("radioactive_snow", 0.5) -- Fade out
                
                -- fade in the acid rain music & ambiance
                -- convenientTrackFadeIn("radioactive_snow", 0.5) -- Fade in the acid rain music
                -- convenientTrackFadeIn("snow-ambiance", 0.5) 
                
                setTrackVolume("radioactive_snow", 0.3) -- set the acid rain music to 1.0 volume
                setTrackVolume("snow-ambiance", 1.0) -- set the rain
            end
            
            globals.previous_weather_event = globals.current_weather_event -- update the previous weather event
            
            timer.every(
                0.1, -- every 0.1 seconds
                function()
                    spawnSnowPlopAtRandomLocation()
                end,
                5, -- repeat 10 times
                true, -- start immediately
                nil, -- no "after" callback
                "radio_snow_particle_spawn"
            )
            
            -- only do damage if game isn't paused
            if globals.gamePaused then
                return -- If the game is paused, do not apply damage
            end
            
            -- choose a random colonist with 100% chance
            if true then
                local acid_rain_def = findInTable(
                    globals.weather_event_defs, "id", "snow"
                )
                
                local colonist = nil
                
                -- if there are damage cushions, then choose them as a priority
                if globals.damage_cushions and #globals.damage_cushions > 0 then
                    -- choose a random damage cushion
                    local index = random_utils.random_int(1, #globals.damage_cushions)
                    colonist = globals.damage_cushions[index]
                    
                    log_debug("got damage cushion at index",index)
                    
                    log_debug("snow event: applying damage to damage cushion:", colonist)
                    
                    if not registry:valid(colonist) then
                        log_debug("Damage cushion is not valid, skipping damage application")
                        globals.damage_cushions[index] = nil -- remove the invalid damage cushion
                        return -- If the damage cushion is not valid, do not apply damage
                    end
                    
                else 
                    -- if there are no damage cushions, then choose a random colonist
                    
                    local fullColonistList = {}
                    -- add all colonists to the fullColonistList
                    lume.extend(fullColonistList, globals.colonists)
                    lume.extend(fullColonistList, globals.healers)
                    lume.extend(fullColonistList, globals.gold_diggers)
                    
                    -- choose a random colonist from the fullColonistList
                    if #fullColonistList > 0 then
                        colonist = fullColonistList[random_utils.random_int(1, #fullColonistList)]
                    else
                        log_debug("No colonists available to apply snow damage to.")
                        return -- If there are no colonists, do not apply damage
                    end
                end
                -- choose a random colonist
                
                if not registry:valid(colonist) or colonist == entt_null then
                    log_debug("Colonist is not valid, skipping damage application")
                    lume.remove(globals.colonists, colonist) -- remove the invalid colonist from the list
                    lume.remove(globals.healers, colonist) -- remove the invalid colonist from the list
                    lume.remove(globals.gold_diggers, colonist) -- remove the invalid colonist_ui
                    return -- If the colonist is not valid, do not apply damage
                end
                
                -- chance to dodge the damage
                if random_utils.random_float(0, 1.0) < totalDodgeChance then
                    log_debug("Colonist dodged the acid rain damage")
                    playSoundEffect("effects", "dodge") -- play dodge sound effect
                    -- call all onDodgeCallbacks
                    for _, callback in ipairs(onDodgeCallbacks) do
                        callback(colonist)
                    end
                    local colonistTransform = registry:get(colonist, Transform)
                    newTextPopup(
                        localization.get("ui.dodgedText"), -- text to display
                        colonistTransform.actualX + colonistTransform.visualW / 2, -- position at the center of the colonist
                        colonistTransform.actualY - 50, -- position above the colonist
                        5 -- duration in seconds
                    )
                    return -- If the colonist dodged, do not apply damage
                end
                
                log_debug("snow event: applying damage to colonist:", colonist)
                if not registry:valid(colonist) then
                    log_debug("Colonist is not valid, skipping damage application")
                    lume.remove(globals.colonists, colonist) -- remove the invalid colonist from the list
                    lume.remove(globals.healers, colonist) -- remove the invalid colonist from the list
                    lume.remove(globals.gold_diggers, colonist) -- remove the invalid colonist_ui
                    return -- If the colonist is not valid, do not apply damage
                end
                
                -- set the blackboard health value (reduce health by 1)
                if colonist and registry:valid(colonist) then
                    
                    local damage_done = random_utils.random_float(1, globals.current_weather_event_base_damage) * 0.5 -- halve the base damage
                    
                    if (totalGlobalDamageReduction > 0) then
                        damage_done = damage_done - totalGlobalDamageReduction -- reduce damage by global damage reduction
                        log_debug("snow event: applying global damage reduction:", totalGlobalDamageReduction, "to damage:", damage_done)
                        -- make sure damage is not negative
                        if damage_done < 0 then
                            damage_done = 0 
                        end
                    end
                    
                    if (totalColdDamageReduction > 0) then
                        damage_done = damage_done - totalColdDamageReduction -- reduce damage by cold damage reduction
                        log_debug("snow event: applying cold damage reduction:", totalColdDamageReduction, "to damage:", damage_done)
                        -- make sure damage is not negative
                        if damage_done < 0 then
                            damage_done = 0 
                        end
                    end
                    
                    if totalDamageTakenMultiplier ~= 1.0 then
                        damage_done = damage_done * totalDamageTakenMultiplier -- apply damage taken multiplier
                        log_debug("Acid rain event: applying damage taken multiplier:", totalDamageTakenMultiplier, "to damage:", damage_done)
                    end
                    
                    log_debug("snow event: applying damage:", damage_done, "to colonist:", colonist)
                    
                    setBlackboardFloat(colonist, "health", getBlackboardFloat(colonist, "health") - damage_done)  
                    
                    -- show a text popup above the colonist
                    local colonistTransform = registry:get(colonist, Transform)
                    newTextPopup(
                        localization.get("ui.snow_damage_text", {damage = damage_done}), -- text to display
                        colonistTransform.actualX + colonistTransform.visualW / 2, -- position at the center of the colonist
                        colonistTransform.actualY - 50, -- position above the colonist
                        5 -- duration in seconds
                    )
                    
                    playSoundEffect("effects", "damage-tick") -- play acid rain damage sound effect
                    
                    -- call all onHitCallbacks
                    for _, callback in ipairs(onHitCallbacks) do
                        callback(colonist, damage_done) -- pass the colonist and damage done to the callback
                    end
                end
            end
        end
    end,
    0, -- start immediately
    true,
    nil, -- no "after" callback
    "weather_event_timer" -- unique tag for this timer
    )
    
    log_debug("Setting up colonist death check timer")
    log_debug("colonists", globals.colonists)
    log_debug("healers", globals.healers)
    log_debug("gold_diggers", globals.gold_diggers)
    log_debug("damage_cushions", globals.damage_cushions)
    -- every 1 second, check every colonist
    function checkColonistDeaths()
        local colonists = lume.clone(globals.colonists or {})
        lume.extend(colonists, globals.healers or {})
        lume.extend(colonists, globals.gold_diggers or {})
        lume.extend(colonists, globals.damage_cushions or {})

        log_debug("Checking colonists for death. Count:", #colonists)

        for _, colonist in pairs(colonists) do
            if registry:valid(colonist) and getBlackboardFloat(colonist, "health") <= 0 then
                local ok, err = pcall(function()
                    local transform = registry:get(colonist, Transform)

                    newTextPopup(localization.get("ui.colonist_dead_text"),
                                transform.actualX + transform.visualW / 2,
                                transform.actualY - 50,
                                5)

                    playSoundEffect("effects", "die")
                    spawnCircularBurstParticles(
                        transform.actualX + transform.visualW / 2,
                        transform.actualY + transform.visualH / 2,
                        50, 10,
                        util.getColor("red"), util.getColor("black"))

                    globals.colonists[colonist] = nil
                    globals.healers[colonist] = nil
                    globals.gold_diggers[colonist] = nil
                    globals.damage_cushions[colonist] = nil

                    local ui = globals.ui.colonist_ui[colonist]
                    if ui and ui.hp_ui_box then
                        ui.box.Remove(registry, ui.hp_ui_box)
                    end

                    registry:destroy(colonist)
                end)

                if not ok then
                    log_debug("Colonist death check failed:", err)
                end
            end
        end
    end

    timer.every(0.3, checkColonistDeaths, 0, true, nil)
    
    changeGameState(GAMESTATE.MAIN_MENU) -- Initialize the game in the IN_GAME state
end

function main.update(dt)
    
    if (globals.gamePaused or currentGameState == GAMESTATE.MAIN_MENU) then
        return -- If the game is paused, do not update anything
    end
    
    if (currentGameState == GAMESTATE.MAIN_MENU) then
        globals.main_menu_elapsed_time = globals.main_menu_elapsed_time + dt
    end
    
    -- Update the game time
    -- how many game‐seconds should pass per real second
    local gameTimeSpeedUpFactor = 2500

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
