-- assets/scripts/tests/test_descent_rng.lua
--[[
================================================================================
DESCENT RNG DETERMINISM TESTS
================================================================================
Validates deterministic sequences from the RNG adapter.
]]

local t = require("tests.test_runner")
local rng = require("descent.rng")
local combat = require("descent.combat")

t.describe("Descent RNG", function()
  t.it("same seed produces identical sequences", function()
    rng.init(12345)
    local seq1 = {
      rng.random(),
      rng.random(10),
      rng.random(5, 10),
      rng.random(1, 100),
    }

    rng.init(12345)
    local seq2 = {
      rng.random(),
      rng.random(10),
      rng.random(5, 10),
      rng.random(1, 100),
    }

    for i = 1, #seq1 do
      t.expect(seq1[i]).to_be(seq2[i])
    end
  end)

  t.it("choice is deterministic with same seed", function()
    local list = { "a", "b", "c", "d" }

    rng.init(999)
    local pick1 = rng.choice(list)
    local pick2 = rng.choice(list)

    rng.init(999)
    local pick1b = rng.choice(list)
    local pick2b = rng.choice(list)

    t.expect(pick1).to_be(pick1b)
    t.expect(pick2).to_be(pick2b)
  end)

  t.it("scripted combat sequences are deterministic with same seed", function()
    local attacker = { dex = 10, weapon_base = 5, str = 10, species_bonus = 0 }
    local defender = { evasion = 0, armor = 3 }

    rng.init(42)
    local r1 = combat.resolve_melee(attacker, defender, rng)
    local r2 = combat.resolve_melee(attacker, defender, rng)

    rng.init(42)
    local r1b = combat.resolve_melee(attacker, defender, rng)
    local r2b = combat.resolve_melee(attacker, defender, rng)

    t.expect(r1.hit).to_be(r1b.hit)
    t.expect(r1.roll).to_be(r1b.roll)
    t.expect(r1.damage).to_be(r1b.damage)

    t.expect(r2.hit).to_be(r2b.hit)
    t.expect(r2.roll).to_be(r2b.roll)
    t.expect(r2.damage).to_be(r2b.damage)
  end)
end)
