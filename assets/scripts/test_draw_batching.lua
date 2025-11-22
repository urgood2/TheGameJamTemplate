--[[
    Quick Test Runner for Draw Command Batching
    
    Add this to your game initialization or call it from Lua console:
    
    local test = require("assets.scripts.test_draw_batching")
    test.runQuickTests()
]]

local TestDrawBatching = {}

-- Helper function for visual test results
local function printTestResult(testName, passed, message)
    local icon = passed and "✅" or "❌"
    local status = passed and "PASSED" or "FAILED"
    print(string.format("%s Test: %s - %s", icon, testName, status))
    if message then
        print(string.format("   %s", message))
    end
end

-- Test 1: Module Exists
function TestDrawBatching.testModuleExists()
    local passed = shader_draw_commands ~= nil
    local message = passed and "shader_draw_commands module found" or "Module not loaded!"
    printTestResult("Module Exists", passed, message)
    return passed
end

-- Test 2: Can Create Batch
function TestDrawBatching.testCreateBatch()
    local success, batch = pcall(function()
        return shader_draw_commands.DrawCommandBatch()
    end)
    
    local passed = success and batch ~= nil
    local message = passed and "DrawCommandBatch created successfully" or "Failed to create batch"
    printTestResult("Create Batch", passed, message)
    return passed, batch
end

-- Test 3: Recording State
function TestDrawBatching.testRecording(batch)
    local passed = true
    local messages = {}
    
    -- Test initial state
    if batch:recording() then
        passed = false
        table.insert(messages, "ERROR: Batch recording by default")
    end
    
    -- Test begin recording
    batch:beginRecording()
    if not batch:recording() then
        passed = false
        table.insert(messages, "ERROR: beginRecording() didn't set recording state")
    else
        table.insert(messages, "beginRecording() works")
    end
    
    -- Test end recording
    batch:endRecording()
    if batch:recording() then
        passed = false
        table.insert(messages, "ERROR: endRecording() didn't clear recording state")
    else
        table.insert(messages, "endRecording() works")
    end
    
    printTestResult("Recording State", passed, table.concat(messages, ", "))
    return passed
end

-- Test 4: Add and Execute Commands
function TestDrawBatching.testExecuteCommands()
    local batch = shader_draw_commands.DrawCommandBatch()
    local executionOrder = {}
    
    batch:beginRecording()
    
    -- Add multiple commands
    batch:addCustomCommand(function()
        table.insert(executionOrder, 1)
    end)
    
    batch:addCustomCommand(function()
        table.insert(executionOrder, 2)
    end)
    
    batch:addCustomCommand(function()
        table.insert(executionOrder, 3)
    end)
    
    batch:endRecording()
    
    local size = batch:size()
    if size ~= 3 then
        printTestResult("Execute Commands", false, string.format("Expected 3 commands, got %d", size))
        return false
    end
    
    -- Execute
    batch:execute()
    
    -- Verify execution order
    local passed = #executionOrder == 3 and 
                   executionOrder[1] == 1 and 
                   executionOrder[2] == 2 and 
                   executionOrder[3] == 3
    
    local message = passed and "Commands executed in correct order" or "Commands executed incorrectly"
    printTestResult("Execute Commands", passed, message)
    return passed
end

-- Test 5: Global Batch
function TestDrawBatching.testGlobalBatch()
    local globalBatch = shader_draw_commands.globalBatch
    
    if not globalBatch then
        printTestResult("Global Batch", false, "Global batch not available")
        return false
    end
    
    -- Test clear
    globalBatch:clear()
    if globalBatch:size() ~= 0 then
        printTestResult("Global Batch", false, "Clear didn't empty batch")
        return false
    end
    
    -- Test usage
    globalBatch:beginRecording()
    globalBatch:addCustomCommand(function() end)
    globalBatch:endRecording()
    
    if globalBatch:size() ~= 1 then
        printTestResult("Global Batch", false, "Failed to add command to global batch")
        return false
    end
    
    globalBatch:execute()
    globalBatch:clear()
    
    printTestResult("Global Batch", true, "Global batch is accessible and working")
    return true
end

-- Test 6: Optimization
function TestDrawBatching.testOptimization()
    local batch = shader_draw_commands.DrawCommandBatch()
    
    batch:beginRecording()
    
    -- Add commands that could be optimized
    batch:addCustomCommand(function() end)
    batch:addBeginShader("shader1")
    batch:addEndShader()
    batch:addBeginShader("shader2")
    batch:addEndShader()
    
    batch:endRecording()
    
    local sizeBeforeOptimize = batch:size()
    
    -- Optimize
    local success = pcall(function()
        batch:optimize()
    end)
    
    if not success then
        printTestResult("Optimization", false, "optimize() threw an error")
        return false
    end
    
    -- Execute optimized batch
    success = pcall(function()
        batch:execute()
    end)
    
    if not success then
        printTestResult("Optimization", false, "execute() after optimize() threw an error")
        return false
    end
    
    printTestResult("Optimization", true, string.format("Optimized from %d commands", sizeBeforeOptimize))
    return true
end

-- Test 7: Error Handling
function TestDrawBatching.testErrorHandling()
    local allPassed = true
    local messages = {}
    
    -- Test: Execute without endRecording
    local batch1 = shader_draw_commands.DrawCommandBatch()
    batch1:beginRecording()
    local success = pcall(function()
        batch1:execute()
    end)
    if success then
        table.insert(messages, "Handles execute without endRecording")
    else
        allPassed = false
        table.insert(messages, "ERROR: Crashes on execute without endRecording")
    end
    
    -- Test: Double beginRecording
    local batch2 = shader_draw_commands.DrawCommandBatch()
    success = pcall(function()
        batch2:beginRecording()
        batch2:beginRecording()
        batch2:endRecording()
    end)
    if success then
        table.insert(messages, "Handles double beginRecording")
    else
        allPassed = false
        table.insert(messages, "ERROR: Crashes on double beginRecording")
    end
    
    -- Test: Execute empty batch
    local batch3 = shader_draw_commands.DrawCommandBatch()
    success = pcall(function()
        batch3:execute()
    end)
    if success then
        table.insert(messages, "Handles empty batch execution")
    else
        allPassed = false
        table.insert(messages, "ERROR: Crashes on empty batch")
    end
    
    printTestResult("Error Handling", allPassed, table.concat(messages, ", "))
    return allPassed
end

-- Run Quick Tests (no entities required)
function TestDrawBatching.runQuickTests()
    print("\n" .. string.rep("=", 70))
    print("🧪 Draw Command Batching - Quick Test Suite")
    print(string.rep("=", 70) .. "\n")
    
    local results = {}
    
    -- Test 1: Module exists
    local moduleExists = TestDrawBatching.testModuleExists()
    table.insert(results, moduleExists)
    
    if not moduleExists then
        print("\n❌ CRITICAL: Module not loaded. Cannot continue testing.")
        print("   Make sure shader_draw_commands is properly compiled and registered.")
        return false
    end
    
    -- Test 2: Create batch
    local canCreate, batch = TestDrawBatching.testCreateBatch()
    table.insert(results, canCreate)
    
    if not canCreate then
        print("\n❌ CRITICAL: Cannot create batch. Check C++ bindings.")
        return false
    end
    
    -- Test 3: Recording
    table.insert(results, TestDrawBatching.testRecording(batch))
    
    -- Test 4: Execute commands
    table.insert(results, TestDrawBatching.testExecuteCommands())
    
    -- Test 5: Global batch
    table.insert(results, TestDrawBatching.testGlobalBatch())
    
    -- Test 6: Optimization
    table.insert(results, TestDrawBatching.testOptimization())
    
    -- Test 7: Error handling
    table.insert(results, TestDrawBatching.testErrorHandling())
    
    -- Summary
    print("\n" .. string.rep("=", 70))
    local passed = 0
    for _, result in ipairs(results) do
        if result then passed = passed + 1 end
    end
    
    local allPassed = passed == #results
    local icon = allPassed and "✅" or "❌"
    local status = allPassed and "ALL TESTS PASSED" or "SOME TESTS FAILED"
    
    print(string.format("%s %s: %d/%d tests passed", icon, status, passed, #results))
    print(string.rep("=", 70) .. "\n")
    
    if allPassed then
        print("🎉 Draw command batching is working correctly!")
        print("   You can now use it to optimize rendering in your game.")
        print("   See DRAW_COMMAND_BATCH_TESTING_GUIDE.md for usage examples.")
    else
        print("⚠️  Some tests failed. Please check:")
        print("   1. Is shader_draw_commands.cpp compiled?")
        print("   2. Is RegisterDrawCommandBatchTypes() called during init?")
        print("   3. Check console for specific error messages.")
    end
    
    return allPassed
end

-- Run Full Tests (requires entities and registry)
function TestDrawBatching.runFullTests(registry, layer, entities)
    print("\n" .. string.rep("=", 70))
    print("🧪 Draw Command Batching - Full Test Suite")
    print(string.rep("=", 70) .. "\n")
    
    -- Run quick tests first
    local quickTestsPassed = TestDrawBatching.runQuickTests()
    
    if not quickTestsPassed then
        print("\n❌ Quick tests failed. Fix those first before running full tests.")
        return false
    end
    
    print("\n--- Advanced Tests (with entities) ---\n")
    
    -- Load integration test module
    local success, IntegrationTest = pcall(require, "assets.scripts.examples.integration_test")
    
    if not success then
        print("⚠️  Could not load integration_test.lua")
        print("   Advanced tests skipped.")
        return quickTestsPassed
    end
    
    -- Pick a test entity
    local testEntity = entities and entities[1] or nil
    
    -- Run integration tests
    local integrationPassed = IntegrationTest.runAll(layer, registry, testEntity)
    
    return quickTestsPassed and integrationPassed
end

return TestDrawBatching
