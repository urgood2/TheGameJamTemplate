require("core.globals")
require("registry")
require("ai.init") -- Read in ai scripts and populate the ai table
require("util.util")
require("ui.ui_defs")
require("core.entity_factory")
local z_orders = require("core.z_orders")
local Node = require("monobehavior.behavior_script_v2") -- the new monobehavior script
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

local shapeAnimationPhase = 0

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
    
    -- create a timer to increment the phase
    timer.run(
        function()
            shapeAnimationPhase = shapeAnimationPhase + 1
        end
    )
    
    
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
                :addColor(palette.snapToColorName("gray"))
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
                :addColor(palette.snapToColorName("gray"))
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
                :addColor(palette.snapToColorName("gray"))
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
                :addColor(palette.snapToColorName("gray"))
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
                :addColor(palette.snapToColorName("gray"))
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
            :addColor(palette.snapToColorName("yellow"))
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
                :addColor(palette.snapToColorName("gray"))
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
                :addColor(palette.snapToColorName("green"))
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

local boards = {}

function createNewCard(boardEntityID, isStackable)
    
    -- let's create a couple of cards.
    local card1 = animation_system.createAnimatedObjectWithTransform(
        "card_back_1.png", -- animation ID
        true             -- use animation, not sprite identifier, if false
    )
    
    -- give a script table
    local cardScript = Node{}    
    
    
    cardScript.isStackable = isStackable or true -- whether this card can be stacked on other cards, default true
    
    -- give an update table to align the card's stacks if they exist.
    cardScript.update = function(self, dt)
        local eid = self:handle()
        
        -- return unless self's root is self.
        if self.stackRootEntity and self.stackRootEntity ~= eid then
            return
        end
        
        -- if there is a stack, align the stack
        if self.cardStack and #self.cardStack > 0 then
            local baseTransform = registry:get(eid, Transform)
            
            local stackOffsetY = baseTransform.actualH * 0.2 -- offset each card
            
            for i, stackedCardEid in ipairs(self.cardStack) do
                if stackedCardEid and registry:valid(stackedCardEid) then
                    local stackedTransform = registry:get(stackedCardEid, Transform)
                    stackedTransform.actualX = baseTransform.actualX
                    stackedTransform.actualY = baseTransform.actualY + (i * stackOffsetY)
                end
            end
        end
        
    end
    
    -- attach ecs must be called after defining the callbacks.
    cardScript:attach_ecs{ create_new = false, existing_entity = card1 }
    
    
    
    -- make draggable and set some callbacks in the transform system
    local nodeComp = registry:get(card1, GameObject)
    local gameObjectState = nodeComp.state
    gameObjectState.hoverEnabled = true
    gameObjectState.triggerOnReleaseEnabled = true
    gameObjectState.collisionEnabled = true
    gameObjectState.dragEnabled = true -- allow dragging the colonist
    nodeComp.methods.onHover = function()
    end
    
    nodeComp.methods.onStopHover = function()
    end
    
    animation_system.resizeAnimationObjectsInEntityToFit(
        card1,
        48 * 2,   -- width
        64 * 2    -- height
    )
    
    
    nodeComp.methods.onRelease = function(registry, releasedOn, released)
        log_debug("card", released, "released on", releasedOn)
        
        -- when released on top of a card, get the root card of the stack if there is one, and add self to that stack 
        
        
        -- get the card script table
        local releasedCardScript = getScriptTableFromEntityID(released)
        if not releasedCardScript then return end
        
        -- check stackRootEntity in the table. Also, check that isStackable is true
        if not releasedCardScript.isStackable then
            log_debug("released card is not stackable or has no stackRootEntity")
            return
        end
        
        -- repeated climb tree to find the root entity from the releasedOn
        while true do
            if not releasedOn or releasedOn == entt_null or not registry:valid(releasedOn) then
                break
            end
            local releasedOnScript = getScriptTableFromEntityID(releasedOn)
            if not releasedOnScript then
                break
            end
            if not releasedOnScript.isStackable or not releasedOnScript.stackRootEntity then
                break
            end
            -- climb up the tree
            releasedOn = releasedOnScript.stackRootEntity
            break -- we just need to find it once
        end
        
        -- is the root entity a valid entity?
        local rootEntity = releasedOn or releasedCardScript.stackRootEntity
        if not rootEntity or rootEntity == entt_null or not registry:valid(rootEntity) then
            log_debug("released card has no valid stackRootEntity, setting to self")
            releasedCardScript.stackRootEntity = released
            rootEntity = released
        end
        
        -- now get the root entity's script
        local rootCardScript = getScriptTableFromEntityID(rootEntity)
        if not rootCardScript then
            log_debug("released card's stackRootEntity has no valid script table, bail")
            return
        end
        
        -- add self to the root entity's stack, if self is not the root
        if rootEntity == released then
            log_debug("released card is the root entity, not stacking on self")
            return
        end
        -- make sure neither card is already in a stack and they're being dropped onto each other by accident. It's weird, but sometimes root can be dropped on a member card.
        if rootCardScript.cardStack then
            for _, e in ipairs(rootCardScript.cardStack) do
                if e == released then
                    log_debug("released card is already in the root entity's stack, not stacking again")
                    return
                end
            end
        elseif releasedCardScript.cardStack then
            for _, e in ipairs(releasedCardScript.cardStack) do
                if e == rootEntity then
                    log_debug("root entity is already in the released card's stack, not stacking again")
                    return
                end
            end
        end
        rootCardScript.cardStack = rootCardScript.cardStack or {}
        table.insert(rootCardScript.cardStack, released)
        
        -- also store a reference to the root entity in self
        cardScript.stackRootEntity = rootEntity
        
    end
    
    nodeComp.methods.onDrag = function()
        
        if not boardEntityID then return end
        
        local board = boards[boardEntityID]
        -- dunno why, board can be nil
        if not board then return end
        -- set z order to top so it can be seen
        cardScript.isDragging = true
        
        log_debug("dragging card, bringing to top z:", board.z_orders.top)
        layer_order_system.assignZIndexToEntity(card1, board.z_orders.top)
    end
    
    nodeComp.methods.onStopDrag = function()
        
        if not boardEntityID then return end
        
        local board = boards[boardEntityID]
        -- dunno why, board can be nil
        if not board then return end
        -- reset z order to cached value
        cardScript.isDragging = false
        local cachedZ = board.z_order_cache_per_card and board.z_order_cache_per_card[card1] or board.z_orders.card
        layer_order_system.assignZIndexToEntity(card1, cachedZ)
    end
    
    
    
    return card1
    
end

-- return the object lua table from an entt id
function getScriptTableFromEntityID(eid)
    if not eid or eid == entt_null or not registry:valid(eid) then return nil end
    if not registry:has(eid, ScriptComponent) then return nil end
    local scriptComp = registry:get(eid, ScriptComponent)
    return scriptComp.self
end

-- save game state strings
local planningGameState = "PLANNING"
local actionGameState = "SURVIVORS"

function initMainGame()
    setTrackVolume("main-menu", 0.0)
    
    log_debug("Initializing main game...") -- Debug message to indicate the game is starting
    currentGameState = GAMESTATE.IN_GAME -- Set the game state to IN_GAME
    
    
    
    
    -- let's create a card board
    
    -- first create a generic scriptable entity.
    local board = Node{}
    
    board.z_orders = { bottom = z_orders.card, top = z_orders.card + 1000 } -- save specific z orders for the card in the board.
    board.z_order_cache_per_card = {} -- cache for z orders per card entity id.
    
    
    
    -- replace update function
    board.update = function(self, dt)
        local eid = self:handle()
        if not eid or not registry:valid(eid) then return end

        local area = registry:get(eid, Transform)

        -- -- draw board border
        local pad = 20
        command_buffer.queueDrawDashedRoundedRect(layers.sprites, function(c)
            c.rec = Rectangle.new(
                area.actualX,
                area.actualY,
                math.max(0, area.actualW),
                math.max(0, area.actualH)
            )
            c.radius    = 10
            c.dashLen   = 12
            c.gapLen    = 8
            c.phase     = (shapeAnimationPhase)
            c.arcSteps  = 14
            c.thickness = 5
            c.color     = palette.snapToColorName("yellow")
        end, z_orders.board, layer.DrawCommandSpace.World)

        local cards = self.cards or {}
        local n = #cards
        if n == 0 then return end

        -- probe card size
        local cardW, cardH = 100, 140
        for _, cardEid in ipairs(cards) do
            if cardEid and registry:valid(cardEid) and cardEid ~= entt_null then
                local ct = registry:get(cardEid, Transform)
                if ct and ct.actualW and ct.actualH and ct.actualW > 0 and ct.actualH > 0 then
                    cardW, cardH = ct.actualW, ct.actualH
                    break
                end
            end
        end

        -- layout
        local padding = 20
        local availW = math.max(0, area.actualW - padding * 2)
        local minGap = 12

        local spacing, groupW
        if n == 1 then
            spacing = 0
            groupW  = cardW
        else
            local fitSpacing = (availW - cardW) / (n - 1)
            spacing = math.max(minGap, fitSpacing)
            groupW  = cardW + spacing * (n - 1)
            if groupW > availW then
                spacing = math.max(0, fitSpacing)
                groupW  = cardW + spacing * (n - 1)
            end
        end

        local startX  = area.actualX + padding + (availW - groupW) * 0.5
        local centerY = area.actualY + area.actualH * 0.5

        -- z-order cache (per card)
        self.z_order_cache_per_card = self.z_order_cache_per_card or {}
        local baseZ = z_orders.card
        
        -- sort the cards by actualX
        table.sort(cards, function(a, b)
            if not (a and registry:valid(a) and a ~= entt_null) then return false end
            if not (b and registry:valid(b) and b ~= entt_null) then return true  end

            local at = registry:get(a, Transform)
            local bt = registry:get(b, Transform)
            if not (at and bt) then return false end

            local aCenterX = at.actualX + at.actualW * 0.5
            local bCenterX = bt.actualX + bt.actualW * 0.5

            if aCenterX == bCenterX then
                return a < b   -- compare raw entity ids
            end
            return aCenterX < bCenterX
        end)


        for i, cardEid in ipairs(cards) do
            if cardEid and registry:valid(cardEid) and cardEid ~= entt_null then
                local ct = registry:get(cardEid, Transform)
                if ct then
                    ct.actualX = math.floor(startX + (i - 1) * spacing + 0.5)
                    ct.actualY = math.floor(centerY - ct.actualH * 0.5 + 0.5)
                end
                
                -- don't overwrite zIndex if the card is being dragged
                local zi = baseZ + (i - 1)
                self.z_order_cache_per_card[cardEid] = zi
                
                -- assign zIndex via LayerOrder system
                layer_order_system.assignZIndexToEntity(cardEid, zi)
                
                local cardGameObject = registry:get(cardEid, GameObject)
                if cardGameObject and cardGameObject.state and cardGameObject.state.isBeingDragged then
                    --overwrite
                    layer_order_system.assignZIndexToEntity(cardEid, self.z_orders.top)
                end
                
        
            end
        end
    end


    
    -- attach ecs and load update function
    board:attach_ecs{ create_new = true }
    
    
    local card1 = createNewCard(board:handle())
    local card2 = createNewCard(board:handle())
    
    -- add a couple of test cards outside the card area.
    
    local outsideCard1 = createNewCard()
    local outsideCard2 = createNewCard()
    
    local testTable = getScriptTableFromEntityID(card1)
    
    board.cards = { card1, card2 } -- give a couple of starting cards. These are the entity ids.
    
    -- store in boards table
    boards[board:handle()] = board
    
    -- give a transform comp (automatically in world space)
    transform.CreateOrEmplace(registry, globals.gameWorldContainerEntity(), 0, 0, 600, 200, board:handle())
    
    
    -- timer to test adding new cards
    timer.every(5.0, function()
        local newCard = createNewCard()
        table.insert(board.cards, newCard)
    end)
    
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
                palette.snapToColorName("blue"), -- start color
                palette.snapToColorName("purple"), -- end color
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
