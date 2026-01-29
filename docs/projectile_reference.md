# Projectile System Reference

Paths: `assets/scripts/combat/projectile_system.lua`, examples in `assets/scripts/combat/projectile_examples.lua`, tests in `assets/scripts/test_projectiles.lua`.

## Runtime & Update
- Initialize once: `ProjectileSystem.init()`; cleanup: `ProjectileSystem.cleanup()`.
- Default updates are scheduled via `timer.every_physics_step`; `ProjectileSystem.update(dt)` only runs when physics-step timers are unavailable.
- World bounds come from `SCREEN_BOUND_*` globals; hits on bounds despawn unless `collisionBehavior` is `bounce`.

## Spawning Core
```lua
ProjectileSystem.spawn({
  position = {x, y}, positionIsCenter = true|false,
  movementType = "straight"|"homing"|"orbital"|"arc"|"custom",
  collisionBehavior = "destroy"|"pierce"|"bounce"|"explode"|"pass_through",
  angle|direction|velocity, baseSpeed,
  sprite, size, lifetime,
  damage, damageType, owner, modifiers = {},
  onSpawn = fn, onHit = fn, onDestroy = fn
})
```
- State lives on the entity’s script table: `projectileData`, `projectileBehavior`, `projectileLifetime` (use `ProjectileSystem.getProjectileScript(eid)` to read).
- Collision tags: projectiles are tagged `"projectile"`; targets default to `{ "enemy", "WORLD" }` unless overridden via `collideWithTags`/`targetCollisionTag`/`collideWithWorld`.

## Movement Types
- `straight`: velocity from `angle`/`direction`/`velocity`; rotation matches travel.
- `homing`: `homingTarget`, `homingStrength`, `homingMaxSpeed`; falls back to straight if no valid target.
- `arc`: gravity-assisted; per-projectile override `gravityScale`. If the physics world has no gravity, set `forceManualGravity=true` (and optionally `usePhysics=false`) to use the internal gravity integrator.
- `orbital`: circles around `orbitCenter` and `orbitRadius` with `orbitSpeed`. To lock onto a moving entity, set `orbitCenterEntity=<entity>`; the center is resampled from that entity each tick.
- `custom`: provide `customUpdate(entity, dt, transform, behavior, data)` and drive movement yourself.

## Collision Behaviors
- `destroy`: despawn on first hit.
- `pierce`: track hits; despawn after `maxPierceCount`.
- `bounce`: reflect velocity with `bounceDampening`; despawn after `maxBounces`.
- `explode`: emit `projectile_exploded`, then despawn.
- `pass_through`: apply damage without despawning.
- Hooks: `onHit(projectile, target, data)` fires before behavior resolution; `onDestroy(projectile, data)` fires on cleanup. Signals emitted: `projectile_spawned`, `projectile_hit`, `projectile_exploded`, `projectile_destroyed`.

## Testing Targets (current defaults in `test_projectiles.lua`)
- Homing: targets `survivorEntity` (player) with long lifetime (999s).
- Arc: uses `forceManualGravity=true`, `usePhysics=false` to guarantee custom gravity.
- Orbital: orbits around player (or fallback) with `orbitCenterEntity` to follow player.

## Practical Tips
- If collisions fail: confirm physics world exists, target tags include `"projectile"` ↔ target tag, and `collideWithWorld` as needed.
- For bespoke collision logic, keep `collisionBehavior="pass_through"` or `pierce` and implement effects in `onHit`/signal listeners.

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
