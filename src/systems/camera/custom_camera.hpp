/**
 * @file GameCamera.hpp
 * @brief Smooth 2D camera controller for Raylib-based games using EnTT springs.
 *
 * This camera system provides:
 *   - Spring-based smoothing for position, zoom, rotation, and offset.
 *   - Multiple follow styles with configurable deadzones and lead.
 *   - World bounds clamping to restrict camera movement.
 *   - Full-screen flash and fade effects with callbacks.
 *
 * Usage:
 *   1. Instantiate with your EnTT registry:
 *        GameCamera camera(registry);
 *   2. In your render loop:
 *        camera.Begin();
 *        // draw your world here
 *        camera.End(overlayLayer);
 *   3. Update each frame with delta time:
 *        camera.Update(deltaTime);
 *
 * @author
 * @date
 */

#pragma once

#include <algorithm>            // std::min/max for calculations
#include <functional>           // std::function for callbacks
#include <memory>               // std::shared_ptr

#include <entt/entt.hpp>        // EnTT ECS registry
#include "raylib.h"             // Raylib types and functions

#include "spdlog/spdlog.h"
#include "systems/main_loop_enhancement/main_loop.hpp"
#include "systems/spring/spring.hpp"                  // Spring component definition
#include "systems/layer/layer.hpp"                    // Layer drawing abstraction
#include "systems/layer/layer_command_buffer.hpp"     // Buffered draw commands

// Clamp a float between min and max
static inline float ClampF(float v, float mn, float mx) {
    return (v < mn ? mn : (v > mx ? mx : v));
}

// shortest‐angle lerp in degrees
static inline float LerpAngle(float from, float to, float t) {
    float diff = fmodf((to - from) + 180.f, 360.f) - 180.f;
    return from + diff * t;
}

// Camera follow behavior modes
enum class FollowStyle {
    LOCKON,             ///< Always center target in view
    PLATFORMER,         ///< Lower deadzone, platformer-style follow
    TOPDOWN,            ///< Loose deadzone for top-down view
    TOPDOWN_TIGHT,      ///< Tighter deadzone for precise top-down
    SCREEN_BY_SCREEN,   ///< Jump camera by whole-screen increments
    NONE                ///< No automatic follow
};

// Alias for spring component
using Spring = spring::Spring;

struct ShakeStruct {
    float amplitude;
    float duration;
    float frequency;
    std::vector<float> samples;
    float elapsedTime = 0.0f;
    bool shaking     = true;

    ShakeStruct(float amp, float dur, float freq)
      : amplitude(amp)
      , duration(dur)
      , frequency(freq)
    {
        int count = static_cast<int>(duration * frequency);
        samples.reserve(count+1);
        for(int i = 0; i < count; ++i) {
            // random float in [-1..1]
            samples.push_back(2.0f * (static_cast<float>(rand()) / RAND_MAX) - 1.0f);
        }
    }

    void Update(float dt) {
        if(!shaking) return;
        // elapsedTime += dt;
        // let's used unscaled time for shake
        elapsedTime += main_loop::mainLoop.rawDeltaTime;
        if(elapsedTime >= duration) shaking = false;
    }

    float GetNoise(int idx) const {
        return (idx >= 0 && idx < (int)samples.size()) ? samples[idx] : 0.0f;
    }

    float GetDecay() const {
        return (elapsedTime > duration)
             ? 0.0f
             : (duration - elapsedTime) / duration;
    }

    float GetAmplitude() const {
        if(!shaking) return 0.0f;
        float s  = elapsedTime * frequency;
        int   s0 = static_cast<int>(floorf(s));
        int   s1 = s0 + 1;
        float k  = GetDecay();
        float n0 = GetNoise(s0);
       float n1 = GetNoise(s1);
        float interp = n0 + (s - s0) * (n1 - n0);
        return amplitude * interp * k;
    }
};

/**
 * @class GameCamera
 * @brief Manages a 2D camera with smoothing, follow logic, bounds, and visual effects.
 *
 * Integrates Raylib's Camera2D with EnTT-based springs to smoothly interpolate:
 *   - Camera target (position)
 *   - Zoom
 *   - Rotation
 *   - Offset
 *
 * Supports:
 *   - Multiple follow styles (lock-on, platformer, top-down, screen-by-screen)
 *   - Configurable deadzone and lead (lookahead)
 *   - World bounds clamping
 *   - Flash and fade overlays with durations and callbacks
 */
class GameCamera {
public:
    Camera2D cam{ {0,0}, {0,0}, 0.0f, 1.0f };  ///< Raylib camera: {offset, target, rotation, zoom}

    // --- Follow / deadzone settings ---
    Rectangle deadzone{0,0,0,0};   ///< Screen-space deadzone rectangle
    bool useDeadzone = false;      ///< Enable deadzone logic?
    FollowStyle style = FollowStyle::NONE;  ///< Current follow mode
    float followLerpX = 1.0f, followLerpY = 1.0f;  ///< Lerp amounts for X/Y movement
    float followLeadX = 0.0f, followLeadY = 0.0f;  ///< Lead multipliers for lookahead
    
    // -- Offset damping/strafing settings ---
    float strafeTiltAngle = 0.0f;  // updated each frame
    // keep track of previous frame’s actual target to compute velocity
    Vector2 prevActualTarget{0,0};
    /// fraction of screen width/height before damping kicks in
    float offsetThreshX = 0.24f, offsetThreshY = 0.24f;
    /// max camera‐target offset speed (world units/sec)
    float maxOffsetX   = 200.0f,  maxOffsetY   =  200.0f;
    /// maximum tilt angle in degrees
    float tiltAngle         = 0.5f;  // ≈1.4°
    /// how quickly to tilt toward max (per second)
    float tiltSpeed         =  8.0f;
    /// how quickly to recover back to 0° (per second)
    float tiltRecoverSpeed  =  2.0f;
    float maxExpectedVelocityX = 100.0f;  // Tweak based on gameplay feel
    Vector2 offset = { 0.0f, 0.0f };  // persistent across frames
    float offsetDecayRate = 5.0f;     // higher = faster decay
    float offsetAmplify   = 2.f;     // how much to respond to velocity
    float maxOffsetVel    = 100.0f;   // clamp velocity
    bool enableOffsetDamping = true;
    bool enableStrafeTilt   = true;

    
    // --- noise-based shake storage ---
    std::vector<ShakeStruct> shakesX, shakesY;
    float shakeOffsetX = 0.0f, shakeOffsetY = 0.0f;

    // --- World bounds clamping ---
    Rectangle bounds{0,0,0,0};     ///< World-space bounds rectangle
    bool useBounds = false;        ///< Enable world bounds clamping?

    // --- Flash effect settings ---
    bool flashing = false;         ///< Is flash active?
    float flashTimer = 0.0f;       ///< Elapsed time for flash
    float flashDuration = 0.0f;    ///< Total duration for flash
    Color flashColor{0,0,0,0};     ///< Current flash overlay color

    // --- Fade effect settings ---
    bool fading = false;           ///< Is fade active?
    float fadeTimer = 0.0f;        ///< Elapsed time for fade
    float fadeDuration = 0.0f;     ///< Total duration for fade
    Color fadeStart{0,0,0,0};      ///< Starting color for fade
    Color fadeTarget{0,0,0,0};     ///< Target color for fade
    std::function<void()> fadeAction;   ///< Callback after fade completes

    // --- ECS registry & spring entities for smoothing ---
    entt::registry &registry;      ///< Reference to the EnTT registry
    entt::entity springTargetX;    ///< Spring for cam.target.x
    entt::entity springTargetY;    ///< Spring for cam.target.y
    entt::entity springZoom;       ///< Spring for cam.zoom
    entt::entity springRot;        ///< Spring for cam.rotation
    entt::entity springOffsetX;    ///< Spring for cam.offset.x
    entt::entity springOffsetY;    ///< Spring for cam.offset.y

    /**
     * @brief Constructor: creates spring entities and initializes them.
     * @param reg Reference to EnTT registry
     */
    GameCamera(entt::registry &reg)
      : registry(reg)
    {
        // Create entities for each spring component
        springTargetX  = registry.create();
        springTargetY  = registry.create();
        springZoom     = registry.create();
        springRot      = registry.create();
        springOffsetX  = registry.create();
        springOffsetY  = registry.create();

        // Initialize each spring to the camera's initial values
        registry.emplace<Spring>(springTargetX, Spring{
            .value = cam.target.x,
            .stiffness = 1600.0f,
            .damping = 100.f,
            .targetValue = cam.target.x,
            .usingForTransforms = false  // enable true spring behavior
        });
        registry.emplace<Spring>(springTargetY, Spring{
            .value = cam.target.y,
            .stiffness = 1600.0f,
            .damping = 100.f,
            .targetValue = cam.target.y,
            .usingForTransforms = false  // enable true spring behavior
        });
        registry.emplace<Spring>(springZoom, Spring{
            .value = cam.zoom,
            .stiffness = 1600.0f,
            .damping = 10.f,
            .targetValue = cam.zoom,
            .usingForTransforms = false  // enable true spring behavior
        });
        registry.emplace<Spring>(springRot, Spring{
            .value = cam.rotation,
            .stiffness = 1600.0f,
            .damping = 10.f,
            .targetValue = cam.rotation,
            .usingForTransforms = false  // enable true spring behavior
        });
        registry.emplace<Spring>(springOffsetX, Spring{
            .value = cam.offset.x,
            .stiffness = 1600.0f,
            .damping = 100.f,
            .targetValue = cam.offset.x,
            .usingForTransforms = false  // enable true spring behavior
        });
        registry.emplace<Spring>(springOffsetY, Spring{
            .value = cam.offset.y,
            .stiffness = 1600.0f,
            .damping = 100.f,
            .targetValue = cam.offset.y,
            .usingForTransforms = false  // enable true spring behavior
        });
    }
    
    // destructor: cleans up spring entities, if not already destroyed.
    ~GameCamera() {
        
        if (registry.valid(springTargetX)) registry.destroy(springTargetX);
        if (registry.valid(springTargetY)) registry.destroy(springTargetY);
        if (registry.valid(springZoom))    registry.destroy(springZoom);
        if (registry.valid(springRot))     registry.destroy(springRot);
        if (registry.valid(springOffsetX)) registry.destroy(springOffsetX);
        if (registry.valid(springOffsetY)) registry.destroy(springOffsetY);
    }

    // --- Public API ---
    
    Camera2D& GetCamera() {
        return cam;  // Return the Raylib camera object
    }

    /**
     * @brief Begin drawing world-space content through this camera.
     */
    void Begin() { BeginMode2D(cam); }

    /**
     * @brief End camera mode; optionally draw flash/fade overlays.
     * @param overlayDrawLayer Layer to queue overlay commands onto (pass nullptr to skip).
     */
    void End(std::shared_ptr<layer::Layer> overlayDrawLayer = nullptr) { 
        EndMode2D(); 
        if (overlayDrawLayer) {
            DrawOverlays(overlayDrawLayer);
        }
    }

    /**
     * @brief Move the camera target by (dx, dy) immediately.
     * @param dx Delta X in world units.
     * @param dy Delta Y in world units.
     */
    void Move(float dx, float dy) {
        auto &sx = registry.get<Spring>(springTargetX);
        auto &sy = registry.get<Spring>(springTargetY);
        sx.targetValue += dx;
        sy.targetValue += dy;
    }
    
    /**
    * @brief Trigger a short noise‐based camera shake.
    * @param amplitude Maximum displacement (world units).
    * @param duration  How long it lasts (seconds).
    * @param frequency Samples per second (higher = jerkier).
    */
    void Shake(float amplitude, float duration, float frequency = 60.0f) {
        shakesX.emplace_back(amplitude, duration, frequency);
        shakesY.emplace_back(amplitude, duration, frequency);
    }

    /**
    * @brief Trigger a spring‐based shake by pulsing the offset springs. Overwrites stiffness and damping in the x and y springs with the given values.
    * @param intensity  Magnitude of the impulse.
    * @param angle      Direction (radians).
    * @param stiffness  New spring stiffness for this impulse.
    * @param damping    New spring damping for this impulse.
    */
    void SpringShake(float intensity, float angle, float stiffness, float damping) {
        auto &sox = registry.get<Spring>(springOffsetX);
        auto &soy = registry.get<Spring>(springOffsetY);
        // apply an immediate impulse toward negative direction, springs will pull back
        sox.value += -intensity * cosf(angle);
        soy.value += -intensity * sinf(angle);
        sox.stiffness = stiffness;
        sox.damping   = damping;
        soy.stiffness = stiffness;
        soy.damping   = damping;
    }


    /**
     * @brief Convert the current mouse screen position to world coordinates.
     * @return World-space coordinates of the mouse cursor.
     */
    Vector2 GetMouseWorld() const {
        return GetScreenToWorld2D(globals::GetScaledMousePosition(), cam);
    }

    /**
     * @brief Immediately set follow target; enables deadzone logic. Needs to be called every frame if following a moving target for the duration of the follow.
     * @param worldPos World-space position to follow.
     */
    void Follow(const Vector2 &worldPos) {
        registry.get<Spring>(springTargetX).targetValue = worldPos.x;
        registry.get<Spring>(springTargetY).targetValue = worldPos.y;
        useDeadzone = true;
    }
    
    //───────────────────────────────────────────────────────────────────────────
    // New: gently offset camera‐target based on how fast it’s moving
    void ApplyOffsetDamping(float dt) {
        auto &sx = registry.get<Spring>(springTargetX);
        auto &sy = registry.get<Spring>(springTargetY);

        Vector2 pos = { sx.value, sy.value };
        Vector2 vel = {
            (pos.x - prevActualTarget.x) / dt,
            (pos.y - prevActualTarget.y) / dt
        };

        // Clamp input velocity to avoid spikes
        vel.x = ClampF(vel.x, -maxOffsetVel, maxOffsetVel);
        vel.y = ClampF(vel.y, -maxOffsetVel, maxOffsetVel);

        // Apply velocity as additive offset influence
        offset.x += vel.x * offsetAmplify * dt;
        offset.y += vel.y * offsetAmplify * dt;

        // Decay offset back to zero smoothly
        float decay = 1.0f - expf(-offsetDecayRate * dt);
        offset.x -= offset.x * decay;
        offset.y -= offset.y * decay;
        
        // SPDLOG_DEBUG("Camera offset: ({}, {})", offset.x, offset.y);

        // Apply the offset to your camera target
        cam.target.x = sx.value + offset.x;
        cam.target.y = sy.value + offset.y;
        // sx.targetValue += offset.x;
        // sy.targetValue += offset.y;
    }



    /**
     * @brief Configure a custom deadzone rectangle.
     * @param dz Screen-space rectangle within which target can move freely.
     */
    void SetDeadzone(const Rectangle &dz) { deadzone = dz; useDeadzone = true; }

    /**
     * @brief Select a predefined follow style.
     * @param s One of FollowStyle enum values.
     */
    void SetFollowStyle(FollowStyle s) { style = s; }

    /**
     * @brief Set smoothing factors for camera movement.
     * @param x Lerp amount for X axis (0–1).
     * @param y Lerp amount for Y axis (0–1).
     */
    void SetFollowLerp(float x, float y) { followLerpX = x; followLerpY = y; }

    /**
     * @brief Set lookahead multipliers based on target velocity.
     * @param x Lead multiplier for X axis.
     * @param y Lead multiplier for Y axis.
     */
    void SetFollowLead(float x, float y) { followLeadX = x; followLeadY = y; }

    /**
     * @brief Smoothly change camera zoom over time.
     * @param z Target zoom value.
     */
    void SetActualZoom(float z) {
        registry.get<Spring>(springZoom).targetValue = z;
    }
    
    void SetVisualZoom(float z) {
        cam.zoom = z;  // Set the zoom directly for visual purposes
        registry.get<Spring>(springZoom).value = z;  // Update the spring value too
    }
    
    float GetActualZoom() const {
        return registry.get<Spring>(springZoom).value;
    }
    
    float GetVisualZoom() const {
        return cam.zoom;  // Get the zoom directly from the camera
    }

    /**
     * @brief Smoothly change camera rotation over time.
     * @param r Target rotation in degrees.
     */
    void SetActualRotation(float r) {
        registry.get<Spring>(springRot).targetValue = r;
    }
    
    void SetVisualRotation(float r) {
        cam.rotation = r;  // Set the rotation directly for visual purposes
        registry.get<Spring>(springRot).value = r;  // Update the spring value too
    }
    
    // Offset Damping
    void SetOffsetDampingEnabled(bool enabled) { enableOffsetDamping = enabled; }
    bool IsOffsetDampingEnabled() const { return enableOffsetDamping; }

    // Strafe Tilt
    void SetStrafeTiltEnabled(bool enabled) { enableStrafeTilt = enabled; }
    bool IsStrafeTiltEnabled() const { return enableStrafeTilt; }
    
    float GetActualRotation() const {
        return registry.get<Spring>(springRot).value;
    }
    
    float GetVisualRotation() const {
        return cam.rotation;  // Get the rotation directly from the camera
    }

    /**
     * @brief Smoothly change camera offset over time.
     * @param ofs Target offset vector.
     */
    void SetActualOffset(const Vector2 &ofs) {
        registry.get<Spring>(springOffsetX).targetValue = ofs.x;
        registry.get<Spring>(springOffsetY).targetValue = ofs.y;
    }
    
    void SetVisualOffset(const Vector2 &ofs) {
        cam.offset = ofs;  // Set the offset directly for visual purposes
        registry.get<Spring>(springOffsetX).value = ofs.x;  // Update the spring value too
        registry.get<Spring>(springOffsetY).value = ofs.y;
    }
    
    Vector2 GetActualOffset() const {
        return { registry.get<Spring>(springOffsetX).value,
                 registry.get<Spring>(springOffsetY).value };
    }
    
    Vector2 GetVisualOffset() const {
        return cam.offset;  // Get the offset directly from the camera
    }
    
    void SetActualTarget(const Vector2 &target) {
        registry.get<Spring>(springTargetX).targetValue = target.x;
        registry.get<Spring>(springTargetY).targetValue = target.y;
    }
    
    void SetVisualTarget(const Vector2 &target) {
        cam.target = target;  // Set the target directly for visual purposes
        registry.get<Spring>(springTargetX).value = target.x;  // Update the spring value too
        registry.get<Spring>(springTargetY).value = target.y;
    }
    
    Vector2 GetActualTarget() const {
        return { registry.get<Spring>(springTargetX).value,
                 registry.get<Spring>(springTargetY).value };
    }
    
    Vector2 GetVisualTarget() const {
        return cam.target;  // Get the target directly from the camera
    }
    
    Spring& GetSpringTargetX() {
        return registry.get<Spring>(springTargetX);
    }
    
    Spring& GetSpringTargetY() {
        return registry.get<Spring>(springTargetY);
    }
    
    Spring& GetSpringZoom() {
        return registry.get<Spring>(springZoom);
    }
    
    Spring& GetSpringRotation() {
        return registry.get<Spring>(springRot);
    }
    
    Spring& GetSpringOffsetX() {
        return registry.get<Spring>(springOffsetX);
    }
    
    Spring& GetSpringOffsetY() {
        return registry.get<Spring>(springOffsetY);
    }

    /**
     * @brief Restrict camera movement within specified world bounds.
     * @param b World-space rectangle to clamp camera target.
     */
    void SetBounds(const Rectangle &b) { bounds = b; useBounds = true; }

    /**
     * @brief Flash the screen with a solid color for a duration.
     * @param duration Time in seconds to flash.
     * @param c Color to flash.
     */
    void Flash(float duration, Color c) {
        flashing = true;
        flashDuration = duration;
        flashColor = c;
        flashTimer = 0.0f;
    }
    
    //───────────────────────────────────────────────────────────────────────────
    // New: tilt camera a bit when strafing (without overriding springRot)
    void StrafeTiltAdditive(float dt) {
    auto &sx = registry.get<Spring>(springTargetX);
    Vector2 actual = { sx.value, registry.get<Spring>(springTargetY).value };
    float vx = (actual.x - prevActualTarget.x) / dt;

    // Normalize to [-1, 1] based on max expected movement
    float dir = ClampF(vx / maxExpectedVelocityX, -1.0f, 1.0f);

    float desired = dir * tiltAngle;

    float speed = (fabsf(dir) > 0.01f) ? tiltSpeed : tiltRecoverSpeed;
    strafeTiltAngle = LerpAngle(strafeTiltAngle, desired, speed * dt);

    // Only add tilt at render time; don’t touch the spring’s value
    auto &sr = registry.get<Spring>(springRot);
    cam.rotation = sr.value + strafeTiltAngle;
}

    /**
     * @brief Fade screen to a color over time, then invoke callback.
     * @param duration Time in seconds for fade.
     * @param c Target color at end of fade.
     * @param action Optional callback once fade completes.
     */
    void Fade(float duration, Color c, std::function<void()> action = nullptr) {
        fading = true;
        fadeDuration = duration;
        fadeStart = flashColor;    // start from current overlay color
        fadeTarget = c;
        fadeAction = action;
        fadeTimer = 0.0f;
    }

    /**
     * @brief Update camera springs, effects, follow logic, and bounds.
     * @param dt Delta time in seconds since last update.
     */
    void Update(float dt) {
        
        
        auto &offsetVisualX = registry.get<Spring>(springOffsetX).value;
        auto &offsetVisualY = registry.get<Spring>(springOffsetY).value;
        
        // 1.5) noise‐based shakes
        shakeOffsetX = shakeOffsetY = 0.0f;
        // X‐axis
        for(auto it = shakesX.begin(); it != shakesX.end();) {
            it->Update(dt);
            shakeOffsetX += it->GetAmplitude();
            if(!it->shaking) it = shakesX.erase(it);
            else ++it;
        }
        // Y‐axis
        for(auto it = shakesY.begin(); it != shakesY.end();) {
            it->Update(dt);
            shakeOffsetY += it->GetAmplitude();
            if(!it->shaking) it = shakesY.erase(it);
            else ++it;
        }
        // apply the jitter on top of whatever offset the springs have given us
        offsetVisualX += shakeOffsetX;
        offsetVisualY += shakeOffsetY;

        // 2) Handle flash timing
        if (flashing) {
            flashTimer += dt;
            if (flashTimer >= flashDuration) {
                flashing = false;
            }
        }

        // 3) Handle fade interpolation
        if (fading) {
            fadeTimer += dt;
            float t = std::min(fadeTimer/fadeDuration, 1.0f);
            flashColor.r = (unsigned char)Lerp(fadeStart.r, fadeTarget.r, t);
            flashColor.g = (unsigned char)Lerp(fadeStart.g, fadeTarget.g, t);
            flashColor.b = (unsigned char)Lerp(fadeStart.b, fadeTarget.b, t);
            flashColor.a = (unsigned char)Lerp(fadeStart.a, fadeTarget.a, t);
            if (t >= 1.0f) {
                fading = false;
                if (fadeAction) fadeAction();
            }
        }

        // 4) Apply follow/deadzone logic
        if (style != FollowStyle::NONE && useDeadzone) {
            float sw = (float)globals::VIRTUAL_WIDTH;
            float sh = (float)globals::VIRTUAL_HEIGHT;

            switch (style) {
                case FollowStyle::LOCKON: {
                    float w = sw/16.0f, h = sh/16.0f;
                    deadzone = { (sw-w)/2.0f, (sh-h)/2.0f, w, h };
                } break;
                case FollowStyle::PLATFORMER: {
                    float w = sw/8.0f, h = sh/3.0f;
                    deadzone = { (sw-w)/2.0f, (sh-h)/2.0f - h*0.25f, w, h };
                } break;
                case FollowStyle::TOPDOWN: {
                    float s = std::max(sw,sh)/4.0f;
                    deadzone = { (sw-s)/2.0f, (sh-s)/2.0f, s, s };
                } break;
                case FollowStyle::TOPDOWN_TIGHT: {
                    float s = std::max(sw,sh)/8.0f;
                    deadzone = { (sw-s)/2.0f, (sh-s)/2.0f, s, s };
                } break;
                case FollowStyle::SCREEN_BY_SCREEN: {
                    deadzone = {0,0,0,0};
                } break;
                default: break;
            }

            auto &sx = registry.get<Spring>(springTargetX);
            auto &sy = registry.get<Spring>(springTargetY);
            Vector2 targWorld{ sx.value, sy.value };
            Vector2 targScreen = GetWorldToScreen2D(targWorld, cam);

            float scrollX = 0.0f;
            float scrollY = 0.0f;

            if (style == FollowStyle::SCREEN_BY_SCREEN) {
                if (targScreen.x < 0)        scrollX = -sw;
                else if (targScreen.x >= sw) scrollX =  sw;
                if (targScreen.y < 0)        scrollY = -sh;
                else if (targScreen.y >= sh) scrollY =  sh;
            } else {
                if (targScreen.x < deadzone.x)
                    scrollX = targScreen.x - deadzone.x;
                else if (targScreen.x > deadzone.x + deadzone.width)
                    scrollX = targScreen.x - (deadzone.x + deadzone.width);

                if (targScreen.y < deadzone.y)
                    scrollY = targScreen.y - deadzone.y;
                else if (targScreen.y > deadzone.y + deadzone.height)
                    scrollY = targScreen.y - (deadzone.y + deadzone.height);
            }

            scrollX += (sx.targetValue - sx.value) * followLeadX * cam.zoom;
            scrollY += (sy.targetValue - sy.value) * followLeadY * cam.zoom;

            float worldDX = -scrollX / cam.zoom;
            float worldDY = -scrollY / cam.zoom;

            sx.targetValue = Lerp(sx.value, sx.value + worldDX, followLerpX);
            sy.targetValue = Lerp(sy.value, sy.value + worldDY, followLerpY);
            
            

        }
        
        
        // 1) Pull spring values into the camera
        {
            auto &sx  = registry.get<Spring>(springTargetX);
            auto &sy  = registry.get<Spring>(springTargetY);
            auto &sz  = registry.get<Spring>(springZoom);
            auto &sr  = registry.get<Spring>(springRot);
            auto &sox = registry.get<Spring>(springOffsetX);
            auto &soy = registry.get<Spring>(springOffsetY);
            cam.target.x = sx.value;
            cam.target.y = sy.value;
            cam.zoom     = sz.value;
            cam.rotation = sr.value;
            cam.offset.x = sox.value;
            cam.offset.y = soy.value;
        }
        
        
        // 4.5) APPLY OFFSET-DAMPING
        if (enableOffsetDamping)
            ApplyOffsetDamping(dt);

        // 4.6) APPLY STRAFE-TILT
        if (enableStrafeTilt)
            StrafeTiltAdditive(dt);

        // 5) Clamp within world bounds
        if (useBounds) {
            float halfW = (float)globals::VIRTUAL_WIDTH*0.5f / cam.zoom;
            float halfH = (float)globals::VIRTUAL_HEIGHT*0.5f / cam.zoom;
            cam.target.x = ClampF(cam.target.x, bounds.x + halfW, bounds.x + bounds.width - halfW);
            cam.target.y = ClampF(cam.target.y, bounds.y + halfH, bounds.y + bounds.height - halfH);
        }
        
        // Store actual position for next-frame velocity estimates
        prevActualTarget = {
            registry.get<Spring>(springTargetX).value,
            registry.get<Spring>(springTargetY).value
        };

    }

private:
    /**
     * @brief Queue draw commands for flash/fade overlays.
     * @param overlayDrawLayer Layer to draw overlays on.
     */
    void DrawOverlays(std::shared_ptr<layer::Layer> overlayDrawLayer) {
        if (flashing || fading) {
            layer::QueueCommand<layer::CmdDrawRectangle>(
                overlayDrawLayer, [this](auto* cmd) {
                    cmd->x = 0 + globals::VIRTUAL_WIDTH / 2;   // center X
                    cmd->y = 0 + globals::VIRTUAL_HEIGHT / 2;  // center Y
                    cmd->width  = (float)globals::VIRTUAL_WIDTH;
                    cmd->height = (float)globals::VIRTUAL_HEIGHT;
                    cmd->color = flashColor;            // overlay color
                }, 1000  // draw priority
            );
        }
    }
};
