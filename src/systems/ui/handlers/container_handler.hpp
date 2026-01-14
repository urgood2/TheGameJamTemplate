#pragma once

#include "handler_interface.hpp"

namespace ui {

/**
 * @brief Handler for container UI elements (ROOT, VERTICAL_CONTAINER, HORIZONTAL_CONTAINER).
 *
 * Containers render their background styling (same as RECT_SHAPE) and
 * delegate children rendering to the parent system. Layout calculation
 * is handled by the box system, not by this handler.
 *
 * All three container types use identical rendering logic - they just
 * draw a styled rectangle background. The layout differences (vertical
 * vs horizontal arrangement) are handled by the box.cpp layout engine.
 */
class ContainerHandler : public IUIElementHandler {
public:
    /**
     * @brief Calculate size for the container.
     *
     * Containers don't have intrinsic sizes - their dimensions are
     * determined by their children via the layout engine in box.cpp.
     * This method is a no-op for containers.
     */
    void calculateSize(
        entt::registry& registry,
        entt::entity entity,
        UILayoutConfig& layout,
        float scaleFactor
    ) override;

    /**
     * @brief Draw the container background.
     *
     * Draws using the style config (color, outline, shadow, etc.)
     * at the position/size from the transform. Uses the same
     * rendering logic as RectHandler.
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
