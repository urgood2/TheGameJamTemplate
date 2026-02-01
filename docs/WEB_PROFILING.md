# Web Performance Profiling Guide

This guide explains how to use the web performance profiler to collect and analyze performance metrics in WASM builds.

## Overview

Since Tracy profiler is not available in web builds, we provide a lightweight web-specific profiling system that collects:

- **Frame timing metrics** (JavaScript-side via requestAnimationFrame)
- **C++ zone timings** (via web_profiler.hpp)
- **Memory usage** (Chrome only, via performance.memory API)
- **Per-frame breakdown** (update time, render time, entity count, draw calls)

## Quick Start

### 1. Enable Web Profiling

Open your browser's console (F12) and run:

```javascript
WebProfiler.toggle()
```

This enables both JavaScript frame timing collection and C++ zone profiling.

### 2. Collect Metrics

Let the game run for a while (at least 30 seconds for meaningful data). The profiler automatically:
- Records frame timings (last 300 frames = ~5 seconds of history)
- Collects C++ zone statistics
- Monitors memory usage (if available)

### 3. View Metrics

Print metrics to console:

```javascript
WebProfiler.printMetrics()
```

Example output:
```
=== Web Profiler Metrics ===
Frame Stats (last 300 frames):
  Mean:    16.67 ms (60.0 FPS)
  Min:     12.34 ms
  Max:     42.56 ms
  P50:     16.20 ms
  P95:     22.10 ms
  P99:     28.45 ms
Memory:
  Used:    45.23 MB
  Total:   67.89 MB
  Limit:   2048.00 MB
C++ Timings:
  MainLoopFixedUpdate:
    Mean:  12.34 ms
    Count: 1234
  RenderSystem:
    Mean:  3.21 ms
    Count: 1234
===========================
```

### 4. Export Metrics

Download metrics as JSON file for further analysis:

```javascript
WebProfiler.downloadMetrics()
```

This creates a timestamped JSON file containing:
- Frame timing history
- Frame statistics (mean, min, max, percentiles)
- Memory usage snapshots
- C++ zone timings
- Browser user agent

## Available Console Commands

| Command | Description |
|---------|-------------|
| `WebProfiler.toggle()` | Enable/disable profiling |
| `WebProfiler.printMetrics()` | Print metrics to console |
| `WebProfiler.downloadMetrics()` | Download metrics as JSON |
| `WebProfiler.reset()` | Clear all collected metrics |
| `WebProfiler.getFrameStats()` | Get frame timing statistics |
| `WebProfiler.getMemoryInfo()` | Get memory usage (Chrome only) |

## C++ Integration

### Adding Profiling Zones

Use the `PERF_ZONE` macro to profile C++ code sections:

```cpp
#include "util/web_profiler.hpp"

void myFunction() {
    PERF_ZONE("MyFunction");

    // Your code here...

    {
        PERF_ZONE("MyFunction::ExpensiveSection");
        // Expensive operation...
    }
}
```

### Recording Frame Metrics

To record per-frame metrics from C++:

```cpp
#include "util/web_profiler.hpp"

// In your game loop
void update(float dt) {
    web_profiler::FrameMetrics metrics;
    metrics.timestamp = web_profiler::get_js_timestamp();

    {
        PERF_ZONE("Update");
        // Update logic...
        metrics.update_time_ms = /* measure update time */;
    }

    {
        PERF_ZONE("Render");
        // Render logic...
        metrics.render_time_ms = /* measure render time */;
    }

    metrics.entity_count = registry.size();
    metrics.draw_calls = /* get draw call count */;

    web_profiler::record_frame(metrics);
}
```

### Exporting C++ Metrics to JavaScript

```cpp
// Export metrics to JavaScript (called periodically or on demand)
web_profiler::export_and_send();
```

This sends all collected C++ timings to JavaScript via the `WebProfiler.receiveMetrics()` callback.

## Understanding the Metrics

### Frame Timing Metrics

- **Mean**: Average frame time across all samples
- **Min/Max**: Minimum and maximum frame times observed
- **P50 (Median)**: 50th percentile - half of frames are faster, half are slower
- **P95**: 95th percentile - only 5% of frames are slower than this
- **P99**: 99th percentile - only 1% of frames are slower than this

**What to look for:**
- Mean should be ≤16.67ms for 60 FPS
- P99 spikes indicate occasional stutters
- Large gap between mean and max indicates inconsistent performance

### Memory Metrics (Chrome only)

- **usedJSHeapSize**: Total memory used by JavaScript objects
- **totalJSHeapSize**: Total memory allocated (may include free space)
- **jsHeapSizeLimit**: Maximum memory the browser will allow

**What to look for:**
- Steady increase = potential memory leak
- Saw-tooth pattern = normal GC behavior
- Usage near limit = risk of out-of-memory errors

### C++ Zone Timings

Each profiled zone shows:
- **count**: Number of times the zone was entered
- **mean**: Average time spent in the zone
- **min/max**: Fastest and slowest measurements
- **total**: Total accumulated time

**What to look for:**
- Zones with high mean time are performance bottlenecks
- High count + low mean = many small operations (potential for batching)
- High max = occasional expensive operations (potential for optimization)

## Performance Analysis Workflow

### 1. Identify Bottlenecks

1. Enable profiling and run for 60+ seconds
2. Print metrics to console
3. Look for:
   - Frame times consistently >16.67ms (60 FPS threshold)
   - C++ zones with high mean times
   - High P95/P99 indicating stutters

### 2. Reproduce Issues

1. Enable profiling
2. Perform the slow action
3. Export metrics immediately
4. Compare before/after to isolate the cause

### 3. Validate Improvements

1. Record baseline metrics (before optimization)
2. Make changes
3. Record new metrics (after optimization)
4. Compare frame stats and zone timings

## Example Analysis Session

```javascript
// 1. Start profiling
WebProfiler.toggle()

// 2. Play the game for 60 seconds

// 3. Check current stats
WebProfiler.printMetrics()

// 4. Export for offline analysis
WebProfiler.downloadMetrics()

// 5. Reset and test specific scenario
WebProfiler.reset()
WebProfiler.toggle()

// ... perform specific action (e.g., spawn 100 entities)

// 6. Export targeted metrics
WebProfiler.downloadMetrics()
```

## Analyzing Exported JSON

The exported JSON file contains:

```json
{
  "timestamp": "2025-12-18T12:34:56.789Z",
  "userAgent": "Mozilla/5.0...",
  "memory": {
    "usedMB": "45.23",
    "totalMB": "67.89",
    "jsHeapSizeLimit": 2147483648
  },
  "frameStats": {
    "count": 300,
    "mean": "16.67",
    "min": "12.34",
    "max": "42.56",
    "p50": "16.20",
    "p95": "22.10",
    "p99": "28.45",
    "avgFPS": "60.0"
  },
  "frameTimings": [
    { "time": 16.7, "timestamp": 1234567.89 },
    ...
  ],
  "cppMetrics": {
    "timings": {
      "MainLoopFixedUpdate": {
        "count": 1234,
        "mean": 12.34,
        "min": 10.0,
        "max": 25.0,
        "total": 15234.56
      },
      ...
    },
    "frame_history": [
      {
        "frame_time": 16.67,
        "update_time": 12.34,
        "render_time": 3.21,
        "entity_count": 456,
        "draw_calls": 123,
        "timestamp": 1234567.89
      },
      ...
    ]
  }
}
```

You can load this into a spreadsheet or analysis tool to:
- Plot frame time graphs
- Identify performance trends
- Compare different builds
- Generate performance reports

## Troubleshooting

### "WebProfiler is not defined"

Make sure the game has loaded completely. The WebProfiler is initialized in the HTML shell and should be available after the page loads.

### No C++ metrics showing up

1. Check that web_profiler_bindings.cpp is compiled into the WASM build
2. Verify PERF_ZONE macros are being used in the code
3. Call `web_profiler::export_and_send()` to push metrics to JavaScript
4. Check browser console for errors

### Memory metrics showing null

Memory API is only available in Chrome/Chromium-based browsers. Use Chrome for memory profiling.

### Frame timing seems incorrect

1. Make sure profiling is enabled: `WebProfiler.toggle()`
2. Check that the game is actually running (not paused)
3. Try resetting metrics: `WebProfiler.reset()`

## Best Practices

1. **Profile in Release Builds**: Debug builds have slower performance
2. **Collect Enough Samples**: Run for at least 30-60 seconds for statistical significance
3. **Test Worst-Case Scenarios**: Profile during heavy load (many entities, particles, etc.)
4. **Compare Before/After**: Always capture baseline metrics before optimizing
5. **Export and Archive**: Save JSON exports for long-term tracking
6. **Use Chrome for Memory**: Only Chrome exposes the performance.memory API

## Integration with Build System

To ensure web_profiler_bindings.cpp is compiled:

```bash
# Build web version
just build-web

# The profiler is automatically available in the browser console
```

## Advanced Usage

### Periodic Metric Export

```cpp
// Export metrics every 5 seconds
static float export_timer = 0;
export_timer += dt;

if (export_timer >= 5.0f) {
    web_profiler::export_and_send();
    export_timer = 0;
}
```

### Custom JavaScript Analysis

```javascript
// Access raw frame timings
const timings = WebProfiler.frameTimings;

// Calculate custom metrics
const recentFrames = timings.slice(-60); // last 60 frames
const avgRecent = recentFrames.reduce((a, b) => a + b.time, 0) / 60;

console.log('Average FPS (last second):', (1000 / avgRecent).toFixed(1));
```

### Integration with External Tools

Export JSON and import into:
- Excel/Google Sheets for visualization
- Python/Jupyter for statistical analysis
- Custom dashboards for continuous monitoring
- CI/CD systems for performance regression testing

## See Also

- [Tracy Profiler Integration](TRACY_PROFILING.md) - Native profiling
- [Performance Optimization Guide](PERFORMANCE.md) - Optimization techniques
- [Build System](../CLAUDE.md#build-commands) - Build commands

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
