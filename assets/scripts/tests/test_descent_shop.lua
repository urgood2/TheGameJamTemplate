-- assets/scripts/tests/test_descent_shop.lua
--[[
================================================================================
DESCENT SHOP TESTS
================================================================================
Validates shop availability, deterministic stock generation, purchase behavior,
and reroll rules.
]]

local t = require("tests.test_runner")
local Shop = require("descent.shop")
local Items = require("descent.items")
local rng = require("descent.rng")
local spec = require("descent.spec")

local rng_stub = {
    init = function(seed)
        return rng.init(seed)
    end,
    random_int = function(min, max)
        return rng.random(min, max)
    end,
}

local function setup_shop(seed, floor)
    Items.init()
    Shop.init(rng_stub, Items)
    Shop.generate(floor, seed)
end

local function snapshot_stock()
    local stock = Shop.get_stock()
    local snapshot = {}
    for i, entry in ipairs(stock) do
        snapshot[i] = {
            id = entry.item and entry.item.template_id or nil,
            price = entry.price,
        }
    end
    return snapshot
end

--------------------------------------------------------------------------------
-- Availability
--------------------------------------------------------------------------------

t.describe("Descent Shop - Availability", function()
    t.it("opens on floor 1 and not on floor 2", function()
        setup_shop(1001, 1)
        t.expect(Shop.has_shop(1)).to_be(true)
        t.expect(Shop.is_open()).to_be(true)

        local stock = Shop.get_stock()
        t.expect(#stock >= 4).to_be(true)
        t.expect(#stock <= 6).to_be(true)

        setup_shop(1001, 2)
        t.expect(Shop.has_shop(2)).to_be(false)
        t.expect(Shop.is_open()).to_be(false)
        t.expect(#Shop.get_stock()).to_be(0)
    end)
end)

--------------------------------------------------------------------------------
-- Stock determinism
--------------------------------------------------------------------------------

t.describe("Descent Shop - Stock determinism", function()
    t.it("generates deterministic stock for same seed", function()
        setup_shop(4242, 1)
        local stock1 = snapshot_stock()

        setup_shop(4242, 1)
        local stock2 = snapshot_stock()

        t.expect(stock1).to_equal(stock2)
    end)
end)

--------------------------------------------------------------------------------
-- Purchase behavior
--------------------------------------------------------------------------------

t.describe("Descent Shop - Purchase", function()
    t.it("rejects purchase without enough gold", function()
        setup_shop(777, 1)
        local stock = Shop.get_stock()
        local entry = stock[1]
        t.expect(entry).to_be_truthy()

        local player = { gold = entry.price - 1 }
        local result, purchased, cost = Shop.purchase(player, 1)

        t.expect(result).to_be(Shop.RESULT.INSUFFICIENT_GOLD)
        t.expect(purchased).to_be_nil()
        t.expect(cost).to_be(0)
        t.expect(player.gold).to_be(entry.price - 1)

        local after = Shop.get_stock()
        t.expect(after[1].sold).to_be(false)
        t.expect(after[1].price).to_be(entry.price)
    end)

    t.it("purchases atomically and marks item sold", function()
        setup_shop(888, 1)
        local stock = Shop.get_stock()
        local entry = stock[1]
        t.expect(entry).to_be_truthy()

        local player = { gold = entry.price }
        local result, purchased, cost = Shop.purchase(player, 1)

        t.expect(result).to_be(Shop.RESULT.SUCCESS)
        t.expect(cost).to_be(spec.inventory.use.cost)
        t.expect(player.gold).to_be(0)
        t.expect(purchased).to_be_truthy()
        t.expect(purchased.template_id).to_be(entry.item.template_id)

        local after = Shop.get_stock()
        t.expect(after[1].sold).to_be(true)
        t.expect(#Shop.get_available()).to_be(#after - 1)
    end)
end)

--------------------------------------------------------------------------------
-- Reroll behavior
--------------------------------------------------------------------------------

t.describe("Descent Shop - Reroll", function()
    t.it("enforces cost and reroll determinism", function()
        setup_shop(1357, 1)
        local stock1 = snapshot_stock()
        local cost = Shop.get_reroll_cost()

        local poor = { gold = cost - 1 }
        local result = Shop.reroll(poor)
        t.expect(result).to_be(Shop.RESULT.INSUFFICIENT_GOLD)
        t.expect(poor.gold).to_be(cost - 1)
        t.expect(snapshot_stock()).to_equal(stock1)

        local rich = { gold = cost * 5 }
        local result2 = Shop.reroll(rich)
        t.expect(result2).to_be(Shop.RESULT.SUCCESS)
        t.expect(rich.gold).to_be(cost * 5 - cost)
        t.expect(Shop.get_reroll_cost()).to_be(cost * 2)
        local stock2 = snapshot_stock()

        setup_shop(1357, 1)
        local cost2 = Shop.get_reroll_cost()
        local rich2 = { gold = cost2 * 5 }
        Shop.reroll(rich2)
        local stock2b = snapshot_stock()

        t.expect(stock2).to_equal(stock2b)
    end)
end)

