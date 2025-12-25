--[[
================================================================================
GC PRESSURE MONITOR
================================================================================
Tracks Lua garbage collection patterns per frame to identify:
- High allocation frames (GC spikes)
- Memory trends over time
- GC pause frequency

Usage:
    local gc = require("tools.gc_monitor")

    -- In your update loop:
    gc.frame_start()
    -- ... frame code ...
    gc.frame_end()

    -- Get reports:
    gc.report()              -- Full analysis
    gc.get_current_stats()   -- Current frame stats
================================================================================
]]

local GCMonitor = {}

-- Configuration
local config = {
    enabled = false,
    warn_threshold_kb = 50,      -- Warn if frame allocates more than this
    history_size = 300,          -- ~5 seconds at 60fps
    auto_gc_threshold_mb = 100,  -- Suggest GC when memory exceeds this
}

-- State
local frame_start_mem = 0
local frame_count = 0
local history = {}
local total_allocated = 0
local peak_memory = 0
local gc_count = 0
local last_gc_time = 0
local high_alloc_frames = 0

-- Current frame stats
local current = {
    delta_kb = 0,
    memory_kb = 0,
    is_high = false,
}

function GCMonitor.enable()
    config.enabled = true
    GCMonitor.reset()
    print("[GCMonitor] Enabled")
end

function GCMonitor.disable()
    config.enabled = false
    print("[GCMonitor] Disabled")
end

function GCMonitor.is_enabled()
    return config.enabled
end

function GCMonitor.reset()
    frame_count = 0
    history = {}
    total_allocated = 0
    peak_memory = 0
    gc_count = 0
    high_alloc_frames = 0
    frame_start_mem = collectgarbage("count")
    print("[GCMonitor] Reset stats")
end

function GCMonitor.set_warn_threshold(kb)
    config.warn_threshold_kb = kb
end

function GCMonitor.frame_start()
    if not config.enabled then return end
    frame_start_mem = collectgarbage("count")
end

function GCMonitor.frame_end()
    if not config.enabled then return end

    local frame_end_mem = collectgarbage("count")
    local delta = frame_end_mem - frame_start_mem

    -- Update current stats
    current.delta_kb = delta
    current.memory_kb = frame_end_mem
    current.is_high = delta > config.warn_threshold_kb

    -- Track history
    frame_count = frame_count + 1
    table.insert(history, {
        delta = delta,
        memory = frame_end_mem,
        frame = frame_count,
    })

    -- Trim history
    while #history > config.history_size do
        table.remove(history, 1)
    end

    -- Track stats
    if delta > 0 then
        total_allocated = total_allocated + delta
    end

    if frame_end_mem > peak_memory then
        peak_memory = frame_end_mem
    end

    if current.is_high then
        high_alloc_frames = high_alloc_frames + 1
        if frame_count % 60 == 0 then  -- Don't spam
            print(string.format("[GCMonitor] ⚠️ High allocation frame: %.2f KB", delta))
        end
    end

    -- Detect GC events (memory decreased significantly)
    if delta < -100 then  -- Significant decrease = GC ran
        gc_count = gc_count + 1
        last_gc_time = os.clock()
    end
end

function GCMonitor.get_current_stats()
    return {
        delta_kb = current.delta_kb,
        memory_kb = current.memory_kb,
        memory_mb = current.memory_kb / 1024,
        is_high_allocation = current.is_high,
    }
end

function GCMonitor.get_summary()
    if #history == 0 then
        return {
            avg_delta_kb = 0,
            max_delta_kb = 0,
            current_memory_mb = collectgarbage("count") / 1024,
            peak_memory_mb = peak_memory / 1024,
            gc_count = gc_count,
            high_alloc_frames = high_alloc_frames,
            frame_count = frame_count,
        }
    end

    -- Calculate stats from history
    local sum = 0
    local max = 0
    local positive_count = 0

    for _, h in ipairs(history) do
        if h.delta > 0 then
            sum = sum + h.delta
            positive_count = positive_count + 1
        end
        if h.delta > max then
            max = h.delta
        end
    end

    local avg = positive_count > 0 and (sum / positive_count) or 0

    return {
        avg_delta_kb = avg,
        max_delta_kb = max,
        current_memory_mb = collectgarbage("count") / 1024,
        peak_memory_mb = peak_memory / 1024,
        total_allocated_mb = total_allocated / 1024,
        gc_count = gc_count,
        high_alloc_frames = high_alloc_frames,
        frame_count = frame_count,
        high_alloc_pct = frame_count > 0 and (high_alloc_frames / frame_count * 100) or 0,
    }
end

function GCMonitor.report()
    local stats = GCMonitor.get_summary()

    print("\n" .. string.rep("=", 60))
    print("GC PRESSURE MONITOR REPORT")
    print(string.rep("=", 60))

    print(string.format("\nFrames Analyzed: %d", stats.frame_count))

    print("\n" .. string.rep("-", 60))
    print("MEMORY USAGE")
    print(string.rep("-", 60))
    print(string.format("  Current:   %.2f MB", stats.current_memory_mb))
    print(string.format("  Peak:      %.2f MB", stats.peak_memory_mb))
    print(string.format("  Allocated: %.2f MB (total since reset)", stats.total_allocated_mb))

    print("\n" .. string.rep("-", 60))
    print("PER-FRAME ALLOCATION")
    print(string.rep("-", 60))
    print(string.format("  Average:  %.2f KB/frame", stats.avg_delta_kb))
    print(string.format("  Maximum:  %.2f KB/frame", stats.max_delta_kb))

    print("\n" .. string.rep("-", 60))
    print("GC EVENTS")
    print(string.rep("-", 60))
    print(string.format("  GC runs detected: %d", stats.gc_count))
    print(string.format("  High alloc frames: %d (%.1f%%)",
        stats.high_alloc_frames, stats.high_alloc_pct))

    -- Warnings/Recommendations
    print("\n" .. string.rep("-", 60))
    print("ANALYSIS")
    print(string.rep("-", 60))

    if stats.avg_delta_kb > 20 then
        print("  ⚠️  HIGH average allocation - check for table creation in hot paths")
    elseif stats.avg_delta_kb > 10 then
        print("  ⚡ Moderate allocation - consider pooling frequent objects")
    else
        print("  ✓  Allocation rate looks healthy")
    end

    if stats.high_alloc_pct > 5 then
        print("  ⚠️  Many high-allocation frames - investigate spikes")
    end

    if stats.peak_memory_mb > config.auto_gc_threshold_mb then
        print(string.format("  ⚠️  Memory peaked above %d MB - consider explicit GC", config.auto_gc_threshold_mb))
    end

    print("\n" .. string.rep("=", 60))

    return stats
end

-- Force a GC and report
function GCMonitor.force_gc()
    local before = collectgarbage("count")
    collectgarbage("collect")
    local after = collectgarbage("count")
    local freed = before - after

    print(string.format("[GCMonitor] Forced GC: freed %.2f KB (%.2f MB → %.2f MB)",
        freed, before / 1024, after / 1024))

    return freed
end

-- Get allocation history for graphing
function GCMonitor.get_history()
    return history
end

return GCMonitor
