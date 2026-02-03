-- assets/scripts/test/capabilities.lua
-- Detect and write test capability flags.

local json = require("test.json")

local Capabilities = {}

local function get_iso8601()
    local now = os.date("!*t")
    return string.format(
        "%04d-%02d-%02dT%02d:%02d:%02dZ",
        now.year, now.month, now.day,
        now.hour, now.min, now.sec
    )
end

local function get_platform()
    if _G.globals and _G.globals.platform then
        return tostring(_G.globals.platform.os or "unknown") .. "/" ..
            tostring(_G.globals.platform.arch or "unknown")
    end
    if jit then
        return tostring(jit.os or "unknown") .. "/" .. tostring(jit.arch or "unknown")
    end
    return "unknown/unknown"
end

local function ensure_dir(path)
    local dir = path:match("^(.*)/")
    if dir and dir ~= "" then
        os.execute('mkdir -p "' .. dir .. '" 2>/dev/null')
        os.execute('mkdir "' .. dir:gsub("/", "\\") .. '" 2>NUL')
    end
end

function Capabilities.detect()
    local screenshot_available = type(_G.capture_screenshot) == "function"
        or type(_G.take_screenshot) == "function"
    local log_capture_available = type(_G.capture_log_start) == "function"
        or type(_G.log_capture_start) == "function"

    local scene = _G.globals and _G.globals.scene or nil
    local test_scene_runnable = scene == nil or scene == "test"

    local output_writable = true
    local probe_path = "test_output/.capabilities_probe"
    ensure_dir(probe_path)
    local probe = io.open(probe_path, "w")
    if probe then
        probe:write("ok")
        probe:close()
        os.remove(probe_path)
    else
        output_writable = false
    end

    return {
        schema_version = "1.0",
        generated_at = get_iso8601(),
        platform = get_platform(),
        capabilities = {
            screenshot = screenshot_available,
            log_capture = log_capture_available,
            input_simulation = type(_G.simulate_input) == "function",
            headless = _G.globals and _G.globals.headless == true,
            network = false,
            gpu = true,
        },
        screenshot_available = screenshot_available,
        log_capture_available = log_capture_available,
        test_scene_runnable = test_scene_runnable,
        output_writable = output_writable,
    }
end

function Capabilities.write(path)
    local payload = json.encode(Capabilities.detect(), true)
    ensure_dir(path)
    local file = io.open(path, "w")
    if not file then
        return false
    end
    file:write(payload)
    file:close()
    return true
end

return Capabilities
