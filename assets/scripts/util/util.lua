local task = require("task/task")

-- Wraps v into the interval [−size, limit]
function wrap(v, size, limit)
  if v > limit then return -size end
  if v < -size then return limit end
  return v
end

-- Recursively prints any table (with cycle detection)
function print_table(tbl, indent, seen)
  indent = indent or "" -- current indentation
  seen   = seen or {}   -- tables we’ve already visited

  if seen[tbl] then
    print(indent .. "*<recursion>–") -- cycle detected
    return
  end
  seen[tbl] = true

  -- iterate all entries
  for k, v in pairs(tbl) do
    local key = type(k) == "string" and ("%q"):format(k) or tostring(k)
    if type(v) == "table" then
      print(indent .. "[" .. key .. "] = {")
      print_table(v, indent .. "  ", seen)
      print(indent .. "}")
    else
      -- primitive: just tostring it
      print(indent .. "[" .. key .. "] = " .. tostring(v))
    end
  end
end

-- convenience wrapper
function dump(t)
  assert(type(t) == "table", "dump expects a table")
  print_table(t)
end

-- somewhere in your init.lua, before loading ai.entity_types…
function deep_copy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == "table" then
    copy = {}
    for k, v in pairs(orig) do
      copy[deep_copy(k)] = deep_copy(v)
    end
    setmetatable(copy, deep_copy(getmetatable(orig)))
  else
    copy = orig
  end
  return copy
end


-- utility clamp if you don't already have one
local function clamp(val, min, max)
  if val < min then return min end
  if val > max then return max end
  return val
end


function buyRelicFromSlot(slot)
  -- make sure slot doesn't exceed the number of slots
  if slot < 1 or slot > #globals.currentShopSlots then
    log_debug("buyRelicFromSlot: Invalid slot number: ", slot)
    return
  end
  
  -- create animation entity, add it to the top ui box
  local currentID = globals.currentShopSlots[slot].id
  
  local relicDef = findInTable(globals.relicDefs, "id", currentID)
  
  if not relicDef then
    log_debug("buyRelicFromSlot: No relic definition found for ID: ", currentID)
    return
  end
  
  -- check if the player has enough currency
  if globals.currency < relicDef.costToBuy then
    log_debug("buyRelicFromSlot: Not enough currency to buy relic: ", currentID)
    
    playSoundEffect("effects", "cannot-buy") -- play button click sound
    newTextPopup(
      localization.get("ui.not_enough_currency"),
      globals.screenWidth() / 2,
      globals.screenHeight() / 4,
      5, -- duration in seconds
      "color=fiery_red" -- effect string
    )
    return
  end
  
  playSoundEffect("effects", "shop-buy") -- play button click sound
  
  -- deduct the cost from the player's currency
  globals.currency = globals.currency - relicDef.costToBuy
  log_debug("buyRelicFromSlot: Bought relic: ", currentID, " for ", relicDef.costToBuy, " currency. Remaining currency: ", globals.currency)
  
  -- create the animation entity for the relic
  local relicAnimationEntity = animation_system.createAnimatedObjectWithTransform(
    relicDef.spriteID, -- sprite ID for the relic
    true               -- use animation, not sprite identifier, if false
  )
  
  -- animation_system.resizeAnimationObjectsInEntityToFit(
  --   relicAnimationEntity,
  --   globals.tileSize, -- width
  --   globals.tileSize  -- height
  -- )
  
  -- add hover tooltip
  local gameObject = registry:get(relicAnimationEntity, GameObject)
  gameObject.methods.onHover = function()
    log_debug("Relic hovered: ", relicDef.id)
    showTooltip(
      localization.get(relicDef.localizationKeyName),
      localization.get(relicDef.localizationKeyDesc)
    )
  end
  gameObject.state.hoverEnabled = true
  gameObject.state.collisionEnabled = true
  
  
  -- wrap the animation entity 
  local uie = ui.definitions.wrapEntityInsideObjectElement(
    relicAnimationEntity -- entity to wrap
  )
  
  -- make new ui row
  local uieRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
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
        -- add all relic button defs to the row
        :addChild(uie)
        :build()
  
  globals.ui.relicsUIElementRow = ui.box.GetUIEByID(registry, globals.ui.relicsUIBox, "relics_row")
  log_debug("buyRelicFromSlot: Wrapped entity inside UI element row: ", globals.ui.relicsUIElementRow)
  
  --TODO: add to top bar and renew alignment
  -- local gameobjectCompTopBar = registry:get(globals.ui.relicsUIElementRow, GameObject)
  -- gameobjectCompTopBar.orderedChildren:add(uie) -- add the wrapped entity to the top bar UI element row
  
  --TODO: document that AddTemplateToUIBox must take a row
  ui.box.AddTemplateToUIBox(
    registry,
    globals.ui.relicsUIBox,
    uieRow, -- def to add
    globals.ui.relicsUIElementRow -- parent UI element row to add to
  )
  
  ui.box.RenewAlignment(registry, globals.ui.relicsUIBox) -- re-align the relics UI element row
  
  -- add to the ownedRelics, run the onBuyCallback
  
  table.insert(globals.ownedRelics, {
    id = relicDef.id,
    entity = uie
  })
  -- log_debug("buyRelicFromSlot: Added relic to ownedRelics: ", lume.serialize(globals.ownedRelics))
  
  if relicDef.onBuyCallback then
    relicDef.onBuyCallback() -- run the onBuyCallback if it exists
  end
end

function handleNewDay()
  
  -- every 3 days, we have a weather event 
  globals.timeUntilNextWeatherEvent = globals.timeUntilNextWeatherEvent + 1
  if globals.timeUntilNextWeatherEvent >= 1 then
    globals.timeUntilNextWeatherEvent = 0 -- reset the timer
    -- trigger a weather event
    globals.current_weather_event = globals.weather_event_defs[math.random(1, #globals.weather_event_defs)].id -- pick a random weather event
    
    -- increment the base damage of the weather event
    globals.current_weather_event_base_damage = globals.current_weather_event_base_damage * 2
  end
  
  playSoundEffect("effects", "end-of-day") -- play button click sound
  
  -- select 3 random items for the shop.
  
  lume.clear(globals.currentShopSlots) -- clear the current shop slots
  
  globals.currentShopSlots[1] = { id = lume.randomchoice(globals.relicDefs).id}
  globals.currentShopSlots[2] = { id = lume.randomchoice(globals.relicDefs).id}
  globals.currentShopSlots[3] = { id = lume.randomchoice(globals.relicDefs).id}
  
  log_debug("Current shop slots: ", lume.serialize(globals.currentShopSlots))
  
  --TODO: now populate the shop ui
  
  -- relic1ButtonAnimationEntity
  
  local relicDef = findInTable(globals.relicDefs, "id", globals.currentShopSlots[1].id)
  
  animation_system.replaceAnimatedObjectOnEntity(
    globals.ui["relic1ButtonAnimationEntity"],
    relicDef.spriteID, -- Default animation ID
    true,               -- ? generate a new still animation from sprite, don't set to true, causes bug
    nil,                 -- shader_prepass, -- Optional shader pass config function
    true                 -- Enable shadow
  )
  animation_system.resizeAnimationObjectsInEntityToFit(
    globals.ui["relic1ButtonAnimationEntity"],
    globals.tileSize, -- width
    globals.tileSize  -- height
  )
  
  -- relic1TextEntity
  log_debug("Setting text for relic1TextEntity to: ", localization.get(relicDef.localizationKeyName), "with key: ", relicDef.localizationKeyName)
  TextSystem.Functions.setText(globals.ui["relic1TextEntity"], localization.get(relicDef.localizationKeyName))
  
  -- relic1CostTextEntity
  local costText = "".. relicDef.costToBuy
  TextSystem.Functions.setText(globals.ui["relic1CostTextEntity"], costText)
  
  -- fetch ui element
  local uiElement1 = ui.box.GetUIEByID(registry, globals.ui.weatherShopUIBox, "relic1UIElement")
  
  -- add hover 
  local gameObject1 = registry:get(uiElement1, GameObject)
  local relicDef1 = relicDef
  gameObject1.methods.onHover = function()
    log_debug("Relic 1 hovered!")
    showTooltip(
      localization.get(relicDef1.localizationKeyName),
      localization.get(relicDef1.localizationKeyDesc)
    )
  end
  
  -- add button callback
  local uieUIConfig1 = registry:get(uiElement1, UIConfig)
  -- enable button
  uieUIConfig1.disable_button = false -- enable the button
  uieUIConfig1.buttonCallback = function()
    log_debug("Relic 1 button clicked!")
    buyRelicFromSlot(1) -- buy the relic from slot 1
    -- disable the button
    local uiConfig = registry:get(uiElement1, UIConfig)
    uiConfig.disable_button = true -- disable the button
  end
  -- relic2ButtonAnimationEntity
  relicDef = findInTable(globals.relicDefs, "id", globals.currentShopSlots[2].id)
  animation_system.replaceAnimatedObjectOnEntity(
    globals.ui["relic2ButtonAnimationEntity"],
    relicDef.spriteID, -- Default animation ID
    true,               -- ? generate a new still animation from sprite, don't set to true, causes bug
    nil,                 -- shader_prepass, -- Optional shader pass config function
    true                 -- Enable shadow
  )
  animation_system.resizeAnimationObjectsInEntityToFit(
    globals.ui["relic2ButtonAnimationEntity"],
    globals.tileSize, -- width
    globals.tileSize  -- height
  )
  -- relic2TextEntity
  log_debug("Setting text for relic2TextEntity to: ", localization.get(relicDef.localizationKeyName), "with key: ", relicDef.localizationKeyName)
  TextSystem.Functions.setText(globals.ui["relic2TextEntity"], localization.get(relicDef.localizationKeyName))
  
  -- relic2CostTextEntity
  local costText = "".. relicDef.costToBuy
  TextSystem.Functions.setText(globals.ui["relic2CostTextEntity"], costText)
  -- fetch ui element
  
  local uiElement2 = ui.box.GetUIEByID(registry, globals.ui.weatherShopUIBox, "relic2UIElement")
  -- add hover
  local gameObject2 = registry:get(uiElement2, GameObject)
  local relicDef2 = relicDef
  gameObject2.methods.onHover = function()
    log_debug("Relic 2 hovered!")
    showTooltip(
      localization.get(relicDef2.localizationKeyName),
      localization.get(relicDef2.localizationKeyDesc)
    )
  end
  
  -- enable button
  -- add button callback
  local uieUIConfig2 = registry:get(uiElement2, UIConfig)
  uieUIConfig2.disable_button = false -- enable the button
  uieUIConfig2.buttonCallback = function()
    log_debug("Relic 2 button clicked!")
    buyRelicFromSlot(2) -- buy the relic from slot 2
    -- disable the button
    local uiConfig = registry:get(uiElement2, UIConfig)
    uiConfig.disable_button = true -- disable the button
  end
  -- relic3ButtonAnimationEntity
  relicDef = findInTable(globals.relicDefs, "id", globals.currentShopSlots[3].id)
  animation_system.replaceAnimatedObjectOnEntity(
    globals.ui["relic3ButtonAnimationEntity"],
    relicDef.spriteID, -- Default animation ID
    true,               -- ? generate a new still animation from sprite, don't set to true, causes bug
    nil,                 -- shader_prepass, -- Optional shader pass config function
    true                 -- Enable shadow
  )
  animation_system.resizeAnimationObjectsInEntityToFit(
    globals.ui["relic3ButtonAnimationEntity"],
    globals.tileSize, -- width
    globals.tileSize  -- height
  )
  -- relic3TextEntity
  log_debug("Setting text for relic3TextEntity to: ", localization.get(relicDef.localizationKeyName), "with key: ", relicDef.localizationKeyName)
  TextSystem.Functions.setText(globals.ui["relic3TextEntity"], localization.get(relicDef.localizationKeyName))
  
  -- relic3CostTextEntity
  local costText = "".. relicDef.costToBuy
  TextSystem.Functions.setText(globals.ui["relic3CostTextEntity"], costText)
  -- fetch ui element
  local uiElement3 = ui.box.GetUIEByID(registry, globals.ui.weatherShopUIBox, "relic3UIElement")
  -- add hover
  local gameObject3 = registry:get(uiElement3, GameObject)
  local relicDef3 = relicDef
  gameObject3.methods.onHover = function()
    log_debug("Relic 3 hovered!")
    showTooltip(
      localization.get(relicDef3.localizationKeyName),
      localization.get(relicDef3.localizationKeyDesc)
    )
  end
  -- add button callback
  local uieUIConfig3 = registry:get(uiElement3, UIConfig)
  uieUIConfig3.disable_button = false -- enable the button
  uieUIConfig3.buttonCallback = function()
    log_debug("Relic 3 button clicked!")
    buyRelicFromSlot(3) -- buy the relic from slot 3
    -- disable the button
    local uiConfig = registry:get(uiElement3, UIConfig)
    uiConfig.disable_button = true -- disable the button
  end
  ui.box.RenewAlignment(registry, globals.ui.weatherShopUIBox) -- re-align the shop UI box
  
  -- update shop uiboxTransform to centered
  local shopUIBoxTransform = registry:get(globals.ui.weatherShopUIBox, Transform)
  shopUIBoxTransform.actualX = globals.screenWidth() / 2 - shopUIBoxTransform.actualW / 2
  shopUIBoxTransform.visualX = shopUIBoxTransform.actualX -- snap X
  shopUIBoxTransform.actualY = globals.screenHeight() / 2 - shopUIBoxTransform.actualH / 2
  shopUIBoxTransform.visualY = shopUIBoxTransform.actualY -- snap Y
  -- refer to this:
  
--   local relicSlots = {
--     {id = "relic1", spriteID = "4165-TheRoguelike_1_10_alpha_958.png", text = "ui.relic_slot_1", animHandle = "relic1ButtonAnimationEntity", textHandle = "relic1TextEntity"},
--     {id = "relic2", spriteID = "4169-TheRoguelike_1_10_alpha_962.png", text = "ui.relic_slot_2", animHandle = "relic2ButtonAnimationEntity", textHandle = "relic2TextEntity"},
--     {id = "relic3", spriteID = "4054-TheRoguelike_1_10_alpha_847.png", text = "ui.relic_slot_3", animHandle = "relic3ButtonAnimationEntity", textHandle = "relic3TextEntity"},
-- }

-- local weatherButtonDefs = {}

-- -- populate weatherButtonDefs based on weatherEvents
-- for _, event in ipairs(relicSlots) do

--     -- TODO: so these are stored under globals.ui["relic1TextEntity"] globals.ui["relic1ButtonAnimationEntity"] and so on, we will access these later
--     local buttonDef = createStructurePlacementButton(
--         event.spriteID, -- sprite ID for the weather event
--         event.animHandle, -- global animation handle
--         event.textHandle, -- global text handle
--         event.text, -- localization key for text
--         event.cost -- cost to buy the weather event
--     )
--     -- add buttonDef to weatherButtonDefs
--     table.insert(weatherButtonDefs, buttonDef)
-- end
  
  
  timer.after(
    1.0, -- delay in seconds
    function()
      -- set hours and minutes to 0
      globals.game_time.hours = 0
      globals.game_time.minutes = 0
      ai.pause_ai_system()   -- pause the AI system
      togglePausedState(true)
      -- show the new day message
      if registry:valid(globals.ui.newDayUIBox) then
        local shopTransform = registry:get(globals.ui.weatherShopUIBox, Transform)
        
        local transformComp = registry:get(globals.ui.newDayUIBox, Transform)
        transformComp.actualY = globals.screenHeight() / 2 - shopTransform.actualH / 2 - transformComp.actualH  * 2 -- show above the shop UI box
        -- cneter x
        transformComp.actualX = globals.screenWidth() / 2 - transformComp.actualW / 2
        transformComp.visualX = transformComp.actualX -- snap X
      end
      
      -- for each healer & damage cushion, detract currency and show text popup
      for _, healerEntry in ipairs(globals.healers) do
        
        local transformComp = registry:get(healerEntry, Transform)
        local healerDef = findInTable(globals.creature_defs, "id", "healer")
        local maintenance_cost = healerDef.maintenance_cost
        
        -- show text popup at the location of the healer
        newTextPopup(
          "-"..maintenance_cost,
          transformComp.actualX + transformComp.actualW / 2,
          transformComp.actualY + transformComp.actualH / 2,
          4.0, -- duration in seconds
          "color=fiery_red;slide" -- effect string
        )
        
        --- detract the currency from the player's resources
        globals.currency = globals.currency - maintenance_cost
      end
      
      for _, damageCushionEntry in ipairs(globals.damage_cushions) do
        
        local transformComp = registry:get(damageCushionEntry, Transform)
        local damageCushionDef = findInTable(globals.creature_defs, "id", "damage_cushion")
        local maintenance_cost = damageCushionDef.maintenance_cost
        
        -- show text popup at the location of the damage cushion
        newTextPopup(
          "-"..maintenance_cost,
          transformComp.actualX + transformComp.actualW / 2,
          transformComp.actualY + transformComp.actualH / 2,
          4.0, -- duration in seconds
          "color=fiery_red;slide" -- effect string
        )
        
        --- detract the currency from the player's resources
        globals.currency = globals.currency - maintenance_cost
      end
      
      -- for each colonist home, add a coin image to the location, tween it to the currency ui, then vanish it. Then add the currency to the player's resources
      for _, colonistHomeEntry in ipairs(globals.structures.colonist_homes) do
        
        -- add a coin image to the location of the colonist home
        local coinImage = animation_system.createAnimatedObjectWithTransform(
          "4024-TheRoguelike_1_10_alpha_817.png", -- animation ID
          true             -- use animation, not sprite identifier, if false
        )
        animation_system.resizeAnimationObjectsInEntityToFit(
          coinImage,
            globals.tileSize,   -- width
            globals.tileSize    -- height
        )
        
        playSoundEffect("effects", "gold-gain") -- play coin sound effect
        
        local coinTansformComp = registry:get(coinImage, Transform)
        
        -- text popup at the location of the colonist home
        newTextPopup(
          "+"..math.floor(findInTable(
            globals.structure_defs,
            "id",
            "colonist_home"
          ).currency_per_day * globals.end_of_day_gold_multiplier),
          coinTansformComp.actualX * globals.tileSize + globals.tileSize / 2,
          coinTansformComp.actualY * globals.tileSize + globals.tileSize / 2,
          1.0, -- duration in seconds
          "color=marigold" -- effect string
        )
        
        local transformComp = registry:get(coinImage, Transform)
        local t = registry:get(colonistHomeEntry.entity, Transform)
        -- align above the home
        transformComp.actualX = t.actualX + t.actualW / 2 - transformComp.actualW / 2
        transformComp.actualY = t.actualY - transformComp.actualH / 2 - 5
        transformComp.visualX = transformComp.actualX -- snap X
        transformComp.visualY = transformComp.actualY -- snap Y
        
        -- spawn particles at the center of the coin image
        spawnCircularBurstParticles(
          transformComp.actualX + transformComp.actualW / 2,
          transformComp.actualY + transformComp.actualH / 2,
          10, -- number of particles
          0.3 -- particle size
        )
        
        timer.after(
          1.1,
          function()
            playSoundEffect("effects", "money-to-cash-pile") -- play coin sound effect
            if not registry:valid(coinImage) then
              log_debug("Coin image entity is not valid, skipping tweening")
              return
            end
            
            
            -- tween the coin image to the currency UI box
            local uiBoxTransform = registry:get(globals.ui.currencyUIBox, Transform)
            local transformComp = registry:get(coinImage, Transform)
            transformComp.actualX = uiBoxTransform.actualX + uiBoxTransform.actualW / 2 - transformComp.actualW / 2
            transformComp.actualY = uiBoxTransform.actualY + uiBoxTransform.actualH / 2 - transformComp.actualH / 2
            
            
            
          end
        )
        
        -- delete it after 0.5 seconds
        timer.after(
          2.2, -- delay in seconds
          function()
            if registry:valid(coinImage) then
              registry:destroy(coinImage) -- remove the coin image entity
            end
            -- add the currency to the player's resources
            globals.currency = globals.currency + math.floor(findInTable(
              globals.structure_defs,
              "id",
              "colonist_home"
            ).currency_per_day * globals.end_of_day_gold_multiplier) -- add the currency per day for the colonist home
          end
        )
      end

      -- after 1 second, hide the new day message and show the shop menu
      timer.after(
        3.6,     -- delay in seconds
        function()
          if registry:valid(globals.ui.newDayUIBox) then
            local transformComp = registry:get(globals.ui.newDayUIBox, Transform)
            transformComp.actualY = globals.screenHeight()
            -- center x
            transformComp.actualX = globals.screenWidth() / 2 - transformComp.actualW / 2
            transformComp.visualX = transformComp.actualX -- snap X
          end

          toggleShopWindow()       -- toggle the shop window
        end
      )
    end
  )
end

-- Conveniene function to drive your tooltip
function showTooltip(titleText, bodyText)
  local titleEnt = globals.ui.tooltipTitleText
  local bodyEnt  = globals.ui.tooltipBodyText
  local boxEnt   = globals.ui.tooltipUIBox

  if not titleEnt or not bodyEnt or not boxEnt then
    error("showTooltip: Tooltip entities are not set up correctly!")
    return
  end

  -- 1) set the texts

  TextSystem.Functions.setText(titleEnt, titleText)
  TextSystem.Functions.clearAllEffects(titleEnt)            -- clear any previous effects
  TextSystem.Functions.applyGlobalEffects(titleEnt, "slide;color=plum") -- apply the tooltip title effects
  TextSystem.Functions.setText(bodyEnt, bodyText)
  TextSystem.Functions.applyGlobalEffects(bodyEnt, "color=blue_midnight") -- apply the tooltip body effects

  -- 2) re-calc the box layout to fit new text
  ui.box.RenewAlignment(registry, boxEnt)

  -- 3) grab transforms & dims
  local mouseT           = registry:get(globals.cursor(), Transform)
  local boxT             = registry:get(boxEnt, Transform)

  local screenW, screenH = globals.screenWidth(), globals.screenHeight()

  -- fallback if UIBox doesn’t carry dims
  local w                = boxT.actualW
  local h                = boxT.actualH

  -- 4) position with offset
  local x                = mouseT.actualX + 20
  local y                = mouseT.actualY + 20

  -- 5) clamp to screen bounds
  boxT.actualX           = clamp(x, 0, screenW - w)
  boxT.visualX           = boxT.actualX
  boxT.actualY           = clamp(y, 0, screenH - h)
  boxT.visualY           = boxT.actualY

  -- 6) hard set size
  boxT.visualW           = boxT.actualW
  boxT.visualH           = boxT.actualH
end

function toggleShopWindow()
  if (globals.isShopOpen) then
    globals.isShopOpen = false
    local transform = registry:get(globals.ui.weatherShopUIBox, Transform)
    transform.actualY = globals.screenHeight() -- hide the shop UI box
  else
    globals.isShopOpen = true
    local transform = registry:get(globals.ui.weatherShopUIBox, Transform)
    transform.actualY = globals.screenHeight() / 2 - transform.actualH / 2 -- show the shop UI box
  end
  local transform = registry:get(globals.ui.weatherShopUIBox, Transform)
  -- center x
  transform.actualX = globals.screenWidth() / 2 - transform.actualW / 2
  transform.visualX = transform.actualX -- snap X
end

function showNewAchievementPopup(achievementID)
  if not globals.ui.newAchievementUIBox then
    log_debug("showNewAchievementPopup: newAchievementUIBox is not set up, skipping")
    return
  end

  -- get the achievement definition
  local achievementDef = findInTable(globals.achievements, "id", achievementID)

  -- replace the animation
  animation_system.replaceAnimatedObjectOnEntity(
    globals.ui.achievementIconEntity,
    achievementDef.anim, -- Default animation ID
    false,               -- ? generate a new still animation from sprite, don't set to true, causes bug
    nil,                 -- shader_prepass, -- Optional shader pass config function
    true                 -- Enable shadow
  )
  animation_system.resizeAnimationObjectsInEntityToFit(
    globals.ui.achievementIconEntity,
    60, -- width
    60  -- height
  )

  -- set tooltip
  local gameObject = registry:get(globals.ui.achievementIconEntity, GameObject)
  gameObject.methods.onHover = function()
    achievementDef.tooltipFunc()
  end
  -- gameObject.methods.onStopHover = function()
  --   hideTooltip()
  -- end
  gameObject.state.hoverEnabled = true
  gameObject.state.collisionEnabled = true

  -- renew the alignment of the achievement UI box
  -- ui.box.RenewAlignment(registry, globals.ui.newAchievementUIBox)

  -- play sound
  playSoundEffect("effects", "new_achievement")

  -- if not already at bottom of the screen, move it to the center
  local transformComp = registry:get(globals.ui.newAchievementUIBox, Transform)
  transformComp.actualX = globals.screenWidth() / 2 - transformComp.actualW / 2
  transformComp.visualX = transformComp.actualX -- snap X
  transformComp.actualY = globals.screenHeight() / 2 - transformComp.actualH / 2


  -- spawn particles at the center of the box
  spawnCircularBurstParticles(
    transformComp.actualX + transformComp.actualW / 2,
    transformComp.actualY + transformComp.actualH / 2,
    40, -- number of particles
    0.5 -- particle size
  )

  -- dismiss after 5 seconds
  timer.after(
    5.0, -- delay in seconds
    function()
      log_debug("Dismissing achievement popup: ", achievementID)
      -- move the box out of the screen
      local transformComp = registry:get(globals.ui.newAchievementUIBox, Transform)
      transformComp.actualY = globals.screenHeight() + 500
    end,
    "dismiss_achievement_popup" -- timer name
  )
end

function centerTransformOnScreen(entity)
  -- center the transform of the entity on the screen
  local transformComp = registry:get(entity, Transform)
  transformComp.actualX = globals.screenWidth() / 2 - transformComp.actualW / 2
  transformComp.visualX = transformComp.actualX -- snap X
  transformComp.actualY = globals.screenHeight() / 2 - transformComp.actualH / 2
  transformComp.visualY = transformComp.actualY -- snap Y
end

function newTextPopup(textString, x, y, duration, effectString)
  -- 1) spawn the dynamic text entry
  local entry = ui.definitions.getNewDynamicTextEntry(
    function() return textString end,  -- initial text
    30.0,                              -- font size
    effectString or ""                          -- animation spec
  )
  local entity = entry.config.object

  -- 2) fetch its transform and its size (set by the text system)
  local tc = registry:get(entity, Transform)
  local w, h = tc.actualW or 0, tc.actualH or 0

  -- 3) default to center-screen if no x/y passed
  x = x or (globals.screenWidth()  / 2)
  y = y or (globals.screenHeight() / 2) - 100

  -- 4) shift so that (x,y) is the center
  tc.actualX = x - w * 0.5
  tc.actualY = y - h * 0.5
  tc.visualX = tc.actualX
  tc.visualY = tc.actualY

  -- 5) give it some jiggle/motion
  -- transform.InjectDynamicMotion(entity, 0.7, 0)
  
  timer.for_time(
    duration and duration - .2 or 1.8, -- duration in seconds
    function()
      -- move text slowly upward
      local tc2 = registry:get(entity, Transform)
      tc2.actualY = tc2.actualY - 30 * GetFrameTime()
      
      local textComp = registry:get(entity, TextSystem.Text)
      textComp.globalAlpha = textComp.globalAlpha - 0.1 * GetFrameTime() -- fade out the text
    end,
    nil
  )

  -- 6) after duration, burst and destroy
  timer.after(duration or 2.0, function()
    local tc2 = registry:get(entity, Transform)
    spawnCircularBurstParticles(
      tc2.actualX + tc2.actualW * 0.5,
      tc2.actualY + tc2.actualH * 0.5,
      5, 0.2
    )
    if registry:valid(entity) then
      registry:destroy(entity)
    end
  end)
end


function hideTooltip()
  if (globals.ui.tooltipUIBox == nil) then
    log_debug("hideTooltip: tooltipUIBox is not set up, skipping")
    return
  end
  local tooltipTransform = registry:get(globals.ui.tooltipUIBox, Transform)
  tooltipTransform.actualY = globals.screenHeight()   -- move it out of the screen
  tooltipTransform.visualY = tooltipTransform.actualY -- snap Y
end

-- increment converter ui index and set up ui. use 0 to just set up the ui without changing the index
function cycleConverter(inc)
  -- 1) adjust the selected index by inc (can be  1, 0 or -1)
  globals.selectedConverterIndex = globals.selectedConverterIndex + inc
  if globals.selectedConverterIndex > #globals.converter_defs then
    globals.selectedConverterIndex = 1
  elseif globals.selectedConverterIndex < 1 then
    globals.selectedConverterIndex = #globals.converter_defs
  end
  log_debug("Selected converter index: ", globals.selectedConverterIndex)

  -- 2) figure out locked state & tooltip text
  local locked = not globals.converter_defs[globals.selectedConverterIndex].unlocked
  local title, body
  if locked then
    title                   = localization.get("ui.converter_locked_title")
    local requirementString = getRequirementStringForBuildingOrConverter(globals.converter_defs
      [globals.selectedConverterIndex])
    body                    = localization.get("ui.converter_locked_body") .. requirementString
  else
    local costString        = getCostStringForBuildingOrConverter(globals.converter_defs[globals.selectedConverterIndex])
    local requirementString = getRequirementStringForBuildingOrConverter(globals.converter_defs
      [globals.selectedConverterIndex])
    title                   = localization.get(globals.converter_defs[globals.selectedConverterIndex].ui_text_title)
    body                    = localization.get(globals.converter_defs[globals.selectedConverterIndex].ui_text_body) ..
        costString .. requirementString
  end

  log_debug("hookup hover callbacks for converter entity: ", globals.converter_ui_animation_entity)
  -- 3) hook up hover callbacks
  local converterEntity                   = globals.converter_ui_animation_entity
  local converterGameObject               = registry:get(converterEntity, GameObject)
  converterGameObject.methods.onHover     = function()
    log_debug("Converter entity hovered!")
    showTooltip(title, body)
  end
  converterGameObject.methods.onStopHover = function()
    log_debug("Converter entity stopped hovering!")
    -- hideTooltip()
  end

  -- 4) immediately show it once
  -- showTooltip(title, body)

  log_debug("swap the animation for converter entity: ", globals.converter_ui_animation_entity)
  -- 5) swap the animation
  local animToShow = globals.converter_defs[globals.selectedConverterIndex].unlocked
      and globals.converter_defs[globals.selectedConverterIndex].anim
      or "locked_upgrade_anim"
  animation_system.replaceAnimatedObjectOnEntity(
    globals.converter_ui_animation_entity,
    animToShow,
    false,
    nil, -- shader_prepass, -- Optional shader pass config function
    true -- Enable shadow
  )

  -- 6) add a jiggle
  transform.InjectDynamicMotion(globals.converter_ui_animation_entity, 0.7, 16)
end

function cycleBuilding(inc)
  -- 1) adjust the selected index by inc (can be  1, 0 or -1)
  globals.selectedBuildingIndex = globals.selectedBuildingIndex + inc
  if globals.selectedBuildingIndex > #globals.building_upgrade_defs then
    globals.selectedBuildingIndex = 1
  elseif globals.selectedBuildingIndex < 1 then
    globals.selectedBuildingIndex = #globals.building_upgrade_defs
  end
  log_debug("Selected converter index: ", globals.selectedBuildingIndex)

  -- 2) figure out locked state & tooltip text
  local locked = not globals.building_upgrade_defs[globals.selectedBuildingIndex].unlocked
  local title, body
  if locked then
    title                   = localization.get("ui.building_locked_title")
    local requirementString = getRequirementStringForBuildingOrConverter(globals.building_upgrade_defs
      [globals.selectedBuildingIndex])
    body                    = localization.get("ui.building_locked_body") .. requirementString
  else
    local costString = getCostStringForBuildingOrConverter(globals.building_upgrade_defs[globals.selectedBuildingIndex])
    local requirementString = getRequirementStringForBuildingOrConverter(globals.building_upgrade_defs
      [globals.selectedBuildingIndex])
    log_debug("Cost string for building: ", costString)
    title = localization.get(globals.building_upgrade_defs[globals.selectedBuildingIndex].ui_text_title)
    body  = localization.get(globals.building_upgrade_defs[globals.selectedBuildingIndex].ui_text_body) ..
        costString .. requirementString
  end

  -- 3) hook up hover callbacks
  local converterEntity                   = globals.building_ui_animation_entity
  local converterGameObject               = registry:get(converterEntity, GameObject)
  converterGameObject.methods.onHover     = function()
    showTooltip(title, body)
  end
  converterGameObject.methods.onStopHover = function()
    -- hideTooltip()
  end

  -- 4) immediately show it once
  -- showTooltip(title, body)

  -- 5) swap the animation
  local animToShow                        = globals.building_upgrade_defs[globals.selectedBuildingIndex].unlocked
      and globals.building_upgrade_defs[globals.selectedBuildingIndex].anim
      or "locked_upgrade_anim"
  animation_system.replaceAnimatedObjectOnEntity(
    globals.building_ui_animation_entity,
    animToShow,
    false
  )

  -- 6) add a jiggle
  transform.InjectDynamicMotion(globals.building_ui_animation_entity, 0.7, 16)
end

function buyConverterButtonCallback()
  -- id of currently selected converter
  local selectedConverter = globals.converter_defs[globals.selectedConverterIndex]

  local uiTransformComp = registry:get(globals.converter_ui_animation_entity, Transform)

  if not selectedConverter.unlocked then
    log_debug("Converter is not unlocked yet!")
    newTextPopup(
      localization.get("ui.not_unlocked_msg"),
      uiTransformComp.actualX + uiTransformComp.actualW / 2,
      uiTransformComp.actualY - uiTransformComp.actualH * 2.5,
      2
    )
    playSoundEffect("effects", "cannot-buy")
    return
  end

  -- check if the player has enough resources to buy the converter
  local cost = selectedConverter.cost
  for currency, amount in pairs(cost) do
    if globals.currencies[currency].target < amount then
      log_debug("Not enough", currency, "to buy converter", selectedConverter.id)
      newTextPopup(
        localization.get("ui.not_enough_currency"),
        uiTransformComp.actualX + uiTransformComp.actualW / 2,
        uiTransformComp.actualY - uiTransformComp.actualH * 2.5,
        2
      )
      playSoundEffect("effects", "cannot-buy")
      return
    end
  end

  -- deduct the cost from the player's resources
  for currency, amount in pairs(cost) do
    globals.currencies[currency].target = globals.currencies[currency].target - amount
    log_debug("Deducted", amount, currency, "from player's resources")
  end


  -- create a new example converter entity
  local exampleConverter = create_ai_entity("kobold")

  -- add the converter to the end of the table in the converters table with the id of the converter
  table.insert(globals.converters[selectedConverter.id], exampleConverter)
  log_debug("Added converter entity to globals.converters: ", exampleConverter, " for id: ", selectedConverter.id)

  animation_system.setupAnimatedObjectOnEntity(
    exampleConverter,
    selectedConverter.anim, -- Default animation ID
    false,                  -- ? generate a new still animation from sprite, don't set to true, causes bug
    nil,                    -- shader_prepass, -- Optional shader pass config function
    true                    -- Enable shadow
  )

  animation_system.resizeAnimationObjectsInEntityToFit(
    exampleConverter,
    60, -- width
    60  -- height
  )

  -- make the object draggable
  local gameObjectState = registry:get(exampleConverter, GameObject).state
  gameObjectState.dragEnabled = true
  gameObjectState.clickEnabled = true
  gameObjectState.hoverEnabled = true
  gameObjectState.collisionEnabled = true

  -- create a new text entity
  local infoText = ui.definitions.getNewDynamicTextEntry(
    function() return localization.get("ui.drag_me") end, -- initial text
    15.0,                                                 -- font size
    "bump"                                                -- animation spec
  ).config.object

  -- make the text entity follow the converter entity
  local transformComp = registry:get(exampleConverter, Transform)
  transform.AssignRole(registry, infoText, InheritedPropertiesType.RoleInheritor, exampleConverter,
    InheritedPropertiesSync.Strong,
    InheritedPropertiesSync.Strong,
    InheritedPropertiesSync.Strong,
    InheritedPropertiesSync.Strong,
    Vec2(0, -20) -- offset the text above the converter
  );

  -- local textRole = registry:get(infoText, InheritedProperties)
  -- textRole.flags = AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_TOP

  playSoundEffect("effects", "buy-building")

  -- now locate the converter entity in the game world

  transformComp.actualX = globals.screenWidth() / 2 - transformComp.actualW / 2 -- center it horizontally
  transformComp.actualY = globals.screenHeight() - 300


  -- add onstopdrag method to the converter entity
  local gameObjectComp = registry:get(exampleConverter, GameObject)
  gameObjectComp.methods.onHover = function()
    log_debug("Converter entity hovered! WHy not drag?")
  end
  gameObjectComp.methods.onStopDrag = function()
    log_debug("Converter entity stopped dragging!")
    local gameObjectComp = registry:get(exampleConverter, GameObject)
    local transformComp = registry:get(exampleConverter, Transform)
    local gameObjectState = gameObjectComp.state
    -- get the grid that it's in, grid is 64 pixels wide
    local gridX = math.floor(transformComp.actualX / 64)
    local gridY = math.floor(transformComp.actualY / 64)
    log_debug("Converter entity is in grid: ", gridX, gridY)
    -- snap the entity to the grid, but center it in the grid cell
    local magic_padding = 2
    transformComp.actualX = gridX * 64 + 32 - transformComp.actualW / 2 + magic_padding -- center it in the grid cell
    transformComp.actualY = gridY * 64 + 32 - transformComp.actualH / 2 + magic_padding -- center it in the grid cell
    -- make the entity no longer draggable
    gameObjectState.dragEnabled = false
    gameObjectState.clickEnabled = false
    gameObjectState.hoverEnabled = true
    gameObjectState.collisionEnabled = true

    -- play sound
    playSoundEffect("effects", "place-building")

    -- remove the text entity
    registry:destroy(infoText)
    -- spawn particles at the converter's position center
    spawnCircularBurstParticles(
      transformComp.actualX + transformComp.actualW / 2,
      transformComp.actualY + transformComp.actualH / 2,
      20, -- number of particles
      0.5 -- particle size
    )
    transform.InjectDynamicMotion(exampleConverter, 1.0, 1)
    log_debug("add on hover/stop hover methods to the converter entity")
    -- add on hover/stop hover methods to the building entity
    gameObjectComp.methods.onHover = function()
      showTooltip(

        localization.get(selectedConverter.ui_text_title),
        localization.get(selectedConverter.ui_text_body)
      )
    end
    gameObjectComp.methods.onStopHover = function()
      log_debug("Converter entity stopped hovering!")
      -- hideTooltip()
    end
  end
end

function getRequirementStringForBuildingOrConverter(def)
  local reqString = "\nRequirements:\n"

  -- 1) currency requirements
  if def.required_currencies then
    for currencyKey, amount in pairs(def.required_currencies) do
      log_debug("Requirement currency:", currencyKey, "amount:", amount)
      local currencyName = globals.currencies[currencyKey].human_readable_name
      reqString = reqString
          .. localization.get(
            "ui.requirement_unlock_postfix",
            { number = amount, requirement = currencyName }
          )
    end
  end

  -- 2) building or converter requirements
  if def.required_building_or_converter then
    for reqId, amount in pairs(def.required_building_or_converter) do
      log_debug("Requirement building/converter:", reqId, "amount:", amount)
      -- look up the human‐readable name
      local reqDef = findInTable(globals.building_upgrade_defs, "id", reqId)
          or findInTable(globals.converter_defs, "id", reqId)
      local reqName = localization.get(reqDef.ui_text_title)
      reqString = reqString
          .. localization.get(
            "ui.requirement_unlock_postfix",
            { number = amount, requirement = reqName }
          )
    end
  end

  return reqString
end

function getCostStringForBuildingOrConverter(buildingOrConverterDef)
  local costString = "\nCost:\n"
  local cost = buildingOrConverterDef.cost
  for currency, amount in pairs(cost) do
    log_debug("Cost for currency: ", currency, " amount: ", amount)
    costString = costString ..
        localization.get("ui.cost_tooltip_postfix",
          { cost = amount, currencyName = globals.currencies[currency].human_readable_name }) .. " "
  end
  return costString
end

function getUnlockStrinForBuildingOrConverter(buildingOrConverterDef)

end

-- pass in the converter definition used to output the material
function getCostStringForMaterial(converterDef)
  local costString = "\nCost:\n"
  local cost = converterDef.required_currencies
  log_debug("debug printing cost string for material: ", converterDef.id)
  print_table(cost)
  for currency, amount in pairs(cost) do
    costString = costString ..
        localization.get("ui.material_requirement_tooltip_postfix",
          { cost = amount, currencyName = globals.currencies[currency].human_readable_name }) .. " "
  end
  return costString
end

function togglePausedState(forcePause)
  if (globals.gameOver) then
    log_debug("Game is over, cannot toggle paused state")
    return
  end
  
  -- decide whether we should be paused
  -- if forcePause is nil → flip the current state
  -- if forcePause is boolean → use that
  local willPause
  if forcePause == nil then
    willPause = not globals.gamePaused
  else
    willPause = forcePause
  end

  if willPause then
    -- → go into paused state
    globals.gamePaused = true
    log_debug("Pausing game")
    ai.pause_ai_system()
    timer.pause_group("colonist_movement_group")
    if globals.ui.pauseButtonAnimationEntity then
      animation_system.replaceAnimatedObjectOnEntity(
        globals.ui.pauseButtonAnimationEntity,
        "tile_0537.png",     -- play icon
        true
      )
      animation_system.resizeAnimationObjectsInEntityToFit(
        globals.ui.pauseButtonAnimationEntity, 40, 40
      )
    end
  else
    -- → come out of paused state
    globals.gamePaused = false
    log_debug("Unpausing game")
    ai.resume_ai_system()
    timer.resume_group("colonist_movement_group")
    if globals.ui.pauseButtonAnimationEntity then
      animation_system.replaceAnimatedObjectOnEntity(
        globals.ui.pauseButtonAnimationEntity,
        "tile_0538.png",     -- pause icon
        true
      )
      animation_system.resizeAnimationObjectsInEntityToFit(
        globals.ui.pauseButtonAnimationEntity, 40, 40
      )
    end
  end
end

-- starts walk animation for an entity
function startEntityWalkMotion(e)
  timer.every(0.5,
    function()
      if (not registry:valid(e) or e == entt_null) then
        log_debug("Entity is not valid, stopping walk motion")
        
        -- use schduler to remove the timer
        local task1 = {
              update = function(self, dt)
                  task.wait(0.1) -- wait for 0.5 seconds
                  log_debug("Removing walk timer for entity: ", e)
                  timer.cancel(e .. "_walk_timer") -- cancel the timer
              end
          }
        scheduler:attach(task1) -- attach the task to the scheduler
        return
      end
      local t = registry:get(e, Transform)
      t.actualR = 10 * math.sin(GetTime() * 4)   -- Multiply GetTime() by a factor to increase oscillation speed
    end,
    0,
    true,
    function()
      if (not registry:valid(e)) then
        log_debug("Entity is not valid, stopping walk motion")
        return -- stop the timer if the entity is not valid
      end
      local t = registry:get(e, Transform)
      t.actualR = 0
    end,
    e .. "_walk_timer" -- unique timer name for this entity
  )
end

function spawnRainPlopAtRandomLocation()
    local randomX = random_utils.random_int(0, globals.screenWidth() - 1)
    local randomY = random_utils.random_int(0, globals.screenHeight() - 1)
    spawnCircularBurstParticles(
        randomX, -- X position
        randomY, -- Y position
        10, -- number of particles
        0.5, -- lasting how long
        util.getColor("drab_olive"), -- start color
        util.getColor("green_mos") -- end color
    )
end

function spawnSnowPlopAtRandomLocation()
  local randomX = random_utils.random_int(0, globals.screenWidth() - 1)
  local randomY = random_utils.random_int(0, globals.screenHeight() - 1)
  spawnCircularBurstParticles(
      randomX, -- X position
      randomY, -- Y position
      10, -- number of particles
      0.5, -- lasting how long
      util.getColor("pastel_pink"), -- start color
      util.getColor("blue_sky") -- end color
  )
end

function buyNewColonistHomeCallback() 
  local structureDef = findInTable(globals.structure_defs, "id", "colonist_home")
  
  -- check if the player has enough resources to buy the colonist home
  local cost = structureDef.cost
  if cost > globals.currency then
    log_debug("Not enough resources to buy colonist home")
    newTextPopup(
      localization.get("ui.not_enough_currency"),
      globals.screenWidth() / 2,
      globals.screenHeight() / 2 - 100,
      2
    )
    return  
  end
  
  -- deduct the cost from the player's resources
  globals.currency = globals.currency - cost
  log_debug("Deducted", cost, "from player's resources")
  
  -- create a new colonist home entity
  local colonistHomeEntity = create_transform_entity()
  animation_system.setupAnimatedObjectOnEntity(
    colonistHomeEntity,
    structureDef.spriteID, -- Default animation ID
    true,                  -- ? generate a new still animation from sprite
    nil,                   -- shader_prepass, -- Optional shader pass config
    true
  )
  
  animation_system.resizeAnimationObjectsInEntityToFit(
    colonistHomeEntity,
    globals.tileSize, -- width
    globals.tileSize  -- height
  )
  
  -- make the object draggable
  local gameObjectState = registry:get(colonistHomeEntity, GameObject).state
  gameObjectState.dragEnabled = true
  gameObjectState.clickEnabled = true
  gameObjectState.hoverEnabled = true
  gameObjectState.collisionEnabled = true 
  
  -- create a new text entity
  local infoText = ui.definitions.getNewDynamicTextEntry(
    function() return localization.get("ui.drag_me") end, -- initial text
    15.0,                                                 -- font size
    "bump"                                                -- animation spec  
  ).config.object
  
  -- make the text entity follow the colonist home entity
  transform.AssignRole(registry, infoText, InheritedPropertiesType.RoleInheritor, colonistHomeEntity,
    InheritedPropertiesSync.Strong,
    InheritedPropertiesSync.Strong,
    InheritedPropertiesSync.Strong,   
    InheritedPropertiesSync.Strong,
    Vec2(0, -20) -- offset the text above the colonist home
  );
  
  -- now locate the colonist home entity in the game world
  local transformComp = registry:get(colonistHomeEntity, Transform)
  transformComp.actualX = globals.screenWidth() / 2 - transformComp.actualW / 2 -- center it horizontally
  transformComp.actualY = globals.screenHeight() - 300  
  
  -- add onstopdrag method to the colonist home entity
  local gameObjectComp = registry:get(colonistHomeEntity, GameObject)
  gameObjectComp.methods.onStopDrag = function()
    log_debug("Colonist home entity stopped dragging!") 
    -- add to the table in the buildings table with the id of the building
    table.insert(globals.structures.colonist_homes, { entity = colonistHomeEntity })
    log_debug("Added colonist home entity to globals.structures: ", colonistHomeEntity, " for id: ", structureDef.id) 
    local gameObjectComp = registry:get(colonistHomeEntity, GameObject)
    local transformComp = registry:get(colonistHomeEntity, Transform)
    local gameObjectState = gameObjectComp.state
    -- get the grid that it's in, grid is 64 pixels wide
    local gridX = math.floor(transformComp.actualX / 64)
    local gridY = math.floor(transformComp.actualY / 64)
    log_debug("Colonist home entity is in grid: ", gridX, gridY)  
    -- snap the entity to the grid, but center it in the grid cell  
    local magic_padding = 2
    transformComp.actualX = gridX * 64 + 32 - transformComp.actualW / 2 + magic_padding -- center it in the grid cell
    transformComp.actualY = gridY * 64 + 32 - transformComp.actualH / 2 + magic_padding -- center it in the grid cell
    -- make the entity no longer draggable
    gameObjectState.dragEnabled = false
    gameObjectState.clickEnabled = false
    gameObjectState.hoverEnabled = true
    gameObjectState.collisionEnabled = true 
    -- remove the text entity
    registry:destroy(infoText)  
    -- spawn particles at the colonist home's position center
    spawnCircularBurstParticles(
      transformComp.actualX + transformComp.actualW / 2,
      transformComp.actualY + transformComp.actualH / 2,
      20, -- number of particles
      0.5 -- particle size
    ) 
    playSoundEffect("effects", "building-plop")
    transform.InjectDynamicMotion(colonistHomeEntity, 1.0, 1) 
    log_debug("add on hover/stop hover methods to the colonist home entity")
    -- add on hover/stop hover methods to the colonist home entity
    gameObjectComp.methods.onHover = function()
      showTooltip(
        localization.get(structureDef.ui_tooltip_title),
        localization.get(structureDef.ui_tooltip_body)
      )
    end
    gameObjectComp.methods.onStopHover = function()
      log_debug("Colonist home entity stopped hovering!")
      -- hideTooltip()
    end
    
    -- spawn a new colonist at the colonist home
    spawnNewColonist()
    log_debug("Spawned new colonist at the colonist home")
  end
  
end

function buyNewDuplicatorCallback()
  local structureDef = findInTable(globals.structure_defs, "id", "duplicator")

  -- check if the player has enough resources to buy the duplicator
  local cost = structureDef.cost
  if cost > globals.currency then
    log_debug("Not enough resources to buy duplicator")
    newTextPopup(
      localization.get("ui.not_enough_currency"),
      globals.screenWidth() / 2,
      globals.screenHeight() / 2 - 100,
      2
    )
    return
  end

  -- deduct the cost from the player's resources
  globals.currency = globals.currency - cost
  log_debug("Deducted", cost, "from player's resources")

  --TODO: store duplicator in the globals table

  -- create a new duplicator entity
  local duplicatorEntity = create_transform_entity()


  animation_system.setupAnimatedObjectOnEntity(
    duplicatorEntity,
    structureDef.spriteID, -- Default animation ID
    true,                  -- ? generate a new still animation from sprite
    nil,                   -- shader_prepass, -- Optional shader pass config
    true
  )

  animation_system.resizeAnimationObjectsInEntityToFit(
    duplicatorEntity,
    globals.tileSize, -- width
    globals.tileSize  -- height
  )

  -- make the object draggable
  local gameObjectState = registry:get(duplicatorEntity, GameObject).state
  gameObjectState.dragEnabled = true
  gameObjectState.clickEnabled = true
  gameObjectState.hoverEnabled = true
  gameObjectState.collisionEnabled = true

  -- create a new text entity
  local infoText = ui.definitions.getNewDynamicTextEntry(
    function() return localization.get("ui.drag_me") end, -- initial text
    15.0,                                                 -- font size
    "bump"                                                -- animation spec
  ).config.object
  -- make the text entity follow the duplicator entity
  transform.AssignRole(registry, infoText, InheritedPropertiesType.RoleInheritor, duplicatorEntity,
    InheritedPropertiesSync.Strong,
    InheritedPropertiesSync.Strong,
    InheritedPropertiesSync.Strong,
    InheritedPropertiesSync.Strong,
    Vec2(0, -20) -- offset the text above the duplicator
  );

  -- now locate the duplicator entity in the game world
  local transformComp = registry:get(duplicatorEntity, Transform)
  transformComp.actualX = globals.screenWidth() / 2 - transformComp.actualW / 2 -- center it horizontally
  transformComp.actualY = globals.screenHeight() - 300

  -- add onstopdrag method to the duplicator entity
  local gameObjectComp = registry:get(duplicatorEntity, GameObject)
  gameObjectComp.methods.onStopDrag = function()
    log_debug("Duplicator entity stopped dragging!")


    -- add to the table in the buildings table with the id of the building
    table.insert(globals.structures.duplicators, { entity = duplicatorEntity })
    log_debug("Added duplicator entity to globals.structures: ", duplicatorEntity, " for id: ", structureDef.id)

    local gameObjectComp = registry:get(duplicatorEntity, GameObject)
    local transformComp = registry:get(duplicatorEntity, Transform)
    local gameObjectState = gameObjectComp.state
    -- get the grid that it's in, grid is 64 pixels wide
    local gridX = math.floor(transformComp.actualX / 64)
    local gridY = math.floor(transformComp.actualY / 64)
    log_debug("Duplicator entity is in grid: ", gridX, gridY)
    -- snap the entity to the grid, but center it in the grid cell
    local magic_padding = 2
    transformComp.actualX = gridX * 64 + 32 - transformComp.actualW / 2 + magic_padding -- center it in the grid cell
    transformComp.actualY = gridY * 64 + 32 - transformComp.actualH / 2 + magic_padding -- center it in the grid cell
    -- make the entity no longer draggable
    gameObjectState.dragEnabled = false
    gameObjectState.clickEnabled = false
    gameObjectState.hoverEnabled = true
    gameObjectState.collisionEnabled = true
    -- remove the text entity
    registry:destroy(infoText)

    -- spawn particles at the duplicator's position center
    spawnCircularBurstParticles(
      transformComp.actualX + transformComp.actualW / 2,
      transformComp.actualY + transformComp.actualH / 2,
      20, -- number of particles
      0.5 -- particle size
    )

    transform.InjectDynamicMotion(duplicatorEntity, 1.0, 1)

    log_debug("add on hover/stop hover methods to the duplicator entity")

    -- add on hover/stop hover methods to the duplicator entity
    gameObjectComp.methods.onHover = function()
      showTooltip(
        localization.get(structureDef.ui_tooltip_title),
        localization.get(structureDef.ui_tooltip_body)
      )
    end
    gameObjectComp.methods.onStopHover = function()
      log_debug("Duplicator entity stopped hovering!")
      -- hideTooltip()
    end
  end
end

function buyBuildingButtonCallback()
  -- id of currently selected converter
  local selectedBuilding = globals.building_upgrade_defs[globals.selectedBuildingIndex]

  local uiTransformComp = registry:get(globals.building_ui_animation_entity, Transform)

  if not selectedBuilding.unlocked then
    log_debug("Building is not unlocked yet!")
    newTextPopup(
      localization.get("ui.not_unlocked_msg"),
      uiTransformComp.actualX + uiTransformComp.actualW / 2,
      uiTransformComp.actualY - uiTransformComp.actualH * 2.5,
      2
    )
    playSoundEffect("effects", "cannot-buy")
    return
  end

  -- check if the player has enough resources to buy the building
  local cost = selectedBuilding.cost
  for currency, amount in pairs(cost) do
    if globals.currencies[currency].target < amount then
      log_debug("Not enough", currency, "to buy building", selectedBuilding.id)
      newTextPopup(
        localization.get("ui.not_enough_currency"),
        uiTransformComp.actualX + uiTransformComp.actualW / 2,
        uiTransformComp.actualY - uiTransformComp.actualH * 2.5,
        2
      )
      playSoundEffect("effects", "cannot-buy")
      return
    end
  end

  -- deduct the cost from the player's resources
  for currency, amount in pairs(cost) do
    globals.currencies[currency].target = globals.currencies[currency].target - amount
    log_debug("Deducted", amount, currency, "from player's resources")
  end


  -- create a new example converter entity
  local exampleBuilding = create_ai_entity("kobold")

  -- add to the table in the buildings table with the id of the building
  table.insert(globals.buildings[selectedBuilding.id], exampleBuilding)
  log_debug("Added building entity to globals.buildings: ", exampleBuilding, " for id: ", selectedBuilding.id)

  playSoundEffect("effects", "buy-building")


  animation_system.setupAnimatedObjectOnEntity(
    exampleBuilding,
    selectedBuilding.anim, -- Default animation ID
    false,                 -- ? generate a new still animation from sprite, don't set to true, causes bug
    nil,                   -- shader_prepass, -- Optional shader pass config function
    true                   -- Enable shadow
  )

  animation_system.resizeAnimationObjectsInEntityToFit(
    exampleBuilding,
    60, -- width
    60  -- height
  )

  -- make the object draggable
  local gameObjectState = registry:get(exampleBuilding, GameObject).state
  gameObjectState.dragEnabled = true
  gameObjectState.clickEnabled = true
  gameObjectState.hoverEnabled = true
  gameObjectState.collisionEnabled = true

  -- create a new text entity
  local infoText = ui.definitions.getNewDynamicTextEntry(
    function() return localization.get("ui.drag_me") end, -- initial text
    15.0,                                                 -- font size
    "bump"                                                -- animation spec
  ).config.object

  -- make the text entity follow the converter entity
  transform.AssignRole(registry, infoText, InheritedPropertiesType.RoleInheritor, exampleBuilding,
    InheritedPropertiesSync.Strong,
    InheritedPropertiesSync.Strong,
    InheritedPropertiesSync.Strong,
    InheritedPropertiesSync.Strong,
    Vec2(0, -20) -- offset the text above the converter
  );

  -- local textRole = registry:get(infoText, InheritedProperties)
  -- textRole.flags = AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_TOP


  -- now locate the converter entity in the game world

  local transformComp = registry:get(exampleBuilding, Transform)
  transformComp.actualX = globals.screenWidth() / 2 - transformComp.actualW / 2 -- center it horizontally
  transformComp.actualY = globals.screenHeight() - 300


  -- add onstopdrag method to the converter entity
  local gameObjectComp = registry:get(exampleBuilding, GameObject)
  gameObjectComp.methods.onHover = function()
    log_debug("Converter entity hovered! WHy not drag?")
  end
  gameObjectComp.methods.onStopDrag = function()
    log_debug("Converter entity stopped dragging!")
    local gameObjectComp = registry:get(exampleBuilding, GameObject)
    local transformComp = registry:get(exampleBuilding, Transform)
    local gameObjectState = gameObjectComp.state
    -- get the grid that it's in, grid is 64 pixels wide
    local gridX = math.floor(transformComp.actualX / 64)
    local gridY = math.floor(transformComp.actualY / 64)
    log_debug("Converter entity is in grid: ", gridX, gridY)
    -- snap the entity to the grid, but center it in the grid cell
    local magic_padding = 2
    transformComp.actualX = gridX * 64 + 32 - transformComp.actualW / 2 + magic_padding -- center it in the grid cell
    transformComp.actualY = gridY * 64 + 32 - transformComp.actualH / 2 + magic_padding -- center it in the grid cell
    -- make the entity no longer draggable
    gameObjectState.dragEnabled = false
    gameObjectState.clickEnabled = false
    gameObjectState.hoverEnabled = true
    gameObjectState.collisionEnabled = true
    -- remove the text entity
    registry:destroy(infoText)
    -- spawn particles at the converter's position center
    spawnCircularBurstParticles(
      transformComp.actualX + transformComp.actualW / 2,
      transformComp.actualY + transformComp.actualH / 2,
      20, -- number of particles
      0.5 -- particle size
    )
    transform.InjectDynamicMotion(exampleBuilding, 1.0, 1)

    playSoundEffect("effects", "place-building")

    log_debug("add on hover/stop hover methods to the building entity")
    -- add on hover/stop hover methods to the building entity

    -- localization.get("ui.currency_text", {currency = math.floor(globals.currencies.whale_dust.amount)})

    gameObjectComp.methods.onHover = function()
      log_debug("Building entity hovered!")
      showTooltip(
        localization.get(selectedBuilding.ui_text_title),
        localization.get(selectedBuilding.ui_text_body)
      )
    end
    gameObjectComp.methods.onStopHover = function()
      log_debug("Building entity stopped hovering!")
      -- hideTooltip()
    end


    -- is the building a krill home or krill farm?
    if selectedBuilding.id == "krill_home" then
      -- spawn a krill entity at the building's position
      timer.after(
        0.4, -- delay in seconds
        function()
          spawnNewKrillAtLocation(
            transformComp.actualX + transformComp.actualW / 2,
            transformComp.actualY + transformComp.actualH / 2
          )

          -- spawn particles at the building's position center
          spawnCircularBurstParticles(
            transformComp.actualX + transformComp.actualW / 2,
            transformComp.actualY + transformComp.actualH / 2,
            50, -- number of particles
            0.5 -- seconds
          )

          log_debug("Spawned a krill entity at the building's position")
        end
      )
    elseif selectedBuilding.id == "krill_farm" then
      -- spawn 3
      for j = 1, 3 do
        timer.after(
          j * 0.2, -- delay in seconds
          function()
            spawnNewKrillAtLocation(
              transformComp.actualX + transformComp.actualW / 2,
              transformComp.actualY + transformComp.actualH / 2
            )
            -- spawn particles at the building's position center
            spawnCircularBurstParticles(


              transformComp.actualX + transformComp.actualW / 2,
              transformComp.actualY + transformComp.actualH / 2,
              50, -- number of particles
              0.5 -- seconds
            )
            log_debug("Spawned a krill entity at the building's position")
          end
        )
      end
    end
  end
end

--- Find a table entry by a given field name/value.
-- @param list  An array-like table of records.
-- @param field The field name to test (string).
-- @param value The value to match against.
-- @return      The first entry whose entry[field] == value, or nil if none.
function findInTable(list, field, value)
  for _, entry in ipairs(list) do
    if entry[field] == value then
      return entry
    end
  end
  return nil
end

function updateBuildings()
  for buildingID, buildingTable in pairs(globals.buildings) do
    -- loop through each building type
    for i = 1, #buildingTable do
      local buildingEntity = buildingTable[i]

      -- ensure building has been placed
      local gameObject = registry:get(buildingEntity, GameObject)
      if gameObject.state.dragEnabled then
        log_debug("Building", buildingID, "is not placed yet, skipping")
        goto continue
      end

      local buildingTransform = registry:get(buildingEntity, Transform)
      local buildingDefTable = findInTable(globals.building_upgrade_defs, "id", buildingID)


      -- check the resource collection rate
      local resourceCollectionRate = buildingDefTable.resource_collection_rate
      if not resourceCollectionRate then
        log_debug("Building", buildingID, "has no resource collection rate defined, skipping")
        goto continue
      end
      for resource, amount in pairs(resourceCollectionRate) do
        -- find the entry in the currencies_not_picked_up table
        local currencyEntitiesNotPickedUp = globals.currencies_not_picked_up[resource]
        if currencyEntitiesNotPickedUp then
          -- get as many as the amount specified
          for j = 1, amount do
            if #currencyEntitiesNotPickedUp > 0 then
              local currencyEntity = table.remove(currencyEntitiesNotPickedUp, 1)

              log_debug("Building", buildingID, "gathered", resource, "from entity", currencyEntity)

              --TODO: move the currency entity to the building's position
              local currencyTransform = registry:get(currencyEntity, Transform)
              currencyTransform.actualX = buildingTransform.actualX + buildingTransform.actualW / 2
              currencyTransform.actualY = buildingTransform.actualY + buildingTransform.actualH / 2

              log_debug("playing sound effect with ID", buildingID)
              playSoundEffect("effects", buildingID)

              timer.after(
                0.8, -- delay in seconds
                function()
                  -- increment the global currency count
                  globals.currencies[resource].target = globals.currencies[resource].target + 1
                  -- spawn particles at the building's position center
                  spawnCircularBurstParticles(
                    buildingTransform.actualX + buildingTransform.actualW / 2,
                    buildingTransform.actualY + buildingTransform.actualH / 2,
                    10, -- number of particles
                    0.5 -- seconds
                  )
                  -- remove the currency entity from the registry
                  if (registry:valid(currencyEntity) == true) then
                    registry:destroy(currencyEntity)
                  end
                end
              )
            else
              log_debug("No more", resource, "entities to gather from")
              break
            end
          end
        end
      end

      ::continue::
    end
  end
end

function updateConverters()
  for converterID, converterTable in pairs(globals.converters) do
    -- loop through each converter type
    for i = 1, #converterTable do
      local converterEntity = converterTable[i]

      -- ensure converter has been placed
      local gameObject = registry:get(converterEntity, GameObject)
      if gameObject.state.dragEnabled then
        log_debug("Converter", converterID, "is not placed yet, skipping")
        goto continue
      end

      local converterTransform = registry:get(converterEntity, Transform)
      local converterDefTable = findInTable(globals.converter_defs, "id", converterID)


      -- check the global currencies table for the converter's required currency
      local requirement_met = true -- assume requirement is met
      for currency, amount in pairs(converterDefTable.required_currencies) do
        if globals.currencies[currency].target < amount then
          log_debug("Converter", converterID, "requires", amount, currency, "but only has",
            globals.currencies[currency].target)
          requirement_met = false -- requirement not met
          break
        end
      end
      if requirement_met then
        -- detract from target currency
        for currency, amount in pairs(converterDefTable.required_currencies) do
          globals.currencies[currency].target = globals.currencies[currency].target - amount
          log_debug("Converter", converterID, "detracted", amount, currency, "from target")
        end
        -- spawn the new currency at the converter's position, in converter table's output field
        for currency, amount in pairs(converterDefTable.output) do
          log_debug("Converter", converterID, "added", amount, currency, "to target")

          playSoundEffect("effects", converterID)

          for j = 1, amount do
            timer.after(
              0.1, -- delay in seconds
              function()
                spawnCurrencyAutoCollect(
                  converterTransform.actualX,
                  converterTransform.actualY,
                  currency
                )
              end
            )
          end
        end
      end
      ::continue::
    end
  end
end

function removeValueFromTable(t, value)
  for i, v in ipairs(t) do
    if v == value then
      table.remove(t, i)
      return true
    end
  end
  return false
end
