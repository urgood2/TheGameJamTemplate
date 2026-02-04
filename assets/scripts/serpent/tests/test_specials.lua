-- assets/scripts/serpent/tests/test_specials.lua
--[[
    Test Suite: Specials System

    Deterministic verification of all 6 implemented specials:
    1. healer_adjacent_regen - 10 HP/sec to adjacent units
    2. knight_block - 20% damage reduction
    3. sniper_crit - 20% chance for 2x damage
    4. bard_adjacent_atkspd - +10% attack speed to adjacent units
    5. berserker_frenzy - +5% attack per kill
    6. paladin_divine_shield - Negate first nonzero hit per wave

    Run with: lua assets/scripts/serpent/tests/test_specials.lua
]]

-- Load dependencies
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local specials_system = require("serpent.specials_system")

-- Test framework
local test = {}
test.passed = 0
test.failed = 0

function test.assert_eq(actual, expected, message)
    if actual == expected then
        test.passed = test.passed + 1
        return true
    else
        test.failed = test.failed + 1
        print(string.format("✗ FAILED: %s\n  Expected: %s\n  Actual: %s",
            message or "assertion", tostring(expected), tostring(actual)))
        return false
    end
end

function test.assert_true(condition, message)
    return test.assert_eq(condition, true, message)
end

function test.assert_false(condition, message)
    return test.assert_eq(condition, false, message)
end

function test.assert_near(actual, expected, tolerance, message)
    if math.abs(actual - expected) <= tolerance then
        test.passed = test.passed + 1
        return true
    else
        test.failed = test.failed + 1
        print(string.format("✗ FAILED: %s\n  Expected: %s (±%s)\n  Actual: %s",
            message or "assertion", tostring(expected), tostring(tolerance), tostring(actual)))
        return false
    end
end

-- Mock RNG for deterministic tests
local function create_mock_rng(sequence)
    local idx = 0
    return {
        float = function(self)
            idx = idx + 1
            return sequence[((idx - 1) % #sequence) + 1]
        end
    }
end

-- Helper: Create a test segment
local function make_segment(instance_id, special_id, hp)
    return {
        instance_id = instance_id,
        def_id = "test_unit",
        level = 1,
        hp = hp or 100,
        hp_max_base = 100,
        attack_base = 10,
        range_base = 50,
        atk_spd_base = 1.0,
        cooldown = 0,
        acquired_seq = instance_id,
        special_id = special_id,
        special_state = nil
    }
end

-- Helper: Create a test snake state
local function make_snake_state(segments)
    return {
        segments = segments,
        min_len = 3,
        max_len = 8
    }
end

--===========================================================================
-- TEST 1: Healer Adjacent Regen
--===========================================================================

function test.test_healer_regen_basic()
    print("\n=== Test: Healer Adjacent Regen (Basic) ===")

    local snake_state = make_snake_state({
        make_segment(1, nil, 100),                        -- Left neighbor
        make_segment(2, "healer_adjacent_regen", 100),    -- Healer
        make_segment(3, nil, 100),                        -- Right neighbor
    })

    local ctx = { snake_state = snake_state }

    -- Heal rate is 10 HP/sec, so 0.1s = 1 HP (accumulator reaches 1.0)
    local events = specials_system.process_healer_regen(0.1, ctx)

    -- Should generate 2 heal events (1 for left, 1 for right)
    test.assert_eq(#events, 2, "Should generate 2 heal events (left + right)")

    -- Verify heal amounts
    local left_heals = 0
    local right_heals = 0
    for _, event in ipairs(events) do
        test.assert_eq(event.type, "HealEventUnit", "Event should be HealEventUnit")
        test.assert_eq(event.heal_amount, 1, "Heal amount should be 1")
        if event.target_instance_id == 1 then
            left_heals = left_heals + 1
        elseif event.target_instance_id == 3 then
            right_heals = right_heals + 1
        end
    end

    test.assert_eq(left_heals, 1, "Should heal left neighbor once")
    test.assert_eq(right_heals, 1, "Should heal right neighbor once")

    print("✓ Healer regenerates adjacent units at 10 HP/sec")
end

function test.test_healer_regen_accumulator()
    print("\n=== Test: Healer Regen Accumulator ===")

    local snake_state = make_snake_state({
        make_segment(1, nil, 100),
        make_segment(2, "healer_adjacent_regen", 100),
        make_segment(3, nil, 100),
    })

    local ctx = { snake_state = snake_state }

    -- 0.05s should not emit (0.5 HP accumulated)
    local events1 = specials_system.process_healer_regen(0.05, ctx)
    test.assert_eq(#events1, 0, "0.05s should not emit heal events (accumulator < 1.0)")

    -- Another 0.05s should emit (1.0 HP accumulated)
    local events2 = specials_system.process_healer_regen(0.05, ctx)
    test.assert_eq(#events2, 2, "Another 0.05s should emit heal events (accumulator >= 1.0)")

    print("✓ Healer accumulator works correctly")
end

function test.test_healer_regen_head_only()
    print("\n=== Test: Healer at Head (One Neighbor) ===")

    local snake_state = make_snake_state({
        make_segment(1, "healer_adjacent_regen", 100),    -- Healer at head
        make_segment(2, nil, 100),                        -- Only right neighbor
        make_segment(3, nil, 100),
    })

    local ctx = { snake_state = snake_state }

    local events = specials_system.process_healer_regen(0.1, ctx)

    -- Should only heal right neighbor (no left at position 0)
    test.assert_eq(#events, 1, "Healer at head should only heal right neighbor")
    test.assert_eq(events[1].target_instance_id, 2, "Should heal segment 2 (right)")

    print("✓ Healer at head only heals right neighbor")
end

function test.test_healer_regen_dead_neighbor()
    print("\n=== Test: Healer With Dead Neighbor ===")

    local snake_state = make_snake_state({
        make_segment(1, nil, 0),                          -- Dead left neighbor
        make_segment(2, "healer_adjacent_regen", 100),    -- Healer
        make_segment(3, nil, 100),                        -- Alive right neighbor
    })

    local ctx = { snake_state = snake_state }

    local events = specials_system.process_healer_regen(0.1, ctx)

    -- Should only heal alive right neighbor
    test.assert_eq(#events, 1, "Should only heal alive neighbors")
    test.assert_eq(events[1].target_instance_id, 3, "Should heal alive right neighbor")

    print("✓ Healer skips dead neighbors")
end

--===========================================================================
-- TEST 2: Knight Block
--===========================================================================

function test.test_knight_block_passive_mod()
    print("\n=== Test: Knight Block Passive Mod ===")

    local snake_state = make_snake_state({
        make_segment(1, nil, 100),
        make_segment(2, "knight_block", 100),
        make_segment(3, nil, 100),
    })

    local passive_mods = specials_system.get_passive_mods(snake_state, {})

    -- Knight should have 0.8 damage_taken_mult (20% reduction)
    test.assert_eq(passive_mods[2].damage_taken_mult, 0.8,
        "Knight should have 20% damage reduction (0.8x)")

    -- Other segments should have no reduction
    test.assert_eq(passive_mods[1].damage_taken_mult, 1.0,
        "Non-knight should have no damage reduction")

    print("✓ Knight block provides 20% damage reduction")
end

function test.test_knight_block_on_damage()
    print("\n=== Test: Knight Block On Damage ===")

    local snake_state = make_snake_state({
        make_segment(1, "knight_block", 100),
    })

    local ctx = { snake_state = snake_state }
    local damage_event = {
        target_instance_id = 1,
        amount_int = 100
    }

    local modified_event, _ = specials_system.on_damage_taken(ctx, damage_event)

    test.assert_eq(modified_event.amount_int, 80, "100 damage should be reduced to 80")
    test.assert_true(modified_event.reduced_by_block, "Should flag damage as reduced by block")

    print("✓ Knight block reduces damage in on_damage_taken")
end

--===========================================================================
-- TEST 3: Sniper Crit
--===========================================================================

function test.test_sniper_crit_success()
    print("\n=== Test: Sniper Crit (Success Roll) ===")

    local ctx = {}
    local attack_event = {
        attacker_special_id = "sniper_crit",
        damage = 50
    }

    -- RNG roll of 0.1 is < 0.2, so crit should trigger
    local rng = create_mock_rng({0.1})

    local modified_event, _ = specials_system.on_attack(ctx, attack_event, rng)

    test.assert_eq(modified_event.damage, 100, "Crit should double damage (50 -> 100)")
    test.assert_true(modified_event.is_critical, "Should flag as critical hit")

    print("✓ Sniper crit doubles damage on successful roll")
end

function test.test_sniper_crit_fail()
    print("\n=== Test: Sniper Crit (Failed Roll) ===")

    local ctx = {}
    local attack_event = {
        attacker_special_id = "sniper_crit",
        damage = 50
    }

    -- RNG roll of 0.5 is >= 0.2, so crit should NOT trigger
    local rng = create_mock_rng({0.5})

    local modified_event, _ = specials_system.on_attack(ctx, attack_event, rng)

    test.assert_eq(modified_event.damage, 50, "No crit should keep original damage")
    test.assert_eq(modified_event.is_critical, nil, "Should not flag as critical")

    print("✓ Sniper crit fails when roll >= 20%")
end

function test.test_sniper_crit_threshold()
    print("\n=== Test: Sniper Crit (Threshold Boundary) ===")

    local ctx = {}
    local attack_event = {
        attacker_special_id = "sniper_crit",
        damage = 50
    }

    -- Test at exactly 0.2 (should NOT crit, since < is strict)
    local rng = create_mock_rng({0.2})
    local modified_event, _ = specials_system.on_attack(ctx, attack_event, rng)

    test.assert_eq(modified_event.damage, 50, "Roll of exactly 0.2 should not crit")

    -- Test at 0.19999 (should crit)
    local rng2 = create_mock_rng({0.19999})
    local modified_event2, _ = specials_system.on_attack(ctx, attack_event, rng2)
    test.assert_eq(modified_event2.damage, 100, "Roll of 0.19999 should crit")

    print("✓ Sniper crit threshold is exactly 20%")
end

--===========================================================================
-- TEST 4: Bard Adjacent Attack Speed
--===========================================================================

function test.test_bard_atkspd_adjacent()
    print("\n=== Test: Bard Adjacent Attack Speed ===")

    local snake_state = make_snake_state({
        make_segment(1, nil, 100),                       -- Left neighbor
        make_segment(2, "bard_adjacent_atkspd", 100),    -- Bard
        make_segment(3, nil, 100),                       -- Right neighbor
    })

    local passive_mods = specials_system.get_passive_mods(snake_state, {})

    -- Adjacent segments should have 1.10x attack speed
    test.assert_near(passive_mods[1].atk_spd_mult, 1.10, 0.001,
        "Left neighbor should have +10% attack speed")
    test.assert_near(passive_mods[3].atk_spd_mult, 1.10, 0.001,
        "Right neighbor should have +10% attack speed")

    -- Bard itself should have normal attack speed
    test.assert_eq(passive_mods[2].atk_spd_mult, 1.0,
        "Bard should not buff self")

    print("✓ Bard buffs adjacent units by +10% attack speed")
end

function test.test_bard_atkspd_stacks()
    print("\n=== Test: Bard Attack Speed Stacks ===")

    local snake_state = make_snake_state({
        make_segment(1, "bard_adjacent_atkspd", 100),    -- Bard
        make_segment(2, nil, 100),                       -- Gets buffed by both bards
        make_segment(3, "bard_adjacent_atkspd", 100),    -- Bard
    })

    local passive_mods = specials_system.get_passive_mods(snake_state, {})

    -- Middle segment should have 1.10 * 1.10 = 1.21x attack speed
    test.assert_near(passive_mods[2].atk_spd_mult, 1.21, 0.001,
        "Two bard buffs should stack multiplicatively (1.10 * 1.10 = 1.21)")

    print("✓ Multiple bard buffs stack multiplicatively")
end

--===========================================================================
-- TEST 5: Berserker Frenzy
--===========================================================================

function test.test_berserker_frenzy_initial()
    print("\n=== Test: Berserker Frenzy (Initial) ===")

    local snake_state = make_snake_state({
        make_segment(1, "berserker_frenzy", 100),
    })

    local passive_mods = specials_system.get_passive_mods(snake_state, {})

    -- With no kills, attack mult should be 1.0
    test.assert_eq(passive_mods[1].atk_mult, 1.0,
        "Berserker with no kills should have 1.0x attack")

    print("✓ Berserker starts with no attack bonus")
end

function test.test_berserker_frenzy_kill_stacks()
    print("\n=== Test: Berserker Frenzy (Kill Stacks) ===")

    local segment = make_segment(1, "berserker_frenzy", 100)
    segment.special_state = { kill_count = 5 }

    local snake_state = make_snake_state({ segment })

    local passive_mods = specials_system.get_passive_mods(snake_state, {})

    -- 5 kills = 5 * 5% = 25% bonus = 1.25x
    test.assert_near(passive_mods[1].atk_mult, 1.25, 0.001,
        "Berserker with 5 kills should have 1.25x attack")

    print("✓ Berserker frenzy grants +5% attack per kill")
end

function test.test_berserker_frenzy_on_enemy_death()
    print("\n=== Test: Berserker Frenzy On Enemy Death ===")

    local segment = make_segment(1, "berserker_frenzy", 100)
    segment.special_state = { kill_count = 0 }

    local snake_state = make_snake_state({ segment })
    local ctx = { snake_state = snake_state }

    -- Trigger enemy death
    specials_system.on_enemy_death(ctx, { enemy_id = 100 })

    test.assert_eq(segment.special_state.kill_count, 1,
        "Berserker kill count should increment on enemy death")

    -- Another death
    specials_system.on_enemy_death(ctx, { enemy_id = 101 })

    test.assert_eq(segment.special_state.kill_count, 2,
        "Kill count should increment again")

    print("✓ Berserker frenzy tracks kills correctly")
end

--===========================================================================
-- TEST 6: Paladin Divine Shield
--===========================================================================

function test.test_paladin_shield_first_hit()
    print("\n=== Test: Paladin Divine Shield (First Hit) ===")

    local segment = make_segment(1, "paladin_divine_shield", 100)
    local snake_state = make_snake_state({ segment })

    local ctx = { snake_state = snake_state }
    local damage_event = {
        target_instance_id = 1,
        amount_int = 50
    }

    local modified_event, _ = specials_system.on_damage_taken(ctx, damage_event)

    test.assert_eq(modified_event.amount_int, 0, "First hit should be negated")
    test.assert_true(modified_event.negated_by_shield, "Should flag as negated by shield")
    test.assert_true(segment.special_state.shield_used, "Shield should be marked as used")

    print("✓ Paladin divine shield negates first hit")
end

function test.test_paladin_shield_second_hit()
    print("\n=== Test: Paladin Divine Shield (Second Hit) ===")

    local segment = make_segment(1, "paladin_divine_shield", 100)
    segment.special_state = { shield_used = true }

    local snake_state = make_snake_state({ segment })
    local ctx = { snake_state = snake_state }
    local damage_event = {
        target_instance_id = 1,
        amount_int = 50
    }

    local modified_event, _ = specials_system.on_damage_taken(ctx, damage_event)

    test.assert_eq(modified_event.amount_int, 50, "Second hit should not be negated")
    test.assert_eq(modified_event.negated_by_shield, nil, "Should not flag as negated")

    print("✓ Paladin divine shield only blocks first hit")
end

function test.test_paladin_shield_wave_reset()
    print("\n=== Test: Paladin Divine Shield (Wave Reset) ===")

    local segment = make_segment(1, "paladin_divine_shield", 100)
    segment.special_state = { shield_used = true }

    local snake_state = make_snake_state({ segment })
    local ctx = { snake_state = snake_state }

    -- Trigger wave start
    specials_system.on_wave_start(ctx)

    test.assert_false(segment.special_state.shield_used,
        "Shield should be reset on wave start")

    print("✓ Paladin divine shield resets each wave")
end

function test.test_paladin_shield_zero_damage()
    print("\n=== Test: Paladin Divine Shield (Zero Damage) ===")

    local segment = make_segment(1, "paladin_divine_shield", 100)
    local snake_state = make_snake_state({ segment })

    local ctx = { snake_state = snake_state }
    local damage_event = {
        target_instance_id = 1,
        amount_int = 0  -- Zero damage hit
    }

    local modified_event, _ = specials_system.on_damage_taken(ctx, damage_event)

    -- Shield should NOT be consumed by zero damage
    test.assert_eq(segment.special_state.shield_used, false,
        "Shield should not be used on zero damage")

    print("✓ Paladin divine shield ignores zero damage hits")
end

--===========================================================================
-- RUN ALL TESTS
--===========================================================================

function test.run_all()
    print("================================================================================")
    print("TEST SUITE: Specials System (bd-1fv)")
    print("================================================================================")

    -- Test 1: Healer Adjacent Regen
    test.test_healer_regen_basic()
    test.test_healer_regen_accumulator()
    test.test_healer_regen_head_only()
    test.test_healer_regen_dead_neighbor()

    -- Test 2: Knight Block
    test.test_knight_block_passive_mod()
    test.test_knight_block_on_damage()

    -- Test 3: Sniper Crit
    test.test_sniper_crit_success()
    test.test_sniper_crit_fail()
    test.test_sniper_crit_threshold()

    -- Test 4: Bard Adjacent Attack Speed
    test.test_bard_atkspd_adjacent()
    test.test_bard_atkspd_stacks()

    -- Test 5: Berserker Frenzy
    test.test_berserker_frenzy_initial()
    test.test_berserker_frenzy_kill_stacks()
    test.test_berserker_frenzy_on_enemy_death()

    -- Test 6: Paladin Divine Shield
    test.test_paladin_shield_first_hit()
    test.test_paladin_shield_second_hit()
    test.test_paladin_shield_wave_reset()
    test.test_paladin_shield_zero_damage()

    print("\n================================================================================")
    print(string.format("RESULTS: %d passed, %d failed", test.passed, test.failed))
    print("================================================================================")

    return test.failed == 0
end

-- Execute tests if run directly
if arg and arg[0] and arg[0]:match("test_specials") then
    local success = test.run_all()
    os.exit(success and 0 or 1)
end

return test
