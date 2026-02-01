-- assets/scripts/tests/test_descent_player.lua
--[[
================================================================================
DESCENT PLAYER LEVELING TESTS
================================================================================
Validates XP thresholds, stat recalculation, and event emission.
]]

local t = require("tests.test_runner")
local Player = require("descent.player")
local spec = require("descent.spec")

local function expected_hp(level, species_hp_mod)
  local base = spec.stats.hp.base
  local mult = spec.stats.hp.level_multiplier
  return math.floor((base + species_hp_mod) * (1 + level * mult))
end

local function expected_mp(level, species_mp_mod)
  local base = spec.stats.mp.base
  local mult = spec.stats.mp.level_multiplier
  return math.floor((base + species_mp_mod) * (1 + level * mult))
end

t.describe("Descent Player", function()
  t.it("uses spec XP thresholds", function()
    local state = Player.create({ species_xp_mod = 1 })
    local expected = spec.stats.xp.base * 2
    t.expect(state.xp_to_next).to_be(expected)
  end)

  t.it("recalculates HP/MP on level up", function()
    local state = Player.create({ species_hp_mod = 0, species_mp_mod = 0, species_xp_mod = 1 })
    local hp_before = state.hp_max
    local mp_before = state.mp_max

    Player.add_xp(state, state.xp_to_next)
    t.expect(state.level).to_be(2)

    local hp_after = expected_hp(2, 0)
    local mp_after = expected_mp(2, 0)
    t.expect(state.hp_max).to_be(hp_after)
    t.expect(state.mp_max).to_be(mp_after)
    t.expect(state.hp).to_be(hp_before + (hp_after - hp_before))
    t.expect(state.mp).to_be(mp_before + (mp_after - mp_before))
  end)

  t.it("emits level-up and spell selection events", function()
    local state = Player.create({ species_xp_mod = 1 })
    local level_ups = 0
    local spell_selects = 0

    Player.on_level_up(function()
      level_ups = level_ups + 1
    end)

    Player.on_spell_select(function()
      spell_selects = spell_selects + 1
    end)

    Player.add_xp(state, state.xp_to_next)

    t.expect(level_ups).to_be(1)
    t.expect(spell_selects).to_be(1)
  end)
end)
