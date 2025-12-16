#pragma once

#include "entt/entity/registry.hpp"
#include "../core/ui_components.hpp"
#include "../ui_data.hpp"
#include "core/globals.hpp"
#include "systems/transform/transform_functions.hpp"
#include "systems/layer/layer.hpp"
#include <memory>

namespace ui {

// Forward declarations
struct UIConfig;
struct UIState;
struct RoundedRectangleVerticesCache;

/**
 * @brief Context passed to handlers during the draw phase.
 *
 * Contains all information needed to render a UI element,
 * including the layer pointer, z-index, and computed values.
 */
struct UIDrawContext {
    // Rendering target
    std::shared_ptr<layer::Layer> layer;
    int zIndex = 0;

    // Entity components (some may be nullptr if not present)
    UIConfig* config = nullptr;                    // Legacy config (for fallback)
    UIState* state = nullptr;                      // Runtime state
    transform::GameObject* node = nullptr;         // GameObject with displacement info
    RoundedRectangleVerticesCache* rectCache = nullptr;  // Cached vertices
    const globals::FontData* fontData = nullptr;   // Font data for text rendering

    // Computed transform values
    float actualX = 0, actualY = 0, actualW = 0, actualH = 0;
    float visualX = 0, visualY = 0, visualW = 0, visualH = 0;
    float visualScaleWithHoverAndMotion = 1.0f;
    float visualR = 0;
    float rotationOffset = 0;

    // Interaction state
    float parallaxDist = 1.2f;
    bool buttonBeingPressed = false;
    bool buttonActive = true;
};

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
     * using the provided context which includes all needed components and state.
     *
     * @param registry The ECS registry
     * @param entity The UI element entity
     * @param style Visual styling configuration
     * @param transform Current transform with position/size
     * @param ctx Draw context with layer, z-index, and computed values
     */
    virtual void draw(
        entt::registry& registry,
        entt::entity entity,
        const UIStyleConfig& style,
        const transform::Transform& transform,
        const UIDrawContext& ctx
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
