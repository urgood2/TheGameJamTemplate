#pragma once

#include "raylib.h"
#include <vector>


namespace game {


    // part of the main game loop. Place anything that doesn't fit in with systems, etc. in here
    extern auto update(float delta) -> void;

    extern auto init() -> void;
    void SetUpShaderUniforms();
    extern auto draw(float dt) -> void;

    extern bool isPaused, isGameOver;
    extern bool isGameOver;
    extern bool gameStarted; // if game state has begun (not in menu )
}