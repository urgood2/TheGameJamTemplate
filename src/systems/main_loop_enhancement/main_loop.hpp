#pragma once

#include <optional>

// just some data for the main loop
namespace main_loop
{
    struct Data
    {
        float smoothedDeltaTime = 0.0f; // Smoothed delta time for the current frame.
        float realtimeTimer = 0.0f;    // Realtime timer since start of game
        float totaltimeTimer = 0.0f;   // Total time since start of game, excluding pauses

        float timescale = 1.0f;    // Time scale for updates
        float rate = 1.0f / 60.0f; // Fixed timestep (e.g., 60 updates per second)
        float lag = 0.0f;          // Accumulated time
        float maxFrameSkip = 5.0f; // Maximum frames to skip
        int frame = 0;             // Frame counter
        float framerate = 240.0f;  // Desired framerate
        float sleepTime = 0.001f;  // Sleep duration to prevent CPU hogging

        int updates = 0;           // Updates in the current second
        int renderedUPS = 0;       // Displayed updates per second (running average)
        int renderedFPS = 0;       // Displayed frames per second (running average)
        float updateTimer = 0.0f;  // Timer to calculate UPS every second
    };

    extern Data mainLoop;

    extern void initMainLoopData(std::optional<int> fps, std::optional<int> ups);

} // namespace main_loop

