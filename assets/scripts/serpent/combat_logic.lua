-- Serpent Combat Logic Module
-- Handles combat mechanics for the Serpent minigame

local rng = require("serpent.rng")
local game_logic = require("serpent.game_logic")
local synergy_system = require("serpent.synergy_system")
local specials_system = require("serpent.specials_system")

-- Mock log functions for environments that don't have them
local log_debug = log_debug or function(msg) end
local log_warning = log_warning or function(msg) end

local combat_logic = {}

-- Combat state structure
local CombatState = {}
CombatState.__index = CombatState

function CombatState.new(player_units, enemy_units, wave_number)
    local state = {
        player_units = player_units or {},
        enemy_units = enemy_units or {},
        turn = 1,
        phase = "player", -- "player" or "enemy"
        wave_number = wave_number or 1,
        combat_log = {},
        time_elapsed = 0,
        is_complete = false,
        winner = nil
    }
    setmetatable(state, CombatState)
    return state
end

-- Combat phases
local COMBAT_PHASES = {
    PLAYER = "player",
    ENEMY = "enemy",
    COMPLETE = "complete"
}

--[[
    Initialize combat between player snake and enemy wave

    @param player_snake SnakeState - Player's snake formation
    @param enemy_wave table - Enemy units for this wave
    @param wave_number number - Current wave number
    @return CombatState - New combat state
]]
function combat_logic.init_combat(player_snake, enemy_wave, wave_number)
    if not player_snake or not enemy_wave then
        error("init_combat: player_snake and enemy_wave are required")
    end

    -- Copy units to avoid modifying originals
    local player_units = {}
    for _, unit in ipairs(player_snake.units) do
        player_units[#player_units + 1] = table.copy(unit)
    end

    local enemy_units = {}
    for _, unit in ipairs(enemy_wave) do
        enemy_units[#enemy_units + 1] = table.copy(unit)
    end

    local combat_state = CombatState.new(player_units, enemy_units, wave_number)

    log_debug(string.format("[CombatLogic] Combat initialized - Wave %d: %d player vs %d enemy units",
                           wave_number, #player_units, #enemy_units))

    return combat_state
end

--[[
    Process one combat turn

    @param combat_state CombatState - Current combat state
    @param dt number - Delta time in seconds
    @return CombatState - Updated combat state
]]
function combat_logic.update_combat(combat_state, dt)
    if combat_state.is_complete then
        return combat_state
    end

    combat_state.time_elapsed = combat_state.time_elapsed + dt

    -- Process special abilities (healers, buffs, etc.)
    combat_state.player_units = game_logic.process_specials(combat_state.player_units, dt)

    -- Check for combat completion
    if is_combat_complete(combat_state) then
        finish_combat(combat_state)
        return combat_state
    end

    -- Process combat actions based on phase
    if combat_state.phase == COMBAT_PHASES.PLAYER then
        process_player_phase(combat_state)
        combat_state.phase = COMBAT_PHASES.ENEMY
    elseif combat_state.phase == COMBAT_PHASES.ENEMY then
        process_enemy_phase(combat_state)
        combat_state.phase = COMBAT_PHASES.PLAYER
        combat_state.turn = combat_state.turn + 1
    end

    return combat_state
end

--[[
    Process player units' actions

    @param combat_state CombatState - Combat state to modify
]]
function process_player_phase(combat_state)
    for _, unit in ipairs(combat_state.player_units) do
        if is_unit_alive(unit) then
            -- Find target and attack
            local target = find_target(unit, combat_state.enemy_units, "enemy")
            if target then
                perform_attack(unit, target, combat_state)
            end
        end
    end
end

--[[
    Process enemy units' actions

    @param combat_state CombatState - Combat state to modify
]]
function process_enemy_phase(combat_state)
    for _, unit in ipairs(combat_state.enemy_units) do
        if is_unit_alive(unit) then
            -- Find target and attack
            local target = find_target(unit, combat_state.player_units, "player")
            if target then
                perform_attack(unit, target, combat_state)
            end
        end
    end
end

--[[
    Find the best target for a unit to attack

    @param attacker table - Attacking unit
    @param targets table - Array of potential target units
    @param target_type string - "player" or "enemy"
    @return table|nil - Target unit or nil
]]
function find_target(attacker, targets, target_type)
    local alive_targets = {}
    for _, target in ipairs(targets) do
        if is_unit_alive(target) then
            table.insert(alive_targets, target)
        end
    end

    if #alive_targets == 0 then
        return nil
    end

    -- Simple targeting: attack first alive unit (front of formation)
    return alive_targets[1]
end

--[[
    Perform an attack between two units

    @param attacker table - Attacking unit
    @param target table - Target unit
    @param combat_state CombatState - Combat state for logging
]]
function perform_attack(attacker, target, combat_state)
    local damage = calculate_damage(attacker, target)

    -- Apply damage
    target.stats.hp = math.max(0, target.stats.hp - damage)

    -- Log the attack
    local log_entry = string.format("Turn %d: %s attacks %s for %d damage (HP: %d -> %d)",
                                   combat_state.turn,
                                   attacker.type or "unknown",
                                   target.type or "unknown",
                                   damage,
                                   target.stats.hp + damage,
                                   target.stats.hp)
    table.insert(combat_state.combat_log, log_entry)

    log_debug("[CombatLogic] " .. log_entry)

    -- Check if target died
    if target.stats.hp <= 0 then
        table.insert(combat_state.combat_log,
                     string.format("%s has been defeated!", target.type or "unit"))
    end
end

--[[
    Calculate damage for an attack

    @param attacker table - Attacking unit
    @param target table - Target unit
    @return number - Damage amount
]]
function calculate_damage(attacker, target)
    local base_damage = attacker.stats.attack or 25
    local target_defense = target.stats.defense or 0

    -- Apply random variance (±20%)
    local prng = rng.create(os.time())
    local variance = prng:float(0.8, 1.2)

    local final_damage = math.floor((base_damage - target_defense) * variance)
    return math.max(1, final_damage) -- Minimum 1 damage
end

--[[
    Check if a unit is alive

    @param unit table - Unit to check
    @return boolean - True if alive
]]
function is_unit_alive(unit)
    return unit and unit.stats and unit.stats.hp and unit.stats.hp > 0
end

--[[
    Check if combat is complete

    @param combat_state CombatState - Combat state to check
    @return boolean - True if combat is over
]]
function is_combat_complete(combat_state)
    local living_players = 0
    local living_enemies = 0

    for _, unit in ipairs(combat_state.player_units) do
        if is_unit_alive(unit) then
            living_players = living_players + 1
        end
    end

    for _, unit in ipairs(combat_state.enemy_units) do
        if is_unit_alive(unit) then
            living_enemies = living_enemies + 1
        end
    end

    return living_players == 0 or living_enemies == 0
end

--[[
    Finish combat and determine winner

    @param combat_state CombatState - Combat state to finalize
]]
function finish_combat(combat_state)
    combat_state.is_complete = true

    local living_players = 0
    for _, unit in ipairs(combat_state.player_units) do
        if is_unit_alive(unit) then
            living_players = living_players + 1
        end
    end

    if living_players > 0 then
        combat_state.winner = "player"
        table.insert(combat_state.combat_log, "Victory! Player wins!")
    else
        combat_state.winner = "enemy"
        table.insert(combat_state.combat_log, "Defeat! Enemies win!")
    end

    log_debug(string.format("[CombatLogic] Combat complete - Winner: %s (Turn %d)",
                           combat_state.winner, combat_state.turn))
end

--[[
    Process contact damage between units

    @param contact_snapshot table - Array of contact events {enemy_id, instance_id}
    @param player_units table - Player units array
    @param enemy_units table - Enemy units array
    @param contact_cooldowns table - Cooldown tracking table
    @param current_time number - Current game time in seconds
    @return number - Number of contact damage events processed
]]
function combat_logic.process_contact_damage(contact_snapshot, player_units, enemy_units, contact_cooldowns, current_time)
    if not contact_snapshot or #contact_snapshot == 0 then
        return 0
    end

    local CONTACT_DAMAGE = 15 -- Base contact damage
    local COOLDOWN_DURATION = 0.5 -- 0.5 seconds cooldown
    local damage_events = 0

    -- Sort contact snapshot by enemy_id, then instance_id for deterministic processing
    table.sort(contact_snapshot, function(a, b)
        if a.enemy_id == b.enemy_id then
            return a.instance_id < b.instance_id
        end
        return a.enemy_id < b.enemy_id
    end)

    -- Initialize cooldowns table if not provided
    contact_cooldowns = contact_cooldowns or {}

    -- Process each contact event
    for _, contact in ipairs(contact_snapshot) do
        local enemy_id = contact.enemy_id
        local instance_id = contact.instance_id

        -- Create cooldown key
        local cooldown_key = enemy_id .. "_" .. instance_id

        -- Check cooldown gating
        local last_contact_time = contact_cooldowns[cooldown_key]
        if not last_contact_time or (current_time - last_contact_time) >= COOLDOWN_DURATION then

            -- Find the units involved
            local enemy_unit = find_unit_by_id(enemy_units, enemy_id)
            local player_unit = find_unit_by_id(player_units, instance_id)

            if enemy_unit and player_unit and is_unit_alive(player_unit) then
                -- Apply contact damage to player unit
                local damage = calculate_contact_damage(enemy_unit, player_unit)
                player_unit.stats.hp = math.max(0, player_unit.stats.hp - damage)

                -- Update cooldown
                contact_cooldowns[cooldown_key] = current_time

                damage_events = damage_events + 1

                log_debug(string.format("[CombatLogic] Contact damage: Enemy %d -> Player %d (%d damage, HP: %d)",
                                       enemy_id, instance_id, damage, player_unit.stats.hp))

                -- Check if player unit died from contact
                if player_unit.stats.hp <= 0 then
                    log_debug(string.format("[CombatLogic] Player unit %d destroyed by contact damage", instance_id))
                end
            end
        else
            local remaining_cooldown = COOLDOWN_DURATION - (current_time - last_contact_time)
            log_debug(string.format("[CombatLogic] Contact blocked by cooldown: %s (%.2fs remaining)",
                                   cooldown_key, remaining_cooldown))
        end
    end

    if damage_events > 0 then
        log_debug(string.format("[CombatLogic] Processed %d contact damage events from %d contacts",
                               damage_events, #contact_snapshot))
    end

    return damage_events
end

--[[
    Calculate contact damage between enemy and player unit

    @param enemy_unit table - Enemy unit dealing damage
    @param player_unit table - Player unit taking damage
    @return number - Contact damage amount
]]
function calculate_contact_damage(enemy_unit, player_unit)
    local base_damage = 15

    -- Scale damage based on enemy stats
    local enemy_power = enemy_unit.stats.attack or enemy_unit.stats.power or 20
    local scaling_factor = enemy_power / 20 -- Normalize to base power of 20

    -- Consider player defense
    local player_defense = player_unit.stats.defense or 0

    local final_damage = math.floor((base_damage * scaling_factor) - (player_defense * 0.5))
    return math.max(1, final_damage) -- Minimum 1 damage
end

--[[
    Find a unit by its ID in a units array

    @param units table - Array of units
    @param unit_id number - ID to search for
    @return table|nil - Unit with matching ID or nil
]]
function find_unit_by_id(units, unit_id)
    for _, unit in ipairs(units) do
        if unit.id == unit_id then
            return unit
        end
    end
    return nil
end

--[[
    Clean up expired cooldowns to prevent memory leaks

    @param contact_cooldowns table - Cooldown tracking table
    @param current_time number - Current game time
    @param cooldown_duration number - Cooldown duration (default 0.5s)
]]
function combat_logic.cleanup_contact_cooldowns(contact_cooldowns, current_time, cooldown_duration)
    cooldown_duration = cooldown_duration or 0.5

    for key, last_time in pairs(contact_cooldowns) do
        if (current_time - last_time) > (cooldown_duration * 2) then
            contact_cooldowns[key] = nil
        end
    end
end

-- Utility function for deep copying tables
function table.copy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = type(v) == "table" and table.copy(v) or v
    end
    return copy
end

--[[
    Implement boss injection for milestone waves
    Wave 10: prepend swarm_queen to forced_queue
    Wave 20: prepend lich_king to forced_queue
]]
function combat_logic.inject_boss(wave_number, forced_queue, boss_defs)
    local boss_injected = false

    if wave_number == 10 and boss_defs["swarm_queen"] then
        table.insert(forced_queue, 1, {
            unit_type = "swarm_queen",
            unit_def = boss_defs["swarm_queen"],
            is_boss = true,
            wave_number = wave_number
        })
        boss_injected = true
        log_debug("[CombatLogic] Injected Swarm Queen boss for Wave 10")
    end

    if wave_number == 20 and boss_defs["lich_king"] then
        table.insert(forced_queue, 1, {
            unit_type = "lich_king",
            unit_def = boss_defs["lich_king"],
            is_boss = true,
            wave_number = wave_number
        })
        boss_injected = true
        log_debug("[CombatLogic] Injected Lich King boss for Wave 20")
    end

    return boss_injected
end

--===========================================================================
-- POSITION MERGE PHASE
-- Synchronizes physics positions with combat snapshots
--===========================================================================

--- Update enemy combat snapshots with current physics positions
--- @param enemy_snaps table Array of enemy combat snapshots
--- @param enemy_pos_snaps table Array of enemy position snapshots from physics
--- @return table Updated enemy_snaps with synchronized x/y positions
function combat_logic.merge_enemy_positions(enemy_snaps, enemy_pos_snaps)
    if not enemy_snaps or not enemy_pos_snaps then
        log_warning("[CombatLogic] merge_enemy_positions: missing required parameters")
        return enemy_snaps or {}
    end

    -- Build lookup table for enemy positions by enemy_id
    local pos_by_enemy_id = {}
    for _, pos_snap in ipairs(enemy_pos_snaps) do
        if pos_snap and pos_snap.enemy_id then
            pos_by_enemy_id[pos_snap.enemy_id] = {
                x = pos_snap.x or 0,
                y = pos_snap.y or 0
            }
        end
    end

    -- Update enemy_snaps with current physics positions
    local updated_count = 0
    for _, enemy_snap in ipairs(enemy_snaps) do
        if enemy_snap and enemy_snap.enemy_id then
            local physics_pos = pos_by_enemy_id[enemy_snap.enemy_id]
            if physics_pos then
                enemy_snap.x = physics_pos.x
                enemy_snap.y = physics_pos.y
                updated_count = updated_count + 1
            else
                log_warning(string.format("[CombatLogic] No physics position for enemy_id=%d", enemy_snap.enemy_id))
            end
        end
    end

    log_debug(string.format("[CombatLogic] Updated %d enemy positions from physics", updated_count))
    return enemy_snaps
end

--- Build segment position lookup table from physics snapshots
--- @param segment_pos_snaps table Array of segment position snapshots from physics
--- @return table Lookup table: segment_positions_by_instance_id[instance_id] = {x, y}
function combat_logic.build_segment_positions_by_instance_id(segment_pos_snaps)
    local segment_positions_by_instance_id = {}

    if not segment_pos_snaps then
        log_warning("[CombatLogic] build_segment_positions_by_instance_id: missing segment_pos_snaps")
        return segment_positions_by_instance_id
    end

    for _, pos_snap in ipairs(segment_pos_snaps) do
        if pos_snap and pos_snap.instance_id then
            segment_positions_by_instance_id[pos_snap.instance_id] = {
                x = pos_snap.x or 0,
                y = pos_snap.y or 0
            }
        end
    end

    local count = 0
    for _ in pairs(segment_positions_by_instance_id) do count = count + 1 end
    log_debug(string.format("[CombatLogic] Built segment position lookup for %d instances", count))

    return segment_positions_by_instance_id
end

--- Merge all position data for combat (combines enemy and segment position merging)
--- @param enemy_snaps table Array of enemy combat snapshots to update
--- @param enemy_pos_snaps table Array of enemy position snapshots from physics
--- @param segment_pos_snaps table Array of segment position snapshots from physics
--- @return table, table Updated enemy_snaps, segment_positions_by_instance_id lookup table
function combat_logic.merge_positions(enemy_snaps, enemy_pos_snaps, segment_pos_snaps)
    log_debug("[CombatLogic] Starting position merge phase")

    -- Update enemy combat snapshots with physics positions
    local updated_enemy_snaps = combat_logic.merge_enemy_positions(enemy_snaps, enemy_pos_snaps)

    -- Build segment position lookup table
    local segment_positions_by_instance_id = combat_logic.build_segment_positions_by_instance_id(segment_pos_snaps)

    log_debug("[CombatLogic] Position merge phase completed")
    return updated_enemy_snaps, segment_positions_by_instance_id
end

--===========================================================================
-- SYNERGY + PASSIVE MULTIPLIER PHASE
-- Computes synergy state, passive modifiers, and effective stats per segment.
--===========================================================================

--- Compute synergy state, passive modifiers, and effective stats for segments
--- @param snake_state table Current snake state
--- @param unit_defs table Unit definitions keyed by def_id
--- @param segment_positions_by_instance_id table Optional position lookup {instance_id={x,y}}
--- @return table, table, table, table Updated snake_state, synergy_state, passive_mods, segment_combat_snaps
function combat_logic.compute_synergy_and_passives(snake_state, unit_defs, segment_positions_by_instance_id)
    local base_state = snake_state or { segments = {}, min_len = 3, max_len = 8 }
    local segments = base_state.segments or {}

    local synergy_state = synergy_system.calculate(segments, unit_defs)
    local passive_mods_by_instance_id = specials_system.get_passive_mods(base_state, unit_defs)

    local updated_state = {
        segments = {},
        min_len = base_state.min_len or 3,
        max_len = base_state.max_len or 8
    }

    local segment_combat_snaps = {}
    local support_bonuses = (synergy_state.active_bonuses and synergy_state.active_bonuses.Support) or {}

    for _, segment in ipairs(segments) do
        if segment and segment.instance_id then
            local updated_segment = table.copy(segment)
            local unit_def = unit_defs and segment.def_id and unit_defs[segment.def_id] or nil
            local unit_class = unit_def and unit_def.class or nil

            local hp_mult = 1.0
            local atk_mult = 1.0
            local range_mult = 1.0
            local atk_spd_mult = 1.0
            local cooldown_period_mult = 1.0

            -- Apply Support synergy "all stats" globally (only once per segment)
            if support_bonuses.hp_mult then
                hp_mult = hp_mult * support_bonuses.hp_mult
            end
            if support_bonuses.atk_mult then
                atk_mult = atk_mult * support_bonuses.atk_mult
            end
            if support_bonuses.range_mult then
                range_mult = range_mult * support_bonuses.range_mult
            end
            if support_bonuses.atk_spd_mult then
                atk_spd_mult = atk_spd_mult * support_bonuses.atk_spd_mult
            end

            -- Apply class-specific synergy bonuses (skip Support to avoid double-count)
            if unit_class and unit_class ~= "Support" and synergy_state.active_bonuses then
                local class_bonuses = synergy_state.active_bonuses[unit_class] or {}
                if class_bonuses.hp_mult then
                    hp_mult = hp_mult * class_bonuses.hp_mult
                end
                if class_bonuses.atk_mult then
                    atk_mult = atk_mult * class_bonuses.atk_mult
                end
                if class_bonuses.range_mult then
                    range_mult = range_mult * class_bonuses.range_mult
                end
                if class_bonuses.atk_spd_mult then
                    atk_spd_mult = atk_spd_mult * class_bonuses.atk_spd_mult
                end
                if class_bonuses.cooldown_period_mult then
                    cooldown_period_mult = cooldown_period_mult * class_bonuses.cooldown_period_mult
                end
            end

            -- Apply passive modifiers from specials (multiplicative stacking)
            local passive_mods = passive_mods_by_instance_id[segment.instance_id] or {}
            hp_mult = hp_mult * (passive_mods.hp_mult or 1.0)
            atk_mult = atk_mult * (passive_mods.atk_mult or 1.0)
            range_mult = range_mult * (passive_mods.range_mult or 1.0)
            atk_spd_mult = atk_spd_mult * (passive_mods.atk_spd_mult or 1.0)

            -- Compute effective stats (no drift)
            local hp_max_base = segment.hp_max_base or 0
            local attack_base = segment.attack_base or 0
            local range_base = segment.range_base or 0
            local atk_spd_base = segment.atk_spd_base or 0

            local effective_hp_max = math.floor((hp_max_base * hp_mult) + 0.00001)
            local effective_attack = math.floor((attack_base * atk_mult) + 0.00001)
            local effective_range = range_base * range_mult
            local effective_atk_spd = atk_spd_base * atk_spd_mult

            local effective_period = math.huge
            if effective_atk_spd > 0 then
                effective_period = (1 / effective_atk_spd) * cooldown_period_mult
            end

            -- Clamp HP to effective max if it decreases
            if updated_segment.hp and updated_segment.hp > effective_hp_max then
                updated_segment.hp = effective_hp_max
            end

            table.insert(updated_state.segments, updated_segment)

            local pos = segment_positions_by_instance_id and
                        segment_positions_by_instance_id[segment.instance_id] or nil

            table.insert(segment_combat_snaps, {
                instance_id = segment.instance_id,
                def_id = segment.def_id,
                special_id = segment.special_id,
                x = pos and pos.x or 0,
                y = pos and pos.y or 0,
                cooldown_num = segment.cooldown or 0,
                effective_hp_max_int = effective_hp_max,
                effective_attack_int = effective_attack,
                effective_range_num = effective_range,
                effective_atk_spd_num = effective_atk_spd,
                effective_period_num = effective_period,
                damage_taken_mult = passive_mods.damage_taken_mult or 1.0
            })
        end
    end

    return updated_state, synergy_state, passive_mods_by_instance_id, segment_combat_snaps
end

--- Test position merge functionality
--- @return boolean True if position merge works correctly
function combat_logic.test_position_merge()
    -- Test data: enemy snapshots with outdated positions
    local enemy_snaps = {
        {enemy_id = 1, x = 100, y = 100, hp = 50},
        {enemy_id = 3, x = 200, y = 200, hp = 30}
    }

    -- Test data: current physics positions (different from combat snapshots)
    local enemy_pos_snaps = {
        {enemy_id = 1, x = 150, y = 125},
        {enemy_id = 3, x = 225, y = 175}
    }

    -- Test data: segment position snapshots
    local segment_pos_snaps = {
        {instance_id = 10, x = 300, y = 400},
        {instance_id = 11, x = 320, y = 420}
    }

    -- Test position merging
    local updated_enemy_snaps, segment_positions = combat_logic.merge_positions(
        enemy_snaps, enemy_pos_snaps, segment_pos_snaps
    )

    -- Check that enemy positions were updated
    if updated_enemy_snaps[1].x ~= 150 or updated_enemy_snaps[1].y ~= 125 then
        log_warning("[CombatLogic] Enemy position merge test failed for enemy_id=1")
        return false
    end

    if updated_enemy_snaps[2].x ~= 225 or updated_enemy_snaps[2].y ~= 175 then
        log_warning("[CombatLogic] Enemy position merge test failed for enemy_id=3")
        return false
    end

    -- Check that segment position lookup was built correctly
    if not segment_positions[10] or segment_positions[10].x ~= 300 or segment_positions[10].y ~= 400 then
        log_warning("[CombatLogic] Segment position lookup test failed for instance_id=10")
        return false
    end

    if not segment_positions[11] or segment_positions[11].x ~= 320 or segment_positions[11].y ~= 420 then
        log_warning("[CombatLogic] Segment position lookup test failed for instance_id=11")
        return false
    end

    -- Check that original data structure wasn't damaged
    if updated_enemy_snaps[1].hp ~= 50 or updated_enemy_snaps[2].hp ~= 30 then
        log_warning("[CombatLogic] Position merge damaged original enemy data")
        return false
    end

    log_debug("[CombatLogic] Position merge tests passed")
    return true
end

-- Export combat phases and state class
combat_logic.COMBAT_PHASES = COMBAT_PHASES
combat_logic.CombatState = CombatState

return combat_logic
