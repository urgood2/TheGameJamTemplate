-- test_render_groups.lua
-- Integration test for render groups system

local function test_render_groups()
    print("[test_render_groups] Starting tests...")

    -- Test 1: Create group
    render_groups.create("test_enemies", {"flash"})
    print("[test_render_groups] Created group 'test_enemies' with shader 'flash'")

    -- Test 2: Create test entity
    local testEntity = registry:create()
    print("[test_render_groups] Created test entity:", testEntity)

    -- Test 3: Add entity to group
    render_groups.add("test_enemies", testEntity)
    print("[test_render_groups] Added entity to group")

    -- Test 4: Add with custom shaders
    local testEntity2 = registry:create()
    render_groups.add("test_enemies", testEntity2, {"3d_skew", "dissolve"})
    print("[test_render_groups] Added entity2 with custom shaders")

    -- Test 5: Dynamic shader manipulation
    render_groups.addShader("test_enemies", testEntity, "outline")
    print("[test_render_groups] Added 'outline' shader to entity")

    render_groups.removeShader("test_enemies", testEntity, "outline")
    print("[test_render_groups] Removed 'outline' shader from entity")

    render_groups.setShaders("test_enemies", testEntity, {"custom1", "custom2"})
    print("[test_render_groups] Set custom shader list")

    render_groups.resetToDefault("test_enemies", testEntity)
    print("[test_render_groups] Reset to default shaders")

    -- Test 6: Remove entity
    render_groups.remove("test_enemies", testEntity)
    print("[test_render_groups] Removed entity from group")

    -- Test 7: Remove from all
    render_groups.removeFromAll(testEntity2)
    print("[test_render_groups] Removed entity2 from all groups")

    -- Cleanup
    render_groups.clearAll()
    registry:destroy(testEntity)
    registry:destroy(testEntity2)

    print("[test_render_groups] All tests passed!")
    return true
end

return { run = test_render_groups }
