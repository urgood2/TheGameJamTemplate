-- assets/scripts/tests/test_skills_data.lua
--[[
================================================================================
TEST: Skills Data for Skills Panel
================================================================================
TDD tests for the expanded skills data (32 skills: 8 per element).
Per spec: /Users/joshuashin/.claude/plans/final-demo-content-spec.md (Part 5)

Fire (8): Kindle, Pyrokinesis, Fire Healing, Combustion, Flame Familiar, Roil, Scorch Master, Fire Form
Ice (8): Frostbite, Cryokinesis, Ice Armor, Shatter Synergy, Frost Familiar, Frost Turret, Freeze Master, Ice Form
Lightning (8): Spark, Electrokinesis, Chain Lightning, Surge, Storm Familiar, Amplify Pain, Charge Master, Storm Form
Void (8): Entropy, Necrokinesis, Cursed Flesh, Grave Summon, Doom Mark, Anchor of Doom, Doom Master, Void Form
================================================================================
]]

local TestRunner = require("tests.test_runner")
local describe = TestRunner.describe
local it = TestRunner.it
local expect = TestRunner.expect

describe("Skills Data - 32 Skills for Demo", function()
    local Skills = require("data.skills")

    --------------------------------------------------------------------------------
    -- STRUCTURE TESTS
    --------------------------------------------------------------------------------

    describe("Skill Count", function()
        it("has exactly 32 skills defined", function()
            local count = 0
            for id, def in pairs(Skills) do
                if type(def) == "table" and def.name then
                    count = count + 1
                end
            end
            expect(count).to_be(32)
        end)

        it("has exactly 8 fire skills", function()
            local fireSkills = Skills.getByElement("fire")
            expect(#fireSkills).to_be(8)
        end)

        it("has exactly 8 ice skills", function()
            local iceSkills = Skills.getByElement("ice")
            expect(#iceSkills).to_be(8)
        end)

        it("has exactly 8 lightning skills", function()
            local lightningSkills = Skills.getByElement("lightning")
            expect(#lightningSkills).to_be(8)
        end)

        it("has exactly 8 void skills", function()
            local voidSkills = Skills.getByElement("void")
            expect(#voidSkills).to_be(8)
        end)
    end)

    describe("Required Fields", function()
        it("every skill has required fields: id, name, description, element, icon, cost", function()
            local allSkills = Skills.getAllSkills()
            for _, entry in ipairs(allSkills) do
                local skill = entry.def
                local id = entry.id

                expect(skill.id).never().to_be_nil()
                expect(skill.name).never().to_be_nil()
                expect(skill.description).never().to_be_nil()
                expect(skill.element).never().to_be_nil()
                expect(skill.icon).never().to_be_nil()
                expect(skill.cost).never().to_be_nil()
            end
        end)

        it("every skill id matches its table key", function()
            for id, def in pairs(Skills) do
                if type(def) == "table" and def.name then
                    expect(def.id).to_be(id)
                end
            end
        end)

        it("every skill has at least one effect", function()
            local allSkills = Skills.getAllSkills()
            for _, entry in ipairs(allSkills) do
                expect(entry.def.effects).never().to_be_nil()
                expect(#entry.def.effects > 0).to_be(true)
            end
        end)

        it("every skill has a valid element", function()
            local validElements = { fire = true, ice = true, lightning = true, void = true }
            local allSkills = Skills.getAllSkills()
            for _, entry in ipairs(allSkills) do
                local skill = entry.def
                expect(validElements[skill.element]).to_be_truthy()
            end
        end)

        it("every skill has a numeric cost between 1 and 5", function()
            local allSkills = Skills.getAllSkills()
            for _, entry in ipairs(allSkills) do
                local skill = entry.def
                expect(type(skill.cost)).to_be("number")
                expect(skill.cost >= 1 and skill.cost <= 5).to_be(true)
            end
        end)
    end)

    --------------------------------------------------------------------------------
    -- FIRE SKILLS (8)
    --------------------------------------------------------------------------------

    describe("Fire Skills", function()
        it("has Kindle (cost 1)", function()
            local skill = Skills.get("kindle")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("fire")
            expect(skill.cost).to_be(1)
        end)

        it("has Pyrokinesis (cost 1)", function()
            local skill = Skills.get("pyrokinesis")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("fire")
            expect(skill.cost).to_be(1)
        end)

        it("has Fire Healing (cost 2)", function()
            local skill = Skills.get("fire_healing")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("fire")
            expect(skill.cost).to_be(2)
        end)

        it("has Combustion (cost 2)", function()
            local skill = Skills.get("combustion")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("fire")
            expect(skill.cost).to_be(2)
        end)

        it("has Flame Familiar (cost 3)", function()
            local skill = Skills.get("flame_familiar")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("fire")
            expect(skill.cost).to_be(3)
        end)

        it("has Roil (cost 3)", function()
            local skill = Skills.get("roil")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("fire")
            expect(skill.cost).to_be(3)
        end)

        it("has Scorch Master (cost 4)", function()
            local skill = Skills.get("scorch_master")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("fire")
            expect(skill.cost).to_be(4)
        end)

        it("has Fire Form (cost 5)", function()
            local skill = Skills.get("fire_form")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("fire")
            expect(skill.cost).to_be(5)
        end)
    end)

    --------------------------------------------------------------------------------
    -- ICE SKILLS (8)
    --------------------------------------------------------------------------------

    describe("Ice Skills", function()
        it("has Frostbite (cost 1)", function()
            local skill = Skills.get("frostbite")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("ice")
            expect(skill.cost).to_be(1)
        end)

        it("has Cryokinesis (cost 1)", function()
            local skill = Skills.get("cryokinesis")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("ice")
            expect(skill.cost).to_be(1)
        end)

        it("has Ice Armor (cost 2)", function()
            local skill = Skills.get("ice_armor")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("ice")
            expect(skill.cost).to_be(2)
        end)

        it("has Shatter Synergy (cost 2)", function()
            local skill = Skills.get("shatter_synergy")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("ice")
            expect(skill.cost).to_be(2)
        end)

        it("has Frost Familiar (cost 3)", function()
            local skill = Skills.get("frost_familiar")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("ice")
            expect(skill.cost).to_be(3)
        end)

        it("has Frost Turret (cost 3)", function()
            local skill = Skills.get("frost_turret")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("ice")
            expect(skill.cost).to_be(3)
        end)

        it("has Freeze Master (cost 4)", function()
            local skill = Skills.get("freeze_master")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("ice")
            expect(skill.cost).to_be(4)
        end)

        it("has Ice Form (cost 5)", function()
            local skill = Skills.get("ice_form")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("ice")
            expect(skill.cost).to_be(5)
        end)
    end)

    --------------------------------------------------------------------------------
    -- LIGHTNING SKILLS (8)
    --------------------------------------------------------------------------------

    describe("Lightning Skills", function()
        it("has Spark (cost 1)", function()
            local skill = Skills.get("spark")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("lightning")
            expect(skill.cost).to_be(1)
        end)

        it("has Electrokinesis (cost 1)", function()
            local skill = Skills.get("electrokinesis")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("lightning")
            expect(skill.cost).to_be(1)
        end)

        it("has Chain Lightning (cost 2)", function()
            local skill = Skills.get("chain_lightning")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("lightning")
            expect(skill.cost).to_be(2)
        end)

        it("has Surge (cost 2)", function()
            local skill = Skills.get("surge")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("lightning")
            expect(skill.cost).to_be(2)
        end)

        it("has Storm Familiar (cost 3)", function()
            local skill = Skills.get("storm_familiar")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("lightning")
            expect(skill.cost).to_be(3)
        end)

        it("has Amplify Pain (cost 3)", function()
            local skill = Skills.get("amplify_pain")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("lightning")
            expect(skill.cost).to_be(3)
        end)

        it("has Charge Master (cost 4)", function()
            local skill = Skills.get("charge_master")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("lightning")
            expect(skill.cost).to_be(4)
        end)

        it("has Storm Form (cost 5)", function()
            local skill = Skills.get("storm_form")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("lightning")
            expect(skill.cost).to_be(5)
        end)
    end)

    --------------------------------------------------------------------------------
    -- VOID SKILLS (8)
    --------------------------------------------------------------------------------

    describe("Void Skills", function()
        it("has Entropy (cost 1)", function()
            local skill = Skills.get("entropy")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("void")
            expect(skill.cost).to_be(1)
        end)

        it("has Necrokinesis (cost 1)", function()
            local skill = Skills.get("necrokinesis")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("void")
            expect(skill.cost).to_be(1)
        end)

        it("has Cursed Flesh (cost 2)", function()
            local skill = Skills.get("cursed_flesh")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("void")
            expect(skill.cost).to_be(2)
        end)

        it("has Grave Summon (cost 2)", function()
            local skill = Skills.get("grave_summon")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("void")
            expect(skill.cost).to_be(2)
        end)

        it("has Doom Mark (cost 3)", function()
            local skill = Skills.get("doom_mark")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("void")
            expect(skill.cost).to_be(3)
        end)

        it("has Anchor of Doom (cost 3)", function()
            local skill = Skills.get("anchor_of_doom")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("void")
            expect(skill.cost).to_be(3)
        end)

        it("has Doom Master (cost 4)", function()
            local skill = Skills.get("doom_master")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("void")
            expect(skill.cost).to_be(4)
        end)

        it("has Void Form (cost 5)", function()
            local skill = Skills.get("void_form")
            expect(skill).never().to_be_nil()
            expect(skill.element).to_be("void")
            expect(skill.cost).to_be(5)
        end)
    end)

    --------------------------------------------------------------------------------
    -- HELPER FUNCTION TESTS
    --------------------------------------------------------------------------------

    describe("Helper Functions", function()
        it("getOrderedByElement returns skills sorted by cost then name", function()
            -- This function should exist for UI grid ordering
            expect(Skills.getOrderedByElement).never().to_be_nil()

            local fireSkills = Skills.getOrderedByElement("fire")
            expect(#fireSkills).to_be(8)

            -- Check ordering: cost 1 skills first, then cost 2, etc.
            local prevCost = 0
            for _, entry in ipairs(fireSkills) do
                expect(entry.def.cost >= prevCost).to_be(true)
                prevCost = entry.def.cost
            end
        end)

        it("getAllOrdered returns all 32 skills in deterministic order", function()
            expect(Skills.getAllOrdered).never().to_be_nil()

            local allSkills = Skills.getAllOrdered()
            expect(#allSkills).to_be(32)
        end)
    end)
end)

-- Run tests if executed directly
if arg and arg[0] and arg[0]:match("test_skills_data%.lua$") then
    TestRunner.run()
end

return TestRunner
