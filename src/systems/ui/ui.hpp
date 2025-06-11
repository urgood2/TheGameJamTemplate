#pragma once

#include "util/common_headers.hpp"

#include <string>
#include <vector>
#include <unordered_map>
#include <variant>
#include <functional>

#include "systems/transform/transform_functions.hpp"
#include "systems/input/input_functions.hpp"
#include "systems/layer/layer.hpp"
#include "systems/reflection/reflection.hpp"

#include "ui_data.hpp"
#include "common_definitions.hpp"
#include "element.hpp"
#include "util.hpp"
#include "box.hpp"

#include "rlgl.h"
#include "raylib.h"

using namespace snowhouse; // assert


namespace ui {
    
    extern auto exposeToLua(sol::state &lua) -> void;
}