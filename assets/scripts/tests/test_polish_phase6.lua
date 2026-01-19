--[[
================================================================================
TEST: Polish Features Phase 6 - Demo Implementation
================================================================================
TDD tests for Phase 6 requirements:
1. Tutorial skip system
2. Demo footer UI (overlay + feedback buttons)
3. Shop pack UI structure

These tests verify the existence and basic structure of polish features.
================================================================================
]]

local TestRunner = require("tests.test_runner")
local describe = TestRunner.describe
local it = TestRunner.it
local expect = TestRunner.expect

-- Stub globals needed by UI modules at runtime
if not Col then
    _G.Col = function(r, g, b, a)
        return { r = r or 0, g = g or 0, b = b or 0, a = a or 255 }
    end
end
if not globals then
    _G.globals = {
        screenWidth = function() return 1920 end,
        screenHeight = function() return 1080 end,
    }
end

--------------------------------------------------------------------------------
-- SECTION 1: Tutorial Skip System
--------------------------------------------------------------------------------

describe("Phase 6: Tutorial Skip System", function()
    local TutorialDialogue = require("tutorial.dialogue")

    it("tutorial dialogue module exists", function()
        expect(TutorialDialogue).never().to_be_nil()
    end)

    it("has skip as instance method", function()
        -- skip is an instance method (TutorialDialogue:skip())
        expect(TutorialDialogue.__index and TutorialDialogue.__index.skip or TutorialDialogue.skip).never().to_be_nil()
    end)

    it("has onSkipAll callback setter", function()
        -- onSkipAll allows setting a callback when user holds ESC
        expect(TutorialDialogue.__index and TutorialDialogue.__index.onSkipAll or TutorialDialogue.onSkipAll).never().to_be_nil()
    end)

    it("DEFAULTS includes skip configuration", function()
        expect(TutorialDialogue.DEFAULTS).never().to_be_nil()
    end)
end)

--------------------------------------------------------------------------------
-- SECTION 2: Demo Footer UI
--------------------------------------------------------------------------------

describe("Phase 6: Demo Footer UI", function()
    local DemoFooterUI = require("ui.demo_footer_ui")

    it("demo footer module exists", function()
        expect(DemoFooterUI).never().to_be_nil()
    end)

    it("has init function", function()
        expect(DemoFooterUI.init).never().to_be_nil()
    end)

    it("has update function", function()
        expect(DemoFooterUI.update).never().to_be_nil()
    end)

    it("has draw function", function()
        expect(DemoFooterUI.draw).never().to_be_nil()
    end)

    it("has show function", function()
        expect(DemoFooterUI.show).never().to_be_nil()
    end)

    it("has hide function", function()
        expect(DemoFooterUI.hide).never().to_be_nil()
    end)

    it("has cleanup function", function()
        expect(DemoFooterUI.cleanup).never().to_be_nil()
    end)
end)

--------------------------------------------------------------------------------
-- SECTION 3: Shop Pack UI
--------------------------------------------------------------------------------

describe("Phase 6: Shop Pack UI", function()
    local ShopPackUI = require("ui.shop_pack_ui")

    it("shop pack module exists", function()
        expect(ShopPackUI).never().to_be_nil()
    end)

    it("has init function", function()
        expect(ShopPackUI.init).never().to_be_nil()
    end)

    it("has update function", function()
        expect(ShopPackUI.update).never().to_be_nil()
    end)

    it("has draw function", function()
        expect(ShopPackUI.draw).never().to_be_nil()
    end)

    it("has show function", function()
        expect(ShopPackUI.show).never().to_be_nil()
    end)

    it("has hide function", function()
        expect(ShopPackUI.hide).never().to_be_nil()
    end)

    it("has cleanup function", function()
        expect(ShopPackUI.cleanup).never().to_be_nil()
    end)
end)

--------------------------------------------------------------------------------
-- SECTION 4: Shop System Core
--------------------------------------------------------------------------------

describe("Phase 6: Shop System Core", function()
    local ShopSystem = require("core.shop_system")

    it("shop system module exists", function()
        expect(ShopSystem).never().to_be_nil()
    end)

    it("has pack purchase function", function()
        expect(ShopSystem.purchasePack).never().to_be_nil()
    end)

    it("has pack types function", function()
        expect(ShopSystem.getPackTypes).never().to_be_nil()
    end)

    it("has pack generation function", function()
        expect(ShopSystem.generatePack).never().to_be_nil()
    end)
end)

--------------------------------------------------------------------------------
-- SECTION 5: Content Availability (No Dead Content)
--------------------------------------------------------------------------------

describe("Phase 6: Content Availability", function()
    -- Verify all new content types are defined and not empty

    it("avatars are accessible", function()
        local Avatars = require("data.avatars")
        local count = 0
        for id, def in pairs(Avatars) do
            if type(def) == "table" and def.type then
                count = count + 1
            end
        end
        expect(count > 0).to_be(true)
    end)

    it("skills are accessible", function()
        local Skills = require("data.skills")
        local all = Skills.getAllSkills()
        expect(#all > 0).to_be(true)
    end)

    it("artifacts are accessible", function()
        local Artifacts = require("data.artifacts")
        local all = Artifacts.getAll()
        expect(#all > 0).to_be(true)
    end)

    it("equipment is accessible", function()
        local Equipment = require("data.equipment")
        local all = Equipment.getAll()
        expect(#all > 0).to_be(true)
    end)
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

-- Only run if executed directly
if arg and arg[0] and arg[0]:match("test_polish_phase6%.lua$") then
    local success = TestRunner.run()
    os.exit(success and 0 or 1)
end

return TestRunner
