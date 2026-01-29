# Task 3.1: Shader/Texture Batching - Investigation Findings

**Date:** 2025-12-18
**Task:** Add Shader/Texture Batching to Sort Key
**Status:** Investigation Complete, Tests Created

---

## Executive Summary

Explored the layer system's rendering pipeline to understand how shader and texture batching could be implemented. Created comprehensive test suite documenting current behavior and expected outcomes. Implementation is straightforward but requires careful design due to the command buffer architecture.

---

## Current System Architecture

### DrawCommandV2 Structure

Located in `src/systems/layer/layer_optimized.hpp` (lines 147-156):

```cpp
struct DrawCommandV2 {
    DrawCommandType type;
    void* data;
    int z;
    DrawCommandSpace space = DrawCommandSpace::Screen;

    uint64_t uniqueID = 0; // For stable sorting
    uint64_t followAnchor;   // 0 = none
};
```

**Key Observations:**
- No shader_id or texture_id fields in DrawCommandV2
- Shader and texture state are managed via separate command types (CmdSetShader, CmdSetTexture)
- Current sorting: z-order primary, space secondary (when g_enableStateBatching = true)
- Uses stable_sort to preserve insertion order within same sort keys

### Shader/Texture Command Model

Shaders and textures are **stateful commands** in the command stream:

```cpp
struct CmdSetShader {
    Shader shader;  // Raylib Shader struct with id, locs
};

struct CmdSetTexture {
    Texture2D texture;  // Raylib Texture2D with id
};
```

**Implication:** Shader/texture IDs are NOT stored per draw command. They exist as separate commands that set GPU state. This means:
- Batching requires tracking "current shader" and "current texture" as commands are processed
- Cannot simply add shader_id/texture_id fields to DrawCommandV2
- Must infer state from command stream during sort

---

## Current Sorting Implementation

From `src/systems/layer/layer_command_buffer.cpp` (lines 11-38):

```cpp
const std::vector<DrawCommandV2>& GetCommandsSorted(const std::shared_ptr<Layer>& layer) {
    if (!layer->isSorted) {
        ZoneScoped;
        ZoneName("CommandBuffer Sort", 18);

        if (g_enableStateBatching) {
            // Sort by z, then by space
            std::stable_sort(layer->commands.begin(), layer->commands.end(),
                [](const DrawCommandV2& a, const DrawCommandV2& b) {
                    if (a.z != b.z) return a.z < b.z;
                    if (a.space != b.space) return a.space < b.space;
                    return false;
                });
        } else {
            // Original sort - z only
            std::stable_sort(layer->commands.begin(), layer->commands.end(),
                [](const DrawCommandV2& a, const DrawCommandV2& b) {
                    if (a.z != b.z) return a.z < b.z;
                    return false;
                });
        }
        layer->isSorted = true;
    }
    return layer->commands;
}
```

**Pattern Established:**
- Feature flags control batching behavior (e.g., g_enableStateBatching)
- stable_sort preserves insertion order when keys are equal
- Sort key is hierarchical: z > space > (potential future keys)

---

## Benchmark Data Context

From Phase 1 benchmarks (`tests/benchmark/benchmark_rendering.cpp`):

### Mock Command Structure (for testing)

```cpp
struct MockDrawCommand {
    int z;
    int space;
    int shader_id;
    int texture_id;
    void* data;
};
```

### Performance Results (5000 commands)

| Sort Key | Mean Time | Shader Changes | Texture Changes |
|----------|-----------|----------------|-----------------|
| z only | ~0.12ms | 4541 | 4896 |
| z + space | ~0.13ms | N/A | N/A |
| z + space + shader + texture | ~0.26ms | 1856 (-59%) | 2311 (-53%) |

**Conclusion:**
- Full batching reduces shader changes by 59%
- Full batching reduces texture changes by 53%
- CPU overhead: +0.14ms (~2x slower sort, still < 0.3ms)
- Trade-off is favorable: minimal CPU cost, significant GPU state change reduction

---

## Implementation Challenges

### Challenge 1: Shader/Texture IDs Not in DrawCommandV2

**Problem:** Shader and texture state are set via CmdSetShader/CmdSetTexture commands, not stored per-command.

**Solution Options:**

1. **State Tracking During Sort** (Recommended)
   - Add shader_id and texture_id fields to DrawCommandV2
   - Pre-process command buffer to infer current state for each command
   - Store inferred state in DrawCommandV2 before sorting
   - Sort using these fields as tertiary/quaternary keys

2. **Two-Pass Sort**
   - First pass: group by z + space
   - Second pass: within each group, reorder to minimize state changes
   - More complex, but doesn't modify DrawCommandV2 structure

3. **State Machine Sort Comparator**
   - Track "current shader/texture" within comparator
   - Expensive: comparator is called O(n log n) times
   - Not recommended due to performance and state management complexity

**Recommendation:** Option 1 (State Tracking During Sort)
- Clean separation of concerns
- Enables future optimizations (e.g., shader/texture atlasing)
- Minimal performance overhead (single linear pass before sort)

### Challenge 2: Shader/Texture Identification

**Problem:** Raylib Shader and Texture2D structs don't expose IDs directly in a portable way.

**Raylib Shader Structure:**
```cpp
typedef struct Shader {
    unsigned int id;        // OpenGL shader program id
    int *locs;             // Shader locations array
} Shader;
```

**Raylib Texture2D Structure:**
```cpp
typedef struct Texture2D {
    unsigned int id;        // OpenGL texture id
    int width;
    int height;
    int mipmaps;
    int format;
} Texture2D;
```

**Solution:** Access .id field directly
- Both structures expose unsigned int id publicly
- Can be used for comparison in sort key
- 0 = no shader/texture set (default state)

### Challenge 3: Command Stream State Inference

**Problem:** Shaders and textures are stateful. A draw command uses whatever shader/texture was last set.

**Example Command Stream:**
```
CmdSetShader(shader1)    // All following draws use shader1
CmdDrawRectangle()       // uses shader1
CmdDrawCircle()          // uses shader1
CmdSetShader(shader2)    // Switch to shader2
CmdDrawRectangle()       // uses shader2
```

**Solution: State Tracking Pass**

Pseudo-code:
```cpp
void InferShaderTextureState(std::vector<DrawCommandV2>& commands) {
    unsigned int currentShader = 0;
    unsigned int currentTexture = 0;

    for (auto& cmd : commands) {
        if (cmd.type == DrawCommandType::SetShader) {
            auto* setShader = static_cast<CmdSetShader*>(cmd.data);
            currentShader = setShader->shader.id;
        } else if (cmd.type == DrawCommandType::SetTexture) {
            auto* setTexture = static_cast<CmdSetTexture*>(cmd.data);
            currentTexture = setTexture->texture.id;
        }

        // Tag command with current state
        cmd.shader_id = currentShader;
        cmd.texture_id = currentTexture;
    }
}
```

Call this before sorting, then sort includes shader_id and texture_id.

---

## Proposed Implementation Plan

### Step 1: Extend DrawCommandV2 Structure

Add shader_id and texture_id fields:

```cpp
struct DrawCommandV2 {
    DrawCommandType type;
    void* data;
    int z;
    DrawCommandSpace space = DrawCommandSpace::Screen;

    uint64_t uniqueID = 0;
    uint64_t followAnchor = 0;

    // NEW: State tracking for batching
    unsigned int shader_id = 0;   // 0 = default/no shader
    unsigned int texture_id = 0;  // 0 = default/no texture
};
```

**Impact:** +8 bytes per command (2 x uint32)
- 5000 commands = +40KB memory
- Acceptable overhead for batching benefit

### Step 2: Add Feature Flag

Following the pattern of `g_enableStateBatching`:

```cpp
// In layer_command_buffer.hpp
namespace layer::layer_command_buffer {
    inline bool g_enableStateBatching = false;   // Existing
    inline bool g_enableShaderBatching = false;  // NEW
}
```

### Step 3: Implement State Inference Pass

Add function to infer shader/texture state:

```cpp
// In layer_command_buffer.cpp
void InferRenderState(std::vector<DrawCommandV2>& commands) {
    unsigned int currentShader = 0;
    unsigned int currentTexture = 0;

    for (auto& cmd : commands) {
        switch (cmd.type) {
            case DrawCommandType::SetShader: {
                auto* setShader = static_cast<CmdSetShader*>(cmd.data);
                currentShader = setShader->shader.id;
                break;
            }
            case DrawCommandType::SetTexture: {
                auto* setTexture = static_cast<CmdSetTexture*>(cmd.data);
                currentTexture = setTexture->texture.id;
                break;
            }
            case DrawCommandType::ResetShader: {
                currentShader = 0;
                break;
            }
            // Other state-changing commands...
            default:
                break;
        }

        // Tag command with current render state
        cmd.shader_id = currentShader;
        cmd.texture_id = currentTexture;
    }
}
```

### Step 4: Update Sort Logic

Modify `GetCommandsSorted` to include shader/texture in sort key:

```cpp
const std::vector<DrawCommandV2>& GetCommandsSorted(const std::shared_ptr<Layer>& layer) {
    if (!layer->isSorted) {
        ZoneScoped;
        ZoneName("CommandBuffer Sort", 18);

        // NEW: Infer shader/texture state if batching enabled
        if (g_enableShaderBatching) {
            InferRenderState(layer->commands);
        }

        if (g_enableShaderBatching) {
            // Sort by z, space, shader, texture
            std::stable_sort(layer->commands.begin(), layer->commands.end(),
                [](const DrawCommandV2& a, const DrawCommandV2& b) {
                    if (a.z != b.z) return a.z < b.z;
                    if (a.space != b.space) return a.space < b.space;
                    if (a.shader_id != b.shader_id) return a.shader_id < b.shader_id;
                    if (a.texture_id != b.texture_id) return a.texture_id < b.texture_id;
                    return false;
                });
        } else if (g_enableStateBatching) {
            // Existing: Sort by z, space
            std::stable_sort(layer->commands.begin(), layer->commands.end(),
                [](const DrawCommandV2& a, const DrawCommandV2& b) {
                    if (a.z != b.z) return a.z < b.z;
                    if (a.space != b.space) return a.space < b.space;
                    return false;
                });
        } else {
            // Original: z only
            std::stable_sort(layer->commands.begin(), layer->commands.end(),
                [](const DrawCommandV2& a, const DrawCommandV2& b) {
                    if (a.z != b.z) return a.z < b.z;
                    return false;
                });
        }

        layer->isSorted = true;
    }
    return layer->commands;
}
```

**Note:** Could simplify by making g_enableShaderBatching imply g_enableStateBatching.

### Step 5: Update Tests

Tests already created in `tests/unit/test_layer_batching.cpp`. Update assertions:

```cpp
// Current (before implementation):
EXPECT_EQ(shaderChanges, 3) << "Without batching, expect 3 distinct shader sequences";

// After implementation:
if (g_enableShaderBatching) {
    EXPECT_LE(shaderChanges, 2) << "With batching, shader changes should be reduced";
} else {
    EXPECT_EQ(shaderChanges, 3);
}
```

---

## Test Suite Created

Created comprehensive test suite in `tests/unit/test_layer_batching.cpp`:

### Test Cases

1. **ShaderBatchingReducesStateChanges**
   - Pattern: shader1, draw, shader2, draw, shader1, draw
   - Expected: 3 shader changes → 2 after batching

2. **TextureBatchingReducesStateChanges**
   - Pattern: tex1, draw, tex2, draw, tex1, draw
   - Expected: 3 texture changes → 2 after batching

3. **CombinedShaderTextureBatching**
   - Complex pattern with both shader and texture changes
   - Verifies sort key priority: z > space > shader > texture

4. **ZOrderTakesPrecedenceOverBatching**
   - Ensures z-order correctness is preserved
   - Shader batching only occurs within same z-level

### Helper Functions

```cpp
int countTypeChanges(const std::vector<DrawCommandV2>& commands, DrawCommandType type)
```

Counts consecutive sequences of a command type (e.g., SetShader) to measure state changes.

---

## Performance Expectations

Based on benchmark data:

### Current System (z-only sort)
- Sort time: ~0.12ms (5000 commands)
- Shader changes: 4541
- Texture changes: 4896

### With Shader/Texture Batching
- Sort time: ~0.26ms (5000 commands) - **+0.14ms overhead**
- Shader changes: ~1856 (-59%) - **2685 fewer changes**
- Texture changes: ~2311 (-53%) - **2585 fewer changes**

### State Inference Pass Overhead
- Linear scan: O(n)
- Expected: ~0.02ms for 5000 commands
- Total overhead: ~0.16ms (inference + slower sort)

**Conclusion:** Overhead is negligible compared to GPU state change savings.

---

## Recommendations

### Immediate Next Steps

1. **Implement DrawCommandV2 extension**
   - Add shader_id and texture_id fields
   - Verify no ABI breaks (struct is value-copied)

2. **Add g_enableShaderBatching flag**
   - Off by default for safety
   - Can be toggled at runtime for A/B testing

3. **Implement InferRenderState()**
   - Handle all state-changing commands (SetShader, SetTexture, ResetShader)
   - Add debug logging to verify correctness

4. **Update sort comparator**
   - Add shader_id and texture_id to sort key
   - Maintain stable_sort to preserve insertion order

5. **Run tests and benchmarks**
   - Verify test_layer_batching passes
   - Run benchmark_rendering to measure actual performance
   - Compare shader/texture change counts

### Future Optimizations

1. **Shader/Texture Atlasing**
   - Once shader_id/texture_id are tracked, can identify optimization opportunities
   - Combine frequently-used shaders into uber-shaders
   - Atlas small textures into larger sheets

2. **Command Buffer Compaction**
   - Remove redundant SetShader/SetTexture commands
   - If shader1 is set twice in a row, eliminate second command

3. **Dynamic Batching Heuristics**
   - Auto-enable batching when command count > threshold
   - Disable if sort overhead exceeds benefit

4. **Multi-threaded Sort**
   - For very large command buffers (>10k commands)
   - Parallel sort by z-level, then merge

---

## Open Questions

1. **Should g_enableShaderBatching imply g_enableStateBatching?**
   - Current design: two independent flags
   - Alternative: shader batching always includes space batching
   - Recommendation: Keep independent for flexibility

2. **How to handle blend mode changes?**
   - CmdSetBlendMode also affects render state
   - Should it be included in sort key?
   - Recommendation: Add in future iteration, measure impact first

3. **Should state inference be cached?**
   - Currently runs every time GetCommandsSorted is called
   - Could cache results and only re-infer on command buffer changes
   - Recommendation: Profile first, optimize if needed

4. **What about other render state?**
   - Scissor modes, stencil state, matrix transforms
   - These are more context-sensitive
   - Recommendation: Start with shader/texture, expand if beneficial

---

## Files Modified/Created

### Created
- `tests/unit/test_layer_batching.cpp` - Comprehensive test suite

### To Be Modified (for implementation)
- `src/systems/layer/layer_optimized.hpp` - Add shader_id/texture_id to DrawCommandV2
- `src/systems/layer/layer_command_buffer.hpp` - Add g_enableShaderBatching flag
- `src/systems/layer/layer_command_buffer.cpp` - Implement state inference and extended sort

### Existing Reference Files
- `tests/benchmark/benchmark_rendering.cpp` - Performance benchmarks with mock data
- `tests/unit/test_layer_state_batching.cpp` - Existing space batching tests

---

## Summary

Shader and texture batching is **feasible and beneficial** for the layer system:

**Pros:**
- 59% reduction in shader changes
- 53% reduction in texture changes
- Minimal CPU overhead (~0.16ms)
- Clean implementation pattern (follows g_enableStateBatching)
- Extensible to other render states

**Cons:**
- +8 bytes per DrawCommandV2 (acceptable)
- Requires state inference pass (O(n), cheap)
- Slightly more complex sort logic

**Verdict:** Recommended for implementation. Tests are in place, architecture is understood, and performance benefits are measurable.

---

**Next:** Proceed with implementation following the steps outlined above, or hand off to next session with this documentation.

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
