-- Lua port scaffold for shader uniform initialization.
-- Mirrors the logic in C++ SetUpShaderUniforms so we can move the setup into Lua.
-- NOTE: Not yet invoked from main.lua; wire it in after parity is reached.

local shader_uniforms = {}

-- Simple constructors to mimic the C++ Vector2/3/4 usage.
-- Delegate to the engine-provided global constructors so we get real userdata,
-- but still accept plain tables in case we ever call these before globals are set.
local function Vector2(val, y)
    if _G.Vector2 then
        return _G.Vector2(val, y)
    end
    if type(val) == "table" then
        return { x = val.x or val[1] or 0.0, y = val.y or val[2] or 0.0 }
    end
    return { x = val or 0.0, y = y or 0.0 }
end

local function Vector3(val, y, z)
    if _G.Vector3 then
        return _G.Vector3(val, y, z)
    end
    if type(val) == "table" then
        return { x = val.x or val[1] or 0.0, y = val.y or val[2] or 0.0, z = val.z or val[3] or 0.0 }
    end
    return { x = val or 0.0, y = y or 0.0, z = z or 0.0 }
end

local function Vector4(val, y, z, w)
    if _G.Vector4 then
        return _G.Vector4(val, y, z, w)
    end
    if type(val) == "table" then
        return { x = val.x or val[1] or 0.0, y = val.y or val[2] or 0.0, z = val.z or val[3] or 0.0, w = val.w or val[4] or 0.0 }
    end
    return { x = val or 0.0, y = y or 0.0, z = z or 0.0, w = w or 0.0 }
end

-- Approximate normalized Raylib colors (0-1) to replace ColorNormalize.
local COLOR_BLUE_N    = { x = 0.0,       y = 121/255, z = 241/255, w = 1.0 }
local COLOR_PURPLE_N  = { x = 200/255,   y = 122/255, z = 255/255, w = 1.0 }
local COLOR_SKYBLUE_N = { x = 102/255,   y = 191/255, z = 255/255, w = 1.0 }
local COLOR_PINK_N    = { x = 255/255,   y = 109/255, z = 194/255, w = 1.0 }
local COLOR_RED_N     = { x = 230/255,   y = 41/255,  z = 55/255,  w = 1.0 }
local COLOR_ORANGE_N  = { x = 255/255,   y = 161/255, z = 0.0,     w = 1.0 }

local function normalize_value(value)
    if type(value) == "userdata" then
        return value
    end
    if type(value) == "table" then
        if value.x and value.y and value.z and value.w then
            return Vector4(value)
        elseif value.x and value.y and value.z then
            return Vector3(value)
        elseif value.x and value.y then
            return Vector2(value)
        end
    end
    return value
end

local set = function(shader, name, value)
    globalShaderUniforms:set(shader, name, normalize_value(value))
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

    -- vacuum_collapse
    set("vacuum_collapse", "burst_progress", 0.0)
    set("vacuum_collapse", "spread_strength", 1.0)
    set("vacuum_collapse", "distortion_strength", 0.05)
    set("vacuum_collapse", "fade_start", 0.7)

    -- fireworks
    set("fireworks", "uGridRect", Vector4{ x = 0, y = 0, z = 1, w = 1 })
    set("fireworks", "uImageSize", Vector2{ x = VW, y = VH })
    set("fireworks", "Praticle_num", 30)
    set("fireworks", "TimeStep", 2)
    set("fireworks", "s77", 0.90)
    set("fireworks", "Range", 0.75)
    set("fireworks", "s55", 0.16)
    set("fireworks", "gravity", 0.50)
    set("fireworks", "ShneyMagnitude", 1.00)
    set("fireworks", "s33", 0.13)
    set("fireworks", "iTime", 0.0)
    set("fireworks", "s99", 6.50)
    set("fireworks", "s11", 0.80)
    set("fireworks", "speed", 2.00)

    -- starry_tunnel
    set("starry_tunnel", "m", 12)
    set("starry_tunnel", "n", 40)
    set("starry_tunnel", "hasNeonEffect", true)
    set("starry_tunnel", "hasDot", false)
    set("starry_tunnel", "haszExpend", false)
    set("starry_tunnel", "theta", 20.0)
    set("starry_tunnel", "addH", 5.0)
    set("starry_tunnel", "scale", 0.05)
    set("starry_tunnel", "light_disperse", 4.0)
    set("starry_tunnel", "stertch", 30.0)
    set("starry_tunnel", "speed", 30.0)
    set("starry_tunnel", "modTime", 20.0)
    set("starry_tunnel", "rotate_speed", 3.0)
    set("starry_tunnel", "rotate_plane_speed", 1.0)
    set("starry_tunnel", "theta_sine_change_speed", 0.0)
    set("starry_tunnel", "iswhite", false)
    set("starry_tunnel", "isdarktotransparent", false)
    set("starry_tunnel", "bemask", false)
    set("starry_tunnel", "debugMode", 0)

    -- item_glow
    set("item_glow", "glow_color", Vector4{ x = 1.0, y = 0.9, z = 0.5, w = 0.10 })
    set("item_glow", "intensity", 1.5)
    set("item_glow", "spread", 1.0)
    set("item_glow", "pulse_speed", 1.0)

    -- efficient_pixel_outline
    set("efficient_pixel_outline", "uGridRect", Vector4{ x = 0, y = 0, z = 1, w = 1 })
    set("efficient_pixel_outline", "uImageSize", Vector2{ x = VW, y = VH })
    set("efficient_pixel_outline", "outlineColor", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 1.0 })
    set("efficient_pixel_outline", "outlineType", 2)
    set("efficient_pixel_outline", "thickness", 1.0)

    -- atlas_outline
    set("atlas_outline", "uGridRect", Vector4{ x = 0, y = 0, z = 1, w = 1 })
    set("atlas_outline", "uImageSize", Vector2{ x = VW, y = VH })
    set("atlas_outline", "outlineWidth", 1.0)
    set("atlas_outline", "outlineColor", Vector4{ x = 1.0, y = 1.0, z = 1.0, w = 1.0 })

    -- pixel_perfect_dissolving
    set("pixel_perfect_dissolving", "uGridRect", Vector4{ x = 0, y = 0, z = 1, w = 1 })
    set("pixel_perfect_dissolving", "uImageSize", Vector2{ x = VW, y = VH })
    set("pixel_perfect_dissolving", "sensitivity", 0.5)

    -- dissolve_with_burn_edge
    set("dissolve_with_burn_edge", "uGridRect", Vector4{ x = 0, y = 0, z = 1, w = 1 })
    set("dissolve_with_burn_edge", "uImageSize", Vector2{ x = VW, y = VH })
    set("dissolve_with_burn_edge", "burn_size", 0.5)
    set("dissolve_with_burn_edge", "burn_color", Vector4{ x = 1.0, y = 0.5, z = 0.0, w = 1.0 })
    set("dissolve_with_burn_edge", "dissolve_amount", 0.0)

    -- burn_2d
    set("burn_2d", "uGridRect", Vector4{ x = 0, y = 0, z = 1, w = 1 })
    set("burn_2d", "uImageSize", Vector2{ x = VW, y = VH })
    set("burn_2d", "ashColor", Vector4{ x = 0.2, y = 0.2, z = 0.2, w = 1.0 })
    set("burn_2d", "burnColor", Vector4{ x = 1.0, y = 0.3, z = 0.0, w = 1.0 })
    set("burn_2d", "proBurnColor", Vector4{ x = 1.0, y = 1.0, z = 0.0, w = 1.0 })
    set("burn_2d", "burn_amount", 0.0)

    -- hologram_2d
    set("hologram_2d", "uGridRect", Vector4{ x = 0, y = 0, z = 1, w = 1 })
    set("hologram_2d", "uImageSize", Vector2{ x = VW, y = VH })
    set("hologram_2d", "strength", 0.3)
    set("hologram_2d", "offset", 0.1)
    set("hologram_2d", "scan_line_amount", 1.0)
    set("hologram_2d", "warp_amount", 0.1)

    -- liquid_effects
    set("liquid_effects", "uGridRect", Vector4{ x = 0, y = 0, z = 1, w = 1 })
    set("liquid_effects", "uImageSize", Vector2{ x = VW, y = VH })
    set("liquid_effects", "amplitude", 0.05)
    set("liquid_effects", "frequency", 10.0)
    set("liquid_effects", "speed", 2.0)

    -- liquid_fill_sphere
    set("liquid_fill_sphere", "uGridRect", Vector4{ x = 0, y = 0, z = 1, w = 1 })
    set("liquid_fill_sphere", "uImageSize", Vector2{ x = VW, y = VH })
    set("liquid_fill_sphere", "fill_amount", 0.5)
    set("liquid_fill_sphere", "liquid_color", Vector4{ x = 0.0, y = 0.5, z = 1.0, w = 0.8 })

    -- pixel_art_trail
    set("pixel_art_trail", "uGridRect", Vector4{ x = 0, y = 0, z = 1, w = 1 })
    set("pixel_art_trail", "uImageSize", Vector2{ x = VW, y = VH })
    set("pixel_art_trail", "trail_length", 5.0)
    set("pixel_art_trail", "trail_color", Vector4{ x = 1.0, y = 1.0, z = 1.0, w = 0.5 })

    -- animated_dotted_outline
    set("animated_dotted_outline", "uGridRect", Vector4{ x = 0, y = 0, z = 1, w = 1 })
    set("animated_dotted_outline", "uImageSize", Vector2{ x = VW, y = VH })
    set("animated_dotted_outline", "line_color", Vector4{ x = 1.0, y = 1.0, z = 1.0, w = 1.0 })
    set("animated_dotted_outline", "line_thickness", 1.0)
    set("animated_dotted_outline", "frequency", 10.0)

    -- colorful_outline
    set("colorful_outline", "uGridRect", Vector4{ x = 0, y = 0, z = 1, w = 1 })
    set("colorful_outline", "uImageSize", Vector2{ x = VW, y = VH })
    set("colorful_outline", "intensity", 50)
    set("colorful_outline", "precision", 0.01)
    set("colorful_outline", "outline_color", Vector4{ x = 1.0, y = 0.0, z = 1.0, w = 1.0 })
    set("colorful_outline", "outline_color_2", Vector4{ x = 0.0, y = 1.0, z = 1.0, w = 1.0 })

    -- dynamic_glow
    set("dynamic_glow", "uGridRect", Vector4{ x = 0, y = 0, z = 1, w = 1 })
    set("dynamic_glow", "uImageSize", Vector2{ x = VW, y = VH })
    set("dynamic_glow", "glow_strength", 2.0)
    set("dynamic_glow", "glow_color", Vector4{ x = 1.0, y = 0.5, z = 0.0, w = 1.0 })

    -- wobbly
    set("wobbly", "uGridRect", Vector4{ x = 0, y = 0, z = 1, w = 1 })
    set("wobbly", "uImageSize", Vector2{ x = VW, y = VH })
    set("wobbly", "amplitude", 0.02)
    set("wobbly", "frequency", 5.0)
    set("wobbly", "alpha_tresh", 0.8)
    set("wobbly", "shrink", 2.0)
    set("wobbly", "offset_mul", 2.0)
    set("wobbly", "coff_angle", 0.0)
    set("wobbly", "coff_mul", 0.5)
    set("wobbly", "coff_std", 0.2)
    set("wobbly", "amp1", 0.125)
    set("wobbly", "freq1", 4.0)
    set("wobbly", "speed1", 5.0)
    set("wobbly", "amp2", 0.125)
    set("wobbly", "freq2", 9.0)
    set("wobbly", "speed2", 1.46)

    -- bounce_wave
    set("bounce_wave", "uGridRect", Vector4{ x = 0, y = 0, z = 1, w = 1 })
    set("bounce_wave", "uImageSize", Vector2{ x = VW, y = VH })
    set("bounce_wave", "amplitude", 10.0)
    set("bounce_wave", "frequency", 5.0)
    set("bounce_wave", "quantization", 8.0)

    -- radial_fire_2d
    set("radial_fire_2d", "uGridRect", Vector4{ x = 0, y = 0, z = 1, w = 1 })
    set("radial_fire_2d", "uImageSize", Vector2{ x = VW, y = VH })
    set("radial_fire_2d", "fire_intensity", 1.0)

    -- radial_shine_2d
    set("radial_shine_2d", "uGridRect", Vector4{ x = 0, y = 0, z = 1, w = 1 })
    set("radial_shine_2d", "uImageSize", Vector2{ x = VW, y = VH })
    set("radial_shine_2d", "shine_color", Vector4{ x = 1.0, y = 1.0, z = 1.0, w = 1.0 })
    set("radial_shine_2d", "shine_strength", 1.0)
    set("radial_shine_2d", "center", Vector2{ x = 0.5, y = 0.5 })
    set("radial_shine_2d", "shine_speed", 1.0)
    set("radial_shine_2d", "shine_width", 0.1)

    -- holographic_card
    set("holographic_card", "uGridRect", Vector4{ x = 0, y = 0, z = 1, w = 1 })
    set("holographic_card", "uImageSize", Vector2{ x = VW, y = VH })
    set("holographic_card", "rotation", 0.0)
    set("holographic_card", "perspective_strength", 0.3)

    -- 3d_skew
    set("3d_skew", "fov", -0.39)
    set("3d_skew", "x_rot", 0.0)
    set("3d_skew", "y_rot", 0.0)
    set("3d_skew", "inset", 0.0)
    set("3d_skew", "hovering", 0.3)
    set("3d_skew", "rand_trans_power", 0.4)
    set("3d_skew", "rand_seed", 3.1415)
    set("3d_skew", "rotation", 0.0)
    set("3d_skew", "cull_back", 0.0)
    set("3d_skew", "tilt_enabled", 0.0)
    set("3d_skew", "regionRate", Vector2{ x = 1.0, y = 1.0 })
    set("3d_skew", "pivot", Vector2{ x = 0.0, y = 0.0 })
    set("3d_skew", "quad_center", Vector2{ x = 0.0, y = 0.0 })
    set("3d_skew", "quad_size", Vector2{ x = 1.0, y = 1.0 })
    set("3d_skew", "uv_passthrough", 0.0)
    set("3d_skew", "uGridRect", Vector4{ x = 0.0, y = 0.0, z = 1.0, w = 1.0 })
    set("3d_skew", "uImageSize", Vector2{ x = VIRTUAL_W, y = VIRTUAL_H })
    set("3d_skew", "texture_details", Vector4{ x = 0.0, y = 0.0, z = 64.0, w = 64.0 })
    set("3d_skew", "image_details", Vector2{ x = 65.15, y = 64.0 })
    set("3d_skew", "dissolve", 0.0)
    set("3d_skew", "shadow", 0.0)
    set("3d_skew", "burn_colour_1", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 0.0 })
    set("3d_skew", "burn_colour_2", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 0.0 })
    set("3d_skew", "card_rotation", 0.0)
    set("3d_skew", "material_tint", Vector3{ x = 1.0, y = 1.0, z = 1.0 })
    set("3d_skew", "grain_intensity", -1.95)
    set("3d_skew", "grain_scale", -2.21)
    set("3d_skew", "sheen_strength", -1.49)
    set("3d_skew", "sheen_width", 2.22)
    set("3d_skew", "sheen_speed", 2.3)
    set("3d_skew", "noise_amount", 1.12)
    -- Dissolve defaults aligned to the Godot reference.
    set("3d_skew", "spread_strength", 1.0)
    set("3d_skew", "distortion_strength", 0.05)
    set("3d_skew", "fade_start", 0.7)
    set("3d_skew", "time", get_time())

    -- 3d_skew_hologram (shares the same base params; overlay effect differs in shader)
    set("3d_skew_hologram", "fov", -0.39)
    set("3d_skew_hologram", "x_rot", 0.0)
    set("3d_skew_hologram", "y_rot", 0.0)
    set("3d_skew_hologram", "inset", 0.0)
    set("3d_skew_hologram", "hovering", 0.3)
    set("3d_skew_hologram", "rand_trans_power", 0.4)
    set("3d_skew_hologram", "rand_seed", 3.1415)
    set("3d_skew_hologram", "rotation", 0.0)
    set("3d_skew_hologram", "cull_back", 0.0)
    set("3d_skew_hologram", "tilt_enabled", 0.0)
    set("3d_skew_hologram", "regionRate", Vector2{ x = 1.0, y = 1.0 })
    set("3d_skew_hologram", "pivot", Vector2{ x = 0.0, y = 0.0 })
    set("3d_skew_hologram", "quad_center", Vector2{ x = 0.0, y = 0.0 })
    set("3d_skew_hologram", "quad_size", Vector2{ x = 1.0, y = 1.0 })
    set("3d_skew_hologram", "uv_passthrough", 0.0)
    set("3d_skew_hologram", "uGridRect", Vector4{ x = 0.0, y = 0.0, z = 1.0, w = 1.0 })
    set("3d_skew_hologram", "uImageSize", Vector2{ x = VIRTUAL_W, y = VIRTUAL_H })
    set("3d_skew_hologram", "texture_details", Vector4{ x = 0.0, y = 0.0, z = 64.0, w = 64.0 })
    set("3d_skew_hologram", "image_details", Vector2{ x = 65.15, y = 64.0 })
    set("3d_skew_hologram", "dissolve", 0.0)
    set("3d_skew_hologram", "shadow", 0.0)
    set("3d_skew_hologram", "burn_colour_1", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 0.0 })
    set("3d_skew_hologram", "burn_colour_2", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 0.0 })
    set("3d_skew_hologram", "card_rotation", 0.0)
    set("3d_skew_hologram", "material_tint", Vector3{ x = 1.0, y = 1.0, z = 1.0 })
    set("3d_skew_hologram", "grain_intensity", -1.95)
    set("3d_skew_hologram", "grain_scale", -2.21)
    set("3d_skew_hologram", "sheen_strength", -1.49)
    set("3d_skew_hologram", "sheen_width", 2.22)
    set("3d_skew_hologram", "sheen_speed", 2.3)
    set("3d_skew_hologram", "noise_amount", 1.12)
    set("3d_skew_hologram", "spread_strength", 1.0)
    set("3d_skew_hologram", "distortion_strength", 0.05)
    set("3d_skew_hologram", "fade_start", 0.7)
    set("3d_skew_hologram", "time", get_time())

    -- 3d_skew_polychrome (polychrome hue shift replaces sheen)
    set("3d_skew_polychrome", "fov", -0.39)
    set("3d_skew_polychrome", "x_rot", 0.0)
    set("3d_skew_polychrome", "y_rot", 0.0)
    set("3d_skew_polychrome", "inset", 0.0)
    set("3d_skew_polychrome", "hovering", 0.3)
    set("3d_skew_polychrome", "rand_trans_power", 0.4)
    set("3d_skew_polychrome", "rand_seed", 3.1415)
    set("3d_skew_polychrome", "rotation", 0.0)
    set("3d_skew_polychrome", "cull_back", 0.0)
    set("3d_skew_polychrome", "tilt_enabled", 0.0)
    set("3d_skew_polychrome", "regionRate", Vector2{ x = 1.0, y = 1.0 })
    set("3d_skew_polychrome", "pivot", Vector2{ x = 0.0, y = 0.0 })
    set("3d_skew_polychrome", "quad_center", Vector2{ x = 0.0, y = 0.0 })
    set("3d_skew_polychrome", "quad_size", Vector2{ x = 1.0, y = 1.0 })
    set("3d_skew_polychrome", "uv_passthrough", 0.0)
    set("3d_skew_polychrome", "uGridRect", Vector4{ x = 0.0, y = 0.0, z = 1.0, w = 1.0 })
    set("3d_skew_polychrome", "uImageSize", Vector2{ x = VIRTUAL_W, y = VIRTUAL_H })
    set("3d_skew_polychrome", "texture_details", Vector4{ x = 0.0, y = 0.0, z = 64.0, w = 64.0 })
    set("3d_skew_polychrome", "image_details", Vector2{ x = 65.15, y = 64.0 })
    set("3d_skew_polychrome", "dissolve", 0.0)
    set("3d_skew_polychrome", "shadow", 0.0)
    set("3d_skew_polychrome", "burn_colour_1", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 0.0 })
    set("3d_skew_polychrome", "burn_colour_2", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 0.0 })
    set("3d_skew_polychrome", "card_rotation", 0.0)
    set("3d_skew_polychrome", "material_tint", Vector3{ x = 1.0, y = 1.0, z = 1.0 })
    set("3d_skew_polychrome", "grain_intensity", -1.95)
    set("3d_skew_polychrome", "grain_scale", -2.21)
    set("3d_skew_polychrome", "sheen_strength", -1.49)
    set("3d_skew_polychrome", "sheen_width", 2.22)
    set("3d_skew_polychrome", "sheen_speed", 2.3)
    set("3d_skew_polychrome", "noise_amount", 1.12)
    set("3d_skew_polychrome", "spread_strength", 1.0)
    set("3d_skew_polychrome", "distortion_strength", 0.05)
    set("3d_skew_polychrome", "fade_start", 0.7)
    set("3d_skew_polychrome", "polychrome", Vector2{ x = 0.65, y = 0.25 })
    set("3d_skew_polychrome", "time", get_time())

    -- 3d_skew_foil (foil overlay effect)
    set("3d_skew_foil", "fov", -0.39)
    set("3d_skew_foil", "x_rot", 0.0)
    set("3d_skew_foil", "y_rot", 0.0)
    set("3d_skew_foil", "inset", 0.0)
    set("3d_skew_foil", "hovering", 0.3)
    set("3d_skew_foil", "rand_trans_power", 0.4)
    set("3d_skew_foil", "rand_seed", 3.1415)
    set("3d_skew_foil", "rotation", 0.0)
    set("3d_skew_foil", "cull_back", 0.0)
    set("3d_skew_foil", "tilt_enabled", 0.0)
    set("3d_skew_foil", "regionRate", Vector2{ x = 1.0, y = 1.0 })
    set("3d_skew_foil", "pivot", Vector2{ x = 0.0, y = 0.0 })
    set("3d_skew_foil", "quad_center", Vector2{ x = 0.0, y = 0.0 })
    set("3d_skew_foil", "quad_size", Vector2{ x = 1.0, y = 1.0 })
    set("3d_skew_foil", "uv_passthrough", 0.0)
    set("3d_skew_foil", "uGridRect", Vector4{ x = 0.0, y = 0.0, z = 1.0, w = 1.0 })
    set("3d_skew_foil", "uImageSize", Vector2{ x = VIRTUAL_W, y = VIRTUAL_H })
    set("3d_skew_foil", "texture_details", Vector4{ x = 0.0, y = 0.0, z = 64.0, w = 64.0 })
    set("3d_skew_foil", "image_details", Vector2{ x = 65.15, y = 64.0 })
    set("3d_skew_foil", "dissolve", 0.0)
    set("3d_skew_foil", "shadow", 0.0)
    set("3d_skew_foil", "burn_colour_1", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 0.0 })
    set("3d_skew_foil", "burn_colour_2", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 0.0 })
    set("3d_skew_foil", "card_rotation", 0.0)
    set("3d_skew_foil", "material_tint", Vector3{ x = 1.0, y = 1.0, z = 1.0 })
    set("3d_skew_foil", "grain_intensity", -1.95)
    set("3d_skew_foil", "grain_scale", -2.21)
    set("3d_skew_foil", "sheen_strength", -1.49)
    set("3d_skew_foil", "sheen_width", 2.22)
    set("3d_skew_foil", "sheen_speed", 2.3)
    set("3d_skew_foil", "noise_amount", 1.12)
    set("3d_skew_foil", "spread_strength", 1.0)
    set("3d_skew_foil", "distortion_strength", 0.05)
    set("3d_skew_foil", "fade_start", 0.7)
    set("3d_skew_foil", "foil", Vector2{ x = 0.65, y = 0.25 })
    set("3d_skew_foil", "time", get_time())

    -- 3d_skew_negative_shine
    set("3d_skew_negative_shine", "fov", -0.39)
    set("3d_skew_negative_shine", "x_rot", 0.0)
    set("3d_skew_negative_shine", "y_rot", 0.0)
    set("3d_skew_negative_shine", "inset", 0.0)
    set("3d_skew_negative_shine", "hovering", 0.3)
    set("3d_skew_negative_shine", "rand_trans_power", 0.4)
    set("3d_skew_negative_shine", "rand_seed", 3.1415)
    set("3d_skew_negative_shine", "rotation", 0.0)
    set("3d_skew_negative_shine", "cull_back", 0.0)
    set("3d_skew_negative_shine", "tilt_enabled", 0.0)
    set("3d_skew_negative_shine", "regionRate", Vector2{ x = 1.0, y = 1.0 })
    set("3d_skew_negative_shine", "pivot", Vector2{ x = 0.0, y = 0.0 })
    set("3d_skew_negative_shine", "quad_center", Vector2{ x = 0.0, y = 0.0 })
    set("3d_skew_negative_shine", "quad_size", Vector2{ x = 1.0, y = 1.0 })
    set("3d_skew_negative_shine", "uv_passthrough", 0.0)
    set("3d_skew_negative_shine", "uGridRect", Vector4{ x = 0.0, y = 0.0, z = 1.0, w = 1.0 })
    set("3d_skew_negative_shine", "uImageSize", Vector2{ x = VIRTUAL_W, y = VIRTUAL_H })
    set("3d_skew_negative_shine", "texture_details", Vector4{ x = 0.0, y = 0.0, z = 64.0, w = 64.0 })
    set("3d_skew_negative_shine", "image_details", Vector2{ x = 65.15, y = 64.0 })
    set("3d_skew_negative_shine", "dissolve", 0.0)
    set("3d_skew_negative_shine", "shadow", 0.0)
    set("3d_skew_negative_shine", "burn_colour_1", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 0.0 })
    set("3d_skew_negative_shine", "burn_colour_2", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 0.0 })
    set("3d_skew_negative_shine", "card_rotation", 0.0)
    set("3d_skew_negative_shine", "material_tint", Vector3{ x = 1.0, y = 1.0, z = 1.0 })
    set("3d_skew_negative_shine", "grain_intensity", -1.95)
    set("3d_skew_negative_shine", "grain_scale", -2.21)
    set("3d_skew_negative_shine", "sheen_strength", -1.49)
    set("3d_skew_negative_shine", "sheen_width", 2.22)
    set("3d_skew_negative_shine", "sheen_speed", 2.3)
    set("3d_skew_negative_shine", "noise_amount", 1.12)
    set("3d_skew_negative_shine", "spread_strength", 1.0)
    set("3d_skew_negative_shine", "distortion_strength", 0.05)
    set("3d_skew_negative_shine", "fade_start", 0.7)
    set("3d_skew_negative_shine", "negative_shine", Vector2{ x = 0.65, y = 0.25 })
    set("3d_skew_negative_shine", "time", get_time())

    -- 3d_skew_negative
    set("3d_skew_negative", "fov", -0.39)
    set("3d_skew_negative", "x_rot", 0.0)
    set("3d_skew_negative", "y_rot", 0.0)
    set("3d_skew_negative", "inset", 0.0)
    set("3d_skew_negative", "hovering", 0.3)
    set("3d_skew_negative", "rand_trans_power", 0.4)
    set("3d_skew_negative", "rand_seed", 3.1415)
    set("3d_skew_negative", "rotation", 0.0)
    set("3d_skew_negative", "cull_back", 0.0)
    set("3d_skew_negative", "tilt_enabled", 0.0)
    set("3d_skew_negative", "regionRate", Vector2{ x = 1.0, y = 1.0 })
    set("3d_skew_negative", "pivot", Vector2{ x = 0.0, y = 0.0 })
    set("3d_skew_negative", "quad_center", Vector2{ x = 0.0, y = 0.0 })
    set("3d_skew_negative", "quad_size", Vector2{ x = 1.0, y = 1.0 })
    set("3d_skew_negative", "uv_passthrough", 0.0)
    set("3d_skew_negative", "uGridRect", Vector4{ x = 0.0, y = 0.0, z = 1.0, w = 1.0 })
    set("3d_skew_negative", "uImageSize", Vector2{ x = VIRTUAL_W, y = VIRTUAL_H })
    set("3d_skew_negative", "texture_details", Vector4{ x = 0.0, y = 0.0, z = 64.0, w = 64.0 })
    set("3d_skew_negative", "image_details", Vector2{ x = 65.15, y = 64.0 })
    set("3d_skew_negative", "dissolve", 0.0)
    set("3d_skew_negative", "shadow", 0.0)
    set("3d_skew_negative", "burn_colour_1", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 0.0 })
    set("3d_skew_negative", "burn_colour_2", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 0.0 })
    set("3d_skew_negative", "card_rotation", 0.0)
    set("3d_skew_negative", "material_tint", Vector3{ x = 1.0, y = 1.0, z = 1.0 })
    set("3d_skew_negative", "grain_intensity", -1.95)
    set("3d_skew_negative", "grain_scale", -2.21)
    set("3d_skew_negative", "sheen_strength", -1.49)
    set("3d_skew_negative", "sheen_width", 2.22)
    set("3d_skew_negative", "sheen_speed", 2.3)
    set("3d_skew_negative", "noise_amount", 1.12)
    set("3d_skew_negative", "spread_strength", 1.0)
    set("3d_skew_negative", "distortion_strength", 0.05)
    set("3d_skew_negative", "fade_start", 0.7)
    set("3d_skew_negative", "negative", Vector2{ x = 0.65, y = 0.25 })
    set("3d_skew_negative", "time", get_time())

    -- squish
    set("squish", "up_left", Vector2{ x = 0.0, y = 0.0 })
    set("squish", "up_right", Vector2{ x = 1.0, y = 0.0 })
    set("squish", "down_right", Vector2{ x = 1.0, y = 1.0 })
    set("squish", "down_left", Vector2{ x = 0.0, y = 1.0 })
    set("squish", "plane_size", Vector2{ x = VIRTUAL_W, y = VIRTUAL_H })

    -- peaches_background
    set("peaches_background", "resolution", Vector2{ x = VIRTUAL_W, y = VIRTUAL_H })
    set("peaches_background", "iTime", get_time())
    set("peaches_background", "resolution", Vector2{ x = 1440.0, y = 900.0 })
    set("peaches_background", "blob_count", 5.02)
    set("peaches_background", "blob_spacing", -0.89)
    set("peaches_background", "shape_amplitude", 0.205)
    set("peaches_background", "distortion_strength", 4.12)
    set("peaches_background", "noise_strength", 0.14)
    set("peaches_background", "radial_falloff", -0.03)
    set("peaches_background", "wave_strength", 1.55)
    set("peaches_background", "highlight_gain", 3.8)
    set("peaches_background", "cl_shift", 0.1)
    set("peaches_background", "edge_softness_min", 0.32)
    set("peaches_background", "edge_softness_max", 0.68)
    set("peaches_background", "colorTint", Vector3{ x = 0.33, y = 0.57, z = 0.31 })
    set("peaches_background", "blob_color_blend", 0.69)
    set("peaches_background", "hue_shift", 0.8)
    set("peaches_background", "pixel_size", 6.0)
    set("peaches_background", "pixel_enable", 1.0)
    set("peaches_background", "blob_offset", Vector2{ x = 0.0, y = -0.1 })
    set("peaches_background", "movement_randomness", 16.2)

    -- foil
    set("foil", "time", get_time())
    set("foil", "dissolve", 0.0)
    set("foil", "foil", Vector2{ x = 1.0, y = 1.0 })
    set("foil", "texture_details", Vector4{ x = 0.0, y = 0.0, z = 128.0, w = 128.0 })
    set("foil", "image_details", Vector2{ x = 128.0, y = 128.0 })
    set("foil", "burn_colour_1", Vector4{ x = 1.0, y = 0.3, z = 0.0, w = 1.0 })
    set("foil", "burn_colour_2", Vector4{ x = 1.0, y = 1.0, z = 0.2, w = 1.0 })
    set("foil", "shadow", 0.0)

    -- holo
    set("holo", "time", 0.0)
    set("holo", "dissolve", 0.0)
    set("holo", "texture_details", Vector4{ x = 0.0, y = 0.0, z = 64.0, w = 64.0 })
    set("holo", "image_details", Vector2{ x = 64.0, y = 64.0 })
    set("holo", "holo", Vector2{ x = 1.2, y = 0.8 })
    set("holo", "burn_colour_1", COLOR_BLUE_N)
    set("holo", "burn_colour_2", COLOR_PURPLE_N)
    set("holo", "shadow", 0.0)
    set("holo", "mouse_screen_pos", Vector2{ x = 0.0, y = 0.0 })
    set("holo", "hovering", 0.0)
    set("holo", "screen_scale", 1.0)

    -- polychrome
    set("polychrome", "texture_details", Vector4{ x = 0.0, y = 0.0, z = 64.0, w = 64.0 })
    set("polychrome", "image_details", Vector2{ x = 64.0, y = 64.0 })
    set("polychrome", "time", get_time())
    set("polychrome", "dissolve", 0.0)
    set("polychrome", "polychrome", Vector2{ x = 0.1, y = 0.1 })
    set("polychrome", "shadow", 0.0)
    set("polychrome", "burn_colour_1", Vector4{ x = 1.0, y = 1.0, z = 0.0, w = 1.0 })
    set("polychrome", "burn_colour_2", Vector4{ x = 1.0, y = 1.0, z = 1.0, w = 1.0 })

    -- material_card_overlay
    set("material_card_overlay", "uGridRect", Vector4{ x = 0.0, y = 0.0, z = 188.0, w = 230.66667 })
    set("material_card_overlay", "uImageSize", Vector2{ x = 188.0, y = 230.66667 })
    set("material_card_overlay", "texture_details", Vector4{ x = 0.0, y = 0.0, z = 64.0, w = 64.0 })
    set("material_card_overlay", "image_details", Vector2{ x = 65.15, y = 64.0 })
    set("material_card_overlay", "time", get_time())
    set("material_card_overlay", "dissolve", 0.0)
    set("material_card_overlay", "shadow", 0.0)
    set("material_card_overlay", "burn_colour_1", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 0.0 })
    set("material_card_overlay", "burn_colour_2", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 0.0 })
    set("material_card_overlay", "card_rotation", 0.0)
    set("material_card_overlay", "material_tint", Vector3{ x = 1.0, y = 1.0, z = 1.0 })
    set("material_card_overlay", "grain_intensity", -1.95)
    set("material_card_overlay", "grain_scale", -2.21)
    set("material_card_overlay", "sheen_strength", -1.49)
    set("material_card_overlay", "sheen_width", 2.22)
    set("material_card_overlay", "sheen_speed", 2.3)
    set("material_card_overlay", "noise_amount", 1.12)
    register("material_card_overlay", function(_shader)
        set("material_card_overlay", "time", get_time())
    end)

    -- material_card_overlay_new_dissolve
    set("material_card_overlay_new_dissolve", "uGridRect", Vector4{ x = 0.0, y = 0.0, z = 188.0, w = 230.66667 })
    set("material_card_overlay_new_dissolve", "uImageSize", Vector2{ x = 188.0, y = 230.66667 })
    set("material_card_overlay_new_dissolve", "texture_details", Vector4{ x = 0.0, y = 0.0, z = 64.0, w = 64.0 })
    set("material_card_overlay_new_dissolve", "image_details", Vector2{ x = 65.15, y = 64.0 })
    set("material_card_overlay_new_dissolve", "time", get_time())
    set("material_card_overlay_new_dissolve", "dissolve", 0.0)
    set("material_card_overlay_new_dissolve", "shadow", 0.0)
    set("material_card_overlay_new_dissolve", "burn_colour_1", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 0.0 })
    set("material_card_overlay_new_dissolve", "burn_colour_2", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 0.0 })
    set("material_card_overlay_new_dissolve", "card_rotation", 0.0)
    set("material_card_overlay_new_dissolve", "material_tint", Vector3{ x = 1.0, y = 1.0, z = 1.0 })
    set("material_card_overlay_new_dissolve", "grain_intensity", -1.95)
    set("material_card_overlay_new_dissolve", "grain_scale", -2.21)
    set("material_card_overlay_new_dissolve", "sheen_strength", -1.49)
    set("material_card_overlay_new_dissolve", "sheen_width", 2.22)
    set("material_card_overlay_new_dissolve", "sheen_speed", 2.3)
    set("material_card_overlay_new_dissolve", "noise_amount", 1.12)
    register("material_card_overlay_new_dissolve", function(_shader)
        set("material_card_overlay_new_dissolve", "time", get_time())
    end)

    -- negative_shine
    set("negative_shine", "texture_details", Vector4{ x = 0.0, y = 0.0, z = 64.0, w = 64.0 })
    set("negative_shine", "image_details", Vector2{ x = 64.0, y = 64.0 })
    set("negative_shine", "negative_shine", Vector2{ x = 1.0, y = 1.0 })
    set("negative_shine", "burn_colour_1", COLOR_SKYBLUE_N)
    set("negative_shine", "burn_colour_2", COLOR_PINK_N)
    set("negative_shine", "shadow", 0.0)
    set("negative_shine", "mouse_screen_pos", Vector2{ x = 0.0, y = 0.0 })
    set("negative_shine", "hovering", 0.0)
    set("negative_shine", "screen_scale", 1.0)

    -- negative
    set("negative", "texture_details", Vector4{ x = 0.0, y = 0.0, z = 64.0, w = 64.0 })
    set("negative", "image_details", Vector2{ x = 64.0, y = 64.0 })
    set("negative", "negative", Vector2{ x = 1.0, y = 1.0 })
    set("negative", "dissolve", 0.0)
    set("negative", "burn_colour_1", COLOR_RED_N)
    set("negative", "burn_colour_2", COLOR_ORANGE_N)
    set("negative", "shadow", 0.0)
    set("negative", "mouse_screen_pos", Vector2{ x = 0.0, y = 0.0 })
    set("negative", "hovering", 0.0)
    set("negative", "screen_scale", 1.0)

    -- spectrum_circle
    set("spectrum_circle", "iResolution", Vector2{ x = VIRTUAL_W, y = VIRTUAL_H })
    set("spectrum_circle", "uCenter", Vector2{ x = 200, y = 150 })
    set("spectrum_circle", "uRadius", 30.0)

    -- spectrum_line_background
    set("spectrum_line_background", "uLineSpacing", 100.0)
    set("spectrum_line_background", "uLineWidth", 0.75)
    set("spectrum_line_background", "uBeamHeight", 30.0)
    set("spectrum_line_background", "uBeamIntensity", 1.0)
    set("spectrum_line_background", "uOpacity", 1.0)
    set("spectrum_line_background", "uBeamY", 200.0)
    set("spectrum_line_background", "uBeamWidth", 400.0)
    set("spectrum_line_background", "uBeamX", 400.0)

    -- voucher_sheen
    set("voucher_sheen", "booster", Vector2{ x = 0.0, y = 0.0 })
    set("voucher_sheen", "dissolve", 0.0)
    set("voucher_sheen", "time", 0.0)
    set("voucher_sheen", "texture_details", Vector4{ x = 0.0, y = 0.0, z = 64.0, w = 64.0 })
    set("voucher_sheen", "image_details", Vector2{ x = 64.0, y = 64.0 })
    set("voucher_sheen", "shadow", false)
    set("voucher_sheen", "burn_colour_1", COLOR_BLUE_N)
    set("voucher_sheen", "burn_colour_2", COLOR_PURPLE_N)

    -- discrete_clouds
    set("discrete_clouds", "bottom_color", Vector4{ x = 1.0, y = 1.0, z = 1.0, w = 1.0 })
    set("discrete_clouds", "top_color", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 1.0 })
    set("discrete_clouds", "layer_count", 20)
    set("discrete_clouds", "time_scale", 0.2)
    set("discrete_clouds", "base_intensity", 0.5)
    set("discrete_clouds", "size", 0.1)

    -- bounding_battle_bg
    set("bounding_battle_bg", "snes_transparency", false)
    set("bounding_battle_bg", "gba_transparency", false)
    set("bounding_battle_bg", "horizontal_scan_line", false)
    set("bounding_battle_bg", "vertical_scan_line", false)
    set("bounding_battle_bg", "enable_palette_cycling", false)
    set("bounding_battle_bg", "sprite_scroll_direction", Vector2{ x = 0.0, y = 0.0 })
    set("bounding_battle_bg", "sprite_scroll_speed", 0.01)
    set("bounding_battle_bg", "gba_transparency_scroll_direction", Vector2{ x = 0.0, y = 0.0 })
    set("bounding_battle_bg", "gba_transparency_scroll_speed", 0.01)
    set("bounding_battle_bg", "gba_transparency_value", 0.5)
    set("bounding_battle_bg", "horizontal_wave_amplitude", 0.0)
    set("bounding_battle_bg", "horizontal_wave_frequency", 0.0)
    set("bounding_battle_bg", "horizontal_wave_speed", 1.0)
    set("bounding_battle_bg", "vertical_wave_amplitude", 0.0)
    set("bounding_battle_bg", "vertical_wave_frequency", 0.0)
    set("bounding_battle_bg", "vertical_wave_speed", 1.0)
    set("bounding_battle_bg", "horizontal_deform_amplitude", 0.0)
    set("bounding_battle_bg", "horizontal_deform_frequency", 0.0)
    set("bounding_battle_bg", "horizontal_deform_speed", 1.0)
    set("bounding_battle_bg", "vertical_deform_amplitude", 0.0)
    set("bounding_battle_bg", "vertical_deform_frequency", 0.0)
    set("bounding_battle_bg", "vertical_deform_speed", 1.0)
    set("bounding_battle_bg", "width", 640.0)
    set("bounding_battle_bg", "height", 480.0)
    set("bounding_battle_bg", "palette_cycling_speed", 0.1)

    -- infinite_scrolling_texture
    set("infinite_scrolling_texture", "scroll_speed", 0.1)
    set("infinite_scrolling_texture", "angle", 0.0)
    set("infinite_scrolling_texture", "pixel_perfect", true)

    -- rain_snow
    set("rain_snow", "rain_amount", 500.0)
    set("rain_snow", "near_rain_length", 0.3)
    set("rain_snow", "far_rain_length", 0.1)
    set("rain_snow", "near_rain_width", 0.5)
    set("rain_snow", "far_rain_width", 0.3)
    set("rain_snow", "near_rain_transparency", 1.0)
    set("rain_snow", "far_rain_transparency", 0.5)
    set("rain_snow", "rain_color", Vector4{ x = 1.0, y = 1.0, z = 1.0, w = 1.0 })
    set("rain_snow", "base_rain_speed", 0.3)
    set("rain_snow", "additional_rain_speed_range", 0.3)

    -- pixel_art_gradient
    set("pixel_art_gradient", "grid_size", 16.0)
    set("pixel_art_gradient", "smooth_size", 8.0)

    -- extensible_color_palette
    set("extensible_color_palette", "u_size", 8)
    set("extensible_color_palette", "u_use_lerp", true)
    set("extensible_color_palette", "u_add_source_colors", false)
    set("extensible_color_palette", "u_add_greyscale_colors", false)

    -- dissolve_burn
    set("dissolve_burn", "burn_color", Vector4{ x = 1.0, y = 0.7, z = 0.0, w = 1.0 })
    set("dissolve_burn", "burn_size", 0.1)
    set("dissolve_burn", "dissolve_amount", 0.0)

    -- wobbly_grid
    set("wobbly_grid", "amplitude", 10.0)
    set("wobbly_grid", "frequency", 5.0)
    set("wobbly_grid", "speed", 2.0)

    -- fireworks_2d
    set("fireworks_2d", "particle_count", 100)
    set("fireworks_2d", "explosion_radius", 0.3)

    -- efficient_pixel_outlines
    set("efficient_pixel_outlines", "outline_color", Vector4{ x = 1.0, y = 1.0, z = 1.0, w = 1.0 })
    set("efficient_pixel_outlines", "outline_thickness", 1.0)
    set("efficient_pixel_outlines", "use_8_directions", false)

    -- pixel_perfect_dissolve
    set("pixel_perfect_dissolve", "dissolve_amount", 0.0)
    set("pixel_perfect_dissolve", "pixel_size", 1.0)
    set("pixel_perfect_dissolve", "sensitivity", 0.5)

    -- random_displacement
    set("random_displacement", "displacement_amount", 5.0)
    set("random_displacement", "speed", 1.0)

    -- drop_shadow (screen)
    set("drop_shadow", "background_color", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 0.0 })
    set("drop_shadow", "shadow_color", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 0.5 })
    set("drop_shadow", "offset_in_pixels", Vector2{ x = 5.0, y = 5.0 })
    set("drop_shadow", "screen_pixel_size", Vector2{ x = 1.0 / VIRTUAL_W, y = 1.0 / VIRTUAL_H })
    set("drop_shadow", "shadowOffset", Vector2{ x = 5.0, y = 5.0 })
    set("drop_shadow", "shadowColor", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 0.5 })
    set("drop_shadow", "shadowSoftness", 1.0)

    -- chromatic_aberration (screen)
    set("chromatic_aberration", "r_displacement", Vector2{ x = 3.0, y = 0.0 })
    set("chromatic_aberration", "g_displacement", Vector2{ x = 0.0, y = 0.0 })
    set("chromatic_aberration", "b_displacement", Vector2{ x = -3.0, y = 0.0 })
    set("chromatic_aberration", "height", 0.7)
    set("chromatic_aberration", "width", 0.5)
    set("chromatic_aberration", "fade", 0.7)
    set("chromatic_aberration", "screen_pixel_size", Vector2{ x = 1.0 / VIRTUAL_W, y = 1.0 / VIRTUAL_H })

    -- darkened_blur (screen)
    set("darkened_blur", "lod", 5.0)
    set("darkened_blur", "mix_percentage", 0.3)

    -- custom_2d_light (screen)
    set("custom_2d_light", "light_color", Vector3{ x = 255.0, y = 255.0, z = 255.0 })
    set("custom_2d_light", "brightness", 0.5)
    set("custom_2d_light", "attenuation_strength", 0.5)
    set("custom_2d_light", "intensity", 1.0)
    set("custom_2d_light", "max_brightness", 1.0)

    -- palette_shader (screen)
    set("palette_shader", "palette_size", 16)

    -- perspective_warp (screen)
    set("perspective_warp", "topleft", Vector2{ x = 0.01, y = 0.0 })
    set("perspective_warp", "topright", Vector2{ x = 0.0, y = 0.0 })
    set("perspective_warp", "bottomleft", Vector2{ x = 0.0, y = 0.0 })
    set("perspective_warp", "bottomright", Vector2{ x = 0.0, y = 0.0 })

    -- radial_shine_highlight (screen)
    set("radial_shine_highlight", "spread", 0.5)
    set("radial_shine_highlight", "cutoff", 0.1)
    set("radial_shine_highlight", "size", 1.0)
    set("radial_shine_highlight", "speed", 1.0)
    set("radial_shine_highlight", "ray1_density", 8.0)
    set("radial_shine_highlight", "ray2_density", 30.0)
    set("radial_shine_highlight", "ray2_intensity", 0.3)
    set("radial_shine_highlight", "core_intensity", 2.0)
    set("radial_shine_highlight", "seed", 5.0)
    set("radial_shine_highlight", "hdr", 0)

    -- efficient_pixel_outline (godot block)
    set("efficient_pixel_outline", "outlineColor", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 1.0 })
    set("efficient_pixel_outline", "outlineType", 2)
    set("efficient_pixel_outline", "thickness", 1.0)

    -- atlas_outline (godot block)
    set("atlas_outline", "outlineWidth", 1.0)
    set("atlas_outline", "outlineColor", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 1.0 })
    set("atlas_outline", "uGridRect", Vector4{ x = 0.0, y = 0.0, z = 1.0, w = 1.0 })
    set("atlas_outline", "uImageSize", Vector2{ x = 1.0, y = 1.0 })

    -- burn_2d (godot block)
    set("burn_2d", "burnSize", 1.0)
    set("burn_2d", "burnColor1", Vector4{ x = 1.0, y = 0.7, z = 0.0, w = 1.0 })
    set("burn_2d", "burnColor2", Vector4{ x = 0.5, y = 0.0, z = 0.0, w = 1.0 })
    set("burn_2d", "burnColor3", Vector4{ x = 0.1, y = 0.1, z = 0.1, w = 1.0 })

    -- dissolve_burn_edge
    set("dissolve_burn_edge", "burnSize", 1.3)
    set("dissolve_burn_edge", "progress", 0.0)

    -- drop_shadow (godot block)
    set("drop_shadow", "shadowOffset", Vector2{ x = 5.0, y = 5.0 })
    set("drop_shadow", "shadowColor", Vector4{ x = 0.0, y = 0.0, z = 0.0, w = 0.5 })
    set("drop_shadow", "shadowSoftness", 1.0)

    -- hologram (godot block)
    set("hologram", "strength", 0.5)
    set("hologram", "frequency", 10.0)

    -- liquid_sphere
    set("liquid_sphere", "liquidLevel", 0.5)
    set("liquid_sphere", "waveAmplitude", 0.1)
    set("liquid_sphere", "waveFrequency", 5.0)
    set("liquid_sphere", "liquidColor", Vector4{ x = 0.2, y = 0.6, z = 0.8, w = 0.7 })

    -- texture_liquid
    set("texture_liquid", "waterColor1", Vector4{ x = 0.2, y = 0.6, z = 0.8, w = 0.5 })
    set("texture_liquid", "waterColor2", Vector4{ x = 0.1, y = 0.5, z = 0.7, w = 0.4 })
    set("texture_liquid", "waterLevelPercentage", 0.0)
    set("texture_liquid", "waveFrequency1", 10.0)
    set("texture_liquid", "waveAmplitude1", 0.05)
    set("texture_liquid", "waveFrequency2", 15.0)
    set("texture_liquid", "waveAmplitude2", 0.03)
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

    register("vacuum_collapse", function(_shader)
        set("vacuum_collapse", "iTime", get_time())
    end)

    register("fireworks", function(_shader)
        set("fireworks", "iTime", get_time())
    end)

    register("starry_tunnel", function(_shader)
        set("starry_tunnel", "iTime", get_time())
    end)

    register("item_glow", function(_shader)
        set("item_glow", "iTime", get_time())
    end)

    register("pixel_perfect_dissolving", function(_shader)
        set("pixel_perfect_dissolving", "iTime", get_time())
    end)

    register("burn_2d", function(_shader)
        set("burn_2d", "iTime", get_time())
    end)

    register("hologram_2d", function(_shader)
        set("hologram_2d", "iTime", get_time())
    end)

    register("liquid_effects", function(_shader)
        set("liquid_effects", "iTime", get_time())
    end)

    register("liquid_fill_sphere", function(_shader)
        set("liquid_fill_sphere", "iTime", get_time())
    end)

    register("pixel_art_trail", function(_shader)
        set("pixel_art_trail", "iTime", get_time())
    end)

    register("animated_dotted_outline", function(_shader)
        set("animated_dotted_outline", "iTime", get_time())
    end)

    register("dynamic_glow", function(_shader)
        set("dynamic_glow", "iTime", get_time())
    end)

    register("wobbly", function(_shader)
        set("wobbly", "iTime", get_time())
    end)

    register("bounce_wave", function(_shader)
        set("bounce_wave", "iTime", get_time())
    end)

    register("radial_fire_2d", function(_shader)
        set("radial_fire_2d", "iTime", get_time())
    end)

    register("radial_shine_2d", function(_shader)
        set("radial_shine_2d", "iTime", get_time())
    end)

    register("holographic_card", function(_shader)
        set("holographic_card", "iTime", get_time())
    end)

    register("3d_skew", function(_shader)
        set("3d_skew", "iTime", get_time())
        set("3d_skew", "time", get_time())
        set("3d_skew", "mouse_screen_pos", get_mouse())
        set("3d_skew", "resolution", Vector2{ x = globals.screenWidth(), y = globals.screenHeight() })
    end)

    register("3d_skew_hologram", function(_shader)
        set("3d_skew_hologram", "iTime", get_time())
        set("3d_skew_hologram", "time", get_time())
        set("3d_skew_hologram", "mouse_screen_pos", get_mouse())
        set("3d_skew_hologram", "resolution", Vector2{ x = globals.screenWidth(), y = globals.screenHeight() })
    end)

    register("3d_skew_polychrome", function(_shader)
        set("3d_skew_polychrome", "iTime", get_time())
        set("3d_skew_polychrome", "time", get_time())
        set("3d_skew_polychrome", "mouse_screen_pos", get_mouse())
        set("3d_skew_polychrome", "resolution", Vector2{ x = globals.screenWidth(), y = globals.screenHeight() })
    end)

    register("3d_skew_foil", function(_shader)
        set("3d_skew_foil", "iTime", get_time())
        set("3d_skew_foil", "time", get_time())
        set("3d_skew_foil", "mouse_screen_pos", get_mouse())
        set("3d_skew_foil", "resolution", Vector2{ x = globals.screenWidth(), y = globals.screenHeight() })
    end)

    register("3d_skew_negative_shine", function(_shader)
        set("3d_skew_negative_shine", "iTime", get_time())
        set("3d_skew_negative_shine", "time", get_time())
        set("3d_skew_negative_shine", "mouse_screen_pos", get_mouse())
        set("3d_skew_negative_shine", "resolution", Vector2{ x = globals.screenWidth(), y = globals.screenHeight() })
    end)

    register("3d_skew_negative", function(_shader)
        set("3d_skew_negative", "iTime", get_time())
        set("3d_skew_negative", "time", get_time())
        set("3d_skew_negative", "mouse_screen_pos", get_mouse())
        set("3d_skew_negative", "resolution", Vector2{ x = globals.screenWidth(), y = globals.screenHeight() })
    end)

    register("squish", function(_shader)
        local t = get_time()
        set("squish", "squish_x", math.sin(t * 0.5) * 0.1)
        set("squish", "squish_Y", math.cos(t * 0.2) * 0.1)
    end)

    register("peaches_background", function(_shader)
        set("peaches_background", "iTime", get_time() * 0.5)
    end)

    register("foil", function(_shader)
        set("foil", "time", get_time())
    end)

    register("holo", function(_shader)
        set("holo", "time", get_time())
    end)

    register("polychrome", function(_shader)
        set("polychrome", "time", get_time())
    end)

    register("material_card_overlay", function(_shader)
        set("material_card_overlay", "time", get_time())
    end)

    register("negative_shine", function(_shader)
        set("negative_shine", "time", get_time())
    end)

    register("negative", function(_shader)
        set("negative", "time", get_time())
    end)

    register("spectrum_circle", function(_shader)
        set("spectrum_circle", "iTime", get_time())
    end)

    register("spectrum_line_background", function(_shader)
        set("spectrum_line_background", "iTime", get_time())
        set("spectrum_line_background", "iResolution", Vector2{ x = globals.screenWidth(), y = globals.screenHeight() })
    end)

    register("voucher_sheen", function(_shader)
        set("voucher_sheen", "time", get_time())
    end)

    register("discrete_clouds", function(_shader)
        set("discrete_clouds", "time", get_time())
    end)

    register("bounding_battle_bg", function(_shader)
        set("bounding_battle_bg", "time", get_time())
    end)

    register("infinite_scrolling_texture", function(_shader)
        set("infinite_scrolling_texture", "time", get_time())
    end)

    register("rain_snow", function(_shader)
        set("rain_snow", "time", get_time())
    end)

    register("dissolve_burn", function(_shader)
        set("dissolve_burn", "time", get_time())
    end)

    register("wobbly_grid", function(_shader)
        set("wobbly_grid", "time", get_time())
    end)

    register("radial_shine_highlight", function(_shader)
        set("radial_shine_highlight", "time", get_time())
    end)

    register("fireworks_2d", function(_shader)
        set("fireworks_2d", "time", get_time())
    end)

    register("pixel_perfect_dissolve", function(_shader)
        set("pixel_perfect_dissolve", "time", get_time())
    end)

    register("random_displacement", function(_shader)
        set("random_displacement", "time", get_time())
    end)

    register("hologram", function(_shader)
        set("hologram", "iTime", get_time())
    end)

    register("liquid_sphere", function(_shader)
        set("liquid_sphere", "iTime", get_time())
    end)

    register("texture_liquid", function(_shader)
        set("texture_liquid", "iTime", get_time())
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

    -- One-time validation snapshot (logs a few representative uniforms).
    shaders.updateAllShaderUniforms()
    local function summarize(val)
        local t = type(val)
        if t == "table" then
            return "{table}"
        elseif t == "userdata" then
            local ok, id = pcall(function() return val.id end)
            if ok and id then
                return string.format("{userdata id=%s}", tostring(id))
            end
            return "{userdata}"
        else
            return tostring(val)
        end
    end
    local function log_uniform(shader, name)
        local ok, v = pcall(function() return globalShaderUniforms:get(shader, name) end)
        if not ok then
            log_debug(string.format("shader_uniforms.validate %s.%s -> error: %s", shader, name, v))
            return
        end
        log_debug(string.format("shader_uniforms.validate %s.%s = %s", shader, name, summarize(v)))
    end
    log_uniform("crt", "iTime")
    log_uniform("balatro_background", "spin_rotation")
    log_uniform("tile_grid_overlay", "atlas")
    log_uniform("screen_tone_transition", "screen_pixel_size")
    log_uniform("material_card_overlay", "material_tint")
    log_uniform("material_card_overlay", "burn_colour_1")
    log_uniform("material_card_overlay", "burn_colour_2")
    log_uniform("material_card_overlay", "dissolve")
    log_uniform("material_card_overlay", "grain_intensity")
    log_uniform("material_card_overlay", "sheen_strength")
    log_uniform("material_card_overlay", "noise_amount")
end

return shader_uniforms
