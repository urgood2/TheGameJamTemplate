#pragma once
#include <algorithm>
#include <cmath>
#include "stats.hpp"

// OffensiveAbility vs DefensiveAbility → PTH and crit bucket using your formula
struct HitResult {
    float pth = 0.f;         // Percent To Hit, 0..100
    float damageScalar = 1.f; // sub-75 clamp, crit tiers above 90
    float critChance = 0.f;  // pth - 90 if pth > 90
    float critMultiplier = 1.f; // up to 3.5x (from stats or tier caps)
};

inline float ComputePTH(float oa, float da) {
    // PTH = 3.15 * (OA / (3.5 OA + DA)) + 0.0002275 * (OA - DA) + 0.2
    // Output domain is 0..1; we'll scale to 0..100
    if (oa < 1.f) oa = 1.f; if (da < 1.f) da = 1.f;
    float p = 3.15f * (oa / (3.5f * oa + da)) + 0.0002275f * (oa - da) + 0.2f;
    p = std::clamp(p, 0.0f, 1.0f);
    return p * 100.0f;
}

inline HitResult ResolveHitAndCrit(float oa, float da, float unitCritMultiplierStat) {
    HitResult hr{};
    hr.pth = ComputePTH(oa, da);

    // Floor at 60% (never below 60 to hit)
    hr.pth = std::max(60.0f, hr.pth);

    // Sub-75: scale damage down linearly (pth/75)
    if (hr.pth < 75.0f) {
        hr.damageScalar = hr.pth / 75.0f;
        hr.critChance = 0.f;
        hr.critMultiplier = 1.f;
        return hr;
    }

    // 90+: crit chance = pth - 90
    if (hr.pth > 90.0f) {
        hr.critChance = std::min(100.0f, hr.pth - 90.0f);
        // Crit tiers for damage scalar (example mapping; adjust as desired)
        // Thresholds from your spec: 90,105,120,130,135 → 1.1,1.2,1.3,1.4,1.5
        if      (hr.pth >= 135.0f) hr.damageScalar = 1.5f;
        else if (hr.pth >= 130.0f) hr.damageScalar = 1.4f;
        else if (hr.pth >= 120.0f) hr.damageScalar = 1.3f;
        else if (hr.pth >= 105.0f) hr.damageScalar = 1.2f;
        else                        hr.damageScalar = 1.1f; // 90..105
        // Cap with unit stat (max x3.5)
        hr.critMultiplier = std::clamp(unitCritMultiplierStat, 1.0f, 3.5f);
    } else {
        hr.damageScalar = 1.0f;
        hr.critMultiplier = 1.0f;
    }
    return hr;
}

// Resistance Reduction order: Type1 (sum), then Type2 (max, multiplicative, cannot push below 0 here), then Type3 (max, flat)
inline float ApplyRROrdered(float baseResPct, float type1SumPct, float type2PctReduced, float type3Flat) {
    float r = baseResPct - type1SumPct;                        // can go < 0
    r = r * (1.0f - std::max(0.0f, type2PctReduced));          // multiplicative, this step cannot push below 0 itself
    r = r - type3Flat;                                         // can go < 0
    return r;
}

// Armor: 70% mitigated within protection (modified by absorption multiplier), 30% always passes; overflow passes fully
inline float ApplyArmor(float rawPhysicalDamage, float armorProtection, float absorptionMultiplier /* e.g., 1.2 for +20% */) {
    if (rawPhysicalDamage <= 0.0f || armorProtection <= 0.0f) return rawPhysicalDamage;
    const float within = std::min(rawPhysicalDamage, armorProtection);
    const float overflow = std::max(0.0f, rawPhysicalDamage - armorProtection);
    const float baseAbsorb = 0.70f * absorptionMultiplier; // e.g., 0.84 with +20%
    const float absorbed = within * std::clamp(baseAbsorb, 0.0f, 1.0f);
    const float passedWithin = within - absorbed; // at least 30% baseline unless absorption raised it
    return passedWithin + overflow;
}