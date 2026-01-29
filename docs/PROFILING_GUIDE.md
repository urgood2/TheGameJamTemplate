# Performance Profiling Guide

This guide covers how to use the performance tools available in the game engine.

## Quick Reference - Keybinds

| Key | Action |
|-----|--------|
| **F3** | Toggle performance overlay (FPS, draw calls, memory) |
| **F4** | Toggle physics debug rendering |
| **F7** | Toggle hot-path analyzer (press once to start, again to stop and report) |
| **F8** | Print ECS dashboard report (entity/component stats) |
| **F10** | Capture crash report (if crash reporter enabled) |

---

## Quick Start

### In-Game Performance Overlay (F3)

Press **F3** during gameplay to toggle the performance overlay. It shows:
- FPS and frame time graph
- Draw call breakdown (sprites, text, shapes, UI, state changes)
- Entity count
- Lua memory usage

From Lua:
```lua
perf_overlay.toggle()       -- Toggle visibility
perf_overlay.show()         -- Show overlay
perf_overlay.hide()         -- Hide overlay
perf_overlay.set_position(1) -- 0=TL, 1=TR, 2=BL, 3=BR
perf_overlay.set_opacity(0.8)

local stats = perf_overlay.get_stats()
print(stats.fps, stats.frame_time_ms, stats.draw_calls_total)
```

---

## Lua Profiling Tools

### Hot-Path Analyzer (F4)

Press **F4** to start/stop profiling. Or use programmatically:

```lua
local hotpath = require("tools.hotpath_analyzer")

-- Quick profile of a specific function
hotpath.profile(function()
    -- Code to analyze
    for i = 1, 100 do
        local pos = Q.center(someEntity)
    end
end)

-- Or profile for a few seconds of gameplay
hotpath.start()
-- ... play for 1-2 seconds ONLY (high overhead!)
hotpath.stop()
hotpath.report(20)  -- Top 20 hot functions
```

**Output shows:**
- C++ boundary calls (component_cache.get, registry calls, physics)
- All function call frequencies
- Optimization suggestions

**WARNING:** Uses `debug.sethook` which adds 10-100x overhead. Only profile for 1-2 seconds.

### ECS Dashboard (F5)

Press **F5** for a quick report. Or use programmatically:

```lua
local ecs = require("tools.ecs_dashboard")

ecs.report()           -- Full report with component distribution
ecs.entity_count()     -- Quick entity count
ecs.find_orphans()     -- Find entities missing expected components
print(ecs.summary())   -- One-line summary
```

### GC Monitor

Track per-frame garbage collection pressure:

```lua
local gc = require("tools.gc_monitor")

-- In your game loop
function update(dt)
    gc.frame_start()
    -- ... game logic ...
    gc.frame_end()
end

-- After gameplay
gc.report()  -- Shows high-allocation frames
```

### Unified Performance Interface

All tools in one place:

```lua
local perf = require("tools.perf")

perf.start_all()     -- Start all profilers
-- play for 1-2 seconds
perf.stop_all()      -- Stop all profilers
perf.report_all()    -- Print all reports

-- Or take a snapshot
local snap = perf.snapshot()
print(snap.gc_kb, snap.entity_count)
```

---

## Tracy Profiler (C++ Deep Dive)

For detailed C++ profiling, build with Tracy enabled:

```bash
just build-debug  # Tracy is enabled by default in debug builds
```

### Viewing Traces

1. Download Tracy profiler from: https://github.com/wolfpld/tracy/releases
2. Run the Tracy GUI
3. Start your game
4. Tracy will connect and show real-time traces

### Reading Tracy Data

The codebase has ZONE_SCOPED instrumentation in:
- **Core Loop:** RunGameLoop, MainLoopFixedUpdateAbstraction, updateSystems
- **Rendering:** layer commands, animation, text rendering
- **Physics:** PhysicsWorld::Update, collision processing
- **Scripting:** Lua script updates, monobehavior system
- **AI:** Behavior tree updates, GOAP planning
- **Audio:** sound_system::Update
- **Input:** input polling and processing

Look for:
- Long frame times (spikes in the timeline)
- Nested zones to identify which subsystem is slow
- Memory allocation patterns (if TracyAlloc is used)

---

## Example Profiling Session

### Scenario: "Why is my game running slow?"

1. **Start with the overlay (F3)**
   - Check FPS - is it below target?
   - Check draw calls - are they unexpectedly high?
   - Check Lua memory - is it growing unbounded?

2. **If draw calls are high:**
   - Use ECS dashboard to count entities
   - Check if you have sprite spam or UI over-rendering

3. **If Lua memory is high:**
   - Run GC monitor to find allocation hot spots
   - Check for table churn in update loops

4. **If frame time spikes:**
   - Use Tracy for C++ analysis
   - Use hot-path analyzer for Lua analysis
   - Look for unexpected C++ boundary crossings

### Common Optimization Patterns

**Reduce C++ boundary crossings:**
```lua
-- Bad: Multiple calls per frame
local x, y = Q.center(entity)
local w, h = Q.size(entity)

-- Better: Cache if not changing
local cached = { x = 0, y = 0, w = 0, h = 0 }
function refreshCache(entity)
    cached.x, cached.y = Q.center(entity)
    cached.w, cached.h = Q.size(entity)
end
```

**Reduce GC pressure:**
```lua
-- Bad: Creates new table every frame
local function update()
    local temp = { x = 1, y = 2 }
    process(temp)
end

-- Better: Reuse table
local temp = { x = 0, y = 0 }
local function update()
    temp.x, temp.y = 1, 2
    process(temp)
end
```

**Batch operations:**
```lua
-- Bad: Individual component access
for entity in registry:view(Transform):each() do
    local t = component_cache.get(entity, Transform)
    -- process
end

-- Better: Already batched by view iteration
-- The view itself is efficient
```

---

## Benchmarks

Run performance regression tests:

```bash
./build/tests/benchmark/perf_benchmarks
```

Tests include:
- Entity creation/destruction speed
- Component access patterns
- View iteration performance
- Lua boundary crossing overhead

---

## Performance Checklist

Before shipping:
- [ ] F3 overlay shows stable 60 FPS (or target)
- [ ] Draw calls are reasonable (< 1000 for simple games)
- [ ] Lua memory stable over time (no unbounded growth)
- [ ] No GC spikes visible in frame graph
- [ ] Tracy shows no unexpected hotspots

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
