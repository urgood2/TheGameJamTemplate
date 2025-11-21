# Testing Plan - Completed Systems

**Date:** 2025-11-20
**Systems to Test:** Projectile System, Wand Execution Engine, Combat Loop Framework, Bug Fixes

---

## 🎯 Overview

We need to test 4 major completed systems:
1. ✅ **Projectile System** (Task 1) - Physics-driven projectile spawning
2. ✅ **Wand Execution Engine** (Task 2) - Trigger/action/modifier pipeline
3. ✅ **Combat Loop Framework** (Task 4) - Enemy spawning, waves, loot
4. ✅ **Bug Fixes** (#7, #10) - Background translucency, entity filtering

---

## 🔧 Pre-Test Setup

### 1. Compile the Project
```bash
cd /Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate

# Rebuild (make sure bug fixes are compiled in)
cmake --build build --config Debug
```

### 2. Check for Compilation Errors
**Expected issues:**
- ⚠️ `timer.every_physics_step()` may not exist yet
- ⚠️ `PhysicsSyncConfig` component may have different name
- ⚠️ Lua syntax errors if module paths are wrong

**If you get errors, note them and we'll fix them together.**

---

## 📊 Test 1: Projectile System (Task 1)

### Test 1A: Can We Load the Module?

**Create a test file:** `assets/scripts/test_projectiles.lua`

```lua
-- Test: Load the projectile system module
print("\n========== PROJECTILE SYSTEM TEST ==========")

local ProjectileSystem = require("assets.scripts.combat.projectile_system")

if ProjectileSystem then
    print("[✓] ProjectileSystem module loaded successfully")
else
    print("[✗] Failed to load ProjectileSystem module")
    return
end

-- Initialize
ProjectileSystem.init()
print("[✓] ProjectileSystem initialized")
```

**Run this in your game's init function temporarily:**
```lua
-- In your main.lua or game init:
require("assets.scripts.test_projectiles")
```

**Expected Output:**
```
========== PROJECTILE SYSTEM TEST ==========
[✓] ProjectileSystem module loaded successfully
[✓] ProjectileSystem initialized
```

---

### Test 1B: Spawn a Basic Projectile

**Add to test file:**
```lua
-- Test: Spawn a basic projectile
local timer = require("core.timer")

-- Wait a bit for physics world to initialize
timer.after(0.5, function()
    print("\n[TEST] Spawning basic projectile...")

    local projectileId = ProjectileSystem.spawn({
        position = {x = 400, y = 300},
        angle = 0,  -- Shoot right
        baseSpeed = 300,
        damage = 10,
        owner = nil,
        lifetime = 3.0,
        movementType = "straight",
        collisionBehavior = "destroy",
        size = 16
    })

    if projectileId and entity_cache.valid(projectileId) then
        print("[✓] Projectile spawned successfully! Entity ID:", projectileId)
    else
        print("[✗] Failed to spawn projectile")
    end
end)
```

**What to Look For:**
- ✅ Console message: `[✓] Projectile spawned successfully!`
- ✅ A projectile appears on screen and moves right
- ✅ Projectile disappears after 3 seconds
- ❌ If nothing appears, projectile might be off-screen or rendering is broken

---

### Test 1C: Test Different Movement Types

**Add to test file:**
```lua
-- Test homing projectile (needs a target)
timer.after(1.0, function()
    print("\n[TEST] Testing homing projectile...")

    -- First, create a dummy target entity
    local targetEntity = registry:create()
    local targetTransform = component_cache.get(targetEntity, Transform)
    targetTransform.actualX = 600
    targetTransform.actualY = 300
    targetTransform.actualW = 32
    targetTransform.actualH = 32

    -- Spawn homing projectile
    local homingProj = ProjectileSystem.spawn({
        position = {x = 200, y = 300},
        baseSpeed = 200,
        damage = 15,
        lifetime = 5.0,
        movementType = "homing",
        homingTarget = targetEntity,
        homingStrength = 2.0,
        homingMaxSpeed = 400,
        collisionBehavior = "destroy"
    })

    if homingProj then
        print("[✓] Homing projectile spawned")
    end
end)

-- Test arc (gravity) projectile
timer.after(2.0, function()
    print("\n[TEST] Testing arc projectile...")

    local arcProj = ProjectileSystem.spawn({
        position = {x = 300, y = 200},
        angle = math.pi / 4,  -- 45 degrees up
        baseSpeed = 400,
        damage = 20,
        lifetime = 5.0,
        movementType = "arc",
        gravityScale = 1.0,
        collisionBehavior = "destroy"
    })

    if arcProj then
        print("[✓] Arc projectile spawned")
    end
end)
```

**What to Look For:**
- ✅ Homing projectile curves toward target
- ✅ Arc projectile follows parabolic path (affected by gravity)
- ❌ If projectiles jitter or teleport → Bug #1 (physics sync) needs fixing

---

### Test 1D: Physics Step Timer

**Check console output:**
```
ProjectileSystem registered with physics step timer
```

**If you see:**
```
ProjectileSystem will use manual update() calls
```

**Then:** Your timer doesn't have `every_physics_step()` yet. That's OK, but you need to call `ProjectileSystem.update(dt)` in your main loop.

**Add to your main update function:**
```lua
function update(dt)
    -- ... existing code ...

    -- If not using physics step timer, call this:
    ProjectileSystem.update(dt)
end
```

---

## 📊 Test 2: Wand Execution Engine (Task 2)

### Test 2A: Load Wand System

**Create test file:** `assets/scripts/test_wand.lua`

```lua
print("\n========== WAND EXECUTION TEST ==========")

local WandExecutor = require("assets.scripts.wand.wand_executor")
local WandTests = require("assets.scripts.wand.wand_test_examples")

if WandExecutor and WandTests then
    print("[✓] Wand system modules loaded")
else
    print("[✗] Failed to load wand system modules")
    return
end

-- Initialize
WandExecutor.init()
print("[✓] WandExecutor initialized")
```

---

### Test 2B: Run Example Wands

**Add to test file:**
```lua
-- Test 1: Basic Fire Bolt
print("\n[TEST 1] Running Basic Fire Bolt example...")
local wand1 = WandTests.example1_BasicFireBolt()

-- Test 2: Piercing Ice Shard
print("\n[TEST 2] Running Piercing Ice Shard example...")
local wand2 = WandTests.example2_PiercingIceShard()

-- Test 3: Triple Shot
print("\n[TEST 3] Running Triple Shot example...")
local wand3 = WandTests.example3_TripleShot()
```

**What to Look For:**
- ✅ Console shows: `Loaded [wand name] wand`
- ✅ After 1 second, projectiles spawn automatically (timer trigger)
- ✅ Multiple projectiles spawn for triple shot
- ❌ If no projectiles spawn → Check if ProjectileSystem is initialized

---

### Test 2C: Manual Wand Execution

**Add to test file:**
```lua
-- Test manual wand firing
timer.after(5.0, function()
    print("\n[TEST] Manually executing wand...")

    if wand1 then
        WandExecutor.execute(wand1)
        print("[✓] Wand executed manually")
    end
end)
```

**What to Look For:**
- ✅ Projectile spawns when you manually call execute
- ✅ Cooldown prevents rapid firing

---

## 📊 Test 3: Combat Loop Framework (Task 4)

### Test 3A: Load Combat Loop

**Create test file:** `assets/scripts/test_combat_loop.lua`

```lua
print("\n========== COMBAT LOOP TEST ==========")

local CombatLoopTest = require("assets.scripts.combat.combat_loop_test")

if CombatLoopTest then
    print("[✓] Combat loop test module loaded")
else
    print("[✗] Failed to load combat loop test module")
    return
end

-- Initialize the test scenario
CombatLoopTest.initialize()
print("[✓] Combat loop test initialized")
```

---

### Test 3B: Run Test Scenario

**Add to test file:**
```lua
-- The test has keyboard controls:
-- T = Start/stop combat
-- R = Reset
-- K = Kill all enemies

print("\nControls:")
print("  [T] = Start/Stop combat")
print("  [R] = Reset")
print("  [K] = Kill all enemies")

-- Auto-start after 2 seconds
timer.after(2.0, function()
    print("\n[TEST] Auto-starting combat...")
    -- Call the start function if available
    if CombatLoopTest.start then
        CombatLoopTest.start()
    end
end)
```

**What to Look For:**
- ✅ Enemies spawn in wave 1
- ✅ Wave counter shows "Wave 1"
- ✅ Enemies have health bars
- ✅ When enemies die, loot drops
- ✅ Wave 2 starts after wave 1 complete
- ❌ If enemies don't spawn → Check entity factory function exists

---

### Test 3C: Check State Machine

**Add to test file:**
```lua
-- Monitor state changes
timer.every(1.0, function()
    -- Log current combat state
    if CombatLoopTest.getCombatState then
        local state = CombatLoopTest.getCombatState()
        print("[STATE]", state)
    end
end)
```

**Expected State Flow:**
```
[STATE] INIT
[STATE] WAVE_START
[STATE] SPAWNING
[STATE] COMBAT
[STATE] VICTORY
[STATE] INTERMISSION
[STATE] WAVE_START  (Wave 2)
```

---

## 📊 Test 4: Bug Fixes

### Test 4A: Bug Fix #7 (Background Translucency)

**Visual Test:**
1. Launch the game
2. Look at the background
3. Move around, spawn entities

**What to Look For:**
- ✅ Background is solid, opaque
- ✅ No flickering or fading to transparency
- ❌ If background is translucent → Bug fix didn't compile in

---

### Test 4B: Bug Fix #10 (Entity Filtering)

**Test with projectiles:**
```lua
-- Spawn 10 projectiles without state tags
for i = 1, 10 do
    timer.after(i * 0.2, function()
        ProjectileSystem.spawn({
            position = {x = 100 + i * 50, y = 300},
            angle = 0,
            baseSpeed = 200,
            lifetime = 10.0,
            movementType = "straight"
        })
    end)
end
```

**What to Look For:**
- ✅ All 10 projectiles are visible
- ✅ Camera follows player
- ❌ If projectiles are invisible → Bug fix didn't work or entities need StateTag

---

## 🐛 Common Issues & Solutions

### Issue 1: "timer.every_physics_step() doesn't exist"

**Solution:**
```lua
-- In projectile_system.lua, change line 39:
ProjectileSystem.use_physics_step_timer = false

-- Then call update manually:
function mainUpdate(dt)
    ProjectileSystem.update(dt)
end
```

---

### Issue 2: "PhysicsSyncConfig not found"

**Solution:**
The projectile system has a safe fallback. Check console for:
```
PhysicsSyncConfig not available, projectile will use default sync
```

This is OK for now. Projectiles will still work but may not have optimal sync.

---

### Issue 3: "Projectiles spawn but don't move"

**Check:**
1. Is physics world initialized? (`globals.physicsWorld`)
2. Are velocities being set? Add logging in `initializeMovement()`
3. Is `ProjectileSystem.update()` being called?

---

### Issue 4: "Module not found" errors

**Solution:**
Check module paths. You might need:
```lua
-- Try different paths:
local ProjectileSystem = require("assets/scripts/combat/projectile_system")
-- vs
local ProjectileSystem = require("scripts.combat.projectile_system")
-- vs
local ProjectileSystem = require("combat.projectile_system")
```

---

### Issue 5: "Enemies don't spawn"

**Check:**
1. Does `create_ai_entity(type)` function exist?
2. Is entity factory initialized?
3. Check console for error messages

**Workaround:**
```lua
-- In combat_loop_test.lua, provide a dummy entity factory:
local function dummyEntityFactory(type)
    local e = registry:create()
    -- Add transform, sprite, etc.
    return e
end
```

---

## 📝 Test Results Template

Copy this and fill it out as you test:

```
========== TEST RESULTS ==========

## Projectile System
[ ] Module loads without errors
[ ] Projectiles spawn and are visible
[ ] Straight movement works
[ ] Homing movement works
[ ] Arc (gravity) movement works
[ ] Projectiles despawn after lifetime
[ ] Physics step timer registered (or manual update works)

Issues Found:
-

## Wand Execution Engine
[ ] Module loads without errors
[ ] Example wands load
[ ] Timer triggers fire
[ ] Projectiles spawn from wands
[ ] Modifiers apply correctly (speed, damage, etc.)
[ ] Multicast works (multiple projectiles)

Issues Found:
-

## Combat Loop Framework
[ ] Module loads without errors
[ ] Test scenario initializes
[ ] Enemies spawn in waves
[ ] Wave progression works
[ ] Loot drops on enemy death
[ ] State machine transitions correctly

Issues Found:
-

## Bug Fixes
[ ] Background is opaque (not translucent)
[ ] Entities without StateTag render
[ ] Camera follows player
[ ] Projectiles are visible

Issues Found:
-

## Overall System Integration
[ ] No crashes
[ ] No memory leaks (check with profiler if available)
[ ] Frame rate is acceptable
[ ] Systems work together

Issues Found:
-
```

---

## 🚀 Next Steps After Testing

Based on what we find:

1. **If everything works:** 🎉 Celebrate! Then move to Task 3 (Card Integration)
2. **If minor issues:** Fix them together
3. **If major issues:** Debug and resolve before continuing
4. **If module loading fails:** Adjust paths and dependencies

---

## 💡 Tips

- **Start simple:** Test one system at a time
- **Check console:** Most errors will show up there
- **Add logging:** Put `print()` statements everywhere
- **Comment out code:** If something breaks, isolate it
- **Ask for help:** Share error messages and I'll help debug

---

Ready to start testing? Let me know when you've compiled and I'll help you run through these tests!
