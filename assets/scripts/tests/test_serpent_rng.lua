--[[
================================================================================
TEST: Serpent RNG
================================================================================
Tests for deterministic RNG utilities used by Serpent mode.

Run with: lua assets/scripts/tests/test_serpent_rng.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

package.loaded["serpent.rng"] = nil

local t = require("tests.test_runner")

t.describe("serpent.rng - Module API", function()
    t.it("can be required", function()
        local RNG = require("serpent.rng")
        t.expect(RNG).to_be_truthy()
    end)

    t.it("exposes RNG.new constructor", function()
        local RNG = require("serpent.rng")
        t.expect(type(RNG.new)).to_be("function")
    end)
end)

t.describe("serpent.rng - Determinism", function()
    t.it("stores seed for HUD display", function()
        local RNG = require("serpent.rng")
        local rng = RNG.new(12345)
        t.expect(rng.seed).to_be(12345)
    end)

    t.it("produces same sequence with same seed", function()
        local RNG = require("serpent.rng")
        local rng1 = RNG.new(42)
        local rng2 = RNG.new(42)
        t.expect(rng1:next_u32()).to_be(rng2:next_u32())
        t.expect(rng1:int(1, 100)).to_be(rng2:int(1, 100))
        t.expect(rng1:float(0, 1)).to_be(rng2:float(0, 1))
    end)

    t.it("reseed updates seed", function()
        local RNG = require("serpent.rng")
        local rng = RNG.new(7)
        rng:reseed(99)
        t.expect(rng.seed).to_be(99)
    end)

    t.it("different seeds diverge", function()
        local RNG = require("serpent.rng")
        local rng1 = RNG.new(12345)
        local rng2 = RNG.new(54321)

        -- Different seeds should produce different sequences
        t.expect(rng1:next_u32()).never().to_be(rng2:next_u32())
        t.expect(rng1:int(1, 100)).never().to_be(rng2:int(1, 100))
        t.expect(rng1:float(0, 1)).never().to_be(rng2:float(0, 1))
    end)
end)

t.describe("serpent.rng - Bounds Testing", function()
    t.it("int inclusive bounds work correctly", function()
        local RNG = require("serpent.rng")
        local rng = RNG.new(42)

        -- Test single value bounds
        t.expect(rng:int(5, 5)).to_be(5)

        -- Test range bounds by generating many values
        local all_in_bounds = true
        for i = 1, 100 do
            local val = rng:int(10, 15)
            if val < 10 or val > 15 then
                all_in_bounds = false
                break
            end
        end
        t.expect(all_in_bounds).to_be(true)

        -- Test negative bounds
        local neg_val = rng:int(-5, -1)
        local in_neg_bounds = (neg_val >= -5 and neg_val <= -1)
        t.expect(in_neg_bounds).to_be(true)
    end)

    t.it("choice consumes one int", function()
        local RNG = require("serpent.rng")
        local rng1 = RNG.new(777)
        local rng2 = RNG.new(777)

        local list = {"a", "b", "c", "d", "e"}

        -- choice() should consume same amount as int(1, #list)
        local choice_result = rng1:choice(list)
        local int_result = rng2:int(1, #list)

        -- Verify choice returned valid item
        local found = false
        for _, item in ipairs(list) do
            if item == choice_result then
                found = true
                break
            end
        end
        t.expect(found).to_be(true)

        -- Both RNGs should be in same state after consuming one value
        t.expect(rng1:next_u32()).to_be(rng2:next_u32())
    end)
end)

local success = t.run()
os.exit(success and 0 or 1)
