#pragma once
#include <entt/entt.hpp>
#include "events.hpp"
/*
    This should be customized based on the mechanics of the game
    and the layout of the game board/world.
*/

// Position on a 1D line per team (front = index 0 by convention)
struct BoardPos {
    int lane = 0;   // support multi-lane later; 0 for single-lane SAP-like
    int index = -1; // 0..N-1 from front to back
};

inline bool IsAhead(const BoardPos& a, const BoardPos& b) {
    return (a.lane == b.lane) && (a.index < b.index);
}

struct BoardHelpers {
    // Returns entity directly ahead (index-1) if any
    static entt::entity AllyAhead(entt::registry& r, entt::entity e) {
        auto* pa = r.try_get<BoardPos>(e); if (!pa) return entt::null;
        auto view = r.view<BoardPos, Team>();
        auto* ta = r.try_get<Team>(e);
        entt::entity best = entt::null; int want = pa->index - 1;
        for (auto it : view) {
            auto& p = view.get<BoardPos>(it);
            auto& t = view.get<Team>(it);
            if (t.teamId == ta->teamId && p.lane == pa->lane && p.index == want) { best = it; break; }
        }
        return best;
    }

    // N allies behind including gaps
    static void AlliesBehind(entt::registry& r, entt::entity e, int n, std::vector<entt::entity>& out) {
        auto* pa = r.try_get<BoardPos>(e); if (!pa) return;
        auto* ta = r.try_get<Team>(e); if (!ta) return;
        int start = pa->index + 1;
        auto view = r.view<BoardPos, Team>();
        for (int k=0; k<n; ++k) {
            int want = start + k;
            for (auto it : view) {
                auto& p = view.get<BoardPos>(it); auto& t = view.get<Team>(it);
                if (t.teamId==ta->teamId && p.lane==pa->lane && p.index==want) { out.push_back(it); break; }
            }
        }
    }

    // Adjacent allies (index-1 and index+1)
    static void Adjacent(entt::registry& r, entt::entity e, std::vector<entt::entity>& out) {
        auto* pa = r.try_get<BoardPos>(e); if (!pa) return;
        auto* ta = r.try_get<Team>(e); if (!ta) return;
        auto view = r.view<BoardPos, Team>();
        for (auto it : view) {
            auto& p = view.get<BoardPos>(it); auto& t = view.get<Team>(it);
            if (t.teamId==ta->teamId && p.lane==pa->lane && (p.index==pa->index-1 || p.index==pa->index+1))
                out.push_back(it);
        }
    }
};