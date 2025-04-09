#include "box.hpp"

#include "systems/text/textVer2.hpp"
#include "components/graphics.hpp"
#include "inventory_ui.hpp"
namespace ui
{
    // TODO: update function registry for methods that replace transform-provided methods

    // TODO: make sure all methods take into account that children can be uiboxes as well

    void LogChildrenOrder(entt::registry& registry, entt::entity parent) {
        auto& parentNode = registry.get<transform::GameObject>(parent);
        SPDLOG_DEBUG("Children of entity {}:", static_cast<int>(parent));
        for (const auto& [id, child] : parentNode.children) {
            SPDLOG_DEBUG("  - ID: {}, Entity: {}", id, static_cast<int>(child));
        }
    }    

    // 
    void box::BuildUIElementTree(entt::registry &registry, entt::entity uiBoxEntity, UIElementTemplateNode &rootDef, entt::entity uiElementParent)
    {
        struct StackEntry {
            UIElementTemplateNode* def;
            entt::entity parent;
        };

        std::stack<StackEntry> stack;
        std::unordered_map<UIElementTemplateNode*, entt::entity> nodeToEntity;

        stack.push({&rootDef, uiElementParent});

        while (!stack.empty()) {
            auto [def, parent] = stack.top();
            stack.pop();

            // Create new UI element
            entt::entity entity = element::Initialize(registry, parent, uiBoxEntity, def->type, def->config);
            nodeToEntity[def] = entity;
            auto* config = registry.try_get<UIConfig>(entity);

            SPDLOG_DEBUG("Initialized UI element of type {}: entity = {}, parent = {}", magic_enum::enum_name<UITypeEnum>(def->type), static_cast<int>(entity), static_cast<int>(parent));

            auto* parentConfig = registry.try_get<UIConfig>(parent);

            // Apply inherited config values
            if (registry.valid(parent) && parentConfig) {
                if (parentConfig->group) {
                    if (config) config->group = parentConfig->group;
                    else registry.emplace<UIConfig>(entity).group = parentConfig->group;
                }

                if (parentConfig->buttonCallback) {
                    if (config) config->button_UIE = parent;
                    else registry.emplace<UIConfig>(entity).button_UIE = parent;
                }

                if (parentConfig->button_UIE) {
                    if (config) config->button_UIE = parentConfig->button_UIE;
                    else registry.emplace<UIConfig>(entity).buttonCallback = parentConfig->buttonCallback;
                }

            }

            // If object + button
            if (def->type == UITypeEnum::OBJECT && config && config->buttonCallback) {
                auto& node = registry.get<transform::GameObject>(config->object.value());
                node.state.clickEnabled = false;
            }

            // If text, pre-calculate text bounds
            if (def->type == UITypeEnum::TEXT && config && config->text) {
                float scale = config->scale.value_or(1.0f);
                float fontSize = globals::fontData.fontLoadedSize * scale * globals::fontData.fontScale;
                auto [w, h] = MeasureTextEx(globals::fontData.font, config->text->c_str(), fontSize, globals::fontData.spacing);
                if (config->verticalText.value_or(false)) std::swap(w, h);
                //FIXME: testing, commenting out
                // config->minWidth = w;
                // config->minHeight = h;
            }

            // Handle root element
            if (!registry.valid(parent)) {
                auto* box = registry.try_get<UIBoxComponent>(uiBoxEntity);
                box->uiRoot = entity;
                registry.get<transform::GameObject>(entity).parent = uiBoxEntity;
            } else {
                auto& thisConfig = registry.get<UIConfig>(entity);
                if (!thisConfig.id) {
                    auto& parentGO = registry.get<transform::GameObject>(parent);

                    int idx = static_cast<int>(parentGO.children.size());
                    thisConfig.id = std::to_string(idx);
                    
                }
                auto& parentGO = registry.get<transform::GameObject>(parent);
                const auto& id = thisConfig.id.value();

                AssertThat(parentGO.children.find(id) == parentGO.children.end(), Is().EqualTo(true)); // check for duplicate ids
                
                parentGO.children[thisConfig.id.value()] = entity;
                parentGO.orderedChildren.push_back(entity);
                SPDLOG_DEBUG("Inserted child into parent {}: ID = {}, Entity = {}", static_cast<int>(parent), thisConfig.id.value(), static_cast<int>(entity));
            }

            if (def->config.mid) {
                auto& boxTransform = registry.get<transform::Transform>(uiBoxEntity);
                boxTransform.middleEntityForAlignment = entity;
            }

            // Push children in reverse order so the first child is processed first
            if (def->type == UITypeEnum::VERTICAL_CONTAINER || def->type == UITypeEnum::HORIZONTAL_CONTAINER || def->type == UITypeEnum::ROOT) {
                SPDLOG_DEBUG("Processing children for container entity {} (type: {})", static_cast<int>(entity), magic_enum::enum_name<UITypeEnum>(def->type));
                for (int i = static_cast<int>(def->children.size()) - 1; i >= 0; --i) {
                    // Only assign an ID if one hasn't already been set
                    if (!def->children[i].config.id.has_value()) {
                        def->children[i].config.id = std::to_string(i); // or use indexToAlphaID(i)
                    }
                    stack.push({&def->children[i], entity});
                }
            }
        }
    }

    
    // must be existing & initialized uibox (by calling initialize() )
    void box::RenewAlignment(entt::registry &registry, entt::entity self)
    {
        
        auto &definition = registry.get<UIElementTemplateNode>(self);
        auto &config = registry.get<UIConfig>(self);

        // Initialize transform component
        auto &transform = registry.get<transform::Transform>(self);

        // Setup Role component already done
        
        // Initialize node component (handles interaction state)
        auto &node = registry.get<transform::GameObject>(self);
        auto &uiBox = registry.get<UIBoxComponent>(self);
        auto &uiBoxRole = registry.get<transform::InheritedProperties>(self);
        auto uiRoot = uiBox.uiRoot.value();
        auto &uiRootRole = registry.get<transform::InheritedProperties>(uiRoot);
        auto &uiRootConfig = registry.get<UIConfig>(uiRoot);
        
        // First, set parent-child relationships to create the tree structure
        // BuildUIElementTree(registry, self, definition, entt::null);
        // auto *uiBox = registry.try_get<UIBoxComponent>(self);
        // auto *uiBoxRole = registry.try_get<transform::InheritedProperties>(self);
        // auto uiRoot = uiBox->uiRoot.value();
        // // Set the midpoint for any future alignments to use
        // transform.middleEntityForAlignment = uiRoot;
        // auto &uiRootRole = registry.get<transform::InheritedProperties>(uiRoot);

        // Calculate the correct and width/height and offset for each node
        CalcTreeSizes(registry, uiRoot, {transform.getActualX(), transform.getActualY(), transform.getActualW(), transform.getActualH()}, true);

        transform::AlignToMaster(&registry, self);

        uiRootRole.offset = uiBoxRole.offset;

        // start with root entity.
        auto &uiElementComp = registry.get<UIElementComponent>(uiRoot);
        // start with uibox's offset values so we align to that, w and h are unused.
        ui::LocalTransform runningTransform{uiBoxRole.offset->x, uiBoxRole.offset->y, 0.f, 0.f};

        placeUIElementsRecursively(registry, uiRoot, runningTransform, UITypeEnum::VERTICAL_CONTAINER, uiRoot);

        handleAlignment(registry, uiRoot);

        // LATER: LR clamp not implemented, not sure if necessary

        ui::element::InitializeVisualTransform(registry, uiRoot);
    }

    entt::entity box::Initialize(entt::registry &registry, const TransformConfig &transformData,
                                 UIElementTemplateNode definition, std::optional<UIConfig> config)
    {
        auto self = transform::CreateOrEmplace(&registry, globals::gameWorldContainerEntity, transformData.x, transformData.y, transformData.w, transformData.h);

        // Initialize transform component
        auto &transform = registry.get<transform::Transform>(self);
        transform.setActualRotation(transformData.r);

        // Store UIBox definition, which contains schematic
        registry.emplace<UIElementTemplateNode>(self, definition);
        if (config)
            registry.emplace<UIConfig>(self, config.value());
        registry.emplace<UIState>(self);
        registry.emplace<UIBoxComponent>(self);

        // Setup Role component (alignment & hierarchy) for the box
        if (config)
        {
            auto &role = registry.get<transform::InheritedProperties>(self);

            // copy values if role exists
            if (config->role)
            {
                role = config->role.value();
            }

            config->master = config->master.value_or(config->parent.value_or(self)); // Default to self if not specified

            // no role provided in config, use config's values or defaults
            if (!config->role)
            {
                role.master = config->master.value();
                role.location_bond = config->location_bond;
                role.size_bond = config->size_bond.value_or(transform::InheritedProperties::Sync::Weak);
                role.rotation_bond = config->rotation_bond.value_or(transform::InheritedProperties::Sync::Weak);
                role.scale_bond = config->scale_bond.value_or(transform::InheritedProperties::Sync::Weak);
                if (config->alignmentFlags)
                {
                    role.flags = transform::InheritedProperties::Alignment();
                    role.flags->alignment = config->alignmentFlags.value();
                }
                role.offset = config->offset.value_or(Vector2{0, 0});
            }
            // if role is set, use that instead

            transform::ConfigureAlignment(&registry, self, true, role.master, role.location_bond, role.size_bond.value_or(transform::InheritedProperties::Sync::Weak), role.rotation_bond.value_or(transform::InheritedProperties::Sync::Weak), role.scale_bond.value_or(transform::InheritedProperties::Sync::Weak), role.flags->alignment, role.flags->extraAlignmentFinetuningOffset);

            // TODO: config->align should overwrite role alignment? check this
            if (config->alignmentFlags)
            {
                role.flags = transform::InheritedProperties::Alignment();
                role.flags->alignment = config->alignmentFlags.value();
            }

            auto &node = registry.get<transform::GameObject>(self);
            node.parent = config->parent;
        }

        // Initialize node component (handles interaction state)
        auto &node = registry.get<transform::GameObject>(self);
        node.state.dragEnabled = false;                                  // UIBox is not draggable by default
        node.state.collisionEnabled = config->canCollide.value_or(true); // Default to true if not specified
        node.debug.debugText = fmt::format("UIBox {}", static_cast<int>(self));
        // Parent-child relationship setup (construct UI tree)

        // First, set parent-child relationships to create the tree structure
        BuildUIElementTree(registry, self, definition, entt::null);
        auto *uiBox = registry.try_get<UIBoxComponent>(self);
        auto *uiBoxRole = registry.try_get<transform::InheritedProperties>(self);
        auto uiRoot = uiBox->uiRoot.value();
        // Set the midpoint for any future alignments to use
        transform.middleEntityForAlignment = uiRoot;
        auto &uiRootRole = registry.get<transform::InheritedProperties>(uiRoot);

        // Calculate the correct and width/height and offset for each node
        CalcTreeSizes(registry, uiRoot, {transform.getActualX(), transform.getActualY(), transform.getActualW(), transform.getActualH()}, true);

        transform::AlignToMaster(&registry, self);

        uiRootRole.offset = uiBoxRole->offset;

        // start with root entity.
        auto &uiElementComp = registry.get<UIElementComponent>(uiRoot);
        // start with uibox's offset values so we align to that, w and h are unused.
        ui::LocalTransform runningTransform{uiBoxRole->offset->x, uiBoxRole->offset->y, 0.f, 0.f};

        placeUIElementsRecursively(registry, uiRoot, runningTransform, UITypeEnum::VERTICAL_CONTAINER, uiRoot);

        handleAlignment(registry, uiRoot); 
        // ui::element::SetAlignments(registry, uiRoot, uiBoxRole->offset, true);

        // auto final_WH = ui::element::SetWH(registry, uiRoot);

        // everything is in place, but if the ui box is aligned to something else, the offset for this is not applied since everything is based on 0,0 (respective to the ui box)

        // LATER: LR clamp not implemented, not sure if necessary

        ui::element::InitializeVisualTransform(registry, uiRoot);

        // If this is a root UIBox, store it in an instance list
        if (config->instanceType)
        {
            util::AddInstanceToRegistry(registry, self, *config->instanceType); // For now, the only alternative is POPUP
        }
        else
        {
            util::AddInstanceToRegistry(registry, self, "UIBOX");
        }

        return self;
    }

    auto box::handleAlignment(entt::registry &registry, entt::entity root) -> void
    {
        auto &uiConfig = registry.get<UIConfig>(root);
        auto &uiState = registry.get<UIState>(root);
        auto &node = registry.get<transform::GameObject>(root);
        auto &role = registry.get<transform::InheritedProperties>(root);
        auto &transform = registry.get<transform::Transform>(root);

        // generate stack

        struct StackEntry
        {
            entt::entity uiElement{entt::null};
            std::optional<float> scale;
        };

        std::vector<StackEntry> processingOrder;
        std::stack<StackEntry> stack;

        stack.push({root, uiConfig.scale.value_or(1.0f)}); // first (root) element

        // Step 1: Collect nodes in top-down order (DFS)
        while (!stack.empty())
        {
            auto entry = stack.top();
            stack.pop();
            processingOrder.push_back(entry);

            auto *node = registry.try_get<transform::GameObject>(entry.uiElement);
            if (!node)
                continue;

            // Push children onto stack (DFS order)
            for (auto childEntry : node->orderedChildren)
            {
                auto child = childEntry;
                if (registry.valid(child))
                {
                    auto &uiConfig = registry.get<UIConfig>(child);
                    auto &uiState = registry.get<UIState>(child);
                    stack.push({child, uiConfig.scale.value_or(1.0f)});
                }
            }
        }

        // traverse in bottom-up order
        for (auto it = processingOrder.rbegin(); it != processingOrder.rend(); ++it)
        {
            auto [entity, scale] = *it;
            auto &uiConfig = registry.get<UIConfig>(entity);
            auto &uiState = registry.get<UIState>(entity);
            auto &node = registry.get<transform::GameObject>(entity);
            auto &role = registry.get<transform::InheritedProperties>(entity);
            auto &transform = registry.get<transform::Transform>(entity);

            // no children & no alignment, skip

            if (node.children.size() == 0)
            {
                SPDLOG_DEBUG("Skipping alignment adjustment entity {} (parent {}) - no children", static_cast<int>(entity), static_cast<int>(node.parent.value_or(entt::null)));
                continue;
            }

            if ((!uiConfig.alignmentFlags || uiConfig.alignmentFlags.value_or(transform::InheritedProperties::Alignment::NONE) == transform::InheritedProperties::Alignment::NONE))
            {
                SPDLOG_DEBUG("Skipping alignment adjustment entity {} (parent {}) - no alignment", static_cast<int>(entity), static_cast<int>(node.parent.value_or(entt::null)));
                continue;
            }

            auto alignmentFlags = uiConfig.alignmentFlags.value();
            std::string alignmentString = "";
            if (alignmentFlags & transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                alignmentString += "VERTICAL_CENTER ";
            if (alignmentFlags & transform::InheritedProperties::Alignment::HORIZONTAL_CENTER)
                alignmentString += "HORIZONTAL_CENTER ";
            if (alignmentFlags & transform::InheritedProperties::Alignment::VERTICAL_TOP)
                alignmentString += "VERTICAL_TOP ";
            if (alignmentFlags & transform::InheritedProperties::Alignment::HORIZONTAL_RIGHT)
                alignmentString += "HORIZONTAL_RIGHT ";
            if (alignmentFlags & transform::InheritedProperties::Alignment::VERTICAL_BOTTOM)
                alignmentString += "VERTICAL_BOTTOM ";
            if (alignmentFlags & transform::InheritedProperties::Alignment::HORIZONTAL_LEFT)
                alignmentString += "HORIZONTAL_LEFT ";
            if (alignmentFlags & transform::InheritedProperties::Alignment::ALIGN_TO_INNER_EDGES)
                alignmentString += "ALIGN_TO_INNER_EDGES ";
            SPDLOG_DEBUG("Adjusting alignment for entity {} (parent {}) with alignment: {}", static_cast<int>(entity), static_cast<int>(node.parent.value_or(entt::null)), alignmentString);

            auto selfDimensions = Vector2{transform.getActualW(), transform.getActualH()};
            auto selfOffset = role.offset.value_or(Vector2{0, 0});

            auto selfDimensionsPaddingShavedOff = Vector2{selfDimensions.x - 2 * uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value(), selfDimensions.y - 2 * uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value()};
            auto selfOffsetWithPadding = Vector2{selfOffset.x + uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value(), selfOffset.y + uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value()};

            // row + horizontal center should center all children within it
            // column + vertical center should center all children within it

            auto selfContentDimensions = selfDimensions;
            auto selfContentOffset = role.offset.value_or(Vector2{0, 0});

            // subtract padding from content dimensions
            selfContentDimensions.x -= 2 * uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value();
            selfContentDimensions.y -= 2 * uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value();
            // add padding to content offset
            selfContentOffset.x += uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value();
            selfContentOffset.y += uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value();

            int childCounter = 0;

            float sumOfAllChildWidths = 0;
            float sumOfAllChildHeights = 0;
            float maxChildWidth = 0;
            float maxChildHeight = 0;
            for (auto childEntry : node.orderedChildren)
            {
                auto child = childEntry;
                auto &childTransform = registry.get<transform::Transform>(child);
                auto &childRole = registry.get<transform::InheritedProperties>(child);
                auto &childUIConfig = registry.get<UIConfig>(child);
                auto &childUIState = registry.get<UIState>(child);

                auto childDimensions = Vector2{childTransform.getActualW(), childTransform.getActualH()};
                // if child has emboss, add to height
                if (childUIConfig.emboss)
                {
                    childDimensions.y += childUIConfig.emboss.value() * uiConfig.scale.value();
                }

                sumOfAllChildWidths += childDimensions.x;
                sumOfAllChildHeights += childDimensions.y;
                maxChildWidth = std::max(maxChildWidth, childDimensions.x);
                maxChildHeight = std::max(maxChildHeight, childDimensions.y);
            }

            float runningXOffset = 0;
            float runningYOffset = 0;

            // for each child, adjust alignment
            for (auto childEntry : node.orderedChildren)
            {
                auto child = childEntry;
                auto &childTransform = registry.get<transform::Transform>(child);
                auto &childRole = registry.get<transform::InheritedProperties>(child);
                auto &childUIConfig = registry.get<UIConfig>(child);
                auto &childUIState = registry.get<UIState>(child);

                auto childDimensions = childUIState.contentDimensions.value();
                // if child has emboss, add to height
                if (childUIConfig.emboss)
                {
                    childDimensions.y += childUIConfig.emboss.value() * uiConfig.scale.value();
                }
                auto childOffset = childRole.offset.value_or(Vector2{0, 0});

                if (alignmentFlags == transform::InheritedProperties::Alignment::NONE)
                {
                    AssertThat(false, Is().EqualTo(true)); // should not happen
                    continue;
                }

                if (alignmentFlags & transform::InheritedProperties::Alignment::VERTICAL_CENTER)
                {
                    if (uiConfig.uiType == UITypeEnum::HORIZONTAL_CONTAINER)
                    {

                        // self's padded content area / 2 - child's height / 2
                        // -> y starting location
                        // place child at y starting location, and do nothing else
                        auto yLoc = selfContentOffset.y + (selfContentDimensions.y / 2) - (childDimensions.y / 2);
                        element::ApplyAlignment(registry, child, 0, yLoc - childRole.offset->y);
                    }
                    else if (uiConfig.uiType == UITypeEnum::VERTICAL_CONTAINER || uiConfig.uiType == UITypeEnum::ROOT)
                    {
                        // self's padded context area / 2 - (sum of all child heights + (child count - 1) * padding) / 2
                        // -> y starting location
                        // increment y starting location by child's width + padding each time
                        auto yLoc = selfContentOffset.y + (selfContentDimensions.y / 2) - (sumOfAllChildHeights + (node.children.size() - 1) * uiConfig.padding.value_or(globals::settings.uiPadding)  * uiConfig.scale.value()) / 2 + runningYOffset;
                        element::ApplyAlignment(registry, child, 0, yLoc - childRole.offset->y);
                        runningYOffset += childDimensions.y + uiConfig.padding.value_or(globals::settings.uiPadding)  * uiConfig.scale.value();
                    }
                }

                if (alignmentFlags & transform::InheritedProperties::Alignment::HORIZONTAL_CENTER)
                {
                    if (uiConfig.uiType == UITypeEnum::HORIZONTAL_CONTAINER)
                    {
                        // self's padded context area / 2 - (sum of all child widths + (child count - 1) * padding) / 2
                        // -> x starting location
                        // increment x starting location by child's width + padding each time
                        auto xLoc = selfContentOffset.x + (selfContentDimensions.x / 2) - (sumOfAllChildWidths + (node.children.size() - 1) * uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value() ) / 2 + runningXOffset;
                        element::ApplyAlignment(registry, child, xLoc - childRole.offset->x, 0);
                        runningXOffset += childDimensions.x + uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value();
                    }
                    else if (uiConfig.uiType == UITypeEnum::VERTICAL_CONTAINER || uiConfig.uiType == UITypeEnum::ROOT)
                    {
                        auto xLoc = selfContentOffset.x + (selfContentDimensions.x / 2) - (childDimensions.x / 2);
                        // childRole.offset->x = xLoc;
                        element::ApplyAlignment(registry, child, xLoc - childRole.offset->x, 0);
                        // self's padded content area / 2 - child's width / 2
                        // -> x starting location
                        // place child at x starting location, and do nothing else
                    }
                }

                if (alignmentFlags & transform::InheritedProperties::Alignment::HORIZONTAL_RIGHT)
                {
                    if (uiConfig.uiType == UITypeEnum::HORIZONTAL_CONTAINER)
                    {
                        auto xLoc = selfContentOffset.x + (selfContentDimensions.x) - (sumOfAllChildWidths + (node.children.size() - 1) * uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value()) + runningXOffset;
                        element::ApplyAlignment(registry, child, xLoc - childRole.offset->x, 0);
                        runningXOffset += childDimensions.x + uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value();
                    }
                    else if (uiConfig.uiType == UITypeEnum::VERTICAL_CONTAINER || uiConfig.uiType == UITypeEnum::ROOT)
                    {
                        auto xLoc = selfContentOffset.x + selfContentDimensions.x - childDimensions.x;
                        element::ApplyAlignment(registry, child, xLoc - childRole.offset->x, 0);
                    }
                }

                if (alignmentFlags & transform::InheritedProperties::Alignment::VERTICAL_BOTTOM)
                {
                    if (uiConfig.uiType == UITypeEnum::HORIZONTAL_CONTAINER)
                    {

                        auto yLoc = selfContentOffset.y + selfContentDimensions.y - childDimensions.y;
                        element::ApplyAlignment(registry, child, 0, yLoc - childRole.offset->y);
                    }
                    else if (uiConfig.uiType == UITypeEnum::VERTICAL_CONTAINER || uiConfig.uiType == UITypeEnum::ROOT)
                    {
                        // self's padded context offset + self's padded content height - child's height
                        // -> y starting location
                        // increment y starting location by child's height + padding + emboss (if present) each time
                        auto yLoc = selfContentOffset.y + (selfContentDimensions.y) - (sumOfAllChildHeights + (node.children.size() - 1) * uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value()) + runningYOffset;
                        element::ApplyAlignment(registry, child, 0, yLoc - childRole.offset->y);
                        runningYOffset += childDimensions.y + uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value();
                    }
                }

                // TOP and LEFT are not implemented, since they are the default values
            }
        }
    }

    std::optional<entt::entity> box::GetUIEByID(entt::registry &registry, entt::entity node, const std::string &id)
    {
        if (!registry.valid(node))
            return std::nullopt;

        auto &config = registry.get<UIConfig>(node); // Assuming UI elements have a UIConfig component
        if (config.id == id)
            return node; // If ID matches, return this node

        auto &nodeComp = registry.get<transform::GameObject>(node);
        for (auto childEntry : nodeComp.orderedChildren)
        {
            auto child = childEntry;
            auto result = GetUIEByID(registry, child, id);
            if (result)
                return result;
        }

        // look in ui root's children
        auto *uiBox = registry.try_get<UIBoxComponent>(node);
        if (!uiBox)
            return std::nullopt;
        auto uiRoot = uiBox->uiRoot.value();
        auto &uiRootComp = registry.get<transform::GameObject>(uiRoot);
        for (auto childEntry : uiRootComp.orderedChildren)
        {
            auto child = childEntry;
            auto result = GetUIEByID(registry, child, id);
            if (result)
                return result;
        }

        if (config.object)
        { // If this UIElement has an associated object with children
            auto result = GetUIEByID(registry, config.object.value(), id);
            if (result)
                return result;
        }

        return std::nullopt;
    }

    // TODO: processing must have parent rect passed in, but it must also have the child elements. how do we do this?

    std::pair<float, float> box::CalcTreeSizes(entt::registry &registry, entt::entity uiElement, ui::LocalTransform parentUINodeRect,
                                               bool forceRecalculateLayout, std::optional<float> scale)
    {

        struct StackEntry
        {
            entt::entity uiElement{entt::null};
            ui::LocalTransform parentUINodeRect{};
            bool forceRecalculateLayout{false};
            std::optional<float> scale;
        };

        std::vector<StackEntry> processingOrder;
        std::stack<StackEntry> stack;
        std::unordered_map<entt::entity, Vector2> contentSizes; // contains calculated content size (calculated by each child, and self, while traversing tree bottom up)

        stack.push({uiElement, parentUINodeRect, forceRecalculateLayout, scale}); // first (root) element

        // Step 1: Collect nodes in top-down order (DFS)
        while (!stack.empty())
        {
            auto entry = stack.top();
            stack.pop();
            processingOrder.push_back(entry);

            auto *node = registry.try_get<transform::GameObject>(entry.uiElement);
            if (!node)
                continue;

            // Push children onto stack (DFS order)
            for (auto childEntry : node->orderedChildren)
            {
                auto child = childEntry;
                if (registry.valid(child))
                {
                    auto &uiConfig = registry.get<UIConfig>(child);
                    auto &uiState = registry.get<UIState>(child);
                    stack.push({child, parentUINodeRect, forceRecalculateLayout, scale}); // TODO: does parentUINodeRect need to change?
                }
            }
        }

        // print out stack
        SPDLOG_DEBUG("Processing order: ");
        for (auto it = processingOrder.rbegin(); it != processingOrder.rend(); ++it)
        {
            auto [entity, parentUINodeRect, forceRecalculateLayout, scale] = *it;
            auto &uiConfig = registry.get<UIConfig>(entity);
            auto &uiState = registry.get<UIState>(entity);
            auto &nodeTransform = registry.get<transform::Transform>(entity);
            auto &node = registry.get<transform::GameObject>(entity);
            auto &role = registry.get<transform::InheritedProperties>(entity);
            SPDLOG_DEBUG("- entity {} | UIT: {} | parentUINodeRect: ({}, {}, {}, {}) | forceRecalculateLayout: {} | scale: {}", static_cast<int>(entity), magic_enum::enum_name<UITypeEnum>(uiConfig.uiType.value()), parentUINodeRect.x, parentUINodeRect.y, parentUINodeRect.w, parentUINodeRect.h, forceRecalculateLayout, scale.value_or(1.f));
        }

        auto &nodeTransform = registry.get<transform::Transform>(uiElement);
        auto &node = registry.get<transform::GameObject>(uiElement);
        auto &uiConfig = registry.get<UIConfig>(uiElement);
        auto &uiState = registry.get<UIState>(uiElement);
        LocalTransform calcCurrentNodeTransform{}; // Stores transformed values for current node
        float padding = uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value();

        // Step 2: Process nodes in bottom-up order (ensuring child elements are always processed before parents), including the root element
        for (auto it = processingOrder.rbegin(); it != processingOrder.rend(); ++it)
        {
            auto [entity, parentUINodeRect, forceRecalculateLayout, scale] = *it;

            auto &uiConfig = registry.get<UIConfig>(entity);
            auto &uiState = registry.get<UIState>(entity);
            auto &nodeTransform = registry.get<transform::Transform>(entity);
            auto &node = registry.get<transform::GameObject>(entity);
            auto &role = registry.get<transform::InheritedProperties>(entity);

            // 1. non - containers - rect, text, and object, always bottom of tree.
            if (uiConfig.uiType == UITypeEnum::RECT_SHAPE || uiConfig.uiType == UITypeEnum::TEXT || uiConfig.uiType == UITypeEnum::OBJECT)
            { 
                if (uiConfig.uiType == UITypeEnum::OBJECT) {
                    // debug
                    SPDLOG_DEBUG("Processing object entity {} (parent {})", static_cast<int>(entity), static_cast<int>(node.parent.value_or(entt::null)));
                }
                auto dimensions = TreeCalcSubNonContainer(registry, entity, parentUINodeRect, forceRecalculateLayout, scale, calcCurrentNodeTransform);
                SPDLOG_DEBUG("Calculated content size for entity {}: ({}, {})", static_cast<int>(entity), dimensions.x, dimensions.y);
                // Store content size for this child
                contentSizes[entity] = dimensions;
                continue;
            }

            // 2. containers - vertical, horizontal, root
            auto dimensions = TreeCalcSubContainer(registry, entity, parentUINodeRect, forceRecalculateLayout, scale, calcCurrentNodeTransform, contentSizes);
            SPDLOG_DEBUG("Calculated content size for container {}: ({}, {})", static_cast<int>(entity), dimensions.x, dimensions.y);
            contentSizes[entity] = dimensions;
        }

        
        // set content sizes for all calculated nodes
        Vector2 biggestSize{0.f, 0.f};
        for (auto [uiElement, contentSize] : contentSizes)
        {
            auto &uiState = registry.get<UIState>(uiElement);
            auto &transform = registry.get<transform::Transform>(uiElement);
            uiState.contentDimensions = contentSize;
            transform.setActualW(contentSize.x);
            transform.setActualH(contentSize.y);
            transform.setVisualW(contentSize.x);
            transform.setVisualH(contentSize.y);

            if (contentSize.x > biggestSize.x)
                biggestSize.x = contentSize.x;
            if (contentSize.y > biggestSize.y)
                biggestSize.y = contentSize.y;
        }
        // get last element, set uiroot size to this, uibox is invisible

        auto &rootTransform = registry.get<transform::Transform>(uiElement);
        rootTransform.setActualW(biggestSize.x + padding);
        // rootTransform.setActualH(biggestSize.y - padding);
        rootTransform.setActualH(biggestSize.y);

        // is the first child a horizontal container? if so, add padding to the height
        if (node.children.size() > 0)
        {
            rootTransform.setActualH(padding);

            // root children, add padding * 2 + root child heights (+emboss if they have any)

            for (auto childEntry : node.orderedChildren)
            {
                auto child = childEntry;
                auto &childConfig = registry.get<UIConfig>(child);
                auto &childState = registry.get<UIState>(child);
                auto &childTransform = registry.get<transform::Transform>(child);
                auto &childRole = registry.get<transform::InheritedProperties>(child);

                auto incrementHeight = childState.contentDimensions->y + padding;
                if (childConfig.emboss)
                {
                    incrementHeight += childConfig.emboss.value() * uiConfig.scale.value();
                }

                rootTransform.setActualH(rootTransform.getActualH() + incrementHeight);
            }
        }

        auto &rootUIElementComp = registry.get<UIElementComponent>(uiElement);
        auto &uiBoxTransform = registry.get<transform::Transform>(rootUIElementComp.uiBox);
        uiBoxTransform.setActualW(rootTransform.getActualW());
        uiBoxTransform.setActualH(rootTransform.getActualH());

        // Step 3: check all containers to see if max width and height is exceeded, and adjust if necessary
        for (auto it = processingOrder.rbegin(); it != processingOrder.rend(); ++it)
        {
            auto [entity, parentUINodeRect, forceRecalculateLayout, scale] = *it;

            auto &uiConfig = registry.get<UIConfig>(entity);
            auto &uiState = registry.get<UIState>(entity);
            auto &nodeTransform = registry.get<transform::Transform>(entity);
            auto &node = registry.get<transform::GameObject>(entity);
            auto &role = registry.get<transform::InheritedProperties>(entity);

            // 1. non - containers - rect, text, and object, always bottom of tree.
            if (uiConfig.uiType == UITypeEnum::RECT_SHAPE || uiConfig.uiType == UITypeEnum::TEXT || uiConfig.uiType == UITypeEnum::OBJECT)
            {
                continue;
            }

            auto currentDims = contentSizes.at(entity);

            // If max width or height doesn't exist or isn't exceeded, continue
            if ((!uiConfig.maxWidth || currentDims.x <= uiConfig.maxWidth.value()) && (!uiConfig.maxHeight || currentDims.y <= uiConfig.maxHeight.value()))
            {
                continue;
            }

            // first, calculate the necessary scale factor to fit within the max dimensions.
            auto scaleW = uiConfig.maxWidth ? uiConfig.maxWidth.value() / currentDims.x : 1.0f;
            auto scaleH = uiConfig.maxHeight ? uiConfig.maxHeight.value() / currentDims.y : 1.0f;
            auto scaling = std::min(scaleW, scaleH);

            // then apply the scale factor to all sub element sizes. The alignment functions will take care of the rest.
            element::ApplyScalingFactorToSizesInSubtree(registry, entity, scaling);
            
        }


        // sizes have been set. Now we have to actually place all of the nodes in the right places respective to the parent rect (uibox)
        // top down
        // ui::UITypeEnum currentAlignmentToUse = UITypeEnum::VERTICAL_CONTAINER; // default layout type is column
        // calcCurrentNodeTransform.x = parentUINodeRect.x;
        // calcCurrentNodeTransform.y = parentUINodeRect.y;

        // bool firstVerticalContainer = true;
        // bool firstHorizontalContainer = true;

        // for (auto it = processingOrder.begin(); it != processingOrder.end(); ++it)
        // {
        //     auto [entity, parentUINodeRect, forceRecalculateLayout, scale] = *it;

        //     auto &uiConfig = registry.get<UIConfig>(entity);
        //     auto &uiState = registry.get<UIState>(entity);
        //     auto &nodeTransform = registry.get<transform::Transform>(entity);
        //     auto &node = registry.get<transform::GameObject>(entity);
        //     auto &role = registry.get<transform::InheritedProperties>(entity);

        //     // is it a container?
        //     if (uiConfig.uiType.value() == UITypeEnum::VERTICAL_CONTAINER || uiConfig.uiType.value() == UITypeEnum::HORIZONTAL_CONTAINER || uiConfig.uiType.value() == UITypeEnum::ROOT) {
        //         currentAlignmentToUse = uiConfig.uiType.value(); // store container for children logic

        //         // root should have 0,0
        //         if (uiConfig.uiType.value() == UITypeEnum::ROOT) {
        //             calcCurrentNodeTransform.x = parentUINodeRect.x;
        //             calcCurrentNodeTransform.y = parentUINodeRect.y;
        //         }
        //         else {
        //             // add padding for the container.
        //             calcCurrentNodeTransform.x += padding;
        //             calcCurrentNodeTransform.y += padding;
        //         }

        //         role.offset = {calcCurrentNodeTransform.x, calcCurrentNodeTransform.y};

        //         // adding a row, so increment y, reset x
        //         if (uiConfig.uiType.value() == UITypeEnum::HORIZONTAL_CONTAINER && !firstHorizontalContainer) {
        //             calcCurrentNodeTransform.y += uiState.contentDimensions->y;
        //             calcCurrentNodeTransform.x = parentUINodeRect.x;
        //         }
        //         else if (!firstVerticalContainer) {
        //             calcCurrentNodeTransform.x += uiState.contentDimensions->x;
        //             calcCurrentNodeTransform.y = parentUINodeRect.y;
        //         }

        //         // set first container flags
        //         if (uiConfig.uiType.value() == UITypeEnum::HORIZONTAL_CONTAINER) {
        //             firstHorizontalContainer = false;
        //         }
        //         else {
        //             firstVerticalContainer = false;
        //         }
        //     }
        //     // is it a non-container?
        //     else {

        //         // add padding for the element
        //         if (currentAlignmentToUse == UITypeEnum::HORIZONTAL_CONTAINER) {
        //             calcCurrentNodeTransform.x += padding;
        //         }
        //         else {
        //             calcCurrentNodeTransform.y += padding;
        //         }

        //         // are we in a row currently?
        //         if (currentAlignmentToUse == UITypeEnum::HORIZONTAL_CONTAINER) {
        //             // add width for the element
        //             calcCurrentNodeTransform.x += uiState.contentDimensions->x;
        //         }
        //         // are we in a column? (root and vertical container are treated as columns)
        //         else {
        //             // add height for the element, but if we are in the root, add nothing
        //             if (uiConfig.uiType.value() != UITypeEnum::ROOT) {
        //                 calcCurrentNodeTransform.y += uiState.contentDimensions->y;
        //             }
        //         }

        //         role.offset = {calcCurrentNodeTransform.x, calcCurrentNodeTransform.y};
        //     }

        // }

        // place at the given location, adding padding.
        // now do the same thing for each child.

        // if self is a container, increment x or y with padding and emboss as necessary.
        // if self is not a container, increment x or y with padding and emboss as necessary.

        // all processing done. Now we have the final rect size for the root in the map.

        
        auto rootContentSize = uiState.contentDimensions.value_or(Vector2{0.f, 0.f});
        // set uibox size to root content size
        // uiBoxTransform.setActualW(rootContentSize.x);
        // uiBoxTransform.setActualH(rootContentSize.y);
        return {rootContentSize.x, rootContentSize.y};
    }

    auto isVertContainer(entt::registry &registry, entt::entity uiElement) -> bool
    {
        auto &uiConfig = registry.get<UIConfig>(uiElement);
        return uiConfig.uiType == UITypeEnum::VERTICAL_CONTAINER || uiConfig.uiType == UITypeEnum::ROOT;
    }

    auto box::placeUIElementsRecursively(entt::registry &registry, entt::entity uiElement, ui::LocalTransform &runningTransform, ui::UITypeEnum parentType, entt::entity parent) -> void
    {
        auto &uiConfig = registry.get<UIConfig>(uiElement);
        auto &uiState = registry.get<UIState>(uiElement);
        auto &nodeTransform = registry.get<transform::Transform>(uiElement);
        auto &node = registry.get<transform::GameObject>(uiElement);
        auto &role = registry.get<transform::InheritedProperties>(uiElement);

        // place at the given location, adding padding.
        role.offset = {runningTransform.x, runningTransform.y};

        // am I a ui element?
        if (uiConfig.uiType == UITypeEnum::RECT_SHAPE || uiConfig.uiType == UITypeEnum::TEXT || uiConfig.uiType == UITypeEnum::OBJECT)
        {
            placeNonContainerUIE(role, runningTransform, uiElement, parentType, uiState, uiConfig);
            return;
        }

        // --------------------------------------------------
        // am I a container?

        // runningTransform.x += uiConfig.padding.value_or(globals::settings.uiPadding);
        // runningTransform.y += uiConfig.padding.value_or(globals::settings.uiPadding);

        role.offset = {runningTransform.x, runningTransform.y};
        SPDLOG_DEBUG("Placing entity {} at ({}, {})", static_cast<int>(uiElement), runningTransform.x, runningTransform.y);

        // cache transform before adding children
        auto transformCache = runningTransform;
        runningTransform.x += uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value();
        runningTransform.y += uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value();
        // for each child, do the same thing.
        for (auto childEntry : node.orderedChildren)
        {
            auto child = childEntry;
            if (!registry.valid(child))
                continue;
            SPDLOG_DEBUG("Processing child entity {}", static_cast<int>(child));

            placeUIElementsRecursively(registry, child, runningTransform, uiConfig.uiType.value(), uiElement);
        }
        // restore cache
        runningTransform = transformCache;

        // increment by height + emboss if it is a row, or by width if it is a column.
        if (uiConfig.uiType == UITypeEnum::HORIZONTAL_CONTAINER && parentType != UITypeEnum::HORIZONTAL_CONTAINER)
        {
            // runningTransform.y += uiState.contentDimensions->y + uiConfig.emboss.value_or(0.f) + uiConfig.padding.value_or(globals::settings.uiPadding);
            runningTransform.y += uiState.contentDimensions->y;
            // add emboss if it exists
            if (uiConfig.emboss)
            {
                runningTransform.y += uiConfig.emboss.value() * uiConfig.scale.value();
            }

            runningTransform.y += uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value();
        }
        else if (uiConfig.uiType == UITypeEnum::HORIZONTAL_CONTAINER && parentType == UITypeEnum::HORIZONTAL_CONTAINER)
        {
            // runningTransform.y += uiState.contentDimensions->y + uiConfig.emboss.value_or(0.f) + uiConfig.padding.value_or(globals::settings.uiPadding);
            runningTransform.x += uiState.contentDimensions->x + uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value();
        }
        else if (isVertContainer(registry, uiElement) && !isVertContainer(registry, parent))
        { // make sure my parent wasn't the same type

            // runningTransform.x += uiState.contentDimensions->x + uiConfig.padding.value_or(globals::settings.uiPadding);
            runningTransform.x += uiState.contentDimensions->x + uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value();
        }
        else if (isVertContainer(registry, uiElement) && isVertContainer(registry, parent))
        {

            // runningTransform.x += uiState.contentDimensions->x + uiConfig.padding.value_or(globals::settings.uiPadding);
            runningTransform.y += uiState.contentDimensions->y + uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value() + uiConfig.emboss.value_or(0.f) * uiConfig.scale.value();
        }
    }

    void box::placeNonContainerUIE(transform::InheritedProperties &role, ui::LocalTransform &runningTransform, entt::entity uiElement, ui::UITypeEnum parentType, ui::UIState &uiState, ui::UIConfig &uiConfig)
    {
        auto object = globals::registry.get<UIConfig>(uiElement).object.value_or(entt::null);
        //REVIEW: why is the ui element checked? shouldn't the object be checked?
        // if (globals::registry.any_of<TextSystem::Text>(uiElement))
        // {
        //     // debug
        //     SPDLOG_DEBUG("Placing text entity {} at ({}, {})", static_cast<int>(uiElement), runningTransform.x, runningTransform.y);

        //     // also apply to text object TODO: apply later to other object ui entities
        //     auto object = globals::registry.get<UIConfig>(uiElement).object.value();
        //     auto &textRole = globals::registry.get<transform::InheritedProperties>(object);
        //     auto &textTransform = globals::registry.get<transform::Transform>(object);

        //     textRole.offset = {runningTransform.x, runningTransform.y};
        // }
        // else if (object != entt::null && globals::registry.any_of<AnimationQueueComponent>(object))
        // {
        //     // debug
        //     SPDLOG_DEBUG("Placing animated entity {} at ({}, {})", static_cast<int>(uiElement), runningTransform.x, runningTransform.y);

        //     // also apply to animated object TODO: apply later to other object ui entities
        //     auto object = globals::registry.get<UIConfig>(uiElement).object.value();
        //     auto &animationRole = globals::registry.get<transform::InheritedProperties>(object);
        //     auto &animationTransform = globals::registry.get<transform::Transform>(object);

        //     animationRole.offset = {runningTransform.x, runningTransform.y};
        // }
        // else {
            role.offset = {runningTransform.x, runningTransform.y};
        // }
        

        // place at the given location, adding padding.
        // runningTransform.x += uiConfig.padding.value_or(globals::settings.uiPadding);
        // runningTransform.y += uiConfig.padding.value_or(globals::settings.uiPadding);
        

        SPDLOG_DEBUG("Placing entity {} at ({}, {})", static_cast<int>(uiElement), runningTransform.x, runningTransform.y);

        // is my parent not a row?
        if (parentType != UITypeEnum::HORIZONTAL_CONTAINER)
        {
            // increment y with padding and emboss as necessary.
            // runningTransform.y += uiState.contentDimensions->y + uiConfig.padding.value_or(globals::settings.uiPadding) + uiConfig.emboss.value_or(0.f);
            runningTransform.y += uiState.contentDimensions->y;
            // add emboss if it exists
            if (uiConfig.emboss)
            {
                runningTransform.y += uiConfig.emboss.value() * uiConfig.scale.value();
            }
            runningTransform.y += uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value();
            SPDLOG_DEBUG("Incrementing y by {} for entity {}", uiState.contentDimensions->y + uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value() + uiConfig.emboss.value_or(0.f) * uiConfig.scale.value(), static_cast<int>(uiElement));
        }
        else
        {
            // increment x with padding as necessary.
            // runningTransform.x += uiState.contentDimensions->x + uiConfig.padding.value_or(globals::settings.uiPadding);
            runningTransform.x += uiState.contentDimensions->x + uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value();
            SPDLOG_DEBUG("Incrementing x by {} for entity {}", uiState.contentDimensions->x + uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value(), static_cast<int>(uiElement));
        }
    }

    auto box::TreeCalcSubContainer(entt::registry &registry, entt::entity uiElement, ui::LocalTransform parentUINodeRect,
                                   bool forceRecalculateLayout, std::optional<float> scale, LocalTransform &calcCurrentNodeTransform, std::unordered_map<entt::entity, Vector2> &contentSizes) -> Vector2
    {
        if (!registry.valid(uiElement))
            return {0.f, 0.f};

        LocalTransform calcChildTransform{}; // Stores transformed values for child calculations
        auto &nodeTransform = registry.get<transform::Transform>(uiElement);
        auto &node = registry.get<transform::GameObject>(uiElement);
        auto &uiConfig = registry.get<UIConfig>(uiElement);
        auto &uiState = registry.get<UIState>(uiElement);
        float max_w = 0.f, max_h = 0.f;
        float accumulated_w = 0.f, accumulated_h = 0.f;
        float padding = uiConfig.padding.value_or(globals::settings.uiPadding) * uiConfig.scale.value();
        float factor = scale.value_or(1.0f);

        SubCalculateContainerSize(calcCurrentNodeTransform, parentUINodeRect, uiConfig, calcChildTransform, padding, node, registry, factor, contentSizes);

        if (!(uiConfig.maxWidth && uiConfig.maxWidth.value() < calcChildTransform.w) && !(uiConfig.maxHeight && uiConfig.maxHeight.value() < calcChildTransform.h))
        {
            // stop execution flow here, max dims not exceeded.
            calcCurrentNodeTransform.x = parentUINodeRect.x;
            ClampDimensionsToMinimumsIfPresent(uiConfig, calcChildTransform);
            ui::element::SetValues(registry, uiElement, calcCurrentNodeTransform, forceRecalculateLayout);
            return {calcChildTransform.w, calcChildTransform.h}; // final content size for this container
        }
        // max dimensions have been exceeded.
        // We'll have to scale down the entire subtree to fit within the max dimensions.
        // else {
        //     calcCurrentNodeTransform.x = parentUINodeRect.x;
        //     ClampDimensionsToMinimumsIfPresent(uiConfig, calcChildTransform);
        //     ui::element::SetValues(registry, uiElement, calcCurrentNodeTransform, forceRecalculateLayout);

        //     auto currentDims = Vector2{calcChildTransform.w, calcChildTransform.h};

        //     // first, calculate the necessary scale factor to fit within the max dimensions.
        //     auto scaleW = uiConfig.maxWidth ? uiConfig.maxWidth.value() / currentDims.x : 1.0f;
        //     auto scaleH = uiConfig.maxHeight ? uiConfig.maxHeight.value() / currentDims.y : 1.0f;
        //     auto scaling = std::min(scaleW, scaleH);

        //     // then apply the scale factor to all sub element sizes. The alignment functions will take care of the rest.
        //     element::ApplyScalingFactorToSizesInSubtree(registry, uiElement, scaling);
        //     // TODO: ensure all padding references (and emboss) are multiplied by the uiConfig scale
        // }

        // FIXME: add this feature later
        //  // if this runs, max width/height constraints are exceeded, adjust scale, run calculations again.
        //  float restriction = uiConfig.maxWidth.value_or(uiConfig.maxHeight.value());
        //  factor *= restriction / (uiConfig.maxWidth ? calcChildTransform.w : calcChildTransform.h);

        // // do-over with scale factor to fit everything in.
        // SubCalculateContainerLayouts(calcCurrentNodeTransform, parentUINodeRect, uiConfig, calcChildTransform, padding, node, registry, factor, contentSizes);

        // final content size for this container
        calcCurrentNodeTransform.x = parentUINodeRect.x;
        ClampDimensionsToMinimumsIfPresent(uiConfig, calcChildTransform);
        ui::element::SetValues(registry, uiElement, calcCurrentNodeTransform, forceRecalculateLayout);
        return {calcChildTransform.w, calcChildTransform.h};
    }

    auto box::SubCalculateContainerSize(ui::LocalTransform &calcCurrentNodeTransform, ui::LocalTransform &parentUINodeRect, ui::UIConfig &selfUIConfig, ui::LocalTransform &calcChildTransform, float padding, transform::GameObject &node, entt::registry &registry, float factor, std::unordered_map<entt::entity, Vector2> &contentSizes) -> void
    {
        // TODO: factor not applied here.
        calcCurrentNodeTransform.x = parentUINodeRect.x;
        calcCurrentNodeTransform.y = parentUINodeRect.y;
        calcCurrentNodeTransform.w = selfUIConfig.minWidth.value_or(0.0f);
        calcCurrentNodeTransform.h = selfUIConfig.minHeight.value_or(0.0f);

        // If this is the root node, position is forced to (0,0).
        if (selfUIConfig.uiType == UITypeEnum::ROOT)
        {
            calcCurrentNodeTransform.x = 0;
            calcCurrentNodeTransform.y = 0;
            calcCurrentNodeTransform.w = selfUIConfig.minWidth.value_or(0.0f);
            calcCurrentNodeTransform.h = selfUIConfig.minHeight.value_or(0.0f);
        }

        // _ct is offset by padding and reset to (0,0) size. (child transform will be passed to children)
        // calcChildTransform.x = calcCurrentNodeTransform.x + padding;
        // calcChildTransform.y = calcCurrentNodeTransform.y + padding;
        calcChildTransform.w = 0.f;
        calcChildTransform.h = 0.f;

        // two cases: self is a vertical container with children elements. -> add heights.
        // or self is a horizontal container with two vertical containers. -> add only width.

        bool hasAtLeastOneChild = false;
        bool hasAtLeastOneContainerChild = false;
        // Anything that is not a row is treated as a column.
        for (auto childEntry : node.orderedChildren)
        {
            hasAtLeastOneChild = true;
            auto child = childEntry;
            if (!registry.valid(child))
                continue;
            // ensure that it is a valid uielement
            AssertThat(registry.any_of<UIElementComponent>(child), Is().EqualTo(true));

            auto &childNode = registry.get<transform::GameObject>(child);
            auto &childUIConfig = registry.get<UIConfig>(child);
            auto childScale = factor * (childUIConfig.scale.value_or(1.0f));
            childUIConfig.scale = childScale;

            auto [child_w, child_h] = contentSizes.at(child); // child will always exist because they are processed first.

            // self can be horizontal or vertical.

            if (childUIConfig.uiType == UITypeEnum::VERTICAL_CONTAINER || childUIConfig.uiType == UITypeEnum::ROOT || childUIConfig.uiType == UITypeEnum::HORIZONTAL_CONTAINER)
            {
                hasAtLeastOneContainerChild = true;
            }

            // increment by height for each row item, based on self type.
            if (selfUIConfig.uiType == UITypeEnum::HORIZONTAL_CONTAINER)
            {
                // calcChildTransform.w = std::max(calcChildTransform.w, child_w + padding);
                calcChildTransform.w += child_w + padding;
                // calcChildTransform.x += child_w + padding;
                auto emboss = childUIConfig.emboss.value_or(0.f) * childUIConfig.scale.value();
                if (child_h + padding + emboss > calcChildTransform.h)
                {
                    calcChildTransform.h = child_h + padding + emboss;
                }
                // if (childUIConfig.emboss)
                // {
                //     calcChildTransform.h += childUIConfig.emboss.value();
                //     // calcChildTransform.h = std::max(calcChildTransform.h, child_h + padding + childUIConfig.emboss.value());
                // }

            } // increment by width fo each colum item.
            else if (selfUIConfig.uiType == UITypeEnum::VERTICAL_CONTAINER || selfUIConfig.uiType == UITypeEnum::ROOT)
            {
                // calcChildTransform.h = std::max(calcChildTransform.h, child_h + padding);
                calcChildTransform.h += child_h + padding;
                // calcChildTransform.y += child_h + padding;
                if (child_w + padding > calcChildTransform.w)
                {
                    calcChildTransform.w = child_w + padding;
                }
                if (childUIConfig.emboss)
                {
                    calcChildTransform.h += childUIConfig.emboss.value() * childUIConfig.scale.value();
                    //     // calcChildTransform.w = std::max(calcChildTransform.w, child_w + padding + childUIConfig.emboss.value());
                }
            }
        }

        // add padding to the final width and height.
        if (selfUIConfig.uiType == UITypeEnum::HORIZONTAL_CONTAINER && !hasAtLeastOneContainerChild)
        {
            calcChildTransform.w += padding;
            calcChildTransform.h += padding;
        }
        else if (selfUIConfig.uiType == UITypeEnum::HORIZONTAL_CONTAINER && hasAtLeastOneContainerChild)
        {
            calcChildTransform.w += padding;
            calcChildTransform.h += padding;
        }
        else if (selfUIConfig.uiType == UITypeEnum::VERTICAL_CONTAINER && !hasAtLeastOneContainerChild)
        {
            // calcChildTransform.h += padding; // This is necessary for vertical containers containing elements
            calcChildTransform.w += padding;
        }
        else if (selfUIConfig.uiType == UITypeEnum::VERTICAL_CONTAINER && hasAtLeastOneContainerChild)
        {
            calcChildTransform.w += padding;
            calcChildTransform.h += padding; // This is necessary for vertical containers containing elements
        }

        if (hasAtLeastOneChild)
        {
            if (selfUIConfig.uiType == UITypeEnum::HORIZONTAL_CONTAINER)
            {
                // calcChildTransform.w += padding;
                // calcChildTransform.h += padding;
            }
            else if (selfUIConfig.uiType == UITypeEnum::VERTICAL_CONTAINER && !hasAtLeastOneContainerChild)
            {
                // calcChildTransform.h += padding;
                calcChildTransform.h += padding;
            }
        }
    }

    void box::ClampDimensionsToMinimumsIfPresent(ui::UIConfig &uiConfig, ui::LocalTransform &calcTransform)
    {
        if (uiConfig.minWidth && uiConfig.minWidth.value() > calcTransform.w)
        {
            calcTransform.w = uiConfig.minWidth.value();
        }
        if (uiConfig.minHeight && uiConfig.minHeight.value() > calcTransform.h)
        {
            calcTransform.h = uiConfig.minHeight.value();
        }
    }

    auto box::TreeCalcSubNonContainer(entt::registry &registry, entt::entity uiElement, ui::LocalTransform parentUINodeRect,
                                      bool forceRecalculateLayout, std::optional<float> scale, LocalTransform &calcCurrentNodeTransform) -> Vector2
    {
        if (!registry.valid(uiElement))
            return {0.f, 0.f};

        auto &nodeTransform = registry.get<transform::Transform>(uiElement);
        auto &node = registry.get<transform::GameObject>(uiElement);
        auto &uiConfig = registry.get<UIConfig>(uiElement);
        auto &uiState = registry.get<UIState>(uiElement);

        // TODO: how does this know which X/Y value to use? parent rects have not been calculated yet.

        calcCurrentNodeTransform.x = parentUINodeRect.x;
        calcCurrentNodeTransform.y = parentUINodeRect.y;
        calcCurrentNodeTransform.w = uiConfig.width.has_value() ? uiConfig.width.value() : nodeTransform.getActualW();
        calcCurrentNodeTransform.h = uiConfig.height.has_value() && uiConfig.height.has_value() ? uiConfig.height.value() : nodeTransform.getActualH();

        // if there is min width specified, and width is greater than min width, use min width
        if (uiConfig.minWidth && calcCurrentNodeTransform.w < uiConfig.minWidth.value())
        {
            calcCurrentNodeTransform.w = uiConfig.minWidth.value();
        }
        // same with min height
        if (uiConfig.minHeight && calcCurrentNodeTransform.h < uiConfig.minHeight.value())
        {
            calcCurrentNodeTransform.h = uiConfig.minHeight.value();
        }

        if (uiConfig.uiType == UITypeEnum::TEXT)
        {
            // Clear previous text drawable
            uiState.textDrawable = std::nullopt;

            float scaleFactor = uiConfig.scale.value_or(1.0f);

            

            if (uiConfig.ref_component && uiConfig.ref_value)
            {
                // get component with reflection
                auto comp = reflection::retrieveComponent(&registry, uiConfig.ref_entity.value(), uiConfig.ref_component.value());
                auto value = reflection::retrieveFieldByString(comp, uiConfig.ref_component.value(), uiConfig.ref_value.value());
                uiConfig.text = reflection::meta_any_to_string(value);

                if (uiConfig.updateFunc && !forceRecalculateLayout)
                {
                    uiConfig.updateFunc.value()(&registry, uiElement, 0.f);
                }
            }

            if (!uiConfig.text.has_value())
            {
                uiConfig.text = "[UI ERROR]";
            }

            if (!uiConfig.language)
                uiConfig.language = globals::language;

            //TODO: respect font size from config
            float fontSize = globals::fontData.fontLoadedSize * scaleFactor * globals::fontData.fontScale;
            auto [measuredWidth, measuredHeight] = MeasureTextEx(globals::fontData.font, uiConfig.text.value().c_str(), fontSize, globals::fontData.spacing);

            calcCurrentNodeTransform.w = measuredWidth;
                calcCurrentNodeTransform.h = measuredHeight;

            // swap width and height if text is vertical
            if (uiConfig.verticalText.value_or(false))
            {
                calcCurrentNodeTransform.w = measuredHeight;
                calcCurrentNodeTransform.h = measuredWidth;
            }

            // does this have max width or height?
            if (uiConfig.maxWidth && calcCurrentNodeTransform.w > uiConfig.maxWidth.value())
            {
                calcCurrentNodeTransform.w = uiConfig.maxWidth.value();
                // TODO: scale down the text (need to calculate and store the scale value in the config)
            }
            if (uiConfig.maxHeight && calcCurrentNodeTransform.h > uiConfig.maxHeight.value())
            {
                calcCurrentNodeTransform.h = uiConfig.maxHeight.value();
                // TODO: how to measure the height of text and scale it down?
            }

            uiState.contentDimensions = Vector2{calcCurrentNodeTransform.w, calcCurrentNodeTransform.h};
            ui::element::SetValues(registry, uiElement, calcCurrentNodeTransform, forceRecalculateLayout);
        }
        else if (uiConfig.uiType == UITypeEnum::OBJECT || uiConfig.uiType == UITypeEnum::RECT_SHAPE)
        {
            if (uiConfig.uiType == UITypeEnum::OBJECT)
            {
                auto object = uiConfig.object.value();
                // text, animated, or inventory grid object.
                // if (globals::registry.any_of<TextSystem::Text>(object) || globals::registry.any_of<AnimationQueueComponent>(object) || globals::registry.any_of<InventoryGrid>(object))
                // {
                    auto &objectTransform = globals::registry.get<transform::Transform>(object);
                    calcCurrentNodeTransform.w = objectTransform.getActualW();
                    calcCurrentNodeTransform.h = objectTransform.getActualH();
                // }
            }
            

            if (uiConfig.maxWidth && calcCurrentNodeTransform.w > uiConfig.maxWidth.value())
            {
                calcCurrentNodeTransform.w = uiConfig.maxWidth.value();
                // TODO: scale down the object itself if that's possible. This will depend on the object type.
            }
            if (uiConfig.maxHeight && calcCurrentNodeTransform.h > uiConfig.maxHeight.value())
            {
                calcCurrentNodeTransform.h = uiConfig.maxHeight.value();
                // TODO: scale down the object itself if that's possible. This will depend on the object type.
            }
            uiState.contentDimensions = Vector2{calcCurrentNodeTransform.w, calcCurrentNodeTransform.h};
            ui::element::SetValues(registry, uiElement, calcCurrentNodeTransform, forceRecalculateLayout);
        }

        ClampDimensionsToMinimumsIfPresent(uiConfig, calcCurrentNodeTransform);
        return {calcCurrentNodeTransform.w, calcCurrentNodeTransform.h};
    }

    // Function to remove a group of elements from the UI system
    bool box::RemoveGroup(entt::registry &registry, entt::entity entity, const std::string &group)
    {
        if (registry.valid(entity) == false)
        {
            auto *uiBox = registry.try_get<UIBoxComponent>(entity);
            entity = uiBox->uiRoot.value();
            if (registry.valid(entity) == false)
                return false;
        }

        auto *transform = registry.try_get<transform::Transform>(entity);
        auto *element = registry.try_get<UIElementComponent>(entity);
        auto *uiConfig = registry.try_get<UIConfig>(entity);
        auto *uiBox = registry.try_get<UIBoxComponent>(entity);
        auto *role = registry.try_get<transform::InheritedProperties>(entity);

        auto &node = registry.get<transform::GameObject>(entity);

        // Iterate over children and recursively remove them if they belong to the group
        // node.children.erase(
        //     std::remove_if(node.children.begin(), node.children.end(),
        //         [&](entt::entity child) {
        //             return RemoveGroup(registry, child, group);
        //         }),
        //     node.children.end()
        // );
        for (auto it = node.children.begin(); it != node.children.end();)
        {
            if (RemoveGroup(registry, it->second, group))
            {
                it = node.children.erase(it); // Safe erase while iterating
            }
            else
            {
                ++it;
            }
        }

        if (uiConfig && uiConfig->group && uiConfig->group.value() == group)
        {
            registry.destroy(entity);
            return true;
        }

        CalcTreeSizes(registry, uiBox->uiRoot.value(), {transform->getActualX(), transform->getActualY(), transform->getActualW(), transform->getActualH()}, true);
        ui::element::SetWH(registry, uiBox->uiRoot.value());
        transform::ConfigureAlignment(&registry, uiBox->uiRoot.value(), false, entt::null);

        return false;
    }

    auto box::GetGroup(entt::registry &registry, entt::entity entity, const std::string &group) -> std::vector<entt::entity>
    {
        std::vector<entt::entity> ingroup;

        // If entity is invalid, set to its own ui root if possible, else return nullopt
        if (!registry.valid(entity))
        {
            auto *uiBox = registry.try_get<UIBoxComponent>(entity);
            if (uiBox && uiBox->uiRoot)
                entity = uiBox->uiRoot.value();
            else
                return {};
        }

        // Try to retrieve necessary components
        auto *node = registry.try_get<transform::GameObject>(entity);
        auto *uiConfig = registry.try_get<UIConfig>(entity);

        // Ensure the node exists
        AssertThat(node, Is().Not().EqualTo(nullptr));

        // Recursively traverse child nodes
        for (auto childEntry : node->orderedChildren)
        {
            auto child = childEntry;
            ingroup = GetGroup(registry, child, group);
        }

        // If this node belongs to the requested group, add it to the list
        if (uiConfig && uiConfig->group && uiConfig->group.value() == group)
        {
            ingroup.push_back(entity);
        }

        return ingroup;
    }

    void box::Remove(entt::registry &registry, entt::entity entity)
    {
        // Ensure entity exists
        if (!registry.valid(entity))
            return;

        // If this is the overlay menu, refresh alerts
        if (entity == globals::overlayMenu)
        {
            globals::shouldRefreshAlerts = true;
        }

        auto &uiBox = registry.get<UIBoxComponent>(entity);

        ui::element::Remove(registry, uiBox.uiRoot.value());

        // Remove entity from global registry
        auto instanceType = registry.get<UIConfig>(entity).instanceType.value_or("UIBOX");
        auto &instanceList = globals::globalUIInstanceMap[instanceType];

        auto it = std::find(instanceList.begin(), instanceList.end(), entity);
        if (it != instanceList.end())
        {
            instanceList.erase(it);
        }

        // Remove all children recursively
        auto &node = registry.get<transform::GameObject>(entity);
        for (auto childEntry : node.children)
        {
            auto child = childEntry.second;
            util::RemoveAll(registry, child);
        }
        node.children.clear();
        node.orderedChildren.clear();

        // Remove transform component
        transform::RemoveEntity(&registry, entity);

        // Finally, destroy the entity
        registry.destroy(entity);
    }

    // entity is a uibox.
    void box::Draw(std::shared_ptr<layer::Layer> layerPtr, entt::registry &registry, entt::entity entity)
    {
        // LATER: do not draw if already drawn this frame
        auto *uiBox = registry.try_get<UIBoxComponent>(entity);
        auto *uiState = registry.try_get<UIState>(entity);
        auto *node = registry.try_get<transform::GameObject>(entity);

        AssertThat(uiBox, Is().Not().EqualTo(nullptr));
        AssertThat(uiState, Is().Not().EqualTo(nullptr));
        AssertThat(node, Is().Not().EqualTo(nullptr));

        // 🎨 Draw all child elements (except tooltips & alerts)
        // Draw the box's child elements, not the ui root's. The ui hierarchy is stored in the ui root's children, so these would be special-case.
        if (node)
        {
            for (auto childEntry : node->children)
            {
                auto &entryName = childEntry.first;
                auto child = childEntry.second;
                auto *childUIElement = registry.try_get<UIElementComponent>(child);
                auto *childUIBox = registry.try_get<UIBoxComponent>(child);

                // TODO: use these identifiers later?
                if (registry.valid(child) && childUIElement && entryName != "h_popup" && entryName != "alert")
                {
                    SPDLOG_DEBUG("drawing uibox child {}", entryName);
                    // this is a ui element, not a ui box, draw the element itself, then the children
                    ui::element::DrawSelf(layerPtr, registry, child);
                    ui::element::DrawChildren(layerPtr, registry, child);
                }
                else if (childUIBox)
                {
                    SPDLOG_DEBUG("drawing uibox child {}", entryName);
                    // this is a ui box, recursive draw
                    box::Draw(layerPtr, registry, child);
                }
                // TODO: add alternative rendering if necessary for the uibox children. Not sure why this is necessary
            }
        }

        // ✅ Only draw if visible
        // draw the ui root's children. this is different from the uibox's children.
        if (node->state.visible)
        {
            // LATER: not using draw hash
            //  addToDrawHash(entity);  // Adds UI element to draw batch (optimization)

            // 🎨 Draw the root UI element
            if (uiBox->uiRoot)
            {
                // TODO: are child nodes in defs added to root's children, or to the ui box as children?
                element::DrawSelf(layerPtr, registry, uiBox->uiRoot.value());
                element::DrawChildren(layerPtr, registry, uiBox->uiRoot.value());
            }

            // 🖌 Draw elements in layers (ordered rendering)
            // TODO: should elements in layers be excluded from other drawing like above? figure out
            for (auto layerEntry : uiBox->drawLayers)
            {
                auto layerEntity = layerEntry.second;
                if (registry.valid(layerEntity))
                {
                    auto *element = registry.try_get<UIElementComponent>(layerEntity);
                    auto *uiBox = registry.try_get<UIBoxComponent>(layerEntity);
                    // if not a UIelement, then call the draw self method for the component
                    if (element)
                    {
                        ui::element::DrawSelf(layerPtr, registry, layerEntity);
                        ui::element::DrawChildren(layerPtr, registry, layerEntity);
                    }
                    else if (uiBox)
                    {
                        box::Draw(layerPtr, registry, layerEntity);
                    }
                }
            }
        }

        // REVIEW: alerts are the red pips on the top right. alerts can also be popups?
        if (node->children.find("alert") != node->children.end())
        {
            auto alert = node->children["alert"];
            if (registry.valid(alert))
            {
                ui::element::DrawSelf(layerPtr, registry, alert);
                ui::element::DrawChildren(layerPtr, registry, alert);
            }
        }

        transform::DrawBoundingBoxAndDebugInfo(&registry, entity, layerPtr);
    }

    void box::Recalculate(entt::registry &registry, entt::entity entity)
    {
        bool doNotUse = true;
        AssertThat(doNotUse, Is().EqualTo(false)); // TODO: this method should be deleted

        auto *uiBox = registry.try_get<UIBoxComponent>(entity);
        auto *uiBoxRole = registry.try_get<transform::InheritedProperties>(entity);
        auto *transform = registry.try_get<transform::Transform>(entity);
        auto *uiState = registry.try_get<UIState>(entity);

        AssertThat(uiBox, Is().Not().EqualTo(nullptr));
        AssertThat(transform, Is().Not().EqualTo(nullptr));
        AssertThat(uiState, Is().Not().EqualTo(nullptr));

        // 1️⃣ Calculate proper position, width, and height (recursive layout processing)
        auto rootEntity = uiBox->uiRoot.value();
        CalcTreeSizes(registry, rootEntity, {transform->getActualX(), transform->getActualY(), transform->getActualW(), transform->getActualH()}, true);

        // 2️⃣ Calculate final width/height for the container elements
        ui::element::SetWH(registry, rootEntity);

        // 3️⃣ Set correct alignments for all UI elements
        ui::element::SetAlignments(registry, rootEntity, uiBoxRole->offset, true);

        // 4️⃣ Apply calculated dimensions to the UIBox transform
        transform->setActualW(registry.get<transform::Transform>(rootEntity).getActualW());
        transform->setActualH(registry.get<transform::Transform>(rootEntity).getActualH());

        // 5️⃣ Refresh major cache
        // TODO: figure out what this does exactly
        globals::REFRESH_FRAME_MASTER_CACHE = (globals::REFRESH_FRAME_MASTER_CACHE.value_or(0) + 1);

        // 6️⃣ Initialize visual transforms (VT) for the UI root
        ui::element::InitializeVisualTransform(registry, rootEntity);

        // 7️⃣ Cleanup: Decrease cache value if necessary
        if (globals::REFRESH_FRAME_MASTER_CACHE > 1)
        {
            globals::REFRESH_FRAME_MASTER_CACHE = *globals::REFRESH_FRAME_MASTER_CACHE - 1;
        }
        else
        {
            globals::REFRESH_FRAME_MASTER_CACHE.reset();
        }
    }

    void box::Move(entt::registry &registry, entt::entity self, float dt)
    {
        auto *transform = registry.try_get<transform::Transform>(self);
        auto *uiBox = registry.try_get<UIBoxComponent>(self);

        AssertThat(transform, Is().Not().EqualTo(nullptr));
        AssertThat(uiBox, Is().Not().EqualTo(nullptr));

        transform::UpdateTransform(&registry, self, dt);
        transform::UpdateTransform(&registry, uiBox->uiRoot.value(), dt);
    }

    void box::Drag(entt::registry &registry, entt::entity self, Vector2 offset, float dt)
    {
        auto *transform = registry.try_get<transform::Transform>(self);
        auto *node = registry.try_get<transform::GameObject>(self);
        auto *uiBox = registry.try_get<UIBoxComponent>(self);

        AssertThat(transform, Is().Not().EqualTo(nullptr));
        AssertThat(uiBox, Is().Not().EqualTo(nullptr));
        AssertThat(node, Is().Not().EqualTo(nullptr));

        // TODO: fill out missing transform functions in node component
        if (node->methods->onDrag)
            node->methods->onDrag(registry, self);
        transform::UpdateTransform(&registry, uiBox->uiRoot.value(), dt);
    }

    void box::AddChild(entt::registry &registry, entt::entity uiBox, UIElementTemplateNode uiElementDef, entt::entity parent)
    {
        BuildUIElementTree(registry, uiBox, uiElementDef, parent);
        RenewAlignment(registry, uiBox);
    }

    void box::SetContainer(entt::registry &registry, entt::entity self, entt::entity container)
    {
        auto *transform = registry.try_get<transform::Transform>(self);
        auto *uiBox = registry.try_get<UIBoxComponent>(self);

        AssertThat(transform, Is().Not().EqualTo(nullptr));
        AssertThat(uiBox, Is().Not().EqualTo(nullptr));

        // TODO: document what a container is relative to hierarchy too

        // so this sets the uiRoot hierarchy (all ui elements in ui box) to be inside container
        // then it sets the uibox itself to be inside container as well.
        transform::ConfigureContainerForEntity(&registry, uiBox->uiRoot.value(), container);
        transform::ConfigureContainerForEntity(&registry, self, container);
    }

    std::string box::DebugPrint(entt::registry &registry, entt::entity self, int indent)
    {
        auto *transform = registry.try_get<transform::Transform>(self);
        auto *uiBox = registry.try_get<UIBoxComponent>(self);
        auto *uiBoxObject = registry.try_get<transform::GameObject>(self);
        auto *config = registry.try_get<UIConfig>(self);
        auto *role = registry.try_get<transform::InheritedProperties>(self);
        auto *uiConfig = registry.try_get<UIConfig>(uiBox->uiRoot.value());

        AssertThat(transform, Is().Not().EqualTo(nullptr));
        AssertThat(uiBox, Is().Not().EqualTo(nullptr));
        AssertThat(config, Is().Not().EqualTo(nullptr));

        std::string result = fmt::format(" \n| UIBox | - ID: {} [entt-{}] w/h: {}/{} UIElement children: {} | LOC({},{}) OFF({},{}) OFF_ALN({},{}) {}",
                                         uiConfig->id.value_or("N/A"),
                                         static_cast<int>(self),
                                         static_cast<int>(transform->getActualW()),
                                         static_cast<int>(transform->getActualH()),
                                         uiBoxObject->children.size(),
                                         static_cast<int>(transform->getActualX()),
                                         static_cast<int>(transform->getActualY()),
                                         static_cast<int>(role->offset->x),
                                         static_cast<int>(role->offset->y),
                                         static_cast<int>(role->flags->extraAlignmentFinetuningOffset.x),
                                         static_cast<int>(role->flags->extraAlignmentFinetuningOffset.y),
                                         uiBoxObject->state.isBeingHovered? "HOVERED" : "");

        if (uiBox->uiRoot)
        {
            result += ui::element::DebugPrintTree(registry, uiBox->uiRoot.value(), indent + 1);
        }

        return result;
    }

}