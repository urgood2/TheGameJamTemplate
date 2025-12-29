#include "layer_optimized.hpp"

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

#include "layer.hpp"
#include "core/globals.hpp"
#include "raylib.h"
#include "systems/ui/element.hpp"

#include "systems/ui/ui_data.hpp"
#include "systems/layer/layer_command_buffer_data.hpp"
#include "systems/shaders/shader_draw_commands.hpp"
#include "systems/render_groups/render_groups.hpp"
#include "systems/layer/layer_order_system.hpp"

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
    
    void ExecutePushObjectTransformsToMatrix(std::shared_ptr<layer::Layer> layer, CmdPushObjectTransformsToMatrix* c) {
        layer::pushEntityTransformsToMatrix(globals::getRegistry(), c->entity, layer);
    }
    
    void ExecuteScopedTransformCompositeRender(std::shared_ptr<layer::Layer> layer, CmdScopedTransformCompositeRender* c) {
        layer::pushEntityTransformsToMatrixImmediate(globals::getRegistry(), c->entity, layer);
        // Execute child commands
        for (auto& cmd : c->children) {
            auto it = dispatcher.find(cmd.type);
            if (it != dispatcher.end()) {
                it->second(layer, cmd.data);
                IncrementDrawCallStats(cmd.type);  // Count child commands
            }
        }
        PopMatrix();
    }

    void ExecuteScopedTransformCompositeRenderWithPipeline(std::shared_ptr<layer::Layer> layer, CmdScopedTransformCompositeRenderWithPipeline* c) {
        if (!c->registry) {
            SPDLOG_WARN("ScopedTransformCompositeRenderWithPipeline: registry is null");
            return;
        }

        // Execute the shader pipeline for this entity's BatchedLocalCommands
        // This processes text/shapes through shader effects (polychrome, holo, etc.)
        shader_draw_commands::DrawCommandBatch batch;
        batch.beginRecording();
        shader_draw_commands::executeEntityPipelineWithCommands(
            *c->registry,
            c->entity,
            batch,
            true  // auto-optimize
        );
        batch.endRecording();
        batch.execute();

        // Also execute any child commands in local space (legacy support)
        if (!c->children.empty()) {
            layer::pushEntityTransformsToMatrixImmediate(*c->registry, c->entity, layer);
            for (auto& cmd : c->children) {
                auto it = dispatcher.find(cmd.type);
                if (it != dispatcher.end()) {
                    it->second(layer, cmd.data);
                    g_drawCallsThisFrame++;
                }
            }
            PopMatrix();
        }
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
        layer::DrawDashedLine(c->start, c->end, c->dashLength, c->gapLength, c->phase, c->thickness, c->color);
    }
    
    void ExecuteDrawGradientRectCentered(std::shared_ptr<layer::Layer> layer, CmdDrawGradientRectCentered* c) {
        layer::DrawGradientRectCentered(
            c->cx, c->cy,
            c->width, c->height,
            c->topLeft, c->topRight,
            c->bottomRight, c->bottomLeft
        );
    }
    
    void ExecuteDrawGradientRectRoundedCentered(std::shared_ptr<layer::Layer> layer, CmdDrawGradientRectRoundedCentered* c) {
        layer::DrawGradientRectRoundedCentered(
            c->cx, c->cy,
            c->width, c->height,
            c->roundness,
            c->segments,
            c->topLeft, c->topRight,
            c->bottomRight, c->bottomLeft
        );
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
    
    
    void ExecuteClearStencilBuffer(std::shared_ptr<layer::Layer> layer, CmdClearStencilBuffer* c) {
        clearStencilBuffer();
    }
    void ExecuteBeginStencilMode(std::shared_ptr<layer::Layer> layer, CmdBeginStencilMode* c) {
        beginStencil();
    }
    void ExecuteStencilOp(std::shared_ptr<layer::Layer> layer, CmdStencilOp* c) {
        glStencilOp(c->sfail, c->dpfail, c->dppass);
    }
    void ExecuteRenderBatchFlush(std::shared_ptr<layer::Layer> layer, CmdRenderBatchFlush* c) {
        rlDrawRenderBatchActive();
    }
    void ExecuteAtomicStencilMask(std::shared_ptr<layer::Layer> layer, CmdAtomicStencilMask* c) {
        glStencilMask(c->mask);
    }
    void ExecuteColorMask(std::shared_ptr<layer::Layer> layer, CmdColorMask* c) {
        glColorMask(c->red, c->green, c->blue, c->alpha);
    }
    void ExecuteStencilFunc(std::shared_ptr<layer::Layer> layer, CmdStencilFunc* c) {
        glStencilFunc(c->func, c->ref, c->mask);
    }
    void ExecuteEndStencilMode(std::shared_ptr<layer::Layer> layer, CmdEndStencilMode* c) {
        endStencil();
    }
    void ExecuteBeginStencilMask(std::shared_ptr<layer::Layer> layer, CmdBeginStencilMask* c) {
        beginStencilMask();
    }
    void ExecuteEndStencilMask(std::shared_ptr<layer::Layer> layer, CmdEndStencilMask* c) {
        endStencilMask();
    }
    void ExecuteDrawCenteredEllipse(std::shared_ptr<layer::Layer> layer, CmdDrawCenteredEllipse* c) {
        ellipse(c->x, c->y, c->rx, c->ry, c->color, c->lineWidth);
    }
    void ExecuteDrawRoundedLine(std::shared_ptr<layer::Layer> layer, CmdDrawRoundedLine* c) {
        rounded_line(c->x1, c->y1, c->x2, c->y2, c->color, c->lineWidth);
    }
    void ExecuteDrawPolyline(std::shared_ptr<layer::Layer> layer, CmdDrawPolyline* c) {
        polyline(c->points, c->color, c->lineWidth);
    }
    void ExecuteDrawArc(std::shared_ptr<layer::Layer> layer, CmdDrawArc* c) {
        arc(c->type.c_str(), c->x, c->y, c->r, c->r1, c->r2, c->color, c->lineWidth, c->segments);
    }
    void ExecuteDrawTriangleEquilateral(std::shared_ptr<layer::Layer> layer, CmdDrawTriangleEquilateral* c) {
        triangle_equilateral(c->x, c->y, c->w, c->color, c->lineWidth);
    }
    void ExecuteDrawCenteredFilledRoundedRect(std::shared_ptr<layer::Layer> layer, CmdDrawCenteredFilledRoundedRect* c) {
        rectangle(c->x, c->y, c->w, c->h, c->rx, c->ry, c->color, c->lineWidth);
    }
    
    void ExecuteDrawSteppedRoundedRect(std::shared_ptr<layer::Layer> layer, CmdDrawSteppedRoundedRect* c) {
        float width = c->w;
        float height = c->h;
        float x = c->x - width * 0.5f;
        float y = c->y - height * 0.5f;
        float borderWidth = c->borderWidth;
        int numSteps = c->numSteps;
        
        float cornerSize = std::max(std::max(width, height) / 60.0f, 12.0f);
        float outerRadius = cornerSize;
        float innerRadius = std::max(outerRadius - borderWidth, 0.0f);
        
        Rectangle outerRec = {x, y, width, height};
        Rectangle innerRec = {x + borderWidth, y + borderWidth, 
                              width - 2 * borderWidth, height - 2 * borderWidth};
        
        const Vector2 outerCenters[4] = {
            {outerRec.x + outerRadius, outerRec.y + outerRadius},
            {outerRec.x + outerRec.width - outerRadius, outerRec.y + outerRadius},
            {outerRec.x + outerRec.width - outerRadius, outerRec.y + outerRec.height - outerRadius},
            {outerRec.x + outerRadius, outerRec.y + outerRec.height - outerRadius}
        };
        
        const Vector2 innerCenters[4] = {
            {innerRec.x + innerRadius, innerRec.y + innerRadius},
            {innerRec.x + innerRec.width - innerRadius, innerRec.y + innerRadius},
            {innerRec.x + innerRec.width - innerRadius, innerRec.y + innerRec.height - innerRadius},
            {innerRec.x + innerRadius, innerRec.y + innerRec.height - innerRadius}
        };
        
        const float angles[4] = {180.0f, 270.0f, 0.0f, 90.0f};
        float stepLength = 90.0f / static_cast<float>(numSteps);
        
        std::vector<Vector2> outerVertices;
        std::vector<Vector2> innerVertices;
        
        for (int k = 0; k < 4; ++k) {
            float angle = angles[k];
            const Vector2& outerCenter = outerCenters[k];
            const Vector2& innerCenter = innerCenters[k];
            
            for (int i = 0; i < numSteps; i++) {
                Vector2 outerStart = {
                    outerCenter.x + cosf(DEG2RAD * angle) * outerRadius,
                    outerCenter.y + sinf(DEG2RAD * angle) * outerRadius
                };
                Vector2 outerEnd = {
                    outerCenter.x + cosf(DEG2RAD * (angle + stepLength)) * outerRadius,
                    outerCenter.y + sinf(DEG2RAD * (angle + stepLength)) * outerRadius
                };
                Vector2 innerStart = {
                    innerCenter.x + cosf(DEG2RAD * angle) * innerRadius,
                    innerCenter.y + sinf(DEG2RAD * angle) * innerRadius
                };
                Vector2 innerEnd = {
                    innerCenter.x + cosf(DEG2RAD * (angle + stepLength)) * innerRadius,
                    innerCenter.y + sinf(DEG2RAD * (angle + stepLength)) * innerRadius
                };
                
                Vector2 outerStep1, outerStep2, innerStep1, innerStep2;
                if (k == 0 || k == 2) {
                    outerStep1 = {outerEnd.x, outerStart.y};
                    outerStep2 = outerEnd;
                    innerStep1 = {innerEnd.x, innerStart.y};
                    innerStep2 = innerEnd;
                } else {
                    outerStep1 = {outerStart.x, outerEnd.y};
                    outerStep2 = outerEnd;
                    innerStep1 = {innerStart.x, innerEnd.y};
                    innerStep2 = innerEnd;
                }
                
                outerVertices.push_back(outerStart);
                outerVertices.push_back(outerStep1);
                outerVertices.push_back(outerStep1);
                outerVertices.push_back(outerStep2);
                
                innerVertices.push_back(innerStart);
                innerVertices.push_back(innerStep1);
                innerVertices.push_back(innerStep1);
                innerVertices.push_back(innerStep2);
                
                angle += stepLength;
            }
        }
        
        Vector2 outerEdges[8] = {
            {outerRec.x + outerRadius, outerRec.y}, 
            {outerRec.x + outerRec.width - outerRadius, outerRec.y},
            {outerRec.x + outerRec.width, outerRec.y + outerRadius},
            {outerRec.x + outerRec.width, outerRec.y + outerRec.height - outerRadius},
            {outerRec.x + outerRec.width - outerRadius, outerRec.y + outerRec.height},
            {outerRec.x + outerRadius, outerRec.y + outerRec.height},
            {outerRec.x, outerRec.y + outerRec.height - outerRadius},
            {outerRec.x, outerRec.y + outerRadius}
        };
        
        Vector2 innerEdges[8] = {
            {innerRec.x + innerRadius, innerRec.y}, 
            {innerRec.x + innerRec.width - innerRadius, innerRec.y},
            {innerRec.x + innerRec.width, innerRec.y + innerRadius},
            {innerRec.x + innerRec.width, innerRec.y + innerRec.height - innerRadius},
            {innerRec.x + innerRec.width - innerRadius, innerRec.y + innerRec.height},
            {innerRec.x + innerRadius, innerRec.y + innerRec.height},
            {innerRec.x, innerRec.y + innerRec.height - innerRadius},
            {innerRec.x, innerRec.y + innerRadius}
        };
        
        for (int i = 0; i < 8; i += 2) {
            outerVertices.push_back(outerEdges[i]);
            outerVertices.push_back(outerEdges[i + 1]);
            innerVertices.push_back(innerEdges[i]);
            innerVertices.push_back(innerEdges[i + 1]);
        }
        
        if (c->fillColor.a > 0 && innerVertices.size() >= 3) {
            DrawTriangleFan(innerVertices.data(), static_cast<int>(innerVertices.size()), c->fillColor);
        }
        
        if (c->borderColor.a > 0 && outerVertices.size() >= 2) {
            for (size_t i = 0; i < outerVertices.size(); i += 2) {
                if (i + 1 < outerVertices.size()) {
                    DrawLineEx(outerVertices[i], outerVertices[i + 1], borderWidth, c->borderColor);
                }
            }
        }
    }
    
    void ExecuteDrawSpriteCentered(std::shared_ptr<layer::Layer> layer, CmdDrawSpriteCentered* c) {
        DrawSpriteCentered(c->spriteName, c->x, c->y, c->dstW, c->dstH, c->tint);
    }
    void ExecuteDrawSpriteTopLeft(std::shared_ptr<layer::Layer> layer, CmdDrawSpriteTopLeft* c) {
        DrawSpriteTopLeft(c->spriteName, c->x, c->y, c->dstW, c->dstH, c->tint);
    }
    void ExecuteDrawDashedCircle(std::shared_ptr<layer::Layer> layer, CmdDrawDashedCircle* c) {
        DrawDashedCircle({c->center.x, c->center.y}, c->radius, c->dashLength, c->gapLength, c->phase, c->segments, c->thickness, c->color);
    }
    void ExecuteDrawDashedRoundedRect(std::shared_ptr<layer::Layer> layer, CmdDrawDashedRoundedRect* c) {
        DrawDashedRoundedRect(c->rec, c->dashLen, c->gapLen, c->phase, c->radius, c->arcSteps, c->thickness, c->color);
    }
    void ExecuteDrawDashedLine(std::shared_ptr<layer::Layer> layer, CmdDrawDashedLine* c) {
        DashedLine(c->start.x, c->start.y, c->end.x, c->end.y, c->dashLength, c->gapLength, c->color, c->thickness);
    }

    void ExecuteDrawBatchedEntities(std::shared_ptr<layer::Layer> layer, CmdDrawBatchedEntities* c) {
        // Create a batch and execute all entities through it
        shader_draw_commands::DrawCommandBatch batch;
        batch.beginRecording();

        for (entt::entity entity : c->entities) {
            shader_draw_commands::executeEntityPipelineWithCommands(
                *c->registry,
                entity,
                batch,
                false  // Don't auto-optimize yet, we'll do it once at the end
            );
        }

        batch.endRecording();

        if (c->autoOptimize) {
            batch.optimize();
        }

        batch.execute();
    }

    void ExecuteDrawRenderGroup(std::shared_ptr<layer::Layer> layer, CmdDrawRenderGroup* c) {
        auto* group = render_groups::getGroup(c->groupName);
        if (!group) {
            SPDLOG_WARN("ExecuteDrawRenderGroup: group '{}' not found", c->groupName);
            return;
        }

        static int callCount = 0;
        if (callCount < 5) {
            SPDLOG_INFO("[render_groups] ExecuteDrawRenderGroup called for '{}' with {} entities",
                       c->groupName, group->entities.size());
            callCount++;
        }

        // 1. Collect valid entities with z-order, remove invalid
        std::vector<std::pair<int, size_t>> sortedIndices;
        sortedIndices.reserve(group->entities.size());

        for (size_t i = 0; i < group->entities.size(); ) {
            entt::entity e = group->entities[i].entity;

            // Lazy cleanup of invalid entities
            if (!c->registry->valid(e)) {
                group->entities[i] = group->entities.back();
                group->entities.pop_back();
                continue;
            }

            if (!c->registry->all_of<AnimationQueueComponent>(e)) {
                ++i;
                continue;
            }

            auto& anim = c->registry->get<AnimationQueueComponent>(e);
            if (anim.noDraw) {
                ++i;
                continue;
            }

            int z = layer_order_system::GetZIndex(*c->registry, e);
            sortedIndices.emplace_back(z, i);
            ++i;
        }

        // 2. Sort by z-order
        std::sort(sortedIndices.begin(), sortedIndices.end());

        // 3. Batch render
        shader_draw_commands::DrawCommandBatch batch;
        batch.beginRecording();

        for (auto& [z, idx] : sortedIndices) {
            auto& entry = group->entities[idx];
            const auto& shaders = entry.shaders.empty() ? group->defaultShaders : entry.shaders;

            shader_draw_commands::executeEntityWithShaders(*c->registry, entry.entity, shaders, batch);
        }

        batch.endRecording();
        if (c->autoOptimize) batch.optimize();
        batch.execute();
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
        RegisterRenderer<CmdBeginScissorMode>(DrawCommandType::BeginScissorMode, [](std::shared_ptr<layer::Layer> layer, CmdBeginScissorMode* c) { 
            BeginScissorMode(c->area.x, c->area.y, c->area.width, c->area.height);
        });
        RegisterRenderer<CmdEndScissorMode>(DrawCommandType::EndScissorMode, [](std::shared_ptr<layer::Layer> layer, CmdEndScissorMode*) { 
            EndScissorMode(); 
        });
        RegisterRenderer<CmdRenderUISliceFromDrawList>(DrawCommandType::RenderUISliceFromDrawList, [](std::shared_ptr<layer::Layer> layer, CmdRenderUISliceFromDrawList* c) { 
            renderSliceOffscreenFromDrawList(globals::getRegistry(), c->drawList, c->startIndex, c->endIndex, layer, c->pad); 
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
        RegisterRenderer<CmdPushObjectTransformsToMatrix>(DrawCommandType::PushObjectTransformsToMatrix, ExecutePushObjectTransformsToMatrix);
        RegisterRenderer<CmdScopedTransformCompositeRender>(DrawCommandType::ScopedTransformCompositeRender, ExecuteScopedTransformCompositeRender);
        RegisterRenderer<CmdScopedTransformCompositeRenderWithPipeline>(DrawCommandType::ScopedTransformCompositeRenderWithPipeline, ExecuteScopedTransformCompositeRenderWithPipeline);
        RegisterRenderer<CmdDrawCircleFilled>(DrawCommandType::Circle, ExecuteCircle);
        RegisterRenderer<CmdDrawCircleLine>(DrawCommandType::CircleLine, ExecuteCircleLine);
        RegisterRenderer<CmdDrawRectangle>(DrawCommandType::Rectangle, ExecuteRectangle);
        RegisterRenderer<CmdDrawRectanglePro>(DrawCommandType::RectanglePro, ExecuteRectanglePro);
        RegisterRenderer<CmdDrawRectangleLinesPro>(DrawCommandType::RectangleLinesPro, ExecuteRectangleLinesPro);
        RegisterRenderer<CmdDrawLine>(DrawCommandType::Line, ExecuteLine);
        RegisterRenderer<CmdDrawDashedLine>(DrawCommandType::DashedLine, ExecuteDashedLine);
        RegisterRenderer<CmdDrawGradientRectCentered>(DrawCommandType::DrawGradientRectCentered, ExecuteDrawGradientRectCentered);
        RegisterRenderer<CmdDrawGradientRectRoundedCentered>(DrawCommandType::DrawGradientRectRoundedCentered, ExecuteDrawGradientRectRoundedCentered);
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
        RegisterRenderer<CmdClearStencilBuffer>(DrawCommandType::ClearStencilBuffer, ExecuteClearStencilBuffer);
        RegisterRenderer<CmdStencilOp>(DrawCommandType::StencilOp, ExecuteStencilOp);
        RegisterRenderer<CmdRenderBatchFlush>(DrawCommandType::RenderBatchFlush, ExecuteRenderBatchFlush);
        RegisterRenderer<CmdAtomicStencilMask>(DrawCommandType::AtomicStencilMask, ExecuteAtomicStencilMask);
        RegisterRenderer<CmdColorMask>(DrawCommandType::ColorMask, ExecuteColorMask);
        RegisterRenderer<CmdStencilFunc>(DrawCommandType::StencilFunc, ExecuteStencilFunc);
        RegisterRenderer<CmdBeginStencilMode>(DrawCommandType::BeginStencilMode, ExecuteBeginStencilMode);
        RegisterRenderer<CmdEndStencilMode>(DrawCommandType::EndStencilMode, ExecuteEndStencilMode);
        RegisterRenderer<CmdBeginStencilMask>(DrawCommandType::BeginStencilMask, ExecuteBeginStencilMask);
        RegisterRenderer<CmdEndStencilMask>(DrawCommandType::EndStencilMask, ExecuteEndStencilMask);
        RegisterRenderer<CmdDrawCenteredEllipse>(DrawCommandType::DrawCenteredEllipse, ExecuteDrawCenteredEllipse);
        RegisterRenderer<CmdDrawRoundedLine>(DrawCommandType::DrawRoundedLine, ExecuteDrawRoundedLine);
        RegisterRenderer<CmdDrawPolyline>(DrawCommandType::DrawPolyline, ExecuteDrawPolyline);
        RegisterRenderer<CmdDrawArc>(DrawCommandType::DrawArc, ExecuteDrawArc);
        RegisterRenderer<CmdDrawTriangleEquilateral>(DrawCommandType::DrawTriangleEquilateral, ExecuteDrawTriangleEquilateral);
        RegisterRenderer<CmdDrawCenteredFilledRoundedRect>(DrawCommandType::DrawCenteredFilledRoundedRect, ExecuteDrawCenteredFilledRoundedRect);
        RegisterRenderer<CmdDrawSteppedRoundedRect>(DrawCommandType::DrawSteppedRoundedRect, ExecuteDrawSteppedRoundedRect);
        RegisterRenderer<CmdDrawSpriteCentered>(DrawCommandType::DrawSpriteCentered, ExecuteDrawSpriteCentered);
        RegisterRenderer<CmdDrawSpriteTopLeft>(DrawCommandType::DrawSpriteTopLeft, ExecuteDrawSpriteTopLeft);
        RegisterRenderer<CmdDrawDashedCircle>(DrawCommandType::DrawDashedCircle, ExecuteDrawDashedCircle);
        RegisterRenderer<CmdDrawDashedRoundedRect>(DrawCommandType::DrawDashedRoundedRect, ExecuteDrawDashedRoundedRect);
        RegisterRenderer<CmdDrawDashedLine>(DrawCommandType::DrawDashedLine, ExecuteDrawDashedLine);
        RegisterRenderer<CmdDrawBatchedEntities>(DrawCommandType::DrawBatchedEntities, ExecuteDrawBatchedEntities);
        RegisterRenderer<CmdDrawRenderGroup>(DrawCommandType::DrawRenderGroup, ExecuteDrawRenderGroup);

    }
}
