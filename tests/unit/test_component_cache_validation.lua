--[[
    Tests for component_cache entity validation
]]

local test_validation = {}

function test_validation.test_get_returns_nil_for_nil_entity()
    local component_cache = require("core.component_cache")
    local result = component_cache.get(nil, _G.Transform)
    assert(result == nil, "Should return nil for nil entity")
    print("✓ get returns nil for nil entity")
    return true
end

function test_validation.test_get_returns_nil_for_invalid_entity()
    local component_cache = require("core.component_cache")
    -- Use a clearly invalid entity ID (very large number that was never created)
    local invalid_entity = 999999999
    local result = component_cache.get(invalid_entity, _G.Transform)
    assert(result == nil, "Should return nil for invalid entity")
    print("✓ get returns nil for invalid entity")
    return true
end

function test_validation.test_ensure_entity_returns_false_for_nil()
    local component_cache = require("core.component_cache")
    local result = component_cache.ensure(nil)
    assert(result == false, "ensure should return false for nil")
    print("✓ ensure returns false for nil")
    return true
end

function test_validation.test_ensure_entity_returns_false_for_invalid()
    local component_cache = require("core.component_cache")
    local invalid_entity = 999999999
    local result = component_cache.ensure(invalid_entity)
    assert(result == false, "ensure should return false for invalid entity")
    print("✓ ensure returns false for invalid entity")
    return true
end

function test_validation.test_safe_get_returns_nil_and_false_for_invalid()
    local component_cache = require("core.component_cache")
    local comp, valid = component_cache.safe_get(999999999, _G.Transform)
    assert(comp == nil, "Should return nil component for invalid entity")
    assert(valid == false, "Should return false validity flag")
    print("✓ safe_get returns nil,false for invalid entity")
    return true
end

function test_validation.run_all()
    print("\n=== Component Cache Validation Tests ===\n")
    local tests = {
        test_validation.test_get_returns_nil_for_nil_entity,
        test_validation.test_get_returns_nil_for_invalid_entity,
        test_validation.test_ensure_entity_returns_false_for_nil,
        test_validation.test_ensure_entity_returns_false_for_invalid,
        test_validation.test_safe_get_returns_nil_and_false_for_invalid,
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

return test_validation
