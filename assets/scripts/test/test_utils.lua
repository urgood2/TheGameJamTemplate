-- assets/scripts/test/test_utils.lua
-- Assertion helpers and deterministic utilities.

local TestUtils = {}

TestUtils.DEFAULT_SEED = 12345

local log_handle = nil
local current_test_id = nil
local screenshot_hook = nil
local artifact_hook = nil
local spawned_entities = {}
local fallback_entity_id = 900000

local function fail(msg)
    error(msg or "assertion failed", 2)
end

local function escape_json_string(value)
    return value
        :gsub('\\', '\\\\')
        :gsub('"', '\\"')
        :gsub('\n', '\\n')
        :gsub('\r', '\\r')
        :gsub('\t', '\\t')
end

local function is_array(tbl)
    if type(tbl) ~= "table" then
        return false
    end
    local count = 0
    for k in pairs(tbl) do
        if type(k) ~= "number" then
            return false
        end
        if k > count then
            count = k
        end
    end
    for i = 1, count do
        if tbl[i] == nil then
            return false
        end
    end
    return true
end

local function encode_json_value(value, indent, visited)
    visited = visited or {}
    local value_type = type(value)
    if value_type == "nil" then
        return "null"
    end
    if value_type == "boolean" then
        return value and "true" or "false"
    end
    if value_type == "number" then
        return tostring(value)
    end
    if value_type == "string" then
        return '"' .. escape_json_string(value) .. '"'
    end
    if value_type ~= "table" then
        return '"' .. escape_json_string(tostring(value)) .. '"'
    end
    if visited[value] then
        return '"<cycle>"'
    end
    visited[value] = true

    indent = indent or 0
    local next_indent = indent + 2
    local padding = string.rep(" ", indent)
    local next_padding = string.rep(" ", next_indent)

    if is_array(value) then
        if #value == 0 then
            visited[value] = nil
            return "[]"
        end
        local items = {}
        for i = 1, #value do
            table.insert(items, next_padding .. encode_json_value(value[i], next_indent, visited))
        end
        visited[value] = nil
        return "[\n" .. table.concat(items, ",\n") .. "\n" .. padding .. "]"
    end

    local keys = {}
    for k in pairs(value) do
        table.insert(keys, k)
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)

    if #keys == 0 then
        visited[value] = nil
        return "{}"
    end

    local items = {}
    for _, key in ipairs(keys) do
        local key_str = tostring(key)
        local encoded = encode_json_value(value[key], next_indent, visited)
        table.insert(items, next_padding .. '"' .. escape_json_string(key_str) .. '": ' .. encoded)
    end
    visited[value] = nil
    return "{\n" .. table.concat(items, ",\n") .. "\n" .. padding .. "}"
end

local function ensure_dir(path)
    local ok = os.execute(string.format('mkdir -p "%s" 2>/dev/null', path))
    if ok == nil or ok == false then
        os.execute(string.format('mkdir "%s" 2>NUL', path:gsub("/", "\\")))
    end
end

local function touch(path)
    local handle = io.open(path, "w")
    if handle then
        handle:close()
    end
end

function TestUtils.assert_eq(actual, expected, msg)
    TestUtils.log(string.format("[ASSERT] assert_eq: comparing actual=%s expected=%s", tostring(actual), tostring(expected)))
    if actual ~= expected then
        local message = string.format("%s: expected %s, got %s", msg or "assert_eq", tostring(expected), tostring(actual))
        TestUtils.log(string.format("[ASSERT] assert_eq: FAIL - actual=%s expected=%s - msg: '%s'", tostring(actual), tostring(expected), msg or ""))
        fail(message)
    end
    TestUtils.log("[ASSERT] assert_eq: PASS")
end

function TestUtils.assert_neq(actual, expected, msg)
    TestUtils.log(string.format("[ASSERT] assert_neq: comparing actual=%s expected=%s", tostring(actual), tostring(expected)))
    if actual == expected then
        TestUtils.log(string.format("[ASSERT] assert_neq: FAIL - actual=%s expected=%s - msg: '%s'", tostring(actual), tostring(expected), msg or ""))
        fail(string.format("%s: expected != %s", msg or "assert_neq", tostring(expected)))
    end
    TestUtils.log("[ASSERT] assert_neq: PASS")
end

function TestUtils.assert_true(value, msg)
    TestUtils.log(string.format("[ASSERT] assert_true: value=%s", tostring(value)))
    if not value then
        TestUtils.log(string.format("[ASSERT] assert_true: FAIL - msg: '%s'", msg or ""))
        fail(msg or "assert_true failed")
    end
    TestUtils.log("[ASSERT] assert_true: PASS")
end

function TestUtils.assert_false(value, msg)
    TestUtils.log(string.format("[ASSERT] assert_false: value=%s", tostring(value)))
    if value then
        TestUtils.log(string.format("[ASSERT] assert_false: FAIL - msg: '%s'", msg or ""))
        fail(msg or "assert_false failed")
    end
    TestUtils.log("[ASSERT] assert_false: PASS")
end

function TestUtils.assert_nil(value, msg)
    TestUtils.log(string.format("[ASSERT] assert_nil: value=%s", tostring(value)))
    if value ~= nil then
        TestUtils.log(string.format("[ASSERT] assert_nil: FAIL - msg: '%s'", msg or ""))
        fail(msg or "assert_nil failed")
    end
    TestUtils.log("[ASSERT] assert_nil: PASS")
end

function TestUtils.assert_not_nil(value, msg)
    TestUtils.log(string.format("[ASSERT] assert_not_nil: value=%s", tostring(value)))
    if value == nil then
        TestUtils.log(string.format("[ASSERT] assert_not_nil: FAIL - msg: '%s'", msg or ""))
        fail(msg or "assert_not_nil failed")
    end
    TestUtils.log("[ASSERT] assert_not_nil: PASS")
end

function TestUtils.assert_gt(actual, expected, msg)
    TestUtils.log(string.format("[ASSERT] assert_gt: comparing actual=%s expected=%s", tostring(actual), tostring(expected)))
    if not (actual > expected) then
        TestUtils.log(string.format("[ASSERT] assert_gt: FAIL - msg: '%s'", msg or ""))
        fail(msg or "assert_gt failed")
    end
    TestUtils.log("[ASSERT] assert_gt: PASS")
end

function TestUtils.assert_gte(actual, expected, msg)
    TestUtils.log(string.format("[ASSERT] assert_gte: comparing actual=%s expected=%s", tostring(actual), tostring(expected)))
    if not (actual >= expected) then
        TestUtils.log(string.format("[ASSERT] assert_gte: FAIL - msg: '%s'", msg or ""))
        fail(msg or "assert_gte failed")
    end
    TestUtils.log("[ASSERT] assert_gte: PASS")
end

function TestUtils.assert_lt(actual, expected, msg)
    TestUtils.log(string.format("[ASSERT] assert_lt: comparing actual=%s expected=%s", tostring(actual), tostring(expected)))
    if not (actual < expected) then
        TestUtils.log(string.format("[ASSERT] assert_lt: FAIL - msg: '%s'", msg or ""))
        fail(msg or "assert_lt failed")
    end
    TestUtils.log("[ASSERT] assert_lt: PASS")
end

function TestUtils.assert_lte(actual, expected, msg)
    TestUtils.log(string.format("[ASSERT] assert_lte: comparing actual=%s expected=%s", tostring(actual), tostring(expected)))
    if not (actual <= expected) then
        TestUtils.log(string.format("[ASSERT] assert_lte: FAIL - msg: '%s'", msg or ""))
        fail(msg or "assert_lte failed")
    end
    TestUtils.log("[ASSERT] assert_lte: PASS")
end

function TestUtils.assert_contains(haystack, needle, msg)
    TestUtils.log(string.format("[ASSERT] assert_contains: haystack=%s needle=%s", tostring(haystack), tostring(needle)))
    if type(haystack) ~= "string" or not haystack:find(needle, 1, true) then
        TestUtils.log(string.format("[ASSERT] assert_contains: FAIL - msg: '%s'", msg or ""))
        fail(msg or "assert_contains failed")
    end
    TestUtils.log("[ASSERT] assert_contains: PASS")
end

function TestUtils.assert_throws(fn, msg)
    TestUtils.log("[ASSERT] assert_throws: expecting throw")
    local ok = pcall(fn)
    if ok then
        TestUtils.log(string.format("[ASSERT] assert_throws: FAIL - msg: '%s'", msg or ""))
        fail(msg or "assert_throws failed")
    end
    TestUtils.log("[ASSERT] assert_throws: PASS")
    return true
end

function TestUtils.assert_error(fn, expected, msg)
    if msg == nil and expected ~= nil then
        msg = expected
        expected = nil
    end
    TestUtils.log("[ASSERT] assert_error: expecting error")
    local ok, err = pcall(fn)
    if ok then
        TestUtils.log(string.format("[ASSERT] assert_error: FAIL - msg: '%s'", msg or ""))
        fail(msg or "assert_error failed")
    end
    if expected and not tostring(err):find(expected, 1, true) then
        TestUtils.log(string.format("[ASSERT] assert_error: FAIL - expected '%s' got '%s'", tostring(expected), tostring(err)))
        fail(string.format("%s: expected error containing '%s', got '%s'", msg or "assert_error", tostring(expected), tostring(err)))
    end
    TestUtils.log("[ASSERT] assert_error: PASS")
end

function TestUtils.safe_filename(name)
    local safe = tostring(name or ""):lower():gsub("[^a-z0-9%._-]", "_")
    safe = safe:gsub("_+", "_")
    if safe == "" then
        safe = "unnamed"
    end
    return safe
end

function TestUtils.basename(path)
    if not path then
        return "unknown"
    end
    local clean = path:gsub("^@", "")
    return clean:match("([^/\\]+)$") or clean
end

function TestUtils.get_iso8601()
    local now = os.date("!*t")
    return string.format(
        "%04d-%02d-%02dT%02d:%02d:%02dZ",
        now.year, now.month, now.day,
        now.hour, now.min, now.sec
    )
end

function TestUtils.get_platform()
    if _G.globals and _G.globals.platform then
        return tostring(_G.globals.platform.os or "unknown") .. "/" .. tostring(_G.globals.platform.arch or "unknown")
    end
    if jit then
        return tostring(jit.os or "unknown") .. "/" .. tostring(jit.arch or "unknown")
    end
    return "unknown/unknown"
end

function TestUtils.get_git_sha()
    if _G.globals and _G.globals.git_sha then
        return _G.globals.git_sha
    end
    local handle = io.open("version.txt", "r")
    if handle then
        local line = handle:read("*l")
        handle:close()
        if line and line ~= "" then
            return line:match("^(%w+)")
        end
    end
    return nil
end

function TestUtils.get_engine_version()
    if _G.globals and _G.globals.engine_version then
        return _G.globals.engine_version
    end
    return nil
end

function TestUtils.ensure_output_dirs()
    ensure_dir("test_output")
    ensure_dir("test_output/screenshots")
    ensure_dir("test_output/artifacts")
    touch("test_output/screenshots/.gitkeep")
    touch("test_output/artifacts/.gitkeep")
end

function TestUtils.wipe_output()
    os.execute('rm -f test_output/*.json test_output/*.md test_output/*.xml test_output/*.txt 2>/dev/null')
    os.execute('rm -f test_output/screenshots/* 2>/dev/null')
    os.execute('rm -f test_output/artifacts/* 2>/dev/null')
    os.execute('del /q test_output\\screenshots\\* 2>NUL')
    os.execute('del /q test_output\\artifacts\\* 2>NUL')
    TestUtils.ensure_output_dirs()
end

function TestUtils.open_log(path)
    if log_handle then
        log_handle:close()
    end
    log_handle = io.open(path, "w")
end

function TestUtils.log(message)
    local line = tostring(message or "")
    print(line)
    if log_handle then
        log_handle:write(line .. "\n")
        log_handle:flush()
    end
end

function TestUtils.close_log()
    if log_handle then
        log_handle:close()
        log_handle = nil
    end
end

function TestUtils.set_current_test(test_id)
    current_test_id = test_id
end

function TestUtils.set_screenshot_hook(fn)
    screenshot_hook = fn
end

function TestUtils.set_artifact_hook(fn)
    artifact_hook = fn
end

function TestUtils.record_artifact(path, test_id)
    local id = test_id or current_test_id
    if artifact_hook and id and path then
        artifact_hook(id, path)
    end
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

local function file_size(path)
    local handle = io.open(path, "rb")
    if not handle then
        return 0
    end
    local size = handle:seek("end") or 0
    handle:close()
    return size
end

function TestUtils.capture_screenshot(name)
    TestUtils.ensure_output_dirs()
    local safe = TestUtils.safe_filename(name)
    local path = "test_output/screenshots/" .. safe .. ".png"
    TestUtils.log(string.format("[SCREENSHOT] capture_screenshot: capturing '%s'", safe))
    if _G.TakeScreenshot then
        _G.TakeScreenshot(path)
    elseif _G.capture_screenshot then
        _G.capture_screenshot(path)
    else
        placeholder_png(path)
    end
    local size = file_size(path)
    TestUtils.log(string.format("[SCREENSHOT] capture_screenshot: written to %s (%d bytes)", path, size))
    if screenshot_hook and current_test_id then
        screenshot_hook(current_test_id, path)
    end
    TestUtils.record_artifact(path)
    return path
end

function TestUtils.step_frames(n)
    local frames = tonumber(n) or 0
    if frames <= 0 then
        return
    end
    if _G.step_frames then
        _G.step_frames(frames)
        return
    end
    if _G.advance_frame then
        for _ = 1, frames do
            _G.advance_frame()
        end
        return
    end
    -- Fallback no-op loop for deterministic call sites.
    for _ = 1, frames do
        -- intentionally empty
    end
end

function TestUtils.screenshot_after_frames(name, n_frames)
    local frames = tonumber(n_frames) or 0
    TestUtils.log(string.format("[SCREENSHOT] screenshot_after_frames: waiting %d frames...", frames))
    TestUtils.step_frames(frames)
    TestUtils.log(string.format("[SCREENSHOT] screenshot_after_frames: capturing '%s'", tostring(name)))
    local path = TestUtils.capture_screenshot(name)
    local size = file_size(path)
    local size_kb = math.ceil(size / 1024)
    TestUtils.log(string.format("[SCREENSHOT] screenshot_after_frames: written to %s (%dKB)", path, size_kb))
    return path
end

local function clear_spawned_entities()
    if #spawned_entities == 0 then
        return 0
    end
    local cleared = 0
    if _G.registry and type(_G.registry.destroy) == "function" then
        for _, entity in ipairs(spawned_entities) do
            pcall(function() _G.registry:destroy(entity) end)
            cleared = cleared + 1
            if _G.component_cache and type(_G.component_cache.invalidate) == "function" then
                _G.component_cache.invalidate(entity)
            end
        end
    else
        cleared = #spawned_entities
    end
    spawned_entities = {}
    return cleared
end

function TestUtils.spawn_test_entity(opts)
    local options = opts or {}
    local entity = nil
    if _G.registry and type(_G.registry.create) == "function" then
        entity = _G.registry:create()
    else
        fallback_entity_id = fallback_entity_id + 1
        entity = fallback_entity_id
    end
    table.insert(spawned_entities, entity)
    if options.components and _G.component_cache and type(_G.component_cache.set) == "function" then
        for component, data in pairs(options.components) do
            _G.component_cache.set(entity, component, data)
        end
    end
    if options.init and type(options.init) == "function" then
        options.init(entity)
    end
    return entity
end

function TestUtils.write_json(path, data)
    local file = io.open(path, "w")
    if not file then
        fail("Could not write json: " .. tostring(path))
    end
    file:write(encode_json_value(data, 0))
    file:write("\n")
    file:close()
end

function TestUtils.write_file(path, content, add_newline)
    local file = io.open(path, "w")
    if not file then
        return false
    end
    file:write(content or "")
    if add_newline ~= false then
        file:write("\n")
    end
    file:close()
    return true
end

function TestUtils.reset_world()
    TestUtils.log("[RESET] reset_world: clearing test entities...")
    local cleared = clear_spawned_entities()
    local extra_cleared = 0
    if _G.clear_all_test_entities then
        local ok, result = pcall(_G.clear_all_test_entities)
        if ok and type(result) == "number" then
            extra_cleared = result
        end
    end
    TestUtils.log(string.format("[RESET] reset_world: entities cleared: %d", cleared + extra_cleared))

    TestUtils.log("[RESET] reset_world: resetting registries...")
    if _G.reset_ui_registry then
        pcall(_G.reset_ui_registry)
    end
    if _G.reset_physics_world then
        pcall(_G.reset_physics_world)
    end
    if _G.component_cache and _G.component_cache.clear then
        _G.component_cache.clear()
    elseif _G.component_cache and _G.component_cache._reset then
        _G.component_cache._reset()
    end

    TestUtils.log(string.format("[RESET] reset_world: resetting RNG seed to: %d", TestUtils.DEFAULT_SEED))
    math.randomseed(TestUtils.DEFAULT_SEED)
    if _G.engine_rng and _G.engine_rng.seed then
        _G.engine_rng.seed(TestUtils.DEFAULT_SEED)
    end

    if _G.reset_world then
        pcall(_G.reset_world)
    end

    if _G.camera and _G.camera.set_position then
        _G.camera.set_position(0, 0)
    end
    if _G.camera and _G.camera.set_zoom then
        _G.camera.set_zoom(1.0)
    end
    TestUtils.log("[RESET] reset_world: camera reset to default")

    if _G.ui_root and _G.ui_root.reset then
        _G.ui_root.reset()
    end

    TestUtils.log("[RESET] reset_world: COMPLETE")
end

return TestUtils
