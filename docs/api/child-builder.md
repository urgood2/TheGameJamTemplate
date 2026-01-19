# ChildBuilder API

Fluent API for attaching child entities to parents with offset, rotation, and animation support.

## Basic Usage

```lua
local ChildBuilder = require("core.child_builder")

ChildBuilder.for_entity(weapon)
    :attachTo(player)
    :offset(20, 0)
    :rotateWith()
    :apply()
```

## Builder Methods

| Method | Purpose |
|--------|---------|
| `:attachTo(parent)` | Set parent entity |
| `:offset(x, y)` | Position offset from parent center |
| `:rotateWith()` | Rotate with parent |
| `:scaleWith()` | Scale with parent |
| `:eased()` | Smooth position following |
| `:named(name)` | Name for lookup |
| `:permanent()` | Persist after parent death |
| `:apply()` | Apply configuration |

## Static Helpers

| Function | Purpose |
|----------|---------|
| `ChildBuilder.setOffset(entity, x, y)` | Immediate offset change |
| `ChildBuilder.getOffset(entity)` | Get current offset |
| `ChildBuilder.getParent(entity)` | Get parent entity |
| `ChildBuilder.detach(entity)` | Remove from parent |
| `ChildBuilder.animateOffset(entity, opts)` | Tween offset |
| `ChildBuilder.orbit(entity, opts)` | Arc/circular animation |

## Animate Child Offset (Weapon Swing)

```lua
ChildBuilder.animateOffset(weapon, {
    to = { x = -20, y = 30 },
    duration = 0.2,
    ease = "outQuad"
})

ChildBuilder.orbit(weapon, {
    radius = 30,
    startAngle = 0,
    endAngle = math.pi/2,
    duration = 0.2
})
```

## Example: Weapon Attached to Player

```lua
local weapon = EntityBuilder.simple("sword", 0, 0, 32, 32)

ChildBuilder.for_entity(weapon)
    :attachTo(player)
    :offset(16, 0)        -- 16px to the right of player center
    :rotateWith()         -- Rotate when player rotates
    :named("weapon")      -- Can lookup later
    :apply()

-- Later: animate a swing
ChildBuilder.animateOffset(weapon, {
    to = { x = -20, y = 30 },
    duration = 0.15,
    ease = "outQuad",
    onComplete = function()
        ChildBuilder.setOffset(weapon, 16, 0)  -- Reset
    end
})
```
