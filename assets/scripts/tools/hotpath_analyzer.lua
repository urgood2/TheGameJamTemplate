--[[
================================================================================
HOT-PATH ANALYZER
================================================================================
Identifies which Lua functions are called most frequently, focusing on
C++ boundary crossings (component_cache.get, registry calls, physics, etc.)

This helps find optimization opportunities where batching or caching could
reduce Lua<->C++ call overhead.

⚠️  PERFORMANCE WARNING:
    This profiler uses debug.sethook which adds 10-100x overhead!
    - Only profile for 1-2 seconds maximum
    - Results show CALL FREQUENCY, not execution time
    - The profiler itself will appear as a hot path
    - Frame times will be much slower during profiling

Usage:
    local hotpath = require("tools.hotpath_analyzer")
    hotpath.start()
    -- play for 1-2 seconds only!
    hotpath.stop()
    hotpath.report(20)  -- top 20 hot functions

Or for targeted profiling:
    hotpath.profile(function()
        -- code to profile
    end)
================================================================================
]]

local HotPathAnalyzer = {}

-- Tracking state
local tracking = false
local call_counts = {}
local boundary_calls = {}  -- Specifically C++ boundary functions
local start_time = 0
local start_gc = 0

-- Known C++ boundary functions to track specially
local BOUNDARY_FUNCTIONS = {
    -- Component access
    ["component_cache.get"] = true,
    ["registry:get"] = true,
    ["registry:try_get"] = true,
    ["registry:valid"] = true,
    ["registry:create"] = true,
    ["registry:destroy"] = true,

    -- Physics
    ["physics.set_velocity"] = true,
    ["physics.get_velocity"] = true,
    ["physics.apply_impulse"] = true,
    ["physics.set_position"] = true,

    -- Transform shortcuts
    ["Q.center"] = true,
    ["Q.visualCenter"] = true,
    ["Q.move"] = true,
    ["Q.size"] = true,

    -- Rendering
    ["draw.sprite"] = true,
    ["draw.textPro"] = true,
    ["draw.local_command"] = true,

    -- Timer
    ["timer.after"] = true,
    ["timer.every"] = true,
}

-- Hook function
local function track_hook(event, line)
    if not tracking then return end

    local info = debug.getinfo(2, "Snf")
    if not info then return end

    -- Skip profiler internals
    if info.source and info.source:match("hotpath_analyzer") then
        return
    end

    local name = info.name or "anonymous"
    local source = info.short_src or "?"
    local key = name .. " @ " .. source .. ":" .. (info.linedefined or 0)

    call_counts[key] = (call_counts[key] or 0) + 1

    -- Check if this is a known boundary function
    for pattern, _ in pairs(BOUNDARY_FUNCTIONS) do
        if name:match(pattern) or key:match(pattern) then
            boundary_calls[pattern] = (boundary_calls[pattern] or 0) + 1
            break
        end
    end
end

function HotPathAnalyzer.start()
    tracking = true
    call_counts = {}
    boundary_calls = {}
    start_time = os.clock()
    start_gc = collectgarbage("count")

    -- Use call hook to track function entries
    debug.sethook(track_hook, "c")
    print("[HotPathAnalyzer] Started tracking")
end

function HotPathAnalyzer.stop()
    tracking = false
    debug.sethook()
    print("[HotPathAnalyzer] Stopped tracking")
end

function HotPathAnalyzer.reset()
    call_counts = {}
    boundary_calls = {}
    start_time = os.clock()
    start_gc = collectgarbage("count")
    print("[HotPathAnalyzer] Reset counters")
end

-- Profile a specific function/block
function HotPathAnalyzer.profile(fn)
    HotPathAnalyzer.start()
    local ok, result = pcall(fn)
    HotPathAnalyzer.stop()

    if not ok then
        print("[HotPathAnalyzer] Error during profiling: " .. tostring(result))
    end

    return HotPathAnalyzer.get_results()
end

-- Get raw results as table
function HotPathAnalyzer.get_results()
    local elapsed = os.clock() - start_time
    local gc_delta = collectgarbage("count") - start_gc

    -- Sort by call count
    local sorted = {}
    for k, v in pairs(call_counts) do
        table.insert(sorted, { location = k, count = v })
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)

    -- Sort boundary calls
    local sorted_boundary = {}
    for k, v in pairs(boundary_calls) do
        table.insert(sorted_boundary, { name = k, count = v })
    end
    table.sort(sorted_boundary, function(a, b) return a.count > b.count end)

    return {
        elapsed = elapsed,
        gc_delta_kb = gc_delta,
        all_calls = sorted,
        boundary_calls = sorted_boundary,
        total_calls = #sorted,
    }
end

function HotPathAnalyzer.report(top_n)
    top_n = top_n or 20

    local results = HotPathAnalyzer.get_results()
    local elapsed = results.elapsed

    print("\n" .. string.rep("=", 70))
    print("HOT-PATH ANALYSIS REPORT")
    print(string.rep("=", 70))
    print(string.format("Duration: %.3f seconds", elapsed))
    print(string.format("Memory delta: %.2f KB", results.gc_delta_kb))
    print(string.format("Unique call sites: %d", results.total_calls))

    -- C++ Boundary calls (most important for optimization)
    if #results.boundary_calls > 0 then
        print("\n" .. string.rep("-", 70))
        print("C++ BOUNDARY CALLS (Optimization Targets)")
        print(string.rep("-", 70))

        for i, entry in ipairs(results.boundary_calls) do
            local rate = elapsed > 0 and (entry.count / elapsed) or 0
            print(string.format("%2d. %-35s %8d calls (%7.1f/sec)",
                i, entry.name, entry.count, rate))
        end
    end

    -- All hot functions
    print("\n" .. string.rep("-", 70))
    print(string.format("ALL HOT FUNCTIONS (top %d)", top_n))
    print(string.rep("-", 70))

    for i = 1, math.min(top_n, #results.all_calls) do
        local entry = results.all_calls[i]
        local rate = elapsed > 0 and (entry.count / elapsed) or 0
        print(string.format("%2d. %8d calls (%7.1f/sec) - %s",
            i, entry.count, rate, entry.location))
    end

    print(string.rep("=", 70) .. "\n")

    -- Optimization suggestions
    local total_boundary = 0
    for _, v in pairs(results.boundary_calls) do
        total_boundary = total_boundary + v.count
    end

    if total_boundary > 10000 then
        print("⚠️  HIGH BOUNDARY CROSSING: " .. total_boundary .. " C++ calls")
        print("   Consider: caching component lookups, batching operations")
    end

    return results
end

-- Check if profiler is running
function HotPathAnalyzer.is_tracking()
    return tracking
end

-- Add custom boundary function to track
function HotPathAnalyzer.add_boundary_function(pattern)
    BOUNDARY_FUNCTIONS[pattern] = true
end

return HotPathAnalyzer
