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
    float requestedSize = static_cast<float>(fontData.defaultSize);
    if (contentConfig && contentConfig->fontSize) {
        requestedSize = contentConfig->fontSize.value();
    } else if (config->fontSize) {
        requestedSize = config->fontSize.value();
    }

    // Get style values
    const auto& styleColor = style.color;
    const auto styleShadow = style.shadow;

    const bool shadowsOn = globals::getSettings().shadowsOn;
    const float spacing = config->textSpacing.value_or(fontData.spacing);
    const float scale = layoutScale.value_or(1.0f) * fontData.fontScale * globals::getGlobalUIScaleFactor();

    // Calculate effective size and select best font for that size
    // This avoids GPU scaling which causes pixel gaps with TEXTURE_FILTER_POINT
    const float effectiveSize = requestedSize * scale;
    const Font& bestFont = fontData.getBestFontForSize(effectiveSize);
    const float fontSize = static_cast<float>(bestFont.baseSize);

    // Only apply GPU scaling if we couldn't find an exact font match
    const float fontScaleRatio = effectiveSize / fontSize;
    const bool needsGpuScaling = std::abs(fontScaleRatio - 1.0f) > 0.01f;

    // Scale shadow offset relative to rendered font size (in pixels)
    Vector2& fixedShadow = globals::getFixedTextShadowOffset();
    const float shadowOffsetX = fixedShadow.x * effectiveSize * 0.04f;
    const float shadowOffsetY = fixedShadow.y * effectiveSize * -0.03f;

    bool drawShadow = (config->button_UIE && ctx.buttonActive) ||
                      (!config->button_UIE && styleShadow && shadowsOn);

    // Shadow pass
    if (drawShadow) {
        layer::QueueCommand<layer::CmdPushMatrix>(layerPtr, [](layer::CmdPushMatrix *cmd) {}, zIndex);

        Vector2 layerDisplacement = {node->layerDisplacement->x, node->layerDisplacement->y};
        layer::QueueCommand<layer::CmdTranslate>(layerPtr,
            [x = ctx.actualX + layerDisplacement.x + shadowOffsetX,
             y = ctx.actualY + layerDisplacement.y + shadowOffsetY](layer::CmdTranslate *cmd) {
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

        if ((styleShadow || (config->button_UIE && ctx.buttonActive)) && shadowsOn) {
            Color shadowColor = Color{0, 0, 0, static_cast<unsigned char>(styleColor.value_or(WHITE).a * 0.3f)};

            float textX = fontData.fontRenderOffset.x;
            float textY = fontData.fontRenderOffset.y;

            if (needsGpuScaling) {
                layer::QueueCommand<layer::CmdScale>(layerPtr, [fontScaleRatio](layer::CmdScale *cmd) {
                    cmd->scaleX = fontScaleRatio;
                    cmd->scaleY = fontScaleRatio;
                }, zIndex);
            }
            if (config->text) {
                layer::QueueCommand<layer::CmdTextPro>(layerPtr,
                    [text = config->text.value(), font = bestFont, textX, textY, spacing, shadowColor, fontSize](layer::CmdTextPro *cmd) {
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

    if (needsGpuScaling) {
        layer::QueueCommand<layer::CmdScale>(layerPtr, [fontScaleRatio](layer::CmdScale *cmd) {
            cmd->scaleX = fontScaleRatio;
            cmd->scaleY = fontScaleRatio;
        }, zIndex);
    }

    if (config->text) {
        layer::QueueCommand<layer::CmdTextPro>(layerPtr,
            [text = config->text.value(), font = bestFont, textX, textY, spacing, renderColor, fontSize](layer::CmdTextPro *cmd) {
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
