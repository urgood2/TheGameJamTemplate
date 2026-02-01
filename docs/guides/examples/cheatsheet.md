# Lua Scripting & AI Cheatsheet

*An extensive reference to your current Lua-based game scripting, AI setup, and coroutine/task utilities.*

Notes: 
- all directory paths in scripts are added to Lua's `package.path` in C++ automatically, as well as any subdirectories and .lua files within them. 
- The lua context comes preloaded with `sol::state` bindings for your ECS registry, `Transform`, `Sprite`, `ScriptComponent`, `Timer`, `Scheduler`, `InputState`, and other core types, which can be found in [this file](chugget_code_definitions.lua).

---

## 1. Required Modules & Globals

```lua
local globals = require("init.globals")   -- core game constants & registry handle
require("registry")                       -- registers `registry` global for ECS ops
local task    = require("task.task")      -- coroutine helpers: wait, run_named_task
require("ai.init")                       -- loads/initializes global `ai` definitions from scripts
require("util.util")                     -- utility functions: log_debug(), fadeOutScreen(), etc.
```

* **globals**: holds shared singletons (registry, inputState, etc.)
* **registry**: your EnTT-backed world interface (`create`, `emplace`, `get`, `add_script`, `runtime_view`, etc.)
* **task.task**: Lua module providing `task.wait`, `task.run_named_task`, and named coroutine management
* **ai.init**: populates a global `ai` table with `entity_types`, `actions`, `worldstate_updaters`, `goal_selectors`, `blackboard_init`
* **util.util**: common functions (e.g. `log_debug(...)`, `fadeOutScreen(duration)`)

---

## 2. Game Loop Skeleton

```lua
main = {}

function main.init()
  -- One-time setup: spawn entities, attach scripts & timers, configure AI
end

function main.update(dt)
  -- Per-frame logic: update physics, scripts, scheduler, AI tick
end

function main.draw(dt)
  -- Per-frame rendering: draw sprites, UI, debug overlays
end
```

**Key Points:**

* `dt` is the delta-time in seconds since the last frame.
* Put heavy setup in `main.init()` to avoid runtime allocations.
* `main.update()` is where you drive your simulation (entity scripts, AI planning).

---

## 3. Defining ScriptComponent Tables

Each script is just a Lua table with optional methods: `init`, `update`, `on_collision`, and `destroy`.

```lua
local PlayerLogic = {
  -- custom fields (persist per-entity)
  speed = 150,  -- movement speed (px/sec)
  hp    = 10,

  init = function(self)
    -- called once when script is attached
    print("[Player] init; id=", self.id)
    self.x, self.y = 0, 0
  end,

  update = function(self, dt)
    -- called each frame
    self.x = self.x + self.speed * dt
    -- access other components:
    -- local t = self.owner:get(self.id, Transform)
    -- t.actualX, t.actualY = self.x, self.y
  end,

  on_collision = function(self, other)
    -- called when this entity collides with `other` entity
  end,

  destroy = function(self)
    -- called just before entity removal
    print("[Player] destroyed at (", self.x, ",", self.y, ")")
  end,
}
```

**Attach** to an entity:

```lua
local e = registry:create()
registry:add_script(e, PlayerLogic)
```

---

## 4. Spawning Entities with AI

Use `create_ai_entity(type, overrides?)` to spawn GOAP-driven creatures.

### Default spawn

```lua
local kobold = create_ai_entity("kobold")
```

Spawns with prototype data from `ai.entity_types.kobold`.

### With overrides

```lua
local custom = create_ai_entity("kobold", {
  initial = { hungry=false, has_food=true },
  goal    = { wandering=true },
  blackboard_init = function(e)
    local bb = get_blackboard(e)
    bb:set_double("speed_mod", 1.5)
  end,
})
```

* **`overrides`**: table where keys match any top-level in the AI-definition (`initial`, `goal`, `blackboard_init`, `select_goal`, `actions`, etc.). Overrides are merged *after* deep-copying the prototype.
* **Common override targets**:

  * `initial`: world-state keys
  * `goal`: target-state keys
  * `blackboard_init(e)`: set up custom blackboard data
  * `select_goal(e)`: supply custom goal-selection logic

---

## 5. AI Definition Structure

Your `ai` table (printed via `dump(ai)`) looks like:

```lua
ai = {
  entity_types = {
    kobold = {
      initial = { hungry=true, enemyvisible=false, has_food=true },
      goal    = { hungry=false },
      init_blackboard = function(e) ... end,
      select_goal     = function(e) ... end,
    }
  },

  actions = {
    eat = {
      name   = "eat",
      cost   = 1,
      pre    = { hungry=true },
      post   = { hungry=false },
      start  = function(e) ... end,
      update = function(self,e,dt) ... end,
      finish = function(e) ... end,
    }
  },

  worldstate_updaters = {
    hunger_check  = function(e,dt) ... end,
    enemy_sight   = function(e,dt) ... end,
  },

  goal_selectors = {
    kobold = function(e) ... end,
  },

  blackboard_init = {
    kobold = function(e) ... end,
  },
}
```

Load order in C++:

1. `actions` (global)
2. `worldstate_updaters` (global)
3. `entity_types[type].initial`, `goal`, `init_blackboard`, `select_goal`

---

## 6. Coroutine & Task Utilities

### `task.wait(seconds)`

Yield inside a coroutine until `seconds` have elapsed.

```lua
task.wait(2.5)  -- suspends for 2.5s (accumulates dt)
```

### `task.run_named_task(self, name, fn)`

Starts a Lua coroutine bound to `self` with identifier `name`.

```lua
task.run_named_task(self, "blinker", function()
  print("Blink start")
  task.wait(5.0)
  print("Blink end")
end)
```

* Multiple named tasks can coexist per-entity.
* Use `self._flags[name] = true` to prevent re-spawning.

### `scheduler:attach(p1, p2, ...)`

Chain a sequence of process-tables (each with an `update(dt)` method).

```lua
scheduler:attach(p1, p2, p3)
```

Each process runs to completion (`wait` returns) before the next starts.

---

## 7. Timers & Utilities

### `timer.every(interval, fn, count, repeat, tag)`

Schedule `fn()` every `interval` seconds.

* `count`: run this many times (`0` for infinite)
* `repeat`: **true** to auto-repeat
* `tag`: optional string to cancel later

```lua
timer.every(1.0, function()
  log_debug("Tick @" .. tostring(os.clock()))
end, 0, true, nil, "tick_timer")
```

### Debug Helpers

* `log_debug(...)` — your C++‑bound logger
* `dump(table)` — pretty-print any Lua table
* `os.clock()` — CPU time, useful for profiling tasks

---

---

## 8. Dynamic Goal Selector Overrides

You can swap or tweak an entity’s goal selector at runtime by grabbing its per-instance AI definition table:

```lua
local ai_def = ai.get_entity_ai_def(myEntity)

-- Swap in a brand-new selector for just this instance:
ai_def.goal_selectors[ ai_def.type ] = function(e)
  -- your custom logic:
  ai.set_goal(e, { custom_flag = true })
end

-- OR tweak the existing selector:
local old_sel = ai_def.goal_selectors[ ai_def.type ]
ai_def.goal_selectors[ ai_def.type ] = function(e)
  -- run original selector first:
  old_sel(e)
  -- then apply extra world-state changes:
  ai.set_worldstate(e, "extra_flag", true)
end
```

### End of Cheatsheet

Keep this reference next to your editor for fast lookup!

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
