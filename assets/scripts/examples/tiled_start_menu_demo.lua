-- Start-menu Tiled demo runtime.
-- Designed for normal game startup (non test-mode) so users can enter from the
-- main menu and inspect a real rendered map.

local tiled_bridge = require("core.procgen.tiled_bridge")

local M = {}

local state = {
    active = false,
    frame = 0,
    map_id = nil,
    draw_count = 0,
    draw_opts = nil,
}

local DEFAULT_MAP_PATH = "tests/out/tiled_demo_runtime/map/demo.tmj"

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

    -- Fixed framing for the demo map.
    cam:SetActualTarget(256, 256)
    cam:SetActualOffset(640, 360)
    cam:SetActualZoom(1.0)
end

function M.start(opts)
    opts = opts or {}

    local tiled = _G.tiled
    if not tiled then
        return false, "tiled bindings unavailable"
    end

    local map_path = opts.mapPath or DEFAULT_MAP_PATH

    local ok_load, map_or_err = pcall(tiled.load_map, map_path)
    if not ok_load then
        return false, tostring(map_or_err)
    end

    local map_id = map_or_err
    local ok_set, set_err = pcall(tiled.set_active_map, map_id)
    if not ok_set then
        return false, tostring(set_err)
    end

    configure_camera()

    state.active = true
    state.frame = 0
    state.map_id = map_id
    state.draw_count = 0
    state.draw_opts = {
        map_id = map_id,
        base_z = 0,
        layer_z_step = 1,
        z_per_row = 1,
        offset_x = 0,
        offset_y = 0,
        opacity = 1.0,
    }

    print("[tiled_start_menu_demo] started map_id=" .. tostring(map_id))
    return true, { map_id = map_id }
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
    state.draw_opts = nil
    print("[tiled_start_menu_demo] stopped")
end

function M.isActive()
    return state.active
end

return M
