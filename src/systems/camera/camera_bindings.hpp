// camera_bindings.hpp
#pragma once
#include <sol/sol.hpp>
#include "camera_manager.hpp"   // the file you posted
#include "systems/scripting/binding_recorder.hpp"
// assumes raylib types (Vector2, Rectangle, Color) + entt::registry* are already exposed or passable

namespace camera_bindings {

inline void expose_camera_to_lua(sol::state& lua) {
    auto& rec = BindingRecorder::instance();
    const std::vector<std::string> path = {"camera"};

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
        "Follow", &GameCamera::Follow,
        "SetDeadzone", &GameCamera::SetDeadzone,
        "SetFollowStyle", &GameCamera::SetFollowStyle,
        "SetFollowLerp", &GameCamera::SetFollowLerp,
        "SetFollowLead", &GameCamera::SetFollowLead,

        // effects
        "Flash", &GameCamera::Flash,
        "Shake", &GameCamera::Shake,
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

        "SetActualOffset", &GameCamera::SetActualOffset,
        "SetVisualOffset", &GameCamera::SetVisualOffset,
        "GetActualOffset", &GameCamera::GetActualOffset,
        "GetVisualOffset", &GameCamera::GetVisualOffset,

        "SetActualTarget", &GameCamera::SetActualTarget,
        "SetVisualTarget", &GameCamera::SetVisualTarget,
        "GetActualTarget", &GameCamera::GetActualTarget,
        "GetVisualTarget", &GameCamera::GetVisualTarget,

        "SetBounds", &GameCamera::SetBounds,

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
        t.doc = "Smooth 2D camera with springs, follow modes, bounds, shake, flash/fade.";
        rec.record_property("GameCamera", {"Begin()", "", "BeginMode2D with this camera."});
        rec.record_property("GameCamera", {"End(layer?)", "", "EndMode2D; optional overlay draw."});
        rec.record_property("GameCamera", {"Update(dt)", "", "Advance springs/effects/follow/bounds."});
        rec.record_property("GameCamera", {"Move(dx,dy)", "", "Nudge target immediately."});
        rec.record_property("GameCamera", {"Follow(worldPos)", "", "Set follow target (enables deadzone)."});
        rec.record_property("GameCamera", {"SetFollowStyle(style)", "", "Set follow mode."});
        rec.record_property("GameCamera", {"Flash(duration,color)", "", "Full-screen flash."});
        rec.record_property("GameCamera", {"Fade(duration,color,cb?)", "", "Fade to color then call cb()."});
        rec.record_property("GameCamera", {"Shake(amp,dur,freq?)", "", "Noise-based shake."});
        rec.record_property("GameCamera", {"SpringShake(intensity,angle,stiffness,damping)", "", "Impulse via offset springs."});
        // …you can add more docs as needed
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
    rec.bind_function(lua, path, "Get",
        [](const std::string& name) -> GameCamera* {
            return camera_manager::Get(name).get();
        },
        "---@param name string\n---@return GameCamera  # Borrowed pointer (owned by manager)\nFetch a camera by name.");

    rec.bind_function(lua, path, "Update",
        &camera_manager::Update,
        "---@param name string\n---@param dt number\nUpdate a single camera.");

    rec.bind_function(lua, path, "UpdateAll",
        &camera_manager::UpdateAll,
        "---@param dt number\nUpdate all cameras.");

    rec.bind_function(lua, path, "Begin",
        sol::overload(
            // Begin by name (recommended)
            [](const std::string& name){ camera_manager::Begin(name); },
            // Begin by raw Camera2D* (advanced)
            [](Camera2D* cam){
                if (!cam) throw std::runtime_error("camera.Begin: Camera2D* was nil");
                camera_manager::Begin(*cam);
            }
        ),
        "---@overload fun(name:string)\n"
        "---@overload fun(cam:Camera2D*)\n"
        "Enter 2D mode with a named camera (or raw Camera2D).");

    rec.bind_function(lua, path, "End",
        [](){ camera_manager::End(); },
        "End the current camera (handles nesting).");

    // Convenience: with(name, fn) — RAII-like scope in Lua
    rec.bind_function(lua, path, "with",
        [](const std::string& name, sol::function fn){
            camera_manager::Begin(name);
            // ensure End() even if fn errors
            sol::protected_function pfn = fn;
            sol::protected_function_result r = pfn();
            camera_manager::End();
            if (!r.valid()) {
                sol::error err = r;
                throw std::runtime_error(std::string("camera.with callback error: ") + err.what());
            }
        },
        "---@param name string\n---@param fn fun()\nRun fn inside Begin/End for the named camera.");
}

} // namespace bindings
