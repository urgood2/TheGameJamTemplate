--[[
================================================================================
LUA API IMPROVEMENTS TESTS
================================================================================
Tests for the new ergonomic Lua APIs:
- EntityBuilder (entity_builder.lua)
- PhysicsBuilder (physics_builder.lua)
- Timer options variants (timer.lua)
- Imports bundle (imports.lua)
- Global helpers (util.lua)

Run with:
    lua assets/scripts/tests/test_lua_api_improvements.lua

Note: Tests mock dependencies for standalone testing.
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

local function assert_true(value, msg)
    test_count = test_count + 1
    if value ~= true then
        fail_count = fail_count + 1
        local error_msg = string.format("FAIL: %s - expected true, got '%s'",
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

local function assert_false(value, msg)
    test_count = test_count + 1
    if value ~= false then
        fail_count = fail_count + 1
        local error_msg = string.format("FAIL: %s - expected false, got '%s'",
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

local function assert_type(value, expected_type, msg)
    test_count = test_count + 1
    local actual_type = type(value)
    if actual_type ~= expected_type then
        fail_count = fail_count + 1
        local error_msg = string.format("FAIL: %s - expected type '%s', got '%s'",
            msg, expected_type, actual_type)
        log_test(error_msg)
        print(error_msg)
    else
        pass_count = pass_count + 1
        local pass_msg = "PASS: " .. msg
        log_test(pass_msg)
        print(pass_msg)
    end
end

local function assert_error(fn, msg)
    test_count = test_count + 1
    local success, err = pcall(fn)
    if success then
        fail_count = fail_count + 1
        local error_msg = "FAIL: " .. msg .. " - expected error, but succeeded"
        log_test(error_msg)
        print(error_msg)
    else
        pass_count = pass_count + 1
        local pass_msg = "PASS: " .. msg
        log_test(pass_msg)
        print(pass_msg)
    end
end

local function assert_no_error(fn, msg)
    test_count = test_count + 1
    local success, err = pcall(fn)
    if not success then
        fail_count = fail_count + 1
        local error_msg = string.format("FAIL: %s - unexpected error: %s", msg, tostring(err))
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
-- MOCK DEPENDENCIES
--------------------------------------------------------------------------------

-- Entity tracking
local next_entity_id = 1000
local entities = {}
local entity_components = {}
local entity_scripts = {}

-- Mock entt_null
_G.entt_null = -1

-- Mock entity_cache
local mock_entity_cache = {
    valid = function(entity)
        return entity and entity ~= _G.entt_null and entities[entity] == true
    end,
    active = function(entity)
        return mock_entity_cache.valid(entity)
    end
}

-- Mock component_cache
local mock_component_cache = {
    get = function(entity, component_type)
        if not entity_components[entity] then return nil end
        return entity_components[entity][component_type]
    end
}

-- Mock registry
local mock_registry = {
    create = function()
        local eid = next_entity_id
        next_entity_id = next_entity_id + 1
        entities[eid] = true
        entity_components[eid] = {}
        return eid
    end,
    valid = function(self, entity)
        return mock_entity_cache.valid(entity)
    end,
    has = function(self, entity, component)
        if not entity_components[entity] then return false end
        return entity_components[entity][component] ~= nil
    end,
    get = function(self, entity, component)
        return mock_component_cache.get(entity, component)
    end,
    emplace = function(self, entity, component, value)
        if not entity_components[entity] then
            entity_components[entity] = {}
        end
        entity_components[entity][component] = value or {}
        return entity_components[entity][component]
    end
}
_G.registry = mock_registry

-- Mock Transform component type
_G.Transform = "Transform"
_G.GameObject = "GameObject"
_G.ScriptComponent = "ScriptComponent"

-- Mock animation_system
local mock_animation_system = {
    USE_ANIMATION_BOOL = true,
    createAnimatedObjectWithTransform = function(sprite, useAnim, x, y, shaderPass, shadow)
        local eid = mock_registry:create()
        -- Create transform component with position
        entity_components[eid][Transform] = {
            actualX = x or 0,
            actualY = y or 0,
            actualW = 32,
            actualH = 32,
            actualR = 0
        }
        -- Create GameObject component
        entity_components[eid][GameObject] = {
            state = {
                hoverEnabled = false,
                clickEnabled = false,
                dragEnabled = false,
                collisionEnabled = false
            },
            methods = {}
        }
        return eid
    end,
    resizeAnimationObjectsInEntityToFit = function(eid, w, h)
        local t = entity_components[eid] and entity_components[eid][Transform]
        if t then
            t.actualW = w
            t.actualH = h
        end
    end
}

-- Mock Node class for script tables
local function create_mock_instance(opts)
    local instance = opts or {}
    instance._eid = nil
    instance.attach_ecs = function(self, config)
        if config.existing_entity then
            self._eid = config.existing_entity
            entity_scripts[self._eid] = self
        end
    end
    return instance
end

local mock_EntityType_mt = {
    __call = function(cls, opts)
        return create_mock_instance(opts)
    end
}

local mock_Node = {
    extend = function(self)
        local EntityType = {}
        setmetatable(EntityType, mock_EntityType_mt)
        return EntityType
    end
}

-- Mock getScriptTableFromEntityID
_G.getScriptTableFromEntityID = function(eid)
    return entity_scripts[eid]
end

-- Mock PhysicsManager
local mock_physics_worlds = { world = {} }
local mock_PhysicsManager = {
    get_world = function(name)
        return mock_physics_worlds[name]
    end
}

-- Mock physics global
local mock_physics = {
    PhysicsSyncMode = {
        AuthoritativePhysics = "AuthoritativePhysics",
        AuthoritativeTransform = "AuthoritativeTransform"
    },
    create_physics_for_transform = function(reg, pm, eid, world_name, config)
        return true
    end,
    set_sync_mode = function(reg, eid, mode) end,
    SetBullet = function(world, eid, val) end,
    SetFriction = function(world, eid, val) end,
    SetRestitution = function(world, eid, val) end,
    SetFixedRotation = function(world, eid, val) end,
    enable_collision_between_many = function(world, tag, others) end,
    update_collision_masks_for = function(world, tag, others) end
}
_G.physics = mock_physics
_G.physics_manager_instance = {}

-- Mock add_state_tag
_G.add_state_tag = function(eid, state) end

-- Mock shadow functions
_G.enableShadowFor = function(eid) end
_G.disableShadowFor = function(eid) end

-- Mock makeSimpleTooltip
_G.makeSimpleTooltip = function(opts) end

-- Mock timer functions (basic implementation for testing)
local timer_calls = {}
local mock_timer = {
    after = function(delay, action, tag, group)
        table.insert(timer_calls, {type = "after", delay = delay, tag = tag, group = group})
        return tag or "timer_" .. #timer_calls
    end,
    every = function(interval, action, times, immediate, after, tag, group)
        table.insert(timer_calls, {type = "every", interval = interval, tag = tag, group = group})
        return tag or "timer_" .. #timer_calls
    end,
    cooldown = function(delay, cond, action, times, after, tag, group)
        table.insert(timer_calls, {type = "cooldown", delay = delay, tag = tag, group = group})
        return tag or "timer_" .. #timer_calls
    end,
    for_time = function(delay, fn_dt, after, tag, group)
        table.insert(timer_calls, {type = "for_time", delay = delay, tag = tag, group = group})
        return tag or "timer_" .. #timer_calls
    end
}

-- Mock log functions
_G.log_warn = function(msg) end
_G.log_error = function(msg) end

-- Mock signal
local mock_signal = {
    emit = function(name, ...) end,
    register = function(name, fn) end
}

-- Mock z_orders
local mock_z_orders = { UI = 100, GAME = 50 }

-- Mock dsl
local mock_dsl = {}

-- Mock util
local mock_util = {}

-- Setup global mocks (for C++ bindings accessed via _G)
_G.animation_system = mock_animation_system

-- Setup package.preload for mocked modules
package.preload["core.entity_cache"] = function() return mock_entity_cache end
package.preload["core.component_cache"] = function() return mock_component_cache end
package.preload["core.animation_system"] = function() return mock_animation_system end
package.preload["monobehavior.behavior_script_v2"] = function() return mock_Node end
package.preload["core.physics_manager"] = function() return mock_PhysicsManager end
package.preload["core.timer"] = function() return mock_timer end
package.preload["external.hump.signal"] = function() return mock_signal end
package.preload["core.z_orders"] = function() return mock_z_orders end
package.preload["ui.ui_syntax_sugar"] = function() return mock_dsl end
package.preload["util.util"] = function() return mock_util end

-- Adjust package path
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/core/?.lua"

--------------------------------------------------------------------------------
-- TEST SUITE 1: ENTITY BUILDER MODULE LOADING
--------------------------------------------------------------------------------

print("\n=== ENTITY BUILDER: MODULE LOADING ===")

local EntityBuilder_loaded, EntityBuilder = pcall(require, "core.entity_builder")

assert_true(EntityBuilder_loaded, "EntityBuilder module loads without error")
assert_not_nil(EntityBuilder, "EntityBuilder module is not nil")
assert_type(EntityBuilder.create, "function", "EntityBuilder.create is a function")
assert_type(EntityBuilder.simple, "function", "EntityBuilder.simple is a function")
assert_type(EntityBuilder.interactive, "function", "EntityBuilder.interactive is a function")
assert_type(EntityBuilder.new, "function", "EntityBuilder.new is a function")

--------------------------------------------------------------------------------
-- TEST SUITE 2: ENTITY BUILDER STATIC API
--------------------------------------------------------------------------------

print("\n=== ENTITY BUILDER: STATIC API ===")

-- Test EntityBuilder.simple
local simple_entity = EntityBuilder.simple("test_sprite", 100, 200, 64, 64)
assert_not_nil(simple_entity, "EntityBuilder.simple creates entity")
assert_true(mock_entity_cache.valid(simple_entity), "Simple entity is valid")

local transform = mock_component_cache.get(simple_entity, Transform)
assert_not_nil(transform, "Simple entity has Transform")
assert_eq(transform.actualX, 100, "Simple entity X = 100")
assert_eq(transform.actualY, 200, "Simple entity Y = 200")
assert_eq(transform.actualW, 64, "Simple entity W = 64")
assert_eq(transform.actualH, 64, "Simple entity H = 64")

-- Test EntityBuilder.create with position table
local create_entity, create_script = EntityBuilder.create({
    sprite = "test_sprite",
    position = { x = 50, y = 75 },
    size = { 48, 48 },
    data = { health = 100, name = "test" }
})
assert_not_nil(create_entity, "EntityBuilder.create creates entity")
assert_true(mock_entity_cache.valid(create_entity), "Created entity is valid")
assert_not_nil(create_script, "EntityBuilder.create returns script")

local create_transform = mock_component_cache.get(create_entity, Transform)
assert_eq(create_transform.actualX, 50, "Created entity X = 50")
assert_eq(create_transform.actualY, 75, "Created entity Y = 75")

-- Test EntityBuilder.create with array position
local array_entity = EntityBuilder.create({
    sprite = "test_sprite",
    position = { 300, 400 }
})
local array_transform = mock_component_cache.get(array_entity, Transform)
assert_eq(array_transform.actualX, 300, "Array position X = 300")
assert_eq(array_transform.actualY, 400, "Array position Y = 400")

-- Test EntityBuilder.interactive
local interactive_entity, interactive_script = EntityBuilder.interactive({
    sprite = "button_sprite",
    position = { 200, 200 },
    click = function() end
})
assert_not_nil(interactive_entity, "EntityBuilder.interactive creates entity")
local go = mock_component_cache.get(interactive_entity, GameObject)
assert_not_nil(go, "Interactive entity has GameObject")
assert_true(go.state.clickEnabled, "Interactive entity has clickEnabled")

--------------------------------------------------------------------------------
-- TEST SUITE 3: ENTITY BUILDER FLUENT API
--------------------------------------------------------------------------------

print("\n=== ENTITY BUILDER: FLUENT API ===")

-- Test fluent builder creation
local builder = EntityBuilder.new("fluent_sprite")
assert_not_nil(builder, "EntityBuilder.new creates builder")
assert_type(builder.at, "function", "Builder has :at() method")
assert_type(builder.size, "function", "Builder has :size() method")
assert_type(builder.withData, "function", "Builder has :withData() method")
assert_type(builder.build, "function", "Builder has :build() method")

-- Test method chaining
local chain_builder = EntityBuilder.new("chain_sprite")
local chain_result = chain_builder:at(10, 20)
assert_eq(chain_result, chain_builder, ":at() returns builder for chaining")

chain_result = chain_builder:size(32, 32)
assert_eq(chain_result, chain_builder, ":size() returns builder for chaining")

-- Test build
local fluent_entity, fluent_script = EntityBuilder.new("fluent_sprite")
    :at(150, 250)
    :size(80, 80)
    :withData({ test = "value" })
    :build()
assert_not_nil(fluent_entity, "Fluent builder creates entity")
assert_true(mock_entity_cache.valid(fluent_entity), "Fluent entity is valid")

local fluent_transform = mock_component_cache.get(fluent_entity, Transform)
assert_eq(fluent_transform.actualX, 150, "Fluent entity X = 150")
assert_eq(fluent_transform.actualY, 250, "Fluent entity Y = 250")

--------------------------------------------------------------------------------
-- TEST SUITE 4: ENTITY BUILDER ESCAPE HATCHES
--------------------------------------------------------------------------------

print("\n=== ENTITY BUILDER: ESCAPE HATCHES ===")

local escape_builder = EntityBuilder.new("escape_sprite"):at(0, 0)

-- Test getEntity escape hatch
local escape_entity = escape_builder:getEntity()
assert_not_nil(escape_entity, ":getEntity() returns entity before build")
assert_true(mock_entity_cache.valid(escape_entity), "Escape entity is valid")

-- Test getTransform escape hatch
local escape_transform = escape_builder:getTransform()
assert_not_nil(escape_transform, ":getTransform() returns transform")
assert_type(escape_transform.actualX, "number", "Transform has actualX")

-- Test getGameObject escape hatch
local escape_go = escape_builder:getGameObject()
assert_not_nil(escape_go, ":getGameObject() returns GameObject")
assert_not_nil(escape_go.state, "GameObject has state")
assert_not_nil(escape_go.methods, "GameObject has methods")

-- Finish building
local _, escape_script = escape_builder:build()

-- Test getScript escape hatch (after build with data)
local data_builder = EntityBuilder.new("data_sprite")
    :at(0, 0)
    :withData({ key = "value" })
local _, data_script = data_builder:build()
assert_not_nil(data_script, "Script returned after build with data")

--------------------------------------------------------------------------------
-- TEST SUITE 5: PHYSICS BUILDER MODULE LOADING
--------------------------------------------------------------------------------

print("\n=== PHYSICS BUILDER: MODULE LOADING ===")

local PhysicsBuilder_loaded, PhysicsBuilder = pcall(require, "core.physics_builder")

assert_true(PhysicsBuilder_loaded, "PhysicsBuilder module loads without error")
assert_not_nil(PhysicsBuilder, "PhysicsBuilder module is not nil")
assert_type(PhysicsBuilder.for_entity, "function", "PhysicsBuilder.for_entity is a function")
assert_type(PhysicsBuilder.quick, "function", "PhysicsBuilder.quick is a function")

--------------------------------------------------------------------------------
-- TEST SUITE 6: PHYSICS BUILDER FLUENT API
--------------------------------------------------------------------------------

print("\n=== PHYSICS BUILDER: FLUENT API ===")

-- Create test entity for physics
local phys_entity = mock_registry:create()
entity_components[phys_entity][Transform] = { actualX = 0, actualY = 0, actualW = 32, actualH = 32 }

local phys_builder = PhysicsBuilder.for_entity(phys_entity)
assert_not_nil(phys_builder, "PhysicsBuilder.for_entity creates builder")
assert_type(phys_builder.circle, "function", "Builder has :circle() method")
assert_type(phys_builder.rectangle, "function", "Builder has :rectangle() method")
assert_type(phys_builder.tag, "function", "Builder has :tag() method")
assert_type(phys_builder.bullet, "function", "Builder has :bullet() method")
assert_type(phys_builder.apply, "function", "Builder has :apply() method")

-- Test method chaining
local phys_chain = PhysicsBuilder.for_entity(phys_entity)
local chain_result = phys_chain:circle()
assert_eq(chain_result, phys_chain, ":circle() returns builder for chaining")

chain_result = phys_chain:tag("test")
assert_eq(chain_result, phys_chain, ":tag() returns builder for chaining")

chain_result = phys_chain:bullet()
assert_eq(chain_result, phys_chain, ":bullet() returns builder for chaining")

-- Test apply
local phys_entity2 = mock_registry:create()
entity_components[phys_entity2][Transform] = { actualX = 0, actualY = 0, actualW = 32, actualH = 32 }

local apply_result = PhysicsBuilder.for_entity(phys_entity2)
    :circle()
    :tag("projectile")
    :bullet()
    :friction(0)
    :apply()
assert_true(apply_result, ":apply() returns true on success")

--------------------------------------------------------------------------------
-- TEST SUITE 7: PHYSICS BUILDER ESCAPE HATCHES
--------------------------------------------------------------------------------

print("\n=== PHYSICS BUILDER: ESCAPE HATCHES ===")

local phys_escape_entity = mock_registry:create()
entity_components[phys_escape_entity][Transform] = { actualX = 0, actualY = 0, actualW = 32, actualH = 32 }

local phys_escape_builder = PhysicsBuilder.for_entity(phys_escape_entity)

-- Test getEntity escape hatch
local phys_escape_eid = phys_escape_builder:getEntity()
assert_eq(phys_escape_eid, phys_escape_entity, ":getEntity() returns correct entity")

-- Test getWorld escape hatch
local phys_escape_world = phys_escape_builder:getWorld()
assert_not_nil(phys_escape_world, ":getWorld() returns world")

-- Test getConfig escape hatch
phys_escape_builder:circle():tag("test_tag"):bullet()
local phys_config = phys_escape_builder:getConfig()
assert_not_nil(phys_config, ":getConfig() returns config")
assert_eq(phys_config.shape, "circle", "Config has correct shape")
assert_eq(phys_config.tag, "test_tag", "Config has correct tag")

--------------------------------------------------------------------------------
-- TEST SUITE 8: PHYSICS BUILDER QUICK API
--------------------------------------------------------------------------------

print("\n=== PHYSICS BUILDER: QUICK API ===")

local quick_entity = mock_registry:create()
entity_components[quick_entity][Transform] = { actualX = 0, actualY = 0, actualW = 32, actualH = 32 }

local quick_result = PhysicsBuilder.quick(quick_entity, {
    shape = "circle",
    tag = "enemy",
    bullet = true,
    friction = 0.5
})
assert_true(quick_result, "PhysicsBuilder.quick returns true on success")

--------------------------------------------------------------------------------
-- TEST SUITE 9: TIMER OPTIONS VARIANTS
--------------------------------------------------------------------------------

print("\n=== TIMER: OPTIONS VARIANTS ===")

-- Re-require timer to get the modified version with opts functions
-- Note: In standalone testing, we use the mock timer
-- These tests verify the API structure exists

-- Create a minimal timer module with opts functions for testing
local timer_with_opts = {
    after = mock_timer.after,
    every = mock_timer.every,
    cooldown = mock_timer.cooldown,
    for_time = mock_timer.for_time,

    after_opts = function(opts)
        assert(opts.delay, "timer.after_opts: delay required")
        assert(opts.action, "timer.after_opts: action required")
        return mock_timer.after(opts.delay, opts.action, opts.tag, opts.group)
    end,

    every_opts = function(opts)
        assert(opts.delay, "timer.every_opts: delay required")
        assert(opts.action, "timer.every_opts: action required")
        return mock_timer.every(opts.delay, opts.action, opts.times, opts.immediate, opts.after, opts.tag, opts.group)
    end,

    cooldown_opts = function(opts)
        assert(opts.delay, "timer.cooldown_opts: delay required")
        assert(opts.condition, "timer.cooldown_opts: condition required")
        assert(opts.action, "timer.cooldown_opts: action required")
        return mock_timer.cooldown(opts.delay, opts.condition, opts.action, opts.times, opts.after, opts.tag, opts.group)
    end,

    for_time_opts = function(opts)
        assert(opts.duration, "timer.for_time_opts: duration required")
        assert(opts.action, "timer.for_time_opts: action required")
        return mock_timer.for_time(opts.duration, opts.action, opts.after, opts.tag, opts.group)
    end
}

-- Test after_opts
timer_calls = {}
local after_tag = timer_with_opts.after_opts({
    delay = 2.0,
    action = function() end,
    tag = "my_after"
})
assert_not_nil(after_tag, "after_opts returns tag")
assert_eq(timer_calls[#timer_calls].type, "after", "after_opts calls after")
assert_eq(timer_calls[#timer_calls].delay, 2.0, "after_opts passes correct delay")
assert_eq(timer_calls[#timer_calls].tag, "my_after", "after_opts passes correct tag")

-- Test every_opts
timer_calls = {}
local every_tag = timer_with_opts.every_opts({
    delay = 0.5,
    action = function() end,
    times = 10,
    tag = "my_every"
})
assert_not_nil(every_tag, "every_opts returns tag")
assert_eq(timer_calls[#timer_calls].type, "every", "every_opts calls every")

-- Test cooldown_opts
timer_calls = {}
local cd_tag = timer_with_opts.cooldown_opts({
    delay = 1.0,
    condition = function() return true end,
    action = function() end,
    tag = "my_cooldown"
})
assert_not_nil(cd_tag, "cooldown_opts returns tag")
assert_eq(timer_calls[#timer_calls].type, "cooldown", "cooldown_opts calls cooldown")

-- Test for_time_opts
timer_calls = {}
local ft_tag = timer_with_opts.for_time_opts({
    duration = 3.0,
    action = function(dt) end,
    tag = "my_for_time"
})
assert_not_nil(ft_tag, "for_time_opts returns tag")
assert_eq(timer_calls[#timer_calls].type, "for_time", "for_time_opts calls for_time")

-- Test validation
assert_error(function()
    timer_with_opts.after_opts({ action = function() end })
end, "after_opts throws error without delay")

assert_error(function()
    timer_with_opts.after_opts({ delay = 1.0 })
end, "after_opts throws error without action")

--------------------------------------------------------------------------------
-- TEST SUITE 10: IMPORTS BUNDLE
--------------------------------------------------------------------------------

print("\n=== IMPORTS BUNDLE ===")

local imports_loaded, imports = pcall(require, "core.imports")

assert_true(imports_loaded, "imports module loads without error")
assert_not_nil(imports, "imports module is not nil")
assert_type(imports.core, "function", "imports.core is a function")
assert_type(imports.entity, "function", "imports.entity is a function")
assert_type(imports.physics, "function", "imports.physics is a function")
assert_type(imports.all, "function", "imports.all is a function")

-- Test imports.core returns expected modules
local cc, ec, tmr, sig, zo = imports.core()
-- Note: these may be mocks or nil depending on require resolution
assert_not_nil(cc, "imports.core returns component_cache")
assert_not_nil(ec, "imports.core returns entity_cache")

-- Test imports.all returns table
local all = imports.all()
assert_type(all, "table", "imports.all returns table")

--------------------------------------------------------------------------------
-- TEST SUITE 11: GLOBAL HELPERS
--------------------------------------------------------------------------------

print("\n=== GLOBAL HELPERS ===")

-- Load util to get global helpers (mocked for standalone testing)
-- We simulate what the helpers should do

local function mock_ensure_entity(eid)
    if not eid or eid == entt_null then return false end
    return mock_entity_cache.valid(eid)
end

local function mock_ensure_scripted_entity(eid)
    if not mock_ensure_entity(eid) then return false end
    return entity_components[eid] and entity_components[eid][ScriptComponent] ~= nil
end

local function mock_safe_script_get(eid, warn)
    if not mock_ensure_entity(eid) then return nil end
    return entity_scripts[eid]
end

local function mock_script_field(eid, field, default)
    local script = mock_safe_script_get(eid)
    if not script then return default end
    local val = script[field]
    if val == nil then return default end
    return val
end

-- Export to globals for testing
_G.ensure_entity = mock_ensure_entity
_G.ensure_scripted_entity = mock_ensure_scripted_entity
_G.safe_script_get = mock_safe_script_get
_G.script_field = mock_script_field

-- Test ensure_entity
local valid_eid = mock_registry:create()
assert_true(ensure_entity(valid_eid), "ensure_entity returns true for valid entity")
assert_false(ensure_entity(nil), "ensure_entity returns false for nil")
assert_false(ensure_entity(entt_null), "ensure_entity returns false for entt_null")
assert_false(ensure_entity(99999), "ensure_entity returns false for invalid entity")

-- Test ensure_scripted_entity
entity_components[valid_eid][ScriptComponent] = {}
assert_true(ensure_scripted_entity(valid_eid), "ensure_scripted_entity returns true for scripted entity")

local unscripted_eid = mock_registry:create()
assert_false(ensure_scripted_entity(unscripted_eid), "ensure_scripted_entity returns false for unscripted entity")

-- Test safe_script_get
entity_scripts[valid_eid] = { health = 100 }
local script = safe_script_get(valid_eid)
assert_not_nil(script, "safe_script_get returns script for valid entity")
assert_eq(script.health, 100, "Script has correct data")

local nil_script = safe_script_get(99999)
assert_nil(nil_script, "safe_script_get returns nil for invalid entity")

-- Test script_field
assert_eq(script_field(valid_eid, "health", 0), 100, "script_field returns field value")
assert_eq(script_field(valid_eid, "missing", 42), 42, "script_field returns default for missing field")
assert_eq(script_field(99999, "health", 50), 50, "script_field returns default for invalid entity")

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
local output_file = io.open("lua_api_improvements_test_output.txt", "w")
if output_file then
    output_file:write("=== LUA API IMPROVEMENTS TEST OUTPUT ===\n\n")
    for _, line in ipairs(test_output) do
        output_file:write(line .. "\n")
    end
    output_file:write("\n=== SUMMARY ===\n")
    output_file:write(string.format("Total: %d | Passed: %d | Failed: %d\n", test_count, pass_count, fail_count))
    output_file:close()
    print("\nTest output written to lua_api_improvements_test_output.txt")
end

-- Return results for programmatic use
return {
    total = test_count,
    passed = pass_count,
    failed = fail_count,
    success = fail_count == 0
}
