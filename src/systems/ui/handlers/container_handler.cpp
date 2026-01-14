#include "container_handler.hpp"
#include "../element.hpp"
#include "../util.hpp"
#include "core/globals.hpp"
#include "systems/layer/layer_command_buffer.hpp"
#include <spdlog/spdlog.h>

namespace ui {

void ContainerHandler::calculateSize(
    entt::registry& registry,
    entt::entity entity,
    UILayoutConfig& layout,
    float scaleFactor
) {
    // Containers don't calculate their own size - their dimensions
    // are determined by their children via the layout engine in box.cpp.
    // This is intentionally a no-op.
}

void ContainerHandler::draw(
    entt::registry& registry,
    entt::entity entity,
    const UIStyleConfig& style,
    const transform::Transform& t,
    const UIDrawContext& ctx
) {
    // ContainerHandler draws container elements (ROOT, VERTICAL_CONTAINER, HORIZONTAL_CONTAINER)
    // Using the same rendering logic as RectHandler - they all just draw styled rectangles

    if (!ctx.layer || !ctx.node) {
        SPDLOG_WARN("ContainerHandler::draw called with incomplete context");
        return;
    }

    auto layerPtr = ctx.layer;
    auto* config = ctx.config;  // Keep for util functions that still need it
    auto* node = ctx.node;
    const int zIndex = ctx.zIndex;

    // Make a mutable copy of transform for util functions that require non-const ref
    auto transformCopy = t;

    // Use style values from UIStyleConfig (split component)
    const auto& stylingType = style.stylingType;
    const auto& styleColor = style.color;
    const auto styleShadow = style.shadow;
    const auto styleEmboss = style.emboss;

    layer::QueueCommand<layer::CmdPushMatrix>(layerPtr, [](layer::CmdPushMatrix *cmd) {}, zIndex);

    // Shadow pass - use style.shadow from split component
    if (styleShadow && globals::getSettings().shadowsOn) {
        Color shadowColor = Color{0, 0, 0, static_cast<unsigned char>(styleColor.value_or(WHITE).a * 0.3f)};
        if (style.shadowColor) {
            shadowColor = style.shadowColor.value();
        }

        if (stylingType == ui::UIStylingType::ROUNDED_RECTANGLE) {
            util::DrawSteppedRoundedRectangle(layerPtr, registry, entity, transformCopy, config, *node, ctx.rectCache,
                ctx.visualX, ctx.visualY, ctx.visualW, ctx.visualH,
                ctx.visualScaleWithHoverAndMotion, ctx.visualR, ctx.rotationOffset,
                ui::RoundedRectangleVerticesCache_TYPE_SHADOW, ctx.parallaxDist,
                {}, std::nullopt, std::nullopt, zIndex);
        } else if (stylingType == ui::UIStylingType::NINEPATCH_BORDERS) {
            util::DrawNPatchUIElement(layerPtr, registry, entity, shadowColor, ctx.parallaxDist, std::nullopt, zIndex);
        }
    }

    // Emboss pass
    if (styleEmboss) {
        Color c = ColorBrightness(styleColor.value_or(WHITE), node->state.isBeingHovered ? -0.8f : -0.5f);

        if (stylingType == ui::UIStylingType::ROUNDED_RECTANGLE) {
            util::DrawSteppedRoundedRectangle(layerPtr, registry, entity, transformCopy, config, *node, ctx.rectCache,
                ctx.visualX, ctx.visualY, ctx.visualW, ctx.visualH,
                ctx.visualScaleWithHoverAndMotion, ctx.visualR, ctx.rotationOffset,
                ui::RoundedRectangleVerticesCache_TYPE_EMBOSS, ctx.parallaxDist,
                {{"emboss", c}}, std::nullopt, std::nullopt, zIndex);
        } else if (stylingType == ui::UIStylingType::NINEPATCH_BORDERS) {
            util::DrawNPatchUIElement(layerPtr, registry, entity, c, ctx.parallaxDist, std::nullopt, zIndex);
        }
    }

    // Main fill pass
    Color fillColor = styleColor.value_or(WHITE);
    if (ctx.visualW > 0.01) {
        if (stylingType == ui::UIStylingType::ROUNDED_RECTANGLE) {
            util::DrawSteppedRoundedRectangle(layerPtr, registry, entity, transformCopy, config, *node, ctx.rectCache,
                ctx.visualX, ctx.visualY, ctx.visualW, ctx.visualH,
                ctx.visualScaleWithHoverAndMotion, ctx.visualR, ctx.rotationOffset,
                ui::RoundedRectangleVerticesCache_TYPE_FILL, ctx.parallaxDist,
                {{"fill", fillColor}}, std::nullopt, std::nullopt, zIndex);
        } else if (stylingType == ui::UIStylingType::NINEPATCH_BORDERS) {
            util::DrawNPatchUIElement(layerPtr, registry, entity, fillColor, ctx.parallaxDist, std::nullopt, zIndex);
        }
    } else {
        layer::QueueCommand<layer::CmdDrawRectangle>(layerPtr, [w = ctx.actualW, h = ctx.actualH, fillColor](layer::CmdDrawRectangle *cmd) {
            cmd->x = 0;
            cmd->y = 0;
            cmd->width = w;
            cmd->height = h;
            cmd->color = fillColor;
        }, zIndex);
    }

    layer::QueueCommand<layer::CmdPopMatrix>(layerPtr, [](layer::CmdPopMatrix *cmd) {}, zIndex);
}

} // namespace ui
