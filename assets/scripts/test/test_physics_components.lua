-- test_physics_components.lua
-- Physics component access tests (Phase 3 B2)

local TestRunner = require("test.test_runner")
local test_utils = require("test.test_utils")

local function require_globals()
    test_utils.assert_not_nil(_G.registry, "registry available")
    test_utils.assert_not_nil(_G.component_cache, "component_cache available")
    test_utils.assert_not_nil(_G.ObjectLayerTag, "ObjectLayerTag available")
    test_utils.assert_not_nil(_G.PhysicsLayer, "PhysicsLayer available")
    test_utils.assert_not_nil(_G.BodyComponent, "BodyComponent available")
    test_utils.assert_not_nil(_G.ColliderComponent, "ColliderComponent available")
    test_utils.assert_not_nil(_G.RaycastHit, "RaycastHit available")
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

TestRunner.register("physics.components.smoke", "components", function()
    require_globals()
end, {
    tags = {"physics", "components", "smoke"},
    doc_ids = {
        "component:ObjectLayerTag",
        "component:PhysicsLayer",
        "component:BodyComponent",
        "component:ColliderComponent",
        "component:RaycastHit",
    },
    requires = {"test_scene"},
})

TestRunner.register("physics.components.physicslayer.read_write", "components", function()
    require_globals()
    local entity = test_utils.spawn_test_entity()

    emplace_component(entity, PhysicsLayer, {
        tag = "WORLD",
        tag_hash = 0,
    })

    local layer = _G.component_cache.get(entity, PhysicsLayer)
    test_utils.assert_not_nil(layer, "PhysicsLayer component available")
    test_utils.assert_eq(layer.tag, "WORLD", "PhysicsLayer.tag read")

    layer.tag = "PLAYER"
    test_utils.assert_eq(layer.tag, "PLAYER", "PhysicsLayer.tag write")
end, {
    tags = {"physics", "components"},
    doc_ids = {"component:PhysicsLayer"},
    requires = {"test_scene"},
})

TestRunner.register("physics.components.objectlayertag.read_write", "components", function()
    require_globals()
    local entity = test_utils.spawn_test_entity()

    emplace_component(entity, ObjectLayerTag, {
        name = "WORLD",
        hash = 0,
    })

    local tag = _G.component_cache.get(entity, ObjectLayerTag)
    test_utils.assert_not_nil(tag, "ObjectLayerTag component available")
    test_utils.assert_eq(tag.name, "WORLD", "ObjectLayerTag.name read")
    test_utils.assert_not_nil(tag.hash, "ObjectLayerTag.hash present")

    tag.name = "PLAYER"
    test_utils.assert_eq(tag.name, "PLAYER", "ObjectLayerTag.name write")
end, {
    tags = {"physics", "components"},
    doc_ids = {"component:ObjectLayerTag"},
    requires = {"test_scene"},
})

TestRunner.register("physics.components.bodycomponent.nil_body", "components", function()
    require_globals()
    local entity = test_utils.spawn_test_entity()

    emplace_component(entity, BodyComponent, {})

    local body = _G.component_cache.get(entity, BodyComponent)
    test_utils.assert_not_nil(body, "BodyComponent component available")
    test_utils.assert_eq(body.body, nil, "BodyComponent.body defaults to nil")
end, {
    tags = {"physics", "components"},
    doc_ids = {"component:BodyComponent"},
    requires = {"test_scene"},
})
