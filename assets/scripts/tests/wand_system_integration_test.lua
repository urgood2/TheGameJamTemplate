--[[
================================================================================
WAND SYSTEM INTEGRATION TEST
================================================================================
Comprehensive test to verify all wand system components work together:
- Card evaluation (card_eval_order_test.lua)
- Wand executor (wand_executor.lua)
- Wand modifiers (wand_modifiers.lua)
- Wand actions (wand_actions.lua)
- Wand triggers (wand_triggers.lua)

This test ensures everything is ready for implementing cards.
================================================================================
]] --

local WandSystemTest = {}

-- Dependencies
local cardEval = require("core.card_eval_order_test")
local WandExecutor = require("wand.wand_executor")
local WandModifiers = require("wand.wand_modifiers")
local WandActions = require("wand.wand_actions")
local WandTriggers = require("wand.wand_triggers")

--[[
================================================================================
TEST 1: Card Template System
================================================================================
]] --

function WandSystemTest.test1_CardTemplates()
    print("\n" .. string.rep("=", 60))
    print("TEST 1: Card Template System")
    print(string.rep("=", 60))

    local success = true
    local errors = {}

    -- Test action cards
    local actionCards = {
        "ACTION_BASIC_PROJECTILE",
        "ACTION_FAST_ACCURATE_PROJECTILE",
        "ACTION_SLOW_ORB",
        "ACTION_EXPLOSIVE_FIRE_PROJECTILE",
    }

    for _, cardId in ipairs(actionCards) do
        if not cardEval.card_defs[cardId] then
            success = false
            table.insert(errors, "Missing action card: " .. cardId)
        else
            print("✓ Found action card: " .. cardId)
        end
    end

    -- Test modifier cards
    local modifierCards = {
        "MOD_SEEKING",
        "MOD_SPEED_UP",
        "MOD_DAMAGE_UP",
        "MOD_EXPLOSIVE",
        "MULTI_DOUBLE_CAST",
        "MULTI_TRIPLE_CAST",
    }

    for _, cardId in ipairs(modifierCards) do
        if not cardEval.card_defs[cardId] then
            success = false
            table.insert(errors, "Missing modifier card: " .. cardId)
        else
            print("✓ Found modifier card: " .. cardId)
        end
    end

    -- Test card creation
    local testCard = cardEval.create_card_from_template(cardEval.card_defs.ACTION_BASIC_PROJECTILE)
    if not testCard or not testCard.card_id then
        success = false
        table.insert(errors, "Failed to create card from template")
    else
        print("✓ Successfully created card instance: " .. testCard.card_id)
    end

    if success then
        print("\n✅ TEST 1 PASSED: All card templates available")
    else
        print("\n❌ TEST 1 FAILED:")
        for _, err in ipairs(errors) do
            print("  - " .. err)
        end
    end

    return success
end

--[[
================================================================================
TEST 2: Modifier Aggregation System
================================================================================
]] --

function WandSystemTest.test2_ModifierAggregation()
    print("\n" .. string.rep("=", 60))
    print("TEST 2: Modifier Aggregation System")
    print(string.rep("=", 60))

    local success = true
    local errors = {}

    -- Create modifier cards
    local modifierCards = {
        cardEval.create_card_from_template(cardEval.card_defs.MOD_DAMAGE_UP),
        cardEval.create_card_from_template(cardEval.card_defs.MOD_SPEED_UP),
    }

    -- Test aggregation
    local aggregate = WandModifiers.aggregate(modifierCards)

    if not aggregate then
        success = false
        table.insert(errors, "Failed to create modifier aggregate")
    else
        print("✓ Created modifier aggregate")

        -- Check expected properties
        if aggregate.damageBonus and aggregate.damageBonus > 0 then
            print("✓ Damage bonus applied: +" .. aggregate.damageBonus)
        else
            success = false
            table.insert(errors, "Damage bonus not applied correctly")
        end

        if aggregate.speedBonus and aggregate.speedBonus > 0 then
            print("✓ Speed bonus applied: +" .. aggregate.speedBonus)
        else
            success = false
            table.insert(errors, "Speed bonus not applied correctly")
        end
    end

    -- Test empty aggregation
    local emptyAggregate = WandModifiers.createAggregate()
    if not emptyAggregate then
        success = false
        table.insert(errors, "Failed to create empty aggregate")
    else
        print("✓ Created empty aggregate")
    end

    if success then
        print("\n✅ TEST 2 PASSED: Modifier aggregation working")
    else
        print("\n❌ TEST 2 FAILED:")
        for _, err in ipairs(errors) do
            print("  - " .. err)
        end
    end

    return success
end

--[[
================================================================================
TEST 3: Wand Executor Initialization
================================================================================
]] --

function WandSystemTest.test3_WandExecutorInit()
    print("\n" .. string.rep("=", 60))
    print("TEST 3: Wand Executor Initialization")
    print(string.rep("=", 60))

    local success = true
    local errors = {}

    -- Initialize executor
    WandExecutor.init()
    print("✓ WandExecutor initialized")

    -- Create simple wand
    local wandDef = {
        id = "test_wand_init",
        type = "trigger",
        mana_max = 50,
        mana_recharge_rate = 10,
        cast_block_size = 1,
        cast_delay = 100,
        recharge_time = 500,
        spread_angle = 5,
        shuffle = false,
        total_card_slots = 1,
        always_cast_cards = {},
    }

    local cardPool = {
        cardEval.create_card_from_template(cardEval.card_defs.ACTION_BASIC_PROJECTILE),
    }

    local triggerDef = {
        id = "every_N_seconds",
        type = "trigger",
        interval = 1.0,
    }

    -- Load wand
    local wandId = WandExecutor.loadWand(wandDef, cardPool, triggerDef)

    if not wandId then
        success = false
        table.insert(errors, "Failed to load wand")
    else
        print("✓ Loaded wand: " .. wandId)

        -- Check wand state
        local state = WandExecutor.getWandState(wandId)
        if not state then
            success = false
            table.insert(errors, "Failed to get wand state")
        else
            print("✓ Retrieved wand state")
            print("  - Current mana: " .. state.currentMana .. "/" .. state.maxMana)
            print("  - Mana regen: " .. state.manaRegenRate .. "/s")
        end

        -- Unload wand
        WandExecutor.unloadWand(wandId)
        print("✓ Unloaded wand")
    end

    -- Cleanup
    WandExecutor.cleanup()
    print("✓ WandExecutor cleaned up")

    if success then
        print("\n✅ TEST 3 PASSED: Wand executor working")
    else
        print("\n❌ TEST 3 FAILED:")
        for _, err in ipairs(errors) do
            print("  - " .. err)
        end
    end

    return success
end

--[[
================================================================================
TEST 4: Card Evaluation Order
================================================================================
]] --

function WandSystemTest.test4_CardEvaluation()
    print("\n" .. string.rep("=", 60))
    print("TEST 4: Card Evaluation Order")
    print(string.rep("=", 60))

    local success = true
    local errors = {}

    -- Create test wand
    local wandDef = cardEval.wand_defs[1] -- TEST_WAND_1

    -- Create card pool with modifiers and actions
    local cardPool = {
        cardEval.create_card_from_template(cardEval.card_defs.MOD_DAMAGE_UP),
        cardEval.create_card_from_template(cardEval.card_defs.ACTION_BASIC_PROJECTILE),
        cardEval.create_card_from_template(cardEval.card_defs.MULTI_DOUBLE_CAST),
        cardEval.create_card_from_template(cardEval.card_defs.ACTION_FAST_ACCURATE_PROJECTILE),
    }

    -- Simulate wand
    local result = cardEval.simulate_wand(wandDef, cardPool)

    if not result then
        success = false
        table.insert(errors, "Failed to simulate wand")
    else
        print("✓ Simulated wand: " .. result.wand_id)

        if not result.blocks or #result.blocks == 0 then
            success = false
            table.insert(errors, "No cast blocks generated")
        else
            print("✓ Generated " .. #result.blocks .. " cast block(s)")

            for i, block in ipairs(result.blocks) do
                print("  Block " .. i .. ": " .. #block.cards .. " card(s)")
                if block.applied_modifiers and #block.applied_modifiers > 0 then
                    print("    - Applied " .. #block.applied_modifiers .. " modifier(s)")
                end
            end
        end

        -- Check weight/overload calculation
        if result.total_weight then
            print("✓ Total weight calculated: " .. result.total_weight)
        end

        if result.overload_ratio then
            print("✓ Overload ratio: " .. string.format("%.2f", result.overload_ratio))
        end
    end

    if success then
        print("\n✅ TEST 4 PASSED: Card evaluation working")
    else
        print("\n❌ TEST 4 FAILED:")
        for _, err in ipairs(errors) do
            print("  - " .. err)
        end
    end

    return success
end

--[[
================================================================================
TEST 5: Trigger System
================================================================================
]] --

function WandSystemTest.test5_TriggerSystem()
    print("\n" .. string.rep("=", 60))
    print("TEST 5: Trigger System")
    print(string.rep("=", 60))

    local success = true
    local errors = {}

    -- Initialize trigger system
    WandTriggers.init()
    print("✓ WandTriggers initialized")

    -- Test trigger registration
    local triggerDef = {
        id = "every_N_seconds",
        type = "trigger",
        interval = 1.0,
    }

    local executorCalled = false
    local testExecutor = function(wandId, triggerType)
        executorCalled = true
        print("✓ Trigger executor called for wand: " .. wandId)
    end

    WandTriggers.register("test_wand_trigger", triggerDef, testExecutor)
    print("✓ Registered trigger")

    -- Check registration
    local registration = WandTriggers.getRegistration("test_wand_trigger")
    if not registration then
        success = false
        table.insert(errors, "Failed to retrieve trigger registration")
    else
        print("✓ Retrieved trigger registration")
    end

    -- Unregister
    WandTriggers.unregister("test_wand_trigger")
    print("✓ Unregistered trigger")

    -- Cleanup
    WandTriggers.cleanup()
    print("✓ WandTriggers cleaned up")

    if success then
        print("\n✅ TEST 5 PASSED: Trigger system working")
    else
        print("\n❌ TEST 5 FAILED:")
        for _, err in ipairs(errors) do
            print("  - " .. err)
        end
    end

    return success
end

--[[
================================================================================
TEST 6: Full Integration Test
================================================================================
]] --

function WandSystemTest.test6_FullIntegration()
    print("\n" .. string.rep("=", 60))
    print("TEST 6: Full Integration Test")
    print(string.rep("=", 60))

    local success = true
    local errors = {}

    -- Initialize all systems
    WandExecutor.init()

    -- Create a complex wand with modifiers and actions
    local wandDef = {
        id = "integration_test_wand",
        type = "trigger",
        mana_max = 100,
        mana_recharge_rate = 10,
        cast_block_size = 3,
        cast_delay = 100,
        recharge_time = 1000,
        spread_angle = 10,
        shuffle = false,
        total_card_slots = 5,
        always_cast_cards = {},
    }

    local cardPool = {
        cardEval.create_card_from_template(cardEval.card_defs.MULTI_DOUBLE_CAST),
        cardEval.create_card_from_template(cardEval.card_defs.MOD_DAMAGE_UP),
        cardEval.create_card_from_template(cardEval.card_defs.ACTION_BASIC_PROJECTILE),
        cardEval.create_card_from_template(cardEval.card_defs.MOD_SPEED_UP),
        cardEval.create_card_from_template(cardEval.card_defs.ACTION_FAST_ACCURATE_PROJECTILE),
    }

    local triggerDef = {
        id = "every_N_seconds",
        type = "trigger",
        interval = 2.0,
    }

    -- Load wand
    local wandId = WandExecutor.loadWand(wandDef, cardPool, triggerDef)

    if not wandId then
        success = false
        table.insert(errors, "Failed to load integration test wand")
    else
        print("✓ Loaded integration test wand: " .. wandId)

        -- Check if wand can cast
        local canCast = WandExecutor.canCast(wandId)
        print("✓ Can cast: " .. tostring(canCast))

        -- Get wand state
        local state = WandExecutor.getWandState(wandId)
        if state then
            print("✓ Wand state:")
            print("  - Mana: " .. state.currentMana .. "/" .. state.maxMana)
            print("  - Cooldown: " .. state.cooldownRemaining .. "s")
            print("  - Recharging: " .. tostring(state.isRecharging))
        end

        -- Unload wand
        WandExecutor.unloadWand(wandId)
        print("✓ Unloaded wand")
    end

    -- Cleanup
    WandExecutor.cleanup()

    if success then
        print("\n✅ TEST 6 PASSED: Full integration working")
    else
        print("\n❌ TEST 6 FAILED:")
        for _, err in ipairs(errors) do
            print("  - " .. err)
        end
    end

    return success
end

--[[
================================================================================
TEST RUNNER
================================================================================
]] --

function WandSystemTest.runAll()
    print("\n" .. string.rep("=", 80))
    print("WAND SYSTEM INTEGRATION TEST SUITE")
    print(string.rep("=", 80))

    local results = {
        WandSystemTest.test1_CardTemplates(),
        WandSystemTest.test2_ModifierAggregation(),
        WandSystemTest.test3_WandExecutorInit(),
        WandSystemTest.test4_CardEvaluation(),
        WandSystemTest.test5_TriggerSystem(),
        WandSystemTest.test6_FullIntegration(),
    }

    local passed = 0
    local failed = 0

    for _, result in ipairs(results) do
        if result then
            passed = passed + 1
        else
            failed = failed + 1
        end
    end

    print("\n" .. string.rep("=", 80))
    print("TEST RESULTS")
    print(string.rep("=", 80))
    print(string.format("Passed: %d/%d", passed, #results))
    print(string.format("Failed: %d/%d", failed, #results))

    if failed == 0 then
        print("\n✅ ALL TESTS PASSED - Wand system is ready for card implementation!")
    else
        print("\n❌ SOME TESTS FAILED - Please fix issues before implementing cards")
    end

    print(string.rep("=", 80))

    return failed == 0
end

return WandSystemTest
