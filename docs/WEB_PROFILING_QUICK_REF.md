# Web Profiling Quick Reference

## Console Commands (Copy-Paste Ready)

```javascript
// Enable profiling
WebProfiler.toggle()

// View metrics (after 30-60 seconds)
WebProfiler.printMetrics()

// Export to JSON file
WebProfiler.downloadMetrics()

// Reset and start fresh
WebProfiler.reset()
WebProfiler.toggle()

// Check frame stats
WebProfiler.getFrameStats()

// Check memory (Chrome only)
WebProfiler.getMemoryInfo()
```

## C++ Profiling Macros

```cpp
// Add to any function
#include "util/web_profiler.hpp"

void myFunction() {
    PERF_ZONE("MyFunction");
    // ... your code ...
}

// Nested zones
void complexFunction() {
    PERF_ZONE("ComplexFunction");

    {
        PERF_ZONE("ComplexFunction::Step1");
        // ...
    }

    {
        PERF_ZONE("ComplexFunction::Step2");
        // ...
    }
}
```

## Interpreting Results

### Frame Time Guidelines

| Metric | Target (60 FPS) | Status |
|--------|----------------|--------|
| Mean | ≤16.67ms | Good |
| Mean | 16.67-20ms | Marginal |
| Mean | >20ms | Bad - needs optimization |
| P95 | ≤20ms | Good |
| P95 | >25ms | Occasional stutters |
| P99 | ≤25ms | Good |
| P99 | >33ms | Frequent stutters |

### Memory Guidelines (Chrome)

- **Steady increase:** Memory leak - find and fix
- **Saw-tooth pattern:** Normal GC - OK
- **Near limit:** Risk of crash - reduce memory usage
- **High total:** Consider asset optimization

### C++ Zone Times

- **High mean + high count:** Hot path - optimize first
- **High mean + low count:** Occasional expensive operation
- **Low mean + high count:** Many small operations - batch them

## Common Issues

### No data showing
```javascript
// Check if profiling is enabled
WebProfiler.enabled  // should be true

// Toggle it
WebProfiler.toggle()
```

### Memory shows null
```javascript
// Only works in Chrome/Edge
// Switch browser or skip memory profiling
```

### Frame times seem wrong
```javascript
// Reset and try again
WebProfiler.reset()
WebProfiler.toggle()

// Wait 30+ seconds before checking
```

## Export Format

```json
{
  "timestamp": "2025-12-18T...",
  "frameStats": {
    "mean": "16.67",    // ← Target: ≤16.67ms
    "p95": "22.10",     // ← Target: ≤20ms
    "p99": "28.45",     // ← Target: ≤25ms
    "avgFPS": "60.0"    // ← Target: ≥60
  },
  "memory": {
    "usedMB": "45.23",  // ← Watch for steady increase
    "totalMB": "67.89"
  },
  "cppMetrics": {
    "timings": {
      "MainLoopFixedUpdate": {
        "mean": 12.34,  // ← Bottleneck candidate
        "count": 1234
      }
      // ... other zones
    }
  }
}
```

## Workflow

1. **Enable:** `WebProfiler.toggle()`
2. **Wait:** 30-60 seconds
3. **Check:** `WebProfiler.printMetrics()`
4. **Export:** `WebProfiler.downloadMetrics()`
5. **Optimize:** Focus on high-mean zones
6. **Verify:** Repeat 1-4 and compare

## Links

- Full Guide: `docs/WEB_PROFILING.md`
- Integration Example: `docs/examples/web_profiler_integration.cpp`
- Summary: `docs/WEB_PROFILING_README.md`

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
