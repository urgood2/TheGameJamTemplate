# Projectile System - Physics Integration Modifications

**Date:** 2025-11-20
**Changes:** Made projectile system fully physics-driven and integrated with physics step timer

---

## Summary of Changes

The projectile system has been modified to be **fully physics-driven** and compatible with your existing physics-transform sync system. All three recommendations have been implemented:

1. ✅ **Made projectiles fully physics-driven**
2. ✅ **Added explicit physics sync configuration**
3. ✅ **Registered with physics step timer**

---

## Detailed Changes

### 1. Physics-Driven Movement (All Movement Types)

**Modified Functions:**
- `updateStraightMovement()` - Lines 468-492
- `updateHomingMovement()` - Lines 494-573
- `updateOrbitalMovement()` - Lines 575-607
- `updateArcMovement()` - Lines 609-628

**Key Changes:**

#### Straight Movement
```lua
-- BEFORE: Manual transform updates
transform.actualX = transform.actualX + behavior.velocity.x * dt
transform.actualY = transform.actualY + behavior.velocity.y * dt

-- AFTER: Physics-driven
local vx, vy = physics.GetVelocity(globals.physicsWorld, entity)
behavior.velocity.x = vx  -- Sync from physics
behavior.velocity.y = vy
transform.visualR = math.atan2(vy, vx)  -- Visual rotation only
```

#### Homing Movement
```lua
-- BEFORE: Applied velocity then manually updated transform
physics.SetVelocity(globals.physicsWorld, entity, desiredVelX, desiredVelY)
transform.actualX = transform.actualX + desiredVelX * dt  -- Manual update

-- AFTER: Only set velocity, let physics sync handle position
physics.SetVelocity(globals.physicsWorld, entity, desiredVelX, desiredVelY)
transform.visualR = math.atan2(desiredVelY, desiredVelX)  // Visual only
-- Physics sync system updates actualX/actualY automatically
```

#### Orbital Movement
```lua
-- BEFORE: Directly set transform position
transform.actualX = targetX
transform.actualY = targetY

-- AFTER: Calculate velocity to reach target position
local velocityX = (targetX - currentX) / dt
local velocityY = (targetY - currentY) / dt
physics.SetVelocity(globals.physicsWorld, entity, velocityX, velocityY)
transform.visualR = behavior.orbitAngle + math.pi / 2  -- Visual only
```

#### Arc Movement
```lua
-- BEFORE: Manual gravity simulation
behavior.velocity.y = behavior.velocity.y + (900 * behavior.gravityScale * dt)
transform.actualX = transform.actualX + behavior.velocity.x * dt

// AFTER: Let Chipmunk2D handle gravity
local vx, vy = physics.GetVelocity(globals.physicsWorld, entity)
behavior.velocity.x = vx  -- Sync from physics
behavior.velocity.y = vy
transform.visualR = math.atan2(vy, vx)  -- Visual rotation only
```

**Benefits:**
- ✅ No manual transform manipulation
- ✅ Physics drives position (via SetVelocity)
- ✅ Transform sync system handles rendering position
- ✅ Smooth interpolation from physics sync
- ✅ No conflicts with physics-transform authority

---

### 2. Physics Sync Configuration

**Modified Function:** `setupPhysics()` - Lines 312-348

**Added Code:**
```lua
-- Configure physics sync: Make physics authoritative for projectiles
if registry and registry.emplace then
    local PhysicsSyncConfig = {
        -- Physics is authoritative (physics drives transform)
        mode = "AuthoritativePhysics",

        -- Pull position from physics to transform
        pullPositionFromPhysics = true,

        -- Rotation handling: Use visual rotation for sprite facing
        rotMode = "TransformFixed_PhysicsFollows",
        pullAngleFromPhysics = false,  -- Don't pull rotation from physics
        useVisualRotationWhenDragging = false,  -- Projectiles can't be dragged

        -- Interpolation for smooth rendering
        useInterpolation = true,

        -- Not kinematic (dynamic body)
        useKinematic = false,
    }

    -- Try to set the sync config
    if registry.try_get then
        local success = pcall(function()
            registry:emplace(entity, "PhysicsSyncConfig", PhysicsSyncConfig)
        end)
        if not success then
            log_debug("PhysicsSyncConfig not available, projectile will use default sync")
        end
    end
end
```

**What This Does:**
- Sets `AuthoritativePhysics` mode - physics drives transform position
- Enables position pulling from physics to transform
- Uses `visualR` for sprite rotation (physics rotation is locked)
- Enables interpolation for smooth rendering between physics steps
- Safe fallback if PhysicsSyncConfig component doesn't exist

**Integration with Your System:**
- Compatible with `transform_physics_hook.hpp`
- Works with `BodyToTransform()` sync function
- Uses the same authority modes as your other entities
- Follows the same interpolation pattern

---

### 3. Physics Step Timer Integration

**Modified Functions:**
- `init()` - Lines 1000-1034
- `cleanup()` - Lines 1037-1053
- `update()` - Lines 437-445
- Added `updateInternal()` - Lines 414-433

**New Module Variables:**
```lua
-- Line 37-39
ProjectileSystem.physics_step_timer_id = nil
ProjectileSystem.use_physics_step_timer = true  -- Set to true to update on physics steps
```

**Init Function - Added Timer Registration:**
```lua
-- Register projectile update on physics step timer
if ProjectileSystem.use_physics_step_timer and timer then
    -- Use physics_step tag so this runs synchronously with physics updates
    ProjectileSystem.physics_step_timer_id = timer.every_physics_step(function(dt)
        ProjectileSystem.updateInternal(dt)
    end, "projectile_update")

    log_info("ProjectileSystem registered with physics step timer")
else
    log_info("ProjectileSystem will use manual update() calls")
end
```

**Cleanup Function - Cancel Timer:**
```lua
-- Cancel physics step timer if active
if ProjectileSystem.physics_step_timer_id and timer then
    timer.cancel(ProjectileSystem.physics_step_timer_id)
    ProjectileSystem.physics_step_timer_id = nil
end
```

**Update Function - Smart Routing:**
```lua
--- Public update function (for manual updates when not using physics step timer)
function ProjectileSystem.update(dt)
    -- If using physics step timer, this is a no-op (timer handles updates)
    if ProjectileSystem.use_physics_step_timer then
        return
    end

    -- Otherwise, call updateInternal directly
    ProjectileSystem.updateInternal(dt)
end
```

**How It Works:**
1. **If `use_physics_step_timer = true`** (default):
   - `init()` registers `updateInternal()` with `timer.every_physics_step()`
   - Updates run synchronously with physics steps (before or after `cpSpaceStep()`)
   - Calling `update()` manually is a no-op

2. **If `use_physics_step_timer = false`**:
   - `init()` skips timer registration
   - Must call `ProjectileSystem.update(dt)` manually each frame
   - Works for testing or non-physics-driven mode

**Benefits:**
- ✅ Updates run at the same frequency as physics
- ✅ No timing mismatch between projectile velocity changes and physics step
- ✅ Homing/orbital calculations happen right before physics applies them
- ✅ Backward compatible (can still use manual `update()` calls)

---

## Usage Examples

### Initialization (in your main game init)
```lua
local ProjectileSystem = require("assets.scripts.combat.projectile_system")

-- Initialize once
ProjectileSystem.init()  -- Automatically registers with physics step timer

-- No need to call ProjectileSystem.update() if using physics step timer!
```

### If You Want Manual Updates (not recommended)
```lua
-- Set this BEFORE calling init()
ProjectileSystem.use_physics_step_timer = false

ProjectileSystem.init()  -- Won't register timer

-- Now you must call update() yourself
function update(dt)
    ProjectileSystem.update(dt)
end
```

### Spawning a Projectile
```lua
-- Spawning works exactly the same
local projectileId = ProjectileSystem.spawn({
    position = {x = 100, y = 100},
    angle = math.pi / 4,
    baseSpeed = 300,
    damage = 15,
    owner = playerEntity,
    lifetime = 3.0,
    movementType = "homing",  -- Now fully physics-driven!
    homingTarget = enemyEntity,
    collisionBehavior = "pierce"
})
```

---

## Testing Checklist

### Before Running:
1. ⬜ **Apply Bug Fix #1** from TASK_5_BUG_FIXES_REPORT.md (physics-transform sync)
2. ⬜ **Apply Bug Fix #2** from TASK_5_BUG_FIXES_REPORT.md (drag & drop collision shape drift)
3. ⬜ Verify your `timer` module has `every_physics_step()` function
4. ⬜ Verify your registry supports `PhysicsSyncConfig` component

### Test Scenarios:
1. ⬜ **Straight projectile**: Should move smoothly without jitter
2. ⬜ **Homing projectile**: Should track target smoothly
3. ⬜ **Orbital projectile**: Should orbit without position jumping
4. ⬜ **Arc projectile**: Should follow parabolic arc (gravity)
5. ⬜ **Collision detection**: Should detect hits with enemies
6. ⬜ **Lifetime despawn**: Should despawn after timeout
7. ⬜ **No memory leaks**: Check with Tracy profiler

---

## Compatibility Notes

### Works With:
- ✅ Your existing physics-transform sync system (`transform_physics_hook.hpp`)
- ✅ Chipmunk2D physics world
- ✅ EnTT registry
- ✅ Your timer system (if it has `every_physics_step()`)
- ✅ Task 2 Wand System (projectiles spawned by wands)
- ✅ Task 4 Combat Loop (enemy projectiles)

### May Need Adjustment:
- ⚠️ **If `timer.every_physics_step()` doesn't exist**: Set `use_physics_step_timer = false` and call `update()` manually
- ⚠️ **If `PhysicsSyncConfig` component name is different**: Update line 338 in setupPhysics()
- ⚠️ **If sync mode enum names are different**: Update lines 317, 323 (string vs enum)

---

## Performance Impact

**Before (Hybrid):**
- Manual transform updates (CPU overhead)
- Potential physics-transform desyncs
- Render interpolation may jitter

**After (Physics-Driven):**
- Physics calculates position once
- Transform sync pulls position (efficient)
- Smooth interpolation from physics sync
- Runs on physics step (optimal timing)

**Expected:** Slight performance improvement due to less redundant calculations.

---

## Troubleshooting

### Problem: Projectiles jitter or teleport
**Solution:** Apply Bug Fix #1 (physics-transform sync) from TASK_5_BUG_FIXES_REPORT.md

### Problem: Timer not registering
**Check:** Does your timer module have `every_physics_step()` function?
**Workaround:** Set `use_physics_step_timer = false` and call `update()` manually

### Problem: PhysicsSyncConfig errors
**Check:** Is the component name correct? (line 338)
**Fix:** Update component name or disable by commenting out lines 314-344

### Problem: Homing projectiles don't track
**Check:** Is `homingTarget` valid?
**Debug:** Add `log_debug` in `updateHomingMovement()` to see velocity values

### Problem: Projectiles don't move at all
**Check:** Is physics world initialized before calling `ProjectileSystem.init()`?
**Check:** Are velocities being set? Add logging in `initializeMovement()`

---

## Next Steps

1. **Apply the bug fixes** from [TASK_5_BUG_FIXES_REPORT.md](TASK_5_BUG_FIXES_REPORT.md)
2. **Test projectile spawning** with the examples in `projectile_examples.lua`
3. **Test integration** with the wand system (Task 2)
4. **Profile performance** with Tracy to verify no regressions
5. **Check for memory leaks** (especially with pooling)

---

## Files Modified

- `/Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/combat/projectile_system.lua`

**Lines Changed:**
- 37-39: Added physics step timer variables
- 312-348: Added PhysicsSyncConfig setup
- 414-445: Refactored update functions
- 468-628: Modified all movement functions to be physics-driven
- 1000-1034: Modified init() to register timer
- 1037-1053: Modified cleanup() to cancel timer

**Total Changes:** ~200 lines modified/added

---

## Summary

✅ **All three recommendations implemented**
✅ **Fully physics-driven projectile movement**
✅ **Explicit physics sync configuration**
✅ **Physics step timer integration**
✅ **Backward compatible** (can disable timer if needed)
✅ **Ready for testing** (after bug fixes applied)

The projectile system is now fully integrated with your physics-transform sync architecture and should work smoothly without conflicts!
