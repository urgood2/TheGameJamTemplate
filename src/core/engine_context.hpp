#pragma once

#include <map>
#include <memory>
#include <string>

#include "entt/entt.hpp"
#include "raylib.h"
#include "sol/sol.hpp"

#include "core/globals.hpp"
#include "core/globals.hpp"
#include "components/graphics.hpp"

namespace input {
    struct InputState;
}

// Placeholder for future audio system state; currently mirrors legacy globals once wired.
struct AudioContext {
    bool deviceInitialized{false};
};

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
    input::InputState* inputState{nullptr}; // non-owning, mirrors legacy globals
    AudioContext* audio{nullptr}; // non-owning placeholder for audio state
    json configJson{};
    json colorsJson{};
    json uiStringsJson{};
    json animationsJson{};
    json aiConfigJson{};
    json aiActionsJson{};
    json aiWorldstateJson{};
    json ninePatchJson{};

    // Mutable state
    GameState currentGameState{GameState::LOADING_SCREEN};
    Vector2 worldMousePosition{0.0f, 0.0f};
    Vector2 scaledMousePosition{0.0f, 0.0f};

    explicit EngineContext(EngineConfig cfg);
    ~EngineContext();

    EngineContext(const EngineContext&) = delete;
    EngineContext& operator=(const EngineContext&) = delete;
    EngineContext(EngineContext&&) = default;
    EngineContext& operator=(EngineContext&&) = delete;

private:
    const EngineConfig config;
};

std::unique_ptr<EngineContext> createEngineContext(const std::string& configPath);
