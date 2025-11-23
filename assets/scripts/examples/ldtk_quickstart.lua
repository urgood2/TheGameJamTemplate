--[[
LDtk quickstart sample

What it does:
- Loads `assets/ldtk_config.json`
- Installs a simple entity spawner hook
- Sets an active level and rebuilds colliders in physics world "world"
- Prints a small summary so you can confirm the path worked

Usage (from anywhere in Lua):
local ldtk_demo = require("examples.ldtk_quickstart")
ldtk_demo.run({ level = "Level_0" })
]]

local M = {}

local DEFAULTS = {
    config = "ldtk_config.json",
    level = "Level_0",
    world = "world",
    physicsTag = "WORLD",
    rebuildColliders = true,
    spawnEntities = true,
    printSummary = true,
}

local function log(msg)
    print("[ldtk_quickstart] " .. msg)
end

local function defaultSpawner(name, px, py, layerName, gx, gy, tags)
    local prefabId = ldtk.prefab_for(name)

    if prefabId and prefabId ~= "" then
        local target = _G[prefabId]
        if type(target) == "function" then
            target(px, py)
            log(string.format("spawned %s via function %s at (%.1f, %.1f)", name, prefabId, px, py))
            return
        elseif type(target) == "table" and type(target.spawn) == "function" then
            target.spawn(target, px, py)
            log(string.format("spawned %s via table %s:spawn at (%.1f, %.1f)", name, prefabId, px, py))
            return
        end

        log(string.format("prefab %s mapped for %s but no callable spawn; position (%.1f, %.1f)", prefabId, name, px, py))
        return
    end

    log(string.format("no prefab mapping for %s (grid %s,%s layer %s)", name, tostring(gx), tostring(gy), tostring(layerName)))
end

local function summarize(level, colliderLayers)
    log("active level: " .. level)
    log("collider layers: " .. (table.concat(colliderLayers, ", ")))

    local layerName = colliderLayers[1]
    if not layerName then
        log("no collider layers configured; skipping IntGrid summary")
        return
    end

    local ok, result = pcall(function()
        local count = 0
        ldtk.each_intgrid(level, layerName, function(_, _, val)
            if val ~= 0 then count = count + 1 end
        end)
        return count
    end)

    if ok then
        log(string.format("IntGrid '%s': %d solid cells", layerName, result))
    else
        log(string.format("IntGrid '%s' read failed: %s", layerName, tostring(result)))
    end
end

function M.run(opts)
    opts = opts or {}

    local config = opts.config or DEFAULTS.config
    local level = opts.level or DEFAULTS.level
    local world = opts.world or DEFAULTS.world
    local physicsTag = opts.physicsTag or DEFAULTS.physicsTag
    local rebuildColliders = opts.rebuildColliders
    if rebuildColliders == nil then rebuildColliders = DEFAULTS.rebuildColliders end
    local spawnEntities = opts.spawnEntities
    if spawnEntities == nil then spawnEntities = DEFAULTS.spawnEntities end
    local printSummary = opts.printSummary
    if printSummary == nil then printSummary = DEFAULTS.printSummary end

    ldtk.load_config(config)

    if opts.spawner ~= false then
        ldtk.set_spawner(opts.spawner or defaultSpawner)
    end

    if not globals.physicsWorld then
        log("globals.physicsWorld is nil; collider generation will warn unless you initialize physics first")
    end

    ldtk.set_active_level(level, world, rebuildColliders, spawnEntities, physicsTag)

    if printSummary then
        summarize(level, ldtk.collider_layers())
    end
end

return M
