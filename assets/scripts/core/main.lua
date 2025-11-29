require("init.bit_compat")
require("core.globals")
require("registry")
require("ai.init") -- Read in ai scripts and populate the ai table
require("util.util")
require("ui.ui_defs")
require("core.entity_factory")
require("core.gameplay")
local profile = require("external.profile")  -- https://github.com/2dengine/profile.lua
local z_orders = require("core.z_orders")
local Node = require("monobehavior.behavior_script_v2") -- the new monobehavior script
local palette = require("color.palette")
local combat_core = require("combat.combat_system")
local TimerChain = require("core.timer_chain")
local timer = require("core.timer")
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
local shader_uniforms = require("core.shader_uniforms")
local CastFeedUI = require("ui.cast_feed_ui")
-- local bit = require("bit") -- LuaJIT's bit library
local shader_prepass = require("shaders.prepass_example")
lume = require("external.lume")
-- Represents game loop main module
main = main or {}

PROFILE_ENABLED = false -- set to true to enable profiling

-- Game state (used only in lua)
GAMESTATE = {
    MAIN_MENU = 0,
    IN_GAME = 1
}

shapeAnimationPhase = 0

local currentGameState = GAMESTATE.MAIN_MENU -- Set the initial game state to IN_GAME

local telemetry_once_flags = {}
local function record_telemetry(event, props)
    -- Guard against missing bindings or runtime errors so gameplay keeps going.
    if type(telemetry) ~= "table" or type(telemetry.record) ~= "function" then
        return
    end
    local ok, err = pcall(telemetry.record, event, props or {})
    if not ok then
        if log_debug then
            log_debug(string.format("telemetry.record failed for %s: %s", event, tostring(err)))
        else
            print("telemetry.record failed for " .. tostring(event) .. ": " .. tostring(err))
        end
    end
end

-- Expose helpers globally for other modules (planning/action/shop phases).
_G.record_telemetry = record_telemetry
_G.telemetry_session_id = function()
    if type(telemetry) == "table" and type(telemetry.session_id) == "function" then
        return telemetry.session_id()
    end
    return "lua-session-unknown"
end

local function record_telemetry_once(flag, event, props)
    if telemetry_once_flags[flag] then
        return
    end
    telemetry_once_flags[flag] = true
    record_telemetry(event, props)
end

local mainMenuEntities = {
}

function myCustomCallback()
    -- a test to see if the callback works for text typing
    wait(5)
    return true
end

function initMainMenu()
    
    add_layer_shader("sprites", "pixelate_image")
    -- add_fullscreen_shader("pixelate_image")
    globalShaderUniforms:set("pixelate_image", "pixelRatio", 0.6)
    
    -- create a timer to increment the phase
    timer.run(
        function()
            shapeAnimationPhase = shapeAnimationPhase + 1
        end
    )
    
    
    globals.currentGameState = GAMESTATE.MAIN_MENU -- Set the game state to MAIN_MENU
    record_telemetry_once("scene_main_menu", "scene_enter", { scene = "main_menu" })
    setCategoryVolume("effects", 0.5)
    playMusic("main-menu", true) 
    setTrackVolume("main-menu", 0.3)
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
    local logoTransform = component_cache.get(globals.ui.logo, Transform)
    logoTransform.actualX = globals.screenWidth() / 2 - logoTransform.actualW / 2
    logoTransform.actualY = globals.screenHeight() / 2 - logoTransform.actualH / 2 - 400 -- move it up a bit
    
    timer.every(
        0.1, -- every 0.5 seconds
        function()
            -- make the text move up and down (bob)
            local transformComp = component_cache.get(globals.ui.logo, Transform)
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
                :addColor(util.getColor("gray"))
                :addEmboss(2.0)
                :addMinWidth(500) -- minimum width of the button
                :addShadow(true)
                :addHover(true) -- needed for button effect
                :addButtonCallback(function ()
                    playSoundEffect("effects", "button-click") -- play button click sound
                    startGameButtonCallback() -- callback for the start game button
                end)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
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
                :addColor(util.getColor("gray"))
                :addEmboss(2.0)
                :addMinWidth(500) -- minimum width of the button
                :addButtonCallback(function ()
                    playSoundEffect("effects", "button-click") -- play button click sound
                    -- Open the Discord link
                    record_telemetry("discord_button_clicked", { scene = "main_menu" })
                    OpenURL("https://discord.gg/urpjVuPwjW") 
                end)
                :addShadow(true)
                :addMinWidth(500) -- minimum width of the button
                :addHover(true) -- needed for button effect
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
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
                :addColor(util.getColor("gray"))
                :addEmboss(2.0)
                :addButtonCallback(function ()
                    playSoundEffect("effects", "button-click") -- play button click sound
                    -- Open the Bluesky link
                    record_telemetry("follow_button_clicked", { scene = "main_menu", platform = "bluesky" })
                    OpenURL("https://bsky.app/profile/chugget.itch.io") 
                end)
                :addShadow(true)
                :addHover(true) -- needed for button effect
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :build()
        )
        :addChild(blueskyText)
        :addChild(blueskyIconTemplate)
        :build()
        
    local inputTextElement = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.INPUT_TEXT)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("gray"))
                :addEmboss(2.0)
                :addShadow(true)
                :addMinHeight(50) -- minimum height of the input text
                :addMinWidth(300) -- minimum width of the input text
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :build()
        )
    :build()
        
    local inputTextRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("gray"))
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
            :addColor(util.getColor("yellow"))
            :addShadow(true)
            :addHeight(200)
            :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
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
    local mainMenuTransform = component_cache.get(mainMenuEntities.main_menu_uibox, Transform)
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
                :addColor(util.getColor("gray"))
                :addEmboss(2.0)
                :addShadow(true)
                :addHover(true) -- needed for button effect
                :addButtonCallback(function ()
                    playSoundEffect("effects", "button-click") -- play button click sound
            -- Switch the language
            if (localization.getCurrentLanguage() == "en_us") then
                record_telemetry("language_changed", { from = "en_us", to = "ko_kr", session_id = telemetry_session_id() })
                localization.setCurrentLanguage("ko_kr")
            else
                record_telemetry("language_changed", { from = "ko_kr", to = "en_us", session_id = telemetry_session_id() })
                localization.setCurrentLanguage("en_us")
            end
        end)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :build()
        )
        :addChild(languageText)
        :build()
        
    -- new root
    local languageButtonRoot = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.ROOT)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("green"))
                :addShadow(true)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
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
    local languageButtonTransform = component_cache.get(mainMenuEntities.language_button_uibox, Transform)
    languageButtonTransform.actualX = globals.screenWidth() - languageButtonTransform.actualW - 20
    languageButtonTransform.actualY = globals.screenHeight() - languageButtonTransform.actualH - 20
    
end

function startGameButtonCallback()
    clearMainMenu() -- clear the main menu
                    
    record_telemetry("start_game_clicked", { scene = "main_menu" })
    
    --TODO: add full screeen transition shader, tween the value of that
    add_fullscreen_shader("screen_tone_transition") -- Add the fade out shader
    
    fadeOutMusic("main-menu", 1.0) -- Fade out the main menu music over 1 second
    
    -- 0 is dark, 1 is light
    globalShaderUniforms:set("screen_tone_transition", "position", 1)
    
    timer.tween_scalar(
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
            timer.tween_scalar(
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
            
            
            -- add_fullscreen_shader("pixelate_image")
            
        end,
        "main_menu_to_game_state_change" -- unique tag for this timer
    )
    
end
function clearMainMenu() 
    --TODO:
    -- for each entity in mainMenuEntities, push it down out of view
    for _, entity in pairs(mainMenuEntities) do
        if registry:has(entity, Transform) then
            local transform = component_cache.get(entity, Transform)
            transform.actualY = globals.screenHeight() + 500 -- push it down out of view
        end
    end
    
    -- move global.ui.logo out of view
    local logoTransform = component_cache.get(globals.ui.logo, Transform)
    logoTransform.actualY = globals.screenHeight() + 500 -- push it down out of view
    
    
    -- delete tiemrs
    timer.cancel("logo_text_update") -- cancel the logo text update timer
    timer.cancel("logo_text_pulse") -- cancel the logo text pulse timer
end

boards = {}



function initMainGame()
    
    print("Runtime:", jit and jit.version or _VERSION)

    
    setTrackVolume("main-menu", 0.0)
    
    playPlaylist({ "main-music-1", "main-music-2", "main-music-3", "main-music-4", "main-music-5" }, true) -- loop.

    
    log_debug("Initializing main game...") -- Debug message to indicate the game is starting
    currentGameState = GAMESTATE.IN_GAME -- Set the game state to IN_GAME
    record_telemetry_once("scene_main_game", "scene_enter", { scene = "main_game" })
    
    initPlanningPhase()
    initActionPhase()
    initPlanningUI()
    initShopPhase()

    -- begin in planning state by default
    startPlanningPhase()
    
    -- run debug ui every frame.
    timer.run_every_render_frame(
        function()
            debugUI()
        end
    )
    
    
    if os.getenv("RUN_PROJECTILE_TESTS") == "1" then
        record_telemetry("debug_tests_enabled", { suite = "projectile" })
        ProjectileSystemTest = require("test_projectiles")
    end

    local runWandTests = os.getenv("RUN_WAND_TESTS") == "1"
    if runWandTests then
        record_telemetry("debug_tests_enabled", { suite = "wand" })
        local WandTests = require("wand.wand_test_examples")
        WandTests.runAllTests()
    end

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




ProjectileSystemTest = nil
  
-- Main function to initialize the game. Called at the start of the game.
function main.init()
    log_debug("Game initializing...") -- Debug message to indicate the game is initializing
    record_telemetry_once("session_start", "session_start", {
        session_id = telemetry_session_id(),
        scene = "boot"
    })
    record_telemetry_once("lua_runtime_init", "lua_runtime_init", {
        lua = _VERSION,
        jit = jit and jit.version or "none"
    })
    math.randomseed(12345)
    if PROFILE_ENABLED then
        profile.start()
    end

    -- Initialize shader uniforms in Lua (migrating from C++).
    if globalShaderUniforms then
        shader_uniforms.init()
    else
        log_warn("shader_uniforms.init skipped: globalShaderUniforms not ready")
    end

    
    -- register color palette "RESURRECT-64"
    palette.register{
        names   = {"Blackberry", "Dark Lavender", "Muted Plum", "Dusty Rose", "Warm Taupe", "Shadow Mauve", "Slate Purple", "Soft Steel", "Pale Mint", "White", "Dark Crimson", "Fiery Red", "Tomato Red", "Apricot", "Burgundy", "Coral Red", "Tangerine", "Goldenrod", "Sunflower", "Mulberry", "Chestnut", "Rust", "Amber", "Marigold", "Espresso", "Olive Drab", "Moss Green", "Chartreuse", "Lemon Chiffon", "Deep Teal", "Jade Green", "Seafoam Green", "Mint Green", "Lime", "Charcoal", "Forest Slate", "Verdigris", "Sage", "Olive Mist", "Teal Blue", "Cyan Green", "Turquoise", "Aqua", "Pale Aqua", "Midnight Blue", "Indigo", "Royal Blue", "Sky Blue", "Baby Blue", "Plum", "Violet", "Purple Orchid", "Lavender", "Pink Blush", "Wine", "Rosewood", "Blush Pink", "Coral Pink", "Deep Magenta", "Raspberry", "Fuchsia", "Pastel Pink", "Peach", "Apricot Cream" }
    }
    
    -- input binding test
    input.bind("do_something", { device="keyboard", key=KeyboardKey.KEY_SPACE, trigger="Pressed", context="gameplay" })
    -- input.bind("do_something_else", { device="keyboard", key=KeyboardKey.KEY_SPACE, trigger="Released", context="gameplay" })
    -- input.set_context("gameplay") -- set the input context to gameplay
    input.bind("mouse_click", { device="mouse", key=MouseButton.BUTTON_LEFT, trigger="Pressed", context="gameplay" })
    
    

    
    -- timer.every(0.16, function()
        
        -- if input.action_pressed("do_something") then
        --     log_debug("Space key pressed!") -- Debug message to indicate the space key was pressed
        -- end
        -- if input.action_released("do_something") then
        --     log_debug("Space key released!") -- Debug message to indicate the space key was released
        -- end
    --     if input.action_down("do_something") then
    --         log_debug("Space key down!") -- Debug message to indicate the space key is being held down
            
    --         local mouseT           = component_cache.get(globals.cursor(), Transform)
            
            
    --         -- Try one at a time to see effects clearly
    --         -- TestCircularBurst()
    --         -- TestFan()
    --         -- TestImageBurst()
    --         -- TestRing()
    --         -- TestRectArea()
    --         -- TestCone()
    --         -- TestFountain()
    --         TestExplosion()
            
    --         -- spawnGrowingCircleParticle(mouseT.visualX, mouseT.visualY, 100, 100, 0.2)
            
    --         -- spawnCircularBurstParticles(
    --         --     mouseT.visualX, 
    --         --     mouseT.visualY, 
    --         --     5, -- count
    --         --     0.5, -- seconds
    --         --     util.getColor("blue"), -- start color
    --         --     util.getColor("purple"), -- end color
    --         --     "outCubic", -- from util.easing
    --         --     "screen" -- screen space
    --         -- )
            
    --         -- slowTime(5, 0.2) -- slow time to 50% for 0.2 seconds
    --     end
        
    -- end)
    
    -- enable debug mode if the environment variable is set
    if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
        require("lldebugger").start()
    end
    
    timer.every(0.2, function()
        -- tracy.zoneBeginN("Tooltip Hide Timer Tick") -- just some default depth to avoid bugs
        if entity_cache.valid(globals.inputState.cursor_hovering_target) == false or globals.inputState.cursor_hovering_target == globals.gameWorldContainerEntity()  then
            hideTooltip() -- Hide the tooltip if the cursor is not hovering over any target
        end
        -- tracy.zoneEnd()
    end,
    0, -- start immediately)
    true,
    nil, -- no "after" callback
    "tooltip_hide_timer" -- unique tag for this timer
    )
    
    changeGameState(GAMESTATE.MAIN_MENU) -- Initialize the game in the IN_GAME state
    
end

local prevFrameCounter = 0

local profileFrameCounter = 0
local printProfileEveryNFrames = 1 -- print profile every N frames


physicsTickCounter = 0
function main.update(dt)
    -- tracy.zoneBeginN("lua main.update") -- just some default depth to avoid bugs
    local currentRenderFrameCount = main_loop.data.renderFrame
    local isRenderFrame = (currentRenderFrameCount ~= prevFrameCounter)
    prevFrameCounter = currentRenderFrameCount
    
    if PROFILE_ENABLED then
        profileFrameCounter = profileFrameCounter + 1
        if profileFrameCounter >= printProfileEveryNFrames then
            profileFrameCounter = 0
            local rep = profile.report(30) -- print top X functions
            log_debug("Profile Report:\n" .. rep)
            profile.reset()
        end
    end
    -- begin frame for cache.
    component_cache.begin_frame()

    
    -- timer updates.
    physicsTickCounter = main_loop.data.physicsTicks
    
    timer.update(dt, isRenderFrame) -- Update the timer system
    timer.update_physics_step() -- Update the timer system for physics steps
    
    
    -- caching systems.
    entity_cache.update_frame() -- Update the entity cache for the current frame

    component_cache.update_frame() -- Update the component cache for the current frame
    
    -- Node system (lua side)
    Node.update_all(dt) -- Update all nodes with update() functions
    
    
    if (globals.gamePaused or currentGameState == GAMESTATE.MAIN_MENU) then
        return -- If the game is paused, do not update anything
    end
    
    if (currentGameState == GAMESTATE.MAIN_MENU) then
        globals.main_menu_elapsed_time = globals.main_menu_elapsed_time + dt
    end
    
    if ProjectileSystemTest ~= nil then
        ProjectileSystemTest.update(dt)
    end
    
    -- tracy.zoneEnd()
    
    -- end frame for cache.
    component_cache.end_frame()
end

function main.draw(dt)
   -- tracy.zoneBeginN("lua main.draw") -- just some default depth to avoid bugs
   -- tracy.zoneEnd()
end
