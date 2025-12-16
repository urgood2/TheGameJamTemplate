#pragma once

#include "handler_interface.hpp"

namespace ui {

/**
 * @brief Handler for RECT_SHAPE UI elements.
 *
 * Handles simple rectangular elements with optional styling
 * (colors, outlines, shadows, 9-patch, etc.).
 *
 * RECT_SHAPE elements use explicit dimensions from their layout config
 * and render based on their style config.
 */
class RectHandler : public IUIElementHandler {
public:
    /**
     * @brief Calculate size for the rectangle.
     *
     * RECT_SHAPE uses explicit dimensions from layout config.
     * This method applies scale factor if needed.
     */
    void calculateSize(
        entt::registry& registry,
        entt::entity entity,
        UILayoutConfig& layout,
        float scaleFactor
    ) override;

    /**
     * @brief Draw the rectangle.
     *
     * Draws using the style config (color, outline, shadow, etc.)
     * at the position/size from the transform.
     */
    void draw(
        entt::registry& registry,
        entt::entity entity,
        const UIStyleConfig& style,
        const transform::Transform& transform
    ) override;
};

} // namespace ui
