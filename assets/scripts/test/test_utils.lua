-- assets/scripts/test/test_utils.lua
-- Assertion helpers and deterministic utilities.

local TestUtils = {}

local log_handle = nil
local current_test_id = nil
local screenshot_hook = nil
local artifact_hook = nil

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
    if actual ~= expected then
        fail(string.format("%s: expected %s, got %s", msg or "assert_eq", tostring(expected), tostring(actual)))
    end
end

function TestUtils.assert_neq(actual, expected, msg)
    if actual == expected then
        fail(string.format("%s: expected != %s", msg or "assert_neq", tostring(expected)))
    end
end

function TestUtils.assert_true(value, msg)
    if not value then
        fail(msg or "assert_true failed")
    end
end

function TestUtils.assert_false(value, msg)
    if value then
        fail(msg or "assert_false failed")
    end
end

function TestUtils.assert_nil(value, msg)
    if value ~= nil then
        fail(msg or "assert_nil failed")
    end
end

function TestUtils.assert_not_nil(value, msg)
    if value == nil then
        fail(msg or "assert_not_nil failed")
    end
end

function TestUtils.assert_gt(actual, expected, msg)
    if not (actual > expected) then
        fail(msg or "assert_gt failed")
    end
end

function TestUtils.assert_gte(actual, expected, msg)
    if not (actual >= expected) then
        fail(msg or "assert_gte failed")
    end
end

function TestUtils.assert_lt(actual, expected, msg)
    if not (actual < expected) then
        fail(msg or "assert_lt failed")
    end
end

function TestUtils.assert_lte(actual, expected, msg)
    if not (actual <= expected) then
        fail(msg or "assert_lte failed")
    end
end

function TestUtils.assert_contains(haystack, needle, msg)
    if type(haystack) ~= "string" or not haystack:find(needle, 1, true) then
        fail(msg or "assert_contains failed")
    end
end

function TestUtils.assert_throws(fn, msg)
    local ok = pcall(fn)
    if ok then
        fail(msg or "assert_throws failed")
    end
end

function TestUtils.assert_error(fn, expected, msg)
    local ok, err = pcall(fn)
    if ok then
        fail(msg or "assert_error failed")
    end
    if expected and not tostring(err):find(expected, 1, true) then
        fail(string.format("%s: expected error containing '%s', got '%s'", msg or "assert_error", tostring(expected), tostring(err)))
    end
end

function TestUtils.safe_filename(name)
    local safe = tostring(name or ""):gsub("[^%w%._-]", "_")
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
    os.execute('rm -rf test_output/screenshots 2>/dev/null')
    os.execute('rm -rf test_output/artifacts 2>/dev/null')
    os.execute('rmdir /s /q test_output\\screenshots 2>NUL')
    os.execute('rmdir /s /q test_output\\artifacts 2>NUL')
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

function TestUtils.capture_screenshot(name)
    TestUtils.ensure_output_dirs()
    local safe = TestUtils.safe_filename(name)
    local path = "test_output/screenshots/" .. safe .. ".png"
    if _G.TakeScreenshot then
        _G.TakeScreenshot(path)
    elseif _G.capture_screenshot then
        _G.capture_screenshot(path)
    else
        placeholder_png(path)
    end
    if screenshot_hook and current_test_id then
        screenshot_hook(current_test_id, path)
    end
    TestUtils.record_artifact(path)
    return path
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

function TestUtils.write_file(path, content)
    local file = io.open(path, "w")
    if not file then
        fail("Could not write file: " .. tostring(path))
    end
    file:write(content or "")
    file:write("\n")
    file:close()
end

function TestUtils.reset_world()
    if _G.component_cache and _G.component_cache.clear then
        _G.component_cache.clear()
    elseif _G.component_cache and _G.component_cache._reset then
        _G.component_cache._reset()
    end

    math.randomseed(12345)

    if _G.engine_rng and _G.engine_rng.seed then
        _G.engine_rng.seed(12345)
    end

    if _G.reset_world then
        _G.reset_world()
    end

    if _G.camera and _G.camera.set_position then
        _G.camera.set_position(0, 0)
    end
    if _G.camera and _G.camera.set_zoom then
        _G.camera.set_zoom(1.0)
    end

    if _G.ui_root and _G.ui_root.reset then
        _G.ui_root.reset()
    end

    TestUtils.log("[RESET] World reset complete")
end

return TestUtils
