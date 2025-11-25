#pragma once

#include "../third_party/rlImGui/rlImGui.h" // raylib imGUI binding

#include "game.hpp"
#include "globals.hpp"

#include "../components/graphics.hpp"

#include <string>
using std::string;

namespace init {

extern auto base_init() -> void;
extern auto startInit() -> void;
extern auto initGUI() -> void;
extern auto initECS() -> void;
extern auto initSystems() -> void;
extern auto loadConfigFileValues() -> void;
extern auto loadTextures() -> void;
void scanAssetsFolderAndAddAllPaths();
auto loadJSONData() -> void;
void loadAnimationsFromJSON();
void loadColorsFromJSON();
void loadInSpriteFramesFromJSON();
Texture2D retrieveNotAtlasTexture(string refrence);
std::string getAssetPath(const std::string path_uuid_or_raw_identifier);
AnimationObject getAnimationObject(std::string uuid_or_raw_identifier,
                                    ::EngineContext *ctx = nullptr);
std::string getUIString(std::string uuid_or_raw_identifier,
                        ::EngineContext *ctx = nullptr);
globals::SpriteFrameData getSpriteFrame(std::string uuid_or_raw_identifier,
                                        ::EngineContext *ctx = nullptr);

// utility
auto extractFileNumber(const std::string &filename) -> int;
} // namespace init
