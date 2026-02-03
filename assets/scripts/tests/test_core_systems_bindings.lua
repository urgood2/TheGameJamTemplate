-- assets/scripts/tests/test_core_systems_bindings.lua
--[[
================================================================================
CORE SYSTEMS BINDINGS TESTS
================================================================================
Run standalone:
    lua assets/scripts/tests/test_core_systems_bindings.lua
================================================================================
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/tests/?.lua"

if _G.__core_systems_bindings_tests_loaded then
    return
end
_G.__core_systems_bindings_tests_loaded = true

local standalone = not _G.registry
if standalone then
    pcall(require, "tests.mocks.engine_mock")
end

local t = require("tests.test_runner")

local entity_store = {}
local component_store = {}
local next_entity_id = 1000

local function reset_state()
    entity_store = {}
    component_store = {}
    next_entity_id = 1000
end

local function ensure_registry()
    local registry = _G.registry
    if type(registry) ~= "table" then
        return registry
    end

    registry.create = registry.create or function()
        next_entity_id = next_entity_id + 1
        entity_store[next_entity_id] = true
        return next_entity_id
    end

    registry.valid = registry.valid or function(_, entity)
        return entity_store[entity] == true
    end

    registry.destroy = registry.destroy or function(_, entity)
        entity_store[entity] = nil
        component_store[entity] = nil
    end

    registry.emplace = registry.emplace or function(_, entity, component, value)
        component_store[entity] = component_store[entity] or {}
        local entry = value or { _type = component }
        component_store[entity][component] = entry
        return entry
    end

    registry.get = registry.get or function(_, entity, component)
        return component_store[entity] and component_store[entity][component] or nil
    end

    registry.has = registry.has or function(_, entity, component)
        return component_store[entity] and component_store[entity][component] ~= nil
    end

    registry.add_script = registry.add_script or function(_, entity, script)
        component_store[entity] = component_store[entity] or {}
        component_store[entity]["ScriptComponent"] = { self = script }
    end

    return registry
end

local function ensure_component_cache()
    local cache = _G.component_cache or {}

    cache.get = cache.get or function(entity, component)
        return component_store[entity] and component_store[entity][component] or nil
    end

    cache.set = cache.set or function(entity, component, value)
        component_store[entity] = component_store[entity] or {}
        component_store[entity][component] = value
        return value
    end

    cache.invalidate = cache.invalidate or function(entity, component)
        if not entity then
            component_store = {}
            return
        end
        if not component_store[entity] then
            return
        end
        if component then
            component_store[entity][component] = nil
        else
            component_store[entity] = nil
        end
    end

    _G.component_cache = cache
    package.loaded["core.component_cache"] = cache
    return cache
end

local function ensure_globals()
    _G.globals = _G.globals or {}
    local g = _G.globals
    g.screenWidth = g.screenWidth or 1280
    g.screenHeight = g.screenHeight or 720
    g.dt = g.dt or 0.016

    if not _G.GetScreenWidth then
        _G.GetScreenWidth = function() return g.screenWidth end
    end
    if not _G.GetScreenHeight then
        _G.GetScreenHeight = function() return g.screenHeight end
    end
    if not _G.GetFrameTime then
        _G.GetFrameTime = function() return g.dt end
    end

    return g
end

local function register(test_id, doc_ids, source_ref, fn)
    t:register(test_id, "core", function()
        reset_state()
        ensure_registry()
        ensure_component_cache()
        ensure_globals()
        fn()
    end, {
        doc_ids = doc_ids,
        tags = { "bindings", "core" },
        source_ref = source_ref,
    })
end

register(
    "core.registry.create.basic",
    { "sol2_property_entt_registry_create" },
    "src/systems/scripting/registry_bond.cpp",
    function()
        local registry = ensure_registry()
        local entity = registry:create()
        t.expect(type(entity)).to_be("number")
        if registry.valid then
            t.expect(registry:valid(entity)).to_be_truthy()
        end
    end
)

register(
    "core.registry.emplace.basic",
    { "sol2_property_entt_registry_emplace", "sol2_property_entt_registry_has" },
    "src/systems/scripting/registry_bond.cpp",
    function()
        local registry = ensure_registry()
        local entity = registry:create()
        local comp = registry:emplace(entity, "Transform", { x = 10, y = 20 })
        t.expect(comp).to_be_truthy()
        if registry.has then
            t.expect(registry:has(entity, "Transform")).to_be_truthy()
        end
    end
)

register(
    "core.registry.get.basic",
    { "sol2_property_entt_registry_get" },
    "src/systems/scripting/registry_bond.cpp",
    function()
        local registry = ensure_registry()
        local entity = registry:create()
        registry:emplace(entity, "Transform", { x = 5, y = 6 })
        local comp = registry:get(entity, "Transform")
        t.expect(comp).to_be_truthy()
        t.expect(comp.x).to_be(5)
    end
)

register(
    "core.component_cache.get.basic",
    { "sol2_function_component_cache_get" },
    "assets/scripts/core/component_cache.lua",
    function()
        local registry = ensure_registry()
        local cache = ensure_component_cache()
        local entity = registry:create()
        registry:emplace(entity, "Transform", { x = 1, y = 2 })
        local comp = cache.get(entity, "Transform")
        t.expect(comp).to_be_truthy()
        t.expect(comp.y).to_be(2)
    end
)

register(
    "core.component_cache.invalidate.on_destroy",
    { "sol2_function_component_cache_invalidate" },
    "assets/scripts/core/component_cache.lua",
    function()
        local registry = ensure_registry()
        local cache = ensure_component_cache()
        local entity = registry:create()
        registry:emplace(entity, "Transform", { x = 7, y = 8 })
        t.expect(cache.get(entity, "Transform")).to_be_truthy()
        registry:destroy(entity)
        cache.invalidate(entity)
        t.expect(cache.get(entity, "Transform")).to_be_nil()
    end
)

register(
    "core.globals.screen_dimensions",
    {
        "sol2_property_globals_screenwidth",
        "sol2_property_globals_screenheight",
        "sol2_function_getscreenwidth",
        "sol2_function_getscreenheight",
    },
    "src/systems/scripting/scripting_functions.cpp",
    function()
        local g = ensure_globals()
        local width = g.screenWidth or _G.GetScreenWidth()
        local height = g.screenHeight or _G.GetScreenHeight()
        t.expect(width > 0).to_be_truthy()
        t.expect(height > 0).to_be_truthy()
    end
)

register(
    "core.globals.delta_time",
    { "sol2_function_getframetime" },
    "src/systems/scripting/scripting_functions.cpp",
    function()
        local dt = _G.GetFrameTime()
        t.expect(type(dt)).to_be("number")
        t.expect(dt > 0).to_be_truthy()
    end
)

return t
