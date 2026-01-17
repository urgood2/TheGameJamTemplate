// src/systems/ui/sizing_pass.hpp
// Encapsulates the multi-pass layout sizing algorithm for UI trees.
// Part of the Phase 4 CalcTreeSizes refactoring.
//
// This class breaks down the monolithic CalcTreeSizes into focused phases:
// 1. buildProcessingOrder() - DFS traversal to collect nodes
// 2. calculateIntrinsicSizes() - Bottom-up sizing of leaves and containers
// 3. commitToTransforms() - Write calculated sizes to Transform components
// 4. applyMaxConstraints() - Scale down subtrees that exceed max dimensions
// 5. applyGlobalScale() - Apply global UI scale factor
#pragma once

#include <entt/entt.hpp>
#include <vector>
#include <stack>
#include <unordered_map>
#include <optional>
#include "raylib.h"  // For Vector2
#include "systems/ui/ui_data.hpp"
#include "systems/ui/type_traits.hpp"
#include "systems/transform/transform.hpp"
#include "core/globals.hpp"

namespace ui::layout {

/// Entry for processing queue - bundles an entity with its sizing context
struct SizingEntry {
    entt::entity entity{entt::null};
    LocalTransform parentRect{};      ///< Parent's local transform rectangle
    bool forceRecalculate{false};     ///< Force layout recalculation
    std::optional<float> scale;       ///< Optional scale override
};

/// Multi-pass layout sizing algorithm for UI trees.
///
/// Usage:
/// @code
/// SizingPass pass(registry, rootEntity, parentRect, forceRecalc, scale);
/// auto [width, height] = pass.run();
/// @endcode
class SizingPass {
public:
    /// Construct a sizing pass for a UI tree
    /// @param reg Entity registry
    /// @param root Root entity of the UI tree
    /// @param parentRect Parent's local transform rectangle
    /// @param forceRecalc Force layout recalculation
    /// @param scale Optional scale override
    SizingPass(entt::registry& reg, entt::entity root,
               LocalTransform parentRect, bool forceRecalc,
               std::optional<float> scale = std::nullopt);

    /// Execute all sizing passes and return final root dimensions
    /// @return Pair of (width, height) for the root element
    std::pair<float, float> run();

    /// Get the processing order (for debugging/testing)
    const std::vector<SizingEntry>& processingOrder() const { return processingOrder_; }

    /// Get calculated content sizes (for debugging/testing)
    const std::unordered_map<entt::entity, Vector2>& contentSizes() const { return contentSizes_; }

private:
    // === Phase 1: Build Processing Order ===
    /// Collect all nodes in top-down DFS order
    void buildProcessingOrder();

    // === Phase 2: Calculate Intrinsic Sizes ===
    /// Process nodes bottom-up to calculate content dimensions
    void calculateIntrinsicSizes();

    // === Phase 3: Commit to Transforms ===
    /// Write calculated sizes to Transform components
    /// @return The biggest content size found
    Vector2 commitToTransforms();

    /// Calculate and set the root element's final height
    void finalizeRootHeight(const Vector2& biggestSize);

    // === Phase 4: Apply Max Constraints ===
    /// Scale down subtrees that exceed max width/height constraints
    void applyMaxConstraints();

    // === Phase 5: Apply Global Scale ===
    /// Apply global UI scale factor to all elements
    void applyGlobalScale();

    // === Member Data ===
    entt::registry& reg_;
    entt::entity root_;
    LocalTransform parentRect_;
    bool forceRecalc_;
    std::optional<float> scale_;

    std::vector<SizingEntry> processingOrder_;
    std::unordered_map<entt::entity, Vector2> contentSizes_;
    LocalTransform calcCurrentNodeTransform_{};  ///< Temporary for calculations
};

} // namespace ui::layout
