--[[
Tiled quickstart sample

What it does:
- Optionally loads a .tmj map and sets it active
- Draws all map tile layers (optionally y-sorted) into a target render layer
- Registers an object spawner and spawns map objects
- Loads a ruleset (rules.txt + runtime_json) and applies it to a sample procedural grid
- Builds physics colliders from that procedural grid

Usage (from Lua):
local tiled_demo = require("examples.tiled_quickstart")
local summary = tiled_demo.run({
  mapPath = "maps/example.tmj",
  targetLayer = "background",
  rulesPath = "planning/tiled_assets/rulesets/dungeon_mode_walls.rules.txt",
  world = "world",
})
print(summary.map_id, summary.draw_count, summary.spawn_count)
]]

local tiled_bridge = require("core.procgen.tiled_bridge")
local vendor = require("core.procgen.vendor")

local M = {}

local DEFAULTS = {
    mapPath = nil,
    mapId = nil,
    targetLayer = "background",
    drawMap = true,
    drawYSorted = true,
    drawBaseZ = 0,
    drawLayerStep = 1,
    drawZPerRow = 1,
    drawOffsetX = 0,
    drawOffsetY = 0,
    drawOpacity = 1.0,

    spawnObjects = true,

    rulesPath = "planning/tiled_assets/rulesets/dungeon_mode_walls.rules.txt",
    proceduralWidth = 16,
    proceduralHeight = 12,
    buildProceduralColliders = true,

    world = "world",
    physicsTag = "WORLD",
    solidValues = { 1 },
    cellSize = 16,

    printSummary = true,
}

local function log(msg)
    print("[tiled_quickstart] " .. msg)
end

local function make_sample_grid(w, h)
    local g = vendor.Grid(w, h, 0)

    -- Border walls.
    for x = 1, w do
        g:set(x, 1, 1)
        g:set(x, h, 1)
    end
    for y = 1, h do
        g:set(1, y, 1)
        g:set(w, y, 1)
    end

    -- Simple internal walls to exercise junction/corner rules.
    local mid_y = math.floor(h / 2)
    for x = 3, w - 2 do
        g:set(x, mid_y, 1)
    end
    local mid_x = math.floor(w / 2)
    for y = 3, h - 2 do
        g:set(mid_x, y, 1)
    end

    return g
end

local function default_spawner(obj)
    local name = obj.name or ""
    local typ = obj.type or ""
    local x = tonumber(obj.x) or 0
    local y = tonumber(obj.y) or 0
    local layer = obj.layer or ""
    log(string.format("object: id=%s name=%s type=%s layer=%s pos=(%.1f, %.1f)", tostring(obj.id), name, typ, layer, x, y))
end

function M.run(opts)
    opts = opts or {}
    local tiled = _G.tiled
    assert(tiled, "tiled bindings not available")

    local mapPath = opts.mapPath
    if mapPath == nil then mapPath = DEFAULTS.mapPath end
    local mapId = opts.mapId
    if mapId == nil then mapId = DEFAULTS.mapId end
    local targetLayer = opts.targetLayer or DEFAULTS.targetLayer

    local drawMap = opts.drawMap
    if drawMap == nil then drawMap = DEFAULTS.drawMap end
    local drawYSorted = opts.drawYSorted
    if drawYSorted == nil then drawYSorted = DEFAULTS.drawYSorted end

    local spawnObjects = opts.spawnObjects
    if spawnObjects == nil then spawnObjects = DEFAULTS.spawnObjects end

    local rulesPath = opts.rulesPath or DEFAULTS.rulesPath
    local proceduralWidth = opts.proceduralWidth or DEFAULTS.proceduralWidth
    local proceduralHeight = opts.proceduralHeight or DEFAULTS.proceduralHeight

    local buildProceduralColliders = opts.buildProceduralColliders
    if buildProceduralColliders == nil then
        buildProceduralColliders = DEFAULTS.buildProceduralColliders
    end

    local world = opts.world or DEFAULTS.world
    local physicsTag = opts.physicsTag or DEFAULTS.physicsTag
    local solidValues = opts.solidValues or DEFAULTS.solidValues
    local cellSize = opts.cellSize or DEFAULTS.cellSize

    local printSummary = opts.printSummary
    if printSummary == nil then printSummary = DEFAULTS.printSummary end

    local loadedMapId = mapId
    if mapPath and mapPath ~= "" then
        loadedMapId = tiled.load_map(mapPath)
    end
    if loadedMapId and loadedMapId ~= "" then
        tiled.set_active_map(loadedMapId)
    end

    local drawCount = 0
    if drawMap and loadedMapId and loadedMapId ~= "" then
        local drawOpts = {
            map_id = loadedMapId,
            base_z = opts.drawBaseZ or DEFAULTS.drawBaseZ,
            layer_z_step = opts.drawLayerStep or DEFAULTS.drawLayerStep,
            z_per_row = opts.drawZPerRow or DEFAULTS.drawZPerRow,
            offset_x = opts.drawOffsetX or DEFAULTS.drawOffsetX,
            offset_y = opts.drawOffsetY or DEFAULTS.drawOffsetY,
            opacity = opts.drawOpacity or DEFAULTS.drawOpacity,
        }

        if drawYSorted then
            drawCount = tiled_bridge.drawAllLayersYSorted(targetLayer, drawOpts)
        else
            drawCount = tiled_bridge.drawAllLayers(targetLayer, drawOpts)
        end
    end

    local spawnCount = 0
    if spawnObjects and loadedMapId and loadedMapId ~= "" then
        spawnCount = tiled_bridge.spawnObjects(loadedMapId, opts.spawner or default_spawner)
    end

    local rulesetId = nil
    local proceduralResult = nil
    local proceduralColliderCount = 0

    if rulesPath and rulesPath ~= "" then
        rulesetId = tiled_bridge.loadRuleDefs(rulesPath)
        local grid = opts.grid or make_sample_grid(proceduralWidth, proceduralHeight)
        proceduralResult = tiled_bridge.applyRules(grid, rulesetId)

        if buildProceduralColliders then
            proceduralColliderCount = tiled_bridge.buildColliders(grid, {
                worldName = world,
                physicsTag = physicsTag,
                solidValues = solidValues,
                cellSize = cellSize,
            })
        end
    end

    local summary = {
        map_id = loadedMapId,
        draw_count = drawCount,
        spawn_count = spawnCount,
        ruleset_id = rulesetId,
        procedural_width = proceduralResult and proceduralResult.width or 0,
        procedural_height = proceduralResult and proceduralResult.height or 0,
        procedural_collider_count = proceduralColliderCount,
    }

    if printSummary then
        log(string.format(
            "map=%s draw=%d spawn=%d ruleset=%s proc=%dx%d colliders=%d",
            tostring(summary.map_id),
            summary.draw_count,
            summary.spawn_count,
            tostring(summary.ruleset_id),
            summary.procedural_width,
            summary.procedural_height,
            summary.procedural_collider_count
        ))
    end

    return summary
end

return M
