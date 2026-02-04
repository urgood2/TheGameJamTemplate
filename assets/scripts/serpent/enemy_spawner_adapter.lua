-- assets/scripts/serpent/enemy_spawner_adapter.lua
--[[
    Enemy Spawner Adapter Module

    Consumes SpawnEnemyEvent from wave director and creates runtime enemy entities.
    Implements deterministic spawn positioning and enemy snapshot management.
]]

local enemy_factory = require("serpent.enemy_factory")
local PhysicsBuilder = require("core.physics_builder")
local C = require("core.constants")

local enemy_spawner_adapter = {}

-- Spawn rate configuration constants
local SPAWN_RATE_PER_SEC = 10
local MAX_SPAWNS_PER_FRAME = 3

-- Entity mapping and state
local enemy_id_to_entity_id = {}
local entity_id_to_enemy_id = {}
local spawned_enemies = {}

--- Initialize the adapter
function enemy_spawner_adapter.init()
    enemy_id_to_entity_id = {}
    entity_id_to_enemy_id = {}
    spawned_enemies = {}
end

--- Compute spawn position using edge_random algorithm
--- @param rng table RNG instance for deterministic positioning
--- @param spawn_rule table Spawn rule with { mode="edge_random", arena={ w, h, padding } }
--- @return number, number x, y spawn coordinates
function enemy_spawner_adapter.compute_spawn_position(rng, spawn_rule)
    if not spawn_rule or spawn_rule.mode ~= "edge_random" then
        error("enemy_spawner_adapter: unsupported spawn_rule mode: " .. tostring(spawn_rule.mode))
    end

    local arena = spawn_rule.arena
    if not arena then
        error("enemy_spawner_adapter: spawn_rule missing arena configuration")
    end

    local w = arena.w or 800
    local h = arena.h or 600
    local padding = arena.padding or 50

    -- Choose edge index (1=left, 2=right, 3=top, 4=bottom)
    local edge = rng:int(1, 4)

    -- Choose coordinate along edge
    local t = rng:float()

    -- Compute position based on edge
    local x, y
    if edge == 1 then -- left
        x = padding
        y = padding + t * (h - 2 * padding)
    elseif edge == 2 then -- right
        x = w - padding
        y = padding + t * (h - 2 * padding)
    elseif edge == 3 then -- top
        x = padding + t * (w - 2 * padding)
        y = padding
    else -- edge == 4, bottom
        x = padding + t * (w - 2 * padding)
        y = h - padding
    end

    return x, y
end

--- Spawn a single enemy from SpawnEnemyEvent
--- @param spawn_event table SpawnEnemyEvent { kind="spawn_enemy", enemy_id, def_id, spawn_rule }
--- @param rng table RNG instance for deterministic positioning
--- @param wave_num number Current wave number for scaling
--- @param enemy_defs table Enemy definitions
--- @param wave_config table Wave configuration (unused but part of API)
--- @return table Enemy snapshot
function enemy_spawner_adapter.spawn_enemy(spawn_event, rng, wave_num, enemy_defs, wave_config)
    local enemy_id = spawn_event.enemy_id
    local def_id = spawn_event.def_id
    local spawn_rule = spawn_event.spawn_rule

    if enemy_id_to_entity_id[enemy_id] then
        error("enemy_spawner_adapter: enemy with enemy_id " .. enemy_id .. " already exists")
    end

    -- Get enemy definition
    local enemy_def = enemy_defs and enemy_defs[def_id]
    if not enemy_def then
        error("enemy_spawner_adapter: enemy definition not found for def_id: " .. tostring(def_id))
    end

    -- Compute spawn position
    local x, y = enemy_spawner_adapter.compute_spawn_position(rng, spawn_rule)

    -- Create enemy snapshot with scaled stats
    local enemy_snapshot = enemy_factory.create_snapshot(enemy_def, enemy_id, wave_num, wave_config, x, y)

    -- Create the runtime entity
    local entity_id = spawn()

    -- Set position
    physics.SetPosition(_G.physics, _G.registry, entity_id, x, y)

    -- Create physics body with ENEMY tag
    PhysicsBuilder.for_entity(entity_id)
        :circle()
        :tag(C.CollisionTags.ENEMY)
        :density(1.0)
        :friction(0.5)
        :fixedRotation(true)
        :apply()

    -- Update mappings
    enemy_id_to_entity_id[enemy_id] = entity_id
    entity_id_to_enemy_id[entity_id] = enemy_id
    spawned_enemies[enemy_id] = {
        entity_id = entity_id,
        enemy_id = enemy_id,
        snapshot = enemy_snapshot,
    }

    -- Register with contact collector
    local contact_collector = enemy_spawner_adapter._get_contact_collector()
    if contact_collector and contact_collector.register_enemy_entity then
        contact_collector.register_enemy_entity(enemy_id, entity_id)
    end

    log_debug(string.format("[EnemySpawnerAdapter] Spawned enemy_id=%d def_id=%s at (%.1f,%.1f)",
              enemy_id, def_id, x, y))

    return enemy_snapshot
end

--- Despawn an enemy entity
--- @param enemy_id number Enemy ID to despawn
function enemy_spawner_adapter.despawn_enemy(enemy_id)
    local enemy_info = spawned_enemies[enemy_id]
    if not enemy_info then
        log_warning("enemy_spawner_adapter: attempt to despawn unknown enemy_id " .. enemy_id)
        return
    end

    local entity_id = enemy_info.entity_id

    -- Unregister from contact collector
    local contact_collector = enemy_spawner_adapter._get_contact_collector()
    if contact_collector and contact_collector.unregister_enemy_entity then
        contact_collector.unregister_enemy_entity(enemy_id, entity_id)
    end

    -- Clean up entity
    despawn(entity_id)

    -- Clean up mappings
    enemy_id_to_entity_id[enemy_id] = nil
    entity_id_to_enemy_id[entity_id] = nil
    spawned_enemies[enemy_id] = nil

    log_debug(string.format("[EnemySpawnerAdapter] Despawned enemy_id=%d entity_id=%d",
              enemy_id, entity_id))
end

--- Apply multiple spawn events and return updated enemy snapshots
--- @param spawn_events table Array of SpawnEnemyEvent
--- @param enemy_entities table Current enemy entities (not directly used but part of API)
--- @param enemy_snaps table Current enemy snapshots array
--- @param rng table RNG instance for deterministic positioning
--- @param wave_num number Current wave number for scaling
--- @param enemy_defs table Enemy definitions
--- @param wave_config table Wave configuration
--- @return table, table Updated enemy_entities, updated enemy_snaps (sorted by enemy_id)
function enemy_spawner_adapter.apply(spawn_events, enemy_entities, enemy_snaps, rng, wave_num, enemy_defs, wave_config)
    local updated_snaps = enemy_snaps and {table.unpack(enemy_snaps)} or {}

    -- Process each spawn event
    for _, event in ipairs(spawn_events or {}) do
        if event.kind == "spawn_enemy" then
            local new_snapshot = enemy_spawner_adapter.spawn_enemy(
                event, rng, wave_num, enemy_defs, wave_config
            )
            table.insert(updated_snaps, new_snapshot)
        else
            log_warning("enemy_spawner_adapter: unknown spawn event kind: " .. tostring(event.kind))
        end
    end

    -- Sort snapshots by enemy_id to maintain contract
    table.sort(updated_snaps, function(a, b)
        return a.enemy_id < b.enemy_id
    end)

    log_debug(string.format("[EnemySpawnerAdapter] Applied %d spawn events, %d total enemies",
              #(spawn_events or {}), #updated_snaps))

    return enemy_entities, updated_snaps
end

--- Despawn an enemy
--- @param enemy_id number Enemy ID to despawn
function enemy_spawner_adapter.despawn_enemy(enemy_id)
    local enemy_info = spawned_enemies[enemy_id]
    if not enemy_info then
        log_warning("enemy_spawner_adapter: attempt to despawn unknown enemy_id " .. enemy_id)
        return
    end

    local entity_id = enemy_info.entity_id

    -- Unregister from contact collector
    local contact_collector = enemy_spawner_adapter._get_contact_collector()
    if contact_collector and contact_collector.unregister_enemy_entity then
        contact_collector.unregister_enemy_entity(enemy_id, entity_id)
    end

    -- Clean up entity
    despawn(entity_id)

    -- Clean up mappings
    enemy_id_to_entity_id[enemy_id] = nil
    entity_id_to_enemy_id[entity_id] = nil
    spawned_enemies[enemy_id] = nil

    log_debug(string.format("[EnemySpawnerAdapter] Despawned enemy_id=%d entity_id=%d",
              enemy_id, entity_id))
end

--- Update enemy position
--- @param enemy_id number Enemy ID
--- @param x number New X position
--- @param y number New Y position
function enemy_spawner_adapter.set_enemy_position(enemy_id, x, y)
    local entity_id = enemy_id_to_entity_id[enemy_id]
    if not entity_id then
        log_warning("enemy_spawner_adapter: attempt to position unknown enemy_id " .. enemy_id)
        return
    end

    physics.SetPosition(_G.physics, _G.registry, entity_id, x, y)
end

--- Build position snapshots for pure combat logic
--- @return table Array of EnemyPosSnapshot sorted by enemy_id
function enemy_spawner_adapter.build_pos_snapshots()
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

    -- Sort by enemy_id for deterministic order
    table.sort(snapshots, function(a, b)
        return a.enemy_id < b.enemy_id
    end)

    return snapshots
end

--- Get entity ID for an enemy
--- @param enemy_id number Enemy ID
--- @return number|nil Entity ID or nil if not found
function enemy_spawner_adapter.get_entity_id(enemy_id)
    return enemy_id_to_entity_id[enemy_id]
end

--- Get enemy ID for an entity
--- @param entity_id number Entity ID
--- @return number|nil Enemy ID or nil if not found
function enemy_spawner_adapter.get_enemy_id(entity_id)
    return entity_id_to_enemy_id[entity_id]
end

--- Get spawned enemy snapshot
--- @param enemy_id number Enemy ID
--- @return table|nil Enemy snapshot or nil if not found
function enemy_spawner_adapter.get_enemy_snapshot(enemy_id)
    local enemy_info = spawned_enemies[enemy_id]
    return enemy_info and enemy_info.snapshot
end

--- Clean up all spawned enemies
function enemy_spawner_adapter.cleanup()
    local to_despawn = {}
    for enemy_id, _ in pairs(spawned_enemies) do
        table.insert(to_despawn, enemy_id)
    end
    for _, enemy_id in ipairs(to_despawn) do
        enemy_spawner_adapter.despawn_enemy(enemy_id)
    end
end

--- Get or create contact collector (stub implementation)
--- @return table|nil Contact collector instance
function enemy_spawner_adapter._get_contact_collector()
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

return enemy_spawner_adapter