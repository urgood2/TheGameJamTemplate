# UI & Shader Improvements Spec

**Date:** 2026-01-02
**Status:** Ready for Implementation

---

## 1. Planning Phase Background Shader

### Goal
Apply a monocolor effect to the background during the planning phase only, creating a clear visual distinction between phases.

### Specification

| Property | Value |
|----------|-------|
| Effect Type | Blend: Desaturation + Warm Sepia Tint |
| Intensity | Medium (40-60% strength) |
| Transition | Fade over 0.2-0.3s when phase changes |
| Scope | Background layer only (not entities/UI) |
| Toggle | Always-on, no settings needed |

### Implementation Notes
- Apply desaturation first, then overlay sepia tint
- Use a uniform `u_phase_blend` (0.0 = combat, 1.0 = planning) for smooth interpolation
- Sepia color suggestion: `vec3(0.9, 0.75, 0.55)` or similar warm tone
- Listen to phase change events to trigger the transition tween

---

## 2. 3D-Skew Shader Outline

### Goal
Add an optional outline to the existing `3d_skew` family of shaders for selection state and general styling.

### Specification

| Property | Value |
|----------|-------|
| Rendering | Shader-based (GPU outline pass) |
| Default Thickness | 3-4 pixels at 1x scale |
| Use Cases | Selection state indicator, general per-card styling |
| Color | Configurable via uniform (default: white or card-specific) |
| Toggle | Per-entity enable/disable via shader parameter |

### Implementation Notes
- Add outline as additional pass in the 3d_skew shader family
- New uniforms: `u_outline_enabled`, `u_outline_color`, `u_outline_thickness`
- Outline should respect the 3D perspective transformation
- For selection state: enable outline on hover/select, disable otherwise
- Consider using SDF-based outline for smooth scaling

---

## 3. Smart Tooltip Positioning

### Goal
Tooltips should appear adjacent to their target object, never covering it, never going out of bounds, with smart fallback positioning.

### Specification

| Property | Value |
|----------|-------|
| Default Position | Right of object, vertically centered |
| Fallback Chain | Right → Left → Above → Below → Clamp to bounds |
| Overlap Handling | Prioritize visibility (allow partial overlap on very large objects) |
| Bounds | Screen edges with padding margin |
| Centering | Vertical centering when on left/right; horizontal centering when above/below |

### Positioning Algorithm
```
1. Calculate object bounds (with small padding)
2. Try preferred side (right):
   - Position tooltip to right of object
   - Vertically center tooltip relative to object
   - Check if tooltip fits within screen bounds
3. If out of bounds, try fallback sides in order:
   - Left (vertically centered)
   - Above (horizontally centered)
   - Below (horizontally centered)
4. If all sides fail:
   - Use best-fit side
   - Clamp tooltip position to screen bounds
   - Accept partial overlap with object to maintain readability
```

### Edge Cases
- **Very large objects:** Prioritize tooltip visibility, allow partial overlap
- **Very small objects:** Tooltip may be larger than object, just ensure no full coverage
- **Near screen corners:** Smart fallback will find best available space

---

## 4. Critical Hit Damage Integration

### Goal
Add tooling for guaranteed crits, and differentiate crit damage in the damage number display.

### Specification

| Property | Value |
|----------|-------|
| Force-Crit API | Per-attack flag: `{ forceCrit = true }` in attack data |
| Crit Display Color | Gold/Yellow (vs. normal red) |
| Existing System | Crits already work in combat; this adds force-crit + visual distinction |

### API Design
```lua
-- Force a guaranteed crit in attack data
local attackData = {
    damage = 50,
    source = playerEntity,
    forceCrit = true,  -- NEW: bypasses crit roll, guarantees crit
}

-- Combat system checks:
local isCrit = attackData.forceCrit or rollCrit(attackData.critChance)
```

### Damage Number Changes
```lua
-- In damage popup system:
if hitResult.isCrit then
    popup.damage(entity, damage, { color = "gold" })  -- Crit: gold
else
    popup.damage(entity, damage)  -- Normal: red (default)
end
```

### Implementation Notes
- Modify combat system's hit resolution to check `forceCrit` flag before RNG roll
- Pass `isCrit` result through to damage number display system
- Update `popup.damage()` or equivalent to accept color override
- Cards/abilities can set `forceCrit = true` on their attack data to guarantee crits

---

## 5. MOD_CAST_FROM_EVENT Fix (TRIGGER_ON_KILL)

### Goal
Fix projectiles spawned by `MOD_CAST_FROM_EVENT` with `TRIGGER_ON_KILL` to spawn from the position where the enemy died, not from the player.

### Current Behavior
- Projectiles spawn from **player position** instead of dead enemy position

### Expected Behavior
- Projectiles should spawn from the **enemy's death position**

### Root Cause Investigation Needed
- The event context when `TRIGGER_ON_KILL` fires likely contains `source` (player) but not `target_position` (enemy death location)
- The cast system is defaulting to source position

### Fix Approach
1. Ensure kill event includes enemy's position in event data:
   ```lua
   ctx.bus:emit("OnKill", {
       killer = attacker,
       victim = enemy,
       position = { x = enemyX, y = enemyY },  -- Include death position
   })
   ```

2. In `MOD_CAST_FROM_EVENT` handler, use event position if available:
   ```lua
   local spawnPos = eventData.position or getEntityPosition(eventData.killer)
   ```

---

## 6. Right-Click Detection on Cards

### Goal
Detect right mouse button clicks on cards in addition to existing left-click.

### Specification

| Property | Value |
|----------|-------|
| Action | Log statement only (for now) |
| Scope | Cards with interactive/clickable components |
| Future Use | Placeholder for context menu, inspect, etc. |

### Implementation Notes
- Extend existing card click detection to check for right mouse button
- Use `IsMouseButtonPressed(MOUSE_BUTTON_RIGHT)` or equivalent Raylib binding
- Add `onRightClick` callback alongside existing `onClick`:
  ```lua
  interactive = {
      click = function(reg, eid) ... end,
      rightClick = function(reg, eid)
          print("[DEBUG] Right-click on card:", eid)
      end,
  }
  ```
- Ensure hover detection already works (right-click requires knowing which card is under cursor)

---

## Summary Checklist

- [ ] **Planning Phase Shader:** Sepia + desaturation, 0.2-0.3s fade, 40-60% intensity
- [ ] **3D-Skew Outline:** Shader-based, 3-4px, selection + styling use
- [ ] **Smart Tooltips:** Right-first, smart fallback chain, visibility priority
- [ ] **Crit Damage:** `forceCrit` flag, gold color for crit numbers
- [ ] **Cast From Event:** Fix spawn position to use enemy death location
- [ ] **Right-Click:** Add detection, log statement placeholder

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
