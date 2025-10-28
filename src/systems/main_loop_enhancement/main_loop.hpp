#pragma once

#include <optional>
#include <string>
#include "systems/scripting/binding_recorder.hpp"

// just some data for the main loop
namespace main_loop
{
    struct Data
    {
        float rawDeltaTime = 0.0f;      // Raw delta time for the current frame.
        float smoothedDeltaTime = 0.0f; // Smoothed delta time for the current frame.
        float realtimeTimer = 0.0f;    // Realtime timer since start of game
        float totaltimeTimer = 0.0f;   // Total time since start of game, excluding pauses
        
        

        float timescale = 1.0f;    // Time scale for updates
        float rate = 1.0f / 120.0f; // Fixed timestep (e.g., 60 updates per second)
        float lag = 0.0f;          // Accumulated time
        float maxFrameSkip = 5.0f; // Maximum frames to skip
        int frame = 0;             // fixed update frame count
        int renderFrame = 0;         // total rendered frames since start

        float framerate = 240.0f;  // Desired framerate
        float sleepTime = 0.001f;  // Sleep duration to prevent CPU hogging

        int updates = 0;           // Updates in the current second
        int renderedUPS = 0;       // Displayed updates per second (running average)
        int renderedFPS = 0;       // Displayed frames per second (running average)
        float updateTimer = 0.0f;  // Timer to calculate UPS every second
        
        int physicsTicks = 0;    // Number of physics ticks
    };

    extern Data mainLoop;

    extern void initMainLoopData(std::optional<int> fps, std::optional<int> ups);
    
    // Returns the total scaled game time (in seconds)
    inline auto getTime() -> float
    {
        // timescale affects the perceived time in-game
        return mainLoop.totaltimeTimer;
    }

    // Returns real (unscaled) elapsed time
    inline auto getRealTime() -> float
    {
        return mainLoop.realtimeTimer;
    }

    // Returns delta time for current frame (smoothed)
    inline auto getDelta() -> float
    {
        return mainLoop.smoothedDeltaTime * mainLoop.timescale;
    }
    
    inline auto exposeToLua(sol::state &lua) -> void
    {
        using namespace main_loop;
        auto &rec = BindingRecorder::instance();

        lua["main_loop"] = sol::table(lua, sol::create);

        lua.new_usertype<Data>(
            "MainLoopData",
            "smoothedDeltaTime", &Data::smoothedDeltaTime,
            "realtimeTimer", &Data::realtimeTimer,
            "totaltimeTimer", &Data::totaltimeTimer,
            "timescale", &Data::timescale,
            "rate", &Data::rate,
            "lag", &Data::lag,
            "maxFrameSkip", &Data::maxFrameSkip,
            "frame", &Data::frame,
            "renderFrame", &Data::renderFrame,
            "framerate", &Data::framerate,
            "sleepTime", &Data::sleepTime,
            "updates", &Data::updates,
            "renderedUPS", &Data::renderedUPS,
            "renderedFPS", &Data::renderedFPS,
            "updateTimer", &Data::updateTimer,
            "physicsTicks", &Data::physicsTicks
        );

        rec.add_type("MainLoopData").doc =
            "Holds timing, frame rate, and delta-time state for the main game loop.";

        rec.record_property("MainLoopData", {"smoothedDeltaTime", "float", "Smoothed delta time for the current frame."});
        rec.record_property("MainLoopData", {"realtimeTimer", "float", "Real-time timer since game start (unscaled)."});
        rec.record_property("MainLoopData", {"totaltimeTimer", "float", "Total accumulated in-game time excluding pauses."});
        rec.record_property("MainLoopData", {"timescale", "float", "Scaling factor applied to delta time (1.0 = normal speed)."});
        rec.record_property("MainLoopData", {"rate", "float", "Fixed timestep in seconds (default 1/60)."});
        rec.record_property("MainLoopData", {"lag", "float", "Accumulated lag between fixed updates."});
        rec.record_property("MainLoopData", {"maxFrameSkip", "float", "Maximum number of fixed updates processed per frame."});
        rec.record_property("MainLoopData", {"frame", "int", "Frame counter since start of the game."});
        rec.record_property("MainLoopData", {"framerate", "float", "Target rendering frame rate."});
        rec.record_property("MainLoopData", {"sleepTime", "float", "Sleep duration per frame to prevent CPU hogging."});
        rec.record_property("MainLoopData", {"updates", "int", "Number of logic updates in the current second."});
        rec.record_property("MainLoopData", {"renderedUPS", "int", "Smoothed updates per second (running average)."});
        rec.record_property("MainLoopData", {"renderedFPS", "int", "Smoothed frames per second (running average)."});
        rec.record_property("MainLoopData", {"updateTimer", "float", "Timer used to compute UPS over time."});

        // ─────────────────────────────────────────────
        // Global instance and helper functions
        // ─────────────────────────────────────────────
        lua["main_loop"]["data"] = std::ref(mainLoop);
        rec.record_property("main_loop", {"data", "MainLoopData", "Global main loop data instance (live reference)."});

        lua["main_loop"]["init"] = &initMainLoopData;
        rec.record_property("main_loop", {"init", "function(fps?: int, ups?: int)", "Initialize main loop data with optional FPS and UPS values."});

        // ─────────────────────────────────────────────
        // Your replacement for Raylib's GetTime()
        // ─────────────────────────────────────────────
        lua["main_loop"]["getTime"] = &getTime;
        lua["main_loop"]["getRealTime"] = &getRealTime;
        lua["main_loop"]["getDelta"] = &getDelta;

        rec.record_property("main_loop", {"getTime", "function(): number", "Get total scaled game time in seconds (replaces Raylib's GetTime)."});
        rec.record_property("main_loop", {"getRealTime", "function(): number", "Get total real (unscaled) elapsed time in seconds."});
        rec.record_property("main_loop", {"getDelta", "function(): number", "Get scaled delta time for the current frame."});
    }



} // namespace main_loop

