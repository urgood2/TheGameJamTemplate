#pragma once

/**
 * Global variables used by main.cpp.
 *
 * The extern variables are defined in main.
 */
#include "raylib.h"                         // raylib
#include "entt/entt.hpp"                    // ECS
#include "../third_party/rlImGui/rlImGui.h" // raylib imGUI binding
#include "../core/gui.hpp"

#if defined(_WIN32)
#define NOGDI  // All GDI defines and routines
#define NOUSER // All USER defines and routines
#endif

#define SPDLOG_ACTIVE_LEVEL SPDLOG_LEVEL_DEBUG // compiler-time log level

#include "spdlog/spdlog.h" // SPD logging lib // or any library that uses Windows.h
#include "spdlog/sinks/basic_file_sink.h"

#include "effolkronium/random.hpp"   // https://github.com/effolkronium/random

// #include "behaviortree_cpp_v3/bt_factory.h" // https://github.com/BehaviorTree/BehaviorTree.CPP/tree/v3.8/

#include "../components/graphics.hpp"

#include "../systems/anim_system.hpp"
#include "../systems/collision/Quadtree.h"
#include "../systems/localization/localization.hpp"


#include "third_party/rlImGui/imgui.h" // raylib imGUI binding

#include "gui.hpp"

#define JSON_DIAGNOSTICS 1
#include <nlohmann/json.hpp>          // nlohmann JSON parsing
#include <fmt/core.h>                 // https://github.com/fmtlib/fmt
#include <boost/algorithm/string.hpp> // boost string
#include <boost/tokenizer.hpp>        // string tokenizer

#include <iostream>
#include <sstream>
#include <string>
#include <fstream>
#include <memory>
#include <map>
#include <regex>
#include <cassert>
#include <cmath>
#include <string>
#include <vector>
#include <unordered_map>
#include <functional>
#include <optional>

#include "sol/sol.hpp"

using std::string, std::unique_ptr, std::vector;
using namespace std::literals;
// using namespace BT;
using json = nlohmann::json;
using Random = effolkronium::random_static; // get base random alias which is auto seeded and has static API and internal state

// Keep track of game state
enum class GameState
{
    MAIN_MENU,
    LOADING_SCREEN,
    MAIN_GAME,
    GAME_OVER
};

namespace input
{
    struct InputState;
}

namespace transform
{
    struct MasterCacheEntry;
    struct SpringCacheBundle;
}

namespace shaders
{
    struct ShaderUniformComponent;
}

namespace layer 
{
    struct Layer;
}

class PhysicsManager;

namespace globals
{
    extern std::shared_ptr<PhysicsManager> physicsManager; // physics manager instance
    
    extern std::unordered_map<entt::entity, transform::SpringCacheBundle> g_springCache;
    
    extern std::unordered_map<entt::entity, transform::MasterCacheEntry> getMasterCacheEntityToParentCompMap;

    extern float globalUIScaleFactor; // scale factor for UI elements
    
    extern bool drawDebugInfo, drawPhysicsDebug; // set to true to allow debug drawing of transforms
    
    extern const float UI_PROGRESS_BAR_INSET_PIXELS; // inset for progress bar fill (the portion that fills the bar)
    
    extern shaders::ShaderUniformComponent globalShaderUniforms; // keep track of shader uniforms;

    extern GameState currentGameState;

    //---------------------------------------------------------
    // constants
    extern int screenWidth, screenHeight;
    extern int gameWorldViewportWidth, gameWorldViewportHeight;
    extern const float FONT_SIZE;
    extern string gameTitle;

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

    extern vector<entt::entity> enemies;

    // keep track of execution step name during world gen (also for loading screen)
    extern string worldGenCurrentStep;

    // these must be in context throughout main loop. Used for multithreading loading

    // Keep track of loading messages
    extern std::map<int, std::string> loadingStages;

    // current loading message index
    extern int loadingStateIndex;

    // store loaded animation data mapped to animation id
    extern std::map<std::string, AnimationObject> animationsMap;

    // show mouse current status
    extern bool isMouseDragStarted;

    // keep track of mouse dragging coords (start and end)
    extern Vector2 mouseDragStartedCoords, mouseDragEndedCoords;

    extern bool showObserverWindow;

    extern int worldWidth, worldHeight;

    // font for the ui (IMGUI)
    extern ImFont *uiFont12;

    // Texture onto which game world is drawn
    extern RenderTexture gameWorldViewPort;

    // world map (2d grid - maybe make into 3d later?)
    extern vector<vector<entt::entity>> map;

    // for pathfinding version of map
    extern vector<double> pathfindingMatrix;

    // clicked entity
    extern entt::entity clickedEntity;

    // various raw files
    extern json activityJSON, colorsJSON, environmentJSON, floraJSON, humanJSON, levelsJSON, materialsJSON, worldGenJSON, muscleJSON, timeJSON, behaviorTreeConfigJSON, levelCurvesJSON, namegenJSON, professionJSON, particleEffectsJSON, uiStringsJSON, animationsJSON, itemsJSON, combatActionToStateJSON, combatAttackWoundsJSON, combatAvailableActionsByStateJSON, objectsJSON, aiConfigJSON, aiActionsJSON, aiWorldstateJSON, ninePatchJSON;

    extern json miniJamCardsJSON, miniJamEnemiesJSON;

    // thesaurus (english)
    extern json thesaurusJSON; // https://github.com/zaibacu/thesaurusb

    // sprite data
    extern json spritesJSON, cp437MappingsJSON;

    // Global vector to hold all loaded textures
    extern std::map<string, Texture2D> textureAtlasMap;

    // game config
    extern json configJSON;

    // game camera
    // extern Camera2D camera;
    extern float cameraDamping, cameraStiffness;
    extern Vector2 cameraVelocity;
    extern Vector2 nextCameraTarget; // keep track of desired next camera target position

    struct SpriteFrameData
    {
        std::string atlasUUID{}; // texture for the sprite frame, from the laoded texture map
        Rectangle frame{};   // frame rectangle
    };

    // map sprite number to sprite draw rect (source)
    extern std::map<std::string, SpriteFrameData> spriteDrawFrames; 

    // map sprite number to CP437 char and UTF codepoint, vice versa

    // char is the first of the pair, utf16 codepoint is the second
    extern std::map<int, std::pair<char, int>> spriteNumberToCP437_char_and_UTF16;
    extern std::map<char, int> CP437_charToSpriteNumber;

    // map environment id to json array element
    extern std::map<string, json> environmentTilesMap;

    // map color name to color
    extern std::map<string, Color> colorsMap;

    // ---------- old variables from prev, project (to be deletecd)

    // true if forced branching dialogue choices have been displayed and we're waiting for player input
    extern bool awaitingInputForForcedBranchingDialogue;
    // contains a list of dialogue choice IDs (for json array node) that are currently viable. The json information used will be from the current map location
    extern vector<string> viableForcedBranchingChoicesByID;

    // read raw data from json
    extern json data;

    // keep track of endings reached
    extern json saveRecord;

    // font used by the game
    extern Font font, smallerFont, translationFont;

    // announcement log
    extern int currentLogDisplayIndex;

    // keep track of scroll update flag (should scroll pos be updated for new location?)
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

    extern float G_TIMER_REAL;       // updates only when game is not paused
    extern float G_TIMER_TOTAL;      // updates even when game is paused
    extern long G_FRAMES_MOVE;       // total frames since game start
    extern entt::entity G_ROOM;      // entity that is a moveable representing the map
    extern float G_COLLISION_BUFFER; // Buffer for collision detection from lua //TODO: move to globals later
    extern int G_TILESIZE;           // TODO: used by movable, not sure how it is used

    extern bool reduced_motion;

    extern float guiClippingRotation; // rotation for clipping in gui, used for juice in imgui

    extern std::map<std::string, gui::NinePatchData> ninePatchDataMap; // used for ninepatch drawing in imgui

    extern std::vector<std::vector<bool>> globalVisibilityMap;
    extern bool useLineOfSight;

    extern sol::state lua; // for events

    extern Texture2D titleTexture;

    extern layer::Layer backgroundLayer, gameLayer, uiLayer;

    extern float BASE_SHADOW_EXAGGERATION; // multiplied to shadow offsets

    extern std::optional<int> REFRESH_FRAME_MASTER_CACHE;

    extern bool shouldRefreshAlerts;

    extern entt::entity cursor;      // cursor object used to follow location of mouse or controller
    extern entt::entity overlayMenu; // uibox being used as overlay menu (start, etc.)

    extern std::unordered_map<std::string, std::vector<entt::entity>> globalUIInstanceMap;

    // contains string-mapped functions to be used by ui elements as button callbacks
    extern std::unordered_map<std::string, std::function<void()>> buttonCallbacks;

    extern std::optional<bool> noModCursorStack; // TODO: document this

    struct Settings
    {
        bool shadowsOn = true;
        float uiPadding = 10.0f;
    };

    

    extern Settings settings;

    struct FontData
    {
        Font font{};
        float fontLoadedSize = 32.f;       // the size of the font when loaded
        float fontScale = 1.0f;            // the scale of the font when rendered
        float spacing = 1.0f;              // the horizontal spacing for the font
        Vector2 fontRenderOffset = {2, 0}; // the offset of the font when rendered, applied to ensure text is centered correctly in ui, it is multiplied by scale when applied
        // <— store your codepoint list if you ever need it later
        std::vector<int> codepoints;
    };

    extern float uiPadding;

    extern input::InputState inputState;

    extern Color uiBackgroundDark, uiTextLight, uiOutlineLight, uiTextInactive, uiHover, uiInventoryOccupied, uiInventoryEmpty;

    extern std::string language; // the current language for the game

    extern bool under_overlay; // set to true when an ui overlay is active

    extern float vibration; // vibration strength for controllers

    extern bool releaseMode; // set to true to disable debug features

    extern bool isGamePaused;

    extern bool screenWipe; // true when the screen is being wiped (transitioning between scenes)

    extern entt::entity gameWorldContainerEntity; // entity representing the entire game world (usually the size of the screen)
    
    // ECS registry
    extern entt::registry registry;

    // extern Camera2D camera2D;

    extern void updateGlobalVariables();
    extern Vector2 getWorldMousePosition();
}