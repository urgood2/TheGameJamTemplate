-- assets/scripts/tests/mocks/engine_mock.lua
--[[
================================================================================
ENGINE MOCK: Minimal Game Engine Simulation for Standalone Tests
================================================================================
Provides lightweight mocks for C++ globals and game-specific modules that are
normally only available when running inside the game engine.

Usage in test files:
    require("tests.mocks.engine_mock")  -- Sets up all mocks
    local t = require("tests.test_runner")
    -- ... tests ...

The mock provides:
- C++ globals (registry, component_cache, physics, etc.)
- UI system stubs (ui.definitions, animation_system, etc.)
- Logging functions (log_debug, log_warn, log_error)
- Utility functions (ensure_entity, safe_script_get, etc.)

Game-only feature detection:
- If test code accidentally calls game-only features, a clear error
  is raised explaining what's missing and how to mock it.
]]

local EngineMock = {}

-- Track what's been mocked for diagnostics
EngineMock._mocked_globals = {}
EngineMock._game_only_features = {}

--------------------------------------------------------------------------------
-- Mock Entity IDs (simple incrementing counter)
--------------------------------------------------------------------------------

local _next_entity_id = 1000

function EngineMock.next_entity()
    _next_entity_id = _next_entity_id + 1
    return _next_entity_id
end

--------------------------------------------------------------------------------
-- Mock Registry (minimal EnTT registry simulation)
--------------------------------------------------------------------------------

local MockRegistry = {}
MockRegistry.__index = MockRegistry

function MockRegistry:create()
    return EngineMock.next_entity()
end

function MockRegistry:valid(entity)
    return entity ~= nil and type(entity) == "number"
end

function MockRegistry:destroy(entity)
    -- No-op in mock
end

_G.registry = setmetatable({}, MockRegistry)
EngineMock._mocked_globals.registry = true

--------------------------------------------------------------------------------
-- Mock Component Cache
--------------------------------------------------------------------------------

local _component_store = {}

_G.component_cache = {
    get = function(entity, component_type)
        if not _component_store[entity] then return nil end
        return _component_store[entity][component_type]
    end,
    set = function(entity, component_type, value)
        if not _component_store[entity] then
            _component_store[entity] = {}
        end
        _component_store[entity][component_type] = value
    end,
    -- For test cleanup
    _reset = function()
        _component_store = {}
    end
}
EngineMock._mocked_globals.component_cache = true

--------------------------------------------------------------------------------
-- Mock Logging Functions
--------------------------------------------------------------------------------

local _captured_logs = { debug = {}, warn = {}, error = {} }

_G.log_debug = function(msg)
    table.insert(_captured_logs.debug, msg)
end

_G.log_warn = function(msg)
    table.insert(_captured_logs.warn, msg)
    -- Also print to stderr for visibility
    io.stderr:write("WARN: " .. tostring(msg) .. "\n")
end

_G.log_error = function(msg)
    table.insert(_captured_logs.error, msg)
    io.stderr:write("ERROR: " .. tostring(msg) .. "\n")
end

-- For test assertions on log output
EngineMock.get_logs = function()
    return _captured_logs
end

EngineMock.clear_logs = function()
    _captured_logs = { debug = {}, warn = {}, error = {} }
end

EngineMock._mocked_globals.log_debug = true
EngineMock._mocked_globals.log_warn = true
EngineMock._mocked_globals.log_error = true

--------------------------------------------------------------------------------
-- Mock Globals & Constants
--------------------------------------------------------------------------------

_G.globals = {
    screenWidth = 1920,
    screenHeight = 1080,
    dt = 0.016,  -- ~60 FPS
    time = 0,
}
EngineMock._mocked_globals.globals = true

_G.AlignmentFlag = {
    HORIZONTAL_CENTER = 1,
    VERTICAL_CENTER = 2,
    HORIZONTAL_LEFT = 4,
    HORIZONTAL_RIGHT = 8,
    VERTICAL_TOP = 16,
    VERTICAL_BOTTOM = 32,
}
EngineMock._mocked_globals.AlignmentFlag = true

_G.bit = {
    bor = function(a, b) return (a or 0) + (b or 0) end,
    band = function(a, b) return math.min(a or 0, b or 0) end,
    bnot = function(a) return -(a or 0) - 1 end,
}
EngineMock._mocked_globals.bit = true

--------------------------------------------------------------------------------
-- Mock Color System
--------------------------------------------------------------------------------

local MockColor = {}
function MockColor.new(r, g, b, a)
    return { r = r or 255, g = g or 255, b = b or 255, a = a or 255 }
end

_G.Color = MockColor
_G.util = {
    getColor = function(c)
        if type(c) == "string" then
            local colors = {
                white = { r = 255, g = 255, b = 255, a = 255 },
                black = { r = 0, g = 0, b = 0, a = 255 },
                red = { r = 255, g = 0, b = 0, a = 255 },
                green = { r = 0, g = 255, b = 0, a = 255 },
                blue = { r = 0, g = 0, b = 255, a = 255 },
            }
            return colors[c] or colors.white
        end
        return c
    end
}
EngineMock._mocked_globals.Color = true
EngineMock._mocked_globals.util = true

--------------------------------------------------------------------------------
-- Mock UI System
--------------------------------------------------------------------------------

_G.ui = {
    definitions = {
        def = function(t) return t end,
        wrapEntityInsideObjectElement = function(e) return e end,
        getNewDynamicTextEntry = function(fn, sz, eff) return { config = {} } end,
        getTextFromString = function(txt, opts) return { type = "TEXT", config = opts } end,
    },
    box = {},
}
EngineMock._mocked_globals.ui = true

_G.animation_system = {
    createAnimatedObjectWithTransform = function() return EngineMock.next_entity() end,
    resizeAnimationObjectsInEntityToFit = function() end,
}
EngineMock._mocked_globals.animation_system = true

_G.layer_order_system = {
    assignZIndexToEntity = function() end,
    getZIndex = function() return 0 end,
}
EngineMock._mocked_globals.layer_order_system = true

--------------------------------------------------------------------------------
-- Mock Physics System
--------------------------------------------------------------------------------

_G.physics = {
    PhysicsSyncMode = {
        AuthoritativePhysics = 0,
        AuthoritativeTransform = 1,
    },
    create_physics_for_transform = function() end,
    set_sync_mode = function() end,
    enable_collision_between_many = function() end,
    update_collision_masks_for = function() end,
}
EngineMock._mocked_globals.physics = true

--------------------------------------------------------------------------------
-- Mock Timer (minimal)
--------------------------------------------------------------------------------

local MockTimer = {}
MockTimer._timers = {}

function MockTimer.after(delay, fn)
    table.insert(MockTimer._timers, { delay = delay, fn = fn, type = "after" })
end

function MockTimer.every(delay, fn)
    table.insert(MockTimer._timers, { delay = delay, fn = fn, type = "every" })
end

function MockTimer._reset()
    MockTimer._timers = {}
end

-- Note: The real timer module is at "core.timer" - we don't mock it at _G
-- Tests that need timer should either require the real module or use this mock explicitly
EngineMock._mocked_globals._timer = MockTimer

--------------------------------------------------------------------------------
-- Mock Shader Pipeline
--------------------------------------------------------------------------------

_G.shader_pipeline = {
    addShader = function() end,
    removeShader = function() end,
    setUniform = function() end,
}
EngineMock._mocked_globals.shader_pipeline = true

_G.globalShaderUniforms = {
    setFloat = function() end,
    setVec2 = function() end,
    setVec4 = function() end,
}
EngineMock._mocked_globals.globalShaderUniforms = true

--------------------------------------------------------------------------------
-- Mock Command Buffer
--------------------------------------------------------------------------------

_G.command_buffer = {
    queueDrawBatchedEntities = function() end,
    queueDrawRectangle = function() end,
    queueDrawText = function() end,
}
EngineMock._mocked_globals.command_buffer = true

--------------------------------------------------------------------------------
-- Mock Layers & Z-Orders
--------------------------------------------------------------------------------

_G.layers = {
    sprites = "sprites",
    ui = "ui",
    effects = "effects",
}
EngineMock._mocked_globals.layers = true

_G.z_orders = {
    background = 0,
    card = 100,
    top_card = 200,
    ui_tooltips = 900,
}
EngineMock._mocked_globals.z_orders = true

_G.layer = {
    DrawCommandSpace = {
        World = 0,
        Screen = 1,
    }
}
EngineMock._mocked_globals.layer = true

--------------------------------------------------------------------------------
-- Mock Localization
--------------------------------------------------------------------------------

_G.localization = {
    get = function(key) return key end,
    getStyled = function(key, params) return key end,
}
EngineMock._mocked_globals.localization = true

--------------------------------------------------------------------------------
-- Entity Validation Helpers
--------------------------------------------------------------------------------

_G.ensure_entity = function(eid)
    return eid ~= nil and type(eid) == "number"
end

_G.ensure_scripted_entity = function(eid)
    return _G.ensure_entity(eid)
end

_G.safe_script_get = function(eid)
    -- In mock, return a minimal script table
    if not _G.ensure_entity(eid) then return nil end
    return { entity = eid }
end

_G.script_field = function(eid, field, default)
    local script = _G.safe_script_get(eid)
    if not script then return default end
    return script[field] or default
end

EngineMock._mocked_globals.ensure_entity = true
EngineMock._mocked_globals.ensure_scripted_entity = true
EngineMock._mocked_globals.safe_script_get = true
EngineMock._mocked_globals.script_field = true

--------------------------------------------------------------------------------
-- Game-Only Feature Detection
--------------------------------------------------------------------------------

-- Features that require the full game engine
EngineMock._game_only_features = {
    "raylib",
    "window",
    "audio",
    "input_system",
    "quadtreeWorld",
    "quadtreeUI",
    "FindAllEntitiesAtPoint",
    "chipmunk",
}

-- Create error-throwing stubs for game-only features
for _, feature in ipairs(EngineMock._game_only_features) do
    if _G[feature] == nil then
        _G[feature] = setmetatable({}, {
            __index = function(_, key)
                error(string.format(
                    "[GAME-ONLY FEATURE] '%s.%s' requires the game engine.\n" ..
                    "This feature is not available in standalone Lua tests.\n" ..
                    "Either mock it in your test or skip this test for standalone execution.",
                    feature, tostring(key)
                ), 2)
            end,
            __call = function()
                error(string.format(
                    "[GAME-ONLY FEATURE] '%s' requires the game engine.\n" ..
                    "This feature is not available in standalone Lua tests.\n" ..
                    "Either mock it in your test or skip this test for standalone execution.",
                    feature
                ), 2)
            end,
        })
    end
end

--------------------------------------------------------------------------------
-- API for Tests
--------------------------------------------------------------------------------

--- Reset all mock state (call in before_each)
function EngineMock.reset()
    _next_entity_id = 1000
    _component_store = {}
    _captured_logs = { debug = {}, warn = {}, error = {} }
    MockTimer._reset()
end

--- Check if a global is mocked
function EngineMock.is_mocked(name)
    return EngineMock._mocked_globals[name] == true
end

--- Get list of all mocked globals
function EngineMock.list_mocked()
    local list = {}
    for name, _ in pairs(EngineMock._mocked_globals) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end

return EngineMock
