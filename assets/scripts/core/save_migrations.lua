---@type table<number, fun(data: table): table>
local migrations = {}

-- Example migration (commented out - add real ones as needed):
-- migrations[2] = function(data)
--     data.statistics = data.statistics or {
--         runs_completed = 0,
--         highest_wave = 0,
--         total_kills = 0,
--     }
--     return data
-- end

return migrations
