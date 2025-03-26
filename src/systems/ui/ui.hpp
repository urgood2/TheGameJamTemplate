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
#include "element.hpp"
#include "util.hpp"
#include "box.hpp"

#include "rlgl.h"
#include "raylib.h"

using namespace snowhouse; // assert

namespace ui
{
    //TODO: alignment offset is differnt from role offset. Figure out how to use them, in alignToMaster for instance
    //TODO: figure out how to hook up the ui system to the main loop

    // TODO: make a simple definition to test the ui system

    // TODO: sketch out definitions, nestable initializers,e tc.
    // TODO: should probably make a bare bones entity tree with only ui config components in place, then flesh them out by running the ui pass or something

    // TODO: need to learn how to create ui definitions & button callbacks and how to mesh input & transform updates & ui updates with the main loo
    
    //TODO: make uibox init method use the definition below
    
    // UIElementTemplateNode createUIBoxCharacterButton(
    //     GamepadButton button = GAMEPAD_BUTTON_UNKNOWN,
    //     std::optional<std::string> func = std::nullopt,
    //     Color colour = RED,
    //     std::optional<std::string> updateFunc = std::nullopt,
    //     std::optional<float> maxWidth = std::nullopt
    // ) {
    //     return UIElementTemplateNode{
    //         .type = UITypeEnum::ROOT, // Root UI element
    //         .config = { 
    //             .align = transform::Role::Alignment::HORIZONTAL_CENTER | transform::Role::Alignment::VERTICAL_CENTER,
    //             .padding = 0.1f,
    //             .colour = BLANK}, // clear 
    //         .children = { 
    //             UIElementTemplateNode{
    //                 .type = UITypeEnum::COLUMN, // Main container
    //                 .config = {
    //                     .align = transform::Role::Alignment::VERTICAL_TOP | transform::Role::Alignment::HORIZONTAL_CENTER,
    //                     .min_width = 1.9f, 
    //                     .padding = 0.2f,
    //                     // .min_height = 1.2f,
    //                     // .r = 0.1f, 
    //                     //TODO: r seems to be a resolution variable, but it's not actually used.
    //                     .hover = true,
    //                     .colour = colour,
    //                     // .button = button, 
    //                     //TODO: button should be string like "buy_from_shop". It is the identifier of a function. Figure out thw relationship with func, which is also a function
    //                     .func = updateFunc.value_or(""), //TODO: this function seems to be called every frame.
    //                     // .shadow = true,
    //                     // .max_width = maxWidth.value_or(0.0f)
    //                 },
    //                 .children = {
    //                     UIElementTemplateNode{
    //                         .type = UITypeEnum::ROW, // Row holding text
    //                         .config = {
    //                             .align = transform::Role::Alignment::HORIZONTAL_CENTER | transform::Role::Alignment::VERTICAL_CENTER,
    //                             .padding = 0.0f,
    //                         },
    //                         .children = {
    //                             UIElementTemplateNode{
    //                                 .type = UITypeEnum::TEXT, // Text element
    //                                 .config = {
    //                                     .colour =Color{255, 255, 255, 255},
    //                                     .text = "example test",
    //                                     // .scale = 0.55f,
                                        
    //                                     .focusArgs = {
    //                                         //TODO: not sure about func or orientation
    //                                         // .button = GamepadButton::DPAD_UP,
    //                                         // .orientation = "bm",
    //                                         // .func = "set_button_pip"
    //                                     }
    //                                 }
    //                             }
    //                         }
    //                     }
    //                 }
    //             }
    //         }
    //     };
            
    // }
    

    

}
