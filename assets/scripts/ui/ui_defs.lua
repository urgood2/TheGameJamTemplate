
-- build defs here


ui_defs = {
    
}

function ui_defs.placeBuilding(buildingName)
    
end

function ui_defs.generateUI() 
    -- ui
    
    globals.currencies["whale_dust"].ui_icon_entity = animation_system.createAnimatedObjectWithTransform(
        "whale_dust_anim", -- animation ID
        false             -- use animation, not sprite id
    )
    -- add tooltip
    local whaleDustGameObject = registry:get(globals.currencies["whale_dust"].ui_icon_entity, GameObject)
    whaleDustGameObject.methods.onHover = function()
        showTooltip(localization.get("ui.tooltip_currency_whale_dust_title"), localization.get("ui.tooltip_currency_whale_dust"))
    end
    whaleDustGameObject.methods.onStopHover = function()
        hideTooltip()
    end
    whaleDustGameObject.state.hoverEnabled = true
    whaleDustGameObject.state.collisionEnabled = true -- enable collision for the hover to work
    
    local currencyIconDef = ui.definitions.wrapEntityInsideObjectElement(
        globals.currencies["whale_dust"].ui_icon_entity)
    
    local sliderTextMoving = ui.definitions.getNewDynamicTextEntry(
        localization.get("ui.currency_text"),  -- initial text
        16.0,                                 -- font size
        nil,                                  -- no style override
        "pulse=0.9,1.1"                       -- animation spec
    )
    
    --TODO do this later
    sliderTextMoving.config.initFunc = function(registry, entity)
        localization.onLanguageChanged(function(newLang)
            TextSystem.Functions.setText(entity, localization.get("ui.currency_text", {currency = math.floor(globals.currencies.whale_dust.amount)}))
        end)
    end
    sliderTextMoving.config.updateFunc = function(r, entity, dt)
        local elementUIConfig = registry:get(entity, UIConfig)
        local objectEntity = elementUIConfig.object
        if not registry:valid(objectEntity) then
            return
        end
        
        local objectTextComp = registry:get(objectEntity, TextSystem.Text)
        
        
        local text = localization.get("ui.currency_text", {currency = math.floor(globals.currencies.whale_dust.amount)})
        
        if (objectTextComp.rawText ~= text) then
            TextSystem.Functions.setText(objectEntity, text)
        end
    end
    
    -- create other entries for crystals, wafers, chips
    globals.currencies["wafer"].ui_icon_entity = animation_system.createAnimatedObjectWithTransform(
        "wafer_anim", -- animation ID
        false             -- use animation, not sprite id
    )
    -- add tooltip
    local waferGameObject = registry:get(globals.currencies["wafer"].ui_icon_entity, GameObject)
    local converterDef = findInTable(globals.converter_defs, "id", "crystal_to_wafer")
    waferGameObject.methods.onHover = function()
        showTooltip(localization.get("ui.tooltip_currency_wafers_title"), localization.get("ui.tooltip_currency_wafers") .. getCostStringForMaterial(converterDef))
    end
    waferGameObject.methods.onStopHover = function()
        hideTooltip()
    end
    waferGameObject.state.hoverEnabled = true
    waferGameObject.state.collisionEnabled = true -- enable collision for the hover to work
    
    globals.currencies["chip"].ui_icon_entity = animation_system.createAnimatedObjectWithTransform(
        "chip_anim", -- animation ID
        false             -- use animation, not sprite id
    )
    local converterDef = findInTable(globals.converter_defs, "id", "wafer_to_chip")
    local chipGameObject = registry:get(globals.currencies["chip"].ui_icon_entity, GameObject)
    chipGameObject.methods.onHover = function()
        showTooltip(localization.get("ui.tooltip_currency_chips_title"), localization.get("ui.tooltip_currency_chips") .. getCostStringForMaterial(converterDef))
    end
    chipGameObject.methods.onStopHover = function()
        hideTooltip()
    end
    chipGameObject.state.hoverEnabled = true
    chipGameObject.state.collisionEnabled = true -- enable collision for the hover to work
    
    globals.currencies["crystal"].ui_icon_entity = animation_system.createAnimatedObjectWithTransform(
        "crystal_anim", -- animation ID
        false             -- use animation, not sprite id
    )
    local converterDef = findInTable(globals.converter_defs, "id", "dust_to_crystal")
    local crystalGameObject = registry:get(globals.currencies["crystal"].ui_icon_entity, GameObject)
    crystalGameObject.methods.onHover = function()
        showTooltip(localization.get("ui.tooltip_currency_crystals_title"), localization.get("ui.tooltip_currency_crystals") .. getCostStringForMaterial(converterDef))
    end
    crystalGameObject.methods.onStopHover = function()
        hideTooltip()
    end
    crystalGameObject.state.hoverEnabled = true
    crystalGameObject.state.collisionEnabled = true -- enable collision for the hover to work
    
    
    globals.currencies["song_essence"].ui_icon_entity = animation_system.createAnimatedObjectWithTransform(
        "song_essence_anim", -- animation ID
        false             -- use animation, not sprite id
    )
    local songEssenceGameObject = registry:get(globals.currencies["song_essence"].ui_icon_entity, GameObject)
    songEssenceGameObject.methods.onHover = function()
        showTooltip(localization.get("ui.tooltip_currency_song_essence_title"), localization.get("ui.tooltip_currency_song_essence"))
    end
    songEssenceGameObject.methods.onStopHover = function()
        hideTooltip()
    end
    songEssenceGameObject.state.hoverEnabled = true
    songEssenceGameObject.state.collisionEnabled = true -- enable collision for the hover to work
    
    -- now make the text entries for the other currencies
    local textSongEssence = ui.definitions.getNewDynamicTextEntry(
        localization.get("ui.currency_text_song_essence"),  -- initial text
        16.0,                                 -- font size
        nil,                                  -- no style override
        "pulse=0.9,1.1"                       -- animation spec
    )
    textSongEssence.config.initFunc = function(registry, entity)
        localization.onLanguageChanged(function(newLang)
            TextSystem.Functions.setText(entity, localization.get("ui.currency_text_song_essence", {currency = math.floor(globals.currencies.song_essence.amount)}))
        end)
    end
    
    textSongEssence.config.updateFunc = function(r, entity, dt)
        local elementUIConfig = registry:get(entity, UIConfig)
        local objectEntity = elementUIConfig.object
        if not registry:valid(objectEntity) then
            return
        end
        
        local objectTextComp = registry:get(objectEntity, TextSystem.Text)
        
        local text = localization.get("ui.currency_text_song_essence", {currency = math.floor(globals.currencies.song_essence.amount)})
        
        if (objectTextComp.rawText ~= text) then
            TextSystem.Functions.setText(objectEntity, text)
        end
    end
    
    local textWafers = ui.definitions.getNewDynamicTextEntry(
        localization.get("ui.currency_text_wafers"),  -- initial text
        16.0,                                 -- font size
        nil,                                  -- no style override
        "pulse=0.9,1.1"                       -- animation spec
    )
    
    textWafers.config.initFunc = function(registry, entity)
        localization.onLanguageChanged(function(newLang)
            TextSystem.Functions.setText(entity, localization.get("ui.currency_text_wafers", {currency = math.floor(globals.currencies.wafer.amount)}))
        end)
    end
    
    textWafers.config.updateFunc = function(r, entity, dt)
        local elementUIConfig = registry:get(entity, UIConfig)
        local objectEntity = elementUIConfig.object
        if not registry:valid(objectEntity) then
            return
        end
        
        local objectTextComp = registry:get(objectEntity, TextSystem.Text)
        
        local text = localization.get("ui.currency_text_wafers", {currency = math.floor(globals.currencies.wafer.amount)})
        
        if (objectTextComp.rawText ~= text) then
            TextSystem.Functions.setText(objectEntity, text)
        end
    end
    
    local textCrystals = ui.definitions.getNewDynamicTextEntry(
        localization.get("ui.currency_text_crystals"),  -- initial text
        16.0,                                 -- font size
        nil,                                  -- no style override
        "pulse=0.9,1.1"                       -- animation spec
    )
    textCrystals.config.initFunc = function(registry, entity)
        localization.onLanguageChanged(function(newLang)
            TextSystem.Functions.setText(entity, localization.get("ui.currency_text_crystals", {currency = math.floor(globals.currencies.crystal.amount)}))
        end)
    end
    textCrystals.config.updateFunc = function(r, entity, dt)
        local elementUIConfig = registry:get(entity, UIConfig)
        local objectEntity = elementUIConfig.object
        if not registry:valid(objectEntity) then
            return
        end
        
        local objectTextComp = registry:get(objectEntity, TextSystem.Text)
        
        local text = localization.get("ui.currency_text_crystals", {currency = math.floor(globals.currencies.crystal.amount)})
        
        if (objectTextComp.rawText ~= text) then
            TextSystem.Functions.setText(objectEntity, text)
        end
    end
    
    local textChips = ui.definitions.getNewDynamicTextEntry(
        localization.get("ui.currency_text_chips"),  -- initial text
        16.0,                                 -- font size
        nil,                                  -- no style override
        "pulse=0.9,1.1"                       -- animation spec
    )
    textChips.config.initFunc = function(registry, entity)
        localization.onLanguageChanged(function(newLang)
            TextSystem.Functions.setText(entity, localization.get("ui.currency_text_chips", {currency = math.floor(globals.currencies.chip.amount)}))
        end)
    end
    textChips.config.updateFunc = function(r, entity, dt)
        local elementUIConfig = registry:get(entity, UIConfig)
        local objectEntity = elementUIConfig.object
        if not registry:valid(objectEntity) then
            return
        end
        
        local objectTextComp = registry:get(objectEntity, TextSystem.Text)
        
        local text = localization.get("ui.currency_text_chips", {currency = math.floor(globals.currencies.chip.amount)})
        
        if (objectTextComp.rawText ~= text) then
            TextSystem.Functions.setText(objectEntity, text)
        end
    end
    
    -- now wrap each icon + text in a row
    local currencyWhaleDustRow = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("lapi_lazuli"))
            :addNoMovementWhenDragged(true)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(currencyIconDef)
    :addChild(sliderTextMoving)
    :build()
    
    local currencyWafersRow = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("lapi_lazuli"))
            :addNoMovementWhenDragged(true)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(ui.definitions.wrapEntityInsideObjectElement(globals.currencies["wafer"].ui_icon_entity))
    :addChild(textWafers)
    :build()
    
    local currencyChipsRow = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("lapi_lazuli"))
            :addNoMovementWhenDragged(true)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(ui.definitions.wrapEntityInsideObjectElement(globals.currencies["chip"].ui_icon_entity))
    :addChild(textChips)
    
    :build()
    
    local currencyCrystalsRow = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("lapi_lazuli"))
            :addNoMovementWhenDragged(true)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(ui.definitions.wrapEntityInsideObjectElement(globals.currencies["crystal"].ui_icon_entity))
    :addChild(textCrystals)
    :build()
    
    local currencySongEssenceRow = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("lapi_lazuli"))
            :addNoMovementWhenDragged(true)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(ui.definitions.wrapEntityInsideObjectElement(globals.currencies["song_essence"].ui_icon_entity))
    :addChild(textSongEssence)
    :build()
    
    
    local sliderTemplate = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.VERTICAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("lapi_lazuli"))
            
            :addNoMovementWhenDragged(true)
            :addAlign(AlignmentFlag.HORIZONTAL_LEFT | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(currencySongEssenceRow)
    :addChild(currencyWhaleDustRow)
    :addChild(currencyCrystalsRow)
    :addChild(currencyWafersRow)
    :addChild(currencyChipsRow)
    :build()
    
    local newRoot =  UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.ROOT)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("keppel"))
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(sliderTemplate)
    :build()
    
    
    -- dump(ui.box)
    debug(ui)
    debug(ui.element)
    -- dump(newRoot)
    
    local newUIBox = ui.box.Initialize({x = globals.screenWidth() - 400, y = 10}, newRoot)
    
    local newUIBoxTransform = registry:get(newUIBox, Transform)
    local uiBoxComp = registry:get(newUIBox, UIBoxComponent)
    debug(newUIBox)
    debug(uiBoxComp)
    -- anchor to the top right corner of the screen
    newUIBoxTransform.actualX = globals.screenWidth() - newUIBoxTransform.actualW -- 10 pixels from the right edge
    newUIBoxTransform.actualY = 10 -- 10 pixels from the top edge
    
    -- TODO: test aligning to the inside of the game world container with a delay to let the update run
    timer.after(
        1.0, -- delay in seconds
        function()
            -- debug("Aligning newUIBox to the game world container")
            -- align the new UI box to the game world container
            --TODO: debug this, we need to get it working
            -- local uiBoxRole = registry:get(newUIBox, InheritedProperties)
            -- local uiBoxTransform = registry:get(newUIBox, Transform)
            -- transform.AssignRole(registry, newUIBox, InheritedPropertiesType.RoleInheritor, globals.gameWorldContainerEntity());

            -- local gameWorldContainerTransform = registry:get(globals.gameWorldContainerEntity(), Transform)
            -- debug("uiBox width = ", uiBoxTransform.actualW, "uiBox height = ", uiBoxTransform.actualH)
            -- debug("gameWorldContainer width = ", gameWorldContainerTransform.actualW, "gameWorldContainer height = ", gameWorldContainerTransform.actualH)
            -- uiBoxRole.flags = AlignmentFlag.HORIZONTAL_RIGHT | AlignmentFlag.ALIGN_TO_INNER_EDGES | AlignmentFlag.VERTICAL_TOP
        end
    )
    
    
    -- prestige button
    local prestigeButtonText = ui.definitions.getNewDynamicTextEntry(
        localization.get("ui.achievements_button"),  -- initial text
        20.0,                                 -- font size
        nil,                                  -- no style override
        "bump"                       -- animation spec
    )
    

    local prestigeButtonDef = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("lapi_lazuli"))
            -- :addShadow(true)
            :addEmboss(4.0)
            :addHover(true) -- needed for button effect
            :addButtonCallback(function()
                -- button click callback
                debug("Prestige button clicked!")
                local uibox_transform = registry:get(globals.ui.prestige_uibox, Transform)

                -- uibox_transform.actualY = uibox_transform.actualY + 300

                if globals.ui.prestige_window_open then
                    -- close the prestige window
                    globals.ui.prestige_window_open = false                    
                    uibox_transform.actualY = globals.screenHeight()
                else
                    -- open the prestige window
                    globals.ui.prestige_window_open = true
                    uibox_transform.actualY = globals.screenHeight() / 2 - uibox_transform.actualH / 2

                end
            end)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(prestigeButtonText)
    :build()

    local prestigeButtonRoot =  UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.ROOT)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("keppel"))
            :addMinHeight(50)
            :addShadow(true)
            :addMaxWidth(300)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(prestigeButtonDef)
    :build()
    -- create a new UI box for the prestige button
    local prestigeButtonUIBox = ui.box.Initialize({x = globals.screenWidth() - 300, y = 450}, prestigeButtonRoot)
    
    -- right-align the prestige button UI box
    local prestigeButtonTransform = registry:get(prestigeButtonUIBox, Transform)
    prestigeButtonTransform.actualX = globals.screenWidth() - prestigeButtonTransform.actualW -- 10 pixels from the right edge
    


    -- prestige upgrades window
    
    -- there will be six ui elements in each row, and as many rows as needed to fit all the upgrades
    
    local achievementRows = {}
    local currentRow = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("keppel"))
            :addNoMovementWhenDragged(true)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :build()
    
    for i, achivementDef in ipairs(globals.achievements) do
        debug("Adding achievement: ", achivementDef.id, " with animation: ", achivementDef.anim)
        -- make a new achievement animation entity
        achivementDef.anim_entity = animation_system.createAnimatedObjectWithTransform(
            achivementDef.unlocked and  achivementDef.anim or "locked_anim", -- animation ID
            false             -- use animation, not sprite id
        )
        
        -- resize to fit 48 x 48
        animation_system.resizeAnimationObjectsInEntityToFit(
            achivementDef.anim_entity,
            48, -- Width
            48  -- Height
        ) 
        
        -- wrap 
        local achievementAnimDef = ui.definitions.wrapEntityInsideObjectElement(achivementDef.anim_entity)
        
        -- make it hoverable
        local achievementGameObject = registry:get(achivementDef.anim_entity, GameObject)
        achievementGameObject.methods.onHover = function()
            debug("Achievement entity hovered!")
            achivementDef.tooltipFunc()
        end
        achievementGameObject.methods.onStopHover = function()
            debug("Achievement entity stopped hovering!")
            hideTooltip()
        end
        achievementGameObject.state.hoverEnabled = true
        achievementGameObject.state.collisionEnabled = true -- enable collision for the hover to work
        
        -- make a row that will hold the achievement icon
        local imageContainer = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("lapi_lazuli"))
                :addNoMovementWhenDragged(true)
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(achievementAnimDef)
        :build()
        
        -- add the achievement icon to the current row
        currentRow.children:add(imageContainer)
        
        -- if we passed the sixth achievement, we need to start a new row
        if i % 6 == 0 and i > 1 then
            -- save the current row to the achievement rows
            table.insert(achievementRows, currentRow)
            -- start a new row
            currentRow = UIElementTemplateNodeBuilder.create()
            :addType(UITypeEnum.HORIZONTAL_CONTAINER)
            :addConfig(
                UIConfigBuilder.create()
                    :addColor(util.getColor("keppel"))
                    :addNoMovementWhenDragged(true)
                    :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
                    :addInitFunc(function(registry, entity)
                        -- something init-related here
                    end)
                    :build()
            )
            :build()
        end
    end
    
    -- if there are any remaining achievements in the current row, add it to the achievement rows
    if #currentRow.children > 0 and achievementRows[#achievementRows] ~= currentRow then
        table.insert(achievementRows, currentRow)
    end
    
    
    -- make a red X button 
    local closeButtonText = ui.definitions.getNewDynamicTextEntry(
        "Close",  -- initial text
        15.0,                                 -- font size
        nil,                                  -- no style override
        "pulse=0.9,1.1"                       -- animation spec
    )
    -- make a new close button template
    local closeButtonTemplate = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("glaucou"))
            :addEmboss(2.0)
            :addShadow(true)
            :addHover(true) -- needed for button effect
            :addButtonCallback(function()
                -- close the prestige window
                debug("Prestige window close button clicked!")
                globals.ui.prestige_window_open = false
                local uibox_transform = registry:get(globals.ui.prestige_uibox, Transform)
                uibox_transform.actualY = globals.screenHeight()  -- move it out of the screen
            end)
            :addAlign(AlignmentFlag.HORIZONTAL_RIGHT | AlignmentFlag.VERTICAL_TOP)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(closeButtonText)
    :build()
    
    
    -- vertical container for the prestige upgrades
    local prestigeUpgradesContainer = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.VERTICAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("keppel"))
            :addMinWidth(300)
            :addMinHeight(400)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :build()
    
    -- achievements text for the top of the window
    local achievementsText = ui.definitions.getNewDynamicTextEntry(
        localization.get("ui.achievements_button"),  -- initial text
        30.0,                                 -- font size
        nil,                                  -- no style override
        "rainbow"                       -- animation spec
    )
    
    local achievementsTextTemplate = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("lapi_lazuli"))
            :addNoMovementWhenDragged(true)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_TOP)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(achievementsText)
    :build()
    
    -- add title
    prestigeUpgradesContainer.children:add(achievementsTextTemplate)
    
    -- add rows
    for i, row in ipairs(achievementRows) do
        -- add the row to the prestige upgrades container
        prestigeUpgradesContainer.children:add(row)
    end
    
    -- add the close button to the prestige upgrades container
    prestigeUpgradesContainer.children:add(closeButtonTemplate)

    -- uibox for the prestige upgrades
    local prestigeUpgradesContainerRoot = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.ROOT)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("lapi_lazuli"))
            :addMinHeight(400)
            :addMinWidth(300)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(prestigeUpgradesContainer)
    :build()

    -- create a new UI box for the prestige upgrades
    globals.ui.prestige_uibox = ui.box.Initialize({x = 350, y = globals.screenHeight()}, prestigeUpgradesContainerRoot)
    
    -- center the ui box X-axi
    local prestigeUiboxTransform = registry:get(globals.ui.prestige_uibox, Transform)
    prestigeUiboxTransform.actualX = globals.screenWidth() / 2 - prestigeUiboxTransform.actualW / 2
    
    -- ui for the buildings
    local buildingText = ui.definitions.getNewDynamicTextEntry(
        localization.get("ui.building_text"),  -- initial text
        20.0,                                 -- font size
        nil,                                  -- no style override
        "float"                       -- animation spec
    )
    
    local buildingTextGameObject = registry:get(buildingText.config.object, GameObject)
    -- set onhover & stop hover callbacks to show tooltip
    buildingTextGameObject.methods.onHover = function()
        debug("Building text entity hovered!")
        showTooltip(localization.get("ui.grav_wave_title"), localization.get("ui.grav_wave_desc"))
    end
    buildingTextGameObject.methods.onStopHover = function()
        debug("Building text entity stopped hovering!")
        hideTooltip()
    end
    -- make hoverable
    buildingTextGameObject.state.hoverEnabled = true
    buildingTextGameObject.state.collisionEnabled = true -- enable collision for the hover to work
    
    
    local buildingTextTemplate = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
    UIConfigBuilder.create()
        :addColor(util.getColor("lapi_lazuli"))
        :addMinHeight(50)
        :addProgressBar(true) -- enable progress bar effect
        :addProgressBarFullColor(util.getColor("BLUE"))
        :addProgressBarEmptyColor(util.getColor("WHITE"))
        :addProgressBarFetchValueLamnda(function(entity)
            -- return the timer value for the gravity wave thing
            -- debug("Fetching gravity wave seconds for entity: ", timer.get_delay("shockwave_uniform_tween"))
            return (globals.gravityWaveSeconds - globals.timeUntilNextGravityWave) / (timer.get_delay("shockwave_uniform_tween") or globals.gravityWaveSeconds)
        end)

        :addNoMovementWhenDragged(true)
        :addMinWidth(500)
        :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
        :addInitFunc(function(registry, entity)
            -- something init-related here
        end)
        :build()
    )
    :addChild(buildingText)
    :build()
    
    local buildingTextRoot =  UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.ROOT)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("keppel"))
            :addMinHeight(50)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(buildingTextTemplate)
    :build()
    
    -- create a new UI box for the gravity wave progress bar
    local buildingTextUIBox = ui.box.Initialize({x = globals.screenWidth() - 400, y = 600}, buildingTextRoot)
    
    -- align top of the screen, centered
    local buildingTextTransform = registry:get(buildingTextUIBox, Transform)
    buildingTextTransform.actualX = globals.screenWidth() / 2 - buildingTextTransform.actualW / 2
    buildingTextTransform.actualY = 10 -- 10 pixels from the top edge
    
    
    
    
    
    
    
    
    
    -- Make a bottom UI box that will hold the purchase ui
    
    
    -- first upgrade ui (buildings)
    
      
    
    
    timer.every(
        4, -- every 4 seconds
        function()
            -- check building unlock conditions
            -- loop through the table. for each required table, check if the building with that id is unlocked. If all required buildings are unlocked, set the building to unlocked
            local yLocationIncrement = 0 -- used to offset the y position of the text notification
            for i, building in ipairs(globals.building_upgrade_defs) do
                -- remember previous state so we can detect a flip
                local wasUnlocked = building.unlocked
            
                -- only consider those with any requirements
                if not building.unlocked and building.required then
                    local allRequiredUnlocked = true
            
                    -- 1) dependency check
                    for _, reqId in ipairs(building.required) do
                        local reqB = findInTable(globals.building_upgrade_defs, "id", reqId)
                        if not reqB or not reqB.unlocked then
                            allRequiredUnlocked = false
                            break
                        end
                    end
            
                    -- 2) currency check (only if deps passed)
                    if allRequiredUnlocked and building.required_currencies then
                        for currencyKey, reqAmount in pairs(building.required_currencies) do
                            local have = globals.currencies[currencyKey].target or 0
                            if have < reqAmount then
                                allRequiredUnlocked = false
                                break
                            end
                        end
                    end
                    
                    -- 3) building_or_converter check
                    if allRequiredUnlocked and building.required_building_or_converter then
                        for reqId, reqCount in pairs(building.required_building_or_converter) do
                            local owned = # (globals.buildings[reqId] or {})
                            if owned < reqCount then
                                allRequiredUnlocked = false
                                break
                            end
                        end
                    end

            
                    -- 3) if status flipped, show popup
                    if wasUnlocked ~= allRequiredUnlocked then
                        debug("Building ", building.id,
                              " unlocked status changed to: ", allRequiredUnlocked)
                        if allRequiredUnlocked then
                            newTextPopup(
                                localization.get(
                                    "ui.new_unlock",
                                    { unlock = localization.get(building.ui_text_title) }
                                ),
                                globals.screenWidth() / 2,
                                globals.screenHeight() / 2 + yLocationIncrement,
                                4
                            )
                            timer.after(
                                0.1, 
                                function()
                                    local pitch = random_utils.random_float(0.8, 1.2)
                                    playSoundEffect("effects", "new-unlock", pitch)
                                end
                            )
                            yLocationIncrement = yLocationIncrement + 30 -- increment the y location for the next popup
                            
                            -- reset the building UI to the first building
                            cycleBuilding(0) -- reset the building UI to the first building
                        end
                    end
            
                    -- 4) store new state
                    building.unlocked = allRequiredUnlocked
                end
            end
            
            -- now do the same for converters
            for i, conv in ipairs(globals.converter_defs) do
                local wasUnlocked = conv.unlocked

                -- only test those still locked and with requirements
                if not conv.unlocked then
                    local allReqsOK = true

                    -- 1) building-dependency check
                    for _, bId in ipairs(conv.required_building) do
                        local b = findInTable(globals.building_upgrade_defs, "id", bId)
                        if not b or not b.unlocked then
                            allReqsOK = false
                            break
                        end
                    end

                    -- 2) converter-dependency check (only if buildings passed)
                    if allReqsOK and conv.required_converter then
                        for _, cId in ipairs(conv.required_converter) do
                            local c = findInTable(globals.converter_defs, "id", cId)
                            if not c or not c.unlocked then
                                allReqsOK = false
                                break
                            end
                        end
                    end
                    
                    -- 3) building_or_converter check
                    if allReqsOK and conv.required_building_or_converter then
                        for reqId, reqCount in pairs(conv.required_building_or_converter) do
                            local owned = # (globals.converters[reqId] or {})
                            if owned < reqCount then
                                allReqsOK = false
                                break
                            end
                        end
                    end


                    -- 3) currency check (only if all deps passed)
                    if allReqsOK and conv.required_currencies then
                        for key, amount in pairs(conv.required_currencies) do
                            local have = globals.currencies[key].target or 0
                            if have < amount then
                                allReqsOK = false
                                break
                            end
                        end
                    end

                    -- 4) flip-detect and popup
                    if wasUnlocked ~= allReqsOK then
                        debug("Converter ", conv.id,
                            " unlocked status changed to: ", allReqsOK)
                        if allReqsOK then
                            newTextPopup(
                                localization.get(
                                    "ui.new_unlock",
                                    { unlock = localization.get(conv.ui_text_title) }
                                ),
                                globals.screenWidth() / 2,
                                globals.screenHeight() / 2 + yLocationIncrement,
                                4
                            )
                            timer.after(
                                0.1, 
                                function()
                                    local pitch = random_utils.random_float(0.8, 1.2)
                                    playSoundEffect("effects", "new-unlock", pitch)
                                end
                            )
                            yLocationIncrement = yLocationIncrement + 30
                            cycleConverter(0) -- reset the converter UI to the first converter
                        end
                    end

                    -- 5) store new state
                    conv.unlocked = allReqsOK
                end
            end
        end,
        0,-- repeat forever,
        false,-- run immediately
        nil,
        "building_unlock_check" -- timer name
    )
      
    globals.selectedBuildingIndex = 1 -- the index of the currently selected building in the upgrade list
    
    -- "left" button
    local leftButtonText = ui.definitions.getNewDynamicTextEntry(
        "<",  -- initial text
        20.0,                                 -- font size
        nil,                                  -- no style override
        "pulse=0.9,1.1"                       -- animation spec
    )
    -- make new button template
    local leftButtonTemplate = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("lapi_lazuli"))
            -- :addShadow(true)
            :addEmboss(4.0)
            :addHover(true) -- needed for button effect
            :addButtonCallback(function()
                playSoundEffect("effects", "button-click") -- play button click sound
                cycleBuilding(-1) -- decrement the selected building index
                -- debug("Left button clicked! Current building index: ", globals.selectedBuildingIndex)
            end)
            :addAlign(AlignmentFlag.HORIZONTAL_LEFT | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(leftButtonText)
    :build()
    
    -- middle text 
    --TODO: customize this based on update data
    globals.building_ui_animation_entity = animation_system.createAnimatedObjectWithTransform(
        globals.building_upgrade_defs[1].anim, -- animation ID
        false             -- use animation, not sprite id
    )
    local middleTextElement = ui.definitions.wrapEntityInsideObjectElement(globals.building_ui_animation_entity) -- wrap the text in an object element
    cycleBuilding(0) -- initialize the building UI with the first building
    
    -- make animatino hoverable
    local buildingUIAnimGameObject = registry:get(globals.building_ui_animation_entity, GameObject)
    buildingUIAnimGameObject.state.dragEnabled = false
    buildingUIAnimGameObject.state.hoverEnabled = true
    buildingUIAnimGameObject.state.clickEnabled = false
    buildingUIAnimGameObject.state.collisionEnabled = true
    
    
    
    -- right button
    local rightButtonText = ui.definitions.getNewDynamicTextEntry(
        ">",  -- initial text
        20.0,                                 -- font size
        nil,                                  -- no style override
        "pulse=0.9,1.1"                       -- animation spec
    )
    -- make new button template
    local rightButtonTemplate = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("lapi_lazuli"))
            -- :addShadow(true)
            :addEmboss(4.0)
            :addHover(true) -- needed for button effect
            :addButtonCallback(function()
                playSoundEffect("effects", "button-click") -- play button click sound
                cycleBuilding(1) -- increment the selected building index
            end)
            :addAlign(AlignmentFlag.HORIZONTAL_RIGHT | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(rightButtonText)
    :build()
    
    
    -- buy button
    local buyButtonText = ui.definitions.getNewDynamicTextEntry(
        localization.get("ui.buy_button"),  -- initial text
        20.0,                                 -- font size
        nil,                                  -- no style override
        "rainbow"                       -- animation spec
    )
    -- make new button template
    local buyButtonTemplate = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("lapi_lazuli"))
            -- :addShadow(true)
            :addEmboss(4.0)
            :addHover(true) -- needed for button effect
            :addButtonCallback(function()
                playSoundEffect("effects", "button-click") -- play button click sound
                buyBuildingButtonCallback()
            end)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(buyButtonText)
    :build()
    
    
    -- second upgrade ui (converters)
    
    globals.converter_ui_animation_entity = nil
    
    globals.selectedConverterIndex = 1 -- the index of the currently selected building in the upgrade list
    
    -- "left" button
    local leftButtonTextConverter = ui.definitions.getNewDynamicTextEntry(
        "<",  -- initial text
        20.0,                                 -- font size
        nil,                                  -- no style override
        "pulse=0.9,1.1"                       -- animation spec
    )
    -- make new button template
    local leftButtonTemplateConverter = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("lapi_lazuli"))
            -- :addShadow(true)
            :addEmboss(4.0)
            :addHover(true) -- needed for button effect
            :addButtonCallback(function()
                playSoundEffect("effects", "button-click") -- play button click sound
                cycleConverter(-1)
            end)
            :addAlign(AlignmentFlag.HORIZONTAL_LEFT | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(leftButtonTextConverter)
    :build()
    
    -- middle text 
    --TODO: customize this based on update data
    globals.converter_ui_animation_entity = animation_system.createAnimatedObjectWithTransform(
        "locked_upgrade_anim", -- animation ID
        false             -- use animation, not sprite id
    )
    
    -- make globals.converter_ui_animation_entity hoverable
    local converterGameObject = registry:get(globals.converter_ui_animation_entity, GameObject)
    converterGameObject.state.dragEnabled = false
    converterGameObject.state.clickEnabled = false
    converterGameObject.state.hoverEnabled = true
    converterGameObject.state.collisionEnabled = true
    
    local middleTextElementConverter = ui.definitions.wrapEntityInsideObjectElement(globals.converter_ui_animation_entity) -- wrap the text in an object element
    
    cycleConverter(0) -- cycle to the first converter
    
    
    -- right button
    local rightButtonTextConverter = ui.definitions.getNewDynamicTextEntry(
        ">",  -- initial text
        20.0,                                 -- font size
        nil,                                  -- no style override
        "pulse=0.9,1.1"                       -- animation spec
    )
    -- make new button template
    local rightButtonTemplateConverter = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("lapi_lazuli"))
            -- :addShadow(true)
            :addEmboss(4.0)
            :addHover(true) -- needed for button effect
            :addButtonCallback(function()
                -- button click callback
                playSoundEffect("effects", "button-click") -- play button click sound
                debug("Right button clicked!")
                cycleConverter(1)
            end)
            :addAlign(AlignmentFlag.HORIZONTAL_RIGHT | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(rightButtonTextConverter)
    :build()
    
    
    -- buy button
    local buyButtonTextConverter = ui.definitions.getNewDynamicTextEntry(
        localization.get("ui.buy_button"),  -- initial text
        20.0,                                 -- font size
        nil,                                  -- no style override
        "rainbow"                       -- animation spec
    )
    -- make new button template
    local buyButtonTemplateConverter = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("lapi_lazuli"))
            -- :addShadow(true)
            :addEmboss(4.0)
            :addHover(true) -- needed for button effect
            :addButtonCallback(function()
                -- button click callback
                playSoundEffect("effects", "button-click") -- play button click sound
                debug("Buy button clicked!")
                
                buyConverterButtonCallback()
                
            end)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(buyButtonTextConverter)
    :build()

    -- make a horizontal container for all upgrade ui
    local upgradeUIContainer = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("keppel"))
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(leftButtonTemplate)
    :addChild(middleTextElement)
    :addChild(rightButtonTemplate)
    :addChild(buyButtonTemplate)
    :addChild(leftButtonTemplateConverter)
    :addChild(middleTextElementConverter)
    :addChild(rightButtonTemplateConverter)
    :addChild(buyButtonTemplateConverter)
    :build()
    
    -- make a new upgrade UI root
    local upgradeUIRoot =  UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.ROOT)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("lapi_lazuli"))
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(upgradeUIContainer)
    :build()
    
    -- create a new UI box for the upgrade UI
    globals.ui.upgradeUIBox = ui.box.Initialize({x = 0, y = globals.screenHeight() - 50}, upgradeUIRoot)
    
    -- align the upgrade UI box to the bottom of the screen
    local upgradeUIBoxTransform = registry:get(globals.ui.upgradeUIBox, Transform)
    upgradeUIBoxTransform.actualX = globals.screenWidth() / 2 - upgradeUIBoxTransform.actualW / 2 -- center it horizontally
    upgradeUIBoxTransform.actualY = globals.screenHeight() - upgradeUIBoxTransform.actualH -- align to the bottom of the screen
    
    
    
    -- new achivement window
    local newAchievementText = ui.definitions.getNewDynamicTextEntry(
        localization.get("ui.new_achievement_title"),  -- initial text
        20.0,                                 -- font size
        nil,                                  -- no style override
        "rainbow"                       -- animation spec
    )
    
    -- make new animated entity
    globals.achievementIconEntity = animation_system.createAnimatedObjectWithTransform(
        "locked_anim", -- animation ID
        false             -- use animation, not sprite id
    )
    -- resize
    animation_system.resizeAnimationObjectsInEntityToFit(
        globals.achievementIconEntity,
        60,
        60
    )
    -- wrap the animated entity in an object element
    local newAchievementAnimDef = ui.definitions.wrapEntityInsideObjectElement(globals.achievementIconEntity)
    
    -- make a new horizontal container for the new achievement text
    local newAchievementAnimContainer = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("lapi_lazuli"))
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)        
            :build()
    )
    :addChild(newAchievementAnimDef) -- add the achievement icon
    :build()
    
    
    -- make a new root for the new achievement text
    local newAchievementTextRoot =  UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.ROOT)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("keppel"))
            :addMinHeight(50)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()        
    )
    :addChild(newAchievementText)
    :addChild(newAchievementAnimContainer)
    :build()
    
    -- create a new UI box for the new achievement text
    globals.ui.newAchievementUIBox = ui.box.Initialize({x = 0, y = globals.screenHeight() + 400}, newAchievementTextRoot)   
    
    
    
    
    -- tooltip ui box that will follow the mouse cursor
    local tooltipTitleText = ui.definitions.getNewDynamicTextEntry(
        localization.get("sample tooltip title"),  -- initial text
        18.0,                                 -- font size
        nil,                                  -- no style override
        "rainbow"                       -- animation spec
    )
    globals.ui.tooltipTitleText = tooltipTitleText.config.object
    local tooltipBodyText = ui.definitions.getNewDynamicTextEntry(
        localization.get("Sample tooltip body text"),  -- initial text
        15.0,                                 -- font size
        nil,                                  -- no style override
        "fade"                       -- animation spec
    )
    globals.ui.tooltipBodyText = tooltipBodyText.config.object
    
    -- make vertical container for the tooltip
    local tooltipContainer = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.VERTICAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("lapi_lazuli"))
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
            :addColor(util.getColor("keppel"))
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
