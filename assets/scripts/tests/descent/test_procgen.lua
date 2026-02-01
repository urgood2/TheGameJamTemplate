-- assets/scripts/tests/descent/test_procgen.lua
--[[
================================================================================
PROCGEN VALIDATION TESTS
================================================================================
Tests for procgen.lua validation and fallback behavior.

Requirements from bd-2qf.20:
- Walkable start/stairs (floors 1-4)
- Reachability (BFS from start to stairs)
- Quotas enforced (enemies within min-max range)
- No overlaps (stairs not under entity/item)
- Fallback behavior (after MAX_ATTEMPTS)
- Seeds 1-10 for reproducibility
================================================================================
]]

local T = {}

local procgen = require("descent.procgen")
local Map = require("descent.map")
local spec = require("descent.spec")
local rng = require("descent.rng")
local pathfinding = require("descent.pathfinding")

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

local function is_walkable(map, x, y)
    local tile = Map.get_tile(map, x, y)
    return tile == Map.TILE.FLOOR or
           tile == Map.TILE.STAIRS_UP or
           tile == Map.TILE.STAIRS_DOWN
end

local function check_no_overlaps(placements)
    local positions = {}
    
    local function add_pos(p, name)
        if p then
            local key = p.x .. "," .. p.y
            if positions[key] then
                return false, name .. " overlaps with " .. positions[key]
            end
            positions[key] = name
        end
        return true
    end
    
    local ok, err = add_pos(placements.player_start, "player_start")
    if not ok then return ok, err end
    
    ok, err = add_pos(placements.stairs_down, "stairs_down")
    if not ok then return ok, err end
    
    ok, err = add_pos(placements.stairs_up, "stairs_up")
    if not ok then return ok, err end
    
    ok, err = add_pos(placements.shop, "shop")
    if not ok then return ok, err end
    
    ok, err = add_pos(placements.altar, "altar")
    if not ok then return ok, err end
    
    ok, err = add_pos(placements.miniboss, "miniboss")
    if not ok then return ok, err end
    
    ok, err = add_pos(placements.boss, "boss")
    if not ok then return ok, err end
    
    -- Check enemies
    if placements.enemies then
        for i, e in ipairs(placements.enemies) do
            ok, err = add_pos(e, "enemy_" .. i)
            if not ok then return ok, err end
        end
    end
    
    return true, nil
end

--------------------------------------------------------------------------------
-- Walkable Start Tests
--------------------------------------------------------------------------------

function T.test_walkable_start_floor_1()
    rng.init(42)
    local floor_data, _ = procgen.generate(1, 42)
    
    assert(floor_data, "Generation should succeed for floor 1")
    assert(floor_data.placements.player_start, "Should have player start")
    
    local ps = floor_data.placements.player_start
    assert(is_walkable(floor_data.map, ps.x, ps.y),
        "Player start should be walkable")
    
    return true
end

function T.test_walkable_start_seeds_1_to_10()
    for seed = 1, 10 do
        rng.init(seed)
        local floor_data, _ = procgen.generate(1, seed)
        
        assert(floor_data, "Generation should succeed for seed " .. seed)
        local ps = floor_data.placements.player_start
        assert(ps, "Should have player start for seed " .. seed)
        assert(is_walkable(floor_data.map, ps.x, ps.y),
            "Player start should be walkable for seed " .. seed)
    end
    
    return true
end

--------------------------------------------------------------------------------
-- Stairs Walkable Tests
--------------------------------------------------------------------------------

function T.test_stairs_down_walkable_floor_1()
    rng.init(42)
    local floor_data, _ = procgen.generate(1, 42)
    
    local sd = floor_data.placements.stairs_down
    assert(sd, "Floor 1 should have stairs down")
    
    local tile = Map.get_tile(floor_data.map, sd.x, sd.y)
    assert(tile == Map.TILE.STAIRS_DOWN,
        "Stairs down position should be STAIRS_DOWN tile")
    
    return true
end

function T.test_stairs_up_walkable_floor_2()
    rng.init(42)
    local floor_data, _ = procgen.generate(2, 42)
    
    local su = floor_data.placements.stairs_up
    assert(su, "Floor 2 should have stairs up")
    
    local tile = Map.get_tile(floor_data.map, su.x, su.y)
    assert(tile == Map.TILE.STAIRS_UP,
        "Stairs up position should be STAIRS_UP tile")
    
    return true
end

function T.test_no_stairs_down_floor_5()
    rng.init(42)
    local floor_data, _ = procgen.generate(5, 42)
    
    assert(not floor_data.placements.stairs_down,
        "Floor 5 should NOT have stairs down")
    
    return true
end

--------------------------------------------------------------------------------
-- Reachability Tests
--------------------------------------------------------------------------------

function T.test_reachability_start_to_stairs_down()
    rng.init(42)
    local floor_data, _ = procgen.generate(1, 42)
    
    local ps = floor_data.placements.player_start
    local sd = floor_data.placements.stairs_down
    
    local path = pathfinding.find_path(floor_data.map, ps.x, ps.y, sd.x, sd.y)
    assert(path, "Path from start to stairs down should exist")
    assert(#path >= 2, "Path should have at least start and end nodes")
    
    return true
end

function T.test_reachability_start_to_stairs_up()
    rng.init(42)
    local floor_data, _ = procgen.generate(2, 42)
    
    local ps = floor_data.placements.player_start
    local su = floor_data.placements.stairs_up
    
    local path = pathfinding.find_path(floor_data.map, ps.x, ps.y, su.x, su.y)
    assert(path, "Path from start to stairs up should exist")
    
    return true
end

function T.test_reachability_all_floors_seeds_1_to_10()
    for seed = 1, 10 do
        for floor_num = 1, 4 do
            rng.init(seed)
            local floor_data, _ = procgen.generate(floor_num, seed)
            
            local ps = floor_data.placements.player_start
            local sd = floor_data.placements.stairs_down
            
            if sd then
                local path = pathfinding.find_path(floor_data.map, ps.x, ps.y, sd.x, sd.y)
                assert(path, string.format(
                    "Floor %d seed %d: stairs down should be reachable",
                    floor_num, seed))
            end
        end
    end
    
    return true
end

--------------------------------------------------------------------------------
-- Quotas Tests
--------------------------------------------------------------------------------

function T.test_enemy_quota_floor_1()
    local floor_spec = spec.floors.floors[1]
    
    rng.init(42)
    local floor_data, _ = procgen.generate(1, 42)
    
    local enemy_count = floor_data.placements.enemies and #floor_data.placements.enemies or 0
    
    assert(enemy_count >= floor_spec.enemies_min,
        string.format("Enemy count %d should be >= %d",
            enemy_count, floor_spec.enemies_min))
    assert(enemy_count <= floor_spec.enemies_max,
        string.format("Enemy count %d should be <= %d",
            enemy_count, floor_spec.enemies_max))
    
    return true
end

function T.test_enemy_quota_all_floors_seeds_1_to_10()
    for seed = 1, 10 do
        for floor_num = 1, 5 do
            local floor_spec = spec.floors.floors[floor_num]
            rng.init(seed)
            local floor_data, _ = procgen.generate(floor_num, seed)
            
            local enemy_count = floor_data.placements.enemies and #floor_data.placements.enemies or 0
            
            assert(enemy_count >= floor_spec.enemies_min,
                string.format("Floor %d seed %d: enemy count %d >= %d",
                    floor_num, seed, enemy_count, floor_spec.enemies_min))
        end
    end
    
    return true
end

function T.test_shop_placement_floor_1()
    rng.init(42)
    local floor_data, _ = procgen.generate(1, 42)
    
    -- Floor 1 should have shop per spec
    assert(floor_data.placements.shop, "Floor 1 should have shop placement")
    
    return true
end

function T.test_altar_placement_floor_2()
    rng.init(42)
    local floor_data, _ = procgen.generate(2, 42)
    
    -- Floor 2 should have altar per spec
    assert(floor_data.placements.altar, "Floor 2 should have altar placement")
    
    return true
end

--------------------------------------------------------------------------------
-- No Overlaps Tests
--------------------------------------------------------------------------------

function T.test_no_overlaps_floor_1()
    rng.init(42)
    local floor_data, _ = procgen.generate(1, 42)
    
    local ok, err = check_no_overlaps(floor_data.placements)
    assert(ok, "No overlaps on floor 1: " .. (err or ""))
    
    return true
end

function T.test_no_overlaps_all_floors_seeds_1_to_10()
    for seed = 1, 10 do
        for floor_num = 1, 5 do
            rng.init(seed)
            local floor_data, _ = procgen.generate(floor_num, seed)
            
            local ok, err = check_no_overlaps(floor_data.placements)
            assert(ok, string.format(
                "Floor %d seed %d: no overlaps - %s",
                floor_num, seed, err or ""))
        end
    end
    
    return true
end

function T.test_stairs_not_on_player_start()
    for seed = 1, 10 do
        rng.init(seed)
        local floor_data, _ = procgen.generate(1, seed)
        
        local ps = floor_data.placements.player_start
        local sd = floor_data.placements.stairs_down
        
        if ps and sd then
            assert(ps.x ~= sd.x or ps.y ~= sd.y,
                string.format("Seed %d: stairs down should not be on player start", seed))
        end
    end
    
    return true
end

--------------------------------------------------------------------------------
-- Fallback Behavior Tests
--------------------------------------------------------------------------------

function T.test_fallback_has_required_placements()
    -- Use fallback directly
    local fallback_data = procgen.generate_fallback(1)
    
    assert(fallback_data, "Fallback should return data")
    assert(fallback_data.fallback == true, "Should be marked as fallback")
    assert(fallback_data.placements.player_start, "Fallback should have player start")
    assert(fallback_data.placements.stairs_down, "Fallback should have stairs down")
    
    return true
end

function T.test_fallback_reachable()
    local fallback_data = procgen.generate_fallback(1)
    
    local ps = fallback_data.placements.player_start
    local sd = fallback_data.placements.stairs_down
    
    local path = pathfinding.find_path(fallback_data.map, ps.x, ps.y, sd.x, sd.y)
    assert(path, "Fallback: stairs should be reachable from start")
    
    return true
end

function T.test_fallback_walkable_start()
    local fallback_data = procgen.generate_fallback(1)
    
    local ps = fallback_data.placements.player_start
    assert(is_walkable(fallback_data.map, ps.x, ps.y),
        "Fallback player start should be walkable")
    
    return true
end

function T.test_fallback_no_overlaps()
    local fallback_data = procgen.generate_fallback(1)
    
    local ok, err = check_no_overlaps(fallback_data.placements)
    assert(ok, "Fallback: no overlaps - " .. (err or ""))
    
    return true
end

--------------------------------------------------------------------------------
-- Determinism Tests
--------------------------------------------------------------------------------

function T.test_deterministic_same_seed()
    rng.init(42)
    local data1, _ = procgen.generate(1, 42)
    
    rng.init(42)
    local data2, _ = procgen.generate(1, 42)
    
    -- Same seed should produce same hash
    assert(data1.hash == data2.hash,
        "Same seed should produce same hash: " .. data1.hash .. " vs " .. data2.hash)
    
    return true
end

function T.test_different_seeds_different_hash()
    rng.init(1)
    local data1, _ = procgen.generate(1, 1)
    
    rng.init(2)
    local data2, _ = procgen.generate(1, 2)
    
    -- Different seeds should usually produce different hashes
    -- (not guaranteed but very likely)
    assert(data1.hash ~= data2.hash,
        "Different seeds should produce different hashes")
    
    return true
end

function T.test_hash_format()
    rng.init(42)
    local floor_data, _ = procgen.generate(1, 42)
    
    assert(floor_data.hash, "Should have hash")
    assert(type(floor_data.hash) == "string", "Hash should be string")
    assert(#floor_data.hash == 8, "Hash should be 8 hex chars")
    assert(floor_data.hash:match("^%x+$"), "Hash should be hex only")
    
    return true
end

--------------------------------------------------------------------------------
-- Map Size Tests
--------------------------------------------------------------------------------

function T.test_floor_dimensions()
    for floor_num = 1, 5 do
        local floor_spec = spec.floors.floors[floor_num]
        rng.init(42)
        local floor_data, _ = procgen.generate(floor_num, 42)
        
        assert(floor_data.map.w == floor_spec.width,
            string.format("Floor %d width should be %d", floor_num, floor_spec.width))
        assert(floor_data.map.h == floor_spec.height,
            string.format("Floor %d height should be %d", floor_num, floor_spec.height))
    end
    
    return true
end

--------------------------------------------------------------------------------
-- Test Runner
--------------------------------------------------------------------------------

function T.run_all()
    local tests = {
        -- Walkable start
        { name = "walkable_start_floor_1", fn = T.test_walkable_start_floor_1 },
        { name = "walkable_start_seeds_1_to_10", fn = T.test_walkable_start_seeds_1_to_10 },
        
        -- Stairs walkable
        { name = "stairs_down_walkable_floor_1", fn = T.test_stairs_down_walkable_floor_1 },
        { name = "stairs_up_walkable_floor_2", fn = T.test_stairs_up_walkable_floor_2 },
        { name = "no_stairs_down_floor_5", fn = T.test_no_stairs_down_floor_5 },
        
        -- Reachability
        { name = "reachability_start_to_stairs_down", fn = T.test_reachability_start_to_stairs_down },
        { name = "reachability_start_to_stairs_up", fn = T.test_reachability_start_to_stairs_up },
        { name = "reachability_all_floors_seeds_1_to_10", fn = T.test_reachability_all_floors_seeds_1_to_10 },
        
        -- Quotas
        { name = "enemy_quota_floor_1", fn = T.test_enemy_quota_floor_1 },
        { name = "enemy_quota_all_floors_seeds_1_to_10", fn = T.test_enemy_quota_all_floors_seeds_1_to_10 },
        { name = "shop_placement_floor_1", fn = T.test_shop_placement_floor_1 },
        { name = "altar_placement_floor_2", fn = T.test_altar_placement_floor_2 },
        
        -- No overlaps
        { name = "no_overlaps_floor_1", fn = T.test_no_overlaps_floor_1 },
        { name = "no_overlaps_all_floors_seeds_1_to_10", fn = T.test_no_overlaps_all_floors_seeds_1_to_10 },
        { name = "stairs_not_on_player_start", fn = T.test_stairs_not_on_player_start },
        
        -- Fallback
        { name = "fallback_has_required_placements", fn = T.test_fallback_has_required_placements },
        { name = "fallback_reachable", fn = T.test_fallback_reachable },
        { name = "fallback_walkable_start", fn = T.test_fallback_walkable_start },
        { name = "fallback_no_overlaps", fn = T.test_fallback_no_overlaps },
        
        -- Determinism
        { name = "deterministic_same_seed", fn = T.test_deterministic_same_seed },
        { name = "different_seeds_different_hash", fn = T.test_different_seeds_different_hash },
        { name = "hash_format", fn = T.test_hash_format },
        
        -- Map size
        { name = "floor_dimensions", fn = T.test_floor_dimensions },
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
    print(string.format("Procgen validation tests: %d passed, %d failed", passed, failed))
    
    return failed == 0
end

return T
