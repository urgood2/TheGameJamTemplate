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
    Vector2 drawPos{0.0f, 0.0f};
    float destW = static_cast<float>(animationFrame->width);
    float destH = static_cast<float>(animationFrame->height);
    float cardRotationRad = 0.0f;
    if (auto *t = registry.try_get<transform::Transform>(e)) {
        t->updateCachedValues();
        drawPos = {t->getVisualX(), t->getVisualY()};
        destW = t->getVisualW();
        destH = t->getVisualH();
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
    Rectangle destRect = {drawPos.x + destW * 0.5f, drawPos.y + destH * 0.5f, destW, destH};
    Vector2 origin = {destW * 0.5f, destH * 0.5f};

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
            float renderWidth = animationFrame->width + pipelineComp.padding * 2.0f;
            float renderHeight = animationFrame->height + pipelineComp.padding * 2.0f;

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
            shader_pipeline::front().texture,
            {0, 0, (float)shader_pipeline::width, (float)shader_pipeline::height},
            destRect,
            origin,
            cardRotationRad * RAD2DEG,
            WHITE
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
            float renderWidth = animationFrame->width + pipelineComp.padding * 2.0f;
            float renderHeight = animationFrame->height + pipelineComp.padding * 2.0f;

            uniforms.set("uImageSize", Vector2{renderWidth, renderHeight});
            uniforms.set("uGridRect", Vector4{
                0, 0, renderWidth, renderHeight
            });

            batch.addSetUniforms(overlay.shaderName, uniforms);
        }

        // Determine source texture based on input source
        RenderTexture2D source = (overlay.inputSource == shader_pipeline::OverlayInputSource::BaseSprite)
            ? shader_pipeline::GetBaseRenderTextureCache()
            : shader_pipeline::GetPostShaderPassRenderTextureCache();

        batch.addDrawTexturePro(
            source.texture,
            {0, 0, (float)shader_pipeline::width, (float)shader_pipeline::height},
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
