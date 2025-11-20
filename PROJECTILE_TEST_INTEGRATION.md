# How to Run the Projectile System Test

## Quick Start

I've created **[test_projectiles.lua](assets/scripts/test_projectiles.lua)** which will test the projectile system automatically.

---

## Method 1: Add to Your Main Game Init (Recommended)

### Step 1: Open your main.lua file

Open: `/Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/core/main.lua`

### Step 2: Add the test to initMainGame()

Find the `initMainGame()` function (around line 386) and add this **at the very end**:

```lua
function initMainGame()
    -- ... your existing initialization code ...

    -- ADD THIS AT THE END:
    print("\n[INIT] Running Projectile System Test...")
    local ProjectileTest = require("assets.scripts.test_projectiles")
    -- Test will run automatically
end
```

### Step 3: Run your game

```bash
./build/YourExecutable
```

### Step 4: Watch the console

You should see output like this:

```
============================================================
PROJECTILE SYSTEM TEST - STARTING
============================================================
[✓] Core dependencies loaded
[✓] ProjectileSystem module loaded successfully
[✓] ProjectileSystem initialized
[i] Using physics step timer for updates
------------------------------------------------------------
Scheduling tests...
------------------------------------------------------------

[TEST 1] Basic Straight Projectile
----------------------------------------
[✓] Basic projectile spawned successfully
    Entity ID: 12345
    Position: (400, 300)
    Direction: Right (0°)
    Speed: 300

[TEST 2] Multiple Projectiles
----------------------------------------
[i] Spawned 5 out of 5 projectiles
[✓] All projectiles spawned successfully

[TEST 3] Homing Projectile
----------------------------------------
[✓] Homing projectile spawned successfully
    Target position: (600, 300)
    Homing strength: 2.0

[TEST 4] Arc (Gravity) Projectile
----------------------------------------
[✓] Arc projectile spawned successfully
    Launch angle: 45°
    Gravity scale: 1.0
    Expected: Parabolic trajectory

============================================================
PROJECTILE SYSTEM TEST - RESULTS
============================================================
[✓] basicProjectile
[✓] multipleProjectiles
[✓] homingProjectile
[✓] arcProjectile
------------------------------------------------------------
Results: 4/4 tests passed (100.0%)
============================================================

🎉 ALL TESTS PASSED! Projectile system is working correctly!
```

---

## Method 2: Create a Separate Test Scene (Alternative)

If you don't want to add it to your main game:

### Step 1: Create a test scene

Create: `assets/scripts/test_scene.lua`

```lua
local TestScene = {}

function TestScene.init()
    print("Loading test scene...")

    -- Run projectile test
    local ProjectileTest = require("assets.scripts.test_projectiles")
end

function TestScene.update(dt)
    -- Update projectile system if not using physics step timer
    local ProjectileSystem = require("assets.scripts.combat.projectile_system")
    if not ProjectileSystem.use_physics_step_timer then
        ProjectileSystem.update(dt)
    end
end

return TestScene
```

### Step 2: Load it from main

```lua
-- In main.lua
function initMainGame()
    -- ... existing code ...

    -- Load test scene
    local TestScene = require("assets.scripts.test_scene")
    TestScene.init()
end
```

---

## What to Look For

### ✅ Console Output

**Success indicators:**
- `[✓] ProjectileSystem module loaded successfully`
- `[✓] ProjectileSystem initialized`
- `[✓] Basic projectile spawned successfully`
- `4/4 tests passed (100.0%)`

**Failure indicators:**
- `[✗] FAILED to load ProjectileSystem module`
- `[✗] FAILED to spawn projectile`
- Any Lua error messages

### ✅ Visual Indicators

**You should see on screen:**

1. **Test 1 (1 second in):** A projectile appears at center-right and moves to the right
   - Should move smoothly without jittering
   - Should disappear after 3 seconds

2. **Test 2 (2 seconds in):** 5 projectiles fan out in a spread pattern
   - Should all be visible
   - Should move in slightly different directions

3. **Test 3 (3 seconds in):** A projectile starts on the left and curves toward a target point
   - Should curve smoothly (not jump)
   - Demonstrates homing behavior

4. **Test 4 (4 seconds in):** A projectile launches upward at 45° and follows a parabolic arc
   - Should arc downward due to gravity
   - Demonstrates physics integration

### ❌ If Projectiles Are Invisible

**Check:**
1. Are projectiles rendering? (Check z-order, layer visibility)
2. Are sprites attached to projectiles?
3. Is the camera positioned correctly?

**To debug:** Add this to see projectile positions:
```lua
-- In main update loop:
for entity, _ in pairs(ProjectileSystem.active_projectiles) do
    local transform = component_cache.get(entity, Transform)
    if transform then
        print("Projectile at:", transform.actualX, transform.actualY)
    end
end
```

---

## Common Issues

### Issue 1: "module not found"

**Error:** `module 'assets.scripts.combat.projectile_system' not found`

**Solution:** Try different paths:
```lua
-- Try one of these:
require("assets.scripts.combat.projectile_system")
require("scripts.combat.projectile_system")
require("combat.projectile_system")
```

### Issue 2: "timer.every_physics_step() doesn't exist"

**Console shows:** `[i] Using manual update() calls`

**Solution:** Add to your main update loop:
```lua
function update(dt)
    -- ... existing code ...

    local ProjectileSystem = require("assets.scripts.combat.projectile_system")
    ProjectileSystem.update(dt)
end
```

### Issue 3: "physics not available"

**Console shows:** `Physics world not available, projectile will not have collision`

**Solution:** Make sure physics is initialized before projectile system:
```lua
-- In initMainGame(), before loading projectiles:
if not globals.physicsWorld then
    print("[!] Warning: Physics world not initialized yet!")
end
```

### Issue 4: Projectiles spawn but don't move

**Debug steps:**
1. Check if `update()` is being called
2. Add logging to movement functions
3. Verify physics velocities are being set

---

## Disable the Test

Once testing is complete, simply comment out or remove the line:

```lua
-- local ProjectileTest = require("assets.scripts.test_projectiles")
```

---

## Next Steps

Once the projectile test passes:
1. Test the Wand System (depends on projectiles)
2. Test the Combat Loop (uses projectiles for enemy attacks)
3. Integrate with your card UI

---

Ready to test? Add the require line to your `initMainGame()` and run the game!
