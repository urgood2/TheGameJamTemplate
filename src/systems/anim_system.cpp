#pragma once

#include <optional>
#include <string>
#include <tuple>
#include <vector>

#include "../components/graphics.hpp"
#include "../core/engine_context.hpp"
#include "../core/globals.hpp"
#include "anim_system.hpp"
#include "core/init.hpp"
#include "systems/shaders/shader_pipeline.hpp"
#include "systems/transform/transform_functions.hpp"
#include "systems/uuid/uuid.hpp"

#include "spdlog/spdlog.h"

#include "systems/scripting/binding_recorder.hpp"

#include "sol/sol.hpp"

namespace animation_system {

static Texture2D *resolveAtlasTexture(const std::string &atlasUUID) {
  return getAtlasTexture(atlasUUID);
}

void setHorizontalFlip(entt::entity e, bool flip) {
  if (!globals::getRegistry().any_of<AnimationQueueComponent>(e))
    return;

  auto &animQueue = globals::getRegistry().get<AnimationQueueComponent>(e);

  // Apply to default animation
  animQueue.defaultAnimation.flippedHorizontally = flip;

  // Apply to all animations in the queue
  for (auto &animObj : animQueue.animationQueue)
    animObj.flippedHorizontally = flip;
}

void flipAnimation(entt::entity e, bool horizontal, bool vertical) {
  if (!globals::getRegistry().any_of<AnimationQueueComponent>(e))
    return;

  auto &animQueue = globals::getRegistry().get<AnimationQueueComponent>(e);

  // flip default animation
  animQueue.defaultAnimation.flippedHorizontally = horizontal;
  animQueue.defaultAnimation.flippedVertically = vertical;

  // also apply to any queued animations
  for (auto &animObj : animQueue.animationQueue) {
    animObj.flippedHorizontally = horizontal;
    animObj.flippedVertically = vertical;
  }
}

void setAnimationFlip(entt::entity e, bool flipH, bool flipV) {
  flipAnimation(e, flipH, flipV);
}

void toggleAnimationFlip(entt::entity e) {
  if (!globals::getRegistry().any_of<AnimationQueueComponent>(e))
    return;
  auto &animQueue = globals::getRegistry().get<AnimationQueueComponent>(e);
  auto &anim = animQueue.defaultAnimation;
  anim.flippedHorizontally = !anim.flippedHorizontally;
}

auto exposeToLua(sol::state &lua) -> void {

  auto &rec = BindingRecorder::instance();

  // 1) Create the top‐level animation_system table
  sol::table anim = lua.create_named_table("animation_system");
  // Emit: local animation_system = {}
  rec.add_type("animation_system").doc = "Animation system functions";

  lua.new_usertype<AnimationQueueComponent>(
      "AnimationQueueComponent", "noDraw", &AnimationQueueComponent::noDraw,
      "drawWithLegacyPipeline",
      &AnimationQueueComponent::drawWithLegacyPipeline,
      "type_id",
      []() { return entt::type_hash<AnimationQueueComponent>::value(); });

  // 2) Bind & record free functions under animation_system

  rec.bind_function(lua, {"animation_system"}, "set_horizontal_flip",
                    &animation_system::setHorizontalFlip,
                    "---@param e entt.entity # Target entity\n"
                    "---@param flip boolean # Whether to flip horizontally\n"
                    "---@return nil\n"
                    "Flips all animations for the entity horizontally");

  // update(dt: number) -> nil
  rec.bind_function(lua, {"animation_system"}, "update",
                    &animation_system::update,
                    "---@param dt number # Delta time in seconds\n"
                    "---@return nil",
                    "Advances all animations by dt");

  // getNinepatchUIBorderInfo(uuid: string) -> NPatchInfo, Texture2D
  rec.bind_function(lua, {"animation_system"}, "getNinepatchUIBorderInfo",
                    &animation_system::getNinepatchUIBorderInfo,
                    "---@param uuid_or_raw_identifier string # N-patch "
                    "identifier or raw key\n"
                    "---@return NPatchInfo info # Border slicing information\n"
                    "---@return Texture2D texture # Associated texture",
                    "Returns nine-patch border info and texture");

  rec.bind_function(
      lua, {"animation_system"}, "setFGColorForAllAnimationObjects",
      &animation_system::setFGColorForAllAnimationObjects,
      "---@param e entt.entity # Target entity\n"
      "---@param fgColor Color # Foreground color to set\n"
      "---@return nil",
      "Sets the foreground color for all animation objects in an entity");

  // createAnimatedObjectWithTransform(defaultAnimationIDOrSpriteUUID: string,
  // generateNewAnimFromSprite?: boolean, x?: number, y?: number,
  // shaderPassConfigFunc?: fun(entt.entity), shadowEnabled?: boolean) ->
  // entt.entity

  rec.bind_function(
      lua, {"animation_system"}, "createAnimatedObjectWithTransform",
      // wrapper lambda to coerce Lua numbers → C++ ints and apply defaults
      [](const std::string &defaultAnimationIDOrSpriteUUID,
         sol::optional<bool> generateNewAnimFromSprite, sol::optional<double> x,
         sol::optional<double> y,
         sol::optional<std::function<void(entt::entity)>> shaderPassConfigFunc,
         sol::optional<bool> shadowEnabled) -> entt::entity {
        return animation_system::createAnimatedObjectWithTransform(
            defaultAnimationIDOrSpriteUUID,
            generateNewAnimFromSprite.value_or(false),
            static_cast<int>(x.value_or(0.0)), // force integer
            static_cast<int>(y.value_or(0.0)), // force integer
            shaderPassConfigFunc.value_or(nullptr),
            shadowEnabled.value_or(true));
      },
      "---@param defaultAnimationIDOrSpriteUUID string # Animation ID or "
      "sprite UUID\n"
      "---@param generateNewAnimFromSprite boolean? # Create a new anim from "
      "sprite? Default false\n"
      "---@param x number? # Initial X position. Default 0\n"
      "---@param y number? # Initial Y position. Default 0\n"
      "---@param shaderPassConfigFunc fun(entt_entity: entt.entity)? # "
      "Optional shader setup callback\n"
      "---@param shadowEnabled boolean? # Enable shadow? Default true\n"
      "---@return entt.entity entity # Created animation entity",
      "Creates an animated object with a transform");

  rec.bind_function(
      lua, {"animation_system"}, "replaceAnimatedObjectOnEntity",
      // wrapper lambda to apply defaults
      [](entt::entity entity, const std::string &defaultAnimationIDOrSpriteUUID,
         sol::optional<bool> generateNewAnimFromSprite,
         sol::optional<std::function<void(entt::entity)>> shaderPassConfigFunc,
         sol::optional<bool> shadowEnabled) -> void {
        animation_system::replaceAnimatedObjectOnEntity(
            entity, defaultAnimationIDOrSpriteUUID,
            generateNewAnimFromSprite.value_or(false),
            shaderPassConfigFunc.value_or(nullptr),
            shadowEnabled.value_or(true));
      },
      // Updated doc-comments:
      "---@param e entt.entity                                             # "
      "Entity to replace animated object on\n"
      "---@param defaultAnimationIDOrSpriteUUID string                      # "
      "Animation ID or sprite UUID\n"
      "---@param generateNewAnimFromSprite boolean?                         # "
      "Regenerate animation from sprite? Default false\n"
      "---@param shaderPassConfigFunc fun(entt_entity: entt.entity)?        # "
      "Optional shader pass configuration callback\n"
      "---@param shadowEnabled boolean?                                    # "
      "Enable shadow? Default true\n"
      "---@return entt.entity                                             # "
      "Entity whose animated object was replaced",
      "Replaces the animated object on an entity, optionally regenerating it "
      "from a sprite UUID and applying shader‐pass & shadow settings");

  // setupAnimatedObjectOnEntity(
  //    e: entt.entity,
  //    defaultAnimationIDOrSpriteUUID: string,
  //    generateNewAnimFromSprite?: boolean,
  //    shaderPassConfigFunc?: fun(entt_entity: entt.entity),
  //    shadowEnabled?: boolean
  // ) -> void
  rec.bind_function(
      lua, {"animation_system"}, "setupAnimatedObjectOnEntity",
      &animation_system::setupAnimatedObjectOnEntity,
      R"lua(
        ---@param e entt.entity                        # The existing entity to configure
        ---@param defaultAnimationIDOrSpriteUUID string # Animation ID or sprite UUID
        ---@param generateNewAnimFromSprite boolean?    # Create a new anim from sprite? Default false
        ---@param shaderPassConfigFunc fun(entt.entity)? # Optional shader setup callback
        ---@param shadowEnabled boolean?                # Enable shadow? Default true
        ---@return nil
        )lua",
      "Configures an existing entity with Transform, AnimationQueueComponent, "
      "and optional shader‐pass + shadow settings");

  rec.bind_function(
      lua, {"animation_system"}, "set_flip",
      &animation_system::setAnimationFlip,
      "---@param e entt.entity\n"
      "---@param flipH boolean\n"
      "---@param flipV boolean\n"
      "---@return nil\n"
      "Sets the horizontal/vertical flip flags on all animations of an entity");

  rec.bind_function(
      lua, {"animation_system"}, "toggle_flip",
      &animation_system::toggleAnimationFlip,
      "---@param e entt.entity\n"
      "---@return nil\n"
      "Toggles horizontal flip for the entity's current animation");

  // createStillAnimationFromSpriteUUID(spriteUUID: string, fg?: Color, bg?:
  // Color) -> AnimationObject
  rec.bind_function(
      lua, {"animation_system"}, "createStillAnimationFromSpriteUUID",
      &animation_system::createStillAnimationFromSpriteUUID,
      "---@param spriteUUID string # Sprite UUID to use\n"
      "---@param fg Color? # Optional foreground tint\n"
      "---@param bg Color? # Optional background tint\n"
      "---@return AnimationObject animObj # New still animation object",
      "Creates a still animation from a sprite UUID");

  // resizeAnimationObjectsInEntityToFit(e: entt.entity, targetWidth: number,
  // targetHeight: number) -> nil
  rec.bind_function(lua, {"animation_system"},
                    "resizeAnimationObjectsInEntityToFit",
                    &animation_system::resizeAnimationObjectsInEntityToFit,
                    "---@param e entt.entity # Target entity\n"
                    "---@param targetWidth number # Desired width\n"
                    "---@param targetHeight number # Desired height\n"
                    "---@return nil",
                    "Resizes all animation objects in an entity to fit");

  // resizeAnimationObjectsInEntityToFitAndCenterUI(e: entt.entity, targetWidth:
  // number, targetHeight: number, centerLaterally?: boolean, centerVertically?:
  // boolean) -> nil
  rec.bind_function(
      lua, {"animation_system"},
      "resizeAnimationObjectsInEntityToFitAndCenterUI",
      &animation_system::resizeAnimationObjectsInEntityToFitAndCenterUI,
      "---@param e entt.entity # Target entity\n"
      "---@param targetWidth number # Desired width\n"
      "---@param targetHeight number # Desired height\n"
      "---@param centerLaterally boolean? # Center horizontally? Default true\n"
      "---@param centerVertically boolean? # Center vertically? Default true\n"
      "---@return nil",
      "Resizes and centers all animation objects in an entity");

  // resetAnimationUIRenderScale(e: entt.entity) -> nil
  rec.bind_function(lua, {"animation_system"}, "resetAnimationUIRenderScale",
                    &animation_system::resetAnimationUIRenderScale,
                    "---@param e entt.entity # Target entity\n"
                    "---@return nil",
                    "Resets UI render scale for an entity’s animations");

  // resizeAnimationObjectToFit(animObj: AnimationObject, targetWidth: number,
  // targetHeight: number) -> nil
  rec.bind_function(
      lua, {"animation_system"}, "resizeAnimationObjectToFit",
      &animation_system::resizeAnimationObjectToFit,
      "---@param animObj AnimationObject # Animation object reference\n"
      "---@param targetWidth number # Desired width\n"
      "---@param targetHeight number # Desired height\n"
      "---@return nil",
      "Resizes a single animation object to fit");

  rec.bind_function(
      lua, {"animation_system"}, "getCurrentFrame",
      &animation_system::getCurrentFrame,
      "---@param e entt.entity # Target entity\n"
      "---@return number frame # Current frame index",
      "Gets the current frame index of the active animation");

  rec.bind_function(
      lua, {"animation_system"}, "getFrameCount",
      &animation_system::getFrameCount,
      "---@param e entt.entity # Target entity\n"
      "---@return number count # Total frame count",
      "Gets the total number of frames in the active animation");

  rec.bind_function(
      lua, {"animation_system"}, "isPlaying",
      &animation_system::isPlaying,
      "---@param e entt.entity # Target entity\n"
      "---@return boolean playing # True if animation is playing",
      "Checks if the animation is currently playing");

  rec.bind_function(
      lua, {"animation_system"}, "getProgress",
      &animation_system::getProgress,
      "---@param e entt.entity # Target entity\n"
      "---@return number progress # Progress from 0.0 to 1.0",
      "Gets the progress of the current animation (0.0 to 1.0)");

  rec.bind_function(
      lua, {"animation_system"}, "play",
      &animation_system::playAnimation,
      "---@param e entt.entity # Target entity\n"
      "---@return nil",
      "Starts or resumes the animation");

  rec.bind_function(
      lua, {"animation_system"}, "pause",
      &animation_system::pauseAnimation,
      "---@param e entt.entity # Target entity\n"
      "---@return nil",
      "Pauses the animation at the current frame");

  rec.bind_function(
      lua, {"animation_system"}, "stop",
      &animation_system::stopAnimation,
      "---@param e entt.entity # Target entity\n"
      "---@return nil",
      "Stops the animation and resets to frame 0");

  rec.bind_function(
      lua, {"animation_system"}, "setSpeed",
      &animation_system::setAnimationSpeed,
      "---@param e entt.entity # Target entity\n"
      "---@param speed number # Speed multiplier (1.0 = normal)\n"
      "---@return nil",
      "Sets the animation playback speed multiplier");

  rec.bind_function(
      lua, {"animation_system"}, "seekFrame",
      &animation_system::seekAnimationFrame,
      "---@param e entt.entity # Target entity\n"
      "---@param frame number # Frame index to seek to\n"
      "---@return nil",
      "Seeks to a specific frame in the animation");

  lua.new_enum<PlaybackDirection>(
      "PlaybackDirection",
      {
          {"Forward", PlaybackDirection::Forward},
          {"Reverse", PlaybackDirection::Reverse},
          {"Pingpong", PlaybackDirection::Pingpong},
          {"PingpongReverse", PlaybackDirection::PingpongReverse}
      }
  );

  rec.bind_function(
      lua, {"animation_system"}, "setDirection",
      &animation_system::setPlaybackDirection,
      "---@param e entt.entity # Target entity\n"
      "---@param direction PlaybackDirection # Playback direction\n"
      "---@return nil",
      "Sets the playback direction (Forward, Reverse, Pingpong, PingpongReverse)");

  rec.bind_function(
      lua, {"animation_system"}, "setLoopCount",
      &animation_system::setLoopCount,
      "---@param e entt.entity # Target entity\n"
      "---@param loopCount number # Number of loops (-1 = infinite, 0 = play once)\n"
      "---@return nil",
      "Sets the number of times the animation should loop");

  rec.bind_function(
      lua, {"animation_system"}, "onFrameChange",
      &animation_system::setOnFrameChange,
      "---@param e entt.entity # Target entity\n"
      "---@param callback fun(oldFrame: number, newFrame: number) # Callback function\n"
      "---@return nil",
      "Sets callback fired when animation frame changes");

  rec.bind_function(
      lua, {"animation_system"}, "onLoopComplete",
      &animation_system::setOnLoopComplete,
      "---@param e entt.entity # Target entity\n"
      "---@param callback fun(loopCount: number) # Callback with current loop count\n"
      "---@return nil",
      "Sets callback fired when animation completes a loop");

  rec.bind_function(
      lua, {"animation_system"}, "onAnimationEnd",
      &animation_system::setOnAnimationEnd,
      "---@param e entt.entity # Target entity\n"
      "---@param callback fun() # Callback function\n"
      "---@return nil",
      "Sets callback fired when animation ends (loopCount reached)");

  rec.bind_function(
      lua, {"animation_system"}, "clearCallbacks",
      &animation_system::clearAnimationCallbacks,
      "---@param e entt.entity # Target entity\n"
      "---@return nil",
      "Clears all animation callbacks for the entity");
}

auto createStillAnimationFromSpriteUUID(std::string spriteUUID,
                                        std::optional<Color> fg,
                                        std::optional<Color> bg)
    -> AnimationObject {

  constexpr float DEFAULT_DURATION = 5.0f;

  AnimationObject ao = {};

  ao.id = "PROGRAM_GENERATED_ANIMATION";
  ao.uuid = "PROGRAM_GENERATED_ANIMATION";
  ao.currentAnimIndex = 0;

  SpriteComponentASCII frame{};
  if (!bg) {
    frame.noBackgroundColor = true;
  } else {
    frame.bgColor = bg.value();
  }

  if (!fg) {
    // frame.noForegroundColor = false;
    frame.fgColor = WHITE; // just retain original sprite color
  } else {
    frame.fgColor = fg.value();
  }

  frame.fgColor = fg.value_or(WHITE);
  frame.bgColor = bg.value_or(BLANK);
  frame.spriteUUID = uuid::add(spriteUUID);
  // using namespace snowhouse;
  // AssertThat(::init::getSpriteFrame(frame.spriteUUID).frame.width,
  // IsGreaterThan(0));
  const auto spriteFrameData =
      init::getSpriteFrame(frame.spriteUUID, globals::g_ctx);
  frame.spriteData.frame = spriteFrameData.frame;
  // TODO: need to load in the atlas to the texturemap
  auto atlasUUID = spriteFrameData.atlasUUID;
  frame.spriteData.texture = resolveAtlasTexture(atlasUUID);
  if (frame.spriteData.texture == nullptr) {
    SPDLOG_ERROR("Texture atlas '{}' not found for sprite '{}'", atlasUUID,
                 spriteUUID);
  }
  frame.spriteFrame =
      std::make_shared<globals::SpriteFrameData>(spriteFrameData);

  ao.animationList.emplace_back(frame, DEFAULT_DURATION);

  return ao;
}

/*
    for generateNewAnimFromSprite, please set only to true if the provided uuid
   is not for an animation (animations.json), but for a sprite from the sprite
   sheet
*/
auto createAnimatedObjectWithTransform(
    std::string defaultAnimationIDorSpriteUUID, bool generateNewAnimFromSprite,
    int x, int y, std::function<void(entt::entity)> shaderPassConfig,
    bool shadowEnabled) -> entt::entity {
  auto e = globals::getRegistry().create();
  transform::CreateOrEmplace(&globals::getRegistry(),
                             globals::getGameWorldContainer(), x, y, 0, 0, e);
  auto &transform = globals::getRegistry().get<transform::Transform>(e);
  auto &animQueue = globals::getRegistry().emplace<AnimationQueueComponent>(e);
  if (generateNewAnimFromSprite) {
    // create a new animation object from the sprite UUID
    animQueue.defaultAnimation = createStillAnimationFromSpriteUUID(
        defaultAnimationIDorSpriteUUID, std::nullopt, std::nullopt);
  } else {
    // use the default animation object
    animQueue.defaultAnimation =
        init::getAnimationObject(defaultAnimationIDorSpriteUUID);
  }

  auto &gameObject = globals::getRegistry().get<transform::GameObject>(e);

  if (!shadowEnabled) {
    gameObject.shadowDisplacement.reset();
  }

  // set width and height to the animation size
  // TODO: optionally provide custom size upon init
  if (!animQueue.defaultAnimation.animationList.empty()) {
    const auto& firstFrame = animQueue.defaultAnimation.animationList.front().first;
    transform.setActualW(firstFrame.spriteFrame->frame.width);
    transform.setActualH(firstFrame.spriteFrame->frame.height);
  } else {
    SPDLOG_WARN("createAnimatedObjectWithTransform: empty animation list for entity {}", static_cast<int>(e));
    transform.setActualW(1);  // Fallback to minimal valid dimensions
    transform.setActualH(1);
  }

  if (shaderPassConfig)
    shaderPassConfig(e); // pass the entity to the shader pass config function

  return e;
}

auto replaceAnimatedObjectOnEntity(
    entt::entity e, std::string defaultAnimationIDorSpriteUUID,
    bool generateNewAnimFromSprite,
    std::function<void(entt::entity)> shaderPassConfig, bool shadowEnabled)
    -> void {
  // --- ASSUME: `e` already has a transform::Transform attached ---
  auto &registry = globals::getRegistry();
  auto &animQueue = globals::getRegistry().get<AnimationQueueComponent>(e);
  auto &gameObject = registry.get<transform::GameObject>(e);
  auto &transform = registry.get<transform::Transform>(e);

  // 0) remember how big this entity *really* is right now:
  auto storedW = transform.getActualW();
  auto storedH = transform.getActualH();

  // 1) swap in the new animation
  if (generateNewAnimFromSprite) {
    animQueue.defaultAnimation = createStillAnimationFromSpriteUUID(
        defaultAnimationIDorSpriteUUID, std::nullopt, std::nullopt);
  } else {
    animQueue.defaultAnimation =
        init::getAnimationObject(defaultAnimationIDorSpriteUUID);
  }
  // 4) size the transform to match the first frame
  if (!animQueue.defaultAnimation.animationList.empty()) {
    const auto &firstFrame =
        animQueue.defaultAnimation.animationList.front().first.spriteFrame->frame;
    transform.setActualW(firstFrame.width);
    transform.setActualH(firstFrame.height);
  } else {
    SPDLOG_WARN("replaceAnimatedObjectOnEntity: empty animation list for entity {}", static_cast<int>(e));
    transform.setActualW(1);  // Fallback to minimal valid dimensions
    transform.setActualH(1);
  }

  // transform.setActualW(newW);
  // transform.setActualH(newH);

  if (shaderPassConfig)
    shaderPassConfig(e); // pass the entity to the shader pass config function

  if (!shadowEnabled) {
    gameObject.shadowDisplacement.reset();
  }
}

auto setupAnimatedObjectOnEntity(
    entt::entity e, std::string defaultAnimationIDorSpriteUUID,
    bool generateNewAnimFromSprite,
    std::function<void(entt::entity)> shaderPassConfig, bool shadowEnabled)
    -> void {
  // --- ASSUME: `e` already has a transform::Transform attached ---
  auto &registry = globals::getRegistry();
  auto &transform = registry.get<transform::Transform>(e);

  // 1) attach animation queue
  auto &animQueue = registry.emplace_or_replace<AnimationQueueComponent>(e);

  if (generateNewAnimFromSprite) {
    animQueue.defaultAnimation = createStillAnimationFromSpriteUUID(
        defaultAnimationIDorSpriteUUID, std::nullopt, std::nullopt);
  } else {
    animQueue.defaultAnimation =
        init::getAnimationObject(defaultAnimationIDorSpriteUUID);
  }

  // 2) grab the GameObject (should already exist via your Transform→GameObject
  // mapping)
  auto &gameObject = registry.get<transform::GameObject>(e);

  // 3) optionally disable shadow
  if (!shadowEnabled) {
    gameObject.shadowDisplacement.reset();
  }

  // 4) size the transform to match the first frame
  if (!animQueue.defaultAnimation.animationList.empty()) {
    const auto &firstFrame =
        animQueue.defaultAnimation.animationList.front().first.spriteFrame->frame;
    transform.setActualW(firstFrame.width);
    transform.setActualH(firstFrame.height);
  } else {
    SPDLOG_WARN("setupAnimatedObjectOnEntity: empty animation list for entity {}", static_cast<int>(e));
    transform.setActualW(1);
    transform.setActualH(1);
  }

  // 5) run any custom shader‐pass config
  if (shaderPassConfig) {
    shaderPassConfig(e);
  }
}

auto resizeAnimationObjectsInEntityToFit(entt::entity e, float targetWidth,
                                         float targetHeight) -> void {
  auto &animQueue = globals::getRegistry().get<AnimationQueueComponent>(e);
  auto &transform = globals::getRegistry().get<transform::Transform>(e);

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

auto setFGColorForAllAnimationObjects(entt::entity e, Color fgColor) -> void {
  auto &animQueue = globals::getRegistry().get<AnimationQueueComponent>(e);

  // set the foreground color for all animation objects
  for (auto &animObject : animQueue.animationQueue) {
    for (auto &frame : animObject.animationList) {
      frame.first.fgColor = fgColor;
    }
  }

  // also set the default animation's frames
  for (auto &frame : animQueue.defaultAnimation.animationList) {
    frame.first.fgColor = fgColor;
  }
}

void resetAnimationUIRenderScale(entt::entity e) {
  if (!globals::getRegistry().any_of<AnimationQueueComponent>(e)) {
    return;
  }
  auto &animQueue = globals::getRegistry().get<AnimationQueueComponent>(e);
  for (auto &animObject : animQueue.animationQueue) {
    animObject.uiRenderScale = 1.0f;
  }
  if (!animQueue.defaultAnimation.animationList.empty()) {
    animQueue.defaultAnimation.uiRenderScale = 1.0f;
  }

  // calc intrinsic size, set to transform
  auto &transform = globals::getRegistry().get<transform::Transform>(e);
  auto &role = globals::getRegistry().get<transform::InheritedProperties>(e);

  // Guard: ensure default animation has frames
  if (animQueue.defaultAnimation.animationList.empty()) {
    SPDLOG_WARN("resetAnimationUIRenderScale: empty animation list for entity {}", static_cast<int>(e));
    return;
  }

  auto &firstFrame = animQueue.defaultAnimation.animationList.front().first;
  float rawWidth = firstFrame.spriteFrame->frame.width;
  float rawHeight = firstFrame.spriteFrame->frame.height;
  float intrinsicScale =
      animQueue.defaultAnimation.intrinsincRenderScale.value_or(1.0f);
  float effectiveWidth = rawWidth * intrinsicScale;
  float effectiveHeight = rawHeight * intrinsicScale;
  transform.setActualW(effectiveWidth);
  transform.setActualH(effectiveHeight);
  role.offset->x = 0.0f;
  role.offset->y = 0.0f;
  SPDLOG_DEBUG("Reset entity {} | raw: ({}, {}) | intrinsic: {} | uiScale: {} "
               "| final: ({}, {})",
               static_cast<int>(e), rawWidth, rawHeight, intrinsicScale, 1.0f,
               effectiveWidth, effectiveHeight);
}

// utilizes ui render scale to resize the animation objects
// uses default animation object for size calculations
void resizeAnimationObjectsInEntityToFitAndCenterUI(entt::entity e,
                                                    float targetWidth,
                                                    float targetHeight,
                                                    bool centerLaterally,
                                                    bool centerVertically) {
  auto &animQueue = globals::getRegistry().get<AnimationQueueComponent>(e);
  auto &transform = globals::getRegistry().get<transform::Transform>(e);
  auto &role = globals::getRegistry().get<transform::InheritedProperties>(e);

  // Runtime guard (assertions removed in release builds)
  if (animQueue.defaultAnimation.animationList.empty()) {
    SPDLOG_ERROR("resizeAnimationObjectsInEntityToFitAndCenterUI: empty animation list for entity {}", static_cast<int>(e));
    return;
  }

  const auto &firstFrame = animQueue.defaultAnimation.animationList.front().first;
  float rawWidth = firstFrame.spriteFrame->frame.width;
  float rawHeight = firstFrame.spriteFrame->frame.height;

  // Use intrinsic scale if available
  float intrinsicScale =
      animQueue.defaultAnimation.intrinsincRenderScale.value_or(1.0f);
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

  SPDLOG_DEBUG("UI Resize entity {} | raw: ({}, {}) | intrinsic: {} | uiScale: "
               "{} | final: ({}, {})",
               static_cast<int>(e), rawWidth, rawHeight, intrinsicScale,
               uiScale, finalW, finalH);

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
auto resizeAnimationObjectToFit(AnimationObject &animObj, float targetWidth,
                                float targetHeight) -> void {

  float scaleX = 1.0f;
  float scaleY = 1.0f;

  // Runtime guard (assertions removed in release builds)
  if (animObj.animationList.empty() ||
      animObj.currentAnimIndex >= animObj.animationList.size()) {
    SPDLOG_WARN("resizeAnimationObjectToFit: invalid animation state");
    return;
  }

  // get the scale factor which will fit the target width and height
  const auto& currentFrame = animObj.animationList[animObj.currentAnimIndex].first;
  scaleX = targetWidth / currentFrame.spriteFrame->frame.width;
  scaleY = targetHeight / currentFrame.spriteFrame->frame.height;
  float scale = std::min(scaleX, scaleY);
  animObj.intrinsincRenderScale = scale;
}

// assumes classic 9 patch layout (9 patches, 4 corners, 4 edges, 1 center)
auto getNinepatchUIBorderInfo(std::string uuid_or_raw_identifier)
    -> std::tuple<NPatchInfo, Texture2D> {

  // get id, use it to fetch the source rect and texture

  NPatchInfo nPatchInfo = {};
  auto frame = init::getSpriteFrame(uuid_or_raw_identifier, globals::g_ctx);

  nPatchInfo.source = frame.frame;

  // always assume the texture has 4 pixels at the centers for stretch
  nPatchInfo.left = nPatchInfo.source.width * 0.5f - 2;
  nPatchInfo.top = nPatchInfo.source.height * 0.5f - 2;
  nPatchInfo.right = nPatchInfo.source.width * 0.5f - 2;
  nPatchInfo.bottom = nPatchInfo.source.height * 0.5f - 2;
  nPatchInfo.layout = NPatchLayout::NPATCH_NINE_PATCH; // classic 9 patch layout

  Texture2D *texture = resolveAtlasTexture(frame.atlasUUID);

  if (texture == nullptr || texture->id == 0) {
    SPDLOG_ERROR("Texture atlas '{}' not found for nine-patch '{}'",
                 frame.atlasUUID, uuid_or_raw_identifier);
  }

  return std::make_tuple(nPatchInfo, texture ? *texture : Texture2D{});
}

namespace {
AnimationObject* getActiveAnimation(entt::entity e) {
  auto& registry = globals::getRegistry();
  if (!registry.valid(e) || !registry.all_of<AnimationQueueComponent>(e)) {
    return nullptr;
  }
  auto& ac = registry.get<AnimationQueueComponent>(e);
  if (!ac.animationQueue.empty() && ac.currentAnimationIndex < ac.animationQueue.size()) {
    return &ac.animationQueue[ac.currentAnimationIndex];
  }
  if (!ac.defaultAnimation.animationList.empty()) {
    return &ac.defaultAnimation;
  }
  return nullptr;
}
}

auto getCurrentFrame(entt::entity e) -> unsigned int {
  auto* anim = getActiveAnimation(e);
  return anim ? anim->currentAnimIndex : 0;
}

auto getFrameCount(entt::entity e) -> size_t {
  auto* anim = getActiveAnimation(e);
  return anim ? anim->animationList.size() : 0;
}

auto isPlaying(entt::entity e) -> bool {
  auto* anim = getActiveAnimation(e);
  return anim && !anim->paused && anim->speedMultiplier > 0.0f;
}

auto getProgress(entt::entity e) -> float {
  auto* anim = getActiveAnimation(e);
  if (!anim || anim->animationList.empty()) return 0.0f;
  return static_cast<float>(anim->currentAnimIndex) / static_cast<float>(anim->animationList.size());
}

auto playAnimation(entt::entity e) -> void {
  auto* anim = getActiveAnimation(e);
  if (anim) {
    anim->paused = false;
    if (anim->speedMultiplier <= 0.0f) {
      anim->speedMultiplier = 1.0f;
    }
  }
}

auto pauseAnimation(entt::entity e) -> void {
  auto* anim = getActiveAnimation(e);
  if (anim) {
    anim->paused = true;
  }
}

auto stopAnimation(entt::entity e) -> void {
  auto* anim = getActiveAnimation(e);
  if (anim) {
    anim->paused = true;
    anim->currentAnimIndex = 0;
    anim->currentElapsedTime = 0;
    anim->currentLoopCount = 0;
    anim->pingpongReversing = false;
  }
}

auto setAnimationSpeed(entt::entity e, float speed) -> void {
  auto* anim = getActiveAnimation(e);
  if (anim) {
    anim->speedMultiplier = std::max(0.0f, speed);
  }
}

auto seekAnimationFrame(entt::entity e, unsigned int frame) -> void {
  auto* anim = getActiveAnimation(e);
  if (anim && !anim->animationList.empty()) {
    anim->currentAnimIndex = std::min(frame, static_cast<unsigned int>(anim->animationList.size() - 1));
    anim->currentElapsedTime = 0;
  }
}

auto setPlaybackDirection(entt::entity e, PlaybackDirection direction) -> void {
  auto* anim = getActiveAnimation(e);
  if (anim) {
    anim->playbackDirection = direction;
    if (direction == PlaybackDirection::Reverse || direction == PlaybackDirection::PingpongReverse) {
      if (anim->currentAnimIndex == 0 && !anim->animationList.empty()) {
        anim->currentAnimIndex = static_cast<unsigned int>(anim->animationList.size() - 1);
      }
      if (direction == PlaybackDirection::PingpongReverse) {
        anim->pingpongReversing = true;
      }
    }
  }
}

auto setLoopCount(entt::entity e, int loopCount) -> void {
  auto* anim = getActiveAnimation(e);
  if (anim) {
    anim->loopCount = loopCount;
    anim->currentLoopCount = 0;
  }
}

auto setOnFrameChange(entt::entity e, std::function<void(unsigned int, unsigned int)> callback) -> void {
  auto* anim = getActiveAnimation(e);
  if (anim) {
    anim->onFrameChange = std::move(callback);
  }
}

auto setOnLoopComplete(entt::entity e, std::function<void(int)> callback) -> void {
  auto* anim = getActiveAnimation(e);
  if (anim) {
    anim->onLoopComplete = std::move(callback);
  }
}

auto setOnAnimationEnd(entt::entity e, std::function<void()> callback) -> void {
  auto* anim = getActiveAnimation(e);
  if (anim) {
    anim->onAnimationEnd = std::move(callback);
  }
}

auto clearAnimationCallbacks(entt::entity e) -> void {
  auto* anim = getActiveAnimation(e);
  if (anim) {
    anim->onFrameChange = nullptr;
    anim->onLoopComplete = nullptr;
    anim->onAnimationEnd = nullptr;
  }
}

auto update(float delta) -> void {
  ZONE_SCOPED("Update animation system");
  auto view = globals::getRegistry().view<AnimationQueueComponent>();

  for (auto &e : view) {
    auto &ac = globals::getRegistry().get<AnimationQueueComponent>(e);

    // only update if enabled
    if (!ac.enabled) {
      continue;
    }

    if (ac.animationQueue.empty() && ac.useCallbackOnAnimationQueueComplete &&
        ac.onAnimationQueueCompleteCallback) {

      ac.onAnimationQueueCompleteCallback();
      continue;
    } else if (ac.animationQueue.empty()) {
      if (ac.defaultAnimation.animationList.empty()) {
        continue;
      }
      
      if (ac.defaultAnimation.paused) {
        continue;
      }
      
      if (ac.defaultAnimation.currentAnimIndex >= ac.defaultAnimation.animationList.size()) {
        ac.defaultAnimation.currentAnimIndex = 0;
      }
      
      float effectiveSpeed = std::max(0.0f, ac.defaultAnimation.speedMultiplier);
      if (effectiveSpeed == 0.0f) {
        continue;
      }
      
      ac.defaultAnimation.currentElapsedTime += delta * effectiveSpeed;

      if (ac.defaultAnimation.currentElapsedTime >
          ac.defaultAnimation.animationList[ac.defaultAnimation.currentAnimIndex].second) {
        
        auto& anim = ac.defaultAnimation;
        size_t frameCount = anim.animationList.size();
        unsigned int oldIndex = anim.currentAnimIndex;
        anim.currentElapsedTime = 0;
        bool loopCompleted = false;
        bool animationEnded = false;
        
        switch (anim.playbackDirection) {
          case PlaybackDirection::Forward:
            anim.currentAnimIndex = (anim.currentAnimIndex + 1) % frameCount;
            if (anim.currentAnimIndex == 0) {
              loopCompleted = true;
              if (anim.loopCount >= 0) {
                anim.currentLoopCount++;
                if (anim.currentLoopCount > anim.loopCount) {
                  anim.paused = true;
                  anim.currentAnimIndex = oldIndex;
                  animationEnded = true;
                }
              }
            }
            break;
            
          case PlaybackDirection::Reverse:
            if (anim.currentAnimIndex == 0) {
              anim.currentAnimIndex = static_cast<unsigned int>(frameCount - 1);
              loopCompleted = true;
              if (anim.loopCount >= 0) {
                anim.currentLoopCount++;
                if (anim.currentLoopCount > anim.loopCount) {
                  anim.paused = true;
                  anim.currentAnimIndex = 0;
                  animationEnded = true;
                }
              }
            } else {
              anim.currentAnimIndex--;
            }
            break;
            
          case PlaybackDirection::Pingpong:
            if (!anim.pingpongReversing) {
              if (anim.currentAnimIndex >= frameCount - 1) {
                anim.pingpongReversing = true;
                if (frameCount > 1) anim.currentAnimIndex--;
              } else {
                anim.currentAnimIndex++;
              }
            } else {
              if (anim.currentAnimIndex == 0) {
                anim.pingpongReversing = false;
                loopCompleted = true;
                if (anim.loopCount >= 0) {
                  anim.currentLoopCount++;
                  if (anim.currentLoopCount > anim.loopCount) {
                    anim.paused = true;
                    animationEnded = true;
                  }
                }
                if (!anim.paused && frameCount > 1) anim.currentAnimIndex++;
              } else {
                anim.currentAnimIndex--;
              }
            }
            break;
            
          case PlaybackDirection::PingpongReverse:
            if (anim.pingpongReversing) {
              if (anim.currentAnimIndex == 0) {
                anim.pingpongReversing = false;
                if (frameCount > 1) anim.currentAnimIndex++;
              } else {
                anim.currentAnimIndex--;
              }
            } else {
              if (anim.currentAnimIndex >= frameCount - 1) {
                anim.pingpongReversing = true;
                loopCompleted = true;
                if (anim.loopCount >= 0) {
                  anim.currentLoopCount++;
                  if (anim.currentLoopCount > anim.loopCount) {
                    anim.paused = true;
                    animationEnded = true;
                  }
                }
                if (!anim.paused && frameCount > 1) anim.currentAnimIndex--;
              } else {
                anim.currentAnimIndex++;
              }
            }
            break;
        }
        
        if (anim.currentAnimIndex != oldIndex && anim.onFrameChange) {
          anim.onFrameChange(oldIndex, anim.currentAnimIndex);
        }
        if (loopCompleted && anim.onLoopComplete) {
          anim.onLoopComplete(anim.currentLoopCount);
        }
        if (animationEnded && anim.onAnimationEnd) {
          anim.onAnimationEnd();
        }
      }
    } else {
      if (ac.currentAnimationIndex >= ac.animationQueue.size()) {
        ac.currentAnimationIndex = 0;
      }

      auto &currentAnimation = ac.animationQueue[ac.currentAnimationIndex];
      
      if (currentAnimation.paused) {
        continue;
      }

      if (currentAnimation.animationList.empty() ||
          currentAnimation.currentAnimIndex >= currentAnimation.animationList.size()) {
        continue;
      }
      
      float effectiveSpeed = std::max(0.0f, currentAnimation.speedMultiplier);
      if (effectiveSpeed == 0.0f) {
        continue;
      }

      currentAnimation.currentElapsedTime += delta * effectiveSpeed;

      if (currentAnimation.currentElapsedTime >
          currentAnimation.animationList[currentAnimation.currentAnimIndex].second) {
        
        auto& anim = currentAnimation;
        size_t frameCount = anim.animationList.size();
        unsigned int oldIndex = anim.currentAnimIndex;
        anim.currentElapsedTime = 0;
        
        bool loopCompleted = false;
        bool animationEnded = false;
        
        switch (anim.playbackDirection) {
          case PlaybackDirection::Forward:
            anim.currentAnimIndex = (anim.currentAnimIndex + 1) % frameCount;
            if (anim.currentAnimIndex == 0) {
              loopCompleted = true;
              if (anim.loopCount >= 0) {
                anim.currentLoopCount++;
                if (anim.currentLoopCount > anim.loopCount) {
                  anim.paused = true;
                  anim.currentAnimIndex = oldIndex;
                  animationEnded = true;
                }
              }
            }
            break;
            
          case PlaybackDirection::Reverse:
            if (anim.currentAnimIndex == 0) {
              anim.currentAnimIndex = static_cast<unsigned int>(frameCount - 1);
              loopCompleted = true;
              if (anim.loopCount >= 0) {
                anim.currentLoopCount++;
                if (anim.currentLoopCount > anim.loopCount) {
                  anim.paused = true;
                  anim.currentAnimIndex = 0;
                  animationEnded = true;
                }
              }
            } else {
              anim.currentAnimIndex--;
            }
            break;
            
          case PlaybackDirection::Pingpong:
            if (!anim.pingpongReversing) {
              if (anim.currentAnimIndex >= frameCount - 1) {
                anim.pingpongReversing = true;
                if (frameCount > 1) anim.currentAnimIndex--;
              } else {
                anim.currentAnimIndex++;
              }
            } else {
              if (anim.currentAnimIndex == 0) {
                anim.pingpongReversing = false;
                loopCompleted = true;
                if (anim.loopCount >= 0) {
                  anim.currentLoopCount++;
                  if (anim.currentLoopCount > anim.loopCount) {
                    anim.paused = true;
                    animationEnded = true;
                  }
                }
                if (!anim.paused && frameCount > 1) anim.currentAnimIndex++;
              } else {
                anim.currentAnimIndex--;
              }
            }
            break;
            
          case PlaybackDirection::PingpongReverse:
            if (anim.pingpongReversing) {
              if (anim.currentAnimIndex == 0) {
                anim.pingpongReversing = false;
                if (frameCount > 1) anim.currentAnimIndex++;
              } else {
                anim.currentAnimIndex--;
              }
            } else {
              if (anim.currentAnimIndex >= frameCount - 1) {
                anim.pingpongReversing = true;
                loopCompleted = true;
                if (anim.loopCount >= 0) {
                  anim.currentLoopCount++;
                  if (anim.currentLoopCount > anim.loopCount) {
                    anim.paused = true;
                    animationEnded = true;
                  }
                }
                if (!anim.paused && frameCount > 1) anim.currentAnimIndex--;
              } else {
                anim.currentAnimIndex++;
              }
            }
            break;
        }
        
        if (anim.currentAnimIndex != oldIndex && anim.onFrameChange) {
          anim.onFrameChange(oldIndex, anim.currentAnimIndex);
        }
        if (loopCompleted && anim.onLoopComplete) {
          anim.onLoopComplete(anim.currentLoopCount);
        }
        if (animationEnded && anim.onAnimationEnd) {
          anim.onAnimationEnd();
        }
        
        if (animationEnded) {
          if (ac.currentAnimationIndex + 1 < ac.animationQueue.size()) {
            ac.currentAnimationIndex++;
            ac.animationQueue[ac.currentAnimationIndex].currentAnimIndex = 0;
            ac.animationQueue[ac.currentAnimationIndex].currentElapsedTime = 0;
          } else {
            ac.animationQueue.clear();
            ac.currentAnimationIndex = 0;
            if (ac.useCallbackOnAnimationQueueComplete &&
                ac.onAnimationQueueCompleteCallback) {
              ac.onAnimationQueueCompleteCallback();
            }
          }
        }
      }
    }
  }
}
} // namespace animation_system
