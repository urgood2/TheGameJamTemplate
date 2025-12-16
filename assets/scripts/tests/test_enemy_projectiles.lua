--[[
================================================================================
ENEMY PROJECTILE INTEGRATION TESTS
================================================================================
Tests for the enemy projectile system, including:
- Enemy projectile presets (data/projectiles.lua)
- Enemy aiming utilities (combat/enemy_aiming.lua)
- Enemy shooter mixin (combat/enemy_shooter.lua)
- Defensive jokers (data/jokers.lua)

Run via: dofile("assets/scripts/tests/test_enemy_projectiles.lua")
Then call: Tests.run_all()
================================================================================
]]

local Tests = {}

-- Load dependencies
local Projectiles = require("data.projectiles")
local EnemyAiming = require("combat.enemy_aiming")
local Jokers = require("data.jokers")

-- Helper: check if table has all required fields
local function has_fields(tbl, fields)
    for _, field in ipairs(fields) do
        if tbl[field] == nil then
            return false, field
        end
    end
    return true
end

-- Helper: check if value is approximately equal (for floating point)
local function approx_equal(a, b, epsilon)
    epsilon = epsilon or 0.001
    return math.abs(a - b) < epsilon
end

-- Helper: vector magnitude
local function vec_length(vec)
    return math.sqrt(vec.x * vec.x + vec.y * vec.y)
end

--============================================================================
-- PROJECTILE PRESET TESTS
--============================================================================

local function test_enemy_projectile_presets_exist()
    local presets = {
        "enemy_basic_shot",
        "enemy_fireball",
        "enemy_ice_shard",
        "enemy_homing_orb",
        "enemy_spread_shot"
    }

    for _, id in ipairs(presets) do
        if not Projectiles[id] then
            return false, "test_enemy_projectile_presets_exist (missing: " .. id .. ")"
        end
    end

    return true, "test_enemy_projectile_presets_exist"
end

local function test_enemy_projectile_flags()
    local presets = {
        "enemy_basic_shot",
        "enemy_fireball",
        "enemy_ice_shard",
        "enemy_homing_orb",
        "enemy_spread_shot"
    }

    for _, id in ipairs(presets) do
        local preset = Projectiles[id]
        if not preset.enemy then
            return false, "test_enemy_projectile_flags (missing enemy=true: " .. id .. ")"
        end
    end

    return true, "test_enemy_projectile_flags"
end

local function test_enemy_projectile_required_fields()
    local presets = {
        "enemy_basic_shot",
        "enemy_fireball",
        "enemy_ice_shard",
        "enemy_homing_orb",
        "enemy_spread_shot"
    }

    local required = { "id", "speed", "damage_type", "movement", "collision", "lifetime", "tags" }

    for _, id in ipairs(presets) do
        local preset = Projectiles[id]
        local ok, missing = has_fields(preset, required)
        if not ok then
            return false, "test_enemy_projectile_required_fields (" .. id .. " missing: " .. missing .. ")"
        end
    end

    return true, "test_enemy_projectile_required_fields"
end

local function test_enemy_fireball_has_effect()
    local preset = Projectiles.enemy_fireball

    if preset.on_hit_effect ~= "burn" then
        return false, "test_enemy_fireball_has_effect (expected burn effect)"
    end

    if not preset.on_hit_duration or preset.on_hit_duration <= 0 then
        return false, "test_enemy_fireball_has_effect (missing or invalid duration)"
    end

    return true, "test_enemy_fireball_has_effect"
end

local function test_enemy_ice_shard_has_effect()
    local preset = Projectiles.enemy_ice_shard

    if preset.on_hit_effect ~= "freeze" then
        return false, "test_enemy_ice_shard_has_effect (expected freeze effect)"
    end

    if not preset.on_hit_duration or preset.on_hit_duration <= 0 then
        return false, "test_enemy_ice_shard_has_effect (missing or invalid duration)"
    end

    return true, "test_enemy_ice_shard_has_effect"
end

local function test_enemy_homing_orb_has_homing()
    local preset = Projectiles.enemy_homing_orb

    if preset.movement ~= "homing" then
        return false, "test_enemy_homing_orb_has_homing (expected homing movement)"
    end

    if not preset.homing_strength or preset.homing_strength <= 0 then
        return false, "test_enemy_homing_orb_has_homing (missing or invalid homing_strength)"
    end

    return true, "test_enemy_homing_orb_has_homing"
end

--============================================================================
-- ENEMY AIMING TESTS
--============================================================================

local function test_enemy_aiming_direct()
    local shooterPos = { x = 0, y = 0 }
    local targetPos = { x = 100, y = 0 }

    local dir = EnemyAiming.direct(shooterPos, targetPos)

    -- Should point right (1, 0)
    if not approx_equal(dir.x, 1) or not approx_equal(dir.y, 0) then
        return false, "test_enemy_aiming_direct (expected {1, 0}, got {" .. dir.x .. ", " .. dir.y .. "})"
    end

    -- Test diagonal
    targetPos = { x = 100, y = 100 }
    dir = EnemyAiming.direct(shooterPos, targetPos)

    -- Should be normalized
    local length = vec_length(dir)
    if not approx_equal(length, 1) then
        return false, "test_enemy_aiming_direct (not normalized, length=" .. length .. ")"
    end

    return true, "test_enemy_aiming_direct"
end

local function test_enemy_aiming_spread()
    local shooterPos = { x = 0, y = 0 }
    local targetPos = { x = 100, y = 0 }
    local spreadAngle = 30
    local count = 3

    local directions = EnemyAiming.spread(shooterPos, targetPos, spreadAngle, count)

    if #directions ~= count then
        return false, "test_enemy_aiming_spread (expected " .. count .. " directions, got " .. #directions .. ")"
    end

    -- All should be normalized
    for i, dir in ipairs(directions) do
        local length = vec_length(dir)
        if not approx_equal(length, 1) then
            return false, "test_enemy_aiming_spread (direction " .. i .. " not normalized, length=" .. length .. ")"
        end
    end

    -- Single direction should equal direct aim
    local singleDir = EnemyAiming.spread(shooterPos, targetPos, spreadAngle, 1)
    if #singleDir ~= 1 then
        return false, "test_enemy_aiming_spread (single count should return 1 direction)"
    end

    return true, "test_enemy_aiming_spread"
end

local function test_enemy_aiming_ring()
    local count = 8
    local directions = EnemyAiming.ring(count)

    if #directions ~= count then
        return false, "test_enemy_aiming_ring (expected " .. count .. " directions, got " .. #directions .. ")"
    end

    -- All should be normalized
    for i, dir in ipairs(directions) do
        local length = vec_length(dir)
        if not approx_equal(length, 1) then
            return false, "test_enemy_aiming_ring (direction " .. i .. " not normalized, length=" .. length .. ")"
        end
    end

    -- Test with offset
    local offsetDirs = EnemyAiming.ring(count, math.pi / 4)
    if #offsetDirs ~= count then
        return false, "test_enemy_aiming_ring (offset version failed)"
    end

    return true, "test_enemy_aiming_ring"
end

local function test_enemy_aiming_distance()
    local pos1 = { x = 0, y = 0 }
    local pos2 = { x = 3, y = 4 }

    local dist = EnemyAiming.distance(pos1, pos2)

    -- 3-4-5 triangle
    if not approx_equal(dist, 5) then
        return false, "test_enemy_aiming_distance (expected 5, got " .. dist .. ")"
    end

    -- Same position
    dist = EnemyAiming.distance(pos1, pos1)
    if not approx_equal(dist, 0) then
        return false, "test_enemy_aiming_distance (same position should be 0, got " .. dist .. ")"
    end

    return true, "test_enemy_aiming_distance"
end

local function test_enemy_aiming_spiral()
    local baseAngle = 0
    local count = 12
    local spacing = 30

    local directions = EnemyAiming.spiral(baseAngle, count, spacing)

    if #directions ~= count then
        return false, "test_enemy_aiming_spiral (expected " .. count .. " directions, got " .. #directions .. ")"
    end

    -- All should be normalized
    for i, dir in ipairs(directions) do
        local length = vec_length(dir)
        if not approx_equal(length, 1) then
            return false, "test_enemy_aiming_spiral (direction " .. i .. " not normalized, length=" .. length .. ")"
        end
    end

    return true, "test_enemy_aiming_spiral"
end

local function test_enemy_aiming_lead_target()
    local shooterPos = { x = 0, y = 0 }
    local targetPos = { x = 100, y = 0 }
    local targetVelocity = { x = 50, y = 0 }
    local projectileSpeed = 100

    local dir = EnemyAiming.leadTarget(shooterPos, targetPos, targetVelocity, projectileSpeed)

    -- Should be normalized
    local length = vec_length(dir)
    if not approx_equal(length, 1) then
        return false, "test_enemy_aiming_lead_target (not normalized, length=" .. length .. ")"
    end

    -- With zero velocity, should equal direct aim
    local directDir = EnemyAiming.direct(shooterPos, targetPos)
    local leadDirZeroVel = EnemyAiming.leadTarget(shooterPos, targetPos, { x = 0, y = 0 }, projectileSpeed)

    if not approx_equal(directDir.x, leadDirZeroVel.x) or not approx_equal(directDir.y, leadDirZeroVel.y) then
        return false, "test_enemy_aiming_lead_target (zero velocity should equal direct aim)"
    end

    return true, "test_enemy_aiming_lead_target"
end

--============================================================================
-- DEFENSIVE JOKER TESTS
--============================================================================

local function test_defensive_jokers_exist()
    local jokerIds = { "iron_skin", "flame_ward", "thorns", "survival_instinct" }

    for _, id in ipairs(jokerIds) do
        if not Jokers[id] then
            return false, "test_defensive_jokers_exist (missing: " .. id .. ")"
        end
    end

    return true, "test_defensive_jokers_exist"
end

local function test_defensive_jokers_have_calculate()
    local jokerIds = { "iron_skin", "flame_ward", "thorns", "survival_instinct" }

    for _, id in ipairs(jokerIds) do
        local joker = Jokers[id]
        if type(joker.calculate) ~= "function" then
            return false, "test_defensive_jokers_have_calculate (missing calculate: " .. id .. ")"
        end
    end

    return true, "test_defensive_jokers_have_calculate"
end

local function test_iron_skin_reduces_damage()
    local joker = Jokers.iron_skin

    local context = {
        event = "on_player_damaged",
        source = "enemy_projectile",
        damage = 20
    }

    local result = joker.calculate(joker, context)

    if not result then
        return false, "test_iron_skin_reduces_damage (no result returned)"
    end

    if not result.damage_reduction or result.damage_reduction <= 0 then
        return false, "test_iron_skin_reduces_damage (no damage reduction)"
    end

    return true, "test_iron_skin_reduces_damage"
end

local function test_flame_ward_blocks_fire()
    local joker = Jokers.flame_ward

    local context = {
        event = "on_player_damaged",
        source = "enemy_projectile",
        damage_type = "fire",
        damage = 25
    }

    local result = joker.calculate(joker, context)

    if not result then
        return false, "test_flame_ward_blocks_fire (no result returned)"
    end

    if not result.damage_reduction or result.damage_reduction ~= context.damage then
        return false, "test_flame_ward_blocks_fire (should block all fire damage)"
    end

    -- Should not trigger for non-fire
    context.damage_type = "ice"
    result = joker.calculate(joker, context)

    if result and result.damage_reduction then
        return false, "test_flame_ward_blocks_fire (should not block non-fire damage)"
    end

    return true, "test_flame_ward_blocks_fire"
end

local function test_thorns_reflects_damage()
    local joker = Jokers.thorns

    local context = {
        event = "on_player_damaged",
        source = "enemy_projectile",
        damage = 20
    }

    local result = joker.calculate(joker, context)

    if not result then
        return false, "test_thorns_reflects_damage (no result returned)"
    end

    if not result.reflect_damage or result.reflect_damage <= 0 then
        return false, "test_thorns_reflects_damage (no reflect damage)"
    end

    -- Should reflect 50%
    local expected = math.floor(context.damage * 0.5)
    if result.reflect_damage ~= expected then
        return false, "test_thorns_reflects_damage (expected " .. expected .. ", got " .. result.reflect_damage .. ")"
    end

    return true, "test_thorns_reflects_damage"
end

local function test_survival_instinct_grants_buff()
    local joker = Jokers.survival_instinct

    local context = {
        event = "on_player_damaged",
        source = "enemy_projectile",
        damage = 15
    }

    local result = joker.calculate(joker, context)

    if not result then
        return false, "test_survival_instinct_grants_buff (no result returned)"
    end

    if not result.buff then
        return false, "test_survival_instinct_grants_buff (no buff returned)"
    end

    if result.buff.value <= 1.0 then
        return false, "test_survival_instinct_grants_buff (buff should increase damage)"
    end

    if not result.buff.duration or result.buff.duration <= 0 then
        return false, "test_survival_instinct_grants_buff (buff needs duration)"
    end

    return true, "test_survival_instinct_grants_buff"
end

local function test_defensive_jokers_ignore_other_events()
    local jokerIds = { "iron_skin", "flame_ward", "thorns", "survival_instinct" }

    for _, id in ipairs(jokerIds) do
        local joker = Jokers[id]

        -- Test with wrong event
        local context = {
            event = "on_spell_cast",
            source = "enemy_projectile"
        }

        local result = joker.calculate(joker, context)

        if result then
            return false, "test_defensive_jokers_ignore_other_events (" .. id .. " should ignore non-damage events)"
        end

        -- Test with wrong source
        context = {
            event = "on_player_damaged",
            source = "player_spell"
        }

        result = joker.calculate(joker, context)

        if result then
            return false, "test_defensive_jokers_ignore_other_events (" .. id .. " should ignore non-projectile damage)"
        end
    end

    return true, "test_defensive_jokers_ignore_other_events"
end

--============================================================================
-- RUN ALL TESTS
--============================================================================

function Tests.run_all()
    print("\n=== ENEMY PROJECTILE INTEGRATION TESTS ===\n")

    local tests = {
        -- Projectile preset tests
        test_enemy_projectile_presets_exist,
        test_enemy_projectile_flags,
        test_enemy_projectile_required_fields,
        test_enemy_fireball_has_effect,
        test_enemy_ice_shard_has_effect,
        test_enemy_homing_orb_has_homing,

        -- Enemy aiming tests
        test_enemy_aiming_direct,
        test_enemy_aiming_spread,
        test_enemy_aiming_ring,
        test_enemy_aiming_distance,
        test_enemy_aiming_spiral,
        test_enemy_aiming_lead_target,

        -- Defensive joker tests
        test_defensive_jokers_exist,
        test_defensive_jokers_have_calculate,
        test_iron_skin_reduces_damage,
        test_flame_ward_blocks_fire,
        test_thorns_reflects_damage,
        test_survival_instinct_grants_buff,
        test_defensive_jokers_ignore_other_events,
    }

    local passed = 0
    local failed = 0

    for _, test in ipairs(tests) do
        local ok, name = test()
        if ok then
            passed = passed + 1
            print("✓ " .. name)
        else
            failed = failed + 1
            print("✗ " .. name)
        end
    end

    print(string.format("\n=== RESULTS: %d passed, %d failed ===\n", passed, failed))

    return failed == 0
end

-- Auto-run if directly executed
if rawget(_G, "__TESTING__") then
    Tests.run_all()
end

return Tests
