-- assets/scripts/test/test_runner.lua
-- Main test harness for engine pattern verification.

local TestRunner = {}

local TestUtils = require("test.test_utils")
local TestRegistry = require("test.test_registry")
local RunState = require("test.run_state")

local RUNNER_VERSION = "1.0"

local tests = {}
local config = {
    filter = nil,
    tags = nil,
    shard_count = 1,
    shard_index = 0,
    timeout_frames = 600,
    frame_time = 1 / 60,
    wipe_output = true,
    record_baselines = false,
    skip_self_tests = false,
}

local artifacts_by_test = {}
local screenshots_by_test = {}

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

local function test_file_for(fn, opts)
    if opts and opts.test_file then
        return TestUtils.basename(opts.test_file)
    end
    local info = debug.getinfo(fn, "S")
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

local function write_report(path, summary, results, capabilities)
    local lines = {}
    table.insert(lines, "# Test Report")
    table.insert(lines, "")
    table.insert(lines, "## Summary")
    table.insert(lines, string.format("- Passed: %d", summary.passed))
    table.insert(lines, string.format("- Failed: %d", summary.failed))
    table.insert(lines, string.format("- Skipped: %d", summary.skipped))
    table.insert(lines, string.format("- Total: %d", summary.total))
    table.insert(lines, "")
    table.insert(lines, "## Capabilities")
    for key, value in pairs(capabilities.capabilities or {}) do
        table.insert(lines, string.format("- %s: %s", key, tostring(value)))
    end
    table.insert(lines, "")
    table.insert(lines, "## Results")
    for _, result in ipairs(results) do
        local status = result.status == "pass" and "PASS" or result.status == "fail" and "FAIL" or "SKIP"
        local line = string.format("- %s: %s (%.2fms)", status, result.test_id, result.duration_ms or 0)
        if result.status == "skip" and result.skip_reason then
            line = line .. " - " .. result.skip_reason
        elseif result.status == "fail" and result.error and result.error.message then
            line = line .. " - " .. result.error.message
        end
        table.insert(lines, line)
    end
    table.insert(lines, "")
    table.insert(lines, "## Failures")
    for _, result in ipairs(results) do
        if result.status == "fail" then
            table.insert(lines, string.format("- TEST_FAIL: %s - %s", result.test_id, result.error and result.error.message or "error"))
            if result.error and result.error.stack_trace then
                table.insert(lines, "```")
                table.insert(lines, result.error.stack_trace)
                table.insert(lines, "```")
            end
        end
    end
    table.insert(lines, "")
    table.insert(lines, "## Skipped")
    for _, result in ipairs(results) do
        if result.status == "skip" then
            table.insert(lines, string.format("- TEST_SKIP: %s - %s", result.test_id, result.skip_reason or "skipped"))
        end
    end
    table.insert(lines, "")
    table.insert(lines, "## Artifacts")
    for test_id, paths in pairs(artifacts_by_test) do
        for _, artifact in ipairs(paths) do
            table.insert(lines, string.format("- %s - %s", test_id, artifact))
        end
    end
    table.insert(lines, "")
    table.insert(lines, "## Screenshots")
    for test_id, paths in pairs(screenshots_by_test) do
        for _, shot in ipairs(paths) do
            table.insert(lines, string.format("- %s - %s", test_id, shot))
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
    local test_scene_runnable = _G.TEST_SCENE or _G.test_scene_loaded

    local headless = false
    if _G.globals and _G.globals.headless ~= nil then
        headless = _G.globals.headless
    end

    local gpu_available = true
    if _G.globals and _G.globals.renderer == "null" then
        gpu_available = false
    end

    local platform = TestUtils.get_platform()

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
        },
        feature_flags = {
            record_baselines = config.record_baselines,
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
    if config.filter then
        local needle = tostring(config.filter):lower()
        local id_match = tostring(test.test_id):lower():find(needle, 1, true)
        local cat_match = tostring(test.category or ""):lower():find(needle, 1, true)
        local name_match = tostring(test.display_name or ""):lower():find(needle, 1, true)
        if not id_match and not cat_match and not name_match then
            return false
        end
    end

    if config.tags and #config.tags > 0 then
        local hit = false
        for _, tag in ipairs(config.tags) do
            if has_tag(test, tag) then
                hit = true
                break
            end
        end
        if not hit then
            return false
        end
    end

    return true
end

local function run_with_timeout(fn, timeout_sec)
    if not timeout_sec or timeout_sec <= 0 then
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

function TestRunner.register(self_or_test_id, category, fn, opts, ...)
    local test_id = self_or_test_id
    if self_or_test_id == TestRunner then
        test_id = category
        category = fn
        fn = opts
        opts = ...
    end
    opts = opts or {}
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

    TestRegistry.register(test_id, {
        test_file = entry.test_file,
        category = entry.category,
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
    artifacts_by_test = {}
    screenshots_by_test = {}
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

    local capabilities = detect_capabilities()
    TestUtils.write_json("test_output/capabilities.json", capabilities)

    TestUtils.open_log("test_output/test_log.txt")
    TestUtils.log(string.format("[RUNNER] Starting run (filter=%s)", tostring(config.filter or "")))
    TestUtils.log(string.format("[CAPS] screenshot=%s log_capture=%s test_scene=%s", tostring(capabilities.capabilities.screenshot), tostring(capabilities.capabilities.log_capture), tostring(capabilities.capabilities.test_scene)))

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
        TestUtils.log(string.format("[SHARD] shard %d/%d (%d tests)", config.shard_index, config.shard_count, #sharded))
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

    local function run_list(list, label)
        for _, test in ipairs(list) do
            local skip_reason = missing_requirements(test.requires, capabilities)
            if skip_reason then
                RunState.test_start(test.test_id)
                RunState.test_end(test.test_id, "skipped")
                counts.skipped = counts.skipped + 1
                table.insert(results, {
                    test_id = test.test_id,
                    test_file = test.test_file,
                    category = test.category,
                    status = "skip",
                    duration_ms = 0,
                    skip_reason = skip_reason,
                    doc_ids = test.doc_ids,
                })
                TestUtils.log(string.format("TEST_SKIP: %s - %s", test.test_id, skip_reason))
            else
                TestUtils.set_current_test(test.test_id)
                if config.before_each then
                    config.before_each()
                else
                    TestUtils.reset_world()
                end

                RunState.test_start(test.test_id)
                TestUtils.log(string.format("[TEST START] %s", test.test_id))

                local start = os.clock()
                local timeout_sec = (test.timeout_frames or config.timeout_frames) * config.frame_time
                local ok, err = run_with_timeout(test.fn, timeout_sec)
                local duration_ms = (os.clock() - start) * 1000

                if ok and test.timeout_ms and duration_ms > test.timeout_ms then
                    ok = false
                    err = string.format("timeout exceeded: %.2fms", test.timeout_ms)
                end
                if ok and test.perf_budget_ms and duration_ms > test.perf_budget_ms then
                    ok = false
                    err = string.format("perf budget exceeded: %.2fms > %.2fms", duration_ms, test.perf_budget_ms)
                end

                local result_status = ok and "pass" or "fail"
                if ok then
                    counts.passed = counts.passed + 1
                else
                    counts.failed = counts.failed + 1
                end

                local trace = nil
                if not ok and err then
                    trace = debug.traceback(err, 2)
                end

                RunState.test_end(test.test_id, ok and "passed" or "failed")
                TestUtils.log(string.format("[TEST END] %s [%s] (%.2fms)", test.test_id, ok and "PASS" or "FAIL", duration_ms))
                if ok then
                    TestUtils.log(string.format("TEST_PASS: %s", test.test_id))
                else
                    TestUtils.log(string.format("TEST_FAIL: %s - %s", test.test_id, tostring(err)))
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
                table.insert(results, {
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
                })

                if config.after_each then
                    config.after_each()
                else
                    TestUtils.reset_world()
                end
            end
        end
        if label and label ~= "" then
            TestUtils.log(string.format("[RUNNER] Completed %s", label))
        end
    end

    TestUtils.set_screenshot_hook(record_screenshot)
    TestUtils.set_artifact_hook(record_artifact)

    if #self_tests > 0 then
        TestUtils.log(string.format("[RUNNER] Running %d self-tests", #self_tests))
        run_list(self_tests, "self-tests")
        if counts.failed > 0 then
            TestUtils.log("[RUNNER] Self-test failures detected; aborting main suite")
        else
            run_list(main_tests, "main suite")
        end
    else
        run_list(main_tests, "main suite")
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
        passed = counts.failed == 0,
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

    local coverage = TestRegistry.coverage_summary()
    coverage.total_tests = total

    local manifest = {
        schema_version = "1.0",
        generated_at = TestUtils.get_iso8601(),
        tests = TestRegistry.all(),
        coverage_summary = coverage,
    }

    TestUtils.write_json("test_output/status.json", status)
    TestUtils.write_json("test_output/results.json", results_payload)
    TestUtils.write_json("test_output/test_manifest.json", manifest)

    write_report("test_output/report.md", summary, results, capabilities)
    write_junit("test_output/junit.xml", summary, results)

    RunState.complete(counts.failed == 0)
    TestUtils.close_log()

    return counts.failed == 0
end

return TestRunner
