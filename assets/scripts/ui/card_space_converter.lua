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
  - Has ScreenSpaceCollisionMarker (set by transform.set_space)
  - transform.set_space(entity, "screen")
  - Collision via UI quadtree

- World-space: Follows camera. Used for planning boards.
  - NO ScreenSpaceCollisionMarker
  - transform.set_space(entity, "world")
  - Collision via world quadtree
  - Has PLANNING_STATE tag

================================================================================
]]

local CardSpaceConverter = {}

local component_cache = require("core.component_cache")

function CardSpaceConverter.toWorldSpace(cardEntity)
    if not registry:valid(cardEntity) then 
        log_warn("[CardSpaceConverter] toWorldSpace: invalid entity")
        return false 
    end
    
    if transform and transform.set_space then
        transform.set_space(cardEntity, "world")
    end
    
    if clear_state_tags then
        clear_state_tags(cardEntity)
    end
    if add_state_tag and PLANNING_STATE then
        add_state_tag(cardEntity, PLANNING_STATE)
    end
    if remove_default_state_tag then
        remove_default_state_tag(cardEntity)
    end
    
    local go = component_cache.get(cardEntity, GameObject)
    if go then
        go.state.collisionEnabled = true
        go.state.dragEnabled = true
        go.state.hoverEnabled = true
    end
    
    log_debug("[CardSpaceConverter] Converted to world-space: " .. tostring(cardEntity))
    return true
end

function CardSpaceConverter.toScreenSpace(cardEntity)
    if not registry:valid(cardEntity) then 
        log_warn("[CardSpaceConverter] toScreenSpace: invalid entity")
        return false 
    end
    
    if transform and transform.set_space then
        transform.set_space(cardEntity, "screen")
    end
    
    if clear_state_tags then
        clear_state_tags(cardEntity)
    end
    if add_state_tag then
        add_state_tag(cardEntity, "default_state")
    end
    
    local go = component_cache.get(cardEntity, GameObject)
    if go then
        go.state.collisionEnabled = true
        go.state.hoverEnabled = true
        go.state.dragEnabled = true
    end
    
    log_debug("[CardSpaceConverter] Converted to screen-space: " .. tostring(cardEntity))
    return true
end

function CardSpaceConverter.isScreenSpace(cardEntity)
    if not registry:valid(cardEntity) then return false end
    if transform and transform.is_screen_space then
        return transform.is_screen_space(cardEntity)
    end
    if transform and transform.get_space then
        return transform.get_space(cardEntity) == "screen"
    end
    return false
end

function CardSpaceConverter.isWorldSpace(cardEntity)
    if not registry:valid(cardEntity) then return false end
    return not CardSpaceConverter.isScreenSpace(cardEntity)
end

log_debug("[CardSpaceConverter] Module loaded")

return CardSpaceConverter
