-- assets/scripts/serpent/specials_system.lua
--[[
    Specials System Module

    Handles unit special abilities including healer adjacent regen, knight block,
    sniper crit, bard attack speed buffs, berserker frenzy, and paladin divine shield.
]]

local specials_system = {}

--- Process special ability ticks and generate heal events
--- @param dt number Delta time in seconds
--- @param ctx table Combat context with snake_state and other data
--- @param rng table RNG instance for deterministic rolls
--- @return table Array of events generated (HealEventUnit, etc.)
function specials_system.tick(dt, ctx, rng)
    local events = {}

    if not ctx or not ctx.snake_state or not ctx.snake_state.segments then
        return events
    end

    -- Process healer adjacent regen
    local heal_events = specials_system.process_healer_regen(dt, ctx)
    for _, event in ipairs(heal_events) do
        table.insert(events, event)
    end

    return events
end

--- Process healer adjacent regeneration with deterministic ordering
--- @param dt number Delta time in seconds
--- @param ctx table Combat context
--- @return table Array of HealEventUnit events
function specials_system.process_healer_regen(dt, ctx)
    local events = {}
    local segments = ctx.snake_state.segments

    -- Process healers in head→tail order
    for i, segment in ipairs(segments) do
        if segment and segment.special_id == "healer_adjacent_regen" and segment.hp > 0 then
            -- Initialize special state if needed
            if not segment.special_state then
                segment.special_state = {
                    heal_left_accum = 0.0,
                    heal_right_accum = 0.0
                }
            end

            local special_state = segment.special_state

            -- Process left neighbor first
            local left_index = i - 1
            if left_index >= 1 then
                local left_neighbor = segments[left_index]
                if left_neighbor and left_neighbor.hp > 0 then
                    special_state.heal_left_accum = special_state.heal_left_accum + (10 * dt)

                    -- Drain accumulator and emit heal events
                    while special_state.heal_left_accum >= 1.0 do
                        table.insert(events, {
                            type = "HealEventUnit",
                            target_instance_id = left_neighbor.instance_id,
                            heal_amount = 1,
                            source_instance_id = segment.instance_id,
                            source_type = "healer_regen"
                        })
                        special_state.heal_left_accum = special_state.heal_left_accum - 1.0
                    end
                end
            end

            -- Then process right neighbor
            local right_index = i + 1
            if right_index <= #segments then
                local right_neighbor = segments[right_index]
                if right_neighbor and right_neighbor.hp > 0 then
                    special_state.heal_right_accum = special_state.heal_right_accum + (10 * dt)

                    -- Drain accumulator and emit heal events
                    while special_state.heal_right_accum >= 1.0 do
                        table.insert(events, {
                            type = "HealEventUnit",
                            target_instance_id = right_neighbor.instance_id,
                            heal_amount = 1,
                            source_instance_id = segment.instance_id,
                            source_type = "healer_regen"
                        })
                        special_state.heal_right_accum = special_state.heal_right_accum - 1.0
                    end
                end
            end
        end
    end

    return events
end

--- Get passive modifiers from special abilities
--- @param ctx table Combat context
--- @return table Modifiers by instance_id
function specials_system.get_passive_mods(ctx)
    local mods_by_instance_id = {}

    if not ctx or not ctx.snake_state or not ctx.snake_state.segments then
        return mods_by_instance_id
    end

    local segments = ctx.snake_state.segments

    -- Process each segment for passive effects
    for i, segment in ipairs(segments) do
        if segment and segment.hp > 0 then
            -- Initialize mods for this instance
            if not mods_by_instance_id[segment.instance_id] then
                mods_by_instance_id[segment.instance_id] = {
                    damage_reduction = 1.0,  -- Multiplicative damage reduction
                    attack_speed_mult = 1.0, -- Attack speed multiplier
                    attack_mult = 1.0        -- Attack damage multiplier
                }
            end

            local mods = mods_by_instance_id[segment.instance_id]

            -- Knight block: 20% damage reduction
            if segment.special_id == "knight_block" then
                mods.damage_reduction = mods.damage_reduction * 0.8 -- 20% less damage
            end

            -- Bard adjacent attack speed buff
            if segment.special_id == "bard_adjacent_atkspd" then
                -- Buff adjacent segments
                if i > 1 then -- Left neighbor
                    local left_neighbor = segments[i - 1]
                    if left_neighbor and left_neighbor.hp > 0 then
                        local left_id = left_neighbor.instance_id
                        if not mods_by_instance_id[left_id] then
                            mods_by_instance_id[left_id] = {
                                damage_reduction = 1.0,
                                attack_speed_mult = 1.0,
                                attack_mult = 1.0
                            }
                        end
                        mods_by_instance_id[left_id].attack_speed_mult =
                            mods_by_instance_id[left_id].attack_speed_mult * 1.1 -- +10%
                    end
                end

                if i < #segments then -- Right neighbor
                    local right_neighbor = segments[i + 1]
                    if right_neighbor and right_neighbor.hp > 0 then
                        local right_id = right_neighbor.instance_id
                        if not mods_by_instance_id[right_id] then
                            mods_by_instance_id[right_id] = {
                                damage_reduction = 1.0,
                                attack_speed_mult = 1.0,
                                attack_mult = 1.0
                            }
                        end
                        mods_by_instance_id[right_id].attack_speed_mult =
                            mods_by_instance_id[right_id].attack_speed_mult * 1.1 -- +10%
                    end
                end
            end

            -- Berserker frenzy: +5% attack per kill
            if segment.special_id == "berserker_frenzy" then
                if not segment.special_state then
                    segment.special_state = { kill_count = 0 }
                end
                local kill_bonus = 1.0 + (segment.special_state.kill_count * 0.05)
                mods.attack_mult = mods.attack_mult * kill_bonus
            end
        end
    end

    return mods_by_instance_id
end

--- Handle attack events for special abilities (sniper crit, etc.)
--- @param ctx table Combat context
--- @param attack_event table Attack event to potentially modify
--- @param rng table RNG instance
--- @return table, table Modified attack_event, extra_events
function specials_system.on_attack(ctx, attack_event, rng)
    -- Properly copy the attack event preserving all fields
    local modified_event = {}
    for k, v in pairs(attack_event) do
        modified_event[k] = v
    end
    local extra_events = {}

    -- Sniper crit: 20% chance for 2x damage
    if attack_event.attacker_special_id == "sniper_crit" then
        local crit_roll = rng:float()
        if crit_roll < 0.2 then -- 20% chance
            modified_event.damage = modified_event.damage * 2
            modified_event.is_critical = true
        end
    end

    return modified_event, extra_events
end

--- Handle damage taken events for special abilities
--- @param ctx table Combat context
--- @param damage_event table Damage event to potentially modify
--- @return table, table Modified damage_event, extra_events
function specials_system.on_damage_taken(ctx, damage_event)
    -- Properly copy the damage event preserving all fields
    local modified_event = {}
    for k, v in pairs(damage_event) do
        modified_event[k] = v
    end
    local extra_events = {}

    -- Find the target segment
    local target_segment = nil
    if ctx.snake_state and ctx.snake_state.segments then
        for _, segment in ipairs(ctx.snake_state.segments) do
            if segment.instance_id == damage_event.target_instance_id then
                target_segment = segment
                break
            end
        end
    end

    if target_segment then
        -- Paladin divine shield: negate first nonzero hit per wave
        if target_segment.special_id == "paladin_divine_shield" then
            if not target_segment.special_state then
                target_segment.special_state = { shield_used = false }
            end

            if not target_segment.special_state.shield_used and modified_event.amount_int > 0 then
                modified_event.amount_int = 0
                target_segment.special_state.shield_used = true
                modified_event.negated_by_shield = true
            end
        end

        -- Knight block: 20% damage reduction
        if target_segment.special_id == "knight_block" and modified_event.amount_int > 0 then
            modified_event.amount_int = math.floor(modified_event.amount_int * 0.8)
            modified_event.reduced_by_block = true
        end
    end

    return modified_event, extra_events
end

--- Handle enemy death events for special abilities
--- @param ctx table Combat context
--- @param death_event table Enemy death event
--- @return table Array of extra events
function specials_system.on_enemy_death(ctx, death_event)
    local extra_events = {}

    -- Credit kills to berserker units
    if ctx.snake_state and ctx.snake_state.segments then
        for _, segment in ipairs(ctx.snake_state.segments) do
            if segment and segment.special_id == "berserker_frenzy" and segment.hp > 0 then
                if not segment.special_state then
                    segment.special_state = { kill_count = 0 }
                end
                segment.special_state.kill_count = segment.special_state.kill_count + 1
            end
        end
    end

    return extra_events
end

--- Handle wave start for special abilities (reset shields, etc.)
--- @param ctx table Combat context
function specials_system.on_wave_start(ctx)
    if not ctx or not ctx.snake_state or not ctx.snake_state.segments then
        return
    end

    -- Reset paladin shields
    for _, segment in ipairs(ctx.snake_state.segments) do
        if segment and segment.special_id == "paladin_divine_shield" then
            if not segment.special_state then
                segment.special_state = {}
            end
            segment.special_state.shield_used = false
        end
    end
end

--- Get passive modifiers for all segments by instance_id
--- @param snake_state table Snake state with segments
--- @param unit_defs table Unit definitions for class lookup
--- @return table Passive modifiers by instance_id
function specials_system.get_passive_mods(snake_state, unit_defs)
    local passive_mods = {}

    if not snake_state or not snake_state.segments then
        return passive_mods
    end

    -- Process each segment for passive effects
    for i, segment in ipairs(snake_state.segments) do
        if segment and segment.instance_id and segment.hp and segment.hp > 0 then
            local mods = {
                hp_mult = 1.0,
                atk_mult = 1.0,
                range_mult = 1.0,
                atk_spd_mult = 1.0,
                damage_taken_mult = 1.0
            }

            -- Knight block: 20% damage reduction
            if segment.special_id == "knight_block" then
                mods.damage_taken_mult = 0.8
            end

            -- Berserker frenzy: +5% attack per kill
            if segment.special_id == "berserker_frenzy" and segment.special_state then
                local kill_count = segment.special_state.kill_count or 0
                local attack_bonus = 1.0 + (kill_count * 0.05)
                mods.atk_mult = attack_bonus
            end

            passive_mods[segment.instance_id] = mods
        end
    end

    -- Process bard buffs (affects adjacent segments)
    for i, segment in ipairs(snake_state.segments) do
        if segment and segment.special_id == "bard_adjacent_atkspd" and segment.hp and segment.hp > 0 then
            -- Buff left neighbor
            if i > 1 then
                local left_neighbor = snake_state.segments[i - 1]
                if left_neighbor and left_neighbor.instance_id then
                    if not passive_mods[left_neighbor.instance_id] then
                        passive_mods[left_neighbor.instance_id] = {
                            hp_mult = 1.0, atk_mult = 1.0, range_mult = 1.0,
                            atk_spd_mult = 1.0, damage_taken_mult = 1.0
                        }
                    end
                    -- Stack multiplicatively with existing bonuses
                    passive_mods[left_neighbor.instance_id].atk_spd_mult =
                        passive_mods[left_neighbor.instance_id].atk_spd_mult * 1.10
                end
            end

            -- Buff right neighbor
            if i < #snake_state.segments then
                local right_neighbor = snake_state.segments[i + 1]
                if right_neighbor and right_neighbor.instance_id then
                    if not passive_mods[right_neighbor.instance_id] then
                        passive_mods[right_neighbor.instance_id] = {
                            hp_mult = 1.0, atk_mult = 1.0, range_mult = 1.0,
                            atk_spd_mult = 1.0, damage_taken_mult = 1.0
                        }
                    end
                    -- Stack multiplicatively with existing bonuses
                    passive_mods[right_neighbor.instance_id].atk_spd_mult =
                        passive_mods[right_neighbor.instance_id].atk_spd_mult * 1.10
                end
            end
        end
    end

    return passive_mods
end

return specials_system