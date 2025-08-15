#pragma once
#include <vector>
#include "stats.hpp"
#include "ids.hpp"

// Active buffs / auras
struct BuffInstance {
    Sid id{0};
    float timeLeftSec{0.f};
    uint8_t stacks{1};
    Sid stackingKey{0}; // for unique/replace policies

    // Packed stat deltas for this buff
    std::array<float, (size_t)StatId::COUNT> add{};
    std::array<float, (size_t)StatId::COUNT> mul{};
};

struct ActiveBuffs { std::vector<BuffInstance> list; };

// Ability reference component (what a unit can use)
struct AbilityRef { Sid id{0}; };
struct KnownAbilities { std::vector<AbilityRef> list; };

// Simple status flags (for demo). Extend with rich data as needed.
struct StatusFlags {
    bool isChilled = false;
    bool isFrozen = false;
    bool isStunned = false;
};

struct HeldItem { Sid id{0}; };
struct Level { int level=1; };
struct Experience { int xp=0; };
struct ClassTags { std::vector<Sid> tags; };
inline bool HasClass(const ClassTags& c, Sid tag){ return std::find(c.tags.begin(), c.tags.end(), tag) != c.tags.end(); }
struct NextHitMitigation { float pct = 0.5f; };