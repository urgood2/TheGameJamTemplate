-- Recursively prints any table (with cycle detection)
function print_table(tbl, indent, seen)
    indent = indent or ""                 -- current indentation
    seen   = seen   or {}                 -- tables we’ve already visited
  
    if seen[tbl] then
      print(indent .. "*<recursion>–")    -- cycle detected
      return
    end
    seen[tbl] = true
  
    -- iterate all entries
    for k, v in pairs(tbl) do
      local key = type(k) == "string" and ("%q"):format(k) or tostring(k)
      if type(v) == "table" then
        print(indent .. "["..key.."] = {")
        print_table(v, indent.."  ", seen)
        print(indent .. "}")
      else
        -- primitive: just tostring it
        print(indent .. "["..key.."] = " .. tostring(v))
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
    for k,v in pairs(orig) do
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
  TextSystem.Functions.setText(bodyEnt,  bodyText)

  -- 2) re-calc the box layout to fit new text
  ui.box.RenewAlignment(registry, boxEnt)

  -- 3) grab transforms & dims
  local mouseT   = registry:get(globals.cursor(), Transform)
  local boxT     = registry:get(boxEnt,   Transform)

  local screenW, screenH = globals.screenWidth(), globals.screenHeight()

  -- fallback if UIBox doesn’t carry dims
  local w = boxT.actualW
  local h = boxT.actualH
  
  -- 4) position with offset
  local x = mouseT.actualX + 20
  local y = mouseT.actualY + 20

  -- 5) clamp to screen bounds
  boxT.actualX = clamp(x, 0, screenW - w)
  boxT.actualY = clamp(y, 0, screenH - h)
end

function hideTooltip()
  local tooltipTransform = registry:get(globals.ui.tooltipUIBox, Transform)
  tooltipTransform.actualY = globals.screenHeight()  -- move it out of the screen
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

  -- 3) hook up hover callbacks
  local converterEntity      = globals.converter_ui_animation_entity
  local converterGameObject  = registry:get(converterEntity, GameObject)
  converterGameObject.methods.onHover = function()
      debug("Converter entity hovered!")
      showTooltip(title, body)
  end
  converterGameObject.methods.onStopHover = function()
      debug("Converter entity stopped hovering!")
      hideTooltip()
  end

  -- 4) immediately show it once
  showTooltip(title, body)

  -- 5) swap the animation
  local animToShow = globals.converter_defs[globals.selectedConverterIndex].unlocked
                      and globals.converter_defs[globals.selectedConverterIndex].anim
                      or "locked_upgrade_anim"
  animation_system.replaceAnimatedObjectOnEntity(
      globals.converter_ui_animation_entity,
      animToShow,
      false
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
  local converterEntity      = globals.building_ui_animation_entity
  local converterGameObject  = registry:get(converterEntity, GameObject)
  converterGameObject.methods.onHover = function()
      showTooltip(title, body)
  end
  converterGameObject.methods.onStopHover = function()
      hideTooltip()
  end

  -- 4) immediately show it once
  showTooltip(title, body)

  -- 5) swap the animation
  local animToShow = globals.building_upgrade_defs[globals.selectedBuildingIndex].unlocked
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
