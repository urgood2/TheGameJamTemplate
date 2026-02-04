-- test_core_components.lua
-- Core + graphics component access tests (Phase 3 B1)

local TestRunner = require("test.test_runner")
local test_utils = require("test.test_utils")

local function require_globals()
    test_utils.assert_not_nil(_G.registry, "registry available")
    test_utils.assert_not_nil(_G.component_cache, "component_cache available")
    test_utils.assert_not_nil(_G.TransformCustom, "TransformCustom available")
    test_utils.assert_not_nil(_G.FrameData, "FrameData available")
    test_utils.assert_not_nil(_G.SpriteComponentASCII, "SpriteComponentASCII available")
    test_utils.assert_not_nil(_G.AnimationQueueComponent, "AnimationQueueComponent available")
end

local function emplace_component(entity, comp_type, data)
    local payload = data or {}
    payload.__type = comp_type
    local ok, result = pcall(function()
        return _G.registry:emplace(entity, payload)
    end)
    test_utils.assert_true(ok, "registry:emplace succeeded")
    return result
end

TestRunner.register("core.components.smoke", "components", function()
    require_globals()
end, {
    tags = {"core", "graphics", "components", "smoke"},
    doc_ids = {
        "component:TransformCustom",
        "component:FrameData",
        "component:SpriteComponentASCII",
        "component:AnimationQueueComponent",
    },
    requires = {"test_scene"},
})

TestRunner.register("core.components.transformcustom.read_write", "components", function()
    require_globals()
    local entity = test_utils.spawn_test_entity()

    emplace_component(entity, TransformCustom, {
        x = 10,
        y = 20,
        w = 3,
        h = 4,
        r = 0,
        scale = 1,
    })

    local transform = _G.component_cache.get(entity, TransformCustom)
    test_utils.assert_not_nil(transform, "TransformCustom component available")
    test_utils.assert_eq(transform.x, 10, "TransformCustom.x read")
    test_utils.assert_eq(transform.y, 20, "TransformCustom.y read")

    transform.x = 42
    transform.y = 84
    test_utils.assert_eq(transform.x, 42, "TransformCustom.x write")
    test_utils.assert_eq(transform.y, 84, "TransformCustom.y write")
end, {
    tags = {"core", "components"},
    doc_ids = {"component:TransformCustom"},
    requires = {"test_scene"},
})

TestRunner.register("core.components.framedata.read", "components", function()
    require_globals()
    local entity = test_utils.spawn_test_entity()

    emplace_component(entity, FrameData, {
        frame = { x = 1, y = 2, width = 3, height = 4 },
        texture = nil,
    })

    local frame = _G.component_cache.get(entity, FrameData)
    test_utils.assert_not_nil(frame, "FrameData component available")
    test_utils.assert_not_nil(frame.frame, "FrameData.frame available")
end, {
    tags = {"core", "components"},
    doc_ids = {"component:FrameData"},
    requires = {"test_scene"},
})

TestRunner.register("core.components.spritecomponentascii.read_write", "components", function()
    require_globals()
    local entity = test_utils.spawn_test_entity()

    emplace_component(entity, SpriteComponentASCII, {
        spriteNumber = 1,
        noBackgroundColor = true,
        noForegroundColor = false,
    })

    local sprite = _G.component_cache.get(entity, SpriteComponentASCII)
    test_utils.assert_not_nil(sprite, "SpriteComponentASCII component available")
    test_utils.assert_eq(sprite.spriteNumber, 1, "SpriteComponentASCII.spriteNumber read")

    sprite.spriteNumber = 2
    test_utils.assert_eq(sprite.spriteNumber, 2, "SpriteComponentASCII.spriteNumber write")
end, {
    tags = {"core", "graphics", "components"},
    doc_ids = {"component:SpriteComponentASCII"},
    requires = {"test_scene"},
})

TestRunner.register("core.components.animationqueuecomponent.read_write", "components", function()
    require_globals()
    local entity = test_utils.spawn_test_entity()

    emplace_component(entity, AnimationQueueComponent, {
        enabled = false,
        currentAnimationIndex = 0,
        useCallbackOnAnimationQueueComplete = false,
    })

    local anim = _G.component_cache.get(entity, AnimationQueueComponent)
    test_utils.assert_not_nil(anim, "AnimationQueueComponent component available")
    test_utils.assert_eq(anim.enabled, false, "AnimationQueueComponent.enabled read")

    anim.enabled = true
    test_utils.assert_eq(anim.enabled, true, "AnimationQueueComponent.enabled write")
end, {
    tags = {"core", "graphics", "components"},
    doc_ids = {"component:AnimationQueueComponent"},
    requires = {"test_scene"},
})
