-- Wraps v into the interval [−size, limit]
function wrap(v, size, limit)
  if v > limit then return -size end
  if v < -size then return limit end
  return v
end

-- Recursively prints any table (with cycle detection)
function print_table(tbl, indent, seen)
  indent = indent or ""   -- current indentation
  seen   = seen or {}     -- tables we’ve already visited

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
  TextSystem.Functions.setText(bodyEnt, bodyText)

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
end

function newTextPopup(text, x, y, duration)
  -- create a new text popup entity
  local text = ui.definitions.getNewDynamicTextEntry(
    text,  -- initial text
    15.0,  -- font size
    nil,   -- no style override
    "bump" -- animation spec
  ).config.object

  -- set position
  local transformComp = registry:get(text, Transform)
  transformComp.actualX = x or globals.screenWidth() / 2
  transformComp.actualY = y or globals.screenHeight() / 2
  transformComp.visualX = transformComp.actualX
  transformComp.visualY = transformComp.actualY

  -- inject dynamic motion
  transform.InjectDynamicMotion(text, 0.7, 16)

  -- timer to make it disappear
  timer.after(duration or 2.0, function()
    local transformComp = registry:get(text, Transform)

    spawnCircularBurstParticles(
      transformComp.actualX + transformComp.actualW / 2,
      transformComp.actualY + transformComp.actualH / 2,
      5,
      0.2)

    if registry:valid(text) then
      registry:destroy(text) -- remove the text entity after the duration
    end
  end)
end

function hideTooltip()
  local tooltipTransform = registry:get(globals.ui.tooltipUIBox, Transform)
  tooltipTransform.actualY = globals.screenHeight() -- move it out of the screen
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
  debug("Selected converter index: ", globals.selectedConverterIndex)

  -- 2) figure out locked state & tooltip text
  local locked = not globals.converter_defs[globals.selectedConverterIndex].unlocked
  local title, body
  if locked then
    title = localization.get("ui.converter_locked_title")
    body  = localization.get("ui.converter_locked_body")
  else
    title = localization.get(globals.converter_defs[globals.selectedConverterIndex].ui_text_title)
    body  = localization.get(globals.converter_defs[globals.selectedConverterIndex].ui_text_body)
  end

  debug("hookup hover callbacks for converter entity: ", globals.converter_ui_animation_entity)
  -- 3) hook up hover callbacks
  local converterEntity                   = globals.converter_ui_animation_entity
  local converterGameObject               = registry:get(converterEntity, GameObject)
  converterGameObject.methods.onHover     = function()
    debug("Converter entity hovered!")
    showTooltip(title, body)
  end
  converterGameObject.methods.onStopHover = function()
    debug("Converter entity stopped hovering!")
    hideTooltip()
  end

  -- 4) immediately show it once
  -- showTooltip(title, body)

  debug("swap the animation for converter entity: ", globals.converter_ui_animation_entity)
  -- 5) swap the animation
  local animToShow = globals.converter_defs[globals.selectedConverterIndex].unlocked
      and globals.converter_defs[globals.selectedConverterIndex].anim
      or "locked_upgrade_anim"
  animation_system.replaceAnimatedObjectOnEntity(
    globals.converter_ui_animation_entity,
    animToShow,
    false,
    nil,   -- shader_prepass, -- Optional shader pass config function
    true   -- Enable shadow
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
  debug("Selected converter index: ", globals.selectedBuildingIndex)

  -- 2) figure out locked state & tooltip text
  local locked = not globals.building_upgrade_defs[globals.selectedBuildingIndex].unlocked
  local title, body
  if locked then
    title = localization.get("ui.building_locked_title")
    body  = localization.get("ui.building_locked_body")
  else
    title = localization.get(globals.building_upgrade_defs[globals.selectedBuildingIndex].ui_text_title)
    body  = localization.get(globals.building_upgrade_defs[globals.selectedBuildingIndex].ui_text_body)
  end

  -- 3) hook up hover callbacks
  local converterEntity                   = globals.building_ui_animation_entity
  local converterGameObject               = registry:get(converterEntity, GameObject)
  converterGameObject.methods.onHover     = function()
    showTooltip(title, body)
  end
  converterGameObject.methods.onStopHover = function()
    hideTooltip()
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
    debug("Converter is not unlocked yet!")
    newTextPopup(
      localization.get("ui.not_unlocked_msg"),
      uiTransformComp.actualX + uiTransformComp.actualW / 2,
      uiTransformComp.actualY - uiTransformComp.actualH * 2.5,
      2
    )
    return
  end

  -- create a new example converter entity
  local exampleConverter = create_ai_entity("kobold")

  -- add the converter to the end of the table in the converters table with the id of the converter
  table.insert(globals.converters[selectedConverter.id], exampleConverter)
  debug("Added converter entity to globals.converters: ", exampleConverter, " for id: ", selectedConverter.id)

  animation_system.setupAnimatedObjectOnEntity(
    exampleConverter,
    selectedConverter.anim,   -- Default animation ID
    false,                    -- ? generate a new still animation from sprite, don't set to true, causes bug
    nil,                      -- shader_prepass, -- Optional shader pass config function
    true                      -- Enable shadow
  )

  animation_system.resizeAnimationObjectsInEntityToFit(
    exampleConverter,
    60,   -- width
    60    -- height
  )

  -- make the object draggable
  local gameObjectState = registry:get(exampleConverter, GameObject).state
  gameObjectState.dragEnabled = true
  gameObjectState.clickEnabled = true
  gameObjectState.hoverEnabled = true
  gameObjectState.collisionEnabled = true

  -- create a new text entity
  local infoText = ui.definitions.getNewDynamicTextEntry(
    localization.get("ui.drag_me"),   -- initial text
    15.0,                             -- font size
    nil,                              -- no style override
    "bump"                            -- animation spec
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


  -- now locate the converter entity in the game world

  transformComp.actualX = globals.screenWidth() / 2 - transformComp.actualW / 2 -- center it horizontally
  transformComp.actualY = globals.screenHeight() - 300


  -- add onstopdrag method to the converter entity
  local gameObjectComp = registry:get(exampleConverter, GameObject)
  gameObjectComp.methods.onHover = function()
    debug("Converter entity hovered! WHy not drag?")
  end
  gameObjectComp.methods.onStopDrag = function()
    debug("Converter entity stopped dragging!")
    local gameObjectComp = registry:get(exampleConverter, GameObject)
    local transformComp = registry:get(exampleConverter, Transform)
    local gameObjectState = gameObjectComp.state
    -- get the grid that it's in, grid is 64 pixels wide
    local gridX = math.floor(transformComp.actualX / 64)
    local gridY = math.floor(transformComp.actualY / 64)
    debug("Converter entity is in grid: ", gridX, gridY)
    -- snap the entity to the grid, but center it in the grid cell
    local magic_padding = 2
    transformComp.actualX = gridX * 64 + 32 - transformComp.actualW / 2 + magic_padding   -- center it in the grid cell
    transformComp.actualY = gridY * 64 + 32 - transformComp.actualH / 2 + magic_padding   -- center it in the grid cell
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
      20,     -- number of particles
      0.5     -- particle size
    )
    transform.InjectDynamicMotion(exampleConverter, 1.0, 1)
    debug("add on hover/stop hover methods to the converter entity")
    -- add on hover/stop hover methods to the building entity
    gameObjectComp.methods.onHover = function()
      showTooltip(

        localization.get(selectedConverter.ui_text_title),
        localization.get(selectedConverter.ui_text_body)
      )
    end
    gameObjectComp.methods.onStopHover = function()
      debug("Converter entity stopped hovering!")
      hideTooltip()
    end
  end
end

function buyBuildingButtonCallback()
  -- id of currently selected converter
  local selectedBuilding = globals.building_upgrade_defs[globals.selectedBuildingIndex]

  local uiTransformComp = registry:get(globals.building_ui_animation_entity, Transform)

  if not selectedBuilding.unlocked then
    debug("Building is not unlocked yet!")
    newTextPopup(
      localization.get("ui.not_unlocked_msg"),
      uiTransformComp.actualX + uiTransformComp.actualW / 2,
      uiTransformComp.actualY - uiTransformComp.actualH * 2.5,
      2
    )
    return
  end



  -- create a new example converter entity
  local exampleBuilding = create_ai_entity("kobold")

  -- add to the table in the buildings table with the id of the building
  table.insert(globals.buildings[selectedBuilding.id], exampleBuilding)
  debug("Added building entity to globals.buildings: ", exampleBuilding, " for id: ", selectedBuilding.id)


  animation_system.setupAnimatedObjectOnEntity(
    exampleBuilding,
    selectedBuilding.anim,   -- Default animation ID
    false,                   -- ? generate a new still animation from sprite, don't set to true, causes bug
    nil,                     -- shader_prepass, -- Optional shader pass config function
    true                     -- Enable shadow
  )

  animation_system.resizeAnimationObjectsInEntityToFit(
    exampleBuilding,
    60,   -- width
    60    -- height
  )

  -- make the object draggable
  local gameObjectState = registry:get(exampleBuilding, GameObject).state
  gameObjectState.dragEnabled = true
  gameObjectState.clickEnabled = true
  gameObjectState.hoverEnabled = true
  gameObjectState.collisionEnabled = true

  -- create a new text entity
  local infoText = ui.definitions.getNewDynamicTextEntry(
    localization.get("ui.drag_me"),   -- initial text
    15.0,                             -- font size
    nil,                              -- no style override
    "bump"                            -- animation spec
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
    debug("Converter entity hovered! WHy not drag?")
  end
  gameObjectComp.methods.onStopDrag = function()
    debug("Converter entity stopped dragging!")
    local gameObjectComp = registry:get(exampleBuilding, GameObject)
    local transformComp = registry:get(exampleBuilding, Transform)
    local gameObjectState = gameObjectComp.state
    -- get the grid that it's in, grid is 64 pixels wide
    local gridX = math.floor(transformComp.actualX / 64)
    local gridY = math.floor(transformComp.actualY / 64)
    debug("Converter entity is in grid: ", gridX, gridY)
    -- snap the entity to the grid, but center it in the grid cell
    local magic_padding = 2
    transformComp.actualX = gridX * 64 + 32 - transformComp.actualW / 2 + magic_padding   -- center it in the grid cell
    transformComp.actualY = gridY * 64 + 32 - transformComp.actualH / 2 + magic_padding   -- center it in the grid cell
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
      20,     -- number of particles
      0.5     -- particle size
    )
    transform.InjectDynamicMotion(exampleBuilding, 1.0, 1)

    debug("add on hover/stop hover methods to the building entity")
    -- add on hover/stop hover methods to the building entity
    gameObjectComp.methods.onHover = function()
      debug("Building entity hovered!")
      showTooltip(
        localization.get(selectedBuilding.ui_text_title),
        localization.get(selectedBuilding.ui_text_body)
      )
    end
    gameObjectComp.methods.onStopHover = function()
      debug("Building entity stopped hovering!")
      hideTooltip()
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

function updateConverters()
  for converterID, converterTable in pairs(globals.converters) do
    -- loop through each converter type
    for i = 1, #converterTable do
      local converterEntity = converterTable[i]
      
      -- ensure converter has been placed
      local gameObject = registry:get(converterEntity, GameObject)
      if gameObject.state.dragEnabled then
        debug("Converter", converterID, "is not placed yet, skipping")
        goto continue
      end
      
      local converterTransform = registry:get(converterEntity, Transform)
      local converterDefTable = findInTable(globals.converter_defs, "id", converterID)
      

      -- check the global currencies table for the converter's required currency
      local requirement_met = true   -- assume requirement is met
      for currency, amount in pairs(converterDefTable.required_currencies) do
        if globals.currencies[currency].target < amount then
          debug("Converter", converterID, "requires", amount, currency, "but only has",
            globals.currencies[currency].target)
          requirement_met = false       -- requirement not met
          break
        end
      end
      if requirement_met then
        -- detract from target currency
        for currency, amount in pairs(converterDefTable.required_currencies) do
          globals.currencies[currency].target = globals.currencies[currency].target - amount
          debug("Converter", converterID, "detracted", amount, currency, "from target")
        end
        -- spawn the new currency at the converter's position, in converter table's output field
        for currency, amount in pairs(converterDefTable.output) do
          debug("Converter", converterID, "added", amount, currency, "to target")

          for j = 1, amount do
            timer.after(
              0.1,           -- delay in seconds
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
