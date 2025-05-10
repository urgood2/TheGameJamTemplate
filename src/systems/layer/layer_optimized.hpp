#pragma once

#include "util/common_headers.hpp"

#include "layer.hpp"

namespace layer
{
    //TODO: something about manual destruction of non-trivial types, make template-based auto-destructor code
    
    /*
    
    std::vector<std::function<void()>> destructors;

    template<typename T>
    T* Add(...) {
        ...
        if constexpr (!std::is_trivially_destructible_v<T>) {
            destructors.emplace_back([cmd]() { cmd->~T(); });
        }
    }

    void Clear() {
        for (auto& d : destructors) d();
        destructors.clear();
        arena.clear();
        commands.clear();
    }

    
    */
    
    // ===========================
    // Command Types
    // ===========================
    

    enum class DrawCommandType {
        BeginDrawing,
        EndDrawing,
        ClearBackground,
        Translate,
        Scale,
        Rotate,
        AddPush,
        AddPop,
        PushMatrix,
        PopMatrix,
        Circle,
        Rectangle,
        RectanglePro,
        RectangleLinesPro,
        Line,
        DashedLine,
        Text,
        DrawTextCentered,
        TextPro,
        DrawImage,
        TexturePro,
        DrawEntityAnimation,
        DrawTransformEntityAnimation,
        DrawTransformEntityAnimationPipeline,
        SetShader,
        ResetShader,
        SetBlendMode,
        UnsetBlendMode,
        SendUniformFloat,
        SendUniformInt,
        SendUniformVec2,
        SendUniformVec3,
        SendUniformVec4,
        SendUniformFloatArray,
        SendUniformIntArray,
        Vertex,
        BeginOpenGLMode, // renamed from begin_mode
        EndOpenGLMode,   // renamed from end_mode
        SetColor, 
        SetLineWidth, 
        SetTexture, 
        RenderRectVerticesFilledLayer, 
        RenderRectVerticlesOutlineLayer, 
        Polygon, 
        RenderNPatchRect, 
        Triangle
    };

    // ===========================
    // Draw Command Structs
    // ===========================
    struct CmdBeginDrawing {};
    struct CmdEndDrawing {};

    struct CmdClearBackground {
        Color color;
    };

    struct CmdTranslate {
        float x, y;
    };

    struct CmdScale {
        float scaleX, scaleY;
    };

    struct CmdRotate {
        float angle;
    };

    struct CmdAddPush {
        Camera2D* camera;
    };

    struct CmdAddPop {};
    struct CmdPushMatrix {};
    struct CmdPopMatrix {};

    struct CmdDrawCircle {
        float x, y, radius;
        Color color;
    };

    struct CmdDrawRectangle {
        float x, y, width, height;
        Color color;
        float lineWidth;
    };

    struct CmdDrawRectanglePro {
        float offsetX, offsetY;
        Vector2 size;
        Vector2 rotationCenter;
        float rotation;
        Color color;
    };

    struct CmdDrawRectangleLinesPro {
        float offsetX, offsetY;
        Vector2 size;
        float lineThickness;
        Color color;
    };

    struct CmdDrawLine {
        float x1, y1, x2, y2;
        Color color;
        float lineWidth;
    };

    struct CmdDrawDashedLine {
        float x1, y1, x2, y2;
        float dashSize, gapSize;
        Color color;
        float lineWidth;
    };

    struct CmdDrawText {
        std::string text;
        Font font;
        float x, y;
        Color color;
        float fontSize;
    };

    struct CmdDrawTextCentered {
        std::string text;
        Font font;
        float x, y;
        Color color;
        float fontSize;
    };

    struct CmdTextPro {
        std::string text;
        Font font;
        float x, y;
        Vector2 origin;
        float rotation;
        float fontSize;
        float spacing;
        Color color;
    };

    struct CmdDrawImage {
        Texture2D image;
        float x, y;
        float rotation;
        float scaleX, scaleY;
        Color color;
    };

    struct CmdTexturePro {
        Texture2D texture;
        Rectangle source;
        float offsetX, offsetY;
        Vector2 size;
        Vector2 rotationCenter;
        float rotation;
        Color color;
    };

    struct CmdDrawEntityAnimation {
        entt::entity e;
        entt::registry* registry;
        int x, y;
    };

    struct CmdDrawTransformEntityAnimation {
        entt::entity e;
        entt::registry* registry;
    };

    struct CmdDrawTransformEntityAnimationPipeline {
        entt::entity e;
        entt::registry* registry;
    };

    struct CmdSetShader {
        Shader shader;
    };

    struct CmdResetShader {};

    struct CmdSetBlendMode {
        int blendMode;
    };

    struct CmdUnsetBlendMode {};

    struct CmdSendUniformFloat {
        Shader shader;
        std::string uniform;
        float value;
    };

    struct CmdSendUniformInt {
        Shader shader;
        std::string uniform;
        int value;
    };

    struct CmdSendUniformVec2 {
        Shader shader;
        std::string uniform;
        Vector2 value;
    };

    struct CmdSendUniformVec3 {
        Shader shader;
        std::string uniform;
        Vector3 value;
    };

    struct CmdSendUniformVec4 {
        Shader shader;
        std::string uniform;
        Vector4 value;
    };

    struct CmdSendUniformFloatArray {
        Shader shader;
        std::string uniform;
        std::vector<float> values;
    };

    struct CmdSendUniformIntArray {
        Shader shader;
        std::string uniform;
        std::vector<int> values;
    };

    struct CmdVertex {
        Vector2 v;
        Color color;
    };

    struct CmdBeginOpenGLMode {
        int mode;
    };

    struct CmdEndOpenGLMode {};

    struct CmdSetColor {
        Color color;
    };

    struct CmdSetLineWidth {
        float lineWidth;
    };

    struct CmdSetTexture {
        Texture2D texture;
    };

    struct CmdRenderRectVerticesFilledLayer {
        std::shared_ptr<layer::Layer> layerPtr;
        Rectangle outerRec;
        bool progressOrFullBackground;
        entt::entity cache;
        Color color;
    };

    struct CmdRenderRectVerticesOutlineLayer {
        std::shared_ptr<layer::Layer> layerPtr;
        entt::entity cache;
        Color color;
        bool useFullVertices;
    };

    struct CmdDrawPolygon {
        std::vector<Vector2> vertices;
        Color color;
        float lineWidth;
    };

    struct CmdRenderNPatchRect {
        Texture2D sourceTexture;
        NPatchInfo info;
        Rectangle dest;
        Vector2 origin;
        float rotation;
        Color tint;
    };

    struct CmdDrawTriangle {
        Vector2 p1, p2, p3;
        Color color;
    };


    // ===========================
    // Draw Command Buffer
    // ===========================
    struct DrawCommandV2 {
        DrawCommandType type;
        void* data;
        int z;
    };

    namespace CommandBuffer {
        static std::vector<std::byte> arena;
        static std::vector<DrawCommandV2> commands;
        static std::vector<std::function<void()>> destructors;
    
        inline void Clear() {
            for (auto& d : destructors) d();
            destructors.clear();
            arena.clear();
            commands.clear();
        }
    
        template<typename T>
        T* Add(DrawCommandType type, int z = 0) {
            size_t offset = arena.size();
            arena.resize(offset + sizeof(T));
            T* cmd = new (&arena[offset]) T{};
            commands.push_back({type, cmd, z});
            if constexpr (!std::is_trivially_destructible_v<T>) {
                destructors.emplace_back([cmd]() { cmd->~T(); });
            }
            return cmd;
        }
    
        inline const std::vector<DrawCommandV2>& GetCommands() {
            return commands;
        }
    } // namespace CommandBufferNS
    

    // ===========================
    // Dispatcher System
    // ===========================
    using RenderFunc = std::function<void(void*)>;
    extern std::unordered_map<DrawCommandType, RenderFunc> dispatcher;

    template<typename T>
    inline void RegisterRenderer(DrawCommandType type, void(*func)(T*)) {
        dispatcher[type] = [func](void* data) {
            func(static_cast<T*>(data));
        };
    }

    // ===========================
    // Render Function Definitions
    // ===========================
    inline void RenderDrawCircle(CmdDrawCircle* c) {
        DrawCircleV({c->x, c->y}, c->radius, c->color);
    }
    
    
    inline void ExecuteTranslate(CmdTranslate* c) {
        Translate(c->x, c->y);
    }
    inline void ExecuteScale(CmdScale* c) {
        Scale(c->scaleX, c->scaleY);
    }
    
    inline void ExecuteRotate(CmdRotate* c) {
        Rotate(c->angle);
    }
    
    inline void ExecuteAddPush(CmdAddPush* c) {
        Push(c->camera);
    }
    
    inline void ExecuteAddPop(CmdAddPop* c) {
        Pop();
    }
    
    inline void ExecutePushMatrix(CmdPushMatrix* c) {
        PushMatrix();
    }
    
    inline void ExecutePopMatrix(CmdPopMatrix* c) {
        PopMatrix();
    }
    
    inline void ExecuteCircle(CmdDrawCircle* c) {
        Circle(c->x, c->y, c->radius, c->color);
    }
    
    inline void ExecuteRectangle(CmdDrawRectangle* c) {
        RectangleDraw(c->x, c->y, c->width, c->height, c->color, c->lineWidth);
    }
    
    inline void ExecuteRectanglePro(CmdDrawRectanglePro* c) {
        RectanglePro(c->offsetX, c->offsetY, c->size, c->rotationCenter, c->rotation, c->color);
    }
    
    inline void ExecuteRectangleLinesPro(CmdDrawRectangleLinesPro* c) {
        RectangleLinesPro(c->offsetX, c->offsetY, c->size, c->lineThickness, c->color);
    }
    
    inline void ExecuteLine(CmdDrawLine* c) {
        Line(c->x1, c->y1, c->x2, c->y2, c->color, c->lineWidth);
    }
    
    inline void ExecuteDashedLine(CmdDrawDashedLine* c) {
        DashedLine(c->x1, c->y1, c->x2, c->y2, c->dashSize, c->gapSize, c->color, c->lineWidth);
    }
    
    inline void ExecuteText(CmdDrawText* c) {
        Text(c->text, c->font, c->x, c->y, c->color, c->fontSize);
    }
    
    inline void ExecuteTextCentered(CmdDrawTextCentered* c) {
        Text(c->text, c->font, c->x, c->y, c->color, c->fontSize);
    }
    
    inline void ExecuteTextPro(CmdTextPro* c) {
        TextPro(c->text, c->font, c->x, c->y, c->origin, c->rotation, c->fontSize, c->spacing, c->color);
    }
    
    inline void ExecuteDrawImage(CmdDrawImage* c) {
        DrawImage(c->image, c->x, c->y, c->rotation, c->scaleX, c->scaleY, c->color);
    }
    
    inline void ExecuteTexturePro(CmdTexturePro* c) {
        TexturePro(c->texture, c->source, c->offsetX, c->offsetY, c->size, c->rotationCenter, c->rotation, c->color);
    }
    
    inline void ExecuteDrawEntityAnimation(CmdDrawEntityAnimation* c) {
        DrawEntityWithAnimation(*c->registry, c->e, c->x, c->y);
    }
    
    inline void ExecuteDrawTransformEntityAnimation(CmdDrawTransformEntityAnimation* c) {
        DrawTransformEntityWithAnimation(*c->registry, c->e);
    }
    
    inline void ExecuteDrawTransformEntityAnimationPipeline(CmdDrawTransformEntityAnimationPipeline* c) {
        DrawTransformEntityWithAnimationWithPipeline(*c->registry, c->e);
    }
    
    inline void ExecuteSetShader(CmdSetShader* c) {
        SetShader(c->shader);
    }
    
    inline void ExecuteResetShader(CmdResetShader* c) {
        ResetShader();
    }
    
    inline void ExecuteSetBlendMode(CmdSetBlendMode* c) {
        SetBlendMode(c->blendMode);
    }
    
    inline void ExecuteUnsetBlendMode(CmdUnsetBlendMode* c) {
        UnsetBlendMode();
    }
    
    inline void ExecuteSendUniformFloat(CmdSendUniformFloat* c) {
        SendUniformFloat(c->shader, c->uniform, c->value);
    }
    
    inline void ExecuteSendUniformInt(CmdSendUniformInt* c) {
        SendUniformInt(c->shader, c->uniform, c->value);
    }
    
    inline void ExecuteSendUniformVec2(CmdSendUniformVec2* c) {
        SendUniformVector2(c->shader, c->uniform, c->value);
    }
    
    inline void ExecuteSendUniformVec3(CmdSendUniformVec3* c) {
        SendUniformVector3(c->shader, c->uniform, c->value);
    }
    
    inline void ExecuteSendUniformVec4(CmdSendUniformVec4* c) {
        SendUniformVector4(c->shader, c->uniform, c->value);
    }
    
    inline void ExecuteSendUniformFloatArray(CmdSendUniformFloatArray* c) {
        SendUniformFloatArray(c->shader, c->uniform, c->values.data(), c->values.size());
    }
    
    inline void ExecuteSendUniformIntArray(CmdSendUniformIntArray* c) {
        SendUniformIntArray(c->shader, c->uniform, c->values.data(), c->values.size());
    }
    
    inline void ExecuteVertex(CmdVertex* c) {
        Vertex(c->v, c->color);
    }
    
    inline void ExecuteBeginOpenGLMode(CmdBeginOpenGLMode* c) {
        BeginRLMode(c->mode);
    }
    
    inline void ExecuteEndOpenGLMode(CmdEndOpenGLMode* c) {
        EndRLMode();
    }
    
    inline void ExecuteSetColor(CmdSetColor* c) {
        SetColor(c->color);
    }
    
    inline void ExecuteSetLineWidth(CmdSetLineWidth* c) {
        SetLineWidth(c->lineWidth);
    }
    
    inline void ExecuteSetTexture(CmdSetTexture* c) {
        SetRLTexture(c->texture);
    }
    
    
    inline void ExecuteRenderRectVerticesFilledLayer(CmdRenderRectVerticesFilledLayer* c) {
        RenderRectVerticesFilledLayer(c->layerPtr, c->outerRec, c->progressOrFullBackground, c->cache, c->color);
    }
    
    inline void ExecuteRenderRectVerticesOutlineLayer(CmdRenderRectVerticesOutlineLayer* c) {
        RenderRectVerticlesOutlineLayer(c->layerPtr, c->cache, c->color, c->useFullVertices);
    }
    
    inline void ExecutePolygon(CmdDrawPolygon* c) {
        Polygon(c->vertices, c->color, c->lineWidth);
    }
    
    inline void ExecuteRenderNPatchRect(CmdRenderNPatchRect* c) {
        RenderNPatchRect(c->sourceTexture, c->info, c->dest, c->origin, c->rotation, c->tint);
    }
    
    inline void ExecuteTriangle(CmdDrawTriangle* c) {
        Triangle(c->p1, c->p2, c->p3, c->color);
    }

    // ===========================
    // Init Dispatch Table Once
    // ===========================
    inline void InitDispatcher() {
        RegisterRenderer<CmdBeginDrawing>(DrawCommandType::BeginDrawing, [](CmdBeginDrawing*) { 
            BeginDrawingAction(); });
        RegisterRenderer<CmdEndDrawing>(DrawCommandType::EndDrawing, [](CmdEndDrawing*) { EndDrawingAction(); });
        RegisterRenderer<CmdClearBackground>(DrawCommandType::ClearBackground, [](CmdClearBackground* c) { 
            ClearBackgroundAction(c->color); 
        });
        RegisterRenderer<CmdTranslate>(DrawCommandType::Translate, ExecuteTranslate);
        RegisterRenderer<CmdScale>(DrawCommandType::Scale, ExecuteScale);
        RegisterRenderer<CmdRotate>(DrawCommandType::Rotate, ExecuteRotate);
        RegisterRenderer<CmdAddPush>(DrawCommandType::AddPush, ExecuteAddPush);
        RegisterRenderer<CmdAddPop>(DrawCommandType::AddPop, ExecuteAddPop);
        RegisterRenderer<CmdPushMatrix>(DrawCommandType::PushMatrix, ExecutePushMatrix);
        RegisterRenderer<CmdPopMatrix>(DrawCommandType::PopMatrix, ExecutePopMatrix);
        RegisterRenderer<CmdDrawCircle>(DrawCommandType::Circle, ExecuteCircle);
        RegisterRenderer<CmdDrawRectangle>(DrawCommandType::Rectangle, ExecuteRectangle);
        RegisterRenderer<CmdDrawRectanglePro>(DrawCommandType::RectanglePro, ExecuteRectanglePro);
        RegisterRenderer<CmdDrawRectangleLinesPro>(DrawCommandType::RectangleLinesPro, ExecuteRectangleLinesPro);
        RegisterRenderer<CmdDrawLine>(DrawCommandType::Line, ExecuteLine);
        RegisterRenderer<CmdDrawDashedLine>(DrawCommandType::DashedLine, ExecuteDashedLine);
        RegisterRenderer<CmdDrawText>(DrawCommandType::Text, ExecuteText);
        RegisterRenderer<CmdDrawTextCentered>(DrawCommandType::DrawTextCentered, ExecuteTextCentered);
        RegisterRenderer<CmdTextPro>(DrawCommandType::TextPro, ExecuteTextPro);
        RegisterRenderer<CmdDrawImage>(DrawCommandType::DrawImage, ExecuteDrawImage);
        RegisterRenderer<CmdTexturePro>(DrawCommandType::TexturePro, ExecuteTexturePro);
        RegisterRenderer<CmdDrawEntityAnimation>(DrawCommandType::DrawEntityAnimation, ExecuteDrawEntityAnimation);
        RegisterRenderer<CmdDrawTransformEntityAnimation>(DrawCommandType::DrawTransformEntityAnimation, ExecuteDrawTransformEntityAnimation);
        RegisterRenderer<CmdDrawTransformEntityAnimationPipeline>(DrawCommandType::DrawTransformEntityAnimationPipeline, ExecuteDrawTransformEntityAnimationPipeline);
        RegisterRenderer<CmdSetShader>(DrawCommandType::SetShader, ExecuteSetShader);
        RegisterRenderer<CmdResetShader>(DrawCommandType::ResetShader, ExecuteResetShader);
        RegisterRenderer<CmdSetBlendMode>(DrawCommandType::SetBlendMode, ExecuteSetBlendMode);
        RegisterRenderer<CmdUnsetBlendMode>(DrawCommandType::UnsetBlendMode, ExecuteUnsetBlendMode);
        RegisterRenderer<CmdSendUniformFloat>(DrawCommandType::SendUniformFloat, ExecuteSendUniformFloat);
        RegisterRenderer<CmdSendUniformInt>(DrawCommandType::SendUniformInt, ExecuteSendUniformInt);
        RegisterRenderer<CmdSendUniformVec2>(DrawCommandType::SendUniformVec2, ExecuteSendUniformVec2);
        RegisterRenderer<CmdSendUniformVec3>(DrawCommandType::SendUniformVec3, ExecuteSendUniformVec3);
        RegisterRenderer<CmdSendUniformVec4>(DrawCommandType::SendUniformVec4, ExecuteSendUniformVec4);
        RegisterRenderer<CmdSendUniformFloatArray>(DrawCommandType::SendUniformFloatArray, ExecuteSendUniformFloatArray);
        RegisterRenderer<CmdSendUniformIntArray>(DrawCommandType::SendUniformIntArray, ExecuteSendUniformIntArray);
        RegisterRenderer<CmdVertex>(DrawCommandType::Vertex, ExecuteVertex);
        RegisterRenderer<CmdBeginOpenGLMode>(DrawCommandType::BeginOpenGLMode, ExecuteBeginOpenGLMode);
        RegisterRenderer<CmdEndOpenGLMode>(DrawCommandType::EndOpenGLMode, ExecuteEndOpenGLMode);
        RegisterRenderer<CmdSetColor>(DrawCommandType::SetColor, ExecuteSetColor);
        RegisterRenderer<CmdSetLineWidth>(DrawCommandType::SetLineWidth, ExecuteSetLineWidth);
        RegisterRenderer<CmdSetTexture>(DrawCommandType::SetTexture, ExecuteSetTexture);
        RegisterRenderer<CmdRenderRectVerticesFilledLayer>(DrawCommandType::RenderRectVerticesFilledLayer, ExecuteRenderRectVerticesFilledLayer);
        RegisterRenderer<CmdRenderRectVerticesOutlineLayer>(DrawCommandType::RenderRectVerticlesOutlineLayer, ExecuteRenderRectVerticesOutlineLayer);
        RegisterRenderer<CmdDrawPolygon>(DrawCommandType::Polygon, ExecutePolygon);
        RegisterRenderer<CmdRenderNPatchRect>(DrawCommandType::RenderNPatchRect, ExecuteRenderNPatchRect);
        RegisterRenderer<CmdDrawTriangle>(DrawCommandType::Triangle, ExecuteTriangle);
    }

}
   