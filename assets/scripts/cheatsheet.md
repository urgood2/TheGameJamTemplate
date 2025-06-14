# Lua Scripting & Coroutine Cheatsheet

---

## 1. Module Imports

```lua
local globals  = require("init.globals")
require("registry")                 -- attaches `registry` global
local task     = require("task/task")
```

* **`globals`**: shared constants / utilities
* **`registry`**: your EnTT registry bindings
* **`task`**: coroutine helper (wait, run\_named\_task, etc.)

---

## 2. Main Game Loop Module

```lua
main = {}

function main.init()
  -- runs once at startup
end

function main.update(dt)
  -- runs every frame before draw
end

function main.draw(dt)
  -- runs every frame for rendering
end
```

* Place entity-creation, scheduler setup, etc. in `main.init()`
* Use `dt` for frame-rate–independent logic

---

## 3. Entity & ScriptComponent Setup

```lua
-- create an entity
local eid = registry:create()

-- attach a script table
registry:add_script(eid, PlayerLogic)
```

* `registry:create() → entity-id`
* `registry:add_script(id, table)`

  * your C++ system looks for `init/update/destroy` on that table

---

## 4. Script-Table Structure

```lua
local PlayerLogic = {
  -- custom fields
  speed = 150,
  hp    = 10,

  -- called immediately after add_script
  init = function(self)
    self.x, self.y = 0, 0
    print("[player] init, id =", self.id)
  end,

  -- called every frame: dt is seconds since last frame
  update = function(self, dt)
    self.x = self.x + self.speed * dt
    -- can access other components:
    -- self.owner:get(self.id, Transform).x = self.x
  end,

  -- called when entity is destroyed
  destroy = function(self)
    print("[player] destroy; final pos:", self.x, self.y)
  end,
}
```

* **`self.id`** & **`self.owner`** come from your C++ binding
* Keep per-entity state inside the table (`self.x`, `self._flag`, etc.)

---

## 5. Spawning Coroutine Tasks

### A) `task.run_named_task`

```lua
task.run_named_task(self, "task_name", function()
  -- arbitrary coroutine code
  task.wait(5.0)
  print("done waiting")
end)
```

* **Parameters**:

  1. `self` (script table)
  2. name/ID string
  3. function body

* **Inside** your `M.wait(seconds)`:

  ```lua
  local elapsed = 0
  while elapsed < seconds do
    local dt = coroutine.yield()   -- yields back to C++
    elapsed = elapsed + dt
  end
  ```

### B) Batch scheduling via `scheduler:attach`

```lua
local p1 = { update = function(self, dt) debug("P1 start"); task.wait(5.0); debug("P1 end") end }
local p2 = { update = function(self, dt) debug("P2 start"); task.wait(5.0); debug("P2 end") end }
local p3 = { update = function(self, dt) debug("P3 start"); task.wait(10.0); debug("P3 end") end }

scheduler:attach(p1, p2, p3)
```

* Chaining multiple processes in sequence
* Each `update` table is run one after the previous succeeds

---

## 6. Debug & Timing

* **`print(...)`**: standard console output
* **`debug(...)`**: your custom debug logger
* **`os.clock()`**: CPU-time stamp—good for rough profiling
* Example:

  ```lua
  print("▶︎ Task start @ " .. tostring(os.clock()))
  ```

---

## 7. Common Patterns

* **One-time flags**:

  ```lua
  if not self._spawned then
    -- spawn tasks
    self._spawned = true
  end
  ```

* **Loop-driven spawns**:

  ```lua
  for i, delay in ipairs({10,20,30}) do
    task.run_named_task(self, "t"..i, function()
      print("start", i); task.wait(delay); print("end", i)
    end)
  end
  ```

* **Access other components**:

  ```lua
  local pos = self.owner:get(self.id, Transform)
  pos.x, pos.y = ...
  ```

---

Keep this cheat-sheet handy as you expand your system—each section maps directly to the patterns in your code above.
