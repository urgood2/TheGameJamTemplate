# Physics + Steering Lua API — Quick Guide & Examples

This doc shows how to drive your Chipmunk2D physics + steering from Lua using the bindings you exposed in `expose_physics_to_lua`, `expose_steering_to_lua`, and **`expose_physics_manager_to_lua`**. It sticks to **exactly** the signatures you bound (no extras) and uses **Chipmunk units** throughout.

> **Units & Coordinates**
>
> * "Chipmunk units" here match your engine’s physics units.
> * If your render world is Raylib pixels, convert with your helpers (`raylibToChipmunkCoords`, etc.) and mind the Y‑flip when sampling from the screen.

---

## Table of Contents

1. [Setup: Creating a world](#setup-creating-a-world)
2. [Collision tags, masks & triggers](#collision-tags-masks--triggers)
3. [Adding colliders](#adding-colliders)
4. [Creating physics from transforms](#creating-physics-from-transforms)
5. [Physics Manager & Navmesh (`pm.*`)](#physics-manager--navmesh-pm)
6. [Queries: Raycast & AABB](#queries-raycast--aabb)
7. [Collision/Trigger events](#collisiontrigger-events)
8. [Steering: Make an agent & update](#steering-make-an-agent--update)
9. [Steering behaviors](#steering-behaviors)

   * [Seek / Flee](#seek--flee)
   * [Wander](#wander)
   * [Boids (Separate / Align / Cohesion)](#boids-separate--align--cohesion)
   * [Pursuit / Evade](#pursuit--evade)
   * [Path following](#path-following)
   * [Timed forces & impulses](#timed-forces--impulses)
10. [Practical patterns](#practical-patterns)
11. [Gotchas & FAQs](#gotchas--faqs)

---

## Setup: Creating a world

```lua
-- Construct a PhysicsWorld (C++ ctor is PhysicsWorld(entt::registry*, meter, gx, gy)).
local W = physics.PhysicsWorld(registry, 64.0, 0.0, 900.0)  -- 64 px = 1 unit, gravity downward

-- Step each frame:
function game_update(dt)
  W:Update(dt)
  W:PostUpdate()  -- if you buffer events that flush after stepping
end

-- Optional visuals (debug)
function game_debug_draw()
  W:RenderColliders()
end
```

---

## Collision tags, masks & triggers

Define your allowed collisions declaratively with **tags**.

```lua
-- Define the universe of tags (order defines category ids internally)
W:SetCollisionTags({ "player", "enemy", "projectile", "terrain", "sensor" })

-- Enable/disable collision pairs (adds/removes masks)
W:EnableCollisionBetween("player", {"enemy", "terrain"})
W:DisableCollisionBetween("player", {"projectile"}) -- player bullets pass through self, for example

-- Triggers are separate, for sensor-style overlaps
W:EnableTriggerBetween("sensor", {"player", "enemy"})

-- Add/remove tags at runtime if needed
W:AddCollisionTag("pickup")
W:EnableCollisionBetween("player", {"pickup"})

-- Print table for sanity
W:PrintCollisionTags()
```

> **Note**: After changing masks, call `W:UpdateCollisionMasks(tag, collidesWith)` for a bulk reset on that tag if you want to reapply to existing shapes.

---

## Adding colliders

`physics.AddCollider(world, e, tag, shapeType, a, b, c, d, isSensor, points?)`

* `shapeType`: `'rectangle'|'circle'|'segment'|'polygon'|'chain'`
* `(a,b,c,d)` meanings:

  * **rectangle**: `a=width`, `b=height` (centered on body position unless you offset in C++)
  * **circle**: `a=radius` (b/c/d ignored)
  * **segment**: `a=x1`, `b=y1`, `c=x2`, `d=y2`
  * **polygon / chain**: pass `points = { {x,y}, ... }`; `(a..d)` ignored
* `isSensor`: sensors don’t collide but do trigger.

```lua
-- Example: player as dynamic rectangle collider
physics.AddCollider(W, player, "player", "rectangle", 32, 48, 0, 0, false)

-- Example: terrain as static chain from explicit vertices
physics.AddCollider(W, ground, "terrain", "chain", 0,0,0,0, false, {
  {x=0,y=300}, {x=200,y=320}, {x=400,y=315}, {x=560,y=290}
})

-- Example: one-way sensor strip
physics.AddCollider(W, sensor, "sensor", "segment", 100,200, 400,200, true)
```

> **Default mask rule**: If a tag’s mask list is empty, your C++ applies a wildcard (collide with all). Configure masks early to avoid surprises.

---

## Creating physics from transforms

`physics.create_physics_for_transform(registry, manager, entity, info)`

This helper builds a physics body + shape from an entity’s **`transform.Transform`** component and inserts it into the correct `PhysicsWorld`.

### What it does

* Reads **actual size/position/rotation** from the `Transform`.
* Builds a Chipmunk `cpBody` + shape (`rectangle` or `circle`, extendable).
* Centers the body correctly (Transform.x/y + half W/H).
* Tags it with the provided **collision tag** and emplaces a `ColliderComponent`.
* Applies tag masks with `ApplyCollisionFilter`.

### Example

```lua
local info = {
  shape = "rectangle", -- or "circle"
  tag   = "player",
  sensor = false,
  density = 1.0
}

-- Create physics body for a transform-backed entity
physics.create_physics_for_transform(registry, physicsManager, player, info)
```

### Notes

* **Transform vs Visual**: uses `Transform.actual`, not visual (so spring/hover scale effects don’t alter physics).
* **Shapes**: only Rectangle & Circle bound; extend in C++ for Segment/Polygon.
* **Defaults**: dynamic body with density=1, moment=∞. Override later with `SetBodyType` etc.
* **Sync**: combine with `PhysicsSyncConfig` if you want drag/teleport/visual‑follow behaviors.

---

## Physics Manager & Navmesh (`pm.*`)

High-level utilities to **register worlds**, **step/draw them centrally**, and run **navmesh pathfinding** / **visibility (cone-of-vision)** against your colliders.

> These APIs come from your `expose_physics_manager_to_lua(...)` bindings. Signatures here match exactly.

### Register & control worlds

```lua
-- Register a PhysicsWorld under a name (optionally bind to a game-state string).
pm.add_world("world", W)               -- or: pm.add_world("world", W, "InGame")

-- Toggle stepping & debug draw per world:
pm.enable_step("world", true)
pm.enable_debug_draw("world", true)

-- Central stepping/drawing (honors state binding + toggles):
function game_update(dt)
  pm.step_all(dt)
end

function game_debug_draw()
  pm.draw_all()
end

-- Move an entity between worlds safely:
pm.move_entity_to_world(npc, "dungeon_world")
```

### Navmesh config (per world)

```lua
-- Read current nav config (table with fields).
local cfg = pm.get_nav_config("world")
-- Tweak and apply (marks navmesh dirty):
cfg.default_inflate_px = 12
pm.set_nav_config("world", cfg)

-- Force rebuild now (optional; otherwise lazy on first query):
pm.rebuild_navmesh("world")
```

**What is `default_inflate_px`?**
The clearance padding applied to obstacles when building the navmesh. Too small → paths skim walls. Too large → narrow corridors disappear. Start around **8–16** in your scale.

### Marking geometry changes

Whenever you add/remove static terrain or flip “obstacle” flags, mark the mesh dirty:

```lua
pm.mark_navmesh_dirty("world")
```

You can also tag/untag specific entities as navmesh obstacles:

```lua
-- Include/exclude an entity's collider in navmesh obstacle set:
pm.set_nav_obstacle(groundEntity, true)   -- marks dirty for its world automatically
```

### Pathfinding

```lua
-- Find a path from (sx,sy) to (dx,dy) in Chipmunk/navmesh units.
local path = pm.find_path("world", sx, sy, dx, dy)
-- path is an array of waypoints: { {x=..,y=..}, ... }

-- Example: feed waypoints into your steering path follower
if #path > 0 then
  steering.set_path(registry, agent, path, 16.0)  -- 16 = arrive radius
end
```

### Cone-of-vision / visibility polygon

```lua
-- Visibility fan points from a source within radius (against obstacles)
local fan = pm.vision_fan("world", actor.x, actor.y, 180)
-- fan is an array of {x,y} you can draw as a polygon
```

### Minimal recipe

```lua
-- 1) World & registration
local W = physics.PhysicsWorld(registry, 64.0, 0.0, 900.0)
pm.add_world("world", W)
pm.enable_step("world", true)
pm.enable_debug_draw("world", true)

-- 2) Mark terrain as nav obstacles
pm.set_nav_obstacle(terrainEntity, true)

-- 3) Configure, rebuild, and query a path
local cfg = pm.get_nav_config("world")
cfg.default_inflate_px = 10
pm.set_nav_config("world", cfg)
pm.rebuild_navmesh("world")

local pts = pm.find_path("world", 32,32, 640,256)
if #pts > 0 then steering.set_path(registry, agent, pts, 14) end

-- 4) Frame loop
function update(dt)
  pm.step_all(dt)              -- steps all active worlds
  steering.path_follow(registry, agent, 1.0, 1.0)
  steering.update(registry, agent, dt)
end

function debug_draw()
  pm.draw_all()                -- draws colliders for worlds with debug on
end
```

**Notes (no fluff):**

* Path/vision inputs cast to integers in your current binding. If truncation bites, change cast to rounding on the C++ side.
* Rebuild cost scales with obstacle count; if it’s hot, cache converted polygons or rebuild incrementally.
* Worlds bound to inactive game-states won’t step/draw via `pm.step_all/pm.draw_all`. That’s intended.

---

## Queries: Raycast & AABB

```lua
-- Raycast in Chipmunk units
local hits = physics.Raycast(W, 100, 100, 400, 260)
for i, h in ipairs(hits) do
  -- h is physics.RaycastHit: { shape=userdata, point={x,y}, normal={x,y}, fraction=number }
  print(i, h.fraction, h.point.x, h.point.y)
end

-- AABB query (returns shape userData values)
local ud = physics.GetObjectsInArea(W, 0, 0, 256, 256)
for _, u in ipairs(ud) do print("hit userData:", u) end
```

---

## Collision/Trigger events

You buffer events in `PhysicsWorld`. Pull them by tag pair **after** `Update/PostUpdate`.

```lua
function late_update()
  -- CollisionEnter between player and enemy
  local ce = W:GetCollisionEnter("player", "enemy")
  for _, ev in ipairs(ce) do
    -- ev: CollisionEvent with A/B pointers and contact data (x1,y1,x2,y2,nx,ny)
    -- Typically you recover the entity from body/shape userData in C++ helpers
  end

  -- TriggerEnter between sensor and player
  local te = W:GetTriggerEnter("sensor", "player")
  for _, obj in ipairs(te) do
    -- obj is a void* you stored (e.g., entity id). Use your retrieval helpers if needed.
  end
end
```

---

## Steering: Make an agent & update

```lua
-- Add a steerable component with caps
steering.make_steerable(registry, agent, 140.0, 2000.0, math.pi*2.0, 2.0)

-- Per-frame: compose forces & clamp
steering.update(registry, agent, dt)
```

> Steering expects a Chipmunk `cpBody*` reachable from your entity (via `ColliderComponent` or legacy `BodyComponent`).

---

## Steering behaviors

### Seek / Flee

```lua
-- Seek using vector table
steering.seek_point(registry, agent, {x=320,y=200}, 1.0, 1.0)

-- Seek using x,y
steering.seek_point(registry, agent, 480.0, 260.0, 0.8, 0.5)

-- Flee if within panic distance
steering.flee_point(registry, agent, {x=player_x, y=player_y}, 150.0, 1.0)
```

**Tips**

* `decel`: higher decel = softer arrival.
* `weight`: behavior blend weight; use smaller weights when mixing.

### Wander

```lua
-- jitter, radius, distance, weight
steering.wander(registry, agent, 20.0, 40.0, 40.0, 0.6)
```

### Boids (Separate / Align / Cohesion)

Neighbors are a **Lua array** of `entt.entity` ids.

```lua
local neighbors = { e1, e2, e3 }

steering.separate(registry, agent, 48.0, neighbors, 1.0)
steering.align(registry, agent, neighbors, 96.0, 0.5)
steering.cohesion(registry, agent, neighbors, 120.0, 0.5)
```

**Pattern:** build a neighbor list via a spatial grid/AABB query (`GetObjectsInArea`) → filter to flock tag → feed to behaviors.

### Pursuit / Evade

```lua
steering.pursuit(registry, hunter, target, 1.0)
steering.evade(registry, rabbit, hunter, 1.0)
```

### Path following

```lua
-- Set waypoints once (Chipmunk units)
steering.set_path(registry, agent, {
  {x=64,y=64}, {x=256,y=64}, {x=256,y=256}, {x=64,y=256}
}, 16.0) -- arrive radius

-- Each frame
steering.path_follow(registry, agent, 1.0, 1.0) -- decel, weight
```

### Timed forces & impulses

```lua
-- Apply a force that decays to zero over 0.35s at 60 degrees
steering.apply_force(registry, agent, 800.0, math.rad(60), 0.35)

-- Apply a constant per-frame impulse for 0.5s at -90 degrees
steering.apply_impulse(registry, agent, 1200.0, -math.pi/2, 0.5)
```

---

## Practical patterns

### 1) Spawning a player with camera & controls

```lua
-- Create world/collider
local player = create_entity()
physics.AddCollider(W, player, "player",  "circle",    14,0,0,0, false)

-- Steering caps
steering.make_steerable(registry, player, 150, 2200, math.pi*2, 2.0)

-- Per-frame input → steering
local move_target = {x=mx, y=my} -- mouse converted to Chipmunk units if needed
steering.seek_point(registry, player, move_target, 1.0, 1.0)
steering.update(registry, player, dt)
```

### 2) Simple flock

```lua
for _, b in ipairs(boids) do
  local ns = gather_neighbors(W, b, 96.0) -- your helper that returns {entities}
  steering.separate(registry, b, 48.0, ns, 1.2)
  steering.align(registry, b, ns, 96.0, 0.5)
  steering.cohesion(registry, b, ns, 120.0, 0.6)
  steering.wander(registry, b, 18.0, 35.0, 35.0, 0.3)
  steering.update(registry, b, dt)
end
```

### 3) Patrol path with chase/evade

```lua
-- Setup
steering.set_path(registry, guard, {
  {x=100,y=100},{x=300,y=100},{x=300,y=220},{x=100,y=220}
}, 18)

-- Update
if player_visible then
  steering.pursuit(registry, guard, player, 1.0)
else
  steering.path_follow(registry, guard, 1.0, 0.8)
end
steering.update(registry, guard, dt)
```

---

## Gotchas & FAQs

**Q: My raycast points don’t line up with the sprite.**
A: Convert to Chipmunk units and mind the Y‑flip when sampling from screen coordinates. Keep camera transforms out of the physics world.

**Q: Colliders aren’t interacting as expected.**
A: Ensure both tags exist (`SetCollisionTags`) and that their masks allow the pair (`EnableCollisionBetween`). If a tag’s mask list is empty, it may act as “collide with all” depending on your C++ default; set masks explicitly.

**Q: My boids don’t move.**
A: You must call `steering.update(registry, e, dt)` every frame after enqueuing behaviors.

**Q: Segment vs chain?**
A: `segment` is a single line from `(x1,y1)` to `(x2,y2)` via `(a..d)`. `chain` is a polyline using `points = { {x,y}... }`.

**Q: How do I tag shapes after creation?**
A: Use `W:UpdateColliderTag(e, newTag)`; if you changed masks globally, call `W:UpdateCollisionMasks(tag, collidesWith)` and reapply with your helpers.

**Q: Sensors never collide.**
A: Correct—set `isSensor=true` to receive trigger events without physical response.

---

## Minimal End‑to‑End Example

```lua
-- World
local W = physics.PhysicsWorld(registry, 64.0, 0.0, 900.0)
W:SetCollisionTags({"player","enemy","terrain","sensor"})
W:EnableCollisionBetween("player", {"terrain","enemy"})

-- Entities
local player = create_entity()
local enemy  = create_entity()
physics.AddCollider(W, player, "player",  "circle",    14,0,0,0, false)
physics.AddCollider(W, enemy,  "enemy",   "rectangle", 24,24,0,0, false)

-- Register world with manager and enable
pm.add_world("world", W)
pm.enable_step("world", true)
pm.enable_debug_draw("world", true)

-- Steering caps
steering.make_steerable(registry, player, 160, 2200, math.pi*2, 2.0)
steering.make_steerable(registry, enemy,  140, 2000, math.pi*2, 2.0)

function update(dt)
  -- behaviors
  steering.seek_point(registry, player, 480, 300, 1.0, 1.0)
  steering.pursuit(registry, enemy, player, 1.0)

  -- compose/apply
  steering.update(registry, player, dt)
  steering.update(registry, enemy,  dt)

  -- step via manager
  pm.step_all(dt)

  -- events
  for _, ev in ipairs(W:GetCollisionEnter("player","enemy")) do
    print("bonk!", ev.x1, ev.y1)
  end
end

function debug_draw()
  pm.draw_all()
end
```
