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
#include "box.hpp"
#include "util.hpp"

#include "rlgl.h"
#include "raylib.h"



namespace ui {
    
    

    namespace element {
        auto Initialize(entt::registry &registry, entt::entity parent, entt::entity uiBox, UITypeEnum type, std::optional<UIConfig> config) -> entt::entity;
        auto ApplyScalingFactorToSizesInSubtree(entt::registry &registry, entt::entity rootEntity, float scaling) -> void;
        void UpdateUIObjectScalingAndRecnter(ui::UIConfig *uiConfig, float newScale, transform::Transform *transform);
        auto SetValues(entt::registry &registry, entt::entity entity, const LocalTransform &_T, bool recalculate) -> void;
        auto DebugPrintTree(entt::registry &registry, entt::entity entity, int indent) -> std::string;
        auto InitializeVisualTransform(entt::registry &registry, entt::entity entity) -> void;
        auto JuiceUp(entt::registry &registry, entt::entity entity, float amount, float rot_amt) -> void;
        auto CanBeDragged(entt::registry &registry, entt::entity entity) -> std::optional<entt::entity>;
        auto DrawChildren(std::shared_ptr<layer::Layer> layerPtr, entt::registry &registry, entt::entity entity) -> void;
        auto SetWH(entt::registry &registry, entt::entity entity) -> std::pair<float, float>;
        auto ApplyAlignment(entt::registry &registry, entt::entity entity, float x, float y) -> void;
        auto SetAlignments(entt::registry &registry, entt::entity entity, std::optional<Vector2> uiBoxOffset = std::nullopt, bool rootEntity = false) -> void;
        void UpdateText(entt::registry &registry, entt::entity entity, UIConfig *config, UIState *state);
        void UpdateObject(entt::registry &registry, entt::entity entity, UIConfig *elementConfig, transform::GameObject *elementNode, UIConfig *objectConfig, transform::Transform *objTransform, transform::InheritedProperties *objectRole, transform::GameObject *objectNode);
        void DrawSelf(std::shared_ptr<layer::Layer> layerPtr, entt::entity entity, UIElementComponent &uiElementComp, UIConfig &configComp, UIState &stateComp, transform::GameObject &nodeComp, transform::Transform &transformComp, const int &zIndex = 0);
        void Update(entt::registry &registry, entt::entity entity, float dt,  UIConfig *uiConfig, transform::Transform *transform, UIElementComponent *uiElement, transform::GameObject *node);
        auto CollidesWithPoint(entt::registry &registry, entt::entity entity, const Vector2 &cursorPosition) -> bool;
        auto PutFocusedCursor(entt::registry &registry, entt::entity entity) -> Vector2;
        auto Remove(entt::registry &registry, entt::entity entity) -> void;
        auto Click(entt::registry &registry, entt::entity entity) -> void;
        auto Release(entt::registry &registry, entt::entity entity, entt::entity objectBeingDragged) -> void;
        auto ApplyHover(entt::registry &registry, entt::entity entity) -> void;
        auto StopHover(entt::registry &registry, entt::entity entity) -> void;
        void buildUIDrawList(entt::registry &registry,
            entt::entity root,
            std::vector<entt::entity> &out);

    }
}