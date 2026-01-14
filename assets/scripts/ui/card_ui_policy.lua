--[[
================================================================================
CARD UI POLICY
================================================================================

Centralized module for applying UI-specific setup to cards. Manages:
- Screen-space vs world-space tags
- Z-order for dragging and normal display
- Collision quadtree assignment
- Planning card elevation when inventory opens
- Card resizing when transferring between board and inventory

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

-- Planning card elevation (auto-registered via signals):
CardUIPolicy.elevatePlanningCards()       -- Called on player_inventory_opened
CardUIPolicy.resetPlanningCards()         -- Called on player_inventory_closed
CardUIPolicy.arePlanningCardsElevated()   -- Check current state

Z-ORDER HIERARCHY:
-----------------
- NORMAL_CARD_Z    = 101   (planning cards on board, below grid)
- PANEL_Z          = 800   (inventory panel background)
- GRID_Z           = 850   (inventory grid slots)
- ELEVATED_CARD_Z  = 900   (elevated planning cards, above grid)
- UI_CARD_Z        = 1000  (inventory cards, above panel and grid)
- DRAG_Z           = 1400  (dragged cards, above everything)

================================================================================
]]

local CardUIPolicy = {}

local z_orders = require("core.z_orders")
local component_cache = require("core.component_cache")
local signal = require("external.hump.signal")

-- Z-order constants for UI cards
local UI_CARD_Z = z_orders.ui_tooltips + 100  -- Normal cards in inventory (= 1000, above panel at 800 and grid at 850)
local DRAG_Z = z_orders.ui_tooltips + 500     -- Dragged cards (above everything) (= 1400)
local NORMAL_CARD_Z = z_orders.card           -- Normal cards on planning board (= 101)
local ELEVATED_CARD_Z = z_orders.ui_tooltips  -- Elevated planning cards (= 900, above grid at 850)

--------------------------------------------------------------------------------
-- SIZE CONSTANTS FOR CARD RESIZING
--------------------------------------------------------------------------------
-- When cards transfer between board and inventory, they need to be resized.
-- Board cards use screen-percentage sizing (~288×384 at 1920px width).
-- Inventory slots are fixed 64×64px.
--------------------------------------------------------------------------------
local INVENTORY_SLOT_SIZE = 64  -- Matches SLOT_WIDTH/HEIGHT in player_inventory.lua

-- Get board card dimensions (computed same way as gameplay.lua)
-- Uses 15% of screen width with 48:64 aspect ratio
local function getBoardCardDimensions()
    if globals and globals.screenWidth then
        local cardW = globals.screenWidth() * 0.150
        local cardH = cardW * (64 / 48)  -- Maintains 48:64 aspect ratio
        return cardW, cardH
    end
    -- Fallback values matching gameplay_cfg defaults
    return 80, 112
end

-- Track elevation state to avoid redundant operations
local _planningCardsElevated = false

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

    -- Resize card to fit inventory slot (64×64)
    -- Board cards are ~288×384px; inventory slots are 64×64px
    -- CRITICAL: Must use resizeAnimationObjectsInEntityToFitAndCenterUI for UI rendering!
    -- The regular resize only sets intrinsincRenderScale, but shader pipeline uses uiRenderScale.
    -- NOTE: Pass false for centering - centerItemOnSlot() handles positioning separately.
    -- Using true would cause double-centering (offset + actualX/Y both applied).
    if animation_system and animation_system.resizeAnimationObjectsInEntityToFitAndCenterUI then
        animation_system.resizeAnimationObjectsInEntityToFitAndCenterUI(
            cardEntity,
            INVENTORY_SLOT_SIZE,
            INVENTORY_SLOT_SIZE,
            false,  -- centerLaterally (handled by centerItemOnSlot)
            false   -- centerVertically (handled by centerItemOnSlot)
        )
    elseif animation_system and animation_system.resizeAnimationObjectsInEntityToFit then
        -- Fallback if UI-specific resize not available
        animation_system.resizeAnimationObjectsInEntityToFit(
            cardEntity,
            INVENTORY_SLOT_SIZE,
            INVENTORY_SLOT_SIZE
        )
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
-- NOTE: If planning cards are currently elevated (inventory is open), uses
--       ELEVATED_CARD_Z instead of NORMAL_CARD_Z to maintain visibility.
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
    -- Use elevated z-order if inventory is currently open (Cause #7 fix)
    local targetZ = _planningCardsElevated and ELEVATED_CARD_Z or NORMAL_CARD_Z
    if layer_order_system and layer_order_system.assignZIndexToEntity then
        layer_order_system.assignZIndexToEntity(cardEntity, targetZ)
    end

    -- Resize card back to board dimensions (~288×384 at 1920px)
    -- Inventory slots are 64×64px; board cards use screen-percentage sizing
    -- First, reset UI render scale (clears uiRenderScale set by inventory resize)
    if animation_system and animation_system.resetAnimationUIRenderScale then
        animation_system.resetAnimationUIRenderScale(cardEntity)
    end
    -- Then resize to board dimensions using regular resize (sets intrinsincRenderScale)
    local boardW, boardH = getBoardCardDimensions()
    if animation_system and animation_system.resizeAnimationObjectsInEntityToFit then
        animation_system.resizeAnimationObjectsInEntityToFit(
            cardEntity,
            boardW,
            boardH
        )
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
-- NOTE: If space="world" and planning cards are elevated, uses ELEVATED_CARD_Z.
--------------------------------------------------------------------------------
function CardUIPolicy.resetZOrder(cardEntity, space)
    if not registry:valid(cardEntity) then
        log_warn("[CardUIPolicy] resetZOrder: invalid entity")
        return false
    end

    local targetZ
    if space == "world" then
        -- Use elevated z-order if inventory is currently open (Cause #7 fix)
        targetZ = _planningCardsElevated and ELEVATED_CARD_Z or NORMAL_CARD_Z
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
-- PLANNING CARD ELEVATION
--------------------------------------------------------------------------------
-- When the inventory grid opens, planning cards on the board need to be
-- elevated to render ABOVE the grid slots (z=850) but BELOW inventory cards (z=1000).
-- This prevents world-space planning cards from being hidden by the grid panel.
--------------------------------------------------------------------------------

--- Elevate all world-space planning cards to render above the inventory grid.
-- Called when player_inventory_opened signal fires.
-- @return number Count of elevated cards
function CardUIPolicy.elevatePlanningCards()
    if _planningCardsElevated then
        log_debug("[CardUIPolicy] Planning cards already elevated, skipping")
        return 0
    end

    if not PLANNING_STATE then
        log_warn("[CardUIPolicy] PLANNING_STATE not available, cannot elevate cards")
        return 0
    end

    -- Access the global cards table from gameplay.lua
    local cardsTable = rawget(_G, "cards")
    if not cardsTable then
        log_debug("[CardUIPolicy] No cards table found, nothing to elevate")
        return 0
    end

    local count = 0
    for entity, cardScript in pairs(cardsTable) do
        if entity and registry:valid(entity) then
            -- Only elevate cards that are in world-space (on the planning board)
            local isWorldSpace = CardUIPolicy.isWorldSpace(entity)
            if isWorldSpace then
                if layer_order_system and layer_order_system.assignZIndexToEntity then
                    layer_order_system.assignZIndexToEntity(entity, ELEVATED_CARD_Z)
                    count = count + 1
                end
            end
        end
    end

    _planningCardsElevated = true
    log_debug("[CardUIPolicy] Elevated " .. count .. " planning cards to z=" .. ELEVATED_CARD_Z)
    return count
end

--- Reset all world-space planning cards to their normal z-order.
-- Called when player_inventory_closed signal fires.
-- @return number Count of reset cards
function CardUIPolicy.resetPlanningCards()
    if not _planningCardsElevated then
        log_debug("[CardUIPolicy] Planning cards not elevated, skipping reset")
        return 0
    end

    -- Access the global cards table from gameplay.lua
    local cardsTable = rawget(_G, "cards")
    if not cardsTable then
        log_debug("[CardUIPolicy] No cards table found, nothing to reset")
        _planningCardsElevated = false
        return 0
    end

    local count = 0
    for entity, cardScript in pairs(cardsTable) do
        if entity and registry:valid(entity) then
            -- Only reset cards that are in world-space (on the planning board)
            local isWorldSpace = CardUIPolicy.isWorldSpace(entity)
            if isWorldSpace then
                if layer_order_system and layer_order_system.assignZIndexToEntity then
                    layer_order_system.assignZIndexToEntity(entity, NORMAL_CARD_Z)
                    count = count + 1
                end
            end
        end
    end

    _planningCardsElevated = false
    log_debug("[CardUIPolicy] Reset " .. count .. " planning cards to z=" .. NORMAL_CARD_Z)
    return count
end

--- Check if planning cards are currently elevated
-- @return boolean True if cards are elevated
function CardUIPolicy.arePlanningCardsElevated()
    return _planningCardsElevated
end

--------------------------------------------------------------------------------
-- SIGNAL HANDLERS FOR INVENTORY INTEGRATION
--------------------------------------------------------------------------------
-- Automatically elevate/reset planning cards when inventory opens/closes.
-- This ensures world-space planning cards render above the grid panel.
--------------------------------------------------------------------------------

local _signalHandlersRegistered = false

--- Register signal handlers for automatic elevation.
-- Safe to call multiple times; handlers are only registered once.
function CardUIPolicy.registerInventorySignalHandlers()
    if _signalHandlersRegistered then return end

    signal.register("player_inventory_opened", function()
        CardUIPolicy.elevatePlanningCards()
    end)

    signal.register("player_inventory_closed", function()
        CardUIPolicy.resetPlanningCards()
    end)

    _signalHandlersRegistered = true
    log_debug("[CardUIPolicy] Registered inventory signal handlers")
end

-- Auto-register handlers when module loads
CardUIPolicy.registerInventorySignalHandlers()

--------------------------------------------------------------------------------
-- CONSTANTS (exposed for external use)
--------------------------------------------------------------------------------
CardUIPolicy.Z_UI_CARD = UI_CARD_Z
CardUIPolicy.Z_DRAG = DRAG_Z
CardUIPolicy.Z_NORMAL_CARD = NORMAL_CARD_Z
CardUIPolicy.Z_ELEVATED_CARD = ELEVATED_CARD_Z

-- Size constants for card resizing
CardUIPolicy.INVENTORY_SLOT_SIZE = INVENTORY_SLOT_SIZE
CardUIPolicy.getBoardCardDimensions = getBoardCardDimensions

log_debug("[CardUIPolicy] Module loaded")

return CardUIPolicy
