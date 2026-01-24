-- assets/scripts/tests/test_skills_panel.lua
--[[
================================================================================
TEST: Skills Panel Module
================================================================================
TDD tests for the skills panel UI module.

Focus: State management, API, and testable logic.
Integration testing (actual rendering) requires the full game engine.
================================================================================
]]

local TestRunner = require("tests.test_runner")
local describe = TestRunner.describe
local it = TestRunner.it
local expect = TestRunner.expect

-- Mock globals that the module needs (for unit testing without game engine)
_G.registry = nil
_G.GetScreenWidth = function() return 1920 end
_G.GetScreenHeight = function() return 1080 end
_G.localization = nil
_G.component_cache = { get = function() return nil end }
_G.ui = nil
_G.add_state_tag = function() end
_G.clear_state_tags = function() end

describe("Skills Panel Module", function()
    -- Load module once, reset state between tests
    package.loaded["ui.skills_panel"] = nil
    local SkillsPanel = require("ui.skills_panel")

    TestRunner.before_each(function()
        -- Reset module state between tests
        if SkillsPanel and SkillsPanel._reset then
            SkillsPanel._reset()
        end
    end)

    --------------------------------------------------------------------------------
    -- MODULE API
    --------------------------------------------------------------------------------

    describe("Module API", function()
        it("exports open function", function()
            expect(SkillsPanel.open).never().to_be_nil()
            expect(type(SkillsPanel.open)).to_be("function")
        end)

        it("exports close function", function()
            expect(SkillsPanel.close).never().to_be_nil()
            expect(type(SkillsPanel.close)).to_be("function")
        end)

        it("exports toggle function", function()
            expect(SkillsPanel.toggle).never().to_be_nil()
            expect(type(SkillsPanel.toggle)).to_be("function")
        end)

        it("exports isOpen function", function()
            expect(SkillsPanel.isOpen).never().to_be_nil()
            expect(type(SkillsPanel.isOpen)).to_be("function")
        end)

        it("exports destroy function", function()
            expect(SkillsPanel.destroy).never().to_be_nil()
            expect(type(SkillsPanel.destroy)).to_be("function")
        end)

        it("exports getSkillButtonState function", function()
            expect(SkillsPanel.getSkillButtonState).never().to_be_nil()
            expect(type(SkillsPanel.getSkillButtonState)).to_be("function")
        end)
    end)

    --------------------------------------------------------------------------------
    -- INITIAL STATE
    --------------------------------------------------------------------------------

    describe("Initial State", function()
        it("starts closed", function()
            expect(SkillsPanel.isOpen()).to_be(false)
        end)

        it("is not initialized until opened", function()
            expect(SkillsPanel.isInitialized()).to_be(false)
        end)
    end)

    --------------------------------------------------------------------------------
    -- SKILL BUTTON STATE LOGIC
    --------------------------------------------------------------------------------

    describe("getSkillButtonState", function()
        local SkillSystem = require("core.skill_system")

        local function createTestPlayer(skillPoints)
            local player = { skill_points = skillPoints or 10 }
            SkillSystem.init(player)
            return player
        end

        it("returns 'locked' for void skills (demo locked element)", function()
            local player = createTestPlayer(10)
            local buttonState = SkillsPanel.getSkillButtonState(player, "entropy")  -- void skill
            expect(buttonState).to_be("locked")
        end)

        it("returns 'learned' for already learned skills", function()
            local player = createTestPlayer(10)
            SkillSystem.learn_skill(player, "kindle")
            local buttonState = SkillsPanel.getSkillButtonState(player, "kindle")
            expect(buttonState).to_be("learned")
        end)

        it("returns 'available' for unlearned affordable skills", function()
            local player = createTestPlayer(10)
            local buttonState = SkillsPanel.getSkillButtonState(player, "kindle")  -- cost 1
            expect(buttonState).to_be("available")
        end)

        it("returns 'insufficient' for unaffordable skills", function()
            local player = createTestPlayer(2)
            local buttonState = SkillsPanel.getSkillButtonState(player, "fire_form")  -- cost 5
            expect(buttonState).to_be("insufficient")
        end)

        it("returns 'available' for fire skills (unlocked element)", function()
            local player = createTestPlayer(10)
            local buttonState = SkillsPanel.getSkillButtonState(player, "kindle")
            expect(buttonState).to_be("available")
        end)

        it("returns 'available' for ice skills (unlocked element)", function()
            local player = createTestPlayer(10)
            local buttonState = SkillsPanel.getSkillButtonState(player, "frostbite")
            expect(buttonState).to_be("available")
        end)

        it("returns 'available' for lightning skills (unlocked element)", function()
            local player = createTestPlayer(10)
            local buttonState = SkillsPanel.getSkillButtonState(player, "spark")
            expect(buttonState).to_be("available")
        end)

        it("returns 'locked' for non-existent skill", function()
            local player = createTestPlayer(10)
            local buttonState = SkillsPanel.getSkillButtonState(player, "nonexistent_skill_xyz")
            expect(buttonState).to_be("locked")
        end)
    end)

    --------------------------------------------------------------------------------
    -- CONFIGURATION
    --------------------------------------------------------------------------------

    describe("Configuration", function()
        it("has fire as unlocked element", function()
            local config = SkillsPanel.getConfig()
            expect(config.unlocked_elements).to_contain("fire")
        end)

        it("has ice as unlocked element", function()
            local config = SkillsPanel.getConfig()
            expect(config.unlocked_elements).to_contain("ice")
        end)

        it("has lightning as unlocked element", function()
            local config = SkillsPanel.getConfig()
            expect(config.unlocked_elements).to_contain("lightning")
        end)

        it("has void as locked element", function()
            local config = SkillsPanel.getConfig()
            expect(config.locked_elements).to_contain("void")
        end)

        it("has 4 columns (one per element)", function()
            local config = SkillsPanel.getConfig()
            expect(config.columns).to_be(4)
        end)

        it("has 8 rows (skills per element)", function()
            local config = SkillsPanel.getConfig()
            expect(config.rows).to_be(8)
        end)
    end)

    --------------------------------------------------------------------------------
    -- GRID DATA GENERATION
    --------------------------------------------------------------------------------

    describe("getGridData", function()
        it("returns skills organized by element columns", function()
            local gridData = SkillsPanel.getGridData()
            expect(gridData).never().to_be_nil()
            expect(gridData.fire).never().to_be_nil()
            expect(gridData.ice).never().to_be_nil()
            expect(gridData.lightning).never().to_be_nil()
            expect(gridData.void).never().to_be_nil()
        end)

        it("has 8 skills per element column", function()
            local gridData = SkillsPanel.getGridData()
            expect(#gridData.fire).to_be(8)
            expect(#gridData.ice).to_be(8)
            expect(#gridData.lightning).to_be(8)
            expect(#gridData.void).to_be(8)
        end)

        it("skills are sorted by cost (ascending)", function()
            local gridData = SkillsPanel.getGridData()
            local fireSkills = gridData.fire

            -- Verify ascending cost order (skills are {id, def} pairs)
            local prevCost = 0
            for _, entry in ipairs(fireSkills) do
                local cost = entry.def.cost
                expect(cost >= prevCost).to_be(true)
                prevCost = cost
            end
        end)
    end)

    --------------------------------------------------------------------------------
    -- SKILL POINTS DISPLAY
    --------------------------------------------------------------------------------

    describe("getSkillPointsDisplay", function()
        local SkillSystem = require("core.skill_system")

        it("returns formatted string with available/total points", function()
            local player = { skill_points = 10 }
            SkillSystem.init(player)

            local display = SkillsPanel.getSkillPointsDisplay(player)
            expect(display).to_contain("10")
        end)

        it("reflects spent points", function()
            local player = { skill_points = 10 }
            SkillSystem.init(player)
            SkillSystem.learn_skill(player, "kindle")  -- cost 1

            local display = SkillsPanel.getSkillPointsDisplay(player)
            -- Should show 9 remaining out of 10
            expect(display).to_contain("9")
        end)
    end)

    --------------------------------------------------------------------------------
    -- SIGNAL EMISSION
    --------------------------------------------------------------------------------

    describe("Signal Emission", function()
        it("emits skills_panel_opened when opening", function()
            -- Mock signal module
            local emittedEvents = {}
            package.loaded["external.hump.signal"] = {
                emit = function(event, data)
                    table.insert(emittedEvents, { event = event, data = data })
                end,
                register = function() end,
                remove = function() end,
            }

            -- Reload module to pick up mock
            package.loaded["ui.skills_panel"] = nil
            local SkillsPanelFresh = require("ui.skills_panel")

            SkillsPanelFresh.open()
            local found = false
            for _, e in ipairs(emittedEvents) do
                if e.event == "skills_panel_opened" then
                    found = true
                    break
                end
            end
            expect(found).to_be(true)

            -- Cleanup
            SkillsPanelFresh._reset()
            package.loaded["external.hump.signal"] = nil
        end)

        it("emits skills_panel_closed when closing", function()
            -- Mock signal module
            local emittedEvents = {}
            package.loaded["external.hump.signal"] = {
                emit = function(event, data)
                    table.insert(emittedEvents, { event = event, data = data })
                end,
                register = function() end,
                remove = function() end,
            }

            -- Reload module to pick up mock
            package.loaded["ui.skills_panel"] = nil
            local SkillsPanelFresh = require("ui.skills_panel")

            SkillsPanelFresh.open()
            emittedEvents = {}  -- Clear open event
            SkillsPanelFresh.close()

            local found = false
            for _, e in ipairs(emittedEvents) do
                if e.event == "skills_panel_closed" then
                    found = true
                    break
                end
            end
            expect(found).to_be(true)

            -- Cleanup
            SkillsPanelFresh._reset()
            package.loaded["external.hump.signal"] = nil
        end)
    end)
end)

-- Run tests if executed directly
if arg and arg[0] and arg[0]:match("test_skills_panel%.lua$") then
    TestRunner.run()
end

return TestRunner
