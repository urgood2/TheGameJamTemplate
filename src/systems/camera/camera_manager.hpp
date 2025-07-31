// camera_manager.hpp
#pragma once
#include "raylib.h"

#include "util/common_headers.hpp"

namespace camera_manager {

    // Tracks whether we’ve called BeginMode2D and with which camera
    inline bool        s_active = false;
    inline Camera2D*   s_camera = nullptr;

    // Begin 2D mode if not already active, with the given camera
    inline void Begin(Camera2D& cam) {
        if (!s_active) {
            ::BeginMode2D(cam);
            s_active = true;
            s_camera = &cam;
        }
        else {
            // if you want to assert that you don't switch cameras mid-stream:
            assert(s_camera == &cam && "CameraManager::Begin called with a different camera");
        }
    }

    // End 2D mode if it was active
    inline void End() {
        if (s_active) {
            ::EndMode2D();
            s_active = false;
            s_camera = nullptr;
        }
    }

    // Query functions
    inline bool     IsActive()   { return s_active; }
    inline Camera2D* Current()   { return s_camera; }

    // A little RAII guard so you can write:
    //   { Camera2DGuard guard(myCam);  /* do world draws */ }
    struct Guard {
        Guard(Camera2D& cam) { Begin(cam); }
        ~Guard()             { End();   }
        // non-copyable
        Guard(const Guard&) = delete;
        Guard& operator=(const Guard&) = delete;
    };

} // namespace CameraManager