-- assets/scripts/serpent/contact_collector_adapter.lua
--[[
    Contact Collector Adapter Module

    Provides object-oriented interface for enemy entity registration that wraps
    the functional contact_collector module. Manages global collector state
    and provides the register_enemy_entity/unregister_enemy_entity API.
]]

local contact_collector = require("serpent.contact_collector")

local contact_collector_adapter = {}

-- Global collector state
local collector_state = nil

--- Initialize the contact collector adapter
function contact_collector_adapter.init()
    collector_state = contact_collector.create_state(15, 0.5) -- 15 damage, 0.5s cooldown
    log_debug("[ContactCollectorAdapter] Initialized with collector state")
end

--- Get the current collector state
--- @return table Current collector state
function contact_collector_adapter.get_state()
    if not collector_state then
        contact_collector_adapter.init()
    end
    return collector_state
end

--- Update the collector state
--- @param new_state table New collector state
function contact_collector_adapter.set_state(new_state)
    collector_state = new_state
end

--- Register an enemy entity for contact tracking
--- @param enemy_id number Enemy ID
--- @param entity_id number Physics entity ID
function contact_collector_adapter.register_enemy_entity(enemy_id, entity_id)
    if not collector_state then
        contact_collector_adapter.init()
    end

    log_debug(string.format("[ContactCollectorAdapter] Registering enemy: enemy_id=%d, entity_id=%d",
              enemy_id, entity_id))

    collector_state = contact_collector.register_enemy(collector_state, enemy_id, entity_id)
end

--- Unregister an enemy entity with overlap cleanup
--- @param enemy_id number Enemy ID
--- @param entity_id number Physics entity ID (optional, for validation)
function contact_collector_adapter.unregister_enemy_entity(enemy_id, entity_id)
    if not collector_state then
        log_warning("[ContactCollectorAdapter] No collector state during unregister")
        return
    end

    log_debug(string.format("[ContactCollectorAdapter] Unregistering enemy: enemy_id=%d, entity_id=%d",
              enemy_id, entity_id or -1))

    -- Validate entity_id if provided
    if entity_id then
        local registered_entity_id = collector_state.registered_enemies[enemy_id]
        if registered_entity_id and registered_entity_id ~= entity_id then
            log_warning(string.format(
                "[ContactCollectorAdapter] Entity ID mismatch during unregister: expected=%d, actual=%d",
                registered_entity_id, entity_id))
        end
    end

    -- Unregister with overlap cleanup (handled by contact_collector.unregister_enemy)
    collector_state = contact_collector.unregister_enemy(collector_state, enemy_id)
end

--- Register a snake unit entity for contact tracking
--- @param instance_id number Unit instance ID
--- @param entity_id number Physics entity ID
function contact_collector_adapter.register_unit_entity(instance_id, entity_id)
    if not collector_state then
        contact_collector_adapter.init()
    end

    log_debug(string.format("[ContactCollectorAdapter] Registering unit: instance_id=%d, entity_id=%d",
              instance_id, entity_id))

    collector_state = contact_collector.register_unit(collector_state, instance_id, entity_id)
end

--- Unregister a snake unit entity
--- @param instance_id number Unit instance ID
--- @param entity_id number Physics entity ID (optional, for validation)
function contact_collector_adapter.unregister_unit_entity(instance_id, entity_id)
    if not collector_state then
        log_warning("[ContactCollectorAdapter] No collector state during unit unregister")
        return
    end

    log_debug(string.format("[ContactCollectorAdapter] Unregistering unit: instance_id=%d, entity_id=%d",
              instance_id, entity_id or -1))

    -- Validate entity_id if provided
    if entity_id then
        local registered_entity_id = collector_state.registered_units[instance_id]
        if registered_entity_id and registered_entity_id ~= entity_id then
            log_warning(string.format(
                "[ContactCollectorAdapter] Unit entity ID mismatch during unregister: expected=%d, actual=%d",
                registered_entity_id, entity_id))
        end
    end

    collector_state = contact_collector.unregister_unit(collector_state, instance_id)
end

--- Process physics contact events and return damage events
--- @param contact_events table Array of physics contact events
--- @param current_time number Current game time in seconds
--- @return table Array of DamageEventUnit events
function contact_collector_adapter.process_contacts(contact_events, current_time)
    if not collector_state then
        return {}
    end

    local updated_state, damage_events = contact_collector.process_contacts(
        collector_state, contact_events, current_time)

    collector_state = updated_state
    return damage_events
end

--- Get contact collector status
--- @return table Status summary
function contact_collector_adapter.get_status()
    if not collector_state then
        return {
            registered_enemies = 0,
            registered_units = 0,
            active_cooldowns = 0,
            active_contacts = 0,
            total_contacts = 0
        }
    end

    return contact_collector.get_status(collector_state)
end

--- Cleanup expired cooldowns to prevent memory leaks
--- @param current_time number Current game time
function contact_collector_adapter.cleanup_cooldowns(current_time)
    if not collector_state then
        return
    end

    collector_state = contact_collector.cleanup_cooldowns(collector_state, current_time)
end

--- Get snapshot of current active contacts
--- @return table Array of contact snapshots
function contact_collector_adapter.get_contact_snapshot()
    if not collector_state then
        return {}
    end

    return contact_collector.get_contact_snapshot(collector_state)
end

--- Clear overlap and cooldown state without removing registrations
function contact_collector_adapter.clear()
    if not collector_state then
        return
    end

    collector_state = contact_collector.clear(collector_state)
    log_debug("[ContactCollectorAdapter] Cleared overlap state")
end

--- Build ContactSnapshot sorted by (enemy_id, instance_id)
--- @return table ContactSnapshot array sorted by (enemy_id, instance_id)
function contact_collector_adapter.build_snapshot()
    if not collector_state then
        return {}
    end

    -- Get the sorted contact snapshot
    local snapshot = contact_collector.get_contact_snapshot(collector_state)

    log_debug(string.format("[ContactCollectorAdapter] Built snapshot with %d contacts", #snapshot))

    return snapshot
end

--- Reset the collector state
function contact_collector_adapter.reset()
    collector_state = contact_collector.create_state(15, 0.5)
    log_debug("[ContactCollectorAdapter] Reset collector state")
end

--- Register a segment entity for contact tracking (alias for register_unit_entity)
--- @param instance_id number Segment instance ID
--- @param entity_id number Physics entity ID
function contact_collector_adapter.register_segment_entity(instance_id, entity_id)
    log_debug(string.format("[ContactCollectorAdapter] Registering segment (via unit): instance_id=%d, entity_id=%d",
              instance_id, entity_id))

    contact_collector_adapter.register_unit_entity(instance_id, entity_id)
end

--- Unregister a segment entity with overlap cleanup (alias for unregister_unit_entity)
--- @param instance_id number Segment instance ID
--- @param entity_id number Physics entity ID (optional, for validation)
function contact_collector_adapter.unregister_segment_entity(instance_id, entity_id)
    log_debug(string.format("[ContactCollectorAdapter] Unregistering segment (via unit): instance_id=%d, entity_id=%d",
              instance_id, entity_id or -1))

    contact_collector_adapter.unregister_unit_entity(instance_id, entity_id)
end

--- Cleanup all registrations and reset
function contact_collector_adapter.cleanup()
    contact_collector_adapter.clear()
    collector_state = nil
    log_debug("[ContactCollectorAdapter] Cleanup complete")
end

return contact_collector_adapter
