require("init.bit_compat")
require("core.globals")
-- registry is a C++ global exposed via Sol2, not a Lua module - removed invalid require
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
local InventoryTabMarker = require("ui.inventory_tab_marker")
-- local bit = require("bit") -- LuaJIT's bit library
local shader_prepass = require("shaders.prepass_example")
lume = require("external.lume")
local TextBuilderDemo = require("demos.text_builder_demo")
local Text = require("core.text") -- TextBuilder system for fire-and-forget text
local TutorialDialogueDemo = require("tutorial.dialogue.demo")
local LightingDemo = require("demos.lighting_demo")
-- local RenderGroupsTest = require("tests.test_render_groups_visual") -- Visual test for render groups (disabled: DrawRenderGroup command not registered)
local SpecialItem = require("core.special_item")
SaveManager = require("core.save_manager") -- Global for C++ debug UI access
local PatchNotesModal = require("ui.patch_notes_modal")
local ok, InventoryGridDemo = pcall(require, "examples.inventory_grid_demo")
if not ok then
    print("[ERROR] Failed to load InventoryGridDemo: " .. tostring(InventoryGridDemo))
    InventoryGridDemo = nil
end
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
local autoStartMainGameEnv = (os.getenv and ((os.getenv("AUTO_START_MAIN_GAME") == "1") or (os.getenv("AUTO_ACTION_PHASE") == "1"))) or false

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

local MAIN_MENU_TIMER_GROUP = "main_menu"
local MAIN_MENU_PHASE_TIMER_TAG = "main_menu_shape_phase"

function myCustomCallback()
    -- a test to see if the callback works for text typing
    wait(5)
    return true
end

function initMainMenu()
    log_debug("[initMainMenu] Starting main menu initialization...")
    
    -- create a timer to increment the phase
    timer.run(
        function()
            shapeAnimationPhase = shapeAnimationPhase + 1
        end,
        nil,
        MAIN_MENU_PHASE_TIMER_TAG,
        MAIN_MENU_TIMER_GROUP
    )
    
    
    globals.currentGameState = GAMESTATE.MAIN_MENU -- Set the game state to MAIN_MENU
    record_telemetry_once("scene_main_menu", "scene_enter", { scene = "main_menu" })
    setCategoryVolume("effects", 0.5)
    playMusic("main-menu", true)
    setTrackVolume("main-menu", 0.3)

    -- RenderGroupsTest.init() -- disabled

    local screenW = globals.screenWidth()
    local screenH = globals.screenHeight()
    local centerY = screenH / 2 - 100
    
    -- TEST: Using same shader for all 3 items to isolate shader vs position issue
    -- Uncomment one of these options to test:
    -- OPTION A: All prismatic (currently working shader)
    local testShader = "3d_skew_prismatic"
    -- OPTION B: All holo (currently not working)
    -- local testShader = "3d_skew_holo"

    log_debug("[SpecialItem Test] Using shader: " .. testShader .. " for all items")

    mainMenuEntities.special_item_1 = SpecialItem.new("frame0012.png")
        :at(screenW / 2 - 150, centerY)
        :size(64, 64)
        :shader(testShader)
        :particles("bubble", { colors = { "cyan", "magenta", "yellow" } })
        :outline("gold", 2)
        :build()

    mainMenuEntities.special_item_2 = SpecialItem.new("frame0012.png")
        :at(screenW / 2, centerY)
        :size(64, 64)
        :shader(testShader)
        :particles("sparkle", { colors = { "white", "gold" } })
        :outline("cyan", 2)
        :build()

    mainMenuEntities.special_item_3 = SpecialItem.new("frame0012.png")
        :at(screenW / 2 + 150, centerY)
        :size(64, 64)
        :shader(testShader)
        :particles("magical", { colors = { "purple", "blue", "pink" } })
        :outline("purple", 2)
        :build()

    -- DEBUG: Verify SpecialItem components
    local function debugSpecialItem(name, item)
        if not item then
            log_warn("[SpecialItem Debug] " .. name .. " is nil!")
            return
        end
        local eid = item:handle()
        if not entity_cache.valid(eid) then
            log_warn("[SpecialItem Debug] " .. name .. " has invalid entity handle!")
            return
        end
        local transform = component_cache.get(eid, Transform)
        local hasShaderPipeline = registry:has(eid, shader_pipeline.ShaderPipelineComponent)
        local hasAnimQueue = registry:has(eid, AnimationQueueComponent)
        local hasGameObject = registry:has(eid, GameObject)

        -- Check shader pipeline details
        local shaderInfo = "none"
        if hasShaderPipeline then
            local comp = component_cache.get(eid, shader_pipeline.ShaderPipelineComponent)
            if comp and comp.getPassCount then
                shaderInfo = tostring(comp:getPassCount()) .. " passes"
            else
                shaderInfo = "present"
            end
        end

        -- Check draw layer
        local layerInfo = "unknown"
        if hasGameObject then
            local go = component_cache.get(eid, GameObject)
            if go and go.layer then
                layerInfo = tostring(go.layer)
            end
        end

        log_debug(string.format("[SpecialItem Debug] %s: entity=%s, pos=(%.0f,%.0f), size=(%.0f,%.0f), shader=%s, animQueue=%s, layer=%s, particles=%s",
            name,
            tostring(eid),
            transform and transform.actualX or -1,
            transform and transform.actualY or -1,
            transform and transform.actualW or -1,
            transform and transform.actualH or -1,
            shaderInfo,
            hasAnimQueue and "YES" or "NO",
            layerInfo,
            item.particleStream and "YES" or "NO"
        ))
    end

    debugSpecialItem("special_item_1", mainMenuEntities.special_item_1)
    debugSpecialItem("special_item_2", mainMenuEntities.special_item_2)
    debugSpecialItem("special_item_3", mainMenuEntities.special_item_3)
    log_debug("[SpecialItem Debug] Active count: " .. SpecialItem.getActiveCount())

    -- Additional debug: Check entity version and renderer state
    local function checkEntityRenderState(name, item)
        if not item then return end
        local eid = item:handle()
        if not entity_cache.valid(eid) then return end

        -- Check if entity has a visible sprite frame
        local animQueue = component_cache.get(eid, AnimationQueueComponent)
        if animQueue then
            local defaultAnim = animQueue.defaultAnimation
            local animListEmpty = (not defaultAnim or not defaultAnim.animationList or #defaultAnim.animationList == 0)
            log_debug(string.format("[SpecialItem Debug] %s animList empty: %s", name, tostring(animListEmpty)))
        else
            log_debug(string.format("[SpecialItem Debug] %s has NO AnimationQueueComponent!", name))
        end

        -- Check draw layer in GameObject
        local go = component_cache.get(eid, GameObject)
        if go then
            log_debug(string.format("[SpecialItem Debug] %s drawLayer: %s, visible: %s, zIndex: %s",
                name,
                tostring(go.layer or "nil"),
                tostring(go.visible),
                tostring(go.zIndex or "nil")
            ))
        end
    end

    checkEntityRenderState("special_item_1", mainMenuEntities.special_item_1)
    checkEntityRenderState("special_item_2", mainMenuEntities.special_item_2)
    checkEntityRenderState("special_item_3", mainMenuEntities.special_item_3)

    -- create start game button
    
    
    -- create main logo
    -- globals.ui.logo = animation_system.createAnimatedObjectWithTransform(
    --     "b3832.png", -- animation ID
    --     true             -- use animation, not sprite identifier, if false
    -- )
    -- animation_system.resizeAnimationObjectsInEntityToFit(
    --     globals.ui.logo,
    --     64 * 3,   -- width
    --     64 * 3    -- height
    -- )
    -- -- center
    -- local logoTransform = component_cache.get(globals.ui.logo, Transform)
    -- logoTransform.actualX = globals.screenWidth() / 2 - logoTransform.actualW / 2
    -- logoTransform.actualY = globals.screenHeight() / 2 - logoTransform.actualH / 2 - 400 -- move it up a bit
    
    -- timer.every(
    --     0.1, -- every 0.5 seconds
    --     function()
    --         -- make the text move up and down (bob)
    --         local transformComp = component_cache.get(globals.ui.logo, Transform)
    --         local bobHeight = 10 -- height of the bob
    --         local time = os.clock() -- get the current time
    --         local bobOffset = math.sin(time * 2) * bobHeight -- calculate the offset
    --         transformComp.actualY = globals.screenHeight() / 2 - transformComp.actualH / 2 - 200 + bobOffset -- apply the offset to the Y position
            
    --     end,
    --     0, -- infinite repetitions
    --     true, -- start immediately
    --     nil, -- no "after" callback
    --     "logo_text_pulse",
    --     MAIN_MENU_TIMER_GROUP
    -- )
    
    
    local startButtonText = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.start_game_button") end,  -- initial text
        30.0,                                 -- font size
        "color=fuchsia"                       -- animation spec
    )
    local startButtonTemplate = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("muted_plum"))  -- Resurrect 64 palette
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
                :addColor(util.getColor("purple_slate"))  -- Resurrect 64 palette
                :addEmboss(2.0)
                :addMinWidth(500) -- minimum width of the button
                :addButtonCallback(function ()
                    playSoundEffect("effects", "button-click") -- play button click sound
                    -- Open the Discord link
                    record_telemetry("discord_button_clicked", { scene = "main_menu" })
                    OpenURL("https://discord.gg/rp6yXxKu5z")
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
                :addColor(util.getColor("purple_slate"))  -- Resurrect 64 palette
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
                :addColor(util.getColor("dark_lavender"))  -- Resurrect 64 palette
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
                :addColor(util.getColor("dark_lavender"))  -- Resurrect 64 palette
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
            :addColor(util.getColor("blackberry"))  -- Resurrect 64 palette
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
    ui.box.set_draw_layer(mainMenuEntities.main_menu_uibox, "ui")
    
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
                :addColor(util.getColor("green_jade"))  -- Resurrect 64 palette
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
                :addColor(util.getColor("deep_teal"))  -- Resurrect 64 palette
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
    ui.box.set_draw_layer(mainMenuEntities.language_button_uibox, "ui")
    
    -- put in the bottom right corner
    local languageButtonTransform = component_cache.get(mainMenuEntities.language_button_uibox, Transform)
    languageButtonTransform.actualX = globals.screenWidth() - languageButtonTransform.actualW - 20
    languageButtonTransform.actualY = globals.screenHeight() - languageButtonTransform.actualH - 20

    PatchNotesModal.init()
    createPatchNotesButton()
    createTabDemo()
    createInventoryTestButton()
end

function createInventoryTestButton()
    local dsl = require("ui.ui_syntax_sugar")
    local PlayerInventory = require("ui.player_inventory")
    local timer = require("core.timer")
    
    local buttonDef = dsl.strict.root {
        config = {
            color = util.getColor("green_jade"),
            padding = 8,
            emboss = 3,
        },
        children = {
            dsl.strict.button("Test Inventory", {
                fontSize = 14,
                color = "transparent",
                textColor = "white",
                shadow = true,
                onClick = function()
                    log_debug("[TEST] Inventory button clicked!")
                    if playSoundEffect then playSoundEffect("effects", "button-click") end
                    PlayerInventory.toggle()
                    log_debug("[TEST] PlayerInventory.isOpen() = " .. tostring(PlayerInventory.isOpen()))

                    if PlayerInventory.isOpen() then
                        timer.after_opts({
                            delay = 0.1,
                            action = function()
                                PlayerInventory.spawnDummyCards()
                                log_debug("[TEST] Dummy cards spawned")
                            end,
                            tag = "spawn_dummy_cards"
                        })
                    end
                end
            })
        }
    }
    
    mainMenuEntities.inventory_test_button = dsl.spawn(
        { x = 120, y = globals.screenHeight() - 60 },
        buttonDef,
        "ui",
        100
    )
    ui.box.set_draw_layer(mainMenuEntities.inventory_test_button, "ui")
    log_debug("[TRACE] Inventory test button created")

    if os.getenv and os.getenv("AUTO_TEST_INVENTORY") == "1" then
        timer.after_opts({
            delay = 0.1,
            action = function()
                PlayerInventory.toggle()
                if PlayerInventory.isOpen() then
                    PlayerInventory.spawnDummyCards()
                end
            end,
            tag = "auto_open_test_inventory"
        })
    end
end

function createTabDemo()
    print("[TRACE] createTabDemo called")
    local dsl = require("ui.ui_syntax_sugar")
    local panelWidth = 420  -- Increased to fit 6 tabs (Game, Graphics, Audio, Sprites, Inventory, Gallery)
    local gallerySafeMargins = {
        left = 24,
        right = panelWidth + 40,
        top = 24,
        bottom = 48,
    }
    
    local tabDef = dsl.strict.root {
        config = {
            color = util.getColor("blackberry"),
            padding = 4,
            emboss = 3,
        },
        children = {
            dsl.strict.tabs {
                id = "demo_tabs",
                activeTab = "game",
                contentMinWidth = 400,  -- Increased to fit 6 tabs
                contentMinHeight = 120,
                tabs = {
                    {
                        id = "game",
                        label = "Game",
                        content = function()
                            return dsl.strict.vbox {
                                config = { padding = 4 },
                                children = {
                                    dsl.strict.text("Game Settings", { fontSize = 16, color = "white", shadow = true }),
                                    dsl.strict.spacer(8),
                                    dsl.strict.text("Speed: Normal", { fontSize = 12, color = "gray_light" }),
                                    dsl.strict.text("Difficulty: Medium", { fontSize = 12, color = "gray_light" }),
                                }
                            }
                        end
                    },
                    {
                        id = "graphics",
                        label = "Graphics",
                        content = function()
                            return dsl.strict.vbox {
                                config = { padding = 4 },
                                children = {
                                    dsl.strict.text("Graphics Settings", { fontSize = 16, color = "white", shadow = true }),
                                    dsl.strict.spacer(8),
                                    dsl.strict.text("Fullscreen: Off", { fontSize = 12, color = "gray_light" }),
                                    dsl.strict.text("VSync: On", { fontSize = 12, color = "gray_light" }),
                                }
                            }
                        end
                    },
                    {
                        id = "audio",
                        label = "Audio",
                        content = function()
                            return dsl.strict.vbox {
                                config = { padding = 4 },
                                children = {
                                    dsl.strict.text("Audio Settings", { fontSize = 16, color = "white", shadow = true }),
                                    dsl.strict.spacer(8),
                                    dsl.strict.text("Master: 100%", { fontSize = 12, color = "gray_light" }),
                                    dsl.strict.text("Music: 80%", { fontSize = 12, color = "gray_light" }),
                                    dsl.strict.text("SFX: 100%", { fontSize = 12, color = "gray_light" }),
                                }
                            }
                        end
                    },
                    {
                        id = "sprites",
                        label = "Sprites",
                        content = function()
                            local SpriteShowcase = require("ui.sprite_ui_showcase")
                            return SpriteShowcase.createShowcase()
                        end
                    },
                    {
                        id = "inventory",
                        label = "Inventory",
                        content = function()
                            local PlayerInventory = require("ui.player_inventory")
                            return dsl.strict.vbox {
                                config = { padding = 8 },
                                children = {
                                    dsl.strict.text("Player Inventory Test", { fontSize = 16, color = "white", shadow = true }),
                                    dsl.strict.spacer(8),
                                    dsl.strict.text("Status: " .. (PlayerInventory.isOpen() and "OPEN" or "CLOSED"), { fontSize = 12, color = "gray_light" }),
                                    dsl.strict.spacer(12),
                                    dsl.strict.button("Open Inventory", {
                                        fontSize = 14,
                                        color = "green_jade",
                                        textColor = "white",
                                        minWidth = 140,
                                        onClick = function()
                                            if playSoundEffect then playSoundEffect("effects", "button-click") end
                                            PlayerInventory.open()
                                            print("[TEST] PlayerInventory.open() called")
                                        end
                                    }),
                                    dsl.strict.spacer(4),
                                    dsl.strict.button("Close Inventory", {
                                        fontSize = 14,
                                        color = "indian_red",
                                        textColor = "white",
                                        minWidth = 140,
                                        onClick = function()
                                            if playSoundEffect then playSoundEffect("effects", "button-click") end
                                            PlayerInventory.close()
                                            print("[TEST] PlayerInventory.close() called")
                                        end
                                    }),
                                    dsl.strict.spacer(4),
                                    dsl.strict.button("Toggle Inventory", {
                                        fontSize = 14,
                                        color = "blue_steel",
                                        textColor = "white",
                                        minWidth = 140,
                                        onClick = function()
                                            if playSoundEffect then playSoundEffect("effects", "button-click") end
                                            PlayerInventory.toggle()
                                            print("[TEST] PlayerInventory.toggle() called - now " .. (PlayerInventory.isOpen() and "OPEN" or "CLOSED"))
                                        end
                                    }),
                                }
                            }
                        end
                    },
                    {
                        id = "gallery",
                        label = "Gallery",
                        content = function()
                            local GalleryViewer = require("ui.showcase.gallery_viewer")
                            return dsl.strict.vbox {
                                config = { padding = 8 },
                                children = {
                                    dsl.strict.text("UI Showcase Gallery", { fontSize = 16, color = "white", shadow = true }),
                                    dsl.strict.spacer(8),
                                    dsl.strict.text("Browse UI component examples", { fontSize = 12, color = "gray_light" }),
                                    dsl.strict.text("with live previews and code.", { fontSize = 12, color = "gray_light" }),
                                    dsl.strict.spacer(12),
                                    dsl.strict.button("Open Gallery", {
                                        fontSize = 14,
                                        color = "green_jade",
                                        textColor = "white",
                                        minWidth = 140,
                                        onClick = function()
                                            if playSoundEffect then playSoundEffect("effects", "button-click") end
                                            -- Let the gallery auto-fit to safe screen bounds
                                            GalleryViewer.showGlobalWithOptions(nil, nil, { safeMargins = gallerySafeMargins })
                                            print("[GALLERY] Showcase gallery opened")
                                        end
                                    }),
                                    dsl.strict.spacer(4),
                                    dsl.strict.button("Close Gallery", {
                                        fontSize = 14,
                                        color = "indian_red",
                                        textColor = "white",
                                        minWidth = 140,
                                        onClick = function()
                                            if playSoundEffect then playSoundEffect("effects", "button-click") end
                                            GalleryViewer.hideGlobal()
                                            print("[GALLERY] Showcase gallery closed")
                                        end
                                    }),
                                }
                            }
                        end
                    },
                }
            }
        }
    }
    
    mainMenuEntities.tab_demo_uibox = dsl.spawn({ x = globals.screenWidth() - panelWidth - 20, y = 20 }, tabDef)
    ui.box.set_draw_layer(mainMenuEntities.tab_demo_uibox, "ui")

    -- Auto-open gallery for testing (one-shot, guarded by module-level flag)
    if os.getenv and os.getenv("AUTO_TEST_GALLERY") == "1" and not _G._galleryTestScheduled then
        _G._galleryTestScheduled = true
        print("[GALLERY_TEST] Scheduling gallery auto-open in 0.5s")
        local timer = require("core.timer")
        timer.after(0.5, function()
            print("[GALLERY_TEST] Timer fired!")
            if _G._galleryTestOpened then
                print("[GALLERY_TEST] Gallery already opened, skipping")
                return
            end
            _G._galleryTestOpened = true
            local ok, err = pcall(function()
                local GalleryViewer = require("ui.showcase.gallery_viewer")
                print("[GALLERY_TEST] Opening gallery (auto-fit)")
                GalleryViewer.showGlobalWithOptions(nil, nil, { safeMargins = gallerySafeMargins })
                print("[GALLERY_TEST] Gallery opened successfully")
            end)
            if not ok then
                print("[GALLERY_TEST] ERROR:", err)
            end
        end)
    end
end

function createPatchNotesButton()
    local dsl = require("ui.ui_syntax_sugar")
    
    local hasUnread = PatchNotesModal.hasUnread()
    
    -- Use dsl.strict.button which properly handles click via buttonCallback
    local buttonDef = dsl.strict.root {
        config = {
            color = util.getColor("gray"),
            padding = 8,
            emboss = 2,
        },
        children = {
            dsl.strict.button("Notes", {
                fontSize = 14,
                color = "transparent", -- Use transparent so root color shows through
                textColor = "white",
                shadow = true,
                onClick = function()
                    if playSoundEffect then
                        playSoundEffect("effects", "button-click")
                    end
                    PatchNotesModal.open()
                end
            })
        }
    }

    mainMenuEntities.patch_notes_button = dsl.spawn(
        { x = 20, y = globals.screenHeight() - 60 },
        buttonDef,
        "ui",
        100
    )
    ui.box.set_draw_layer(mainMenuEntities.patch_notes_button, "ui")
    
    mainMenuEntities._patchNotesHasUnread = hasUnread
end

function drawPatchNotesBadge()
    if not mainMenuEntities.patch_notes_button then return end
    if not mainMenuEntities._patchNotesHasUnread then return end
    if not PatchNotesModal.hasUnread() then 
        mainMenuEntities._patchNotesHasUnread = false
        return 
    end
    
    -- Get position from UIBoxComponent's uiRoot (UIBox entities store transform there)
    local boxComp = component_cache.get(mainMenuEntities.patch_notes_button, UIBoxComponent)
    if not boxComp or not boxComp.uiRoot then return end
    
    local t = component_cache.get(boxComp.uiRoot, Transform)
    if not t then return end
    
    local badgeX = t.actualX + t.actualW - 4
    local badgeY = t.actualY + 4
    local badgeRadius = 6
    local space = layer.DrawCommandSpace.Screen
    
    command_buffer.queueDrawCenteredEllipse(layers.ui, function(c)
        c.x = badgeX
        c.y = badgeY
        c.rx = badgeRadius
        c.ry = badgeRadius
        c.color = util.getColor("red")
    end, 150, space)
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
            add_fullscreen_shader("palette_quantize") -- Apply palette quantize globally
        end,
        "main_menu_to_game_state_change" -- unique tag for this timer
    )
    
end
function clearMainMenu()

    -- RenderGroupsTest.cleanup()
    InventoryGridDemo.cleanup()

    if mainMenuEntities.special_item_1 then mainMenuEntities.special_item_1:destroy(); mainMenuEntities.special_item_1 = nil end
    if mainMenuEntities.special_item_2 then mainMenuEntities.special_item_2:destroy(); mainMenuEntities.special_item_2 = nil end
    if mainMenuEntities.special_item_3 then mainMenuEntities.special_item_3:destroy(); mainMenuEntities.special_item_3 = nil end

    for _, entity in pairs(mainMenuEntities) do
        if type(entity) == "number" and registry:valid(entity) and registry:has(entity, Transform) then
            local transform = component_cache.get(entity, Transform)
            if transform then
                transform.actualY = globals.screenHeight() + 500
            end
        end
    end
    
    -- move global.ui.logo out of view
    if globals.ui.logo and entity_cache.valid(globals.ui.logo) then
        local logoTransform = component_cache.get(globals.ui.logo, Transform)
        if logoTransform then
            logoTransform.actualY = globals.screenHeight() + 500 -- push it down out of view
        end
    end
    
    
    -- delete tiemrs
    timer.kill_group(MAIN_MENU_TIMER_GROUP)
    timer.cancel("logo_text_update") -- cancel the logo text update timer
    timer.cancel("logo_text_pulse") -- cancel the logo text pulse timer
    timer.cancel(MAIN_MENU_PHASE_TIMER_TAG) -- cancel the shape phase timer
    remove_layer_shader("sprites", "pixelate_image")

    if mainMenuEntities.main_menu_uibox and ui.box and ui.box.Remove then
        ui.box.Remove(registry, mainMenuEntities.main_menu_uibox)
        mainMenuEntities.main_menu_uibox = nil
    end
    if mainMenuEntities.language_button_uibox and ui.box and ui.box.Remove then
        ui.box.Remove(registry, mainMenuEntities.language_button_uibox)
        mainMenuEntities.language_button_uibox = nil
    end
    if mainMenuEntities.patch_notes_button and ui.box and ui.box.Remove then
        ui.box.Remove(registry, mainMenuEntities.patch_notes_button)
        mainMenuEntities.patch_notes_button = nil
    end
    PatchNotesModal.destroy()
    -- Clean up gallery viewer if open
    local GalleryViewer = require("ui.showcase.gallery_viewer")
    GalleryViewer.destroyGlobal()
    if mainMenuEntities.tab_demo_uibox and ui.box and ui.box.Remove then
        ui.box.Remove(registry, mainMenuEntities.tab_demo_uibox)
        local dsl = require("ui.ui_syntax_sugar")
        dsl.cleanupTabs("demo_tabs")
        mainMenuEntities.tab_demo_uibox = nil
    end
    if entity_cache and entity_cache.valid and entity_cache.valid(globals.ui.logo) then
        registry:destroy(globals.ui.logo)
        globals.ui.logo = nil
    end
end

boards = {}



function initMainGame()
    
    print("Runtime:", jit and jit.version or _VERSION)

    
    setTrackVolume("main-menu", 0.0)
    
    playPlaylist({
        "lo_fi_wash_over_main",
        "lo_fi_wash_over_intensity_1",
        "lo_fi_wash_over_intensity_2",
        
    }, true) -- loop.

    
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

    -- LightingDemo.start()

end

function changeGameState(newState)
    -- Check if the new state is different from the current state
    if currentGameState == GAMESTATE.MAIN_MENU and newState ~= GAMESTATE.MAIN_MENU then
        clearMainMenu()
    end

    if newState == GAMESTATE.MAIN_MENU then
        initMainMenu()
    elseif newState == GAMESTATE.IN_GAME then
        initMainGame()
    else
        error("Invalid game state: " .. tostring(newState))
    end
    currentGameState = newState
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

    -- Initialize save system early
    SaveManager.init()

    -- Load modules that register collectors
    Statistics = require("core.statistics") -- Global for C++ debug UI access

    -- Register grid inventory save collector (registers itself with SaveManager on require)
    local GridInventorySave = require("core.grid_inventory_save")

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

    -- Run DX Audit smoke test to verify new Lua APIs work correctly
    -- Set RUN_DX_AUDIT_TEST=1 to enable, or always run in debug builds
    -- local runDxAuditTest = os.getenv("RUN_DX_AUDIT_TEST") == "1"
    local runDxAuditTest = true
    if runDxAuditTest then
        local ok, test_module = pcall(require, "tests.test_dx_audit_changes")
        if ok and test_module and test_module.run then
            log_debug("[DX Audit] Running smoke test...")
            local results = test_module.run()
            if results.failed > 0 then
                log_warn(string.format("[DX Audit] %d test(s) FAILED - check console output", results.failed))
            else
                log_debug(string.format("[DX Audit] All %d tests passed!", results.passed))
            end
        else
            log_warn("[DX Audit] Could not load test module: " .. tostring(test_module))
        end
    end

    -- Run UIValidator tests (set RUN_UI_VALIDATOR_TESTS=1 to enable)
    local runUIValidatorTests = os.getenv("RUN_UI_VALIDATOR_TESTS") == "1"
    if runUIValidatorTests then
        local ok, test_module = pcall(require, "tests.run_ui_validator_tests")
        if ok and test_module and test_module.run then
            log_debug("[UIValidator] Running tests...")
            local success = test_module.run()
            if success then
                log_debug("[UIValidator] All tests passed!")
            else
                log_warn("[UIValidator] Some tests FAILED - check console output")
            end
        else
            log_warn("[UIValidator] Could not load test module: " .. tostring(test_module))
        end
    end

    -- Run real PlayerInventory validation (set RUN_REAL_INVENTORY_TEST=1 to enable)
    local runRealInventoryTest = os.getenv("RUN_REAL_INVENTORY_TEST") == "1"
    if runRealInventoryTest then
        local ok, test_module = pcall(require, "tests.test_real_player_inventory")
        if ok and test_module and test_module.run then
            log_debug("[RealInventoryTest] Running real PlayerInventory validation...")
            test_module.run()
        else
            log_warn("[RealInventoryTest] Could not load test module: " .. tostring(test_module))
        end
    end

    -- Legacy tooltip hide timer - no longer needed with DSL tooltips
    -- Tooltips now hide via onStopHover handlers in the DSL system
    -- This timer was used for mouse-following tooltips which are being phased out
    -- timer.every(0.2, function()
    --     -- tracy.zoneBeginN("Tooltip Hide Timer Tick") -- just some default depth to avoid bugs
    --     if entity_cache.valid(globals.inputState.cursor_hovering_target) == false or globals.inputState.cursor_hovering_target == globals.gameWorldContainerEntity()  then
    --         hideTooltip() -- Hide the tooltip if the cursor is not hovering over any target
    --     end
    --     -- tracy.zoneEnd()
    -- end,
    -- 0, -- start immediately)
    -- true,
    -- nil, -- no "after" callback
    -- "tooltip_hide_timer" -- unique tag for this timer
    -- )
    
    changeGameState(GAMESTATE.MAIN_MENU) -- Initialize the game in the IN_GAME state

    if autoStartMainGameEnv then
        timer.after(0.25, function()
            print("[DEBUG ACTION] AUTO_START_MAIN_GAME triggering startGameButtonCallback()")
            if startGameButtonCallback then
                startGameButtonCallback()
            else
                print("[DEBUG ACTION] AUTO_START_MAIN_GAME fallback state switch")
                changeGameState(GAMESTATE.IN_GAME)
            end
        end, "auto_start_main_game")
    end
    
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
    
    local isPaused = (globals.gamePaused or currentGameState == GAMESTATE.MAIN_MENU)

    if not isPaused then
        -- Node system (lua side)
        Node.update_all(dt) -- Update all nodes with update() functions
    end

    -- TextBuilder system - MUST be called every frame to queue text draw commands
    -- Runs even when paused so UI text still renders
    Text.update(dt)

    if (currentGameState == GAMESTATE.MAIN_MENU) then
        globals.main_menu_elapsed_time = globals.main_menu_elapsed_time + dt
        SpecialItem.update(dt)
        SpecialItem.draw()
        PatchNotesModal.update(dt)
        PatchNotesModal.draw()
        drawPatchNotesBadge()
    end

    if isPaused then
        component_cache.end_frame()
        return -- If the game is paused, do not update gameplay objects
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
