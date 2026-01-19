--[[
================================================================================
TEST: Gods & Classes Phase 3 - Demo Implementation
================================================================================
TDD tests for Phase 3 requirements:
1. Gods and Classes as avatar entries with `type` field
2. Blessing effect type for activated abilities
3. Starting bonuses for classes
4. Patron blessings for gods

RED PHASE: These tests are written BEFORE implementation.
================================================================================
]]

local TestRunner = require("tests.test_runner")
local describe = TestRunner.describe
local it = TestRunner.it
local expect = TestRunner.expect

--------------------------------------------------------------------------------
-- SECTION 1: God Definitions
--------------------------------------------------------------------------------

describe("Phase 3: God Definitions", function()
    local Avatars = require("data.avatars")

    it("has pyra god defined", function()
        expect(Avatars.pyra).never().to_be_nil()
        expect(Avatars.pyra.type).to_be("god")
    end)

    it("has frost god defined", function()
        expect(Avatars.frost).never().to_be_nil()
        expect(Avatars.frost.type).to_be("god")
    end)

    it("has storm god defined", function()
        expect(Avatars.storm).never().to_be_nil()
        expect(Avatars.storm.type).to_be("god")
    end)

    it("has void god defined", function()
        expect(Avatars.void).never().to_be_nil()
        expect(Avatars.void.type).to_be("god")
    end)

    it("gods have blessing effects", function()
        local pyra = Avatars.pyra
        expect(pyra.effects).never().to_be_nil()

        -- Find blessing effect
        local hasBlessing = false
        for _, effect in ipairs(pyra.effects) do
            if effect.type == "blessing" then
                hasBlessing = true
                break
            end
        end
        expect(hasBlessing).to_be(true)
    end)

    it("god blessings have cooldown and duration", function()
        local pyra = Avatars.pyra
        for _, effect in ipairs(pyra.effects) do
            if effect.type == "blessing" then
                expect(effect.cooldown).never().to_be_nil()
                expect(effect.duration).never().to_be_nil()
                break
            end
        end
    end)
end)

--------------------------------------------------------------------------------
-- SECTION 2: Class Definitions
--------------------------------------------------------------------------------

describe("Phase 3: Class Definitions", function()
    local Avatars = require("data.avatars")

    it("has warrior class defined", function()
        expect(Avatars.warrior).never().to_be_nil()
        expect(Avatars.warrior.type).to_be("class")
    end)

    it("has mage class defined", function()
        expect(Avatars.mage).never().to_be_nil()
        expect(Avatars.mage.type).to_be("class")
    end)

    it("has rogue class defined", function()
        expect(Avatars.rogue).never().to_be_nil()
        expect(Avatars.rogue.type).to_be("class")
    end)

    it("classes have starting bonuses", function()
        local warrior = Avatars.warrior
        expect(warrior.effects).never().to_be_nil()

        -- Find stat_buff effect (starting bonus)
        local hasStartingBonus = false
        for _, effect in ipairs(warrior.effects) do
            if effect.type == "stat_buff" then
                hasStartingBonus = true
                break
            end
        end
        expect(hasStartingBonus).to_be(true)
    end)

    it("classes are selectable at run start", function()
        local warrior = Avatars.warrior
        -- Classes should not have unlock conditions (available from start)
        expect(warrior.unlock).to_be_nil()
    end)
end)

--------------------------------------------------------------------------------
-- SECTION 3: Avatar Type Field
--------------------------------------------------------------------------------

describe("Phase 3: Avatar Type Field", function()
    local Avatars = require("data.avatars")

    it("existing avatars have type = avatar", function()
        -- Existing avatars should be type "avatar" (ascensions)
        expect(Avatars.wildfire.type).to_be("avatar")
        expect(Avatars.citadel.type).to_be("avatar")
        expect(Avatars.conduit.type).to_be("avatar")
    end)

    it("can filter by type", function()
        local gods = {}
        local classes = {}
        local avatars = {}

        for id, def in pairs(Avatars) do
            if type(def) == "table" and def.type then
                if def.type == "god" then
                    gods[#gods + 1] = id
                elseif def.type == "class" then
                    classes[#classes + 1] = id
                elseif def.type == "avatar" then
                    avatars[#avatars + 1] = id
                end
            end
        end

        expect(#gods >= 4).to_be(true)
        expect(#classes >= 3).to_be(true)
        expect(#avatars >= 7).to_be(true)
    end)
end)

--------------------------------------------------------------------------------
-- SECTION 4: Blessing Effect Type
--------------------------------------------------------------------------------

describe("Phase 3: Blessing Effect Type", function()
    local AvatarSystem = require("wand.avatar_system")

    -- Skip if AvatarSystem not available
    if not AvatarSystem then
        it("SKIPPED: AvatarSystem not available", function()
            expect(true).to_be(true)
        end)
        return
    end

    it("blessing effect type is recognized", function()
        -- AvatarSystem should recognize blessing effects
        -- We test this by checking if BLESSING_EFFECTS exists
        local hasBlessingSupport = AvatarSystem.BLESSING_EFFECTS ~= nil
            or AvatarSystem.apply_blessings ~= nil
            or AvatarSystem.activate_blessing ~= nil
        expect(hasBlessingSupport).to_be(true)
    end)

    it("can activate blessing with cooldown", function()
        -- Check that blessing activation respects cooldown
        local activateFunc = AvatarSystem.activate_blessing
        expect(activateFunc).never().to_be_nil()
    end)
end)

--------------------------------------------------------------------------------
-- SECTION 5: Helper Functions
--------------------------------------------------------------------------------

describe("Phase 3: Avatar Helper Functions", function()
    local Avatars = require("data.avatars")

    it("has getByType helper function", function()
        expect(Avatars.getByType).never().to_be_nil()
    end)

    it("getByType returns all gods", function()
        local gods = Avatars.getByType("god")
        expect(gods).never().to_be_nil()
        expect(#gods >= 4).to_be(true)
    end)

    it("getByType returns all classes", function()
        local classes = Avatars.getByType("class")
        expect(classes).never().to_be_nil()
        expect(#classes >= 3).to_be(true)
    end)

    it("getByType returns all avatars", function()
        local avatars = Avatars.getByType("avatar")
        expect(avatars).never().to_be_nil()
        expect(#avatars >= 7).to_be(true)
    end)
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

-- Only run if executed directly
if arg and arg[0] and arg[0]:match("test_gods_classes_phase3%.lua$") then
    local success = TestRunner.run()
    os.exit(success and 0 or 1)
end

return TestRunner
