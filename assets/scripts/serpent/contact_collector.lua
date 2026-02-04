-- assets/scripts/serpent/contact_collector.lua
--[[
    Contact Collector Module

    Manages physics collision tracking between snake units and enemies for
    the Serpent minigame. Provides deterministic contact event collection
    and cooldown management.
]]

local contact_collector = {}

-- Default contact damage and cooldown configuration
local DEFAULT_CONTACT_DAMAGE = 15
local DEFAULT_COOLDOWN_SEC = 0.5

--- Create a new contact collector state
--- @param contact_damage number Damage dealt per contact (default 15)
--- @param cooldown_sec number Cooldown between contacts (default 0.5)
--- @return table Contact collector state
function contact_collector.create_state(contact_damage, cooldown_sec)
    return {
        contact_damage = contact_damage or DEFAULT_CONTACT_DAMAGE,
        cooldown_sec = cooldown_sec or DEFAULT_COOLDOWN_SEC,
        registered_enemies = {}, -- enemy_id -> entity_id mapping
        registered_units = {},   -- instance_id -> entity_id mapping
        contact_cooldowns = {},  -- "enemy_id_instance_id" -> last_contact_time
        active_contacts = {},    -- Current frame contacts
        active_overlaps = {},    -- Set of current overlaps keyed by "enemy_id:instance_id"
        total_contacts = 0       -- Stats tracking
    }
end

--- Register an enemy entity for contact tracking
--- @param collector_state table Current collector state
--- @param enemy_id number Enemy ID
--- @param entity_id number Physics entity ID
--- @return table Updated collector state
function contact_collector.register_enemy(collector_state, enemy_id, entity_id)
    local updated_state = contact_collector._copy_state(collector_state)
    updated_state.registered_enemies[enemy_id] = entity_id
    return updated_state
end

--- Unregister an enemy entity
--- @param collector_state table Current collector state
--- @param enemy_id number Enemy ID
--- @return table Updated collector state
function contact_collector.unregister_enemy(collector_state, enemy_id)
    local updated_state = contact_collector._copy_state(collector_state)
    updated_state.registered_enemies[enemy_id] = nil

    -- Clean up any cooldowns for this enemy
    local keys_to_remove = {}
    for key, _ in pairs(updated_state.contact_cooldowns) do
        if string.match(key, "^" .. enemy_id .. "_") then
            table.insert(keys_to_remove, key)
        end
    end

    for _, key in ipairs(keys_to_remove) do
        updated_state.contact_cooldowns[key] = nil
    end

    return updated_state
end

--- Register a snake unit entity for contact tracking
--- @param collector_state table Current collector state
--- @param instance_id number Unit instance ID
--- @param entity_id number Physics entity ID
--- @return table Updated collector state
function contact_collector.register_unit(collector_state, instance_id, entity_id)
    local updated_state = contact_collector._copy_state(collector_state)
    updated_state.registered_units[instance_id] = entity_id
    return updated_state
end

--- Unregister a snake unit entity
--- @param collector_state table Current collector state
--- @param instance_id number Unit instance ID
--- @return table Updated collector state
function contact_collector.unregister_unit(collector_state, instance_id)
    local updated_state = contact_collector._copy_state(collector_state)
    updated_state.registered_units[instance_id] = nil

    -- Clean up any cooldowns for this unit
    local keys_to_remove = {}
    for key, _ in pairs(updated_state.contact_cooldowns) do
        if string.match(key, "_" .. instance_id .. "$") then
            table.insert(keys_to_remove, key)
        end
    end

    for _, key in ipairs(keys_to_remove) do
        updated_state.contact_cooldowns[key] = nil
    end

    return updated_state
end

--- Process physics contacts and generate damage events
--- @param collector_state table Current collector state
--- @param contact_events table Array of physics contact events
--- @param current_time number Current game time in seconds
--- @return table, table Updated state, array of DamageEventUnit events
function contact_collector.process_contacts(collector_state, contact_events, current_time)
    local updated_state = contact_collector._copy_state(collector_state)
    local damage_events = {}

    updated_state.active_contacts = {}
    updated_state.active_overlaps = {}

    -- Process each physics contact
    for _, contact_event in ipairs(contact_events or {}) do
        if contact_collector._is_valid_contact_event(contact_event) then
            local enemy_id, instance_id = contact_collector._identify_contact_entities(
                updated_state, contact_event)

            if enemy_id and instance_id then
                -- Track overlap using the specified key format
                local overlap_key = enemy_id .. ":" .. instance_id
                updated_state.active_overlaps[overlap_key] = {
                    enemy_id = enemy_id,
                    instance_id = instance_id,
                    contact_time = current_time
                }

                -- Record active contact
                table.insert(updated_state.active_contacts, {
                    enemy_id = enemy_id,
                    instance_id = instance_id,
                    contact_time = current_time
                })

                -- Check cooldown
                local cooldown_key = enemy_id .. "_" .. instance_id
                local last_contact = updated_state.contact_cooldowns[cooldown_key]

                if not last_contact or
                   (current_time - last_contact) >= updated_state.cooldown_sec then

                    -- Create damage event
                    table.insert(damage_events, {
                        type = "DamageEventUnit",
                        target_instance_id = instance_id,
                        amount_int = updated_state.contact_damage,
                        source_type = "enemy_contact",
                        source_id = enemy_id
                    })

                    -- Update cooldown
                    updated_state.contact_cooldowns[cooldown_key] = current_time
                    updated_state.total_contacts = updated_state.total_contacts + 1
                end
            end
        end
    end

    return updated_state, damage_events
end

--- Clear overlap and cooldown state without removing registrations
--- @param collector_state table Current collector state
--- @return table Updated collector state
function contact_collector.clear(collector_state)
    local updated_state = contact_collector._copy_state(collector_state)
    updated_state.contact_cooldowns = {}
    updated_state.active_contacts = {}
    updated_state.active_overlaps = {}
    updated_state.total_contacts = 0
    return updated_state
end

--- Cleanup expired cooldowns to prevent memory leaks
--- @param collector_state table Current collector state
--- @param current_time number Current game time
--- @return table Updated collector state
function contact_collector.cleanup_cooldowns(collector_state, current_time)
    local updated_state = contact_collector._copy_state(collector_state)

    local expiry_threshold = updated_state.cooldown_sec * 2
    local keys_to_remove = {}

    for key, last_time in pairs(updated_state.contact_cooldowns) do
        if (current_time - last_time) > expiry_threshold then
            table.insert(keys_to_remove, key)
        end
    end

    for _, key in ipairs(keys_to_remove) do
        updated_state.contact_cooldowns[key] = nil
    end

    return updated_state
end

--- Get contact collector status
--- @param collector_state table Collector state
--- @return table Status summary
function contact_collector.get_status(collector_state)
    return {
        registered_enemies = contact_collector._count_table(collector_state.registered_enemies),
        registered_units = contact_collector._count_table(collector_state.registered_units),
        active_cooldowns = contact_collector._count_table(collector_state.contact_cooldowns),
        active_contacts = #collector_state.active_contacts,
        active_overlaps = contact_collector._count_table(collector_state.active_overlaps),
        total_contacts = collector_state.total_contacts,
        contact_damage = collector_state.contact_damage,
        cooldown_sec = collector_state.cooldown_sec
    }
end

--- Get snapshot of current active contacts for combat processing
--- @param collector_state table Collector state
--- @return table Array of contact snapshots
function contact_collector.get_contact_snapshot(collector_state)
    local snapshot = {}
    for _, contact in ipairs(collector_state.active_contacts or {}) do
        table.insert(snapshot, {
            enemy_id = contact.enemy_id,
            instance_id = contact.instance_id,
            contact_time = contact.contact_time
        })
    end

    -- Sort for deterministic processing
    table.sort(snapshot, function(a, b)
        if a.enemy_id == b.enemy_id then
            return a.instance_id < b.instance_id
        end
        return a.enemy_id < b.enemy_id
    end)

    return snapshot
end

--- Check if two entities are currently overlapping
--- @param collector_state table Collector state
--- @param enemy_id number Enemy ID
--- @param instance_id number Unit instance ID
--- @return boolean True if entities are overlapping
function contact_collector.is_overlapping(collector_state, enemy_id, instance_id)
    local overlap_key = enemy_id .. ":" .. instance_id
    return collector_state.active_overlaps[overlap_key] ~= nil
end

--- Get all active overlaps as an array
--- @param collector_state table Collector state
--- @return table Array of overlap data
function contact_collector.get_active_overlaps(collector_state)
    local overlaps = {}
    for key, overlap in pairs(collector_state.active_overlaps or {}) do
        table.insert(overlaps, {
            key = key,
            enemy_id = overlap.enemy_id,
            instance_id = overlap.instance_id,
            contact_time = overlap.contact_time
        })
    end

    -- Sort for deterministic ordering
    table.sort(overlaps, function(a, b)
        return a.key < b.key
    end)

    return overlaps
end

--- Clear specific overlap (for testing or manual management)
--- @param collector_state table Collector state
--- @param enemy_id number Enemy ID
--- @param instance_id number Unit instance ID
--- @return table Updated collector state
function contact_collector.clear_overlap(collector_state, enemy_id, instance_id)
    local updated_state = contact_collector._copy_state(collector_state)
    local overlap_key = enemy_id .. ":" .. instance_id
    updated_state.active_overlaps[overlap_key] = nil
    return updated_state
end

--- Identify entities involved in a contact event
--- @param collector_state table Collector state
--- @param contact_event table Physics contact event
--- @return number, number enemy_id, instance_id (or nil if not relevant)
function contact_collector._identify_contact_entities(collector_state, contact_event)
    local entity_a = contact_event.entity_a
    local entity_b = contact_event.entity_b

    -- Find which entity is enemy and which is unit
    local enemy_id = nil
    local instance_id = nil

    -- Check if entity_a is enemy, entity_b is unit
    for eid, entity in pairs(collector_state.registered_enemies) do
        if entity == entity_a then
            enemy_id = eid
            break
        end
    end

    if enemy_id then
        for iid, entity in pairs(collector_state.registered_units) do
            if entity == entity_b then
                instance_id = iid
                break
            end
        end
    end

    -- Check if entity_b is enemy, entity_a is unit (reverse)
    if not enemy_id then
        for eid, entity in pairs(collector_state.registered_enemies) do
            if entity == entity_b then
                enemy_id = eid
                break
            end
        end

        if enemy_id then
            for iid, entity in pairs(collector_state.registered_units) do
                if entity == entity_a then
                    instance_id = iid
                    break
                end
            end
        end
    end

    return enemy_id, instance_id
end

--- Validate contact event structure
--- @param contact_event table Event to validate
--- @return boolean True if valid contact event
function contact_collector._is_valid_contact_event(contact_event)
    return contact_event and
           contact_event.entity_a and
           contact_event.entity_b and
           contact_event.entity_a ~= contact_event.entity_b
end

--- Deep copy collector state
--- @param state table State to copy
--- @return table Deep copy
function contact_collector._copy_state(state)
    local copy = {
        contact_damage = state.contact_damage,
        cooldown_sec = state.cooldown_sec,
        registered_enemies = {},
        registered_units = {},
        contact_cooldowns = {},
        active_contacts = {},
        active_overlaps = {},
        total_contacts = state.total_contacts
    }

    for k, v in pairs(state.registered_enemies) do
        copy.registered_enemies[k] = v
    end

    for k, v in pairs(state.registered_units) do
        copy.registered_units[k] = v
    end

    for k, v in pairs(state.contact_cooldowns) do
        copy.contact_cooldowns[k] = v
    end

    for _, contact in ipairs(state.active_contacts) do
        table.insert(copy.active_contacts, {
            enemy_id = contact.enemy_id,
            instance_id = contact.instance_id,
            contact_time = contact.contact_time
        })
    end

    for key, overlap in pairs(state.active_overlaps) do
        copy.active_overlaps[key] = {
            enemy_id = overlap.enemy_id,
            instance_id = overlap.instance_id,
            contact_time = overlap.contact_time
        }
    end

    return copy
end

--- Count entries in a table
--- @param t table Table to count
--- @return number Number of entries
function contact_collector._count_table(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

--- Test contact processing and cooldown behavior
--- @return boolean True if contact processing works correctly
function contact_collector.test_contact_processing()
    local collector_state = contact_collector.create_state(10, 1.0) -- 10 damage, 1s cooldown

    -- Register entities
    collector_state = contact_collector.register_enemy(collector_state, 2001, 101)
    collector_state = contact_collector.register_unit(collector_state, 3001, 201)

    -- Create contact event
    local contact_events = {
        { entity_a = 101, entity_b = 201 } -- Enemy 2001 touches unit 3001
    }

    -- Process at time 0
    local updated_state, damage_events = contact_collector.process_contacts(
        collector_state, contact_events, 0.0)

    -- Should generate damage event
    if #damage_events ~= 1 then
        return false
    end

    local damage_event = damage_events[1]
    if damage_event.target_instance_id ~= 3001 or
       damage_event.amount_int ~= 10 or
       damage_event.source_id ~= 2001 then
        return false
    end

    -- Process same contact again immediately - should be blocked by cooldown
    local updated_state2, damage_events2 = contact_collector.process_contacts(
        updated_state, contact_events, 0.1)

    if #damage_events2 ~= 0 then
        return false -- Should be blocked
    end

    -- Process after cooldown expires
    local updated_state3, damage_events3 = contact_collector.process_contacts(
        updated_state2, contact_events, 1.1)

    if #damage_events3 ~= 1 then
        return false -- Should allow contact again
    end

    return true
end

--- Test entity registration and cleanup
--- @return boolean True if registration works correctly
function contact_collector.test_entity_registration()
    local collector_state = contact_collector.create_state()

    -- Register entities
    collector_state = contact_collector.register_enemy(collector_state, 1001, 501)
    collector_state = contact_collector.register_unit(collector_state, 2001, 601)

    local status = contact_collector.get_status(collector_state)
    if status.registered_enemies ~= 1 or status.registered_units ~= 1 then
        return false
    end

    -- Unregister enemy
    collector_state = contact_collector.unregister_enemy(collector_state, 1001)

    status = contact_collector.get_status(collector_state)
    if status.registered_enemies ~= 0 or status.registered_units ~= 1 then
        return false
    end

    -- Unregister unit
    collector_state = contact_collector.unregister_unit(collector_state, 2001)

    status = contact_collector.get_status(collector_state)
    if status.registered_enemies ~= 0 or status.registered_units ~= 0 then
        return false
    end

    return true
end

--- Test cooldown cleanup
--- @return boolean True if cooldown cleanup works correctly
function contact_collector.test_cooldown_cleanup()
    local collector_state = contact_collector.create_state(10, 0.5)

    -- Register entities and process contact
    collector_state = contact_collector.register_enemy(collector_state, 1001, 501)
    collector_state = contact_collector.register_unit(collector_state, 2001, 601)

    local contact_events = {
        { entity_a = 501, entity_b = 601 }
    }

    -- Process contact at time 0
    collector_state, _ = contact_collector.process_contacts(
        collector_state, contact_events, 0.0)

    local status = contact_collector.get_status(collector_state)
    if status.active_cooldowns ~= 1 then
        return false
    end

    -- Cleanup at time that should expire cooldowns
    collector_state = contact_collector.cleanup_cooldowns(collector_state, 2.0)

    status = contact_collector.get_status(collector_state)
    if status.active_cooldowns ~= 0 then
        return false
    end

    return true
end

--- Test contact snapshot functionality
--- @return boolean True if contact snapshots work correctly
function contact_collector.test_contact_snapshot()
    local collector_state = contact_collector.create_state()

    -- Register multiple entities
    collector_state = contact_collector.register_enemy(collector_state, 1001, 501)
    collector_state = contact_collector.register_enemy(collector_state, 1002, 502)
    collector_state = contact_collector.register_unit(collector_state, 2001, 601)

    local contact_events = {
        { entity_a = 501, entity_b = 601 }, -- Enemy 1001 touches unit 2001
        { entity_a = 502, entity_b = 601 }  -- Enemy 1002 touches unit 2001
    }

    -- Process contacts
    collector_state, _ = contact_collector.process_contacts(
        collector_state, contact_events, 1.0)

    -- Get snapshot
    local snapshot = contact_collector.get_contact_snapshot(collector_state)

    -- Should have 2 contacts, sorted by enemy_id
    if #snapshot ~= 2 then
        return false
    end

    if snapshot[1].enemy_id ~= 1001 or snapshot[1].instance_id ~= 2001 then
        return false
    end

    if snapshot[2].enemy_id ~= 1002 or snapshot[2].instance_id ~= 2001 then
        return false
    end

    return true
end

--- Test overlap tracking functionality
--- @return boolean True if overlap tracking works correctly
function contact_collector.test_overlap_tracking()
    local collector_state = contact_collector.create_state()

    -- Register entities
    collector_state = contact_collector.register_enemy(collector_state, 1001, 501)
    collector_state = contact_collector.register_enemy(collector_state, 1002, 502)
    collector_state = contact_collector.register_unit(collector_state, 2001, 601)

    local contact_events = {
        { entity_a = 501, entity_b = 601 }, -- Enemy 1001 touches unit 2001
        { entity_a = 502, entity_b = 601 }, -- Enemy 1002 touches unit 2001
        { entity_a = 501, entity_b = 601 }  -- Duplicate contact (should not create duplicate overlap)
    }

    -- Process contacts
    local updated_state, _ = contact_collector.process_contacts(
        collector_state, contact_events, 1.0)

    -- Should have 2 overlaps (no duplicates)
    local overlaps = contact_collector.get_active_overlaps(updated_state)
    if #overlaps ~= 2 then
        return false
    end

    -- Check specific overlap exists
    if not contact_collector.is_overlapping(updated_state, 1001, 2001) then
        return false
    end

    if not contact_collector.is_overlapping(updated_state, 1002, 2001) then
        return false
    end

    -- Check overlap keys are in expected format
    local expected_keys = {"1001:2001", "1002:2001"}
    for i, overlap in ipairs(overlaps) do
        if overlap.key ~= expected_keys[i] then
            return false
        end
    end

    -- Test clearing overlap
    updated_state = contact_collector.clear_overlap(updated_state, 1001, 2001)
    if contact_collector.is_overlapping(updated_state, 1001, 2001) then
        return false
    end

    -- Other overlap should still exist
    if not contact_collector.is_overlapping(updated_state, 1002, 2001) then
        return false
    end

    return true
end

-- Compatibility aliases for enemy_spawner_adapter integration
contact_collector.register_enemy_entity = contact_collector.register_enemy
contact_collector.unregister_enemy_entity = contact_collector.unregister_enemy

-- Compatibility aliases for snake_entity_adapter integration
contact_collector.register_segment_entity = contact_collector.register_unit
contact_collector.unregister_segment_entity = contact_collector.unregister_unit

return contact_collector
