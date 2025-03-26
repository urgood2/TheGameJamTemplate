#include "factory.hpp"

#include "entt/entt.hpp"

namespace factory {

    AnimationQueueComponent& emplaceAnimationQueue(entt::registry &registry, entt::entity e)
    {
        return registry.emplace<AnimationQueueComponent>(e);
    }
}