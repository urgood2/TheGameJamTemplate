#include "element.hpp"

#include "systems/reflection/reflection.hpp"
#include "systems/text/textVer2.hpp"
#include "core/globals.hpp"
#include "util/utilities.hpp"

namespace ui
{
    //TODO: update function registry for methods that replace transform-provided methods

    // TODO: two of these?
    entt::entity element::Initialize(
        entt::registry &registry,
        entt::entity parent,
        entt::entity uiBox,
        UITypeEnum type,
        std::optional<UIConfig> config)
    {
        entt::entity entity = transform::CreateOrEmplace(&registry, globals::gameWorldContainerEntity, 0, 0, 0, 0); // values are set up in set_values

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
        auto &node = registry.get<transform::GameObject>(entity);
        node.parent = parent;
        // node.debug.debugText = fmt::format("UIElement {}", static_cast<int>(entity));

        if (config && config->object)
        {
            // TODO: does this mean objects attached to a ui element also need to have a ui element component? or can this be moved elsewhere?
            // TODO: think of a more logical place for parent variable (perhaps node?)
            // auto &objectUIElement = registry.get<UIElementComponent>(config->object.value());
            auto &objectUINode = registry.get<transform::GameObject>(config->object.value());
            objectUINode.parent = entity;
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
                transform::CreateOrEmplace(&registry, globals::gameWorldContainerEntity, transformReference.x, transformReference.y, transformReference.w, transformReference.h, entity);
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
        }\

        // Assign role within UI hierarchy
        transform::AssignRole(&registry, entity, transform::InheritedProperties::Type::RoleInheritor,
                           uiElement->uiBox,
                           transform::InheritedProperties::Sync::Strong,
                           transform::InheritedProperties::Sync::Strong,
                           transform::InheritedProperties::Sync::Weak,
                           transform::InheritedProperties::Sync::Weak,
                           Vector2{transformReference.x, transformReference.y});

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
            case UITypeEnum::VERTICAL_CONTAINER:
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
                input::AddNodeToInputRegistry(registry, globals::inputState, uiConfig->button_UIE.value_or(entity), uiConfig->focusArgs->button.value());
            }
            if (uiConfig->focusArgs->snap_to)
            {
                input::SnapToNode(registry, globals::inputState, entity);
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

        // Ensure the entity is a valid UIElement
        if (!uiElement || !uiConfig || !transform)
        {
            return std::string(indent, ' ') + "| MISSING COMPONENTS |\n";
        }

        // Determine the UI type as a string
        std::string UIT(magic_enum::enum_name(uiElement->UIT));

        // Build the topology string with indentation
        std::string boxStr = fmt::format("\n{}| {} | - ID: {} [entt-{}] w/h: {}/{} UIElement children: {} | LOC({},{}) OFF({},{}) OFF_ALN({},{}) {}",
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
            node->state.isBeingHovered ? "HOVERED" : "");

        // If this is an "Object" (UIT == "O"), determine object type
        if (uiElement->UIT == UITypeEnum::OBJECT)
        {
            std::string objectType = "OTHER";

            if (uiConfig->object)
            {
                auto *objTransform = registry.try_get<transform::Transform>(*uiConfig->object);

                // Check object type based on class assumptions (this should be refined)
                // LATER: add these in later
                if (registry.try_get<UIBoxComponent>(*uiConfig->object))
                    objectType = "UIBox";
                else if (registry.try_get<TextSystem::Text>(*uiConfig->object)) 
                    objectType = "Text";
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
        transform::MoveWithMaster(&registry, entity, 0);
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
            UpdateText(registry, entity);
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
                transform::MoveWithMaster(&registry, objectEntity, 0);
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

    void element::DrawChildren(std::shared_ptr<layer::Layer> layerPtr, entt::registry &registry, entt::entity entity)
    {

        auto *uiElement = registry.try_get<UIElementComponent>(entity);
        auto *uiConfig = registry.try_get<UIConfig>(entity);
        auto *node = registry.try_get<transform::GameObject>(entity);

        AssertThat(uiElement, Is().Not().EqualTo(nullptr));
        AssertThat(uiConfig, Is().Not().EqualTo(nullptr));
        AssertThat(node, Is().Not().EqualTo(nullptr));

        // If element (node) is not visible, skip drawing
        if (!node->state.visible)
            return;

        for (auto childEntry : node->orderedChildren)
        {
            auto child = childEntry;
            auto *childConfig = registry.try_get<UIConfig>(child);
            if (!childConfig)
                continue;

            // Skip elements with a `draw_layer` or special names

            // TODO: document h_popup and alert?
            // TODO: ensure that config->id is always set (to value in children map?)
            if (childConfig->drawLayer || childConfig->id == "h_popup" || childConfig->id == "alert")
                continue;

            // Draw first if `draw_after` is false
            if (!childConfig->draw_after)
            {
                DrawSelf(layerPtr, registry, child);
            }

            // Recursively draw children
            DrawChildren(layerPtr, registry, child);

            // Draw again if `draw_after` is true
            if (childConfig->draw_after)
            {
                DrawSelf(layerPtr, registry, child);
            }
        }
    }

    auto createTooltipUIBox(entt::registry &registry, entt::entity parent, ui::Tooltip tooltip) -> UIElementTemplateNode {

        ui::UIElementTemplateNode title = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::TEXT)
            .addConfig(
                ui::UIConfig::Builder::create()
                    .addText(tooltip.title.value_or("Tooltip Title"))
                    .addColor(WHITE)
                    .addAlign(transform::InheritedProperties::Alignment::HORIZONTAL_CENTER | transform::InheritedProperties::Alignment::VERTICAL_CENTER)
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

        float padding = uiConfig->padding.value_or(globals::uiPadding);
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

            transform->setActualW(transform->getActualW() * scaling);
            transform->setActualH(transform->getActualH() * scaling);
            uiState->contentDimensions = {transform->getActualW(), transform->getActualH()};
            uiConfig->scale = uiConfig->scale.value_or(1.0f) * scaling;

            //TODO: custom code for text, object, etc. which need special handling for scaling

            SPDLOG_DEBUG("Applying scaling factor to entity {} resulted in width: {}, height: {}, content dimensions: {}, scale: {}",
                        static_cast<int>(entity), transform->getActualW(), transform->getActualH(), uiState->contentDimensions->x, uiConfig->scale.value_or(1.0f));
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

            SPDLOG_DEBUG("Applying alignment to entity {} with x: {}, y: {}, resulted in offset x: {}, y: {}. This entity has {} children.",
                        static_cast<int>(entity), x, y, role->offset->x, role->offset->y, node->children.size());
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

            float padding = config->padding.value_or(globals::uiPadding);

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
                        childConfig->uiType == UITypeEnum::OBJECT)
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

    void element::UpdateText(entt::registry &registry, entt::entity entity)
    {
        auto *config = registry.try_get<UIConfig>(entity);
        auto *state = registry.try_get<UIState>(entity);

        AssertThat(config, Is().Not().EqualTo(nullptr));
        AssertThat(state, Is().Not().EqualTo(nullptr));

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
                    ui::box::Recalculate(registry, entity);
                }

                // Store updated text
                config->prev_ref_value = value;
            }
        }
    }

    void element::UpdateObject(entt::registry &registry, entt::entity entity)
    {
        auto *config = registry.try_get<UIConfig>(entity);

        AssertThat(config, Is().Not().EqualTo(nullptr));

        // Step 1: Update the object reference if it has changed
        if (config->ref_component && config->ref_value)
        {
            auto comp = reflection::retrieveComponent(&registry, config->ref_entity.value(), config->ref_component.value());
            auto value = reflection::retrieveFieldByString(comp, config->ref_component.value(), config->ref_value.value());
            if (value != config->prev_ref_value)
            {
                config->object = value.cast<entt::entity>();
                ui::box::Recalculate(registry, entity);
            }
        }

        // Step 2: Ensure object exists before proceeding
        if (!config->object)
            return;

        auto *objectConfig = registry.try_get<UIConfig>(config->object.value());
        auto *objectState = registry.try_get<UIState>(config->object.value());
        auto *objectNode = registry.try_get<transform::GameObject>(config->object.value());
        auto *objectTransform = registry.try_get<transform::Transform>(config->object.value());

        if (!objectConfig) {
            SPDLOG_ERROR("Object {} does not exist or is missing components.", static_cast<int>(config->object.value()));
            return;
        }

        // Step 3: Refresh object movement state
        objectConfig->refreshMovement = true;

        // Step 4: Handle hover state synchronization
        auto *elementState = registry.try_get<UIState>(entity);
        auto *elementNode = registry.try_get<transform::GameObject>(entity);

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

        // Step 5: Handle object updates
        if (objectConfig->ui_object_updated)
        {
            objectConfig->ui_object_updated = false;

            objectConfig->parent = entity;

            // Assign role
            if (config->role)
            {
                transform::AssignRole(&registry, config->object.value(), config->role->role_type, config->role->master, config->role->location_bond, config->role->size_bond, config->role->rotation_bond, config->role->scale_bond, config->role->offset);
            }
            else
            {
                transform::AssignRole(&registry, config->object.value(), transform::InheritedProperties::Type::RoleInheritor, entity);
            }

            // Move object relative to parent
            transform::MoveWithMaster(&registry, config->object.value(), 0);

            // Adjust parent dimensions & alignments
            if (objectConfig->non_recalc)
            { // TODO: there is also no_recalc. what is the difference?
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
                ui::box::RenewAlignment(registry, entity);
            }
        }
    }

    // TODO: check logic, ensure working properly, refactor logic to be more readable (test with various ui types and configurations)
    void element::DrawSelf(std::shared_ptr<layer::Layer> layerPtr, entt::registry &registry, entt::entity entity)
    {
        ::util::Profiler profiler("DrawSelf");
        auto *uiElement = registry.try_get<UIElementComponent>(entity);
        auto *config = registry.try_get<UIConfig>(entity);
        auto *state = registry.try_get<UIState>(entity);
        auto *node = registry.try_get<transform::GameObject>(entity);
        auto *transform = registry.try_get<transform::Transform>(entity);

        AssertThat(uiElement, Is().Not().EqualTo(nullptr));
        AssertThat(config, Is().Not().EqualTo(nullptr));
        AssertThat(state, Is().Not().EqualTo(nullptr));
        AssertThat(node, Is().Not().EqualTo(nullptr));
        AssertThat(transform, Is().Not().EqualTo(nullptr));
        
        auto actualX = transform->getActualX();
        auto actualY = transform->getActualY();
        auto actualW = transform->getActualW();
        auto actualH = transform->getActualH();
        auto visualX = transform->getVisualX();
        auto visualY = transform->getVisualY();
        auto visualW = transform->getVisualW();
        auto visualH = transform->getVisualH();

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
            auto parentEntity = node->parent.value();
            Vector2 parentParallax = {0, 0};

            auto *parentElement = registry.try_get<UIElementComponent>(parentEntity);
            auto *parentNode = registry.try_get<transform::GameObject>(parentEntity);

            float parentLayerX = (registry.valid(parentEntity) && parentEntity != uiElement->uiBox) ? parentNode->layerDisplacement->x : 0;
            float parentLayerY = (registry.valid(parentEntity) && parentEntity != uiElement->uiBox) ? parentNode->layerDisplacement->y : 0;

            float shadowOffsetX = (config->shadow ? 0.4f * node->shadowDisplacement->x : 0) ;
            float shadowOffsetY = (config->shadow ? 0.4f * node->shadowDisplacement->y : 0) ;

            // node->layerDisplacement->x = parentLayerX + shadowOffsetX;
            // node->layerDisplacement->y = parentLayerY + shadowOffsetY;
            
            node->layerDisplacement->x = parentLayerX;
            node->layerDisplacement->y = parentLayerY;

            // This code applies a parallax effect to the button when it is clicked, hovered, or dragged while the cursor is down. The button moves slightly in the direction of its shadow displacement, giving a depth effect, and it resets parallaxDist to avoid continuous movement.
            if (config->buttonCallback && ((state->last_clicked && state->last_clicked.value() > main_loop::mainLoop.realtimeTimer - 0.1f) || ((config->buttonCallback && (node->state.isBeingHovered || node->state.isBeingDragged)))) && globals::inputState.is_cursor_down)
            {

                node->layerDisplacement->x -= parallaxDist * node->shadowDisplacement->x;
                node->layerDisplacement->y -= parallaxDist * 1.8f * node->shadowDisplacement->y;
                parallaxDist = 0;
                buttonBeingPressed = true;
                
                SPDLOG_DEBUG("Button being pressed: {}, setting layer displacement to x: {}, y: {}", buttonBeingPressed, node->layerDisplacement->x, node->layerDisplacement->y);
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
            float textParallaxSX = node->shadowDisplacement->x * globals::fontData.fontLoadedSize * 0.04f / (config->scale.value() * globals::fontData.fontScale);
            float textParallaxSY = node->shadowDisplacement->y * globals::fontData.fontLoadedSize * -0.03f / (config->scale.value() * globals::fontData.fontScale);

            bool drawShadow = (config->button_UIE && buttonActive) || (!config->button_UIE && config->shadow && globals::settings.shadowsOn);

            if (drawShadow)
            {
                // util::PrepDraw(layerPtr, registry, entity, 0.97f);
                layer::AddPushMatrix(layerPtr);
                Vector2 layerDisplacement = {node->layerDisplacement->x, node->layerDisplacement->y};
                layer::AddTranslate(layerPtr, actualX + textParallaxSX + layerDisplacement.x, actualY + textParallaxSY + layerDisplacement.y);
                
                if (config->verticalText)
                {
                    layer::AddTranslate(layerPtr, 0, actualH);
                    layer::AddRotate(layerPtr, -PI / 2);
                }
                if ((config->shadow || (config->button_UIE && buttonActive)) && globals::settings.shadowsOn)
                {
                    Color shadowColor = Color{0, 0, 0, static_cast<unsigned char>(config->color->a * 0.3f)};

                    //TODO: figure out how this scaling works?
                    float textX = globals::fontData.fontRenderOffset.x + (config->verticalText ? textParallaxSY : textParallaxSX) * config->scale.value_or(1.0f) * globals::fontData.fontScale;
                    float textY = globals::fontData.fontRenderOffset.y + (config->verticalText ? textParallaxSX : textParallaxSY) * config->scale.value_or(1.0f) * globals::fontData.fontScale;
                    float fontScale = config->scale.value_or(1.0f) * globals::fontData.fontScale;
                    float spacing = config->textSpacing.value_or(globals::fontData.spacing);   
                    
                    layer::AddTextPro(layerPtr, config->text.value(), globals::fontData.font, textX, textY, {0, 0}, 0, fontScale * globals::fontData.fontLoadedSize, spacing, shadowColor);
                    
                    //TODO: no such thing as x scale and y scale in raylib. Just add spacing and font size to the globals (spacing to replace squish)

                    // text offset and spacing and fontscale are configurable values that are added to font rendering (scale changes font scaling), squish also does this (ussually 1), and offset is different for different font types. render_scale is the size at which the font is initially loaded.
                }

                layer::AddPopMatrix(layerPtr);
            }

            // util::PrepDraw(layerPtr, registry, entity, 1.0f);
            layer::AddPushMatrix(layerPtr);
            Vector2 layerDisplacement = {node->layerDisplacement->x, node->layerDisplacement->y};
            layer::AddTranslate(layerPtr, actualX + layerDisplacement.x, actualY + layerDisplacement.y);
            if (config->verticalText)
            {
                layer::AddTranslate(layerPtr, 0, actualH);
                layer::AddRotate(layerPtr, -PI / 2);
            }
            Color renderColor = config->color.value();
            if (buttonActive == false)
            {
                renderColor = globals::uiTextInactive;
            }
            
            float textX = globals::fontData.fontRenderOffset.x * config->scale.value_or(1.0f) * globals::fontData.fontScale;
            float textY = globals::fontData.fontRenderOffset.y * config->scale.value_or(1.0f) * globals::fontData.fontScale;
            float fontScale = config->scale.value_or(1.0f) * globals::fontData.fontScale;
            float spacing = config->textSpacing.value_or(globals::fontData.spacing);
            
            layer::AddTextPro(layerPtr, config->text.value(), globals::fontData.font, textX, textY, {0, 0}, 0, fontScale * globals::fontData.fontLoadedSize, spacing, renderColor);

            layer::AddPopMatrix(layerPtr);
        }
        else if (config->uiType == UITypeEnum::RECT_SHAPE || config->uiType == UITypeEnum::VERTICAL_CONTAINER || config->uiType == UITypeEnum::HORIZONTAL_CONTAINER || config->uiType == UITypeEnum::ROOT)
        {
            //TODO: need to apply scale and rotation to the rounded rectangle - make a prepdraw method that applies the transform's values
            layer::AddPushMatrix(layerPtr);
            if (config->shadow && globals::settings.shadowsOn)
            {
                layer::AddScale(layerPtr, 0.98f, 0.98f);

                Color shadowColor = Color{0, 0, 0, static_cast<unsigned char>(config->color->a * 0.3f)};
                if (config->shadowColor)
                {
                    shadowColor = config->shadowColor.value();
                }
                util::DrawSteppedRoundedRectangle(layerPtr, registry, entity, ui::RoundedRectangleVerticesCache_TYPE_SHADOW, parallaxDist);
                    
                layer::AddScale(layerPtr, 1 / 0.98f, 1 / 0.98f);
            }

            // float scale = buttonBeingPressed ? 0.990f : 1.0f;
            // layer::AddScale(layerPtr, scale, scale);
            
            
            auto collidedButton = config->button_UIE.value_or(entity);
            
            // if self is a button itself, ignore button UIE
            if (registry.get<UIConfig>(entity).buttonCallback) {
                collidedButton = entity;
            }
            
              
            
            auto &collidedButtonConfig = registry.get<UIConfig>(collidedButton);
            auto &collidedButtonNode = registry.get<transform::GameObject>(collidedButton);
            auto &collidedButtonUIState = registry.get<UIState>(collidedButton);
            
            // draw embossed rectangle
            if (config->emboss)
            {
                Color c = ColorBrightness(config->color.value(), collidedButtonNode.state.isBeingHovered ? -0.8f : -0.5f);
                util::DrawSteppedRoundedRectangle(layerPtr, registry, entity, ui::RoundedRectangleVerticesCache_TYPE_EMBOSS, parallaxDist, {{"emboss", c}});
            } 
        
            
            // darken if button is on cooldown
            Color buttonColor = config->buttonDelay ? util::MixColours(config->color.value(), BLACK, 0.5f) : config->color.value();
            bool collidedButtonHovered = collidedButtonConfig.hover && collidedButtonNode.state.isBeingHovered; 

            if (collidedButtonNode.state.isBeingHovered && (entity == (entt::entity)85)) {
                // SPDLOG_DEBUG("DrawSelf(): Button is being hovered: {}", collidedButtonNode.state.isBeingHovered);
            }

            //DONE: hover over container applies hover to all child entities. Why? THe hover state itself doesn't propagate to children. ANSWER: button UIE enabled for parents who are buttons.

            bool clickedRecently = collidedButtonUIState.last_clicked && collidedButtonUIState.last_clicked.value() > main_loop::mainLoop.realtimeTimer - 0.1f;
            

            std::optional<Color> specialColor;
            // if (collidedButtonHovered)
            //     SPDLOG_DEBUG("DrawSelf(): Button is being hovered: {}", static_cast<int>(entity));
            // if (clickedRecently)
            //     SPDLOG_DEBUG("DrawSelf(): Button is being clicked: {}", static_cast<int>(entity));
            if (collidedButtonHovered || clickedRecently)
            {
                specialColor = ColorBrightness(buttonColor, -0.5f);
                // specialColor = BLACK;
            }

            // std::vector<Color> colors = specialColor ? std::vector<Color>{buttonColor, specialColor.value()} : std::vector<Color>{buttonColor};
            std::vector<Color> colors = specialColor ? std::vector<Color>{specialColor.value()} : std::vector<Color>{buttonColor};
            // std::vector<Color> colors = specialColor ? std::vector<Color>{buttonColor} : std::vector<Color>{buttonColor};

            for (auto color : colors)
            {
                if (/*config->pixelatedRectangle && */visualW > 0.01)
                {
                    if (config->buttonDelay)
                    {
                        // gray background
                        util::DrawSteppedRoundedRectangle(layerPtr, registry, entity, ui::RoundedRectangleVerticesCache_TYPE_FILL, parallaxDist, {{"fill", color}});

                        // progress bar
                        util::DrawSteppedRoundedRectangle(layerPtr, registry, entity, ui::RoundedRectangleVerticesCache_TYPE_FILL, parallaxDist, {{"fill", color}}, config->buttonDelayProgress);

                    }
                    else if (config->progressBar)
                    {
                        auto colorToUse = config->progressBarEmptyColor.value_or(GRAY);

                        util::DrawSteppedRoundedRectangle(layerPtr, registry, entity, ui::RoundedRectangleVerticesCache_TYPE_FILL, parallaxDist, {{"fill", colorToUse}});

                        // DrawPixellatedRect(layerPtr, registry, entity, "fill", parallaxDist);
                        // colorToUse = config->progressBarFullColor.value_or(BLUE);

                        colorToUse = config->progressBarFullColor.value_or(BLUE);
                        
                        // retrieve the current progress bar value using reflection
                        auto component = reflection::retrieveComponent(&globals::registry, entity, config->progressBarValueComponentName.value());
                        auto value = reflection::retrieveFieldByString(component, config->progressBarValueComponentName.value(), config->progressBarValueFieldName.value());
                        float progress = value.cast<float>() / config->progressBarMaxValue.value_or(1.0f);
                        SPDLOG_DEBUG("Drawself(): Progress bar progress: {}", progress);
                        
                        util::DrawSteppedRoundedRectangle(layerPtr, registry, entity, ui::RoundedRectangleVerticesCache_TYPE_FILL, parallaxDist, {{"progress", colorToUse}}, std::nullopt, progress);
                    }
                    else
                    {
                        util::DrawSteppedRoundedRectangle(layerPtr, registry, entity, ui::RoundedRectangleVerticesCache_TYPE_FILL, parallaxDist, {{"fill", color}});
                        // SPDLOG_DEBUG("DrawSelf(): Drawing stepped rectangle with width: {}, height: {}", transform->getActualW(), transform->getActualH());
                    }
                }
                else
                {
                    layer::AddRectangle(layerPtr, 0, 0, actualW, actualH, color);
                    SPDLOG_DEBUG("DrawSelf(): Drawing rectangle with width: {}, height: {}", transform->getActualW(), transform->getActualH());
                }
            }

            layer::AddPopMatrix(layerPtr);
        }
        else if (config->uiType == UITypeEnum::OBJECT && config->object)
        {
            //TODO: this part needs fixing
            // hightlighted object outline
            auto &objectNode = registry.get<transform::GameObject>(config->object.value());
            if (config->focusWithObject && objectNode.state.isBeingFocused)
            {
                state->object_focus_timer = state->object_focus_timer.value_or(main_loop::mainLoop.realtimeTimer);
                float lw = 50.0f * std::pow(std::max(0.0f, (state->object_focus_timer.value() - main_loop::mainLoop.realtimeTimer + 0.3f)), 2);
                // util::PrepDraw(layerPtr, registry, entity, 1.0f);
                Color c = util::AdjustAlpha(WHITE, 0.2f * lw);
                util::DrawSteppedRoundedRectangle(layerPtr, registry, entity, ui::RoundedRectangleVerticesCache_TYPE_FILL, parallaxDist, {{"fill", c}});
                c = config->color->a > 0.01f ? util::MixColours(WHITE, config->color.value(), 0.8f) : WHITE;
                util::DrawSteppedRoundedRectangle(layerPtr, registry, entity, ui::RoundedRectangleVerticesCache_TYPE_OUTLINE, parallaxDist, {{"outline", c}}, std::nullopt, lw + 1.5f);
                layer::AddPopMatrix(layerPtr);
            }
            else
            {
                state->object_focus_timer.reset();
            }
        }

        // outline
        if (config->outlineColor && config->outlineColor->a > 0.01f)
        {
            if (config->outlineThickness)
            {
                // util::PrepDraw(layerPtr, registry, entity, 1.0f);
                float lineWidth = config->outlineThickness.value();
                if (config->line_emboss)
                {
                    Color c = ColorBrightness(config->outlineColor.value(), node->state.isBeingHovered ? 0.5f : 0.3f);
                    util::DrawSteppedRoundedRectangle(layerPtr, registry, entity, ui::RoundedRectangleVerticesCache_TYPE_LINE_EMBOSS, parallaxDist, {{"outline_emboss", c}}, std::nullopt, lineWidth);
                }
                if (transform->getVisualW() > 0.01)
                {
                    util::DrawSteppedRoundedRectangle(layerPtr, registry, entity, ui::RoundedRectangleVerticesCache_TYPE_OUTLINE, parallaxDist, {{"outline", config->outlineColor.value()}}, std::nullopt, lineWidth);
                }
            }
        }

        // highlighted button outline (only when mouse not active)
        if (node->state.isBeingFocused && globals::inputState.hid.mouse_enabled == false && IsCursorHidden() == true)
        {
            state->focus_timer = state->focus_timer.value_or(main_loop::mainLoop.realtimeTimer);
            float lw = 50.0f * std::pow(std::max(0.0f, (state->focus_timer.value() - main_loop::mainLoop.realtimeTimer + 0.3f)), 2);
            // util::PrepDraw(layerPtr, registry, entity, 1.0f);
            Color c = Fade(WHITE, 0.2f * lw);

            util::DrawSteppedRoundedRectangle(layerPtr, registry, entity, ui::RoundedRectangleVerticesCache_TYPE_FILL, parallaxDist, {{"fill", c}}, std::nullopt, lw + 4.0f);
            //TODO: refactor this whole method later

            c = config->color->a > 0.01f ? util::MixColours(WHITE, config->color.value(), 0.8f) : WHITE;

            util::DrawSteppedRoundedRectangle(layerPtr, registry, entity, ui::RoundedRectangleVerticesCache_TYPE_OUTLINE, parallaxDist, {{"outline", c}}, std::nullopt, lw + 4.f);
            
        }
        else
        {
            state->focus_timer.reset();
        }

        // draw "selection" triangle (arrow pointing to selected object)
        if (config->chosen)
        {
            // layer::AddScale(layerPtr, .98f, .98f);
            // util::PrepDraw(layerPtr, registry, entity, 0.98f);
            if (config->shadow && globals::settings.shadowsOn)
            {
                Color shadowColor = Color{0, 0, 0, static_cast<unsigned char>(config->color->a * 0.3f)};
                auto points = util::GetChosenTriangleFromRect(node->layerDisplacement->x - node->shadowDisplacement->x * parallaxDist * 0.5f, node->layerDisplacement->y - node->shadowDisplacement->y * parallaxDist * 0.5f, transform->getActualW(), transform->getActualH(), config->chosen_vert == "vert");
                layer::AddPolygon(layerPtr, points, shadowColor);
            };
            // layer::AddPopMatrix(layerPtr);

            // util::PrepDraw(layerPtr, registry, entity, 1.0f);
            layer::AddPolygon(layerPtr, util::GetChosenTriangleFromRect(node->layerDisplacement->x, node->layerDisplacement->y, transform->getActualW(), transform->getActualH() , config->chosen_vert == "vert"), RED);
        }

        // call the object's own lambda draw function, if it has one
        if (node->drawFunction) {
            // util::PrepDraw(layerPtr, registry, entity, 0.98f);
            node->drawFunction(layerPtr, registry, entity);
            // layer::AddPopMatrix(layerPtr);
        }
        
        //TODO: enable this back later
        // transform::DrawBoundingBoxAndDebugInfo(&registry, entity, layerPtr);

        profiler.Stop();
    }
    

    void element::Update(entt::registry &registry, entt::entity entity, float dt)
    {
        // Retrieve components
        auto *uiConfig = registry.try_get<UIConfig>(entity);
        auto *transform = registry.try_get<transform::Transform>(entity);
        auto *uiElement = registry.try_get<UIElementComponent>(entity);
        auto *node = registry.try_get<transform::GameObject>(entity);

        AssertThat(uiConfig, Is().Not().EqualTo(nullptr));
        AssertThat(transform, Is().Not().EqualTo(nullptr));
        AssertThat(uiElement, Is().Not().EqualTo(nullptr));
        AssertThat(node, Is().Not().EqualTo(nullptr));

        // REVIEW: not tracking fucntion calls

        // Handle button delay
        if (uiConfig->buttonDelay)
        {
            if (uiConfig->buttonCallback)
                uiConfig->buttonTemp = uiConfig->buttonCallback;
            uiConfig->buttonCallback = std::nullopt;
            uiConfig->buttonDelayProgress = (main_loop::mainLoop.realtimeTimer - uiConfig->buttonDelayStart.value()) / uiConfig->buttonDelay.value();

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
            UpdateText(registry, entity);
        }

        // Handle object update
        if (uiElement->UIT == UITypeEnum::OBJECT)
        {
            UpdateObject(registry, entity);
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
                input::ModifyCurrentCursorContextLayer(registry, globals::inputState, -1);
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
                std::vector<entt::entity> choices = ui::box::GetGroup(registry, entity, uiConfig->group.value_or(""));

                for (auto choiceEntity : choices)
                {
                    auto *choiceConfig = registry.try_get<UIConfig>(choiceEntity);
                    if (choiceConfig && choiceConfig->choice)
                    {
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
        if (globals::inputState.text_input_hook && globals::inputState.text_input_hook.value() == entity)
        {
            globals::inputState.text_input_hook.reset();
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
        
        SPDLOG_DEBUG("ApplyHover(): Applying hover for entity: {}", static_cast<int>(entity));

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
        auto &controller = globals::inputState;
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
        node->methods->onHover(registry, entity);
    }

    void element::StopHover(entt::registry &registry, entt::entity entity)
    {
        auto *node = registry.try_get<transform::GameObject>(entity);
        auto *uiConfig = registry.try_get<UIConfig>(entity);

        AssertThat(node, Is().Not().EqualTo(nullptr));
        AssertThat(uiConfig, Is().Not().EqualTo(nullptr));

        if (node->methods->onStopHover)
        {
            node->methods->onStopHover(registry, entity);
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
        node->methods->onRelease(registry, entity, objectBeingDragged);

        if (uiElement && registry.valid(*node->parent))
        {
            Release(registry, *node->parent, objectBeingDragged); // Propagate release event to parent
        }
    }
}