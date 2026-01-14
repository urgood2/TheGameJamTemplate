#include "input_text_handler.hpp"
#include "../element.hpp"
#include "core/globals.hpp"
#include "systems/layer/layer_command_buffer.hpp"
#include "systems/main_loop_enhancement/main_loop.hpp"
#include <spdlog/spdlog.h>
#include <cmath>

namespace ui {

void InputTextHandler::calculateSize(
    entt::registry& registry,
    entt::entity entity,
    UILayoutConfig& layout,
    float scaleFactor
) {
    // INPUT_TEXT elements derive size from text measurement
    // For now, this is a placeholder - actual sizing handled by layout engine
}

void InputTextHandler::draw(
    entt::registry& registry,
    entt::entity entity,
    const UIStyleConfig& style,
    const transform::Transform& t,
    const UIDrawContext& ctx
) {
    // InputTextHandler draws INPUT_TEXT elements with text from TextInput component
    // and a blinking caret cursor

    if (!ctx.layer || !ctx.node || !ctx.fontData) {
        SPDLOG_WARN("InputTextHandler::draw called with incomplete context");
        return;
    }

    auto layerPtr = ctx.layer;
    auto* node = ctx.node;
    const auto& fontData = *ctx.fontData;
    const int zIndex = ctx.zIndex;

    // Get TextInput component for text and cursor state
    const auto* textInput = registry.try_get<ui::TextInput>(entity);
    if (!textInput) {
        SPDLOG_WARN("InputTextHandler::draw called without TextInput component");
        return;
    }
    const std::string& displayText = textInput->text;

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

    // Get spacing from content config
    const float spacing = (contentConfig && contentConfig->textSpacing)
        ? contentConfig->textSpacing.value()
        : fontData.spacing;

    // Get button_UIE from interaction config for shadow logic
    const auto buttonUIE = interactionConfig ? interactionConfig->button_UIE : std::optional<entt::entity>{};

    // Get style values from UIStyleConfig
    const auto& styleColor = style.color;
    const auto styleShadow = style.shadow;

    const bool shadowsOn = globals::getSettings().shadowsOn;
    const float scale = layoutScale.value_or(1.0f) * fontData.fontScale * globals::getGlobalUIScaleFactor();

    // Calculate effective size and select best font for that size
    const float effectiveSize = requestedSize * scale;
    const Font& bestFont = fontData.getBestFontForSize(effectiveSize);
    const float actualSize = static_cast<float>(bestFont.baseSize);

    // Scale shadow offset relative to rendered font size (in pixels)
    Vector2& fixedShadow = globals::getFixedTextShadowOffset();
    const float shadowOffsetX = fixedShadow.x * actualSize * 0.04f;
    const float shadowOffsetY = fixedShadow.y * actualSize * -0.03f;

    // Determine shadow drawing: button elements draw shadow when active, non-buttons when styleShadow is set
    bool drawShadow = (buttonUIE && ctx.buttonActive) ||
                      (!buttonUIE && styleShadow && shadowsOn);

    // Common translate: position at element origin + layer displacement
    Vector2 layerDisplacement = {node->layerDisplacement->x, node->layerDisplacement->y};
    float textX = fontData.fontRenderOffset.x * scale;
    float textY = fontData.fontRenderOffset.y * scale;

    Color renderColor = styleColor.value_or(WHITE);
    if (!ctx.buttonActive) {
        renderColor = globals::uiTextInactive;
    }

    // 1) Optional shadow pass
    if (drawShadow) {
        layer::QueueCommand<layer::CmdPushMatrix>(layerPtr, [](layer::CmdPushMatrix *cmd) {}, zIndex);

        layer::QueueCommand<layer::CmdTranslate>(layerPtr,
            [x = ctx.actualX + layerDisplacement.x + shadowOffsetX,
             y = ctx.actualY + layerDisplacement.y + shadowOffsetY](layer::CmdTranslate *cmd) {
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

        Color shadowColor = Color{0, 0, 0, static_cast<unsigned char>(styleColor.value_or(WHITE).a * 0.3f)};

        layer::QueueCommand<layer::CmdTextPro>(layerPtr,
            [text = displayText, font = bestFont, textX, textY, spacing, shadowColor, actualSize](layer::CmdTextPro *cmd) {
            cmd->text = text.c_str();
            cmd->font = font;
            cmd->x = textX;
            cmd->y = textY;
            cmd->origin = {0, 0};
            cmd->rotation = 0;
            cmd->fontSize = actualSize;
            cmd->spacing = spacing;
            cmd->color = shadowColor;
        }, zIndex);

        layer::QueueCommand<layer::CmdPopMatrix>(layerPtr, [](layer::CmdPopMatrix *cmd) {}, zIndex);
    }

    // 2) Main text pass
    layer::QueueCommand<layer::CmdPushMatrix>(layerPtr, [](layer::CmdPushMatrix *cmd) {}, zIndex);

    layer::QueueCommand<layer::CmdTranslate>(layerPtr,
        [x = ctx.actualX + layerDisplacement.x, y = ctx.actualY + layerDisplacement.y](layer::CmdTranslate *cmd) {
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

    layer::QueueCommand<layer::CmdTextPro>(layerPtr,
        [text = displayText, font = bestFont, textX, textY, spacing, renderColor, actualSize](layer::CmdTextPro *cmd) {
        cmd->text = text.c_str();
        cmd->font = font;
        cmd->x = textX;
        cmd->y = textY;
        cmd->origin = {0, 0};
        cmd->rotation = 0;
        cmd->fontSize = actualSize;
        cmd->spacing = spacing;
        cmd->color = renderColor;
    }, zIndex);

    // 3) Blinking caret (only when focused/active)
    if (textInput->isActive) {
        // Blink at 1Hz (on 0.5s, off 0.5s)
        bool blinkOn = std::fmod(main_loop::mainLoop.realtimeTimer, 1.0f) < 0.5f;
        if (blinkOn) {
            // Measure the text up to cursorPos at the native font size
            std::string left = displayText.substr(0, std::min<size_t>(displayText.size(), textInput->cursorPos));
            Vector2 lhsSize = MeasureTextEx(bestFont, left.c_str(), actualSize, spacing);

            float caretX = textX + lhsSize.x;
            float caretY = textY;                    // same baseline as text
            float caretWidth = 2.0f;                 // 2px
            float caretHeight = actualSize * 1.1f;  // little taller than glyphs

            Color caretColor = renderColor;
            caretColor.a = std::max<unsigned char>(caretColor.a, 220);

            // Draw a thin vertical rectangle as caret (no scaling transform)
            float caretDrawX = caretX;
            float caretDrawY = caretY - actualSize * 0.85f;  // shift up to cap height
            layer::QueueCommand<layer::CmdDrawRectangle>(layerPtr,
                [caretDrawX, caretDrawY, caretWidth, caretHeight, caretColor](layer::CmdDrawRectangle *cmd) {
                cmd->x = caretDrawX;
                cmd->y = caretDrawY;
                cmd->width = caretWidth;
                cmd->height = caretHeight;
                cmd->color = caretColor;
            }, zIndex);
        }
    }

    layer::QueueCommand<layer::CmdPopMatrix>(layerPtr, [](layer::CmdPopMatrix *cmd) {}, zIndex);
}

} // namespace ui
