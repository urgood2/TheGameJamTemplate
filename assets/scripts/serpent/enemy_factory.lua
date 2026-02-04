-- assets/scripts/serpent/enemy_factory.lua
--[[
    Enemy Factory Module

    Creates enemy snapshots with scaled stats based on wave progression.
    Handles HP/damage scaling and tag preservation for boss detection.
]]

local enemy_factory = {}

--- Create an enemy snapshot with scaled stats
--- @param enemy_def table Enemy definition from enemies.lua data
--- @param enemy_id number Unique enemy instance ID
--- @param wave_num number Current wave number (1-20)
--- @param wave_config table Wave configuration settings
--- @param x number Spawn X position
--- @param y number Spawn Y position
--- @return table EnemySnapshot with scaled stats and metadata
function enemy_factory.create_snapshot(enemy_def, enemy_id, wave_num, wave_config, x, y)
    if not enemy_def then
        error("enemy_factory.create_snapshot: enemy_def is required")
    end
    if not enemy_id then
        error("enemy_factory.create_snapshot: enemy_id is required")
    end

    -- Apply wave scaling to base stats
    local scaled_hp = enemy_factory.scale_hp(enemy_def.base_hp, wave_num)
    local scaled_damage = enemy_factory.scale_damage(enemy_def.base_damage, wave_num)

    -- Create enemy snapshot
    local snapshot = {
        -- Identity
        enemy_id = enemy_id,
        def_id = enemy_def.id,
        type = enemy_def.type,

        -- Scaled stats
        hp = scaled_hp,
        max_hp = scaled_hp,
        damage = scaled_damage,

        -- Base properties (unscaled)
        speed = enemy_def.speed,

        -- Position
        x = x or 0,
        y = y or 0,

        -- Metadata
        wave_num = wave_num,
        tags = enemy_def.tags and {table.unpack(enemy_def.tags)} or {},

        -- Status
        is_alive = true,
        spawn_time = os.clock(),
    }

    return snapshot
end

--- Calculate HP multiplier based on wave number
--- @param wave number Wave number (1-20)
--- @return number HP multiplier value
function enemy_factory.hp_mult(wave)
    if not wave then
        return 1.0
    end

    -- HP multiplier formula: 1 + wave * 0.1
    return 1 + wave * 0.1
end

--- Apply HP scaling formula based on wave number
--- @param base_hp number Base HP from enemy definition
--- @param wave_num number Current wave number (1-20)
--- @return number Scaled HP value (floored)
function enemy_factory.scale_hp(base_hp, wave_num)
    if not base_hp or not wave_num then
        return base_hp or 100
    end

    -- Use wave_config HP multiplier: 1 + wave * 0.1
    local hp_mult = enemy_factory.hp_mult(wave_num)
    local scaled_hp = base_hp * hp_mult + 0.00001

    return math.floor(scaled_hp)
end

--- Apply damage scaling formula based on wave number
--- @param base_damage number Base damage from enemy definition
--- @param wave_num number Current wave number (1-20)
--- @return number Scaled damage value (floored)
function enemy_factory.scale_damage(base_damage, wave_num)
    if not base_damage or not wave_num then
        return base_damage or 10
    end

    -- Use wave_config damage multiplier: 1 + wave * 0.05
    local dmg_mult = enemy_factory.dmg_mult(wave_num)
    local scaled_damage = base_damage * dmg_mult + 0.00001

    return math.floor(scaled_damage)
end

--- Calculate damage multiplier based on wave number
--- Formula: Enemy_Damage_Multiplier = 1 + Wave * 0.05
--- @param wave number Wave number (1-20)
--- @return number Damage multiplier
function enemy_factory.dmg_mult(wave)
    if not wave or wave < 1 then
        wave = 1
    end
    return 1 + wave * 0.05
end

--- Check if enemy is a boss based on tags
--- @param enemy_snapshot table Enemy snapshot to check
--- @return boolean True if enemy is a boss
function enemy_factory.is_boss(enemy_snapshot)
    if not enemy_snapshot or not enemy_snapshot.tags then
        return false
    end

    for _, tag in ipairs(enemy_snapshot.tags) do
        if tag == "boss" then
            return true
        end
    end

    return false
end

--- Get enemy display name
--- @param enemy_snapshot table Enemy snapshot
--- @return string Display name for the enemy
function enemy_factory.get_display_name(enemy_snapshot)
    if not enemy_snapshot then
        return "Unknown Enemy"
    end

    return enemy_snapshot.type or "Enemy"
end

return enemy_factory