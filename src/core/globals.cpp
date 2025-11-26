
#include "globals.hpp" // global variables

#include "../components/graphics.hpp"
#include "engine_context.hpp"
#include "events.hpp"

#include "../core/gui.hpp"

#include "../systems/anim_system.hpp"
#include "systems/input/input_function_data.hpp"
#include "systems/shaders/shader_system.hpp"
#include "systems/collision/Quadtree.h"
#include "systems/localization/localization.hpp"

#include "../systems/physics/physics_manager.hpp"

#include <iostream>
#include <sstream>
#include <string>
#include <fstream>
#include <memory>
#include <map>
#include <regex>
#include <cassert>
#include <cmath>
#include <functional>

#include "sol/sol.hpp"

using std::string, std::unique_ptr, std::vector;
using namespace std::literals;
using Random = effolkronium::random_static; // get base random alias which is auto seeded and has static API and internal state


namespace globals {

    using ::EngineContext;
    
    EngineContext* g_ctx = nullptr;
    static AudioContext g_audioContext{};
    static event_bus::EventBus g_fallbackEventBus{};

    // Mouse/cursor tracking mirrored into EngineContext when present.
    Vector2 worldMousePosition = {0,0};
    Camera2D camera2D = {0};
    Vector2 lastMouseClick{0.0f, 0.0f};
    int lastMouseButton{-1};
    bool hasLastClickFlag{false};
    entt::entity lastMouseClickTarget{entt::null};
    bool hasLastMouseClickTargetFlag{false};
    entt::entity lastCollisionA{entt::null};
    entt::entity lastCollisionB{entt::null};
    entt::entity lastUIFocus{entt::null};
    entt::entity lastUIButtonActivated{entt::null};
    std::string lastLoadingStage{};
    bool lastLoadingStageSuccess{true};
    static std::deque<CollisionNote> collisionLog;
    constexpr size_t kCollisionLogMax = 32;

    template <typename T>
    static T& resolveCtxOrLegacy(T& legacy, T EngineContext::*member) {
        if (g_ctx) {
            auto& slot = g_ctx->*member;
            if (slot.empty() && !legacy.empty()) {
                slot = legacy;
            }
            return slot;
        }
        return legacy;
    }

void setEngineContext(EngineContext* ctx) {
    g_ctx = ctx;
    if (g_ctx) {
        g_ctx->inputState = &inputState;
        g_ctx->physicsManager = physicsManager;
        g_ctx->worldMousePosition = {0.0f, 0.0f};
        g_ctx->scaledMousePosition = {0.0f, 0.0f};
        g_ctx->audio = &g_audioContext;

        g_ctx->currentGameState = currentGameState;
        g_ctx->isGamePaused = isGamePaused;
        g_ctx->useImGUI = useImGUI;
        g_ctx->finalRenderScale = finalRenderScale;
        g_ctx->finalLetterboxOffsetX = finalLetterboxOffsetX;
        g_ctx->finalLetterboxOffsetY = finalLetterboxOffsetY;
        g_ctx->globalUIScaleFactor = globalUIScaleFactor;
        g_ctx->uiScaleFactor = globalUIScaleFactor;
        g_ctx->uiPadding = uiPadding;
        g_ctx->settings = settings;
        g_ctx->cameraDamping = cameraDamping;
        g_ctx->cameraStiffness = cameraStiffness;
        g_ctx->cameraVelocity = cameraVelocity;
        g_ctx->nextCameraTarget = nextCameraTarget;
        g_ctx->worldWidth = worldWidth;
        g_ctx->worldHeight = worldHeight;
        g_ctx->baseShadowExaggeration = BASE_SHADOW_EXAGGERATION;
        g_ctx->visibilityMap = globalVisibilityMap;
        g_ctx->useLineOfSight = useLineOfSight;
        g_ctx->timerReal = G_TIMER_REAL;
        g_ctx->timerTotal = G_TIMER_TOTAL;
        g_ctx->framesMove = G_FRAMES_MOVE;
        g_ctx->drawDebugInfo = drawDebugInfo;
        g_ctx->drawPhysicsDebug = drawPhysicsDebug;
        g_ctx->releaseMode = releaseMode;
        g_ctx->screenWipe = screenWipe;
        g_ctx->underOverlay = under_overlay;
        g_ctx->vibration = vibration;
        g_ctx->lastMouseClickTarget = lastMouseClickTarget;
        g_ctx->hasLastMouseClickTarget = hasLastMouseClickTargetFlag;
        g_ctx->lastMouseClick = lastMouseClick;
        g_ctx->lastMouseButton = lastMouseButton;
        g_ctx->hasLastMouseClick = hasLastClickFlag;
        g_ctx->lastCollisionA = lastCollisionA;
        g_ctx->lastCollisionB = lastCollisionB;
        g_ctx->lastUIFocus = lastUIFocus;
        g_ctx->lastUIButtonActivated = lastUIButtonActivated;
        g_ctx->lastLoadingStage = lastLoadingStage;
        g_ctx->lastLoadingStageSuccess = lastLoadingStageSuccess;
        // collision log is intentionally kept local; not mirroring to ctx to avoid copies.

        g_ctx->shaderUniforms = globalShaderUniforms;
        if (!g_ctx->shaderUniformsPtr) {
            g_ctx->shaderUniformsOwned = std::make_unique<shaders::ShaderUniformComponent>(globalShaderUniforms);
            g_ctx->shaderUniformsPtr = g_ctx->shaderUniformsOwned.get();
        } else {
            *g_ctx->shaderUniformsPtr = globalShaderUniforms;
        }
    }
}

    // Get mouse position scaled to virtual resolution so collision works regardless of window size
    
    Vector2 GetScaledMousePosition()
    {
        Vector2 m = GetMousePosition();

        // Avoid division by zero before render scale is initialized.
        float scale = getFinalRenderScale();
        if (scale <= 0.0f) {
            scale = 1.0f;
        }

        // Remove letterbox offset
        m.x -= getLetterboxOffsetX();
        m.y -= getLetterboxOffsetY();

        // Undo uniform scale
        m.x /= scale;
        m.y /= scale;

        if (g_ctx) {
            g_ctx->scaledMousePosition = m;
        }
        return m;
    }

    Vector2 getScaledMousePositionCached() {
        // Always compute to keep both legacy globals and context in sync.
        return GetScaledMousePosition();
    }


    
    const int VIRTUAL_WIDTH = 1280;
    const int VIRTUAL_HEIGHT = 800; // steam deck resolution
    
    float finalRenderScale = 0.f; // the final render scale to apply when drawing to the screen, updated each frame
    float finalLetterboxOffsetX = 0.0f;
    float finalLetterboxOffsetY = 0.0f;
    float& getFinalRenderScale() { 
        if (g_ctx) return g_ctx->finalRenderScale;
        return finalRenderScale; 
    }
    float& getLetterboxOffsetX() { 
        if (g_ctx) return g_ctx->finalLetterboxOffsetX;
        return finalLetterboxOffsetX; 
    }
    float& getLetterboxOffsetY() { 
        if (g_ctx) return g_ctx->finalLetterboxOffsetY;
        return finalLetterboxOffsetY; 
    }
    void setFinalRenderScale(float v) { 
        finalRenderScale = v; 
        if (g_ctx) g_ctx->finalRenderScale = v;
    }
    void setLetterboxOffsetX(float v) { 
        finalLetterboxOffsetX = v; 
        if (g_ctx) g_ctx->finalLetterboxOffsetX = v;
    }
    void setLetterboxOffsetY(float v) { 
        finalLetterboxOffsetY = v; 
        if (g_ctx) g_ctx->finalLetterboxOffsetY = v;
    }
    
    bool useImGUI = true; // set to true to use imGUI for debugging
    bool& getUseImGUI() { 
        if (g_ctx) return g_ctx->useImGUI;
        return useImGUI; 
    }
    void setUseImGUI(bool v) {
        useImGUI = v;
        if (g_ctx) g_ctx->useImGUI = v;
    }
    
    std::shared_ptr<PhysicsManager> physicsManager; // physics manager instance
    std::shared_ptr<PhysicsManager>& getPhysicsManagerPtr() {
        if (g_ctx && g_ctx->physicsManager) return g_ctx->physicsManager;
        return physicsManager;
    }
    PhysicsManager* getPhysicsManager() {
        return getPhysicsManagerPtr().get();
    }
    
    std::unordered_map<entt::entity, transform::SpringCacheBundle> g_springCache;

    std::unordered_map<entt::entity, transform::MasterCacheEntry> getMasterCacheEntityToParentCompMap{};

    float globalUIScaleFactor =1.f; // scale factor for UI elements
    float& getGlobalUIScaleFactor() {
        if (g_ctx) return g_ctx->globalUIScaleFactor;
        return globalUIScaleFactor; 
    }
    void setGlobalUIScaleFactor(float v) {
        globalUIScaleFactor = v;
        if (g_ctx) {
            g_ctx->globalUIScaleFactor = v;
            g_ctx->uiScaleFactor = v;
        }
        getEventBus().publish(events::UIScaleChanged{v});
    }

    bool drawDebugInfo = false, drawPhysicsDebug = false; // set to true to allow debug drawing of transforms
    bool& getDrawDebugInfo() {
        if (g_ctx) return g_ctx->drawDebugInfo;
        return drawDebugInfo;
    }
    bool& getDrawPhysicsDebug() {
        if (g_ctx) return g_ctx->drawPhysicsDebug;
        return drawPhysicsDebug;
    }
    void setDrawDebugInfo(bool v) {
        drawDebugInfo = v;
        if (g_ctx) g_ctx->drawDebugInfo = v;
    }
    void setDrawPhysicsDebug(bool v) {
        drawPhysicsDebug = v;
        if (g_ctx) g_ctx->drawPhysicsDebug = v;
    }
    
    const float UI_PROGRESS_BAR_INSET_PIXELS = 4.0f; // inset for progress bar fill (the portion that fills the bar)

    shaders::ShaderUniformComponent globalShaderUniforms{}; // keep track of shader uniforms
    shaders::ShaderUniformComponent& getGlobalShaderUniforms() {
        if (g_ctx && g_ctx->shaderUniformsPtr) return *g_ctx->shaderUniformsPtr;
        return globalShaderUniforms; 
    }

    std::map<std::string, SpriteFrameData> spriteDrawFrames; 

    // store gui ninepatch data
    std::map<std::string, gui::NinePatchData> ninePatchDataMap;

    // Vector to keep track of all loaded textures to manage their lifetime
    std::map<std::string, Texture2D> loadedTextures;

    // keep track of mouse dragging coords (start and end, in tile units)
    Vector2 mouseDragStartedCoords{-1.0f, -1.0f}, mouseDragEndedCoords{-1.0f, -1.0f};

    // keep track of execution step name during world gen (also for loading screen)
    string worldGenCurrentStep{};

    // read raw data from json
    json data{};

    // font used by the game
    Font font{}, smallerFont{}, translationFont{};

    // screen dimensions
    int screenWidth{VIRTUAL_WIDTH}, screenHeight{VIRTUAL_HEIGHT};
    int gameWorldViewportWidth{VIRTUAL_WIDTH}, gameWorldViewportHeight{VIRTUAL_HEIGHT};
    int& getScreenWidth() { return screenWidth; }
    int& getScreenHeight() { return screenHeight; }
    int& getGameWorldViewportWidth() { return gameWorldViewportWidth; }
    int& getGameWorldViewportHeight() { return gameWorldViewportHeight; }

    int worldWidth{}, worldHeight{}; // world dimensions
    int& getWorldWidth() { 
        if (g_ctx) return g_ctx->worldWidth;
        return worldWidth; 
    }
    int& getWorldHeight() { 
        if (g_ctx) return g_ctx->worldHeight;
        return worldHeight; 
    }
    
    
    
    // collision detection
    std::function<quadtree::Box<float>(entt::entity)> getBoxWorld = [](entt::entity e) -> quadtree::Box<float> {
        auto &transform = globals::getRegistry().get<transform::Transform>(e);
        
        const float x = transform.getActualX();
        const float y = transform.getActualY();
        const float w = transform.getActualW();
        const float h = transform.getActualH();
        const float r = std::abs(transform.getActualRotation());
    
        // Use inflation factor only when rotation is non-negligible
        constexpr float inflation = 1.4142f; // sqrt(2)
        const float factor = (r < 0.0001f) ? 1.0f : inflation;
    
        const float hw = w * 0.5f * factor;
        const float hh = h * 0.5f * factor;
    
        const float cx = x + w * 0.5f;
        const float cy = y + h * 0.5f;
    
        return quadtree::Box<float>{
            {cx - hw, cy - hh},
            {hw * 2.0f, hh * 2.0f}
        };
    };
    
    
    quadtree::Box<float> uiBounds{-(float)getScreenWidth(), -(float)getScreenHeight(), (float)getScreenWidth() * 3, (float)getScreenHeight() * 3}; // Define the ui space bounds for the quadtree
    quadtree::Box<float> worldBounds{-(float)getScreenWidth(), -(float)getScreenHeight(), (float)getScreenWidth() *3, (float)getScreenHeight() * 3}; // Define the world space bounds for the quadtree
    quadtree::Quadtree<entt::entity, decltype(getBoxWorld)> quadtreeWorld(worldBounds, getBoxWorld);
    quadtree::Quadtree<entt::entity, decltype(getBoxWorld)> quadtreeUI(worldBounds, getBoxWorld);

    // Keep track of loading messages
    std::map<int, std::string> loadingStages;

    // game camera
    Camera2D camera{};
    float cameraDamping{.4f}, cameraStiffness{0.99f};
    Vector2 cameraVelocity{0,0};
    Vector2 nextCameraTarget{0,0}; // keep track of desired next camera target position
    float& getCameraDamping() { 
        if (g_ctx) return g_ctx->cameraDamping;
        return cameraDamping; 
    }
    float& getCameraStiffness() { 
        if (g_ctx) return g_ctx->cameraStiffness;
        return cameraStiffness; 
    }
    Vector2& getCameraVelocity() { 
        if (g_ctx) return g_ctx->cameraVelocity;
        return cameraVelocity; 
    }
    Vector2& getNextCameraTarget() { 
        if (g_ctx) return g_ctx->nextCameraTarget;
        return nextCameraTarget; 
    }

    //TODO make a map of names to all available sprites
    //TODO how to mesh this with animations?
    std::map<std::string, AnimationObject> animationsMap{};

    // font for the ui (IMGUI)
    ImFont* uiFont12{}, *uiFontSmall{};

    // Texture onto which game world is drawn
    RenderTexture gameWorldViewPort{};

    // world map (2d grid - maybe make into 3d later?)
    vector<vector<entt::entity>> map{};

    // map sprite number to CP437 char and UTF codepoint, vice versa

    // char is the first of the pair, utf16 codepoint is the second
    std::map<int, std::pair<char, int>> spriteNumberToCP437_char_and_UTF16{};
    std::map<char, int> CP437_charToSpriteNumber{};

    // map environment id to json array element
    std::map<string, json> environmentTilesMap{};

    // game state
    GameState currentGameState{GameState::LOADING_SCREEN};
    GameState& getCurrentGameState() { 
        if (g_ctx) return g_ctx->currentGameState;
        return currentGameState; 
    }

    void setCurrentGameState(GameState state) {
        auto old = getCurrentGameState();
        if (old == state) {
            return;
        }
        currentGameState = state;
        if (g_ctx) {
            g_ctx->currentGameState = state;
        }
        getEventBus().publish(events::GameStateChanged{old, state});
    }

    // show mouse current status
    bool isMouseDragStarted{false};

    bool debugRenderWindowShowing{false};

    // current loading message index
    int loadingStateIndex{0};

    // various raw files 
    json activityJSON{}, colorsJSON{}, environmentJSON{}, floraJSON{}, humanJSON{}, levelsJSON{}, levelCurvesJSON{}, materialsJSON{}, worldGenJSON{}, muscleJSON{}, timeJSON{}, itemsJSON{}, behaviorTreeConfigJSON{}, namegenJSON{}, professionJSON{}, particleEffectsJSON{}, uiStringsJSON{}, combatActionToStateJSON{}, combatAttackWoundsJSON{}, combatAvailableActionsByStateJSON{}, objectsJSON{}, aiWorldstateJSON{}, aiActionsJSON{}, aiConfigJSON{}, ninePatchJSON{};

    // thesaurus (english)
    json thesaurusJSON{}; // https://github.com/zaibacu/thesaurusb

    // sprite data
    json spritesJSON{}, cp437MappingsJSON{}, animationsJSON{};

    // game config
    json configJSON{};

    // pathfinding version of map
    // TODO event-based updating
    vector<double> pathfindingMatrix{};
    std::vector<double>& getPathfindingMatrix() { return pathfindingMatrix; }
    // std::shared_ptr<fudge::JumpPointMap<double>> pathfindingMap{};
    // TODO init pathfinding map
    // TODO make pathfinding behavior tree subtree

    // timers used by classes taken from lua
    float G_TIMER_REAL = 0.0f; // updates only when game is not paused
    float G_TIMER_TOTAL = 0.0f; // updates even when game is paused
    long G_FRAMES_MOVE = 0; // total frames since game start
    entt::entity G_ROOM = entt::null; // entity that is a moveable representing the map
    float G_COLLISION_BUFFER = 0.05f; // Buffer for collision detection from lua //TODO: move to globals later
    int G_TILESIZE = 16; // TODO: used by movable, not sure how it is used
    float& getTimerReal() { 
        if (g_ctx) return g_ctx->timerReal;
        return G_TIMER_REAL; 
    }
    float& getTimerTotal() { 
        if (g_ctx) return g_ctx->timerTotal;
        return G_TIMER_TOTAL; 
    }
    long& getFramesMove() { 
        if (g_ctx) return g_ctx->framesMove;
        return G_FRAMES_MOVE; 
    }

    // motion reduction setting (for animations,text,smoothing etc.)
    bool reduced_motion = false;

    float guiClippingRotation{0.0f}; // for imgui animations


    // for line of sight
    std::vector<std::vector<bool>> globalVisibilityMap{};
    bool useLineOfSight{false};
    std::vector<std::vector<bool>>& getGlobalVisibilityMap() { 
        if (g_ctx) return g_ctx->visibilityMap;
        return globalVisibilityMap; 
    }
    bool& getUseLineOfSight() { 
        if (g_ctx) return g_ctx->useLineOfSight;
        return useLineOfSight; 
    }

    sol::state lua; // for events

    Texture2D titleTexture{};

    // Global vector to hold all loaded textures (non sprite atlas)
    std::map<string, Texture2D> textureAtlasMap;

    layer::Layer backgroundLayer{}, gameLayer{}, uiLayer{};

    // contains raw color data from colors.json, mapped to raw color names from the same file. 
    // use resources::getColor to get a color from this map with either raw name or uuid
    std::map<std::string, Color> colors{};

    
    float BASE_SHADOW_EXAGGERATION = 1.8f; 
    float& getBaseShadowExaggeration() {
        if (g_ctx) return g_ctx->baseShadowExaggeration;
        return BASE_SHADOW_EXAGGERATION;
    }

    //TODO: document
    std::optional<int> REFRESH_FRAME_MASTER_CACHE{}; // used for transform calculations

    bool shouldRefreshAlerts = false; //TODO: document

    entt::entity cursor; // cursor object used to follow location of mouse or controller
    entt::entity overlayMenu; // a uibox which is the overlay menu of the game

    std::unordered_map<std::string, std::vector<entt::entity>> globalUIInstanceMap; // maps ui types to a list of them. For now, there are UIBOX and POPUP types
    std::unordered_map<std::string, std::function<void()>> buttonCallbacks; //TODO: document

    std::optional<bool> noModCursorStack;
 
    Settings settings{};
    Settings& getSettings() {
        if (g_ctx) return g_ctx->settings;
        return settings;
    }


    float uiPadding = 4.0f; // padding for UI elements
    float& getUiPadding() { 
        if (g_ctx) return g_ctx->uiPadding;
        return uiPadding; 
    }
    
    input::InputState inputState{};
    
    Color uiBackgroundDark = DARKGRAY, 
        uiTextLight = LIGHTGRAY,
        uiOutlineLight = GRAY,
        uiTextInactive = DARKGRAY,
        uiHover = WHITE,
        uiInventoryOccupied = LIGHTGRAY,
        uiInventoryEmpty = WHITE;

    std::string language{"en"}; // the current language for the game

    bool under_overlay{false}; // set to true when an ui overlay is active
    bool& getUnderOverlay() { 
        if (g_ctx) return g_ctx->underOverlay;
        return under_overlay; 
    }

    float vibration{0.0f}; // vibration strength for controllers
    float& getVibration() {
        if (g_ctx) return g_ctx->vibration;
        return vibration;
    }

    bool releaseMode = false; // set to true to disable debug features
    bool& getReleaseMode() { 
        if (g_ctx) return g_ctx->releaseMode;
        return releaseMode; 
    }
    void setReleaseMode(bool v) {
        releaseMode = v;
        if (g_ctx) g_ctx->releaseMode = v;
    }
    
    bool isGamePaused = false; // self-explanatory
    bool& getIsGamePaused() { 
        if (g_ctx) return g_ctx->isGamePaused;
        return isGamePaused; 
    }
    void setIsGamePaused(bool v) {
        isGamePaused = v;
        if (g_ctx) g_ctx->isGamePaused = v;
    }

    bool screenWipe = false; // true when the screen is being wiped (transitioning between scenes). Set this to true during transitions to prevent input.
    bool& getScreenWipe() { 
        if (g_ctx) return g_ctx->screenWipe;
        return screenWipe; 
    }

    entt::entity gameWorldContainerEntity;

    // the main entity registry for the ECS
    entt::registry registry{};

    json& getConfigJson() {
        return resolveCtxOrLegacy(configJSON, &EngineContext::configJson);
    }

    json& getColorsJson() {
        return resolveCtxOrLegacy(colorsJSON, &EngineContext::colorsJson);
    }

    json& getUiStringsJson() {
        return resolveCtxOrLegacy(uiStringsJSON, &EngineContext::uiStringsJson);
    }

    json& getAnimationsJson() {
        return resolveCtxOrLegacy(animationsJSON, &EngineContext::animationsJson);
    }

    json& getAiConfigJson() {
        return resolveCtxOrLegacy(aiConfigJSON, &EngineContext::aiConfigJson);
    }

    json& getAiActionsJson() {
        return resolveCtxOrLegacy(aiActionsJSON, &EngineContext::aiActionsJson);
    }

    json& getAiWorldstateJson() {
        return resolveCtxOrLegacy(aiWorldstateJSON, &EngineContext::aiWorldstateJson);
    }

    json& getNinePatchJson() {
        return resolveCtxOrLegacy(ninePatchJSON, &EngineContext::ninePatchJson);
    }

    std::map<std::string, Texture2D>& getTextureAtlasMap() {
        return resolveCtxOrLegacy(textureAtlasMap, &EngineContext::textureAtlas);
    }

    std::map<std::string, AnimationObject>& getAnimationsMap() {
        return resolveCtxOrLegacy(animationsMap, &EngineContext::animations);
    }

    std::map<std::string, SpriteFrameData>& getSpriteFrameMap() {
        return resolveCtxOrLegacy(spriteDrawFrames, &EngineContext::spriteFrames);
    }

    std::map<std::string, Color>& getColorsMap() {
        return resolveCtxOrLegacy(colors, &EngineContext::colors);
    }

    entt::entity getCursorEntity() {
        if (g_ctx) {
            return g_ctx->cursor;
        }
        return cursor;
    }

    void setCursorEntity(entt::entity e) {
        cursor = e;
        if (g_ctx) {
            g_ctx->cursor = e;
        }
    }

    entt::entity getOverlayMenu() {
        if (g_ctx) return g_ctx->overlayMenu;
        return overlayMenu;
    }

    void setOverlayMenu(entt::entity e) {
        overlayMenu = e;
        if (g_ctx) g_ctx->overlayMenu = e;
    }

    entt::entity getGameWorldContainer() {
        if (g_ctx) return g_ctx->gameWorldContainerEntity;
        return gameWorldContainerEntity;
    }

    void setGameWorldContainer(entt::entity e) {
        gameWorldContainerEntity = e;
        if (g_ctx) g_ctx->gameWorldContainerEntity = e;
    }

    std::unordered_map<std::string, std::vector<entt::entity>>& getGlobalUIInstanceMap() {
        if (g_ctx) {
            return g_ctx->globalUIInstances;
        }
        return globalUIInstanceMap;
    }

    std::unordered_map<std::string, std::function<void()>>& getButtonCallbacks() {
        if (g_ctx) {
            return g_ctx->buttonCallbacks;
        }
        return buttonCallbacks;
    }

    entt::registry& getRegistry() {
        if (g_ctx) {
            return g_ctx->registry;
        }
        return registry;
    }

    event_bus::EventBus& getEventBus() {
        if (g_ctx) {
            return g_ctx->eventBus;
        }
        return g_fallbackEventBus;
    }

    input::InputState& getInputState() {
        if (g_ctx && g_ctx->inputState) {
            return *g_ctx->inputState;
        }
        return inputState;
    }

    void updateGlobalVariables() {
        // Update world mouse position
        //==============================================================================
        Vector2 mousePos = GetMousePosition();
        Vector2 screenCenter = {globals::VIRTUAL_WIDTH / 2.0f, globals::VIRTUAL_HEIGHT / 2.0f};
        
        // Adjust for zoom and screen center
        Vector2 zoomedPosition = {mousePos.x - screenCenter.x, mousePos.y - screenCenter.y};
        Vector2 centeredPosition = {zoomedPosition.x / camera2D.zoom, zoomedPosition.y / camera2D.zoom};
        
        // Apply rotation (camera rotation is counterclockwise, so we need -cameraAngle)
        float cameraAngleRad = -camera2D.rotation * DEG2RAD; // Convert to radians
        Vector2 rotatedPosition = {
            centeredPosition.x * cosf(cameraAngleRad) - centeredPosition.y * sinf(cameraAngleRad),
            centeredPosition.x * sinf(cameraAngleRad) + centeredPosition.y * cosf(cameraAngleRad)
        };
        
        // Translate to world coordinates
        worldMousePosition = {
            rotatedPosition.x + camera2D.target.x,
            rotatedPosition.y + camera2D.target.y
        };
        //==============================================================================

        if (g_ctx) {
            g_ctx->worldMousePosition = worldMousePosition;
        }
        

    }



    Vector2 getWorldMousePosition() {
        if (g_ctx) {
            return g_ctx->worldMousePosition;
        }
        return worldMousePosition;
    }

    void recordMouseClick(Vector2 pos, int button) {
        recordMouseClick(pos, button, entt::null);
    }

    void recordMouseClick(Vector2 pos, int button, entt::entity target) {
        lastMouseClick = pos;
        lastMouseButton = button;
        hasLastClickFlag = true;
        if (target != entt::null) {
            lastMouseClickTarget = target;
            hasLastMouseClickTargetFlag = true;
        }
        if (g_ctx) {
            g_ctx->lastMouseClick = pos;
            g_ctx->lastMouseButton = button;
            g_ctx->hasLastMouseClick = true;
            if (target != entt::null) {
                g_ctx->lastMouseClickTarget = target;
                g_ctx->hasLastMouseClickTarget = true;
            }
        }
    }

    bool hasLastMouseClick() {
        if (g_ctx) return g_ctx->hasLastMouseClick;
        return hasLastClickFlag;
    }

    Vector2 getLastMouseClickPosition() {
        if (g_ctx && g_ctx->hasLastMouseClick) return g_ctx->lastMouseClick;
        return lastMouseClick;
    }

    int getLastMouseClickButton() {
        if (g_ctx && g_ctx->hasLastMouseClick) return g_ctx->lastMouseButton;
        return lastMouseButton;
    }

    entt::entity getLastMouseClickTarget() {
        if (g_ctx && g_ctx->hasLastMouseClickTarget) return g_ctx->lastMouseClickTarget;
        if (hasLastMouseClickTargetFlag) return lastMouseClickTarget;
        return entt::null;
    }

    entt::entity getLastCollisionA() {
        if (g_ctx && g_ctx->lastCollisionA != entt::null) return g_ctx->lastCollisionA;
        return lastCollisionA;
    }

    entt::entity getLastCollisionB() {
        if (g_ctx && g_ctx->lastCollisionB != entt::null) return g_ctx->lastCollisionB;
        return lastCollisionB;
    }

    void setLastCollision(entt::entity a, entt::entity b) {
        lastCollisionA = a;
        lastCollisionB = b;
        if (g_ctx) {
            g_ctx->lastCollisionA = a;
            g_ctx->lastCollisionB = b;
        }
    }

    entt::entity getLastUIFocus() {
        if (g_ctx && g_ctx->lastUIFocus != entt::null) return g_ctx->lastUIFocus;
        return lastUIFocus;
    }

    void setLastUIFocus(entt::entity e) {
        lastUIFocus = e;
        if (g_ctx) g_ctx->lastUIFocus = e;
    }

    entt::entity getLastUIButtonActivated() {
        if (g_ctx && g_ctx->lastUIButtonActivated != entt::null) return g_ctx->lastUIButtonActivated;
        return lastUIButtonActivated;
    }

    void setLastUIButtonActivated(entt::entity e) {
        lastUIButtonActivated = e;
        if (g_ctx) g_ctx->lastUIButtonActivated = e;
    }

    const std::string& getLastLoadingStage() {
        if (g_ctx && !g_ctx->lastLoadingStage.empty()) return g_ctx->lastLoadingStage;
        return lastLoadingStage;
    }

    bool getLastLoadingStageSuccess() {
        if (g_ctx) return g_ctx->lastLoadingStageSuccess;
        return lastLoadingStageSuccess;
    }

    void setLastLoadingStage(const std::string& stageId, bool success) {
        lastLoadingStage = stageId;
        lastLoadingStageSuccess = success;
        if (g_ctx) {
            g_ctx->lastLoadingStage = stageId;
            g_ctx->lastLoadingStageSuccess = success;
        }
    }

    const std::vector<CollisionNote>& getCollisionLog() {
        static std::vector<CollisionNote> cache;
        cache.assign(collisionLog.begin(), collisionLog.end());
        return cache;
    }

    void pushCollisionLog(const CollisionNote& note) {
        if (collisionLog.size() >= kCollisionLogMax) {
            collisionLog.pop_front();
        }
        collisionLog.push_back(note);
    }
}
