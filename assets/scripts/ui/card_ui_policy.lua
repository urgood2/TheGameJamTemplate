--[[
================================================================================
CARD UI POLICY
================================================================================

Centralized module for applying UI-specific setup to cards. Manages:
- Screen-space vs world-space tags
- Z-order for dragging and normal display
- Collision quadtree assignment

This provides consistent card rendering behavior across all inventory grids
and planning boards.

USAGE:
------
local CardUIPolicy = require("ui.card_ui_policy")

-- When card enters inventory UI (screen-space):
CardUIPolicy.setupForScreenSpace(cardEntity)

-- When card leaves inventory UI (world-space):
CardUIPolicy.setupForWorldSpace(cardEntity)

-- During drag operations:
CardUIPolicy.setDragZOrder(cardEntity)    -- Card being dragged
CardUIPolicy.resetZOrder(cardEntity)      -- Card dropped

================================================================================
]]

local CardUIPolicy = {}

local z_orders = require("core.z_orders")
local component_cache = require("core.component_cache")

-- Z-order constants for UI cards
local UI_CARD_Z = z_orders.ui_tooltips - 100  -- Normal cards in inventory (800)
local DRAG_Z = z_orders.ui_tooltips + 500     -- Dragged cards (above everything, 1400)
local NORMAL_CARD_Z = z_orders.card           -- Normal cards on planning board (101)
local ELEVATED_CARD_Z = z_orders.ui_tooltips  -- Planning cards when inventory is open (900)

--------------------------------------------------------------------------------
-- SCREEN-SPACE SETUP
--------------------------------------------------------------------------------
-- Configures a card entity for screen-space rendering (inventory UI).
-- - Sets transform space to "screen" (triggers ScreenSpaceCollisionMarker)
-- - Card will use UI quadtree for collision
-- - Sets appropriate z-order for inventory display
--------------------------------------------------------------------------------
function CardUIPolicy.setupForScreenSpace(cardEntity)
    if not registry:valid(cardEntity) then
        log_warn("[CardUIPolicy] setupForScreenSpace: invalid entity")
        return false
    end

    -- Set transform space to screen (this adds ScreenSpaceCollisionMarker internally)
    if transform and transform.set_space then
        transform.set_space(cardEntity, "screen")
    end

    -- Set z-order for inventory display
    if layer_order_system and layer_order_system.assignZIndexToEntity then
        layer_order_system.assignZIndexToEntity(cardEntity, UI_CARD_Z)
    end

    -- Enable interaction states
    local go = component_cache.get(cardEntity, GameObject)
    if go and go.state then
        go.state.collisionEnabled = true
        go.state.hoverEnabled = true
        go.state.dragEnabled = true
    end

    log_debug("[CardUIPolicy] Configured for screen-space: " .. tostring(cardEntity))
    return true
end

--------------------------------------------------------------------------------
-- WORLD-SPACE SETUP
--------------------------------------------------------------------------------
-- Configures a card entity for world-space rendering (planning board).
-- - Sets transform space to "world" (removes ScreenSpaceCollisionMarker)
-- - Card will use world quadtree for collision
-- - Sets appropriate z-order for board display
--------------------------------------------------------------------------------
function CardUIPolicy.setupForWorldSpace(cardEntity)
    if not registry:valid(cardEntity) then
        log_warn("[CardUIPolicy] setupForWorldSpace: invalid entity")
        return false
    end

    -- Set transform space to world (removes ScreenSpaceCollisionMarker)
    if transform and transform.set_space then
        transform.set_space(cardEntity, "world")
    end

    -- Set z-order for board display
    if layer_order_system and layer_order_system.assignZIndexToEntity then
        layer_order_system.assignZIndexToEntity(cardEntity, NORMAL_CARD_Z)
    end

    -- Clear state tags and set to planning state (for board cards)
    if clear_state_tags then
        clear_state_tags(cardEntity)
    end
    if add_state_tag and PLANNING_STATE then
        add_state_tag(cardEntity, PLANNING_STATE)
    end
    if remove_default_state_tag then
        remove_default_state_tag(cardEntity)
    end

    -- Enable interaction states
    local go = component_cache.get(cardEntity, GameObject)
    if go and go.state then
        go.state.collisionEnabled = true
        go.state.hoverEnabled = true
        go.state.dragEnabled = true
    end

    log_debug("[CardUIPolicy] Configured for world-space: " .. tostring(cardEntity))
    return true
end

--------------------------------------------------------------------------------
-- DRAG Z-ORDER
--------------------------------------------------------------------------------
-- Sets a card's z-order to appear above all other UI elements during drag.
-- Use when drag starts.
--------------------------------------------------------------------------------
function CardUIPolicy.setDragZOrder(cardEntity)
    if not registry:valid(cardEntity) then
        log_warn("[CardUIPolicy] setDragZOrder: invalid entity")
        return false
    end

    if layer_order_system and layer_order_system.assignZIndexToEntity then
        layer_order_system.assignZIndexToEntity(cardEntity, DRAG_Z)
        log_debug("[CardUIPolicy] Set drag z-order for: " .. tostring(cardEntity) .. " z=" .. DRAG_Z)
        return true
    end

    return false
end

--------------------------------------------------------------------------------
-- RESET Z-ORDER
--------------------------------------------------------------------------------
-- Resets a card's z-order to normal display level.
-- Use when drag ends. Defaults to screen-space z-order; use optional space
-- parameter to specify "world" for board cards.
--------------------------------------------------------------------------------
function CardUIPolicy.resetZOrder(cardEntity, space)
    if not registry:valid(cardEntity) then
        log_warn("[CardUIPolicy] resetZOrder: invalid entity")
        return false
    end

    local targetZ
    if space == "world" then
        targetZ = NORMAL_CARD_Z
    else
        -- Default to screen-space (inventory) z-order
        targetZ = UI_CARD_Z
    end

    if layer_order_system and layer_order_system.assignZIndexToEntity then
        layer_order_system.assignZIndexToEntity(cardEntity, targetZ)
        log_debug("[CardUIPolicy] Reset z-order for: " .. tostring(cardEntity) .. " z=" .. targetZ)
        return true
    end

    return false
end

--------------------------------------------------------------------------------
-- QUERY HELPERS
--------------------------------------------------------------------------------

-- Returns true if the card is currently in screen-space
function CardUIPolicy.isScreenSpace(cardEntity)
    if not registry:valid(cardEntity) then return false end
    if transform and transform.is_screen_space then
        return transform.is_screen_space(cardEntity)
    end
    if transform and transform.get_space then
        return transform.get_space(cardEntity) == "screen"
    end
    return false
end

-- Returns true if the card is currently in world-space
function CardUIPolicy.isWorldSpace(cardEntity)
    if not registry:valid(cardEntity) then return false end
    return not CardUIPolicy.isScreenSpace(cardEntity)
end

-- Returns the current z-order of the card
function CardUIPolicy.getZOrder(cardEntity)
    if not registry:valid(cardEntity) then return nil end
    if layer_order_system and layer_order_system.getZIndex then
        return layer_order_system.getZIndex(cardEntity)
    end
    return nil
end

--------------------------------------------------------------------------------
-- PLANNING CARD Z-ORDER ELEVATION
--------------------------------------------------------------------------------
-- Elevates all planning board cards above the inventory panel.
-- Call when inventory opens.
--------------------------------------------------------------------------------
function CardUIPolicy.elevatePlanningCards()
    if not PLANNING_STATE then
        log_warn("[CardUIPolicy] PLANNING_STATE not available")
        return 0
    end

    local count = 0
    local totalEntities = 0
    local screenSpaceCount = 0
    local view = registry:runtime_view(PLANNING_STATE)

    view:each(function(entity)
        totalEntities = totalEntities + 1
        if registry:valid(entity) then
            local isWorld = CardUIPolicy.isWorldSpace(entity)
            if not isWorld then
                screenSpaceCount = screenSpaceCount + 1
            end
            if isWorld then
                if layer_order_system and layer_order_system.assignZIndexToEntity then
                    layer_order_system.assignZIndexToEntity(entity, ELEVATED_CARD_Z)
                    count = count + 1
                end
            end
        end
    end)

    log_debug("[CardUIPolicy] Elevated " .. count .. "/" .. totalEntities .. " planning cards to z=" .. ELEVATED_CARD_Z .. " (screen-space: " .. screenSpaceCount .. ")")
    return count
end

--------------------------------------------------------------------------------
-- RESTORE PLANNING CARD Z-ORDER
--------------------------------------------------------------------------------
-- Restores all planning board cards to normal z-order.
-- Call when inventory closes.
--------------------------------------------------------------------------------
function CardUIPolicy.restorePlanningCards()
    if not PLANNING_STATE then
        log_warn("[CardUIPolicy] PLANNING_STATE not available")
        return 0
    end

    local count = 0
    local view = registry:runtime_view(PLANNING_STATE)

    view:each(function(entity)
        if registry:valid(entity) and CardUIPolicy.isWorldSpace(entity) then
            if layer_order_system and layer_order_system.assignZIndexToEntity then
                layer_order_system.assignZIndexToEntity(entity, NORMAL_CARD_Z)
                count = count + 1
            end
        end
    end)

    log_debug("[CardUIPolicy] Restored " .. count .. " planning cards to z=" .. NORMAL_CARD_Z)
    return count
end

--------------------------------------------------------------------------------
-- CONSTANTS (exposed for external use)
--------------------------------------------------------------------------------
CardUIPolicy.Z_UI_CARD = UI_CARD_Z
CardUIPolicy.Z_DRAG = DRAG_Z
CardUIPolicy.Z_NORMAL_CARD = NORMAL_CARD_Z
CardUIPolicy.Z_ELEVATED_CARD = ELEVATED_CARD_Z

log_debug("[CardUIPolicy] Module loaded")

return CardUIPolicy
