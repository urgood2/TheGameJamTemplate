#pragma once

#include "raylib.h"
#include "line_of_sight.hpp"
#include <memory>

extern std::shared_ptr<los::MyVisibility> myVisibility;

// anything with this component will affect the visibility map
struct HasVisionComponent
{
    float visionRange{10};
};

struct BlocksLightComponent
{
    bool blocksLight{false};
};