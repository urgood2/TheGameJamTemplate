-- assets/scripts/serpent/unit_damage_logic.lua
--[[
    Unit Damage Logic Module

    Processes damage events applied to snake units, applies on_damage_taken modifiers,
    and emits death events when units die. Part of the pure combat logic pipeline.
]]

local specials_system = require("serpent.specials_system")
local snake_logic = require("serpent.snake_logic")

local unit_damage_logic = {}

--- Process damage events for snake units
--- @param damage_events table Array of DamageEventUnit events to process
--- @param snake_state table Current snake state
--- @param ctx table Combat context for special ability processing
--- @return table, table Updated snake_state, array of DeathEventUnit events
function unit_damage_logic.process_damage_events(damage_events, snake_state, ctx)
    if not damage_events or #damage_events == 0 then
        return snake_state, {}
    end

    local updated_state = snake_state
    local all_death_events = {}

    -- Process damage events in deterministic order (sorted by target_instance_id)
    local sorted_events = {}
    for _, event in ipairs(damage_events) do
        table.insert(sorted_events, event)
    end
    table.sort(sorted_events, function(a, b)
        return a.target_instance_id < b.target_instance_id
    end)

    -- Process each damage event
    for _, damage_event in ipairs(sorted_events) do
        if unit_damage_logic._is_valid_damage_event(damage_event) then
            -- Create a proper copy of the damage event
            local event_copy = unit_damage_logic._copy_table(damage_event)

            -- Apply on_damage_taken modifiers through specials_system
            local modified_event, extra_events = specials_system.on_damage_taken(ctx, event_copy)

            -- Apply the damage if any remains after modifiers
            if modified_event.amount_int and modified_event.amount_int > 0 then
                local new_state, death_events = snake_logic.apply_damage(
                    updated_state,
                    modified_event.target_instance_id,
                    modified_event.amount_int
                )
                updated_state = new_state

                -- Convert snake_logic death events to DeathEventUnit format
                for _, death in ipairs(death_events) do
                    table.insert(all_death_events, {
                        type = "DeathEventUnit",
                        instance_id = death.instance_id,
                        cause = modified_event.source_type or "unknown"
                    })
                end
            end

            -- Add any extra events from specials processing
            for _, extra_event in ipairs(extra_events or {}) do
                if extra_event.type == "DeathEventUnit" then
                    table.insert(all_death_events, extra_event)
                end
            end
        end
    end

    return updated_state, all_death_events
end

--- Apply a single damage event to a specific unit
--- @param damage_event table DamageEventUnit to apply
--- @param snake_state table Current snake state
--- @param ctx table Combat context for special abilities
--- @return table, table Updated snake_state, array of death events
function unit_damage_logic.apply_damage_event(damage_event, snake_state, ctx)
    return unit_damage_logic.process_damage_events({damage_event}, snake_state, ctx)
end

--- Create a damage event for a unit
--- @param target_instance_id number Instance ID of target unit
--- @param damage_amount number Amount of damage to deal (positive integer)
--- @param source_type string Source of the damage (e.g., "enemy_contact", "spell")
--- @param source_id number Optional source entity ID
--- @return table DamageEventUnit structure
function unit_damage_logic.create_damage_event(target_instance_id, damage_amount, source_type, source_id)
    local amount = math.floor(math.max(0, damage_amount or 0))
    return {
        type = "DamageEventUnit",
        target_instance_id = target_instance_id,
        amount_int = amount,
        source_type = source_type or "unknown",
        source_id = source_id
    }
end

--- Validate damage event structure
--- @param damage_event table Event to validate
--- @return boolean True if event is valid
function unit_damage_logic._is_valid_damage_event(damage_event)
    return damage_event and
           damage_event.type == "DamageEventUnit" and
           damage_event.target_instance_id and
           damage_event.amount_int and
           damage_event.amount_int >= 0
end

--- Deep copy a table
--- @param t table Table to copy
--- @return table Deep copy of the table
function unit_damage_logic._copy_table(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = type(v) == "table" and unit_damage_logic._copy_table(v) or v
    end
    return copy
end

--- Calculate effective damage after all modifiers
--- @param base_damage number Base damage amount
--- @param target_instance_id number Target unit instance ID
--- @param snake_state table Snake state for passive mod lookup
--- @param unit_defs table Unit definitions for calculations
--- @return number Final damage amount after all modifiers
function unit_damage_logic.calculate_effective_damage(base_damage, target_instance_id, snake_state, unit_defs)
    if not base_damage or base_damage <= 0 then
        return 0
    end

    -- Get passive modifiers from specials system
    local passive_mods = specials_system.get_passive_mods(snake_state, unit_defs)
    local target_mods = passive_mods[target_instance_id]

    if target_mods and target_mods.damage_taken_mult then
        local modified_damage = base_damage * target_mods.damage_taken_mult
        return math.floor(modified_damage)
    end

    return math.floor(base_damage)
end

--- Get damage reduction summary for a unit
--- @param instance_id number Unit instance ID
--- @param snake_state table Snake state
--- @param unit_defs table Unit definitions
--- @return table Damage reduction info
function unit_damage_logic.get_damage_reduction_info(instance_id, snake_state, unit_defs)
    local passive_mods = specials_system.get_passive_mods(snake_state, unit_defs)
    local unit_mods = passive_mods[instance_id] or {}

    local damage_taken_mult = unit_mods.damage_taken_mult or 1.0
    local reduction_percent = (1.0 - damage_taken_mult) * 100

    return {
        damage_taken_mult = damage_taken_mult,
        reduction_percent = reduction_percent,
        has_reduction = reduction_percent > 0
    }
end

--- Test damage application with knight block
--- @return boolean True if damage reduction works correctly
function unit_damage_logic.test_knight_block_reduction()
    -- Create snake with knight_block unit
    local snake_state = {
        segments = {
            {
                instance_id = 1,
                def_id = "soldier",
                special_id = "knight_block",
                hp = 100,
                hp_max_base = 100,
                level = 1
            }
        },
        min_len = 1,
        max_len = 8
    }

    local ctx = { snake_state = snake_state }

    -- Create damage event for 20 damage
    local damage_event = unit_damage_logic.create_damage_event(1, 20, "test_damage")

    -- Process damage (should be reduced by knight_block to 16)
    local updated_state, death_events = unit_damage_logic.apply_damage_event(damage_event, snake_state, ctx)

    -- Knight should take 80% damage (16 damage), leaving 84 HP
    local knight = snake_logic.find_segment(updated_state, 1)
    if not knight or knight.hp ~= 84 then
        return false
    end

    -- Should be no death events
    if #death_events ~= 0 then
        return false
    end

    return true
end

--- Test paladin divine shield negation
--- @return boolean True if shield negation works correctly
function unit_damage_logic.test_paladin_divine_shield()
    -- Create snake with paladin_divine_shield unit
    local snake_state = {
        segments = {
            {
                instance_id = 1,
                def_id = "paladin",
                special_id = "paladin_divine_shield",
                hp = 100,
                hp_max_base = 100,
                level = 1,
                special_state = { shield_used = false }
            }
        },
        min_len = 1,
        max_len = 8
    }

    local ctx = { snake_state = snake_state }

    -- Create damage event for 50 damage
    local damage_event = unit_damage_logic.create_damage_event(1, 50, "test_damage")

    -- Process damage (should be completely negated by divine shield)
    local updated_state, death_events = unit_damage_logic.apply_damage_event(damage_event, snake_state, ctx)

    -- Paladin should take no damage (shield blocks first hit)
    local paladin = snake_logic.find_segment(updated_state, 1)
    if not paladin or paladin.hp ~= 100 then
        return false
    end

    -- Shield should be marked as used
    if not paladin.special_state or not paladin.special_state.shield_used then
        return false
    end

    -- Should be no death events
    if #death_events ~= 0 then
        return false
    end

    -- Second damage event should go through
    local damage_event2 = unit_damage_logic.create_damage_event(1, 30, "test_damage2")
    updated_state, death_events = unit_damage_logic.apply_damage_event(damage_event2, updated_state, ctx)

    -- Paladin should now take full damage
    paladin = snake_logic.find_segment(updated_state, 1)
    if not paladin or paladin.hp ~= 70 then
        return false
    end

    return true
end

--- Test lethal damage and death event generation
--- @return boolean True if death events work correctly
function unit_damage_logic.test_lethal_damage()
    -- Create snake with low HP unit
    local snake_state = {
        segments = {
            {
                instance_id = 1,
                def_id = "soldier",
                hp = 10,
                hp_max_base = 100,
                level = 1
            }
        },
        min_len = 1,
        max_len = 8
    }

    local ctx = { snake_state = snake_state }

    -- Create lethal damage event
    local damage_event = unit_damage_logic.create_damage_event(1, 15, "lethal_damage")

    -- Process damage
    local updated_state, death_events = unit_damage_logic.apply_damage_event(damage_event, snake_state, ctx)

    -- Unit should be removed from snake
    if #updated_state.segments ~= 0 then
        return false
    end

    -- Should generate death event
    if #death_events ~= 1 then
        return false
    end

    local death_event = death_events[1]
    if death_event.type ~= "DeathEventUnit" or
       death_event.instance_id ~= 1 or
       death_event.cause ~= "lethal_damage" then
        return false
    end

    return true
end

--- Test damage event processing order
--- @return boolean True if events are processed in correct order
function unit_damage_logic.test_damage_event_order()
    -- Create snake with multiple units
    local snake_state = {
        segments = {
            { instance_id = 3, hp = 50, hp_max_base = 50 },
            { instance_id = 1, hp = 50, hp_max_base = 50 },
            { instance_id = 2, hp = 50, hp_max_base = 50 }
        },
        min_len = 1,
        max_len = 8
    }

    local ctx = { snake_state = snake_state }

    -- Create damage events in mixed order
    local damage_events = {
        unit_damage_logic.create_damage_event(3, 10, "damage_3"),
        unit_damage_logic.create_damage_event(1, 20, "damage_1"),
        unit_damage_logic.create_damage_event(2, 15, "damage_2")
    }

    -- Process all damage events
    local updated_state, death_events = unit_damage_logic.process_damage_events(damage_events, snake_state, ctx)

    -- Check that damage was applied correctly (should be sorted by instance_id)
    local unit1 = snake_logic.find_segment(updated_state, 1)
    local unit2 = snake_logic.find_segment(updated_state, 2)
    local unit3 = snake_logic.find_segment(updated_state, 3)

    if not unit1 or unit1.hp ~= 30 then return false end  -- 50 - 20 = 30
    if not unit2 or unit2.hp ~= 35 then return false end  -- 50 - 15 = 35
    if not unit3 or unit3.hp ~= 40 then return false end  -- 50 - 10 = 40

    return true
end

return unit_damage_logic