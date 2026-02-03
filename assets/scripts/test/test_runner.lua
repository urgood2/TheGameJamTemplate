-- assets/scripts/test/test_runner.lua
-- Main test harness for engine pattern verification.

local TestRunner = {}

local TestUtils = require("test.test_utils")
local TestRegistry = require("test.test_registry_runtime")
local RunState = require("test.run_state")
local BaselineCompare = require("test.baseline_compare")

local RUNNER_VERSION = "1.0"

local tests = {}
local tests_by_id = {}

local config = {
    filter = nil,
    tags = nil,
    tags_any = nil,
    tags_all = nil,
    category = nil,
    name_substr = nil,
    test_id = nil,
    doc_id = nil,
    shard_count = 1,
    shard_index = 0,
    timeout_frames = 600,
    frame_time = 1 / 60,
    wipe_output = true,
    record_baselines = false,
    skip_self_tests = false,
    quarantine_mode = os.getenv("TEST_QUARANTINE_MODE") or os.getenv("QUARANTINE_MODE") or "pr",
}

local artifacts_by_test = {}
local screenshots_by_test = {}
local quarantine_results = {}

local function normalize_tags(tags)
    if not tags then
        return nil
    end
    if type(tags) == "string" then
        local list = {}
        for tag in tags:gmatch("[^,%s]+") do
            table.insert(list, tag)
        end
        return list
    end
    if type(tags) == "table" then
        return tags
    end
    return nil
end

-- Quarantine system
local quarantine_cache = nil

local function load_quarantine()
    if quarantine_cache then
        return quarantine_cache
    end

    local path = "test_baselines/visual_quarantine.json"
    local file = io.open(path, "r")
    if not file then
        quarantine_cache = { quarantined_tests = {} }
        return quarantine_cache
    end

    local content = file:read("*all")
    file:close()

    local ok, data = pcall(function()
        return TestUtils.parse_json(content)
    end)

    if ok and data then
        quarantine_cache = data
    else
        quarantine_cache = { quarantined_tests = {} }
    end

    return quarantine_cache
end

local function parse_iso8601(str)
    if not str then return nil end
    local year, month, day, hour, min, sec = str:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
    if not year then return nil end
    return os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour) or 0,
        min = tonumber(min) or 0,
        sec = tonumber(sec) or 0
    })
end

local function check_quarantine(test_id)
    local quarantine = load_quarantine()
    local now = os.time()

    for _, entry in ipairs(quarantine.quarantined_tests or {}) do
        if entry.test_id == test_id then
            local expires_ts = parse_iso8601(entry.expires_at)
            local is_expired = expires_ts and now > expires_ts

            return {
                quarantined = true,
                expired = is_expired,
                reason = entry.reason,
                owner = entry.owner,
                issue_link = entry.issue_link,
                expires_at = entry.expires_at,
                platforms = entry.platforms or {"*"},
                renewal_count = entry.renewal_count or 0,
                max_renewals = entry.max_renewals or 2
            }
        end
    end

    return { quarantined = false }
end

local function log_quarantine_status()
    local quarantine = load_quarantine()
    local entries = quarantine.quarantined_tests or {}
    local now = os.time()

    TestUtils.log("[QUARANTINE] === Quarantine Status ===")
    TestUtils.log(string.format("[QUARANTINE] Active quarantines: %d", #entries))

    for _, entry in ipairs(entries) do
        local expires_ts = parse_iso8601(entry.expires_at)
        local is_expired = expires_ts and now > expires_ts
        local status_suffix = is_expired and ", EXPIRED!" or ""
        TestUtils.log(string.format("[QUARANTINE]   - %s (expires: %s%s)",
            entry.test_id,
            entry.expires_at or "unknown",
            status_suffix
        ))
    end
end

local function has_tag(test, tag)
    if not test.tags then
        return false
    end
    for _, t in ipairs(test.tags) do
        if t == tag then
            return true
        end
    end
    return false
end

local function normalize_quarantine_mode(mode)
    local value = tostring(mode or "pr"):lower()
    if value == "nightly" or value == "full" or value == "scheduled" then
        return "nightly"
    end
    return "pr"
end

local function quarantine_blocks(mode)
    return normalize_quarantine_mode(mode) == "nightly"
end

local function is_visual_test(test)
    return has_tag(test, "visual") or test.category == "visual"
end

local function log_quarantine_status(entries, mode)
    TestUtils.log("[QUARANTINE] === Quarantine Status ===")
    local active = {}
    local expired = {}
    local invalid = {}
    for _, item in ipairs(entries or {}) do
        if item.status == "active" then
            table.insert(active, item)
        elseif item.status == "expired" then
            table.insert(expired, item)
        elseif item.status == "invalid" then
            table.insert(invalid, item)
        end
    end

    TestUtils.log(string.format("[QUARANTINE] Active quarantines: %d", #active))
    for _, item in ipairs(active) do
        local entry = item.entry or {}
        TestUtils.log(string.format(
            "[QUARANTINE]   - %s (expires: %s)",
            tostring(entry.test_id or "unknown"),
            tostring(item.expires_at or entry.expires_at or entry.expires_date or "unknown")
        ))
    end

    for _, item in ipairs(expired) do
        local entry = item.entry or {}
        TestUtils.log(string.format(
            "[QUARANTINE]   - %s (expires: %s, EXPIRED!)",
            tostring(entry.test_id or "unknown"),
            tostring(item.expires_at or entry.expires_at or entry.expires_date or "unknown")
        ))
    end

    for _, item in ipairs(invalid) do
        local entry = item.entry or {}
        TestUtils.log(string.format(
            "[QUARANTINE]   - %s (INVALID: %s)",
            tostring(entry.test_id or "unknown"),
            tostring(item.error or "missing fields")
        ))
    end

    TestUtils.log(string.format("[QUARANTINE] Mode: %s", normalize_quarantine_mode(mode)))
end

local function test_file_for(fn, opts)
    if opts and opts.test_file then
        return TestUtils.basename(opts.test_file)
    end
    local info = debug and debug.getinfo and debug.getinfo(fn, "S") or nil
    if info and info.source then
        return TestUtils.basename(info.source)
    end
    return "unknown"
end

local function ensure_test_entry(entry)
    if not entry.test_id or entry.test_id == "" then
        error("test_id required")
    end
    if type(entry.fn) ~= "function" then
        error("test function required for " .. tostring(entry.test_id))
    end
end

local function read_file_size(path)
    local file = io.open(path, "rb")
    if not file then
        return 0
    end
    local size = file:seek("end") or 0
    file:close()
    return size
end

local function log_report_write(path, write_fn)
    TestUtils.log(string.format("[REPORT] Writing %s...", path))
    local ok = write_fn()
    local size = read_file_size(path)
    TestUtils.log(string.format("[REPORT] %s written (%d bytes)", path, size))
    return ok
end

local function write_report(path, summary, results, screenshots, quarantine_entries, quarantine_mode)
    local lines = {}
    table.insert(lines, "# Test Report")
    table.insert(lines, "## Summary")
    table.insert(lines, "Generated: " .. TestUtils.get_iso8601())
    local quarantine_failed = summary.quarantine_failed or 0
    local quarantine_blocking = summary.quarantine_blocking or 0
    local quarantine_expired = summary.quarantine_expired or 0
    table.insert(lines, string.format(
        "Summary: %d passed, %d failed, %d skipped, %d quarantined (%d total)",
        summary.passed,
        summary.failed,
        summary.skipped,
        quarantine_failed,
        summary.total
    ))
    if quarantine_blocking > 0 or quarantine_expired > 0 then
        table.insert(lines, string.format(
            "Quarantine blockers: %d failed (blocking), %d expired",
            quarantine_blocking,
            quarantine_expired
        ))
    end
    table.insert(lines, "")
    table.insert(lines, "## Results")

    local failure_lines = {}
    local skipped_lines = {}
    for _, result in ipairs(results) do
        local status = result.status == "pass" and "PASS"
            or result.status == "fail" and "FAIL"
            or result.status == "quarantine_fail" and "QUAR"
            or "SKIP"
        local test_file = result.test_file or "unknown"
        local line = string.format("%s %s::%s", status, test_file, result.test_id)
        if result.status == "skip" then
            local reason = tostring(result.skip_reason or "skipped"):gsub("\n", " ")
            line = line .. " - " .. reason
            table.insert(skipped_lines, line)
        elseif result.status == "fail" then
            local reason = tostring(result.error and result.error.message or "failure"):gsub("\n", " ")
            line = line .. " - " .. reason
            table.insert(failure_lines, line)
        end
        table.insert(lines, line)
    end

    table.insert(lines, "")
    table.insert(lines, "## Failures")
    if #failure_lines == 0 then
        table.insert(lines, "None")
    else
        for _, line in ipairs(failure_lines) do
            table.insert(lines, line)
        end
    end

    table.insert(lines, "")
    table.insert(lines, "## Skipped")
    if #skipped_lines == 0 then
        table.insert(lines, "None")
    else
        for _, line in ipairs(skipped_lines) do
            table.insert(lines, line)
        end
    end

    table.insert(lines, "")
    table.insert(lines, "## Quarantined Tests")
    if not quarantine_entries or #quarantine_entries == 0 then
        table.insert(lines, "None")
    else
        table.insert(lines, "| Test | Reason | Owner | Expires | Status |")
        table.insert(lines, "|------|--------|-------|---------|--------|")
        local results_by_id = {}
        for _, result in ipairs(results) do
            results_by_id[result.test_id] = result
        end
        local expired_count = 0
        for _, item in ipairs(quarantine_entries) do
            local entry = item.entry or {}
            local test_id = tostring(entry.test_id or "unknown")
            local reason = tostring(entry.reason or "unknown")
            local owner = tostring(entry.owner or "unknown")
            local expires = tostring(item.expires_at or entry.expires_at or entry.expires_date or "unknown")
            local status = item.status or "unknown"
            local res = results_by_id[test_id]
            if res then
                if res.status == "pass" then
                    status = "PASSED"
                elseif res.status == "quarantine_fail" then
                    status = quarantine_blocks(quarantine_mode) and "FAILED (blocking)" or "FAILED (not blocking)"
                elseif res.status == "fail" then
                    if item.status == "expired" then
                        status = "EXPIRED (blocking)"
                    else
                        status = "FAILED"
                    end
                elseif res.status == "skip" then
                    status = "SKIPPED"
                end
            else
                if item.status == "expired" then
                    status = "EXPIRED (blocking)"
                elseif item.status == "active" then
                    status = "NOT RUN"
                else
                    status = tostring(item.status or "unknown"):upper()
                end
            end
            if item.status == "expired" then
                expired_count = expired_count + 1
            end
            table.insert(lines, string.format("| %s | %s | %s | %s | %s |", test_id, reason, owner, expires, status))
        end
        if expired_count > 0 then
            table.insert(lines, "")
            table.insert(lines, string.format("**Note:** %d quarantine(s) expired and are now blocking.", expired_count))
        end
    end

    table.insert(lines, "")
    table.insert(lines, "## Screenshots")
    local screenshot_lines = {}
    if screenshots then
        for test_id, paths in pairs(screenshots) do
            table.sort(paths)
            for _, shot in ipairs(paths) do
                table.insert(screenshot_lines, string.format("- %s: %s", test_id, shot))
            end
        end
    end
    table.sort(screenshot_lines)
    if #screenshot_lines == 0 then
        table.insert(lines, "None")
    else
        for _, line in ipairs(screenshot_lines) do
            table.insert(lines, line)
        end
    end

    TestUtils.write_file(path, table.concat(lines, "\n"))
end

local function xml_escape(text)
    if not text then
        return ""
    end
    return tostring(text)
        :gsub("&", "&amp;")
        :gsub("<", "&lt;")
        :gsub(">", "&gt;")
        :gsub("\"", "&quot;")
        :gsub("'", "&apos;")
end

local function write_junit(path, summary, results)
    local total = summary.total
    local lines = {}
    table.insert(lines, string.format(
        '<testsuite name="LuaTests" tests="%d" failures="%d" skipped="%d">',
        total, summary.failed, summary.skipped
    ))
    for _, result in ipairs(results) do
        local time_sec = (result.duration_ms or 0) / 1000
        table.insert(lines, string.format(
            '  <testcase name="%s" classname="%s" time="%.4f">',
            xml_escape(result.test_id),
            xml_escape(result.category or "unknown"),
            time_sec
        ))
        if result.status == "fail" then
            table.insert(lines, string.format(
                '    <failure message="%s">%s</failure>',
                xml_escape(result.error and result.error.message or "error"),
                xml_escape(result.error and result.error.stack_trace or "")
            ))
        elseif result.status == "skip" then
            table.insert(lines, string.format(
                '    <skipped message="%s" />',
                xml_escape(result.skip_reason or "skipped")
            ))
        end
        table.insert(lines, "  </testcase>")
    end
    table.insert(lines, "</testsuite>")

    TestUtils.write_file(path, table.concat(lines, "\n"))
end

local function check_writable()
    local path = "test_output/.write_test"
    local file = io.open(path, "w")
    if not file then
        return false
    end
    file:write("ok")
    file:close()
    os.remove(path)
    return true
end

local function detect_capabilities()
    local screenshot_available = _G.TakeScreenshot or _G.capture_screenshot
    local log_capture_available = _G.test_logger or _G.log_debug or _G.log_info
    local screenshot_api = nil
    if _G.TakeScreenshot then
        screenshot_api = "TakeScreenshot"
    elseif _G.capture_screenshot then
        screenshot_api = "capture_screenshot"
    elseif _G.take_screenshot then
        screenshot_api = "take_screenshot"
    end
    local log_capture_method = nil
    if _G.test_logger then
        log_capture_method = "test_logger"
    elseif _G.log_debug or _G.log_info then
        log_capture_method = "engine_logger"
    end

    local scene = nil
    if _G.globals then
        scene = _G.globals.scene or _G.globals.current_scene or _G.globals.scene_name
    end

    local test_scene_runnable = false
    if _G.TEST_SCENE or _G.test_scene_loaded or _G.force_test_scene then
        test_scene_runnable = true
    elseif scene ~= nil then
        test_scene_runnable = tostring(scene):lower() == "test"
    elseif os.getenv("TEST_SCENE") == "1" then
        test_scene_runnable = true
    end

    local world_reset_strategy = "test_utils.reset_world()"
    if _G.reset_world then
        world_reset_strategy = "reset_world()"
    end

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

    local headless = false
    if _G.globals and _G.globals.headless ~= nil then
        headless = _G.globals.headless
    end

    local gpu_available = true
    if _G.globals and _G.globals.renderer == "null" then
        gpu_available = false
    end

    local screen_w = nil
    local screen_h = nil
    if _G.globals and _G.globals.screenWidth and _G.globals.screenHeight then
        screen_w = _G.globals.screenWidth
        screen_h = _G.globals.screenHeight
        if type(screen_w) == "function" then
            screen_w = screen_w()
        end
        if type(screen_h) == "function" then
            screen_h = screen_h()
        end
    end

    local platform = TestUtils.get_platform()
    local renderer = _G.globals and _G.globals.renderer or "unknown"
    local dpi_scale = _G.globals and _G.globals.dpi_scale or 1.0
    local resolution = (screen_w and screen_h) and (tostring(screen_w) .. "x" .. tostring(screen_h)) or "unknown"

    return {
        schema_version = "1.0",
        generated_at = TestUtils.get_iso8601(),
        platform = platform,
        capabilities = {
            screenshot = screenshot_available and true or false,
            log_capture = log_capture_available and true or false,
            input_simulation = _G.simulate_input and true or false,
            headless = headless,
            network = os.getenv("NO_NETWORK") ~= "1",
            gpu = gpu_available,
            test_scene = test_scene_runnable and true or false,
            output_writable = check_writable(),
            world_reset = true,
            ubs = ubs_identified,
        },
        gates = {
            deterministic_test_scene = test_scene_runnable and true or false,
            test_output_writable = check_writable(),
            screenshot_capture = screenshot_available and true or false,
            log_capture = log_capture_available and true or false,
            world_reset = true,
            ubs_identified = ubs_identified,
        },
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
        feature_flags = {
            record_baselines = config.record_baselines,
        },
        environment = {
            renderer = renderer,
            resolution = resolution,
            dpi_scale = dpi_scale,
        },
    }
end

local function missing_requirements(requires, capabilities)
    if not requires or #requires == 0 then
        return nil
    end
    local missing = {}
    for _, req in ipairs(requires) do
        if req == "screenshot" and not capabilities.capabilities.screenshot then
            table.insert(missing, "screenshot")
        elseif req == "log_capture" and not capabilities.capabilities.log_capture then
            table.insert(missing, "log_capture")
        elseif req == "test_scene" and not capabilities.capabilities.test_scene then
            table.insert(missing, "test_scene")
        elseif req == "output" and not capabilities.capabilities.output_writable then
            table.insert(missing, "output_writable")
        end
    end
    if #missing > 0 then
        return "missing capability: " .. table.concat(missing, ", ")
    end
    return nil
end

local function matches_filter(test)
    if config.category and test.category ~= config.category then
        return false
    end
    if config.test_id and test.test_id ~= config.test_id then
        return false
    end
    if config.name_substr and not tostring(test.test_id):find(config.name_substr, 1, true) then
        return false
    end
    if config.doc_id then
        local found = false
        for _, doc_id in ipairs(test.doc_ids or {}) do
            if doc_id == config.doc_id then
                found = true
                break
            end
        end
        if not found then
            return false
        end
    end

    if config.filter then
        local needle = tostring(config.filter):lower()
        local id_match = tostring(test.test_id):lower():find(needle, 1, true)
        local cat_match = tostring(test.category or ""):lower():find(needle, 1, true)
        local name_match = tostring(test.display_name or ""):lower():find(needle, 1, true)
        if not id_match and not cat_match and not name_match then
            return false
        end
    end

    local tags_any = config.tags_any or config.tags
    if tags_any and #tags_any > 0 then
        local hit = false
        for _, tag in ipairs(tags_any) do
            if has_tag(test, tag) then
                hit = true
                break
            end
        end
        if not hit then
            return false
        end
    end

    if config.tags_all and #config.tags_all > 0 then
        for _, tag in ipairs(config.tags_all) do
            if not has_tag(test, tag) then
                return false
            end
        end
    end

    return true
end

local function run_with_timeout(fn, timeout_sec)
    if not timeout_sec or timeout_sec <= 0 or not debug or not debug.sethook then
        return pcall(fn)
    end
    local start = os.clock()
    local timed_out = false

    local function hook()
        if os.clock() - start > timeout_sec then
            timed_out = true
            error("timeout exceeded", 2)
        end
    end

    debug.sethook(hook, "", 10000)
    local ok, err = pcall(fn)
    debug.sethook()

    if timed_out then
        return false, string.format("timeout exceeded: %.2fs", timeout_sec)
    end

    return ok, err
end

local function record_artifact(test_id, path)
    if not artifacts_by_test[test_id] then
        artifacts_by_test[test_id] = {}
    end
    table.insert(artifacts_by_test[test_id], path)
end

local function record_screenshot(test_id, path)
    if not screenshots_by_test[test_id] then
        screenshots_by_test[test_id] = {}
    end
    table.insert(screenshots_by_test[test_id], path)
    record_artifact(test_id, path)
end

local function ensure_dir(path)
    os.execute(string.format('mkdir -p "%s" 2>/dev/null', path))
    os.execute(string.format('mkdir "%s" 2>NUL', path:gsub("/", "\\")))
end

local function copy_file(src, dst)
    local input = io.open(src, "rb")
    if not input then
        return false
    end
    local data = input:read("*all")
    input:close()

    local dir = dst:match("^(.*)/")
    if dir then
        ensure_dir(dir)
    end

    local output = io.open(dst, "wb")
    if not output then
        return false
    end
    output:write(data)
    output:close()
    return true
end

local function baseline_root(capabilities)
    local platform_key = TestUtils.safe_filename(capabilities.platform or "unknown")
    local renderer = TestUtils.safe_filename(capabilities.environment and capabilities.environment.renderer or "unknown")
    local resolution = TestUtils.safe_filename(capabilities.environment and capabilities.environment.resolution or "unknown")
    return "test_baselines/screenshots/" .. platform_key .. "/" .. renderer .. "/" .. resolution
end

function TestRunner.register(self_or_test_id, category, fn, opts, ...)
    local test_id = self_or_test_id
    if self_or_test_id == TestRunner then
        test_id = category
        category = fn
        fn = opts
        opts = ...
    end
    opts = opts or {}

    if tests_by_id[test_id] then
        TestUtils.log(string.format("[REGISTER] Duplicate test_id ignored: %s", tostring(test_id)))
        return tests_by_id[test_id]
    end

    local entry = {
        test_id = test_id,
        category = category,
        fn = fn,
        test_file = test_file_for(fn, opts),
        tags = opts.tags or {},
        doc_ids = opts.doc_ids or {},
        requires = opts.requires or {},
        timeout_ms = opts.timeout_ms,
        timeout_frames = opts.timeout_frames,
        perf_budget_ms = opts.perf_budget_ms,
        display_name = opts.display_name,
        self_test = opts.self_test or has_tag({ tags = opts.tags or {} }, "selftest"),
    }
    ensure_test_entry(entry)
    table.insert(tests, entry)
    tests_by_id[test_id] = entry

    TestRegistry.register(test_id, entry.category, {
        test_file = entry.test_file,
        tags = entry.tags,
        doc_ids = entry.doc_ids,
        requires = entry.requires,
        display_name = entry.display_name,
    })

    return entry
end

function TestRunner.configure(opts)
    opts = opts or {}
    if opts.filter ~= nil then config.filter = opts.filter end
    if opts.tags ~= nil then config.tags = normalize_tags(opts.tags) end
    if opts.tags_any ~= nil then config.tags_any = normalize_tags(opts.tags_any) end
    if opts.tags_all ~= nil then config.tags_all = normalize_tags(opts.tags_all) end
    if opts.category ~= nil then config.category = opts.category end
    if opts.name_substr ~= nil then config.name_substr = opts.name_substr end
    if opts.test_id ~= nil then config.test_id = opts.test_id end
    if opts.doc_id ~= nil then config.doc_id = opts.doc_id end
    if opts.shard_count then config.shard_count = tonumber(opts.shard_count) or 1 end
    if opts.shard_index then config.shard_index = tonumber(opts.shard_index) or 0 end
    if opts.timeout_frames then config.timeout_frames = tonumber(opts.timeout_frames) or config.timeout_frames end
    if opts.frame_time then config.frame_time = tonumber(opts.frame_time) or config.frame_time end
    if opts.wipe_output ~= nil then config.wipe_output = opts.wipe_output end
    if opts.record_baselines ~= nil then config.record_baselines = opts.record_baselines end
    if opts.skip_self_tests ~= nil then config.skip_self_tests = opts.skip_self_tests end
end

function TestRunner.before_each(self_or_fn, maybe_fn)
    local fn = self_or_fn
    if self_or_fn == TestRunner then
        fn = maybe_fn
    end
    config.before_each = fn
end

function TestRunner.after_each(self_or_fn, maybe_fn)
    local fn = self_or_fn
    if self_or_fn == TestRunner then
        fn = maybe_fn
    end
    config.after_each = fn
end

function TestRunner.clear()
    tests = {}
    tests_by_id = {}
    artifacts_by_test = {}
    screenshots_by_test = {}
    TestRegistry.clear()
end

function TestRunner.run(self_or_opts, maybe_opts)
    local opts = self_or_opts
    if self_or_opts == TestRunner then
        opts = maybe_opts
    end
    TestRunner.configure(opts)

    TestUtils.ensure_output_dirs()
    if config.wipe_output then
        TestUtils.wipe_output()
    end

    TestUtils.open_log("test_output/test_log.txt")
    TestUtils.log(string.format("[RUNNER] Starting run (filter=%s)", tostring(config.filter or "")))

    local capabilities = detect_capabilities()
    TestUtils.log(string.format(
        "[CAPS] screenshot=%s, log_capture=%s",
        capabilities.capabilities.screenshot and "yes" or "no",
        capabilities.capabilities.log_capture and "yes" or "no"
    ))
    log_report_write("test_output/capabilities.json", function()
        return TestUtils.write_json("test_output/capabilities.json", capabilities)
    end)

    RunState.init()

    local ordered = {}
    for _, test in ipairs(tests) do
        table.insert(ordered, test)
    end
    table.sort(ordered, function(a, b)
        if (a.category or "") == (b.category or "") then
            return a.test_id < b.test_id
        end
        return (a.category or "") < (b.category or "")
    end)

    local filtered = {}
    for _, test in ipairs(ordered) do
        if matches_filter(test) then
            table.insert(filtered, test)
        end
    end

    local sharded = {}
    if config.shard_count > 1 then
        for index, test in ipairs(filtered) do
            if ((index - 1) % config.shard_count) == config.shard_index then
                table.insert(sharded, test)
            end
        end
        TestUtils.log(string.format(
            "[SHARD] Running shard %d/%d (%d tests)",
            config.shard_index,
            config.shard_count,
            #sharded
        ))
    else
        sharded = filtered
    end

    local self_tests = {}
    local main_tests = {}
    for _, test in ipairs(sharded) do
        if test.self_test or has_tag(test, "selftest") or test.category == "selftest" then
            table.insert(self_tests, test)
        else
            table.insert(main_tests, test)
        end
    end

    if config.skip_self_tests then
        self_tests = {}
    end

    local results = {}
    local counts = { passed = 0, failed = 0, skipped = 0 }
    local run_start = os.clock()

    local function run_entry(test)
        local skip_reason = missing_requirements(test.requires, capabilities)

        RunState.test_start(test.test_id)
        TestUtils.log(string.format("[SENTINEL] Updated run_state: last_test_started=%s", test.test_id))
        TestUtils.log(string.format("[TEST START] %s (category: %s)", test.test_id, test.category or "unknown"))
        TestUtils.set_current_test(test.test_id)

        if skip_reason then
            RunState.test_end(test.test_id, "skipped")
            counts.skipped = counts.skipped + 1
            TestUtils.log(string.format("[SKIP] %s: %s", test.test_id, skip_reason))
            TestUtils.log(string.format("[TEST END] %s [SKIP] (0ms)", test.test_id))
            table.insert(results, {
                test_id = test.test_id,
                test_file = test.test_file,
                category = test.category,
                status = "skip",
                duration_ms = 0,
                skip_reason = skip_reason,
                doc_ids = test.doc_ids,
            })
            return true, nil, "skip"
        end

        local ok_before, before_err
        if config.before_each then
            ok_before, before_err = pcall(config.before_each)
        else
            ok_before, before_err = pcall(TestUtils.reset_world)
        end

        local start = os.clock()
        local timeout_sec = (test.timeout_frames or config.timeout_frames) * config.frame_time
        local ok, err = true, nil
        if ok_before then
            ok, err = run_with_timeout(test.fn, timeout_sec)
        else
            ok = false
            err = before_err
        end

        local ok_after, after_err
        if config.after_each then
            ok_after, after_err = pcall(config.after_each)
        else
            ok_after, after_err = pcall(TestUtils.reset_world)
        end
        if not ok_after and ok then
            ok = false
            err = after_err
        end

        local duration_ms = (os.clock() - start) * 1000

        if ok and test.timeout_ms and duration_ms > test.timeout_ms then
            ok = false
            err = string.format("timeout exceeded: %.2fms", test.timeout_ms)
        end
        if ok and test.perf_budget_ms and duration_ms > test.perf_budget_ms then
            ok = false
            err = string.format("perf budget exceeded: %.2fms > %.2fms", duration_ms, test.perf_budget_ms)
        end

        local trace = nil
        if not ok and err and debug and debug.traceback then
            trace = debug.traceback(err, 2)
        end

        -- Check quarantine status for visual tests
        local quarantine_status = check_quarantine(test.test_id)
        local is_visual = has_tag(test, "visual")
        local is_quarantine_fail = false
        local result_status = ok and "pass" or "fail"

        if not ok and is_visual and quarantine_status.quarantined then
            if quarantine_status.expired then
                -- Expired quarantine: still counts as real failure
                TestUtils.log(string.format("[QUARANTINE] Test: %s", test.test_id))
                TestUtils.log(string.format("[QUARANTINE]   Status: EXPIRED quarantine"))
                TestUtils.log(string.format("[QUARANTINE]   Expired: %s", quarantine_status.expires_at or "unknown"))
                TestUtils.log(string.format("[QUARANTINE]   Action: Blocking (expired quarantine)"))
                counts.failed = counts.failed + 1
            else
                -- Active quarantine: treat as warning
                result_status = "quarantine_fail"
                is_quarantine_fail = true
                TestUtils.log(string.format("[QUARANTINE] Test: %s", test.test_id))
                TestUtils.log(string.format("[QUARANTINE]   Status: quarantine_fail"))
                TestUtils.log(string.format("[QUARANTINE]   Reason: %s", quarantine_status.reason or "unknown"))
                TestUtils.log(string.format("[QUARANTINE]   Owner: %s", quarantine_status.owner or "unknown"))
                TestUtils.log(string.format("[QUARANTINE]   Issue: %s", quarantine_status.issue_link or "none"))
                TestUtils.log(string.format("[QUARANTINE]   Expires: %s", quarantine_status.expires_at or "unknown"))
                TestUtils.log(string.format("[QUARANTINE]   Action: Warning only (PR CI)"))
                -- Quarantine failures don't count toward overall failure count
                counts.passed = counts.passed + 1  -- counted as "not blocking"
                table.insert(quarantine_results, {
                    test_id = test.test_id,
                    reason = quarantine_status.reason,
                    owner = quarantine_status.owner,
                    expires_at = quarantine_status.expires_at,
                    issue_link = quarantine_status.issue_link,
                    status = "failed"
                })
            end
        elseif ok then
            counts.passed = counts.passed + 1
            -- Track passed quarantined tests
            if quarantine_status.quarantined then
                table.insert(quarantine_results, {
                    test_id = test.test_id,
                    reason = quarantine_status.reason,
                    owner = quarantine_status.owner,
                    expires_at = quarantine_status.expires_at,
                    issue_link = quarantine_status.issue_link,
                    status = "passed"
                })
            end
        else
            counts.failed = counts.failed + 1
        end

        RunState.test_end(test.test_id, ok and "passed" or (is_quarantine_fail and "quarantine_fail" or "failed"))
        TestUtils.log(string.format(
            "[TEST END] %s [%s] (%.2fms)",
            test.test_id,
            ok and "PASS" or (is_quarantine_fail and "QUARANTINE_FAIL" or "FAIL"),
            duration_ms
        ))

        if ok then
            TestUtils.log(string.format("TEST_PASS: %s", test.test_id))
        elseif is_quarantine_fail then
            local err_text = tostring(err or "error")
            TestUtils.log(string.format("[QUARANTINE_FAIL] %s: %s (not blocking)", test.test_id, err_text))
        else
            local err_text = tostring(err or "error")
            TestUtils.log(string.format("[FAIL DETAIL] %s: %s", test.test_id, err_text))
            if trace then
                TestUtils.log(string.format("[FAIL DETAIL] %s: %s", test.test_id, trace:gsub("\n", " | ")))
            end
            TestUtils.log(string.format("TEST_FAIL: %s - %s", test.test_id, err_text))
        end

        if not ok then
            local artifact_dir = "test_output/artifacts/" .. TestUtils.safe_filename(test.test_id)
            os.execute(string.format('mkdir -p "%s" 2>/dev/null', artifact_dir))
            TestUtils.write_file(artifact_dir .. "/error.txt", tostring(err or "error"))
            if trace then
                TestUtils.write_file(artifact_dir .. "/stack_trace.txt", trace)
            end
            record_artifact(test.test_id, artifact_dir .. "/error.txt")
            if trace then
                record_artifact(test.test_id, artifact_dir .. "/stack_trace.txt")
            end
        end

        local artifacts = artifacts_by_test[test.test_id] or {}
        local result_entry = {
            test_id = test.test_id,
            test_file = test.test_file,
            category = test.category,
            status = result_status,
            duration_ms = duration_ms,
            artifacts = artifacts,
            doc_ids = test.doc_ids,
            error = ok and nil or {
                message = tostring(err or "error"),
                stack_trace = trace,
            },
        }

        -- Add quarantine metadata if applicable
        if quarantine_status.quarantined then
            result_entry.quarantine = {
                reason = quarantine_status.reason,
                owner = quarantine_status.owner,
                expires_at = quarantine_status.expires_at,
                issue_link = quarantine_status.issue_link,
                expired = quarantine_status.expired
            }
        end

        table.insert(results, result_entry)

        return ok, err, result_status
    end

    TestUtils.set_screenshot_hook(record_screenshot)
    TestUtils.set_artifact_hook(record_artifact)

    -- Log quarantine status before tests run
    log_quarantine_status()

    local self_failed = false
    if #self_tests > 0 then
        TestUtils.log("[SELF-TEST] === Test Harness Self-Test Suite ===")
        TestUtils.log(string.format("[SELF-TEST] Running %d validation tests", #self_tests))
        for _, test in ipairs(self_tests) do
            local ok, err = run_entry(test)
            if ok then
                TestUtils.log(string.format("[SELF-TEST] %s: PASS", test.test_id))
            else
                TestUtils.log(string.format("[SELF-TEST] %s: FAIL - %s", test.test_id, tostring(err or "error")))
                self_failed = true
                break
            end
        end
        if self_failed then
            TestUtils.log("[SELF-TEST] CRITICAL: Harness self-test failed! Aborting main suite.")
            TestUtils.log("[SELF-TEST] Fix harness before running tests.")
        else
            TestUtils.log(string.format("[SELF-TEST] All %d self-tests passed. Proceeding to main suite.", #self_tests))
        end
    end

    if not self_failed then
        for _, test in ipairs(main_tests) do
            run_entry(test)
        end
    end

    if config.record_baselines then
        local root = baseline_root(capabilities)
        for test_id, paths in pairs(screenshots_by_test) do
            for _, shot in ipairs(paths) do
                local dst = root .. "/" .. TestUtils.basename(shot)
                if copy_file(shot, dst) then
                    TestUtils.log(string.format("[BASELINE] %s -> %s", shot, dst))
                    record_artifact(test_id, dst)
                else
                    TestUtils.log(string.format("[BASELINE] Failed to copy %s", shot))
                end
            end
        end
    end

    local total = counts.passed + counts.failed + counts.skipped
    local summary = {
        passed = counts.passed,
        failed = counts.failed,
        skipped = counts.skipped,
        total = total,
    }

    local duration_ms = math.floor((os.clock() - run_start) * 1000)

    local status = {
        schema_version = "1.0",
        runner_version = RUNNER_VERSION,
        passed = counts.failed == 0 and not self_failed,
        failed = counts.failed,
        skipped = counts.skipped,
        passed_count = counts.passed,
        total = total,
        generated_at = TestUtils.get_iso8601(),
        commit = TestUtils.get_git_sha(),
        platform = TestUtils.get_platform(),
        engine_version = TestUtils.get_engine_version(),
        duration_ms = duration_ms,
    }

    local results_payload = {
        schema_version = "1.0",
        runner_version = RUNNER_VERSION,
        generated_at = TestUtils.get_iso8601(),
        tests = results,
    }

    log_report_write("test_output/status.json", function()
        return TestUtils.write_json("test_output/status.json", status)
    end)
    log_report_write("test_output/results.json", function()
        return TestUtils.write_json("test_output/results.json", results_payload)
    end)

    do
        local ok, CoverageReport = pcall(require, "test.test_coverage_report")
        if ok and CoverageReport and type(CoverageReport.generate) == "function" then
            local generated = pcall(CoverageReport.generate, "test_output/results.json", "test_output/coverage_report.md")
            if not generated then
                TestUtils.log("[REPORT] WARNING: Failed to generate coverage_report.md")
            end
        else
            TestUtils.log("[REPORT] WARNING: Coverage report module not available")
        end
    end

    local manifest = TestRegistry.build_manifest()
    log_report_write("test_output/test_manifest.json", function()
        return TestUtils.write_json("test_output/test_manifest.json", manifest)
    end)

    log_report_write("test_output/report.md", function()
        return write_report("test_output/report.md", summary, results, screenshots_by_test)
    end)
    log_report_write("test_output/junit.xml", function()
        return write_junit("test_output/junit.xml", summary, results)
    end)

    RunState.complete(counts.failed == 0 and not self_failed)
    TestUtils.close_log()

    return counts.failed == 0 and not self_failed
end

return TestRunner
