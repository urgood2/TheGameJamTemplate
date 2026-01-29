# UI Asset Pack System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable loading and using UI asset packs from itch.io with a clean Lua API and visual manifest editor.

**Architecture:** JSON manifest describes atlas regions and element types. C++ loads manifest into `UIAssetPack` struct stored in `EngineContext`. Lua `PackHandle` userdata returns configured `UIConfig` tables. ImGui editor creates manifests visually.

**Tech Stack:** C++20, Sol2 (Lua bindings), nlohmann/json, ImGui, Raylib

---

## Task 1: Define Core Data Structures

**Files:**
- Create: `src/systems/ui/ui_pack.hpp`

**Step 1: Write the header file**

```cpp
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

} // namespace ui
```

**Step 2: Verify it compiles**

Run: `just build-debug 2>&1 | grep -E "(error|ui_pack)"`
Expected: No errors mentioning ui_pack.hpp

**Step 3: Commit**

```bash
git add src/systems/ui/ui_pack.hpp
git commit -m "feat(ui): add UIAssetPack data structures"
```

---

## Task 2: Add Pack Registry to EngineContext

**Files:**
- Modify: `src/core/engine_context.hpp:59-64`

**Step 1: Add include and member**

Add after line 22 (after existing includes):
```cpp
#include "systems/ui/ui_pack.hpp"
```

Add after line 63 (after `buttonCallbacks`):
```cpp
std::unordered_map<std::string, ui::UIAssetPack> uiPacks;
```

**Step 2: Verify it compiles**

Run: `just build-debug 2>&1 | grep -E "error"`
Expected: No errors

**Step 3: Commit**

```bash
git add src/core/engine_context.hpp
git commit -m "feat(ui): add uiPacks registry to EngineContext"
```

---

## Task 3: Implement JSON Manifest Parser

**Files:**
- Create: `src/systems/ui/ui_pack.cpp`

**Step 1: Write the implementation**

```cpp
#include "ui_pack.hpp"
#include "core/globals.hpp"
#include "core/engine_context.hpp"
#include "util/common_headers.hpp"
#include <fstream>

namespace ui {

namespace {

SpriteScaleMode parseScaleMode(const std::string& mode) {
    if (mode == "tile") return SpriteScaleMode::Tile;
    if (mode == "fixed") return SpriteScaleMode::Fixed;
    return SpriteScaleMode::Stretch;
}

RegionDef parseRegionDef(const json& j) {
    RegionDef def;

    if (j.contains("region") && j["region"].is_array() && j["region"].size() == 4) {
        auto& r = j["region"];
        def.region = {
            r[0].get<float>(),
            r[1].get<float>(),
            r[2].get<float>(),
            r[3].get<float>()
        };
    }

    if (j.contains("9patch") && j["9patch"].is_array() && j["9patch"].size() == 4) {
        auto& p = j["9patch"];
        NPatchInfo info{};
        info.source = def.region;
        info.left = p[0].get<int>();
        info.top = p[1].get<int>();
        info.right = p[2].get<int>();
        info.bottom = p[3].get<int>();
        info.layout = NPATCH_NINE_PATCH;
        def.ninePatch = info;
    }

    if (j.contains("scale_mode")) {
        def.scaleMode = parseScaleMode(j["scale_mode"].get<std::string>());
    }

    return def;
}

ButtonDef parseButtonDef(const json& j) {
    ButtonDef def;
    if (j.contains("normal")) def.normal = parseRegionDef(j["normal"]);
    if (j.contains("hover")) def.hover = parseRegionDef(j["hover"]);
    if (j.contains("pressed")) def.pressed = parseRegionDef(j["pressed"]);
    if (j.contains("disabled")) def.disabled = parseRegionDef(j["disabled"]);
    return def;
}

ProgressBarDef parseProgressBarDef(const json& j) {
    ProgressBarDef def;
    if (j.contains("background")) def.background = parseRegionDef(j["background"]);
    if (j.contains("fill")) def.fill = parseRegionDef(j["fill"]);
    return def;
}

ScrollbarDef parseScrollbarDef(const json& j) {
    ScrollbarDef def;
    if (j.contains("track")) def.track = parseRegionDef(j["track"]);
    if (j.contains("thumb")) def.thumb = parseRegionDef(j["thumb"]);
    return def;
}

SliderDef parseSliderDef(const json& j) {
    SliderDef def;
    if (j.contains("track")) def.track = parseRegionDef(j["track"]);
    if (j.contains("thumb")) def.thumb = parseRegionDef(j["thumb"]);
    return def;
}

InputDef parseInputDef(const json& j) {
    InputDef def;
    if (j.contains("normal")) def.normal = parseRegionDef(j["normal"]);
    if (j.contains("focus")) def.focus = parseRegionDef(j["focus"]);
    return def;
}

} // anonymous namespace

bool registerPack(const std::string& name, const std::string& manifestPath) {
    std::ifstream file(manifestPath);
    if (!file.is_open()) {
        SPDLOG_ERROR("Failed to open UI pack manifest: {}", manifestPath);
        return false;
    }

    json manifest;
    try {
        file >> manifest;
    } catch (const json::parse_error& e) {
        SPDLOG_ERROR("Failed to parse UI pack manifest {}: {}", manifestPath, e.what());
        return false;
    }

    UIAssetPack pack;
    pack.name = name;

    // Get atlas path relative to manifest directory
    std::filesystem::path manifestDir = std::filesystem::path(manifestPath).parent_path();
    if (manifest.contains("atlas")) {
        pack.atlasPath = (manifestDir / manifest["atlas"].get<std::string>()).string();
    }

    // Load texture if not already loaded
    if (!pack.atlasPath.empty()) {
        auto* existingTex = getAtlasTexture(pack.atlasPath);
        if (existingTex) {
            pack.atlas = existingTex;
        } else {
            // Load and cache the texture
            Texture2D tex = LoadTexture(pack.atlasPath.c_str());
            if (tex.id != 0) {
                if (globals::g_ctx) {
                    globals::g_ctx->textureAtlas[pack.atlasPath] = tex;
                    pack.atlas = &globals::g_ctx->textureAtlas[pack.atlasPath];
                } else {
                    globals::textureAtlasMap[pack.atlasPath] = tex;
                    pack.atlas = &globals::textureAtlasMap[pack.atlasPath];
                }
            } else {
                SPDLOG_ERROR("Failed to load UI pack atlas: {}", pack.atlasPath);
            }
        }
    }

    // Parse element definitions
    if (manifest.contains("panels")) {
        for (auto& [key, val] : manifest["panels"].items()) {
            pack.panels[key] = parseRegionDef(val);
        }
    }

    if (manifest.contains("buttons")) {
        for (auto& [key, val] : manifest["buttons"].items()) {
            pack.buttons[key] = parseButtonDef(val);
        }
    }

    if (manifest.contains("progress_bars")) {
        for (auto& [key, val] : manifest["progress_bars"].items()) {
            pack.progressBars[key] = parseProgressBarDef(val);
        }
    }

    if (manifest.contains("scrollbars")) {
        for (auto& [key, val] : manifest["scrollbars"].items()) {
            pack.scrollbars[key] = parseScrollbarDef(val);
        }
    }

    if (manifest.contains("sliders")) {
        for (auto& [key, val] : manifest["sliders"].items()) {
            pack.sliders[key] = parseSliderDef(val);
        }
    }

    if (manifest.contains("inputs")) {
        for (auto& [key, val] : manifest["inputs"].items()) {
            pack.inputs[key] = parseInputDef(val);
        }
    }

    if (manifest.contains("icons")) {
        for (auto& [key, val] : manifest["icons"].items()) {
            pack.icons[key] = parseRegionDef(val);
        }
    }

    // Store in registry
    if (globals::g_ctx) {
        globals::g_ctx->uiPacks[name] = std::move(pack);
        SPDLOG_INFO("Registered UI pack '{}' with {} panels, {} buttons, {} icons",
            name, globals::g_ctx->uiPacks[name].panels.size(),
            globals::g_ctx->uiPacks[name].buttons.size(),
            globals::g_ctx->uiPacks[name].icons.size());
        return true;
    }

    SPDLOG_ERROR("No EngineContext available to register UI pack");
    return false;
}

UIAssetPack* getPack(const std::string& name) {
    if (globals::g_ctx) {
        auto it = globals::g_ctx->uiPacks.find(name);
        if (it != globals::g_ctx->uiPacks.end()) {
            return &it->second;
        }
    }
    return nullptr;
}

} // namespace ui
```

**Step 2: Add function declarations to header**

Add to `src/systems/ui/ui_pack.hpp` before the closing `}` of namespace:

```cpp
/// Register a UI asset pack from a JSON manifest file
bool registerPack(const std::string& name, const std::string& manifestPath);

/// Get a registered pack by name, returns nullptr if not found
UIAssetPack* getPack(const std::string& name);
```

**Step 3: Add to CMakeLists.txt**

Find the UI source files list and add `ui_pack.cpp` to it.

**Step 4: Verify it compiles**

Run: `just build-debug 2>&1 | grep -E "error"`
Expected: No errors

**Step 5: Commit**

```bash
git add src/systems/ui/ui_pack.hpp src/systems/ui/ui_pack.cpp
git commit -m "feat(ui): implement JSON manifest parser for UI packs"
```

---

## Task 4: Add SPRITE Styling Type to UIConfig

**Files:**
- Modify: `src/systems/ui/ui_data.hpp:172-175`

**Step 1: Add SPRITE enum value**

Change the `UIStylingType` enum:

```cpp
enum class UIStylingType {
    ROUNDED_RECTANGLE,
    NINEPATCH_BORDERS,
    SPRITE  // New: texture region with scale_mode
};
```

**Step 2: Add sprite-related fields to UIConfig**

Add after line 189 (after `nPatchSourceTexture`):

```cpp
// Sprite rendering (for UI asset pack sprites)
std::optional<Texture2D*> spriteSourceTexture;
std::optional<Rectangle> spriteSourceRect;
SpriteScaleMode spriteScaleMode = SpriteScaleMode::Stretch;
```

Note: `SpriteScaleMode` needs to be forward-declared or the include added.

**Step 3: Add include for SpriteScaleMode**

Add at top of ui_data.hpp:
```cpp
#include "ui_pack.hpp"  // For SpriteScaleMode
```

Or move `SpriteScaleMode` to ui_data.hpp to avoid circular dependency.

**Step 4: Verify it compiles**

Run: `just build-debug 2>&1 | grep -E "error"`
Expected: No errors

**Step 5: Commit**

```bash
git add src/systems/ui/ui_data.hpp
git commit -m "feat(ui): add SPRITE styling type to UIConfig"
```

---

## Task 5: Implement Sprite Rendering in DrawSelf

**Files:**
- Modify: `src/systems/ui/element.cpp` (find DrawSelf function)

**Step 1: Find existing rendering branch**

Search for `NINEPATCH_BORDERS` or `DrawNPatchUIElement` in element.cpp to locate the rendering logic.

**Step 2: Add SPRITE rendering case**

After the 9-patch rendering branch, add:

```cpp
else if (config.stylingType == UIStylingType::SPRITE && config.spriteSourceTexture && config.spriteSourceRect) {
    auto* tex = config.spriteSourceTexture.value();
    auto srcRect = config.spriteSourceRect.value();

    Rectangle destRect = {
        transform.getVisualX(),
        transform.getVisualY(),
        transform.getVisualW(),
        transform.getVisualH()
    };

    switch (config.spriteScaleMode) {
        case SpriteScaleMode::Fixed: {
            // Draw at original size, centered
            float cx = destRect.x + (destRect.width - srcRect.width) / 2.0f;
            float cy = destRect.y + (destRect.height - srcRect.height) / 2.0f;
            DrawTextureRec(*tex, srcRect, {cx, cy}, WHITE);
            break;
        }
        case SpriteScaleMode::Tile: {
            // Tile to fill container
            for (float y = destRect.y; y < destRect.y + destRect.height; y += srcRect.height) {
                for (float x = destRect.x; x < destRect.x + destRect.width; x += srcRect.width) {
                    // Clip if needed at edges
                    float drawW = std::min(srcRect.width, destRect.x + destRect.width - x);
                    float drawH = std::min(srcRect.height, destRect.y + destRect.height - y);
                    Rectangle clippedSrc = {srcRect.x, srcRect.y, drawW, drawH};
                    DrawTextureRec(*tex, clippedSrc, {x, y}, WHITE);
                }
            }
            break;
        }
        case SpriteScaleMode::Stretch:
        default: {
            // Scale to fit
            DrawTexturePro(*tex, srcRect, destRect, {0, 0}, 0.0f, WHITE);
            break;
        }
    }
}
```

**Step 3: Verify it compiles**

Run: `just build-debug 2>&1 | grep -E "error"`
Expected: No errors

**Step 4: Commit**

```bash
git add src/systems/ui/element.cpp
git commit -m "feat(ui): implement SPRITE rendering with scale modes"
```

---

## Task 6: Create PackHandle Lua Userdata

**Files:**
- Create: `src/systems/ui/ui_pack_lua.cpp`

**Step 1: Write the Lua bindings**

```cpp
#include "ui_pack.hpp"
#include "ui_data.hpp"
#include "sol/sol.hpp"
#include "core/globals.hpp"
#include "systems/scripting/binding_recorder.hpp"

namespace ui {

/// Lua-facing handle to a registered UI pack
struct PackHandle {
    std::string packName;

    PackHandle(const std::string& name) : packName(name) {}

    UIAssetPack* getPack() const {
        return ui::getPack(packName);
    }
};

namespace {

UIConfig makeConfigFromRegion(const RegionDef& region, Texture2D* atlas, const sol::table& opts) {
    UIConfig config;

    if (region.ninePatch) {
        config.stylingType = UIStylingType::NINEPATCH_BORDERS;
        config.nPatchInfo = region.ninePatch;
        config.nPatchSourceTexture = atlas ? *atlas : Texture2D{};
    } else {
        config.stylingType = UIStylingType::SPRITE;
        config.spriteSourceTexture = atlas;
        config.spriteSourceRect = region.region;
        config.spriteScaleMode = region.scaleMode;
    }

    // Merge with user options
    if (opts.valid()) {
        if (opts["padding"].valid()) config.padding = opts["padding"].get<float>();
        if (opts["color"].valid()) config.color = opts["color"].get<Color>();
        if (opts["onClick"].valid()) config.buttonCallback = opts["onClick"].get<std::function<void()>>();
        if (opts["width"].valid()) config.width = opts["width"].get<int>();
        if (opts["height"].valid()) config.height = opts["height"].get<int>();
    }

    return config;
}

sol::object panelMethod(PackHandle& handle, const std::string& variant, sol::optional<sol::table> opts, sol::this_state L) {
    auto* pack = handle.getPack();
    if (!pack) {
        SPDLOG_ERROR("UI pack '{}' not found", handle.packName);
        return sol::nil;
    }

    auto it = pack->panels.find(variant);
    if (it == pack->panels.end()) {
        SPDLOG_ERROR("Panel variant '{}' not found in pack '{}'", variant, handle.packName);
        return sol::nil;
    }

    UIConfig config = makeConfigFromRegion(it->second, pack->atlas, opts.value_or(sol::table()));
    return sol::make_object(L, config);
}

sol::object buttonMethod(PackHandle& handle, const std::string& variant, sol::optional<sol::table> opts, sol::this_state L) {
    auto* pack = handle.getPack();
    if (!pack) return sol::nil;

    auto it = pack->buttons.find(variant);
    if (it == pack->buttons.end()) {
        SPDLOG_ERROR("Button variant '{}' not found in pack '{}'", variant, handle.packName);
        return sol::nil;
    }

    // Return config for normal state (button states handled separately)
    UIConfig config = makeConfigFromRegion(it->second.normal, pack->atlas, opts.value_or(sol::table()));
    return sol::make_object(L, config);
}

sol::table progressBarMethod(PackHandle& handle, const std::string& variant, sol::this_state L) {
    sol::state_view lua(L);
    sol::table result = lua.create_table();

    auto* pack = handle.getPack();
    if (!pack) return result;

    auto it = pack->progressBars.find(variant);
    if (it == pack->progressBars.end()) return result;

    result["background"] = makeConfigFromRegion(it->second.background, pack->atlas, sol::table());
    result["fill"] = makeConfigFromRegion(it->second.fill, pack->atlas, sol::table());
    return result;
}

sol::table scrollbarMethod(PackHandle& handle, const std::string& variant, sol::this_state L) {
    sol::state_view lua(L);
    sol::table result = lua.create_table();

    auto* pack = handle.getPack();
    if (!pack) return result;

    auto it = pack->scrollbars.find(variant);
    if (it == pack->scrollbars.end()) return result;

    result["track"] = makeConfigFromRegion(it->second.track, pack->atlas, sol::table());
    result["thumb"] = makeConfigFromRegion(it->second.thumb, pack->atlas, sol::table());
    return result;
}

sol::table sliderMethod(PackHandle& handle, const std::string& variant, sol::this_state L) {
    sol::state_view lua(L);
    sol::table result = lua.create_table();

    auto* pack = handle.getPack();
    if (!pack) return result;

    auto it = pack->sliders.find(variant);
    if (it == pack->sliders.end()) return result;

    result["track"] = makeConfigFromRegion(it->second.track, pack->atlas, sol::table());
    result["thumb"] = makeConfigFromRegion(it->second.thumb, pack->atlas, sol::table());
    return result;
}

sol::object inputMethod(PackHandle& handle, const std::string& variant, sol::optional<sol::table> opts, sol::this_state L) {
    auto* pack = handle.getPack();
    if (!pack) return sol::nil;

    auto it = pack->inputs.find(variant);
    if (it == pack->inputs.end()) return sol::nil;

    UIConfig config = makeConfigFromRegion(it->second.normal, pack->atlas, opts.value_or(sol::table()));
    return sol::make_object(L, config);
}

sol::object iconMethod(PackHandle& handle, const std::string& variant, sol::optional<sol::table> opts, sol::this_state L) {
    auto* pack = handle.getPack();
    if (!pack) return sol::nil;

    auto it = pack->icons.find(variant);
    if (it == pack->icons.end()) return sol::nil;

    UIConfig config = makeConfigFromRegion(it->second, pack->atlas, opts.value_or(sol::table()));
    return sol::make_object(L, config);
}

} // anonymous namespace

void exposePackToLua(sol::state& lua) {
    auto& rec = BindingRecorder::instance();

    // Get or create ui table
    sol::table ui = lua["ui"].get_or_create<sol::table>();

    // PackHandle usertype
    lua.new_usertype<PackHandle>("UIPackHandle",
        sol::constructors<PackHandle(const std::string&)>(),
        "panel", &panelMethod,
        "button", &buttonMethod,
        "progress_bar", &progressBarMethod,
        "scrollbar", &scrollbarMethod,
        "slider", &sliderMethod,
        "input", &inputMethod,
        "icon", &iconMethod
    );

    auto& packDef = rec.add_type("UIPackHandle");
    packDef.doc = "Handle to a registered UI asset pack.";
    rec.record_method("UIPackHandle", {"panel", "---@param variant string\n---@param opts? table\n---@return UIConfig", "Get panel config by variant name.", false, false});
    rec.record_method("UIPackHandle", {"button", "---@param variant string\n---@param opts? table\n---@return UIConfig", "Get button config by variant name.", false, false});
    rec.record_method("UIPackHandle", {"progress_bar", "---@param variant string\n---@return table", "Get progress bar configs (background + fill).", false, false});
    rec.record_method("UIPackHandle", {"scrollbar", "---@param variant string\n---@return table", "Get scrollbar configs (track + thumb).", false, false});
    rec.record_method("UIPackHandle", {"slider", "---@param variant string\n---@return table", "Get slider configs (track + thumb).", false, false});
    rec.record_method("UIPackHandle", {"input", "---@param variant string\n---@param opts? table\n---@return UIConfig", "Get input field config by variant name.", false, false});
    rec.record_method("UIPackHandle", {"icon", "---@param variant string\n---@param opts? table\n---@return UIConfig", "Get icon config by variant name.", false, false});

    // Register pack function
    ui.set_function("register_pack", [](const std::string& name, const std::string& path) -> bool {
        return registerPack(name, path);
    });
    rec.record_free_function({"ui"}, {"register_pack", "---@param name string\n---@param manifestPath string\n---@return boolean", "Register a UI asset pack from a JSON manifest.", true, false});

    // Use pack function
    ui.set_function("use_pack", [](const std::string& name, sol::this_state L) -> sol::object {
        if (getPack(name)) {
            return sol::make_object(L, PackHandle(name));
        }
        SPDLOG_ERROR("UI pack '{}' not registered", name);
        return sol::nil;
    });
    rec.record_free_function({"ui"}, {"use_pack", "---@param name string\n---@return UIPackHandle|nil", "Get a handle to a registered UI pack.", true, false});
}

} // namespace ui
```

**Step 2: Add declaration to header**

Add to `src/systems/ui/ui_pack.hpp`:
```cpp
/// Expose UI pack system to Lua
void exposePackToLua(sol::state& lua);
```

**Step 3: Call from ui::exposeToLua**

Add at the end of `src/systems/ui/ui.cpp` `exposeToLua` function:
```cpp
// UI Asset Pack system
exposePackToLua(lua);
```

And add include at top of ui.cpp:
```cpp
#include "ui_pack.hpp"
```

**Step 4: Add to CMakeLists.txt**

Add `ui_pack_lua.cpp` to the UI sources.

**Step 5: Verify it compiles**

Run: `just build-debug 2>&1 | grep -E "error"`
Expected: No errors

**Step 6: Commit**

```bash
git add src/systems/ui/ui_pack.hpp src/systems/ui/ui_pack_lua.cpp src/systems/ui/ui.cpp
git commit -m "feat(ui): add Lua bindings for UI asset packs"
```

---

## Task 7: Expose SpriteScaleMode to Lua

**Files:**
- Modify: `src/systems/ui/ui_pack_lua.cpp`

**Step 1: Add enum exposure**

Add to `exposePackToLua` function:

```cpp
// SpriteScaleMode enum
lua.new_enum<SpriteScaleMode>("SpriteScaleMode", {
    {"Stretch", SpriteScaleMode::Stretch},
    {"Tile", SpriteScaleMode::Tile},
    {"Fixed", SpriteScaleMode::Fixed}
});
auto& scaleModeEnum = rec.add_type("SpriteScaleMode");
scaleModeEnum.doc = "How non-9-patch sprites fill their container.";
rec.record_property("SpriteScaleMode", {"Stretch", "0", "Scale sprite to fit container."});
rec.record_property("SpriteScaleMode", {"Tile", "1", "Repeat sprite to fill area."});
rec.record_property("SpriteScaleMode", {"Fixed", "2", "Draw at original size, centered."});
```

**Step 2: Update UIConfig Lua binding to include new fields**

In `src/systems/ui/ui.cpp`, find the UIConfig usertype and add:

```cpp
"spriteSourceTexture", &UIConfig::spriteSourceTexture,
"spriteSourceRect", &UIConfig::spriteSourceRect,
"spriteScaleMode", &UIConfig::spriteScaleMode,
```

And update UIStylingType enum:
```cpp
lua.new_enum<UIStylingType>("UIStylingType", {
    {"RoundedRectangle", UIStylingType::ROUNDED_RECTANGLE},
    {"NinePatchBorders", UIStylingType::NINEPATCH_BORDERS},
    {"Sprite", UIStylingType::SPRITE}
});
```

**Step 3: Verify it compiles**

Run: `just build-debug 2>&1 | grep -E "error"`
Expected: No errors

**Step 4: Commit**

```bash
git add src/systems/ui/ui_pack_lua.cpp src/systems/ui/ui.cpp
git commit -m "feat(ui): expose SpriteScaleMode and SPRITE styling to Lua"
```

---

## Task 8: Create Test Pack Manifest

**Files:**
- Create: `assets/ui_packs/test_pack/pack.json`

**Step 1: Create directory and manifest**

```json
{
  "name": "test_pack",
  "version": "1.0",
  "atlas": "test_atlas.png",

  "panels": {
    "simple": { "region": [0, 0, 64, 64], "9patch": [8, 8, 8, 8] }
  },

  "buttons": {
    "default": {
      "normal": { "region": [64, 0, 48, 16] },
      "hover": { "region": [64, 16, 48, 16] },
      "pressed": { "region": [64, 32, 48, 16] }
    }
  },

  "icons": {
    "star": { "region": [112, 0, 16, 16], "scale_mode": "fixed" }
  }
}
```

**Step 2: Create a simple test atlas (can be a placeholder)**

Create a 128x64 PNG with colored regions matching the manifest. Or skip if you want to test with a real pack later.

**Step 3: Commit**

```bash
git add assets/ui_packs/
git commit -m "test: add test UI pack manifest"
```

---

## Task 9: Write Integration Test Script

**Files:**
- Create: `assets/scripts/tests/test_ui_pack.lua`

**Step 1: Write test script**

```lua
-- Test script for UI asset pack system
local function test_ui_pack()
    print("=== Testing UI Asset Pack System ===")

    -- Test registration
    local success = ui.register_pack("test", "assets/ui_packs/test_pack/pack.json")
    assert(success, "Failed to register test pack")
    print("PASS: Pack registration")

    -- Test use_pack
    local pack = ui.use_pack("test")
    assert(pack ~= nil, "Failed to get pack handle")
    print("PASS: Get pack handle")

    -- Test panel
    local panelConfig = pack:panel("simple")
    assert(panelConfig ~= nil, "Failed to get panel config")
    assert(panelConfig.stylingType == UIStylingType.NinePatchBorders, "Panel should be 9-patch")
    print("PASS: Panel config")

    -- Test button
    local buttonConfig = pack:button("default")
    assert(buttonConfig ~= nil, "Failed to get button config")
    print("PASS: Button config")

    -- Test icon
    local iconConfig = pack:icon("star")
    assert(iconConfig ~= nil, "Failed to get icon config")
    assert(iconConfig.stylingType == UIStylingType.Sprite, "Icon should be sprite")
    assert(iconConfig.spriteScaleMode == SpriteScaleMode.Fixed, "Icon should be fixed scale")
    print("PASS: Icon config")

    -- Test with options
    local panelWithOpts = pack:panel("simple", { padding = 20 })
    assert(panelWithOpts.padding == 20, "Options should be merged")
    print("PASS: Options merging")

    print("=== All UI Pack Tests Passed ===")
end

return test_ui_pack
```

**Step 2: Commit**

```bash
git add assets/scripts/tests/test_ui_pack.lua
git commit -m "test: add Lua integration test for UI packs"
```

---

## Task 10: Create ImGui Pack Editor - Data Structures

**Files:**
- Create: `src/systems/ui/editor/pack_editor.hpp`

**Step 1: Write header**

```cpp
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
```

**Step 2: Commit**

```bash
git add src/systems/ui/editor/pack_editor.hpp
git commit -m "feat(ui): add ImGui pack editor data structures"
```

---

## Task 11: Implement Pack Editor Viewport

**Files:**
- Create: `src/systems/ui/editor/pack_editor.cpp`

**Step 1: Write viewport implementation**

```cpp
#include "pack_editor.hpp"
#include "imgui.h"
#include "rlImGui.h"
#include <fstream>
#include <filesystem>

namespace ui::editor {

void initPackEditor(PackEditorState& state) {
    state.zoom = 1.0f;
    state.pan = {0, 0};
    state.selection = {};
    state.editCtx = {};
    state.statusMessage = "Ready";
}

void renderAtlasViewport(PackEditorState& state) {
    ImVec2 viewportSize = ImGui::GetContentRegionAvail();
    ImVec2 viewportPos = ImGui::GetCursorScreenPos();

    // Draw background
    ImDrawList* drawList = ImGui::GetWindowDrawList();
    drawList->AddRectFilled(viewportPos,
        ImVec2(viewportPos.x + viewportSize.x, viewportPos.y + viewportSize.y),
        IM_COL32(40, 40, 40, 255));

    if (!state.atlas || state.atlas->id == 0) {
        ImGui::Text("No atlas loaded");
        return;
    }

    // Handle zoom with scroll wheel
    if (ImGui::IsWindowHovered()) {
        float wheel = ImGui::GetIO().MouseWheel;
        if (wheel != 0) {
            float oldZoom = state.zoom;
            state.zoom = std::clamp(state.zoom + wheel * 0.1f, 0.1f, 10.0f);

            // Zoom toward mouse position
            ImVec2 mousePos = ImGui::GetMousePos();
            ImVec2 relMouse = ImVec2(mousePos.x - viewportPos.x, mousePos.y - viewportPos.y);
            float zoomRatio = state.zoom / oldZoom;
            state.pan.x = relMouse.x - (relMouse.x - state.pan.x) * zoomRatio;
            state.pan.y = relMouse.y - (relMouse.y - state.pan.y) * zoomRatio;
        }

        // Handle pan with middle mouse
        if (ImGui::IsMouseDragging(ImGuiMouseButton_Middle)) {
            ImVec2 delta = ImGui::GetMouseDragDelta(ImGuiMouseButton_Middle);
            state.pan.x += delta.x;
            state.pan.y += delta.y;
            ImGui::ResetMouseDragDelta(ImGuiMouseButton_Middle);
        }

        // Handle selection with left mouse
        if (ImGui::IsMouseClicked(ImGuiMouseButton_Left)) {
            ImVec2 mousePos = ImGui::GetMousePos();
            state.selection.active = true;
            state.selection.start = {
                (mousePos.x - viewportPos.x - state.pan.x) / state.zoom,
                (mousePos.y - viewportPos.y - state.pan.y) / state.zoom
            };
            state.selection.end = state.selection.start;
        }

        if (ImGui::IsMouseDragging(ImGuiMouseButton_Left) && state.selection.active) {
            ImVec2 mousePos = ImGui::GetMousePos();
            state.selection.end = {
                (mousePos.x - viewportPos.x - state.pan.x) / state.zoom,
                (mousePos.y - viewportPos.y - state.pan.y) / state.zoom
            };
        }

        if (ImGui::IsMouseReleased(ImGuiMouseButton_Left)) {
            // Snap to pixel boundaries
            auto rect = state.selection.getRect();
            state.selection.start = {std::floor(rect.x), std::floor(rect.y)};
            state.selection.end = {
                std::floor(rect.x + rect.width),
                std::floor(rect.y + rect.height)
            };
        }
    }

    // Draw atlas
    float scaledW = state.atlas->width * state.zoom;
    float scaledH = state.atlas->height * state.zoom;

    ImVec2 atlasPos = ImVec2(viewportPos.x + state.pan.x, viewportPos.y + state.pan.y);

    // Use rlImGui to draw Raylib texture in ImGui
    rlImGuiImageRect(state.atlas,
        static_cast<int>(scaledW), static_cast<int>(scaledH),
        Rectangle{0, 0, static_cast<float>(state.atlas->width), static_cast<float>(state.atlas->height)});

    // Draw selection rectangle
    if (state.selection.active) {
        auto rect = state.selection.getRect();
        ImVec2 selStart = ImVec2(
            atlasPos.x + rect.x * state.zoom,
            atlasPos.y + rect.y * state.zoom
        );
        ImVec2 selEnd = ImVec2(
            atlasPos.x + (rect.x + rect.width) * state.zoom,
            atlasPos.y + (rect.y + rect.height) * state.zoom
        );
        drawList->AddRect(selStart, selEnd, IM_COL32(255, 255, 0, 255), 0, 0, 2.0f);

        // Draw 9-patch guides if enabled
        if (state.editCtx.useNinePatch) {
            auto& g = state.editCtx.guides;
            // Left guide
            drawList->AddLine(
                ImVec2(selStart.x + g.left * state.zoom, selStart.y),
                ImVec2(selStart.x + g.left * state.zoom, selEnd.y),
                IM_COL32(255, 100, 100, 200));
            // Right guide
            drawList->AddLine(
                ImVec2(selEnd.x - g.right * state.zoom, selStart.y),
                ImVec2(selEnd.x - g.right * state.zoom, selEnd.y),
                IM_COL32(255, 100, 100, 200));
            // Top guide
            drawList->AddLine(
                ImVec2(selStart.x, selStart.y + g.top * state.zoom),
                ImVec2(selEnd.x, selStart.y + g.top * state.zoom),
                IM_COL32(100, 255, 100, 200));
            // Bottom guide
            drawList->AddLine(
                ImVec2(selStart.x, selEnd.y - g.bottom * state.zoom),
                ImVec2(selEnd.x, selEnd.y - g.bottom * state.zoom),
                IM_COL32(100, 255, 100, 200));
        }
    }
}

void renderElementPanel(PackEditorState& state) {
    // Element type selection
    const char* elementTypes[] = {"Panel", "Button", "Progress Bar", "Scrollbar", "Slider", "Input", "Icon"};
    int currentType = static_cast<int>(state.editCtx.elementType);
    if (ImGui::Combo("Element Type", &currentType, elementTypes, IM_ARRAYSIZE(elementTypes))) {
        state.editCtx.elementType = static_cast<PackElementType>(currentType);
    }

    // Variant name
    static char variantBuf[64] = "";
    ImGui::InputText("Variant Name", variantBuf, sizeof(variantBuf));
    state.editCtx.variantName = variantBuf;

    // Button state (if button)
    if (state.editCtx.elementType == PackElementType::Button) {
        const char* buttonStates[] = {"Normal", "Hover", "Pressed", "Disabled"};
        int currentState = static_cast<int>(state.editCtx.buttonState);
        ImGui::Combo("Button State", &currentState, buttonStates, IM_ARRAYSIZE(buttonStates));
        state.editCtx.buttonState = static_cast<ButtonState>(currentState);
    }

    // 9-patch toggle
    ImGui::Checkbox("Use 9-Patch", &state.editCtx.useNinePatch);

    if (state.editCtx.useNinePatch) {
        ImGui::SliderInt("Left", &state.editCtx.guides.left, 0, 32);
        ImGui::SliderInt("Top", &state.editCtx.guides.top, 0, 32);
        ImGui::SliderInt("Right", &state.editCtx.guides.right, 0, 32);
        ImGui::SliderInt("Bottom", &state.editCtx.guides.bottom, 0, 32);
    } else {
        // Scale mode
        const char* scaleModes[] = {"Stretch", "Tile", "Fixed"};
        int currentMode = static_cast<int>(state.editCtx.scaleMode);
        ImGui::Combo("Scale Mode", &currentMode, scaleModes, IM_ARRAYSIZE(scaleModes));
        state.editCtx.scaleMode = static_cast<SpriteScaleMode>(currentMode);
    }

    // Selection info
    if (state.selection.active) {
        auto rect = state.selection.getRect();
        ImGui::Separator();
        ImGui::Text("Selection: (%.0f, %.0f) %.0fx%.0f", rect.x, rect.y, rect.width, rect.height);
    }

    // Add to pack button
    if (ImGui::Button("Add to Pack") && !state.editCtx.variantName.empty() && state.selection.active) {
        auto rect = state.selection.getRect();
        RegionDef region;
        region.region = rect;
        region.scaleMode = state.editCtx.scaleMode;

        if (state.editCtx.useNinePatch) {
            NPatchInfo info{};
            info.source = rect;
            info.left = state.editCtx.guides.left;
            info.top = state.editCtx.guides.top;
            info.right = state.editCtx.guides.right;
            info.bottom = state.editCtx.guides.bottom;
            info.layout = NPATCH_NINE_PATCH;
            region.ninePatch = info;
        }

        switch (state.editCtx.elementType) {
            case PackElementType::Panel:
                state.workingPack.panels[state.editCtx.variantName] = region;
                break;
            case PackElementType::Icon:
                state.workingPack.icons[state.editCtx.variantName] = region;
                break;
            case PackElementType::Button: {
                auto& btn = state.workingPack.buttons[state.editCtx.variantName];
                switch (state.editCtx.buttonState) {
                    case ButtonState::Normal: btn.normal = region; break;
                    case ButtonState::Hover: btn.hover = region; break;
                    case ButtonState::Pressed: btn.pressed = region; break;
                    case ButtonState::Disabled: btn.disabled = region; break;
                }
                break;
            }
            // TODO: Handle other types
            default: break;
        }

        state.statusMessage = "Added " + state.editCtx.variantName;
    }
}

void renderPackContents(PackEditorState& state) {
    ImGui::Text("Pack Contents:");
    ImGui::Separator();

    if (!state.workingPack.panels.empty()) {
        ImGui::Text("Panels: %zu", state.workingPack.panels.size());
        for (auto& [name, _] : state.workingPack.panels) {
            ImGui::BulletText("%s", name.c_str());
        }
    }

    if (!state.workingPack.buttons.empty()) {
        ImGui::Text("Buttons: %zu", state.workingPack.buttons.size());
        for (auto& [name, btn] : state.workingPack.buttons) {
            int states = 1 + (btn.hover ? 1 : 0) + (btn.pressed ? 1 : 0) + (btn.disabled ? 1 : 0);
            ImGui::BulletText("%s (%d states)", name.c_str(), states);
        }
    }

    if (!state.workingPack.icons.empty()) {
        ImGui::Text("Icons: %zu", state.workingPack.icons.size());
        for (auto& [name, _] : state.workingPack.icons) {
            ImGui::BulletText("%s", name.c_str());
        }
    }
}

void renderPackEditor(PackEditorState& state) {
    if (!state.isOpen) return;

    ImGui::SetNextWindowSize(ImVec2(1000, 700), ImGuiCond_FirstUseEver);
    if (ImGui::Begin("UI Pack Editor", &state.isOpen, ImGuiWindowFlags_MenuBar)) {
        // Menu bar
        if (ImGui::BeginMenuBar()) {
            if (ImGui::BeginMenu("File")) {
                if (ImGui::MenuItem("New Pack")) {
                    initPackEditor(state);
                }
                if (ImGui::MenuItem("Load Atlas...")) {
                    // TODO: File dialog
                }
                if (ImGui::MenuItem("Save Pack...")) {
                    // TODO: File dialog + savePackManifest
                }
                ImGui::EndMenu();
            }
            ImGui::EndMenuBar();
        }

        // Zoom controls
        ImGui::Text("Zoom: %.0f%%", state.zoom * 100);
        ImGui::SameLine();
        if (ImGui::Button("+")) state.zoom = std::min(state.zoom + 0.25f, 10.0f);
        ImGui::SameLine();
        if (ImGui::Button("-")) state.zoom = std::max(state.zoom - 0.25f, 0.1f);
        ImGui::SameLine();
        if (ImGui::Button("Fit")) state.zoom = 1.0f;
        ImGui::SameLine();
        if (ImGui::Button("1:1")) state.zoom = 1.0f;

        // Main layout: viewport | sidebar
        ImGui::Columns(2);
        ImGui::SetColumnWidth(0, ImGui::GetWindowWidth() * 0.65f);

        // Left: Atlas viewport
        ImGui::BeginChild("Viewport", ImVec2(0, -30), true);
        renderAtlasViewport(state);
        ImGui::EndChild();

        ImGui::NextColumn();

        // Right: Element panel + contents
        ImGui::BeginChild("Sidebar", ImVec2(0, -30));
        renderElementPanel(state);
        ImGui::Separator();
        renderPackContents(state);
        ImGui::EndChild();

        ImGui::Columns(1);

        // Status bar
        ImGui::Text("Status: %s", state.statusMessage.c_str());
    }
    ImGui::End();
}

bool savePackManifest(const PackEditorState& state, const std::string& path) {
    json manifest;
    manifest["name"] = state.workingPack.name;
    manifest["version"] = "1.0";

    if (!state.atlasPath.empty()) {
        std::filesystem::path atlasRel = std::filesystem::relative(
            state.atlasPath,
            std::filesystem::path(path).parent_path()
        );
        manifest["atlas"] = atlasRel.string();
    }

    auto regionToJson = [](const RegionDef& r) -> json {
        json j;
        j["region"] = {r.region.x, r.region.y, r.region.width, r.region.height};
        if (r.ninePatch) {
            j["9patch"] = {r.ninePatch->left, r.ninePatch->top, r.ninePatch->right, r.ninePatch->bottom};
        }
        if (r.scaleMode != SpriteScaleMode::Stretch) {
            j["scale_mode"] = r.scaleMode == SpriteScaleMode::Tile ? "tile" : "fixed";
        }
        return j;
    };

    for (auto& [name, panel] : state.workingPack.panels) {
        manifest["panels"][name] = regionToJson(panel);
    }

    for (auto& [name, btn] : state.workingPack.buttons) {
        json btnJson;
        btnJson["normal"] = regionToJson(btn.normal);
        if (btn.hover) btnJson["hover"] = regionToJson(*btn.hover);
        if (btn.pressed) btnJson["pressed"] = regionToJson(*btn.pressed);
        if (btn.disabled) btnJson["disabled"] = regionToJson(*btn.disabled);
        manifest["buttons"][name] = btnJson;
    }

    for (auto& [name, icon] : state.workingPack.icons) {
        manifest["icons"][name] = regionToJson(icon);
    }

    // TODO: progress_bars, scrollbars, sliders, inputs

    std::ofstream file(path);
    if (!file.is_open()) return false;
    file << manifest.dump(2);
    return true;
}

bool loadPackManifest(PackEditorState& state, const std::string& path) {
    // Reuse existing registerPack logic, then copy to workingPack
    if (registerPack("_editor_temp", path)) {
        auto* pack = getPack("_editor_temp");
        if (pack) {
            state.workingPack = *pack;
            state.atlasPath = pack->atlasPath;
            state.atlas = pack->atlas;
            return true;
        }
    }
    return false;
}

} // namespace ui::editor
```

**Step 2: Add to CMakeLists.txt**

Add `src/systems/ui/editor/pack_editor.cpp` to sources.

**Step 3: Verify it compiles**

Run: `just build-debug 2>&1 | grep -E "error"`
Expected: No errors

**Step 4: Commit**

```bash
git add src/systems/ui/editor/
git commit -m "feat(ui): implement ImGui pack editor with viewport and controls"
```

---

## Task 12: Wire Editor into ImGui Debug Menu

**Files:**
- Find and modify the ImGui debug/dev menu (likely in `src/systems/debug/` or similar)

**Step 1: Find the debug menu location**

Search for ImGui menu registration in the codebase.

**Step 2: Add editor toggle**

```cpp
#include "systems/ui/editor/pack_editor.hpp"

// In the debug menu rendering:
static ui::editor::PackEditorState packEditorState;

if (ImGui::MenuItem("UI Pack Editor")) {
    packEditorState.isOpen = true;
}

// Somewhere in the main ImGui render loop:
ui::editor::renderPackEditor(packEditorState);
```

**Step 3: Verify it compiles and runs**

Run: `just build-debug && ./build/raylib-cpp-cmake-template`
Expected: Debug menu shows "UI Pack Editor" option

**Step 4: Commit**

```bash
git add [modified files]
git commit -m "feat(ui): wire pack editor into debug menu"
```

---

## Final Verification

**Step 1: Run full build**

```bash
just build-debug
```

**Step 2: Run the test script (if Lua console available)**

```lua
dofile("assets/scripts/tests/test_ui_pack.lua")()
```

**Step 3: Open pack editor in-game**

- Launch game
- Open debug menu
- Click "UI Pack Editor"
- Load an atlas
- Create some regions
- Save manifest
- Load manifest with ui.register_pack in Lua
- Verify elements render correctly

---

## Summary of Files Created/Modified

**New Files:**
- `src/systems/ui/ui_pack.hpp` - Data structures
- `src/systems/ui/ui_pack.cpp` - JSON parser
- `src/systems/ui/ui_pack_lua.cpp` - Lua bindings
- `src/systems/ui/editor/pack_editor.hpp` - Editor header
- `src/systems/ui/editor/pack_editor.cpp` - Editor implementation
- `assets/ui_packs/test_pack/pack.json` - Test manifest
- `assets/scripts/tests/test_ui_pack.lua` - Integration test

**Modified Files:**
- `src/core/engine_context.hpp` - Add uiPacks map
- `src/systems/ui/ui_data.hpp` - Add SPRITE styling type
- `src/systems/ui/ui.cpp` - Add Lua bindings
- `src/systems/ui/element.cpp` - Add sprite rendering
- CMakeLists.txt - Add new source files
- Debug menu file - Wire in editor

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
