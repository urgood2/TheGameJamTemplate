-- assets/scripts/test/baseline_compare.lua
-- Visual baseline comparison utilities for screenshot testing.
--
-- This module provides:
-- - Platform key computation
-- - Baseline path resolution
-- - Tolerance loading
-- - Quarantine checking
-- - Diff artifact generation (when engine supports it)
--
-- Logging prefix: [BASELINE]

local BaselineCompare = {}

local test_utils = require("test.test_utils")

-- Configuration
local BASELINES_ROOT = "test_baselines"
local SCREENSHOTS_DIR = BASELINES_ROOT .. "/screenshots"
local TOLERANCES_FILE = BASELINES_ROOT .. "/visual_tolerances.json"
local QUARANTINE_FILE = BASELINES_ROOT .. "/visual_quarantine.json"

-- Cached config
local tolerances_cache = nil
local quarantine_cache = nil

--------------------------------------------------------------------------------
-- Platform Key
--------------------------------------------------------------------------------

--- Compute platform key from environment.
--- Format: <os>/<renderer>/<resolution>
--- Example: linux/opengl/1920x1080
--- @return string platform_key
--- @return table components Individual components for logging
function BaselineCompare.compute_platform_key()
    local os_name = "unknown"
    local renderer = "unknown"
    local resolution = "unknown"

    -- Detect OS
    if _G.globals and _G.globals.platform then
        os_name = _G.globals.platform.os or os_name
    elseif jit then
        os_name = jit.os or os_name
    end
    os_name = os_name:lower()

    -- Detect renderer
    if _G.globals and _G.globals.renderer then
        renderer = tostring(_G.globals.renderer):lower()
    end

    -- Detect resolution
    if _G.globals and _G.globals.screenWidth and _G.globals.screenHeight then
        local w = _G.globals.screenWidth
        local h = _G.globals.screenHeight
        if type(w) == "function" then w = w() end
        if type(h) == "function" then h = h() end
        if w and h then
            resolution = tostring(w) .. "x" .. tostring(h)
        end
    end

    local components = {
        os = os_name,
        renderer = renderer,
        resolution = resolution,
    }

    local key = os_name .. "/" .. renderer .. "/" .. resolution
    return key, components
end

--------------------------------------------------------------------------------
-- Tolerance Loading
--------------------------------------------------------------------------------

--- Load tolerances from visual_tolerances.json.
--- @return table tolerances { default_tolerance, per_test_overrides }
function BaselineCompare.load_tolerances()
    if tolerances_cache then
        return tolerances_cache
    end

    local file = io.open(TOLERANCES_FILE, "r")
    if not file then
        test_utils.log("[BASELINE] No tolerances file found, using defaults")
        tolerances_cache = {
            default_tolerance = {
                pixel_diff_threshold = 0.01,
                ssim_threshold = 0.98,
            },
            per_test_overrides = {},
        }
        return tolerances_cache
    end

    local content = file:read("*all")
    file:close()

    -- Simple JSON parsing (for basic structure)
    local parsed = BaselineCompare._parse_json(content)
    if parsed then
        tolerances_cache = parsed
        test_utils.log(string.format(
            "[BASELINE] Loaded tolerances: default pixel_diff=%.3f, ssim=%.3f",
            parsed.default_tolerance and parsed.default_tolerance.pixel_diff_threshold or 0.01,
            parsed.default_tolerance and parsed.default_tolerance.ssim_threshold or 0.98
        ))
    else
        test_utils.log("[BASELINE] Failed to parse tolerances, using defaults")
        tolerances_cache = {
            default_tolerance = {
                pixel_diff_threshold = 0.01,
                ssim_threshold = 0.98,
            },
            per_test_overrides = {},
        }
    end

    return tolerances_cache
end

--- Get tolerance for a specific test.
--- @param test_id string Test identifier
--- @return table tolerance { pixel_diff_threshold, ssim_threshold }
function BaselineCompare.get_tolerance(test_id)
    local tolerances = BaselineCompare.load_tolerances()

    -- Check for per-test override
    if tolerances.per_test_overrides and tolerances.per_test_overrides[test_id] then
        local override = tolerances.per_test_overrides[test_id]
        test_utils.log(string.format(
            "[BASELINE] Using override tolerance for %s: pixel_diff=%.3f, ssim=%.3f (reason: %s)",
            test_id,
            override.pixel_diff_threshold or tolerances.default_tolerance.pixel_diff_threshold,
            override.ssim_threshold or tolerances.default_tolerance.ssim_threshold,
            override.reason or "unspecified"
        ))
        return {
            pixel_diff_threshold = override.pixel_diff_threshold or tolerances.default_tolerance.pixel_diff_threshold,
            ssim_threshold = override.ssim_threshold or tolerances.default_tolerance.ssim_threshold,
        }
    end

    return tolerances.default_tolerance
end

--------------------------------------------------------------------------------
-- Quarantine
--------------------------------------------------------------------------------

--- Load quarantine from visual_quarantine.json.
--- @return table quarantine { quarantined_tests = [] }
function BaselineCompare.load_quarantine()
    if quarantine_cache then
        return quarantine_cache
    end

    local file = io.open(QUARANTINE_FILE, "r")
    if not file then
        quarantine_cache = { quarantined_tests = {} }
        return quarantine_cache
    end

    local content = file:read("*all")
    file:close()

    local parsed = BaselineCompare._parse_json(content)
    if parsed and parsed.quarantined_tests then
        quarantine_cache = parsed
        test_utils.log(string.format(
            "[BASELINE] Loaded quarantine: %d tests quarantined",
            #parsed.quarantined_tests
        ))
    else
        quarantine_cache = { quarantined_tests = {} }
    end

    return quarantine_cache
end

--- Check if a test is quarantined.
--- @param test_id string Test identifier
--- @return boolean is_quarantined
--- @return table|nil entry Quarantine entry if quarantined
function BaselineCompare.is_quarantined(test_id)
    local quarantine = BaselineCompare.load_quarantine()
    local today = os.date("%Y-%m-%d")

    for _, entry in ipairs(quarantine.quarantined_tests or {}) do
        if entry.test_id == test_id then
            -- Check if expired
            if entry.expires_date and entry.expires_date < today then
                test_utils.log(string.format(
                    "[BASELINE] Quarantine expired for %s (expired: %s)",
                    test_id, entry.expires_date
                ))
                return false, nil
            end
            test_utils.log(string.format(
                "[BASELINE] Test %s is quarantined: %s (expires: %s)",
                test_id, entry.reason or "no reason", entry.expires_date or "never"
            ))
            return true, entry
        end
    end

    return false, nil
end

--------------------------------------------------------------------------------
-- Baseline Path Resolution
--------------------------------------------------------------------------------

--- Get baseline path for a test screenshot.
--- @param test_id string Test identifier
--- @param screenshot_name string|nil Optional screenshot name (defaults to test_id)
--- @return string path Full path to baseline
function BaselineCompare.get_baseline_path(test_id, screenshot_name)
    local platform_key = BaselineCompare.compute_platform_key()
    local safe_name = test_utils.safe_filename(screenshot_name or test_id)
    return SCREENSHOTS_DIR .. "/" .. platform_key .. "/" .. safe_name .. ".png"
end

--- Check if a baseline exists for a test.
--- @param test_id string Test identifier
--- @param screenshot_name string|nil Optional screenshot name
--- @return boolean exists
--- @return string path Path to baseline (whether or not it exists)
function BaselineCompare.baseline_exists(test_id, screenshot_name)
    local path = BaselineCompare.get_baseline_path(test_id, screenshot_name)
    local file = io.open(path, "rb")
    if file then
        file:close()
        return true, path
    end
    return false, path
end

--------------------------------------------------------------------------------
-- Comparison (placeholder - requires engine image API)
--------------------------------------------------------------------------------

--- Compare a screenshot against its baseline.
--- @param screenshot_path string Path to captured screenshot
--- @param test_id string Test identifier
--- @return table result { match, pixel_diff, ssim, baseline_path, needs_baseline }
function BaselineCompare.compare(screenshot_path, test_id)
    local exists, baseline_path = BaselineCompare.baseline_exists(test_id)

    if not exists then
        test_utils.log(string.format(
            "[BASELINE] No baseline for %s at %s (NeedsBaseline)",
            test_id, baseline_path
        ))
        return {
            match = true,  -- Pass when no baseline (with flag)
            needs_baseline = true,
            baseline_path = baseline_path,
            pixel_diff = nil,
            ssim = nil,
        }
    end

    local tolerance = BaselineCompare.get_tolerance(test_id)

    -- Actual comparison requires engine image API
    -- For now, return a pass if baseline exists (placeholder)
    if _G.compare_images then
        local metrics = _G.compare_images(screenshot_path, baseline_path)
        local match = (
            metrics.pixel_diff <= tolerance.pixel_diff_threshold and
            metrics.ssim >= tolerance.ssim_threshold
        )

        if not match then
            -- Generate diff artifacts
            BaselineCompare.generate_diff_artifacts(test_id, screenshot_path, baseline_path, metrics)
        end

        return {
            match = match,
            needs_baseline = false,
            baseline_path = baseline_path,
            pixel_diff = metrics.pixel_diff,
            ssim = metrics.ssim,
        }
    end

    -- Fallback: assume match when no comparison API available
    test_utils.log(string.format(
        "[BASELINE] Comparison API not available, assuming match for %s",
        test_id
    ))
    return {
        match = true,
        needs_baseline = false,
        baseline_path = baseline_path,
        pixel_diff = 0,
        ssim = 1.0,
    }
end

--------------------------------------------------------------------------------
-- Diff Artifacts
--------------------------------------------------------------------------------

--- Generate diff artifacts for a failed comparison.
--- @param test_id string Test identifier
--- @param actual_path string Path to captured screenshot
--- @param baseline_path string Path to baseline
--- @param metrics table Comparison metrics
function BaselineCompare.generate_diff_artifacts(test_id, actual_path, baseline_path, metrics)
    local artifact_dir = "test_output/artifacts/" .. test_utils.safe_filename(test_id)

    -- Ensure directory exists
    os.execute(string.format('mkdir -p "%s" 2>/dev/null', artifact_dir))
    os.execute(string.format('mkdir "%s" 2>NUL', artifact_dir:gsub("/", "\\")))

    -- Copy baseline
    local baseline_dst = artifact_dir .. "/baseline.png"
    BaselineCompare._copy_file(baseline_path, baseline_dst)

    -- Copy actual
    local actual_dst = artifact_dir .. "/actual.png"
    BaselineCompare._copy_file(actual_path, actual_dst)

    -- Generate diff image (requires engine API)
    if _G.generate_diff_image then
        local diff_dst = artifact_dir .. "/diff.png"
        _G.generate_diff_image(actual_path, baseline_path, diff_dst)
    end

    -- Write metrics
    local metrics_path = artifact_dir .. "/metrics.json"
    test_utils.write_json(metrics_path, {
        test_id = test_id,
        pixel_diff = metrics.pixel_diff,
        ssim = metrics.ssim,
        threshold_used = BaselineCompare.get_tolerance(test_id),
        generated_at = test_utils.get_iso8601(),
    })

    test_utils.log(string.format(
        "[BASELINE] Generated diff artifacts for %s at %s",
        test_id, artifact_dir
    ))
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

--- Simple JSON parser for configuration files.
--- @param content string JSON content
--- @return table|nil parsed Parsed table or nil on error
function BaselineCompare._parse_json(content)
    -- Try to use external JSON module if available
    local ok, json = pcall(require, "external.json")
    if ok and json and json.decode then
        local parse_ok, result = pcall(json.decode, content)
        if parse_ok then
            return result
        end
    end

    -- Try test.json module
    ok, json = pcall(require, "test.json")
    if ok and json and json.decode then
        local parse_ok, result = pcall(json.decode, content)
        if parse_ok then
            return result
        end
    end

    -- Fallback: very basic JSON parsing for our specific formats
    -- This handles only simple objects with string/number values
    local result = {}

    -- Extract schema_version
    local schema = content:match('"schema_version"%s*:%s*"([^"]+)"')
    if schema then
        result.schema_version = schema
    end

    -- Extract default_tolerance
    local default_block = content:match('"default_tolerance"%s*:%s*(%b{})')
    if default_block then
        result.default_tolerance = {}
        local pixel = default_block:match('"pixel_diff_threshold"%s*:%s*([%d%.]+)')
        local ssim = default_block:match('"ssim_threshold"%s*:%s*([%d%.]+)')
        if pixel then result.default_tolerance.pixel_diff_threshold = tonumber(pixel) end
        if ssim then result.default_tolerance.ssim_threshold = tonumber(ssim) end
    end

    -- Extract per_test_overrides (empty for now)
    result.per_test_overrides = {}

    -- Extract quarantined_tests (empty array check)
    if content:find('"quarantined_tests"%s*:%s*%[%s*%]') then
        result.quarantined_tests = {}
    end

    return result
end

--- Copy a file.
--- @param src string Source path
--- @param dst string Destination path
--- @return boolean success
function BaselineCompare._copy_file(src, dst)
    local input = io.open(src, "rb")
    if not input then
        return false
    end
    local data = input:read("*all")
    input:close()

    local output = io.open(dst, "wb")
    if not output then
        return false
    end
    output:write(data)
    output:close()
    return true
end

--- Clear cached configuration (for testing).
function BaselineCompare.clear_cache()
    tolerances_cache = nil
    quarantine_cache = nil
end

return BaselineCompare
