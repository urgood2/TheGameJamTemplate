# Physics + Steering Lua API — Quick Guide & Examples

This doc shows how to drive your Chipmunk2D physics + steering from Lua using the bindings you exposed in `expose_physics_to_lua`, `expose_steering_to_lua`, and **`expose_physics_manager_to_lua`**. It sticks to **exactly** the signatures you bound (no extras) and uses **Chipmunk units** throughout.

> **Units & Coordinates**
>
> * "Chipmunk units" here match your engine’s physics units.

---

## Table of Contents

1. [Setup: Creating a world](#setup-creating-a-world)
2. [Collision tags, masks & triggers](#collision-tags-masks--triggers)
3. [Adding colliders](#adding-colliders)
4. [Creating physics from transforms](#creating-physics-from-transforms)
5. [Physics Manager & Navmesh (`PhysicsManager.*`)](#physics-manager--navmesh-pm)
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
```

---

## Collision tags, masks & triggers

Define your allowed collisions declaratively with **tags**.

```lua
-- Define the universe of tags (order defines category ids internally)
W:SetCollisionTags({ "player", "enemy", "projectile", "terrain", "sensor" })

-- Enable/disable collision pairs (adds/removes masks)
W:EnableCollisionBetween("player", {"enemy", "terrain"})
W:DisableCollisionBetween("player", {"projectile"}) -- player bullets pass through self

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

  * **rectangle**: `a=width`, `b=height`
  * **circle**: `a=radius`
  * **segment**: `a=x1`, `b=y1`, `c=x2`, `d=y2`
  * **polygon / chain**: pass `points = { {x,y}, ... }`
* `isSensor`: sensors don’t collide but do trigger.

```lua
-- Example: player as dynamic rectangle collider
physics.AddCollider(W, player, "player", "rectangle", 32, 48, 0, 0, false)

-- Example: terrain as static chain from vertices
physics.AddCollider(W, ground, "terrain", "chain", 0,0,0,0, false, {
  {x=0,y=300}, {x=200,y=320}, {x=400,y=315}, {x=560,y=290}
})

-- Example: one-way sensor strip
physics.AddCollider(W, sensor, "sensor", "segment", 100,200, 400,200, true)
```

---

## Creating physics from transforms

`physics.create_physics_for_transform(registry, manager, entity, info)`

Helper to build a physics body + shape from an entity’s **`transform.Transform`**.

### Example

```lua
local info = { shape = "rectangle", tag = "player", sensor = false, density = 1.0 }
physics.create_physics_for_transform(registry, physicsManager, player, info)
```

---

## Physics Manager & Navmesh (`PhysicsManager.*`)

High-level utilities to **register worlds**, **step/draw centrally**, and run **navmesh pathfinding** / **visibility**. There is a global instance singleton available as `physics_manager_instance`.

### Register & control worlds

```lua
PhysicsManager.add_world("world", W)
PhysicsManager.enable_step("world", true)
PhysicsManager.enable_debug_draw("world", true)
PhysicsManager.move_entity_to_world(npc, "dungeon_world")
```

### Query worlds

```lua
local w = PhysicsManager.get_world("world")
local has = PhysicsManager.has_world("world")
local active = PhysicsManager.is_world_active("world")
```

### Step & draw all

```lua
PhysicsManager.step_all(dt)
PhysicsManager.draw_all()
```

### Navmesh config

```lua
local cfg = PhysicsManager.get_nav_config("world")
cfg.default_inflate_px = 12
PhysicsManager.set_nav_config("world", cfg)
PhysicsManager.rebuild_navmesh("world")
```

### Marking geometry changes

```lua
PhysicsManager.mark_navmesh_dirty("world")
PhysicsManager.set_nav_obstacle(groundEntity, true)
```

### Pathfinding

```lua
local path = PhysicsManager.find_path("world", sx, sy, dx, dy)
```

### Visibility polygon

```lua
local fan = PhysicsManager.vision_fan("world", actor.x, actor.y, 180)
```

---

## Queries: Raycast & AABB

```lua
local hits = physics.Raycast(W, 100, 100, 400, 260)
local ud = physics.GetObjectsInArea(W, 0, 0, 256, 256)
```

---

## Collision/Trigger events

```lua
local ce = W:GetCollisionEnter("player", "enemy")
local te = W:GetTriggerEnter("sensor", "player")
```

---

## Steering: Make an agent & update

```lua
steering.make_steerable(registry, agent, 140.0, 2000.0, math.pi*2.0, 2.0)
```

---

## Steering behaviors

### Seek / Flee

```lua
steering.seek_point(registry, agent, {x=320,y=200}, 1.0, 1.0)
steering.flee_point(registry, agent, {x=player_x, y=player_y}, 150.0, 1.0)
```

### Wander

```lua
steering.wander(registry, agent, 20.0, 40.0, 40.0, 0.6)
```

### Boids

```lua
steering.separate(registry, agent, 48.0, neighbors, 1.0)
```

### Pursuit / Evade

```lua
steering.pursuit(registry, hunter, target, 1.0)
```

### Path following

```lua
steering.set_path(registry, agent, { {x=64,y=64}, {x=256,y=64} }, 16.0)
steering.path_follow(registry, agent, 1.0, 1.0)
```

### Timed forces & impulses

```lua
steering.apply_force(registry, agent, 800.0, math.rad(60), 0.35)
```

---

## Gotchas & FAQs

* Worlds bound to inactive game-states won’t step/draw.
* Path/vision inputs are truncated to integers.
* Sensors don’t collide—only trigger.
