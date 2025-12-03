#pragma once

#include <vector>
#include <string>
#include <map>
#include <memory>
#include <optional>

// #include "tweeny.h"

#include "raylib.h"

// Structure to hold frame data and associated texture
struct FrameData {
    Rectangle frame;
    Texture2D* texture; // Use a pointer to manage multiple textures efficiently
};

namespace globals {
    struct SpriteFrameData;
}

struct SpriteComponentASCII
{
    std::shared_ptr<globals::SpriteFrameData> spriteFrame{}; // coordinates of the sprite on the sprite image

    FrameData spriteData{}; // the sprite data for the sprite TODO: phase out spriteframe and use this instead
    
    int spriteNumber{}; // from assets/graphics/cp437_mappings.json
    
    char charCP437{' '}; // character in CP437
    
    int codepoint_UTF16; // character codepoint in UTF16 format (hex)
    std::string spriteUUID{}; // the UUID of the sprite
    
    Color fgColor{WHITE}, bgColor{BLACK};
    
    bool noBackgroundColor{false}; // if true, don't draw background color
    bool noForegroundColor{false}; // if true, don't overlay foreground color
    
};

struct AnimationObject
{
    std::string uuid{};
    std::string id;
    unsigned int currentAnimIndex{0};
    double currentElapsedTime{0};
    std::vector<std::pair<SpriteComponentASCII, double>> animationList{};
    bool flippedHorizontally{false}; // if true, flip the animation horizontally
    bool flippedVertically{false}; // if true, flip the animation vertically
    std::optional<float> intrinsincRenderScale{std::nullopt}; // the scale of the animation, animation will be scaled relative to the original size if this exists. This serves as a default scale for the animation object.
    std::optional<float> uiRenderScale{std::nullopt}; // this is scaling applied atop the intrinsic render scale. It's used to scale down animations in ui, when ui animations are already scaled down/up based on necessity. Only applied when it exists.
};

/// @brief Any object with this component will be updated by an animationSystem. This object should be attached to any entity which has an animation.
struct AnimationQueueComponent
{
    bool noDraw{false}; // if true, don't draw the animation
    bool drawWithLegacyPipeline{true}; // if false, skip DrawTransformEntityWithAnimationWithPipeline
    bool enabled{true};
    AnimationObject defaultAnimation{}; //  if this does not exist, and the queue is empty/completed, the entity's SpriteComponentASCII will be used
    std::vector<AnimationObject> animationQueue{}; // a queue of animations to play.
    std::map<int, std::string> fgColorOverwriteMap{}; // a map of color overwrites to apply to the animation object when playing the animation. Only applied if a color exists for the current animation index.
    int currentAnimationIndex{0}; // the index of the current animation in the queue.
    std::function<void()> onAnimationQueueCompleteCallback{}; // a callback to call when the animation queue is completed
    bool useCallbackOnAnimationQueueComplete{false}; // if true, the callback will be called when the animation queue is completed
};

/// @brief Any object with this component will be updated by a locationTweeningSystem. The actual location will be kept in the location component, but this component will be used for rendering (for movement animations)
struct TweenedLocationComponent 
{
    // tweeny::tween<double, double> locationTween{}; 
};
