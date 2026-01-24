-- assets/scripts/tests/test_skill_confirmation_modal.lua
--[[
================================================================================
TEST: Skill Confirmation Modal Module
================================================================================
TDD tests for the skill learning confirmation modal.

The modal:
- Shows skill name, description, cost, and current points
- Has Confirm and Cancel buttons
- Requires explicit button click to dismiss (no click-outside)
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

describe("Skill Confirmation Modal", function()
    package.loaded["ui.skill_confirmation_modal"] = nil
    local SkillConfirmationModal = require("ui.skill_confirmation_modal")

    TestRunner.before_each(function()
        if SkillConfirmationModal and SkillConfirmationModal._reset then
            SkillConfirmationModal._reset()
        end
    end)

    --------------------------------------------------------------------------------
    -- MODULE API
    --------------------------------------------------------------------------------

    describe("Module API", function()
        it("exports show function", function()
            expect(SkillConfirmationModal.show).never().to_be_nil()
            expect(type(SkillConfirmationModal.show)).to_be("function")
        end)

        it("exports hide function", function()
            expect(SkillConfirmationModal.hide).never().to_be_nil()
            expect(type(SkillConfirmationModal.hide)).to_be("function")
        end)

        it("exports isVisible function", function()
            expect(SkillConfirmationModal.isVisible).never().to_be_nil()
            expect(type(SkillConfirmationModal.isVisible)).to_be("function")
        end)

        it("exports confirm function", function()
            expect(SkillConfirmationModal.confirm).never().to_be_nil()
            expect(type(SkillConfirmationModal.confirm)).to_be("function")
        end)

        it("exports cancel function", function()
            expect(SkillConfirmationModal.cancel).never().to_be_nil()
            expect(type(SkillConfirmationModal.cancel)).to_be("function")
        end)

        it("exports getModalData function", function()
            expect(SkillConfirmationModal.getModalData).never().to_be_nil()
            expect(type(SkillConfirmationModal.getModalData)).to_be("function")
        end)
    end)

    --------------------------------------------------------------------------------
    -- INITIAL STATE
    --------------------------------------------------------------------------------

    describe("Initial State", function()
        it("is not visible by default", function()
            expect(SkillConfirmationModal.isVisible()).to_be(false)
        end)

        it("has no modal data by default", function()
            local data = SkillConfirmationModal.getModalData()
            expect(data).to_be_nil()
        end)
    end)

    --------------------------------------------------------------------------------
    -- SHOW/HIDE
    --------------------------------------------------------------------------------

    describe("Show/Hide", function()
        local SkillSystem = require("core.skill_system")

        local function createTestPlayer(skillPoints)
            local player = { skill_points = skillPoints or 10 }
            SkillSystem.init(player)
            return player
        end

        it("show sets visible state", function()
            local player = createTestPlayer(10)
            SkillConfirmationModal.show(player, "kindle")
            expect(SkillConfirmationModal.isVisible()).to_be(true)
        end)

        it("show stores modal data", function()
            local player = createTestPlayer(10)
            SkillConfirmationModal.show(player, "kindle")

            local data = SkillConfirmationModal.getModalData()
            expect(data).never().to_be_nil()
            expect(data.skillId).to_be("kindle")
            expect(data.player).to_be(player)
        end)

        it("hide clears visible state", function()
            local player = createTestPlayer(10)
            SkillConfirmationModal.show(player, "kindle")
            SkillConfirmationModal.hide()
            expect(SkillConfirmationModal.isVisible()).to_be(false)
        end)

        it("hide clears modal data", function()
            local player = createTestPlayer(10)
            SkillConfirmationModal.show(player, "kindle")
            SkillConfirmationModal.hide()
            expect(SkillConfirmationModal.getModalData()).to_be_nil()
        end)
    end)

    --------------------------------------------------------------------------------
    -- MODAL DATA
    --------------------------------------------------------------------------------

    describe("Modal Data", function()
        local SkillSystem = require("core.skill_system")
        local Skills = require("data.skills")

        local function createTestPlayer(skillPoints)
            local player = { skill_points = skillPoints or 10 }
            SkillSystem.init(player)
            return player
        end

        it("includes skill name", function()
            local player = createTestPlayer(10)
            SkillConfirmationModal.show(player, "kindle")

            local data = SkillConfirmationModal.getModalData()
            expect(data.skillName).to_be("Kindle")
        end)

        it("includes skill description", function()
            local player = createTestPlayer(10)
            SkillConfirmationModal.show(player, "kindle")

            local data = SkillConfirmationModal.getModalData()
            expect(data.skillDescription).never().to_be_nil()
            expect(#data.skillDescription > 0).to_be(true)
        end)

        it("includes skill cost", function()
            local player = createTestPlayer(10)
            SkillConfirmationModal.show(player, "kindle")

            local data = SkillConfirmationModal.getModalData()
            expect(data.skillCost).to_be(1)  -- kindle costs 1
        end)

        it("includes current skill points", function()
            local player = createTestPlayer(10)
            SkillConfirmationModal.show(player, "kindle")

            local data = SkillConfirmationModal.getModalData()
            expect(data.currentPoints).to_be(10)
        end)

        it("includes remaining skill points", function()
            local player = createTestPlayer(10)
            SkillSystem.learn_skill(player, "pyrokinesis")  -- cost 1, remaining = 9
            SkillConfirmationModal.show(player, "kindle")

            local data = SkillConfirmationModal.getModalData()
            expect(data.remainingPoints).to_be(9)
        end)

        it("includes canAfford flag", function()
            local player = createTestPlayer(10)
            SkillConfirmationModal.show(player, "kindle")

            local data = SkillConfirmationModal.getModalData()
            expect(data.canAfford).to_be(true)
        end)

        it("canAfford is false when insufficient points", function()
            local player = createTestPlayer(2)
            SkillConfirmationModal.show(player, "fire_form")  -- cost 5

            local data = SkillConfirmationModal.getModalData()
            expect(data.canAfford).to_be(false)
        end)
    end)

    --------------------------------------------------------------------------------
    -- CONFIRM/CANCEL ACTIONS
    --------------------------------------------------------------------------------

    describe("Confirm/Cancel Actions", function()
        local SkillSystem = require("core.skill_system")

        local function createTestPlayer(skillPoints)
            local player = { skill_points = skillPoints or 10 }
            SkillSystem.init(player)
            return player
        end

        it("confirm learns the skill when affordable", function()
            local player = createTestPlayer(10)
            SkillConfirmationModal.show(player, "kindle")

            local success = SkillConfirmationModal.confirm()
            expect(success).to_be(true)
            expect(SkillSystem.has_skill(player, "kindle")).to_be(true)
        end)

        it("confirm hides the modal on success", function()
            local player = createTestPlayer(10)
            SkillConfirmationModal.show(player, "kindle")

            SkillConfirmationModal.confirm()
            expect(SkillConfirmationModal.isVisible()).to_be(false)
        end)

        it("confirm returns false when not affordable", function()
            local player = createTestPlayer(2)
            SkillConfirmationModal.show(player, "fire_form")  -- cost 5

            local success = SkillConfirmationModal.confirm()
            expect(success).to_be(false)
            expect(SkillSystem.has_skill(player, "fire_form")).to_be(false)
        end)

        it("confirm keeps modal open on failure", function()
            local player = createTestPlayer(2)
            SkillConfirmationModal.show(player, "fire_form")

            SkillConfirmationModal.confirm()
            expect(SkillConfirmationModal.isVisible()).to_be(true)
        end)

        it("cancel hides the modal without learning", function()
            local player = createTestPlayer(10)
            SkillConfirmationModal.show(player, "kindle")

            SkillConfirmationModal.cancel()
            expect(SkillConfirmationModal.isVisible()).to_be(false)
            expect(SkillSystem.has_skill(player, "kindle")).to_be(false)
        end)
    end)
end)

-- Run tests if executed directly
if arg and arg[0] and arg[0]:match("test_skill_confirmation_modal%.lua$") then
    TestRunner.run()
end

return TestRunner
