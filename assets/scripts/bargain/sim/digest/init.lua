-- assets/scripts/bargain/sim/digest/init.lua

local constants = require("bargain.sim.constants")

local digest = {}

digest.version = constants.DIGEST_VERSION

digest.METRICS = {
    "hp_lost_total",
    "turns_elapsed",
    "damage_dealt_total",
    "damage_taken_total",
    "forced_actions_count",
    "denied_actions_count",
    "visible_tiles_count",
    "resources_spent_total",
}

local function safe_num(value)
    if type(value) ~= "number" then
        return 0
    end
    return value
end

local function stats_string(stats)
    local parts = {}
    for _, key in ipairs(digest.METRICS) do
        parts[#parts + 1] = key .. "=" .. tostring(safe_num(stats[key]))
    end
    return table.concat(parts, ";")
end

function digest.compute(world)
    local seed = world.seed or 0
    local floor_num = world.floor_num or 0
    local turn = world.turn or 0
    local phase = world.phase or ""
    local run_state = world.run_state or ""
    local caps_hit = world.caps_hit and "1" or "0"

    local player = world.entities and world.entities.by_id and world.entities.by_id[world.player_id]
    local hp = player and player.hp or 0

    local stats = world.stats or {}
    local stats_blob = stats_string(stats)

    local deals = ""
    if world.deal_state and type(world.deal_state.chosen) == "table" then
        deals = table.concat(world.deal_state.chosen, ",")
    end

    return table.concat({
        digest.version,
        "seed=" .. seed,
        "floor=" .. floor_num,
        "turn=" .. turn,
        "phase=" .. phase,
        "run=" .. run_state,
        "caps=" .. caps_hit,
        "hp=" .. hp,
        "stats=" .. stats_blob,
        "deals=" .. deals,
    }, "|")
end

return digest
