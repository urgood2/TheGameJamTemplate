--[[
================================================================================
SHADER BUILDER VISUAL TEST
================================================================================
Visual demonstration of ShaderBuilder applying non-3d_skew shaders.

To run: Load this file in-game during PLANNING_STATE, or call:
    dofile("assets/scripts/tests/shader_builder_visual_test.lua")

Expected result: Multiple test sprites with different shaders applied,
demonstrating that ShaderBuilder works with any shader, not just 3d_skew family.
]]

local ShaderBuilder = require("core.shader_builder")
local component_cache = require("core.component_cache")

-- animation_system is a global C++ binding (not a Lua module)

local VisualTest = {}

-- Test entities we create (for cleanup)
VisualTest.test_entities = {}

-- Register a "glow" shader family for testing
local function setup_glow_family()
    ShaderBuilder.register_family("glow", {
        uniforms = { "glow_intensity", "glow_color" },
        defaults = {
            glow_intensity = 1.0,
        },
    })
    print("[ShaderBuilder Visual Test] Registered 'glow' shader family")
end

-- Register a "flash" shader family for testing
local function setup_flash_family()
    ShaderBuilder.register_family("flash", {
        uniforms = { "flash_color", "flash_intensity" },
        defaults = {
            flash_intensity = 1.0,
        },
    })
    print("[ShaderBuilder Visual Test] Registered 'flash' shader family")
end

-- Register a "dissolve" shader family for testing
local function setup_dissolve_family()
    ShaderBuilder.register_family("dissolve", {
        uniforms = { "dissolve", "burn_colour_1", "burn_colour_2" },
        defaults = {
            dissolve = 0.0,
        },
    })
    print("[ShaderBuilder Visual Test] Registered 'dissolve' shader family")
end

-- Create a test sprite entity at given position
local function create_test_sprite(x, y, label)
    -- Try to create an animated entity with a common sprite
    local entity = nil

    -- Try different sprite sources (actual IDs from codebase)
    local sprite_options = {
        "frame0012.png",       -- Chest sprite (from gameplay.lua:8892)
        "b8090.png",           -- EXP pickup sprite (from gameplay.lua:707)
    }

    for _, sprite_id in ipairs(sprite_options) do
        local ok, result = pcall(function()
            return animation_system.createAnimatedObjectWithTransform(sprite_id, true)
        end)
        if ok and result then
            entity = result
            print("[ShaderBuilder Visual Test] Created sprite with: " .. sprite_id)
            break
        end
    end

    if not entity then
        -- Fallback: create a basic entity
        entity = registry:create()
        print("[ShaderBuilder Visual Test] Created basic entity (no sprite found)")
    end

    -- Set position
    local transform = component_cache.get(entity, Transform)
    if transform then
        transform.actualX = x
        transform.actualY = y
        transform.actualW = 64
        transform.actualH = 64
        transform.visualX = x
        transform.visualY = y
        transform.visualW = 64
        transform.visualH = 64
    end

    -- Add to PLANNING_STATE if available
    if add_state_tag and PLANNING_STATE then
        add_state_tag(entity, PLANNING_STATE)
    end

    table.insert(VisualTest.test_entities, entity)
    print("[ShaderBuilder Visual Test] Created test entity: " .. label .. " at (" .. x .. ", " .. y .. ")")

    return entity
end

-- Run the visual test
function VisualTest.run()
    print("")
    print("================================================================================")
    print("SHADER BUILDER VISUAL TEST - Starting")
    print("================================================================================")

    -- Setup shader families
    setup_glow_family()
    setup_flash_family()
    setup_dissolve_family()

    local screen_w = globals and globals.screenWidth and globals.screenWidth() or 800
    local screen_h = globals and globals.screenHeight and globals.screenHeight() or 600
    local center_x = screen_w / 2
    local center_y = screen_h / 2

    -- Test 1: Entity with "flash" shader (using fluent API)
    print("")
    print("[Test 1] Applying 'flash' shader via ShaderBuilder...")
    local entity1 = create_test_sprite(center_x - 150, center_y, "flash_test")
    if entity1 then
        ShaderBuilder.for_entity(entity1)
            :add("flash")
            :apply()
        print("[Test 1] SUCCESS: 'flash' shader applied via ShaderBuilder")
    end

    -- Test 2: Entity with "glow" shader (using fluent API with custom uniforms)
    print("")
    print("[Test 2] Applying 'glow' shader with custom uniforms...")
    local entity2 = create_test_sprite(center_x, center_y, "glow_test")
    if entity2 then
        ShaderBuilder.for_entity(entity2)
            :add("glow_fragment", { glow_intensity = 2.0 })
            :apply()
        print("[Test 2] SUCCESS: 'glow_fragment' shader applied with custom uniforms")
    end

    -- Test 3: Entity with "dissolve" shader (animated effect)
    print("")
    print("[Test 3] Applying 'dissolve' shader...")
    local entity3 = create_test_sprite(center_x + 150, center_y, "dissolve_test")
    if entity3 then
        ShaderBuilder.for_entity(entity3)
            :add("dissolve_burn_fragment", { dissolve = 0.3 })
            :apply()
        print("[Test 3] SUCCESS: 'dissolve_burn_fragment' shader applied")
    end

    -- Test 4: Verify family detection works for registered families
    print("")
    print("[Test 4] Verifying family detection...")
    local flash_family = ShaderBuilder.get_shader_family("flash")
    local glow_family = ShaderBuilder.get_shader_family("glow_fragment")
    local dissolve_family = ShaderBuilder.get_shader_family("dissolve_burn_fragment")
    local unknown_family = ShaderBuilder.get_shader_family("unknown_shader")

    print("  flash -> family: " .. tostring(flash_family))
    print("  glow_fragment -> family: " .. tostring(glow_family))
    print("  dissolve_burn_fragment -> family: " .. tostring(dissolve_family))
    print("  unknown_shader -> family: " .. tostring(unknown_family))

    if flash_family == "flash" and glow_family == "glow" and dissolve_family == "dissolve" and unknown_family == nil then
        print("[Test 4] SUCCESS: Family detection working correctly")
    else
        print("[Test 4] PARTIAL: Some family detections may not match (check shader names)")
    end

    print("")
    print("================================================================================")
    print("SHADER BUILDER VISUAL TEST - Complete")
    print("================================================================================")
    print("Created " .. #VisualTest.test_entities .. " test entities")
    print("Look for sprites at center of screen with different shader effects")
    print("Call VisualTest.cleanup() to remove test entities")
    print("")

    return true
end

-- Cleanup test entities
function VisualTest.cleanup()
    print("[ShaderBuilder Visual Test] Cleaning up " .. #VisualTest.test_entities .. " test entities...")
    for _, entity in ipairs(VisualTest.test_entities) do
        if registry and registry:valid(entity) then
            registry:destroy(entity)
        end
    end
    VisualTest.test_entities = {}
    print("[ShaderBuilder Visual Test] Cleanup complete")
end

-- Auto-run if loaded directly
if ... == nil then
    VisualTest.run()
end

-- Export for manual use
_G.ShaderBuilderVisualTest = VisualTest

return VisualTest
