#pragma once
#include <random>
#include "events.hpp"
#include "components.hpp"
#include "util/common_headers.hpp"


// define targeting function
using TargetFunc = std::function<void(const Event&, Context&, std::vector<entt::entity>&)>;

// Helper: are two entities on the same team?
inline bool SameTeam(entt::registry& world, entt::entity a, entt::entity b) {
    auto ta = world.try_get<Team>(a);
    auto tb = world.try_get<Team>(b);
    return ta && tb && ta->teamId == tb->teamId;
}

// Self
static inline TargetFunc TargetSelf() {
    return [](const Event& e, Context& cx, std::vector<entt::entity>& out){
        // if (e.source != entt::null) out.push_back(e.source);
    };
}

// Primary target (e.g., the enemy you clicked)
static inline TargetFunc TargetPrimary() {
    return [](const Event& e, Context& cx, std::vector<entt::entity>& out){
        // if (e.primaryTarget != entt::null) out.push_back(e.primaryTarget);
    };
}

// All enemies of the source
static inline TargetFunc TargetAllEnemies() {
    return [](const Event& e, Context& cx, std::vector<entt::entity>& out){
        if (e.source == entt::null) return;
        auto& world = cx.world;
        auto view = world.view<Team>();
        for (auto ent : view) {
            if (!SameTeam(world, ent, e.source)) out.push_back(ent);
        }
    };
}

// Random allies (n) excluding self by default
static inline TargetFunc TargetRandomAllies(int n, bool includeSelf=false) {
    return [n, includeSelf](const Event& e, Context& cx, std::vector<entt::entity>& out){
        if (e.source == entt::null) return;
        std::vector<entt::entity> pool;
        auto& world = cx.world;
        auto view = world.view<Team>();
        for (auto ent : view) {
            if (SameTeam(world, ent, e.source)) {
                if (!includeSelf && ent == e.source) continue;
                pool.push_back(ent);
            }
        }
        // Deterministic pick: naive first N (replace with seeded shuffle)
        if ((int)pool.size() <= n) out = pool; else out.assign(pool.begin(), pool.begin()+n);
    };
}

// Ally ahead of self
static inline TargetFunc TargetAllyAhead() {
    return [](const Event& e, Context& cx, std::vector<entt::entity>& out){
        if (e.source == entt::null) return;
        auto ahead = BoardHelpers::AllyAhead(cx.world, e.source);
        if (ahead != entt::null) out.push_back(ahead);
    };
}

// N allies behind self
static inline TargetFunc TargetAlliesBehind(int n) {
    return [n](const Event& e, Context& cx, std::vector<entt::entity>& out){
        if (e.source == entt::null) return;
        BoardHelpers::AlliesBehind(cx.world, e.source, n, out);
    };
}

// Nth ally (1-based from front)
static inline TargetFunc TargetNthAlly(int n) {
    return [n](const Event& e, Context& cx, std::vector<entt::entity>& out){
        auto view = cx.world.view<BoardPos, Team>();
        if (e.source==entt::null) return;
        auto* ts = cx.world.try_get<Team>(e.source); if (!ts) return;
        for (auto it : view) {
            auto& p = view.get<BoardPos>(it); auto& t = view.get<Team>(it);
            if (t.teamId==ts->teamId && p.index==(n-1)) { out.push_back(it); break; }
        }
    };
}

// Two adjacent allies
static inline TargetFunc TargetTwoAdjacentAllies() {
    return [](const Event& e, Context& cx, std::vector<entt::entity>& out){
        if (e.source==entt::null) return;
        BoardHelpers::Adjacent(cx.world, e.source, out);
        if (out.size()>2) out.resize(2);
    };
}