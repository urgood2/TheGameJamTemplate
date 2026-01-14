#include "object_handler.hpp"
#include "../element.hpp"
#include "../util.hpp"
#include "core/globals.hpp"
#include "systems/layer/layer_command_buffer.hpp"
#include "systems/main_loop_enhancement/main_loop.hpp"
#include <spdlog/spdlog.h>
#include <cmath>

namespace ui {

void ObjectHandler::calculateSize(
    entt::registry& registry,
    entt::entity entity,
    UILayoutConfig& layout,
    float scaleFactor
) {
    // OBJECT elements typically use explicit dimensions from config
    // or derive size from the attached object.
    // Size calculation is handled by the layout engine in box.cpp
}

void ObjectHandler::draw(
    entt::registry& registry,
    entt::entity entity,
    const UIStyleConfig& style,
    const transform::Transform& t,
    const UIDrawContext& ctx
) {
    // ObjectHandler draws OBJECT elements - primarily the focus highlight
    // when the attached object is focused.

    if (!ctx.layer || !ctx.node) {
        SPDLOG_WARN("ObjectHandler::draw called with incomplete context");
        return;
    }

    auto layerPtr = ctx.layer;
    auto* config = ctx.config;
    auto* state = ctx.state;
    auto* node = ctx.node;
    const int zIndex = ctx.zIndex;

    // Check if we have an attached object
    if (!config || !config->object) {
        return;
    }

    entt::entity objectEntity = config->object.value();

    // Check if the object entity is valid
    if (!registry.valid(objectEntity)) {
        return;
    }

    // Get the attached object's GameObject to check focus state
    auto* objectNode = registry.try_get<transform::GameObject>(objectEntity);
    if (!objectNode) {
        return;
    }

    // Make a mutable copy of transform for util functions
    auto transformCopy = t;

    // Draw focus highlight if the object is focused and focusWithObject is enabled
    if (config->focusWithObject && objectNode->state.isBeingFocused) {
        // Initialize or update the focus timer
        if (state) {
            // Balance matrix stack: push before drawing highlight primitives
            layer::QueueCommand<layer::CmdPushMatrix>(layerPtr, [](layer::CmdPushMatrix *cmd) {}, zIndex);

            state->object_focus_timer = state->object_focus_timer.value_or(main_loop::mainLoop.realtimeTimer);

            // Calculate highlight intensity based on time (animated fade)
            // lw = 50 * (max(0, timer - currentTime + 0.3))^2
            // This creates a brief highlight that fades out over 0.3 seconds
            float timeDiff = state->object_focus_timer.value() - main_loop::mainLoop.realtimeTimer + 0.3f;
            float lw = 50.0f * std::pow(std::max(0.0f, timeDiff), 2);

            // Draw filled rounded rectangle (highlight background)
            Color fillColor = util::AdjustAlpha(WHITE, 0.2f * lw);
            util::DrawSteppedRoundedRectangle(
                layerPtr, registry, entity, transformCopy, config, *node, ctx.rectCache,
                ctx.visualX, ctx.visualY, ctx.visualW, ctx.visualH,
                ctx.visualScaleWithHoverAndMotion, ctx.visualR, ctx.rotationOffset,
                ui::RoundedRectangleVerticesCache_TYPE_FILL, ctx.parallaxDist,
                {{"fill", fillColor}}, std::nullopt, std::nullopt, zIndex
            );

            // Draw outline rounded rectangle (highlight border)
            // Mix white with the element's color if it has meaningful alpha
            Color outlineColor = WHITE;
            if (style.color && style.color->a > 0.01f) {
                outlineColor = util::MixColours(WHITE, style.color.value(), 0.8f);
            }
            util::DrawSteppedRoundedRectangle(
                layerPtr, registry, entity, transformCopy, config, *node, ctx.rectCache,
                ctx.visualX, ctx.visualY, ctx.visualW, ctx.visualH,
                ctx.visualScaleWithHoverAndMotion, ctx.visualR, ctx.rotationOffset,
                ui::RoundedRectangleVerticesCache_TYPE_OUTLINE, ctx.parallaxDist,
                {{"outline", outlineColor}}, std::nullopt, std::nullopt, zIndex
            );

            layer::QueueCommand<layer::CmdPopMatrix>(layerPtr, [](layer::CmdPopMatrix *cmd) {}, zIndex);
        }
    } else {
        // Reset the focus timer when not focused
        if (state) {
            state->object_focus_timer.reset();
        }
    }

    // Note: The actual object content (sprite, text, etc.) is rendered by
    // the attached entity's own rendering system, not by this handler.
    // This handler only handles the focus highlight overlay.
}

} // namespace ui
