-- assets/scripts/tests/test_entity_lifecycle.lua
--[[
================================================================================
TEST: Entity Lifecycle (mock-driven, deterministic)
================================================================================
Run standalone: lua assets/scripts/tests/test_entity_lifecycle.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local EngineMock = require("tests.mocks.engine_mock")

local TestRunner = require("core.test.test_runner")
local t = require("tests.test_runner")
local Node = require("monobehavior.behavior_script_v2")

--------------------------------------------------------------------------------
-- Mock core engine globals (deterministic + standalone)
--------------------------------------------------------------------------------

_G.entt_null = 0
_G.ScriptComponent = "ScriptComponent"
_G.GameObject = "GameObject"
_G.Transform = "Transform"

local entity_store = {}
local next_entity_id = 1000
local component_store = {}

local function reset_registry()
    entity_store = {}
    next_entity_id = 1000
end

_G.component_cache = {
    get = function(eid, comp)
        if not component_store[eid] then return nil end
        return component_store[eid][comp]
    end,
    set = function(eid, comp, value)
        if not component_store[eid] then
            component_store[eid] = {}
        end
        component_store[eid][comp] = value
        return value
    end,
    invalidate = function(eid, comp)
        if not eid then
            component_store = {}
            return
        end
        if not component_store[eid] then return end
        if comp then
            component_store[eid][comp] = nil
        else
            component_store[eid] = nil
        end
    end,
    _reset = function()
        component_store = {}
    end,
}

_G.registry = {
    create = function()
        next_entity_id = next_entity_id + 1
        entity_store[next_entity_id] = true
        return next_entity_id
    end,
    valid = function(_, eid)
        return entity_store[eid] == true
    end,
    destroy = function(_, eid)
        entity_store[eid] = nil
    end,
    add_script = function(_, eid, script)
        _G.component_cache.set(eid, _G.ScriptComponent, { self = script })
    end,
    has = function(_, eid, comp)
        return _G.component_cache.get(eid, comp) ~= nil
    end,
    get = function(_, eid, comp)
        return _G.component_cache.get(eid, comp)
    end,
}

package.loaded["core.entity_cache"] = {
    valid = function(eid)
        return _G.registry:valid(eid)
    end,
}

package.loaded["task.task"] = package.loaded["task.task"] or {
    run_named_task = function() end,
    wait = function() end,
    count_tasks = function() return 0 end,
}

package.loaded["core.timer"] = package.loaded["core.timer"] or {
    after = function(_, fn)
        if fn then fn() end
        return "timer"
    end,
    every = function(_, fn)
        if fn then fn() end
        return "timer"
    end,
    cancel = function() end,
}

--------------------------------------------------------------------------------
-- Entity lifecycle helpers (match util.lua semantics)
--------------------------------------------------------------------------------

local function ensure_entity(eid)
    return eid ~= nil and eid ~= entt_null and _G.registry:valid(eid)
end

local function ensure_scripted_entity(eid)
    return ensure_entity(eid) and _G.registry:has(eid, _G.ScriptComponent)
end

local function safe_script_get(eid)
    if not ensure_entity(eid) then return nil end
    local script_comp = _G.component_cache.get(eid, _G.ScriptComponent)
    if not script_comp then return nil end
    return script_comp.self
end

local function script_field(eid, field, default)
    local script = safe_script_get(eid)
    if not script then return default end
    local value = script[field]
    if value == nil then return default end
    return value
end

_G.ensure_entity = ensure_entity
_G.ensure_scripted_entity = ensure_scripted_entity
_G.safe_script_get = safe_script_get
_G.script_field = script_field

local function destroy_entity(eid)
    _G.registry:destroy(eid)
    _G.component_cache.invalidate(eid)
end

local function create_scripted_entity(data)
    local eid = _G.registry:create()
    local ScriptType = Node:extend()
    local script = ScriptType(data or {})
    script:attach_ecs { create_new = false, existing_entity = eid }
    return eid, script
end

local function reset_world()
    _G.component_cache._reset()
    reset_registry()
    EngineMock.clear_logs()
end

local function cleanup_world()
    _G.component_cache._reset()
    reset_registry()
    EngineMock.clear_logs()
end

local PERF_BUDGET_MS = 50

--------------------------------------------------------------------------------
-- Logging helpers (required format)
--------------------------------------------------------------------------------

local header_logged = false

local function log_line(msg)
    print("[ECS-TEST] " .. msg)
end

local function log_header()
    if not header_logged then
        log_line("=== Entity Lifecycle Tests ===")
        header_logged = true
    end
end

local function log_start(test_id, setup, tags)
    log_header()
    log_line("Reset world before: smoke.registry")
    reset_world()
    log_line("")
    log_line("Testing: " .. test_id)
    if setup then
        log_line("  " .. setup)
    end
    log_line("  Doc ID: pattern:" .. test_id)
    if tags then
        log_line("  Tags: " .. table.concat(tags, ", "))
    end
end

local function log_action(action)
    log_line("  " .. action)
end

local function log_pass(test_id, elapsed_ms)
    log_line(string.format("PASS: %s (%.2fms)", test_id, elapsed_ms))
end

--------------------------------------------------------------------------------
-- Test registration wrapper
--------------------------------------------------------------------------------

local function register(test_id, setup, fn, tags)
    local meta_tags = tags or { "ecs", "lifecycle" }
    TestRunner.register(test_id, "ecs", function()
        local start = os.clock()
        log_start(test_id, setup, meta_tags)
        local ok, err = xpcall(fn, debug.traceback)
        cleanup_world()
        if not ok then
            error(err)
        end
        local elapsed_ms = (os.clock() - start) * 1000
        log_pass(test_id, elapsed_ms)
    end, {
        doc_ids = { "pattern:" .. test_id },
        tags = meta_tags,
    })
end

--------------------------------------------------------------------------------
-- Tests (required IDs)
--------------------------------------------------------------------------------

-- Initialization Order
register("ecs.attach_ecs.assign_before_attach", "Creating EntityType", function()
    local eid = _G.registry:create()
    local ScriptType = Node:extend()
    local script = ScriptType {}
    log_action("Assigning data.value = 42")
    log_action("Assigning data FIRST")
    script.data = { value = 42 }

    local observed = nil
    script:run_custom_func(function(_, self)
        observed = self.data and self.data.value or nil
    end)

    log_action("Calling attach_ecs SECOND")
    script:attach_ecs { create_new = false, existing_entity = eid }
    log_action("Verifying: data.value == 42")

    t.assert_equals(42, script.data.value, "data preserved after attach")
    t.assert_equals(42, observed, "attach-time hook saw data")
end)

register("ecs.attach_ecs.assign_after_attach_fails", "Creating EntityType", function()
    local eid = _G.registry:create()
    local ScriptType = Node:extend()
    local script = ScriptType {}

    local observed = nil
    script:run_custom_func(function(_, self)
        observed = self.data and self.data.value or nil
    end)

    log_action("Calling attach_ecs FIRST")
    script:attach_ecs { create_new = false, existing_entity = eid }
    log_action("Assigning data.value = 42 AFTER attach_ecs")
    script.data = { value = 42 }
    log_action("Verifying: attach-time hook missed data")

    t.assert_nil(observed, "attach-time hook missed late data")
    t.assert_equals(42, script.data.value, "data exists but too late")
end)

register("ecs.init.data_preserved", "Creating entity with nested data", function()
    local ScriptType = Node:extend()
    function ScriptType:init()
        self.init_seen = self.data and self.data.value or nil
    end

    log_action("Assigning nested data before attach")
    local script = ScriptType { data = { value = 99, nested = { hp = 10 } } }
    local eid = _G.registry:create()
    log_action("Calling attach_ecs")
    script:attach_ecs { create_new = false, existing_entity = eid }
    log_action("Verifying: init saw data and nested preserved")

    t.assert_equals(99, script.init_seen, "init sees data when passed at creation")
    t.assert_equals(10, script.data.nested.hp, "nested data preserved")
end)

-- GameObject
register("ecs.gameobject.no_data_storage", "Creating scripted entity with GameObject", function()
    local eid, script = create_scripted_entity({ health = 10 })
    _G.component_cache.set(eid, _G.GameObject, { state = {} })
    local go = _G.component_cache.get(eid, _G.GameObject)
    log_action("Attempting to store data on GameObject")
    go.health = 999
    log_action("Verifying: script table remains source of truth")

    t.assert_equals(10, script.health, "script data unchanged")
    t.assert_equals(10, safe_script_get(eid).health, "script table is source of truth")
end)

register("ecs.gameobject.script_table_usage", "Creating scripted entity", function()
    local eid, script = create_scripted_entity({})
    log_action("Storing state in script table")
    script.state = { mode = "active" }
    log_action("Verifying: safe_script_get returns data")

    local fetched = safe_script_get(eid)
    t.assert_not_nil(fetched, "safe_script_get returns script table")
    t.assert_equals("active", fetched.state.mode, "script table retains data")
end)

-- Validation
register("ecs.validate.ensure_entity_valid", "Creating valid entity", function()
    local eid = _G.registry:create()
    log_action("Calling ensure_entity(valid_eid)")
    t.assert_true(ensure_entity(eid), "ensure_entity returns true for valid entity")
end)

register("ecs.validate.ensure_entity_invalid", "Creating then destroying entity", function()
    local eid = _G.registry:create()
    destroy_entity(eid)
    log_action("Calling ensure_entity on nil/entt_null/destroyed")

    t.assert_false(ensure_entity(nil), "nil entity invalid")
    t.assert_false(ensure_entity(entt_null), "entt_null invalid")
    t.assert_false(ensure_entity(eid), "destroyed entity invalid")
end)

register("ecs.validate.ensure_scripted_entity_valid", "Creating scripted entity", function()
    local eid = _G.registry:create()
    local ScriptType = Node:extend()
    local script = ScriptType {}
    script:attach_ecs { create_new = false, existing_entity = eid }
    log_action("Calling ensure_scripted_entity(valid)")
    t.assert_true(ensure_scripted_entity(eid), "scripted entity valid")
end)

register("ecs.validate.ensure_scripted_entity_invalid", "Creating non-scripted entity", function()
    local eid = _G.registry:create()
    log_action("Calling ensure_scripted_entity on entity without ScriptComponent")
    t.assert_false(ensure_scripted_entity(eid), "entity without script invalid")
end)

-- Safe Access
register("ecs.access.script_field_default", "Creating scripted entity", function()
    local eid = _G.registry:create()
    local ScriptType = Node:extend()
    local script = ScriptType {}
    script:attach_ecs { create_new = false, existing_entity = eid }
    log_action("Calling script_field(eid, \"health\", 100)")

    t.assert_equals(100, script_field(eid, "health", 100), "default returned when missing")
end)

register("ecs.access.script_field_nil", "Creating scripted entity", function()
    local eid = _G.registry:create()
    local ScriptType = Node:extend()
    local script = ScriptType {}
    script:attach_ecs { create_new = false, existing_entity = eid }
    log_action("Calling script_field(eid, \"mana\", nil)")

    t.assert_nil(script_field(eid, "mana", nil), "nil default allowed")
end)

register("ecs.access.safe_script_get_valid", "Creating scripted entity", function()
    local eid, _ = create_scripted_entity({ value = 7 })
    log_action("Calling safe_script_get(valid)")
    t.assert_not_nil(safe_script_get(eid), "safe_script_get returns script table")
end)

register("ecs.access.safe_script_get_invalid", "Using invalid entity id", function()
    log_action("Calling safe_script_get(invalid)")
    t.assert_nil(safe_script_get(99999), "invalid entity returns nil")
end)

-- Component Cache
register("ecs.cache.get_valid", "Creating entity with Transform", function()
    local eid = _G.registry:create()
    _G.component_cache.set(eid, _G.Transform, { actualX = 10 })
    log_action("Calling component_cache.get")
    local comp = _G.component_cache.get(eid, _G.Transform)

    log_action("Verifying: component_cache.get returns component")
    t.assert_not_nil(comp, "component_cache.get returns component")
    t.assert_equals(10, comp.actualX, "component data preserved")
end)

register("ecs.cache.get_after_destroy", "Creating entity then destroying", function()
    local eid = _G.registry:create()
    _G.component_cache.set(eid, _G.Transform, { actualX = 10 })
    log_action("Destroying entity")
    destroy_entity(eid)
    log_action("Calling component_cache.get on destroyed entity")

    t.assert_nil(_G.component_cache.get(eid, _G.Transform), "cache empty after destroy")
end)

register("ecs.cache.invalidation", "Creating entity with Transform", function()
    local eid = _G.registry:create()
    _G.component_cache.set(eid, _G.Transform, { actualX = 10 })
    log_action("Invalidating Transform component")
    _G.component_cache.invalidate(eid, _G.Transform)

    log_action("Verifying: invalidate clears component")
    t.assert_nil(_G.component_cache.get(eid, _G.Transform), "invalidate clears component")
end)

register("ecs.cache.performance", "Repeated cache lookups", function()
    local eid = _G.registry:create()
    _G.component_cache.set(eid, _G.Transform, { actualX = 10 })
    log_action("Performing 1000 cache lookups")
    local start_time = os.clock()
    for _ = 1, 1000 do
        local comp = _G.component_cache.get(eid, _G.Transform)
        t.assert_not_nil(comp, "cached lookup returns component")
    end
    local elapsed_ms = (os.clock() - start_time) * 1000
    log_action(string.format("Verifying perf budget: %.2fms < %dms", elapsed_ms, PERF_BUDGET_MS))
    t.assert_true(elapsed_ms < PERF_BUDGET_MS, "cache lookup stays within perf budget")
end, { "ecs", "lifecycle", "performance" })

-- Destruction
register("ecs.destroy.no_stale_refs", "Creating entity then destroying", function()
    local eid, _ = create_scripted_entity({ value = 1 })
    log_action("Destroying entity")
    destroy_entity(eid)
    log_action("Calling safe_script_get(ref)")

    t.assert_nil(safe_script_get(eid), "safe_script_get returns nil after destroy")
end, { "ecs", "lifecycle", "cleanup" })

register("ecs.destroy.then_recreate", "Destroy then recreate", function()
    local eid, _ = create_scripted_entity({ value = 5 })
    log_action("Destroying entity")
    destroy_entity(eid)
    log_action("Creating new entity after destroy")
    local new_eid, new_script = create_scripted_entity({ value = 7 })

    log_action("Verifying: new entity has clean state")
    t.assert_equals(7, new_script.value, "new entity has clean state")
    t.assert_true(new_eid ~= eid, "new entity id differs")
    log_action("Verifying: old entity script gone")
    t.assert_nil(safe_script_get(eid), "old entity script gone")
end, { "ecs", "lifecycle", "cleanup" })

register("ecs.destroy.cleanup_all_references", "Cleaning reference list", function()
    local eid_a, _ = create_scripted_entity({})
    local eid_b, _ = create_scripted_entity({})
    local refs = { eid_a, eid_b }
    log_action("Destroying first entity")
    destroy_entity(eid_a)
    log_action("Filtering refs with ensure_entity")

    local cleaned = {}
    for _, ref in ipairs(refs) do
        if ensure_entity(ref) then
            table.insert(cleaned, ref)
        end
    end

    t.assert_equals(1, #cleaned, "invalid references removed")
    t.assert_equals(eid_b, cleaned[1], "valid reference retained")
end, { "ecs", "lifecycle", "cleanup" })

register("ecs.destroy.cache_cleared", "Destroy clears component_cache", function()
    local eid = _G.registry:create()
    _G.component_cache.set(eid, _G.Transform, { actualX = 22 })
    log_action("Destroying entity")
    destroy_entity(eid)

    log_action("Verifying: cache cleared after destroy")
    t.assert_nil(_G.component_cache.get(eid, _G.Transform), "cache cleared after destroy")
end, { "ecs", "lifecycle", "cleanup" })

-- LuaJIT
register("ecs.luajit.200_local_limit", "LuaJIT local variable cap", function()
    if not jit then
        log_action("SKIP: LuaJIT not present in this runtime")
        return
    end

    log_action("Building chunk with >200 locals")
    local locals = {}
    for i = 1, 205 do
        locals[#locals + 1] = string.format("local v%d = %d", i, i)
    end
    locals[#locals + 1] = "return v1"
    local chunk = table.concat(locals, "\n")

    log_action("Compiling chunk with >200 locals")
    local ok = pcall(load, chunk)
    log_action("Verifying: LuaJIT rejects chunk")
    t.assert_false(ok, "LuaJIT rejects chunks with >200 locals")
end, { "ecs", "lifecycle", "luajit" })

local success = TestRunner.run()
os.exit(success and 0 or 1)
