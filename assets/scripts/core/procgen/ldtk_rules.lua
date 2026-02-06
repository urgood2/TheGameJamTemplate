-- assets/scripts/core/procgen/ldtk_rules.lua
-- Convenience wrapper for procedural LDtk auto-tiling + render + colliders.
--
-- Responsibilities:
--  - load rule definitions (.ldtk) for ldtk_rule_import
--  - parse .ldtk JSON for layer metadata (rule layers, render layers)
--  - resolve tile cell size from rule layer tileset
--  - apply rules to a procedural grid
--  - draw selected rule layers
--  - build colliders from the grid (optionally using resolved cell size)

local json = require("external.json")
local ldtk_bridge = require("core.procgen.ldtk_bridge")

local Rules = {}

local state = {
    loaded = false,
    def_path = nil,
    asset_dir = nil,
    grid_size = nil,
    layers = {},
    rule_layers = {},
    render_layers = {},
    intgrid_layers = {},
    levels = {},
    default_level = nil,
}

local function read_json(path)
    if not path or path == "" then return nil end
    local function try_open(p)
        local f = io.open(p, "r")
        if not f then return nil end
        local content = f:read("*a")
        f:close()
        local ok, data = pcall(json.decode, content)
        if ok then return data end
        return nil
    end

    -- Try asset-relative first if util is available, then raw path.
    if util and util.getRawAssetPathNoUUID then
        local resolved = util.getRawAssetPathNoUUID(path)
        local data = resolved and try_open(resolved)
        if data then return data end
    end
    return try_open(path)
end

local function parse_layers(defs)
    state.layers = {}
    state.rule_layers = {}
    state.render_layers = {}
    state.intgrid_layers = {}

    if not defs or not defs.layers then return end

    for _, layer in ipairs(defs.layers) do
        local name = layer.identifier or layer.name or ""
        local ltype = layer.__type or layer.type or ""
        local grid = layer.gridSize or layer.grid_size
        local auto_groups = layer.autoRuleGroups or {}
        local has_rules = #auto_groups > 0

        if grid and not state.grid_size then
            state.grid_size = grid
        end

        table.insert(state.layers, {
            name = name,
            type = ltype,
            grid_size = grid,
            has_rules = has_rules,
        })

        if ltype == "IntGrid" then
            table.insert(state.intgrid_layers, name)
        end
        if has_rules then
            table.insert(state.rule_layers, name)
            if ltype ~= "IntGrid" then
                table.insert(state.render_layers, name)
            end
        end
    end
end

local function parse_levels(levels)
    state.levels = {}
    state.default_level = nil
    if not levels then return end

    for i, lvl in ipairs(levels) do
        local ident = lvl.identifier or lvl.name or ("Level_" .. tostring(i))
        local px_w = lvl.pxWid or lvl.px_width or 0
        local px_h = lvl.pxHei or lvl.px_height or 0
        local entry = {
            name = ident,
            px_w = px_w,
            px_h = px_h,
            world_x = lvl.worldX or 0,
            world_y = lvl.worldY or 0,
        }
        table.insert(state.levels, entry)
        if not state.default_level then
            state.default_level = entry
        end
    end
end

local function resolve_cell_size(preferred_layer)
    if _G.ldtk and _G.ldtk.get_layer_index and _G.ldtk.get_tileset_info and preferred_layer then
        local idx = _G.ldtk.get_layer_index(preferred_layer)
        if idx and idx >= 0 then
            local info = _G.ldtk.get_tileset_info(idx)
            if info and info.tile_size and info.tile_size > 0 then
                return info.tile_size
            end
        end
    end
    return state.grid_size or 16
end

function Rules.load(def_path, asset_dir)
    assert(_G.ldtk and _G.ldtk.load_rule_defs, "ldtk.load_rule_defs not available")
    _G.ldtk.load_rule_defs(def_path, asset_dir)

    state.def_path = def_path
    state.asset_dir = asset_dir
    state.grid_size = nil

    local data = read_json(def_path)
    if data then
        state.grid_size = data.defaultGridSize
        parse_layers(data.defs)
        parse_levels(data.levels)
    end

    state.loaded = true
    return {
        grid_size = state.grid_size,
        rule_layers = state.rule_layers,
        render_layers = state.render_layers,
        intgrid_layers = state.intgrid_layers,
        levels = state.levels,
        default_level = state.default_level,
    }
end

function Rules.get_layers()
    return {
        all = state.layers,
        rule_layers = state.rule_layers,
        render_layers = state.render_layers,
        intgrid_layers = state.intgrid_layers,
    }
end

function Rules.get_level_dims(level_name)
    local target = nil
    if level_name then
        for _, lvl in ipairs(state.levels) do
            if lvl.name == level_name then
                target = lvl
                break
            end
        end
    end
    target = target or state.default_level
    if not target then
        return nil
    end

    local cell = resolve_cell_size(state.render_layers[1] or state.rule_layers[1])
    local tiles_w = cell > 0 and math.floor(target.px_w / cell) or 0
    local tiles_h = cell > 0 and math.floor(target.px_h / cell) or 0
    return {
        px_w = target.px_w,
        px_h = target.px_h,
        tiles_w = tiles_w,
        tiles_h = tiles_h,
        cell_size = cell,
        name = target.name,
    }
end

function Rules.get_cell_size(preferred_layer)
    return resolve_cell_size(preferred_layer or state.render_layers[1] or state.rule_layers[1])
end

function Rules.apply_rules(grid, opts)
    opts = opts or {}
    local rule_layer = opts.rule_layer or state.rule_layers[1]
    assert(rule_layer, "No rule layer available - load defs or pass rule_layer")
    return ldtk_bridge.applyRules(grid, rule_layer)
end

function Rules.draw(opts)
    opts = opts or {}
    local ldtk = _G.ldtk
    if not ldtk then return end

    local target_layer = opts.target_layer or "background"
    local offset_x = opts.offset_x or 0
    local offset_y = opts.offset_y or 0
    local base_z = opts.base_z or 0
    local z_step = opts.z_step or 1
    local opacity = opts.opacity or 1.0

    local layers = opts.layers or state.render_layers
    for i, name in ipairs(layers or {}) do
        local idx = ldtk.get_layer_index(name)
        if idx and idx >= 0 then
            ldtk.draw_procedural_layer(
                idx,
                target_layer,
                offset_x,
                offset_y,
                base_z + (i - 1) * z_step,
                opacity
            )
        end
    end
end

function Rules.build_colliders(grid, opts)
    opts = opts or {}
    opts.cellSize = opts.cellSize or resolve_cell_size(opts.rule_layer or state.rule_layers[1])
    ldtk_bridge.buildColliders(grid, opts)
end

function Rules.cleanup()
    ldtk_bridge.cleanup()
end

return Rules
