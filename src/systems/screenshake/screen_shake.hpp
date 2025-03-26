
#pragma once

#include "raylib.h"
#include <cstdlib>

//portable screen shake implementation, just apply the offset to the camera target

namespace screenshake {
    
    struct ScreenShake
    {
        float duration = 0.0f;                 // Remaining shake duration
        float intensity = 0.0f;                // Shake intensity
        Vector2 offset = {0.0f, 0.0f};         // Current shake offset
        Vector2 originalTarget = {0.0f, 0.0f}; // Original camera target
        bool isShaking = false;                // Indicates if shake is active
    };

    ScreenShake screenShake;
    // Function to start the screen shake
    inline void StartScreenShake(float intensity, float duration)
    {
        screenShake.intensity = intensity;
        screenShake.duration = duration;
        screenShake.offset = {0.0f, 0.0f};
    }

    inline void UpdateScreenShake(Camera2D &camera, float deltaTime)
    {
        if (screenShake.duration > 0.0f)
        {
            // Save original target if not already shaking
            if (!screenShake.isShaking)
            {
                screenShake.originalTarget = camera.target;
                screenShake.isShaking = true;
            }

            // Generate random offsets for the shake
            screenShake.offset.x = (float)((rand() % 200 - 100) / 100.0) * screenShake.intensity;
            screenShake.offset.y = (float)((rand() % 200 - 100) / 100.0) * screenShake.intensity;

            // Apply the shake offset to the camera
            camera.target = {
                screenShake.originalTarget.x + screenShake.offset.x,
                screenShake.originalTarget.y + screenShake.offset.y};

            // Reduce duration over time
            screenShake.duration -= deltaTime;
        }
        else if (screenShake.isShaking)
        {
            // Reset camera to its original position when shake ends
            camera.target = screenShake.originalTarget;
            screenShake.offset = {0.0f, 0.0f};
            screenShake.intensity = 0.0f;
            screenShake.isShaking = false;
        }
    }
}