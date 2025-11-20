--[[
    Combat Loop Integration

    This module provides the integration layer between the combat loop framework
    and the existing game systems. It wires up:
    - Combat state machine
    - Wave manager
    - Enemy spawner
    - Loot system
    - Entity cleanup
    - Event bus
    - Existing combat system

    Usage:
        local CombatLoopIntegration = require("combat.combat_loop_integration")

        -- Initialize
        local combat_loop = CombatLoopIntegration.new(config)

        -- Start combat
        combat_loop:start()

        -- Update each frame
        combat_loop:update(dt)
]]

local CombatStateMachine = require("combat.combat_state_machine")
local WaveManager = require("combat.wave_manager")
local LootSystem = require("combat.loot_system")
local EntityCleanup = require("combat.entity_cleanup")

local CombatLoopIntegration = {}
CombatLoopIntegration.__index = CombatLoopIntegration

--[[
    Create a new combat loop integration instance

    @param config table {
        waves = { wave_config_1, wave_config_2, ... },
        player_entity = Player entity ID,
        combat_context = Existing combat context (optional),

        -- Entity factory function
        entity_factory_fn = function(enemy_type) -> entity_id,

        -- Loot configuration
        loot_tables = { enemy_type = loot_table, ... },
        loot_collection_mode = "auto_collect" | "click" | "magnet",

        -- Callbacks
        on_wave_start = function(wave_number),
        on_wave_complete = function(wave_number, stats),
        on_combat_end = function(victory, stats),
        on_all_waves_complete = function(total_stats)
    }
    @return CombatLoopIntegration instance
]]
function CombatLoopIntegration.new(config)
    local self = setmetatable({}, CombatLoopIntegration)

    -- Store config
    self.config = config
    self.player_entity = config.player_entity or survivorEntity
    self.combat_context = config.combat_context

    -- Create combat context if not provided
    if not self.combat_context then
        self.combat_context = self:create_default_combat_context()
    end

    -- Initialize loot system
    self.loot_system = LootSystem.new({
        combat_context = self.combat_context,
        player_entity = self.player_entity,
        loot_tables = config.loot_tables,
        default_collection_mode = config.loot_collection_mode or "auto_collect",
        on_loot_collected = function(player, loot_type, amount)
            self:on_loot_collected(player, loot_type, amount)
        end
    })

    -- Initialize wave manager
    self.wave_manager = WaveManager.new({
        waves = config.waves or {},
        combat_context = self.combat_context,
        entity_factory_fn = config.entity_factory_fn or create_ai_entity,
        on_wave_start = function(wave_number, wave_config)
            self:on_wave_start(wave_number, wave_config)
        end,
        on_wave_complete = function(wave_number, stats)
            self:on_wave_complete(wave_number, stats)
        end,
        on_all_waves_complete = function(total_stats)
            self:on_all_waves_complete(total_stats)
        end
    })

    -- Initialize combat state machine
    self.state_machine = CombatStateMachine.new({
        wave_manager = self.wave_manager,
        combat_context = self.combat_context,
        player_entity = self.player_entity,

        on_wave_start = function(wave_number)
            if config.on_wave_start then
                config.on_wave_start(wave_number)
            end
        end,

        on_victory = function(wave_stats)
            self:handle_victory(wave_stats)
        end,

        on_defeat = function()
            self:handle_defeat()
        end,

        on_intermission = function(next_wave)
            self:handle_intermission(next_wave)
        end,

        on_game_won = function(total_stats)
            self:handle_game_won(total_stats)
        end,

        on_game_over = function()
            self:handle_game_over()
        end,

        is_player_alive = function()
            return self:is_player_alive()
        end
    })

    -- Setup event listeners
    self:setup_event_listeners()

    -- State
    self.initialized = true

    log_debug("[CombatLoopIntegration] Initialized with", #(config.waves or {}), "waves")

    return self
end

--[[
    Create a default combat context with event bus
]]
function CombatLoopIntegration:create_default_combat_context()
    local EventBus = {
        listeners = {},

        on = function(self, event_name, callback)
            self.listeners[event_name] = self.listeners[event_name] or {}
            table.insert(self.listeners[event_name], callback)
        end,

        emit = function(self, event_name, event_data)
            local callbacks = self.listeners[event_name]
            if callbacks then
                for _, callback in ipairs(callbacks) do
                    callback(event_data)
                end
            end
        end
    }

    return {
        bus = EventBus
    }
end

--[[
    Setup event listeners for combat loop
]]
function CombatLoopIntegration:setup_event_listeners()
    local bus = self.combat_context.bus

    if not bus then
        log_warn("[CombatLoopIntegration] No event bus available")
        return
    end

    -- Listen for entity deaths
    bus:on("OnEntityDeath", function(event)
        self:handle_entity_death(event.entity, event.killer)
    end)

    -- Listen for damage events (for stats tracking)
    bus:on("OnHitResolved", function(event)
        if event.source == self.player_entity then
            self.wave_manager:track_damage_dealt(event.damage or 0)
        elseif event.target == self.player_entity then
            self.wave_manager:track_damage_taken(event.damage or 0)
        end
    end)

    log_debug("[CombatLoopIntegration] Event listeners setup complete")
end

--[[
    Start the combat loop
]]
function CombatLoopIntegration:start()
    log_debug("[CombatLoopIntegration] Starting combat loop")

    self.state_machine:start()
end

--[[
    Update the combat loop (call every frame)

    @param dt number - Delta time
]]
function CombatLoopIntegration:update(dt)
    self.state_machine:update(dt)
end

--[[
    Handle entity death
]]
function CombatLoopIntegration:handle_entity_death(entity_id, killer)
    log_debug("[CombatLoopIntegration] Entity death:", entity_id)

    -- Get position before cleanup
    local position = nil
    if registry and registry:valid(entity_id) then
        local transform = registry:get(entity_id, Transform)
        if transform then
            position = {
                x = transform.actualX + (transform.actualW or 0) * 0.5,
                y = transform.actualY + (transform.actualH or 0) * 0.5
            }
        end
    end

    -- Cleanup entity
    EntityCleanup.handle_death(entity_id, {
        killer = killer,
        emit_event = false,  -- Already emitted
        combat_context = self.combat_context,
        wave_manager = self.wave_manager,
        spawn_loot = true,
        loot_system = self.loot_system,
        death_effects = true
    })
end

--[[
    Check if player is alive
]]
function CombatLoopIntegration:is_player_alive()
    if not self.player_entity or not registry or not registry:valid(self.player_entity) then
        return false
    end

    -- Check via blackboard
    if getBlackboardFloat then
        local hp = getBlackboardFloat(self.player_entity, "health")
        if hp then
            return hp > 0
        end
    end

    -- Check via script component
    if getScriptTableFromEntityID then
        local player_data = getScriptTableFromEntityID(self.player_entity)
        if player_data and player_data.hp then
            return player_data.hp > 0
        end
    end

    -- Default: assume alive
    return true
end

--[[
    Wave start callback
]]
function CombatLoopIntegration:on_wave_start(wave_number, wave_config)
    log_debug("[CombatLoopIntegration] Wave", wave_number, "started")
end

--[[
    Wave complete callback
]]
function CombatLoopIntegration:on_wave_complete(wave_number, stats)
    log_debug("[CombatLoopIntegration] Wave", wave_number, "complete")

    if self.config.on_wave_complete then
        self.config.on_wave_complete(wave_number, stats)
    end
end

--[[
    All waves complete callback
]]
function CombatLoopIntegration:on_all_waves_complete(total_stats)
    log_debug("[CombatLoopIntegration] All waves complete!")

    if self.config.on_all_waves_complete then
        self.config.on_all_waves_complete(total_stats)
    end
end

--[[
    Loot collected callback
]]
function CombatLoopIntegration:on_loot_collected(player, loot_type, amount)
    log_debug("[CombatLoopIntegration] Loot collected:", loot_type, amount)
end

--[[
    Handle victory state
]]
function CombatLoopIntegration:handle_victory(wave_stats)
    log_debug("[CombatLoopIntegration] Victory!")
    log_debug("  Wave:", wave_stats.wave_number)
    log_debug("  Duration:", string.format("%.1f", wave_stats.duration), "seconds")
    log_debug("  Enemies killed:", wave_stats.enemies_killed)
    log_debug("  Rewards: XP", wave_stats.total_xp, "/ Gold", wave_stats.total_gold)

    -- Apply rewards to player
    self:apply_wave_rewards(wave_stats)
end

--[[
    Apply wave rewards to player
]]
function CombatLoopIntegration:apply_wave_rewards(wave_stats)
    -- Grant XP
    if wave_stats.total_xp > 0 then
        self.loot_system:apply_xp(wave_stats.total_xp)
    end

    -- Grant gold
    if wave_stats.total_gold > 0 then
        self.loot_system:apply_gold(wave_stats.total_gold)
    end
end

--[[
    Handle defeat state
]]
function CombatLoopIntegration:handle_defeat()
    log_debug("[CombatLoopIntegration] Defeat - Player died")

    if self.config.on_combat_end then
        self.config.on_combat_end(false, nil)
    end
end

--[[
    Handle intermission state
]]
function CombatLoopIntegration:handle_intermission(next_wave)
    log_debug("[CombatLoopIntegration] Intermission - Next wave:", next_wave)
end

--[[
    Handle game won state
]]
function CombatLoopIntegration:handle_game_won(total_stats)
    log_debug("[CombatLoopIntegration] Game Won!")
    log_debug("  Total waves completed:", total_stats.waves_completed)
    log_debug("  Total enemies killed:", total_stats.total_enemies_killed)
    log_debug("  Total XP earned:", total_stats.total_xp_earned)
    log_debug("  Total gold earned:", total_stats.total_gold_earned)

    if self.config.on_combat_end then
        self.config.on_combat_end(true, total_stats)
    end
end

--[[
    Handle game over state
]]
function CombatLoopIntegration:handle_game_over()
    log_debug("[CombatLoopIntegration] Game Over")
end

--[[
    Manually progress to next wave (from intermission)
]]
function CombatLoopIntegration:progress_to_next_wave()
    return self.state_machine:progress_to_next_wave()
end

--[[
    Pause the combat loop
]]
function CombatLoopIntegration:pause()
    self.state_machine:pause()
end

--[[
    Resume the combat loop
]]
function CombatLoopIntegration:resume()
    self.state_machine:resume()
end

--[[
    Stop the combat loop
]]
function CombatLoopIntegration:stop()
    self.state_machine:stop()
    self.loot_system:cleanup_all_loot()
end

--[[
    Reset the combat loop
]]
function CombatLoopIntegration:reset()
    self.state_machine:reset()
    self.loot_system:cleanup_all_loot()
end

--[[
    Get current state
]]
function CombatLoopIntegration:get_current_state()
    return self.state_machine:get_current_state()
end

--[[
    Get wave statistics
]]
function CombatLoopIntegration:get_wave_stats()
    return self.wave_manager:get_wave_stats()
end

--[[
    Get total statistics
]]
function CombatLoopIntegration:get_total_stats()
    return self.wave_manager:get_total_stats()
end

return CombatLoopIntegration
