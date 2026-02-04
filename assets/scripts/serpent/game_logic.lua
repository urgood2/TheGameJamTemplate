-- Serpent Game Logic Module
-- Handles game state creation and management for the Serpent minigame

local rng = require("serpent.rng")

local game_logic = {}

-- SnakeState structure definition
local SnakeState = {}
SnakeState.__index = SnakeState

function SnakeState.new(units, length, id_counter)
    local state = {
        units = units or {},
        length = length or 0,
        id_counter = id_counter or 1
    }
    setmetatable(state, SnakeState)
    return state
end

-- Unit types for the Serpent game
local UNIT_TYPES = {
    SOLDIER = "soldier",
    APPRENTICE = "apprentice",
    SCOUT = "scout"
}

--[[
    Create initial snake state with predefined unit composition

    @param unit_defs table - Unit definitions containing stats and properties for each unit type
    @param min_len number - Minimum snake length
    @param max_len number - Maximum snake length
    @param id_state table - State object for generating unique IDs
    @return SnakeState - New snake state with soldier, apprentice, and scout units
]]
function game_logic.create_initial(unit_defs, min_len, max_len, id_state)
    if not unit_defs then
        error("create_initial: unit_defs is required")
    end

    if not min_len or not max_len then
        error("create_initial: min_len and max_len are required")
    end

    if min_len > max_len then
        error("create_initial: min_len cannot be greater than max_len")
    end

    if min_len < 3 then
        error("create_initial: min_len must be at least 3 to accommodate soldier, apprentice, and scout")
    end

    -- Initialize RNG if not already done
    local prng = rng.create(id_state and id_state.seed or os.time())

    -- Generate random length between min_len and max_len
    local snake_length = prng:int(min_len, max_len)

    -- Create initial units array
    local units = {}
    local id_counter = id_state and id_state.counter or 1

    -- Add required units: soldier, apprentice, scout
    table.insert(units, create_unit(unit_defs, UNIT_TYPES.SOLDIER, id_counter))
    id_counter = id_counter + 1

    table.insert(units, create_unit(unit_defs, UNIT_TYPES.APPRENTICE, id_counter))
    id_counter = id_counter + 1

    table.insert(units, create_unit(unit_defs, UNIT_TYPES.SCOUT, id_counter))
    id_counter = id_counter + 1

    -- Fill remaining slots with random unit types if snake_length > 3
    local available_types = {UNIT_TYPES.SOLDIER, UNIT_TYPES.APPRENTICE, UNIT_TYPES.SCOUT}
    for i = 4, snake_length do
        local unit_type = prng:choice(available_types)
        table.insert(units, create_unit(unit_defs, unit_type, id_counter))
        id_counter = id_counter + 1
    end

    -- Update id_state if provided
    if id_state then
        id_state.counter = id_counter
    end

    log_debug(string.format("[GameLogic] Created initial snake state with %d units", snake_length))

    return SnakeState.new(units, snake_length, id_counter)
end

--[[
    Create a unit with given type and ID

    @param unit_defs table - Unit definitions
    @param unit_type string - Type of unit to create
    @param id number - Unique ID for the unit
    @return table - Unit object
]]
function create_unit(unit_defs, unit_type, id)
    local unit_def = unit_defs[unit_type]
    if not unit_def then
        error(string.format("create_unit: No definition found for unit type '%s'", unit_type))
    end

    return {
        id = id,
        type = unit_type,
        stats = unit_def.stats and table.copy(unit_def.stats) or {},
        properties = unit_def.properties and table.copy(unit_def.properties) or {},
        position = { x = 0, y = 0 }, -- Default position
        created_at = os.time()
    }
end

-- Helper function to deep copy tables
function table.copy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = type(v) == "table" and table.copy(v) or v
    end
    return copy
end

--[[
    Calculate effective multipliers for all units based on synergies

    @param units table - Array of unit objects with id, type, and stats
    @param synergy_defs table - Synergy definitions for calculating bonuses
    @return table - by_instance_id table with multiplier values for each unit
]]
function game_logic.get_effective_multipliers(units, synergy_defs)
    local by_instance_id = {}

    if not units or #units == 0 then
        return by_instance_id
    end

    -- Default multiplier values (no bonus)
    local default_multipliers = {
        hp_mult = 1.0,
        atk_mult = 1.0,
        range_mult = 1.0,
        atk_spd_mult = 1.0,
        cooldown_period_mult = 1.0,
        global_regen_per_sec = 0.0
    }

    -- Calculate multipliers for each unit
    for _, unit in ipairs(units) do
        local multipliers = table.copy(default_multipliers)

        -- Apply synergy bonuses based on adjacent units and unit composition
        if synergy_defs then
            multipliers = apply_synergies(unit, units, synergy_defs, multipliers)
        end

        by_instance_id[unit.id] = multipliers
    end

    log_debug(string.format("[GameLogic] Calculated multipliers for %d units", #units))
    return by_instance_id
end

--[[
    Apply synergy effects to a unit's multipliers

    @param unit table - Target unit
    @param all_units table - All units in the formation
    @param synergy_defs table - Synergy definitions
    @param multipliers table - Base multipliers to modify
    @return table - Modified multipliers
]]
function apply_synergies(unit, all_units, synergy_defs, multipliers)
    local result = table.copy(multipliers)

    -- Count unit types for type-based synergies
    local type_counts = {}
    for _, u in ipairs(all_units) do
        type_counts[u.type] = (type_counts[u.type] or 0) + 1
    end

    -- Apply type-based synergies
    for unit_type, count in pairs(type_counts) do
        local synergy = synergy_defs[unit_type]
        if synergy and synergy.per_unit and count > 1 then
            local bonus_factor = (count - 1) * synergy.per_unit.factor
            if synergy.per_unit.hp_bonus then
                result.hp_mult = result.hp_mult + bonus_factor
            end
            if synergy.per_unit.atk_bonus then
                result.atk_mult = result.atk_mult + bonus_factor
            end
            if synergy.per_unit.atk_spd_bonus then
                result.atk_spd_mult = result.atk_spd_mult + bonus_factor
            end
            if synergy.per_unit.global_regen then
                result.global_regen_per_sec = result.global_regen_per_sec + synergy.per_unit.global_regen * count
            end
        end
    end

    -- Apply Support unit threshold synergies
    local support_count = type_counts["support"] or 0
    if support_count >= 2 then
        -- 2+ Support units: 5 HP/sec global regen
        result.global_regen_per_sec = result.global_regen_per_sec + 5.0

        if support_count >= 4 then
            -- 4+ Support units: 10 HP/sec global regen + 10% all stats
            result.global_regen_per_sec = result.global_regen_per_sec + 5.0 -- Additional 5 for total 10
            result.hp_mult = result.hp_mult + 0.1
            result.atk_mult = result.atk_mult + 0.1
            result.atk_spd_mult = result.atk_spd_mult + 0.1
            result.range_mult = result.range_mult + 0.1
        end
    end

    -- Apply adjacent unit bonuses (placeholder - would need position logic)
    -- This would check neighboring units and apply position-based synergies

    return result
end

--[[
    Process healer adjacent regen special ability

    @param healer_unit table - The healer unit
    @param all_units table - Array of all units in formation
    @param dt number - Delta time in seconds
    @return table - Updated units with healed HP
]]
function game_logic.healer_adjacent_regen(healer_unit, all_units, dt)
    if not healer_unit or healer_unit.type ~= "healer" then
        return all_units
    end

    local HEAL_RATE = 10 -- HP per second per adjacent unit
    local updated_units = table.copy(all_units)

    -- Initialize accumulator if it doesn't exist
    if not healer_unit.heal_accumulator then
        healer_unit.heal_accumulator = 0
    end

    -- Add healing over time to accumulator
    healer_unit.heal_accumulator = healer_unit.heal_accumulator + (HEAL_RATE * dt)

    -- Find healer's position in the formation
    local healer_index = nil
    for i, unit in ipairs(updated_units) do
        if unit.id == healer_unit.id then
            healer_index = i
            break
        end
    end

    if not healer_index then
        log_debug("[GameLogic] Healer unit not found in formation")
        return updated_units
    end

    -- Heal adjacent units (previous and next in formation)
    local adjacent_indices = {healer_index - 1, healer_index + 1}
    local healed_count = 0

    for _, adj_index in ipairs(adjacent_indices) do
        if adj_index >= 1 and adj_index <= #updated_units then
            local target_unit = updated_units[adj_index]

            -- Only heal living units that aren't at max HP
            if target_unit and target_unit.stats and target_unit.stats.hp and target_unit.stats.max_hp then
                if target_unit.stats.hp > 0 and target_unit.stats.hp < target_unit.stats.max_hp then
                    -- Apply healing from accumulator
                    if healer_unit.heal_accumulator >= 1.0 then
                        local heal_amount = math.floor(healer_unit.heal_accumulator)
                        local new_hp = math.min(target_unit.stats.hp + heal_amount, target_unit.stats.max_hp)
                        local actual_heal = new_hp - target_unit.stats.hp

                        target_unit.stats.hp = new_hp
                        healer_unit.heal_accumulator = healer_unit.heal_accumulator - heal_amount
                        healed_count = healed_count + 1

                        log_debug(string.format("[GameLogic] Healer %d healed unit %d for %d HP",
                                               healer_unit.id, target_unit.id, actual_heal))
                    end
                end
            end
        end
    end

    if healed_count > 0 then
        log_debug(string.format("[GameLogic] Healer %d processed adjacent regen on %d units",
                               healer_unit.id, healed_count))
    end

    return updated_units
end

--[[
    Process all special abilities for units

    @param units table - Array of all units
    @param dt number - Delta time in seconds
    @return table - Updated units after processing specials
]]
function game_logic.process_specials(units, dt)
    local updated_units = table.copy(units)

    for _, unit in ipairs(updated_units) do
        -- Process healer special ability
        if unit.type == "healer" then
            updated_units = game_logic.healer_adjacent_regen(unit, updated_units, dt)
        end

        -- TODO: Add other special abilities here
        -- - Soldier defensive stance
        -- - Scout movement bonuses
        -- - Apprentice spell casting
    end

    return updated_units
end

--[[
    Buy a unit and add it to the snake formation

    @param snake_state SnakeState - Current snake state
    @param unit_type string - Type of unit to buy
    @param unit_defs table - Unit definitions
    @param gold_state table - Player's gold/currency state
    @param id_state table - ID generation state
    @return boolean - Success/failure
    @return string - Message
]]
function game_logic.buy(snake_state, unit_type, unit_defs, gold_state, id_state)
    if not snake_state or not unit_type or not unit_defs or not gold_state or not id_state then
        return false, "Missing required parameters"
    end

    local unit_def = unit_defs[unit_type]
    if not unit_def then
        return false, "Unknown unit type: " .. unit_type
    end

    local cost = unit_def.cost or 3
    if gold_state.amount < cost then
        return false, "Insufficient gold"
    end

    -- Deduct gold
    gold_state.amount = gold_state.amount - cost

    -- Create new unit
    local new_unit = create_unit(unit_defs, unit_type, id_state.counter)
    id_state.counter = id_state.counter + 1

    -- Append to tail of snake
    table.insert(snake_state.units, new_unit)
    snake_state.length = #snake_state.units

    log_debug(string.format("[GameLogic] Bought %s unit (ID: %d) for %d gold",
                           unit_type, new_unit.id, cost))

    -- Run combines to check for unit upgrades
    local combines_applied = run_combines(snake_state, unit_defs)
    if combines_applied > 0 then
        log_debug(string.format("[GameLogic] Applied %d combines after purchase", combines_applied))
    end

    return true, "Unit purchased successfully"
end

--[[
    Process unit combinations and upgrades

    @param snake_state SnakeState - Current snake state
    @param unit_defs table - Unit definitions with combine rules
    @return number - Number of combines applied
]]
function run_combines(snake_state, unit_defs)
    local combines_count = 0
    local units = snake_state.units

    -- Check for adjacent unit combinations
    local i = 1
    while i < #units do
        local unit_a = units[i]
        local unit_b = units[i + 1]

        if unit_a and unit_b then
            local combine_result = check_combine(unit_a, unit_b, unit_defs)
            if combine_result then
                -- Replace the two units with the combined unit
                local new_unit = create_unit(unit_defs, combine_result.type, unit_a.id)
                new_unit.stats = combine_result.stats

                -- Remove old units and insert new one
                table.remove(units, i + 1) -- Remove second unit first
                table.remove(units, i)     -- Then first unit
                table.insert(units, i, new_unit) -- Insert combined unit

                combines_count = combines_count + 1
                log_debug(string.format("[GameLogic] Combined %s + %s -> %s",
                                       unit_a.type, unit_b.type, combine_result.type))

                -- Don't increment i to check new combinations with this unit
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end

    snake_state.length = #units
    return combines_count
end

--[[
    Check if two units can be combined

    @param unit_a table - First unit
    @param unit_b table - Second unit
    @param unit_defs table - Unit definitions with combine rules
    @return table|nil - Combined unit definition or nil
]]
function check_combine(unit_a, unit_b, unit_defs)
    -- Same type combination
    if unit_a.type == unit_b.type then
        local base_def = unit_defs[unit_a.type]
        if base_def and base_def.upgrade_type then
            return {
                type = base_def.upgrade_type,
                stats = merge_stats(unit_a.stats, unit_b.stats, base_def.upgrade_bonus)
            }
        end
    end

    -- Special combinations (e.g., soldier + apprentice = paladin)
    local combine_key = unit_a.type .. "+" .. unit_b.type
    local reverse_key = unit_b.type .. "+" .. unit_a.type

    for _, unit_def in pairs(unit_defs) do
        if unit_def.combines then
            if unit_def.combines[combine_key] or unit_def.combines[reverse_key] then
                return {
                    type = unit_def.type,
                    stats = merge_stats(unit_a.stats, unit_b.stats, unit_def.combine_bonus)
                }
            end
        end
    end

    return nil
end

--[[
    Merge stats from two units with optional bonus

    @param stats_a table - First unit's stats
    @param stats_b table - Second unit's stats
    @param bonus table - Optional stat bonuses
    @return table - Merged stats
]]
function merge_stats(stats_a, stats_b, bonus)
    local result = {}
    bonus = bonus or {}

    -- Combine base stats
    for stat, value in pairs(stats_a) do
        result[stat] = value + (stats_b[stat] or 0) + (bonus[stat] or 0)
    end

    for stat, value in pairs(stats_b) do
        if not result[stat] then
            result[stat] = value + (bonus[stat] or 0)
        end
    end

    return result
end

-- Export unit types for external use
game_logic.UNIT_TYPES = UNIT_TYPES
game_logic.SnakeState = SnakeState

--- Initialize combat state for a new combat phase
--- @param snake_state table Snake state with segments
--- @param wave_num number Current wave number
--- @return table Combat state with accumulators and cooldown map
function game_logic.init_state(snake_state, wave_num)
    local combat_state = {
        -- Time tracking
        combat_time_sec = 0.0,
        wave_num = wave_num or 1,

        -- Contact damage cooldowns map
        contact_cooldowns = {},

        -- Global regen accumulator
        global_regen_accum = 0.0,
        global_regen_cursor = 1,

        -- Targeted heal accumulators (per instance_id)
        targeted_heal_accums = {},

        -- Combat state flags
        is_active = true,
        enemies_cleared = false
    }

    -- Initialize targeted heal accumulators for each segment
    if snake_state and snake_state.segments then
        for _, segment in ipairs(snake_state.segments) do
            if segment and segment.instance_id then
                combat_state.targeted_heal_accums[segment.instance_id] = 0.0
            end
        end
    end

    return combat_state
end

return game_logic
