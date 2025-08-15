#pragma once
#include <vector>
#include <functional>
#include <algorithm>
#include <entt/entt.hpp>
#include "ids.hpp"
#include "stats.hpp"

// Event types your triggers may listen to
enum class EventType : uint16_t {
    BattleStarted,
    TurnStarted, TurnEnded,
    AttackStarted, AttackResolved,
    SpellCastStarted, SpellCastResolved,
    DamageWillBeDealt, DamageDealt, DamageTaken,
    Healed, UnitDied,
    StatusApplied, StatusExpired,
    OnProvoke, OnDefend,
    BuyUnit, SellUnit, RollShop, UpgradeShopTier, ItemBought, 
    AllyLevelUp

};

struct Event {
    EventType type;
    entt::entity source{entt::null};
    entt::entity primaryTarget{entt::null};
    DamageBundle* damage{nullptr}; // optional
};

// The runtime context passed everywhere during resolution
struct Context {
    entt::registry& world;
    // Deterministic RNG seed slice / frame index could live here
};

// Listener with ordering knobs for determinism
struct EventListener {
    int lane = 0;        // e.g., 0 = normal, negative for pre, positive for post
    int priority = 0;    // higher first
    int tieBreak = 0;    // stable tie-breaker (e.g., by OA or position)
    std::function<void(const Event&, Context&)> fn;
};

class EventBus {
public:
    void subscribe(EventType t, EventListener l) {
        auto& vec = listeners[(size_t)t];
        vec.push_back(std::move(l));
        std::stable_sort(vec.begin(), vec.end(), [](const auto& a, const auto& b){
            if (a.lane != b.lane) return a.lane < b.lane; // pre < normal < post
            if (a.priority != b.priority) return a.priority > b.priority; // high first
            return a.tieBreak < b.tieBreak;
        });
    }

    void dispatch(const Event& e, Context& cx) {
        auto& vec = listeners[(size_t)e.type];
        for (auto& l : vec) l.fn(e, cx);
    }

private:
    std::array<std::vector<EventListener>,  (size_t)EventType::UnitDied + 1> listeners{};
};