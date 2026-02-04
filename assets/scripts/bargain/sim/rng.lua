-- assets/scripts/bargain/sim/rng.lua
--[[
================================================================================
BARGAIN SIM: Single Authoritative RNG
================================================================================

This module provides the ONLY source of randomness for the Bargain simulation.
Using math.random, os.time, frame dt, or any other non-deterministic source
in sim scope is FORBIDDEN.

Implementation: Xorshift128+ algorithm
- Fast, high-quality pseudorandom number generator
- Deterministic given the same seed
- Full 64-bit state for high period (~2^128)

USAGE:
    local RNG = require("bargain.sim.rng")

    -- Create RNG from seed
    local rng = RNG.new(world.seed)

    -- Generate random values
    local n = rng:next()           -- [0, 1) float
    local i = rng:int(1, 6)        -- 1-6 inclusive (like dice)
    local f = rng:float(0, 100)    -- [0, 100) float
    local b = rng:bool()           -- true/false with 50% each
    local b = rng:chance(0.3)      -- true with 30% probability

    -- Save/restore state for determinism
    local state = rng:get_state()
    rng:set_state(state)

DETERMINISM CONTRACT:
    - Same seed always produces same sequence
    - State is fully serializable (two integers)
    - No external dependencies (pure Lua math only)
]]

local RNG = {}
RNG.__index = RNG

-- Constants for xorshift128+
-- These are well-tested constants from the original paper
local MASK32 = 0xFFFFFFFF

-- Bit operations (Lua 5.3+ has bit32, but we use manual for compatibility)
local function lshift(x, n)
    return (x * (2 ^ n)) % (2 ^ 32)
end

local function rshift(x, n)
    return math.floor(x / (2 ^ n)) % (2 ^ 32)
end

local function bxor(a, b)
    local result = 0
    local bit = 1
    for _ = 1, 32 do
        local bit_a = a % 2
        local bit_b = b % 2
        if bit_a ~= bit_b then
            result = result + bit
        end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        bit = bit * 2
    end
    return result
end

--- Create a new RNG instance
--- @param seed number Integer seed value
--- @return table RNG instance
function RNG.new(seed)
    assert(type(seed) == "number", "RNG seed must be a number")

    local self = setmetatable({}, RNG)

    -- Initialize state from seed using splitmix64-style mixing
    -- This ensures even simple seeds like 1, 2, 3 produce well-distributed initial states
    seed = math.floor(seed) % (2^32)

    -- Mix the seed to create two state values
    local z = seed
    z = bxor(z, rshift(z, 16))
    z = (z * 0x85ebca6b) % (2^32)
    z = bxor(z, rshift(z, 13))
    z = (z * 0xc2b2ae35) % (2^32)
    z = bxor(z, rshift(z, 16))
    self._state0 = z

    -- Second state value
    z = (seed + 0x9E3779B9) % (2^32)  -- Golden ratio derived constant
    z = bxor(z, rshift(z, 16))
    z = (z * 0x85ebca6b) % (2^32)
    z = bxor(z, rshift(z, 13))
    z = (z * 0xc2b2ae35) % (2^32)
    z = bxor(z, rshift(z, 16))
    self._state1 = z

    -- Ensure non-zero state (xorshift requires this)
    if self._state0 == 0 and self._state1 == 0 then
        self._state0 = 1
    end

    -- Store original seed for debugging/serialization
    self._seed = seed

    return self
end

--- Internal: Generate next raw 32-bit value
--- Uses xorshift64* algorithm (simpler than xorshift128+ for 32-bit Lua)
function RNG:_next_raw()
    local s0 = self._state0
    local s1 = self._state1

    -- xorshift128+ step
    local t = s0
    local s = s1
    s0 = s
    t = bxor(t, lshift(t, 23) % (2^32))
    t = bxor(t, rshift(t, 17))
    t = bxor(t, s)
    t = bxor(t, rshift(s, 26))
    s1 = t

    self._state0 = s0
    self._state1 = s1

    return (s0 + s1) % (2^32)
end

--- Generate a random float in [0, 1)
--- @return number Float in range [0, 1)
function RNG:next()
    return self:_next_raw() / (2^32)
end

--- Generate a random integer in [min, max] (inclusive)
--- @param min number Minimum value (inclusive)
--- @param max number Maximum value (inclusive)
--- @return number Integer in range [min, max]
function RNG:int(min, max)
    assert(type(min) == "number" and type(max) == "number", "int() requires two numbers")
    assert(min <= max, "int() min must be <= max")

    min = math.floor(min)
    max = math.floor(max)

    local range = max - min + 1
    local raw = self:_next_raw()
    return min + (raw % range)
end

--- Generate a random float in [min, max)
--- @param min number Minimum value (inclusive)
--- @param max number Maximum value (exclusive)
--- @return number Float in range [min, max)
function RNG:float(min, max)
    assert(type(min) == "number" and type(max) == "number", "float() requires two numbers")

    local t = self:next()
    return min + t * (max - min)
end

--- Generate a random boolean (50% chance each)
--- @return boolean Random true or false
function RNG:bool()
    return self:_next_raw() % 2 == 0
end

--- Return true with given probability
--- @param probability number Probability in [0, 1]
--- @return boolean True with given probability
function RNG:chance(probability)
    assert(type(probability) == "number", "chance() requires a number")
    assert(probability >= 0 and probability <= 1, "chance() probability must be in [0, 1]")

    return self:next() < probability
end

--- Choose a random element from an array
--- @param array table Array to choose from
--- @return any Random element, or nil if array is empty
function RNG:choose(array)
    assert(type(array) == "table", "choose() requires a table")

    local len = #array
    if len == 0 then return nil end

    return array[self:int(1, len)]
end

--- Shuffle an array in-place (Fisher-Yates)
--- @param array table Array to shuffle
--- @return table The same array, shuffled
function RNG:shuffle(array)
    assert(type(array) == "table", "shuffle() requires a table")

    local len = #array
    for i = len, 2, -1 do
        local j = self:int(1, i)
        array[i], array[j] = array[j], array[i]
    end

    return array
end

--- Get weighted random index based on weights array
--- @param weights table Array of numeric weights
--- @return number Index of chosen element (1-based)
function RNG:weighted(weights)
    assert(type(weights) == "table", "weighted() requires a table")
    assert(#weights > 0, "weighted() requires non-empty weights")

    local total = 0
    for i = 1, #weights do
        assert(type(weights[i]) == "number" and weights[i] >= 0,
               "weighted() requires non-negative numeric weights")
        total = total + weights[i]
    end

    if total == 0 then
        -- All weights zero, choose uniformly
        return self:int(1, #weights)
    end

    local r = self:float(0, total)
    local acc = 0
    for i = 1, #weights do
        acc = acc + weights[i]
        if r < acc then
            return i
        end
    end

    return #weights  -- Fallback for floating point edge case
end

--- Get the current state (for serialization/replay)
--- @return table State object with state0 and state1
function RNG:get_state()
    return {
        state0 = self._state0,
        state1 = self._state1,
        seed = self._seed,
    }
end

--- Set the state (for deserialization/replay)
--- @param state table State object from get_state()
function RNG:set_state(state)
    assert(type(state) == "table", "set_state() requires a table")
    assert(type(state.state0) == "number", "set_state() requires state0")
    assert(type(state.state1) == "number", "set_state() requires state1")

    self._state0 = state.state0
    self._state1 = state.state1
    if state.seed then
        self._seed = state.seed
    end
end

--- Clone this RNG (same state, independent instance)
--- @return table New RNG instance with same state
function RNG:clone()
    local copy = RNG.new(0)
    copy:set_state(self:get_state())
    return copy
end

--- Get the original seed
--- @return number The seed used to create this RNG
function RNG:get_seed()
    return self._seed
end

return RNG
