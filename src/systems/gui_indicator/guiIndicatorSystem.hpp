#pragma once

#include "../../util/common_headers.hpp"
#include <entt/entt.hpp>

namespace ui_indicators {

    extern auto update(entt::registry& registry, const float dt) -> void;
    extern auto draw(entt::registry& registry) -> void;
    
    extern auto update(const float dt) -> void;
    extern auto draw() -> void;
}