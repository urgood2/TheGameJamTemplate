#pragma once

#include "entt/entt.hpp"
#include <optional>

// The arguments passed in are: the initial value of the spring, its stiffness and damping.
namespace spring {

    struct Spring {
        float value{};
        float stiffness{};
        float damping{};
        float targetValue{};
        float velocity{};
        bool enabled{true}; // springs will not update if this is false

        // New optional fields
        std::optional<float> maxVelocity{};       // Optional maximum velocity 
        std::optional<float> smoothingFactor{};   // Optional smoothing factor between 0 and 1 (higher = faster smoothing)

        // experimental
        std::optional<float> timeToTarget{}; // Optional time in seconds to reach the target
        float remainingTime{};               // Internal tracking of remaining time
        std::function<double(double)> easingFunction{}; // Custom easing function (optional)

        bool preventOvershoot = false;  // New flag to enforce non-overshooting behavior
        
        bool usingForTransforms = true; // If true, this spring is used for transforms and will use a different update logic

    };
    
    extern auto updateAllSprings(entt::registry &registry, float deltaTime) -> void ;

    extern auto update(Spring& spring, float deltaTime) -> void;
     
    // Pull the spring with a certain amount of force. This force should be related to the initial value you set to the spring.
    extern auto pull(Spring& spring, float force, float stiffness = -1, float damping = -1) -> void;

    // Animates the spring such that it reaches the target value in a smoothy springy motion.
    // Unlike pull, which tugs on the spring so that it bounces around the anchor, this changes that anchor itself.
    extern auto animateToTarget(Spring& spring, float targetValue, float stiffness, float damping) -> void;

    extern auto animateToTargetWithTime(Spring &spring, float targetValue, float timeToTarget, 
                                 std::function<double(double)> easingFunction = nullptr, 
                                 float initialStiffness = 100.0f, float initialDamping = 10.0f) -> void;
}