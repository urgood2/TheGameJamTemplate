--[[
================================================================================
API REFERENCE - Comprehensive List of Global Functions and Modules
================================================================================
This module serves as documentation for all globally-available APIs in Lua.
It does NOT expose new functionality - it documents what's already available.

HOW GLOBALS ARE SET UP:
1. C++ bindings (scripting_functions.cpp) - registry, physics, camera, etc.
2. Lua modules with _G exports - gameplay.lua, util.lua, etc.

CATEGORIES:
- ECS & Entity Management
- Component Access
- Physics
- Camera
- UI & Tooltips
- State Management
- Timers
- Signals/Events
- Content Systems
- Utility Functions
- Debug/Telemetry

Usage:
    local api = require("core.api")
    api.print_available()  -- Print all available APIs
    api.check_bindings()   -- Verify C++ bindings are loaded
]]

local API = {}

--===========================================================================
-- C++ BINDINGS (set by scripting_functions.cpp)
--===========================================================================
-- These are set before any Lua code runs

API.CPP_BINDINGS = {
    -- ECS
    registry = "EnTT registry for entity/component management",
    entt_null = "Null entity constant",

    -- Physics
    physics = "Physics system (Chipmunk2D wrapper)",
    physics_manager_instance = "Global physics manager",
    PhysicsManager = "Physics world manager",

    -- Rendering
    animation_system = "Sprite animation system",
    shader_pipeline = "Shader pipeline manager",
    command_buffer = "Draw command buffer",
    layer = "Render layer manager",

    -- Camera
    camera = "Camera system",

    -- Input
    input = "Input manager",
    controller = "Controller navigation",

    -- AI
    steering = "Steering behaviors",
    ai_system = "AI/behavior tree system",

    -- Sound
    sound = "Sound manager",

    -- Logging
    log_debug = "Debug logging (may be disabled)",
    log_info = "Info logging",
    log_warn = "Warning logging",
    log_error = "Error logging",

    -- Components (string names for ECS)
    Transform = "Position/size/rotation component",
    GameObject = "Game object component with state and methods",
    ScriptComponent = "Lua script attachment",
    StateTag = "State tag component",
    Shadow = "Shadow rendering component",
    AnimationQueueComponent = "Animation queue component",
}

--===========================================================================
-- ENTITY MANAGEMENT (from util.lua and gameplay.lua)
--===========================================================================

API.ENTITY = {
    -- Validation
    ensure_entity = {
        signature = "ensure_entity(eid) -> boolean",
        description = "Check if entity ID is valid (not nil, not entt_null, valid in registry)",
    },
    ensure_scripted_entity = {
        signature = "ensure_scripted_entity(eid) -> boolean",
        description = "Check if entity is valid AND has a ScriptComponent",
    },

    -- Script Table Access
    getScriptTableFromEntityID = {
        signature = "getScriptTableFromEntityID(eid) -> table|nil",
        description = "Get the Lua script table attached to an entity",
    },
    safe_script_get = {
        signature = "safe_script_get(eid, warn_on_nil?) -> table|nil",
        description = "Safely get script table with optional warning",
    },
    script_field = {
        signature = "script_field(eid, field, default) -> any",
        description = "Safely get a field from an entity's script table with default",
    },

    -- Component Access
    safe_component_get = {
        signature = "safe_component_get(eid, comp_type, context?) -> component|nil",
        description = "Safely get component with strict-mode warnings",
    },
    require_component = {
        signature = "require_component(eid, comp_type, context?) -> component",
        description = "Get component or throw error (for required components)",
    },

    -- State Tags
    add_state_tag = {
        signature = "add_state_tag(eid, state)",
        description = "Add a state tag to an entity",
    },
    remove_default_state_tag = {
        signature = "remove_default_state_tag(eid)",
        description = "Remove the default state tag from an entity",
    },
    is_state_active = {
        signature = "is_state_active(state) -> boolean",
        description = "Check if a game state is currently active",
    },
    activate_state = {
        signature = "activate_state(state)",
        description = "Activate a game state",
    },
    deactivate_state = {
        signature = "deactivate_state(state)",
        description = "Deactivate a game state",
    },
}

--===========================================================================
-- UI & TOOLTIPS (from gameplay.lua)
--===========================================================================

API.UI = {
    makeSimpleTooltip = {
        signature = "makeSimpleTooltip(title, body, id?) -> entity",
        description = "Create a simple tooltip entity",
    },
    ensureSimpleTooltip = {
        signature = "ensureSimpleTooltip(title, body, id?)",
        description = "Create tooltip if not exists, otherwise update it",
    },
    showSimpleTooltipAbove = {
        signature = "showSimpleTooltipAbove(title, body, target_entity, id?)",
        description = "Show tooltip positioned above an entity",
    },
    hideSimpleTooltip = {
        signature = "hideSimpleTooltip(id?)",
        description = "Hide a tooltip by ID",
    },
    destroyAllSimpleTooltips = {
        signature = "destroyAllSimpleTooltips()",
        description = "Destroy all active tooltips",
    },
    centerTooltipAboveEntity = {
        signature = "centerTooltipAboveEntity(tooltip_eid, target_eid)",
        description = "Center a tooltip entity above another entity",
    },
    makeCardTooltip = {
        signature = "makeCardTooltip(card) -> entity",
        description = "Create a card-specific tooltip",
    },
    ensureCardTooltip = {
        signature = "ensureCardTooltip(card)",
        description = "Create card tooltip if not exists",
    },
}

--===========================================================================
-- GAME STATE (from gameplay.lua)
--===========================================================================

API.STATE = {
    -- State Constants
    PLANNING_STATE = "PLANNING",
    ACTION_STATE = "SURVIVORS",

    -- Runtime State (read-only)
    current_phase = "Current game phase (planning/action/shop)",
    phase_started_at = "Timestamp when current phase started",

    -- Cost Constants
    AVATAR_PURCHASE_COST = "Cost to purchase avatar in shop",
}

--===========================================================================
-- UTILITY QUERIES (from gameplay.lua)
--===========================================================================

API.QUERIES = {
    isEnemyEntity = {
        signature = "isEnemyEntity(eid) -> boolean",
        description = "Check if an entity is an enemy",
    },
}

--===========================================================================
-- MODULES (Lua modules available via require)
--===========================================================================

API.MODULES = {
    -- Core
    ["core.imports"] = "Bundle imports for common modules",
    ["core.constants"] = "Magic string constants (collision tags, states, etc.)",
    ["core.timer"] = "Timer system for delays, intervals, sequences",
    ["core.component_cache"] = "Cached component access",
    ["core.entity_cache"] = "Entity validation utilities",
    ["core.entity_builder"] = "Fluent entity creation API",
    ["core.physics_builder"] = "Fluent physics setup API",
    ["core.shader_builder"] = "Fluent shader composition API",
    ["core.spawn"] = "Spawn presets and entity creation",
    ["core.draw"] = "Draw command wrappers",
    ["core.z_orders"] = "Z-order constants for rendering",
    ["core.render_layers"] = "Render layer management",
    ["core.particles"] = "Particle system builder",

    -- Data
    ["data.cards"] = "Card definitions",
    ["data.jokers"] = "Joker definitions",
    ["data.projectiles"] = "Projectile presets",
    ["data.enemies"] = "Enemy definitions",
    ["data.spawn_presets"] = "Entity spawn presets",
    ["data.content_defaults"] = "Default values for content",

    -- Combat
    ["combat.combat_system"] = "Combat calculations and actors",
    ["combat.projectile_system"] = "Projectile spawning and management",
    ["combat.enemy_factory"] = "Enemy creation with combat integration",
    ["combat.wave_helpers"] = "Wave system utilities",

    -- Wand
    ["wand.wand_executor"] = "Wand spell execution",
    ["wand.joker_system"] = "Joker event handling",
    ["wand.tag_evaluator"] = "Tag synergy evaluation",

    -- UI
    ["ui.ui_syntax_sugar"] = "Declarative UI DSL",
    ["ui.ui_defs"] = "UI definitions and utilities",

    -- External
    ["external.hump.signal"] = "Signal/event system",
    ["external.object"] = "OOP class system",

    -- Behavior
    ["monobehavior.behavior_script_v2"] = "Node script base class",

    -- Utilities
    ["util.util"] = "General utility functions",
    ["util.easing"] = "Easing functions for animations",
    ["color.palette"] = "Color palette definitions",

    -- Tools
    ["tools.content_validator"] = "Content validation utilities",
}

--===========================================================================
-- STRICT MODE (from util.lua)
--===========================================================================

API.STRICT = {
    set_strict_mode = {
        signature = "set_strict_mode(enabled)",
        description = "Enable/disable strict mode warnings for nil returns",
    },
    is_strict_mode = {
        signature = "is_strict_mode() -> boolean",
        description = "Check if strict mode is enabled",
    },
    STRICT_MODE = {
        description = "Set _G.STRICT_MODE = true before loading util.lua to enable",
    },
    DEBUG_MODE = {
        description = "Set _G.DEBUG_MODE = true to enable both strict mode and debug features",
    },
}

--===========================================================================
-- TELEMETRY (from main.lua)
--===========================================================================

API.TELEMETRY = {
    record_telemetry = {
        signature = "record_telemetry(event_name, data)",
        description = "Record a telemetry event",
    },
    telemetry_session_id = {
        signature = "telemetry_session_id() -> string",
        description = "Get current telemetry session ID",
    },
}

--===========================================================================
-- HELPER FUNCTIONS
--===========================================================================

--- Print all available APIs to console
function API.print_available()
    print("=== AVAILABLE GLOBAL APIs ===")
    print("")

    print("-- C++ Bindings --")
    for name, desc in pairs(API.CPP_BINDINGS) do
        local status = _G[name] and "OK" or "MISSING"
        print(string.format("  [%s] %s: %s", status, name, desc))
    end
    print("")

    print("-- Entity Functions --")
    for name, info in pairs(API.ENTITY) do
        local status = _G[name] and "OK" or "MISSING"
        print(string.format("  [%s] %s", status, info.signature or name))
    end
    print("")

    print("-- UI Functions --")
    for name, info in pairs(API.UI) do
        local status = _G[name] and "OK" or "MISSING"
        print(string.format("  [%s] %s", status, info.signature or name))
    end
end

--- Check if all C++ bindings are loaded
--- @return boolean success
--- @return string[] missing List of missing bindings
function API.check_bindings()
    local missing = {}
    for name, _ in pairs(API.CPP_BINDINGS) do
        if not _G[name] then
            table.insert(missing, name)
        end
    end
    return #missing == 0, missing
end

--- List all available modules
--- @return string[] List of module paths
function API.list_modules()
    local modules = {}
    for path, _ in pairs(API.MODULES) do
        table.insert(modules, path)
    end
    table.sort(modules)
    return modules
end

--- Get documentation for a specific global
--- @param name string Global name
--- @return table|nil Documentation info
function API.get_docs(name)
    -- Check each category
    if API.ENTITY[name] then return API.ENTITY[name] end
    if API.UI[name] then return API.UI[name] end
    if API.QUERIES[name] then return API.QUERIES[name] end
    if API.STRICT[name] then return API.STRICT[name] end
    if API.TELEMETRY[name] then return API.TELEMETRY[name] end
    if API.CPP_BINDINGS[name] then
        return { description = API.CPP_BINDINGS[name] }
    end
    return nil
end

return API
