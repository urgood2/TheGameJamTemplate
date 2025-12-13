--[[
================================================================================
DRAW - Table-based Command Buffer Wrappers
================================================================================
Pure Lua wrapper over command_buffer and shader_draw_commands for ergonomic
table-based drawing instead of verbose callback patterns.

Usage - Command Buffer:
    -- Before (verbose)
    command_buffer.queueTextPro(layer, function(c)
        c.text = "Hello"
        c.font = myFont
        c.x = 100
        c.y = 200
        c.origin = { x = 0, y = 0 }
        c.rotation = 0
        c.fontSize = 16
        c.spacing = 1
        c.color = WHITE
    end, 0, layer.DrawCommandSpace.Screen)

    -- After (concise)
    draw.textPro(layer, {
        text = "Hello",
        font = myFont,
        x = 100,
        y = 200,
    })

Usage - Local Commands:
    -- Before (verbose)
    shader_draw_commands.add_local_command(
        registry, entity, "text_pro",
        function(c)
            c.text = "hello"
            c.font = localization.getFont()
            c.x = 10
            c.y = 20
            c.origin = { x = 0, y = 0 }
            c.rotation = 0
            c.fontSize = 20
            c.spacing = 1
            c.color = WHITE
        end,
        1,
        layer.DrawCommandSpace.World,
        true,
        false,
        false
    )

    -- After (concise)
    draw.local_command(entity, "text_pro", {
        text = "hello",
        font = localization.getFont(),
        x = 10, y = 20,
        fontSize = 20,
    }, { z = 1, preset = "shaded_text" })

Dependencies:
    - command_buffer (C++ binding via Sol2)
    - shader_draw_commands (C++ binding via Sol2)
    - layer (for DrawCommandSpace enum)
    - registry (global ECS registry)

Design:
    - Table-based API with smart defaults
    - Separate props and options tables for clarity
    - Named presets for common render configurations
    - Backwards compatible with existing callback patterns
]]

local draw = {}

-- Localize globals for performance
local command_buffer = _G.command_buffer
local shader_draw_commands = _G.shader_draw_commands
local layer = _G.layer
local registry = _G.registry

--------------------------------------------------------------------------------
-- DEFAULT VALUES
--------------------------------------------------------------------------------
-- Smart defaults for common command types to reduce boilerplate
--------------------------------------------------------------------------------

local DEFAULTS = {
    -- camelCase keys (for draw.textPro, draw.rectangle, etc.)
    textPro = {
        origin = { x = 0, y = 0 },
        rotation = 0,
        fontSize = 16,
        spacing = 1,
        color = WHITE,
    },
    rectangle = {
        color = WHITE,
    },
    texturePro = {
        origin = { x = 0, y = 0 },
        rotation = 0,
        tint = WHITE,
    },
    circleFilled = {},
    line = {},
    rectanglePro = {
        origin = { x = 0, y = 0 },
        rotation = 0,
        color = WHITE,
    },
    rectangleLinesPro = {
        origin = { x = 0, y = 0 },
        rotation = 0,
        color = WHITE,
        lineThick = 1,
    },
    -- snake_case aliases (for draw.local_command command types)
    text_pro = {
        origin = { x = 0, y = 0 },
        rotation = 0,
        fontSize = 16,
        spacing = 1,
        color = WHITE,
    },
    draw_rectangle = {
        color = WHITE,
    },
    texture_pro = {
        origin = { x = 0, y = 0 },
        rotation = 0,
        tint = WHITE,
    },
    draw_circle_filled = {},
    draw_line = {},
    rectangle_pro = {
        origin = { x = 0, y = 0 },
        rotation = 0,
        color = WHITE,
    },
    rectangle_lines_pro = {
        origin = { x = 0, y = 0 },
        rotation = 0,
        color = WHITE,
        lineThick = 1,
    },
}

--------------------------------------------------------------------------------
-- RENDER OPTION PRESETS
--------------------------------------------------------------------------------
-- Named presets for common render configurations (local_command only)
--------------------------------------------------------------------------------

local RENDER_PRESETS = {
    shaded_text = {
        textPass = true,
        uvPassthrough = true,
    },
    sticker = {
        stickerPass = true,
        uvPassthrough = true,
    },
    world = {
        space = layer.DrawCommandSpace.World,
    },
    screen = {
        space = layer.DrawCommandSpace.Screen,
    },
}

--------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
--------------------------------------------------------------------------------

-- Generic wrapper factory for command_buffer.queueXXX functions
-- @param cmdName string - Command name (e.g., "TextPro", "DrawRectangle")
-- @param defaults table - Default values for this command type
-- @return function - Wrapper function with signature (layer, props, z, space)
local function make_queue_wrapper(cmdName, defaults)
    return function(layerObj, props, z, space)
        z = z or 0
        space = space or layer.DrawCommandSpace.Screen

        command_buffer["queue" .. cmdName](layerObj, function(c)
            -- Apply defaults first
            for k, v in pairs(defaults) do
                -- Deep copy for table values (like origin)
                if type(v) == "table" then
                    c[k] = {}
                    for tk, tv in pairs(v) do
                        c[k][tk] = tv
                    end
                else
                    c[k] = v
                end
            end
            -- Apply user props (override defaults)
            for k, v in pairs(props) do
                c[k] = v
            end
        end, z, space)
    end
end

--------------------------------------------------------------------------------
-- PUBLIC API - COMMAND BUFFER WRAPPERS
--------------------------------------------------------------------------------

-- Queue text with advanced controls (font, rotation, origin)
-- @param layerObj Layer - The layer to draw on
-- @param props table - Text properties { text, font, x, y, fontSize?, rotation?, origin?, spacing?, color? }
-- @param z number - Z-index (default: 0)
-- @param space DrawCommandSpace - World or Screen (default: Screen)
draw.textPro = make_queue_wrapper("TextPro", DEFAULTS.textPro)

-- Queue filled rectangle
-- @param layerObj Layer - The layer to draw on
-- @param props table - Rectangle properties { x, y, width, height, color? }
-- @param z number - Z-index (default: 0)
-- @param space DrawCommandSpace - World or Screen (default: Screen)
draw.rectangle = make_queue_wrapper("DrawRectangle", DEFAULTS.rectangle)

-- Queue texture with advanced controls (rotation, origin, source rect)
-- @param layerObj Layer - The layer to draw on
-- @param props table - Texture properties { texture, source, dest, origin?, rotation?, tint? }
-- @param z number - Z-index (default: 0)
-- @param space DrawCommandSpace - World or Screen (default: Screen)
draw.texturePro = make_queue_wrapper("TexturePro", DEFAULTS.texturePro)

-- Queue filled circle
-- @param layerObj Layer - The layer to draw on
-- @param props table - Circle properties { x, y, radius, color? }
-- @param z number - Z-index (default: 0)
-- @param space DrawCommandSpace - World or Screen (default: Screen)
draw.circleFilled = make_queue_wrapper("DrawCircleFilled", DEFAULTS.circleFilled)

-- Queue line
-- @param layerObj Layer - The layer to draw on
-- @param props table - Line properties { startX, startY, endX, endY, color?, thickness? }
-- @param z number - Z-index (default: 0)
-- @param space DrawCommandSpace - World or Screen (default: Screen)
draw.line = make_queue_wrapper("DrawLine", DEFAULTS.line)

-- Queue rectangle with advanced controls (rotation, origin)
-- @param layerObj Layer - The layer to draw on
-- @param props table - Rectangle properties { rect, origin?, rotation?, color? }
-- @param z number - Z-index (default: 0)
-- @param space DrawCommandSpace - World or Screen (default: Screen)
draw.rectanglePro = make_queue_wrapper("DrawRectanglePro", DEFAULTS.rectanglePro)

-- Queue rectangle outline with advanced controls (rotation, origin)
-- @param layerObj Layer - The layer to draw on
-- @param props table - Rectangle properties { rect, origin?, rotation?, lineThick?, color? }
-- @param z number - Z-index (default: 0)
-- @param space DrawCommandSpace - World or Screen (default: Screen)
draw.rectangleLinesPro = make_queue_wrapper("DrawRectangleLinesPro", DEFAULTS.rectangleLinesPro)

--------------------------------------------------------------------------------
-- PUBLIC API - LOCAL COMMAND WRAPPER
--------------------------------------------------------------------------------

-- Add a local draw command to an entity (renders inside its shader pipeline)
-- @param entity userdata - EnTT entity handle
-- @param cmdType string - Command type (e.g., "text_pro", "draw_rect")
-- @param props table - Command properties (varies by cmdType)
-- @param opts table - Render options { z?, space?, textPass?, uvPassthrough?, stickerPass?, preset? }
--   - z: Z-index relative to sprite (negative = before, non-negative = after)
--   - space: DrawCommandSpace.World or DrawCommandSpace.Screen
--   - textPass: Force text pass rendering
--   - uvPassthrough: Disable UV remapping (useful for 3d_skew shaders)
--   - stickerPass: Force sticker pass rendering
--   - preset: Named preset ("shaded_text", "sticker", "world", "screen")
function draw.local_command(entity, cmdType, props, opts)
    opts = opts or {}

    -- Apply preset if specified
    if opts.preset and RENDER_PRESETS[opts.preset] then
        local preset = RENDER_PRESETS[opts.preset]
        for k, v in pairs(preset) do
            if opts[k] == nil then
                opts[k] = v
            end
        end
    end

    -- Extract render options with defaults
    local z = opts.z or 0
    local space = opts.space or layer.DrawCommandSpace.Screen
    local textPass = opts.textPass or false
    local uvPassthrough = opts.uvPassthrough or false
    local stickerPass = opts.stickerPass or false

    -- Get defaults for this command type
    local defaults = DEFAULTS[cmdType] or {}

    shader_draw_commands.add_local_command(
        registry,
        entity,
        cmdType,
        function(c)
            -- Apply defaults first
            for k, v in pairs(defaults) do
                -- Deep copy for table values
                if type(v) == "table" then
                    c[k] = {}
                    for tk, tv in pairs(v) do
                        c[k][tk] = tv
                    end
                else
                    c[k] = v
                end
            end
            -- Apply user props (override defaults)
            for k, v in pairs(props) do
                c[k] = v
            end
        end,
        z,
        space,
        textPass,
        uvPassthrough,
        stickerPass
    )
end

-- Get available render presets (read-only access)
-- Useful for introspection and tooling
-- @return table - Copy of the render presets registry
function draw.get_presets()
    local copy = {}
    for name, config in pairs(RENDER_PRESETS) do
        copy[name] = {}
        for k, v in pairs(config) do
            copy[name][k] = v
        end
    end
    return copy
end

-- Register a new render preset or extend an existing one
-- Useful for mods or dynamic preset registration
-- @param name string - Preset name (e.g., "my_custom_preset")
-- @param config table - Preset configuration { textPass?, uvPassthrough?, stickerPass?, space? }
function draw.register_preset(name, config)
    RENDER_PRESETS[name] = {
        textPass = config.textPass or false,
        uvPassthrough = config.uvPassthrough or false,
        stickerPass = config.stickerPass or false,
        space = config.space,
    }
end

-- Get default values for a command type
-- Useful for debugging and documentation
-- @param cmdType string - Command type name
-- @return table|nil - Copy of defaults, or nil if no defaults defined
function draw.get_defaults(cmdType)
    local defaults = DEFAULTS[cmdType]
    if not defaults then return nil end

    local copy = {}
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            copy[k] = {}
            for tk, tv in pairs(v) do
                copy[k][tk] = tv
            end
        else
            copy[k] = v
        end
    end
    return copy
end

return draw
