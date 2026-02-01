# Comprehensive Performance Audit Design

**Date:** 2025-12-17
**Status:** Approved
**Approach:** Hybrid - Targeted audit with profiling validation

## Overview

A systematic performance audit covering all platforms (native + web) and all metrics (frame time, throughput, memory, load times). Uses a measured approach: refactor with test coverage, profile-driven decisions only.

### Priority Areas (User-Identified)
1. **Lua/C++ boundary** - Suspected scripting overhead
2. **Rendering/draw calls** - Suspected GPU bottleneck

### Success Criteria

| Metric | Target |
|--------|--------|
| Frame time (native) | Maintain 60fps, 99th percentile < 18ms |
| Frame time (web) | Maintain 60fps on mid-range hardware |
| Draw calls | 20-50% reduction in typical scenes |
| Memory (Lua GC) | No GC pauses > 5ms |
| Load time | 20-30% improvement |
| Test coverage | All optimizations have benchmark tests |
| No regressions | All existing tests pass |

---

## Phase 1: Profiling Infrastructure (Foundation)

Before optimizing anything, establish reliable measurement.

### 1.1 Native Profiling (Tracy)
- Verify Tracy integration works (`TRACY_ENABLE` build)
- Add missing zones to suspected hot paths
- Create benchmark scenarios (stress tests)

### 1.2 Web Profiling (Browser DevTools + Custom)
- Add lightweight timing instrumentation (no Tracy on WASM)
- Console-based frame time logging
- Memory snapshot tooling via `performance.measureUserAgentSpecificMemory()`

### 1.3 Baseline Metrics
- Record current performance across standard test scenarios
- Document: avg frame time, 99th percentile, draw calls, memory usage
- Create reproducible benchmark scenes

### Deliverables
- Profiling build configuration
- Benchmark test scenes
- Baseline metrics document

---

## Phase 2: Lua/C++ Boundary Optimization

Lua/C++ crossings are notoriously expensive (~100-1000x slower than native calls).

### 2.1 Profiling the Boundary

**What to measure:**
- Function call frequency across the boundary (per frame)
- Time spent in Sol2 type conversion/marshalling
- Hot Lua functions that call C++ repeatedly
- C++ functions called most frequently from Lua

**Where to instrument:**
- `src/systems/scripting/scripting_functions.cpp` - All exposed bindings
- `src/systems/scripting/scripting_system.cpp` - Update hooks
- Lua coroutine dispatch paths

### 2.2 Optimization Patterns

| Pattern | Problem | Solution |
|---------|---------|----------|
| Chatty API | Many small calls per frame | Batch operations (e.g., `get_components(entities)` vs `get_component(entity)` N times) |
| Repeated lookups | Same data fetched every frame | Cache in Lua tables, invalidate on change |
| Type marshalling | Complex types converted repeatedly | Use lightweight handles/IDs instead of full objects |
| Per-entity updates | Lua `update()` called per entity | Bulk update patterns, entity groups |

### 2.3 Candidate Optimizations

- **Bulk component access**: `get_components_batch(entity_list, ComponentType)`
- **Cached physics queries**: Avoid repeated `get_world("world")` calls
- **Entity iteration in C++**: Move hot loops from Lua to C++ with callbacks
- **Reduced coroutine overhead**: Pool coroutines, reduce creation/teardown

### 2.4 TDD Approach

1. **Benchmark test** - Measure current performance (e.g., "1000 entity updates in X ms")
2. **Write failing test** - Assert improved threshold (e.g., "should complete in < X/2 ms")
3. **Implement optimization** - Batch API, caching, etc.
4. **Verify improvement** - Test passes, re-profile to confirm

---

## Phase 3: Rendering/Draw Call Optimization

Draw calls are often the #1 GPU bottleneck, especially on web where WebGL has higher per-call overhead.

### 3.1 Profiling Rendering

**What to measure:**
- Draw calls per frame (already instrumented: `layer::g_drawCallsThisFrame`)
- Time in sort/dispatch (Tracy zones exist)
- State changes: camera mode toggles, shader switches, texture binds
- Batch break frequency and causes

**Key files:**
- `src/systems/layer/layer_command_buffer.cpp` - Sort behavior
- `src/systems/layer/layer_optimized.cpp` - Dispatch loop
- `src/core/game.cpp` - Draw pipeline (~line 1950+)

### 3.2 Current State

Already implemented:
- Sort dirty flag (avoids redundant sorts)
- State batching by z + space (reduces camera toggles)
- Draw call counter (visibility into problem)

**Likely missing:**
- Shader batching (group by shader within z-level)
- Texture atlasing awareness (batch same-atlas draws)
- Instanced rendering for repeated sprites

### 3.3 Candidate Optimizations

| Optimization | Impact | Complexity |
|--------------|--------|------------|
| Shader batching | High - reduces shader switches | Medium |
| Texture batching | High - reduces texture binds | Medium |
| Draw call merging | High - combine compatible commands | High |
| Instanced rendering | Very High - single call for many sprites | High (Raylib limitation) |
| Hybrid batching key | Medium - sort by (z, space, shader, texture) | Low |

### 3.4 TDD Approach

1. **Baseline test**: "Scene X renders in Y draw calls"
2. **Optimization test**: "Scene X renders in < Y/2 draw calls"
3. **Regression test**: "Visual output identical before/after"
4. **Implement** with feature flag (like existing `g_enableStateBatching`)

### 3.5 Web-Specific Considerations

- WebGL draw call overhead is ~10x higher than native OpenGL
- Texture atlas utilization is critical (fewer binds)
- Consider render target reuse to avoid allocation

---

## Phase 4: Memory & GC Optimization

Memory efficiency affects both platforms, but is critical for web where GC pauses cause visible hitches.

### 4.1 Profiling Memory

**Native (C++ side):**
- Allocation frequency in hot paths (Tracy memory profiling)
- Object pool utilization rates
- Peak memory usage per scene

**Lua side:**
- GC pressure from table creation
- String interning misses
- Coroutine allocation patterns

**Web:**
- `performance.measureUserAgentSpecificMemory()` for heap size
- Chrome DevTools memory timeline
- GC pause frequency and duration

### 4.2 Known Memory Patterns

| Pattern | Location | Status |
|---------|----------|--------|
| Object pools | `layer_command_buffer.hpp` | Implemented |
| Manual GC stepping | `game.cpp:1573` | Implemented |
| Component caching | `core/component_cache` | Implemented |

**Likely problem areas:**
- Lua table creation in hot loops (e.g., `{ x = 1, y = 2 }` every frame)
- Temporary string concatenation
- Signal event data tables
- Vec2/Vec3 temporaries across boundary

### 4.3 Candidate Optimizations

| Optimization | Impact | Complexity |
|--------------|--------|------------|
| Table recycling | High - reduce Lua GC pressure | Medium |
| Preallocated event tables | Medium - fewer temporaries | Low |
| String interning | Medium - reduce string allocs | Low |
| Incremental GC tuning | Medium - smoother GC pauses | Low |
| Pooled Vec2/Vec3 | Medium - reduce boundary allocs | Medium |

### 4.4 Lua GC Tuning

Current: Manual `collectgarbage("step")` per frame.

Potential improvements:
```lua
-- Tune incremental GC for smoother collection
collectgarbage("incremental", 100, 200, 10)  -- pause, stepmul, stepsize
```

---

## Phase 5: Load Time Optimization

Load times affect perceived performance significantly.

### 5.1 Profiling Load Times

**What to measure:**
- Time from launch to first frame
- Scene/level transition duration
- Asset loading breakdown (textures, shaders, audio, Lua scripts)
- Initialization sequence bottlenecks

**Where to instrument:**
- `src/core/init.cpp` - Engine bootstrap
- `src/core/game.cpp` - Scene loading paths
- Shader compilation time
- Lua `require()` / `dofile()` timing

### 5.2 Common Bottlenecks

| Bottleneck | Typical Cause | Solution |
|------------|---------------|----------|
| Shader compilation | All shaders compiled at startup | Lazy compile, shader cache |
| Texture loading | Large textures loaded synchronously | Async loading, compression |
| Lua initialization | Heavy `require()` chains | Lazy require, bytecode precompile |
| Physics setup | Full navmesh build on load | Lazy/incremental navmesh |
| Audio loading | All sounds loaded upfront | Stream large audio, preload critical |

### 5.3 Candidate Optimizations

| Optimization | Impact | Complexity |
|--------------|--------|------------|
| Lazy shader compilation | High - defer until first use | Medium |
| Lua bytecode precompilation | Medium - faster parse | Low |
| Async asset loading | High - non-blocking loads | High |
| Progressive scene loading | Medium - show UI during load | Medium |
| Asset preloading hints | Medium - load next scene assets early | Low |

### 5.4 Web-Specific Load Considerations

- WASM module size affects initial download
- Asset fetch latency from network round-trips
- IndexedDB caching for compiled shaders/assets
- Progressive loading with visual feedback

---

## Phase 6: Web-Specific Optimization

A dedicated pass for WASM/Emscripten-specific performance.

### 6.1 Web Platform Constraints

| Constraint | Impact | Mitigation |
|------------|--------|------------|
| Single-threaded | No parallel processing | Batch work, avoid blocking |
| No Tracy | Limited profiling | Custom instrumentation |
| JS interop overhead | Expensive boundary crossings | Minimize EM_ASM calls |
| GC pauses | Browser GC affects frame timing | Reduce allocations |
| WebGL limits | Fewer draw calls tolerable | Aggressive batching |

### 6.2 Candidate Optimizations

| Optimization | Impact | Complexity |
|--------------|--------|------------|
| Reduce EM_ASM calls | High - JS boundary is expensive | Medium |
| WebGL state caching | Medium - avoid redundant GL calls | Medium |
| Emscripten `-O3` + LTO | Medium - better codegen | Low (build flag) |
| WASM SIMD | High - vectorized math | Medium |
| Asyncify tuning | Medium - async operation overhead | Medium |
| Preload critical assets | High - reduce stalls | Low |

### 6.3 Build Configuration Review

Review:
- Optimization level (`-O2` vs `-O3` vs `-Os`)
- Link-time optimization (`-flto`)
- SIMD support (`-msimd128`)
- Memory settings (`INITIAL_MEMORY`, `ALLOW_MEMORY_GROWTH`)

---

## Execution Workflow

### Git Strategy

```
master (stable)
    └── worktree: perf-audit (isolated workspace)
         ├── Phase 1: Profiling infrastructure
         ├── Phase 2: Lua/C++ boundary
         ├── Phase 3: Rendering/draw calls
         ├── Phase 4: Memory/GC
         ├── Phase 5: Load times
         └── Phase 6: Web-specific
```

### Per-Optimization TDD Cycle

1. **PROFILE**: Measure current state
2. **HYPOTHESIS**: "X is the bottleneck"
3. **TEST (RED)**: Write benchmark test with target threshold
4. **IMPLEMENT**: Optimize to pass threshold
5. **TEST (GREEN)**: Verify improvement
6. **PROFILE**: Confirm real-world gains
7. **REVIEW**: Agent reviews changes
8. **COMMIT**: Document what improved and by how much

### Agent Strategy

| Task Type | Agent Approach |
|-----------|----------------|
| Profiling analysis | Single agent analyzes Tracy/metrics output |
| Independent optimizations | Parallel agents for unrelated subsystems |
| Code review | Fresh agent reviews each phase |
| Test writing | Agent per test suite |

### Review Checkpoints

| Checkpoint | What's Reviewed |
|------------|-----------------|
| After Phase 1 | Profiling setup, baseline metrics validity |
| After Phase 2 | Lua/C++ changes, API compatibility |
| After Phase 3 | Rendering changes, visual correctness |
| After Phase 4 | Memory patterns, no new leaks |
| After Phase 5 | Load time changes, no regressions |
| After Phase 6 | Web build works, no native regressions |
| Final | Full integration review before merge |

---

## Risk Mitigation

- **Feature flags** for all optimizations (easy rollback)
- **Benchmark tests** catch regressions automatically
- **Phase-by-phase review** catches issues early
- **Isolated worktree** protects master branch
- **Profile before and after** every change

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
