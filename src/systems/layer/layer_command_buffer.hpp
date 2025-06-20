#pragma once

#include <typeindex>
#include <unordered_map>

#include "util/common_headers.hpp"
#include "layer_optimized.hpp"

namespace layer::layer_command_buffer {
    template <typename T>
    DynamicObjectPoolWrapper<T>& GetDrawCommandPool(Layer& layer);
}

#define DELETE_COMMAND(layer, typeEnum, CmdType) \
    case DrawCommandType::typeEnum: \
        layer_command_buffer::GetDrawCommandPool<CmdType>(*layer).delete_object(static_cast<CmdType*>(cmd.data)); \
        break;

namespace layer
{
    namespace layer_command_buffer {

        inline void Clear(std::shared_ptr<Layer>& layer) {
            for (auto& cmd : layer->commands) {
                switch (cmd.type) {
                    DELETE_COMMAND(layer, BeginDrawing, CmdBeginDrawing)
                    DELETE_COMMAND(layer, EndDrawing, CmdEndDrawing)
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

        
    
        template<typename T>
        DrawCommandType GetDrawCommandType();

        
        // Explicit specializations for GetDrawCommandType
        template<> inline DrawCommandType GetDrawCommandType<CmdBeginDrawing>() { return DrawCommandType::BeginDrawing; }
        template<> inline DrawCommandType GetDrawCommandType<CmdEndDrawing>() { return DrawCommandType::EndDrawing; }
        template<> inline DrawCommandType GetDrawCommandType<CmdClearBackground>() { return DrawCommandType::ClearBackground; }
        template<> inline DrawCommandType GetDrawCommandType<CmdTranslate>() { return DrawCommandType::Translate; }
        template<> inline DrawCommandType GetDrawCommandType<CmdScale>() { return DrawCommandType::Scale; }
        template<> inline DrawCommandType GetDrawCommandType<CmdRotate>() { return DrawCommandType::Rotate; }
        template<> inline DrawCommandType GetDrawCommandType<CmdAddPush>() { return DrawCommandType::AddPush; }
        template<> inline DrawCommandType GetDrawCommandType<CmdAddPop>() { return DrawCommandType::AddPop; }
        template<> inline DrawCommandType GetDrawCommandType<CmdPushMatrix>() { return DrawCommandType::PushMatrix; }
        template<> inline DrawCommandType GetDrawCommandType<CmdPopMatrix>() { return DrawCommandType::PopMatrix; }
        template<> inline DrawCommandType GetDrawCommandType<CmdDrawCircleFilled>() { return DrawCommandType::Circle; }
        template<> inline DrawCommandType GetDrawCommandType<CmdDrawCircleLine>() { return DrawCommandType::CircleLine; }
        template<> inline DrawCommandType GetDrawCommandType<CmdDrawRectangle>() { return DrawCommandType::Rectangle; }
        template<> inline DrawCommandType GetDrawCommandType<CmdDrawRectanglePro>() { return DrawCommandType::RectanglePro; }
        template<> inline DrawCommandType GetDrawCommandType<CmdDrawRectangleLinesPro>() { return DrawCommandType::RectangleLinesPro; }
        template<> inline DrawCommandType GetDrawCommandType<CmdDrawLine>() { return DrawCommandType::Line; }
        template<> inline DrawCommandType GetDrawCommandType<CmdDrawDashedLine>() { return DrawCommandType::DashedLine; }
        template<> inline DrawCommandType GetDrawCommandType<CmdDrawText>() { return DrawCommandType::Text; }
        template<> inline DrawCommandType GetDrawCommandType<CmdDrawTextCentered>() { return DrawCommandType::DrawTextCentered; }
        template<> inline DrawCommandType GetDrawCommandType<CmdTextPro>() { return DrawCommandType::TextPro; }
        template<> inline DrawCommandType GetDrawCommandType<CmdDrawImage>() { return DrawCommandType::DrawImage; }
        template<> inline DrawCommandType GetDrawCommandType<CmdTexturePro>() { return DrawCommandType::TexturePro; }
        template<> inline DrawCommandType GetDrawCommandType<CmdDrawEntityAnimation>() { return DrawCommandType::DrawEntityAnimation; }
        template<> inline DrawCommandType GetDrawCommandType<CmdDrawTransformEntityAnimation>() { return DrawCommandType::DrawTransformEntityAnimation; }
        template<> inline DrawCommandType GetDrawCommandType<CmdDrawTransformEntityAnimationPipeline>() { return DrawCommandType::DrawTransformEntityAnimationPipeline; }
        template<> inline DrawCommandType GetDrawCommandType<CmdSetShader>() { return DrawCommandType::SetShader; }
        template<> inline DrawCommandType GetDrawCommandType<CmdResetShader>() { return DrawCommandType::ResetShader; }
        template<> inline DrawCommandType GetDrawCommandType<CmdSetBlendMode>() { return DrawCommandType::SetBlendMode; }
        template<> inline DrawCommandType GetDrawCommandType<CmdUnsetBlendMode>() { return DrawCommandType::UnsetBlendMode; }
        template<> inline DrawCommandType GetDrawCommandType<CmdSendUniformFloat>() { return DrawCommandType::SendUniformFloat; }
        template<> inline DrawCommandType GetDrawCommandType<CmdSendUniformInt>() { return DrawCommandType::SendUniformInt; }
        template<> inline DrawCommandType GetDrawCommandType<CmdSendUniformVec2>() { return DrawCommandType::SendUniformVec2; }
        template<> inline DrawCommandType GetDrawCommandType<CmdSendUniformVec3>() { return DrawCommandType::SendUniformVec3; }
        template<> inline DrawCommandType GetDrawCommandType<CmdSendUniformVec4>() { return DrawCommandType::SendUniformVec4; }
        template<> inline DrawCommandType GetDrawCommandType<CmdSendUniformFloatArray>() { return DrawCommandType::SendUniformFloatArray; }
        template<> inline DrawCommandType GetDrawCommandType<CmdSendUniformIntArray>() { return DrawCommandType::SendUniformIntArray; }
        template<> inline DrawCommandType GetDrawCommandType<CmdVertex>() { return DrawCommandType::Vertex; }
        template<> inline DrawCommandType GetDrawCommandType<CmdBeginOpenGLMode>() { return DrawCommandType::BeginOpenGLMode; }
        template<> inline DrawCommandType GetDrawCommandType<CmdEndOpenGLMode>() { return DrawCommandType::EndOpenGLMode; }
        template<> inline DrawCommandType GetDrawCommandType<CmdSetColor>() { return DrawCommandType::SetColor; }
        template<> inline DrawCommandType GetDrawCommandType<CmdSetLineWidth>() { return DrawCommandType::SetLineWidth; }
        template<> inline DrawCommandType GetDrawCommandType<CmdSetTexture>() { return DrawCommandType::SetTexture; }
        template<> inline DrawCommandType GetDrawCommandType<CmdRenderRectVerticesFilledLayer>() { return DrawCommandType::RenderRectVerticesFilledLayer; }
        template<> inline DrawCommandType GetDrawCommandType<CmdRenderRectVerticesOutlineLayer>() { return DrawCommandType::RenderRectVerticlesOutlineLayer; }
        template<> inline DrawCommandType GetDrawCommandType<CmdDrawPolygon>() { return DrawCommandType::Polygon; }
        template<> inline DrawCommandType GetDrawCommandType<CmdRenderNPatchRect>() { return DrawCommandType::RenderNPatchRect; }
        template<> inline DrawCommandType GetDrawCommandType<CmdDrawTriangle>() { return DrawCommandType::Triangle; }
        
        template <typename T>
        struct PoolBlockSize {
            static constexpr ::detail::index_t value = 128;
        };

        // Optional: specialize for types that need more space
        template <>
        struct PoolBlockSize<CmdVertex> {
            static constexpr ::detail::index_t value = 512;
        };


        template<typename T>
        T* AddExplicit(std::shared_ptr<Layer>& layer, DrawCommandType type, int z = 0) {
            // 1) Pool lookup in O(1)
            T* cmd = GetDrawCommandPool<T>(*layer).new_object();
            assert(cmd && "Draw command allocation failed");

            // 2) Append to vector
            layer->commands.push_back({ type, cmd, z });
            if (z != 0) {
                layer->isSorted = false;
            }
            return cmd;
        }

        template<typename T>
        inline T* Add(std::shared_ptr<Layer>& layer, int z = 0) {
            return AddExplicit<T>(layer, GetDrawCommandType<T>(), z);
        }


        // --------------------------------------------------------------------------------------
        //  GetDrawCommandPool<T>(layer)
        //  --------------------------------
        //  - Uses a preallocated array slot: index = static_cast<size_t>(GetDrawCommandType<T>())
        //  - If slot is null, allocate a new DynamicObjectPoolWrapper<T>, store pointer there.
        //  - Always returns a reference to the pool for type T.
        //
        // layer_command_buffer.hpp (excerpt)
        template<typename T>    
        inline DynamicObjectPoolWrapper<T>& GetDrawCommandPool(Layer& layer) {
            size_t idx = static_cast<size_t>(GetDrawCommandType<T>());
            assert(
                idx < static_cast<size_t>(DrawCommandType::Count)
                && "GetDrawCommandType<T>() returned out‐of‐range DrawCommandType"
            );

            auto& slot = layer.commandPoolsArray[idx];
            if (!slot) {
                // Allocate and store the unique_ptr
                slot = std::make_unique<DynamicObjectPoolWrapper<T>>(PoolBlockSize<T>::value);
            }

            // Cast back to the derived pool type
            return *static_cast<DynamicObjectPoolWrapper<T>*>(slot.get());
        }
    
        inline const std::vector<DrawCommandV2>& GetCommandsSorted(const std::shared_ptr<Layer>& layer) {
            if (!layer->isSorted) {
                std::stable_sort(layer->commands.begin(), layer->commands.end(), [](const DrawCommandV2& a, const DrawCommandV2& b) {
                    return a.z < b.z;
                });
                layer->isSorted = true;
            }
            return layer->commands;
        }
        
    } // namespace CommandBufferNS
    
    // Inline, header‐only. Takes any callable (lambda, function, struct) that can be invoked as init(cmd).
    template<typename T, typename Initializer>
    inline T* QueueCommand(std::shared_ptr<Layer> layer, Initializer&& init, int z = 0) {
        T* cmd = layer_command_buffer::Add<T>(layer, z);
        // inlined call, no std::function
        init(cmd);
        return cmd;
    }
    
    /// Logs the block count and current allocations for a given CmdType pool
    template<typename CmdType>
    inline void LogPoolStats(const std::shared_ptr<Layer>& layer) {
        auto& pool = layer_command_buffer::GetDrawCommandPool<CmdType>(*layer);
        ObjectPoolStats stats = pool.calc_stats();
        DrawCommandType cmdType = layer_command_buffer::GetDrawCommandType<CmdType>();
        
        // magic_enum::enum_name returns a std::string_view; convert to std::string for logging
        auto nameView = magic_enum::enum_name(cmdType);
        std::string name{nameView};
        
        spdlog::info("[PoolStats] {} → blocks={}, allocs={}", name, stats.num_blocks, stats.num_allocations);
    }
    
    /// 
    /// Logs stats for all draw-command pools defined in DrawCommandType.
    /// Usage: layer::layer_command_buffer::LogAllPoolStats(myLayerPtr);
    inline void LogAllPoolStats(const std::shared_ptr<Layer>& layer) {
        // Define the list of all command types here
        using AllCmds = std::tuple<
            CmdBeginDrawing,
            CmdEndDrawing,
            CmdClearBackground,
            CmdTranslate,
            CmdScale,
            CmdRotate,
            CmdAddPush,
            CmdAddPop,
            CmdPushMatrix,
            CmdPopMatrix,
            CmdDrawCircleFilled,
            CmdDrawCircleLine,
            CmdDrawRectangle,
            CmdDrawRectanglePro,
            CmdDrawRectangleLinesPro,
            CmdDrawLine,
            CmdDrawDashedLine,
            CmdDrawText,
            CmdDrawTextCentered,
            CmdTextPro,
            CmdDrawImage,
            CmdTexturePro,
            CmdDrawEntityAnimation,
            CmdDrawTransformEntityAnimation,
            CmdDrawTransformEntityAnimationPipeline,
            CmdSetShader,
            CmdResetShader,
            CmdSetBlendMode,
            CmdUnsetBlendMode,
            CmdSendUniformFloat,
            CmdSendUniformInt,
            CmdSendUniformVec2,
            CmdSendUniformVec3,
            CmdSendUniformVec4,
            CmdSendUniformFloatArray,
            CmdSendUniformIntArray,
            CmdVertex,
            CmdBeginOpenGLMode,
            CmdEndOpenGLMode,
            CmdSetColor,
            CmdSetLineWidth,
            CmdSetTexture,
            CmdRenderRectVerticesFilledLayer,
            CmdRenderRectVerticesOutlineLayer,
            CmdDrawPolygon,
            CmdRenderNPatchRect,
            CmdDrawTriangle
        >;

        // Unpack and log for each
        std::apply([&](auto... cmd){
            (LogPoolStats<std::decay_t<decltype(cmd)>>(layer), ...);
        }, AllCmds{});
    }

}