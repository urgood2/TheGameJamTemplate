#pragma once

#include <string>
#include <unordered_map>
#include <optional>
#include "raylib.h"

namespace ui {

/// Scale mode for non-9-patch sprites
enum class SpriteScaleMode {
    Stretch,  // Scale sprite to fit container (default)
    Tile,     // Repeat sprite to fill area
    Fixed     // Draw at original size, centered
};

/// Region definition - maps to JSON region entry
struct RegionDef {
    Rectangle region{0, 0, 0, 0};           // x, y, width, height in atlas
    std::optional<NPatchInfo> ninePatch;    // If present, use 9-patch rendering
    SpriteScaleMode scaleMode = SpriteScaleMode::Stretch;
};

/// Button with multiple states
struct ButtonDef {
    RegionDef normal;
    std::optional<RegionDef> hover;
    std::optional<RegionDef> pressed;
    std::optional<RegionDef> disabled;
};

/// Progress bar with background and fill
struct ProgressBarDef {
    RegionDef background;
    RegionDef fill;
};

/// Scrollbar with track and thumb
struct ScrollbarDef {
    RegionDef track;
    RegionDef thumb;
};

/// Slider with track and thumb
struct SliderDef {
    RegionDef track;
    RegionDef thumb;
};

/// Input field with normal and focus states
struct InputDef {
    RegionDef normal;
    std::optional<RegionDef> focus;
};

/// Complete UI asset pack
struct UIAssetPack {
    std::string name;
    std::string atlasPath;
    Texture2D* atlas = nullptr;  // Pointer to texture in EngineContext::textureAtlas

    std::unordered_map<std::string, RegionDef> panels;
    std::unordered_map<std::string, ButtonDef> buttons;
    std::unordered_map<std::string, ProgressBarDef> progressBars;
    std::unordered_map<std::string, ScrollbarDef> scrollbars;
    std::unordered_map<std::string, SliderDef> sliders;
    std::unordered_map<std::string, InputDef> inputs;
    std::unordered_map<std::string, RegionDef> icons;
};

/// Register a UI asset pack from a JSON manifest file
bool registerPack(const std::string& name, const std::string& manifestPath);

/// Get a registered pack by name, returns nullptr if not found
UIAssetPack* getPack(const std::string& name);

// Forward declare for Lua
namespace sol { class state; }

/// Expose UI pack system to Lua
void exposePackToLua(sol::state& lua);

} // namespace ui
