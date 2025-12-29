local timer = require("core.timer")
local Easing = require("util.easing")

local M = {
    defaults = nil,
    targets = {
        planning = {
            color1 = { x = 0.2, y = 0.45, z = 0.7 },
            color2 = { x = 0.15, y = 0.6, z = 0.55 },
            color3 = { x = 0.05, y = 0.12, z = 0.18 },
            flow_speed = 0.5,
            curl_scale = 2.5,
            curl_intensity = 1.2,
            color_shift = 0.15,
            iridescence = 0.4,
            contrast = 1.1,
            brightness = 0.02,
            noise_octaves = 4.0,
            pixel_size = 5.0,
            pixel_enable = 1.0
        },
        shop = {
            color1 = { x = 0.85, y = 0.65, z = 0.2 },
            color2 = { x = 0.75, y = 0.35, z = 0.15 },
            color3 = { x = 0.15, y = 0.08, z = 0.05 },
            flow_speed = 0.6,
            curl_scale = 3.5,
            curl_intensity = 1.8,
            color_shift = 0.0,
            iridescence = 0.7,
            contrast = 1.3,
            brightness = 0.0,
            noise_octaves = 4.0,
            pixel_size = 6.0,
            pixel_enable = 1.0
        }
    }
}

local function make_vec3(x, y, z)
    if _G.Vector3 then
        return _G.Vector3(x, y, z)
    end
    return { x = x, y = y, z = z }
end

local function copy_vec3(v)
    if not v then return { x = 0, y = 0, z = 0 } end
    return { x = v.x or v[1] or 0, y = v.y or v[2] or 0, z = v.z or v[3] or 0 }
end

function M.ensure_defaults()
    if M.defaults or not globalShaderUniforms then
        return M.defaults ~= nil
    end

    local function get(name)
        return globalShaderUniforms:get("oily_water_background", name)
    end

    M.defaults = {
        color1 = copy_vec3(get("color1")),
        color2 = copy_vec3(get("color2")),
        color3 = copy_vec3(get("color3")),
        flow_speed = get("flow_speed") or 0.8,
        curl_scale = get("curl_scale") or 3.0,
        curl_intensity = get("curl_intensity") or 1.5,
        color_shift = get("color_shift") or 0.0,
        iridescence = get("iridescence") or 0.6,
        contrast = get("contrast") or 1.2,
        brightness = get("brightness") or 0.0,
        noise_octaves = get("noise_octaves") or 4.0,
        pixel_size = get("pixel_size") or 4.0,
        pixel_enable = get("pixel_enable") or 1.0
    }

    local d = M.defaults
    M.targets.action = {
        color1 = copy_vec3(d.color1),
        color2 = copy_vec3(d.color2),
        color3 = copy_vec3(d.color3),
        flow_speed = d.flow_speed,
        curl_scale = d.curl_scale,
        curl_intensity = d.curl_intensity,
        color_shift = d.color_shift,
        iridescence = d.iridescence,
        contrast = d.contrast,
        brightness = d.brightness,
        noise_octaves = d.noise_octaves,
        pixel_size = d.pixel_size,
        pixel_enable = d.pixel_enable
    }

    return true
end

function M.tween_scalar(name, target, duration)
    if target == nil then return end
    timer.tween_scalar(
        duration,
        function() return globalShaderUniforms:get("oily_water_background", name) end,
        function(v) globalShaderUniforms:set("oily_water_background", name, v) end,
        target,
        Easing.inOutQuad.f,
        nil,
        "oily_bg_" .. name
    )
end

function M.tween_vec3(name, target, duration)
    if not target then return end
    local tag = "oily_bg_" .. name

    for _, comp in ipairs({"x", "y", "z"}) do
        timer.tween_scalar(
            duration,
            function()
                local current = globalShaderUniforms:get("oily_water_background", name)
                return current and current[comp] or 0
            end,
            function(v)
                local current = globalShaderUniforms:get("oily_water_background", name) or {x=0, y=0, z=0}
                current[comp] = v
                globalShaderUniforms:set("oily_water_background", name, make_vec3(current.x, current.y, current.z))
            end,
            target[comp] or 0,
            Easing.inOutQuad.f,
            nil,
            tag .. "_" .. comp
        )
    end
end

function M.tween_all(targets, duration)
    if not targets then return end
    local dur = duration or 1.0

    M.tween_vec3("color1", targets.color1, dur)
    M.tween_vec3("color2", targets.color2, dur)
    M.tween_vec3("color3", targets.color3, dur)

    local scalar_props = {
        "flow_speed", "curl_scale", "curl_intensity", "color_shift",
        "iridescence", "contrast", "brightness", "noise_octaves",
        "pixel_size", "pixel_enable"
    }
    for _, name in ipairs(scalar_props) do
        M.tween_scalar(name, targets[name], dur)
    end
end

function M.apply_phase(phase)
    if not globalShaderUniforms then return end
    if not M.ensure_defaults() then return end
    M.tween_all(M.targets[phase], 1.0)
end

return M
