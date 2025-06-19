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

#include "systems/scripting/binding_recorder.hpp"

// Graphics namespace for rendering functions
namespace layer
{
    void exposeToLua(sol::state &lua) {

        sol::state_view luaView{lua};
        auto layerTbl = luaView["layer"].get_or_create<sol::table>();
        if (!layerTbl.valid()) {
            layerTbl = lua.create_table();
            lua["layer"] = layerTbl;
        }
        

        auto& rec = BindingRecorder::instance();

        rec.add_type("layer").doc = "namespace for rendering & layer operations";
        rec.add_type("layer.LayerOrderComponent", true).doc = "Stores Z-index for layer sorting";
        layerTbl.new_usertype<layer::LayerOrderComponent>("LayerOrderComponent",
            sol::constructors<>(),
            "zIndex", &layer::LayerOrderComponent::zIndex,
            "type_id", []() {
                return entt::type_hash<layer::LayerOrderComponent>::value(); }
        );
        rec.record_property("layer.LayerOrderComponent", {"zIndex", "integer", "Z sort order"});

        rec.add_type("layer.Layer", true).doc = "Represents a drawing layer and its properties.";
        layerTbl.new_usertype<layer::Layer>("Layer",
            sol::constructors<>(),
            "canvases",        &layer::Layer::canvases,
            // "drawCommands",    &layer::Layer::drawCommands,
            "fixed",           &layer::Layer::fixed,
            "zIndex",          &layer::Layer::zIndex,
            "backgroundColor", &layer::Layer::backgroundColor,
            "commands",        &layer::Layer::commands,
            "isSorted",        &layer::Layer::isSorted,
            "postProcessShaders", &layer::Layer::postProcessShaders,
            "removePostProcessShader", &layer::Layer::removePostProcessShader,
            "addPostProcessShader", &layer::Layer::addPostProcessShader,
            "clearPostProcessShaders", &layer::Layer::clearPostProcessShaders,
            "type_id", []() {
                return entt::type_hash<layer::Layer>::value(); }
        );
        std::vector<std::string> postProcessShaders;
        
        rec.record_property("layer.Layer", {"canvases", "table", "Map of canvas names to textures"});
        rec.record_property("layer.Layer", {"drawCommands", "table", "Command list"});
        rec.record_property("layer.Layer", {"fixed", "boolean", "Whether layer is fixed"});
        rec.record_property("layer.Layer", {"zIndex", "integer", "Z-index"});
        rec.record_property("layer.Layer", {"backgroundColor", "Color", "Background fill color"});
        rec.record_property("layer.Layer", {"commands", "table", "Draw commands list"});
        rec.record_property("layer.Layer", {"isSorted", "boolean", "True if layer is sorted"});
        rec.record_property("layer.Layer", {"postProcessShaders", "vector", "List of post-process shaders to run after drawing"});

        rec.record_free_function({"layer.Layer"}, MethodDef{
            .name = "removePostProcessShader",
            .signature = R"(---@param layer Layer # Target layer
        ---@param shader_name string # Name of the shader to remove
        ---@return void)",
            .doc = R"(Removes a post-process shader from the layer by name.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer.Layer"}, MethodDef{
            .name = "addPostProcessShader",
            .signature = R"(---@param layer Layer # Target layer
        ---@param shader_name string # Name of the shader to add
        ---@param shader Shader # Shader instance to add
        ---@return void)",
            .doc = R"(Adds a post-process shader to the layer.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer.Layer"}, MethodDef{
            .name = "clearPostProcessShaders",
            .signature = R"(---@param layer Layer # Target layer
        ---@return void)",
            .doc = R"(Removes all post-process shaders from the layer.)",
            .is_static = true,
            .is_overload = false
        });
        

        layerTbl["layers"] = &layer::layers;
        rec.record_property("layer", {"layers", "table", "Global list of layers"});

        // 5) Overloads helpers
        using LPtr = std::shared_ptr<layer::Layer>;

        // // 6) Functions
        layerTbl.set_function("SortLayers", &layer::SortLayers);
        layerTbl.set_function("UpdateLayerZIndex", &layer::UpdateLayerZIndex);
        layerTbl.set_function("CreateLayer", &layer::CreateLayer);
        layerTbl.set_function("CreateLayerWithSize", &layer::CreateLayerWithSize);
        layerTbl.set_function("RemoveLayerFromCanvas", &layer::RemoveLayerFromCanvas);

        rec.bind_function(lua, {"layer"}, "SortLayers", &layer::SortLayers,
            "---@return nil",
            "Sorts all layers by their Z-index."
        );

        rec.bind_function(lua, {"layer"}, "UpdateLayerZIndex", &layer::UpdateLayerZIndex,
            "---@param layer layer.Layer\n"
            "---@param newZIndex integer\n"
            "---@return nil",
            "Updates the Z-index of a layer and resorts the layer list."
        );

        rec.bind_function(lua, {"layer"}, "CreateLayer", &layer::CreateLayer,
            "---@return layer.Layer",
            "Creates a new layer with a default-sized main canvas and returns it."
        );

        rec.bind_function(lua, {"layer"}, "CreateLayerWithSize", &layer::CreateLayerWithSize,
            "---@param width integer\n"
            "---@param height integer\n"
            "---@return layer.Layer",
            "Creates a layer with a main canvas of a specified size."
        );

        rec.bind_function(lua, {"layer"}, "RemoveLayerFromCanvas", &layer::RemoveLayerFromCanvas,
            "---@param layer layer.Layer\n"
            "---@return nil",
            "Removes a layer and unloads its canvases."
        );

        rec.bind_function(lua, {"layer"}, "ResizeCanvasInLayer", &layer::ResizeCanvasInLayer,
            "---@param layer layer.Layer\n"
            "---@param canvasName string\n"
            "---@param newWidth integer\n"
            "---@param newHeight integer\n"
            "---@return nil",
            "Resizes a specific canvas within a layer."
        );

        // --- Corrected Overload Handling for AddCanvasToLayer ---
        // Base function
        rec.bind_function(lua, {"layer"}, "AddCanvasToLayer",
            static_cast<void(*)(LPtr,const std::string&)>(&layer::AddCanvasToLayer),
            "---@param layer layer.Layer\n"
            "---@param canvasName string\n"
            "---@return nil",
            "Adds a canvas to the layer, matching the layer's default size.",
            /*is_overload=*/false
        );
        // Overload with size
        rec.bind_function(lua, {"layer"}, "AddCanvasToLayer",
            static_cast<void(*)(LPtr,const std::string&,int,int)>(&layer::AddCanvasToLayer),
            "---@overload fun(layer: layer.Layer, canvasName: string, width: integer, height: integer):nil",
            "Adds a canvas of a specific size to the layer.",
            /*is_overload=*/true
        );


        rec.bind_function(lua, {"layer"}, "RemoveCanvas", &layer::RemoveCanvas,
            "---@param layer layer.Layer\n"
            "---@param canvasName string\n"
            "---@return nil",
            "Removes a canvas by name from a specific layer."
        );

        rec.bind_function(lua, {"layer"}, "UnloadAllLayers", &layer::UnloadAllLayers,
            "---@return nil",
            "Destroys all layers and their contents."
        );

        rec.bind_function(lua, {"layer"}, "ClearDrawCommands", &layer::ClearDrawCommands,
            "---@param layer layer.Layer\n"
            "---@return nil",
            "Clears draw commands for a specific layer."
        );

        rec.bind_function(lua, {"layer"}, "ClearAllDrawCommands", &layer::ClearAllDrawCommands,
            "---@return nil",
            "Clears all draw commands from all layers."
        );

        rec.bind_function(lua, {"layer"}, "Begin", &layer::Begin,
            "---@return nil",
            "Begins drawing to all canvases. (Calls BeginTextureMode on all)."
        );

        rec.bind_function(lua, {"layer"}, "End", &layer::End,
            "---@return nil",
            "Ends drawing to all canvases. (Calls EndTextureMode on all)."
        );

        rec.bind_function(lua, {"layer"}, "RenderAllLayersToCurrentRenderTarget", &layer::RenderAllLayersToCurrentRenderTarget,
            "---@param camera? Camera2D # Optional camera for rendering.\n"
            "---@return nil",
            "Renders all layers to the current render target."
        );

        rec.bind_function(lua, {"layer"}, "DrawLayerCommandsToSpecificCanvas",
            static_cast<void(*)(LPtr,const std::string&,Camera2D*)>(&layer::DrawLayerCommandsToSpecificCanvasOptimizedVersion),
            "---@param layer layer.Layer\n"
            "---@param canvasName string\n"
            "---@param camera Camera2D # The camera to use for rendering.\n"
            "---@return nil",
            "Draws a layer's queued commands to a specific canvas within that layer."
        );

        rec.bind_function(lua, {"layer"}, "DrawCanvasToCurrentRenderTargetWithTransform", &layer::DrawCanvasToCurrentRenderTargetWithTransform,
            "---@param layer layer.Layer\n"
            "---@param canvasName string\n"
            "---@param x? number\n"
            "---@param y? number\n"
            "---@param rotation? number\n"
            "---@param scaleX? number\n"
            "---@param scaleY? number\n"
            "---@param color? Color\n"
            "---@param shader? Shader\n"
            "---@param flat? boolean\n"
            "---@return nil",
            "Draws a canvas to the current render target with transform, color, and an optional shader."
        );

        rec.bind_function(lua, {"layer"}, "DrawCanvasOntoOtherLayer", &layer::DrawCanvasOntoOtherLayer,
            "---@param sourceLayer layer.Layer\n"
            "---@param sourceCanvasName string\n"
            "---@param destLayer layer.Layer\n"
            "---@param destCanvasName string\n"
            "---@param x number\n"
            "---@param y number\n"
            "---@param rotation number\n"
            "---@param scaleX number\n"
            "---@param scaleY number\n"
            "---@param tint Color\n"
            "---@return nil",
            "Draws a canvas from one layer onto a canvas in another layer."
        );

        rec.bind_function(lua, {"layer"}, "DrawCanvasOntoOtherLayerWithShader", &layer::DrawCanvasOntoOtherLayerWithShader,
            "---@param sourceLayer layer.Layer\n"
            "---@param sourceCanvasName string\n"
            "---@param destLayer layer.Layer\n"
            "---@param destCanvasName string\n"
            "---@param x number\n"
            "---@param y number\n"
            "---@param rotation number\n"
            "---@param scaleX number\n"
            "---@param scaleY number\n"
            "---@param tint Color\n"
            "---@param shader Shader\n"
            "---@return nil",
            "Draws a canvas from one layer onto another with a shader."
        );

        rec.bind_function(lua, {"layer"}, "DrawCanvasToCurrentRenderTargetWithDestRect", &layer::DrawCanvasToCurrentRenderTargetWithDestRect,
            "---@param layer layer.Layer\n"
            "---@param canvasName string\n"
            "---@param destRect Rectangle\n"
            "---@param color Color\n"
            "---@param shader Shader\n"
            "---@return nil",
            "Draws a canvas to the current render target, fitting it to a destination rectangle."
        );

        rec.bind_function(lua, {"layer"}, "DrawCustomLamdaToSpecificCanvas", &layer::DrawCustomLamdaToSpecificCanvas,
            "---@param layer layer.Layer\n"
            "---@param canvasName? string\n"
            "---@param drawActions fun():void\n"
            "---@return nil",
            "Executes a custom drawing function that renders to a specific canvas."
        );

        rec.bind_function(lua, {"layer"}, "DrawTransformEntityWithAnimation", &layer::DrawTransformEntityWithAnimation,
            "---@param registry Registry\n"
            "---@param entity Entity\n"
            "---@return nil",
            "Draws an entity with a Transform and Animation component directly."
        );

        rec.bind_function(lua, {"layer"}, "DrawTransformEntityWithAnimationWithPipeline", &layer::DrawTransformEntityWithAnimationWithPipeline,
            "---@param registry Registry\n"
            "---@param entity Entity\n"
            "---@return nil",
            "Draws an entity with a Transform and Animation component using the rendering pipeline."
        );

        // 1) Bind DrawCommandType enum as a plain table:
        layerTbl["DrawCommandType"] = lua.create_table_with(
            "BeginDrawing",                             layer::DrawCommandType::BeginDrawing,
            "EndDrawing",                               layer::DrawCommandType::EndDrawing,
            "ClearBackground",                          layer::DrawCommandType::ClearBackground,
            "Translate",                                layer::DrawCommandType::Translate,
            "Scale",                                    layer::DrawCommandType::Scale,
            "Rotate",                                   layer::DrawCommandType::Rotate,
            "AddPush",                                  layer::DrawCommandType::AddPush,
            "AddPop",                                   layer::DrawCommandType::AddPop,
            "PushMatrix",                               layer::DrawCommandType::PushMatrix,
            "PopMatrix",                                layer::DrawCommandType::PopMatrix,
            "DrawCircle",                               layer::DrawCommandType::Circle,
            "DrawRectangle",                            layer::DrawCommandType::Rectangle,
            "DrawRectanglePro",                         layer::DrawCommandType::RectanglePro,
            "DrawRectangleLinesPro",                    layer::DrawCommandType::RectangleLinesPro,
            "DrawLine",                                 layer::DrawCommandType::Line,
            "DrawDashedLine",                           layer::DrawCommandType::DashedLine,
            "DrawText",                                 layer::DrawCommandType::Text,
            "DrawTextCentered",                         layer::DrawCommandType::DrawTextCentered,
            "TextPro",                                  layer::DrawCommandType::TextPro,
            "DrawImage",                                layer::DrawCommandType::DrawImage,
            "TexturePro",                               layer::DrawCommandType::TexturePro,
            "DrawEntityAnimation",                      layer::DrawCommandType::DrawEntityAnimation,
            "DrawTransformEntityAnimation",             layer::DrawCommandType::DrawTransformEntityAnimation,
            "DrawTransformEntityAnimationPipeline",     layer::DrawCommandType::DrawTransformEntityAnimationPipeline,
            "SetShader",                                layer::DrawCommandType::SetShader,
            "ResetShader",                              layer::DrawCommandType::ResetShader,
            "SetBlendMode",                             layer::DrawCommandType::SetBlendMode,
            "UnsetBlendMode",                           layer::DrawCommandType::UnsetBlendMode,
            "SendUniformFloat",                         layer::DrawCommandType::SendUniformFloat,
            "SendUniformInt",                           layer::DrawCommandType::SendUniformInt,
            "SendUniformVec2",                          layer::DrawCommandType::SendUniformVec2,
            "SendUniformVec3",                          layer::DrawCommandType::SendUniformVec3,
            "SendUniformVec4",                          layer::DrawCommandType::SendUniformVec4,
            "SendUniformFloatArray",                    layer::DrawCommandType::SendUniformFloatArray,
            "SendUniformIntArray",                      layer::DrawCommandType::SendUniformIntArray,
            "Vertex",                                   layer::DrawCommandType::Vertex,
            "BeginOpenGLMode",                          layer::DrawCommandType::BeginOpenGLMode,
            "EndOpenGLMode",                            layer::DrawCommandType::EndOpenGLMode,
            "SetColor",                                 layer::DrawCommandType::SetColor,
            "SetLineWidth",                             layer::DrawCommandType::SetLineWidth,
            "SetTexture",                               layer::DrawCommandType::SetTexture,
            "RenderRectVerticesFilledLayer",            layer::DrawCommandType::RenderRectVerticesFilledLayer,
            "RenderRectVerticesOutlineLayer",           layer::DrawCommandType::RenderRectVerticlesOutlineLayer,
            "DrawPolygon",                              layer::DrawCommandType::Polygon,
            "RenderNPatchRect",                         layer::DrawCommandType::RenderNPatchRect,
            "DrawTriangle",                             layer::DrawCommandType::Triangle
        );

        // 1b) EmmyLua docs via BindingRecorder
        rec.add_type("layer.DrawCommandType").doc = "Drawing instruction types used by Layer system";

        rec.record_property("layer.DrawCommandType", { "BeginDrawing", "0", "Start drawing a layer frame" });
        rec.record_property("layer.DrawCommandType", { "EndDrawing", "1", "End drawing a layer frame" });
        rec.record_property("layer.DrawCommandType", { "ClearBackground", "2", "Clear background with color" });
        rec.record_property("layer.DrawCommandType", { "Translate", "3", "Translate coordinate system" });
        rec.record_property("layer.DrawCommandType", { "Scale", "4", "Scale coordinate system" });
        rec.record_property("layer.DrawCommandType", { "Rotate", "5", "Rotate coordinate system" });
        rec.record_property("layer.DrawCommandType", { "AddPush", "6", "Push transform matrix" });
        rec.record_property("layer.DrawCommandType", { "AddPop", "7", "Pop transform matrix" });
        rec.record_property("layer.DrawCommandType", { "PushMatrix", "8", "Explicit push matrix command" });
        rec.record_property("layer.DrawCommandType", { "PopMatrix", "9", "Explicit pop matrix command" });
        rec.record_property("layer.DrawCommandType", { "DrawCircle", "10", "Draw a filled circle" });
        rec.record_property("layer.DrawCommandType", { "DrawRectangle", "11", "Draw a filled rectangle" });
        rec.record_property("layer.DrawCommandType", { "DrawRectanglePro", "12", "Draw a scaled and rotated rectangle" });
        rec.record_property("layer.DrawCommandType", { "DrawRectangleLinesPro", "13", "Draw rectangle outline" });
        rec.record_property("layer.DrawCommandType", { "DrawLine", "14", "Draw a line" });
        rec.record_property("layer.DrawCommandType", { "DrawDashedLine", "15", "Draw a dashed line" });
        rec.record_property("layer.DrawCommandType", { "DrawText", "16", "Draw plain text" });
        rec.record_property("layer.DrawCommandType", { "DrawTextCentered", "17", "Draw text centered" });
        rec.record_property("layer.DrawCommandType", { "TextPro", "18", "Draw stylized/proportional text" });
        rec.record_property("layer.DrawCommandType", { "DrawImage", "19", "Draw a texture/image" });
        rec.record_property("layer.DrawCommandType", { "TexturePro", "20", "Draw transformed texture" });
        rec.record_property("layer.DrawCommandType", { "DrawEntityAnimation", "21", "Draw animation of an entity" });
        rec.record_property("layer.DrawCommandType", { "DrawTransformEntityAnimation", "22", "Draw transform-aware animation" });
        rec.record_property("layer.DrawCommandType", { "DrawTransformEntityAnimationPipeline", "23", "Draw pipelined animation with transform" });
        rec.record_property("layer.DrawCommandType", { "SetShader", "24", "Set active shader" });
        rec.record_property("layer.DrawCommandType", { "ResetShader", "25", "Reset to default shader" });
        rec.record_property("layer.DrawCommandType", { "SetBlendMode", "26", "Set blend mode" });
        rec.record_property("layer.DrawCommandType", { "UnsetBlendMode", "27", "Reset blend mode" });
        rec.record_property("layer.DrawCommandType", { "SendUniformFloat", "28", "Send float uniform to shader" });
        rec.record_property("layer.DrawCommandType", { "SendUniformInt", "29", "Send int uniform to shader" });
        rec.record_property("layer.DrawCommandType", { "SendUniformVec2", "30", "Send vec2 uniform to shader" });
        rec.record_property("layer.DrawCommandType", { "SendUniformVec3", "31", "Send vec3 uniform to shader" });
        rec.record_property("layer.DrawCommandType", { "SendUniformVec4", "32", "Send vec4 uniform to shader" });
        rec.record_property("layer.DrawCommandType", { "SendUniformFloatArray", "33", "Send float array uniform to shader" });
        rec.record_property("layer.DrawCommandType", { "SendUniformIntArray", "34", "Send int array uniform to shader" });
        rec.record_property("layer.DrawCommandType", { "Vertex", "35", "Draw raw vertex" });
        rec.record_property("layer.DrawCommandType", { "BeginOpenGLMode", "36", "Begin native OpenGL mode" });
        rec.record_property("layer.DrawCommandType", { "EndOpenGLMode", "37", "End native OpenGL mode" });
        rec.record_property("layer.DrawCommandType", { "SetColor", "38", "Set current draw color" });
        rec.record_property("layer.DrawCommandType", { "SetLineWidth", "39", "Set width of lines" });
        rec.record_property("layer.DrawCommandType", { "SetTexture", "40", "Bind texture to use" });
        rec.record_property("layer.DrawCommandType", { "RenderRectVerticesFilledLayer", "41", "Draw filled rects from vertex list" });
        rec.record_property("layer.DrawCommandType", { "RenderRectVerticesOutlineLayer", "42", "Draw outlined rects from vertex list" });
        rec.record_property("layer.DrawCommandType", { "DrawPolygon", "43", "Draw a polygon" });
        rec.record_property("layer.DrawCommandType", { "RenderNPatchRect", "44", "Draw a 9-patch rectangle" });
        rec.record_property("layer.DrawCommandType", { "DrawTriangle", "45", "Draw a triangle" });
        

        // Helper macro to reduce boilerplate
        #define BIND_CMD(name, ...) \
        layerTbl.new_usertype<layer::Cmd##name>("Cmd" #name, \
            sol::constructors<>(), \
            __VA_ARGS__, \
            "type_id", []() { return entt::type_hash<layer::Cmd##name>::value(); } \
        );

        // 2) Register every Cmd* struct:
        BIND_CMD(BeginDrawing,           "dummy", &layer::CmdBeginDrawing::dummy)
        BIND_CMD(EndDrawing,             "dummy", &layer::CmdEndDrawing::dummy)
        BIND_CMD(ClearBackground,        "color", &layer::CmdClearBackground::color)
        BIND_CMD(Translate,              "x", &layer::CmdTranslate::x, "y", &layer::CmdTranslate::y)
        BIND_CMD(Scale,                  "scaleX", &layer::CmdScale::scaleX, "scaleY", &layer::CmdScale::scaleY)
        BIND_CMD(Rotate,                 "angle", &layer::CmdRotate::angle)
        BIND_CMD(AddPush,                "camera", &layer::CmdAddPush::camera)
        BIND_CMD(AddPop,                 "dummy", &layer::CmdAddPop::dummy)
        BIND_CMD(PushMatrix,             "dummy", &layer::CmdPushMatrix::dummy)
        BIND_CMD(PopMatrix,              "dummy", &layer::CmdPopMatrix::dummy)
        BIND_CMD(DrawCircleFilled,             "x", &layer::CmdDrawCircleFilled::x, "y", &layer::CmdDrawCircleFilled::y, "radius", &layer::CmdDrawCircleFilled::radius, "color", &layer::CmdDrawCircleFilled::color)
        BIND_CMD(DrawCircleLine,        "x", &layer::CmdDrawCircleLine::x, "y", &layer::CmdDrawCircleLine::y, "innerRadius", &layer::CmdDrawCircleLine::innerRadius, "outerRadius", &layer::CmdDrawCircleLine::outerRadius, "startAngle", &layer::CmdDrawCircleLine::startAngle, "endAngle", &layer::CmdDrawCircleLine::endAngle, "segments", &layer::CmdDrawCircleLine::segments, "color", &layer::CmdDrawCircleLine::color)
        BIND_CMD(DrawRectangle,          "x", &layer::CmdDrawRectangle::x, "y", &layer::CmdDrawRectangle::y, "width", &layer::CmdDrawRectangle::width, "height", &layer::CmdDrawRectangle::height, "color", &layer::CmdDrawRectangle::color, "lineWidth", &layer::CmdDrawRectangle::lineWidth)
        BIND_CMD(DrawRectanglePro,       "offsetX", &layer::CmdDrawRectanglePro::offsetX, "offsetY", &layer::CmdDrawRectanglePro::offsetY, "size", &layer::CmdDrawRectanglePro::size, "rotationCenter", &layer::CmdDrawRectanglePro::rotationCenter, "rotation", &layer::CmdDrawRectanglePro::rotation, "color", &layer::CmdDrawRectanglePro::color)
        BIND_CMD(DrawRectangleLinesPro,  "offsetX", &layer::CmdDrawRectangleLinesPro::offsetX, "offsetY", &layer::CmdDrawRectangleLinesPro::offsetY, "size", &layer::CmdDrawRectangleLinesPro::size, "lineThickness", &layer::CmdDrawRectangleLinesPro::lineThickness, "color", &layer::CmdDrawRectangleLinesPro::color)
        BIND_CMD(DrawLine,               "x1", &layer::CmdDrawLine::x1, "y1", &layer::CmdDrawLine::y1, "x2", &layer::CmdDrawLine::x2, "y2", &layer::CmdDrawLine::y2, "color", &layer::CmdDrawLine::color, "lineWidth", &layer::CmdDrawLine::lineWidth)
        BIND_CMD(DrawDashedLine,         "x1", &layer::CmdDrawDashedLine::x1, "y1", &layer::CmdDrawDashedLine::y1, "x2", &layer::CmdDrawDashedLine::x2, "y2", &layer::CmdDrawDashedLine::y2, "dashSize", &layer::CmdDrawDashedLine::dashSize, "gapSize", &layer::CmdDrawDashedLine::gapSize, "color", &layer::CmdDrawDashedLine::color, "lineWidth", &layer::CmdDrawDashedLine::lineWidth)
        BIND_CMD(DrawText,               "text", &layer::CmdDrawText::text, "font", &layer::CmdDrawText::font, "x", &layer::CmdDrawText::x, "y", &layer::CmdDrawText::y, "color", &layer::CmdDrawText::color, "fontSize", &layer::CmdDrawText::fontSize)
        BIND_CMD(DrawTextCentered,       "text", &layer::CmdDrawTextCentered::text, "font", &layer::CmdDrawTextCentered::font, "x", &layer::CmdDrawTextCentered::x, "y", &layer::CmdDrawTextCentered::y, "color", &layer::CmdDrawTextCentered::color, "fontSize", &layer::CmdDrawTextCentered::fontSize)
        BIND_CMD(TextPro,                "text", &layer::CmdTextPro::text, "font", &layer::CmdTextPro::font, "x", &layer::CmdTextPro::x, "y", &layer::CmdTextPro::y, "origin", &layer::CmdTextPro::origin, "rotation", &layer::CmdTextPro::rotation, "fontSize", &layer::CmdTextPro::fontSize, "spacing", &layer::CmdTextPro::spacing, "color", &layer::CmdTextPro::color)
        BIND_CMD(DrawImage,              "image", &layer::CmdDrawImage::image, "x", &layer::CmdDrawImage::x, "y", &layer::CmdDrawImage::y, "rotation", &layer::CmdDrawImage::rotation, "scaleX", &layer::CmdDrawImage::scaleX, "scaleY", &layer::CmdDrawImage::scaleY, "color", &layer::CmdDrawImage::color)
        BIND_CMD(TexturePro,             "texture", &layer::CmdTexturePro::texture, "source", &layer::CmdTexturePro::source, "offsetX", &layer::CmdTexturePro::offsetX, "offsetY", &layer::CmdTexturePro::offsetY, "size", &layer::CmdTexturePro::size, "rotationCenter", &layer::CmdTexturePro::rotationCenter, "rotation", &layer::CmdTexturePro::rotation, "color", &layer::CmdTexturePro::color)
        BIND_CMD(DrawEntityAnimation,    "e", &layer::CmdDrawEntityAnimation::e, "registry", &layer::CmdDrawEntityAnimation::registry, "x", &layer::CmdDrawEntityAnimation::x, "y", &layer::CmdDrawEntityAnimation::y)
        BIND_CMD(DrawTransformEntityAnimation, "e", &layer::CmdDrawTransformEntityAnimation::e, "registry", &layer::CmdDrawTransformEntityAnimation::registry)
        BIND_CMD(DrawTransformEntityAnimationPipeline, "e", &layer::CmdDrawTransformEntityAnimationPipeline::e, "registry", &layer::CmdDrawTransformEntityAnimationPipeline::registry)
        BIND_CMD(SetShader,              "shader", &layer::CmdSetShader::shader)
        // instead of BIND_CMD(ResetShader /*no fields*/)
        layerTbl.new_usertype< ::layer::CmdResetShader >(
            "CmdResetShader", 
            sol::constructors<>()
        );
        BIND_CMD(SetBlendMode,           "blendMode", &layer::CmdSetBlendMode::blendMode)
        BIND_CMD(UnsetBlendMode,         "dummy", &layer::CmdUnsetBlendMode::dummy)
        BIND_CMD(SendUniformFloat,       "shader", &layer::CmdSendUniformFloat::shader, "uniform", &layer::CmdSendUniformFloat::uniform, "value", &layer::CmdSendUniformFloat::value)
        BIND_CMD(SendUniformInt,         "shader", &layer::CmdSendUniformInt::shader, "uniform", &layer::CmdSendUniformInt::uniform, "value", &layer::CmdSendUniformInt::value)
        BIND_CMD(SendUniformVec2,        "shader", &layer::CmdSendUniformVec2::shader, "uniform", &layer::CmdSendUniformVec2::uniform, "value", &layer::CmdSendUniformVec2::value)
        BIND_CMD(SendUniformVec3,        "shader", &layer::CmdSendUniformVec3::shader, "uniform", &layer::CmdSendUniformVec3::uniform, "value", &layer::CmdSendUniformVec3::value)
        BIND_CMD(SendUniformVec4,        "shader", &layer::CmdSendUniformVec4::shader, "uniform", &layer::CmdSendUniformVec4::uniform, "value", &layer::CmdSendUniformVec4::value)
        BIND_CMD(SendUniformFloatArray,  "shader", &layer::CmdSendUniformFloatArray::shader, "uniform", &layer::CmdSendUniformFloatArray::uniform, "values", &layer::CmdSendUniformFloatArray::values)
        BIND_CMD(SendUniformIntArray,    "shader", &layer::CmdSendUniformIntArray::shader, "uniform", &layer::CmdSendUniformIntArray::uniform, "values", &layer::CmdSendUniformIntArray::values)
        BIND_CMD(Vertex,                 "v", &layer::CmdVertex::v, "color", &layer::CmdVertex::color)
        BIND_CMD(BeginOpenGLMode,        "mode", &layer::CmdBeginOpenGLMode::mode)
        BIND_CMD(EndOpenGLMode,          "dummy", &layer::CmdEndOpenGLMode::dummy)
        BIND_CMD(SetColor,               "color", &layer::CmdSetColor::color)
        BIND_CMD(SetLineWidth,           "lineWidth", &layer::CmdSetLineWidth::lineWidth)
        BIND_CMD(SetTexture,             "texture", &layer::CmdSetTexture::texture)
        BIND_CMD(RenderRectVerticesFilledLayer, "outerRec", &layer::CmdRenderRectVerticesFilledLayer::outerRec, "progressOrFullBackground", &layer::CmdRenderRectVerticesFilledLayer::progressOrFullBackground, "cache", &layer::CmdRenderRectVerticesFilledLayer::cache, "color", &layer::CmdRenderRectVerticesFilledLayer::color)
        BIND_CMD(RenderRectVerticesOutlineLayer, "cache", &layer::CmdRenderRectVerticesOutlineLayer::cache, "color", &layer::CmdRenderRectVerticesOutlineLayer::color, "useFullVertices", &layer::CmdRenderRectVerticesOutlineLayer::useFullVertices)
        BIND_CMD(DrawPolygon,            "vertices", &layer::CmdDrawPolygon::vertices, "color", &layer::CmdDrawPolygon::color, "lineWidth", &layer::CmdDrawPolygon::lineWidth)
        BIND_CMD(RenderNPatchRect,       "sourceTexture", &layer::CmdRenderNPatchRect::sourceTexture, "info", &layer::CmdRenderNPatchRect::info, "dest", &layer::CmdRenderNPatchRect::dest, "origin", &layer::CmdRenderNPatchRect::origin, "rotation", &layer::CmdRenderNPatchRect::rotation, "tint", &layer::CmdRenderNPatchRect::tint)
        BIND_CMD(DrawTriangle,           "p1", &layer::CmdDrawTriangle::p1, "p2", &layer::CmdDrawTriangle::p2, "p3", &layer::CmdDrawTriangle::p3, "color", &layer::CmdDrawTriangle::color)

        #undef BIND_CMD

        rec.add_type("layer.CmdBeginDrawing", true);
        rec.record_property("layer.CmdBeginDrawing", { "dummy", "false", "Unused field" });

        rec.add_type("layer.CmdEndDrawing", true);
        rec.record_property("layer.CmdEndDrawing", { "dummy", "false", "Unused field" });

        rec.add_type("layer.CmdClearBackground", true);
        rec.record_property("layer.CmdClearBackground", { "color", "Color", "Background color" });

        rec.add_type("layer.CmdTranslate", true);
        rec.record_property("layer.CmdTranslate", { "x", "number", "X offset" });
        rec.record_property("layer.CmdTranslate", { "y", "number", "Y offset" });

        rec.add_type("layer.CmdScale", true);
        rec.record_property("layer.CmdScale", { "scaleX", "number", "Scale in X" });
        rec.record_property("layer.CmdScale", { "scaleY", "number", "Scale in Y" });

        rec.add_type("layer.CmdRotate", true);
        rec.record_property("layer.CmdRotate", { "angle", "number", "Rotation angle in degrees" });

        rec.add_type("layer.CmdAddPush", true);
        rec.record_property("layer.CmdAddPush", { "camera", "table", "Camera parameters" });

        rec.add_type("layer.CmdAddPop", true);
        rec.record_property("layer.CmdAddPop", { "dummy", "false", "Unused field" });

        rec.add_type("layer.CmdPushMatrix", true);
        rec.record_property("layer.CmdPushMatrix", { "dummy", "false", "Unused field" });

        rec.add_type("layer.CmdPopMatrix", true);
        rec.record_property("layer.CmdPopMatrix", { "dummy", "false", "Unused field" });

        rec.add_type("layer.CmdDrawCircleFilled", true);
        rec.record_property("layer.CmdDrawCircleFilled", { "x", "number", "Center X" });
        rec.record_property("layer.CmdDrawCircleFilled", { "y", "number", "Center Y" });
        rec.record_property("layer.CmdDrawCircleFilled", { "radius", "number", "Radius" });
        rec.record_property("layer.CmdDrawCircleFilled", { "color", "Color", "Fill color" });
        
        rec.add_type("layer.CmdDrawCircleLine", true);
        rec.record_property("layer.CmdDrawCircleLine", { "x", "number", "Center X" });
        rec.record_property("layer.CmdDrawCircleLine", { "y", "number", "Center Y" });
        rec.record_property("layer.CmdDrawCircleLine", { "innerRadius", "number", "Inner radius" });
        rec.record_property("layer.CmdDrawCircleLine", { "outerRadius", "number", "Outer radius" });
        rec.record_property("layer.CmdDrawCircleLine", { "startAngle", "number", "Start angle in degrees" });
        rec.record_property("layer.CmdDrawCircleLine", { "endAngle", "number", "End angle in degrees" });
        rec.record_property("layer.CmdDrawCircleLine", { "segments", "number", "Number of segments" });
        rec.record_property("layer.CmdDrawCircleLine", { "color", "Color", "Line color" });

        rec.add_type("layer.CmdDrawRectangle", true);
        rec.record_property("layer.CmdDrawRectangle", { "x", "number", "Top-left X" });
        rec.record_property("layer.CmdDrawRectangle", { "y", "number", "Top-left Y" });
        rec.record_property("layer.CmdDrawRectangle", { "width", "number", "Width" });
        rec.record_property("layer.CmdDrawRectangle", { "height", "number", "Height" });
        rec.record_property("layer.CmdDrawRectangle", { "color", "Color", "Fill color" });
        rec.record_property("layer.CmdDrawRectangle", { "lineWidth", "number", "Line width" });

        rec.add_type("layer.CmdDrawRectanglePro", true);
        rec.record_property("layer.CmdDrawRectanglePro", { "offsetX", "number", "Offset X" });
        rec.record_property("layer.CmdDrawRectanglePro", { "offsetY", "number", "Offset Y" });
        rec.record_property("layer.CmdDrawRectanglePro", { "size", "Vector2", "Size" });
        rec.record_property("layer.CmdDrawRectanglePro", { "rotationCenter", "Vector2", "Rotation center" });
        rec.record_property("layer.CmdDrawRectanglePro", { "rotation", "number", "Rotation" });
        rec.record_property("layer.CmdDrawRectanglePro", { "color", "Color", "Color" });

        rec.add_type("layer.CmdDrawRectangleLinesPro", true);
        rec.record_property("layer.CmdDrawRectangleLinesPro", { "offsetX", "number", "Offset X" });
        rec.record_property("layer.CmdDrawRectangleLinesPro", { "offsetY", "number", "Offset Y" });
        rec.record_property("layer.CmdDrawRectangleLinesPro", { "size", "Vector2", "Size" });
        rec.record_property("layer.CmdDrawRectangleLinesPro", { "lineThickness", "number", "Line thickness" });
        rec.record_property("layer.CmdDrawRectangleLinesPro", { "color", "Color", "Color" });

        rec.add_type("layer.CmdDrawLine", true);
        rec.record_property("layer.CmdDrawLine", { "x1", "number", "Start X" });
        rec.record_property("layer.CmdDrawLine", { "y1", "number", "Start Y" });
        rec.record_property("layer.CmdDrawLine", { "x2", "number", "End X" });
        rec.record_property("layer.CmdDrawLine", { "y2", "number", "End Y" });
        rec.record_property("layer.CmdDrawLine", { "color", "Color", "Line color" });
        rec.record_property("layer.CmdDrawLine", { "lineWidth", "number", "Line width" });

        rec.add_type("layer.CmdDrawDashedLine", true);
        rec.record_property("layer.CmdDrawDashedLine", { "x1", "number", "Start X" });
        rec.record_property("layer.CmdDrawDashedLine", { "y1", "number", "Start Y" });
        rec.record_property("layer.CmdDrawDashedLine", { "x2", "number", "End X" });
        rec.record_property("layer.CmdDrawDashedLine", { "y2", "number", "End Y" });
        rec.record_property("layer.CmdDrawDashedLine", { "dashSize", "number", "Dash size" });
        rec.record_property("layer.CmdDrawDashedLine", { "gapSize", "number", "Gap size" });
        rec.record_property("layer.CmdDrawDashedLine", { "color", "Color", "Color" });
        rec.record_property("layer.CmdDrawDashedLine", { "lineWidth", "number", "Line width" });

        rec.add_type("layer.CmdDrawText", true);
        rec.record_property("layer.CmdDrawText", { "text", "string", "Text" });
        rec.record_property("layer.CmdDrawText", { "font", "Font", "Font" });
        rec.record_property("layer.CmdDrawText", { "x", "number", "X" });
        rec.record_property("layer.CmdDrawText", { "y", "number", "Y" });
        rec.record_property("layer.CmdDrawText", { "color", "Color", "Color" });
        rec.record_property("layer.CmdDrawText", { "fontSize", "number", "Font size" });

        rec.add_type("layer.CmdDrawTextCentered", true);
        rec.record_property("layer.CmdDrawTextCentered", { "text", "string", "Text" });
        rec.record_property("layer.CmdDrawTextCentered", { "font", "Font", "Font" });
        rec.record_property("layer.CmdDrawTextCentered", { "x", "number", "X" });
        rec.record_property("layer.CmdDrawTextCentered", { "y", "number", "Y" });
        rec.record_property("layer.CmdDrawTextCentered", { "color", "Color", "Color" });
        rec.record_property("layer.CmdDrawTextCentered", { "fontSize", "number", "Font size" });

        rec.add_type("layer.CmdTextPro", true);
        rec.record_property("layer.CmdTextPro", { "text", "string", "Text" });
        rec.record_property("layer.CmdTextPro", { "font", "Font", "Font" });
        rec.record_property("layer.CmdTextPro", { "x", "number", "X" });
        rec.record_property("layer.CmdTextPro", { "y", "number", "Y" });
        rec.record_property("layer.CmdTextPro", { "origin", "Vector2", "Origin" });
        rec.record_property("layer.CmdTextPro", { "rotation", "number", "Rotation" });
        rec.record_property("layer.CmdTextPro", { "fontSize", "number", "Font size" });
        rec.record_property("layer.CmdTextPro", { "spacing", "number", "Spacing" });
        rec.record_property("layer.CmdTextPro", { "color", "Color", "Color" });

        rec.add_type("layer.CmdDrawImage", true);
        rec.record_property("layer.CmdDrawImage", { "image", "Texture2D", "Image" });
        rec.record_property("layer.CmdDrawImage", { "x", "number", "X" });
        rec.record_property("layer.CmdDrawImage", { "y", "number", "Y" });
        rec.record_property("layer.CmdDrawImage", { "rotation", "number", "Rotation" });
        rec.record_property("layer.CmdDrawImage", { "scaleX", "number", "Scale X" });
        rec.record_property("layer.CmdDrawImage", { "scaleY", "number", "Scale Y" });
        rec.record_property("layer.CmdDrawImage", { "color", "Color", "Tint color" });

        rec.add_type("layer.CmdTexturePro", true);
        rec.record_property("layer.CmdTexturePro", { "texture", "Texture2D", "Texture" });
        rec.record_property("layer.CmdTexturePro", { "source", "Rectangle", "Source rect" });
        rec.record_property("layer.CmdTexturePro", { "offsetX", "number", "Offset X" });
        rec.record_property("layer.CmdTexturePro", { "offsetY", "number", "Offset Y" });
        rec.record_property("layer.CmdTexturePro", { "size", "Vector2", "Size" });
        rec.record_property("layer.CmdTexturePro", { "rotationCenter", "Vector2", "Rotation center" });
        rec.record_property("layer.CmdTexturePro", { "rotation", "number", "Rotation" });
        rec.record_property("layer.CmdTexturePro", { "color", "Color", "Color" });

        rec.add_type("layer.CmdDrawEntityAnimation", true);
        rec.record_property("layer.CmdDrawEntityAnimation", { "e", "Entity", "entt::entity" });
        rec.record_property("layer.CmdDrawEntityAnimation", { "registry", "Registry", "EnTT registry" });
        rec.record_property("layer.CmdDrawEntityAnimation", { "x", "number", "X" });
        rec.record_property("layer.CmdDrawEntityAnimation", { "y", "number", "Y" });

        rec.add_type("layer.CmdDrawTransformEntityAnimation", true);
        rec.record_property("layer.CmdDrawTransformEntityAnimation", { "e", "Entity", "entt::entity" });
        rec.record_property("layer.CmdDrawTransformEntityAnimation", { "registry", "Registry", "EnTT registry" });

        rec.add_type("layer.CmdDrawTransformEntityAnimationPipeline", true);
        rec.record_property("layer.CmdDrawTransformEntityAnimationPipeline", { "e", "Entity", "entt::entity" });
        rec.record_property("layer.CmdDrawTransformEntityAnimationPipeline", { "registry", "Registry", "EnTT registry" });

        rec.add_type("layer.CmdSetShader", true);
        rec.record_property("layer.CmdSetShader", { "shader", "Shader", "Shader object" });

        rec.add_type("layer.CmdResetShader", true);

        rec.add_type("layer.CmdSetBlendMode", true);
        rec.record_property("layer.CmdSetBlendMode", { "blendMode", "number", "Blend mode" });

        rec.add_type("layer.CmdUnsetBlendMode", true);
        rec.record_property("layer.CmdUnsetBlendMode", { "dummy", "false", "Unused field" });

        rec.add_type("layer.CmdSendUniformFloat", true);
        rec.record_property("layer.CmdSendUniformFloat", { "shader", "Shader", "Shader" });
        rec.record_property("layer.CmdSendUniformFloat", { "uniform", "string", "Uniform name" });
        rec.record_property("layer.CmdSendUniformFloat", { "value", "number", "Float value" });

        rec.add_type("layer.CmdSendUniformInt", true);
        rec.record_property("layer.CmdSendUniformInt", { "shader", "Shader", "Shader" });
        rec.record_property("layer.CmdSendUniformInt", { "uniform", "string", "Uniform name" });
        rec.record_property("layer.CmdSendUniformInt", { "value", "number", "Int value" });

        rec.add_type("layer.CmdSendUniformVec2", true);
        rec.record_property("layer.CmdSendUniformVec2", { "shader", "Shader", "Shader" });
        rec.record_property("layer.CmdSendUniformVec2", { "uniform", "string", "Uniform name" });
        rec.record_property("layer.CmdSendUniformVec2", { "value", "Vector2", "Vec2 value" });

        rec.add_type("layer.CmdSendUniformVec3", true);
        rec.record_property("layer.CmdSendUniformVec3", { "shader", "Shader", "Shader" });
        rec.record_property("layer.CmdSendUniformVec3", { "uniform", "string", "Uniform name" });
        rec.record_property("layer.CmdSendUniformVec3", { "value", "Vector3", "Vec3 value" });

        rec.add_type("layer.CmdSendUniformVec4", true);
        rec.record_property("layer.CmdSendUniformVec4", { "shader", "Shader", "Shader" });
        rec.record_property("layer.CmdSendUniformVec4", { "uniform", "string", "Uniform name" });
        rec.record_property("layer.CmdSendUniformVec4", { "value", "Vector4", "Vec4 value" });

        rec.add_type("layer.CmdSendUniformFloatArray", true);
        rec.record_property("layer.CmdSendUniformFloatArray", { "shader", "Shader", "Shader" });
        rec.record_property("layer.CmdSendUniformFloatArray", { "uniform", "string", "Uniform name" });
        rec.record_property("layer.CmdSendUniformFloatArray", { "values", "table", "Float array" });

        rec.add_type("layer.CmdSendUniformIntArray", true);
        rec.record_property("layer.CmdSendUniformIntArray", { "shader", "Shader", "Shader" });
        rec.record_property("layer.CmdSendUniformIntArray", { "uniform", "string", "Uniform name" });
        rec.record_property("layer.CmdSendUniformIntArray", { "values", "table", "Int array" });

        rec.add_type("layer.CmdVertex", true);
        rec.record_property("layer.CmdVertex", { "v", "Vector3", "Position" });
        rec.record_property("layer.CmdVertex", { "color", "Color", "Vertex color" });

        rec.add_type("layer.CmdBeginOpenGLMode", true);
        rec.record_property("layer.CmdBeginOpenGLMode", { "mode", "number", "GL mode enum" });

        rec.add_type("layer.CmdEndOpenGLMode", true);
        rec.record_property("layer.CmdEndOpenGLMode", { "dummy", "false", "Unused field" });

        rec.add_type("layer.CmdSetColor", true);
        rec.record_property("layer.CmdSetColor", { "color", "Color", "Draw color" });

        rec.add_type("layer.CmdSetLineWidth", true);
        rec.record_property("layer.CmdSetLineWidth", { "lineWidth", "number", "Line width" });

        rec.add_type("layer.CmdSetTexture", true);
        rec.record_property("layer.CmdSetTexture", { "texture", "Texture2D", "Texture to bind" });

        rec.add_type("layer.CmdRenderRectVerticesFilledLayer", true);
        rec.record_property("layer.CmdRenderRectVerticesFilledLayer", { "outerRec", "Rectangle", "Outer rectangle" });
        rec.record_property("layer.CmdRenderRectVerticesFilledLayer", { "progressOrFullBackground", "bool", "Mode" });
        rec.record_property("layer.CmdRenderRectVerticesFilledLayer", { "cache", "table", "Vertex cache" });
        rec.record_property("layer.CmdRenderRectVerticesFilledLayer", { "color", "Color", "Fill color" });

        rec.add_type("layer.CmdRenderRectVerticesOutlineLayer", true);
        rec.record_property("layer.CmdRenderRectVerticesOutlineLayer", { "cache", "table", "Vertex cache" });
        rec.record_property("layer.CmdRenderRectVerticesOutlineLayer", { "color", "Color", "Outline color" });
        rec.record_property("layer.CmdRenderRectVerticesOutlineLayer", { "useFullVertices", "bool", "Use full vertices" });

        rec.add_type("layer.CmdDrawPolygon", true);
        rec.record_property("layer.CmdDrawPolygon", { "vertices", "table", "Vertex array" });
        rec.record_property("layer.CmdDrawPolygon", { "color", "Color", "Polygon color" });
        rec.record_property("layer.CmdDrawPolygon", { "lineWidth", "number", "Line width" });

        rec.add_type("layer.CmdRenderNPatchRect", true);
        rec.record_property("layer.CmdRenderNPatchRect", { "sourceTexture", "Texture2D", "Source texture" });
        rec.record_property("layer.CmdRenderNPatchRect", { "info", "NPatchInfo", "Nine-patch info" });
        rec.record_property("layer.CmdRenderNPatchRect", { "dest", "Rectangle", "Destination" });
        rec.record_property("layer.CmdRenderNPatchRect", { "origin", "Vector2", "Origin" });
        rec.record_property("layer.CmdRenderNPatchRect", { "rotation", "number", "Rotation" });
        rec.record_property("layer.CmdRenderNPatchRect", { "tint", "Color", "Tint color" });

        rec.add_type("layer.CmdDrawTriangle", true);
        rec.record_property("layer.CmdDrawTriangle", { "p1", "Vector2", "Point 1" });
        rec.record_property("layer.CmdDrawTriangle", { "p2", "Vector2", "Point 2" });
        rec.record_property("layer.CmdDrawTriangle", { "p3", "Vector2", "Point 3" });
        rec.record_property("layer.CmdDrawTriangle", { "color", "Color", "Triangle color" });


        // 3) DrawCommandV2
        layerTbl.new_usertype<layer::DrawCommandV2>("DrawCommandV2",
            sol::constructors<>(),
            "type", &layer::DrawCommandV2::type,
            "data", &layer::DrawCommandV2::data,
            "z",    &layer::DrawCommandV2::z
        );

        rec.add_type("layer.DrawCommandV2", true).doc = "A single draw command with type, data payload, and z-order.";
        rec.record_property("layer.DrawCommandV2", { "type", "number", "The draw command type enum" });
        rec.record_property("layer.DrawCommandV2", { "data", "any",    "The actual command data (CmdX struct)" });
        rec.record_property("layer.DrawCommandV2", { "z",    "number", "Z-order depth value for sorting" });

        // 2) Create the command_buffer sub‐table
        auto cb = luaView["command_buffer"].get_or_create<sol::table>();
        if (!cb.valid()) {
            cb = lua.create_table();
            layerTbl["command_buffer"] = cb;
        }

        // Recorder: Top-level namespace
        rec.add_type("command_buffer");


        // 3) For each CmdXXX, expose a queueXXX helper
        //    Pattern: queueCmdName(layer, init_fn, z)
        #define QUEUE_CMD(cmd)                                                       \
        cb.set_function("queue" #cmd,                                              \
            [](std::shared_ptr<layer::Layer> lyr, sol::function init, int z) {       \
            return ::layer::QueueCommand<                    \
                            ::layer::Cmd##cmd                                       \
                    >(                                                               \
                lyr,                                                                 \
                [&](::layer::Cmd##cmd* c) { init(c); },                              \
                z                                                                    \
            );                                                                     \
            }                                                                        \
        );


        QUEUE_CMD(BeginDrawing)
        QUEUE_CMD(EndDrawing)
        QUEUE_CMD(ClearBackground)
        QUEUE_CMD(Translate)
        QUEUE_CMD(Scale)
        QUEUE_CMD(Rotate)
        QUEUE_CMD(AddPush)
        QUEUE_CMD(AddPop)
        QUEUE_CMD(PushMatrix)
        QUEUE_CMD(PopMatrix)
        QUEUE_CMD(DrawCircleFilled)
        QUEUE_CMD(DrawRectangle)
        QUEUE_CMD(DrawRectanglePro)
        QUEUE_CMD(DrawRectangleLinesPro)
        QUEUE_CMD(DrawLine)
        QUEUE_CMD(DrawDashedLine)
        QUEUE_CMD(DrawText)
        QUEUE_CMD(DrawTextCentered)
        QUEUE_CMD(TextPro)
        QUEUE_CMD(DrawImage)
        QUEUE_CMD(TexturePro)
        QUEUE_CMD(DrawEntityAnimation)
        QUEUE_CMD(DrawTransformEntityAnimation)
        QUEUE_CMD(DrawTransformEntityAnimationPipeline)
        QUEUE_CMD(SetShader)
        QUEUE_CMD(ResetShader)
        QUEUE_CMD(SetBlendMode)
        QUEUE_CMD(UnsetBlendMode)
        QUEUE_CMD(SendUniformFloat)
        QUEUE_CMD(SendUniformInt)
        QUEUE_CMD(SendUniformVec2)
        QUEUE_CMD(SendUniformVec3)
        QUEUE_CMD(SendUniformVec4)
        QUEUE_CMD(SendUniformFloatArray)
        QUEUE_CMD(SendUniformIntArray)
        QUEUE_CMD(Vertex)
        QUEUE_CMD(BeginOpenGLMode)
        QUEUE_CMD(EndOpenGLMode)
        QUEUE_CMD(SetColor)
        QUEUE_CMD(SetLineWidth)
        QUEUE_CMD(SetTexture)
        QUEUE_CMD(RenderRectVerticesFilledLayer)
        QUEUE_CMD(RenderRectVerticesOutlineLayer)
        QUEUE_CMD(DrawPolygon)
        QUEUE_CMD(RenderNPatchRect)
        QUEUE_CMD(DrawTriangle)

        #undef QUEUE_CMD  

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueBeginDrawing",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdBeginDrawing) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdBeginDrawing into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueEndDrawing",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdEndDrawing) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdEndDrawing into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueClearBackground",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdClearBackground) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdClearBackground into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueTranslate",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdTranslate) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdTranslate into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueScale",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdScale) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdScale into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueRotate",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdRotate) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdRotate into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueAddPush",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdAddPush) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdAddPush into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueAddPop",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdAddPop) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdAddPop into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queuePushMatrix",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdPushMatrix) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdPushMatrix into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queuePopMatrix",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdPopMatrix) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdPopMatrix into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueDrawCircle",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdDrawCircleFilled) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdDrawCircleFilled into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueDrawRectangle",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdDrawRectangle) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdDrawRectangle into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueDrawRectanglePro",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdDrawRectanglePro) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdDrawRectanglePro into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueDrawRectangleLinesPro",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdDrawRectangleLinesPro) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdDrawRectangleLinesPro into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueDrawLine",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdDrawLine) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdDrawLine into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueDrawDashedLine",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdDrawDashedLine) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdDrawDashedLine into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueDrawText",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdDrawText) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdDrawText into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueDrawTextCentered",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdDrawTextCentered) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdDrawTextCentered into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueTextPro",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdTextPro) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdTextPro into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueDrawImage",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdDrawImage) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdDrawImage into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueTexturePro",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdTexturePro) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdTexturePro into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueDrawEntityAnimation",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdDrawEntityAnimation) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdDrawEntityAnimation into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueDrawTransformEntityAnimation",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdDrawTransformEntityAnimation) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdDrawTransformEntityAnimation into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueDrawTransformEntityAnimationPipeline",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdDrawTransformEntityAnimationPipeline) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdDrawTransformEntityAnimationPipeline into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueSetShader",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdSetShader) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdSetShader into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueResetShader",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdResetShader) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdResetShader into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueSetBlendMode",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdSetBlendMode) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdSetBlendMode into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueUnsetBlendMode",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdUnsetBlendMode) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdUnsetBlendMode into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueSendUniformFloat",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdSendUniformFloat) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdSendUniformFloat into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueSendUniformInt",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdSendUniformInt) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdSendUniformInt into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueSendUniformVec2",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdSendUniformVec2) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdSendUniformVec2 into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueSendUniformVec3",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdSendUniformVec3) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdSendUniformVec3 into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueSendUniformVec4",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdSendUniformVec4) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdSendUniformVec4 into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueSendUniformFloatArray",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdSendUniformFloatArray) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdSendUniformFloatArray into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueSendUniformIntArray",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdSendUniformIntArray) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdSendUniformIntArray into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueVertex",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdVertex) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdVertex into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueBeginOpenGLMode",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdBeginOpenGLMode) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdBeginOpenGLMode into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueEndOpenGLMode",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdEndOpenGLMode) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdEndOpenGLMode into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueSetColor",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdSetColor) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdSetColor into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueSetLineWidth",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdSetLineWidth) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdSetLineWidth into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueSetTexture",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdSetTexture) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdSetTexture into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueRenderRectVerticesFilledLayer",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdRenderRectVerticesFilledLayer) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdRenderRectVerticesFilledLayer into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueRenderRectVerticesOutlineLayer",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdRenderRectVerticesOutlineLayer) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdRenderRectVerticesOutlineLayer into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueDrawPolygon",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdDrawPolygon) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdDrawPolygon into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueRenderNPatchRect",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdRenderNPatchRect) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdRenderNPatchRect into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

        rec.record_free_function({"layer"}, MethodDef{
            .name = "queueDrawTriangle",
            .signature = R"(---@param layer Layer # Target layer to queue into
        ---@param init_fn fun(c: layer.CmdDrawTriangle) # Function to initialize the command
        ---@param z number # Z-order depth to queue at
        ---@return void)",
            .doc = R"(Queues a CmdDrawTriangle into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.)",
            .is_static = true,
            .is_overload = false
        });

    }

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
        // std::sort(layer->drawCommands.begin(), layer->drawCommands.end(), [](const DrawCommand &a, const DrawCommand &b)
        //           { return a.z < b.z; });
    }

    void AddDrawCommand(std::shared_ptr<Layer> layer, const std::string &type, const std::vector<DrawCommandArgs> &args, int z)
    {
        DrawCommand command{type, args, z};
        // layer->drawCommands.push_back(command);
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
        // layer->drawCommands.clear();
        
        layer_command_buffer::Clear(layer);
    }

    void Begin() {
        // ZoneScopedN("Layer Begin-clear commands");
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
        std::string shaderName)
    {
        // Check canvas validity
        if (srcLayer->canvases.find(srcCanvasName) == srcLayer->canvases.end()) return;
        if (dstLayer->canvases.find(dstCanvasName) == dstLayer->canvases.end()) return;
    
        const RenderTexture2D& srcCanvas = srcLayer->canvases.at(srcCanvasName);
        RenderTexture2D& dstCanvas = dstLayer->canvases.at(dstCanvasName);
    
        
    
        BeginTextureMode(dstCanvas);

        ClearBackground(BLANK);
        
        Shader shader = shaders::getShader(shaderName);
        
        // Optional shader
        if (shader.id != 0) {
            BeginShaderMode(shader);
            
            
            // texture uniforms need to be set after beginShaderMode
            shaders::TryApplyUniforms(shader, globals::globalShaderUniforms, shaderName);
        }
    
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

    
    /**
     * @brief Draws all layer commands to a specific canvas and applies all post-process shaders in sequence.
     *
     * This function first draws the layer's commands to the specified canvas using an optimized version.
     * If the layer has any post-process shaders, it ensures a secondary "pong" render texture exists,
     * then applies each shader in the post-process chain by ping-ponging between the source and destination
     * render textures. After all shaders are applied, if the final result is not in the original canvas,
     * it copies the result back.
     *
     * @param layerPtr Shared pointer to the Layer object containing canvases and shader information.
     * @param canvasName The name of the canvas to which the layer commands should be drawn and shaders applied.
     * @param camera Pointer to the Camera2D object used for rendering.
     */
    void DrawLayerCommandsToSpecificCanvasApplyAllShaders(std::shared_ptr<Layer> layerPtr, const std::string &canvasName, Camera2D *camera) {
        DrawLayerCommandsToSpecificCanvasOptimizedVersion(layerPtr, canvasName, camera);

        // nothing to do if no post-shaders
        if (layerPtr->postProcessShaders.empty()) return;
        
        // 2) Make sure your “ping” buffer exists:
        const std::string ping = canvasName;
        const std::string pong = canvasName + "_double";
        if (layerPtr->canvases.find(pong) == layerPtr->canvases.end()) {
            // create it with same size as ping:
            auto &srcTex = layerPtr->canvases.at(ping);
            layerPtr->canvases[pong] = LoadRenderTexture(srcTex.texture.width, srcTex.texture.height);
        }
        
        // 3) Run the full-screen shader chain:
        std::string src = ping, dst = pong;
        for (auto &shaderName : layerPtr->postProcessShaders) {
            // clear dst
            BeginTextureMode(layerPtr->canvases.at(dst));
            ClearBackground(BLANK);
            EndTextureMode();

            layer::DrawCanvasOntoOtherLayerWithShader(
                layerPtr,  // src layer
                src,                 // src canvas
                layerPtr,  // dst layer
                dst,                 // dst canvas
                0, 0, 0, 1, 1,       // x, y, rot, scaleX, scaleY
                WHITE,
                shaderName
            );
            std::swap(src, dst);
        }
        
        // 4) If the final result isn’t back in “main”, copy it home:
        if (src != canvasName) {
            // clear original ping
            BeginTextureMode(layerPtr->canvases.at(canvasName));
            ClearBackground(BLANK);
            EndTextureMode();
            layer::DrawCanvasOntoOtherLayer(
                layerPtr,
                src,
                layerPtr,
                canvasName,
                0, 0, 0, 1, 1,
                WHITE
            );
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
        // rlEnableDepthTest();
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
            // each triangle is 3 verts
            if (rlCheckRenderBatchLimit(3))
            {
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
        // rlEnableDepthTest();
        rlColor4ub(255, 255, 255, 255); // Reset to white before each draw
        rlSetTexture(0);
        rlDisableColorBlend(); // Disable color blending for solid color
        rlEnableColorBlend(); // Enable color blending for textures
        rlBegin(RL_TRIANGLES);
        rlSetBlendMode(rlBlendMode::RL_BLEND_ALPHA);

        // Draw quads between outer and inner outlines using two triangles each
        for (size_t i = 0; i < outerVertices.size(); i += 2)
        {
            // each triangle is 3 verts
            if (rlCheckRenderBatchLimit(3))
            {
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
    void DrawCanvasToCurrentRenderTargetWithTransform(const std::shared_ptr<Layer> layer, const std::string &canvasName, float x, float y, float rotation, float scaleX, float scaleY, const Color &color, std::string shaderName, bool flat)
    {
        

        if (layer->canvases.find(canvasName) == layer->canvases.end())
            return;
            
        Shader shader = shaders::getShader(shaderName);
        
        // Optional shader
        if (shader.id != 0) {
            BeginShaderMode(shader);
            
            
            // texture uniforms need to be set after beginShaderMode
            shaders::TryApplyUniforms(shader, globals::globalShaderUniforms, shaderName);
        }
            
        

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
        const Rectangle &destRect, const Color &color, std::string shaderName)
    {
        if (layer->canvases.find(canvasName) == layer->canvases.end())
            return;

        Shader shader = shaders::getShader(shaderName);
    
        // Optional shader
        if (shader.id != 0) {
            BeginShaderMode(shader);
            
            
            // texture uniforms need to be set after beginShaderMode
            shaders::TryApplyUniforms(shader, globals::globalShaderUniforms, shaderName);
        }

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
    
    
    //FIXME: for some reason, draw calls are not being executed inside this function. But they do work in the other versino.
    auto DrawTransformEntityWithAnimationWithPipeline(entt::registry& registry, entt::entity e) -> void {
        
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
    
        auto& pipelineComp = registry.get<shader_pipeline::ShaderPipelineComponent>(e);
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
        Rectangle srcRec{
            (float)animationFrame->x,
            (float)animationFrame->y,
            (float)animationFrame->width,
            (float)animationFrame->height
        };
        
        // the destination quad inside your RT, before flipping
        Rectangle dstRec{
            pad,
            pad,
            baseWidth,
            baseHeight
        };
        
        // apply flips by moving origin to the other side and negating size:
        if (flipX) {
            srcRec.x += srcRec.width;
            srcRec.width = -srcRec.width;
            dstRec.x  += dstRec.width;    // move right edge back to pad
            dstRec.width  = -dstRec.width;
        }
        if (flipY) {
            srcRec.y += srcRec.height;
            srcRec.height = -srcRec.height;
            dstRec.y  += dstRec.height;   // move bottom edge back to pad
            dstRec.height = -dstRec.height;
        }
  
        
        // hacky fix to ensure entities are not fully transparent
        if (fgColor.a == 0) {
            // SPDLOG_WARN("Entity {} has a foreground color with alpha 0. Setting to 255.", (int)e);
            fgColor = WHITE;
        }
        
        //FIXME: this works. why doesn't the rest?
        // DrawTexture(*spriteAtlas, 0, 0, WHITE); // Debug draw the atlas to see if it's loaded correctly
        
        if (!shader_pipeline::IsInitialized() 
            || shader_pipeline::width  < (int) renderWidth 
            || shader_pipeline::height < (int) renderHeight) 
        {
            shader_pipeline::ShaderPipelineUnload();
            shader_pipeline::ShaderPipelineInit(renderWidth, renderHeight);
        }
    
        // 2. Draw base sprite to front() (no transforms) = id 6
        render_stack_switch_internal::Push(shader_pipeline::front());
        ClearBackground({0, 0, 0, 0});
        Vector2 drawOffset = { pad, pad };
    
        if (drawBackground) {
            layer::RectanglePro(drawOffset.x, drawOffset.y, {baseWidth, baseHeight}, {0, 0}, 0, bgColor);
        }
    
        if (drawForeground) {
            if (animationFrame) {
                // layer::TexturePro(*spriteAtlas, *animationFrame, drawOffset.x, drawOffset.y, {baseWidth, baseHeight}, {0, 0}, 0, fgColor);
                // layer::TexturePro(*spriteAtlas, srcRec, drawOffset.x, drawOffset.y, {baseWidth * xFlipModifier , -baseHeight * yFlipModifier }, {0, 0}, 0, {fgColor.r, fgColor.g, fgColor.b, fgColor.a});
                
                layer::TexturePro(
                    *spriteAtlas,
                    {animationFrame->x, animationFrame->y, animationFrame->width  * xFlipModifier, animationFrame->height  * -yFlipModifier},
                    drawOffset.x, drawOffset.y,
                    {baseWidth * xFlipModifier, baseHeight * yFlipModifier},
                    {0, 0},
                    0,
                    fgColor
                );
            } else {
                layer::RectanglePro(drawOffset.x, drawOffset.y, {baseWidth, baseHeight}, {0, 0}, 0, fgColor);
            }
        }
    
        render_stack_switch_internal::Pop(); // turn off id 6
    
        // 🟡 Save base sprite result
        RenderTexture2D baseSpriteRender = shader_pipeline::GetBaseRenderTextureCache(); 
        render_stack_switch_internal::Push(baseSpriteRender);
        ClearBackground({0, 0, 0, 0});
        DrawTexture(shader_pipeline::front().texture, 0, 0, WHITE);
        render_stack_switch_internal::Pop();
        
    
        // 3. Apply shader passes
        for (shader_pipeline::ShaderPass& pass : pipelineComp.passes) {
            if (!pass.enabled) continue;
    
            Shader shader = shaders::getShader(pass.shaderName);
            if (!shader.id) {
                SPDLOG_WARN("Shader {} not found for entity {}", pass.shaderName, (int)e);
                continue; // skip if shader is not found
            }
            render_stack_switch_internal::Push(shader_pipeline::back());
            ClearBackground({0, 0, 0, 0});
            BeginShaderMode(shader);
            if (pass.injectAtlasUniforms) {
                injectAtlasUniforms(globals::globalShaderUniforms, pass.shaderName, {0, drawOffset.y / 2,
                        (float)renderWidth,
                        (float)renderHeight}, Vector2{(float)renderWidth, (float)renderHeight}); // FIXME: not sure why, but it only works when I do this instead of the full texture size
                
            }
            
            if (pass.customPrePassFunction) pass.customPrePassFunction();
            //TODO: auto inject sprite atlas texture dims and sprite rect here 
            // injectAtlasUniforms(globals::globalShaderUniforms, pass.shaderName, srcRec, Vector2{(float)spriteAtlas->width, (float)spriteAtlas->height});
            
            TryApplyUniforms(shader, globals::globalShaderUniforms, pass.shaderName);
            DrawTextureRec(shader_pipeline::front().texture, {0, 0, (float)renderWidth * xFlipModifier, (float)-renderHeight * yFlipModifier}, {0, 0}, WHITE); // invert Y 
    
            EndShaderMode();
            render_stack_switch_internal::Pop();
            shader_pipeline::Swap();
            
            shader_pipeline::SetLastRenderTarget(shader_pipeline::front()); 
    
        }
    
        // // 🔵 Save post-pass result
        RenderTexture2D postPassRender = {}; // id 6 is now the result of all passes
        if (!shader_pipeline::GetLastRenderTarget()) {
            shader_pipeline::SetLastRenderTarget(shader_pipeline::front()); // if no passes, we use the front texture
            postPassRender = shader_pipeline::front();
        } else {
            postPassRender = *shader_pipeline::GetLastRenderTarget(); // if there are passes, we use the last render target
        }
        
        // 🟡 Save post shader pass sprite result
        RenderTexture2D postProcessRender = shader_pipeline::GetPostShaderPassRenderTextureCache();
        render_stack_switch_internal::Push(postProcessRender);
        ClearBackground({0, 0, 0, 0});
        DrawTexture(shader_pipeline::front().texture, 0, 0, WHITE);
        render_stack_switch_internal::Pop();
        
        // DrawTexture(postPassRender.texture, 90, 30, WHITE);
    
        // // 4. Overlay draws
        for (const auto& overlay : pipelineComp.overlayDraws) {
            if (!overlay.enabled) continue;
    
            Shader shader = shaders::getShader(overlay.shaderName);
            AssertThat(shader.id, IsGreaterThan(0));
            render_stack_switch_internal::Push(shader_pipeline::front());
            ClearBackground({0, 0, 0, 0});
            BeginShaderMode(shader);
            if (overlay.customPrePassFunction) overlay.customPrePassFunction();
            // injectAtlasUniforms(globals::globalShaderUniforms, overlay.shaderName, srcRec, Vector2{(float)spriteAtlas->width, (float)spriteAtlas->height});
            TryApplyUniforms(shader, globals::globalShaderUniforms, overlay.shaderName);
    
            RenderTexture2D& source = (overlay.inputSource == shader_pipeline::OverlayInputSource::BaseSprite) ? baseSpriteRender : postPassRender;
            DrawTextureRec(source.texture, {0, 0, renderWidth * xFlipModifier, (float)-renderHeight * yFlipModifier}, {0, 0}, WHITE);
    
            EndShaderMode();
            render_stack_switch_internal::Pop();
            shader_pipeline::Swap();
            
            shader_pipeline::SetLastRenderTarget(shader_pipeline::back()); 
    
            // render_stack_switch_internal::Push(shader_pipeline::front());
            // BeginBlendMode((int)overlay.blendMode);
            // DrawTextureRec(shader_pipeline::back().texture, {0, 0, renderWidth * xFlipModifier, (float)-renderHeight * yFlipModifier}, {0, 0}, WHITE);
            // EndBlendMode();
            // render_stack_switch_internal::Pop();
        }
    
        
        RenderTexture toRender{};
        if (pipelineComp.overlayDraws.empty() ==  false) {
            toRender = shader_pipeline::back(); //  in this case it's the overlay draw result
        } else if (pipelineComp.passes.empty() == false) {
            // if there are passes, we use the last render target
            toRender = shader_pipeline::GetPostShaderPassRenderTextureCache();
        } else {
            // nothing?
            toRender = shader_pipeline::GetBaseRenderTextureCache();
        }

        
        // 5. Final draw with transform
        auto& transform = registry.get<transform::Transform>(e);
        Vector2 drawPos = { transform.getVisualX() - pad, transform.getVisualY() - pad }; // why subtract pad here?
        shader_pipeline::SetLastRenderRect({ drawPos.x, drawPos.y, renderWidth, renderHeight }); // shouldn't this store the last dest rect that was drawn on the last texture?
    
        Rectangle sourceRect = { 0, 0, renderWidth, -renderHeight }; // why is origin here?
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
        
        // shadow rendering first
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
                
                // Draw shadow by rendering the same frame with a black tint and offset
                DrawTextureRec(toRender.texture, sourceRect, { 0, 0 }, shadowColor);

                // Reset translation to original position
                Translate(shadowOffsetX, -shadowOffsetY);
            }
        }
        
        
        

        
        DrawTextureRec(toRender.texture, sourceRect, { 0, 0 }, WHITE);
        
        // debug rect
        if (globals::drawDebugInfo) {
            shader_pipeline::width;
            shader_pipeline::height;
            DrawRectangleLines(-pad, -pad, (int)shader_pipeline::width, (int)shader_pipeline::height, RED);
            DrawText(fmt::format("SHADER PASSEntity ID: {}", static_cast<int>(e)).c_str(), 10, 10, 10, RED);
        }
        
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
    
    void CircleLine(float x, float y, float innerRadius, float outerRadius, float startAngle, float endAngle, int segments, const Color &color)
    {
        DrawRing({x, y}, innerRadius, outerRadius, startAngle, endAngle, segments, {color.r, color.g, color.b, color.a});
    }

    void Line(float x1, float y1, float x2, float y2, const Color &color, float lineWidth)
    {
        DrawLineEx({x1, y1}, {x2, y2}, lineWidth, {color.r, color.g, color.b, color.a});
    }

    void RectangleDraw(float x, float y, float width, float height, const Color &color, float lineWidth)
    {
        if (rlCheckRenderBatchLimit(3))
        {
            rlEnd();
            rlDrawRenderBatchActive(); // push what you have
            rlBegin(RL_TRIANGLES);     // start a new batch
        }
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
        if (rlCheckRenderBatchLimit(3))
                {
                    rlEnd();
                    rlDrawRenderBatchActive(); // push what you have
                    rlBegin(RL_TRIANGLES);     // start a new batch
                }
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
        if (rlCheckRenderBatchLimit(3))
                {
                    rlEnd();
                    rlDrawRenderBatchActive(); // push what you have
                    rlBegin(RL_TRIANGLES);     // start a new batch
                }
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