#include "shader_draw_commands.hpp"
#include "core/globals.hpp"
#include "components/components.hpp"
#include "components/graphics.hpp"
#include "systems/scripting/binding_recorder.hpp"
#include "util/utilities.hpp"
#include "systems/transform/transform.hpp"
#include "raylib.h"

namespace shader_draw_commands {

void executeEntityPipelineWithCommands(
    entt::registry& registry,
    entt::entity e,
    DrawCommandBatch& batch,
    bool autoOptimize
) {
    // Check if entity has required components
    if (!registry.any_of<shader_pipeline::ShaderPipelineComponent>(e)) {
        SPDLOG_WARN("Entity {} does not have ShaderPipelineComponent", (int)e);
        return;
    }

    if (!registry.any_of<AnimationQueueComponent>(e)) {
        SPDLOG_WARN("Entity {} does not have AnimationQueueComponent", (int)e);
        return;
    }

    auto& pipelineComp = registry.get<shader_pipeline::ShaderPipelineComponent>(e);
    auto& aqc = registry.get<AnimationQueueComponent>(e);

    // Skip if entity is marked as no draw
    if (aqc.noDraw) {
        return;
    }

    // Get current sprite information (copy to avoid dangling references) + flips
    SpriteComponentASCII currentSpriteData{};
    SpriteComponentASCII* currentSprite = nullptr;
    Rectangle animationFrameData{};
    Rectangle* animationFrame = nullptr;
    bool flipX = false;
    bool flipY = false;

    if (aqc.animationQueue.empty()) {
        if (!aqc.defaultAnimation.animationList.empty()) {
            currentSpriteData = aqc.defaultAnimation
                .animationList[aqc.defaultAnimation.currentAnimIndex].first;
            animationFrameData = currentSpriteData.spriteData.frame;
            currentSprite = &currentSpriteData;
            animationFrame = &animationFrameData;
            flipX = aqc.defaultAnimation.flippedHorizontally;
            flipY = aqc.defaultAnimation.flippedVertically;
        }
    } else {
        auto& currentAnimObject = aqc.animationQueue[aqc.currentAnimationIndex];
        currentSpriteData = currentAnimObject
            .animationList[currentAnimObject.currentAnimIndex].first;
        animationFrameData = currentSpriteData.spriteData.frame;
        currentSprite = &currentSpriteData;
        animationFrame = &animationFrameData;
        flipX = currentAnimObject.flippedHorizontally;
        flipY = currentAnimObject.flippedVertically;
    }

    if (!currentSprite || !animationFrame) {
        return;
    }

    Color bgColor = currentSprite->bgColor;
    Color fgColor = currentSprite->fgColor;
    bool drawBackground = !currentSprite->noBackgroundColor;
    bool drawForeground = !currentSprite->noForegroundColor;
    if (fgColor.a == 0) {
        fgColor = WHITE;
    }

    // Only begin/end recording here if the caller hasn't already started a batch.
    const bool startedRecordingHere = !batch.recording();
    if (startedRecordingHere) {
        batch.beginRecording();
    }

    // Per-entity transform info for positioning, scaling, and rotation.
    float intrinsicScale = 1.0f;
    float uiScale = 1.0f;
    if (aqc.animationQueue.empty()) {
        intrinsicScale = aqc.defaultAnimation.intrinsincRenderScale.value_or(1.0f);
        uiScale = aqc.defaultAnimation.uiRenderScale.value_or(1.0f);
    } else {
        const auto& currentAnimObject = aqc.animationQueue[aqc.currentAnimationIndex];
        intrinsicScale = currentAnimObject.intrinsincRenderScale.value_or(1.0f);
        uiScale = currentAnimObject.uiRenderScale.value_or(1.0f);
    }
    float renderScale = intrinsicScale * uiScale;

    // Baseline dimensions from sprite (no padding in direct render path)
    float baseW = static_cast<float>(animationFrame->width) * renderScale;
    float baseH = static_cast<float>(animationFrame->height) * renderScale;
    float renderW = baseW;
    float renderH = baseH;

    float xSign = flipX ? -1.0f : 1.0f;
    float ySign = flipY ? -1.0f : 1.0f;
    Rectangle srcRect{
        static_cast<float>(animationFrame->x),
        static_cast<float>(animationFrame->y),
        static_cast<float>(animationFrame->width) * xSign,
        static_cast<float>(animationFrame->height) * ySign};

    Vector2 center{renderW * 0.5f, renderH * 0.5f};
    float destW = baseW;
    float destH = baseH;
    float baseVisualW = destW;
    float baseVisualH = destH;
    float basePosX = 0.0f;
    float basePosY = 0.0f;
    float drawRotationDeg = 0.0f;
    float uniformRotationDeg = 0.0f;
    transform::Transform* transformComp = registry.try_get<transform::Transform>(e);
    if (transformComp) {
        transformComp->updateCachedValues();
        const float visualW = transformComp->getVisualW();
        const float visualH = transformComp->getVisualH();
        basePosX = transformComp->getVisualX();
        basePosY = transformComp->getVisualY();
        baseVisualW = visualW;
        baseVisualH = visualH;

        const float scale = transformComp->getVisualScaleWithHoverAndDynamicMotionReflected();
        destW = visualW * scale;
        destH = visualH * scale;

        drawRotationDeg = transformComp->getVisualRWithDynamicMotionAndXLeaning();
        uniformRotationDeg = drawRotationDeg;
        if (std::abs(uniformRotationDeg) < 0.0001f) {
            uniformRotationDeg = transformComp->getVisualR();
        }
    } else {
        // Fallback when no transform exists: use sprite size at origin
        basePosX = 0.0f;
        basePosY = 0.0f;
    }
    const float cardRotationRad = uniformRotationDeg * DEG2RAD;
    const float cardRotationDeg = drawRotationDeg;

    // Pivot at transform center; keep transform position as the top-left anchor at scale 1,
    // and allow scale to expand/contract symmetrically around the center.
    Vector2 origin = {destW * 0.5f, destH * 0.5f};
    center = {basePosX + baseVisualW * 0.5f,
              basePosY + baseVisualH * 0.5f};
    Rectangle destRect{center.x, center.y, destW, destH};
    static int debugRotationLogs = 0;
    if (debugRotationLogs < 8) {
        SPDLOG_INFO("material_card_overlay rotation rad={} deg={} hasTransform={}",
                    cardRotationRad,
                    cardRotationRad * RAD2DEG,
                    registry.any_of<transform::Transform>(e));
        ++debugRotationLogs;
    }

    // Add base sprite draw command
    auto spriteAtlas = currentSprite->spriteData.texture;

    // Background fill to match legacy pipeline
    if (drawBackground) {
        Rectangle bgRect{
            destRect.x,
            destRect.y,
            destRect.width,
            destRect.height};
        batch.addCustomCommand([bgRect, origin, cardRotationDeg, bgColor]() {
            DrawRectanglePro(bgRect, origin, cardRotationDeg, bgColor);
        });
    }

    // Ground ellipse shadow (non-rotating)
    if (transformComp && registry.any_of<transform::GameObject>(e)) {
        const auto &node = registry.get<transform::GameObject>(e);
        if (node.shadowDisplacement &&
            node.shadowMode == transform::GameObject::ShadowMode::GroundEllipse) {
            float baseX = transformComp->getVisualX() + transformComp->getVisualW() * 0.5f;
            float baseY = transformComp->getVisualY() + transformComp->getVisualH() +
                          node.groundShadowYOffset;

            float s = transformComp->getVisualScaleWithHoverAndDynamicMotionReflected();
            float spriteW = transformComp->getVisualW();
            float spriteH = transformComp->getVisualH();

            float rx = node.groundShadowRadiusX.has_value()
                           ? *node.groundShadowRadiusX
                           : spriteW * 0.40f;

            float ry = node.groundShadowRadiusY.has_value()
                           ? *node.groundShadowRadiusY
                           : spriteH * 0.15f;

            rx *= s * node.groundShadowHeightFactor;
            ry *= s * node.groundShadowHeightFactor;

            if (node.groundShadowColor.a > 0 && rx > 0.1f && ry > 0.1f) {
                Color ellipseColor = node.groundShadowColor;
                batch.addCustomCommand([baseX, baseY, rx, ry, ellipseColor]() {
                    rlPushMatrix();
                    rlTranslatef(baseX, baseY, 0.0f);
                    rlScalef(rx, ry, 1.0f);
                    DrawCircleV({0.0f, 0.0f}, 1.0f, ellipseColor);
                    rlPopMatrix();
                });
            }
        }
    }

    // Approximate legacy sprite-based shadow rendering
    if (registry.any_of<transform::GameObject>(e)) {
        const auto &node = registry.get<transform::GameObject>(e);
        if (node.shadowMode == transform::GameObject::ShadowMode::SpriteBased &&
            node.shadowDisplacement) {
            const float baseExaggeration = globals::getBaseShadowExaggeration();
            const float heightFactor = 1.0f + node.shadowHeight.value_or(0.0f);
            const float shadowOffsetX =
                node.shadowDisplacement->x * baseExaggeration * heightFactor;
            const float shadowOffsetY =
                node.shadowDisplacement->y * baseExaggeration * heightFactor;

            Color shadowColor = Fade(BLACK, 0.8f);
            Rectangle shadowDest = destRect;
            shadowDest.x -= shadowOffsetX;
            shadowDest.y += shadowOffsetY;

            batch.addDrawTexturePro(
                *spriteAtlas,
                srcRect,
                shadowDest,
                origin,
                cardRotationDeg,
                shadowColor
            );
        }
    }

    if (drawForeground) {
        batch.addDrawTexturePro(
            *spriteAtlas,
            srcRect,
            destRect,
            origin,
            cardRotationDeg,
            fgColor
        );
    }

    // Add shader passes as commands
    for (auto& pass : pipelineComp.passes) {
        if (!pass.enabled) continue;

        // Begin shader
        batch.addBeginShader(pass.shaderName);

        shaders::ShaderUniformSet uniforms;
        if (pass.injectAtlasUniforms) {
            float renderWidth = renderW;
            float renderHeight = renderH;

            uniforms.set("uImageSize", Vector2{renderWidth, renderHeight});
            uniforms.set("uGridRect", Vector4{0, 0, renderWidth, renderHeight});
        }
        if (pass.shaderName == "material_card_overlay") {
            uniforms.set("card_rotation", cardRotationRad);
        }
        if (!uniforms.uniforms.empty()) {
            batch.addSetUniforms(pass.shaderName, uniforms);
        }

        // Custom pre-pass function
        if (pass.customPrePassFunction) {
            batch.addCustomCommand(pass.customPrePassFunction);
        }

        // Draw the texture through the shader
        if (drawForeground) {
            batch.addDrawTexturePro(
                *spriteAtlas,
                srcRect,
                destRect,
                origin,
                cardRotationDeg,
                fgColor
            );
        }

        // End shader
        batch.addEndShader();
    }

    // Add overlay draws
    for (const auto& overlay : pipelineComp.overlayDraws) {
        if (!overlay.enabled) continue;

        batch.addBeginShader(overlay.shaderName);

        if (overlay.customPrePassFunction) {
            batch.addCustomCommand(overlay.customPrePassFunction);
        }

        if (overlay.injectAtlasUniforms) {
            shaders::ShaderUniformSet uniforms;
            float renderWidth = renderW;
            float renderHeight = renderH;

            uniforms.set("uImageSize", Vector2{renderWidth, renderHeight});
            uniforms.set("uGridRect", Vector4{
                0, 0, renderWidth, renderHeight
            });

            batch.addSetUniforms(overlay.shaderName, uniforms);
        }

        if (drawForeground) {
            batch.addDrawTexturePro(
                *spriteAtlas,
                srcRect,
                destRect,
                origin,
                cardRotationDeg,
                WHITE
            );
        }

        batch.addEndShader();
    }

    // End/optimize only if we started recording in this helper.
    if (startedRecordingHere) {
        batch.endRecording();
    }
    if (autoOptimize && startedRecordingHere) {
        batch.optimize();
    }
}

void exposeToLua(sol::state& lua) {
    auto& rec = BindingRecorder::instance();

    // Create namespace table
    sol::table sdc = lua.create_named_table("shader_draw_commands");
    rec.add_type("shader_draw_commands").doc =
        "Draw command batching system for optimized shader rendering.";

    // DrawCommandType enum
    sdc["DrawCommandType"] = lua.create_table_with(
        "BeginShader", DrawCommandType::BeginShader,
        "EndShader", DrawCommandType::EndShader,
        "DrawTexture", DrawCommandType::DrawTexture,
        "SetUniforms", DrawCommandType::SetUniforms,
        "Custom", DrawCommandType::Custom
    );
    auto& enumType = rec.add_type("shader_draw_commands.DrawCommandType");
    enumType.doc = "Types of draw commands that can be batched.";

    // DrawCommandBatch class
    sdc.new_usertype<DrawCommandBatch>("DrawCommandBatch",
        sol::constructors<DrawCommandBatch()>(),

        "beginRecording", &DrawCommandBatch::beginRecording,
        "endRecording", &DrawCommandBatch::endRecording,
        "recording", &DrawCommandBatch::recording,

        "addBeginShader", &DrawCommandBatch::addBeginShader,
        "addEndShader", &DrawCommandBatch::addEndShader,
        "addDrawTexture", &DrawCommandBatch::addDrawTexture,
        "addSetUniforms", &DrawCommandBatch::addSetUniforms,
        "addCustomCommand", &DrawCommandBatch::addCustomCommand,

        "execute", &DrawCommandBatch::execute,
        "optimize", &DrawCommandBatch::optimize,
        "clear", &DrawCommandBatch::clear,
        "size", &DrawCommandBatch::size,

        "type_id", []() { return entt::type_hash<DrawCommandBatch>::value(); }
    );

    auto& batchType = rec.add_type("shader_draw_commands.DrawCommandBatch", true);
    batchType.doc = "Manages a batch of draw commands for optimized rendering.";

    // Document methods
    rec.record_method("shader_draw_commands.DrawCommandBatch", {
        "beginRecording",
        "---@return nil",
        "Start recording draw commands into the batch."
    });

    rec.record_method("shader_draw_commands.DrawCommandBatch", {
        "endRecording",
        "---@return nil",
        "Stop recording draw commands."
    });

    rec.record_method("shader_draw_commands.DrawCommandBatch", {
        "recording",
        "---@return boolean",
        "Check if currently recording commands."
    });

    rec.record_method("shader_draw_commands.DrawCommandBatch", {
        "addBeginShader",
        "---@param shaderName string\n---@return nil",
        "Add a command to begin using a shader."
    });

    rec.record_method("shader_draw_commands.DrawCommandBatch", {
        "addEndShader",
        "---@return nil",
        "Add a command to end the current shader."
    });

    rec.record_method("shader_draw_commands.DrawCommandBatch", {
        "addDrawTexture",
        "---@param texture Texture2D\n---@param sourceRect Rectangle\n---@param position Vector2\n---@param tint? Color\n---@return nil",
        "Add a command to draw a texture."
    });

    rec.record_method("shader_draw_commands.DrawCommandBatch", {
        "addCustomCommand",
        "---@param func fun()\n---@return nil",
        "Add a custom command function to execute."
    });

    rec.record_method("shader_draw_commands.DrawCommandBatch", {
        "execute",
        "---@return nil",
        "Execute all recorded commands in order."
    });

    rec.record_method("shader_draw_commands.DrawCommandBatch", {
        "optimize",
        "---@return nil",
        "Optimize command order to minimize shader state changes."
    });

    rec.record_method("shader_draw_commands.DrawCommandBatch", {
        "clear",
        "---@return nil",
        "Clear all commands from the batch."
    });

    rec.record_method("shader_draw_commands.DrawCommandBatch", {
        "size",
        "---@return integer",
        "Get the number of commands in the batch."
    });

    // Global batch accessor
    sdc["globalBatch"] = &globalBatch;

    // Helper function
    sdc.set_function("executeEntityPipelineWithCommands",
        [](entt::registry* registry, entt::entity e, DrawCommandBatch& batch, bool autoOptimize) {
            executeEntityPipelineWithCommands(*registry, e, batch, autoOptimize);
        }
    );

    rec.record_free_function({"shader_draw_commands"}, {
        "executeEntityPipelineWithCommands",
        "---@param registry Registry\n"
        "---@param entity Entity\n"
        "---@param batch DrawCommandBatch\n"
        "---@param autoOptimize? boolean\n"
        "---@return nil",
        "Execute an entity's shader pipeline using draw command batching."
    });

    SPDLOG_INFO("Exposed shader_draw_commands to Lua");
}

} // namespace shader_draw_commands
