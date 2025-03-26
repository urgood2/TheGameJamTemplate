#include "spring.hpp"

#include "util/common_headers.hpp"

// The arguments passed in are: the initial value of the spring, its stiffness and damping.
namespace spring
{

    // updates all spring components in the registry
    auto updateAllSprings(entt::registry &registry, float deltaTime) -> void
    {
        auto view = registry.view<Spring>();
        for (auto entity : view)
        {
            auto &spring = view.get<Spring>(entity);
            update(spring, deltaTime);
        }
    }

    auto update(Spring &spring, float deltaTime) -> void
    {
        if (!spring.enabled)
        {
            return;
        }

        // Smoothing factor (default to 1.0 if not provided)
        float smoothingFactor = spring.smoothingFactor.value_or(0.9f);

        if (spring.timeToTarget.has_value())
        {
            // Decrease remaining time
            spring.remainingTime -= deltaTime;

            if (spring.remainingTime <= 0.0f)
            {
                // Clamp the value and velocity to stop the spring
                spring.value = spring.targetValue;
                spring.velocity = 0.0f;
                spring.timeToTarget.reset(); // Disable timing
                return;
            }

            // Calculate normalized time (0 to 1)
            float normalizedTime = 1.0f - (spring.remainingTime / spring.timeToTarget.value());

            // Apply easing function, if available
            float easedTime = normalizedTime;
            if (spring.easingFunction)
            {
                easedTime = static_cast<float>(spring.easingFunction(normalizedTime));
            }

            // Calculate dynamic stiffness and damping
            float distance = std::abs(spring.targetValue - spring.value);
            spring.stiffness = 9.0f / (spring.timeToTarget.value() * spring.timeToTarget.value());
            spring.damping = 6.0f / spring.timeToTarget.value();

            

            // Update spring using eased time
            float a = -spring.stiffness * (spring.value - spring.targetValue * easedTime) - spring.damping * spring.velocity;
            spring.velocity += a * deltaTime;
            spring.value += spring.velocity * deltaTime;
        }
        else
        {
            //FIXME: This is a temporary fix to prevent overshooting
            float criticalDamping = 2.0f * std::sqrt(spring.stiffness);

            // Standard spring update
            // float a = -spring.stiffness * (spring.value - spring.targetValue) - spring.damping * spring.velocity;
            float a = -spring.stiffness * (spring.value - spring.targetValue) - std::max(spring.damping, criticalDamping) * spring.velocity;

            spring.velocity += a * deltaTime * smoothingFactor;

            // Clamp velocity if maxVelocity is specified
            if (spring.maxVelocity.has_value())
            {
                float maxVel = spring.maxVelocity.value();
                if (std::abs(spring.velocity) > maxVel)
                {
                    spring.velocity = (spring.velocity > 0 ? 1 : -1) * maxVel;
                }
            }

            // **Prevent overshooting logic**
            if (spring.preventOvershoot)
            {
                if ((spring.value < spring.targetValue && spring.velocity > 0) ||
                    (spring.value > spring.targetValue && spring.velocity < 0))
                {
                    float projectedValue = spring.value + spring.velocity * deltaTime;

                    // If projected value overshoots, clamp it to target
                    if ((spring.value < spring.targetValue && projectedValue > spring.targetValue) ||
                        (spring.value > spring.targetValue && projectedValue < spring.targetValue))
                    {
                        spring.value = spring.targetValue;
                        spring.velocity = 0.0f; // Stop movement
                    }
                    else
                    {
                        spring.value += spring.velocity * deltaTime;
                    }
                }
                else
                {
                    spring.value += spring.velocity * deltaTime;
                }
            }
            else
            {
                spring.value += spring.velocity * deltaTime;
            }

            constexpr float snapThreshold = 0.01f; // Higher value prevents jitter

            // Snapping logic if very close to target
            if (std::abs(spring.value - spring.targetValue) < snapThreshold && std::abs(spring.velocity) < snapThreshold)
            {
                spring.value = spring.targetValue;
                spring.velocity = 0.0f;
            }
        }
    }

    // Pull the spring with a certain amount of force. This force should be related to the initial value you set to the spring.
    auto pull(Spring &spring, float force, float stiffness, float damping) -> void
    {
        if (!spring.enabled)
        {
            return;
        }
        spring.stiffness = stiffness;
        spring.damping = damping;
        spring.value = spring.value + force;
    }

    // Animates the spring such that it reaches the target value in a smoothy springy motion.
    // Unlike pull, which tugs on the spring so that it bounces around the anchor, this changes that anchor itself.
    auto animateToTarget(Spring &spring, float targetValue, float stiffness, float damping) -> void
    {
        if (!spring.enabled)
        {
            return;
        }
        spring.stiffness = stiffness;
        spring.damping = damping;
        spring.targetValue = targetValue;
    }

    auto animateToTargetWithTime(Spring &spring, float targetValue, float timeToTarget,
                                 std::function<double(double)> easingFunction,
                                 float initialStiffness, float initialDamping) -> void
    {
        if (!spring.enabled)
        {
            return;
        }
        spring.targetValue = targetValue;
        spring.timeToTarget = timeToTarget;
        spring.remainingTime = timeToTarget;
        spring.easingFunction = easingFunction; // Set the easing function
        spring.stiffness = initialStiffness;    // Initial stiffness (can be overridden)
        spring.damping = initialDamping;        // Initial damping (can be overridden)
    }

}