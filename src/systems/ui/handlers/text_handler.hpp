#pragma once

#include "handler_interface.hpp"

namespace ui {

/**
 * @brief Handler for TEXT UI elements.
 *
 * Handles text elements with optional shadow, vertical text support,
 * font scaling, and button-related visual states.
 */
class TextHandler : public IUIElementHandler {
public:
    /**
     * @brief Calculate size for text element.
     *
     * TEXT elements derive their size from text measurement.
     */
    void calculateSize(
        entt::registry& registry,
        entt::entity entity,
        UILayoutConfig& layout,
        float scaleFactor
    ) override;

    /**
     * @brief Draw the text element.
     *
     * Draws text with optional shadow, supporting vertical text
     * and button visual states.
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
