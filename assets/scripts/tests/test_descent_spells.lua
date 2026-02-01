-- assets/scripts/tests/test_descent_spells.lua
--[[
================================================================================
DESCENT SPELL TESTS
================================================================================
Validates spell selection, MP/LOS/range checks, and deterministic outcomes.
]]

local t = require("tests.test_runner")
local Spells = require("descent.spells")
local Player = require("descent.player")
local Map = require("descent.map")

local function make_open_map(w, h)
  local map = Map.new(w, h, { default_tile = Map.TILE.FLOOR })
  for y = 1, h do
    for x = 1, w do
      Map.set_tile(map, x, y, Map.TILE.FLOOR)
    end
  end
  return map
end

t.describe("Descent Spells", function()
  t.it("selects a spell on level-up", function()
    local state = Player.init({})
    Spells.bind_player(Player)
    local before = #state.spells
    Player.add_xp(state, state.xp_to_next)
    t.expect(#state.spells).to_be(before + 1)
  end)

  t.it("validates MP, range, and LOS", function()
    local caster = { x = 1, y = 1, mp = 1, int = 0 }
    local target = { x = 2, y = 1, armor = 0, hp = 10 }

    local ok, reason = Spells.can_cast(Spells.SPELL.MAGIC_MISSILE, caster, target, { has_los = function() return true end })
    t.expect(ok).to_be(false)
    t.expect(reason).to_be("not_enough_mp")

    caster.mp = 10
    ok, reason = Spells.can_cast(Spells.SPELL.MAGIC_MISSILE, caster, { x = 20, y = 20 }, { has_los = function() return true end })
    t.expect(ok).to_be(false)
    t.expect(reason).to_be("out_of_range")

    ok, reason = Spells.can_cast(Spells.SPELL.MAGIC_MISSILE, caster, target, { has_los = function() return false end })
    t.expect(ok).to_be(false)
    t.expect(reason).to_be("no_los")
  end)

  t.it("casts deterministic damage and heal", function()
    local caster = { x = 1, y = 1, mp = 10, int = 0, species_multiplier = 1 }
    local target = { x = 2, y = 1, armor = 1, hp = 10 }

    local result = Spells.cast(Spells.SPELL.MAGIC_MISSILE, caster, target, { has_los = function() return true end })
    t.expect(result.success).to_be(true)
    t.expect(result.damage).to_be(3) -- base 4 minus armor 1

    local heal_target = { x = 1, y = 1, hp = 2, hp_max = 10 }
    local heal_result = Spells.cast(Spells.SPELL.HEAL, caster, heal_target, {})
    t.expect(heal_result.success).to_be(true)
    t.expect(heal_target.hp).to_be(8)
  end)

  t.it("blink uses deterministic RNG when provided", function()
    local caster = { x = 2, y = 2, mp = 10 }
    local map = make_open_map(5, 5)
    local rng = {
      choice = function(list)
        return list[1]
      end,
    }

    local result = Spells.cast(Spells.SPELL.BLINK, caster, nil, { map = map, rng = rng })
    t.expect(result.success).to_be(true)
    t.expect(result.destination).to_be_truthy()
  end)
end)
