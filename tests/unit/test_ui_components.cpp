// tests/unit/test_ui_components.cpp
// Unit tests for the split UI component system

#include <gtest/gtest.h>
#include "systems/ui/core/ui_components.hpp"
#include "systems/ui/ui_data.hpp"

using namespace ui;

class UIComponentsTest : public ::testing::Test {
protected:
    void SetUp() override {}
    void TearDown() override {}
};

// =============================================================================
// UIElementCore Tests
// =============================================================================

TEST_F(UIComponentsTest, UIElementCore_DefaultValues) {
    UIElementCore core;

    EXPECT_EQ(core.type, UITypeEnum::NONE);
    EXPECT_TRUE(core.uiBox == entt::null);
    EXPECT_EQ(core.id, "");
    EXPECT_EQ(core.treeOrder, 0);
}

TEST_F(UIComponentsTest, UIElementCore_AssignedValues) {
    UIElementCore core;
    core.type = UITypeEnum::RECT_SHAPE;
    core.id = "test_element";
    core.treeOrder = 5;

    EXPECT_EQ(core.type, UITypeEnum::RECT_SHAPE);
    EXPECT_EQ(core.id, "test_element");
    EXPECT_EQ(core.treeOrder, 5);
}

// =============================================================================
// UIStyleConfig Tests
// =============================================================================

TEST_F(UIComponentsTest, UIStyleConfig_DefaultValues) {
    UIStyleConfig style;

    EXPECT_EQ(style.stylingType, UIStylingType::ROUNDED_RECTANGLE);
    EXPECT_FALSE(style.color.has_value());
    EXPECT_FALSE(style.outlineColor.has_value());
    EXPECT_EQ(style.shadow, false);
    EXPECT_EQ(style.noFill, false);
    EXPECT_EQ(style.pixelatedRectangle, true);
}

// =============================================================================
// UILayoutConfig Tests
// =============================================================================

TEST_F(UIComponentsTest, UILayoutConfig_DefaultValues) {
    UILayoutConfig layout;

    EXPECT_FALSE(layout.width.has_value());
    EXPECT_FALSE(layout.height.has_value());
    EXPECT_FALSE(layout.padding.has_value());
    EXPECT_EQ(layout.mid, false);
    EXPECT_EQ(layout.draw_after, false);
}

// =============================================================================
// UIInteractionConfig Tests
// =============================================================================

TEST_F(UIComponentsTest, UIInteractionConfig_DefaultValues) {
    UIInteractionConfig interaction;

    EXPECT_EQ(interaction.hover, false);
    EXPECT_EQ(interaction.disable_button, false);
    EXPECT_EQ(interaction.buttonClicked, false);
    EXPECT_EQ(interaction.force_focus, false);
}

// =============================================================================
// UIContentConfig Tests
// =============================================================================

TEST_F(UIComponentsTest, UIContentConfig_DefaultValues) {
    UIContentConfig content;

    EXPECT_FALSE(content.text.has_value());
    EXPECT_FALSE(content.fontSize.has_value());
    EXPECT_EQ(content.progressBar, false);
    EXPECT_EQ(content.objectRecalculate, false);
}

// =============================================================================
// Extraction Function Tests
// =============================================================================

TEST_F(UIComponentsTest, ExtractStyle_CopiesAllFields) {
    UIConfig config;
    config.color = RED;
    config.outlineColor = BLUE;
    config.shadow = true;
    config.stylingType = UIStylingType::NINEPATCH_BORDERS;
    config.noFill = true;

    auto style = extractStyle(config);

    // Compare optionals by checking has_value and value
    EXPECT_TRUE(style.color.has_value());
    EXPECT_TRUE(style.outlineColor.has_value());
    EXPECT_EQ(style.shadow, config.shadow);
    EXPECT_EQ(style.stylingType, config.stylingType);
    EXPECT_EQ(style.noFill, config.noFill);
}

TEST_F(UIComponentsTest, ExtractLayout_CopiesAllFields) {
    UIConfig config;
    config.width = 100;
    config.height = 200;
    config.padding = 10.0f;
    config.alignmentFlags = 5;
    config.mid = true;

    auto layout = extractLayout(config);

    EXPECT_EQ(layout.width, config.width);
    EXPECT_EQ(layout.height, config.height);
    EXPECT_EQ(layout.padding, config.padding);
    EXPECT_EQ(layout.alignmentFlags, config.alignmentFlags);
    EXPECT_EQ(layout.mid, config.mid);
}

TEST_F(UIComponentsTest, ExtractInteraction_CopiesAllFields) {
    UIConfig config;
    config.hover = true;
    config.canCollide = true;
    config.force_focus = true;
    config.disable_button = true;

    auto interaction = extractInteraction(config);

    EXPECT_EQ(interaction.hover, config.hover);
    EXPECT_EQ(interaction.canCollide, config.canCollide);
    EXPECT_EQ(interaction.force_focus, config.force_focus);
    EXPECT_EQ(interaction.disable_button, config.disable_button);
}

TEST_F(UIComponentsTest, ExtractContent_CopiesAllFields) {
    UIConfig config;
    config.text = "Hello";
    config.fontSize = 24.0f;
    config.progressBar = true;
    config.verticalText = true;

    auto content = extractContent(config);

    EXPECT_EQ(content.text, config.text);
    EXPECT_EQ(content.fontSize, config.fontSize);
    EXPECT_EQ(content.progressBar, config.progressBar);
    EXPECT_EQ(content.verticalText, config.verticalText);
}

// =============================================================================
// UIConfigBundle Tests
// =============================================================================

TEST_F(UIComponentsTest, UIConfigBundle_ContainsAllComponents) {
    UIConfigBundle bundle;

    // Set values in each component
    bundle.style.color = RED;
    bundle.layout.width = 100;
    bundle.interaction.hover = true;
    bundle.content.text = "Test";

    // Verify all components are accessible and hold values
    EXPECT_TRUE(bundle.style.color.has_value());
    EXPECT_TRUE(bundle.layout.width.has_value());
    EXPECT_EQ(bundle.layout.width.value(), 100);
    EXPECT_EQ(bundle.interaction.hover, true);
    EXPECT_TRUE(bundle.content.text.has_value());
    EXPECT_EQ(bundle.content.text.value(), "Test");
}

// =============================================================================
// Edge Case Tests
// =============================================================================

TEST_F(UIComponentsTest, ExtractStyle_HandlesEmptyOptionals) {
    UIConfig config;
    // No fields set - all optionals should remain empty

    auto style = extractStyle(config);

    EXPECT_FALSE(style.color.has_value());
    EXPECT_FALSE(style.outlineColor.has_value());
    EXPECT_EQ(style.stylingType, UIStylingType::ROUNDED_RECTANGLE); // default
}

TEST_F(UIComponentsTest, ExtractLayout_DefaultDimensions) {
    UIConfig config;
    // No dimensions set

    auto layout = extractLayout(config);

    EXPECT_FALSE(layout.width.has_value());
    EXPECT_FALSE(layout.height.has_value());
    EXPECT_FALSE(layout.minWidth.has_value());
    EXPECT_FALSE(layout.maxWidth.has_value());
}

TEST_F(UIComponentsTest, ExtractInteraction_DefaultCallbacks) {
    UIConfig config;
    // No callbacks set

    auto interaction = extractInteraction(config);

    EXPECT_FALSE(interaction.buttonCallback.has_value());
    EXPECT_FALSE(interaction.updateFunc.has_value());
    EXPECT_FALSE(interaction.initFunc.has_value());
}
