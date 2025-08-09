#include "layer_command_buffer.hpp"
#include "layer.hpp"

namespace layer
{
    namespace layer_command_buffer
    {
        
        const std::vector<DrawCommandV2>& GetCommandsSorted(const std::shared_ptr<Layer>& layer) {
            if (!layer->isSorted) {
                std::stable_sort(layer->commands.begin(), layer->commands.end(), [](const DrawCommandV2& a, const DrawCommandV2& b) {
                    return a.z < b.z;
                });
                layer->isSorted = true;
            }
            return layer->commands;
        }
        
        void Clear(std::shared_ptr<Layer>& layer) {
            for (auto& cmd : layer->commands) {
                switch (cmd.type) {
                    DELETE_COMMAND(layer, RenderUISelfImmediate, CmdRenderUISelfImmediate)
                    DELETE_COMMAND(layer, RenderUISliceFromDrawList, CmdRenderUISliceFromDrawList)
                    DELETE_COMMAND(layer, BeginDrawing, CmdBeginDrawing)
                    DELETE_COMMAND(layer, EndDrawing, CmdEndDrawing)
                    DELETE_COMMAND(layer, BeginScissorMode, CmdBeginScissorMode)
                    DELETE_COMMAND(layer, EndScissorMode, CmdEndScissorMode)
                    DELETE_COMMAND(layer, ClearBackground, CmdClearBackground)
                    DELETE_COMMAND(layer, Translate, CmdTranslate)
                    DELETE_COMMAND(layer, Scale, CmdScale)
                    DELETE_COMMAND(layer, Rotate, CmdRotate)
                    DELETE_COMMAND(layer, AddPush, CmdAddPush)
                    DELETE_COMMAND(layer, AddPop, CmdAddPop)
                    DELETE_COMMAND(layer, PushMatrix, CmdPushMatrix)
                    DELETE_COMMAND(layer, PopMatrix, CmdPopMatrix)
                    DELETE_COMMAND(layer, Circle, CmdDrawCircleFilled)
                    DELETE_COMMAND(layer, CircleLine, CmdDrawCircleLine)
                    DELETE_COMMAND(layer, Rectangle, CmdDrawRectangle)
                    DELETE_COMMAND(layer, RectanglePro, CmdDrawRectanglePro)
                    DELETE_COMMAND(layer, RectangleLinesPro, CmdDrawRectangleLinesPro)
                    DELETE_COMMAND(layer, Line, CmdDrawLine)
                    DELETE_COMMAND(layer, DashedLine, CmdDrawDashedLine)
                    DELETE_COMMAND(layer, Text, CmdDrawText)
                    DELETE_COMMAND(layer, DrawTextCentered, CmdDrawTextCentered)
                    DELETE_COMMAND(layer, TextPro, CmdTextPro)
                    DELETE_COMMAND(layer, DrawImage, CmdDrawImage)
                    DELETE_COMMAND(layer, TexturePro, CmdTexturePro)
                    DELETE_COMMAND(layer, DrawEntityAnimation, CmdDrawEntityAnimation)
                    DELETE_COMMAND(layer, DrawTransformEntityAnimation, CmdDrawTransformEntityAnimation)
                    DELETE_COMMAND(layer, DrawTransformEntityAnimationPipeline, CmdDrawTransformEntityAnimationPipeline)
                    DELETE_COMMAND(layer, SetShader, CmdSetShader)
                    DELETE_COMMAND(layer, ResetShader, CmdResetShader)
                    DELETE_COMMAND(layer, SetBlendMode, CmdSetBlendMode)
                    DELETE_COMMAND(layer, UnsetBlendMode, CmdUnsetBlendMode)
                    DELETE_COMMAND(layer, SendUniformFloat, CmdSendUniformFloat)
                    DELETE_COMMAND(layer, SendUniformInt, CmdSendUniformInt)
                    DELETE_COMMAND(layer, SendUniformVec2, CmdSendUniformVec2)
                    DELETE_COMMAND(layer, SendUniformVec3, CmdSendUniformVec3)
                    DELETE_COMMAND(layer, SendUniformVec4, CmdSendUniformVec4)
                    DELETE_COMMAND(layer, SendUniformFloatArray, CmdSendUniformFloatArray)
                    DELETE_COMMAND(layer, SendUniformIntArray, CmdSendUniformIntArray)
                    DELETE_COMMAND(layer, Vertex, CmdVertex)
                    DELETE_COMMAND(layer, BeginOpenGLMode, CmdBeginOpenGLMode)
                    DELETE_COMMAND(layer, EndOpenGLMode, CmdEndOpenGLMode)
                    DELETE_COMMAND(layer, SetColor, CmdSetColor)
                    DELETE_COMMAND(layer, SetLineWidth, CmdSetLineWidth)
                    DELETE_COMMAND(layer, SetTexture, CmdSetTexture)
                    DELETE_COMMAND(layer, RenderRectVerticesFilledLayer, CmdRenderRectVerticesFilledLayer)
                    DELETE_COMMAND(layer, RenderRectVerticlesOutlineLayer, CmdRenderRectVerticesOutlineLayer)
                    DELETE_COMMAND(layer, Polygon, CmdDrawPolygon)
                    DELETE_COMMAND(layer, RenderNPatchRect, CmdRenderNPatchRect)
                    DELETE_COMMAND(layer, Triangle, CmdDrawTriangle)
                    default:
                        SPDLOG_ERROR("Unknown command type: {}", magic_enum::enum_name(cmd.type));
                        break;
                }
            }
        
            layer->commands.clear();
            layer->isSorted = true;
        }
    }
}