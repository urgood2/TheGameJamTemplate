-- assets/scripts/tests/test_skills_panel_input.lua
--[[
================================================================================
TEST: Skills Panel Input Handler
================================================================================
TDD tests for the skills panel input and signal integration module.
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
_G.isKeyPressed = nil

describe("Skills Panel Input Handler", function()
    -- Reset all skills panel modules to get fresh state
    package.loaded["ui.skills_panel_input"] = nil
    package.loaded["ui.skills_panel"] = nil
    package.loaded["ui.skills_tab_marker"] = nil
    package.loaded["ui.skill_confirmation_modal"] = nil

    local SkillsPanelInput = require("ui.skills_panel_input")
    local SkillConfirmationModal = require("ui.skill_confirmation_modal")
    local SkillsPanel = require("ui.skills_panel")

    TestRunner.before_each(function()
        -- Reset all modules between tests
        if SkillsPanelInput and SkillsPanelInput._reset then
            SkillsPanelInput._reset()
        end
        if SkillConfirmationModal and SkillConfirmationModal._reset then
            SkillConfirmationModal._reset()
        end
        if SkillsPanel and SkillsPanel._reset then
            SkillsPanel._reset()
        end
    end)

    --------------------------------------------------------------------------------
    -- MODULE API
    --------------------------------------------------------------------------------

    describe("Module API", function()
        it("exports initialize function", function()
            expect(SkillsPanelInput.initialize).never().to_be_nil()
            expect(type(SkillsPanelInput.initialize)).to_be("function")
        end)

        it("exports shutdown function", function()
            expect(SkillsPanelInput.shutdown).never().to_be_nil()
            expect(type(SkillsPanelInput.shutdown)).to_be("function")
        end)

        it("exports isInitialized function", function()
            expect(SkillsPanelInput.isInitialized).never().to_be_nil()
            expect(type(SkillsPanelInput.isInitialized)).to_be("function")
        end)

        it("exports getPlayer function", function()
            expect(SkillsPanelInput.getPlayer).never().to_be_nil()
            expect(type(SkillsPanelInput.getPlayer)).to_be("function")
        end)

        it("exports onSkillButtonClicked function", function()
            expect(SkillsPanelInput.onSkillButtonClicked).never().to_be_nil()
            expect(type(SkillsPanelInput.onSkillButtonClicked)).to_be("function")
        end)
    end)

    --------------------------------------------------------------------------------
    -- INITIAL STATE
    --------------------------------------------------------------------------------

    describe("Initial State", function()
        it("is not initialized by default", function()
            expect(SkillsPanelInput.isInitialized()).to_be(false)
        end)

        it("has no player by default", function()
            expect(SkillsPanelInput.getPlayer()).to_be_nil()
        end)
    end)

    --------------------------------------------------------------------------------
    -- INITIALIZATION
    --------------------------------------------------------------------------------

    describe("Initialization", function()
        local SkillSystem = require("core.skill_system")

        local function createTestPlayer(skillPoints)
            local player = { skill_points = skillPoints or 10 }
            SkillSystem.init(player)
            return player
        end

        it("sets initialized state", function()
            local player = createTestPlayer(10)
            SkillsPanelInput.initialize(player)
            expect(SkillsPanelInput.isInitialized()).to_be(true)
        end)

        it("stores player reference", function()
            local player = createTestPlayer(10)
            SkillsPanelInput.initialize(player)
            local storedPlayer = SkillsPanelInput.getPlayer()
            expect(storedPlayer).never().to_be_nil()
            expect(storedPlayer.skill_points).to_be(player.skill_points)
        end)

        it("can be initialized multiple times safely", function()
            local player = createTestPlayer(10)
            SkillsPanelInput.initialize(player)
            SkillsPanelInput.initialize(player)  -- Should not error
            expect(SkillsPanelInput.isInitialized()).to_be(true)
        end)
    end)

    --------------------------------------------------------------------------------
    -- SHUTDOWN
    --------------------------------------------------------------------------------

    describe("Shutdown", function()
        local SkillSystem = require("core.skill_system")

        local function createTestPlayer(skillPoints)
            local player = { skill_points = skillPoints or 10 }
            SkillSystem.init(player)
            return player
        end

        it("clears initialized state", function()
            local player = createTestPlayer(10)
            SkillsPanelInput.initialize(player)
            SkillsPanelInput.shutdown()
            expect(SkillsPanelInput.isInitialized()).to_be(false)
        end)

        it("clears player reference", function()
            local player = createTestPlayer(10)
            SkillsPanelInput.initialize(player)
            SkillsPanelInput.shutdown()
            expect(SkillsPanelInput.getPlayer()).to_be_nil()
        end)

        it("can be called when not initialized", function()
            SkillsPanelInput.shutdown()  -- Should not error
            expect(SkillsPanelInput.isInitialized()).to_be(false)
        end)
    end)

    --------------------------------------------------------------------------------
    -- SKILL BUTTON CLICK HANDLER
    --------------------------------------------------------------------------------

    describe("onSkillButtonClicked", function()
        local SkillSystem = require("core.skill_system")

        local function createTestPlayer(skillPoints)
            local player = { skill_points = skillPoints or 10 }
            SkillSystem.init(player)
            return player
        end

        local function resetAllModules()
            if SkillsPanelInput and SkillsPanelInput._reset then
                SkillsPanelInput._reset()
            end
            if SkillConfirmationModal and SkillConfirmationModal._reset then
                SkillConfirmationModal._reset()
            end
            if SkillsPanel and SkillsPanel._reset then
                SkillsPanel._reset()
            end
        end

        it("shows modal when called with valid skill", function()
            resetAllModules()
            local player = createTestPlayer(10)
            SkillsPanelInput.initialize(player)

            SkillsPanelInput.onSkillButtonClicked("kindle")
            expect(SkillConfirmationModal.isVisible()).to_be(true)
        end)

        it("does nothing when no player set", function()
            resetAllModules()
            -- Don't initialize - no player
            SkillsPanelInput.onSkillButtonClicked("kindle")
            expect(SkillConfirmationModal.isVisible()).to_be(false)
        end)

        it("does nothing with nil skill", function()
            resetAllModules()
            local player = createTestPlayer(10)
            SkillsPanelInput.initialize(player)

            SkillsPanelInput.onSkillButtonClicked(nil)
            expect(SkillConfirmationModal.isVisible()).to_be(false)
        end)
    end)
end)

-- Run tests if executed directly
if arg and arg[0] and arg[0]:match("test_skills_panel_input%.lua$") then
    TestRunner.run()
end

return TestRunner
