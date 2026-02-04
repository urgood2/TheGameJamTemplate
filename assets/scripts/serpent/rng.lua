-- Serpent RNG module
-- Deterministic PRNG implementations that do not touch math.randomseed.

require("init.bit_compat")

local rng = {}

---@class SerpentRNG
---@field next fun(self: SerpentRNG): number Returns [0, 1)
---@field next_u32 fun(self: SerpentRNG): number Returns unsigned 32-bit int
---@field int fun(self: SerpentRNG, min: number, max: number): number Returns min..max inclusive
---@field float fun(self: SerpentRNG, min: number, max: number): number Returns [min, max)
---@field reseed fun(self: SerpentRNG, seed: number): nil
---@field seed number Seed used to initialize RNG (for HUD/debug display)

local UINT32_MAX = 0xFFFFFFFF
local UINT32_MOD = 0x100000000

local function normalize_seed_u32(seed)
    if type(seed) ~= "number" then
        seed = tonumber(seed) or 0
    end
    seed = math.floor(seed)
    seed = seed % UINT32_MOD
    if seed == 0 then
        -- Avoid xorshift zero lockup.
        seed = 0x6D2B79F5
    end
    return seed
end

local function attach_common(self, modulus)
    function self:next()
        return self:next_u32() / modulus
    end

    function self:int(min, max)
        if max == nil then
            max = min
            min = 1
        end
        if min == max then return min end
        local range = max - min + 1
        return math.floor(self:next() * range) + min
    end

    function self:float(min, max)
        if min == nil then
            -- No arguments: return [0, 1)
            return self:next()
        elseif max == nil then
            -- One argument: treat as max, min = 0
            max = min
            min = 0
        end
        return min + (max - min) * self:next()
    end

    function self:choice(list)
        if not list or #list == 0 then
            return nil
        end
        local index = self:int(1, #list)
        return list[index]
    end
end

local function make_xorshift(seed)
    local self = {}
    self._state = normalize_seed_u32(seed)
    self.seed = self._state

    function self:reseed(new_seed)
        self._state = normalize_seed_u32(new_seed)
        self.seed = self._state
    end

    function self:next_u32()
        local x = bit.tobit(self._state)
        x = bit.bxor(x, bit.lshift(x, 13))
        x = bit.bxor(x, bit.rshift(x, 17))
        x = bit.bxor(x, bit.lshift(x, 5))
        self._state = bit.band(x, UINT32_MAX)
        return self._state
    end

    attach_common(self, UINT32_MOD)
    return self
end

-- LCG parameters (same as procgen; kept within 2^31 for portability)
local LCG_A = 1103515245
local LCG_C = 12345
local LCG_M = 2^31

local function normalize_seed_lcg(seed)
    if type(seed) ~= "number" then
        seed = tonumber(seed) or 0
    end
    seed = math.floor(seed) % LCG_M
    return seed
end

local function make_lcg(seed)
    local self = {}
    self._state = normalize_seed_lcg(seed)
    self.seed = self._state

    function self:reseed(new_seed)
        self._state = normalize_seed_lcg(new_seed)
        self.seed = self._state
    end

    function self:next_u32()
        self._state = (LCG_A * self._state + LCG_C) % LCG_M
        return self._state
    end

    attach_common(self, LCG_M)
    return self
end

--- Create a new RNG.
--- @param seed number
--- @param algorithm string|nil "xorshift" (default) or "lcg"
--- @return SerpentRNG
function rng.create(seed, algorithm)
    if algorithm == "lcg" then
        return make_lcg(seed)
    end
    return make_xorshift(seed)
end

-- Alias for callers that prefer procgen-style naming.
function rng.create_rng(seed, algorithm)
    return rng.create(seed, algorithm)
end

-- Primary constructor (plan spec: RNG.new(seed))
function rng.new(seed, algorithm)
    return rng.create(seed, algorithm)
end

return rng
