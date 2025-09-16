# Spring Component Lua API Usage Guide

This guide explains how to use the `Spring` component and its helpers from Lua after binding via Sol2.

---

## Overview

Springs are physics-inspired values that interpolate smoothly toward a target. They can be used for UI animation, camera smoothing, juicy effects, or any transform-like property.

The Lua API exposes:

* The `Spring` component (attach to entities).
* A `spring` module with factory functions and helpers.
* Methods to pull, animate, and update springs.

---

## Creating Springs

### Create a new entity with a Spring (one-liner)

```lua
-- (entity, springRef) = spring.make(registry, initialValue, stiffness, damping, opts?)
local e, s = spring.make(registry, 0.0, 120.0, 14.0, {
  target = 1.0,
  smoothingFactor = 0.9,
  preventOvershoot = true,
  maxVelocity = 10.0
})
```

* **registry** – your bound `entt::registry`
* **initialValue** – starting value
* **stiffness** – spring constant
* **damping** – damping factor
* **opts (optional)** – Lua table to configure extra fields (`target`, `smoothingFactor`, `preventOvershoot`, etc.)

### Attach to an existing entity

```lua
local sp = spring.attach(registry, player, 0.0, 90.0, 12.0, { target = 1.0 })
sp:pull(0.4)        -- impulse-like tug
sp:animate_to(0.0, 90.0, 12.0)
```

---

## Updating

### Update all Springs in the registry

```lua
spring.update_all(registry, dt)
```

### Update a single Spring

```lua
spring.update(s, dt)
```

Call these every frame in your update loop.

---

## Methods on Spring

```lua
s:pull(force, stiffness?, damping?)   -- apply impulse
s:animate_to(target, stiffness, damping)

-- animate toward target in a given time, optional easing function
s:animate_to_time(1.0, 0.35, function(t) return t*t*(3-2*t) end)

s:enable()            -- enable updates
s:disable()           -- disable updates
s:snap_to_target()    -- jump to target, zero velocity
```

---

## Fields on Spring

All fields are read/write from Lua:

```lua
s.value = 0.0          -- current value
s.targetValue = 1.0    -- target value
s.velocity = 0.0       -- current velocity
s.stiffness = 120.0    -- spring constant
s.damping = 14.0       -- damping constant
s.enabled = true       -- toggle updates

-- Optional behavior fields
s.usingForTransforms = true
s.preventOvershoot = true
s.maxVelocity = 10.0
s.smoothingFactor = 0.9
s.timeToTarget = nil   -- set internally by animate_to_time
```

---

## Example Usage

### Simple animation

```lua
local e, s = spring.make(registry, 0.0, 100.0, 12.0)
s:animate_to(1.0, 120.0, 14.0)

function update(dt)
  spring.update_all(registry, dt)
  print("Value:", s.value)
end
```

### Time-based animation with easing

```lua
local e, s = spring.make(registry, 0.0, 100.0, 12.0)

s:animate_to_time(1.0, 0.5, function(t)
  -- ease in/out (smoothstep)
  return t*t*(3 - 2*t)
end)
```

### Pull for “juice”

```lua
-- scale spring on a UI element
local e, scaleSpring = spring.make(registry, 1.0, 150.0, 15.0)

-- tug on click
theButton:on_click(function()
  scaleSpring:pull(0.25)
end)
```

---

## Notes

* All functions return live references: modifying a field in Lua updates the actual component.
* Use `preventOvershoot` if you want springs to stop exactly at their target.
* Use `smoothingFactor` to dampen integration if you see jitter.
* Easing functions for `animate_to_time` are optional; default is linear.
