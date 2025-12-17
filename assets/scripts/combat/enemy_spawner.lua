--[[
    Enemy Spawner System

    Handles enemy spawning with configurable patterns:
    - Instant spawning (all at once)
    - Timed spawning (scheduled over time)
    - Budget-based spawning (point allocation)
    - Continuous/survival spawning

    Integrates with:
    - Entity factory (create_ai_entity)
    - Timer system (scheduled spawns)
    - Event bus (spawn notifications)
    - Combat system (enemy tracking)
]]

local timer = require("core.timer")
local random_utils = require("util.util")
local component_cache = require("core.component_cache")

local EnemySpawner = {}
EnemySpawner.__index = EnemySpawner

-- Spawn point type constants
EnemySpawner.SpawnPointTypes = {
    RANDOM_AREA = "random_area",
    FIXED_POINTS = "fixed_points",
    OFF_SCREEN = "off_screen",
    AROUND_PLAYER = "around_player",
    CIRCLE = "circle"
}

-- Spawn pattern type constants
EnemySpawner.SpawnPatternTypes = {
    INSTANT = "instant",
    TIMED = "timed",
    BUDGET = "budget",
    SURVIVAL = "survival"
}

--[[
    Create a new enemy spawner instance

    @param config table {
        wave_manager = WaveManager instance (optional, for callbacks)
        combat_context = Combat context (optional, for event bus)
        entity_factory_fn = function(enemy_type) -> entity_id (required)
        on_enemy_spawned = function(entity_id, enemy_type) (optional callback)
    }
    @return EnemySpawner instance
]]
function EnemySpawner.new(config)
    local self = setmetatable({}, EnemySpawner)

    self.wave_manager = config.wave_manager
    self.combat_context = config.combat_context
    self.entity_factory_fn = config.entity_factory_fn or create_ai_entity
    self.on_enemy_spawned = config.on_enemy_spawned

    -- Tracking
    self.spawned_enemies = {}  -- List of all spawned enemy entity IDs
    self.spawn_count = 0       -- Total enemies spawned this wave
    self.active_spawns = {}    -- Scheduled spawns in progress

    -- State
    self.is_spawning = false
    self.spawn_complete = false
    self.current_wave_config = nil

    return self
end

--[[
    Start spawning enemies for a wave

    @param wave_config table {
        type = "instant" | "timed" | "budget" | "survival",
        enemies = { {type="goblin", count=5, cost=1}, ... },
        spawn_schedule = { {delay=0, enemy="goblin", count=3}, ... },
        budget = number (for budget mode),
        survival_duration = number (for survival mode),
        spawn_interval = number (for survival mode),
        spawn_config = { type="random_area", area={x,y,w,h}, ... },
        difficulty_scale = number (multiplier for enemy stats)
    }
]]
function EnemySpawner:start_spawning(wave_config)
    self.current_wave_config = wave_config
    self.is_spawning = true
    self.spawn_complete = false
    self.spawn_count = 0
    self.spawned_enemies = {}

    local pattern_type = wave_config.type or "instant"

    if pattern_type == self.SpawnPatternTypes.INSTANT then
        self:spawn_instant_wave(wave_config)
    elseif pattern_type == self.SpawnPatternTypes.TIMED then
        self:spawn_timed_wave(wave_config)
    elseif pattern_type == self.SpawnPatternTypes.BUDGET then
        self:spawn_budget_wave(wave_config)
    elseif pattern_type == self.SpawnPatternTypes.SURVIVAL then
        self:spawn_survival_wave(wave_config)
    else
        log_error("Unknown spawn pattern type:", pattern_type)
        self.spawn_complete = true
        self.is_spawning = false
    end
end

--[[
    Spawn all enemies immediately (instant wave)
]]
function EnemySpawner:spawn_instant_wave(wave_config)
    log_debug("[EnemySpawner] Starting instant wave spawn")

    local enemies = wave_config.enemies or {}

    for _, enemy_def in ipairs(enemies) do
        local enemy_type = enemy_def.type
        local count = enemy_def.count or 1

        for i = 1, count do
            self:spawn_enemy(enemy_type, wave_config)
        end
    end

    self.spawn_complete = true
    self.is_spawning = false

    log_debug("[EnemySpawner] Instant wave spawn complete. Total enemies:", self.spawn_count)
end

--[[
    Spawn enemies on a schedule (timed wave)
]]
function EnemySpawner:spawn_timed_wave(wave_config)
    log_debug("[EnemySpawner] Starting timed wave spawn")

    local spawn_schedule = wave_config.spawn_schedule or {}
    local wave_number = wave_config.wave_number or 1

    local total_scheduled = 0
    for _, entry in ipairs(spawn_schedule) do
        total_scheduled = total_scheduled + (entry.count or 1)
    end

    log_debug("[EnemySpawner] Scheduled", #spawn_schedule, "spawn events for", total_scheduled, "enemies")

    for schedule_index, entry in ipairs(spawn_schedule) do
        local delay = entry.delay or 0
        local enemy_type = entry.enemy
        local count = entry.count or 1

        local timer_tag = string.format("wave_%d_spawn_%d", wave_number, schedule_index)

        timer.after(delay, function()
            for i = 1, count do
                self:spawn_enemy(enemy_type, wave_config)
            end

            -- Check if this was the last scheduled spawn
            self.active_spawns[timer_tag] = nil
            if self:are_all_spawns_complete() then
                self.spawn_complete = true
                self.is_spawning = false
                log_debug("[EnemySpawner] All timed spawns complete")
            end
        end, timer_tag)

        self.active_spawns[timer_tag] = true
    end
end

--[[
    Spawn enemies based on budget allocation
]]
function EnemySpawner:spawn_budget_wave(wave_config)
    log_debug("[EnemySpawner] Starting budget wave spawn")

    local budget = wave_config.budget or 10
    local enemies = wave_config.enemies or {}

    -- Build weighted list based on costs
    local available_enemies = {}
    for _, enemy_def in ipairs(enemies) do
        if enemy_def.cost and enemy_def.cost <= budget then
            table.insert(available_enemies, {
                type = enemy_def.type,
                cost = enemy_def.cost,
                weight = enemy_def.weight or 1
            })
        end
    end

    if #available_enemies == 0 then
        log_error("[EnemySpawner] No affordable enemies for budget:", budget)
        self.spawn_complete = true
        self.is_spawning = false
        return
    end

    -- Spend budget
    local remaining_budget = budget
    while remaining_budget > 0 do
        -- Find enemies we can afford
        local affordable = {}
        for _, enemy in ipairs(available_enemies) do
            if enemy.cost <= remaining_budget then
                table.insert(affordable, {
                    item = enemy,
                    w = enemy.weight
                })
            end
        end

        if #affordable == 0 then
            log_debug("[EnemySpawner] Cannot afford any more enemies. Remaining budget:", remaining_budget)
            break
        end

        -- Pick weighted random enemy
        local chosen = random_utils.weighted_choice(affordable)
        if chosen then
            self:spawn_enemy(chosen.type, wave_config)
            remaining_budget = remaining_budget - chosen.cost
        else
            break
        end
    end

    self.spawn_complete = true
    self.is_spawning = false

    log_debug("[EnemySpawner] Budget wave complete. Spent:", budget - remaining_budget, "/", budget)
end

--[[
    Spawn enemies continuously over time (survival mode)
]]
function EnemySpawner:spawn_survival_wave(wave_config)
    log_debug("[EnemySpawner] Starting survival wave spawn")

    local duration = wave_config.survival_duration or 60
    local spawn_interval = wave_config.spawn_interval or 3
    local enemies = wave_config.enemies or {}
    local wave_number = wave_config.wave_number or 1

    if #enemies == 0 then
        log_error("[EnemySpawner] No enemies defined for survival wave")
        self.spawn_complete = true
        self.is_spawning = false
        return
    end

    local elapsed = 0
    local timer_tag = "survival_wave_" .. wave_number

    -- Periodic spawn timer
    timer.every(spawn_interval, function()
        elapsed = elapsed + spawn_interval

        if elapsed >= duration then
            -- Survival duration reached
            timer.cancel(timer_tag)
            self.spawn_complete = true
            self.is_spawning = false
            log_debug("[EnemySpawner] Survival wave complete")
            return
        end

        -- Pick random enemy type
        local enemy_def = enemies[math.random(1, #enemies)]
        local count = enemy_def.count or 1

        for i = 1, count do
            self:spawn_enemy(enemy_def.type, wave_config)
        end
    end, 0, true, nil, timer_tag)

    self.active_spawns[timer_tag] = true
end

--[[
    Spawn a single enemy

    @param enemy_type string - Enemy type identifier
    @param wave_config table - Current wave configuration
    @return entity_id or nil
]]
function EnemySpawner:spawn_enemy(enemy_type, wave_config)
    -- Get spawn position
    local spawn_pos = self:get_spawn_position(wave_config.spawn_config or {})

    if not spawn_pos then
        log_error("[EnemySpawner] Failed to get spawn position for enemy:", enemy_type)
        return nil
    end

    -- Create entity using factory function
    local entity_id = self.entity_factory_fn(enemy_type)

    if not entity_id or entity_id == entt_null then
        log_error("[EnemySpawner] Failed to create entity for enemy type:", enemy_type)
        return nil
    end

    -- Set position
    if registry and registry:valid(entity_id) then
        local transform = component_cache.get(entity_id, Transform)
        if transform then
            transform.actualX = spawn_pos.x
            transform.actualY = spawn_pos.y
        end
    end

    -- Apply difficulty scaling
    if wave_config.difficulty_scale and wave_config.difficulty_scale ~= 1.0 then
        self:apply_difficulty_scaling(entity_id, wave_config.difficulty_scale)
    end

    -- Track spawned enemy
    table.insert(self.spawned_enemies, entity_id)
    self.spawn_count = self.spawn_count + 1

    -- Callbacks
    if self.on_enemy_spawned then
        self.on_enemy_spawned(entity_id, enemy_type)
    end

    -- Event bus
    if self.combat_context and self.combat_context.bus then
        self.combat_context.bus:emit("OnEnemySpawned", {
            entity = entity_id,
            enemy_type = enemy_type,
            wave_number = wave_config.wave_number,
            spawn_position = spawn_pos
        })
    end

    log_debug("[EnemySpawner] Spawned", enemy_type, "at", spawn_pos.x, spawn_pos.y, "- Total spawned:", self.spawn_count)

    return entity_id
end

--[[
    Get spawn position based on spawn configuration

    @param spawn_config table
    @return {x, y} or nil
]]
function EnemySpawner:get_spawn_position(spawn_config)
    local spawn_type = spawn_config.type or self.SpawnPointTypes.RANDOM_AREA

    if spawn_type == self.SpawnPointTypes.RANDOM_AREA then
        return self:get_random_area_position(spawn_config)

    elseif spawn_type == self.SpawnPointTypes.FIXED_POINTS then
        return self:get_fixed_point_position(spawn_config)

    elseif spawn_type == self.SpawnPointTypes.OFF_SCREEN then
        return self:get_off_screen_position(spawn_config)

    elseif spawn_type == self.SpawnPointTypes.AROUND_PLAYER then
        return self:get_around_player_position(spawn_config)

    elseif spawn_type == self.SpawnPointTypes.CIRCLE then
        return self:get_circle_position(spawn_config)
    else
        log_error("[EnemySpawner] Unknown spawn point type:", spawn_type)
        return nil
    end
end

-- Random position within defined area
function EnemySpawner:get_random_area_position(config)
    local area = config.area or { x = 100, y = 100, w = 600, h = 400 }

    return {
        x = area.x + math.random() * area.w,
        y = area.y + math.random() * area.h
    }
end

-- Random selection from fixed points
function EnemySpawner:get_fixed_point_position(config)
    local points = config.points or {{x = 400, y = 300}}

    if #points == 0 then
        log_error("[EnemySpawner] No fixed points defined")
        return {x = 400, y = 300}
    end

    return points[math.random(1, #points)]
end

-- Position just outside screen bounds
function EnemySpawner:get_off_screen_position(config)
    local margin = config.margin or 50
    local screen_w = globals.screenWidth and globals.screenWidth() or 1600
    local screen_h = globals.screenHeight and globals.screenHeight() or 1200

    -- Pick a random side: 0=top, 1=right, 2=bottom, 3=left
    local side = math.random(0, 3)

    if side == 0 then  -- Top
        return { x = math.random(0, screen_w), y = -margin }
    elseif side == 1 then  -- Right
        return { x = screen_w + margin, y = math.random(0, screen_h) }
    elseif side == 2 then  -- Bottom
        return { x = math.random(0, screen_w), y = screen_h + margin }
    else  -- Left
        return { x = -margin, y = math.random(0, screen_h) }
    end
end

-- Random position around player at specified radius
function EnemySpawner:get_around_player_position(config)
    local player = config.player or survivorEntity
    local radius = config.radius or 300
    local min_radius = config.min_radius or radius * 0.8

    if not player or not registry or not registry:valid(player) then
        log_error("[EnemySpawner] No valid player for around_player spawn")
        return {x = 400, y = 300}
    end

    local transform = component_cache.get(player, Transform)
    if not transform then
        return {x = 400, y = 300}
    end

    local player_x = transform.actualX + (transform.actualW or 0) * 0.5
    local player_y = transform.actualY + (transform.actualH or 0) * 0.5

    -- Random angle
    local angle = math.random() * 2 * math.pi
    local dist = min_radius + math.random() * (radius - min_radius)

    return {
        x = player_x + math.cos(angle) * dist,
        y = player_y + math.sin(angle) * dist
    }
end

-- Position on a circle
function EnemySpawner:get_circle_position(config)
    local center = config.center or {x = 400, y = 300}
    local radius = config.radius or 200
    local angle_offset = config.angle_offset or 0

    -- Evenly distribute enemies around circle if using circle mode
    local index = self.spawn_count or 0
    local total = config.total_enemies or 8
    local angle = angle_offset + (index / total) * 2 * math.pi

    return {
        x = center.x + math.cos(angle) * radius,
        y = center.y + math.sin(angle) * radius
    }
end

--[[
    Apply difficulty scaling to an enemy's stats

    @param entity_id - Enemy entity ID
    @param scale - Difficulty multiplier
]]
function EnemySpawner:apply_difficulty_scaling(entity_id, scale)
    if not registry or not registry:valid(entity_id) then
        return
    end

    -- Try to scale health via blackboard
    if getBlackboardFloat then
        local current_hp = getBlackboardFloat(entity_id, "health")
        local max_hp = getBlackboardFloat(entity_id, "max_health")

        if max_hp and max_hp > 0 then
            local new_max = math.floor(max_hp * scale)
            setBlackboardFloat(entity_id, "max_health", new_max)
            setBlackboardFloat(entity_id, "health", new_max)

            log_debug("[EnemySpawner] Scaled enemy", entity_id, "HP:", max_hp, "->", new_max)
        end
    end

    -- Try to scale combat stats if available
    local script = getScriptTableFromEntityID and getScriptTableFromEntityID(entity_id)
    if script and script.stats then
        local stats = script.stats
        if stats.get and stats.add_base then
            local base_hp = stats:get("health")
            if base_hp > 0 then
                stats:add_base("health", base_hp * (scale - 1))
                stats:recompute()
            end
        end
    end
end

--[[
    Check if all scheduled spawns are complete
]]
function EnemySpawner:are_all_spawns_complete()
    for tag, active in pairs(self.active_spawns) do
        if active then
            return false
        end
    end
    return true
end

--[[
    Stop spawning and cancel all timers
]]
function EnemySpawner:stop_spawning()
    self.is_spawning = false

    -- Cancel all active spawn timers
    for tag, _ in pairs(self.active_spawns) do
        timer.cancel(tag)
    end

    self.active_spawns = {}
    log_debug("[EnemySpawner] Spawning stopped")
end

--[[
    Reset the spawner for a new wave
]]
function EnemySpawner:reset()
    self:stop_spawning()
    self.spawned_enemies = {}
    self.spawn_count = 0
    self.spawn_complete = false
    self.current_wave_config = nil
end

--[[
    Get list of currently alive spawned enemies
]]
function EnemySpawner:get_alive_enemies()
    local alive = {}

    for _, entity_id in ipairs(self.spawned_enemies) do
        if registry and registry:valid(entity_id) and entity_id ~= entt_null then
            alive[#alive + 1] = entity_id
        end
    end

    return alive
end

--[[
    Remove an enemy from tracking (called on death)
]]
function EnemySpawner:remove_enemy(entity_id)
    for i, eid in ipairs(self.spawned_enemies) do
        if eid == entity_id then
            table.remove(self.spawned_enemies, i)
            return true
        end
    end
    return false
end

return EnemySpawner
