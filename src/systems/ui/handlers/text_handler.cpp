#include "text_handler.hpp"
#include "../element.hpp"
#include "core/globals.hpp"
#include "systems/layer/layer_command_buffer.hpp"
#include <spdlog/spdlog.h>

namespace ui {

void TextHandler::calculateSize(
    entt::registry& registry,
    entt::entity entity,
    UILayoutConfig& layout,
    float scaleFactor
) {
    // TEXT elements derive size from text measurement
    // For now, this is a placeholder - actual sizing handled by layout engine
}

void TextHandler::draw(
    entt::registry& registry,
    entt::entity entity,
    const UIStyleConfig& style,
    const transform::Transform& t,
    const UIDrawContext& ctx
) {
    // TextHandler draws TEXT elements with shadow and optional vertical text

    if (!ctx.layer || !ctx.config || !ctx.node || !ctx.fontData) {
        SPDLOG_WARN("TextHandler::draw called with incomplete context");
        return;
    }

    auto layerPtr = ctx.layer;
    auto* config = ctx.config;
    auto* node = ctx.node;
    const auto& fontData = *ctx.fontData;
    const int zIndex = ctx.zIndex;

    // Get scale from layout config or legacy config
    auto* layoutConfig = registry.try_get<UILayoutConfig>(entity);
    const auto& layoutScale = layoutConfig ? layoutConfig->scale : config->scale;

    if (!layoutScale) {
        return; // Scale required for text rendering
    }

    // Get content config for text-specific fields
    auto* contentConfig = registry.try_get<UIContentConfig>(entity);
    const auto contentVerticalText = contentConfig ? contentConfig->verticalText : config->verticalText;

    // Get style values
    const auto& styleColor = style.color;
    const auto styleShadow = style.shadow;

    // Calculate parallax values for shadow
    float rawScale = layoutScale.value() * fontData.fontScale;
    float scaleFactor = std::clamp(1.0f / (rawScale * rawScale), 0.01f, 1.0f);
    float textParallaxSX = node->shadowDisplacement->x * fontData.fontLoadedSize * 0.04f * scaleFactor;
    float textParallaxSY = node->shadowDisplacement->y * fontData.fontLoadedSize * -0.03f * scaleFactor;

    bool drawShadow = (config->button_UIE && ctx.buttonActive) ||
                      (!config->button_UIE && styleShadow && globals::getSettings().shadowsOn);

    // Shadow pass
    if (drawShadow) {
        layer::QueueCommand<layer::CmdPushMatrix>(layerPtr, [](layer::CmdPushMatrix *cmd) {}, zIndex);

        Vector2 layerDisplacement = {node->layerDisplacement->x, node->layerDisplacement->y};
        layer::QueueCommand<layer::CmdTranslate>(layerPtr,
            [x = ctx.actualX + textParallaxSX + layerDisplacement.x,
             y = ctx.actualY + textParallaxSY + layerDisplacement.y](layer::CmdTranslate *cmd) {
            cmd->x = x;
            cmd->y = y;
        }, zIndex);

        if (contentVerticalText) {
            layer::QueueCommand<layer::CmdTranslate>(layerPtr, [h = ctx.actualH](layer::CmdTranslate *cmd) {
                cmd->x = 0;
                cmd->y = h;
            }, zIndex);
            layer::QueueCommand<layer::CmdRotate>(layerPtr, [](layer::CmdRotate *cmd) {
                cmd->angle = -PI / 2;
            }, zIndex);
        }

        if ((styleShadow || (config->button_UIE && ctx.buttonActive)) && globals::getSettings().shadowsOn) {
            Color shadowColor = Color{0, 0, 0, static_cast<unsigned char>(styleColor.value_or(WHITE).a * 0.3f)};

            float textX = fontData.fontRenderOffset.x +
                         (contentVerticalText ? textParallaxSY : textParallaxSX) * layoutScale.value_or(1.0f) * fontData.fontScale;
            float textY = fontData.fontRenderOffset.y +
                         (contentVerticalText ? textParallaxSX : textParallaxSY) * layoutScale.value_or(1.0f) * fontData.fontScale;
            float spacing = config->textSpacing.value_or(fontData.spacing);
            float scale = layoutScale.value_or(1.0f) * fontData.fontScale * globals::getGlobalUIScaleFactor();

            layer::QueueCommand<layer::CmdScale>(layerPtr, [scale](layer::CmdScale *cmd) {
                cmd->scaleX = scale;
                cmd->scaleY = scale;
            }, zIndex);

            float fontSize = fontData.fontLoadedSize;
            if (config->text) {
                layer::QueueCommand<layer::CmdTextPro>(layerPtr,
                    [text = config->text.value(), font = fontData.font, textX, textY, spacing, shadowColor, fontSize](layer::CmdTextPro *cmd) {
                    cmd->text = text.c_str();
                    cmd->font = font;
                    cmd->x = textX;
                    cmd->y = textY;
                    cmd->origin = {0, 0};
                    cmd->rotation = 0;
                    cmd->fontSize = fontSize;
                    cmd->spacing = spacing;
                    cmd->color = shadowColor;
                }, zIndex);
            }
        }

        layer::QueueCommand<layer::CmdPopMatrix>(layerPtr, [](layer::CmdPopMatrix *cmd) {}, zIndex);
    }

    // Main text pass
    layer::QueueCommand<layer::CmdPushMatrix>(layerPtr, [](layer::CmdPushMatrix *cmd) {}, zIndex);

    Vector2 layerDisplacement = {node->layerDisplacement->x, node->layerDisplacement->y};
    layer::QueueCommand<layer::CmdTranslate>(layerPtr,
        [x = ctx.actualX + layerDisplacement.x, y = ctx.actualY + layerDisplacement.y](layer::CmdTranslate *cmd) {
        cmd->x = x;
        cmd->y = y;
    }, zIndex);

    if (contentVerticalText) {
        layer::QueueCommand<layer::CmdTranslate>(layerPtr, [h = ctx.actualH](layer::CmdTranslate *cmd) {
            cmd->x = 0;
            cmd->y = h;
        }, zIndex);
        layer::QueueCommand<layer::CmdRotate>(layerPtr, [](layer::CmdRotate *cmd) {
            cmd->angle = -PI / 2;
        }, zIndex);
    }

    Color renderColor = styleColor.value_or(WHITE);
    if (!ctx.buttonActive) {
        renderColor = globals::uiTextInactive;
    }

    float textX = fontData.fontRenderOffset.x;
    float textY = fontData.fontRenderOffset.y;
    float scale = layoutScale.value_or(1.0f) * fontData.fontScale * globals::getGlobalUIScaleFactor();

    layer::QueueCommand<layer::CmdScale>(layerPtr, [scale](layer::CmdScale *cmd) {
        cmd->scaleX = scale;
        cmd->scaleY = scale;
    }, zIndex);

    float spacing = config->textSpacing.value_or(fontData.spacing);
    float fontSize = fontData.fontLoadedSize;

    if (config->text) {
        layer::QueueCommand<layer::CmdTextPro>(layerPtr,
            [text = config->text.value(), font = fontData.font, textX, textY, spacing, renderColor, fontSize](layer::CmdTextPro *cmd) {
            cmd->text = text.c_str();
            cmd->font = font;
            cmd->x = textX;
            cmd->y = textY;
            cmd->origin = {0, 0};
            cmd->rotation = 0;
            cmd->fontSize = fontSize;
            cmd->spacing = spacing;
            cmd->color = renderColor;
        }, zIndex);
    }

    layer::QueueCommand<layer::CmdPopMatrix>(layerPtr, [](layer::CmdPopMatrix *cmd) {}, zIndex);
}

} // namespace ui
