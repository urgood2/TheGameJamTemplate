#include "shader_draw_commands.hpp"
#include "core/globals.hpp"
#include "components/components.hpp"
#include "components/graphics.hpp"
#include "systems/scripting/binding_recorder.hpp"
#include "util/utilities.hpp"
#include "systems/transform/transform.hpp"
#include "raylib.h"
#include "spdlog/spdlog.h"
#include <algorithm>
#include <cmath>
#include <unordered_map>
#include <utility>

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

    const float xSign = flipX ? -1.0f : 1.0f;
    const float ySign = flipY ? -1.0f : 1.0f;
    // When flipping, offset into the atlas by frame dimensions so negative widths/heights
    // don't sample outside the intended region.
    Rectangle srcRect{
        static_cast<float>(animationFrame->x) + (flipX ? static_cast<float>(animationFrame->width) : 0.0f),
        static_cast<float>(animationFrame->y) + (flipY ? static_cast<float>(animationFrame->height) : 0.0f),
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

    // Add base sprite draw command
    auto spriteAtlas = currentSprite->spriteData.texture;

    // Atlas rect and size for accurate UVs in shaders
    Rectangle atlasRect{
        static_cast<float>(animationFrame->x),
        static_cast<float>(animationFrame->y),
        static_cast<float>(animationFrame->width),
        static_cast<float>(animationFrame->height)};
    Vector2 atlasSize{
        static_cast<float>(spriteAtlas->width),
        static_cast<float>(spriteAtlas->height)};

    // Pivot at transform center; keep transform position as the top-left anchor at scale 1,
    // and allow scale to expand/contract symmetrically around the center.
    Vector2 origin = {destW * 0.5f, destH * 0.5f};
    center = {basePosX + baseVisualW * 0.5f,
              basePosY + baseVisualH * 0.5f};
    Rectangle destRect{center.x, center.y, destW, destH};
    Vector2 skewCenter{destRect.x, destRect.y};
    Vector2 skewSize{std::abs(destRect.width), std::abs(destRect.height)};
    static int debugRotationLogs = 0;
    if (debugRotationLogs < 8) {
        SPDLOG_INFO("material_card_overlay rotation rad={} deg={} hasTransform={}",
                    cardRotationRad,
                    cardRotationRad * RAD2DEG,
                    registry.any_of<transform::Transform>(e));
        ++debugRotationLogs;
    }

    bool tiltEnabled = false;
    if (registry.any_of<transform::GameObject>(e)) {
        const auto& node = registry.get<transform::GameObject>(e);
        tiltEnabled = node.state.isBeingHovered || node.state.isBeingFocused;
    }

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

    bool renderShadow = false;
    Rectangle shadowDest{};
    Color shadowColor{};
    if (registry.any_of<transform::GameObject>(e)) {
        const auto& node = registry.get<transform::GameObject>(e);
        if (node.shadowMode == transform::GameObject::ShadowMode::SpriteBased &&
            node.shadowDisplacement) {
            const float baseExaggeration = globals::getBaseShadowExaggeration();
            const float dragLift = node.state.isBeingDragged ? 7.5f : 1.0f; // stronger lift when dragging
            const float heightFactor = (1.0f + node.shadowHeight.value_or(0.0f)) * dragLift;
            const float shadowOffsetX =
                node.shadowDisplacement->x * baseExaggeration * heightFactor;
            const float shadowOffsetY =
                node.shadowDisplacement->y * baseExaggeration * heightFactor;

            shadowDest = destRect;
            shadowDest.x -= shadowOffsetX;
            shadowDest.y += shadowOffsetY;
            shadowColor = Fade(BLACK, 0.8f);
            renderShadow = true;
        }
    }

    BatchedLocalCommands* localCmds = registry.try_get<BatchedLocalCommands>(e);
    std::vector<OwnedDrawCommand> allLocalCommands;
    if (localCmds) {
        allLocalCommands = localCmds->commands;
        std::stable_sort(allLocalCommands.begin(), allLocalCommands.end(),
                         [](const OwnedDrawCommand& a, const OwnedDrawCommand& b) {
                             return a.cmd.z < b.cmd.z;
                         });
        // Commands are intended to be frame-scoped; clear after consuming to avoid
        // accumulation and duplicated draws across frames.
        localCmds->clear();
    }

    auto renderLocalCommand = [](const OwnedDrawCommand& oc) {
        auto it = layer::dispatcher.find(oc.cmd.type);
        if (it != layer::dispatcher.end()) {
            std::shared_ptr<layer::Layer> dummyLayer{};
            it->second(dummyLayer, oc.cmd.data);
        }
    };

    auto shaderIsPseudo3DSkew = [](const std::string& shaderName) {
        return shaderName == "3d_skew" ||
               shaderName == "3d_skew_aurora" ||
               shaderName == "3d_skew_foil" ||
               shaderName == "3d_skew_gold_seal" ||
               shaderName == "3d_skew_holo" ||
               shaderName == "3d_skew_hologram" ||
               shaderName == "3d_skew_iridescent" ||
               shaderName == "3d_skew_negative" ||
               shaderName == "3d_skew_negative_tint" ||
               shaderName == "3d_skew_negative_shine" ||
               shaderName == "3d_skew_nebula" ||
               shaderName == "3d_skew_crystalline" ||
               shaderName == "3d_skew_glitch" ||
               shaderName == "3d_skew_oil_slick" ||
               shaderName == "3d_skew_plasma" ||
               shaderName == "3d_skew_polychrome" ||
               shaderName == "3d_skew_polka_dot" ||
               shaderName == "3d_skew_prismatic" ||
               shaderName == "3d_skew_thermal" ||
               shaderName == "3d_skew_voucher";
    };

    struct SkewUniformCacheEntry {
        bool valid{false};
        Vector2 regionRate{};
        Vector2 pivot{};
        Vector2 quadCenter{};
        Vector2 quadSize{};
        float tiltEnabled{0.0f};
        float cardRotation{0.0f};
        float uvPassthrough{-9999.0f};
    };
    auto& skewUniformCache = [&]() -> std::unordered_map<std::string, SkewUniformCacheEntry>& {
        static std::unordered_map<std::string, SkewUniformCacheEntry> cache;
        return cache;
    }();
    auto applySkewUniforms = [&](const std::string& shaderName,
                                 const Vector2& regionRateVal,
                                 const Vector2& pivotVal,
                                 const Vector2& quadCenterVal,
                                 const Vector2& quadSizeVal,
                                 float tiltEnabledVal,
                                 float cardRotationVal,
                                 float uvPassthroughVal) {
        auto& cache = skewUniformCache[shaderName];
        const bool needsUpdate =
            !cache.valid ||
            cache.regionRate.x != regionRateVal.x ||
            cache.regionRate.y != regionRateVal.y ||
            cache.pivot.x != pivotVal.x ||
            cache.pivot.y != pivotVal.y ||
            cache.quadCenter.x != quadCenterVal.x ||
            cache.quadCenter.y != quadCenterVal.y ||
            cache.quadSize.x != quadSizeVal.x ||
            cache.quadSize.y != quadSizeVal.y ||
            cache.tiltEnabled != tiltEnabledVal ||
            cache.cardRotation != cardRotationVal ||
            cache.uvPassthrough != uvPassthroughVal;
        if (!needsUpdate) {
            return;
        }

        auto& uniforms = globals::getGlobalShaderUniforms();
        uniforms.set(shaderName, "regionRate", regionRateVal);
        uniforms.set(shaderName, "pivot", pivotVal);
        uniforms.set(shaderName, "quad_center", quadCenterVal);
        uniforms.set(shaderName, "quad_size", quadSizeVal);
        uniforms.set(shaderName, "uv_passthrough", uvPassthroughVal);
        uniforms.set(shaderName, "tilt_enabled", tiltEnabledVal);
        uniforms.set(shaderName, "card_rotation", cardRotationVal);

        Shader shader = shaders::getShader(shaderName);
        if (shader.id) {
            shaders::TryApplyUniforms(shader,
                                      uniforms,
                                      shaderName);
        }

        cache.valid = true;
        cache.regionRate = regionRateVal;
        cache.pivot = pivotVal;
        cache.quadCenter = quadCenterVal;
        cache.quadSize = quadSizeVal;
        cache.tiltEnabled = tiltEnabledVal;
        cache.cardRotation = cardRotationVal;
        cache.uvPassthrough = uvPassthroughVal;
    };

    auto makeLocalCommandEmitter = [&](const std::vector<OwnedDrawCommand>& commands,
                                       bool beforeSprite,
                                       bool shaderIs3DSkew = false,
                                       std::string targetShaderName = {}) {
        const float capturedBaseVisualW = baseVisualW;
        const float capturedBaseVisualH = baseVisualH;
        const float capturedDestW = destW;
        const float capturedDestH = destH;
        const float capturedRotation = cardRotationDeg;
        const Vector2 capturedCenter = center;
        auto commandsCopy = commands; // keep shared_ptr owners alive

        return [commandsCopy,
                beforeSprite,
                capturedBaseVisualW,
                capturedBaseVisualH,
                capturedDestW,
                capturedDestH,
                capturedRotation,
                capturedCenter,
                renderLocalCommand,
                shaderIs3DSkew,
                targetShaderName]() {
            auto& uniforms = globals::getGlobalShaderUniforms();
            bool haveRegionCache = false;
            Vector2 lastRegionRate{0.0f, 0.0f};
            Vector2 lastPivot{0.0f, 0.0f};
            float cachedUvPassthrough = -123.0f;

            auto applyUvPassthrough = [&](float value) {
                if (!shaderIs3DSkew || targetShaderName.empty()) {
                    return;
                }
                if (cachedUvPassthrough == value) {
                    return;
                }
                uniforms.set(targetShaderName, "uv_passthrough", value);
                Shader shader = shaders::getShader(targetShaderName);
                if (shader.id) {
                    shaders::TryApplyUniforms(shader,
                                              uniforms,
                                              targetShaderName);
                }
                cachedUvPassthrough = value;
            };
            auto apply3DSkewAtlasForCommand = [&](const OwnedDrawCommand& oc) {
                if (!shaderIs3DSkew || targetShaderName.empty()) {
                    return;
                }

                Vector2 regionRate{1.0f, 1.0f};
                Vector2 pivot{0.0f, 0.0f};
                bool hasRegion = false;

                if (oc.cmd.type == layer::DrawCommandType::TexturePro) {
                    auto* texCmd = static_cast<layer::CmdTexturePro*>(oc.cmd.data);
                    if (texCmd && texCmd->texture.id != 0 &&
                        texCmd->texture.width > 0 && texCmd->texture.height > 0) {
                        regionRate = Vector2{
                            texCmd->source.width / static_cast<float>(texCmd->texture.width),
                            texCmd->source.height / static_cast<float>(texCmd->texture.height)};
                        pivot = Vector2{
                            texCmd->source.x / static_cast<float>(texCmd->texture.width),
                            texCmd->source.y / static_cast<float>(texCmd->texture.height)};
                        hasRegion = true;
                    }
                }

                if (!hasRegion) {
                    regionRate = Vector2{1.0f, 1.0f};
                    pivot = Vector2{0.0f, 0.0f};
                }

                if (haveRegionCache &&
                    regionRate.x == lastRegionRate.x &&
                    regionRate.y == lastRegionRate.y &&
                    pivot.x == lastPivot.x &&
                    pivot.y == lastPivot.y) {
                    return;
                }

                uniforms.set(targetShaderName, "regionRate", regionRate);
                uniforms.set(targetShaderName, "pivot", pivot);
                Shader shader = shaders::getShader(targetShaderName);
                if (shader.id) {
                    shaders::TryApplyUniforms(shader,
                                              uniforms,
                                              targetShaderName);
                }
                lastRegionRate = regionRate;
                lastPivot = pivot;
                haveRegionCache = true;
            };

            const float scaleX = (capturedBaseVisualW > 0.0f)
                                     ? (capturedDestW / capturedBaseVisualW)
                                     : 1.0f;
            const float scaleY = (capturedBaseVisualH > 0.0f)
                                     ? (capturedDestH / capturedBaseVisualH)
                                     : 1.0f;
            rlPushMatrix();
            rlTranslatef(capturedCenter.x, capturedCenter.y, 0.0f);
            rlRotatef(capturedRotation, 0.0f, 0.0f, 1.0f);
            rlScalef(scaleX, scaleY, 1.0f);
            rlTranslatef(-capturedBaseVisualW * 0.5f,
                         -capturedBaseVisualH * 0.5f,
                         0.0f);
            for (const auto& oc : commandsCopy) {
                const bool cmdIsBefore = oc.cmd.z < 0;
                if (beforeSprite != cmdIsBefore) {
                    continue;
                }
                if (shaderIs3DSkew) {
                    apply3DSkewAtlasForCommand(oc);
                }
                if (oc.forceUvPassthrough) {
                    applyUvPassthrough(1.0f);
                }
                renderLocalCommand(oc);
                if (oc.forceUvPassthrough) {
                    applyUvPassthrough(0.0f);
                }
            }
            rlPopMatrix();
        };
    };

    // Partition locals into text, sticker, and non-text so we can render sticker/text separately with identity atlas.
    auto isTextCommand = [](const OwnedDrawCommand& oc) {
        using layer::DrawCommandType;
        return oc.forceTextPass ||
               oc.cmd.type == DrawCommandType::Text ||
               oc.cmd.type == DrawCommandType::DrawTextCentered ||
               oc.cmd.type == DrawCommandType::TextPro;
    };
    std::vector<OwnedDrawCommand> localTextCommands;
    std::vector<OwnedDrawCommand> localStickerCommands;
    std::vector<OwnedDrawCommand> localNonTextCommands;
    for (const auto& oc : allLocalCommands) {
        if (isTextCommand(oc)) {
            localTextCommands.push_back(oc);
        } else if (oc.forceStickerPass) {
            localStickerCommands.push_back(oc);
        } else {
            localNonTextCommands.push_back(oc);
        }
    }

    const bool hasLocalNonTextCommands = !localNonTextCommands.empty();
    const bool hasLocalTextCommands = !localTextCommands.empty();
    const bool hasLocalStickerCommands = !localStickerCommands.empty();

    int lastEnabledPass = -1;
    for (size_t i = 0; i < pipelineComp.passes.size(); ++i) {
        if (pipelineComp.passes[i].enabled) {
            lastEnabledPass = static_cast<int>(i);
        }
    }
    int lastEnabledOverlay = -1;
    for (size_t i = 0; i < pipelineComp.overlayDraws.size(); ++i) {
        if (pipelineComp.overlayDraws[i].enabled) {
            lastEnabledOverlay = static_cast<int>(i);
        }
    }
    auto selectTextLikeShader = [&]() -> std::pair<std::string, bool> {
        std::string shaderName;
        bool injectAtlas = true;
        if (lastEnabledOverlay != -1) {
            shaderName = pipelineComp.overlayDraws[lastEnabledOverlay].shaderName;
            injectAtlas = pipelineComp.overlayDraws[lastEnabledOverlay].injectAtlasUniforms;
        } else if (lastEnabledPass != -1) {
            shaderName = pipelineComp.passes[lastEnabledPass].shaderName;
            injectAtlas = pipelineComp.passes[lastEnabledPass].injectAtlasUniforms;
        }
        return {shaderName, injectAtlas};
    };

    if (drawForeground && pipelineComp.passes.empty()) {
        if (hasLocalNonTextCommands) {
            batch.addCustomCommand(makeLocalCommandEmitter(localNonTextCommands, /*beforeSprite=*/true));
        }
        batch.addDrawTexturePro(
            *spriteAtlas,
            srcRect,
            destRect,
            origin,
            cardRotationDeg,
            fgColor
        );
        if (hasLocalNonTextCommands) {
            batch.addCustomCommand(makeLocalCommandEmitter(localNonTextCommands, /*beforeSprite=*/false));
        }
        if (hasLocalTextCommands) {
            // Draw text with default shader but same transform.
            batch.addCustomCommand(makeLocalCommandEmitter(localTextCommands, /*beforeSprite=*/true));
            batch.addCustomCommand(makeLocalCommandEmitter(localTextCommands, /*beforeSprite=*/false));
        }
    } else if (drawForeground && !pipelineComp.passes.empty()) {
        // Emit non-text locals inside the same pass/overlay as the sprite so
        // forceUvPassthrough overlays draw.
        if (hasLocalNonTextCommands && lastEnabledPass != -1) {
            batch.addCustomCommand(makeLocalCommandEmitter(localNonTextCommands, /*beforeSprite=*/true));
        }
        // sprite draw happens inside passes below
    }

    // Add shader passes as commands
    for (size_t passIndex = 0; passIndex < pipelineComp.passes.size(); ++passIndex) {
        auto& pass = pipelineComp.passes[passIndex];
        if (!pass.enabled) continue;

        // Begin shader
        batch.addBeginShader(pass.shaderName);

        // Run pre-pass work and apply uniforms after any dynamic updates.
        {
            const std::string shaderName = pass.shaderName;
            const bool injectAtlas = pass.injectAtlasUniforms;
            const bool isCardOverlay =
                (shaderName == "material_card_overlay" ||
                 shaderName == "material_card_overlay_new_dissolve");
            const float cardRotation = cardRotationRad;
            // For pseudo-3D skew shaders, keep UVs locked to the atlas sub-rect.
            const bool is3DSkew = shaderIsPseudo3DSkew(shaderName);
            const Vector2 regionRate{
                atlasRect.width / atlasSize.x,
                atlasRect.height / atlasSize.y};
            const Vector2 pivot{
                atlasRect.x / atlasSize.x,
                atlasRect.y / atlasSize.y};
            auto customPrePass = pass.customPrePassFunction;

            batch.addCustomCommand([shaderName,
                                    injectAtlas,
                                    isCardOverlay,
                                    is3DSkew,
                                    atlasRect,
                                    atlasSize,
                                    regionRate,
                                    pivot,
                                    cardRotation,
                                    skewCenter,
                                    skewSize,
                                    customPrePass,
                                    tiltEnabled,
                                    applySkewUniforms]() {
                if (injectAtlas) {
                    shaders::injectAtlasUniforms(
                        globals::getGlobalShaderUniforms(),
                        shaderName,
                        atlasRect,
                        atlasSize);
                }
                if (is3DSkew) {
                    applySkewUniforms(shaderName,
                                      regionRate,
                                      pivot,
                                      skewCenter,
                                      skewSize,
                                      tiltEnabled ? 1.0f : 0.0f,
                                      cardRotation,
                                      0.0f);
                }
                if (isCardOverlay) {
                    globals::getGlobalShaderUniforms().set(
                        shaderName,
                        "card_rotation",
                        cardRotation);
                }
                if (customPrePass) {
                    customPrePass();
                }

                Shader shader = shaders::getShader(shaderName);
                if (shader.id) {
                    shaders::TryApplyUniforms(
                        shader,
                        globals::getGlobalShaderUniforms(),
                        shaderName);
                }
            });
        }

        const bool passIs3DSkew = shaderIsPseudo3DSkew(pass.shaderName);
        const bool passIsCardOverlay =
            (pass.shaderName == "material_card_overlay" ||
             pass.shaderName == "material_card_overlay_new_dissolve");

        if (drawForeground) {
            const bool emitLocalsThisPass =
                hasLocalNonTextCommands &&
                static_cast<int>(passIndex) == lastEnabledPass;
            if (renderShadow) {
                batch.addCustomCommand([shaderName = pass.shaderName,
                                        passIs3DSkew,
                                        passIsCardOverlay,
                                        cardRotation = cardRotationRad]() {
                    if (passIs3DSkew || passIsCardOverlay) {
                        globals::getGlobalShaderUniforms().set(shaderName, "shadow", 1.0f);
                        globals::getGlobalShaderUniforms().set(shaderName, "card_rotation", cardRotation);
                        Shader shader = shaders::getShader(shaderName);
                        if (shader.id) {
                            shaders::TryApplyUniforms(shader,
                                                      globals::getGlobalShaderUniforms(),
                                                      shaderName);
                        }
                    }
                });

                batch.addDrawTexturePro(
                    *spriteAtlas,
                    srcRect,
                    shadowDest,
                    origin,
                    cardRotationDeg,
                    shadowColor
                );

                batch.addCustomCommand([shaderName = pass.shaderName,
                                        passIs3DSkew,
                                        passIsCardOverlay]() {
                    if (passIs3DSkew || passIsCardOverlay) {
                        globals::getGlobalShaderUniforms().set(shaderName, "shadow", 0.0f);
                        Shader shader = shaders::getShader(shaderName);
                        if (shader.id) {
                            shaders::TryApplyUniforms(shader,
                                                      globals::getGlobalShaderUniforms(),
                                                      shaderName);
                        }
                    }
                });
            }
            if (emitLocalsThisPass) {
                batch.addCustomCommand(makeLocalCommandEmitter(localNonTextCommands, /*beforeSprite=*/true));
            }
            batch.addDrawTexturePro(
                *spriteAtlas,
                srcRect,
                destRect,
                origin,
                cardRotationDeg,
                fgColor
            );
            if (emitLocalsThisPass) {
                batch.addCustomCommand(makeLocalCommandEmitter(localNonTextCommands, /*beforeSprite=*/false));
            }
        }

        // End shader
        batch.addEndShader();
    }

    // Add overlay draws
    for (size_t overlayIndex = 0; overlayIndex < pipelineComp.overlayDraws.size(); ++overlayIndex) {
        const auto& overlay = pipelineComp.overlayDraws[overlayIndex];
        if (!overlay.enabled) continue;

        batch.addBeginShader(overlay.shaderName);

        // Run pre-pass work and apply uniforms after any dynamic updates.
        {
            const std::string shaderName = overlay.shaderName;
            const bool injectAtlas = overlay.injectAtlasUniforms;
            const bool is3DSkew = shaderIsPseudo3DSkew(shaderName);
            const bool isCardOverlay =
                (shaderName == "material_card_overlay" ||
                 shaderName == "material_card_overlay_new_dissolve");
            const float cardRotation = cardRotationRad;
            auto customPrePass = overlay.customPrePassFunction;

            batch.addCustomCommand([shaderName,
                                    injectAtlas,
                                    is3DSkew,
                                    isCardOverlay,
                                    cardRotation,
                                    atlasRect,
                                    atlasSize,
                                    regionRate = Vector2{atlasRect.width / atlasSize.x,
                                                         atlasRect.height / atlasSize.y},
                                    pivot = Vector2{atlasRect.x / atlasSize.x,
                                                    atlasRect.y / atlasSize.y},
                                    skewCenter,
                                    skewSize,
                                    tiltEnabled,
                                    customPrePass,
                                    applySkewUniforms]() {
                if (injectAtlas) {
                    shaders::injectAtlasUniforms(
                        globals::getGlobalShaderUniforms(),
                        shaderName,
                        atlasRect,
                        atlasSize);
                }
                if (is3DSkew) {
                    applySkewUniforms(shaderName,
                                      regionRate,
                                      pivot,
                                      skewCenter,
                                      skewSize,
                                      tiltEnabled ? 1.0f : 0.0f,
                                      cardRotation,
                                      0.0f);
                }
                if (isCardOverlay) {
                    globals::getGlobalShaderUniforms().set(
                        shaderName,
                        "card_rotation",
                        cardRotation);
                }
                if (customPrePass) {
                    customPrePass();
                }

                Shader shader = shaders::getShader(shaderName);
                if (shader.id) {
                    shaders::TryApplyUniforms(
                        shader,
                        globals::getGlobalShaderUniforms(),
                        shaderName);
                }
            });
        }

        if (drawForeground) {
            const bool emitLocalsThisOverlay =
                hasLocalNonTextCommands &&
                static_cast<int>(overlayIndex) == lastEnabledOverlay;
            if (emitLocalsThisOverlay) {
                batch.addCustomCommand(makeLocalCommandEmitter(localNonTextCommands, /*beforeSprite=*/true));
            }
            batch.addDrawTexturePro(
                *spriteAtlas,
                srcRect,
                destRect,
                origin,
                cardRotationDeg,
                WHITE
            );
            if (emitLocalsThisOverlay) {
                batch.addCustomCommand(makeLocalCommandEmitter(localNonTextCommands, /*beforeSprite=*/false));
            }
        }

        batch.addEndShader();
    }

    // Sticker pass: identity atlas + uv_passthrough, separate from text
    if (drawForeground && hasLocalStickerCommands) {
        auto [stickerShaderName, stickerInjectAtlas] = selectTextLikeShader();
        if (!stickerShaderName.empty()) {
            const bool stickerIs3DSkew = shaderIsPseudo3DSkew(stickerShaderName);
            batch.addBeginShader(stickerShaderName);
            batch.addCustomCommand([stickerShaderName,
                                    stickerInjectAtlas,
                                    stickerIs3DSkew,
                                    cardRotation = cardRotationRad,
                                    skewCenter,
                                    skewSize,
                                    tiltEnabled,
                                    applySkewUniforms]() {
                if (stickerInjectAtlas) {
                    shaders::injectAtlasUniforms(
                        globals::getGlobalShaderUniforms(),
                        stickerShaderName,
                        Rectangle{0.0f, 0.0f, 1.0f, 1.0f},
                        Vector2{1.0f, 1.0f});
                }
                if (stickerIs3DSkew) {
                    applySkewUniforms(stickerShaderName,
                                      Vector2{1.0f, 1.0f},
                                      Vector2{0.0f, 0.0f},
                                      skewCenter,
                                      skewSize,
                                      tiltEnabled ? 1.0f : 0.0f,
                                      cardRotation,
                                      1.0f);
                } else {
                    globals::getGlobalShaderUniforms().set(stickerShaderName, "card_rotation", cardRotation);
                }
                Shader shader = shaders::getShader(stickerShaderName);
                if (shader.id) {
                    shaders::TryApplyUniforms(
                        shader,
                        globals::getGlobalShaderUniforms(),
                        stickerShaderName);
                }
            });
            batch.addCustomCommand(makeLocalCommandEmitter(localStickerCommands, /*beforeSprite=*/true, stickerIs3DSkew, stickerShaderName));
            batch.addCustomCommand(makeLocalCommandEmitter(localStickerCommands, /*beforeSprite=*/false, stickerIs3DSkew, stickerShaderName));
            batch.addEndShader();
        }
    }

    // Dedicated text pass: reuse the last active shader (overlay preferred) but
    // force identity atlas uniforms so font atlas sampling stays stable.
    if (drawForeground && hasLocalTextCommands) {
        auto [textShaderName, textInjectAtlas] = selectTextLikeShader();

        if (!textShaderName.empty()) {
            const bool textIs3DSkew = shaderIsPseudo3DSkew(textShaderName);
            batch.addBeginShader(textShaderName);
            batch.addCustomCommand([textShaderName,
                                    textInjectAtlas,
                                    textIs3DSkew,
                                    cardRotation = cardRotationRad,
                                    skewCenter,
                                    skewSize,
                                    tiltEnabled,
                                    applySkewUniforms]() {
                if (textInjectAtlas) {
                    shaders::injectAtlasUniforms(
                        globals::getGlobalShaderUniforms(),
                        textShaderName,
                        Rectangle{0.0f, 0.0f, 1.0f, 1.0f},
                        Vector2{1.0f, 1.0f});
                }
                if (textIs3DSkew) {
                    applySkewUniforms(textShaderName,
                                      Vector2{1.0f, 1.0f},
                                      Vector2{0.0f, 0.0f},
                                      skewCenter,
                                      skewSize,
                                      tiltEnabled ? 1.0f : 0.0f,
                                      cardRotation,
                                      1.0f);
                } else {
                    globals::getGlobalShaderUniforms().set(textShaderName, "card_rotation", cardRotation);
                }
                Shader shader = shaders::getShader(textShaderName);
                if (shader.id) {
                    shaders::TryApplyUniforms(
                        shader,
                        globals::getGlobalShaderUniforms(),
                        textShaderName);
                }
            });

            batch.addCustomCommand(makeLocalCommandEmitter(localTextCommands, /*beforeSprite=*/true, textIs3DSkew, textShaderName));
            batch.addCustomCommand(makeLocalCommandEmitter(localTextCommands, /*beforeSprite=*/false, textIs3DSkew, textShaderName));

            batch.addEndShader();
        }
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
        "Draw command batching for shader pipelines. "
        "Build a DrawCommandBatch in Lua, optionally optimize it, then execute once.";
    rec.record_property("shader_draw_commands", {
        "globalBatch",
        "DrawCommandBatch",
        "Shared batch instance you can reuse instead of allocating each frame."
    });

    // DrawCommandType enum
    sdc["DrawCommandType"] = lua.create_table_with(
        "BeginShader", DrawCommandType::BeginShader,
        "EndShader", DrawCommandType::EndShader,
        "DrawTexture", DrawCommandType::DrawTexture,
        "DrawText", DrawCommandType::DrawText,
        "SetUniforms", DrawCommandType::SetUniforms,
        "Custom", DrawCommandType::Custom
    );
    auto& enumType = rec.add_type("shader_draw_commands.DrawCommandType");
    enumType.doc = "Draw command tags used inside a DrawCommandBatch.";

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
        "addDrawText", &DrawCommandBatch::addDrawText,

        "execute", &DrawCommandBatch::execute,
        "optimize", &DrawCommandBatch::optimize,
        "clear", &DrawCommandBatch::clear,
        "size", &DrawCommandBatch::size,

        "type_id", []() { return entt::type_hash<DrawCommandBatch>::value(); }
    );

    auto& batchType = rec.add_type("shader_draw_commands.DrawCommandBatch", true);
    batchType.doc =
        "Record shader/text draw commands then execute them later as a single batch. "
        "Use beginRecording/endRecording to delimit writes; call optimize to collapse redundant shader changes.";

    // Document methods
    rec.record_method("shader_draw_commands.DrawCommandBatch", {
        "beginRecording",
        "---@param self DrawCommandBatch\n---@return nil",
        "Start recording draw commands into the batch."
    });

    rec.record_method("shader_draw_commands.DrawCommandBatch", {
        "endRecording",
        "---@param self DrawCommandBatch\n---@return nil",
        "Stop recording draw commands."
    });

    rec.record_method("shader_draw_commands.DrawCommandBatch", {
        "recording",
        "---@param self DrawCommandBatch\n---@return boolean",
        "Check if currently recording commands."
    });

    rec.record_method("shader_draw_commands.DrawCommandBatch", {
        "addBeginShader",
        "---@param self DrawCommandBatch\n---@param shaderName string\n---@return nil",
        "Add a command to begin using a shader."
    });

    rec.record_method("shader_draw_commands.DrawCommandBatch", {
        "addEndShader",
        "---@param self DrawCommandBatch\n---@return nil",
        "Add a command to end the current shader."
    });

    rec.record_method("shader_draw_commands.DrawCommandBatch", {
        "addDrawTexture",
        "---@param self DrawCommandBatch\n---@param texture Texture2D\n---@param sourceRect Rectangle\n---@param position Vector2\n---@param tint? Color\n---@return nil",
        "Queue a texture draw using the source rect size at the given position."
    });
    rec.record_method("shader_draw_commands.DrawCommandBatch", {
        "addDrawText",
        "---@param self DrawCommandBatch\n---@param text string\n---@param position Vector2\n---@param fontSize number\n---@param spacing number\n---@param color? Color\n---@param font? Font\n---@return nil",
        "Add a command to draw text."
    });

    rec.record_method("shader_draw_commands.DrawCommandBatch", {
        "addCustomCommand",
        "---@param self DrawCommandBatch\n---@param func fun()\n---@return nil",
        "Add a custom function to be executed inside the batch (runs during render)."
    });

    rec.record_method("shader_draw_commands.DrawCommandBatch", {
        "addSetUniforms",
        "---@param self DrawCommandBatch\n---@param shaderName string\n---@param uniforms ShaderUniformSet\n---@return nil",
        "Apply a ShaderUniformSet to the currently active shader inside the batch."
    });

    rec.record_method("shader_draw_commands.DrawCommandBatch", {
        "execute",
        "---@param self DrawCommandBatch\n---@return nil",
        "Execute all recorded commands in order."
    });

    rec.record_method("shader_draw_commands.DrawCommandBatch", {
        "optimize",
        "---@param self DrawCommandBatch\n---@return nil",
        "Optimize command order to minimize shader state changes."
    });

    rec.record_method("shader_draw_commands.DrawCommandBatch", {
        "clear",
        "---@param self DrawCommandBatch\n---@return nil",
        "Clear all commands from the batch."
    });

    rec.record_method("shader_draw_commands.DrawCommandBatch", {
        "size",
        "---@param self DrawCommandBatch\n---@return integer",
        "Get the number of commands in the batch."
    });

    // Generic helper: add any existing layer command to BatchedLocalCommands (local space, shader-aware)
    sdc.set_function("add_local_command",
        [](entt::registry* registry, entt::entity e, const std::string& type,
           sol::object initFnObj, sol::object zObj, sol::object spaceObj, sol::object forceTextObj, sol::object forceUvPassObj, sol::object forceStickerObj) {
            int z = zObj.is<int>() ? zObj.as<int>() : 0;
            layer::DrawCommandSpace space = layer::DrawCommandSpace::Screen;
            if (spaceObj.is<int>()) {
                int s = spaceObj.as<int>();
                if (s == static_cast<int>(layer::DrawCommandSpace::World)) {
                    space = layer::DrawCommandSpace::World;
                }
            }
            bool forceTextPass = forceTextObj.is<bool>() ? forceTextObj.as<bool>() : false;
            bool forceUvPassthrough = forceUvPassObj.is<bool>() ? forceUvPassObj.as<bool>() : false;
            bool forceStickerPass = forceStickerObj.is<bool>() ? forceStickerObj.as<bool>() : false;
            sol::protected_function initFn;
            if (initFnObj.is<sol::protected_function>()) {
                initFn = initFnObj.as<sol::protected_function>();
            }
            auto callInit = [&](auto* c) {
                if (initFn.valid()) {
                    auto res = initFn(c);
                    if (!res.valid()) {
                        sol::error err = res;
                        SPDLOG_ERROR("add_local_command init error: {}", err.what());
                    }
                }
            };

#define ADD_CMD(name, T)                                                                    \
    if (type == name) {                                                                    \
        AddLocalCommand<T>(*registry, e, z, space, [&](T* c) { callInit(c); }, forceTextPass, forceUvPassthrough, forceStickerPass);            \
        return;                                                                            \
    }

            ADD_CMD("render_ui_slice", layer::CmdRenderUISliceFromDrawList)
            ADD_CMD("render_ui_self_immediate", layer::CmdRenderUISelfImmediate)
            ADD_CMD("begin_scissor", layer::CmdBeginScissorMode)
            ADD_CMD("end_scissor", layer::CmdEndScissorMode)
            ADD_CMD("begin_drawing", layer::CmdBeginDrawing)
            ADD_CMD("end_drawing", layer::CmdEndDrawing)
            ADD_CMD("clear_background", layer::CmdClearBackground)
            ADD_CMD("translate", layer::CmdTranslate)
            ADD_CMD("scale", layer::CmdScale)
            ADD_CMD("rotate", layer::CmdRotate)
            ADD_CMD("add_push", layer::CmdAddPush)
            ADD_CMD("add_pop", layer::CmdAddPop)
            ADD_CMD("push_matrix", layer::CmdPushMatrix)
            ADD_CMD("pop_matrix", layer::CmdPopMatrix)
            ADD_CMD("push_object_transforms", layer::CmdPushObjectTransformsToMatrix)
            ADD_CMD("scoped_transform_composite_render", layer::CmdScopedTransformCompositeRender)
            ADD_CMD("draw_circle", layer::CmdDrawCircleFilled)
            ADD_CMD("draw_circle_line", layer::CmdDrawCircleLine)
            ADD_CMD("draw_rect", layer::CmdDrawRectangle)
            ADD_CMD("draw_rect_pro", layer::CmdDrawRectanglePro)
            ADD_CMD("draw_rect_lines_pro", layer::CmdDrawRectangleLinesPro)
            ADD_CMD("draw_line", layer::CmdDrawLine)
            ADD_CMD("draw_text", layer::CmdDrawText)
            ADD_CMD("draw_text_centered", layer::CmdDrawTextCentered)
            ADD_CMD("text_pro", layer::CmdTextPro)
            ADD_CMD("draw_image", layer::CmdDrawImage)
            ADD_CMD("texture_pro", layer::CmdTexturePro)
            ADD_CMD("draw_entity_animation", layer::CmdDrawEntityAnimation)
            ADD_CMD("draw_transform_entity_animation", layer::CmdDrawTransformEntityAnimation)
            ADD_CMD("draw_transform_entity_animation_pipeline", layer::CmdDrawTransformEntityAnimationPipeline)
            ADD_CMD("set_shader", layer::CmdSetShader)
            ADD_CMD("reset_shader", layer::CmdResetShader)
            ADD_CMD("set_blend_mode", layer::CmdSetBlendMode)
            ADD_CMD("unset_blend_mode", layer::CmdUnsetBlendMode)
            ADD_CMD("send_uniform_float", layer::CmdSendUniformFloat)
            ADD_CMD("send_uniform_int", layer::CmdSendUniformInt)
            ADD_CMD("send_uniform_vec2", layer::CmdSendUniformVec2)
            ADD_CMD("send_uniform_vec3", layer::CmdSendUniformVec3)
            ADD_CMD("send_uniform_vec4", layer::CmdSendUniformVec4)
            ADD_CMD("send_uniform_float_array", layer::CmdSendUniformFloatArray)
            ADD_CMD("send_uniform_int_array", layer::CmdSendUniformIntArray)
            ADD_CMD("vertex", layer::CmdVertex)
            ADD_CMD("begin_gl_mode", layer::CmdBeginOpenGLMode)
            ADD_CMD("end_gl_mode", layer::CmdEndOpenGLMode)
            ADD_CMD("set_color", layer::CmdSetColor)
            ADD_CMD("set_line_width", layer::CmdSetLineWidth)
            ADD_CMD("set_texture", layer::CmdSetTexture)
            ADD_CMD("render_rect_vertices_filled", layer::CmdRenderRectVerticesFilledLayer)
            ADD_CMD("render_rect_vertices_outline", layer::CmdRenderRectVerticesOutlineLayer)
            ADD_CMD("draw_polygon", layer::CmdDrawPolygon)
            ADD_CMD("render_npatch_rect", layer::CmdRenderNPatchRect)
            ADD_CMD("draw_triangle", layer::CmdDrawTriangle)
            ADD_CMD("begin_stencil_mode", layer::CmdBeginStencilMode)
            ADD_CMD("color_mask", layer::CmdColorMask)
            ADD_CMD("stencil_func", layer::CmdStencilFunc)
            ADD_CMD("stencil_op", layer::CmdStencilOp)
            ADD_CMD("render_batch_flush", layer::CmdRenderBatchFlush)
            ADD_CMD("atomic_stencil_mask", layer::CmdAtomicStencilMask)
            ADD_CMD("end_stencil_mode", layer::CmdEndStencilMode)
            ADD_CMD("clear_stencil_buffer", layer::CmdClearStencilBuffer)
            ADD_CMD("begin_stencil_mask", layer::CmdBeginStencilMask)
            ADD_CMD("end_stencil_mask", layer::CmdEndStencilMask)
            ADD_CMD("draw_centered_ellipse", layer::CmdDrawCenteredEllipse)
            ADD_CMD("draw_rounded_line", layer::CmdDrawRoundedLine)
            ADD_CMD("draw_polyline", layer::CmdDrawPolyline)
            ADD_CMD("draw_arc", layer::CmdDrawArc)
            ADD_CMD("draw_triangle_equilateral", layer::CmdDrawTriangleEquilateral)
            ADD_CMD("draw_centered_filled_rounded_rect", layer::CmdDrawCenteredFilledRoundedRect)
            ADD_CMD("draw_sprite_centered", layer::CmdDrawSpriteCentered)
            ADD_CMD("draw_sprite_top_left", layer::CmdDrawSpriteTopLeft)
            ADD_CMD("draw_dashed_circle", layer::CmdDrawDashedCircle)
            ADD_CMD("draw_dashed_rounded_rect", layer::CmdDrawDashedRoundedRect)
            ADD_CMD("draw_dashed_line", layer::CmdDrawDashedLine)
            ADD_CMD("draw_gradient_rect_centered", layer::CmdDrawGradientRectCentered)
            ADD_CMD("draw_gradient_rect_rounded_centered", layer::CmdDrawGradientRectRoundedCentered)
            ADD_CMD("draw_batched_entities", layer::CmdDrawBatchedEntities)
            else {
                SPDLOG_WARN("add_local_command: unsupported type '{}'", type);
            }
#undef ADD_CMD
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
        "add_local_command",
        "---@param registry Registry\n"
        "---@param entity Entity\n"
        "---@param type string @ layer command name (e.g., \"draw_rect\")\n"
        "---@param initFn function|nil @ called with the command instance to fill fields\n"
        "---@param z integer|nil @ z offset (default 0, <0 runs before sprite)\n"
        "---@param space integer|nil @ layer.DrawCommandSpace.World or Screen\n"
        "---@param forceTextPass boolean|nil @ render in text pass even if not a text command\n"
        "---@param forceUvPassthrough boolean|nil @ keep atlas UVs unwarped for 3d_skew\n"
        "---@param forceStickerPass boolean|nil @ render in sticker pass (identity atlas, after overlays)\n"
        "---@return nil",
        "Attach a layer command to BatchedLocalCommands so it renders with the entity's shader pipeline."
    });

    rec.record_free_function({"shader_draw_commands"}, {
        "executeEntityPipelineWithCommands",
        "---@param registry Registry\n"
        "---@param entity Entity\n"
        "---@param batch DrawCommandBatch\n"
        "---@param autoOptimize? boolean\n"
        "---@return nil",
        "Record an entity's shader pipeline into a batch; optionally autoOptimize before execution."
    });

    SPDLOG_INFO("Exposed shader_draw_commands to Lua");
}

} // namespace shader_draw_commands
