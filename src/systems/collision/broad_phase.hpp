#pragma once

#include <unordered_map>
#include <vector>
#include <utility>
#include <cmath>
#include <array>
#include <entt/entt.hpp>

#include "systems/transform/transform_functions.hpp"
#include "util/common_headers.hpp"



namespace collision {
        
    struct AABB {
        float x, y, w, h;
    };

    inline bool AABBOverlap(const AABB &a, const AABB &b) {
        return !(a.x + a.w < b.x || b.x + b.w < a.x ||
                a.y + a.h < b.y || b.y + b.h < a.y);
    }

    inline AABB MakeAABBFromEntity(entt::registry &registry, entt::entity e) {
        auto &t = registry.get<transform::Transform>(e);

        float scale = t.getVisualScaleWithHoverAndDynamicMotionReflected();

        //TODO: this right? scale should be applied to the width and height?
        float width = t.getVisualW() * scale;
        float height = t.getVisualH() * scale;

        return AABB{
            t.getVisualX(),
            t.getVisualY(),
            width,
            height
        };
    }
    
    namespace std {
    template<>
    struct hash<std::pair<int, int>> {
        auto operator()(const std::pair<int, int>& p) const noexcept -> size_t {
            // Basic hash combiner
            return hash<int>()(p.first) ^ (hash<int>()(p.second) << 1);
        }
    };
}

    class BroadPhaseGrid {
    public:
        using GridKey = std::pair<int, int>;

        BroadPhaseGrid(float cellSize = 128.0f)
            : m_cellSize(cellSize) {}

        void Clear() {
            m_grid.clear();
        }

        void Insert(entt::entity e, const AABB &aabb) {
            GridKey key = GetGridKey(aabb.x, aabb.y);
            m_grid[key].push_back({e, aabb});
        }

        void InsertAutoAABB(entt::registry &registry, entt::entity e) {
            AABB aabb = MakeAABBFromEntity(registry, e);
            Insert(e, aabb);
        }

        template <typename Func>
        void ForEachPossibleCollision(Func &&callback) {
            static const std::array<GridKey, 9> neighborOffsets = {{
                {-1, -1}, {0, -1}, {1, -1},
                {-1,  0}, {0,  0}, {1,  0},
                {-1,  1}, {0,  1}, {1,  1}
            }};

            for (const auto &[cell, list] : m_grid) {
                for (size_t i = 0; i < list.size(); ++i) {
                    for (size_t j = i + 1; j < list.size(); ++j) {
                        callback(list[i].first, list[j].first);
                    }
                }

                for (const auto &[dx, dy] : neighborOffsets) {
                    if (dx == 0 && dy == 0) continue;
                    GridKey neighbor = {cell.first + dx, cell.second + dy};
                    if (m_grid.find(neighbor) == m_grid.end()) continue;

                    for (auto &[e1, a1] : list) {
                        for (auto &[e2, a2] : m_grid[neighbor]) {
                            if (AABBOverlap(a1, a2)) {
                                callback(e1, e2);
                            }
                        }
                    }
                }
            }
        }

        std::vector<entt::entity> FindOverlapsWith(entt::registry &registry, BroadPhaseGrid &broadphase, entt::entity entityA) {
        AABB target = MakeAABBFromEntity(registry, entityA);
        auto key = broadphase.GetGridKey(target.x, target.y);

        std::vector<entt::entity> results;

        // Check this cell and neighbors
        std::array<std::pair<int, int>, 9> neighborOffsets = {{
            {-1, -1}, {0, -1}, {1, -1},
            {-1,  0}, {0,  0}, {1,  0},
            {-1,  1}, {0,  1}, {1,  1}
        }};

        for (auto [dx, dy] : neighborOffsets) {
            auto neighborKey = std::make_pair(key.first + dx, key.second + dy);
            auto it = broadphase.m_grid.find(neighborKey);
            if (it == broadphase.m_grid.end()) continue;

            for (auto &[otherE, otherAABB] : it->second) {
                if (otherE == entityA) continue; // skip self
                if (AABBOverlap(target, otherAABB)) {
                    results.push_back(otherE);
                }
            }
        }

        return results;
    }

    private:
        float m_cellSize;

        GridKey GetGridKey(float x, float y) const {
            return {
                static_cast<int>(std::floor(x / m_cellSize)),
                static_cast<int>(std::floor(y / m_cellSize))
            };
        }

        std::unordered_map<GridKey, std::vector<std::pair<entt::entity, AABB>>> m_grid;
    };
    
}