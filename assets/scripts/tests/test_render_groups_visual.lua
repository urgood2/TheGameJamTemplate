local M = {}

local component_cache = require("core.component_cache")

local testEntity = nil
local testGroup = "visual_test_3d_skew"

function M.init()
    print("[render_groups_test] Initializing 3d_skew shader visual test...")

    render_groups.create(testGroup, {"3d_skew_holo"})

    testEntity = animation_system.createAnimatedObjectWithTransform(
        "enemy_type_1.png",
        true
    )

    animation_system.resizeAnimationObjectsInEntityToFit(
        testEntity,
        128,
        128
    )

    local transform = component_cache.get(testEntity, Transform)
    if transform then
        transform.actualX = globals.screenWidth() / 2 - 64
        transform.actualY = 100
    end

    local nodeComp = component_cache.get(testEntity, GameObject)
    if nodeComp then
        nodeComp.state.hoverEnabled = true
        nodeComp.state.collisionEnabled = true
    end

    render_groups.add(testGroup, testEntity)

    print("[render_groups_test] Created entity:", testEntity, "with 3d_skew_holo shader")
end

local drawCallCount = 0
function M.draw()
    if not testEntity then return end

    if command_buffer and command_buffer.queueDrawRenderGroup and layers and layers.sprites then
        drawCallCount = drawCallCount + 1
        if drawCallCount <= 3 then
            print("[render_groups_test] Queuing 3d_skew draw #" .. drawCallCount)
        end
        command_buffer.queueDrawRenderGroup(layers.sprites, function(cmd)
            cmd.registry = registry
            cmd.groupName = testGroup
            cmd.autoOptimize = true
        end, 1000, layer.DrawCommandSpace.World)
    else
        if drawCallCount == 0 then
            print("[render_groups_test] ERROR: Missing command_buffer or layers!")
            drawCallCount = -1
        end
    end
end

function M.cleanup()
    if testEntity then
        render_groups.removeFromAll(testEntity)
        registry:destroy(testEntity)
        testEntity = nil
    end
    render_groups.clearGroup(testGroup)
    print("[render_groups_test] Cleaned up")
end

return M
