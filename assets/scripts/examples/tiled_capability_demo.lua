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
    if value == nil then
        return DEFAULTS.rulesPaths
    end

    if type(value) == "string" then
        return { value }
    end

    if type(value) ~= "table" then
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
    local rulesPaths = normalize_rules_paths(opts.rulesPaths)
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
    end

    return summary
end

return M
