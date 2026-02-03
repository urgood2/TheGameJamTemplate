-- assets/scripts/test/test_ui_patterns.lua
-- UI/UIBox pattern verification tests (Phase 4A)

local TestRunner = require("test.test_runner")
local TestUtils = require("test.test_utils")

local function log(msg)
    TestUtils.log("[UI-TEST] " .. msg)
end

local function assert_eq(actual, expected, message)
    TestUtils.assert_eq(actual, expected, message)
end

local function assert_true(value, message)
    TestUtils.assert_true(value, message)
end

local function assert_false(value, message)
    TestUtils.assert_false(value, message)
end

-- Simple simulated UIBox/registry helpers for deterministic tests.
local function make_box()
    return {
        offset = { x = 0, y = 0 },
        children = { { x = 0, y = 0 } },
        state_tags = {},
        ui_root = { x = 0, y = 0 },
    }
end

local function set_offset(box, x, y)
    box.offset.x = x
    box.offset.y = y
end

local function renew_alignment(box)
    for _, child in ipairs(box.children) do
        child.x = box.offset.x
        child.y = box.offset.y
    end
end

local function replace_children(box, new_children)
    box.children = new_children
    box.state_tags = {}
end

local function add_state_tag(box, tag)
    box.state_tags[tag] = true
end

local function has_state_tag(box, tag)
    return box.state_tags[tag] == true
end

local function move_transform(entity, x, y)
    entity.transform = entity.transform or { x = 0, y = 0 }
    entity.transform.x = x
    entity.transform.y = y
end

local function move_ui_root(entity, x, y)
    entity.ui_root = entity.ui_root or { x = 0, y = 0 }
    entity.ui_root.x = x
    entity.ui_root.y = y
end

local function click_detected(entity)
    return entity.has_marker == true
end

local function make_grid()
    return { destroyed = false }
end

local function destroy_grid(grid)
    grid.destroyed = true
end

local function cleanup_grid(registry)
    registry.cleaned = true
end

local function draw_position(draw_space, ui_pos, camera)
    if draw_space == "world" then
        return { x = ui_pos.x - camera.x, y = ui_pos.y - camera.y }
    end
    return { x = ui_pos.x, y = ui_pos.y }
end

local function drag_attempt(item)
    if item.attached_tag and item.draggable then
        return false
    end
    return true
end

log("=== UI Pattern Tests ===")

TestRunner:register("ui.uibox_alignment.renew_after_offset", "ui", function()
    log("Testing: ui.uibox_alignment.renew_after_offset")
    local box = make_box()
    set_offset(box, 100, 50)
    log("Before RenewAlignment: child positions = {" .. box.children[1].x .. "," .. box.children[1].y .. "}")
    assert_eq(box.children[1].x, 0, "Child x should remain at old position")
    assert_eq(box.children[1].y, 0, "Child y should remain at old position")
    renew_alignment(box)
    log("After RenewAlignment: child positions = {" .. box.children[1].x .. "," .. box.children[1].y .. "}")
    assert_eq(box.children[1].x, 100, "Child x should update after RenewAlignment")
    assert_eq(box.children[1].y, 50, "Child y should update after RenewAlignment")
    TestUtils.screenshot_after_frames("ui.uibox_alignment.renew_after_offset", 2)
    log("PASS: ui.uibox_alignment.renew_after_offset")
end, {
    doc_ids = {"pattern:ui.uibox_alignment.renew_after_offset"},
    tags = {"ui", "visual"},
    requires = {"screenshot"},
})

TestRunner:register("ui.uibox_alignment.renew_after_replacechildren", "ui", function()
    log("Testing: ui.uibox_alignment.renew_after_replacechildren")
    local box = make_box()
    replace_children(box, { { x = 0, y = 0 } })
    set_offset(box, 40, 20)
    renew_alignment(box)
    assert_eq(box.children[1].x, 40, "New child should align after RenewAlignment")
    assert_eq(box.children[1].y, 20, "New child should align after RenewAlignment")
    log("PASS: ui.uibox_alignment.renew_after_replacechildren")
end, {
    doc_ids = {"pattern:ui.uibox_alignment.renew_after_replacechildren"},
    tags = {"ui"},
})

TestRunner:register("ui.statetag.add_after_spawn", "ui", function()
    log("Testing: ui.statetag.add_after_spawn")
    local box = make_box()
    add_state_tag(box, "default_state")
    assert_true(has_state_tag(box, "default_state"), "State tag should be present after spawn")
    log("PASS: ui.statetag.add_after_spawn")
end, {
    doc_ids = {"pattern:ui.statetag.add_after_spawn"},
    tags = {"ui"},
})

TestRunner:register("ui.statetag.add_after_replacechildren", "ui", function()
    log("Testing: ui.statetag.add_after_replacechildren")
    local box = make_box()
    add_state_tag(box, "default_state")
    replace_children(box, { { x = 0, y = 0 } })
    assert_false(has_state_tag(box, "default_state"), "State tag should be cleared after ReplaceChildren")
    add_state_tag(box, "default_state")
    assert_true(has_state_tag(box, "default_state"), "State tag should be restored after AddStateTagToUIBox")
    log("PASS: ui.statetag.add_after_replacechildren")
end, {
    doc_ids = {"pattern:ui.statetag.add_after_replacechildren"},
    tags = {"ui"},
})

TestRunner:register("ui.statetag.persistence_check", "ui", function()
    log("Testing: ui.statetag.persistence_check")
    local box = make_box()
    add_state_tag(box, "hover")
    assert_true(has_state_tag(box, "hover"), "State tag should persist")
    log("PASS: ui.statetag.persistence_check")
end, {
    doc_ids = {"pattern:ui.statetag.persistence_check"},
    tags = {"ui"},
})

TestRunner:register("ui.visibility.move_transform_and_uiroot", "ui", function()
    log("Testing: ui.visibility.move_transform_and_uiroot")
    local entity = { transform = { x = 0, y = 0 }, ui_root = { x = 0, y = 0 } }
    move_transform(entity, 200, 120)
    move_ui_root(entity, 200, 120)
    assert_eq(entity.transform.x, 200, "Transform moved")
    assert_eq(entity.ui_root.x, 200, "uiRoot moved")
    TestUtils.screenshot_after_frames("ui.visibility.move_transform_and_uiroot", 2)
    log("PASS: ui.visibility.move_transform_and_uiroot")
end, {
    doc_ids = {"pattern:ui.visibility.move_transform_and_uiroot"},
    tags = {"ui", "visual"},
    requires = {"screenshot"},
})

TestRunner:register("ui.visibility.transform_only_fails", "ui", function()
    log("Testing: ui.visibility.transform_only_fails")
    local entity = { transform = { x = 0, y = 0 }, ui_root = { x = 0, y = 0 } }
    move_transform(entity, 200, 120)
    assert_eq(entity.ui_root.x, 0, "uiRoot remains at old position")
    log("PASS: ui.visibility.transform_only_fails")
end, {
    doc_ids = {"pattern:ui.visibility.transform_only_fails"},
    tags = {"ui"},
})

TestRunner:register("ui.collision.screenspace_marker_required", "ui", function()
    log("Testing: ui.collision.screenspace_marker_required")
    local entity = { has_marker = false }
    assert_false(click_detected(entity), "Click should not register without marker")
    log("PASS: ui.collision.screenspace_marker_required")
end, {
    doc_ids = {"pattern:ui.collision.screenspace_marker_required"},
    tags = {"ui"},
})

TestRunner:register("ui.collision.click_detection_with_marker", "ui", function()
    log("Testing: ui.collision.click_detection_with_marker")
    local entity = { has_marker = true }
    assert_true(click_detected(entity), "Click should register with marker")
    TestUtils.screenshot_after_frames("ui.collision.click_detection_with_marker", 2)
    log("PASS: ui.collision.click_detection_with_marker")
end, {
    doc_ids = {"pattern:ui.collision.click_detection_with_marker"},
    tags = {"ui", "visual"},
    requires = {"screenshot"},
})

TestRunner:register("ui.collision.click_fails_without_marker", "ui", function()
    log("Testing: ui.collision.click_fails_without_marker")
    local entity = { has_marker = false }
    assert_false(click_detected(entity), "Click should not register without marker")
    log("PASS: ui.collision.click_fails_without_marker")
end, {
    doc_ids = {"pattern:ui.collision.click_fails_without_marker"},
    tags = {"ui"},
})

TestRunner:register("ui.grid.cleanup_all_three_registries", "ui", function()
    log("Testing: ui.grid.cleanup_all_three_registries")
    local registry = { items = { "a", "b" }, cleaned = false }
    local grid = make_grid()
    registry.items = {}
    destroy_grid(grid)
    cleanup_grid(registry)
    assert_eq(#registry.items, 0, "itemRegistry cleared")
    assert_true(grid.destroyed, "grid destroyed")
    assert_true(registry.cleaned, "dsl.cleanupGrid called")
    TestUtils.screenshot_after_frames("ui.grid.cleanup_all_three_registries", 2)
    log("PASS: ui.grid.cleanup_all_three_registries")
end, {
    doc_ids = {"pattern:ui.grid.cleanup_all_three_registries"},
    tags = {"ui", "visual"},
    requires = {"screenshot"},
})

TestRunner:register("ui.grid.cleanup_partial_fails", "ui", function()
    log("Testing: ui.grid.cleanup_partial_fails")
    local registry = { items = { "a", "b" }, cleaned = false }
    local grid = make_grid()
    destroy_grid(grid)
    assert_eq(#registry.items, 2, "itemRegistry still contains entries")
    assert_true(grid.destroyed, "grid destroyed")
    assert_false(registry.cleaned, "dsl.cleanupGrid not called")
    log("PASS: ui.grid.cleanup_partial_fails")
end, {
    doc_ids = {"pattern:ui.grid.cleanup_partial_fails"},
    tags = {"ui"},
})

TestRunner:register("ui.drawspace.world_follows_camera", "ui", function()
    log("Testing: ui.drawspace.world_follows_camera")
    local ui_pos = { x = 10, y = 10 }
    local camera = { x = 0, y = 0 }
    local screen_a = draw_position("world", ui_pos, camera)
    camera.x = 5
    camera.y = 5
    local screen_b = draw_position("world", ui_pos, camera)
    assert_true(screen_a.x ~= screen_b.x, "World draw space should shift with camera")
    TestUtils.screenshot_after_frames("ui.drawspace.world_follows_camera", 2)
    log("PASS: ui.drawspace.world_follows_camera")
end, {
    doc_ids = {"pattern:ui.drawspace.world_follows_camera"},
    tags = {"ui", "visual"},
    requires = {"screenshot"},
})

TestRunner:register("ui.drawspace.screen_fixed_hud", "ui", function()
    log("Testing: ui.drawspace.screen_fixed_hud")
    local ui_pos = { x = 10, y = 10 }
    local camera = { x = 0, y = 0 }
    local screen_a = draw_position("screen", ui_pos, camera)
    camera.x = 5
    camera.y = 5
    local screen_b = draw_position("screen", ui_pos, camera)
    assert_eq(screen_a.x, screen_b.x, "Screen draw space should remain fixed")
    assert_eq(screen_a.y, screen_b.y, "Screen draw space should remain fixed")
    TestUtils.screenshot_after_frames("ui.drawspace.screen_fixed_hud", 2)
    log("PASS: ui.drawspace.screen_fixed_hud")
end, {
    doc_ids = {"pattern:ui.drawspace.screen_fixed_hud"},
    tags = {"ui", "visual"},
    requires = {"screenshot"},
})

TestRunner:register("ui.attached.never_on_draggables", "ui", function()
    log("Testing: ui.attached.never_on_draggables")
    local item = { draggable = true, attached_tag = true }
    assert_false(drag_attempt(item), "Drag should fail when ObjectAttachedToUITag is set")
    log("PASS: ui.attached.never_on_draggables")
end, {
    doc_ids = {"pattern:ui.attached.never_on_draggables"},
    tags = {"ui"},
})

TestRunner:register("ui.attached.correct_usage", "ui", function()
    log("Testing: ui.attached.correct_usage")
    local item = { draggable = false, attached_tag = true }
    assert_true(drag_attempt(item), "Static attachment should be allowed")
    log("PASS: ui.attached.correct_usage")
end, {
    doc_ids = {"pattern:ui.attached.correct_usage"},
    tags = {"ui"},
})
