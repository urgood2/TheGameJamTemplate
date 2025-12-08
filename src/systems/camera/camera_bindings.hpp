// camera_bindings.hpp
#pragma once
#include <sol/sol.hpp>
#include <sol/types.hpp>
#include "camera_manager.hpp"   // the file you posted
#include "systems/scripting/binding_recorder.hpp"
#include "util/error_handling.hpp"
// assumes raylib types (Vector2, Rectangle, Color) + entt::registry* are already exposed or passable

namespace camera_bindings {

inline void expose_camera_to_lua(sol::state& lua) {
    auto& rec = BindingRecorder::instance();
    const std::vector<std::string> path = {"camera"};

    auto table_to_rect = [](sol::table t) {
        Rectangle r{};
        r.x = t.get_or("x", 0.0f);
        r.y = t.get_or("y", 0.0f);
        r.width  = t.get_or("width", t.get_or("w", 0.0f));
        r.height = t.get_or("height", t.get_or("h", 0.0f));
        return r;
    };

    // Namespace doc
    rec.add_type("camera").doc =
        "Camera namespace. Create named cameras, update them, and use them for rendering.";

    // FollowStyle enum as table: camera.FollowStyle.*
    lua["camera"] = lua["camera"].get_or_create<sol::table>();
    lua["camera"]["FollowStyle"] = lua.create_table_with(
        "LOCKON",           static_cast<int>(FollowStyle::LOCKON),
        "PLATFORMER",       static_cast<int>(FollowStyle::PLATFORMER),
        "TOPDOWN",          static_cast<int>(FollowStyle::TOPDOWN),
        "TOPDOWN_TIGHT",    static_cast<int>(FollowStyle::TOPDOWN_TIGHT),
        "SCREEN_BY_SCREEN", static_cast<int>(FollowStyle::SCREEN_BY_SCREEN),
        "NONE",             static_cast<int>(FollowStyle::NONE)
    );
    {
        auto& t = rec.add_type("camera.FollowStyle");
        t.doc = "Camera follow modes.";
        rec.record_property("camera.FollowStyle", {"LOCKON", "0", "Always center target."});
        rec.record_property("camera.FollowStyle", {"PLATFORMER", "1", "Platformer-style deadzone."});
        rec.record_property("camera.FollowStyle", {"TOPDOWN", "2", "Loose top-down deadzone."});
        rec.record_property("camera.FollowStyle", {"TOPDOWN_TIGHT", "3", "Tighter top-down deadzone."});
        rec.record_property("camera.FollowStyle", {"SCREEN_BY_SCREEN", "4", "Move by screen pages."});
        rec.record_property("camera.FollowStyle", {"NONE", "5", "No automatic follow."});
    }

    // ──────────────────────────────────────────────────────────────────────────
    // GameCamera usertype (methods that make sense from Lua)
    // NOTE: we expose pointer (GameCamera*) returned by the manager.
    // Make sure Spring is bound if you want to expose GetSpring*; otherwise omit.
    // ──────────────────────────────────────────────────────────────────────────
// GameCamera usertype (Lua-friendly overloads added; engine API unchanged)
// ──────────────────────────────────────────────────────────────────────────
lua.new_usertype<GameCamera>("GameCamera",
    sol::no_constructor,

    // frame control
    "Begin", &GameCamera::Begin,
    "End",   sol::overload(
                [](GameCamera& self){ self.End(nullptr); },
                [](GameCamera& self, std::shared_ptr<layer::Layer> layer){ self.End(layer); }
             ),

    // motion / follow
    "Move", &GameCamera::Move,       
    "Follow", sol::overload(
                  &GameCamera::Follow,                                   // existing (Vector2)
                  [](GameCamera& self, float x, float y){                // new (x, y)
                      self.Follow(Vector2{x, y});
                  }
              ),
    "SetDeadzone", sol::overload(
                      &GameCamera::SetDeadzone,                          // existing (Rectangle / optional<Rectangle>)
                      [](GameCamera& self, float x, float y, float w, float h){ // new numbers
                          self.SetDeadzone(Rectangle{x, y, w, h});
                      },
                      [table_to_rect](GameCamera& self, sol::table t){   // Lua table
                          self.SetDeadzone(table_to_rect(t));
                      },
                      [](GameCamera& self, sol::lua_nil_t){                  // disable
                          self.useDeadzone = false;
                          self.deadzone = Rectangle{0, 0, 0, 0};
                      }
                  ),
    "SetFollowStyle", &GameCamera::SetFollowStyle,
    "SetFollowLerp",  &GameCamera::SetFollowLerp,
    "SetFollowLead",  &GameCamera::SetFollowLead, 

    // effects
    "Flash",       &GameCamera::Flash,
    "Shake",       &GameCamera::Shake,
    "SpringShake", &GameCamera::SpringShake,

    // zoom / rotation / offset / target (Actual = spring target, Visual = immediate)
    "SetActualZoom", &GameCamera::SetActualZoom,
    "SetVisualZoom", &GameCamera::SetVisualZoom,
    "GetActualZoom", &GameCamera::GetActualZoom,
    "GetVisualZoom", &GameCamera::GetVisualZoom,

    "SetActualRotation", &GameCamera::SetActualRotation,
    "SetVisualRotation", &GameCamera::SetVisualRotation,
    "GetActualRotation", &GameCamera::GetActualRotation,
    "GetVisualRotation", &GameCamera::GetVisualRotation,

    "SetActualOffset", sol::overload(
                           &GameCamera::SetActualOffset,                 // existing (Vector2)
                           [](GameCamera& self, float x, float y){       // new (x, y)
                               self.SetActualOffset(Vector2{x, y});
                           }
                       ),
    "SetVisualOffset", sol::overload(
                           &GameCamera::SetVisualOffset,                 // existing (Vector2)
                           [](GameCamera& self, float x, float y){       // new (x, y)
                               self.SetVisualOffset(Vector2{x, y});
                           }
                       ),
    "GetActualOffset", &GameCamera::GetActualOffset,
    "GetVisualOffset", &GameCamera::GetVisualOffset,
    // "SetActualTargetSmooth", [](GameCamera& self, float x, float y,
    //                             sol::optional<int>    frames,
    //                             sol::optional<float>  kBoost,
    //                             sol::optional<float>  dBoost,
    //                             sol::optional<float>  jumpThreshold)
    // {
    //     self.SetActualTargetSmooth(
    //         Vector2{ x, y },
    //         frames.value_or(8),
    //         kBoost.value_or(2000.f),
    //         dBoost.value_or(200.f),
    //         jumpThreshold.value_or(0.f)
    //     );
    // },

    "SetActualTarget", sol::overload(
                           &GameCamera::SetActualTarget,                 // existing (Vector2)
                           [](GameCamera& self, float x, float y){       // new (x, y)
                               self.SetActualTarget(Vector2{x, y});
                           }
                       ),
    "SetVisualTarget", sol::overload(
                           &GameCamera::SetVisualTarget,                 // existing (Vector2)
                           [](GameCamera& self, float x, float y){       // new (x, y)
                               self.SetVisualTarget(Vector2{x, y});
                           }
                       ),
    "GetActualTarget", &GameCamera::GetActualTarget,
    "GetVisualTarget", &GameCamera::GetVisualTarget,

    "SetBounds", sol::overload(
                     &GameCamera::SetBounds,                             // existing (Rectangle / optional<Rectangle>)
                     [](GameCamera& self, float x, float y, float w, float h){ // new numbers
                         self.SetBounds(Rectangle{x, y, w, h});
                     },
                     [table_to_rect](GameCamera& self, sol::table t){    // Lua table
                         self.SetBounds(table_to_rect(t));
                     },
                     [](GameCamera& self, sol::lua_nil_t){                   // disable
                         self.useBounds = false;
                         self.bounds = Rectangle{0, 0, 0, 0};
                     }
                 ),
    "SetBoundsPadding", &GameCamera::SetBoundsPadding,
            
    // "SnapActualTo", &GameCamera::SnapActualTo, // immediate snap of actual (spring) position

    // toggles
    "SetOffsetDampingEnabled", &GameCamera::SetOffsetDampingEnabled,
    "IsOffsetDampingEnabled",  &GameCamera::IsOffsetDampingEnabled,
    "SetStrafeTiltEnabled",    &GameCamera::SetStrafeTiltEnabled,
    "IsStrafeTiltEnabled",     &GameCamera::IsStrafeTiltEnabled,

    // queries / helpers
    "GetMouseWorld", &GameCamera::GetMouseWorld,

    // per-frame update
    "Update", &GameCamera::Update
);


    // Optional: Fade with Lua callback (sol2 will box the lambda)
    // Expose as a free function method on the usertype via set_function:
    {
        sol::usertype<GameCamera> gc = lua["GameCamera"];
        gc.set_function("Fade", [](GameCamera& self, float duration, Color c, sol::object maybe_cb){
            if (maybe_cb.is<sol::function>()) {
                sol::function cb = maybe_cb.as<sol::function>();
                self.Fade(duration, c, [cb]() mutable { cb(); });
            } else {
                self.Fade(duration, c, nullptr);
            }
        });
    }

    // Document the GameCamera type
  {
        auto& t = rec.add_type("GameCamera");
        t.doc = "Smooth 2D camera with springs, follow modes, bounds, shake, and flash/fade.\n"
                "Actual* setters target the spring (smoothed) values; Visual* setters apply immediately.";

        // Frame control
        rec.record_method("GameCamera", MethodDef{
            "Begin",
            "---@return nil",
            "Enter 2D mode using this camera.",
            /*is_static=*/false, /*is_overload=*/false
        });
        rec.record_method("GameCamera", MethodDef{
            "End",
            "---@return nil",
            "End 2D mode for this camera.",
            false, false
        });
        rec.record_method("GameCamera", MethodDef{
            "SnapActualTo",
            "---@param x number\n---@param y number\n---@return nil",
            "Instantly move the camera’s actual position to (x, y), skipping smoothing.\n"
            "Resets spring values/velocities, clears shakes, and suppresses follow logic for a couple frames.\n"
            "Use when teleporting or hard-setting camera position.",
            false, false
        });
        rec.record_method("GameCamera", MethodDef{
            "End",
            "(layer:Layer):nil",
            "End 2D mode, then draw an overlay using the given Layer.",
            false, true
        });
        
        rec.record_method("GameCamera", MethodDef{
            "SetActualTargetSmooth",
            "---@param x number\n---@param y number\n---@param frames integer @frames of boosted damping (default 8)\n"
            "---@param kBoost number @temporary stiffness (default 2000)\n"
            "---@param dBoost number @temporary damping (default 200)\n"
            "---@param jumpThreshold number @world distance to trigger boosted settle; <=0 means always (default 0)\n"
            "---@return nil",
            "Single-call smooth move to (x, y). Zeroes velocity, boosts damping briefly to prevent jitter on big jumps,\n"
            "and suppresses follow/deadzone for a few frames. Restores tuning automatically.",
            false, false
        });


        // Motion / follow
        rec.record_method("GameCamera", MethodDef{
            "Move",
            "---@param dx number\n---@param dy number\n---@return nil",
            "Nudge the camera target immediately by (dx, dy).",
            false, false
        });
        rec.record_method("GameCamera", MethodDef{
            "Move",
            "(delta:Vector2):nil",
            "Nudge the camera target by a vector.",
            false, true
        });

        rec.record_method("GameCamera", MethodDef{
            "Follow",
            "---@param worldPos Vector2\n---@return nil",
            "Set the world-space follow target (enables deadzone logic).",
            false, false
        });

        rec.record_method("GameCamera", MethodDef{
            "SetDeadzone",
            "---@param rect Rectangle|nil # nil disables deadzone\n---@return nil",
            "Set or clear the deadzone rectangle (world units).",
            false, false
        });
        rec.record_method("GameCamera", MethodDef{
            "SetDeadzone",
            "---@param x number\n---@param y number\n---@param w number\n---@param h number\n---@return nil",
            "Set deadzone rectangle by x, y, width, height values.",
            false, true
        });
        rec.record_method("GameCamera", MethodDef{
            "SetDeadzone",
            "---@param t {x: number, y: number, width: number, height: number}\n---@return nil",
            "Set deadzone from a Lua table with x, y, width/w, height/h fields.",
            false, true
        });

        rec.record_method("GameCamera", MethodDef{
            "SetFollowStyle",
            "---@param style integer|camera.FollowStyle\n---@return nil",
            "Choose the follow behavior.",
            false, false
        });

        rec.record_method("GameCamera", MethodDef{
            "SetFollowLerp",
            "---@param t number # 0..1 smoothing toward follow target\n---@return nil",
            "Higher t snaps faster; lower t is smoother.",
            false, false
        });

        rec.record_method("GameCamera", MethodDef{
            "SetFollowLead",
            "---@param lead Vector2\n---@return nil",
            "Lead the camera ahead of movement.",
            false, false
        });
        rec.record_method("GameCamera", MethodDef{
            "SetFollowLead",
            "(x:number, y:number):nil",
            "Lead the camera by components.",
            false, true
        });

        // Effects
        rec.record_method("GameCamera", MethodDef{
            "Flash",
            "---@param duration number\n---@param color Color\n---@return nil",
            "Fullscreen flash of the given color.",
            false, false
        });

        rec.record_method("GameCamera", MethodDef{
            "Fade",
            "---@param duration number\n---@param color Color\n---@param cb? fun():nil\n---@return nil",
            "Fade to color; optional callback invoked when fade completes.",
            false, false
        });

        rec.record_method("GameCamera", MethodDef{
            "Shake",
            "---@param amplitude number\n---@param duration number\n---@param frequency? number\n---@return nil",
            "Noise-based screenshake.",
            false, false
        });

        rec.record_method("GameCamera", MethodDef{
            "SpringShake",
            "---@param intensity number\n---@param angle number # radians\n---@param stiffness number\n---@param damping number\n---@return nil",
            "Kick the offset spring system with an impulse.",
            false, false
        });

        // Zoom
        rec.record_method("GameCamera", MethodDef{
            "SetActualZoom",
            "---@param z number\n---@return nil",
            "Set spring-target zoom (smoothed).",
            false, false
        });
        rec.record_method("GameCamera", MethodDef{
            "SetVisualZoom",
            "---@param z number\n---@return nil",
            "Set immediate zoom (unsmoothed).",
            false, false
        });
        rec.record_method("GameCamera", MethodDef{
            "GetActualZoom",
            "---@return number",
            "Current spring-target zoom.",
            false, false
        });
        rec.record_method("GameCamera", MethodDef{
            "GetVisualZoom",
            "---@return number",
            "Current immediate zoom.",
            false, false
        });

        // Rotation (radians)
        rec.record_method("GameCamera", MethodDef{
            "SetActualRotation",
            "---@param radians number\n---@return nil",
            "Set spring-target rotation (radians).",
            false, false
        });
        rec.record_method("GameCamera", MethodDef{
            "SetVisualRotation",
            "---@param radians number\n---@return nil",
            "Set immediate rotation (radians).",
            false, false
        });
        rec.record_method("GameCamera", MethodDef{
            "GetActualRotation",
            "---@return number",
            "Current spring-target rotation (radians).",
            false, false
        });
        rec.record_method("GameCamera", MethodDef{
            "GetVisualRotation",
            "---@return number",
            "Current immediate rotation (radians).",
            false, false
        });

        // Offset
        rec.record_method("GameCamera", MethodDef{
            "SetActualOffset",
            "---@param offset Vector2\n---@return nil",
            "Set spring-target offset.",
            false, false
        });
        rec.record_method("GameCamera", MethodDef{
            "SetActualOffset",
            "(x:number, y:number):nil",
            "Set spring-target offset by components.",
            false, true
        });

        rec.record_method("GameCamera", MethodDef{
            "SetVisualOffset",
            "---@param offset Vector2\n---@return nil",
            "Set immediate offset.",
            false, false
        });
        rec.record_method("GameCamera", MethodDef{
            "SetVisualOffset",
            "(x:number, y:number):nil",
            "Set immediate offset by components.",
            false, true
        });

        rec.record_method("GameCamera", MethodDef{
            "GetActualOffset",
            "---@return Vector2",
            "Current spring-target offset.",
            false, false
        });
        rec.record_method("GameCamera", MethodDef{
            "GetVisualOffset",
            "---@return Vector2",
            "Current immediate offset.",
            false, false
        });

        // Target (world center)
        rec.record_method("GameCamera", MethodDef{
            "SetActualTarget",
            "---@param world Vector2\n---@return nil",
            "Set spring-target position.",
            false, false
        });
        rec.record_method("GameCamera", MethodDef{
            "SetActualTarget",
            "(x:number, y:number):nil",
            "Set spring-target position by components.",
            false, true
        });
        rec.record_method("GameCamera", MethodDef{
            "SetVisualTarget",
            "---@param world Vector2\n---@return nil",
            "Set immediate position.",
            false, false
        });
        rec.record_method("GameCamera", MethodDef{
            "SetVisualTarget",
            "(x:number, y:number):nil",
            "Set immediate position by components.",
            false, true
        });
        rec.record_method("GameCamera", MethodDef{
            "GetActualTarget",
            "---@return Vector2",
            "Current spring-target position.",
            false, false
        });
        rec.record_method("GameCamera", MethodDef{
            "GetVisualTarget",
            "---@return Vector2",
            "Current immediate position.",
            false, false
        });

        // Bounds
        rec.record_method("GameCamera", MethodDef{
            "SetBounds",
            "---@param rect Rectangle|nil # nil disables clamping\n---@return nil",
            "Set world-space clamp rectangle or disable when nil.",
            false, false
        });
        rec.record_method("GameCamera", MethodDef{
            "SetBounds",
            "---@param x number\n---@param y number\n---@param w number\n---@param h number\n---@return nil",
            "Set bounds rectangle by x, y, width, height values.",
            false, true
        });
        rec.record_method("GameCamera", MethodDef{
            "SetBounds",
            "---@param t {x: number, y: number, width: number, height: number}\n---@return nil",
            "Set bounds from a Lua table with x, y, width/w, height/h fields.",
            false, true
        });
        rec.record_method("GameCamera", MethodDef{
            "SetBoundsPadding",
            "---@param padding number # extra screen-space leeway in pixels\n---@return nil",
            "Allow a little slack when clamping bounds (useful when bounds equal the viewport).",
            false, false
        });

        // Toggles
        rec.record_method("GameCamera", MethodDef{
            "SetOffsetDampingEnabled",
            "---@param enabled boolean\n---@return nil",
            "Enable/disable damping on the offset spring.",
            false, false
        });
        rec.record_method("GameCamera", MethodDef{
            "IsOffsetDampingEnabled",
            "---@return boolean",
            "Whether offset damping is enabled.",
            false, false
        });
        rec.record_method("GameCamera", MethodDef{
            "SetStrafeTiltEnabled",
            "---@param enabled boolean\n---@return nil",
            "Enable/disable strafe tilt effect.",
            false, false
        });
        rec.record_method("GameCamera", MethodDef{
            "IsStrafeTiltEnabled",
            "---@return boolean",
            "Whether strafe tilt is enabled.",
            false, false
        });

        // Queries / per-frame update
        rec.record_method("GameCamera", MethodDef{
            "GetMouseWorld",
            "---@return Vector2",
            "Mouse position in world space using this camera.",
            false, false
        });
        rec.record_method("GameCamera", MethodDef{
            "Update",
            "---@param dt number\n---@return nil",
            "Advance springs, effects, follow, and bounds by dt seconds.",
            false, false
        });
    }


    // ──────────────────────────────────────────────────────────────────────────
    // camera manager functions in namespace camera
    // Note: pass entt::registry* from Lua; we dereference inside.
    rec.bind_function(lua, path, "Create",
        [](const std::string& name, entt::registry* reg){
            if (!reg) throw std::runtime_error("camera.Create: registry* was nil");
            camera_manager::Create(name, *reg);
        },
        "---@param name string               # Unique camera name\n"
        "---@param registry entt.registry*   # Pointer to your ECS registry\n"
        "Create or overwrite a named GameCamera.");

    rec.bind_function(lua, path, "Exists",
        &camera_manager::Exists,
        "---@param name string\n---@return boolean\nCheck whether a named camera exists.");

    rec.bind_function(lua, path, "Remove",
        &camera_manager::Remove,
        "---@param name string\nRemove (destroy) a named camera.");

    // Get returns GameCamera* so Lua can call methods (manager keeps the shared_ptr alive)
    // Safety: checks existence first and throws a clear error instead of crashing
    rec.bind_function(lua, path, "Get",
        [](const std::string& name) -> GameCamera* {
            if (!camera_manager::Exists(name)) {
                throw std::runtime_error("camera.Get: no camera named '" + name + "' exists. "
                    "Call camera.Create() first or check with camera.Exists().");
            }
            return camera_manager::Get(name).get();
        },
        "---@param name string\n---@return GameCamera  # Borrowed pointer (owned by manager)\n"
        "Fetch a camera by name. Throws if camera doesn't exist - use Exists() to check first.");

    rec.bind_function(lua, path, "Update",
        &camera_manager::Update,
        "---@param name string\n---@param dt number\nUpdate a single camera.");

    rec.bind_function(lua, path, "UpdateAll",
        &camera_manager::UpdateAll,
        "---@param dt number\nUpdate all cameras.");

    rec.bind_function(lua, path, "Begin",
        sol::overload(
            // Begin by name (recommended) - with existence check
            [](const std::string& name){
                if (!camera_manager::Exists(name)) {
                    throw std::runtime_error("camera.Begin: no camera named '" + name + "' exists. "
                        "Call camera.Create() first.");
                }
                camera_manager::Begin(name);
            },
            // Begin by raw Camera2D* (advanced)
            [](Camera2D* cam){
                if (!cam) throw std::runtime_error("camera.Begin: Camera2D* was nil");
                camera_manager::Begin(*cam);
            }
        ),
        "---@overload fun(name:string)\n"
        "---@overload fun(cam:Camera2D*)\n"
        "Enter 2D mode with a named camera (or raw Camera2D). Throws if camera doesn't exist.");

    rec.bind_function(lua, path, "End",
        [](){ camera_manager::End(); },
        "End the current camera (handles nesting).");

    // Convenience: with(name, fn) — RAII-like scope in Lua
    rec.bind_function(lua, path, "with",
        [](const std::string& name, sol::function fn){
            if (!camera_manager::Exists(name)) {
                throw std::runtime_error("camera.with: no camera named '" + name + "' exists. "
                    "Call camera.Create() first.");
            }
            camera_manager::Begin(name);
            // ensure End() even if fn errors
            sol::protected_function pfn = fn;
            auto r = util::safeLuaCall(pfn, "camera.with callback");
            camera_manager::End();
            if (r.isErr()) {
                throw std::runtime_error(std::string("camera.with callback error: ") + r.error());
            }
        },
        "---@param name string\n---@param fn fun()\nRun fn inside Begin/End for the named camera. Throws if camera doesn't exist.");
}

} // namespace bindings
