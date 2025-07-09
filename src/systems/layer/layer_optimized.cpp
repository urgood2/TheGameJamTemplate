#include "layer_optimized.hpp"

#include "layer.hpp"
#include "core/globals.hpp"
#include "systems/ui/element.hpp"

namespace layer
{
    std::unordered_map<DrawCommandType, RenderFunc> dispatcher{};
    
    // -------------------------------------------------------------------------------------
    // Command Execution Functions
    // -------------------------------------------------------------------------------------
    
    void RenderDrawCircle(std::shared_ptr<layer::Layer> layer, CmdDrawCircleFilled* c) {
        DrawCircleV({c->x, c->y}, c->radius, c->color);
    }
    
    void RenderDrawCircleLine(std::shared_ptr<layer::Layer> layer, CmdDrawCircleLine* c) {
        DrawRing({c->x, c->y}, c->innerRadius, c->outerRadius, c->startAngle, c->endAngle, c->segments, c->color);
    }
    
    void ExecuteTranslate(std::shared_ptr<layer::Layer> layer, CmdTranslate* c) {
        Translate(c->x, c->y);
    }
    void ExecuteScale(std::shared_ptr<layer::Layer> layer, CmdScale* c) {
        Scale(c->scaleX, c->scaleY);
    }
    
    void ExecuteRotate(std::shared_ptr<layer::Layer> layer, CmdRotate* c) {
        Rotate(c->angle);
    }
    
    void ExecuteAddPush(std::shared_ptr<layer::Layer> layer, CmdAddPush* c) {
        Push(c->camera);
    }
    
    void ExecuteAddPop(std::shared_ptr<layer::Layer> layer, CmdAddPop* c) {
        Pop();
    }
    
    void ExecutePushMatrix(std::shared_ptr<layer::Layer> layer, CmdPushMatrix* c) {
        PushMatrix();
    }
    
    void ExecutePopMatrix(std::shared_ptr<layer::Layer> layer, CmdPopMatrix* c) {
        PopMatrix();
    }
    
    void ExecuteCircle(std::shared_ptr<layer::Layer> layer, CmdDrawCircleFilled* c) {
        Circle(c->x, c->y, c->radius, c->color);
    }
    
    void ExecuteCircleLine(std::shared_ptr<layer::Layer> layer, CmdDrawCircleLine* c) {
        CircleLine(c->x, c->y, c->innerRadius, c->outerRadius, c->startAngle, c->endAngle, c->segments, c->color);
    }
    
    void ExecuteRectangle(std::shared_ptr<layer::Layer> layer, CmdDrawRectangle* c) {
        RectangleDraw(c->x, c->y, c->width, c->height, c->color, c->lineWidth);
    }
    
    void ExecuteRectanglePro(std::shared_ptr<layer::Layer> layer, CmdDrawRectanglePro* c) {
        RectanglePro(c->offsetX, c->offsetY, c->size, c->rotationCenter, c->rotation, c->color);
    }
    
    void ExecuteRectangleLinesPro(std::shared_ptr<layer::Layer> layer, CmdDrawRectangleLinesPro* c) {
        RectangleLinesPro(c->offsetX, c->offsetY, c->size, c->lineThickness, c->color);
    }
    
    void ExecuteLine(std::shared_ptr<layer::Layer> layer, CmdDrawLine* c) {
        Line(c->x1, c->y1, c->x2, c->y2, c->color, c->lineWidth);
    }
    
    void ExecuteDashedLine(std::shared_ptr<layer::Layer> layer, CmdDrawDashedLine* c) {
        DashedLine(c->x1, c->y1, c->x2, c->y2, c->dashSize, c->gapSize, c->color, c->lineWidth);
    }
    
    void ExecuteText(std::shared_ptr<layer::Layer> layer, CmdDrawText* c) {
        Text(c->text, c->font, c->x, c->y, c->color, c->fontSize);
    }
    
    void ExecuteTextCentered(std::shared_ptr<layer::Layer> layer, CmdDrawTextCentered* c) {
        Text(c->text, c->font, c->x, c->y, c->color, c->fontSize);
    }
    
    void ExecuteTextPro(std::shared_ptr<layer::Layer> layer, CmdTextPro* c) {
        TextPro(c->text, c->font, c->x, c->y, c->origin, c->rotation, c->fontSize, c->spacing, c->color);
    }
    
    void ExecuteDrawImage(std::shared_ptr<layer::Layer> layer, CmdDrawImage* c) {
        DrawImage(c->image, c->x, c->y, c->rotation, c->scaleX, c->scaleY, c->color);
    }
    
    void ExecuteTexturePro(std::shared_ptr<layer::Layer> layer, CmdTexturePro* c) {
        TexturePro(c->texture, c->source, c->offsetX, c->offsetY, c->size, c->rotationCenter, c->rotation, c->color);
    }
    
    void ExecuteDrawEntityAnimation(std::shared_ptr<layer::Layer> layer, CmdDrawEntityAnimation* c) {
        DrawEntityWithAnimation(*c->registry, c->e, c->x, c->y);
    }
    
    void ExecuteDrawTransformEntityAnimation(std::shared_ptr<layer::Layer> layer, CmdDrawTransformEntityAnimation* c) {
        DrawTransformEntityWithAnimation(*c->registry, c->e);
    }
    
    void ExecuteDrawTransformEntityAnimationPipeline(std::shared_ptr<layer::Layer> layer, CmdDrawTransformEntityAnimationPipeline* c) {
        DrawTransformEntityWithAnimationWithPipeline(*c->registry, c->e);
    }
    
    void ExecuteSetShader(std::shared_ptr<layer::Layer> layer, CmdSetShader* c) {
        SetShader(c->shader);
    }
    
    void ExecuteResetShader(std::shared_ptr<layer::Layer> layer, CmdResetShader* c) {
        ResetShader();
    }
    
    void ExecuteSetBlendMode(std::shared_ptr<layer::Layer> layer, CmdSetBlendMode* c) {
        SetBlendMode(c->blendMode);
    }
    
    void ExecuteUnsetBlendMode(std::shared_ptr<layer::Layer> layer, CmdUnsetBlendMode* c) {
        UnsetBlendMode();
    }
    
    void ExecuteSendUniformFloat(std::shared_ptr<layer::Layer> layer, CmdSendUniformFloat* c) {
        SendUniformFloat(c->shader, c->uniform, c->value);
    }
    
    void ExecuteSendUniformInt(std::shared_ptr<layer::Layer> layer, CmdSendUniformInt* c) {
        SendUniformInt(c->shader, c->uniform, c->value);
    }
    
    void ExecuteSendUniformVec2(std::shared_ptr<layer::Layer> layer, CmdSendUniformVec2* c) {
        SendUniformVector2(c->shader, c->uniform, c->value);
    }
    
    void ExecuteSendUniformVec3(std::shared_ptr<layer::Layer> layer, CmdSendUniformVec3* c) {
        SendUniformVector3(c->shader, c->uniform, c->value);
    }
    
    void ExecuteSendUniformVec4(std::shared_ptr<layer::Layer> layer, CmdSendUniformVec4* c) {
        SendUniformVector4(c->shader, c->uniform, c->value);
    }
    
    void ExecuteSendUniformFloatArray(std::shared_ptr<layer::Layer> layer, CmdSendUniformFloatArray* c) {
        SendUniformFloatArray(c->shader, c->uniform, c->values.data(), c->values.size());
    }
    
    void ExecuteSendUniformIntArray(std::shared_ptr<layer::Layer> layer, CmdSendUniformIntArray* c) {
        SendUniformIntArray(c->shader, c->uniform, c->values.data(), c->values.size());
    }
    
    void ExecuteVertex(std::shared_ptr<layer::Layer> layer, CmdVertex* c) {
        Vertex(c->v, c->color);
    }
    
    void ExecuteBeginOpenGLMode(std::shared_ptr<layer::Layer> layer, CmdBeginOpenGLMode* c) {
        BeginRLMode(c->mode);
    }
    
    void ExecuteEndOpenGLMode(std::shared_ptr<layer::Layer> layer, CmdEndOpenGLMode* c) {
        EndRLMode();
    }
    
    void ExecuteSetColor(std::shared_ptr<layer::Layer> layer, CmdSetColor* c) {
        SetColor(c->color);
    }
    
    void ExecuteSetLineWidth(std::shared_ptr<layer::Layer> layer, CmdSetLineWidth* c) {
        SetLineWidth(c->lineWidth);
    }
    
    void ExecuteSetTexture(std::shared_ptr<layer::Layer> layer, CmdSetTexture* c) {
        SetRLTexture(c->texture);
    }
    
    void ExecuteRenderRectVerticesFilledLayer(std::shared_ptr<layer::Layer> layer, CmdRenderRectVerticesFilledLayer* c) {
        RenderRectVerticesFilledLayer(layer, c->outerRec, c->progressOrFullBackground, c->cache, c->color);
    }
    
    void ExecuteRenderRectVerticesOutlineLayer(std::shared_ptr<layer::Layer> layer, CmdRenderRectVerticesOutlineLayer* c) {
        RenderRectVerticlesOutlineLayer(layer, c->cache, c->color, c->useFullVertices);
    }
    
    void ExecutePolygon(std::shared_ptr<layer::Layer> layer, CmdDrawPolygon* c) {
        Polygon(c->vertices, c->color, c->lineWidth);
    }
    
    void ExecuteRenderNPatchRect(std::shared_ptr<layer::Layer> layer, CmdRenderNPatchRect* c) {
        RenderNPatchRect(c->sourceTexture, c->info, c->dest, c->origin, c->rotation, c->tint);
    }
    
    void ExecuteTriangle(std::shared_ptr<layer::Layer> layer, CmdDrawTriangle* c) {
        Triangle(c->p1, c->p2, c->p3, c->color);
    }
    
    // -------------------------------------------------------------------------------------
    // Command Registration Functions
    // -------------------------------------------------------------------------------------
    
    void InitDispatcher() {
        RegisterRenderer<CmdBeginDrawing>(DrawCommandType::BeginDrawing, [](std::shared_ptr<layer::Layer> layer, CmdBeginDrawing*) { 
            BeginDrawingAction(); });
        RegisterRenderer<CmdEndDrawing>(DrawCommandType::EndDrawing, [](std::shared_ptr<layer::Layer> layer, CmdEndDrawing*) { EndDrawingAction(); });
        RegisterRenderer<CmdClearBackground>(DrawCommandType::ClearBackground, [](std::shared_ptr<layer::Layer> layer, CmdClearBackground* c) { 
            ClearBackgroundAction(c->color); 
        });
        RegisterRenderer<CmdRenderUISliceFromDrawList>(DrawCommandType::RenderUISliceFromDrawList, [](std::shared_ptr<layer::Layer> layer, CmdRenderUISliceFromDrawList* c) { 
            renderSliceOffscreenFromDrawList(globals::registry, c->drawList, c->startIndex, c->endIndex, layer, c->pad); 
        });
        RegisterRenderer<CmdRenderUISelfImmediate>(DrawCommandType::RenderUISelfImmediate, [](std::shared_ptr<layer::Layer> layer, CmdRenderUISelfImmediate* c) { 
            auto &uiElementComp = ui::globalUIGroup.get<ui::UIElementComponent>(c->entity);
            auto &configComp = ui::globalUIGroup.get<ui::UIConfig>(c->entity);
            auto &stateComp = ui::globalUIGroup.get<ui::UIState>(c->entity);
            auto &nodeComp = ui::globalUIGroup.get<transform::GameObject>(c->entity);
            auto &transformComp = ui::globalUIGroup.get<transform::Transform>(c->entity);
            ui::element::DrawSelfImmediate(layer, c->entity, uiElementComp, configComp, stateComp, nodeComp, transformComp);
        });
        RegisterRenderer<CmdTranslate>(DrawCommandType::Translate, ExecuteTranslate);
        RegisterRenderer<CmdScale>(DrawCommandType::Scale, ExecuteScale);
        RegisterRenderer<CmdRotate>(DrawCommandType::Rotate, ExecuteRotate);
        RegisterRenderer<CmdAddPush>(DrawCommandType::AddPush, ExecuteAddPush);
        RegisterRenderer<CmdAddPop>(DrawCommandType::AddPop, ExecuteAddPop);
        RegisterRenderer<CmdPushMatrix>(DrawCommandType::PushMatrix, ExecutePushMatrix);
        RegisterRenderer<CmdPopMatrix>(DrawCommandType::PopMatrix, ExecutePopMatrix);
        RegisterRenderer<CmdDrawCircleFilled>(DrawCommandType::Circle, ExecuteCircle);
        RegisterRenderer<CmdDrawCircleLine>(DrawCommandType::CircleLine, ExecuteCircleLine);
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