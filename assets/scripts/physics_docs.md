# Physics + Steering Lua API — Quick Guide & Examples (Updated)

This doc shows how to drive your Chipmunk2D physics + steering from Lua using the bindings exposed in `expose_physics_to_lua`, `expose_steering_to_lua`, and **`expose_physics_manager_to_lua`**. It sticks to **exactly** the signatures you bound (no extras) and uses **Chipmunk units** throughout.

> **Units & Coordinates**
>
> * "Chipmunk units" here match your engine’s physics units.

---

## Table of Contents

1. [Setup: Creating a world](#setup-creating-a-world)
2. [Collision tags, masks & triggers](#collision-tags-masks--triggers)
3. [Adding colliders](#adding-colliders)
4. [Multi‑shape API](#multi-shape-api)
5. [Creating physics from transforms](#creating-physics-from-transforms)
6. [Physics Sync & Rotation Policy](#physics-sync--rotation-policy)
7. [Physics Manager & Navmesh (`PhysicsManager.*`)](#physics-manager--navmesh-pm)
8. [Queries: Raycast, AABB & precise](#queries-raycast-aabb--precise)
9. [Collision/Trigger events (buffered)](#collisiontrigger-events-buffered)
10. [Arbiter scratch store (key/value)](#arbiter-scratch-store-keyvalue)
11. [Lua collision handler registration](#lua-collision-handler-registration)
12. [Body kinematics & material props](#body-kinematics--material-props)
13. [Fluids / buoyancy sensors](#fluids--buoyancy-sensors)
14. [One‑way platforms](#one-way-platforms)
15. [Sticky glue (temporary joints)](#sticky-glue-temporary-joints)
16. [Controllers: platformer / top‑down / tank](#controllers-platformer--top-down--tank)
17. [Custom gravity & orbits](#custom-gravity--orbits)
18. [Shatter & slice](#shatter--slice)
19. [Static chains / bars / bounds / tilemaps](#static-chains--bars--bounds--tilemaps)
20. [Contact metrics & neighbors](#contact-metrics--neighbors)
21. [Mouse drag helper](#mouse-drag-helper)
22. [Constraints (quick wrappers) & breakables](#constraints-quick-wrappers--breakables)
23. [Collision grouping (union‑find)](#collision-grouping-union-find)
24. [Steering: Make an agent & update](#steering-make-an-agent--update)
25. [Steering behaviors](#steering-behaviors)
26. [Practical patterns](#practical-patterns)
27. [Gotchas & FAQs](#gotchas--faqs)
28. [Annex: Per‑API Examples (Copy/Paste Ready)](#annex-perapi-examples-copypaste-ready)

---

## Setup: Creating a world

```lua
-- C++ ctor: PhysicsWorld(entt::registry*, meter, gx, gy)
local W = physics.PhysicsWorld(registry, 64.0, 0.0, 900.0)  -- 64 px = 1 unit, gravity downward
```

**Type docs**

* `physics.RaycastHit` fields:

  * `shape: lightuserdata @ cpShape*`
  * `point: {x:number,y:number}`
  * `normal: {x:number,y:number}`
  * `fraction: number` (0..1 distance fraction along the segment)

* `physics.CollisionEvent` fields:

  * `objectA, objectB: lightuserdata` (internally mapped to `entt.entity`)
  * `x1,y1` (point on A), `x2,y2` (point on B), `nx,ny` (contact normal)

* `physics.ColliderShapeType`: `Rectangle | Circle | Polygon | Chain`

* `physics.PhysicsSyncMode` enum table:

  * `AuthoritativePhysics | AuthoritativeTransform | FollowVisual | FrozenWhileDesynced`

* `physics.RotationSyncMode` enum table:

  * `TransformFixed_PhysicsFollows | PhysicsFree_TransformFollows`

---

## Collision tags, masks & triggers

```lua
-- Print table for sanity
W:PrintCollisionTags()
```

> **Bulk reapply:** After large changes, `W:UpdateCollisionMasks(tag, collidesWith)` reapplies masks to existing shapes of `tag`.

**Lua-table friendly helpers (same behavior, easier from Lua):**

```lua
-- Exact wrappers bound in C++
physics.set_collision_tags(W, {"player","enemy","terrain"})
physics.enable_collision_between_many(W, "player", {"enemy","terrain"})
physics.disable_collision_between_many(W, "player", {"projectile"})

-- Single or list (auto-dispatch on arg type)
physics.enable_collision_between(W, "player", "enemy")
physics.enable_collision_between(W, "player", {"enemy","terrain"})
physics.disable_collision_between(W, "player", "projectile")

-- Triggers (sensors)
physics.enable_trigger_between_many(W, "sensor", {"player","enemy"})
physics.disable_trigger_between_many(W, "sensor", {"enemy"})
physics.enable_trigger_between(W, "sensor", "player")
physics.disable_trigger_between(W, "sensor", {"player","enemy"})

-- Re-write one tag’s mask list and reapply filters
physics.update_collision_masks_for(W, "player", {"enemy","terrain"})
```

---

## Adding colliders

`physics.AddCollider(world, e, tag, shapeType, a, b, c, d, isSensor, points?)`

* `shapeType`: `'rectangle'|'circle'|'polygon'|'chain'`

  * **NOTE:** `'segment'` is **not** supported by `PhysicsWorld::MakeShapeFor` in this build.
* `(a,b,c,d)` meanings:

  * **rectangle**: `a=width`, `b=height`
  * **circle**: `a=radius`
  * **polygon / chain**: pass `points = { {x,y}, ... }` (overrides `a..d`)
* `isSensor`: sensors don’t collide but do trigger.

```lua
-- Dynamic rectangle collider
physics.AddCollider(W, player, "player", "rectangle", 32, 48, 0, 0, false)

-- Static chain from vertices
physics.AddCollider(W, ground, "terrain", "chain", 0,0,0,0, false, {
  {x=0,y=300}, {x=200,y=320}, {x=400,y=315}, {x=560,y=290}
})
```

**Attach helpers**

```lua
-- Store entity ids on cpShape/cpBody userData (and convert back)
physics.SetEntityToShape(shapePtr, e)
physics.SetEntityToBody(bodyPtr, e)
local e2 = physics.GetEntityFromBody(bodyPtr)
local e3 = physics.entity_from_ptr(lightuserdata_ptr)
```

---

## Multi‑shape API

```lua
-- Add an extra shape to an existing body (or create body if missing)
physics.add_shape_to_entity(W, e, "player", "circle", 16, 0,0,0, false)

-- Remove by index (0 = primary)
local removed = physics.remove_shape_at(W, e, 1)

-- Clear all shapes (primary + extras)
physics.clear_all_shapes(W, e)

-- Count & AABB per shape
local count = physics.get_shape_count(W, e)
local bb = physics.get_shape_bb(W, e, 0) -- {l,b,r,t}
```

---

## Creating physics from transforms

Two overloads:

```lua
-- (1) Uses the entity's current world
physics.create_physics_for_transform(registry, PhysicsManager, e, {
  shape = "rectangle", tag = "player", sensor = false, density = 1.0,
})

-- (2) Explicit world with extras
physics.create_physics_for_transform(registry, PhysicsManager, e, "world_name", {
  shape = "circle", tag = "enemy", sensor = false, density = 0.75,
  inflate_px = 2.0, set_world_ref = true,
})
```

`shape`: `rectangle|circle|polygon|chain` (string, case‑insensitive).

---

## Physics Sync & Rotation Policy

> Control who is authoritative (physics vs. transform), and whether rotation is locked or follows physics.

**Enums (tables):**

```lua
physics.PhysicsSyncMode       -- AuthoritativePhysics | AuthoritativeTransform | FollowVisual | FrozenWhileDesynced
physics.RotationSyncMode      -- TransformFixed_PhysicsFollows | PhysicsFree_TransformFollows
```

**Helpers (exact bindings):**

```lua
-- Immediately re-apply current rotation policy to entity e
physics.enforce_rotation_policy(registry, e)

-- Two convenience toggles for rotation policy
physics.use_transform_fixed_rotation(registry, e)      -- lock body; Transform angle is authority
physics.use_physics_free_rotation(registry, e)         -- body rotates; Transform copies body angle

-- Set/get sync mode (accepts enum int or string)
physics.set_sync_mode(registry, e, physics.PhysicsSyncMode.AuthoritativePhysics)
physics.set_sync_mode(registry, e, "FollowVisual")
local mode = physics.get_sync_mode(registry, e)        -- integer enum value

-- Set/get rotation mode (accepts enum int or string)
physics.set_rotation_mode(registry, e, physics.RotationSyncMode.TransformFixed_PhysicsFollows)
physics.set_rotation_mode(registry, e, "PhysicsFree_TransformFollows")
local rmode = physics.get_rotation_mode(registry, e)   -- integer enum value
```

---

## Physics Manager & Navmesh (PM)

Utilities to register worlds, step/draw centrally, and run navmesh/vision.

```lua
PhysicsManager.add_world("world", W)
PhysicsManager.enable_step("world", true)
PhysicsManager.enable_debug_draw("world", true)
PhysicsManager.move_entity_to_world(npc, "dungeon_world")

local w = PhysicsManager.get_world("world")
local has = PhysicsManager.has_world("world")
local active = PhysicsManager.is_world_active("world")

PhysicsManager.step_all(dt)
PhysicsManager.draw_all()

local cfg = PhysicsManager.get_nav_config("world")
cfg.default_inflate_px = 12
PhysicsManager.set_nav_config("world", cfg)
PhysicsManager.rebuild_navmesh("world")
PhysicsManager.mark_navmesh_dirty("world")
PhysicsManager.set_nav_obstacle(groundEntity, true)
```

---

## Queries: Raycast, AABB & precise

```lua
-- Segment raycast (nearest-first)
local hits = physics.Raycast(W, 100, 100, 400, 260)  -- {physics.RaycastHit}
for _,h in ipairs(hits) do
  -- h.shape (cpShape*), h.point{x,y}, h.normal{x,y}, h.fraction
end

-- AABB query to entities
local entities = physics.GetObjectsInArea(W, 0, 0, 256, 256) -- {entt.entity}
```

**Precise queries**

```lua
-- Closest segment hit with optional fat radius
local q = physics.segment_query_first(W, {x=0,y=0}, {x=300,y=0}, 4.0)
-- q = { hit=bool, shape=ptr|nil, point={x,y}|nil, normal={x,y}|nil, alpha=number }

-- Nearest shape to a point (distance < 0 => inside)
local n = physics.point_query_nearest(W, {x=mx,y=my}, 128.0)
-- n = { hit=bool, shape=ptr|nil, point={x,y}|nil, distance=number|nil }
```

---

## Collision/Trigger events (buffered)

```lua
-- Collision begins since last PostUpdate()
local ce = physics.GetCollisionEnter(W, "player", "enemy")
for _,ev in ipairs(ce) do
  -- ev = { a=entt.entity, b=entt.entity, x1,y1,x2,y2,nx,ny }
end

-- Trigger begins since last PostUpdate()
local te = physics.GetTriggerEnter(W, "sensor", "player") -- {entt.entity}
```

**Lifecycle reminder**

Call `W:Update(dt)` each frame. After consuming event buffers, call `W:PostUpdate()`.

---

## Arbiter scratch store (key/value)

Attach transient data to a Chipmunk arbiter during contact.

```lua
-- number
physics.arb_set_number(W, arbPtr, "damage", 12.5)
local dmg = physics.arb_get_number(W, arbPtr, "damage", 0.0)

-- boolean
physics.arb_set_bool(W, arbPtr, "one_way_reject", true)
local reject = physics.arb_get_bool(W, arbPtr, "one_way_reject", false)

-- pointer (lightuserdata)
physics.arb_set_ptr(W, arbPtr, "owner", some_ptr)
local ptr = physics.arb_get_ptr(W, arbPtr)
```

---

## Lua collision handler registration

Register Lua callbacks for **pair** or **wildcard** tags.

```lua
-- PreSolve: return false to reject contact; nil/true to accept
physics.on_pair_presolve(W, "player", "enemy", function(arb) return true end)
physics.on_pair_postsolve(W, "player", "enemy", function(arb) end)

physics.on_wildcard_presolve(W, "projectile", function(arb) end)
physics.on_wildcard_postsolve(W, "projectile", function(arb) end)

-- Clear handlers
physics.clear_pair_handlers(W, "player", "enemy")
physics.clear_wildcard_handlers(W, "projectile")
```

---

## Body kinematics & material props

```lua
-- Velocities & forces
physics.SetVelocity(W, e, vx, vy)
physics.SetAngularVelocity(W, e, av)           -- radians/sec
physics.ApplyForce(W, e, fx, fy)
physics.ApplyImpulse(W, e, ix, iy)
physics.ApplyTorque(W, e, torque)

-- Damping
physics.SetDamping(W, e, linear)               -- scale velocity by (1-linear)
physics.SetGlobalDamping(W, 0.02)

-- Pose
local p = physics.GetPosition(W, e)            -- {x,y}
physics.SetPosition(W, e, x, y)
local a = physics.GetAngle(W, e)               -- radians
physics.SetAngle(W, e, radians)

-- Material across ALL shapes on entity
physics.SetRestitution(W, e, restitution)
physics.SetFriction(W, e, friction)

-- Body flags
physics.SetAwake(W, e, true)
local m = physics.GetMass(W, e)
physics.SetMass(W, e, new_mass)
physics.SetBullet(W, e, true)
physics.SetFixedRotation(W, e, true)
physics.SetBodyType(W, e, "dynamic")          -- 'static'|'kinematic'|'dynamic'
```

---

## Fluids / buoyancy sensors

```lua
physics.register_fluid_volume(W, "water", 1.0, 2.0)      -- density, drag
physics.add_fluid_sensor_aabb(W, 0, 0, 640, 160, "water")
```

---

## One‑way platforms

```lua
-- Normal defaults to {0,1} (up). Entities pass from backside.
local plat = physics.add_one_way_platform(W, 100, 200, 400, 200, 6.0, "one_way", {x=0,y=1})
```

---

## Sticky glue (temporary joints)

```lua
physics.enable_sticky_between(W, "slime", "terrain", 200.0, 5000.0)
physics.disable_sticky_between(W, "slime", "terrain")
```

---

## Controllers: platformer / top‑down / tank

```lua
-- Platformer (kinematic-friendly)
local player = physics.create_platformer_player(W, {x=64,y=64}, 24, 40, "player")
physics.set_platformer_input(W, player, move_x, jump_held) -- move_x in [-1..1]

-- Top‑down controller (pivot constraint)
physics.create_topdown_controller(W, e, max_bias, max_force)

-- Tank controller (enable + command + update)
physics.enable_tank_controller(W, e, 30.0, 30.0, 10000.0, 50000.0, 1.2)
physics.command_tank_to(W, e, {x=tx, y=ty})
physics.update_tanks(W, dt)
```

---

## Custom gravity & orbits

```lua
physics.enable_inverse_square_gravity_to_point(W, e, {x=0,y=0}, 20000.0)
physics.enable_inverse_square_gravity_to_body(W, satellite, planet, 40000.0)
physics.disable_custom_gravity(W, e)

local planet = physics.create_planet(W, 64.0, math.rad(15), "planet", {x=0,y=0})
local orbiter = physics.spawn_orbiting_box(W, {x=120,y=0}, 8.0, 2.0, 40000.0, {x=0,y=0})
```

---

## Shatter & slice

```lua
local ok = physics.shatter_nearest(W, mx, my, 5) -- Voronoi shatter nearest polygon
local sliced = physics.slice_first_hit(W, {x=0,y=0}, {x=200,y=0}, 1.0, 50.0)
```

---

## Static chains / bars / bounds / tilemaps

```lua
local chain = physics.add_smooth_segment_chain(W, {
  {x=0,y=320}, {x=200,y=340}, {x=400,y=330}
}, 4.0, "terrain")

local bar = physics.add_bar_segment(W, {x=0,y=0}, {x=80,y=0}, 3.0, "terrain", 1)

physics.add_screen_bounds(W, 0,0, 1280,720, 8.0, "world")

-- Tilemap colliders from boolean grid grid[x][y]
physics.create_tilemap_colliders(W, grid, 32.0, 3.0)
```

---

## Contact metrics & neighbors

```lua
local touching = physics.touching_entities(W, e)      -- {entt.entity}
local totalF = physics.total_force_on(W, e, dt)
local weight = physics.weight_on(W, e, dt)
local crush = physics.crush_on(W, e, dt)              -- {touching_count, crush}
```

---

## Mouse drag helper

```lua
physics.start_mouse_drag(W, mx, my)
physics.update_mouse_drag(W, mx, my)
physics.end_mouse_drag(W)
```

---

## Constraints (quick wrappers) & breakables

```lua
-- Add constraints
local c1 = physics.add_pin_joint(W, ea, {x=0,y=0}, eb, {x=0,y=0})
local c2 = physics.add_slide_joint(W, ea, {x=0,y=0}, eb, {x=32,y=0}, 8.0, 64.0)
local c3 = physics.add_pivot_joint_world(W, ea, eb, {x=100,y=100})
local c4 = physics.add_damped_spring(W, ea, {x=0,y=0}, eb, {x=16,y=0}, 24.0, 200.0, 6.0)
local c5 = physics.add_damped_rotary_spring(W, ea, eb, 0.0, 15000.0, 80.0)

-- Limits
physics.set_constraint_limits(W, c2, 50000.0, 0.0)   -- pass nil to keep a value

-- Upright helper
physics.add_upright_spring(W, e, 4000.0, 120.0)

-- Breakable
local bc = physics.make_breakable_slide_joint(W, ea, eb, {x=0,y=0}, {x=32,y=0}, 8, 64,
                                              12000.0, 0.6, true, true, 0.05)
physics.make_constraint_breakable(W, c3, 15000.0, 0.5, false, 0.0)
```

---

## Collision grouping (union‑find)

```lua
-- Group bodies that collide among same‑type contacts; when size >= threshold,
-- a C++ callback you defined will run.
physics.enable_collision_grouping(W, 1000, 2000, 6) -- min_type, max_type, threshold
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

## Practical patterns

* Call `W:Update(dt)` every frame; consume event buffers; then call `W:PostUpdate()`.
* Tag/world setup up-front; mutate masks sparingly mid‑frame (prefer staging + `PostUpdate`).
* Use the multi‑shape API to compose complex colliders (primary + extras) per entity.
* Store temporary per‑contact data with `arb_*` getters/setters inside your Pre/PostSolve.

---

## Gotchas & FAQs

* **No segment shape in `AddCollider`:** Use `add_smooth_segment_chain` or `add_bar_segment` instead.
* **Sensors** don’t collide—only trigger.
* Worlds bound to inactive game-states won’t step/draw.
* Path/vision inputs may be truncated to integers by your PM utilities.
* `entt.entity` values are returned directly where documented; when you receive a `lightuserdata` that encodes an entity id, convert with `physics.entity_from_ptr(ptr)`.

---

## Annex: Per‑API Examples (Copy/Paste Ready)

> Minimal snippets that exercise each new API. Assumes you have `registry`, `PhysicsManager`, and a world `W` already created.

### Multi‑shape composition

```lua
-- Primary rectangle
physics.AddCollider(W, e, "player", "rectangle", 32, 48, 0, 0, false)
-- Add a circular bumper as an extra shape
physics.add_shape_to_entity(W, e, "player", "circle", 14, 0, 0, 0, false)
print("shapes:", physics.get_shape_count(W, e))
local bb0 = physics.get_shape_bb(W, e, 0)
local bb1 = physics.get_shape_bb(W, e, 1)
-- Remove the extra
physics.remove_shape_at(W, e, 1)
```

### Precise queries

```lua
local s = physics.segment_query_first(W, {x=0,y=0}, {x=300,y=0}, 6.0)
if s.hit then
  print("alpha:", s.alpha, "hit shape:", s.shape)
end
local n = physics.point_query_nearest(W, {x=mx,y=my}, 128.0)
if n.hit then
  print("nearest distance:", n.distance)
end
```

### Arbiter scratch store inside PreSolve/PostSolve

```lua
-- Reject collisions if we previously marked this arbiter as one-way reject
physics.on_wildcard_presolve(W, "one_way", function(arb)
  if physics.arb_get_bool(W, arb, "reject", false) then return false end
  -- Example: set a damage value to read in PostSolve
  physics.arb_set_number(W, arb, "damage", 10.0)
  return true
end)

physics.on_wildcard_postsolve(W, "one_way", function(arb)
  local dmg = physics.arb_get_number(W, arb, "damage", 0.0)
  if dmg > 0 then print("applied dmg:", dmg) end
end)
```

### Pair & wildcard handler registration (and clearing)

```lua
local function pair_pre(arb)
  -- e.g., turn on sticky if a key is held, else accept
  return true
end
local function pair_post(arb)
  -- collect analytics or spawn particles using arbiter impulses
end
physics.on_pair_presolve(W, "player", "enemy", pair_pre)
physics.on_pair_postsolve(W, "player", "enemy", pair_post)
physics.on_wildcard_postsolve(W, "projectile", function(arb) end)
-- Later, clear:
physics.clear_pair_handlers(W, "player", "enemy")
physics.clear_wildcard_handlers(W, "projectile")
```

### Fluids

```lua
physics.register_fluid_volume(W, "water", 1.0, 2.5)
physics.add_fluid_sensor_aabb(W, 0, 0, 640, 160, "water")
```

### One‑way platforms

```lua
local normal_up = {x=0,y=1}
local plat = physics.add_one_way_platform(W, 100, 200, 400, 200, 6.0, "one_way", normal_up)
-- In presolve, you can conditionally reject contact by using arb store (see above)
```

### Sticky glue

```lua
physics.enable_sticky_between(W, "slime", "terrain", 250.0, 6000.0)
-- Disable later:
physics.disable_sticky_between(W, "slime", "terrain")
```

### Controllers

```lua
-- Platformer
local player = physics.create_platformer_player(W, {x=64,y=64}, 24, 40, "player")
function update(dt)
  local input_x = (right and 1 or 0) + (left and -1 or 0)
  physics.set_platformer_input(W, player, input_x, jump_held)
  W:Update(dt); W:PostUpdate()
end

-- Top‑down attach (constraint-based)
physics.create_topdown_controller(W, e, 1.0, 3000.0)

-- Tank
physics.enable_tank_controller(W, tank, 30.0, 30.0, 10000.0, 50000.0, 1.2)
physics.command_tank_to(W, tank, {x=tx,y=ty})
physics.update_tanks(W, dt)
```

### Custom gravity & orbits

```lua
local planet = physics.create_planet(W, 64.0, math.rad(10), "planet", {x=0,y=0})
local orbiter = physics.spawn_orbiting_box(W, {x=120,y=0}, 8.0, 2.0, 30000.0, {x=0,y=0})
physics.enable_inverse_square_gravity_to_body(W, orbiter, planet, 30000.0)
```

### Shatter & slice

```lua
if physics.shatter_nearest(W, mx, my, 6) then
  print("shattered")
end
local sliced = physics.slice_first_hit(W, {x=0,y=0}, {x=200,y=0}, 1.0, 50.0)
```

### Static chains / bars / bounds / tilemaps

```lua
local chain = physics.add_smooth_segment_chain(W, {
  {x=0,y=320}, {x=200,y=340}, {x=400,y=330}
}, 4.0, "terrain")
local bar = physics.add_bar_segment(W, {x=0,y=0}, {x=80,y=0}, 3.0, "terrain", 1)
physics.add_screen_bounds(W, 0,0, 1280,720, 8.0, "world")

-- Tilemap from boolean grid grid[x][y]
local grid = {
  [0] = {[0]=true,[1]=true},
  [1] = {[0]=true,[1]=false},
}
physics.create_tilemap_colliders(W, grid, 32.0, 3.0)
```

### Contact metrics & neighbors

```lua
local touching = physics.touching_entities(W, e)
for _,ee in ipairs(touching) do print("touch:", ee) end
print("F:", physics.total_force_on(W, e, dt))
print("weight:", physics.weight_on(W, e, dt))
local c = physics.crush_on(W, e, dt); print("crush:", c.crush)
```

### Mouse drag helper

```lua
physics.start_mouse_drag(W, mx, my)
physics.update_mouse_drag(W, mx, my)
physics.end_mouse_drag(W)
```

### Constraints & breakables

```lua
local c2 = physics.add_slide_joint(W, ea, {x=0,y=0}, eb, {x=32,y=0}, 8.0, 64.0)
physics.set_constraint_limits(W, c2, 40000.0, nil)  -- keep maxBias
local bc = physics.make_breakable_slide_joint(W, ea, eb, {x=0,y=0}, {x=32,y=0}, 8, 64,
  12000.0, 0.6, true, true, 0.05)
physics.make_constraint_breakable(W, c2, 15000.0, 0.5, false, 0.0)
```

### Collision grouping (union‑find)

```lua
-- Group shapes with types in [1000,2000]; when group size >= 6, your C++ callback runs
physics.enable_collision_grouping(W, 1000, 2000, 6)
```
