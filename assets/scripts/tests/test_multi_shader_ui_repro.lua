--[[
================================================================================
MULTI-SHADER UI REPRODUCTION TEST
================================================================================

BUG REPRODUCTION:
-----------------
Having 2+ shader-enabled UI elements (e.g., cards with 3d_skew) causes elements 
to flip upside-down due to shared global state corruption in ShaderPipelineComponent.

ROOT CAUSE IDENTIFIED:
Global variables in shader_pipeline.hpp:112-124 (ping/pong/baseCache/postPassCache)
are shared across all ShaderPipelineComponent instances. When multiple UI elements
render with shaders, these caches become corrupted, leading to incorrect vertex
transformations and visual flipping.

REPRODUCTION PROCEDURE:
1. Spawn 3 UI elements (cards with distinct IDs for identification)
2. Add ShaderPipelineComponent to each with 3d_skew shader
3. Verify each element's shader is added successfully
4. Expected: 3 visually distinct cards with 3d skew effect
5. Actual: Cards appear flipped upside-down or with visual distortion

LOGGING:
Each element logs its creation and shader status to help identify timing
of the corruption and which element(s) are affected.

To run in-game:
    dofile("assets/scripts/tests/test_multi_shader_ui_repro.lua")
    MultiShaderUIRepro.run()
    -- Then open inventory or panel to see the 3 cards rendered

To clean up:
    MultiShaderUIRepro.cleanup()
]]

local ShaderBuilder = require("core.shader_builder")
local component_cache = require("core.component_cache")

local MultiShaderUIRepro = {}

-- Test entities created
MultiShaderUIRepro.test_entities = {}
MultiShaderUIRepro.shader_components = {}

-- Helper: Create a UI element (simulating card-like entity)
local function create_ui_card(label, x, y, seed)
    local entity = animation_system.createAnimatedObjectWithTransform(
        "card-new-test-action.png",  -- From player_inventory.lua example
        true,
        x or 0,
        y or 0,
        nil,
        true
    )
    
    if not entity or not registry:valid(entity) then
        print("[MultiShaderUIRepro] ERROR: Failed to create card entity for: " .. label)
        return nil
    end
    
    -- Get transform component
    local transform = component_cache.get(entity, Transform)
    if transform then
        transform.actualX = x or 0
        transform.actualY = y or 0
        transform.actualW = 64
        transform.actualH = 64
        transform.visualX = x or 0
        transform.visualY = y or 0
        transform.visualW = 64
        transform.visualH = 64
    end
    
    -- Add state tag for visibility (PLANNING_STATE or "default_state")
    if add_state_tag then
        add_state_tag(entity, "default_state")
    end
    
    -- Setup shader pipeline with 3d_skew (matching player_inventory.lua:338-352)
    if _G.shader_pipeline and _G.shader_pipeline.ShaderPipelineComponent then
        local shaderPipelineComp = registry:emplace(entity, _G.shader_pipeline.ShaderPipelineComponent)
        shaderPipelineComp:addPass("3d_skew")
        
        -- Store reference to shader component for debugging
        MultiShaderUIRepro.shader_components[entity] = shaderPipelineComp
        
        -- Set custom uniform (skew seed varies per card)
        local skewSeed = (seed or math.random()) * 10000
        local passes = shaderPipelineComp.passes
        if passes and #passes >= 1 then
            local pass = passes[#passes]
            if pass and pass.shaderName and pass.shaderName:sub(1, 7) == "3d_skew" then
                pass.customPrePassFunction = function()
                    if globalShaderUniforms then
                        globalShaderUniforms:set(pass.shaderName, "rand_seed", skewSeed)
                    end
                end
            end
        end
        
        print(string.format(
            "[MultiShaderUIRepro] %s: ShaderPipelineComponent added with 3d_skew (seed=%.2f)",
            label, skewSeed
        ))
    else
        print("[MultiShaderUIRepro] WARNING: shader_pipeline not available")
    end
    
    table.insert(MultiShaderUIRepro.test_entities, entity)
    print("[MultiShaderUIRepro] Created card: " .. label .. " at (" .. (x or 0) .. ", " .. (y or 0) .. ")")
    
    return entity
end

-- Main reproduction test
function MultiShaderUIRepro.run()
    print("")
    print("================================================================================")
    print("MULTI-SHADER UI REPRODUCTION TEST - Starting")
    print("================================================================================")
    print("")
    
    local screen_w = globals and globals.screenWidth and globals.screenWidth() or 1280
    local screen_h = globals and globals.screenHeight and globals.screenHeight() or 720
    
    -- Calculate positions for 3 cards in a row
    local card_spacing = 200
    local base_x = (screen_w - (card_spacing * 2)) / 2  -- Center the 3 cards
    local base_y = screen_h / 2
    
    print("[MultiShaderUIRepro] Screen: " .. screen_w .. "x" .. screen_h)
    print("[MultiShaderUIRepro] Spawning 3 UI cards with 3d_skew shader...")
    print("")
    
    -- Card 1: Left position
    print("[Card 1] Creating left card...")
    local card1 = create_ui_card(
        "Card_1_LEFT",
        base_x,
        base_y,
        0.123
    )
    
    -- Small delay to separate shader pipeline state
    if timer and timer.after then
        timer.after(0.01, function() end)
    end
    
    -- Card 2: Center position
    print("[Card 2] Creating center card...")
    local card2 = create_ui_card(
        "Card_2_CENTER",
        base_x + card_spacing,
        base_y,
        0.456
    )
    
    -- Small delay
    if timer and timer.after then
        timer.after(0.01, function() end)
    end
    
    -- Card 3: Right position
    print("[Card 3] Creating right card...")
    local card3 = create_ui_card(
        "Card_3_RIGHT",
        base_x + card_spacing * 2,
        base_y,
        0.789
    )
    
    print("")
    print("================================================================================")
    print("BUG REPRODUCTION CHECKLIST")
    print("================================================================================")
    print("")
    print("EXPECTED BEHAVIOR:")
    print("  ✓ 3 distinct card entities spawn")
    print("  ✓ Each card has ShaderPipelineComponent with 3d_skew pass")
    print("  ✓ Cards render with 3D skew effect (perspective tilt)")
    print("  ✓ Cards display at correct positions with correct orientation (upright)")
    print("")
    print("ACTUAL BUG BEHAVIOR (WHAT WE'RE TESTING FOR):")
    print("  ✗ Cards appear flipped upside-down")
    print("  ✗ Visual corruption/glitching when 2+ cards active")
    print("  ✗ Shader effects appear inverted or offset")
    print("")
    
    -- Log shader component state
    print("SHADER PIPELINE STATE:")
    for entity, shaderComp in pairs(MultiShaderUIRepro.shader_components) do
        if registry:valid(entity) then
            local hasShaderPipeline = registry:has(entity, _G.shader_pipeline.ShaderPipelineComponent)
            local passCount = shaderComp.passes and #shaderComp.passes or 0
            print(string.format(
                "  Entity %d: HasShaderPipeline=%s, PassCount=%d",
                entity, tostring(hasShaderPipeline), passCount
            ))
            
            if shaderComp.passes then
                for i, pass in ipairs(shaderComp.passes) do
                    print(string.format(
                        "    Pass[%d]: name=%s, enabled=%s",
                        i, pass.shaderName, tostring(pass.enabled)
                    ))
                end
            end
        end
    end
    
    print("")
    print("================================================================================")
    print("MULTI-SHADER UI REPRODUCTION TEST - Complete")
    print("================================================================================")
    print(string.format("Created %d UI cards with shaders", #MultiShaderUIRepro.test_entities))
    print("If cards appear FLIPPED UPSIDE-DOWN or DISTORTED → BUG REPRODUCED")
    print("If cards appear CORRECT (upright with 3D skew) → BUG NOT VISIBLE")
    print("")
    print("NEXT STEPS:")
    print("  1. Open inventory (press 'I') to see cards in UI context")
    print("  2. Document visual appearance (flipped vs correct)")
    print("  3. Call MultiShaderUIRepro.cleanup() to remove test entities")
    print("")
    
    return #MultiShaderUIRepro.test_entities > 0
end

-- Cleanup function
function MultiShaderUIRepro.cleanup()
    print("[MultiShaderUIRepro] Cleaning up " .. #MultiShaderUIRepro.test_entities .. " test entities...")
    
    for _, entity in ipairs(MultiShaderUIRepro.test_entities) do
        if registry and registry:valid(entity) then
            registry:destroy(entity)
        end
    end
    
    MultiShaderUIRepro.test_entities = {}
    MultiShaderUIRepro.shader_components = {}
    print("[MultiShaderUIRepro] Cleanup complete")
end

-- Auto-run if loaded directly
if ... == nil then
    MultiShaderUIRepro.run()
end

-- Export for manual use
_G.MultiShaderUIRepro = MultiShaderUIRepro

return MultiShaderUIRepro
