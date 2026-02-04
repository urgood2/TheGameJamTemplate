-- assets/scripts/serpent/attack_modifier_logic.lua
--[[
    Attack Modifier Logic Module

    Applies on-attack specials (sniper_crit) and converts AttackEvents to DamageEventEnemy.
    This is step 7 in the combat tick simulation per PLAN.md.
]]

local attack_modifier_logic = {}

--- Apply attack modifiers and convert to damage events
--- @param attack_events table Array of AttackEvent structures
--- @param snake_state table Snake state with segment instances
--- @param unit_defs table Unit definitions for special_id lookup
--- @param rng table RNG instance for modifier rolls
--- @return table Array of DamageEventEnemy events
function attack_modifier_logic.process_attacks(attack_events, snake_state, unit_defs, rng)
    local damage_events = {}

    if not attack_events or not snake_state or not unit_defs or not rng then
        return damage_events
    end

    -- Create lookup for segments by instance_id for special checking
    local segments_by_id = {}
    if snake_state.segments then
        for _, segment in ipairs(snake_state.segments) do
            if segment and segment.instance_id then
                segments_by_id[segment.instance_id] = segment
            end
        end
    end

    -- Process each AttackEvent in the order they were emitted
    for _, attack_event in ipairs(attack_events) do
        if attack_event and attack_event.attacker_instance_id and attack_event.target_enemy_id and
           attack_event.base_damage_int then

            local final_damage = attack_event.base_damage_int
            local attacker_segment = segments_by_id[attack_event.attacker_instance_id]

            -- Apply sniper_crit modifier if applicable
            if attacker_segment and attacker_segment.def_id then
                local unit_def = unit_defs[attacker_segment.def_id]
                if unit_def and unit_def.special_id == "sniper_crit" then
                    -- Roll for 20% chance to deal 2x damage
                    local crit_roll = rng:float()
                    if crit_roll < 0.20 then
                        final_damage = final_damage * 2
                    end
                end
            end

            -- Emit DamageEventEnemy with final damage amount
            table.insert(damage_events, {
                kind = "damage_enemy",
                target_enemy_id = attack_event.target_enemy_id,
                amount_int = final_damage,
                source_instance_id = attack_event.attacker_instance_id
            })
        end
    end

    return damage_events
end

--- Get attack modifier summary for debugging
--- @param attack_events table Array of AttackEvent structures
--- @param snake_state table Snake state with segment instances
--- @param unit_defs table Unit definitions for special_id lookup
--- @return table Summary of modifiers that would be applied
function attack_modifier_logic.get_modifier_summary(attack_events, snake_state, unit_defs)
    local summary = {
        total_attacks = #(attack_events or {}),
        sniper_attacks = 0,
        units_with_sniper = {}
    }

    if not attack_events or not snake_state or not unit_defs then
        return summary
    end

    -- Create lookup for segments by instance_id
    local segments_by_id = {}
    if snake_state.segments then
        for _, segment in ipairs(snake_state.segments) do
            if segment and segment.instance_id then
                segments_by_id[segment.instance_id] = segment
            end
        end
    end

    -- Count sniper crit attacks and identify sniper units
    for _, attack_event in ipairs(attack_events) do
        if attack_event and attack_event.attacker_instance_id then
            local attacker_segment = segments_by_id[attack_event.attacker_instance_id]
            if attacker_segment and attacker_segment.def_id then
                local unit_def = unit_defs[attacker_segment.def_id]
                if unit_def and unit_def.special_id == "sniper_crit" then
                    summary.sniper_attacks = summary.sniper_attacks + 1
                    -- Add unique unit to list if not already present
                    local already_listed = false
                    for _, listed_id in ipairs(summary.units_with_sniper) do
                        if listed_id == attack_event.attacker_instance_id then
                            already_listed = true
                            break
                        end
                    end
                    if not already_listed then
                        table.insert(summary.units_with_sniper, attack_event.attacker_instance_id)
                    end
                end
            end
        end
    end

    return summary
end

--- Test sniper crit modifier implementation
--- @return boolean True if sniper crit logic is correctly implemented
function attack_modifier_logic.test_sniper_crit()
    -- Mock RNG that always returns 0.1 (below 0.2 threshold for crit)
    local mock_rng = {
        float = function() return 0.1 end
    }

    -- Mock attack event from a sniper
    local attack_events = {
        {
            attacker_instance_id = 1,
            target_enemy_id = 10,
            base_damage_int = 25
        }
    }

    -- Mock snake state with a sniper segment
    local snake_state = {
        segments = {
            {
                instance_id = 1,
                def_id = "sniper"
            }
        }
    }

    -- Mock unit definitions with sniper
    local unit_defs = {
        sniper = {
            special_id = "sniper_crit"
        }
    }

    -- Process attacks - should get 2x damage due to crit
    local damage_events = attack_modifier_logic.process_attacks(
        attack_events, snake_state, unit_defs, mock_rng
    )

    -- Should produce one damage event
    if #damage_events ~= 1 then
        return false
    end

    -- Should have double damage (50 instead of 25)
    if damage_events[1].amount_int ~= 50 then
        return false
    end

    -- Should have correct structure
    if damage_events[1].kind ~= "damage_enemy" or
       damage_events[1].target_enemy_id ~= 10 or
       damage_events[1].source_instance_id ~= 1 then
        return false
    end

    -- Test non-crit case with RNG that returns 0.5 (above 0.2 threshold)
    local no_crit_rng = {
        float = function() return 0.5 end
    }

    local no_crit_damage = attack_modifier_logic.process_attacks(
        attack_events, snake_state, unit_defs, no_crit_rng
    )

    -- Should have base damage (25, no modification)
    if #no_crit_damage ~= 1 or no_crit_damage[1].amount_int ~= 25 then
        return false
    end

    return true
end

--- Test processing multiple attack events with mixed modifiers
--- @return boolean True if multi-attack processing is correct
function attack_modifier_logic.test_multi_attack_processing()
    -- Mock RNG that alternates crit/no-crit (0.1, 0.3, 0.1, 0.3...)
    local call_count = 0
    local mock_rng = {
        float = function()
            call_count = call_count + 1
            return (call_count % 2 == 1) and 0.1 or 0.3
        end
    }

    -- Multiple attack events from different unit types
    local attack_events = {
        { attacker_instance_id = 1, target_enemy_id = 10, base_damage_int = 25 }, -- sniper (should crit)
        { attacker_instance_id = 2, target_enemy_id = 11, base_damage_int = 15 }, -- soldier (no special)
        { attacker_instance_id = 1, target_enemy_id = 12, base_damage_int = 25 }  -- sniper (should not crit)
    }

    local snake_state = {
        segments = {
            { instance_id = 1, def_id = "sniper" },
            { instance_id = 2, def_id = "soldier" }
        }
    }

    local unit_defs = {
        sniper = { special_id = "sniper_crit" },
        soldier = { special_id = nil }
    }

    local damage_events = attack_modifier_logic.process_attacks(
        attack_events, snake_state, unit_defs, mock_rng
    )

    -- Should produce 3 damage events
    if #damage_events ~= 3 then
        return false
    end

    -- First attack: sniper crit (25 * 2 = 50)
    if damage_events[1].amount_int ~= 50 then
        return false
    end

    -- Second attack: soldier no modifier (15)
    if damage_events[2].amount_int ~= 15 then
        return false
    end

    -- Third attack: sniper no crit (25)
    if damage_events[3].amount_int ~= 25 then
        return false
    end

    return true
end

return attack_modifier_logic