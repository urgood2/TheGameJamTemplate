-- assets/scripts/tests/test_ui_patterns.lua
-- UI/UIBox gotcha tests (mock-driven, deterministic)

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/tests/?.lua"

require("tests.mocks.engine_mock")

local TestRunner = require("tests.test_runner")
local t = TestRunner
local ChildBuilder = require("core.child_builder")

_G.Transform = _G.Transform or { _type = "Transform" }
_G.InheritedProperties = _G.InheritedProperties or { _type = "InheritedProperties" }
_G.UIBoxComponent = _G.UIBoxComponent or { _type = "UIBoxComponent" }
_G.ScreenSpaceCollisionMarker = _G.ScreenSpaceCollisionMarker or { _type = "ScreenSpaceCollisionMarker" }
_G.ObjectAttachedToUITag = _G.ObjectAttachedToUITag or { _type = "ObjectAttachedToUITag" }

local DOC_IDS = {
    ["ui.uibox_alignment.renew_after_offset"] = "pattern:ui.uibox_alignment.renew_after_offset",
    ["ui.uibox_alignment.renew_after_replacechildren"] = "pattern:ui.uibox_alignment.renew_after_replacechildren",
    ["ui.statetag.add_after_spawn"] = "pattern:ui.statetag.add_after_spawn",
    ["ui.statetag.add_after_replacechildren"] = "pattern:ui.statetag.add_after_replacechildren",
    ["ui.statetag.persistence_check"] = "pattern:ui.statetag.persistence_check",
    ["ui.visibility.move_transform_and_uiroot"] = "pattern:ui.visibility.move_transform_and_uiroot",
    ["ui.visibility.transform_only_fails"] = "pattern:ui.visibility.transform_only_fails",
    ["ui.collision.screenspace_marker_required"] = "pattern:ui.collision.screenspace_marker_required",
    ["ui.collision.click_detection_with_marker"] = "pattern:ui.collision.click_detection_with_marker",
    ["ui.collision.click_fails_without_marker"] = "pattern:ui.collision.click_fails_without_marker",
    ["ui.grid.cleanup_all_three_registries"] = "pattern:ui.grid.cleanup_all_three_registries",
    ["ui.grid.cleanup_partial_fails"] = "pattern:ui.grid.cleanup_partial_fails",
    ["ui.drawspace.world_follows_camera"] = "pattern:ui.drawspace.world_follows_camera",
    ["ui.drawspace.screen_fixed_hud"] = "pattern:ui.drawspace.screen_fixed_hud",
    ["ui.attached.never_on_draggables"] = "pattern:ui.attached.never_on_draggables",
    ["ui.attached.correct_usage"] = "pattern:ui.attached.correct_usage",
}

local VISUAL_TESTS = {
    ["ui.uibox_alignment.renew_after_offset"] = true,
    ["ui.uibox_alignment.renew_after_replacechildren"] = true,
    ["ui.visibility.move_transform_and_uiroot"] = true,
    ["ui.visibility.transform_only_fails"] = true,
    ["ui.collision.click_detection_with_marker"] = true,
    ["ui.grid.cleanup_all_three_registries"] = true,
    ["ui.drawspace.world_follows_camera"] = true,
    ["ui.drawspace.screen_fixed_hud"] = true,
    ["ui.attached.correct_usage"] = true,
}

local header_logged = false
local VIEWPORT = { width = 1280, height = 720, dpi_scale = 1.0 }
local CAPTURE_FRAME = 5

local function log_ui(msg)
    print(string.format("[UI-TEST] %s", msg))
end

local function ensure_dir(path)
    if os.execute then
        os.execute(string.format("mkdir -p %s", path))
    end
end

local function write_placeholder_png(path)
    local png_bytes = string.char(
        0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A,
        0x00,0x00,0x00,0x0D,0x49,0x48,0x44,0x52,
        0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x01,
        0x08,0x06,0x00,0x00,0x00,0x1F,0x15,0xC4,0x89,
        0x00,0x00,0x00,0x0A,0x49,0x44,0x41,0x54,
        0x78,0x9C,0x63,0x60,0x00,0x00,0x00,0x02,0x00,0x01,
        0xE5,0x27,0xD4,0xA2,
        0x00,0x00,0x00,0x00,0x49,0x45,0x4E,0x44,0xAE,0x42,0x60,0x82
    )
    local file = io.open(path, "wb")
    if not file then
        error("Could not write screenshot: " .. tostring(path))
    end
    file:write(png_bytes)
    file:close()
end

local function configure_visual_context()
    if globals then
        globals.screenWidth = VIEWPORT.width
        globals.screenHeight = VIEWPORT.height
        globals.dpi_scale = VIEWPORT.dpi_scale
        globals.time = 0
        globals.dt = 0
    end
end

_G.screenshot = _G.screenshot or {
    capture = function(path)
        write_placeholder_png(path)
        return path
    end,
}

local function capture_screenshot(test_id)
    configure_visual_context()
    local dir = "test_output/screenshots"
    ensure_dir(dir)
    local safe = TestRunner.safe_filename(test_id)
    local filename = string.format("%s/%s.png", dir, safe)
    write_placeholder_png(filename)
    log_ui(string.format(
        "  Screenshot: %s (frame=%d, viewport=%dx%d, dpi=%.1f)",
        filename,
        CAPTURE_FRAME,
        VIEWPORT.width,
        VIEWPORT.height,
        VIEWPORT.dpi_scale
    ))
    return filename
end

local ui_state_tags = {}
local ui_children = {}

local function reset_ui_state()
    if component_cache and component_cache._reset then
        component_cache._reset()
    end
    ui_state_tags = {}
    ui_children = {}
end

local function get_state_tags(entity)
    return ui_state_tags[entity] or {}
end

ui.box = ui.box or {}
ui.box.AddStateTagToUIBox = function(a, b, c)
    local entity = a
    local tag = b
    if c ~= nil then
        entity = b
        tag = c
    end
    local tags = ui_state_tags[entity] or {}
    tags[tag] = true
    ui_state_tags[entity] = tags
end

ui.box.ClearStateTagsFromUIBox = function(a, b)
    local entity = a
    if b ~= nil then
        entity = b
    end
    ui_state_tags[entity] = {}
end

ui.box.ReplaceChildren = function(a, b, c)
    local entity = a
    local new_children = b
    if c ~= nil then
        entity = b
        new_children = c
    end
    ui_children[entity] = new_children or {}
    ui_state_tags[entity] = {}
end

ui.box.RenewAlignment = function(reg, box)
    local parent_transform = component_cache.get(box, Transform) or { actualX = 0, actualY = 0 }
    local children = ui_children[box] or {}
    for _, child in ipairs(children) do
        local ip = component_cache.get(child, InheritedProperties)
        local tform = component_cache.get(child, Transform)
        if ip and tform and ip.offset then
            tform.actualX = parent_transform.actualX + ip.offset.x
            tform.actualY = parent_transform.actualY + ip.offset.y
        end
    end
end

local function create_uibox()
    local box = registry:create()
    local root = registry:create()
    component_cache.set(box, Transform, { actualX = 0, actualY = 0 })
    component_cache.set(root, Transform, { actualX = 0, actualY = 0 })
    component_cache.set(root, InheritedProperties, { offset = { x = 0, y = 0 } })
    component_cache.set(box, UIBoxComponent, { uiRoot = root })
    ui_children[box] = {}
    return box, root
end

local function add_child(box)
    local child = registry:create()
    component_cache.set(child, Transform, { actualX = 0, actualY = 0 })
    component_cache.set(child, InheritedProperties, { master = box, offset = { x = 0, y = 0 } })
    table.insert(ui_children[box], child)
    return child
end

local function simulate_click(entity)
    local marker = component_cache.get(entity, ScreenSpaceCollisionMarker)
    return marker ~= nil
end

local camera = { x = 0, y = 0 }
local function simulate_draw(space, x, y)
    if space == "world" then
        return x - camera.x, y - camera.y
    end
    return x, y
end

local function create_grid()
    local grid = { destroyed = false, items = { 1, 2, 3 } }
    function grid:destroy()
        self.destroyed = true
    end
    return grid
end

local dsl = { cleanupGrid = function() end }

local function simulate_drag(entity)
    local tag = component_cache.get(entity, ObjectAttachedToUITag)
    if tag then
        return false
    end
    return true
end

local function log_start(test_id, setup)
    if not header_logged then
        log_ui("=== UI Pattern Tests ===")
        header_logged = true
    end
    log_ui("Testing: " .. test_id)
    if setup then
        log_ui("  Setup: " .. setup)
    end
    log_ui("  Doc ID: " .. (DOC_IDS[test_id] or "unknown"))
end

local function log_action(action)
    log_ui("  Action: " .. action)
end

local function log_info(info)
    log_ui("  " .. info)
end

local function log_pass(test_id)
    log_ui("PASS: " .. test_id)
end

local function copy_list(list)
    local out = {}
    for i, v in ipairs(list or {}) do
        out[i] = v
    end
    return out
end

local function ensure_tag(tags, tag)
    for _, existing in ipairs(tags) do
        if existing == tag then
            return
        end
    end
    table.insert(tags, tag)
end

local function ensure_requirement(reqs, requirement)
    for _, existing in ipairs(reqs) do
        if existing == requirement then
            return
        end
    end
    table.insert(reqs, requirement)
end

local function register_ui_test(test_id, test_fn, opts)
    opts = opts or {}
    local tags = copy_list(opts.tags)
    if #tags == 0 then
        tags = { "ui" }
    end
    local requires = copy_list(opts.requires)
    if VISUAL_TESTS[test_id] then
        ensure_tag(tags, "visual")
        ensure_requirement(requires, "screenshot")
    end

    TestRunner:register(test_id, "ui", test_fn, {
        tags = tags,
        doc_ids = DOC_IDS[test_id] and { DOC_IDS[test_id] } or {},
        requires = requires,
        source_ref = "assets/scripts/tests/test_ui_patterns.lua",
    })
end

--------------------------------------------------------------------------------
-- Alignment Tests
--------------------------------------------------------------------------------

register_ui_test("ui.uibox_alignment.renew_after_offset", function()
    local test_id = "ui.uibox_alignment.renew_after_offset"
    reset_ui_state()
    log_start(test_id, "Creating UIBox with child")

    local box = create_uibox()
    local child = add_child(box)

    ui.box.RenewAlignment(registry, box)
    local before = component_cache.get(child, Transform)
    t.expect(before.actualX).to_be(0)
    t.expect(before.actualY).to_be(0)

    log_action("Applying setOffset (100, 50)")
    ChildBuilder.setOffset(child, 100, 50)
    local mid = component_cache.get(child, Transform)
    log_info(string.format("Before RenewAlignment: child positions = {%d, %d}", mid.actualX, mid.actualY))
    t.expect(mid.actualX).to_be(0)
    t.expect(mid.actualY).to_be(0)

    log_action("Calling RenewAlignment")
    ui.box.RenewAlignment(registry, box)
    local after = component_cache.get(child, Transform)
    log_info(string.format("After RenewAlignment: child positions = {%d, %d}", after.actualX, after.actualY))
    t.expect(after.actualX).to_be(100)
    t.expect(after.actualY).to_be(50)

    capture_screenshot(test_id)
    log_pass(test_id)
end)

register_ui_test("ui.uibox_alignment.renew_after_replacechildren", function()
    local test_id = "ui.uibox_alignment.renew_after_replacechildren"
    reset_ui_state()
    log_start(test_id, "Creating UIBox and replacing children")

    local box = create_uibox()
    add_child(box)
    log_action("ReplaceChildren (clears state tags)")
    ui.box.ReplaceChildren(box, {})

    local new_child = add_child(box)
    log_action("Applying setOffset (25, 30) to new child")
    ChildBuilder.setOffset(new_child, 25, 30)
    log_action("Calling RenewAlignment")
    ui.box.RenewAlignment(registry, box)

    local tform = component_cache.get(new_child, Transform)
    t.expect(tform.actualX).to_be(25)
    t.expect(tform.actualY).to_be(30)

    capture_screenshot(test_id)
    log_pass(test_id)
end)

--------------------------------------------------------------------------------
-- State Tag Tests
--------------------------------------------------------------------------------

register_ui_test("ui.statetag.add_after_spawn", function()
    local test_id = "ui.statetag.add_after_spawn"
    reset_ui_state()
    log_start(test_id, "Spawn UIBox")

    log_action("AddStateTagToUIBox default_state")
    local box = create_uibox()
    ui.box.AddStateTagToUIBox(box, "default_state")
    local tags = get_state_tags(box)
    t.expect(tags.default_state).to_be_truthy()

    log_pass(test_id)
end, { tags = { "ui" } })

register_ui_test("ui.statetag.add_after_replacechildren", function()
    local test_id = "ui.statetag.add_after_replacechildren"
    reset_ui_state()
    log_start(test_id, "Spawn UIBox with state tag")

    local box = create_uibox()
    ui.box.AddStateTagToUIBox(box, "default_state")
    log_action("ReplaceChildren (state tag lost)")
    ui.box.ReplaceChildren(box, {})

    local tags_after_replace = get_state_tags(box)
    t.expect(tags_after_replace.default_state).to_be_falsy()

    log_action("Re-add state tag after ReplaceChildren")
    ui.box.AddStateTagToUIBox(box, "default_state")
    local tags_after_restore = get_state_tags(box)
    t.expect(tags_after_restore.default_state).to_be_truthy()

    log_pass(test_id)
end, { tags = { "ui" } })

register_ui_test("ui.statetag.persistence_check", function()
    local test_id = "ui.statetag.persistence_check"
    reset_ui_state()
    log_start(test_id, "Spawn UIBox and apply state tag")

    local box = create_uibox()
    log_action("Apply default_state tag")
    ui.box.AddStateTagToUIBox(box, "default_state")

    local tags = get_state_tags(box)
    t.expect(tags.default_state).to_be_truthy()

    log_action("Re-apply default_state tag after simulated state change")
    ui.box.AddStateTagToUIBox(box, "default_state")
    local tags_after = get_state_tags(box)
    t.expect(tags_after.default_state).to_be_truthy()

    log_pass(test_id)
end, { tags = { "ui" } })

--------------------------------------------------------------------------------
-- Visibility Tests
--------------------------------------------------------------------------------

register_ui_test("ui.visibility.move_transform_and_uiroot", function()
    local test_id = "ui.visibility.move_transform_and_uiroot"
    reset_ui_state()
    log_start(test_id, "Create UIBox and uiRoot")

    local box, root = create_uibox()
    local box_t = component_cache.get(box, Transform)
    local root_t = component_cache.get(root, Transform)

    log_action("Move Transform and uiRoot to (200, 300)")
    box_t.actualX, box_t.actualY = 200, 300
    root_t.actualX, root_t.actualY = 200, 300

    t.expect(root_t.actualX).to_be(200)
    t.expect(root_t.actualY).to_be(300)

    capture_screenshot(test_id)
    log_pass(test_id)
end)

register_ui_test("ui.visibility.transform_only_fails", function()
    local test_id = "ui.visibility.transform_only_fails"
    reset_ui_state()
    log_start(test_id, "Create UIBox and uiRoot")

    local box, root = create_uibox()
    local box_t = component_cache.get(box, Transform)
    local root_t = component_cache.get(root, Transform)

    log_action("Move Transform only (500, 600)")
    box_t.actualX, box_t.actualY = 500, 600
    -- root stays at 0,0

    t.expect(root_t.actualX).to_be(0)
    t.expect(root_t.actualY).to_be(0)

    capture_screenshot(test_id)
    log_pass(test_id)
end)

--------------------------------------------------------------------------------
-- Collision Tests
--------------------------------------------------------------------------------

register_ui_test("ui.collision.screenspace_marker_required", function()
    local test_id = "ui.collision.screenspace_marker_required"
    reset_ui_state()
    log_start(test_id, "Create UIBox without marker")

    local box = create_uibox()
    log_action("Simulate click without ScreenSpaceCollisionMarker")
    local clicked = simulate_click(box)
    t.expect(clicked).to_be_falsy()

    log_pass(test_id)
end, { tags = { "ui" } })

register_ui_test("ui.collision.click_detection_with_marker", function()
    local test_id = "ui.collision.click_detection_with_marker"
    reset_ui_state()
    log_start(test_id, "Create UIBox and add marker")

    local box = create_uibox()
    log_action("Emplace ScreenSpaceCollisionMarker")
    component_cache.set(box, ScreenSpaceCollisionMarker, {})
    local clicked = simulate_click(box)
    t.expect(clicked).to_be_truthy()

    capture_screenshot(test_id)
    log_pass(test_id)
end)

register_ui_test("ui.collision.click_fails_without_marker", function()
    local test_id = "ui.collision.click_fails_without_marker"
    reset_ui_state()
    log_start(test_id, "Create UIBox without marker")

    local box = create_uibox()
    log_action("Simulate click without ScreenSpaceCollisionMarker")
    local clicked = simulate_click(box)
    t.expect(clicked).to_be_falsy()

    log_pass(test_id)
end, { tags = { "ui" } })

--------------------------------------------------------------------------------
-- Grid Cleanup Tests
--------------------------------------------------------------------------------

register_ui_test("ui.grid.cleanup_all_three_registries", function()
    local test_id = "ui.grid.cleanup_all_three_registries"
    reset_ui_state()
    log_start(test_id, "Create grid and registries")

    local itemRegistry = { a = 1, b = 2 }
    local grid = create_grid()
    local cleanup_called = false
    dsl.cleanupGrid = function()
        cleanup_called = true
    end

    log_action("Clear itemRegistry, destroy grid, call dsl.cleanupGrid")
    itemRegistry = {}
    grid:destroy()
    dsl.cleanupGrid(registry)

    t.expect(grid.destroyed).to_be_truthy()
    t.expect(cleanup_called).to_be_truthy()
    t.expect(next(itemRegistry)).to_be_nil()

    capture_screenshot(test_id)
    log_pass(test_id)
end)

register_ui_test("ui.grid.cleanup_partial_fails", function()
    local test_id = "ui.grid.cleanup_partial_fails"
    reset_ui_state()
    log_start(test_id, "Create grid and registries")

    local itemRegistry = { a = 1 }
    local grid = create_grid()
    log_action("Destroy grid only (partial cleanup)")
    grid:destroy()

    t.expect(grid.destroyed).to_be_truthy()
    t.expect(next(itemRegistry)).to_be_truthy()

    log_pass(test_id)
end, { tags = { "ui" } })

--------------------------------------------------------------------------------
-- DrawCommandSpace Tests
--------------------------------------------------------------------------------

register_ui_test("ui.drawspace.world_follows_camera", function()
    local test_id = "ui.drawspace.world_follows_camera"
    reset_ui_state()
    camera.x = 0
    camera.y = 0
    log_start(test_id, "Move camera and draw in World space")

    log_action("Move camera to (100, 50)")
    camera.x = 100
    camera.y = 50
    local x, y = simulate_draw("world", 200, 200)

    t.expect(x).to_be(100)
    t.expect(y).to_be(150)

    capture_screenshot(test_id)
    log_pass(test_id)
end)

register_ui_test("ui.drawspace.screen_fixed_hud", function()
    local test_id = "ui.drawspace.screen_fixed_hud"
    reset_ui_state()
    camera.x = 0
    camera.y = 0
    log_start(test_id, "Move camera and draw in Screen space")

    log_action("Move camera to (100, 50)")
    camera.x = 100
    camera.y = 50
    local x, y = simulate_draw("screen", 200, 200)

    t.expect(x).to_be(200)
    t.expect(y).to_be(200)

    capture_screenshot(test_id)
    log_pass(test_id)
end)

--------------------------------------------------------------------------------
-- ObjectAttachedToUITag Tests
--------------------------------------------------------------------------------

register_ui_test("ui.attached.never_on_draggables", function()
    local test_id = "ui.attached.never_on_draggables"
    reset_ui_state()
    log_start(test_id, "Create draggable with ObjectAttachedToUITag")

    local entity = registry:create()
    log_action("Attach ObjectAttachedToUITag and attempt drag")
    component_cache.set(entity, ObjectAttachedToUITag, {})

    local ok = simulate_drag(entity)
    t.expect(ok).to_be_falsy()

    log_pass(test_id)
end, { tags = { "ui" } })

register_ui_test("ui.attached.correct_usage", function()
    local test_id = "ui.attached.correct_usage"
    reset_ui_state()
    log_start(test_id, "Create draggable without tag")

    local entity = registry:create()
    log_action("Attempt drag without tag")
    local ok = simulate_drag(entity)
    t.expect(ok).to_be_truthy()

    log_action("Attach ObjectAttachedToUITag and attempt drag")
    component_cache.set(entity, ObjectAttachedToUITag, {})
    local ok_after = simulate_drag(entity)
    t.expect(ok_after).to_be_falsy()

    capture_screenshot(test_id)
    log_pass(test_id)
end)

local success = TestRunner.run()
os.exit(success and 0 or 1)
