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

#include "rlgl.h"
#include "raylib.h"



namespace ui {

    namespace box {
        void AddTemplateToUIBox(entt::registry &registry,
                            entt::entity uiBoxEntity,
                            UIElementTemplateNode &templateDef,
                            std::optional<entt::entity> maybeParent = std::nullopt);
        auto handleAlignment(entt::registry &registry, entt::entity root) -> void;
        auto BuildUIElementTree(entt::registry& registry, entt::entity uiBoxEntity, UIElementTemplateNode &uiElementDef, entt::entity uiElementParent) -> void;
        auto Initialize(entt::registry &registry, const TransformConfig &transformData, UIElementTemplateNode definition, std::optional<UIConfig> config = std::nullopt) -> entt::entity;
        auto placeUIElementsRecursively(entt::registry &registry, entt::entity uiElement, ui::LocalTransform &runningTransform, ui::UITypeEnum parentType, entt::entity parent) -> void;
        void placeNonContainerUIE(transform::InheritedProperties &role, ui::LocalTransform &runningTransform, entt::entity uiElement, ui::UITypeEnum parentType, ui::UIState &uiState, ui::UIConfig &uiConfig);
        auto ClampDimensionsToMinimumsIfPresent(ui::UIConfig &uiConfig, ui::LocalTransform &calcTransform) -> void;
        auto CalcTreeSizes(entt::registry &registry, entt::entity uiElement, ui::LocalTransform parentUINodeRect,
            bool forceRecalculateLayout = false, std::optional<float> scale = std::nullopt) -> std::pair<float, float>;
        auto TreeCalcSubNonContainer(entt::registry &registry, entt::entity uiElement, ui::LocalTransform parentUINodeRect,
                                     bool forceRecalculateLayout, std::optional<float> scale, LocalTransform &calcCurrentNodeTransform) -> Vector2;
        // void ClampUsingMinDimensionsIfPresent(ui::UIConfig &uiConfig, ui::LocalTransform &calcCurrentNodeTransform);
        void RenewAlignment(entt::registry &registry, entt::entity self);
        auto TreeCalcSubContainer(entt::registry &registry, entt::entity uiElement, ui::LocalTransform parentUINodeRect,
                bool forceRecalculateLayout, std::optional<float> scale, LocalTransform &calcCurrentNodeTransform, std::unordered_map<entt::entity, Vector2> &contentSizes) -> Vector2;
        auto SubCalculateContainerSize(ui::LocalTransform &calcCurrentNodeTransform, ui::LocalTransform &parentUINodeRect, ui::UIConfig &uiConfig, ui::LocalTransform &calcChildTransform, float padding, transform::GameObject &node, entt::registry &registry, float factor, std::unordered_map<entt::entity, Vector2> &contentSizes) ->void;
        auto GetUIEByID(entt::registry &registry, entt::entity node, const std::string &id) -> std::optional<entt::entity>;
        std::optional<entt::entity> GetUIEByID(entt::registry &registry, const std::string &id);
        // Function to remove a group of elements from the UI system
        auto RemoveGroup(entt::registry &registry, entt::entity entity, const std::string &group) -> bool;
        auto GetGroup(entt::registry &registry, entt::entity entity, const std::string &group) -> std::vector<entt::entity>;
        auto Remove(entt::registry &registry, entt::entity entity) -> void;
        // auto Draw(std::shared_ptr<layer::Layer> layerPtr, entt::registry &registry, entt::entity entity) -> void;
        auto Recalculate(entt::registry &registry, entt::entity entity) -> void;
        void AssignTreeOrderComponents(entt::registry& registry, entt::entity rootUIElement);
        auto AssignLayerOrderComponents(entt::registry& registry, entt::entity uiBox) -> void;
        auto Move(entt::registry &registry, entt::entity self, float dt) -> void;
        auto Drag(entt::registry &registry, entt::entity self, Vector2 offset, float dt) -> void;
        auto AddChild(entt::registry& registry, entt::entity uiBox, UIElementTemplateNode uiElementDef, entt::entity parent) -> void;
        auto SetContainer(entt::registry &registry, entt::entity self, entt::entity container) -> void;
        auto DebugPrint(entt::registry &registry, entt::entity self, int indent = 0) -> std::string;
        void TraverseUITreeBottomUp(entt::registry &registry, entt::entity rootUIElement, std::function<void(entt::entity)> visitor);
        void drawAllBoxes(entt::registry &registry,
            std::shared_ptr<layer::Layer> layerPtr);
        void drawAllBoxesShaderEnabled(entt::registry &registry,
                std::shared_ptr<layer::Layer> layerPtr);
        void buildUIBoxDrawList(
                entt::registry &registry,
                entt::entity        boxEntity,
                std::vector<UIDrawListItem> &out,
                int depth = 0);
                
        

    }
    
    // a ui element wrapper that can be used to access UI elements in a more convenient way from lua            
    struct UIElementHandle {
        entt::registry* reg;
        entt::entity   elem;

        UIElementHandle(entt::registry* r = nullptr, entt::entity e = entt::null)
            : reg(r), elem(e) {}

        // Fetch by string id under a UIBox entity
        static std::optional<UIElementHandle>
        getById(entt::registry& r, entt::entity boxEntity, const std::string& id) {
            auto result = ui::box::GetUIEByID(r, boxEntity, id);
            if (result) return UIElementHandle(&r, *result);
            return std::nullopt;
        }

        // Get parent UI element (or null)
        UIElementHandle parent() const {
            if (!reg || elem == entt::null) return {reg, entt::null};
            auto &node = reg->get<transform::GameObject>(elem);
            if (node.parent) return UIElementHandle(reg, node.parent.value());
            return {reg, entt::null};
        }

        // Get all direct children handles
        std::vector<UIElementHandle> children() const {
            std::vector<UIElementHandle> out;
            if (!reg || elem == entt::null) return out;
            auto &node = reg->get<transform::GameObject>(elem);
            for (auto child : node.orderedChildren) {
                out.emplace_back(reg, child);
            }
            return out;
        }

        // Move this element (and its subtree) under a new parent
        void moveTo(const UIElementHandle& newParent) const {
            if (!reg || elem == entt::null) return;
            // Remove from old parent's containers
            auto &selfNode = reg->get<transform::GameObject>(elem);
            if (selfNode.parent) {
                auto oldParent = selfNode.parent.value();
                auto &oldGO = reg->get<transform::GameObject>(oldParent);
                // erase from map and vector
                if (auto* cfg = reg->try_get<UIConfig>(elem)) {
                    oldGO.children.erase(cfg->id.value());
                }
                oldGO.orderedChildren.erase(
                    std::remove(oldGO.orderedChildren.begin(), oldGO.orderedChildren.end(), elem),
                    oldGO.orderedChildren.end());
            }
            
            // Attach to new parent
            selfNode.parent = newParent.elem;
            if (auto* cfg = reg->try_get<UIConfig>(elem)) {
                auto &newGO = reg->get<transform::GameObject>(newParent.elem);
                newGO.children[cfg->id.value()] = elem;
                newGO.orderedChildren.push_back(elem);
                cfg->groupParent = newParent.elem;
            }
        }

        // Recursively destroy this element and any attached UI object
        void destroyRecursive() const {
            if (!reg || elem == entt::null) return;
            // post-order traversal
            ui::box::TraverseUITreeBottomUp(*reg, elem, [&](entt::entity e) {
                // destroy associated GameObject if present
                if (auto* cfg = reg->try_get<UIConfig>(e)) {
                    if (cfg->object) {
                        reg->destroy(cfg->object.value());
                    }
                }
                reg->destroy(e);
            });
        }

        // True if this element wraps a GameObject
        bool isObjectWrapper() const {
            if (!reg || elem == entt::null) return false;
            if (auto* cfg = reg->try_get<UIConfig>(elem)) {
                return cfg->uiType == UITypeEnum::OBJECT && cfg->object.has_value();
            }
            return false;
        }

        // Return the wrapped GameObject entity (undefined if not a wrapper)
        entt::entity getWrappedObject() const {
            if (auto* cfg = reg->try_get<UIConfig>(elem)) {
                return cfg->object.value_or(entt::null);
            }
            return entt::null;
        }
    };
                

}