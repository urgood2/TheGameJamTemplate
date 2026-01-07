// tests/unit/test_ui_sprite_system.cpp
// TDD RED Phase: Tests should FAIL until implementation complete

#include <gtest/gtest.h>
#include "systems/ui/core/ui_components.hpp"
#include "systems/ui/ui_data.hpp"
#include "systems/nine_patch/nine_patch_baker.hpp"
#include "systems/ui/ui_decoration.hpp"

using namespace ui;

class UISpriteSystemTest : public ::testing::Test {
protected:
    void SetUp() override {}
    void TearDown() override {}
};

TEST_F(UISpriteSystemTest, NPatchRegionModes_DefaultValues) {
    nine_patch::NPatchRegionModes modes;
    
    EXPECT_EQ(modes.topLeft, nine_patch::SpriteScaleMode::Fixed);
    EXPECT_EQ(modes.topRight, nine_patch::SpriteScaleMode::Fixed);
    EXPECT_EQ(modes.bottomLeft, nine_patch::SpriteScaleMode::Fixed);
    EXPECT_EQ(modes.bottomRight, nine_patch::SpriteScaleMode::Fixed);
    
    EXPECT_EQ(modes.top, nine_patch::SpriteScaleMode::Tile);
    EXPECT_EQ(modes.bottom, nine_patch::SpriteScaleMode::Tile);
    EXPECT_EQ(modes.left, nine_patch::SpriteScaleMode::Tile);
    EXPECT_EQ(modes.right, nine_patch::SpriteScaleMode::Tile);
    
    EXPECT_EQ(modes.center, nine_patch::SpriteScaleMode::Stretch);
}

TEST_F(UISpriteSystemTest, NPatchRegionModes_MixedModes) {
    nine_patch::NPatchRegionModes modes;
    
    modes.topLeft = nine_patch::SpriteScaleMode::Fixed;
    modes.top = nine_patch::SpriteScaleMode::Tile;
    modes.center = nine_patch::SpriteScaleMode::Stretch;
    
    EXPECT_EQ(modes.topLeft, nine_patch::SpriteScaleMode::Fixed);
    EXPECT_EQ(modes.top, nine_patch::SpriteScaleMode::Tile);
    EXPECT_EQ(modes.center, nine_patch::SpriteScaleMode::Stretch);
}

TEST_F(UISpriteSystemTest, SizingMode_FitSprite) {
    UISpriteConfig spriteConfig;
    
    spriteConfig.sizingMode = UISizingMode::FitSprite;
    spriteConfig.spriteWidth = 200;
    spriteConfig.spriteHeight = 150;
    
    EXPECT_EQ(spriteConfig.sizingMode, UISizingMode::FitSprite);
    EXPECT_EQ(spriteConfig.spriteWidth, 200);
    EXPECT_EQ(spriteConfig.spriteHeight, 150);
}

TEST_F(UISpriteSystemTest, SizingMode_FitContent) {
    UISpriteConfig spriteConfig;
    
    spriteConfig.sizingMode = UISizingMode::FitContent;
    
    EXPECT_EQ(spriteConfig.sizingMode, UISizingMode::FitContent);
}

TEST_F(UISpriteSystemTest, UIDecoration_DefaultValues) {
    UIDecoration decoration;
    
    EXPECT_EQ(decoration.anchor, UIDecoration::Anchor::TopLeft);
    EXPECT_FLOAT_EQ(decoration.offset.x, 0.0f);
    EXPECT_FLOAT_EQ(decoration.offset.y, 0.0f);
    EXPECT_FLOAT_EQ(decoration.opacity, 1.0f);
    EXPECT_EQ(decoration.flipX, false);
    EXPECT_EQ(decoration.flipY, false);
    EXPECT_FLOAT_EQ(decoration.rotation, 0.0f);
    EXPECT_EQ(decoration.zOffset, 0);
    EXPECT_EQ(decoration.visible, true);
}

TEST_F(UISpriteSystemTest, UIDecoration_AllAnchors) {
    UIDecoration decoration;
    
    decoration.anchor = UIDecoration::Anchor::TopLeft;
    EXPECT_EQ(decoration.anchor, UIDecoration::Anchor::TopLeft);
    
    decoration.anchor = UIDecoration::Anchor::TopCenter;
    EXPECT_EQ(decoration.anchor, UIDecoration::Anchor::TopCenter);
    
    decoration.anchor = UIDecoration::Anchor::TopRight;
    EXPECT_EQ(decoration.anchor, UIDecoration::Anchor::TopRight);
    
    decoration.anchor = UIDecoration::Anchor::MiddleLeft;
    EXPECT_EQ(decoration.anchor, UIDecoration::Anchor::MiddleLeft);
    
    decoration.anchor = UIDecoration::Anchor::Center;
    EXPECT_EQ(decoration.anchor, UIDecoration::Anchor::Center);
    
    decoration.anchor = UIDecoration::Anchor::MiddleRight;
    EXPECT_EQ(decoration.anchor, UIDecoration::Anchor::MiddleRight);
    
    decoration.anchor = UIDecoration::Anchor::BottomLeft;
    EXPECT_EQ(decoration.anchor, UIDecoration::Anchor::BottomLeft);
    
    decoration.anchor = UIDecoration::Anchor::BottomCenter;
    EXPECT_EQ(decoration.anchor, UIDecoration::Anchor::BottomCenter);
    
    decoration.anchor = UIDecoration::Anchor::BottomRight;
    EXPECT_EQ(decoration.anchor, UIDecoration::Anchor::BottomRight);
}

TEST_F(UISpriteSystemTest, UIDecoration_ZOffset) {
    UIDecoration aboveDecoration;
    aboveDecoration.zOffset = 1;
    EXPECT_GT(aboveDecoration.zOffset, 0);
    
    UIDecoration belowDecoration;
    belowDecoration.zOffset = -1;
    EXPECT_LT(belowDecoration.zOffset, 0);
}

TEST_F(UISpriteSystemTest, UIDecorations_MultipleDecorations) {
    UIDecorations decorations;
    
    UIDecoration cornerFlourish;
    cornerFlourish.spriteName = "flourish_tl.png";
    cornerFlourish.anchor = UIDecoration::Anchor::TopLeft;
    cornerFlourish.offset = {-4.0f, -4.0f};
    
    UIDecoration titleBar;
    titleBar.spriteName = "title_bar.png";
    titleBar.anchor = UIDecoration::Anchor::TopCenter;
    titleBar.offset = {0.0f, -8.0f};
    
    decorations.items.push_back(cornerFlourish);
    decorations.items.push_back(titleBar);
    
    EXPECT_EQ(decorations.items.size(), 2);
    EXPECT_EQ(decorations.items[0].spriteName, "flourish_tl.png");
    EXPECT_EQ(decorations.items[1].spriteName, "title_bar.png");
}

TEST_F(UISpriteSystemTest, UIStateBackgrounds_DefaultState) {
    UIStateBackgrounds stateBackgrounds;
    
    EXPECT_EQ(stateBackgrounds.currentState, UIStateBackgrounds::State::NORMAL);
    
    EXPECT_FALSE(stateBackgrounds.normal.has_value());
    EXPECT_FALSE(stateBackgrounds.hover.has_value());
    EXPECT_FALSE(stateBackgrounds.pressed.has_value());
    EXPECT_FALSE(stateBackgrounds.disabled.has_value());
}

TEST_F(UISpriteSystemTest, UIStateBackgrounds_GetCurrentStyle) {
    UIStateBackgrounds stateBackgrounds;
    
    UIStyleConfig normalStyle;
    normalStyle.color = GRAY;
    stateBackgrounds.normal = normalStyle;
    
    UIStyleConfig hoverStyle;
    hoverStyle.color = BLUE;
    stateBackgrounds.hover = hoverStyle;
    
    UIStyleConfig pressedStyle;
    pressedStyle.color = DARKBLUE;
    stateBackgrounds.pressed = pressedStyle;
    
    stateBackgrounds.currentState = UIStateBackgrounds::State::NORMAL;
    const UIStyleConfig* current = stateBackgrounds.getCurrentStyle();
    ASSERT_NE(current, nullptr);
    EXPECT_TRUE(current->color.has_value());
    
    stateBackgrounds.currentState = UIStateBackgrounds::State::HOVER;
    current = stateBackgrounds.getCurrentStyle();
    ASSERT_NE(current, nullptr);
    
    stateBackgrounds.currentState = UIStateBackgrounds::State::PRESSED;
    current = stateBackgrounds.getCurrentStyle();
    ASSERT_NE(current, nullptr);
}

TEST_F(UISpriteSystemTest, SpritePanelConfig_InlineDefinition) {
    SpritePanelConfig panel;
    
    panel.spriteName = "panel_wood.png";
    panel.borders = {12, 12, 12, 12};
    
    EXPECT_EQ(panel.spriteName, "panel_wood.png");
    EXPECT_EQ(panel.borders.left, 12);
    EXPECT_EQ(panel.borders.top, 12);
    EXPECT_EQ(panel.borders.right, 12);
    EXPECT_EQ(panel.borders.bottom, 12);
}

TEST_F(UISpriteSystemTest, SpritePanelConfig_WithRegionModes) {
    SpritePanelConfig panel;
    
    panel.spriteName = "ornate_frame.png";
    panel.regionModes.topLeft = nine_patch::SpriteScaleMode::Fixed;
    panel.regionModes.top = nine_patch::SpriteScaleMode::Tile;
    panel.regionModes.center = nine_patch::SpriteScaleMode::Stretch;
    
    EXPECT_EQ(panel.regionModes.topLeft, nine_patch::SpriteScaleMode::Fixed);
    EXPECT_EQ(panel.regionModes.top, nine_patch::SpriteScaleMode::Tile);
    EXPECT_EQ(panel.regionModes.center, nine_patch::SpriteScaleMode::Stretch);
}

TEST_F(UISpriteSystemTest, SpriteButtonConfig_AllStates) {
    SpriteButtonConfig button;
    
    button.states.normal = "btn_normal.png";
    button.states.hover = "btn_hover.png";
    button.states.pressed = "btn_pressed.png";
    button.states.disabled = "btn_disabled.png";
    button.borders = {4, 4, 4, 4};
    
    EXPECT_EQ(button.states.normal, "btn_normal.png");
    EXPECT_EQ(button.states.hover, "btn_hover.png");
    EXPECT_EQ(button.states.pressed, "btn_pressed.png");
    EXPECT_EQ(button.states.disabled, "btn_disabled.png");
}

TEST_F(UISpriteSystemTest, SpriteButtonConfig_AutoSuffixShorthand) {
    SpriteButtonConfig button;
    
    button.baseSprite = "btn_blue";
    button.autoFindStates = true;
    
    EXPECT_EQ(button.baseSprite, "btn_blue");
    EXPECT_TRUE(button.autoFindStates);
}
