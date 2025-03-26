#pragma once

#include "entt/fwd.hpp"
#include "components/graphics.hpp"

struct AnimationQueueComponent;

namespace factory {

    // --------------------------------------------------------------------------------------------
    // Factory Functions to conveninetly add components to entities
    // --------------------------------------------------------------------------------------------
    AnimationQueueComponent& emplaceAnimationQueue(entt::registry &registry, entt::entity e);
}