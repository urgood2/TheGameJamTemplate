#pragma once

#include "raylib.h"
#include "systems/ui/core/ui_components.hpp"
#include "systems/nine_patch/nine_patch_baker.hpp"
#include <optional>
#include <string>
#include <vector>

namespace ui {

enum class UISizingMode {
    FitContent,
    FitSprite
};

struct UISpriteConfig {
    UISizingMode sizingMode = UISizingMode::FitContent;
    int spriteWidth = 0;
    int spriteHeight = 0;
};

struct UIDecoration {
    enum class Anchor {
        TopLeft, TopCenter, TopRight,
        MiddleLeft, Center, MiddleRight,
        BottomLeft, BottomCenter, BottomRight
    };
    
    std::string spriteName;
    Anchor anchor = Anchor::TopLeft;
    Vector2 offset{0.0f, 0.0f};
    float opacity = 1.0f;
    bool flipX = false;
    bool flipY = false;
    float rotation = 0.0f;
    Vector2 scale{1.0f, 1.0f};
    int zOffset = 0;
    Color tint = WHITE;
    bool visible = true;
    std::string id;
};

struct UIDecorations {
    std::vector<UIDecoration> items;
};

struct UIStateBackgrounds {
    enum class State {
        NORMAL,
        HOVER,
        PRESSED,
        DISABLED
    };
    
    std::optional<UIStyleConfig> normal;
    std::optional<UIStyleConfig> hover;
    std::optional<UIStyleConfig> pressed;
    std::optional<UIStyleConfig> disabled;
    State currentState = State::NORMAL;
    
    const UIStyleConfig* getCurrentStyle() const {
        switch (currentState) {
            case State::NORMAL: return normal.has_value() ? &normal.value() : nullptr;
            case State::HOVER: return hover.has_value() ? &hover.value() : nullptr;
            case State::PRESSED: return pressed.has_value() ? &pressed.value() : nullptr;
            case State::DISABLED: return disabled.has_value() ? &disabled.value() : nullptr;
        }
        return nullptr;
    }
};

struct SpritePanelBorders {
    int left = 0;
    int top = 0;
    int right = 0;
    int bottom = 0;
};

struct SpritePanelConfig {
    std::string spriteName;
    SpritePanelBorders borders;
    nine_patch::NPatchRegionModes regionModes;
    UISizingMode sizingMode = UISizingMode::FitContent;
    UIDecorations decorations;
};

struct SpriteButtonStates {
    std::string normal;
    std::string hover;
    std::string pressed;
    std::string disabled;
};

struct SpriteButtonConfig {
    SpriteButtonStates states;
    SpritePanelBorders borders;
    std::string baseSprite;
    bool autoFindStates = false;
};

}
