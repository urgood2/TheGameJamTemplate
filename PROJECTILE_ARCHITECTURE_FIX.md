# Projectile System Architecture Fix

## What Was Fixed

The projectile system was using an incorrect data storage pattern that didn't match the game engine's architecture.

## Changes Made

### 1. Added Required Libraries
```lua
local signal = require("external.hump.signal")
local Node = require("monobehavior.behavior_script_v2")
```

### 2. Initialize Script Table on Entity Creation

**Critical Addition:**
```lua
-- Initialize script table for this entity (required for getScriptTableFromEntityID)
local ProjectileType = Node:extend()
local projectileScript = ProjectileType {}
projectileScript:attach_ecs { create_new = false, existing_entity = entity }
```

This step is **essential** - without it, `getScriptTableFromEntityID()` returns `nil`!

### 3. Fixed Data Storage Pattern

**BEFORE (Wrong):**
```lua
-- Storing in GameObject component directly
if not registry:has(entity, GameObject) then
    registry:emplace(entity, GameObject)
end
local gameObj = component_cache.get(entity, GameObject)
gameObj.projectileData = projectileData
gameObj.projectileBehavior = projectileBehavior
gameObj.projectileLifetime = projectileLifetime
```

**AFTER (Correct):**
```lua
-- Using script table pattern
local projectileScript = getScriptTableFromEntityID(entity)
projectileScript.projectileData = projectileData
projectileScript.projectileBehavior = projectileBehavior
projectileScript.projectileLifetime = projectileLifetime
```

### 4. Replaced Event Publishing

**BEFORE (Wrong):**
```lua
publishLuaEvent("projectile_spawned", {
    entity = entity,
    owner = params.owner,
    position = params.position,
    projectileType = params.projectileType or "default"
})
```

**AFTER (Correct):**
```lua
signal.emit("projectile_spawned", entity, {
    owner = params.owner,
    position = params.position,
    projectileType = params.projectileType or "default"
})
```

## Functions Updated

All references to `gameObj.projectileData`, `gameObj.projectileBehavior`, and `gameObj.projectileLifetime` were replaced with the script table pattern:

1. ✅ `ProjectileSystem.spawn()` - Lines 224-228
2. ✅ `ProjectileSystem.initializeMovement()` - Lines 351-353
3. ✅ `ProjectileSystem.updateProjectile()` - Lines 445-451
4. ✅ `ProjectileSystem.handleCollision()` - Lines 712-722
5. ✅ `ProjectileSystem.handleBounce()` - Lines 819-826
6. ✅ `ProjectileSystem.destroy()` - Lines 873-889
7. ✅ `ProjectileSystem.returnToPool()` - Lines 912-919

## Events Updated

All `publishLuaEvent()` calls replaced with `signal.emit()`:

1. ✅ `projectile_spawned` - Line 248
2. ✅ `projectile_hit` - Line 742
3. ✅ `projectile_exploded` - Line 841
4. ✅ `projectile_destroyed` - Line 887

## Why This Matters

### Correct Architecture
- Uses `getScriptTableFromEntityID()` which is the proper way to attach Lua data to entities
- Matches the pattern used throughout the codebase (see [gameplay.lua](assets/scripts/core/gameplay.lua))
- GameObject component already exists on entities - we don't need to emplace it

### Event System
- Uses the signal library (`external.hump.signal`) which is the standard event system
- Follows the pattern: `signal.emit(eventName, entity, data)`
- Matches event handling in [gameplay.lua:3569-3622](assets/scripts/core/gameplay.lua#L3569-L3622)

## Next Steps

1. ✅ Build successfully compiles
2. **Test projectile visibility** - The visibility issue may now be resolved since we're using the correct data storage
3. **Test projectile lifecycle** - Verify spawn → update → destroy works correctly
4. **Test event system** - Ensure signals are emitted and can be received by wand system

## Files Modified

- [assets/scripts/combat/projectile_system.lua](assets/scripts/combat/projectile_system.lua) - Complete refactor of data storage pattern
