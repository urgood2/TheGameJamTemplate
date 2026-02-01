-- assets/scripts/tests/test_descent_combat.lua
--[[
================================================================================
DESCENT COMBAT TESTS
================================================================================
Validates combat math per spec (hit chance clamp, damage floor, deterministic RNG).
]]

local t = require("tests.test_runner")
local Combat = require("descent.combat")

local function expect_error(fn, substring)
  local ok, err = pcall(fn)
  t.expect(ok).to_be(false)
  t.expect(tostring(err)).to_contain(substring)
end

t.describe("Descent Combat", function()
  t.it("clamps melee hit chance", function()
    local attacker = { dex = 1 }
    local defender = { evasion = 100 }
    local chance = Combat.melee_hit_chance(attacker, defender)
    t.expect(chance).to_be(5)

    attacker.dex = 100
    defender.evasion = 0
    chance = Combat.melee_hit_chance(attacker, defender)
    t.expect(chance).to_be(95)
  end)

  t.it("clamps magic hit chance", function()
    local attacker = { skill = -10, id = 1, type = "player" }
    expect_error(function() Combat.magic_hit_chance(attacker) end, "Negative skill")

    attacker.skill = 100
    local chance = Combat.magic_hit_chance(attacker)
    t.expect(chance).to_be(95)
  end)

  t.it("floors damage at zero after armor", function()
    local attacker = { weapon_base = 2, str = 1, species_bonus = 0 }
    local defender = { armor = 10 }
    local raw = Combat.melee_raw_damage(attacker)
    t.expect(raw).to_be(3)
    local final = Combat.apply_armor(raw, defender)
    t.expect(final).to_be(0)
  end)

  t.it("uses deterministic scripted RNG", function()
    local rng = Combat.scripted_rng({ 1, 100, 50 })
    local attacker = { dex = 10, weapon_base = 5, str = 10, species_bonus = 0 }
    local defender = { evasion = 0, armor = 3 }

    local result = Combat.resolve_melee(attacker, defender, rng)
    t.expect(result.hit).to_be(true)
    t.expect(result.damage).to_be(12)

    local result2 = Combat.resolve_melee(attacker, defender, rng)
    t.expect(result2.hit).to_be(false)
  end)

  t.it("rejects negative stats with entity context", function()
    local attacker = { dex = -1, id = 7, type = "goblin" }
    local defender = { evasion = 0 }
    expect_error(function() Combat.melee_hit_chance(attacker, defender) end, "goblin:7")
  end)
end)
