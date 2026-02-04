--- Run state sentinel for crash/hang detection.
--- Writes test_output/run_state.json at harness start, updates after each test,
--- and marks complete on graceful finish.
---
--- Usage:
---   local RunState = require("test.run_state")
---   RunState.init()               -- Call at harness start
---   RunState.test_start(test_id)  -- Before each test
---   RunState.test_end(test_id, passed)  -- After each test
---   RunState.complete(all_passed) -- At graceful finish
---
--- CI can detect crashes/hangs by checking:
---   - Missing run_state.json -> crash before harness started
---   - in_progress: true after timeout -> crash/hang during run
---   - last_test_started ~= last_test_completed -> crash in specific test
---
--- @module test.run_state

local RunState = {}

-- Configuration
local OUTPUT_DIR = "test_output"
local STATE_FILE = OUTPUT_DIR .. "/run_state.json"
local SCHEMA_VERSION = "1.0"

-- Internal state
local state = nil

--- Generate a unique run ID based on timestamp and random value.
--- @return string run_id
local function generate_run_id()
    local timestamp = os.time()
    local random_part = math.random(100000, 999999)
    return string.format("%d_%06d", timestamp, random_part)
end

--- Get current ISO8601 timestamp.
--- @return string iso8601 timestamp
local function get_iso8601()
    local now = os.date("!*t")
    return string.format(
        "%04d-%02d-%02dT%02d:%02d:%02dZ",
        now.year, now.month, now.day,
        now.hour, now.min, now.sec
    )
end

--- Get platform info string.
--- @return string platform info
local function get_platform()
    -- Try to detect platform from globals or environment
    local os_name = "unknown"
    local arch = "unknown"

    -- Check if we have access to platform info from engine
    if _G.globals and _G.globals.platform then
        os_name = _G.globals.platform.os or os_name
        arch = _G.globals.platform.arch or arch
    elseif jit then
        -- LuaJIT provides some info
        os_name = jit.os or os_name
        arch = jit.arch or arch
    end

    return os_name .. "/" .. arch
end

--- Get git commit SHA if available.
--- @return string|nil git_sha
local function get_git_sha()
    -- Try to read from a version file or environment
    if _G.globals and _G.globals.git_sha then
        return _G.globals.git_sha
    end

    -- Try to read from version file
    local version_file = io.open("version.txt", "r")
    if version_file then
        local content = version_file:read("*l")
        version_file:close()
        if content then
            return content:match("^%w+")
        end
    end

    return nil
end

--- Get engine version if available.
--- @return string|nil version
local function get_engine_version()
    if _G.globals and _G.globals.engine_version then
        return _G.globals.engine_version
    end
    return nil
end

--- Ensure output directory exists.
local function ensure_output_dir()
    -- Create directory using os.execute (cross-platform fallback)
    local success = os.execute("mkdir -p " .. OUTPUT_DIR .. " 2>/dev/null")
    if not success then
        -- Windows fallback
        os.execute('mkdir "' .. OUTPUT_DIR:gsub("/", "\\") .. '" 2>NUL')
    end
end

--- Write state to JSON file.
local function write_state()
    if not state then
        return false
    end

    ensure_output_dir()

    local file = io.open(STATE_FILE, "w")
    if not file then
        print("[RUN_STATE] ERROR: Could not write " .. STATE_FILE)
        return false
    end

    -- Simple JSON encoding (no external dependencies)
    local function encode_value(v)
        if v == nil then
            return "null"
        elseif type(v) == "boolean" then
            return v and "true" or "false"
        elseif type(v) == "number" then
            return tostring(v)
        elseif type(v) == "string" then
            return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
        elseif type(v) == "table" then
            local parts = {}
            -- Check if array or object
            local is_array = #v > 0 or next(v) == nil
            if is_array then
                for _, item in ipairs(v) do
                    table.insert(parts, encode_value(item))
                end
                return "[" .. table.concat(parts, ", ") .. "]"
            else
                for k, val in pairs(v) do
                    table.insert(parts, '"' .. tostring(k) .. '": ' .. encode_value(val))
                end
                return "{\n    " .. table.concat(parts, ",\n    ") .. "\n  }"
            end
        end
        return "null"
    end

    local json_parts = {
        '{',
        '  "schema_version": ' .. encode_value(state.schema_version) .. ',',
        '  "in_progress": ' .. encode_value(state.in_progress) .. ',',
        '  "run_id": ' .. encode_value(state.run_id) .. ',',
        '  "started_at": ' .. encode_value(state.started_at) .. ',',
        '  "commit": ' .. encode_value(state.commit) .. ',',
        '  "platform": ' .. encode_value(state.platform) .. ',',
        '  "engine_version": ' .. encode_value(state.engine_version) .. ',',
        '  "last_test_started": ' .. encode_value(state.last_test_started) .. ',',
        '  "last_test_completed": ' .. encode_value(state.last_test_completed) .. ',',
        '  "partial_counts": ' .. encode_value(state.partial_counts),
    }

    if state.completed_at then
        table.insert(json_parts, ',')
        table.insert(json_parts, '  "completed_at": ' .. encode_value(state.completed_at) .. ',')
        table.insert(json_parts, '  "passed": ' .. encode_value(state.passed))
    end

    table.insert(json_parts, '}')

    file:write(table.concat(json_parts, '\n'))
    file:close()

    return true
end

--- Initialize run state at harness start.
--- Must be called before any tests run.
--- @return boolean success
function RunState.init()
    print("[RUN_STATE] Initializing run state sentinel...")

    state = {
        schema_version = SCHEMA_VERSION,
        in_progress = true,
        run_id = generate_run_id(),
        started_at = get_iso8601(),
        commit = get_git_sha(),
        platform = get_platform(),
        engine_version = get_engine_version(),
        last_test_started = nil,
        last_test_completed = nil,
        partial_counts = {
            passed = 0,
            failed = 0,
            skipped = 0,
        },
        completed_at = nil,
        passed = nil,
    }

    local success = write_state()
    if success then
        print("[RUN_STATE] Run state initialized: " .. state.run_id)
    end

    return success
end

--- Mark a test as started.
--- Call this immediately before running each test.
--- @param test_id string The test identifier
function RunState.test_start(test_id)
    if not state then
        print("[RUN_STATE] WARNING: test_start called before init()")
        return
    end

    state.last_test_started = test_id
    write_state()

    print("[RUN_STATE] Test started: " .. test_id)
end

--- Mark a test as completed.
--- Call this immediately after each test finishes.
--- @param test_id string The test identifier
--- @param result string One of: "passed", "failed", "skipped"
function RunState.test_end(test_id, result)
    if not state then
        print("[RUN_STATE] WARNING: test_end called before init()")
        return
    end

    state.last_test_completed = test_id

    -- Update counts
    if result == "passed" then
        state.partial_counts.passed = state.partial_counts.passed + 1
    elseif result == "failed" then
        state.partial_counts.failed = state.partial_counts.failed + 1
    elseif result == "skipped" then
        state.partial_counts.skipped = state.partial_counts.skipped + 1
    end

    write_state()

    print("[RUN_STATE] Test completed: " .. test_id .. " (" .. result .. ")")
end

--- Mark the test run as complete.
--- Call this at graceful finish of all tests.
--- @param all_passed boolean Whether all tests passed
function RunState.complete(all_passed)
    if not state then
        print("[RUN_STATE] WARNING: complete called before init()")
        return
    end

    state.in_progress = false
    state.completed_at = get_iso8601()
    state.passed = all_passed

    write_state()

    local status = all_passed and "PASSED" or "FAILED"
    print("[RUN_STATE] Run complete: " .. status)
    print("[RUN_STATE]   Passed: " .. state.partial_counts.passed)
    print("[RUN_STATE]   Failed: " .. state.partial_counts.failed)
    print("[RUN_STATE]   Skipped: " .. state.partial_counts.skipped)
end

--- Get current run state (for debugging/inspection).
--- @return table|nil state
function RunState.get_state()
    return state
end

--- Get the state file path.
--- @return string path
function RunState.get_state_file()
    return STATE_FILE
end

--- Reset state (for testing purposes).
function RunState.reset()
    state = nil
end

return RunState
