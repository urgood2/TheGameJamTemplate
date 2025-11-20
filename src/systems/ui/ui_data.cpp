#include "ui_data.hpp"
#include "systems/entity_gamestate_management/entity_gamestate_management.hpp"

namespace ui {
    bool uiGroupInitialized = false;
    decltype( std::declval<entt::registry&>()
              .group<
                UIElementComponent,
                UIConfig,
                UIState,
                transform::GameObject,
                transform::Transform
              >(entt::get<>, entt::exclude<entity_gamestate_management::InactiveTag>) )
        globalUIGroup{};

}

