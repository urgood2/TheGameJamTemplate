--[[
================================================================================
UNIFIED PERFORMANCE TOOLKIT
================================================================================
Central module that loads all performance tools and provides quick access.

Usage:
    local perf = require("tools.perf")

    -- Quick access to all tools
    perf.overlay.toggle()           -- Toggle FPS/draw call overlay
    perf.hotpath.start()            -- Start hot-path profiling
    perf.ecs.report()               -- ECS entity/component report
    perf.gc.enable()                -- Enable GC monitoring
    perf.profile.start()            -- Lua function profiler

    -- One-shot commands
    perf.snapshot()                 -- Print current state of everything
    perf.start_all()                -- Start all profilers
    perf.stop_all()                 -- Stop all and report

    -- Frame hooks (call in your update loop for continuous monitoring)
    perf.frame_start()
    perf.frame_end()
================================================================================
]]

local perf = {}

-- Load all tools lazily
local _tools = {}

local function get_tool(name, path)
    if not _tools[name] then
        local ok, tool = pcall(require, path)
        if ok then
            _tools[name] = tool
        else
            print("[perf] Warning: Could not load " .. name .. ": " .. tostring(tool))
            _tools[name] = {}  -- Empty table to prevent repeated load attempts
        end
    end
    return _tools[name]
end

-- Tool accessors (lazy loaded)
perf.hotpath = setmetatable({}, {
    __index = function(_, k)
        return get_tool("hotpath", "tools.hotpath_analyzer")[k]
    end
})

perf.ecs = setmetatable({}, {
    __index = function(_, k)
        return get_tool("ecs", "tools.ecs_dashboard")[k]
    end
})

perf.gc = setmetatable({}, {
    __index = function(_, k)
        return get_tool("gc", "tools.gc_monitor")[k]
    end
})

perf.profile = setmetatable({}, {
    __index = function(_, k)
        return get_tool("profile", "external.profile")[k]
    end
})

perf.allocation = setmetatable({}, {
    __index = function(_, k)
        return get_tool("allocation", "tools.allocation_profiler")[k]
    end
})

-- Overlay is provided by C++ perf_overlay module
perf.overlay = setmetatable({}, {
    __index = function(_, k)
        if perf_overlay then
            return perf_overlay[k]
        end
        return function() print("[perf] perf_overlay not available") end
    end
})

-- Frame hooks for continuous monitoring
function perf.frame_start()
    local gc = get_tool("gc", "tools.gc_monitor")
    if gc.frame_start then gc.frame_start() end
end

function perf.frame_end()
    local gc = get_tool("gc", "tools.gc_monitor")
    if gc.frame_end then gc.frame_end() end
end

-- Start all profilers
function perf.start_all()
    print("\n[perf] Starting all profilers...")

    local hotpath = get_tool("hotpath", "tools.hotpath_analyzer")
    if hotpath.start then hotpath.start() end

    local gc = get_tool("gc", "tools.gc_monitor")
    if gc.enable then gc.enable() end

    if perf_overlay and perf_overlay.show then
        perf_overlay.show()
    end

    print("[perf] All profilers active\n")
end

-- Stop all profilers and generate reports
function perf.stop_all()
    print("\n[perf] Stopping all profilers and generating reports...")

    local hotpath = get_tool("hotpath", "tools.hotpath_analyzer")
    if hotpath.stop then hotpath.stop() end
    if hotpath.report then hotpath.report(20) end

    local gc = get_tool("gc", "tools.gc_monitor")
    if gc.report then gc.report() end

    local ecs = get_tool("ecs", "tools.ecs_dashboard")
    if ecs.report then ecs.report() end

    print("[perf] Reports complete\n")
end

-- Take a snapshot of current performance state
function perf.snapshot()
    print("\n" .. string.rep("=", 70))
    print("PERFORMANCE SNAPSHOT")
    print(string.rep("=", 70))

    -- Memory
    local mem_kb = collectgarbage("count")
    print(string.format("\nLua Memory: %.2f MB", mem_kb / 1024))

    -- FPS (from main_loop if available)
    if main_loop and main_loop.data then
        local data = main_loop.data
        print(string.format("FPS: %d | Frame Time: %.2fms",
            data.renderedFPS, data.smoothedDeltaTime * 1000))
    end

    -- Overlay stats (if C++ module available)
    if perf_overlay and perf_overlay.get_stats then
        local stats = perf_overlay.get_stats()
        if stats then
            print(string.format("Draw Calls: %d (Sprites: %d, Text: %d, Shapes: %d)",
                stats.draw_calls_total or 0,
                stats.draw_calls_sprites or 0,
                stats.draw_calls_text or 0,
                stats.draw_calls_shapes or 0))
        end
    end

    -- Entity count
    local ecs = get_tool("ecs", "tools.ecs_dashboard")
    if ecs.entity_count then
        print(string.format("Entities: %d", ecs.entity_count()))
    end

    -- GC stats
    local gc = get_tool("gc", "tools.gc_monitor")
    if gc.get_summary then
        local summary = gc.get_summary()
        if summary.frame_count > 0 then
            print(string.format("GC: %.2f KB/frame avg, %d high-alloc frames (%.1f%%)",
                summary.avg_delta_kb,
                summary.high_alloc_frames,
                summary.high_alloc_pct))
        end
    end

    print(string.rep("=", 70) .. "\n")
end

-- Quick benchmark helper
function perf.benchmark(name, iterations, fn)
    iterations = iterations or 1000
    collectgarbage("collect")

    local start_mem = collectgarbage("count")
    local start_time = os.clock()

    for i = 1, iterations do
        fn(i)
    end

    local elapsed = os.clock() - start_time
    local end_mem = collectgarbage("count")
    local mem_delta = end_mem - start_mem

    print(string.format("[benchmark] %s: %.3fms total, %.3fµs/iter, %.2fKB allocated",
        name,
        elapsed * 1000,
        (elapsed * 1000000) / iterations,
        mem_delta))

    return {
        name = name,
        iterations = iterations,
        total_ms = elapsed * 1000,
        per_iter_us = (elapsed * 1000000) / iterations,
        memory_kb = mem_delta,
    }
end

-- Help text
function perf.help()
    print([[
================================================================================
PERFORMANCE TOOLKIT COMMANDS
================================================================================

QUICK COMMANDS:
  perf.snapshot()        - Print current performance state
  perf.start_all()       - Enable all profilers
  perf.stop_all()        - Stop all and print reports

TOOLS:
  perf.overlay.toggle()  - Toggle FPS/draw call overlay (F3)
  perf.overlay.show()    - Show overlay
  perf.overlay.hide()    - Hide overlay
  perf.overlay.get_stats() - Get metrics as table

  perf.hotpath.start()   - Start C++ boundary profiling
  perf.hotpath.stop()    - Stop profiling
  perf.hotpath.report(n) - Show top N hot functions

  perf.ecs.report()      - Entity/component distribution
  perf.ecs.entity_count() - Quick entity count
  perf.ecs.find_orphans() - Find orphaned entities

  perf.gc.enable()       - Enable GC monitoring
  perf.gc.disable()      - Disable GC monitoring
  perf.gc.report()       - Show GC pressure report
  perf.gc.force_gc()     - Force garbage collection

  perf.profile.start()   - Start Lua function profiler
  perf.profile.stop()    - Stop profiler
  perf.profile.report(n) - Show top N functions

  perf.benchmark(name, iterations, fn) - Quick benchmark

FRAME HOOKS (call in update loop for continuous monitoring):
  perf.frame_start()
  perf.frame_end()
================================================================================
]])
end

return perf
