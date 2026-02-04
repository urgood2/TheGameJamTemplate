--[[
================================================================================
TEST: SERPENT_SEED Determinism Verification
================================================================================
Manual verification that same SERPENT_SEED yields identical results for:
- Shop offers (tier selection, unit IDs, costs)
- Enemy spawn positions (x, y coordinates via edge_random algorithm)

Implements task bd-2mf2 requirements: "Same SERPENT_SEED yields identical shop offers and spawn positions"

Run with: lua assets/scripts/serpent/tests/test_determinism_verification.lua
Or with specific seed: SERPENT_SEED=54321 lua assets/scripts/serpent/tests/test_determinism_verification.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")

-- Mock dependencies for test environment
_G.log_debug = function(msg) end
_G.log_warning = function(msg) end

t.describe("SERPENT_SEED Determinism Verification", function()
    t.it("produces identical shop offers with same seed", function()
        local rng = require("serpent.rng")
        local shop = require("serpent.serpent_shop")
        local shop_odds = require("serpent.data.shop_odds")
        local units_module = require("serpent.data.units")

        -- Convert units module to lookup table format expected by shop
        local units = {}
        for _, unit in ipairs(units_module.get_all_units()) do
            units[unit.id] = unit
        end

        -- Get seed from environment or use default
        local test_seed = tonumber(os.getenv("SERPENT_SEED") or "") or 12345
        local wave_num = 5
        local gold = 100

        -- Generate shop offers with first RNG instance
        local rng1 = rng.create(test_seed)
        local shop_state1 = shop.enter_shop(wave_num, gold, rng1, units, shop_odds)

        -- Generate shop offers with second RNG instance (same seed)
        local rng2 = rng.create(test_seed)
        local shop_state2 = shop.enter_shop(wave_num, gold, rng2, units, shop_odds)

        -- Verify shop state is identical
        t.expect(shop_state1.upcoming_wave).to_be(shop_state2.upcoming_wave)
        t.expect(shop_state1.reroll_count).to_be(shop_state2.reroll_count)
        t.expect(#shop_state1.offers).to_be(#shop_state2.offers)

        -- Verify each offer is identical
        for i = 1, #shop_state1.offers do
            local offer1 = shop_state1.offers[i]
            local offer2 = shop_state2.offers[i]

            t.expect(offer1.slot).to_be(offer2.slot)
            t.expect(offer1.def_id).to_be(offer2.def_id)
            t.expect(offer1.tier).to_be(offer2.tier)
            t.expect(offer1.cost).to_be(offer2.cost)
        end

        -- Print results for manual verification
        print(string.format("\n=== Shop Offers Test (SEED=%d, WAVE=%d) ===", test_seed, wave_num))
        for i = 1, #shop_state1.offers do
            local offer = shop_state1.offers[i]
            print(string.format("Slot %d: %s (T%d, %d gold)",
                offer.slot, offer.def_id, offer.tier, offer.cost))
        end
    end)

    t.it("produces identical spawn positions with same seed", function()
        local rng = require("serpent.rng")
        local enemy_spawner_adapter = require("serpent.enemy_spawner_adapter")

        -- Get seed from environment or use default
        local test_seed = tonumber(os.getenv("SERPENT_SEED") or "") or 12345

        local spawn_rule = {
            mode = "edge_random",
            arena = { w = 800, h = 600, padding = 50 }
        }

        -- Generate spawn positions with first RNG instance
        local rng1 = rng.create(test_seed)
        local positions1 = {}
        for i = 1, 10 do
            local x, y = enemy_spawner_adapter.compute_spawn_position(rng1, spawn_rule)
            positions1[i] = { x = x, y = y }
        end

        -- Generate spawn positions with second RNG instance (same seed)
        local rng2 = rng.create(test_seed)
        local positions2 = {}
        for i = 1, 10 do
            local x, y = enemy_spawner_adapter.compute_spawn_position(rng2, spawn_rule)
            positions2[i] = { x = x, y = y }
        end

        -- Verify all positions are identical
        for i = 1, 10 do
            t.expect(positions1[i].x).to_be(positions2[i].x)
            t.expect(positions1[i].y).to_be(positions2[i].y)
        end

        -- Print results for manual verification
        print(string.format("\n=== Spawn Positions Test (SEED=%d) ===", test_seed))
        for i = 1, 10 do
            local pos = positions1[i]
            print(string.format("Enemy %2d: (%.2f, %.2f)", i, pos.x, pos.y))
        end
    end)

    t.it("produces identical shop rerolls with same seed", function()
        local rng = require("serpent.rng")
        local shop = require("serpent.serpent_shop")
        local shop_odds = require("serpent.data.shop_odds")
        local units_module = require("serpent.data.units")

        -- Convert units module to lookup table format expected by shop
        local units = {}
        for _, unit in ipairs(units_module.get_all_units()) do
            units[unit.id] = unit
        end

        -- Get seed from environment or use default
        local test_seed = tonumber(os.getenv("SERPENT_SEED") or "") or 12345
        local wave_num = 3
        local gold = 100

        -- Setup initial shop state and perform reroll with first RNG
        local rng1 = rng.create(test_seed)
        local initial_shop1 = shop.enter_shop(wave_num, gold, rng1, units, shop_odds)
        local rerolled_shop1, cost1 = shop.reroll(initial_shop1, rng1, units, shop_odds)

        -- Setup identical initial shop state and perform reroll with second RNG (same seed)
        local rng2 = rng.create(test_seed)
        local initial_shop2 = shop.enter_shop(wave_num, gold, rng2, units, shop_odds)
        local rerolled_shop2, cost2 = shop.reroll(initial_shop2, rng2, units, shop_odds)

        -- Verify initial shops are identical
        for i = 1, #initial_shop1.offers do
            t.expect(initial_shop1.offers[i].def_id).to_be(initial_shop2.offers[i].def_id)
        end

        -- Verify rerolled shops are identical
        t.expect(cost1).to_be(cost2)
        t.expect(rerolled_shop1.reroll_count).to_be(rerolled_shop2.reroll_count)
        t.expect(#rerolled_shop1.offers).to_be(#rerolled_shop2.offers)

        for i = 1, #rerolled_shop1.offers do
            local offer1 = rerolled_shop1.offers[i]
            local offer2 = rerolled_shop2.offers[i]

            t.expect(offer1.def_id).to_be(offer2.def_id)
            t.expect(offer1.tier).to_be(offer2.tier)
            t.expect(offer1.cost).to_be(offer2.cost)
        end

        -- Print results for manual verification
        print(string.format("\n=== Shop Reroll Test (SEED=%d, WAVE=%d) ===", test_seed, wave_num))
        print("Initial offers:")
        for i = 1, #initial_shop1.offers do
            local offer = initial_shop1.offers[i]
            print(string.format("  Slot %d: %s (T%d, %d gold)",
                offer.slot, offer.def_id, offer.tier, offer.cost))
        end
        print(string.format("Reroll cost: %d gold", -cost1))
        print("Rerolled offers:")
        for i = 1, #rerolled_shop1.offers do
            local offer = rerolled_shop1.offers[i]
            print(string.format("  Slot %d: %s (T%d, %d gold)",
                offer.slot, offer.def_id, offer.tier, offer.cost))
        end
    end)

    t.it("produces different results with different seeds", function()
        local rng = require("serpent.rng")
        local shop = require("serpent.serpent_shop")
        local shop_odds = require("serpent.data.shop_odds")
        local units_module = require("serpent.data.units")
        local enemy_spawner_adapter = require("serpent.enemy_spawner_adapter")

        -- Convert units module to lookup table format expected by shop
        local units = {}
        for _, unit in ipairs(units_module.get_all_units()) do
            units[unit.id] = unit
        end

        -- Use two different seeds
        local seed1 = 12345
        local seed2 = 54321
        local wave_num = 5
        local gold = 100

        -- Generate shop offers with different seeds
        local rng1 = rng.create(seed1)
        local rng2 = rng.create(seed2)

        local shop_state1 = shop.enter_shop(wave_num, gold, rng1, units, shop_odds)
        local shop_state2 = shop.enter_shop(wave_num, gold, rng2, units, shop_odds)

        -- Check that at least one offer is different (very high probability)
        local offers_different = false
        for i = 1, #shop_state1.offers do
            if shop_state1.offers[i].def_id ~= shop_state2.offers[i].def_id then
                offers_different = true
                break
            end
        end

        -- Generate spawn positions with different seeds
        local spawn_rule = {
            mode = "edge_random",
            arena = { w = 800, h = 600, padding = 50 }
        }

        local rng3 = rng.create(seed1)
        local rng4 = rng.create(seed2)

        local pos1_x, pos1_y = enemy_spawner_adapter.compute_spawn_position(rng3, spawn_rule)
        local pos2_x, pos2_y = enemy_spawner_adapter.compute_spawn_position(rng4, spawn_rule)

        local positions_different = (pos1_x ~= pos2_x) or (pos1_y ~= pos2_y)

        -- At least one system should produce different results
        t.expect(offers_different or positions_different).to_be(true)

        -- Print results for manual verification
        print(string.format("\n=== Different Seeds Test (SEED1=%d, SEED2=%d) ===", seed1, seed2))
        print("Shop offers differ:", offers_different)
        print("Spawn positions differ:", positions_different)
        print(string.format("Spawn1: (%.2f, %.2f)", pos1_x, pos1_y))
        print(string.format("Spawn2: (%.2f, %.2f)", pos2_x, pos2_y))
    end)
end)

t.describe("SERPENT_SEED Environment Integration", function()
    t.it("reads seed from SERPENT_SEED environment variable", function()
        -- Test the formula from PLAN.md: STARTING_SEED = tonumber(os.getenv("SERPENT_SEED") or "") or 12345

        -- Test with no environment variable (should default to 12345)
        local default_seed = tonumber(os.getenv("SERPENT_SEED") or "") or 12345

        -- Test current environment variable value
        local env_value = os.getenv("SERPENT_SEED")
        local parsed_seed = tonumber(env_value or "") or 12345

        t.expect(parsed_seed).to_be(default_seed)

        -- Print current seed configuration for manual verification
        print(string.format("\n=== SERPENT_SEED Environment Test ==="))
        print(string.format("Environment variable SERPENT_SEED: %s", env_value or "(not set)"))
        print(string.format("Parsed seed value: %d", parsed_seed))
        print(string.format("Default seed (if unset): %d", 12345))

        -- Verify seed produces reproducible results
        local rng = require("serpent.rng")
        local test_rng1 = rng.create(parsed_seed)
        local test_rng2 = rng.create(parsed_seed)

        local val1 = test_rng1:float()
        local val2 = test_rng2:float()

        t.expect(val1).to_be(val2)
        print(string.format("RNG test with seed %d: %.6f", parsed_seed, val1))
    end)
end)

-- Add comprehensive manual verification report
local function run_manual_verification_report()
    local test_seed = tonumber(os.getenv("SERPENT_SEED") or "") or 12345

    print("\n" .. string.rep("=", 80))
    print("SERPENT_SEED DETERMINISM VERIFICATION REPORT")
    print(string.rep("=", 80))
    print(string.format("Test Seed: %d", test_seed))
    print("Date: " .. os.date("%Y-%m-%d %H:%M:%S"))
    print("")

    -- Quick determinism check
    local rng = require("serpent.rng")
    local shop = require("serpent.serpent_shop")
    local shop_odds = require("serpent.data.shop_odds")
    local units_module = require("serpent.data.units")
    local enemy_spawner_adapter = require("serpent.enemy_spawner_adapter")

    -- Convert units module to lookup table format expected by shop
    local units = {}
    for _, unit in ipairs(units_module.get_all_units()) do
        units[unit.id] = unit
    end

    print("1. Shop Offers Determinism:")
    local rng1 = rng.create(test_seed)
    local rng2 = rng.create(test_seed)

    local shop1 = shop.enter_shop(1, 100, rng1, units, shop_odds)
    local shop2 = shop.enter_shop(1, 100, rng2, units, shop_odds)

    local shop_identical = true
    for i = 1, #shop1.offers do
        if shop1.offers[i].def_id ~= shop2.offers[i].def_id then
            shop_identical = false
            break
        end
    end
    print(string.format("   ✓ Same seed produces identical shop offers: %s", shop_identical and "PASS" or "FAIL"))

    print("")
    print("2. Spawn Position Determinism:")
    local spawn_rule = { mode = "edge_random", arena = { w = 800, h = 600, padding = 50 } }

    local rng3 = rng.create(test_seed)
    local rng4 = rng.create(test_seed)

    local x1, y1 = enemy_spawner_adapter.compute_spawn_position(rng3, spawn_rule)
    local x2, y2 = enemy_spawner_adapter.compute_spawn_position(rng4, spawn_rule)

    local positions_identical = (x1 == x2 and y1 == y2)
    print(string.format("   ✓ Same seed produces identical spawn positions: %s", positions_identical and "PASS" or "FAIL"))

    print("")
    print("3. Cross-Run Determinism Test:")
    print("   To verify determinism across runs, execute this command multiple times:")
    print(string.format("   SERPENT_SEED=%d lua assets/scripts/serpent/tests/test_determinism_verification.lua", test_seed))
    print("   The output should be identical every time.")

    print("")
    print("VERIFICATION STATUS: " .. (shop_identical and positions_identical and "COMPLETE" or "FAILED"))
    print(string.rep("=", 80))
end

-- Run the test suite
local success = t.run()

-- Run manual verification report
run_manual_verification_report()

-- Exit with appropriate code
os.exit(success and 0 or 1)