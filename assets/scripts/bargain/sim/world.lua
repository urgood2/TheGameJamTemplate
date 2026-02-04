-- assets/scripts/bargain/sim/world.lua
--[[
================================================================================
BARGAIN SIM: World State Schema
================================================================================

The World object contains all state needed to run and replay a Bargain game.
It is designed to be:
1. Fully serializable (for save/load and repro JSON)
2. Deterministic (all randomness flows through world.rng)
3. Minimal (only essential game state)

REQUIRED FIELDS:
- seed: number              Original seed for deterministic replay
- rng: table               RNG state (seeded from seed)
- turn: number             Current turn number (0-indexed)
- floor_num: number        Current floor (1-7)
- phase: string            Current game phase
- run_state: string        "running", "victory", or "death"
- caps_hit: table          Map of cap_name -> count
- player_id: number        Entity ID of the player
- grid: table              2D tile grid
- entities: table          Entity registry (id -> entity)
- deal_state: table|nil    Current deal offer state
- stats: table             Run statistics
]]

local World = {}

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

--- Valid game phases
World.PHASES = {
    player_turn = "player_turn",
    enemy_turn = "enemy_turn",
    offer = "offer",
    floor_transition = "floor_transition",
    terminal = "terminal",
}

--- Valid run states
World.RUN_STATES = {
    running = "running",
    victory = "victory",
    death = "death",
}

--- Cap names tracked in the MVP
World.CAPS = {
    turn_limit = "turn_limit",          -- Max turns per floor
    damage_cap = "damage_cap",          -- Max damage per hit
    heal_cap = "heal_cap",              -- Max heal per action
    entity_cap = "entity_cap",          -- Max entities per floor
}

--------------------------------------------------------------------------------
-- Simple Seeded RNG
--------------------------------------------------------------------------------

--- Create a new RNG from a seed
--- Uses a simple LCG (Linear Congruential Generator)
--- @param seed number Integer seed
--- @return table rng RNG state with :next() method
local function create_rng(seed)
    -- Ensure seed is a positive integer
    seed = math.abs(math.floor(seed)) % 2147483647
    if seed == 0 then seed = 1 end
    
    local state = seed
    
    return {
        seed = seed,
        state = state,
        
        --- Get next random integer [0, max)
        --- @param max number Upper bound (exclusive)
        --- @return number
        next = function(self, max)
            -- LCG parameters (same as glibc)
            self.state = (self.state * 1103515245 + 12345) % 2147483648
            return self.state % max
        end,
        
        --- Get next random float [0, 1)
        --- @return number
        next_float = function(self)
            return self:next(1000000) / 1000000
        end,
        
        --- Get random integer in range [min, max] (inclusive)
        --- @param min number Lower bound
        --- @param max number Upper bound
        --- @return number
        range = function(self, min, max)
            return min + self:next(max - min + 1)
        end,
        
        --- Serialize RNG state for save/load
        --- @return table
        serialize = function(self)
            return {seed = self.seed, state = self.state}
        end,
    }
end

--- Restore RNG from serialized state
--- @param data table Serialized RNG {seed, state}
--- @return table rng
local function restore_rng(data)
    local rng = create_rng(data.seed)
    rng.state = data.state
    return rng
end

--------------------------------------------------------------------------------
-- World Schema
--------------------------------------------------------------------------------

--- Required fields in a World object
World.REQUIRED_FIELDS = {
    "seed",
    "rng",
    "turn",
    "floor_num",
    "phase",
    "run_state",
    "caps_hit",
    "player_id",
    "grid",
    "entities",
    "deal_state",
    "stats",
}

--- Create a new World with default values
--- @param seed number Optional seed (defaults to 0)
--- @return table world
function World.create(seed)
    seed = seed or 0
    
    return {
        -- Core state
        seed = seed,
        rng = create_rng(seed),
        turn = 0,
        floor_num = 1,
        phase = World.PHASES.player_turn,
        run_state = World.RUN_STATES.running,
        
        -- Caps tracking
        caps_hit = {
            turn_limit = 0,
            damage_cap = 0,
            heal_cap = 0,
            entity_cap = 0,
        },
        
        -- Entity state
        player_id = 1,  -- Player always has ID 1
        grid = {},      -- 2D grid, populated by floor generator
        entities = {},  -- id -> entity mapping
        
        -- Deal state (nil when no offer pending)
        deal_state = nil,
        
        -- Statistics
        stats = {
            turns_total = 0,
            damage_dealt = 0,
            damage_taken = 0,
            deals_accepted = 0,
            deals_declined = 0,
            enemies_killed = 0,
        },
    }
end

--- Validate a World object has all required fields
--- @param world table Object to validate
--- @return boolean ok, string|nil error_message
function World.validate(world)
    if type(world) ~= "table" then
        return false, "World must be a table"
    end
    
    -- Check required fields
    for _, field in ipairs(World.REQUIRED_FIELDS) do
        if world[field] == nil then
            return false, string.format("World missing required field: '%s'", field)
        end
    end
    
    -- Validate seed
    if type(world.seed) ~= "number" then
        return false, "World.seed must be a number"
    end
    
    -- Validate rng
    if type(world.rng) ~= "table" or type(world.rng.next) ~= "function" then
        return false, "World.rng must be an RNG object with :next() method"
    end
    
    -- Validate turn
    if type(world.turn) ~= "number" or world.turn < 0 then
        return false, "World.turn must be a non-negative number"
    end
    
    -- Validate floor_num
    if type(world.floor_num) ~= "number" or world.floor_num < 1 or world.floor_num > 7 then
        return false, "World.floor_num must be 1-7"
    end
    
    -- Validate phase
    if not World.PHASES[world.phase] then
        return false, string.format("Invalid World.phase: '%s'", tostring(world.phase))
    end
    
    -- Validate run_state
    if not World.RUN_STATES[world.run_state] then
        return false, string.format("Invalid World.run_state: '%s'", tostring(world.run_state))
    end
    
    -- Validate caps_hit
    if type(world.caps_hit) ~= "table" then
        return false, "World.caps_hit must be a table"
    end
    
    -- Validate player_id
    if type(world.player_id) ~= "number" then
        return false, "World.player_id must be a number"
    end
    
    -- Validate grid
    if type(world.grid) ~= "table" then
        return false, "World.grid must be a table"
    end
    
    -- Validate entities
    if type(world.entities) ~= "table" then
        return false, "World.entities must be a table"
    end
    
    -- deal_state can be nil or table
    if world.deal_state ~= nil and type(world.deal_state) ~= "table" then
        return false, "World.deal_state must be nil or a table"
    end
    
    -- Validate stats
    if type(world.stats) ~= "table" then
        return false, "World.stats must be a table"
    end
    
    return true, nil
end

--- Serialize a World for save/load or repro JSON
--- @param world table World to serialize
--- @return table serialized
function World.serialize(world)
    return {
        seed = world.seed,
        rng = world.rng:serialize(),
        turn = world.turn,
        floor_num = world.floor_num,
        phase = world.phase,
        run_state = world.run_state,
        caps_hit = world.caps_hit,
        player_id = world.player_id,
        grid = world.grid,
        entities = world.entities,
        deal_state = world.deal_state,
        stats = world.stats,
    }
end

--- Deserialize a World from saved data
--- @param data table Serialized world data
--- @return table world, string|nil error
function World.deserialize(data)
    if type(data) ~= "table" then
        return nil, "Serialized world must be a table"
    end
    
    local world = {
        seed = data.seed,
        rng = restore_rng(data.rng),
        turn = data.turn,
        floor_num = data.floor_num,
        phase = data.phase,
        run_state = data.run_state,
        caps_hit = data.caps_hit,
        player_id = data.player_id,
        grid = data.grid,
        entities = data.entities,
        deal_state = data.deal_state,
        stats = data.stats,
    }
    
    local ok, err = World.validate(world)
    if not ok then
        return nil, err
    end
    
    return world, nil
end

--------------------------------------------------------------------------------
-- RNG Export (for testing)
--------------------------------------------------------------------------------

World.create_rng = create_rng
World.restore_rng = restore_rng

--------------------------------------------------------------------------------
-- Module Export
--------------------------------------------------------------------------------

return World
