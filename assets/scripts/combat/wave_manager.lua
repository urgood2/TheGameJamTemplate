--[[
    Wave Manager System

    Manages wave progression, difficulty scaling, and wave lifecycle:
    - Load wave configurations
    - Track wave progress
    - Calculate difficulty scaling
    - Manage wave transitions
    - Calculate rewards based on performance

    Integrates with:
    - Enemy spawner (spawn enemies)
    - Combat state machine (state transitions)
    - Event bus (wave events)
]]

local timer = require("core.timer")
local EnemySpawner = require("combat.enemy_spawner")

local WaveManager = {}
WaveManager.__index = WaveManager

--[[
    Create a new wave manager

    @param config table {
        waves = { wave_config_1, wave_config_2, ... },
        combat_context = Combat context (for event bus),
        entity_factory_fn = function(enemy_type) -> entity_id,
        on_wave_start = function(wave_number, wave_config),
        on_wave_complete = function(wave_number, stats),
        on_all_waves_complete = function(total_stats)
    }
    @return WaveManager instance
]]
function WaveManager.new(config)
    local self = setmetatable({}, WaveManager)

    -- Configuration
    self.waves = config.waves or {}
    self.combat_context = config.combat_context
    self.entity_factory_fn = config.entity_factory_fn

    -- Callbacks
    self.on_wave_start = config.on_wave_start
    self.on_wave_complete = config.on_wave_complete
    self.on_all_waves_complete = config.on_all_waves_complete

    -- State
    self.current_wave_number = 0
    self.current_wave_config = nil
    self.wave_in_progress = false
    self.all_waves_complete = false

    -- Tracking
    self.tracked_enemies = {}  -- All enemies for current wave
    self.wave_stats = self:create_wave_stats()

    -- Enemy spawner
    self.spawner = EnemySpawner.new({
        wave_manager = self,
        combat_context = self.combat_context,
        entity_factory_fn = self.entity_factory_fn,
        on_enemy_spawned = function(entity_id, enemy_type)
            self:on_enemy_spawned(entity_id, enemy_type)
        end
    })

    -- Global stats
    self.total_stats = {
        waves_completed = 0,
        total_enemies_killed = 0,
        total_damage_dealt = 0,
        total_damage_taken = 0,
        total_xp_earned = 0,
        total_gold_earned = 0,
        total_time = 0
    }

    return self
end

--[[
    Create a new wave stats tracking object
]]
function WaveManager:create_wave_stats()
    return {
        wave_number = 0,
        start_time = 0,
        end_time = 0,
        duration = 0,

        enemies_spawned = 0,
        enemies_killed = 0,
        damage_dealt = 0,
        damage_taken = 0,

        base_xp = 0,
        base_gold = 0,
        interest_gold = 0,
        speed_bonus = 0,
        total_xp = 0,
        total_gold = 0,

        perfect_clear = true  -- No damage taken
    }
end

--[[
    Start the wave sequence from wave 1
]]
function WaveManager:start_waves()
    if #self.waves == 0 then
        log_error("[WaveManager] No waves configured!")
        return false
    end

    self.current_wave_number = 0
    self.all_waves_complete = false
    self:start_next_wave()
    return true
end

--[[
    Start the next wave in sequence
]]
function WaveManager:start_next_wave()
    if self.wave_in_progress then
        log_warn("[WaveManager] Cannot start next wave - wave already in progress")
        return false
    end

    self.current_wave_number = self.current_wave_number + 1

    if self.current_wave_number > #self.waves then
        log_debug("[WaveManager] All waves complete!")
        self.all_waves_complete = true
        self:on_all_waves_finished()
        return false
    end

    local wave_config = self.waves[self.current_wave_number]
    wave_config.wave_number = self.current_wave_number

    self:start_wave(wave_config)
    return true
end

--[[
    Start a specific wave

    @param wave_config table - Wave configuration
]]
function WaveManager:start_wave(wave_config)
    log_debug("[WaveManager] Starting wave", wave_config.wave_number)

    self.current_wave_config = wave_config
    self.wave_in_progress = true

    -- Reset stats
    self.wave_stats = self:create_wave_stats()
    self.wave_stats.wave_number = wave_config.wave_number
    self.wave_stats.start_time = os.clock()

    -- Set base rewards
    local rewards = wave_config.rewards or {}
    self.wave_stats.base_xp = rewards.base_xp or 50
    self.wave_stats.base_gold = rewards.base_gold or 20

    -- Reset tracking
    self.tracked_enemies = {}

    -- Emit event
    if self.combat_context and self.combat_context.bus then
        self.combat_context.bus:emit("OnWaveStart", {
            wave_number = wave_config.wave_number,
            wave_config = wave_config
        })
    end

    -- Callback
    if self.on_wave_start then
        self.on_wave_start(wave_config.wave_number, wave_config)
    end

    -- Start spawning enemies
    self.spawner:start_spawning(wave_config)

    log_debug("[WaveManager] Wave", wave_config.wave_number, "started")
end

--[[
    Update the wave manager (call every frame during combat)

    @param dt number - Delta time
]]
function WaveManager:update(dt)
    if not self.wave_in_progress then
        return
    end

    -- Check wave completion
    if self:is_wave_complete() then
        self:complete_wave()
    end
end

--[[
    Check if current wave is complete (all enemies dead)

    @return boolean
]]
function WaveManager:is_wave_complete()
    if not self.wave_in_progress then
        return false
    end

    -- Wait for spawning to finish
    if not self.spawner.spawn_complete then
        return false
    end

    -- Check if all enemies are dead
    local alive_enemies = self:get_alive_enemies()
    return #alive_enemies == 0
end

--[[
    Complete the current wave
]]
function WaveManager:complete_wave()
    if not self.wave_in_progress then
        return
    end

    log_debug("[WaveManager] Wave", self.current_wave_number, "complete!")

    self.wave_in_progress = false
    self.wave_stats.end_time = os.clock()
    self.wave_stats.duration = self.wave_stats.end_time - self.wave_stats.start_time

    -- Calculate rewards
    self:calculate_rewards()

    -- Update global stats
    self.total_stats.waves_completed = self.total_stats.waves_completed + 1
    self.total_stats.total_enemies_killed = self.total_stats.total_enemies_killed + self.wave_stats.enemies_killed
    self.total_stats.total_damage_dealt = self.total_stats.total_damage_dealt + self.wave_stats.damage_dealt
    self.total_stats.total_damage_taken = self.total_stats.total_damage_taken + self.wave_stats.damage_taken
    self.total_stats.total_xp_earned = self.total_stats.total_xp_earned + self.wave_stats.total_xp
    self.total_stats.total_gold_earned = self.total_stats.total_gold_earned + self.wave_stats.total_gold
    self.total_stats.total_time = self.total_stats.total_time + self.wave_stats.duration

    -- Emit event
    if self.combat_context and self.combat_context.bus then
        self.combat_context.bus:emit("OnWaveComplete", {
            wave_number = self.current_wave_number,
            stats = self.wave_stats
        })
    end

    -- Callback
    if self.on_wave_complete then
        self.on_wave_complete(self.current_wave_number, self.wave_stats)
    end

    -- Log stats
    self:log_wave_stats()
end

--[[
    Calculate wave rewards based on performance
]]
function WaveManager:calculate_rewards()
    local stats = self.wave_stats
    local rewards = self.current_wave_config.rewards or {}

    -- Base rewards
    stats.base_xp = rewards.base_xp or 50
    stats.base_gold = rewards.base_gold or 20

    -- Interest: bonus gold for time survived
    local interest_rate = rewards.interest_per_second or 0
    if interest_rate > 0 and stats.duration > 0 then
        stats.interest_gold = math.floor(stats.duration * interest_rate)
    end

    -- Speed bonus: bonus for clearing quickly
    local target_time = rewards.target_time or 60
    if stats.duration < target_time then
        local speed_multiplier = rewards.speed_multiplier or 1
        stats.speed_bonus = math.floor((target_time - stats.duration) * speed_multiplier)
    end

    -- Perfect clear bonus
    if stats.perfect_clear and stats.damage_taken == 0 then
        stats.speed_bonus = stats.speed_bonus + (rewards.perfect_bonus or 20)
    end

    -- Total rewards
    stats.total_xp = stats.base_xp
    stats.total_gold = stats.base_gold + stats.interest_gold + stats.speed_bonus
end

--[[
    Log wave statistics
]]
function WaveManager:log_wave_stats()
    local s = self.wave_stats
    log_debug("===== Wave", s.wave_number, "Stats =====")
    log_debug("  Duration:", string.format("%.1f", s.duration), "seconds")
    log_debug("  Enemies: spawned", s.enemies_spawned, "/ killed", s.enemies_killed)
    log_debug("  Damage: dealt", s.damage_dealt, "/ taken", s.damage_taken)
    log_debug("  Rewards:")
    log_debug("    Base XP:", s.base_xp, "/ Gold:", s.base_gold)
    log_debug("    Interest:", s.interest_gold)
    log_debug("    Speed bonus:", s.speed_bonus)
    log_debug("    Total XP:", s.total_xp, "/ Gold:", s.total_gold)
    log_debug("  Perfect clear:", s.perfect_clear)
    log_debug("========================")
end

--[[
    Called when an enemy is spawned

    @param entity_id - Enemy entity ID
    @param enemy_type string - Enemy type
]]
function WaveManager:on_enemy_spawned(entity_id, enemy_type)
    table.insert(self.tracked_enemies, entity_id)
    self.wave_stats.enemies_spawned = self.wave_stats.enemies_spawned + 1

    log_debug("[WaveManager] Enemy spawned:", enemy_type, "- Total:", self.wave_stats.enemies_spawned)
end

--[[
    Called when an enemy dies

    @param entity_id - Enemy entity ID
    @param killer - Entity that killed the enemy (optional)
]]
function WaveManager:on_enemy_death(entity_id, killer)
    -- Remove from tracked list
    self.spawner:remove_enemy(entity_id)

    for i, eid in ipairs(self.tracked_enemies) do
        if eid == entity_id then
            table.remove(self.tracked_enemies, i)
            break
        end
    end

    self.wave_stats.enemies_killed = self.wave_stats.enemies_killed + 1

    log_debug("[WaveManager] Enemy killed - Remaining:", #self.tracked_enemies)

    -- Emit event
    if self.combat_context and self.combat_context.bus then
        self.combat_context.bus:emit("OnEnemyDeath", {
            entity = entity_id,
            killer = killer,
            wave_number = self.current_wave_number
        })
    end
end

--[[
    Track damage dealt (for stats)

    @param amount number
]]
function WaveManager:track_damage_dealt(amount)
    self.wave_stats.damage_dealt = self.wave_stats.damage_dealt + amount
end

--[[
    Track damage taken (for stats and perfect clear)

    @param amount number
]]
function WaveManager:track_damage_taken(amount)
    self.wave_stats.damage_taken = self.wave_stats.damage_taken + amount
    if amount > 0 then
        self.wave_stats.perfect_clear = false
    end
end

--[[
    Get list of currently alive tracked enemies

    @return table - List of entity IDs
]]
function WaveManager:get_alive_enemies()
    local alive = {}

    for _, entity_id in ipairs(self.tracked_enemies) do
        if registry and registry:valid(entity_id) and entity_id ~= entt_null then
            alive[#alive + 1] = entity_id
        end
    end

    return alive
end

--[[
    Get current wave number

    @return number
]]
function WaveManager:get_current_wave_number()
    return self.current_wave_number
end

--[[
    Get total number of waves

    @return number
]]
function WaveManager:get_total_waves()
    return #self.waves
end

--[[
    Check if there are more waves

    @return boolean
]]
function WaveManager:has_more_waves()
    return self.current_wave_number < #self.waves
end

--[[
    Called when all waves are finished
]]
function WaveManager:on_all_waves_finished()
    log_debug("[WaveManager] All waves complete!")
    log_debug("===== Total Stats =====")
    log_debug("  Waves completed:", self.total_stats.waves_completed)
    log_debug("  Total enemies killed:", self.total_stats.total_enemies_killed)
    log_debug("  Total damage dealt:", self.total_stats.total_damage_dealt)
    log_debug("  Total damage taken:", self.total_stats.total_damage_taken)
    log_debug("  Total XP earned:", self.total_stats.total_xp_earned)
    log_debug("  Total gold earned:", self.total_stats.total_gold_earned)
    log_debug("  Total time:", string.format("%.1f", self.total_stats.total_time), "seconds")
    log_debug("=======================")

    if self.on_all_waves_complete then
        self.on_all_waves_complete(self.total_stats)
    end

    if self.combat_context and self.combat_context.bus then
        self.combat_context.bus:emit("OnAllWavesComplete", {
            total_stats = self.total_stats
        })
    end
end

--[[
    Stop the current wave and reset
]]
function WaveManager:stop_wave()
    if not self.wave_in_progress then
        return
    end

    log_debug("[WaveManager] Stopping wave", self.current_wave_number)

    self.spawner:stop_spawning()
    self.wave_in_progress = false
end

--[[
    Reset the wave manager completely
]]
function WaveManager:reset()
    self:stop_wave()

    self.current_wave_number = 0
    self.current_wave_config = nil
    self.all_waves_complete = false
    self.tracked_enemies = {}
    self.wave_stats = self:create_wave_stats()

    self.total_stats = {
        waves_completed = 0,
        total_enemies_killed = 0,
        total_damage_dealt = 0,
        total_damage_taken = 0,
        total_xp_earned = 0,
        total_gold_earned = 0,
        total_time = 0
    }

    self.spawner:reset()

    log_debug("[WaveManager] Reset complete")
end

--[[
    Get current wave statistics

    @return table - Wave stats
]]
function WaveManager:get_wave_stats()
    return self.wave_stats
end

--[[
    Get total statistics across all waves

    @return table - Total stats
]]
function WaveManager:get_total_stats()
    return self.total_stats
end

return WaveManager
