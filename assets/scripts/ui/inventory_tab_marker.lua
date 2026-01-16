--[[
================================================================================
INVENTORY TAB MARKER - Standalone sprite visible in planning phase
================================================================================

Simple standalone sprite that appears above the inventory panel during planning.

USAGE:
------
local InventoryTabMarker = require("ui.inventory_tab_marker")

-- Called automatically via signal, but can also init manually:
InventoryTabMarker.init()

================================================================================
]]

local InventoryTabMarker = {}

local signal = require("external.hump.signal")
local component_cache = require("core.component_cache")
local z_orders = require("core.z_orders")
local timer = require("core.timer")

local SPRITE_NAME = "inventory-tab-marker.png"
local MARKER_WIDTH = 48
local MARKER_HEIGHT = 32
local MARKER_Z = z_orders.ui_tooltips + 200  -- Above inventory UI
local TIMER_GROUP = "inventory_tab_marker"

local state = {
    entity = nil,
    initialized = false,
    signalHandler = nil,
    renderTimerActive = false,
}

local function calculatePosition()
    local screenW = globals.screenWidth()
    local screenH = globals.screenHeight()

    if not screenW or not screenH or screenW <= 0 or screenH <= 0 then
        return nil, nil
    end

    -- Position at center-bottom area of screen (above where inventory panel would be)
    local x = screenW / 2 - MARKER_WIDTH / 2
    local y = screenH - 300  -- Roughly above the inventory panel

    return x, y
end

local function createMarker()
    print("[InventoryTabMarker] createMarker called")
    local x, y = calculatePosition()
    if not x or not y then
        print("[InventoryTabMarker] Cannot create marker - screen dimensions not ready")
        return nil
    end
    print("[InventoryTabMarker] Creating marker at (" .. x .. ", " .. y .. ")")

    local entity = animation_system.createAnimatedObjectWithTransform(
        SPRITE_NAME, true, x, y, nil, true
    )
    print("[InventoryTabMarker] Entity created: " .. tostring(entity))

    if not entity or not registry:valid(entity) then
        log_warn("[InventoryTabMarker] Failed to create marker entity")
        return nil
    end

    -- Resize to desired dimensions
    animation_system.resizeAnimationObjectsInEntityToFit(entity, MARKER_WIDTH, MARKER_HEIGHT)

    -- Set z-order
    if layer_order_system and layer_order_system.assignZIndexToEntity then
        layer_order_system.assignZIndexToEntity(entity, MARKER_Z)
    end

    -- Set screen-space for fixed UI positioning
    transform.set_space(entity, "screen")

    -- Use legacy pipeline for rendering - it handles screen-space sprites
    local animComp = component_cache.get(entity, AnimationQueueComponent)
    if animComp then
        animComp.drawWithLegacyPipeline = true
    end

    -- Make visible during PLANNING phase using the proper state tag
    -- CRITICAL: Must remove default_state first, otherwise entity is always visible!
    if remove_default_state_tag then
        remove_default_state_tag(entity)
    end
    if add_state_tag and PLANNING_STATE then
        add_state_tag(entity, PLANNING_STATE)
    end

    log_debug("[InventoryTabMarker] Created marker at (" .. x .. ", " .. y .. ")")

    return entity
end

-- No explicit render timer needed - legacy pipeline handles screen-space sprites
local function setupRenderTimer()
    -- Kept for API compatibility but does nothing now
end

local function showMarker()
    if not state.entity or not registry:valid(state.entity) then
        return
    end

    if add_state_tag and PLANNING_STATE then
        add_state_tag(state.entity, PLANNING_STATE)
    end

    log_debug("[InventoryTabMarker] Marker shown")
end

local function hideMarker()
    if not state.entity or not registry:valid(state.entity) then
        return
    end

    if remove_state_tag and PLANNING_STATE then
        remove_state_tag(state.entity, PLANNING_STATE)
    end

    log_debug("[InventoryTabMarker] Marker hidden")
end

function InventoryTabMarker.init()
    print("[InventoryTabMarker] init() called, initialized=" .. tostring(state.initialized))
    if state.initialized then
        return
    end

    state.entity = createMarker()

    if state.entity then
        setupRenderTimer()
        state.initialized = true
        log_debug("[InventoryTabMarker] Initialized")
    end
end

function InventoryTabMarker.destroy()
    timer.kill_group(TIMER_GROUP)
    state.renderTimerActive = false

    if state.entity and registry:valid(state.entity) then
        registry:destroy(state.entity)
    end
    state.entity = nil
    state.initialized = false

    if state.signalHandler then
        signal.remove("game_state_changed", state.signalHandler)
        state.signalHandler = nil
    end

    log_debug("[InventoryTabMarker] Destroyed")
end

function InventoryTabMarker.getEntity()
    return state.entity
end

-- Register signal handler to initialize when game enters PLANNING phase
state.signalHandler = function(data)
    print("[InventoryTabMarker] game_state_changed received: " .. tostring(data and data.current))
    if data and data.current == "PLANNING" then
        if not state.initialized then
            InventoryTabMarker.init()
        else
            showMarker()
        end
    elseif data and data.current ~= "PLANNING" then
        hideMarker()
    end
end

signal.register("game_state_changed", state.signalHandler)

print("[InventoryTabMarker] Module loaded - signal registered")

-- Also try to init after a short delay if we're already in planning
timer.after_opts({
    delay = 0.5,
    action = function()
        print("[InventoryTabMarker] Delayed init check - PLANNING_STATE=" .. tostring(PLANNING_STATE))
        if is_state_active and is_state_active(PLANNING_STATE) then
            print("[InventoryTabMarker] Planning state is active - initializing")
            InventoryTabMarker.init()
        else
            print("[InventoryTabMarker] Planning state not active yet")
        end
    end,
    tag = "marker_delayed_init"
})

return InventoryTabMarker
