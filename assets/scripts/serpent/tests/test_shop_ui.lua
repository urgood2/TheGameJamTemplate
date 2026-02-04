-- assets/scripts/serpent/tests/test_shop_ui.lua
--[[
    Test Suite: Shop UI View-Model Helpers

    Verifies shop UI view-model formatting:
    - get_view_model: offer slots, affordability, reroll cost
    - Slot status (empty, sold, purchasable)
    - Button state (reroll, ready)

    Run with: lua assets/scripts/serpent/tests/test_shop_ui.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

-- Test framework
local test = {}
test.passed = 0
test.failed = 0

function test.assert_eq(actual, expected, message)
    if actual == expected then
        test.passed = test.passed + 1
        return true
    else
        test.failed = test.failed + 1
        print(string.format("\226\156\151 FAILED: %s\n  Expected: %s\n  Actual: %s",
            message or "assertion", tostring(expected), tostring(actual)))
        return false
    end
end

function test.assert_true(condition, message)
    return test.assert_eq(condition, true, message)
end

function test.assert_false(condition, message)
    return test.assert_eq(condition, false, message)
end

-- Mock Text system before requiring shop_ui
local MockText = {
    define = function()
        return {
            content = function(self, content) return self end,
            size = function(self, size) return self end,
            anchor = function(self, anchor) return self end,
            space = function(self, space) return self end,
            z = function(self, z) return self end,
            spawn = function(self)
                return {
                    at = function(self, x, y) return { stop = function() end } end
                }
            end
        }
    end
}
package.loaded["core.text"] = MockText

-- Mock signal system
local MockSignal = {
    last_emitted = nil,
    last_args = {},
}
function MockSignal.emit(signal_name, ...)
    MockSignal.last_emitted = signal_name
    MockSignal.last_args = {...}
end
package.loaded["external.hump.signal"] = MockSignal

-- Mock serpent_shop with required constants and functions
local MockShop = {
    BASE_REROLL_COST = 2,
    can_buy = function(shop_state, snake_state, gold, slot_index, unit_defs, rng, combine_logic)
        if not shop_state or not shop_state.offers then return false end
        local offer = shop_state.offers[slot_index]
        if not offer or offer.sold then return false end
        if gold < (offer.cost or 0) then return false end
        -- Check max length
        if snake_state and snake_state.segments then
            local max_len = snake_state.max_len or 8
            if #snake_state.segments >= max_len then return false end
        end
        return true
    end
}
package.loaded["serpent.serpent_shop"] = MockShop

-- Mock snake_logic for can_sell function
local MockSnakeLogic = {
    can_sell = function(snake_state, instance_id)
        if not snake_state or not snake_state.segments then return false end
        local min_len = snake_state.min_len or 3
        -- Can sell if current length > min_len
        return #snake_state.segments > min_len
    end
}
package.loaded["serpent.snake_logic"] = MockSnakeLogic

-- Mock globals
_G.globals = {
    screenWidth = function() return 800 end,
    screenHeight = function() return 600 end
}
_G.log_debug = function(msg) end

local shop_ui = require("serpent.ui.shop_ui")

--===========================================================================
-- Helper: Create test fixtures
--===========================================================================

local function make_shop_state(offers, reroll_count)
    return {
        offers = offers or {},
        reroll_count = reroll_count or 0
    }
end

local function make_snake_state(segment_count, min_len, max_len)
    local segments = {}
    for i = 1, segment_count do
        table.insert(segments, { instance_id = i, def_id = "soldier", level = 1 })
    end
    return {
        segments = segments,
        min_len = min_len or 3,
        max_len = max_len or 8
    }
end

local function make_offer(def_id, cost, sold)
    return {
        def_id = def_id,
        cost = cost,
        sold = sold or false
    }
end

local function make_unit_defs()
    return {
        soldier = { name = "Soldier", cost = 3 },
        knight = { name = "Knight", cost = 4 },
        mage = { name = "Mage", cost = 5 }
    }
end

--===========================================================================
-- TEST: View Model - Basic Structure
--===========================================================================

function test.test_view_model_structure()
    print("\n=== Test: View Model Structure ===")

    local shop_state = make_shop_state({})
    local snake_state = make_snake_state(3)
    local gold = 100
    local unit_defs = make_unit_defs()

    local vm = shop_ui.get_view_model(shop_state, snake_state, gold, unit_defs)

    test.assert_eq(vm.gold, 100, "View model has gold")
    test.assert_true(vm.offers ~= nil, "View model has offers array")
    test.assert_true(vm.reroll ~= nil, "View model has reroll info")
    test.assert_true(vm.ready ~= nil, "View model has ready info")
    test.assert_eq(#vm.offers, 5, "View model has 5 offer slots")

    print("\226\156\147 View model structure correct")
end

function test.test_view_model_nil_shop_state()
    print("\n=== Test: View Model Nil Shop State ===")

    local vm = shop_ui.get_view_model(nil, nil, 50, {})

    test.assert_eq(vm.gold, 50, "Gold preserved with nil shop state")
    test.assert_eq(#vm.offers, 5, "Still has 5 offer slots")

    -- All slots should be empty
    for i = 1, 5 do
        test.assert_true(vm.offers[i].empty, string.format("Slot %d is empty", i))
    end

    print("\226\156\147 Nil shop state handled correctly")
end

--===========================================================================
-- TEST: View Model - Offer Slots
--===========================================================================

function test.test_offer_slot_available()
    print("\n=== Test: Offer Slot Available ===")

    local shop_state = make_shop_state({
        make_offer("soldier", 3, false)
    })
    local snake_state = make_snake_state(3)  -- Room to buy more
    local gold = 10
    local unit_defs = make_unit_defs()

    local vm = shop_ui.get_view_model(shop_state, snake_state, gold, unit_defs)
    local slot = vm.offers[1]

    test.assert_false(slot.empty, "Slot is not empty")
    test.assert_eq(slot.def_id, "soldier", "Correct def_id")
    test.assert_eq(slot.cost, 3, "Correct cost")
    test.assert_eq(slot.unit_name, "Soldier", "Correct unit name from unit_defs")
    test.assert_true(slot.can_afford, "Can afford (10 gold >= 3 cost)")
    test.assert_true(slot.can_buy, "Can buy (has room)")

    print("\226\156\147 Available offer slot correct")
end

function test.test_offer_slot_sold()
    print("\n=== Test: Offer Slot Sold ===")

    local shop_state = make_shop_state({
        make_offer("soldier", 3, true)  -- sold = true
    })
    local snake_state = make_snake_state(3)
    local gold = 100
    local unit_defs = make_unit_defs()

    local vm = shop_ui.get_view_model(shop_state, snake_state, gold, unit_defs)
    local slot = vm.offers[1]

    test.assert_true(slot.empty, "Sold slot is empty")
    test.assert_eq(slot.unit_name, "SOLD", "Sold slot shows SOLD")

    print("\226\156\147 Sold offer slot correct")
end

function test.test_offer_slot_cannot_afford()
    print("\n=== Test: Offer Slot Cannot Afford ===")

    local shop_state = make_shop_state({
        make_offer("knight", 4, false)
    })
    local snake_state = make_snake_state(3)
    local gold = 2  -- Not enough gold
    local unit_defs = make_unit_defs()

    local vm = shop_ui.get_view_model(shop_state, snake_state, gold, unit_defs)
    local slot = vm.offers[1]

    test.assert_false(slot.can_afford, "Cannot afford (2 gold < 4 cost)")
    test.assert_false(slot.can_buy, "Cannot buy (not enough gold)")

    print("\226\156\147 Cannot afford slot correct")
end

function test.test_offer_slot_snake_at_max()
    print("\n=== Test: Offer Slot Snake at Max Length ===")

    local shop_state = make_shop_state({
        make_offer("soldier", 3, false)
    })
    local snake_state = make_snake_state(8, 3, 8)  -- At max length
    local gold = 100
    local unit_defs = make_unit_defs()

    local vm = shop_ui.get_view_model(shop_state, snake_state, gold, unit_defs)
    local slot = vm.offers[1]

    test.assert_true(slot.can_afford, "Can afford")
    test.assert_false(slot.can_buy, "Cannot buy (snake at max length)")

    print("\226\156\147 Snake at max length prevents buying")
end

function test.test_offer_slots_mixed()
    print("\n=== Test: Mixed Offer Slots ===")

    local shop_state = make_shop_state({
        make_offer("soldier", 3, false),   -- Available, affordable
        make_offer("knight", 4, false),    -- Available, affordable
        make_offer("mage", 5, false),      -- Available, unaffordable
        make_offer("soldier", 3, true),    -- Sold
        nil                                 -- Empty (nil)
    })
    local snake_state = make_snake_state(3)
    local gold = 4
    local unit_defs = make_unit_defs()

    local vm = shop_ui.get_view_model(shop_state, snake_state, gold, unit_defs)

    -- Slot 1: soldier, affordable
    test.assert_false(vm.offers[1].empty, "Slot 1 not empty")
    test.assert_true(vm.offers[1].can_afford, "Slot 1 affordable")

    -- Slot 2: knight, exactly affordable
    test.assert_false(vm.offers[2].empty, "Slot 2 not empty")
    test.assert_true(vm.offers[2].can_afford, "Slot 2 affordable (4 == 4)")

    -- Slot 3: mage, too expensive
    test.assert_false(vm.offers[3].empty, "Slot 3 not empty")
    test.assert_false(vm.offers[3].can_afford, "Slot 3 not affordable (4 < 5)")

    -- Slot 4: sold
    test.assert_true(vm.offers[4].empty, "Slot 4 is sold/empty")

    -- Slot 5: nil/empty
    test.assert_true(vm.offers[5].empty, "Slot 5 is empty")

    print("\226\156\147 Mixed offer slots correct")
end

function test.test_offer_unknown_unit()
    print("\n=== Test: Offer Unknown Unit ===")

    local shop_state = make_shop_state({
        make_offer("unknown_unit", 5, false)
    })
    local snake_state = make_snake_state(3)
    local gold = 10
    local unit_defs = {}  -- No definitions

    local vm = shop_ui.get_view_model(shop_state, snake_state, gold, unit_defs)
    local slot = vm.offers[1]

    test.assert_eq(slot.unit_name, "unknown_unit", "Falls back to def_id when no unit_def")

    print("\226\156\147 Unknown unit falls back to def_id")
end

--===========================================================================
-- TEST: View Model - Reroll Button
--===========================================================================

function test.test_reroll_base_cost()
    print("\n=== Test: Reroll Base Cost ===")

    local shop_state = make_shop_state({}, 0)  -- No rerolls yet
    local vm = shop_ui.get_view_model(shop_state, nil, 10, {})

    test.assert_eq(vm.reroll.cost, 2, "Base reroll cost is 2")
    test.assert_true(vm.reroll.can_afford, "Can afford reroll with 10 gold")

    print("\226\156\147 Base reroll cost correct")
end

function test.test_reroll_cost_increases()
    print("\n=== Test: Reroll Cost Increases ===")

    -- After 3 rerolls, cost should be 2 + 3 = 5
    local shop_state = make_shop_state({}, 3)
    local vm = shop_ui.get_view_model(shop_state, nil, 10, {})

    test.assert_eq(vm.reroll.cost, 5, "Reroll cost is 5 after 3 rerolls (2 + 3)")

    print("\226\156\147 Reroll cost increment correct")
end

function test.test_reroll_cannot_afford()
    print("\n=== Test: Reroll Cannot Afford ===")

    local shop_state = make_shop_state({}, 5)  -- Cost will be 2 + 5 = 7
    local vm = shop_ui.get_view_model(shop_state, nil, 5, {})

    test.assert_eq(vm.reroll.cost, 7, "Reroll cost is 7")
    test.assert_false(vm.reroll.can_afford, "Cannot afford reroll (5 < 7)")

    print("\226\156\147 Reroll affordability correct")
end

function test.test_reroll_exactly_afford()
    print("\n=== Test: Reroll Exactly Afford ===")

    local shop_state = make_shop_state({}, 0)  -- Cost = 2
    local vm = shop_ui.get_view_model(shop_state, nil, 2, {})

    test.assert_true(vm.reroll.can_afford, "Can afford reroll with exactly enough gold")

    print("\226\156\147 Reroll exact affordability correct")
end

--===========================================================================
-- TEST: View Model - Ready Button (min length check)
--===========================================================================

function test.test_ready_button_enabled_at_min_length()
    print("\n=== Test: Ready Button Enabled at Min Length ===")

    local snake_state = make_snake_state(3, 3, 8)  -- Exactly at min_len
    local vm = shop_ui.get_view_model({}, snake_state, 0, {})

    test.assert_true(vm.ready.enabled, "Ready enabled at min length (3 >= 3)")
    test.assert_eq(vm.ready.current_length, 3, "Current length is 3")
    test.assert_eq(vm.ready.min_length, 3, "Min length is 3")

    print("\226\156\147 Ready button enabled at min length")
end

function test.test_ready_button_enabled_above_min()
    print("\n=== Test: Ready Button Enabled Above Min Length ===")

    local snake_state = make_snake_state(5, 3, 8)  -- Above min_len
    local vm = shop_ui.get_view_model({}, snake_state, 0, {})

    test.assert_true(vm.ready.enabled, "Ready enabled above min (5 >= 3)")

    print("\226\156\147 Ready button enabled above min length")
end

function test.test_ready_button_disabled_below_min()
    print("\n=== Test: Ready Button Disabled Below Min Length ===")

    local snake_state = make_snake_state(2, 3, 8)  -- Below min_len
    local vm = shop_ui.get_view_model({}, snake_state, 0, {})

    test.assert_false(vm.ready.enabled, "Ready disabled below min (2 < 3)")
    test.assert_eq(vm.ready.current_length, 2, "Current length is 2")

    print("\226\156\147 Ready button disabled below min length")
end

function test.test_ready_button_disabled_empty_snake()
    print("\n=== Test: Ready Button Disabled Empty Snake ===")

    local snake_state = make_snake_state(0, 3, 8)  -- Empty snake
    local vm = shop_ui.get_view_model({}, snake_state, 0, {})

    test.assert_false(vm.ready.enabled, "Ready disabled with empty snake (0 < 3)")

    print("\226\156\147 Ready button disabled with empty snake")
end

function test.test_ready_button_nil_snake_state()
    print("\n=== Test: Ready Button with Nil Snake State ===")

    local vm = shop_ui.get_view_model({}, nil, 0, {})

    test.assert_false(vm.ready.enabled, "Ready disabled with nil snake (0 < 3)")
    test.assert_eq(vm.ready.current_length, 0, "Current length is 0 for nil")
    test.assert_eq(vm.ready.min_length, 3, "Default min length is 3")

    print("\226\156\147 Ready button handles nil snake state")
end

--===========================================================================
-- TEST: Sell View-Model
--===========================================================================

function test.test_sell_view_model_nil_snake()
    print("\n=== Test: Sell View Model Nil Snake ===")

    local vm = shop_ui.get_sell_view_model(nil, {})

    test.assert_eq(#vm.segments, 0, "No segments for nil snake")
    test.assert_eq(vm.total_segments, 0, "Total segments is 0")
    test.assert_false(vm.any_sellable, "None sellable for nil snake")

    print("\226\156\147 Nil snake sell view-model correct")
end

function test.test_sell_view_model_at_min_length()
    print("\n=== Test: Sell View Model at Min Length ===")

    local snake_state = make_snake_state(3, 3, 8)  -- At min_len = 3
    local vm = shop_ui.get_sell_view_model(snake_state, make_unit_defs())

    test.assert_eq(vm.total_segments, 3, "Total segments is 3")
    test.assert_eq(vm.min_length, 3, "Min length is 3")
    test.assert_false(vm.any_sellable, "None sellable at min length")
    test.assert_eq(vm.can_sell_count, 0, "Can sell count is 0")

    -- Each segment should have can_sell = false
    for i = 1, 3 do
        test.assert_false(vm.segments[i].can_sell, string.format("Segment %d not sellable", i))
        test.assert_true(vm.segments[i].sell_blocked_reason ~= nil, string.format("Segment %d has blocked reason", i))
    end

    print("\226\156\147 At min length sell view-model correct")
end

function test.test_sell_view_model_above_min_length()
    print("\n=== Test: Sell View Model Above Min Length ===")

    local snake_state = make_snake_state(5, 3, 8)  -- Above min_len
    local vm = shop_ui.get_sell_view_model(snake_state, make_unit_defs())

    test.assert_eq(vm.total_segments, 5, "Total segments is 5")
    test.assert_true(vm.any_sellable, "Some sellable above min length")
    test.assert_eq(vm.can_sell_count, 5, "All 5 can be sold (5 > 3)")

    -- All segments should be sellable
    for i = 1, 5 do
        test.assert_true(vm.segments[i].can_sell, string.format("Segment %d sellable", i))
        test.assert_eq(vm.segments[i].sell_blocked_reason, nil, string.format("Segment %d no blocked reason", i))
    end

    print("\226\156\147 Above min length sell view-model correct")
end

function test.test_sell_view_model_segment_data()
    print("\n=== Test: Sell View Model Segment Data ===")

    local snake_state = make_snake_state(4, 3, 8)
    local unit_defs = make_unit_defs()
    local vm = shop_ui.get_sell_view_model(snake_state, unit_defs)

    local segment = vm.segments[1]

    test.assert_eq(segment.index, 1, "Index is 1")
    test.assert_eq(segment.instance_id, 1, "Instance ID is 1")
    test.assert_eq(segment.def_id, "soldier", "Def ID is soldier")
    test.assert_eq(segment.unit_name, "Soldier", "Unit name from unit_defs")
    test.assert_eq(segment.level, 1, "Level is 1")

    print("\226\156\147 Segment data in sell view-model correct")
end

function test.test_sell_view_model_unknown_unit()
    print("\n=== Test: Sell View Model Unknown Unit ===")

    -- Create snake with unknown unit type
    local snake_state = {
        segments = {{ instance_id = 1, def_id = "unknown", level = 2 }},
        min_len = 1,
        max_len = 8
    }
    local vm = shop_ui.get_sell_view_model(snake_state, {})

    test.assert_eq(vm.segments[1].unit_name, "unknown", "Falls back to def_id")

    print("\226\156\147 Unknown unit in sell view-model correct")
end

--===========================================================================
-- TEST: View Model - Edge Cases
--===========================================================================

function test.test_empty_shop_state()
    print("\n=== Test: Empty Shop State ===")

    local shop_state = { offers = {} }
    local vm = shop_ui.get_view_model(shop_state, nil, 50, {})

    for i = 1, 5 do
        test.assert_true(vm.offers[i].empty, string.format("Slot %d empty", i))
    end

    print("\226\156\147 Empty shop state handled")
end

function test.test_zero_gold()
    print("\n=== Test: Zero Gold ===")

    local shop_state = make_shop_state({
        make_offer("soldier", 3, false)
    })
    local vm = shop_ui.get_view_model(shop_state, nil, 0, {})

    test.assert_eq(vm.gold, 0, "Gold is 0")
    test.assert_false(vm.offers[1].can_afford, "Cannot afford with 0 gold")
    test.assert_false(vm.reroll.can_afford, "Cannot reroll with 0 gold")

    print("\226\156\147 Zero gold edge case handled")
end

function test.test_large_gold()
    print("\n=== Test: Large Gold Amount ===")

    local shop_state = make_shop_state({
        make_offer("soldier", 3, false)
    })
    local snake_state = make_snake_state(3)
    local vm = shop_ui.get_view_model(shop_state, snake_state, 9999, {})

    test.assert_eq(vm.gold, 9999, "Gold is 9999")
    test.assert_true(vm.offers[1].can_afford, "Can afford with large gold")
    test.assert_true(vm.reroll.can_afford, "Can reroll with large gold")

    print("\226\156\147 Large gold amount handled")
end

--===========================================================================
-- RUN ALL TESTS
--===========================================================================

function test.run_all()
    print("================================================================================")
    print("TEST SUITE: Shop UI View-Model Helpers (bd-36o3)")
    print("================================================================================")

    -- Structure tests
    test.test_view_model_structure()
    test.test_view_model_nil_shop_state()

    -- Offer slot tests
    test.test_offer_slot_available()
    test.test_offer_slot_sold()
    test.test_offer_slot_cannot_afford()
    test.test_offer_slot_snake_at_max()
    test.test_offer_slots_mixed()
    test.test_offer_unknown_unit()

    -- Reroll tests
    test.test_reroll_base_cost()
    test.test_reroll_cost_increases()
    test.test_reroll_cannot_afford()
    test.test_reroll_exactly_afford()

    -- Ready button tests (min length check)
    test.test_ready_button_enabled_at_min_length()
    test.test_ready_button_enabled_above_min()
    test.test_ready_button_disabled_below_min()
    test.test_ready_button_disabled_empty_snake()
    test.test_ready_button_nil_snake_state()

    -- Sell view-model tests
    test.test_sell_view_model_nil_snake()
    test.test_sell_view_model_at_min_length()
    test.test_sell_view_model_above_min_length()
    test.test_sell_view_model_segment_data()
    test.test_sell_view_model_unknown_unit()

    -- Edge cases
    test.test_empty_shop_state()
    test.test_zero_gold()
    test.test_large_gold()

    print("\n================================================================================")
    print(string.format("RESULTS: %d passed, %d failed", test.passed, test.failed))
    print("================================================================================")

    return test.failed == 0
end

-- Execute tests if run directly
if arg and arg[0] and arg[0]:match("test_shop_ui") then
    local success = test.run_all()
    os.exit(success and 0 or 1)
end

return test
