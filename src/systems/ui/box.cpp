#include "box.hpp"

#include "entt/entity/fwd.hpp"
#include <cmath>
#include "spdlog/spdlog.h"
#include "systems/entity_gamestate_management/entity_gamestate_management.hpp"
#include "systems/layer/layer_command_buffer.hpp"
#include "systems/layer/layer_optimized.hpp"
#include "systems/text/textVer2.hpp"
#include "systems/layer/layer_order_system.hpp"
#include "systems/collision/broad_phase.hpp"
#include "systems/shaders//shader_pipeline.hpp"
#include "components/graphics.hpp"
#include "inventory_ui.hpp"
#include "core/globals.hpp"
#include "systems/ui/ui_data.hpp"

// Phase 2 utility headers for box.cpp refactoring
#include "systems/ui/traversal.hpp"
#include "systems/ui/type_traits.hpp"
#include "systems/ui/layout_metrics.hpp"
#include "systems/ui/sizing_pass.hpp"
namespace ui
{
    namespace
    {
        thread_local std::unordered_set<entt::entity> boxesBeingRemoved;
        
        bool IsVisibleWindowSurface(const UIConfig& config)
        {
            if (config.nPatchInfo || config.nPatchSourceTexture) {
                return true;
            }
            if (config.outlineThickness && config.outlineThickness.value_or(0.0f) > 0.0f) {
                return true;
            }
            if (config.color && config.color->a > 0) {
                return true;
            }
            return false;
        }

        void ApplyUniformWindowPaddingIfNeeded(entt::registry& registry, entt::entity uiRoot)
        {
            auto* config = registry.try_get<UIConfig>(uiRoot);
            if (!config || !config->uiType) {
                return;
            }

            const auto type = config->uiType.value();
            const bool isContainer = (type == UITypeEnum::VERTICAL_CONTAINER) ||
                                     (type == UITypeEnum::HORIZONTAL_CONTAINER) ||
                                     (type == UITypeEnum::ROOT) ||
                                     (type == UITypeEnum::SCROLL_PANE);
            if (!isContainer) {
                return;
            }

            if (!IsVisibleWindowSurface(*config)) {
                return;
            }

            config->padding = globals::getSettings().uiWindowPadding;
        }
    }

    // TODO: update function registry for methods that replace transform-provided methods

    // TODO: make sure all methods take into account that children can be uiboxes as well

    void LogChildrenOrder(entt::registry &registry, entt::entity parent)
    {
        auto &parentNode = registry.get<transform::GameObject>(parent);
        // SPDLOG_DEBUG("Children of entity {}:", static_cast<int>(parent));
        for (const auto &[id, child] : parentNode.children)
        {
            SPDLOG_DEBUG("  - ID: {}, Entity: {}", id, static_cast<int>(child));
        }
    }

    //
    void box::BuildUIElementTree(entt::registry &registry, entt::entity uiBoxEntity, UIElementTemplateNode &rootDef, entt::entity uiElementParent)
    {
        struct StackEntry
        {
            UIElementTemplateNode def;
            entt::entity parent;
        }; 

        // make ui box screen space as well
        registry.emplace_or_replace<collision::ScreenSpaceCollisionMarker>(uiBoxEntity);

        std::stack<StackEntry> stack;
        stack.push({rootDef, uiElementParent});

        while (!stack.empty())
        {
            auto [def, parent] = stack.top();
            stack.pop();

            // Create new UI element
            entt::entity entity = element::Initialize(registry, parent, uiBoxEntity, def.type, def.config);
            // make screen space  no matter what
            registry.emplace_or_replace<collision::ScreenSpaceCollisionMarker>(entity);
            auto *config = registry.try_get<UIConfig>(entity);
            
            // if ((int)entity == 840) {
            //     SPDLOG_DEBUG("Debugging UI element with entity ID 840");
            // }
            
            //FIXME: bug with lua where it doesn't set the type properly?
            if (magic_enum::enum_name<UITypeEnum>(def.type) == "") {
                SPDLOG_ERROR("UITypeEnum is not set for entity {}, parent {}, type {}", static_cast<int>(entity), static_cast<int>(parent), magic_enum::enum_name<UITypeEnum>(def.type));
                throw std::runtime_error("UITypeEnum is not set for entity " + std::to_string(static_cast<int>(entity)) + ", parent " + std::to_string(static_cast<int>(parent)) + ", value is: " + std::to_string((int)def.type));
            }

            // SPDLOG_DEBUG("Initialized UI element of type {}: entity = {}, parent = {}", magic_enum::enum_name<UITypeEnum>(def.type), static_cast<int>(entity), static_cast<int>(parent));

            auto *parentConfig = registry.try_get<UIConfig>(parent);

            // Apply inherited config values
            if (registry.valid(parent) && parentConfig)
            {
                if (parentConfig->group)
                {
                    if (config)
                    {
                        config->group = parentConfig->group;
                        config->groupParent = parent;
                    }
                    else
                        registry.emplace<UIConfig>(entity).group = parentConfig->group;
                }

                if (parentConfig->buttonCallback)
                {
                    if (config)
                        config->button_UIE = parent;
                    else
                        registry.emplace<UIConfig>(entity).button_UIE = parent;
                }

                if (parentConfig->button_UIE)
                {
                    if (config)
                        config->button_UIE = parentConfig->button_UIE;
                    else
                        registry.emplace<UIConfig>(entity).buttonCallback = parentConfig->buttonCallback;
                }
            }

            // If object + button
            if (def.type == UITypeEnum::OBJECT && config && config->buttonCallback && config->object && registry.valid(config->object.value()))
            {
                auto &node = registry.get<transform::GameObject>(config->object.value());
                node.state.clickEnabled = false;

                // make the object also screen space
                registry.emplace<collision::ScreenSpaceCollisionMarker>(config->object.value());
            }
            
            // if object, make sure the object is screen space, and so is the OBJECT container
            if (config && config->object && registry.valid(config->object.value()))
            {
                registry.emplace_or_replace<collision::ScreenSpaceCollisionMarker>(config->object.value());

                // make sure to mark the object as attached to UI, so it's not rendered doubly
                registry.emplace_or_replace<ui::ObjectAttachedToUITag>(config->object.value());

            }

            // If text, pre-calculate text bounds
            if (def.type == UITypeEnum::TEXT && config && config->text)
            {
                float scale = config->scale.value_or(1.0f);

                // Get the appropriate font data - check for named font first
                const globals::FontData& fontData = [](const UIConfig* config) -> const globals::FontData& {
                    if (config && config->fontName) {
                        const auto& fontName = config->fontName.value();
                        if (localization::hasNamedFont(fontName)) {
                            return localization::getNamedFont(fontName);
                        }
                    }
                    return localization::getFontData();
                }(config);

                // Use custom fontSize if specified, otherwise use default
                // Include globalUIScaleFactor to match rendering calculation
                float baseFontSize = config->fontSize.has_value() ? config->fontSize.value() : fontData.defaultSize;
                float totalScale = scale * fontData.fontScale * globals::getGlobalUIScaleFactor();
                float effectiveSize = baseFontSize * totalScale;
                const Font& bestFont = fontData.getBestFontForSize(effectiveSize);
                float actualSize = static_cast<float>(bestFont.baseSize);
                auto [w, h] = MeasureTextEx(bestFont, config->text->c_str(), actualSize, fontData.spacing);
                if (config->verticalText.value_or(false))
                    std::swap(w, h);
                // FIXME: testing, commenting out
                //  config->minWidth = w;
                //  config->minHeight = h;
            }

            // Handle root element
            if (!registry.valid(parent))
            {
                auto *box = registry.try_get<UIBoxComponent>(uiBoxEntity);
                box->uiRoot = entity;
                registry.get<transform::GameObject>(entity).parent = uiBoxEntity;

                // assign carbon copy role to the root element,
                transform::AssignRole(&registry, entity, transform::InheritedProperties::Type::RoleInheritor, uiBoxEntity,
                                      transform::InheritedProperties::Sync::Strong, transform::InheritedProperties::Sync::Strong,
                                      transform::InheritedProperties::Sync::Strong, transform::InheritedProperties::Sync::Strong);
            }
            else
            {
                auto &thisConfig = registry.get<UIConfig>(entity);
                if (!thisConfig.id)
                {
                    auto &parentGO = registry.get<transform::GameObject>(parent);

                    int idx = static_cast<int>(parentGO.children.size());
                    thisConfig.id = std::to_string(idx);
                }
                else {
                    SPDLOG_DEBUG("UI element has ID: {}", *thisConfig.id);
                }
                auto &parentGO = registry.get<transform::GameObject>(parent);
                const auto &id = thisConfig.id.value();

                AssertThat(parentGO.children.find(id) == parentGO.children.end(), Is().EqualTo(true)); // check for duplicate ids

                parentGO.children[thisConfig.id.value()] = entity;
                parentGO.orderedChildren.push_back(entity);
                // SPDLOG_DEBUG("Inserted child into parent {}: ID = {}, Entity = {}", static_cast<int>(parent), thisConfig.id.value(), static_cast<int>(entity));
            }

            if (def.config.mid)
            {
                auto &boxTransform = registry.get<transform::Transform>(uiBoxEntity);
                boxTransform.middleEntityForAlignment = entity;
            }

            // Push children in reverse order so the first child is processed first
            if (def.type == UITypeEnum::VERTICAL_CONTAINER || def.type == UITypeEnum::HORIZONTAL_CONTAINER || def.type == UITypeEnum::ROOT || def.type == UITypeEnum::SCROLL_PANE)
            {
                // SPDLOG_DEBUG("Processing children for container entity {} (type: {})", static_cast<int>(entity), magic_enum::enum_name<UITypeEnum>(def.type));
                for (int i = static_cast<int>(def.children.size()) - 1; i >= 0; --i)
                {
                    // Only assign an ID if one hasn't already been set
                    if (!def.children[i].config.id.has_value())
                    {
                        def.children[i].config.id = std::to_string(i); // or use indexToAlphaID(i)
                    }
                    else {
                        SPDLOG_DEBUG("Child UI element already has ID: {}", *(def.children[i].config.id));
                    }
                    stack.push({def.children[i], entity});
                }
            }
        }
    }

    // must be existing & initialized uibox (by calling initialize() )
    void box::RenewAlignment(entt::registry &registry, entt::entity self)
    {

        // Initialize transform component
        auto &transform = registry.get<transform::Transform>(self);

        // Setup Role component already done

        // Initialize node component (handles interaction state)
        auto &uiBox = registry.get<UIBoxComponent>(self);
        auto &uiBoxRole = registry.get<transform::InheritedProperties>(self);
        auto uiRoot = uiBox.uiRoot.value();
        auto &uiRootRole = registry.get<transform::InheritedProperties>(uiRoot);

        ApplyUniformWindowPaddingIfNeeded(registry, uiRoot);

        // First, set parent-child relationships to create the tree structure

        // go through all children wihch are objects and reset size with void resetAnimationUIRenderScale(entt::entity e)

        box::TraverseUITreeBottomUp(registry, uiRoot, [&](entt::entity child)
                                    {
            auto *childConfig = registry.try_get<UIConfig>(child);
            
            if (childConfig && childConfig->onUIScalingResetToOne) {
                childConfig->onUIScalingResetToOne.value()(&registry, child);
                return;
            }

            if (childConfig && childConfig->object && registry.any_of<TextSystem::Text>(childConfig->object.value())) {
                //TODO: return size to original here
                TextSystem::Functions::resetTextScaleAndLayout(childConfig->object.value());
            }
            else if (childConfig && childConfig->object) {
                animation_system::resetAnimationUIRenderScale(childConfig->object.value());
            } });

        // Calculate the correct and width/height and offset for each node
        CalcTreeSizes(registry, uiRoot, {transform.getActualX(), transform.getActualY(), transform.getActualW(), transform.getActualH()}, true);

        transform::AlignToMaster(&registry, self);

        uiRootRole.offset = uiBoxRole.offset;

        // start with root entity.
        // start with uibox's offset values so we align to that, w and h are unused.
        ui::LocalTransform runningTransform{uiBoxRole.offset->x, uiBoxRole.offset->y, 0.f, 0.f};

        placeUIElementsRecursively(registry, uiRoot, runningTransform, UITypeEnum::VERTICAL_CONTAINER, uiRoot);

        handleAlignment(registry, uiRoot);

        // LATER: LR clamp not implemented, not sure if necessary

        box::TraverseUITreeBottomUp(registry, uiRoot, [&](entt::entity child)
                                    {
            auto *childConfig = registry.try_get<UIConfig>(child);
            if (childConfig && childConfig->onUIResizeFunc) {
                childConfig->onUIResizeFunc.value()(&registry, child);
            } });

        ui::element::InitializeVisualTransform(registry, uiRoot);

        // probably need to assign layer order components as well
        // to box first (next available one)  and then give the same one to all children

        AssignLayerOrderComponents(registry, self);
        AssignTreeOrderComponents(registry, uiRoot);
        
        // call resize func
        if (uiBox.onBoxResize) {
            uiBox.onBoxResize(self);
        }
    }

    namespace {
        constexpr float kUIRootSyncEpsilon = 0.01f;

        inline bool needs_sync(float a, float b) {
            return std::fabs(a - b) > kUIRootSyncEpsilon;
        }
    }

    void box::SyncUIRootToBox(entt::registry &registry, entt::entity uiBox)
    {
        auto *boxComp = registry.try_get<UIBoxComponent>(uiBox);
        if (!boxComp || !boxComp->uiRoot.has_value()) return;

        entt::entity uiRoot = boxComp->uiRoot.value();
        if (!registry.valid(uiRoot)) return;

        auto *boxTransform = registry.try_get<transform::Transform>(uiBox);
        auto *rootTransform = registry.try_get<transform::Transform>(uiRoot);
        if (!boxTransform || !rootTransform) return;

        // Access springs directly to avoid extra cache work unless a sync is needed.
        auto &boxX = boxTransform->getXSpring();
        auto &boxY = boxTransform->getYSpring();
        auto &boxW = boxTransform->getWSpring();
        auto &boxH = boxTransform->getHSpring();

        auto &rootX = rootTransform->getXSpring();
        auto &rootY = rootTransform->getYSpring();
        auto &rootW = rootTransform->getWSpring();
        auto &rootH = rootTransform->getHSpring();

        const float boxActualX = boxX.targetValue;
        const float boxActualY = boxY.targetValue;
        const float boxVisualX = boxX.value;
        const float boxVisualY = boxY.value;
        const float rootActualX = rootX.targetValue;
        const float rootActualY = rootY.targetValue;
        const float rootVisualX = rootX.value;
        const float rootVisualY = rootY.value;

        const float rootActualW = rootW.targetValue;
        const float rootActualH = rootH.targetValue;
        const float rootVisualW = rootW.value;
        const float rootVisualH = rootH.value;
        const float boxActualW = boxW.targetValue;
        const float boxActualH = boxH.targetValue;
        const float boxVisualW = boxW.value;
        const float boxVisualH = boxH.value;

        const bool posMismatch =
            needs_sync(rootActualX, boxActualX) || needs_sync(rootActualY, boxActualY) ||
            needs_sync(rootVisualX, boxVisualX) || needs_sync(rootVisualY, boxVisualY);
        const bool sizeMismatch =
            needs_sync(boxActualW, rootActualW) || needs_sync(boxActualH, rootActualH) ||
            needs_sync(boxVisualW, rootVisualW) || needs_sync(boxVisualH, rootVisualH);

        if (!posMismatch && !sizeMismatch) return;

        if (posMismatch) {
            // Snap uiRoot position to the UIBox actual position for collision correctness.
            rootX.targetValue = boxActualX;
            rootY.targetValue = boxActualY;
            rootX.value = boxVisualX;
            rootY.value = boxVisualY;
        }

        if (sizeMismatch) {
            // Keep UIBox size in sync with uiRoot (layout owns root size).
            boxW.targetValue = rootActualW;
            boxH.targetValue = rootActualH;
            boxW.value = rootVisualW;
            boxH.value = rootVisualH;
        }

        boxTransform->updateCachedValues(true);
        rootTransform->updateCachedValues(true);
        boxTransform->markDirty();
        rootTransform->markDirty();
        transform::UpdateTransformMatrices(registry, uiBox);
        transform::UpdateTransformMatrices(registry, uiRoot);
    }

    void box::SyncAllUIRootsToBoxes(entt::registry &registry)
    {
        // PERF: reuse cached view when available
        if (!uiBoxViewInitialized) {
            uiBoxViewInitialized = true;
            globalUIBoxView = registry.view<UIBoxComponent>();
        }

        for (auto ent : globalUIBoxView) {
            SyncUIRootToBox(registry, ent);
        }
    }

    entt::entity box::Initialize(entt::registry &registry, const TransformConfig &transformData,
                                 UIElementTemplateNode definition, std::optional<UIConfig> config)
    {
        auto self = transform::CreateOrEmplace(&registry, globals::gameWorldContainerEntity, transformData.x, transformData.y, transformData.w, transformData.h);
        
        // ui box should be screen space by default
        registry.emplace<collision::ScreenSpaceCollisionMarker>(self);

        // Initialize transform component
        auto &transform = registry.get<transform::Transform>(self);
        transform.setActualRotation(transformData.r);

        // Store UIBox definition, which contains schematic
        auto &templateDefToUse = registry.emplace<UIElementTemplateNode>(self, definition);
        if (config)
            registry.emplace<UIConfig>(self, config.value());
        registry.emplace<UIState>(self);
        auto &selfBoxComp = registry.emplace<UIBoxComponent>(self);

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
        BuildUIElementTree(registry, self, templateDefToUse, entt::null);
        auto *uiBox = registry.try_get<UIBoxComponent>(self);
        auto *uiBoxRole = registry.try_get<transform::InheritedProperties>(self);
        auto uiRoot = uiBox->uiRoot.value();

        ApplyUniformWindowPaddingIfNeeded(registry, uiRoot);

        // Set the midpoint for any future alignments to use
        transform.middleEntityForAlignment = uiRoot;
        auto &uiRootRole = registry.get<transform::InheritedProperties>(uiRoot);

        // Calculate the correct and width/height and offset for each node
        CalcTreeSizes(registry, uiRoot, {transform.getActualX(), transform.getActualY(), transform.getActualW(), transform.getActualH()}, true);

        // TODO: iterate through all children, save the sizes at scale = 1 for later use

        // transform::AlignToMaster(&registry, self);

        uiRootRole.offset = uiBoxRole->offset;

        // start with root entity.
        auto &uiElementComp = registry.get<UIElementComponent>(uiRoot);
        // start with uibox's offset values so we align to that, w and h are unused.
        ui::LocalTransform runningTransform{uiBoxRole->offset->x, uiBoxRole->offset->y, 0.f, 0.f};

        placeUIElementsRecursively(registry, uiRoot, runningTransform, UITypeEnum::VERTICAL_CONTAINER, uiRoot);
        
        // check offset value for entity 70
        // auto &debugConfig = registry.get<UIConfig>(entt::entity(70));
        // auto &debugRole = registry.get<transform::InheritedProperties>(entt::entity(70));
        // SPDLOG_DEBUG("Entity 70 offset: ({}, {}), role offset: ({}, {})", debugConfig.offset->x, debugConfig.offset->y, debugRole.offset->x, debugRole.offset->y);
        

        handleAlignment(registry, uiRoot);
        // ui::element::SetAlignments(registry, uiRoot, uiBoxRole->offset, true);
        
        // SPDLOG_DEBUG("Entity 70 offset after handleAlignment: ({}, {}), role offset: ({}, {})", debugConfig.offset->x, debugConfig.offset->y, debugRole.offset->x, debugRole.offset->y);

        // auto final_WH = ui::element::SetWH(registry, uiRoot);

        // everything is in place, but if the ui box is aligned to something else, the offset for this is not applied since everything is based on 0,0 (respective to the ui box)

        // LATER: LR clamp not implemented, not sure if necessary

        ui::element::InitializeVisualTransform(registry, uiRoot);

        AssignLayerOrderComponents(registry, self);

        AssignTreeOrderComponents(registry, uiRoot);

        // If this is a root UIBox, store it in an instance list
        if (config->instanceType)
        {
            util::AddInstanceToRegistry(registry, self, *config->instanceType); // For now, the only alternative is POPUP
        }
        else
        {
            util::AddInstanceToRegistry(registry, self, "UIBOX");
        }
        
        // call resize func
        if (selfBoxComp.onBoxResize) {
            selfBoxComp.onBoxResize(self);
        }
        
        SPDLOG_DEBUG(DebugPrint(registry, self));

        return self;
    }

    auto box::AssignLayerOrderComponents(entt::registry &registry, entt::entity uiBox) -> void
    {
        struct StackEntry
        {
            entt::entity uiElement{entt::null};
        };

        // 1) Update the z‐indexes on ALL LayerOrderComponents if your
        //    global system says they need it:
        layer::layer_order_system::UpdateLayerZIndexesAsNecessary();

        // 2) Read the root box’s layer index once:
        auto const &rootLayer = registry.get<layer::LayerOrderComponent>(uiBox).zIndex;

        // 3) Grab the tree root under that box:
        auto const &uiBoxComp = registry.get<UIBoxComponent>(uiBox);
        entt::entity root = uiBoxComp.uiRoot.value_or(entt::null);
        if (root == entt::null)
            return;

        // 4) DFS stack:
        std::stack<StackEntry> stack;
        stack.push({root});

        // SPDLOG_DEBUG("=== Begin AssignLayerOrderComponents for box {} (zIndex={}) ===",
                    //  static_cast<int>(uiBox), rootLayer);

        while (!stack.empty())
        {
            auto entry = stack.top();
            stack.pop();
            auto e = entry.uiElement;
            if (!registry.valid(e))
                continue;

            // 5) assign or replace the same LayerOrderComponent:
            registry.emplace_or_replace<layer::LayerOrderComponent>(
                e,
                layer::LayerOrderComponent{rootLayer});

            // 6) if this element “owns” an object, give it the same layer too:
            if (auto cfg = registry.try_get<UIConfig>(e))
            {
                if (cfg->object)
                {
                    entt::entity obj = cfg->object.value();
                    if (registry.valid(obj))
                    {
                        registry.emplace_or_replace<layer::LayerOrderComponent>(
                            obj,
                            layer::LayerOrderComponent{rootLayer});
                    }
                }
            }

            // 7) push children in reverse so they come out in the intended order:
            if (auto node = registry.try_get<transform::GameObject>(e))
            {
                for (auto it = node->orderedChildren.rbegin();
                     it != node->orderedChildren.rend();
                     ++it)
                {
                    if (registry.valid(*it))
                        stack.push({*it});
                }
            }
        }

        // SPDLOG_DEBUG("=== Done AssignLayerOrderComponents for box {} ===", static_cast<int>(uiBox));
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

        stack.push({root, uiConfig.scale.value_or(1.0f) * globals::getGlobalUIScaleFactor()}); // first (root) element

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
                    stack.push({child, uiConfig.scale.value_or(1.0f) * globals::getGlobalUIScaleFactor()});
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

            if (node.orderedChildren.size() == 0)
            {
                // SPDLOG_DEBUG("Skipping alignment adjustment entity {} (parent {}) - no children", static_cast<int>(entity), static_cast<int>(node.parent.value_or(entt::null)));
                continue;
            }

            if ((!uiConfig.alignmentFlags || uiConfig.alignmentFlags.value_or(transform::InheritedProperties::Alignment::NONE) == transform::InheritedProperties::Alignment::NONE))
            {
                // SPDLOG_DEBUG("Skipping alignment adjustment entity {} (parent {}) - no alignment", static_cast<int>(entity), static_cast<int>(node.parent.value_or(entt::null)));
                continue;
            }

            auto alignmentFlags = uiConfig.alignmentFlags.value();

            // Check for conflicting alignment flags
            std::string conflictDesc;
            if (hasConflictingAlignmentFlags(alignmentFlags, &conflictDesc)) {
                spdlog::warn("[UI] Conflicting alignment flags on entity {}: {}",
                             static_cast<uint32_t>(entity), conflictDesc);
            }

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
            // SPDLOG_DEBUG("Adjusting alignment for entity {} (parent {}) with alignment: {}", static_cast<int>(entity), static_cast<int>(node.parent.value_or(entt::null)), alignmentString);

            auto selfDimensions = Vector2{transform.getActualW(), transform.getActualH()};
            auto selfOffset = role.offset.value_or(Vector2{0, 0});

            // row + horizontal center should center all children within it
            // column + vertical center should center all children within it

            auto selfContentDimensions = selfDimensions;
            auto selfContentOffset = role.offset.value_or(Vector2{0, 0});

            // subtract padding from content dimensions
            selfContentDimensions.x -= 2 * uiConfig.effectivePadding();
            selfContentDimensions.y -= 2 * uiConfig.effectivePadding();
            // add padding to content offset
            selfContentOffset.x += uiConfig.effectivePadding();
            selfContentOffset.y += uiConfig.effectivePadding();

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
                    childDimensions.y += childUIConfig.emboss.value() * uiConfig.scale.value() * globals::getGlobalUIScaleFactor();
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
                    childDimensions.y += childUIConfig.emboss.value() * uiConfig.scale.value() * globals::getGlobalUIScaleFactor();
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
                        auto yLoc = selfContentOffset.y + (selfContentDimensions.y / 2) - (sumOfAllChildHeights + (node.orderedChildren.size() - 1) * uiConfig.effectivePadding()) / 2 + runningYOffset;
                        element::ApplyAlignment(registry, child, 0, yLoc - childRole.offset->y);
                        runningYOffset += childDimensions.y + uiConfig.effectivePadding();
                    }
                    else if (uiConfig.uiType == UITypeEnum::SCROLL_PANE) {
                        // do nothing
                    }
                }

                if (alignmentFlags & transform::InheritedProperties::Alignment::HORIZONTAL_CENTER)
                {
                    if (uiConfig.uiType == UITypeEnum::HORIZONTAL_CONTAINER)
                    {
                        // self's padded context area / 2 - (sum of all child widths + (child count - 1) * padding) / 2
                        // -> x starting location
                        // increment x starting location by child's width + padding each time
                        auto xLoc = selfContentOffset.x + (selfContentDimensions.x / 2) - (sumOfAllChildWidths + (node.orderedChildren.size() - 1) * uiConfig.effectivePadding()) / 2 + runningXOffset;
                        element::ApplyAlignment(registry, child, xLoc - childRole.offset->x, 0);
                        runningXOffset += childDimensions.x + uiConfig.effectivePadding();
                    }
                    else if (uiConfig.uiType == UITypeEnum::VERTICAL_CONTAINER || uiConfig.uiType == UITypeEnum::ROOT || uiConfig.uiType == UITypeEnum::SCROLL_PANE)
                    {
                        auto xLoc = selfContentOffset.x + (selfContentDimensions.x / 2) - (childDimensions.x / 2);
                        // childRole.offset->x = xLoc;
                        element::ApplyAlignment(registry, child, xLoc - childRole.offset->x, 0);
                        // self's padded content area / 2 - child's width / 2
                        // -> x starting location
                        // place child at x starting location, and do nothing else
                    }
                    
                }

                else if (alignmentFlags & transform::InheritedProperties::Alignment::HORIZONTAL_RIGHT)
                {
                    if (uiConfig.uiType == UITypeEnum::HORIZONTAL_CONTAINER)
                    {
                        auto xLoc = selfContentOffset.x + (selfContentDimensions.x) - (sumOfAllChildWidths + (node.orderedChildren.size() - 1) * uiConfig.effectivePadding()) + runningXOffset;
                        element::ApplyAlignment(registry, child, xLoc - childRole.offset->x, 0);
                        runningXOffset += childDimensions.x + uiConfig.effectivePadding();
                    }
                    else if (uiConfig.uiType == UITypeEnum::VERTICAL_CONTAINER || uiConfig.uiType == UITypeEnum::ROOT)
                    {
                        auto xLoc = selfContentOffset.x + selfContentDimensions.x - childDimensions.x;
                        element::ApplyAlignment(registry, child, xLoc - childRole.offset->x, 0);
                    }

                    else if (uiConfig.uiType == UITypeEnum::SCROLL_PANE) {
                        // do nothing
                    }
                }
                // HORIZONTAL_LEFT is default, no action needed

                // Vertical alignment: VERTICAL_CENTER takes priority over VERTICAL_BOTTOM
                // (VERTICAL_TOP is default, no action needed)
                // Note: Can't use else-if directly because horizontal alignment code is between
                // VERTICAL_CENTER and VERTICAL_BOTTOM blocks, so we use explicit guard
                if ((alignmentFlags & transform::InheritedProperties::Alignment::VERTICAL_BOTTOM) &&
                    !(alignmentFlags & transform::InheritedProperties::Alignment::VERTICAL_CENTER))
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
                        auto yLoc = selfContentOffset.y + (selfContentDimensions.y) - (sumOfAllChildHeights + (node.orderedChildren.size() - 1) * uiConfig.effectivePadding()) + runningYOffset;
                        element::ApplyAlignment(registry, child, 0, yLoc - childRole.offset->y);
                        runningYOffset += childDimensions.y + uiConfig.effectivePadding();
                    }
                    
                    else if (uiConfig.uiType == UITypeEnum::SCROLL_PANE) {
                        // do nothing
                    }
                }

                // TOP and LEFT are not implemented, since they are the default values
            }
        }
    }

    std::optional<entt::entity> box::GetUIEByID(entt::registry &registry, const std::string &id) noexcept;

    static std::optional<entt::entity> SearchUIHierarchy(entt::registry &registry, entt::entity node, const std::string &id) noexcept
    {
        if (!registry.valid(node))
            return std::nullopt;

        if (auto *config = registry.try_get<UIConfig>(node); config && config->id == id)
            return node;

        // Check transform children
        if (auto *nodeComp = registry.try_get<transform::GameObject>(node))
        {
            for (auto child : nodeComp->orderedChildren)
            {
                if (auto result = SearchUIHierarchy(registry, child, id); result)
                    return result;
            }
        }

        // Check UIConfig::object reference
        if (auto *config = registry.try_get<UIConfig>(node); config && config->object.has_value())
        {
            if (auto result = SearchUIHierarchy(registry, config->object.value(), id); result)
                return result;
        }

        return std::nullopt;
    }

    std::optional<entt::entity> box::GetUIEByID(entt::registry &registry, const std::string &id) noexcept
    {
        if (!uiBoxViewInitialized) {
            uiBoxViewInitialized = true;
            globalUIBoxView = registry.view<UIBoxComponent>();
        }
        for (auto entity : globalUIBoxView)
        {
            // Check the UIBox entity itself
            if (auto result = SearchUIHierarchy(registry, entity, id); result)
                return result;

            // Check the UIBox's root node and its children
            const auto &uiBox = globalUIBoxView.get<UIBoxComponent>(entity);
            if (uiBox.uiRoot.has_value())
            {
                entt::entity uiRoot = uiBox.uiRoot.value();
                if (auto result = SearchUIHierarchy(registry, uiRoot, id); result)
                    return result;
            }
        }

        return std::nullopt;
    }

    std::optional<entt::entity> box::GetUIEByID(entt::registry &registry, entt::entity node, const std::string &id) noexcept
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
    std::pair<float, float> box::CalcTreeSizes(entt::registry &registry, entt::entity uiElement, ui::LocalTransform parentUINodeRect,
                                               bool forceRecalculateLayout, std::optional<float> scale)
    {
        // Phase 4 refactoring: Delegate to SizingPass class which encapsulates
        // the multi-pass layout algorithm in focused, testable methods.
        layout::SizingPass pass(registry, uiElement, parentUINodeRect, forceRecalculateLayout, scale);
        return pass.run();
    }

    /**
     * @brief Traverses a UI tree in a bottom-up order and applies a visitor function to each UI element.
     *
     * This function performs a depth-first search (DFS) starting from the given root UI element,
     * collects all elements in a top-down order, and then processes them in reverse order (bottom-up).
     *
     * @param registry The entity-component system (ECS) registry containing the UI elements.
     * @param rootUIElement The root entity of the UI tree to traverse.
     * @param visitor A lambda or function to be executed for each UI element in bottom-up order.
     *
     * The traversal assumes that each UI element is represented as an entity in the ECS and that
     * the hierarchy of UI elements is defined using the `transform::GameObject` component. The
     * `orderedChildren` field of this component is used to determine the child elements of a node.
     *
     * Example usage:
     * @code
     * entt::registry registry;
     * entt::entity root = ...; // Root UI element
     * TraverseUITreeBottomUp(registry, root, [](entt::entity entity) {
     *     // Perform operations on each UI element
     * });
     * @endcode
     */
    void box::TraverseUITreeBottomUp(entt::registry &registry, entt::entity rootUIElement, std::function<void(entt::entity)> visitor, bool excludeTopmostParent)
    {
        struct StackEntry
        {
            entt::entity uiElement{entt::null};
        };

        std::vector<StackEntry> processingOrder;
        std::stack<StackEntry> stack;

        stack.push({rootUIElement});

        // Step 1: Top-down DFS collection
        while (!stack.empty())
        {
            auto entry = stack.top();
            stack.pop();

            processingOrder.push_back(entry);

            if (auto *node = registry.try_get<transform::GameObject>(entry.uiElement))
            {
                for (auto child : node->orderedChildren)
                {
                    if (registry.valid(child))
                    {
                        stack.push({child});
                    }
                }
            }
        }
        
        // After building processingOrder...
        
        // Step 2: Bottom-up execution of lambda
        for (auto it = processingOrder.rbegin(); it != processingOrder.rend(); ++it) {
            if (excludeTopmostParent && it->uiElement == rootUIElement)         
                continue; // exclude topmost parent
            visitor(it->uiElement);
        }


        // for (auto it = processingOrder.rbegin(); it != processingOrder.rend(); ++it)
        // {
        //     visitor(it->uiElement);
        // }
    }

    void box::AssignTreeOrderComponents(entt::registry &registry, entt::entity rootUIElement)
    {
        struct StackEntry
        {
            entt::entity uiElement{entt::null};
        };

        std::vector<StackEntry> processingOrder;
        std::stack<StackEntry> stack;

        stack.push({rootUIElement});
        int currentOrder = 0;

        // SPDLOG_DEBUG("=== Begin AssignTreeOrderComponents ===");

        // Step 1: Top-down DFS collection + assign TreeOrderComponent
        while (!stack.empty())
        {
            auto entry = stack.top();
            stack.pop();

            processingOrder.push_back(entry);

            entt::entity e = entry.uiElement;
            if (!registry.valid(e))
                continue;

            registry.emplace_or_replace<transform::TreeOrderComponent>(e, transform::TreeOrderComponent{currentOrder});

            // does e have an attached object (animation/text)
            auto &uiConfig = registry.get<UIConfig>(e);
            if (uiConfig.object)
            {
                // if it has an object, set the order on the object as well, but one above the current order
                auto object = uiConfig.object.value();
                registry.emplace_or_replace<transform::TreeOrderComponent>(object, transform::TreeOrderComponent{currentOrder + 1});
            }

            // SPDLOG_DEBUG("Assigned TreeOrderComponent to entity {} with order {}", static_cast<int>(e), currentOrder);
            ++currentOrder;

            if (auto *node = registry.try_get<transform::GameObject>(e))
            {
                // SPDLOG_DEBUG
                // ("Entity {} has {} ordered children", static_cast<int>(e), node->orderedChildren.size());

                for (auto it = node->orderedChildren.rbegin(); it != node->orderedChildren.rend(); ++it)
                {
                    if (registry.valid(*it))
                    {
                        // SPDLOG_DEBUG("  Queuing child entity {} for traversal", static_cast<int>(*it));
                        stack.push({*it});
                    }
                }
            }
        }

        // SPDLOG_DEBUG("=== Finished AssignTreeOrderComponents. Total entities ordered: {} ===", currentOrder);
    }

    auto isVertContainer(entt::registry &registry, entt::entity uiElement) -> bool
    {
        auto &uiConfig = registry.get<UIConfig>(uiElement);
        return uiConfig.uiType == UITypeEnum::VERTICAL_CONTAINER || uiConfig.uiType == UITypeEnum::ROOT || uiConfig.uiType == UITypeEnum::SCROLL_PANE;
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

        // am I a ui element (non-container)?
        if (uiConfig.uiType == UITypeEnum::RECT_SHAPE || uiConfig.uiType == UITypeEnum::TEXT ||
            uiConfig.uiType == UITypeEnum::OBJECT || uiConfig.uiType == UITypeEnum::INPUT_TEXT ||
            uiConfig.uiType == UITypeEnum::FILLER)
        {
            placeNonContainerUIE(registry, role, runningTransform, uiElement, parentType, uiState, uiConfig);
            return;
        }

        // --------------------------------------------------
        // am I a container?

        // runningTransform.x += uiConfig.padding.value_or(globals::getSettings().uiPadding);
        // runningTransform.y += uiConfig.padding.value_or(globals::getSettings().uiPadding);

        role.offset = {runningTransform.x, runningTransform.y};
        // SPDLOG_DEBUG("Placing entity {} at ({}, {})", static_cast<int>(uiElement), runningTransform.x, runningTransform.y);

        // cache transform before adding children
        auto transformCache = runningTransform;
        runningTransform.x += uiConfig.effectivePadding();
        runningTransform.y += uiConfig.effectivePadding();
        // for each child, do the same thing.
        for (auto childEntry : node.orderedChildren)
        {
            auto child = childEntry;
            if (!registry.valid(child))
                continue;
            // SPDLOG_DEBUG("Processing child entity {}", static_cast<int>(child));

            placeUIElementsRecursively(registry, child, runningTransform, uiConfig.uiType.value(), uiElement);
        }
        // restore cache
        runningTransform = transformCache;
        
        // debug
        if (uiConfig.uiType == UITypeEnum::HORIZONTAL_CONTAINER && parentType == UITypeEnum::SCROLL_PANE) 
        {
            SPDLOG_DEBUG("Placed horizontal container entity {} at ({}, {}) with content size ({}, {})", static_cast<int>(uiElement), runningTransform.x, runningTransform.y, uiState.contentDimensions->x, uiState.contentDimensions->y);
        }

        // increment by height + emboss if it is a row, or by width if it is a column.
        if (uiConfig.uiType == UITypeEnum::HORIZONTAL_CONTAINER && parentType != UITypeEnum::HORIZONTAL_CONTAINER)
        {
            // runningTransform.y += uiState.contentDimensions->y + uiConfig.emboss.value_or(0.f) + uiConfig.padding.value_or(globals::getSettings().uiPadding);
            runningTransform.y += uiState.contentDimensions->y;
            // add emboss if it exists
            if (uiConfig.emboss)
            {
                runningTransform.y += uiConfig.emboss.value() * uiConfig.scale.value() * globals::getGlobalUIScaleFactor();
            }

            runningTransform.y += uiConfig.effectivePadding();
        }
        else if (uiConfig.uiType == UITypeEnum::HORIZONTAL_CONTAINER && parentType == UITypeEnum::HORIZONTAL_CONTAINER)
        {
            // runningTransform.y += uiState.contentDimensions->y + uiConfig.emboss.value_or(0.f) + uiConfig.padding.value_or(globals::getSettings().uiPadding);
            runningTransform.x += uiState.contentDimensions->x + uiConfig.effectivePadding();
        }
        else if (isVertContainer(registry, uiElement) && !isVertContainer(registry, parent))
        { // make sure my parent wasn't the same type

            // runningTransform.x += uiState.contentDimensions->x + uiConfig.padding.value_or(globals::getSettings().uiPadding);
            runningTransform.x += uiState.contentDimensions->x + uiConfig.effectivePadding();
        }
        else if (isVertContainer(registry, uiElement) && isVertContainer(registry, parent))
        {

            // runningTransform.x += uiState.contentDimensions->x + uiConfig.padding.value_or(globals::getSettings().uiPadding);
            runningTransform.y += uiState.contentDimensions->y + uiConfig.effectivePadding() + uiConfig.emboss.value_or(0.f) * uiConfig.scale.value() * globals::getGlobalUIScaleFactor();
        }
    }

    void box::placeNonContainerUIE(entt::registry &registry, transform::InheritedProperties &role, ui::LocalTransform &runningTransform, entt::entity uiElement, ui::UITypeEnum parentType, ui::UIState &uiState, ui::UIConfig &uiConfig)
    {
        auto object = registry.get<UIConfig>(uiElement).object.value_or(entt::null);
        // REVIEW: why is the ui element checked? shouldn't the object be checked?
        //  if (globals::getRegistry().any_of<TextSystem::Text>(uiElement))
        //  {
        //      // debug
        //      SPDLOG_DEBUG("Placing text entity {} at ({}, {})", static_cast<int>(uiElement), runningTransform.x, runningTransform.y);

        //     // also apply to text object TODO: apply later to other object ui entities
        //     auto object = globals::getRegistry().get<UIConfig>(uiElement).object.value();
        //     auto &textRole = globals::getRegistry().get<transform::InheritedProperties>(object);
        //     auto &textTransform = globals::getRegistry().get<transform::Transform>(object);

        //     textRole.offset = {runningTransform.x, runningTransform.y};
        // }
        // else if (object != entt::null && globals::getRegistry().any_of<AnimationQueueComponent>(object))
        // {
        //     // debug
        //     SPDLOG_DEBUG("Placing animated entity {} at ({}, {})", static_cast<int>(uiElement), runningTransform.x, runningTransform.y);

        //     // also apply to animated object TODO: apply later to other object ui entities
        //     auto object = globals::getRegistry().get<UIConfig>(uiElement).object.value();
        //     auto &animationRole = globals::getRegistry().get<transform::InheritedProperties>(object);
        //     auto &animationTransform = globals::getRegistry().get<transform::Transform>(object);

        //     animationRole.offset = {runningTransform.x, runningTransform.y};
        // }
        // else {
        role.offset = {runningTransform.x, runningTransform.y};
        // }

        // place at the given location, adding padding.
        // runningTransform.x += uiConfig.padding.value_or(globals::getSettings().uiPadding);
        // runningTransform.y += uiConfig.padding.value_or(globals::getSettings().uiPadding);

        // SPDLOG_DEBUG("Placing entity {} at ({}, {})", static_cast<int>(uiElement), runningTransform.x, runningTransform.y);

        // is my parent not a row?
        if (parentType != UITypeEnum::HORIZONTAL_CONTAINER)
        {
            // increment y with padding and emboss as necessary.
            // runningTransform.y += uiState.contentDimensions->y + uiConfig.padding.value_or(globals::getSettings().uiPadding) + uiConfig.emboss.value_or(0.f);
            runningTransform.y += uiState.contentDimensions->y;
            // add emboss if it exists
            if (uiConfig.emboss)
            {
                runningTransform.y += uiConfig.emboss.value() * uiConfig.scale.value() * globals::getGlobalUIScaleFactor();
            }
            runningTransform.y += uiConfig.effectivePadding();
            // SPDLOG_DEBUG("Incrementing y by {} for entity {}", uiState.contentDimensions->y + uiConfig.padding.value_or(globals::getSettings().uiPadding) * uiConfig.scale.value() * globals::getGlobalUIScaleFactor() + uiConfig.emboss.value_or(0.f) * uiConfig.scale.value() * globals::getGlobalUIScaleFactor(), static_cast<int>(uiElement));
        }
        else
        {
            // increment x with padding as necessary.
            // runningTransform.x += uiState.contentDimensions->x + uiConfig.padding.value_or(globals::getSettings().uiPadding);
            runningTransform.x += uiState.contentDimensions->x + uiConfig.effectivePadding();
            // SPDLOG_DEBUG("Incrementing x by {} for entity {}", uiState.contentDimensions->x + uiConfig.padding.value_or(globals::getSettings().uiPadding) * uiConfig.scale.value() * globals::getGlobalUIScaleFactor(), static_cast<int>(uiElement));
        }
    }
    
    
    // Internal DFS that stamps the same 'rootPane' everywhere in the subtree.
    static void markSubtreeWithRootPane(entt::registry& R, entt::entity node, entt::entity rootPane) {
        if (!R.valid(node)) return;

        // Stamp every node (including nested panes) with the *root* pane.
        R.emplace_or_replace<ui::UIPaneParentRef>(node, ui::UIPaneParentRef{rootPane});

        if (auto go = R.try_get<transform::GameObject>(node)) {
            for (auto child : go->orderedChildren) {
                if (R.valid(child)) {
                    markSubtreeWithRootPane(R, child, rootPane);
                }
            }
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
        float padding = uiConfig.effectivePadding();
        float factor = scale.value_or(1.0f);
        
        

        SubCalculateContainerSize(calcCurrentNodeTransform, parentUINodeRect, uiConfig, calcChildTransform, padding, node, registry, factor, contentSizes);

        // final content size for this container
        calcCurrentNodeTransform.x = parentUINodeRect.x;
        calcCurrentNodeTransform.y = parentUINodeRect.y;
        ClampDimensionsToMinimumsIfPresent(uiConfig, calcChildTransform);

        // Distribute remaining space to filler children after container size is known
        // This must happen after ClampDimensionsToMinimumsIfPresent so we know the actual container size
        Vector2 containerSize = { calcChildTransform.w, calcChildTransform.h };
        DistributeFillerSpace(registry, uiElement, uiConfig, containerSize, contentSizes);

        ui::element::SetValues(registry, uiElement, calcCurrentNodeTransform, forceRecalculateLayout);

        // 2) If not a scroll pane, commit content size as before.
        if (uiConfig.uiType != UITypeEnum::SCROLL_PANE) {
            return {calcChildTransform.w, calcChildTransform.h};
        }

        // Handle SCROLL_PANE: set up viewport and scrolling
        auto &scr = registry.emplace_or_replace<ui::UIScrollComponent>(uiElement);

        const float contentW = calcChildTransform.w;
        const float contentH = calcChildTransform.h;

        SPDLOG_DEBUG("Setting up scroll pane on entity {}", static_cast<int>(uiElement));

        // Decide the viewport from UIConfig:
        // 1) If explicit width/height given -> use them.
        // 2) Else if only maxWidth/maxHeight -> clamp content to those -> that is the viewport.
        // 3) Else -> viewport == content (no scroll yet).
        auto pick = [](float content, std::optional<float> fixed, std::optional<float> maxv) {
            if (fixed) return *fixed;
            if (maxv)  return std::min(content, *maxv);
            return content;
        };
        const float vpW_cfg = pick(contentW, uiConfig.width,  uiConfig.maxWidth);
        const float vpH_cfg = pick(contentH, uiConfig.height, uiConfig.maxHeight);

        // Set pane (current node) to viewport size
        calcCurrentNodeTransform.x = parentUINodeRect.x;
        calcCurrentNodeTransform.w = vpW_cfg;
        calcCurrentNodeTransform.h = vpH_cfg;

        // Clamp the pane itself (if you have mins)
        ClampDimensionsToMinimumsIfPresent(uiConfig, /* <-- use current node */ calcCurrentNodeTransform);

        // 4) Now commit ONCE
        ui::element::SetValues(registry, uiElement, calcCurrentNodeTransform, /*force*/ true /* or pass through */);

node.state.collisionEnabled = true; // enable collision for scroll pane

        // Content: what children demanded (pre-viewport)
        scr.contentSize  = { contentW, contentH };

        // Viewport: from config decision (post-viewport)
        scr.viewportSize = { vpW_cfg, vpH_cfg };

        // Vertical scroll range
        scr.minOffset = 0.f;
        scr.maxOffset = std::max(0.f, scr.contentSize.y - scr.viewportSize.y) + uiConfig.effectivePadding();

        // Clamp any existing offset
        scr.offset = std::clamp(scr.offset, scr.minOffset, scr.maxOffset);
        scr.prevOffset = scr.offset;

        // (Optional) tag all descendants so collision can cheaply test against parent pane
        // This helper must DFS children of `uiElement` and set UIPaneParentRef{uiElement} on each.
        markSubtreeWithRootPane(registry, uiElement, uiElement);

        return {vpW_cfg, vpH_cfg};
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

            // Spacers should only affect the layout axis (not the cross axis)
            const bool isSpacer = childUIConfig.instanceType && childUIConfig.instanceType.value() == "spacer";
            if (isSpacer)
            {
                if (selfUIConfig.uiType == UITypeEnum::HORIZONTAL_CONTAINER)
                {
                    child_h = 0.f;
                }
                else
                {
                    child_w = 0.f;
                }
            }

            // self can be horizontal or vertical.

            if (childUIConfig.uiType == UITypeEnum::VERTICAL_CONTAINER || childUIConfig.uiType == UITypeEnum::ROOT || childUIConfig.uiType == UITypeEnum::HORIZONTAL_CONTAINER || childUIConfig.uiType == UITypeEnum::SCROLL_PANE)
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
            else if (selfUIConfig.uiType == UITypeEnum::VERTICAL_CONTAINER || selfUIConfig.uiType == UITypeEnum::ROOT || selfUIConfig.uiType == UITypeEnum::SCROLL_PANE)
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

        // Add final padding to both dimensions for all container types.
        // This consolidates previously scattered padding logic into one location.
        // All containers (horizontal, vertical, root, scroll_pane) with children
        // need padding added to both width and height for proper layout.
        if (hasAtLeastOneChild)
        {
            if (selfUIConfig.uiType == UITypeEnum::HORIZONTAL_CONTAINER ||
                selfUIConfig.uiType == UITypeEnum::VERTICAL_CONTAINER ||
                selfUIConfig.uiType == UITypeEnum::ROOT ||
                selfUIConfig.uiType == UITypeEnum::SCROLL_PANE)
            {
                calcChildTransform.w += padding;
                calcChildTransform.h += padding;
            }
        }
    }

    auto box::DistributeFillerSpace(entt::registry &registry, entt::entity containerEntity, ui::UIConfig &containerConfig,
                                    Vector2 containerSize, std::unordered_map<entt::entity, Vector2> &contentSizes) -> void
    {
        auto *node = registry.try_get<transform::GameObject>(containerEntity);
        if (!node) return;

        // Determine if this is a horizontal or vertical container
        const bool isHorizontal = containerConfig.uiType == UITypeEnum::HORIZONTAL_CONTAINER;
        const bool isVertical = containerConfig.uiType == UITypeEnum::VERTICAL_CONTAINER ||
                                containerConfig.uiType == UITypeEnum::ROOT ||
                                containerConfig.uiType == UITypeEnum::SCROLL_PANE;

        if (!isHorizontal && !isVertical) return;

        // Collect fillers and calculate fixed content size
        std::vector<entt::entity> fillers;
        float totalFixedSize = 0.0f;
        float totalFlex = 0.0f;
        float maxCrossAxisSize = 0.0f;
        int childCount = 0;

        for (auto child : node->orderedChildren) {
            if (!registry.valid(child)) continue;
            auto *childConfig = registry.try_get<UIConfig>(child);
            if (!childConfig) continue;
            childCount++;

            if (childConfig->isFiller || childConfig->uiType == UITypeEnum::FILLER) {
                fillers.push_back(child);
                totalFlex += childConfig->flexWeight;
            } else {
                // Accumulate fixed child sizes (size only, not spacing)
                auto it = contentSizes.find(child);
                if (it != contentSizes.end()) {
                    if (isHorizontal) {
                        totalFixedSize += it->second.x;
                        maxCrossAxisSize = std::max(maxCrossAxisSize, it->second.y);
                    } else {
                        totalFixedSize += it->second.y;
                        maxCrossAxisSize = std::max(maxCrossAxisSize, it->second.x);
                    }
                }
            }
        }

        if (fillers.empty()) return; // No fillers to distribute

        // Calculate available space for fillers
        // Available = Container Size - Fixed Children - Padding (including outer edges)
        float padding = containerConfig.effectivePadding();
        float primaryAxisSize = isHorizontal ? containerSize.x : containerSize.y;

        // Total padding added by layout = inner gaps + outer edges = padding * (children + 1)
        float totalPadding = padding * (static_cast<float>(childCount) + 1.0f);
        float availableSpace = primaryAxisSize - totalFixedSize - totalPadding;

        // Ensure non-negative
        availableSpace = std::max(0.0f, availableSpace);

        // Distribute space proportionally based on flex weights
        for (auto filler : fillers) {
            auto *fillerConfig = registry.try_get<UIConfig>(filler);
            if (!fillerConfig) continue;

            // Clear any persisted min constraints from previous layout passes
            fillerConfig->minWidth.reset();
            fillerConfig->minHeight.reset();

            // Calculate this filler's share
            float share = (totalFlex > 0.0f) ? (fillerConfig->flexWeight / totalFlex) * availableSpace : 0.0f;

            // Apply maxFillSize cap if set
            if (fillerConfig->maxFillSize > 0.0f) {
                share = std::min(share, fillerConfig->maxFillSize);
            }

            // Round to nearest pixel
            share = std::round(share);

            // Store computed fill size
            fillerConfig->computedFillSize = share;

            // Update content sizes cache
            // Filler takes share on primary axis, and matches max sibling height on cross-axis
            if (isHorizontal) {
                contentSizes[filler] = { share, maxCrossAxisSize };
            } else {
                contentSizes[filler] = { maxCrossAxisSize, share };
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

            if (uiConfig.ref_entity && uiConfig.ref_component && uiConfig.ref_value && registry.valid(uiConfig.ref_entity.value()))
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

            // Get the appropriate font data - check for named font first
            const globals::FontData& fontData = [](const UIConfig& cfg) -> const globals::FontData& {
                if (cfg.fontName) {
                    const auto& fontName = cfg.fontName.value();
                    if (localization::hasNamedFont(fontName)) {
                        return localization::getNamedFont(fontName);
                    }
                }
                return localization::getFontData();
            }(uiConfig);

            // Use custom fontSize if specified, otherwise use default
            // Include globalUIScaleFactor to match rendering calculation
            float baseFontSize = uiConfig.fontSize.has_value() ? uiConfig.fontSize.value() : fontData.defaultSize;
            float totalScale = scaleFactor * fontData.fontScale * globals::getGlobalUIScaleFactor();
            float effectiveSize = baseFontSize * totalScale;
            const Font& bestFont = fontData.getBestFontForSize(effectiveSize);
            float actualSize = static_cast<float>(bestFont.baseSize);
            auto [measuredWidth, measuredHeight] = MeasureTextEx(bestFont, uiConfig.text.value().c_str(), actualSize, fontData.spacing);

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
        else if (uiConfig.uiType == UITypeEnum::OBJECT || uiConfig.uiType == UITypeEnum::RECT_SHAPE || uiConfig.uiType == UITypeEnum::INPUT_TEXT)
        {
            // TODO: minwidth respecting for other types of objects
            if (uiConfig.uiType == UITypeEnum::OBJECT)
            {
                if (uiConfig.object && registry.valid(uiConfig.object.value()))
                {
                    auto object = uiConfig.object.value();
                    auto &objectTransform = registry.get<transform::Transform>(object);
                    calcCurrentNodeTransform.w = objectTransform.getActualW();
                    calcCurrentNodeTransform.h = objectTransform.getActualH();
                }
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

            // Apply scale to content dimensions - DO NOT reset scale as it would destroy user configuration
            uiState.contentDimensions = Vector2{calcCurrentNodeTransform.w * uiConfig.scale.value_or(1.0f), calcCurrentNodeTransform.h * uiConfig.scale.value_or(1.0f)};
            ui::element::SetValues(registry, uiElement, calcCurrentNodeTransform, forceRecalculateLayout);

            // FIX: Removed scale reset to 1.0f
            // User-specified scale should be preserved across layout recalculations.
            // The original reset was destroying user configuration.
        }
        else if (uiConfig.uiType == UITypeEnum::FILLER || uiConfig.isFiller)
        {
            // Fillers initially have 0 size - their actual size is computed later
            // in DistributeFillerSpace() after the parent container size is known.
            // DistributeFillerSpace() sets minWidth/minHeight with the correct axis-aware values.
            if (uiConfig.minWidth && uiConfig.minHeight) {
                // Use dimensions set by DistributeFillerSpace()
                calcCurrentNodeTransform.w = static_cast<float>(uiConfig.minWidth.value());
                calcCurrentNodeTransform.h = static_cast<float>(uiConfig.minHeight.value());
            } else {
                // Initial pass: fillers contribute 0 size until DistributeFillerSpace() runs
                calcCurrentNodeTransform.w = 0.0f;
                calcCurrentNodeTransform.h = 0.0f;
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
// FIX: Check validity BEFORE accessing any components to prevent UB
        if (!registry.valid(entity))
        {
            SPDLOG_WARN("RemoveGroup called with invalid entity");
            return false;
        }

        // Try to get the UI root if this is a UIBox wrapper
        auto *uiBox = registry.try_get<UIBoxComponent>(entity);
        if (uiBox && uiBox->uiRoot)
        {
            entity = uiBox->uiRoot.value();
            if (!registry.valid(entity))
            {
                SPDLOG_WARN("RemoveGroup: uiRoot is invalid");
                return false;
            }
        }

        auto *transform = registry.try_get<transform::Transform>(entity);
        auto *element = registry.try_get<UIElementComponent>(entity);
        auto *uiConfig = registry.try_get<UIConfig>(entity);
        // NOTE: uiBox already declared above (line ~1857), reuse it here
        uiBox = registry.try_get<UIBoxComponent>(entity);
        auto *role = registry.try_get<transform::InheritedProperties>(entity);

        auto *node = registry.try_get<transform::GameObject>(entity);
        if (!node)
        {
            return false;
        }

        // Iterate over children and recursively remove them if they belong to the group
        for (auto it = node->children.begin(); it != node->children.end();)
        {
            if (RemoveGroup(registry, it->second, group))
            {
                it = node->children.erase(it); // Safe erase while iterating
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

        // Only recalculate if we have valid uiBox and transform
        if (uiBox && uiBox->uiRoot && registry.valid(uiBox->uiRoot.value()) && transform)
        {
            CalcTreeSizes(registry, uiBox->uiRoot.value(), {transform->getActualX(), transform->getActualY(), transform->getActualW(), transform->getActualH()}, true);
            ui::element::SetWH(registry, uiBox->uiRoot.value());
            transform::ConfigureAlignment(&registry, uiBox->uiRoot.value(), false, entt::null);
        }

        return false;
    }

    auto box::GetGroup(entt::registry &registry, entt::entity entity, const std::string &group) -> std::vector<entt::entity>
    {
        std::vector<entt::entity> ingroup;

// FIX: Check validity BEFORE accessing any components to prevent UB
        if (!registry.valid(entity))
        {
            SPDLOG_WARN("GetGroup called with invalid entity");
            return {};
        }

        // Try to get the UI root if this is a UIBox wrapper
        auto *uiBox = registry.try_get<UIBoxComponent>(entity);
        if (uiBox && uiBox->uiRoot)
        {
            entity = uiBox->uiRoot.value();
            if (!registry.valid(entity))
            {
                SPDLOG_WARN("GetGroup: uiRoot is invalid");
                return {};
            }
        }

        auto *node = registry.try_get<transform::GameObject>(entity);
        auto *uiConfig = registry.try_get<UIConfig>(entity);

        if (!node) return ingroup;

        // Recursively traverse child nodes
        for (auto childEntry : node->orderedChildren)
        {
            auto child = childEntry;
            auto childGroup = GetGroup(registry, child, group);
            ingroup.insert(ingroup.end(), childGroup.begin(), childGroup.end());
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
        if (!registry.valid(entity))
            return;

        if (boxesBeingRemoved.contains(entity)) {
            spdlog::warn("box::Remove cycle detected for entity {}", static_cast<uint32_t>(entity));
            return;
        }
        boxesBeingRemoved.insert(entity);

        if (entity == globals::getOverlayMenu())
        {
            globals::shouldRefreshAlerts = true;
        }

        auto *uiBox = registry.try_get<UIBoxComponent>(entity);
        if (uiBox && uiBox->uiRoot && registry.valid(uiBox->uiRoot.value()))
        {
            ui::element::Remove(registry, uiBox->uiRoot.value());
        }

        auto *uiConfig = registry.try_get<UIConfig>(entity);
        if (uiConfig)
        {
            auto instanceType = uiConfig->instanceType.value_or("UIBOX");
            auto &instanceList = globals::getGlobalUIInstanceMap()[instanceType];

            auto it = std::find(instanceList.begin(), instanceList.end(), entity);
            if (it != instanceList.end())
            {
                instanceList.erase(it);
            }
        }

        auto *node = registry.try_get<transform::GameObject>(entity);
        if (node)
        {
            std::vector<entt::entity> childrenCopy;
            childrenCopy.reserve(node->children.size());
            for (auto &childEntry : node->children)
            {
                childrenCopy.push_back(childEntry.second);
            }
            node->children.clear();
            node->orderedChildren.clear();
            
            for (auto child : childrenCopy)
            {
                util::RemoveAll(registry, child);
            }
        }

        transform::RemoveEntity(&registry, entity);
        boxesBeingRemoved.erase(entity);
    }

    // NOTE: The old box::Draw function has been removed.
    // Drawing is now handled by drawAllBoxesShaderEnabled() which uses a
    // flattened draw list approach for better performance and proper scissor handling.

    void box::Recalculate(entt::registry &registry, entt::entity entity)
    {
        if (!registry.valid(entity)) return;
        
        auto *uiBox = registry.try_get<UIBoxComponent>(entity);
        auto *uiBoxRole = registry.try_get<transform::InheritedProperties>(entity);
        auto *transform = registry.try_get<transform::Transform>(entity);
        auto *uiState = registry.try_get<UIState>(entity);

        if (!uiBox || !transform || !uiState) return;

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
    
    
    
    // Assign the given state tag to all elements in the given UI box (including owned objects)
    // Migrated to use traversal::forEachWithObjects utility (Phase 3.1)
    auto box::AssignStateTagsToUIBox(entt::registry &registry, entt::entity uiBox, const std::string &stateName) -> void
    {
        using namespace entity_gamestate_management;

        if (!registry.valid(uiBox)) return;

        auto const *uiBoxComp = registry.try_get<UIBoxComponent>(uiBox);
        if (!uiBoxComp) return;

        // Helper to add state tag to an entity
        auto addStateTag = [&](entt::entity e) {
            if (!registry.valid(e)) return;
            if (registry.any_of<StateTag>(e)) {
                registry.get<StateTag>(e).add_tag(stateName);
            } else {
                registry.emplace<StateTag>(e, stateName);
            }
        };

        // Tag the box itself
        addStateTag(uiBox);

        // Get the root element
        entt::entity root = uiBoxComp->uiRoot.value_or(entt::null);
        if (root == entt::null) return;

        // Tag all elements and their owned objects using traversal utility
        traversal::forEachWithObjects(registry, root, addStateTag);
    }
    
    
    // Add the tag to all elements in the box (opposite of ClearStateTags)
    // Migrated to use traversal::forEachWithObjects utility (Phase 3.2)
    auto box::AddStateTagToUIBox(entt::registry &registry, entt::entity uiBox, const std::string &tagToAdd) -> void
    {
        using namespace entity_gamestate_management;

        if (!registry.valid(uiBox)) return;

        auto const *uiBoxComp = registry.try_get<UIBoxComponent>(uiBox);
        if (!uiBoxComp) return;

        // Helper to add state tag to an entity and apply effects
        auto addTagAndApply = [&](entt::entity e) {
            if (!registry.valid(e)) return;
            if (registry.all_of<StateTag>(e)) {
                registry.get<StateTag>(e).add_tag(tagToAdd);
            } else {
                StateTag tag{};
                tag.add_tag(tagToAdd);
                registry.emplace<StateTag>(e, std::move(tag));
            }
            applyStateEffectsToEntity(registry, e);
        };

        // Add tag to the box itself
        addTagAndApply(uiBox);

        // Get the root element
        entt::entity root = uiBoxComp->uiRoot.value_or(entt::null);
        if (root == entt::null) return;

        // Add tag to all elements and their owned objects using traversal utility
        traversal::forEachWithObjects(registry, root, addTagAndApply);
    }

    
    //-----------------------------------------------------------------------------
    // Clear all StateTags in a given UI box hierarchy (including owned objects)
    // Migrated to use traversal::forEachWithObjects utility (Phase 3.3)
    //-----------------------------------------------------------------------------
    auto box::ClearStateTagsFromUIBox(entt::registry &registry, entt::entity uiBox) -> void
    {
        using namespace entity_gamestate_management;

        if (!registry.valid(uiBox)) return;

        auto const *uiBoxComp = registry.try_get<UIBoxComponent>(uiBox);
        if (!uiBoxComp) return;

        // Helper to clear state tag from an entity and apply effects
        auto clearTagAndApply = [&](entt::entity e) {
            if (!registry.valid(e)) return;
            if (registry.all_of<StateTag>(e)) {
                registry.get<StateTag>(e).clear();
                applyStateEffectsToEntity(registry, e);
            }
        };

        // Clear state tag on the box itself
        clearTagAndApply(uiBox);

        // Get the root element
        entt::entity root = uiBoxComp->uiRoot.value_or(entt::null);
        if (root == entt::null) return;

        // Clear state tags for all elements and their owned objects using traversal utility
        traversal::forEachWithObjects(registry, root, clearTagAndApply);
    }
    
    // Set transform spring enabled state for all elements in a UI box
    // Migrated to use traversal::forEachWithObjects utility (Phase 3.4)
    auto box::SetTransformSpringsEnabledInUIBox(entt::registry &registry, entt::entity uiBox, bool enabled) -> void
    {
        using namespace transform;

        if (!registry.valid(uiBox)) return;

        auto const *uiBoxComp = registry.try_get<UIBoxComponent>(uiBox);
        if (!uiBoxComp) return;

        // Helper to toggle springs on an entity's transform
        auto toggleSprings = [&](entt::entity e) {
            if (!registry.valid(e)) return;
            if (auto t = registry.try_get<transform::Transform>(e)) {
                auto tryEnableSpring = [&](entt::entity springEnt) {
                    if (registry.valid(springEnt)) {
                        if (auto spring = registry.try_get<Spring>(springEnt))
                            spring->enabled = enabled;
                    }
                };
                tryEnableSpring(t->x);
                tryEnableSpring(t->y);
                tryEnableSpring(t->w);
                tryEnableSpring(t->h);
                tryEnableSpring(t->r);
                tryEnableSpring(t->s);
            }
        };

        // Apply to the box itself
        toggleSprings(uiBox);

        // Get the root element
        entt::entity root = uiBoxComp->uiRoot.value_or(entt::null);
        if (root == entt::null) return;

        // Toggle springs for all elements and their owned objects using traversal utility
        traversal::forEachWithObjects(registry, root, toggleSprings);
    }

    
    
    /**
     * @brief Finds the end index of a subtree in a draw order list.
     *
     * This function determines the range of items in the `drawOrder` vector
     * that belong to the subtree starting at the specified `startIndex`.
     * The subtree is defined as all consecutive items with a depth greater
     * than the depth of the item at `startIndex`.
     *
     * @param drawOrder A vector of `UIDrawListItem` objects representing the draw order.
     * @param startIndex The index of the item where the subtree starts.
     * @return The index one past the last descendant of the subtree.
     */
    static size_t findSubtreeEnd(const std::vector<UIDrawListItem>& drawOrder,
        size_t                        startIndex)
    {
        int myDepth = drawOrder[startIndex].depth;
        size_t i = startIndex + 1;
        // all items with depth > myDepth belong to my subtree
        while (i < drawOrder.size() && drawOrder[i].depth > myDepth) {
            ++i;
        }
        return i;  // one past the last descendant
    }
    
    struct ActiveScissor {
        size_t endExclusive; // first index after the subtree
        int    z;
        entt::entity pane{entt::null}; // NEW: which pane this scope represents
        std::shared_ptr<layer::Layer> layerPtr; // layer used for begin/end scissor
    };

    void box::drawAllBoxesShaderEnabled(entt::registry &registry,
                           std::shared_ptr<layer::Layer> layerPtr)
    {
        auto defaultLayerPtr = layerPtr;
        // 1) Build a flat list in the exact order your old box::Draw would have used.
        std::vector<UIDrawListItem> drawOrder;
        drawOrder.reserve(200); // or an estimate of your total UI element count
        
        std::vector<ActiveScissor> scissorStack;

        // 2) Now draw them all with one tight fully owning group loop.
        // PERF: Initialize cached view/group once before use.
        EnsureUIGroupInitialized(registry);

        // PERF: Use cached view for UIBoxComponent iteration
        for (auto ent : globalUIBoxView)
        {
            // check if the entity is active
            if (!entity_gamestate_management::active_states_instance().is_active(registry.get<entity_gamestate_management::StateTag>(ent)))
                continue; // skip inactive entities
            // TODO: probably sort these with layer order
            buildUIBoxDrawList(registry, ent, drawOrder);
        }

        entt::entity uiBoxEntity{entt::null};
        int drawOrderZIndex = 0;

        // 3) Loop in our flattened order:
        for (size_t i = 0; i < drawOrder.size(); ++i) {
            auto &drawListItem = drawOrder[i];
            auto ent = drawListItem.e;
            
            // 1) update box Z every iteration
            auto &elemComp = globalUIGroup.get<UIElementComponent>(ent);
            if (elemComp.uiBox != uiBoxEntity) {
                uiBoxEntity     = elemComp.uiBox;
                drawOrderZIndex = registry.get<layer::LayerOrderComponent>(uiBoxEntity).zIndex;
                if (auto* l = registry.try_get<UIBoxLayer>(uiBoxEntity)) {
                    auto overrideLayer = game::GetLayer(l->layerName);
                    if (!overrideLayer) {
                        spdlog::error("UI box {} requested unknown layer '{}'", static_cast<int>(uiBoxEntity), l->layerName);
                        layerPtr = defaultLayerPtr;
                    } else {
                        layerPtr = overrideLayer;
                    }
                } else {
                    layerPtr = defaultLayerPtr;
                }
            }
            
            //TODO: update with:drawOrderZIndex = registry.get<layer::LayerOrderComponent>(uiBoxEntity).zIndex; if the uibox has changed.

            if (!registry.valid(ent))
                continue;

            auto &cfg = globalUIGroup.get<UIConfig>(ent);
            
            auto &xf = globalUIGroup.get<transform::Transform>(ent);
            
            // close any finished scissor scopes before drawing item i
            while (!scissorStack.empty() && i >= scissorStack.back().endExclusive) {
                // Pop matrix first so only the children were translated
                // layer::QueueCommand<layer::CmdPopMatrix>(
                //     layerPtr, [](layer::CmdPopMatrix*){}, scissorStack.back().z
                // );
                auto scopeLayer = scissorStack.back().layerPtr ? scissorStack.back().layerPtr : defaultLayerPtr;
                layer::QueueCommand<layer::CmdEndScissorMode>(
                    scopeLayer, [](layer::CmdEndScissorMode*){}, scissorStack.back().z
                );
                scissorStack.pop_back();
            }

            
            // 1) Check if the UI element is a scroll pane
            if (cfg.uiType == UITypeEnum::SCROLL_PANE) {
                auto &scr = registry.get<UIScrollComponent>(ent);
                
                // find [start=i, end) where depth strictly increases and stays in same UIBox
                size_t start = i;
                int parentDepth = drawOrder[i].depth;
                size_t end = i + 1;
                while (end < drawOrder.size() && drawOrder[end].depth > parentDepth) {
                    auto &nextElem = globalUIGroup.get<UIElementComponent>(drawOrder[end].e);
                    if (nextElem.uiBox != uiBoxEntity) break;
                    ++end;
                }

                // compute a SCREEN-SPACE rect; don't divide by 2
                // (if your Transform is center-based, convert to top-left)
                float x = xf.getActualX(); // top-left x in screen coords
                float y = xf.getActualY(); // top-left y in screen coords
                float w = xf.getActualW();
                float h = xf.getActualH();
                Rectangle r{ x, y, w, h };

                layer::QueueCommand<layer::CmdBeginScissorMode>(
                    layerPtr, [r](layer::CmdBeginScissorMode *cmd){ cmd->area = r; }, drawOrderZIndex
                );

                // keep the scope open until we reach 'end'
                scissorStack.push_back({ end, drawOrderZIndex, ent, layerPtr });

                // Optional (if you want to offset children visually by scroll):
                // layer::QueueCommand<layer::CmdPushMatrix>(
                //     layerPtr, [&](layer::CmdPushMatrix *cmd) {
                //     }, drawOrderZIndex
                // );
                // layer::QueueCommand<layer::CmdTranslate>(
                //     layerPtr, [&, scr](layer::CmdTranslate *c) {
                //         c->y = scr.offset; // scroll offset in screen space
                //     }, drawOrderZIndex
                // );
                
                // layer::QueueCommand<layer::CmdTranslate>(layerPtr, [&, scr](auto* c){ c->dx = horiz? -scr.offset : 0; c->dy = vert? -scr.offset : 0; }, drawOrderZIndex);
                // and later, when scope closes (in the while-pop above), queue PopMatrix before EndScissor.
            }


            // Check pipeline
            auto* pipeline = registry.try_get<shader_pipeline::ShaderPipelineComponent>(ent);
            if (pipeline && (pipeline->hasPassesOrOverlays())) {
                // SPDLOG_DEBUG("Drawing UI element {} with shader pipeline", (int)    ent);
                //FIXME: only include children if config says so.
                // Determine range: element + all children with greater depth
                size_t start = i;
                int parentDepth = drawOrder[i].depth;
                size_t end = i + 1;
                bool includeChildren = cfg.includeChildrenInShaderPass;

                if (includeChildren) {
                    while (end < drawOrder.size() && drawOrder[end].depth > parentDepth)
                    {
                        auto &nextElemComp = globalUIGroup.get<UIElementComponent>(drawOrder[end].e);
                        if (nextElemComp.uiBox != uiBoxEntity) {
                            break; // stop if we reach a different UIBox
                        }
                        
                        // increment end index otherwise, we are in the same UIBox
                        ++end;
                    }
                }

                // Offscreen render pass
                //TODO: make this a command that can be queued. Also, how to pass draw order list in an efficient way?
                //TODO: how to do z index here? layer & tree order?
                layer::QueueCommand<layer::CmdRenderUISliceFromDrawList>(
                    layerPtr,
                    [&, start, end](layer::CmdRenderUISliceFromDrawList *cmd) {
                      // build only the subrange you need
                      cmd->drawList.assign(
                        drawOrder.begin() + start,
                        drawOrder.begin() + end
                      );
                      cmd->startIndex = 0;      // after assign, indices are [0..end-start)
                      cmd->endIndex   = end - start;
                    },
                    drawOrderZIndex
                  );
                // renderSliceOffscreenFromDrawList(registry, drawOrder, start, end, layerPtr);
                if (includeChildren) {
                    i = end - 2;
                }
                continue;
            }

            // Pull the five group‐components by reference (O(1)):
            // auto &elemComp = globalUIGroup.get<UIElementComponent>(ent);
            // auto &st = globalUIGroup.get<UIState>(ent);
            // auto &node = globalUIGroup.get<transform::GameObject>(ent);
            // auto &xf = globalUIGroup.get<transform::Transform>(ent);

            if (elemComp.uiBox != uiBoxEntity)
            {
                // If this is a new UIBox, set the current box entity.
                uiBoxEntity = elemComp.uiBox;
                drawOrderZIndex = registry.get<layer::LayerOrderComponent>(uiBoxEntity).zIndex;
            }

            // Finally call your lean DrawSelf that only does `try_get`
            // for optional pieces (RoundedRectangleVerticesCache, etc.).
            //FIXME: this should be a command that can be queued.
            // element::DrawSelfImmediate(layerPtr, ent, elemComp, cfg, st, node, xf);
            
            layer::QueueCommand<layer::CmdRenderUISelfImmediate>(
                layerPtr, [ent](layer::CmdRenderUISelfImmediate *cmd) {
                    //TODO: fill here
                    cmd->entity = ent;
                }, drawOrderZIndex);
        }

        // 4) If you still want to draw bounding boxes for each UIBox itself:
        if (globals::getDrawDebugInfo())
        {
            for (auto box : globalUIBoxView)
            {
                transform::DrawBoundingBoxAndDebugInfo(&registry, box, layerPtr);
            }
        }
        
        // if anything remains open (e.g., if the last element ended a scope), close it
        while (!scissorStack.empty()) {
            auto scope = scissorStack.back();
            scissorStack.pop_back();
            
            
            // Draw transient scrollbars (inside scissor, so they clip)
            if (registry.valid(scope.pane)
                && registry.any_of<ui::UIScrollComponent, transform::Transform>(scope.pane)) {

                const auto &scr = registry.get<ui::UIScrollComponent>(scope.pane);
                auto &pxf = registry.get<transform::Transform>(scope.pane);

                // visibility window
                float alphaFrac = 0.f;
                if (scr.showUntilT > 0.0) {
                    const double now = main_loop::getTime();
                    const double remain = scr.showUntilT - now;
                    if (remain > 0.0) {
                        const double tail = std::min<double>(0.25, scr.showSeconds);
                        alphaFrac = (remain >= tail) ? 1.f : float(remain / tail);
                    }
                }

                if (alphaFrac > 0.f) {
                    const float x = pxf.getActualX();
                    const float y = pxf.getActualY();
                    const float w = pxf.getActualW();
                    const float h = pxf.getActualH();

                    // V bar (single-axis)
                    if (scr.maxOffset > 0.f) {
                        const float visFrac = std::clamp(h / std::max(1.f, scr.contentSize.y), 0.f, 1.f);
                        const float barLen  = std::max(scr.barMinLen, visFrac * h);
                        const float travel  = h - barLen;
                        // ✅ normalize with min/max
                        const float denom = std::max(1e-6f, scr.maxOffset - scr.minOffset);
                        float t = (scr.offset - scr.minOffset) / denom;
                        t = std::clamp(t, 0.f, 1.f);
                        // const float barY    = y + barLen * 0.5f + t * travel;
                        const float barX    = x + w - scr.barThickness;

                        Color c = WHITE;
                        c.a = static_cast<unsigned char>(std::round(160.f * alphaFrac));

                        // Rectangle br{ barX, barY, scr.barThickness, barLen };
                        
                        
                        // convert to centered rect for CmdDrawCenteredFilledRoundedRect
                        const float cx = barX + scr.barThickness * 0.5f;
                        const float cy = y + barLen * 0.5f + t * travel;
                        
                        // choose a radius (wire this to your component if you have one)
                        const float r = 6.0f;
                        
                        

                        layer::QueueCommand<layer::CmdDrawCenteredFilledRoundedRect>(
                            layerPtr,
                            [cx, cy, scr, barLen, c, r](auto* cmd){
                                cmd->x = cx;
                                cmd->y = cy;
                                cmd->w = scr.barThickness;
                                cmd->h = barLen * 0.9;
                                cmd->rx = r;          // rounded corners
                                cmd->ry = r;
                                cmd->color = c;
                                cmd->lineWidth.reset(); // filled, no stroke
                            },
                            scope.z + 1
                        );
                    }

                    // (Optional) Horizontal bar if you add X scrolling later…
                }
            }
    
            layer::QueueCommand<layer::CmdEndScissorMode>(
                scope.layerPtr ? scope.layerPtr : defaultLayerPtr, [](layer::CmdEndScissorMode*){}, scope.z
            );
        }
    }


    void box::drawAllBoxes(entt::registry &registry,
                           std::shared_ptr<layer::Layer> layerPtr)
    {
        // Phase 5 consolidation: Delegate to the full-featured shader-enabled version.
        // The shader-enabled version has proper scissor stack management and layer overrides,
        // which were missing in this simpler version (it started scissor modes but never
        // closed them properly).
        drawAllBoxesShaderEnabled(registry, layerPtr);
    }

    void box::buildUIBoxDrawList(
        entt::registry &registry,
        entt::entity boxEntity,
        std::vector<UIDrawListItem> &out,
        int depth )
    {
        
        using namespace entity_gamestate_management;

        // --- top of buildUIBoxDrawList ---
        if (auto* tag = registry.try_get<StateTag>(boxEntity)) {
            if (!is_active(*tag))
                return; // skip entire box and subtree
        }
        
        // Fetch the UIBox and its GameObject. If either is missing, bail.
        auto *uiBox = registry.try_get<UIBoxComponent>(boxEntity);
        auto *boxNode = registry.try_get<transform::GameObject>(boxEntity);
        if (!uiBox || !boxNode)
            return;

        // 1) Draw all direct children of this box (except tooltips & alerts)
        //    Prefer orderedChildren for stable ordering; fall back to the map if empty.
        if (!boxNode->orderedChildren.empty()) {
            for (auto child : boxNode->orderedChildren)
            {
                auto *childConfig = registry.try_get<UIConfig>(child);
                std::string entryName = (childConfig && childConfig->id) ? *childConfig->id : std::string{};
                if (entryName.empty()) {
                    for (auto const &kv : boxNode->children) {
                        if (kv.second == child) {
                            entryName = kv.first;
                            break;
                        }
                    }
                }

                if (auto* tag = registry.try_get<StateTag>(child)) {
                    if (!is_active(*tag))
                        continue; // skip inactive elements
                }

                auto *childUIElement = registry.try_get<UIElementComponent>(child);
                auto *childUIBox = registry.try_get<UIBoxComponent>(child);
                auto *childNode = registry.try_get<transform::GameObject>(child);

                // Skip if not a valid entity or not visible
                if (!registry.valid(child) || !childNode || !childNode->state.visible)
                    continue;

                // If it’s a UIElement (and not “h_popup”/“alert”), push that element + its subtree:
                if (childUIElement && entryName != "h_popup" && entryName != "alert")
                {
                    element::buildUIDrawList(registry, child, out, depth);
                }
                // If it’s another UIBox, recurse fully into that box:
                else if (childUIBox)
                {
                    buildUIBoxDrawList(registry, child, out, depth);
                }
            }
        } else {
            // Fallback: use map order when orderedChildren is not populated.
            for (auto const &entry : boxNode->children)
            {
                // entry.first is the name (string), entry.second is the entity
                const auto &entryName = entry.first;
                entt::entity child = entry.second;

                if (auto* tag = registry.try_get<StateTag>(child)) {
                    if (!is_active(*tag))
                        continue; // skip inactive elements
                }

                auto *childUIElement = registry.try_get<UIElementComponent>(child);
                auto *childUIBox = registry.try_get<UIBoxComponent>(child);
                auto *childNode = registry.try_get<transform::GameObject>(child);

                // Skip if not a valid entity or not visible
                if (!registry.valid(child) || !childNode || !childNode->state.visible)
                    continue;

                if (childUIElement && entryName != "h_popup" && entryName != "alert")
                {
                    element::buildUIDrawList(registry, child, out, depth);
                }
                else if (childUIBox)
                {
                    buildUIBoxDrawList(registry, child, out, depth);
                }
            }
        }

        // 2) If this box’s node is visible, draw its uiRoot first:
        if (boxNode->state.visible && uiBox->uiRoot)
        {

            entt::entity rootElem = uiBox->uiRoot.value();
            // 1) draw the root itself (same as element::DrawSelf(root))
            out.push_back({rootElem, depth});
            // rootElem might itself have children; flatten them as well
            element::buildUIDrawList(registry, rootElem, out, depth + 1);
        }

        // 3) Iterate drawLayers in insertion order:
        //    for each layerEntity: if it’s a UIElement → flatten its subtree;
        //                         if it’s a UIBox     → recurse on that box.
        for (auto const &layerEntry : uiBox->drawLayers)
        {
            entt::entity layerEnt = layerEntry.second;
            if (!registry.valid(layerEnt))
                continue;

            auto *layerElemBox = registry.try_get<UIBoxComponent>(layerEnt);
            auto *layerElemEl = registry.try_get<UIElementComponent>(layerEnt);
            auto *layerNode = registry.try_get<transform::GameObject>(layerEnt);

            // Skip if it’s not visible or no GameObject
            if (!layerNode || !layerNode->state.visible)
                continue;

            if (layerElemEl)
            {
                element::buildUIDrawList(registry, layerEnt, out, depth);
            }
            else if (layerElemBox)
            {
                buildUIBoxDrawList(registry, layerEnt, out, depth);
            }
        }

        // 4) Finally, if there’s an “alert” child, draw it last:
        auto alertIt = boxNode->children.find("alert");
        if (alertIt != boxNode->children.end())
        {
            entt::entity alertEnt = alertIt->second;
            auto *alertNode = registry.try_get<transform::GameObject>(alertEnt);
            auto *alertConfig = registry.try_get<UIConfig>(alertEnt);

            if (registry.valid(alertEnt) && alertNode && alertNode->state.visible && alertConfig)
            {
                element::buildUIDrawList(registry, alertEnt, out, depth);
            }
        }
    }

    void box::Move(entt::registry &registry, entt::entity self, float dt)
    {
        // DEPRECATED: This function is a no-op stub kept for Lua API compatibility.
        // UI movement is now handled through transform springs and direct position updates.
        (void)registry; (void)self; (void)dt;
    }

    void box::Drag(entt::registry &registry, entt::entity self, Vector2 offset, float dt)
    {
        // DEPRECATED: This function is a no-op stub kept for Lua API compatibility.
        // UI dragging is now handled through the input system and direct position updates.
        (void)registry; (void)self; (void)offset; (void)dt;
    }

    void box::AddChild(entt::registry &registry, entt::entity uiBox, UIElementTemplateNode uiElementDef, entt::entity parent)
    {
        BuildUIElementTree(registry, uiBox, uiElementDef, parent);
        RenewAlignment(registry, uiBox);
    }

    void box::SetContainer(entt::registry &registry, entt::entity self, entt::entity container)
    {
        if (!registry.valid(self)) return;
        
        auto *transform = registry.try_get<transform::Transform>(self);
        auto *uiBox = registry.try_get<UIBoxComponent>(self);

        if (!transform || !uiBox) return;

        // TODO: document what a container is relative to hierarchy too

        // so this sets the uiRoot hierarchy (all ui elements in ui box) to be inside container
        // then it sets the uibox itself to be inside containerp as well.
        transform::ConfigureContainerForEntity(&registry, uiBox->uiRoot.value(), container);
        transform::ConfigureContainerForEntity(&registry, self, container);
    }

    /// “Inject” a UI template into an existing box at runtime
    void box::AddTemplateToUIBox(entt::registry &registry,
                            entt::entity uiBoxEntity,
                            UIElementTemplateNode &templateDef,
                            std::optional<entt::entity> maybeParent)
    {
        // 1) get the box component & its root
        auto &boxComp = registry.get<UIBoxComponent>(uiBoxEntity);
        assert(boxComp.uiRoot && "UIBox has to be already initialized");
        entt::entity uiRoot = boxComp.uiRoot.value();

        // 2) decide where to attach: explicit parent or fall back to root
        entt::entity parent = maybeParent.value_or(uiRoot);

        // 3) build the tree under that parent
        box::BuildUIElementTree(registry, uiBoxEntity, templateDef, parent);

        // // 4) recalc sizes & alignment on the whole subtree
        // //    grab the transform of uiRoot to get its current bounds
        // auto &rootT = registry.get<transform::Transform>(uiRoot);
        // Rectangle rootRect{
        //     rootT.getActualX(),
        //     rootT.getActualY(),
        //     rootT.getActualW(),
        //     rootT.getActualH()};
        // ui::LocalTransform calcTransform{rootRect.x, rootRect.y, rootRect.width, rootRect.height};
        // CalcTreeSizes(registry, uiRoot, calcTransform, /* topLevel = */ true);
        // handleAlignment(registry, uiRoot);
        // ui::element::InitializeVisualTransform(registry, uiRoot);

        // // 5) assign ordering so your new widgets sort & draw correctly
        // AssignLayerOrderComponents(registry, uiBoxEntity);
        // AssignTreeOrderComponents(registry, uiRoot);

        // call renew alignment to ensure all elements are aligned correctly
        RenewAlignment(registry, uiBoxEntity);
    }
    std::string box::DebugPrint(entt::registry &registry, entt::entity self, int indent)
    {
        if (!registry.valid(self)) return "[invalid entity]";
        
        auto *transform = registry.try_get<transform::Transform>(self);
        auto *uiBox = registry.try_get<UIBoxComponent>(self);
        auto *uiBoxObject = registry.try_get<transform::GameObject>(self);
        auto *config = registry.try_get<UIConfig>(self);
        auto *role = registry.try_get<transform::InheritedProperties>(self);
        
        if (!transform || !uiBox || !config) return "[missing components]";
        if (!uiBox->uiRoot) return "[no uiRoot]";
        
        auto *uiConfig = registry.try_get<UIConfig>(uiBox->uiRoot.value());

        auto layerOrderComp = registry.try_get<layer::LayerOrderComponent>(self);

        std::string result = fmt::format(" \n| UIBox | - ID: {} [entt-{}] w/h: {}/{} UIElement children: {} | LOC({},{}) OFF({},{}) OFF_ALN({},{}) {} LayerOrder: {}",
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
                                         uiBoxObject->state.isBeingHovered ? "HOVERED" : "",
                                         layerOrderComp ? std::to_string(layerOrderComp->zIndex) : "N/A");

        if (uiBox->uiRoot)
        {
            result += ui::element::DebugPrintTree(registry, uiBox->uiRoot.value(), indent + 1);
        }

        return result;
    }

    bool box::ReplaceChildren(
        entt::registry& registry,
        entt::entity parent,
        UIElementTemplateNode& newDefinition
    ) {
        if (!registry.valid(parent)) {
            SPDLOG_WARN("ReplaceChildren: Invalid parent entity");
            return false;
        }
        
        auto* uiElement = registry.try_get<UIElementComponent>(parent);
        if (!uiElement) {
            SPDLOG_WARN("ReplaceChildren: Parent {} has no UIElementComponent", 
                        static_cast<int>(parent));
            return false;
        }
        
        entt::entity uiBox = uiElement->uiBox;
        if (!registry.valid(uiBox)) {
            SPDLOG_WARN("ReplaceChildren: UIBox {} is invalid", 
                        static_cast<int>(uiBox));
            return false;
        }
        
        auto* node = registry.try_get<transform::GameObject>(parent);
        if (!node) {
            SPDLOG_WARN("ReplaceChildren: Parent {} has no GameObject", 
                        static_cast<int>(parent));
            return false;
        }
        
        std::vector<entt::entity> childrenToDestroy;
        childrenToDestroy.reserve(node->orderedChildren.size());
        for (auto child : node->orderedChildren) {
            if (registry.valid(child)) {
                childrenToDestroy.push_back(child);
            }
        }
        
        for (auto child : childrenToDestroy) {
            box::TraverseUITreeBottomUp(registry, child, [&](entt::entity e) {
                if (auto* cfg = registry.try_get<UIConfig>(e)) {
                    if (cfg->object && registry.valid(cfg->object.value())) {
                        registry.destroy(cfg->object.value());
                    }
                }
                registry.destroy(e);
            }, false);
        }
        
        node->children.clear();
        node->orderedChildren.clear();
        
        BuildUIElementTree(registry, uiBox, newDefinition, parent);
        
        RenewAlignment(registry, uiBox);
        
        SPDLOG_DEBUG("ReplaceChildren: Replaced {} old children with new content on entity {}", 
                     childrenToDestroy.size(), static_cast<int>(parent));
        
        return true;
    }

}
