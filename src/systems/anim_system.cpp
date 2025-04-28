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

namespace animation_system {
    
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
    auto createAnimatedObjectWithTransform (std::string defaultAnimationIDorSpriteUUID, bool generateNewAnimFromSprite, int x, int y, std::function<void(entt::entity)> shaderPassConfig) ->  entt::entity {
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
        
        // set width and height to the animation size
        //TODO: optionally provide custom size upon init
        transform.setActualW(animQueue.defaultAnimation.animationList.at(0).first.spriteFrame->frame.width);
        transform.setActualH(animQueue.defaultAnimation.animationList.at(0).first.spriteFrame->frame.height);        
        
        return e;
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