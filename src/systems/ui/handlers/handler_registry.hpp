#pragma once

#include "handler_interface.hpp"
#include "../ui_data.hpp"
#include <memory>
#include <unordered_map>

namespace ui {

/**
 * @brief Singleton registry for type-specific UI element handlers.
 *
 * Maps UITypeEnum values to their corresponding handler implementations.
 * Use UIHandlerRegistry::instance() to access the singleton.
 *
 * Example usage:
 * @code
 * auto* handler = UIHandlerRegistry::instance().get(UITypeEnum::RECT_SHAPE);
 * if (handler) {
 *     handler->draw(registry, entity, style, transform);
 * }
 * @endcode
 */
class UIHandlerRegistry {
public:
    /**
     * @brief Get the singleton instance.
     * @return Reference to the singleton registry
     */
    static UIHandlerRegistry& instance();

    /**
     * @brief Register a handler for a specific UI type.
     *
     * Takes ownership of the handler via unique_ptr.
     *
     * @param type The UI type this handler manages
     * @param handler The handler implementation
     */
    void registerHandler(UITypeEnum type, std::unique_ptr<IUIElementHandler> handler);

    /**
     * @brief Get the handler for a UI type.
     *
     * @param type The UI type to look up
     * @return Pointer to the handler, or nullptr if no handler registered
     */
    IUIElementHandler* get(UITypeEnum type);

    /**
     * @brief Check if a handler exists for a UI type.
     *
     * @param type The UI type to check
     * @return true if a handler is registered
     */
    bool hasHandler(UITypeEnum type) const;

private:
    UIHandlerRegistry() = default;
    UIHandlerRegistry(const UIHandlerRegistry&) = delete;
    UIHandlerRegistry& operator=(const UIHandlerRegistry&) = delete;

    std::unordered_map<UITypeEnum, std::unique_ptr<IUIElementHandler>> handlers_;
};

/**
 * @brief Register all built-in UI element handlers.
 *
 * Call this once at startup (after Lua is initialized but before UI is used).
 * Registers handlers for: RECT_SHAPE, TEXT, OBJECT, containers, etc.
 */
void registerAllHandlers();

} // namespace ui
