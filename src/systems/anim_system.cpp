#pragma once

#include "anim_system.hpp"
#include "../core/globals.hpp"
#include "../components/graphics.hpp"

namespace animation_system {

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