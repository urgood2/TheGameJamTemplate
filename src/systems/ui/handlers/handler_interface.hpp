#pragma once

#include "entt/entity/registry.hpp"
#include "../core/ui_components.hpp"
#include "systems/transform/transform_functions.hpp"

namespace ui {

/**
 * @brief Base interface for type-specific UI element handlers.
 *
 * Each UI element type (RECT_SHAPE, TEXT, OBJECT, etc.) has its own handler
 * that implements type-specific layout, rendering, and interaction logic.
 * This is the Strategy pattern for UI element behavior.
 */
struct IUIElementHandler {
    virtual ~IUIElementHandler() = default;

    /**
     * @brief Layout phase - calculate element dimensions.
     *
     * Called during the size calculation pass. Handler should update
     * the layout config (width/height) if the element has intrinsic size.
     *
     * @param registry The ECS registry
     * @param entity The UI element entity
     * @param layout The layout config to potentially update
     * @param scaleFactor Current UI scale factor
     */
    virtual void calculateSize(
        entt::registry& registry,
        entt::entity entity,
        UILayoutConfig& layout,
        float scaleFactor
    ) = 0;

    /**
     * @brief Render phase - draw the element.
     *
     * Called during the draw pass. Handler should render the element
     * using the style config and transform.
     *
     * @param registry The ECS registry
     * @param entity The UI element entity
     * @param style Visual styling configuration
     * @param transform Current transform with position/size
     */
    virtual void draw(
        entt::registry& registry,
        entt::entity entity,
        const UIStyleConfig& style,
        const transform::Transform& transform
    ) = 0;

    /**
     * @brief Optional: handle click input.
     *
     * Called when the element is clicked. Default returns false (not handled).
     *
     * @param registry The ECS registry
     * @param entity The UI element entity
     * @param interaction Interaction config to potentially update
     * @param mousePos Position of the click
     * @return true if the click was handled
     */
    virtual bool handleClick(
        entt::registry& registry,
        entt::entity entity,
        UIInteractionConfig& interaction,
        Vector2 mousePos
    ) { return false; }

    /**
     * @brief Optional: handle hover state.
     *
     * Called when the element is being hovered. Default does nothing.
     *
     * @param registry The ECS registry
     * @param entity The UI element entity
     * @param interaction Interaction config to potentially update
     */
    virtual void handleHover(
        entt::registry& registry,
        entt::entity entity,
        UIInteractionConfig& interaction
    ) {}

    /**
     * @brief Optional: per-frame update.
     *
     * Called every frame for elements that need continuous updates.
     * Default does nothing.
     *
     * @param registry The ECS registry
     * @param entity The UI element entity
     * @param dt Delta time since last frame
     */
    virtual void update(
        entt::registry& registry,
        entt::entity entity,
        float dt
    ) {}
};

} // namespace ui
