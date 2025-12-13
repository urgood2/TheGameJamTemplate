--[[
================================================================================
SHADER ERGONOMICS INTEGRATION TESTS
================================================================================
Tests for shader_builder.lua and draw.lua modules.

These tests verify:
1. ShaderBuilder family detection and registry API
2. ShaderBuilder fluent API method chaining
3. Draw module defaults and presets
4. Draw module local_command options merging

Run with:
    lua assets/scripts/tests/shader_ergonomics_test.lua
    or load in-game for full integration testing

Note: Some tests mock dependencies since they don't exist in standalone Lua.
]]

--------------------------------------------------------------------------------
-- TEST FRAMEWORK
--------------------------------------------------------------------------------

local test_count = 0
local pass_count = 0
local fail_count = 0
local test_output = {}

local function log_test(msg)
    table.insert(test_output, msg)
end

local function assert_eq(actual, expected, msg)
    test_count = test_count + 1
    if actual ~= expected then
        fail_count = fail_count + 1
        local error_msg = string.format("FAIL: %s - expected '%s', got '%s'",
            msg, tostring(expected), tostring(actual))
        log_test(error_msg)
        print(error_msg)
    else
        pass_count = pass_count + 1
        local pass_msg = "PASS: " .. msg
        log_test(pass_msg)
        print(pass_msg)
    end
end

local function assert_not_nil(value, msg)
    test_count = test_count + 1
    if value == nil then
        fail_count = fail_count + 1
        local error_msg = "FAIL: " .. msg .. " - expected non-nil, got nil"
        log_test(error_msg)
        print(error_msg)
    else
        pass_count = pass_count + 1
        local pass_msg = "PASS: " .. msg
        log_test(pass_msg)
        print(pass_msg)
    end
end

local function assert_nil(value, msg)
    test_count = test_count + 1
    if value ~= nil then
        fail_count = fail_count + 1
        local error_msg = string.format("FAIL: %s - expected nil, got '%s'",
            msg, tostring(value))
        log_test(error_msg)
        print(error_msg)
    else
        pass_count = pass_count + 1
        local pass_msg = "PASS: " .. msg
        log_test(pass_msg)
        print(pass_msg)
    end
end

local function assert_table_has_key(tbl, key, msg)
    test_count = test_count + 1
    if tbl[key] == nil then
        fail_count = fail_count + 1
        local error_msg = string.format("FAIL: %s - table missing key '%s'",
            msg, tostring(key))
        log_test(error_msg)
        print(error_msg)
    else
        pass_count = pass_count + 1
        local pass_msg = "PASS: " .. msg
        log_test(pass_msg)
        print(pass_msg)
    end
end

local function assert_table_equal(actual, expected, msg)
    test_count = test_count + 1
    local match = true
    for k, v in pairs(expected) do
        if actual[k] ~= v then
            match = false
            break
        end
    end
    if not match then
        fail_count = fail_count + 1
        local error_msg = string.format("FAIL: %s - tables do not match", msg)
        log_test(error_msg)
        print(error_msg)
    else
        pass_count = pass_count + 1
        local pass_msg = "PASS: " .. msg
        log_test(pass_msg)
        print(pass_msg)
    end
end

--------------------------------------------------------------------------------
-- MOCK DEPENDENCIES (for standalone testing)
--------------------------------------------------------------------------------

-- Mock entity_cache module
local mock_entity_cache = {
    valid = function(entity)
        -- Mock entity is valid if it's a table with _id field
        return entity and type(entity) == "table" and entity._id ~= nil
    end
}

-- Mock registry and shader components (minimal implementation for testing)
local mock_registry = {
    entities = {},

    has = function(self, entity, component)
        local eid = entity._id
        if not self.entities[eid] then return false end
        return self.entities[eid][component] ~= nil
    end,

    get = function(self, entity, component)
        local eid = entity._id
        if not self.entities[eid] then return nil end
        return self.entities[eid][component]
    end,

    emplace = function(self, entity, component)
        local eid = entity._id
        if not self.entities[eid] then
            self.entities[eid] = {}
        end
        -- Create mock component
        local comp = {
            passes = {},
            addPass = function(self, shaderName)
                table.insert(self.passes, shaderName)
            end,
            clearAll = function(self)
                self.passes = {}
            end
        }
        self.entities[eid][component] = comp
        return comp
    end
}

local mock_shader_pipeline = {
    ShaderPipelineComponent = "ShaderPipelineComponent"
}

local mock_globalShaderUniforms = {
    uniforms = {},
    set = function(self, shaderName, uniformName, value)
        local key = shaderName .. "." .. uniformName
        self.uniforms[key] = value
    end
}

local mock_layer = {
    DrawCommandSpace = {
        Screen = "Screen",
        World = "World"
    }
}

-- Mock shader_draw_commands (needs to be set before loading draw module)
local mock_shader_draw_commands = {
    add_local_command = function(registry, entity, cmdType, callback, z, space, textPass, uvPassthrough, stickerPass)
        -- Default implementation - will be overridden in tests
    end
}

-- Mock command_buffer (for draw module queue wrappers)
local mock_command_buffer = {
    queueTextPro = function(layerObj, callback, z, space) end,
    queueDrawRectangle = function(layerObj, callback, z, space) end,
    queueTexturePro = function(layerObj, callback, z, space) end,
    queueDrawCircleFilled = function(layerObj, callback, z, space) end,
    queueDrawLine = function(layerObj, callback, z, space) end,
    queueDrawRectanglePro = function(layerObj, callback, z, space) end,
    queueDrawRectangleLinesPro = function(layerObj, callback, z, space) end,
}

-- Setup global mocks
_G.registry = mock_registry
_G.shader_pipeline = mock_shader_pipeline
_G.globalShaderUniforms = mock_globalShaderUniforms
_G.layer = mock_layer
_G.shader_draw_commands = mock_shader_draw_commands
_G.command_buffer = mock_command_buffer
_G.WHITE = { r = 255, g = 255, b = 255, a = 255 }

-- Mock require for entity_cache
package.preload["core.entity_cache"] = function()
    return mock_entity_cache
end

--------------------------------------------------------------------------------
-- LOAD MODULES UNDER TEST
--------------------------------------------------------------------------------

-- Adjust package path to find modules
package.path = package.path .. ";./assets/scripts/core/?.lua"

local ShaderBuilder = require("shader_builder")
local draw = require("draw")

--------------------------------------------------------------------------------
-- TEST SUITE 1: SHADER BUILDER - FAMILY DETECTION
--------------------------------------------------------------------------------

print("\n=== SHADER BUILDER: FAMILY DETECTION ===")

-- Test 1: Detect family for known shader
local family = ShaderBuilder.get_shader_family("3d_skew_holo")
assert_eq(family, "3d_skew", "detect_family returns correct prefix for '3d_skew_holo'")

-- Test 2: Detect family for another known shader variant
family = ShaderBuilder.get_shader_family("3d_skew_prismatic")
assert_eq(family, "3d_skew", "detect_family returns correct prefix for '3d_skew_prismatic'")

-- Test 3: Detect family for liquid shader
family = ShaderBuilder.get_shader_family("liquid_wave")
assert_eq(family, "liquid", "detect_family returns correct prefix for 'liquid_wave'")

-- Test 4: Unknown shader returns nil
family = ShaderBuilder.get_shader_family("unknown_shader_xyz")
assert_nil(family, "detect_family returns nil for unknown shader")

-- Test 5: Partial match should not detect family
family = ShaderBuilder.get_shader_family("3d")
assert_nil(family, "detect_family returns nil for partial prefix '3d'")

--------------------------------------------------------------------------------
-- TEST SUITE 2: SHADER BUILDER - FAMILY REGISTRY
--------------------------------------------------------------------------------

print("\n=== SHADER BUILDER: FAMILY REGISTRY ===")

-- Test 6: get_families returns all families
local families = ShaderBuilder.get_families()
assert_not_nil(families, "get_families returns non-nil")
assert_not_nil(families["3d_skew"], "get_families includes '3d_skew' family")
assert_not_nil(families["liquid"], "get_families includes 'liquid' family")

-- Test 7: get_families returns a copy (not original)
families["3d_skew"] = nil
local families2 = ShaderBuilder.get_families()
assert_not_nil(families2["3d_skew"], "get_families returns copy (original not modified)")

-- Test 8: register_family adds new family
ShaderBuilder.register_family("energy", {
    uniforms = { "glow_strength", "pulse_rate" },
    defaults = { glow_strength = 1.0 }
})
family = ShaderBuilder.get_shader_family("energy_beam")
assert_eq(family, "energy", "register_family successfully adds new family")

-- Test 9: Verify registered family config
families = ShaderBuilder.get_families()
assert_not_nil(families["energy"], "Registered family appears in get_families")
assert_eq(families["energy"].defaults.glow_strength, 1.0, "Registered family has correct defaults")

--------------------------------------------------------------------------------
-- TEST SUITE 3: SHADER BUILDER - FLUENT API
--------------------------------------------------------------------------------

print("\n=== SHADER BUILDER: FLUENT API ===")

-- Create mock entity
local test_entity = { _id = 123 }

-- Test 10: Builder creation
local builder = ShaderBuilder.for_entity(test_entity)
assert_not_nil(builder, "for_entity creates builder instance")
assert_not_nil(builder.add, "Builder has add method")
assert_not_nil(builder.withUniform, "Builder has withUniform method")
assert_not_nil(builder.apply, "Builder has apply method")
assert_not_nil(builder.clear, "Builder has clear method")

-- Test 11: Builder add method chaining
builder = ShaderBuilder.for_entity(test_entity)
local result = builder:add("3d_skew_holo")
assert_eq(result, builder, "add method returns self for chaining")

-- Test 12: Builder withUniform method chaining
result = builder:withUniform("3d_skew_holo", "sheen_strength", 1.5)
assert_eq(result, builder, "withUniform method returns self for chaining")

-- Test 13: Builder clear method chaining
result = builder:clear()
assert_eq(result, builder, "clear method returns self for chaining")

-- Test 14: Builder apply method returns entity
result = builder:add("3d_skew_holo"):apply()
assert_eq(result, test_entity, "apply method returns entity")

-- Test 15: Builder adds passes to component
mock_registry.entities[123] = nil -- Reset entity
builder = ShaderBuilder.for_entity(test_entity)
builder:add("3d_skew_holo"):add("dissolve"):apply()
local comp = mock_registry:get(test_entity, "ShaderPipelineComponent")
assert_not_nil(comp, "apply creates ShaderPipelineComponent")
assert_eq(#comp.passes, 2, "apply adds correct number of passes")
assert_eq(comp.passes[1], "3d_skew_holo", "First pass is '3d_skew_holo'")
assert_eq(comp.passes[2], "dissolve", "Second pass is 'dissolve'")

-- Test 16: Builder with custom uniforms
mock_registry.entities[124] = nil
local test_entity2 = { _id = 124 }
builder = ShaderBuilder.for_entity(test_entity2)
builder:add("3d_skew_holo", { sheen_strength = 2.0, sheen_speed = 3.0 }):apply()
assert_eq(mock_globalShaderUniforms.uniforms["3d_skew_holo.sheen_strength"], 2.0,
    "Custom uniform sheen_strength set correctly")
assert_eq(mock_globalShaderUniforms.uniforms["3d_skew_holo.sheen_speed"], 3.0,
    "Custom uniform sheen_speed set correctly")

-- Test 17: Builder clear removes passes
mock_registry.entities[125] = nil
local test_entity3 = { _id = 125 }
builder = ShaderBuilder.for_entity(test_entity3)
builder:add("3d_skew_holo"):apply()
comp = mock_registry:get(test_entity3, "ShaderPipelineComponent")
local passes_before_clear = #comp.passes
builder:clear()
comp = mock_registry:get(test_entity3, "ShaderPipelineComponent")
assert_eq(#comp.passes, 0, "clear removes all passes")

-- Test 18: Builder validates entity
local invalid_entity = { no_id = true }
local success, err = pcall(function()
    ShaderBuilder.for_entity(invalid_entity)
end)
assert_eq(success, false, "for_entity throws error for invalid entity")

--------------------------------------------------------------------------------
-- TEST SUITE 4: DRAW MODULE - DEFAULTS
--------------------------------------------------------------------------------

print("\n=== DRAW MODULE: DEFAULTS ===")

-- Test 19: DEFAULTS table has camelCase keys
local defaults = draw.get_defaults("textPro")
assert_not_nil(defaults, "get_defaults returns defaults for 'textPro'")
assert_eq(defaults.fontSize, 16, "textPro defaults has fontSize = 16")
assert_eq(defaults.spacing, 1, "textPro defaults has spacing = 1")
assert_not_nil(defaults.origin, "textPro defaults has origin table")
assert_eq(defaults.origin.x, 0, "textPro origin.x = 0")
assert_eq(defaults.origin.y, 0, "textPro origin.y = 0")

-- Test 20: DEFAULTS table has snake_case keys
defaults = draw.get_defaults("text_pro")
assert_not_nil(defaults, "get_defaults returns defaults for 'text_pro' (snake_case)")
assert_eq(defaults.fontSize, 16, "text_pro defaults has fontSize = 16")

-- Test 21: Rectangle defaults
defaults = draw.get_defaults("rectangle")
assert_not_nil(defaults, "get_defaults returns defaults for 'rectangle'")
assert_table_has_key(defaults, "color", "rectangle defaults has 'color' key")

-- Test 22: get_defaults returns nil for unknown type
defaults = draw.get_defaults("unknown_command_type")
assert_nil(defaults, "get_defaults returns nil for unknown command type")

-- Test 23: get_defaults returns copy (not original)
defaults = draw.get_defaults("textPro")
defaults.fontSize = 999
local defaults2 = draw.get_defaults("textPro")
assert_eq(defaults2.fontSize, 16, "get_defaults returns copy (original not modified)")

--------------------------------------------------------------------------------
-- TEST SUITE 5: DRAW MODULE - PRESETS
--------------------------------------------------------------------------------

print("\n=== DRAW MODULE: PRESETS ===")

-- Test 24: get_presets returns all presets
local presets = draw.get_presets()
assert_not_nil(presets, "get_presets returns non-nil")
assert_not_nil(presets["shaded_text"], "get_presets includes 'shaded_text'")
assert_not_nil(presets["sticker"], "get_presets includes 'sticker'")
assert_not_nil(presets["world"], "get_presets includes 'world'")
assert_not_nil(presets["screen"], "get_presets includes 'screen'")

-- Test 25: shaded_text preset config
assert_eq(presets["shaded_text"].textPass, true, "shaded_text has textPass = true")
assert_eq(presets["shaded_text"].uvPassthrough, true, "shaded_text has uvPassthrough = true")

-- Test 26: world preset config
assert_eq(presets["world"].space, "World", "world preset has space = World")

-- Test 27: register_preset adds new preset
draw.register_preset("my_custom", {
    textPass = true,
    stickerPass = false,
    space = "Screen"
})
presets = draw.get_presets()
assert_not_nil(presets["my_custom"], "register_preset adds new preset")
assert_eq(presets["my_custom"].textPass, true, "Custom preset has correct textPass")
assert_eq(presets["my_custom"].space, "Screen", "Custom preset has correct space")

--------------------------------------------------------------------------------
-- TEST SUITE 6: DRAW MODULE - LOCAL COMMAND (MOCKED)
--------------------------------------------------------------------------------

print("\n=== DRAW MODULE: LOCAL COMMAND ===")

-- Update mock shader_draw_commands to capture calls
local last_add_local_command_call = nil
mock_shader_draw_commands.add_local_command = function(registry, entity, cmdType, callback, z, space, textPass, uvPassthrough, stickerPass)
    -- Capture the call arguments
    local cmd_props = {}
    callback(cmd_props) -- Execute callback to get props
    last_add_local_command_call = {
        entity = entity,
        cmdType = cmdType,
        props = cmd_props,
        z = z,
        space = space,
        textPass = textPass,
        uvPassthrough = uvPassthrough,
        stickerPass = stickerPass
    }
end

-- Test 28: local_command with minimal options
last_add_local_command_call = nil
local test_entity4 = { _id = 200 }
draw.local_command(test_entity4, "text_pro", {
    text = "hello",
    x = 10,
    y = 20
})
assert_not_nil(last_add_local_command_call, "local_command calls add_local_command")
assert_eq(last_add_local_command_call.cmdType, "text_pro", "Command type is 'text_pro'")
assert_eq(last_add_local_command_call.props.text, "hello", "Props.text = 'hello'")
assert_eq(last_add_local_command_call.props.fontSize, 16, "Props.fontSize = 16 (from defaults)")
assert_eq(last_add_local_command_call.z, 0, "z defaults to 0")
assert_eq(last_add_local_command_call.space, "Screen", "space defaults to Screen")

-- Test 29: local_command with preset
last_add_local_command_call = nil
draw.local_command(test_entity4, "text_pro", {
    text = "world",
    x = 100,
    y = 200
}, { preset = "shaded_text" })
assert_eq(last_add_local_command_call.textPass, true, "shaded_text preset sets textPass = true")
assert_eq(last_add_local_command_call.uvPassthrough, true, "shaded_text preset sets uvPassthrough = true")

-- Test 30: local_command options override preset
last_add_local_command_call = nil
draw.local_command(test_entity4, "text_pro", {
    text = "override",
}, { preset = "shaded_text", textPass = false })
assert_eq(last_add_local_command_call.textPass, false, "Explicit option overrides preset")
assert_eq(last_add_local_command_call.uvPassthrough, true, "Preset value used when not overridden")

-- Test 31: local_command merges props with defaults
last_add_local_command_call = nil
draw.local_command(test_entity4, "text_pro", {
    text = "merge",
    fontSize = 24, -- Override default
})
assert_eq(last_add_local_command_call.props.fontSize, 24, "Custom fontSize overrides default")
assert_eq(last_add_local_command_call.props.spacing, 1, "Default spacing preserved")
assert_not_nil(last_add_local_command_call.props.origin, "Default origin table preserved")

-- Test 32: local_command with custom z and space
last_add_local_command_call = nil
draw.local_command(test_entity4, "text_pro", {
    text = "custom"
}, { z = 5, space = mock_layer.DrawCommandSpace.World })
assert_eq(last_add_local_command_call.z, 5, "Custom z value used")
assert_eq(last_add_local_command_call.space, "World", "Custom space value used")

-- Test 33: local_command throws error for invalid entity
local invalid_entity_ok, invalid_entity_err = pcall(function()
    draw.local_command(nil, "text_pro", { text = "fail" })
end)
assert_eq(invalid_entity_ok, false, "local_command throws error for nil entity")

local invalid_entity_ok2, invalid_entity_err2 = pcall(function()
    draw.local_command({ no_id = true }, "text_pro", { text = "fail" })
end)
assert_eq(invalid_entity_ok2, false, "local_command throws error for entity without _id")

-- Test 34: local_command throws error for invalid command type
local invalid_cmd_ok, invalid_cmd_err = pcall(function()
    draw.local_command(test_entity4, "invalid_command", { text = "fail" })
end)
assert_eq(invalid_cmd_ok, false, "local_command throws error for invalid command type")

--------------------------------------------------------------------------------
-- TEST SUMMARY
--------------------------------------------------------------------------------

print("\n=== TEST SUMMARY ===")
print(string.format("Total tests: %d", test_count))
print(string.format("Passed: %d", pass_count))
print(string.format("Failed: %d", fail_count))

if fail_count == 0 then
    print("\n✓ ALL TESTS PASSED")
else
    print(string.format("\n✗ %d TEST(S) FAILED", fail_count))
end

-- Write output to file
local output_file = io.open("shader_ergonomics_test_output.txt", "w")
if output_file then
    output_file:write("=== SHADER ERGONOMICS TEST OUTPUT ===\n\n")
    for _, line in ipairs(test_output) do
        output_file:write(line .. "\n")
    end
    output_file:write("\n=== SUMMARY ===\n")
    output_file:write(string.format("Total: %d | Passed: %d | Failed: %d\n", test_count, pass_count, fail_count))
    output_file:close()
    print("\nTest output written to shader_ergonomics_test_output.txt")
end

-- Exit with appropriate code
os.exit(fail_count == 0 and 0 or 1)
