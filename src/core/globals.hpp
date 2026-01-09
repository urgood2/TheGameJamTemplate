#pragma once

/**
 * @file globals.hpp
 * @brief Legacy global state kept for compatibility while migrating to EngineContext.
 *
 * Most entries mirror fields inside EngineContext; new code should prefer the
 * context and treat these globals as a temporary bridge during refactors.
 */
#include "../core/gui.hpp"
#include "../third_party/rlImGui/rlImGui.h" // raylib imGUI binding
#include "entt/entt.hpp"                    // ECS
#include "raylib.h"                         // raylib

/// @cond DOXYGEN_SHOULD_SKIP_THIS
#if defined(_WIN32)
#define NOGDI  // All GDI defines and routines
// NOUSER intentionally omitted so Win32 clipboard/user APIs stay available
#endif

#define SPDLOG_ACTIVE_LEVEL SPDLOG_LEVEL_DEBUG // compiler-time log level

#include "spdlog/sinks/basic_file_sink.h"
#include "spdlog/spdlog.h" // SPD logging lib // or any library that uses Windows.h

#include "effolkronium/random.hpp" // https://github.com/effolkronium/random

// #include "behaviortree_cpp_v3/bt_factory.h" //
// https://github.com/BehaviorTree/BehaviorTree.CPP/tree/v3.8/

#include "../components/graphics.hpp"

#include "../systems/anim_system.hpp"
#include "../systems/collision/Quadtree.h"
#include "../systems/localization/localization.hpp"
#include "event_bus.hpp"

#include "third_party/rlImGui/imgui.h" // raylib imGUI binding

#include "gui.hpp"

#ifndef JSON_DIAGNOSTICS
#define JSON_DIAGNOSTICS 1
#endif
/// @endcond
#include <fmt/core.h>        // https://github.com/fmtlib/fmt
#include <nlohmann/json.hpp> // nlohmann JSON parsing
// #include <boost/algorithm/string.hpp> // boost string
// #include <boost/tokenizer.hpp>        // string tokenizer

#include <cassert>
#include <cmath>
#include <fstream>
#include <functional>
#include <iostream>
#include <map>
#include <memory>
#include <optional>
#include <regex>
#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>

#include "sol/sol.hpp"

using std::string, std::unique_ptr, std::vector;
using namespace std::literals;
// using namespace BT;
using json = nlohmann::json;
using Random =
    effolkronium::random_static; // get base random alias which is auto seeded
                                 // and has static API and internal state

/// @cond DOXYGEN_SHOULD_SKIP_THIS
#if defined(ENGINECTX_DEPRECATE_GLOBALS) && !defined(__DOXYGEN__)
#define ENGINECTX_DEPRECATED(msg) [[deprecated(msg)]]
#else
#define ENGINECTX_DEPRECATED(msg)
#endif
/// @endcond

class EngineContext;

// Keep track of game state
enum class GameState { MAIN_MENU, LOADING_SCREEN, MAIN_GAME, GAME_OVER };

namespace input {
struct InputState;
}

namespace transform {
struct MasterCacheEntry;
struct SpringCacheBundle;
} // namespace transform

namespace shaders {
struct ShaderUniformComponent;
}

namespace layer {
struct Layer;
}

class PhysicsManager;

namespace globals {
// Bridge pointer to the new EngineContext (incremental migration).
extern ::EngineContext *g_ctx;
void setEngineContext(::EngineContext *ctx);

/// @cond LEGACY_ENGINECTX_GLOBALS
ENGINECTX_DEPRECATED(
    "Access EngineContext::inputState instead of globals::getInputState()")
[[nodiscard]] input::InputState &getInputState();

[[nodiscard]] extern Vector2 GetScaledMousePosition();
[[nodiscard]] extern Vector2 getScaledMousePositionCached();

// Virtual design resolution (like SNKRX)
extern const int VIRTUAL_WIDTH;
extern const int VIRTUAL_HEIGHT; // steam deck resolution

extern float
    finalRenderScale; // the final render scale to apply when drawing to the
                      // screen, updated each frame, letterbox adjusted
extern float finalLetterboxOffsetX;
extern float finalLetterboxOffsetY;
ENGINECTX_DEPRECATED("Access EngineContext::finalRenderScale instead of "
                     "globals::getFinalRenderScale()")
[[nodiscard]] float &getFinalRenderScale();
ENGINECTX_DEPRECATED("Access EngineContext::finalLetterboxOffsetX instead of "
                     "globals::getLetterboxOffsetX()")
[[nodiscard]] float &getLetterboxOffsetX();
ENGINECTX_DEPRECATED("Access EngineContext::finalLetterboxOffsetY instead of "
                     "globals::getLetterboxOffsetY()")
[[nodiscard]] float &getLetterboxOffsetY();
void setFinalRenderScale(float v);
void setLetterboxOffsetX(float v);
void setLetterboxOffsetY(float v);

extern bool useImGUI; // set to true to use imGUI for debugging
ENGINECTX_DEPRECATED(
    "Access EngineContext::useImGUI instead of globals::getUseImGUI()")
[[nodiscard]] bool &getUseImGUI();
void setUseImGUI(bool v);

extern std::shared_ptr<PhysicsManager>
    physicsManager; // physics manager instance
ENGINECTX_DEPRECATED("Access EngineContext::physicsManager instead of "
                     "globals::getPhysicsManagerPtr()")
[[nodiscard]] std::shared_ptr<PhysicsManager> &getPhysicsManagerPtr();
ENGINECTX_DEPRECATED("Access EngineContext::physicsManager instead of "
                     "globals::getPhysicsManager()")
[[nodiscard]] PhysicsManager *getPhysicsManager();

extern std::unordered_map<entt::entity, transform::SpringCacheBundle>
    g_springCache;

extern std::unordered_map<entt::entity, transform::MasterCacheEntry>
    getMasterCacheEntityToParentCompMap;

extern float globalUIScaleFactor; // scale factor for UI elements
ENGINECTX_DEPRECATED("Access EngineContext::globalUIScaleFactor instead of "
                     "globals::getGlobalUIScaleFactor()")
[[nodiscard]] float &getGlobalUIScaleFactor();
void setGlobalUIScaleFactor(float v);

extern bool drawDebugInfo,
    drawPhysicsDebug; // set to true to allow debug drawing of transforms
ENGINECTX_DEPRECATED("Access EngineContext::drawDebugInfo instead of "
                     "globals::getDrawDebugInfo()")
[[nodiscard]] bool &getDrawDebugInfo();
ENGINECTX_DEPRECATED("Access EngineContext::drawPhysicsDebug instead of "
                     "globals::getDrawPhysicsDebug()")
[[nodiscard]] bool &getDrawPhysicsDebug();
void setDrawDebugInfo(bool v);
void setDrawPhysicsDebug(bool v);

extern const float
    UI_PROGRESS_BAR_INSET_PIXELS; // inset for progress bar fill (the portion
                                  // that fills the bar)

extern shaders::ShaderUniformComponent
    globalShaderUniforms; // keep track of shader uniforms;
ENGINECTX_DEPRECATED("Access EngineContext::shaderUniforms instead of "
                     "globals::getGlobalShaderUniforms()")
[[nodiscard]] shaders::ShaderUniformComponent &getGlobalShaderUniforms();

extern GameState currentGameState;
ENGINECTX_DEPRECATED("Access EngineContext::currentGameState instead of "
                     "globals::getCurrentGameState()")
[[nodiscard]] GameState &getCurrentGameState();

//---------------------------------------------------------
// constants
extern int screenWidth, screenHeight;
extern int gameWorldViewportWidth, gameWorldViewportHeight;
extern const float FONT_SIZE;
extern string gameTitle;
ENGINECTX_DEPRECATED(
    "Access EngineContext sizes instead of globals::getScreenWidth()")
[[nodiscard]] int &getScreenWidth();
ENGINECTX_DEPRECATED(
    "Access EngineContext sizes instead of globals::getScreenHeight()")
[[nodiscard]] int &getScreenHeight();
ENGINECTX_DEPRECATED("Access EngineContext sizes instead of "
                     "globals::getGameWorldViewportWidth()")
[[nodiscard]] int &getGameWorldViewportWidth();
ENGINECTX_DEPRECATED("Access EngineContext sizes instead of "
                     "globals::getGameWorldViewportHeight()")
[[nodiscard]] int &getGameWorldViewportHeight();

//---------------------------------------------------------
// imGUI variables
extern bool debugRenderWindowShowing;

// collision detection
// Function to get the bounding box of an entity
extern std::function<quadtree::Box<float>(entt::entity)> getBoxWorld;
extern std::function<quadtree::Box<float>(entt::entity)> getBoxUI;

// Define the world bounds for the quadtree
extern quadtree::Box<float> worldBounds, uiBounds;

// Quadtree instance for collision detection
extern quadtree::Quadtree<entt::entity, decltype(getBoxWorld)> quadtreeWorld;
extern quadtree::Quadtree<entt::entity, decltype(getBoxUI)> quadtreeUI;

//---------------------------------------------------------
// variables

ENGINECTX_DEPRECATED("Access EngineContext::enemies instead of globals::enemies")
extern vector<entt::entity> enemies;

// keep track of execution step name during world gen (also for loading screen)
extern string worldGenCurrentStep;

// these must be in context throughout main loop. Used for multithreading
// loading

// Keep track of loading messages
extern std::map<int, std::string> loadingStages;

// current loading message index
extern int loadingStateIndex;

// store loaded animation data mapped to animation id
extern std::map<std::string, AnimationObject> animationsMap;
[[nodiscard]] std::map<std::string, AnimationObject> &getAnimationsMap();

// show mouse current status
extern bool isMouseDragStarted;

// keep track of mouse dragging coords (start and end)
extern Vector2 mouseDragStartedCoords, mouseDragEndedCoords;

extern bool showObserverWindow;

extern int worldWidth, worldHeight;
[[nodiscard]] int &getWorldWidth();
[[nodiscard]] int &getWorldHeight();

// font for the ui (IMGUI)
extern ImFont *uiFont12;

// Texture onto which game world is drawn
extern RenderTexture gameWorldViewPort;

// world map (2d grid - maybe make into 3d later?)
extern vector<vector<entt::entity>> map;

// for pathfinding version of map
extern vector<double> pathfindingMatrix;
[[nodiscard]] std::vector<double> &getPathfindingMatrix();

ENGINECTX_DEPRECATED("Access EngineContext::clickedEntity instead of globals::clickedEntity")
extern entt::entity clickedEntity;

// JSON configuration files - actively used
extern json colorsJSON, uiStringsJSON, animationsJSON, aiConfigJSON,
    aiActionsJSON, aiWorldstateJSON, ninePatchJSON;

// Deprecated JSON blobs - unused legacy data, will be removed in future version
[[deprecated("activityJSON is unused - remove reference")]]
extern json activityJSON;
[[deprecated("environmentJSON is unused - remove reference")]]
extern json environmentJSON;
[[deprecated("floraJSON is unused - remove reference")]]
extern json floraJSON;
[[deprecated("humanJSON is unused - remove reference")]]
extern json humanJSON;
[[deprecated("levelsJSON is unused - remove reference")]]
extern json levelsJSON;
[[deprecated("materialsJSON is unused - remove reference")]]
extern json materialsJSON;
[[deprecated("worldGenJSON is unused - remove reference")]]
extern json worldGenJSON;
[[deprecated("muscleJSON is unused - remove reference")]]
extern json muscleJSON;
[[deprecated("timeJSON is unused - remove reference")]]
extern json timeJSON;
[[deprecated("behaviorTreeConfigJSON is unused - remove reference")]]
extern json behaviorTreeConfigJSON;
[[deprecated("levelCurvesJSON is unused - remove reference")]]
extern json levelCurvesJSON;
[[deprecated("namegenJSON is unused - remove reference")]]
extern json namegenJSON;
[[deprecated("professionJSON is unused - remove reference")]]
extern json professionJSON;
[[deprecated("particleEffectsJSON is unused - remove reference")]]
extern json particleEffectsJSON;
[[deprecated("itemsJSON is unused - remove reference")]]
extern json itemsJSON;
[[deprecated("combatActionToStateJSON is unused - remove reference")]]
extern json combatActionToStateJSON;
[[deprecated("combatAttackWoundsJSON is unused - remove reference")]]
extern json combatAttackWoundsJSON;
[[deprecated("combatAvailableActionsByStateJSON is unused - remove reference")]]
extern json combatAvailableActionsByStateJSON;
[[deprecated("objectsJSON is unused - remove reference")]]
extern json objectsJSON;

extern json miniJamCardsJSON, miniJamEnemiesJSON;

// thesaurus (english)
extern json thesaurusJSON; // https://github.com/zaibacu/thesaurusb

// sprite data
extern json spritesJSON, cp437MappingsJSON;

// Global vector to hold all loaded textures
extern std::map<string, Texture2D> textureAtlasMap;
[[nodiscard]] std::map<std::string, Texture2D> &getTextureAtlasMap();

// game config
extern json configJSON;
[[nodiscard]] json &getConfigJson();
[[nodiscard]] json &getColorsJson();
[[nodiscard]] json &getUiStringsJson();
[[nodiscard]] json &getAnimationsJson();
[[nodiscard]] json &getAiConfigJson();
[[nodiscard]] json &getAiActionsJson();
[[nodiscard]] json &getAiWorldstateJson();
[[nodiscard]] json &getNinePatchJson();

// game camera
// extern Camera2D camera;
extern float cameraDamping, cameraStiffness;
extern Vector2 cameraVelocity;
extern Vector2
    nextCameraTarget; // keep track of desired next camera target position
ENGINECTX_DEPRECATED("Access EngineContext::cameraDamping instead of "
                     "globals::getCameraDamping()")
[[nodiscard]] float &getCameraDamping();
ENGINECTX_DEPRECATED("Access EngineContext::cameraStiffness instead of "
                     "globals::getCameraStiffness()")
[[nodiscard]] float &getCameraStiffness();
ENGINECTX_DEPRECATED("Access EngineContext::cameraVelocity instead of "
                     "globals::getCameraVelocity()")
[[nodiscard]] Vector2 &getCameraVelocity();
ENGINECTX_DEPRECATED("Access EngineContext::nextCameraTarget instead of "
                     "globals::getNextCameraTarget()")
[[nodiscard]] Vector2 &getNextCameraTarget();

struct SpriteFrameData {
  std::string
      atlasUUID{}; // texture for the sprite frame, from the laoded texture map
  Rectangle frame{}; // frame rectangle
};

// map sprite number to sprite draw rect (source)
extern std::map<std::string, SpriteFrameData> spriteDrawFrames;
[[nodiscard]] std::map<std::string, SpriteFrameData> &getSpriteFrameMap();

// map sprite number to CP437 char and UTF codepoint, vice versa

// char is the first of the pair, utf16 codepoint is the second
extern std::map<int, std::pair<char, int>> spriteNumberToCP437_char_and_UTF16;
extern std::map<char, int> CP437_charToSpriteNumber;

// map environment id to json array element
extern std::map<string, json> environmentTilesMap;

// map color name to color
extern std::map<std::string, Color> colors;
[[nodiscard]] std::map<std::string, Color> &getColorsMap();

// true if forced branching dialogue choices have been displayed and we're
// waiting for player input
extern bool awaitingInputForForcedBranchingDialogue;
// contains a list of dialogue choice IDs (for json array node) that are
// currently viable. The json information used will be from the current map
// location
extern vector<string> viableForcedBranchingChoicesByID;

// read raw data from json
extern json data;

// keep track of endings reached
extern json saveRecord;

// font used by the game
extern Font font, smallerFont, translationFont;

// announcement log
extern int currentLogDisplayIndex;

// keep track of scroll update flag (should scroll pos be updated for new
// location?)
extern bool updateScrollPositionToHidePreviousText;

// starting text to show.
extern string startText;

// map of global bool flags that will be set throughout the game
extern std::map<string, bool> globalFlagsFromJSON;
// map of global variables that can be set/read by json nodes
extern std::map<string, string> globalVariablesMapFromJSON;

// How long the object should shake for.
extern float shakeDuration;

// Amplitude of the shake. A larger value shakes the camera harder.
extern float shakeAmount;
extern float decreaseFactor;

constexpr int MAX_ACTIONS = 64; // goap

extern float G_TIMER_REAL;  // updates only when game is not paused
extern float G_TIMER_TOTAL; // updates even when game is paused
extern long G_FRAMES_MOVE;  // total frames since game start
extern entt::entity G_ROOM; // entity that is a moveable representing the map
extern float G_COLLISION_BUFFER; // Buffer for collision detection from lua
                                 // //TODO: move to globals later
extern int G_TILESIZE; // TODO: used by movable, not sure how it is used
[[nodiscard]] float &getTimerReal();
[[nodiscard]] float &getTimerTotal();
[[nodiscard]] long &getFramesMove();

extern bool reduced_motion;

extern float guiClippingRotation; // rotation for clipping in gui, used for
                                  // juice in imgui

extern std::map<std::string, gui::NinePatchData>
    ninePatchDataMap; // used for ninepatch drawing in imgui

extern std::vector<std::vector<uint8_t>> globalVisibilityMap;
extern bool useLineOfSight;
[[nodiscard]] std::vector<std::vector<uint8_t>> &getGlobalVisibilityMap();
[[nodiscard]] bool &getUseLineOfSight();

extern sol::state lua; // for events

extern Texture2D titleTexture;

extern layer::Layer backgroundLayer, gameLayer, uiLayer;

extern float BASE_SHADOW_EXAGGERATION; // multiplied to shadow offsets
[[nodiscard]] float &getBaseShadowExaggeration();

// Fixed text shadow offset - consistent regardless of screen position (not affected by parallax)
extern Vector2 FIXED_TEXT_SHADOW_OFFSET;
[[nodiscard]] Vector2 &getFixedTextShadowOffset();

extern std::optional<int> REFRESH_FRAME_MASTER_CACHE;

extern bool shouldRefreshAlerts;

extern entt::entity
    cursor; // cursor object used to follow location of mouse or controller
extern entt::entity
    overlayMenu; // uibox being used as overlay menu (start, etc.)

extern std::unordered_map<std::string, std::vector<entt::entity>>
    globalUIInstanceMap;

// contains string-mapped functions to be used by ui elements as button
// callbacks
extern std::unordered_map<std::string, std::function<void()>> buttonCallbacks;

extern std::optional<bool> noModCursorStack; // TODO: document this

struct Settings {
  bool shadowsOn = true;
  float uiPadding = 4.0f;  // Unified with globals::uiPadding (was 10.0f)
  float uiWindowPadding = 10.0f; // Uniform padding for top-level UI windows/panels
};

extern Settings settings;
[[nodiscard]] Settings &getSettings();
void setCurrentGameState(GameState state);

struct FontData {
  // Multi-size font cache
  std::map<int, Font> fontsBySize;  // size -> Font (sorted)
  int defaultSize = 22;

  float fontScale = 1.0f;      // the scale of the font when rendered
  float spacing = 1.0f;        // the horizontal spacing for the font
  Vector2 fontRenderOffset = {
      2, 5}; // the offset of the font when rendered, applied to ensure text is
             // centered correctly in ui, it is multiplied by scale when applied
  // <— store your codepoint list if you ever need it later
  std::vector<int> codepoints;

  [[nodiscard]] const Font& getBestFontForSize(float requestedSize) const {
    int requested = static_cast<int>(std::round(requestedSize));

    // Find smallest size >= requested (prefer downscaling)
    auto it = fontsBySize.lower_bound(requested);
    if (it != fontsBySize.end()) {
      return it->second;
    }
    // Fall back to largest available size
    if (!fontsBySize.empty()) {
      return fontsBySize.rbegin()->second;
    }
    // Ultimate fallback - return empty font (should never happen)
    static Font empty{};
    return empty;
  }

  [[nodiscard]] const Font& getDefaultFont() const {
    return getBestFontForSize(static_cast<float>(defaultSize));
  }
};

extern float uiPadding;
ENGINECTX_DEPRECATED(
    "Access EngineContext::uiPadding instead of globals::getUiPadding()")
[[nodiscard]] float &getUiPadding();

extern input::InputState inputState;

extern Color uiBackgroundDark, uiTextLight, uiOutlineLight, uiTextInactive,
    uiHover, uiInventoryOccupied, uiInventoryEmpty;

extern std::string language; // the current language for the game

extern bool under_overlay; // set to true when an ui overlay is active
ENGINECTX_DEPRECATED(
    "Access EngineContext::underOverlay instead of globals::getUnderOverlay()")
[[nodiscard]] bool &getUnderOverlay();

extern float vibration; // vibration strength for controllers
ENGINECTX_DEPRECATED(
    "Access EngineContext::vibration instead of globals::getVibration()")
[[nodiscard]] float &getVibration();

extern bool releaseMode; // set to true to disable debug features
ENGINECTX_DEPRECATED(
    "Access EngineContext::releaseMode instead of globals::getReleaseMode()")
[[nodiscard]] bool &getReleaseMode();

extern bool isGamePaused;
ENGINECTX_DEPRECATED(
    "Access EngineContext::isGamePaused instead of globals::getIsGamePaused()")
[[nodiscard]] bool &getIsGamePaused();
void setIsGamePaused(bool v);

extern bool screenWipe; // true when the screen is being wiped (transitioning
                        // between scenes)
ENGINECTX_DEPRECATED(
    "Access EngineContext::screenWipe instead of globals::getScreenWipe()")
[[nodiscard]] bool &getScreenWipe();

extern entt::entity
    gameWorldContainerEntity; // entity representing the entire game world
                              // (usually the size of the screen)

// ECS registry
extern entt::registry registry;

ENGINECTX_DEPRECATED(
    "Access EngineContext::eventBus instead of globals::getEventBus()")
[[nodiscard]] event_bus::EventBus &getEventBus();

// Helpers to bridge cursor entity while migrating to EngineContext.
ENGINECTX_DEPRECATED(
    "Access EngineContext::cursor instead of globals::getCursorEntity()")
[[nodiscard]] entt::entity getCursorEntity();
void setCursorEntity(entt::entity e);
ENGINECTX_DEPRECATED(
    "Access EngineContext::overlayMenu instead of globals::getOverlayMenu()")
[[nodiscard]] entt::entity getOverlayMenu();
void setOverlayMenu(entt::entity e);
ENGINECTX_DEPRECATED("Access EngineContext::gameWorldContainerEntity instead "
                     "of globals::getGameWorldContainer()")
[[nodiscard]] entt::entity getGameWorldContainer();
void setGameWorldContainer(entt::entity e);
[[nodiscard]] std::unordered_map<std::string, std::vector<entt::entity>> &
getGlobalUIInstanceMap();
[[nodiscard]] std::unordered_map<std::string, std::function<void()>> &getButtonCallbacks();

// Accessors that respect EngineContext when available.
ENGINECTX_DEPRECATED(
    "Access EngineContext::registry instead of globals::getRegistry()")
[[nodiscard]] entt::registry &getRegistry();
// extern Camera2D camera2D;

extern void updateGlobalVariables();
[[nodiscard]] extern Vector2 getWorldMousePosition();

void setReleaseMode(bool v);
void recordMouseClick(Vector2 pos, int button);
[[nodiscard]] bool hasLastMouseClick();
[[nodiscard]] Vector2 getLastMouseClickPosition();
[[nodiscard]] int getLastMouseClickButton();
void recordMouseClick(Vector2 pos, int button, entt::entity target);
[[nodiscard]] entt::entity getLastMouseClickTarget();
[[nodiscard]] entt::entity getLastCollisionA();
[[nodiscard]] entt::entity getLastCollisionB();
void setLastCollision(entt::entity a, entt::entity b);
[[nodiscard]] entt::entity getLastUIFocus();
void setLastUIFocus(entt::entity e);
[[nodiscard]] entt::entity getLastUIButtonActivated();
void setLastUIButtonActivated(entt::entity e);
[[nodiscard]] const std::string &getLastLoadingStage();
[[nodiscard]] bool getLastLoadingStageSuccess();
void setLastLoadingStage(const std::string &stageId, bool success);

struct CollisionNote {
  entt::entity a{entt::null};
  entt::entity b{entt::null};
  bool began{true};
  Vector2 point{0.0f, 0.0f};
  double timestamp{0.0};
};

[[nodiscard]] const std::vector<CollisionNote> &getCollisionLog();
void pushCollisionLog(const CollisionNote &note);
/// @endcond
} // namespace globals
