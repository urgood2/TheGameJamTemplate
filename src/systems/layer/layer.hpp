#pragma once

#include "raylib.h"

#include <vector>
#include <unordered_map>
#include <string>
#include <variant>
#include <functional>
#include <stdexcept>
#include <cmath>
#include <algorithm>
#include <functional>
#include <memory>
#include <typeindex>
#include <stack>

#include "layer_optimized.hpp"
#include "layer_dynamic_pool_wrapper.hpp"
#include "systems/layer/layer_command_buffer_data.hpp"
#include "sol/sol.hpp"

#include "entt/fwd.hpp"

#include "third_party/objectpool-master/src/object_pool.hpp"
// TODO: make internal functions not accessible?

namespace layer
{
    
    // only use for (DrawLayerCommandsToSpecificCanvas)
    namespace render_stack_switch_internal
    {
        extern std::stack<RenderTexture2D> renderStack;

        // Push a new render target, auto-ending the previous one if needed
        inline void Push(RenderTexture2D target)
        {
            if (!renderStack.empty())
            {
                // End the currently active texture mode
                EndTextureMode();
            }
            // SPDLOG_DEBUG("Ending previous render target {} and pushing new target {}", renderStack.empty() ? "none" : std::to_string(renderStack.top().id), target.id);
            renderStack.push(target);
            BeginTextureMode(target);
        }

        // Pop the top render target and resume the previous one
        inline void Pop()
        {
            assert(!renderStack.empty() && "Render stack underflow: Pop called without a matching Push!");

            // End current texture mode
            EndTextureMode();
            renderStack.pop();

            // Resume the previous target
            if (!renderStack.empty())
            {
                BeginTextureMode(renderStack.top());
            }
        }

        // Peek current render target (optional utility)
        inline RenderTexture2D* Current()
        {
            if (renderStack.empty()) return nullptr;
            return &renderStack.top();
        }

        // Check if we’re inside any render target
        inline bool IsActive()
        {
            return !renderStack.empty();
        }

        // Clear the entire stack and end current mode — use with caution
        inline void ForceClear()
        {
            if (!renderStack.empty())
            {
                EndTextureMode();
            }

            while (!renderStack.empty()) renderStack.pop();
        }
    }
    //------------------------------------------------------------------------------------
    // lua exposure
    //------------------------------------------------------------------------------------
    extern void exposeToLua(sol::state &lua);

    //------------------------------------------------------------------------------------
    // Data Structures Definition
    //------------------------------------------------------------------------------------
    using DrawCommandArgs = std::variant<bool, int, int *, float *, float, Color, Camera2D *, Texture2D, struct Rectangle, struct NPatchInfo,  std::string, Font, Vector2, Vector3, Vector4, std::vector<Vector2>, std::vector<int>, std::vector<float>, Shader, entt::entity, entt::registry *>;

    struct LayerOrderComponent
    {
        int zIndex = 0; // Z-index for sorting layers
        bool operator<(const LayerOrderComponent &other) const {
            return zIndex < other.zIndex;
        }
    };

    // Represents a single draw command
    struct DrawCommand
    {
        std::string type;                  // Command type (e.g., "circle", "rectangle")
        std::vector<DrawCommandArgs> args; // Arguments for the command
        int z = 0;                         // Optional Z-ordering
    };

    

    // Represents a drawing layer
    struct Layer
    {
        std::unordered_map<std::string, RenderTexture2D> canvases; // Canvases keyed by name
        std::vector<DrawCommand> drawCommands;                     // Commands to execute on the canvas
        bool fixed = false;                                        // Whether the layer ignores camera transforms
        int zIndex = 0;                                            // Global Z-index for this layer
        Color backgroundColor = BLANK;                             // Background color (default: transparent)
        
        // Per-layer draw command buffer
        std::vector<std::byte> arena;
        std::vector<DrawCommandV2> commands;
        std::vector<layer::DrawCommandV2>* commands_ptr = &commands; // testing.
        std::vector<std::function<void()>> destructors;
        bool isSorted = true;

        // New:
        std::array<std::unique_ptr<IDynamicPool>, static_cast<size_t>(DrawCommandType::Count)> commandPoolsArray = {};

        // NEW: the list of full-screen shaders to run after drawing
        std::vector<std::string> postProcessShaders;
        
        // helper to add one
        void addPostProcessShader(std::string_view name) {
            postProcessShaders.emplace_back(name);
        }
        // helper to clear them
        void clearPostProcessShaders() {
            postProcessShaders.clear();
        }

        void removePostProcessShader(std::string_view name) {
            auto it = std::remove(postProcessShaders.begin(), postProcessShaders.end(), name);
            if (it != postProcessShaders.end()) {
                postProcessShaders.erase(it, postProcessShaders.end());
            } else {
                throw std::runtime_error("Shader not found in post-process shaders");
            }
        }
    };

    extern std::vector<std::shared_ptr<Layer>> layers;

    

    inline void ClearPools(Layer& layer) {
        for (auto& pool : layer.commandPoolsArray)
            pool->delete_all();
    }

    //------------------------------------------------------------------------------------
    // Functions Declaration
    //------------------------------------------------------------------------------------

    // Layer management
    void SortLayers();
    void UpdateLayerZIndex(std::shared_ptr<Layer> layer, int newZIndex);
    std::shared_ptr<Layer> CreateLayer();
    std::shared_ptr<Layer> CreateLayerWithSize(int width, int height);
    void RemoveLayerFromCanvas(std::shared_ptr<Layer> layer);
    void ResizeCanvasInLayer(std::shared_ptr<Layer> layer, const std::string &canvasName, int width, int height);
    void AddCanvasToLayer(std::shared_ptr<Layer> layer, const std::string &name, int width, int height);
    void AddCanvasToLayer(std::shared_ptr<Layer> layer, const std::string &name);
    void RemoveCanvas(std::shared_ptr<Layer> layer, const std::string &canvasName);
    void UnloadAllLayers();
    void ClearDrawCommands(std::shared_ptr<Layer> layer);
    void ClearAllDrawCommands();
    void Begin();
    void End();

    // Drawing utilities
    void RenderAllLayersToCurrentRenderTarget(Camera2D *camera = nullptr);
    void DrawLayerCommandsToSpecificCanvas(std::shared_ptr<Layer> layer, const std::string &canvasName, Camera2D *camera = nullptr); // render commands in a layer to a specific "canvas" within the layer object, which can then be drawn to another layer, the screen, etc.
    void DrawLayerCommandsToSpecificCanvasOptimizedVersion(std::shared_ptr<Layer> layer, const std::string &canvasName, Camera2D *camera);
    void DrawLayerCommandsToSpecificCanvasApplyAllShaders(std::shared_ptr<Layer> layerPtr, const std::string &canvasName, Camera2D *camera);
    void DrawCanvasToCurrentRenderTargetWithTransform(const std::shared_ptr<Layer> layer, const std::string &canvasName,
                                                      float x = 0, float y = 0,
                                                      float rotation = 0,
                                                      float scaleX = 1, float scaleY = 1,
                                                      const Color &color = WHITE,
                                                      std::string shaderName = "ERROR-404",
                                                      bool flat = false); // render a layer's given canvas to the screen, or whatever target is in use.
    
    auto DrawTransformEntityWithAnimationWithPipeline(entt::registry& registry, entt::entity e) -> void;
    void DrawCanvasOntoOtherLayer(
        const std::shared_ptr<Layer> &srcLayer,
        const std::string &srcCanvasName,
        const std::shared_ptr<Layer> &dstLayer,
        const std::string &dstCanvasName,
        float x, float y,
        float rotation, float scaleX, float scaleY,
        const Color &tint);
    void DrawCanvasOntoOtherLayerWithShader(
        const std::shared_ptr<Layer> &srcLayer,
        const std::string &srcCanvasName,
        const std::shared_ptr<Layer> &dstLayer,
        const std::string &dstCanvasName,
        float x, float y,
        float rotation, float scaleX, float scaleY,
        const Color &tint,
        std::string shaderName = "ERROR-404");

    void DrawCanvasToCurrentRenderTargetWithDestRect(
        const std::shared_ptr<Layer> layer, const std::string &canvasName,
        const Rectangle &destRect, const Color &color, std::string shaderName = "ERROR-404");
    void DrawCustomLamdaToSpecificCanvas(const std::shared_ptr<Layer> layer, const std::string &canvasName = "main", std::function<void()> drawActions = []() {}); // render whatever is in the function lambda to a specific canvas within a layer object. Note that you should not call any of the AddXXX functions in the lambda, as they will not be rendered to the canvas. Instead, call the AddXXX functions outside of the lambda, then call things like DrawCanvasToCurrentRenderTargetWithTransform() in the actions lambda to render the commands to the canvas.
    auto DrawTransformEntityWithAnimation(entt::registry &registry, entt::entity e) -> void;
    auto DrawTransformEntityWithAnimationWithPipeline(entt::registry& registry, entt::entity e) -> void;
    void RenderNPatchRect(Texture2D sourceTexture, NPatchInfo info, Rectangle dest, Vector2 origin, float rotation, Color tint);
    
    auto pushEntityTransformsToMatrix(entt::registry &registry,
                                  entt::entity e,
                                  std::shared_ptr<layer::Layer> layer,
                                  int zOrder = 0) -> void;
    auto pushEntityTransformsToMatrixImmediate(entt::registry &registry,
                                  entt::entity e,
                                  std::shared_ptr<layer::Layer> layer,
                                  int zOrder = 0) -> void;

    // Command helpers - These functions add draw commands to the specified layer
    void AddBeginDrawing(std::shared_ptr<Layer> layer);
    void AddEndDrawing(std::shared_ptr<Layer> layer);
    void AddClearBackground(std::shared_ptr<Layer> layer, Color color);
    void AddDrawEntityWithAnimation(std::shared_ptr<Layer> layer, entt::registry *registry, entt::entity e, int x, int y, int z = 0);
    auto AddDrawTransformEntityWithAnimation(std::shared_ptr<Layer> layer, entt::registry* registry, entt::entity e, int z) -> void;
    void AddRectangle(std::shared_ptr<Layer> layer, float x, float y, float width, float height, const Color &color, float lineWidth = 0.0f, int z = 0);
    void AddCircle(std::shared_ptr<Layer> layer, float x, float y, float radius, Color color, int z = 0);
    void AddRectangleLinesPro(std::shared_ptr<Layer> layer, float offsetX, float offsetY, const Vector2 &size, float lineThickness, const Color &color, int z = 0);
    void AddRectanglePro(std::shared_ptr<Layer> layer, float offsetX, float offsetY, const Vector2 &size, const Color &color, const Vector2 &rotationCenter = {}, float rotation = 0.f, int z = 0);
    void AddDashedLine(std::shared_ptr<Layer> layer, float x1, float y1, float x2, float y2, float dashSize, float gapSize, const Color &color, float lineWidth, int z = 0);
    void AddLine(std::shared_ptr<Layer> layer, float x1, float y1, float x2, float y2, const Color &color, float lineWidth = 1.0f, int z = 0);
    void AddPolygon(std::shared_ptr<Layer> layer, const std::vector<Vector2> &vertices, const Color &color, float lineWidth = 0.0f, int z = 0);
    void AddTriangle(std::shared_ptr<Layer> layer, Vector2 p1, Vector2 p2, Vector2 p3, const Color &color, int z = 0);
    void AddDrawImage(std::shared_ptr<Layer> layer, const Texture2D &image, float x, float y, float rotation = 0.0f, float scaleX = 1.0f, float scaleY = 1.0f, const Color &color = WHITE, int z = 0);
    void AddTextPro(std::shared_ptr<Layer> layer, const std::string &text, Font font, float x, float y, const Vector2 &origin, float rotation, float fontSize, float spacing, const Color &color, int z = 0);
    void AddTexturePro(std::shared_ptr<Layer> layer, Texture2D texture, const struct Rectangle &source, float offsetX, float offsetY, const Vector2 &size, const Vector2 &rotationCenter, float rotation, const Color &color, int z = 0);
    void AddDrawTextCentered(std::shared_ptr<Layer> layer, const std::string &text, const Font &font, float x, float y, const Color &color, float fontSize = 20.0f, int z = 0);
    void AddText(std::shared_ptr<Layer> layer, const std::string &text, Font font, float x, float y, const Color &color, float fontSize, int z = 0);
    void AddPop(std::shared_ptr<Layer> layer, int z = 0);
    void AddRotate(std::shared_ptr<Layer> layer, float angle, int z = 0);
    void AddScale(std::shared_ptr<Layer> layer, float scaleX, float scaleY, int z = 0);
    void AddSetShader(std::shared_ptr<Layer> layer, const Shader &shader, int z = 0);
    void AddResetShader(std::shared_ptr<Layer> layer, int z = 0);
    void AddPush(std::shared_ptr<Layer> layer, Camera2D *camera, int z = 0);
    void AddSetBlendMode(std::shared_ptr<Layer> layer, int blendMode, int z = 0);
    void AddUnsetBlendMode(std::shared_ptr<Layer> layer, int z = 0);
    void AddPushMatrix(std::shared_ptr<Layer> layer, int z = 0);
    void AddPopMatrix(std::shared_ptr<Layer> layer, int z = 0);
    void AddTranslate(std::shared_ptr<Layer> layer, float x, float y, int z = 0);
    void AddVertex(std::shared_ptr<Layer> layer, Vector2 v, Color color, int z = 0);
    void AddBeginRLMode(std::shared_ptr<Layer> layer, int mode, int z = 0);
    void AddEndRLMode(std::shared_ptr<Layer> layer, int z = 0);
    void AddCustomPolygonOrLineWithRLGL(std::shared_ptr<Layer> layer, const std::vector<Vector2> &vertices, const Color &color, bool filled, int z = 0);
    void AddSetColor(std::shared_ptr<Layer> layer, const Color &color, int z = 0);
    void AddSetLineWidth(std::shared_ptr<Layer> layer, float lineWidth, int z = 0);
    void AddSetRLTexture(std::shared_ptr<Layer> layer, Texture2D texture, int z);
    void AddRenderRectVerticesFilledLayer(std::shared_ptr<Layer> layerPtr, const Rectangle outerRec, bool progressOrFullBackground, entt::entity cacheEntity, const Color color, int z = 0);
    void AddRenderRectVerticlesOutlineLayer(std::shared_ptr<Layer> layer, entt::entity cacheEntity, const Color color, bool useFull, int z = 0);
    auto AddDrawTransformEntityWithAnimationWithPipeline(std::shared_ptr<Layer> layer, entt::registry* registry, entt::entity e, int z = 0) -> void;
    void AddRenderNPatchRect(std::shared_ptr<Layer> layer, Texture2D sourceTexture, const NPatchInfo &info, const Rectangle& dest, const Vector2& origin, float rotation, const Color& tint, int z = 0);
    

    // Command management - These functions add, remove, and sort draw commands, usually used internally
    void SortDrawCommands(std::shared_ptr<Layer> layer);
    void AddDrawCommand(std::shared_ptr<Layer> layer, const std::string &type, const std::vector<DrawCommandArgs> &args, int z = 0);

    // Basic drawing functions & transformation - These are used internally by the command helpers when doing the actual rendering
    void BeginDrawingAction();
    void EndDrawingAction();
    void ClearBackgroundAction(Color color);
    void DrawEntityWithAnimation(entt::registry &registry, entt::entity e, int x, int y);
    void Circle(float x, float y, float radius, const Color &color);
    void CircleLine(float x, float y, float innerRadius, float outerRadius, float startAngle, float endAngle, int segments, const Color &color);
    void Line(float x1, float y1, float x2, float y2, const Color &color, float lineWidth);
    void RectangleDraw(float x, float y, float width, float height, const Color &color, float lineWidth = 0.0f);
    void Triangle(Vector2 p1, Vector2 p2, Vector2 p3, const Color &color);
    void DashedLine(float x1, float y1, float x2, float y2, float dashSize, float gapSize, const Color &color, float lineWidth);
    void Polygon(const std::vector<Vector2> &vertices, const Color &color, float lineWidth = 0.0f);
    void Text(const std::string &text, Font font, float x, float y, const Color &color, float fontSize);
    void TextPro(const std::string &text, Font font, float x, float y, const Vector2 &origin, float rotation, float fontSize, float spacing, const Color &color);
    void RectanglePro(float offsetX, float offsetY, const Vector2 &size, const Vector2 &rotationCenter, float rotation, const Color &color);
    void TexturePro(Texture2D texture, const struct Rectangle &source, float offsetX, float offsetY, const Vector2 &size, const Vector2 &rotationCenter, float rotation, const Color &color);
    void RectangleLinesPro(float offsetX, float offsetY, const Vector2 &size, float lineThickness, const Color &color);
    void DrawImage(const Texture2D &image, float x, float y, float rotation, float scaleX, float scaleY, const Color &color);
    void DrawTextCentered(const std::string &text, const Font &font, float x, float y, const Color &color, float fontSize = 20.0f);
    void SetBlendMode(int blendMode);
    void UnsetBlendMode();
    void PushMatrix();
    void PopMatrix();
    void Push(Camera2D *camera);
    void Pop();
    void Translate(float x, float y);
    void Scale(float x, float y);
    void Rotate(float angle);
    void SetShader(const Shader &shader);
    void ResetShader();
    void Vertex(Vector2 v, Color color);
    void BeginRLMode(int mode);
    void EndRLMode();
    void SetLineWidth(float lineWidth);
    void SetColor(const Color &color);
    void SetRLTexture(Texture2D texture);
    void RenderRectVerticesFilledLayer(std::shared_ptr<layer::Layer> layerPtr, const Rectangle outerRec, bool progressOrFullBackground, entt::entity cacheEntity, const Color color);
    void RenderRectVerticlesOutlineLayer(std::shared_ptr<layer::Layer> layerPtr, entt::entity cacheEntity, const Color color, bool useFull);
    void renderSliceOffscreenFromDrawList(
        entt::registry& registry,
        const std::vector<ui::UIDrawListItem>& drawList,
        size_t startIndex,
        size_t endIndex,
        std::shared_ptr<layer::Layer> layerPtr,
        float pad = 0.0f);
        

    void DrawGradientRectCentered(
    float cx, float cy,
    float width, float height,
    Color topLeft, Color topRight,
    Color bottomRight, Color bottomLeft);


    void DrawGradientRectRoundedCentered(
        float cx, float cy,
        float width, float height,
        float roundness,
        int segments,
        Color topLeft, Color topRight,
        Color bottomRight, Color bottomLeft);
        
void DrawDashedLine(const Vector2 &start,
                    const Vector2 &end,
                    float dashLength,
                    float gapLength,
                    float phase,
                    float thickness,
                    Color color);
void DrawDashedRoundedRect(const Rectangle& rec,
                           float dashLen,
                           float gapLen,
                           float phase,
                           float radius,
                           int arcSteps,
                           float thickness,
                           Color color);
void DrawDashedCircle(const Vector2 &center,
                      float radius,
                      float dashLength,
                      float gapLength,
                      float phase,
                      int segments,
                      float thickness,
                      Color color);
ArcType ArcTypeFromString(const char* s);
void rectangle(float x, float y, float w, float h,
                      std::optional<float> rx = {},
                      std::optional<float> ry = {},
                      std::optional<Color> color = {},
                      std::optional<float> lineWidth = {});
void triangle_equilateral(float x, float y, float w,
                                 std::optional<Color> color = {},
                                 std::optional<float> lineWidth = {});
void circle(float x, float y, float r,
                   std::optional<Color> color = {},
                   std::optional<float> lineWidth = {});
void arc(const char* arctype, float x, float y, float r, float r1, float r2,
                std::optional<Color> color = {},
                std::optional<float> lineWidth = {},
                int segments = 0);
void polygon(const std::vector<Vector2>& vertices,
                    std::optional<Color> color = {},
                    std::optional<float> lineWidth = {});
void line(float x1, float y1, float x2, float y2,
                 std::optional<Color> color = {},
                 std::optional<float> lineWidth = {});
void polyline(const std::vector<Vector2>& points,
                     std::optional<Color> color = {},
                     std::optional<float> lineWidth = {});
void rounded_line(float x1, float y1, float x2, float y2,
                         std::optional<Color> color = {},
                         std::optional<float> lineWidth = {});
void ellipse(float x, float y, float rx, float ry,
                    std::optional<Color> color = {},
                    std::optional<float> lineWidth = {});
void DrawSpriteTopLeft(const std::string& spriteName,
                       float x, float y,
                       std::optional<float> dstW = std::nullopt,
                       std::optional<float> dstH = std::nullopt,
                       Color tint = WHITE);
void DrawSpriteCentered(const std::string& spriteName,
                        float x, float y,
                        std::optional<float> dstW = std::nullopt,
                        std::optional<float> dstH = std::nullopt,
                        Color tint = WHITE);
void clearStencilBuffer();
void beginStencil();
void beginStencilMask();
void endStencilMask();

void endStencil();
RenderTexture2D LoadRenderTextureStencilEnabled(int width, int height);

    // NOTE that you should set shader uniforms directly when rendering at the layer level-- that is, rendering entire layers.
    void AddUniformFloat(std::shared_ptr<Layer> layer, Shader shader, const std::string &uniform, float value);
    void SendUniformFloat(Shader &shader, const std::string &uniform, float value);

    void AddUniformInt(std::shared_ptr<Layer> layer, Shader shader, const std::string &uniform, int value);
    void SendUniformInt(Shader &shader, const std::string &uniform, int value);

    void AddUniformVector2(std::shared_ptr<Layer> layer, Shader shader, const std::string &uniform, const Vector2 &value);
    void SendUniformVector2(Shader &shader, const std::string &uniform, const Vector2 &value);

    void AddUniformVector3(std::shared_ptr<Layer> layer, Shader shader, const std::string &uniform, const Vector3 &value);
    void SendUniformVector3(Shader &shader, const std::string &uniform, const Vector3 &value);

    void AddUniformVector4(std::shared_ptr<Layer> layer, Shader shader, const std::string &uniform, const Vector4 &value);
    void SendUniformVector4(Shader &shader, const std::string &uniform, const Vector4 &value);

    void AddUniformFloatArray(std::shared_ptr<Layer> layer, Shader shader, const std::string &uniform, const float *values, int count);
    void SendUniformFloatArray(Shader &shader, const std::string &uniform, const float *values, int count);

    void AddUniformIntArray(std::shared_ptr<Layer> layer, Shader shader, const std::string &uniform, const int *values, int count);
    void SendUniformIntArray(Shader &shader, const std::string &uniform, const int *values, int count);

} // namespace layer
