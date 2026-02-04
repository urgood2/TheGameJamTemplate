-- assets/scripts/serpent/reroll_button_view_model.lua
--[[
    Reroll Button View-Model Module

    Provides view-model functionality for the shop reroll button with cost calculation,
    affordability checking, and label generation for UI components.

    Implements task bd-221 requirements: "Reroll label with cost, enable/disable based on gold"
]]

local shop = require("serpent.serpent_shop")

-- Mock log functions for environments that don't have them
local log_debug = log_debug or function(msg) end
local log_warning = log_warning or function(msg) end

local reroll_button_view_model = {}

--- Calculate the current reroll cost based on shop state
--- @param shop_state table Current shop state with reroll_count
--- @return number Current reroll cost in gold
function reroll_button_view_model.calculate_reroll_cost(shop_state)
    local reroll_count = 0
    if shop_state and shop_state.reroll_count then
        reroll_count = shop_state.reroll_count
    end

    return shop.BASE_REROLL_COST + reroll_count
end

--- Check if the player can afford the reroll
--- @param gold number Current player gold
--- @param reroll_cost number Cost of reroll (optional, calculated if not provided)
--- @param shop_state table Shop state (used if reroll_cost not provided)
--- @return boolean True if player can afford the reroll
function reroll_button_view_model.can_afford_reroll(gold, reroll_cost, shop_state)
    local cost = reroll_cost or reroll_button_view_model.calculate_reroll_cost(shop_state)
    return (gold or 0) >= cost
end

--- Generate the reroll button label with cost
--- @param shop_state table Current shop state
--- @param show_cost boolean Whether to show cost in parentheses (default: true)
--- @return string Formatted label text
function reroll_button_view_model.get_reroll_label(shop_state, show_cost)
    show_cost = show_cost == nil and true or show_cost

    if not show_cost then
        return "Reroll"
    end

    local cost = reroll_button_view_model.calculate_reroll_cost(shop_state)
    return string.format("Reroll (%d gold)", cost)
end

--- Get the appropriate color for the reroll button based on affordability
--- @param gold number Current player gold
--- @param shop_state table Current shop state
--- @return string Color name for UI display
function reroll_button_view_model.get_button_color(gold, shop_state)
    local can_afford = reroll_button_view_model.can_afford_reroll(gold, nil, shop_state)
    return can_afford and "cyan" or "red"
end

--- Get comprehensive reroll button view-model data
--- @param shop_state table Current shop state
--- @param gold number Current player gold
--- @return table Complete view-model with all reroll button data
function reroll_button_view_model.get_view_model(shop_state, gold)
    local cost = reroll_button_view_model.calculate_reroll_cost(shop_state)
    local can_afford = reroll_button_view_model.can_afford_reroll(gold, cost)

    local reroll_count = shop_state and shop_state.reroll_count or 0

    return {
        -- Core functionality
        enabled = can_afford,
        cost = cost,
        can_afford = can_afford,

        -- Display properties
        label = reroll_button_view_model.get_reroll_label(shop_state, true),
        label_short = "Reroll",
        color = reroll_button_view_model.get_button_color(gold, shop_state),

        -- Detailed information
        reroll_count = reroll_count,
        base_cost = shop.BASE_REROLL_COST,
        cost_breakdown = {
            base = shop.BASE_REROLL_COST,
            additional = reroll_count,
            formula = string.format("%d + %d", shop.BASE_REROLL_COST, reroll_count)
        },

        -- Player context
        player_gold = gold,
        gold_after_reroll = math.max(0, (gold or 0) - cost),

        -- UI hints
        tooltip = string.format("Reroll shop offers for %d gold (base: %d + %d per previous reroll)",
                               cost, shop.BASE_REROLL_COST, reroll_count),
        accessibility_label = can_afford and
                            string.format("Reroll button, costs %d gold, affordable", cost) or
                            string.format("Reroll button, costs %d gold, not affordable", cost)
    }
end

--- Get minimal view-model for simple UI components
--- @param shop_state table Current shop state
--- @param gold number Current player gold
--- @return table Minimal view-model with essential data
function reroll_button_view_model.get_minimal_view_model(shop_state, gold)
    local cost = reroll_button_view_model.calculate_reroll_cost(shop_state)
    local can_afford = reroll_button_view_model.can_afford_reroll(gold, cost)

    return {
        enabled = can_afford,
        label = reroll_button_view_model.get_reroll_label(shop_state, true),
        cost = cost,
        color = reroll_button_view_model.get_button_color(gold, shop_state)
    }
end

--- Predict reroll cost for future rerolls
--- @param shop_state table Current shop state
--- @param additional_rerolls number Number of additional rerolls to calculate for
--- @return table Array of costs for each future reroll
function reroll_button_view_model.predict_future_costs(shop_state, additional_rerolls)
    additional_rerolls = additional_rerolls or 3

    local current_reroll_count = shop_state and shop_state.reroll_count or 0
    local costs = {}

    for i = 1, additional_rerolls do
        local future_count = current_reroll_count + i - 1
        local future_cost = shop.BASE_REROLL_COST + future_count
        table.insert(costs, {
            reroll_number = i,
            total_rerolls = current_reroll_count + i,
            cost = future_cost
        })
    end

    return costs
end

--- Check if multiple rerolls are affordable
--- @param shop_state table Current shop state
--- @param gold number Current player gold
--- @param num_rerolls number Number of rerolls to check affordability for
--- @return boolean, number True if affordable, total cost of all rerolls
function reroll_button_view_model.can_afford_multiple_rerolls(shop_state, gold, num_rerolls)
    num_rerolls = num_rerolls or 1

    local total_cost = 0
    local current_reroll_count = shop_state and shop_state.reroll_count or 0

    for i = 0, num_rerolls - 1 do
        local cost = shop.BASE_REROLL_COST + current_reroll_count + i
        total_cost = total_cost + cost
    end

    return (gold or 0) >= total_cost, total_cost
end

--- Get warning information about reroll affordability
--- @param shop_state table Current shop state
--- @param gold number Current player gold
--- @return table Warning information with messages and thresholds
function reroll_button_view_model.get_affordability_warnings(shop_state, gold)
    local cost = reroll_button_view_model.calculate_reroll_cost(shop_state)
    local can_afford = reroll_button_view_model.can_afford_reroll(gold, cost)

    local warnings = {
        has_warning = false,
        warning_type = nil,
        message = nil
    }

    if not can_afford then
        warnings.has_warning = true
        warnings.warning_type = "insufficient_gold"
        warnings.message = string.format("Need %d more gold to reroll", cost - (gold or 0))
    elseif (gold or 0) == cost then
        warnings.has_warning = true
        warnings.warning_type = "exact_cost"
        warnings.message = "Reroll will use all your gold"
    elseif (gold or 0) - cost < 3 then -- Assuming minimum unit cost is around 3
        warnings.has_warning = true
        warnings.warning_type = "low_remaining"
        warnings.message = string.format("Only %d gold will remain after reroll", (gold or 0) - cost)
    end

    return warnings
end

--- Test the reroll cost calculation
--- @return boolean True if reroll cost calculation works correctly
function reroll_button_view_model.test_reroll_cost_calculation()
    -- Test base cost with no rerolls
    local shop_state_0 = { reroll_count = 0 }
    local cost_0 = reroll_button_view_model.calculate_reroll_cost(shop_state_0)
    if cost_0 ~= shop.BASE_REROLL_COST then
        log_warning(string.format("Base cost test failed: expected %d, got %d", shop.BASE_REROLL_COST, cost_0))
        return false
    end

    -- Test increasing cost with rerolls
    local shop_state_3 = { reroll_count = 3 }
    local cost_3 = reroll_button_view_model.calculate_reroll_cost(shop_state_3)
    local expected_3 = shop.BASE_REROLL_COST + 3
    if cost_3 ~= expected_3 then
        log_warning(string.format("Reroll cost test failed: expected %d, got %d", expected_3, cost_3))
        return false
    end

    -- Test nil shop state
    local cost_nil = reroll_button_view_model.calculate_reroll_cost(nil)
    if cost_nil ~= shop.BASE_REROLL_COST then
        log_warning(string.format("Nil shop state test failed: expected %d, got %d", shop.BASE_REROLL_COST, cost_nil))
        return false
    end

    log_debug("[RerollButtonViewModel] Reroll cost calculation test passed")
    return true
end

--- Test affordability checking
--- @return boolean True if affordability checking works correctly
function reroll_button_view_model.test_affordability_checking()
    local shop_state = { reroll_count = 2 }
    local cost = shop.BASE_REROLL_COST + 2 -- Should be 4 if BASE_REROLL_COST is 2

    -- Test can afford
    local can_afford_yes = reroll_button_view_model.can_afford_reroll(cost, cost)
    if not can_afford_yes then
        log_warning("Affordability test failed: should be affordable with exact cost")
        return false
    end

    local can_afford_more = reroll_button_view_model.can_afford_reroll(cost + 5, cost)
    if not can_afford_more then
        log_warning("Affordability test failed: should be affordable with more gold")
        return false
    end

    -- Test cannot afford
    local can_afford_no = reroll_button_view_model.can_afford_reroll(cost - 1, cost)
    if can_afford_no then
        log_warning("Affordability test failed: should not be affordable with insufficient gold")
        return false
    end

    -- Test with nil gold
    local can_afford_nil = reroll_button_view_model.can_afford_reroll(nil, cost)
    if can_afford_nil then
        log_warning("Affordability test failed: should not be affordable with nil gold")
        return false
    end

    log_debug("[RerollButtonViewModel] Affordability checking test passed")
    return true
end

--- Test label generation
--- @return boolean True if label generation works correctly
function reroll_button_view_model.test_label_generation()
    local shop_state = { reroll_count = 1 }
    local expected_cost = shop.BASE_REROLL_COST + 1

    -- Test full label
    local full_label = reroll_button_view_model.get_reroll_label(shop_state, true)
    local expected_full = string.format("Reroll (%d gold)", expected_cost)
    if full_label ~= expected_full then
        log_warning(string.format("Full label test failed: expected '%s', got '%s'", expected_full, full_label))
        return false
    end

    -- Test short label
    local short_label = reroll_button_view_model.get_reroll_label(shop_state, false)
    if short_label ~= "Reroll" then
        log_warning(string.format("Short label test failed: expected 'Reroll', got '%s'", short_label))
        return false
    end

    log_debug("[RerollButtonViewModel] Label generation test passed")
    return true
end

--- Run all reroll button view-model tests
--- @return boolean True if all tests pass
function reroll_button_view_model.run_all_tests()
    local tests = {
        { "reroll_cost_calculation", reroll_button_view_model.test_reroll_cost_calculation },
        { "affordability_checking", reroll_button_view_model.test_affordability_checking },
        { "label_generation", reroll_button_view_model.test_label_generation },
    }

    local passed = 0
    local total = #tests

    log_debug("[RerollButtonViewModel] Running " .. total .. " tests...")

    for _, test in ipairs(tests) do
        local test_name, test_func = test[1], test[2]
        local success = test_func()

        if success then
            log_debug("[RerollButtonViewModel] ✓ " .. test_name)
            passed = passed + 1
        else
            log_warning("[RerollButtonViewModel] ✗ " .. test_name)
        end
    end

    log_debug(string.format("[RerollButtonViewModel] Results: %d/%d tests passed", passed, total))
    return passed == total
end

return reroll_button_view_model