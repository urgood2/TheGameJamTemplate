--[[
================================================================================
MANUAL VERIFICATION: Contact Damage System
================================================================================
Verifies that enemy touching segment deals damage once per 0.5 seconds.

This script tests the exact requirement:
"Verify enemy touching segment deals damage once per 0.5s"

Run with: lua manual_tests/contact_damage_verification.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local contact_collector = require("serpent.contact_collector")

print("================================================================================")
print("MANUAL VERIFICATION: Contact Damage System")
print("================================================================================")
print("Testing requirement: Enemy touching segment deals damage once per 0.5s")
print()

--- Test basic contact damage with 0.5s cooldown
function test_basic_contact_damage()
    print("=== Test 1: Basic Contact Damage (0.5s cooldown) ===")

    local collector_state = contact_collector.create_state(15, 0.5) -- Default values

    -- Register test entities (enemy_id=100, entity_id=500) and (instance_id=200, entity_id=600)
    collector_state = contact_collector.register_enemy(collector_state, 100, 500)
    collector_state = contact_collector.register_unit(collector_state, 200, 600)

    local contact_events = {
        { entity_a = 500, entity_b = 600 } -- Enemy touches segment
    }

    -- Verify damage occurs at t=0
    local state_0, events_0 = contact_collector.process_contacts(collector_state, contact_events, 0.0)
    assert(#events_0 == 1, "Should deal damage on first contact")
    assert(events_0[1].amount_int == 15, "Should deal 15 damage")
    assert(events_0[1].target_instance_id == 200, "Should target correct segment")
    print("✓ t=0.0s: Dealt 15 damage to segment (first contact)")

    -- Verify damage blocked during cooldown
    local state_1, events_1 = contact_collector.process_contacts(state_0, contact_events, 0.25)
    assert(#events_1 == 0, "Should block damage during cooldown")
    print("✓ t=0.25s: Damage blocked (cooldown active)")

    -- Verify damage occurs when cooldown expires
    local state_2, events_2 = contact_collector.process_contacts(state_1, contact_events, 0.5)
    assert(#events_2 == 1, "Should deal damage when cooldown expires")
    assert(events_2[1].amount_int == 15, "Should deal same damage")
    print("✓ t=0.5s: Dealt 15 damage to segment (cooldown expired)")

    -- Verify continued blocking
    local state_3, events_3 = contact_collector.process_contacts(state_2, contact_events, 0.75)
    assert(#events_3 == 0, "Should block damage after new cooldown starts")
    print("✓ t=0.75s: Damage blocked (new cooldown active)")

    -- Verify next damage cycle
    local state_4, events_4 = contact_collector.process_contacts(state_3, contact_events, 1.0)
    assert(#events_4 == 1, "Should deal damage at next cooldown expiry")
    print("✓ t=1.0s: Dealt 15 damage to segment (next cycle)")

    print("✓ Basic contact damage test PASSED")
    print()
end

--- Test precise cooldown timing
function test_precise_cooldown_timing()
    print("=== Test 2: Precise Cooldown Timing ===")

    local collector_state = contact_collector.create_state(10, 0.5)
    collector_state = contact_collector.register_enemy(collector_state, 101, 501)
    collector_state = contact_collector.register_unit(collector_state, 201, 601)

    local contact_events = {{ entity_a = 501, entity_b = 601 }}

    -- Test various timings around the 0.5s boundary
    local test_cases = {
        {time = 0.0,   expected_damage = true,  desc = "Initial contact"},
        {time = 0.1,   expected_damage = false, desc = "0.1s after - blocked"},
        {time = 0.49,  expected_damage = false, desc = "0.49s after - blocked"},
        {time = 0.499, expected_damage = false, desc = "0.499s after - blocked"},
        {time = 0.5,   expected_damage = true,  desc = "Exactly 0.5s - allowed"},
        {time = 0.501, expected_damage = false, desc = "0.501s from new baseline - blocked"},
        {time = 1.0,   expected_damage = true,  desc = "1.0s from new baseline - allowed"},
    }

    local current_state = collector_state

    for _, case in ipairs(test_cases) do
        local updated_state, events = contact_collector.process_contacts(current_state, contact_events, case.time)
        local has_damage = #events > 0

        assert(has_damage == case.expected_damage,
               string.format("Expected %s damage at t=%.3fs, got %s",
                           case.expected_damage and "damage" or "no",
                           case.time,
                           has_damage and "damage" or "no damage"))

        print(string.format("✓ t=%.3fs: %s (%s)", case.time,
                          has_damage and "Damage dealt" or "No damage", case.desc))

        current_state = updated_state
    end

    print("✓ Precise cooldown timing test PASSED")
    print()
end

--- Test multiple enemy contacts
function test_multiple_enemy_contacts()
    print("=== Test 3: Multiple Enemy Contacts ===")

    local collector_state = contact_collector.create_state(8, 0.5)

    -- Register multiple enemies and one segment
    collector_state = contact_collector.register_enemy(collector_state, 102, 502) -- Enemy A
    collector_state = contact_collector.register_enemy(collector_state, 103, 503) -- Enemy B
    collector_state = contact_collector.register_unit(collector_state, 202, 602)   -- Segment

    -- Both enemies touch the same segment
    local contact_events = {
        { entity_a = 502, entity_b = 602 }, -- Enemy A touches segment
        { entity_a = 503, entity_b = 602 }  -- Enemy B touches segment
    }

    -- Both should deal damage initially (separate cooldowns)
    local state_0, events_0 = contact_collector.process_contacts(collector_state, contact_events, 0.0)
    assert(#events_0 == 2, "Should deal damage from both enemies")
    print("✓ t=0.0s: Both enemies deal damage simultaneously (separate cooldowns)")

    -- Both should be blocked during cooldown
    local state_1, events_1 = contact_collector.process_contacts(state_0, contact_events, 0.25)
    assert(#events_1 == 0, "Should block damage from both enemies")
    print("✓ t=0.25s: Both enemies blocked during cooldown")

    -- Both should deal damage when cooldown expires
    local state_2, events_2 = contact_collector.process_contacts(state_1, contact_events, 0.5)
    assert(#events_2 == 2, "Should deal damage from both enemies after cooldown")
    print("✓ t=0.5s: Both enemies deal damage after cooldown expires")

    print("✓ Multiple enemy contacts test PASSED")
    print()
end

--- Test segment vs enemy cooldown isolation
function test_cooldown_isolation()
    print("=== Test 4: Cooldown Isolation Between Entity Pairs ===")

    local collector_state = contact_collector.create_state(12, 0.5)

    -- Register one enemy and two segments
    collector_state = contact_collector.register_enemy(collector_state, 104, 504) -- Enemy
    collector_state = contact_collector.register_unit(collector_state, 203, 603)   -- Segment A
    collector_state = contact_collector.register_unit(collector_state, 204, 604)   -- Segment B

    -- Enemy touches first segment at t=0
    local contact_a = {{ entity_a = 504, entity_b = 603 }}
    local state_0, events_0 = contact_collector.process_contacts(collector_state, contact_a, 0.0)
    assert(#events_0 == 1, "Should damage first segment")
    print("✓ t=0.0s: Enemy damages Segment A")

    -- Enemy touches second segment at t=0.25 (should work - different pair)
    local contact_b = {{ entity_a = 504, entity_b = 604 }}
    local state_1, events_1 = contact_collector.process_contacts(state_0, contact_b, 0.25)
    assert(#events_1 == 1, "Should damage second segment (different cooldown)")
    print("✓ t=0.25s: Enemy damages Segment B (separate cooldown)")

    -- Enemy touches first segment again at t=0.25 (should be blocked)
    local state_2, events_2 = contact_collector.process_contacts(state_1, contact_a, 0.25)
    assert(#events_2 == 0, "Should block first segment (cooldown active)")
    print("✓ t=0.25s: Enemy vs Segment A blocked (cooldown active)")

    print("✓ Cooldown isolation test PASSED")
    print()
end

--- Test edge cases and error handling
function test_edge_cases()
    print("=== Test 5: Edge Cases ===")

    local collector_state = contact_collector.create_state(5, 0.5)

    -- Test with no entities registered
    local empty_events = {}
    local state_0, events_0 = contact_collector.process_contacts(collector_state, empty_events, 0.0)
    assert(#events_0 == 0, "Should handle empty contact events")
    print("✓ Empty contact events handled correctly")

    -- Test with invalid contact events
    collector_state = contact_collector.register_enemy(collector_state, 105, 505)
    collector_state = contact_collector.register_unit(collector_state, 205, 605)

    local invalid_events = {
        { entity_a = 999, entity_b = 605 }, -- Unknown enemy entity
        { entity_a = 505, entity_b = 999 }, -- Unknown unit entity
        { entity_a = 505, entity_b = 505 }, -- Same entity (should be ignored)
    }

    local state_1, events_1 = contact_collector.process_contacts(collector_state, invalid_events, 0.0)
    assert(#events_1 == 0, "Should ignore invalid contact events")
    print("✓ Invalid contact events ignored correctly")

    -- Test zero cooldown (should always allow damage)
    local zero_cooldown_state = contact_collector.create_state(3, 0.0) -- 0 second cooldown
    zero_cooldown_state = contact_collector.register_enemy(zero_cooldown_state, 106, 506)
    zero_cooldown_state = contact_collector.register_unit(zero_cooldown_state, 206, 606)

    local rapid_events = {{ entity_a = 506, entity_b = 606 }}

    local state_z1, events_z1 = contact_collector.process_contacts(zero_cooldown_state, rapid_events, 0.0)
    assert(#events_z1 == 1, "Should deal damage with zero cooldown")

    local state_z2, events_z2 = contact_collector.process_contacts(state_z1, rapid_events, 0.001)
    assert(#events_z2 == 1, "Should deal damage again immediately with zero cooldown")
    print("✓ Zero cooldown behavior works correctly")

    print("✓ Edge cases test PASSED")
    print()
end

--- Test integration with actual constants
function test_default_constants()
    print("=== Test 6: Default Constants Verification ===")

    -- Test that default values match specification
    local default_state = contact_collector.create_state()
    assert(default_state.cooldown_sec == 0.5, "Default cooldown should be 0.5 seconds")
    assert(default_state.contact_damage == 15, "Default damage should be 15")
    print("✓ Default cooldown: 0.5 seconds")
    print("✓ Default damage: 15")

    -- Test that custom values work
    local custom_state = contact_collector.create_state(25, 1.0)
    assert(custom_state.cooldown_sec == 1.0, "Custom cooldown should work")
    assert(custom_state.contact_damage == 25, "Custom damage should work")
    print("✓ Custom cooldown: 1.0 seconds")
    print("✓ Custom damage: 25")

    print("✓ Default constants verification PASSED")
    print()
end

--- Main verification runner
function run_verification()
    print("Running comprehensive contact damage verification...")
    print()

    -- Run all verification tests
    test_basic_contact_damage()
    test_precise_cooldown_timing()
    test_multiple_enemy_contacts()
    test_cooldown_isolation()
    test_edge_cases()
    test_default_constants()

    print("================================================================================")
    print("VERIFICATION RESULTS")
    print("================================================================================")
    print("✅ MANUAL VERIFICATION PASSED")
    print()
    print("✓ Enemy touching segment deals damage once per 0.5 seconds")
    print("✓ Cooldown system prevents damage spam")
    print("✓ Multiple entities have independent cooldowns")
    print("✓ Precise timing works as expected")
    print("✓ Edge cases handled gracefully")
    print("✓ Default constants match specification")
    print()
    print("The contact damage system works exactly as specified:")
    print("- Initial contact deals damage immediately")
    print("- Subsequent contacts are blocked for 0.5 seconds")
    print("- Damage resumes exactly when cooldown expires")
    print("- Each enemy-segment pair has independent cooldowns")
    print()
    print("✅ REQUIREMENT VERIFIED: Contact damage works correctly")

    return true
end

-- Run the verification
local success = run_verification()
os.exit(success and 0 or 1)