#pragma once

#include "handler_interface.hpp"

namespace ui {

/**
 * @brief Handler for INPUT_TEXT UI elements.
 *
 * Handles text input elements with blinking caret cursor,
 * optional shadow, and text rendering similar to TextHandler.
 */
class InputTextHandler : public IUIElementHandler {
public:
    /**
     * @brief Calculate size for input text element.
     *
     * INPUT_TEXT elements derive their size from text measurement.
     */
    void calculateSize(
        entt::registry& registry,
        entt::entity entity,
        UILayoutConfig& layout,
        float scaleFactor
    ) override;

    /**
     * @brief Draw the input text element.
     *
     * Draws text from TextInput component with optional shadow,
     * and renders a blinking caret at cursor position when focused.
     */
    void draw(
        entt::registry& registry,
        entt::entity entity,
        const UIStyleConfig& style,
        const transform::Transform& transform,
        const UIDrawContext& ctx
    ) override;
};

} // namespace ui
