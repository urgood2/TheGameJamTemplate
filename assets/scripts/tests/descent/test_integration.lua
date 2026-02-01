-- assets/scripts/tests/descent/test_integration.lua
--[[
================================================================================
INTEGRATION TEST: FULL RUN SEED 42
================================================================================
Tests full game determinism with seed 42.

Requirements from bd-2qf.65:
- Deterministic map generation
- Deterministic enemy spawns
- Deterministic combat outcomes
- Same seed = identical game

Acceptance: Same seed = identical game.
================================================================================
]]

local T = {}

-- Dependencies
local procgen = require("descent.procgen")
local Map = require("descent.map")
local spec = require("descent.spec")
local rng = require("descent.rng")
local combat = require("descent.combat")
local pathfinding = require("descent.pathfinding")
local player_mod = require("descent.player")

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

local function create_test_player()
    return {
        id = "player_1",
        type = "player",
        x = 0,
        y = 0,
        hp = spec.stats.hp.base,
        hp_max = spec.stats.hp.base,
        mp = spec.stats.mp.base,
        mp_max = spec.stats.mp.base,
        level = 1,
        xp = 0,
        str = 10,
        dex = 10,
        int = 10,
        weapon_base = 5,
        armor = 2,
        evasion = 10,
        species_bonus = 0,
        species_multiplier = 1,
        spell_base = 8,
        skill = 5,
        inventory = {},
        spells = {},
        gold = 0,
        god = nil,
        piety = 0,
    }
end

local function create_test_enemy(id, x, y)
    return {
        id = "enemy_" .. id,
        type = "enemy",
        name = "goblin",
        x = x,
        y = y,
        hp = 10,
        hp_max = 10,
        str = 5,
        dex = 8,
        int = 3,
        weapon_base = 3,
        armor = 1,
        evasion = 5,
        species_bonus = 0,
        alive = true,
    }
end

local function generate_full_floor(floor_num, seed)
    rng.init(seed)
    local floor_data, _ = procgen.generate(floor_num, seed)
    
    if not floor_data then
        return nil
    end
    
    -- Create player at start
    local player = create_test_player()
    player.x = floor_data.placements.player_start.x
    player.y = floor_data.placements.player_start.y
    
    -- Create enemies
    local enemies = {}
    for i, e in ipairs(floor_data.placements.enemies or {}) do
        table.insert(enemies, create_test_enemy(i, e.x, e.y))
    end
    
    return {
        floor_data = floor_data,
        player = player,
        enemies = enemies,
    }
end

local function compute_state_hash(game)
    local parts = {}
    
    -- Map hash
    table.insert(parts, game.floor_data.hash)
    
    -- Player position
    table.insert(parts, string.format("p%d,%d", game.player.x, game.player.y))
    
    -- Enemy positions
    for i, e in ipairs(game.enemies) do
        table.insert(parts, string.format("e%d:%d,%d", i, e.x, e.y))
    end
    
    local str = table.concat(parts, "_")
    
    -- Simple hash
    local hash = 5381
    for i = 1, #str do
        hash = ((hash * 33) + string.byte(str, i)) % 2147483647
    end
    
    return string.format("%08x", hash)
end

local function simulate_combat_sequence(player, enemies, seed, num_rounds)
    rng.init(seed)
    local results = {}
    
    for round = 1, num_rounds do
        for i, enemy in ipairs(enemies) do
            if enemy.hp > 0 then
                -- Player attacks enemy
                local result = combat.resolve_melee(player, enemy)
                table.insert(results, {
                    round = round,
                    attacker = "player",
                    target = i,
                    hit = result.hit,
                    damage = result.damage,
                    roll = result.roll,
                })
                
                if result.hit then
                    enemy.hp = enemy.hp - result.damage
                end
                
                -- Enemy attacks player if still alive
                if enemy.hp > 0 then
                    local enemy_result = combat.resolve_melee(enemy, player)
                    table.insert(results, {
                        round = round,
                        attacker = "enemy_" .. i,
                        target = "player",
                        hit = enemy_result.hit,
                        damage = enemy_result.damage,
                        roll = enemy_result.roll,
                    })
                    
                    if enemy_result.hit then
                        player.hp = player.hp - enemy_result.damage
                    end
                end
            end
        end
    end
    
    return results
end

--------------------------------------------------------------------------------
-- Determinism Tests
--------------------------------------------------------------------------------

function T.test_seed_42_map_deterministic()
    rng.init(42)
    local game1 = generate_full_floor(1, 42)
    
    rng.init(42)
    local game2 = generate_full_floor(1, 42)
    
    assert(game1, "Game 1 should generate")
    assert(game2, "Game 2 should generate")
    
    assert(game1.floor_data.hash == game2.floor_data.hash,
        "Same seed should produce same map hash")
    
    return true
end

function T.test_seed_42_enemy_spawn_deterministic()
    rng.init(42)
    local game1 = generate_full_floor(1, 42)
    
    rng.init(42)
    local game2 = generate_full_floor(1, 42)
    
    assert(#game1.enemies == #game2.enemies,
        "Same seed should produce same enemy count")
    
    for i = 1, #game1.enemies do
        assert(game1.enemies[i].x == game2.enemies[i].x,
            "Enemy " .. i .. " should have same x position")
        assert(game1.enemies[i].y == game2.enemies[i].y,
            "Enemy " .. i .. " should have same y position")
    end
    
    return true
end

function T.test_seed_42_player_start_deterministic()
    rng.init(42)
    local game1 = generate_full_floor(1, 42)
    
    rng.init(42)
    local game2 = generate_full_floor(1, 42)
    
    assert(game1.player.x == game2.player.x,
        "Player should start at same x")
    assert(game1.player.y == game2.player.y,
        "Player should start at same y")
    
    return true
end

function T.test_seed_42_combat_deterministic()
    -- Run combat sequence with seed 42
    local player1 = create_test_player()
    local enemies1 = { create_test_enemy(1, 5, 5), create_test_enemy(2, 6, 5) }
    local results1 = simulate_combat_sequence(player1, enemies1, 42, 3)
    
    -- Run same sequence again
    local player2 = create_test_player()
    local enemies2 = { create_test_enemy(1, 5, 5), create_test_enemy(2, 6, 5) }
    local results2 = simulate_combat_sequence(player2, enemies2, 42, 3)
    
    assert(#results1 == #results2,
        "Same seed should produce same combat event count")
    
    for i = 1, #results1 do
        assert(results1[i].hit == results2[i].hit,
            "Combat " .. i .. " hit should match")
        assert(results1[i].roll == results2[i].roll,
            "Combat " .. i .. " roll should match")
        assert(results1[i].damage == results2[i].damage,
            "Combat " .. i .. " damage should match")
    end
    
    return true
end

function T.test_seed_42_full_state_deterministic()
    local hash1 = compute_state_hash(generate_full_floor(1, 42))
    local hash2 = compute_state_hash(generate_full_floor(1, 42))
    
    assert(hash1 == hash2,
        "Full state hash should match for same seed: " .. hash1 .. " vs " .. hash2)
    
    return true
end

--------------------------------------------------------------------------------
-- All Floors Determinism
--------------------------------------------------------------------------------

function T.test_all_floors_deterministic()
    for floor_num = 1, 5 do
        local hash1 = compute_state_hash(generate_full_floor(floor_num, 42))
        local hash2 = compute_state_hash(generate_full_floor(floor_num, 42))
        
        assert(hash1 == hash2,
            string.format("Floor %d: hash should match - %s vs %s",
                floor_num, hash1, hash2))
    end
    
    return true
end

--------------------------------------------------------------------------------
-- Different Seeds Different Results
--------------------------------------------------------------------------------

function T.test_different_seeds_different_maps()
    local hash42 = compute_state_hash(generate_full_floor(1, 42))
    local hash43 = compute_state_hash(generate_full_floor(1, 43))
    
    assert(hash42 ~= hash43,
        "Different seeds should produce different maps")
    
    return true
end

function T.test_different_seeds_different_combat()
    local player1 = create_test_player()
    local enemies1 = { create_test_enemy(1, 5, 5) }
    local results1 = simulate_combat_sequence(player1, enemies1, 42, 5)
    
    local player2 = create_test_player()
    local enemies2 = { create_test_enemy(1, 5, 5) }
    local results2 = simulate_combat_sequence(player2, enemies2, 43, 5)
    
    -- At least some rolls should differ
    local differences = 0
    for i = 1, math.min(#results1, #results2) do
        if results1[i].roll ~= results2[i].roll then
            differences = differences + 1
        end
    end
    
    assert(differences > 0,
        "Different seeds should produce different combat rolls")
    
    return true
end

--------------------------------------------------------------------------------
-- Edge Case Tests
--------------------------------------------------------------------------------

function T.test_seed_0_works()
    local game = generate_full_floor(1, 0)
    assert(game, "Seed 0 should generate valid floor")
    assert(game.floor_data, "Should have floor data")
    assert(game.player, "Should have player")
    
    return true
end

function T.test_large_seed_works()
    local game = generate_full_floor(1, 2147483647)
    assert(game, "Large seed should generate valid floor")
    
    return true
end

function T.test_sequential_seeds_different()
    local hashes = {}
    for seed = 1, 10 do
        local game = generate_full_floor(1, seed)
        local hash = compute_state_hash(game)
        
        assert(not hashes[hash],
            "Seed " .. seed .. " should produce unique hash")
        hashes[hash] = seed
    end
    
    return true
end

--------------------------------------------------------------------------------
-- Consistency After Multiple Operations
--------------------------------------------------------------------------------

function T.test_consistency_after_combat()
    -- Generate floor
    rng.init(42)
    local game = generate_full_floor(1, 42)
    local initial_hash = game.floor_data.hash
    
    -- Simulate some combat
    if #game.enemies > 0 then
        combat.resolve_melee(game.player, game.enemies[1])
    end
    
    -- Map hash should not change from combat
    assert(game.floor_data.hash == initial_hash,
        "Map hash should not change after combat")
    
    return true
end

function T.test_multi_floor_consistency()
    local hashes = {}
    
    rng.init(42)
    for floor_num = 1, 5 do
        local game = generate_full_floor(floor_num, 42 + floor_num)
        hashes[floor_num] = game.floor_data.hash
    end
    
    -- Regenerate and compare
    rng.init(42)
    for floor_num = 1, 5 do
        local game = generate_full_floor(floor_num, 42 + floor_num)
        assert(game.floor_data.hash == hashes[floor_num],
            "Floor " .. floor_num .. " hash should match on regeneration")
    end
    
    return true
end

--------------------------------------------------------------------------------
-- Test Runner
--------------------------------------------------------------------------------

function T.run_all()
    local tests = {
        -- Core determinism
        { name = "seed_42_map_deterministic", fn = T.test_seed_42_map_deterministic },
        { name = "seed_42_enemy_spawn_deterministic", fn = T.test_seed_42_enemy_spawn_deterministic },
        { name = "seed_42_player_start_deterministic", fn = T.test_seed_42_player_start_deterministic },
        { name = "seed_42_combat_deterministic", fn = T.test_seed_42_combat_deterministic },
        { name = "seed_42_full_state_deterministic", fn = T.test_seed_42_full_state_deterministic },
        
        -- All floors
        { name = "all_floors_deterministic", fn = T.test_all_floors_deterministic },
        
        -- Different seeds
        { name = "different_seeds_different_maps", fn = T.test_different_seeds_different_maps },
        { name = "different_seeds_different_combat", fn = T.test_different_seeds_different_combat },
        
        -- Edge cases
        { name = "seed_0_works", fn = T.test_seed_0_works },
        { name = "large_seed_works", fn = T.test_large_seed_works },
        { name = "sequential_seeds_different", fn = T.test_sequential_seeds_different },
        
        -- Consistency
        { name = "consistency_after_combat", fn = T.test_consistency_after_combat },
        { name = "multi_floor_consistency", fn = T.test_multi_floor_consistency },
    }
    
    local passed = 0
    local failed = 0
    
    for _, test in ipairs(tests) do
        local ok, err = pcall(test.fn)
        if ok then
            print("[PASS] " .. test.name)
            passed = passed + 1
        else
            print("[FAIL] " .. test.name .. ": " .. tostring(err))
            failed = failed + 1
        end
    end
    
    print("")
    print(string.format("Integration tests (seed 42): %d passed, %d failed", passed, failed))
    
    return failed == 0
end

return T
