#pragma once

#include "raylib.h"
#include "raymath.h"

#include "entt/fwd.hpp"

#include <optional>
#include <vector>
#include <unordered_map>
#include <string>
#include <functional> 

#include "third_party/objectpool-master/src/object_pool.hpp"
#include "systems/layer/layer_command_buffer_data.hpp"
#include "third_party/spine_impl/spine_raylib.hpp"

namespace layer
{
    struct Layer;

    // Performance monitoring
    inline int g_drawCallsThisFrame = 0;

    // Draw call statistics by source type
    struct DrawCallStats {
        uint32_t sprites = 0;      // Sprites, animations, entities
        uint32_t text = 0;         // All text rendering
        uint32_t shapes = 0;       // Primitives (circles, rectangles, lines, etc.)
        uint32_t ui = 0;           // UI elements
        uint32_t state = 0;        // State changes (transforms, shaders, blend modes)
        uint32_t other = 0;        // Everything else

        void reset() {
            sprites = text = shapes = ui = state = other = 0;
        }

        uint32_t total() const {
            return sprites + text + shapes + ui + state + other;
        }
    };

    inline DrawCallStats g_drawCallStats;

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
        BeginScissorMode,
        EndScissorMode,
        Translate,
        Scale,
        Rotate,
        AddPush,
        AddPop,
        PushMatrix,
        PopMatrix,
        ScopedTransformCompositeRender,
        ScopedTransformCompositeRenderWithPipeline,
        PushObjectTransformsToMatrix,
        Circle,
        CircleLine,
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
        Triangle,
        RenderUISliceFromDrawList, // for ui
        RenderUISelfImmediate, // for ui
        ClearStencilBuffer,
        StencilOp,
        RenderBatchFlush,
        AtomicStencilMask,
        ColorMask,
        StencilFunc,
        BeginStencilMode,
        BeginStencilMask,
        EndStencilMode,
        EndStencilMask,
        DrawCenteredEllipse,
        DrawRoundedLine,
        DrawPolyline,
        DrawArc,
        DrawTriangleEquilateral,
        DrawCenteredFilledRoundedRect,
        DrawSpriteCentered,
        DrawSpriteTopLeft,
        DrawDashedCircle,
        DrawDashedRoundedRect,
        DrawDashedLine,
        DrawGradientRectCentered,
        DrawGradientRectRoundedCentered,
        DrawBatchedEntities,
        DrawRenderGroup,

        Count // <--- always last
    };
    
    // ===========================
    // Draw Command Buffer
    // ===========================
    
    enum class DrawCommandSpace {
        World,
        Screen
    };

    struct DrawCommandV2 {
        DrawCommandType type;
        void* data;
        int z;
        DrawCommandSpace space = DrawCommandSpace::Screen; // Default to screen space

        uint64_t uniqueID = 0; // For stable sorting
        uint64_t followAnchor;   // 0 = none

        // NEW: For shader/texture batching optimization (opt-in)
        unsigned int shader_id = 0;
        unsigned int texture_id = 0;
    };

    // ===========================
    // Draw Command Structs
    // ===========================
    struct CmdRenderUISliceFromDrawList {
        std::vector<ui::UIDrawListItem> drawList;
        size_t startIndex;
        size_t endIndex;
        std::shared_ptr<layer::Layer> layerPtr;
        float pad = 10.f; // Padding around the slice
    };

    struct CmdRenderUISelfImmediate {
        entt::entity entity;
        entt::registry* registry;
        // Components needed for rendering
        // These should be fetched from the registry in the render function
        // UIElementComponent, UIConfig, UIState, GameObject, Transform
    };
    
    struct CmdBeginScissorMode {
        Rectangle area;
    };
    
    struct CmdEndScissorMode {
        bool dummy = false; // Placeholder, struct can't be empty
    };

    struct CmdBeginDrawing {
        bool dummy = false; // Placeholder
    };
    struct CmdEndDrawing {
        bool dummy = false; // Placeholder
    };

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

    struct CmdAddPop {
        bool dummy = false; // Placeholder
    };
    struct CmdPushMatrix {
        bool dummy = false; // Placeholder
    };
    struct CmdPopMatrix {
        bool dummy = false; // Placeholder
    };
    
    struct CmdPushObjectTransformsToMatrix {
        entt::entity entity;
    };
    
    struct CmdScopedTransformCompositeRender {
        entt::entity entity;
        std::vector<DrawCommandV2> children;
    };

    // Like ScopedTransformCompositeRender, but also executes the shader pipeline
    // for the entity's BatchedLocalCommands. Use this for text/shapes that need
    // to render through shader effects (e.g., polychrome, holo, dissolve).
    struct CmdScopedTransformCompositeRenderWithPipeline {
        entt::entity entity;
        std::vector<DrawCommandV2> children;
        entt::registry* registry = nullptr;  // Needed for pipeline execution
    };

    struct CmdDrawCircleFilled {
        float x, y, radius;
        Color color;
    };
    
    struct CmdDrawCircleLine {
        float x, y, innerRadius, outerRadius, startAngle, endAngle;
        int segments;
        Color color;
    };

    struct CmdDrawRectangle {
        float x, y, width, height;
        Color color;
        float lineWidth = 1.0f;
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
        float lineThickness = 1.0f;
        Color color;
    };

    struct CmdDrawLine {
        float x1, y1, x2, y2;
        Color color;
        float lineWidth = 1.0f;
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

    struct CmdUnsetBlendMode {
        bool dummy = false; // Placeholder
    };

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

    struct CmdEndOpenGLMode {
        bool dummy = false; // Placeholder
    };

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
        Rectangle outerRec;
        bool progressOrFullBackground;
        entt::entity cache;
        Color color;
    };

    struct CmdRenderRectVerticesOutlineLayer {
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
    
    struct CmdBeginStencilMode {
        bool dummy = false; // Placeholder
    };
    
    struct CmdColorMask {
        bool red;
        bool green;
        bool blue;
        bool alpha;
    };
    
    struct CmdStencilFunc {
        int func;
        int ref;
        unsigned int mask;
    };
    
    struct CmdStencilOp {
        int sfail;
        int dpfail;
        int dppass;
    };
    
    struct CmdRenderBatchFlush {
        bool dummy = false; // Placeholder
    };
    
    struct CmdAtomicStencilMask {
        unsigned int mask;
    };
    
    struct CmdEndStencilMode {
        bool dummy = false; // Placeholder
    };
    
    struct CmdClearStencilBuffer {
        bool dummy = false; // Placeholder
    };
    
    struct CmdBeginStencilMask {
        bool dummy = false; // Placeholder
    };
    
    struct CmdEndStencilMask {
        bool dummy = false; // Placeholder
    };
    
    struct CmdDrawCenteredEllipse {
        float x, y, rx, ry;
        Color color = WHITE;
        std::optional<float> lineWidth = std::nullopt; // If set, draw outline with this width; else filled
    };
    
    struct CmdDrawRoundedLine {
        float x1, y1, x2, y2;
        Color color = WHITE;
        float lineWidth = 1.0f;
    };
    
    struct CmdDrawPolyline {
        std::vector<Vector2> points;
        Color color = WHITE;
        float lineWidth = 1.0f;
    };
    
    struct CmdDrawArc {
        std::string type;
        float x, y, r, r1, r2;
        Color color = WHITE;
        float lineWidth = 1.0f;
        int segments = 0;
    };
    
    struct CmdDrawTriangleEquilateral {
        float x, y, w;
        Color color = WHITE;
        std::optional<float> lineWidth = std::nullopt; // If set, draw outline with this width; else filled
    };
    
    struct CmdDrawCenteredFilledRoundedRect {
        float x, y, w, h;
        std::optional<float> rx = {};
        std::optional<float> ry = {};
        Color color = WHITE;
        std::optional<float> lineWidth = {};
    };
    
    struct CmdDrawSpriteCentered {
        std::string spriteName;
        float x, y;
        std::optional<float> dstW = std::nullopt;
        std::optional<float> dstH = std::nullopt;
        Color tint = WHITE;
    };
     
    struct CmdDrawSpriteTopLeft {
        std::string spriteName;
        float x, y;
        std::optional<float> dstW = std::nullopt;
        std::optional<float> dstH = std::nullopt;
        Color tint = WHITE;
    };
    
    struct CmdDrawDashedCircle {
        Vector2 center;
        float radius;
        float dashLength;
        float gapLength;
        float phase;
        int segments;
        float thickness;
        Color color;
    };
    
    struct CmdDrawDashedRoundedRect {
        Rectangle rec;
        float dashLen;
        float gapLen;
        float phase;
        float radius;
        int arcSteps;
        float thickness;
        Color color;
    };
    
    struct CmdDrawDashedLine {
        Vector2 start;
        Vector2 end;
        float dashLength;
        float gapLength;
        float phase;
        float thickness;
        Color color;
    };
    
    struct CmdDrawGradientRectCentered {
        float cx, cy;
        float width, height;
        Color topLeft, topRight, bottomRight, bottomLeft;
    };
    
    struct CmdDrawGradientRectRoundedCentered {
        float cx, cy;
        float width, height;
        float roundness;
        int segments;
        Color topLeft, topRight, bottomRight, bottomLeft;
    };

    struct CmdDrawBatchedEntities {
        entt::registry* registry;
        std::vector<entt::entity> entities;
        bool autoOptimize = true;
    };

    struct CmdDrawRenderGroup {
        entt::registry* registry;
        std::string groupName;
        bool autoOptimize = true;
    };




    // ===========================
    // Dispatcher System
    // ===========================
    using RenderFunc = std::function<void(std::shared_ptr<layer::Layer>, void*)>;
    extern std::unordered_map<DrawCommandType, RenderFunc> dispatcher;

    template<typename T>
    inline void RegisterRenderer(DrawCommandType type, void(*func)(std::shared_ptr<layer::Layer>, T*)) {
        dispatcher[type] = [func](std::shared_ptr<layer::Layer> layer, void* data) {
            func(layer, static_cast<T*>(data));
        };
    }
    
    




    // ===========================
    // Render Function Definitions
    // ===========================
    extern void RenderDrawCircle(std::shared_ptr<layer::Layer> layer, CmdDrawCircleFilled* c);
    extern void RenderDrawCircleLine(std::shared_ptr<layer::Layer> layer, CmdDrawCircleLine* c);
    extern void ExecuteTranslate(std::shared_ptr<layer::Layer> layer, CmdTranslate* c);
    extern void ExecuteScale(std::shared_ptr<layer::Layer> layer, CmdScale* c);
    extern void ExecuteRotate(std::shared_ptr<layer::Layer> layer, CmdRotate* c);
    extern void ExecuteAddPush(std::shared_ptr<layer::Layer> layer, CmdAddPush* c);
    extern void ExecuteAddPop(std::shared_ptr<layer::Layer> layer, CmdAddPop* c);
    extern void ExecutePushMatrix(std::shared_ptr<layer::Layer> layer, CmdPushMatrix* c);
    extern void ExecutePopMatrix(std::shared_ptr<layer::Layer> layer, CmdPopMatrix* c);
    extern void ExecutePushObjectTransformsToMatrix(std::shared_ptr<layer::Layer> layer, CmdPushObjectTransformsToMatrix* c);
    extern void ExecuteCircle(std::shared_ptr<layer::Layer> layer, CmdDrawCircleFilled* c);
    extern void ExecuteCircleLine(std::shared_ptr<layer::Layer> layer, CmdDrawCircleLine* c);
    extern void ExecuteRectangle(std::shared_ptr<layer::Layer> layer, CmdDrawRectangle* c);
    extern void ExecuteRectanglePro(std::shared_ptr<layer::Layer> layer, CmdDrawRectanglePro* c);
    extern void ExecuteRectangleLinesPro(std::shared_ptr<layer::Layer> layer, CmdDrawRectangleLinesPro* c);
    extern void ExecuteLine(std::shared_ptr<layer::Layer> layer, CmdDrawLine* c);
    extern void ExecuteDashedLine(std::shared_ptr<layer::Layer> layer, CmdDrawDashedLine* c);
    extern void ExecuteText(std::shared_ptr<layer::Layer> layer, CmdDrawText* c);
    extern void ExecuteTextCentered(std::shared_ptr<layer::Layer> layer, CmdDrawTextCentered* c);
    extern void ExecuteTextPro(std::shared_ptr<layer::Layer> layer, CmdTextPro* c);
    extern void ExecuteDrawImage(std::shared_ptr<layer::Layer> layer, CmdDrawImage* c);
    extern void ExecuteTexturePro(std::shared_ptr<layer::Layer> layer, CmdTexturePro* c);
    extern void ExecuteDrawEntityAnimation(std::shared_ptr<layer::Layer> layer, CmdDrawEntityAnimation* c);
    extern void ExecuteDrawTransformEntityAnimation(std::shared_ptr<layer::Layer> layer, CmdDrawTransformEntityAnimation* c);
    extern void ExecuteDrawTransformEntityAnimationPipeline(std::shared_ptr<layer::Layer> layer, CmdDrawTransformEntityAnimationPipeline* c);
    extern void ExecuteSetShader(std::shared_ptr<layer::Layer> layer, CmdSetShader* c);
    extern void ExecuteResetShader(std::shared_ptr<layer::Layer> layer, CmdResetShader* c);
    extern void ExecuteSetBlendMode(std::shared_ptr<layer::Layer> layer, CmdSetBlendMode* c);
    extern void ExecuteUnsetBlendMode(std::shared_ptr<layer::Layer> layer, CmdUnsetBlendMode* c);
    extern void ExecuteScopedTransformCompositeRender(std::shared_ptr<layer::Layer> layer, CmdScopedTransformCompositeRender* c);
    extern void ExecuteScopedTransformCompositeRenderWithPipeline(std::shared_ptr<layer::Layer> layer, CmdScopedTransformCompositeRenderWithPipeline* c);
    extern void ExecuteSendUniformFloat(std::shared_ptr<layer::Layer> layer, CmdSendUniformFloat* c);
    extern void ExecuteSendUniformInt(std::shared_ptr<layer::Layer> layer, CmdSendUniformInt* c);
    extern void ExecuteSendUniformVec2(std::shared_ptr<layer::Layer> layer, CmdSendUniformVec2* c);
    extern void ExecuteSendUniformVec3(std::shared_ptr<layer::Layer> layer, CmdSendUniformVec3* c);
    extern void ExecuteSendUniformVec4(std::shared_ptr<layer::Layer> layer, CmdSendUniformVec4* c);
    extern void ExecuteSendUniformFloatArray(std::shared_ptr<layer::Layer> layer, CmdSendUniformFloatArray* c);
    extern void ExecuteSendUniformIntArray(std::shared_ptr<layer::Layer> layer, CmdSendUniformIntArray* c);
    extern void ExecuteVertex(std::shared_ptr<layer::Layer> layer, CmdVertex* c);
    extern void ExecuteBeginOpenGLMode(std::shared_ptr<layer::Layer> layer, CmdBeginOpenGLMode* c);
    extern void ExecuteEndOpenGLMode(std::shared_ptr<layer::Layer> layer, CmdEndOpenGLMode* c);
    extern void ExecuteSetColor(std::shared_ptr<layer::Layer> layer, CmdSetColor* c);
    extern void ExecuteSetLineWidth(std::shared_ptr<layer::Layer> layer, CmdSetLineWidth* c);
    extern void ExecuteSetTexture(std::shared_ptr<layer::Layer> layer, CmdSetTexture* c);
    extern void ExecuteRenderRectVerticesFilledLayer(std::shared_ptr<layer::Layer> layer, CmdRenderRectVerticesFilledLayer* c);
    extern void ExecuteRenderRectVerticesOutlineLayer(std::shared_ptr<layer::Layer> layer, CmdRenderRectVerticesOutlineLayer* c);
    extern void ExecutePolygon(std::shared_ptr<layer::Layer> layer, CmdDrawPolygon* c);
    extern void ExecuteRenderNPatchRect(std::shared_ptr<layer::Layer> layer, CmdRenderNPatchRect* c);
    extern void ExecuteTriangle(std::shared_ptr<layer::Layer> layer, CmdDrawTriangle* c);
    
    extern void ExecuteClearStencilBuffer(std::shared_ptr<layer::Layer> layer, CmdClearStencilBuffer* c);
    extern void ExecuteBeginStencilMode(std::shared_ptr<layer::Layer> layer, CmdBeginStencilMode* c);
    extern void ExecuteStencilOp(std::shared_ptr<layer::Layer> layer, CmdStencilOp* c);
    extern void ExecuteRenderBatchFlush(std::shared_ptr<layer::Layer> layer, CmdRenderBatchFlush* c);
    extern void ExecuteAtomicStencilMask(std::shared_ptr<layer::Layer> layer, CmdAtomicStencilMask* c);
    extern void ExecuteColorMask(std::shared_ptr<layer::Layer> layer, CmdColorMask* c);
    extern void ExecuteStencilFunc(std::shared_ptr<layer::Layer> layer, CmdStencilFunc* c);
    extern void ExecuteEndStencilMode(std::shared_ptr<layer::Layer> layer, CmdEndStencilMode* c);
    extern void ExecuteBeginStencilMask(std::shared_ptr<layer::Layer> layer, CmdBeginStencilMask* c);
    extern void ExecuteEndStencilMask(std::shared_ptr<layer::Layer> layer, CmdEndStencilMask* c);
    extern void ExecuteDrawCenteredEllipse(std::shared_ptr<layer::Layer> layer, CmdDrawCenteredEllipse* c);
    extern void ExecuteDrawRoundedLine(std::shared_ptr<layer::Layer> layer, CmdDrawRoundedLine* c);
    extern void ExecuteDrawPolyline(std::shared_ptr<layer::Layer> layer, CmdDrawPolyline* c);
    extern void ExecuteDrawArc(std::shared_ptr<layer::Layer> layer, CmdDrawArc* c);
    extern void ExecuteDrawTriangleEquilateral(std::shared_ptr<layer::Layer> layer, CmdDrawTriangleEquilateral* c);
    extern void ExecuteDrawCenteredFilledRoundedRect(std::shared_ptr<layer::Layer> layer, CmdDrawCenteredFilledRoundedRect* c);
    extern void ExecuteDrawSpriteCentered(std::shared_ptr<layer::Layer> layer, CmdDrawSpriteCentered* c);
    extern void ExecuteDrawSpriteTopLeft(std::shared_ptr<layer::Layer> layer, CmdDrawSpriteTopLeft* c);
    extern void ExecuteDrawDashedCircle(std::shared_ptr<layer::Layer> layer, CmdDrawDashedCircle* c);
    extern void ExecuteDrawDashedRoundedRect(std::shared_ptr<layer::Layer> layer, CmdDrawDashedRoundedRect* c);
    extern void ExecuteDrawDashedLine(std::shared_ptr<layer::Layer> layer, CmdDrawDashedLine* c);
    extern void ExecuteDrawGradientRectCentered(std::shared_ptr<layer::Layer> layer, CmdDrawGradientRectCentered* c) ;
    extern void ExecuteDrawGradientRectRoundedCentered(std::shared_ptr<layer::Layer> layer, CmdDrawGradientRectRoundedCentered* c) ;
    extern void ExecuteDrawBatchedEntities(std::shared_ptr<layer::Layer> layer, CmdDrawBatchedEntities* c);
    extern void ExecuteDrawRenderGroup(std::shared_ptr<layer::Layer> layer, CmdDrawRenderGroup* c);


    // ===========================
    // Init Dispatch Table Once
    // ===========================
    extern void InitDispatcher();

    // ===========================
    // Draw Call Stats Helper
    // ===========================
    // Helper function to categorize draw commands and update statistics
    inline void IncrementDrawCallStats(DrawCommandType type) {
        g_drawCallsThisFrame++;

        switch (type) {
            // Sprite/Animation commands
            case DrawCommandType::DrawEntityAnimation:
            case DrawCommandType::DrawTransformEntityAnimation:
            case DrawCommandType::DrawTransformEntityAnimationPipeline:
            case DrawCommandType::DrawImage:
            case DrawCommandType::TexturePro:
            case DrawCommandType::DrawSpriteCentered:
            case DrawCommandType::DrawSpriteTopLeft:
            case DrawCommandType::DrawBatchedEntities:
                g_drawCallStats.sprites++;
                break;

            // Text commands
            case DrawCommandType::Text:
            case DrawCommandType::DrawTextCentered:
            case DrawCommandType::TextPro:
                g_drawCallStats.text++;
                break;

            // Shape primitives
            case DrawCommandType::Circle:
            case DrawCommandType::CircleLine:
            case DrawCommandType::Rectangle:
            case DrawCommandType::RectanglePro:
            case DrawCommandType::RectangleLinesPro:
            case DrawCommandType::Line:
            case DrawCommandType::DashedLine:
            case DrawCommandType::Polygon:
            case DrawCommandType::Triangle:
            case DrawCommandType::DrawCenteredEllipse:
            case DrawCommandType::DrawRoundedLine:
            case DrawCommandType::DrawPolyline:
            case DrawCommandType::DrawArc:
            case DrawCommandType::DrawTriangleEquilateral:
            case DrawCommandType::DrawCenteredFilledRoundedRect:
            case DrawCommandType::DrawDashedCircle:
            case DrawCommandType::DrawDashedRoundedRect:
            case DrawCommandType::DrawGradientRectCentered:
            case DrawCommandType::DrawGradientRectRoundedCentered:
            case DrawCommandType::RenderNPatchRect:
            case DrawCommandType::RenderRectVerticesFilledLayer:
            case DrawCommandType::RenderRectVerticlesOutlineLayer:
                g_drawCallStats.shapes++;
                break;

            // UI commands
            case DrawCommandType::RenderUISliceFromDrawList:
            case DrawCommandType::RenderUISelfImmediate:
                g_drawCallStats.ui++;
                break;

            // State changes (don't actually render anything)
            case DrawCommandType::SetShader:
            case DrawCommandType::ResetShader:
            case DrawCommandType::SetBlendMode:
            case DrawCommandType::UnsetBlendMode:
            case DrawCommandType::Translate:
            case DrawCommandType::Scale:
            case DrawCommandType::Rotate:
            case DrawCommandType::PushMatrix:
            case DrawCommandType::PopMatrix:
            case DrawCommandType::AddPush:
            case DrawCommandType::AddPop:
            case DrawCommandType::PushObjectTransformsToMatrix:
            case DrawCommandType::ScopedTransformCompositeRender:
            case DrawCommandType::SendUniformFloat:
            case DrawCommandType::SendUniformInt:
            case DrawCommandType::SendUniformVec2:
            case DrawCommandType::SendUniformVec3:
            case DrawCommandType::SendUniformVec4:
            case DrawCommandType::SendUniformFloatArray:
            case DrawCommandType::SendUniformIntArray:
            case DrawCommandType::BeginStencilMode:
            case DrawCommandType::EndStencilMode:
            case DrawCommandType::BeginStencilMask:
            case DrawCommandType::EndStencilMask:
            case DrawCommandType::StencilFunc:
            case DrawCommandType::StencilOp:
            case DrawCommandType::ColorMask:
            case DrawCommandType::AtomicStencilMask:
            case DrawCommandType::ClearStencilBuffer:
            case DrawCommandType::RenderBatchFlush:
            case DrawCommandType::BeginScissorMode:
            case DrawCommandType::EndScissorMode:
            case DrawCommandType::SetColor:
            case DrawCommandType::SetLineWidth:
            case DrawCommandType::SetTexture:
                g_drawCallStats.state++;
                break;

            // OpenGL/Vertex commands and other misc
            case DrawCommandType::BeginOpenGLMode:
            case DrawCommandType::EndOpenGLMode:
            case DrawCommandType::Vertex:
            case DrawCommandType::BeginDrawing:
            case DrawCommandType::EndDrawing:
            case DrawCommandType::ClearBackground:
            default:
                g_drawCallStats.other++;
                break;
        }
    }

}
   