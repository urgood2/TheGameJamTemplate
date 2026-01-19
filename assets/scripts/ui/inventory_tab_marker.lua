--[[
================================================================================
INVENTORY TAB MARKER - DSL-based UI box with sprite above inventory panel
================================================================================

A clickable tab marker that appears above the inventory panel during planning.
Uses DSL hbox with state tags for visibility (AssignStateTagsToUIBox pattern).

USAGE:
------
local InventoryTabMarker = require("ui.inventory_tab_marker")

-- Called automatically via signal when entering PLANNING phase
InventoryTabMarker.init()

================================================================================
]]

local InventoryTabMarker = {}

local signal = require("external.hump.signal")
local dsl = require("ui.ui_syntax_sugar")
local z_orders = require("core.z_orders")
local timer = require("core.timer")

-- local SPRITE_NAME = "inventory-tab-marker.png"
local MARKER_WIDTH = 48
local MARKER_HEIGHT = 32
local MARKER_Z = z_orders.ui_tooltips + 200  -- Above inventory UI
local TIMER_GROUP = "inventory_tab_marker"
local RENDER_LAYER = "ui"

-- Match inventory panel dimensions for positioning (from player_inventory.lua)
-- PANEL_HEIGHT = HEADER(32) + TABS(32) + GRID(212) + FOOTER(36) + PADDING(20) = 332
local INVENTORY_PANEL_HEIGHT = 332
local GAP_ABOVE_PANEL = 8  -- Gap between marker and panel top

local state = {
    entity = nil,
    initialized = false,
    signalHandler = nil,
    markerX = 0,
    markerY = 0,
}

local function calculatePosition()
    local screenW = globals.screenWidth()
    local screenH = globals.screenHeight()

    if not screenW or not screenH or screenW <= 0 or screenH <= 0 then
        return nil, nil
    end

    -- Calculate where the inventory panel top would be
    local panelY = screenH - INVENTORY_PANEL_HEIGHT - 10

    -- Position marker centered horizontally, just above the panel
    local x = (screenW - MARKER_WIDTH) / 2
    local y = panelY - MARKER_HEIGHT - GAP_ABOVE_PANEL

    return x, y
end

local function createMarkerDefinition()
    return dsl.hbox {
        config = {
            padding = 0,
            minWidth = MARKER_WIDTH,
            minHeight = MARKER_HEIGHT,
            buttonCallback = function()
                local ok, PlayerInventory = pcall(require, "ui.player_inventory")
                if ok and PlayerInventory and PlayerInventory.toggle then
                    PlayerInventory.toggle()
                end
            end
        },
        children = {
            dsl.anim("inventory-tab-marker.png", { w = MARKER_WIDTH, h = MARKER_HEIGHT, shadow = false })
        }
    }
end

local function createMarker()
    local x, y = calculatePosition()
    if not x or not y then
        log_warn("[InventoryTabMarker] Cannot create marker - screen dimensions not ready")
        return nil
    end

    state.markerX = x
    state.markerY = y

    local markerDef = createMarkerDefinition()
    local markerEntity = dsl.spawn({ x = x, y = y }, markerDef, RENDER_LAYER, MARKER_Z)
    state.entity = markerEntity

    if not markerEntity or markerEntity == entt_null or not registry:valid(markerEntity) then
        log_warn("[InventoryTabMarker] Failed to create marker entity")
        return nil
    end

    -- Set draw layer to sprites for proper z-ordering (same pattern as player_inventory.lua)
    if ui and ui.box and ui.box.set_draw_layer then
        ui.box.set_draw_layer(markerEntity, "sprites")
        log_debug("[InventoryTabMarker] Set draw layer to sprites")
    end

    -- Assign PLANNING_STATE tag so box is only visible during planning phase
    if ui and ui.box and ui.box.AssignStateTagsToUIBox and PLANNING_STATE then
        ui.box.AssignStateTagsToUIBox(markerEntity, PLANNING_STATE)
        log_debug("[InventoryTabMarker] Assigned PLANNING_STATE tag to marker")
    else
        log_warn("[InventoryTabMarker] Could not assign state tag - ui.box.AssignStateTagsToUIBox or PLANNING_STATE not available")
    end

    -- CRITICAL: Remove default state tag so state-based visibility works
    if remove_default_state_tag then
        remove_default_state_tag(markerEntity)
        log_debug("[InventoryTabMarker] Removed default state tag")
    end

    log_debug("[InventoryTabMarker] Created marker at (" .. x .. ", " .. y .. ")")

    -- Debug: check entity transform
    local t = component_cache.get(markerEntity, Transform)
    if t then
        log_debug("[InventoryTabMarker] Transform: x=" .. tostring(t.actualX) .. " y=" .. tostring(t.actualY) .. " w=" .. tostring(t.actualW) .. " h=" .. tostring(t.actualH))
    else
        log_warn("[InventoryTabMarker] No Transform component on marker entity!")
    end

    return markerEntity
end

function InventoryTabMarker.init()
    if state.initialized then
        return
    end

    state.entity = createMarker()

    if state.entity then
        state.initialized = true
        log_debug("[InventoryTabMarker] Initialized")
    end
end

function InventoryTabMarker.destroy()
    timer.kill_group(TIMER_GROUP)

    if state.entity and registry:valid(state.entity) then
        if ui and ui.box and ui.box.Remove then
            ui.box.Remove(registry, state.entity)
        else
            registry:destroy(state.entity)
        end
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

-- Register signal handler to initialize when entering planning
state.signalHandler = function(data)
    if data and data.current == "PLANNING" then
        if not state.initialized then
            InventoryTabMarker.init()
        end
    end
end

signal.register("game_state_changed", state.signalHandler)

-- Also try to init after a short delay if we're already in planning
timer.after_opts({
    delay = 0.5,
    action = function()
        if is_state_active and is_state_active(PLANNING_STATE) then
            InventoryTabMarker.init()
        end
    end,
    tag = "marker_delayed_init"
})

log_debug("[InventoryTabMarker] Module loaded")

return InventoryTabMarker
