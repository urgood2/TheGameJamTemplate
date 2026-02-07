-- Start-menu Tiled demo runtime.
-- Designed for normal game startup (non test-mode) so users can enter from the
-- main menu and inspect a real rendered map.

local tiled_bridge = require("core.procgen.tiled_bridge")

local M = {}

local state = {
    active = false,
    frame = 0,
    map_id = nil,
    map_path = nil,
    draw_count = 0,
    draw_opts = nil,
}

local DEFAULT_MAP_PATH = "assets/maps/tiled_demo/wall_showcase.tmj"
local FALLBACK_MAP_PATHS = {
    DEFAULT_MAP_PATH,
    "tests/out/tiled_demo_runtime/map/demo.tmj",
}

local function configure_camera()
    if not camera or not camera.Get then
        print("[tiled_start_menu_demo] camera bindings unavailable; using defaults")
        return
    end

    local cam = camera.Get("world_camera")
    if not cam then
        print("[tiled_start_menu_demo] world_camera missing; using defaults")
        return
    end

    -- Pixel-perfect framing for the generated wall showcase map (144x96 tiles @ 8px).
    -- Fractional zoom can make 8px tiles look off-grid due to sub-pixel sampling.
    cam:SetActualTarget(576, 384)
    cam:SetActualOffset(640, 360)
    cam:SetActualZoom(1.0)
end

local function contains_value(list, value)
    for i = 1, #list do
        if list[i] == value then
            return true
        end
    end
    return false
end

local function resolve_map_paths(opts)
    local out = {}

    if type(opts.mapPaths) == "table" then
        for i = 1, #opts.mapPaths do
            local p = opts.mapPaths[i]
            if type(p) == "string" and p ~= "" and not contains_value(out, p) then
                out[#out + 1] = p
            end
        end
    end

    if type(opts.mapPath) == "string" and opts.mapPath ~= "" and not contains_value(out, opts.mapPath) then
        out[#out + 1] = opts.mapPath
    end

    for i = 1, #FALLBACK_MAP_PATHS do
        local p = FALLBACK_MAP_PATHS[i]
        if not contains_value(out, p) then
            out[#out + 1] = p
        end
    end

    return out
end

function M.start(opts)
    opts = opts or {}

    local tiled = _G.tiled
    if not tiled then
        return false, "tiled bindings unavailable"
    end

    local map_paths = resolve_map_paths(opts)
    local loaded_map_id = nil
    local loaded_map_path = nil
    local load_errors = {}

    for i = 1, #map_paths do
        local candidate = map_paths[i]
        local ok_load, map_or_err = pcall(tiled.load_map, candidate)
        if ok_load then
            loaded_map_id = map_or_err
            loaded_map_path = candidate
            break
        end
        load_errors[#load_errors + 1] = candidate .. ": " .. tostring(map_or_err)
    end

    if not loaded_map_id then
        return false, "failed to load any demo map (" .. table.concat(load_errors, " | ") .. ")"
    end

    local ok_set, set_err = pcall(tiled.set_active_map, loaded_map_id)
    if not ok_set then
        return false, tostring(set_err)
    end

    configure_camera()

    state.active = true
    state.frame = 0
    state.map_id = loaded_map_id
    state.map_path = loaded_map_path
    state.draw_count = 0
    state.draw_opts = {
        map_id = loaded_map_id,
        base_z = 0,
        layer_z_step = 1,
        z_per_row = 1,
        offset_x = 0,
        offset_y = 0,
        opacity = 1.0,
    }

    print(
        "[tiled_start_menu_demo] started map_id=" ..
        tostring(loaded_map_id) ..
        " map_path=" .. tostring(loaded_map_path)
    )
    return true, { map_id = loaded_map_id, map_path = loaded_map_path }
end

function M.update(_dt)
    if not state.active then
        return 0
    end

    state.frame = state.frame + 1
    state.draw_count = tiled_bridge.drawAllLayersYSorted("background", state.draw_opts)

    if state.frame % 300 == 0 then
        print("[tiled_start_menu_demo] frame=" .. tostring(state.frame) ..
              " draw_count=" .. tostring(state.draw_count))
    end

    return state.draw_count
end

function M.stop()
    if not state.active then
        return
    end

    state.active = false
    state.frame = 0
    state.draw_count = 0
    state.map_id = nil
    state.map_path = nil
    state.draw_opts = nil
    print("[tiled_start_menu_demo] stopped")
end

function M.isActive()
    return state.active
end

return M
