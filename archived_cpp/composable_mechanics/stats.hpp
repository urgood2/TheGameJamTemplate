#pragma once
#include <array>
#include <cstdint>
#include "ids.hpp"

// ---- Damage types ----
enum class DamageType : uint8_t {
    Physical, Pierce, Bleed, Trauma,
    Fire, Cold, Lightning, Acid, Poison,
    Vitality, VitalityDecay, Aether, Chaos,
    COUNT
};

// ---- Stat IDs (expand as needed) ----
enum class StatId : uint16_t {
    // Primary
    Physique, Cunning, Spirit,
    // Derived core
    OffensiveAbility, DefensiveAbility, CritMultiplier,
    AttackSpeed, CastSpeed, RunSpeed,
    CooldownReduction, SkillCostReduction, HealingIncrease,
    EnergyAbsorb, Constitution, ExperienceGain,
    // Pools
    MaxHP, HPRegen, MaxEnergy, EnergyRegen,
    // Generic damage scalars
    PercentWeaponDamage, PercentAllDamage, CritDamagePercent,
    // Resistances per damage type (example subset)
    Resist_Physical, Resist_Pierce, Resist_Bleed, Resist_Trauma,
    Resist_Fire, Resist_Cold, Resist_Lightning, Resist_Acid, Resist_Poison,
    Resist_Vitality, Resist_VitalityDecay, Resist_Aether, Resist_Chaos,
    // CC resistances
    Resist_Stun, Resist_Slow, Resist_Freeze, Resist_Sleep,
    Resist_Trap, Resist_Petrify, Resist_Disruption,
    Resist_LifeLeech, Resist_EnergyLeech, Resist_Reflect,
    COUNT
};

// Small bit flags for damage source classification
enum DamageTags : uint32_t {
    DmgTag_None         = 0,
    DmgTag_IsWeapon     = 1u << 0,
    DmgTag_IsSkill      = 1u << 1,
    DmgTag_IsShieldSkill= 1u << 2,
};

// Flat + Percent package per damage type
struct DamageBundle {
    float weaponScalar = 1.0f; // e.g., 1.10 => 110% weapon damage
    std::array<float, (size_t)DamageType::COUNT> flat{}; // already split by type
    uint32_t tags = DmgTag_None;
};

// Resistance Reduction types
enum class RRType : uint8_t { Type1PctAdd, Type2PctReduced, Type3Flat };

struct ResistPack {
    // Base resistances (in percent points, e.g., 30 = 30%)
    std::array<float, (size_t)DamageType::COUNT> base{};
    // Per-hit staging (cleared for each resolution)
    std::array<float, (size_t)DamageType::COUNT> rrType1Sum{};  // sum of -X% sources
    std::array<float, (size_t)DamageType::COUNT> rrType2Max{};  // max of X% Reduced
    std::array<float, (size_t)DamageType::COUNT> rrType3Max{};  // max of X flat Reduced
};

struct ShieldStats {
    float blockChance = 0.0f;     // 0..1
    float blockAmount = 0.0f;     // flat block amount
    float recoveryTimeSec = 0.0f; // time between blocks
    float recoveryLeftSec = 0.0f; // runtime gate
};

// Layered stat storage for one unit
struct Stats {
    std::array<float, (size_t)StatId::COUNT> base{};  // base values
    std::array<float, (size_t)StatId::COUNT> add{};   // sum of flat bonuses
    std::array<float, (size_t)StatId::COUNT> mul{};   // sum of percent bonuses (0.25 = +25%)
    std::array<float, (size_t)StatId::COUNT> final{}; // cached final values

    void ClearAddMul() {
        add.fill(0.f); mul.fill(0.f);
    }
    void RecomputeFinal() {
        for (size_t i = 0; i < final.size(); ++i) {
            final[i] = (base[i] + add[i]) * (1.0f + mul[i]);
        }
    }

    float operator[](StatId id) const { return final[(size_t)id]; }
    float& Base(StatId id) { return base[(size_t)id]; }
    void   AddFlat(StatId id, float v) { add[(size_t)id] += v; }
    void   AddPercent(StatId id, float v) { mul[(size_t)id] += v; }
};

// Health/Energy pools (separate from Stats to let effects address them directly)
struct LifeEnergy {
    float hp = 0.f, maxHp = 0.f;
    float energy = 0.f, maxEnergy = 0.f;
};

// Team alignment for simple targeters
struct Team {
    uint8_t teamId = 0; // 0 = player, 1 = enemy, etc.
};