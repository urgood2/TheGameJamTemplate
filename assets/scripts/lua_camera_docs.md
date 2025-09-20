# Camera Lua Bindings (Sol2) — Full Guide

This doc packages a production-ready Lua API around your `GameCamera` and `camera_manager` using Sol2, plus examples, gotchas, and a quick reference. It assumes the binding function you posted (below as **Binding Kernel**) is compiled into your engine and that **`entt::registry*`**, **Raylib PODs** (`Vector2`, `Rectangle`, `Color`), and your **`layer::Layer`** handle are already usable from Lua.

---

## TL;DR — Quick Start

```cpp
// C++ (once at boot, after creating your registry)
sol::state L; /* ... open libs ... */
expose_camera_to_lua(L);   // function from this doc’s Binding Kernel
```

```lua
-- Lua (boot): create and configure a camera
camera.Create("world_camera", registry)
local cam = camera.Get("world_camera")
cam:SetFollowStyle(camera.FollowStyle.TOPDOWN)
cam:SetFollowLerp(0.15, 0.15)
cam:SetFollowLead(0.2, 0.2)
cam:SetBounds{ x=0, y=0, width=4096, height=4096 }
cam:SetOffsetDampingEnabled(true)
cam:SetStrafeTiltEnabled(true)
```

```lua
-- Lua (game loop)
timer.every_frame(function(dt)
  local px, py = player:get_world_pos()
  cam:SetActualTarget{ x = px, y = py }
  cam:Update(dt)
end)

-- Lua (render)
camera.with("world_camera", function()
  draw_world()
end)
```

```lua
-- Effects
cam:Flash(0.2, Color{255,255,255,200})
cam:Fade(0.6, Color{0,0,0,255}, function() load_next_scene() end)
cam:Shake(12.0, 0.35, 60.0)                    -- noise-based
cam:SpringShake(30.0, math.rad(180), 2400, 22) -- spring impulse
```

---

## Binding Kernel (C++)

> Drop this into your bindings compilation unit. It exposes the **`camera`** namespace, `camera.FollowStyle` enum, and the **`GameCamera`** usertype, including a `Fade()` wrapper to accept an optional Lua callback.

```cpp
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

    // GameCamera usertype
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
        // zoom / rotation / offset / target
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

    // Fade wrapper with optional Lua callback
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

    // GameCamera docs (lua_defs)
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
    }

    // camera namespace functions
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
            [](const std::string& name){ camera_manager::Begin(name); },
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

    rec.bind_function(lua, path, "with",
        [](const std::string& name, sol::function fn){
            camera_manager::Begin(name);
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
```

---

## Usage Examples (Lua)

### 1) World follow (top-down), with velocity-based lead and strafe tilt

```lua
camera.Create("world_camera", registry)
local cam = camera.Get("world_camera")
cam:SetFollowStyle(camera.FollowStyle.TOPDOWN)
cam:SetFollowLerp(0.18, 0.18)
cam:SetFollowLead(0.25, 0.20)
cam:SetBounds{ x=0, y=0, width=8192, height=8192 }
cam:SetOffsetDampingEnabled(true)
cam:SetStrafeTiltEnabled(true)

-- in update
timer.every_frame(function(dt)
  local p = player:get_world_pos_v2() -- returns {x=...,y=...}
  cam:SetActualTarget(p)
  cam:Update(dt)
end)

-- in render
camera.with("world_camera", function()
  draw_tilemap()
  draw_entities()
end)
```

### 2) Platformer screen-by-screen paging

```lua
cam:SetFollowStyle(camera.FollowStyle.SCREEN_BY_SCREEN)
cam:SetFollowLerp(1.0, 1.0)   -- snap per page
cam:SetFollowLead(0.0, 0.0)
```

### 3) Hit-confirm screenshake recipe

```lua
local function hit_confirm(x, y)
  cam:Shake(14.0, 0.20, 90.0)
  cam:SpringShake(24.0, math.atan2(y - cam:GetVisualTarget().y, x - cam:GetVisualTarget().x), 2600.0, 24.0)
end
```

### 4) Fade to black → load next scene

```lua
cam:Fade(0.75, Color{0,0,0,255}, function()
  Scene.load("Dungeon02")
end)
```

---

## Integration Checklist (C++)

* ✅ Call `expose_camera_to_lua(L)` **after** opening Sol2 libs and before running game scripts.
* ✅ Ensure **`entt::registry*`** is pushed into Lua (e.g., as a light userdata/global `registry`).
* ✅ If passing Raylib structs as tables from Lua, provide helpers or bind the PODs.
* ✅ If using `layer::Layer` from Lua, expose a factory/getter that returns `std::shared_ptr<layer::Layer>`.
* ✅ Your `camera_manager` owns cameras in a `std::unordered_map<std::string, std::shared_ptr<GameCamera>>`. Lua receives **borrowed** `GameCamera*` — do **not** keep references after `camera.Remove(name)`.

---

## Gotchas & Best Practices

* **Begin/End nesting:** Allowed only with the **same camera**; mismatched nesting asserts.
* **Lifetime:** `camera.Get(name)` returns a raw pointer owned by the manager. If you call `camera.Remove(name)`, any stored Lua pointer will dangle.

  * Safer pattern: don’t store `cam`; keep `local cam = camera.Get("world_camera")` in a narrow scope or re-fetch when needed.
* **Fade callback:** Wrapped to accept an optional Lua function; it executes on fade completion.
* **Follow vs SetActualTarget:** `Follow(pos)` enables deadzone-follow logic; `SetActualTarget(pos)` directly animates spring target. You can use both; follow logic may further adjust springs.
* **Bounds clamping:** Happens **after** all updates (offset, tilt, shakes, follow).
* **Performance:** `UpdateAll(dt)` is handy if you manage many cameras. Keep `Shake` sample frequency modest (e.g., 60–120) to avoid overhead.

---

## API Quick Reference

### Namespace: `camera`

* `camera.Create(name: string, registry: entt.registry*)`
* `camera.Exists(name: string) -> boolean`
* `camera.Remove(name: string)`
* `camera.Get(name: string) -> GameCamera` *(borrowed)*
* `camera.Update(name: string, dt: number)`
* `camera.UpdateAll(dt: number)`
* `camera.Begin(name: string)` **or** `camera.Begin(cam: Camera2D*)`
* `camera.End()`
* `camera.with(name: string, fn: fun())` — runs `fn` inside `Begin/End`
* `camera.FollowStyle` enum table: `LOCKON, PLATFORMER, TOPDOWN, TOPDOWN_TIGHT, SCREEN_BY_SCREEN, NONE`

### Type: `GameCamera`

* **Frame:** `Begin()`, `End(layer?)`, `Update(dt)`
* **Target/Follow:** `Move(dx,dy)`, `Follow(pos)`, `SetDeadzone(rect)`, `SetFollowStyle(style)`, `SetFollowLerp(x,y)`, `SetFollowLead(x,y)`
* **Bounds:** `SetBounds(rect)`
* **Zoom:** `SetActualZoom(z)`, `SetVisualZoom(z)`, `GetActualZoom()`, `GetVisualZoom()`
* **Rotation:** `SetActualRotation(deg)`, `SetVisualRotation(deg)`, `GetActualRotation()`, `GetVisualRotation()`
* **Offset:** `SetActualOffset(v2)`, `SetVisualOffset(v2)`, `GetActualOffset()`, `GetVisualOffset()`
* **Target:** `SetActualTarget(v2)`, `SetVisualTarget(v2)`, `GetActualTarget()`, `GetVisualTarget()`
* **Effects:** `Flash(duration,color)`, `Fade(duration,color, cb?)`, `Shake(amp,dur,freq?)`, `SpringShake(intensity,angle,stiffness,damping)`
* **Toggles:** `SetOffsetDampingEnabled(bool)`, `IsOffsetDampingEnabled()`, `SetStrafeTiltEnabled(bool)`, `IsStrafeTiltEnabled()`
* **Misc:** `GetMouseWorld()`

**Struct tables (when passing as Lua tables):**

* `Vector2` → `{ x:number, y:number }`
* `Rectangle` → `{ x:number, y:number, width:number, height:number }`
* `Color` → `{ r:number, g:number, b:number, a:number }`

---

## Example: Scene Bootstrap (C++ + Lua)

```cpp
// C++ scene init
struct SceneWorld {
  entt::registry& R;
  SceneWorld(entt::registry& reg, sol::state& L) : R(reg) {
    // make registry available in Lua
    L["registry"] = &R; // light userdata or a wrapped usertype

    // expose camera api
    expose_camera_to_lua(L);
  }
};
```

```lua
-- Lua scene script
local function init_world_camera()
  if not camera.Exists("world_camera") then
    camera.Create("world_camera", registry)
  end
  local cam = camera.Get("world_camera")
  cam:SetFollowStyle(camera.FollowStyle.TOPDOWN_TIGHT)
  cam:SetFollowLerp(0.2, 0.2)
  cam:SetFollowLead(0.15, 0.12)
  cam:SetBounds{ x=-512, y=-512, width=12288, height=12288 }
  return cam
end

local cam = init_world_camera()

on_update(function(dt)
  local p = Player.world_pos()
  cam:SetActualTarget(p)
  cam:Update(dt)
end)

on_render(function()
  camera.with("world_camera", function()
    Map.draw()
    Units.draw()
    Projectiles.draw()
  end)
end)
```

---

## Troubleshooting

* **`camera.Create: registry* was nil`** → You forgot to set `L["registry"] = &registry;` before calling from Lua.
* **Mismatched Begin/End** → Don’t call `camera.Begin("A")` then `camera.End()` during `camera.Begin("B")`. Nesting must reuse the same underlying `Camera2D`.
* **Dangling `GameCamera*`** → After `camera.Remove(name)`, re-fetch with `camera.Get(name)` or guard with `camera.Exists(name)`.
* **Nothing draws** → Ensure `camera.Begin`/`camera.End` bracket your world drawing and that your draw code isn’t accidentally using screen-space transforms.

---

## Unit-Test Ideas (Lua-driven)

* `Exists` before/after `Create`/`Remove`.
* `UpdateAll` vs per-name `Update` parity.
* Deadzone behavior by injecting target motion and checking spring targets.
* Bounds clamping by setting tiny world bounds and large screen size.
* Fade callback firing exactly once at end-of-fade.

---

## Optional: Safer Handle Pattern (Name-Resolving Proxy)

If you want to avoid exposing raw `GameCamera*` to Lua, return a lightweight proxy:

```cpp
struct CameraHandle { std::string name; };
// Bind methods that internally resolve: camera_manager::Get(name)->Method(...)
```

This avoids dangling pointers after `Remove(name)` at the cost of a tiny lookup per call.

---

## `.lua_defs` Snippet (emitted by BindingRecorder)

> Your `BindingRecorder` already records the essentials. Here’s a compact, human-checked header you can prepend to the generated file:

```lua
---camera: Namespace for named GameCameras
---
---camera.Create(name: string, registry: entt.registry*)
---camera.Exists(name: string): boolean
---camera.Remove(name: string)
---camera.Get(name: string): GameCamera        -- borrowed
---camera.Update(name: string, dt: number)
---camera.UpdateAll(dt: number)
---camera.Begin(name: string) | camera.Begin(cam: Camera2D*)
---camera.End()
---camera.with(name: string, fn: fun())
---
---camera.FollowStyle = { LOCKON=0, PLATFORMER=1, TOPDOWN=2, TOPDOWN_TIGHT=3, SCREEN_BY_SCREEN=4, NONE=5 }

---@class GameCamera
local GameCamera = {}
function GameCamera:Begin() end
---@param layer layer.Layer?
function GameCamera:End(layer) end
---@param dt number
function GameCamera:Update(dt) end
function GameCamera:Move(dx,dy) end
function GameCamera:Follow(pos) end
function GameCamera:SetDeadzone(rect) end
function GameCamera:SetFollowStyle(style) end
function GameCamera:SetFollowLerp(x,y) end
function GameCamera:SetFollowLead(x,y) end
function GameCamera:SetBounds(rect) end
function GameCamera:Flash(duration, color) end
function GameCamera:Fade(duration, color, cb) end
function GameCamera:Shake(amp, dur, freq) end
function GameCamera:SpringShake(intensity, angle, stiffness, damping) end
function GameCamera:SetActualZoom(z) end
function GameCamera:SetVisualZoom(z) end
function GameCamera:GetActualZoom() return 0 end
function GameCamera:GetVisualZoom() return 0 end
function GameCamera:SetActualRotation(deg) end
function GameCamera:SetVisualRotation(deg) end
function GameCamera:GetActualRotation() return 0 end
function GameCamera:GetVisualRotation() return 0 end
function GameCamera:SetActualOffset(v2) end
function GameCamera:SetVisualOffset(v2) end
function GameCamera:GetActualOffset() return {x=0,y=0} end
function GameCamera:GetVisualOffset() return {x=0,y=0} end
function GameCamera:SetActualTarget(v2) end
function GameCamera:SetVisualTarget(v2) end
function GameCamera:GetActualTarget() return {x=0,y=0} end
function GameCamera:GetVisualTarget() return {x=0,y=0} end
function GameCamera:SetOffsetDampingEnabled(b) end
function GameCamera:IsOffsetDampingEnabled() return false end
function GameCamera:SetStrafeTiltEnabled(b) end
function GameCamera:IsStrafeTiltEnabled() return false end
function GameCamera:GetMouseWorld() return {x=0,y=0} end
```

---

## Change Log (suggested)

* v1.0 — Initial Sol2 binding, effects, follow modes, docs, and examples.

---

**Done.** Plug the kernel in, skim the quick-start, and you’re good to ship. If you want me to tailor the examples to your exact `layer::Layer` API or emit the full generated `.lua_defs` file from your current `BindingRecorder`, say the word.
