#pragma once

/**
 * @file engine_context.hpp
 * @brief Central dependency-injection container replacing the legacy globals.
 */

#include <functional>
#include <map>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

#include "entt/entt.hpp"
#include "raylib.h"
#include "sol/sol.hpp"

#include "core/event_bus.hpp"
#include "core/globals.hpp"
#include "components/graphics.hpp"
#include "systems/shaders/shader_system.hpp"
#include "systems/ui/ui_pack.hpp"

namespace shaders { struct ShaderUniformComponent; }
namespace input { struct InputState; }

/// Placeholder for audio system state; mirrors legacy globals until audio is migrated.
struct AudioContext {
    bool deviceInitialized{false};
};

/// Lightweight configuration used to construct EngineContext.
struct EngineConfig {
    std::string configPath;
};

/**
 * @brief Core engine state container used for dependency injection.
 *
 * Owns the ECS registry plus resource caches and mirrors in-flight runtime
 * values that were previously global. During the migration, many members
 * intentionally track legacy globals to keep both call sites valid.
 *
 * @note Thread-safety: not thread-safe; main thread only.
 * @note Ownership: owns most caches; pointers marked as non-owning are mirrors
 *       to legacy globals and must outlive the context.
 * @note Initialization: prefer creating via createEngineContext() so JSON
 *       configuration is wired consistently.
 */
struct EngineContext {
    // Core systems/state
    entt::registry registry;
    sol::state lua;

    std::shared_ptr<PhysicsManager> physicsManager{};
    event_bus::EventBus eventBus;

    // Resource caches (owned)
    std::map<std::string, Texture2D> textureAtlas;
    std::map<std::string, AnimationObject> animations;
    std::map<std::string, globals::SpriteFrameData> spriteFrames;
    std::map<std::string, Color> colors;
    std::unordered_map<std::string, std::vector<entt::entity>> globalUIInstances;
    std::unordered_map<std::string, std::function<void()>> buttonCallbacks;
    std::unordered_map<std::string, ui::UIAssetPack> uiPacks;
    ::input::InputState* inputState{nullptr}; // non-owning, mirrors legacy globals
    AudioContext* audio{nullptr}; // non-owning placeholder for audio state
    float uiScaleFactor{1.0f};
    float baseShadowExaggeration{1.8f};
    ::shaders::ShaderUniformComponent* shaderUniformsPtr{nullptr}; // optional alias to global or owned
    std::unique_ptr<::shaders::ShaderUniformComponent> shaderUniformsOwned{};
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
    bool isGamePaused{false};
    bool useImGUI{true};
    bool drawDebugInfo{false};
    bool drawPhysicsDebug{false};
    bool releaseMode{false};
    bool screenWipe{false};
    bool underOverlay{false};
    float vibration{0.0f};
    float finalRenderScale{0.0f};
    float finalLetterboxOffsetX{0.0f};
    float finalLetterboxOffsetY{0.0f};
    float globalUIScaleFactor{1.0f};
    float uiPadding{4.0f};
    globals::Settings settings{};
    float cameraDamping{0.4f};
    float cameraStiffness{0.99f};
    Vector2 cameraVelocity{0.0f, 0.0f};
    Vector2 nextCameraTarget{0.0f, 0.0f};
    int worldWidth{0};
    int worldHeight{0};
    ::shaders::ShaderUniformComponent shaderUniforms{};
    std::vector<std::vector<uint8_t>> visibilityMap{};  // uint8_t for performance (vector<bool> is slow)
    bool useLineOfSight{false};
    float timerReal{0.0f};
    float timerTotal{0.0f};
    long framesMove{0};
    Vector2 worldMousePosition{0.0f, 0.0f};
    Vector2 scaledMousePosition{0.0f, 0.0f};
    Vector2 lastMouseClick{0.0f, 0.0f};
    int lastMouseButton{-1};
    bool hasLastMouseClick{false};
    entt::entity lastMouseClickTarget{entt::null};
    bool hasLastMouseClickTarget{false};
    entt::entity lastCollisionA{entt::null};
    entt::entity lastCollisionB{entt::null};
    entt::entity lastUIFocus{entt::null};
    entt::entity lastUIButtonActivated{entt::null};
    std::string lastLoadingStage{};
    bool lastLoadingStageSuccess{true};
    entt::entity cursor{entt::null};
    entt::entity overlayMenu{entt::null};
    entt::entity gameWorldContainerEntity{entt::null};

    explicit EngineContext(EngineConfig cfg);
    ~EngineContext();

    EngineContext(const EngineContext&) = delete;
    EngineContext& operator=(const EngineContext&) = delete;
    EngineContext(EngineContext&&) = default;
    EngineContext& operator=(EngineContext&&) = delete;

private:
    const EngineConfig config;
};

/**
 * @brief Create and initialize a new EngineContext from a config path.
 * @param configPath Path to config.json (raw, not UUID).
 * @return Move-only EngineContext ready for incremental migration away from globals.
 */
std::unique_ptr<EngineContext> createEngineContext(const std::string& configPath);

/// Helper: prefer context atlas, fall back to legacy globals.
inline Texture2D* getAtlasTexture(const std::string& atlasUUID) {
    if (globals::g_ctx) {
        auto it = globals::g_ctx->textureAtlas.find(atlasUUID);
        if (it != globals::g_ctx->textureAtlas.end()) {
            return &it->second;
        }
    }
    auto legacyIt = globals::textureAtlasMap.find(atlasUUID);
    if (legacyIt != globals::textureAtlasMap.end()) {
        return &legacyIt->second;
    }
    return nullptr;
}
