#include <gtest/gtest.h>

#include "components/components.hpp"

class GOAPUtilsTest : public ::testing::Test {
protected:
    actionplanner_t ap;

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
    actionplanner_t ap;
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
