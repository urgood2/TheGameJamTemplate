#include "systems/ai/ai_system.hpp"
#include "systems/input/input_functions.hpp"
#include "systems/layer/layer.hpp"
#include "systems/physics/transform_physics_hook.hpp"
#include "third_party/rlImGui/imgui.h"
#include "third_party/rlImGui/imgui_internal.h"
#include "third_party/rlImGui/rlImGui.h"
#define RAYGUI_IMPLEMENTATION // needed to use raygui

#define _WIN32_WINNT 0x0600

#include "raylib.h"      // raylib
#include "entt/entt.hpp" // ECS
// #include "tweeny.h"      // tweening library

// #define TRACY_NO_CALLSTACK  // disable callstack capturing in tracy for lua code to work.
// #undef TRACY_HAS_CALLSTACK
#include "third_party/tracy-master/public/tracy/Tracy.hpp"



#if defined(_WIN32)
#define NOGDI  // All GDI defines and routines
#define NOUSER // All USER defines and routines
#endif

#define SPDLOG_ACTIVE_LEVEL SPDLOG_LEVEL_TRACE // compiler-time log level

#include "spdlog/spdlog.h" // SPD logging lib // or any library that uses Windows.h
#include "spdlog/sinks/basic_file_sink.h"
#include "spdlog/sinks/stdout_color_sinks.h" // or any library that uses Windows.h

#include "util/common_headers.hpp" // common headers like json, spdlog, etc.

#if defined(_WIN32) // raylib uses these names as function parameters
#undef near
#undef far
#endif

#if defined(PLATFORM_WEB)
#include <emscripten/emscripten.h>
#endif

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif

#include "effolkronium/random.hpp"   // https://github.com/effolkronium/random

#include "core/init.hpp"
#include "core/graphics.hpp"
#include "core/game.hpp"
#include "core/gui.hpp"
#include "core/globals.hpp"

#include "util/utilities.hpp" // global utilty methods

#define JSON_DIAGNOSTICS 1
#include <nlohmann/json.hpp> // nlohmann JSON parsing
using json = nlohmann::json;

#include <fmt/core.h>                 // https://github.com/fmtlib/fmt
// #include <boost/stacktrace.hpp> // stack trace

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
#include <algorithm> 
#include <numeric>

// #define SPINE_USE_STD_FUNCTION
// #include "spine/spine.h"
// #include "third_party/spine_impl/spine_raylib.hpp"

#include "raymath.h"

// #include "systems/physics/physics_world.hpp"
#include "systems/main_loop_enhancement/main_loop.hpp"
#include "systems/shaders/shader_system.hpp"
#include "systems/shaders/shader_pipeline.hpp"
#include "systems/anim_system.hpp"
#include "systems/input/input.hpp"
#include "systems/timer/timer.hpp"
#include "systems/sound/sound_system.hpp"
#include "systems/layer/layer_optimized.hpp"
#include "systems/localization/localization.hpp"
#include "systems/scripting/scripting_system.hpp"
#include "systems/fade/fade_system.hpp"
#include "systems/palette/palette_quantizer.hpp"



using std::string, std::unique_ptr, std::vector;
using namespace std::literals;
// using namespace BT;
using Random = effolkronium::random_static; // get base random alias which is auto seeded and has static API and internal state

// update methods
auto updateSystems(float dt) -> void;

auto updateTimers(float dt) -> void
{
    globals::G_TIMER_REAL += dt;
    globals::G_TIMER_TOTAL += dt;
}


bool pauseGameWhenOutofFocus = true;
bool updatedGame = false;
auto mainGameStateGameLoop(float dt) -> void
{

    // updatedGame = false;
    // bool shouldPauseFromNoFocus = (pauseGameWhenOutofFocus == true && IsWindowFocused() == false);
    // if (shouldPauseFromNoFocus == false && game::isGameOver == false)
    // {
        game::update(dt);
        // updatedGame = true;
        // if (game::isPaused == false)
    // }
}

void mainMenuStateGameLoop(float dt)
{
    
    // FIXME: just set game to main game state for now
    globals::currentGameState = GameState::MAIN_GAME;
    // show main menu here
}

void MainLoopFixedUpdateAbstraction(float dt)
{
    ZoneScopedN("MainLoopFixedUpdateAbstraction"); // custom label
    
    updateSystems(dt);

    // this switch statement handles only update logic, rendering is handled in the mainloopRenderAbstraction function
    switch (globals::currentGameState)
    {
    case GameState::MAIN_MENU:
        // show main menu
        mainMenuStateGameLoop(dt);
        break;
    case GameState::MAIN_GAME:
        // show main game screen
        mainGameStateGameLoop(dt);
        break;
    case GameState::GAME_OVER:
        // show game over screen
        mainGameStateGameLoop(dt);
        break;
    default:
        globals::currentGameState = GameState::MAIN_MENU;
        break;
    }
    
    // finalize input state at end of frame
    input::finalizeUpdateAtEndOfFrame(globals::inputState, dt);
    
    // physics post-update
    globals::physicsManager->stepAllPostUpdate(dt);
}



auto mainGameStateGameLoopRender(float dt) -> void {
    game::draw(dt);
}



auto mainMenuStateGameLoopRender(float dt) -> void {

}

bool mainMenuFirstFrame{true}; // used to determine if this is the first frame of the main menu
auto mainMenuStateGameLoop() -> void
{

}

auto loadingScreenStateGameLoopRender(float dt) -> void
{
    // show loading screen

    BeginDrawing();
    ClearBackground(RAYWHITE);
    DrawText("Loading...", 20, 20, 40, LIGHTGRAY);
    EndDrawing();
}

auto gameOverScreenGameLoopRender(float dt) -> void
{

    // gui::showGameOverModal();
    // ends the ImGui content mode. Make all ImGui calls before this
}


auto MainLoopRenderAbstraction(float dt) -> void {
    
    
    switch (globals::currentGameState)
    {
    case GameState::MAIN_MENU:
        mainMenuStateGameLoopRender(dt); 
        break;
    case GameState::MAIN_GAME:
        mainGameStateGameLoopRender(dt);
        break;
    case GameState::LOADING_SCREEN:
        loadingScreenStateGameLoopRender(dt);
        break;
    case GameState::GAME_OVER:
        gameOverScreenGameLoopRender(dt);
        break;
    default:
        // draw nothing
        break;
    }
    
    


}
// The main game loop function that runs until the application or window is closed.
// The main game loop callback / blocking loop
void RunGameLoop()
{
    using namespace main_loop;

    // ---------- Initialization ----------
    float lastFrameTime = GetTime();

    // Optional frame smoothing
    const int frameSmoothingCount = 10;
    std::deque<float> frameTimes;

    // FPS tracking
    int frameCounter = 0;
    double fpsLastTime = GetTime();

    // Fixed time step (LÖVE uses display refresh or 1/60)
    const float fixedDelta = mainLoop.rate; // e.g., 1/60.0f
    float accumulator = fixedDelta;

#ifndef __EMSCRIPTEN__
    while (!WindowShouldClose())
    {
        ZoneScopedN("RunGameLoop");
#endif
        // ---------- Step 1: Begin Drawing ----------
        {
            ZoneScopedN("BeginDrawing/rlImGuiBegin call");
            BeginDrawing();
#ifndef __EMSCRIPTEN__
            if (globals::useImGUI)
                rlImGuiBegin();
#endif
        }

        // ---------- Step 2: Measure real delta ----------
        float rawDeltaTime = std::max(GetFrameTime(), 0.001f);
        frameTimes.push_back(rawDeltaTime);
        if (frameTimes.size() > frameSmoothingCount)
            frameTimes.pop_front();
        float deltaTime = std::accumulate(frameTimes.begin(), frameTimes.end(), 0.0f) / frameTimes.size();

        // ---------- Step 3: Update timers ----------
        mainLoop.realtimeTimer += deltaTime;
        if (!globals::isGamePaused)
            mainLoop.totaltimeTimer += deltaTime;

        // ---------- Step 4: Fixed-step accumulator ----------
        accumulator += deltaTime;

        // Run updates while we have enough accumulated time
        while (accumulator >= fixedDelta)
        {
            ZoneScopedN("FixedUpdate");
            MainLoopFixedUpdateAbstraction(fixedDelta * mainLoop.timescale);

            accumulator -= fixedDelta;
            mainLoop.updates++;
            mainLoop.frame++;
        }

        // ---------- Step 5: Render (no interpolation, just latest state) ----------
        // ZoneScopedN("Render");
        MainLoopRenderAbstraction(deltaTime * mainLoop.timescale); // LÖVE doesn't interpolate, so alpha=1

        // ---------- Step 6: Update render timers ----------
        timer::TimerSystem::update_render_timers(deltaTime * mainLoop.timescale);

        // ---------- Step 7: FPS counter ----------
        frameCounter++;
        double now = GetTime();
        if (now - fpsLastTime >= 1.0)
        {
            mainLoop.renderedFPS = frameCounter;
            frameCounter = 0;
            fpsLastTime = now;
        }

        // ---------- Step 8: End Drawing ----------
        {
            ZoneScopedN("EndDrawing/rlImGuiEnd call");
#ifndef __EMSCRIPTEN__
            if (globals::useImGUI)
                rlImGuiEnd();
#endif
            EndDrawing();
        }

        mainLoop.renderFrame++; // one frame rendered

        // ---------- Step 9: Sleep / yield (like love.timer.sleep) ----------
        WaitTime(0.001f); // optional: avoids pegging 100% CPU on fast frames

#ifdef __EMSCRIPTEN__
        // no loop for web
#else
    } // while (!WindowShouldClose())
#endif
}




int main(void)
{

    // --------------------------------------------------------------------------------------
    // game init
    // --------------------------------------------------------------------------------------

    init::base_init();
    
    layer::InitDispatcher();

    SetTargetFPS(main_loop::mainLoop.framerate); 

    SetExitKey(-1);

    init::startInit();
    main_loop::initMainLoopData(std::nullopt, 60); // match monitor refresh rate for fps, 60 ups
    

    input::Init(globals::inputState);

    game::init();
    
    
    //gamepad connected? just connect gamepad 0
    if (IsGamepadAvailable(0)) {
        input::SetCurrentGamepad(globals::inputState, GetGamepadName(0), 0);
    }
    
    // --------------------------------------------------------------------------------------
    // game loop
    // --------------------------------------------------------------------------------------

    // audio::SetMusic(MENU_MUSIC1);

    SPDLOG_INFO("Starting game loop...");
#ifdef __EMSCRIPTEN__

    emscripten_set_main_loop(RunGameLoop, 0, 1);
#else

    // try {
    
    // Main game loop
    while (!WindowShouldClose())
    { // Detect window close button or ESC key
        // FrameMark; // marks one frame
        RunGameLoop();
    }

#endif
    // De-Initialization

    //TODO: unload all textures & sprite atlas & sounds
    //TODO: unload all layer commands as welll.
    palette_quantizer::unloadPaletteTexture(); // unload palette texture if any
    layer::UnloadAllLayers();
    shaders::unloadShaders();
    sound_system::Unload();
    shader_pipeline::ShaderPipelineUnload();

    // after your game loop is over, before you close the window
    rlImGuiShutdown(); // cleans up ImGui

    CloseAudioDevice(); // Close audio device

    //--------------------------------------------------------------------------------------
    CloseWindow(); // Close window and OpenGL context
    //--------------------------------------------------------------------------------------

    return 0;
}

/// @brief Update the systems that operate on ECS components. Note: dt is in seconds
/// @return
auto updateSystems(float dt) -> void
{
    ZoneScopedN("UpdateSystems"); // custom label
    
    // clear layers
    {
        ZoneScopedN("layer::Begin");
        layer::Begin(); // clear all commands so we begin fresh next frame, and also let draw commands from update loop to show up when rendering (update is called before draw). we do this in update rather than draw since draw will execute more often than update.
    }
    
    {
        ZoneScopedN("Input System Update");
        updateTimers(dt); // these are used by event queue system (TODO: replace with mainloop abstraction)
        fade_system::update(dt); // update fade system
    }
    
    {
        ZoneScopedN("Input System Update");
        input::Update(globals::registry, globals::inputState, dt);
    }
    
    {
        ZoneScopedN("Global Variables Update & sound");
        globals::updateGlobalVariables();
        sound_system::Update(main_loop::mainLoop.rawDeltaTime); // update sound system, ignore slowed DT here.
    }
    
    {
        ZoneScopedN("Physics Transform Hook ApplyAuthoritativeTransform");
        physics::ApplyAuthoritativeTransform(globals::registry, *globals::physicsManager);
    }
    
    {
        ZoneScopedN("Physics Step All Worlds");
        globals::physicsManager->stepAll(dt); // step all physics worlds
    }
    
    {
        ZoneScopedN("Physics Transform Hook ApplyAuthoritativePhysics");
        physics::ApplyAuthoritativePhysics(globals::registry, *globals::physicsManager);
    }
    
    // systems
    
    shaders::update(dt);
    timer::TimerSystem::update_timers(dt);
    spring::updateAllSprings(globals::registry, dt);
    animation_system::update(dt);
    transform::ExecuteCallsForTransformMethod<void>(globals::registry, entt::null, transform::TransformMethod::UpdateAllTransforms, &globals::registry, dt);
    
    {
        ZoneScopedN("EventQueueSystem::EventManager::update");
        // update event queue
        timer::EventQueueSystem::EventManager::update(dt);
    }
    
    {
        ZoneScopedN("scripting::monobehavior_system::update");
        scripting::monobehavior_system::update(globals::registry, dt); // update all monobehavior scripts in the registry
    }
    {
        ZoneScopedN("AI System Update");
        ai_system::masterScheduler.update(static_cast<ai_system::fsec>(dt)); // update the AI system scheduler
    }
    
    {
        ZoneScopedN("ai_system::updateHumanAI");
        ai_system::updateHumanAI(dt); // update the GOAP AI system for creatures
    }
}
