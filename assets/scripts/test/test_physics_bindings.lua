-- test_physics_bindings.lua
-- Physics bindings coverage tests (Phase 2 A1)

local TestRunner = require("test.test_runner")
local test_utils = require("test.test_utils")

local function get_physics()
    return _G.physics
end

local function build_world(tags)
    local physics = get_physics()
    test_utils.assert_not_nil(physics, "physics module available")
    test_utils.assert_not_nil(PhysicsWorld, "PhysicsWorld usertype available")

    local registry = _G.registry or registry
    test_utils.assert_not_nil(registry, "registry available")

    local world = PhysicsWorld(registry, 1.0, 0.0, 0.0)
    test_utils.assert_not_nil(world, "PhysicsWorld constructed")

    if physics.set_collision_tags and tags then
        physics.set_collision_tags(world, tags)
    end

    return world
end

local function add_circle(world, entity, tag, radius, x, y)
    local physics = get_physics()
    physics.AddCollider(world, entity, tag, "circle", radius, 0, 0, 0, false, nil)
    if physics.SetPosition then
        physics.SetPosition(world, entity, x or 0, y or 0)
    end
end

-- Smoke test: module and key functions exist
TestRunner.register("physics.bindings.smoke", "physics", function()
    local physics = get_physics()
    test_utils.assert_not_nil(physics, "physics module exists")
    test_utils.assert_true(type(physics.segment_query_first) == "function", "segment_query_first exists")
    test_utils.assert_true(type(physics.entity_from_ptr) == "function", "entity_from_ptr exists")
    test_utils.assert_true(type(physics.AddCollider) == "function", "AddCollider exists")
    test_utils.assert_true(type(physics.add_shape_to_entity) == "function", "add_shape_to_entity exists")
    test_utils.assert_true(type(physics.update_collision_masks_for) == "function", "update_collision_masks_for exists")
end, {
    tags = {"physics", "smoke"},
    doc_ids = {},
    requires = {"test_scene"},
})

-- Functional: segment_query_first hits entity and entity_from_ptr resolves
TestRunner.register("physics.segment_query.hit_entity", "physics", function()
    test_utils.reset_world()
    local physics = get_physics()
    local world = build_world({"wall"})

    local entity = test_utils.spawn_test_entity()
    add_circle(world, entity, "wall", 10, 0, 0)

    local hit = physics.segment_query_first(world, {x = -20, y = 0}, {x = 20, y = 0})
    test_utils.assert_true(hit.hit, "Expected hit")
    test_utils.assert_not_nil(hit.shape, "Expected hit shape")

    local hit_entity = physics.entity_from_ptr(hit.shape)
    test_utils.assert_eq(hit_entity, entity, "Expected hit entity")
    test_utils.reset_world()
end, {
    tags = {"physics", "raycast"},
    doc_ids = {
        "sol2_function_physics_table_segment_query_first",
        "sol2_function_physics_entity_from_ptr",
    },
    requires = {"test_scene"},
})

-- Functional: segment_query_first returns no hit for empty world
TestRunner.register("physics.segment_query.no_hit", "physics", function()
    test_utils.reset_world()
    local physics = get_physics()
    local world = build_world({"wall"})

    local hit = physics.segment_query_first(world, {x = -20, y = 0}, {x = 20, y = 0})
    test_utils.assert_false(hit.hit, "Expected no hit")
    test_utils.reset_world()
end, {
    tags = {"physics", "raycast"},
    doc_ids = {"sol2_function_physics_table_segment_query_first"},
    requires = {"test_scene"},
})

-- Functional: AddCollider creates a shape for an entity
TestRunner.register("physics.add_collider.circle", "physics", function()
    test_utils.reset_world()
    local physics = get_physics()
    local world = build_world({"wall"})

    local entity = test_utils.spawn_test_entity()
    add_circle(world, entity, "wall", 8, 5, 0)

    local count = physics.get_shape_count(world, entity)
    test_utils.assert_eq(count, 1, "Expected one shape after AddCollider")
    test_utils.reset_world()
end, {
    tags = {"physics", "collider"},
    doc_ids = {"sol2_function_physics_addcollider"},
    requires = {"test_scene"},
})

-- Functional: add_shape_to_entity adds a second shape
TestRunner.register("physics.add_shape.circle", "physics", function()
    test_utils.reset_world()
    local physics = get_physics()
    local world = build_world({"wall"})

    local entity = test_utils.spawn_test_entity()
    add_circle(world, entity, "wall", 6, 0, 0)
    physics.add_shape_to_entity(world, entity, "wall", "circle", 4, 0, 0, 0, false, nil)

    local count = physics.get_shape_count(world, entity)
    test_utils.assert_eq(count, 2, "Expected two shapes after add_shape_to_entity")
    test_utils.reset_world()
end, {
    tags = {"physics", "collider"},
    doc_ids = {"sol2_function_physics_add_shape_to_entity"},
    requires = {"test_scene"},
})

-- Functional: update_collision_masks_for applies without errors
TestRunner.register("physics.update_collision_masks.basic", "physics", function()
    test_utils.reset_world()
    local physics = get_physics()
    local world = build_world({"a", "b"})

    physics.update_collision_masks_for(world, "a", {"b"})
    test_utils.assert_true(true, "update_collision_masks_for executed")
    test_utils.reset_world()
end, {
    tags = {"physics", "collision"},
    doc_ids = {"sol2_function_physics_table_update_collision_masks_for"},
    requires = {"test_scene"},
})

-- Integration: raycast hits the first collider (wall)
TestRunner.register("physics.raycast_through_wall", "physics", function()
    test_utils.reset_world()
    local physics = get_physics()
    local world = build_world({"wall", "target"})

    local wall = test_utils.spawn_test_entity()
    local target = test_utils.spawn_test_entity()
    add_circle(world, wall, "wall", 6, 0, 0)
    add_circle(world, target, "target", 6, 16, 0)

    local hit = physics.segment_query_first(world, {x = -20, y = 0}, {x = 20, y = 0})
    test_utils.assert_true(hit.hit, "Expected wall hit")
    local hit_entity = physics.entity_from_ptr(hit.shape)
    test_utils.assert_eq(hit_entity, wall, "Expected wall to be first hit")
    test_utils.reset_world()
end, {
    tags = {"physics", "raycast", "integration"},
    doc_ids = {
        "sol2_function_physics_table_segment_query_first",
        "sol2_function_physics_entity_from_ptr",
    },
    requires = {"test_scene"},
})

-- Integration: collision callback fires on overlapping shapes
TestRunner.register("physics.collision_callback", "physics", function()
    test_utils.reset_world()
    local physics = get_physics()
    local world = build_world({"a", "b"})

    physics.enable_collision_between(world, "a", "b")

    local hit_count = 0
    physics.on_pair_begin(world, "a", "b", function()
        hit_count = hit_count + 1
        return true
    end)

    local a = test_utils.spawn_test_entity()
    local b = test_utils.spawn_test_entity()
    add_circle(world, a, "a", 6, 0, 0)
    add_circle(world, b, "b", 6, 0, 0)

    for _ = 1, 3 do
        world:Update(0.016)
    end
    world:PostUpdate()

    test_utils.assert_true(hit_count > 0, "Expected collision callback to fire")
    test_utils.reset_world()
end, {
    tags = {"physics", "collision", "integration"},
    doc_ids = {"sol2_function_physics_table_on_pair_begin"},
    requires = {"test_scene"},
})
