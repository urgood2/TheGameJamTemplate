local SaveManager = require("core.save_manager")

local Statistics = {
    runs_completed = 0,
    highest_wave = 0,
    total_kills = 0,
    total_gold_earned = 0,
    playtime_seconds = 0,
}

-- Register with SaveManager
SaveManager.register("statistics", {
    collect = function()
        return {
            runs_completed = Statistics.runs_completed,
            highest_wave = Statistics.highest_wave,
            total_kills = Statistics.total_kills,
            total_gold_earned = Statistics.total_gold_earned,
            playtime_seconds = Statistics.playtime_seconds,
        }
    end,

    distribute = function(data)
        Statistics.runs_completed = data.runs_completed or 0
        Statistics.highest_wave = data.highest_wave or 0
        Statistics.total_kills = data.total_kills or 0
        Statistics.total_gold_earned = data.total_gold_earned or 0
        Statistics.playtime_seconds = data.playtime_seconds or 0
    end
})

--- Increment a statistic and trigger save
---@param stat string
---@param amount? number
function Statistics.increment(stat, amount)
    amount = amount or 1
    if Statistics[stat] ~= nil then
        Statistics[stat] = Statistics[stat] + amount
        SaveManager.save()
    end
end

--- Set a statistic if new value is higher
---@param stat string
---@param value number
function Statistics.set_high(stat, value)
    if Statistics[stat] ~= nil and value > Statistics[stat] then
        Statistics[stat] = value
        SaveManager.save()
    end
end

return Statistics
