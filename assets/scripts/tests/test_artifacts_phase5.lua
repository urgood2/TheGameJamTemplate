--[[
================================================================================
TEST: Artifacts & Equipment Phase 5 - Demo Implementation
================================================================================
TDD tests for Phase 5 requirements:
1. Artifact data definitions using Joker schema (calculate function)
2. Equipment schema completeness (12+ items)
3. Proc triggers and stat applications

RED PHASE: These tests are written BEFORE implementation.
================================================================================
]]

local TestRunner = require("tests.test_runner")
local describe = TestRunner.describe
local it = TestRunner.it
local expect = TestRunner.expect

--------------------------------------------------------------------------------
-- SECTION 1: Artifact Data Definitions
--------------------------------------------------------------------------------

describe("Phase 5: Artifact Data Definitions", function()
    local Artifacts = require("data.artifacts")

    it("has at least 6 artifacts defined", function()
        local count = 0
        for id, def in pairs(Artifacts) do
            if type(def) == "table" and def.name then
                count = count + 1
            end
        end
        expect(count >= 6).to_be(true)
    end)

    it("artifacts have required fields", function()
        for id, def in pairs(Artifacts) do
            if type(def) == "table" and def.name then
                expect(def.id).never().to_be_nil()
                expect(def.name).never().to_be_nil()
                expect(def.description).never().to_be_nil()
                expect(def.rarity).never().to_be_nil()
            end
        end
    end)

    it("artifacts have calculate function", function()
        local hasCalculate = false
        for id, def in pairs(Artifacts) do
            if type(def) == "table" and type(def.calculate) == "function" then
                hasCalculate = true
                break
            end
        end
        expect(hasCalculate).to_be(true)
    end)

    it("has fire-themed artifact", function()
        local hasFire = false
        for id, def in pairs(Artifacts) do
            if type(def) == "table" and def.element == "fire" then
                hasFire = true
                break
            end
        end
        expect(hasFire).to_be(true)
    end)

    it("has ice-themed artifact", function()
        local hasIce = false
        for id, def in pairs(Artifacts) do
            if type(def) == "table" and def.element == "ice" then
                hasIce = true
                break
            end
        end
        expect(hasIce).to_be(true)
    end)

    it("has lightning-themed artifact", function()
        local hasLightning = false
        for id, def in pairs(Artifacts) do
            if type(def) == "table" and def.element == "lightning" then
                hasLightning = true
                break
            end
        end
        expect(hasLightning).to_be(true)
    end)
end)

--------------------------------------------------------------------------------
-- SECTION 2: Artifact Helper Functions
--------------------------------------------------------------------------------

describe("Phase 5: Artifact Helper Functions", function()
    local Artifacts = require("data.artifacts")

    it("has get helper function", function()
        expect(Artifacts.get).never().to_be_nil()
    end)

    it("has getAll helper function", function()
        expect(Artifacts.getAll).never().to_be_nil()
    end)

    it("has getByRarity helper function", function()
        expect(Artifacts.getByRarity).never().to_be_nil()
    end)

    it("has getByElement helper function", function()
        expect(Artifacts.getByElement).never().to_be_nil()
    end)
end)

--------------------------------------------------------------------------------
-- SECTION 3: Equipment Completeness
--------------------------------------------------------------------------------

describe("Phase 5: Equipment Completeness", function()
    local Equipment = require("data.equipment")

    it("has at least 12 equipment items", function()
        local count = 0
        for id, def in pairs(Equipment) do
            if type(def) == "table" and def.name and def.slot then
                count = count + 1
            end
        end
        expect(count >= 12).to_be(true)
    end)

    it("has items for each slot type", function()
        local slots = {}
        for id, def in pairs(Equipment) do
            if type(def) == "table" and def.slot then
                slots[def.slot] = true
            end
        end
        -- Essential slots
        expect(slots["main_hand"]).to_be(true)
        expect(slots["chest"]).to_be(true)
        expect(slots["head"]).to_be(true)
    end)

    it("equipment has stats field", function()
        local hasStats = false
        for id, def in pairs(Equipment) do
            if type(def) == "table" and def.stats then
                hasStats = true
                break
            end
        end
        expect(hasStats).to_be(true)
    end)

    it("equipment can have procs", function()
        local hasProcs = false
        for id, def in pairs(Equipment) do
            if type(def) == "table" and def.procs then
                hasProcs = true
                break
            end
        end
        expect(hasProcs).to_be(true)
    end)
end)

--------------------------------------------------------------------------------
-- SECTION 4: Equipment New Items (Phase 5 additions)
--------------------------------------------------------------------------------

describe("Phase 5: Equipment New Items", function()
    local Equipment = require("data.equipment")

    -- Verify spec items exist (from plan - these should be implemented)
    it("has main_hand weapon variety", function()
        local weapons = Equipment.getBySlot("main_hand")
        expect(#weapons >= 2).to_be(true)
    end)

    it("has chest armor variety", function()
        local armor = Equipment.getBySlot("chest")
        expect(#armor >= 1).to_be(true)
    end)

    it("has accessory variety (rings, necklace)", function()
        local ring1 = Equipment.getBySlot("ring1")
        local ring2 = Equipment.getBySlot("ring2")
        local necklace = Equipment.getBySlot("necklace")
        local totalAccessories = #ring1 + #ring2 + #necklace
        expect(totalAccessories >= 3).to_be(true)
    end)

    it("equipment getByRarity works", function()
        local rares = Equipment.getByRarity("Rare")
        expect(rares).never().to_be_nil()
        expect(#rares >= 2).to_be(true)
    end)
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

-- Only run if executed directly
if arg and arg[0] and arg[0]:match("test_artifacts_phase5%.lua$") then
    local success = TestRunner.run()
    os.exit(success and 0 or 1)
end

return TestRunner
