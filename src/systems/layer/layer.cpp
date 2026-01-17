#include "layer.hpp"

#if defined(PLATFORM_WEB)
#include "util/web_glad_shim.hpp"
#endif

#if defined(__EMSCRIPTEN__)
#define GL_GLEXT_PROTOTYPES
#include <GLES3/gl3.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>
#else
// #include <GL/gl.h>
// #include <GL/glext.h>
#endif

#include "raylib.h"
#include <algorithm>
#include <cmath>
#include <functional>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <variant>
#include <vector>

#include "core/engine_context.hpp"
#include "core/globals.hpp"

#include "core/init.hpp"
#include "spdlog/spdlog.h"
#include "systems/camera/camera_manager.hpp"
#include "systems/collision/broad_phase.hpp"
#include "systems/layer/layer_optimized.hpp"
#include "systems/scripting/script_process.hpp"
#include "systems/shaders/shader_pipeline.hpp"
#include "systems/ui/box.hpp"
#include "systems/ui/element.hpp"
#include "systems/ui/ui_data.hpp"
#include "systems/uuid/uuid.hpp"
#include "util/error_handling.hpp"

#include "systems/layer/layer_command_buffer_data.hpp"
#include "systems/transform/transform_functions.hpp"

#include "entt/entt.hpp"

#include "rlgl.h"

#include "snowhouse/snowhouse.h"

#include "util/common_headers.hpp"

#include "layer_command_buffer.hpp"

#include "systems/scripting/binding_recorder.hpp"

namespace layer {
// only use for (DrawLayerCommandsToSpecificCanvas)
namespace render_stack_switch_internal {
std::stack<RenderTexture2D> renderStack{};
}
} // namespace layer

// Graphics namespace for rendering functions
namespace layer {

std::vector<std::shared_ptr<Layer>> layers;

void SortLayers() {
  std::sort(layers.begin(), layers.end(),
            [](std::shared_ptr<Layer> a, std::shared_ptr<Layer> b) {
              return a->zIndex < b->zIndex;
            });
}

void UpdateLayerZIndex(std::shared_ptr<Layer> layer, int newZIndex) {
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

void RenderAllLayersToCurrentRenderTarget(Camera2D *camera) {
  // PERF: Removed unconditional SortLayers() - called every frame but "feature isn't used"
  // Sort is still performed in UpdateLayerZIndex() when z-index actually changes

  using namespace snowhouse;
  AssertThat(layers.size(), IsGreaterThan(0));

  if (!camera) {
    // SPDLOG_WARN("Camera is null, rendering without camera transformations.");
  }

  // display layer count
  // SPDLOG_DEBUG("Rendering {} layers.", layers.size());

  int i = 0;
  for (std::shared_ptr<Layer> layer : layers) {
    // SPDLOG_DEBUG("Rendering layer #{} with {} canvases.", i++,
    // layer->canvases.size());
    AssertThat(layer->canvases.size(), IsGreaterThan(0));
    for (const auto &[canvasName, canvas] : layer->canvases) {
      DrawLayerCommandsToSpecificCanvas(layer, canvasName, camera);
      DrawCanvasToCurrentRenderTargetWithTransform(layer, canvasName, 0, 0, 0,
                                                   1, 1, WHITE);
    }
  }
}

void DrawCustomLamdaToSpecificCanvas(const std::shared_ptr<Layer> layer,
                                     const std::string &canvasName,
                                     std::function<void()> drawActions) {
  auto it = layer->canvases.find(canvasName);
  if (it == layer->canvases.end())
    return; // no canvas to draw to

  BeginTextureMode(it->second);

  // clear screen
  ClearBackground(layer->backgroundColor);

  drawActions();

  EndTextureMode();
}

void SortDrawCommands(std::shared_ptr<Layer> layer) {
  // std::sort(layer->drawCommands.begin(), layer->drawCommands.end(), [](const
  // DrawCommand &a, const DrawCommand &b)
  //           { return a.z < b.z; });
}

void AddDrawCommand(std::shared_ptr<Layer> layer, const std::string &type,
                    const std::vector<DrawCommandArgs> &args, int z) {
  DrawCommand command{type, args, z};
  // layer->drawCommands.push_back(command);
}

std::shared_ptr<Layer> CreateLayer() {
  return CreateLayerWithSize(globals::VIRTUAL_WIDTH, globals::VIRTUAL_HEIGHT);
}

void ResizeCanvasInLayer(std::shared_ptr<Layer> layer,
                         const std::string &canvasName, int width, int height) {
  auto it = layer->canvases.find(canvasName);
  if (it != layer->canvases.end()) {
    UnloadRenderTexture(it->second); // Free the existing texture
    // it->second = LoadRenderTexture(width, height); // Create a new one with
    // the specified dimensions
    it->second = LoadRenderTextureStencilEnabled(
        width, height); // Create a new one with the specified dimensions
  } else {
    // Handle error: Canvas does not exist
    SPDLOG_ERROR("Error: Canvas '{}' does not exist in the layer.", canvasName);
  }
}

std::shared_ptr<Layer> CreateLayerWithSize(int width, int height) {
  auto layer = std::make_shared<Layer>();
  // Create a default "main" canvas with the specified size
  // RenderTexture2D mainCanvas = LoadRenderTexture(width, height);
  RenderTexture2D mainCanvas = LoadRenderTextureStencilEnabled(width, height);
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
  // layer->drawCommands.clear();

  layer_command_buffer::Clear(layer);
}

void Begin() {
  ZONE_SCOPED("Layer Begin-clear commands");
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

void UnloadAllLayers() {
  for (std::shared_ptr<Layer> layer : layers) {
    for (const auto &[canvasName, canvas] : layer->canvases) {
      UnloadRenderTexture(canvas);
    }
  }
}

void AddCanvasToLayer(std::shared_ptr<Layer> layer, const std::string &name,
                      int width, int height) {
  // RenderTexture2D canvas = LoadRenderTexture(width, height);
  RenderTexture2D canvas = LoadRenderTextureStencilEnabled(width, height);
  layer->canvases[name] = canvas;
}

void AddCanvasToLayer(std::shared_ptr<Layer> layer, const std::string &name) {
  RenderTexture2D canvas =
      // LoadRenderTexture(globals::VIRTUAL_WIDTH, globals::VIRTUAL_HEIGHT);
      LoadRenderTextureStencilEnabled(globals::VIRTUAL_WIDTH,
                                      globals::VIRTUAL_HEIGHT);
  layer->canvases[name] = canvas;
}

void DrawCanvasOntoOtherLayerWithShader(
    const std::shared_ptr<Layer> &srcLayer, const std::string &srcCanvasName,
    const std::shared_ptr<Layer> &dstLayer, const std::string &dstCanvasName,
    float x, float y, float rotation, float scaleX, float scaleY,
    const Color &tint, std::string shaderName) {
  // PERF: Use find result directly instead of find + at (was double lookup)
  auto srcIt = srcLayer->canvases.find(srcCanvasName);
  if (srcIt == srcLayer->canvases.end())
    return;
  auto dstIt = dstLayer->canvases.find(dstCanvasName);
  if (dstIt == dstLayer->canvases.end())
    return;

  const RenderTexture2D &srcCanvas = srcIt->second;
  RenderTexture2D &dstCanvas = dstIt->second;

  BeginTextureMode(dstCanvas);

  ClearBackground(BLANK);

  Shader shader = shaders::getShader(shaderName);

  // Optional shader
  if (shader.id != 0) {
    BeginShaderMode(shader);

    // texture uniforms need to be set after beginShaderMode
    shaders::TryApplyUniforms(shader, globals::getGlobalShaderUniforms(),
                              shaderName);
  }

  DrawTexturePro(
      srcCanvas.texture,
      {0, 0, (float)srcCanvas.texture.width, (float)-srcCanvas.texture.height},
      {x, y, srcCanvas.texture.width * scaleX,
       srcCanvas.texture.height * scaleY},
      {0, 0}, rotation, tint);

  if (shader.id != 0)
    EndShaderMode();

  EndTextureMode();
}

void DrawCanvasOntoOtherLayer(const std::shared_ptr<Layer> &srcLayer,
                              const std::string &srcCanvasName,
                              const std::shared_ptr<Layer> &dstLayer,
                              const std::string &dstCanvasName, float x,
                              float y, float rotation, float scaleX,
                              float scaleY, const Color &tint) {
  // PERF: Use find result directly instead of find + at (was double lookup)
  auto srcIt = srcLayer->canvases.find(srcCanvasName);
  if (srcIt == srcLayer->canvases.end())
    return;
  auto dstIt = dstLayer->canvases.find(dstCanvasName);
  if (dstIt == dstLayer->canvases.end())
    return;

  RenderTexture2D src = srcIt->second;
  RenderTexture2D &dst = dstIt->second;

  BeginTextureMode(dst);

  DrawTexturePro(
      src.texture, {0, 0, (float)src.texture.width, (float)-src.texture.height},
      {x, y, src.texture.width * scaleX, src.texture.height * scaleY}, {0, 0},
      rotation, tint);

  EndTextureMode();
}

/**
 * @brief Draws all layer commands to a specific canvas and applies all
 * post-process shaders in sequence.
 *
 * This function first draws the layer's commands to the specified canvas using
 * an optimized version. If the layer has any post-process shaders, it ensures a
 * secondary "pong" render texture exists, then applies each shader in the
 * post-process chain by ping-ponging between the source and destination render
 * textures. After all shaders are applied, if the final result is not in the
 * original canvas, it copies the result back.
 *
 * @param layerPtr Shared pointer to the Layer object containing canvases and
 * shader information.
 * @param canvasName The name of the canvas to which the layer commands should
 * be drawn and shaders applied.
 * @param camera Pointer to the Camera2D object used for rendering.
 */
void DrawLayerCommandsToSpecificCanvasApplyAllShaders(
    std::shared_ptr<Layer> layerPtr, const std::string &canvasName,
    Camera2D *camera) {
  DrawLayerCommandsToSpecificCanvasOptimizedVersion(layerPtr, canvasName,
                                                    camera);

  // nothing to do if no post-shaders
  if (layerPtr->postProcessShaders.empty())
    return;

  // 2) Make sure your "ping" buffer exists:
  const std::string ping = canvasName;
  const std::string pong = canvasName + "_double";

  // First ensure ping canvas exists
  auto pingIt = layerPtr->canvases.find(ping);
  if (pingIt == layerPtr->canvases.end()) {
    SPDLOG_WARN("ApplyPostProcessShaders: ping canvas '{}' not found", ping);
    return;
  }

  if (layerPtr->canvases.find(pong) == layerPtr->canvases.end()) {
    // create it with same size as ping:
    auto &srcTex = pingIt->second;
    layerPtr->canvases[pong] =
        // LoadRenderTexture(srcTex.texture.width, srcTex.texture.height);
        LoadRenderTextureStencilEnabled(srcTex.texture.width,
                                        srcTex.texture.height);
  }

  // 3) Run the full-screen shader chain:
  std::string src = ping, dst = pong;
  for (auto &shaderName : layerPtr->postProcessShaders) {
    // clear dst - use operator[] since we know pong was just created
    auto dstIt = layerPtr->canvases.find(dst);
    if (dstIt == layerPtr->canvases.end()) continue;

    BeginTextureMode(dstIt->second);
    ClearBackground(BLANK);
    EndTextureMode();

    layer::DrawCanvasOntoOtherLayerWithShader(layerPtr, // src layer
                                              src,      // src canvas
                                              layerPtr, // dst layer
                                              dst,      // dst canvas
                                              0, 0, 0, 1,
                                              1, // x, y, rot, scaleX, scaleY
                                              WHITE, shaderName);
    std::swap(src, dst);
  }

  // 4) If the final result isn't back in "main", copy it home:
  if (src != canvasName) {
    auto canvasIt = layerPtr->canvases.find(canvasName);
    if (canvasIt == layerPtr->canvases.end()) return;

    // clear original ping
    BeginTextureMode(canvasIt->second);
    ClearBackground(BLANK);
    EndTextureMode();
    layer::DrawCanvasOntoOtherLayer(layerPtr, src, layerPtr, canvasName, 0, 0,
                                    0, 1, 1, WHITE);
  }
}

void DrawLayerCommandsToSpecificCanvasOptimizedVersion(
    std::shared_ptr<Layer> layer, const std::string &canvasName,
    Camera2D *camera) {
  // PERF: Use find result directly instead of find + operator[] (was double lookup)
  auto it = layer->canvases.find(canvasName);
  if (it == layer->canvases.end())
    return;

  render_stack_switch_internal::Push(it->second);

  ClearBackground(layer->backgroundColor);

  // if (!layer->fixed && camera)
  // {
  //     BeginMode2D(*camera);
  // }

  bool cameraActive = false;

  // Dispatch all draw commands from the arena-based command buffer
  for (const auto &command : layer_command_buffer::GetCommandsSorted(layer)) {
    // 2) Decide if this one wants the camera
    bool wantsCamera = (camera);

    // if (command.space == layer::DrawCommandSpace::World) {
    //     SPDLOG_DEBUG("Command {} wants camera in world space",
    //     magic_enum::enum_name(command.type));
    // } else {
    //     SPDLOG_DEBUG("Command {} does not want camera in screen space",
    //     magic_enum::enum_name(command.type));
    // }

    if (wantsCamera && command.space == layer::DrawCommandSpace::World &&
        !cameraActive) {
      camera_manager::Begin(
          *camera); // use camera manager to handle camera state so that draw
                    // command methods can know whether camera is active
      cameraActive = true;
      // SPDLOG_DEBUG("Command {} activating camera in world space",
      // magic_enum::enum_name(command.type));
    } else if (command.space == layer::DrawCommandSpace::Screen &&
               cameraActive) {
      camera_manager::End(); // use camera manager to handle camera state so
                             // that draw command methods can know whether
                             // camera is active
      cameraActive = false;
      // SPDLOG_DEBUG("Command {} deactivating camera in world space",
      // magic_enum::enum_name(command.type));
    }

    auto it = dispatcher.find(command.type);
    if (it != dispatcher.end()) {
      it->second(layer.get(), command.data);
      IncrementDrawCallStats(command.type);
    } else {
      SPDLOG_ERROR("Unhandled draw command type {}");
    }
  }

  // if (!layer->fixed && camera)
  // {
  //     EndMode2D();
  // }

  // ensure we leave the camera off
  if (cameraActive) {
    camera_manager::End();
  }

  render_stack_switch_internal::Pop();
}

void DrawLayerCommandsToSpecificCanvas(std::shared_ptr<Layer> layer,
                                       const std::string &canvasName,
                                       Camera2D *camera) {
  // PERF: Use find result directly instead of find + operator[] (was double lookup)
  auto it = layer->canvases.find(canvasName);
  if (it == layer->canvases.end())
    return;

  // SPDLOG_DEBUG("Drawing commands to canvas: {}", canvasName);

  render_stack_switch_internal::Push(it->second);

  // Clear the canvas with the background color
  ClearBackground(layer->backgroundColor);

  if (!layer->fixed && camera) {
    BeginMode2D(*camera);
  }

  // Sort draw commands by z before rendering
  // SortDrawCommands(layer); // FIXME: just render in order they were added

  using namespace snowhouse;

  for (const auto &command : layer->drawCommands) {
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
    else if (command.type == "translate") {
      AssertThat(command.args.size(),
                 Equals(2)); // Validate number of arguments
      float x = std::get<float>(command.args[0]);
      float y = std::get<float>(command.args[1]);
      layer::Translate(x, y);
    } else if (command.type == "scale") {
      AssertThat(command.args.size(),
                 Equals(2)); // Validate number of arguments
      float scaleX = std::get<float>(command.args[0]);
      float scaleY = std::get<float>(command.args[1]);
      AssertThat(scaleX,
                 IsGreaterThanOrEqualTo(0.0f)); // ScaleX must be positive
      AssertThat(scaleY,
                 IsGreaterThanOrEqualTo(0.0f)); // ScaleY must be positive
      layer::Scale(scaleX, scaleY);
    } else if (command.type == "rotate") {
      AssertThat(command.args.size(),
                 Equals(1)); // Validate number of arguments
      float angle = std::get<float>(command.args[0]);
      layer::Rotate(angle);
    } else if (command.type == "add_push") {
      AssertThat(command.args.size(),
                 Equals(1)); // Validate number of arguments
      Camera2D *camera = std::get<Camera2D *>(command.args[0]);

      layer::QueueCommand<layer::CmdAddPush>(
          layer, [camera](layer::CmdAddPush *cmd) { cmd->camera = camera; });
    } else if (command.type == "add_pop") {
      AssertThat(command.args.size(), Equals(0)); // Validate no arguments
      layer::Pop();
    } else if (command.type == "push_matrix") {
      AssertThat(command.args.size(), Equals(0)); // Validate no arguments
      layer::PushMatrix();
    } else if (command.type == "pop_matrix") {
      AssertThat(command.args.size(), Equals(0)); // Validate no arguments
      layer::PopMatrix();
    }

    // Shape Drawing
    else if (command.type == "circle") {
      AssertThat(command.args.size(),
                 Equals(4)); // Validate number of arguments
      float x = std::get<float>(command.args[0]);
      float y = std::get<float>(command.args[1]);
      float radius = std::get<float>(command.args[2]);
      Color color = std::get<Color>(command.args[3]);
      AssertThat(radius, IsGreaterThan(0.0f)); // Radius must be positive
      layer::Circle(x, y, radius, color);
    } else if (command.type == "rectangle") {
      AssertThat(command.args.size(),
                 Equals(6)); // Validate number of arguments
      float x = std::get<float>(command.args[0]);
      float y = std::get<float>(command.args[1]);
      float width = std::get<float>(command.args[2]);
      float height = std::get<float>(command.args[3]);
      Color color = std::get<Color>(command.args[4]);
      float lineWidth = std::get<float>(command.args[5]);
      AssertThat(width, IsGreaterThan(0.0f));  // Width must be positive
      AssertThat(height, IsGreaterThan(0.0f)); // Height must be positive
      layer::RectangleDraw(x, y, width, height, color, lineWidth);
    } else if (command.type == "rectanglePro") {
      AssertThat(command.args.size(),
                 Equals(6)); // Validate number of arguments
      float offsetX = std::get<float>(command.args[0]);
      float offsetY = std::get<float>(command.args[1]);
      Vector2 size = std::get<Vector2>(command.args[2]);
      Vector2 rotationCenter = std::get<Vector2>(command.args[3]);
      float rotation = std::get<float>(command.args[4]);
      Color color = std::get<Color>(command.args[5]);
      layer::RectanglePro(offsetX, offsetY, size, rotationCenter, rotation,
                          color);
    } else if (command.type == "rectangleLinesPro") {
      AssertThat(command.args.size(),
                 Equals(5)); // Validate number of arguments
      float offsetX = std::get<float>(command.args[0]);
      float offsetY = std::get<float>(command.args[1]);
      Vector2 size = std::get<Vector2>(command.args[2]);
      float lineThickness = std::get<float>(command.args[3]);
      Color color = std::get<Color>(command.args[4]);
      layer::RectangleLinesPro(offsetX, offsetY, size, lineThickness, color);
    } else if (command.type == "line") {
      AssertThat(command.args.size(),
                 Equals(6)); // Validate number of arguments
      float x1 = std::get<float>(command.args[0]);
      float y1 = std::get<float>(command.args[1]);
      float x2 = std::get<float>(command.args[2]);
      float y2 = std::get<float>(command.args[3]);
      Color color = std::get<Color>(command.args[4]);
      float lineWidth = std::get<float>(command.args[5]);
      AssertThat(lineWidth, IsGreaterThan(0.0f)); // Line width must be positive
      layer::Line(x1, y1, x2, y2, color, lineWidth);
    } else if (command.type == "dashed_line") {
      AssertThat(command.args.size(),
                 Equals(8)); // Validate number of arguments
      float x1 = std::get<float>(command.args[0]);
      float y1 = std::get<float>(command.args[1]);
      float x2 = std::get<float>(command.args[2]);
      float y2 = std::get<float>(command.args[3]);
      float dashSize = std::get<float>(command.args[4]);
      float gapSize = std::get<float>(command.args[5]);
      Color color = std::get<Color>(command.args[6]);
      float lineWidth = std::get<float>(command.args[7]);
      AssertThat(dashSize, IsGreaterThan(0.0f));  // Dash size must be positive
      AssertThat(gapSize, IsGreaterThan(0.0f));   // Gap size must be positive
      AssertThat(lineWidth, IsGreaterThan(0.0f)); // Line width must be positive
      layer::DashedLine(x1, y1, x2, y2, dashSize, gapSize, color, lineWidth);
    }

    // Text Rendering
    else if (command.type == "text") {
      AssertThat(command.args.size(),
                 Equals(6)); // Validate number of arguments
      std::string text = std::get<std::string>(command.args[0]);
      Font font = std::get<Font>(command.args[1]);
      float x = std::get<float>(command.args[2]);
      float y = std::get<float>(command.args[3]);
      Color color = std::get<Color>(command.args[4]);
      float fontSize = std::get<float>(command.args[5]);
      // AssertThat(fontSize, IsGreaterThan(0.0f)); // Font size must be
      // positive
      layer::Text(text, font, x, y, color, fontSize);
    } else if (command.type == "draw_text_centered") {
      AssertThat(command.args.size(),
                 Equals(6)); // Validate number of arguments
      std::string text = std::get<std::string>(command.args[0]);
      Font font = std::get<Font>(command.args[1]);
      float x = std::get<float>(command.args[2]);
      float y = std::get<float>(command.args[3]);
      Color color = std::get<Color>(command.args[4]);
      float fontSize = std::get<float>(command.args[5]);
      AssertThat(fontSize, IsGreaterThan(0.0f)); // Font size must be positive
      layer::DrawTextCentered(text, font, x, y, color, fontSize);
    } else if (command.type == "textPro") {
      AssertThat(command.args.size(),
                 Equals(9)); // Validate number of arguments
      std::string text = std::get<std::string>(command.args[0]);
      Font font = std::get<Font>(command.args[1]);
      float x = std::get<float>(command.args[2]);
      float y = std::get<float>(command.args[3]);
      Vector2 origin = std::get<Vector2>(command.args[4]);
      float rotation = std::get<float>(command.args[5]);
      float fontSize = std::get<float>(command.args[6]);
      float spacing = std::get<float>(command.args[7]);
      Color color = std::get<Color>(command.args[8]);
      // AssertThat(fontSize, IsGreaterThan(0.0f)); // Font size must be
      // positive
      AssertThat(spacing, IsGreaterThan(0.0f)); // Spacing must be positive
      layer::TextPro(text, font, x, y, origin, rotation, fontSize, spacing,
                     color);
    }

    // Drawing Commands
    else if (command.type == "draw_image") {
      AssertThat(command.args.size(),
                 Equals(7)); // Validate number of arguments
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
    } else if (command.type == "texturePro") {
      AssertThat(command.args.size(),
                 Equals(8)); // Validate number of arguments
      Texture2D texture = std::get<Texture2D>(command.args[0]);
      struct Rectangle source = std::get<struct Rectangle>(command.args[1]);
      float offsetX = std::get<float>(command.args[2]);
      float offsetY = std::get<float>(command.args[3]);
      Vector2 size = std::get<Vector2>(command.args[4]);
      Vector2 rotationCenter = std::get<Vector2>(command.args[5]);
      float rotation = std::get<float>(command.args[6]);
      Color color = std::get<Color>(command.args[7]);
      layer::TexturePro(texture, source, offsetX, offsetY, size, rotationCenter,
                        rotation, color);
    } else if (command.type == "draw_entity_animation") {
      AssertThat(command.args.size(),
                 Equals(4)); // Validate number of arguments
      entt::entity e = std::get<entt::entity>(command.args[0]);
      entt::registry *registry = std::get<entt::registry *>(command.args[1]);
      int x = std::get<int>(command.args[2]);
      int y = std::get<int>(command.args[3]);
      layer::DrawEntityWithAnimation(*registry, e, x, y);
    } else if (command.type == "draw_transform_entity_animation") {
      AssertThat(command.args.size(),
                 Equals(2)); // Validate number of arguments
      entt::entity e = std::get<entt::entity>(command.args[0]);
      entt::registry *registry = std::get<entt::registry *>(command.args[1]);
      layer::DrawTransformEntityWithAnimation(*registry, e);
    } else if (command.type == "draw_transform_entity_animation_pipeline") {
      AssertThat(command.args.size(),
                 Equals(2)); // Validate number of arguments
      entt::entity e = std::get<entt::entity>(command.args[0]);
      entt::registry *registry = std::get<entt::registry *>(command.args[1]);
      layer::DrawTransformEntityWithAnimationWithPipeline(*registry, e);
    }
    // Shader Commands
    else if (command.type == "set_shader") {
      AssertThat(command.args.size(),
                 Equals(1)); // Validate number of arguments
      Shader shader = std::get<Shader>(command.args[0]);
      layer::SetShader(shader);
    } else if (command.type == "reset_shader") {
      AssertThat(command.args.size(), Equals(0)); // Validate no arguments
      layer::ResetShader();
    } else if (command.type == "set_blend_mode") {
      AssertThat(command.args.size(),
                 Equals(1)); // Validate number of arguments
      int blendMode = std::get<int>(command.args[0]);
      AssertThat(blendMode,
                 IsGreaterThanOrEqualTo(0)); // BlendMode must be valid
      AssertThat(blendMode,
                 IsLessThanOrEqualTo(4)); // Assuming 0-4 are valid blend modes
      layer::SetBlendMode(blendMode);
    } else if (command.type == "unset_blend_mode") {

      layer::UnsetBlendMode();
    } else if (command.type == "send_uniform_float") {
      AssertThat(command.args.size(), Equals(3)); // Validate arguments
      Shader shader = std::get<Shader>(command.args[0]);
      std::string uniform = std::get<std::string>(command.args[1]);
      float value = std::get<float>(command.args[2]);
      AssertThat(uniform.empty(), IsFalse()); // Uniform name must not be empty
      SendUniformFloat(shader, uniform, value);
    } else if (command.type == "send_uniform_int") {
      AssertThat(command.args.size(), Equals(3));
      Shader shader = std::get<Shader>(command.args[0]);
      std::string uniform = std::get<std::string>(command.args[1]);
      int value = std::get<int>(command.args[2]);
      AssertThat(uniform.empty(), IsFalse());
      SendUniformInt(shader, uniform, value);
    } else if (command.type == "send_uniform_vec2") {
      AssertThat(command.args.size(), Equals(3));
      Shader shader = std::get<Shader>(command.args[0]);
      std::string uniform = std::get<std::string>(command.args[1]);
      Vector2 value = std::get<Vector2>(command.args[2]);
      AssertThat(uniform.empty(), IsFalse());
      SendUniformVector2(shader, uniform, value);
    } else if (command.type == "send_uniform_vec3") {
      AssertThat(command.args.size(), Equals(3));
      Shader shader = std::get<Shader>(command.args[0]);
      std::string uniform = std::get<std::string>(command.args[1]);
      Vector3 value = std::get<Vector3>(command.args[2]);
      AssertThat(uniform.empty(), IsFalse());
      SendUniformVector3(shader, uniform, value);
    } else if (command.type == "send_uniform_vec4") {
      AssertThat(command.args.size(), Equals(3));
      Shader shader = std::get<Shader>(command.args[0]);
      std::string uniform = std::get<std::string>(command.args[1]);
      Vector4 value = std::get<Vector4>(command.args[2]);
      AssertThat(uniform.empty(), IsFalse());
      SendUniformVector4(shader, uniform, value);
    } else if (command.type == "send_uniform_float_array") {
      AssertThat(command.args.size(), Equals(3));
      Shader shader = std::get<Shader>(command.args[0]);
      std::string uniform = std::get<std::string>(command.args[1]);
      std::vector<float> values = std::get<std::vector<float>>(command.args[2]);
      AssertThat(uniform.empty(), IsFalse());
      SendUniformFloatArray(shader, uniform, values.data(), values.size());
    } else if (command.type == "send_uniform_int_array") {
      AssertThat(command.args.size(), Equals(3));
      Shader shader = std::get<Shader>(command.args[0]);
      std::string uniform = std::get<std::string>(command.args[1]);
      std::vector<int> values = std::get<std::vector<int>>(command.args[2]);
      AssertThat(uniform.empty(), IsFalse());
      SendUniformIntArray(shader, uniform, values.data(), values.size());
    } else if (command.type == "vertex") {
      AssertThat(command.args.size(), Equals(2));
      Vector2 v = std::get<Vector2>(command.args[0]);
      Color color = std::get<Color>(command.args[1]);
      Vertex(v, color);
    } else if (command.type == "begin_mode") {
      AssertThat(command.args.size(), Equals(1));
      int mode = std::get<int>(command.args[0]);
      BeginRLMode(mode);
    } else if (command.type == "end_mode") {
      EndRLMode();
    } else if (command.type == "set_color") {
      AssertThat(command.args.size(), Equals(1));
      Color color = std::get<Color>(command.args[0]);
      SetColor(color);
    } else if (command.type == "set_line_width") {
      AssertThat(command.args.size(), Equals(1));
      float lineWidth = std::get<float>(command.args[0]);
      SetLineWidth(lineWidth);
    } else if (command.type == "set_texture") {
      AssertThat(command.args.size(), Equals(1));
      Texture2D texture = std::get<Texture2D>(command.args[0]);
      SetRLTexture(texture);
    } else if (command.type == "render_rect_vertices_filled_layer") {
      AssertThat(command.args.size(), Equals(4));
      Rectangle outerRec = std::get<Rectangle>(command.args[0]);
      bool progressOrFullBackground = std::get<bool>(command.args[1]);
      entt::entity cache = std::get<entt::entity>(command.args[2]);
      Color color = std::get<Color>(command.args[3]);
      RenderRectVerticesFilledLayer(layer.get(), outerRec, progressOrFullBackground,
                                    cache, color);
    } else if (command.type == "render_rect_verticles_outline_layer") {
      AssertThat(command.args.size(), Equals(3));
      entt::entity cache = std::get<entt::entity>(command.args[0]);
      Color color = std::get<Color>(command.args[1]);
      bool useFullVertices = std::get<bool>(command.args[2]);
      RenderRectVerticlesOutlineLayer(layer.get(), cache, color, useFullVertices);
    } else if (command.type == "polygon") {
      AssertThat(command.args.size(), Equals(3));
      std::vector<Vector2> vertices =
          std::get<std::vector<Vector2>>(command.args[0]);
      Color color = std::get<Color>(command.args[1]);
      float lineWidth = std::get<float>(command.args[2]);
      layer::Polygon(vertices, color, lineWidth);
    } else if (command.type == "circle") {
      AssertThat(command.args.size(), Equals(4));
      float x = std::get<float>(command.args[0]);
      float y = std::get<float>(command.args[1]);
      float radius = std::get<float>(command.args[2]);
      Color color = std::get<Color>(command.args[3]);
      layer::Circle(x, y, radius, color);
    } else if (command.type == "render_npatch") {
      AssertThat(command.args.size(), Equals(6));
      Texture2D sourceTexture = std::get<Texture2D>(command.args[0]);
      NPatchInfo info = std::get<NPatchInfo>(command.args[1]);
      Rectangle dest = std::get<Rectangle>(command.args[2]);
      Vector2 origin = std::get<Vector2>(command.args[3]);
      float rotation = std::get<float>(command.args[4]);
      Color tint = std::get<Color>(command.args[5]);
      layer::RenderNPatchRect(sourceTexture, info, dest, origin, rotation,
                              tint);
    } else if (command.type == "triangle") {
      AssertThat(command.args.size(), Equals(4));
      Vector2 p1 = std::get<Vector2>(command.args[0]);
      Vector2 p2 = std::get<Vector2>(command.args[1]);
      Vector2 p3 = std::get<Vector2>(command.args[2]);
      Color color = std::get<Color>(command.args[3]);
      layer::Triangle(p1, p2, p3, color);
    }
    // Fallback for undefined commands
    else {
      throw std::runtime_error("Undefined draw command: " + command.type);
    }
  }

  if (!layer->fixed && camera) {
    EndMode2D();
  }

  // EndTextureMode();
  render_stack_switch_internal::Pop();
}

void AddSetColor(std::shared_ptr<Layer> layer, const Color &color, int z) {
  AddDrawCommand(layer, "set_color", {color}, z);
}

void SetColor(const Color &color) {
  rlColor4ub(color.r, color.g, color.b, color.a);
}

void AddSetLineWidth(std::shared_ptr<Layer> layer, float lineWidth, int z) {
  AddDrawCommand(layer, "set_line_width", {lineWidth}, z);
}

void SetLineWidth(float lineWidth) { rlSetLineWidth(lineWidth); }

void Vertex(Vector2 v, Color color) {
  rlColor4ub(color.r, color.g, color.b, color.a);
  rlVertex2f(v.x, v.y);
}

void AddVertex(std::shared_ptr<Layer> layer, Vector2 v, Color color, int z) {
  AddDrawCommand(layer, "vertex", {v, color}, z);
}

void AddCircle(std::shared_ptr<Layer> layer, float x, float y, float radius,
               Color color, int z) {
  AddDrawCommand(layer, "circle", {x, y, radius, color}, z);
}

void SetRLTexture(Texture2D texture) { rlSetTexture(texture.id); }

void AddSetRLTexture(std::shared_ptr<Layer> layer, Texture2D texture, int z) {
  AddDrawCommand(layer, "set_texture", {texture}, z);
}

void BeginRLMode(int mode) { rlBegin(mode); }

void AddBeginRLMode(std::shared_ptr<Layer> layer, int mode, int z) {
  AddDrawCommand(layer, "begin_mode", {mode}, z);
}

void EndRLMode() { rlEnd(); }

void AddEndRLMode(std::shared_ptr<Layer> layer, int z) {
  AddDrawCommand(layer, "end_mode", {}, z);
}

void AddRenderNPatchRect(std::shared_ptr<Layer> layer, Texture2D sourceTexture,
                         const NPatchInfo &info, const Rectangle &dest,
                         const Vector2 &origin, float rotation,
                         const Color &tint, int z) {
  AddDrawCommand(layer, "render_npatch",
                 {sourceTexture, info, dest, origin, rotation, tint}, z);
}

void RenderNPatchRect(Texture2D sourceTexture, NPatchInfo info, Rectangle dest,
                      Vector2 origin, float rotation, Color tint) {
  DrawTextureNPatch(sourceTexture, info, dest, origin, rotation, tint);
}

void AddRenderRectVerticesFilledLayer(std::shared_ptr<Layer> layerPtr,
                                      const Rectangle outerRec,
                                      bool progressOrFullBackground,
                                      entt::entity cacheEntity,
                                      const Color color, int z) {
  AddDrawCommand(layerPtr, "render_rect_vertices_filled_layer",
                 {outerRec, progressOrFullBackground, cacheEntity, color}, z);
}

void DrawGradientRectCentered(float cx, float cy, float width, float height,
                              Color topLeft, Color topRight, Color bottomRight,
                              Color bottomLeft) {
  float x = cx - width / 2.0f;
  float y = cy - height / 2.0f;

  rlBegin(RL_QUADS);
  rlColor4ub(topLeft.r, topLeft.g, topLeft.b, topLeft.a);
  rlVertex2f(x, y);

  rlColor4ub(topRight.r, topRight.g, topRight.b, topRight.a);
  rlVertex2f(x + width, y);

  rlColor4ub(bottomRight.r, bottomRight.g, bottomRight.b, bottomRight.a);
  rlVertex2f(x + width, y + height);

  rlColor4ub(bottomLeft.r, bottomLeft.g, bottomLeft.b, bottomLeft.a);
  rlVertex2f(x, y + height);
  rlEnd();
}

void DrawRectangleRoundedGradientH(Rectangle rec, float roundnessLeft,
                                   float roundnessRight, int segments,
                                   Color left, Color right) {
  // Neither side is rounded
  if ((roundnessLeft <= 0.0f && roundnessRight <= 0.0f) || (rec.width < 1) ||
      (rec.height < 1)) {
    DrawRectangleGradientEx(rec, left, left, right, right);
    return;
  }

  if (roundnessLeft >= 1.0f)
    roundnessLeft = 1.0f;
  if (roundnessRight >= 1.0f)
    roundnessRight = 1.0f;

  // Calculate corner radius both from right and left
  float recSize = rec.width > rec.height ? rec.height : rec.width;
  float radiusLeft = (recSize * roundnessLeft) / 2;
  float radiusRight = (recSize * roundnessRight) / 2;

  if (radiusLeft <= 0.0f)
    radiusLeft = 0.0f;
  if (radiusRight <= 0.0f)
    radiusRight = 0.0f;

  if (radiusRight <= 0.0f && radiusLeft <= 0.0f)
    return;

  float stepLength = 90.0f / (float)segments;

  /*
  Diagram Copied here for reference, original at 'DrawRectangleRounded()' source
  code

        P0____________________P1
        /|                    |\
       /1|          2         |3\
   P7 /__|____________________|__\ P2
     |   |P8                P9|   |
     | 8 |          9         | 4 |
     | __|____________________|__ |
   P6 \  |P11              P10|  / P3
       \7|          6         |5/
        \|____________________|/
        P5                    P4
  */

  // Coordinates of the 12 points also apdated from `DrawRectangleRounded`
  const Vector2 point[12] = {
      // PO, P1, P2
      {(float)rec.x + radiusLeft, rec.y},
      {(float)(rec.x + rec.width) - radiusRight, rec.y},
      {rec.x + rec.width, (float)rec.y + radiusRight},
      // P3, P4
      {rec.x + rec.width, (float)(rec.y + rec.height) - radiusRight},
      {(float)(rec.x + rec.width) - radiusRight, rec.y + rec.height},
      // P5, P6, P7
      {(float)rec.x + radiusLeft, rec.y + rec.height},
      {rec.x, (float)(rec.y + rec.height) - radiusLeft},
      {rec.x, (float)rec.y + radiusLeft},
      // P8, P9
      {(float)rec.x + radiusLeft, (float)rec.y + radiusLeft},
      {(float)(rec.x + rec.width) - radiusRight, (float)rec.y + radiusRight},
      // P10, P11
      {(float)(rec.x + rec.width) - radiusRight,
       (float)(rec.y + rec.height) - radiusRight},
      {(float)rec.x + radiusLeft, (float)(rec.y + rec.height) - radiusLeft}};

  const Vector2 centers[4] = {point[8], point[9], point[10], point[11]};
  const float angles[4] = {180.0f, 270.0f, 0.0f, 90.0f};

#if defined(SUPPORT_QUADS_DRAW_MODE)
  rlSetTexture(GetShapesTexture().id);
  Rectangle shapeRect = GetShapesTextureRectangle();

  rlBegin(RL_QUADS);
  // Draw all the 4 corners: [1] Upper Left Corner, [3] Upper Right Corner, [5]
  // Lower Right Corner, [7] Lower Left Corner
  for (int k = 0; k < 4; ++k) {
    Color color;
    float radius;
    if (k == 0)
      color = left, radius = radiusLeft; // [1] Upper Left Corner
    if (k == 1)
      color = right, radius = radiusRight; // [3] Upper Right Corner
    if (k == 2)
      color = right, radius = radiusRight; // [5] Lower Right Corner
    if (k == 3)
      color = left, radius = radiusLeft; // [7] Lower Left Corner
    float angle = angles[k];
    const Vector2 center = centers[k];

    for (int i = 0; i < segments / 2; i++) {
      rlColor4ub(color.r, color.g, color.b, color.a);
      rlTexCoord2f(shapeRect.x / texShapes.width,
                   shapeRect.y / texShapes.height);
      rlVertex2f(center.x, center.y);

      rlTexCoord2f((shapeRect.x + shapeRect.width) / texShapes.width,
                   shapeRect.y / texShapes.height);
      rlVertex2f(center.x + cosf(DEG2RAD * (angle + stepLength * 2)) * radius,
                 center.y + sinf(DEG2RAD * (angle + stepLength * 2)) * radius);

      rlTexCoord2f((shapeRect.x + shapeRect.width) / texShapes.width,
                   (shapeRect.y + shapeRect.height) / texShapes.height);
      rlVertex2f(center.x + cosf(DEG2RAD * (angle + stepLength)) * radius,
                 center.y + sinf(DEG2RAD * (angle + stepLength)) * radius);

      rlTexCoord2f(shapeRect.x / texShapes.width,
                   (shapeRect.y + shapeRect.height) / texShapes.height);
      rlVertex2f(center.x + cosf(DEG2RAD * angle) * radius,
                 center.y + sinf(DEG2RAD * angle) * radius);

      angle += (stepLength * 2);
    }

    // End one even segments
    if (segments % 2) {
      rlTexCoord2f(shapeRect.x / texShapes.width,
                   shapeRect.y / texShapes.height);
      rlVertex2f(center.x, center.y);

      rlTexCoord2f((shapeRect.x + shapeRect.width) / texShapes.width,
                   (shapeRect.y + shapeRect.height) / texShapes.height);
      rlVertex2f(center.x + cosf(DEG2RAD * (angle + stepLength)) * radius,
                 center.y + sinf(DEG2RAD * (angle + stepLength)) * radius);

      rlTexCoord2f(shapeRect.x / texShapes.width,
                   (shapeRect.y + shapeRect.height) / texShapes.height);
      rlVertex2f(center.x + cosf(DEG2RAD * angle) * radius,
                 center.y + sinf(DEG2RAD * angle) * radius);

      rlTexCoord2f((shapeRect.x + shapeRect.width) / texShapes.width,
                   shapeRect.y / texShapes.height);
      rlVertex2f(center.x, center.y);
    }
  }

  // Here we use the 'Diagram' to guide ourselves to which point receives what
  // color By choosing the color correctly associated with a pointe the gradient
  // effect will naturally come from OpenGL interpolation

  // [2] Upper Rectangle
  rlColor4ub(left.r, left.g, left.b, left.a);
  rlTexCoord2f(shapeRect.x / texShapes.width, shapeRect.y / texShapes.height);
  rlVertex2f(point[0].x, point[0].y);
  rlTexCoord2f(shapeRect.x / texShapes.width,
               (shapeRect.y + shapeRect.height) / texShapes.height);
  rlVertex2f(point[8].x, point[8].y);

  rlColor4ub(right.r, right.g, right.b, right.a);
  rlTexCoord2f((shapeRect.x + shapeRect.width) / texShapes.width,
               (shapeRect.y + shapeRect.height) / texShapes.height);
  rlVertex2f(point[9].x, point[9].y);

  rlColor4ub(right.r, right.g, right.b, right.a);
  rlTexCoord2f((shapeRect.x + shapeRect.width) / texShapes.width,
               shapeRect.y / texShapes.height);
  rlVertex2f(point[1].x, point[1].y);

  // [4] Left Rectangle
  rlColor4ub(right.r, right.g, right.b, right.a);
  rlTexCoord2f(shapeRect.x / texShapes.width, shapeRect.y / texShapes.height);
  rlVertex2f(point[2].x, point[2].y);
  rlTexCoord2f(shapeRect.x / texShapes.width,
               (shapeRect.y + shapeRect.height) / texShapes.height);
  rlVertex2f(point[9].x, point[9].y);
  rlTexCoord2f((shapeRect.x + shapeRect.width) / texShapes.width,
               (shapeRect.y + shapeRect.height) / texShapes.height);
  rlVertex2f(point[10].x, point[10].y);
  rlTexCoord2f((shapeRect.x + shapeRect.width) / texShapes.width,
               shapeRect.y / texShapes.height);
  rlVertex2f(point[3].x, point[3].y);

  // [6] Bottom Rectangle
  rlColor4ub(left.r, left.g, left.b, left.a);
  rlTexCoord2f(shapeRect.x / texShapes.width, shapeRect.y / texShapes.height);
  rlVertex2f(point[11].x, point[11].y);
  rlTexCoord2f(shapeRect.x / texShapes.width,
               (shapeRect.y + shapeRect.height) / texShapes.height);
  rlVertex2f(point[5].x, point[5].y);

  rlColor4ub(right.r, right.g, right.b, right.a);
  rlTexCoord2f((shapeRect.x + shapeRect.width) / texShapes.width,
               (shapeRect.y + shapeRect.height) / texShapes.height);
  rlVertex2f(point[4].x, point[4].y);
  rlTexCoord2f((shapeRect.x + shapeRect.width) / texShapes.width,
               shapeRect.y / texShapes.height);
  rlVertex2f(point[10].x, point[10].y);

  // [8] left Rectangle
  rlColor4ub(left.r, left.g, left.b, left.a);
  rlTexCoord2f(shapeRect.x / texShapes.width, shapeRect.y / texShapes.height);
  rlVertex2f(point[7].x, point[7].y);
  rlTexCoord2f(shapeRect.x / texShapes.width,
               (shapeRect.y + shapeRect.height) / texShapes.height);
  rlVertex2f(point[6].x, point[6].y);
  rlTexCoord2f((shapeRect.x + shapeRect.width) / texShapes.width,
               (shapeRect.y + shapeRect.height) / texShapes.height);
  rlVertex2f(point[11].x, point[11].y);
  rlTexCoord2f((shapeRect.x + shapeRect.width) / texShapes.width,
               shapeRect.y / texShapes.height);
  rlVertex2f(point[8].x, point[8].y);

  // [9] Middle Rectangle
  rlColor4ub(left.r, left.g, left.b, left.a);
  rlTexCoord2f(shapeRect.x / texShapes.width, shapeRect.y / texShapes.height);
  rlVertex2f(point[8].x, point[8].y);
  rlTexCoord2f(shapeRect.x / texShapes.width,
               (shapeRect.y + shapeRect.height) / texShapes.height);
  rlVertex2f(point[11].x, point[11].y);

  rlColor4ub(right.r, right.g, right.b, right.a);
  rlTexCoord2f((shapeRect.x + shapeRect.width) / texShapes.width,
               (shapeRect.y + shapeRect.height) / texShapes.height);
  rlVertex2f(point[10].x, point[10].y);
  rlTexCoord2f((shapeRect.x + shapeRect.width) / texShapes.width,
               shapeRect.y / texShapes.height);
  rlVertex2f(point[9].x, point[9].y);

  rlEnd();
  rlSetTexture(0);
#else

  // Here we use the 'Diagram' to guide ourselves to which point receives what
  // color By choosing the color correctly associated with a pointe the gradient
  // effect will naturally come from OpenGL interpolation But this time instead
  // of Quad, we think in triangles

  rlBegin(RL_TRIANGLES);
  // Draw all of the 4 corners: [1] Upper Left Corner, [3] Upper Right Corner,
  // [5] Lower Right Corner, [7] Lower Left Corner
  for (int k = 0; k < 4; ++k) {
    Color color = {0};
    float radius = 0.0f;
    if (k == 0)
      color = left, radius = radiusLeft; // [1] Upper Left Corner
    if (k == 1)
      color = right, radius = radiusRight; // [3] Upper Right Corner
    if (k == 2)
      color = right, radius = radiusRight; // [5] Lower Right Corner
    if (k == 3)
      color = left, radius = radiusLeft; // [7] Lower Left Corner

    float angle = angles[k];
    const Vector2 center = centers[k];

    for (int i = 0; i < segments; i++) {
      rlColor4ub(color.r, color.g, color.b, color.a);
      rlVertex2f(center.x, center.y);
      rlVertex2f(center.x + cosf(DEG2RAD * (angle + stepLength)) * radius,
                 center.y + sinf(DEG2RAD * (angle + stepLength)) * radius);
      rlVertex2f(center.x + cosf(DEG2RAD * angle) * radius,
                 center.y + sinf(DEG2RAD * angle) * radius);
      angle += stepLength;
    }
  }

  // [2] Upper Rectangle
  rlColor4ub(left.r, left.g, left.b, left.a);
  rlVertex2f(point[0].x, point[0].y);
  rlVertex2f(point[8].x, point[8].y);
  rlColor4ub(right.r, right.g, right.b, right.a);
  rlVertex2f(point[9].x, point[9].y);
  rlVertex2f(point[1].x, point[1].y);
  rlColor4ub(left.r, left.g, left.b, left.a);
  rlVertex2f(point[0].x, point[0].y);
  rlColor4ub(right.r, right.g, right.b, right.a);
  rlVertex2f(point[9].x, point[9].y);

  // [4] Right Rectangle
  rlColor4ub(right.r, right.g, right.b, right.a);
  rlVertex2f(point[9].x, point[9].y);
  rlVertex2f(point[10].x, point[10].y);
  rlVertex2f(point[3].x, point[3].y);
  rlVertex2f(point[2].x, point[2].y);
  rlVertex2f(point[9].x, point[9].y);
  rlVertex2f(point[3].x, point[3].y);

  // [6] Bottom Rectangle
  rlColor4ub(left.r, left.g, left.b, left.a);
  rlVertex2f(point[11].x, point[11].y);
  rlVertex2f(point[5].x, point[5].y);
  rlColor4ub(right.r, right.g, right.b, right.a);
  rlVertex2f(point[4].x, point[4].y);
  rlVertex2f(point[10].x, point[10].y);
  rlColor4ub(left.r, left.g, left.b, left.a);
  rlVertex2f(point[11].x, point[11].y);
  rlColor4ub(right.r, right.g, right.b, right.a);
  rlVertex2f(point[4].x, point[4].y);

  // [8] Left Rectangle
  rlColor4ub(left.r, left.g, left.b, left.a);
  rlVertex2f(point[7].x, point[7].y);
  rlVertex2f(point[6].x, point[6].y);
  rlVertex2f(point[11].x, point[11].y);
  rlVertex2f(point[8].x, point[8].y);
  rlVertex2f(point[7].x, point[7].y);
  rlVertex2f(point[11].x, point[11].y);

  // [9] Middle Rectangle
  rlColor4ub(left.r, left.g, left.b, left.a);
  rlVertex2f(point[8].x, point[8].y);
  rlVertex2f(point[11].x, point[11].y);
  rlColor4ub(right.r, right.g, right.b, right.a);
  rlVertex2f(point[10].x, point[10].y);
  rlVertex2f(point[9].x, point[9].y);
  rlColor4ub(left.r, left.g, left.b, left.a);
  rlVertex2f(point[8].x, point[8].y);
  rlColor4ub(right.r, right.g, right.b, right.a);
  rlVertex2f(point[10].x, point[10].y);
  rlEnd();
#endif
}

void DrawGradientRectRoundedCentered(
    float cx, float cy, float width, float height, float roundness,
    int segments, Color top, Color bottom, Color,
    Color) // unused last two color params, for signature compatibility
{
  if (width <= 0.0f || height <= 0.0f)
    return;

  Rectangle rec = {cx - width * 0.5f, cy - height * 0.5f, width, height};

  rlPushMatrix();

  // Move to center of rectangle before rotation
  rlTranslatef(cx, cy, 0.0f);

  // Rotate -90° CCW so horizontal gradient becomes vertical (top→bottom)
  rlRotatef(-90.0f, 0.0f, 0.0f, 1.0f);

  // Adjust rectangle to rotated coordinate system (centered again)
  Rectangle rotated = {-height * 0.5f, // new x (since rotated)
                       -width * 0.5f,  // new y
                       height,         // swapped width/height
                       width};

  // Reuse existing horizontal version safely
  DrawRectangleRoundedGradientH(rotated, roundness, roundness, segments, top,
                                bottom);

  rlPopMatrix();
}

void RenderRectVerticesFilledLayer(Layer* layerPtr,
                                   const Rectangle outerRec,
                                   bool progressOrFullBackground,
                                   entt::entity cacheEntity,
                                   const Color color) {

  auto &cache = globals::getRegistry().get<ui::RoundedRectangleVerticesCache>(
      cacheEntity);

  auto &outerVertices = progressOrFullBackground
                            ? cache.outerVerticesProgressReflected
                            : cache.outerVerticesFullRect;

  rlColor4ub(255, 255, 255, 255); // Reset to white before each draw
  rlSetTexture(0);
  rlDisableDepthTest(); // Disable depth testing for 2D rendering
  // rlEnableDepthTest();
  rlDisableColorBlend(); // Disable color blending for solid color
  rlEnableColorBlend();  // Enable color blending for textures
  rlBegin(RL_TRIANGLES);
  rlSetBlendMode(rlBlendMode::RL_BLEND_ALPHA);

  // Center of the entire rectangle (for filling)
  Vector2 center = {outerRec.x + outerRec.width / 2.0f,
                    outerRec.y + outerRec.height / 2.0f};
  // SPDLOG_DEBUG("RenderRectVerticesFilledLayer > Center: x: {}, y: {}",
  // center.x, center.y);

  // Fill using the **outer vertices** and the **center**
  for (size_t i = 0; i < outerVertices.size(); i += 2) {
    // each triangle is 3 verts
    if (rlCheckRenderBatchLimit(3)) {
      rlEnd();
      rlDrawRenderBatchActive(); // push what you have
      rlBegin(RL_TRIANGLES);     // start a new batch
    }

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

void AddRenderRectVerticlesOutlineLayer(std::shared_ptr<Layer> layer,
                                        entt::entity cacheEntity,
                                        const Color color, bool useFullVertices,
                                        int z) {
  AddDrawCommand(layer, "render_rect_verticles_outline_layer",
                 {cacheEntity, color, useFullVertices}, z);
}

void RenderRectVerticlesOutlineLayer(Layer* layerPtr,
                                     entt::entity cacheEntity,
                                     const Color color, bool useFullVertices) {

  auto &cache = globals::getRegistry().get<ui::RoundedRectangleVerticesCache>(
      cacheEntity);
  auto &innerVertices = (useFullVertices)
                            ? cache.innerVerticesFullRect
                            : cache.innerVerticesProgressReflected;
  auto &outerVertices = (useFullVertices)
                            ? cache.outerVerticesFullRect
                            : cache.outerVerticesProgressReflected;

  // Draw the outlines
  // Draw the filled outline
  rlDisableDepthTest(); // Disable depth testing for 2D rendering
  // rlEnableDepthTest();
  rlColor4ub(255, 255, 255, 255); // Reset to white before each draw
  rlSetTexture(0);
  rlDisableColorBlend(); // Disable color blending for solid color
  rlEnableColorBlend();  // Enable color blending for textures
  rlBegin(RL_TRIANGLES);
  rlSetBlendMode(rlBlendMode::RL_BLEND_ALPHA);

  // Draw quads between outer and inner outlines using two triangles each
  for (size_t i = 0; i < outerVertices.size(); i += 2) {
    // each triangle is 3 verts
    if (rlCheckRenderBatchLimit(3)) {
      rlEnd();
      rlDrawRenderBatchActive(); // push what you have
      rlBegin(RL_TRIANGLES);     // start a new batch
    }

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

void AddCustomPolygonOrLineWithRLGL(std::shared_ptr<Layer> layer,
                                    const std::vector<Vector2> &vertices,
                                    const Color &color, bool filled, int z) {
  int mode = filled ? RL_TRIANGLES : RL_LINES;

  AddBeginRLMode(layer, mode, z);

  for (const auto &v : vertices) {
    AddVertex(layer, v, color, z);
  }

  AddEndRLMode(layer, z);
}

// in order to make this method stackable inside lamdas, we can't call
// begindrawing() in here. that must be handled by the user.
void DrawCanvasToCurrentRenderTargetWithTransform(
    const std::shared_ptr<Layer> layer, const std::string &canvasName, float x,
    float y, float rotation, float scaleX, float scaleY, const Color &color,
    std::string shaderName, bool flat) {

  auto canvasIt = layer->canvases.find(canvasName);
  if (canvasIt == layer->canvases.end()) {
    SPDLOG_WARN("DrawCanvasToCurrentRenderTargetWithTransform: canvas '{}' not found", canvasName);
    return;
  }
  const auto& canvas = canvasIt->second;

  Shader shader = shaders::getShader(shaderName);

  // Optional shader
  if (shader.id != 0) {
    BeginShaderMode(shader);

    // texture uniforms need to be set after beginShaderMode
    shaders::TryApplyUniforms(shader, globals::getGlobalShaderUniforms(),
                              shaderName);
  }

  // Set color - use cached canvas reference instead of .at()
  DrawTexturePro(
      canvas.texture,
      {0, 0, (float)canvas.texture.width,
       (float)-canvas.texture.height},
      {x, y, (float)canvas.texture.width * scaleX,
       (float)-canvas.texture.height * scaleY},
      {0, 0}, rotation, {color.r, color.g, color.b, color.a});

  if (shader.id != 0)
    EndShaderMode();
}

// Function that uses a destination rectangle
void DrawCanvasToCurrentRenderTargetWithDestRect(
    const std::shared_ptr<Layer> layer, const std::string &canvasName,
    const Rectangle &destRect, const Color &color, std::string shaderName) {
  // PERF: Use find result directly instead of find + at (was double lookup)
  auto it = layer->canvases.find(canvasName);
  if (it == layer->canvases.end())
    return;

  Shader shader = shaders::getShader(shaderName);

  // Optional shader
  if (shader.id != 0) {
    BeginShaderMode(shader);

    // texture uniforms need to be set after beginShaderMode
    shaders::TryApplyUniforms(shader, globals::getGlobalShaderUniforms(),
                              shaderName);
  }

  // Draw the texture to the specified destination rectangle
  const auto& canvas = it->second;
  DrawTexturePro(
      canvas.texture,
      {0, 0, (float)canvas.texture.width,
       (float)-canvas.texture.height},
      destRect, // Destination rectangle
      {0, 0},   // Origin for rotation (set to top-left here, can be adjusted)
      0.0f,     // No rotation
      {color.r, color.g, color.b, color.a});

  if (shader.id != 0)
    EndShaderMode();
}

auto AddDrawTransformEntityWithAnimationWithPipeline(
    std::shared_ptr<Layer> layer, entt::registry *registry, entt::entity e,
    int z) -> void {
  AddDrawCommand(layer, "draw_transform_entity_animation_pipeline",
                 {e, registry}, z);
}

auto DrawTransformEntityWithAnimationWithPipeline(entt::registry &registry,
                                                  entt::entity e) -> void {

  // disable the camera if it exists
  Camera2D *camera = nullptr;
  if (camera_manager::IsActive()) {
    camera = camera_manager::Current();
    camera_manager::End();
  }

  // 1. Fetch animation frame and sprite - use COPIES to avoid dangling pointers
  Rectangle animationFrameData{};
  Rectangle *animationFrame = nullptr;
  SpriteComponentASCII currentSpriteData{};
  SpriteComponentASCII *currentSprite = nullptr;
  bool flipX{false}, flipY{false};

  float intrinsicScale = 1.0f;
  float uiScale = 1.0f;

  if (registry.any_of<AnimationQueueComponent>(e)) {
    auto &aqc = registry.get<AnimationQueueComponent>(e);
    if (aqc.noDraw) {
      // Restore camera before early return to avoid state corruption
      if (camera) {
        camera_manager::Begin(*camera);
      }
      return;
    }
    if (!aqc.drawWithLegacyPipeline) {
      if (camera) {
        camera_manager::Begin(*camera);
      }
      return;
    }

    // compute the same renderScale as in your other overload:
    intrinsicScale =
        aqc.animationQueue.empty()
            ? aqc.defaultAnimation.intrinsincRenderScale.value_or(1.0f)
            : aqc.animationQueue[aqc.currentAnimationIndex]
                  .intrinsincRenderScale.value_or(1.0f);

    uiScale = aqc.animationQueue.empty()
                  ? aqc.defaultAnimation.uiRenderScale.value_or(1.0f)
                  : aqc.animationQueue[aqc.currentAnimationIndex]
                        .uiRenderScale.value_or(1.0f);

    if (aqc.animationQueue.empty()) {
      if (!aqc.defaultAnimation.animationList.empty()) {
        // Copy data instead of storing pointers to avoid dangling references
        animationFrameData =
            aqc.defaultAnimation
                .animationList[aqc.defaultAnimation.currentAnimIndex]
                .first.spriteData.frame;
        animationFrame = &animationFrameData;
        currentSpriteData =
            aqc.defaultAnimation
                .animationList[aqc.defaultAnimation.currentAnimIndex]
                .first;
        currentSprite = &currentSpriteData;
        flipX = aqc.defaultAnimation.flippedHorizontally;
        flipY = aqc.defaultAnimation.flippedVertically;
      }
    } else {
      auto &currentAnimObject = aqc.animationQueue[aqc.currentAnimationIndex];
      // Copy data instead of storing pointers to avoid dangling references
      animationFrameData =
          currentAnimObject.animationList[currentAnimObject.currentAnimIndex]
              .first.spriteData.frame;
      animationFrame = &animationFrameData;
      currentSpriteData =
          currentAnimObject.animationList[currentAnimObject.currentAnimIndex]
              .first;
      currentSprite = &currentSpriteData;
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

  float baseWidth = animationFrame->width * renderScale;
  float baseHeight = animationFrame->height * renderScale;

  auto &pipelineComp =
      registry.get<shader_pipeline::ShaderPipelineComponent>(e);
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

  // the raw frame in atlas (always positive size)
  Rectangle srcRec{(float)animationFrame->x, (float)animationFrame->y,
                   (float)animationFrame->width, (float)animationFrame->height};

  // the destination quad inside your RT, before flipping
  Rectangle dstRec{pad, pad, baseWidth, baseHeight};

  // apply flips by moving origin to the other side and negating size:
  if (flipX) {
    srcRec.x += srcRec.width;
    srcRec.width = -srcRec.width;
    dstRec.x += dstRec.width; // move right edge back to pad
    dstRec.width = -dstRec.width;
  }
  if (flipY) {
    srcRec.y += srcRec.height;
    srcRec.height = -srcRec.height;
    dstRec.y += dstRec.height; // move bottom edge back to pad
    dstRec.height = -dstRec.height;
  }

  auto &transform = registry.get<transform::Transform>(e);

  // right after you compute renderWidth/renderHeight:
  shader_pipeline::ResetDebugRects();

  // hacky fix to ensure entities are not fully transparent
  if (fgColor.a == 0) {
    // SPDLOG_WARN("Entity {} has a foreground color with alpha 0. Setting to
    // 255.", (int)e);
    fgColor = WHITE;
  }

  // FIXME: this works. why doesn't the rest?
  //  DrawTexture(*spriteAtlas, 0, 0, WHITE); // Debug draw the atlas to see if
  //  it's loaded correctly

  if (!shader_pipeline::IsInitialized() ||
      shader_pipeline::width < (int)renderWidth ||
      shader_pipeline::height < (int)renderHeight) {

    // shader_pipeline::ShaderPipelineInit(renderWidth, renderHeight);

    auto newW = std::max(shader_pipeline::width, (int)renderWidth);
    auto newH = std::max(shader_pipeline::height, (int)renderHeight);
    shader_pipeline::ShaderPipelineUnload();
    shader_pipeline::ShaderPipelineInit(newW, newH);
    SPDLOG_DEBUG("ShaderPipelineInit called with new size: {}x{}",
                 shader_pipeline::width, shader_pipeline::height);
  }

  // 2. Draw base sprite to front() (no transforms) = id 6
  render_stack_switch_internal::Push(shader_pipeline::front());
  ClearBackground({0, 0, 0, 0});

  // local content area origin (0,0) should be inside padding
  Vector2 drawOffset = {pad, pad};

  bool usedLocalCallback = false;

  // DrawCircle(0, 0, 100, RED); // debug point at local origin

  // 🟡 NEW: check for RenderImmediateCallback (Lua override)
  bool usedImmediateCallback = false;
  if (registry.any_of<transform::RenderImmediateCallback>(e)) {
    const auto &cb = registry.get<transform::RenderImmediateCallback>(e);
    if (cb.fn.valid()) {
      rlPushMatrix();

      // Move to padded draw area
      rlTranslatef(drawOffset.x, drawOffset.y, 0);

      // Center the local origin inside the image region
      rlTranslatef(baseWidth * 0.5f, baseHeight * 0.5f, 0);

      // Optional: flip Y if you still need upright drawing later
      // rlTranslatef(0, baseHeight, 0);
      // rlScalef(1, -1, 1);

      // Now (0,0) is at the image center
      // DrawCircle(0, 0, 100, RED); // should render centered
      // DrawGradientRectRoundedCentered(
      //     0, 0,
      //     baseWidth, baseHeight,
      //     0.2f, 16,
      //     RED, BLUE,
      //     GREEN, YELLOW);
      cb.fn(baseWidth, baseHeight); // run Lua callback here if desired
      rlPopMatrix();

      usedImmediateCallback = true;
      if (cb.disableSpriteRendering)
        usedLocalCallback = true;
    }
  }

  if (registry.any_of<transform::RenderLocalCallback>(e)) {
    const auto &cb = registry.get<transform::RenderLocalCallback>(e);
    if (cb.fn && !cb.afterPipeline) {
      Translate(drawOffset.x, drawOffset.y);
      cb.fn(baseWidth, baseHeight, /*isShadow=*/false);

      DrawCircle(0, 0, 100, RED); // debug point at local origin
      Translate(-drawOffset.x, -drawOffset.y);
      usedLocalCallback = true;
    }
  }

  // existing sprite drawing logic only runs if no callback replaced it
  if (!usedLocalCallback && !usedImmediateCallback) {
    if (drawBackground) {
      layer::RectanglePro(drawOffset.x, drawOffset.y, {baseWidth, baseHeight},
                          {0, 0}, 0, bgColor);
    }

    if (drawForeground) {
      if (animationFrame) {
        layer::TexturePro(
            *spriteAtlas,
            {animationFrame->x, animationFrame->y,
             animationFrame->width * xFlipModifier,
             animationFrame->height * -yFlipModifier},
            drawOffset.x, drawOffset.y,
            {baseWidth * xFlipModifier, baseHeight * yFlipModifier}, {0, 0}, 0,
            fgColor);

        shader_pipeline::SetLastRenderRect({drawOffset.x, drawOffset.y,
                                            baseWidth * xFlipModifier,
                                            baseHeight * yFlipModifier});
        shader_pipeline::RecordDebugRect(shader_pipeline::GetLastRenderRect());
      } else {
        layer::RectanglePro(drawOffset.x, drawOffset.y, {baseWidth, baseHeight},
                            {0, 0}, 0, fgColor);
      }
    }
  }

  render_stack_switch_internal::Pop(); // done with id 6

  // 🟡 Save base sprite result
  // RenderTexture2D baseSpriteRender =
  //     shader_pipeline::GetBaseRenderTextureCache();
  // render_stack_switch_internal::Push(baseSpriteRender);
  // ClearBackground({0, 0, 0, 0});
  // DrawTexture(shader_pipeline::front().texture, 0, 0, WHITE);
  // render_stack_switch_internal::Pop();

  RenderTexture2D baseSpriteRender =
      shader_pipeline::GetBaseRenderTextureCache();
  layer::render_stack_switch_internal::Push(baseSpriteRender);
  ClearBackground({0, 0, 0, 0});
  Rectangle baseSpriteSourceRect = {
      0.0f, (float)shader_pipeline::front().texture.height - renderHeight,
      renderWidth, renderHeight};
  DrawTextureRec(shader_pipeline::front().texture, baseSpriteSourceRect, {0, 0},
                 WHITE);
  layer::render_stack_switch_internal::Pop();

  if (globals::getDrawDebugInfo()) {
    // Draw
    DrawTextureRec(shader_pipeline::front().texture, baseSpriteSourceRect,
                   {0, 0}, WHITE);
  }

  // 3. Apply shader passes
  int total = pipelineComp.passes.size();

  int i = 0;
  for (shader_pipeline::ShaderPass &pass : pipelineComp.passes) {
    bool lastPass = (++i == total);

    if (!pass.enabled)
      continue;

    Shader shader = shaders::getShader(pass.shaderName);
    if (!shader.id) {
      SPDLOG_WARN("Shader {} not found for entity {}", pass.shaderName, (int)e);
      continue; // skip if shader is not found
    }
    render_stack_switch_internal::Push(shader_pipeline::back());
    ClearBackground({0, 0, 0, 0});
    BeginShaderMode(shader);
    if (pass.injectAtlasUniforms) {
      injectAtlasUniforms(
          globals::getGlobalShaderUniforms(), pass.shaderName,
          {0, 0, (float)renderWidth, (float)renderHeight},
          Vector2{
              (float)renderWidth,
              (float)
                  renderHeight}); // FIXME: not sure why, but it only works when
                                  // I do this instead of the full texture size

      // float drawnH = frameHeight*renderScale + pad*2.f;
      // globals::globalShaderUniforms.set(pass.shaderName, "uTransformHeight",
      //     transform.getVisualH());
    }

    // Per-entity rotation feed for material_card_overlay.
    if (pass.shaderName == "material_card_overlay" ||
        pass.shaderName == "material_card_overlay_new_dissolve") {
      float rotDeg = transform.getVisualRWithDynamicMotionAndXLeaning();
      if (std::abs(rotDeg) < 0.0001f) {
        rotDeg = transform.getVisualR();
      }
      globals::getGlobalShaderUniforms().set(pass.shaderName, "card_rotation",
                                             rotDeg * DEG2RAD);
    }

    if (pass.customPrePassFunction)
      pass.customPrePassFunction();
    // TODO: auto inject sprite atlas texture dims and sprite rect here
    //  injectAtlasUniforms(globals::globalShaderUniforms, pass.shaderName,
    //  srcRec, Vector2{(float)spriteAtlas->width, (float)spriteAtlas->height});

    TryApplyUniforms(shader, globals::getGlobalShaderUniforms(),
                     pass.shaderName);

    // Apply per-entity uniforms (override global uniforms for this entity)
    if (registry.any_of<shaders::ShaderUniformComponent>(e)) {
        auto& entityUniforms = registry.get<shaders::ShaderUniformComponent>(e);
        entityUniforms.applyToShaderForEntity(shader, pass.shaderName, e, registry);
    }

    // DrawTextureRec(shader_pipeline::front().texture,
    //                {0, 0, (float)renderWidth * xFlipModifier,
    //                 (float)-renderHeight * yFlipModifier},
    //                {0, 0}, WHITE); // invert Y
    Rectangle sourceRect = {
        0.0f, (float)shader_pipeline::front().texture.height - renderHeight,
        renderWidth, renderHeight};
    DrawTextureRec(shader_pipeline::front().texture, sourceRect, {0, 0}, WHITE);

    shader_pipeline::SetLastRenderRect(
        {0, 0, renderWidth * xFlipModifier, renderHeight * yFlipModifier});
    shader_pipeline::RecordDebugRect(shader_pipeline::GetLastRenderRect());

    EndShaderMode();
    render_stack_switch_internal::Pop();
    shader_pipeline::Swap();

    shader_pipeline::SetLastRenderTarget(shader_pipeline::front());
  }

  // // 🔵 Save post-pass result
  RenderTexture2D postPassRender = {}; // id 6 is now the result of all passes
  if (pipelineComp.passes.empty()) {
    // No shader passes - use the base sprite render directly
    shader_pipeline::SetLastRenderTarget(baseSpriteRender);
    postPassRender = *shader_pipeline::GetLastRenderTarget();
  } else if (!shader_pipeline::GetLastRenderTarget()) {
    shader_pipeline::SetLastRenderTarget(
        shader_pipeline::front()); // if no passes, we use the front texture
    postPassRender = shader_pipeline::front();
  } else {
    postPassRender =
        *shader_pipeline::GetLastRenderTarget(); // if there are passes, we use
                                                 // the last render target
  }

  // 🟡 Save post shader pass sprite result
  RenderTexture2D postProcessRender =
      shader_pipeline::GetPostShaderPassRenderTextureCache();
  render_stack_switch_internal::Push(postProcessRender);
  ClearBackground({0, 0, 0, 0});

  if (pipelineComp.passes.empty()) {
    // No shader passes - treat like 1 pass (odd) for consistent behavior
    Rectangle sourceRect = {
        0.0f, (float)baseSpriteRender.texture.height - renderHeight,
        renderWidth, renderHeight};
    DrawTextureRec(baseSpriteRender.texture, sourceRect, {0, 0}, WHITE);
  } else if (pipelineComp.passes.size() % 2 == 0) {
    DrawTexture(postPassRender.texture, 0, 0, WHITE);
  } else {
    Rectangle sourceRect = {0.0f,
                            (float)postPassRender.texture.height - renderHeight,
                            renderWidth, renderHeight};
    DrawTextureRec(postPassRender.texture, sourceRect, {0, 0}, WHITE);
  }

  // DrawTextureRec(postPassRender.texture,
  // 			{ 0.0f,
  // 				(float)postPassRender.texture.height,
  // 				renderWidth,
  // 				-renderHeight },
  // 			{0,0},
  // 			WHITE);
  render_stack_switch_internal::Pop();

  if (globals::getDrawDebugInfo()) {
    // Draw
    DrawTexture(postPassRender.texture, 0, 150, WHITE);
  }

  // DrawTexture(postPassRender.texture, 90, 30, WHITE);

  bool internalFlipFlagForShaderPipeline =
      true; // FIXME: testing
            //    pipelineComp.overlayDraws.size() % 2 != 0; // if odd, we flip
            //    the Y

  // if there is an overlay draw at all, we need to draw the base sprite to the
  // front texture first.
  if (!pipelineComp.overlayDraws.empty()) {
    // get the first through an iterator
    auto firstOverlay = pipelineComp.overlayDraws.begin();
    if (firstOverlay != pipelineComp.overlayDraws.end() &&
        firstOverlay->inputSource ==
            shader_pipeline::OverlayInputSource::BaseSprite) {
      // if the first overlay is a base sprite, we need to draw the base sprite
      // to the front texture.
      render_stack_switch_internal::Push(shader_pipeline::front());
      ClearBackground({0, 0, 0, 0});
      // no shader
      // DrawTextureRec(baseSpriteRender.texture,
      //                {0, 0, renderWidth * xFlipModifier,
      //                 -(float)renderHeight * yFlipModifier},
      //                {0, 0}, WHITE);
      Rectangle sourceRect = {
          0.0f, (float)baseSpriteRender.texture.height - renderHeight,
          renderWidth, renderHeight};
      DrawTextureRec(baseSpriteRender.texture, sourceRect, {0, 0}, WHITE);
      render_stack_switch_internal::Pop();
    } else {
      // if the first overlay is not a base sprite, we need to draw the post
      // pass render to the front texture.
      render_stack_switch_internal::Push(shader_pipeline::front());
      ClearBackground({0, 0, 0, 0});
      // no shader
      // DrawTextureRec(postProcessRender.texture,
      //                {0, 0, renderWidth * xFlipModifier,
      //                 -(float)renderHeight * yFlipModifier},
      //                {0, 0}, WHITE);
      Rectangle sourceRect = {
          0.0f, (float)postProcessRender.texture.height - renderHeight,
          renderWidth, renderHeight};
      DrawTextureRec(postProcessRender.texture, sourceRect, {0, 0}, WHITE);
      render_stack_switch_internal::Pop();
    }
  }

  // 4. Overlay draws, which can be optioanll used together with the shader
  // passes above.
  for (const auto &overlay : pipelineComp.overlayDraws) {
    if (!overlay.enabled)
      continue;

    Shader shader = shaders::getShader(overlay.shaderName);
    if (shader.id <= 0)
      continue;
    AssertThat(shader.id, IsGreaterThan(0));
    render_stack_switch_internal::Push(shader_pipeline::front());
    // ClearBackground({0, 0, 0, 0});
    BeginShaderMode(shader);
    if (overlay.customPrePassFunction)
      overlay.customPrePassFunction();
    if (overlay.injectAtlasUniforms) {
      injectAtlasUniforms(
          globals::getGlobalShaderUniforms(), overlay.shaderName,
          {0, 0, (float)renderWidth, (float)renderHeight},
          Vector2{
              (float)renderWidth,
              (float)
                  renderHeight}); // FIXME: not sure why, but it only works when
                                  // I do this instead of the full texture size
    }
    TryApplyUniforms(shader, globals::getGlobalShaderUniforms(),
                     overlay.shaderName);

    // Apply per-entity uniforms (override global uniforms for this entity)
    if (registry.any_of<shaders::ShaderUniformComponent>(e)) {
        auto& entityUniforms = registry.get<shaders::ShaderUniformComponent>(e);
        entityUniforms.applyToShaderForEntity(shader, overlay.shaderName, e, registry);
    }

    RenderTexture2D &source =
        (overlay.inputSource == shader_pipeline::OverlayInputSource::BaseSprite)
            ? baseSpriteRender
            : postPassRender;
    // DrawTextureRec(source.texture,
    //                {0, 0, renderWidth * xFlipModifier,
    //                 -(float)renderHeight * yFlipModifier},
    //                {0, 0}, WHITE);
    Rectangle sourceRect = {0.0f, (float)source.texture.height - renderHeight,
                            renderWidth, renderHeight};
    DrawTextureRec(source.texture, sourceRect, {0, 0}, WHITE);

    EndShaderMode();
    render_stack_switch_internal::Pop();
    // shader_pipeline::Swap();
    // don't swap, we draw onto the front texture, which is the last render
    // target.

    shader_pipeline::SetLastRenderRect(
        {0, 0, renderWidth * xFlipModifier, -renderHeight * yFlipModifier});
    // shader_pipeline::RecordDebugRect(shader_pipeline::GetLastRenderRect());

    shader_pipeline::SetLastRenderTarget(shader_pipeline::back());

    // render_stack_switch_internal::Push(shader_pipeline::front());
    // BeginBlendMode((int)overlay.blendMode);
    // DrawTextureRec(shader_pipeline::back().texture, {0, 0, renderWidth *
    // xFlipModifier, (float)-renderHeight * yFlipModifier}, {0, 0}, WHITE);
    // EndBlendMode();
    // render_stack_switch_internal::Pop();
  }

  RenderTexture toRender{};
  if (pipelineComp.overlayDraws.empty() == false) {
    toRender =
        shader_pipeline::front(); //  in this case it's the overlay draw result
  } else {
    // if there are passes or no passes, we use the post-process render cache
    // which contains either the shader results or the base sprite
    toRender = shader_pipeline::GetPostShaderPassRenderTextureCache();
  }

  if (globals::getDrawDebugInfo()) {
    // Draw the final texture to the screen for debugging
    DrawTexture(toRender.texture, 0, 300, WHITE);
    DrawText(fmt::format("Final Render Texture: {}x{}", toRender.texture.width,
                         toRender.texture.height)
                 .c_str(),
             10, 300, 20, WHITE);
  }

  // turn the camera back on if it was active (since we're rendering to the
  // screen now, and to restore camera state in the command buffer)
  bool isScreenSpace = registry.any_of<collision::ScreenSpaceCollisionMarker>(e);
  if (camera && !isScreenSpace) {
    camera_manager::Begin(*camera);
  }

  // ============================================================
  //               NEW GROUND ELLIPSE SHADOW BLOCK  (FIXED ANCHOR)
  // ============================================================
  if (registry.any_of<transform::GameObject>(e)) {
    auto &node = registry.get<transform::GameObject>(e);

    if (node.shadowDisplacement &&
        node.shadowMode == transform::GameObject::ShadowMode::GroundEllipse) {

      // ----- Correct anchor point -----
      // Center horizontally, bottom vertically
      float baseX = transform.getVisualX() + transform.getVisualW() * 0.5f;
      float baseY = transform.getVisualY() + transform.getVisualH() +
                    node.groundShadowYOffset;

      // Compute visual scale
      float s = transform.getVisualScaleWithHoverAndDynamicMotionReflected();

      // Sprite size (pre-scale)
      float spriteW = transform.getVisualW();
      float spriteH = transform.getVisualH();

      // Radii (auto or override)
      float rx = node.groundShadowRadiusX.has_value()
                     ? *node.groundShadowRadiusX
                     : spriteW * 0.40f;

      float ry = node.groundShadowRadiusY.has_value()
                     ? *node.groundShadowRadiusY
                     : spriteH * 0.15f;

      // Apply scaling and height factor
      rx *= s * node.groundShadowHeightFactor;
      ry *= s * node.groundShadowHeightFactor;

      if (node.groundShadowColor.a > 0 && rx > 0.1f && ry > 0.1f) {
        rlPushMatrix();
        rlTranslatef(baseX, baseY, 0.0f);
        rlScalef(rx, ry, 1.0f);
        DrawCircleV({0.0f, 0.0f}, 1.0f, node.groundShadowColor);
        rlPopMatrix();
      }
    }
  }
  // ============================================================

  // 5. Final draw with transform

  Vector2 drawPos = {transform.getVisualX() - pad,
                     transform.getVisualY() - pad}; // why subtract pad here?
  shader_pipeline::SetLastRenderRect(
      {drawPos.x, drawPos.y, renderWidth,
       renderHeight}); // shouldn't this store the last dest rect that was drawn
                       // on the last texture?

  // default (no flip)
  Rectangle finalSourceRect = {0.0f,
                               (float)toRender.texture.height - renderHeight,
                               renderWidth, renderHeight};

  // if we’ve done an odd number of flips, correct it exactly once:
  if (pipelineComp.passes.empty()) {
    // No passes - treat like odd (1 pass) for consistency
    // Already set correctly above (default finalSourceRect), no change needed
  } else if (pipelineComp.passes.size() % 2 == 0) {
    finalSourceRect.y = (float)toRender.texture.height;
    finalSourceRect.height = -(float)renderHeight;
  } else {
    // if we have an odd number of flips, we need to flip the Y coordinate
    // sourceRect.y      = (float)renderHeight;
    // sourceRect.height = (float)-renderHeight;
  }

  Vector2 origin = {renderWidth * 0.5f, renderHeight * 0.5f};
  Vector2 position = {drawPos.x + origin.x, drawPos.y + origin.y};

  // PushMatrix();
  // Translate(position.x, position.y);
  // Scale(transform.getVisualScaleWithHoverAndDynamicMotionReflected(),
  //       transform.getVisualScaleWithHoverAndDynamicMotionReflected());
  // Rotate(transform.getVisualRWithDynamicMotionAndXLeaning());
  // Translate(-origin.x, -origin.y);

  // shadow rendering first (with rotation but world-space offset)
  // ============================================================
  //        ORIGINAL SPRITE-BASED SHADOW (SpriteBased only)
  // ============================================================
  {
    auto &node = registry.get<transform::GameObject>(e);

    if (node.shadowMode == transform::GameObject::ShadowMode::SpriteBased &&
        node.shadowDisplacement) {
      float baseExaggeration = globals::getBaseShadowExaggeration();
      float heightFactor = 1.0f + node.shadowHeight.value_or(
                                      0.f); // Increase effect based on height

      // Adjust displacement using shadow height (in world space)
      float shadowOffsetX =
          node.shadowDisplacement->x * baseExaggeration * heightFactor;
      float shadowOffsetY =
          node.shadowDisplacement->y * baseExaggeration * heightFactor;

      float shadowAlpha = 0.8f; // 0.0f to 1.0f
      Color shadowColor = Fade(BLACK, shadowAlpha);

      // Draw shadow at world-space offset WITH rotation (shadow rotates with
      // sprite)
      PushMatrix();
      Translate(position.x - shadowOffsetX, position.y + shadowOffsetY);
      float s = transform.getVisualScaleWithHoverAndDynamicMotionReflected();
      float visualScaleX = (transform.getVisualW() / baseWidth) * s;
      float visualScaleY = (transform.getVisualH() / baseHeight) * s;
      Scale(visualScaleX, visualScaleY);
      Rotate(
          transform.getVisualRWithDynamicMotionAndXLeaning()); // Shadow rotates
                                                               // with sprite
      Translate(-origin.x, -origin.y);
      DrawTextureRec(toRender.texture, finalSourceRect, {0, 0}, shadowColor);
      PopMatrix();
    }
  }

  PushMatrix();
  Translate(position.x, position.y);
  float s = transform.getVisualScaleWithHoverAndDynamicMotionReflected();
  float visualScaleX = (transform.getVisualW() / baseWidth) * s;
  float visualScaleY = (transform.getVisualH() / baseHeight) * s;
  Scale(visualScaleX, visualScaleY);
  Rotate(transform.getVisualRWithDynamicMotionAndXLeaning());
  Translate(-origin.x, -origin.y);

  DrawTextureRec(toRender.texture, finalSourceRect, {0, 0}, WHITE);

  // debug rect
  if (globals::getDrawDebugInfo()) {
    // DrawRectangleLines(-pad, -pad, (int)shader_pipeline::width,
    // (int)shader_pipeline::height, RED); DrawText(fmt::format("SHADER
    // PASSEntity ID: {}", static_cast<int>(e)).c_str(), 10, 10, 15, WHITE);
  }

  // add local callback rendering which should go after the pipeline ends. (hud,
  // or something that should bypass the ususal shader pipeline)
  if (registry.any_of<transform::RenderLocalCallback>(e)) {
    const auto &cb = registry.get<transform::RenderLocalCallback>(e);
    // if you keep afterPipeline, gate it here:
    if (cb.fn && cb.afterPipeline) {
      // choose size (sprite-backed or callback-defined)
      const float cw = (animationFrame ? baseWidth : cb.contentWidth);
      const float ch = (animationFrame ? baseHeight : cb.contentHeight);

      // Optional shadow call (mirrors your texture shadow)
      if (registry.any_of<transform::GameObject>(e)) {
        auto &node = registry.get<transform::GameObject>(e);
        if (node.shadowDisplacement) {
          const float baseEx = globals::getBaseShadowExaggeration();
          const float hFact = 1.0f + node.shadowHeight.value_or(0.f);
          const float shX = node.shadowDisplacement->x * baseEx * hFact;
          const float shY = node.shadowDisplacement->y * baseEx * hFact;

          Translate(-shX, shY);
          Translate(pad, pad);
          cb.fn(cw, ch, /*isShadow=*/true); // first pass: shadow
          Translate(-pad, -pad);
          Translate(shX, -shY);
        }
      }

      // Main (non-shadow) pass
      Translate(pad, pad);
      cb.fn(cw, ch, /*isShadow=*/false);
      Translate(-pad, -pad);
    }
  }

  PopMatrix();

  // draw the mini pipeline view + ALL rects
  // shader_pipeline::DebugDrawAllRects(10, 10);
}

//-----------------------------------------------------------------------------------
// renderSliceOffscreen
//   Renders a single UI entity (and optionally its subtree) through your
//   shader_pipeline system—passes, overlays—and then draws it back to the
//   screen.
//-----------------------------------------------------------------------------------
// FIXME: doesn't use queue, immediate commands. maybe change?
void renderSliceOffscreenFromDrawList(
    entt::registry &registry, const std::vector<ui::UIDrawListItem> &drawList,
    size_t startIndex, size_t endIndex, Layer* layerPtr,
    float pad) {

  ui::EnsureUIGroupInitialized(registry);

  Camera2D *camera = nullptr;
  if (camera_manager::IsActive()) {
    camera = camera_manager::Current();
    camera_manager::End();
  }

  // 1. Compute the bounding box of the entities in the range
  float xMin = FLT_MAX, yMin = FLT_MAX;
  float xMax = -FLT_MAX, yMax = -FLT_MAX;
  float visualScaleWithHover = 1.0f, visualRotationWithDynamicMotion = 0.0f;

  for (size_t i = startIndex; i < endIndex; ++i) {
    entt::entity e = drawList[i].e;
    auto &xf = ui::globalUIGroup.get<transform::Transform>(e);
    float x = xf.getVisualX();
    float y = xf.getVisualY();
    float w = xf.getVisualW();
    float h = xf.getVisualH();

    xMin = std::min(xMin, x);
    yMin = std::min(yMin, y);
    xMax = std::max(xMax, x + w);
    yMax = std::max(yMax, y + h);

    visualScaleWithHover =
        xf.getVisualScaleWithHoverAndDynamicMotionReflected();
    visualRotationWithDynamicMotion =
        xf.getVisualRWithDynamicMotionAndXLeaning();
  }

  float renderW = (xMax - xMin) + pad * 2.0f;
  float renderH = (yMax - yMin) + pad * 2.0f;

  // Ensure pipeline texture size

  // if (!shader_pipeline::IsInitialized() ||
  //     shader_pipeline::width < (int)renderWidth ||
  //     shader_pipeline::height < (int)renderHeight) {
  //   shader_pipeline::ShaderPipelineUnload();
  //   shader_pipeline::ShaderPipelineInit(renderWidth, renderHeight);
  // }
  if (!shader_pipeline::IsInitialized() ||
      shader_pipeline::width < (int)renderW ||
      shader_pipeline::height < (int)renderH) {

    auto newW = std::max(shader_pipeline::width, (int)renderW);
    auto newH = std::max(shader_pipeline::height, (int)renderH);
    shader_pipeline::ShaderPipelineUnload();
    shader_pipeline::ShaderPipelineInit(newW, newH);
    SPDLOG_DEBUG("ShaderPipelineInit called with new size: {}x{}",
                 shader_pipeline::width, shader_pipeline::height);
  }
  shader_pipeline::ResetDebugRects();

  // Get pipeline from first entity
  auto &pipeline = registry.get<shader_pipeline::ShaderPipelineComponent>(
      drawList[startIndex].e);

  // 2. Draw to front()
  layer::render_stack_switch_internal::Push(shader_pipeline::front());
  ClearBackground({0, 0, 0, 0});

  rlPushMatrix();
  rlTranslatef(-xMin + pad, -yMin + pad, 0);
  for (size_t i = startIndex; i < endIndex; ++i) {
    entt::entity e = drawList[i].e;
    auto &uiElementComp = ui::globalUIGroup.get<ui::UIElementComponent>(e);
    auto &configComp = ui::globalUIGroup.get<ui::UIConfig>(e);
    auto &stateComp = ui::globalUIGroup.get<ui::UIState>(e);
    auto &nodeComp = ui::globalUIGroup.get<transform::GameObject>(e);
    auto &transformComp = ui::globalUIGroup.get<transform::Transform>(e);
    ui::element::DrawSelfImmediate(layerPtr, e, uiElementComp, configComp,
                                   stateComp, nodeComp, transformComp);
  }
  rlPopMatrix();
  layer::render_stack_switch_internal::Pop(); // TODO: is the right texture now
                                              // in front()?

  // 3. Copy front() to base cache
  RenderTexture2D baseRT = shader_pipeline::GetBaseRenderTextureCache();
  layer::render_stack_switch_internal::Push(baseRT); // FIXME: flip every time.
  ClearBackground({0, 0, 0, 0});
  // DrawTexture(shader_pipeline::front().texture, 0, 0, WHITE);

  Rectangle sourceRect = {
      0.0f, // x
      (float)shader_pipeline::front().texture.height -
          renderH, // y = start at top of the texture
      renderW,     // width
      renderH      // negative height to flip back
  };
  DrawTextureRec(shader_pipeline::front().texture, sourceRect, {0, 0}, WHITE);
  layer::render_stack_switch_internal::Pop();

  // FIXME: draw the baseRT to the screen here, so we can see what we're
  // rendering offscreen.
  // auto tex = layer::render_stack_switch_internal::Current();
  // layer::render_stack_switch_internal::Pop();
  // DrawTexture(baseRT.texture, 0, 0, WHITE); // Debug dra
  // layer::render_stack_switch_internal::Push(*tex);

  // 4. Shader passes
  for (auto &pass : pipeline.passes) {
    if (!pass.enabled)
      continue;
    Shader sh = shaders::getShader(pass.shaderName);
    if (!sh.id)
      continue;

    layer::render_stack_switch_internal::Push(shader_pipeline::back());
    ClearBackground({0, 0, 0, 0});
    BeginShaderMode(sh);
    if (pass.injectAtlasUniforms)
      injectAtlasUniforms(globals::getGlobalShaderUniforms(), pass.shaderName,
                          {0, 0, renderW, renderH}, {renderW, renderH});
    if (pass.customPrePassFunction)
      pass.customPrePassFunction();
    TryApplyUniforms(sh, globals::getGlobalShaderUniforms(), pass.shaderName);
    Rectangle sourceRect = {
        0.0f, // x
        (float)shader_pipeline::front().texture.height -
            renderH, // y = start at top of the texture
        renderW,     // width
        renderH      // negative height to flip back
    };
    DrawTextureRec(shader_pipeline::front().texture, sourceRect, {0, 0}, WHITE);
    // DrawTextureRec(shader_pipeline::front().texture, {0, 0, renderW,
    // renderH}, {0, 0}, WHITE);  // y-flipped, maintained
    EndShaderMode();
    layer::render_stack_switch_internal::Pop();
    shader_pipeline::Swap();
    shader_pipeline::SetLastRenderTarget(
        shader_pipeline::front()); // TODO: is this logic right?
  }

  // 5. Collect post-pass
  // RenderTexture2D postPassRT = GetLastRenderTarget() ? *GetLastRenderTarget()
  // : front(); // TODO: this gets overwritten by the next overlay draw, so we
  // need to save it before that?

  RenderTexture2D postPassRT = shader_pipeline::GetLastRenderTarget()
                                   ? *shader_pipeline::GetLastRenderTarget()
                                   : shader_pipeline::front();

  auto postCache = shader_pipeline::
      GetPostShaderPassRenderTextureCache(); // TODO: resize to renderW, renderH
  layer::render_stack_switch_internal::Push(postCache);
  ClearBackground({0, 0, 0, 0});
  DrawTexture(postPassRT.texture, 0, 0, WHITE);
  layer::render_stack_switch_internal::Pop(); // also y-flipped

  if (globals::getDrawDebugInfo()) {
    // DrawTexture(postPassRT.texture, 0, 0, WHITE);

    // DrawRectangle(0, 0, postPassRT.texture.width, postPassRT.texture.height,
    //               {0, 255, 0, 100});
    // DrawRectangle(0, 0, renderW, renderH, {255, 0, 0, 150});
    // DrawText(fmt::format("PostPassRT (green): {}x{}",
    // postPassRT.texture.width,
    //                      postPassRT.texture.height)
    //              .c_str(),
    //          10, 10, 20, WHITE);
    // DrawText(fmt::format("RenderSize (red): {}x{}", renderW,
    // renderH).c_str(),
    //          10, 30, 20, WHITE);
  }

  // prime for overlays, if any
  if (!pipeline.overlayDraws.empty()) {
    auto &first = pipeline.overlayDraws.front();
    render_stack_switch_internal::Push(shader_pipeline::front());
    ClearBackground({0, 0, 0, 0});
    if (first.inputSource == shader_pipeline::OverlayInputSource::BaseSprite)
      DrawTextureRec(baseRT.texture, {0, 0, renderW, renderH}, {0, 0}, WHITE);
    else
      DrawTextureRec(postCache.texture, {0, 0, renderW, renderH}, {0, 0},
                     WHITE); // everything stays y-flipped
    render_stack_switch_internal::Pop();
  }

  // 6. Overlays
  for (auto &ov : pipeline.overlayDraws) {
    if (!ov.enabled)
      continue;
    Shader sh = shaders::getShader(ov.shaderName);
    if (!sh.id)
      continue;

    layer::render_stack_switch_internal::Push(shader_pipeline::front());
    BeginShaderMode(sh);
    if (ov.injectAtlasUniforms)
      injectAtlasUniforms(globals::getGlobalShaderUniforms(), ov.shaderName,
                          {0, 0, renderW, renderH}, {renderW, renderH});
    if (ov.customPrePassFunction)
      ov.customPrePassFunction();
    TryApplyUniforms(sh, globals::getGlobalShaderUniforms(), ov.shaderName);
    RenderTexture2D &src =
        (ov.inputSource == shader_pipeline::OverlayInputSource::BaseSprite)
            ? baseRT
            : postPassRT;
    DrawTextureRec(src.texture, {0, 0, renderW, renderH}, {0, 0},
                   WHITE); // y-flipped, maintained
    EndShaderMode();
    layer::render_stack_switch_internal::Pop();
    shader_pipeline::SetLastRenderTarget(shader_pipeline::back());
  }

  // 7. Choose final RT
  RenderTexture2D finalRT = !pipeline.overlayDraws.empty()
                                ? shader_pipeline::front()
                            : !pipeline.passes.empty() ? postCache
                                                       : baseRT;
  // restore camera if it was active
  if (camera) {
    camera_manager::Begin(*camera);
  }

  // now place the slice at the bounding‐box origin (xMin,yMin), not the last
  // entity
  Vector2 drawPos = {xMin - pad, yMin - pad};
  shader_pipeline::SetLastRenderRect({drawPos.x, drawPos.y, renderW, renderH});

  // Rectangle sourceRect = {0, 0, renderW, -renderH};
  sourceRect = {
      0.0f,                          // x
      (float)finalRT.texture.height, // y = start at top of the texture
      renderW,                       // width
      -renderH                       // negative height to flip back
  };

  Vector2 origin = {renderW * 0.5f, renderH * 0.5f};
  Vector2 position = {drawPos.x + origin.x, drawPos.y + origin.y};

  PushMatrix();
  Translate(position.x, position.y);
  Scale(visualScaleWithHover, // you did capture this from the last entity,
                              // which is fine if all in this slice share it
        visualScaleWithHover);
  Rotate(visualRotationWithDynamicMotion);
  Translate(-origin.x, -origin.y);

  // final blit
  DrawTextureRec(finalRT.texture, sourceRect, {0, 0}, WHITE);

  PopMatrix();
}

auto AddDrawTransformEntityWithAnimation(std::shared_ptr<Layer> layer,
                                         entt::registry *registry,
                                         entt::entity e, int z) -> void {
  AddDrawCommand(layer, "draw_transform_entity_animation", {e, registry}, z);
}

auto DrawTransformEntityWithAnimation(entt::registry &registry, entt::entity e)
    -> void {
  // AQC gate (unchanged)
  if (registry.any_of<AnimationQueueComponent>(e)) {
    auto &aqc = registry.get<AnimationQueueComponent>(e);
    if (aqc.noDraw)
      return;
  }

  // -------- Gather state --------
  const bool hasAQC = registry.any_of<AnimationQueueComponent>(e);
  const bool hasCB = registry.any_of<transform::RenderLocalCallback>(e);

  float renderScale = 1.0f;

  Rectangle *animationFrame = nullptr;
  SpriteComponentASCII *currentSprite = nullptr;
  bool flipX{false}, flipY{false};

  if (hasAQC) {
    auto &aqc = registry.get<AnimationQueueComponent>(e);
    if (aqc.animationQueue.empty()) {
      if (!aqc.defaultAnimation.animationList.empty()) {
        animationFrame =
            &aqc.defaultAnimation
                 .animationList[aqc.defaultAnimation.currentAnimIndex]
                 .first.spriteData.frame;
        currentSprite =
            &aqc.defaultAnimation
                 .animationList[aqc.defaultAnimation.currentAnimIndex]
                 .first;
        flipX = aqc.defaultAnimation.flippedHorizontally;
        flipY = aqc.defaultAnimation.flippedVertically;
        renderScale =
            aqc.defaultAnimation.intrinsincRenderScale.value_or(1.0f) *
            aqc.defaultAnimation.uiRenderScale.value_or(1.0f);
      }
    } else {
      auto &cur = aqc.animationQueue[aqc.currentAnimationIndex];
      animationFrame =
          &cur.animationList[cur.currentAnimIndex].first.spriteData.frame;
      currentSprite = &cur.animationList[cur.currentAnimIndex].first;
      flipX = cur.flippedHorizontally;
      flipY = cur.flippedVertically;
      renderScale = cur.intrinsincRenderScale.value_or(1.0f) *
                    cur.uiRenderScale.value_or(1.0f);
    }
  }

  using namespace snowhouse;
  // If there is NO AQC, we allow callback to supply the visuals.
  if (!hasCB) {
    // Original asserts stay for the sprite path
    AssertThat(animationFrame, Is().Not().Null());
    AssertThat(currentSprite, Is().Not().Null());
  }

  Texture2D *spriteAtlas =
      currentSprite ? currentSprite->spriteData.texture : nullptr;

  // Content size:
  float renderWidth = 0.f;
  float renderHeight = 0.f;

  if (animationFrame) {
    renderWidth = animationFrame->width;
    renderHeight = animationFrame->height;
  } else if (hasCB) {
    const auto &cb = registry.get<transform::RenderLocalCallback>(e);
    renderWidth = cb.contentWidth;
    renderHeight = cb.contentHeight;
  }

  AssertThat(renderWidth, IsGreaterThan(0.0f));
  AssertThat(renderHeight, IsGreaterThan(0.0f));

  float flipXModifier = flipX ? -1.0f : 1.0f;
  float flipYModifier = flipY ? -1.0f : 1.0f;

  // Colors (kept for background rectangle + sprite tint)
  Color bgColor = {0, 0, 0, 0};
  Color fgColor = WHITE;
  bool drawBackground = false;
  bool drawForeground = true;

  if (currentSprite) {
    bgColor = currentSprite->bgColor;
    fgColor = currentSprite->fgColor;
    if (fgColor.a <= 0)
      fgColor = WHITE; // safety
    drawBackground = !currentSprite->noBackgroundColor;
    drawForeground = !currentSprite->noForegroundColor;
    // (Your forced debug)
    drawForeground = true;
  }

  auto &transform = registry.get<transform::Transform>(e);

  // -------- World transform (unchanged) --------
  PushMatrix();
  Translate(transform.getVisualX() + transform.getVisualW() * 0.5f,
            transform.getVisualY() + transform.getVisualH() * 0.5f);
  Scale(transform.getVisualScaleWithHoverAndDynamicMotionReflected(),
        transform.getVisualScaleWithHoverAndDynamicMotionReflected());
  Rotate(transform.getVisualRWithDynamicMotionAndXLeaning());
  Translate(-transform.getVisualW() * 0.5f, -transform.getVisualH() * 0.5f);

  // Background rectangle if desired (applies to both sprite and callback
  // content)
  if (drawBackground) {
    layer::RectanglePro(0, 0, {renderWidth, renderHeight}, {0, 0}, 0, bgColor);
  }

  // -------- Foreground draw --------
  if (drawForeground) {
    // If we have a callback, it takes precedence over sprite drawing
    if (hasCB) {
      const auto &cb = registry.get<transform::RenderLocalCallback>(e);

      // Optional shadow pass (mirrors your sprite shadow behavior)
      if (registry.any_of<transform::GameObject>(e)) {
        auto &node = registry.get<transform::GameObject>(e);
        if (node.shadowDisplacement) {
          float baseEx = globals::getBaseShadowExaggeration();
          float hFact = 1.0f + node.shadowHeight.value_or(0.f);
          float shX = node.shadowDisplacement->x * baseEx * hFact;
          float shY = node.shadowDisplacement->y * baseEx * hFact;

          Color shadowColor = Fade(BLACK, 0.8f);
          // We can't force-tint arbitrary callback draw; we just position the
          // shadow version. Let the callback optionally branch on isShadow.
          Translate(-shX, shY);
          Scale(renderScale, renderScale);
          cb.fn(renderWidth, renderHeight, /*isShadow=*/true);
          Scale(1.0f / renderScale, 1.0f / renderScale);
          Translate(shX, -shY);
        }
      }

      // Main callback draw at local (0,0)
      Scale(renderScale, renderScale);
      cb.fn(renderWidth, renderHeight, /*isShadow=*/false);
      Scale(1.0f / renderScale, 1.0f / renderScale);

    } else if (animationFrame && spriteAtlas) {
      // Original sprite path (unchanged)
      if (registry.any_of<transform::GameObject>(e)) {
        auto &node = registry.get<transform::GameObject>(e);
        if (node.shadowDisplacement) {
          float baseEx = globals::getBaseShadowExaggeration();
          float hFact = 1.0f + node.shadowHeight.value_or(0.f);
          float shX = node.shadowDisplacement->x * baseEx * hFact;
          float shY = node.shadowDisplacement->y * baseEx * hFact;
          Color shadowColor = Fade(BLACK, 0.8f);

          Translate(-shX, shY);
          Scale(renderScale, renderScale);
          layer::TexturePro(
              *spriteAtlas,
              {animationFrame->x, animationFrame->y,
               animationFrame->width * flipXModifier,
               animationFrame->height * flipYModifier},
              0, 0, {renderWidth * flipXModifier, renderHeight * flipYModifier},
              {0, 0}, 0, shadowColor);
          Scale(1.0f / renderScale, 1.0f / renderScale);
          Translate(shX, -shY);
        }
      }

      Scale(renderScale, renderScale);
      layer::TexturePro(*spriteAtlas,
                        {animationFrame->x, animationFrame->y,
                         animationFrame->width * flipXModifier,
                         animationFrame->height * flipYModifier},
                        0, 0, {renderWidth, renderHeight}, {0, 0}, 0, fgColor);
      Scale(1.0f / renderScale, 1.0f / renderScale);

    } else {
      // Fallback rect if neither sprite nor callback (unlikely due to asserts)
      layer::RectanglePro(0, 0, {renderWidth, renderHeight}, {0, 0}, 0,
                          fgColor);
    }
  }

  PopMatrix();
}

auto AddDrawEntityWithAnimation(std::shared_ptr<Layer> layer,
                                entt::registry *registry, entt::entity e, int x,
                                int y, int z) -> void {
  AddDrawCommand(layer, "draw_entity_animation", {e, registry, x, y}, z);
}

// deprecated
auto DrawEntityWithAnimation(entt::registry &registry, entt::entity e, int x,
                             int y) -> void {

  // Fetch the animation frame if the entity has an animation queue
  Rectangle *animationFrame = nullptr;
  SpriteComponentASCII *currentSprite = nullptr;

  if (registry.any_of<AnimationQueueComponent>(e)) {
    auto &aqc = registry.get<AnimationQueueComponent>(e);

    // Use the current animation frame or the default frame
    if (aqc.animationQueue.empty()) {
      if (!aqc.defaultAnimation.animationList.empty()) {
        animationFrame =
            &aqc.defaultAnimation
                 .animationList[aqc.defaultAnimation.currentAnimIndex]
                 .first.spriteData.frame;
        currentSprite =
            &aqc.defaultAnimation
                 .animationList[aqc.defaultAnimation.currentAnimIndex]
                 .first;
      }
    } else {
      auto &currentAnimObject = aqc.animationQueue[aqc.currentAnimationIndex];
      animationFrame =
          &currentAnimObject.animationList[currentAnimObject.currentAnimIndex]
               .first.spriteData.frame;
      currentSprite =
          &currentAnimObject.animationList[currentAnimObject.currentAnimIndex]
               .first;
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

  if (currentSprite) {
    bgColor = currentSprite->bgColor;
    fgColor = currentSprite->fgColor;
    drawBackground = !currentSprite->noBackgroundColor;
    drawForeground = !currentSprite->noForegroundColor;
  }

  // Draw background rectangle if enabled
  if (drawBackground) {
    layer::RectanglePro(x, y, {renderWidth, renderHeight}, {0, 0}, 0,
                        {bgColor.r, bgColor.g, bgColor.b, bgColor.a});
  }

  // Draw the animation frame or a default rectangle if no animation is present
  if (!drawForeground)
    return;

  auto &node = registry.get<transform::GameObject>(e);

  if (animationFrame) {

    if (node.shadowDisplacement) {
      float baseExaggeration = globals::getBaseShadowExaggeration();
      float heightFactor = 1.0f + node.shadowHeight.value_or(
                                      0.f); // Increase effect based on height

      // Adjust displacement using shadow height
      float shadowOffsetX =
          node.shadowDisplacement->x * baseExaggeration * heightFactor;
      float shadowOffsetY =
          node.shadowDisplacement->y * baseExaggeration * heightFactor;

      float shadowAlpha = 0.8f; // 0.0f to 1.0f
      Color shadowColor = Fade(BLACK, shadowAlpha);

      // Translate to shadow position
      Translate(-shadowOffsetX, shadowOffsetY);

      // Draw shadow by rendering the same frame with a black tint and offset
      layer::TexturePro(spriteAtlas,
                        {animationFrame->x, animationFrame->y,
                         animationFrame->width, animationFrame->height},
                        0, 0, {renderWidth, renderHeight}, {0, 0}, 0,
                        shadowColor);

      // Reset translation to original position
      Translate(shadowOffsetX, -shadowOffsetY);
    }

    // draw main image

    layer::TexturePro(spriteAtlas,
                      {animationFrame->x, animationFrame->y,
                       animationFrame->width, animationFrame->height},
                      x, y, {renderWidth, renderHeight}, {0, 0}, 0,
                      {fgColor.r, fgColor.g, fgColor.b, fgColor.a});
  } else {
    layer::RectanglePro(x, y, {renderWidth, renderHeight}, {0, 0}, 0,
                        {fgColor.r, fgColor.g, fgColor.b, fgColor.a});
  }
}

// Pushes the transform commands for an entity's transform component onto the
// layer's command queue. remember to pair with a CmdPopMatrix!
auto pushEntityTransformsToMatrix(entt::registry &registry, entt::entity e,
                                  Layer* layer,
                                  int zOrder) -> void {
  // Determine whether the entity renders in world or screen space.
  bool isScreenSpace =
      registry.any_of<collision::ScreenSpaceCollisionMarker>(e);
  layer::DrawCommandSpace drawSpace = isScreenSpace
                                          ? layer::DrawCommandSpace::Screen
                                          : layer::DrawCommandSpace::World;

  // Retrieve the transform (and any needed springs)
  auto &entityTransform = registry.get<transform::Transform>(e);

  // --- Push Matrix ---
  layer::QueueCommand<layer::CmdPushMatrix>(
      layer, [](layer::CmdPushMatrix *cmd) {}, zOrder, drawSpace);

  // --- Apply Translation: move to entity center ---
  layer::QueueCommand<layer::CmdTranslate>(
      layer,
      [x = entityTransform.getVisualX() + entityTransform.getVisualW() * 0.5f,
       y = entityTransform.getVisualY() +
           entityTransform.getVisualH() * 0.5f](layer::CmdTranslate *cmd) {
        cmd->x = x;
        cmd->y = y;
      },
      zOrder, drawSpace);

  // --- Apply Scaling ---
  layer::QueueCommand<layer::CmdScale>(
      layer,
      [scaleX =
           entityTransform.getVisualScaleWithHoverAndDynamicMotionReflected(),
       scaleY =
           entityTransform.getVisualScaleWithHoverAndDynamicMotionReflected()](
          layer::CmdScale *cmd) {
        cmd->scaleX = scaleX;
        cmd->scaleY = scaleY;
      },
      zOrder, drawSpace);

  // --- Apply Rotation ---
  layer::QueueCommand<layer::CmdRotate>(
      layer,
      [rotation = entityTransform.getVisualR() +
                  entityTransform.rotationOffset](layer::CmdRotate *cmd) {
        cmd->angle = rotation;
      },
      zOrder, drawSpace);

  // --- Translate back to local origin ---
  layer::QueueCommand<layer::CmdTranslate>(
      layer,
      [x = -entityTransform.getVisualW() * 0.5f,
       y = -entityTransform.getVisualH() * 0.5f](layer::CmdTranslate *cmd) {
        cmd->x = x;
        cmd->y = y;
      },
      zOrder, drawSpace);
}

auto pushEntityTransformsToMatrixImmediate(entt::registry &registry,
                                           entt::entity e,
                                           Layer* layer,
                                           int zOrder) -> void {
  auto &t = registry.get<transform::Transform>(e);

  PushMatrix();
  rlMultMatrixf(MatrixToFloat(t.cachedMatrix));
}

void Circle(float x, float y, float radius, const Color &color) {
  DrawCircle(static_cast<int>(x), static_cast<int>(y), radius,
             {color.r, color.g, color.b, color.a});
}

void CircleLine(float x, float y, float innerRadius, float outerRadius,
                float startAngle, float endAngle, int segments,
                const Color &color) {
  DrawRing({x, y}, innerRadius, outerRadius, startAngle, endAngle, segments,
           {color.r, color.g, color.b, color.a});
}

void Line(float x1, float y1, float x2, float y2, const Color &color,
          float lineWidth) {
  DrawLineEx({x1, y1}, {x2, y2}, lineWidth,
             {color.r, color.g, color.b, color.a});
}

void RectangleDraw(float x, float y, float width, float height,
                   const Color &color, float lineWidth) {
  if (lineWidth == 0.0f) {
    DrawRectangle(static_cast<int>(x - width / 2),
                  static_cast<int>(y - height / 2), static_cast<int>(width),
                  static_cast<int>(height),
                  {color.r, color.g, color.b, color.a});
  } else {
    DrawRectangleLinesEx({x - width / 2, y - height / 2, width, height},
                         lineWidth, {color.r, color.g, color.b, color.a});
  }
}

void AddRectangle(std::shared_ptr<Layer> layer, float x, float y, float width,
                  float height, const Color &color, float lineWidth, int z) {
  AddDrawCommand(layer, "rectangle", {x, y, width, height, color, lineWidth},
                 z);
}

void DashedLine(float x1, float y1, float x2, float y2, float dashSize,
                float gapSize, const Color &color, float lineWidth) {
  float dx = x2 - x1;
  float dy = y2 - y1;
  float len = sqrt(dx * dx + dy * dy);
  float step = dashSize + gapSize;
  float angle = atan2(dy, dx);

  for (float i = 0; i < len; i += step) {
    float startX = x1 + cos(angle) * i;
    float startY = y1 + sin(angle) * i;
    float endX = x1 + cos(angle) * std::min(i + dashSize, len);
    float endY = y1 + sin(angle) * std::min(i + dashSize, len);
    DrawLineEx({startX, startY}, {endX, endY}, lineWidth,
               {color.r, color.g, color.b, color.a});
  }
}

void AddDashedLine(std::shared_ptr<Layer> layer, float x1, float y1, float x2,
                   float y2, float dashSize, float gapSize, const Color &color,
                   float lineWidth, int z) {
  AddDrawCommand(layer, "dashed_line",
                 {x1, y1, x2, y2, dashSize, gapSize, color, lineWidth}, z);
}

void AddLine(std::shared_ptr<Layer> layer, float x1, float y1, float x2,
             float y2, const Color &color, float lineWidth, int z) {
  AddDrawCommand(layer, "line", {x1, y1, x2, y2, color, lineWidth}, z);
}

void Polygon(const std::vector<Vector2> &vertices, const Color &color,
             float lineWidth) {
  if (lineWidth == 0.0f) {
    DrawPoly(vertices[0], vertices.size(), vertices[1].x, vertices[1].y,
             {color.r, color.g, color.b, color.a});
  } else {
    DrawLineStrip(const_cast<std::vector<Vector2> &>(vertices).data(),
                  vertices.size(), {color.r, color.g, color.b, color.a});
  }
}

void AddPolygon(std::shared_ptr<Layer> layer,
                const std::vector<Vector2> &vertices, const Color &color,
                float lineWidth, int z) {
  AddDrawCommand(layer, "polygon", {vertices, color, lineWidth}, z);
}

void Triangle(Vector2 p1, Vector2 p2, Vector2 p3, const Color &color) {
  DrawTriangle(p2, p1, p3, {color.r, color.g, color.b, color.a});
}

void AddTriangle(std::shared_ptr<Layer> layer, Vector2 p1, Vector2 p2,
                 Vector2 p3, const Color &color, int z) {
  AddDrawCommand(layer, "triangle", {p1, p2, p3, color}, z);
}

void Push(Camera2D *camera) { BeginMode2D(*camera); }

void Pop() { EndMode2D(); }

void AddPush(std::shared_ptr<Layer> layer, Camera2D *camera, int z) {
  AddDrawCommand(layer, "push", {camera}, z);
}

void AddPop(std::shared_ptr<Layer> layer, int z) {
  AddDrawCommand(layer, "pop", {}, z);
}

void Rotate(float angle) { rlRotatef(angle, 0.0f, 0.0f, 1.0f); }

void AddRotate(std::shared_ptr<Layer> layer, float angle, int z) {
  AddDrawCommand(layer, "rotate", {angle}, z);
}

void Scale(float scaleX, float scaleY) {
  // SPDLOG_DEBUG("Set layer scale: {} {}", scaleX, scaleY);
  rlScalef(scaleX, scaleY, 1.0f);
}

void AddScale(std::shared_ptr<Layer> layer, float scaleX, float scaleY, int z) {
  AddDrawCommand(layer, "scale", {scaleX, scaleY}, z);
}

void SetShader(const Shader &shader) { BeginShaderMode(shader); }

void ResetShader() { EndShaderMode(); }

void AddSetShader(std::shared_ptr<Layer> layer, const Shader &shader, int z) {
  AddDrawCommand(layer, "set_shader", {shader}, z);
}

void AddResetShader(std::shared_ptr<Layer> layer, int z) {
  AddDrawCommand(layer, "reset_shader", {}, z);
}

void DrawImage(const Texture2D &image, float x, float y, float rotation,
               float scaleX, float scaleY, const Color &color) {
  DrawTextureEx(image, {x, y}, rotation, scaleX,
                {color.r, color.g, color.b, color.a});
}

void AddDrawImage(std::shared_ptr<Layer> layer, const Texture2D &image, float x,
                  float y, float rotation, float scaleX, float scaleY,
                  const Color &color, int z) {
  AddDrawCommand(layer, "draw_image",
                 {image, x, y, rotation, scaleX, scaleY, color}, z);
}

void DrawTextCentered(const std::string &text, const Font &font, float x,
                      float y, const Color &color, float fontSize) {
  Vector2 textSize = MeasureTextEx(font, text.c_str(), fontSize, 1.0f);
  DrawTextEx(font, text.c_str(), {x - textSize.x / 2, y - textSize.y / 2},
             fontSize, 1.0f, {color.r, color.g, color.b, color.a});
}

void AddDrawTextCentered(std::shared_ptr<Layer> layer, const std::string &text,
                         const Font &font, float x, float y, const Color &color,
                         float fontSize, int z) {
  AddDrawCommand(layer, "draw_text_centered",
                 {text, font, x, y, color, fontSize}, z);
}

void SetBlendMode(int blendMode) { ::BeginBlendMode((BlendMode)blendMode); }

void UnsetBlendMode() { ::EndBlendMode(); }

void AddSetBlendMode(std::shared_ptr<Layer> layer, int blendMode, int z) {
  AddDrawCommand(layer, "set_blend_mode", {blendMode}, z);
}

void AddUnsetBlendMode(std::shared_ptr<Layer> layer, int z) {
  AddDrawCommand(layer, "unset_blend_mode", {-1}, z);
}

void AddUniformFloat(std::shared_ptr<Layer> layer, Shader shader,
                     const std::string &uniform, float value) {
  layer->drawCommands.push_back(
      {"send_uniform_float", {shader, uniform, value}});
}

void SendUniformFloat(Shader &shader, const std::string &uniform, float value) {
  SetShaderValue(shader, GetShaderLocation(shader, uniform.c_str()), &value,
                 SHADER_UNIFORM_FLOAT);
}

void AddUniformInt(std::shared_ptr<Layer> layer, Shader shader,
                   const std::string &uniform, int value) {
  layer->drawCommands.push_back({"send_uniform_int", {shader, uniform, value}});
}

void SendUniformInt(Shader &shader, const std::string &uniform, int value) {
  SetShaderValue(shader, GetShaderLocation(shader, uniform.c_str()), &value,
                 SHADER_UNIFORM_INT);
}

void AddUniformVector2(std::shared_ptr<Layer> layer, Shader shader,
                       const std::string &uniform, const Vector2 &value) {
  layer->drawCommands.push_back(
      {"send_uniform_vec2", {shader, uniform, value}});
}

void SendUniformVector2(Shader &shader, const std::string &uniform,
                        const Vector2 &value) {
  SetShaderValue(shader, GetShaderLocation(shader, uniform.c_str()), &value,
                 SHADER_UNIFORM_VEC2);
}

void AddUniformVector3(std::shared_ptr<Layer> layer, Shader shader,
                       const std::string &uniform, const Vector3 &value) {
  layer->drawCommands.push_back(
      {"send_uniform_vec3", {shader, uniform, value}});
}

void SendUniformVector3(Shader &shader, const std::string &uniform,
                        const Vector3 &value) {
  SetShaderValue(shader, GetShaderLocation(shader, uniform.c_str()), &value,
                 SHADER_UNIFORM_VEC3);
}

void AddUniformVector4(std::shared_ptr<Layer> layer, Shader shader,
                       const std::string &uniform, const Vector4 &value) {
  layer->drawCommands.push_back(
      {"send_uniform_vec4", {shader, uniform, value}});
}

void SendUniformVector4(Shader &shader, const std::string &uniform,
                        const Vector4 &value) {
  SetShaderValue(shader, GetShaderLocation(shader, uniform.c_str()), &value,
                 SHADER_UNIFORM_VEC4);
}

void AddUniformFloatArray(std::shared_ptr<Layer> layer, Shader shader,
                          const std::string &uniform, const float *values,
                          int count) {
  std::vector<float> array(values, values + count);
  AddDrawCommand(layer, "send_uniform_float_array",
                 std::vector<DrawCommandArgs>{shader, uniform, array}, 0);
}

void SendUniformFloatArray(Shader &shader, const std::string &uniform,
                           const float *values, int count) {
  SetShaderValue(shader, GetShaderLocation(shader, uniform.c_str()), values,
                 SHADER_UNIFORM_FLOAT);
}

void AddUniformIntArray(std::shared_ptr<Layer> layer, Shader shader,
                        const std::string &uniform, const int *values,
                        int count) {
  std::vector<int> array(values, values + count);
  AddDrawCommand(layer, "send_uniform_int_array",
                 std::vector<DrawCommandArgs>{shader, uniform, array}, 0);
}

void SendUniformIntArray(Shader &shader, const std::string &uniform,
                         const int *values, int count) {
  SetShaderValue(shader, GetShaderLocation(shader, uniform.c_str()), values,
                 SHADER_UNIFORM_INT);
}

void PushMatrix() { rlPushMatrix(); }

void AddPushMatrix(std::shared_ptr<Layer> layer, int z) {
  AddDrawCommand(layer, "push_matrix", {}, z);
}

void PopMatrix() {
  // SPDLOG_DEBUG("Pop layer matrix");
  rlPopMatrix();
}

void AddPopMatrix(std::shared_ptr<Layer> layer, int z) {
  AddDrawCommand(layer, "pop_matrix", {}, z);
}

void Translate(float x, float y) { rlTranslatef(x, y, 0); }

void AddTranslate(std::shared_ptr<Layer> layer, float x, float y, int z) {
  AddDrawCommand(layer, "translate", {x, y}, z);
}

void Text(const std::string &text, Font font, float x, float y,
          const Color &color, float fontSize) {
  DrawTextEx(font, text.c_str(), {x, y}, fontSize, 1.0f,
             {color.r, color.g, color.b, color.a});
}

void AddText(std::shared_ptr<Layer> layer, const std::string &text, Font font,
             float x, float y, const Color &color, float fontSize, int z) {
  AddDrawCommand(layer, "text", {text, font, x, y, color, fontSize}, z);
}

void TextPro(const std::string &text, Font font, float x, float y,
             const Vector2 &origin, float rotation, float fontSize,
             float spacing, const Color &color) {
  DrawTextPro(font, text.c_str(), {x, y}, origin, rotation, fontSize, spacing,
              {color.r, color.g, color.b, color.a});
}

void AddTextPro(std::shared_ptr<Layer> layer, const std::string &text,
                Font font, float x, float y, const Vector2 &origin,
                float rotation, float fontSize, float spacing,
                const Color &color, int z) {
  AddDrawCommand(layer, "textPro",
                 {text, font, x, y, origin, rotation, fontSize, spacing, color},
                 z);
}

void RectanglePro(float offsetX, float offsetY, const Vector2 &size,
                  const Vector2 &rotationCenter, float rotation,
                  const Color &color) {
  struct Rectangle rect = {offsetX, offsetY, size.x, size.y};
  DrawRectanglePro(rect, rotationCenter, rotation, color);
}

void AddRectanglePro(std::shared_ptr<Layer> layer, float offsetX, float offsetY,
                     const Vector2 &size, const Color &color,
                     const Vector2 &rotationCenter, float rotation, int z) {
  AddDrawCommand(layer, "rectanglePro",
                 {offsetX, offsetY, size, rotationCenter, rotation, color}, z);
}

void TexturePro(Texture2D texture, const struct Rectangle &source,
                float offsetX, float offsetY, const Vector2 &size,
                const Vector2 &rotationCenter, float rotation,
                const Color &color) {
  struct Rectangle dest = {offsetX, offsetY, size.x, size.y};
  DrawTexturePro(texture, source, dest, rotationCenter, rotation, color);
}

void AddTexturePro(std::shared_ptr<Layer> layer, Texture2D texture,
                   const struct Rectangle &source, float offsetX, float offsetY,
                   const Vector2 &size, const Vector2 &rotationCenter,
                   float rotation, const Color &color, int z) {
  AddDrawCommand(layer, "texturePro",
                 {texture, source, offsetX, offsetY, size, rotationCenter,
                  rotation, color},
                 z);
}

void RectangleLinesPro(float offsetX, float offsetY, const Vector2 &size,
                       float lineThickness, const Color &color) {
  struct Rectangle rect = {offsetX, offsetY, size.x, size.y};
  DrawRectangleLinesEx(rect, lineThickness, color);
}

void AddRectangleLinesPro(std::shared_ptr<Layer> layer, float offsetX,
                          float offsetY, const Vector2 &size,
                          float lineThickness, const Color &color, int z) {
  AddDrawCommand(layer, "rectangleLinesPro",
                 {offsetX, offsetY, size, lineThickness, color}, z);
}

void AddBeginDrawing(std::shared_ptr<Layer> layer) {
  layer->drawCommands.push_back({"begin_drawing", {}});
}

void BeginDrawingAction() { ::BeginDrawing(); }

void AddEndDrawing(std::shared_ptr<Layer> layer) {
  layer->drawCommands.push_back({"end_drawing", {}});
}

void EndDrawingAction() { ::EndDrawing(); }

void AddClearBackground(std::shared_ptr<Layer> layer, Color color) {
  AddDrawCommand(layer, "clear_background", {color}, 0);
}

void ClearBackgroundAction(Color color) { ::ClearBackground(color); }

// Draws an animated dashed line between 'start' and 'end'.
// 'dashLength' and 'gapLength' define the pattern in world units.
// 'phase' shifts the pattern along the line (advance it by phase units).
// 'thickness' is the line width.
// 'color' is the line color.
auto DrawDashedLine(const Vector2 &start, const Vector2 &end, float dashLength,
                    float gapLength, float phase, float thickness, Color color)
    -> void {
  const float dx = end.x - start.x;
  const float dy = end.y - start.y;
  const float length = std::sqrt(dx * dx + dy * dy);
  if (length <= 0.0f)
    return;

  // Normalize direction
  const float dirX = dx / length;
  const float dirY = dy / length;

  const float pattern = dashLength + gapLength;
  phase = std::fmod(phase, pattern);

  // Start at -phase so we shift the dashes forward
  float pos = -phase;
  while (pos < length) {
    float segStart = (pos < 0) ? 0 : pos;
    float segEnd = (pos + dashLength > length) ? length : pos + dashLength;

    if (segEnd > 0.0f) {
      Vector2 p1 = {start.x + dirX * segStart, start.y + dirY * segStart};
      Vector2 p2 = {start.x + dirX * segEnd, start.y + dirY * segEnd};
      DrawLineEx(p1, p2, thickness, color);
    }
    pos += pattern;
  }
}

static constexpr float EPSILON_SEAM = 1e-4f;
// Draw a dashed rectangle (optionally rounded).
// rec        : The rectangle area.
// dashLength : Length of each dash (in pixels).
// gapLength  : Length of each gap between dashes.
// phase      : Shift along the perimeter (in pixels).
// radius     : Corner radius. If <= 0, corners are sharp.
// segments   : Resolution for approximating curved dashes (full-circle
// subdivision). thickness  : Line thickness. color      : Line color.

void DrawDashedPolylineLoop(const std::vector<Vector2> &pts,
                            const std::vector<float> &cum, float dashLen,
                            float gapLen, float phase, float thickness,
                            Color color) {
  float total = cum.back();
  float pattern = dashLen + gapLen;

  // normalize phase into [0,pattern)
  phase = std::fmod(phase, pattern);
  if (phase < 0)
    phase += pattern;

  auto EvalPos = [&](float dist) {
    // wrap into [0,total)
    dist = std::fmod(dist, total);
    if (dist < 0)
      dist += total;
    // binary-search segment
    auto it = std::upper_bound(cum.begin(), cum.end(), dist);
    int idx = std::clamp(int(it - cum.begin()) - 1, 0, (int)pts.size() - 1);
    float local = (dist - cum[idx]) / (cum[idx + 1] - cum[idx]);
    Vector2 A = pts[idx];
    Vector2 B = pts[(idx + 1) % pts.size()];
    return Vector2{A.x + (B.x - A.x) * local, A.y + (B.y - A.y) * local};
  };

  // step the dash window
  for (float t = -phase; t < total; t += pattern) {
    float start = t;
    float end = t + dashLen;

    if (end <= total) {
      Vector2 P0 = EvalPos(start), P1 = EvalPos(end);
      DrawLineEx(P0, P1, thickness, color);
    } else {
      // two-part dash: tail + head
      Vector2 P0 = EvalPos(start);
      Vector2 Pmid = EvalPos(total);
      DrawLineEx(P0, Pmid, thickness, color);
      Vector2 P1 = EvalPos(end);
      Vector2 PheadStart = EvalPos(0.0f);
      DrawLineEx(PheadStart, P1, thickness, color);
    }
  }
}

static std::vector<Vector2> BuildPerimeter(const Rectangle &rec, float radius,
                                           int arcSteps) {
  std::vector<Vector2> pts;
  pts.reserve(4 * arcSteps + 8);

  float x = rec.x, y = rec.y, w = rec.width, h = rec.height;
  float R = std::clamp(radius, 0.0f, std::min(w, h) * 0.5f);

  // 1. Top edge
  pts.push_back({x + R, y});
  pts.push_back({x + w - R, y});

  // 2. Top-right quarter-arc (270°→360°), EXCLUDE both end-points
  for (int i = 1; i < arcSteps; ++i) {
    float a = 1.5f * PI + (PI / 2) * (i / (float)arcSteps);
    pts.push_back({x + w - R + std::cos(a) * R, y + R + std::sin(a) * R});
  }

  // 3. Right edge
  pts.push_back({x + w, y + R});
  pts.push_back({x + w, y + h - R});

  // 4. Bottom-right quarter-arc (0°→90°)
  for (int i = 1; i < arcSteps; ++i) {
    float a = 0.0f + (PI / 2) * (i / (float)arcSteps);
    pts.push_back({x + w - R + std::cos(a) * R, y + h - R + std::sin(a) * R});
  }

  // 5. Bottom edge
  pts.push_back({x + w - R, y + h});
  pts.push_back({x + R, y + h});

  // 6. Bottom-left quarter-arc (90°→180°)
  for (int i = 1; i < arcSteps; ++i) {
    float a = 0.5f * PI + (PI / 2) * (i / (float)arcSteps);
    pts.push_back({x + R + std::cos(a) * R, y + h - R + std::sin(a) * R});
  }

  // 7. Left edge
  pts.push_back({x, y + h - R});
  pts.push_back({x, y + R});

  // 8. Top-left quarter-arc (180°→270°)
  for (int i = 1; i < arcSteps; ++i) {
    float a = PI + (PI / 2) * (i / (float)arcSteps);
    pts.push_back({x + R + std::cos(a) * R, y + R + std::sin(a) * R});
  }

  return pts;
}

static std::vector<float> BuildCumLengths(const std::vector<Vector2> &pts) {
  int m = (int)pts.size();
  std::vector<float> cum(m + 1, 0.0f);
  for (int i = 0; i < m; ++i) {
    float dx = pts[i + 1 == m ? 0 : i + 1].x - pts[i].x;
    float dy = pts[i + 1 == m ? 0 : i + 1].y - pts[i].y;
    cum[i + 1] = cum[i] + std::hypot(dx, dy);
  }
  return cum;
}

void DrawDashedRoundedRect(const Rectangle &rec, float dashLen, float gapLen,
                           float phase, float radius, int arcSteps,
                           float thickness, Color color) {
  static std::vector<Vector2> perimeter;
  static std::vector<float> cumLen;

  // Rebuild only if your rec/radius/arcSteps change:
  perimeter = BuildPerimeter(rec, radius, arcSteps);
  cumLen = BuildCumLengths(perimeter);

  DrawDashedPolylineLoop(perimeter, cumLen, dashLen, gapLen, phase, thickness,
                         color);
}

// Draws an animated dashed circle centered at 'center' with radius 'radius'.
// 'dashLength' and 'gapLength' define the pattern along the circumference.
// 'phase' shifts the pattern around the circle (advance by phase units).
// 'segments' is the resolution for approximating each dash arc.
// 'thickness' is the line width, 'color' is the circle color.
auto DrawDashedCircle(const Vector2 &center, float radius, float dashLength,
                      float gapLength, float phase, int segments,
                      float thickness, Color color) -> void {
  // circumference-based pattern
  const float pattern = dashLength + gapLength;
  // clamp phase to [0, pattern)
  phase = std::fmod(phase, pattern);
  if (phase < 0)
    phase += pattern;

  // angles in radians
  const float dashAng = dashLength / radius;
  const float gapAng = gapLength / radius;
  const float phaseAng = phase / radius;

  // we'll do two sweeps: main, then wrapped
  auto drawSweep = [&](float startTheta, float endTheta) {
    float theta = startTheta;
    while (theta < endTheta) {
      float segStart = std::max(theta, startTheta);
      float segEnd = std::min(theta + dashAng, endTheta);
      if (segEnd > segStart) {
        // approximate arc by subdividing proportional to full-circle segments
        int arcSegs = std::max(
            1, (int)std::ceil((segEnd - segStart) / (2.0f * PI) * segments));
        for (int i = 0; i < arcSegs; ++i) {
          float t1 = segStart + (segEnd - segStart) * i / (float)arcSegs;
          float t2 = segStart + (segEnd - segStart) * (i + 1) / (float)arcSegs;
          Vector2 p1 = {center.x + std::cos(t1) * radius,
                        center.y + std::sin(t1) * radius};
          Vector2 p2 = {center.x + std::cos(t2) * radius,
                        center.y + std::sin(t2) * radius};
          DrawLineEx(p1, p2, thickness, color);
        }
      }
      theta += dashAng + gapAng;
    }
  };

  // Primary arc from -phaseAng to (2π - phaseAng)
  drawSweep(-phaseAng, 2 * PI - phaseAng);

  // Wrapped arc: shift by +2π so any dash spilling over the top is drawn
  drawSweep(2 * PI - phaseAng, 2 * (2 * PI) - phaseAng);
}

// -- new shape calls
float rad2deg(float r) { return r * 180.0f / PI; }

// Pick a reasonable default tessellation for arcs/rings based on radius.
// Raylib wants an explicit segment count for DrawRing/DrawCircleSector.
int autoSegments(float radius) {
  // ~ 1 segment per 6 px of circumference, clamped.
  int seg = std::max(12, (int)std::round((2.0f * PI * radius) / 6.0f));
  return std::min(seg, 256);
}

// Convenience: default color when user doesn't supply one (mirrors LÖVE
// "state") We just pick WHITE; Raylib doesn't track a global draw color.
Color defaultColor() { return WHITE; }

// -----------------------------------------------------------------------------
// Arc types (LÖVE has "pie", "open", "closed")
// -----------------------------------------------------------------------------

ArcType ArcTypeFromString(const char *s) {
  if (!s)
    return ArcType::Open;
  if (std::strcmp(s, "pie") == 0)
    return ArcType::Pie;
  if (std::strcmp(s, "closed") == 0)
    return ArcType::Closed;
  // LÖVE also uses "open"
  return ArcType::Open;
}

// -----------------------------------------------------------------------------
// Rectangle centered at (x,y). Optional rounded corners.
// rx, ry are pixel radii in LÖVE; Raylib only supports a single roundness.
// We map to roundness = min(rx,ry)/min(w,h). Different rx/ry are approximated.
// -----------------------------------------------------------------------------
void rectangle(float x, float y, float w, float h, std::optional<float> rx,
               std::optional<float> ry, std::optional<Color> color,
               std::optional<float> lineWidth) {
  Rectangle rec{x - w * 0.5f, y - h * 0.5f, w, h};

  const bool doStroke = lineWidth.has_value();
  const bool doFill = color.has_value() && !doStroke;
  Color C = color.value_or(defaultColor());

  // pprint color value
  //  SPDLOG_DEBUG("rectangle color: {} {} {} {}", C.r, C.g, C.b, C.a);

  if (rx.has_value() || ry.has_value()) {
    // Raylib uses [0..1] roundness proportion of min(width,height).
    float px = rx.value_or(0.0f);
    float py = ry.value_or(px);
    float pxMin = std::max(0.0f, std::min(px, py));
    float roundness = (std::min(w, h) <= 0)
                          ? 0.0f
                          : std::clamp(pxMin / std::min(w, h), 0.0f, 1.0f);
    int segments = 12 + (int)std::round(8.0f * roundness);

    if (doStroke) {
      DrawRectangleRoundedLinesEx(rec, roundness, segments,
                                  std::max(1.0f, lineWidth.value()), C);
    } else {
      DrawRectangleRounded(rec, roundness, segments, C);
    }
    return;
  }

  if (doStroke) {
    DrawRectangleLinesEx(rec, std::max(1.0f, lineWidth.value()), C);
  } else if (doFill) {
    DrawRectangleRec(rec, C);
  } else {
    DrawRectangleLines((int)rec.x, (int)rec.y, (int)rec.width, (int)rec.height,
                       C);
  }
}

// -----------------------------------------------------------------------------
// Isosceles triangle pointing right (angle 0), centered at (x,y), size w
// (height across) and h (length).
// -----------------------------------------------------------------------------
void triangle(float x, float y, float w, float h,
              std::optional<Color> color = {},
              std::optional<float> lineWidth = {}) {
  Vector2 p1{x + h * 0.5f, y};
  Vector2 p2{x - h * 0.5f, y - w * 0.5f};
  Vector2 p3{x - h * 0.5f, y + w * 0.5f};

  Color C = color.value_or(defaultColor());
  if (lineWidth.has_value()) {
    float t = std::max(1.0f, lineWidth.value());
    DrawLineEx(p1, p2, t, C);
    DrawLineEx(p2, p3, t, C);
    DrawLineEx(p3, p1, t, C);
  } else if (color.has_value()) {
    DrawTriangle(p1, p2, p3, C);
  } else {
    DrawTriangleLines(p1, p2, p3, C);
  }
}

// -----------------------------------------------------------------------------
// Equilateral triangle of width w, centered at (x,y), pointing right.
// -----------------------------------------------------------------------------
void triangle_equilateral(float x, float y, float w, std::optional<Color> color,
                          std::optional<float> lineWidth) {
  float h = std::sqrt(w * w - (w * 0.5f) * (w * 0.5f)); // = w*sqrt(3)/2
  triangle(x, y, w, h, color, lineWidth);
}

// -----------------------------------------------------------------------------
// Circle at (x,y) radius r
// - fill: DrawCircleV
// - 1px:  DrawCircleLines
// - thick stroke: DrawRing with inner/outer radii
// -----------------------------------------------------------------------------
void circle(float x, float y, float r, std::optional<Color> color,
            std::optional<float> lineWidth) {
  Color C = color.value_or(defaultColor());
  Vector2 c{x, y};

  if (lineWidth.has_value()) {
    float t = std::max(1.0f, lineWidth.value());
    float inner = std::max(0.0f, r - t * 0.5f);
    float outer = r + t * 0.5f;
    DrawRing(c, inner, outer, 0.0f, 360.0f, autoSegments(r), C);
  } else if (color.has_value()) {
    DrawCircleV(c, r, C);
  } else {
    DrawCircleLines((int)x, (int)y, r, C);
  }
}

// -----------------------------------------------------------------------------
// Arc: angles r1..r2 in RADIANS.
//  - Pie (filled wedge): DrawCircleSector
//  - Open (stroked arc only): DrawRing with small thickness or provided
//  lineWidth
//  - Closed (stroked arc + chord): emulate with lines on ends + arc ring
// -----------------------------------------------------------------------------
void arc(ArcType type, float x, float y, float r, float r1, float r2,
         std::optional<Color> color = {}, std::optional<float> lineWidth = {},
         int segments = 0) {
  Color C = color.value_or(defaultColor());
  Vector2 c{x, y};
  float a1 = rad2deg(r1);
  float a2 = rad2deg(r2);
  if (a2 < a1)
    std::swap(a1, a2);

  int seg = (segments > 0) ? segments : autoSegments(r);

  if (!lineWidth.has_value() && color.has_value() && type == ArcType::Pie) {
    DrawCircleSector(c, r, a1, a2, seg, C);
    return;
  }

  // Stroke / open arc is best with a ring band
  float t = std::max(1.0f, lineWidth.value_or(1.0f));
  float inner = std::max(0.0f, r - t * 0.5f);
  float outer = r + t * 0.5f;
  DrawRing(c, inner, outer, a1, a2, seg, C);

  if (type == ArcType::Closed && !lineWidth.has_value()) {
    // If someone asked for "fill+closed" (rare in LÖVE), emulate a chord fill:
    // simple approach: draw two skinny triangles to the center; keep it simple.
    // (Keeping this minimal per your "use built-ins" request.)
    DrawLineEx(c, Vector2{x + r * std::cos(r1), y + r * std::sin(r1)}, 1.0f, C);
    DrawLineEx(c, Vector2{x + r * std::cos(r2), y + r * std::sin(r2)}, 1.0f, C);
  }
}

// Convenience overload matching your LÖVE signature where arctype is a string.
void arc(const char *arctype, float x, float y, float r, float r1, float r2,
         std::optional<Color> color, std::optional<float> lineWidth,
         int segments) {
  arc(ArcTypeFromString(arctype), x, y, r, r1, r2, color, lineWidth, segments);
}

// -----------------------------------------------------------------------------
// Polygon: vertices in order. For fill, assumes convex (or star-shaped) for
// DrawTriangleFan. Stroke uses DrawLineEx per edge; closed polygon.
// -----------------------------------------------------------------------------
void polygon(const std::vector<Vector2> &vertices, std::optional<Color> color,
             std::optional<float> lineWidth) {
  if (vertices.size() < 2)
    return;
  Color C = color.value_or(defaultColor());

  if (lineWidth.has_value()) {
    float t = std::max(1.0f, lineWidth.value());
    for (size_t i = 0; i < vertices.size(); ++i) {
      const Vector2 &a = vertices[i];
      const Vector2 &b = vertices[(i + 1) % vertices.size()];
      DrawLineEx(a, b, t, C);
    }
  } else if (color.has_value()) {
    // Simple convex fill path: triangle fan from v0
    rlBegin(RL_TRIANGLES);
    rlColor4ub(C.r, C.g, C.b, C.a);
    const Vector2 &v0 = vertices[0];
    for (size_t i = 1; i + 1 < vertices.size(); ++i) {
      const Vector2 &v1 = vertices[i];
      const Vector2 &v2 = vertices[i + 1];
      rlVertex2f(v0.x, v0.y);
      rlVertex2f(v1.x, v1.y);
      rlVertex2f(v2.x, v2.y);
    }
    rlEnd();
  } else {
    for (size_t i = 0; i < vertices.size(); ++i) {
      const Vector2 &a = vertices[i];
      const Vector2 &b = vertices[(i + 1) % vertices.size()];
      DrawLineV(a, b, C);
    }
  }
}

// -----------------------------------------------------------------------------
// Line: (x1,y1)-(x2,y2)
// -----------------------------------------------------------------------------
void line(float x1, float y1, float x2, float y2, std::optional<Color> color,
          std::optional<float> lineWidth) {
  Color C = color.value_or(defaultColor());
  if (lineWidth.has_value()) {
    DrawLineEx(Vector2{x1, y1}, Vector2{x2, y2},
               std::max(1.0f, lineWidth.value()), C);
  } else {
    DrawLine((int)x1, (int)y1, (int)x2, (int)y2, C);
  }
}

// -----------------------------------------------------------------------------
// Polyline: draw connected segments (open path).
// -----------------------------------------------------------------------------
void polyline(const std::vector<Vector2> &points, std::optional<Color> color,
              std::optional<float> lineWidth) {
  if (points.size() < 2)
    return;
  Color C = color.value_or(defaultColor());
  float t = std::max(1.0f, lineWidth.value_or(1.0f));
  for (size_t i = 0; i + 1 < points.size(); ++i) {
    DrawLineEx(points[i], points[i + 1], t, C);
  }
}

// -----------------------------------------------------------------------------
// Rounded line caps: DrawLineEx + two endpoint circles for perfect round caps.
// -----------------------------------------------------------------------------
void rounded_line(float x1, float y1, float x2, float y2,
                  std::optional<Color> color, std::optional<float> lineWidth) {
  Color C = color.value_or(defaultColor());
  float t = std::max(1.0f, lineWidth.value_or(1.0f));
  Vector2 a{x1, y1}, b{x2, y2};
  DrawLineEx(a, b, t, C);
  DrawCircleV(a, t * 0.5f, C);
  DrawCircleV(b, t * 0.5f, C);
}

// -----------------------------------------------------------------------------
// Ellipse centered at (x,y) with radii rx, ry.
// - fill: DrawEllipse
// - 1px stroke: DrawEllipseLines
// - thick stroke: emulate with scaled ring (rlScale), keeping it simple.
// -----------------------------------------------------------------------------
void ellipse(float x, float y, float rx, float ry, std::optional<Color> color,
             std::optional<float> lineWidth) {
  Color C = color.value_or(defaultColor());
  if (lineWidth.has_value()) {
    float t = std::max(1.0f, lineWidth.value());
    rlPushMatrix();
    rlTranslatef(x, y, 0.0f);
    rlScalef(1.0f, ry / rx, 1.0f);
    float inner = std::max(0.0f, rx - t * 0.5f);
    float outer = rx + t * 0.5f;
    DrawRing(Vector2{0, 0}, inner, outer, 0.0f, 360.0f, autoSegments(rx), C);
    rlDrawRenderBatchActive(); // <---- CRUCIAL
    rlPopMatrix();
  } else if (color.has_value()) {
    DrawEllipse((int)x, (int)y, (int)rx, (int)ry, C);
  } else {
    DrawEllipseLines((int)x, (int)y, (int)rx, (int)ry, C);
  }
}

// -- immediate sprite render
static Texture2D *resolveAtlasTexture(const std::string &atlasUUID) {
  return getAtlasTexture(atlasUUID);
}

auto DrawSpriteTopLeft(const std::string &spriteName, float x, float y,
                       std::optional<float> dstW, std::optional<float> dstH,
                       Color tint) -> void {
  // Resolve atlas frame + texture
  const auto spriteId = uuid::add(spriteName);
  const auto &sfd = init::getSpriteFrame(
      spriteId, globals::g_ctx); // expects .frame and .atlasUUID

  Texture2D *tex = resolveAtlasTexture(sfd.atlasUUID);
  if (!tex) {
    // TraceLog(LOG_WARNING, "Atlas texture not found for sprite '%s'",
    // spriteName.c_str());
    return;
  }

  const Rectangle src = sfd.frame;

  // Destination size (native if not provided). Keep aspect if only one is set.
  float w = dstW.value_or(src.width);
  float h = dstH.value_or(src.height);
  if (dstW && !dstH) {
    h = w * (src.height / src.width);
  } else if (dstH && !dstW) {
    w = h * (src.width / src.height);
  }

  // Top-left anchored destination rect
  const Rectangle dst = {x, y, w, h};
  const Vector2 origin = {0.0f, 0.0f};

  DrawTexturePro(*tex, src, dst, origin, 0.0f, tint);
}

// Draw the sprite named `spriteName` centered at (x,y).
// - If both dstW and dstH are unset, draws at native (frame) size.
// - If only one is set, preserves aspect ratio to compute the other.
// - `tint` tints the sprite (WHITE = unchanged).
auto DrawSpriteCentered(const std::string &spriteName, float x, float y,
                        std::optional<float> dstW, std::optional<float> dstH,
                        Color tint) -> void {
  // Resolve atlas frame + texture
  const auto spriteId = uuid::add(spriteName);
  const auto &sfd = init::getSpriteFrame(
      spriteId,
      globals::g_ctx); // expect: has .frame (Rectangle) and .atlasUUID

  Texture2D *tex = resolveAtlasTexture(sfd.atlasUUID);
  if (!tex) {
    // TODO: replace with your logging/error path
    // TraceLog(LOG_WARNING, "Atlas texture not found for sprite '%s'",
    // spriteName.c_str());
    return;
  }

  const Rectangle src = sfd.frame; // sub-rect in the atlas

  // Determine destination size
  float w = dstW.value_or(src.width);
  float h = dstH.value_or(src.height);
  if (dstW && !dstH) { // width forced, keep aspect
    h = w * (src.height / src.width);
  } else if (dstH && !dstW) { // height forced, keep aspect
    w = h * (src.width / src.height);
  }

  // Centered destination rect
  const Rectangle dst = {x - 0.5f * w, y - 0.5f * h, w, h};

  // No rotation; origin is top-left of dst
  const Vector2 origin = {0.0f, 0.0f};
  DrawTexturePro(*tex, src, dst, origin, 0.0f, tint);
}
#if !defined(__EMSCRIPTEN__)
#include "external/glad.h"
#endif

#include "rlgl.h"

// Stencil masks

void clearStencilBuffer() {
  rlDrawRenderBatchActive();
  glStencilMask(0xFF); // make sure all bits can be cleared
  glClearStencil(0);   // the value they’ll be cleared to
  glClear(GL_STENCIL_BUFFER_BIT);
}

void beginStencil() {
  rlDrawRenderBatchActive();
  glEnable(GL_STENCIL_TEST);

  // Clear all existing stencil bits to zero, and allow writing to all bits:
  glClear(GL_STENCIL_BUFFER_BIT);
  glStencilMask(0xFF);
}

void beginStencilMask() {
  glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
  glStencilFunc(GL_ALWAYS, 1, 0xFF);
  glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);
}

void endStencilMask() {
  rlDrawRenderBatchActive();
  // Now only draw where stencil == 1, and never change the stencil buffer:
  glStencilFunc(GL_EQUAL, 1, 0xFF);
  glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP);

  // Stop writing to stencil bits
  glStencilMask(0x00);

  glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
}

void endStencil() {
  rlDrawRenderBatchActive();
  glDisable(GL_STENCIL_TEST);
}

RenderTexture2D LoadRenderTextureStencilEnabled(int width, int height) {
  RenderTexture2D target = {0};

  target.id = rlLoadFramebuffer(); // Create framebuffer object
  if (target.id <= 0) {
    TRACELOG(LOG_WARNING, "FBO: Framebuffer object cannot be created");
    return target;
  }

  rlEnableFramebuffer(target.id);

  // ------------------------------------------------------------
  // COLOR ATTACHMENT (RGBA8)
  // ------------------------------------------------------------
  target.texture.id =
      rlLoadTexture(NULL, width, height, PIXELFORMAT_UNCOMPRESSED_R8G8B8A8, 1);
  target.texture.width = width;
  target.texture.height = height;
  target.texture.format = PIXELFORMAT_UNCOMPRESSED_R8G8B8A8;
  target.texture.mipmaps = 1;
  SetTextureFilter(target.texture, TEXTURE_FILTER_POINT);

  rlFramebufferAttach(target.id, target.texture.id,
                      RL_ATTACHMENT_COLOR_CHANNEL0, RL_ATTACHMENT_TEXTURE2D, 0);

  // ------------------------------------------------------------
  // DEPTH + STENCIL RENDERBUFFER (GL_DEPTH24_STENCIL8)
  // ------------------------------------------------------------
  unsigned int depthStencilId = 0;
  glGenRenderbuffers(1, &depthStencilId);
  glBindRenderbuffer(GL_RENDERBUFFER, depthStencilId);
  glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, width, height);

  // Attach same renderbuffer to both depth and stencil
  rlFramebufferAttach(target.id, depthStencilId, RL_ATTACHMENT_DEPTH,
                      RL_ATTACHMENT_RENDERBUFFER, 0);
  rlFramebufferAttach(target.id, depthStencilId, RL_ATTACHMENT_STENCIL,
                      RL_ATTACHMENT_RENDERBUFFER, 0);

  // Store metadata
  target.depth.id = depthStencilId;
  target.depth.width = width;
  target.depth.height = height;
  target.depth.format = PIXELFORMAT_UNCOMPRESSED_R8G8B8A8; // placeholder
  target.depth.mipmaps = 1;

  // ------------------------------------------------------------
  // VALIDATION + CLEANUP
  // ------------------------------------------------------------
  if (rlFramebufferComplete(target.id))
    TRACELOG(LOG_INFO,
             "FBO: [ID %i] Framebuffer with depth+stencil created successfully",
             target.id);
  else
    TRACELOG(LOG_WARNING, "FBO: [ID %i] Framebuffer is incomplete", target.id);

  rlDisableFramebuffer();

  return target;
}

} // namespace layer
