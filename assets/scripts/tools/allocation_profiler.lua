-- Allocation profiler for finding table creation hotspots
-- Usage: require this, call start(), run code, call report()
--
-- Example:
--   local profiler = require("tools.allocation_profiler")
--   profiler.start()
--   -- Run code to profile
--   profiler.stop()
--   profiler.report(20)  -- Show top 20 hotspots

local AllocationProfiler = {}

local tracking = false
local allocations = {}
local call_counts = {}
local start_time = 0
local start_gc_count = 0

-- Hook into table creation (approximate via debug hooks)
local function track_hook(event)
    if not tracking then return end

    local info = debug.getinfo(2, "Sl")
    if info and info.source and info.currentline then
        -- Filter out profiler itself and engine internals
        if info.source:match("allocation_profiler") then
            return
        end

        local key = info.source .. ":" .. info.currentline
        call_counts[key] = (call_counts[key] or 0) + 1
    end
end

function AllocationProfiler.start()
    tracking = true
    allocations = {}
    call_counts = {}
    start_time = os.clock()
    start_gc_count = collectgarbage("count")

    -- Note: This is approximate - Lua doesn't expose table allocations directly
    -- We track function calls as a proxy for allocation patterns
    debug.sethook(track_hook, "c", 0)
    print("[AllocationProfiler] Started tracking")
end

function AllocationProfiler.stop()
    tracking = false
    debug.sethook()
    print("[AllocationProfiler] Stopped tracking")
end

function AllocationProfiler.report(top_n)
    top_n = top_n or 20

    local elapsed = os.clock() - start_time
    local gc_delta = collectgarbage("count") - start_gc_count

    -- Sort by count
    local sorted = {}
    for k, v in pairs(call_counts) do
        table.insert(sorted, { location = k, count = v })
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)

    print("\n=== Allocation Hotspots (top " .. top_n .. ") ===")
    print(string.format("Profiling duration: %.3f seconds", elapsed))
    print(string.format("Memory delta: %.2f KB", gc_delta))
    print(string.format("Total locations tracked: %d", #sorted))
    print("-------------------------------------------")

    for i = 1, math.min(top_n, #sorted) do
        local entry = sorted[i]
        local calls_per_sec = elapsed > 0 and (entry.count / elapsed) or 0
        print(string.format("%d. %s: %d calls (%.1f/sec)",
            i, entry.location, entry.count, calls_per_sec))
    end
    print("=====================================\n")

    return sorted
end

function AllocationProfiler.get_gc_stats()
    return {
        memory_kb = collectgarbage("count"),
        gc_count = collectgarbage("count"),
        tracking = tracking,
        hotspot_count = 0,  -- Could be enhanced with more detailed tracking
    }
end

-- Export results to file for later analysis
function AllocationProfiler.export(filename)
    filename = filename or "allocation_profile.txt"

    local sorted = {}
    for k, v in pairs(call_counts) do
        table.insert(sorted, { location = k, count = v })
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)

    local file = io.open(filename, "w")
    if not file then
        print("[AllocationProfiler] Failed to open file: " .. filename)
        return false
    end

    local elapsed = os.clock() - start_time
    local gc_delta = collectgarbage("count") - start_gc_count

    file:write("=== Allocation Profile Report ===\n")
    file:write(string.format("Date: %s\n", os.date("%Y-%m-%d %H:%M:%S")))
    file:write(string.format("Duration: %.3f seconds\n", elapsed))
    file:write(string.format("Memory delta: %.2f KB\n", gc_delta))
    file:write(string.format("Total locations: %d\n\n", #sorted))

    for i, entry in ipairs(sorted) do
        local calls_per_sec = elapsed > 0 and (entry.count / elapsed) or 0
        file:write(string.format("%d. %s: %d calls (%.1f/sec)\n",
            i, entry.location, entry.count, calls_per_sec))
    end

    file:close()
    print("[AllocationProfiler] Exported to: " .. filename)
    return true
end

-- Reset counters without stopping tracking
function AllocationProfiler.reset()
    allocations = {}
    call_counts = {}
    start_time = os.clock()
    start_gc_count = collectgarbage("count")
    print("[AllocationProfiler] Counters reset")
end

-- Check if profiler is currently active
function AllocationProfiler.is_tracking()
    return tracking
end

return AllocationProfiler
