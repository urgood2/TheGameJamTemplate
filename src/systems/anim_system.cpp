#pragma once

#include <string>
#include <vector>
#include <tuple>
#include <optional>

#include "anim_system.hpp"
#include "../core/globals.hpp"
#include "../components/graphics.hpp"
#include "systems/transform/transform_functions.hpp"
#include "systems/shaders/shader_pipeline.hpp"
#include "systems/uuid/uuid.hpp"
#include "core/init.hpp"

#include "sol/sol.hpp"

namespace animation_system {

    auto exposeToLua(sol::state &lua) -> void {
        // 1) Ensure the top‐level table
        sol::table anim = lua.create_named_table("animation_system");

        // 2) Bind each free function
        anim.set_function("update", &animation_system::update);

        // returns (NPatchInfo, Texture2D)
        anim.set_function("getNinepatchUIBorderInfo", &animation_system::getNinepatchUIBorderInfo);

        // full‐signature binding; Lua will need to pass all args or use nil for defaults
        anim.set_function("createAnimatedObjectWithTransform",
            &animation_system::createAnimatedObjectWithTransform);

        // convenience still‐animation factory
        anim.set_function("createStillAnimationFromSpriteUUID",
            &animation_system::createStillAnimationFromSpriteUUID);

        // resizing helpers
        anim.set_function("resizeAnimationObjectsInEntityToFit",
            &animation_system::resizeAnimationObjectsInEntityToFit);
        anim.set_function("resizeAnimationObjectsInEntityToFitAndCenterUI",
            &animation_system::resizeAnimationObjectsInEntityToFitAndCenterUI);
        anim.set_function("resetAnimationUIRenderScale",
            &animation_system::resetAnimationUIRenderScale);
        anim.set_function("resizeAnimationObjectToFit",
            &animation_system::resizeAnimationObjectToFit);
    }
    
    auto createStillAnimationFromSpriteUUID(std::string spriteUUID, std::optional<Color> fg, std::optional<Color> bg) -> AnimationObject {
        
        constexpr float DEFAULT_DURATION = 5.0f;
        
        AnimationObject ao = {};
        
        ao.id = "PROGRAM_GENERATED_ANIMATION";
        ao.uuid = "PROGRAM_GENERATED_ANIMATION";
        ao.currentAnimIndex = 0;
        
        SpriteComponentASCII frame{};
        if (!bg)
        {
            frame.noBackgroundColor = true;
        }
        else
        {
            frame.bgColor = bg.value();
        }

        if (!fg)
        {
            // frame.noForegroundColor = false;
            frame.fgColor = WHITE; // just retain original sprite color
        }
        else
        {
            frame.fgColor = fg.value();
        }

        frame.fgColor = fg.value_or(WHITE);
        frame.bgColor = bg.value_or(BLANK);
        frame.spriteUUID = uuid::add(spriteUUID);
        // using namespace snowhouse;
        // AssertThat(::init::getSpriteFrame(frame.spriteUUID).frame.width, IsGreaterThan(0));
        frame.spriteData.frame = init::getSpriteFrame(frame.spriteUUID).frame;
        //TODO: need to load in the atlas to the texturemap
        auto atlasUUID = init::getSpriteFrame(frame.spriteUUID).atlasUUID;
        frame.spriteData.texture = &globals::textureAtlasMap.at(atlasUUID);
        frame.spriteFrame = std::make_shared<globals::SpriteFrameData>(init::getSpriteFrame(frame.spriteUUID));

        ao.animationList.emplace_back(frame, DEFAULT_DURATION);
        
        return ao;
    }
    
    /*
        for generateNewAnimFromSprite, please set only to true if the provided uuid is not for an animation (animations.json), but for a sprite from the sprite sheet
    */
    auto createAnimatedObjectWithTransform (std::string defaultAnimationIDorSpriteUUID, bool generateNewAnimFromSprite, int x, int y, std::function<void(entt::entity)> shaderPassConfig, bool shadowEnabled) ->  entt::entity {
        auto e = globals::registry.create();
        transform::CreateOrEmplace(&globals::registry, globals::gameWorldContainerEntity, x, y, 0, 0, e);
        auto &transform = globals::registry.get<transform::Transform>(e);
        auto &animQueue = globals::registry.emplace<AnimationQueueComponent>(e);
        if (generateNewAnimFromSprite) {
            // create a new animation object from the sprite UUID
            animQueue.defaultAnimation = createStillAnimationFromSpriteUUID(defaultAnimationIDorSpriteUUID, std::nullopt, std::nullopt);
        }
        else {
            // use the default animation object
            animQueue.defaultAnimation = init::getAnimationObject(defaultAnimationIDorSpriteUUID);
        }

        auto &gameObject = globals::registry.get<transform::GameObject>(e);

        if (!shadowEnabled) {
            gameObject.shadowDisplacement.reset();
        }
        
        // set width and height to the animation size
        //TODO: optionally provide custom size upon init
        transform.setActualW(animQueue.defaultAnimation.animationList.at(0).first.spriteFrame->frame.width);
        transform.setActualH(animQueue.defaultAnimation.animationList.at(0).first.spriteFrame->frame.height); 
        
        if (shaderPassConfig)
            shaderPassConfig(e); // pass the entity to the shader pass config function
        
        return e;
    }
    
    auto resizeAnimationObjectsInEntityToFit(entt::entity e, float targetWidth, float targetHeight) -> void {
        auto &animQueue = globals::registry.get<AnimationQueueComponent>(e);
        auto &transform = globals::registry.get<transform::Transform>(e);
        
        // get the scale factor which will fit the target width and height
        float scaleX = targetWidth / transform.getActualW();
        float scaleY = targetHeight / transform.getActualH();
        float scale = std::min(scaleX, scaleY);
        transform.setActualW(transform.getActualW() * scale);
        transform.setActualH(transform.getActualH() * scale);
        
        // apply the scale to the animation objects
        for (auto &animObject : animQueue.animationQueue) {
            animObject.intrinsincRenderScale = scale;
        }
        if (!animQueue.defaultAnimation.animationList.empty()) {
            animQueue.defaultAnimation.intrinsincRenderScale = scale;
        }
    }
    
    void resetAnimationUIRenderScale(entt::entity e) {
        if (!globals::registry.any_of<AnimationQueueComponent>(e)) {
            return;
        }
        auto &animQueue = globals::registry.get<AnimationQueueComponent>(e);
        for (auto &animObject : animQueue.animationQueue) {
            animObject.uiRenderScale = 1.0f;
        }
        if (!animQueue.defaultAnimation.animationList.empty()) {
            animQueue.defaultAnimation.uiRenderScale = 1.0f;
        }
        
        // calc intrinsic size, set to transform
        auto &transform = globals::registry.get<transform::Transform>(e);
        auto &role = globals::registry.get<transform::InheritedProperties>(e);
        auto &firstFrame = animQueue.defaultAnimation.animationList.at(0).first;
        float rawWidth = firstFrame.spriteFrame->frame.width;
        float rawHeight = firstFrame.spriteFrame->frame.height;
        float intrinsicScale = animQueue.defaultAnimation.intrinsincRenderScale.value_or(1.0f);
        float effectiveWidth = rawWidth * intrinsicScale;
        float effectiveHeight = rawHeight * intrinsicScale;
        transform.setActualW(effectiveWidth);
        transform.setActualH(effectiveHeight);
        role.offset->x = 0.0f;
        role.offset->y = 0.0f;
        SPDLOG_DEBUG("Reset entity {} | raw: ({}, {}) | intrinsic: {} | uiScale: {} | final: ({}, {})",
                    static_cast<int>(e), rawWidth, rawHeight, intrinsicScale, 1.0f, effectiveWidth, effectiveHeight);
    }
    
    // utilizes ui render scale to resize the animation objects
    // uses default animation object for size calculations
    void resizeAnimationObjectsInEntityToFitAndCenterUI(entt::entity e, float targetWidth, float targetHeight, bool centerLaterally, bool centerVertically)
    {
        auto &animQueue = globals::registry.get<AnimationQueueComponent>(e);
        auto &transform = globals::registry.get<transform::Transform>(e);
        auto &role = globals::registry.get<transform::InheritedProperties>(e);

        using namespace snowhouse;
        AssertThat(animQueue.defaultAnimation.animationList.size(), IsGreaterThan(0));

        const auto &firstFrame = animQueue.defaultAnimation.animationList.at(0).first;
        float rawWidth = firstFrame.spriteFrame->frame.width;
        float rawHeight = firstFrame.spriteFrame->frame.height;

        // Use intrinsic scale if available
        float intrinsicScale = animQueue.defaultAnimation.intrinsincRenderScale.value_or(1.0f);
        float effectiveWidth = rawWidth * intrinsicScale;
        float effectiveHeight = rawHeight * intrinsicScale;

        // Calculate the scale needed to fit within target size
        float scaleX = targetWidth / effectiveWidth;
        float scaleY = targetHeight / effectiveHeight;
        float uiScale = std::min(scaleX, scaleY);

        float finalW = effectiveWidth * uiScale;
        float finalH = effectiveHeight * uiScale;

        // Apply to transform
        transform.setActualW(finalW);
        transform.setActualH(finalH);

        SPDLOG_DEBUG("UI Resize entity {} | raw: ({}, {}) | intrinsic: {} | uiScale: {} | final: ({}, {})",
                    static_cast<int>(e), rawWidth, rawHeight, intrinsicScale, uiScale, finalW, finalH);

        // Apply only uiRenderScale
        for (auto &animObject : animQueue.animationQueue) {
            animObject.uiRenderScale = uiScale;
        }
        if (!animQueue.defaultAnimation.animationList.empty()) {
            animQueue.defaultAnimation.uiRenderScale = uiScale;
        }

        // Optional centering
        role.offset->x = centerLaterally ? (targetWidth - finalW) / 2.0f : 0.0f;
        role.offset->y = centerVertically ? (targetHeight - finalH) / 2.0f : 0.0f;
    }

    
    // resizes all animation objects in the queue to fit the target width and height
    // Note that this assumes the animation frames are all the same size
    auto resizeAnimationObjectToFit(AnimationObject &animObj, float targetWidth, float targetHeight) -> void {
        
        float scaleX = 1.0f;
        float scaleY = 1.0f;
        
        // assert the animation list is not empty
        using namespace snowhouse;
        AssertThat(animObj.animationList.size(), IsGreaterThan(0));
        
        // get the scale factor which will fit the target width and height
        scaleX = targetWidth / animObj.animationList.at(animObj.currentAnimIndex).first.spriteFrame->frame.width;
        scaleY = targetHeight / animObj.animationList.at(animObj.currentAnimIndex).first.spriteFrame->frame.height;
        float scale = std::min(scaleX, scaleY);
        animObj.intrinsincRenderScale = scale;
        
    }
    
    // assumes classic 9 patch layout (9 patches, 4 corners, 4 edges, 1 center)
    auto getNinepatchUIBorderInfo(std::string uuid_or_raw_identifier) -> std::tuple<NPatchInfo, Texture2D> {
        
        // get id, use it to fetch the source rect and texture
        
        NPatchInfo nPatchInfo = {};
        auto frame = init::getSpriteFrame(uuid_or_raw_identifier);
        
        nPatchInfo.source = frame.frame;
        
        // always assume the texture has 4 pixels at the centers for stretch
        nPatchInfo.left = nPatchInfo.source.width * 0.5f - 2;
        nPatchInfo.top = nPatchInfo.source.height * 0.5f - 2;
        nPatchInfo.right = nPatchInfo.source.width * 0.5f - 2;
        nPatchInfo.bottom = nPatchInfo.source.height * 0.5f - 2;
        nPatchInfo.layout = NPatchLayout::NPATCH_NINE_PATCH; // classic 9 patch layout
        
        return std::make_tuple(nPatchInfo, globals::textureAtlasMap.at(frame.atlasUUID));
    }

    auto update(float delta) -> void {
        ZoneScopedN("Update animation system");
        auto view = globals::registry.view<AnimationQueueComponent>();
    
        for (auto &e : view) {
            auto &ac = globals::registry.get<AnimationQueueComponent>(e);
    
            // only update if enabled
            if (!ac.enabled) {
                continue;
            }
    
            if (ac.animationQueue.empty() && 
                ac.useCallbackOnAnimationQueueComplete && 
                ac.onAnimationQueueCompleteCallback) {
    
                ac.onAnimationQueueCompleteCallback();
                continue;
            }
            else if (ac.animationQueue.empty()) {
                ac.defaultAnimation.currentElapsedTime += delta;
    
                if (ac.defaultAnimation.currentElapsedTime > ac.defaultAnimation.animationList.at(ac.defaultAnimation.currentAnimIndex).second) {
                    ac.defaultAnimation.currentAnimIndex = (++ac.defaultAnimation.currentAnimIndex % ac.defaultAnimation.animationList.size());
                    ac.defaultAnimation.currentElapsedTime = 0;
                }
            }
            else {
                if (ac.currentAnimationIndex >= ac.animationQueue.size()) {
                    ac.currentAnimationIndex = 0;
                }
    
                auto &currentAnimation = ac.animationQueue.at(ac.currentAnimationIndex);
    
                // Update the current animation
                currentAnimation.currentElapsedTime += delta;
    
                if (currentAnimation.currentElapsedTime > currentAnimation.animationList.at(currentAnimation.currentAnimIndex).second) {
                    if (currentAnimation.currentAnimIndex >= currentAnimation.animationList.size() - 1) {
                        // The current animation has completed
                        if (ac.currentAnimationIndex + 1 < ac.animationQueue.size()) {
                            // Move to the next animation in the queue
                            ac.currentAnimationIndex++;
                            // Reset the next animation's state
                            ac.animationQueue.at(ac.currentAnimationIndex).currentAnimIndex = 0;
                            ac.animationQueue.at(ac.currentAnimationIndex).currentElapsedTime = 0;
                        } else {
                            // All animations in the queue have completed
                            ac.animationQueue.clear();
                            ac.currentAnimationIndex = 0;
                            // Optionally, invoke the callback here if all animations completed
                            if (ac.useCallbackOnAnimationQueueComplete && ac.onAnimationQueueCompleteCallback) {
                                ac.onAnimationQueueCompleteCallback();
                            }
                        }
                    } else {
                        // Move to the next frame in the current animation
                        currentAnimation.currentAnimIndex++;
                        currentAnimation.currentElapsedTime = 0;
                    }
                }
            }
        }
    
    }
}