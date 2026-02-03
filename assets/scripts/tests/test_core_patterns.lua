--[[
================================================================================
CORE PATTERN TESTS
================================================================================
Exercises core builder, timer, and signal patterns for Phase 5 mining.

Run with:
    lua assets/scripts/tests/test_core_patterns.lua
================================================================================
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/tests/?.lua"

local standalone = not _G.registry
if standalone then
    pcall(require, "tests.mocks.engine_mock")
end

local t = require("tests.test_runner")

local function register(test_id, doc_id, source_ref, fn)
    t:register(test_id, "core", fn, {
        doc_ids = { doc_id },
        tags = { "pattern", "core" },
        source_ref = source_ref,
    })
end

local function patch_table(target, patches)
    local originals = {}
    for key, value in pairs(patches) do
        originals[key] = target[key]
        target[key] = value
    end
    return function()
        for key, _ in pairs(patches) do
            target[key] = originals[key]
        end
    end
end

local function ensure_child_builder_stubs()
    _G.transform = _G.transform or {}
    _G.transform.AssignRole = _G.transform.AssignRole or function() end
    _G.transform.ConfigureAlignment = _G.transform.ConfigureAlignment or function() end
    _G.Vector2 = _G.Vector2 or function(vec) return { x = vec.x, y = vec.y } end
    _G.InheritedPropertiesType = _G.InheritedPropertiesType or { RoleInheritor = 1, RoleCarbonCopy = 2 }
    _G.InheritedPropertiesSync = _G.InheritedPropertiesSync or { Strong = 1 }
    _G.AlignmentFlag = _G.AlignmentFlag or {
        HORIZONTAL_LEFT = 1,
        HORIZONTAL_RIGHT = 2,
        HORIZONTAL_CENTER = 4,
        VERTICAL_TOP = 8,
        VERTICAL_BOTTOM = 16,
        VERTICAL_CENTER = 32,
        ALIGN_TO_INNER_EDGES = 64,
    }
    _G.bit = _G.bit or { bor = function(a, b) return (a or 0) + (b or 0) end }
    _G.InheritedProperties = _G.InheritedProperties or { _type = "InheritedProperties" }
    _G.GameObject = _G.GameObject or { _type = "GameObject" }
end

register(
    "core.entity_builder.create",
    "pattern:core.entity_builder.create",
    "assets/scripts/core/entity_builder.lua:14",
    function()
        _G.Transform = _G.Transform or { _type = "Transform" }
        local EntityBuilder = require("core.entity_builder")
        local entity, script = EntityBuilder.create({
            sprite = "test_sprite",
            position = { x = 10, y = 20 },
            size = { 16, 16 },
        })
        t.expect(type(entity)).to_be("number")
        t.expect(script).to_be_nil()
    end
)

register(
    "core.entity_builder.fluent_chain",
    "pattern:core.entity_builder.fluent_chain",
    "assets/scripts/core/procgen/spawner.lua:9",
    function()
        _G.Transform = _G.Transform or { _type = "Transform" }
        local EntityBuilder = require("core.entity_builder")
        local builder = EntityBuilder.new("test_sprite"):at(5, 6):size(12, 12)
        local entity = builder:build()
        t.expect(type(entity)).to_be("number")
    end
)

register(
    "core.child_builder.attach_offset",
    "pattern:core.child_builder.attach_offset",
    "assets/scripts/core/child_builder.lua:12",
    function()
        ensure_child_builder_stubs()

        local registry = _G.registry
        local component_cache = _G.component_cache

        local parent = registry:create()
        local child = registry:create()

        component_cache.set(parent, _G.GameObject, { children = {}, orderedChildren = {} })
        component_cache.set(child, _G.InheritedProperties, { flags = {} })

        local ChildBuilder = require("core.child_builder")
        local result = ChildBuilder.for_entity(child)
            :attachTo(parent)
            :offset(20, 0)
            :rotateWith()
            :apply()

        t.expect(result).to_be(child)
        local parentGO = component_cache.get(parent, _G.GameObject)
        t.expect(parentGO.children[tostring(child)]).to_be(child)
    end
)

register(
    "core.shader_builder.add_apply",
    "pattern:core.shader_builder.add_apply",
    "assets/scripts/core/shader_builder.lua:9",
    function()
        local registry = _G.registry
        local restore_registry = patch_table(registry, {
            has = function() return false end,
            emplace = function(_, _, _)
                return {
                    passes = {},
                    addPass = function(self, pass) self.passes[#self.passes + 1] = pass end,
                    clearAll = function() end,
                    removePass = function() end,
                }
            end,
        })

        _G.shader_pipeline = _G.shader_pipeline or {}
        _G.shader_pipeline.ShaderPipelineComponent = _G.shader_pipeline.ShaderPipelineComponent or {}
        _G.globalShaderUniforms = _G.globalShaderUniforms or {}
        _G.globalShaderUniforms.set = _G.globalShaderUniforms.set or function() end

        local ShaderBuilder = require("core.shader_builder")
        local entity = registry:create()
        local result = ShaderBuilder.for_entity(entity):add("3d_skew_holo"):apply()

        restore_registry()

        t.expect(result).to_be(entity)
    end
)

register(
    "core.physics_builder.basic_chain",
    "pattern:core.physics_builder.basic_chain",
    "assets/scripts/core/physics_builder.lua:13",
    function()
        local registry = _G.registry
        local physics = _G.physics or {}
        _G.physics = physics
        _G.physics_manager_instance = _G.physics_manager_instance or {}
        _G.PhysicsManager = _G.PhysicsManager or { get_world = function() return {} end }

        local restore_physics = patch_table(physics, {
            SetBullet = physics.SetBullet or function() end,
            SetFriction = physics.SetFriction or function() end,
            SetRestitution = physics.SetRestitution or function() end,
            SetFixedRotation = physics.SetFixedRotation or function() end,
        })

        local PhysicsBuilder = require("core.physics_builder")
        local entity = registry:create()
        local builder = PhysicsBuilder.for_entity(entity)
            :circle()
            :tag("projectile")
            :bullet()
            :friction(0)
            :collideWith({ "enemy", "WORLD" })

        builder:apply()
        local cfg = builder:getConfig()

        restore_physics()

        t.expect(cfg.tag).to_be("projectile")
        t.expect(cfg.shape).to_be("circle")
    end
)

register(
    "core.timer.after_basic",
    "pattern:core.timer.after_basic",
    "assets/scripts/core/main.lua:704",
    function()
        local timer = require("core.timer")
        timer.clear_all()

        local tag = timer.after(0.1, function() end, "core_after_tag")
        t.expect(tag).to_be("core_after_tag")
        timer.cancel(tag)
        t.expect(timer.timers[tag]).to_be_nil()
    end
)

register(
    "core.timer.every_guarded_tick",
    "pattern:core.timer.every_guarded_tick",
    "assets/scripts/core/behaviors.lua:210",
    function()
        local timer = require("core.timer")
        timer.clear_all()

        local count = 0
        local tag = timer.every(0.1, function() count = count + 1 end, 0, true, nil, "core_every_tag")
        t.expect(tag).to_be("core_every_tag")
        t.expect(count).to_be(1)
        timer.cancel(tag)
        t.expect(timer.timers[tag]).to_be_nil()
    end
)

register(
    "core.timer.tween_scalar",
    "pattern:core.timer.tween_scalar",
    "assets/scripts/core/main.lua:146",
    function()
        local timer = require("core.timer")
        timer.clear_all()

        local value = 0
        local function getter() return value end
        local function setter(v) value = v end

        timer.tween_scalar(0.2, getter, setter, 10, nil, nil, "core_tween_tag")
        timer.update(0.1)
        t.expect(value > 0).to_be_truthy()
        timer.update(0.2)
        t.expect(timer.timers["core_tween_tag"]).to_be_nil()
    end
)

register(
    "core.signal.emit",
    "pattern:core.signal.emit",
    "assets/scripts/core/grid_transfer.lua:123",
    function()
        local signal = require("external.hump.signal")
        _G.signal = signal

        local count = 0
        signal.clear("core_signal_emit")
        signal.register("core_signal_emit", function() count = count + 1 end)
        signal.emit("core_signal_emit", { id = 1 })

        t.expect(count).to_be(1)
    end
)

register(
    "core.signal.register",
    "pattern:core.signal.register",
    "assets/scripts/core/main.lua:204",
    function()
        local signal = require("external.hump.signal")
        _G.signal = signal

        local count = 0
        signal.clear("core_signal_register")
        signal.register("core_signal_register", function() count = count + 1 end)
        signal.emit("core_signal_register")

        t.expect(count).to_be(1)
    end
)

register(
    "core.signal_group.cleanup",
    "pattern:core.signal_group.cleanup",
    "assets/scripts/core/signal_group.lua:73",
    function()
        local signal = require("external.hump.signal")
        _G.signal = signal

        local SignalGroup = require("core.signal_group")
        local group = SignalGroup.new("core_test_group")

        local count = 0
        signal.clear("core_signal_group")
        group:on("core_signal_group", function() count = count + 1 end)
        signal.emit("core_signal_group")
        group:cleanup()
        signal.emit("core_signal_group")

        t.expect(count).to_be(1)
    end
)

register(
    "core.event_bridge.attach",
    "pattern:core.event_bridge.attach",
    "assets/scripts/core/event_bridge.lua:271",
    function()
        local signal = require("external.hump.signal")
        _G.signal = signal

        local EventBridge = require("core.event_bridge")

        local bus = { handlers = {} }
        function bus:on(event, handler)
            self.handlers[event] = self.handlers[event] or {}
            table.insert(self.handlers[event], handler)
        end
        function bus:emit(event, data)
            local handlers = self.handlers[event] or {}
            for i = 1, #handlers do
                handlers[i](data)
            end
        end

        local ctx = { bus = bus }
        local ok = EventBridge.attach(ctx)

        local count = 0
        signal.clear("enemy_spawned")
        signal.register("enemy_spawned", function() count = count + 1 end)
        bus:emit("OnEnemySpawned", { id = 123 })

        t.expect(ok).to_be(true)
        t.expect(count).to_be(1)
    end
)

if standalone then
    t.run()
end

return t
