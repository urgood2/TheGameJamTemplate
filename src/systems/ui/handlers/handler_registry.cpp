#include "handler_registry.hpp"
#include "rect_handler.hpp"
#include "text_handler.hpp"
#include "container_handler.hpp"
#include "object_handler.hpp"
#include <spdlog/spdlog.h>

namespace ui {

UIHandlerRegistry& UIHandlerRegistry::instance() {
    static UIHandlerRegistry inst;
    return inst;
}

void UIHandlerRegistry::registerHandler(UITypeEnum type, std::unique_ptr<IUIElementHandler> handler) {
    handlers_[type] = std::move(handler);
    SPDLOG_DEBUG("Registered handler for UITypeEnum::{}", static_cast<int>(type));
}

IUIElementHandler* UIHandlerRegistry::get(UITypeEnum type) {
    auto it = handlers_.find(type);
    return (it != handlers_.end()) ? it->second.get() : nullptr;
}

bool UIHandlerRegistry::hasHandler(UITypeEnum type) const {
    return handlers_.find(type) != handlers_.end();
}

void registerAllHandlers() {
    auto& reg = UIHandlerRegistry::instance();

    // Register type-specific handlers
    reg.registerHandler(UITypeEnum::RECT_SHAPE, std::make_unique<RectHandler>());
    reg.registerHandler(UITypeEnum::TEXT, std::make_unique<TextHandler>());

    // Container handlers (ROOT, VERTICAL_CONTAINER, HORIZONTAL_CONTAINER)
    // All three use the same rendering logic - just styled rectangle backgrounds
    reg.registerHandler(UITypeEnum::ROOT, std::make_unique<ContainerHandler>());
    reg.registerHandler(UITypeEnum::VERTICAL_CONTAINER, std::make_unique<ContainerHandler>());
    reg.registerHandler(UITypeEnum::HORIZONTAL_CONTAINER, std::make_unique<ContainerHandler>());

    // Object handler - renders focus highlight for attached objects
    reg.registerHandler(UITypeEnum::OBJECT, std::make_unique<ObjectHandler>());

    // Future handlers to add:
    // reg.registerHandler(UITypeEnum::SCROLL_PANE, std::make_unique<ScrollPaneHandler>());
    // etc.

    SPDLOG_INFO("UI handler registration complete ({} handlers)", 6);
}

} // namespace ui
