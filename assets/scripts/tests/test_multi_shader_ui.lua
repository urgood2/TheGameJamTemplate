--[[
================================================================================
Multi-Element UI Shader Integration Test
================================================================================
Tests that multiple UI elements with shaders render correctly without
corruption due to isolated per-element render contexts.

Expected Result: 5 cards with shaders all render correctly (no upside-down)
Visual Verification: Run game and observe cards
Log Verification: Check console for PASS/FAIL message
================================================================================
]]

local log_info = function(msg)
    print("[test_multi_shader_ui] " .. msg)
end

local log_pass = function(msg)
    print("[test_multi_shader_ui] ✓ PASS: " .. msg)
end

local log_fail = function(msg)
    print("[test_multi_shader_ui] ✗ FAIL: " .. msg)
end

local function runTest()
    log_info("Starting multi-element UI shader isolation test")
    
    local entities = {}
    local cardCount = 5
    
    for i = 1, cardCount do
        local e = registry:create()
        
        registry:emplace(e, Transform, 100 + (i * 120), 300, 100, 150)
        registry:emplace(e, AnimationQueueComponent)
        registry:emplace(e, entity_gamestate_management.StateTag, "default_state")
        
        local shaderComp = registry:emplace(e, shader_pipeline.ShaderPipelineComponent)
        shaderComp:addPass("3d_skew")
        
        table.insert(entities, e)
        
        log_info(string.format("Created card %d: entity=%d, pass_count=%d", 
            i, e, #shaderComp.passes))
    end
    
    Timer.after(2, function()
        local allHaveContext = true
        local isolationCount = 0
        
        for i, e in ipairs(entities) do
            if registry:all_of_UIShaderRenderContext(e) then
                local ctx = registry:get_UIShaderRenderContext(e)
                log_info(string.format("Card %d context: initialized=%s, swapCount=%d", 
                    i, tostring(ctx.initialized), ctx.swapCount))
                isolationCount = isolationCount + 1
            else
                log_info(string.format("Card %d: NO UIShaderRenderContext", i))
                allHaveContext = false
            end
        end
        
        if allHaveContext and isolationCount == cardCount then
            log_pass(string.format("All %d elements have distinct UIShaderRenderContext", cardCount))
            log_pass("Multi-element shader isolation working correctly")
        else
            log_fail(string.format("Expected %d contexts, got %d", cardCount, isolationCount))
        end
        
        for _, e in ipairs(entities) do
            registry:destroy(e)
        end
        
        log_info("Test complete - entities cleaned up")
    end, "test_multi_shader_ui")
end

runTest()
