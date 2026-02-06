-- assets/scripts/core/action_arena_ldtk.lua
-- Procedural action arena backed by LDtk auto-rules.

local ldtk_rules = require("core.procgen.ldtk_rules")
local PatternBuilder = require("core.procgen.pattern_builder")
local coords = require("core.procgen.coords")
local Grid = require("core.procgen.vendor").Grid

local Arena = {}

local state = {
    ready = false,
    opts = nil,
    bounds = nil,
}

local defaults = {
    def_path = "Typical_TopDown_example.ldtk",
    asset_dir = nil, -- nil => derive from LDtk def file location
    level_name = nil, -- nil => first level in file
    rule_layer = "Collisions",
    render_layers = { "Default_floor", "Wall_tops" },
    target_layer = "sprites",
    base_z = 0,
    z_step = 1,
    opacity = 1.0,
    offset_x = 0,
    offset_y = 0,
    world_name = "world",
    physics_tag = "WORLD",
    solid_values = { 1 },
    fill_density = 0.42,
    ca_rule = "B5678/S45678",
    ca_iterations = 12,
    wall_value = 1,
    floor_value = 0,
    fallback_tiles_w = 80,
    fallback_tiles_h = 45,
    seed = nil,
}

local function is_absolute_path(path)
    if type(path) ~= "string" or path == "" then
        return false
    end
    if path:sub(1, 1) == "/" then
        return true
    end
    if path:match("^%a:[/\\]") then
        return true
    end
    if path:sub(1, 2) == "\\\\" then
        return true
    end
    return false
end

local function clone_table(src)
    local out = {}
    for k, v in pairs(src or {}) do
        if type(v) == "table" then
            local child = {}
            for ck, cv in pairs(v) do
                child[ck] = cv
            end
            out[k] = child
        else
            out[k] = v
        end
    end
    return out
end

local function merge_opts(opts)
    local merged = clone_table(defaults)
    for k, v in pairs(opts or {}) do
        if type(v) == "table" then
            merged[k] = clone_table(v)
        else
            merged[k] = v
        end
    end
    return merged
end

local function resolve_def_path(def_path)
    if is_absolute_path(def_path) then
        return def_path
    end
    if util and util.getRawAssetPathNoUUID then
        local resolved = util.getRawAssetPathNoUUID(def_path)
        if resolved and resolved ~= "" then
            return resolved
        end
    end
    return def_path
end

local function resolve_asset_dir(def_path, asset_dir)
    if asset_dir and asset_dir ~= "" then
        if is_absolute_path(asset_dir) then
            return asset_dir
        end
        if util and util.getRawAssetPathNoUUID then
            local resolved = util.getRawAssetPathNoUUID(asset_dir)
            if resolved and resolved ~= "" then
                return resolved
            end
        end
        return asset_dir
    end

    local dir = def_path and def_path:match("(.+)/[^/]+$")
    return dir or "assets"
end

local function set_border_walls(grid, wall_value)
    for x = 1, grid.w do
        grid:set(x, 1, wall_value)
        grid:set(x, grid.h, wall_value)
    end
    for y = 1, grid.h do
        grid:set(1, y, wall_value)
        grid:set(grid.w, y, wall_value)
    end
end

local function choose_seed(seed)
    if seed ~= nil then return seed end
    return math.floor((os.time() % 1000000) + 1)
end

local function generate_cave_grid(w, h, cfg, seed)
    if seed then
        math.randomseed(seed)
    end

    local pattern = PatternBuilder.new()
        :square(w, h)
        :sample(math.floor(w * h * cfg.fill_density))
        :automata(cfg.ca_rule, cfg.ca_iterations)
        :keepLargest()
        :build()

    local grid = Grid(w, h, cfg.wall_value)
    coords.patternToGrid(pattern, grid, cfg.floor_value, 1, 1)
    return grid
end

function Arena.init(opts)
    local cfg = merge_opts(opts)
    local rules = ldtk_rules

    cfg.def_path = resolve_def_path(cfg.def_path)
    cfg.asset_dir = resolve_asset_dir(cfg.def_path, cfg.asset_dir)

    rules.load(cfg.def_path, cfg.asset_dir)

    local level = rules.get_level_dims(cfg.level_name)
    local cell_size = rules.get_cell_size(cfg.rule_layer)
    local tiles_w = (level and level.tiles_w) or cfg.fallback_tiles_w
    local tiles_h = (level and level.tiles_h) or cfg.fallback_tiles_h

    if tiles_w < 8 then tiles_w = cfg.fallback_tiles_w end
    if tiles_h < 8 then tiles_h = cfg.fallback_tiles_h end
    if cell_size <= 0 then cell_size = 16 end

    local seed = choose_seed(cfg.seed)
    local grid = generate_cave_grid(tiles_w, tiles_h, cfg, seed)

    set_border_walls(grid, cfg.wall_value)

    rules.cleanup()
    rules.apply_rules(grid, { rule_layer = cfg.rule_layer })
    rules.build_colliders(grid, {
        worldName = cfg.world_name,
        physicsTag = cfg.physics_tag,
        solidValues = cfg.solid_values,
        cellSize = cell_size,
        rule_layer = cfg.rule_layer,
    })

    local px_w = tiles_w * cell_size
    local px_h = tiles_h * cell_size

    state.ready = true
    state.opts = cfg
    state.bounds = {
        left = cfg.offset_x,
        top = cfg.offset_y,
        right = cfg.offset_x + px_w,
        bottom = cfg.offset_y + px_h,
        cell_size = cell_size,
        tiles_w = tiles_w,
        tiles_h = tiles_h,
        seed = seed,
    }

    return state.bounds
end

function Arena.draw()
    if not state.ready then return end
    ldtk_rules.draw({
        layers = state.opts.render_layers,
        target_layer = state.opts.target_layer,
        offset_x = state.opts.offset_x,
        offset_y = state.opts.offset_y,
        base_z = state.opts.base_z,
        z_step = state.opts.z_step,
        opacity = state.opts.opacity,
    })
end

function Arena.cleanup()
    ldtk_rules.cleanup()
    state.ready = false
    state.opts = nil
    state.bounds = nil
end

function Arena.is_ready()
    return state.ready
end

function Arena.get_bounds()
    return state.bounds
end

return Arena
