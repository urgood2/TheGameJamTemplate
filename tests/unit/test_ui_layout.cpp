// tests/unit/test_ui_layout.cpp
#include <gtest/gtest.h>
#include "systems/ui/ui_data.hpp"
#include "systems/ui/box.hpp"
#include "systems/transform/transform.hpp"
#include "core/globals.hpp"
#include <unordered_map>

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

// ============================================================
// Filler Distribution Tests
// ============================================================

TEST_F(UILayoutTest, FillerDistributionSubtractsPadding) {
    entt::registry R;

    // Container setup
    const float padding = 4.0f;
    const float containerWidth = 150.0f;
    const float containerHeight = 20.0f;

    auto container = R.create();
    auto &containerGO = R.emplace<transform::GameObject>(container);
    auto &containerCfg = R.emplace<ui::UIConfig>(container);
    containerCfg.uiType = ui::UITypeEnum::HORIZONTAL_CONTAINER;
    containerCfg.padding = padding;

    std::unordered_map<entt::entity, Vector2> contentSizes;

    auto addChild = [&](float w, float h, bool filler, float flex) {
        auto e = R.create();
        R.emplace<transform::GameObject>(e);
        R.emplace<transform::Transform>(e);
        auto &cfg = R.emplace<ui::UIConfig>(e);
        cfg.uiType = filler ? ui::UITypeEnum::FILLER : ui::UITypeEnum::RECT_SHAPE;
        cfg.isFiller = filler;
        cfg.flexWeight = flex;
        cfg.maxFillSize = 0.0f;
        containerGO.orderedChildren.push_back(e);
        contentSizes[e] = { filler ? 0.0f : w, filler ? 0.0f : h };
        return e;
    };

    auto left = addChild(50.0f, 10.0f, false, 0.0f);
    auto filler = addChild(0.0f, 0.0f, true, 1.0f);
    auto right = addChild(30.0f, 10.0f, false, 0.0f);

    const Vector2 containerSize{containerWidth, containerHeight};

    ui::box::DistributeFillerSpace(R, container, containerCfg, containerSize, contentSizes);

    const auto &fillerCfg = R.get<ui::UIConfig>(filler);
    ASSERT_TRUE(contentSizes.contains(filler));

    // Available space: 150 - (50+30) - padding*(children+1) = 150 - 80 - 16 = 54
    EXPECT_FLOAT_EQ(fillerCfg.computedFillSize, 54.0f);
    EXPECT_FLOAT_EQ(contentSizes[filler].x, 54.0f);
    EXPECT_FLOAT_EQ(contentSizes[filler].y, 10.0f); // matches tallest sibling
    EXPECT_FALSE(fillerCfg.minWidth.has_value());
    EXPECT_FALSE(fillerCfg.minHeight.has_value());
}

TEST_F(UILayoutTest, FillerClearsPersistedMinDimensions) {
    entt::registry R;

    auto container = R.create();
    auto &containerGO = R.emplace<transform::GameObject>(container);
    auto &containerCfg = R.emplace<ui::UIConfig>(container);
    containerCfg.uiType = ui::UITypeEnum::HORIZONTAL_CONTAINER;
    containerCfg.padding = 4.0f;

    std::unordered_map<entt::entity, Vector2> contentSizes;

    auto filler = R.create();
    R.emplace<transform::GameObject>(filler);
    R.emplace<transform::Transform>(filler);
    auto &fillerCfg = R.emplace<ui::UIConfig>(filler);
    fillerCfg.uiType = ui::UITypeEnum::FILLER;
    fillerCfg.isFiller = true;
    fillerCfg.flexWeight = 1.0f;
    fillerCfg.maxFillSize = 0.0f;
    fillerCfg.minWidth = 999.0f;   // stale values from prior layout
    fillerCfg.minHeight = 888.0f;
    containerGO.orderedChildren.push_back(filler);
    contentSizes[filler] = {0.0f, 0.0f};

    ui::box::DistributeFillerSpace(R, container, containerCfg, {120.0f, 20.0f}, contentSizes);

    EXPECT_FALSE(fillerCfg.minWidth.has_value());
    EXPECT_FALSE(fillerCfg.minHeight.has_value());
    EXPECT_GT(fillerCfg.computedFillSize, 0.0f);
}
