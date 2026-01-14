---
name: debug-ui-collision
description: Use when UI elements don't respond to clicks - runs 7-step diagnostic checklist covering collision setup, input system, and z-order issues
---

# Debug UI Collision Skill

## When to Use

Trigger this skill when:
- UI buttons/tabs not responding to clicks
- Drag-and-drop not registering
- Hover states not activating
- UI elements "invisible" to input system

## Diagnostic Checklist

Work through these steps IN ORDER. Stop when you find the issue.

### Step 1: Check ScreenSpaceCollisionMarker

```lua
local hasMarker = registry:any_of(entity, ScreenSpaceCollisionMarker)
if not hasMarker then
    print("MISSING: ScreenSpaceCollisionMarker - UI elements need this for click detection")
    -- FIX: registry:emplace(entity, ScreenSpaceCollisionMarker {})
end
```

**Why first:** Most common cause of UI non-responsiveness.

### Step 2: Verify Collision Bounds

```lua
local coll = component_cache.get(entity, CollisionShape2D)
if coll then
    print("Bounds:", coll.aabb_min_x, coll.aabb_min_y, "to", coll.aabb_max_x, coll.aabb_max_y)
    -- Check: bounds should match visual size and position
else
    print("MISSING: CollisionShape2D component")
end
```

**Common issue:** Bounds at (0,0,0,0) or misaligned with visual.

### Step 3: Check Z-Order

```lua
local z = layer_order_system.getZIndex(entity)
print("Z-order:", z)
-- Compare with overlapping elements - higher z = on top for input
```

**Common issue:** Another element at higher z-order is consuming input.

### Step 4: Verify DrawCommandSpace

```lua
-- For HUD/fixed UI: should use Screen
-- For game objects: should use World
-- Mismatch causes position calculation errors
```

### Step 5: Debug Render Collision Box

```lua
draw.debug_bounds(entity, "red")
-- Visual should align with collision bounds
-- If misaligned, fix transform or collision shape
```

### Step 6: Check Parent Input Consumption

```lua
local parent = ChildBuilder.getParent(entity)
if parent then
    local parentUI = component_cache.get(parent, UIElementComponent)
    if parentUI and parentUI.consumes_input then
        print("Parent is consuming input!")
    end
end
```

### Step 7: Verify Quadtree Membership

```lua
-- With ScreenSpaceCollisionMarker = UI quadtree (screen coords)
-- Without = World quadtree (camera-transformed coords)
-- Cross-quadtree: use FindAllEntitiesAtPoint() which queries both
```

## Quick Fixes

| Symptom | Likely Fix |
|---------|------------|
| Clicks ignored | Add ScreenSpaceCollisionMarker |
| Wrong position | Check DrawCommandSpace World/Screen |
| Behind other UI | Increase z-order |
| Bounds at 0,0 | Re-emplace CollisionShape2D |

## Resolution Verification

After applying fix, verify with:
```lua
-- Click should now work
-- Hover states should activate
-- Debug bounds should be visible at correct position
```
