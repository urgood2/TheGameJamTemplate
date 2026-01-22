--[[
================================================================================
TEST: Constants Module Expansion
================================================================================
Tests for the expanded constants module with Timing, Stats, UI, and Colors.

TDD Approach:
- RED: Tests should FAIL before expansion is implemented
- GREEN: Implement expansion, tests pass

Run with: lua assets/scripts/tests/test_constants_expansion.lua
]]

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

-- Clear cached module
package.loaded["core.constants"] = nil
_G.C = nil

local t = require("tests.test_runner")
local C = require("core.constants")

--------------------------------------------------------------------------------
-- Tests: Existing categories still work
--------------------------------------------------------------------------------

t.describe("Constants - Existing categories", function()

    t.it("has CollisionTags", function()
        t.expect(C.CollisionTags).to_be_truthy()
        t.expect(C.CollisionTags.PLAYER).to_be("player")
        t.expect(C.CollisionTags.ENEMY).to_be("enemy")
    end)

    t.it("has States", function()
        t.expect(C.States).to_be_truthy()
        t.expect(C.States.PLANNING).to_be("PLANNING")
    end)

    t.it("has DamageTypes", function()
        t.expect(C.DamageTypes).to_be_truthy()
        t.expect(C.DamageTypes.FIRE).to_be("fire")
    end)

    t.it("has helper functions", function()
        t.expect(type(C.values)).to_be("function")
        t.expect(type(C.is_valid)).to_be("function")
    end)
end)

--------------------------------------------------------------------------------
-- Tests: NEW - Timing constants
--------------------------------------------------------------------------------

t.describe("Constants.Timing", function()

    t.it("exists as a category", function()
        t.expect(C.Timing).to_be_truthy()
        t.expect(type(C.Timing)).to_be("table")
    end)

    t.it("has common delay values", function()
        t.expect(C.Timing.FRAME).to_be_truthy()
        t.expect(type(C.Timing.FRAME)).to_be("number")

        t.expect(C.Timing.SHORT).to_be_truthy()
        t.expect(type(C.Timing.SHORT)).to_be("number")

        t.expect(C.Timing.MEDIUM).to_be_truthy()
        t.expect(C.Timing.LONG).to_be_truthy()
    end)

    t.it("has attack/cooldown values", function()
        t.expect(C.Timing.ATTACK_COOLDOWN).to_be_truthy()
        t.expect(type(C.Timing.ATTACK_COOLDOWN)).to_be("number")
    end)

    t.it("has animation timing values", function()
        t.expect(C.Timing.FADE_DURATION).to_be_truthy()
        t.expect(C.Timing.POPUP_DURATION).to_be_truthy()
    end)
end)

--------------------------------------------------------------------------------
-- Tests: NEW - Stats constants
--------------------------------------------------------------------------------

t.describe("Constants.Stats", function()

    t.it("exists as a category", function()
        t.expect(C.Stats).to_be_truthy()
        t.expect(type(C.Stats)).to_be("table")
    end)

    t.it("has base health/damage values", function()
        t.expect(C.Stats.BASE_HEALTH).to_be_truthy()
        t.expect(type(C.Stats.BASE_HEALTH)).to_be("number")

        t.expect(C.Stats.BASE_DAMAGE).to_be_truthy()
        t.expect(type(C.Stats.BASE_DAMAGE)).to_be("number")
    end)

    t.it("has movement speed values", function()
        t.expect(C.Stats.BASE_SPEED).to_be_truthy()
        t.expect(type(C.Stats.BASE_SPEED)).to_be("number")
    end)
end)

--------------------------------------------------------------------------------
-- Tests: NEW - UI constants
--------------------------------------------------------------------------------

t.describe("Constants.UI", function()

    t.it("exists as a category", function()
        t.expect(C.UI).to_be_truthy()
        t.expect(type(C.UI)).to_be("table")
    end)

    t.it("has padding/margin values", function()
        t.expect(C.UI.PADDING_SMALL).to_be_truthy()
        t.expect(type(C.UI.PADDING_SMALL)).to_be("number")

        t.expect(C.UI.PADDING_MEDIUM).to_be_truthy()
        t.expect(C.UI.PADDING_LARGE).to_be_truthy()
    end)

    t.it("has z-order values", function()
        t.expect(C.UI.Z_BACKGROUND).to_be_truthy()
        t.expect(C.UI.Z_GAME).to_be_truthy()
        t.expect(C.UI.Z_UI).to_be_truthy()
        t.expect(C.UI.Z_OVERLAY).to_be_truthy()
    end)

    t.it("has font size values", function()
        t.expect(C.UI.FONT_SMALL).to_be_truthy()
        t.expect(C.UI.FONT_MEDIUM).to_be_truthy()
        t.expect(C.UI.FONT_LARGE).to_be_truthy()
    end)
end)

--------------------------------------------------------------------------------
-- Tests: NEW - Colors constants
--------------------------------------------------------------------------------

t.describe("Constants.Colors", function()

    t.it("exists as a category", function()
        t.expect(C.Colors).to_be_truthy()
        t.expect(type(C.Colors)).to_be("table")
    end)

    t.it("has basic colors as tables with r,g,b,a", function()
        t.expect(C.Colors.WHITE).to_be_truthy()
        t.expect(type(C.Colors.WHITE)).to_be("table")
        t.expect(C.Colors.WHITE.r).to_be(255)
        t.expect(C.Colors.WHITE.g).to_be(255)
        t.expect(C.Colors.WHITE.b).to_be(255)

        t.expect(C.Colors.BLACK).to_be_truthy()
        t.expect(C.Colors.BLACK.r).to_be(0)
    end)

    t.it("has semantic colors", function()
        t.expect(C.Colors.DAMAGE).to_be_truthy()
        t.expect(C.Colors.HEAL).to_be_truthy()
        t.expect(C.Colors.BUFF).to_be_truthy()
        t.expect(C.Colors.DEBUFF).to_be_truthy()
    end)

    t.it("has UI colors", function()
        t.expect(C.Colors.UI_PRIMARY).to_be_truthy()
        t.expect(C.Colors.UI_SECONDARY).to_be_truthy()
    end)
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

local success = t.run()
os.exit(success and 0 or 1)
