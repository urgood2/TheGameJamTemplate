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
        void ClampUsingMinDimensionsIfPresent(ui::UIConfig &uiConfig, ui::LocalTransform &calcCurrentNodeTransform);
        auto TreeCalcSubContainer(entt::registry &registry, entt::entity uiElement, ui::LocalTransform parentUINodeRect,
                bool forceRecalculateLayout, std::optional<float> scale, LocalTransform &calcCurrentNodeTransform, std::unordered_map<entt::entity, Vector2> &contentSizes) -> Vector2;
        auto SubCalculateContainerSize(ui::LocalTransform &calcCurrentNodeTransform, ui::LocalTransform &parentUINodeRect, ui::UIConfig &uiConfig, ui::LocalTransform &calcChildTransform, float padding, transform::GameObject &node, entt::registry &registry, float factor, std::unordered_map<entt::entity, Vector2> &contentSizes) ->void;
        auto GetUIEByID(entt::registry &registry, entt::entity node, const std::string &id) -> std::optional<entt::entity>;
        // Function to remove a group of elements from the UI system
        auto RemoveGroup(entt::registry &registry, entt::entity entity, const std::string &group) -> bool;
        auto GetGroup(entt::registry &registry, entt::entity entity, const std::string &group) -> std::vector<entt::entity>;
        auto Remove(entt::registry &registry, entt::entity entity) -> void;
        auto Draw(std::shared_ptr<layer::Layer> layerPtr, entt::registry &registry, entt::entity entity) -> void;
        auto Recalculate(entt::registry &registry, entt::entity entity) -> void;
        auto Move(entt::registry &registry, entt::entity self, float dt) -> void;
        auto Drag(entt::registry &registry, entt::entity self, Vector2 offset, float dt) -> void;
        auto AddChild(entt::registry& registry, entt::entity uiBox, UIElementTemplateNode uiElementDef, entt::entity parent) -> void;
        auto SetContainer(entt::registry &registry, entt::entity self, entt::entity container) -> void;
        auto DebugPrint(entt::registry &registry, entt::entity self, int indent = 0) -> std::string;

    }

}