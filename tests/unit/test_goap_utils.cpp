#include <gtest/gtest.h>

#include "components/components.hpp"

class GOAPUtilsTest : public ::testing::Test {
protected:
    actionplanner_t ap{};

    void SetUp() override {
        goap_actionplanner_clear(&ap);
        // Register some atoms for testing
        // goap_set_pre registers atoms implicitly
        goap_set_pre(&ap, "test_action", "hungry", true);
        goap_set_pre(&ap, "test_action", "tired", true);
        goap_set_pre(&ap, "test_action", "has_weapon", true);
    }
};

// =============================================================================
// mask_from_names tests
// =============================================================================

TEST_F(GOAPUtilsTest, MaskFromNamesEmptyList) {
    std::vector<std::string> names;
    bfield_t mask = mask_from_names(ap, names);
    EXPECT_EQ(mask, 0);
}

TEST_F(GOAPUtilsTest, MaskFromNamesSingleAtom) {
    std::vector<std::string> names = {"hungry"};
    bfield_t mask = mask_from_names(ap, names);
    
    // Should have exactly one bit set
    EXPECT_NE(mask, 0);
    // Check it's a power of 2 (single bit)
    EXPECT_EQ(mask & (mask - 1), 0);
}

TEST_F(GOAPUtilsTest, MaskFromNamesMultipleAtoms) {
    std::vector<std::string> names = {"hungry", "tired"};
    bfield_t mask = mask_from_names(ap, names);
    
    // Should have exactly two bits set
    EXPECT_NE(mask, 0);
    
    // Count bits - should be 2
    int bitCount = 0;
    bfield_t temp = mask;
    while (temp) {
        bitCount += temp & 1;
        temp >>= 1;
    }
    EXPECT_EQ(bitCount, 2);
}

TEST_F(GOAPUtilsTest, MaskFromNamesUnknownAtomIgnored) {
    std::vector<std::string> names = {"hungry", "nonexistent_atom", "tired"};
    bfield_t mask = mask_from_names(ap, names);
    
    // Should only have bits for known atoms (hungry, tired)
    std::vector<std::string> knownNames = {"hungry", "tired"};
    bfield_t expectedMask = mask_from_names(ap, knownNames);
    
    EXPECT_EQ(mask, expectedMask);
}

TEST_F(GOAPUtilsTest, MaskFromNamesAllAtoms) {
    std::vector<std::string> names = {"hungry", "tired", "has_weapon"};
    bfield_t mask = mask_from_names(ap, names);
    
    // Count bits - should be 3 (all registered atoms)
    int bitCount = 0;
    bfield_t temp = mask;
    while (temp) {
        bitCount += temp & 1;
        temp >>= 1;
    }
    EXPECT_EQ(bitCount, 3);
}

// =============================================================================
// build_watch_mask tests
// These tests require sol::table, so we need Lua state
// =============================================================================

class GOAPWatchMaskTest : public ::testing::Test {
protected:
    actionplanner_t ap{};
    sol::state lua;

    void SetUp() override {
        goap_actionplanner_clear(&ap);
        // Register atoms
        goap_set_pre(&ap, "test_action", "hungry", true);
        goap_set_pre(&ap, "test_action", "tired", true);
        goap_set_pre(&ap, "test_action", "has_weapon", true);
        goap_set_pre(&ap, "test_action", "near_enemy", true);
        
        lua.open_libraries(sol::lib::base, sol::lib::table);
    }
};

TEST_F(GOAPWatchMaskTest, BuildWatchMaskWildcardReturnsAllBits) {
    // Create action table with watch = "*"
    lua.script(R"(
        action = {
            watch = "*"
        }
    )");
    
    sol::table actionTbl = lua["action"];
    bfield_t mask = build_watch_mask(ap, actionTbl);
    
    // Should return mask covering all atoms (numatoms = 4)
    // All bits from 0 to numatoms-1 should be set
    bfield_t expected = (1ULL << ap.numatoms) - 1ULL;
    EXPECT_EQ(mask, expected);
}

TEST_F(GOAPWatchMaskTest, BuildWatchMaskExplicitTableReturnsCorrectBits) {
    // Create action table with explicit watch list
    lua.script(R"(
        action = {
            watch = { "hungry", "tired" }
        }
    )");
    
    sol::table actionTbl = lua["action"];
    bfield_t mask = build_watch_mask(ap, actionTbl);
    
    // Should match mask_from_names for the same atoms
    std::vector<std::string> expected = {"hungry", "tired"};
    bfield_t expectedMask = mask_from_names(ap, expected);
    
    EXPECT_EQ(mask, expectedMask);
}

TEST_F(GOAPWatchMaskTest, BuildWatchMaskAutoWatchPreconditions) {
    // Create action table with no 'watch' but with 'pre' conditions
    lua.script(R"(
        action = {
            pre = {
                hungry = true,
                has_weapon = true
            }
        }
    )");
    
    sol::table actionTbl = lua["action"];
    bfield_t mask = build_watch_mask(ap, actionTbl);
    
    // Should auto-watch the precondition keys
    std::vector<std::string> expected = {"hungry", "has_weapon"};
    bfield_t expectedMask = mask_from_names(ap, expected);
    
    EXPECT_EQ(mask, expectedMask);
}

TEST_F(GOAPWatchMaskTest, BuildWatchMaskEmptyTableReturnsZero) {
    // Create empty action table - no watch, no pre
    lua.script(R"(
        action = {}
    )");
    
    sol::table actionTbl = lua["action"];
    bfield_t mask = build_watch_mask(ap, actionTbl);
    
    EXPECT_EQ(mask, 0);
}

TEST_F(GOAPWatchMaskTest, BuildWatchMaskExplicitOverridesPre) {
    // Create action table with both watch and pre
    // watch should take precedence
    lua.script(R"(
        action = {
            watch = { "tired" },
            pre = {
                hungry = true,
                has_weapon = true
            }
        }
    )");
    
    sol::table actionTbl = lua["action"];
    bfield_t mask = build_watch_mask(ap, actionTbl);
    
    // Should use explicit watch, not pre
    std::vector<std::string> expected = {"tired"};
    bfield_t expectedMask = mask_from_names(ap, expected);
    
    EXPECT_EQ(mask, expectedMask);
}

TEST_F(GOAPWatchMaskTest, BuildWatchMaskIgnoresUnknownAtomsInWatch) {
    lua.script(R"(
        action = {
            watch = { "hungry", "unknown_atom", "tired" }
        }
    )");

    sol::table actionTbl = lua["action"];
    bfield_t mask = build_watch_mask(ap, actionTbl);

    // Should only include known atoms
    std::vector<std::string> expected = {"hungry", "tired"};
    bfield_t expectedMask = mask_from_names(ap, expected);

    EXPECT_EQ(mask, expectedMask);
}

// =============================================================================
// Reactive replan diff tests (Phase 0.1)
// These test the compute_replan_changed_bits function that should only
// detect changes from world state updaters, not from action postconditions
// =============================================================================

class GOAPReplanDiffTest : public ::testing::Test {
protected:
    actionplanner_t ap;

    void SetUp() override {
        goap_actionplanner_clear(&ap);
        // Register atoms: hungry, tired, has_gold, near_enemy
        goap_set_pre(&ap, "test_action", "hungry", true);
        goap_set_pre(&ap, "test_action", "tired", true);
        goap_set_pre(&ap, "test_action", "has_gold", true);
        goap_set_pre(&ap, "test_action", "near_enemy", true);
    }

    // Helper to get atom index
    int getAtomIndex(const char* name) {
        for (int i = 0; i < ap.numatoms; ++i) {
            if (ap.atm_names[i] && strcmp(ap.atm_names[i], name) == 0) {
                return i;
            }
        }
        return -1;
    }

    // Helper to set atom value
    void setAtom(worldstate_t& ws, const char* name, bool value) {
        int idx = getAtomIndex(name);
        if (idx >= 0) {
            ws.dontcare &= ~(1LL << idx);  // Clear dontcare bit
            if (value) {
                ws.values |= (1LL << idx);
            } else {
                ws.values &= ~(1LL << idx);
            }
        }
    }
};

TEST_F(GOAPReplanDiffTest, NoChangeWhenStatesIdentical) {
    worldstate_t state_after_action = {};
    worldstate_t current_state = {};
    worldstate_t cached_state = {};

    // All states are identical
    setAtom(state_after_action, "hungry", true);
    setAtom(current_state, "hungry", true);
    setAtom(cached_state, "hungry", true);

    // compute_replan_changed_bits should return 0 - no changes from updaters
    bfield_t changed = ai::compute_replan_changed_bits(
        state_after_action, current_state, cached_state);

    EXPECT_EQ(changed, 0);
}

TEST_F(GOAPReplanDiffTest, IgnoresChangesFromActionPostconditions) {
    worldstate_t state_after_action = {};
    worldstate_t current_state = {};
    worldstate_t cached_state = {};

    // Initial state: hungry=false
    setAtom(cached_state, "hungry", false);

    // Action postcondition set hungry=true
    setAtom(state_after_action, "hungry", true);

    // Current state matches state_after_action (no updater changes)
    setAtom(current_state, "hungry", true);

    // Should return 0 because the change was from action, not updater
    bfield_t changed = ai::compute_replan_changed_bits(
        state_after_action, current_state, cached_state);

    EXPECT_EQ(changed, 0);
}

TEST_F(GOAPReplanDiffTest, DetectsChangesFromWorldStateUpdaters) {
    worldstate_t state_after_action = {};
    worldstate_t current_state = {};
    worldstate_t cached_state = {};

    // Initial state: near_enemy=false
    setAtom(cached_state, "near_enemy", false);

    // State after action: still near_enemy=false (action didn't change it)
    setAtom(state_after_action, "near_enemy", false);

    // Updater detected enemy: near_enemy=true
    setAtom(current_state, "near_enemy", true);

    // Should detect the change from updater
    bfield_t changed = ai::compute_replan_changed_bits(
        state_after_action, current_state, cached_state);

    int nearEnemyIdx = getAtomIndex("near_enemy");
    EXPECT_NE(changed & (1LL << nearEnemyIdx), 0);
}

TEST_F(GOAPReplanDiffTest, IgnoresDontCareBits) {
    worldstate_t state_after_action = {};
    worldstate_t current_state = {};
    worldstate_t cached_state = {};

    // Set tired to dontcare in current state
    int tiredIdx = getAtomIndex("tired");
    current_state.dontcare |= (1LL << tiredIdx);

    // Set different values that would normally trigger change
    setAtom(state_after_action, "tired", false);
    setAtom(cached_state, "tired", false);
    // current_state has tired as dontcare, even if value differs

    bfield_t changed = ai::compute_replan_changed_bits(
        state_after_action, current_state, cached_state);

    // Should not detect change on dontcare bit
    EXPECT_EQ(changed & (1LL << tiredIdx), 0);
}

TEST_F(GOAPReplanDiffTest, CombinedScenario) {
    worldstate_t state_after_action = {};
    worldstate_t current_state = {};
    worldstate_t cached_state = {};

    // Setup cached state
    setAtom(cached_state, "hungry", true);
    setAtom(cached_state, "has_gold", false);
    setAtom(cached_state, "near_enemy", false);

    // Action postcondition: has_gold=true (mined gold)
    setAtom(state_after_action, "hungry", true);
    setAtom(state_after_action, "has_gold", true);  // Changed by action
    setAtom(state_after_action, "near_enemy", false);

    // Current state after updaters:
    // - has_gold=true (from action - should be ignored)
    // - near_enemy=true (from updater - should be detected)
    setAtom(current_state, "hungry", true);
    setAtom(current_state, "has_gold", true);
    setAtom(current_state, "near_enemy", true);  // Changed by updater

    bfield_t changed = ai::compute_replan_changed_bits(
        state_after_action, current_state, cached_state);

    int hasGoldIdx = getAtomIndex("has_gold");
    int nearEnemyIdx = getAtomIndex("near_enemy");

    // has_gold change should NOT be detected (action postcondition)
    EXPECT_EQ(changed & (1LL << hasGoldIdx), 0);

    // near_enemy change SHOULD be detected (updater change)
    EXPECT_NE(changed & (1LL << nearEnemyIdx), 0);
}

// =============================================================================
// Plan drift detection tests (Phase 0.2)
// These test the compute_plan_drift function that detects if the current state
// has drifted significantly from when the plan was created
// =============================================================================

class GOAPPlanDriftTest : public ::testing::Test {
protected:
    actionplanner_t ap;

    void SetUp() override {
        goap_actionplanner_clear(&ap);
        // Register atoms
        goap_set_pre(&ap, "test_action", "hungry", true);
        goap_set_pre(&ap, "test_action", "tired", true);
        goap_set_pre(&ap, "test_action", "has_gold", true);
        goap_set_pre(&ap, "test_action", "near_enemy", true);
    }

    int getAtomIndex(const char* name) {
        for (int i = 0; i < ap.numatoms; ++i) {
            if (ap.atm_names[i] && strcmp(ap.atm_names[i], name) == 0) {
                return i;
            }
        }
        return -1;
    }

    void setAtom(worldstate_t& ws, const char* name, bool value) {
        int idx = getAtomIndex(name);
        if (idx >= 0) {
            ws.dontcare &= ~(1LL << idx);
            if (value) {
                ws.values |= (1LL << idx);
            } else {
                ws.values &= ~(1LL << idx);
            }
        }
    }
};

TEST_F(GOAPPlanDriftTest, NoDriftWhenStatesIdentical) {
    worldstate_t plan_start_state = {};
    worldstate_t current_state = {};

    setAtom(plan_start_state, "hungry", true);
    setAtom(plan_start_state, "has_gold", false);

    setAtom(current_state, "hungry", true);
    setAtom(current_state, "has_gold", false);

    bfield_t drift = ai::compute_plan_drift(plan_start_state, current_state);
    EXPECT_EQ(drift, 0);
}

TEST_F(GOAPPlanDriftTest, DetectsDriftFromPlanStart) {
    worldstate_t plan_start_state = {};
    worldstate_t current_state = {};

    // Plan was created when not hungry
    setAtom(plan_start_state, "hungry", false);
    setAtom(plan_start_state, "has_gold", false);

    // Now we're hungry - significant drift
    setAtom(current_state, "hungry", true);
    setAtom(current_state, "has_gold", false);

    bfield_t drift = ai::compute_plan_drift(plan_start_state, current_state);

    int hungryIdx = getAtomIndex("hungry");
    EXPECT_NE(drift & (1LL << hungryIdx), 0);
}

TEST_F(GOAPPlanDriftTest, IgnoresDontCareBits) {
    worldstate_t plan_start_state = {};
    worldstate_t current_state = {};

    setAtom(plan_start_state, "hungry", true);

    // Current state has tired as dontcare
    int tiredIdx = getAtomIndex("tired");
    current_state.dontcare |= (1LL << tiredIdx);
    setAtom(current_state, "hungry", true);

    bfield_t drift = ai::compute_plan_drift(plan_start_state, current_state);

    // Tired shouldn't be detected as drift
    EXPECT_EQ(drift & (1LL << tiredIdx), 0);
}

TEST_F(GOAPPlanDriftTest, MultipleDriftBits) {
    worldstate_t plan_start_state = {};
    worldstate_t current_state = {};

    // Plan start: peaceful, no gold
    setAtom(plan_start_state, "hungry", false);
    setAtom(plan_start_state, "near_enemy", false);
    setAtom(plan_start_state, "has_gold", false);

    // Current: hungry and enemy nearby (two drifts)
    setAtom(current_state, "hungry", true);
    setAtom(current_state, "near_enemy", true);
    setAtom(current_state, "has_gold", false);  // Same as plan start

    bfield_t drift = ai::compute_plan_drift(plan_start_state, current_state);

    int hungryIdx = getAtomIndex("hungry");
    int nearEnemyIdx = getAtomIndex("near_enemy");
    int hasGoldIdx = getAtomIndex("has_gold");

    EXPECT_NE(drift & (1LL << hungryIdx), 0);
    EXPECT_NE(drift & (1LL << nearEnemyIdx), 0);
    EXPECT_EQ(drift & (1LL << hasGoldIdx), 0);  // No drift here
}

// =============================================================================
// Atom count validation tests (Phase 0.3)
// These test that atom counts are validated to prevent undefined behavior
// with signed bitfield shifts
// =============================================================================

class GOAPAtomCapTest : public ::testing::Test {
protected:
    actionplanner_t ap;

    void SetUp() override {
        goap_actionplanner_clear(&ap);
    }
};

TEST_F(GOAPAtomCapTest, ValidAtomCountReturnsTrue) {
    // Register a small number of atoms
    goap_set_pre(&ap, "action1", "atom1", true);
    goap_set_pre(&ap, "action1", "atom2", true);

    EXPECT_TRUE(ai::validate_atom_count(ap));
    EXPECT_EQ(ai::get_safe_atom_cap(), 62);  // Max safe atoms for signed int64
}

TEST_F(GOAPAtomCapTest, AtomCountAtCapReturnsTrue) {
    // Manually set numatoms to the cap (62)
    ap.numatoms = 62;
    EXPECT_TRUE(ai::validate_atom_count(ap));
}

TEST_F(GOAPAtomCapTest, AtomCountOverCapReturnsFalse) {
    // Manually set numatoms over the cap
    ap.numatoms = 63;
    EXPECT_FALSE(ai::validate_atom_count(ap));
}

TEST_F(GOAPAtomCapTest, AtomCountAt64ReturnsFalse) {
    // Maximum atom count (MAXATOMS) should fail
    ap.numatoms = 64;
    EXPECT_FALSE(ai::validate_atom_count(ap));
}

TEST_F(GOAPAtomCapTest, ZeroAtomCountReturnsTrue) {
    // Edge case: zero atoms is valid
    EXPECT_TRUE(ai::validate_atom_count(ap));
}

// =============================================================================
// Schema versioning tests (Phase 0.4)
// These test the version tracking for actionset and atom schemas
// =============================================================================

// Note: GOAPComponent has sol::table members that require Lua state
// We test the version logic separately using simple struct to verify the concept

namespace {
struct VersionedSchema {
    uint32_t actionset_version = 0;
    uint32_t atom_schema_version = 0;
};
}

TEST(GOAPVersioningTest, DefaultVersionsAreZero) {
    VersionedSchema schema;
    EXPECT_EQ(schema.actionset_version, 0u);
    EXPECT_EQ(schema.atom_schema_version, 0u);
}

TEST(GOAPVersioningTest, VersionsCanBeIncremented) {
    VersionedSchema schema;

    schema.actionset_version++;
    schema.atom_schema_version++;

    EXPECT_EQ(schema.actionset_version, 1u);
    EXPECT_EQ(schema.atom_schema_version, 1u);
}

TEST(GOAPVersioningTest, VersionsTrackIndependently) {
    VersionedSchema schema;

    schema.actionset_version = 5;
    schema.atom_schema_version = 10;

    EXPECT_EQ(schema.actionset_version, 5u);
    EXPECT_EQ(schema.atom_schema_version, 10u);
}

TEST(GOAPVersioningTest, VersionMatchingForCacheKey) {
    VersionedSchema schema1;
    VersionedSchema schema2;

    // Same versions should match
    EXPECT_TRUE(schema1.actionset_version == schema2.actionset_version);
    EXPECT_TRUE(schema1.atom_schema_version == schema2.atom_schema_version);

    // After incrementing one, they shouldn't match
    schema1.actionset_version++;
    EXPECT_FALSE(schema1.actionset_version == schema2.actionset_version);

    // But atom schema should still match
    EXPECT_TRUE(schema1.atom_schema_version == schema2.atom_schema_version);
}

// =============================================================================
// Version increment transactional behavior tests (Code Review Fix)
// These test that versions should only increment on full success
// =============================================================================

namespace {
// Mock structure for atom count testing (avoids uninitialized actionplanner_t issues)
struct MockAtomHolder {
    int numatoms = 0;
};

// Adapter to make MockAtomHolder work with validate_atom_count pattern
bool mock_validate_atom_count(const MockAtomHolder& holder) {
    return holder.numatoms <= ai::get_safe_atom_cap();
}

// Simulates the transactional loading behavior:
// Returns true only if both validation passes AND loading completes
bool simulate_load_with_validation(VersionedSchema& schema,
                                    MockAtomHolder& holder,
                                    int atoms_to_add,
                                    bool throw_exception) {
    try {
        // Simulate adding atoms
        holder.numatoms = atoms_to_add;

        // Simulate exception during loading
        if (throw_exception) {
            throw std::runtime_error("Simulated load failure");
        }

        // Validate atom count - early return on failure
        if (!mock_validate_atom_count(holder)) {
            return false;  // Don't increment version
        }

        // Only increment on complete success
        schema.actionset_version++;
        return true;
    } catch (...) {
        // Exception occurred - version should NOT have been incremented
        // (version increment is at the END of try block)
        return false;
    }
}
}

TEST(GOAPVersioningTransactionalTest, VersionIncrementOnlyOnSuccess) {
    VersionedSchema schema;
    MockAtomHolder holder;

    EXPECT_EQ(schema.actionset_version, 0u);

    // Successful load with valid atom count
    bool success = simulate_load_with_validation(schema, holder, 10, false);

    EXPECT_TRUE(success);
    EXPECT_EQ(schema.actionset_version, 1u);
}

TEST(GOAPVersioningTransactionalTest, VersionNotIncrementedOnValidationFailure) {
    VersionedSchema schema;
    MockAtomHolder holder;

    EXPECT_EQ(schema.actionset_version, 0u);

    // Load with invalid atom count (63 > 62 cap)
    bool success = simulate_load_with_validation(schema, holder, 63, false);

    EXPECT_FALSE(success);
    EXPECT_EQ(schema.actionset_version, 0u);  // Version should NOT have incremented
}

TEST(GOAPVersioningTransactionalTest, VersionNotIncrementedOnException) {
    VersionedSchema schema;
    MockAtomHolder holder;

    EXPECT_EQ(schema.actionset_version, 0u);

    // Load that throws exception
    bool success = simulate_load_with_validation(schema, holder, 10, true);

    EXPECT_FALSE(success);
    EXPECT_EQ(schema.actionset_version, 0u);  // Version should NOT have incremented
}

TEST(GOAPVersioningTransactionalTest, MultipleSuccessfulLoadsIncrementVersion) {
    VersionedSchema schema;
    MockAtomHolder holder;

    // Three successful loads
    simulate_load_with_validation(schema, holder, 10, false);
    simulate_load_with_validation(schema, holder, 20, false);
    simulate_load_with_validation(schema, holder, 30, false);

    EXPECT_EQ(schema.actionset_version, 3u);
}

TEST(GOAPVersioningTransactionalTest, FailedLoadBetweenSuccessfulLoads) {
    VersionedSchema schema;
    MockAtomHolder holder;

    // First successful load
    simulate_load_with_validation(schema, holder, 10, false);
    EXPECT_EQ(schema.actionset_version, 1u);

    // Failed load (atom count too high)
    simulate_load_with_validation(schema, holder, 63, false);
    EXPECT_EQ(schema.actionset_version, 1u);  // Still 1

    // Another successful load
    simulate_load_with_validation(schema, holder, 20, false);
    EXPECT_EQ(schema.actionset_version, 2u);
}

// =============================================================================
// replan_to_goal utility tests (Phase 0.5)
// These test the goal state merging utilities that support replan_to_goal
// =============================================================================

class GOAPReplanToGoalTest : public ::testing::Test {
protected:
    actionplanner_t ap;

    void SetUp() override {
        goap_actionplanner_clear(&ap);
        // Register atoms
        goap_set_pre(&ap, "test_action", "hungry", true);
        goap_set_pre(&ap, "test_action", "tired", true);
        goap_set_pre(&ap, "test_action", "has_gold", true);
        goap_set_pre(&ap, "test_action", "near_enemy", true);
    }

    int getAtomIndex(const char* name) {
        for (int i = 0; i < ap.numatoms; ++i) {
            if (ap.atm_names[i] && strcmp(ap.atm_names[i], name) == 0) {
                return i;
            }
        }
        return -1;
    }

    void setAtom(worldstate_t& ws, const char* name, bool value) {
        int idx = getAtomIndex(name);
        if (idx >= 0) {
            ws.dontcare &= ~(1LL << idx);
            if (value) {
                ws.values |= (1LL << idx);
            } else {
                ws.values &= ~(1LL << idx);
            }
        }
    }

    bool getAtomValue(const worldstate_t& ws, const char* name) {
        int idx = getAtomIndex(name);
        if (idx >= 0) {
            return (ws.values & (1LL << idx)) != 0;
        }
        return false;
    }

    bool isAtomDontCare(const worldstate_t& ws, const char* name) {
        int idx = getAtomIndex(name);
        if (idx >= 0) {
            return (ws.dontcare & (1LL << idx)) != 0;
        }
        return true;
    }
};

TEST_F(GOAPReplanToGoalTest, MergeGoalOverridesSpecifiedAtoms) {
    worldstate_t current_goal;
    worldstate_t explicit_goal;
    goap_worldstate_clear(&current_goal);
    goap_worldstate_clear(&explicit_goal);

    // Current goal: hungry=false
    setAtom(current_goal, "hungry", false);

    // Explicit goal: has_gold=true (override with new goal)
    setAtom(explicit_goal, "has_gold", true);

    worldstate_t merged = ai::merge_goal_state(current_goal, explicit_goal);

    // Merged should have both goals
    EXPECT_FALSE(getAtomValue(merged, "hungry"));  // From current
    EXPECT_TRUE(getAtomValue(merged, "has_gold")); // From explicit
}

TEST_F(GOAPReplanToGoalTest, ExplicitGoalOverridesCurrentGoal) {
    worldstate_t current_goal;
    worldstate_t explicit_goal;
    goap_worldstate_clear(&current_goal);
    goap_worldstate_clear(&explicit_goal);

    // Current goal: hungry=false
    setAtom(current_goal, "hungry", false);

    // Explicit goal: hungry=true (override)
    setAtom(explicit_goal, "hungry", true);

    worldstate_t merged = ai::merge_goal_state(current_goal, explicit_goal);

    // Explicit goal takes precedence
    EXPECT_TRUE(getAtomValue(merged, "hungry"));
}

TEST_F(GOAPReplanToGoalTest, DontCareAtomsNotOverridden) {
    worldstate_t current_goal;
    worldstate_t explicit_goal;
    goap_worldstate_clear(&current_goal);   // All atoms start as dontcare
    goap_worldstate_clear(&explicit_goal);

    // Current goal: hungry=false (clears dontcare for hungry)
    // tired remains dontcare since we never set it
    setAtom(current_goal, "hungry", false);

    // Explicit goal: only has_gold specified
    setAtom(explicit_goal, "has_gold", true);

    worldstate_t merged = ai::merge_goal_state(current_goal, explicit_goal);

    // tired should still be dontcare since neither goal specified it
    EXPECT_TRUE(isAtomDontCare(merged, "tired"));
}

// =============================================================================
// AI Trace Ring Buffer tests (Phase 1.1)
// These test the per-entity trace buffer for debugging AI decisions
// =============================================================================

class AITraceBufferTest : public ::testing::Test {
protected:
    ai::AITraceBuffer buffer;

    void SetUp() override {
        buffer.clear();
    }
};

TEST_F(AITraceBufferTest, NewBufferIsEmpty) {
    EXPECT_EQ(buffer.size(), 0);
    EXPECT_TRUE(buffer.empty());
}

TEST_F(AITraceBufferTest, CanAddEvent) {
    buffer.push(ai::TraceEvent{
        .type = ai::TraceEventType::GOAL_SELECTED,
        .message = "Selected goal: get_food"
    });

    EXPECT_EQ(buffer.size(), 1);
    EXPECT_FALSE(buffer.empty());
}

TEST_F(AITraceBufferTest, EventsRetrievedInOrder) {
    buffer.push(ai::TraceEvent{
        .type = ai::TraceEventType::GOAL_SELECTED,
        .message = "first"
    });
    buffer.push(ai::TraceEvent{
        .type = ai::TraceEventType::PLAN_BUILT,
        .message = "second"
    });
    buffer.push(ai::TraceEvent{
        .type = ai::TraceEventType::ACTION_START,
        .message = "third"
    });

    auto events = buffer.get_all();
    ASSERT_EQ(events.size(), 3);
    EXPECT_EQ(events[0].message, "first");
    EXPECT_EQ(events[1].message, "second");
    EXPECT_EQ(events[2].message, "third");
}

TEST_F(AITraceBufferTest, EventTypesStoredCorrectly) {
    buffer.push(ai::TraceEvent{.type = ai::TraceEventType::GOAL_SELECTED});
    buffer.push(ai::TraceEvent{.type = ai::TraceEventType::PLAN_BUILT});
    buffer.push(ai::TraceEvent{.type = ai::TraceEventType::ACTION_START});
    buffer.push(ai::TraceEvent{.type = ai::TraceEventType::ACTION_FINISH});
    buffer.push(ai::TraceEvent{.type = ai::TraceEventType::ACTION_ABORT});
    buffer.push(ai::TraceEvent{.type = ai::TraceEventType::WORLDSTATE_CHANGED});
    buffer.push(ai::TraceEvent{.type = ai::TraceEventType::REPLAN_TRIGGERED});

    auto events = buffer.get_all();
    ASSERT_EQ(events.size(), 7);
    EXPECT_EQ(events[0].type, ai::TraceEventType::GOAL_SELECTED);
    EXPECT_EQ(events[1].type, ai::TraceEventType::PLAN_BUILT);
    EXPECT_EQ(events[2].type, ai::TraceEventType::ACTION_START);
    EXPECT_EQ(events[3].type, ai::TraceEventType::ACTION_FINISH);
    EXPECT_EQ(events[4].type, ai::TraceEventType::ACTION_ABORT);
    EXPECT_EQ(events[5].type, ai::TraceEventType::WORLDSTATE_CHANGED);
    EXPECT_EQ(events[6].type, ai::TraceEventType::REPLAN_TRIGGERED);
}

TEST_F(AITraceBufferTest, RingBufferOverwritesOldEvents) {
    // Default buffer size is 100 events
    constexpr size_t kBufferSize = 100;

    // Fill buffer completely
    for (size_t i = 0; i < kBufferSize; ++i) {
        buffer.push(ai::TraceEvent{
            .type = ai::TraceEventType::GOAL_SELECTED,
            .message = "old_" + std::to_string(i)
        });
    }
    EXPECT_EQ(buffer.size(), kBufferSize);

    // Add one more - should overwrite the oldest
    buffer.push(ai::TraceEvent{
        .type = ai::TraceEventType::GOAL_SELECTED,
        .message = "new_event"
    });

    // Size should still be kBufferSize
    EXPECT_EQ(buffer.size(), kBufferSize);

    // First event should now be "old_1" (old_0 was overwritten)
    auto events = buffer.get_all();
    EXPECT_EQ(events[0].message, "old_1");
    // Last event should be "new_event"
    EXPECT_EQ(events[kBufferSize - 1].message, "new_event");
}

TEST_F(AITraceBufferTest, ClearRemovesAllEvents) {
    buffer.push(ai::TraceEvent{.type = ai::TraceEventType::GOAL_SELECTED});
    buffer.push(ai::TraceEvent{.type = ai::TraceEventType::PLAN_BUILT});

    buffer.clear();

    EXPECT_EQ(buffer.size(), 0);
    EXPECT_TRUE(buffer.empty());
}

TEST_F(AITraceBufferTest, EventStoresTimestamp) {
    buffer.push(ai::TraceEvent{
        .type = ai::TraceEventType::ACTION_START,
        .message = "test"
    });

    auto events = buffer.get_all();
    ASSERT_EQ(events.size(), 1);
    // Timestamp should be non-zero (set by push)
    EXPECT_GT(events[0].timestamp, 0.0);
}

TEST_F(AITraceBufferTest, EventStoresEntityId) {
    buffer.push(ai::TraceEvent{
        .type = ai::TraceEventType::ACTION_START,
        .message = "test",
        .entity_id = 42
    });

    auto events = buffer.get_all();
    ASSERT_EQ(events.size(), 1);
    EXPECT_EQ(events[0].entity_id, 42);
}

TEST_F(AITraceBufferTest, EventStoresExtraData) {
    buffer.push(ai::TraceEvent{
        .type = ai::TraceEventType::PLAN_BUILT,
        .message = "Plan built",
        .extra_data = {
            {"steps", "3"},
            {"cost", "10"}
        }
    });

    auto events = buffer.get_all();
    ASSERT_EQ(events.size(), 1);
    EXPECT_EQ(events[0].extra_data.at("steps"), "3");
    EXPECT_EQ(events[0].extra_data.at("cost"), "10");
}

TEST_F(AITraceBufferTest, GetRecentReturnsLatestEvents) {
    for (int i = 0; i < 50; ++i) {
        buffer.push(ai::TraceEvent{
            .type = ai::TraceEventType::GOAL_SELECTED,
            .message = "event_" + std::to_string(i)
        });
    }

    // Get last 10 events
    auto recent = buffer.get_recent(10);
    ASSERT_EQ(recent.size(), 10);
    EXPECT_EQ(recent[0].message, "event_40");
    EXPECT_EQ(recent[9].message, "event_49");
}

TEST_F(AITraceBufferTest, GetRecentHandlesMoreThanSize) {
    buffer.push(ai::TraceEvent{.type = ai::TraceEventType::GOAL_SELECTED, .message = "a"});
    buffer.push(ai::TraceEvent{.type = ai::TraceEventType::GOAL_SELECTED, .message = "b"});
    buffer.push(ai::TraceEvent{.type = ai::TraceEventType::GOAL_SELECTED, .message = "c"});

    // Request more than available
    auto recent = buffer.get_recent(100);
    ASSERT_EQ(recent.size(), 3);
}

TEST_F(AITraceBufferTest, FilterByEventType) {
    buffer.push(ai::TraceEvent{.type = ai::TraceEventType::GOAL_SELECTED, .message = "goal1"});
    buffer.push(ai::TraceEvent{.type = ai::TraceEventType::ACTION_START, .message = "action1"});
    buffer.push(ai::TraceEvent{.type = ai::TraceEventType::GOAL_SELECTED, .message = "goal2"});
    buffer.push(ai::TraceEvent{.type = ai::TraceEventType::ACTION_FINISH, .message = "finish1"});

    auto goals = buffer.get_by_type(ai::TraceEventType::GOAL_SELECTED);
    ASSERT_EQ(goals.size(), 2);
    EXPECT_EQ(goals[0].message, "goal1");
    EXPECT_EQ(goals[1].message, "goal2");
}

// =============================================================================
// Trace Helper Functions tests (Phase 1.1)
// These test the convenience functions for recording trace events
// =============================================================================

class AITraceHelperTest : public ::testing::Test {
protected:
    ai::AITraceBuffer buffer;

    void SetUp() override {
        buffer.clear();
    }
};

TEST_F(AITraceHelperTest, TraceEventTypeNameReturnsCorrectStrings) {
    EXPECT_STREQ(ai::trace_event_type_name(ai::TraceEventType::GOAL_SELECTED), "GOAL_SELECTED");
    EXPECT_STREQ(ai::trace_event_type_name(ai::TraceEventType::PLAN_BUILT), "PLAN_BUILT");
    EXPECT_STREQ(ai::trace_event_type_name(ai::TraceEventType::ACTION_START), "ACTION_START");
    EXPECT_STREQ(ai::trace_event_type_name(ai::TraceEventType::ACTION_FINISH), "ACTION_FINISH");
    EXPECT_STREQ(ai::trace_event_type_name(ai::TraceEventType::ACTION_ABORT), "ACTION_ABORT");
    EXPECT_STREQ(ai::trace_event_type_name(ai::TraceEventType::WORLDSTATE_CHANGED), "WORLDSTATE_CHANGED");
    EXPECT_STREQ(ai::trace_event_type_name(ai::TraceEventType::REPLAN_TRIGGERED), "REPLAN_TRIGGERED");
}

TEST_F(AITraceHelperTest, TraceGoalSelectedBasic) {
    ai::trace_goal_selected(buffer, 42, "EAT_FOOD");

    auto events = buffer.get_all();
    ASSERT_EQ(events.size(), 1);
    EXPECT_EQ(events[0].type, ai::TraceEventType::GOAL_SELECTED);
    EXPECT_EQ(events[0].entity_id, 42);
    EXPECT_EQ(events[0].extra_data.at("goal"), "EAT_FOOD");
    EXPECT_TRUE(events[0].message.find("EAT_FOOD") != std::string::npos);
}

TEST_F(AITraceHelperTest, TraceGoalSelectedWithBandAndScore) {
    ai::trace_goal_selected(buffer, 10, "ATTACK", "COMBAT", 95);

    auto events = buffer.get_all();
    ASSERT_EQ(events.size(), 1);
    EXPECT_EQ(events[0].extra_data.at("band"), "COMBAT");
    EXPECT_EQ(events[0].extra_data.at("score"), "95");
}

TEST_F(AITraceHelperTest, TracePlanBuilt) {
    ai::trace_plan_built(buffer, 5, 3, 15, "MoveTo");

    auto events = buffer.get_all();
    ASSERT_EQ(events.size(), 1);
    EXPECT_EQ(events[0].type, ai::TraceEventType::PLAN_BUILT);
    EXPECT_EQ(events[0].entity_id, 5);
    EXPECT_EQ(events[0].extra_data.at("steps"), "3");
    EXPECT_EQ(events[0].extra_data.at("cost"), "15");
    EXPECT_EQ(events[0].extra_data.at("first_action"), "MoveTo");
}

TEST_F(AITraceHelperTest, TraceActionStart) {
    ai::trace_action_start(buffer, 7, "AttackEnemy");

    auto events = buffer.get_all();
    ASSERT_EQ(events.size(), 1);
    EXPECT_EQ(events[0].type, ai::TraceEventType::ACTION_START);
    EXPECT_EQ(events[0].extra_data.at("action"), "AttackEnemy");
}

TEST_F(AITraceHelperTest, TraceActionFinish) {
    ai::trace_action_finish(buffer, 8, "GatherResource", "success");

    auto events = buffer.get_all();
    ASSERT_EQ(events.size(), 1);
    EXPECT_EQ(events[0].type, ai::TraceEventType::ACTION_FINISH);
    EXPECT_EQ(events[0].extra_data.at("action"), "GatherResource");
    EXPECT_EQ(events[0].extra_data.at("result"), "success");
}

TEST_F(AITraceHelperTest, TraceActionAbort) {
    ai::trace_action_abort(buffer, 9, "MoveTo", "target_destroyed");

    auto events = buffer.get_all();
    ASSERT_EQ(events.size(), 1);
    EXPECT_EQ(events[0].type, ai::TraceEventType::ACTION_ABORT);
    EXPECT_EQ(events[0].extra_data.at("action"), "MoveTo");
    EXPECT_EQ(events[0].extra_data.at("reason"), "target_destroyed");
}

TEST_F(AITraceHelperTest, TraceWorldstateChanged) {
    ai::trace_worldstate_changed(buffer, 11, 0b1010, "hungry and tired changed");

    auto events = buffer.get_all();
    ASSERT_EQ(events.size(), 1);
    EXPECT_EQ(events[0].type, ai::TraceEventType::WORLDSTATE_CHANGED);
    EXPECT_EQ(events[0].extra_data.at("changed_bits"), "10");  // 0b1010 = 10
}

TEST_F(AITraceHelperTest, TraceReplanTriggered) {
    ai::trace_replan_triggered(buffer, 12, "worldstate_changed");

    auto events = buffer.get_all();
    ASSERT_EQ(events.size(), 1);
    EXPECT_EQ(events[0].type, ai::TraceEventType::REPLAN_TRIGGERED);
    EXPECT_EQ(events[0].extra_data.at("reason"), "worldstate_changed");
}

TEST_F(AITraceHelperTest, MultipleHelpersInSequence) {
    ai::trace_goal_selected(buffer, 1, "EAT");
    ai::trace_plan_built(buffer, 1, 2, 5);
    ai::trace_action_start(buffer, 1, "FindFood");
    ai::trace_worldstate_changed(buffer, 1, 0b100, "food_found");
    ai::trace_action_finish(buffer, 1, "FindFood");
    ai::trace_action_start(buffer, 1, "Eat");
    ai::trace_action_finish(buffer, 1, "Eat");

    auto events = buffer.get_all();
    ASSERT_EQ(events.size(), 7);

    // Verify event types in order
    EXPECT_EQ(events[0].type, ai::TraceEventType::GOAL_SELECTED);
    EXPECT_EQ(events[1].type, ai::TraceEventType::PLAN_BUILT);
    EXPECT_EQ(events[2].type, ai::TraceEventType::ACTION_START);
    EXPECT_EQ(events[3].type, ai::TraceEventType::WORLDSTATE_CHANGED);
    EXPECT_EQ(events[4].type, ai::TraceEventType::ACTION_FINISH);
    EXPECT_EQ(events[5].type, ai::TraceEventType::ACTION_START);
    EXPECT_EQ(events[6].type, ai::TraceEventType::ACTION_FINISH);
}
