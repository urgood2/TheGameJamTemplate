# Lua MonoBehaviour (Object‑based) — Usage Guide (Updated)

A concise, copy‑paste‑friendly guide for defining and using Lua “MonoBehaviour”‑style scripts built on your zero‑dep `Object` class, with **ECS attach helpers** (`attach_ecs`, `run_custom_func`, `handle`). This matches the **updated `node.lua`** you provided and plugs directly into your existing C++ `ScriptComponent` / `init_script` / `script_system_update` pipeline.

---

## TL;DR

* Subclass from `Object`; your class is **callable** via `__call` → `Class{...}` constructs an **instance table** and runs `init(args)`.
* Use `registry:add_script(entity, instance)` or call `instance:attach_ecs{ ... }` to bind to an EnTT entity.
* `attach_ecs{}` by default **creates a new entity** and **attaches the script**. Pass `existing_entity = <eid>` to attach to an existing one. Pass `create_new = false` to do nothing ECS‑wise.
* Use `instance:run_custom_func(function(eid, self) ... end)` to run ECS‑dependent setup (queued until attached, or immediate if already attached).
* `instance:handle()` returns the EnTT entity ID once attached.

---

## File Layout (example)

```
scripts/
  external/object.lua    -- your OOP helper (already implemented)
  task/
    task.lua             -- your coroutine helper (already implemented)
  behaviours/
    node.lua             -- the updated script (see below)
```

---

## Final Script (reference)

Below is the **reference structure** your `node.lua` follows. Your actual file already contains these pieces.

```lua
local Object = require("external/object")
local task = require("task/task")

local node = Object:extend()

-- This script is a MonoBehavior script that will be attached to a node. It should be named accordingly for the component it represents, and linked up c++ side.

-- Called once, right after the component is attached.
function node:init(args) end

-- Called every frame by script_system_update()
function node:update(dt)
    print('node [#' .. self.id() .. '] update()', transform)
    -- local transform = self.owner:get(self.id(), Transform)

    -- coroutine task example
    -- task.run_named_task("blinker", function()
    --   print("start")
    --   task.wait(1.0)
    --   print("end")
    -- end)

    print("tasks active:", task.count_tasks())
end

-- Called just before the entity is destroyed
function node:destroy()
    print('bye, bye! from: node #' .. self.id())
end

function node:on_collision(other) end

-- Merge args into self before init so init can read them, also return self from __call for chaining
function node:__call(args)
  local obj = setmetatable({}, self)
  if type(args) == "table" then
    for k, v in pairs(args) do obj[k] = v end
  end
  if obj.init then obj:init(args) end
  return obj
end

-- ===== ECS attach helpers (ADD-ONLY) =====
-- Requires a global `registry` (entt::registry) with:
--   registry:create(), registry:destroy(eid), registry:add_script(eid, lua_table)
--   (and your meta-based :emplace/:get if you use them elsewhere)

-- Fetch stored entity id (if any)
function node:handle()
  return self._eid
end

-- Queue or immediately run a custom function.
-- Signature: fn(eid, self)
function node:run_custom_func(fn)
  if type(fn) ~= "function" then return self end
  if self._eid then
    -- already attached → run immediately
    fn(self._eid, self)
  else
    -- not attached yet → queue
    if not self._queued_funcs then self._queued_funcs = {} end
    table.insert(self._queued_funcs, fn)
  end
  return self
end

-- Attach policy:
-- opts = {
--   create_new      = true,     -- default true
--   existing_entity = <eid>,    -- if set, attach to this entity (no creation)
-- }
function node:attach_ecs(opts)
  opts = opts or {}
  local create_new = (opts.create_new ~= false) and (opts.existing_entity == nil)
  assert(type(registry) == "userdata" or type(registry) == "table",
         "global 'registry' must be bound to an entt::registry instance")

  -- Pure Lua object case: explicitly disable both
  if not create_new and not opts.existing_entity then
    return self
  end

  -- Create or use existing
  local eid = opts.existing_entity
  if not eid then
    eid = registry:create()
  end

  -- Always attach ScriptComponent
  registry:add_script(eid, self)

  -- Stash handle
  self._eid = eid

  -- Flush queued run_custom_func callbacks (if any)
  if self._queued_funcs then
    for i = 1, #self._queued_funcs do
      local fn = self._queued_funcs[i]
      if type(fn) == "function" then fn(eid, self) end
    end
    self._queued_funcs = nil
  end

  return self
end

return node
```

> **Note:** `print('... update()', transform)` references a local `transform` variable; uncomment the `self.owner:get(...)` line to fetch it from C++ if you’ve bound `Transform`.

---

## Lifecycle at a Glance

1. **Construction (Lua)** → `local inst = Node{ speed = 200 }` merges fields then calls `init(args)`.
2. **Attach (Lua → C++)** → either `registry:add_script(entity, inst)` **or** `inst:attach_ecs{ ... }`.
3. **Initialization (C++)** → `init_script` injects `self.id()` and `self.owner`, caches hooks (`update`, `on_collision`, `destroy`).
4. **Update (C++)** → `script_system_update` calls `self:update(dt)` each frame if present.
5. **Collision (C++)** → physics/collision system calls `self:on_collision(other)` if present.
6. **Destruction (C++)** → on entity teardown, `self:destroy()` runs if present.

---

## Attaching Options (All Cases)

### A) **Pure Lua object** (no entity side‑effects)

```lua
HitCircle{ x = 10, y = 20 }
  :attach_ecs{ create_new = false }      -- explicitly do nothing ECS‑wise
  :run_custom_func(function(eid, self)    -- queued, but since no attach happens, this stays queued
    -- will NOT run (no entity)
  end)
```

### B) **Create a new entity (default)**

```lua
local c = HitCircle{ x = 10, y = 20, rs = 12, color = 0xFFAA88FF }
  :run_custom_func(function(eid, self)
    -- Add components via meta API once attached
    -- registry:emplace(eid, Transform)
    -- local t = registry:get(eid, Transform)
    -- t.x, t.y = self.x or 0, self.y or 0
  end)
  :attach_ecs{}  -- create_new=true by default
```

### C) **Attach to an existing entity**

```lua
local eid = lookup_some_entity()
HitCircle{ x = 30, y = 60 }
  :run_custom_func(function(eid, self)
    -- Will run immediately after attach_ecs below
  end)
  :attach_ecs{ existing_entity = eid }
```

### D) **Queue multiple custom steps** (order preserved)

```lua
HitCircle{ rs = 24, color = 0xFFAA44FF }
  :run_custom_func(function(eid, self) -- A
    -- setup A
  end)
  :run_custom_func(function(eid, self) -- B
    -- setup B
  end)
  :attach_ecs{}                        -- runs A then B
  :run_custom_func(function(eid, self) -- runs immediately (already attached)
    -- setup C
  end)
```

---

## Method Overrides (Per‑Instance, No New Types)

You can override or wrap any method on **just one instance**:

```lua
local c = HitCircle{ x = 50, y = 50 }:attach_ecs{}

-- Replace update for this instance only
c.update = function(self, dt)
  print("Custom update for entity", self:handle(), dt)
end

-- Wrap destroy (call original then extra)
local base_destroy = c.destroy
c.destroy = function(self)
  if base_destroy then base_destroy(self) end
  print("Extra cleanup for", self:handle())
end
```

This works because instances are plain tables; method lookups hit the instance first before falling back to the class.

---

## Common Patterns

### Chainable Construction + Attach + Custom Setup

```lua
HitCircle{ x = self.x, y = self.y, rs = 12, color = self.color }
  :run_custom_func(function(eid, self)
    -- e.g., give it a Transform & tweak
    -- registry:emplace(eid, Transform)
    -- local t = registry:get(eid, Transform)
    -- t.x, t.y = self.x, self.y
  end)
  :attach_ecs{}
  :run_custom_func(function(eid, self)
    -- e.g., start a particle component, status flags, etc.
  end)
```

### Pure Lua Behaviour (No Entity)

```lua
local ghost = Node{ hp = 1 }:attach_ecs{ create_new = false }
-- still updated by script system if you attach via registry elsewhere
```

### Late Customization After Attach

```lua
local inst = Node{ speed = 200 }:attach_ecs{}
inst:run_custom_func(function(eid, self)
  -- modify components that require the entity to exist
end)
```

---

## Accessing C++ Registry/Components

Your engine provides:

* `self.id()` → the current entity ID (EnTT handle)
* `self.owner` → your registry interface (the bound `entt::registry` methods)

Typical component operations (pseudocode; match your bindings):

```lua
-- Using meta-based APIs you exposed on the registry usertype
registry:emplace(eid, Transform)                 -- default-construct component
local tr = registry:get(eid, Transform)          -- get_or_emplace and return reference
tr.x, tr.y = 100, 200

-- Checks
if registry:has(eid, Transform) then
  local tr = registry:get(eid, Transform)
end

-- Cleanup
registry:remove(eid, Transform)
```

> All of the above can be placed inside `run_custom_func` to ensure `eid` exists.

---

## Tasks / Coroutines (`task` module)

```lua
function node:init()
  task.run_task(function()
    task.wait(0.25)
    print("quarter second passed for", self.id())
  end)
end

function node:update(dt)
  if not self._started then
    task.run_named_task("blinker", function()
      while true do
        -- do something periodically
        task.wait(0.5)
      end
    end)
    self._started = true
  end
end

print("tasks active:", task.count_tasks())
```

Ensure your scheduler ticks these tasks each frame (either via C++ or a Lua update loop).

---

## Conditional Destruction (`:destroy_when`)

You can queue automatic deletion of an entity by chaining `:destroy_when`.  
It sets up a timer that checks a **predicate function** until it returns true, then destroys the entity via `registry:destroy`.

### Usage

```lua
obj:destroy_when(function(self, eid)
  -- Return true when the entity should be destroyed
  return self.hp <= 0
end, {
  interval = 0,   -- seconds between checks (0 = every frame)
  grace    = 0,   -- delay before destroy after condition met
  timeout  = nil, -- optional max seconds before giving up
  tag      = nil, -- optional timer tag
  group    = nil, -- optional timer group
})
```

---

## Troubleshooting Checklist

* **`self.id()` is nil or errors:** confirm the instance was attached via `registry:add_script(eid, inst)` or `inst:attach_ecs{}` **before** the first frame update.
* **`self.owner` is nil:** verify your C++ `init_script` injects it when the script is attached.
* **Queued `run_custom_func` didn’t run:** this only runs when `attach_ecs{}` actually attaches. If you passed `create_new = false` and no `existing_entity`, nothing attaches.
* **Chaining broke:** make sure every utility you add returns `self`.
* **Crashes on component access:** ensure the component type is bound and that your meta `emplace/get` signatures match your engine’s expectations.

## Final Checklist

* [ ] Use `Class{...}` to construct; `__call` merges args then runs `init`.
* [ ] Attach via `registry:add_script(eid, inst)` or `inst:attach_ecs{ ... }`.
* [ ] Use `run_custom_func` for ECS‑dependent setup; it queues until attached.
* [ ] Retrieve the EnTT handle with `handle()` when needed.
* [ ] Keep all helpers chainable (`return self`).
* [ ] Bind your component types and meta functions on the C++ side.

You’re set. Define behaviours, attach them cleanly, and build ECS‑aware setup in small, composable steps with `run_custom_func`. Enjoy the one‑liner ergonomics with explicit control when you need it.
