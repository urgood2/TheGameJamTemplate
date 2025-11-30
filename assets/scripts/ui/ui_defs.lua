-- local bit = require("bit") -- LuaJIT's bit library

-- build defs here
local timer = require("core.timer")

ui_defs = {
    
}

function ui_defs.placeBuilding(buildingName)
    
end

function createStructurePlacementButton(spriteID, globalAnimationHandle, globalTextHandle, textLocalizationKey, costValue, globalCostTextHandle)
    globals.ui[globalAnimationHandle] = animation_system.createAnimatedObjectWithTransform(
        spriteID, -- animation ID
        true             -- true if sprite id
    )
    
    animation_system.resizeAnimationObjectsInEntityToFit(
        globals.ui[globalAnimationHandle], -- entity to resize
        40, -- width
        40  -- height
    )
    
    local uiIconHomeDef = ui.definitions.wrapEntityInsideObjectElement(globals.ui[globalAnimationHandle])
        
    -- colonist home text, for colonist home buy button
    local itemTextDef = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get(textLocalizationKey) end,  -- initial text
        20.0,                                 -- font size
        ""                       -- animation spec
    )
    
    
    globals.ui[globalTextHandle] = itemTextDef.config.object -- store the text entity in globals
    
    
    local costRow = nil
    if costValue then
        -- cost string
        local costText = ui.definitions.getNewDynamicTextEntry(
            function() return localization.get("ui.cost_text", {cost = costValue}) end,  -- initial text
            20.0,                                 -- font size
            ""                       -- animation spec
        )
        if globalCostTextHandle then
            globals.ui[globalCostTextHandle] = costText.config.object -- store the cost text entity in globals
        end
        
        -- animation entity for the cost icon
        local costIconEntity = animation_system.createAnimatedObjectWithTransform(
            "4024-TheRoguelike_1_10_alpha_817.png", -- animation ID for currency icon
            true             -- true if sprite id
        )
        
        
        local costIconDef = ui.definitions.wrapEntityInsideObjectElement(costIconEntity)
    
        -- resize the cost icon to fit
        animation_system.resizeAnimationObjectsInEntityToFit(
            costIconEntity, -- entity to resize
            20, -- width
            20  -- height
        )
        costRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("blank"))
                -- :addShadow(true) --- IGNORE ---
                -- :addEmboss(4.0)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(costIconDef)
        :addChild(costText)
        :build()

    end
    -- make a horizontal container for the cost icon and text
    
    
    -- vertical container for home text + cost 
    local colonistHomeTextDef = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.VERTICAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("blank"))
                -- :addShadow(true) --- IGNORE ---
                -- :addEmboss(4.0)
                :addPadding(0)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(itemTextDef)
        :build()
        
    if costRow then
        colonistHomeTextDef.children:add(costRow) -- add the cost row if it exists
    end
    
    local colonistHomeTextDef = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("taupe_warm"))
                -- :addShadow(true) --- IGNORE ---
                :addEmboss(4.0)
                :addHover(true) -- needed for button effect
                :addButtonCallback(function()
                    -- button click callback
                    log_debug(globalTextHandle .. " button clicked!")
                    playSoundEffect("effects", "button-click") -- play button click sound
                end)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(uiIconHomeDef)
        :addChild(colonistHomeTextDef)
        :build()
        
    return colonistHomeTextDef
end

-- Builds the shop/relic UI without relying on generateUI.
local function buildShopUI()
    if globals.ui.weatherShopUIBox then
        return
    end

    local weatherDifficultyText = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.weather_difficulty_text", {difficulty = globals.current_weather_event_base_damage}) end,  -- initial text
        30.0,                                 -- font size
        "pulse"                       -- animation spec
    )
    
    globals.ui.weatherDifficultyTextEntity = weatherDifficultyText
    
    -- update it every 2 seconds
    timer.every(2, function()
        -- update the weather difficulty text every 2 seconds
        local text = localization.get("ui.weather_difficulty_text", {difficulty = globals.current_weather_event_base_damage})
        TextSystem.Functions.setText(globals.ui.weatherDifficultyTextEntity.config.object, text)    
        TextSystem.Functions.applyGlobalEffects(globals.ui.weatherDifficultyTextEntity.config.object, "pulse") -- apply the pulse effect to the text
    end)
    
    -- put in a row
    local weatherDifficultyTextDef = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("blank"))
                -- :addShadow(true) --- IGNORE ---
                -- :addEmboss(4.0) --- IGNORE ---
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(globals.ui.weatherDifficultyTextEntity)
        :build()
    -- create a new UI box for the weather difficulty text
    globals.ui.weatherDifficultyUIBox = ui.box.Initialize({x = globals.screenWidth() - 200, y = 60}, weatherDifficultyTextDef)
    -- align the weather difficulty UI box to the top right of the screen
    local weatherDifficultyTransform = registry:get(globals.ui.weatherDifficultyUIBox, Transform)
    weatherDifficultyTransform.actualX = globals.screenWidth() - weatherDifficultyTransform.actualW - 10 -- 10 pixels from the right edge
    weatherDifficultyTransform.visualX = weatherDifficultyTransform.actualX -- update visual position as well
    weatherDifficultyTransform.actualY = 10 -- 10 pixels from the top edge
    weatherDifficultyTransform.visualY = weatherDifficultyTransform.actualY
    
    
    local relicSlots = {
        {id = "relic1", spriteID = "4165-TheRoguelike_1_10_alpha_958.png", text = "ui.relic_slot_1", animHandle = "relic1ButtonAnimationEntity", textHandle = "relic1TextEntity", cost = 0, costTextHandle = "relic1CostTextEntity", uielementID = "relic1UIElement"},
        {id = "relic2", spriteID = "4169-TheRoguelike_1_10_alpha_962.png", text = "ui.relic_slot_2", animHandle = "relic2ButtonAnimationEntity", textHandle = "relic2TextEntity", cost = 0, costTextHandle = "relic2CostTextEntity", uielementID = "relic2UIElement"},
        {id = "relic3", spriteID = "4054-TheRoguelike_1_10_alpha_847.png", text = "ui.relic_slot_3", animHandle = "relic3ButtonAnimationEntity", textHandle = "relic3TextEntity", cost = 0, costTextHandle = "relic3CostTextEntity", uielementID = "relic3UIElement"},
    }

    local weatherButtonDefs = {}
    
    -- populate weatherButtonDefs based on weatherEvents
    for _, event in ipairs(relicSlots) do

        -- TODO: so these are stored under globals.ui["relic1TextEntity"] globals.ui["relic1ButtonAnimationEntity"] and so on, we will access these later
        local buttonDef = createStructurePlacementButton(
            event.spriteID, -- sprite ID for the weather event
            event.animHandle, -- global animation handle
            event.textHandle, -- global text handle
            event.text, -- localization key for text
            event.cost, -- cost to buy the weather event
            event.costTextHandle -- global cost text handle
        )
        
        buttonDef.config.id = event.uielementID -- set the id for the buttonDef
        -- add buttonDef to weatherButtonDefs
        table.insert(weatherButtonDefs, buttonDef)
    end

    local ShopSystem = require("core.shop_system")
    globals.shopUIState.rerollCost = globals.shopUIState.rerollCost or ShopSystem.config.baseRerollCost
    globals.shopUIState.rerollCount = globals.shopUIState.rerollCount or 0
    globals.shopUIState.locked = globals.shopUIState.locked or false
    globals.shopUIState.awaitingRemoval = false

    local function formatGold(amount)
        return "Gold: " .. tostring(math.floor(amount + 0.5))
    end

    globals.ui.shopLockIcons = {}

    local function buildLockIcon(idSuffix)
        local icon = animation_system.createAnimatedObjectWithTransform(
            "4024-TheRoguelike_1_10_alpha_817.png",
            true
        )
        animation_system.resizeAnimationObjectsInEntityToFit(icon, 22, 22)
        animation_system.setFGColorForAllAnimationObjects(icon, util.getColor("blackberry"))
        local animComp = component_cache.get(icon, AnimationQueueComponent)
        if animComp then
            animComp.noDraw = true
        end
        local iconGO = component_cache.get(icon, GameObject)
        if iconGO and iconGO.state then
            iconGO.state.hoverEnabled = false
            iconGO.state.collisionEnabled = false
        end
        table.insert(globals.ui.shopLockIcons, icon)
        local iconDef = ui.definitions.wrapEntityInsideObjectElement(icon)
        iconDef.config.id = "shop_lock_icon_" .. idSuffix
        return iconDef
    end

    local function setLockIconsVisible(visible)
        for _, icon in ipairs(globals.ui.shopLockIcons) do
            local animComp = component_cache.get(icon, AnimationQueueComponent)
            if animComp then
                animComp.noDraw = not visible
            end
            local t = component_cache.get(icon, Transform)
            if t then
                local size = visible and 22 or 0
                t.actualW = size
                t.visualW = size
                t.actualH = size
                t.visualH = size
            end
        end
        if globals.ui.weatherShopUIBox then
            ui.box.RenewAlignment(registry, globals.ui.weatherShopUIBox)
        end
    end
    globals.ui.setLockIconsVisible = setLockIconsVisible

    local offerSlots = {}
    for i, buttonDef in ipairs(weatherButtonDefs) do
        if i <= 3 then
            local slot = UIElementTemplateNodeBuilder.create()
                :addType(UITypeEnum.VERTICAL_CONTAINER)
                :addConfig(
                    UIConfigBuilder.create()
                        :addColor(util.getColor("blank"))
                        :addPadding(4)
                        :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                        :build()
                )
                :addChild(buildLockIcon(i))
                :addChild(buttonDef)
                :build()
            table.insert(offerSlots, slot)
        end
    end
    
    -- add a close button to the weather shop
    local closeButton = createStructurePlacementButton(
        "4158-TheRoguelike_1_10_alpha_951.png", 
        "shopCloseButton", -- global animation handle
        "shopCloseText", -- global text handle
        "ui.shop_close" -- localization key for text
    )
    closeButton.config.buttonCallback = function ()
        -- close the weather shop
        log_debug("Weather shop closed!")
        playSoundEffect("effects", "button-click") -- play button click sound
        toggleShopWindow() -- toggle the shop window visibility
        togglePausedState(false) -- unpause the game
    end
    
    -- add a text entity that says "Shop"
    globals.ui.weatherShopTextEntity = ui.definitions.getNewDynamicTextEntry(
        function() return "SHOP" end,  -- initial text
        46.0,                                 -- font size
        "float;wiggle;color=marigold"                       -- animation spec
    )

    local shopGoldIcon = animation_system.createAnimatedObjectWithTransform(
        "4024-TheRoguelike_1_10_alpha_817.png",
        true
    )
    animation_system.resizeAnimationObjectsInEntityToFit(
        shopGoldIcon,
        28,
        28
    )
    globals.ui.shopGoldText = ui.definitions.getNewDynamicTextEntry(
        function() return formatGold(globals.currency) end,  -- initial text
        26.0,                                 -- font size
        "pulse;color=apricot_cream"                       -- animation spec
    )

    local goldRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("blank"))
                :addPadding(6)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :build()
        )
        :addChild(ui.definitions.wrapEntityInsideObjectElement(shopGoldIcon))
        :addChild(globals.ui.shopGoldText)
        :build()

    local offersLabel = ui.definitions.getNewDynamicTextEntry(
        function() return "Card Offers" end,
        22.0,
        "color=apricot_cream"
    )

    local offersRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("blank"))
                :addPadding(8)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :build()
        )
        :addChildren(offerSlots)
        :build()

    local offersPanel = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.ROOT)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("taupe_warm"))
                :addEmboss(6.0)
                :addPadding(12)
                :addMinWidth(560)
                :addMinHeight(200)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :build()
        )
        :addChild(offersLabel)
        :addChild(offersRow)
        :build()

    local function buildShopButton(textEntry, callback, id)
        return UIElementTemplateNodeBuilder.create()
            :addType(UITypeEnum.HORIZONTAL_CONTAINER)
            :addConfig(
                UIConfigBuilder.create()
                    :addId(id or "")
                    :addColor(util.getColor("dusty_rose"))
                    :addEmboss(4.0)
                    :addHover(true)
                    :addPadding(6)
                    :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                    :addButtonCallback(callback)
                    :build()
            )
            :addChild(textEntry)
            :build()
    end

    globals.ui.shopRemoveButtonText = ui.definitions.getNewDynamicTextEntry(
        function() return "Remove card" end,
        20.0,
        "bump"
    )
    globals.ui.shopLockButtonText = ui.definitions.getNewDynamicTextEntry(
        function()
            if globals.shopUIState.locked then
                return "Unlock offers"
            end
            return "Lock offers"
        end,
        20.0,
        "pulse"
    )
    globals.ui.shopRerollButtonText = ui.definitions.getNewDynamicTextEntry(
        function() return string.format("Reroll (%dg)", math.floor(globals.shopUIState.rerollCost + 0.5)) end,
        20.0,
        "bump"
    )

    local function refreshRerollText()
        if globals.ui.shopRerollButtonText and globals.ui.shopRerollButtonText.config then
            TextSystem.Functions.setText(
                globals.ui.shopRerollButtonText.config.object,
                string.format("Reroll (%dg)", math.floor(globals.shopUIState.rerollCost + 0.5))
            )
        end
    end

    local function refreshLockText()
        if globals.ui.shopLockButtonText and globals.ui.shopLockButtonText.config then
            local nextLabel = globals.shopUIState.locked and "Unlock offers" or "Lock offers"
            TextSystem.Functions.setText(globals.ui.shopLockButtonText.config.object, nextLabel)
        end
    end

    local function refreshGoldText()
        if globals.ui.shopGoldText and globals.ui.shopGoldText.config then
            TextSystem.Functions.setText(globals.ui.shopGoldText.config.object, formatGold(globals.currency))
        end
    end

    local removeButton = buildShopButton(globals.ui.shopRemoveButtonText, function()
        globals.shopUIState.awaitingRemoval = true
        playSoundEffect("effects", "button-click")
        newTextPopup(
            string.format("Choose a card to remove (-%dg)", ShopSystem.config.removalCost),
            globals.screenWidth() / 2,
            globals.screenHeight() / 2 - 80,
            1.8,
            "color=fiery_red"
        )
    end, "shop_remove_button")

    local lockButton = buildShopButton(globals.ui.shopLockButtonText, function()
        local nextLocked = not globals.shopUIState.locked
        if setShopLocked then
            setShopLocked(nextLocked)
        else
            globals.shopUIState.locked = nextLocked
        end
        playSoundEffect("effects", "button-click")
        setLockIconsVisible(globals.shopUIState.locked)
        refreshLockText()
        newTextPopup(
            globals.shopUIState.locked and "Shop locked" or "Shop unlocked",
            globals.screenWidth() / 2,
            globals.screenHeight() / 2 - 100,
            1.4,
            "color=plum"
        )
    end, "shop_lock_button")

    local rerollButton = buildShopButton(globals.ui.shopRerollButtonText, function()
        local spend = math.floor(globals.shopUIState.rerollCost + 0.5)
        local success = rerollActiveShop and rerollActiveShop()
        if not success then
            playSoundEffect("effects", "cannot-buy")
            local message = "Need more gold to reroll"
            if not (getActiveShop and getActiveShop()) then
                message = "Shop not available"
            end
            newTextPopup(
                message,
                globals.screenWidth() / 2,
                globals.screenHeight() / 2 - 60,
                1.4,
                "color=fiery_red"
            )
            return
        end
        refreshRerollText()
        refreshGoldText()
        newTextPopup(
            string.format("Rerolled shop for %dg", spend),
            globals.screenWidth() / 2,
            globals.screenHeight() / 2 - 120,
            1.6,
            "color=marigold"
        )
    end, "shop_reroll_button")

    local actionRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("dusty_rose"))
                :addPadding(6)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :build()
        )
        :addChild(removeButton)
        :addChild(lockButton)
        :addChild(rerollButton)
        :addChild(closeButton)
        :build()

    local jokerTitle = ui.definitions.getNewDynamicTextEntry(
        function() return "Joker Shelf" end,
        26.0,
        "float;color=blue_midnight"
    )
    local jokerHint = ui.definitions.getNewDynamicTextEntry(
        function() return "Reserve a slot for jokers and wildcards" end,
        18.0,
        "color=apricot_cream"
    )

    local jokerPanel = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.ROOT)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("taupe_warm"))
                :addEmboss(4.0)
                :addPadding(10)
                :addMinWidth(500)
                :addMinHeight(90)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :build()
        )
        :addChild(jokerTitle)
        :addChild(jokerHint)
        :build()

    local header = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.VERTICAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("blank"))
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :build()
        )
        :addChild(globals.ui.weatherShopTextEntity)
        :addChild(goldRow)
        :build()

    local weatherRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.VERTICAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("dusty_rose"))
                -- :addShadow(true) --- IGNORE ---
                :addEmboss(4.0)
                :addPadding(12)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        -- add all weather button defs to the row
        :addChild(header) -- add the weather shop text entity
        :addChild(offersPanel)
        :addChild(actionRow)
        :addChild(jokerPanel)
        :build()
    
    
    -- create a new UI box for the shop
    globals.ui.weatherShopUIBox = ui.box.Initialize({x = 10, y = globals.screenHeight() - 100}, weatherRow)
    -- align the weather shop UI box to the center of the screen
    local weatherShopTransform = registry:get(globals.ui.weatherShopUIBox, Transform)
    weatherShopTransform.actualX = globals.screenWidth() / 2 - weatherShopTransform.actualW / 2 -- center horizontally
    weatherShopTransform.visualX = weatherShopTransform.actualX -- update visual position as well
    weatherShopTransform.actualY = globals.screenHeight() -- out of view initially

    setLockIconsVisible(globals.shopUIState.locked)
    refreshRerollText()
    refreshLockText()
    refreshGoldText()
    
    
    -- relics menu 
    -- for each relic in globals.ownedRelics, create a hoverable animatione entity
    local relicsRowImages = {}
    
    for _, ownedRelic in ipairs(globals.ownedRelics) do
        local relicID = ownedRelic.id
        local relicDef = findInTable(globals.relicDefs, "id", relicID)
        if relicDef then
            -- you already have the entry, no need to look it up again
            ownedRelic.animation_entity = animation_system.createAnimatedObjectWithTransform(
                relicDef.spriteID,
                true
            )
        
            animation_system.resizeAnimationObjectsInEntityToFit(
                ownedRelic.animation_entity,
                40, 40
            )
        
            local relicIconDef = ui.definitions.wrapEntityInsideObjectElement(ownedRelic.animation_entity)
        
            local relicGameObject = registry:get(ownedRelic.animation_entity, GameObject)
            relicGameObject.methods.onHover = function()
                showTooltip(
                localization.get(relicDef.localizationKeyName),
                localization.get(relicDef.localizationKeyDesc)
                )
            end
            relicGameObject.state.hoverEnabled = true
            relicGameObject.state.collisionEnabled = true -- enable collision for the hover to work
      
          table.insert(relicsRowImages, relicIconDef)
        end
      end
    
    -- make a new row for relics
    local relicsRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addId("relics_row")
                :addColor(util.getColor("blank"))
                -- :addShadow(true) --- IGNORE ---
                -- :addEmboss(4.0)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        -- add all relic button defs to the row
        :addChildren(relicsRowImages)
        :build()
    relicsRow.config.id = "relics_row" -- set the id for the relics row   
    
    -- new root
    local relicsRoot = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.ROOT)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("dusty_rose"))
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(relicsRow) -- add the relics row
        :build()
    -- new ui box for relics
    globals.ui.relicsUIBox = ui.box.Initialize({x = 10, y = globals.screenHeight() - 200}, relicsRoot)
    -- align the relics UI box to the left side of the screen, and top
    local relicsTransform = registry:get(globals.ui.relicsUIBox, Transform)
    local currencyBoxTrnsform = globals.ui.currencyUIBox and registry:get(globals.ui.currencyUIBox, Transform)
    
    globals.ui.relicsUIElementRow = ui.box.GetUIEByID(registry, globals.ui.relicsUIBox, "relics_row")
    
    if currencyBoxTrnsform then
        relicsTransform.actualX = currencyBoxTrnsform.actualX + currencyBoxTrnsform.actualW + 10 -- 10 pixels from the right edge of the currency box
    else
        relicsTransform.actualX = 10
    end
    relicsTransform.visualX = relicsTransform.actualX -- update visual position as well
    relicsTransform.actualY = 10 -- 10 pixels from the top edge
    relicsTransform.visualY = relicsTransform.actualY -- update visual position as well
    
    
    -- text that says "new day has arrived!"
    globals.ui.newDayTextEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.new_day_text") end,  -- initial text
        30.0,                                 -- font size
        "bump"                       -- animation spec
    )
    
    -- put in its own row
    local newDayTextDef = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("taupe_warm"))
                -- :addShadow(true) --- IGNORE ---
                :addEmboss(4.0)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(globals.ui.newDayTextEntity)
        :build()
        
    -- new uibox
    globals.ui.newDayUIBox = ui.box.Initialize({x = globals.screenWidth() / 2 - 150, y = globals.screenHeight() / 2 - 50}, newDayTextDef)
    -- align the new day UI box to the center of the screen
    local newDayTransform = registry:get(globals.ui.newDayUIBox, Transform)
    newDayTransform.actualX = globals.screenWidth() / 2 - newDayTransform.actualW / 2 -- center horizontally
    newDayTransform.visualX = newDayTransform.actualX -- update visual position as well
    newDayTransform.actualY = globals.screenHeight() -- hide it initially
end

function ui_defs.generateShopUI()
    buildShopUI()
end

function ui_defs.generateUI()
    
    -- make a ui rect to the side of the screen
    local rectDef = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.RECT_SHAPE)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("taupe_warm"))
                -- :addShadow(true) --- IGNORE ---
                :addEmboss(4.0)
                :addMinWidth(230)
                :addMinHeight(230)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_LEFT , AlignmentFlag.VERTICAL_TOP))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :build()
        
    local rectTextDef = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.TEXT)
        :addConfig(
            UIConfigBuilder.create()
                :addText(localization.get("ui.drag_to_duplicate")) -- title text
                :addColor(util.getColor("blackberry"))
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_BOTTOM))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :build()
        
    -- ui root
    local dragDropboxRoot = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.ROOT)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("dusty_rose"))
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_TOP))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(rectDef)
        :addChild(rectTextDef)
        :build()
        
    -- ui box, place it at the top left corner of the screen
    dragDropboxUIBOX = ui.box.Initialize({x = 10, y = 10}, dragDropboxRoot)
    -- align the ui box to the top left corner of the screen
    local uiBoxTransform = registry:get(dragDropboxUIBOX, Transform)
    uiBoxTransform.actualX = 10 -- 10 pixels from the left edge
    uiBoxTransform.visualX = uiBoxTransform.actualX -- update visual position as well
    uiBoxTransform.actualY = 300 -- 10 pixels from the top edge
    
    -- get root, make collidable
    local rootEntity = registry:get(dragDropboxUIBOX, UIBoxComponent).uiRoot
    local rootGameObject = registry:get(rootEntity, GameObject)
    rootGameObject.state.collisionEnabled = true -- make the root collidable
    rootGameObject.state.triggerOnReleaseEnabled = true -- make the root hoverable
    
    rootGameObject.methods.onRelease = function(registry, releasedOn, released)
        log_debug("entity", released, "released on", releasedOn)
        
        -- is it one of the colonists?
        if lume.find(globals.colonists, released) == nil then
            -- not one of the colonists. show text popup
            newTextPopup(
                localization.get("ui.drag_to_duplicate_invalid") -- text to show
            )   
            return
        else
            -- check the colonist has more than 2 hp 
            local health = getBlackboardFloat(released, "health") or 0
            if health < 2 then
                -- not enough health to duplicate, show text popup
                newTextPopup(
                    localization.get("ui.drag_to_duplicate_invalid_health") -- text to show
                )
                return
            end
            
            log_debug("Duplicating colonist", released, "on", releasedOn, "with health", health)
            
            playSoundEffect("effects", "drop-duplicate") -- play acid rain damage sound effect
            -- half the health of the colonist
            setBlackboardFloat(released, "health", health / 2) -- halve the health of the colonist
        end
        
        -- pause the game, show a window which shows a list of selections
        togglePausedState(true) -- pause the game
        
        -- set global variable
        globals.recentlyDroppedColonist = released -- set the recently dropped colonist
        
        -- TODO: show globals.ui.creatureDuplicateChoiceUIbox
        local creatureChoiceTransform = registry:get(globals.ui.creatureDuplicateChoiceUIbox, Transform)
        creatureChoiceTransform.actualY = globals.screenHeight() / 2 - creatureChoiceTransform.actualH / 2 -- center it vertically
    end
    
    layer_order_system.assignZIndexToEntity(
        dragDropboxUIBOX, -- entity to assign z-index to
        2 -- z-index value
    )
    ui.box.AssignLayerOrderComponents(
        registry, -- registry to use
        dragDropboxUIBOX -- ui box to assign layer order components to
    )
    -- 
    -- AssignLayerOrderComponents to propogate to uibox
    
    
    -- gold digger 3830-TheRoguelike_1_10_alpha_623.png
        -- costs nothing but dies very easily
    -- healer 3868-TheRoguelike_1_10_alpha_661.png
        -- costs 1 gold each turn to maintain
    -- damage cushion 3846-TheRoguelike_1_10_alpha_639.png  
        -- costs 2 gold each turn to maintain
    
    local gold_digger_button_def = createStructurePlacementButton(
        "3830-TheRoguelike_1_10_alpha_623.png", -- sprite ID for colonist home
        "goldDiggerAnimEntity", -- global animation handle
        "goldDiggerTextEntity", -- global text handle
        "ui.gold_digger_button", -- localization key for text
        findInTable(globals.creature_defs, "id", "gold_digger").cost -- cost to buy the colonist home
    )
    
    gold_digger_button_def.config.id = "gold_digger_button" -- set the id for the button
    gold_digger_button_def.config.buttonCallback = function ()
        -- check if user has enough gold
        if (globals.currency < findInTable(globals.creature_defs, "id", "gold_digger").cost) then
            newTextPopup(
                localization.get("ui.not_enough_currency") -- text to show
            )
            playSoundEffect("effects", "cannot-buy") -- play cannot buy sound effect
            return
        end
        playSoundEffect("effects", "duplicate") -- play button click sound
        -- deduct the cost from the currency
        globals.currency = globals.currency - findInTable(globals.creature_defs, "id", "gold_digger").cost
        spawnGoldDigger() -- spawn a gold digger
        
        -- move the selected colonist, if valid, 300 pixels to the right
        if (globals.recentlyDroppedColonist and registry:valid(globals.recentlyDroppedColonist) and globals.recentlyDroppedColonist ~= entt_null) then
            local transform = registry:get(globals.recentlyDroppedColonist, Transform)
            transform.actualX = transform.actualX + 300 -- move 300 pixels to the right
            
            
            -- reset variable
            globals.recentlyDroppedColonist = nil -- reset the recently dropped colonist
        end
        
        -- resume the game
        togglePausedState(false) -- unpause the game
        
        -- hide the creature duplicate choice UI box
        local transform = registry:get(globals.ui.creatureDuplicateChoiceUIbox, Transform)
        transform.actualY = globals.screenHeight() -- hide the UI box
    end
    
    local healer_button_def = createStructurePlacementButton(
        "3868-TheRoguelike_1_10_alpha_661.png", -- sprite ID for healer
        "healerAnimEntity", -- global animation handle
        "healerTextEntity", -- global text handle
        "ui.healer_button", -- localization key for text
        findInTable(globals.creature_defs, "id", "healer").cost -- cost to buy the colonist home
    )
    
    healer_button_def.config.id = "healer_button" -- set the id for the button
    healer_button_def.config.buttonCallback = function ()
        -- check if user has enough gold
        if (globals.currency < findInTable(globals.creature_defs, "id", "healer").cost) then
            newTextPopup(
                localization.get("ui.not_enough_currency") -- text to show
            )
            playSoundEffect("effects", "cannot-buy") -- play cannot buy sound effect
            return
        end
        playSoundEffect("effects", "duplicate") -- play button click sound
        -- deduct the cost from the currency
        globals.currency = globals.currency - findInTable(globals.creature_defs, "id", "healer").cost
        spawnHealer() -- spawn a healer
        
        -- move the selected colonist, if valid, 300 pixels to the right
        if (globals.recentlyDroppedColonist and registry:valid(globals.recentlyDroppedColonist) and globals.recentlyDroppedColonist ~= entt_null) then
            local transform = registry:get(globals.recentlyDroppedColonist, Transform)
            transform.actualX = transform.actualX + 300 -- move 300 pixels to the right
            
            -- reset variable
            globals.recentlyDroppedColonist = nil -- reset the recently dropped colonist
        end
        -- resume the game
        togglePausedState(false) -- unpause the game
        
        -- hide the creature duplicate choice UI box
        local transform = registry:get(globals.ui.creatureDuplicateChoiceUIbox, Transform)
        transform.actualY = globals.screenHeight() -- hide the UI box
    end
    
    
    local damage_cushion_button_def = createStructurePlacementButton(
        "3846-TheRoguelike_1_10_alpha_639.png", -- sprite ID for damage cushion
        "damageCushionAnimEntity", -- global animation handle
        "damageCushionTextEntity", -- global text handle
        "ui.damage_cushion_button", -- localization key for text
        findInTable(globals.creature_defs, "id", "damage_cushion").cost -- cost to buy the colonist home
    )
    
    damage_cushion_button_def.config.id = "damage_cushion_button" -- set the id for the button
    damage_cushion_button_def.config.buttonCallback = function ()
        
        -- check if user has enough gold
        if (globals.currency < findInTable(globals.creature_defs, "id", "damage_cushion").cost) then
            newTextPopup(
                localization.get("ui.not_enough_currency") -- text to show
            )
            playSoundEffect("effects", "cannot-buy") -- play cannot buy sound effect
            return
        end
        
        playSoundEffect("effects", "duplicate") -- play button click sound
        -- deduct the cost from the currency
        globals.currency = globals.currency - findInTable(globals.creature_defs, "id", "damage_cushion").cost
        spawnDamageCushion() -- spawn a damage cushion
        
        -- move the selected colonist, if valid, 300 pixels to the right
        if (globals.recentlyDroppedColonist and registry:valid(globals.recentlyDroppedColonist) and globals.recentlyDroppedColonist ~= entt_null) then
            local transform = registry:get(globals.recentlyDroppedColonist, Transform)
            transform.actualX = transform.actualX + 300 -- move 300 pixels to the right
            
            -- reset variable
            globals.recentlyDroppedColonist = nil -- reset the recently dropped colonist
        end
        
        -- resume the game
        togglePausedState(false) -- unpause the game
        
        -- hide the creature duplicate choice UI box
        local transform = registry:get(globals.ui.creatureDuplicateChoiceUIbox, Transform)
        transform.actualY = globals.screenHeight() -- hide the UI box
    end
    
    -- add to row
    local creatureRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("dusty_rose"))
                -- :addShadow(true) --- IGNORE ---
                :addEmboss(4.0)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(gold_digger_button_def)
        :addChild(healer_button_def)
        :addChild(damage_cushion_button_def)
        :build()
        
    -- a text entity that says "cancel"
    local cancelTextDef = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.TEXT)
        :addConfig(
            UIConfigBuilder.create()
                :addText(localization.get("ui.cancel_button")) -- title text
                :addColor(util.getColor("blackberry"))
                :addEmboss(4.0)
                :addButtonCallback(function()
                    -- button click callback
                    log_debug("Cancel button clicked!")
                    playSoundEffect("effects", "button-click") -- play button click sound
                    
                    -- hide the creature duplicate choice UI box
                    local transform = registry:get(globals.ui.creatureDuplicateChoiceUIbox, Transform)
                    transform.actualY = globals.screenHeight() -- hide the UI box
                    togglePausedState(false) -- unpause the game
                end)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_BOTTOM))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :build()
    
    -- new rootEntity
    local duplicateChoiceRoot = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.ROOT)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("dusty_rose"))
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_TOP))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(creatureRow) -- add the drag to duplicate text entity
        -- :addChild(cancelTextDef) -- add the cancel text entity
        :build()
    -- new uibox
    globals.ui.creatureDuplicateChoiceUIbox = ui.box.Initialize({x = 10, y = 200}, duplicateChoiceRoot)
    
    layer_order_system.assignZIndexToEntity(
        globals.ui.creatureDuplicateChoiceUIbox, -- entity to assign z-index to
        5 -- z-index value
    )
    ui.box.AssignLayerOrderComponents( -- propogate layer order components to the uibox
        registry, -- registry to use
        globals.ui.creatureDuplicateChoiceUIbox -- ui box to assign layer order components to
    )
    -- align the creature duplicate choice UI box to the center of the screen, out of view
    local creatureChoiceTransform = registry:get(globals.ui.creatureDuplicateChoiceUIbox, Transform)
    creatureChoiceTransform.actualX = globals.screenWidth() / 2 - creatureChoiceTransform.actualW / 2 -- center it horizontally
    creatureChoiceTransform.visualX = creatureChoiceTransform.actualX -- update visual position as well
    creatureChoiceTransform.actualY = globals.screenHeight() -- out of view initially
    
    -- get uie by id
    globals.ui.goldDiggerButtonElement = ui.box.GetUIEByID(
        registry,
        "gold_digger_button" -- id of the UI element
    )
    globals.ui.healerButtonElement = ui.box.GetUIEByID(
        registry,
        "healer_button" -- id of the UI element
    )
    globals.ui.damageCushionButtonElement = ui.box.GetUIEByID(
        registry,
        "damage_cushion_button" -- id of the UI element
    )
    
    -- add hover
    local goldDiggerButtonGameObject = registry:get(globals.ui.goldDiggerButtonElement, GameObject)
    goldDiggerButtonGameObject.state.hoverEnabled = true -- enable hover for the button
    goldDiggerButtonGameObject.state.collisionEnabled = true -- enable collision for the button
    goldDiggerButtonGameObject.methods.onHover = function(registry, hoveredOn, hovered)
        -- show the tooltip 
        showTooltip(
            localization.get("ui.gold_digger_button"), -- entity hovered on
            localization.get("ui.gold_digger_tooltip_body") -- tooltip body
        )
    end
    local healerButtonGameObject = registry:get(globals.ui.healerButtonElement, GameObject)
    healerButtonGameObject.state.hoverEnabled = true -- enable hover for the button_UIE
    healerButtonGameObject.state.collisionEnabled = true -- enable collision for the button
    
    healerButtonGameObject.methods.onHover = function(registry, hoveredOn, hovered)
        -- show the tooltip 
        showTooltip(
            localization.get("ui.healer_button"), -- entity hovered only    
            localization.get("ui.healer_tooltip_body") -- tooltip body
        )
    end
    local damageCushionButtonGameObject = registry:get(globals.ui.damageCushionButtonElement, GameObject)
    damageCushionButtonGameObject.state.hoverEnabled = true -- enable hover for the button_UIE
    damageCushionButtonGameObject.state.collisionEnabled = true -- enable collision for the button
    damageCushionButtonGameObject.methods.onHover = function(registry, hoveredOn, hovered)
        -- show the tooltip 
        showTooltip(
            localization.get("ui.damage_cushion_button"), -- entity hovered on
            localization.get("ui.damage_cushion_tooltip_body") -- tooltip body
        )
    end
    
    
    -- show current weather
    globals.ui.weatherTextEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.weather_ui_format", {weather = globals.current_weather_event}) end,  -- initial text
        30.0,                                 -- font size
        "rainbow"                       -- animation spec
    )
    
    layer_order_system.assignZIndexToEntity(
        globals.ui.weatherTextEntity.config.object, -- entity to assign z-index to
        40 -- z-index value, always show in front
    )
    
    -- place at the top center of the screen
    local weatherTransform = registry:get(globals.ui.weatherTextEntity.config.object, Transform)
    weatherTransform.actualX = globals.screenWidth() / 2 - weatherTransform.actualW / 2 -- center it horizontally
    weatherTransform.visualX = weatherTransform.actualX -- update visual position as well
    weatherTransform.actualY = 150 -- 10 pixels from the top edge
    weatherTransform.visualY = weatherTransform.actualY -- update visual position as well
    
    -- timer to update weather 
    timer.every(1, function()
        -- update the weather text every second
        local input = nil
        if globals.current_weather_event == nil then
            input = "Fair Weather"
        else
            input = findInTable(globals.weather_event_defs, "id", globals.current_weather_event).ui_text
            input = localization.get(input) -- get the localized text for the weather event
        end
        local text = localization.get("ui.weather_ui_format", {weather = input})
        TextSystem.Functions.setText(globals.ui.weatherTextEntity.config.object, text)
        TextSystem.Functions.applyGlobalEffects(globals.ui.weatherTextEntity.config.object, "rainbow") -- apply the rainbow effect to the text

        -- center the weather text
        local weatherTextTransform = registry:get(globals.ui.weatherTextEntity.config.object, Transform)
        weatherTextTransform.actualX = globals.screenWidth() / 2 - weatherTextTransform.actualW / 2 -- center it horizontally
        weatherTextTransform.visualX = weatherTextTransform.actualX -- update visual position as well
        
    end)
    
    -- show day 
    globals.ui.dayTextEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.day_ui_format", {day = globals.game_time.days or 1}) end,  -- initial text
        60.0,                                 -- font size
        "color=blackberry"                       -- animation spec
    )
    
    -- show time in XX:XX AM/PM format, create text entity
    globals.ui.timeTextEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.time_ui_format", {hour = globals.game_time.hours, am_pm = globals.game_time.hours < 12 and "AM" or "PM"}) end,  -- initial text
        40.0,                                 -- font size
        "pulse=0.9,1.0"                       -- animation spec
    )
    
    log_debug(globals.ui.timeTextEntity.config.object)
    
    
    timer.every(0.5, function()
        log_debug("Updating game time...")
        -- update the time text every second
        local text = localization.get("ui.time_ui_format", {hour = globals.game_time.hours, minute = math.floor(globals.game_time.minutes), am_pm = globals.game_time.hours < 12 and "AM" or "PM"})
        TextSystem.Functions.setText(globals.ui.timeTextEntity.config.object, text)
        
        -- update the ui box size
        ui.box.RenewAlignment(registry, globals.ui.timeTextUIBox)
        
        -- get ui box transform, align to the right side of the screen
        local uiBoxTransform = registry:get(globals.ui.timeTextUIBox, Transform)
        uiBoxTransform.actualX = globals.screenWidth() - uiBoxTransform.actualW - 10 -- 10 pixels from the right edge
        uiBoxTransform.visualX = uiBoxTransform.actualX -- update visual position as well
        uiBoxTransform.visualW = uiBoxTransform.actualW -- update visual width as well
        
        
    end)
    
    timer.every(1, function()
        -- update the day text every second
        local text = localization.get("ui.day_ui_format", {day = globals.game_time.days})
        TextSystem.Functions.setText(globals.ui.dayTextEntity.config.object, text)
        
        -- update the ui box size
        ui.box.RenewAlignment(registry, globals.ui.dayTextUIBox)
        
        -- get ui box transform, align to the right side of the screen
        local uiBoxTransform = registry:get(globals.ui.dayTextUIBox, Transform)
        uiBoxTransform.actualX = globals.screenWidth() - uiBoxTransform.actualW - 10 -- 10 pixels from the right edge
        uiBoxTransform.visualX = uiBoxTransform.actualX -- update visual position as well
        uiBoxTransform.visualW = uiBoxTransform.actualW -- update visual width as well
        
    end)
    
    -- new root
    local timeTextRoot = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.ROOT)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("dusty_rose"))
                :addNoMovementWhenDragged(true)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_LEFT , AlignmentFlag.VERTICAL_TOP))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        
        :addChild(globals.ui.timeTextEntity)
        :build()
        
    
    
    -- new day root
    local dayTextRoot = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.ROOT)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("dusty_rose"))
                :addNoMovementWhenDragged(true)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_LEFT , AlignmentFlag.VERTICAL_TOP))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        
        :addChild(globals.ui.dayTextEntity)
        :build()
    -- create a new UI box for the day text
    globals.ui.dayTextUIBox = ui.box.Initialize({x = 10, y = 60}, dayTextRoot)
    -- align the day text UI box to the right side of the screen
    local dayTextTransform = registry:get(globals.ui.dayTextUIBox, Transform)
    dayTextTransform.actualX = globals.screenWidth() - dayTextTransform.actualW - 10 -- 10 pixels from the right edge
    dayTextTransform.visualX = dayTextTransform.actualX -- update visual position as well
    
    -- create a new UI box for the time text
    globals.ui.timeTextUIBox = ui.box.Initialize({x = 10, y = 10}, timeTextRoot)
    
    -- right side of the screen, below the day text
    local timeTextTransform = registry:get(globals.ui.timeTextUIBox, Transform)
    timeTextTransform.actualX = globals.screenWidth() - timeTextTransform.actualW - 10 -- 10 pixels from the right edge
    timeTextTransform.visualX = timeTextTransform.actualX -- update visual position as well
    timeTextTransform.actualY = dayTextTransform.actualY + dayTextTransform.actualH + 10 -- 10 pixels below the day texture
    timeTextTransform.visualY = timeTextTransform.actualY -- update visual position as well
    
    -- a shop button 
    globals.ui.shopButtonTextEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.shop_button") end,  -- initial text
        20.0,                                 -- font size
        "bump"                       -- animation spec
    )
    
    local shopButtonDef = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("dusty_rose"))
                -- :addShadow(true) --- IGNORE ---
                :addEmboss(4.0)
                :addHover(true) -- needed for button effect
                :addButtonCallback(function()
                    -- button click callback
                    log_debug("Shop button clicked!")
                    playSoundEffect("effects", "button-click") -- play button click sound
                    
                    if (globals.isShopOpen) then
                        globals.isShopOpen = false
                        local transform = registry:get(globals.ui.weatherShopUIBox, Transform)
                        transform.actualY = globals.screenHeight() -- hide the shop UI box
                    else
                        globals.isShopOpen = true
                        local transform = registry:get(globals.ui.weatherShopUIBox, Transform)
                        transform.actualY = globals.screenHeight() / 2 - transform.actualH / 2-- show the shop UI box
                    end
                    
                end)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(globals.ui.shopButtonTextEntity)
        :build()
        
    local shopButtonRoot = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.ROOT)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("blank"))
                :addMinHeight(50)
                -- :addShadow(true)
                -- :addMaxWidth(300)
                :addPadding(0)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(shopButtonDef)
        :build()
        
    -- create a new UI box for the shop button
    globals.ui.shopButtonUIBox = ui.box.Initialize({x = globals.screenWidth() - 300, y = 10}, shopButtonRoot)
    -- align the shop button UI box to the right side of the screen
    local shopButtonTransform = registry:get(globals.ui.shopButtonUIBox, Transform)
    shopButtonTransform.actualX = globals.screenWidth() - shopButtonTransform.actualW - 10 -- 10 pixels from the right edge
    shopButtonTransform.visualX = shopButtonTransform.actualX -- update visual position as well
    -- move it out of sight
    shopButtonTransform.actualY = globals.screenHeight()
    
    
    -- text that says "strcture placement"
    globals.ui.itemPlacementTextEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.item_placement_text") end,  -- initial text
        30.0,                                 -- font size
        "bump"                       -- animation spec
    )
    
    -- put in its own row
    local itemPlacementTextDef = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("blank"))
                -- :addShadow(true) --- IGNORE ---
                -- :addEmboss(4.0)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(globals.ui.itemPlacementTextEntity)
        :build()
        
    
        
    local home_structure_def = createStructurePlacementButton(
        "3490-TheRoguelike_1_10_alpha_283.png", -- sprite ID for colonist home
        "colonistHomeButtoAnimationEntity", -- global animation handle
        "colonistHomeTextEntity", -- global text handle
        "ui.colonist_home_text", -- localization key for text
        findInTable(globals.structure_defs, "id", "colonist_home").cost -- cost to buy the colonist home
    )
    
    home_structure_def.config.buttonCallback = function ()
        playSoundEffect("effects", "building-placed") -- play the currency spawn sound effect
        buyNewColonistHomeCallback()
    end
    
    home_structure_def.config.id = "colonist_home_button" -- set the id for the button, so we can find it later
    
    -- local duplicator_structure_def = createStructurePlacementButton(
    --     "3641-TheRoguelike_1_10_alpha_434.png", -- sprite ID for duplicator
    --     "duplicatorButtonAnimationEntity", -- global animation handle
    --     "duplicatorTextEntity", -- global text handle
    --     "ui.duplicator_text", -- localization key for text
    --     findInTable(globals.structure_defs, "id", "duplicator").cost -- cost to buy the duplicator
    -- )
    
    -- duplicator_structure_def.config.buttonCallback = function ()
    --     buyNewDuplicatorCallback()
    -- end
    



    
    -- make horizontal container for other items if necessary
    local structurePlacementRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addId("structure_placement_row")
                :addColor(util.getColor("dusty_rose"))
                :addShadow(true) 
                -- :addEmboss(4.0) --- IGNORE ---
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(home_structure_def)
        -- :addChild(duplicator_structure_def)
        :build()
        
    -- new vertical container for title and buttons row
    local newRoot = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.VERTICAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("blank"))
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_LEFT , AlignmentFlag.VERTICAL_TOP))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(itemPlacementTextDef)
        :addChild(structurePlacementRow)
        :build()
        
    -- create a new UI box for the structure placement row
    globals.ui.structurePlacementUIBox = ui.box.Initialize({x = 10, y = 120}, newRoot)
    
    -- get the uie colonist home button
    globals.ui.colonistHomeButton = ui.box.GetUIEByID(
        registry, -- registry to use
        globals.ui.structurePlacementUIBox, -- ui box to search in
        "colonist_home_button" -- id of the UI element to find
    )
    -- add hover
    local colonistHomeButtonGameObject = registry:get(globals.ui.colonistHomeButton, GameObject)
    colonistHomeButtonGameObject.state.hoverEnabled = true -- enable hover for the colonist
    colonistHomeButtonGameObject.state.collisionEnabled = true -- enable collision for the colonist home button
    colonistHomeButtonGameObject.methods.onHover = function(registry, hoveredOn, hovered)
        showTooltip(localization.get("ui.colonist_home_tooltip_title"),
            localization.get("ui.colonist_home_tooltip_body"))
    end
    
    -- align the structure placement UI box to the left side of the screen, and bottom
    local structurePlacementTransform = registry:get(globals.ui.structurePlacementUIBox, Transform)
    structurePlacementTransform.actualX = 10 -- 10 pixels from the left edge
    structurePlacementTransform.visualX = structurePlacementTransform.actualX -- update visual position as well
    structurePlacementTransform.actualY = globals.screenHeight() - structurePlacementTransform.actualH - 10 -- 10 pixels from the bottom edge
    structurePlacementTransform.visualY = structurePlacementTransform.actualY -- update visual position as well
    
    
    -- currency icon
    globals.ui.currencyIconEntity = animation_system.createAnimatedObjectWithTransform(
        "4024-TheRoguelike_1_10_alpha_817.png", -- animation ID
        true             -- true if sprite id
    )
    
    animation_system.resizeAnimationObjectsInEntityToFit(
        globals.ui.currencyIconEntity, -- entity to resize
        40, -- width
        40  -- height
    )
    
    -- wrap the currency icon in a UI element
    local currencyIconDef = ui.definitions.wrapEntityInsideObjectElement(globals.ui.currencyIconEntity)
    
    -- new number text entry for the currency amount
    globals.ui.currencyTextEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.currency_text", {currency = math.floor(0)}) end,  -- initial text
        30.0,                                 -- font size
        ""                       -- animation spec
    )
    
    globals.ui.currencyTextEntity.config.minWidth = 100
    
    -- new timer to update the currency text every second
    timer.every(1, function()
        -- update the currency text every second
        local text = localization.get("ui.currency_text", {currency = math.floor(globals.currency)})
        TextSystem.Functions.setText(globals.ui.currencyTextEntity.config.object, text)
        if globals.ui.shopGoldText and globals.ui.shopGoldText.config and globals.ui.shopGoldText.config.object then
            TextSystem.Functions.setText(globals.ui.shopGoldText.config.object, "Gold: " .. math.floor(globals.currency + 0.5))
        end
        
    end)
    
    -- add both to a rootUIElement
    local currencyRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("blank"))
                -- :addShadow(true) --- IGNORE ---
                -- :addEmboss(4.0)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(currencyIconDef)
        :addChild(globals.ui.currencyTextEntity)
        :build()
        
    -- create a new UI box for the currency row
    globals.ui.currencyUIBox = ui.box.Initialize({x = globals.screenWidth() - 200, y = 10}, currencyRow)
    -- align the currency UI box to the top left
    local currencyTransform = registry:get(globals.ui.currencyUIBox, Transform)
    currencyTransform.actualX = 10
    currencyTransform.visualX = currencyTransform.actualX -- update visual position as well
    currencyTransform.actualY = 10 -- 10 pixels from the top edge
    currencyTransform.visualY = currencyTransform.actualY -- update visual position as well
    
    if not globals.ui.weatherShopUIBox then
        -- make a weather dificulty text
        globals.ui.weatherDifficultyTextEntity = ui.definitions.getNewDynamicTextEntry(
            function() return localization.get("ui.weather_difficulty_text", {difficulty = globals.current_weather_event_base_damage}) end,  -- initial text
            30.0,                                 -- font size
            "pulse"                       -- animation spec
        )
    
    -- update it every 2 seconds
    timer.every(2, function()
        -- update the weather difficulty text every 2 seconds
        local text = localization.get("ui.weather_difficulty_text", {difficulty = globals.current_weather_event_base_damage})
        TextSystem.Functions.setText(globals.ui.weatherDifficultyTextEntity.config.object, text)    
        TextSystem.Functions.applyGlobalEffects(globals.ui.weatherDifficultyTextEntity.config.object, "pulse") -- apply the pulse effect to the text
    end)
    
    -- put in a row
    local weatherDifficultyTextDef = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("blank"))
                -- :addShadow(true) --- IGNORE ---
                -- :addEmboss(4.0) --- IGNORE ---
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(globals.ui.weatherDifficultyTextEntity)
        :build()
    -- create a new UI box for the weather difficulty text
    globals.ui.weatherDifficultyUIBox = ui.box.Initialize({x = globals.screenWidth() - 200, y = 60}, weatherDifficultyTextDef)
    -- align the weather difficulty UI box to the top right of the screen
    local weatherDifficultyTransform = registry:get(globals.ui.weatherDifficultyUIBox, Transform)
    weatherDifficultyTransform.actualX = globals.screenWidth() - weatherDifficultyTransform.actualW - 10 -- 10 pixels from the right edge
    weatherDifficultyTransform.visualX = weatherDifficultyTransform.actualX -- update visual position as well
    weatherDifficultyTransform.actualY = 10 -- 10 pixels from the top edge
    weatherDifficultyTransform.visualY = weatherDifficultyTransform.actualY
    
    
    local relicSlots = {
        {id = "relic1", spriteID = "4165-TheRoguelike_1_10_alpha_958.png", text = "ui.relic_slot_1", animHandle = "relic1ButtonAnimationEntity", textHandle = "relic1TextEntity", cost = 0, costTextHandle = "relic1CostTextEntity", uielementID = "relic1UIElement"},
        {id = "relic2", spriteID = "4169-TheRoguelike_1_10_alpha_962.png", text = "ui.relic_slot_2", animHandle = "relic2ButtonAnimationEntity", textHandle = "relic2TextEntity", cost = 0, costTextHandle = "relic2CostTextEntity", uielementID = "relic2UIElement"},
        {id = "relic3", spriteID = "4054-TheRoguelike_1_10_alpha_847.png", text = "ui.relic_slot_3", animHandle = "relic3ButtonAnimationEntity", textHandle = "relic3TextEntity", cost = 0, costTextHandle = "relic3CostTextEntity", uielementID = "relic3UIElement"},
    }

    local weatherButtonDefs = {}
    
    -- populate weatherButtonDefs based on weatherEvents
    for _, event in ipairs(relicSlots) do

        -- TODO: so these are stored under globals.ui["relic1TextEntity"] globals.ui["relic1ButtonAnimationEntity"] and so on, we will access these later
        local buttonDef = createStructurePlacementButton(
            event.spriteID, -- sprite ID for the weather event
            event.animHandle, -- global animation handle
            event.textHandle, -- global text handle
            event.text, -- localization key for text
            event.cost, -- cost to buy the weather event
            event.costTextHandle -- global cost text handle
        )
        
        buttonDef.config.id = event.uielementID -- set the id for the buttonDef
        -- add buttonDef to weatherButtonDefs
        table.insert(weatherButtonDefs, buttonDef)
    end

    local ShopSystem = require("core.shop_system")
    globals.shopUIState.rerollCost = globals.shopUIState.rerollCost or ShopSystem.config.baseRerollCost
    globals.shopUIState.rerollCount = globals.shopUIState.rerollCount or 0
    globals.shopUIState.locked = globals.shopUIState.locked or false
    globals.shopUIState.awaitingRemoval = false

    local function formatGold(amount)
        return "Gold: " .. tostring(math.floor(amount + 0.5))
    end

    globals.ui.shopLockIcons = {}

    local function buildLockIcon(idSuffix)
        local icon = animation_system.createAnimatedObjectWithTransform(
            "4024-TheRoguelike_1_10_alpha_817.png",
            true
        )
        animation_system.resizeAnimationObjectsInEntityToFit(icon, 22, 22)
        animation_system.setFGColorForAllAnimationObjects(icon, util.getColor("blackberry"))
        local animComp = component_cache.get(icon, AnimationQueueComponent)
        if animComp then
            animComp.noDraw = true
        end
        local iconGO = component_cache.get(icon, GameObject)
        if iconGO and iconGO.state then
            iconGO.state.hoverEnabled = false
            iconGO.state.collisionEnabled = false
        end
        table.insert(globals.ui.shopLockIcons, icon)
        local iconDef = ui.definitions.wrapEntityInsideObjectElement(icon)
        iconDef.config.id = "shop_lock_icon_" .. idSuffix
        return iconDef
    end

    local function setLockIconsVisible(visible)
        for _, icon in ipairs(globals.ui.shopLockIcons) do
            local animComp = component_cache.get(icon, AnimationQueueComponent)
            if animComp then
                animComp.noDraw = not visible
            end
            local t = component_cache.get(icon, Transform)
            if t then
                local size = visible and 22 or 0
                t.actualW = size
                t.visualW = size
                t.actualH = size
                t.visualH = size
            end
        end
        if globals.ui.weatherShopUIBox then
            ui.box.RenewAlignment(registry, globals.ui.weatherShopUIBox)
        end
    end
    globals.ui.setLockIconsVisible = setLockIconsVisible

    local offerSlots = {}
    for i, buttonDef in ipairs(weatherButtonDefs) do
        if i <= 3 then
            local slot = UIElementTemplateNodeBuilder.create()
                :addType(UITypeEnum.VERTICAL_CONTAINER)
                :addConfig(
                    UIConfigBuilder.create()
                        :addColor(util.getColor("blank"))
                        :addPadding(4)
                        :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                        :build()
                )
                :addChild(buildLockIcon(i))
                :addChild(buttonDef)
                :build()
            table.insert(offerSlots, slot)
        end
    end
    
    -- add a close button to the weather shop
    local closeButton = createStructurePlacementButton(
        "4158-TheRoguelike_1_10_alpha_951.png", 
        "shopCloseButton", -- global animation handle
        "shopCloseText", -- global text handle
        "ui.shop_close" -- localization key for text
    )
    closeButton.config.buttonCallback = function ()
        -- close the weather shop
        log_debug("Weather shop closed!")
        playSoundEffect("effects", "button-click") -- play button click sound
        toggleShopWindow() -- toggle the shop window visibility
        togglePausedState(false) -- unpause the game
    end
    
    -- add a text entity that says "Shop"
    globals.ui.weatherShopTextEntity = ui.definitions.getNewDynamicTextEntry(
        function() return "SHOP" end,  -- initial text
        46.0,                                 -- font size
        "float;wiggle;color=marigold"                       -- animation spec
    )

    local shopGoldIcon = animation_system.createAnimatedObjectWithTransform(
        "4024-TheRoguelike_1_10_alpha_817.png",
        true
    )
    animation_system.resizeAnimationObjectsInEntityToFit(
        shopGoldIcon,
        28,
        28
    )
    globals.ui.shopGoldText = ui.definitions.getNewDynamicTextEntry(
        function() return formatGold(globals.currency) end,  -- initial text
        26.0,                                 -- font size
        "pulse;color=apricot_cream"                       -- animation spec
    )

    local goldRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("blank"))
                :addPadding(6)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :build()
        )
        :addChild(ui.definitions.wrapEntityInsideObjectElement(shopGoldIcon))
        :addChild(globals.ui.shopGoldText)
        :build()

    local offersLabel = ui.definitions.getNewDynamicTextEntry(
        function() return "Card Offers" end,
        22.0,
        "color=apricot_cream"
    )

    local offersRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("blank"))
                :addPadding(8)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :build()
        )
        :addChildren(offerSlots)
        :build()

    local offersPanel = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.ROOT)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("taupe_warm"))
                :addEmboss(6.0)
                :addPadding(12)
                :addMinWidth(560)
                :addMinHeight(200)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :build()
        )
        :addChild(offersLabel)
        :addChild(offersRow)
        :build()

    local function buildShopButton(textEntry, callback, id)
        return UIElementTemplateNodeBuilder.create()
            :addType(UITypeEnum.HORIZONTAL_CONTAINER)
            :addConfig(
                UIConfigBuilder.create()
                    :addId(id or "")
                    :addColor(util.getColor("dusty_rose"))
                    :addEmboss(4.0)
                    :addHover(true)
                    :addPadding(6)
                    :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                    :addButtonCallback(callback)
                    :build()
            )
            :addChild(textEntry)
            :build()
    end

    globals.ui.shopRemoveButtonText = ui.definitions.getNewDynamicTextEntry(
        function() return "Remove card" end,
        20.0,
        "bump"
    )
    globals.ui.shopLockButtonText = ui.definitions.getNewDynamicTextEntry(
        function()
            if globals.shopUIState.locked then
                return "Unlock offers"
            end
            return "Lock offers"
        end,
        20.0,
        "pulse"
    )
    globals.ui.shopRerollButtonText = ui.definitions.getNewDynamicTextEntry(
        function() return string.format("Reroll (%dg)", math.floor(globals.shopUIState.rerollCost + 0.5)) end,
        20.0,
        "bump"
    )

    local function refreshRerollText()
        if globals.ui.shopRerollButtonText and globals.ui.shopRerollButtonText.config then
            TextSystem.Functions.setText(
                globals.ui.shopRerollButtonText.config.object,
                string.format("Reroll (%dg)", math.floor(globals.shopUIState.rerollCost + 0.5))
            )
        end
    end

    local function refreshLockText()
        if globals.ui.shopLockButtonText and globals.ui.shopLockButtonText.config then
            local nextLabel = globals.shopUIState.locked and "Unlock offers" or "Lock offers"
            TextSystem.Functions.setText(globals.ui.shopLockButtonText.config.object, nextLabel)
        end
    end

    local function refreshGoldText()
        if globals.ui.shopGoldText and globals.ui.shopGoldText.config then
            TextSystem.Functions.setText(globals.ui.shopGoldText.config.object, formatGold(globals.currency))
        end
    end

    local removeButton = buildShopButton(globals.ui.shopRemoveButtonText, function()
        globals.shopUIState.awaitingRemoval = true
        playSoundEffect("effects", "button-click")
        newTextPopup(
            string.format("Choose a card to remove (-%dg)", ShopSystem.config.removalCost),
            globals.screenWidth() / 2,
            globals.screenHeight() / 2 - 80,
            1.8,
            "color=fiery_red"
        )
    end, "shop_remove_button")

    local lockButton = buildShopButton(globals.ui.shopLockButtonText, function()
        local nextLocked = not globals.shopUIState.locked
        if setShopLocked then
            setShopLocked(nextLocked)
        else
            globals.shopUIState.locked = nextLocked
        end
        playSoundEffect("effects", "button-click")
        setLockIconsVisible(globals.shopUIState.locked)
        refreshLockText()
        newTextPopup(
            globals.shopUIState.locked and "Shop locked" or "Shop unlocked",
            globals.screenWidth() / 2,
            globals.screenHeight() / 2 - 100,
            1.4,
            "color=plum"
        )
    end, "shop_lock_button")

    local rerollButton = buildShopButton(globals.ui.shopRerollButtonText, function()
        local spend = math.floor(globals.shopUIState.rerollCost + 0.5)
        local success = rerollActiveShop and rerollActiveShop()
        if not success then
            playSoundEffect("effects", "cannot-buy")
            local message = "Need more gold to reroll"
            if not (getActiveShop and getActiveShop()) then
                message = "Shop not available"
            end
            newTextPopup(
                message,
                globals.screenWidth() / 2,
                globals.screenHeight() / 2 - 60,
                1.4,
                "color=fiery_red"
            )
            return
        end
        refreshRerollText()
        refreshGoldText()
        newTextPopup(
            string.format("Rerolled shop for %dg", spend),
            globals.screenWidth() / 2,
            globals.screenHeight() / 2 - 120,
            1.6,
            "color=marigold"
        )
    end, "shop_reroll_button")

    local actionRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("dusty_rose"))
                :addPadding(6)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :build()
        )
        :addChild(removeButton)
        :addChild(lockButton)
        :addChild(rerollButton)
        :addChild(closeButton)
        :build()

    local jokerTitle = ui.definitions.getNewDynamicTextEntry(
        function() return "Joker Shelf" end,
        26.0,
        "float;color=blue_midnight"
    )
    local jokerHint = ui.definitions.getNewDynamicTextEntry(
        function() return "Reserve a slot for jokers and wildcards" end,
        18.0,
        "color=apricot_cream"
    )

    local jokerPanel = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.ROOT)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("taupe_warm"))
                :addEmboss(4.0)
                :addPadding(10)
                :addMinWidth(500)
                :addMinHeight(90)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :build()
        )
        :addChild(jokerTitle)
        :addChild(jokerHint)
        :build()

    local header = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.VERTICAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("blank"))
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :build()
        )
        :addChild(globals.ui.weatherShopTextEntity)
        :addChild(goldRow)
        :build()

    local weatherRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.VERTICAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("dusty_rose"))
                -- :addShadow(true) --- IGNORE ---
                :addEmboss(4.0)
                :addPadding(12)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        -- add all weather button defs to the row
        :addChild(header) -- add the weather shop text entity
        :addChild(offersPanel)
        :addChild(actionRow)
        :addChild(jokerPanel)
        :build()
    
    
    -- create a new UI box for the shop
    globals.ui.weatherShopUIBox = ui.box.Initialize({x = 10, y = globals.screenHeight() - 100}, weatherRow)
    -- align the weather shop UI box to the center of the screen
    local weatherShopTransform = registry:get(globals.ui.weatherShopUIBox, Transform)
    weatherShopTransform.actualX = globals.screenWidth() / 2 - weatherShopTransform.actualW / 2 -- center horizontally
    weatherShopTransform.visualX = weatherShopTransform.actualX -- update visual position as well
    weatherShopTransform.actualY = globals.screenHeight() -- out of view initially

    setLockIconsVisible(globals.shopUIState.locked)
    refreshRerollText()
    refreshLockText()
    refreshGoldText()
    
    
    -- relics menu 
    -- for each relic in globals.ownedRelics, create a hoverable animatione entity
    local relicsRowImages = {}
    
    for _, ownedRelic in ipairs(globals.ownedRelics) do
        local relicID = ownedRelic.id
        local relicDef = findInTable(globals.relicDefs, "id", relicID)
        if relicDef then
            -- you already have the entry, no need to look it up again
            ownedRelic.animation_entity = animation_system.createAnimatedObjectWithTransform(
                relicDef.spriteID,
                true
            )
        
            animation_system.resizeAnimationObjectsInEntityToFit(
                ownedRelic.animation_entity,
                40, 40
            )
        
            local relicIconDef = ui.definitions.wrapEntityInsideObjectElement(ownedRelic.animation_entity)
        
            local relicGameObject = registry:get(ownedRelic.animation_entity, GameObject)
            relicGameObject.methods.onHover = function()
                showTooltip(
                localization.get(relicDef.localizationKeyName),
                localization.get(relicDef.localizationKeyDesc)
                )
            end
            relicGameObject.state.hoverEnabled = true
            relicGameObject.state.collisionEnabled = true -- enable collision for the hover to work
      
          table.insert(relicsRowImages, relicIconDef)
        end
      end
    
    -- make a new row for relics
    local relicsRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addId("relics_row")
                :addColor(util.getColor("blank"))
                -- :addShadow(true) --- IGNORE ---
                -- :addEmboss(4.0)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        -- add all relic button defs to the row
        :addChildren(relicsRowImages)
        :build()
    relicsRow.config.id = "relics_row" -- set the id for the relics row   
    
    -- new root
    local relicsRoot = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.ROOT)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("dusty_rose"))
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(relicsRow) -- add the relics row
        :build()
    -- new ui box for relics
    globals.ui.relicsUIBox = ui.box.Initialize({x = 10, y = globals.screenHeight() - 200}, relicsRoot)
    -- align the relics UI box to the left side of the screen, and top
    local relicsTransform = registry:get(globals.ui.relicsUIBox, Transform)
    local currencyBoxTrnsform = registry:get(globals.ui.currencyUIBox, Transform)
    
    globals.ui.relicsUIElementRow = ui.box.GetUIEByID(registry, globals.ui.relicsUIBox, "relics_row")
    
    relicsTransform.actualX = currencyBoxTrnsform.actualX + currencyBoxTrnsform.actualW + 10 -- 10 pixels from the right edge of the currency box
    relicsTransform.visualX = relicsTransform.actualX -- update visual position as well
    relicsTransform.actualY = 10 -- 10 pixels from the top edge
    relicsTransform.visualY = relicsTransform.actualY -- update visual position as well
    
    
    -- text that says "new day has arrived!"
    globals.ui.newDayTextEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.new_day_text") end,  -- initial text
        30.0,                                 -- font size
        "bump"                       -- animation spec
    )
    
    -- put in its own row
    local newDayTextDef = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("taupe_warm"))
                -- :addShadow(true) --- IGNORE ---
                :addEmboss(4.0)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(globals.ui.newDayTextEntity)
        :build()
        
    -- new uibox
        globals.ui.newDayUIBox = ui.box.Initialize({x = globals.screenWidth() / 2 - 150, y = globals.screenHeight() / 2 - 50}, newDayTextDef)
        -- align the new day UI box to the center of the screen
        local newDayTransform = registry:get(globals.ui.newDayUIBox, Transform)
        newDayTransform.actualX = globals.screenWidth() / 2 - newDayTransform.actualW / 2 -- center horizontally
        newDayTransform.visualX = newDayTransform.actualX -- update visual position as well
        newDayTransform.actualY = globals.screenHeight() -- hide it initially
    end
    
    
    -- new pause/unpause button
    -- new anim entity for pause button
    globals.ui.pauseButtonAnimationEntity = animation_system.createAnimatedObjectWithTransform(
        "tile_0538.png", -- animation/sprite ID
        true             
    )
    animation_system.resizeAnimationObjectsInEntityToFit(
        globals.ui.pauseButtonAnimationEntity, -- entity to resize
        40, -- width
        40  -- height
    )
    -- wrap the pause button in a UI element
    local pauseButtonDef = ui.definitions.wrapEntityInsideObjectElement(globals.ui.pauseButtonAnimationEntity)
    -- new row 
    local pauseButtonRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("blank"))
                :addHover(true) -- needed for button effect
                -- :addShadow(true) --- IGNORE ---
                -- :addEmboss(4.0)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :addButtonCallback(function()
                    -- button click callback
                    log_debug("Pause button clicked!")
                    playSoundEffect("effects", "button-click") -- play button click sound
                    
                    togglePausedState()
                    
                end)
                :build()
        )
        :addChild(pauseButtonDef)
        :build()
        
    -- create a new UI box for the pause button
    globals.ui.pauseButtonUIBox = ui.box.Initialize({x = globals.screenWidth() - 100, y = 10}, pauseButtonRow)
    -- align the pause button UI box to the right side of the screen
    local pauseButtonTransform = registry:get(globals.ui.pauseButtonUIBox, Transform)
    pauseButtonTransform.actualX = globals.screenWidth() - pauseButtonTransform.actualW - 10 -- 10 pixels from the right edge
    pauseButtonTransform.visualX = pauseButtonTransform.actualX -- update visual position as well
    -- above the shop button
    local shopButtonTransform = registry:get(globals.ui.shopButtonUIBox, Transform)
    pauseButtonTransform.actualY = shopButtonTransform.actualY - pauseButtonTransform.actualH - 10 -- 10 pixels below the shop button
    pauseButtonTransform.visualY = pauseButtonTransform.actualY -- update visual position as well
    
    
    globals.tutorials = {
        "ui.tutorial_duplicate",
        "ui.tutorial_game_goal",
        "ui.tutorial_advanced",
        "ui.tutorial_end"
    }
    
    globals.currentTutorialIndex = 1 -- Start with the first tutorial
    
    -- first, make a row with a text entity and a close button
    -- globals.ui.tutorialText = ui.definitions.getNewDynamicTextEntry(
    --     function() return localization.get(globals.tutorials[globals.currentTutorialIndex]) end,  -- initial text
    --     30.0,                                 -- font size
    --     ""                       -- animation spec
    -- )
    
    -- local rectTextDef = UIElementTemplateNodeBuilder.create()
    --     :addType(UITypeEnum.TEXT)
    --     :addConfig(
    --         UIConfigBuilder.create()
    --             :addText(localization.get("ui.drag_to_duplicate")) -- title text
    --             :addColor(util.getColor("blackberry"))
    --             :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_BOTTOM)
    --             :addInitFunc(function(registry, entity)
    --                 -- something init-related here
    --             end)
    --             :build()
    --     )
    --     :build()
    local rowDef = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.TEXT)
        :addConfig(
            UIConfigBuilder.create()
                :addId("tutorial_text_row")
                :addColor(util.getColor("taupe_warm"))
                :addText(localization.get(globals.tutorials[globals.currentTutorialIndex])) -- title text
                :addColor(util.getColor("blackberry"))
                -- :addEmboss(2.0)
                -- :addMinWidth(500) -- minimum width of the button
                -- :addShadow(true)
                -- :addHover(true) -- needed for button effect
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :build()
        )
        -- :addChild(globals.ui.tutorialText)
        :build()
        
    local closeButtonText = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.next_tutorial_text") end,  -- initial text
        30.0,                                 -- font size
        "color=apricot_cream"                       -- animation spec
    )
    
    local closeButtonTemplate = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("taupe_warm"))
                :addEmboss(2.0)
                :addHover(true) -- needed for button effect
                :addMinWidth(500) -- minimum width of the button
                :addButtonCallback(function ()
                    nextTutorialCallback()
                end)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :build()
        )
        :addChild(closeButtonText)
        :build()
        
    -- new root
    local tutorialRoot = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.ROOT)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("mauve_shadow"))
                :addShadow(true)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(rowDef)
        :addChild(closeButtonTemplate)
        :build()
        
    -- new uibox for the tutorial
    globals.ui.tutorial_uibox = ui.box.Initialize({x = 350, y = globals.screenHeight()}, tutorialRoot)
    -- center the uibox
    local tutorialTransform = registry:get(globals.ui.tutorial_uibox, Transform)
    tutorialTransform.actualX = globals.screenWidth() / 2 - tutorialTransform.actualW / 2
    -- snap x
    tutorialTransform.visualX = tutorialTransform.actualX
    tutorialTransform.actualY = globals.screenHeight() / 2 - tutorialTransform.actualH / 2
end

function ui_defs.generateTooltipUI()

    -- tooltip ui box that will follow the mouse cursor
    local tooltipTitleText = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("sample tooltip title") end,  -- initial text
        30.0,                                 -- font size
        "rainbow"                       -- animation spec
    )
    registry:get(tooltipTitleText.config.object, TextSystem.Text).shadow_enabled = false -- disable shadow for the tooltip title text
    globals.ui.tooltipTitleText = tooltipTitleText.config.object
    local tooltipBodyText = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("Sample tooltip body text") end,  -- initial text
        30.0,                                 -- font size
        "fade"                       -- animation spec
)
    registry:get(tooltipBodyText.config.object, TextSystem.Text).shadow_enabled = false -- disable shadow for the tooltip body text
    globals.ui.tooltipBodyText = tooltipBodyText.config.object
    
    -- make vertical container for the tooltip
    local tooltipContainer = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.VERTICAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("taupe_warm"))
            :addMinHeight(50)
            :addMinWidth(200)
            :addPadding(2)
            :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(tooltipTitleText)
    :addChild(tooltipBodyText)
    :build()
    -- make a new tooltip root
    local tooltipRoot =  UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.ROOT)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("dusty_rose"))
            :addMinHeight(50)
            :addPadding(2)
            :addShadow(true)
            :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER , AlignmentFlag.VERTICAL_CENTER))
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(tooltipContainer)
    :build()
    
    
    
    
    
    
    
    -- create a new UI box for the tooltip
    
    globals.ui.tooltipUIBox = ui.box.Initialize({x = 300, y = globals.screenHeight()}, tooltipRoot)
    
    layer_order_system.assignZIndexToEntity(
        globals.ui.tooltipUIBox, -- entity to assign z-index to
        1000 -- z-index value, always show in front
    )
    
    -- get transform for the tooltip UI box
    local tooltipTransform = registry:get(globals.ui.tooltipUIBox, Transform)
    tooltipTransform.ignoreXLeaning = true -- ignore X leaning so it doesn't tilt
    local uiBoxComp = registry:get(globals.ui.tooltipUIBox, UIBoxComponent)
    local uiTooltipRootTransform = registry:get(uiBoxComp.uiRoot, Transform)
    uiTooltipRootTransform.ignoreXLeaning = true -- ignore X leaning so it doesn't tilt
     
end

return ui_defs
