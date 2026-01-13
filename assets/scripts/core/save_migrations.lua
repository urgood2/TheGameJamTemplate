---@type table<number, fun(data: table): table>
local migrations = {}

-- Migration from v1 to v2: Add grid_inventory support
-- Legacy saves without grid_inventory key will have cards placed sequentially on load
migrations[2] = function(data)
    -- Initialize empty grid_inventory structure
    -- The actual card data will be populated when the game loads
    -- and detects no grid positions, placing cards sequentially
    if not data.grid_inventory then
        data.grid_inventory = {
            version = 1,
            player_inventory = nil,  -- Will trigger sequential placement
            wand_loadouts = nil,     -- Will trigger sequential placement
        }
        print("[SaveMigrations] v1→v2: Added empty grid_inventory (legacy mode)")
    end
    return data
end

return migrations
