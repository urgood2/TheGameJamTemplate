#pragma once

#include "util/common_headers.hpp"

namespace ui
{
    // used for ordering ui elements in the draw list
    struct UIDrawListItem {
        entt::entity e{ entt::null}; // the entity to draw
        int depth{ 0 }; // the depth of the entity in the hierarchy, used for ordering
    };
}