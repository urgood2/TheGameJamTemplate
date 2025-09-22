# Timer & EventQueueSystem — Lua API Reference

> Production‑ready reference for the timer module and EventQueueSystem bindings created in `exposeToLua(sol::state& lua)`.

* **Host**: C++ (Sol2) → Lua
* **Update loop**: call `timer.update(dt)` every frame
* **Thread safety**: functions passed in are cloned into the main Lua state
* **Time units**: seconds (floats)

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Frame Model & Best Practices](#frame-model--best-practices)
3. [Math Utilities](#math-utilities)
4. [Types & Enums](#types--enums)
5. [Timer Core API](#timer-core-api)
6. [Timer Creation API](#timer-creation-api)

   * [`timer.run`](#timerrun)
   * [`timer.after`](#timerafter)
   * [`timer.cooldown`](#timercooldown)
   * [`timer.every`](#timerevery)
   * [`timer.every_step`](#timerevery_step)
   * [`timer.for_time`](#timerfor_time)
   * [`timer.tween` (3 overloads)](#timertween)
7. [Timer Control & Query](#timer-control--query)
8. [Tags, Groups, Multipliers](#tags-groups-multipliers)
9. [EventQueueSystem](#eventqueuesystem)

   * [Enums](#eventqueuesystem-enums)
   * [Data Classes](#eventqueuesystem-data-classes)
   * [Builders](#eventqueuesystem-builders)
   * [Core API](#eventqueuesystem-core-api)
   * [Worked Examples](#eventqueuesystem-worked-examples)
10. [Error Handling & Diagnostics](#error-handling--diagnostics)
11. [Migration Notes & Gotchas](#migration-notes--gotchas)

---

## Quick Start

```lua
-- Call once per frame
function _update(dt)
  timer.update(dt)
end

-- 1) Fire once next frame (or immediately + after-callback)
local h1 = timer.run(function()
  print("run once now")
end, function()
  print("after run")
end, "tag.run", "ui")

-- 2) Fire after fixed delay
local h2 = timer.after(0.5, function()
  print("0.5s passed")
end, "tag.after")

-- 3) Repeating every 0.25s, 5 times, immediate tick, then after
local h3 = timer.every(0.25, function()
  print("tick")
end, 5, true, function()
  print("every done")
end, "tag.every")

-- 4) Frame-for-duration (receives dt each frame)
local h4 = timer.for_time(1.2, function(dt)
  -- update animation with dt
end, function() print("for done") end, "tag.for")

-- 5) Tween (table fields overload)
local camera = { x = 0, y = 0, zoom = 1 }
local h5 = timer.tween(1.2, camera, { x = 320, y = 180, zoom = 1.25 }, nil, nil, "cam_move", "camera")
```

---

## Frame Model & Best Practices

**Recommended order per frame:**

1. Input / transform edits (e.g., drags)
2. Optional authoritative push to physics
3. Physics step
4. Authoritative pull from physics
5. **`timer.update(dt)`** — advances all timers
6. Render using your visual state

**Tips**

* Keep `dt` consistent (don’t pass wall time when paused unless intended).
* Prefer **tags** and **groups** for lifecycle control (pause/resume/kill).
* Use **`every` with `times`** for bounded loops instead of manual counters.

---

## Math Utilities

Namespace: `timer.math`

### `remap(value, from1, to1, from2, to2) -> number`

Maps `value` from range `[from1,to1]` to `[from2,to2]` (no clamping).

### `lerp(a, b, t) -> number`

Linear interpolation where `t∈[0,1]`.

```lua
local t = 0.25
local v = timer.math.lerp(10, 20, t)          -- 12.5
local s = timer.math.remap(0.5, 0, 1, 100,0)  -- 50
```

---

## Types & Enums

### `timer.TimerType`

* `RUN` — fire once immediately
* `AFTER` — fire once after delay
* `COOLDOWN` — gate action by cooldown
* `EVERY` — fixed/variable interval
* `EVERY_STEP` — interval eases between start/end
* `FOR` — frame callback for duration
* `TWEEN` — value interpolation

---

## Timer Core API

All functions live on `timer`.

* `timer.update(dt)` — advance all timers; call once per frame.
* `timer.cancel(handle)` — cancel one timer by handle.
* `timer.reset(handle)` — reset elapsed time (e.g., cooldown).
* `timer.get_delay(handle) -> number|nil`
* `timer.get_every_index(handle) -> integer|nil` — current tick count.
* `timer.get_for_elapsed(handle) -> number|nil` — normalized 0…1.
* `timer.get_timer_and_delay(handle) -> (elapsed, delay)`
* `timer.set_multiplier(mult)` / `timer.get_multiplier()` — global speed.

**Group/Tag control**

* `timer.pause(tag)` / `timer.resume(tag)`
* `timer.kill_group(group)`
* `timer.pause_group(group)` / `timer.resume_group(group)`

---

## Timer Creation API

> Any `delay`/`duration`/`interval` parameter accepts a `number` or a `{min,max}` table. If a range is passed, a value is sampled **once at creation**.

### `timer.run`

```lua
handle = timer.run(action:fun(), after?:fun(), tag?:string, group?:string)
```

Runs `action` once (this frame). `after` fires after `action` completes.

**Example**

```lua
timer.run(function() spawn_enemy() end, function() sfx.play("spawn") end, "spawn_now", "wave1")
```

---

### `timer.after`

```lua
handle = timer.after(delay:number|{number,number}, action:fun(), tag?:string, group?:string)
```

Fire `action` once after `delay` seconds.

**Example**

```lua
timer.after({0.3,0.6}, function() ui.flash("READY!") end, "ready_msg")
```

---

### `timer.cooldown`

```lua
handle = timer.cooldown(delay:number|{number,number}, condition:fun():boolean,
                        action:fun(), times?:integer, after?:fun(), tag?:string, group?:string)
```

Runs `action` whenever `condition()` is true **and** cooldown has elapsed. If `times>0`, stops after that many triggers. `after` runs when finished.

**Example**

```lua
local shots = 0
local h = timer.cooldown(0.2, function() return input.fire end, function()
  shots = shots + 1; player:shoot()
end, 10, function() print("burst done") end, "burst")
```

---

### `timer.every`

```lua
handle = timer.every(interval:number|{number,number}, action:fun(),
                     times?:integer, immediate?:boolean,
                     after?:fun(), tag?:string, group?:string)
```

Repeats `action` on an interval. If `immediate` is true, runs once at creation. If `times>0`, stops after that many calls.

**Example**

```lua
-- Pulse 8 times at 0.1s, starting immediately
local h = timer.every(0.1, function() effect:pulse() end, 8, true, function() effect:stop() end, "pulse")
```

---

### `timer.every_step`

```lua
handle = timer.every_step(start_delay:number, end_delay:number, times:integer,
                          action:fun(), immediate?:boolean,
                          step_method?:fun(t:number):number, after?:fun(),
                          tag?:string, group?:string)
```

Runs `action` a fixed number of times while **interpolating** the interval from `start_delay`→`end_delay`. `step_method` shapes the interpolation (`t` is 0→1 over the steps).

**Example**

```lua
-- 20 steps: start fast (0.02) and ramp to slow (0.12) using quadratic ease-out
local quadOut = function(t) return 1 - (1 - t)*(1 - t) end
local h = timer.every_step(0.02, 0.12, 20, function() spawn.spark() end, false, quadOut, nil, "ramp")
```

---

### `timer.for_time`

```lua
handle = timer.for_time(duration:number|{number,number}, action:fun(dt:number), after?:fun(), tag?:string, group?:string)
```

Calls `action(dt)` **every frame** for `duration` seconds. `after` fires once at the end.

**Example**

```lua
-- Screen fade over 0.8s with your own integrator
local alpha = 0
local h = timer.for_time(0.8, function(dt) alpha = math.min(1, alpha + dt/0.8) end,
                         function() ui.hide_overlay() end, "fade")
```

---

### `timer.tween`

> Three overloads drive value(s) from **start→target** over time. Default easing is **linear** if none provided.

#### 1) **Scalar** getter/setter

```lua
handle = timer.tween(duration, getter:fun():number, setter:fun(v:number),
                     target_value:number, tag?:string, group?:string,
                     easing?:fun(t:number):number, after?:fun())
```

**Use when** the value lives behind engine getters/setters.

**Example**

```lua
-- Zoom camera from current to 1.25 in 1.2s with ease-in-out quad
local easeInOutQuad = function(t) return t < 0.5 and 2*t*t or (-1 + (4 - 2*t)*t) end
local h = timer.tween(1.2, camera.getZoom, camera.setZoom, 1.25, "cam_zoom", "camera", easeInOutQuad)
```

#### 2) **Tracks** array (multiple engine-backed values)

```lua
handle = timer.tween(duration, tracks:{ { get:fun():number, set:fun(v:number), to:number, from?:number }[] },
                     easing?:fun(t:number):number, after?:fun(), tag?:string, group?:string)
```

**Use when** tweening several independent values via get/set pairs.

**Example**

```lua
local tracks = {
  { get = camera.getX, set = camera.setX, to = 320 },
  { get = camera.getY, set = camera.setY, to = 180 },
  { get = camera.getZoom, set = camera.setZoom, to = 1.25 },
}
local h = timer.tween(1.2, tracks, nil, nil, "cam_move", "camera")
```

#### 3) **Table fields** (pure Lua table)

```lua
handle = timer.tween(duration, target:table, source:table<string, number>,
                     easing?:fun(t:number):number, after?:fun(), tag?:string, group?:string)
```

**Use when** animating numeric fields on a Lua table. Start values are captured once at creation.

**Example**

```lua
local cam = { x=0, y=0, zoom=1 }
local h = timer.tween(1.2, cam, { x=320, y=180, zoom=1.25 }, nil, function() print("arrived") end, "cam_move", "camera")
```

---

## Timer Control & Query

```lua
-- Pause / resume by tag
timer.pause("cam_move")
timer.resume("cam_move")

-- Pause a whole group (e.g., all UI timers)
timer.pause_group("ui")

-- Kill a group
timer.kill_group("level_intro")

-- Introspection
local i = timer.get_every_index(h3)
local e01, d01 = timer.get_timer_and_delay(h2)
```

---

## Tags, Groups, Multipliers

* **`tag`**: a unique string per logical timer. Re-using a tag lets you pause/resume/cancel that logical timer without tracking handles globally.
* **`group`**: bucket multiple timers to control them together (`pause_group`, `resume_group`, `kill_group`).
* **Global multiplier**: `timer.set_multiplier(s)` scales time for **all** timers (e.g., 0 = freeze, 0.5 = slow-mo, 2 = speedup). Query via `timer.get_multiplier()`.

---

## EventQueueSystem

Event system for building **sequenced** or **conditioned** events with optional easing payloads.

### EventQueueSystem Enums

* `EaseType`: `LERP`, `ELASTIC_IN`, `ELASTIC_OUT`, `QUAD_IN`, `QUAD_OUT`
* `TriggerType`: `IMMEDIATE`, `AFTER`, `BEFORE`, `EASE`, `CONDITION`
* `TimerType`: `REAL_TIME`, `TOTAL_TIME_EXCLUDING_PAUSE`

### EventQueueSystem Data Classes

* **`EaseData`**

  * `type: EaseType`
  * `startValue: number`, `endValue: number`
  * `startTime: number`, `endTime: number`
  * `setValueCallback: fun(value:number)`
  * `getValueCallback: fun():number`

* **`ConditionData`**

  * `check: fun():boolean`

* **`Event`**

  * `eventTrigger: TriggerType`
  * `blocksQueue: boolean`, `canBeBlocked: boolean`
  * `complete: boolean`, `timerStarted: boolean`
  * `delaySeconds: number` (for AFTER)
  * `retainAfterCompletion: boolean`
  * `createdWhilePaused: boolean`
  * `func: function`
  * `timerType: TimerType`
  * `time: number`
  * `ease: EaseData`
  * `condition: ConditionData`
  * `tag: string`, `debugID: string`
  * `deleteNextCycleImmediately: boolean`

### EventQueueSystem Builders

* **`EaseDataBuilder`** (fluent)

  * `:Type(t)`, `:StartValue(v)`, `:EndValue(v)`, `:StartTime(t)`, `:EndTime(t)`
  * `:SetCallback(cb)`, `:GetCallback(cb)`
  * `:Build() -> EaseData`

* **`EventBuilder`** (fluent)

  * `:Trigger(t)`, `:BlocksQueue(b)`, `:CanBeBlocked(b)`
  * `:Delay(seconds)`, `:Func(cb)`
  * `:Ease(easeData)`, `:Condition(condData)`
  * `:Tag(tag)`, `:DebugID(id)`
  * `:RetainAfterCompletion(b)`, `:CreatedWhilePaused(b)`
  * `:TimerType(t)`, `:StartTimer()`
  * `:DeleteNextCycleImmediately(b)`
  * `:Build() -> Event`, `:AddToQueue()`

### EventQueueSystem Core API

* `EventQueueSystem.add_event(event, queue?:string, front?:boolean)`
* `EventQueueSystem.get_event_by_tag(tag, queue?:string) -> Event|nil`
* `EventQueueSystem.clear_queue(queue?:string)`
* `EventQueueSystem.update(forced?:boolean)`

### EventQueueSystem — Worked Examples

**1) Immediate event, blocks queue**

```lua
local ev = EventQueueSystem.EventBuilder()
  :Trigger(EventQueueSystem.TriggerType.IMMEDIATE)
  :BlocksQueue(true)
  :Func(function() cutscene.play("intro") end)
  :Tag("intro_play")
  :Build()

EventQueueSystem.add_event(ev, "cutscene")
```

**2) Delayed event followed by an ease**

```lua
-- First, AFTER 1.0s fire a function
EventQueueSystem.EventBuilder()
  :Trigger(EventQueueSystem.TriggerType.AFTER)
  :Delay(1.0)
  :Func(function() sfx.play("beep") end)
  :Tag("beep")
  :AddToQueue()

-- Then an EASE from current zoom → 1.25 over 1.2s
local ease = EventQueueSystem.EaseDataBuilder()
  :Type(EventQueueSystem.EaseType.LERP)
  :StartValue(camera.getZoom())
  :EndValue(1.25)
  :StartTime(0.0)
  :EndTime(1.2)
  :GetCallback(function() return camera.getZoom() end)
  :SetCallback(function(v) camera.setZoom(v) end)
  :Build()

EventQueueSystem.EventBuilder()
  :Trigger(EventQueueSystem.TriggerType.EASE)
  :Ease(ease)
  :Tag("cam_zoom_ease")
  :AddToQueue()
```

**3) Conditional gate**

```lua
local cond = { check = function() return player:hasKey("boss") end }
EventQueueSystem.EventBuilder()
  :Trigger(EventQueueSystem.TriggerType.CONDITION)
  :Condition(cond)
  :Func(function() door:open() end)
  :Tag("boss_door")
  :AddToQueue()
```

---

## Error Handling & Diagnostics

* All wrapped Lua callbacks are invoked via `sol::protected_function`. Errors are logged (e.g., via spdlog) and the timer continues unless your C++ cancels it.
* If you pass a bad descriptor to `tween(tracks)` or `tween(table, source)`, invalid entries are skipped; `after` is still called if provided.
* `tween` captures **start values once** at creation. Changing them mid-tween won’t retroactively adjust deltas.

---

## Migration Notes & Gotchas

* **Default easing**: unified to **linear** for all tween overloads unless you provide an easing function.
* **Ranges** (`{min,max}`) are sampled once per creation, not every tick.
* **Global multiplier** applies to all timers uniformly. If you need per-timer scaling, extend the API.
* **Tags vs Handles**: both are returned/usable, but tags make orchestration simpler. Be consistent.
* **Threading**: any function passed from coroutine/secondary state is cloned into the main state (`clone_to_main`) to avoid lifetime issues.
* **every\_step semantics**: `times` is the total count; `step_method` receives normalized progress (0→1) across those steps and returns a scale that remaps `start_delay→end_delay`.

---

## Appendix: Handy Easing Snippets

```lua
-- Linear (default)
local linear = function(t) return t end

-- Quadratic in/out
local quadIn  = function(t) return t*t end
local quadOut = function(t) return 1 - (1-t)*(1-t) end
local quadIO  = function(t) return t<0.5 and 2*t*t or (-1 + (4-2*t)*t) end

-- Sine in/out/inout
local sinIn   = function(t) return math.sin(1.5707963 * t) end
local sinOut  = function(t) t = 1 - t; return 1 + math.sin(1.5707963 * (-t)) end
local sinIO   = function(t) return 0.5 * (1 + math.sin(3.1415926 * (t - 0.5))) end
```

---

**Changelog**

* v1.0 — Initial reference covering `timer` + `EventQueueSystem` bindings and examples.
