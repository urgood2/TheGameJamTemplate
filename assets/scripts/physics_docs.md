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

* [Arbiter object (cpArbiter wrapper)](#arbiter-object-cparbiter-wrapper)

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
local world = physics.PhysicsWorld(registry, 64.0, 0.0, 900.0)  -- 64 px = 1 unit, gravity downward
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

* `physics.Arbiter` (wrapper over `cpArbiter*`) — see [Arbiter object](#arbiter-object-cparbiter-wrapper).

---

## Collision tags, masks & triggers

```lua
-- Print table for sanity
world:PrintCollisionTags()
```

> **Bulk reapply:** After large changes, `world:UpdateCollisionMasks(tag, collidesWith)` reapplies masks to existing shapes of `tag`.

**Lua-table friendly helpers (same behavior, easier from Lua):**

```lua
-- Exact wrappers bound in C++
physics.set_collision_tags(world, {"player","enemy","terrain"})
physics.enable_collision_between_many(world, "player", {"enemy","terrain"})
physics.disable_collision_between_many(world, "player", {"projectile"})

-- Single or list (auto-dispatch on arg type)
physics.enable_collision_between(world, "player", "enemy")
physics.enable_collision_between(world, "player", {"enemy","terrain"})
physics.disable_collision_between(world, "player", "projectile")

-- Triggers (sensors)
physics.enable_trigger_between_many(world, "sensor", {"player","enemy"})
physics.disable_trigger_between_many(world, "sensor", {"enemy"})
physics.enable_trigger_between(world, "sensor", "player")
physics.disable_trigger_between(world, "sensor", {"player","enemy"})

-- Re-write one tag’s mask list and reapply filters
physics.update_collision_masks_for(world, "player", {"enemy","terrain"})
```

---

## Adding colliders

These need to be called **after** you create physics for an entity (e.g., `create_physics_for_transform`).

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
physics.AddCollider(world, player, "player", "rectangle", 32, 48, 0, 0, false)

-- Static chain from vertices
physics.AddCollider(world, ground, "terrain", "chain", 0,0,0,0, false, {
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
physics.add_shape_to_entity(world, e, "player", "circle", 16, 0,0,0, false)

-- Remove by index (0 = primary)
local removed = physics.remove_shape_at(world, e, 1)

-- Clear all shapes (primary + extras)
physics.clear_all_shapes(world, e)

-- Count & AABB per shape
local count = physics.get_shape_count(world, e)
local bb = physics.get_shape_bb(world, e, 0) -- {l,b,r,t}
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
PhysicsManager.add_world("world", world)
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
local hits = physics.Raycast(world, 100, 100, 400, 260)  -- {physics.RaycastHit}
for _,h in ipairs(hits) do
  -- h.shape (cpShape*), h.point{x,y}, h.normal{x,y}, h.fraction
end

-- AABB query to entities
local entities = physics.GetObjectsInArea(world, 0, 0, 256, 256) -- {entt.entity}
```

**Precise queries**

```lua
-- Closest segment hit with optional fat radius (hitscan)
local q = physics.segment_query_first(world, {x=0,y=0}, {x=300,y=0}, 4.0)
-- q = { hit=bool, shape=ptr|nil, point={x,y}|nil, normal={x,y}|nil, alpha=number }

-- Nearest shape to a point with max distance (distance < 0 => inside)
local n = physics.point_query_nearest(world, {x=mx,y=my}, 128.0)
-- n = { hit=bool, shape=ptr|nil, point={x,y}|nil, distance=number|nil }
```

---

## Collision/Trigger events (buffered)

```lua
-- Collision begins since last PostUpdate()
local ce = physics.GetCollisionEnter(world, "player", "enemy")
for _,ev in ipairs(ce) do
  -- ev = { a=entt.entity, b=entt.entity, x1,y1,x2,y2,nx,ny }
end

-- Trigger begins since last PostUpdate()
local te = physics.GetTriggerEnter(world, "sensor", "player") -- {entt.entity}
```

**Lifecycle reminder**

Call `world:Update(dt)` each frame. After consuming event buffers, call `world:PostUpdate()`.

---

## Arbiter scratch store (key/value)

Attach transient data to a Chipmunk arbiter during contact.

```lua
-- number
physics.arb_set_number(world, arbPtr, "damage", 12.5)
local dmg = physics.arb_get_number(world, arbPtr, "damage", 0.0)

-- boolean
physics.arb_set_bool(world, arbPtr, "one_way_reject", true)
local reject = physics.arb_get_bool(world, arbPtr, "one_way_reject", false)

-- pointer (lightuserdata)
physics.arb_set_ptr(world, arbPtr, "owner", some_ptr)
local ptr = physics.arb_get_ptr(world, arbPtr)
```

---

## Arbiter object (cpArbiter wrapper)

**Type:** `physics.Arbiter` — a thin wrapper over `cpArbiter*` passed to all collision callbacks.

**Fields / methods** (exactly as bound):

* `ptr: lightuserdata` — raw arbiter pointer.
* `entities(): { entityA, entityB }` — the two `entt.entity` ids participating in the contact.
* `tags(world): { tagA, tagB }` — resolves the two collision tags using the given `PhysicsWorld`.
* `normal: {x, y}` — contact normal from A→B.
* `total_impulse: {x, y}` — total impulse applied this step.
* `total_impulse_length(): number` — magnitude of the above.
* `is_first_contact(): boolean` — true only on the first step the shapes touch.
* `is_removal(): boolean` — true when contact is being removed.
* **PreSolve‑only mutators:**

  * `set_friction(f: number)`
  * `set_elasticity(e: number)`
  * `set_surface_velocity(vx: number, vy: number)`
  * `ignore()` — skip this contact pair for the rest of the step.

**Usage examples**

```lua
physics.on_wildcard_presolve(world, "player", function(arb)
  -- Gate expensive setup to the first contact frame only
  if arb:is_first_contact() then
    local a, b = arb:entities()
    -- e.g., start a sound or spawn a decal tagged to A/B
  end

  -- One‑way platform example (flip normal test not shown)
  if physics.arb_get_bool(world, arb, "reject", false) then
    return false -- reject this contact
  end

  -- Tune contact properties dynamically
  arb:set_friction(0.9)
  arb:set_elasticity(0.1)
  arb:set_surface_velocity(0.0, 0.0)
  return true
end)

physics.on_pair_postsolve(world, "projectile", "enemy", function(arb)
  local n = arb.normal            -- {x,y}
  local J = arb:total_impulse_length()
  if J > 500.0 then
    local ta, tb = arb:tags(world)
    print("HARD HIT:", ta, "→", tb, "impulse=", J)
  end
end)
```

> **Rules of thumb**
>
> * Only call mutators in **PreSolve**. Chipmunk ignores these in PostSolve.
> * Use `is_first_contact()` to do one‑shot setup; `is_removal()` for teardown.
> * Prefer `arbiter scratch store` (above) for passing flags between Pre/Post.

# Arbiter Caveats & Usage Notes

This section documents important caveats when working with the **`physics.Arbiter`** type in Lua. These details should be understood to avoid runtime errors and misuse.

---

## Lifetime & Scope

* **Valid only inside collision callbacks**: The `Arbiter` wraps a raw `cpArbiter*` from Chipmunk2D. This pointer is only guaranteed valid *during* the callback (`begin`, `preSolve`, `postSolve`, `separate`).
* **Do not store or cache** the Arbiter object for later use. Once the callback returns, the pointer is no longer safe.

---

## Property Access

* Properties defined via `sol::property` are **fields** in Lua, not methods.

  ```lua
  local n = arb.normal              -- table {x, y}
  local imp = arb.total_impulse     -- table {x, y}
  local len = arb.total_impulse_length -- number
  ```
* **Do not call them like functions** (`arb.normal()` ❌). Always access as fields.
* Methods like `entities()`, `tags(world)`, `is_first_contact()`, etc. still use **colon syntax**:

  ```lua
  local e1, e2 = arb:entities()
  local t1, t2 = arb:tags(world)
  if arb:is_first_contact() then ... end
  ```

---

## PreSolve Mutators

* The following functions are only valid inside a **`preSolve`** callback:

  * `set_friction(f)`
  * `set_elasticity(e)`
  * `set_surface_velocity(vx, vy)`
  * `ignore()`
* Using them in `begin`, `postSolve`, or `separate` callbacks is undefined and may crash.

---

## Common Pitfalls

1. **Wrong parameter order in properties**: Ensure bound C++ functions have `(LuaArbiter&, sol::this_state)` order, not reversed. Otherwise you’ll see errors like *"expected userdata, got no value"*.
2. **Colon vs dot confusion**: Use `:` for methods, `.` for properties.
3. **Tags require world reference**: `arb:tags(world)` must be passed the `PhysicsWorld` object. Without it, tag resolution fails.
4. **Do not reuse outside callbacks**: Trying to access `arb.total_impulse` later will throw.

---

## Example Usage

```lua
physics.on_wildcard_presolve(world, "player", function(arb)
    if arb:is_first_contact() then
        print("First contact normal:", arb.normal.x, arb.normal.y)
    end

    local e1, e2 = arb:entities()
    local t1, t2 = arb:tags(world)
    print("Collision between", t1, "and", t2)

    arb:set_friction(0.8)
    arb:set_elasticity(0.2)
end)
```

---

## Lua collision handler registration

Register Lua callbacks for **pair** or **wildcard** tags.

```lua
-- PreSolve: return false to reject contact; nil/true to accept
physics.on_pair_presolve(world, "player", "enemy", function(arb) return true end)
physics.on_pair_postsolve(world, "player", "enemy", function(arb) end)

physics.on_wildcard_presolve(world, "projectile", function(arb) end)
physics.on_wildcard_postsolve(world, "projectile", function(arb) end)

-- Clear handlers
physics.clear_pair_handlers(world, "player", "enemy")
physics.clear_wildcard_handlers(world, "projectile")
```

---

## Body kinematics & material props

```lua
-- Velocities & forces
physics.SetVelocity(world, e, vx, vy)
physics.SetAngularVelocity(world, e, av)           -- radians/sec
physics.ApplyForce(world, e, fx, fy)
physics.ApplyImpulse(world, e, ix, iy)
physics.ApplyTorque(world, e, torque)

-- Damping
physics.SetDamping(world, e, linear)               -- scale velocity by (1-linear)
physics.SetGlobalDamping(world, 0.02)

-- Pose
local p = physics.GetPosition(world, e)            -- {x,y}
physics.SetPosition(world, e, x, y)
local a = physics.GetAngle(world, e)               -- radians
physics.SetAngle(world, e, radians)

-- Material across ALL shapes on entity
physics.SetRestitution(world, e, restitution)
physics.SetFriction(world, e, friction)

-- Body flags
physics.SetAwake(world, e, true)
local m = physics.GetMass(world, e)
physics.SetMass(world, e, new_mass)
physics.SetBullet(world, e, true)
physics.SetFixedRotation(world, e, true)
physics.SetBodyType(world, e, "dynamic")          -- 'static'|'kinematic'|'dynamic'
```

---

## Fluids / buoyancy sensors

```lua
physics.register_fluid_volume(world, "water", 1.0, 2.0)      -- density, drag
physics.add_fluid_sensor_aabb(world, 0, 0, 640, 160, "water")
```

---

## One‑way platforms

```lua
-- Normal defaults to {0,1} (up). Entities pass from backside.
local plat = physics.add_one_way_platform(world, 100, 200, 400, 200, 6.0, "one_way", {x=0,y=1})
```

---

## Sticky glue (temporary joints)

```lua
physics.enable_sticky_between(world, "slime", "terrain", 200.0, 5000.0)
physics.disable_sticky_between(world, "slime", "terrain")
```

---

## Controllers: platformer / top‑down / tank

```lua
-- Platformer (kinematic-friendly)
local player = physics.create_platformer_player(world, {x=64,y=64}, 24, 40, "player")
physics.set_platformer_input(world, player, move_x, jump_held) -- move_x in [-1..1]

-- Top‑down controller (pivot constraint)
physics.create_topdown_controller(world, e, max_bias, max_force)

-- Tank controller (enable + command + update)
physics.enable_tank_controller(world, e, 30.0, 30.0, 10000.0, 50000.0, 1.2)
physics.command_tank_to(world, e, {x=tx, y=ty})
physics.update_tanks(world, dt)
```

---

## Custom gravity & orbits

```lua
physics.enable_inverse_square_gravity_to_point(world, e, {x=0,y=0}, 20000.0)
physics.enable_inverse_square_gravity_to_body(world, satellite, planet, 40000.0)
physics.disable_custom_gravity(world, e)

local planet = physics.create_planet(world, 64.0, math.rad(15), "planet", {x=0,y=0})
local orbiter = physics.spawn_orbiting_box(world, {x=120,y=0}, 8.0, 2.0, 40000.0, {x=0,y=0})
```

---

## Shatter & slice

```lua
local ok = physics.shatter_nearest(world, mx, my, 5) -- Voronoi shatter nearest polygon
local sliced = physics.slice_first_hit(world, {x=0,y=0}, {x=200,y=0}, 1.0, 50.0)
```

---

## Static chains / bars / bounds / tilemaps

```lua
local chain = physics.add_smooth_segment_chain(world, {
  {x=0,y=320}, {x=200,y=340}, {x=400,y=330}
}, 4.0, "terrain")

local bar = physics.add_bar_segment(world, {x=0,y=0}, {x=80,y=0}, 3.0, "terrain", 1)

physics.add_screen_bounds(world, 0,0, 1280,720, 8.0, "world")

-- Tilemap colliders from boolean grid grid[x][y]
physics.create_tilemap_colliders(world, grid, 32.0, 3.0)
```

---

## Contact metrics & neighbors

```lua
local touching = physics.touching_entities(world, e)      -- {entt.entity}
local totalF = physics.total_force_on(world, e, dt)
local weight = physics.weight_on(world, e, dt)
local crush = physics.crush_on(world, e, dt)              -- {touching_count, crush}
```

---

## Mouse drag helper

```lua
physics.start_mouse_drag(world, mx, my)
physics.update_mouse_drag(world, mx, my)
physics.end_mouse_drag(world)
```

---

## Constraints (quick wrappers) & breakables

```lua
-- Add constraints
local c1 = physics.add_pin_joint(world, ea, {x=0,y=0}, eb, {x=0,y=0})
local c2 = physics.add_slide_joint(world, ea, {x=0,y=0}, eb, {x=32,y=0}, 8.0, 64.0)
local c3 = physics.add_pivot_joint_world(world, ea, eb, {x=100,y=100})
local c4 = physics.add_damped_spring(world, ea, {x=0,y=0}, eb, {x=16,y=0}, 24.0, 200.0, 6.0)
local c5 = physics.add_damped_rotary_spring(world, ea, eb, 0.0, 15000.0, 80.0)

-- Limits
physics.set_constraint_limits(world, c2, 50000.0, 0.0)   -- pass nil to keep a value

-- Upright helper
physics.add_upright_spring(world, e, 4000.0, 120.0)

-- Breakable
local bc = physics.make_breakable_slide_joint(world, ea, eb, {x=0,y=0}, {x=32,y=0}, 8, 64,
                                              12000.0, 0.6, true, true, 0.05)
physics.make_constraint_breakable(world, c3, 15000.0, 0.5, false, 0.0)
```

---

## Collision grouping (union‑find)

```lua
-- Group bodies that collide among same‑type contacts; when size >= threshold,
-- a C++ callback you defined will run.
physics.enable_collision_grouping(world, 1000, 2000, 6) -- min_type, max_type, threshold
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

* Call `world:Update(dt)` every frame; consume event buffers; then call `world:PostUpdate()`.
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

> Minimal snippets that exercise each new API. Assumes you have `registry`, `PhysicsManager`, and a world `world` already created.

### Multi‑shape composition

```lua
-- Primary rectangle
physics.AddCollider(world, e, "player", "rectangle", 32, 48, 0, 0, false)
-- Add a circular bumper as an extra shape
physics.add_shape_to_entity(world, e, "player", "circle", 14, 0, 0, 0, false)
print("shapes:", physics.get_shape_count(world, e))
local bb0 = physics.get_shape_bb(world, e, 0)
local bb1 = physics.get_shape_bb(world, e, 1)
-- Remove the extra
physics.remove_shape_at(world, e, 1)
```

### Precise queries

```lua
local s = physics.segment_query_first(world, {x=0,y=0}, {x=300,y=0}, 6.0)
if s.hit then
  print("alpha:", s.alpha, "hit shape:", s.shape)
end
local n = physics.point_query_nearest(world, {x=mx,y=my}, 128.0)
if n.hit then
  print("nearest distance:", n.distance)
end
```

### Arbiter scratch store inside PreSolve/PostSolve

```lua
-- Reject collisions if we previously marked this arbiter as one-way reject
physics.on_wildcard_presolve(world, "one_way", function(arb)
  if physics.arb_get_bool(world, arb, "reject", false) then return false end
  -- Example: set a damage value to read in PostSolve
  physics.arb_set_number(world, arb, "damage", 10.0)
  return true
end)

physics.on_wildcard_postsolve(world, "one_way", function(arb)
  local dmg = physics.arb_get_number(world, arb, "damage", 0.0)
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
physics.on_pair_presolve(world, "player", "enemy", pair_pre)
physics.on_pair_postsolve(world, "player", "enemy", pair_post)
physics.on_wildcard_postsolve(world, "projectile", function(arb) end)
-- Later, clear:
physics.clear_pair_handlers(world, "player", "enemy")
physics.clear_wildcard_handlers(world, "projectile")
```

### Fluids

```lua
physics.register_fluid_volume(world, "water", 1.0, 2.5)
physics.add_fluid_sensor_aabb(world, 0, 0, 640, 160, "water")
```

### One‑way platforms

```lua
local normal_up = {x=0,y=1}
local plat = physics.add_one_way_platform(world, 100, 200, 400, 200, 6.0, "one_way", normal_up)
-- In presolve, you can conditionally reject contact by using arb store (see above)
```

### Sticky glue

```lua
physics.enable_sticky_between(world, "slime", "terrain", 250.0, 6000.0)
-- Disable later:
physics.disable_sticky_between(world, "slime", "terrain")
```

### Controllers

```lua
-- Platformer
local player = physics.create_platformer_player(world, {x=64,y=64}, 24, 40, "player")
function update(dt)
  local input_x = (right and 1 or 0) + (left and -1 or 0)
  physics.set_platformer_input(world, player, input_x, jump_held)
  world:Update(dt); world:PostUpdate()
end

-- Top‑down attach (constraint-based)
physics.create_topdown_controller(world, e, 1.0, 3000.0)

-- Tank
physics.enable_tank_controller(world, tank, 30.0, 30.0, 10000.0, 50000.0, 1.2)
physics.command_tank_to(world, tank, {x=tx,y=ty})
physics.update_tanks(world, dt)
```

### Custom gravity & orbits

```lua
local planet = physics.create_planet(world, 64.0, math.rad(10), "planet", {x=0,y=0})
local orbiter = physics.spawn_orbiting_box(world, {x=120,y=0}, 8.0, 2.0, 30000.0, {x=0,y=0})
physics.enable_inverse_square_gravity_to_body(world, orbiter, planet, 30000.0)
```

### Shatter & slice

```lua
if physics.shatter_nearest(world, mx, my, 6) then
  print("shattered")
end
local sliced = physics.slice_first_hit(world, {x=0,y=0}, {x=200,y=0}, 1.0, 50.0)
```

### Static chains / bars / bounds / tilemaps

```lua
local chain = physics.add_smooth_segment_chain(world, {
  {x=0,y=320}, {x=200,y=340}, {x=400,y=330}
}, 4.0, "terrain")
local bar = physics.add_bar_segment(world, {x=0,y=0}, {x=80,y=0}, 3.0, "terrain", 1)
physics.add_screen_bounds(world, 0,0, 1280,720, 8.0, "world")

-- Tilemap from boolean grid grid[x][y]
local grid = {
  [0] = {[0]=true,[1]=true},
  [1] = {[0]=true,[1]=false},
}
physics.create_tilemap_colliders(world, grid, 32.0, 3.0)
```

### Contact metrics & neighbors

```lua
local touching = physics.touching_entities(world, e)
for _,ee in ipairs(touching) do print("touch:", ee) end
print("F:", physics.total_force_on(world, e, dt))
print("weight:", physics.weight_on(world, e, dt))
local c = physics.crush_on(world, e, dt); print("crush:", c.crush)
```

### Mouse drag helper

```lua
physics.start_mouse_drag(world, mx, my)
physics.update_mouse_drag(world, mx, my)
physics.end_mouse_drag(world)
```

### Constraints & breakables

```lua
local c2 = physics.add_slide_joint(world, ea, {x=0,y=0}, eb, {x=32,y=0}, 8.0, 64.0)
physics.set_constraint_limits(world, c2, 40000.0, nil)  -- keep maxBias
local bc = physics.make_breakable_slide_joint(world, ea, eb, {x=0,y=0}, {x=32,y=0}, 8, 64,
  12000.0, 0.6, true, true, 0.05)
physics.make_constraint_breakable(world, c2, 15000.0, 0.5, false, 0.0)
```

### Collision grouping (union‑find)

```lua
-- Group shapes with types in [1000,2000]; when group size >= 6, your C++ callback runs
physics.enable_collision_grouping(world, 1000, 2000, 6)
```
