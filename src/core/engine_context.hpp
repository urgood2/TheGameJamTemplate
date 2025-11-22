#pragma once

#include <map>
#include <memory>
#include <string>

#include "entt/entt.hpp"
#include "raylib.h"
#include "sol/sol.hpp"

#include "core/globals.hpp"
#include "components/graphics.hpp"

// A minimal EngineContext to begin migrating away from globals.
struct EngineConfig {
    std::string configPath;
};

struct EngineContext {
    // Core systems/state
    entt::registry registry;
    sol::state lua;

    std::shared_ptr<PhysicsManager> physicsManager{};

    // Resource caches (owned)
    std::map<std::string, Texture2D> textureAtlas;
    std::map<std::string, AnimationObject> animations;
    std::map<std::string, globals::SpriteFrameData> spriteFrames;
    std::map<std::string, Color> colors;

    // Mutable state
    GameState currentGameState{GameState::LOADING_SCREEN};
    Vector2 worldMousePosition{0.0f, 0.0f};

    explicit EngineContext(EngineConfig cfg);
    ~EngineContext();

    EngineContext(const EngineContext&) = delete;
    EngineContext& operator=(const EngineContext&) = delete;
    EngineContext(EngineContext&&) = default;
    EngineContext& operator=(EngineContext&&) = default;

private:
    const EngineConfig config;
};

std::unique_ptr<EngineContext> createEngineContext(const std::string& configPath);
