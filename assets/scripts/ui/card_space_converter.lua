--[[
================================================================================
CARD SPACE CONVERTER
================================================================================

Converts card entities between screen-space (inventory UI) and world-space 
(planning boards).

USAGE:
------
local CardSpaceConverter = require("ui.card_space_converter")

-- When moving card FROM inventory TO board:
CardSpaceConverter.toWorldSpace(cardEntity)

-- When moving card FROM board TO inventory:
CardSpaceConverter.toScreenSpace(cardEntity)

COORDINATE SPACES:
-----------------
- Screen-space: Fixed to screen, ignores camera. Used for UI inventory.
  - Has ObjectAttachedToUITag
  - transform.set_space(entity, "screen")
  - Collision via UI quadtree

- World-space: Follows camera. Used for planning boards.
  - NO ObjectAttachedToUITag
  - transform.set_space(entity, "world")
  - Collision via world quadtree
  - Has PLANNING_STATE tag

================================================================================
]]

local CardSpaceConverter = {}

local component_cache = require("core.component_cache")

--------------------------------------------------------------------------------
-- Convert to World Space (Inventory -> Board)
--------------------------------------------------------------------------------

--- Convert card from screen-space (inventory) to world-space (board)
--- @param cardEntity number Entity ID of the card
--- @return boolean success
function CardSpaceConverter.toWorldSpace(cardEntity)
    if not registry:valid(cardEntity) then 
        log_warn("[CardSpaceConverter] toWorldSpace: invalid entity")
        return false 
    end
    
    -- 1. Remove screen-space markers
    if ObjectAttachedToUITag and registry:has(cardEntity, ObjectAttachedToUITag) then
        registry:remove(cardEntity, ObjectAttachedToUITag)
    end
    
    -- 2. Set transform to world space
    if transform and transform.set_space then
        transform.set_space(cardEntity, "world")
    end
    
    -- 3. Update state tags for planning mode visibility
    if clear_state_tags then
        clear_state_tags(cardEntity)
    end
    if add_state_tag and PLANNING_STATE then
        add_state_tag(cardEntity, PLANNING_STATE)
    end
    if remove_default_state_tag then
        remove_default_state_tag(cardEntity)
    end
    
    -- 4. Ensure collision is enabled for world quadtree
    local go = component_cache.get(cardEntity, GameObject)
    if go then
        go.state.collisionEnabled = true
        go.state.dragEnabled = true
        go.state.hoverEnabled = true
    end
    
    log_debug("[CardSpaceConverter] Converted to world-space: " .. tostring(cardEntity))
    return true
end

--------------------------------------------------------------------------------
-- Convert to Screen Space (Board -> Inventory)
--------------------------------------------------------------------------------

--- Convert card from world-space (board) to screen-space (inventory)
--- @param cardEntity number Entity ID of the card
--- @return boolean success
function CardSpaceConverter.toScreenSpace(cardEntity)
    if not registry:valid(cardEntity) then 
        log_warn("[CardSpaceConverter] toScreenSpace: invalid entity")
        return false 
    end
    
    -- 1. Add screen-space markers
    if ObjectAttachedToUITag and not registry:has(cardEntity, ObjectAttachedToUITag) then
        registry:emplace(cardEntity, ObjectAttachedToUITag)
    end
    
    -- 2. Set transform to screen space
    if transform and transform.set_space then
        transform.set_space(cardEntity, "screen")
    end
    
    -- 3. Update state tags (screen-space UI uses default_state)
    if clear_state_tags then
        clear_state_tags(cardEntity)
    end
    if add_state_tag then
        add_state_tag(cardEntity, "default_state")
    end
    
    -- 4. Ensure collision is enabled for UI quadtree
    local go = component_cache.get(cardEntity, GameObject)
    if go then
        go.state.collisionEnabled = true
        go.state.hoverEnabled = true
        go.state.dragEnabled = true
    end
    
    log_debug("[CardSpaceConverter] Converted to screen-space: " .. tostring(cardEntity))
    return true
end

--------------------------------------------------------------------------------
-- Utility: Check Current Space
--------------------------------------------------------------------------------

--- Check if card is in screen-space
--- @param cardEntity number Entity ID
--- @return boolean
function CardSpaceConverter.isScreenSpace(cardEntity)
    if not registry:valid(cardEntity) then return false end
    return ObjectAttachedToUITag and registry:has(cardEntity, ObjectAttachedToUITag)
end

--- Check if card is in world-space
--- @param cardEntity number Entity ID
--- @return boolean
function CardSpaceConverter.isWorldSpace(cardEntity)
    return not CardSpaceConverter.isScreenSpace(cardEntity)
end

log_debug("[CardSpaceConverter] Module loaded")

return CardSpaceConverter
