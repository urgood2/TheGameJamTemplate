// src/systems/ui/sizing_pass.cpp
// Implementation of the multi-pass layout sizing algorithm.
// Part of the Phase 4 CalcTreeSizes refactoring.

#include "systems/ui/sizing_pass.hpp"
#include "systems/ui/box.hpp"
#include "systems/ui/element.hpp"
#include "systems/ui/type_traits.hpp"
#include <spdlog/spdlog.h>
#include <algorithm>

namespace ui::layout {

SizingPass::SizingPass(entt::registry& reg, entt::entity root,
                       LocalTransform parentRect, bool forceRecalc,
                       std::optional<float> scale)
    : reg_(reg)
    , root_(root)
    , parentRect_(parentRect)
    , forceRecalc_(forceRecalc)
    , scale_(scale)
{
}

std::pair<float, float> SizingPass::run() {
    // Phase 1: Build processing order (DFS top-down collection)
    buildProcessingOrder();

    // Phase 2: Calculate intrinsic sizes (bottom-up)
    calculateIntrinsicSizes();

    // Phase 3: Commit sizes to transforms
    Vector2 biggestSize = commitToTransforms();

    // Finalize root element's height calculation
    finalizeRootHeight(biggestSize);

    // Phase 4: Apply max constraints (scale down oversized subtrees)
    applyMaxConstraints();

    // Phase 5: Apply global scale factor
    applyGlobalScale();

    // Return final root content size
    auto& uiState = reg_.get<UIState>(root_);
    Vector2 rootContentSize = uiState.contentDimensions.value_or(Vector2{0.f, 0.f});
    return {rootContentSize.x, rootContentSize.y};
}

void SizingPass::buildProcessingOrder() {
    processingOrder_.clear();

    std::stack<SizingEntry> stack;
    stack.push({root_, parentRect_, forceRecalc_, scale_});

    // DFS traversal - collect nodes in top-down order
    while (!stack.empty()) {
        auto entry = stack.top();
        stack.pop();
        processingOrder_.push_back(entry);

        auto* node = reg_.try_get<transform::GameObject>(entry.entity);
        if (!node) continue;

        // Push children onto stack (reverse order for correct left-to-right processing)
        LocalTransform nextParentRect = entry.parentRect;
        if (auto* parentTransform = reg_.try_get<transform::Transform>(entry.entity)) {
            nextParentRect = {
                parentTransform->getActualX(),
                parentTransform->getActualY(),
                parentTransform->getActualW(),
                parentTransform->getActualH()
            };
        }

        auto pushChild = [&](entt::entity child) {
            if (!reg_.valid(child)) return;
            if (reg_.all_of<UIConfig, UIState>(child)) {
                stack.push({child, nextParentRect, forceRecalc_, scale_});
            }
        };

        if (!node->orderedChildren.empty()) {
            for (auto child : node->orderedChildren) {
                pushChild(child);
            }
        } else {
            // Fallback: when orderedChildren is empty, traverse the named map.
            for (auto const &kv : node->children) {
                pushChild(kv.second);
            }
        }
    }
}

void SizingPass::calculateIntrinsicSizes() {
    contentSizes_.clear();

    // Process in reverse order (bottom-up: leaves before containers)
    for (auto it = processingOrder_.rbegin(); it != processingOrder_.rend(); ++it) {
        auto& entry = *it;
        auto entity = entry.entity;

        auto& uiConfig = reg_.get<UIConfig>(entity);

        // Leaf elements (non-containers) - includes FILLER type and isFiller flag
        if (TypeTraits::isLeaf(uiConfig.uiType.value_or(UITypeEnum::NONE)) || uiConfig.isFiller) {
            Vector2 dimensions = box::TreeCalcSubNonContainer(
                reg_, entity, entry.parentRect, entry.forceRecalculate,
                entry.scale, calcCurrentNodeTransform_);

            SPDLOG_DEBUG("Calculated content size for entity {}: ({}, {})",
                        static_cast<int>(entity), dimensions.x, dimensions.y);
            contentSizes_[entity] = dimensions;
            continue;
        }

        // Container elements
        Vector2 dimensions = box::TreeCalcSubContainer(
            reg_, entity, entry.parentRect, entry.forceRecalculate,
            entry.scale, calcCurrentNodeTransform_, contentSizes_);

        SPDLOG_DEBUG("Calculated content size for container {}: ({}, {})",
                    static_cast<int>(entity), dimensions.x, dimensions.y);
        contentSizes_[entity] = dimensions;
    }
}

Vector2 SizingPass::commitToTransforms() {
    Vector2 biggestSize{0.f, 0.f};

    for (auto& [uiElement, contentSize] : contentSizes_) {
        auto& uiState = reg_.get<UIState>(uiElement);
        auto& transform = reg_.get<transform::Transform>(uiElement);

        uiState.contentDimensions = contentSize;

        Vector2 finalContentSize = contentSize;

        // Scroll panes use viewport size instead of content size for rendering
        if (auto* scr = reg_.try_get<UIScrollComponent>(uiElement)) {
            transform.setActualW(scr->viewportSize.x);
            transform.setActualH(scr->viewportSize.y);
            transform.setVisualW(scr->viewportSize.x);
            transform.setVisualH(scr->viewportSize.y);
            transform.getWSpring().velocity = 0.0f;
            transform.getHSpring().velocity = 0.0f;
            finalContentSize = Vector2{scr->viewportSize.x, contentSize.y};
        } else {
            transform.setActualW(contentSize.x);
            transform.setActualH(contentSize.y);
            transform.setVisualW(contentSize.x);
            transform.setVisualH(contentSize.y);
            transform.getWSpring().velocity = 0.0f;
            transform.getHSpring().velocity = 0.0f;
        }

        if (finalContentSize.x > biggestSize.x) biggestSize.x = finalContentSize.x;
        if (finalContentSize.y > biggestSize.y) biggestSize.y = finalContentSize.y;
    }

    return biggestSize;
}

void SizingPass::finalizeRootHeight(const Vector2& biggestSize) {
    auto& rootTransform = reg_.get<transform::Transform>(root_);
    auto& uiConfig = reg_.get<UIConfig>(root_);
    auto& node = reg_.get<transform::GameObject>(root_);
    float padding = uiConfig.effectivePadding();

    rootTransform.setActualW(biggestSize.x + padding);
    rootTransform.setActualH(biggestSize.y);

    // If root has children and is not a scroll pane, calculate height from children
    if (!node.orderedChildren.empty() && uiConfig.uiType != UITypeEnum::SCROLL_PANE) {
        rootTransform.setActualH(padding);  // Start with top padding

        for (auto childEntry : node.orderedChildren) {
            auto child = childEntry;
            auto& childConfig = reg_.get<UIConfig>(child);
            auto& childState = reg_.get<UIState>(child);

            float incrementHeight = childState.contentDimensions.value_or(Vector2{0.f, 0.f}).y + padding;

            // Add emboss if present
            if (childConfig.emboss) {
                incrementHeight += childConfig.emboss.value() *
                                   uiConfig.scale.value_or(1.0f) *
                                   globals::getGlobalUIScaleFactor();
            }

            rootTransform.setActualH(rootTransform.getActualH() + incrementHeight);
        }
    }

    rootTransform.setVisualW(rootTransform.getActualW());
    rootTransform.setVisualH(rootTransform.getActualH());
    rootTransform.getWSpring().velocity = 0.0f;
    rootTransform.getHSpring().velocity = 0.0f;

    // Update the UIBox entity's transform to match root
    auto& rootUIElementComp = reg_.get<UIElementComponent>(root_);
    auto& uiBoxTransform = reg_.get<transform::Transform>(rootUIElementComp.uiBox);
    uiBoxTransform.setActualW(rootTransform.getActualW());
    uiBoxTransform.setActualH(rootTransform.getActualH());
    uiBoxTransform.setVisualW(uiBoxTransform.getActualW());
    uiBoxTransform.setVisualH(uiBoxTransform.getActualH());
    uiBoxTransform.getWSpring().velocity = 0.0f;
    uiBoxTransform.getHSpring().velocity = 0.0f;
}

void SizingPass::applyMaxConstraints() {
    // Process in bottom-up order
    for (auto it = processingOrder_.rbegin(); it != processingOrder_.rend(); ++it) {
        auto entity = it->entity;
        auto& uiConfig = reg_.get<UIConfig>(entity);

        // Skip leaf elements (including fillers)
        if (TypeTraits::isLeaf(uiConfig.uiType.value_or(UITypeEnum::NONE)) || uiConfig.isFiller) {
            continue;
        }

        auto dims = contentSizes_.at(entity);

        // Skip if neither max dimension is exceeded
        bool widthExceeded = uiConfig.maxWidth && dims.x > uiConfig.maxWidth.value();
        bool heightExceeded = uiConfig.maxHeight && dims.y > uiConfig.maxHeight.value();

        if (!widthExceeded && !heightExceeded) {
            continue;
        }

        // Calculate the scale factor needed to fit within constraints
        float scaleW = uiConfig.maxWidth ? uiConfig.maxWidth.value() / dims.x : 1.0f;
        float scaleH = uiConfig.maxHeight ? uiConfig.maxHeight.value() / dims.y : 1.0f;
        float scaling = std::min(scaleW, scaleH);

        // Apply scale to all elements in subtree
        element::ApplyScalingFactorToSizesInSubtree(reg_, entity, scaling);
    }
}

void SizingPass::applyGlobalScale() {
    float globalScale = globals::getGlobalUIScaleFactor();

    for (auto it = processingOrder_.rbegin(); it != processingOrder_.rend(); ++it) {
        auto entity = it->entity;
        auto& uiConfig = reg_.get<UIConfig>(entity);
        auto& uiState = reg_.get<UIState>(entity);

        // Apply to content dimensions
        // NOTE: TEXT and INPUT_TEXT already have global scale applied during measurement
        // (in TreeCalcSubNonContainer), so we skip them to avoid double-scaling
        if (uiState.contentDimensions) {
            bool isTextElement = TypeTraits::isTextElement(uiConfig.uiType.value_or(UITypeEnum::NONE));
            if (!isTextElement) {
                uiState.contentDimensions->x *= globalScale;
                uiState.contentDimensions->y *= globalScale;
            }
        }

        // Apply to transform dimensions (skip text elements which were already scaled during measurement)
        auto& transform = reg_.get<transform::Transform>(entity);
        bool isTextElement = TypeTraits::isTextElement(uiConfig.uiType.value_or(UITypeEnum::NONE));
        if (!isTextElement) {
            transform.setActualW(transform.getActualW() * globalScale);
            transform.setActualH(transform.getActualH() * globalScale);
        }

        // Update attached object scaling
        if (uiConfig.object) {
            element::UpdateUIObjectScalingAndRecnter(&uiConfig, globalScale, &transform);
        }
    }
}

} // namespace ui::layout
