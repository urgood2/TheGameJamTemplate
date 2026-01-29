#pragma once

/**
 * @file init.hpp
 * @brief Initialization entry points for engine startup and asset loading.
 */

#include "../third_party/rlImGui/rlImGui.h" // raylib imGUI binding

#include "game.hpp"
#include "globals.hpp"

#include "../components/graphics.hpp"

#include <string>
using std::string;

namespace init {

/// One-time startup: logging, assets, window, GUI, physics, and textures.
extern auto base_init() -> void;
/// Lightweight Taskflow-driven initialization for systems and localization.
extern auto startInit() -> void;
#ifndef __EMSCRIPTEN__
/// Async initialization with loading screen progress updates (desktop only).
extern auto startInitAsync(int loadingThreads) -> void;
#endif
/// Configure ImGui fonts/styles; should run after window creation.
extern auto initGUI() -> void;
/// Connect ECS signals (listeners are currently stubs while migrating).
extern auto initECS() -> void;
/// Initialize subsystems that do not depend on the render loop.
extern auto initSystems() -> void;
/// Load screen dimensions and other config values from config.json.
extern auto loadConfigFileValues() -> void;
/// Load sprite atlas textures and attach them to animations.
extern auto loadTextures() -> void;
/// Recursively register asset paths to the UUID system.
void scanAssetsFolderAndAddAllPaths();
/// Load JSON blobs (colors, animations, config, AI) into globals/context.
auto loadJSONData() -> void;
/// Parse animations JSON and populate animation map.
void loadAnimationsFromJSON();
/// Populate color map and persist UUID annotations back to disk.
void loadColorsFromJSON();
/// Load sprite frame metadata from graphics/ JSON files.
void loadInSpriteFramesFromJSON();
[[nodiscard]] Texture2D retrieveNotAtlasTexture(string refrence);
[[nodiscard]] std::string getAssetPath(const std::string path_uuid_or_raw_identifier);
[[nodiscard]] AnimationObject getAnimationObject(std::string uuid_or_raw_identifier,
                                    ::EngineContext *ctx = nullptr);
[[nodiscard]] std::string getUIString(std::string uuid_or_raw_identifier,
                        ::EngineContext *ctx = nullptr);
[[nodiscard]] globals::SpriteFrameData getSpriteFrame(std::string uuid_or_raw_identifier,
                                        ::EngineContext *ctx = nullptr);

// utility
/// Extract trailing/leading numeric index from filenames like sprites-3.json.
auto extractFileNumber(const std::string &filename) -> int;
} // namespace init
