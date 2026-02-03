--[[
================================================================================
ENTITY LIFECYCLE TESTS
================================================================================
Tests for entity creation, initialization order, validation, and destruction.

Covers:
- Initialization order (attach_ecs timing)
- GameObject restrictions
- Entity validation (ensure_entity, ensure_scripted_entity)
- Safe access patterns (script_field, safe_script_get)
- Component cache behavior
- Destruction and cleanup

Doc IDs: pattern:ecs.*
================================================================================
]]

local TestRunner = require("test.test_runner")
local test_utils = require("test.test_utils")

local assert_eq = test_utils.assert_eq
local assert_true = test_utils.assert_true
local assert_false = test_utils.assert_false
local assert_nil = test_utils.assert_nil
local assert_not_nil = test_utils.assert_not_nil

local function log_test(msg)
    test_utils.log("[ECS-TEST] " .. msg)
end

--------------------------------------------------------------------------------
-- DEPENDENCIES
--------------------------------------------------------------------------------

local Node = require("monobehavior.behavior_script_v2")
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")

local registry = _G.registry
local entt_null = _G.entt_null

local safe_script_get = _G.safe_script_get
local script_field = _G.script_field
local ensure_entity = _G.ensure_entity
local ensure_scripted_entity = _G.ensure_scripted_entity

--------------------------------------------------------------------------------
-- Test registration helper
--------------------------------------------------------------------------------

local function register(test_id, fn, opts)
    opts = opts or {}
    opts.tags = opts.tags or {"ecs"}
    opts.requires = opts.requires or {"test_scene"}
    TestRunner.register(test_id, "ecs", fn, opts)
end

--------------------------------------------------------------------------------
-- INITIALIZATION ORDER TESTS
--------------------------------------------------------------------------------

register("ecs.attach_ecs.assign_before_attach", function()
    log_test("Creating EntityType")
    local entity = registry:create()
    local EntityType = Node:extend()
    local script = EntityType {}

    log_test("Assigning data.value = 42 FIRST")
    script.data = { value = 42 }
    script.customField = "hello"

    log_test("Calling attach_ecs SECOND")
    script:attach_ecs { create_new = false, existing_entity = entity }

    log_test("Verifying: data preserved after attach")
    assert_eq(script.data.value, 42, "data.value should remain 42")
    assert_eq(script.customField, "hello", "customField should remain hello")
end, {
    doc_ids = {"pattern:ecs.attach_ecs.assign_before_attach"},
})

register("ecs.init.data_preserved", function()
    local entity = registry:create()
    local EntityType = Node:extend()
    local script = EntityType {}

    script.data = { value = "test" }
    script:attach_ecs { create_new = false, existing_entity = entity }

    assert_eq(script.data.value, "test", "data.value should survive attach_ecs")
end, {
    doc_ids = {"pattern:ecs.attach_ecs.data_preserved"},
})

register("ecs.gameobject.script_table_usage", function()
    local entity = registry:create()
    local EntityType = Node:extend()
    local script = EntityType {}

    script:attach_ecs { create_new = false, existing_entity = entity }

    local go = component_cache.get(entity, _G.GameObject)
    assert_not_nil(go, "GameObject should exist")
    assert_eq(go.script, script, "GameObject script table should point to script")
end, {
    doc_ids = {"pattern:ecs.gameobject.script_table_usage"},
})

--------------------------------------------------------------------------------
-- ENTITY VALIDATION TESTS
--------------------------------------------------------------------------------

register("ecs.validate.ensure_entity_valid", function()
    local entity = registry:create()
    assert_true(ensure_entity(entity), "ensure_entity should return true for valid entity")
end, {
    doc_ids = {"pattern:ecs.ensure_entity.valid"},
})

register("ecs.validate.ensure_entity_invalid", function()
    local fake_entity = 999999
    assert_false(ensure_entity(fake_entity), "ensure_entity should return false for invalid entity")
end, {
    doc_ids = {"pattern:ecs.ensure_entity.invalid"},
})

register("ecs.validate.ensure_entity_nil", function()
    assert_false(ensure_entity(nil), "ensure_entity should return false for nil")
end, {
    doc_ids = {"pattern:ecs.ensure_entity.nil"},
})

register("ecs.validate.ensure_scripted_entity_valid", function()
    local entity = registry:create()
    local EntityType = Node:extend()
    local script = EntityType {}

    script:attach_ecs { create_new = false, existing_entity = entity }

    assert_true(ensure_scripted_entity(entity), "ensure_scripted_entity should return true for scripted entity")
end, {
    doc_ids = {"pattern:ecs.ensure_scripted_entity.valid"},
})

register("ecs.validate.ensure_scripted_entity_invalid", function()
    local entity = registry:create()
    assert_false(ensure_scripted_entity(entity), "ensure_scripted_entity should return false when no ScriptComponent")
end, {
    doc_ids = {"pattern:ecs.ensure_scripted_entity.invalid"},
})

--------------------------------------------------------------------------------
-- SAFE ACCESS TESTS
--------------------------------------------------------------------------------

register("ecs.access.script_field_default", function()
    local entity = registry:create()
    local EntityType = Node:extend()
    local script = EntityType {}

    script:attach_ecs { create_new = false, existing_entity = entity }

    local value = script_field(entity, "missing_field", "fallback")
    assert_eq(value, "fallback", "script_field should return default when missing")
end, {
    doc_ids = {"pattern:ecs.script_field.default"},
})

register("ecs.access.script_field_existing", function()
    local entity = registry:create()
    local EntityType = Node:extend()
    local script = EntityType {}

    script.data = { count = 10 }
    script:attach_ecs { create_new = false, existing_entity = entity }

    local value = script_field(entity, "data")
    assert_true(type(value) == "table", "script_field should return existing value")
end, {
    doc_ids = {"pattern:ecs.script_field.existing"},
})

register("ecs.access.safe_script_get_valid", function()
    local entity = registry:create()
    local EntityType = Node:extend()
    local script = EntityType {}

    script.data = { count = 7 }
    script:attach_ecs { create_new = false, existing_entity = entity }

    local value = safe_script_get(entity, "data")
    assert_true(type(value) == "table", "safe_script_get should return existing value")
end, {
    doc_ids = {"pattern:ecs.safe_script_get.valid"},
})

register("ecs.access.safe_script_get_invalid", function()
    local fake_entity = 999999
    local value = safe_script_get(fake_entity, "data")
    assert_nil(value, "safe_script_get should return nil for invalid entity")
end, {
    doc_ids = {"pattern:ecs.safe_script_get.invalid"},
})

register("ecs.access.safe_script_get_nil", function()
    local value = safe_script_get(nil, "data")
    assert_nil(value, "safe_script_get should return nil for nil entity")
end, {
    doc_ids = {"pattern:ecs.safe_script_get.nil"},
})

--------------------------------------------------------------------------------
-- COMPONENT CACHE TESTS
--------------------------------------------------------------------------------

register("ecs.cache.get_valid", function()
    local entity = registry:create()
    local EntityType = Node:extend()
    local script = EntityType {}

    script:attach_ecs { create_new = false, existing_entity = entity }

    local cached = component_cache.get(entity, _G.Transform)
    assert_not_nil(cached, "component_cache returns component")
end, {
    doc_ids = {"pattern:ecs.component_cache.get_valid"},
})

register("ecs.cache.get_after_destroy", function()
    local entity = registry:create()
    local EntityType = Node:extend()
    local script = EntityType {}

    script:attach_ecs { create_new = false, existing_entity = entity }

    registry:destroy(entity)
    local result = component_cache.get(entity, _G.Transform)
    assert_nil(result, "component_cache returns nil for destroyed entity")
end, {
    doc_ids = {"pattern:ecs.component_cache.get_after_destroy"},
})

--------------------------------------------------------------------------------
-- DESTRUCTION AND CLEANUP
--------------------------------------------------------------------------------

register("ecs.destroy.no_stale_refs", function()
    local entity = registry:create()
    local EntityType = Node:extend()
    local script = EntityType {}

    script:attach_ecs { create_new = false, existing_entity = entity }
    registry:destroy(entity)

    assert_false(entity_cache.valid(entity), "entity should be invalid after destroy")
    assert_false(ensure_entity(entity), "ensure_entity should return false after destroy")
end, {
    doc_ids = {"pattern:ecs.destroy.no_stale_refs"},
})

register("ecs.destroy.then_recreate", function()
    local entity = registry:create()
    registry:destroy(entity)

    local new_entity = registry:create()
    assert_true(ensure_entity(new_entity), "new entity should be valid")
end, {
    doc_ids = {"pattern:ecs.destroy.then_recreate"},
})

register("ecs.destroy.cache_cleared", function()
    local entity = registry:create()
    local EntityType = Node:extend()
    local script = EntityType {}

    script:attach_ecs { create_new = false, existing_entity = entity }

    local cached1 = component_cache.get(entity, _G.Transform)
    assert_not_nil(cached1, "component_cache returns component")

    registry:destroy(entity)

    local cached2 = component_cache.get(entity, _G.Transform)
    assert_nil(cached2, "component_cache should be cleared on destroy")
end, {
    doc_ids = {"pattern:ecs.destroy.cache_cleared"},
})

return true
