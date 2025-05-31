#include "layer.hpp"

#include "raylib.h"
#include <vector>
#include <unordered_map>
#include <string>
#include <functional>
#include <variant>
#include <stdexcept>
#include <cmath>
#include <algorithm>

#include "core/globals.hpp"

#include "systems/ui/ui_data.hpp"
#include "systems/shaders/shader_pipeline.hpp"

#include "systems/transform/transform_functions.hpp"

#include "entt/entt.hpp"

#include "rlgl.h"

#include "snowhouse/snowhouse.h"

#include "util/common_headers.hpp"

#include "layer_command_buffer.hpp"

// Graphics namespace for rendering functions
namespace layer
{

    std::vector<std::shared_ptr<Layer>> layers;

    void SortLayers()
    {
        std::sort(layers.begin(), layers.end(), [](std::shared_ptr<Layer> a, std::shared_ptr<Layer> b)
                  { return a->zIndex < b->zIndex; });
    }

    void UpdateLayerZIndex(std::shared_ptr<Layer> layer, int newZIndex)
    {
        layer->zIndex = newZIndex;
        SortLayers();
    }

    void RemoveLayerFromCanvas(std::shared_ptr<Layer> layer) {
        // Unload all canvases in the layer
        for (const auto &[canvasName, canvas] : layer->canvases) {
            UnloadRenderTexture(canvas);
        }
        // Remove the layer from the list
        layers.erase(std::remove(layers.begin(), layers.end(), layer), layers.end());
    }

    void RenderAllLayersToCurrentRenderTarget(Camera2D *camera)
    {
        SortLayers(); //FIXME: not sorting, feature relaly isn't used

        using namespace snowhouse;
        AssertThat(layers.size(), IsGreaterThan(0));

        if (!camera) {
            // SPDLOG_WARN("Camera is null, rendering without camera transformations.");
        }

        // display layer count
        // SPDLOG_DEBUG("Rendering {} layers.", layers.size());

        int i = 0;
        for (std::shared_ptr<Layer> layer : layers)
        {
            // SPDLOG_DEBUG("Rendering layer #{} with {} canvases.", i++, layer->canvases.size());
            AssertThat(layer->canvases.size(), IsGreaterThan(0));
            for (const auto &[canvasName, canvas] : layer->canvases)
            {
                DrawLayerCommandsToSpecificCanvas(layer, canvasName, camera);
                DrawCanvasToCurrentRenderTargetWithTransform(layer, canvasName, 0, 0, 0, 1, 1, WHITE);

            }
        }
    }

    void DrawCustomLamdaToSpecificCanvas(const std::shared_ptr<Layer> layer, const std::string &canvasName, std::function<void()> drawActions) {
        if (layer->canvases.find(canvasName) == layer->canvases.end())
            return; // no canvas to draw to

        BeginTextureMode(layer->canvases.at(canvasName));

        // clear screen
        ClearBackground(layer->backgroundColor);

        drawActions();

        EndTextureMode();
    }

    void SortDrawCommands(std::shared_ptr<Layer> layer)
    {
        std::sort(layer->drawCommands.begin(), layer->drawCommands.end(), [](const DrawCommand &a, const DrawCommand &b)
                  { return a.z < b.z; });
    }

    void AddDrawCommand(std::shared_ptr<Layer> layer, const std::string &type, const std::vector<DrawCommandArgs> &args, int z)
    {
        DrawCommand command{type, args, z};
        layer->drawCommands.push_back(command);
    }

    std::shared_ptr<Layer> CreateLayer() {
        return CreateLayerWithSize(GetScreenWidth(), GetScreenHeight());
    }

    void ResizeCanvasInLayer(std::shared_ptr<Layer> layer, const std::string &canvasName, int width, int height) {
        auto it = layer->canvases.find(canvasName);
        if (it != layer->canvases.end()) {
            UnloadRenderTexture(it->second); // Free the existing texture
            it->second = LoadRenderTexture(width, height); // Create a new one with the specified dimensions
        } else {
            // Handle error: Canvas does not exist
            SPDLOG_ERROR("Error: Canvas '{}' does not exist in the layer.", canvasName);
        }
    }

    std::shared_ptr<Layer> CreateLayerWithSize(int width, int height) {
        auto layer = std::make_shared<Layer>();
        // Create a default "main" canvas with the specified size
        RenderTexture2D mainCanvas = LoadRenderTexture(width, height);
        layer->canvases["main"] = mainCanvas;
        layers.push_back(layer);
        return layer;
    }

    void RemoveCanvas(std::shared_ptr<Layer> layer, const std::string &canvasName) {
        auto it = layer->canvases.find(canvasName);
        if (it != layer->canvases.end()) {
            UnloadRenderTexture(it->second); // Free the render texture
            layer->canvases.erase(it);       // Remove the canvas from the map
        } else {
            // Handle error: Canvas does not exist
            SPDLOG_ERROR("Error: Canvas '{}' does not exist in the layer.", canvasName);
        }
    }
    

    void ClearDrawCommands(std::shared_ptr<Layer> layer) {
        layer->drawCommands.clear();
        
        layer_command_buffer::Clear(layer);
    }

    void Begin() {
        ClearAllDrawCommands();
    }

    void End() {
        // FIXME: does nothing for now
    }


    void ClearAllDrawCommands() {
        for (std::shared_ptr<Layer> layer : layers) {
            ClearDrawCommands(layer);
        }
    }
    
    void UnloadAllLayers()
    {
        for (std::shared_ptr<Layer> layer : layers)
        {
            for (const auto &[canvasName, canvas] : layer->canvases)
            {
                UnloadRenderTexture(canvas);
            }
        }
    }

    void AddCanvasToLayer(std::shared_ptr<Layer> layer, const std::string &name, int width, int height)
    {
        RenderTexture2D canvas = LoadRenderTexture(width, height);
        layer->canvases[name] = canvas;
    }

    void AddCanvasToLayer(std::shared_ptr<Layer> layer, const std::string &name)
    {
        RenderTexture2D canvas = LoadRenderTexture(GetScreenWidth(), GetScreenHeight());
        layer->canvases[name] = canvas;
    }

    void DrawCanvasOntoOtherLayerWithShader(
        const std::shared_ptr<Layer>& srcLayer,
        const std::string& srcCanvasName,
        const std::shared_ptr<Layer>& dstLayer,
        const std::string& dstCanvasName,
        float x, float y,
        float rotation, float scaleX, float scaleY,
        const Color& tint,
        Shader shader)
    {
        // Check canvas validity
        if (srcLayer->canvases.find(srcCanvasName) == srcLayer->canvases.end()) return;
        if (dstLayer->canvases.find(dstCanvasName) == dstLayer->canvases.end()) return;
    
        const RenderTexture2D& srcCanvas = srcLayer->canvases.at(srcCanvasName);
        RenderTexture2D& dstCanvas = dstLayer->canvases.at(dstCanvasName);
    
        
    
        BeginTextureMode(dstCanvas);
        
        if (shader.id != 0)
            BeginShaderMode(shader);
    
        DrawTexturePro(
            srcCanvas.texture,
            { 0, 0, (float)srcCanvas.texture.width, (float)-srcCanvas.texture.height },
            { x, y, srcCanvas.texture.width * scaleX, srcCanvas.texture.height * scaleY },
            { 0, 0 },
            rotation,
            tint
        );

    
        if (shader.id != 0)
            EndShaderMode();
    
        
        EndTextureMode();
    }

    void DrawCanvasOntoOtherLayer(
        const std::shared_ptr<Layer>& srcLayer,
        const std::string& srcCanvasName,
        const std::shared_ptr<Layer>& dstLayer,
        const std::string& dstCanvasName,
        float x, float y,
        float rotation, float scaleX, float scaleY,
        const Color& tint)
    {
        // Check if both layers and canvases exist
        if (srcLayer->canvases.find(srcCanvasName) == srcLayer->canvases.end()) return;
        if (dstLayer->canvases.find(dstCanvasName) == dstLayer->canvases.end()) return;
    
        RenderTexture2D src = srcLayer->canvases.at(srcCanvasName);
        RenderTexture2D& dst = dstLayer->canvases.at(dstCanvasName);
    
        BeginTextureMode(dst);
    
        DrawTexturePro(
            src.texture,
            { 0, 0, (float)src.texture.width, (float)-src.texture.height },
            { x, y, src.texture.width * scaleX, src.texture.height * scaleY },
            { 0, 0 },
            rotation,
            tint
        );
    
        EndTextureMode();
    }
    
    // only use for (DrawLayerCommandsToSpecificCanvas)
    namespace render_stack_switch_internal
    {
        static std::stack<RenderTexture2D> renderStack{};

        // Push a new render target, auto-ending the previous one if needed
        inline void Push(RenderTexture2D target)
        {
            if (!renderStack.empty())
            {
                // End the currently active texture mode
                EndTextureMode();
            }

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
    
    void DrawLayerCommandsToSpecificCanvasOptimizedVersion(std::shared_ptr<Layer> layer, const std::string &canvasName, Camera2D *camera)
    {
        if (layer->canvases.find(canvasName) == layer->canvases.end())
            return;

        render_stack_switch_internal::Push(layer->canvases[canvasName]);

        ClearBackground(layer->backgroundColor);

        if (!layer->fixed && camera)
        {
            BeginMode2D(*camera);
        }

        // Dispatch all draw commands from the arena-based command buffer
        for (const auto& command : layer_command_buffer::GetCommandsSorted(layer))
        {
            auto it = dispatcher.find(command.type);
            if (it != dispatcher.end()) {
                it->second(layer, command.data);
            } else {
                SPDLOG_ERROR("Unhandled draw command type {}");
            }
        }

        if (!layer->fixed && camera)
        {
            EndMode2D();
        }

        render_stack_switch_internal::Pop();
    }


    void DrawLayerCommandsToSpecificCanvas(std::shared_ptr<Layer> layer, const std::string &canvasName, Camera2D *camera)
    {
        if (layer->canvases.find(canvasName) == layer->canvases.end())
            return;

        // SPDLOG_DEBUG("Drawing commands to canvas: {}", canvasName);

        // BeginTextureMode(layer->canvases[canvasName]);
        render_stack_switch_internal::Push(layer->canvases[canvasName]);
        
        // Clear the canvas with the background color
        ClearBackground(layer->backgroundColor);

        if (!layer->fixed && camera)
        {
            BeginMode2D(*camera);
        }

        // Sort draw commands by z before rendering
        // SortDrawCommands(layer); // FIXME: just render in order they were added

        using namespace snowhouse;

        for (const auto &command : layer->drawCommands)
        {
            // SPDLOG_DEBUG("Drawing command: {}", command.type);
            // basic
            if (command.type == "begin_drawing") {
                BeginDrawingAction();
            } else if (command.type == "end_drawing") {
                EndDrawingAction();
            } else if (command.type == "clear_background") {
                AssertThat(command.args.size(), Equals(1));
                Color color = std::get<Color>(command.args[0]);
                ClearBackgroundAction(color);
            } 

            // Transformations
            else if(command.type == "translate")
            {
                AssertThat(command.args.size(), Equals(2)); // Validate number of arguments
                float x = std::get<float>(command.args[0]);
                float y = std::get<float>(command.args[1]);
                layer::Translate(x, y);
            }
            else if (command.type == "scale")
            {
                AssertThat(command.args.size(), Equals(2)); // Validate number of arguments
                float scaleX = std::get<float>(command.args[0]);
                float scaleY = std::get<float>(command.args[1]);
                AssertThat(scaleX, IsGreaterThanOrEqualTo(0.0f)); // ScaleX must be positive
                AssertThat(scaleY, IsGreaterThanOrEqualTo(0.0f)); // ScaleY must be positive
                layer::Scale(scaleX, scaleY);
            }
            else if (command.type == "rotate")
            {
                AssertThat(command.args.size(), Equals(1)); // Validate number of arguments
                float angle = std::get<float>(command.args[0]);
                layer::Rotate(angle);
            }
            else if (command.type == "add_push")
            {
                AssertThat(command.args.size(), Equals(1)); // Validate number of arguments
                Camera2D *camera = std::get<Camera2D *>(command.args[0]);
                
                
                layer::QueueCommand<layer::CmdAddPush>(layer, [camera](layer::CmdAddPush *cmd) {
                    cmd->camera = camera;
                });
            }
            else if (command.type == "add_pop")
            {
                AssertThat(command.args.size(), Equals(0)); // Validate no arguments
                layer::Pop();
            }
            else if (command.type == "push_matrix")
            {
                AssertThat(command.args.size(), Equals(0)); // Validate no arguments
                layer::PushMatrix();
            }
            else if (command.type == "pop_matrix")
            {
                AssertThat(command.args.size(), Equals(0)); // Validate no arguments
                layer::PopMatrix();
            }

            // Shape Drawing
            else if (command.type == "circle")
            {
                AssertThat(command.args.size(), Equals(4)); // Validate number of arguments
                float x = std::get<float>(command.args[0]);
                float y = std::get<float>(command.args[1]);
                float radius = std::get<float>(command.args[2]);
                Color color = std::get<Color>(command.args[3]);
                AssertThat(radius, IsGreaterThan(0.0f)); // Radius must be positive
                layer::Circle(x, y, radius, color);
            }
            else if (command.type == "rectangle")
            {
                AssertThat(command.args.size(), Equals(6)); // Validate number of arguments
                float x = std::get<float>(command.args[0]);
                float y = std::get<float>(command.args[1]);
                float width = std::get<float>(command.args[2]);
                float height = std::get<float>(command.args[3]);
                Color color = std::get<Color>(command.args[4]);
                float lineWidth = std::get<float>(command.args[5]);
                AssertThat(width, IsGreaterThan(0.0f)); // Width must be positive
                AssertThat(height, IsGreaterThan(0.0f)); // Height must be positive
                layer::RectangleDraw(x, y, width, height, color, lineWidth);
            }
            else if (command.type == "rectanglePro")
            {
                AssertThat(command.args.size(), Equals(6)); // Validate number of arguments
                float offsetX = std::get<float>(command.args[0]);
                float offsetY = std::get<float>(command.args[1]);
                Vector2 size = std::get<Vector2>(command.args[2]);
                Vector2 rotationCenter = std::get<Vector2>(command.args[3]);
                float rotation = std::get<float>(command.args[4]);
                Color color = std::get<Color>(command.args[5]);
                layer::RectanglePro(offsetX, offsetY, size, rotationCenter, rotation, color);
            }
            else if (command.type == "rectangleLinesPro")
            {
                AssertThat(command.args.size(), Equals(5)); // Validate number of arguments
                float offsetX = std::get<float>(command.args[0]);
                float offsetY = std::get<float>(command.args[1]);
                Vector2 size = std::get<Vector2>(command.args[2]);
                float lineThickness = std::get<float>(command.args[3]);
                Color color = std::get<Color>(command.args[4]);
                layer::RectangleLinesPro(offsetX, offsetY, size, lineThickness, color);
            }
            else if (command.type == "line")
            {
                AssertThat(command.args.size(), Equals(6)); // Validate number of arguments
                float x1 = std::get<float>(command.args[0]);
                float y1 = std::get<float>(command.args[1]);
                float x2 = std::get<float>(command.args[2]);
                float y2 = std::get<float>(command.args[3]);
                Color color = std::get<Color>(command.args[4]);
                float lineWidth = std::get<float>(command.args[5]);
                AssertThat(lineWidth, IsGreaterThan(0.0f)); // Line width must be positive
                layer::Line(x1, y1, x2, y2, color, lineWidth);
            }
            else if (command.type == "dashed_line")
            {
                AssertThat(command.args.size(), Equals(8)); // Validate number of arguments
                float x1 = std::get<float>(command.args[0]);
                float y1 = std::get<float>(command.args[1]);
                float x2 = std::get<float>(command.args[2]);
                float y2 = std::get<float>(command.args[3]);
                float dashSize = std::get<float>(command.args[4]);
                float gapSize = std::get<float>(command.args[5]);
                Color color = std::get<Color>(command.args[6]);
                float lineWidth = std::get<float>(command.args[7]);
                AssertThat(dashSize, IsGreaterThan(0.0f)); // Dash size must be positive
                AssertThat(gapSize, IsGreaterThan(0.0f));  // Gap size must be positive
                AssertThat(lineWidth, IsGreaterThan(0.0f)); // Line width must be positive
                layer::DashedLine(x1, y1, x2, y2, dashSize, gapSize, color, lineWidth);
            }

            // Text Rendering
            else if (command.type == "text")
            {
                AssertThat(command.args.size(), Equals(6)); // Validate number of arguments
                std::string text = std::get<std::string>(command.args[0]);
                Font font = std::get<Font>(command.args[1]);
                float x = std::get<float>(command.args[2]);
                float y = std::get<float>(command.args[3]);
                Color color = std::get<Color>(command.args[4]);
                float fontSize = std::get<float>(command.args[5]);
                // AssertThat(fontSize, IsGreaterThan(0.0f)); // Font size must be positive
                layer::Text(text, font, x, y, color, fontSize);
            }
            else if (command.type == "draw_text_centered")
            {
                AssertThat(command.args.size(), Equals(6)); // Validate number of arguments
                std::string text = std::get<std::string>(command.args[0]);
                Font font = std::get<Font>(command.args[1]);
                float x = std::get<float>(command.args[2]);
                float y = std::get<float>(command.args[3]);
                Color color = std::get<Color>(command.args[4]);
                float fontSize = std::get<float>(command.args[5]);
                AssertThat(fontSize, IsGreaterThan(0.0f)); // Font size must be positive
                layer::DrawTextCentered(text, font, x, y, color, fontSize);
            }
            else if (command.type == "textPro")
            {
                AssertThat(command.args.size(), Equals(9)); // Validate number of arguments
                std::string text = std::get<std::string>(command.args[0]);
                Font font = std::get<Font>(command.args[1]);
                float x = std::get<float>(command.args[2]);
                float y = std::get<float>(command.args[3]);
                Vector2 origin = std::get<Vector2>(command.args[4]);
                float rotation = std::get<float>(command.args[5]);
                float fontSize = std::get<float>(command.args[6]);
                float spacing = std::get<float>(command.args[7]);
                Color color = std::get<Color>(command.args[8]);
                // AssertThat(fontSize, IsGreaterThan(0.0f)); // Font size must be positive
                AssertThat(spacing, IsGreaterThan(0.0f));  // Spacing must be positive
                layer::TextPro(text, font, x, y, origin, rotation, fontSize, spacing, color);
            }

            // Drawing Commands
            else if (command.type == "draw_image")
            {
                AssertThat(command.args.size(), Equals(7)); // Validate number of arguments
                Texture2D image = std::get<Texture2D>(command.args[0]);
                float x = std::get<float>(command.args[1]);
                float y = std::get<float>(command.args[2]);
                float rotation = std::get<float>(command.args[3]);
                float scaleX = std::get<float>(command.args[4]);
                float scaleY = std::get<float>(command.args[5]);
                Color color = std::get<Color>(command.args[6]);
                AssertThat(scaleX, IsGreaterThan(0.0f)); // ScaleX must be positive
                AssertThat(scaleY, IsGreaterThan(0.0f)); // ScaleY must be positive
                layer::DrawImage(image, x, y, rotation, scaleX, scaleY, color);
            }
            else if (command.type == "texturePro")
            {
                AssertThat(command.args.size(), Equals(8)); // Validate number of arguments
                Texture2D texture = std::get<Texture2D>(command.args[0]);
                struct Rectangle source = std::get<struct Rectangle>(command.args[1]);
                float offsetX = std::get<float>(command.args[2]);
                float offsetY = std::get<float>(command.args[3]);
                Vector2 size = std::get<Vector2>(command.args[4]);
                Vector2 rotationCenter = std::get<Vector2>(command.args[5]);
                float rotation = std::get<float>(command.args[6]);
                Color color = std::get<Color>(command.args[7]);
                layer::TexturePro(texture, source, offsetX, offsetY, size, rotationCenter, rotation, color);
            }
            else if (command.type == "draw_entity_animation")
            {
                AssertThat(command.args.size(), Equals(4)); // Validate number of arguments
                entt::entity e = std::get<entt::entity>(command.args[0]);
                entt::registry *registry = std::get<entt::registry *>(command.args[1]);
                int x = std::get<int>(command.args[2]);
                int y = std::get<int>(command.args[3]);
                layer::DrawEntityWithAnimation(*registry, e, x, y);
            }
            else if (command.type == "draw_transform_entity_animation") {
                AssertThat(command.args.size(), Equals(2)); // Validate number of arguments
                entt::entity e = std::get<entt::entity>(command.args[0]);
                entt::registry *registry = std::get<entt::registry *>(command.args[1]);
                layer::DrawTransformEntityWithAnimation(*registry, e);
            }
            else if (command.type == "draw_transform_entity_animation_pipeline") {
                AssertThat(command.args.size(), Equals(2)); // Validate number of arguments
                entt::entity e = std::get<entt::entity>(command.args[0]);
                entt::registry *registry = std::get<entt::registry *>(command.args[1]);
                layer::DrawTransformEntityWithAnimationWithPipeline(*registry, e);
            }
            // Shader Commands
            else if (command.type == "set_shader")
            {
                AssertThat(command.args.size(), Equals(1)); // Validate number of arguments
                Shader shader = std::get<Shader>(command.args[0]);
                layer::SetShader(shader);
            }
            else if (command.type == "reset_shader")
            {
                AssertThat(command.args.size(), Equals(0)); // Validate no arguments
                layer::ResetShader();
            }
            else if (command.type == "set_blend_mode")
            {
                AssertThat(command.args.size(), Equals(1)); // Validate number of arguments
                int blendMode = std::get<int>(command.args[0]);
                AssertThat(blendMode, IsGreaterThanOrEqualTo(0)); // BlendMode must be valid
                AssertThat(blendMode, IsLessThanOrEqualTo(4));    // Assuming 0-4 are valid blend modes
                layer::SetBlendMode(blendMode);
            }
            else if (command.type == "unset_blend_mode")
            {
                
                layer::UnsetBlendMode();
            }
            else if (command.type == "send_uniform_float")
            {
                AssertThat(command.args.size(), Equals(3)); // Validate arguments
                Shader shader = std::get<Shader>(command.args[0]);
                std::string uniform = std::get<std::string>(command.args[1]);
                float value = std::get<float>(command.args[2]);
                AssertThat(uniform.empty(), IsFalse()); // Uniform name must not be empty
                SendUniformFloat(shader, uniform, value);
            }
            else if (command.type == "send_uniform_int")
            {
                AssertThat(command.args.size(), Equals(3));
                Shader shader = std::get<Shader>(command.args[0]);
                std::string uniform = std::get<std::string>(command.args[1]);
                int value = std::get<int>(command.args[2]);
                AssertThat(uniform.empty(), IsFalse());
                SendUniformInt(shader, uniform, value);
            }
            else if (command.type == "send_uniform_vec2")
            {
                AssertThat(command.args.size(), Equals(3));
                Shader shader = std::get<Shader>(command.args[0]);
                std::string uniform = std::get<std::string>(command.args[1]);
                Vector2 value = std::get<Vector2>(command.args[2]);
                AssertThat(uniform.empty(), IsFalse());
                SendUniformVector2(shader, uniform, value);
            }
            else if (command.type == "send_uniform_vec3")
            {
                AssertThat(command.args.size(), Equals(3));
                Shader shader = std::get<Shader>(command.args[0]);
                std::string uniform = std::get<std::string>(command.args[1]);
                Vector3 value = std::get<Vector3>(command.args[2]);
                AssertThat(uniform.empty(), IsFalse());
                SendUniformVector3(shader, uniform, value);
            }
            else if (command.type == "send_uniform_vec4")
            {
                AssertThat(command.args.size(), Equals(3));
                Shader shader = std::get<Shader>(command.args[0]);
                std::string uniform = std::get<std::string>(command.args[1]);
                Vector4 value = std::get<Vector4>(command.args[2]);
                AssertThat(uniform.empty(), IsFalse());
                SendUniformVector4(shader, uniform, value);
            }
            else if (command.type == "send_uniform_float_array")
            {
                AssertThat(command.args.size(), Equals(3));
                Shader shader = std::get<Shader>(command.args[0]);
                std::string uniform = std::get<std::string>(command.args[1]);
                std::vector<float> values = std::get<std::vector<float>>(command.args[2]);
                AssertThat(uniform.empty(), IsFalse());
                SendUniformFloatArray(shader, uniform, values.data(), values.size());
            }
            else if (command.type == "send_uniform_int_array")
            {
                AssertThat(command.args.size(), Equals(3));
                Shader shader = std::get<Shader>(command.args[0]);
                std::string uniform = std::get<std::string>(command.args[1]);
                std::vector<int> values = std::get<std::vector<int>>(command.args[2]);
                AssertThat(uniform.empty(), IsFalse());
                SendUniformIntArray(shader, uniform, values.data(), values.size());
            }
            else if (command.type == "vertex") 
            {
                AssertThat(command.args.size(), Equals(2));
                Vector2 v = std::get<Vector2>(command.args[0]);
                Color color = std::get<Color>(command.args[1]);
                Vertex(v, color);
            }
            else if (command.type == "begin_mode") 
            {
                AssertThat(command.args.size(), Equals(1));
                int mode = std::get<int>(command.args[0]);
                BeginRLMode(mode);
            }
            else if (command.type == "end_mode") 
            {
                EndRLMode();
            }
            else if (command.type == "set_color") {
                AssertThat(command.args.size(), Equals(1));
                Color color = std::get<Color>(command.args[0]);
                SetColor(color);
            }
            else if (command.type == "set_line_width") {
                AssertThat(command.args.size(), Equals(1));
                float lineWidth = std::get<float>(command.args[0]);
                SetLineWidth(lineWidth);
            }
            else if (command.type == "set_texture") {
                AssertThat(command.args.size(), Equals(1));
                Texture2D texture = std::get<Texture2D>(command.args[0]);
                SetRLTexture(texture);
            }
            else if (command.type == "render_rect_vertices_filled_layer") {
                AssertThat(command.args.size(), Equals(4));
                Rectangle outerRec = std::get<Rectangle>(command.args[0]);
                bool progressOrFullBackground = std::get<bool>(command.args[1]);
                entt::entity cache = std::get<entt::entity>(command.args[2]);
                Color color = std::get<Color>(command.args[3]);
                RenderRectVerticesFilledLayer(layer, outerRec, progressOrFullBackground, cache, color);
            }
            else if (command.type == "render_rect_verticles_outline_layer") {
                AssertThat(command.args.size(), Equals(3));
                entt::entity cache = std::get<entt::entity>(command.args[0]);
                Color color = std::get<Color>(command.args[1]);
                bool useFullVertices = std::get<bool>(command.args[2]);
                RenderRectVerticlesOutlineLayer(layer, cache, color, useFullVertices);
            }
            else if (command.type == "polygon") {
                AssertThat(command.args.size(), Equals(3));
                std::vector<Vector2> vertices = std::get<std::vector<Vector2>>(command.args[0]);
                Color color = std::get<Color>(command.args[1]);
                float lineWidth = std::get<float>(command.args[2]);
                layer::Polygon(vertices, color, lineWidth);
            }
            else if (command.type == "circle") {
                AssertThat(command.args.size(), Equals(4));
                float x = std::get<float>(command.args[0]);
                float y = std::get<float>(command.args[1]);
                float radius = std::get<float>(command.args[2]);
                Color color = std::get<Color>(command.args[3]);
                layer::Circle(x, y, radius, color);
            }
            else if (command.type == "render_npatch") {
                AssertThat(command.args.size(), Equals(6));
                Texture2D sourceTexture = std::get<Texture2D>(command.args[0]);
                NPatchInfo info = std::get<NPatchInfo>(command.args[1]);
                Rectangle dest = std::get<Rectangle>(command.args[2]);
                Vector2 origin = std::get<Vector2>(command.args[3]);
                float rotation = std::get<float>(command.args[4]);
                Color tint = std::get<Color>(command.args[5]);
                layer::RenderNPatchRect(sourceTexture, info, dest, origin, rotation, tint);
            }
            else if (command.type == "triangle") {
                AssertThat(command.args.size(), Equals(4));
                Vector2 p1 = std::get<Vector2>(command.args[0]);
                Vector2 p2 = std::get<Vector2>(command.args[1]);
                Vector2 p3 = std::get<Vector2>(command.args[2]);
                Color color = std::get<Color>(command.args[3]);
                layer::Triangle(p1, p2, p3, color);
            }
            // Fallback for undefined commands
            else
            {
                throw std::runtime_error("Undefined draw command: " + command.type);
            }
        }

        if (!layer->fixed && camera)
        {
            EndMode2D();
        }

        // EndTextureMode();
        render_stack_switch_internal::Pop();
    }

    void AddSetColor(std::shared_ptr<Layer> layer, const Color& color, int z)
    {
        AddDrawCommand(layer, "set_color", {color}, z);
    }

    void SetColor(const Color& color)
    {
        rlColor4ub(color.r, color.g, color.b, color.a);
    }

    void AddSetLineWidth(std::shared_ptr<Layer> layer, float lineWidth, int z)
    {
        AddDrawCommand(layer, "set_line_width", {lineWidth}, z);
    }

    void SetLineWidth(float lineWidth)
    {
        rlSetLineWidth(lineWidth);
    }
    
    void Vertex(Vector2 v, Color color)
    {
        rlColor4ub(color.r, color.g, color.b, color.a);
        rlVertex2f(v.x, v.y);
    }

    void AddVertex(std::shared_ptr<Layer> layer, Vector2 v, Color color, int z)
    {
        AddDrawCommand(layer, "vertex", {v, color}, z);
    }

    void AddCircle(std::shared_ptr<Layer> layer, float x, float y, float radius, Color color, int z)
    {
        AddDrawCommand(layer, "circle", {x, y, radius, color}, z);
    }

    void SetRLTexture(Texture2D texture)
    {
        rlSetTexture(texture.id);
    }

    void AddSetRLTexture(std::shared_ptr<Layer> layer, Texture2D texture, int z)
    {
        AddDrawCommand(layer, "set_texture", {texture}, z);
    }

    void BeginRLMode(int mode)
    {
        rlBegin(mode);
    }

    void AddBeginRLMode(std::shared_ptr<Layer> layer, int mode, int z)
    {
        AddDrawCommand(layer, "begin_mode", {mode}, z);
    }

    void EndRLMode()
    {
        rlEnd();
    }

    void AddEndRLMode(std::shared_ptr<Layer> layer, int z)
    {
        AddDrawCommand(layer, "end_mode", {}, z);
    }
    
    void AddRenderNPatchRect(std::shared_ptr<Layer> layer, Texture2D sourceTexture, const NPatchInfo &info, const Rectangle& dest, const Vector2& origin, float rotation, const Color& tint, int z)
    {
        AddDrawCommand(layer, "render_npatch", {sourceTexture, info, dest, origin, rotation, tint}, z);
    }
    
    void RenderNPatchRect(Texture2D sourceTexture, NPatchInfo info, Rectangle dest, Vector2 origin, float rotation, Color tint) {
        DrawTextureNPatch(sourceTexture, info, dest, origin, rotation, tint);
    }

    void AddRenderRectVerticesFilledLayer(std::shared_ptr<Layer> layerPtr, const Rectangle outerRec, bool progressOrFullBackground, entt::entity cacheEntity, const Color color, int z) {
        AddDrawCommand(layerPtr, "render_rect_vertices_filled_layer", {outerRec, progressOrFullBackground, cacheEntity, color}, z);
    }

    void RenderRectVerticesFilledLayer(std::shared_ptr<layer::Layer> layerPtr, const Rectangle outerRec, bool progressOrFullBackground, entt::entity cacheEntity, const Color color) {
        
        auto &cache  = globals::registry.get<ui::RoundedRectangleVerticesCache>(cacheEntity);
        
        auto &outerVertices = progressOrFullBackground ? cache.outerVerticesProgressReflected : cache.outerVerticesFullRect;


        rlColor4ub(255, 255, 255, 255); // Reset to white before each draw
        rlSetTexture(0);
        rlDisableDepthTest(); // Disable depth testing for 2D rendering
        rlEnableDepthTest();
        rlDisableColorBlend(); // Disable color blending for solid color
        rlEnableColorBlend(); // Enable color blending for textures
        rlBegin(RL_TRIANGLES);
        rlSetBlendMode(rlBlendMode::RL_BLEND_ALPHA);

        // Center of the entire rectangle (for filling)
        Vector2 center = {outerRec.x + outerRec.width / 2.0f, outerRec.y + outerRec.height / 2.0f};
        // SPDLOG_DEBUG("RenderRectVerticesFilledLayer > Center: x: {}, y: {}", center.x, center.y);

        // Fill using the **outer vertices** and the **center**
        for (size_t i = 0; i < outerVertices.size(); i += 2)
        {
            // Triangle: Center → Outer1 → Outer2
            rlColor4ub(color.r, color.g, color.b, color.a);
            rlVertex2f(center.x, center.y);
            rlColor4ub(color.r, color.g, color.b, color.a);
            rlVertex2f(outerVertices[i + 1].x, outerVertices[i + 1].y);
            rlColor4ub(color.r, color.g, color.b, color.a);
            rlVertex2f(outerVertices[i].x, outerVertices[i].y);
        }

        rlEnd();

    }
    
    void AddRenderRectVerticlesOutlineLayer(std::shared_ptr<Layer> layer, entt::entity cacheEntity, const Color color, bool useFullVertices, int z) {
        AddDrawCommand(layer, "render_rect_verticles_outline_layer", {cacheEntity, color, useFullVertices}, z);
    }
    
    void RenderRectVerticlesOutlineLayer(std::shared_ptr<layer::Layer> layerPtr, entt::entity cacheEntity, const Color color, bool useFullVertices) {
        
        auto &cache  = globals::registry.get<ui::RoundedRectangleVerticesCache>(cacheEntity);
        auto &innerVertices = (useFullVertices) ? cache.innerVerticesFullRect : cache.innerVerticesProgressReflected;
        auto &outerVertices = (useFullVertices) ? cache.outerVerticesFullRect : cache.outerVerticesProgressReflected;
        
        // Draw the outlines
        // Draw the filled outline
        rlDisableDepthTest(); // Disable depth testing for 2D rendering
        rlEnableDepthTest();
        rlColor4ub(255, 255, 255, 255); // Reset to white before each draw
        rlSetTexture(0);
        rlDisableColorBlend(); // Disable color blending for solid color
        rlEnableColorBlend(); // Enable color blending for textures
        rlBegin(RL_TRIANGLES);
        rlSetBlendMode(rlBlendMode::RL_BLEND_ALPHA);

        // Draw quads between outer and inner outlines using two triangles each
        for (size_t i = 0; i < outerVertices.size(); i += 2)
        {
            rlColor4ub(color.r, color.g, color.b, color.a);
            rlVertex2f(outerVertices[i].x, outerVertices[i].y);
            rlColor4ub(color.r, color.g, color.b, color.a);
            rlVertex2f(innerVertices[i].x, innerVertices[i].y);
            rlColor4ub(color.r, color.g, color.b, color.a);
            rlVertex2f(innerVertices[i + 1].x, innerVertices[i + 1].y);
            
            rlColor4ub(color.r, color.g, color.b, color.a);
            rlVertex2f(outerVertices[i].x, outerVertices[i].y);
            rlColor4ub(color.r, color.g, color.b, color.a);
            rlVertex2f(innerVertices[i + 1].x, innerVertices[i + 1].y);
            rlColor4ub(color.r, color.g, color.b, color.a);
            rlVertex2f(outerVertices[i + 1].x, outerVertices[i + 1].y);
        }

        rlEnd();
    }

    void AddCustomPolygonOrLineWithRLGL(std::shared_ptr<Layer> layer, const std::vector<Vector2>& vertices, const Color& color, bool filled, int z)
    {
        int mode = filled ? RL_TRIANGLES : RL_LINES;
        
        AddBeginRLMode(layer, mode, z);

        for (const auto& v : vertices)
        {
            AddVertex(layer, v, color, z);
        }

        AddEndRLMode(layer, z);
    }





    // in order to make this method stackable inside lamdas, we can't call begindrawing() in here.
    // that must be handled by the user.
    void DrawCanvasToCurrentRenderTargetWithTransform(const std::shared_ptr<Layer> layer, const std::string &canvasName, float x, float y, float rotation, float scaleX, float scaleY, const Color &color, Shader shader, bool flat)
    {
        if (layer->canvases.find(canvasName) == layer->canvases.end())
            return;

        // Optional shader
        if (shader.id != 0)
            BeginShaderMode(shader);

        // Set color
        DrawTexturePro(
            layer->canvases.at(canvasName).texture,
            {0, 0, (float)layer->canvases.at(canvasName).texture.width, (float)-layer->canvases.at(canvasName).texture.height},
            {x, y, (float)layer->canvases.at(canvasName).texture.width * scaleX, (float)-layer->canvases.at(canvasName).texture.height * scaleY},
            {0, 0},
            rotation,
            {color.r, color.g, color.b, color.a});

        if (shader.id != 0)
            EndShaderMode();
    }

    // Function that uses a destination rectangle
    void DrawCanvasToCurrentRenderTargetWithDestRect(
        const std::shared_ptr<Layer> layer, const std::string &canvasName,
        const Rectangle &destRect, const Color &color, Shader shader)
    {
        if (layer->canvases.find(canvasName) == layer->canvases.end())
            return;

        // Optional shader
        if (shader.id != 0)
            BeginShaderMode(shader);

        // Draw the texture to the specified destination rectangle
        DrawTexturePro(
            layer->canvases.at(canvasName).texture,
            {0, 0, (float)layer->canvases.at(canvasName).texture.width, (float)-layer->canvases.at(canvasName).texture.height},
            destRect, // Destination rectangle
            {0, 0},   // Origin for rotation (set to top-left here, can be adjusted)
            0.0f,     // No rotation
            {color.r, color.g, color.b, color.a});

        if (shader.id != 0)
            EndShaderMode();
    }

    auto AddDrawTransformEntityWithAnimationWithPipeline(std::shared_ptr<Layer> layer, entt::registry* registry, entt::entity e, int z) -> void {
        AddDrawCommand(layer, "draw_transform_entity_animation_pipeline", {e, registry}, z);
    }
    
    // auto DrawTransformEntityWithAnimationWithPipeline(entt::registry& registry, entt::entity e) -> void {
    //     using namespace shaders;
    //     using namespace shader_pipeline;

    
    //     // 1. Fetch animation frame and sprite
    //     Rectangle* animationFrame = nullptr;
    //     SpriteComponentASCII* currentSprite = nullptr;

        
    //     bool flipX{false}, flipY{false};
    
    //     if (registry.any_of<AnimationQueueComponent>(e)) {
            
    //         auto& aqc = registry.get<AnimationQueueComponent>(e);
            
    //         if (aqc.noDraw)
    //         {
    //             return;
    //         }
            
    //         if (aqc.animationQueue.empty()) {
    //             if (!aqc.defaultAnimation.animationList.empty()) {
    //                 animationFrame = &aqc.defaultAnimation.animationList[aqc.defaultAnimation.currentAnimIndex].first.spriteData.frame;
    //                 currentSprite = &aqc.defaultAnimation.animationList[aqc.defaultAnimation.currentAnimIndex].first;
    //                 flipX = aqc.defaultAnimation.flippedHorizontally;
    //                 flipY = aqc.defaultAnimation.flippedVertically;
    //             }
    //         } else {
    //             auto& currentAnimObject = aqc.animationQueue[aqc.currentAnimationIndex];
    //             animationFrame = &currentAnimObject.animationList[currentAnimObject.currentAnimIndex].first.spriteData.frame;
    //             currentSprite = &currentAnimObject.animationList[currentAnimObject.currentAnimIndex].first;
    //             flipX = currentAnimObject.flippedHorizontally;
    //             flipY = currentAnimObject.flippedVertically;
    //         }
    //     }
    
    //     AssertThat(animationFrame, Is().Not().Null());
    //     AssertThat(currentSprite, Is().Not().Null());

    //     auto spriteAtlas = currentSprite->spriteData.texture;
    
    //     float baseWidth = animationFrame->width;
    //     float baseHeight = animationFrame->height;
    
    //     auto& pipelineComp = registry.get<ShaderPipelineComponent>(e);
    //     float pad = pipelineComp.padding;
    
    //     float renderWidth = baseWidth + pad * 2.0f;
    //     float renderHeight = baseHeight + pad * 2.0f;

    //     float xFlipModifier = flipX ? -1.0f : 1.0f;
    //     float yFlipModifier = flipY ? -1.0f : 1.0f;
    
    //     AssertThat(renderWidth, IsGreaterThan(0.0f));
    //     AssertThat(renderHeight, IsGreaterThan(0.0f));
    
    //     Color bgColor = currentSprite->bgColor;
    //     Color fgColor = currentSprite->fgColor;
    //     bool drawBackground = !currentSprite->noBackgroundColor;
    //     bool drawForeground = !currentSprite->noForegroundColor;
    
    //     // 2. Init pipeline buffer if needed
    //     if (!IsInitialized() || width < renderWidth || height < renderHeight) {
    //         shader_pipeline::ShaderPipelineUnload();
    //         ShaderPipelineInit(renderWidth, renderHeight);
    //     }
    
    //     // 3. Draw base sprite to ping texture (no transforms!)
    //     // BeginTextureMode(front());
    //     render_stack_switch_internal::Push(front());
    //     ClearBackground({0, 0, 0, 0});
    
    //     Vector2 drawOffset = { pad, pad };
    
    //     if (drawBackground) {
    //         layer::RectanglePro(drawOffset.x, drawOffset.y, {baseWidth, baseHeight}, {0, 0}, 0, bgColor);
    //     }
    
    //     if (drawForeground) {
    //         if (animationFrame) {
    //             layer::TexturePro(*spriteAtlas, *animationFrame, drawOffset.x, drawOffset.y, {baseWidth * xFlipModifier, baseHeight * yFlipModifier}, {0, 0}, 0, fgColor);
    //             // debug draw rect
    //             // layer::RectanglePro(drawOffset.x, drawOffset.y, {baseWidth, baseHeight}, {0, 0}, 0, fgColor);
                
    //         } else {
    //             layer::RectanglePro(drawOffset.x, drawOffset.y, {baseWidth, baseHeight}, {0, 0}, 0, fgColor);
    //         }
    //     }
        
    //     render_stack_switch_internal::Pop();
        
    //     // render the result of front() to the screen for debugging
        
    
    //     // 4. Apply shader passes
        
    //     int debugPassIndex = 0;  // you can reset this outside if needed
    
    //     for (ShaderPass& pass : pipelineComp.passes) {
    //         if (!pass.enabled) continue;
    
    //         Shader shader = getShader(pass.shaderName);
            
    //         render_stack_switch_internal::Push(back());
    //         // BeginTextureMode(back());
    //         ClearBackground({0, 0, 0, 0});
            
    //         AssertThat(shader.id, IsGreaterThan(0));
    //         //FIXME: commenting out shader for debugging
    //         BeginShaderMode(shader);

    //         shaders::ApplyUniformsToShader(shader, pass.uniforms);
    //         // run optional lambda pre-pass
    //         if (pass.customPrePassFunction) {
    //             pass.customPrePassFunction();
    //         }
    
    //         DrawTextureRec(front().texture, {0, 0, (float)width * xFlipModifier, (float)-height * yFlipModifier}, {0, 0}, WHITE); // invert Y 
    
    //         EndShaderMode();
    //         render_stack_switch_internal::Pop();
    
    //         Swap();
            
    //         // DEBUG: Show result of each pass visually
            

    //         int debugOffsetX = 10;
    //         int debugOffsetY = 10 + debugPassIndex * (int)(renderHeight + 10);

    //         DrawTextureRec(
    //             front().texture,
    //             { 0, 0, renderWidth * xFlipModifier, -renderHeight * yFlipModifier},  // negative Y to flip
    //             { (float)debugOffsetX, (float)debugOffsetY },
    //             WHITE
    //         );
    //         DrawRectangleLines(debugOffsetX, debugOffsetY, (int)renderWidth, (int)renderHeight, RED);
    //         DrawText(
    //             fmt::format("Pass {}: {}", debugPassIndex, pass.shaderName).c_str(),
    //             debugOffsetX + 5,
    //             debugOffsetY + 5,
    //             10,
    //             WHITE
    //         );

    //         debugPassIndex++;
    //     }
    
    //     SetLastRenderTarget(front());
    
    //     // 5. Final draw with transform
    //     auto& transform = registry.get<transform::Transform>(e);
    
    //     // Where we want the final (padded) texture drawn on screen
    //     Vector2 drawPos = {
    //         transform.getVisualX() - pad,
    //         transform.getVisualY() - pad
    //     };
    
    //     // Update for use elsewhere
    //     SetLastRenderRect({ drawPos.x, drawPos.y, renderWidth, renderHeight });
    
    //     Rectangle sourceRect = { 0, 0, renderWidth * xFlipModifier, -renderHeight * yFlipModifier};  // Negative height to flip Y
    //     Vector2 origin = { renderWidth * 0.5f, renderHeight * 0.5f };
    //     Vector2 position = { drawPos.x + origin.x, drawPos.y + origin.y };
        
    //     PushMatrix();
    //     Translate(position.x, position.y);
    //     Scale(transform.getVisualScaleWithHoverAndDynamicMotionReflected(), transform.getVisualScaleWithHoverAndDynamicMotionReflected());
    //     Rotate(transform.getVisualRWithDynamicMotionAndXLeaning());
    //     Translate(-origin.x, -origin.y);
    
    //     DrawTextureRec(front().texture, sourceRect, { 0, 0 }, WHITE);
    //     // debug rect
    
    //     PopMatrix();
    // }
    
    auto DrawTransformEntityWithAnimationWithPipeline(entt::registry& registry, entt::entity e) -> void {
        using namespace shaders;
        using namespace shader_pipeline;
    
        // 1. Fetch animation frame and sprite
        Rectangle* animationFrame = nullptr;
        SpriteComponentASCII* currentSprite = nullptr;
        bool flipX{false}, flipY{false};
        
        float intrinsicScale = 1.0f;
        float uiScale = 1.0f;

        
    
        if (registry.any_of<AnimationQueueComponent>(e)) {
            auto& aqc = registry.get<AnimationQueueComponent>(e);
            if (aqc.noDraw) return;
            
            // compute the same renderScale as in your other overload:
            intrinsicScale = aqc.animationQueue.empty()
            ? aqc.defaultAnimation.intrinsincRenderScale.value_or(1.0f)
            : aqc.animationQueue[aqc.currentAnimationIndex]
                .intrinsincRenderScale.value_or(1.0f);

            uiScale = aqc.animationQueue.empty()
            ? aqc.defaultAnimation.uiRenderScale.value_or(1.0f)
            : aqc.animationQueue[aqc.currentAnimationIndex]
                .uiRenderScale.value_or(1.0f);
    
            if (aqc.animationQueue.empty()) {
                if (!aqc.defaultAnimation.animationList.empty()) {
                    animationFrame = &aqc.defaultAnimation.animationList[aqc.defaultAnimation.currentAnimIndex].first.spriteData.frame;
                    currentSprite = &aqc.defaultAnimation.animationList[aqc.defaultAnimation.currentAnimIndex].first;
                    flipX = aqc.defaultAnimation.flippedHorizontally;
                    flipY = aqc.defaultAnimation.flippedVertically;
                }
            } else {
                auto& currentAnimObject = aqc.animationQueue[aqc.currentAnimationIndex];
                animationFrame = &currentAnimObject.animationList[currentAnimObject.currentAnimIndex].first.spriteData.frame;
                currentSprite = &currentAnimObject.animationList[currentAnimObject.currentAnimIndex].first;
                flipX = currentAnimObject.flippedHorizontally;
                flipY = currentAnimObject.flippedVertically;
            }
        }
        
        float renderScale = intrinsicScale * uiScale;
    
        AssertThat(animationFrame, Is().Not().Null());
        AssertThat(currentSprite, Is().Not().Null());
    
        auto spriteAtlas = currentSprite->spriteData.texture;
        // float baseWidth = animationFrame->width;
        // float baseHeight = animationFrame->height;
        
        float baseWidth  = animationFrame->width  * renderScale;
        float baseHeight = animationFrame->height * renderScale;
    
        auto& pipelineComp = registry.get<ShaderPipelineComponent>(e);
        float pad = pipelineComp.padding;
    
        float renderWidth = baseWidth + pad * 2.0f;
        float renderHeight = baseHeight + pad * 2.0f;
    
        float xFlipModifier = flipX ? -1.0f : 1.0f;
        float yFlipModifier = flipY ? -1.0f : 1.0f;
    
        AssertThat(renderWidth, IsGreaterThan(0.0f));
        AssertThat(renderHeight, IsGreaterThan(0.0f));
    
        Color bgColor = currentSprite->bgColor;
        Color fgColor = currentSprite->fgColor;
        bool drawBackground = !currentSprite->noBackgroundColor;
        bool drawForeground = !currentSprite->noForegroundColor;
    
        if (!IsInitialized() || width < renderWidth || height < renderHeight) {
            ShaderPipelineUnload();
            ShaderPipelineInit(renderWidth, renderHeight);
        }
    
        // 2. Draw base sprite to front() (no transforms)
        render_stack_switch_internal::Push(front());
        ClearBackground({0, 0, 0, 0});
        Vector2 drawOffset = { pad, pad };
    
        if (drawBackground) {
            layer::RectanglePro(drawOffset.x, drawOffset.y, {baseWidth, baseHeight}, {0, 0}, 0, bgColor);
        }
    
        if (drawForeground) {
            if (animationFrame) {
                layer::TexturePro(*spriteAtlas, *animationFrame, drawOffset.x, drawOffset.y, {baseWidth * xFlipModifier, baseHeight * yFlipModifier}, {0, 0}, 0, fgColor);
            } else {
                layer::RectanglePro(drawOffset.x, drawOffset.y, {baseWidth, baseHeight}, {0, 0}, 0, fgColor);
            }
        }
    
        render_stack_switch_internal::Pop();
    
        // 🟡 Save base sprite result
        RenderTexture2D baseSpriteRender = front();
    
        // 3. Apply shader passes
        int debugPassIndex = 0;
        for (ShaderPass& pass : pipelineComp.passes) {
            if (!pass.enabled) continue;
    
            Shader shader = getShader(pass.shaderName);
            render_stack_switch_internal::Push(back());
            ClearBackground({0, 0, 0, 0});
            AssertThat(shader.id, IsGreaterThan(0));
            BeginShaderMode(shader);
            ApplyUniformsToShader(shader, pass.uniforms);
            if (pass.customPrePassFunction) pass.customPrePassFunction();
            DrawTextureRec(front().texture, {0, 0, (float)width * xFlipModifier, (float)-height * yFlipModifier}, {0, 0}, WHITE);
            EndShaderMode();
            render_stack_switch_internal::Pop();
            Swap();
    
            int debugOffsetX = 10;
            int debugOffsetY = 10 + debugPassIndex * (int)(renderHeight + 10);
            DrawTextureRec(front().texture, {0, 0, renderWidth * xFlipModifier, -renderHeight * yFlipModifier}, { (float)debugOffsetX, (float)debugOffsetY }, WHITE);
            DrawRectangleLines(debugOffsetX, debugOffsetY, (int)renderWidth, (int)renderHeight, RED);
            DrawText(fmt::format("Pass {}: {}", debugPassIndex, pass.shaderName).c_str(), debugOffsetX + 5, debugOffsetY + 5, 10, WHITE);
            debugPassIndex++;
        }
    
        // 🔵 Save post-pass result
        RenderTexture2D postPassRender = front();
    
        // 4. Overlay draws
        for (const auto& overlay : pipelineComp.overlayDraws) {
            if (!overlay.enabled) continue;
    
            Shader shader = getShader(overlay.shaderName);
            AssertThat(shader.id, IsGreaterThan(0));
    
            BeginTextureMode(back());
            ClearBackground({0, 0, 0, 0});
            BeginShaderMode(shader);
            ApplyUniformsToShader(shader, overlay.uniforms);
            if (overlay.customPrePassFunction) overlay.customPrePassFunction();
    
            RenderTexture2D& source = (overlay.inputSource == shader_pipeline::OverlayInputSource::BaseSprite) ? baseSpriteRender : postPassRender;
            DrawTextureRec(source.texture, {0, 0, renderWidth * xFlipModifier, -renderHeight * yFlipModifier}, {0, 0}, WHITE);
    
            EndShaderMode();
            EndTextureMode();
    
            render_stack_switch_internal::Push(front());
            BeginBlendMode((int)overlay.blendMode);
            DrawTextureRec(back().texture, {0, 0, renderWidth * xFlipModifier, -renderHeight * yFlipModifier}, {0, 0}, WHITE);
            EndBlendMode();
            render_stack_switch_internal::Pop();
        }
    
        SetLastRenderTarget(front());
    
        // 5. Final draw with transform
        auto& transform = registry.get<transform::Transform>(e);
        Vector2 drawPos = { transform.getVisualX() - pad, transform.getVisualY() - pad };
        SetLastRenderRect({ drawPos.x, drawPos.y, renderWidth, renderHeight });
    
        Rectangle sourceRect = { 0, 0, renderWidth * xFlipModifier, -renderHeight * yFlipModifier };
        Vector2 origin = { renderWidth * 0.5f, renderHeight * 0.5f };
        Vector2 position = { drawPos.x + origin.x, drawPos.y + origin.y };
    
        if (static_cast<int>(e) == 235)
        {
            SPDLOG_DEBUG("DrawTransformEntityWithAnimationWithPipeline > Entity ID: {}, getVisualY: {}, getVisualX: {}, getVisualW: {}, getVisualH: {}", static_cast<int>(e), transform.getVisualY(), transform.getVisualX(), transform.getVisualW(), transform.getVisualH());
        }
        PushMatrix();
        Translate(position.x, position.y);
        Scale(transform.getVisualScaleWithHoverAndDynamicMotionReflected(), transform.getVisualScaleWithHoverAndDynamicMotionReflected());
        Rotate(transform.getVisualRWithDynamicMotionAndXLeaning());
        Translate(-origin.x, -origin.y);
        DrawTextureRec(front().texture, sourceRect, { 0, 0 }, WHITE);
        PopMatrix();
    }
    
    
    
    
    auto AddDrawTransformEntityWithAnimation(std::shared_ptr<Layer> layer, entt::registry* registry, entt::entity e, int z) -> void
    {
        AddDrawCommand(layer, "draw_transform_entity_animation", {e, registry}, z);
    }
    
    auto DrawTransformEntityWithAnimation(entt::registry &registry, entt::entity e) -> void {
        
        if (registry.any_of<AnimationQueueComponent>(e))
        {
            auto &aqc = registry.get<AnimationQueueComponent>(e);
            if (aqc.noDraw)
            {
                return;
            }
        }
        
        
        // if this entity has a master comp that is a ui element, that means it's a ui object and it needs to respect the ui scale
        // float uiScale = 1.0f;
        // auto &role = registry.get<transform::InheritedProperties>(e);
        // if (registry.valid(role.master) && registry.any_of<ui::UIConfig>(role.master))
        // {
        //     uiScale = registry.get<ui::UIConfig>(role.master).scale.value_or(1.0f);
        // }
        
        // this renderscale is from the animation object itself.
        float renderScale = 1.0f;
        
        // Fetch the animation frame if the entity has an animation queue
        Rectangle *animationFrame = nullptr;
        SpriteComponentASCII *currentSprite = nullptr;

        bool flipX{false}, flipY{false};

        if (registry.any_of<AnimationQueueComponent>(e))
        {
            auto &aqc = registry.get<AnimationQueueComponent>(e);

            // Use the current animation frame or the default frame
            if (aqc.animationQueue.empty())
            {
                if (!aqc.defaultAnimation.animationList.empty())
                {
                    animationFrame = &aqc.defaultAnimation.animationList[aqc.defaultAnimation.currentAnimIndex].first.spriteData.frame;
                    currentSprite = &aqc.defaultAnimation.animationList[aqc.defaultAnimation.currentAnimIndex].first;
                    flipX = aqc.defaultAnimation.flippedHorizontally;
                    flipY = aqc.defaultAnimation.flippedVertically;
                    renderScale = aqc.defaultAnimation.intrinsincRenderScale.value_or(1.0f) * aqc.defaultAnimation.uiRenderScale.value_or(1.0f);
                }
            }
            else
            {
                auto &currentAnimObject = aqc.animationQueue[aqc.currentAnimationIndex];
                animationFrame = &currentAnimObject.animationList[currentAnimObject.currentAnimIndex].first.spriteData.frame;
                currentSprite = &currentAnimObject.animationList[currentAnimObject.currentAnimIndex].first;
                flipX = currentAnimObject.flippedHorizontally;
                flipY = currentAnimObject.flippedVertically;
                renderScale = currentAnimObject.intrinsincRenderScale.value_or(1.0f) * currentAnimObject.uiRenderScale.value_or(1.0f);
            }
        }
        

        using namespace snowhouse;

        AssertThat(animationFrame, Is().Not().Null());
        AssertThat(currentSprite, Is().Not().Null());

        auto spriteAtlas = currentSprite->spriteData.texture;

        // float renderWidth = animationFrame->width * uiScale;
        // float renderHeight = animationFrame->height * uiScale;
        float renderWidth = animationFrame->width;
        float renderHeight = animationFrame->height;
        AssertThat(renderWidth, IsGreaterThan(0.0f));
        AssertThat(renderHeight, IsGreaterThan(0.0f));

        float flipXModifier = flipX ? -1.0f : 1.0f;
        float flipYModifier = flipY ? -1.0f : 1.0f;

        // Check if the entity has colors (fg/bg)
        Color bgColor = Color{0, 0, 0, 0}; // Default to fully transparent
        Color fgColor = WHITE;             // Default foreground color
        bool drawBackground = false;
        bool drawForeground = true;

        if (currentSprite)
        {
            bgColor = currentSprite->bgColor;
            fgColor = currentSprite->fgColor;
            //FIXME: debug
            if (fgColor.a <= 0)
                fgColor = WHITE;                      
            drawBackground = !currentSprite->noBackgroundColor;
            drawForeground = !currentSprite->noForegroundColor;
            // FIXME: debug
            drawForeground = true;
        }

        
        // fetch transform
        auto &transform = registry.get<transform::Transform>(e);
        
        if (static_cast<int>(e) == 235)
        {
            SPDLOG_DEBUG("DrawTransformEntityWithAnimationWithPipeline > Entity ID: {}, getVisualY: {}, getVisualX: {}, getVisualW: {}, getVisualH: {}", static_cast<int>(e), transform.getVisualY(), transform.getVisualX(), transform.getVisualW(), transform.getVisualH());
        }
        
        
        PushMatrix();
        
        Translate(transform.getVisualX() + transform.getVisualW() * 0.5, transform.getVisualY() + transform.getVisualH() * 0.5);

        Scale(transform.getVisualScaleWithHoverAndDynamicMotionReflected(), transform.getVisualScaleWithHoverAndDynamicMotionReflected());

        Rotate(transform.getVisualRWithDynamicMotionAndXLeaning());

        Translate(-transform.getVisualW() * 0.5, -transform.getVisualH() * 0.5);

        // Draw background rectangle if enabled
        if (drawBackground)
        {
            layer::RectanglePro(0, 0, {renderWidth, renderHeight}, {0, 0}, 0, {bgColor.r, bgColor.g, bgColor.b, bgColor.a});
        }

        // Draw the animation frame or a default rectangle if no animation is present
        if (drawForeground)
        {
            if (animationFrame)
            {
                auto &node = registry.get<transform::GameObject>(e);

                if (node.shadowDisplacement) {
                    float baseExaggeration = globals::BASE_SHADOW_EXAGGERATION;
                    float heightFactor = 1.0f + node.shadowHeight.value_or(0.f); // Increase effect based on height
    
                    // Adjust displacement using shadow height
                    float shadowOffsetX = node.shadowDisplacement->x * baseExaggeration * heightFactor;
                    float shadowOffsetY = node.shadowDisplacement->y * baseExaggeration * heightFactor;
    
                    float shadowAlpha = 0.8f;      // 0.0f to 1.0f
                    Color shadowColor = Fade(BLACK, shadowAlpha);
    
                    // Translate to shadow position
                    Translate(-shadowOffsetX, shadowOffsetY);
                    
                    Scale(renderScale, renderScale);
    
                    // Draw shadow by rendering the same frame with a black tint and offset
                    layer::TexturePro(
                        *spriteAtlas,
                        {animationFrame->x, animationFrame->y, animationFrame->width  * flipXModifier, animationFrame->height  * flipYModifier},
                        0, 0,
                        {renderWidth * flipXModifier, renderHeight * flipYModifier},
                        {0, 0},
                        0,
                        shadowColor
                    );
                    
                    // undo scale
                    Scale(1.0f / renderScale, 1.0f / renderScale);
    
                    // Reset translation to original position
                    Translate(shadowOffsetX, -shadowOffsetY);
                }
                
                Scale(renderScale, renderScale);

                //FIXME: commenting out for debugging
                layer::TexturePro(*spriteAtlas, {animationFrame->x, animationFrame->y, animationFrame->width * flipXModifier, animationFrame->height * flipYModifier}, 0, 0, {renderWidth , renderHeight }, {0, 0}, 0, {fgColor.r, fgColor.g, fgColor.b, fgColor.a});

                // Vector2 origin = {renderWidth * 0.5f, renderHeight * 0.5f};
                // Vector2 destPos = {renderWidth * 0.5f, renderHeight * 0.5f};

                // layer::TexturePro(
                //     *spriteAtlas,
                //     {animationFrame->x, animationFrame->y, animationFrame->width, animationFrame->height},
                //     destPos.x, destPos.y,                                         // Destination position (centered)
                //     {renderWidth * flipXModifier, renderHeight * flipYModifier}, // Size with flip
                //     origin,                                                       // Origin is center
                //     0,
                //     fgColor
                // );
            }
            else
            {
                layer::RectanglePro(0, 0, {renderWidth, renderHeight}, {0, 0}, 0, {fgColor.r, fgColor.g, fgColor.b, fgColor.a});
            }
        }

        PopMatrix();
        
    }
    
    auto AddDrawEntityWithAnimation(std::shared_ptr<Layer> layer, entt::registry* registry, entt::entity e, int x, int y, int z) -> void
    {
        AddDrawCommand(layer, "draw_entity_animation", {e, registry, x, y}, z);
    }
    
    // deprecated
    auto DrawEntityWithAnimation(entt::registry &registry, entt::entity e, int x, int y) -> void
    {
        
        // Fetch the animation frame if the entity has an animation queue
        Rectangle *animationFrame = nullptr;
        SpriteComponentASCII *currentSprite = nullptr;

        if (registry.any_of<AnimationQueueComponent>(e))
        {
            auto &aqc = registry.get<AnimationQueueComponent>(e);

            // Use the current animation frame or the default frame
            if (aqc.animationQueue.empty())
            {
                if (!aqc.defaultAnimation.animationList.empty())
                {
                    animationFrame = &aqc.defaultAnimation.animationList[aqc.defaultAnimation.currentAnimIndex].first.spriteData.frame;
                    currentSprite = &aqc.defaultAnimation.animationList[aqc.defaultAnimation.currentAnimIndex].first;
                }
            }
            else
            {
                auto &currentAnimObject = aqc.animationQueue[aqc.currentAnimationIndex];
                animationFrame = &currentAnimObject.animationList[currentAnimObject.currentAnimIndex].first.spriteData.frame;
                currentSprite = &currentAnimObject.animationList[currentAnimObject.currentAnimIndex].first;
            }
        }

        using namespace snowhouse;

        auto spriteAtlas = *currentSprite->spriteData.texture;

        AssertThat(animationFrame, Is().Not().Null());
        AssertThat(currentSprite, Is().Not().Null());

        float renderWidth = animationFrame->width;
        float renderHeight = animationFrame->height;
        AssertThat(renderWidth, IsGreaterThan(0.0f));
        AssertThat(renderHeight, IsGreaterThan(0.0f));

        // Check if the entity has colors (fg/bg)
        Color bgColor = Color{0, 0, 0, 0}; // Default to fully transparent
        Color fgColor = WHITE;             // Default foreground color
        bool drawBackground = false;
        bool drawForeground = true;

        if (currentSprite)
        {
            bgColor = currentSprite->bgColor;
            fgColor = currentSprite->fgColor;
            drawBackground = !currentSprite->noBackgroundColor;
            drawForeground = !currentSprite->noForegroundColor;
        }

        // Draw background rectangle if enabled
        if (drawBackground)
        {
            layer::RectanglePro(x, y, {renderWidth, renderHeight}, {0, 0}, 0, {bgColor.r, bgColor.g, bgColor.b, bgColor.a});
        }

        // Draw the animation frame or a default rectangle if no animation is present
        if (!drawForeground) return; 

        auto &node = registry.get<transform::GameObject>(e);
        
        if (animationFrame)
        {

            if (node.shadowDisplacement) {
                float baseExaggeration = globals::BASE_SHADOW_EXAGGERATION;
                float heightFactor = 1.0f + node.shadowHeight.value_or(0.f); // Increase effect based on height

                // Adjust displacement using shadow height
                float shadowOffsetX = node.shadowDisplacement->x * baseExaggeration * heightFactor;
                float shadowOffsetY = node.shadowDisplacement->y * baseExaggeration * heightFactor;

                float shadowAlpha = 0.8f;      // 0.0f to 1.0f
                Color shadowColor = Fade(BLACK, shadowAlpha);

                // Translate to shadow position
                Translate(-shadowOffsetX, shadowOffsetY);

                // Draw shadow by rendering the same frame with a black tint and offset
                layer::TexturePro(
                    spriteAtlas,
                    {animationFrame->x, animationFrame->y, animationFrame->width, animationFrame->height},
                    0, 0,
                    {renderWidth, renderHeight},
                    {0, 0},
                    0,
                    shadowColor
                );

                // Reset translation to original position
                Translate(shadowOffsetX, -shadowOffsetY);
            }
            
            // draw main image

            layer::TexturePro(spriteAtlas, {animationFrame->x, animationFrame->y, animationFrame->width, animationFrame->height}, x, y, {renderWidth, renderHeight}, {0, 0}, 0, {fgColor.r, fgColor.g, fgColor.b, fgColor.a});
        }
        else
        {
            layer::RectanglePro(x, y, {renderWidth, renderHeight}, {0, 0}, 0, {fgColor.r, fgColor.g, fgColor.b, fgColor.a});
        }
    

    }

    void Circle(float x, float y, float radius, const Color &color)
    {
        DrawCircle(static_cast<int>(x), static_cast<int>(y), radius, {color.r, color.g, color.b, color.a});
    }

    void Line(float x1, float y1, float x2, float y2, const Color &color, float lineWidth)
    {
        DrawLineEx({x1, y1}, {x2, y2}, lineWidth, {color.r, color.g, color.b, color.a});
    }

    void RectangleDraw(float x, float y, float width, float height, const Color &color, float lineWidth)
    {
        if (lineWidth == 0.0f)
        {
            DrawRectangle(static_cast<int>(x - width / 2), static_cast<int>(y - height / 2),
                          static_cast<int>(width), static_cast<int>(height),
                          {color.r, color.g, color.b, color.a});
        }
        else
        {
            DrawRectangleLinesEx({x - width / 2, y - height / 2, width, height}, lineWidth, {color.r, color.g, color.b, color.a});
        }
    }


    void AddRectangle(std::shared_ptr<Layer> layer, float x, float y, float width, float height, const Color &color, float lineWidth, int z)
    {
        AddDrawCommand(layer, "rectangle", {x, y, width, height, color, lineWidth}, z);
    }

    void DashedLine(float x1, float y1, float x2, float y2, float dashSize, float gapSize, const Color &color, float lineWidth)
    {
        float dx = x2 - x1;
        float dy = y2 - y1;
        float len = sqrt(dx * dx + dy * dy);
        float step = dashSize + gapSize;
        float angle = atan2(dy, dx);

        for (float i = 0; i < len; i += step)
        {
            float startX = x1 + cos(angle) * i;
            float startY = y1 + sin(angle) * i;
            float endX = x1 + cos(angle) * std::min(i + dashSize, len);
            float endY = y1 + sin(angle) * std::min(i + dashSize, len);
            DrawLineEx({startX, startY}, {endX, endY}, lineWidth, {color.r, color.g, color.b, color.a});
        }
    }

    void AddDashedLine(std::shared_ptr<Layer> layer, float x1, float y1, float x2, float y2, float dashSize, float gapSize, const Color &color, float lineWidth, int z)
    {
        AddDrawCommand(layer, "dashed_line", {x1, y1, x2, y2, dashSize, gapSize, color, lineWidth}, z);
    }

    void AddLine(std::shared_ptr<Layer> layer, float x1, float y1, float x2, float y2, const Color &color, float lineWidth, int z )
    {
        AddDrawCommand(layer, "line", {x1, y1, x2, y2, color, lineWidth}, z);
    }

    void Polygon(const std::vector<Vector2> &vertices, const Color &color, float lineWidth)
    {
        if (lineWidth == 0.0f)
        {
            DrawPoly(vertices[0], vertices.size(), vertices[1].x, vertices[1].y, {color.r, color.g, color.b, color.a});
        }
        else
        {
            DrawLineStrip(const_cast<std::vector<Vector2> &>(vertices).data(), vertices.size(), {color.r, color.g, color.b, color.a});
        }
    }

    void AddPolygon(std::shared_ptr<Layer> layer, const std::vector<Vector2> &vertices, const Color &color, float lineWidth , int z)
    {
        AddDrawCommand(layer, "polygon", {vertices, color, lineWidth}, z);
    }

    void Triangle(Vector2 p1, Vector2 p2, Vector2 p3, const Color &color)
    {
        DrawTriangle(p2, p1, p3, {color.r, color.g, color.b, color.a});
    }

    void AddTriangle(std::shared_ptr<Layer> layer, Vector2 p1, Vector2 p2, Vector2 p3, const Color &color, int z )
    {
        AddDrawCommand(layer, "triangle", {p1, p2, p3, color}, z);
    }

    void Push(Camera2D *camera)
    {
        BeginMode2D(*camera);
    }

    void Pop()
    {
        EndMode2D();
    }

    void AddPush(std::shared_ptr<Layer> layer, Camera2D *camera, int z)
    {
        AddDrawCommand(layer, "push", {camera},z);
    }

    void AddPop(std::shared_ptr<Layer> layer, int z )
    {
        AddDrawCommand(layer, "pop", {}, z);
    }

    void Rotate(float angle)
    {
        rlRotatef(angle, 0.0f, 0.0f, 1.0f);
    }

    void AddRotate(std::shared_ptr<Layer> layer, float angle, int z )
    {
        AddDrawCommand(layer, "rotate", {angle}, z);
    }

    void Scale(float scaleX, float scaleY)
    {
        // SPDLOG_DEBUG("Set layer scale: {} {}", scaleX, scaleY);
        rlScalef(scaleX, scaleY, 1.0f);
    }

    void AddScale(std::shared_ptr<Layer> layer, float scaleX, float scaleY, int z)
    {
        AddDrawCommand(layer, "scale", {scaleX, scaleY}, z);
    }

    void SetShader(const Shader &shader)
    {
        BeginShaderMode(shader);
    }

    void ResetShader()
    {
        EndShaderMode();
    }

    void AddSetShader(std::shared_ptr<Layer> layer, const Shader &shader, int z )
    {
        AddDrawCommand(layer, "set_shader", {shader}, z);
    }

    void AddResetShader(std::shared_ptr<Layer> layer, int z )
    {
        AddDrawCommand(layer, "reset_shader", {}, z);
    }

    void DrawImage(const Texture2D &image, float x, float y, float rotation, float scaleX, float scaleY, const Color &color)
    {
        DrawTextureEx(image, {x, y}, rotation, scaleX, {color.r, color.g, color.b, color.a});
    }

    void AddDrawImage(std::shared_ptr<Layer> layer, const Texture2D &image, float x, float y, float rotation, float scaleX, float scaleY , const Color &color, int z)
    {
        AddDrawCommand(layer, "draw_image", {image, x, y, rotation, scaleX, scaleY, color}, z);
    }

    void DrawTextCentered(const std::string &text, const Font &font, float x, float y, const Color &color, float fontSize)
    {
        Vector2 textSize = MeasureTextEx(font, text.c_str(), fontSize, 1.0f);
        DrawTextEx(font, text.c_str(), {x - textSize.x / 2, y - textSize.y / 2}, fontSize, 1.0f, {color.r, color.g, color.b, color.a});
    }

    void AddDrawTextCentered(std::shared_ptr<Layer> layer, const std::string &text, const Font &font, float x, float y, const Color &color, float fontSize, int z)
    {
        AddDrawCommand(layer, "draw_text_centered", {text, font, x, y, color, fontSize}, z);
    }

    void SetBlendMode(int blendMode)
    {
        ::BeginBlendMode((BlendMode)blendMode);
    }

    void UnsetBlendMode() {
        ::EndBlendMode();
    }

    void AddSetBlendMode(std::shared_ptr<Layer> layer, int blendMode, int z)
    {
        AddDrawCommand(layer, "set_blend_mode", {blendMode}, z);
    }

    void AddUnsetBlendMode(std::shared_ptr<Layer> layer, int z) {
        AddDrawCommand(layer, "unset_blend_mode", {-1}, z);
    }

    void AddUniformFloat(std::shared_ptr<Layer> layer, Shader shader, const std::string &uniform, float value)
    {
        layer->drawCommands.push_back({"send_uniform_float", {shader, uniform, value}});
    }

    void SendUniformFloat(Shader &shader, const std::string &uniform, float value)
    {
        SetShaderValue(shader, GetShaderLocation(shader, uniform.c_str()), &value, SHADER_UNIFORM_FLOAT);
    }

    void AddUniformInt(std::shared_ptr<Layer> layer, Shader shader, const std::string &uniform, int value)
    {
        layer->drawCommands.push_back({"send_uniform_int", {shader, uniform, value}});
    }

    void SendUniformInt(Shader &shader, const std::string &uniform, int value)
    {
        SetShaderValue(shader, GetShaderLocation(shader, uniform.c_str()), &value, SHADER_UNIFORM_INT);
    }

    void AddUniformVector2(std::shared_ptr<Layer> layer, Shader shader, const std::string &uniform, const Vector2 &value)
    {
        layer->drawCommands.push_back({"send_uniform_vec2", {shader, uniform, value}});
    }

    void SendUniformVector2(Shader &shader, const std::string &uniform, const Vector2 &value)
    {
        SetShaderValue(shader, GetShaderLocation(shader, uniform.c_str()), &value, SHADER_UNIFORM_VEC2);
    }

    void AddUniformVector3(std::shared_ptr<Layer> layer, Shader shader, const std::string &uniform, const Vector3 &value)
    {
        layer->drawCommands.push_back({"send_uniform_vec3", {shader, uniform, value}});
    }

    void SendUniformVector3(Shader &shader, const std::string &uniform, const Vector3 &value)
    {
        SetShaderValue(shader, GetShaderLocation(shader, uniform.c_str()), &value, SHADER_UNIFORM_VEC3);
    }

    void AddUniformVector4(std::shared_ptr<Layer> layer, Shader shader, const std::string &uniform, const Vector4 &value)
    {
        layer->drawCommands.push_back({"send_uniform_vec4", {shader, uniform, value}});
    }

    void SendUniformVector4(Shader &shader, const std::string &uniform, const Vector4 &value)
    {
        SetShaderValue(shader, GetShaderLocation(shader, uniform.c_str()), &value, SHADER_UNIFORM_VEC4);
    }

    void AddUniformFloatArray(std::shared_ptr<Layer> layer, Shader shader, const std::string &uniform, const float *values, int count)
    {
        std::vector<float> array(values, values + count);
        AddDrawCommand(layer, "send_uniform_float_array", std::vector<DrawCommandArgs>{shader, uniform, array}, 0);
    }

    void SendUniformFloatArray(Shader &shader, const std::string &uniform, const float *values, int count)
    {
        SetShaderValue(shader, GetShaderLocation(shader, uniform.c_str()), values, SHADER_UNIFORM_FLOAT);
    }

    void AddUniformIntArray(std::shared_ptr<Layer> layer, Shader shader, const std::string &uniform, const int *values, int count)
    {
        std::vector<int> array(values, values + count);
        AddDrawCommand(layer, "send_uniform_int_array", std::vector<DrawCommandArgs>{shader, uniform, array}, 0);
    }

    void SendUniformIntArray(Shader &shader, const std::string &uniform, const int *values, int count)
    {
        SetShaderValue(shader, GetShaderLocation(shader, uniform.c_str()), values, SHADER_UNIFORM_INT);
    }

    void PushMatrix()
    {
        rlPushMatrix();
    }

    void AddPushMatrix(std::shared_ptr<Layer> layer, int z)
    {
        AddDrawCommand(layer, "push_matrix", {}, z);
    }

    void PopMatrix()
    {
        // SPDLOG_DEBUG("Pop layer matrix");
        rlPopMatrix();
    }

    void AddPopMatrix(std::shared_ptr<Layer> layer, int z)
    {
        AddDrawCommand(layer, "pop_matrix", {}, z);
    }

    void Translate(float x, float y)
    {
        rlTranslatef(x, y, 0);
    }

    void AddTranslate(std::shared_ptr<Layer> layer, float x, float y, int z)
    {
        AddDrawCommand(layer, "translate", {x, y}, z);
    }
    
    void Text(const std::string &text, Font font, float x, float y, const Color &color, float fontSize)
    {
        DrawTextEx(font, text.c_str(), {x, y}, fontSize, 1.0f, {color.r, color.g, color.b, color.a});
    }

    void AddText(std::shared_ptr<Layer> layer, const std::string &text, Font font, float x, float y, const Color &color, float fontSize , int z)
    {
        AddDrawCommand(layer, "text", {text, font, x, y, color, fontSize}, z);
    }

    void TextPro(const std::string &text, Font font, float x, float y, const Vector2 &origin, float rotation, float fontSize, float spacing, const Color &color)
    {
        DrawTextPro(font, text.c_str(), {x, y}, origin, rotation, fontSize, spacing, {color.r, color.g, color.b, color.a});
    }

    void AddTextPro(std::shared_ptr<Layer> layer, const std::string &text, Font font, float x, float y, const Vector2 &origin, float rotation, float fontSize, float spacing, const Color &color, int z)
    {
        AddDrawCommand(layer, "textPro", {text, font, x, y, origin, rotation, fontSize, spacing, color}, z);
    }

    void RectanglePro(float offsetX, float offsetY, const Vector2 &size, const Vector2 &rotationCenter, float rotation, const Color &color)
    {
        struct Rectangle rect = {offsetX, offsetY, size.x, size.y};
        DrawRectanglePro(
            rect,
            rotationCenter,
            rotation,
            color);
    }

    void AddRectanglePro(std::shared_ptr<Layer> layer, float offsetX, float offsetY, const Vector2 &size, const Color &color, const Vector2 &rotationCenter, float rotation, int z )
    {
        AddDrawCommand(layer, "rectanglePro", {offsetX, offsetY, size, rotationCenter, rotation, color}, z);
    }

    void TexturePro(Texture2D texture, const struct Rectangle &source, float offsetX, float offsetY, const Vector2 &size, const Vector2 &rotationCenter, float rotation, const Color &color)
    {
        struct Rectangle dest = {offsetX, offsetY, size.x, size.y};
        DrawTexturePro(
            texture,
            source,
            dest,
            rotationCenter,
            rotation,
            color);
    }

    void AddTexturePro(std::shared_ptr<Layer> layer, Texture2D texture, const struct Rectangle &source, float offsetX, float offsetY, const Vector2 &size, const Vector2 &rotationCenter, float rotation, const Color &color, int z )
    {
        AddDrawCommand(layer, "texturePro", {texture, source, offsetX, offsetY, size, rotationCenter, rotation, color}, z);
    }

    void RectangleLinesPro(float offsetX, float offsetY, const Vector2 &size, float lineThickness, const Color &color)
    {
        struct Rectangle rect = {offsetX, offsetY, size.x, size.y};
        DrawRectangleLinesEx(
            rect,
            lineThickness,
            color);
    }

    void AddRectangleLinesPro(std::shared_ptr<Layer> layer, float offsetX, float offsetY, const Vector2 &size, float lineThickness, const Color &color, int z)
    {
        AddDrawCommand(layer, "rectangleLinesPro", {offsetX, offsetY, size, lineThickness, color}, z);
    }

    void AddBeginDrawing(std::shared_ptr<Layer> layer) {
        layer->drawCommands.push_back({"begin_drawing", {}});
    }

    void BeginDrawingAction() {
        ::BeginDrawing();
    }

    void AddEndDrawing(std::shared_ptr<Layer> layer) {
        layer->drawCommands.push_back({"end_drawing", {}});
    }

    void EndDrawingAction() {
        ::EndDrawing();
    }

    void AddClearBackground(std::shared_ptr<Layer> layer, Color color) {
        AddDrawCommand(layer, "clear_background", {color}, 0);
    }

    void ClearBackgroundAction(Color color) {
        ::ClearBackground(color);
    }
}