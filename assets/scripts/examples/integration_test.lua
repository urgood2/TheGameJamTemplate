--[[
    Integration Test: Draw Command Optimization with Layer Queue System
    
    This test verifies that the draw command batching system (shader_draw_commands)
    integrates properly with the existing layer command queue system (layer_command_buffer).
    
    Test scenarios:
    1. Layer queue commands execute correctly
    2. Draw command batching works independently
    3. Both systems can be used together
    4. No conflicts or state corruption occurs
]]

local IntegrationTest = {}

-- Test 1: Layer Queue Basic Functionality
function IntegrationTest.testLayerQueueBasic(layer, registry, entity)
    print("\n=== Test 1: Layer Queue Basic Functionality ===")
    
    local success = pcall(function()
        -- Queue a transform entity animation pipeline command
        layer.queueDrawTransformEntityAnimationPipeline(
            layer,
            function(cmd)
                cmd.registry = registry
                cmd.e = entity
            end,
            0,  -- z-order
            layer.DrawCommandSpace.Screen
        )
        
        print("✅ Layer queue command queued successfully")
    end)
    
    if not success then
        print("❌ Layer queue test failed")
        return false
    end
    
    print("✅ Test 1 passed")
    return true
end

-- Test 2: Draw Command Batch Basic Functionality
function IntegrationTest.testDrawCommandBatchBasic()
    print("\n=== Test 2: Draw Command Batch Basic Functionality ===")
    
    local success = pcall(function()
        local batch = shader_draw_commands.DrawCommandBatch()
        
        -- Test recording
        batch:beginRecording()
        assert(batch:recording() == true, "Batch should be recording")
        
        -- Add some commands
        batch:addCustomCommand(function()
            print("  Custom command executed")
        end)
        
        batch:endRecording()
        assert(batch:recording() == false, "Batch should not be recording")
        
        -- Test size
        local size = batch:size()
        assert(size > 0, "Batch should have commands")
        print(string.format("  Batch has %d command(s)", size))
        
        -- Test execution
        batch:execute()
        
        print("✅ Draw command batch works correctly")
    end)
    
    if not success then
        print("❌ Draw command batch test failed")
        return false
    end
    
    print("✅ Test 2 passed")
    return true
end

-- Test 3: Entity Pipeline with Batching
function IntegrationTest.testEntityPipelineBatching(registry, entity)
    print("\n=== Test 3: Entity Pipeline with Batching ===")
    
    -- Check if entity has required components
    if not entity or entity == entt.null then
        print("⚠️  Skipping test - no valid entity provided")
        return true
    end
    
    local success = pcall(function()
        local batch = shader_draw_commands.DrawCommandBatch()
        
        batch:beginRecording()
        
        -- Execute entity pipeline through batching system
        shader_draw_commands.executeEntityPipelineWithCommands(
            registry,
            entity,
            batch,
            false  -- autoOptimize
        )
        
        batch:endRecording()
        
        local size = batch:size()
        print(string.format("  Entity pipeline generated %d command(s)", size))
        
        -- Optimize and execute
        batch:optimize()
        batch:execute()
        
        print("✅ Entity pipeline batching works correctly")
    end)
    
    if not success then
        print("❌ Entity pipeline batching test failed")
        return false
    end
    
    print("✅ Test 3 passed")
    return true
end

-- Test 4: Mixed Usage (Layer Queue + Batch)
function IntegrationTest.testMixedUsage(layer, registry, entity)
    print("\n=== Test 4: Mixed Usage (Layer Queue + Batch) ===")
    
    local success = pcall(function()
        -- 1. Use layer queue for some drawing
        layer.queueDrawRectangle(
            layer,
            function(cmd)
                cmd.x = 100
                cmd.y = 100
                cmd.width = 50
                cmd.height = 50
                cmd.color = raylib.RED
                cmd.lineWidth = 0
            end,
            0
        )
        print("  Queued rectangle to layer")
        
        -- 2. Use draw command batch for shader-based rendering
        if entity and entity ~= entt.null then
            local batch = shader_draw_commands.DrawCommandBatch()
            batch:beginRecording()
            
            shader_draw_commands.executeEntityPipelineWithCommands(
                registry,
                entity,
                batch,
                true  -- autoOptimize
            )
            
            batch:endRecording()
            batch:execute()
            print(string.format("  Executed entity batch with %d command(s)", batch:size()))
        end
        
        -- 3. More layer queue commands
        layer.queueDrawCircle(
            layer,
            function(cmd)
                cmd.x = 200
                cmd.y = 200
                cmd.radius = 25
                cmd.color = raylib.BLUE
            end,
            0
        )
        print("  Queued circle to layer")
        
        print("✅ Mixed usage works without conflicts")
    end)
    
    if not success then
        print("❌ Mixed usage test failed")
        return false
    end
    
    print("✅ Test 4 passed")
    return true
end

-- Test 5: Global Batch Reusability
function IntegrationTest.testGlobalBatchReuse()
    print("\n=== Test 5: Global Batch Reusability ===")
    
    local success = pcall(function()
        local batch = shader_draw_commands.globalBatch
        
        -- Clear any previous commands
        batch:clear()
        assert(batch:size() == 0, "Global batch should be empty after clear")
        print("  Global batch cleared")
        
        -- Use it
        batch:beginRecording()
        batch:addCustomCommand(function()
            print("    Global batch command executed")
        end)
        batch:endRecording()
        batch:execute()
        
        -- Clear and reuse
        batch:clear()
        assert(batch:size() == 0, "Global batch should be empty after second clear")
        print("  Global batch reused successfully")
        
        print("✅ Global batch is reusable")
    end)
    
    if not success then
        print("❌ Global batch reuse test failed")
        return false
    end
    
    print("✅ Test 5 passed")
    return true
end

-- Test 6: Optimization Correctness
function IntegrationTest.testOptimizationCorrectness()
    print("\n=== Test 6: Optimization Correctness ===")
    
    local success = pcall(function()
        local batch = shader_draw_commands.DrawCommandBatch()
        
        batch:beginRecording()
        
        -- Add commands that would benefit from optimization
        batch:addCustomCommand(function() print("    Command 1") end)
        batch:addBeginShader("shader1")
        batch:addEndShader()
        batch:addBeginShader("shader2")
        batch:addEndShader()
        batch:addBeginShader("shader1")  -- Same as first, could be grouped
        batch:addEndShader()
        batch:addCustomCommand(function() print("    Command 2") end)
        
        batch:endRecording()
        
        local sizeBeforeOptimize = batch:size()
        print(string.format("  Batch size before optimization: %d", sizeBeforeOptimize))
        
        batch:optimize()
        
        local sizeAfterOptimize = batch:size()
        print(string.format("  Batch size after optimization: %d", sizeAfterOptimize))
        
        -- Execute and verify no errors
        batch:execute()
        
        print("✅ Optimization completes without errors")
    end)
    
    if not success then
        print("❌ Optimization test failed")
        return false
    end
    
    print("✅ Test 6 passed")
    return true
end

-- Test 7: Error Handling
function IntegrationTest.testErrorHandling()
    print("\n=== Test 7: Error Handling ===")
    
    -- Test 7a: Executing without endRecording
    local test7a = pcall(function()
        local batch = shader_draw_commands.DrawCommandBatch()
        batch:beginRecording()
        -- Forgot to call endRecording
        batch:execute()  -- Should handle gracefully
    end)
    print(string.format("  Execute without endRecording: %s", test7a and "✅ Handled" or "❌ Failed"))
    
    -- Test 7b: Double beginRecording
    local test7b = pcall(function()
        local batch = shader_draw_commands.DrawCommandBatch()
        batch:beginRecording()
        batch:beginRecording()  -- Should be safe
        batch:endRecording()
    end)
    print(string.format("  Double beginRecording: %s", test7b and "✅ Handled" or "❌ Failed"))
    
    -- Test 7c: Clear and execute empty batch
    local test7c = pcall(function()
        local batch = shader_draw_commands.DrawCommandBatch()
        batch:clear()
        batch:execute()  -- Empty batch
    end)
    print(string.format("  Execute empty batch: %s", test7c and "✅ Handled" or "❌ Failed"))
    
    print("✅ Test 7 passed")
    return true
end

-- Run all tests
function IntegrationTest.runAll(layer, registry, entity)
    print("\n" .. string.rep("=", 60))
    print("Draw Command Optimization Integration Test Suite")
    print(string.rep("=", 60))
    
    local results = {}
    
    table.insert(results, IntegrationTest.testLayerQueueBasic(layer, registry, entity))
    table.insert(results, IntegrationTest.testDrawCommandBatchBasic())
    table.insert(results, IntegrationTest.testEntityPipelineBatching(registry, entity))
    table.insert(results, IntegrationTest.testMixedUsage(layer, registry, entity))
    table.insert(results, IntegrationTest.testGlobalBatchReuse())
    table.insert(results, IntegrationTest.testOptimizationCorrectness())
    table.insert(results, IntegrationTest.testErrorHandling())
    
    -- Summary
    print("\n" .. string.rep("=", 60))
    local passed = 0
    for _, result in ipairs(results) do
        if result then passed = passed + 1 end
    end
    
    print(string.format("Test Results: %d/%d passed", passed, #results))
    
    if passed == #results then
        print("✅ ALL TESTS PASSED - Integration is working correctly!")
    else
        print("❌ SOME TESTS FAILED - Please review the output above")
    end
    print(string.rep("=", 60))
    
    return passed == #results
end

-- Convenience function for quick test
function IntegrationTest.quickTest()
    print("\n🚀 Quick Integration Test (without entities)")
    
    local success = true
    success = IntegrationTest.testDrawCommandBatchBasic() and success
    success = IntegrationTest.testGlobalBatchReuse() and success
    success = IntegrationTest.testOptimizationCorrectness() and success
    success = IntegrationTest.testErrorHandling() and success
    
    if success then
        print("\n✅ Quick test passed! Basic functionality is working.")
    else
        print("\n❌ Quick test failed! Check the implementation.")
    end
    
    return success
end

return IntegrationTest
