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
ProjectileSystemTest.spawnedProjectiles = {}
ProjectileSystemTest.repeatIntervalSeconds = 10
ProjectileSystemTest.repeatTimerTag = "projectile_test_repeat"
ProjectileSystemTest.fallbackHomingTarget = nil
ProjectileSystemTest.fallbackOrbitalCenter = nil

function ProjectileSystemTest.trackProjectile(entity)
    if entity and entity ~= entt_null then
        ProjectileSystemTest.spawnedProjectiles[entity] = true
    end
end

function ProjectileSystemTest.cleanupTrackedProjectiles()
    local ProjectileSystem = ProjectileSystemTest.ProjectileSystem
    local entity_cache = ProjectileSystemTest.entity_cache

    for entity, _ in pairs(ProjectileSystemTest.spawnedProjectiles) do
        if ProjectileSystem and entity_cache and entity_cache.valid(entity) then
            ProjectileSystem.destroy(entity)
        end
        ProjectileSystemTest.spawnedProjectiles[entity] = nil
    end

    ProjectileSystemTest.spawnedProjectiles = {}
end

function ProjectileSystemTest.resetTestState()
    ProjectileSystemTest.testResults = {}
    ProjectileSystemTest.cleanupTrackedProjectiles()
end

function ProjectileSystemTest.startRepeatSchedule()
    local timer = ProjectileSystemTest.timer
    if not timer then
        return
    end

    timer.every(
        ProjectileSystemTest.repeatIntervalSeconds,
        function()
            ProjectileSystemTest.scheduleTests()
        end,
        0,
        false,
        nil,
        ProjectileSystemTest.repeatTimerTag
    )
end

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
    ProjectileSystemTest.startRepeatSchedule()

    return true
end

function ProjectileSystemTest.scheduleTests()
    local timer = ProjectileSystemTest.timer

    ProjectileSystemTest.resetTestState()

    print("\n" .. string.rep("-", 60))
    print(string.format("Scheduling tests... (repeats every %ds)", ProjectileSystemTest.repeatIntervalSeconds))
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

    -- Test 5: Orbital projectile (after 5 seconds)
    timer.after(5.0, function()
        ProjectileSystemTest.testOrbitalProjectile()
    end)

    -- Test 6: Wall collision culling (after 6 seconds)
    timer.after(6.0, function()
        ProjectileSystemTest.testWallCollision()
    end)

    -- Print results (after 9 seconds)
    timer.after(9.0, function()
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
        ProjectileSystemTest.trackProjectile(projectileId)

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
            ProjectileSystemTest.trackProjectile(projectileId)
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

    local targetEntity = survivorEntity
    local usingFallbackTarget = false

    if not targetEntity or not entity_cache.valid(targetEntity) then
        usingFallbackTarget = true
        print("[!] survivorEntity not available; creating fallback target for homing test")
        targetEntity = ProjectileSystemTest.fallbackHomingTarget or registry:create()
        ProjectileSystemTest.fallbackHomingTarget = targetEntity
    end

    local targetTransform = component_cache.get(targetEntity, Transform)
    if usingFallbackTarget and targetTransform then
        targetTransform.actualX = 600
        targetTransform.actualY = 300
        targetTransform.actualW = 32
        targetTransform.actualH = 32
    end
    local success, result = pcall(function()
        -- Ensure player/fallback transform has valid size for homing
        if targetTransform then
            targetTransform.actualW = targetTransform.actualW or 32
            targetTransform.actualH = targetTransform.actualH or 32
        end

        -- Spawn homing projectile
        return ProjectileSystem.spawn({
            position = {x = 200, y = 300},
            positionIsCenter = true,
            baseSpeed = 200,
            damage = 15,
            lifetime = 999, -- long lifetime so we can observe behavior
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
        if targetTransform then
            print(string.format("    Target position: (%.1f, %.1f)", targetTransform.actualX or 0, targetTransform.actualY or 0))
        end
        print("    Homing strength: 2.0")
        ProjectileSystemTest.trackProjectile(result)
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
            gravityScale = 1.5,
            forceManualGravity = true,
            usePhysics = false,
            collisionBehavior = "destroy",
            size = 18
        })
    end)

    if success and projectileId and entity_cache.valid(projectileId) then
        print("[✓] Arc projectile spawned successfully")
        print("    Launch angle: 45°")
        print("    Gravity scale: 1.5 (manual, no world gravity)")
        print("    Expected: Parabolic trajectory using internal gravity")
        ProjectileSystemTest.trackProjectile(projectileId)
        ProjectileSystemTest.testResults.arcProjectile = true
    else
        print("[✗] FAILED to spawn arc projectile")
        if not success then
            print("    Error:", projectileId)
        end
        ProjectileSystemTest.testResults.arcProjectile = false
    end
end

function ProjectileSystemTest.testOrbitalProjectile()
    print("\n[TEST 5] Orbital Projectile")
    print(string.rep("-", 40))

    local ProjectileSystem = ProjectileSystemTest.ProjectileSystem
    local entity_cache = ProjectileSystemTest.entity_cache
    local component_cache = ProjectileSystemTest.component_cache

    local centerEntity = survivorEntity
    if not centerEntity or not entity_cache.valid(centerEntity) then
        print("[!] survivorEntity not available; orbital test will use a fallback center")
        centerEntity = ProjectileSystemTest.fallbackOrbitalCenter or registry:create()
        ProjectileSystemTest.fallbackOrbitalCenter = centerEntity
        local fallbackTransform = component_cache.get(centerEntity, Transform)
        if fallbackTransform then
            fallbackTransform.actualX = 400
            fallbackTransform.actualY = 300
            fallbackTransform.actualW = 32
            fallbackTransform.actualH = 32
        end
    end

    local success, projectileId = pcall(function()
        local playerTransform = component_cache.get(centerEntity, Transform)
        local function centerPos()
            if playerTransform then
                return playerTransform.actualX + (playerTransform.actualW or 0) * 0.5,
                       playerTransform.actualY + (playerTransform.actualH or 0) * 0.5
            end
            return 400, 300
        end

        local cx, cy = centerPos()

        return ProjectileSystem.spawn({
            position = {x = cx, y = cy},
            positionIsCenter = true,
            movementType = "orbital",
            orbitCenter = {x = cx, y = cy},
            orbitCenterEntity = centerEntity,
            orbitRadius = 80,
            orbitSpeed = 2.0,
            lifetime = 999,
            collisionBehavior = "pass_through",
            size = 20,
            sprite = "b488.png" -- use guaranteed sprite to avoid missing animation errors
        })
    end)

    if success and projectileId and entity_cache.valid(projectileId) then
        print("[✓] Orbital projectile spawned successfully")
        print("    Center: player (or fallback)")
        print("    Lifetime: long (999s) for observation")
        ProjectileSystemTest.trackProjectile(projectileId)
        ProjectileSystemTest.testResults.orbitalProjectile = true
    else
        print("[✗] FAILED to spawn orbital projectile")
        if not success then
            print("    Error:", projectileId)
        end
        ProjectileSystemTest.testResults.orbitalProjectile = false
    end
end

function ProjectileSystemTest.testWallCollision()
    print("\n[TEST 6] Wall Collision Culling")
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
    print("  • Orbital projectile should circle the player")
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
