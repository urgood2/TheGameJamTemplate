#pragma once

#include "systems/layer/layer.hpp"
#include "systems/layer/layer_command_buffer.hpp"
#include "systems/ui/ui_data.hpp"

namespace ui_clip {

// A single scissor scope guarding a contiguous subtree in drawOrder.
struct Scope {
    size_t endExclusive; // first index *after* the subtree this scope covers
    int    z;            // z-index to queue EndScissor on
    bool   hadMatrix = false; // if you also push a transform, pop it before EndScissor
};

inline void closeFinishedScopes(size_t i,
                                std::vector<Scope>& stack,
                                const std::shared_ptr<layer::Layer>& layerPtr)
{
    // Close nested-first (LIFO). If multiple scopes end at the same i, pop all.
    while (!stack.empty() && i >= stack.back().endExclusive) {
        if (stack.back().hadMatrix) {
            layer::QueueCommand<layer::CmdPopMatrix>(
                layerPtr, [](auto*){}, stack.back().z);
        }
        layer::QueueCommand<layer::CmdEndScissorMode>(
            layerPtr, [](auto*){}, stack.back().z);
        stack.pop_back();
    }
}

inline void closeAll(std::vector<Scope>& stack,
                     const std::shared_ptr<layer::Layer>& layerPtr)
{
    // In case the last element ended a scope
    while (!stack.empty()) {
        if (stack.back().hadMatrix) {
            layer::QueueCommand<layer::CmdPopMatrix>(
                layerPtr, [](auto*){}, stack.back().z);
        }
        layer::QueueCommand<layer::CmdEndScissorMode>(
            layerPtr, [](auto*){}, stack.back().z);
        stack.pop_back();
    }
}

// Find [start=i, end) where descendants have strictly greater depth and same UIBox.
inline size_t computeSubtreeEnd(const entt::registry& registry,
                                entt::basic_group<entt::entity,
                                                  entt::get_t<UIElementComponent, UIConfig, UIState,
                                                              transform::GameObject, transform::Transform>> const& group,
                                const std::vector<UIDrawListItem>& drawOrder,
                                size_t i,
                                entt::entity currentUIBox)
{
    const int parentDepth = drawOrder[i].depth;
    size_t end = i + 1;
    while (end < drawOrder.size() && drawOrder[end].depth > parentDepth) {
        auto &nextElem = group.get<UIElementComponent>(drawOrder[end].e);
        if (nextElem.uiBox != currentUIBox) break; // don't cross into another box
        ++end;
    }
    return end; // exclusive
}

// Convert your transform to a top-left, pixel-space scissor rect.
// Adjust if your Transform is center-based or if you render to a scaled RT.
inline Rectangle toScissorRect(const transform::Transform& xf)
{
    // If getActualX/Y are top-left in screen pixels, this is correct:
    return Rectangle{ xf.getActualX(), xf.getActualY(), xf.getActualW(), xf.getActualH() };

    // If they are center-based, use:
    // float x = xf.getActualX() - 0.5f * xf.getActualW();
    // float y = xf.getActualY() - 0.5f * xf.getActualH();
    // return Rectangle{ x, y, xf.getActualW(), xf.getActualH() };
}

} // namespace ui_clip