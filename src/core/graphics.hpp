#pragma once

#include "globals.hpp"

#include "../util/utilities.hpp"

struct Vector2;

namespace graphics {
    
    // --------------------------------------------------------
    // Camera
    // ------------------------------------------------
    
    extern auto setNextCameraTarget(Vector2 target) -> void;
    extern void centerCameraOnEntity( entt::entity entity);
    extern auto updateCameraForSpringierMovement(Vector2 targetPosition, float deltaTime) -> void;
    
    // --------------------------------------------------------
    // Drawing
    // ------------------------------------------------

    extern auto drawEntityAtArbitraryLocation(entt::entity, Vector2 location) -> void;
    extern auto init() -> void;
    extern auto drawSpriteFromAtlas(int spriteNumber, Rectangle destRec, Color fg) -> void;
    extern auto Vector2Subtract(Vector2 v1, Vector2 v2) -> Vector2;
    extern auto Vector2Add(Vector2 v1, Vector2 v2) -> Vector2;
    extern auto Vector2Scale(Vector2 v, float scale) -> Vector2;
    extern auto Vector2Normalize(Vector2 v) -> Vector2;
    extern auto Vector2Length(Vector2 v) -> float;
    extern auto drawSpriteComponentASCII(entt::entity e) -> void;
    
    // --------------------------------------------------------
    // Tile visibility
    // ------------------------------------------------
    extern auto isTileVisible(int x, int y) -> bool;
}