#pragma once
#include <vector>
#include <functional>
#include <unordered_map>
#include <string>
#include "ids.hpp"
#include "events.hpp"
#include "effects.hpp"

// Trigger predicate: should this ability fire for this event?
using TriggerPredicate = std::function<bool(const Event&, Context&, entt::entity self)>;

struct Ability {
    Sid name{0};
    TriggerPredicate triggerPredicate; // when to fire
    TargetFunc       collectTargets;   // who to affect
    CompiledEffectGraph effectGraph;   // what to do
    // Runtime controls
    float cooldownSec = 0.f;
    float cooldownLeft = 0.f;
    float internalCooldownSec = 0.f;
    float internalCooldownLeft = 0.f;
};

// Ability database (by Sid)
struct AbilityDatabase {
    std::unordered_map<Sid, Ability> byId;

    const Ability* find(Sid id) const {
        auto it = byId.find(id);
        return it == byId.end() ? nullptr : &it->second;
    }

    Ability& add(const Ability& a) { return byId[a.name] = a; }
};

// Component: which abilities a unit owns
#include "components.hpp"

// System to listen to events and invoke abilities
class AbilitySystem {
public:
    AbilitySystem(EventBus& bus, AbilityDatabase& db) : bus(bus), db(db) {}

    void attachTo(EventType t, int lane, int priority) {
        bus.subscribe(t, EventListener{
            .lane = lane, .priority = priority, .tieBreak = 0,
            .fn = [this](const Event& e, Context& cx){ this->onEvent(e, cx); }
        });
    }

    void tickCooldowns(entt::registry& world, float dtSec) {
        auto view = world.view<KnownAbilities>();
        for (auto e : view) {
            auto& known = view.get<KnownAbilities>(e);
            for (auto ref : known.list) {
                if (auto* a = const_cast<Ability*>(db.find(ref.id))) {
                    a->cooldownLeft = std::max(0.f, a->cooldownLeft - dtSec);
                    a->internalCooldownLeft = std::max(0.f, a->internalCooldownLeft - dtSec);
                }
            }
        }
    }

private:
    void onEvent(const Event& e, Context& cx) {
        // For every unit with abilities, evaluate triggers.
        auto view = cx.world.view<KnownAbilities>();
        for (auto self : view) {
            auto& known = view.get<KnownAbilities>(self);
            for (auto ref : known.list) {
                const Ability* ability = db.find(ref.id);
                if (!ability) continue;
                if (ability->cooldownLeft > 0.f || ability->internalCooldownLeft > 0.f) continue;
                if (!ability->triggerPredicate || !ability->collectTargets) continue;
                if (!ability->triggerPredicate(e, cx, self)) continue;

                std::vector<entt::entity> targets;
                ability->collectTargets(e, cx, targets);
                ExecuteEffectGraph(ability->effectGraph, e, cx, self, targets);

                // Start cooldowns
                const_cast<Ability*>(ability)->cooldownLeft = ability->cooldownSec;
                const_cast<Ability*>(ability)->internalCooldownLeft = ability->internalCooldownSec;
            }
        }
    }

    EventBus& bus;
    AbilityDatabase& db;
};