-- assets/scripts/tests/test_skill_points.lua
--[[
================================================================================
TEST: Skill Points Accounting API
================================================================================
TDD tests for skill points tracking in the skill system.

Model:
- player.skill_points = total available points (awarded via level-up)
- Each skill has a cost (1-5 points)
- spent_points = sum of costs of learned skills
- available_points = total_points - spent_points
================================================================================
]]

local TestRunner = require("tests.test_runner")
local describe = TestRunner.describe
local it = TestRunner.it
local expect = TestRunner.expect

describe("Skill Points Accounting", function()
    local SkillSystem = require("core.skill_system")
    local Skills = require("data.skills")

    -- Helper to create a fresh test player
    local function createTestPlayer(skillPoints)
        local player = {
            skill_points = skillPoints or 0
        }
        SkillSystem.init(player)
        return player
    end

    --------------------------------------------------------------------------------
    -- SKILL COST API
    --------------------------------------------------------------------------------

    describe("get_skill_cost", function()
        it("returns the cost of a skill", function()
            -- kindle costs 1, fire_form costs 5
            expect(SkillSystem.get_skill_cost("kindle")).to_be(1)
            expect(SkillSystem.get_skill_cost("fire_form")).to_be(5)
            expect(SkillSystem.get_skill_cost("combustion")).to_be(2)
            expect(SkillSystem.get_skill_cost("flame_familiar")).to_be(3)
            expect(SkillSystem.get_skill_cost("scorch_master")).to_be(4)
        end)

        it("returns 0 for unknown skills", function()
            expect(SkillSystem.get_skill_cost("nonexistent")).to_be(0)
            expect(SkillSystem.get_skill_cost(nil)).to_be(0)
        end)
    end)

    --------------------------------------------------------------------------------
    -- SKILL POINTS SPENT
    --------------------------------------------------------------------------------

    describe("get_skill_points_spent", function()
        it("returns 0 when no skills learned", function()
            local player = createTestPlayer(10)
            expect(SkillSystem.get_skill_points_spent(player)).to_be(0)
        end)

        it("returns sum of costs of learned skills", function()
            local player = createTestPlayer(10)

            -- Learn kindle (cost 1) and pyrokinesis (cost 1)
            SkillSystem.learn_skill(player, "kindle")
            expect(SkillSystem.get_skill_points_spent(player)).to_be(1)

            SkillSystem.learn_skill(player, "pyrokinesis")
            expect(SkillSystem.get_skill_points_spent(player)).to_be(2)

            -- Learn fire_form (cost 5)
            SkillSystem.learn_skill(player, "fire_form")
            expect(SkillSystem.get_skill_points_spent(player)).to_be(7)
        end)

        it("decreases when skills are unlearned", function()
            local player = createTestPlayer(10)
            SkillSystem.learn_skill(player, "kindle")      -- cost 1
            SkillSystem.learn_skill(player, "fire_form")   -- cost 5
            expect(SkillSystem.get_skill_points_spent(player)).to_be(6)

            SkillSystem.unlearn_skill(player, "kindle")
            expect(SkillSystem.get_skill_points_spent(player)).to_be(5)
        end)

        it("returns 0 for nil player", function()
            expect(SkillSystem.get_skill_points_spent(nil)).to_be(0)
        end)
    end)

    --------------------------------------------------------------------------------
    -- SKILL POINTS REMAINING
    --------------------------------------------------------------------------------

    describe("get_skill_points_remaining", function()
        it("returns total points when no skills learned", function()
            local player = createTestPlayer(10)
            expect(SkillSystem.get_skill_points_remaining(player)).to_be(10)
        end)

        it("returns total minus spent", function()
            local player = createTestPlayer(10)
            SkillSystem.learn_skill(player, "kindle")      -- cost 1
            SkillSystem.learn_skill(player, "combustion")  -- cost 2
            -- spent = 3, remaining = 10 - 3 = 7
            expect(SkillSystem.get_skill_points_remaining(player)).to_be(7)
        end)

        it("can go to 0", function()
            local player = createTestPlayer(6)
            SkillSystem.learn_skill(player, "kindle")      -- cost 1
            SkillSystem.learn_skill(player, "fire_form")   -- cost 5
            -- spent = 6, remaining = 0
            expect(SkillSystem.get_skill_points_remaining(player)).to_be(0)
        end)

        it("returns 0 for nil player", function()
            expect(SkillSystem.get_skill_points_remaining(nil)).to_be(0)
        end)

        it("returns 0 when player has no skill_points field", function()
            local player = {}
            SkillSystem.init(player)
            expect(SkillSystem.get_skill_points_remaining(player)).to_be(0)
        end)
    end)

    --------------------------------------------------------------------------------
    -- CAN LEARN SKILL
    --------------------------------------------------------------------------------

    describe("can_learn_skill", function()
        it("returns true when player has enough points", function()
            local player = createTestPlayer(10)
            expect(SkillSystem.can_learn_skill(player, "kindle")).to_be(true)       -- cost 1
            expect(SkillSystem.can_learn_skill(player, "fire_form")).to_be(true)    -- cost 5
        end)

        it("returns false when player lacks points", function()
            local player = createTestPlayer(2)
            expect(SkillSystem.can_learn_skill(player, "kindle")).to_be(true)       -- cost 1
            expect(SkillSystem.can_learn_skill(player, "fire_form")).to_be(false)   -- cost 5
        end)

        it("returns false when skill already learned", function()
            local player = createTestPlayer(10)
            SkillSystem.learn_skill(player, "kindle")
            expect(SkillSystem.can_learn_skill(player, "kindle")).to_be(false)
        end)

        it("returns false for unknown skill", function()
            local player = createTestPlayer(10)
            expect(SkillSystem.can_learn_skill(player, "nonexistent")).to_be(false)
        end)

        it("considers already spent points", function()
            local player = createTestPlayer(6)
            SkillSystem.learn_skill(player, "scorch_master")  -- cost 4, remaining = 2
            expect(SkillSystem.can_learn_skill(player, "combustion")).to_be(true)   -- cost 2
            expect(SkillSystem.can_learn_skill(player, "flame_familiar")).to_be(false) -- cost 3
        end)

        it("returns false for nil player or skill", function()
            local player = createTestPlayer(10)
            expect(SkillSystem.can_learn_skill(nil, "kindle")).to_be(false)
            expect(SkillSystem.can_learn_skill(player, nil)).to_be(false)
        end)
    end)

    --------------------------------------------------------------------------------
    -- INTEGRATION: learn_skill respects points
    --------------------------------------------------------------------------------

    describe("learn_skill with skill points", function()
        it("fails when player lacks points", function()
            local player = createTestPlayer(2)
            -- fire_form costs 5, player only has 2
            local success = SkillSystem.learn_skill(player, "fire_form")
            expect(success).to_be(false)
            expect(SkillSystem.has_skill(player, "fire_form")).to_be(false)
        end)

        it("succeeds when player has exact points", function()
            local player = createTestPlayer(5)
            local success = SkillSystem.learn_skill(player, "fire_form")
            expect(success).to_be(true)
            expect(SkillSystem.has_skill(player, "fire_form")).to_be(true)
            expect(SkillSystem.get_skill_points_remaining(player)).to_be(0)
        end)
    end)
end)

-- Run tests if executed directly
if arg and arg[0] and arg[0]:match("test_skill_points%.lua$") then
    TestRunner.run()
end

return TestRunner
