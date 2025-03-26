#pragma once

#include "entt/fwd.hpp"
#include <graphics.hpp>

struct ParticleComponent
{
    const std::vector<SpriteComponentASCII> sprites{};
    float animation_speed{};
    float lifetime{};
    float speed{};
    Vector2 direction{};
    std::string start_color{};
    std::string end_color{};
    float gravity{};
}