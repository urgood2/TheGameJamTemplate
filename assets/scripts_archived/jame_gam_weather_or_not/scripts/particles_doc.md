# Lua Particle API – Quickstart & Working Examples

This guide documents the Lua-facing particle bindings exposed by `exposeToLua(sol::state &lua)` and gives **copy‑pasteable examples** you can run immediately.

> TL;DR: You get `particle.Particle`, `particle.ParticleEmitter`, enums (`ParticleRenderType`, `RenderSpace`), helpers (`Vec2`, `Col`), and functions (`CreateParticle`, `CreateParticleEmitter`, `EmitParticles`, `AttachEmitter`, `WipeAll`, `WipeTagged`). Optional fields use `nil` to unset.

---

## What gets registered

### Namespaces & Enums

* **`particle`** – root table.
* **`particle.ParticleRenderType`**

  * `TEXTURE`, `RECTANGLE_LINE`, `RECTANGLE_FILLED`, `CIRCLE_LINE`, `CIRCLE_FILLED`
* **`particle.RenderSpace`**

  * `WORLD`, `SCREEN`

### Types

* **`Particle` (component-like data)**

  * **Required**: `renderType`, `space`, `z`
  * **Optional** (`nil` to clear/unset):

    * `velocity: Vector2?`, `scale: number?`, `rotation: number?`, `rotationSpeed: number?`
    * `lifespan: number?`, `age: number?`, `gravity: number?`, `acceleration: number?`
    * `color: Color?`, `startColor: Color?`, `endColor: Color?`
  * **Callbacks**:

    * `onInitCallback: fun(entity, particle)` – called once after creation
    * `onUpdateCallback: fun(particle, dt)` – called each frame
  * **Meta**: `tostring(p)` prints a short summary

* **`particle.ParticleEmitter`** (config struct)

  * Core: `size: Vector2`, `emissionRate: number` (seconds between emissions),
    `particleLifespan`, `particleSpeed`, `fillArea: boolean`,
    `emissionSpread: number` (deg), `emissionDirection: Vector2`,
    `gravityStrength`, `acceleration`, `randomness`, `explosiveness`, `speedScale`,
    `oneShot`, `oneShotParticleCount`, `prewarm`, `prewarmParticleCount`,
    `blendMode`, `colors: Color[]`
  * Defaults for spawned particles: `defaultZ: integer?`, `defaultSpace: RenderSpace?`

* **Utility Types**

  * `Vector2 { x, y }` with constructors `Vector2()` and `Vector2(x, y)` and helper **`Vec2(x, y)`**
  * `Color { r, g, b, a }` with constructors `Color()` (white) and `Color(r,g,b,a)` and helper **`Col(r,g,b[,a])`**

### Functions

* **`particle.CreateParticle(location: Vector2, size: Vector2, opts?: table, animCfg?: table, tag?: string): entt::entity`**

  * `opts` fields: `renderType`, `velocity`, `rotation`, `rotationSpeed`, `scale`,
    `lifespan`, `age`, `color`, `gravity`, `acceleration`, `startColor`, `endColor`,
    `space` (`"world"|"screen"` or `particle.RenderSpace`), `z: integer`,
    `onUpdateCallback`, `onInitCallback`, `shadow: boolean` (default **true**)
  * `animCfg` (forces `renderType=TEXTURE`): `{ loop: boolean, animationName: string }`

* **`particle.CreateParticleEmitter(...) -> ParticleEmitter`**

  * Overloads:

    * `CreateParticleEmitter()` – default-config emitter
    * `CreateParticleEmitter(location: Vector2, opts: table)` – table-driven builder (your overload)

* **`particle.EmitParticles(emitterEntity, count)`** – burst spawn from an emitter entity.

* **`particle.AttachEmitter(emitterEntity, targetEntity, opts?: { offset: Vector2 })`** – parent emitter under a target with optional offset (uses your transform inheritance helper).

* **`particle.WipeAll()`**, **`particle.WipeTagged(tag: string)`** – destructive cleanup.

---

## Working Example 1 – Circular Burst with Easing (self‑contained)

This reproduces your example, but **self‑contained** (no external `util` needed) and demonstrates using the **derivative** of an ease for velocity while using the base ease for scale.

```lua
-- Minimal easing lib with f (ease) and d (derivative)
Easing = {
  cubic = {
    f = function(t) return 1 - (1 - t)^3 end,            -- outCubic
    d = function(t) local a = 1 - t; return 3*a*a end     -- derivative of outCubic
  },
  -- add your other easings similarly; name with your convention
}

-- Tiny color helper (names → Col). Use your palette if available.
local COLOR = setmetatable({
  WHITE = Col(255,255,255,255),
  apricot_cream = Col(255, 214, 170, 255),
  coral_pink    = Col(255, 127, 127, 255),
}, { __index = function() return Col(255,255,255,255) end })

-- Spawn a ring of rectangles that fly out then slow down (velocity from dE/dt)
function spawnCircularBurstParticles(x, y, count, seconds, startColor, endColor, easingName, space)
  local easing = Easing[easingName] or Easing.cubic
  local initialSize   = 10
  local burstSpeed    = 200
  local growRate      = 20
  local rotationSpeed = 460
  space = space or particle.RenderSpace.SCREEN  -- accept enum or string

  for i = 1, count do
    local angle = math.random() * (2 * math.pi)
    local dir   = Vec2(math.cos(angle), math.sin(angle))

    particle.CreateParticle(
      Vec2(x, y),
      Vec2(initialSize, initialSize),
      {
        renderType    = particle.ParticleRenderType.RECTANGLE_FILLED,
        velocity      = Vec2(0, 0),
        acceleration  = 0,
        lifespan      = seconds,
        startColor    = startColor or COLOR.apricot_cream,
        endColor      = endColor   or COLOR.coral_pink,
        rotationSpeed = rotationSpeed,
        space         = space,  -- can also pass "screen" or "world"
        z             = 0,

        onUpdateCallback = function(comp, dt)
          local age      = comp.age or 0.0
          local life     = comp.lifespan or seconds or 0.000001
          local t        = math.min(math.max(age / life, 0), 1)

          -- 1) Radial speed from derivative of the easing (peaks early, then eases out)
          local speed = burstSpeed * easing.d(t)
          comp.velocity = Vec2(dir.x * speed, dir.y * speed)

          -- 2) Size growth driven by the base ease
          local eased = easing.f(t)
          comp.scale  = initialSize + growRate * (eased * life)
        end,
      },
      nil  -- no animation cfg
    )
  end
end

-- Example call (e.g., on mouse click)
spawnCircularBurstParticles(
  400, 300,
  12,         -- count
  0.6,        -- seconds
  COLOR.apricot_cream,
  COLOR.coral_pink,
  "cubic",   -- using the cubic easing defined above
  particle.RenderSpace.SCREEN
)
```

**Why derivative for velocity?** If position over time is `x(t) = E(t)`, then instantaneous speed is `dx/dt = E'(t)`. Using `E'(t)` gives a natural acceleration/deceleration profile that matches the shape of your easing.

---

## Working Example 2 – Table‑Driven `CreateParticle` with Texture Animation

For animated particles, pass `animCfg` and the binding forces `renderType=TEXTURE`.

```lua
-- Spawns an animated sparkle that gently drifts up
local e = particle.CreateParticle(
  Vec2(512, 320),
  Vec2(16, 16),
  {
    lifespan = 1.25,
    space    = "world",  -- string also supported
    z        = 5,
    color    = Col(255,255,255,220),
    velocity = Vec2(0, -30),
    onInitCallback = function(ent, p)
      -- e.g., jitter its starting rotation
      p.rotation = (math.random() * 20) - 10
    end,
  },
  { loop = true, animationName = "sparkle_small" },
  "fx_sparkle"
)
```

---

## Working Example 3 – Emitters, Bursts, and Attachment

Demonstrates the table‑driven emitter builder, one‑shot bursts, and parenting to an entity with an offset.

```lua
-- Build an emitter at a location with overrides
local emitter_entity = particle.CreateParticleEmitter(
  Vec2(300, 300),
  {
    size = Vec2(48, 48),
    emissionRate = 0.08,         -- seconds between emissions
    particleLifespan = 0.75,
    particleSpeed = 180,
    emissionSpread = 90,          -- degrees
    emissionDirection = Vec2(1,0),
    gravityStrength = 0,
    acceleration = 0,
    randomness = 0.4,
    explosiveness = 0.2,
    colors = { Col(255,255,255,255), Col(255,200,200,255) },
    defaultSpace = particle.RenderSpace.WORLD,
    defaultZ = 2,
  }
)

-- Fire a one‑shot burst of N particles from that emitter
particle.EmitParticles(emitter_entity, 24)

-- Attach the emitter to some existing game entity with an offset
-- (Assumes you have a valid entt::entity handle called `player_entity`)
particle.AttachEmitter(emitter_entity, player_entity, { offset = Vec2(0, -16) })
```

---

## API Details & Gotchas

* **Optional fields** (`velocity`, `rotation`, etc.) are represented as `nil` when unset. Setting to `nil` clears them.
* **`space`** accepts either the enum (`particle.RenderSpace.SCREEN`) **or** a lowercase string (`"screen"` / `"world"`).
* **`shadow`** (in `CreateParticle` opts) defaults to `true`. Set `shadow=false` to disable shadow displacement.
* **Animation**: Supplying `animCfg` forces `renderType=TEXTURE` inside the binding.
* **`onUpdateCallback` / `onInitCallback`** are cloned into the **main Lua state** to avoid coroutine/thread scope issues.
* **`tostring(Particle)`** prints only a brief summary – useful for quick logging.
* **Cleanup**: `particle.WipeTagged("fx_sparkle")` removes only particles with that tag; `WipeAll()` nukes everything.

---

## Extending Easing (optional)

If you keep using derivative‑driven motion, define each easing as a table with `f` and `d`. Example for Sine variants:

```lua
Easing.inSine = {
  f = function(t) return 1 - math.cos(1.5707963 * t) end,   -- same shape as sin(π/2 * t)
  d = function(t) return 1.5707963 * math.sin(1.5707963 * t) end,
}
Easing.outSine = {
  f = function(t) return math.sin(1.5707963 * t) end,       -- classic out‑sine
  d = function(t) return 1.5707963 * math.cos(1.5707963 * t) end,
}
Easing.inOutSine = {
  f = function(t) return 0.5 * (1 - math.cos(3.1415926 * t)) end,
  d = function(t) return 0.5 * 3.1415926 * math.sin(3.1415926 * t) end,
}
```

> Use `Easing.someEase.d(t)` for velocity, `Easing.someEase.f(t)` for position/size.

---

## Quick Reference

* **Spawn a particle**: `particle.CreateParticle(pos, size, opts[, animCfg[, tag]])`
* **Make an emitter**: `particle.CreateParticleEmitter(pos, opts)` or `CreateParticleEmitter()`
* **Burst**: `particle.EmitParticles(emitter, count)`
* **Attach**: `particle.AttachEmitter(emitter, target, { offset = Vec2(dx,dy) })`
* **Kill**: `particle.WipeTagged(tag)` / `particle.WipeAll()`

Happy bursting. Keep the API ergonomic: enums for speed, strings for convenience, `nil` to clear. If anything feels off during use, it probably is—tighten the binding or fix the docs here to match reality.
