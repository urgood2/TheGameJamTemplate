--[[
================================================================================
ENTITY LIFECYCLE TESTS
================================================================================
Tests for entity creation, initialization order, validation, and destruction.

Run with: load_script("test/test_entity_lifecycle.lua")

Covers:
- Initialization order (attach_ecs timing)
- GameObject restrictions
- Entity validation (ensure_entity, ensure_scripted_entity)
- Safe access patterns (script_field, safe_script_get)
- Component cache behavior
- Destruction and cleanup

doc_ids covered: pattern:ecs.*
================================================================================
]]

local test_utils = {}

-- Test state
local _results = {
    passed = 0,
    failed = 0,
    tests = {}
}

--------------------------------------------------------------------------------
-- TEST UTILITIES
--------------------------------------------------------------------------------

local function log_test(msg)
    print("[ECS-TEST] " .. msg)
end

local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", msg or "assertion failed", tostring(expected), tostring(actual)))
    end
    return true
end

local function assert_true(value, msg)
    if not value then
        error(msg or "expected true, got false/nil")
    end
    return true
end

local function assert_false(value, msg)
    if value then
        error(msg or "expected false/nil, got true")
    end
    return true
end

local function assert_nil(value, msg)
    if value ~= nil then
        error(string.format("%s: expected nil, got %s", msg or "assertion failed", tostring(value)))
    end
    return true
end

local function run_test(test_id, test_fn, opts)
    opts = opts or {}
    log_test("")
    log_test("Testing: " .. test_id)

    local success, err = pcall(test_fn)

    if success then
        log_test("PASS: " .. test_id)
        _results.passed = _results.passed + 1
        _results.tests[test_id] = { status = "PASS", doc_ids = opts.doc_ids, tags = opts.tags }
    else
        log_test("FAIL: " .. test_id)
        log_test("  Error: " .. tostring(err))
        _results.failed = _results.failed + 1
        _results.tests[test_id] = { status = "FAIL", error = tostring(err), doc_ids = opts.doc_ids, tags = opts.tags }
    end
end

--------------------------------------------------------------------------------
-- DEPENDENCIES
--------------------------------------------------------------------------------

local Node = require("monobehavior.behavior_script_v2")
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")

-- Globals (may be nil in test environment)
local registry = _G.registry
local entt_null = _G.entt_null

-- Helper functions from util.lua (loaded globally)
local safe_script_get = _G.safe_script_get
local script_field = _G.script_field
local ensure_entity = _G.ensure_entity
local ensure_scripted_entity = _G.ensure_scripted_entity

--------------------------------------------------------------------------------
-- INITIALIZATION ORDER TESTS
--------------------------------------------------------------------------------

run_test("ecs.attach_ecs.assign_before_attach", function()
    log_test("  Creating EntityType")
    local entity = registry:create()
    local EntityType = Node:extend()
    local script = EntityType {}

    log_test("  Assigning data.value = 42 FIRST")
    script.data = { value = 42 }
    script.customField = "hello"

    log_test("  Calling attach_ecs SECOND")
    script:attach_ecs { create_new = false, existing_entity = entity }

    log_test("  Verifying: data preserved after attach")
    assert_eq(script.data.value, 42, "data.value preserved")
    assert_eq(script.customField, "hello", "customField preserved")

    -- Cleanup
    registry:destroy(entity)
end, {
    doc_ids = {"pattern:ecs.attach_ecs.assign_before_attach"},
    tags = {"ecs", "lifecycle", "critical"}
})

run_test("ecs.init.data_preserved", function()
    log_test("  Creating entity with complex nested data")
    local entity = registry:create()
    local EntityType = Node:extend()
    local script = EntityType {}

    -- Complex nested data structure
    script.data = {
        stats = { health = 100, mana = 50 },
        inventory = { "sword", "shield" },
        nested = { deep = { value = "test" } }
    }

    script:attach_ecs { create_new = false, existing_entity = entity }

    log_test("  Verifying nested data preserved")
    assert_eq(script.data.stats.health, 100, "nested stats.health")
    assert_eq(script.data.stats.mana, 50, "nested stats.mana")
    assert_eq(#script.data.inventory, 2, "inventory count")
    assert_eq(script.data.nested.deep.value, "test", "deeply nested value")

    registry:destroy(entity)
end, {
    doc_ids = {"pattern:ecs.init.data_preserved"},
    tags = {"ecs", "lifecycle"}
})

--------------------------------------------------------------------------------
-- GAMEOBJECT TESTS
--------------------------------------------------------------------------------

run_test("ecs.gameobject.script_table_usage", function()
    log_test("  Creating entity with script")
    local entity = registry:create()
    local EntityType = Node:extend()
    local script = EntityType {}
    script.data = { foo = "bar" }
    script:attach_ecs { create_new = false, existing_entity = entity }

    log_test("  Storing data in script.data table")
    script.data.new_field = "new_value"

    log_test("  Verifying: data accessible and persistent")
    assert_eq(script.data.new_field, "new_value", "new field accessible")
    assert_eq(script.data.foo, "bar", "original field preserved")

    registry:destroy(entity)
end, {
    doc_ids = {"pattern:ecs.gameobject.script_table_usage"},
    tags = {"ecs", "lifecycle"}
})

--------------------------------------------------------------------------------
-- VALIDATION TESTS
--------------------------------------------------------------------------------

run_test("ecs.validate.ensure_entity_valid", function()
    log_test("  Creating valid entity")
    local entity = registry:create()

    log_test("  Calling ensure_entity")
    local result = ensure_entity(entity)

    log_test("  Verifying: returns true for valid entity")
    assert_true(result, "ensure_entity returns true for valid entity")

    registry:destroy(entity)
end, {
    doc_ids = {"pattern:ecs.validate.ensure_entity_valid"},
    tags = {"ecs", "validation"}
})

run_test("ecs.validate.ensure_entity_invalid", function()
    log_test("  Creating and destroying entity")
    local entity = registry:create()
    registry:destroy(entity)

    log_test("  Calling ensure_entity on destroyed entity")
    local result = ensure_entity(entity)

    log_test("  Verifying: returns false for destroyed entity")
    assert_false(result, "ensure_entity returns false for destroyed entity")
end, {
    doc_ids = {"pattern:ecs.validate.ensure_entity_invalid"},
    tags = {"ecs", "validation"}
})

run_test("ecs.validate.ensure_entity_nil", function()
    log_test("  Calling ensure_entity with nil")
    local result = ensure_entity(nil)

    log_test("  Verifying: returns false for nil")
    assert_false(result, "ensure_entity returns false for nil")
end, {
    doc_ids = {"pattern:ecs.validate.ensure_entity_nil"},
    tags = {"ecs", "validation"}
})

run_test("ecs.validate.ensure_scripted_entity_valid", function()
    log_test("  Creating entity with script component")
    local entity = registry:create()
    local EntityType = Node:extend()
    local script = EntityType {}
    script:attach_ecs { create_new = false, existing_entity = entity }

    log_test("  Calling ensure_scripted_entity")
    local result = ensure_scripted_entity(entity)

    log_test("  Verifying: returns true for scripted entity")
    assert_true(result, "ensure_scripted_entity returns true")

    registry:destroy(entity)
end, {
    doc_ids = {"pattern:ecs.validate.ensure_scripted_entity_valid"},
    tags = {"ecs", "validation"}
})

run_test("ecs.validate.ensure_scripted_entity_invalid", function()
    log_test("  Creating entity WITHOUT script component")
    local entity = registry:create()
    -- No attach_ecs call - entity has no ScriptComponent

    log_test("  Calling ensure_scripted_entity")
    local result = ensure_scripted_entity(entity)

    log_test("  Verifying: returns false for non-scripted entity")
    assert_false(result, "ensure_scripted_entity returns false")

    registry:destroy(entity)
end, {
    doc_ids = {"pattern:ecs.validate.ensure_scripted_entity_invalid"},
    tags = {"ecs", "validation"}
})

--------------------------------------------------------------------------------
-- SAFE ACCESS TESTS
--------------------------------------------------------------------------------

run_test("ecs.access.script_field_default", function()
    log_test("  Creating entity without 'health' field")
    local entity = registry:create()
    local EntityType = Node:extend()
    local script = EntityType {}
    script.data = { mana = 50 }  -- No health field
    script:attach_ecs { create_new = false, existing_entity = entity }

    log_test("  Calling script_field with default")
    local health = script_field(entity, "health", 100)

    log_test("  Verifying: returns default value")
    assert_eq(health, 100, "script_field returns default for missing field")

    registry:destroy(entity)
end, {
    doc_ids = {"pattern:ecs.access.script_field_default"},
    tags = {"ecs", "access"}
})

run_test("ecs.access.script_field_existing", function()
    log_test("  Creating entity with 'health' field")
    local entity = registry:create()
    local EntityType = Node:extend()
    local script = EntityType {}
    script.health = 75
    script:attach_ecs { create_new = false, existing_entity = entity }

    log_test("  Calling script_field")
    local health = script_field(entity, "health", 100)

    log_test("  Verifying: returns actual value, not default")
    assert_eq(health, 75, "script_field returns actual value")

    registry:destroy(entity)
end, {
    doc_ids = {"pattern:ecs.access.script_field_existing"},
    tags = {"ecs", "access"}
})

run_test("ecs.access.safe_script_get_valid", function()
    log_test("  Creating valid scripted entity")
    local entity = registry:create()
    local EntityType = Node:extend()
    local script = EntityType {}
    script.marker = "test_marker"
    script:attach_ecs { create_new = false, existing_entity = entity }

    log_test("  Calling safe_script_get")
    local result = safe_script_get(entity)

    log_test("  Verifying: returns script table")
    assert_true(result ~= nil, "safe_script_get returns table")
    assert_eq(result.marker, "test_marker", "script table has expected data")

    registry:destroy(entity)
end, {
    doc_ids = {"pattern:ecs.access.safe_script_get_valid"},
    tags = {"ecs", "access"}
})

run_test("ecs.access.safe_script_get_invalid", function()
    log_test("  Creating and destroying entity")
    local entity = registry:create()
    registry:destroy(entity)

    log_test("  Calling safe_script_get on destroyed entity")
    local result = safe_script_get(entity)

    log_test("  Verifying: returns nil without error")
    assert_nil(result, "safe_script_get returns nil for destroyed entity")
end, {
    doc_ids = {"pattern:ecs.access.safe_script_get_invalid"},
    tags = {"ecs", "access"}
})

run_test("ecs.access.safe_script_get_nil", function()
    log_test("  Calling safe_script_get with nil entity")
    local result = safe_script_get(nil)

    log_test("  Verifying: returns nil without error")
    assert_nil(result, "safe_script_get returns nil for nil input")
end, {
    doc_ids = {"pattern:ecs.access.safe_script_get_nil"},
    tags = {"ecs", "access"}
})

--------------------------------------------------------------------------------
-- COMPONENT CACHE TESTS
--------------------------------------------------------------------------------

run_test("ecs.cache.get_valid", function()
    log_test("  Creating entity with Transform")
    local entity = registry:create()
    local transform = registry:emplace(entity, Transform)
    transform.actualX = 100
    transform.actualY = 200

    log_test("  Getting component via cache")
    local cached = component_cache.get(entity, Transform)

    log_test("  Verifying: returns component with correct values")
    assert_true(cached ~= nil, "component_cache returns component")
    assert_eq(cached.actualX, 100, "cached transform has correct X")
    assert_eq(cached.actualY, 200, "cached transform has correct Y")

    registry:destroy(entity)
end, {
    doc_ids = {"pattern:ecs.cache.get_valid"},
    tags = {"ecs", "cache"}
})

run_test("ecs.cache.get_after_destroy", function()
    log_test("  Creating entity with Transform")
    local entity = registry:create()
    registry:emplace(entity, Transform)

    log_test("  Destroying entity")
    registry:destroy(entity)

    log_test("  Trying to get component from cache")
    local result = component_cache.get(entity, Transform)

    log_test("  Verifying: returns nil for destroyed entity")
    assert_nil(result, "component_cache returns nil for destroyed entity")
end, {
    doc_ids = {"pattern:ecs.cache.get_after_destroy"},
    tags = {"ecs", "cache"}
})

--------------------------------------------------------------------------------
-- DESTRUCTION TESTS
--------------------------------------------------------------------------------

run_test("ecs.destroy.no_stale_refs", function()
    log_test("  Creating entity")
    local entity = registry:create()
    local EntityType = Node:extend()
    local script = EntityType {}
    script.marker = "will_be_destroyed"
    script:attach_ecs { create_new = false, existing_entity = entity }

    log_test("  Storing reference")
    local ref = entity

    log_test("  Destroying entity")
    registry:destroy(entity)

    log_test("  Calling safe_script_get(ref)")
    local result = safe_script_get(ref)

    log_test("  Verifying: returns nil (no stale data)")
    assert_nil(result, "safe_script_get returns nil for destroyed entity ref")
end, {
    doc_ids = {"pattern:ecs.destroy.no_stale_refs"},
    tags = {"ecs", "cleanup"}
})

run_test("ecs.destroy.then_recreate", function()
    log_test("  Creating and destroying entity")
    local entity1 = registry:create()
    local EntityType = Node:extend()
    local script1 = EntityType {}
    script1.old_data = "should_not_persist"
    script1:attach_ecs { create_new = false, existing_entity = entity1 }
    registry:destroy(entity1)

    log_test("  Creating NEW entity")
    local entity2 = registry:create()
    local script2 = EntityType {}
    script2.fresh = true
    script2:attach_ecs { create_new = false, existing_entity = entity2 }

    log_test("  Verifying: new entity has clean state")
    assert_true(script2.fresh, "new entity has fresh data")
    assert_nil(script2.old_data, "new entity has no old data")

    registry:destroy(entity2)
end, {
    doc_ids = {"pattern:ecs.destroy.then_recreate"},
    tags = {"ecs", "cleanup"}
})

run_test("ecs.destroy.cache_cleared", function()
    log_test("  Creating entity with Transform")
    local entity = registry:create()
    local transform = registry:emplace(entity, Transform)
    transform.actualX = 999

    log_test("  Caching component")
    local cached1 = component_cache.get(entity, Transform)
    assert_eq(cached1.actualX, 999, "initial cache correct")

    log_test("  Destroying entity")
    registry:destroy(entity)

    log_test("  Verifying: cache returns nil")
    local cached2 = component_cache.get(entity, Transform)
    assert_nil(cached2, "cache cleared after destroy")
end, {
    doc_ids = {"pattern:ecs.destroy.cache_cleared"},
    tags = {"ecs", "cleanup", "cache"}
})

--------------------------------------------------------------------------------
-- SUMMARY
--------------------------------------------------------------------------------

log_test("")
log_test("=== Entity Lifecycle Tests Complete ===")
log_test(string.format("PASSED: %d", _results.passed))
log_test(string.format("FAILED: %d", _results.failed))

if _results.failed > 0 then
    log_test("")
    log_test("Failed tests:")
    for test_id, result in pairs(_results.tests) do
        if result.status == "FAIL" then
            log_test("  - " .. test_id .. ": " .. (result.error or "unknown error"))
        end
    end
end

-- Return results for programmatic access
return _results
