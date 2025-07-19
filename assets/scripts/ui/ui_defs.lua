
-- build defs here


ui_defs = {
    
}

function ui_defs.placeBuilding(buildingName)
    
end

function createStructurePlacementButton(spriteID, globalAnimationHandle, globalTextHandle, textLocalizationKey, costValue)
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
    globals.ui[globalTextHandle] = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get(textLocalizationKey) end,  -- initial text
        20.0,                                 -- font size
        ""                       -- animation spec
    )
    
    
    local costRow = nil
    if costValue then
        -- cost string
        local costText = ui.definitions.getNewDynamicTextEntry(
            function() return localization.get("ui.cost_text", {cost = costValue}) end,  -- initial text
            20.0,                                 -- font size
            ""                       -- animation spec
        )
        
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
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
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
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(globals.ui[globalTextHandle])
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
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
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
function ui_defs.generateUI()
    
    -- make a ui rect to the side of the screen
    local rectDef = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.RECT_SHAPE)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("taupe_warm"))
                -- :addShadow(true) --- IGNORE ---
                :addEmboss(4.0)
                :addMinWidth(200)
                :addMinHeight(200)
                :addAlign(AlignmentFlag.HORIZONTAL_LEFT | AlignmentFlag.VERTICAL_TOP)
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
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_BOTTOM)
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
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_TOP)
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
            
            -- half the health of the colonist
            setBlackboardFloat(released, "health", health / 2) -- halve the health of the colonist
        end
        
        -- pause the game, show a window which shows a list of selections
        togglePausedState(true) -- pause the game
        
        -- TODO: show globals.ui.creatureDuplicateChoiceUIbox
        local creatureChoiceTransform = registry:get(globals.ui.creatureDuplicateChoiceUIbox, Transform)
        creatureChoiceTransform.actualY = globals.screenHeight() / 2 - creatureChoiceTransform.actualH / 2 -- center it vertically
    end
    
    layer_order_system.assignZIndexToEntity(
        dragDropboxUIBOX, -- entity to assign z-index to
        0 -- z-index value
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
    
    gold_digger_button_def.config.buttonCallback = function ()
        -- check if user has enough gold
        if (globals.currency < findInTable(globals.creature_defs, "id", "gold_digger").cost) then
            newTextPopup(
                localization.get("ui.not_enough_currency") -- text to show
            )
            return
        end
        -- deduct the cost from the currency
        globals.currency = globals.currency - findInTable(globals.creature_defs, "id", "gold_digger").cost
        spawnGoldDigger() -- spawn a gold digger
        
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
    
    healer_button_def.config.buttonCallback = function ()
        -- check if user has enough gold
        if (globals.currency < findInTable(globals.creature_defs, "id", "healer").cost) then
            newTextPopup(
                localization.get("ui.not_enough_currency") -- text to show
            )
            return
        end
        -- deduct the cost from the currency
        globals.currency = globals.currency - findInTable(globals.creature_defs, "id", "healer").cost
        spawnHealer() -- spawn a healer
        
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
    
    damage_cushion_button_def.config.buttonCallback = function ()
        -- check if user has enough gold
        if (globals.currency < findInTable(globals.creature_defs, "id", "damage_cushion").cost) then
            newTextPopup(
                localization.get("ui.not_enough_currency") -- text to show
            )
            return
        end
        -- deduct the cost from the currency
        globals.currency = globals.currency - findInTable(globals.creature_defs, "id", "damage_cushion").cost
        spawnDamageCushion() -- spawn a damage cushion
        
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
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
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
                :addShadow(true)
                :addButtonCallback(function()
                    -- button click callback
                    log_debug("Cancel button clicked!")
                    playSoundEffect("effects", "button-click") -- play button click sound
                    
                    -- hide the creature duplicate choice UI box
                    local transform = registry:get(globals.ui.creatureDuplicateChoiceUIbox, Transform)
                    transform.actualY = globals.screenHeight() -- hide the UI box
                    togglePausedState(false) -- unpause the game
                end)
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_BOTTOM)
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
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_TOP)
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(creatureRow) -- add the drag to duplicate text entity
        :addChild(cancelTextDef) -- add the cancel text entity
        :build()
    -- new uibox
    globals.ui.creatureDuplicateChoiceUIbox = ui.box.Initialize({x = 10, y = 200}, duplicateChoiceRoot)
    -- align the creature duplicate choice UI box to the center of the screen, out of view
    local creatureChoiceTransform = registry:get(globals.ui.creatureDuplicateChoiceUIbox, Transform)
    creatureChoiceTransform.actualX = globals.screenWidth() / 2 - creatureChoiceTransform.actualW / 2 -- center it horizontally
    creatureChoiceTransform.visualX = creatureChoiceTransform.actualX -- update visual position as well
    creatureChoiceTransform.actualY = globals.screenHeight() -- out of view initially
    
    -- show current weather
    globals.ui.weatherTextEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.weather_ui_format", {weather = globals.current_weather_event}) end,  -- initial text
        30.0,                                 -- font size
        "pulse"                       -- animation spec
    )
    
    -- place at the top center of the screen
    local weatherTransform = registry:get(globals.ui.weatherTextEntity.config.object, Transform)
    weatherTransform.actualX = globals.screenWidth() / 2 - weatherTransform.actualW / 2 -- center it horizontally
    weatherTransform.visualX = weatherTransform.actualX -- update visual position as well
    weatherTransform.actualY = 100 -- 10 pixels from the top edge
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
                :addAlign(AlignmentFlag.HORIZONTAL_LEFT | AlignmentFlag.VERTICAL_TOP)
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
                :addAlign(AlignmentFlag.HORIZONTAL_LEFT | AlignmentFlag.VERTICAL_TOP)
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
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
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
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
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
    -- bottom right corner of the screen
    shopButtonTransform.actualY = globals.screenHeight() - shopButtonTransform.actualH - 10 -- 10 pixels from the bottom edge
    shopButtonTransform.visualY = shopButtonTransform.actualY -- update visual position as well
    
    
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
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
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
        buyNewColonistHomeCallback()
    end
    
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
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
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
                :addAlign(AlignmentFlag.HORIZONTAL_LEFT | AlignmentFlag.VERTICAL_TOP)
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
        20.0,                                 -- font size
        ""                       -- animation spec
    )
    
    globals.ui.currencyTextEntity.config.minWidth = 100
    
    -- new timer to update the currency text every second
    timer.every(1, function()
        -- update the currency text every second
        local text = localization.get("ui.currency_text", {currency = math.floor(globals.currency)})
        TextSystem.Functions.setText(globals.ui.currencyTextEntity.config.object, text)
        
    end)
    
    -- add both to a rootUIElement
    local currencyRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("blank"))
                -- :addShadow(true) --- IGNORE ---
                -- :addEmboss(4.0)
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
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
    
    
    local relicSlots = {
        {id = "relic1", spriteID = "4165-TheRoguelike_1_10_alpha_958.png", text = "ui.relic_slot_1", animHandle = "relic1ButtonAnimationEntity", textHandle = "relic1TextEntity"},
        {id = "relic2", spriteID = "4169-TheRoguelike_1_10_alpha_962.png", text = "ui.relic_slot_2", animHandle = "relic2ButtonAnimationEntity", textHandle = "relic2TextEntity"},
        {id = "relic3", spriteID = "4054-TheRoguelike_1_10_alpha_847.png", text = "ui.relic_slot_3", animHandle = "relic3ButtonAnimationEntity", textHandle = "relic3TextEntity"},
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
            event.cost -- cost to buy the weather event
        )
        -- add buttonDef to weatherButtonDefs
        table.insert(weatherButtonDefs, buttonDef)
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
    -- add the close button to the weatherButtonDefs
    table.insert(weatherButtonDefs, closeButton)
    
    -- make a new row
    local weatherRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.VERTICAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("dusty_rose"))
                -- :addShadow(true) --- IGNORE ---
                :addEmboss(4.0)
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        -- add all weather button defs to the row
        :addChildren(weatherButtonDefs)
        :build()
    
    
    -- create a new UI box for the shop
    globals.ui.weatherShopUIBox = ui.box.Initialize({x = 10, y = globals.screenHeight() - 100}, weatherRow)
    -- align the weather shop UI box to the center of the screen
    local weatherShopTransform = registry:get(globals.ui.weatherShopUIBox, Transform)
    weatherShopTransform.actualX = globals.screenWidth() / 2 - weatherShopTransform.actualW / 2 -- center horizontally
    weatherShopTransform.visualX = weatherShopTransform.actualX -- update visual position as well
    weatherShopTransform.actualY = globals.screenHeight() -- out of view initially
    
    
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
                :addColor(util.getColor("blank"))
                -- :addShadow(true) --- IGNORE ---
                -- :addEmboss(4.0)
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        -- add all relic button defs to the row
        :addChildren(relicsRowImages)
        :build()
        
    -- new ui box for relics
    globals.ui.relicsUIBox = ui.box.Initialize({x = 10, y = globals.screenHeight() - 200}, relicsRow)
    -- align the relics UI box to the left side of the screen, and top
    local relicsTransform = registry:get(globals.ui.relicsUIBox, Transform)
    local currencyBoxTrnsform = registry:get(globals.ui.currencyUIBox, Transform)
    
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
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
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
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
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
end

function ui_defs.generateTooltipUI()

    -- tooltip ui box that will follow the mouse cursor
    local tooltipTitleText = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("sample tooltip title") end,  -- initial text
        18.0,                                 -- font size
        "rainbow"                       -- animation spec
    )
    globals.ui.tooltipTitleText = tooltipTitleText.config.object
    local tooltipBodyText = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("Sample tooltip body text") end,  -- initial text
        15.0,                                 -- font size
        "fade"                       -- animation spec
    )
    globals.ui.tooltipBodyText = tooltipBodyText.config.object
    
    -- make vertical container for the tooltip
    local tooltipContainer = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.VERTICAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("taupe_warm"))
            :addMinHeight(50)
            :addMinWidth(200)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
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
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(tooltipContainer)
    :build()
    
    
    
    
    
    
    
    -- create a new UI box for the tooltip
    
    globals.ui.tooltipUIBox = ui.box.Initialize({x = 300, y = globals.screenHeight()}, tooltipRoot)
    
    -- get transform for the tooltip UI box
    local tooltipTransform = registry:get(globals.ui.tooltipUIBox, Transform)
    tooltipTransform.ignoreXLeaning = true -- ignore X leaning so it doesn't tilt
    local uiBoxComp = registry:get(globals.ui.tooltipUIBox, UIBoxComponent)
    local uiTooltipRootTransform = registry:get(uiBoxComp.uiRoot, Transform)
    uiTooltipRootTransform.ignoreXLeaning = true -- ignore X leaning so it doesn't tilt
     
end