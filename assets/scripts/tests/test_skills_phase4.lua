--[[
================================================================================
TEST: Skills Phase 4 - Demo Implementation
================================================================================
TDD tests for Phase 4 requirements:
1. Skill data definitions (8-10 skills, 2 per element)
2. Skill runtime system (learn skills, apply stat changes)
3. Skill cleanup on reset

RED PHASE: These tests are written BEFORE implementation.
================================================================================
]]

local TestRunner = require("tests.test_runner")
local describe = TestRunner.describe
local it = TestRunner.it
local expect = TestRunner.expect

--------------------------------------------------------------------------------
-- SECTION 1: Skill Data Definitions
--------------------------------------------------------------------------------

describe("Phase 4: Skill Data Definitions", function()
    local Skills = require("data.skills")

    it("has at least 8 skills defined", function()
        local count = 0
        for id, def in pairs(Skills) do
            if type(def) == "table" and def.name then
                count = count + 1
            end
        end
        expect(count >= 8).to_be(true)
    end)

    it("has fire element skills", function()
        local fireSkills = {}
        for id, def in pairs(Skills) do
            if type(def) == "table" and def.element == "fire" then
                fireSkills[#fireSkills + 1] = id
            end
        end
        expect(#fireSkills >= 2).to_be(true)
    end)

    it("has ice element skills", function()
        local iceSkills = {}
        for id, def in pairs(Skills) do
            if type(def) == "table" and def.element == "ice" then
                iceSkills[#iceSkills + 1] = id
            end
        end
        expect(#iceSkills >= 2).to_be(true)
    end)

    it("has lightning element skills", function()
        local lightningSkills = {}
        for id, def in pairs(Skills) do
            if type(def) == "table" and def.element == "lightning" then
                lightningSkills[#lightningSkills + 1] = id
            end
        end
        expect(#lightningSkills >= 2).to_be(true)
    end)

    it("has void element skills", function()
        local voidSkills = {}
        for id, def in pairs(Skills) do
            if type(def) == "table" and def.element == "void" then
                voidSkills[#voidSkills + 1] = id
            end
        end
        expect(#voidSkills >= 2).to_be(true)
    end)

    it("skills have required fields", function()
        for id, def in pairs(Skills) do
            if type(def) == "table" and def.name then
                expect(def.name).never().to_be_nil()
                expect(def.description).never().to_be_nil()
                expect(def.element).never().to_be_nil()
                expect(def.effects).never().to_be_nil()
            end
        end
    end)

    it("skill effects have stat_buff type", function()
        local hasStatBuff = false
        for id, def in pairs(Skills) do
            if type(def) == "table" and def.effects then
                for _, effect in ipairs(def.effects) do
                    if effect.type == "stat_buff" then
                        hasStatBuff = true
                        break
                    end
                end
            end
            if hasStatBuff then break end
        end
        expect(hasStatBuff).to_be(true)
    end)
end)

--------------------------------------------------------------------------------
-- SECTION 2: Skill System Runtime
--------------------------------------------------------------------------------

describe("Phase 4: Skill System Runtime", function()
    local SkillSystem = require("core.skill_system")

    it("exists as a module", function()
        expect(SkillSystem).never().to_be_nil()
    end)

    it("has learn_skill function", function()
        expect(SkillSystem.learn_skill).never().to_be_nil()
    end)

    it("has unlearn_skill function", function()
        expect(SkillSystem.unlearn_skill).never().to_be_nil()
    end)

    it("has get_learned_skills function", function()
        expect(SkillSystem.get_learned_skills).never().to_be_nil()
    end)

    it("has apply_skill_buffs function", function()
        expect(SkillSystem.apply_skill_buffs).never().to_be_nil()
    end)

    it("has remove_skill_buffs function", function()
        expect(SkillSystem.remove_skill_buffs).never().to_be_nil()
    end)

    it("has cleanup function", function()
        expect(SkillSystem.cleanup).never().to_be_nil()
    end)
end)

--------------------------------------------------------------------------------
-- SECTION 3: Skill Learning Flow
--------------------------------------------------------------------------------

describe("Phase 4: Skill Learning Flow", function()
    local SkillSystem = require("core.skill_system")

    it("can track learned skills on player", function()
        local player = {}
        SkillSystem.init(player)

        local learned = SkillSystem.get_learned_skills(player)
        expect(learned).never().to_be_nil()
        expect(#learned).to_be(0)
    end)

    it("can learn a skill", function()
        local player = {}
        SkillSystem.init(player)

        local success = SkillSystem.learn_skill(player, "flame_affinity")
        expect(success).to_be(true)

        local learned = SkillSystem.get_learned_skills(player)
        expect(#learned).to_be(1)
    end)

    it("cannot learn the same skill twice", function()
        local player = {}
        SkillSystem.init(player)

        SkillSystem.learn_skill(player, "flame_affinity")
        local success = SkillSystem.learn_skill(player, "flame_affinity")
        expect(success).to_be(false)

        local learned = SkillSystem.get_learned_skills(player)
        expect(#learned).to_be(1)
    end)

    it("can unlearn a skill", function()
        local player = {}
        SkillSystem.init(player)

        SkillSystem.learn_skill(player, "flame_affinity")
        local success = SkillSystem.unlearn_skill(player, "flame_affinity")
        expect(success).to_be(true)

        local learned = SkillSystem.get_learned_skills(player)
        expect(#learned).to_be(0)
    end)
end)

--------------------------------------------------------------------------------
-- SECTION 4: Skill Helper Functions
--------------------------------------------------------------------------------

describe("Phase 4: Skill Helper Functions", function()
    local Skills = require("data.skills")

    it("has getByElement helper function", function()
        expect(Skills.getByElement).never().to_be_nil()
    end)

    it("getByElement returns fire skills", function()
        local fireSkills = Skills.getByElement("fire")
        expect(fireSkills).never().to_be_nil()
        expect(#fireSkills >= 2).to_be(true)
    end)

    it("has getAllSkills helper function", function()
        expect(Skills.getAllSkills).never().to_be_nil()
    end)
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

-- Only run if executed directly
if arg and arg[0] and arg[0]:match("test_skills_phase4%.lua$") then
    local success = TestRunner.run()
    os.exit(success and 0 or 1)
end

return TestRunner
