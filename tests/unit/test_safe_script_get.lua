--[[
    Tests for safe_script_get function
]]

local test_safe_script = {}

function test_safe_script.test_returns_nil_for_nil_entity()
    -- Ensure the function exists in globals
    assert(_G.safe_script_get, "safe_script_get should be defined globally")
    local result = safe_script_get(nil)
    assert(result == nil, "Should return nil for nil entity")
    print("✓ safe_script_get returns nil for nil entity")
    return true
end

function test_safe_script.test_returns_nil_for_invalid_entity()
    local invalid_entity = 999999999
    local result = safe_script_get(invalid_entity)
    assert(result == nil, "Should return nil for invalid entity")
    print("✓ safe_script_get returns nil for invalid entity")
    return true
end

function test_safe_script.test_script_field_returns_default_for_nil()
    assert(_G.script_field, "script_field should be defined globally")
    local result = script_field(nil, "health", 100)
    assert(result == 100, "Should return default value for nil entity")
    print("✓ script_field returns default for nil entity")
    return true
end

function test_safe_script.test_script_field_returns_default_for_missing_field()
    local invalid_entity = 999999999
    local result = script_field(invalid_entity, "nonexistent_field", 42)
    assert(result == 42, "Should return default value for missing field")
    print("✓ script_field returns default for missing field")
    return true
end

function test_safe_script.run_all()
    print("\n=== Safe Script Get Tests ===\n")
    local tests = {
        test_safe_script.test_returns_nil_for_nil_entity,
        test_safe_script.test_returns_nil_for_invalid_entity,
        test_safe_script.test_script_field_returns_default_for_nil,
        test_safe_script.test_script_field_returns_default_for_missing_field,
    }
    local passed, failed = 0, 0
    for _, test_func in ipairs(tests) do
        local success, err = pcall(test_func)
        if success then passed = passed + 1
        else failed = failed + 1; print("✗ " .. tostring(err)) end
    end
    print(string.format("\nPassed: %d, Failed: %d", passed, failed))
    return failed == 0
end

return test_safe_script
