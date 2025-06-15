#pragma once

#include "raylib.h"

#include <vector>
#include <memory>
#include <string>

#include "systems/layer/layer.hpp"



namespace game {

    // make layers to draw to
    extern std::shared_ptr<layer::Layer> background;  // background
    extern std::shared_ptr<layer::Layer> sprites;     // sprites
    extern std::shared_ptr<layer::Layer> ui_layer;    // ui
    extern std::shared_ptr<layer::Layer> finalOutput; // final output (for post processing)


    // part of the main game loop. Place anything that doesn't fit in with systems, etc. in here
    extern auto update(float delta) -> void;

    extern auto init() -> void;
    extern auto draw(float dt) -> void;

    extern bool isPaused, isGameOver;
    extern bool isGameOver;
    extern bool gameStarted; // if game state has begun (not in menu )
}