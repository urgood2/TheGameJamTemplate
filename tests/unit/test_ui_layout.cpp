// tests/unit/test_ui_layout.cpp
#include <gtest/gtest.h>
#include "systems/ui/ui_data.hpp"
#include "core/globals.hpp"

class UILayoutTest : public ::testing::Test {
protected:
    void SetUp() override {
        // Store original values
        originalSettingsPadding = globals::getSettings().uiPadding;
        originalGlobalScale = globals::getGlobalUIScaleFactor();

        // Set known test values
        globals::getSettings().uiPadding = 4.0f;
        globals::setGlobalUIScaleFactor(1.0f);
    }

    void TearDown() override {
        // Restore original values
        globals::getSettings().uiPadding = originalSettingsPadding;
        globals::setGlobalUIScaleFactor(originalGlobalScale);
    }

    float originalSettingsPadding;
    float originalGlobalScale;
};

// Test 1: Default values (no explicit padding, scale = 1.0)
TEST_F(UILayoutTest, EffectivePadding_DefaultValues) {
    ui::UIConfig config;
    // padding not set, scale defaults to 1.0f

    float result = config.effectivePadding();

    // Should be: 4.0f (default) * 1.0f (scale) * 1.0f (global) = 4.0f
    EXPECT_FLOAT_EQ(result, 4.0f);
}

// Test 2: Explicit padding value
TEST_F(UILayoutTest, EffectivePadding_ExplicitPadding) {
    ui::UIConfig config;
    config.padding = 8.0f;

    float result = config.effectivePadding();

    // Should be: 8.0f * 1.0f * 1.0f = 8.0f
    EXPECT_FLOAT_EQ(result, 8.0f);
}

// Test 3: With scale factor
TEST_F(UILayoutTest, EffectivePadding_WithScale) {
    ui::UIConfig config;
    config.padding = 4.0f;
    config.scale = 2.0f;

    float result = config.effectivePadding();

    // Should be: 4.0f * 2.0f * 1.0f = 8.0f
    EXPECT_FLOAT_EQ(result, 8.0f);
}

// Test 4: Zero padding (regression test)
TEST_F(UILayoutTest, EffectivePadding_ZeroPadding) {
    ui::UIConfig config;
    config.padding = 0.0f;
    config.scale = 1.0f;

    float result = config.effectivePadding();

    // Should be: 0.0f * 1.0f * 1.0f = 0.0f
    EXPECT_FLOAT_EQ(result, 0.0f);
}

// Test 5: With global UI scale factor
TEST_F(UILayoutTest, EffectivePadding_WithGlobalScale) {
    globals::setGlobalUIScaleFactor(1.5f);

    ui::UIConfig config;
    config.padding = 4.0f;
    config.scale = 1.0f;

    float result = config.effectivePadding();

    // Should be: 4.0f * 1.0f * 1.5f = 6.0f
    EXPECT_FLOAT_EQ(result, 6.0f);
}

// Test 6: Combined scale factors
TEST_F(UILayoutTest, EffectivePadding_CombinedScales) {
    globals::setGlobalUIScaleFactor(2.0f);

    ui::UIConfig config;
    config.padding = 5.0f;
    config.scale = 1.5f;

    float result = config.effectivePadding();

    // Should be: 5.0f * 1.5f * 2.0f = 15.0f
    EXPECT_FLOAT_EQ(result, 15.0f);
}

// ============================================================
// Alignment Flag Conflict Detection Tests
// ============================================================

#include "systems/transform/transform.hpp"

using Align = transform::InheritedProperties::Alignment;

// Test: No conflict with single flag
TEST_F(UILayoutTest, AlignmentFlags_SingleFlag_NoConflict) {
    std::string conflict;
    bool hasConflict = ui::hasConflictingAlignmentFlags(Align::VERTICAL_CENTER, &conflict);

    EXPECT_FALSE(hasConflict);
    EXPECT_TRUE(conflict.empty());
}

// Test: Valid combination (H_CENTER + V_CENTER)
TEST_F(UILayoutTest, AlignmentFlags_ValidCombination) {
    int flags = Align::HORIZONTAL_CENTER | Align::VERTICAL_CENTER;
    std::string conflict;
    bool hasConflict = ui::hasConflictingAlignmentFlags(flags, &conflict);

    EXPECT_FALSE(hasConflict);
}

// Test: Vertical conflict (CENTER + BOTTOM)
TEST_F(UILayoutTest, AlignmentFlags_VerticalConflict_CenterBottom) {
    int flags = Align::VERTICAL_CENTER | Align::VERTICAL_BOTTOM;
    std::string conflict;
    bool hasConflict = ui::hasConflictingAlignmentFlags(flags, &conflict);

    EXPECT_TRUE(hasConflict);
    EXPECT_FALSE(conflict.empty());
}

// Test: Vertical conflict (CENTER + TOP)
TEST_F(UILayoutTest, AlignmentFlags_VerticalConflict_CenterTop) {
    int flags = Align::VERTICAL_CENTER | Align::VERTICAL_TOP;
    std::string conflict;
    bool hasConflict = ui::hasConflictingAlignmentFlags(flags, &conflict);

    EXPECT_TRUE(hasConflict);
}

// Test: Vertical conflict (TOP + BOTTOM)
TEST_F(UILayoutTest, AlignmentFlags_VerticalConflict_TopBottom) {
    int flags = Align::VERTICAL_TOP | Align::VERTICAL_BOTTOM;
    std::string conflict;
    bool hasConflict = ui::hasConflictingAlignmentFlags(flags, &conflict);

    EXPECT_TRUE(hasConflict);
}

// Test: Horizontal conflict (CENTER + LEFT)
TEST_F(UILayoutTest, AlignmentFlags_HorizontalConflict_CenterLeft) {
    int flags = Align::HORIZONTAL_CENTER | Align::HORIZONTAL_LEFT;
    std::string conflict;
    bool hasConflict = ui::hasConflictingAlignmentFlags(flags, &conflict);

    EXPECT_TRUE(hasConflict);
}

// Test: Horizontal conflict (CENTER + RIGHT)
TEST_F(UILayoutTest, AlignmentFlags_HorizontalConflict_CenterRight) {
    int flags = Align::HORIZONTAL_CENTER | Align::HORIZONTAL_RIGHT;
    std::string conflict;
    bool hasConflict = ui::hasConflictingAlignmentFlags(flags, &conflict);

    EXPECT_TRUE(hasConflict);
}

// Test: Horizontal conflict (LEFT + RIGHT)
TEST_F(UILayoutTest, AlignmentFlags_HorizontalConflict_LeftRight) {
    int flags = Align::HORIZONTAL_LEFT | Align::HORIZONTAL_RIGHT;
    std::string conflict;
    bool hasConflict = ui::hasConflictingAlignmentFlags(flags, &conflict);

    EXPECT_TRUE(hasConflict);
}

// Test: Multiple conflicts detected
TEST_F(UILayoutTest, AlignmentFlags_MultipleConflicts) {
    int flags = Align::VERTICAL_CENTER | Align::VERTICAL_BOTTOM | Align::HORIZONTAL_LEFT | Align::HORIZONTAL_RIGHT;
    std::string conflict;
    bool hasConflict = ui::hasConflictingAlignmentFlags(flags, &conflict);

    EXPECT_TRUE(hasConflict);
    // Should report at least one conflict
    EXPECT_FALSE(conflict.empty());
}

// Test: nullptr for conflict description is safe
TEST_F(UILayoutTest, AlignmentFlags_NullptrDescription) {
    int flags = Align::VERTICAL_CENTER | Align::VERTICAL_BOTTOM;

    // Should not crash
    bool hasConflict = ui::hasConflictingAlignmentFlags(flags, nullptr);

    EXPECT_TRUE(hasConflict);
}
