#include "element.hpp"

#include "components/graphics.hpp"
#include "entt/entity/fwd.hpp"
#include "snowhouse/fluent/fluent.h"
#include "spdlog/spdlog.h"
#include "systems/layer/layer.hpp"
#include "systems/layer/layer_optimized.hpp"
#include "systems/reflection/reflection.hpp"
#include "systems/text/textVer2.hpp"
#include "core/globals.hpp"
#include "systems/localization/localization.hpp"
#include "systems/ui/ui_data.hpp"
#include "systems/ui/core/ui_components.hpp"
#include "util/utilities.hpp"
#include "inventory_ui.hpp"
#include "systems/collision/broad_phase.hpp"
#include "systems/shaders/shader_pipeline.hpp"

#include "systems/layer/layer_command_buffer.hpp"
#include "systems/entity_gamestate_management/entity_gamestate_management.hpp"
#include <cstddef>

namespace ui
{
    namespace
    {
        // Resolve the font for a given UI configuration, falling back to the current language font.
        const globals::FontData& resolveFontData(const UIConfig* config)
        {
            if (config && config->fontName) {
                const auto& fontName = config->fontName.value();
                if (localization::hasNamedFont(fontName)) {
                    return localization::getNamedFont(fontName);
                }
            }
            return localization::getFontData();
        }
    }

    //TODO: update function registry for methods that replace transform-provided methods

    // TODO: two of these?
    entt::entity element::Initialize(
        entt::registry &registry,
        entt::entity parent,
        entt::entity uiBox,
        UITypeEnum type,
        std::optional<UIConfig> config)
    {
        entt::entity entity = transform::CreateOrEmplace(&registry, globals::getGameWorldContainer(), 0, 0, 0, 0); // values are set up in set_values
        
        // ui element should be screen space by default
        registry.emplace<collision::ScreenSpaceCollisionMarker>(entity);
        
        // don't let ui X-lean
        auto &transform = registry.get<transform::Transform>(entity);
        transform.ignoreXLeaning = true; // don't let UI elements x-lean, they should always be aligned to the parent

        // Save configuration
        if (config)
        {
            registry.emplace<UIConfig>(entity, *config);
        }
        else
        {
            registry.emplace<UIConfig>(entity);
        }
        registry.get<UIConfig>(entity).uiType = type;

        // Set up parent-child relationship
        auto &element = registry.emplace<UIElementComponent>(entity);
        element.UIT = type;
        element.uiBox = uiBox;
        auto &uiState = registry.emplace<UIState>(entity);
        uiState.contentDimensions = {0, 0};

        // Emplace split components for gradual migration (Phase 1)
        if (config) {
            registry.emplace<UIElementCore>(entity, UIElementCore{
                .type = type,
                .uiBox = uiBox,
                .id = config->id.value_or(""),
                .treeOrder = 0
            });
            registry.emplace<UIStyleConfig>(entity, extractStyle(*config));
            registry.emplace<UILayoutConfig>(entity, extractLayout(*config));
            registry.emplace<UIInteractionConfig>(entity, extractInteraction(*config));
            registry.emplace<UIContentConfig>(entity, extractContent(*config));
        } else {
            registry.emplace<UIElementCore>(entity, UIElementCore{
                .type = type,
                .uiBox = uiBox,
                .id = "",
                .treeOrder = 0
            });
            registry.emplace<UIStyleConfig>(entity);
            registry.emplace<UILayoutConfig>(entity);
            registry.emplace<UIInteractionConfig>(entity);
            registry.emplace<UIContentConfig>(entity);
        }

        auto &node = registry.get<transform::GameObject>(entity);
        node.methods.onHover = nullptr; // disable ui jiggle by default
        node.parent = parent;
        // node.debug.debugText = fmt::format("UIElement {}", static_cast<int>(entity));

        if (config && config->object)
        {
            // TODO: think of a more logical place for parent variable (perhaps node?)
            // auto &objectUIElement = registry.get<UIElementComponent>(config->object.value());
            auto &objectUINode = registry.get<transform::GameObject>(config->object.value());
            objectUINode.parent = entity;
        }
        
        
        // is it a text input?
        if (type == UITypeEnum::INPUT_TEXT)
        {
            // create a text input comp
            registry.emplace_or_replace<TextInput>(entity);
            // make hoverable & collidable
            auto &node = registry.get<transform::GameObject>(entity);
            node.state.hoverEnabled = true;
            node.state.collisionEnabled = true;
            node.state.clickEnabled = true; // enable click events
            
            // change active text input on click
            node.methods.onClick = [entity](entt::registry &reg, entt::entity) {
                globals::getInputState().activeTextInput = entity;
                SPDLOG_DEBUG("Set active text input to {}", static_cast<int>(entity));
            };
            
            node.methods.onHover = [entity](entt::registry &reg, entt::entity) {
                // set mouse cursor to IBEAM
                SetMouseCursor(MOUSE_CURSOR_IBEAM);
            };
            
            node.methods.onStopHover = [entity](entt::registry &reg, entt::entity) {
                // reset mouse cursor to default
                SetMouseCursor(MOUSE_CURSOR_DEFAULT);
            };
        }

        // TODO: doesn't seem to add to the parent's children list? why?

        return entity;
    }

    // entt::entity element::Init(entt::registry &registry, entt::entity parent, entt::entity uiBox, UITypeEnum type,
    //                            std::optional<UIConfig> config)
    // {

    //     // make movable base entity
    //     entt::entity entity = transform::CreateOrEmplace(&registry, globals::gameWorldContainerEntity, 0, 0, 0, 0);
    //     // TODO: any initialization of fields that is being missed?

    //     // save configuration
    //     if (config)
    //     {
    //         registry.emplace<UIConfig>(entity, *config);
    //     }
    //     else
    //     {
    //         registry.emplace<UIConfig>(entity);
    //     }

    //     // TODO: check that master and parent are not confused in entire file

    //     if (config && config->object)
    //     {
    //         auto &role = registry.get<transform::InheritedProperties>(config->object.value());
    //         role.master = entity;
    //     }
    //     auto &node = registry.get<transform::GameObject>(entity);
    //     node.parent = parent;

    //     auto &element = registry.emplace<UIElementComponent>(entity);
    //     element.UIT = type;
    //     element.uiBox = uiBox;

    //     auto &uiState = registry.emplace<UIState>(entity);
    //     uiState.contentDimensions = {0, 0}; // Default dimensions

    //     // TODO: how much of the above should be in uiconfig?
        
    //     // TODO: not sure if this is necssary
    //     // if (registry.valid(parent)) {
    //     //     auto* parentElement = registry.try_get<UIElementComponent>(parent);
    //     //     if (parentElement) {
    //     //         parentElement->children.push_back(entity); // Add this element as a child
    //     //     }
    //     // }
    // }

    void element::SetValues(entt::registry &registry, entt::entity entity, const LocalTransform &transformReference, bool recalculate)
    {
        auto *transform = registry.try_get<transform::Transform>(entity);
        auto *uiElement = registry.try_get<UIElementComponent>(entity);
        auto *uiConfig = registry.try_get<UIConfig>(entity);
        auto *uiState = registry.try_get<UIState>(entity);

        AssertThat(uiElement, Is().Not().EqualTo(nullptr));
        AssertThat(uiConfig, Is().Not().EqualTo(nullptr));
        AssertThat(uiState, Is().Not().EqualTo(nullptr));

        // Initialize transform if it's a new element or not recalculating
        if (!recalculate || transform == nullptr)
        {
            if (transform == nullptr)
            {
                transform::CreateOrEmplace(&registry, globals::getGameWorldContainer(), transformReference.x, transformReference.y, transformReference.w, transformReference.h, entity);
            }
            else {
                transform->setActualX(transformReference.x);
                transform->setActualY(transformReference.y);
                transform->setActualW(transformReference.w);
                transform->setActualH(transformReference.h);
            }
            auto &node = registry.get<transform::GameObject>(entity);
            node.state.clickEnabled = false;
            node.state.dragEnabled = false;
        }
        else
        {
            transform->setActualX(transformReference.x);
            transform->setActualY(transformReference.y);
            transform->setActualW(transformReference.w);
            transform->setActualH(transformReference.h);
        }

        auto &node = registry.get<transform::GameObject>(entity);

        // Handle button-related properties
        if (uiConfig->button_UIE)
        {
            node.state.collisionEnabled = true;
            node.state.hoverEnabled = false;
            node.state.clickEnabled = true;
        }
        if (uiConfig->buttonCallback)
        {
            node.state.collisionEnabled = true;
            node.state.clickEnabled = true;
        }
        if (uiConfig->hover) {
            node.state.hoverEnabled = true;
        }

        // Handle collision settings for tooltips
        if (uiConfig->onDemandTooltip || uiConfig->tooltip || uiConfig->detailedTooltip)
        {
            node.state.collisionEnabled = true;
        }

        // check if it is a text object
        //FIXME: not useful?
        // if (uiElement->UIT == UITypeEnum::OBJECT)
        // {
        //     SPDLOG_DEBUG("Setting up text object with entity {}", static_cast<int>(entity));
            
        //     transform::AssignRole(&registry, uiConfig->object.value(), transform::InheritedProperties::Type::RoleInheritor,
        //         uiElement->uiBox,
        //         transform::InheritedProperties::Sync::Strong,
        //         transform::InheritedProperties::Sync::Strong,
        //         transform::InheritedProperties::Sync::Weak,
        //         transform::InheritedProperties::Sync::Weak,
        //         Vector2{transformReference.x, transformReference.y});
        // } else {
            transform::AssignRole(&registry, entity, transform::InheritedProperties::Type::RoleInheritor,
                uiElement->uiBox,
                transform::InheritedProperties::Sync::Strong,
                transform::InheritedProperties::Sync::Strong,
                transform::InheritedProperties::Sync::Weak,
                transform::InheritedProperties::Sync::Weak,
                Vector2{transformReference.x, transformReference.y});
        // }


        // Assign to draw layers if applicable
        if (uiConfig->drawLayer)
        {
            auto *uiBox = registry.try_get<UIBoxComponent>(uiElement->uiBox);
            if (uiBox)
            {
                uiBox->drawLayers[uiConfig->drawLayer.value()] = entity;
            }
        }

        // Handle collision properties
        if (uiConfig->collideable)
        {
            node.state.collisionEnabled = true;
        }
        if (uiConfig->canCollide)
        {
            node.state.collisionEnabled = uiConfig->canCollide.value();
            if (uiConfig->object)
            {
                auto *objectNode = registry.try_get<transform::GameObject>(uiConfig->object.value());
                if (objectNode)
                {
                    objectNode->state.collisionEnabled = uiConfig->canCollide.value();
                }
            }
        }

        // Assign roles for UI objects
        if (uiElement->UIT == UITypeEnum::OBJECT && !uiConfig->noRole.value_or(false))
        {
            transform::AssignRole(&registry, uiConfig->object.value(), transform::InheritedProperties::Type::RoleInheritor, entity, transform::InheritedProperties::Sync::Strong, transform::InheritedProperties::Sync::Weak, std::nullopt, transform::InheritedProperties::Sync::Weak);
        }

        // Handle reference values
        if (uiConfig->ref_component && uiConfig->ref_value)
        {
            auto comp = reflection::retrieveComponent(&registry, uiConfig->ref_entity.value(), uiConfig->ref_component.value());
            auto value = reflection::retrieveFieldByString(comp, uiConfig->ref_component.value(), uiConfig->ref_value.value());
            uiConfig->prev_ref_value = value;
        }

        // Apply dynamicMotion (animation effects)
        if (uiConfig->dynamicMotion)
        {

            if (uiElement->UIT == UITypeEnum::ROOT)
                transform::InjectDynamicMotion(&registry, entity);
            if (uiElement->UIT == UITypeEnum::TEXT)
                transform::InjectDynamicMotion(&registry, entity);
            if (uiElement->UIT == UITypeEnum::OBJECT)
                transform::InjectDynamicMotion(&registry, entity, 0.5f);
            if (uiElement->UIT == UITypeEnum::RECT_SHAPE)
                transform::InjectDynamicMotion(&registry, entity);
            if (uiElement->UIT == UITypeEnum::VERTICAL_CONTAINER)
                transform::InjectDynamicMotion(&registry, entity);
            if (uiElement->UIT == UITypeEnum::HORIZONTAL_CONTAINER)
                transform::InjectDynamicMotion(&registry, entity);
            if (uiElement->UIT == UITypeEnum::SCROLL_PANE)
                transform::InjectDynamicMotion(&registry, entity);
            if (uiElement->UIT == UITypeEnum::INPUT_TEXT)
                transform::InjectDynamicMotion(&registry, entity);
            
            uiConfig->dynamicMotion = false;
        }

        // Assign default colors if not already set
        if (!uiConfig->color)
        {
            switch (uiElement->UIT)
            {
            case UITypeEnum::ROOT:
            {
                uiConfig->color = globals::uiBackgroundDark;
                break;
            }
            case UITypeEnum::TEXT:
            {
                uiConfig->color = globals::uiTextLight;
                break;
            }
            case UITypeEnum::OBJECT:
            {
                uiConfig->color = WHITE;
                break;
            }
            case UITypeEnum::RECT_SHAPE:
            case UITypeEnum::VERTICAL_CONTAINER:
            case UITypeEnum::HORIZONTAL_CONTAINER:
            case UITypeEnum::SCROLL_PANE:
            {
                uiConfig->color = BLANK;
                break;
            }
            default:
            {
                break;
            }
            }
        }

        // Assign default outline colors if not already set
        if (!uiConfig->outlineColor)
        {
            switch (uiElement->UIT)
            {
            case UITypeEnum::ROOT:
            case UITypeEnum::TEXT:
            case UITypeEnum::OBJECT:
            case UITypeEnum::RECT_SHAPE:
            case UITypeEnum::INPUT_TEXT:
            case UITypeEnum::VERTICAL_CONTAINER:
            case UITypeEnum::SCROLL_PANE:
            case UITypeEnum::HORIZONTAL_CONTAINER:
                uiConfig->outlineColor = globals::uiOutlineLight;
                break;
            default:
                break;
            }
        }

        // Handle controller focus-related properties
        if (uiConfig->focusArgs && !uiConfig->focusArgs->registered)
        {
            if (uiConfig->focusArgs->button)
            {
                input::AddNodeToInputRegistry(registry, globals::getInputState(), uiConfig->button_UIE.value_or(entity), uiConfig->focusArgs->button.value());
            }
            if (uiConfig->focusArgs->snap_to)
            {
                input::SnapToNode(registry, globals::getInputState(), entity);
            }
            if (uiConfig->focusArgs->redirect_focus_to)
            {
                entt::entity parent = node.parent.value();
                while (registry.valid(parent))
                {
                    auto *parentConfig = registry.try_get<UIConfig>(parent);
                    if (parentConfig && parentConfig->focusArgs && parentConfig->focusArgs->claim_focus_from)
                    { // TODO: document funnel from and funnel to, make better names
                        parentConfig->focusArgs->claim_focus_from = entity;
                        uiConfig->focusArgs->redirect_focus_to = parent;
                        break;
                    }
                    auto *parentElement = registry.try_get<UIElementComponent>(parent);
                    auto *parentNode = registry.try_get<transform::GameObject>(parent);
                    parent = parentElement ? parentNode->parent.value() : entt::null;
                }
            }
            uiConfig->focusArgs->registered = true;
        }

        // Handle button delay logic
        if (uiConfig->buttonDelay && !uiConfig->buttonDelayStart)
        {
            uiConfig->buttonDelayStart = main_loop::mainLoop.realtimeTimer;
            uiConfig->buttonDelayEnd = main_loop::mainLoop.realtimeTimer + uiConfig->buttonDelay.value();
            uiConfig->buttonDelayProgress = 0;
        }


        // Initialize parallax layer effect
        // TODO: not sure if this is necessary
        // uiConfig->layeredParallax = {0, 0};

        // Execute associated function if applicable
        // TODO: use set_button_pip function later?
        if (uiConfig->updateFunc && ((uiConfig->button_UIE || uiConfig->buttonCallback)) /*&& uiConfig->updateFunc != "set_button_pip")*/ || uiConfig->instaFunc)
        {
            
            uiConfig->updateFunc.value()(&registry, entity, 0.f);
        }
        
        if (uiConfig->initFunc)
        {
            uiConfig->initFunc.value()(&registry, entity);
        }
    }

    std::string element::DebugPrintTree(entt::registry &registry, entt::entity entity, int indent)
    {
        // Ensure the entity is valid
        if (!registry.valid(entity))
        {
            return std::string(indent, ' ') + "| INVALID ENTITY |\n";
        }

        // Retrieve the UI element's config and transform components
        auto *uiElement = registry.try_get<UIElementComponent>(entity);
        auto *uiConfig = registry.try_get<UIConfig>(entity);
        auto *transform = registry.try_get<transform::Transform>(entity);
        auto *node = registry.try_get<transform::GameObject>(entity);
        auto *role = registry.try_get<transform::InheritedProperties>(entity);
        auto treeOrder = registry.try_get<transform::TreeOrderComponent>(entity);

        // Ensure the entity is a valid UIElement
        if (!uiElement || !uiConfig || !transform)
        {
            return std::string(indent, ' ') + "| MISSING COMPONENTS |\n";
        }

        // Determine the UI type as a string
        std::string UIT(magic_enum::enum_name(uiElement->UIT));

        // Build the topology string with indentation
        std::string boxStr = fmt::format("\n{}| {} | - ID: {} [entt-{}] w/h: {}/{} UIElement children: {} | LOC({},{}) OFF({},{}) OFF_ALN({},{}) {} TreeOrder: {}",
            std::string(indent * 2, ' '),
            UIT,
            uiConfig->id.value_or("N/A"),
            static_cast<int>(entity),
            static_cast<int>(transform->getActualW()),
            static_cast<int>(transform->getActualH()),
            node->children.size(),
            static_cast<int>(transform->getActualX()),
            static_cast<int>(transform->getActualY()),
            static_cast<int>(role->offset->x),
            static_cast<int>(role->offset->y),
            static_cast<int>(role->flags->extraAlignmentFinetuningOffset.x),
            static_cast<int>(role->flags->extraAlignmentFinetuningOffset.y),
            node->state.isBeingHovered ? "HOVERED" : "",
            treeOrder? std::to_string(treeOrder->order) : "N/A"
        );

        // If this is an "Object" (UIT == "O"), determine object type
        if (uiElement->UIT == UITypeEnum::OBJECT)
        {
            std::string objectType = "OTHER";

            if (uiConfig->object)
            {
                auto *objTransform = registry.try_get<transform::Transform>(*uiConfig->object);
                auto *objectRole = registry.try_get<transform::InheritedProperties>(*uiConfig->object);

                // Check object type based on class assumptions (this should be refined)
                // LATER: add these in later
                if (registry.try_get<UIBoxComponent>(*uiConfig->object))
                    objectType = "UIBox";
                else if (registry.try_get<TextSystem::Text>(*uiConfig->object)) {
                    objectType = "Text";
                    // print LOC, OFF, and OFF_ALN for text objects
                    boxStr += fmt::format(" MovingText({})--[LOC({},{}) OFF({},{}) OFF_ALN({},{}) MSTR({}) DIMS({},{})]",
                        static_cast<int>(uiConfig->object.value()),
                        static_cast<int>(objTransform->getActualX()),
                        static_cast<int>(objTransform->getActualY()),
                        static_cast<int>(objectRole->offset->x),
                        static_cast<int>(objectRole->offset->y),
                        static_cast<int>(objectRole->flags->extraAlignmentFinetuningOffset.x),
                        static_cast<int>(objectRole->flags->extraAlignmentFinetuningOffset.y),
                        static_cast<int>(objectRole->master),
                        static_cast<int>(objTransform->getActualW()),
                        static_cast<int>(objTransform->getActualH())
                    
                    );
                }
                else if (registry.try_get<AnimationQueueComponent>(*uiConfig->object)) {
                    objectType = "AnimatedSprite";
                    // print LOC, OFF, and OFF_ALN for animated sprite objects
                    boxStr += fmt::format(" AnimQueue({})--[LOC({},{}) OFF({},{}) OFF_ALN({},{}) MSTR({})]",
                        static_cast<int>(uiConfig->object.value()),
                        static_cast<int>(objTransform->getActualX()),
                        static_cast<int>(objTransform->getActualY()),
                        static_cast<int>(objectRole->offset->x),
                        static_cast<int>(objectRole->offset->y),
                        static_cast<int>(objectRole->flags->extraAlignmentFinetuningOffset.x),
                        static_cast<int>(objectRole->flags->extraAlignmentFinetuningOffset.y),
                        static_cast<int>(objectRole->master));
                }
                else if (registry.try_get<InventoryGrid>(*uiConfig->object)) {
                    objectType = "InventoryGrid";
                    // print LOC, OFF, and OFF_ALN for animated sprite objects
                    boxStr += fmt::format(" InventoryGrid({})--[LOC({},{}) OFF({},{}) OFF_ALN({},{}) MSTR({})]",
                        static_cast<int>(uiConfig->object.value()),
                        static_cast<int>(objTransform->getActualX()),
                        static_cast<int>(objTransform->getActualY()),
                        static_cast<int>(objectRole->offset->x),
                        static_cast<int>(objectRole->offset->y),
                        static_cast<int>(objectRole->flags->extraAlignmentFinetuningOffset.x),
                        static_cast<int>(objectRole->flags->extraAlignmentFinetuningOffset.y),
                        static_cast<int>(objectRole->master));
                }
                
                
                    
                // else if (registry.try_get<Particles>(*uiConfig->object)) objectType = "Particles";
                // else if (registry.try_get<AnimatedSprite>(*uiConfig->object)) objectType = "AnimatedSprite";
            }
            
            

            boxStr += " OBJ: " + objectType;
            
            
        }
        // If this is a Text UI element (UIT == "T"), include the text content
        else if (uiElement->UIT == UITypeEnum::TEXT)
        {
            boxStr += " TEXT: " + (uiConfig->text ? *uiConfig->text : "REF");
        }
        
        if (registry.try_get<transform::TreeOrderComponent>(*uiConfig->object))
            boxStr += fmt::format(" TreeOrder: {}",
            registry.get<transform::TreeOrderComponent>(*uiConfig->object).order);
            
        if (registry.try_get<layer::LayerOrderComponent>(*uiConfig->object))
            boxStr += fmt::format(" LayerOrder: {}",
            registry.get<layer::LayerOrderComponent>(*uiConfig->object).zIndex);

        //  Recursively print child elements with increased indentation
        for (auto childEntry : node->orderedChildren)
        {
            auto child = childEntry;
            boxStr += DebugPrintTree(registry, child, indent + 1);
        }

        return boxStr;
    }

    void element::InitializeVisualTransform(entt::registry &registry, entt::entity entity)
    {
        // Ensure entity is valid
        if (!registry.valid(entity))
            return;

        // Retrieve UIElement, Config, and Transform components
        auto *uiElement = registry.try_get<UIElementComponent>(entity);
        auto *uiConfig = registry.try_get<UIConfig>(entity);
        auto *transform = registry.try_get<transform::Transform>(entity);
        auto *uiState = registry.try_get<UIState>(entity);
        auto *node = registry.try_get<transform::GameObject>(entity);

        // Ensure required components exist
        AssertThat(uiElement, Is().Not().EqualTo(nullptr));
        AssertThat(uiConfig, Is().Not().EqualTo(nullptr));
        AssertThat(transform, Is().Not().EqualTo(nullptr));
        AssertThat(uiState, Is().Not().EqualTo(nullptr));

        // STEP 1: Align with major parent
        transform::MoveWithMaster(entity, 0, *transform, registry.get<transform::InheritedProperties>(entity), *node);
        transform::UpdateParallaxCalculations(&registry, entity);

        // STEP 3: Recursively initialize all child elements
        for (auto childEntry : node->orderedChildren)
        {
            auto child = childEntry;
            InitializeVisualTransform(registry, child);
        }

        // STEP 4: Copy width & height from actual transform (`T`) to visual transform (`VT`)
        transform->setActualW(transform->getActualW());
        transform->setActualH(transform->getActualH());

        // STEP 5: If this is a TEXT UI element, update its text
        if (uiElement->UIT == UITypeEnum::TEXT)
        {
            UpdateText(registry, entity, uiConfig, uiState);
        }

        // STEP 6: Sync the transform of an associated object (if any)
        if (uiConfig->object)
        {
            auto objectEntity = uiConfig->object.value();

            auto *objectTransform = registry.try_get<transform::Transform>(objectEntity);
            auto *objectRole = registry.try_get<transform::InheritedProperties>(objectEntity);
            auto *objectNode = registry.try_get<transform::GameObject>(objectEntity);

            // TODO: so objects have node parents to be the ui element it is associated with?
            if (!uiConfig->noRole)
            {
                transform::SnapTransformValues(&registry, objectEntity, transform->getActualX(), transform->getActualY(), transform->getActualW(), transform->getActualH());
                transform::MoveWithMaster(objectEntity, 0, *objectTransform, *objectRole, *objectNode);
                objectRole->flags->prevAlignment = transform::InheritedProperties::Alignment::NONE;
                transform::AlignToMaster(&registry, objectEntity);
            }

            // STEP 7: If the associated object needs to recalculate, trigger its recalculate function
            if (objectNode && uiConfig->objectRecalculate)
            {
                // must be uibox, since recalc only works for uibox
                auto *objectUIBox = registry.try_get<UIBoxComponent>(objectEntity);
                if (objectUIBox) box::Recalculate(registry, objectEntity);                
            }
        }
    }

    void element::JuiceUp(entt::registry &registry, entt::entity entity, float amount, float rot_amt)
    {
        // Retrieve UIElement and Config components
        auto *uiElement = registry.try_get<UIElementComponent>(entity);
        auto *uiConfig = registry.try_get<UIConfig>(entity);
        auto *transform = registry.try_get<transform::Transform>(entity);

        AssertThat(uiElement, Is().Not().EqualTo(nullptr));
        AssertThat(uiConfig, Is().Not().EqualTo(nullptr));
        AssertThat(transform, Is().Not().EqualTo(nullptr));

        // If this UI element represents an OBJECT (UIT.O), delegate to the associated object
        if (uiElement->UIT == UITypeEnum::OBJECT && uiConfig->object)
        {
            entt::entity objectEntity = uiConfig->object.value();
            auto *objectTransform = registry.try_get<transform::Transform>(objectEntity);
            if (objectTransform)
            {
                // TODO: allow for per-object juicing (different amounts for different objects, or maybe just std::fucntion for juicing children selectively, etc.)
                transform::InjectDynamicMotion(&registry, objectEntity, amount, rot_amt);
            }
            return;
        }
    }
    
    std::optional<entt::entity> element::CanBeDragged(entt::registry &registry, entt::entity entity)
    {
        // Retrieve UIElementComponent and UIConfig
        auto *uiElement = registry.try_get<UIElementComponent>(entity);
        auto *uiConfig = registry.try_get<UIConfig>(entity);
        auto *node = registry.try_get<transform::GameObject>(entity);

        AssertThat(uiElement, Is().Not().EqualTo(nullptr));
        AssertThat(uiConfig, Is().Not().EqualTo(nullptr));
        AssertThat(node, Is().Not().EqualTo(nullptr));

        // Step 1: Check if the element itself can be dragged
        if (node->state.dragEnabled)
        {
            return entity;
        }

        // Step 2: Defer to the parent UIBox
        // uiConfig->parent is the parent UIElement
        auto uiBox = uiElement->uiBox;
        // no can_drag metod for uibox, revert to node
        auto uiBoxNode = registry.try_get<transform::GameObject>(uiBox);
        if (uiBoxNode && uiBoxNode->state.dragEnabled)
        {
            return uiBox;
        }
        return std::nullopt; // No draggable element found
    }

    void element::buildUIDrawList(entt::registry &registry,
                         entt::entity root,
                         std::vector<UIDrawListItem> &out,
                         int depth)
    {
        // Pull exactly the same pointers you had in DrawChildren:
        auto *node = registry.try_get<transform::GameObject>(root);
        auto *uiConfig = registry.try_get<UIConfig>(root);
        
        // return if not active state.
        if (entity_gamestate_management::isEntityActive(root) == false) {
            return;
        }

        // If the node isn’t a UI element or isn’t visible, skip its entire subtree
        if (!node || !uiConfig || !node->state.visible)
            return;

        // Iterate children in the same order you did before:
        for (auto child : node->orderedChildren)
        {
            auto *childConfig = registry.try_get<UIConfig>(child);
            auto *childNode = registry.try_get<transform::GameObject>(child);

            if (!childConfig || !childNode)
                continue;

            // Skip elements that use drawLayer or have special names:
            if (childConfig->drawLayer || childConfig->id == "h_popup" || childConfig->id == "alert")
            {
                continue;
            }

            // “Pre‐draw” if draw_after == false
            if (!childConfig->draw_after)
            {
                out.push_back({.e = child, .depth = depth});
            }

            // Recurse into grandchildren
            buildUIDrawList(registry, child, out, depth + 1);

            // “Post‐draw” if draw_after == true
            if (childConfig->draw_after)
            {
                out.push_back({.e = child, .depth = depth});
            }
        }
    }

    // void element::DrawChildren(std::shared_ptr<layer::Layer> layerPtr, entt::registry &registry, entt::entity entity)
    // {

    //     auto *uiElement = registry.try_get<UIElementComponent>(entity);
    //     auto *uiConfig = registry.try_get<UIConfig>(entity);
    //     auto *node = registry.try_get<transform::GameObject>(entity);

    //     AssertThat(uiElement, Is().Not().EqualTo(nullptr));
    //     AssertThat(uiConfig, Is().Not().EqualTo(nullptr));
    //     AssertThat(node, Is().Not().EqualTo(nullptr));

    //     // If element (node) is not visible, skip drawing
    //     if (!node->state.visible)
    //         return;

    //     for (auto childEntry : node->orderedChildren)
    //     {
    //         auto child = childEntry;
    //         auto *childConfig = registry.try_get<UIConfig>(child);
    //         if (!childConfig)
    //             continue;

    //         // Skip elements with a `draw_layer` or special names

    //         // TODO: document h_popup and alert?
    //         // TODO: ensure that config->id is always set (to value in children map?)
    //         if (childConfig->drawLayer || childConfig->id == "h_popup" || childConfig->id == "alert")
    //             continue;

    //         // Draw first if `draw_after` is false
    //         if (!childConfig->draw_after)
    //         {
    //             DrawSelf(layerPtr, registry, child);
    //         }

    //         // Recursively draw children
    //         DrawChildren(layerPtr, registry, child);

    //         // Draw again if `draw_after` is true
    //         if (childConfig->draw_after)
    //         {
    //             DrawSelf(layerPtr, registry, child);
    //         }
    //     }
    // }

    auto createTooltipUIBox(entt::registry &registry, entt::entity parent, ui::Tooltip tooltip) -> UIElementTemplateNode {

        ui::UIElementTemplateNode title = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::TEXT)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addText(tooltip.title.value_or("Tooltip Title"))
                    .addColor(WHITE)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .addFontName("tooltip")
                    .addScale(0.4f)
                    .build())
            .build();
        ui::UIElementTemplateNode content = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::TEXT)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addText(tooltip.text.value_or("Tooltip Content"))
                    .addColor(WHITE)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .addFontName("tooltip")
                    .addScale(0.4f)
                    .build())
            .build();

        ui::UIElementTemplateNode titleRow = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(WHITE)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .addChild(title)
            .build();

        ui::UIElementTemplateNode contentRow = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(WHITE)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                    .build())
            .addChild(content)
            .build();


        ui::UIElementTemplateNode tooltipUIBoxDef = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::ROOT)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addColor(WHITE)
                    .addOutlineThickness(2.0f)
                    .addOutlineColor(BLUE)
                    .build())
            .addChild(titleRow)
            .addChild(contentRow)
            .build();

        return tooltipUIBoxDef;
    }

    std::pair<float, float> element::SetWH(entt::registry &registry, entt::entity entity)
    {
        auto *uiElement = registry.try_get<UIElementComponent>(entity);
        auto *uiConfig = registry.try_get<UIConfig>(entity);
        auto *node = registry.try_get<transform::GameObject>(entity);
        auto *transform = registry.try_get<transform::Transform>(entity);

        AssertThat(uiElement, Is().Not().EqualTo(nullptr));
        AssertThat(uiConfig, Is().Not().EqualTo(nullptr));
        AssertThat(node, Is().Not().EqualTo(nullptr));
        AssertThat(transform, Is().Not().EqualTo(nullptr));

        float padding = uiConfig->effectivePadding();
        float max_w = 0.f, max_h = 0.f;

        // If no children or `no_fill` is true, return current size
        if (node->children.empty() || uiConfig->noFill)
        {
            return {transform->getActualW(), transform->getActualH()};
        }

        // Iterate through children to find max width and height
        for (auto childEntry : node->children)
        {
            auto child = childEntry.second;
            if (!registry.valid(child))
                continue;

            auto [child_w, child_h] = SetWH(registry, child);

            if (child_w && child_h)
            {
                if (child_w > max_w)
                    max_w = child_w;
                if (child_h > max_h)
                    max_h = child_h;
            }
            else
            {
                max_w = padding;
                max_h = padding;
            }
        }

        // Adjust width and height for ROWS and COLUMNS
        for (auto childEntry : node->children)
        {
            auto child = childEntry.second;
            auto *childConfig = registry.try_get<UIConfig>(child);
            if (!childConfig)
                continue;

            if (childConfig->uiType == UITypeEnum::HORIZONTAL_CONTAINER)
            {
                transform->setActualW(max_w);
            }
            if (childConfig->uiType == UITypeEnum::VERTICAL_CONTAINER)
            {
                transform->setActualH(max_h);
            }
        }

        return {transform->getActualW(), transform->getActualH()};
    }

    void element::ApplyScalingFactorToSizesInSubtree(entt::registry &registry, entt::entity rootEntity, float scaling) 
    {
        struct StackEntry {
            entt::entity entity;
        };

        AssertThat(scaling > 0, Is().EqualTo(true));

        std::vector<StackEntry> processingOrder;
        std::stack<StackEntry> stack;
        stack.push({rootEntity});

        // Step 1: Collect nodes in top-down order (DFS)
        while (!stack.empty()) 
        {
            auto entry = stack.top();
            stack.pop();
            processingOrder.push_back(entry);

            auto *node = registry.try_get<transform::GameObject>(entry.entity);
            if (!node) continue;

            // Push children onto stack (this ensures DFS order)
            for (auto childEntry : node->orderedChildren) 
            {
                auto child = childEntry;
                if (registry.valid(child)) 
                {
                    stack.push({child});
                }
            }
        }

        // Step 2: Process nodes in bottom-up order (ensuring child elements are always processed before parents)
        for (auto it = processingOrder.rbegin(); it != processingOrder.rend(); ++it) 
        {
            auto [entity] = *it;
            auto *role = registry.try_get<transform::InheritedProperties>(entity);
            auto *node = registry.try_get<transform::GameObject>(entity);
            auto *uiElement = registry.try_get<UIElementComponent>(entity);
            auto *transform = registry.try_get<transform::Transform>(entity);
            auto *uiState = registry.try_get<UIState>(entity);
            auto *uiConfig = registry.try_get<UIConfig>(entity);

            if (!role || !node || !uiElement || !transform || !uiState || !uiConfig) continue;

            // SPDLOG_DEBUG("Applying scaling factor to entity {} with initial width: {}, height: {}, content dimensions: {}, scale: {}",
            //             static_cast<int>(entity), transform->getActualW(), transform->getActualH(), uiState->contentDimensions->x, uiConfig->scale.value_or(1.0f));

            transform->setActualW(transform->getActualW() * scaling);
            transform->setActualH(transform->getActualH() * scaling);
            uiState->contentDimensions = {transform->getActualW(), transform->getActualH()};
            uiConfig->scale = uiConfig->scale.value_or(1.0f) * scaling;

            //TODO: custom code for text, object, etc. which need special handling for scaling
            
            if (uiConfig->object)
            {
                UpdateUIObjectScalingAndRecnter(uiConfig, uiConfig->scale.value(), transform);
            }

            // SPDLOG_DEBUG("Applying scaling factor to entity {} resulted in width: {}, height: {}, content dimensions: {}, scale: {}",
            //             static_cast<int>(entity), transform->getActualW(), transform->getActualH(), uiState->contentDimensions->x, uiConfig->scale.value_or(1.0f));
        }
    }

    void element::UpdateUIObjectScalingAndRecnter(ui::UIConfig *uiConfig, float newScale, transform::Transform *transform)
    {
        auto objectEntity = uiConfig->object.value();

        // is it text?
        if (globals::getRegistry().any_of<TextSystem::Text>(objectEntity))
        {
            TextSystem::Functions::setTextScaleAndRecenter(objectEntity, newScale, transform->getActualW(), transform->getActualH(), true, true);
        }
        else if (globals::getRegistry().any_of<AnimationQueueComponent>(objectEntity))
        {
            // FIXME: this isn't working.
            animation_system::resizeAnimationObjectsInEntityToFitAndCenterUI(objectEntity, transform->getActualW(), transform->getActualH());
        }
    }

    void element::ApplyAlignment(entt::registry &registry, entt::entity rootEntity, float offsetX, float offsetY) 
    {
        struct StackEntry {
            entt::entity entity;
            float x, y;
        };

        std::vector<StackEntry> processingOrder;
        std::stack<StackEntry> stack;
        stack.push({rootEntity, offsetX, offsetY});

        // Step 1: Collect nodes in top-down order (DFS)
        while (!stack.empty()) 
        {
            auto entry = stack.top();
            stack.pop();
            processingOrder.push_back(entry);

            auto *node = registry.try_get<transform::GameObject>(entry.entity);
            if (!node) continue;

            // Push children onto stack (this ensures DFS order)
            for (auto childEntry : node->orderedChildren) 
            {
                auto child = childEntry;
                if (registry.valid(child)) 
                {
                    stack.push({child, entry.x, entry.y});
                }
            }
        }

        // Step 2: Process nodes in bottom-up order (ensuring child elements are always processed before parents)
        for (auto it = processingOrder.rbegin(); it != processingOrder.rend(); ++it) 
        {
            auto [entity, x, y] = *it;
            auto *role = registry.try_get<transform::InheritedProperties>(entity);
            auto *node = registry.try_get<transform::GameObject>(entity);
            auto *uiElement = registry.try_get<UIElementComponent>(entity);

            if (!role || !node || !uiElement) continue;

            // Adjust alignment offset
            role->offset->x += x;
            role->offset->y += y;

            // SPDLOG_DEBUG("Applying alignment to entity {} with x: {}, y: {}, resulted in offset x: {}, y: {}. This entity has {} children.",
            //             static_cast<int>(entity), x, y, role->offset->x, role->offset->y, node->children.size());
        }
    }
 
    void element::SetAlignments(entt::registry &registry, entt::entity rootEntity, std::optional<Vector2> uiBoxOffset, bool rootEntityFlag)
    {
        struct StackEntry {
            entt::entity entity;
            std::optional<Vector2> uiBoxOffset;
            bool isRoot;
        };

        std::vector<StackEntry> processingOrder;
        std::stack<StackEntry> stack;
        stack.push({rootEntity, uiBoxOffset, rootEntityFlag});

        // Step 1: Collect nodes in top-down order (DFS)
        while (!stack.empty()) 
        {
            auto entry = stack.top();
            stack.pop();
            processingOrder.push_back(entry);

            auto *node = registry.try_get<transform::GameObject>(entry.entity);
            if (!node) continue;

            // Push children onto stack (DFS order)
            for (auto childEntry : node->orderedChildren) 
            {
                auto child = childEntry;
                if (registry.valid(child)) 
                {
                    stack.push({child, entry.uiBoxOffset, false});
                }
            }
        }

        // Step 2: Process nodes in bottom-up order (ensuring child elements are always processed before parents)
        for (auto it = processingOrder.rbegin(); it != processingOrder.rend(); ++it) 
        {
            auto [entity, uiBoxOffset, isRoot] = *it;

            auto *config = registry.try_get<UIConfig>(entity);
            auto *node = registry.try_get<transform::GameObject>(entity);
            auto *transform = registry.try_get<transform::Transform>(entity);

            AssertThat(config, Is().Not().EqualTo(nullptr));
            AssertThat(node, Is().Not().EqualTo(nullptr));
            AssertThat(transform, Is().Not().EqualTo(nullptr));

            float padding = config->effectivePadding();

            //TODO: this should probably only be added to the offsets once every tree?
            float uiBoxOffsetX = (uiBoxOffset.has_value() && isRoot) ? uiBoxOffset->x : 0;
            float uiBoxOffsetY = (uiBoxOffset.has_value() && isRoot) ? uiBoxOffset->y : 0;

            // Iterate over children
            for (auto childEntry : node->orderedChildren)
            {
                auto child = childEntry;
                auto *childConfig = registry.try_get<UIConfig>(child);
                auto *childTransform = registry.try_get<transform::Transform>(child);
                auto *childUIState = registry.try_get<UIState>(child);

                AssertThat(childConfig, Is().Not().EqualTo(nullptr));
                AssertThat(childTransform, Is().Not().EqualTo(nullptr));
                AssertThat(childUIState, Is().Not().EqualTo(nullptr));

                // Apply vertical alignment
                if (config->alignmentFlags && *config->alignmentFlags & transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                {
                    if (childConfig->uiType == UITypeEnum::TEXT ||
                        childConfig->uiType == UITypeEnum::RECT_SHAPE ||
                        childConfig->uiType == UITypeEnum::OBJECT ||
                        childConfig->uiType == UITypeEnum::INPUT_TEXT)
                    {
                        ApplyAlignment(registry, child, 0 + uiBoxOffsetX, 0.5f * (transform->getActualH() - 2 * padding - childTransform->getActualH())+ uiBoxOffsetY);
                    }
                    else
                    {
                        ApplyAlignment(registry, child, 0+ uiBoxOffsetX, 0.5f * (transform->getActualH() - childUIState->contentDimensions->y)+ uiBoxOffsetY);
                    }
                }

                // Apply horizontal alignment
                if (config->alignmentFlags && *config->alignmentFlags & transform::InheritedProperties::Alignment::HORIZONTAL_CENTER)
                {
                    ApplyAlignment(registry, child, 0.5f * (transform->getActualW() - childUIState->contentDimensions->x)+ uiBoxOffsetX, 0+ uiBoxOffsetY);
                }

                // Apply bottom alignment
                if (config->alignmentFlags && *config->alignmentFlags & transform::InheritedProperties::Alignment::VERTICAL_BOTTOM)
                {
                    ApplyAlignment(registry, child, 0+ uiBoxOffsetX, transform->getActualH() - childUIState->contentDimensions->y+ uiBoxOffsetY);
                }

                // Apply right alignment 
                if (config->alignmentFlags && *config->alignmentFlags & transform::InheritedProperties::Alignment::HORIZONTAL_RIGHT)
                {
                    ApplyAlignment(registry, child, transform->getActualW() - childUIState->contentDimensions->x+ uiBoxOffsetX, 0+ uiBoxOffsetY);
                }

                // // if no alignment, just apply uibox offset to align it relative to uibox
                // if (!config->alignmentFlags || config->alignmentFlags == transform::InheritedProperties::Alignment::NONE)
                // {
                //     ApplyAlignment(registry, child, uiBoxOffsetX, uiBoxOffsetY);
                // }
            }
        }
    }
    
    //Updates for UITYpeEnum::TEXT elements (different from dynamic text objects)
    void element::UpdateText(entt::registry &registry, entt::entity entity, UIConfig *config, UIState *state)
    {

        if (!config->text.has_value())
            return;
        if (!state)
            return;

        // Ensure text drawable exists
        if (!state->textDrawable)
        {
            if (!config->language)
                config->language = globals::language;
            // TODO: set text drawable text here
            //  self.config.text_drawable = love.graphics.newText(self.config.lang.font.FONT, {G.C.WHITE,self.config.text})
            //  state->textDrawable = std::make_optional<std::string>(config->text.value());
        }

        // Check if the text needs updating from reference table
        if (config->ref_entity && config->ref_component && config->ref_value)
        {

            auto comp = reflection::retrieveComponent(&registry, config->ref_entity.value(), config->ref_component.value());
            auto value = reflection::retrieveFieldByString(comp, config->ref_component.value(), config->ref_value.value());
            if (value != config->prev_ref_value)
            {
                // Convert variant to string and update text
                config->text = reflection::meta_any_to_string(value);
                // TODO: update text drawable's text here
                //  *state->textDrawable = config->text.value();

                // If text length changed and recalculation is allowed, trigger UI recalculation
                if (!config->no_recalc && config->prev_ref_value && reflection::meta_any_to_string(config->prev_ref_value).size() != config->text->size())
                {
                    //TODO: doesn't this  need to be a uibox?
                    ui::box::RenewAlignment(registry, entity);
                }

                // Store updated text
                config->prev_ref_value = value;
            }
        }
        else if (config->textGetter)
        {
            auto result = config->textGetter.value()();
            // compare to text getter
            if (config->text != result)
            {
                config->text = result;
                // renew alignment if text changed
                
                ui::box::RenewAlignment(registry, entity);
            }
        }
    }

    void element::UpdateObject(entt::registry &registry, entt::entity entity, UIConfig *elementConfig, transform::GameObject *elementNode, UIConfig *objectConfig, transform::Transform *objectTransform, transform::InheritedProperties *objectRole, 
                               transform::GameObject *objectNode)
    {
        ZONE_SCOPED("UI Element: UpdateObject");
        // auto *config = registry.try_get<UIConfig>(entity);

        // AssertThat(config, Is().Not().EqualTo(nullptr));

        // Step 1: Update the object reference if it has changed
        if (elementConfig->ref_component && elementConfig->ref_value)
        {
            auto comp = reflection::retrieveComponent(&registry, elementConfig->ref_entity.value(), elementConfig->ref_component.value());
            auto value = reflection::retrieveFieldByString(comp, elementConfig->ref_component.value(), elementConfig->ref_value.value());
            if (value != elementConfig->prev_ref_value)
            {
                elementConfig->object = value.cast<entt::entity>();
                ui::box::Recalculate(registry, entity);
            }
        }

        // Step 2: Ensure object exists before proceeding
        if (!elementConfig->object)
            return;

        // auto *objectConfig = registry.try_get<UIConfig>(config->object.value());
        // auto *objectNode = registry.try_get<transform::GameObject>(config->object.value());
        // auto *objectRole = registry.try_get<transform::InheritedProperties>(config->object.value());
        // auto *objectTransform = registry.try_get<transform::Transform>(config->object.value());

        // if (!objectConfig) {
        //     //FIXME: just emplace once
        //     objectConfig = &registry.emplace<UIConfig>(elementConfig->object.value());
        //     // SPDLOG_ERROR("Object {} does not exist or is missing components.", static_cast<int>(config->object.value()));
        // }

        // Step 3: Refresh object movement state
        objectConfig->refreshMovement = true;

        // Step 4: Handle hover state synchronization
        // auto *elementNode = registry.try_get<transform::GameObject>(entity);

        if (objectNode->state.isBeingHovered && !elementNode->state.isBeingHovered)
        {
            ApplyHover(registry, entity);
            elementNode->state.isBeingHovered = true;
        }
        if (!objectNode->state.isBeingHovered && elementNode->state.isBeingHovered)
        {
            StopHover(registry, entity);
            elementNode->state.isBeingHovered = false;
        }
        
        // is the object text?
        if (globals::getRegistry().any_of<TextSystem::Text>(elementConfig->object.value()) && objectConfig->textGetter)
        {
            auto &text = globals::getRegistry().get<TextSystem::Text>(elementConfig->object.value());
            
            auto result = objectConfig->textGetter.value()();
            // compare to text getter
            if (text.rawText != result)
            {
                TextSystem::Functions::setText(elementConfig->object.value(), result);
            }
        }

        // Step 5: Handle object updates
        if (objectConfig->ui_object_updated)
        {
            ZONE_SCOPED("UI Element: UpdateObject - Object Updated");
            objectConfig->ui_object_updated = false;

            objectConfig->parent = entity;

            // Assign role
            if (elementConfig->role)
            {
                // this is probably not called usually
                transform::AssignRole(&registry, elementConfig->object.value(), elementConfig->role->role_type, elementConfig->role->master, elementConfig->role->location_bond, elementConfig->role->size_bond, elementConfig->role->rotation_bond, elementConfig->role->scale_bond, elementConfig->role->offset);
            }
            else
            {
                transform::AssignRole(&registry, elementConfig->object.value(), transform::InheritedProperties::Type::RoleInheritor, entity);
            }

            // Move object relative to parent
            transform::MoveWithMaster(elementConfig->object.value(), 0, *objectTransform, *objectRole, *objectNode);

            // Adjust parent dimensions & alignments
            if (objectConfig->non_recalc)
            { // TODO: there is also no_recalc. what is the difference?
                ZONE_SCOPED("UI Element: UpdateObject - Non Recalc");
                auto *uiElement = registry.try_get<UIElementComponent>(entity);
                auto *node = registry.try_get<transform::GameObject>(entity);
                auto parent = node->parent.value();

                auto *parentConfig = registry.try_get<UIConfig>(parent);
                auto *parentUIState = registry.try_get<UIState>(parent);
                auto *parentTransform = registry.try_get<transform::Transform>(parent);

                parentUIState->contentDimensions->x = objectTransform->getActualW();

                auto uiBox = uiElement->uiBox;
                auto *uiBoxRole = registry.try_get<transform::InheritedProperties>(uiBox);

                ApplyAlignment(registry, entity,
                               parentTransform->getActualX() - objectTransform->getActualX(), parentTransform->getActualY() - objectTransform->getActualY());
                SetAlignments(registry, parent, uiBoxRole->offset);
            }
            else
            {
                ZONE_SCOPED("UI Element: UpdateObject - Recalculate");
                auto *uiElement = registry.try_get<UIElementComponent>(entity);

                ui::box::RenewAlignment(registry, uiElement->uiBox);
            }
        }
    }
    
    void element::DrawSelfImmediate(std::shared_ptr<layer::Layer> layerPtr, entt::entity entity, UIElementComponent &uiElementComp, UIConfig &configComp, UIState &stateComp, transform::GameObject &nodeComp, transform::Transform &transformComp)
    {
        // check validity and bail
        if (!layerPtr)
            return;
        if (!globals::getRegistry().valid(entity))
            return;
        if (entity == entt::null)
            return;
        
        ZONE_SCOPED("UI Element: DrawSelf");
        auto *uiElement = &uiElementComp;
        auto *config = &configComp;
        auto *state = &stateComp;
        auto *node =  &nodeComp;
        auto *transform =  &transformComp;
        auto *rectCache = globals::getRegistry().try_get<RoundedRectangleVerticesCache>(entity);
        const auto& fontData = resolveFontData(config);

        AssertThat(uiElement, Is().Not().EqualTo(nullptr));
        AssertThat(config, Is().Not().EqualTo(nullptr));
        AssertThat(state, Is().Not().EqualTo(nullptr));
        AssertThat(node, Is().Not().EqualTo(nullptr));
        AssertThat(transform, Is().Not().EqualTo(nullptr));
        
        auto actualX = transform->getActualX();
        auto actualY = transform->getActualY();
        auto actualW = transform->getActualW();
        auto actualH = transform->getActualH();
        auto visualW = transform->getVisualW();
        auto visualH = transform->getVisualH();
        auto visualX = transform->getVisualX();
        auto visualY = transform->getVisualY();
        auto visualScaleWithHoverAndMotion = transform->getVisualScaleWithHoverAndDynamicMotionReflected();
        auto visualR = transform->getVisualRWithDynamicMotionAndXLeaning();
        auto rotationOffset = transform->rotationOffset;

        // Check if element should be drawn
        if (!node->state.visible)
        {
            if (config->force_focus)
            {
                // LATER: what would be an equivalent for a draw hash in entt? perhaps not necessary?
                //  addToDrawHash(entity);
            }
            return;
        }

        if (config->force_focus || config->forceCollision || config->button_UIE || config->buttonCallback || node->state.collisionEnabled)
        {
            // TODO: what does addToDrawHash do?
            // LATER: what would be an equivalent for a draw hash in entt? perhaps not necessary?
            //  addToDrawHash(entity);
        }

        bool buttonActive = true;
        float parallaxDist = 1.2f; // parallax empahsis
        bool buttonBeingPressed = false;

        // Is it a button?
        if (config->buttonCallback || config->button_UIE)
        {
            ZONE_SCOPED("UI Element: Button Logic");
            auto parentEntity = node->parent.value();
            Vector2 parentParallax = {0, 0};

            auto *parentElement = globals::getRegistry().try_get<UIElementComponent>(parentEntity);
            auto *parentNode = globals::getRegistry().try_get<transform::GameObject>(parentEntity);

            float parentLayerX = (globals::getRegistry().valid(parentEntity) && parentEntity != uiElement->uiBox) ? parentNode->layerDisplacement->x : 0;
            float parentLayerY = (globals::getRegistry().valid(parentEntity) && parentEntity != uiElement->uiBox) ? parentNode->layerDisplacement->y : 0;

            float shadowOffsetX = (config->shadow ? 0.4f * node->shadowDisplacement->x : 0) ;
            float shadowOffsetY = (config->shadow ? 0.4f * node->shadowDisplacement->y : 0) ;

            // node->layerDisplacement->x = parentLayerX + shadowOffsetX;
            // node->layerDisplacement->y = parentLayerY + shadowOffsetY;
            
            node->layerDisplacement->x = parentLayerX;
            node->layerDisplacement->y = parentLayerY;

            // This code applies a parallax effect to the button when it is clicked, hovered, or dragged while the cursor is down. The button moves slightly in the direction of its shadow displacement, giving a depth effect, and it resets parallaxDist to avoid continuous movement.
            if (config->buttonCallback && ((state->last_clicked && state->last_clicked.value() > main_loop::mainLoop.realtimeTimer - 0.1f) || ((config->buttonCallback && (node->state.isBeingHovered || node->state.isBeingDragged)))) && globals::getInputState().is_cursor_down)
            {

                node->layerDisplacement->x -= parallaxDist * node->shadowDisplacement->x;
                node->layerDisplacement->y -= parallaxDist * 1.8f * node->shadowDisplacement->y;
                parallaxDist = 0;
                buttonBeingPressed = true;
                
                // SPDLOG_DEBUG("Button being pressed: {}, setting layer displacement to x: {}, y: {}", buttonBeingPressed, node->layerDisplacement->x, node->layerDisplacement->y);
            }
        }
        // is it text?
        if (config->uiType == UITypeEnum::TEXT && config->scale)
        {
            ZONE_SCOPED("UI Element: Text Logic");
            float rawScale = config->scale.value() * fontData.fontScale;
            float scaleFactor = std::clamp(1.0f / (rawScale * rawScale), 0.01f, 1.0f); // tunable clamp
            float textParallaxSX = node->shadowDisplacement->x * fontData.fontLoadedSize * 0.04f * scaleFactor;
            float textParallaxSY = node->shadowDisplacement->y * fontData.fontLoadedSize * -0.03f * scaleFactor;
            
            //TODO: if scale is smaller, make the shadow height smaller too

            bool drawShadow = (config->button_UIE && buttonActive) || (!config->button_UIE && config->shadow && globals::getSettings().shadowsOn);

            if (drawShadow)
            {
                layer::PushMatrix();
                
                Vector2 layerDisplacement = {node->layerDisplacement->x, node->layerDisplacement->y};
                layer::Translate(actualX + textParallaxSX + layerDisplacement.x, actualY + textParallaxSY + layerDisplacement.y);
                
                if (config->verticalText)
                {
                    // layer::QueueCommand<layer::CmdTranslate>(layerPtr, [x = 0, y = actualH](layer::CmdTranslate *cmd) {
                    //     cmd->x = x;
                    //     cmd->y = y;
                    // }, zIndex);
                    layer::Translate(0, actualH);
                    // layer::QueueCommand<layer::CmdRotate>(layerPtr, [rotation = -PI / 2](layer::CmdRotate *cmd) {
                    //     cmd->angle = rotation;
                    // }, zIndex);
                    layer::Rotate(-PI / 2);
                }
                if ((config->shadow || (config->button_UIE && buttonActive)) && globals::getSettings().shadowsOn)
                {
                    Color shadowColor = Color{0, 0, 0, static_cast<unsigned char>(config->color->a * 0.3f)};

                    float textX = fontData.fontRenderOffset.x + (config->verticalText ? textParallaxSY : textParallaxSX) * config->scale.value_or(1.0f) * fontData.fontScale;
                    float textY = fontData.fontRenderOffset.y + (config->verticalText ? textParallaxSX : textParallaxSY) * config->scale.value_or(1.0f) * fontData.fontScale;
                    float fontScale = config->scale.value_or(1.0f) * fontData.fontScale;
                    float spacing = config->textSpacing.value_or(fontData.spacing);   

                    float scale = config->scale.value_or(1.0f) * fontData.fontScale * globals::getGlobalUIScaleFactor();
                    // layer::QueueCommand<layer::CmdScale>(layerPtr, [scale = scale](layer::CmdScale *cmd) {
                    //     cmd->scaleX = scale;
                    //     cmd->scaleY = scale;
                    // }, zIndex);
                    layer::Scale(scale, scale);
                    
                    // layer::QueueCommand<layer::CmdTextPro>(layerPtr, [text = config->text.value(), font = localization::getFontData().font, textX, textY, spacing, shadowColor](layer::CmdTextPro *cmd) {
                    //     cmd->text = text.c_str();
                    //     cmd->font = font;
                    //     cmd->x = textX;
                    //     cmd->y = textY;
                    //     cmd->origin = {0, 0};
                    //     cmd->rotation = 0;
                    //     cmd->fontSize = fontData.fontLoadedSize;
                    //     cmd->spacing = spacing;
                    //     cmd->color = shadowColor;
                    // }, zIndex);
                    float fontSize = config->fontSize.has_value() ? config->fontSize.value() : fontData.fontLoadedSize;
                    layer::TextPro(config->text.value().c_str(), fontData.font, textX, textY, {0, 0}, 0, fontSize, spacing, shadowColor);
                    
                    // text offset and spacing and fontscale are configurable values that are added to font rendering (scale changes font scaling), squish also does this (ussually 1), and offset is different for different font types. render_scale is the size at which the font is initially loaded.
                }

                // layer::QueueCommand<layer::CmdPopMatrix>(layerPtr, [](layer::CmdPopMatrix *cmd) {}, zIndex);
                layer::PopMatrix();
            }

            // util::PrepDraw(layerPtr, registry, entity, 1.0f);
            // layer::QueueCommand<layer::CmdPushMatrix>(layerPtr, [](layer::CmdPushMatrix *cmd) {}, zIndex);
            layer::PushMatrix();
            Vector2 layerDisplacement = {node->layerDisplacement->x, node->layerDisplacement->y};
            // layer::QueueCommand<layer::CmdTranslate>(layerPtr, [x = actualX + layerDisplacement.x, y = actualY + layerDisplacement.y](layer::CmdTranslate *cmd) {
            //     cmd->x = x;
            //     cmd->y = y;
            // }, zIndex);
            layer::Translate(actualX + layerDisplacement.x, actualY + layerDisplacement.y);
            if (config->verticalText)
            {
                // layer::QueueCommand<layer::CmdTranslate>(layerPtr, [x = 0, y = actualH](layer::CmdTranslate *cmd) {
                //     cmd->x = x;
                //     cmd->y = y;
                // }, zIndex);
                layer::Translate(0, actualH);
                // layer::QueueCommand<layer::CmdRotate>(layerPtr, [rotation = -PI / 2](layer::CmdRotate *cmd) {
                //     cmd->angle = rotation;
                // }, zIndex);
                layer::Rotate(-PI / 2);
            }
            Color renderColor = config->color.value();
            if (buttonActive == false)
            {
                renderColor = globals::uiTextInactive;
            }
            
            //REVIEW: bugfixing, commenting out
            // float textX = localization::getFontData().fontRenderOffset.x * config->scale.value_or(1.0f) * localization::getFontData().fontScale;
            // float textY = localization::getFontData().fontRenderOffset.y * config->scale.value_or(1.0f) * localization::getFontData().fontScale;
            // float fontScale = config->scale.value_or(1.0f) * localization::getFontData().fontScale;
            float textX = fontData.fontRenderOffset.x;
            float textY = fontData.fontRenderOffset.y;
            float scale = config->scale.value_or(1.0f) * fontData.fontScale * globals::getGlobalUIScaleFactor();
            // layer::QueueCommand<layer::CmdScale>(layerPtr, [scale = scale](layer::CmdScale *cmd) {
            //     cmd->scaleX = scale;
            //     cmd->scaleY = scale;
            // }, zIndex);
            layer::Scale(scale, scale);

            float spacing = config->textSpacing.value_or(fontData.spacing);
            
            // layer::QueueCommand<layer::CmdTextPro>(layerPtr, [text = config->text.value(), font = localization::getFontData().font, textX, textY, spacing, renderColor](layer::CmdTextPro *cmd) {
            //     cmd->text = text.c_str();
            //     cmd->font = font;
            //     cmd->x = textX;
            //     cmd->y = textY;
            //     cmd->origin = {0, 0};
            //     cmd->rotation = 0;
            //     cmd->fontSize = fontData.fontLoadedSize;
            //     cmd->spacing = spacing;
            //     cmd->color = renderColor;
            // }, zIndex);
            float fontSize = config->fontSize.has_value() ? config->fontSize.value() : fontData.fontLoadedSize;
            layer::TextPro(config->text.value().c_str(), fontData.font, textX, textY, {0, 0}, 0, fontSize, spacing, renderColor);

            // layer::QueueCommand<layer::CmdPopMatrix>(layerPtr, [](layer::CmdPopMatrix *cmd) {}, zIndex);
            layer::PopMatrix();
        }
        else if (config->uiType == UITypeEnum::RECT_SHAPE || config->uiType == UITypeEnum::VERTICAL_CONTAINER || config->uiType == UITypeEnum::HORIZONTAL_CONTAINER || config->uiType == UITypeEnum::ROOT || config->uiType == UITypeEnum::SCROLL_PANE || config->uiType == UITypeEnum::INPUT_TEXT)
        {
            ZONE_SCOPED("UI Element: Rectangle/Container Logic");
            //TODO: need to apply scale and rotation to the rounded rectangle - make a prepdraw method that applies the transform's values
            // layer::QueueCommand<layer::CmdPushMatrix>(layerPtr, [](layer::CmdPushMatrix *cmd) {}, zIndex);
            layer::PushMatrix();
            if (config->shadow && globals::getSettings().shadowsOn)
            {
                Color shadowColor = Color{0, 0, 0, static_cast<unsigned char>(config->color->a * 0.3f)};
                if (config->shadowColor)
                {
                    shadowColor = config->shadowColor.value();
                }

                if (config->stylingType == ui::UIStylingType::ROUNDED_RECTANGLE)
                //FIXME: needs immediate draw version
                    util::DrawSteppedRoundedRectangleImmediate(layerPtr, globals::getRegistry(), entity, *transform, config, *node, rectCache, visualX, visualY, visualW, visualH, visualScaleWithHoverAndMotion, visualR, rotationOffset, ui::RoundedRectangleVerticesCache_TYPE_SHADOW, parallaxDist, {}, std::nullopt, std::nullopt);
                else if (config->stylingType == ui::UIStylingType::NINEPATCH_BORDERS)
                    util::DrawNPatchUIElementImmediate(layerPtr, globals::getRegistry(), entity, shadowColor, parallaxDist, std::nullopt);
                    
            }
            
            // draw embossed rectangle
            if (config->emboss)
            {
                Color c = ColorBrightness(config->color.value(), node->state.isBeingHovered ? -0.8f : -0.5f);
                

                if (config->stylingType == ui::UIStylingType::ROUNDED_RECTANGLE)
                    util::DrawSteppedRoundedRectangleImmediate(layerPtr, globals::getRegistry(), entity, *transform, config, *node, rectCache, visualX, visualY, visualW, visualH, visualScaleWithHoverAndMotion, visualR, rotationOffset, ui::RoundedRectangleVerticesCache_TYPE_EMBOSS, parallaxDist, {{"emboss", c}}, std::nullopt, std::nullopt);
                    
                else if (config->stylingType == ui::UIStylingType::NINEPATCH_BORDERS)
                //TODO: ninepatch doens't support layer order yet
                    util::DrawNPatchUIElementImmediate(layerPtr, globals::getRegistry(), entity, c, parallaxDist, std::nullopt);
            }
        
            
            // darken if button is on cooldown
            Color buttonColor = config->buttonDelay ? util::MixColours(config->color.value(), BLACK, 0.5f) : config->color.value();
            bool collidedButtonHovered = config->hover && node->state.isBeingHovered; 

            if (node->state.isBeingHovered && (entity == (entt::entity)85)) {
                // SPDLOG_DEBUG("DrawSelf(): Button is being hovered: {}", collidedButtonNode.state.isBeingHovered);
            }

            //DONE: hover over container applies hover to all child entities. Why? THe hover state itself doesn't propagate to children. ANSWER: button UIE enabled for parents who are buttons.

            bool clickedRecently = state->last_clicked && state->last_clicked.value() > main_loop::mainLoop.realtimeTimer - 0.1f;
            

            std::optional<Color> specialColor;
            if (collidedButtonHovered || clickedRecently || config->disable_button)
            {
                specialColor = ColorBrightness(buttonColor, -0.5f);
            }
            else if (buttonBeingPressed)
            {
                specialColor = ColorBrightness(buttonColor, -0.5f);
            }

            Color color = specialColor ? specialColor.value() : buttonColor;

            if (/*config->pixelatedRectangle && */visualW > 0.01)
            {
                if (config->buttonDelay)
                {
                    // gray background
                    if (config->stylingType == ui::UIStylingType::ROUNDED_RECTANGLE)
                        util::DrawSteppedRoundedRectangleImmediate(layerPtr, globals::getRegistry(), entity, *transform, config, *node, rectCache, visualX, visualY, visualW, visualH, visualScaleWithHoverAndMotion, visualR, rotationOffset, ui::RoundedRectangleVerticesCache_TYPE_FILL, parallaxDist, {{"fill", color}}, std::nullopt, std::nullopt);
                    else if (config->stylingType == ui::UIStylingType::NINEPATCH_BORDERS)
                        util::DrawNPatchUIElementImmediate(layerPtr, globals::getRegistry(), entity, color, parallaxDist, std::nullopt);

                    // progress bar for button delay                  
                    if (config->stylingType == ui::UIStylingType::ROUNDED_RECTANGLE)
                        util::DrawSteppedRoundedRectangleImmediate(layerPtr, globals::getRegistry(), entity, *transform, config, *node, rectCache, visualX, visualY, visualW, visualH, visualScaleWithHoverAndMotion, visualR, rotationOffset, ui::RoundedRectangleVerticesCache_TYPE_FILL, parallaxDist, {{"fill", color}}, config->buttonDelayProgress, std::nullopt);
                    else if (config->stylingType == ui::UIStylingType::NINEPATCH_BORDERS)
                        util::DrawNPatchUIElementImmediate(layerPtr, globals::getRegistry(), entity, color, parallaxDist, config->buttonDelayProgress);

                }
                else if (config->progressBar)
                {
                    auto colorToUse = config->progressBarEmptyColor.value_or(GRAY);
                    
                    colorToUse = config->progressBarFullColor.value_or(GREEN);
                    
                    // retrieve the current progress bar value using reflection
                    
                    float progress = 1.0f;
                    
                    if (config->progressBarFetchValueLambda) {
                        progress = config->progressBarFetchValueLambda(entity);
                        
                        if (entity == (entt::entity)238) {
                            SPDLOG_DEBUG("Drawself(): Progress bar progress: {}", progress);
                        }
                    }
                    else if (config->progressBarValueComponentName){
                        auto component = reflection::retrieveComponent(&globals::getRegistry(), entity, config->progressBarValueComponentName.value());
                        auto value = reflection::retrieveFieldByString(component, config->progressBarValueComponentName.value(), config->progressBarValueFieldName.value());
                        float progress = value.cast<float>() / config->progressBarMaxValue.value_or(1.0f);
                        SPDLOG_DEBUG("Drawself(): Progress bar progress: {}", progress);
                    }
                    
                    if (config->stylingType == ui::UIStylingType::ROUNDED_RECTANGLE)
                        util::DrawSteppedRoundedRectangleImmediate(layerPtr, globals::getRegistry(), entity, *transform, config, *node, rectCache, visualX, visualY, visualW, visualH, visualScaleWithHoverAndMotion, visualR, rotationOffset, ui::RoundedRectangleVerticesCache_TYPE_FILL, parallaxDist, {{"progress", colorToUse}}, progress, std::nullopt);
                    else if (config->stylingType == ui::UIStylingType::NINEPATCH_BORDERS){
                        
                        
                        util::DrawNPatchUIElementImmediate(layerPtr, globals::getRegistry(), entity, config->progressBarEmptyColor.value_or(GRAY), parallaxDist, std::nullopt);
                        
                        util::DrawNPatchUIElementImmediate(layerPtr, globals::getRegistry(), entity, config->progressBarEmptyColor.value_or(GRAY), parallaxDist, progress);
                    }
                    
                }
                else
                {
                    
                    // SPDLOG_DEBUG("DrawSelf(): Drawing stepped rectangle with width: {}, height: {}", transform->getActualW(), transform->getActualH());
                    if (config->stylingType == ui::UIStylingType::ROUNDED_RECTANGLE)
                        util::DrawSteppedRoundedRectangleImmediate(layerPtr, globals::getRegistry(), entity, *transform, config, *node, rectCache, visualX, visualY, visualW, visualH, visualScaleWithHoverAndMotion, visualR, rotationOffset, ui::RoundedRectangleVerticesCache_TYPE_FILL, parallaxDist, {{"fill", color}}, std::nullopt, std::nullopt);
                    else if (config->stylingType == ui::UIStylingType::NINEPATCH_BORDERS)
                        util::DrawNPatchUIElementImmediate(layerPtr, globals::getRegistry(), entity, color, parallaxDist, std::nullopt);
                }
            }
            else
            {
                // layer::QueueCommand<layer::CmdDrawRectangle>(layerPtr, [w = actualW, h = actualH, color](layer::CmdDrawRectangle *cmd) {
                //     cmd->x = 0;
                //     cmd->y = 0;
                //     cmd->width = w;
                //     cmd->height = h;
                //     cmd->color = color;
                // }, zIndex);
                layer::RectangleDraw(0, 0, actualW, actualH, color);
                
                
                SPDLOG_DEBUG("DrawSelf(): Drawing rectangle with width: {}, height: {}", transform->getActualW(), transform->getActualH());
            }
        

            // layer::QueueCommand<layer::CmdPopMatrix>(layerPtr, [](layer::CmdPopMatrix *cmd) {}, zIndex);
            layer::PopMatrix();
        }
        else if (config->uiType == UITypeEnum::OBJECT && config->object && globals::getRegistry().any_of<transform::GameObject>(config->object.value()))
        {
            ZONE_SCOPED("UI Element: Object Logic");
            //TODO: this part needs fixing
            // hightlighted object outline
            auto &objectNode = globals::getRegistry().get<transform::GameObject>(config->object.value());
            if (config->focusWithObject && objectNode.state.isBeingFocused)
            {
                state->object_focus_timer = state->object_focus_timer.value_or(main_loop::mainLoop.realtimeTimer);
                float lw = 50.0f * std::pow(std::max(0.0f, (state->object_focus_timer.value() - main_loop::mainLoop.realtimeTimer + 0.3f)), 2);
                // util::PrepDraw(layerPtr, registry, entity, 1.0f);
                Color c = util::AdjustAlpha(WHITE, 0.2f * lw);
                util::DrawSteppedRoundedRectangleImmediate(layerPtr, globals::getRegistry(), entity, *transform, config, *node, rectCache, visualX, visualY, visualW, visualH, visualScaleWithHoverAndMotion, visualR, rotationOffset, ui::RoundedRectangleVerticesCache_TYPE_FILL, parallaxDist, {{"fill", c}}, std::nullopt, std::nullopt);
                c = config->color->a > 0.01f ? util::MixColours(WHITE, config->color.value(), 0.8f) : WHITE;
                util::DrawSteppedRoundedRectangleImmediate(layerPtr, globals::getRegistry(), entity, *transform, config, *node, rectCache, visualX, visualY, visualW, visualH, visualScaleWithHoverAndMotion, visualR, rotationOffset, ui::RoundedRectangleVerticesCache_TYPE_OUTLINE, parallaxDist, {{"outline", c}}, std::nullopt, std::nullopt);
                // layer::QueueCommand<layer::CmdPopMatrix>(layerPtr, [](layer::CmdPopMatrix *cmd) {}, zIndex);
                layer::PopMatrix();
            }
            else
            {
                state->object_focus_timer.reset();
            }
        }
    // draw input text (IMMEDIATE MODE)
if (config->uiType == UITypeEnum::INPUT_TEXT) {
    // Source
    auto& ti             = globals::getRegistry().get<ui::TextInput>(entity);
    const std::string& s = ti.text;

    // Font & knobs (match TEXT path)
    const auto& fd        = fontData;
    const float uiScale   = config->scale.value_or(1.0f) * fd.fontScale * globals::getGlobalUIScaleFactor();
    const float spacing   = config->textSpacing.value_or(fd.spacing);
    Color renderColor     = BLACK;

    // Parallax (match TEXT path)
    const float rawScale    = config->scale.value_or(1.0f) * fd.fontScale;
    const float scaleFactor = std::clamp(1.0f / (rawScale * rawScale), 0.01f, 1.0f);
    const float textParallaxSX = node->shadowDisplacement->x * fd.fontLoadedSize * 0.04f * scaleFactor;
    const float textParallaxSY = node->shadowDisplacement->y * fd.fontLoadedSize * -0.03f * scaleFactor;

    const bool drawShadow = (config->button_UIE && true) ||
                            (!config->button_UIE && config->shadow && globals::getSettings().shadowsOn);

    // ---- Vertical centering (unscaled space) --------------------------------
    // We center the glyph box (cap + descent) inside the element height.
    // Heuristic metrics; adjust to taste for your font:
    constexpr float kCap  = 0.72f;  // ~cap height relative to fontSize
    constexpr float kDesc = 0.22f;  // ~descent relative to fontSize

    // Check if fontSize is specified in config, otherwise use default
    const float fontSize = config->fontSize.has_value() ? config->fontSize.value() : fd.fontLoadedSize;
    const float invScale = (uiScale != 0.0f) ? 1.0f / uiScale : 1.0f;
    const float innerH   = transform->getActualH() * invScale;  // unscaled element height

    const float textX = fd.fontRenderOffset.x;

    // Center the glyph box: top = baseY - kCap*fontSize, bottom = baseY + kDesc*fontSize
    // Its vertical center is baseY + (kDesc - kCap)*fontSize/2. We want that at innerH/2.
    const float baseY = fd.fontRenderOffset.y
                      + innerH * 0.5f;
                    //   + (kCap - kDesc) * 0.5f * fontSize;

    Vector2 layerDisp = { node->layerDisplacement->x, node->layerDisplacement->y };

    // --- 1) Shadow pass (identical style to TEXT)
    if (drawShadow) {
        layer::PushMatrix();
        layer::Translate(transform->getActualX() + textParallaxSX + layerDisp.x,
                         transform->getActualY() + textParallaxSY + layerDisp.y);

        if (config->verticalText) {
            layer::Translate(0, transform->getActualH());
            layer::Rotate(-PI / 2);
        }

        // In your TEXT path, shadow textX/Y add a parallax term in unscaled coords:
        const float shadowTextX = textX + (config->verticalText ? textParallaxSY : textParallaxSX)
                                            * config->scale.value_or(1.0f) * fd.fontScale;
        const float shadowBaseY = baseY + (config->verticalText ? textParallaxSX : textParallaxSY)
                                            * config->scale.value_or(1.0f) * fd.fontScale;

        Color shadow = { 0, 0, 0,
            static_cast<unsigned char>(std::max(20.0f, config->color->a * 0.30f)) };

        layer::Scale(uiScale, uiScale);
        layer::TextPro(s.c_str(), fd.font, shadowTextX, shadowBaseY, {0,fontSize / 2}, 0, fontSize, spacing, shadow);
        layer::PopMatrix();
    }

    // --- 2) Main text pass
    layer::PushMatrix();
    layer::Translate(transform->getActualX() + layerDisp.x,
                     transform->getActualY() + layerDisp.y);

    if (config->verticalText) {
        layer::Translate(0, transform->getActualH());
        layer::Rotate(-PI / 2);
    }

    layer::Scale(uiScale, uiScale);
    layer::TextPro(s.c_str(), fd.font, textX, baseY, {0,fontSize / 2}, 0, fontSize, spacing, renderColor);

    // --- 3) Blinking caret exactly on the same baseline
    if (ti.isActive) {
        const bool blinkOn = fmodf(main_loop::mainLoop.realtimeTimer, 1.0f) < 0.5f;
        if (blinkOn) {
            const size_t caretPos   = std::min<size_t>(s.size(), ti.cursorPos);
            const std::string left  = s.substr(0, caretPos);
            const Vector2 lhsSize   = MeasureTextEx(fd.font, left.c_str(), fontSize, spacing);

            const float caretX      = textX + lhsSize.x;             // same X baseline
            const float caretTop    = baseY;       // align to cap top
            const float caretHeight = fontSize;     // cover cap..descent
            const float caretWidth  = 2.0f;                           // unscaled; scales with matrix

            Color caretColor = BLACK;
            layer::RectangleDraw(caretX, caretTop, caretWidth, caretHeight, caretColor);
        }
    }

    layer::PopMatrix();
}


        // outline
        if (config->outlineColor && config->outlineColor->a > 0.01f)
        {
            ZONE_SCOPED("UI Element: Outline Logic");
            if (config->outlineThickness)
            {
                // util::PrepDraw(layerPtr, registry, entity, 1.0f);
                float lineWidth = config->outlineThickness.value();
                if (config->line_emboss)
                {
                    Color c = ColorBrightness(config->outlineColor.value(), node->state.isBeingHovered ? 0.5f : 0.3f);
                    util::DrawSteppedRoundedRectangleImmediate(layerPtr, globals::getRegistry(), entity, *transform, config, *node, rectCache, visualX, visualY, visualW, visualH, visualScaleWithHoverAndMotion, visualR, rotationOffset, ui::RoundedRectangleVerticesCache_TYPE_LINE_EMBOSS, parallaxDist, {{"outline_emboss", c}}, std::nullopt, lineWidth);
                }
                if (transform->getVisualW() > 0.01)
                {
                    util::DrawSteppedRoundedRectangleImmediate(layerPtr, globals::getRegistry(), entity, *transform, config, *node, rectCache, visualX, visualY, visualW, visualH, visualScaleWithHoverAndMotion, visualR, rotationOffset, ui::RoundedRectangleVerticesCache_TYPE_OUTLINE, parallaxDist, {{"outline", config->outlineColor.value()}}, std::nullopt, lineWidth);
                }
            }
        }

        // highlighted button outline (only when mouse not active)
        if (node->state.isBeingFocused && globals::getInputState().hid.mouse_enabled == false && IsCursorHidden() == true)
        {
            state->focus_timer = state->focus_timer.value_or(main_loop::mainLoop.realtimeTimer);
            float lw = 50.0f * std::pow(std::max(0.0f, (state->focus_timer.value() - main_loop::mainLoop.realtimeTimer + 0.3f)), 2);
            // util::PrepDraw(layerPtr, registry, entity, 1.0f);
            Color c = Fade(WHITE, 0.2f * lw);

            util::DrawSteppedRoundedRectangleImmediate(layerPtr, globals::getRegistry(), entity, *transform, config, *node, rectCache, visualX, visualY, visualW, visualH, visualScaleWithHoverAndMotion, visualR, rotationOffset, ui::RoundedRectangleVerticesCache_TYPE_FILL, parallaxDist, {{"fill", c}}, std::nullopt, lw + 4.0f);
            //TODO: refactor this whole method later

            c = config->color->a > 0.01f ? util::MixColours(WHITE, config->color.value(), 0.8f) : WHITE;

            util::DrawSteppedRoundedRectangleImmediate(layerPtr, globals::getRegistry(), entity, *transform, config, *node, rectCache, visualX, visualY, visualW, visualH, visualScaleWithHoverAndMotion, visualR, rotationOffset, ui::RoundedRectangleVerticesCache_TYPE_OUTLINE, parallaxDist, {{"outline", c}}, std::nullopt, lw + 4.f);
            
        }
        else
        {
            state->focus_timer.reset();
        }

        // draw "selection" triangle (arrow pointing to selected object)
        if (config->chosen.value_or(false))
        {
            // triangle floats above the object, slightly bobbing with sine
            float TRIANGLE_DISTANCE = 10.f * globals::getGlobalUIScaleFactor();
            float TRIANGLE_HEIGHT = 25.f * globals::getGlobalUIScaleFactor();
            float TRIANGLE_WIDTH = 25.f * globals::getGlobalUIScaleFactor();
            auto sineOffset = std::sin(main_loop::mainLoop.realtimeTimer * 2.0f) * 2.f;

            auto centerX = actualX + actualW * 0.5f;
            auto triangleY = actualY - TRIANGLE_DISTANCE + sineOffset;

            // triangle points downward, so tip is at triangleY, base is above it
            Vector2 p1 = {centerX, triangleY};                                // tip (bottom)
            Vector2 p2 = {centerX - TRIANGLE_WIDTH * 0.5f, triangleY - TRIANGLE_HEIGHT}; // top-left
            Vector2 p3 = {centerX + TRIANGLE_WIDTH * 0.5f, triangleY - TRIANGLE_HEIGHT}; // top-right

            if (config->shadow && globals::getSettings().shadowsOn)
            {
                constexpr auto FLAT_SHADOW_AMOUNT = 3.f;
                Color shadowColor = Color{0, 0, 0, static_cast<unsigned char>(config->color->a * 0.3f)};

                auto shadowOffsetX = node->shadowDisplacement->x * FLAT_SHADOW_AMOUNT;
                auto shadowOffsetY = - node->shadowDisplacement->y * FLAT_SHADOW_AMOUNT;

                Vector2 s1 = {p1.x + shadowOffsetX, p1.y + shadowOffsetY};
                Vector2 s2 = {p2.x + shadowOffsetX, p2.y + shadowOffsetY};
                Vector2 s3 = {p3.x + shadowOffsetX, p3.y + shadowOffsetY};

                // layer::QueueCommand<layer::CmdDrawTriangle>(layerPtr, [s1, s2, s3, shadowColor](layer::CmdDrawTriangle *cmd) {
                //     cmd->p1 = s1;
                //     cmd->p2 = s2;
                //     cmd->p3 = s3;
                //     cmd->color = shadowColor;
                // }, zIndex);
                layer::Triangle(s1, s2, s3, shadowColor);
            }

            // layer::QueueCommand<layer::CmdDrawTriangle>(layerPtr, [p1, p2, p3](layer::CmdDrawTriangle *cmd) {
            //     cmd->p1 = p1;
            //     cmd->p2 = p2;
            //     cmd->p3 = p3;
            //     cmd->color = RED;
            // }, zIndex);
            layer::Triangle(p1, p2, p3, RED);
        }
        
        if (config->uiType == UITypeEnum::OBJECT && config->object) {
            // render the object itself from here.
            //TODO: how to exclude the object from the other rendering?
            
            entt::entity e = config->object.value();
            
            // is it dynamic text?
            auto textView = globals::getRegistry().view<TextSystem::Text, entity_gamestate_management::StateTag>();
            auto animationView = globals::getRegistry().view<AnimationQueueComponent, entity_gamestate_management::StateTag>();
            if (textView.contains(e))
            {
                // check if the entity is active
                if (entity_gamestate_management::active_states_instance().is_active(globals::getRegistry().get<entity_gamestate_management::StateTag>(e)))
                {
                    TextSystem::Functions::renderTextImmediate(e, layerPtr, true);
                }
                
            } 
            
            // is it an animated sprite?
            else if (animationView.contains(e))
            {
                 // check if the entity is active
                if (entity_gamestate_management::active_states_instance().is_active(animationView.get<entity_gamestate_management::StateTag>(e))) {
                    auto *layerOrder = globals::getRegistry().try_get<layer::LayerOrderComponent>(e);
                    auto zIndex = layerOrder ? layerOrder->zIndex : 0;
                    bool isScreenSpace = globals::getRegistry().any_of<collision::ScreenSpaceCollisionMarker>(e);
                    
                    if (!isScreenSpace)
                    {
                        // SPDLOG_DEBUG("Drawing animated sprite {} in world space at zIndex {}", (int)e, zIndex);
                    }
                    
                    if (globals::getRegistry().any_of<shader_pipeline::ShaderPipelineComponent>(e))
                    {
                        layer::ImmediateCommand<layer::CmdDrawTransformEntityAnimationPipeline>(layerPtr, [e](auto* cmd) {
                            cmd->e = e;
                            cmd->registry = &globals::getRegistry();
                        }, zIndex, isScreenSpace ? layer::DrawCommandSpace::Screen : layer::DrawCommandSpace::World);
                    }
                    else
                    {
                        layer::ImmediateCommand<layer::CmdDrawTransformEntityAnimation>(layerPtr, [e](auto* cmd) {
                            cmd->e = e;
                            cmd->registry = &globals::getRegistry();
                        }, zIndex, isScreenSpace ? layer::DrawCommandSpace::Screen : layer::DrawCommandSpace::World);
                    }      
                }
            
            } // end if animation object
        }

        // call the object's own lambda draw function, if it has one
        if (node->drawFunction) {
            //TODO: this probably won't work in immediate mode
            node->drawFunction(layerPtr, globals::getRegistry(), entity, -1);
        }
    }

    void element::DrawSelf(std::shared_ptr<layer::Layer> layerPtr, entt::entity entity, UIElementComponent &uiElementComp, UIConfig &configComp, UIState &stateComp, transform::GameObject &nodeComp, transform::Transform &transformComp, const int &zIndex)
    {
        ZONE_SCOPED("UI Element: DrawSelf");
        auto *uiElement = &uiElementComp;
        auto *config = &configComp;
        auto *state = &stateComp;
        auto *node =  &nodeComp;
        auto *transform =  &transformComp;
        auto *rectCache = globals::getRegistry().try_get<RoundedRectangleVerticesCache>(entity);
        const auto& fontData = resolveFontData(config);

        AssertThat(uiElement, Is().Not().EqualTo(nullptr));
        AssertThat(config, Is().Not().EqualTo(nullptr));
        AssertThat(state, Is().Not().EqualTo(nullptr));
        AssertThat(node, Is().Not().EqualTo(nullptr));
        AssertThat(transform, Is().Not().EqualTo(nullptr));
        
        auto actualX = transform->getActualX();
        auto actualY = transform->getActualY();
        auto actualW = transform->getActualW();
        auto actualH = transform->getActualH();
        auto visualW = transform->getVisualW();
        auto visualH = transform->getVisualH();
        auto visualX = transform->getVisualX();
        auto visualY = transform->getVisualY();
        auto visualScaleWithHoverAndMotion = transform->getVisualScaleWithHoverAndDynamicMotionReflected();
        auto visualR = transform->getVisualRWithDynamicMotionAndXLeaning();
        auto rotationOffset = transform->rotationOffset;

        // Check if element should be drawn
        if (!node->state.visible)
        {
            if (config->force_focus)
            {
                // LATER: what would be an equivalent for a draw hash in entt? perhaps not necessary?
                //  addToDrawHash(entity);
            }
            return;
        }

        if (config->force_focus || config->forceCollision || config->button_UIE || config->buttonCallback || node->state.collisionEnabled)
        {
            // TODO: what does addToDrawHash do?
            // LATER: what would be an equivalent for a draw hash in entt? perhaps not necessary?
            //  addToDrawHash(entity);
        }

        bool buttonActive = true;
        float parallaxDist = 1.2f; // parallax empahsis
        bool buttonBeingPressed = false;

        // Is it a button?
        if (config->buttonCallback || config->button_UIE)
        {
            ZONE_SCOPED("UI Element: Button Logic");
            auto parentEntity = node->parent.value();
            Vector2 parentParallax = {0, 0};

            auto *parentElement = globals::getRegistry().try_get<UIElementComponent>(parentEntity);
            auto *parentNode = globals::getRegistry().try_get<transform::GameObject>(parentEntity);

            float parentLayerX = (globals::getRegistry().valid(parentEntity) && parentEntity != uiElement->uiBox) ? parentNode->layerDisplacement->x : 0;
            float parentLayerY = (globals::getRegistry().valid(parentEntity) && parentEntity != uiElement->uiBox) ? parentNode->layerDisplacement->y : 0;

            float shadowOffsetX = (config->shadow ? 0.4f * node->shadowDisplacement->x : 0) ;
            float shadowOffsetY = (config->shadow ? 0.4f * node->shadowDisplacement->y : 0) ;

            // node->layerDisplacement->x = parentLayerX + shadowOffsetX;
            // node->layerDisplacement->y = parentLayerY + shadowOffsetY;
            
            node->layerDisplacement->x = parentLayerX;
            node->layerDisplacement->y = parentLayerY;

            // This code applies a parallax effect to the button when it is clicked, hovered, or dragged while the cursor is down. The button moves slightly in the direction of its shadow displacement, giving a depth effect, and it resets parallaxDist to avoid continuous movement.
            if (config->buttonCallback && ((state->last_clicked && state->last_clicked.value() > main_loop::mainLoop.realtimeTimer - 0.1f) || ((config->buttonCallback && (node->state.isBeingHovered || node->state.isBeingDragged)))) && globals::getInputState().is_cursor_down)
            {

                node->layerDisplacement->x -= parallaxDist * node->shadowDisplacement->x;
                node->layerDisplacement->y -= parallaxDist * 1.8f * node->shadowDisplacement->y;
                parallaxDist = 0;
                buttonBeingPressed = true;
                
                // SPDLOG_DEBUG("Button being pressed: {}, setting layer displacement to x: {}, y: {}", buttonBeingPressed, node->layerDisplacement->x, node->layerDisplacement->y);
            }
    
    
        
            //TODO: commenting out for testing. also , why is callback a string?
            // auto *buttonUIEConfig = registry.try_get<UIConfig>(config->button_UIE.value());
            // if (config->button_UIE && buttonUIEConfig && buttonUIEConfig->buttonCallback)
            // {
            //     buttonActive = false;
            // }
        }
        // is it text?
        if (config->uiType == UITypeEnum::TEXT && config->scale)
        {
            ZONE_SCOPED("UI Element: Text Logic");
            float rawScale = config->scale.value() * fontData.fontScale;
            float scaleFactor = std::clamp(1.0f / (rawScale * rawScale), 0.01f, 1.0f); // tunable clamp
            float textParallaxSX = node->shadowDisplacement->x * fontData.fontLoadedSize * 0.04f * scaleFactor;
            float textParallaxSY = node->shadowDisplacement->y * fontData.fontLoadedSize * -0.03f * scaleFactor;
            
            //TODO: if scale is smaller, make the shadow height smaller too

            bool drawShadow = (config->button_UIE && buttonActive) || (!config->button_UIE && config->shadow && globals::getSettings().shadowsOn);

            if (drawShadow)
            {
                // util::PrepDraw(layerPtr, registry, entity, 0.97f);
                layer::QueueCommand<layer::CmdPushMatrix>(layerPtr, [](layer::CmdPushMatrix *cmd) {}, zIndex);
                Vector2 layerDisplacement = {node->layerDisplacement->x, node->layerDisplacement->y};
                layer::QueueCommand<layer::CmdTranslate>(layerPtr, [x = actualX + textParallaxSX + layerDisplacement.x, y = actualY + textParallaxSY + layerDisplacement.y](layer::CmdTranslate *cmd) {
                    cmd->x = x;
                    cmd->y = y;
                }, zIndex);
                
                if (config->verticalText)
                {
                    layer::QueueCommand<layer::CmdTranslate>(layerPtr, [x = 0, y = actualH](layer::CmdTranslate *cmd) {
                        cmd->x = x;
                        cmd->y = y;
                    }, zIndex);
                    layer::QueueCommand<layer::CmdRotate>(layerPtr, [rotation = -PI / 2](layer::CmdRotate *cmd) {
                        cmd->angle = rotation;
                    }, zIndex);
                }
                if ((config->shadow || (config->button_UIE && buttonActive)) && globals::getSettings().shadowsOn)
                {
                    Color shadowColor = Color{0, 0, 0, static_cast<unsigned char>(config->color->a * 0.3f)};

                    float textX = fontData.fontRenderOffset.x + (config->verticalText ? textParallaxSY : textParallaxSX) * config->scale.value_or(1.0f) * fontData.fontScale;
                    float textY = fontData.fontRenderOffset.y + (config->verticalText ? textParallaxSX : textParallaxSY) * config->scale.value_or(1.0f) * fontData.fontScale;
                    float fontScale = config->scale.value_or(1.0f) * fontData.fontScale;
                    float spacing = config->textSpacing.value_or(fontData.spacing);   

                    float scale = config->scale.value_or(1.0f) * fontData.fontScale * globals::getGlobalUIScaleFactor();
                    layer::QueueCommand<layer::CmdScale>(layerPtr, [scale = scale](layer::CmdScale *cmd) {
                        cmd->scaleX = scale;
                        cmd->scaleY = scale;
                    }, zIndex);
                    
                    float fontSize = fontData.fontLoadedSize;
                    layer::QueueCommand<layer::CmdTextPro>(layerPtr, [text = config->text.value(), font = fontData.font, textX, textY, spacing, shadowColor, fontSize](layer::CmdTextPro *cmd) {
                        cmd->text = text.c_str();
                        cmd->font = font;
                        cmd->x = textX;
                        cmd->y = textY;
                        cmd->origin = {0, 0};
                        cmd->rotation = 0;
                        cmd->fontSize = fontSize;
                        cmd->spacing = spacing;
                        cmd->color = shadowColor;
                    }, zIndex);
                    
                    // text offset and spacing and fontscale are configurable values that are added to font rendering (scale changes font scaling), squish also does this (ussually 1), and offset is different for different font types. render_scale is the size at which the font is initially loaded.
                }

                layer::QueueCommand<layer::CmdPopMatrix>(layerPtr, [](layer::CmdPopMatrix *cmd) {}, zIndex);
            }

            // util::PrepDraw(layerPtr, registry, entity, 1.0f);
            layer::QueueCommand<layer::CmdPushMatrix>(layerPtr, [](layer::CmdPushMatrix *cmd) {}, zIndex);
            Vector2 layerDisplacement = {node->layerDisplacement->x, node->layerDisplacement->y};
            layer::QueueCommand<layer::CmdTranslate>(layerPtr, [x = actualX + layerDisplacement.x, y = actualY + layerDisplacement.y](layer::CmdTranslate *cmd) {
                cmd->x = x;
                cmd->y = y;
            }, zIndex);
            if (config->verticalText)
            {
                layer::QueueCommand<layer::CmdTranslate>(layerPtr, [x = 0, y = actualH](layer::CmdTranslate *cmd) {
                    cmd->x = x;
                    cmd->y = y;
                }, zIndex);
                layer::QueueCommand<layer::CmdRotate>(layerPtr, [rotation = -PI / 2](layer::CmdRotate *cmd) {
                    cmd->angle = rotation;
                }, zIndex);
            }
            Color renderColor = config->color.value();
            if (buttonActive == false)
            {
                renderColor = globals::uiTextInactive;
            }
            
            //REVIEW: bugfixing, commenting out
            // float textX = localization::getFontData().fontRenderOffset.x * config->scale.value_or(1.0f) * localization::getFontData().fontScale;
            // float textY = localization::getFontData().fontRenderOffset.y * config->scale.value_or(1.0f) * localization::getFontData().fontScale;
            // float fontScale = config->scale.value_or(1.0f) * localization::getFontData().fontScale;
            float textX = fontData.fontRenderOffset.x;
            float textY = fontData.fontRenderOffset.y;
            float scale = config->scale.value_or(1.0f) * fontData.fontScale * globals::getGlobalUIScaleFactor();
            layer::QueueCommand<layer::CmdScale>(layerPtr, [scale = scale](layer::CmdScale *cmd) {
                cmd->scaleX = scale;
                cmd->scaleY = scale;
            }, zIndex);

            float spacing = config->textSpacing.value_or(fontData.spacing);
            
            float fontSize = fontData.fontLoadedSize;
            layer::QueueCommand<layer::CmdTextPro>(layerPtr, [text = config->text.value(), font = fontData.font, textX, textY, spacing, renderColor, fontSize](layer::CmdTextPro *cmd) {
                cmd->text = text.c_str();
                cmd->font = font;
                cmd->x = textX;
                cmd->y = textY;
                cmd->origin = {0, 0};
                cmd->rotation = 0;
                cmd->fontSize = fontSize;
                cmd->spacing = spacing;
                cmd->color = renderColor;
            }, zIndex);

            layer::QueueCommand<layer::CmdPopMatrix>(layerPtr, [](layer::CmdPopMatrix *cmd) {}, zIndex);
        }
        else if (config->uiType == UITypeEnum::RECT_SHAPE || config->uiType == UITypeEnum::VERTICAL_CONTAINER || config->uiType == UITypeEnum::HORIZONTAL_CONTAINER || config->uiType == UITypeEnum::ROOT || config->uiType == UITypeEnum::SCROLL_PANE || config->uiType == UITypeEnum::INPUT_TEXT)
        {
            ZONE_SCOPED("UI Element: Rectangle/Container Logic");
            //TODO: need to apply scale and rotation to the rounded rectangle - make a prepdraw method that applies the transform's values
            layer::QueueCommand<layer::CmdPushMatrix>(layerPtr, [](layer::CmdPushMatrix *cmd) {}, zIndex);
            if (config->shadow && globals::getSettings().shadowsOn)
            {
                // layer::QueueCommand<layer::CmdScale>(layerPtr, [](layer::CmdScale *cmd) {
                    
                //     cmd->scaleX = 0.98f;
                //     cmd->scaleY = 0.98f;
                // });

                Color shadowColor = Color{0, 0, 0, static_cast<unsigned char>(config->color->a * 0.3f)};
                if (config->shadowColor)
                {
                    shadowColor = config->shadowColor.value();
                }

                if (config->stylingType == ui::UIStylingType::ROUNDED_RECTANGLE)
                    util::DrawSteppedRoundedRectangle(layerPtr, globals::getRegistry(), entity, *transform, config, *node, rectCache, visualX, visualY, visualW, visualH, visualScaleWithHoverAndMotion, visualR, rotationOffset, ui::RoundedRectangleVerticesCache_TYPE_SHADOW, parallaxDist, {}, std::nullopt, std::nullopt, zIndex);
                else if (config->stylingType == ui::UIStylingType::NINEPATCH_BORDERS)
                    util::DrawNPatchUIElement(layerPtr, globals::getRegistry(), entity, shadowColor, parallaxDist, std::nullopt, zIndex);
                    
                // layer::QueueCommand<layer::CmdScale>(layerPtr, [](layer::CmdScale *cmd) {
                //     cmd->scaleX = 1 / 0.98f;
                //     cmd->scaleY = 1 / 0.98f;
                // });
            }
            
            // auto collidedButton = config->button_UIE.value_or(entity);
            
            // // if self is a button itself, ignore button UIE
            // if (globals::getRegistry().get<UIConfig>(entity).buttonCallback) {
            //     collidedButton = entity;
            // }
            
              
            
            // auto &collidedButtonConfig = globals::getRegistry().get<UIConfig>(collidedButton);
            // auto &collidedButtonNode = globals::getRegistry().get<transform::GameObject>(collidedButton);
            // auto &collidedButtonUIState = globals::getRegistry().get<UIState>(collidedButton);
            
            // auto collidedButtonConfig = *config;
            // auto collidedButtonNode = *node;
            // auto collidedButtonUIState = *state;
            
            // draw embossed rectangle
            if (config->emboss)
            {
                Color c = ColorBrightness(config->color.value(), node->state.isBeingHovered ? -0.8f : -0.5f);
                

                if (config->stylingType == ui::UIStylingType::ROUNDED_RECTANGLE)
                    util::DrawSteppedRoundedRectangle(layerPtr, globals::getRegistry(), entity, *transform, config, *node, rectCache, visualX, visualY, visualW, visualH, visualScaleWithHoverAndMotion, visualR, rotationOffset, ui::RoundedRectangleVerticesCache_TYPE_EMBOSS, parallaxDist, {{"emboss", c}}, std::nullopt, std::nullopt, zIndex);
                    
                else if (config->stylingType == ui::UIStylingType::NINEPATCH_BORDERS)
                //TODO: ninepatch doens't support layer order yet
                    util::DrawNPatchUIElement(layerPtr, globals::getRegistry(), entity, c, parallaxDist, std::nullopt, zIndex);
            }
        
            
            // darken if button is on cooldown
            Color buttonColor = config->buttonDelay ? util::MixColours(config->color.value(), BLACK, 0.5f) : config->color.value();
            bool collidedButtonHovered = config->hover && node->state.isBeingHovered; 

            if (node->state.isBeingHovered && (entity == (entt::entity)85)) {
                // SPDLOG_DEBUG("DrawSelf(): Button is being hovered: {}", collidedButtonNode.state.isBeingHovered);
            }

            //DONE: hover over container applies hover to all child entities. Why? THe hover state itself doesn't propagate to children. ANSWER: button UIE enabled for parents who are buttons.

            bool clickedRecently = state->last_clicked && state->last_clicked.value() > main_loop::mainLoop.realtimeTimer - 0.1f;
            

            std::optional<Color> specialColor;
            // if (collidedButtonHovered)
            //     SPDLOG_DEBUG("DrawSelf(): Button is being hovered: {}", static_cast<int>(entity));
            // if (clickedRecently)
            //     SPDLOG_DEBUG("DrawSelf(): Button is being clicked: {}", static_cast<int>(entity));
            if (collidedButtonHovered || clickedRecently || config->disable_button)
            {
                // if (collidedButtonHovered)
                //     SPDLOG_DEBUG("DrawSelf(): Button is being hovered: {}", static_cast<int>(entity));
                // if (clickedRecently)
                //     SPDLOG_DEBUG("DrawSelf(): Button is being clicked: {}", static_cast<int>(entity));
                // if (collidedButtonHovered && clickedRecently)
                //     SPDLOG_DEBUG("DrawSelf(): Button is being clicked and hovered: {}", static_cast<int>(entity));

                specialColor = ColorBrightness(buttonColor, -0.5f);
            }
            else if (buttonBeingPressed)
            {
                specialColor = ColorBrightness(buttonColor, -0.5f);
                // specialColor = BLACK;

                // SPDLOG_DEBUG("button clicked or hovered, setting special color: {}, {}, {}, {}", specialColor->r, specialColor->g, specialColor->b, specialColor->a);
            }

            // std::vector<Color> colors = specialColor ? std::vector<Color>{buttonColor, specialColor.value()} : std::vector<Color>{buttonColor};
            Color color = specialColor ? specialColor.value() : buttonColor;
            // std::vector<Color> colors = specialColor ? std::vector<Color>{buttonColor} : std::vector<Color>{buttonColor};
            // if (specialColor) SPDLOG_DEBUG("Special color applied.");


            // SPDLOG_DEBUG("Processing final button color: {}, {}, {}, {}", color.r, color.g, color.b, color.a);
            if (/*config->pixelatedRectangle && */visualW > 0.01)
            {
                if (config->buttonDelay)
                {
                    // gray background
                    if (config->stylingType == ui::UIStylingType::ROUNDED_RECTANGLE)
                        util::DrawSteppedRoundedRectangle(layerPtr, globals::getRegistry(), entity, *transform, config, *node, rectCache, visualX, visualY, visualW, visualH, visualScaleWithHoverAndMotion, visualR, rotationOffset, ui::RoundedRectangleVerticesCache_TYPE_FILL, parallaxDist, {{"fill", color}}, std::nullopt, std::nullopt, zIndex);
                    else if (config->stylingType == ui::UIStylingType::NINEPATCH_BORDERS)
                        util::DrawNPatchUIElement(layerPtr, globals::getRegistry(), entity, color, parallaxDist, std::nullopt, zIndex);

                    // progress bar                        
                    if (config->stylingType == ui::UIStylingType::ROUNDED_RECTANGLE)
                        util::DrawSteppedRoundedRectangle(layerPtr, globals::getRegistry(), entity, *transform, config, *node, rectCache, visualX, visualY, visualW, visualH, visualScaleWithHoverAndMotion, visualR, rotationOffset, ui::RoundedRectangleVerticesCache_TYPE_FILL, parallaxDist, {{"fill", color}}, config->buttonDelayProgress, std::nullopt, zIndex);
                    else if (config->stylingType == ui::UIStylingType::NINEPATCH_BORDERS)
                        util::DrawNPatchUIElement(layerPtr, globals::getRegistry(), entity, color, parallaxDist, config->buttonDelayProgress, zIndex);

                }
                else if (config->progressBar)
                {
                    auto colorToUse = config->progressBarEmptyColor.value_or(GRAY);
                    
                    //FIXME: commenting out for testing
                    // if (config->stylingType == ui::UIStylingType::ROUNDED_RECTANGLE)
                    //     util::DrawSteppedRoundedRectangle(layerPtr, registry, entity, ui::RoundedRectangleVerticesCache_TYPE_FILL, parallaxDist, {{"fill", colorToUse}});
                    // else if (config->stylingType == ui::UIStylingType::NINEPATCH_BORDERS)
                    //     util::DrawNPatchUIElement(layerPtr, registry, entity, color, parallaxDist);
                    

                    colorToUse = config->progressBarFullColor.value_or(GREEN);
                    
                    // retrieve the current progress bar value using reflection
                    
                    float progress = 1.0f;
                    
                    if (config->progressBarFetchValueLambda) {
                        progress = config->progressBarFetchValueLambda(entity);
                        
                        if (entity == (entt::entity)238) {
                            SPDLOG_DEBUG("Drawself(): Progress bar progress: {}", progress);
                        }
                    }
                    else if (config->progressBarValueComponentName){
                        auto component = reflection::retrieveComponent(&globals::getRegistry(), entity, config->progressBarValueComponentName.value());
                        auto value = reflection::retrieveFieldByString(component, config->progressBarValueComponentName.value(), config->progressBarValueFieldName.value());
                        float progress = value.cast<float>() / config->progressBarMaxValue.value_or(1.0f);
                        SPDLOG_DEBUG("Drawself(): Progress bar progress: {}", progress);
                    }
                    
                    if (config->stylingType == ui::UIStylingType::ROUNDED_RECTANGLE)
                        util::DrawSteppedRoundedRectangle(layerPtr, globals::getRegistry(), entity, *transform, config, *node, rectCache, visualX, visualY, visualW, visualH, visualScaleWithHoverAndMotion, visualR, rotationOffset, ui::RoundedRectangleVerticesCache_TYPE_FILL, parallaxDist, {{"progress", colorToUse}}, progress, std::nullopt, zIndex);
                    else if (config->stylingType == ui::UIStylingType::NINEPATCH_BORDERS)
                        util::DrawNPatchUIElement(layerPtr, globals::getRegistry(), entity, color, parallaxDist, progress, zIndex);
                    
                }
                else
                {
                    
                    // SPDLOG_DEBUG("DrawSelf(): Drawing stepped rectangle with width: {}, height: {}", transform->getActualW(), transform->getActualH());
                    if (config->stylingType == ui::UIStylingType::ROUNDED_RECTANGLE)
                        util::DrawSteppedRoundedRectangle(layerPtr, globals::getRegistry(), entity, *transform, config, *node, rectCache, visualX, visualY, visualW, visualH, visualScaleWithHoverAndMotion, visualR, rotationOffset, ui::RoundedRectangleVerticesCache_TYPE_FILL, parallaxDist, {{"fill", color}}, std::nullopt, std::nullopt, zIndex);
                    else if (config->stylingType == ui::UIStylingType::NINEPATCH_BORDERS)
                        util::DrawNPatchUIElement(layerPtr, globals::getRegistry(), entity, color, parallaxDist, std::nullopt, zIndex);
                    else if (config->stylingType == ui::UIStylingType::SPRITE && config->spriteSourceTexture && config->spriteSourceRect)
                    {
                        auto* tex = config->spriteSourceTexture.value();
                        auto srcRect = config->spriteSourceRect.value();

                        // Validate texture pointer before use
                        if (tex && tex->id != 0) {
                            switch (config->spriteScaleMode) {
                            case ui::SpriteScaleMode::Fixed: {
                                // Draw at original size, centered
                                float cx = (visualW - srcRect.width) / 2.0f;
                                float cy = (visualH - srcRect.height) / 2.0f;
                                layer::QueueCommand<layer::CmdTexturePro>(layerPtr, [tex, srcRect, cx, cy, color](layer::CmdTexturePro *cmd) {
                                    cmd->texture = *tex;
                                    cmd->source = srcRect;
                                    cmd->offsetX = cx;
                                    cmd->offsetY = cy;
                                    cmd->size = {srcRect.width, srcRect.height};
                                    cmd->rotationCenter = {0, 0};
                                    cmd->rotation = 0.0f;
                                    cmd->color = color;
                                }, zIndex);
                                break;
                            }
                            case ui::SpriteScaleMode::Tile: {
                                // Tile to fill container
                                // Performance warning: generates one draw command per tile
                                int tilesX = static_cast<int>(std::ceil(visualW / srcRect.width));
                                int tilesY = static_cast<int>(std::ceil(visualH / srcRect.height));
                                int totalTiles = tilesX * tilesY;

                                // Warn if tile count is excessive (reduces performance)
                                if (totalTiles > 100) {
                                    static bool warningShown = false;
                                    if (!warningShown) {
                                        SPDLOG_WARN("Tiling mode generating {} draw commands ({}x{} tiles) - consider using larger tiles or stretch mode for better performance",
                                            totalTiles, tilesX, tilesY);
                                        warningShown = true;
                                    }
                                }

                                for (float y = 0; y < visualH; y += srcRect.height) {
                                    for (float x = 0; x < visualW; x += srcRect.width) {
                                        // Clip if needed at edges
                                        float drawW = std::min(srcRect.width, visualW - x);
                                        float drawH = std::min(srcRect.height, visualH - y);
                                        Rectangle clippedSrc = {srcRect.x, srcRect.y, drawW, drawH};
                                        layer::QueueCommand<layer::CmdTexturePro>(layerPtr, [tex, clippedSrc, x, y, drawW, drawH, color](layer::CmdTexturePro *cmd) {
                                            cmd->texture = *tex;
                                            cmd->source = clippedSrc;
                                            cmd->offsetX = x;
                                            cmd->offsetY = y;
                                            cmd->size = {drawW, drawH};
                                            cmd->rotationCenter = {0, 0};
                                            cmd->rotation = 0.0f;
                                            cmd->color = color;
                                        }, zIndex);
                                    }
                                }
                                break;
                            }
                            case ui::SpriteScaleMode::Stretch:
                            default: {
                                // Scale to fit
                                layer::QueueCommand<layer::CmdTexturePro>(layerPtr, [tex, srcRect, visualW, visualH, color](layer::CmdTexturePro *cmd) {
                                    cmd->texture = *tex;
                                    cmd->source = srcRect;
                                    cmd->offsetX = 0;
                                    cmd->offsetY = 0;
                                    cmd->size = {visualW, visualH};
                                    cmd->rotationCenter = {0, 0};
                                    cmd->rotation = 0.0f;
                                    cmd->color = color;
                                }, zIndex);
                                break;
                            }
                            }
                        }
                    }
                }
            }
            else
            {
                layer::QueueCommand<layer::CmdDrawRectangle>(layerPtr, [w = actualW, h = actualH, color](layer::CmdDrawRectangle *cmd) {
                    cmd->x = 0;
                    cmd->y = 0;
                    cmd->width = w;
                    cmd->height = h;
                    cmd->color = color;
                }, zIndex);
                
                
                SPDLOG_DEBUG("DrawSelf(): Drawing rectangle with width: {}, height: {}", transform->getActualW(), transform->getActualH());
            }
        

            layer::QueueCommand<layer::CmdPopMatrix>(layerPtr, [](layer::CmdPopMatrix *cmd) {}, zIndex);
        }
        else if (config->uiType == UITypeEnum::OBJECT && config->object)
        {
            //TODO: this part needs fixing
            // hightlighted object outline
            auto &objectNode = globals::getRegistry().get<transform::GameObject>(config->object.value());
            if (config->focusWithObject && objectNode.state.isBeingFocused)
            {
                state->object_focus_timer = state->object_focus_timer.value_or(main_loop::mainLoop.realtimeTimer);
                float lw = 50.0f * std::pow(std::max(0.0f, (state->object_focus_timer.value() - main_loop::mainLoop.realtimeTimer + 0.3f)), 2);
                // util::PrepDraw(layerPtr, registry, entity, 1.0f);
                Color c = util::AdjustAlpha(WHITE, 0.2f * lw);
                util::DrawSteppedRoundedRectangle(layerPtr, globals::getRegistry(), entity, *transform, config, *node, rectCache, visualX, visualY, visualW, visualH, visualScaleWithHoverAndMotion, visualR, rotationOffset, ui::RoundedRectangleVerticesCache_TYPE_FILL, parallaxDist, {{"fill", c}}, std::nullopt, std::nullopt, zIndex);
                c = config->color->a > 0.01f ? util::MixColours(WHITE, config->color.value(), 0.8f) : WHITE;
                util::DrawSteppedRoundedRectangle(layerPtr, globals::getRegistry(), entity, *transform, config, *node, rectCache, visualX, visualY, visualW, visualH, visualScaleWithHoverAndMotion, visualR, rotationOffset, ui::RoundedRectangleVerticesCache_TYPE_OUTLINE, parallaxDist, {{"outline", c}}, std::nullopt, std::nullopt, zIndex);
                layer::QueueCommand<layer::CmdPopMatrix>(layerPtr, [](layer::CmdPopMatrix *cmd) {}, zIndex);
            }
            else
            {
                state->object_focus_timer.reset();
            }
        }
        
        // draw input text
        if (config->uiType == UITypeEnum::INPUT_TEXT)
        {
            // Text source: ui::TextInput on the same entity
            auto &textInput = globals::getRegistry().get<ui::TextInput>(entity);
            const std::string &displayText = textInput.text;  // (optionally mask if you add that feature)

            // Reuse same font + knobs you used for TEXT
            float scale      = config->scale.value_or(1.0f) * fontData.fontScale * globals::getGlobalUIScaleFactor();
            float spacing    = config->textSpacing.value_or(fontData.spacing);
            Color renderColor = config->color.value();
            bool buttonActive = true; // same convention as above TEXT block

            if (!buttonActive)
                renderColor = globals::uiTextInactive;

            // Shadow logic identical to TEXT (with parallax derived from the node's shadow)
            bool drawShadow = ((config->button_UIE && buttonActive) || (!config->button_UIE && config->shadow && globals::getSettings().shadowsOn));
            float rawScale = config->scale.value_or(1.0f) * fontData.fontScale;
            float scaleFactor = std::clamp(1.0f / (rawScale * rawScale), 0.01f, 1.0f);
            float textParallaxSX = node->shadowDisplacement->x * fontData.fontLoadedSize * 0.04f * scaleFactor;
            float textParallaxSY = node->shadowDisplacement->y * fontData.fontLoadedSize * -0.03f * scaleFactor;

            // Common translate (like TEXT): position at element origin + layer displacement
            Vector2 layerDisplacement = { node->layerDisplacement->x, node->layerDisplacement->y };

            // 1) Optional shadow pass
            if (drawShadow) {
                layer::QueueCommand<layer::CmdPushMatrix>(layerPtr, [](auto*){}, zIndex);
                layer::QueueCommand<layer::CmdTranslate>(layerPtr, [x = actualX + textParallaxSX + layerDisplacement.x,
                                                                    y = actualY + textParallaxSY + layerDisplacement.y](layer::CmdTranslate *cmd) {
                    cmd->x = x; cmd->y = y;
                }, zIndex);

                if (config->verticalText) {
                    layer::QueueCommand<layer::CmdTranslate>(layerPtr, [h = actualH](layer::CmdTranslate *cmd) { cmd->x = 0; cmd->y = h; }, zIndex);
                    layer::QueueCommand<layer::CmdRotate>(layerPtr, [](layer::CmdRotate *cmd) { cmd->angle = -PI / 2; }, zIndex);
                }

                Color shadowColor = Color{0, 0, 0, static_cast<unsigned char>(config->color->a * 0.3f)};
                float textX  = fontData.fontRenderOffset.x;
                float textY  = fontData.fontRenderOffset.y;
                float s      = scale;
                float fontSize = fontData.fontLoadedSize;

                layer::QueueCommand<layer::CmdScale>(layerPtr, [s](layer::CmdScale *cmd){ cmd->scaleX = s; cmd->scaleY = s; }, zIndex);
                layer::QueueCommand<layer::CmdTextPro>(layerPtr, [t = displayText,
                                                                font = fontData.font,
                                                                textX, textY, spacing, shadowColor, fontSize](layer::CmdTextPro *cmd) {
                    cmd->text     = t.c_str();
                    cmd->font     = font;
                    cmd->x        = textX;
                    cmd->y        = textY;
                    cmd->origin   = {0, 0};
                    cmd->rotation = 0;
                    cmd->fontSize = fontSize;
                    cmd->spacing  = spacing;
                    cmd->color    = shadowColor;
                }, zIndex);

                layer::QueueCommand<layer::CmdPopMatrix>(layerPtr, [](auto*){}, zIndex);
            }

            // 2) Main text pass
            layer::QueueCommand<layer::CmdPushMatrix>(layerPtr, [](auto*){}, zIndex);
            layer::QueueCommand<layer::CmdTranslate>(layerPtr, [x = actualX + layerDisplacement.x,
                                                                y = actualY + layerDisplacement.y](layer::CmdTranslate *cmd) {
                cmd->x = x; cmd->y = y;
            }, zIndex);

            if (config->verticalText) {
                layer::QueueCommand<layer::CmdTranslate>(layerPtr, [h = actualH](layer::CmdTranslate *cmd) { cmd->x = 0; cmd->y = h; }, zIndex);
                layer::QueueCommand<layer::CmdRotate>(layerPtr, [](layer::CmdRotate *cmd) { cmd->angle = -PI / 2; }, zIndex);
            }

            float textX = fontData.fontRenderOffset.x;
            float textY = fontData.fontRenderOffset.y;
            float fontSize = fontData.fontLoadedSize;

            layer::QueueCommand<layer::CmdScale>(layerPtr, [s = scale](layer::CmdScale *cmd){
                cmd->scaleX = s; cmd->scaleY = s;
            }, zIndex);

            layer::QueueCommand<layer::CmdTextPro>(layerPtr, [t = displayText,
                                                            font = fontData.font,
                                                            textX, textY, spacing, renderColor, fontSize](layer::CmdTextPro *cmd) {
                cmd->text     = t.c_str();
                cmd->font     = font;
                cmd->x        = textX;
                cmd->y        = textY;
                cmd->origin   = {0, 0};
                cmd->rotation = 0;
                cmd->fontSize = fontSize;
                cmd->spacing  = spacing;
                cmd->color    = renderColor;
            }, zIndex);

            // 3) Blinking caret (only when focused)
            if (textInput.isActive) {
                // Blink at 1Hz (on 0.5s, off 0.5s)
                bool blinkOn = fmodf(main_loop::mainLoop.realtimeTimer, 1.0f) < 0.5f;
                if (blinkOn) {
                    // Measure the text up to cursorPos at the *unscaled* font size,
                    // then add the unscaled render offset; finally we draw under the current scaling.
                    std::string left = displayText.substr(0, std::min<size_t>(displayText.size(), textInput.cursorPos));
                    float fontSize   = fontData.fontLoadedSize;
                    // NOTE: MeasureTextEx returns *unscaled* pixel width for given fontSize and spacing.
                    Vector2 lhsSize  = MeasureTextEx(fontData.font, left.c_str(), fontSize, spacing);

                    float caretX      = textX + lhsSize.x;
                    float caretY      = textY;                 // same baseline as text
                    float caretWidth  = 2.0f;                  // 2px before scaling
                    float caretHeight = fontSize * 1.1f;       // little taller than glyphs

                    Color caretColor  = renderColor; caretColor.a = std::max<unsigned char>(caretColor.a, 220);

                    // Draw a thin vertical rectangle as caret (inside current Push/Scale)
                    layer::QueueCommand<layer::CmdDrawRectangle>(layerPtr, [cx = caretX, cy = caretY - fontSize * 0.85f, // shift up to cap height
                                                                            w = caretWidth, h = caretHeight, caretColor](layer::CmdDrawRectangle *cmd) {
                        cmd->x = cx;
                        cmd->y = cy;
                        cmd->width  = w;
                        cmd->height = h;
                        cmd->color  = caretColor;
                    }, zIndex);
                }
            }

            layer::QueueCommand<layer::CmdPopMatrix>(layerPtr, [](auto*){}, zIndex);
        }


        // outline
        if (config->outlineColor && config->outlineColor->a > 0.01f)
        {
            ZONE_SCOPED("UI Element: Outline Logic");
            if (config->outlineThickness)
            {
                // util::PrepDraw(layerPtr, registry, entity, 1.0f);
                float lineWidth = config->outlineThickness.value();
                if (config->line_emboss)
                {
                    Color c = ColorBrightness(config->outlineColor.value(), node->state.isBeingHovered ? 0.5f : 0.3f);
                    util::DrawSteppedRoundedRectangle(layerPtr, globals::getRegistry(), entity, *transform, config, *node, rectCache, visualX, visualY, visualW, visualH, visualScaleWithHoverAndMotion, visualR, rotationOffset, ui::RoundedRectangleVerticesCache_TYPE_LINE_EMBOSS, parallaxDist, {{"outline_emboss", c}}, std::nullopt, lineWidth, zIndex);
                }
                if (transform->getVisualW() > 0.01)
                {
                    util::DrawSteppedRoundedRectangle(layerPtr, globals::getRegistry(), entity, *transform, config, *node, rectCache, visualX, visualY, visualW, visualH, visualScaleWithHoverAndMotion, visualR, rotationOffset, ui::RoundedRectangleVerticesCache_TYPE_OUTLINE, parallaxDist, {{"outline", config->outlineColor.value()}}, std::nullopt, lineWidth, zIndex);
                }
            }
        }

        // highlighted button outline (only when mouse not active)
        if (node->state.isBeingFocused && globals::getInputState().hid.mouse_enabled == false && IsCursorHidden() == true)
        {
            state->focus_timer = state->focus_timer.value_or(main_loop::mainLoop.realtimeTimer);
            float lw = 50.0f * std::pow(std::max(0.0f, (state->focus_timer.value() - main_loop::mainLoop.realtimeTimer + 0.3f)), 2);
            // util::PrepDraw(layerPtr, registry, entity, 1.0f);
            Color c = Fade(WHITE, 0.2f * lw);

            util::DrawSteppedRoundedRectangle(layerPtr, globals::getRegistry(), entity, *transform, config, *node, rectCache, visualX, visualY, visualW, visualH, visualScaleWithHoverAndMotion, visualR, rotationOffset, ui::RoundedRectangleVerticesCache_TYPE_FILL, parallaxDist, {{"fill", c}}, std::nullopt, lw + 4.0f, zIndex);
            //TODO: refactor this whole method later

            c = config->color->a > 0.01f ? util::MixColours(WHITE, config->color.value(), 0.8f) : WHITE;

            util::DrawSteppedRoundedRectangle(layerPtr, globals::getRegistry(), entity, *transform, config, *node, rectCache, visualX, visualY, visualW, visualH, visualScaleWithHoverAndMotion, visualR, rotationOffset, ui::RoundedRectangleVerticesCache_TYPE_OUTLINE, parallaxDist, {{"outline", c}}, std::nullopt, lw + 4.f, zIndex);
            
        }
        else
        {
            state->focus_timer.reset();
        }

        // draw "selection" triangle (arrow pointing to selected object)
        if (config->chosen.value_or(false))
        {
            // triangle floats above the object, slightly bobbing with sine
            float TRIANGLE_DISTANCE = 10.f * globals::getGlobalUIScaleFactor();
            float TRIANGLE_HEIGHT = 25.f * globals::getGlobalUIScaleFactor();
            float TRIANGLE_WIDTH = 25.f * globals::getGlobalUIScaleFactor();
            auto sineOffset = std::sin(main_loop::mainLoop.realtimeTimer * 2.0f) * 2.f;

            auto centerX = actualX + actualW * 0.5f;
            auto triangleY = actualY - TRIANGLE_DISTANCE + sineOffset;

            // triangle points downward, so tip is at triangleY, base is above it
            Vector2 p1 = {centerX, triangleY};                                // tip (bottom)
            Vector2 p2 = {centerX - TRIANGLE_WIDTH * 0.5f, triangleY - TRIANGLE_HEIGHT}; // top-left
            Vector2 p3 = {centerX + TRIANGLE_WIDTH * 0.5f, triangleY - TRIANGLE_HEIGHT}; // top-right

            if (config->shadow && globals::getSettings().shadowsOn)
            {
                constexpr auto FLAT_SHADOW_AMOUNT = 3.f;
                Color shadowColor = Color{0, 0, 0, static_cast<unsigned char>(config->color->a * 0.3f)};

                auto shadowOffsetX = node->shadowDisplacement->x * FLAT_SHADOW_AMOUNT;
                auto shadowOffsetY = - node->shadowDisplacement->y * FLAT_SHADOW_AMOUNT;

                Vector2 s1 = {p1.x + shadowOffsetX, p1.y + shadowOffsetY};
                Vector2 s2 = {p2.x + shadowOffsetX, p2.y + shadowOffsetY};
                Vector2 s3 = {p3.x + shadowOffsetX, p3.y + shadowOffsetY};

                layer::QueueCommand<layer::CmdDrawTriangle>(layerPtr, [s1, s2, s3, shadowColor](layer::CmdDrawTriangle *cmd) {
                    cmd->p1 = s1;
                    cmd->p2 = s2;
                    cmd->p3 = s3;
                    cmd->color = shadowColor;
                }, zIndex);
            }

            layer::QueueCommand<layer::CmdDrawTriangle>(layerPtr, [p1, p2, p3](layer::CmdDrawTriangle *cmd) {
                cmd->p1 = p1;
                cmd->p2 = p2;
                cmd->p3 = p3;
                cmd->color = RED;
            }, zIndex);
        }
        
        if (config->uiType == UITypeEnum::OBJECT && config->object) {
            // render the object itself from here.
            //TODO: how to exclude the object from the other rendering?
            
            entt::entity e = config->object.value();
            
            // is it dynamic text?
            auto textView = globals::getRegistry().view<TextSystem::Text, entity_gamestate_management::StateTag>();
            if (textView.contains(e))
            {
                // check if the entity is active
                if (entity_gamestate_management::active_states_instance().is_active(globals::getRegistry().get<entity_gamestate_management::StateTag>(e)))
                {
                    TextSystem::Functions::renderText(e, layerPtr, true);
                }
                
            }
            
                
                //  // check if the entity is active
                // if (!entity_gamestate_management::active_states_instance().is_active(spriteView.get<entity_gamestate_management::StateTag>(e)))
                //     continue; // skip inactive entities
                // auto *layerOrder = globals::getRegistry().try_get<layer::LayerOrderComponent>(e);
                // auto zIndex = layerOrder ? layerOrder->zIndex : 0;
                // bool isScreenSpace = globals::getRegistry().any_of<collision::ScreenSpaceCollisionMarker>(e);
                
                // if (!isScreenSpace)
                // {
                //     // SPDLOG_DEBUG("Drawing animated sprite {} in world space at zIndex {}", (int)e, zIndex);
                // }
                
                // if (globals::getRegistry().any_of<shader_pipeline::ShaderPipelineComponent>(e))
                // {
                //     layer::QueueCommand<layer::CmdDrawTransformEntityAnimationPipeline>(sprites, [e](auto* cmd) {
                //         cmd->e = e;
                //         cmd->registry = &globals::getRegistry();
                //     }, zIndex, isScreenSpace ? layer::DrawCommandSpace::Screen : layer::DrawCommandSpace::World);
                // }
                // else
                // {
                //     layer::QueueCommand<layer::CmdDrawTransformEntityAnimation>(sprites, [e](auto* cmd) {
                //         cmd->e = e;
                //         cmd->registry = &globals::getRegistry();
                //     }, zIndex, isScreenSpace ? layer::DrawCommandSpace::Screen : layer::DrawCommandSpace::World);
                // }      
            
            
        }

        // call the object's own lambda draw function, if it has one
        if (node->drawFunction) {
            // util::PrepDraw(layerPtr, registry, entity, 0.98f);
            node->drawFunction(layerPtr, globals::getRegistry(), entity, zIndex);
        }
        
        //TODO: enable this back later

        if (globals::getDrawDebugInfo())
            transform::DrawBoundingBoxAndDebugInfo(&globals::getRegistry(), entity, layerPtr);
    }
    

    void element::Update(entt::registry &registry, entt::entity entity, float dt,  UIConfig *uiConfig, transform::Transform *transform, UIElementComponent *uiElement, transform::GameObject *node)
    {
        ZONE_SCOPED("UI Element: Update");
        // If button is disabled, keep the callback intact and only gate click input.
        if (uiConfig->disable_button)
        {
            uiConfig->buttonClicked = false;
            node->state.clickEnabled = false;
        }
        else
        {
            node->state.clickEnabled = true;
        }

        // Handle button delay
        if (uiConfig->buttonDelay)
        {
            // if (uiConfig->buttonCallback)
            //     uiConfig->buttonTemp = uiConfig->buttonCallback;
            // uiConfig->buttonCallback = std::nullopt;
            uiConfig->buttonDelayProgress = (main_loop::mainLoop.realtimeTimer - uiConfig->buttonDelayStart.value()) / uiConfig->buttonDelay.value();
            SPDLOG_DEBUG("Button delay progress: {}", uiConfig->buttonDelayProgress.value());

            if (main_loop::mainLoop.realtimeTimer >= uiConfig->buttonDelayEnd.value())
            {
                uiConfig->buttonDelay.reset(); // Remove button delay when expired
            }
        }

        // Restore button state after delay ends
        if (uiConfig->buttonTemp && !uiConfig->buttonDelay)
        {
            uiConfig->buttonCallback = uiConfig->buttonTemp;
        }

        // Reset button clicked state
        if (uiConfig->buttonClicked)
        {
            uiConfig->buttonClicked = false;
        }

        // Execute UI function if defined
        if (uiConfig->updateFunc)
        {
            uiConfig->updateFunc.value()(&registry, entity, dt);
        }

        // Handle text update
        if (uiElement->UIT == UITypeEnum::TEXT)
        {
            UpdateText(registry, entity, &globalUIGroup.get<ui::UIConfig>(entity), &globalUIGroup.get<UIState>(entity));
        }

        // Handle object update
        if (uiElement->UIT == UITypeEnum::OBJECT)
        {
            // void ui::element::UpdateObject(entt::registry &registry, entt::entity entity, ui::UIConfig *elementConfig, transform::GameObject *elementNode, ui::UIConfig *objectConfig, transform::Transform *objectTransform, transform::InheritedProperties *objectRole, transform::GameObject *objectNode)

            // uiConfig

            auto object = uiConfig->object.value();
            auto roleView = registry.view<transform::InheritedProperties>();
     

            if (registry.any_of<ui::UIConfig>(object) == false){
                // no uiconfig entity. emplace one.
                registry.emplace_or_replace<ui::UIConfig>(object);
            }
            
            // skip if transform is destroyed
            if (!registry.valid(object) || !registry.any_of<transform::Transform>(object))
            {
                SPDLOG_ERROR("UI Element: UpdateObject: Object entity {} does not have a Transform component or is not valid.", static_cast<int>(object));
                return;
            }

            UpdateObject(registry, entity, &globalUIGroup.get<ui::UIConfig>(entity), 
                         &globalUIGroup.get<transform::GameObject>(entity), 
                         &globalUIGroup.get<ui::UIConfig>(object), 
                         &globalUIGroup.get<transform::Transform>(object), 
                         &roleView.get<transform::InheritedProperties>(object), 
                         &globalUIGroup.get<transform::GameObject>(object));
        }

        // Call Node update (assuming it exists)
        if (node->updateFunction)
        {
            node->updateFunction(registry, entity, dt);
        }
    }

    bool element::CollidesWithPoint(entt::registry &registry, entt::entity entity, const Vector2 &cursorPosition)
    {
        // Retrieve UI element and UI box components
        auto *uiElement = registry.try_get<UIElementComponent>(entity);
        auto *uiBox = registry.try_get<UIBoxComponent>(entity);
        auto *node = registry.try_get<transform::GameObject>(entity);

        // Ensure valid components exist
        AssertThat(uiElement, Is().Not().EqualTo(nullptr));
        AssertThat(uiBox, Is().Not().EqualTo(nullptr));
        AssertThat(node, Is().Not().EqualTo(nullptr));

        // Check if the UIBox allows collision
        if (node->state.collisionEnabled)
        {
            transform::CheckCollisionWithPoint(&registry, entity, cursorPosition);
        }

        return false; // No collision if `canCollide` is disabled
    }

    void element::Click(entt::registry &registry, entt::entity entity)
    {
        auto *uiElement = registry.try_get<UIElementComponent>(entity);
        auto *uiConfig = registry.try_get<UIConfig>(entity);
        auto *uiState = registry.try_get<UIState>(entity);
        auto *node = registry.try_get<transform::GameObject>(entity);

        // Ensure valid components exist
        AssertThat(uiElement, Is().Not().EqualTo(nullptr));
        AssertThat(uiConfig, Is().Not().EqualTo(nullptr));
        AssertThat(node, Is().Not().EqualTo(nullptr));
        AssertThat(uiState, Is().Not().EqualTo(nullptr));

        // Ensure button conditions are met before proceeding
        float currentTime = main_loop::mainLoop.realtimeTimer;
        if (uiConfig->buttonCallback &&
            (!uiState->last_clicked || uiState->last_clicked.value() + 0.1f < currentTime) &&
            node->state.visible &&
            !node->state.isUnderOverlay &&
            !uiConfig->disable_button)
        {
            // If button is 'single press only', disable it after being clicked
            if (uiConfig->one_press){
                uiConfig->disable_button = true;
                SPDLOG_DEBUG("Button is single press only, disabling it after being clicked");
            }

            uiState->last_clicked = currentTime;

            // Remove a layer from the overlay menu stack
            if (uiConfig->id && *uiConfig->id == "overlay_menu_back_button")
            { // TODO: replace with whatever button name gets rid of overlay menu
                input::ModifyCurrentCursorContextLayer(registry, globals::getInputState(), -1);
                globals::noModCursorStack = true;
            }

            // LATER: example, If the overlay tutorial listens for this button, trigger the next tutorial step
            // if (globals::OVERLAY_TUTORIAL && globals::OVERLAY_TUTORIAL->buttonListen == uiConfig->button) {
            //     globals::FUNCS["tut_next"]();
            // }

            // Call the function associated with this button
            if (uiConfig->buttonCallback) {
                uiConfig->buttonCallback.value()();
            }

            globals::noModCursorStack.reset(); // Reset cursor stack modification

            // Handle UI selection groups (radio button behavior)
            // REVIEW: chosen can be boolean or a string. Not sure how this will pan out. For now, adding a chosen param to the config which is bool, and another string one in the node.config struct.
            if (uiConfig->choice)
            {
                std::vector<entt::entity> choices = ui::box::GetGroup(registry, uiConfig->groupParent.value_or(entt::null), uiConfig->group.value_or(""));
                
                SPDLOG_DEBUG("Click(): Group parent: {}, group: {}", static_cast<int>(uiConfig->groupParent.value_or(entt::null)), uiConfig->group.value_or(""));
                SPDLOG_DEBUG("Click(): Choices size: {}", choices.size());
                

                for (auto choiceEntity : choices)
                {
                    auto *choiceConfig = registry.try_get<UIConfig>(choiceEntity);
                    if (choiceConfig && choiceConfig->chosen)
                    {
                        SPDLOG_DEBUG("Click(): Unsetting choice for entity: {}", static_cast<int>(choiceEntity));
                        choiceConfig->chosen = false;
                    }
                }
                uiConfig->chosen = true;
            }

            // TODO: Play a button press sound

            // TODO: Apply a jiggling effect to the room
            // TODO: add an update function which will modify the transform rotation of the container for the game map that will make it jiggle based on getTime(), based on a jiggle value which decays exponentially over time. This value is combined with a screen shake value as well, modifying the room's transform x & y values. This will be called in the main loop.
            // globals::ROOM.jiggle += 0.5f;

            uiConfig->buttonClicked = true;
        }

        // If this element has a linked button UIElement, trigger its click as well
        // TODO: elements can have elements? how does this work? what is button UIE?
        if (uiConfig->button_UIE)
        {
            Click(registry, uiConfig->button_UIE.value());
        }
    }

    Vector2 element::PutFocusedCursor(entt::registry &registry, entt::entity entity)
    {
        auto *uiConfig = registry.try_get<UIConfig>(entity);
        auto *node = registry.try_get<transform::GameObject>(entity);

        // Ensure valid components exist
        AssertThat(uiConfig, Is().Not().EqualTo(nullptr));
        AssertThat(node, Is().Not().EqualTo(nullptr));

        // Check if this element has tabbed navigation
        if (uiConfig && uiConfig->focusArgs && uiConfig->focusArgs->type == "tab")
        { // TODO: document focus arg type
            for (auto childEntry : node->orderedChildren)
            {
                auto child = childEntry;
                auto *childNode = registry.try_get<transform::GameObject>(child);
                auto *childConfig = registry.try_get<UIConfig>(child);

                if (childNode && !childNode->children.empty())
                {
                    auto *firstChildConfig = registry.try_get<UIConfig>(childNode->children[0]);
                    if (firstChildConfig && firstChildConfig->chosen)
                    {
                        return PutFocusedCursor(registry, childNode->children[0]);
                    }
                }
            }
        }
        else
        {
            // Call base class function (Node::put_focused_cursor equivalent)
            return transform::GetCursorOnFocus(&registry, entity);
        }
    }

    void element::Remove(entt::registry &registry, entt::entity entity)
    {
        auto *uiConfig = registry.try_get<UIConfig>(entity);
        auto *node = registry.try_get<transform::GameObject>(entity);

        AssertThat(uiConfig, Is().Not().EqualTo(nullptr));
        AssertThat(node, Is().Not().EqualTo(nullptr));

        // Step 1: Remove associated object (if any)
        if (uiConfig && uiConfig->object)
        {
            registry.destroy(uiConfig->object.value()); // Destroy linked entity
            uiConfig->object = std::nullopt;
        }

        // Step 2: Reset text input hook if this is the active one
        if (globals::getInputState().text_input_hook && globals::getInputState().text_input_hook.value() == entity)
        {
            globals::getInputState().text_input_hook.reset();
        }

        // Step 3: Recursively remove all children
        if (node)
        {
            for (auto childEntry : node->children)
            {
                auto child = childEntry.second;
                Remove(registry, child);
            }
            node->children.clear(); // Ensure child list is empty
            node->orderedChildren.clear(); // Ensure ordered child list is empty
        }

        // Step 4: Remove entity from registry
        transform::RemoveEntity(&registry, entity);
    }

    void element::ApplyHover(entt::registry &registry, entt::entity entity)
    {
        
        auto *uiConfig = registry.try_get<UIConfig>(entity);
        auto *transform = registry.try_get<transform::Transform>(entity);
        auto *node = registry.try_get<transform::GameObject>(entity);
        auto *roomTransform = registry.try_get<transform::Transform>(globals::gameWorldContainerEntity);

        AssertThat(uiConfig, Is().Not().EqualTo(nullptr));
        AssertThat(transform, Is().Not().EqualTo(nullptr));
        AssertThat(node, Is().Not().EqualTo(nullptr));
        AssertThat(roomTransform, Is().Not().EqualTo(nullptr));
        
        // SPDLOG_DEBUG("ApplyHover(): Applying hover for entity: {}", static_cast<int>(entity));

        // Step 1: Handle On-Demand Tooltip
        if (uiConfig->onDemandTooltip)
        {
            // TODO: implement createPopupTooltip (as part of ui definitions, probably)
            //  uiConfig->hPopup = createPopupTooltip(uiConfig->onDemandTooltip.value());
            UIConfig config = {
                .offset = Vector2{0, transform->getActualY() > roomTransform->getActualH() / 2 ? -0.1f : 0.1f},
                .parent = entity,
                .alignmentFlags = transform->getActualY() > roomTransform->getActualH() / 2 ? transform::InheritedProperties::Alignment::VERTICAL_TOP | transform::InheritedProperties::Alignment::HORIZONTAL_CENTER : transform::InheritedProperties::Alignment::VERTICAL_BOTTOM | transform::InheritedProperties::Alignment::HORIZONTAL_CENTER};
            uiConfig->hPopupConfig = std::make_shared<UIConfig>(config);
        }

        // Step 2: Handle Basic Tooltip
        // TODO: what is the difference between on demand and basic tooltip?
        if (uiConfig->tooltip)
        {
            // TODO: implement createPopupTooltip
            // uiConfig->hPopup = createPopupTooltip(uiConfig->tooltip.value());
            UIConfig config = {
                .offset = Vector2{0, -0.1f},
                .parent = entity,
                .alignmentFlags = transform::InheritedProperties::Alignment::VERTICAL_TOP | transform::InheritedProperties::Alignment::HORIZONTAL_CENTER};
            uiConfig->hPopupConfig = std::make_shared<UIConfig>(config);
        }

        // Step 3: Handle Detailed Tooltip (Only If Pointer is Active)
        auto &controller = globals::getInputState();
        if (uiConfig->detailedTooltip && controller.hid.pointer_enabled)
        {

            UIConfig config = {
                .offset = Vector2{0, -0.1f},
                .parent = entity,
                .alignmentFlags = transform::InheritedProperties::Alignment::VERTICAL_TOP | transform::InheritedProperties::Alignment::HORIZONTAL_CENTER};
            // TODO: implement createDetailedTooltip
            // uiConfig->hPopup = createDetailedTooltip(uiConfig->detailedTooltip.value());

            uiConfig->hPopupConfig = std::make_shared<UIConfig>(config);
        }

        // Step 4: Call the base Node hover function
        if (node->methods.onHover)
        {
            node->methods.onHover(registry, entity);
        }
    }

    void element::StopHover(entt::registry &registry, entt::entity entity)
    {
        auto *node = registry.try_get<transform::GameObject>(entity);
        auto *uiConfig = registry.try_get<UIConfig>(entity);

        AssertThat(node, Is().Not().EqualTo(nullptr));
        AssertThat(uiConfig, Is().Not().EqualTo(nullptr));

        if (node->methods.onStopHover)
        {
            node->methods.onStopHover(registry, entity);
        }
        
        SPDLOG_DEBUG("StopHover(): Stopping hover for entity: {}", static_cast<int>(entity));

        if (uiConfig && uiConfig->onDemandTooltip)
        {
            registry.destroy(*uiConfig->hPopup); // Remove the tooltip UIBox entity
            uiConfig->hPopup = std::nullopt;     // Clear the reference
        }
    }

    void element::Release(entt::registry &registry, entt::entity entity, entt::entity objectBeingDragged)
    {
        auto *uiElement = registry.try_get<UIElementComponent>(entity);
        auto *node = registry.try_get<transform::GameObject>(entity);

        // TODO: question, should this call release on the corresponding node? Assuming so, since ui elements are also nodes and transforms.
        // TODO: other seems to be the object being dragged, if any.
        // if (node->methods.onRelease)
        // {
        //     node->methods.onRelease(registry, entity, objectBeingDragged);
        // }
        
        if (uiElement && registry.valid(*node->parent))
        {
            Release(registry, *node->parent, objectBeingDragged); // Propagate release event to parent
        }
    }
}
