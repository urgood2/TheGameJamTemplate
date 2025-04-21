#pragma once

#include "anim_system.hpp"
#include "../core/globals.hpp"
#include "../components/graphics.hpp"
#include "systems/transform/transform_functions.hpp"
#include "systems/shaders/shader_pipeline.hpp"
#include "core/init.hpp"

namespace animation_system {
    
    auto createAnimatedObjectWithTransform (std::string defaultAnimationID, int x, int y) -> entt::entity {
        auto e = globals::registry.create();
        transform::CreateOrEmplace(&globals::registry, globals::gameWorldContainerEntity, x, y, 0, 0, e);
        auto &transform = globals::registry.get<transform::Transform>(e);
        auto &animQueue = globals::registry.emplace<AnimationQueueComponent>(e);
        animQueue.defaultAnimation = init::getAnimationObject(defaultAnimationID);

        auto &gameObject = globals::registry.get<transform::GameObject>(e);
        
        // add pipeline component
        auto &shaderPipeline = globals::registry.emplace<shader_pipeline::ShaderPipelineComponent>(e);
        
        //FIXME: testing
        auto pass = shader_pipeline::createShaderPass("foil", {
            {"u_color", Vector4{1,1,1,1}},
            {"u_time", 0.0f},
            {"u_resolution", Vector2{(float)globals::screenWidth, (float)globals::screenHeight}}
        });
        pass.customPrePassFunction = []() {
            // Custom pre-pass logic here
            // For example, you can set shader uniforms or perform other operations
            // before the shader is activated for this pass.
            // this function is called after the uniforms are applied for the pass
            shaders::TryApplyUniforms(shaders::getShader("foil"), globals::globalShaderUniforms, "foil");
        };
        
        shaderPipeline.passes.push_back(pass);
        
        
        
        // set width and height to the animation size
        transform.setActualW(animQueue.defaultAnimation.animationList.at(0).first.spriteFrame.width);
        transform.setActualH(animQueue.defaultAnimation.animationList.at(0).first.spriteFrame.height);        
        
        return e;
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