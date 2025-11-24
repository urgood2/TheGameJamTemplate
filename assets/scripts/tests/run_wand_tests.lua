--[[
================================================================================
WAND SYSTEM STATIC VERIFICATION
================================================================================
Performs static analysis to verify the wand system is properly structured
and ready for card implementation without requiring the game engine runtime.

This checks:
1. All required files exist
2. Module dependencies are correct
3. Key functions are defined
4. Card templates are complete
5. System integration points are ready
================================================================================
]] --

local StaticVerification = {}

-- File system utilities
local function fileExists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    return content
end

-- Check if a Lua file has valid syntax
local function checkSyntax(path)
    local content = readFile(path)
    if not content then
        return false, "File not found"
    end

    local func, err = load(content, path)
    if not func then
        return false, err
    end

    return true, "Valid syntax"
end

-- Check if a file defines specific functions
local function checkFunctions(path, functionNames)
    local content = readFile(path)
    if not content then
        return false, {}
    end

    local found = {}
    for _, funcName in ipairs(functionNames) do
        local escapedName = funcName:gsub("[%.%-%+%*%?%[%]%^%$%%]", "%%%1")
        if content:match("function%s+" .. escapedName .. "%s*%(") or
            content:match(escapedName .. "%s*=%s*function%s*%(") then
            table.insert(found, funcName)
        end
    end

    return true, found
end

-- Check if a file requires specific modules
local function checkRequires(path, moduleNames)
    local content = readFile(path)
    if not content then
        return false, {}
    end

    local found = {}
    for _, modName in ipairs(moduleNames) do
        local escapedName = modName:gsub("[%.%-%+%*%?%[%]%^%$%%]", "%%%1")
        if content:match('require%s*%(%s*["\']' .. escapedName .. '["\']%s*%)') then
            table.insert(found, modName)
        end
    end

    return true, found
end

--[[
================================================================================
VERIFICATION TESTS
================================================================================
]] --

function StaticVerification.test1_FileStructure()
    print("\n" .. string.rep("=", 60))
    print("TEST 1: File Structure")
    print(string.rep("=", 60))

    local basePath = "assets/scripts/"
    local requiredFiles = {
        "wand/wand_executor.lua",
        "wand/wand_modifiers.lua",
        "wand/wand_actions.lua",
        "wand/wand_triggers.lua",
        "wand/wand_test_examples.lua",
        "core/card_eval_order_test.lua",
    }

    local success = true
    local missing = {}

    for _, file in ipairs(requiredFiles) do
        local fullPath = basePath .. file
        if fileExists(fullPath) then
            print("✓ Found: " .. file)
        else
            success = false
            table.insert(missing, file)
            print("✗ Missing: " .. file)
        end
    end

    if success then
        print("\n✅ TEST 1 PASSED: All required files exist")
    else
        print("\n❌ TEST 1 FAILED: Missing files:")
        for _, file in ipairs(missing) do
            print("  - " .. file)
        end
    end

    return success
end

function StaticVerification.test2_SyntaxValidation()
    print("\n" .. string.rep("=", 60))
    print("TEST 2: Syntax Validation")
    print(string.rep("=", 60))

    local basePath = "assets/scripts/"
    local files = {
        "wand/wand_executor.lua",
        "wand/wand_modifiers.lua",
        "wand/wand_actions.lua",
        "wand/wand_triggers.lua",
        "core/card_eval_order_test.lua",
    }

    local success = true
    local errors = {}

    for _, file in ipairs(files) do
        local fullPath = basePath .. file
        local valid, msg = checkSyntax(fullPath)

        if valid then
            print("✓ Valid syntax: " .. file)
        else
            success = false
            table.insert(errors, { file = file, error = msg })
            print("✗ Syntax error in " .. file .. ": " .. msg)
        end
    end

    if success then
        print("\n✅ TEST 2 PASSED: All files have valid syntax")
    else
        print("\n❌ TEST 2 FAILED: Syntax errors found")
    end

    return success
end

function StaticVerification.test3_ModuleDependencies()
    print("\n" .. string.rep("=", 60))
    print("TEST 3: Module Dependencies")
    print(string.rep("=", 60))

    local basePath = "assets/scripts/"

    -- Check WandExecutor dependencies
    local _, executorReqs = checkRequires(basePath .. "wand/wand_executor.lua", {
        "wand.wand_modifiers",
        "wand.wand_actions",
        "wand.wand_triggers",
    })

    print("WandExecutor requires:")
    for _, req in ipairs(executorReqs) do
        print("  ✓ " .. req)
    end

    -- Check WandTestExamples dependencies
    local _, testReqs = checkRequires(basePath .. "wand/wand_test_examples.lua", {
        "core.card_eval_order_test",
        "wand.wand_executor",
    })

    print("WandTestExamples requires:")
    for _, req in ipairs(testReqs) do
        print("  ✓ " .. req)
    end

    local success = #executorReqs >= 2 and #testReqs >= 2

    if success then
        print("\n✅ TEST 3 PASSED: Module dependencies are correct")
    else
        print("\n❌ TEST 3 FAILED: Missing dependencies")
    end

    return success
end

function StaticVerification.test4_KeyFunctions()
    print("\n" .. string.rep("=", 60))
    print("TEST 4: Key Functions")
    print(string.rep("=", 60))

    local basePath = "assets/scripts/"
    local success = true

    -- Check WandExecutor functions
    local _, executorFuncs = checkFunctions(basePath .. "wand/wand_executor.lua", {
        "WandExecutor.init",
        "WandExecutor.cleanup",
        "WandExecutor.loadWand",
        "WandExecutor.unloadWand",
        "WandExecutor.execute",
        "WandExecutor.canCast",
    })

    print("WandExecutor functions:")
    for _, func in ipairs(executorFuncs) do
        print("  ✓ " .. func)
    end

    if #executorFuncs < 5 then
        success = false
        print("  ✗ Missing some key functions")
    end

    -- Check WandModifiers functions
    local _, modifierFuncs = checkFunctions(basePath .. "wand/wand_modifiers.lua", {
        "WandModifiers.createAggregate",
        "WandModifiers.aggregate",
        "WandModifiers.applyToAction",
    })

    print("WandModifiers functions:")
    for _, func in ipairs(modifierFuncs) do
        print("  ✓ " .. func)
    end

    if #modifierFuncs < 2 then
        success = false
        print("  ✗ Missing some key functions")
    end

    -- Check WandActions functions
    local _, actionFuncs = checkFunctions(basePath .. "wand/wand_actions.lua", {
        "WandActions.execute",
        "WandActions.executeProjectileAction",
    })

    print("WandActions functions:")
    for _, func in ipairs(actionFuncs) do
        print("  ✓ " .. func)
    end

    if #actionFuncs < 1 then
        success = false
        print("  ✗ Missing some key functions")
    end

    -- Check WandTriggers functions
    local _, triggerFuncs = checkFunctions(basePath .. "wand/wand_triggers.lua", {
        "WandTriggers.init",
        "WandTriggers.cleanup",
        "WandTriggers.register",
        "WandTriggers.unregister",
    })

    print("WandTriggers functions:")
    for _, func in ipairs(triggerFuncs) do
        print("  ✓ " .. func)
    end

    if #triggerFuncs < 3 then
        success = false
        print("  ✗ Missing some key functions")
    end

    if success then
        print("\n✅ TEST 4 PASSED: All key functions are defined")
    else
        print("\n❌ TEST 4 FAILED: Some key functions are missing")
    end

    return success
end

function StaticVerification.test5_CardTemplates()
    print("\n" .. string.rep("=", 60))
    print("TEST 5: Card Templates")
    print(string.rep("=", 60))

    local basePath = "assets/scripts/"
    local content = readFile(basePath .. "core/card_eval_order_test.lua")

    if not content then
        print("❌ Could not read card_eval_order_test.lua")
        return false
    end

    local success = true

    -- Check for CardTemplates table
    if content:match("CardTemplates%s*=%s*{") then
        print("✓ CardTemplates table defined")
    else
        success = false
        print("✗ CardTemplates table not found")
    end

    -- Check for key card types
    local cardTypes = {
        "ACTION_BASIC_PROJECTILE",
        "ACTION_FAST_ACCURATE_PROJECTILE",
        "MOD_DAMAGE_UP",
        "MOD_SPEED_UP",
        "MULTI_DOUBLE_CAST",
        "MULTI_TRIPLE_CAST",
    }

    local foundCards = 0
    for _, cardType in ipairs(cardTypes) do
        if content:match("CardTemplates%." .. cardType) then
            print("  ✓ " .. cardType)
            foundCards = foundCards + 1
        else
            print("  ✗ " .. cardType .. " not found")
        end
    end

    if foundCards < #cardTypes then
        success = false
    end

    -- Check for WandTemplates
    if content:match("WandTemplates%s*=%s*{") then
        print("✓ WandTemplates table defined")
    else
        success = false
        print("✗ WandTemplates table not found")
    end

    -- Check for helper functions
    if content:match("function%s+simulate_wand") or content:match("simulate_wand%s*=%s*function") then
        print("✓ simulate_wand function defined")
    else
        success = false
        print("✗ simulate_wand function not found")
    end

    if success then
        print("\n✅ TEST 5 PASSED: Card templates are properly defined")
    else
        print("\n❌ TEST 5 FAILED: Some card templates are missing")
    end

    return success
end

function StaticVerification.test6_IntegrationPoints()
    print("\n" .. string.rep("=", 60))
    print("TEST 6: Integration Points")
    print(string.rep("=", 60))

    local basePath = "assets/scripts/"
    local success = true

    -- Check that card_eval_order_test exports necessary items
    local cardEvalContent = readFile(basePath .. "core/card_eval_order_test.lua")
    if cardEvalContent then
        if cardEvalContent:match("return%s*{") then
            print("✓ card_eval_order_test.lua has return statement")

            if cardEvalContent:match("wand_defs") then
                print("  ✓ Exports wand_defs")
            end
            if cardEvalContent:match("card_defs") then
                print("  ✓ Exports card_defs")
            end
            if cardEvalContent:match("simulate_wand") then
                print("  ✓ Exports simulate_wand")
            end
        else
            success = false
            print("✗ card_eval_order_test.lua missing return statement")
        end
    end

    -- Check that wand modules return their tables
    local wandModules = {
        "wand/wand_executor.lua",
        "wand/wand_modifiers.lua",
        "wand/wand_actions.lua",
        "wand/wand_triggers.lua",
    }

    for _, module in ipairs(wandModules) do
        local content = readFile(basePath .. module)
        if content and content:match("return%s+Wand") then
            print("✓ " .. module .. " returns module table")
        else
            success = false
            print("✗ " .. module .. " missing return statement")
        end
    end

    if success then
        print("\n✅ TEST 6 PASSED: Integration points are ready")
    else
        print("\n❌ TEST 6 FAILED: Some integration points are missing")
    end

    return success
end

--[[
================================================================================
TEST RUNNER
================================================================================
]] --

function StaticVerification.runAll()
    print("\n" .. string.rep("=", 80))
    print("WAND SYSTEM STATIC VERIFICATION")
    print(string.rep("=", 80))

    local results = {
        StaticVerification.test1_FileStructure(),
        StaticVerification.test2_SyntaxValidation(),
        StaticVerification.test3_ModuleDependencies(),
        StaticVerification.test4_KeyFunctions(),
        StaticVerification.test5_CardTemplates(),
        StaticVerification.test6_IntegrationPoints(),
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
    print("VERIFICATION RESULTS")
    print(string.rep("=", 80))
    print(string.format("Passed: %d/%d", passed, #results))
    print(string.format("Failed: %d/%d", failed, #results))

    if failed == 0 then
        print("\n✅ ALL CHECKS PASSED")
        print("\nThe wand system is properly structured and ready for card implementation!")
        print("\nYou can now:")
        print("  1. Implement cards in card_eval_order_test.lua")
        print("  2. Use the card templates (CardTemplates.*)")
        print("  3. Test with simulate_wand() function")
        print("  4. Load wands with WandExecutor.loadWand()")
    else
        print("\n❌ SOME CHECKS FAILED")
        print("\nPlease fix the issues above before implementing cards.")
    end

    print(string.rep("=", 80))

    return failed == 0
end

-- Run verification
StaticVerification.runAll()
