# Steering System Usage Guide

This document explains how to **set up and use the unified Steering System** (EnTT + Chipmunk2D + Raylib), including common behavior recipes, flocking, path following, and timed force/impulse examples.

---

## 1. Setup

```cpp
entt::registry registry;

// Create PhysicsWorld
auto world = physics::InitPhysicsWorld(&registry, 64.0f, 0.0f, 0.0f);

// Create an agent
entt::entity agent = registry.create();
auto body = physics::MakeSharedBody(1.0f, 1.0f);
auto shape = physics::MakeSharedShape(body.get(), 32, 32, "Agent");
registry.emplace<physics::ColliderComponent>(agent, body, shape, "Agent");

// Make steerable
Steering::MakeSteerable(registry, agent, 140.0f, 1800.0f);

// Position
cpBodySetPosition(body.get(), cpv(100, 100));
```

---

## 2. Game Loop Order

```cpp
float dt = GetFrameTime();

// 1) Choose behaviors
Vector2 mouse = GetMousePosition();
Steering::SeekPoint(registry, agent, mouse, 1.0f, 1.0f);
Steering::Wander   (registry, agent, 20.f, 40.f, 80.f, 0.4f);

// 2) Apply steering
Steering::Update(registry, agent, dt);

// 3) Step physics
cpSpaceStep(world->space, dt);

// 4) Render
cpVect pos = cpBodyGetPosition(Steering::get_cpBody(registry, agent));
Vector2 v2 = physics::chipmunkToRaylibCoords(pos);
DrawCircleV(v2, 10, GREEN);
```

**Always:** Behaviors → `Steering::Update` → `cpSpaceStep`.

---

## 3. Flocking Example

Gather neighbors:

```cpp
std::vector<entt::entity> GatherNeighbors(entt::registry& r, entt::entity self, float radius) {
    std::vector<entt::entity> out;
    cpBody* sb = Steering::get_cpBody(r, self);
    if (!sb) return out;

    cpVect sp = cpBodyGetPosition(sb);
    float r2 = radius*radius;

    for (auto e : r.view<SteerableComponent>()) {
        if (e == self) continue;
        if (auto* b = Steering::get_cpBody(r, e)) {
            cpVect p = cpBodyGetPosition(b);
            if (cpvdistsq(sp, p) <= r2) out.push_back(e);
        }
    }
    return out;
}
```

Use per frame:

```cpp
auto n = GatherNeighbors(registry, agent, 120.f);
Steering::Separate(registry, agent, 40.f, n, 1.2f);
Steering::Align   (reg, agent, n, 120.f, 0.6f);
Steering::Cohesion(reg, agent, n, 120.f, 0.5f);
```

---

## 4. Path Following

Set path once:

```cpp
std::vector<cpVect> path = {
    cpv(50, 50), cpv(300, 60), cpv(500, 200)
};
Steering::SetPath(registry, agent, std::move(path), 16.f);
```

Each frame:

```cpp
Steering::PathFollow(registry, agent, 1.0f, 1.0f);
```

---

## 5. Timed Forces / Impulses

```cpp
// Apply steering force for 0.2s
Steering::ApplySteeringForce(registry, agent, 1400.f, angle, 0.2f);

// Apply impulse burst over 0.08s
Steering::ApplySteeringImpulse(registry, agent, 600.f, angle, 0.08f);
```

Handled in `Steering::Update`.

---

## 6. Pursuit / Evade

```cpp
Steering::Pursuit(registry, agent, target, 1.0f);
Steering::Evade  (reg, agent, target, 1.0f);
```

---

## 7. Recipes

* **Seek + Wander:**

  ```cpp
  Steering::SeekPoint(reg, agent, mouse, 1.0f, 1.0f);
  Steering::Wander   (reg, agent, 18.f, 36.f, 72.f, 0.35f);
  ```

* **Flocking:**

  ```cpp
  auto n = GatherNeighbors(reg, agent, 120.f);
  Steering::Separate(reg, agent, 40.f, n, 1.1f);
  Steering::Align   (reg, agent, n, 120.f, 0.7f);
  Steering::Cohesion(reg, agent, n, 120.f, 0.6f);
  ```

* **Guard patrol:**

  ```cpp
  if (IntruderInSight)
      Steering::Pursuit(reg, guard, intruder, 1.0f);
  else {
      Steering::PathFollow(reg, guard, 1.0f, 1.0f);
      Steering::Wander(reg, guard, 8.f, 20.f, 40.f, 0.15f);
  }
  ```

---

## 8. Batch Update

Don’t update one-by-one. Do:

```cpp
for (auto e : registry.view<SteerableComponent>()) {
    // Choose behaviors for e
}
for (auto e : registry.view<SteerableComponent>()) {
    Steering::Update(registry, e, dt);
}
cpSpaceStep(world->space, dt);
```

---

## Key Tips

* Ensure every steerable has a `ColliderComponent` or `BodyComponent`.
* Don’t divide forces by mass — Chipmunk handles it.
* Always convert between Raylib and Chipmunk coords properly.
* Order: Behaviors → Update → Physics step.
