#include "shader_draw_commands.hpp"
#include "core/globals.hpp"
#include "components/components.hpp"
#include "components/graphics.hpp"
#include "systems/scripting/binding_recorder.hpp"
#include "util/utilities.hpp"
#include "systems/transform/transform.hpp"

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

    // Get current sprite information
    SpriteComponentASCII* currentSprite = nullptr;
    Rectangle* animationFrame = nullptr;

    if (aqc.animationQueue.empty()) {
        if (!aqc.defaultAnimation.animationList.empty()) {
            currentSprite = &aqc.defaultAnimation
                .animationList[aqc.defaultAnimation.currentAnimIndex].first;
            animationFrame = &currentSprite->spriteData.frame;
        }
    } else {
        auto& currentAnimObject = aqc.animationQueue[aqc.currentAnimationIndex];
        currentSprite = &currentAnimObject
            .animationList[currentAnimObject.currentAnimIndex].first;
        animationFrame = &currentSprite->spriteData.frame;
    }

    if (!currentSprite || !animationFrame) {
        return;
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

    Vector2 drawPos{0.0f, 0.0f};
    float baseW = static_cast<float>(animationFrame->width) * renderScale;
    float baseH = static_cast<float>(animationFrame->height) * renderScale;
    float pad = pipelineComp.padding;
    float destW = baseW + pad * 2.0f;
    float destH = baseH + pad * 2.0f;
    float visualScaleX = 1.0f;
    float visualScaleY = 1.0f;
    float cardRotationRad = 0.0f;
    if (auto *t = registry.try_get<transform::Transform>(e)) {
        t->updateCachedValues();
        drawPos = {t->getVisualX(), t->getVisualY()};
        float s = t->getVisualScaleWithHoverAndDynamicMotionReflected();
        if (t->getVisualW() > 0.0f && baseW > 0.0f) {
            visualScaleX = (t->getVisualW() / baseW) * s;
        } else {
            visualScaleX = s;
        }
        if (t->getVisualH() > 0.0f && baseH > 0.0f) {
            visualScaleY = (t->getVisualH() / baseH) * s;
        } else {
            visualScaleY = s;
        }
        destW = (baseW + pad * 2.0f) * visualScaleX;
        destH = (baseH + pad * 2.0f) * visualScaleY;
        float rotDeg = t->getVisualRWithDynamicMotionAndXLeaning();
        if (std::abs(rotDeg) < 0.0001f) {
            rotDeg = t->getVisualR();
        }
        cardRotationRad = rotDeg * DEG2RAD;
    }
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
    Color fgColor = currentSprite->fgColor;

    // Destination rect/rotation centered so rotation pivots around sprite center.
    Rectangle destRect = {drawPos.x - pad + destW * 0.5f, drawPos.y - pad + destH * 0.5f, destW, destH};
    Vector2 origin = {destW * 0.5f, destH * 0.5f};

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
                *animationFrame,
                shadowDest,
                origin,
                cardRotationRad * RAD2DEG,
                shadowColor
            );
        }
    }

    batch.addDrawTexturePro(
        *spriteAtlas,
        *animationFrame,
        destRect,
        origin,
        cardRotationRad * RAD2DEG,
        fgColor
    );

    // Add shader passes as commands
    for (auto& pass : pipelineComp.passes) {
        if (!pass.enabled) continue;

        // Begin shader
        batch.addBeginShader(pass.shaderName);

        shaders::ShaderUniformSet uniforms;
        if (pass.injectAtlasUniforms) {
            float renderWidth = destW;
            float renderHeight = destH;

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
        batch.addDrawTexturePro(
            *spriteAtlas,
            *animationFrame,
            destRect,
            origin,
            cardRotationRad * RAD2DEG,
            fgColor
        );

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
            float renderWidth = destW;
            float renderHeight = destH;

            uniforms.set("uImageSize", Vector2{renderWidth, renderHeight});
            uniforms.set("uGridRect", Vector4{
                0, 0, renderWidth, renderHeight
            });

            batch.addSetUniforms(overlay.shaderName, uniforms);
        }

        batch.addDrawTexturePro(
            *spriteAtlas,
            *animationFrame,
            destRect,
            origin,
            cardRotationRad * RAD2DEG,
            WHITE
        );

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
