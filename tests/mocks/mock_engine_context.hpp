#pragma once

#include <string>

#include "core/engine_context.hpp"
#include "systems/uuid/uuid.hpp"

// Lightweight EngineContext seeded with a couple of colors for tests.
struct MockEngineContext : EngineContext {
    MockEngineContext()
        : EngineContext(EngineConfig{std::string("test_config.json")}) {
        colors[uuid::add("RED")] = RED;
        colors[uuid::add("BLUE")] = BLUE;
    }
};
