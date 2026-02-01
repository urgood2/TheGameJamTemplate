-- assets/scripts/descent/state.lua
--[[
================================================================================
DESCENT STATE MODULE
================================================================================
Central game state container for Descent roguelike mode.

All game state is encapsulated here to prevent global state leaks.
Provides clean reset for new games.

State sections:
- Game: seed, floor, turn, active
- Player: position, stats, inventory
- Map: tiles, dimensions, explored
- Enemies: enemy list
- UI: open panels, selection state
- Floor cache: persisted floor data for backtracking

Usage:
    local state = require("descent.state")
    state.init(seed)
    state.player.x = 5
    state.reset()  -- Clean slate for new game
================================================================================
]]

local M = {}

-- Dependencies
local spec = require("descent.spec")

--------------------------------------------------------------------------------
-- Default State Templates
--------------------------------------------------------------------------------

local function create_default_game()
    return {
        seed = 0,
        floor = 1,
        turn = 0,
        active = false,
        paused = false,
        game_over = false,
        victory = false,
    }
end

local function create_default_player()
    return {
        x = 1,
        y = 1,
        hp = spec.stats.hp.base,
        max_hp = spec.stats.hp.base,
        mp = spec.stats.mp.base,
        max_mp = spec.stats.mp.base,
        level = spec.stats.starting_level,
        xp = 0,
        xp_to_next = spec.stats.xp.base,
        gold = 0,
        stats = {
            str = spec.stats.base_attributes.str,
            dex = spec.stats.base_attributes.dex,
            int = spec.stats.base_attributes.int,
        },
        species_id = "human",
        background_id = "gladiator",
        skills = {},
        inventory = nil,  -- Set by items module
        god = nil,
        piety = 0,
    }
end

local function create_default_map()
    return {
        width = 0,
        height = 0,
        tiles = {},
        explored = {},
        visible = {},
        features = {},  -- Special features like stairs, shops, altars
    }
end

local function create_default_enemies()
    return {
        list = {},  -- Array of enemy entities
        next_id = 1,
    }
end

local function create_default_ui()
    return {
        inventory_open = false,
        character_open = false,
        shop_open = false,
        message_log = {},
        targeting_mode = false,
        targeting_callback = nil,
        selection_index = 1,
    }
end

--------------------------------------------------------------------------------
-- State Container
--------------------------------------------------------------------------------

-- The actual state (module-level, not global)
local state = {
    game = create_default_game(),
    player = create_default_player(),
    map = create_default_map(),
    enemies = create_default_enemies(),
    ui = create_default_ui(),
    floor_cache = {},  -- [floor_num] = { map, enemies, items }
}

--------------------------------------------------------------------------------
-- Public API: State Access
--------------------------------------------------------------------------------

-- Expose state sections as module fields
M.game = state.game
M.player = state.player
M.map = state.map
M.enemies = state.enemies
M.ui = state.ui
M.floor_cache = state.floor_cache

--------------------------------------------------------------------------------
-- Public API: Initialization
--------------------------------------------------------------------------------

--- Initialize state for a new game
--- @param seed number Run seed
--- @param player_data table|nil Optional player data from character creation
function M.init(seed, player_data)
    state.game = create_default_game()
    state.game.seed = seed or 0
    state.game.active = true
    
    state.player = create_default_player()
    if player_data then
        for k, v in pairs(player_data) do
            state.player[k] = v
        end
        -- Apply stats from player_data
        if player_data.stats then
            state.player.stats = player_data.stats
        end
        if player_data.hp then
            state.player.hp = player_data.hp
            state.player.max_hp = player_data.max_hp or player_data.hp
        end
        if player_data.mp then
            state.player.mp = player_data.mp
            state.player.max_mp = player_data.max_mp or player_data.mp
        end
    end
    
    state.map = create_default_map()
    state.enemies = create_default_enemies()
    state.ui = create_default_ui()
    state.floor_cache = {}
    
    -- Update module references
    M.game = state.game
    M.player = state.player
    M.map = state.map
    M.enemies = state.enemies
    M.ui = state.ui
    M.floor_cache = state.floor_cache
end

--- Reset all state (for menu return)
function M.reset()
    state.game = create_default_game()
    state.player = create_default_player()
    state.map = create_default_map()
    state.enemies = create_default_enemies()
    state.ui = create_default_ui()
    state.floor_cache = {}
    
    M.game = state.game
    M.player = state.player
    M.map = state.map
    M.enemies = state.enemies
    M.ui = state.ui
    M.floor_cache = state.floor_cache
end

--------------------------------------------------------------------------------
-- Public API: Floor Management
--------------------------------------------------------------------------------

--- Cache current floor state (for backtracking)
function M.cache_current_floor()
    local floor_num = state.game.floor
    state.floor_cache[floor_num] = {
        map = M.copy_table(state.map),
        enemies = M.copy_table(state.enemies),
    }
end

--- Restore cached floor state
--- @param floor_num number Floor to restore
--- @return boolean True if restored
function M.restore_floor(floor_num)
    local cached = state.floor_cache[floor_num]
    if not cached then
        return false
    end
    
    state.map = M.copy_table(cached.map)
    state.enemies = M.copy_table(cached.enemies)
    state.game.floor = floor_num
    
    M.map = state.map
    M.enemies = state.enemies
    
    return true
end

--- Check if floor is cached
--- @param floor_num number Floor number
--- @return boolean
function M.is_floor_cached(floor_num)
    return state.floor_cache[floor_num] ~= nil
end

--------------------------------------------------------------------------------
-- Public API: Turn Management
--------------------------------------------------------------------------------

--- Advance turn counter
function M.advance_turn()
    state.game.turn = state.game.turn + 1
end

--- Get current turn
--- @return number
function M.get_turn()
    return state.game.turn
end

--------------------------------------------------------------------------------
-- Public API: Game Flow
--------------------------------------------------------------------------------

--- Set game over state
--- @param victory boolean True for victory, false for death
--- @param reason string|nil Reason for game over
function M.set_game_over(victory, reason)
    state.game.game_over = true
    state.game.victory = victory
    state.game.active = false
    state.game.end_reason = reason
end

--- Check if game is over
--- @return boolean
function M.is_game_over()
    return state.game.game_over
end

--- Check if game is active
--- @return boolean
function M.is_active()
    return state.game.active and not state.game.game_over
end

--- Pause/unpause game
--- @param paused boolean
function M.set_paused(paused)
    state.game.paused = paused
end

--- Check if paused
--- @return boolean
function M.is_paused()
    return state.game.paused
end

--------------------------------------------------------------------------------
-- Public API: Message Log
--------------------------------------------------------------------------------

--- Add message to log
--- @param message string Message text
--- @param category string|nil Message category (combat, pickup, etc.)
function M.log_message(message, category)
    table.insert(state.ui.message_log, {
        text = message,
        category = category,
        turn = state.game.turn,
        timestamp = os.time(),
    })
    
    -- Limit log size
    while #state.ui.message_log > 100 do
        table.remove(state.ui.message_log, 1)
    end
end

--- Get recent messages
--- @param count number|nil Number of messages (default 10)
--- @return table Array of messages
function M.get_recent_messages(count)
    count = count or 10
    local result = {}
    local start = math.max(1, #state.ui.message_log - count + 1)
    for i = start, #state.ui.message_log do
        table.insert(result, state.ui.message_log[i])
    end
    return result
end

--------------------------------------------------------------------------------
-- Public API: Serialization
--------------------------------------------------------------------------------

--- Get full state for saving
--- @return table Serializable state
function M.get_save_data()
    return {
        version = 1,
        game = M.copy_table(state.game),
        player = M.copy_table(state.player),
        map = M.copy_table(state.map),
        enemies = M.copy_table(state.enemies),
        floor_cache = M.copy_table(state.floor_cache),
    }
end

--- Load state from save data
--- @param data table Saved state
function M.load_save_data(data)
    if not data or data.version ~= 1 then
        return false
    end
    
    state.game = data.game or create_default_game()
    state.player = data.player or create_default_player()
    state.map = data.map or create_default_map()
    state.enemies = data.enemies or create_default_enemies()
    state.floor_cache = data.floor_cache or {}
    
    -- Reset UI (don't persist)
    state.ui = create_default_ui()
    
    M.game = state.game
    M.player = state.player
    M.map = state.map
    M.enemies = state.enemies
    M.ui = state.ui
    M.floor_cache = state.floor_cache
    
    return true
end

--------------------------------------------------------------------------------
-- Utility
--------------------------------------------------------------------------------

--- Deep copy a table
--- @param t any Value to copy
--- @return any Copied value
function M.copy_table(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = M.copy_table(v)
    end
    return copy
end

--- Get debug summary
--- @return string State summary
function M.get_summary()
    return string.format(
        "Descent State: seed=%d floor=%d turn=%d player@(%d,%d) hp=%d/%d",
        state.game.seed,
        state.game.floor,
        state.game.turn,
        state.player.x,
        state.player.y,
        state.player.hp,
        state.player.max_hp
    )
end

return M
