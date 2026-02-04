-- assets/scripts/bargain/replay/replay.lua

local sim = require("bargain.sim")
local digest = require("bargain.sim.digest")
local victory = require("bargain.victory")
local death = require("bargain.death")
local loader = require("bargain.scripts.loader")
local constants = require("bargain.sim.constants")

local replay = {}

local GOLDEN_DIR = "assets/scripts/tests/bargain/goldens/scripts"

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

local function trim(s)
    if type(s) ~= "string" then
        return ""
    end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function replay.load_script_file(path)
    local chunk, err = loadfile(path)
    if not chunk then
        return nil, err
    end
    local ok, script = pcall(chunk)
    if not ok then
        return nil, script
    end
    return script
end

function replay.run_script(script, seed)
    local world = sim.new_world(seed or 1)
    if type(script.setup) == "function" then
        script.setup(world)
    end

    for _, input in ipairs(script.inputs or {}) do
        sim.step(world, input)
        if world.run_state ~= constants.RUN_STATES.RUNNING then
            break
        end
    end

    victory.check(world)
    death.check(world)

    return {
        world = world,
        digest = digest.compute(world),
        digest_version = digest.version,
    }
end

function replay.run_script_id(id, seed)
    local scripts = loader.load_all()
    local script = scripts.by_id and scripts.by_id[id] or nil
    if not script then
        return nil, "script_not_found"
    end
    return replay.run_script(script, seed)
end

function replay.verify_script(script, seed, golden_dir)
    local result = replay.run_script(script, seed)
    local dir = golden_dir or GOLDEN_DIR
    local script_id = script.id or "unknown"
    local golden_path = string.format("%s/%s.txt", dir, script_id)
    local golden = read_file(golden_path)
    if not golden then
        return false, "missing_golden", result
    end
    if trim(result.digest) ~= trim(golden) then
        return false, "digest_mismatch", result, golden
    end
    if result.world and result.world.run_state == constants.RUN_STATES.RUNNING then
        return false, "non_terminal", result, golden
    end
    return true, result, golden
end

function replay.verify_script_id(id, seed, golden_dir)
    local scripts = loader.load_all()
    local script = scripts.by_id and scripts.by_id[id] or nil
    if not script then
        return false, "script_not_found"
    end
    return replay.verify_script(script, seed, golden_dir)
end

return replay
