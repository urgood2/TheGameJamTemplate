# Lua MonoBehaviour (Object-based) — Usage Guide

A concise, copy‑paste‑friendly guide for defining and using Lua “MonoBehaviour”‑style scripts built on your zero‑dep `Object` class. This guide matches the final `node.lua` you shared and plugs directly into your existing C++ `ScriptComponent`/`init_script`/`script_system_update` pipeline.

---

## TL;DR

* Subclass from `Object` (your tiny OOP helper).
* Return a **callable class** (thanks to `__call`) that constructs an **instance table** with hooks.
* Attach the instance to an entity with `registry:add_script(entity, instance)`.
* C++ injects `self.id()` and `self.owner`, caches your hooks, and drives the lifecycle.

---

## File Layout (example)

```
scripts/
  object.lua           -- your OOP helper (already implemented)
  task/
    task.lua           -- your coroutine helper/module (already implemented)
  behaviours/
    node.lua           -- your final script (below)
```

---

## Final Script (reference)

This is the script you provided, shown here as a reference:

```lua
local Object = require("object")
local task = require("task/task")

local node = Object:extend()

-- Called once, right after the component is attached.
function node:init(args) end

-- Called every frame by script_system_update()
function node:update(dt)
    print('node [#' .. self.id() .. '] update()', transform)
    -- local transform = self.owner:get(self.id(), Transform)

    -- coroutine task example
    -- task.run_named_task("blinker", function()
    --     print("start")
    --     task.wait(1.0)
    --     print("end")
    --   end)

    print("tasks active:", task.count_tasks())
end

-- Called just before the entity is destroyed
function node:destroy()
    print('bye, bye! from: node #' .. self.id())
end

function node:on_collision(other) end

-- Merge args into self before init so init can read them
function node:__call(args)
  local obj = setmetatable({}, self)
  if type(args) == "table" then
    for k, v in pairs(args) do obj[k] = v end
  end
  if obj.init then obj:init(args) end
  return obj
end

return node
```

> **Note**: `print('... update()', transform)` references a `transform` variable that’s commented out; uncomment the `self.owner:get(...)` line (shown below) to actually fetch it.

---

## Lifecycle at a Glance

1. **Construction (Lua)**: `local inst = Node{ speed = 200 }` → returns a table with your fields; calls `init(args)`.
2. **Attach (Lua → C++)**: `registry:add_script(entity, inst)`.
3. **Initialize (C++)**: `init_script` injects `self.id()` and `self.owner`, caches hooks (`update`, `on_collision`, `destroy`), and may call `self.init(self, args)` if you do that during `__call`.
4. **Update (C++)**: `script_system_update` calls `self.update(self, dt)` each frame if present.
5. **Collision (C++)**: Your physics/collision system triggers `self.on_collision(self, other)` if present.
6. **Destruction (C++)**: On entity teardown, `self.destroy(self)` is called if present.

---

## Creating a Behaviour

### 1) Define your class

```lua
local Object = require("object")
local task = require("task/task")

local Node = Object:extend()

function Node:init(args)
  -- args are already merged into self by __call
  self.speed = self.speed or 100
  self.hp    = self.hp    or 10
  self.x, self.y = 0, 0
end

function Node:update(dt)
  -- Example: move in +X over time
  self.x = self.x + (self.speed or 0) * dt
  -- Access your Transform from C++ registry if you’ve bound it
  -- local Transform = Transform  -- (imported/bound type)
  -- local tr = self.owner:get(self.id(), Transform)
  -- tr.x = self.x
end

function Node:on_collision(other)
  -- react to collisions here
end

function Node:destroy()
  print("Node #"..self.id().." destroyed at:", self.x, self.y)
end

function Node:__call(args)
  local obj = setmetatable({}, self)
  if type(args) == "table" then
    for k, v in pairs(args) do obj[k] = v end
  end
  if obj.init then obj:init(args) end
  return obj
end

return Node
```

### 2) Construct and attach

```lua
local Node = require("behaviours/node")

-- Create an instance with initial fields (merged before init runs)
local node_instance = Node{ speed = 220, hp = 12 }

-- Attach to an entity (C++ will inject self.id()/self.owner and cache hooks)
registry:add_script(entity, node_instance)
```

> You can keep using **plain tables** too; the C++ side just needs a table with optional hooks (`init`, `update`, `on_collision`, `destroy`).

---

## Accessing C++ Registry/Components

Your C++ `init_script` exposes:

* `self.id()` → returns the current entity ID.
* `self.owner` → your C++ Registry interface.

Typical component access (pseudocode — adapt to your actual bindings):

```lua
-- Assuming `Transform` is a bound userdata/type name accessible in Lua
local tr = self.owner:get(self.id(), Transform)
tr.x = tr.x + 1
```

If your binding supports safe queries:

```lua
local tr = self.owner:try_get(self.id(), Transform)
if tr then
  -- use tr
end
```

---

## Tasks / Coroutines (`task` module)

If you’ve wired a `task` API that integrates with `ScriptComponent::add_task` or a scheduler, you can launch coroutines from your behaviour.

### Fire‑and‑forget task

```lua
function Node:init()
  task.run_task(function()
    print("fade start")
    task.wait(1.0)
    print("fade end")
  end)
end
```

### Named task (auto‑dedup / restart behaviour depends on your implementation)

```lua
function Node:update(dt)
  if not self._started then
    task.run_named_task("blinker", function()
      while true do
        -- do something
        task.wait(0.5)
      end
    end)
    self._started = true
  end
end
```

### Inspect running tasks

```lua
print("tasks active:", task.count_tasks())
```

> Ensure your Lua `task` module bridges to C++ (or a Lua scheduler) so tasks actually tick each frame.

---

## Patterns & Tips

**Constructor args are fields.** Because `__call` merges `args` first, `init(args)` can immediately read `self.speed`, `self.hp`, etc.

**Hooks are optional.** If a hook is missing (e.g., `on_collision`), C++ will just skip it.

**Prefer returning the class, not an instance, from your behaviour module.** Construct instances at the call site so you can pass per‑entity args.

**Debugging:**

* Add `print("entity:", self.id())` in `init` to verify the C++ injection.
* If `self.owner` is `nil`, confirm `registry:add_script` is called before your first `update` and that `init_script` runs.

**Coexist with plain tables:**

```lua
local Plain = {
  init = function(self) self.t = 0 end,
  update = function(self, dt) self.t = self.t + dt end,
}
registry:add_script(entity, Plain)
```

---

## Minimal Helper (optional)

If you want one call that accepts either a **class** (callable) or a **plain table**:

```lua
function registry.attach_script(entity, cls_or_tbl, args)
  local t = cls_or_tbl
  if type(cls_or_tbl) == 'table' and cls_or_tbl.__call then
    t = cls_or_tbl(args)
  end
  registry:add_script(entity, t)
  return t
end
```

Usage:

```lua
registry.attach_script(entity, Node, { speed = 300 })  -- class
registry.attach_script(entity, Plain)                  -- plain table
```

---

## FAQ

**Q: Do I have to call a super constructor?**
A: Only if you create a subclass of a subclass. With `Object:extend()`, call `Child.super.init(self, args)` inside your child’s `init` if the parent has one.

**Q: Can I add mixins?**
A: Yes. Your `Object:implement(Mixin)` copies functions that don’t exist yet on the class.

**Q: Where do `id()` and `owner` come from?**
A: From your C++ `init_script` when the script is attached.

**Q: Can I rename hooks?**
A: Keep `init`, `update`, `on_collision`, `destroy` for zero‑config compatibility. You can alias in C++ if you want, but it’s optional.

---

## Copy‑Start Template

Use this as a starting point for new behaviours:

```lua
local Object = require('object')
local task = require('task/task')

local MyBehaviour = Object:extend()

function MyBehaviour:init(args)
  self.speed = self.speed or 100
end

function MyBehaviour:update(dt)
  -- local Transform = Transform
  -- local tr = self.owner:get(self.id(), Transform)
  -- tr.x = tr.x + self.speed * dt
end

function MyBehaviour:on_collision(other)
end

function MyBehaviour:destroy()
end

function MyBehaviour:__call(args)
  local obj = setmetatable({}, self)
  if type(args) == 'table' then for k,v in pairs(args) do obj[k]=v end end
  if obj.init then obj:init(args) end
  return obj
end

return MyBehaviour
```

---

## Final Checklist

* [ ] Require `object.lua` and (optionally) `task/task.lua`.
* [ ] Return a class (not an instance) from the module.
* [ ] Use `Class{...}` to construct with args.
* [ ] Attach with `registry:add_script(entity, instance)`.
* [ ] Use `self.id()` and `self.owner` inside hooks.
* [ ] (Optional) Use `task` helpers for coroutines.

You’re set. Define classes, attach them, and let your existing C++ systems drive the lifecycle. Enjoy the mix‑and‑match flexibility with plain tables or class‑style behaviours.
