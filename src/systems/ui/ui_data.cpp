#include "ui_data.hpp"
#include "systems/entity_gamestate_management/entity_gamestate_management.hpp"
#include "systems/transform/transform.hpp"

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

    bool hasConflictingAlignmentFlags(int flags, std::string* conflictDescription) {
        using Align = transform::InheritedProperties::Alignment;

        bool vCenter = flags & Align::VERTICAL_CENTER;
        bool vTop    = flags & Align::VERTICAL_TOP;
        bool vBottom = flags & Align::VERTICAL_BOTTOM;
        bool hCenter = flags & Align::HORIZONTAL_CENTER;
        bool hLeft   = flags & Align::HORIZONTAL_LEFT;
        bool hRight  = flags & Align::HORIZONTAL_RIGHT;

        std::string conflict;

        // Check vertical conflicts
        if (vCenter && vTop) {
            conflict = "VERTICAL_CENTER conflicts with VERTICAL_TOP";
        } else if (vCenter && vBottom) {
            conflict = "VERTICAL_CENTER conflicts with VERTICAL_BOTTOM";
        } else if (vTop && vBottom) {
            conflict = "VERTICAL_TOP conflicts with VERTICAL_BOTTOM";
        }
        // Check horizontal conflicts
        else if (hCenter && hLeft) {
            conflict = "HORIZONTAL_CENTER conflicts with HORIZONTAL_LEFT";
        } else if (hCenter && hRight) {
            conflict = "HORIZONTAL_CENTER conflicts with HORIZONTAL_RIGHT";
        } else if (hLeft && hRight) {
            conflict = "HORIZONTAL_LEFT conflicts with HORIZONTAL_RIGHT";
        }

        if (!conflict.empty()) {
            if (conflictDescription) {
                *conflictDescription = conflict;
            }
            return true;
        }

        return false;
    }

}

