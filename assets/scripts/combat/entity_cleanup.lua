--[[
    Entity Death & Cleanup System

    Handles entity death and proper cleanup to prevent memory leaks:
    - Remove physics bodies
    - Cancel timers
    - Remove UI elements
    - Clear references from global tables
    - Emit death events
    - Trigger death effects (animations, particles, sounds)

    Integrates with:
    - Event bus (OnEntityDeath)
    - Timer system (cancel timers by tag)
    - Physics system (Chipmunk2D)
    - UI system (health bars, nameplates)
    - Wave manager (enemy tracking)
]]

local timer = require("core.timer")

local EntityCleanup = {}

--[[
    Handle entity death and cleanup

    @param entity_id - Entity to cleanup
    @param config table {
        killer = entity that caused the death (optional),
        emit_event = boolean (default true),
        combat_context = combat context for event bus,
        wave_manager = wave manager to update tracking,
        spawn_loot = boolean (default true),
        loot_config = loot configuration table,
        death_effects = boolean (default true) - play death animation/particles
    }
]]
function EntityCleanup.handle_death(entity_id, config)
    config = config or {}

    if not entity_id or entity_id == entt_null then
        log_error("[EntityCleanup] Invalid entity ID for death")
        return
    end

    if not registry or not registry:valid(entity_id) then
        log_debug("[EntityCleanup] Entity already destroyed:", entity_id)
        return
    end

    log_debug("[EntityCleanup] Handling death for entity:", entity_id)

    -- Get entity data before cleanup
    local transform = registry:get(entity_id, Transform)
    local death_position = nil
    if transform then
        death_position = {
            x = transform.actualX + (transform.actualW or 0) * 0.5,
            y = transform.actualY + (transform.actualH or 0) * 0.5
        }
    end

    -- Emit death event BEFORE cleanup
    if config.emit_event ~= false then
        EntityCleanup.emit_death_event(entity_id, config.killer, config.combat_context)
    end

    -- Update wave manager tracking
    if config.wave_manager then
        config.wave_manager:on_enemy_death(entity_id, config.killer)
    end

    -- Death effects (animations, particles, sounds)
    if config.death_effects ~= false and death_position then
        EntityCleanup.play_death_effects(entity_id, death_position, config)
    end

    -- Spawn loot
    if config.spawn_loot ~= false and death_position then
        EntityCleanup.spawn_loot_drops(entity_id, death_position, config)
    end

    -- Cleanup components and references
    EntityCleanup.cleanup_entity(entity_id)

    -- Destroy entity after a brief delay to allow death effects to play
    timer.after(0.1, function()
        if registry and registry:valid(entity_id) then
            registry:destroy(entity_id)
            log_debug("[EntityCleanup] Entity destroyed:", entity_id)
        end
    end, "entity_cleanup_" .. entity_id)
end

--[[
    Emit entity death event

    @param entity_id
    @param killer - Optional killer entity
    @param combat_context - Combat context with event bus
]]
function EntityCleanup.emit_death_event(entity_id, killer, combat_context)
    if combat_context and combat_context.bus then
        combat_context.bus:emit("OnEntityDeath", {
            entity = entity_id,
            killer = killer
        })
    end

    log_debug("[EntityCleanup] Death event emitted for:", entity_id)
end

--[[
    Play death effects (particles, animations, sounds)

    @param entity_id
    @param position table {x, y}
    @param config
]]
function EntityCleanup.play_death_effects(entity_id, position, config)
    -- Death particles (if particle system available)
    if particle and particle.CreateParticle then
        EntityCleanup.spawn_death_particles(position)
    end

    -- Death sound
    if playSoundEffect then
        local death_sounds = config.death_sounds or { "enemy-death" }
        local sound = death_sounds[math.random(1, #death_sounds)]
        playSoundEffect("effects", sound)
    end

    -- Flash effect (if shader system available)
    if shader_pipeline and registry and registry:valid(entity_id) then
        local pipeline = registry:try_get(entity_id, shader_pipeline.ShaderPipelineComponent)
        if pipeline then
            pipeline:addPass("flash")
        end
    end

    log_debug("[EntityCleanup] Death effects played at", position.x, position.y)
end

--[[
    Spawn death particles

    @param position table {x, y}
]]
function EntityCleanup.spawn_death_particles(position)
    -- Small burst of particles
    local particle_count = 20
    local colors = {
        util.getColor and util.getColor("WHITE") or { r = 1, g = 1, b = 1, a = 1 },
        util.getColor and util.getColor("RED") or { r = 1, g = 0, b = 0, a = 1 }
    }

    for i = 1, particle_count do
        local angle = math.random() * math.pi * 2
        local speed = 50 + math.random() * 100
        local lifetime = 0.3 + math.random() * 0.5

        particle.CreateParticle(
            Vec2(position.x - 5, position.y - 5),
            Vec2(10, 10),
            {
                renderType = particle.ParticleRenderType.RECTANGLE_FILLED,
                velocity = Vec2(math.cos(angle) * speed, math.sin(angle) * speed),
                acceleration = 0,
                lifespan = lifetime,
                startColor = colors[math.random(1, #colors)],
                endColor = { r = 0, g = 0, b = 0, a = 0 },
                rotationSpeed = 360,
                space = "world",
                z = 5
            },
            nil
        )
    end
end

--[[
    Spawn loot drops for a dead entity

    @param entity_id
    @param position table {x, y}
    @param config
]]
function EntityCleanup.spawn_loot_drops(entity_id, position, config)
    -- Import loot system if available
    local loot_config = config.loot_config or {}

    -- Try to determine enemy type from entity
    local enemy_type = EntityCleanup.get_enemy_type(entity_id)

    -- Spawn loot based on enemy type
    if config.loot_system and config.loot_system.spawn_loot_for_enemy then
        config.loot_system.spawn_loot_for_enemy(enemy_type, position, config.combat_context)
    else
        -- Simple fallback loot
        EntityCleanup.spawn_simple_loot(position, loot_config)
    end
end

--[[
    Get enemy type from entity (try various methods)

    @param entity_id
    @return string - Enemy type or "unknown"
]]
function EntityCleanup.get_enemy_type(entity_id)
    -- Try to get from script component
    if getScriptTableFromEntityID then
        local script = getScriptTableFromEntityID(entity_id)
        if script and script.enemy_type then
            return script.enemy_type
        end
    end

    -- Try to get from blackboard
    if getBlackboardString then
        local enemy_type = getBlackboardString(entity_id, "enemy_type")
        if enemy_type and enemy_type ~= "" then
            return enemy_type
        end
    end

    return "unknown"
end

--[[
    Spawn simple loot (fallback when loot system not available)

    @param position table {x, y}
    @param loot_config table
]]
function EntityCleanup.spawn_simple_loot(position, loot_config)
    -- Default simple loot: spawn currency using existing system
    if spawnCurrency then
        local gold_amount = loot_config.gold_amount or math.random(1, 3)
        for i = 1, gold_amount do
            local offset_x = (math.random() - 0.5) * 60
            local offset_y = (math.random() - 0.5) * 60
            spawnCurrency(position.x + offset_x, position.y + offset_y, "whale_dust")
        end
    end

    log_debug("[EntityCleanup] Simple loot spawned at", position.x, position.y)
end

--[[
    Cleanup entity components and references

    @param entity_id
]]
function EntityCleanup.cleanup_entity(entity_id)
    log_debug("[EntityCleanup] Cleaning up entity:", entity_id)

    -- Cancel all timers associated with this entity
    EntityCleanup.cancel_entity_timers(entity_id)

    -- Remove physics bodies
    EntityCleanup.cleanup_physics(entity_id)

    -- Remove UI elements
    EntityCleanup.cleanup_ui(entity_id)

    -- Remove from global tracking lists
    EntityCleanup.remove_from_global_lists(entity_id)

    -- Clear AI references
    EntityCleanup.cleanup_ai(entity_id)
end

--[[
    Cancel all timers associated with an entity

    @param entity_id
]]
function EntityCleanup.cancel_entity_timers(entity_id)
    -- Common timer tag patterns used in the codebase
    local timer_patterns = {
        "colonist_hp_text_update_" .. entity_id,
        "colonist_ui_update_" .. entity_id,
        "entity_cleanup_" .. entity_id,
        tostring(entity_id) .. "_walk_timer",
        "entity_" .. entity_id,
    }

    for _, tag in ipairs(timer_patterns) do
        timer.cancel(tag)
    end

    log_debug("[EntityCleanup] Timers cancelled for entity:", entity_id)
end

--[[
    Cleanup physics bodies for an entity

    @param entity_id
]]
function EntityCleanup.cleanup_physics(entity_id)
    -- Remove physics body if exists
    if collision and collision.remove_collider then
        -- Try to remove collider (may not exist for all entities)
        pcall(collision.remove_collider, entity_id)
    end

    -- Alternative: if entity has physics component
    if physics and registry and registry:valid(entity_id) then
        local physics_comp = registry:try_get(entity_id, PhysicsBody)
        if physics_comp and physics.DestroyBody then
            pcall(physics.DestroyBody, world, entity_id)
        end
    end

    log_debug("[EntityCleanup] Physics cleaned for entity:", entity_id)
end

--[[
    Cleanup UI elements attached to entity

    @param entity_id
]]
function EntityCleanup.cleanup_ui(entity_id)
    -- Remove colonist UI (health bars, etc.)
    if globals and globals.ui and globals.ui.colonist_ui then
        local ui_data = globals.ui.colonist_ui[entity_id]

        if ui_data then
            -- Destroy UI box
            if ui_data.hp_ui_box and registry and registry:valid(ui_data.hp_ui_box) then
                registry:destroy(ui_data.hp_ui_box)
            end

            -- Destroy UI text
            if ui_data.hp_ui_text and registry and registry:valid(ui_data.hp_ui_text) then
                registry:destroy(ui_data.hp_ui_text)
            end

            -- Remove from global table
            globals.ui.colonist_ui[entity_id] = nil
        end
    end

    log_debug("[EntityCleanup] UI cleaned for entity:", entity_id)
end

--[[
    Remove entity from global tracking lists

    @param entity_id
]]
function EntityCleanup.remove_from_global_lists(entity_id)
    if not globals then return end

    -- Remove from various entity lists
    local lists_to_check = {
        {"entities", "krill"},
        {"entities", "whales"},
        {"colonists"},
        {"gold_diggers"},
        {"healers"},
        {"damage_cushions"}
    }

    for _, path in ipairs(lists_to_check) do
        local list = globals
        for _, key in ipairs(path) do
            list = list[key]
            if not list then break end
        end

        if list and type(list) == "table" then
            for i, eid in ipairs(list) do
                if eid == entity_id then
                    table.remove(list, i)
                    log_debug("[EntityCleanup] Removed from", table.concat(path, "."))
                    break
                end
            end
        end
    end

    -- Remove from structures
    if globals.structures then
        for structure_type, structure_list in pairs(globals.structures) do
            if type(structure_list) == "table" then
                for i, eid in ipairs(structure_list) do
                    if eid == entity_id then
                        table.remove(structure_list, i)
                        log_debug("[EntityCleanup] Removed from structures." .. structure_type)
                        break
                    end
                end
            end
        end
    end

    log_debug("[EntityCleanup] Removed from global lists for entity:", entity_id)
end

--[[
    Cleanup AI-related components

    @param entity_id
]]
function EntityCleanup.cleanup_ai(entity_id)
    -- Clear blackboard data
    if clearBlackboard then
        pcall(clearBlackboard, entity_id)
    end

    -- Remove from AI systems if needed
    -- (Most AI cleanup happens automatically when entity is destroyed)

    log_debug("[EntityCleanup] AI cleaned for entity:", entity_id)
end

--[[
    Batch cleanup multiple entities efficiently

    @param entity_ids table - List of entity IDs
    @param config table - Shared config for all entities
]]
function EntityCleanup.batch_cleanup(entity_ids, config)
    log_debug("[EntityCleanup] Batch cleanup for", #entity_ids, "entities")

    for _, entity_id in ipairs(entity_ids) do
        EntityCleanup.handle_death(entity_id, config)
    end
end

--[[
    Cleanup all enemies in a wave (emergency cleanup)

    @param wave_manager - Wave manager instance
]]
function EntityCleanup.cleanup_wave_enemies(wave_manager)
    if not wave_manager then return end

    local enemies = wave_manager:get_alive_enemies()

    log_debug("[EntityCleanup] Emergency cleanup of", #enemies, "wave enemies")

    for _, entity_id in ipairs(enemies) do
        EntityCleanup.cleanup_entity(entity_id)

        if registry and registry:valid(entity_id) then
            registry:destroy(entity_id)
        end
    end

    wave_manager.tracked_enemies = {}
    wave_manager.spawner.spawned_enemies = {}
end

return EntityCleanup
