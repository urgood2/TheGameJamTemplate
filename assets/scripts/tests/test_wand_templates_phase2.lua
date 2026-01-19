--[[
================================================================================
TEST: Wand Templates Phase 2 - Demo Implementation
================================================================================
TDD tests for Phase 2.2 requirements:
Findable wand templates with various trigger types:
- Rage Fist (every_N_seconds)
- Storm Walker (on_bump_enemy)
- Frost Anchor (on_stand_still)
- Soul Siphon (enemy_killed)
- Pain Echo (on_distance_traveled)
- Ember Pulse (every_N_seconds + AoE action)

RED PHASE: These tests are written BEFORE implementation.
================================================================================
]]

local TestRunner = require("tests.test_runner")
local describe = TestRunner.describe
local it = TestRunner.it
local expect = TestRunner.expect

--------------------------------------------------------------------------------
-- SECTION 1: Wand Template Existence
--------------------------------------------------------------------------------

describe("Phase 2.2: Wand Template Existence", function()
    local WandEngine = require("core.card_eval_order_test")
    local templates = WandEngine.wand_defs

    it("has RAGE_FIST wand template", function()
        local found = false
        for _, wand in ipairs(templates) do
            if wand.id == "RAGE_FIST" then
                found = true
                break
            end
        end
        expect(found).to_be(true)
    end)

    it("has STORM_WALKER wand template", function()
        local found = false
        for _, wand in ipairs(templates) do
            if wand.id == "STORM_WALKER" then
                found = true
                break
            end
        end
        expect(found).to_be(true)
    end)

    it("has FROST_ANCHOR wand template", function()
        local found = false
        for _, wand in ipairs(templates) do
            if wand.id == "FROST_ANCHOR" then
                found = true
                break
            end
        end
        expect(found).to_be(true)
    end)

    it("has SOUL_SIPHON wand template", function()
        local found = false
        for _, wand in ipairs(templates) do
            if wand.id == "SOUL_SIPHON" then
                found = true
                break
            end
        end
        expect(found).to_be(true)
    end)

    it("has PAIN_ECHO wand template", function()
        local found = false
        for _, wand in ipairs(templates) do
            if wand.id == "PAIN_ECHO" then
                found = true
                break
            end
        end
        expect(found).to_be(true)
    end)

    it("has EMBER_PULSE wand template", function()
        local found = false
        for _, wand in ipairs(templates) do
            if wand.id == "EMBER_PULSE" then
                found = true
                break
            end
        end
        expect(found).to_be(true)
    end)
end)

--------------------------------------------------------------------------------
-- SECTION 2: Wand Template Properties
--------------------------------------------------------------------------------

describe("Phase 2.2: Wand Template Properties", function()
    local WandEngine = require("core.card_eval_order_test")
    local templates = WandEngine.wand_defs

    local function find_wand(id)
        for _, wand in ipairs(templates) do
            if wand.id == id then
                return wand
            end
        end
        return nil
    end

    it("RAGE_FIST has valid properties", function()
        local wand = find_wand("RAGE_FIST")
        expect(wand).never().to_be_nil()
        expect(wand.type).to_be("trigger")
        expect(wand.mana_max).never().to_be_nil()
        expect(wand.cast_block_size).never().to_be_nil()
        expect(wand.total_card_slots).never().to_be_nil()
    end)

    it("STORM_WALKER has valid properties", function()
        local wand = find_wand("STORM_WALKER")
        expect(wand).never().to_be_nil()
        expect(wand.type).to_be("trigger")
        expect(wand.mana_max).never().to_be_nil()
        expect(wand.cast_block_size).never().to_be_nil()
        expect(wand.total_card_slots).never().to_be_nil()
    end)

    it("FROST_ANCHOR has valid properties", function()
        local wand = find_wand("FROST_ANCHOR")
        expect(wand).never().to_be_nil()
        expect(wand.type).to_be("trigger")
        expect(wand.mana_max).never().to_be_nil()
        expect(wand.cast_block_size).never().to_be_nil()
        expect(wand.total_card_slots).never().to_be_nil()
    end)

    it("SOUL_SIPHON has valid properties", function()
        local wand = find_wand("SOUL_SIPHON")
        expect(wand).never().to_be_nil()
        expect(wand.type).to_be("trigger")
        expect(wand.mana_max).never().to_be_nil()
        expect(wand.cast_block_size).never().to_be_nil()
        expect(wand.total_card_slots).never().to_be_nil()
    end)

    it("PAIN_ECHO has valid properties", function()
        local wand = find_wand("PAIN_ECHO")
        expect(wand).never().to_be_nil()
        expect(wand.type).to_be("trigger")
        expect(wand.mana_max).never().to_be_nil()
        expect(wand.cast_block_size).never().to_be_nil()
        expect(wand.total_card_slots).never().to_be_nil()
    end)

    it("EMBER_PULSE has valid properties", function()
        local wand = find_wand("EMBER_PULSE")
        expect(wand).never().to_be_nil()
        expect(wand.type).to_be("trigger")
        expect(wand.mana_max).never().to_be_nil()
        expect(wand.cast_block_size).never().to_be_nil()
        expect(wand.total_card_slots).never().to_be_nil()
    end)
end)

--------------------------------------------------------------------------------
-- SECTION 3: Trigger Type Associations
--------------------------------------------------------------------------------

describe("Phase 2.2: Wand Trigger Type Associations", function()
    local WandEngine = require("core.card_eval_order_test")
    local templates = WandEngine.wand_defs

    local function find_wand(id)
        for _, wand in ipairs(templates) do
            if wand.id == id then
                return wand
            end
        end
        return nil
    end

    it("RAGE_FIST has trigger_type every_N_seconds", function()
        local wand = find_wand("RAGE_FIST")
        expect(wand).never().to_be_nil()
        expect(wand.trigger_type).to_be("every_N_seconds")
    end)

    it("STORM_WALKER has trigger_type on_bump_enemy", function()
        local wand = find_wand("STORM_WALKER")
        expect(wand).never().to_be_nil()
        expect(wand.trigger_type).to_be("on_bump_enemy")
    end)

    it("FROST_ANCHOR has trigger_type on_stand_still", function()
        local wand = find_wand("FROST_ANCHOR")
        expect(wand).never().to_be_nil()
        expect(wand.trigger_type).to_be("on_stand_still")
    end)

    it("SOUL_SIPHON has trigger_type enemy_killed", function()
        local wand = find_wand("SOUL_SIPHON")
        expect(wand).never().to_be_nil()
        expect(wand.trigger_type).to_be("enemy_killed")
    end)

    it("PAIN_ECHO has trigger_type on_distance_traveled", function()
        local wand = find_wand("PAIN_ECHO")
        expect(wand).never().to_be_nil()
        expect(wand.trigger_type).to_be("on_distance_traveled")
    end)

    it("EMBER_PULSE has trigger_type every_N_seconds", function()
        local wand = find_wand("EMBER_PULSE")
        expect(wand).never().to_be_nil()
        expect(wand.trigger_type).to_be("every_N_seconds")
    end)
end)

--------------------------------------------------------------------------------
-- SECTION 4: Flavor and Display Names
--------------------------------------------------------------------------------

describe("Phase 2.2: Wand Display Names", function()
    local WandEngine = require("core.card_eval_order_test")
    local templates = WandEngine.wand_defs

    local function find_wand(id)
        for _, wand in ipairs(templates) do
            if wand.id == id then
                return wand
            end
        end
        return nil
    end

    it("RAGE_FIST has display name", function()
        local wand = find_wand("RAGE_FIST")
        expect(wand).never().to_be_nil()
        expect(wand.name).never().to_be_nil()
        expect(#wand.name > 0).to_be(true)
    end)

    it("STORM_WALKER has display name", function()
        local wand = find_wand("STORM_WALKER")
        expect(wand).never().to_be_nil()
        expect(wand.name).never().to_be_nil()
        expect(#wand.name > 0).to_be(true)
    end)

    it("FROST_ANCHOR has display name", function()
        local wand = find_wand("FROST_ANCHOR")
        expect(wand).never().to_be_nil()
        expect(wand.name).never().to_be_nil()
        expect(#wand.name > 0).to_be(true)
    end)

    it("SOUL_SIPHON has display name", function()
        local wand = find_wand("SOUL_SIPHON")
        expect(wand).never().to_be_nil()
        expect(wand.name).never().to_be_nil()
        expect(#wand.name > 0).to_be(true)
    end)

    it("PAIN_ECHO has display name", function()
        local wand = find_wand("PAIN_ECHO")
        expect(wand).never().to_be_nil()
        expect(wand.name).never().to_be_nil()
        expect(#wand.name > 0).to_be(true)
    end)

    it("EMBER_PULSE has display name", function()
        local wand = find_wand("EMBER_PULSE")
        expect(wand).never().to_be_nil()
        expect(wand.name).never().to_be_nil()
        expect(#wand.name > 0).to_be(true)
    end)
end)

--------------------------------------------------------------------------------
-- SECTION 5: Always-Cast Cards (for themed wands)
--------------------------------------------------------------------------------

describe("Phase 2.2: Wand Always-Cast Cards", function()
    local WandEngine = require("core.card_eval_order_test")
    local templates = WandEngine.wand_defs

    local function find_wand(id)
        for _, wand in ipairs(templates) do
            if wand.id == id then
                return wand
            end
        end
        return nil
    end

    it("EMBER_PULSE has fire-themed always-cast cards", function()
        local wand = find_wand("EMBER_PULSE")
        expect(wand).never().to_be_nil()
        expect(wand.always_cast_cards).never().to_be_nil()
        -- Should have at least one fire-themed card
        expect(#wand.always_cast_cards > 0).to_be(true)
    end)

    it("FROST_ANCHOR has ice-themed always-cast cards", function()
        local wand = find_wand("FROST_ANCHOR")
        expect(wand).never().to_be_nil()
        expect(wand.always_cast_cards).never().to_be_nil()
        -- Should have at least one ice-themed card
        expect(#wand.always_cast_cards > 0).to_be(true)
    end)
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

-- Only run if executed directly
if arg and arg[0] and arg[0]:match("test_wand_templates_phase2%.lua$") then
    local success = TestRunner.run()
    os.exit(success and 0 or 1)
end

return TestRunner
