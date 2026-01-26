--[[
================================================================================
procgen.lua - Procedural Generation DSL
================================================================================
Declarative DSL for procedural content generation: ranges, loot tables, etc.

All random operations require an RNG object for deterministic seeding.
Use procgen.create_rng(seed) to create a seeded RNG.

Usage:
    local procgen = require("core.procgen")

    -- Create a seeded RNG
    local rng = procgen.create_rng(12345)

    -- Range: random value between min and max
    local gold_amount = procgen.range(10, 50)
    local actual_gold = gold_amount:roll(rng)

    -- Constant: value that doesn't scale
    local base_speed = procgen.constant(100)

    -- Loot table with weighted selection
    local chest_loot = procgen.loot {
        { item = "gold", weight = 50, amount = procgen.range(10, 50) },
        { item = "health_potion", weight = 30 },
        { item = "rare_sword", weight = 5, condition = function(ctx)
            return ctx.player.level >= 5
        end },

        -- Guaranteed drops (always included if condition passes)
        guaranteed = {
            { item = "key", condition = function(ctx) return not ctx.player.has_key end }
        },

        -- Number of items to pick from weighted pool
        picks = procgen.range(1, 3)
    }

    -- Roll the loot table
    local items = chest_loot:roll({ player = player, rng = rng })

    -- With debug info
    local items, debug_info = chest_loot:roll({ player = player, rng = rng, debug = true })

Performance:
    - All structures are plain Lua tables
    - RNG is simple LCG (Linear Congruential Generator) for portability
    - Deterministic: same seed always produces same results
]]

---@class Procgen
---@field range fun(min: number, max: number): ProcgenRange
---@field constant fun(value?: number): ProcgenConstant
---@field loot fun(definition: table): ProcgenLoot
---@field create_rng fun(seed: number): ProcgenRNG

---@class ProcgenRange
---@field min number
---@field max number
---@field roll fun(self: ProcgenRange, rng: ProcgenRNG): number

---@class ProcgenConstant
---@field value number
---@field roll fun(self: ProcgenConstant, rng: ProcgenRNG): number

---@class ProcgenLoot
---@field roll fun(self: ProcgenLoot, ctx: table): table[], table|nil

---@class ProcgenRNG
---@field next fun(self: ProcgenRNG): number Returns 0-1
---@field int fun(self: ProcgenRNG, min: number, max: number): number Returns min..max inclusive

------------------------------------------------------------

local procgen = {}

------------------------------------------------------------
-- RNG Implementation (LCG - Linear Congruential Generator)
-- Portable, deterministic, no external dependencies
------------------------------------------------------------

local RNG = {}
RNG.__index = RNG

-- LCG parameters (same as glibc)
local LCG_A = 1103515245
local LCG_C = 12345
local LCG_M = 2^31

--- Create a new seeded RNG.
---@param seed number Seed value
---@return ProcgenRNG
function procgen.create_rng(seed)
    local self = setmetatable({}, RNG)
    self._state = math.floor(seed) % LCG_M
    return self
end

--- Get next random float in [0, 1).
---@return number
function RNG:next()
    self._state = (LCG_A * self._state + LCG_C) % LCG_M
    return self._state / LCG_M
end

--- Get next random integer in [min, max] inclusive.
---@param min number
---@param max number
---@return number
function RNG:int(min, max)
    if min == max then return min end
    local range = max - min + 1
    return math.floor(self:next() * range) + min
end

------------------------------------------------------------
-- procgen.range
------------------------------------------------------------

local Range = {}
Range.__index = Range

--- Create a range that can be rolled.
---@param min number Minimum value (inclusive)
---@param max number Maximum value (inclusive)
---@return ProcgenRange
function procgen.range(min, max)
    local self = setmetatable({}, Range)
    self.min = min
    self.max = max
    return self
end

--- Roll the range using the provided RNG.
---@param rng ProcgenRNG
---@return number
function Range:roll(rng)
    return rng:int(self.min, self.max)
end

------------------------------------------------------------
-- procgen.constant
------------------------------------------------------------

local Constant = {}
Constant.__index = Constant

--- Create a constant value (doesn't scale, returns fixed value).
---@param value number|nil Value (default: 0)
---@return ProcgenConstant
function procgen.constant(value)
    local self = setmetatable({}, Constant)
    self.value = value or 0
    return self
end

--- Roll the constant (always returns the same value).
---@param rng ProcgenRNG
---@return number
function Constant:roll(rng)
    return self.value
end

------------------------------------------------------------
-- procgen.loot
------------------------------------------------------------

local Loot = {}
Loot.__index = Loot

--- Create a loot table.
---@param definition table Loot table definition
---@return ProcgenLoot
function procgen.loot(definition)
    local self = setmetatable({}, Loot)

    -- Extract weighted entries (numeric keys)
    self._entries = {}
    for i, entry in ipairs(definition) do
        self._entries[i] = {
            item = entry.item,
            weight = entry.weight or 1,
            amount = entry.amount,  -- Can be number or Range
            condition = entry.condition
        }
    end

    -- Extract guaranteed drops
    self._guaranteed = definition.guaranteed or {}

    -- Extract picks (default: 1)
    self._picks = definition.picks or 1

    return self
end

--- Helper: resolve a value that might be a number or a rollable (Range/Constant).
---@param value any Number or rollable object
---@param rng ProcgenRNG
---@return number
local function resolve_value(value, rng)
    if value == nil then
        return 1  -- Default amount
    elseif type(value) == "number" then
        return value
    elseif type(value) == "table" and value.roll then
        return value:roll(rng)
    else
        return 1
    end
end

--- Roll the loot table.
---@param ctx table Context with player, rng, debug flag, etc.
---@return table[] items, table|nil debug_info
function Loot:roll(ctx)
    ctx = ctx or {}
    local rng = ctx.rng or procgen.create_rng(0)
    local debug_mode = ctx.debug
    local results = {}
    local debug_info = nil

    if debug_mode then
        debug_info = {
            eligible_items = {},
            total_weight = 0,
            rolls = {}
        }
    end

    -- Step 1: Filter eligible entries based on conditions
    local eligible = {}
    local total_weight = 0

    for _, entry in ipairs(self._entries) do
        local is_eligible = true
        if entry.condition then
            is_eligible = entry.condition(ctx)
        end

        if is_eligible then
            table.insert(eligible, entry)
            total_weight = total_weight + entry.weight

            if debug_info then
                table.insert(debug_info.eligible_items, {
                    item = entry.item,
                    weight = entry.weight
                })
            end
        end
    end

    if debug_info then
        debug_info.total_weight = total_weight
    end

    -- Step 2: Determine number of picks
    local num_picks = resolve_value(self._picks, rng)

    -- Step 3: Roll for each pick
    for pick = 1, num_picks do
        if total_weight <= 0 or #eligible == 0 then
            break  -- No eligible items
        end

        -- Weighted random selection
        local roll = rng:next() * total_weight
        local cumulative = 0
        local selected = nil

        for _, entry in ipairs(eligible) do
            cumulative = cumulative + entry.weight
            if roll < cumulative then
                selected = entry
                break
            end
        end

        if selected then
            local amount = resolve_value(selected.amount, rng)
            table.insert(results, {
                item = selected.item,
                amount = amount
            })

            if debug_info then
                table.insert(debug_info.rolls, {
                    pick = pick,
                    roll_value = roll,
                    selected = selected.item,
                    amount = amount
                })
            end
        end
    end

    -- Step 4: Add guaranteed drops (if conditions pass)
    for _, guaranteed_entry in ipairs(self._guaranteed) do
        local include = true
        if guaranteed_entry.condition then
            include = guaranteed_entry.condition(ctx)
        end

        if include then
            local amount = resolve_value(guaranteed_entry.amount, rng)
            table.insert(results, {
                item = guaranteed_entry.item,
                amount = amount
            })
        end
    end

    return results, debug_info
end

------------------------------------------------------------
-- procgen.curve - Linear interpolation based on context value
------------------------------------------------------------

local Curve = {}
Curve.__index = Curve

--- Create a curve that interpolates between start and end values.
--- By default, interpolates from difficulty 1 to difficulty 10.
---@param key string Context key to read (e.g., "difficulty")
---@param start_value number Value at minimum (default: difficulty 1)
---@param end_value number Value at maximum (default: difficulty 10)
---@param min_key? number Minimum key value (default: 1)
---@param max_key? number Maximum key value (default: 10)
---@return table
function procgen.curve(key, start_value, end_value, min_key, max_key)
    local self = setmetatable({}, Curve)
    self.key = key
    self.start_value = start_value
    self.end_value = end_value
    self.min_key = min_key or 1
    self.max_key = max_key or 10
    return self
end

--- Resolve the curve value based on context.
---@param ctx table Context containing the key
---@return number
function Curve:resolve(ctx)
    local key_value = ctx[self.key] or self.min_key

    -- Clamp to range
    if key_value <= self.min_key then
        return self.start_value
    elseif key_value >= self.max_key then
        return self.end_value
    end

    -- Linear interpolation
    local t = (key_value - self.min_key) / (self.max_key - self.min_key)
    return self.start_value + t * (self.end_value - self.start_value)
end

------------------------------------------------------------
-- procgen.scaled - Dynamic enemy lists that scale with difficulty
------------------------------------------------------------

local Scaled = {}
Scaled.__index = Scaled

--- Create a scaled enemy definition.
---@param definition table { base, per_difficulty, max_enemies }
---@return table
function procgen.scaled(definition)
    local self = setmetatable({}, Scaled)
    self.base = definition.base or {}
    self.per_difficulty = definition.per_difficulty or {}
    self.max_enemies = definition.max_enemies or 999
    return self
end

--- Resolve the enemy list based on difficulty.
---@param ctx table Context containing difficulty
---@return string[]
function Scaled:resolve(ctx)
    local difficulty = ctx.difficulty or 0
    local enemies = {}

    -- Add base enemies
    for _, enemy in ipairs(self.base) do
        if #enemies >= self.max_enemies then break end
        table.insert(enemies, enemy)
    end

    -- Add per_difficulty enemies (one set per difficulty level)
    for d = 1, difficulty do
        for _, enemy in ipairs(self.per_difficulty) do
            if #enemies >= self.max_enemies then break end
            table.insert(enemies, enemy)
        end
        if #enemies >= self.max_enemies then break end
    end

    return enemies
end

------------------------------------------------------------
-- procgen.waves - Enemy wave definitions
------------------------------------------------------------

local Waves = {}
Waves.__index = Waves

--- Create a waves definition.
---@param definition table[] Array of wave definitions
---@return table
function procgen.waves(definition)
    local self = setmetatable({}, Waves)
    self._waves = {}

    for i, wave_def in ipairs(definition) do
        self._waves[i] = {
            enemies = wave_def.enemies,  -- Can be array or Scaled
            spawn_delay = wave_def.spawn_delay or 1.0,  -- Can be number or Curve
            spawn_pattern = wave_def.spawn_pattern or "sequential",
            min_interval = wave_def.min_interval,
            max_interval = wave_def.max_interval
        }
    end

    return self
end

--- Helper: resolve a value that might be a number, Curve, or Scaled.
---@param value any
---@param ctx table
---@return any
local function resolve_dynamic(value, ctx)
    if value == nil then
        return nil
    elseif type(value) == "table" then
        if value.resolve then
            return value:resolve(ctx)
        elseif value.roll then
            -- Rollables (Range/Constant); prefer caller-provided rng, fallback to deterministic seed
            local rng = ctx and ctx.rng or procgen.create_rng(0)
            return value:roll(rng)
        end
    else
        return value
    end
    return value
end

--- Get the number of waves.
---@return number
function Waves:count()
    return #self._waves
end

--- Get a specific wave by index.
---@param index number 1-based wave index
---@param ctx? table Optional context for resolving dynamic values
---@return table|nil
function Waves:get_wave(index, ctx)
    if index < 1 or index > #self._waves then
        return nil
    end

    local wave_def = self._waves[index]
    ctx = ctx or {}

    -- Resolve dynamic values
    local enemies = resolve_dynamic(wave_def.enemies, ctx)
    local spawn_delay = resolve_dynamic(wave_def.spawn_delay, ctx)

    -- Return a defensive copy of enemies to avoid caller mutation persisting
    local enemies_copy = enemies
    if type(enemies) == "table" then
        enemies_copy = {}
        for i = 1, #enemies do
            enemies_copy[i] = enemies[i]
        end
    end

    return {
        enemies = enemies_copy,
        spawn_delay = spawn_delay or wave_def.spawn_delay,
        spawn_pattern = wave_def.spawn_pattern,
        min_interval = wave_def.min_interval,
        max_interval = wave_def.max_interval
    }
end

--- Iterator over all waves.
---@param ctx? table Optional context for resolving dynamic values
---@return fun(): number, table
function Waves:iter(ctx)
    local i = 0
    local n = #self._waves
    return function()
        i = i + 1
        if i <= n then
            return i, self:get_wave(i, ctx)
        end
    end
end

------------------------------------------------------------
-- procgen.layout - Level layout DSL
------------------------------------------------------------

local Layout = {}
Layout.__index = Layout

--- Create a layout definition.
---@param definition table { type, rooms?, corridors?, constraints? }
---@return table
function procgen.layout(definition)
    local self = setmetatable({}, Layout)
    self.type = definition.type or "rooms_and_corridors"
    self.rooms = definition.rooms
    self.corridors = definition.corridors
    self.constraints = definition.constraints or {}
    return self
end

--- Helper: recursively resolve values in a table.
local function resolve_table(tbl, rng)
    if tbl == nil then return nil end

    if type(tbl) == "table" and tbl.roll then
        -- It's a rollable (Range, etc.)
        return tbl:roll(rng)
    elseif type(tbl) ~= "table" then
        -- It's a primitive value
        return tbl
    else
        -- It's a regular table, recurse
        local result = {}
        for k, v in pairs(tbl) do
            result[k] = resolve_table(v, rng)
        end
        return result
    end
end

--- Resolve the layout configuration with random values.
---@param ctx table { rng }
---@return table
function Layout:resolve(ctx)
    ctx = ctx or {}
    local rng = ctx.rng or procgen.create_rng(0)

    return {
        type = self.type,
        rooms = resolve_table(self.rooms, rng),
        corridors = resolve_table(self.corridors, rng),
        constraints = self.constraints  -- Constraints are strings, don't resolve
    }
end

------------------------------------------------------------
-- procgen.stats - Stat scaling DSL
------------------------------------------------------------

local Stats = {}
Stats.__index = Stats

--- Create a stats definition.
---@param definition table { base, scaling?, variants? }
---@return table
function procgen.stats(definition)
    local self = setmetatable({}, Stats)
    self._base = definition.base or {}
    self._scaling = definition.scaling or {}
    self._variants = definition.variants or {}
    return self
end

--- Generate stats based on context.
---@param ctx table { difficulty?, variant?, rng }
---@return table
function Stats:generate(ctx)
    ctx = ctx or {}
    local rng = ctx.rng or procgen.create_rng(0)
    local difficulty = ctx.difficulty or 0
    local variant_name = ctx.variant
    local result = {}

    -- Step 1: Resolve base values (may be number or Range)
    local base_values = {}
    for stat_name, base_value in pairs(self._base) do
        if type(base_value) == "table" and base_value.roll then
            base_values[stat_name] = base_value:roll(rng)
        else
            base_values[stat_name] = base_value
        end
    end

    -- Step 2: Apply scaling functions
    for stat_name, base_value in pairs(base_values) do
        local scaling_fn = self._scaling[stat_name]
        local scaled_value

        if scaling_fn == nil then
            -- No scaling, use base
            scaled_value = base_value
        elseif type(scaling_fn) == "function" then
            -- Function-based scaling
            scaled_value = scaling_fn({
                base = base_value,
                difficulty = difficulty,
                rng = rng
            })
        elseif type(scaling_fn) == "table" and scaling_fn.value ~= nil then
            -- procgen.constant - use base value unchanged
            scaled_value = base_value
        else
            -- Unknown scaling type, use base
            scaled_value = base_value
        end

        result[stat_name] = scaled_value
    end

    -- Step 3: Apply variant multipliers
    if variant_name and self._variants[variant_name] then
        local variant = self._variants[variant_name]
        for stat_name, multiplier in pairs(variant) do
            if result[stat_name] then
                result[stat_name] = result[stat_name] * multiplier
            end
        end
    end

    return result
end

------------------------------------------------------------
-- Initialization Log
------------------------------------------------------------
if _G.log_debug then
    log_debug("[procgen] Module loaded")
end

return procgen
