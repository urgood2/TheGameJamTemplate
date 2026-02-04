-- assets/scripts/serpent/tests/test_enemies.lua
--[[
    Tests for Enemy Data

    Verifies that enemies.lua contains exactly 11 enemies with expected IDs,
    correct numeric fields, and valid wave ranges.
]]

-- Test framework imports would go here
-- For now, implementing as a standalone verification script

local function run_enemy_tests()
    local test_results = {}
    local passed = 0
    local failed = 0

    local function test(name, condition, message)
        local success = condition
        table.insert(test_results, {
            name = name,
            success = success,
            message = message or ""
        })
        if success then
            passed = passed + 1
            print("✓ " .. name)
        else
            failed = failed + 1
            print("✗ " .. name .. " - " .. (message or ""))
        end
    end

    -- Load enemies module
    local enemies_ok, enemies = pcall(require, "serpent.data.enemies")
    if not enemies_ok then
        test("Load enemies module", false, "Failed to require serpent.data.enemies: " .. tostring(enemies))
        return {passed = passed, failed = failed, results = test_results}
    end

    -- Test that we have exactly 11 entries
    local all_enemies = enemies.get_all_enemies and enemies.get_all_enemies() or {}
    test("Exactly 11 enemies", #all_enemies == 11, string.format("Found %d enemies, expected 11", #all_enemies))

    -- Expected enemy IDs as specified in PLAN.md
    local expected_ids = {
        "slime", "bat", "goblin", "orc", "skeleton",
        "wizard", "troll", "demon", "dragon",
        "swarm_queen", "lich_king"
    }

    -- Test that all expected IDs are present
    for _, expected_id in ipairs(expected_ids) do
        local enemy = enemies.get_enemy and enemies.get_enemy(expected_id) or nil
        test("Enemy " .. expected_id .. " exists", enemy ~= nil, "Enemy definition not found")
    end

    -- Test numeric fields match expected values (table-driven)
    local expected_enemy_data = {
        slime = { base_hp = 20, base_damage = 5, speed = 80, boss = false, min_wave = 1, max_wave = 5 },
        bat = { base_hp = 15, base_damage = 8, speed = 200, boss = false, min_wave = 1, max_wave = 10 },
        goblin = { base_hp = 30, base_damage = 10, speed = 120, boss = false, min_wave = 3, max_wave = 10 },
        orc = { base_hp = 50, base_damage = 15, speed = 120, boss = false, min_wave = 5, max_wave = 15 },
        skeleton = { base_hp = 40, base_damage = 12, speed = 120, boss = false, min_wave = 5, max_wave = 15 },
        wizard = { base_hp = 35, base_damage = 20, speed = 100, boss = false, min_wave = 8, max_wave = 20 },
        troll = { base_hp = 100, base_damage = 25, speed = 80, boss = false, min_wave = 10, max_wave = 20 },
        demon = { base_hp = 80, base_damage = 30, speed = 140, boss = false, min_wave = 12, max_wave = 20 },
        dragon = { base_hp = 200, base_damage = 40, speed = 60, boss = false, min_wave = 15, max_wave = 20 },
        swarm_queen = { base_hp = 500, base_damage = 50, speed = 50, boss = true, min_wave = 10, max_wave = 10 },
        lich_king = { base_hp = 800, base_damage = 75, speed = 100, boss = true, min_wave = 20, max_wave = 20 }
    }

    for enemy_id, expected in pairs(expected_enemy_data) do
        local enemy = enemies.get_enemy and enemies.get_enemy(enemy_id) or nil
        if enemy then
            -- Test numeric fields
            test(enemy_id .. " base_hp", enemy.base_hp == expected.base_hp,
                 string.format("Expected %d, got %s", expected.base_hp, tostring(enemy.base_hp)))

            test(enemy_id .. " base_damage", enemy.base_damage == expected.base_damage,
                 string.format("Expected %d, got %s", expected.base_damage, tostring(enemy.base_damage)))

            test(enemy_id .. " speed", enemy.speed == expected.speed,
                 string.format("Expected %d, got %s", expected.speed, tostring(enemy.speed)))

            test(enemy_id .. " min_wave", enemy.min_wave == expected.min_wave,
                 string.format("Expected %d, got %s", expected.min_wave, tostring(enemy.min_wave)))

            test(enemy_id .. " max_wave", enemy.max_wave == expected.max_wave,
                 string.format("Expected %d, got %s", expected.max_wave, tostring(enemy.max_wave)))

            -- Test boss flag (either via tags table or direct boss field)
            local is_boss = false
            if enemy.tags then
                for _, tag in ipairs(enemy.tags) do
                    if tag == "boss" then
                        is_boss = true
                        break
                    end
                end
            elseif enemy.boss ~= nil then
                is_boss = enemy.boss
            end

            test(enemy_id .. " boss flag", is_boss == expected.boss,
                 string.format("Expected %s, got %s", tostring(expected.boss), tostring(is_boss)))
        end
    end

    -- Test wave ranges are valid (min <= max)
    for enemy_id, expected in pairs(expected_enemy_data) do
        local enemy = enemies.get_enemy and enemies.get_enemy(enemy_id) or nil
        if enemy and enemy.min_wave and enemy.max_wave then
            test(enemy_id .. " wave range", enemy.min_wave <= enemy.max_wave,
                 string.format("min_wave %d > max_wave %d", enemy.min_wave, enemy.max_wave))
        end
    end

    -- Test boss enemies have exact wave ranges (min == max)
    local boss_enemies = {"swarm_queen", "lich_king"}
    for _, boss_id in ipairs(boss_enemies) do
        local enemy = enemies.get_enemy and enemies.get_enemy(boss_id) or nil
        if enemy and enemy.min_wave and enemy.max_wave then
            test(boss_id .. " exact wave", enemy.min_wave == enemy.max_wave,
                 string.format("Boss should have exact wave, got %d-%d", enemy.min_wave, enemy.max_wave))
        end
    end

    -- Special test: swarm_queen at wave 10, lich_king at wave 20
    local swarm_queen = enemies.get_enemy and enemies.get_enemy("swarm_queen") or nil
    if swarm_queen then
        test("swarm_queen wave 10", swarm_queen.min_wave == 10 and swarm_queen.max_wave == 10,
             string.format("Expected wave 10, got %d-%d", swarm_queen.min_wave or 0, swarm_queen.max_wave or 0))
    end

    local lich_king = enemies.get_enemy and enemies.get_enemy("lich_king") or nil
    if lich_king then
        test("lich_king wave 20", lich_king.min_wave == 20 and lich_king.max_wave == 20,
             string.format("Expected wave 20, got %d-%d", lich_king.min_wave or 0, lich_king.max_wave or 0))
    end

    return {passed = passed, failed = failed, results = test_results}
end

-- Run tests if executed directly
if not pcall(debug.getlocal, 4, 1) then
    print("=== Enemy Data Tests ===")
    print("")

    local results = run_enemy_tests()

    print("")
    print("=== Test Summary ===")
    print(string.format("Passed: %d", results.passed))
    print(string.format("Failed: %d", results.failed))
    print(string.format("Total:  %d", results.passed + results.failed))

    if results.failed == 0 then
        print("✓ All enemy tests passed!")
        os.exit(0)
    else
        print("✗ Some enemy tests failed!")
        os.exit(1)
    end
end

-- Export for use in test framework
return {
    run_enemy_tests = run_enemy_tests
}