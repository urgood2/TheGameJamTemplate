-- assets/scripts/tests/test_utils.lua
-- Assertion helpers and deterministic utilities for Phase 1 tests.

local TestUtils = {}

local DEFAULT_RNG_SEED = 12345
local spawned_entities = {}
local fallback_entity_id = 900000

local function log(prefix, msg)
    print(string.format("[%s] %s", prefix, msg))
end

local function fail(msg)
    local text = msg or "assertion failed"
    log("ASSERT", text)
    error(text, 2)
end

function TestUtils.assert_eq(actual, expected, msg)
    log("ASSERT", string.format("assert_eq: comparing actual=%s expected=%s", tostring(actual), tostring(expected)))
    if actual ~= expected then
        log("ASSERT", string.format(
            "assert_eq: FAIL - actual=%s expected=%s - msg: '%s'",
            tostring(actual), tostring(expected), tostring(msg or "assert_eq")
        ))
        fail(string.format("%s: expected %s, got %s", msg or "assert_eq", tostring(expected), tostring(actual)))
    end
    log("ASSERT", "assert_eq: PASS")
end

function TestUtils.assert_true(value, msg)
    log("ASSERT", string.format("assert_true: value=%s", tostring(value)))
    if not value then
        log("ASSERT", string.format("assert_true: FAIL - msg: '%s'", tostring(msg or "assert_true failed")))
        fail(msg or "assert_true failed")
    end
    log("ASSERT", "assert_true: PASS")
end

function TestUtils.assert_false(value, msg)
    log("ASSERT", string.format("assert_false: value=%s", tostring(value)))
    if value then
        log("ASSERT", string.format("assert_false: FAIL - msg: '%s'", tostring(msg or "assert_false failed")))
        fail(msg or "assert_false failed")
    end
    log("ASSERT", "assert_false: PASS")
end

function TestUtils.assert_nil(value, msg)
    log("ASSERT", string.format("assert_nil: value=%s", tostring(value)))
    if value ~= nil then
        log("ASSERT", string.format("assert_nil: FAIL - msg: '%s'", tostring(msg or "assert_nil failed")))
        fail(msg or "assert_nil failed")
    end
    log("ASSERT", "assert_nil: PASS")
end

function TestUtils.assert_not_nil(value, msg)
    log("ASSERT", string.format("assert_not_nil: value=%s", tostring(value)))
    if value == nil then
        log("ASSERT", string.format("assert_not_nil: FAIL - msg: '%s'", tostring(msg or "assert_not_nil failed")))
        fail(msg or "assert_not_nil failed")
    end
    log("ASSERT", "assert_not_nil: PASS")
end

function TestUtils.assert_error(fn, expected_error, msg)
    log("ASSERT", "assert_error: invoking function")
    local ok, err = pcall(fn)
    if ok then
        log("ASSERT", string.format("assert_error: FAIL - msg: '%s'", tostring(msg or "assert_error failed")))
        fail(msg or "assert_error failed")
    end
    if expected_error ~= nil then
        local err_text = tostring(err or "")
        local expected_text = tostring(expected_error)
        if not err_text:find(expected_text, 1, true) then
            log("ASSERT", string.format(
                "assert_error: FAIL - expected '%s' in error '%s'",
                expected_text, err_text
            ))
            fail(msg or ("assert_error failed: expected '" .. expected_text .. "'"))
        end
    end
    log("ASSERT", "assert_error: PASS")
    return err
end

function TestUtils.safe_filename(name)
    if not name or name == "" then
        return "unnamed"
    end
    local safe = tostring(name):lower()
    safe = safe:gsub("[^a-z0-9._%-]", "_")
    return safe
end

local function ensure_dir(path)
    if os.execute then
        os.execute(string.format("mkdir -p %s", path))
    end
end

function TestUtils.ensure_output_dirs()
    ensure_dir("test_output")
    ensure_dir("test_output/screenshots")
    ensure_dir("test_output/artifacts")
end

local function placeholder_png(path)
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
        fail("Could not write screenshot: " .. tostring(path))
    end
    file:write(png_bytes)
    file:close()
end

function TestUtils.capture_screenshot(name)
    TestUtils.ensure_output_dirs()
    local safe = TestUtils.safe_filename(name)
    local path = "test_output/screenshots/" .. safe .. ".png"
    if _G.screenshot and type(_G.screenshot.capture) == "function" then
        _G.screenshot.capture(path)
    elseif _G.TakeScreenshot then
        _G.TakeScreenshot(path)
    elseif _G.capture_screenshot then
        _G.capture_screenshot(path)
    else
        placeholder_png(path)
    end
    return path
end

local function step_engine_frame()
    if _G.step_frames and type(_G.step_frames) == "function" then
        _G.step_frames(1)
        return true
    end
    if _G.StepFrames and type(_G.StepFrames) == "function" then
        _G.StepFrames(1)
        return true
    end
    if _G.advance_frame and type(_G.advance_frame) == "function" then
        _G.advance_frame()
        return true
    end
    if _G.main_loop and type(_G.main_loop.step) == "function" then
        _G.main_loop.step()
        return true
    end
    if _G.timer and type(_G.timer.update) == "function" then
        _G.timer.update(1 / 60, true)
        return true
    end
    return false
end

function TestUtils.step_frames(frames)
    local count = tonumber(frames) or 1
    if count <= 0 then
        return
    end
    for _ = 1, count do
        step_engine_frame()
        if _G.component_cache and _G.component_cache.update_frame then
            _G.component_cache.update_frame()
        end
        if _G.entity_cache and _G.entity_cache.update_frame then
            _G.entity_cache.update_frame()
        end
        if _G.globals then
            _G.globals.frameCount = (_G.globals.frameCount or 0) + 1
        end
    end
end

function TestUtils.screenshot_after_frames(name, frames)
    local count = tonumber(frames) or 1
    log("SCREENSHOT", string.format("screenshot_after_frames: waiting %d frames...", count))
    TestUtils.step_frames(count)
    log("SCREENSHOT", string.format("screenshot_after_frames: capturing '%s'", tostring(name or "unnamed")))
    local path = TestUtils.capture_screenshot(name)
    local size_kb = "unknown size"
    local file = io.open(path, "rb")
    if file then
        local bytes = file:seek("end")
        file:close()
        if bytes then
            size_kb = string.format("%.0fKB", bytes / 1024)
        end
    end
    log("SCREENSHOT", string.format(
        "screenshot_after_frames: written to %s (%s)",
        path,
        size_kb
    ))
    return path
end

function TestUtils.spawn_test_entity(opts)
    opts = opts or {}
    local entity
    if _G.registry and type(_G.registry.create) == "function" then
        entity = _G.registry:create()
    else
        fallback_entity_id = fallback_entity_id + 1
        entity = fallback_entity_id
    end
    table.insert(spawned_entities, entity)
    if opts.components and _G.component_cache and type(_G.component_cache.set) == "function" then
        for comp, data in pairs(opts.components) do
            _G.component_cache.set(entity, comp, data)
        end
    end
    return entity
end

local function clear_spawned_entities()
    if #spawned_entities == 0 then
        return 0
    end
    local cleared = #spawned_entities
    if _G.registry and type(_G.registry.destroy) == "function" then
        for _, entity in ipairs(spawned_entities) do
            _G.registry:destroy(entity)
            if _G.component_cache and _G.component_cache.invalidate then
                _G.component_cache.invalidate(entity)
            end
        end
    end
    spawned_entities = {}
    return cleared
end

function TestUtils.reset_world()
    log("RESET", "reset_world: clearing test entities...")
    local cleared = clear_spawned_entities()
    log("RESET", string.format("reset_world: entities cleared: %d", cleared))

    if _G.component_cache then
        if type(_G.component_cache.clear) == "function" then
            _G.component_cache.clear()
        elseif type(_G.component_cache._reset) == "function" then
            _G.component_cache._reset()
        end
    end

    if _G.entity_cache and type(_G.entity_cache.clear) == "function" then
        _G.entity_cache.clear()
    end

    if _G.timer and type(_G.timer._reset) == "function" then
        _G.timer._reset()
    end

    if _G.reset_ui_registry and type(_G.reset_ui_registry) == "function" then
        _G.reset_ui_registry()
    end
    if _G.reset_physics_world and type(_G.reset_physics_world) == "function" then
        _G.reset_physics_world()
    end

    log("RESET", string.format("reset_world: resetting RNG seed to: %d", DEFAULT_RNG_SEED))
    math.randomseed(DEFAULT_RNG_SEED)
    if _G.engine_rng and type(_G.engine_rng.seed) == "function" then
        _G.engine_rng.seed(DEFAULT_RNG_SEED)
    end

    if _G.reset_world and type(_G.reset_world) == "function" then
        _G.reset_world()
    end

    if _G.camera then
        if type(_G.camera.set_position) == "function" then
            _G.camera.set_position(0, 0)
            log("RESET", "reset_world: camera reset to default")
        end
        if type(_G.camera.set_zoom) == "function" then
            _G.camera.set_zoom(1.0)
        end
    else
        log("RESET", "reset_world: camera reset skipped (no camera)")
    end

    if _G.ui_root and type(_G.ui_root.reset) == "function" then
        _G.ui_root.reset()
    end

    log("RESET", "reset_world: COMPLETE")
end

TestUtils.DEFAULT_RNG_SEED = DEFAULT_RNG_SEED

return TestUtils
