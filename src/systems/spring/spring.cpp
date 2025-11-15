#include "spring.hpp"

#include "spdlog/spdlog.h"
#include "util/common_headers.hpp"
#include "systems/entity_gamestate_management/entity_gamestate_management.hpp"

// The arguments passed in are: the initial value of the spring, its stiffness and damping.
namespace spring
{

   
    //------------------------------------------------------------
    // updateAllSprings – self-contained SIMD fast path
    //------------------------------------------------------------
    auto updateAllSprings(entt::registry &registry, float deltaTime) -> void
    {
        ZONE_SCOPED("Update springs");
        
        // SPDLOG_INFO("Total springs: {}", registry.view<spring::Spring>().size());
        // SPDLOG_INFO("Disabled springs: {}", registry.view<spring::SpringDisabledTag>().size());

        // cap integration step size
        constexpr float maxStep = 0.016f;
        float effectiveDt = std::min(deltaTime, maxStep);
        int steps = std::max(1, (int)std::ceil(deltaTime / maxStep));
        float stepDt = deltaTime / (float)steps;

        // collect view once
        auto view = registry.view<Spring>(entt::exclude< entity_gamestate_management::InactiveTag, SpringDisabledTag>);
        const size_t count = view.size_hint();
        if (count == 0) return;

        // Build dense SoA buffers once per frame
        static std::vector<float> value, target, velocity, stiffness, damping;
        if (value.capacity() < count) {
            value.reserve(count);
            target.reserve(count);
            velocity.reserve(count);
            stiffness.reserve(count);
            damping.reserve(count);
        }
        value.resize(count, 0.f);

        size_t i = 0;
        for (auto entity : view)
        {
            const auto &s = view.get<Spring>(entity);
            value[i]     = s.value;
            target[i]    = s.targetValue;
            velocity[i]  = s.velocity;
            stiffness[i] = s.stiffness;
            damping[i]   = s.damping;
            ++i;
        }
        
        
    // #if defined(__x86_64__) || defined(_M_X64)
    //     const size_t step = 8;
    //     const size_t aligned = count - (count % step);
    //     for (int iter = 0; iter < steps; ++iter)
    //     {
    //         const __m256 vdt   = _mm256_set1_ps(stepDt);
    //         const __m256 vneg1 = _mm256_set1_ps(-1.f);

    //         size_t j = 0;
    //         for (; j < aligned; j += step)
    //         {
    //             __m256 vVal = _mm256_loadu_ps(&value[j]);
    //             __m256 vTar = _mm256_loadu_ps(&target[j]);
    //             __m256 vVel = _mm256_loadu_ps(&velocity[j]);
    //             __m256 vK   = _mm256_loadu_ps(&stiffness[j]);
    //             __m256 vD   = _mm256_loadu_ps(&damping[j]);

    //             __m256 vDiff = _mm256_sub_ps(vVal, vTar);
    //             __m256 vA = _mm256_fmadd_ps(vD, vVel, _mm256_mul_ps(vK, vDiff));
    //             vA = _mm256_mul_ps(vA, vneg1);
    //             vA = _mm256_mul_ps(vA, vdt);

    //             vVel = _mm256_add_ps(vVel, vA);
    //             vVal = _mm256_fmadd_ps(vVel, vdt, vVal);

    //             _mm256_storeu_ps(&velocity[j], vVel);
    //             _mm256_storeu_ps(&value[j], vVal);
    //         }

    //         for (; j < count; ++j)
    //         {
    //             float a = -stiffness[j] * (value[j] - target[j]) - damping[j] * velocity[j];
    //             velocity[j] += a * stepDt;
    //             value[j] += velocity[j] * stepDt;
    //         }
    //     }
    // #else
    
        // SPDLOG_INFO("Updating {} springs over {} steps of {} ms each", i, steps, stepDt * 1000.0f);

        // generic scalar fallback (ARM, WASM)
        for (int iter = 0; iter < steps; ++iter)
        {
            for (size_t j = 0; j < i; ++j)
            {
                float a = -stiffness[j] * (value[j] - target[j]) - damping[j] * velocity[j];
                velocity[j] += a * stepDt;
                value[j] += velocity[j] * stepDt;
            }
        }
    // #endif

        // write back to ECS
        i = 0;
        for (auto entity : view)
        {
            auto &s = view.get<Spring>(entity);
            s.value = value[i];
            s.velocity = velocity[i];
            ++i;
        }
    }




    auto update(Spring &spring, float deltaTime) -> void
    {
        if (!spring.enabled)
        {
            return;
        }
        
        if (spring.usingForTransforms) {
            
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
        
        else
        {
            // — Simple spring integration (per https://github.com/a327ex/blog/issues/60) —
            // a = -k * (x - target) - d * v
            float a = -spring.stiffness * (spring.value - spring.targetValue)
                    - spring.damping   * spring.velocity;

            // integrate velocity
            spring.velocity += a * deltaTime;

            // integrate position
            spring.value    += spring.velocity * deltaTime;
        }

    }

    // Pull the spring with a certain amount of force. This force should be related to the initial value you set to the spring.
    auto pull(Spring &spring, float force, float stiffness, float damping) -> void
    {
        if (!spring.enabled)
        {
            return;
        }
        
        // if stiffness or damping is -1, use the current values
        if (stiffness < 0)
        {
            stiffness = spring.stiffness;
        }
        if (damping < 0)
        {
            damping = spring.damping;
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