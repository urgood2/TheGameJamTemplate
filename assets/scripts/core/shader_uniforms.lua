-- Lua port scaffold for shader uniform initialization.
-- Mirrors the logic in C++ SetUpShaderUniforms so we can move the setup into Lua.
-- NOTE: Not yet invoked from main.lua; wire it in after parity is reached.

local shader_uniforms = {}

local set = function(shader, name, value)
    globalShaderUniforms:set(shader, name, value)
end

local register = function(shader, fn)
    shaders.registerUniformUpdate(shader, fn)
end

local get_time = GetTime
local get_mouse = function()
    return input.getMousePos()
end

local function init_tile_grid_overlay()
    local info = getSpriteFrameTextureInfo("tile-grid-boundary.png")
    if not info then
        log_error("tile_grid_overlay: atlas/texture not found for tile-grid-boundary.png")
        return
    end

    register("tile_grid_overlay", function(_shader)
        set("tile_grid_overlay", "mouse_position", get_mouse())
        set("tile_grid_overlay", "atlas", info.atlas)
    end)

    local desiredCellSize = 64.0
    local scale = 1.0 / desiredCellSize

    set("tile_grid_overlay", "uImageSize", info.imageSize)
    set("tile_grid_overlay", "uGridRect", info.gridRect)
    set("tile_grid_overlay", "scale", scale)
    set("tile_grid_overlay", "base_opacity", 0.0)
    set("tile_grid_overlay", "highlight_opacity", 0.4)
    set("tile_grid_overlay", "distance_scaling", 100.0)
end

local function init_palette()
    -- Matches the existing C++ call to palette_quantizer::setPaletteTexture.
    setPaletteTexture("palette_quantize", "graphics/palettes/resurrect-64-1x.png")
end

local function init_static_defaults()
    local VW, VH = globals.screenWidth(), globals.screenHeight()
    local VIRTUAL_W, VIRTUAL_H = VW, VH

    -- custom_polychrome
    set("custom_polychrome", "stripeFreq", 0.3)
    set("custom_polychrome", "waveFreq", 2.0)
    set("custom_polychrome", "waveAmp", 0.4)
    set("custom_polychrome", "waveSpeed", 0.1)
    set("custom_polychrome", "stripeWidth", 1.0)
    set("custom_polychrome", "polychrome", Vector2{ x = 0.0, y = 0.1 })

    -- spotlight
    set("spotlight", "screen_width", VIRTUAL_W)
    set("spotlight", "screen_height", VIRTUAL_H)
    set("spotlight", "circle_size", 0.5)
    set("spotlight", "feather", 0.05)
    set("spotlight", "circle_position", Vector2{ x = 0.5, y = 0.5 })

    -- random_displacement_anim
    set("random_displacement_anim", "interval", 0.5)
    set("random_displacement_anim", "timeDelay", 1.4)
    set("random_displacement_anim", "intensityX", 4.0)
    set("random_displacement_anim", "intensityY", 4.0)
    set("random_displacement_anim", "seed", 42.0)

    -- pixelate_image
    set("pixelate_image", "texSize", Vector2{ x = VW, y = VH })
    set("pixelate_image", "pixelRatio", 0.9)

    -- outer_space_donuts_bg
    set("outer_space_donuts_bg", "iResolution", Vector2{ x = VIRTUAL_W, y = VIRTUAL_H })
    set("outer_space_donuts_bg", "grayAmount", 0.77)
    set("outer_space_donuts_bg", "desaturateAmount ", 2.87)
    set("outer_space_donuts_bg", "speedFactor", 0.61)
    set("outer_space_donuts_bg", "u_brightness", 0.17)
    set("outer_space_donuts_bg", "u_noisiness", 0.22)
    set("outer_space_donuts_bg", "u_hueOffset", 0.0)
    set("outer_space_donuts_bg", "u_donutWidth", -2.77)
    set("outer_space_donuts_bg", "pixel_filter", 150.0)

    -- screen_tone_transition
    set("screen_tone_transition", "in_out", 0.0)
    set("screen_tone_transition", "position", 0.0)
    set("screen_tone_transition", "size", Vector2{ x = 32.0, y = 32.0 })
    set("screen_tone_transition", "screen_pixel_size", Vector2{ x = 1.0 / VIRTUAL_W, y = 1.0 / VIRTUAL_H })
    set("screen_tone_transition", "in_color", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 1.0 })
    set("screen_tone_transition", "out_color", Vector4{ x = 1.0, y = 1.0, z = 1.0, w = 1.0 })

    -- balatro_background
    set("balatro_background", "texelSize", Vector2{ x = 1.0 / VIRTUAL_W, y = 1.0 / VIRTUAL_H })
    set("balatro_background", "polar_coordinates", 0.0)
    set("balatro_background", "polar_center", Vector2{ x = 0.5, y = 0.5 })
    set("balatro_background", "polar_zoom", 4.52)
    set("balatro_background", "polar_repeat", 2.91)
    set("balatro_background", "spin_rotation", 7.0205107)
    set("balatro_background", "spin_speed", 6.8)
    set("balatro_background", "offset", Vector2{ x = 0.0, y = 0.0 })
    set("balatro_background", "contrast", 4.43)
    set("balatro_background", "spin_amount", -0.09)
    set("balatro_background", "pixel_filter", 300.0)
    set("balatro_background", "colour_1", Vector4{ x = 0.020128006, y = 0.0139369555, z = 0.049019635, w = 1.0 })
    set("balatro_background", "colour_2", Vector4{ x = 0.029411793, y = 1.0, z = 0.0, w = 1.0 })
    set("balatro_background", "colour_3", Vector4{ x = 1.0, y = 1.0, z = 1.0, w = 1.0 })

    -- crt
    set("crt", "resolution", Vector2{ x = VIRTUAL_W, y = VIRTUAL_H })
    set("crt", "roll_speed", 1.49)
    set("crt", "resolution", Vector2{ x = 1280.0, y = 700.0 })
    set("crt", "noise_amount", 0.0)
    set("crt", "scan_line_amount", -0.17)
    set("crt", "grille_amount", 0.37)
    set("crt", "scan_line_strength", -3.78)
    set("crt", "pixel_strength", 0.1)
    set("crt", "vignette_amount", 1.41)
    set("crt", "warp_amount", 0.06)
    set("crt", "interference_amount", 0.0)
    set("crt", "roll_line_amount", 0.12)
    set("crt", "grille_size", 0.51)
    set("crt", "vignette_intensity", 0.10)
    set("crt", "iTime", 113.47279)
    set("crt", "aberation_amount", 0.93)
    set("crt", "enable_rgb_scanlines", 1.0)
    set("crt", "enable_dark_scanlines", 1.0)
    set("crt", "scanline_density", 200.0)
    set("crt", "scanline_intensity", 0.10)
    set("crt", "enable_bloom", 1.0)
    set("crt", "bloom_strength", 0.19)
    set("crt", "bloom_radius", 4.0)
    set("crt", "glitch_strength", 0.02)
    set("crt", "glitch_speed", 3.0)
    set("crt", "glitch_density", 180.0)

    -- shockwave
    set("shockwave", "resolution", Vector2{ x = VIRTUAL_W, y = VIRTUAL_H })
    set("shockwave", "strength", 0.18)
    set("shockwave", "center", Vector2{ x = 0.5, y = 0.5 })
    set("shockwave", "radius", 1.93)
    set("shockwave", "aberration", -2.115)
    set("shockwave", "width", 0.28)
    set("shockwave", "feather", 0.415)

    -- glitch
    set("glitch", "resolution", Vector2{ x = VIRTUAL_W, y = VIRTUAL_H })
    set("glitch", "shake_power", 0.03)
    set("glitch", "shake_rate", 0.2)
    set("glitch", "shake_speed", 5.0)
    set("glitch", "shake_block_size", 30.5)
    set("glitch", "shake_color_rate", 0.01)

    -- wind
    set("wind", "speed", 1.0)
    set("wind", "minStrength", 0.05)
    set("wind", "maxStrength", 0.1)
    set("wind", "strengthScale", 100.0)
    set("wind", "interval", 3.5)
    set("wind", "detail", 2.0)
    set("wind", "distortion", 1.0)
    set("wind", "heightOffset", 0.0)
    set("wind", "offset", 1.0)

    -- fade_zoom transition
    set("fade_zoom", "progress", 0.0)
    set("fade_zoom", "zoom_strength", 0.2)
    set("fade_zoom", "fade_color", Vector3{ x = 0.0, y = 0.0, z = 0.0 })

    -- slide_fade transition
    set("fade", "progress", 0.0)
    set("fade", "slide_direction", Vector2{ x = 1.0, y = 0.0 })
    set("fade", "fade_color", Vector3{ x = 0.0, y = 0.0, z = 0.0 })

    -- Additional shader defaults still need to be ported from C++.
    -- Refer to src/core/misc_functions.cpp for the remaining uniforms.
end

local function init_updates()
    register("custom_polychrome", function(_shader)
        set("custom_polychrome", "time", get_time())
    end)

    register("random_displacement_anim", function(_shader)
        set("random_displacement_anim", "iTime", get_time())
    end)

    register("outer_space_donuts_bg", function(_shader)
        set("outer_space_donuts_bg", "iTime", get_time())
    end)

    register("flash", function(_shader)
        set("flash", "iTime", get_time())
    end)

    register("balatro_background", function(_shader)
        local t = get_time()
        set("balatro_background", "iTime", t)
        set("balatro_background", "spin_rotation", math.sin(t * 0.01) * 13.0)
    end)

    register("crt", function(_shader)
        set("crt", "iTime", get_time())
    end)

    register("glitch", function(_shader)
        set("glitch", "iTime", get_time())
    end)

    register("wind", function(_shader)
        set("wind", "iTime", get_time())
    end)

    register("fade_zoom", function(_shader)
        set("fade_zoom", "time", get_time())
    end)

    register("fade", function(_shader)
        set("fade", "time", get_time())
    end)
end

function shader_uniforms.init()
    init_static_defaults()
    init_tile_grid_overlay()
    init_palette()
    init_updates()
end

return shader_uniforms
