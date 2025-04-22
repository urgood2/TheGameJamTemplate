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

#include "entt/fwd.hpp"

// TODO: make internal functions not accessible?

namespace layer
{

    //------------------------------------------------------------------------------------
    // Data Structures Definition
    //------------------------------------------------------------------------------------
    using DrawCommandArgs = std::variant<bool, int, int *, float *, float, Color, Camera2D *, Texture2D, struct Rectangle, std::string, Font, Vector2, Vector3, Vector4, std::vector<Vector2>, std::vector<int>, std::vector<float>, Shader, entt::entity, entt::registry *>;

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
    };

    extern std::vector<std::shared_ptr<Layer>> layers;

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
    void DrawCanvasToCurrentRenderTargetWithTransform(const std::shared_ptr<Layer> layer, const std::string &canvasName,
                                                      float x = 0, float y = 0,
                                                      float rotation = 0,
                                                      float scaleX = 1, float scaleY = 1,
                                                      const Color &color = WHITE,
                                                      Shader shader = {},
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
        Shader shader);

    void DrawCanvasToCurrentRenderTargetWithDestRect(
        const std::shared_ptr<Layer> layer, const std::string &canvasName,
        const Rectangle &destRect, const Color &color, Shader shader);
    void DrawCustomLamdaToSpecificCanvas(const std::shared_ptr<Layer> layer, const std::string &canvasName = "main", std::function<void()> drawActions = []() {}); // render whatever is in the function lambda to a specific canvas within a layer object. Note that you should not call any of the AddXXX functions in the lambda, as they will not be rendered to the canvas. Instead, call the AddXXX functions outside of the lambda, then call things like DrawCanvasToCurrentRenderTargetWithTransform() in the actions lambda to render the commands to the canvas.
    auto DrawTransformEntityWithAnimation(entt::registry &registry, entt::entity e) -> void;
    auto DrawTransformEntityWithAnimationWithPipeline(entt::registry& registry, entt::entity e) -> void;

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
    void AddTriangle(std::shared_ptr<Layer> layer, float x, float y, float size, const Color &color, int z = 0);
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
    void AddRenderRectVerticesFilledLayer(std::shared_ptr<Layer> layerPtr, const Rectangle outerRec, entt::entity cacheEntity, const Color color, int z = 0);
    void AddRenderRectVerticlesOutlineLayer(std::shared_ptr<Layer> layer, entt::entity cacheEntity, const Color color, bool useFull, int z = 0);
    auto AddDrawTransformEntityWithAnimationWithPipeline(std::shared_ptr<Layer> layer, entt::registry* registry, entt::entity e, int z = 0) -> void;

    // Command management - These functions add, remove, and sort draw commands, usually used internally
    void SortDrawCommands(std::shared_ptr<Layer> layer);
    void AddDrawCommand(std::shared_ptr<Layer> layer, const std::string &type, const std::vector<DrawCommandArgs> &args, int z = 0);

    // Basic drawing functions & transformation - These are used internally by the command helpers when doing the actual rendering
    void BeginDrawingAction();
    void EndDrawingAction();
    void ClearBackgroundAction(Color color);
    void DrawEntityWithAnimation(entt::registry &registry, entt::entity e, int x, int y);
    void Circle(float x, float y, float radius, const Color &color);
    void Line(float x1, float y1, float x2, float y2, const Color &color, float lineWidth);
    void RectangleDraw(float x, float y, float width, float height, const Color &color, float lineWidth = 0.0f);
    void Triangle(float x, float y, float size, const Color &color);
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
    void RenderRectVerticesFilledLayer(std::shared_ptr<layer::Layer> layerPtr, const Rectangle outerRec, entt::entity cacheEntity, const Color color);
    void RenderRectVerticlesOutlineLayer(std::shared_ptr<layer::Layer> layerPtr, entt::entity cacheEntity, const Color color, bool useFull);

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
