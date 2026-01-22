--[[
================================================================================
TEST: Procedural Generation DSL
================================================================================
Tests for the procgen module: range, loot tables, and roll functionality.

TDD Approach:
- RED: Tests fail before implementation
- GREEN: Implement, tests pass

Run with: lua assets/scripts/tests/test_procgen.lua
]]

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

-- Clear cached module
package.loaded["core.procgen"] = nil
_G.procgen = nil

local t = require("tests.test_runner")

--------------------------------------------------------------------------------
-- Tests: Module existence
--------------------------------------------------------------------------------

t.describe("procgen - Module API", function()

    t.it("can be required", function()
        local procgen = require("core.procgen")
        t.expect(procgen).to_be_truthy()
    end)

    t.it("has range function", function()
        local procgen = require("core.procgen")
        t.expect(type(procgen.range)).to_be("function")
    end)

    t.it("has loot function", function()
        local procgen = require("core.procgen")
        t.expect(type(procgen.loot)).to_be("function")
    end)

    t.it("has constant function", function()
        local procgen = require("core.procgen")
        t.expect(type(procgen.constant)).to_be("function")
    end)

    t.it("has create_rng function", function()
        local procgen = require("core.procgen")
        t.expect(type(procgen.create_rng)).to_be("function")
    end)
end)

--------------------------------------------------------------------------------
-- Tests: procgen.range
--------------------------------------------------------------------------------

t.describe("procgen.range", function()

    t.it("creates a range object", function()
        local procgen = require("core.procgen")
        local r = procgen.range(1, 10)
        t.expect(r).to_be_truthy()
        t.expect(r.min).to_be(1)
        t.expect(r.max).to_be(10)
    end)

    t.it("range can be rolled", function()
        local procgen = require("core.procgen")
        local r = procgen.range(5, 15)
        local rng = procgen.create_rng(12345)

        local value = r:roll(rng)
        t.expect(type(value)).to_be("number")
        t.expect(value >= 5).to_be(true)
        t.expect(value <= 15).to_be(true)
    end)

    t.it("range is deterministic with same seed", function()
        local procgen = require("core.procgen")
        local r = procgen.range(1, 100)

        local rng1 = procgen.create_rng(42)
        local rng2 = procgen.create_rng(42)

        local v1 = r:roll(rng1)
        local v2 = r:roll(rng2)
        t.expect(v1).to_be(v2)
    end)

    t.it("range produces different values with different seeds", function()
        local procgen = require("core.procgen")
        local r = procgen.range(1, 1000)

        local rng1 = procgen.create_rng(111)
        local rng2 = procgen.create_rng(222)

        local v1 = r:roll(rng1)
        local v2 = r:roll(rng2)
        -- Very unlikely to be equal with range 1-1000
        t.expect(v1 == v2).to_be(false)
    end)

    t.it("range with same min/max returns that value", function()
        local procgen = require("core.procgen")
        local r = procgen.range(42, 42)
        local rng = procgen.create_rng(1)

        local value = r:roll(rng)
        t.expect(value).to_be(42)
    end)
end)

--------------------------------------------------------------------------------
-- Tests: procgen.constant
--------------------------------------------------------------------------------

t.describe("procgen.constant", function()

    t.it("creates a constant that doesn't scale", function()
        local procgen = require("core.procgen")
        local c = procgen.constant(50)
        t.expect(c).to_be_truthy()
        t.expect(c.value).to_be(50)
    end)

    t.it("constant roll returns the value", function()
        local procgen = require("core.procgen")
        local c = procgen.constant(100)
        local rng = procgen.create_rng(1)

        local value = c:roll(rng)
        t.expect(value).to_be(100)
    end)

    t.it("constant with no argument returns 0", function()
        local procgen = require("core.procgen")
        local c = procgen.constant()
        local rng = procgen.create_rng(1)

        t.expect(c:roll(rng)).to_be(0)
    end)
end)

--------------------------------------------------------------------------------
-- Tests: procgen.loot - Basic weighted selection
--------------------------------------------------------------------------------

t.describe("procgen.loot - Basic weighted selection", function()

    t.it("creates a loot table", function()
        local procgen = require("core.procgen")
        local loot = procgen.loot {
            { item = "gold", weight = 50 },
            { item = "sword", weight = 10 }
        }
        t.expect(loot).to_be_truthy()
        t.expect(type(loot.roll)).to_be("function")
    end)

    t.it("returns items from the loot table", function()
        local procgen = require("core.procgen")
        local loot = procgen.loot {
            { item = "gold", weight = 50 },
            { item = "sword", weight = 50 }
        }
        local rng = procgen.create_rng(12345)
        local ctx = { rng = rng }

        local result = loot:roll(ctx)
        t.expect(result).to_be_truthy()
        t.expect(#result >= 1).to_be(true)

        local item = result[1]
        t.expect(item.item == "gold" or item.item == "sword").to_be(true)
    end)

    t.it("respects weight distribution", function()
        local procgen = require("core.procgen")
        local loot = procgen.loot {
            { item = "common", weight = 90 },
            { item = "rare", weight = 10 }
        }

        local common_count = 0
        local rare_count = 0

        -- Roll 100 times with different seeds
        for seed = 1, 100 do
            local rng = procgen.create_rng(seed)
            local result = loot:roll({ rng = rng })
            if result[1].item == "common" then
                common_count = common_count + 1
            else
                rare_count = rare_count + 1
            end
        end

        -- Common should appear much more frequently
        t.expect(common_count > rare_count).to_be(true)
    end)

    t.it("is deterministic with same seed", function()
        local procgen = require("core.procgen")
        local loot = procgen.loot {
            { item = "gold", weight = 50 },
            { item = "sword", weight = 50 }
        }

        local rng1 = procgen.create_rng(42)
        local rng2 = procgen.create_rng(42)

        local result1 = loot:roll({ rng = rng1 })
        local result2 = loot:roll({ rng = rng2 })

        t.expect(result1[1].item).to_be(result2[1].item)
    end)
end)

--------------------------------------------------------------------------------
-- Tests: procgen.loot - Amount ranges
--------------------------------------------------------------------------------

t.describe("procgen.loot - Amount ranges", function()

    t.it("supports fixed amount", function()
        local procgen = require("core.procgen")
        local loot = procgen.loot {
            { item = "gold", weight = 100, amount = 50 }
        }
        local rng = procgen.create_rng(1)

        local result = loot:roll({ rng = rng })
        t.expect(result[1].amount).to_be(50)
    end)

    t.it("supports range amount with procgen.range", function()
        local procgen = require("core.procgen")
        local loot = procgen.loot {
            { item = "gold", weight = 100, amount = procgen.range(10, 50) }
        }
        local rng = procgen.create_rng(42)

        local result = loot:roll({ rng = rng })
        t.expect(result[1].amount >= 10).to_be(true)
        t.expect(result[1].amount <= 50).to_be(true)
    end)

    t.it("defaults to amount = 1 if not specified", function()
        local procgen = require("core.procgen")
        local loot = procgen.loot {
            { item = "sword", weight = 100 }
        }
        local rng = procgen.create_rng(1)

        local result = loot:roll({ rng = rng })
        t.expect(result[1].amount).to_be(1)
    end)
end)

--------------------------------------------------------------------------------
-- Tests: procgen.loot - Conditions
--------------------------------------------------------------------------------

t.describe("procgen.loot - Conditions", function()

    t.it("supports condition predicates", function()
        local procgen = require("core.procgen")
        local loot = procgen.loot {
            { item = "basic_sword", weight = 50 },
            { item = "epic_sword", weight = 50, condition = function(ctx)
                return ctx.player and ctx.player.level >= 10
            end }
        }

        -- Low level player - should only get basic_sword
        local rng = procgen.create_rng(1)
        local ctx_low = { rng = rng, player = { level = 5 } }

        -- Roll many times, epic_sword should never appear
        local got_epic = false
        for seed = 1, 20 do
            local r = procgen.create_rng(seed)
            local result = loot:roll({ rng = r, player = { level = 5 } })
            if result[1].item == "epic_sword" then got_epic = true end
        end
        t.expect(got_epic).to_be(false)
    end)

    t.it("eligible items when condition passes", function()
        local procgen = require("core.procgen")
        local loot = procgen.loot {
            { item = "epic_sword", weight = 100, condition = function(ctx)
                return ctx.player and ctx.player.level >= 10
            end }
        }

        local rng = procgen.create_rng(1)
        local result = loot:roll({ rng = rng, player = { level = 15 } })
        t.expect(result[1].item).to_be("epic_sword")
    end)

    t.it("returns empty if no items eligible", function()
        local procgen = require("core.procgen")
        local loot = procgen.loot {
            { item = "epic_sword", weight = 100, condition = function(ctx)
                return false  -- Never eligible
            end }
        }

        local rng = procgen.create_rng(1)
        local result = loot:roll({ rng = rng })
        t.expect(#result).to_be(0)
    end)
end)

--------------------------------------------------------------------------------
-- Tests: procgen.loot - Guaranteed drops
--------------------------------------------------------------------------------

t.describe("procgen.loot - Guaranteed drops", function()

    t.it("supports guaranteed drops", function()
        local procgen = require("core.procgen")
        local loot = procgen.loot {
            { item = "random_gold", weight = 100 },
            guaranteed = {
                { item = "quest_key" }
            }
        }

        local rng = procgen.create_rng(1)
        local result = loot:roll({ rng = rng })

        -- Should have both the random item AND the guaranteed item
        local has_key = false
        for _, drop in ipairs(result) do
            if drop.item == "quest_key" then has_key = true end
        end
        t.expect(has_key).to_be(true)
    end)

    t.it("guaranteed drops can have conditions", function()
        local procgen = require("core.procgen")
        local loot = procgen.loot {
            { item = "gold", weight = 100 },
            guaranteed = {
                { item = "key", condition = function(ctx)
                    return not ctx.player.has_key
                end }
            }
        }

        -- Player doesn't have key - should get it
        local rng1 = procgen.create_rng(1)
        local result1 = loot:roll({ rng = rng1, player = { has_key = false } })
        local has_key1 = false
        for _, drop in ipairs(result1) do
            if drop.item == "key" then has_key1 = true end
        end
        t.expect(has_key1).to_be(true)

        -- Player has key - should NOT get it
        local rng2 = procgen.create_rng(1)
        local result2 = loot:roll({ rng = rng2, player = { has_key = true } })
        local has_key2 = false
        for _, drop in ipairs(result2) do
            if drop.item == "key" then has_key2 = true end
        end
        t.expect(has_key2).to_be(false)
    end)
end)

--------------------------------------------------------------------------------
-- Tests: procgen.loot - Multiple picks
--------------------------------------------------------------------------------

t.describe("procgen.loot - Multiple picks", function()

    t.it("supports picks as fixed number", function()
        local procgen = require("core.procgen")
        local loot = procgen.loot {
            { item = "gold", weight = 50 },
            { item = "gem", weight = 50 },
            picks = 3
        }

        local rng = procgen.create_rng(42)
        local result = loot:roll({ rng = rng })

        -- Should have 3 items (excluding guaranteed)
        t.expect(#result).to_be(3)
    end)

    t.it("supports picks as range", function()
        local procgen = require("core.procgen")
        local loot = procgen.loot {
            { item = "gold", weight = 100 },
            picks = procgen.range(1, 3)
        }

        local rng = procgen.create_rng(123)
        local result = loot:roll({ rng = rng })

        t.expect(#result >= 1).to_be(true)
        t.expect(#result <= 3).to_be(true)
    end)

    t.it("defaults to picks = 1", function()
        local procgen = require("core.procgen")
        local loot = procgen.loot {
            { item = "gold", weight = 100 }
        }

        local rng = procgen.create_rng(1)
        local result = loot:roll({ rng = rng })

        t.expect(#result).to_be(1)
    end)
end)

--------------------------------------------------------------------------------
-- Tests: procgen.loot - Debug output
--------------------------------------------------------------------------------

t.describe("procgen.loot - Debug output", function()

    t.it("can explain the roll in debug mode", function()
        local procgen = require("core.procgen")
        local loot = procgen.loot {
            { item = "gold", weight = 50 },
            { item = "gem", weight = 50 }
        }

        local rng = procgen.create_rng(1)
        local result, debug_info = loot:roll({ rng = rng, debug = true })

        t.expect(debug_info).to_be_truthy()
        t.expect(debug_info.total_weight).to_be(100)
        t.expect(debug_info.rolls).to_be_truthy()
        t.expect(#debug_info.rolls >= 1).to_be(true)
    end)

    t.it("debug_info shows eligible items", function()
        local procgen = require("core.procgen")
        local loot = procgen.loot {
            { item = "common", weight = 90 },
            { item = "rare", weight = 10, condition = function() return false end }
        }

        local rng = procgen.create_rng(1)
        local result, debug_info = loot:roll({ rng = rng, debug = true })

        t.expect(debug_info.eligible_items).to_be_truthy()
        t.expect(#debug_info.eligible_items).to_be(1)  -- Only common is eligible
        t.expect(debug_info.eligible_items[1].item).to_be("common")
    end)
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

local success = t.run()
os.exit(success and 0 or 1)
