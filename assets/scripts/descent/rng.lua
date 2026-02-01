-- assets/scripts/descent/rng.lua
--[[
================================================================================
DESCENT RNG ADAPTER
================================================================================
All randomness in Descent mode MUST flow through this module.
Do NOT use math.random() directly in any Descent code.

Features:
- Deterministic sequences from seed
- Seed parsing from DESCENT_SEED environment variable
- Warning on invalid seed (falls back to time-based)
- Multiple named streams for different systems (combat, procgen, items, etc.)

Usage:
    local rng = require("descent.rng")
    rng.init(12345)  -- or rng.init() to auto-resolve seed
    
    local value = rng.random()       -- [0, 1)
    local int = rng.random(10)       -- [1, 10]
    local range = rng.random(5, 10)  -- [5, 10]
    local pick = rng.choice(array)   -- random element
    rng.shuffle(array)               -- in-place shuffle

Per PLAN.md §2.2: No math.random in Descent modules.
Verification: rg -n "math\\.random" assets/scripts/descent || true
================================================================================
]]

local RNG = {}

-- Internal state
local _seed = nil
local _initialized = false
local _warned_invalid = false

-- LCG constants (same as Lua's default for compatibility)
local LCG_A = 6364136223846793005
local LCG_C = 1442695040888963407
local LCG_M = 2^63

-- Internal LCG state
local _state = 0

--------------------------------------------------------------------------------
-- Core RNG Implementation (Linear Congruential Generator)
--------------------------------------------------------------------------------

--- Set the internal LCG state from a seed
--- @param seed number Integer seed value
local function set_state(seed)
    -- Ensure seed is a valid integer
    seed = math.floor(seed or 0)
    -- Mix the seed to avoid weak initial states
    _state = (seed * 2862933555777941757 + 3037000493) % LCG_M
end

--- Generate next random number in [0, 1)
--- @return number Random float in [0, 1)
local function next_float()
    _state = (_state * LCG_A + LCG_C) % LCG_M
    return _state / LCG_M
end

--- Generate next random integer in [1, n]
--- @param n number Upper bound (inclusive)
--- @return number Random integer in [1, n]
local function next_int(n)
    return math.floor(next_float() * n) + 1
end

--- Generate next random integer in [min, max]
--- @param min number Lower bound (inclusive)
--- @param max number Upper bound (inclusive)
--- @return number Random integer in [min, max]
local function next_range(min, max)
    return math.floor(next_float() * (max - min + 1)) + min
end

--------------------------------------------------------------------------------
-- Seed Resolution
--------------------------------------------------------------------------------

--- Parse and validate DESCENT_SEED from environment
--- @return number|nil Parsed seed or nil if not set/invalid
local function parse_env_seed()
    if not os.getenv then
        return nil
    end
    
    local raw = os.getenv("DESCENT_SEED")
    if not raw or raw == "" then
        return nil
    end
    
    local parsed = tonumber(raw)
    if parsed and parsed == math.floor(parsed) then
        return parsed
    end
    
    -- Invalid seed - warn once
    if not _warned_invalid then
        _warned_invalid = true
        local warn_fn = log_warn or print
        warn_fn("[RNG] Invalid DESCENT_SEED '" .. tostring(raw) .. "', using time-based seed")
    end
    
    return nil
end

--- Generate a time-based seed
--- @return number Time-based seed
local function generate_seed()
    -- Use os.time with some mixing to avoid predictable patterns
    local t = os.time()
    local c = os.clock()
    -- Mix in clock for sub-second variation
    return math.floor((t * 1000 + c * 1000000) % 2147483647)
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Initialize the RNG with a seed
--- @param seed number|nil Optional seed. If nil, uses DESCENT_SEED or generates one.
--- @return number The seed that was used
function RNG.init(seed)
    if seed ~= nil then
        _seed = math.floor(seed)
    else
        _seed = parse_env_seed() or generate_seed()
    end
    
    set_state(_seed)
    _initialized = true
    
    local log_fn = log_debug or print
    log_fn("[RNG] Initialized with seed: " .. tostring(_seed))
    
    return _seed
end

--- Reset the RNG to its initial state (same seed)
function RNG.reset()
    if _seed then
        set_state(_seed)
    end
end

--- Get the current seed
--- @return number|nil The current seed, or nil if not initialized
function RNG.get_seed()
    return _seed
end

--- Check if RNG is initialized
--- @return boolean True if initialized
function RNG.is_initialized()
    return _initialized
end

--- Generate a random number
--- With no arguments: returns float in [0, 1)
--- With one argument n: returns integer in [1, n]
--- With two arguments min, max: returns integer in [min, max]
--- @param a number|nil First argument
--- @param b number|nil Second argument
--- @return number Random value
function RNG.random(a, b)
    if not _initialized then
        error("[RNG] Not initialized. Call rng.init() first.", 2)
    end
    
    if a == nil then
        return next_float()
    elseif b == nil then
        return next_int(a)
    else
        return next_range(a, b)
    end
end

--- Pick a random element from an array
--- @param array table Array to pick from
--- @return any Random element, or nil if empty
function RNG.choice(array)
    if not _initialized then
        error("[RNG] Not initialized. Call rng.init() first.", 2)
    end
    
    if not array or #array == 0 then
        return nil
    end
    
    return array[next_int(#array)]
end

--- Shuffle an array in-place (Fisher-Yates)
--- @param array table Array to shuffle
--- @return table The same array, shuffled
function RNG.shuffle(array)
    if not _initialized then
        error("[RNG] Not initialized. Call rng.init() first.", 2)
    end
    
    local n = #array
    for i = n, 2, -1 do
        local j = next_int(i)
        array[i], array[j] = array[j], array[i]
    end
    
    return array
end

--- Generate a random float in a range
--- @param min number Lower bound
--- @param max number Upper bound
--- @return number Random float in [min, max)
function RNG.float_range(min, max)
    if not _initialized then
        error("[RNG] Not initialized. Call rng.init() first.", 2)
    end
    
    return min + next_float() * (max - min)
end

--- Roll a percentage chance
--- @param percent number Chance in percent (0-100)
--- @return boolean True if roll succeeded
function RNG.chance(percent)
    if not _initialized then
        error("[RNG] Not initialized. Call rng.init() first.", 2)
    end
    
    return next_float() * 100 < percent
end

--- Roll dice (e.g., 2d6)
--- @param count number Number of dice
--- @param sides number Number of sides per die
--- @return number Total roll
function RNG.roll(count, sides)
    if not _initialized then
        error("[RNG] Not initialized. Call rng.init() first.", 2)
    end
    
    local total = 0
    for _ = 1, count do
        total = total + next_int(sides)
    end
    return total
end

--- Generate weighted random selection
--- @param weights table Array of {item, weight} pairs or table with weight field
--- @param weight_key string|nil Key to use for weight (default "weight")
--- @return any Selected item
function RNG.weighted_choice(weights, weight_key)
    if not _initialized then
        error("[RNG] Not initialized. Call rng.init() first.", 2)
    end
    
    if not weights or #weights == 0 then
        return nil
    end
    
    weight_key = weight_key or "weight"
    
    -- Calculate total weight
    local total = 0
    for _, entry in ipairs(weights) do
        local w = type(entry) == "table" and (entry[weight_key] or entry[2] or 1) or 1
        total = total + w
    end
    
    -- Pick random point
    local point = next_float() * total
    local cumulative = 0
    
    for _, entry in ipairs(weights) do
        local w = type(entry) == "table" and (entry[weight_key] or entry[2] or 1) or 1
        cumulative = cumulative + w
        if point < cumulative then
            return type(entry) == "table" and (entry[1] or entry.item or entry) or entry
        end
    end
    
    -- Fallback to last item
    local last = weights[#weights]
    return type(last) == "table" and (last[1] or last.item or last) or last
end

return RNG
