require("core.globals")
require("registry")
require("ai.init") -- Read in ai scripts and populate the ai table
require("util.util")
require("ui.ui_defs")
require("core.entity_factory")
require("monobehavior.behavior_script_v2") -- the new monobehavior script
local palette = require("color.palette")
local combat_core = require("combat.combat_system")
local TimerChain = require("core.timer_chain")

local shader_prepass = require("shaders.prepass_example")
lume = require("external.lume")
-- Represents game loop main module
main = {}

-- Game state (used only in lua)
GAMESTATE = {
    MAIN_MENU = 0,
    IN_GAME = 1
}

local currentGameState = GAMESTATE.MAIN_MENU -- Set the initial game state to IN_GAME

local mainMenuEntities = {
}

function myCustomCallback()
    -- a test to see if the callback works for text typing
    wait(5)
    return true
end

function initMainMenu()
    
    add_fullscreen_shader("pixelate_image")
    globalShaderUniforms:set("pixelate_image", "pixelRatio", 0.85)
    
    
    globals.currentGameState = GAMESTATE.MAIN_MENU -- Set the game state to MAIN_MENU
    setCategoryVolume("effects", 0.2)
    -- playMusic("main-menu", true) -- Play the main menu music
    -- create start game button
    
    
    -- create main logo
    globals.ui.logo = animation_system.createAnimatedObjectWithTransform(
        "b3832.png", -- animation ID
        true             -- use animation, not sprite identifier, if false
    )
    animation_system.resizeAnimationObjectsInEntityToFit(
        globals.ui.logo,
        64 * 3,   -- width
        64 * 3    -- height
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
        
    local inputTextElement = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.INPUT_TEXT)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("taupe_warm"))
                :addEmboss(2.0)
                :addShadow(true)
                :addMinHeight(50) -- minimum height of the input text
                :addMinWidth(300) -- minimum width of the input text
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
                :build()
        )
    :build()
        
    local inputTextRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("taupe_warm"))
                :addEmboss(2.0)
                :build()
        )
    :addChild(inputTextElement)
    :build()
    
    -- create animation entity for discord
        
    local startMenuRoot = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.SCROLL_PANE)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("mauve_shadow"))
            :addShadow(true)
            :addHeight(200)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(startButtonTemplate)
    :addChild(discordRow)
    :addChild(blueskyRow)
    :addChild(inputTextRow)
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
            
            
            add_fullscreen_shader("pixelate_image")
            
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
    setTrackVolume("main-menu", 0.0)
    
    log_debug("Initializing main game...") -- Debug message to indicate the game is starting
    currentGameState = GAMESTATE.IN_GAME -- Set the game state to IN_GAME
    
    -- -- set game to paused
    togglePausedState(true) -- Set the game to paused state
    
    
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
    -- register color palette "RESURRECT-64"
    palette.register{
        names   = {"Blackberry", "Dark Lavender", "Muted Plum", "Dusty Rose", "Warm Taupe", "Shadow Mauve", "Slate Purple", "Soft Steel", "Pale Mint", "White", "Dark Crimson", "Fiery Red", "Tomato Red", "Apricot", "Burgundy", "Coral Red", "Tangerine", "Goldenrod", "Sunflower", "Mulberry", "Chestnut", "Rust", "Amber", "Marigold", "Espresso", "Olive Drab", "Moss Green", "Chartreuse", "Lemon Chiffon", "Deep Teal", "Jade Green", "Seafoam Green", "Mint Green", "Lime", "Charcoal", "Forest Slate", "Verdigris", "Sage", "Olive Mist", "Teal Blue", "Cyan Green", "Turquoise", "Aqua", "Pale Aqua", "Midnight Blue", "Indigo", "Royal Blue", "Sky Blue", "Baby Blue", "Plum", "Violet", "Purple Orchid", "Lavender", "Pink Blush", "Wine", "Rosewood", "Blush Pink", "Coral Pink", "Deep Magenta", "Raspberry", "Fuchsia", "Pastel Pink", "Peach", "Apricot Cream" }
    }
    
    -- input binding test
    input.bind("do_something", { device="keyboard", key=KeyboardKey.KEY_SPACE, trigger="Pressed", context="gameplay" })
    input.bind("do_something_else", { device="keyboard", key=KeyboardKey.KEY_SPACE, trigger="Released", context="gameplay" })
    -- input.set_context("gameplay") -- set the input context to gameplay
    input.bind("mouse_click", { device="mouse", key=MouseButton.BUTTON_LEFT, trigger="Pressed", context="gameplay" })
    
    

    
    timer.every(0.16, function()
        
        if input.action_pressed("do_something") then
            log_debug("Space key pressed!") -- Debug message to indicate the space key was pressed
        end
        if input.action_released("do_something") then
            log_debug("Space key released!") -- Debug message to indicate the space key was released
        end
        if input.action_down("do_something") then
            log_debug("Space key down!") -- Debug message to indicate the space key is being held down
            
            local mouseT           = registry:get(globals.cursor(), Transform)
            
            -- spawnGrowingCircleParticle(mouseT.visualX, mouseT.visualY, 100, 100, 0.2)
            
            spawnCircularBurstParticles(
                mouseT.visualX, 
                mouseT.visualY, 
                5, -- count
                0.5, -- seconds
                util.getColor("apricot_cream"), -- start color
                util.getColor("coral_pink"), -- end color
                "outCubic", -- from util.easing
                "screen" -- screen space
            )
        end
        
    end)
    
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
    
    changeGameState(GAMESTATE.MAIN_MENU) -- Initialize the game in the IN_GAME state
end

function main.update(dt)
    
    if (globals.gamePaused or currentGameState == GAMESTATE.MAIN_MENU) then
        return -- If the game is paused, do not update anything
    end
    
    if (currentGameState == GAMESTATE.MAIN_MENU) then
        globals.main_menu_elapsed_time = globals.main_menu_elapsed_time + dt
    end
    
end

function main.draw(dt)
   
end
