-- assets/scripts/serpent/enemy_entity_adapter.lua
--[[
    Enemy Entity Adapter Module

    Manages runtime enemy entities with physics bodies for the Serpent minigame.
    Bridges between pure enemy snapshots and runtime entity system.
]]

local PhysicsBuilder = require("core.physics_builder")
local C = require("core.constants")

-- Mock log functions for environments that don't have them
local log_debug = log_debug or function(msg) end
local log_warning = log_warning or function(msg) end
local log_error = log_error or function(msg) end

local enemy_entity_adapter = {}

-- Entity mapping and state
local enemy_id_to_entity_id = {}
local entity_id_to_enemy_id = {}
local spawned_enemies = {}

--- Initialize the adapter
function enemy_entity_adapter.init()
    enemy_id_to_entity_id = {}
    entity_id_to_enemy_id = {}
    spawned_enemies = {}
end

--- Spawn an enemy entity with physics body
--- @param enemy_id number Enemy ID
--- @param x number Initial X position
--- @param y number Initial Y position
--- @param radius number Enemy radius for physics collision (default 16)
--- @return number Entity ID of the spawned enemy
function enemy_entity_adapter.spawn_enemy(enemy_id, x, y, radius)
    radius = radius or 16

    if enemy_id_to_entity_id[enemy_id] then
        log_error("enemy_entity_adapter: enemy with enemy_id " .. enemy_id .. " already exists")
        return nil
    end

    -- Create the entity
    local entity_id = spawn()

    -- Set position
    physics.SetPosition(_G.physics, _G.registry, entity_id, x, y)

    -- Create physics body with ENEMY tag
    PhysicsBuilder.for_entity(entity_id)
        :circle()
        :tag(C.CollisionTags.ENEMY)
        :density(1.0)
        :friction(0.3)
        :fixedRotation(true)
        :apply()

    -- Update mappings
    enemy_id_to_entity_id[enemy_id] = entity_id
    entity_id_to_enemy_id[entity_id] = enemy_id
    spawned_enemies[enemy_id] = {
        entity_id = entity_id,
        enemy_id = enemy_id,
        spawn_time = love.timer.getTime()
    }

    -- Register with contact collector
    local contact_collector = enemy_entity_adapter._get_contact_collector()
    if contact_collector and contact_collector.register_enemy_entity then
        contact_collector.register_enemy_entity(enemy_id, entity_id)
    end

    log_debug(string.format("[EnemyEntityAdapter] Spawned enemy enemy_id=%d entity_id=%d at (%.1f,%.1f)",
              enemy_id, entity_id, x, y))

    return entity_id
end

--- Despawn an enemy entity
--- @param enemy_id number Enemy ID to despawn
function enemy_entity_adapter.despawn_enemy(enemy_id)
    local entity_id = enemy_id_to_entity_id[enemy_id]
    if not entity_id then
        log_warning("enemy_entity_adapter: attempt to despawn unknown enemy_id " .. enemy_id)
        return
    end

    -- Unregister from contact collector
    local contact_collector = enemy_entity_adapter._get_contact_collector()
    if contact_collector and contact_collector.unregister_enemy_entity then
        contact_collector.unregister_enemy_entity(enemy_id, entity_id)
    end

    -- Clean up entity
    despawn(entity_id)

    -- Clean up mappings
    enemy_id_to_entity_id[enemy_id] = nil
    entity_id_to_enemy_id[entity_id] = nil
    spawned_enemies[enemy_id] = nil

    log_debug(string.format("[EnemyEntityAdapter] Despawned enemy enemy_id=%d entity_id=%d",
              enemy_id, entity_id))
end

--- Update enemy position
--- @param enemy_id number Enemy ID
--- @param x number New X position
--- @param y number New Y position
function enemy_entity_adapter.set_enemy_position(enemy_id, x, y)
    local entity_id = enemy_id_to_entity_id[enemy_id]
    if not entity_id then
        log_warning("enemy_entity_adapter: attempt to position unknown enemy_id " .. enemy_id)
        return
    end

    physics.SetPosition(_G.physics, _G.registry, entity_id, x, y)
end

--- Set enemy velocity for movement
--- @param enemy_id number Enemy ID
--- @param vx number Velocity X component
--- @param vy number Velocity Y component
function enemy_entity_adapter.set_enemy_velocity(enemy_id, vx, vy)
    local entity_id = enemy_id_to_entity_id[enemy_id]
    if not entity_id then
        log_warning("enemy_entity_adapter: attempt to set velocity for unknown enemy_id " .. enemy_id)
        return
    end

    physics.SetVelocity(_G.physics, _G.registry, entity_id, vx, vy)
end

--- Sync entities with enemy snapshots (spawn/despawn as needed)
--- @param enemy_snapshots table Array of enemy snapshots with enemy_id, x, y
--- @param default_radius number Default enemy radius for new spawns
function enemy_entity_adapter.sync_with_enemy_snapshots(enemy_snapshots, default_radius)
    default_radius = default_radius or 16.0

    if not enemy_snapshots then
        enemy_snapshots = {}
    end

    local active_enemy_ids = {}

    -- Collect active enemy IDs and spawn/update positions
    for _, enemy_snap in ipairs(enemy_snapshots) do
        if enemy_snap and enemy_snap.enemy_id then
            active_enemy_ids[enemy_snap.enemy_id] = true

            -- Spawn if not exists
            if not enemy_id_to_entity_id[enemy_snap.enemy_id] then
                local x = enemy_snap.x or 0
                local y = enemy_snap.y or 0
                enemy_entity_adapter.spawn_enemy(enemy_snap.enemy_id, x, y, default_radius)
            else
                -- Update position if exists
                if enemy_snap.x and enemy_snap.y then
                    enemy_entity_adapter.set_enemy_position(enemy_snap.enemy_id, enemy_snap.x, enemy_snap.y)
                end
            end
        end
    end

    -- Despawn enemies no longer in snapshots
    local to_despawn = {}
    for enemy_id, _ in pairs(spawned_enemies) do
        if not active_enemy_ids[enemy_id] then
            table.insert(to_despawn, enemy_id)
        end
    end
    for _, enemy_id in ipairs(to_despawn) do
        enemy_entity_adapter.despawn_enemy(enemy_id)
    end
end

--- Build position snapshots for pure combat logic
--- @return table Array of EnemyPosSnapshot sorted by enemy_id
function enemy_entity_adapter.build_pos_snapshots()
    local snapshots = {}

    -- Get all spawned enemies and build position snapshots
    for enemy_id, enemy_info in pairs(spawned_enemies) do
        local entity_id = enemy_info.entity_id
        local pos = physics.GetPosition(_G.physics, _G.registry, entity_id)

        if pos then
            table.insert(snapshots, {
                enemy_id = enemy_id,
                x = pos.x or 0,
                y = pos.y or 0,
            })
        end
    end

    -- Sort by enemy_id to ensure consistent ordering
    table.sort(snapshots, function(a, b)
        return a.enemy_id < b.enemy_id
    end)

    return snapshots
end

--- Get entity ID for an enemy
--- @param enemy_id number Enemy ID
--- @return number|nil Entity ID or nil if not found
function enemy_entity_adapter.get_entity_id(enemy_id)
    return enemy_id_to_entity_id[enemy_id]
end

--- Get enemy ID for an entity
--- @param entity_id number Entity ID
--- @return number|nil Enemy ID or nil if not found
function enemy_entity_adapter.get_enemy_id(entity_id)
    return entity_id_to_enemy_id[entity_id]
end

--- Get all spawned enemy IDs
--- @return table Array of enemy IDs
function enemy_entity_adapter.get_spawned_enemy_ids()
    local enemy_ids = {}
    for enemy_id, _ in pairs(spawned_enemies) do
        table.insert(enemy_ids, enemy_id)
    end
    table.sort(enemy_ids)
    return enemy_ids
end

--- Get count of spawned enemies
--- @return number Number of spawned enemies
function enemy_entity_adapter.get_spawned_count()
    local count = 0
    for _, _ in pairs(spawned_enemies) do
        count = count + 1
    end
    return count
end

--- Check if enemy is spawned
--- @param enemy_id number Enemy ID to check
--- @return boolean True if enemy is spawned
function enemy_entity_adapter.is_enemy_spawned(enemy_id)
    return enemy_id_to_entity_id[enemy_id] ~= nil
end

--- Clean up all spawned enemies
function enemy_entity_adapter.cleanup()
    local to_despawn = {}
    for enemy_id, _ in pairs(spawned_enemies) do
        table.insert(to_despawn, enemy_id)
    end
    for _, enemy_id in ipairs(to_despawn) do
        enemy_entity_adapter.despawn_enemy(enemy_id)
    end
end

--- Get or create contact collector
--- @return table|nil Contact collector instance
function enemy_entity_adapter._get_contact_collector()
    -- Try to get existing contact collector
    if _G.serpent_contact_collector then
        return _G.serpent_contact_collector
    end

    -- Create a stub contact collector if none exists
    local stub_collector = {
        register_enemy_entity = function(enemy_id, entity_id)
            log_debug(string.format("[ContactCollectorStub] register_enemy_entity(%d, %d)",
                      enemy_id, entity_id))
        end,
        unregister_enemy_entity = function(enemy_id, entity_id)
            log_debug(string.format("[ContactCollectorStub] unregister_enemy_entity(%d, %d)",
                      enemy_id, entity_id))
        end,
    }

    _G.serpent_contact_collector = stub_collector
    return stub_collector
end

--- Get status information for debugging
--- @return table Status summary
function enemy_entity_adapter.get_status()
    return {
        spawned_count = enemy_entity_adapter.get_spawned_count(),
        spawned_enemy_ids = enemy_entity_adapter.get_spawned_enemy_ids()
    }
end

return enemy_entity_adapter