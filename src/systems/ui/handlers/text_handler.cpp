#include "text_handler.hpp"
#include "../element.hpp"
#include "core/globals.hpp"
#include "systems/layer/layer_command_buffer.hpp"
#include <cmath>
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

    if (!ctx.layer || !ctx.node || !ctx.fontData) {
        SPDLOG_WARN("TextHandler::draw called with incomplete context");
        return;
    }

    auto layerPtr = ctx.layer;
    auto* node = ctx.node;
    const auto& fontData = *ctx.fontData;
    const int zIndex = ctx.zIndex;

    // Fetch split components from registry
    const auto* layoutConfig = registry.try_get<UILayoutConfig>(entity);
    const auto* contentConfig = registry.try_get<UIContentConfig>(entity);
    const auto* interactionConfig = registry.try_get<UIInteractionConfig>(entity);

    // Get scale from layout config (required for text rendering)
    const auto layoutScale = layoutConfig ? layoutConfig->scale : std::nullopt;
    if (!layoutScale) {
        return; // Scale required for text rendering
    }

    // Get content config values for text-specific fields
    const auto contentVerticalText = contentConfig ? contentConfig->verticalText : std::optional<bool>{};
    float requestedSize = static_cast<float>(fontData.defaultSize);
    if (contentConfig && contentConfig->fontSize) {
        requestedSize = contentConfig->fontSize.value();
    }

    // Get text content and spacing from content config
    const auto contentText = contentConfig ? contentConfig->text : std::optional<std::string>{};
    const float spacing = (contentConfig && contentConfig->textSpacing)
        ? contentConfig->textSpacing.value()
        : fontData.spacing;

    // Get button_UIE from interaction config for shadow logic
    const auto buttonUIE = interactionConfig ? interactionConfig->button_UIE : std::optional<entt::entity>{};

    // Get style values from UIStyleConfig (split component)
    const auto& styleColor = style.color;
    const auto styleShadow = style.shadow;
    const bool snapToPixels = (ctx.config == nullptr) ? true : ctx.config->pixelatedRectangle;
    auto snapPixel = [](float v) -> float { return std::round(v); };

    const bool shadowsOn = globals::getSettings().shadowsOn;
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

    // Determine shadow drawing: button elements draw shadow when active, non-buttons when styleShadow is set
    bool drawShadow = (buttonUIE && ctx.buttonActive) ||
                      (!buttonUIE && styleShadow && shadowsOn);

    // Shadow pass
    if (drawShadow) {
        layer::QueueCommand<layer::CmdPushMatrix>(layerPtr, [](layer::CmdPushMatrix *cmd) {}, zIndex);

        Vector2 layerDisplacement = {node->layerDisplacement->x, node->layerDisplacement->y};
        float shadowTranslateX = ctx.actualX + layerDisplacement.x + shadowOffsetX;
        float shadowTranslateY = ctx.actualY + layerDisplacement.y + shadowOffsetY;
        if (snapToPixels) {
            shadowTranslateX = snapPixel(shadowTranslateX);
            shadowTranslateY = snapPixel(shadowTranslateY);
        }
        layer::QueueCommand<layer::CmdTranslate>(layerPtr,
            [x = shadowTranslateX, y = shadowTranslateY](layer::CmdTranslate *cmd) {
            cmd->x = x;
            cmd->y = y;
        }, zIndex);

        if (contentVerticalText.value_or(false)) {
            layer::QueueCommand<layer::CmdTranslate>(layerPtr, [h = ctx.actualH](layer::CmdTranslate *cmd) {
                cmd->x = 0;
                cmd->y = h;
            }, zIndex);
            layer::QueueCommand<layer::CmdRotate>(layerPtr, [](layer::CmdRotate *cmd) {
                cmd->angle = -PI / 2;
            }, zIndex);
        }

        if ((styleShadow || (buttonUIE && ctx.buttonActive)) && shadowsOn) {
            Color shadowColor = Color{0, 0, 0, static_cast<unsigned char>(styleColor.value_or(WHITE).a * 0.3f)};

            float textX = fontData.fontRenderOffset.x;
            float textY = fontData.fontRenderOffset.y;
            if (snapToPixels) {
                textX = snapPixel(textX);
                textY = snapPixel(textY);
            }

            if (needsGpuScaling) {
                layer::QueueCommand<layer::CmdScale>(layerPtr, [fontScaleRatio](layer::CmdScale *cmd) {
                    cmd->scaleX = fontScaleRatio;
                    cmd->scaleY = fontScaleRatio;
                }, zIndex);
            }
            if (contentText) {
                layer::QueueCommand<layer::CmdTextPro>(layerPtr,
                    [text = contentText.value(), font = bestFont, textX, textY, spacing, shadowColor, fontSize](layer::CmdTextPro *cmd) {
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
    float translateX = ctx.actualX + layerDisplacement.x;
    float translateY = ctx.actualY + layerDisplacement.y;
    if (snapToPixels) {
        translateX = snapPixel(translateX);
        translateY = snapPixel(translateY);
    }
    layer::QueueCommand<layer::CmdTranslate>(layerPtr,
        [x = translateX, y = translateY](layer::CmdTranslate *cmd) {
        cmd->x = x;
        cmd->y = y;
    }, zIndex);

    if (contentVerticalText.value_or(false)) {
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
    if (snapToPixels) {
        textX = snapPixel(textX);
        textY = snapPixel(textY);
    }

    if (needsGpuScaling) {
        layer::QueueCommand<layer::CmdScale>(layerPtr, [fontScaleRatio](layer::CmdScale *cmd) {
            cmd->scaleX = fontScaleRatio;
            cmd->scaleY = fontScaleRatio;
        }, zIndex);
    }

    if (contentText) {
        layer::QueueCommand<layer::CmdTextPro>(layerPtr,
            [text = contentText.value(), font = bestFont, textX, textY, spacing, renderColor, fontSize](layer::CmdTextPro *cmd) {
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
