#include "ui_data.hpp"


namespace ui {
    bool uiGroupInitialized = false;
    decltype( std::declval<entt::registry&>()
              .group<
                UIElementComponent,
                UIConfig,
                UIState,
                transform::GameObject,
                transform::Transform
              >() )
        globalUIGroup{};

}

