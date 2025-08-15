#include "pipelines.hpp"
#include "components.hpp"
#include "events.hpp"
#include <algorithm>

// Helper: pull a stat quickly
static inline float S(const Stats& s, StatId id) { return s.final[(size_t)id]; }

void ResolveAndApplyDamage(entt::entity attacker,
                           entt::entity defender,
                           DamageBundle& bundle,
                           Context& cx,
                           bool emitEvents) {
    auto& world = cx.world;
    auto& atkStats = world.get<Stats>(attacker);
    auto& defStats = world.get<Stats>(defender);
    auto& resist   = world.get<ResistPack>(defender);
    auto& defPools = world.get<LifeEnergy>(defender);

    // 1) OA vs DA → PTH, crit
    HitResult hr = ResolveHitAndCrit(
        S(atkStats, StatId::OffensiveAbility),
        S(defStats, StatId::DefensiveAbility),
        S(atkStats, StatId::CritMultiplier));

    // This skeleton doesn't roll RNG; treat pth < 100 as "hit" for deterministic demo.
    // You can integrate a deterministic RNG slice here.

    // 2) Apply RR staging (defender may have accumulated rr from effects this frame)
    // We'll build a working resistance array per damage type.
    std::array<float,(size_t)DamageType::COUNT> effectiveRes{};
    for (size_t t = 0; t < (size_t)DamageType::COUNT; ++t) {
        float base = resist.base[t];
        float r = ApplyRROrdered(base, resist.rrType1Sum[t], resist.rrType2Max[t], resist.rrType3Max[t]);
        effectiveRes[t] = r; // can be below 0
    }

    // Clear RR staging after consumption (per-hit window)
    resist.rrType1Sum.fill(0.f); resist.rrType2Max.fill(0.f); resist.rrType3Max.fill(0.f);

    // 3) Build raw damage per type from bundle + weapon scaling
    // For demo: assume weaponScalar multiplies Physical only; adapt as needed.
    std::array<float,(size_t)DamageType::COUNT> dmg = bundle.flat;
    dmg[(size_t)DamageType::Physical] *= bundle.weaponScalar;

    // 4) Apply crit scalar (this demo just multiplies all types on crit tiers)
    dmg[(size_t)DamageType::Physical] *= hr.damageScalar;
    
    // Consume NextHitMitigation before resists/armor
    if (auto* nh = world.try_get<NextHitMitigation>(defender)) {
        for (auto& v : dmg) v *= (1.f - std::clamp(nh->pct, 0.f, 1.f));
        world.remove<NextHitMitigation>(defender);
    }

    // 5) Apply resistances (clamp resist to, e.g., -∞..80 for demo; you can add caps)
    for (size_t t = 0; t < dmg.size(); ++t) {
        float res = effectiveRes[t];
        float factor = 1.0f - (res / 100.0f);
        dmg[t] *= factor;
    }

    // 6) Armor for physical portion (70% within protection; we map armor to StatId::Resist_Physical as protection here)
    // In a real build, you'd have explicit ArmorProtection + Absorption stats per slot.
    float armorProtection = S(defStats, StatId::Resist_Physical); // repurpose for demo
    float absorptionMult = 1.0f; // derive from stats
    dmg[(size_t)DamageType::Physical] = ApplyArmor(dmg[(size_t)DamageType::Physical], armorProtection, absorptionMult);

    // 7) Sum and apply to HP
    float total = 0.f; for (float v : dmg) total += v;
    defPools.hp = std::max(0.0f, defPools.hp - total);

    if (emitEvents) {
        Event dealt{ EventType::DamageDealt, attacker, defender, nullptr };
        Event taken{ EventType::DamageTaken, defender, attacker, nullptr };
        cx.world.ctx<EventBus>().dispatch(dealt, cx);
        cx.world.ctx<EventBus>().dispatch(taken, cx);
    }
}