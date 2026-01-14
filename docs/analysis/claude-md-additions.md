# CLAUDE.md Additions - Based on Retrospective Analysis

**Generated:** 2026-01-14
**Source:** Conversation retrospective analysis of 511 transcripts

These additions address recurring struggle patterns identified in development sessions.

---

## Section: Common Mistakes to Avoid (New Entries)

Add these entries to the existing "Common Mistakes to Avoid" section:

### Don't: Exceed LuaJIT's 200 local variable limit

```lua
-- WRONG: File-scope locals accumulate in large files
local sound1 = loadSound("step1.wav")
local sound2 = loadSound("step2.wav")
local sound3 = loadSound("step3.wav")
-- ... 197 more locals = CRASH

-- RIGHT: Group related locals into tables
local sounds = {
    footsteps = {
        loadSound("step1.wav"),
        loadSound("step2.wav"),
        loadSound("step3.wav"),
    }
}
```

**Why:** LuaJIT has a hard limit of 200 local variables per function scope. Large files like `gameplay.lua` can hit this limit. Error message: `too many local variables (limit is 200)`.

### Don't: Forget ScreenSpaceCollisionMarker for UI elements

```lua
-- WRONG: UI element won't receive clicks
local button = createUIElement(...)
-- Missing collision marker!

-- RIGHT: Add collision marker for click detection
local button = createUIElement(...)
registry:emplace(button, ScreenSpaceCollisionMarker {})
```

**Why:** The engine uses dual quadtrees - `quadtreeWorld` for game objects and `quadtreeUI` for screen-space elements. `ScreenSpaceCollisionMarker` places entities in the UI quadtree for click detection.

### Don't: Mix World and Screen DrawCommandSpace carelessly

```lua
-- WRONG: HUD element follows camera
command_buffer.queueDraw(layers.ui, function(c)
    c.x, c.y = 10, 10  -- Screen position
end, z, layer.DrawCommandSpace.World)  -- Wrong! Will move with camera

-- RIGHT: Use Screen for fixed HUD
command_buffer.queueDraw(layers.ui, function(c)
    c.x, c.y = 10, 10
end, z, layer.DrawCommandSpace.Screen)  -- Fixed to viewport
```

---

## Section: Shaders (New Subsection)

Add this new subsection under "Shader Builder API":

### RenderTexture Y-Coordinate Handling

RenderTextures have inverted Y coordinates compared to screen coordinates (Raylib Y=0 at top, OpenGL Y=0 at bottom).

**Fix in fragment shader, NOT in Lua:**

```glsl
// In fragment shader
vec2 flippedTexCoord = vec2(fragTexCoord.x, 1.0 - fragTexCoord.y);
vec4 color = texture(texture0, flippedTexCoord);
```

**Remember:** Update BOTH desktop and web shader versions (`assets/shaders/` and `assets/shaders/web/`).

### GLSL Function Declaration Order

Unlike C/C++, GLSL has no forward declarations. Helper functions must be defined BEFORE first use.

```glsl
// WRONG: rotate2d used before definition
void main() {
    vec2 rotated = rotate2d(uv, angle);  // ERROR: undeclared identifier
}
mat2 rotate2d(float angle) { ... }

// RIGHT: define helper first
mat2 rotate2d(float angle) {
    return mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
}
void main() {
    vec2 rotated = rotate2d(uv, angle);  // Works
}
```

---

## Section: UI Debugging Checklist (New Section)

Add this new section after "World-Space vs Screen-Space Collision":

### UI Element Not Responding to Clicks - Debugging Checklist

When UI elements don't respond to clicks, check in order:

1. **ScreenSpaceCollisionMarker present?**
   ```lua
   local hasMarker = registry:any_of(entity, ScreenSpaceCollisionMarker)
   print("Has collision marker:", hasMarker)
   ```

2. **Collision bounds correct?**
   ```lua
   local coll = component_cache.get(entity, CollisionShape2D)
   print("Collision bounds:", coll.aabb_min_x, coll.aabb_min_y, coll.aabb_max_x, coll.aabb_max_y)
   ```

3. **Z-order high enough?**
   ```lua
   local z = layer_order_system.getZIndex(entity)
   print("Z-order:", z)  -- Should be > anything overlapping
   ```

4. **Correct DrawCommandSpace?**
   - HUD elements: `layer.DrawCommandSpace.Screen`
   - Game elements: `layer.DrawCommandSpace.World`

5. **In correct quadtree?**
   - WITH `ScreenSpaceCollisionMarker`: UI quadtree (screen coords)
   - WITHOUT: World quadtree (camera-transformed coords)

6. **Parent blocking input?**
   - Check if parent element has `consumes_input = true`

7. **Debug render the collision box:**
   ```lua
   draw.debug_bounds(entity, "red")  -- Should align with visual bounds
   ```

---

## Section: Dual Quadtree System (New Section)

Add this section to clarify the collision architecture:

### Understanding the Dual Quadtree System

The engine maintains **two separate spatial indices** for collision detection:

| Quadtree | Component | Query |
|----------|-----------|-------|
| `quadtreeWorld` | NO `ScreenSpaceCollisionMarker` | Uses camera-transformed mouse position |
| `quadtreeUI` | HAS `ScreenSpaceCollisionMarker` | Uses raw screen mouse position |

**Cross-quadtree Interaction:**

To enable world-space objects (cards) to interact with screen-space UI (slots):

```lua
-- FindAllEntitiesAtPoint() queries BOTH quadtrees
local entities = FindAllEntitiesAtPoint(screenX, screenY)
-- Returns both world entities (transformed) and UI entities (screen coords)
```

**Common Pattern - Cards Above UI:**
```lua
-- 1. Create card WITHOUT ObjectAttachedToUITag (stays in world quadtree)
local card = createCard(...)

-- 2. Render to UI layer with World space (camera-aware, renders above UI)
command_buffer.queueDrawBatchedEntities(layers.ui, function(cmd)
    cmd.entities = { card }
end, z_orders.ui_tooltips + 500, layer.DrawCommandSpace.World)

-- 3. UI slots have ScreenSpaceCollisionMarker (in UI quadtree)
-- 4. FindAllEntitiesAtPoint finds both for drag-drop
```

---

## How to Apply These Additions

1. Open `CLAUDE.md` in the project root
2. Find each referenced section
3. Add the new entries at appropriate locations
4. Verify no duplicate content
