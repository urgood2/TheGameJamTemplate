#pragma once


#include "util/common_headers.hpp"
#include "ui_data.hpp"

namespace ui {

    extern auto createTooltipUIBoxDef(entt::registry &registry, ui::Tooltip tooltip) -> ui::UIElementTemplateNode;
}