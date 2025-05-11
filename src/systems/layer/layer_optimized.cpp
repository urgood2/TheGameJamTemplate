#include "layer_optimized.hpp"

#include "layer.hpp"

namespace layer
{
    std::unordered_map<DrawCommandType, RenderFunc> dispatcher{};
    
    // -------------------------------------------------------------------------------------
    // Command Execution Functions
    // -------------------------------------------------------------------------------------
    
    void RenderDrawCircle(CmdDrawCircle* c) {
        DrawCircleV({c->x, c->y}, c->radius, c->color);
    }
    
    void ExecuteTranslate(CmdTranslate* c) {
        Translate(c->x, c->y);
    }
    void ExecuteScale(CmdScale* c) {
        Scale(c->scaleX, c->scaleY);
    }
    
    void ExecuteRotate(CmdRotate* c) {
        Rotate(c->angle);
    }
    
    void ExecuteAddPush(CmdAddPush* c) {
        Push(c->camera);
    }
    
    void ExecuteAddPop(CmdAddPop* c) {
        Pop();
    }
    
    void ExecutePushMatrix(CmdPushMatrix* c) {
        PushMatrix();
    }
    
    void ExecutePopMatrix(CmdPopMatrix* c) {
        PopMatrix();
    }
    
    void ExecuteCircle(CmdDrawCircle* c) {
        Circle(c->x, c->y, c->radius, c->color);
    }
    
    void ExecuteRectangle(CmdDrawRectangle* c) {
        RectangleDraw(c->x, c->y, c->width, c->height, c->color, c->lineWidth);
    }
    
    void ExecuteRectanglePro(CmdDrawRectanglePro* c) {
        RectanglePro(c->offsetX, c->offsetY, c->size, c->rotationCenter, c->rotation, c->color);
    }
    
    void ExecuteRectangleLinesPro(CmdDrawRectangleLinesPro* c) {
        RectangleLinesPro(c->offsetX, c->offsetY, c->size, c->lineThickness, c->color);
    }
    
    void ExecuteLine(CmdDrawLine* c) {
        Line(c->x1, c->y1, c->x2, c->y2, c->color, c->lineWidth);
    }
    
    void ExecuteDashedLine(CmdDrawDashedLine* c) {
        DashedLine(c->x1, c->y1, c->x2, c->y2, c->dashSize, c->gapSize, c->color, c->lineWidth);
    }
    
    void ExecuteText(CmdDrawText* c) {
        Text(c->text, c->font, c->x, c->y, c->color, c->fontSize);
    }
    
    void ExecuteTextCentered(CmdDrawTextCentered* c) {
        Text(c->text, c->font, c->x, c->y, c->color, c->fontSize);
    }
    
    void ExecuteTextPro(CmdTextPro* c) {
        TextPro(c->text, c->font, c->x, c->y, c->origin, c->rotation, c->fontSize, c->spacing, c->color);
    }
    
    void ExecuteDrawImage(CmdDrawImage* c) {
        DrawImage(c->image, c->x, c->y, c->rotation, c->scaleX, c->scaleY, c->color);
    }
    
    void ExecuteTexturePro(CmdTexturePro* c) {
        TexturePro(c->texture, c->source, c->offsetX, c->offsetY, c->size, c->rotationCenter, c->rotation, c->color);
    }
    
    void ExecuteDrawEntityAnimation(CmdDrawEntityAnimation* c) {
        DrawEntityWithAnimation(*c->registry, c->e, c->x, c->y);
    }
    
    void ExecuteDrawTransformEntityAnimation(CmdDrawTransformEntityAnimation* c) {
        DrawTransformEntityWithAnimation(*c->registry, c->e);
    }
    
    void ExecuteDrawTransformEntityAnimationPipeline(CmdDrawTransformEntityAnimationPipeline* c) {
        DrawTransformEntityWithAnimationWithPipeline(*c->registry, c->e);
    }
    
    void ExecuteSetShader(CmdSetShader* c) {
        SetShader(c->shader);
    }
    
    void ExecuteResetShader(CmdResetShader* c) {
        ResetShader();
    }
    
    void ExecuteSetBlendMode(CmdSetBlendMode* c) {
        SetBlendMode(c->blendMode);
    }
    
    void ExecuteUnsetBlendMode(CmdUnsetBlendMode* c) {
        UnsetBlendMode();
    }
    
    void ExecuteSendUniformFloat(CmdSendUniformFloat* c) {
        SendUniformFloat(c->shader, c->uniform, c->value);
    }
    
    void ExecuteSendUniformInt(CmdSendUniformInt* c) {
        SendUniformInt(c->shader, c->uniform, c->value);
    }
    
    void ExecuteSendUniformVec2(CmdSendUniformVec2* c) {
        SendUniformVector2(c->shader, c->uniform, c->value);
    }
    
    void ExecuteSendUniformVec3(CmdSendUniformVec3* c) {
        SendUniformVector3(c->shader, c->uniform, c->value);
    }
    
    void ExecuteSendUniformVec4(CmdSendUniformVec4* c) {
        SendUniformVector4(c->shader, c->uniform, c->value);
    }
    
    void ExecuteSendUniformFloatArray(CmdSendUniformFloatArray* c) {
        SendUniformFloatArray(c->shader, c->uniform, c->values.data(), c->values.size());
    }
    
    void ExecuteSendUniformIntArray(CmdSendUniformIntArray* c) {
        SendUniformIntArray(c->shader, c->uniform, c->values.data(), c->values.size());
    }
    
    void ExecuteVertex(CmdVertex* c) {
        Vertex(c->v, c->color);
    }
    
    void ExecuteBeginOpenGLMode(CmdBeginOpenGLMode* c) {
        BeginRLMode(c->mode);
    }
    
    void ExecuteEndOpenGLMode(CmdEndOpenGLMode* c) {
        EndRLMode();
    }
    
    void ExecuteSetColor(CmdSetColor* c) {
        SetColor(c->color);
    }
    
    void ExecuteSetLineWidth(CmdSetLineWidth* c) {
        SetLineWidth(c->lineWidth);
    }
    
    void ExecuteSetTexture(CmdSetTexture* c) {
        SetRLTexture(c->texture);
    }
    
    
    void ExecuteRenderRectVerticesFilledLayer(CmdRenderRectVerticesFilledLayer* c) {
        RenderRectVerticesFilledLayer(c->layerPtr, c->outerRec, c->progressOrFullBackground, c->cache, c->color);
    }
    
    void ExecuteRenderRectVerticesOutlineLayer(CmdRenderRectVerticesOutlineLayer* c) {
        RenderRectVerticlesOutlineLayer(c->layerPtr, c->cache, c->color, c->useFullVertices);
    }
    
    void ExecutePolygon(CmdDrawPolygon* c) {
        Polygon(c->vertices, c->color, c->lineWidth);
    }
    
    void ExecuteRenderNPatchRect(CmdRenderNPatchRect* c) {
        RenderNPatchRect(c->sourceTexture, c->info, c->dest, c->origin, c->rotation, c->tint);
    }
    
    void ExecuteTriangle(CmdDrawTriangle* c) {
        Triangle(c->p1, c->p2, c->p3, c->color);
    }
    
    // -------------------------------------------------------------------------------------
    // Command Registration Functions
    // -------------------------------------------------------------------------------------
    
    void InitDispatcher() {
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