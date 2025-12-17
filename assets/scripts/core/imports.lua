--[[
================================================================================
IMPORTS - Common Module Bundles
================================================================================
Reduces repetitive require blocks at the top of files.

Usage:
    local imports = require("core.imports")

    -- Core bundle (most common)
    local component_cache, entity_cache, timer, signal, z_orders = imports.core()

    -- Entity creation bundle
    local Node, animation_system, EntityBuilder, spawn = imports.entity()

    -- Physics bundle
    local PhysicsManager, PhysicsBuilder = imports.physics()

    -- Draw/rendering bundle
    local draw, ShaderBuilder, z_orders = imports.draw()

    -- Combat bundle
    local combat_system, projectile_system, wand_executor = imports.combat()

    -- Utilities bundle
    local util, Easing, palette = imports.util()

    -- Full bundle (everything)
    local i = imports.all()
    -- Access: i.timer, i.signal, i.EntityBuilder, i.draw, i.ShaderBuilder, etc.
]]

local imports = {}

--- Core utilities bundle (5 modules)
--- @return table component_cache
--- @return table entity_cache
--- @return table timer
--- @return table signal
--- @return table z_orders
function imports.core()
    return
        require("core.component_cache"),
        require("core.entity_cache"),
        require("core.timer"),
        require("external.hump.signal"),
        require("core.z_orders")
end

--- Entity creation bundle (4 modules)
--- @return table Node (behavior_script_v2)
--- @return table animation_system (may be nil if not available)
--- @return table EntityBuilder
--- @return table spawn
function imports.entity()
    return
        require("monobehavior.behavior_script_v2"),
        _G.animation_system,
        require("core.entity_builder"),
        require("core.spawn")
end

--- Physics bundle (2 modules)
--- @return table|nil PhysicsManager
--- @return table PhysicsBuilder
function imports.physics()
    local PhysicsManager
    pcall(function()
        PhysicsManager = require("core.physics_manager")
    end)
    return
        PhysicsManager,
        require("core.physics_builder")
end

--- UI bundle (3 modules)
--- @return table dsl (ui_syntax_sugar)
--- @return table z_orders
--- @return table util
function imports.ui()
    return
        require("ui.ui_syntax_sugar"),
        require("core.z_orders"),
        require("util.util")
end

--- Shader bundle (2 modules)
--- @return table ShaderBuilder
--- @return table draw
function imports.shaders()
    return
        require("core.shader_builder"),
        require("core.draw")
end

--- Draw bundle (3 modules) - rendering utilities
--- @return table draw
--- @return table ShaderBuilder
--- @return table z_orders
function imports.draw()
    return
        require("core.draw"),
        require("core.shader_builder"),
        require("core.z_orders")
end

--- Combat bundle (3 modules) - combat and wand systems
--- @return table|nil combat_system
--- @return table|nil projectile_system
--- @return table|nil wand_executor
function imports.combat()
    local combat_system, projectile_system, wand_executor
    pcall(function() combat_system = require("combat.combat_system") end)
    pcall(function() projectile_system = require("combat.projectile_system") end)
    pcall(function() wand_executor = require("wand.wand_executor") end)
    return combat_system, projectile_system, wand_executor
end

--- Util bundle (3 modules) - utilities and helpers
--- @return table util
--- @return table Easing
--- @return table palette
function imports.util()
    return
        require("util.util"),
        require("util.easing"),
        require("color.palette")
end

--- All common modules as a single table
--- @return table All imports keyed by name
function imports.all()
    local component_cache, entity_cache, timer, signal, z_orders = imports.core()
    local Node, animation_system, EntityBuilder, spawn = imports.entity()
    local PhysicsManager, PhysicsBuilder = imports.physics()
    local draw, ShaderBuilder = imports.draw()
    local combat_system, projectile_system, wand_executor = imports.combat()
    local util, Easing, palette = imports.util()

    return {
        -- Core
        component_cache = component_cache,
        entity_cache = entity_cache,
        timer = timer,
        signal = signal,
        z_orders = z_orders,

        -- Entity
        Node = Node,
        animation_system = animation_system,
        EntityBuilder = EntityBuilder,
        spawn = spawn,

        -- Physics
        PhysicsManager = PhysicsManager,
        PhysicsBuilder = PhysicsBuilder,

        -- Draw/Shaders
        draw = draw,
        ShaderBuilder = ShaderBuilder,

        -- Combat
        combat_system = combat_system,
        projectile_system = projectile_system,
        wand_executor = wand_executor,

        -- Util
        util = util,
        Easing = Easing,
        palette = palette,
    }
end

return imports
