-- assets/scripts/serpent/combat_adapter.lua
--[[
    Combat Adapter Module

    Applies combat events to runtime entities, including death events
    that trigger entity despawn and contact collector unregister.
    This is step 4 in the COMBAT update order per PLAN.md.
]]

local combat_adapter = {}

-- Logging stubs for testing
local log_debug = log_debug or function(msg) end
local log_warning = log_warning or function(msg) end

--- Apply combat events to runtime entities
--- @param events table Array of combat events (DamageEventEnemy, DeathEventEnemy, DeathEventUnit, etc.)
--- @param snake_entities table Snake entity adapter instance
--- @param enemy_entities table Enemy entity management (could be enemy_spawner_adapter or separate enemy entity system)
--- @param contact_collector table Contact collision tracker
function combat_adapter.apply(events, snake_entities, enemy_entities, contact_collector)
    if not events then
        return
    end

    -- Process events in the order they were emitted for determinism
    for _, event in ipairs(events) do
        if event and event.kind then
            -- Handle death events that require entity cleanup
            if event.kind == "enemy_dead" then
                combat_adapter._handle_enemy_death(event, enemy_entities, contact_collector)
            elseif event.kind == "unit_dead" then
                combat_adapter._handle_unit_death(event, snake_entities, contact_collector)
            elseif event.kind == "damage_enemy" then
                combat_adapter._handle_enemy_damage_visual(event, enemy_entities)
            elseif event.kind == "damage_unit" then
                combat_adapter._handle_unit_damage_visual(event, snake_entities)
            elseif event.kind == "heal_unit" then
                combat_adapter._handle_unit_heal_visual(event, snake_entities)
            end
        end
    end
end

--- Handle enemy death event by despawning the enemy entity
--- @param event table DeathEventEnemy with enemy_id
--- @param enemy_entities table Enemy entity management
--- @param contact_collector table Contact collision tracker
function combat_adapter._handle_enemy_death(event, enemy_entities, contact_collector)
    if not event.enemy_id then
        log_warning("combat_adapter: DeathEventEnemy missing enemy_id")
        return
    end

    -- Despawn enemy entity if enemy_entities has despawn method
    if enemy_entities and enemy_entities.despawn_enemy then
        enemy_entities.despawn_enemy(event.enemy_id)
    end

    -- Unregister from contact collector if needed
    if contact_collector and contact_collector.unregister_enemy_entity then
        contact_collector.unregister_enemy_entity(event.enemy_id)
    end

    log_debug(string.format("[CombatAdapter] Processed enemy death: enemy_id=%d", event.enemy_id))
end

--- Handle unit death event by despawning the segment entity
--- @param event table DeathEventUnit with instance_id
--- @param snake_entities table Snake entity adapter
--- @param contact_collector table Contact collision tracker
function combat_adapter._handle_unit_death(event, snake_entities, contact_collector)
    if not event.instance_id then
        log_warning("combat_adapter: DeathEventUnit missing instance_id")
        return
    end

    -- Despawn segment entity using existing snake entity adapter method
    if snake_entities and snake_entities.despawn_segment then
        snake_entities.despawn_segment(event.instance_id)
    end

    -- Unregister from contact collector if needed
    if contact_collector and contact_collector.unregister_unit_entity then
        contact_collector.unregister_unit_entity(event.instance_id)
    end

    log_debug(string.format("[CombatAdapter] Processed unit death: instance_id=%d", event.instance_id))
end

--- Handle enemy damage for visual effects (optional, may be no-op in v-slice)
--- @param event table DamageEventEnemy
--- @param enemy_entities table Enemy entity management
function combat_adapter._handle_enemy_damage_visual(event, enemy_entities)
    -- No-op for v-slice - pure combat state is authoritative
    -- Future: could trigger damage numbers, screen shake, etc.
end

--- Handle unit damage for visual effects (optional, may be no-op in v-slice)
--- @param event table DamageEventUnit
--- @param snake_entities table Snake entity adapter
function combat_adapter._handle_unit_damage_visual(event, snake_entities)
    -- No-op for v-slice - pure combat state is authoritative
    -- Future: could trigger damage numbers, screen shake, etc.
end

--- Handle unit heal for visual effects (optional, may be no-op in v-slice)
--- @param event table HealEventUnit
--- @param snake_entities table Snake entity adapter
function combat_adapter._handle_unit_heal_visual(event, snake_entities)
    -- No-op for v-slice - pure combat state is authoritative
    -- Future: could trigger heal numbers, glow effects, etc.
end

--- Get summary of events that would be processed
--- @param events table Array of combat events
--- @return table Summary of event processing
function combat_adapter.get_event_summary(events)
    local summary = {
        total_events = #(events or {}),
        enemy_deaths = 0,
        unit_deaths = 0,
        enemy_damage = 0,
        unit_damage = 0,
        unit_heals = 0,
        other_events = 0
    }

    if not events then
        return summary
    end

    for _, event in ipairs(events) do
        if event and event.kind then
            if event.kind == "enemy_dead" then
                summary.enemy_deaths = summary.enemy_deaths + 1
            elseif event.kind == "unit_dead" then
                summary.unit_deaths = summary.unit_deaths + 1
            elseif event.kind == "damage_enemy" then
                summary.enemy_damage = summary.enemy_damage + 1
            elseif event.kind == "damage_unit" then
                summary.unit_damage = summary.unit_damage + 1
            elseif event.kind == "heal_unit" then
                summary.unit_heals = summary.unit_heals + 1
            else
                summary.other_events = summary.other_events + 1
            end
        end
    end

    return summary
end

--- Test death event processing
--- @return boolean True if death event handling works correctly
function combat_adapter.test_death_event_processing()
    -- Track method calls on mock objects
    local despawn_calls = {}
    local unregister_calls = {}

    -- Mock snake entities with despawn tracking
    local mock_snake_entities = {
        despawn_segment = function(instance_id)
            table.insert(despawn_calls, { type = "segment", id = instance_id })
        end
    }

    -- Mock enemy entities with despawn tracking
    local mock_enemy_entities = {
        despawn_enemy = function(enemy_id)
            table.insert(despawn_calls, { type = "enemy", id = enemy_id })
        end
    }

    -- Mock contact collector with unregister tracking
    local mock_contact_collector = {
        unregister_enemy_entity = function(enemy_id)
            table.insert(unregister_calls, { type = "enemy", id = enemy_id })
        end,
        unregister_unit_entity = function(instance_id)
            table.insert(unregister_calls, { type = "unit", id = instance_id })
        end
    }

    -- Test events
    local events = {
        { kind = "enemy_dead", enemy_id = 10 },
        { kind = "unit_dead", instance_id = 5 },
        { kind = "damage_enemy", target_enemy_id = 11, amount_int = 25 }
    }

    -- Apply events
    combat_adapter.apply(events, mock_snake_entities, mock_enemy_entities, mock_contact_collector)

    -- Should have despawned one enemy and one unit
    if #despawn_calls ~= 2 then
        return false
    end

    -- Check enemy despawn
    local enemy_despawn = nil
    local unit_despawn = nil
    for _, call in ipairs(despawn_calls) do
        if call.type == "enemy" and call.id == 10 then
            enemy_despawn = call
        elseif call.type == "segment" and call.id == 5 then
            unit_despawn = call
        end
    end

    if not enemy_despawn or not unit_despawn then
        return false
    end

    -- Should have unregistered both the enemy and unit from contact collector
    if #unregister_calls ~= 2 then
        return false
    end

    -- Check enemy unregister
    local enemy_unregister = nil
    local unit_unregister = nil
    for _, call in ipairs(unregister_calls) do
        if call.type == "enemy" and call.id == 10 then
            enemy_unregister = call
        elseif call.type == "unit" and call.id == 5 then
            unit_unregister = call
        end
    end

    if not enemy_unregister or not unit_unregister then
        return false
    end

    return true
end

return combat_adapter