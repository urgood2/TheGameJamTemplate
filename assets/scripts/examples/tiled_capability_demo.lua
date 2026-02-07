--[[
Tiled capability demo

Single-run demo that exercises all primary Tiled integration capabilities:
- Optional map load + active map set
- Tile layer rendering (normal and y-sorted)
- Optional single-layer rendering (normal and y-sorted)
- Object extraction + object spawn callback path
- Programmatic autotile rules for both required wall rulesets
- Procedural collider generation from grid data

Usage:
local demo = require("examples.tiled_capability_demo")
local summary = demo.run({
  mapPath = "maps/example.tmj",
  mapLayerName = "Ground",
  targetLayer = "background",
})
print(summary.map_id, summary.ruleset_count, summary.procedural_collider_count)
]]

local tiled_bridge = require("core.procgen.tiled_bridge")
local vendor = require("core.procgen.vendor")
local json = require("external.json")

local M = {}

local DEFAULTS = {
    mapPath = nil,
    mapId = nil,
    mapLayerName = nil,
    targetLayer = "background",
    drawMap = true,
    drawYSorted = true,
    drawLayerYSorted = true,
    drawBaseZ = 0,
    drawLayerStep = 1,
    drawZPerRow = 1,
    drawOffsetX = 0,
    drawOffsetY = 0,
    drawOpacity = 1.0,
    spawnObjects = true,
    rulesPaths = {
        "planning/tiled_assets/rulesets/dungeon_mode_walls.rules.txt",
        "planning/tiled_assets/rulesets/dungeon_437_walls.rules.txt",
    },
    useRulesCatalog = false,
    rulesCatalogPath = "planning/tiled_assets/rulesets/wall_rules_catalog.json",
    rulesCatalogLimit = 0,
    rulesCatalogIncludeModes = nil,
    rulesCatalogIncludeSources = nil,
    proceduralWidth = 24,
    proceduralHeight = 16,
    buildProceduralColliders = true,
    world = "world",
    physicsTag = "WORLD",
    solidValues = { 1 },
    cellSize = 16,
    printSummary = true,
}

local function log(msg)
    print("[tiled_capability_demo] " .. msg)
end

local function normalize_boolean(value, fallback)
    if value == nil then
        return fallback
    end
    return value
end

local function normalize_rules_paths(value)
    if type(value) == "string" then
        return { value }
    end

    if value == nil or type(value) ~= "table" then
        return {}
    end

    local out = {}
    for i = 1, #value do
        local path = value[i]
        if type(path) == "string" and path ~= "" then
            out[#out + 1] = path
        end
    end
    return out
end

local function normalize_string_set(value)
    if type(value) == "string" and value ~= "" then
        return { [value] = true }
    end

    if type(value) ~= "table" then
        return nil
    end

    local out = {}
    for i = 1, #value do
        local v = value[i]
        if type(v) == "string" and v ~= "" then
            out[v] = true
        end
    end

    local has_any = false
    for _ in pairs(out) do
        has_any = true
        break
    end

    if has_any then
        return out
    end
    return nil
end

local function read_text(path)
    if not path or path == "" then
        return nil
    end

    local function try_read(candidate)
        local f = io.open(candidate, "r")
        if not f then
            return nil
        end
        local content = f:read("*a")
        f:close()
        return content
    end

    if util and util.getRawAssetPathNoUUID then
        local resolved = util.getRawAssetPathNoUUID(path)
        if resolved and resolved ~= "" then
            local content = try_read(resolved)
            if content then
                return content
            end
        end
    end

    return try_read(path)
end

local function load_rules_paths_from_catalog(catalog_path, include_modes, include_sources, limit)
    local content = read_text(catalog_path)
    if not content then
        return {}, "unable to read catalog file"
    end

    local ok_decode, catalog = pcall(json.decode, content)
    if not ok_decode or type(catalog) ~= "table" then
        return {}, "unable to parse catalog json"
    end

    local entries = catalog.rulesets
    if type(entries) ~= "table" then
        return {}, "catalog missing rulesets array"
    end

    local dedupe = {}
    local out = {}
    for i = 1, #entries do
        local entry = entries[i]
        if type(entry) == "table" then
            local mode = entry.mode
            local source = entry.source
            local rules_path = entry.rules_path
            local mode_ok = (not include_modes) or (type(mode) == "string" and include_modes[mode] == true)
            local source_ok = (not include_sources) or (type(source) == "string" and include_sources[source] == true)
            if mode_ok and source_ok and type(rules_path) == "string" and rules_path ~= "" and not dedupe[rules_path] then
                dedupe[rules_path] = true
                out[#out + 1] = rules_path
                if limit and limit > 0 and #out >= limit then
                    break
                end
            end
        end
    end

    return out, nil
end

local function resolve_rules_paths(opts)
    local explicit_paths = normalize_rules_paths(opts.rulesPaths)
    if #explicit_paths > 0 then
        return explicit_paths, nil
    end

    local use_rules_catalog = normalize_boolean(opts.useRulesCatalog, DEFAULTS.useRulesCatalog)
    if use_rules_catalog then
        local include_modes = normalize_string_set(opts.rulesCatalogIncludeModes or DEFAULTS.rulesCatalogIncludeModes)
        local include_sources = normalize_string_set(opts.rulesCatalogIncludeSources or DEFAULTS.rulesCatalogIncludeSources)
        local rules_catalog_path = opts.rulesCatalogPath or DEFAULTS.rulesCatalogPath
        local rules_catalog_limit = opts.rulesCatalogLimit
        if rules_catalog_limit == nil then
            rules_catalog_limit = DEFAULTS.rulesCatalogLimit
        end

        local catalog_paths, catalog_err = load_rules_paths_from_catalog(
            rules_catalog_path,
            include_modes,
            include_sources,
            rules_catalog_limit
        )

        if #catalog_paths > 0 then
            return catalog_paths, nil
        end
        return DEFAULTS.rulesPaths, catalog_err
    end

    return DEFAULTS.rulesPaths, nil
end

local function count_tiles(result)
    if type(result) ~= "table" or type(result.cells) ~= "table" then
        return 0
    end
    local total = 0
    for i = 1, #result.cells do
        local cell = result.cells[i]
        if type(cell) == "table" then
            total = total + #cell
        end
    end
    return total
end

local function make_demo_grid(w, h)
    local g = vendor.Grid(w, h, 0)

    -- Outer border
    for x = 1, w do
        g:set(x, 1, 1)
        g:set(x, h, 1)
    end
    for y = 1, h do
        g:set(1, y, 1)
        g:set(w, y, 1)
    end

    -- Main horizontal + vertical corridors
    local midY = math.floor(h / 2)
    local midX = math.floor(w / 2)
    for x = 3, w - 2 do
        g:set(x, midY, 1)
    end
    for y = 3, h - 2 do
        g:set(midX, y, 1)
    end

    -- Additional branches to force corners, tees, and caps
    for y = 4, h - 4 do
        g:set(4, y, 1)
    end
    for x = w - 6, w - 3 do
        g:set(x, 4, 1)
    end
    for x = 6, 10 do
        g:set(x, h - 4, 1)
    end

    return g
end

local function default_spawner(obj)
    local id = obj.id or "?"
    local name = obj.name or ""
    local typ = obj.type or ""
    local layer = obj.layer or ""
    local x = tonumber(obj.x) or 0
    local y = tonumber(obj.y) or 0
    log(string.format("spawn object id=%s name=%s type=%s layer=%s at (%.1f, %.1f)", tostring(id), name, typ, layer, x, y))
end

function M.run(opts)
    opts = opts or {}
    local tiled = _G.tiled
    assert(tiled, "tiled bindings not available")

    local mapPath = opts.mapPath
    if mapPath == nil then mapPath = DEFAULTS.mapPath end
    local mapId = opts.mapId
    if mapId == nil then mapId = DEFAULTS.mapId end
    local mapLayerName = opts.mapLayerName
    if mapLayerName == nil then mapLayerName = DEFAULTS.mapLayerName end

    local drawMap = normalize_boolean(opts.drawMap, DEFAULTS.drawMap)
    local drawYSorted = normalize_boolean(opts.drawYSorted, DEFAULTS.drawYSorted)
    local drawLayerYSorted = normalize_boolean(opts.drawLayerYSorted, DEFAULTS.drawLayerYSorted)
    local spawnObjects = normalize_boolean(opts.spawnObjects, DEFAULTS.spawnObjects)
    local buildProceduralColliders = normalize_boolean(opts.buildProceduralColliders, DEFAULTS.buildProceduralColliders)
    local printSummary = normalize_boolean(opts.printSummary, DEFAULTS.printSummary)

    local targetLayer = opts.targetLayer or DEFAULTS.targetLayer
    local rulesPaths, rulesCatalogError = resolve_rules_paths(opts)
    local proceduralWidth = opts.proceduralWidth or DEFAULTS.proceduralWidth
    local proceduralHeight = opts.proceduralHeight or DEFAULTS.proceduralHeight
    local world = opts.world or DEFAULTS.world
    local physicsTag = opts.physicsTag or DEFAULTS.physicsTag
    local solidValues = opts.solidValues or DEFAULTS.solidValues
    local cellSize = opts.cellSize or DEFAULTS.cellSize

    local loadedMapId = mapId
    if mapPath and mapPath ~= "" then
        loadedMapId = tiled.load_map(mapPath)
    end
    if loadedMapId and loadedMapId ~= "" then
        tiled.set_active_map(loadedMapId)
    end

    local drawOpts = {
        map_id = loadedMapId,
        base_z = opts.drawBaseZ or DEFAULTS.drawBaseZ,
        layer_z_step = opts.drawLayerStep or DEFAULTS.drawLayerStep,
        z_per_row = opts.drawZPerRow or DEFAULTS.drawZPerRow,
        offset_x = opts.drawOffsetX or DEFAULTS.drawOffsetX,
        offset_y = opts.drawOffsetY or DEFAULTS.drawOffsetY,
        opacity = opts.drawOpacity or DEFAULTS.drawOpacity,
    }

    local drawAllCount = 0
    local drawAllYSortedCount = 0
    local drawLayerCount = 0
    local drawLayerYSortedCount = 0

    if drawMap and loadedMapId and loadedMapId ~= "" then
        drawAllCount = tiled_bridge.drawAllLayers(targetLayer, drawOpts)
        if drawYSorted then
            drawAllYSortedCount = tiled_bridge.drawAllLayersYSorted(targetLayer, drawOpts)
        end
        if mapLayerName and mapLayerName ~= "" then
            drawLayerCount = tiled_bridge.drawLayer(mapLayerName, targetLayer, drawOpts)
            if drawLayerYSorted then
                drawLayerYSortedCount = tiled_bridge.drawLayerYSorted(mapLayerName, targetLayer, drawOpts)
            end
        end
    end

    local objects = {}
    local objectCount = 0
    local spawnCount = 0

    if loadedMapId and loadedMapId ~= "" then
        objects = tiled_bridge.getObjects(loadedMapId)
        objectCount = #objects
        if spawnObjects then
            spawnCount = tiled_bridge.spawnObjects(loadedMapId, opts.spawner or default_spawner)
        end
    end

    local grid = opts.grid or make_demo_grid(proceduralWidth, proceduralHeight)
    local rulesetSummaries = {}
    for i = 1, #rulesPaths do
        local rulesPath = rulesPaths[i]
        local rulesetId = tiled_bridge.loadRuleDefs(rulesPath)
        local result = tiled_bridge.applyRules(grid, rulesetId)
        rulesetSummaries[#rulesetSummaries + 1] = {
            rules_path = rulesPath,
            ruleset_id = rulesetId,
            width = result and result.width or 0,
            height = result and result.height or 0,
            tile_count = count_tiles(result),
        }
    end

    local colliderCount = 0
    if buildProceduralColliders then
        colliderCount = tiled_bridge.buildColliders(grid, {
            worldName = world,
            physicsTag = physicsTag,
            solidValues = solidValues,
            cellSize = cellSize,
        })
    end

    local summary = {
        map_id = loadedMapId,
        draw_all_count = drawAllCount,
        draw_all_ysorted_count = drawAllYSortedCount,
        draw_layer_count = drawLayerCount,
        draw_layer_ysorted_count = drawLayerYSortedCount,
        object_count = objectCount,
        spawn_count = spawnCount,
        ruleset_count = #rulesetSummaries,
        rulesets = rulesetSummaries,
        procedural_collider_count = colliderCount,
        rules_catalog_error = rulesCatalogError,
    }

    if printSummary then
        log(string.format(
            "map=%s draw(all=%d ysort=%d layer=%d layer_ysort=%d) objects=%d spawn=%d rulesets=%d colliders=%d",
            tostring(summary.map_id),
            summary.draw_all_count,
            summary.draw_all_ysorted_count,
            summary.draw_layer_count,
            summary.draw_layer_ysorted_count,
            summary.object_count,
            summary.spawn_count,
            summary.ruleset_count,
            summary.procedural_collider_count
        ))
        for i = 1, #rulesetSummaries do
            local rule = rulesetSummaries[i]
            log(string.format(
                "ruleset[%d] id=%s path=%s size=%dx%d tiles=%d",
                i,
                tostring(rule.ruleset_id),
                tostring(rule.rules_path),
                rule.width,
                rule.height,
                rule.tile_count
            ))
        end
        if rulesCatalogError then
            log("catalog fallback: " .. tostring(rulesCatalogError))
        end
    end

    return summary
end

return M
