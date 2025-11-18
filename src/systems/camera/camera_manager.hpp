// camera_manager.hpp
#pragma once

#include <cassert>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

#include "raylib.h"
#include "util/common_headers.hpp"
#include "custom_camera.hpp"    // your GameCamera class

namespace camera_manager {

    // ------------------------------------------------------------------
    // Internals
    // ------------------------------------------------------------------

    // are we currently between a Begin() and End()?
    inline bool        s_active     = false;

    // pointer to the raw Raylib Camera2D currently in use
    inline Camera2D*   s_camera     = nullptr;

    // Optional stack of raw Camera2D* for nested usage
    inline std::vector<Camera2D*> s_stack;

    // named registry of GameCamera instances
    inline std::unordered_map<std::string, std::shared_ptr<GameCamera>> s_cameras;
    
    

    // ------------------------------------------------------------------
    // Creation / lookup / removal
    // ------------------------------------------------------------------

    /// Create a new GameCamera under `name`.  Overwrites if existing.
    inline void Create(const std::string &name, entt::registry &reg) {
        s_cameras[name] = std::make_shared<GameCamera>(reg);
    }

    /// Fetch the GameCamera by name (asserts if missing)
    inline std::shared_ptr<GameCamera> Get(const std::string &name) {
        auto it = s_cameras.find(name);
        assert(it != s_cameras.end() && "camera_manager::Get(): no camera by that name");
        return it->second;
    }

    /// Remove (and destroy) the camera with that name
    inline void Remove(const std::string &name) {
        s_cameras.erase(name);
    }

    /// Does a camera by this name exist?
    inline bool Exists(const std::string &name) {
        return s_cameras.find(name) != s_cameras.end();
    }

    
    
    // ------------------------------------------------------------------
    // Update methods
    // ------------------------------------------------------------------

    /**
     * @brief Update a single named camera with delta time.
     */
    inline void Update(const std::string &name, float dt) {
        auto cam = Get(name);
        cam->Update(dt);
    }

    /**
     * @brief Update all managed cameras with delta time.
     */
    inline void UpdateAll(float dt) {
        for (auto &kv : s_cameras) {
            kv.second->Update(dt);
        }
    }

    // ------------------------------------------------------------------
    // Begin / End by raw Camera2D
    // ------------------------------------------------------------------

    /// Begin 2D mode if not already active, with the given Camera2D
    inline void Begin(Camera2D &cam) {
        if (!s_active) {
            ::BeginMode2D(cam);
            s_active = true;
            s_camera = &cam;
            s_stack.push_back(&cam);
        }
        else {
            // nested with the same cam is allowed if you REALLY need it.
            assert(s_camera == &cam && "CameraManager::Begin: mixing different Camera2D in nested calls");
            s_stack.push_back(&cam);
        }
    }

    /// End 2D mode if it was active; handles nesting
    inline void End() {
        assert(s_active && "CameraManager::End() called without matching Begin()");
        s_stack.pop_back();
        if (s_stack.empty()) {
            ::EndMode2D();
            s_active = false;
            s_camera = nullptr;
        }
        else {
            // resume the previous one (rare)
            s_camera = s_stack.back();
        }
    }

    // query functions
    inline bool      IsActive() { return s_active; }
    inline Camera2D* Current()  { return s_camera; }

    //------------------------------------------------------------------------------------
    // FIX: RAII Guard for Camera State Management
    //------------------------------------------------------------------------------------
    /// RAII guard that temporarily disables camera if it's active, then restores it
    class CameraGuard {
    private:
        Camera2D* savedCamera = nullptr;
        bool wasActive = false;
        
    public:
        CameraGuard() = default;
        
        /// Disable camera if active, save state for restoration
        void disable() {
            if (wasActive) {
                SPDLOG_WARN("CameraGuard: Already disabled!");
                return;
            }
            
            if (IsActive()) {
                savedCamera = Current();
                SPDLOG_DEBUG("CameraGuard: Disabling camera at ({}, {}), zoom={}, rotation={}", 
                    savedCamera->offset.x, savedCamera->offset.y, savedCamera->zoom, savedCamera->rotation);
                End();
                wasActive = true;
            } else {
                SPDLOG_DEBUG("CameraGuard: No active camera to disable");
            }
        }
        
        /// Manually restore camera state
        void restore() {
            if (wasActive && savedCamera) {
                SPDLOG_DEBUG("CameraGuard: Restoring camera at ({}, {}), zoom={}, rotation={}", 
                    savedCamera->offset.x, savedCamera->offset.y, savedCamera->zoom, savedCamera->rotation);
                Begin(*savedCamera);
                wasActive = false;
                savedCamera = nullptr;
            } else if (wasActive) {
                SPDLOG_WARN("CameraGuard: Cannot restore - savedCamera is null!");
            }
        }
        
        /// RAII cleanup - automatically restores camera
        ~CameraGuard() {
            if (wasActive && savedCamera) {
                SPDLOG_DEBUG("CameraGuard: Destructor restoring camera at ({}, {})", 
                    savedCamera->offset.x, savedCamera->offset.y);
                Begin(*savedCamera);
            } else if (wasActive) {
                SPDLOG_ERROR("CameraGuard: Destructor - wasActive but savedCamera is null! Camera state corrupted!");
            }
        }
        
        // Non-copyable, non-movable
        CameraGuard(const CameraGuard&) = delete;
        CameraGuard& operator=(const CameraGuard&) = delete;
        CameraGuard(CameraGuard&&) = delete;
        CameraGuard& operator=(CameraGuard&&) = delete;
        
        bool isDisabled() const { return wasActive; }
    };

    // ------------------------------------------------------------------
    // Overloads by camera name
    // ------------------------------------------------------------------

    /// Begin using the named GameCamera
    inline void Begin(const std::string &name) {
        auto cam = Get(name);
        Begin(cam->cam);
    }

    /// End the current named camera
    inline void EndNamed() {
        End();
    }

    // ------------------------------------------------------------------
    // RAII helpers
    // ------------------------------------------------------------------

    /// Guard for raw Camera2D
    struct Guard {
        Guard(Camera2D &cam)  { Begin(cam); }
        ~Guard()              { End(); }
        Guard(const Guard&) = delete;
        Guard& operator=(const Guard&) = delete;
    };

    /// Guard for named GameCamera
    struct NamedGuard {
        NamedGuard(const std::string &name) : _name(name) { Begin(name); }
        ~NamedGuard()                   { End(); }
        NamedGuard(const NamedGuard&) = delete;
        NamedGuard& operator=(const NamedGuard&) = delete;
    private:
        std::string _name;
    };

} // namespace camera_manager
