-- assets/scripts/serpent/ui/shop_ui.lua
--[[
    Shop UI Module

    Provides view-model helpers and interactions for the serpent shop.
    Handles buy/reroll/sell/ready buttons and affordability checks.
]]

local Text = require("core.text")
local signal = require("external.hump.signal")
local shop = require("serpent.serpent_shop")

local shop_ui = {}

-- Active text handles for cleanup
local activeHandles = {}
local buttonBounds = {}

-- Track if shop UI is visible
shop_ui.isVisible = false

-- Shop state for UI (cached for performance)
local cachedShopState = nil
local cachedSnakeState = nil
local cachedGold = 0

--- Initialize shop UI
function shop_ui.init()
    activeHandles = {}
    buttonBounds = {}
    shop_ui.isVisible = false
    cachedShopState = nil
    cachedSnakeState = nil
    cachedGold = 0
end

--- Show the shop UI
--- @param shop_state table Current shop state
--- @param snake_state table Current snake state
--- @param gold number Current gold amount
--- @param unit_defs table Unit definitions for tooltips
function shop_ui.show(shop_state, snake_state, gold, unit_defs)
    if shop_ui.isVisible then return end
    shop_ui.isVisible = true

    -- Cache state for interactions
    cachedShopState = shop_state
    cachedSnakeState = snake_state
    cachedGold = gold

    local screenW = globals.screenWidth()
    local screenH = globals.screenHeight()

    -- Clear any existing handles
    shop_ui.hide()

    -- Render shop title
    shop_ui._renderTitle(screenW, screenH)

    -- Render gold display
    shop_ui._renderGoldDisplay(screenW, screenH, gold)

    -- Render shop offers (5 slots)
    shop_ui._renderOffers(screenW, screenH, shop_state, snake_state, gold, unit_defs)

    -- Render reroll button
    shop_ui._renderRerollButton(screenW, screenH, shop_state, gold)

    -- Render ready button
    shop_ui._renderReadyButton(screenW, screenH)

    log_debug("[ShopUI] Shown")
end

--- Hide the shop UI
function shop_ui.hide()
    if not shop_ui.isVisible then return end
    shop_ui.isVisible = false

    -- Stop all active text handles
    for _, handle in ipairs(activeHandles) do
        if handle and handle.stop then
            handle:stop()
        end
    end
    activeHandles = {}
    buttonBounds = {}

    cachedShopState = nil
    cachedSnakeState = nil
    cachedGold = 0

    log_debug("[ShopUI] Hidden")
end

--- Check for mouse interactions with shop elements
--- @param mouseX number Mouse X position
--- @param mouseY number Mouse Y position
--- @param clicked boolean Whether mouse was clicked this frame
function shop_ui.checkClick(mouseX, mouseY, clicked)
    if not shop_ui.isVisible or not clicked then return end

    -- Check offer slot clicks (buy actions)
    for i = 1, 5 do
        local bounds = buttonBounds["offer_" .. i]
        if bounds and shop_ui._pointInBounds(mouseX, mouseY, bounds) then
            shop_ui._handleBuyClick(i)
            return
        end
    end

    -- Check reroll button
    local rerollBounds = buttonBounds["reroll"]
    if rerollBounds and shop_ui._pointInBounds(mouseX, mouseY, rerollBounds) then
        shop_ui._handleRerollClick()
        return
    end

    -- Check ready button
    local readyBounds = buttonBounds["ready"]
    if readyBounds and shop_ui._pointInBounds(mouseX, mouseY, readyBounds) then
        shop_ui._handleReadyClick()
        return
    end
end

--- Handle buying from an offer slot
--- @param slot_index number Offer slot index (1-5)
function shop_ui._handleBuyClick(slot_index)
    if not cachedShopState or not cachedSnakeState then return end

    log_debug(string.format("[ShopUI] Buy clicked for slot %d", slot_index))
    signal.emit("shop_buy", slot_index)
end

--- Handle reroll button click
function shop_ui._handleRerollClick()
    if not cachedShopState then return end

    log_debug("[ShopUI] Reroll clicked")
    signal.emit("shop_reroll")
end

--- Handle ready button click
function shop_ui._handleReadyClick()
    log_debug("[ShopUI] Ready clicked")
    signal.emit("shop_ready")
end

--- Render shop title
function shop_ui._renderTitle(screenW, screenH)
    local titleRecipe = Text.define()
        :content("[SHOP](color=yellow)")
        :size(48)
        :anchor("center")
        :space("screen")
        :z(1000)

    local titleHandle = titleRecipe:spawn():at(screenW / 2, 80)
    table.insert(activeHandles, titleHandle)
end

--- Render gold display
function shop_ui._renderGoldDisplay(screenW, screenH, gold)
    local goldRecipe = Text.define()
        :content(string.format("[Gold: %d](color=gold)", gold))
        :size(24)
        :anchor("center")
        :space("screen")
        :z(1000)

    local goldHandle = goldRecipe:spawn():at(screenW / 2, 120)
    table.insert(activeHandles, goldHandle)
end

--- Render shop offers (5 slots)
function shop_ui._renderOffers(screenW, screenH, shop_state, snake_state, gold, unit_defs)
    local offers = shop_state.offers or {}
    local slotWidth = 120
    local slotHeight = 80
    local startX = (screenW / 2) - (5 * slotWidth / 2) + (slotWidth / 2)
    local slotY = 200

    for i = 1, 5 do
        local offer = offers[i]
        local slotX = startX + (i - 1) * slotWidth

        if offer and not offer.sold then
            -- Render offer slot with unit info
            shop_ui._renderOfferSlot(slotX, slotY, i, offer, snake_state, gold, unit_defs)
        else
            -- Render empty/sold slot
            shop_ui._renderEmptySlot(slotX, slotY, i)
        end
    end
end

--- Render an offer slot with unit information
function shop_ui._renderOfferSlot(x, y, slot_index, offer, snake_state, gold, unit_defs)
    local unit_def = unit_defs and unit_defs[offer.def_id]
    local unit_name = unit_def and unit_def.name or offer.def_id
    local cost = offer.cost or 0

    -- Check affordability
    local can_afford = gold >= cost
    local can_buy = shop.can_buy(cachedShopState, snake_state, gold, slot_index, unit_defs, nil, nil)

    -- Determine text color based on affordability and availability
    local color = "white"
    if not can_afford then
        color = "red"
    elseif not can_buy then
        color = "orange"
    elseif can_afford and can_buy then
        color = "green"
    end

    -- Render slot content
    local slotRecipe = Text.define()
        :content(string.format("[%s]\n[%d gold](color=%s)", unit_name, cost, color))
        :size(16)
        :anchor("center")
        :space("screen")
        :z(1000)

    local slotHandle = slotRecipe:spawn():at(x, y)
    table.insert(activeHandles, slotHandle)

    -- Store button bounds for click detection
    buttonBounds["offer_" .. slot_index] = {
        x = x - 60,
        y = y - 40,
        w = 120,
        h = 80
    }
end

--- Render an empty/sold slot
function shop_ui._renderEmptySlot(x, y, slot_index)
    local emptyRecipe = Text.define()
        :content("[SOLD](color=gray)")
        :size(16)
        :anchor("center")
        :space("screen")
        :z(1000)

    local emptyHandle = emptyRecipe:spawn():at(x, y)
    table.insert(activeHandles, emptyHandle)
end

--- Render reroll button
function shop_ui._renderRerollButton(screenW, screenH, shop_state, gold)
    local reroll_count = shop_state.reroll_count or 0
    local reroll_cost = shop.BASE_REROLL_COST + reroll_count
    local can_afford = gold >= reroll_cost

    local color = can_afford and "cyan" or "red"
    local rerollRecipe = Text.define()
        :content(string.format("[Reroll (%d gold)](color=%s)", reroll_cost, color))
        :size(20)
        :anchor("center")
        :space("screen")
        :z(1000)

    local rerollHandle = rerollRecipe:spawn():at(screenW / 2 - 100, 350)
    table.insert(activeHandles, rerollHandle)

    -- Store button bounds
    buttonBounds["reroll"] = {
        x = screenW / 2 - 160,
        y = 330,
        w = 120,
        h = 40
    }
end

--- Render ready button
function shop_ui._renderReadyButton(screenW, screenH)
    local readyRecipe = Text.define()
        :content("[Ready](color=green)")
        :size(20)
        :anchor("center")
        :space("screen")
        :z(1000)

    local readyHandle = readyRecipe:spawn():at(screenW / 2 + 100, 350)
    table.insert(activeHandles, readyHandle)

    -- Store button bounds
    buttonBounds["ready"] = {
        x = screenW / 2 + 40,
        y = 330,
        w = 120,
        h = 40
    }
end

--- Check if point is within bounds
function shop_ui._pointInBounds(x, y, bounds)
    return x >= bounds.x and x <= bounds.x + bounds.w and
           y >= bounds.y and y <= bounds.y + bounds.h
end

--- Get view model data for external use
--- @param shop_state table Current shop state
--- @param snake_state table Current snake state
--- @param gold number Current gold amount
--- @param unit_defs table Unit definitions
--- @return table View model with affordability and labels
function shop_ui.get_view_model(shop_state, snake_state, gold, unit_defs)
    local offers = shop_state and shop_state.offers or {}
    local view_model = {
        gold = gold,
        offers = {},
        reroll = {
            cost = shop.BASE_REROLL_COST + (shop_state and shop_state.reroll_count or 0),
            can_afford = false,
        },
        ready = {
            enabled = true,
        }
    }

    -- Calculate reroll affordability
    view_model.reroll.can_afford = gold >= view_model.reroll.cost

    -- Process each offer slot
    for i = 1, 5 do
        local offer = offers[i]
        local slot_data = {
            index = i,
            empty = not offer or offer.sold,
            def_id = offer and offer.def_id,
            cost = offer and offer.cost or 0,
            can_afford = false,
            can_buy = false,
            unit_name = "SOLD"
        }

        if offer and not offer.sold then
            local unit_def = unit_defs and unit_defs[offer.def_id]
            slot_data.unit_name = unit_def and unit_def.name or offer.def_id
            slot_data.can_afford = gold >= slot_data.cost
            slot_data.can_buy = shop.can_buy(shop_state, snake_state, gold, i, unit_defs, nil, nil)
        end

        view_model.offers[i] = slot_data
    end

    return view_model
end

--- Render snake segments with sell interaction
--- @param shop_state table Current shop state
--- @param snake_state table Current snake state
--- @param gold number Current gold amount
--- @param unit_defs table Unit definitions for tooltips
function shop_ui.show_with_segments(shop_state, snake_state, gold, unit_defs)
    -- Call normal show first
    shop_ui.show(shop_state, snake_state, gold, unit_defs)

    -- Add snake segment rendering for sell interactions
    shop_ui._renderSnakeSegments(snake_state, unit_defs)
end

--- Render snake segments for sell interaction
function shop_ui._renderSnakeSegments(snake_state, unit_defs)
    if not snake_state or not snake_state.segments then return end

    local segments = snake_state.segments
    local screenW = globals.screenWidth()
    local segmentWidth = 60
    local segmentHeight = 40
    local startX = (screenW / 2) - (#segments * segmentWidth / 2) + (segmentWidth / 2)
    local segmentY = 420

    for i, segment in ipairs(segments) do
        if segment then
            local segmentX = startX + (i - 1) * segmentWidth
            shop_ui._renderSegmentSlot(segmentX, segmentY, i, segment, snake_state, unit_defs)
        end
    end
end

--- Render a single segment slot for sell interaction
function shop_ui._renderSegmentSlot(x, y, segment_index, segment, snake_state, unit_defs)
    local snake_logic = require("serpent.snake_logic")
    local can_sell = snake_logic.can_sell(snake_state, segment.instance_id)

    local unit_def = unit_defs and unit_defs[segment.def_id]
    local unit_name = unit_def and unit_def.name or segment.def_id
    local level = segment.level or 1

    -- Determine color based on sellability
    local color = can_sell and "yellow" or "gray"

    -- Render segment
    local segmentRecipe = Text.define()
        :content(string.format("[%s L%d](color=%s)", unit_name, level, color))
        :size(12)
        :anchor("center")
        :space("screen")
        :z(1000)

    local segmentHandle = segmentRecipe:spawn():at(x, y)
    table.insert(activeHandles, segmentHandle)

    -- Store button bounds for click detection (only if sellable)
    if can_sell then
        buttonBounds["segment_" .. segment.instance_id] = {
            x = x - 30,
            y = y - 20,
            w = 60,
            h = 40
        }
    end
end

--- Enhanced click checking that includes segment selling
--- @param mouseX number Mouse X position
--- @param mouseY number Mouse Y position
--- @param clicked boolean Whether mouse was clicked this frame
function shop_ui.checkClickWithSell(mouseX, mouseY, clicked)
    if not shop_ui.isVisible or not clicked then return end

    -- Check segment sell clicks first
    for key, bounds in pairs(buttonBounds) do
        if key:match("^segment_") and shop_ui._pointInBounds(mouseX, mouseY, bounds) then
            local instance_id = tonumber(key:match("segment_(%d+)"))
            if instance_id then
                shop_ui._handleSellClick(instance_id)
                return
            end
        end
    end

    -- Fall back to normal click handling
    shop_ui.checkClick(mouseX, mouseY, clicked)
end

--- Handle selling a segment
--- @param instance_id number Segment instance ID to sell
function shop_ui._handleSellClick(instance_id)
    if not cachedSnakeState then return end

    local snake_logic = require("serpent.snake_logic")
    if not snake_logic.can_sell(cachedSnakeState, instance_id) then
        log_debug(string.format("[ShopUI] Cannot sell segment instance_id=%d (would violate min length)", instance_id))
        return
    end

    log_debug(string.format("[ShopUI] Sell clicked for segment instance_id=%d", instance_id))
    signal.emit("shop_sell", instance_id)
end

return shop_ui