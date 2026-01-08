#pragma once

#include "raylib.h"
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

struct SpritePanelBorders {
    int left = 0;
    int top = 0;
    int right = 0;
    int bottom = 0;
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
