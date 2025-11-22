#include "core/engine_context.hpp"

#include <utility>

EngineContext::EngineContext(EngineConfig cfg)
    : physicsManager(nullptr), config(std::move(cfg)) {
    // Leave heavy initialization to init routines; keep constructor lightweight.
}

EngineContext::~EngineContext() = default;

std::unique_ptr<EngineContext> createEngineContext(const std::string& configPath) {
    EngineConfig cfg{};
    cfg.configPath = configPath;

    auto ctx = std::make_unique<EngineContext>(std::move(cfg));
    ctx->currentGameState = GameState::LOADING_SCREEN;
    ctx->worldMousePosition = {0.0f, 0.0f};
    return ctx;
}
