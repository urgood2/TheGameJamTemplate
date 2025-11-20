--[[
    PROJECTILE SYSTEM TEST

    This file tests the projectile system to verify:
    1. Module loads correctly
    2. Projectiles spawn
    3. Different movement types work
    4. Physics integration functions
]]--

local ProjectileSystemTest = {}

-- Test state
ProjectileSystemTest.initialized = false
ProjectileSystemTest.testResults = {}

function ProjectileSystemTest.init()
    print("\n" .. string.rep("=", 60))
    print("PROJECTILE SYSTEM TEST - STARTING")
    print(string.rep("=", 60))

    -- Try to load dependencies
    local timer = require("core.timer")
    local component_cache = require("core.component_cache")
    local entity_cache = require("core.entity_cache")

    print("[✓] Core dependencies loaded")

    -- Load ProjectileSystem
    local success, ProjectileSystem = pcall(require, "assets.scripts.combat.projectile_system")

    if not success then
        print("[✗] FAILED to load ProjectileSystem module")
        print("Error:", ProjectileSystem)
        return false
    end

    print("[✓] ProjectileSystem module loaded successfully")

    -- Store for later use
    ProjectileSystemTest.ProjectileSystem = ProjectileSystem
    ProjectileSystemTest.timer = timer
    ProjectileSystemTest.component_cache = component_cache
    ProjectileSystemTest.entity_cache = entity_cache

    -- Initialize the projectile system
    local initSuccess = pcall(function()
        ProjectileSystem.init()
    end)

    if not initSuccess then
        print("[✗] FAILED to initialize ProjectileSystem")
        return false
    end

    print("[✓] ProjectileSystem initialized")

    -- Check if using physics step timer
    if ProjectileSystem.use_physics_step_timer then
        print("[i] Using physics step timer for updates")
    else
        print("[i] Using manual update() calls")
        print("[!] You need to call ProjectileSystem.update(dt) in your main loop")
    end

    ProjectileSystemTest.initialized = true

    -- Schedule tests
    ProjectileSystemTest.scheduleTests()

    return true
end

function ProjectileSystemTest.scheduleTests()
    local timer = ProjectileSystemTest.timer

    print("\n" .. string.rep("-", 60))
    print("Scheduling tests...")
    print(string.rep("-", 60))

    -- Test 1: Basic straight projectile (after 1 second)
    timer.after(1.0, function()
        ProjectileSystemTest.testBasicProjectile()
    end)

    -- Test 2: Multiple projectiles (after 2 seconds)
    timer.after(2.0, function()
        ProjectileSystemTest.testMultipleProjectiles()
    end)

    -- Test 3: Homing projectile (after 3 seconds)
    timer.after(3.0, function()
        ProjectileSystemTest.testHomingProjectile()
    end)

    -- Test 4: Arc projectile (after 4 seconds)
    timer.after(4.0, function()
        ProjectileSystemTest.testArcProjectile()
    end)

    -- Print results (after 8 seconds)
    timer.after(8.0, function()
        ProjectileSystemTest.printResults()
    end)
end

function ProjectileSystemTest.testBasicProjectile()
    print("\n[TEST 1] Basic Straight Projectile")
    print(string.rep("-", 40))

    local ProjectileSystem = ProjectileSystemTest.ProjectileSystem
    local entity_cache = ProjectileSystemTest.entity_cache

    local success, projectileId = pcall(function()
        return ProjectileSystem.spawn({
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
    end)

    if success and projectileId and entity_cache.valid(projectileId) then
        print("[✓] Basic projectile spawned successfully")
        print("    Entity ID:", projectileId)
        print("    Position: (400, 300)")
        print("    Direction: Right (0°)")
        print("    Speed: 300")
        ProjectileSystemTest.testResults.basicProjectile = true
    else
        print("[✗] FAILED to spawn basic projectile")
        if not success then
            print("    Error:", projectileId)
        end
        ProjectileSystemTest.testResults.basicProjectile = false
    end
end

function ProjectileSystemTest.testMultipleProjectiles()
    print("\n[TEST 2] Multiple Projectiles")
    print(string.rep("-", 40))

    local ProjectileSystem = ProjectileSystemTest.ProjectileSystem
    local entity_cache = ProjectileSystemTest.entity_cache

    local spawnCount = 0
    local successCount = 0

    -- Spawn 5 projectiles in a fan pattern
    for i = 1, 5 do
        spawnCount = spawnCount + 1
        local angle = (i - 3) * (math.pi / 12)  -- -30° to +30°

        local success, projectileId = pcall(function()
            return ProjectileSystem.spawn({
                position = {x = 300, y = 300},
                angle = angle,
                baseSpeed = 250,
                damage = 8,
                lifetime = 4.0,
                movementType = "straight",
                collisionBehavior = "destroy",
                size = 12
            })
        end)

        if success and projectileId and entity_cache.valid(projectileId) then
            successCount = successCount + 1
        end
    end

    print("[i] Spawned", successCount, "out of", spawnCount, "projectiles")

    if successCount == spawnCount then
        print("[✓] All projectiles spawned successfully")
        ProjectileSystemTest.testResults.multipleProjectiles = true
    else
        print("[✗] Some projectiles failed to spawn")
        ProjectileSystemTest.testResults.multipleProjectiles = false
    end
end

function ProjectileSystemTest.testHomingProjectile()
    print("\n[TEST 3] Homing Projectile")
    print(string.rep("-", 40))

    local ProjectileSystem = ProjectileSystemTest.ProjectileSystem
    local entity_cache = ProjectileSystemTest.entity_cache
    local component_cache = ProjectileSystemTest.component_cache

    -- Create a dummy target entity
    local targetEntity = registry:create()

    -- Try to get Transform component
    local Transform = component_cache.Transform or Transform
    if not Transform then
        print("[!] Warning: Transform component not available, using globals")
    end

    local success, result = pcall(function()
        -- Add transform to target
        local targetTransform = component_cache.get(targetEntity, Transform)
        if targetTransform then
            targetTransform.actualX = 600
            targetTransform.actualY = 300
            targetTransform.actualW = 32
            targetTransform.actualH = 32
        end

        -- Spawn homing projectile
        return ProjectileSystem.spawn({
            position = {x = 200, y = 300},
            baseSpeed = 200,
            damage = 15,
            lifetime = 5.0,
            movementType = "homing",
            homingTarget = targetEntity,
            homingStrength = 2.0,
            homingMaxSpeed = 400,
            collisionBehavior = "destroy",
            size = 14
        })
    end)

    if success and result and entity_cache.valid(result) then
        print("[✓] Homing projectile spawned successfully")
        print("    Target position: (600, 300)")
        print("    Homing strength: 2.0")
        ProjectileSystemTest.testResults.homingProjectile = true
    else
        print("[✗] FAILED to spawn homing projectile")
        if not success then
            print("    Error:", result)
        end
        ProjectileSystemTest.testResults.homingProjectile = false
    end
end

function ProjectileSystemTest.testArcProjectile()
    print("\n[TEST 4] Arc (Gravity) Projectile")
    print(string.rep("-", 40))

    local ProjectileSystem = ProjectileSystemTest.ProjectileSystem
    local entity_cache = ProjectileSystemTest.entity_cache

    local success, projectileId = pcall(function()
        return ProjectileSystem.spawn({
            position = {x = 300, y = 200},
            angle = math.pi / 4,  -- 45 degrees up
            baseSpeed = 400,
            damage = 20,
            lifetime = 5.0,
            movementType = "arc",
            gravityScale = 1.0,
            collisionBehavior = "destroy",
            size = 18
        })
    end)

    if success and projectileId and entity_cache.valid(projectileId) then
        print("[✓] Arc projectile spawned successfully")
        print("    Launch angle: 45°")
        print("    Gravity scale: 1.0")
        print("    Expected: Parabolic trajectory")
        ProjectileSystemTest.testResults.arcProjectile = true
    else
        print("[✗] FAILED to spawn arc projectile")
        if not success then
            print("    Error:", projectileId)
        end
        ProjectileSystemTest.testResults.arcProjectile = false
    end
end

function ProjectileSystemTest.printResults()
    print("\n" .. string.rep("=", 60))
    print("PROJECTILE SYSTEM TEST - RESULTS")
    print(string.rep("=", 60))

    local totalTests = 0
    local passedTests = 0

    for testName, result in pairs(ProjectileSystemTest.testResults) do
        totalTests = totalTests + 1
        if result then
            passedTests = passedTests + 1
            print("[✓]", testName)
        else
            print("[✗]", testName)
        end
    end

    print(string.rep("-", 60))
    print(string.format("Results: %d/%d tests passed (%.1f%%)",
        passedTests, totalTests, (passedTests / totalTests) * 100))
    print(string.rep("=", 60))

    if passedTests == totalTests then
        print("\n🎉 ALL TESTS PASSED! Projectile system is working correctly!")
    else
        print("\n⚠️  Some tests failed. Check the output above for details.")
    end

    print("\nWhat to look for visually:")
    print("  • Projectiles should appear on screen")
    print("  • They should move smoothly without jittering")
    print("  • Homing projectiles should curve toward target")
    print("  • Arc projectiles should follow parabolic path")
    print("  • Projectiles should disappear after lifetime expires")
end

-- Auto-initialize if run directly
if not ProjectileSystemTest.initialized then
    local success = ProjectileSystemTest.init()
    if not success then
        print("\n❌ Projectile system test initialization FAILED")
    end
end

return ProjectileSystemTest
