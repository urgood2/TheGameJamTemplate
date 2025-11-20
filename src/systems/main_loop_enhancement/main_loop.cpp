
#include "main_loop.hpp"
#include "raylib.h"

#include <optional>

namespace main_loop
{
    Data mainLoop{};

    void initMainLoopData(std::optional<int> fps, std::optional<int> ups)
    {
        if (fps.has_value())
            mainLoop.framerate = fps.value();
        else
            mainLoop.framerate = GetMonitorRefreshRate(GetCurrentMonitor()); // Monitor refresh rate

        if (mainLoop.framerate == 0) {
            // set to 60 fps
            mainLoop.framerate = 120;
        }
        
        // if (ups.has_value())
        //     mainLoop.rate = 1.0f / ups.value();
        // else
        //     mainLoop.rate = 1.0f / 60.0f; // Fixed timestep (60 updates per second)
    }
} // namespace main_loop