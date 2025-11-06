#include "spring_pool.hpp"
#include "third_party/tracy-master/public/tracy/Tracy.hpp"

// Only include SIMD intrinsics if we are on x86/x64
#if defined(__x86_64__) || defined(_M_X64) || defined(__i386__) || defined(_M_IX86)
    #include <immintrin.h>
    #define SPRINGPOOL_USE_AVX2 1
#else
    #define SPRINGPOOL_USE_AVX2 0
#endif

namespace spring {

SpringPool gPool;

//------------------------------------------------------------
// Register spring in pool (call after emplace<Spring>())
//------------------------------------------------------------
void registerSpring(entt::registry &r, entt::entity e) {
    auto &s = r.get<Spring>(e);
    s.poolIndex = gPool.add(e, s);
}

//------------------------------------------------------------
// SIMD-optimized update loop
//------------------------------------------------------------
void updateSpringPool(float dt) {
    ZoneScopedN("SpringPool::updateAll");
    const size_t count = gPool.value.size();
    if (count == 0) return;

#if defined(__EMSCRIPTEN__)
    // --- WebAssembly SIMD128 or scalar fallback ---
    for (size_t i = 0; i < count; ++i) {
        float mask = gPool.enabled[i] ? 1.f : 0.f;
        float a = (-gPool.stiffness[i] * (gPool.value[i] - gPool.target[i])
                   - gPool.damping[i] * gPool.velocity[i]) * mask;
        gPool.velocity[i] += a * dt;
        gPool.value[i] += gPool.velocity[i] * dt;
    }

#elif SPRINGPOOL_USE_AVX2
    // --- Native x86/x64 AVX2 path ---
    const size_t step = 8;
    const size_t aligned = count - (count % step);
    const __m256 vdt   = _mm256_set1_ps(dt);
    const __m256 vneg1 = _mm256_set1_ps(-1.f);

    size_t i = 0;
    for (; i < aligned; i += step) {
        __m256 vVal = _mm256_loadu_ps(&gPool.value[i]);
        __m256 vTar = _mm256_loadu_ps(&gPool.target[i]);
        __m256 vVel = _mm256_loadu_ps(&gPool.velocity[i]);
        __m256 vK   = _mm256_loadu_ps(&gPool.stiffness[i]);
        __m256 vD   = _mm256_loadu_ps(&gPool.damping[i]);

        __m256 vDiff = _mm256_sub_ps(vVal, vTar);
        __m256 vA = _mm256_fmadd_ps(vD, vVel, _mm256_mul_ps(vK, vDiff));
        vA = _mm256_mul_ps(vA, vneg1);
        vA = _mm256_mul_ps(vA, vdt);

        vVel = _mm256_add_ps(vVel, vA);
        vVal = _mm256_fmadd_ps(vVel, vdt, vVal);

        _mm256_storeu_ps(&gPool.velocity[i], vVel);
        _mm256_storeu_ps(&gPool.value[i], vVal);
    }

    for (; i < count; ++i) {
        if (!gPool.enabled[i]) continue;
        float a = -gPool.stiffness[i] * (gPool.value[i] - gPool.target[i])
                - gPool.damping[i] * gPool.velocity[i];
        gPool.velocity[i] += a * dt;
        gPool.value[i] += gPool.velocity[i] * dt;
    }

#else
    // --- Generic scalar fallback (ARM, Apple Silicon, etc.) ---
    for (size_t i = 0; i < count; ++i) {
        if (!gPool.enabled[i]) continue;
        float a = -gPool.stiffness[i] * (gPool.value[i] - gPool.target[i])
                - gPool.damping[i] * gPool.velocity[i];
        gPool.velocity[i] += a * dt;
        gPool.value[i] += gPool.velocity[i] * dt;
    }
#endif
}

} // namespace spring
