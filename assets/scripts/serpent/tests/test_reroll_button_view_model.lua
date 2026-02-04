--[[
================================================================================
TEST: Reroll Button View-Model Implementation
================================================================================
Verifies that reroll_button_view_model.lua correctly implements:
- Reroll label with cost
- Enable/disable based on gold
- Comprehensive view-model functionality

as specified in task bd-221.

Run with: lua assets/scripts/serpent/tests/test_reroll_button_view_model.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")

-- Mock dependencies
_G.log_debug = function(msg) end
_G.log_warning = function(msg) end

t.describe("reroll_button_view_model.lua - Core Functionality", function()
    t.it("calculates reroll cost correctly", function()
        local reroll_vm = require("serpent.reroll_button_view_model")
        local shop = require("serpent.serpent_shop")

        -- Test with no rerolls (base cost)
        local shop_state_0 = { reroll_count = 0 }
        local cost_0 = reroll_vm.calculate_reroll_cost(shop_state_0)
        t.expect(cost_0).to_be(shop.BASE_REROLL_COST)

        -- Test with multiple rerolls
        local shop_state_3 = { reroll_count = 3 }
        local cost_3 = reroll_vm.calculate_reroll_cost(shop_state_3)
        t.expect(cost_3).to_be(shop.BASE_REROLL_COST + 3)

        -- Test with nil shop state
        local cost_nil = reroll_vm.calculate_reroll_cost(nil)
        t.expect(cost_nil).to_be(shop.BASE_REROLL_COST)

        -- Test with shop state missing reroll_count
        local shop_state_empty = {}
        local cost_empty = reroll_vm.calculate_reroll_cost(shop_state_empty)
        t.expect(cost_empty).to_be(shop.BASE_REROLL_COST)
    end)

    t.it("checks affordability correctly", function()
        local reroll_vm = require("serpent.reroll_button_view_model")

        local shop_state = { reroll_count = 1 }
        local cost = reroll_vm.calculate_reroll_cost(shop_state) -- Should be BASE + 1

        -- Test can afford (exact amount)
        local can_afford_exact = reroll_vm.can_afford_reroll(cost, cost)
        t.expect(can_afford_exact).to_be(true)

        -- Test can afford (more than needed)
        local can_afford_more = reroll_vm.can_afford_reroll(cost + 10, cost)
        t.expect(can_afford_more).to_be(true)

        -- Test cannot afford
        local cannot_afford = reroll_vm.can_afford_reroll(cost - 1, cost)
        t.expect(cannot_afford).to_be(false)

        -- Test with nil gold
        local cannot_afford_nil = reroll_vm.can_afford_reroll(nil, cost)
        t.expect(cannot_afford_nil).to_be(false)

        -- Test with zero gold
        local cannot_afford_zero = reroll_vm.can_afford_reroll(0, cost)
        t.expect(cannot_afford_zero).to_be(false)
    end)

    t.it("generates correct labels", function()
        local reroll_vm = require("serpent.reroll_button_view_model")
        local shop = require("serpent.serpent_shop")

        local shop_state = { reroll_count = 2 }
        local expected_cost = shop.BASE_REROLL_COST + 2

        -- Test full label with cost
        local full_label = reroll_vm.get_reroll_label(shop_state, true)
        local expected_full = string.format("Reroll (%d gold)", expected_cost)
        t.expect(full_label).to_be(expected_full)

        -- Test short label without cost
        local short_label = reroll_vm.get_reroll_label(shop_state, false)
        t.expect(short_label).to_be("Reroll")

        -- Test default behavior (should show cost)
        local default_label = reroll_vm.get_reroll_label(shop_state)
        t.expect(default_label).to_be(expected_full)
    end)

    t.it("returns correct button colors", function()
        local reroll_vm = require("serpent.reroll_button_view_model")

        local shop_state = { reroll_count = 1 }
        local cost = reroll_vm.calculate_reroll_cost(shop_state)

        -- Test affordable color
        local affordable_color = reroll_vm.get_button_color(cost, shop_state)
        t.expect(affordable_color).to_be("cyan")

        -- Test unaffordable color
        local unaffordable_color = reroll_vm.get_button_color(cost - 1, shop_state)
        t.expect(unaffordable_color).to_be("red")

        -- Test with nil gold
        local nil_gold_color = reroll_vm.get_button_color(nil, shop_state)
        t.expect(nil_gold_color).to_be("red")
    end)

    t.it("provides comprehensive view-model data", function()
        local reroll_vm = require("serpent.reroll_button_view_model")
        local shop = require("serpent.serpent_shop")

        local shop_state = { reroll_count = 3 }
        local gold = 20
        local cost = shop.BASE_REROLL_COST + 3

        local view_model = reroll_vm.get_view_model(shop_state, gold)

        -- Test core functionality
        t.expect(view_model.cost).to_be(cost)
        t.expect(view_model.can_afford).to_be(gold >= cost)
        t.expect(view_model.enabled).to_be(gold >= cost)

        -- Test display properties
        t.expect(view_model.label).to_be(string.format("Reroll (%d gold)", cost))
        t.expect(view_model.label_short).to_be("Reroll")
        t.expect(view_model.color).to_be(gold >= cost and "cyan" or "red")

        -- Test detailed information
        t.expect(view_model.reroll_count).to_be(3)
        t.expect(view_model.base_cost).to_be(shop.BASE_REROLL_COST)
        t.expect(view_model.cost_breakdown.base).to_be(shop.BASE_REROLL_COST)
        t.expect(view_model.cost_breakdown.additional).to_be(3)

        -- Test player context
        t.expect(view_model.player_gold).to_be(gold)
        t.expect(view_model.gold_after_reroll).to_be(math.max(0, gold - cost))

        -- Test UI hints exist
        t.expect(view_model.tooltip).never().to_be_nil()
        t.expect(view_model.accessibility_label).never().to_be_nil()
    end)

    t.it("provides minimal view-model data", function()
        local reroll_vm = require("serpent.reroll_button_view_model")

        local shop_state = { reroll_count = 1 }
        local gold = 10

        local minimal_vm = reroll_vm.get_minimal_view_model(shop_state, gold)

        -- Should have essential fields only
        t.expect(minimal_vm.enabled).never().to_be_nil()
        t.expect(minimal_vm.label).never().to_be_nil()
        t.expect(minimal_vm.cost).never().to_be_nil()
        t.expect(minimal_vm.color).never().to_be_nil()

        -- Check values are correct
        local cost = reroll_vm.calculate_reroll_cost(shop_state)
        t.expect(minimal_vm.cost).to_be(cost)
        t.expect(minimal_vm.enabled).to_be(gold >= cost)
    end)
end)

t.describe("reroll_button_view_model.lua - Advanced Features", function()
    t.it("predicts future reroll costs", function()
        local reroll_vm = require("serpent.reroll_button_view_model")
        local shop = require("serpent.serpent_shop")

        local shop_state = { reroll_count = 2 }
        local future_costs = reroll_vm.predict_future_costs(shop_state, 3)

        t.expect(#future_costs).to_be(3)

        -- First future reroll (current + 0)
        t.expect(future_costs[1].reroll_number).to_be(1)
        t.expect(future_costs[1].total_rerolls).to_be(3)
        t.expect(future_costs[1].cost).to_be(shop.BASE_REROLL_COST + 2)

        -- Second future reroll (current + 1)
        t.expect(future_costs[2].reroll_number).to_be(2)
        t.expect(future_costs[2].total_rerolls).to_be(4)
        t.expect(future_costs[2].cost).to_be(shop.BASE_REROLL_COST + 3)

        -- Third future reroll (current + 2)
        t.expect(future_costs[3].reroll_number).to_be(3)
        t.expect(future_costs[3].total_rerolls).to_be(5)
        t.expect(future_costs[3].cost).to_be(shop.BASE_REROLL_COST + 4)
    end)

    t.it("checks multiple reroll affordability", function()
        local reroll_vm = require("serpent.reroll_button_view_model")
        local shop = require("serpent.serpent_shop")

        local shop_state = { reroll_count = 1 }
        local gold = 50

        -- Test single reroll
        local affordable_1, cost_1 = reroll_vm.can_afford_multiple_rerolls(shop_state, gold, 1)
        local expected_cost_1 = shop.BASE_REROLL_COST + 1
        t.expect(affordable_1).to_be(gold >= expected_cost_1)
        t.expect(cost_1).to_be(expected_cost_1)

        -- Test multiple rerolls
        local affordable_3, cost_3 = reroll_vm.can_afford_multiple_rerolls(shop_state, gold, 3)
        -- Costs: (BASE+1) + (BASE+2) + (BASE+3) = 3*BASE + 6
        local expected_cost_3 = 3 * shop.BASE_REROLL_COST + 1 + 2 + 3
        t.expect(affordable_3).to_be(gold >= expected_cost_3)
        t.expect(cost_3).to_be(expected_cost_3)

        -- Test with insufficient gold
        local affordable_poor, cost_poor = reroll_vm.can_afford_multiple_rerolls(shop_state, 1, 1)
        t.expect(affordable_poor).to_be(false)
        t.expect(cost_poor).to_be(shop.BASE_REROLL_COST + 1)
    end)

    t.it("provides affordability warnings", function()
        local reroll_vm = require("serpent.reroll_button_view_model")

        local shop_state = { reroll_count = 0 }
        local cost = reroll_vm.calculate_reroll_cost(shop_state)

        -- Test insufficient gold
        local warning_poor = reroll_vm.get_affordability_warnings(shop_state, cost - 2)
        t.expect(warning_poor.has_warning).to_be(true)
        t.expect(warning_poor.warning_type).to_be("insufficient_gold")

        -- Test exact cost
        local warning_exact = reroll_vm.get_affordability_warnings(shop_state, cost)
        t.expect(warning_exact.has_warning).to_be(true)
        t.expect(warning_exact.warning_type).to_be("exact_cost")

        -- Test low remaining gold
        local warning_low = reroll_vm.get_affordability_warnings(shop_state, cost + 2)
        t.expect(warning_low.has_warning).to_be(true)
        t.expect(warning_low.warning_type).to_be("low_remaining")

        -- Test plenty of gold (no warning)
        local warning_good = reroll_vm.get_affordability_warnings(shop_state, cost + 10)
        t.expect(warning_good.has_warning).to_be(false)
    end)
end)

t.describe("reroll_button_view_model.lua - Edge Cases", function()
    t.it("handles nil shop state gracefully", function()
        local reroll_vm = require("serpent.reroll_button_view_model")

        local cost = reroll_vm.calculate_reroll_cost(nil)
        local can_afford = reroll_vm.can_afford_reroll(10, nil, nil)
        local label = reroll_vm.get_reroll_label(nil)
        local color = reroll_vm.get_button_color(10, nil)
        local view_model = reroll_vm.get_view_model(nil, 10)

        -- Should not crash and return sensible defaults
        t.expect(cost).to_be_truthy()
        t.expect(can_afford ~= nil).to_be(true)
        t.expect(label).to_be_truthy()
        t.expect(color).to_be_truthy()
        t.expect(view_model).to_be_truthy()
    end)

    t.it("handles zero and negative gold", function()
        local reroll_vm = require("serpent.reroll_button_view_model")

        local shop_state = { reroll_count = 1 }

        -- Test zero gold
        local view_model_zero = reroll_vm.get_view_model(shop_state, 0)
        t.expect(view_model_zero.can_afford).to_be(false)
        t.expect(view_model_zero.enabled).to_be(false)
        t.expect(view_model_zero.color).to_be("red")

        -- Test negative gold (should be treated as 0)
        local view_model_neg = reroll_vm.get_view_model(shop_state, -5)
        t.expect(view_model_neg.gold_after_reroll).to_be(0)
    end)

    t.it("handles missing reroll_count in shop state", function()
        local reroll_vm = require("serpent.reroll_button_view_model")
        local shop = require("serpent.serpent_shop")

        local shop_state_empty = {}
        local cost = reroll_vm.calculate_reroll_cost(shop_state_empty)

        t.expect(cost).to_be(shop.BASE_REROLL_COST)

        local view_model = reroll_vm.get_view_model(shop_state_empty, 10)
        t.expect(view_model.reroll_count).to_be(0)
        t.expect(view_model.cost_breakdown.additional).to_be(0)
    end)
end)

t.describe("reroll_button_view_model.lua - Built-in Tests", function()
    t.it("passes all built-in tests", function()
        local reroll_vm = require("serpent.reroll_button_view_model")

        local cost_test = reroll_vm.test_reroll_cost_calculation()
        t.expect(cost_test).to_be(true)

        local affordability_test = reroll_vm.test_affordability_checking()
        t.expect(affordability_test).to_be(true)

        local label_test = reroll_vm.test_label_generation()
        t.expect(label_test).to_be(true)

        local all_tests = reroll_vm.run_all_tests()
        t.expect(all_tests).to_be(true)
    end)
end)

t.describe("reroll_button_view_model.lua - Integration", function()
    t.it("integrates correctly with shop system", function()
        local reroll_vm = require("serpent.reroll_button_view_model")
        local shop = require("serpent.serpent_shop")

        -- Test that our cost calculation matches shop system
        local shop_state = { reroll_count = 5 }

        local our_cost = reroll_vm.calculate_reroll_cost(shop_state)
        local shop_cost = shop.BASE_REROLL_COST + shop_state.reroll_count

        t.expect(our_cost).to_be(shop_cost)

        -- Test that label includes correct cost
        local label = reroll_vm.get_reroll_label(shop_state)
        local expected_label = string.format("Reroll (%d gold)", shop_cost)

        t.expect(label).to_be(expected_label)
    end)

    t.it("provides consistent enabled/disabled states", function()
        local reroll_vm = require("serpent.reroll_button_view_model")

        local shop_state = { reroll_count = 2 }
        local cost = reroll_vm.calculate_reroll_cost(shop_state)

        -- Test enabled state consistency
        local view_model_affordable = reroll_vm.get_view_model(shop_state, cost)
        t.expect(view_model_affordable.enabled).to_be(view_model_affordable.can_afford)
        t.expect(view_model_affordable.color).to_be("cyan")

        -- Test disabled state consistency
        local view_model_poor = reroll_vm.get_view_model(shop_state, cost - 1)
        t.expect(view_model_poor.enabled).to_be(view_model_poor.can_afford)
        t.expect(view_model_poor.color).to_be("red")
    end)
end)

local success = t.run()
os.exit(success and 0 or 1)