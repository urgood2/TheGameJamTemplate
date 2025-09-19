# Input Action Binding System — Documentation & Usage Guide (Lua-first)

This guide matches your current (working) Lua usage. It explains how to **bind**, how **triggers** interact with **polling functions**, how **contexts** gate bindings, and how to handle **mouse**, **keyboard**, and **axes** (incl. mouse wheel via Option 1).

Note that press and down are functionally the same, and this has not been fixed.

---

## 0) Quick Start (exactly like your example)

```lua
input.bind("do_something",       { device = "keyboard", key = KeyboardKey.KEY_SPACE,          trigger = "Pressed",  context = "gameplay" })
input.bind("do_something_else", { device = "keyboard", key = KeyboardKey.KEY_SPACE,          trigger = "Released", context = "gameplay" })
-- input.set_context("gameplay") -- set the input context to gameplay
input.bind("mouse_click",        { device = "mouse",    key = MouseButton.BUTTON_LEFT,        trigger = "Pressed",  context = "gameplay" })

-- Polling inside a timer
timer.every(0.1, function()
  if     input.action_down("do_something") then
    log_debug("Space key down!")
  elseif input.action_released("do_something_else") then
    log_debug("Space key released!")
  elseif input.action_down("mouse_click") then
    log_debug("Mouse left button clicked!")
  end
end)
```

**Why this works:**

* `trigger = "Pressed"` sets `pressed=true` for one frame **and** latches `down=true` until released. So `action_down("do_something")` will be `true` from the press until the release.
* `trigger = "Released"` sets `released=true` only on the release edge. So `action_released("do_something_else")` fires for one frame when SPACE is released.

> Tip: If you only want a single-frame pulse on click, check `action_pressed("mouse_click")`. If you want to treat it as “held” for the entire press duration, use `action_down("mouse_click")` as shown.

---

## 1) Binding Table (Lua)

Your Lua binding helper accepts this shape:

```lua
input.bind(<actionName>, {
  device     = "keyboard" | "mouse" | "gamepad_button" | "gamepad_axis",
  key        = KeyboardKey.* or MouseButton.* or GamepadButton.*  -- for keyboard/mouse/gamepad_button
  -- axis    = GamepadAxis.*                                     -- for gamepad_axis
  trigger    = "Pressed" | "Released" | "Held" | "Repeat" | "AxisPos" | "AxisNeg",
  threshold  = 0.5,         -- used for AxisPos/AxisNeg (deadzone)
  context    = "global" | "gameplay" | "menu" | ...,
  modifiers  = { KeyboardKey.KEY_LEFT_SHIFT, ... }, -- only used for keyboard; optional
  chord_group = "..."       -- optional: group name for chording
})
```

**Notes**

* For **keyboard/mouse/gamepad buttons**, use `key = <enum>`. (Matches your working example.)
* For **axes**, use `device = "gamepad_axis"` and `axis = <enum>` (see §4 for wheel Option 1).
* Omitted fields fall back to defaults in your C++ binder (`trigger = "Pressed"`, `threshold = 0.5`, `context = "global"`).

---

## 2) Triggers and How They Match (Binding phase → Polling phase)

Triggers are evaluated inside `DispatchRaw(...)` when a raw input arrives **and** the binding’s context is active.

### Digital triggers

* **Pressed**  → when input edges **up→down**: sets `pressed = true` (1 frame), **and** `down = true` (latched).
* **Released** → when input edges **down→up**: sets `released = true` (1 frame), sets `down = false`, resets `held`.
* **Held**     → while the device reports down in the current frame, sets/keeps `down = true`.
* **Repeat**   → placeholder—implement cadence if you want auto-repeat pulses.

### Analog triggers (axes)

* **AxisPos**  → if `value > threshold`, updates `state.value = max(state.value, value)` for the frame.
* **AxisNeg**  → if `value < -threshold`, updates `state.value = min(state.value, value)` for the frame.

> **Important:** A binding only updates if its **trigger type matches** the incoming raw event type. A `Pressed` binding won’t react to axis values, and an `AxisPos` binding won’t react to button presses.

### Polling-side meaning

* `input.action_pressed(a)`   → **edge** this frame only.
* `input.action_released(a)`  → **edge** this frame only.
* `input.action_down(a)`      → **latched** from press until release.
* `input.action_value(a)`     → **current axis magnitude** this frame (resets each frame).

Lifecycle order each frame:

```
DispatchRaw(...) → TickActionHolds(dt) → (GAME LOGIC POLLS) → DecayActions()
```

* `DecayActions()` clears `pressed`, `released`, and `value`. It **does not** clear `down`.

---

## 3) Contexts

* A binding is active during dispatch if **either**:

  * `binding.context == "global"`, **or**
  * `binding.context == active_context`.

Switch context at runtime:

```lua
input.set_context("gameplay")
```

Only the selected context + `global` are considered; others don’t need manual disabling.

---

## 4) Axes & Mouse Wheel (Option 1)

**Option 1 (no new device type):** funnel the mouse wheel as a **pseudo gamepad axis**.

C++: define axis codes and dispatch wheel deltas each frame they’re non-zero.

```cpp
constexpr int AXIS_MOUSE_WHEEL_Y = 1001; // expose to Lua
// in Update():
float dy = GetMouseWheelMove();
if (dy != 0.f) {
    input::DispatchRaw(inputState, InputDeviceInputCategory::GAMEPAD_AXIS, AXIS_MOUSE_WHEEL_Y, /*down*/true, /*value*/dy);
}
```

Lua bindings:

```lua
input.bind("ZoomIn",  { device = "gamepad_axis", axis = AXIS_MOUSE_WHEEL_Y, trigger = "AxisPos", threshold = 0.2, context = "gameplay" })
input.bind("ZoomOut", { device = "gamepad_axis", axis = AXIS_MOUSE_WHEEL_Y, trigger = "AxisNeg", threshold = 0.2, context = "gameplay" })

-- usage
local zin  =  input.action_value("ZoomIn")
local zout = -input.action_value("ZoomOut")
if zin  > 0 then camera.zoom(-zin * 0.1) end  -- sign as you prefer
if zout > 0 then camera.zoom( zout * 0.1) end
```

---

## 5) Common Patterns

### Clicks vs Holds

```lua
-- One-frame pulse on click
if input.action_pressed("mouse_click") then do_click() end

-- Treat as held while pressed
if input.action_down("mouse_click") then drag_or_aim() end
```

### Movement (left stick / WASD as axes)

```lua
input.bind("MoveX+", { device = "gamepad_axis", axis = GamepadAxis.GAMEPAD_AXIS_LEFT_X, trigger = "AxisPos", threshold = 0.2, context = "gameplay" })
input.bind("MoveX-", { device = "gamepad_axis", axis = GamepadAxis.GAMEPAD_AXIS_LEFT_X, trigger = "AxisNeg", threshold = 0.2, context = "gameplay" })
local dx = input.action_value("MoveX+") + input.action_value("MoveX-") -- negative on left
```

### Simple keyboard actions

```lua
input.bind("OpenMenu", { device = "keyboard", key = KeyboardKey.KEY_ESCAPE, trigger = "Pressed", context = "gameplay" })
if input.action_pressed("OpenMenu") then ui.toggle_menu() end
```

---

## 6) Troubleshooting

* **`action_down` is never true:** Ensure you **don’t clear `down`** in `DecayActions()`. `down` should only flip in `DispatchRaw` on press/release.
* **Mouse wheel not doing anything:** Make sure you actually **dispatch** the wheel delta (see §4), and your bindings use `device = "gamepad_axis"` with `trigger = "AxisPos/AxisNeg"`.
* **Key spamming `pressed` every frame:** Poll keyboard edges (`IsKeyPressed/IsKeyReleased`) before forwarding to `DispatchRaw`.
* **Wrong context:** Call `input.set_context("gameplay")` (or bind to `global`) to ensure the binding is active.

---

## 7) Rebinding (optional)

```lua
input.start_rebind("Jump", function(ok, b)
  if ok then
    log_debug(string.format("Rebound Jump: device=%d code=%d trigger=%d context=%s", b.device, b.code, b.trigger, b.context))
  end
end)
```

`start_rebind` listens for the next raw input and returns a binding table (`device`, `code`, `trigger`, `context`, `modifiers`).

---

## 8) Quick Checklist

* [ ] Bind with `device`, `key/axis`, `trigger`, `context`.
* [ ] Use `Pressed/Released` for edges; `Held` or `action_down` for continuous.
* [ ] For axes, use `AxisPos/AxisNeg` and set `threshold` (deadzone).
* [ ] Switch active layer with `input.set_context(...)`.
* [ ] Wheel: dispatch as pseudo axis; bind with `gamepad_axis`.
