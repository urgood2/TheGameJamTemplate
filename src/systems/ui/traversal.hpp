// src/systems/ui/traversal.hpp
// Generic UI tree traversal utilities for box.cpp refactoring.
// Part of the Phase 2 utility extraction.
#pragma once

#include <entt/entt.hpp>
#include <functional>
#include <vector>
#include <stack>
#include <algorithm>
#include "systems/transform/transform.hpp"
#include "systems/ui/ui_data.hpp"

namespace ui::traversal {

enum class Order { TopDown, BottomUp };

/// Traverse UI tree, calling visitor on each entity
/// @param reg The entity registry
/// @param root The root entity to start traversal from
/// @param visitor Callable that takes (entt::entity)
/// @param order TopDown (parent before children) or BottomUp (children before parent)
template<typename Visitor>
void forEachInTree(entt::registry& reg, entt::entity root,
                   Visitor&& visitor, Order order = Order::TopDown) {
    if (!reg.valid(root)) return;

    std::vector<entt::entity> nodes;
    std::stack<entt::entity> stack;
    stack.push(root);

    // Collect all nodes in top-down order
    while (!stack.empty()) {
        auto e = stack.top();
        stack.pop();
        if (!reg.valid(e)) continue;

        nodes.push_back(e);

        if (auto* node = reg.try_get<transform::GameObject>(e)) {
            // Push in reverse for correct left-to-right order
            for (auto it = node->orderedChildren.rbegin();
                 it != node->orderedChildren.rend(); ++it) {
                if (reg.valid(*it)) stack.push(*it);
            }
        }
    }

    // Reverse if bottom-up traversal requested
    if (order == Order::BottomUp) {
        std::reverse(nodes.begin(), nodes.end());
    }

    // Visit each node
    for (auto e : nodes) {
        visitor(e);
    }
}

/// Traverse UI tree including owned objects (UIConfig.object)
/// This also visits any object entities attached to UI elements.
/// @param reg The entity registry
/// @param root The root entity to start traversal from
/// @param visitor Callable that takes (entt::entity)
/// @param order TopDown or BottomUp
template<typename Visitor>
void forEachWithObjects(entt::registry& reg, entt::entity root,
                        Visitor&& visitor, Order order = Order::TopDown) {
    forEachInTree(reg, root, [&](entt::entity e) {
        visitor(e);
        if (auto* cfg = reg.try_get<UIConfig>(e)) {
            if (cfg->object && reg.valid(*cfg->object)) {
                visitor(*cfg->object);
            }
        }
    }, order);
}

/// Collect all entities in a UI tree into a vector
/// @param reg The entity registry
/// @param root The root entity
/// @param order TopDown or BottomUp
/// @return Vector of all entities in the tree
inline std::vector<entt::entity> collectTree(entt::registry& reg, entt::entity root,
                                              Order order = Order::TopDown) {
    std::vector<entt::entity> result;
    forEachInTree(reg, root, [&result](entt::entity e) {
        result.push_back(e);
    }, order);
    return result;
}

/// Count entities in a UI tree
/// @param reg The entity registry
/// @param root The root entity
/// @return Number of entities in the tree
inline size_t countTree(entt::registry& reg, entt::entity root) {
    size_t count = 0;
    forEachInTree(reg, root, [&count](entt::entity) { ++count; });
    return count;
}

/// Find first entity matching a predicate
/// @param reg The entity registry
/// @param root The root entity
/// @param predicate Callable returning true for match
/// @return Matching entity or entt::null if not found
template<typename Predicate>
entt::entity findFirst(entt::registry& reg, entt::entity root, Predicate&& predicate) {
    entt::entity found = entt::null;
    forEachInTree(reg, root, [&](entt::entity e) {
        if (found == entt::null && predicate(e)) {
            found = e;
        }
    });
    return found;
}

/// Find all entities matching a predicate
/// @param reg The entity registry
/// @param root The root entity
/// @param predicate Callable returning true for match
/// @return Vector of matching entities
template<typename Predicate>
std::vector<entt::entity> findAll(entt::registry& reg, entt::entity root, Predicate&& predicate) {
    std::vector<entt::entity> result;
    forEachInTree(reg, root, [&](entt::entity e) {
        if (predicate(e)) {
            result.push_back(e);
        }
    });
    return result;
}

} // namespace ui::traversal
