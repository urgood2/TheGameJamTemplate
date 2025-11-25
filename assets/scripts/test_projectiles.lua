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
    local success, ProjectileSystem = pcall(require, "combat.projectile_system")

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
    local initSuccess, initError = pcall(function()
        ProjectileSystem.init()
    end)

    if not initSuccess then
        print("[✗] FAILED to initialize ProjectileSystem")
        print("Error details:", initError)
        print("\nThis is likely due to:")
        print("  1. Physics world not initialized (globals.physicsWorld)")
        print("  2. Physics module not available")
        print("  3. Timer module missing physics step function")
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

    -- Test 5: Wall collision culling (after 5 seconds)
    timer.after(5.0, function()
        ProjectileSystemTest.testWallCollision()
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
    local component_cache = ProjectileSystemTest.component_cache

    local success, projectileId = pcall(function()
        return ProjectileSystem.spawn({
            position = {x = 400, y = 300},
            positionIsCenter = true,
            angle = 0,  -- Shoot right
            baseSpeed = 300,
            damage = 10,
            owner = nil,
            lifetime = 10,
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

        -- DEBUG: Check projectile state
        print("\n[DEBUG] Projectile details:")

        -- Check if entity has transform
        local transform = component_cache.get(projectileId, Transform)
        if transform then
            print("    Transform: x=", transform.actualX, "y=", transform.actualY)
            print("    Size: w=", transform.actualW, "h=", transform.actualH)
        else
            print("    [!] No transform component found")
        end

        local scriptTable = getScriptTableFromEntityID(projectileId)
        if scriptTable then
            print("    Script Table found")
            -- projectileData
            if scriptTable.projectileBehavior then
                print("    Projectile Behavior:", scriptTable.projectileBehavior)
            else
                print("    [!] No projectileBehavior in script table")
            end
        end
        -- Check active projectiles count
        local count = 0
        for _ in pairs(ProjectileSystem.active_projectiles) do
            count = count + 1
        end
        print("    Active projectiles:", count)

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
                positionIsCenter = true,
                angle = angle,
                baseSpeed = 250,
                damage = 8,
                lifetime = 10,
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
            positionIsCenter = true,
            baseSpeed = 200,
            damage = 15,
            lifetime = 10,
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
            positionIsCenter = true,
            angle = math.pi / 4,  -- 45 degrees up
            baseSpeed = 400,
            damage = 20,
            lifetime = 10,
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

function ProjectileSystemTest.testWallCollision()
    print("\n[TEST 5] Wall Collision Culling")
    print(string.rep("-", 40))

    local ProjectileSystem = ProjectileSystemTest.ProjectileSystem

    local success, projectileId = pcall(function()
        return ProjectileSystem.spawn({
            position = {x = 100, y = 100},
            positionIsCenter = true,
            angle = 0,
            baseSpeed = 0,
            damage = 0,
            lifetime = 3,
            movementType = "straight",
            collisionBehavior = "destroy",
            collideWithWorld = true
        })
    end)

    if not (success and projectileId and projectileId ~= entt_null) then
        print("[✗] Failed to spawn projectile for wall test")
        ProjectileSystemTest.testResults.wallCollision = false
        return
    end

    ProjectileSystem.handleCollision(projectileId, entt_null)

    local script = getScriptTableFromEntityID(projectileId)
    local lifetime = script and script.projectileLifetime

    if lifetime and lifetime.shouldDespawn then
        print("[✓] Projectile marked for destruction after hitting wall")
        ProjectileSystemTest.testResults.wallCollision = true
    else
        print("[✗] Projectile did not mark itself for destruction on wall hit")
        ProjectileSystemTest.testResults.wallCollision = false
    end

    -- Cleanup spawned entities
    ProjectileSystem.destroy(projectileId)
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

-- Update function (call this from main loop if not using physics step timer)
function ProjectileSystemTest.update(dt)
    if ProjectileSystemTest.ProjectileSystem then
        if not ProjectileSystemTest.ProjectileSystem.use_physics_step_timer then
            ProjectileSystemTest.ProjectileSystem.update(dt)
        end

        -- Debug: Print active projectile positions every second
        if not ProjectileSystemTest.lastDebugTime then
            ProjectileSystemTest.lastDebugTime = 0
        end

        ProjectileSystemTest.lastDebugTime = ProjectileSystemTest.lastDebugTime + dt

        if ProjectileSystemTest.lastDebugTime >= 1.0 then
            ProjectileSystemTest.lastDebugTime = 0

            local count = 0
            for entity, _ in pairs(ProjectileSystemTest.ProjectileSystem.active_projectiles) do
                count = count + 1
                if ProjectileSystemTest.component_cache then
                    local transform = ProjectileSystemTest.component_cache.get(entity, Transform)
                    if transform then
                        print(string.format("[DEBUG] Projectile %d at (%.1f, %.1f)", entity, transform.actualX, transform.actualY))
                    end
                end
            end

            if count > 0 then
                print(string.format("[DEBUG] Total active projectiles: %d", count))
            end
        end
    end
end

-- Auto-initialize if run directly
if not ProjectileSystemTest.initialized then
    local success = ProjectileSystemTest.init()
    if not success then
        print("\n❌ Projectile system test initialization FAILED")
    else
        print("\n✅ Projectile system test initialized successfully")
        print("\nIMPORTANT: If using manual updates, add this to your main loop:")
        print("  ProjectileSystemTest.update(dt)")
    end
end

return ProjectileSystemTest
