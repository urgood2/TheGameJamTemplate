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
