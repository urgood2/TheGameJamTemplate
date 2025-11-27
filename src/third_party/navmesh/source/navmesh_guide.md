# NavMesh × PhysicsWorld – Game Loop Integration Guide

This document shows how to wire the `NavMesh::PathFinder` cache into your existing `PhysicsManager`/`PhysicsWorld` loop, when to rebuild it, and the practical caveats you should expect in a real game. (Lua usage is covered elsewhere; this file focuses on C++ integration and engine lifecycle.)

---

## TL;DR wiring

1. **Per world cache**: store a `NavmeshCache` (with `PathFinder pf`, `bool dirty`, and `NavmeshWorldConfig`) inside each `PhysicsManager::WorldRec`.

2. **Mark dirty on topology changes**: whenever static geometry changes (spawn/remove an obstacle, toggle sensor/static, change polygon verts), call `PhysicsManager::markNavmeshDirty(worldName)`.

3. **Lazy rebuild**: before the first nav query of a frame, if `dirty == true`, rebuild once using current colliders → vector of `NavMesh::Polygon` → `pf.AddPolygons(polys, inflate_px)`.

4. **Query**: call `PhysicsManager::findPath(world, src, dst)` (or `visionFan`) from AI or gameplay code; these ensure a rebuild first.

5. **Repeat**: only mark dirty and rebuild when needed. Don’t rebuild every frame.

---

## Engine lifecycle: where things plug in

### Startup

* Create physics worlds via `PhysicsManager::add("world_main", make_shared<PhysicsWorld>(...), maybeState)`.
* `add()` allocates `WorldRec::nav = std::make_unique<NavmeshCache>()` with sane defaults.
* Optionally set config per world (`default_inflate_px`, circle tesselation limits, etc.).

### Scene/Level load

* Spawn static obstacles (tiles, walls, blockers) as `ColliderComponent` entities.
* Optionally tag specific entities with `NavmeshObstacle{ include = true/false, inflate_pixels = ... }` to override inclusion rules.
* After level finishes placing static geometry, call `markNavmeshDirty("world_main")`. The first path query will kick off a rebuild.

### Per-frame main loop (pseudo)

```cpp
void Game::update(float dt) {
  // 1) Input & scripting that might edit topology (placing/removing walls)
  processGameplayEdits();                         // must call PM.markNavmeshDirty() if obstacles changed

  // 2) Physics step (your existing code)
  PM.stepAll(dt);                                 // Update/PostUpdate per world

  // 3) AI update
  //    Path queries here are fine — findPath() ensures navmesh is rebuilt lazily if dirty
  for (auto e : aiAgents) {
    auto src = NavMesh::Point(px, py);
    auto dst = NavMesh::Point(tx, ty);
    auto path = PM.findPath("world_main", src, dst);
    agents[e].consumePath(path);
  }

  // 4) Rendering (optional debug draw)
  PM.drawAll();                                   // physics debug
  drawNavmeshDebugIfEnabled();                    // see Debug section
}
```

### Hot edit / streaming scenarios

If your editor or gameplay can toggle obstacles at runtime (e.g., open/close doors), **limit dirty events** to actual topology changes:

* Opening a door: mark dirty once.
* Moving a static wall: mark dirty once after snapping to the new position.
* Minor dynamic bodies (NPCs, bullets) **should not** mark dirty — keep them out of the navmesh.

---

## Inclusion policy (what becomes an obstacle)

Default policy (recommended to start):

* Include colliders where `!isDynamic && !isSensor`.
* Exclude everything else.

Override with `NavmeshObstacle` on an entity:

* `include = true` to force inclusion (even if the body is dynamic).
* `include = false` to force exclusion.
* `inflate_pixels = X` to override world default inflation locally.

**Tip:** keep the navmesh strictly **structural** (level walls, permanent blockers). Handle crowds/characters with local avoidance rather than rebuilding the mesh for them.

---

## Rebuild strategy

**When to mark dirty**

* Entity with a collider is created/destroyed.
* Collider switches between sensor ↔ solid.
* Static obstacle’s shape vertices/radius/size change.
* Level chunk streamed in/out.

**When to rebuild**

* Lazily: on the first `findPath()` or `visionFan()` after `dirty==true`.
* Optionally: manually call `rebuildNavmeshFor(world)` after a large batch edit (e.g., after tilemap bake) so the next frame’s queries are fast.

**Debounce**

* If many edits happen in one frame (e.g., generating a whole dungeon), mark dirty during edits and rebuild **once** at the end or on first query.

**Threading** (optional)

* You can rebuild on a worker thread and swap in the ready `PathFinder`. If you do:

  * Build into a local `PathFinder` object.
  * Atomically replace the world’s `NavmeshCache::pf` once complete.
  * Guard `NavmeshCache::dirty`/`pf` with a lightweight mutex or RCU pattern.
  * Always allow synchronous fallback (rebuild on query) if the job hasn’t finished.

---

## Coordinate system caveats

* Your Chipmunk debug draw uses `cpVect` directly with Raylib draw calls, so your sim appears to be using a Y‑down world. Keep **navmesh points in the same space** you feed to your renderer and AI.
* If you ever decide to run Chipmunk Y‑up and render Y‑down, normalize coordinates when extracting polygons (`cpTransformPoint`), and be consistent when creating `NavMesh::Point` (flip or not) so path results line up with rendering and AI.
* **Units:** Navmesh is unit-agnostic; just be consistent. If you use pixels everywhere, pass pixels for `inflate_pixels`, circle radii, etc.

---

## Geometry extraction caveats

* **Rectangles:** Prefer storing/using a `cpPolyShape` for boxes so you can read its verts in body-local space and transform with `cpBodyGetTransform()`. Avoid `cpShapeGetBB()` for rotated boxes (it returns an AABB in world space and loses rotation).
* **Circles → polygons:** Circle obstacles are approximated with N-gons. Use `NavmeshWorldConfig` to set `circle_tol`, `circle_min_segments`, and `circle_max_segments`. Larger circles need more segments; keep an eye on performance.
* **Segments:** Inflate thin segments to a capsule-like quad using the shape radius or a minimum width (e.g., 1 px) so they become **area** obstacles not zero-thickness lines.
* **Chains/Polygons:** Ensure windings are consistent and polygons are simple (non‑self‑intersecting). If your source geometry can be concave, pass it as a single polygon only if the navmesh library supports it; otherwise pre-process into convex parts or keep as an obstacle *outline* if the library expects obstacle boundaries.

---

## Performance & memory

* **Rebuild cost** scales with the number and complexity of obstacle polygons. Practical tips:

  * Merge co-linear tile edges into long segments before polygonizing, or build wall loops directly from tilemaps.
  * Drop tiny debris and decorative colliders from the navmesh — they just create noise.
  * Keep circle seg count sensible.
* **Query frequency**: Cache paths when feasible (e.g., only re-path when target/source cells change meaningfully).
* **Multiple worlds**: Each `WorldRec` has its own `NavmeshCache`; only rebuild worlds that changed.

---

## Debugging tools

* Add a `navmesh_debug_draw(world)` util:

  * Iterate obstacle polygons you fed into `PathFinder` and draw wireframes.
  * When you query a path, draw the polyline.
  * Visualize “inflation” by drawing original obstacle in one color and inflated boundary in another (if you keep both around for debug).
* Log rebuilds with timings and obstacle counts.
* Expose a console toggle to force `markNavmeshDirty()` and to dump the current obstacle count.

---

## Failure modes & gotchas

* **Empty path**: If `GetPath()` returns empty, quickly check:

  * Are src/dst outside the navigable area (inside an obstacle or beyond bounds)?
  * Did you over-inflate obstacles so they close corridors? Reduce `default_inflate_px`.
  * Is there a gap between tiles that should be closed or, conversely, a seam that accidentally got sealed by merging?
* **Stuck agents**: If agents stand at corners and jitter, add arrival radius & corner smoothing in your steering, not in the navmesh.
* **Precision issues**: Very large coordinates can accumulate float error. Keep worlds within sane ranges (or apply world offset per chunk).
* **Dynamic blockers**: Don’t bake moving NPCs/props into the navmesh. Handle with local avoidance or nav “links” that can toggle (e.g., doors).

---

## Example: end-to-end setup

```cpp
// 1) World creation
PM.add("world_main", physics::InitPhysicsWorld(&registry, /*meter*/64.0f, 0, 0, &globals::getEventBus()));

// 2) Place static level colliders (tiles, walls). For special cases:
registry.emplace<NavmeshObstacle>(wallEntity, NavmeshObstacle{.include=true});

// 3) After level load
PM.markNavmeshDirty("world_main");

// 4) In AI code when you need a path
NavMesh::Point src(px, py);
NavMesh::Point dst(tx, ty);
auto path = PM.findPath("world_main", src, dst); // lazy rebuild if dirty
if (!path.empty()) agent.follow(path);

// 5) When opening a door at runtime
openDoor();
PM.markNavmeshDirty("world_main");
```

---

## Integration checklist

* [ ] `WorldRec` contains `std::unique_ptr<NavmeshCache>` and is initialized in `add()`.
* [ ] `markNavmeshDirty(world)` is called by: level load, tilemap bake, static obstacle create/destroy, sensor/solid toggles.
* [ ] `rebuildNavmeshFor(world)` collects eligible colliders, converts shapes → polygons, calls `pf.AddPolygons(polys, inflate)`.
* [ ] `findPath()`/`visionFan()` ensure rebuild if `dirty`.
* [ ] Optional debug draw and logging added.

---

## Tuning defaults (`NavmeshWorldConfig`)

* `default_inflate_px = 8` (start here; tighten to 4 if hallways get blocked; raise to 12–16 for bulky characters).
* `circle_tol = 2.5f`, `circle_min_segments = 8`, `circle_max_segments = 48`.
* For ultra‑dense tile worlds, consider building larger obstacle loops instead of per-tile boxes.

---

## Extending later (nice-to-haves)

* **Area partitioning / layers**: If a single physics world contains multiple disconnected dungeons, maintain one nav cache per area key.
* **One-way links / jump edges**: Keep these out of the base navmesh; manage separately as “off-mesh links”.
* **Async rebuild**: Add a job to rebuild and atomically swap the `PathFinder` to avoid one-frame rebuild spikes.

---

## Conclusion

Wire it once, keep the mesh **structural**, and rebuild **lazily**. Most headaches disappear if you:

* Only include static, non-sensor geometry by default.
* Mark dirty exactly when topology changes.
* Visualize obstacles and paths during development.

If you want me to tailor the inclusion rules to your exact collider authoring style (tilemap → loops, rotated boxes, etc.), point me to that code path and I’ll slot the conversions precisely.
