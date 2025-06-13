#include "ui.hpp"
#include "sol/sol.hpp"

#include "systems/scripting/binding_recorder.hpp"

namespace ui {
    auto exposeToLua(sol::state &lua) -> void {
        
        // 1) Empty “tag” type
        lua.new_usertype<ObjectAttachedToUITag>("ObjectAttachedToUITag", 
            sol::constructors<>()
        );

        lua.new_enum("UITypeEnum",
            std::initializer_list<std::pair<sol::string_view, UITypeEnum>>{
                {"NONE",                UITypeEnum::NONE},
                {"ROOT",                UITypeEnum::ROOT},
                {"VERTICAL_CONTAINER",  UITypeEnum::VERTICAL_CONTAINER},
                {"HORIZONTAL_CONTAINER",UITypeEnum::HORIZONTAL_CONTAINER},
                {"SLIDER_UI",           UITypeEnum::SLIDER_UI},
                {"INPUT_TEXT",          UITypeEnum::INPUT_TEXT},
                {"RECT_SHAPE",          UITypeEnum::RECT_SHAPE},
                {"TEXT",                UITypeEnum::TEXT},
                {"OBJECT",              UITypeEnum::OBJECT}
            }
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

        lua.new_enum<UIStylingType>("UIStylingType", {
            {"RoundedRectangle", UIStylingType::ROUNDED_RECTANGLE},
            {"NinePatchBorders", UIStylingType::NINEPATCH_BORDERS}
        });
        
        // UIConfig
        lua.new_usertype<UIConfig>("UIConfig",
            sol::constructors<>(),

            // Styling
            "stylingType",            &UIConfig::stylingType,
            "nPatchInfo",             &UIConfig::nPatchInfo,
            "nPatchSourceTexture",    &UIConfig::nPatchSourceTexture,

            // General
            "id",                     &UIConfig::id,
            "instanceType",           &UIConfig::instanceType,
            "uiType",                 &UIConfig::uiType,
            "drawLayer",              &UIConfig::drawLayer,
            "group",                  &UIConfig::group,
            "groupParent",            &UIConfig::groupParent,

            // Position & transform
            "location_bond",          &UIConfig::location_bond,
            "rotation_bond",          &UIConfig::rotation_bond,
            "size_bond",              &UIConfig::size_bond,
            "scale_bond",             &UIConfig::scale_bond,
            "offset",                 &UIConfig::offset,
            "scale",                  &UIConfig::scale,
            "textSpacing",            &UIConfig::textSpacing,
            "focusWithObject",        &UIConfig::focusWithObject,
            "refreshMovement",        &UIConfig::refreshMovement,
            "no_recalc",              &UIConfig::no_recalc,
            "non_recalc",             &UIConfig::non_recalc,
            "noMovementWhenDragged",  &UIConfig::noMovementWhenDragged,

            // Hierarchy
            "master",                 &UIConfig::master,
            "parent",                 &UIConfig::parent,
            "object",                 &UIConfig::object,
            "objectRecalculate",      &UIConfig::objectRecalculate,

            // Dimensions & alignment
            "alignmentFlags",         &UIConfig::alignmentFlags,
            "width",                  &UIConfig::width,
            "height",                 &UIConfig::height,
            "maxWidth",               &UIConfig::maxWidth,
            "maxHeight",              &UIConfig::maxHeight,
            "minWidth",               &UIConfig::minWidth,
            "minHeight",              &UIConfig::minHeight,
            "padding",                &UIConfig::padding,

            // Appearance
            "color",                  &UIConfig::color,
            "outlineColor",           &UIConfig::outlineColor,
            "outlineThickness",       &UIConfig::outlineThickness,
            "makeMovementDynamic",    &UIConfig::makeMovementDynamic,
            "shadow",                 &UIConfig::shadow,
            "outlineShadow",          &UIConfig::outlineShadow,
            "shadowColor",            &UIConfig::shadowColor,
            "noFill",                 &UIConfig::noFill,
            "pixelatedRectangle",     &UIConfig::pixelatedRectangle,

            // Collision & interactivity
            "canCollide",             &UIConfig::canCollide,
            "collideable",            &UIConfig::collideable,
            "forceCollision",         &UIConfig::forceCollision,
            "button_UIE",             &UIConfig::button_UIE,
            "disable_button",         &UIConfig::disable_button,

            // Progress bar
            "progressBarFetchValueLambda", &UIConfig::progressBarFetchValueLambda,
            "progressBar",                 &UIConfig::progressBar,
            "progressBarEmptyColor",       &UIConfig::progressBarEmptyColor,
            "progressBarFullColor",        &UIConfig::progressBarFullColor,
            "progressBarMaxValue",         &UIConfig::progressBarMaxValue,
            "progressBarValueComponentName", &UIConfig::progressBarValueComponentName,
            "progressBarValueFieldName",     &UIConfig::progressBarValueFieldName,
            "ui_object_updated",             &UIConfig::ui_object_updated,

            // Button delays & clicks
            "buttonDelayStart",       &UIConfig::buttonDelayStart,
            "buttonDelay",            &UIConfig::buttonDelay,
            "buttonDelayProgress",    &UIConfig::buttonDelayProgress,
            "buttonDelayEnd",         &UIConfig::buttonDelayEnd,
            "buttonClicked",          &UIConfig::buttonClicked,
            "buttonDistance",         &UIConfig::buttonDistance,

            // Tooltips & hover
            "tooltip",                &UIConfig::tooltip,
            "detailedTooltip",        &UIConfig::detailedTooltip,
            "onDemandTooltip",        &UIConfig::onDemandTooltip,
            "hover",                  &UIConfig::hover,

            // Special behaviors
            "force_focus",            &UIConfig::force_focus,
            "dynamicMotion",          &UIConfig::dynamicMotion,
            "choice",                 &UIConfig::choice,
            "chosen",                 &UIConfig::chosen,
            "one_press",              &UIConfig::one_press,
            "chosen_vert",            &UIConfig::chosen_vert,
            "draw_after",             &UIConfig::draw_after,
            "focusArgs",              &UIConfig::focusArgs,

            // Scripting callbacks
            "updateFunc",             &UIConfig::updateFunc,
            "initFunc",               &UIConfig::initFunc,
            "onUIResizeFunc",         &UIConfig::onUIResizeFunc,
            "onUIScalingResetToOne",  &UIConfig::onUIScalingResetToOne,
            "instaFunc",              &UIConfig::instaFunc,
            "buttonCallback",         &UIConfig::buttonCallback,
            "buttonTemp",             &UIConfig::buttonTemp,
            "textGetter",             &UIConfig::textGetter,

            // References & text
            "ref_entity",             &UIConfig::ref_entity,
            "ref_component",          &UIConfig::ref_component,
            "ref_value",              &UIConfig::ref_value,
            "prev_ref_value",         &UIConfig::prev_ref_value,
            "text",                   &UIConfig::text,
            "language",               &UIConfig::language,
            "verticalText",           &UIConfig::verticalText,

            // Popups
            "hPopup",                 &UIConfig::hPopup,
            "dPopup",                 &UIConfig::dPopup,
            "hPopupConfig",           &UIConfig::hPopupConfig,
            "dPopupConfig",           &UIConfig::dPopupConfig,

            // Misc
            "extend_up",              &UIConfig::extend_up,
            "resolution",             &UIConfig::resolution,
            "emboss",                 &UIConfig::emboss,
            "line_emboss",            &UIConfig::line_emboss,
            "mid",                    &UIConfig::mid,
            "noRole",                 &UIConfig::noRole,
            "role",                   &UIConfig::role,
            "stylingType",            &UIConfig::stylingType,
            "nPatchInfo",             &UIConfig::nPatchInfo,
            "nPatchSourceTexture",    &UIConfig::nPatchSourceTexture
        );

        // UIConfig::Builder
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
            "addMinHeight",                   &UIConfig::Builder::addMinHeight,
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
            "build",                          &UIConfig::Builder::build
        );
        
        lua.new_usertype<UIElementTemplateNode>("UIElementTemplateNode",
            sol::constructors<>(),
            "type",     &UIElementTemplateNode::type,
            "config",   &UIElementTemplateNode::config,
            "children", &UIElementTemplateNode::children
        );
    
        lua.new_usertype<UIElementTemplateNode::Builder>("UIElementTemplateNodeBuilder",
            sol::constructors<>(),
            "create",   &UIElementTemplateNode::Builder::create,
            "addType",  &UIElementTemplateNode::Builder::addType,
            "addConfig",&UIElementTemplateNode::Builder::addConfig,
            "addChild", &UIElementTemplateNode::Builder::addChild,
            "build",    &UIElementTemplateNode::Builder::build
        );
    
        //==== UIElement methods ====
        // 1) Create (or get) the 'ui.element' table in Lua
        // Step 1: make `ui = {}` and get it back
        sol::table ui = lua.create_named_table("ui");
        sol::table element = ui.create_named("element");
        // Now element refers to lua.ui.element

        // 2) Bind every free-function from ui::element into that table
        element.set_function("Initialize",                     &ui::element::Initialize);
        element.set_function("ApplyScalingToSubtree",          &ui::element::ApplyScalingFactorToSizesInSubtree);
        element.set_function("UpdateUIObjectScalingAndRecenter",&ui::element::UpdateUIObjectScalingAndRecnter);
        element.set_function("SetValues",                      &ui::element::SetValues);
        element.set_function("DebugPrintTree",                 &ui::element::DebugPrintTree);
        element.set_function("InitializeVisualTransform",      &ui::element::InitializeVisualTransform);
        element.set_function("JuiceUp",                        &ui::element::JuiceUp);
        element.set_function("CanBeDragged",                   &ui::element::CanBeDragged);
        element.set_function("SetWH",                          &ui::element::SetWH);
        element.set_function("ApplyAlignment",                 &ui::element::ApplyAlignment);
        element.set_function("SetAlignments",                  &ui::element::SetAlignments);
        element.set_function("UpdateText",                     &ui::element::UpdateText);
        element.set_function("UpdateObject",                   &ui::element::UpdateObject);
        element.set_function("DrawSelf",                       &ui::element::DrawSelf);
        element.set_function("Update",                         &ui::element::Update);
        element.set_function("CollidesWithPoint",              &ui::element::CollidesWithPoint);
        element.set_function("PutFocusedCursor",               &ui::element::PutFocusedCursor);
        element.set_function("Remove",                         &ui::element::Remove);
        element.set_function("Click",                          &ui::element::Click);
        element.set_function("Release",                        &ui::element::Release);
        element.set_function("ApplyHover",                     &ui::element::ApplyHover);
        element.set_function("StopHover",                      &ui::element::StopHover);
        element.set_function("BuildUIDrawList",                &ui::element::buildUIDrawList);
        
        // ==== UIBox methods ====
        
        // Ensure ui.box exists (and ui too)
        sol::table box = ui.create_named("box");

        // 1) Alignment & tree building
        box.set_function("handleAlignment", &ui::box::handleAlignment);
        box.set_function("BuildUIElementTree", &ui::box::BuildUIElementTree);

        // 2) Initialization & placement
        box.set_function("Initialize", &ui::box::Initialize);
        box.set_function("placeUIElementsRecursively", &ui::box::placeUIElementsRecursively);
        box.set_function("placeNonContainerUIE", &ui::box::placeNonContainerUIE);

        // 3) Layout calculations
        box.set_function("ClampDimensionsToMinimumsIfPresent", &ui::box::ClampDimensionsToMinimumsIfPresent);
        box.set_function("CalcTreeSizes", &ui::box::CalcTreeSizes);
        box.set_function("TreeCalcSubNonContainer", &ui::box::TreeCalcSubNonContainer);
        box.set_function("RenewAlignment", &ui::box::RenewAlignment);
        box.set_function("TreeCalcSubContainer", &ui::box::TreeCalcSubContainer);
        box.set_function("SubCalculateContainerSize", &ui::box::SubCalculateContainerSize);

        // 4) Lookup & removal
        box.set_function("GetUIEByID", sol::overload(
            static_cast<std::optional<entt::entity> (*)(entt::registry&, entt::entity, const std::string&)>(&ui::box::GetUIEByID),
            static_cast<std::optional<entt::entity> (*)(entt::registry&, const std::string&)>(&ui::box::GetUIEByID)
        ));
        box.set_function("RemoveGroup", &ui::box::RemoveGroup);
        box.set_function("GetGroup", &ui::box::GetGroup);
        box.set_function("Remove", &ui::box::Remove);

        // 5) Recalculation & ordering
        box.set_function("Recalculate", &ui::box::Recalculate);
        box.set_function("AssignTreeOrderComponents", &ui::box::AssignTreeOrderComponents);
        box.set_function("AssignLayerOrderComponents", &ui::box::AssignLayerOrderComponents);

        // 6) Movement & dragging
        box.set_function("Move", &ui::box::Move);
        box.set_function("Drag", &ui::box::Drag);

        // 7) Child management & containers
        box.set_function("AddChild", &ui::box::AddChild);
        box.set_function("SetContainer", &ui::box::SetContainer);

        // 8) Debugging
        box.set_function("DebugPrint", &ui::box::DebugPrint);
        box.set_function("TraverseUITreeBottomUp", &ui::box::TraverseUITreeBottomUp);

        // 9) Drawing lists
        box.set_function("drawAllBoxes", &ui::box::drawAllBoxes);
        box.set_function("buildUIBoxDrawList", &ui::box::buildUIBoxDrawList);

        // 10) Helpers
        box.set_function("ClampDimensionsToMinimumsIfPresent", &ui::box::ClampDimensionsToMinimumsIfPresent);
        
    }
}