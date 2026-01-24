-- assets/scripts/tests/test_skills_tab_marker.lua
--[[
================================================================================
TEST: Skills Tab Marker Module
================================================================================
TDD tests for the skills panel tab marker.

The tab marker:
- Stays visible on the left edge when panel is closed
- Moves with the panel when open
- Clicks toggle the panel
================================================================================
]]

local TestRunner = require("tests.test_runner")
local describe = TestRunner.describe
local it = TestRunner.it
local expect = TestRunner.expect

-- Mock globals
_G.registry = nil
_G.GetScreenWidth = function() return 1920 end
_G.GetScreenHeight = function() return 1080 end
_G.component_cache = { get = function() return nil end }

describe("Skills Tab Marker Module", function()
    package.loaded["ui.skills_tab_marker"] = nil
    local SkillsTabMarker = require("ui.skills_tab_marker")

    TestRunner.before_each(function()
        if SkillsTabMarker and SkillsTabMarker._reset then
            SkillsTabMarker._reset()
        end
    end)

    --------------------------------------------------------------------------------
    -- MODULE API
    --------------------------------------------------------------------------------

    describe("Module API", function()
        it("exports initialize function", function()
            expect(SkillsTabMarker.initialize).never().to_be_nil()
            expect(type(SkillsTabMarker.initialize)).to_be("function")
        end)

        it("exports destroy function", function()
            expect(SkillsTabMarker.destroy).never().to_be_nil()
            expect(type(SkillsTabMarker.destroy)).to_be("function")
        end)

        it("exports updatePosition function", function()
            expect(SkillsTabMarker.updatePosition).never().to_be_nil()
            expect(type(SkillsTabMarker.updatePosition)).to_be("function")
        end)

        it("exports isInitialized function", function()
            expect(SkillsTabMarker.isInitialized).never().to_be_nil()
            expect(type(SkillsTabMarker.isInitialized)).to_be("function")
        end)
    end)

    --------------------------------------------------------------------------------
    -- INITIAL STATE
    --------------------------------------------------------------------------------

    describe("Initial State", function()
        it("is not initialized by default", function()
            expect(SkillsTabMarker.isInitialized()).to_be(false)
        end)
    end)

    --------------------------------------------------------------------------------
    -- POSITION CALCULATION
    --------------------------------------------------------------------------------

    describe("Position Calculation", function()
        it("getClosedPosition returns left edge position", function()
            local x, y = SkillsTabMarker.getClosedPosition()
            expect(x).never().to_be_nil()
            expect(y).never().to_be_nil()
            -- Should be at left edge
            expect(x < 100).to_be(true)
        end)

        it("getOpenPosition returns position attached to panel", function()
            local panelWidth = 300
            local x, y = SkillsTabMarker.getOpenPosition(panelWidth)
            expect(x).never().to_be_nil()
            expect(y).never().to_be_nil()
            -- Should be to the right of panel
            expect(x > panelWidth).to_be(true)
        end)
    end)

    --------------------------------------------------------------------------------
    -- CONFIGURATION
    --------------------------------------------------------------------------------

    describe("Configuration", function()
        it("has sprite configuration", function()
            local config = SkillsTabMarker.getConfig()
            expect(config.sprite).never().to_be_nil()
        end)

        it("has width and height", function()
            local config = SkillsTabMarker.getConfig()
            expect(config.width).never().to_be_nil()
            expect(config.height).never().to_be_nil()
            expect(config.width > 0).to_be(true)
            expect(config.height > 0).to_be(true)
        end)
    end)
end)

-- Run tests if executed directly
if arg and arg[0] and arg[0]:match("test_skills_tab_marker%.lua$") then
    TestRunner.run()
end

return TestRunner
