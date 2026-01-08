#include "sol/sol.hpp"
#include "ui.hpp"
#include "ui_pack.hpp"
#include "systems/ui/core/ui_components.hpp"

#include "systems/scripting/binding_recorder.hpp"

namespace ui {
    auto exposeToLua(sol::state &lua) -> void {
    
        // BindingRecorder instance
        auto& rec = BindingRecorder::instance();

        //=========================================================
        // Part 1: UI Component & Enum Definitions
        //=========================================================

        // 1) Empty “tag” type
        lua.new_usertype<ObjectAttachedToUITag>("ObjectAttachedToUITag", 
            sol::constructors<>(),
            "type_id", []() { return entt::type_hash<ObjectAttachedToUITag>::value(); }
        );
        rec.add_type("ObjectAttachedToUITag").doc = "A tag component indicating an entity is attached to a UI element.";

        // 2) UITypeEnum
        lua.new_enum("UITypeEnum",
            std::initializer_list<std::pair<sol::string_view, UITypeEnum>>{
                {"NONE",                 UITypeEnum::NONE},
                {"ROOT",                 UITypeEnum::ROOT},
                {"VERTICAL_CONTAINER",   UITypeEnum::VERTICAL_CONTAINER},
                {"HORIZONTAL_CONTAINER", UITypeEnum::HORIZONTAL_CONTAINER},
                {"SCROLL_PANE",          UITypeEnum::SCROLL_PANE},
                {"SLIDER_UI",            UITypeEnum::SLIDER_UI},
                {"INPUT_TEXT",           UITypeEnum::INPUT_TEXT},
                {"RECT_SHAPE",           UITypeEnum::RECT_SHAPE},
                {"TEXT",                 UITypeEnum::TEXT},
                {"OBJECT",               UITypeEnum::OBJECT}
            }
        );
        auto& uiTypeEnum = rec.add_type("UITypeEnum");
        uiTypeEnum.doc = "Defines the fundamental type or behavior of a UI element.";
        rec.record_property("UITypeEnum", {"NONE", "0", "No specific UI type."});
        rec.record_property("UITypeEnum", {"ROOT", "1", "The root of a UI tree."});
        rec.record_property("UITypeEnum", {"VERTICAL_CONTAINER", "2", "Arranges children vertically."});
        rec.record_property("UITypeEnum", {"HORIZONTAL_CONTAINER", "3", "Arranges children horizontally."});
        rec.record_property("UITypeEnum", {"SCROLL_PANE", "4", "A scrollable panel for content."});
        rec.record_property("UITypeEnum", {"SLIDER_UI", "5", "A slider UI element."});
        rec.record_property("UITypeEnum", {"INPUT_TEXT", "6", "A text input UI element."});
        rec.record_property("UITypeEnum", {"RECT_SHAPE", "7", "A rectangular shape UI element."});
        rec.record_property("UITypeEnum", {"TEXT", "8", "A simple text UI element."});
        rec.record_property("UITypeEnum", {"OBJECT", "9", "A game object UI element."});
        // 3) UIElementComponent
        lua.new_usertype<UIElementComponent>("UIElementComponent",
            sol::constructors<>(),
            "UIT",    &UIElementComponent::UIT,
            "uiBox",  &UIElementComponent::uiBox,
            "config", &UIElementComponent::config,
            "type_id", []() { return entt::type_hash<UIElementComponent>::value(); }
        );
        auto& uieDef = rec.add_type("UIElementComponent", /*is_data_class=*/true);
        uieDef.doc = "Core component for a UI element, linking its type, root, and configuration.";
        rec.record_property("UIElementComponent", {"UIT", "UITypeEnum", "The type of this UI element."});
        rec.record_property("UIElementComponent", {"uiBox", "Entity", "The root entity of the UI box this element belongs to."});
        rec.record_property("UIElementComponent", {"config", "UIConfig", "The configuration settings for this element."});

        // 4) TextInput
        lua.new_usertype<TextInput>("TextInput",
            sol::constructors<>(),
            "text",      &TextInput::text,
            "cursorPos", &TextInput::cursorPos,
            "maxLength", &TextInput::maxLength,
            "allCaps",   &TextInput::allCaps,
            "callback",  &TextInput::callback,
            "type_id", []() { return entt::type_hash<TextInput>::value(); }
        );
        auto& textInDef = rec.add_type("TextInput", /*is_data_class=*/true);
        textInDef.doc = "Component for managing the state of a text input UI element.";
        rec.record_property("TextInput", {"text", "string", "The current text content."});
        rec.record_property("TextInput", {"cursorPos", "integer", "The position of the text cursor."});
        rec.record_property("TextInput", {"maxLength", "integer", "The maximum allowed length of the text."});
        rec.record_property("TextInput", {"allCaps", "boolean", "If true, all input is converted to uppercase."});
        rec.record_property("TextInput", {"callback", "function|nil", "A callback function triggered on text change."});

        // 5) TextInputHook
        lua.new_usertype<TextInputHook>("TextInputHook",
            sol::constructors<>(),
            "hookedEntity", &TextInputHook::hookedEntity,
            "type_id", []() { return entt::type_hash<TextInputHook>::value(); }
        );
        auto& hookDef = rec.add_type("TextInputHook", /*is_data_class=*/true);
        hookDef.doc = "A component that hooks global text input to a specific text input entity.";
        rec.record_property("TextInputHook", {"hookedEntity", "Entity", "The entity that currently has text input focus."});

        // 6) UIBoxComponent
        lua.new_usertype<UIBoxComponent>("UIBoxComponent",
            "uiRoot",     &UIBoxComponent::uiRoot,
            "drawLayers", &UIBoxComponent::drawLayers,
            "onBoxResize", &UIBoxComponent::onBoxResize,
            "type_id", []() { return entt::type_hash<UIBoxComponent>::value(); }
        );
        auto& boxDef = rec.add_type("UIBoxComponent", /*is_data_class=*/true);
        boxDef.doc = "Defines a root of a UI tree, managing its draw layers.";
        rec.record_property("UIBoxComponent", {"uiRoot", "Entity", "The root entity of this UI tree."});
        rec.record_property("UIBoxComponent", {"drawLayers", "table", "A map of layers used for drawing the UI."});
        rec.record_property("UIBoxComponent", {"onBoxResize", "function|nil", "A callback function triggered when the box is resized."});

        // 7) UIState
        lua.new_usertype<UIState>("UIState",
            sol::constructors<>(),
            "contentDimensions", &UIState::contentDimensions,
            "textDrawable",      &UIState::textDrawable,
            "last_clicked",      &UIState::last_clicked,
            "object_focus_timer",&UIState::object_focus_timer,
            "focus_timer",       &UIState::focus_timer,
            "type_id", []() { return entt::type_hash<UIState>::value(); }
        );
        auto& uiStateDef = rec.add_type("UIState", /*is_data_class=*/true);
        uiStateDef.doc = "Holds dynamic state information for a UI element.";
        rec.record_property("UIState", {"contentDimensions", "Vector2", "The calculated dimensions of the element's content."});
        rec.record_property("UIState", {"textDrawable", "TextDrawable", "The drawable text object."});
        rec.record_property("UIState", {"last_clicked", "Entity", "The last entity that was clicked within this UI context."});
        rec.record_property("UIState", {"object_focus_timer", "number", "Timer for object focus events."});
        rec.record_property("UIState", {"focus_timer", "number", "General purpose focus timer."});

        // 8) Tooltip
        lua.new_usertype<Tooltip>("Tooltip",
            sol::constructors<Tooltip()>(),
            "title", &Tooltip::title,
            "text",  &Tooltip::text,
            "type_id", []() { return entt::type_hash<Tooltip>::value(); }
        );
        auto& tooltipDef = rec.add_type("Tooltip", /*is_data_class=*/true);
        tooltipDef.doc = "Represents a tooltip with a title and descriptive text.";
        rec.record_property("Tooltip", {"title", "string", "The title of the tooltip."});
        rec.record_property("Tooltip", {"text", "string", "The main body text of the tooltip."});

        // 9) FocusArgs
        lua.new_usertype<FocusArgs>("FocusArgs",
            sol::constructors<FocusArgs()>(),
            "button",            &FocusArgs::button,
            "snap_to",           &FocusArgs::snap_to,
            "registered",        &FocusArgs::registered,
            "type",              &FocusArgs::type,
            "claim_focus_from",  &FocusArgs::claim_focus_from,
            "redirect_focus_to", &FocusArgs::redirect_focus_to,
            "nav",               &FocusArgs::nav,
            "no_loop",           &FocusArgs::no_loop,
            "type_id", []() { return entt::type_hash<FocusArgs>::value(); }
        );
        auto& focusDef = rec.add_type("FocusArgs", /*is_data_class=*/true);
        focusDef.doc = "Arguments for configuring focus and navigation behavior.";
        rec.record_property("FocusArgs", {"button", "GamepadButton", "The gamepad button associated with this focus."});
        rec.record_property("FocusArgs", {"snap_to", "boolean", "If the view should snap to this element when focused."});
        rec.record_property("FocusArgs", {"registered", "boolean", "Whether this focus is registered with the focus system."});
        rec.record_property("FocusArgs", {"type", "string", "The type of focus."});
        rec.record_property("FocusArgs", {"claim_focus_from", "table<string, Entity>", "Entities this element can claim focus from."});
        rec.record_property("FocusArgs", {"redirect_focus_to", "Entity|nil", "Redirect focus to another entity."});
        rec.record_property("FocusArgs", {"nav", "table<string, Entity>", "Navigation map (e.g., nav.up = otherEntity)."});
        rec.record_property("FocusArgs", {"no_loop", "boolean", "Disables navigation looping."});

        // 10) SliderComponent
        lua.new_usertype<SliderComponent>("SliderComponent",
            sol::constructors<>(),
            "color",          &SliderComponent::color,
            "text",           &SliderComponent::text,
            "min",            &SliderComponent::min,
            "max",            &SliderComponent::max,
            "value",          &SliderComponent::value,
            "decimal_places", &SliderComponent::decimal_places,
            "w",              &SliderComponent::w,
            "h",              &SliderComponent::h,
            "type_id", []() { return entt::type_hash<SliderComponent>::value(); }
        );
        auto& sliderDef = rec.add_type("SliderComponent", /*is_data_class=*/true);
        sliderDef.doc = "Data for a UI slider element.";
        rec.record_property("SliderComponent", {"color", "string"});
        rec.record_property("SliderComponent", {"text", "string"});
        rec.record_property("SliderComponent", {"min", "number"});
        rec.record_property("SliderComponent", {"max", "number"});
        rec.record_property("SliderComponent", {"value", "number"});
        rec.record_property("SliderComponent", {"decimal_places", "integer"});
        rec.record_property("SliderComponent", {"w", "number"});
        rec.record_property("SliderComponent", {"h", "number"});

        // 11) InventoryGridTileComponent
        lua.new_usertype<InventoryGridTileComponent>("InventoryGridTileComponent",
            sol::constructors<>(),
            "item", &InventoryGridTileComponent::item,
            "type_id", []() { return entt::type_hash<InventoryGridTileComponent>::value(); }
        );
        auto& invTileDef = rec.add_type("InventoryGridTileComponent", /*is_data_class=*/true);
        invTileDef.doc = "Represents a tile in an inventory grid, potentially holding an item.";
        rec.record_property("InventoryGridTileComponent", {"item", "Entity|nil", "The item entity occupying this tile."});

        // 12) UIStylingType Enum
        lua.new_enum<UIStylingType>("UIStylingType", {
            {"RoundedRectangle", UIStylingType::ROUNDED_RECTANGLE},
            {"NinePatchBorders", UIStylingType::NINEPATCH_BORDERS},
            {"Sprite", UIStylingType::SPRITE}
        });
        auto& styleEnum = rec.add_type("UIStylingType");
        styleEnum.doc = "Defines how a UI element's background is styled.";
        rec.record_property("UIStylingType", {"RoundedRectangle", "0", "A simple rounded rectangle."});
        rec.record_property("UIStylingType", {"NinePatchBorders", "1", "A 9-patch texture for scalable borders."});
        rec.record_property("UIStylingType", {"Sprite", "2", "A sprite texture with configurable scale mode."});

        // 12b) UIDecoration::Anchor Enum
        lua.new_enum<UIDecoration::Anchor>("UIDecorationAnchor", {
            {"TopLeft",      UIDecoration::Anchor::TopLeft},
            {"TopCenter",    UIDecoration::Anchor::TopCenter},
            {"TopRight",     UIDecoration::Anchor::TopRight},
            {"MiddleLeft",   UIDecoration::Anchor::MiddleLeft},
            {"Center",       UIDecoration::Anchor::Center},
            {"MiddleRight",  UIDecoration::Anchor::MiddleRight},
            {"BottomLeft",   UIDecoration::Anchor::BottomLeft},
            {"BottomCenter", UIDecoration::Anchor::BottomCenter},
            {"BottomRight",  UIDecoration::Anchor::BottomRight}
        });
        auto& anchorEnum = rec.add_type("UIDecorationAnchor");
        anchorEnum.doc = "Defines the anchor point for a UI decoration relative to its parent.";
        rec.record_property("UIDecorationAnchor", {"TopLeft", "0", "Anchor to top-left corner."});
        rec.record_property("UIDecorationAnchor", {"TopCenter", "1", "Anchor to top-center."});
        rec.record_property("UIDecorationAnchor", {"TopRight", "2", "Anchor to top-right corner."});
        rec.record_property("UIDecorationAnchor", {"MiddleLeft", "3", "Anchor to middle-left."});
        rec.record_property("UIDecorationAnchor", {"Center", "4", "Anchor to center."});
        rec.record_property("UIDecorationAnchor", {"MiddleRight", "5", "Anchor to middle-right."});
        rec.record_property("UIDecorationAnchor", {"BottomLeft", "6", "Anchor to bottom-left corner."});
        rec.record_property("UIDecorationAnchor", {"BottomCenter", "7", "Anchor to bottom-center."});
        rec.record_property("UIDecorationAnchor", {"BottomRight", "8", "Anchor to bottom-right corner."});

        // 12c) UIDecoration struct
        lua.new_usertype<UIDecoration>("UIDecoration",
            sol::constructors<UIDecoration()>(),
            "spriteName", &UIDecoration::spriteName,
            "anchor",     &UIDecoration::anchor,
            "offset",     &UIDecoration::offset,
            "opacity",    &UIDecoration::opacity,
            "flipX",      &UIDecoration::flipX,
            "flipY",      &UIDecoration::flipY,
            "rotation",   &UIDecoration::rotation,
            "scale",      &UIDecoration::scale,
            "zOffset",    &UIDecoration::zOffset,
            "tint",       &UIDecoration::tint,
            "visible",    &UIDecoration::visible,
            "id",         &UIDecoration::id
        );
        auto& decorDef = rec.add_type("UIDecoration", /*is_data_class=*/true);
        decorDef.doc = "A decorative sprite overlay that can be attached to UI elements.";
        rec.record_property("UIDecoration", {"spriteName", "string", "The name of the sprite to display."});
        rec.record_property("UIDecoration", {"anchor", "UIDecorationAnchor", "The anchor point for positioning."});
        rec.record_property("UIDecoration", {"offset", "Vector2", "Offset from the anchor point."});
        rec.record_property("UIDecoration", {"opacity", "number", "Opacity (0.0 to 1.0)."});
        rec.record_property("UIDecoration", {"flipX", "boolean", "Whether to flip horizontally."});
        rec.record_property("UIDecoration", {"flipY", "boolean", "Whether to flip vertically."});
        rec.record_property("UIDecoration", {"rotation", "number", "Rotation in radians."});
        rec.record_property("UIDecoration", {"scale", "Vector2", "Scale factor."});
        rec.record_property("UIDecoration", {"zOffset", "integer", "Z-order offset for layering."});
        rec.record_property("UIDecoration", {"tint", "Color", "Color tint to apply."});
        rec.record_property("UIDecoration", {"visible", "boolean", "Whether the decoration is visible."});
        rec.record_property("UIDecoration", {"id", "string", "Optional identifier for the decoration."});

        // 12d) UIDecorations container
        lua.new_usertype<UIDecorations>("UIDecorations",
            sol::constructors<UIDecorations()>(),
            "items", &UIDecorations::items
        );
        auto& decorsDef = rec.add_type("UIDecorations", /*is_data_class=*/true);
        decorsDef.doc = "A collection of UI decorations attached to an element.";
        rec.record_property("UIDecorations", {"items", "UIDecoration[]", "The list of decorations."});

        // 13) UIConfig
        lua.new_usertype<UIConfig>("UIConfig",  sol::call_constructor, sol::constructors<UIConfig>(),
            // Styling
            "stylingType",           &UIConfig::stylingType,
            "nPatchInfo",            &UIConfig::nPatchInfo,
            "nPatchSourceTexture",   &UIConfig::nPatchSourceTexture,
            "spriteSourceTexture",   &UIConfig::spriteSourceTexture,
            "spriteSourceRect",      &UIConfig::spriteSourceRect,
            "spriteScaleMode",       &UIConfig::spriteScaleMode,
            "decorations",           &UIConfig::decorations,
            // General
            "id",                    &UIConfig::id,
            "instanceType",          &UIConfig::instanceType,
            "uiType",                &UIConfig::uiType,
            "drawLayer",             &UIConfig::drawLayer,
            "group",                 &UIConfig::group,
            "groupParent",           &UIConfig::groupParent,
            // Position & transform
            "location_bond",         &UIConfig::location_bond,
            "rotation_bond",         &UIConfig::rotation_bond,
            "size_bond",             &UIConfig::size_bond,
            "scale_bond",            &UIConfig::scale_bond,
            "offset",                &UIConfig::offset,
            "scale",                 &UIConfig::scale,
            "textSpacing",           &UIConfig::textSpacing,
            "focusWithObject",       &UIConfig::focusWithObject,
            "refreshMovement",       &UIConfig::refreshMovement,
            "no_recalc",             &UIConfig::no_recalc,
            "non_recalc",            &UIConfig::non_recalc,
            "noMovementWhenDragged", &UIConfig::noMovementWhenDragged,
            // Hierarchy
            "master",                &UIConfig::master,
            "parent",                &UIConfig::parent,
            "object",                &UIConfig::object,
            "objectRecalculate",     &UIConfig::objectRecalculate,
            // Dimensions & alignment
            "alignmentFlags",        &UIConfig::alignmentFlags,
            "width",                 &UIConfig::width,
            "height",                &UIConfig::height,
            "maxWidth",              &UIConfig::maxWidth,
            "maxHeight",             &UIConfig::maxHeight,
            "minWidth",              &UIConfig::minWidth,
            "minHeight",             &UIConfig::minHeight,
            "padding",               &UIConfig::padding,
            // Appearance
            "color",                 &UIConfig::color,
            "outlineColor",          &UIConfig::outlineColor,
            "outlineThickness",      &UIConfig::outlineThickness,
            "makeMovementDynamic",   &UIConfig::makeMovementDynamic,
            "shadow",                &UIConfig::shadow,
            "outlineShadow",         &UIConfig::outlineShadow,
            "shadowColor",           &UIConfig::shadowColor,
            "noFill",                &UIConfig::noFill,
            "pixelatedRectangle",    &UIConfig::pixelatedRectangle,
            // Collision & interactivity
            "canCollide",            &UIConfig::canCollide,
            "collideable",           &UIConfig::collideable,
            "forceCollision",        &UIConfig::forceCollision,
            "button_UIE",            &UIConfig::button_UIE,
            "disable_button",        &UIConfig::disable_button,
            // Progress bar
            "progressBarFetchValueLambda", &UIConfig::progressBarFetchValueLambda,
            "progressBar",                 &UIConfig::progressBar,
            "progressBarEmptyColor",       &UIConfig::progressBarEmptyColor,
            "progressBarFullColor",        &UIConfig::progressBarFullColor,
            "progressBarMaxValue",         &UIConfig::progressBarMaxValue,
            "progressBarValueComponentName", &UIConfig::progressBarValueComponentName,
            "progressBarValueFieldName",   &UIConfig::progressBarValueFieldName,
            "ui_object_updated",           &UIConfig::ui_object_updated,
            // Button delays & clicks
            "buttonDelayStart",        &UIConfig::buttonDelayStart,
            "buttonDelay",             &UIConfig::buttonDelay,
            "buttonDelayProgress",     &UIConfig::buttonDelayProgress,
            "buttonDelayEnd",          &UIConfig::buttonDelayEnd,
            "buttonClicked",           &UIConfig::buttonClicked,
            "buttonDistance",          &UIConfig::buttonDistance,
            // Tooltips & hover
            "tooltip",                 &UIConfig::tooltip,
            "detailedTooltip",         &UIConfig::detailedTooltip,
            "onDemandTooltip",         &UIConfig::onDemandTooltip,
            "hover",                   &UIConfig::hover,
            // Special behaviors
            "force_focus",             &UIConfig::force_focus,
            "dynamicMotion",           &UIConfig::dynamicMotion,
            "choice",                  &UIConfig::choice,
            "chosen",                  &UIConfig::chosen,
            "one_press",               &UIConfig::one_press,
            "chosen_vert",             &UIConfig::chosen_vert,
            "draw_after",              &UIConfig::draw_after,
            "focusArgs",               &UIConfig::focusArgs,
            // Scripting callbacks
            "updateFunc",              &UIConfig::updateFunc,
            "initFunc",                &UIConfig::initFunc,
            "onUIResizeFunc",          &UIConfig::onUIResizeFunc,
            "onUIScalingResetToOne",   &UIConfig::onUIScalingResetToOne,
            "instaFunc",               &UIConfig::instaFunc,
            "buttonCallback",          &UIConfig::buttonCallback,
            "buttonTemp",              &UIConfig::buttonTemp,
            "textGetter",              &UIConfig::textGetter,
            // References & text
            "ref_entity",              &UIConfig::ref_entity,
            "ref_component",           &UIConfig::ref_component,
            "ref_value",               &UIConfig::ref_value,
            "prev_ref_value",          &UIConfig::prev_ref_value,
            "text",                    &UIConfig::text,
            "language",                &UIConfig::language,
            "verticalText",            &UIConfig::verticalText,
            // Popups
            "hPopup",                  &UIConfig::hPopup,
            "dPopup",                  &UIConfig::dPopup,
            "hPopupConfig",            &UIConfig::hPopupConfig,
            "dPopupConfig",            &UIConfig::dPopupConfig,
            // Misc
            "extend_up",               &UIConfig::extend_up,
            "resolution",              &UIConfig::resolution,
            "emboss",                  &UIConfig::emboss,
            "line_emboss",             &UIConfig::line_emboss,
            "mid",                     &UIConfig::mid,
            "noRole",                  &UIConfig::noRole,
            "role",                    &UIConfig::role,
            
            
            "type_id", []() { return entt::type_hash<UIConfig>::value(); }
        );
        auto& cfgDef = rec.add_type("UIConfig", /*is_data_class=*/true);
        cfgDef.doc = "A comprehensive configuration component for defining all aspects of a UI element.";
        // Styling
        rec.record_property("UIConfig", {"stylingType", "UIStylingType|nil", "The visual style of the element."});
        rec.record_property("UIConfig", {"nPatchInfo", "NPatchInfo|nil", "9-patch slicing information."});
        rec.record_property("UIConfig", {"nPatchSourceTexture", "string|nil", "Texture path for the 9-patch."});
        rec.record_property("UIConfig", {"spriteSourceTexture", "Texture2D*|nil", "Pointer to the sprite source texture."});
        rec.record_property("UIConfig", {"spriteSourceRect", "Rectangle|nil", "Source rectangle in the sprite texture."});
        rec.record_property("UIConfig", {"spriteScaleMode", "SpriteScaleMode", "How the sprite should be scaled (default: Stretch)."});
        // General
        rec.record_property("UIConfig", {"id", "string|nil", "Unique identifier for this UI element."});
        rec.record_property("UIConfig", {"instanceType", "string|nil", "A specific instance type for categorization."});
        rec.record_property("UIConfig", {"uiType", "UITypeEnum|nil", "The fundamental type of the UI element."});
        rec.record_property("UIConfig", {"drawLayer", "string|nil", "The layer on which this element is drawn."});
        rec.record_property("UIConfig", {"group", "string|nil", "The focus group this element belongs to."});
        rec.record_property("UIConfig", {"groupParent", "string|nil", "The parent focus group."});
        // Position & transform
        rec.record_property("UIConfig", {"location_bond", "InheritedPropertiesSync|nil", "Bonding strength for location."});
        rec.record_property("UIConfig", {"rotation_bond", "InheritedPropertiesSync|nil", "Bonding strength for rotation."});
        rec.record_property("UIConfig", {"size_bond", "InheritedPropertiesSync|nil", "Bonding strength for size."});
        rec.record_property("UIConfig", {"scale_bond", "InheritedPropertiesSync|nil", "Bonding strength for scale."});
        rec.record_property("UIConfig", {"offset", "Vector2|nil", "Offset from the parent/aligned position."});
        rec.record_property("UIConfig", {"scale", "number|nil", "Scale multiplier."});
        rec.record_property("UIConfig", {"textSpacing", "number|nil", "Spacing for text characters."});
        rec.record_property("UIConfig", {"focusWithObject", "boolean|nil", "Whether focus is tied to a game object."});
        rec.record_property("UIConfig", {"refreshMovement", "boolean|nil", "Force movement refresh."});
        rec.record_property("UIConfig", {"no_recalc", "boolean|nil", "Prevents recalculation of transform."});
        rec.record_property("UIConfig", {"non_recalc", "boolean|nil", "Alias for no_recalc."});
        rec.record_property("UIConfig", {"noMovementWhenDragged", "boolean|nil", "Prevents movement while being dragged."});
        // Hierarchy
        rec.record_property("UIConfig", {"master", "string|nil", "ID of the master element."});
        rec.record_property("UIConfig", {"parent", "string|nil", "ID of the parent element."});
        rec.record_property("UIConfig", {"object", "Entity|nil", "The game object associated with this UI element."});
        rec.record_property("UIConfig", {"objectRecalculate", "boolean|nil", "Force recalculation based on the object."});
        // Dimensions & alignment
        rec.record_property("UIConfig", {"alignmentFlags", "integer|nil", "Bitmask of alignment flags."});
        rec.record_property("UIConfig", {"width", "number|nil", "Explicit width."});
        rec.record_property("UIConfig", {"height", "number|nil", "Explicit height."});
        rec.record_property("UIConfig", {"maxWidth", "number|nil", "Maximum width."});
        rec.record_property("UIConfig", {"maxHeight", "number|nil", "Maximum height."});
        rec.record_property("UIConfig", {"minWidth", "number|nil", "Minimum width."});
        rec.record_property("UIConfig", {"minHeight", "number|nil", "Minimum height."});
        rec.record_property("UIConfig", {"padding", "number|nil", "Padding around the content."});
        // Appearance
        rec.record_property("UIConfig", {"color", "string|nil", "Background color."});
        rec.record_property("UIConfig", {"outlineColor", "string|nil", "Outline color."});
        rec.record_property("UIConfig", {"outlineThickness", "number|nil", "Outline thickness in pixels."});
        rec.record_property("UIConfig", {"makeMovementDynamic", "boolean|nil", "Enables springy movement."});
        rec.record_property("UIConfig", {"shadow", "Vector2|nil", "Offset for the shadow."});
        rec.record_property("UIConfig", {"outlineShadow", "Vector2|nil", "Offset for the outline shadow."});
        rec.record_property("UIConfig", {"shadowColor", "string|nil", "Color of the shadow."});
        rec.record_property("UIConfig", {"noFill", "boolean|nil", "If true, the background is not filled."});
        rec.record_property("UIConfig", {"pixelatedRectangle", "boolean|nil", "Use pixel-perfect rectangle drawing."});
        // Collision & interactivity
        rec.record_property("UIConfig", {"canCollide", "boolean|nil", "Whether collision is possible."});
        rec.record_property("UIConfig", {"collideable", "boolean|nil", "Alias for canCollide."});
        rec.record_property("UIConfig", {"forceCollision", "boolean|nil", "Forces collision checks."});
        rec.record_property("UIConfig", {"button_UIE", "boolean|nil", "Behaves as a button."});
        rec.record_property("UIConfig", {"disable_button", "boolean|nil", "Disables button functionality."});
        // Progress bar
        rec.record_property("UIConfig", {"progressBarFetchValueLambda", "function|nil", "Function to get the progress bar's current value."});
        rec.record_property("UIConfig", {"progressBar", "boolean|nil", "If this element is a progress bar."});
        rec.record_property("UIConfig", {"progressBarEmptyColor", "string|nil", "Color of the empty part of the progress bar."});
        rec.record_property("UIConfig", {"progressBarFullColor", "string|nil", "Color of the filled part of the progress bar."});
        rec.record_property("UIConfig", {"progressBarMaxValue", "number|nil", "The maximum value of the progress bar."});
        rec.record_property("UIConfig", {"progressBarValueComponentName", "string|nil", "Component name to fetch progress value from."});
        rec.record_property("UIConfig", {"progressBarValueFieldName", "string|nil", "Field name to fetch progress value from."});
        rec.record_property("UIConfig", {"ui_object_updated", "boolean|nil", "Flag indicating the UI object was updated."});
        // Button delays & clicks
        rec.record_property("UIConfig", {"buttonDelayStart", "boolean|nil", "Flag for button delay start."});
        rec.record_property("UIConfig", {"buttonDelay", "number|nil", "Delay for button actions."});
        rec.record_property("UIConfig", {"buttonDelayProgress", "number|nil", "Progress of the button delay."});
        rec.record_property("UIConfig", {"buttonDelayEnd", "boolean|nil", "Flag for button delay end."});
        rec.record_property("UIConfig", {"buttonClicked", "boolean|nil", "True if the button was clicked this frame."});
        rec.record_property("UIConfig", {"buttonDistance", "number|nil", "Distance for button press effect."});
        // Tooltips & hover
        rec.record_property("UIConfig", {"tooltip", "string|nil", "Simple tooltip text."});
        rec.record_property("UIConfig", {"detailedTooltip", "Tooltip|nil", "A detailed tooltip object."});
        rec.record_property("UIConfig", {"onDemandTooltip", "function|nil", "A function that returns a tooltip."});
        rec.record_property("UIConfig", {"hover", "boolean|nil", "Flag indicating if the element is being hovered."});
        // Special behaviors
        rec.record_property("UIConfig", {"force_focus", "boolean|nil", "Forces this element to take focus."});
        rec.record_property("UIConfig", {"dynamicMotion", "boolean|nil", "Enables dynamic motion effects."});
        rec.record_property("UIConfig", {"choice", "boolean|nil", "Marks this as a choice in a selection."});
        rec.record_property("UIConfig", {"chosen", "boolean|nil", "True if this choice is currently selected."});
        rec.record_property("UIConfig", {"one_press", "boolean|nil", "Button can only be pressed once."});
        rec.record_property("UIConfig", {"chosen_vert", "boolean|nil", "Indicates a vertical choice selection."});
        rec.record_property("UIConfig", {"draw_after", "boolean|nil", "Draw this element after its children."});
        rec.record_property("UIConfig", {"focusArgs", "FocusArgs|nil", "Arguments for focus behavior."});
        // Scripting callbacks
        rec.record_property("UIConfig", {"updateFunc", "function|nil", "Custom update function."});
        rec.record_property("UIConfig", {"initFunc", "function|nil", "Custom initialization function."});
        rec.record_property("UIConfig", {"onUIResizeFunc", "function|nil", "Callback for when the UI is resized."});
        rec.record_property("UIConfig", {"onUIScalingResetToOne", "function|nil", "Callback for when UI scaling resets."});
        rec.record_property("UIConfig", {"instaFunc", "function|nil", "A function to be executed instantly."});
        rec.record_property("UIConfig", {"buttonCallback", "function|nil", "Callback for button presses."});
        rec.record_property("UIConfig", {"buttonTemp", "boolean|nil", "Temporary button flag."});
        rec.record_property("UIConfig", {"textGetter", "function|nil", "Function to dynamically get text content."});
        // References & text
        rec.record_property("UIConfig", {"ref_entity", "Entity|nil", "A referenced entity."});
        rec.record_property("UIConfig", {"ref_component", "string|nil", "Name of a referenced component."});
        rec.record_property("UIConfig", {"ref_value", "any|nil", "A referenced value."});
        rec.record_property("UIConfig", {"prev_ref_value", "any|nil", "The previous referenced value."});
        rec.record_property("UIConfig", {"text", "string|nil", "Static text content."});
        rec.record_property("UIConfig", {"fontSize", "number|nil", "Override font size for this element."});
        rec.record_property("UIConfig", {"fontName", "string|nil", "Named font to use instead of the language default."});
        rec.record_property("UIConfig", {"language", "string|nil", "Language key for localization."});
        rec.record_property("UIConfig", {"verticalText", "boolean|nil", "If true, text is rendered vertically."});
        // Popups
        rec.record_property("UIConfig", {"hPopup", "boolean|nil", "Is a horizontal popup."});
        rec.record_property("UIConfig", {"dPopup", "boolean|nil", "Is a detailed popup."});
        rec.record_property("UIConfig", {"hPopupConfig", "UIConfig|nil", "Configuration for the horizontal popup."});
        rec.record_property("UIConfig", {"dPopupConfig", "UIConfig|nil", "Configuration for the detailed popup."});
        // Misc
        rec.record_property("UIConfig", {"extend_up", "boolean|nil", "If the element extends upwards."});
        rec.record_property("UIConfig", {"resolution", "Vector2|nil", "Resolution context for this element."});
        rec.record_property("UIConfig", {"emboss", "boolean|nil", "Apply an emboss effect."});
        rec.record_property("UIConfig", {"line_emboss", "boolean|nil", "Apply a line emboss effect."});
        rec.record_property("UIConfig", {"mid", "boolean|nil", "A miscellaneous flag."});
        rec.record_property("UIConfig", {"noRole", "boolean|nil", "This element has no inherited properties role."});
        rec.record_property("UIConfig", {"role", "InheritedProperties|nil", "The inherited properties role."});

        //=========================================================
        // Split UI Components (Phase 1 Migration)
        //=========================================================

        // 14) UIElementCore - Identity and hierarchy
        lua.new_usertype<UIElementCore>("UIElementCore",
            sol::constructors<UIElementCore()>(),
            "type", &UIElementCore::type,
            "uiBox", &UIElementCore::uiBox,
            "id", &UIElementCore::id,
            "treeOrder", &UIElementCore::treeOrder,
            "type_id", []() { return entt::type_hash<UIElementCore>::value(); }
        );
        auto& uiCoreDef = rec.add_type("UIElementCore", /*is_data_class=*/true);
        uiCoreDef.doc = "Core identity component for UI elements, containing type, box reference, and tree position.";
        rec.record_property("UIElementCore", {"type", "UITypeEnum", "The fundamental type of this UI element."});
        rec.record_property("UIElementCore", {"uiBox", "Entity", "The root UI box entity this element belongs to."});
        rec.record_property("UIElementCore", {"id", "string", "Unique identifier for this UI element."});
        rec.record_property("UIElementCore", {"treeOrder", "integer", "Order of this element in the UI tree for traversal."});

        // 15) UIStyleConfig - Visual appearance
        lua.new_usertype<UIStyleConfig>("UIStyleConfig",
            sol::constructors<UIStyleConfig()>(),
            "stylingType", &UIStyleConfig::stylingType,
            "color", &UIStyleConfig::color,
            "outlineColor", &UIStyleConfig::outlineColor,
            "shadowColor", &UIStyleConfig::shadowColor,
            "progressBarEmptyColor", &UIStyleConfig::progressBarEmptyColor,
            "progressBarFullColor", &UIStyleConfig::progressBarFullColor,
            "outlineThickness", &UIStyleConfig::outlineThickness,
            "emboss", &UIStyleConfig::emboss,
            "resolution", &UIStyleConfig::resolution,
            "shadow", &UIStyleConfig::shadow,
            "outlineShadow", &UIStyleConfig::outlineShadow,
            "noFill", &UIStyleConfig::noFill,
            "pixelatedRectangle", &UIStyleConfig::pixelatedRectangle,
            "line_emboss", &UIStyleConfig::line_emboss,
            "nPatchInfo", &UIStyleConfig::nPatchInfo,
            "nPatchSourceTexture", &UIStyleConfig::nPatchSourceTexture,
            "nPatchTiling", &UIStyleConfig::nPatchTiling,
            "spriteSourceTexture", &UIStyleConfig::spriteSourceTexture,
            "spriteSourceRect", &UIStyleConfig::spriteSourceRect,
            "spriteScaleMode", &UIStyleConfig::spriteScaleMode,
            "type_id", []() { return entt::type_hash<UIStyleConfig>::value(); }
        );
        auto& uiStyleDef = rec.add_type("UIStyleConfig", /*is_data_class=*/true);
        uiStyleDef.doc = "Visual styling configuration for UI elements.";
        rec.record_property("UIStyleConfig", {"stylingType", "UIStylingType", "The visual style type (rounded rectangle, 9-patch, sprite)."});
        rec.record_property("UIStyleConfig", {"color", "Color|nil", "Background color."});
        rec.record_property("UIStyleConfig", {"outlineColor", "Color|nil", "Outline color."});
        rec.record_property("UIStyleConfig", {"shadowColor", "Color|nil", "Shadow color."});
        rec.record_property("UIStyleConfig", {"outlineThickness", "number|nil", "Outline thickness in pixels."});
        rec.record_property("UIStyleConfig", {"shadow", "boolean", "Whether shadow is enabled."});
        rec.record_property("UIStyleConfig", {"noFill", "boolean", "If true, background is not filled."});
        rec.record_property("UIStyleConfig", {"pixelatedRectangle", "boolean", "Use pixel-perfect rectangle drawing."});

        // 16) UILayoutConfig - Positioning and dimensions
        lua.new_usertype<UILayoutConfig>("UILayoutConfig",
            sol::constructors<UILayoutConfig()>(),
            "width", &UILayoutConfig::width,
            "height", &UILayoutConfig::height,
            "maxWidth", &UILayoutConfig::maxWidth,
            "maxHeight", &UILayoutConfig::maxHeight,
            "minWidth", &UILayoutConfig::minWidth,
            "minHeight", &UILayoutConfig::minHeight,
            "padding", &UILayoutConfig::padding,
            "extend_up", &UILayoutConfig::extend_up,
            "alignmentFlags", &UILayoutConfig::alignmentFlags,
            "location_bond", &UILayoutConfig::location_bond,
            "rotation_bond", &UILayoutConfig::rotation_bond,
            "size_bond", &UILayoutConfig::size_bond,
            "scale_bond", &UILayoutConfig::scale_bond,
            "offset", &UILayoutConfig::offset,
            "scale", &UILayoutConfig::scale,
            "no_recalc", &UILayoutConfig::no_recalc,
            "non_recalc", &UILayoutConfig::non_recalc,
            "mid", &UILayoutConfig::mid,
            "noRole", &UILayoutConfig::noRole,
            "role", &UILayoutConfig::role,
            "master", &UILayoutConfig::master,
            "parent", &UILayoutConfig::parent,
            "drawLayer", &UILayoutConfig::drawLayer,
            "draw_after", &UILayoutConfig::draw_after,
            "type_id", []() { return entt::type_hash<UILayoutConfig>::value(); }
        );
        auto& uiLayoutDef = rec.add_type("UILayoutConfig", /*is_data_class=*/true);
        uiLayoutDef.doc = "Layout configuration for UI elements including positioning, dimensions, and hierarchy.";
        rec.record_property("UILayoutConfig", {"width", "integer|nil", "Explicit width."});
        rec.record_property("UILayoutConfig", {"height", "integer|nil", "Explicit height."});
        rec.record_property("UILayoutConfig", {"maxWidth", "integer|nil", "Maximum width."});
        rec.record_property("UILayoutConfig", {"maxHeight", "integer|nil", "Maximum height."});
        rec.record_property("UILayoutConfig", {"minWidth", "integer|nil", "Minimum width."});
        rec.record_property("UILayoutConfig", {"minHeight", "integer|nil", "Minimum height."});
        rec.record_property("UILayoutConfig", {"padding", "number|nil", "Padding around the content."});
        rec.record_property("UILayoutConfig", {"alignmentFlags", "integer|nil", "Bitmask of alignment flags."});
        rec.record_property("UILayoutConfig", {"offset", "Vector2|nil", "Offset from aligned position."});
        rec.record_property("UILayoutConfig", {"scale", "number|nil", "Scale multiplier."});
        rec.record_property("UILayoutConfig", {"mid", "boolean", "A miscellaneous layout flag."});
        rec.record_property("UILayoutConfig", {"draw_after", "boolean", "Draw this element after its children."});

        // 17) UIInteractionConfig - Input handling and callbacks
        lua.new_usertype<UIInteractionConfig>("UIInteractionConfig",
            sol::constructors<UIInteractionConfig()>(),
            "canCollide", &UIInteractionConfig::canCollide,
            "collideable", &UIInteractionConfig::collideable,
            "forceCollision", &UIInteractionConfig::forceCollision,
            "hover", &UIInteractionConfig::hover,
            "button_UIE", &UIInteractionConfig::button_UIE,
            "disable_button", &UIInteractionConfig::disable_button,
            "buttonDelay", &UIInteractionConfig::buttonDelay,
            "buttonDelayStart", &UIInteractionConfig::buttonDelayStart,
            "buttonDelayEnd", &UIInteractionConfig::buttonDelayEnd,
            "buttonDelayProgress", &UIInteractionConfig::buttonDelayProgress,
            "buttonDistance", &UIInteractionConfig::buttonDistance,
            "buttonClicked", &UIInteractionConfig::buttonClicked,
            "force_focus", &UIInteractionConfig::force_focus,
            "focusWithObject", &UIInteractionConfig::focusWithObject,
            "focusArgs", &UIInteractionConfig::focusArgs,
            "tooltip", &UIInteractionConfig::tooltip,
            "detailedTooltip", &UIInteractionConfig::detailedTooltip,
            "onDemandTooltip", &UIInteractionConfig::onDemandTooltip,
            "buttonCallback", &UIInteractionConfig::buttonCallback,
            "buttonTemp", &UIInteractionConfig::buttonTemp,
            "updateFunc", &UIInteractionConfig::updateFunc,
            "initFunc", &UIInteractionConfig::initFunc,
            "onUIResizeFunc", &UIInteractionConfig::onUIResizeFunc,
            "onUIScalingResetToOne", &UIInteractionConfig::onUIScalingResetToOne,
            "instaFunc", &UIInteractionConfig::instaFunc,
            "choice", &UIInteractionConfig::choice,
            "chosen", &UIInteractionConfig::chosen,
            "one_press", &UIInteractionConfig::one_press,
            "chosen_vert", &UIInteractionConfig::chosen_vert,
            "group", &UIInteractionConfig::group,
            "groupParent", &UIInteractionConfig::groupParent,
            "dynamicMotion", &UIInteractionConfig::dynamicMotion,
            "makeMovementDynamic", &UIInteractionConfig::makeMovementDynamic,
            "noMovementWhenDragged", &UIInteractionConfig::noMovementWhenDragged,
            "refreshMovement", &UIInteractionConfig::refreshMovement,
            "type_id", []() { return entt::type_hash<UIInteractionConfig>::value(); }
        );
        auto& uiInteractionDef = rec.add_type("UIInteractionConfig", /*is_data_class=*/true);
        uiInteractionDef.doc = "Interaction configuration for UI elements including collision, buttons, focus, and callbacks.";
        rec.record_property("UIInteractionConfig", {"canCollide", "boolean|nil", "Whether collision is possible."});
        rec.record_property("UIInteractionConfig", {"hover", "boolean", "Whether element is currently hovered."});
        rec.record_property("UIInteractionConfig", {"disable_button", "boolean", "Disables button functionality."});
        rec.record_property("UIInteractionConfig", {"buttonClicked", "boolean", "True if button was clicked this frame."});
        rec.record_property("UIInteractionConfig", {"force_focus", "boolean", "Forces this element to take focus."});
        rec.record_property("UIInteractionConfig", {"focusArgs", "FocusArgs|nil", "Arguments for focus behavior."});
        rec.record_property("UIInteractionConfig", {"tooltip", "Tooltip|nil", "Simple tooltip."});
        rec.record_property("UIInteractionConfig", {"buttonCallback", "function|nil", "Callback for button presses."});
        rec.record_property("UIInteractionConfig", {"updateFunc", "function|nil", "Custom update function."});
        rec.record_property("UIInteractionConfig", {"choice", "boolean|nil", "Marks this as a choice element."});
        rec.record_property("UIInteractionConfig", {"dynamicMotion", "boolean|nil", "Enables dynamic motion effects."});

        // 18) UIContentConfig - Text, objects, references
        lua.new_usertype<UIContentConfig>("UIContentConfig",
            sol::constructors<UIContentConfig()>(),
            "text", &UIContentConfig::text,
            "language", &UIContentConfig::language,
            "verticalText", &UIContentConfig::verticalText,
            "textSpacing", &UIContentConfig::textSpacing,
            "fontSize", &UIContentConfig::fontSize,
            "fontName", &UIContentConfig::fontName,
            "textGetter", &UIContentConfig::textGetter,
            "object", &UIContentConfig::object,
            "objectRecalculate", &UIContentConfig::objectRecalculate,
            "ui_object_updated", &UIContentConfig::ui_object_updated,
            "includeChildrenInShaderPass", &UIContentConfig::includeChildrenInShaderPass,
            "progressBar", &UIContentConfig::progressBar,
            "progressBarMaxValue", &UIContentConfig::progressBarMaxValue,
            "progressBarValueComponentName", &UIContentConfig::progressBarValueComponentName,
            "progressBarValueFieldName", &UIContentConfig::progressBarValueFieldName,
            "progressBarFetchValueLambda", &UIContentConfig::progressBarFetchValueLambda,
            "ref_entity", &UIContentConfig::ref_entity,
            "ref_component", &UIContentConfig::ref_component,
            "ref_value", &UIContentConfig::ref_value,
            "prev_ref_value", &UIContentConfig::prev_ref_value,
            "hPopup", &UIContentConfig::hPopup,
            "dPopup", &UIContentConfig::dPopup,
            "hPopupConfig", &UIContentConfig::hPopupConfig,
            "dPopupConfig", &UIContentConfig::dPopupConfig,
            "instanceType", &UIContentConfig::instanceType,
            "type_id", []() { return entt::type_hash<UIContentConfig>::value(); }
        );
        auto& uiContentDef = rec.add_type("UIContentConfig", /*is_data_class=*/true);
        uiContentDef.doc = "Content configuration for UI elements including text, attached objects, and references.";
        rec.record_property("UIContentConfig", {"text", "string|nil", "Static text content."});
        rec.record_property("UIContentConfig", {"language", "string|nil", "Language key for localization."});
        rec.record_property("UIContentConfig", {"verticalText", "boolean|nil", "If true, text is rendered vertically."});
        rec.record_property("UIContentConfig", {"fontSize", "number|nil", "Font size for text elements."});
        rec.record_property("UIContentConfig", {"fontName", "string|nil", "Named font to use."});
        rec.record_property("UIContentConfig", {"textGetter", "function|nil", "Function to dynamically get text content."});
        rec.record_property("UIContentConfig", {"object", "Entity|nil", "The game object associated with this UI element."});
        rec.record_property("UIContentConfig", {"objectRecalculate", "boolean", "Force recalculation based on object."});
        rec.record_property("UIContentConfig", {"progressBar", "boolean", "If this element is a progress bar."});
        rec.record_property("UIContentConfig", {"progressBarMaxValue", "number|nil", "Maximum value of the progress bar."});
        rec.record_property("UIContentConfig", {"ref_entity", "Entity|nil", "A referenced entity."});
        rec.record_property("UIContentConfig", {"instanceType", "string|nil", "A specific instance type for categorization."});

        // 19) UIConfigBundle - For passing all configs through builder
        lua.new_usertype<UIConfigBundle>("UIConfigBundle",
            sol::constructors<UIConfigBundle()>(),
            "style", &UIConfigBundle::style,
            "layout", &UIConfigBundle::layout,
            "interaction", &UIConfigBundle::interaction,
            "content", &UIConfigBundle::content,
            "type_id", []() { return entt::type_hash<UIConfigBundle>::value(); }
        );
        auto& uiBundleDef = rec.add_type("UIConfigBundle", /*is_data_class=*/true);
        uiBundleDef.doc = "Bundle of all split UI config components for convenient passing through builders.";
        rec.record_property("UIConfigBundle", {"style", "UIStyleConfig", "Visual styling configuration."});
        rec.record_property("UIConfigBundle", {"layout", "UILayoutConfig", "Layout and positioning configuration."});
        rec.record_property("UIConfigBundle", {"interaction", "UIInteractionConfig", "Interaction and callback configuration."});
        rec.record_property("UIConfigBundle", {"content", "UIContentConfig", "Content and text configuration."});


        //=========================================================
        // Part 1: UIConfig::Builder
        //=========================================================
        lua.new_usertype<UIConfig::Builder>("UIConfigBuilder",
            sol::constructors<>(),
            "create",                         &UIConfig::Builder::create,
            "addId",                          &UIConfig::Builder::addId,
            "addTextGetter",                  &UIConfig::Builder::addTextGetter,
            "addInstanceType",                &UIConfig::Builder::addInstanceType,
            "addUiType",                      &UIConfig::Builder::addUiType,
            "addDrawLayer",                   &UIConfig::Builder::addDrawLayer,
            "addGroup",                       &UIConfig::Builder::addGroup,
            "addLocationBond",                &UIConfig::Builder::addLocationBond,
            "addRotationBond",                &UIConfig::Builder::addRotationBond,
            "addSizeBond",                    &UIConfig::Builder::addSizeBond,
            "addScaleBond",                   &UIConfig::Builder::addScaleBond,
            "addOffset",                      &UIConfig::Builder::addOffset,
            "addScale",                       &UIConfig::Builder::addScale,
            "addTextSpacing",                 &UIConfig::Builder::addTextSpacing,
            "addFontSize",                    &UIConfig::Builder::addFontSize,
            "addFontName",                    &UIConfig::Builder::addFontName,
            "addFocusWithObject",             &UIConfig::Builder::addFocusWithObject,
            "addRefreshMovement",             &UIConfig::Builder::addRefreshMovement,
            "addNoMovementWhenDragged",       &UIConfig::Builder::addNoMovementWhenDragged,
            "addNoRecalc",                    &UIConfig::Builder::addNoRecalc,
            "addNonRecalc",                   &UIConfig::Builder::addNonRecalc,
            "addMakeMovementDynamic",         &UIConfig::Builder::addMakeMovementDynamic,
            "addMaster",                      &UIConfig::Builder::addMaster,
            "addParent",                      &UIConfig::Builder::addParent,
            "addObject",                      &UIConfig::Builder::addObject,
            "addAlign",                       &UIConfig::Builder::addAlign,
            "addWidth",                       &UIConfig::Builder::addWidth,
            "addHeight",                      &UIConfig::Builder::addHeight,
            "addMaxWidth",                    &UIConfig::Builder::addMaxWidth,
            "addMaxHeight",                   &UIConfig::Builder::addMaxHeight,
            "addMinWidth",                    &UIConfig::Builder::addMinWidth,
            "addMinHeight", [](UIConfig::Builder &b, float h){
                // cast float → int, then forward to the real method
                return b.addMinHeight(static_cast<int>(h));
            },
            "addPadding",                     &UIConfig::Builder::addPadding,
            "addColor",                       &UIConfig::Builder::addColor,
            "addOutlineColor",                &UIConfig::Builder::addOutlineColor,
            "addOutlineThickness",            &UIConfig::Builder::addOutlineThickness,
            "addShadow",                      &UIConfig::Builder::addShadow,
            "addShadowColor",                 &UIConfig::Builder::addShadowColor,
            "addNoFill",                      &UIConfig::Builder::addNoFill,
            "addPixelatedRectangle",          &UIConfig::Builder::addPixelatedRectangle,
            "addCanCollide",                  &UIConfig::Builder::addCanCollide,
            "addCollideable",                 &UIConfig::Builder::addCollideable,
            "addForceCollision",              &UIConfig::Builder::addForceCollision,
            "addButtonUIE",                   &UIConfig::Builder::addButtonUIE,
            "addDisableButton",               &UIConfig::Builder::addDisableButton,
            "addProgressBarFetchValueLamnda", &UIConfig::Builder::addProgressBarFetchValueLamnda,
            "addProgressBar",                 &UIConfig::Builder::addProgressBar,
            "addProgressBarEmptyColor",       &UIConfig::Builder::addProgressBarEmptyColor,
            "addProgressBarFullColor",        &UIConfig::Builder::addProgressBarFullColor,
            "addProgressBarMaxValue",         &UIConfig::Builder::addProgressBarMaxValue,
            "addProgressBarValueComponentName",&UIConfig::Builder::addProgressBarValueComponentName,
            "addProgressBarValueFieldName",   &UIConfig::Builder::addProgressBarValueFieldName,
            "addUIObjectUpdated",             &UIConfig::Builder::addUIObjectUpdated,
            "addButtonDelayStart",            &UIConfig::Builder::addButtonDelayStart,
            "addButtonDelay",                 &UIConfig::Builder::addButtonDelay,
            "addButtonDelayProgress",         &UIConfig::Builder::addButtonDelayProgress,
            "addButtonDelayEnd",              &UIConfig::Builder::addButtonDelayEnd,
            "addButtonClicked",               &UIConfig::Builder::addButtonClicked,
            "addButtonDistance",              &UIConfig::Builder::addButtonDistance,
            "addTooltip",                     &UIConfig::Builder::addTooltip,
            "addDetailedTooltip",             &UIConfig::Builder::addDetailedTooltip,
            "addOnDemandTooltip",             &UIConfig::Builder::addOnDemandTooltip,
            "addHover",                       &UIConfig::Builder::addHover,
            "addForceFocus",                  &UIConfig::Builder::addForceFocus,
            "addDynamicMotion",               &UIConfig::Builder::addDynamicMotion,
            "addChoice",                      &UIConfig::Builder::addChoice,
            "addChosen",                      &UIConfig::Builder::addChosen,
            "addOnePress",                    &UIConfig::Builder::addOnePress,
            "addChosenVert",                  &UIConfig::Builder::addChosenVert,
            "addDrawAfter",                   &UIConfig::Builder::addDrawAfter,
            "addFocusArgs",                   &UIConfig::Builder::addFocusArgs,
            "addUpdateFunc",                  &UIConfig::Builder::addUpdateFunc,
            "addInitFunc",                    &UIConfig::Builder::addInitFunc,
            "addOnUIResizeFunc",              &UIConfig::Builder::addOnUIResizeFunc,
            "addOnUIScalingResetToOne",       &UIConfig::Builder::addOnUIScalingResetToOne,
            "addInstaFunc",                   &UIConfig::Builder::addInstaFunc,
            "addButtonCallback",              &UIConfig::Builder::addButtonCallback,
            "addButtonTemp",                  &UIConfig::Builder::addButtonTemp,
            "addRefEntity",                   &UIConfig::Builder::addRefEntity,
            "addRefComponent",                &UIConfig::Builder::addRefComponent,
            "addRefValue",                    &UIConfig::Builder::addRefValue,
            "addPrevRefValue",                &UIConfig::Builder::addPrevRefValue,
            "addText",                        &UIConfig::Builder::addText,
            "addLanguage",                    &UIConfig::Builder::addLanguage,
            "addVerticalText",                &UIConfig::Builder::addVerticalText,
            "addHPopup",                      &UIConfig::Builder::addHPopup,
            "addHPopupConfig",                &UIConfig::Builder::addHPopupConfig,
            "addDPopup",                      &UIConfig::Builder::addDPopup,
            "addDPopupConfig",                &UIConfig::Builder::addDPopupConfig,
            "addExtendUp",                    &UIConfig::Builder::addExtendUp,
            "addResolution",                  &UIConfig::Builder::addResolution,
            "addEmboss",                      &UIConfig::Builder::addEmboss,
            "addLineEmboss",                  &UIConfig::Builder::addLineEmboss,
            "addMid",                         &UIConfig::Builder::addMid,
            "addNoRole",                      &UIConfig::Builder::addNoRole,
            "addRole",                        &UIConfig::Builder::addRole,
            "addStylingType",                 &UIConfig::Builder::addStylingType,
            "addNPatchInfo",                  &UIConfig::Builder::addNPatchInfo,
            "addNPatchSourceTexture",         &UIConfig::Builder::addNPatchSourceTexture,
            "addDecorations",                 &UIConfig::Builder::addDecorations,
            "build",                          &UIConfig::Builder::build,
            "buildBundle",                    &UIConfig::Builder::buildBundle
        );

        auto& cfgBuilder = rec.add_type("UIConfigBuilder");
        cfgBuilder.doc = "A fluent builder for creating UIConfig components.";
        rec.record_method("UIConfigBuilder", {"create", "---@param id string\n---@return self", "Creates a new builder instance with an ID.", true, false});
        rec.record_method("UIConfigBuilder", {"addId", "---@param id string\n---@return self", "Sets the ID.", false, false});
        rec.record_method("UIConfigBuilder", {"addTextGetter", "---@param func function\n---@return self", "Sets a function to dynamically retrieve text.", false, false});
        rec.record_method("UIConfigBuilder", {"addInstanceType", "---@param type string\n---@return self", "Sets the instance type.", false, false});
        rec.record_method("UIConfigBuilder", {"addUiType", "---@param type UITypeEnum\n---@return self", "Sets the UI type.", false, false});
        rec.record_method("UIConfigBuilder", {"addDrawLayer", "---@param layer string\n---@return self", "Sets the drawing layer.", false, false});
        rec.record_method("UIConfigBuilder", {"addGroup", "---@param group string\n---@return self", "Sets the focus group.", false, false});
        rec.record_method("UIConfigBuilder", {"addLocationBond", "---@param bond InheritedPropertiesSync\n---@return self", "Sets the location bond.", false, false});
        rec.record_method("UIConfigBuilder", {"addRotationBond", "---@param bond InheritedPropertiesSync\n---@return self", "Sets the rotation bond.", false, false});
        rec.record_method("UIConfigBuilder", {"addSizeBond", "---@param bond InheritedPropertiesSync\n---@return self", "Sets the size bond.", false, false});
        rec.record_method("UIConfigBuilder", {"addScaleBond", "---@param bond InheritedPropertiesSync\n---@return self", "Sets the scale bond.", false, false});
        rec.record_method("UIConfigBuilder", {"addOffset", "---@param offset Vector2\n---@return self", "Sets the transform offset.", false, false});
        rec.record_method("UIConfigBuilder", {"addScale", "---@param scale number\n---@return self", "Sets the scale.", false, false});
        rec.record_method("UIConfigBuilder", {"addTextSpacing", "---@param spacing number\n---@return self", "Sets text character spacing.", false, false});
        rec.record_method("UIConfigBuilder", {"addFontSize", "---@param fontSize number\n---@return self", "Sets the font size for text elements.", false, false});
        rec.record_method("UIConfigBuilder", {"addFontName", "---@param fontName string\n---@return self", "Sets a named font to use for text elements.", false, false});
        rec.record_method("UIConfigBuilder", {"addFocusWithObject", "---@param focus boolean\n---@return self", "Sets if focus is tied to the game object.", false, false});
        rec.record_method("UIConfigBuilder", {"addRefreshMovement", "---@param refresh boolean\n---@return self", "Sets if movement should be refreshed.", false, false});
        rec.record_method("UIConfigBuilder", {"addNoMovementWhenDragged", "---@param noMove boolean\n---@return self", "Prevents movement while dragged.", false, false});
        rec.record_method("UIConfigBuilder", {"addNoRecalc", "---@param noRecalc boolean\n---@return self", "Prevents transform recalculation.", false, false});
        rec.record_method("UIConfigBuilder", {"addNonRecalc", "---@param nonRecalc boolean\n---@return self", "Alias for addNoRecalc.", false, false});
        rec.record_method("UIConfigBuilder", {"addMakeMovementDynamic", "---@param dynamic boolean\n---@return self", "Enables dynamic (springy) movement.", false, false});
        rec.record_method("UIConfigBuilder", {"addMaster", "---@param id string\n---@return self", "Sets the master UI element by ID.", false, false});
        rec.record_method("UIConfigBuilder", {"addParent", "---@param id string\n---@return self", "Sets the parent UI element by ID.", false, false});
        rec.record_method("UIConfigBuilder", {"addObject", "---@param entity Entity\n---@return self", "Attaches a game object.", false, false});
        rec.record_method("UIConfigBuilder", {"addAlign", "---@param flags integer\n---@return self", "Sets the alignment flags.", false, false});
        rec.record_method("UIConfigBuilder", {"addWidth", "---@param width number\n---@return self", "Sets the width.", false, false});
        rec.record_method("UIConfigBuilder", {"addHeight", "---@param height number\n---@return self", "Sets the height.", false, false});
        rec.record_method("UIConfigBuilder", {"addMaxWidth", "---@param maxWidth number\n---@return self", "Sets the max width.", false, false});
        rec.record_method("UIConfigBuilder", {"addMaxHeight", "---@param maxHeight number\n---@return self", "Sets the max height.", false, false});
        rec.record_method("UIConfigBuilder", {"addMinWidth", "---@param minWidth number\n---@return self", "Sets the min width.", false, false});
        rec.record_method("UIConfigBuilder", {"addMinHeight", "---@param minHeight number\n---@return self", "Sets the min height.", false, false});
        rec.record_method("UIConfigBuilder", {"addPadding", "---@param padding number\n---@return self", "Sets the padding.", false, false});
        rec.record_method("UIConfigBuilder", {"addColor", "---@param color string\n---@return self", "Sets the background color.", false, false});
        rec.record_method("UIConfigBuilder", {"addOutlineColor", "---@param color string\n---@return self", "Sets the outline color.", false, false});
        rec.record_method("UIConfigBuilder", {"addOutlineThickness", "---@param thickness number\n---@return self", "Sets the outline thickness.", false, false});
        rec.record_method("UIConfigBuilder", {"addShadow", "---@param offset Vector2\n---@return self", "Adds a shadow with an offset.", false, false});
        rec.record_method("UIConfigBuilder", {"addShadowColor", "---@param color string\n---@return self", "Sets the shadow color.", false, false});
        rec.record_method("UIConfigBuilder", {"addNoFill", "---@param noFill boolean\n---@return self", "Sets if the background should be transparent.", false, false});
        rec.record_method("UIConfigBuilder", {"addPixelatedRectangle", "---@param pixelated boolean\n---@return self", "Sets if the rectangle should be drawn pixel-perfect.", false, false});
        rec.record_method("UIConfigBuilder", {"addCanCollide", "---@param canCollide boolean\n---@return self", "Sets if collision is enabled.", false, false});
        rec.record_method("UIConfigBuilder", {"addCollideable", "---@param collideable boolean\n---@return self", "Alias for addCanCollide.", false, false});
        rec.record_method("UIConfigBuilder", {"addForceCollision", "---@param force boolean\n---@return self", "Forces collision checks.", false, false});
        rec.record_method("UIConfigBuilder", {"addButtonUIE", "---@param isButton boolean\n---@return self", "Marks this element as a button.", false, false});
        rec.record_method("UIConfigBuilder", {"addDisableButton", "---@param disabled boolean\n---@return self", "Disables the button functionality.", false, false});
        rec.record_method("UIConfigBuilder", {"addProgressBarFetchValueLamnda", "---@param func function\n---@return self", "Sets a function to get progress bar value.", false, false});
        rec.record_method("UIConfigBuilder", {"addProgressBar", "---@param isProgressBar boolean\n---@return self", "Marks this as a progress bar.", false, false});
        rec.record_method("UIConfigBuilder", {"addProgressBarEmptyColor", "---@param color string\n---@return self", "Sets the progress bar's empty color.", false, false});
        rec.record_method("UIConfigBuilder", {"addProgressBarFullColor", "---@param color string\n---@return self", "Sets the progress bar's full color.", false, false});
        rec.record_method("UIConfigBuilder", {"addProgressBarMaxValue", "---@param maxVal number\n---@return self", "Sets the progress bar's max value.", false, false});
        rec.record_method("UIConfigBuilder", {"addProgressBarValueComponentName", "---@param name string\n---@return self", "Sets the component name for progress value.", false, false});
        rec.record_method("UIConfigBuilder", {"addProgressBarValueFieldName", "---@param name string\n---@return self", "Sets the field name for progress value.", false, false});
        rec.record_method("UIConfigBuilder", {"addUIObjectUpdated", "---@param updated boolean\n---@return self", "Sets the UI object updated flag.", false, false});
        rec.record_method("UIConfigBuilder", {"addButtonDelayStart", "---@param delay boolean\n---@return self", "Sets button delay start flag.", false, false});
        rec.record_method("UIConfigBuilder", {"addButtonDelay", "---@param delay number\n---@return self", "Sets button press delay.", false, false});
        rec.record_method("UIConfigBuilder", {"addButtonDelayProgress", "---@param progress number\n---@return self", "Sets button delay progress.", false, false});
        rec.record_method("UIConfigBuilder", {"addButtonDelayEnd", "---@param ended boolean\n---@return self", "Sets button delay end flag.", false, false});
        rec.record_method("UIConfigBuilder", {"addButtonClicked", "---@param clicked boolean\n---@return self", "Sets the button clicked flag.", false, false});
        rec.record_method("UIConfigBuilder", {"addButtonDistance", "---@param distance number\n---@return self", "Sets button press visual distance.", false, false});
        rec.record_method("UIConfigBuilder", {"addTooltip", "---@param text string\n---@return self", "Sets the tooltip text.", false, false});
        rec.record_method("UIConfigBuilder", {"addDetailedTooltip", "---@param tooltip Tooltip\n---@return self", "Sets a detailed tooltip.", false, false});
        rec.record_method("UIConfigBuilder", {"addOnDemandTooltip", "---@param func function\n---@return self", "Sets a function to generate a tooltip.", false, false});
        rec.record_method("UIConfigBuilder", {"addHover", "---@param hover boolean\n---@return self", "Sets the hover state.", false, false});
        rec.record_method("UIConfigBuilder", {"addForceFocus", "---@param force boolean\n---@return self", "Forces this element to take focus.", false, false});
        rec.record_method("UIConfigBuilder", {"addDynamicMotion", "---@param dynamic boolean\n---@return self", "Enables dynamic motion.", false, false});
        rec.record_method("UIConfigBuilder", {"addChoice", "---@param isChoice boolean\n---@return self", "Marks this as a choice element.", false, false});
        rec.record_method("UIConfigBuilder", {"addChosen", "---@param isChosen boolean\n---@return self", "Sets the chosen state.", false, false});
        rec.record_method("UIConfigBuilder", {"addOnePress", "---@param onePress boolean\n---@return self", "Makes the button a one-time press.", false, false});
        rec.record_method("UIConfigBuilder", {"addChosenVert", "---@param isVert boolean\n---@return self", "Sets if choice navigation is vertical.", false, false});
        rec.record_method("UIConfigBuilder", {"addDrawAfter", "---@param drawAfter boolean\n---@return self", "Draws this element after its children.", false, false});
        rec.record_method("UIConfigBuilder", {"addFocusArgs", "---@param args FocusArgs\n---@return self", "Sets the focus arguments.", false, false});
        rec.record_method("UIConfigBuilder", {"addUpdateFunc", "---@param func function\n---@return self", "Sets a custom update function.", false, false});
        rec.record_method("UIConfigBuilder", {"addInitFunc", "---@param func function\n---@return self", "Sets a custom init function.", false, false});
        rec.record_method("UIConfigBuilder", {"addOnUIResizeFunc", "---@param func function\n---@return self", "Sets a resize callback.", false, false});
        rec.record_method("UIConfigBuilder", {"addOnUIScalingResetToOne", "---@param func function\n---@return self", "Sets a scale reset callback.", false, false});
        rec.record_method("UIConfigBuilder", {"addInstaFunc", "---@param func function\n---@return self", "Sets an instant-execution function.", false, false});
        rec.record_method("UIConfigBuilder", {"addButtonCallback", "---@param func function\n---@return self", "Sets a button press callback.", false, false});
        rec.record_method("UIConfigBuilder", {"addButtonTemp", "---@param temp boolean\n---@return self", "Sets a temporary button flag.", false, false});
        rec.record_method("UIConfigBuilder", {"addRefEntity", "---@param entity Entity\n---@return self", "Sets a referenced entity.", false, false});
        rec.record_method("UIConfigBuilder", {"addRefComponent", "---@param name string\n---@return self", "Sets a referenced component name.", false, false});
        rec.record_method("UIConfigBuilder", {"addRefValue", "---@param val any\n---@return self", "Sets a referenced value.", false, false});
        rec.record_method("UIConfigBuilder", {"addPrevRefValue", "---@param val any\n---@return self", "Sets the previous referenced value.", false, false});
        rec.record_method("UIConfigBuilder", {"addText", "---@param text string\n---@return self", "Sets the static text.", false, false});
        rec.record_method("UIConfigBuilder", {"addLanguage", "---@param lang string\n---@return self", "Sets the language key.", false, false});
        rec.record_method("UIConfigBuilder", {"addVerticalText", "---@param vertical boolean\n---@return self", "Enables vertical text.", false, false});
        rec.record_method("UIConfigBuilder", {"addHPopup", "---@param isPopup boolean\n---@return self", "Marks as a horizontal popup.", false, false});
        rec.record_method("UIConfigBuilder", {"addHPopupConfig", "---@param config UIConfig\n---@return self", "Sets the horizontal popup config.", false, false});
        rec.record_method("UIConfigBuilder", {"addDPopup", "---@param isPopup boolean\n---@return self", "Marks as a detailed popup.", false, false});
        rec.record_method("UIConfigBuilder", {"addDPopupConfig", "---@param config UIConfig\n---@return self", "Sets the detailed popup config.", false, false});
        rec.record_method("UIConfigBuilder", {"addExtendUp", "---@param extendUp boolean\n---@return self", "Sets if the element extends upwards.", false, false});
        rec.record_method("UIConfigBuilder", {"addResolution", "---@param res Vector2\n---@return self", "Sets the resolution context.", false, false});
        rec.record_method("UIConfigBuilder", {"addEmboss", "---@param emboss boolean\n---@return self", "Enables emboss effect.", false, false});
        rec.record_method("UIConfigBuilder", {"addLineEmboss", "---@param emboss boolean\n---@return self", "Enables line emboss effect.", false, false});
        rec.record_method("UIConfigBuilder", {"addMid", "---@param mid boolean\n---@return self", "Sets the 'mid' flag.", false, false});
        rec.record_method("UIConfigBuilder", {"addNoRole", "---@param noRole boolean\n---@return self", "Disables the inherited properties role.", false, false});
        rec.record_method("UIConfigBuilder", {"addRole", "---@param role InheritedProperties\n---@return self", "Sets the inherited properties role.", false, false});
        rec.record_method("UIConfigBuilder", {"addStylingType", "---@param type UIStylingType\n---@return self", "Sets the styling type.", false, false});
        rec.record_method("UIConfigBuilder", {"addNPatchInfo", "---@param info NPatchInfo\n---@return self", "Sets the 9-patch info.", false, false});
        rec.record_method("UIConfigBuilder", {"addNPatchSourceTexture", "---@param texture string\n---@return self", "Sets the 9-patch texture.", false, false});
        rec.record_method("UIConfigBuilder", {"addDecorations", "---@param decorations UIDecorations\n---@return self", "Sets decorative sprite overlays.", false, false});
        rec.record_method("UIConfigBuilder", {"build", "---@param self UIConfigBuilder\n---@return UIConfig", "Constructs the final UIConfig object.", false, false});
        rec.record_method("UIConfigBuilder", {"buildBundle", "---@param self UIConfigBuilder\n---@return UIConfigBundle", "Builds UIConfig and extracts split components (UIStyleConfig, UILayoutConfig, UIInteractionConfig, UIContentConfig) into a bundle.", false, false});

        //=========================================================
        // Part 2: UI Templating
        //=========================================================
        lua.new_usertype<UIElementTemplateNode>("UIElementTemplateNode", sol::constructors<>(),
            "type", &UIElementTemplateNode::type, "config", &UIElementTemplateNode::config, "children", &UIElementTemplateNode::children,
            
            "type_id", []() { return entt::type_hash<UIElementTemplateNode>::value(); }
        );
        auto& tNode = rec.add_type("UIElementTemplateNode", /*is_data_class=*/true);
        tNode.doc = "A node in a UI template, defining an element's type, config, and children.";
        rec.record_property("UIElementTemplateNode", {"type", "UITypeEnum"});
        rec.record_property("UIElementTemplateNode", {"config", "UIConfig"});
        rec.record_property("UIElementTemplateNode", {"children", "table<integer, UIElementTemplateNode>"});

        lua.new_usertype<UIElementTemplateNode::Builder>("UIElementTemplateNodeBuilder", sol::constructors<>(),
            "create", &UIElementTemplateNode::Builder::create, 
            "addType", &UIElementTemplateNode::Builder::addType,
            "addConfig", &UIElementTemplateNode::Builder::addConfig, 
            "addChild", &UIElementTemplateNode::Builder::addChild, 
            "addChildren", [](UIElementTemplateNode::Builder &b, sol::table children) {
                // Convert Lua table to vector of UIElementTemplateNode
                std::vector<UIElementTemplateNode> childNodes;
                for (const auto& child : children) {
                    if (child.second.is<UIElementTemplateNode>()) {
                        childNodes.push_back(child.second.as<UIElementTemplateNode>());
                    }
                }
                
                for (const auto& child : childNodes) {
                    b.addChild(child);
                }
                
                return b;
            },
            "build", &UIElementTemplateNode::Builder::build
        );
        auto& tNodeBuilder = rec.add_type("UIElementTemplateNodeBuilder");
        tNodeBuilder.doc = "A fluent builder for creating UI template trees.";
        rec.record_method("UIElementTemplateNodeBuilder", {"create", "---@return UIElementTemplateNodeBuilder", "Creates a new builder instance.", true, false});
        rec.record_method("UIElementTemplateNodeBuilder", {"addType", "---@param type UITypeEnum\n---@return self", "Sets the node's UI type.", false, false});
        rec.record_method("UIElementTemplateNodeBuilder", {"addConfig", "---@param config UIConfig\n---@return self", "Sets the node's config.", false, false});
        rec.record_method("UIElementTemplateNodeBuilder", {"addChild", "---@param child UIElementTemplateNode\n---@return self", "Adds a child template node.", false, false});
        rec.record_method("UIElementTemplateNodeBuilder", {"addChildren", "---@param children table<integer, UIElementTemplateNode>\n---@return self", "Adds multiple child template nodes from a Lua table.", false, false});
        rec.record_method("UIElementTemplateNodeBuilder", {"build", "---@param self UIElementTemplateNodeBuilder\n---@return UIElementTemplateNode", "Builds the final template node.", false, false});


        //==== UIElement methods ====
        // 1) Create (or get) the 'ui.element' table in Lua
        // Step 1: make `ui = {}` and get it back
        sol::table ui = lua.create_named_table("ui");
        if (!ui.valid()) {
            SPDLOG_DEBUG("UI table is not valid");
        }
        auto element = lua["ui"]["element"].get_or_create<sol::table>();
        if (!element.valid()) {
            SPDLOG_DEBUG("UI.ELEMENT table is not valid");
            ui["element"] = element;
        }
        rec.add_type("ui").doc = "Top-level namespace for the UI system.";
        rec.add_type("ui.element").doc = "Functions for creating and managing UI elements.";

        // 2) Bind every free-function from ui::element into that table
        // element.set_function("Initialize",                   &ui::element::Initialize);
        
        element.set_function("ApplyScalingToSubtree",        &ui::element::ApplyScalingFactorToSizesInSubtree);
        element.set_function("UpdateUIObjectScalingAndRecenter",&ui::element::UpdateUIObjectScalingAndRecnter);
        element.set_function("SetValues",                    &ui::element::SetValues);
        element.set_function("DebugPrintTree",               &ui::element::DebugPrintTree);
        element.set_function("InitializeVisualTransform",    &ui::element::InitializeVisualTransform);
        element.set_function("JuiceUp",                      &ui::element::JuiceUp);
        element.set_function("CanBeDragged",                 &ui::element::CanBeDragged);
        element.set_function("SetWH",                        &ui::element::SetWH);
        element.set_function("ApplyAlignment",               &ui::element::ApplyAlignment);
        element.set_function("SetAlignments",                &ui::element::SetAlignments);
        element.set_function("UpdateText",                   &ui::element::UpdateText);
        element.set_function("UpdateObject",                 &ui::element::UpdateObject);
        element.set_function("DrawSelf",                     &ui::element::DrawSelf);
        element.set_function("Update",                       &ui::element::Update);
        element.set_function("CollidesWithPoint",            &ui::element::CollidesWithPoint);
        element.set_function("PutFocusedCursor",             &ui::element::PutFocusedCursor);
        element.set_function("Remove",                       &ui::element::Remove);
        element.set_function("Click",                        &ui::element::Click);
        element.set_function("Release",                      &ui::element::Release);
        element.set_function("ApplyHover",                   &ui::element::ApplyHover);
        element.set_function("StopHover",                    &ui::element::StopHover);
        element.set_function("BuildUIDrawList",              &ui::element::buildUIDrawList);

        // Recorder: Document all the bound functions
        rec.record_free_function({"ui", "element"}, {"Initialize", "---@param registry registry\n---@param parent Entity\n---@param uiBox Entity\n---@param type UITypeEnum\n---@param config? UIConfig\n---@return Entity", "Initializes a new UI element.", true, false});
        rec.record_free_function({"ui", "element"}, {"ApplyScalingToSubtree", "---@param registry registry\n---@param rootEntity Entity\n---@param scaling number\n---@return nil", "Applies a scaling factor to all elements in a UI subtree.", true, false});
        rec.record_free_function({"ui", "element"}, {"UpdateUIObjectScalingAndRecenter", "---@param uiConfig UIConfig\n---@param newScale number\n---@param transform Transform\n---@return nil", "Updates the scaling of a UI object and recenters it.", true, false});
        rec.record_free_function({"ui", "element"}, {"SetValues", "---@param registry registry\n---@param entity Entity\n---@param _T table\n---@param recalculate boolean\n---@return nil", "Sets local transform values for a UI element.", true, false});
        rec.record_free_function({"ui", "element"}, {"DebugPrintTree", "---@param registry registry\n---@param entity Entity\n---@param indent integer\n---@return string", "Returns a string representation of the UI tree for debugging.", true, false});
        rec.record_free_function({"ui", "element"}, {"InitializeVisualTransform", "---@param registry registry\n---@param entity Entity\n---@return nil", "Initializes the visual transform properties (e.g., springs) for an element.", true, false});
        rec.record_free_function({"ui", "element"}, {"JuiceUp", "---@param registry registry\n---@param entity Entity\n---@param amount number\n---@param rot_amt number\n---@return nil", "Applies a 'juice' animation (dynamic motion) to an element.", true, false});
        rec.record_free_function({"ui", "element"}, {"CanBeDragged", "---@param registry registry\n---@param entity Entity\n---@return Entity|nil", "Checks if the element can be dragged and returns the draggable entity if so.", true, false});
        rec.record_free_function({"ui", "element"}, {"SetWH", "---@param registry registry\n---@param entity Entity\n---@return number, number", "Sets the width and height of an element based on its content and configuration.", true, false});
        rec.record_free_function({"ui", "element"}, {"ApplyAlignment", "---@param registry registry\n---@param entity Entity\n---@param x number\n---@param y number\n---@return nil", "Applies alignment logic to position an element.", true, false});
        rec.record_free_function({"ui", "element"}, {"SetAlignments", "---@param registry registry\n---@param entity Entity\n---@param uiBoxOffset? Vector2\n---@param rootEntity? boolean\n---@return nil", "Sets all alignments for an element within its UI box.", true, false});
        rec.record_free_function({"ui", "element"}, {"UpdateText", "---@param registry registry\n---@param entity Entity\n---@param config UIConfig\n---@param state UIState\n---@return nil", "Updates the text content and drawable for a text element.", true, false});
        rec.record_free_function({"ui", "element"}, {"UpdateObject", "---@param registry registry\n---@param entity Entity\n---@param elementConfig UIConfig\n---@param elementNode GameObject\n---@param objectConfig UIConfig\n---@param objTransform Transform\n---@param objectRole InheritedProperties\n---@param objectNode GameObject\n---@return nil", "Updates a UI element that represents a game object.", true, false});
        rec.record_free_function({"ui", "element"}, {"DrawSelf", "---@param layerPtr Layer\n---@param entity Entity\n---@param uiElementComp UIElementComponent\n---@param configComp UIConfig\n---@param stateComp UIState\n---@param nodeComp GameObject\n---@param transformComp Transform\n---@param zIndex? integer\n---@return nil", "Draws a single UI element.", true, false});
        rec.record_free_function({"ui", "element"}, {"Update", "---@param registry registry\n---@param entity Entity\n---@param dt number\n---@param uiConfig UIConfig\n---@param transform Transform\n---@param uiElement UIElementComponent\n---@param node GameObject\n---@return nil", "Performs a full update cycle for a UI element.", true, false});
        rec.record_free_function({"ui", "element"}, {"CollidesWithPoint", "---@param registry registry\n---@param entity Entity\n---@param cursorPosition Vector2\n---@return boolean", "Checks if a UI element collides with a given point.", true, false});
        rec.record_free_function({"ui", "element"}, {"PutFocusedCursor", "---@param registry registry\n---@param entity Entity\n---@return Vector2", "Gets the ideal position for a cursor when focusing this element.", true, false});
        rec.record_free_function({"ui", "element"}, {"Remove", "---@param registry registry\n---@param entity Entity\n---@return nil", "Removes a UI element and its children.", true, false});
        rec.record_free_function({"ui", "element"}, {"Click", "---@param registry registry\n---@param entity Entity\n---@return nil", "Triggers a click event on a UI element.", true, false});
        rec.record_free_function({"ui", "element"}, {"Release", "---@param registry registry\n---@param entity Entity\n---@param objectBeingDragged Entity\n---@return nil", "Triggers a release event on a UI element.", true, false});
        rec.record_free_function({"ui", "element"}, {"ApplyHover", "---@param registry registry\n---@param entity Entity\n---@return nil", "Applies hover state and effects to a UI element.", true, false});
        rec.record_free_function({"ui", "element"}, {"StopHover", "---@param registry registry\n---@param entity Entity\n---@return nil", "Removes hover state and effects from a UI element.", true, false});
        rec.record_free_function({"ui", "element"}, {"BuildUIDrawList", "---@param registry registry\n---@param root Entity\n---@param out_list table\n---@return nil", "Populates a table with a sorted list of UI entities to be drawn.", true, false});


        //==== UIBox methods ====
        sol::table box = ui.create_named("box");
        rec.add_type("ui.box").doc = "Functions for managing and laying out entire UI trees (boxes).";

        // 1) Alignment & tree building
        box.set_function("handleAlignment", &ui::box::handleAlignment);
        rec.record_free_function({"ui", "box"}, {"handleAlignment", "---@param registry registry\n---@param root Entity\n---@return nil", "Handles alignment for an entire UI tree.", true, false});
        
        box.set_function("BuildUIElementTree", &ui::box::BuildUIElementTree);
        rec.record_free_function({"ui", "box"}, {"BuildUIElementTree", "---@param registry registry\n---@param uiBoxEntity Entity\n---@param uiElementDef UIElementTemplateNode\n---@param uiElementParent Entity\n---@return nil", "Builds a UI tree from a template definition.", true, false});
        
                box.set_function("set_draw_layer", [&](entt::entity box, const std::string &name){
            auto layer = game::GetLayer(name);
            if (!layer) {
                spdlog::error("Unknown layer '{}'", name);
                return;
            }
            globals::getRegistry().emplace_or_replace<ui::UIBoxLayer>(box, name);
        });
        
        rec.record_free_function({"ui", "box"}, {"set_draw_layer", "---@param uiBox Entity\n---@param name string\n---@return nil", "Sets the draw layer for a UI box.", true, false});

        

        // 2) Initialization & placement
        // box.set_function("Initialize", &ui::box::Initialize);
        box.set_function("Initialize", 
            []( sol::table table, ui::UIElementTemplateNode temp) -> entt::entity {
            ui::TransformConfig config{};
            config.x = table["x"].get_or(0);
            config.y = table["y"].get_or(0);
            auto result = ui::box::Initialize(globals::getRegistry(), config, temp, ui::UIConfig{});
            SPDLOG_DEBUG("Initialized UI box {} with config: x={}, y={}", static_cast<uint32_t>(result), config.x, config.y);
            if (globals::getRegistry().any_of<ui::UIBoxComponent>(result)) {
                SPDLOG_DEBUG("UI box {} has UIBoxComponent", static_cast<uint32_t>(result));
            }
            return result;
        });
        box.set_function("AssignStateTagsToUIBox", [](entt::entity uiBox, const std::string &stateName) -> void {
            box::AssignStateTagsToUIBox(globals::getRegistry(), uiBox, stateName);
        });
        
        rec.record_free_function({"ui", "box"}, {"AssignStateTagsToUIBox", "---@param registry registry\n---@param uiBox Entity\n---@param stateName string\n---@return nil", "Assigns state tags to all elements in a UI box.", true, false});
         
        box.set_function("AddStateTagToUIBox", [](entt::entity uiBox, const std::string &tagToAdd) -> void {
            box::AddStateTagToUIBox(globals::getRegistry(), uiBox, tagToAdd);
        });
        rec.record_free_function({"ui", "box"}, {"AddStateTagToUIBox", "---@param uiBox Entity\n---@param tagToAdd string\n---@return nil", "Adds a state tag to all elements in a UI box.", true, false});
        
        box.set_function("ClearStateTagsFromUIBox", [](entt::entity uiBox) -> void {
            box::ClearStateTagsFromUIBox(globals::getRegistry(), uiBox);
        });
        rec.record_free_function({"ui", "box"}, {"ClearStateTagsFromUIBox", "---@param uiBox Entity\n---@return nil", "Clears state tags from all elements in a UI box.", true, false});
        // box["Initialize"] = []( sol::table table, ui::UIElementTemplateNode temp) -> entt::entity {
        //     ui::TransformConfig config{};
        //     config.x = table["x"].get_or(0);
        //     config.y = table["y"].get_or(0);
        //     auto result = ui::box::Initialize(globals::getRegistry(), config, temp, ui::UIConfig{});
        //     SPDLOG_DEBUG("Initialized UI box {} with config: x={}, y={}", static_cast<uint32_t>(result), config.x, config.y);
        //     if (globals::getRegistry().any_of<ui::UIBoxComponent>(result)) {
        //         SPDLOG_DEBUG("UI box {} has UIBoxComponent", static_cast<uint32_t>(result));
        //     }
        //     return result;
        // };
        rec.record_free_function({"ui", "box"}, {"Initialize", "---@param registry registry\n---@param transformData table\n---@param definition UIElementTemplateNode\n---@param config? UIConfig\n---@return Entity", "Initializes a new UI box from a definition.", true, false});

        box.set_function("placeUIElementsRecursively", &ui::box::placeUIElementsRecursively);
        rec.record_free_function({"ui", "box"}, {"placeUIElementsRecursively", "---@param registry registry\n---@param uiElement Entity\n---@param runningTransform table\n---@param parentType UITypeEnum\n---@param parent Entity\n---@return nil", "Recursively places UI elements within a layout.", true, false});

        box.set_function("placeNonContainerUIE", &ui::box::placeNonContainerUIE);
        rec.record_free_function({"ui", "box"}, {"placeNonContainerUIE", "---@param role InheritedProperties\n---@param runningTransform table\n---@param uiElement Entity\n---@param parentType UITypeEnum\n---@param uiState UIState\n---@param uiConfig UIConfig\n---@return nil", "Places a single non-container element within its parent.", true, false});

        // 3) Layout calculations
        box.set_function("ClampDimensionsToMinimumsIfPresent", &ui::box::ClampDimensionsToMinimumsIfPresent);
        rec.record_free_function({"ui", "box"}, {"ClampDimensionsToMinimumsIfPresent", "---@param uiConfig UIConfig\n---@param calcTransform table\n---@return nil", "Clamps the calculated transform dimensions to the configured minimums.", true, false});

        box.set_function("CalcTreeSizes", &ui::box::CalcTreeSizes);
        rec.record_free_function({"ui", "box"}, {"CalcTreeSizes", "---@param registry registry\n---@param uiElement Entity\n---@param parentUINodeRect table\n---@param forceRecalculateLayout? boolean\n---@param scale? number\n---@return number, number", "Calculates the sizes for an entire UI tree.", true, false});

        box.set_function("TreeCalcSubNonContainer", &ui::box::TreeCalcSubNonContainer);
        rec.record_free_function({"ui", "box"}, {"TreeCalcSubNonContainer", "---@param registry registry\n---@param uiElement Entity\n---@param parentUINodeRect table\n---@param forceRecalculateLayout boolean\n---@param scale? number\n---@param calcCurrentNodeTransform table\n---@return Vector2", "Calculates the size for a non-container sub-element.", true, false});

        box.set_function("RenewAlignment", &ui::box::RenewAlignment);
        rec.record_free_function({"ui", "box"}, {"RenewAlignment", "---@param registry registry\n---@param self Entity\n---@return nil", "Renews the alignment for an entity.", true, false});
        
        box.set_function("AddTemplateToUIBox", &ui::box::AddTemplateToUIBox);
        rec.record_free_function({"ui", "box"}, {"AddTemplateToUIBox", "---@param registry registry\n---@param uiBoxEntity Entity\n---@param templateDef UIElementTemplateNode\n---@param maybeParent Entity|nil\n---@return nil", "Adds a template definition to a UI box.", true, false});

        box.set_function("TreeCalcSubContainer", &ui::box::TreeCalcSubContainer);
        rec.record_free_function({"ui", "box"}, {"TreeCalcSubContainer", "---@param registry registry\n---@param uiElement Entity\n---@param parentUINodeRect table\n---@param forceRecalculateLayout boolean\n---@param scale? number\n---@param calcCurrentNodeTransform table\n---@param contentSizes table\n---@return Vector2", "Calculates the size for a container sub-element.", true, false});

        box.set_function("SubCalculateContainerSize", &ui::box::SubCalculateContainerSize);
        rec.record_free_function({"ui", "box"}, {"SubCalculateContainerSize", "---@param calcCurrentNodeTransform table\n---@param parentUINodeRect table\n---@param uiConfig UIConfig\n---@param calcChildTransform table\n---@param padding number\n---@param node GameObject\n---@param registry registry\n---@param factor number\n---@param contentSizes table\n---@return nil", "Sub-routine for calculating a container's size based on its children.", true, false});

        // 4) Lookup & removal
        box.set_function("GetUIEByID", sol::overload(
            static_cast<std::optional<entt::entity> (*)(entt::registry&, entt::entity, const std::string&)>(&ui::box::GetUIEByID),
            static_cast<std::optional<entt::entity> (*)(entt::registry&, const std::string&)>(&ui::box::GetUIEByID)
        ));
        rec.record_free_function({"ui", "box"}, {"GetUIEByID", "---@param registry registry\n---@param node Entity\n---@param id string\n---@return Entity|nil", "Gets a UI element by its ID, searching from a specific node.", true, false});
        rec.record_free_function({"ui", "box"}, {
            "GetUIEByID",
            R"(
        ---@param registry registry
        ---@param id string
        ---@return Entity|nil
        )",
            "Gets a UI element by its ID, searching globally.",
            true,
            true
        });

        box.set_function("RemoveGroup", &ui::box::RemoveGroup);
        rec.record_free_function({"ui", "box"}, {"RemoveGroup", "---@param registry registry\n---@param entity Entity\n---@param group string\n---@return boolean", "Removes all UI elements belonging to a specific group.", true, false});

        box.set_function("GetGroup", &ui::box::GetGroup);
        rec.record_free_function({"ui", "box"}, {"GetGroup", "---@param registry registry\n---@param entity Entity\n---@param group string\n---@return Entity[]", "Gets all UI elements belonging to a specific group.", true, false});

        box.set_function("Remove", &ui::box::Remove);
        rec.record_free_function({"ui", "box"}, {"Remove", "---@param registry registry\n---@param entity Entity\n---@return nil", "Removes a UI box and all its elements.", true, false});

        // 5) Recalculation & ordering
        box.set_function("Recalculate", &ui::box::Recalculate);
        rec.record_free_function({"ui", "box"}, {"Recalculate", "---@param registry registry\n---@param entity Entity\n---@return nil", "Forces a full recalculation of a UI box's layout.", true, false});

        box.set_function("AssignTreeOrderComponents", &ui::box::AssignTreeOrderComponents);
        rec.record_free_function({"ui", "box"}, {"AssignTreeOrderComponents", "---@param registry registry\n---@param rootUIElement Entity\n---@return nil", "Assigns tree order components for collision and input processing.", true, false});

        box.set_function("AssignLayerOrderComponents", &ui::box::AssignLayerOrderComponents);
        rec.record_free_function({"ui", "box"}, {"AssignLayerOrderComponents", "---@param registry registry\n---@param uiBox Entity\n---@return nil", "Assigns layer order components for drawing.", true, false});

        // 6) Movement & dragging
        box.set_function("Move", &ui::box::Move);
        rec.record_free_function({"ui", "box"}, {"Move", "---@param registry registry\n---@param self Entity\n---@param dt number\n---@return nil", "Updates the movement and spring physics for a UI box.", true, false});

        box.set_function("Drag", &ui::box::Drag);
        rec.record_free_function({"ui", "box"}, {"Drag", "---@param registry registry\n---@param self Entity\n---@param offset Vector2\n---@param dt number\n---@return nil", "Handles dragging logic for a UI box.", true, false});

        // 7) Child management & containers
        box.set_function("AddChild", &ui::box::AddChild);
        rec.record_free_function({"ui", "box"}, {"AddChild", "---@param registry registry\n---@param uiBox Entity\n---@param uiElementDef UIElementTemplateNode\n---@param parent Entity\n---@return nil", "Adds a new child element to a UI box or container.", true, false});

        box.set_function("SetContainer", &ui::box::SetContainer);
        rec.record_free_function({"ui", "box"}, {"SetContainer", "---@param registry registry\n---@param self Entity\n---@param container Entity\n---@return nil", "Sets the container for a UI box.", true, false});

        // 8) Debugging
        box.set_function("DebugPrint", &ui::box::DebugPrint);
        rec.record_free_function({"ui", "box"}, {"DebugPrint", "---@param registry registry\n---@param self Entity\n---@param indent? integer\n---@return string", "Returns a string representation of the UI box tree for debugging.", true, false});

        box.set_function("TraverseUITreeBottomUp", &ui::box::TraverseUITreeBottomUp);
        rec.record_free_function({"ui", "box"}, {"TraverseUITreeBottomUp", "---@param registry registry\n---@param rootUIElement Entity\n---@param visitor fun(entity: Entity)\n---@return nil", "Traverses the UI tree from the leaves up to the root, calling the visitor function on each element.", true, false});

        box.set_function("ReplaceChildren", [](entt::entity parent, ui::UIElementTemplateNode definition) -> bool {
            auto& registry = globals::getRegistry();
            return ui::box::ReplaceChildren(registry, parent, definition);
        });
        rec.record_free_function({"ui", "box"}, {"ReplaceChildren", "---@param parent Entity\n---@param definition UIElementTemplateNode\n---@return boolean", "Replaces all children of a UI element with new content from a definition.", true, false});

        // 9) Drawing lists
        box.set_function("drawAllBoxes", &ui::box::drawAllBoxes);
        rec.record_free_function({"ui", "box"}, {"drawAllBoxes", "---@param registry registry\n---@param layerPtr Layer\n---@return nil", "Draws all UI boxes in the registry.", true, false});

        box.set_function("buildUIBoxDrawList", &ui::box::buildUIBoxDrawList);
        rec.record_free_function({"ui", "box"}, {"buildUIBoxDrawList", "---@param registry registry\n---@param boxEntity Entity\n---@param out_list table\n---@return nil", "Builds a sorted list of all drawable elements within a UI box.", true, false});

        // 10) Helpers
        box.set_function("ClampDimensionsToMinimumsIfPresent", &ui::box::ClampDimensionsToMinimumsIfPresent);
        // This is a duplicate key, but we'll record it again as the user provided it.
        rec.record_free_function({"ui", "box"}, {"ClampDimensionsToMinimumsIfPresent", "---@param uiConfig UIConfig\n---@param calcTransform table\n---@return nil", "Clamps the calculated transform dimensions to the configured minimums.", true, false});

        // UI Asset Pack system
        exposePackToLua(lua);
    }
}
