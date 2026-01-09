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

#include "rlgl.h"
#include "raylib.h"

namespace ui {

    namespace util {

        // -----------------------------------------------------------------------------
        // Utility Functions
        // -----------------------------------------------------------------------------
        // register metadata for ui/game components to allow reflection.
        auto RegisterMeta() ->void;
        auto RemoveAll(entt::registry &registry, entt::entity entity) -> void;
        // store the ui entity in a global list (which may or may not be necessary)
        auto AddInstanceToRegistry(entt::registry &registry, entt::entity entity, const std::string &instanceType) -> void;
        // Function to calculate a small selection triangle
        auto GetChosenTriangleFromRect(float x, float y, float w, float h, bool vert) -> std::vector<Vector2>;
        // remember to call popMatrix on the layer after done drawing
        auto PrepDraw(std::shared_ptr<layer::Layer> layerPtr, entt::registry &registry, entt::entity entity, float scale = 1.0f, float rotate = 0.0f, std::optional<Vector2> offset = std::nullopt) -> void;
        auto Darken(Color colour, float percent) -> Color;
        auto MixColours(const Color &C1, const Color &C2, float proportionC1) -> Color;
        auto AdjustAlpha(Color c, float newAlpha) -> Color;
        auto IsUIContainer(const entt::registry &registry, entt::entity entity) -> bool;
        auto sliderDiscrete(entt::registry &registry, entt::entity entity, float adjustment) -> void;
    
        auto pointTranslate(Vector2& point, const Vector2& delta) -> void;
        auto pointRotate(Vector2& point, float angle) -> void;

        // Function caller for GameObject's MethodTable member
        using MethodTable = std::unordered_map<std::string, std::any>;
        template <typename Ret, typename... Args>
        Ret call_method(const MethodTable& table, const std::string& method, Args... args) {
            if (table.find(method) != table.end()) {
                auto& func = table.at(method);
                return std::any_cast<std::function<Ret(Args...)>>(func)(args...);
            }
            throw std::runtime_error("Method " + method + " not found!");
        }
        
        /*
            Utilities for rounded rectangles
        */
       
        auto emplaceOrReplaceNewRectangleCache(entt::registry &registry, entt::entity entity, int width, int height, float lineThickness, const int &type, std::optional<float> progress) -> void;

        auto GenerateInnerAndOuterVerticesForRoundedRect(float lineThickness, int width, int height, RoundedRectangleVerticesCache &cache) -> std::pair<std::vector<Vector2>, std::vector<Vector2>>;
        
        auto DrawSteppedRoundedRectangle(std::shared_ptr<layer::Layer> layerPtr, entt::registry &registry, entt::entity entity, transform::Transform &transform, ui::UIConfig* uiConfig, transform::GameObject &node, RoundedRectangleVerticesCache* rectCache, const float &visualX, const float & visualY, const float & visualW, const float & visualH, const float & visualScaleWithHoverAndMotion, const float & visualR, const float & rotationOffset, const int &type, float parallaxModifier=0, const std::unordered_map<std::string, Color> &colorOverrides={}, std::optional<float> progress = std::nullopt, std::optional<float> lineWidthOverride = std::nullopt, const int& zIndex = 0) -> void;
        void DrawSteppedRoundedRectangleImmediate(layer::Layer* layerPtr, entt::registry &registry, entt::entity entity, transform::Transform &transform, ui::UIConfig* uiConfig, transform::GameObject &node, RoundedRectangleVerticesCache* rectCache, const float &visualX, const float & visualY, const float & visualW, const float & visualH, const float & visualScaleWithHoverAndMotion, const float & visualR, const float & rotationOffset, const int &type, float parallaxModifier, const std::unordered_map<std::string, Color> &colorOverrides, std::optional<float> progress, std::optional<float> lineWidthOverride);
        
        auto DrawNPatchUIElement(std::shared_ptr<layer::Layer> layerPtr, entt::registry &registry, entt::entity entity, const Color &colorOverride, float parallaxModifier, std::optional<float> progress = std::nullopt, const int& zIndex = 0) -> void;
        
        auto RenderRectVerticlesOutlineLayer(std::shared_ptr<layer::Layer> layerPtr, const std::vector<Vector2> &outerVertices, const Color color, const  std::vector<Vector2> &innerVertices) -> void;
        void RenderRectVerticlesOutlineLayerImmediate(std::shared_ptr<layer::Layer> layerPtr, const std::vector<Vector2> &outerVertices, const Color color, const std::vector<Vector2> &innerVertices);

        auto RenderRectVerticesFilledLayer(std::shared_ptr<layer::Layer> layerPtr, const Rectangle outerRec, const std::vector<Vector2> &outerVertices, const Color color) -> void;
        void RenderRectVerticesFilledLayerImmediate(layer::Layer* layerPtr, const Rectangle outerRec, const std::vector<Vector2> &outerVertices, const Color color);
        
        auto ClipRoundedRectVertices(std::vector<Vector2>& vertices, float clipX) -> void;
        
        auto getCornerSizeForRect(int width, int height) -> float;
        
        auto ApplyTransformMatrix(const float& visualX,  const float& visualY,  const float& visualW,  const float& visualH,  const float& visualScaleWithHoverAndDynamicMotionReflected,  const float& visualR, const float& rotationOffset, layer::Layer* layerPtr, std::optional<Vector2> addedOffset = std::nullopt, bool applyOnlyTranslation = false, const int& zIndex = 0) -> void;
        void ApplyTransformMatrixImmediate(const float& visualX,  const float& visualY,  const float& visualW,  const float& visualH,  const float& visualScaleWithHoverAndDynamicMotionReflected,  const float& visualR, const float& rotationOffset, layer::Layer* layerPtr, std::optional<Vector2> addedOffset, bool applyOnlyTranslation);
        void DrawNPatchUIElementImmediate(layer::Layer* layerPtr, entt::registry &registry, entt::entity entity, const Color &colorOverride, float parallaxModifier, std::optional<float> progress);
        
        void DrawUIDecorations(layer::Layer* layerPtr, const UIDecorations& decorations, float parentX, float parentY, float parentW, float parentH);
        void DrawUIDecorationsQueued(layer::Layer* layerPtr, const UIDecorations& decorations, float parentX, float parentY, float parentW, float parentH, int zIndex);

    }
}