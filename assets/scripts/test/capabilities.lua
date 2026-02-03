-- assets/scripts/test/capabilities.lua
-- Detect and write test capability flags (Go/No-Go gates).
--
-- Phase 1 (bd-12l.6): Enhanced with full schema support
--
-- Schema:
--   schema_version: "1.0"
--   generated_at: ISO 8601 timestamp
--   gates: Go/No-Go flags (must all be true to run full suite)
--   details: Implementation specifics
--   environment: Platform/rendering info
--   capabilities: Individual capability flags
--
-- Usage:
--   local caps = Capabilities.detect()
--   local ok, reason = Capabilities.check_requirements(caps, {"screenshot", "log_capture"})
--   if not ok then print("SKIP: " .. reason) end

-- Optional JSON encoder
local json = nil
pcall(function() json = require("test.json") end)

local Capabilities = {}

-- Cache for detected capabilities
local cached_caps = nil

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

function Capabilities.detect(force_refresh)
    if cached_caps and not force_refresh then
        return cached_caps
    end

    print("[CAPS] Detecting capabilities...")

    -- Screenshot capability detection
    local screenshot_available = false
    local screenshot_api = nil
    if type(_G.TakeScreenshot) == "function" then
        screenshot_available = true
        screenshot_api = "TakeScreenshot"
    elseif type(_G.capture_screenshot) == "function" then
        screenshot_available = true
        screenshot_api = "capture_screenshot"
    elseif type(_G.take_screenshot) == "function" then
        screenshot_available = true
        screenshot_api = "take_screenshot"
    end

    -- Log capture detection
    local log_capture_available = false
    local log_capture_method = nil
    if type(_G.capture_log_start) == "function" then
        log_capture_available = true
        log_capture_method = "capture_log_start/end"
    elseif type(_G.log_capture_start) == "function" then
        log_capture_available = true
        log_capture_method = "log_capture_start/end"
    elseif type(_G.test_logger) == "table" then
        log_capture_available = true
        log_capture_method = "test_logger"
    end

    -- Test scene detection
    local scene = _G.globals and _G.globals.scene or nil
    local test_scene_runnable = false
    if _G.TEST_SCENE or _G.test_scene_loaded or _G.force_test_scene then
        test_scene_runnable = true
    elseif scene and tostring(scene):lower() == "test" then
        test_scene_runnable = true
    elseif os.getenv and os.getenv("TEST_SCENE") == "1" then
        test_scene_runnable = true
    end

    -- World reset detection
    local world_reset_available = false
    local world_reset_strategy = nil
    if type(_G.reset_world) == "function" then
        world_reset_available = true
        world_reset_strategy = "reset_world()"
    else
        -- Try loading test_utils for reset
        local ok, test_utils = pcall(require, "test.test_utils")
        if ok and test_utils and type(test_utils.reset_world) == "function" then
            world_reset_available = true
            world_reset_strategy = "test_utils.reset_world()"
        end
    end

    -- Output writable detection
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

    -- Input simulation
    local input_simulation = type(_G.simulate_input) == "function"
        or type(_G.input_simulate) == "function"

    -- Environment info
    local resolution = "unknown"
    local dpi_scale = 1.0
    local renderer = "unknown"
    if _G.globals then
        if _G.globals.screen_width and _G.globals.screen_height then
            resolution = tostring(_G.globals.screen_width) .. "x" .. tostring(_G.globals.screen_height)
        end
        if _G.globals.dpi_scale then
            dpi_scale = _G.globals.dpi_scale
        end
        if _G.globals.renderer then
            renderer = _G.globals.renderer
        elseif _G.globals.graphics_api then
            renderer = _G.globals.graphics_api
        end
    end

    -- UBS detection (Justfile-based)
    local ubs_identified = false
    local ubs_command = "just build-debug && just test"
    local ubs_quick = "just test"
    local ubs_pass_fail = "Exit code 0 = PASS; non-zero = FAIL"
    local ubs_log = "stdout/stderr"
    local justfile = io.open("Justfile", "r")
    if justfile then
        ubs_identified = true
        justfile:close()
    end

    cached_caps = {
        schema_version = "1.0",
        generated_at = get_iso8601(),

        -- Go/No-Go gates (critical requirements)
        gates = {
            deterministic_test_scene = test_scene_runnable,
            test_output_writable = output_writable,
            screenshot_capture = screenshot_available,
            log_capture = log_capture_available,
            world_reset = world_reset_available,
            ubs_identified = ubs_identified,
        },

        -- Implementation details
        details = {
            screenshot_api = screenshot_api,
            screenshot_timing = "end_of_frame",
            log_capture_method = log_capture_method,
            world_reset_strategy = world_reset_strategy,
            ubs_command = ubs_command,
            ubs_quick_command = ubs_quick,
            ubs_pass_fail = ubs_pass_fail,
            ubs_log_location = ubs_log,
        },

        -- Environment info
        environment = {
            platform = get_platform(),
            renderer = renderer,
            resolution = resolution,
            dpi_scale = dpi_scale,
        },

        -- Individual capabilities for test requirements
        capabilities = {
            screenshot = screenshot_available,
            log_capture = log_capture_available,
            input_simulation = input_simulation,
            headless = _G.globals and _G.globals.headless == true,
            network = false,  -- Currently not supported
            gpu = renderer ~= "unknown" and renderer ~= "none",
            world_reset = world_reset_available,
            determinism = test_scene_runnable,
            ubs = ubs_identified,
        },
    }

    print(string.format("[CAPS] Detected: screenshot=%s, log_capture=%s, world_reset=%s, output_writable=%s",
        tostring(screenshot_available), tostring(log_capture_available),
        tostring(world_reset_available), tostring(output_writable)))

    return cached_caps
end

--- Check if a single capability is available.
-- @param cap_name string Capability name (e.g., "screenshot", "log_capture")
-- @return boolean True if capability is available
function Capabilities.has(cap_name)
    local caps = Capabilities.detect()
    return caps.capabilities[cap_name] == true
end

--- Check if all required capabilities are available.
-- @param requirements table Array of capability names (e.g., {"screenshot", "log_capture"})
-- @return boolean, string True if all available, or false with missing capability name
function Capabilities.check_requirements(requirements)
    if not requirements or #requirements == 0 then
        return true, nil
    end

    local caps = Capabilities.detect()
    for _, req in ipairs(requirements) do
        if not caps.capabilities[req] then
            return false, req
        end
    end
    return true, nil
end

--- Check if all Go/No-Go gates pass.
-- @return boolean, table True if all pass, or false with list of failed gates
function Capabilities.check_gates()
    local caps = Capabilities.detect()
    local failed = {}

    for gate, passed in pairs(caps.gates) do
        if not passed then
            table.insert(failed, gate)
        end
    end

    table.sort(failed)
    return #failed == 0, failed
end

--- Get a human-readable summary of capabilities.
-- @return string Multi-line summary
function Capabilities.summary()
    local caps = Capabilities.detect()
    local lines = {
        "=== Capabilities Summary ===",
        string.format("Platform: %s", caps.environment.platform),
        string.format("Resolution: %s @ %.1fx DPI", caps.environment.resolution, caps.environment.dpi_scale),
        "",
        "Go/No-Go Gates:",
    }

    for gate, passed in pairs(caps.gates) do
        table.insert(lines, string.format("  %s: %s", gate, passed and "PASS" or "FAIL"))
    end

    table.insert(lines, "")
    table.insert(lines, "Capabilities:")
    for cap, available in pairs(caps.capabilities) do
        table.insert(lines, string.format("  %s: %s", cap, available and "YES" or "NO"))
    end

    return table.concat(lines, "\n")
end

--- Clear cached capabilities (useful for testing).
function Capabilities.clear_cache()
    cached_caps = nil
end

--- Write capabilities.json to the specified path.
-- @param path string Output file path
-- @return boolean True if successful
function Capabilities.write(path)
    path = path or "test_output/capabilities.json"

    if not json or not json.encode then
        -- Fallback to minimal JSON
        print("[CAPS] WARNING: json module not available, using fallback encoder")
        local caps = Capabilities.detect()
        local parts = {
            '{"schema_version":"1.0"',
            ',"generated_at":"' .. caps.generated_at .. '"',
        }
        -- This is a simplified fallback - full capabilities need json module
        local payload = table.concat(parts, "") .. "}"
        ensure_dir(path)
        local file = io.open(path, "w")
        if not file then return false end
        file:write(payload .. "\n")
        file:close()
        return true
    end

    local payload = json.encode(Capabilities.detect(), true)
    ensure_dir(path)
    local file = io.open(path, "w")
    if not file then
        print("[CAPS] ERROR: Could not write to " .. path)
        return false
    end
    file:write(payload)
    file:close()
    print("[CAPS] Written capabilities to " .. path)
    return true
end

return Capabilities
