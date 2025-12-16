#include "rect_handler.hpp"
#include <spdlog/spdlog.h>

namespace ui {

void RectHandler::calculateSize(
    entt::registry& registry,
    entt::entity entity,
    UILayoutConfig& layout,
    float scaleFactor
) {
    // RECT_SHAPE uses explicit dimensions from config
    // Size calculation is straightforward - just apply scale if needed
    // The actual sizing is handled by the layout engine in box.cpp

    // For now, this is a placeholder
    // Future work: Move size calculation logic here from box.cpp
}

void RectHandler::draw(
    entt::registry& registry,
    entt::entity entity,
    const UIStyleConfig& style,
    const transform::Transform& t
) {
    // Delegate to existing util functions for now
    // This will be refactored to self-contained logic later
    //
    // Future implementation will:
    // 1. Get the draw layer/command buffer
    // 2. Based on stylingType, call appropriate drawing:
    //    - ROUNDED_RECTANGLE: DrawSteppedRoundedRectangle
    //    - NINEPATCH_BORDERS: Draw 9-patch
    //    - SPRITE: Draw sprite with scale mode

    // Rectangle rect = { t.actualX, t.actualY, t.actualW, t.actualH };

    // For now, this is a placeholder - actual drawing remains in element.cpp
    // The migration will be: element::DrawSelf -> handler->draw()
}

} // namespace ui
