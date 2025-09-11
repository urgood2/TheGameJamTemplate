// NavmeshComponents.hpp
#pragma once
#include <optional>
#include <raylib.h>
#include "entt/entt.hpp"

struct NavmeshObstacle {
    bool include = true;                  // force include even if body is dynamic (or set false to exclude)
    std::optional<int> inflate_pixels;    // per-entity override (else world default)
};

struct NavmeshWorldConfig {
    int default_inflate_px = 8;           // default margin for all obstacles in this world
    float circle_tol = 2.5f;              // higher => fewer segments for circle approximation
    int circle_min_segments = 8;
    int circle_max_segments = 48;
};