# Z-Order and Layer Rendering

## Setting Entity Z-Level

```lua
layer_order_system.assignZIndexToEntity(entity, z_orders.ui_tooltips + 100)
local z = layer_order_system.getZIndex(entity)
```

## Common Z-Order Values

From `core/z_orders.lua`:

| Constant | Value | Purpose |
|----------|-------|---------|
| `z_orders.background` | ~0 | Background layers |
| `z_orders.card` | ~100 | Normal cards |
| `z_orders.top_card` | 200 | Dragged/focused cards |
| `z_orders.ui_tooltips` | 900 | UI tooltips |

**For UI cards above everything:** Use `z_orders.ui_tooltips + 500` (~1400).

## DrawCommandSpace (Camera Awareness)

| Space | Behavior | Use For |
|-------|----------|---------|
| `layer.DrawCommandSpace.World` | Follows camera | Game objects, world-space cards |
| `layer.DrawCommandSpace.Screen` | Fixed to viewport | HUD, fixed UI elements |

```lua
-- Camera-aware (moves with camera)
command_buffer.queueDrawBatchedEntities(layers.ui, function(cmd)
    cmd.entities = entityList
end, z, layer.DrawCommandSpace.World)

-- Fixed to screen
command_buffer.queueDrawRectangle(layers.ui, function(c)
    c.x, c.y, c.w, c.h = 10, 10, 100, 50
end, z, layer.DrawCommandSpace.Screen)
```

## Dual Quadtree Collision System

The engine uses **two separate quadtrees**:

| Quadtree | Marker | Coordinate System |
|----------|--------|-------------------|
| `quadtreeWorld` | NO `ScreenSpaceCollisionMarker` | Camera-transformed |
| `quadtreeUI` | HAS `ScreenSpaceCollisionMarker` | Screen coordinates |

`FindAllEntitiesAtPoint()` queries BOTH automatically.

### World-Space Card Colliding with Screen-Space UI

```lua
local entity = createCard(...)

-- 1. Do NOT add ObjectAttachedToUITag (stays in world quadtree)
-- 2. Render to UI layer with World space
command_buffer.queueDrawBatchedEntities(layers.ui, function(cmd)
    cmd.entities = { entity }
end, z_orders.ui_tooltips + 500, layer.DrawCommandSpace.World)

-- 3. UI slots get ScreenSpaceCollisionMarker automatically
-- 4. Drag-drop works: input system queries both quadtrees
```

## UI Click Debugging Checklist

When UI doesn't respond to clicks:

1. **Has ScreenSpaceCollisionMarker?**
   ```lua
   print(registry:any_of(entity, ScreenSpaceCollisionMarker))
   ```

2. **Collision bounds correct?**
   ```lua
   local coll = component_cache.get(entity, CollisionShape2D)
   print(coll.aabb_min_x, coll.aabb_min_y, coll.aabb_max_x, coll.aabb_max_y)
   ```

3. **Z-order high enough?**
   ```lua
   print(layer_order_system.getZIndex(entity))
   ```

4. **Correct DrawCommandSpace?**
   - HUD: `Screen`
   - Game: `World`

5. **Debug render bounds:**
   ```lua
   draw.debug_bounds(entity, "red")
   ```

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
