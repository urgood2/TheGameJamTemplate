# TimerChain Reference

Fluent, chainable API for Lua timer sequences. Helps you build precise, maintainable timelines of timed actions.

---

## 🧩 Core Idea

* Each chain holds a list of **steps**.
* Steps are added with calls like `:after`, `:wait`, `:every`, `:tween`.
* Nothing happens until you call `:start()`.
* `start()` walks the steps, keeps a running **offset** (timeline cursor), and schedules timers.
* Some steps **advance offset** (serial), others **spawn side-jobs** (parallel).

---

## 🔄 Serial vs Parallel

### Serial (advance the offset)

* `:after(delay, fn)` → wait `delay` then run `fn`.
* `:wait(delay)` → wait `delay` with no action.
* `:tween(duration, getter, setter, target, ...)`
* `:for_time(duration, fn_dt, ...)`

### Parallel (don’t advance offset)

* `:every(interval, fn, times?, immediate?, after?)`
* `:cooldown(delay, cond, fn, ...)`
* `:every_step(start, finish, times, fn, ...)`
* `:fork(chain)`

### onComplete

Always fires at the **final offset**.

---

## 📜 Example Timelines

### 1. Serial only

```lua
TimerChain.new()
  :after(1, function() print("A") end)
  :wait(2)
  :after(1, function() print("B") end)
  :onComplete(function() print("done") end)
  :start()
```

Timeline:

```
t=1  → A
t=3  → (wait done)
t=4  → B
t=4  → done
```

---

### 2. Parallel step (`every`)

```lua
TimerChain.new()
  :after(1, function() print("A") end)
  :every(0.5, function() print("tick") end, 4)
  :after(1, function() print("B") end)
  :start()
```

Timeline:

```
t=1.0 → A, tick
t=1.5 → tick
t=2.0 → tick
t=2.0 → B
t=2.5 → tick
```

---

### 3. Forking another chain

```lua
local side = TimerChain.new()
  :every(0.3, function() print("blink") end, 3)

TimerChain.new()
  :after(1, function() print("X") end)
  :fork(side)
  :after(2, function() print("Y") end)
  :start()
```

Timeline:

```
t=1.0 → X + fork starts
       side-chain blinks at 1.0, 1.3, 1.6
t=3.0 → Y
```

---

## 🎛️ Groups and Tags

* Each chain has a **group** (default = unique id).
* Steps auto-tag as `chainId_index` unless overridden.
* Control whole chain:

```lua
TimerChain.new("intro")
  :after(1, fn)
  :start()

-- Later:
timer.pause_group("intro")
timer.resume_group("intro")
timer.kill_group("intro")
```

---

## 🧪 Cheat Sheet

* `:after(delay, fn)`
* `:wait(delay)`
* `:do_now(fn)` → alias for `:after(0, fn)`
* `:then_(fn)` → alias for immediate `after`
* `:every(interval, fn, times?, immediate?, after?)`
* `:cooldown(delay, cond, fn, times?, after?)`
* `:every_step(start_delay, end_delay, times, fn, ...)`
* `:for_time(duration, fn_dt, after?)`
* `:tween(duration, getter, setter, target, easing?, after?)`
* `:fork(chain)`
* `:withGroup(group)`
* `:pause()` / `:resume()` / `:cancel()`
* `:onComplete(fn)`
* `:start()`

---

## 🗺️ Mental Model Diagram

```
Serial steps:  offset →───(after)───(wait)───(tween)

Parallel steps: spawn off to the side, offset keeps moving

   main chain → A ──────── B
                  ╲
                   every → tick → tick → tick
```
