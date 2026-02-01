-- assets/scripts/tests/test_descent_endings.lua
--[[
================================================================================
DESCENT ENDINGS UI TESTS
================================================================================
Validates victory/death/error data payloads and return handling.
]]

local t = require("tests.test_runner")
local Endings = require("descent.ui.endings")

local function make_state()
  return {
    seed = 123,
    floor_num = 5,
    turn_count = 42,
    player = { turns_taken = 42, kills = 7, level = 3, xp = 25 },
  }
end

t.describe("Descent Endings UI", function()
  t.it("builds victory data with stats", function()
    local state = make_state()
    Endings.show_victory(state)
    local data = Endings.get_data()
    t.expect(data.type).to_be(Endings.TYPE.VICTORY)
    t.expect(data.stats.seed).to_be(123)
    t.expect(data.stats.floor).to_be(5)
    t.expect(data.stats.turns).to_be(42)
    t.expect(data.stats.kills).to_be(7)
    Endings.cleanup()
  end)

  t.it("builds death data with cause", function()
    local state = make_state()
    Endings.show_death(state, "fell")
    local data = Endings.get_data()
    t.expect(data.type).to_be(Endings.TYPE.DEATH)
    t.expect(data.subtitle).to_be("fell")
    Endings.cleanup()
  end)

  t.it("builds error data with message", function()
    local state = make_state()
    local original_getenv = os.getenv
    os.getenv = function(key)
      if key == "RUN_DESCENT_TESTS" then
        return "0"
      end
      return original_getenv and original_getenv(key) or nil
    end

    Endings.show_error(state, { message = "boom", stack = "trace" })
    local data = Endings.get_data()
    t.expect(data.type).to_be(Endings.TYPE.ERROR)
    t.expect(data.error).to_be("boom")
    t.expect(data.stack).to_be("trace")
    Endings.cleanup()

    os.getenv = original_getenv
  end)
end)
