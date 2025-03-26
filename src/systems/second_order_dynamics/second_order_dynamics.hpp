#pragma once

#include "util/common_headers.hpp"
#include "entt/entt.hpp"
#include "raymath.h"

namespace SecondOrderDynamics {

    /**
     * Generic structure for SecondOrderDynamics, works with float or Vector2.
     */
    template <typename T>
    struct SecondOrderDynamicsData {
        T xp;  // Previous input (target value from last frame)
        T y, yd; // State variables: y = smoothed position, yd = velocity
        float _w, _z, _d, k1, k2, k3; // Internal constants
    };

    /**
     * Initializes the second-order system for a given entity.
     *
     * @param registry The EnTT registry.
     * @param e The entity to initialize dynamics for.
     * @param f Frequency in Hz (higher = faster response).
     * @param z Damping coefficient (higher = less oscillation).
     * @param r Response factor (controls overshoot & anticipation).
     * @param x0 Initial position (float or Vector2).
     */
    template <typename T>
    inline auto init(entt::registry &registry, entt::entity e, float f, float z, float r, T x0) {
        auto &data = registry.emplace_or_replace<SecondOrderDynamicsData<T>>(e);

        // Compute constants
        data._w = 2 * PI * f;
        data._z = z;
        data._d = data._w * sqrt(fabs(data._z * data._z - 1.0f));
        data.k1 = data._z / (PI * f);
        data.k2 = 1 / (data._w * data._w);
        data.k3 = r * data._z / data._w;

        // Initialize state variables
        data.xp = x0;
        data.y = x0;
        data.yd = T{}; // Initialize velocity to zero
    }

    /**
     * Updates the second-order system, adjusting `y` based on target `x`.
     *
     * @param registry The EnTT registry.
     * @param T Time step (delta time).
     * @param x Target position (float or Vector2).
     * @param xd Optional velocity; estimated if not provided.
     */
    template <typename T>
    inline auto update(entt::registry &registry, float deltaTime, T x, T xd = T{}) {
        auto view = registry.view<SecondOrderDynamicsData<T>>();
        for (auto e : view) {
            auto &data = view.template get<SecondOrderDynamicsData<T>>(e);

            // If velocity is not provided, estimate it
            if (xd == T{}) {
                xd = (x - data.xp) / deltaTime;
                data.xp = x; // Store as previous input
            }

            float k1_stable, k2_stable;
            if (data._w * deltaTime < data._z) { 
                k1_stable = data.k1;
                k2_stable = std::max(data.k2, deltaTime * deltaTime * data.k1 / 2.0f);
            } else {
                float t1 = expf(-data._z * data._w * deltaTime);
                float alpha = 2 * t1 * (data._z <= 1 ? cosf(deltaTime * data._d) : coshf(deltaTime * data._d));
                float beta = t1 * t1;
                float t2 = 1 / (1 + beta - alpha);
                k1_stable = (1 - beta) * t2;
                k2_stable = deltaTime * t2;
            }

            // Update position by velocity
            data.y += deltaTime * data.yd;

            // Update velocity by acceleration
            data.yd += deltaTime * ((x + data.k3 * xd - data.y - data.k1 * data.yd) / k2_stable);
        }
    }

    /**
     * Retrieves the current smoothed value (`y`).
     */
    template <typename T>
    inline auto getCurrentValue(entt::registry &registry, entt::entity e) -> T {
        return registry.get<SecondOrderDynamicsData<T>>(e).y;
    }

    /**
     * Retrieves the previous input (`xp`).
     */
    template <typename T>
    inline auto getTargetValue(entt::registry &registry, entt::entity e) -> T {
        return registry.get<SecondOrderDynamicsData<T>>(e).xp;
    }

}; // namespace SecondOrderDynamics
