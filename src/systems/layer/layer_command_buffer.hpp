#pragma once

#include "util/common_headers.hpp"
#include "layer_optimized.hpp"

namespace layer
{
    namespace CommandBuffer {
        extern std::vector<std::byte> arena;
        extern std::vector<DrawCommandV2> commands;
        extern std::vector<std::function<void()>> destructors;
        extern bool isSorted;
    
        inline void Clear() {
            for (auto& d : destructors) d();
            destructors.clear();
            arena.clear();
            commands.clear();
            isSorted = true;
        }
    
        template<typename T>
        T* AddExplicit(DrawCommandType type, int z = 0) {
            size_t offset = arena.size();
            arena.resize(offset + sizeof(T));
            T* cmd = new (&arena[offset]) T{};
            commands.push_back({type, cmd, z});
            if constexpr (!std::is_trivially_destructible_v<T>) {
                destructors.emplace_back([cmd]() { cmd->~T(); });
            }
            if (z != 0) isSorted = false;
            return cmd;
        }
    
        template<typename T>
        DrawCommandType GetDrawCommandType();
    
        template<typename T>
        T* Add(int z = 0) {
            return AddExplicit<T>(GetDrawCommandType<T>(), z);
        }
    
        inline const std::vector<DrawCommandV2>& GetCommandsSorted() {
            if (!isSorted) {
                std::stable_sort(commands.begin(), commands.end(), [](const DrawCommandV2& a, const DrawCommandV2& b) {
                    return a.z < b.z;
                });
                isSorted = true;
            }
            return commands;
        }
    
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
        template<> inline DrawCommandType GetDrawCommandType<CmdDrawCircle>() { return DrawCommandType::Circle; }
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
    } // namespace CommandBufferNS
}