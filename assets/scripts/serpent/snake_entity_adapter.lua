-- assets/scripts/serpent/snake_entity_adapter.lua
--[[
    Snake Entity Adapter Module

    Manages runtime snake segment entities with physics bodies.
    Bridges between pure snake_state and runtime entity system.
]]

local PhysicsBuilder = require("core.physics_builder")
local C = require("core.constants")

local snake_entity_adapter = {}

-- Entity mapping and state
local instance_id_to_entity_id = {}
local entity_id_to_instance_id = {}
local spawned_segments = {}
local segment_spawn_order = {} -- Tracks instance_ids in spawn order (head→tail)

--- Initialize the adapter
function snake_entity_adapter.init()
    instance_id_to_entity_id = {}
    entity_id_to_instance_id = {}
    spawned_segments = {}
    segment_spawn_order = {}
end

--- Spawn a segment entity with physics body
--- @param instance_id number Segment instance ID
--- @param x number Initial X position
--- @param y number Initial Y position
--- @param radius number Segment radius for physics collision
--- @return number Entity ID of the spawned segment
function snake_entity_adapter.spawn_segment(instance_id, x, y, radius)
    if instance_id_to_entity_id[instance_id] then
        error("snake_entity_adapter: segment with instance_id " .. instance_id .. " already exists")
    end

    -- Create the entity
    local entity_id = spawn()

    -- Set position
    physics.SetPosition(_G.physics, _G.registry, entity_id, x, y)

    -- Create physics body with SERPENT_SEGMENT tag
    PhysicsBuilder.for_entity(entity_id)
        :circle()
        :tag(C.CollisionTags.SERPENT_SEGMENT)
        :density(1.0)
        :friction(0.8)
        :fixedRotation(true)
        :apply()

    -- Update mappings
    instance_id_to_entity_id[instance_id] = entity_id
    entity_id_to_instance_id[entity_id] = instance_id
    spawned_segments[instance_id] = {
        entity_id = entity_id,
        instance_id = instance_id,
    }

    -- Track spawn order for head→tail ordering
    table.insert(segment_spawn_order, instance_id)

    -- Register with contact collector
    local contact_collector = snake_entity_adapter._get_contact_collector()
    if contact_collector and contact_collector.register_segment_entity then
        contact_collector.register_segment_entity(instance_id, entity_id)
    end

    log_debug(string.format("[SnakeEntityAdapter] Spawned segment instance_id=%d entity_id=%d",
              instance_id, entity_id))

    return entity_id
end

--- Despawn a segment entity
--- @param instance_id number Segment instance ID to despawn
function snake_entity_adapter.despawn_segment(instance_id)
    local entity_id = instance_id_to_entity_id[instance_id]
    if not entity_id then
        log_warning("snake_entity_adapter: attempt to despawn unknown instance_id " .. instance_id)
        return
    end

    -- Unregister from contact collector
    local contact_collector = snake_entity_adapter._get_contact_collector()
    if contact_collector and contact_collector.unregister_segment_entity then
        contact_collector.unregister_segment_entity(instance_id, entity_id)
    end

    -- Clean up entity
    despawn(entity_id)

    -- Clean up mappings
    instance_id_to_entity_id[instance_id] = nil
    entity_id_to_instance_id[entity_id] = nil
    spawned_segments[instance_id] = nil

    -- Remove from spawn order tracking
    for i, tracked_instance_id in ipairs(segment_spawn_order) do
        if tracked_instance_id == instance_id then
            table.remove(segment_spawn_order, i)
            break
        end
    end

    log_debug(string.format("[SnakeEntityAdapter] Despawned segment instance_id=%d entity_id=%d",
              instance_id, entity_id))
end

--- Update segment position
--- @param instance_id number Segment instance ID
--- @param x number New X position
--- @param y number New Y position
function snake_entity_adapter.set_segment_position(instance_id, x, y)
    local entity_id = instance_id_to_entity_id[instance_id]
    if not entity_id then
        log_warning("snake_entity_adapter: attempt to position unknown instance_id " .. instance_id)
        return
    end

    physics.SetPosition(_G.physics, _G.registry, entity_id, x, y)
end

--- Sync entities with snake state (spawn/despawn as needed)
--- @param snake_state table Current snake state with segments
--- @param default_radius number Default segment radius for new spawns
function snake_entity_adapter.sync_with_snake_state(snake_state, default_radius)
    default_radius = default_radius or 16.0

    if not snake_state or not snake_state.segments then
        -- Despawn all existing segments
        local to_despawn = {}
        for instance_id, _ in pairs(spawned_segments) do
            table.insert(to_despawn, instance_id)
        end
        for _, instance_id in ipairs(to_despawn) do
            snake_entity_adapter.despawn_segment(instance_id)
        end
        return
    end

    local segments = snake_state.segments
    local active_instances = {}

    -- Collect active instance IDs
    for _, segment in ipairs(segments) do
        if segment and segment.instance_id then
            active_instances[segment.instance_id] = true

            -- Spawn if not exists
            if not instance_id_to_entity_id[segment.instance_id] then
                local x = segment.x or 0
                local y = segment.y or 0
                snake_entity_adapter.spawn_segment(segment.instance_id, x, y, default_radius)
            end
        end
    end

    -- Despawn segments no longer in snake state
    local to_despawn = {}
    for instance_id, _ in pairs(spawned_segments) do
        if not active_instances[instance_id] then
            table.insert(to_despawn, instance_id)
        end
    end
    for _, instance_id in ipairs(to_despawn) do
        snake_entity_adapter.despawn_segment(instance_id)
    end
end

--- Build position snapshots for pure combat logic
--- @return table Array of SegmentPosSnapshot in head→tail order
function snake_entity_adapter.build_pos_snapshots()
    local snapshots = {}

    -- Iterate segments in spawn order (head→tail)
    for _, instance_id in ipairs(segment_spawn_order) do
        local segment_info = spawned_segments[instance_id]
        if segment_info then
            local entity_id = segment_info.entity_id
            local pos = physics.GetPosition(_G.physics, _G.registry, entity_id)

            if pos then
                table.insert(snapshots, {
                    instance_id = instance_id,
                    x = pos.x or 0,
                    y = pos.y or 0,
                })
            end
        end
    end

    return snapshots
end

--- Build position snapshots ordered by snake state segments
--- @param snake_state table Current snake state with segments in head→tail order
--- @return table Array of SegmentPosSnapshot in head→tail order matching snake_state
function snake_entity_adapter.build_pos_snapshots_ordered(snake_state)
    local snapshots = {}

    if not snake_state or not snake_state.segments then
        return snapshots
    end

    -- Iterate segments in head→tail order from snake_state
    for _, segment in ipairs(snake_state.segments) do
        if segment and segment.instance_id then
            local entity_id = instance_id_to_entity_id[segment.instance_id]
            if entity_id then
                local pos = physics.GetPosition(_G.physics, _G.registry, entity_id)
                if pos then
                    table.insert(snapshots, {
                        instance_id = segment.instance_id,
                        x = pos.x or 0,
                        y = pos.y or 0,
                    })
                end
            end
        end
    end

    return snapshots
end

--- Get entity ID for a segment instance
--- @param instance_id number Segment instance ID
--- @return number|nil Entity ID or nil if not found
function snake_entity_adapter.get_entity_id(instance_id)
    return instance_id_to_entity_id[instance_id]
end

--- Get instance ID for an entity
--- @param entity_id number Entity ID
--- @return number|nil Instance ID or nil if not found
function snake_entity_adapter.get_instance_id(entity_id)
    return entity_id_to_instance_id[entity_id]
end

--- Clean up all spawned segments
function snake_entity_adapter.cleanup()
    local to_despawn = {}
    for instance_id, _ in pairs(spawned_segments) do
        table.insert(to_despawn, instance_id)
    end
    for _, instance_id in ipairs(to_despawn) do
        snake_entity_adapter.despawn_segment(instance_id)
    end
end

--- Get or create contact collector (stub implementation)
--- @return table|nil Contact collector instance
function snake_entity_adapter._get_contact_collector()
    -- Try to get existing contact collector
    if _G.serpent_contact_collector then
        return _G.serpent_contact_collector
    end

    -- Create a stub contact collector if none exists
    local stub_collector = {
        register_segment_entity = function(instance_id, entity_id)
            log_debug(string.format("[ContactCollectorStub] register_segment_entity(%d, %d)",
                      instance_id, entity_id))
        end,
        unregister_segment_entity = function(instance_id, entity_id)
            log_debug(string.format("[ContactCollectorStub] unregister_segment_entity(%d, %d)",
                      instance_id, entity_id))
        end,
    }

    _G.serpent_contact_collector = stub_collector
    return stub_collector
end

return snake_entity_adapter