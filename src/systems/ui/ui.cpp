#include "ui.hpp"

namespace ui {
    auto exposeToLua(sol::state &lua) -> void {
        
        // 1) Empty “tag” type
        lua.new_usertype<ObjectAttachedToUITag>("ObjectAttachedToUITag", 
            sol::constructors<>()
        );

        // 2) UITypeEnum
        lua.new_enum<UITypeEnum>("UITypeEnum",
            "NONE",               UITypeEnum::NONE,
            "ROOT",               UITypeEnum::ROOT,
            "VERTICAL_CONTAINER", UITypeEnum::VERTICAL_CONTAINER,
            "HORIZONTAL_CONTAINER", UITypeEnum::HORIZONTAL_CONTAINER,
            "SLIDER_UI",          UITypeEnum::SLIDER_UI,
            "INPUT_TEXT",         UITypeEnum::INPUT_TEXT,
            "RECT_SHAPE",         UITypeEnum::RECT_SHAPE,
            "TEXT",               UITypeEnum::TEXT,
            "OBJECT",             UITypeEnum::OBJECT
        );

        // 3) UIElementComponent
        lua.new_usertype<UIElementComponent>("UIElementComponent",
            sol::constructors<>(),
            "UIT",    &UIElementComponent::UIT,
            "uiBox",  &UIElementComponent::uiBox,
            "config", &UIElementComponent::config
        );

        // 4) TextInput
        lua.new_usertype<TextInput>("TextInput",
            sol::constructors<>(),
            "text",      &TextInput::text,
            "cursorPos", &TextInput::cursorPos,
            "maxLength", &TextInput::maxLength,
            "allCaps",   &TextInput::allCaps,
            "callback",  &TextInput::callback
        );

        // 5) TextInputHook
        lua.new_usertype<TextInputHook>("TextInputHook",
            sol::constructors<>(),
            "hookedEntity", &TextInputHook::hookedEntity
        );

        // 6) UIBoxComponent
        lua.new_usertype<UIBoxComponent>("UIBoxComponent",
            sol::constructors<>(),
            "uiRoot",    &UIBoxComponent::uiRoot,
            "drawLayers",&UIBoxComponent::drawLayers
        );

        // 7) UIState
        lua.new_usertype<UIState>("UIState",
            sol::constructors<>(),
            "contentDimensions",  &UIState::contentDimensions,
            "textDrawable",       &UIState::textDrawable,
            "last_clicked",       &UIState::last_clicked,
            "object_focus_timer", &UIState::object_focus_timer,
            "focus_timer",        &UIState::focus_timer
        );

        // 8) Tooltip
        lua.new_usertype<Tooltip>("Tooltip",
            sol::constructors<>(),
            "title", &Tooltip::title,
            "text",  &Tooltip::text
        );
        
        // 1) FocusArgs
        // (make sure GamepadButton is already bound in Lua)
        lua.new_usertype<FocusArgs>("FocusArgs",
            sol::constructors<>(),
            "button",           &FocusArgs::button,
            "snap_to",          &FocusArgs::snap_to,
            "registered",       &FocusArgs::registered,
            "type",             &FocusArgs::type,
            "claim_focus_from", &FocusArgs::claim_focus_from,
            "redirect_focus_to",&FocusArgs::redirect_focus_to,
            "nav",              &FocusArgs::nav,
            "no_loop",          &FocusArgs::no_loop
        );

        // 2) SliderComponent
        lua.new_usertype<SliderComponent>("SliderComponent",
            sol::constructors<>(),
            "color",          &SliderComponent::color,
            "text",           &SliderComponent::text,
            "min",            &SliderComponent::min,
            "max",            &SliderComponent::max,
            "value",          &SliderComponent::value,
            "decimal_places", &SliderComponent::decimal_places,
            "w",              &SliderComponent::w,
            "h",              &SliderComponent::h
        );

        // 3) InventoryGridTileComponent
        lua.new_usertype<InventoryGridTileComponent>("InventoryGridTileComponent",
            sol::constructors<>(),
            "item",           &InventoryGridTileComponent::item
        );

        // 4) UIStylingType enum
        lua.new_enum<UIStylingType>("UIStylingType",
            "ROUNDED_RECTANGLE", UIStylingType::ROUNDED_RECTANGLE,
            "NINEPATCH_BORDERS", UIStylingType::NINEPATCH_BORDERS
        );
        
        
        
    }
}