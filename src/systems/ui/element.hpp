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
        auto SetValues(entt::registry &registry, entt::entity entity, const LocalTransform &_T, bool recalculate) -> void;
        auto DebugPrintTree(entt::registry &registry, entt::entity entity, int indent) -> std::string;
        auto InitializeVisualTransform(entt::registry &registry, entt::entity entity) -> void;
        auto JuiceUp(entt::registry &registry, entt::entity entity, float amount, float rot_amt) -> void;
        auto CanBeDragged(entt::registry &registry, entt::entity entity) -> std::optional<entt::entity>;
        auto DrawChildren(std::shared_ptr<layer::Layer> layerPtr, entt::registry &registry, entt::entity entity) -> void;
        auto SetWH(entt::registry &registry, entt::entity entity) -> std::pair<float, float>;
        auto ApplyAlignment(entt::registry &registry, entt::entity entity, float x, float y) -> void;
        auto SetAlignments(entt::registry &registry, entt::entity entity, std::optional<Vector2> uiBoxOffset = std::nullopt, bool rootEntity = false) -> void;
        auto UpdateText(entt::registry &registry, entt::entity entity) -> void;
        auto UpdateObject(entt::registry &registry, entt::entity entity) -> void;
        auto DrawSelf(std::shared_ptr<layer::Layer> layerPtr, entt::registry &registry, entt::entity entity) -> void;
        auto Update(entt::registry &registry, entt::entity entity, float dt) -> void;
        auto CollidesWithPoint(entt::registry &registry, entt::entity entity, const Vector2 &cursorPosition) -> bool;
        auto PutFocusedCursor(entt::registry &registry, entt::entity entity) -> Vector2;
        auto Remove(entt::registry &registry, entt::entity entity) -> void;
        auto Click(entt::registry &registry, entt::entity entity) -> void;
        auto Release(entt::registry &registry, entt::entity entity, entt::entity objectBeingDragged) -> void;
        auto ApplyHover(entt::registry &registry, entt::entity entity) -> void;
        auto StopHover(entt::registry &registry, entt::entity entity) -> void;

    }
}