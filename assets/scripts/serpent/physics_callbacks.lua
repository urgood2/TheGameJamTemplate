-- assets/scripts/serpent/physics_callbacks.lua
--[[
    Physics Callbacks Module

    Registers physics collision callbacks (on_pair_begin, on_pair_separate) globally
    and integrates with the contact collector system for the Serpent minigame.
]]

local contact_collector = require("serpent.contact_collector")

-- Mock log functions for environments that don't have them
local log_debug = log_debug or function(msg) end
local log_warning = log_warning or function(msg) end
local log_error = log_error or function(msg) end

local physics_callbacks = {}

-- Global callback registration state
local callbacks_registered = false
local global_contact_collector_state = nil
local physics_contact_events = {}

--- Initialize physics callbacks and register them globally
--- @param collector_state table Initial contact collector state (optional)
function physics_callbacks.initialize(collector_state)
    if callbacks_registered then
        log_warning("[PhysicsCallbacks] Callbacks already registered, skipping")
        return
    end

    -- Initialize or use provided collector state
    global_contact_collector_state = collector_state or contact_collector.create_state()

    -- Register collision callbacks with the physics engine
    physics_callbacks._register_pair_callbacks()

    -- Set this module as the global contact collector
    _G.serpent_contact_collector = physics_callbacks

    callbacks_registered = true
    physics_contact_events = {}

    log_debug("[PhysicsCallbacks] Physics collision callbacks registered")
end

--- Cleanup physics callbacks (for testing/restart scenarios)
function physics_callbacks.cleanup()
    if not callbacks_registered then
        return
    end

    physics_callbacks.clear()

    -- Unregister callbacks if physics system supports it
    if _G.physics and _G.physics.UnregisterCallbacks then
        _G.physics.UnregisterCallbacks()
    end

    callbacks_registered = false
    global_contact_collector_state = nil
    physics_contact_events = {}

    log_debug("[PhysicsCallbacks] Physics callbacks cleaned up")
end

--- Clear overlap and cooldown state without removing registrations
function physics_callbacks.clear()
    if global_contact_collector_state then
        global_contact_collector_state = contact_collector.clear(global_contact_collector_state)
    end

    physics_contact_events = {}
    log_debug("[PhysicsCallbacks] Cleared overlap state")
end

--- Get the current contact collector state
--- @return table Contact collector state
function physics_callbacks.get_collector_state()
    return global_contact_collector_state
end

--- Update the global contact collector state
--- @param new_state table New collector state
function physics_callbacks.set_collector_state(new_state)
    global_contact_collector_state = new_state
end

--- Get accumulated physics contact events since last call
--- @return table Array of contact events
function physics_callbacks.get_contact_events()
    local events = physics_contact_events
    physics_contact_events = {} -- Clear for next frame
    return events
end

--- Process accumulated contact events through the collector
--- @param current_time number Current game time in seconds
--- @return table Array of DamageEventUnit events
function physics_callbacks.process_contacts(current_time)
    if not global_contact_collector_state then
        return {}
    end

    local contact_events = physics_callbacks.get_contact_events()

    local updated_state, damage_events = contact_collector.process_contacts(
        global_contact_collector_state, contact_events, current_time)

    global_contact_collector_state = updated_state

    return damage_events
end

--- Register an enemy entity with the global contact collector
--- @param enemy_id number Enemy ID
--- @param entity_id number Physics entity ID
function physics_callbacks.register_enemy(enemy_id, entity_id)
    if global_contact_collector_state then
        global_contact_collector_state = contact_collector.register_enemy(
            global_contact_collector_state, enemy_id, entity_id)
        log_debug(string.format("[PhysicsCallbacks] Registered enemy %d -> entity %d",
                  enemy_id, entity_id))
    end
end

--- Unregister an enemy entity from the global contact collector
--- @param enemy_id number Enemy ID
function physics_callbacks.unregister_enemy(enemy_id)
    if global_contact_collector_state then
        global_contact_collector_state = contact_collector.unregister_enemy(
            global_contact_collector_state, enemy_id)
        log_debug(string.format("[PhysicsCallbacks] Unregistered enemy %d", enemy_id))
    end
end

--- Register a snake unit entity with the global contact collector
--- @param instance_id number Unit instance ID
--- @param entity_id number Physics entity ID
function physics_callbacks.register_unit(instance_id, entity_id)
    if global_contact_collector_state then
        global_contact_collector_state = contact_collector.register_unit(
            global_contact_collector_state, instance_id, entity_id)
        log_debug(string.format("[PhysicsCallbacks] Registered unit %d -> entity %d",
                  instance_id, entity_id))
    end
end

--- Unregister a snake unit entity from the global contact collector
--- @param instance_id number Unit instance ID
function physics_callbacks.unregister_unit(instance_id)
    if global_contact_collector_state then
        global_contact_collector_state = contact_collector.unregister_unit(
            global_contact_collector_state, instance_id)
        log_debug(string.format("[PhysicsCallbacks] Unregistered unit %d", instance_id))
    end
end

--- Get contact collector status for debugging
--- @return table Status summary
function physics_callbacks.get_status()
    if not global_contact_collector_state then
        return {
            callbacks_registered = false,
            collector_initialized = false
        }
    end

    local status = contact_collector.get_status(global_contact_collector_state)
    status.callbacks_registered = callbacks_registered
    status.collector_initialized = true

    return status
end

--- Register the physics collision callbacks
function physics_callbacks._register_pair_callbacks()
    -- Check if physics system is available
    if not _G.physics then
        log_error("[PhysicsCallbacks] Physics system not available")
        return
    end

    -- Register on_pair_begin callback
    local on_pair_begin = function(entity_a, entity_b)
        -- Record contact event
        table.insert(physics_contact_events, {
            type = "contact_begin",
            entity_a = entity_a,
            entity_b = entity_b,
            timestamp = os.clock()
        })

        log_debug(string.format("[PhysicsCallbacks] Contact begin: %d <-> %d",
                  entity_a, entity_b))
    end

    -- Register on_pair_separate callback
    local on_pair_separate = function(entity_a, entity_b)
        -- Record separation event (not currently used for damage but logged)
        log_debug(string.format("[PhysicsCallbacks] Contact separate: %d <-> %d",
                  entity_a, entity_b))
    end

    -- Register with physics system
    if _G.physics.RegisterPairCallbacks then
        _G.physics.RegisterPairCallbacks(on_pair_begin, on_pair_separate)
        log_debug("[PhysicsCallbacks] Registered pair callbacks with physics system")
    elseif _G.physics.SetContactCallbacks then
        _G.physics.SetContactCallbacks(on_pair_begin, on_pair_separate)
        log_debug("[PhysicsCallbacks] Registered contact callbacks with physics system")
    else
        -- Fallback: store callbacks globally
        _G.serpent_physics_on_pair_begin = on_pair_begin
        _G.serpent_physics_on_pair_separate = on_pair_separate
        log_warning("[PhysicsCallbacks] Physics system doesn't support callbacks, stored globally")
    end
end

--- Manually trigger a contact event (for testing)
--- @param entity_a number First entity ID
--- @param entity_b number Second entity ID
function physics_callbacks.simulate_contact(entity_a, entity_b)
    table.insert(physics_contact_events, {
        type = "contact_begin",
        entity_a = entity_a,
        entity_b = entity_b,
        timestamp = os.clock()
    })
end

--- Cleanup expired cooldowns in the contact collector
--- @param current_time number Current game time
function physics_callbacks.cleanup_cooldowns(current_time)
    if global_contact_collector_state then
        global_contact_collector_state = contact_collector.cleanup_cooldowns(
            global_contact_collector_state, current_time)
    end
end

--- Check if physics callbacks are registered
--- @return boolean True if callbacks are registered
function physics_callbacks.is_initialized()
    return callbacks_registered
end

--- Get contact snapshot for combat processing
--- @return table Array of active contact snapshots
function physics_callbacks.get_contact_snapshot()
    if global_contact_collector_state then
        return contact_collector.get_contact_snapshot(global_contact_collector_state)
    end
    return {}
end

--- Test physics callback registration and contact processing
--- @return boolean True if callbacks work correctly
function physics_callbacks.test_callback_registration()
    -- Initialize callbacks
    physics_callbacks.initialize()

    if not physics_callbacks.is_initialized() then
        return false
    end

    -- Register test entities
    physics_callbacks.register_enemy(1001, 501)
    physics_callbacks.register_unit(2001, 601)

    -- Simulate contact
    physics_callbacks.simulate_contact(501, 601)

    -- Process contacts at time 1.0
    local damage_events = physics_callbacks.process_contacts(1.0)

    -- Should generate damage event
    if #damage_events ~= 1 then
        return false
    end

    local damage_event = damage_events[1]
    if damage_event.target_instance_id ~= 2001 or
       damage_event.source_id ~= 1001 then
        return false
    end

    -- Cleanup
    physics_callbacks.cleanup()

    return true
end

--- Test entity registration through physics callbacks
--- @return boolean True if entity registration works correctly
function physics_callbacks.test_entity_registration()
    physics_callbacks.initialize()

    -- Register entities
    physics_callbacks.register_enemy(1001, 501)
    physics_callbacks.register_unit(2001, 601)

    local status = physics_callbacks.get_status()
    if status.registered_enemies ~= 1 or status.registered_units ~= 1 then
        return false
    end

    -- Unregister entities
    physics_callbacks.unregister_enemy(1001)
    physics_callbacks.unregister_unit(2001)

    status = physics_callbacks.get_status()
    if status.registered_enemies ~= 0 or status.registered_units ~= 0 then
        return false
    end

    physics_callbacks.cleanup()
    return true
end

--- Test contact event accumulation
--- @return boolean True if contact events accumulate correctly
function physics_callbacks.test_contact_accumulation()
    physics_callbacks.initialize()

    -- Simulate multiple contacts
    physics_callbacks.simulate_contact(501, 601)
    physics_callbacks.simulate_contact(502, 601)
    physics_callbacks.simulate_contact(501, 602)

    local events = physics_callbacks.get_contact_events()

    -- Should have 3 events
    if #events ~= 3 then
        return false
    end

    -- Events should be cleared after getting them
    local events2 = physics_callbacks.get_contact_events()
    if #events2 ~= 0 then
        return false
    end

    physics_callbacks.cleanup()
    return true
end

-- Compatibility aliases for enemy_spawner_adapter integration
physics_callbacks.register_enemy_entity = physics_callbacks.register_enemy
physics_callbacks.unregister_enemy_entity = physics_callbacks.unregister_enemy

-- Compatibility aliases for snake_entity_adapter integration
physics_callbacks.register_segment_entity = physics_callbacks.register_unit
physics_callbacks.unregister_segment_entity = physics_callbacks.unregister_unit

return physics_callbacks
