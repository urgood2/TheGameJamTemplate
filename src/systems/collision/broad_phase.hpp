#pragma once

#include <unordered_map>
#include <vector>
#include <utility>
#include <cmath>
#include <array>
#include <entt/entt.hpp>

#include "systems/transform/transform_functions.hpp"
#include "util/common_headers.hpp"


namespace std {
    template<>
    struct hash<std::pair<int, int>> {
        auto operator()(const std::pair<int, int>& p) const noexcept -> size_t {
            // Basic hash combiner
            return hash<int>()(p.first) ^ (hash<int>()(p.second) << 1);
        }
    };
}

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
    
    class BroadPhaseGrid {
    public:
        using GridKey = ::std::pair<int, int>;

        BroadPhaseGrid(float cellSize = 128.0f)
            : m_cellSize(cellSize) {}

        void Clear() {
            m_grid.clear();
        }

        void Insert(entt::entity e, const AABB &aabb) {
            int minX = static_cast<int>(std::floor(aabb.x / m_cellSize));
            int maxX = static_cast<int>(std::floor((aabb.x + aabb.w) / m_cellSize));
            int minY = static_cast<int>(std::floor(aabb.y / m_cellSize));
            int maxY = static_cast<int>(std::floor((aabb.y + aabb.h) / m_cellSize));
        
            for (int gx = minX; gx <= maxX; ++gx) {
                for (int gy = minY; gy <= maxY; ++gy) {
                    m_grid[{gx, gy}].push_back({e, aabb});
                }
            }
        }

        void InsertAutoAABB(entt::registry &registry, entt::entity e) {
            AABB aabb = MakeAABBFromEntity(registry, e);
            Insert(e, aabb);
        }

        /**
         * @brief Iterates over all potentially colliding entity pairs in the broadphase grid.
         * 
         * This function checks for possible overlaps within each grid cell and across neighboring cells.
         * It ensures that each unique pair of entities is only considered once, even if both entities
         * are present in multiple cells (e.g., due to large AABBs spanning several grid tiles).
         * 
         * The provided callback will be invoked with two entities (entt::entity a, entt::entity b)
         * that may potentially be colliding based on AABB intersection.
         * 
         * @tparam Func A callable type that takes two entt::entity arguments.
         * @param callback A function or lambda to be called for each unique potentially overlapping pair.
         * 
         * @note Uses an internal unordered_set<uint64_t> to deduplicate entity pairs efficiently.
         * @note Entities are considered overlapping only if their AABBs actually intersect.
         */
        template <typename Func>
        void ForEachPossibleCollision(Func &&callback) {
            static const std::array<GridKey, 9> neighborOffsets = {{
                {-1, -1}, {0, -1}, {1, -1},
                {-1,  0}, {0,  0}, {1,  0},
                {-1,  1}, {0,  1}, {1,  1}
            }};

            std::unordered_set<uint64_t> checkedPairs;

            auto makePairKey = [](entt::entity a, entt::entity b) -> uint64_t {
                uint32_t idA = static_cast<uint32_t>(a);
                uint32_t idB = static_cast<uint32_t>(b);
                if (idA > idB) std::swap(idA, idB);
                return (static_cast<uint64_t>(idA) << 32) | idB;
            };

            for (const auto &[cell, list] : m_grid) {
                // Within same cell
                for (size_t i = 0; i < list.size(); ++i) {
                    for (size_t j = i + 1; j < list.size(); ++j) {
                        entt::entity a = list[i].first;
                        entt::entity b = list[j].first;
                        uint64_t key = makePairKey(a, b);
                        if (checkedPairs.insert(key).second) {
                            callback(a, b);
                        }
                    }
                }

                // Cross-cell comparisons
                for (const auto &[dx, dy] : neighborOffsets) {
                    if (dx == 0 && dy == 0) continue;
                    GridKey neighbor = {cell.first + dx, cell.second + dy};
                    auto it = m_grid.find(neighbor);
                    if (it == m_grid.end()) continue;

                    for (auto &[e1, a1] : list) {
                        for (auto &[e2, a2] : it->second) {
                            if (e1 == e2 || !AABBOverlap(a1, a2)) continue;
                            uint64_t key = makePairKey(e1, e2);
                            if (checkedPairs.insert(key).second) {
                                callback(e1, e2);
                            }
                        }
                    }
                }
            }
        }


        /**
         * @brief Returns a list of entities whose AABBs overlap with the given entity's AABB.
         * 
         * This function determines the spatial region covered by the target entity's AABB
         * and checks all overlapping grid cells for other entities with intersecting AABBs.
         * 
         * The result is deduplicated — entities that appear in multiple overlapping cells
         * are returned only once. The target entity is excluded from the results.
         * 
         * @param registry The EnTT registry used to retrieve transform components.
         * @param broadphase The current broadphase grid storing spatial partition data.
         * @param entityA The entity for which overlaps are to be detected.
         * @return std::vector<entt::entity> A deduplicated list of entities overlapping with entityA.
         * 
         * @note AABB calculations are derived from the entity's transform component.
         */
        std::vector<entt::entity> FindOverlapsWith(entt::registry &registry, BroadPhaseGrid &broadphase, entt::entity entityA) {
            AABB target = MakeAABBFromEntity(registry, entityA);
        
            int minX = static_cast<int>(std::floor(target.x / broadphase.m_cellSize));
            int maxX = static_cast<int>(std::floor((target.x + target.w) / broadphase.m_cellSize));
            int minY = static_cast<int>(std::floor(target.y / broadphase.m_cellSize));
            int maxY = static_cast<int>(std::floor((target.y + target.h) / broadphase.m_cellSize));
        
            std::unordered_set<entt::entity> seen;
            std::vector<entt::entity> results;
        
            for (int gx = minX; gx <= maxX; ++gx) {
                for (int gy = minY; gy <= maxY; ++gy) {
                    auto it = broadphase.m_grid.find({gx, gy});
                    if (it == broadphase.m_grid.end()) continue;
        
                    for (auto &[otherE, otherAABB] : it->second) {
                        if (otherE == entityA || seen.count(otherE)) continue;
                        if (AABBOverlap(target, otherAABB)) {
                            seen.insert(otherE);
                            results.push_back(otherE);
                        }
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

        ::std::unordered_map<GridKey, std::vector<std::pair<entt::entity, AABB>>> m_grid;
    };
    
}