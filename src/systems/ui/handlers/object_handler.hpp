#pragma once

#include "handler_interface.hpp"

namespace ui {

/**
 * @brief Handler for OBJECT UI elements.
 *
 * OBJECT elements display an attached object (entity) and optionally
 * render a focus highlight when the object is focused.
 *
 * The object content rendering is typically handled elsewhere (by the
 * attached entity's own rendering system), so this handler primarily
 * deals with the focus highlight overlay.
 */
class ObjectHandler : public IUIElementHandler {
public:
    /**
     * @brief Calculate size for the object element.
     *
     * OBJECT elements typically derive size from the attached object
     * or use explicit dimensions from layout config.
     */
    void calculateSize(
        entt::registry& registry,
        entt::entity entity,
        UILayoutConfig& layout,
        float scaleFactor
    ) override;

    /**
     * @brief Draw the object element.
     *
     * Draws focus highlight (filled + outline rounded rectangles) when
     * the attached object is focused. Object content is rendered by
     * the attached entity's rendering system.
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
