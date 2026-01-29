# Performance Baseline Metrics

**Date:** 2025-12-18
**Commit:** [Current HEAD]
**Platform:** Native (macOS)

## Test Environment

- **OS:** macOS Darwin 24.4.0
- **CPU:** [To be filled]
- **GPU:** [To be filled]
- **RAM:** [To be filled]

## Lua/C++ Boundary

| Benchmark | Mean (ms) | P99 (ms) | Notes |
|-----------|-----------|----------|-------|
| SingleFunctionCall (10k) | 12.8 | ~15-20 | Empty function call overhead |
| TableCreationInLoop (1k) | 0.12 | ~0.15 | Table allocation cost |
| RepeatedPropertyAccess (10k) | 1.46 | ~2.0 | Component cache access |
| CallbackFromCpp (1k) | 0.036 | ~0.05 | C++ to Lua callback |

**Key Findings:**
- Function call overhead dominates simple operations (~1.28µs per call)
- Table creation is fast when not in tight loops
- Component access is reasonable (~146ns per access)
- Callbacks are very fast (~36ns per call)

## Rendering

| Benchmark | Mean (ms) | P99 (ms) | Notes |
|-----------|-----------|----------|-------|
| SortByZOnly (5k) | 0.12 | ~0.15 | Z-depth only sorting |
| SortByZAndSpace (5k) | 0.18 | ~0.22 | Z + space sorting |
| SortByFullBatchKey (5k) | 0.26 | ~0.32 | Full batch key sorting |
| LargeScaleSort (20k) | 1.12 | ~1.4 | Large-scale batching |

### State Changes (5k commands)

| Sort Method | Space Changes | Shader Changes | Texture Changes |
|-------------|---------------|----------------|-----------------|
| Z-only | 2510 | 4541 | 4896 |
| Full-key | 201 | 1856 | 4859 |

**Key Findings:**
- Full batch key sorting is ~2x slower but reduces state changes dramatically
- Space changes reduced by 92% (2510 → 201)
- Shader changes reduced by 59% (4541 → 1856)
- Texture changes remain high (~4900) in both cases
- Sort overhead is minimal compared to state change savings

## In-Game Metrics

| Metric | Value | Notes |
|--------|-------|-------|
| Draw calls (typical scene) | [To be measured] | |
| FPS (typical scene) | [To be measured] | |
| Frame time avg (ms) | [To be measured] | |
| Frame time p99 (ms) | [To be measured] | |
| Memory usage (MB) | [To be measured] | |

## Web-Specific (if applicable)

| Metric | Value | Notes |
|--------|-------|-------|
| WASM module size (MB) | [To be measured] | |
| Initial load time (s) | [To be measured] | |
| FPS (same scene) | [To be measured] | |
| Memory heap (MB) | [To be measured] | |

## Analysis

### Bottlenecks Identified

1. **Lua/C++ Boundary**
   - Function call overhead is significant for high-frequency operations
   - Recommend batching calls where possible
   - Consider caching frequently-accessed data

2. **Rendering Pipeline**
   - Current sorting strategy (Z-only) causes excessive state changes
   - Full batch key sorting recommended for production builds
   - Texture batching needs investigation (high change rate)

### Recommendations

1. Enable full batch key sorting in release builds
2. Implement texture atlasing to reduce texture state changes
3. Batch Lua API calls in hot paths
4. Profile actual in-game performance to validate microbenchmark findings

### Next Steps

1. Run in-game profiling to measure real-world performance
2. Capture web build metrics for comparison
3. Identify optimization targets based on profiling data
4. Document hardware specifications for reproducibility

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
