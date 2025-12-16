#include "rect_handler.hpp"
#include "../element.hpp"
#include "../util.hpp"
#include "core/globals.hpp"
#include "systems/layer/layer_command_buffer.hpp"
#include <spdlog/spdlog.h>

namespace ui {

void RectHandler::calculateSize(
    entt::registry& registry,
    entt::entity entity,
    UILayoutConfig& layout,
    float scaleFactor
) {
    // RECT_SHAPE uses explicit dimensions from config
    // Size calculation is straightforward - just apply scale if needed
    // The actual sizing is handled by the layout engine in box.cpp

    // For now, this is a placeholder
    // Future work: Move size calculation logic here from box.cpp
}

void RectHandler::draw(
    entt::registry& registry,
    entt::entity entity,
    const UIStyleConfig& style,
    const transform::Transform& t,
    const UIDrawContext& ctx
) {
    // RectHandler draws RECT_SHAPE elements (simple rectangles with styling)
    // This is the pure rectangle rendering logic extracted from DrawSelf

    if (!ctx.layer || !ctx.config || !ctx.node) {
        SPDLOG_WARN("RectHandler::draw called with incomplete context");
        return;
    }

    auto layerPtr = ctx.layer;
    auto* config = ctx.config;
    auto* node = ctx.node;
    const int zIndex = ctx.zIndex;

    // Make a mutable copy of transform for util functions that require non-const ref
    auto transformCopy = t;

    // Use style values (prefer UIStyleConfig over config fallback)
    const auto& stylingType = style.stylingType;
    const auto& styleColor = style.color;
    const auto styleShadow = style.shadow;
    const auto styleEmboss = style.emboss;

    layer::QueueCommand<layer::CmdPushMatrix>(layerPtr, [](layer::CmdPushMatrix *cmd) {}, zIndex);

    // Shadow pass
    if (config->shadow && globals::getSettings().shadowsOn) {
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
