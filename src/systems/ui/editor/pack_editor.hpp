#pragma once

#include "imgui.h"
#include "raylib.h"
#include "../ui_pack.hpp"
#include <string>
#include <vector>
#include <optional>

namespace ui::editor {

/// Selection state in the atlas viewport
struct AtlasSelection {
    bool active = false;
    Vector2 start{0, 0};
    Vector2 end{0, 0};

    Rectangle getRect() const {
        return {
            std::min(start.x, end.x),
            std::min(start.y, end.y),
            std::abs(end.x - start.x),
            std::abs(end.y - start.y)
        };
    }
};

/// 9-patch border editing state
struct NinePatchGuides {
    int left = 8;
    int top = 8;
    int right = 8;
    int bottom = 8;
};

/// Element type being edited
enum class PackElementType {
    Panel,
    Button,
    ProgressBar,
    Scrollbar,
    Slider,
    Input,
    Icon
};

/// Button state being edited
enum class ButtonState {
    Normal,
    Hover,
    Pressed,
    Disabled
};

/// Current editing context
struct EditContext {
    PackElementType elementType = PackElementType::Panel;
    std::string variantName;
    ButtonState buttonState = ButtonState::Normal;
    SpriteScaleMode scaleMode = SpriteScaleMode::Stretch;
    bool useNinePatch = true;
    NinePatchGuides guides;
};

/// Main editor state
struct PackEditorState {
    // Pack being edited
    std::string packName;
    std::string atlasPath;
    Texture2D* atlas = nullptr;
    UIAssetPack workingPack;

    // Viewport state
    float zoom = 1.0f;
    Vector2 pan{0, 0};
    AtlasSelection selection;

    // Edit context
    EditContext editCtx;

    // UI state
    bool isOpen = false;
    bool showPreview = true;
    std::string statusMessage;
};

/// Initialize the pack editor
void initPackEditor(PackEditorState& state);

/// Render the pack editor ImGui window
void renderPackEditor(PackEditorState& state);

/// Save current pack to JSON
bool savePackManifest(const PackEditorState& state, const std::string& path);

/// Load pack from JSON into editor
bool loadPackManifest(PackEditorState& state, const std::string& path);

} // namespace ui::editor
