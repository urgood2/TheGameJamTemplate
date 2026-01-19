# Batch Rendering System Improvement Plan

## Executive Summary

### Problem Statement
The current batch rendering system works well for cards but has significant usability and maintainability issues:

1. **Code Duplication**: Identical Z-bucketing patterns in `gameplay.lua` (~50 lines) and `player_inventory.lua` (~70 lines)
2. **Not Generalizable**: Batch rendering is card-focused; other sprite types require reimplementing the pattern
3. **Limited Optimization**: `autoOptimize` groups by shader but doesn't consider texture atlas changes
4. **Testing Gaps**: No tests for multi-shader combinations or performance benchmarks
5. **Complex C++ Pipeline**: `executeEntityPipelineWithCommands` is 900+ lines, difficult to extend
6. **No Declarative API**: Must manually manage which entities render together

### High-Level Approach
Create a **RenderGroup** system that:
1. Generalizes batch rendering to any sprite type (cards, particles, UI, enemies, etc.)
2. Automatically optimizes both **shader state changes** and **texture state changes**
3. Provides a clean, declarative Lua API
4. Maintains correct Z-ordering and draw space handling
5. Has comprehensive test coverage (unit, integration, performance, visual)
6. Reduces code duplication by 70%+

---

## Architecture Design

### 1. RenderGroup System (New Core Abstraction)

#### Purpose
A reusable system for grouping entities by shader pipeline + texture for optimal batching. Works with ANY sprite type.

#### Lua API Design
```lua
-- Create a render group
local render_group = require("core.render_group")
local group = render_group.create("gameplay_cards")

-- Register entities to group
group:add(entity1)
group:add(entity2)
group:add(entity3)

-- Or add multiple
group:add_many({entity4, entity5, entity6})

-- Queue all entities in group for rendering
group:render(layer, z_order, space)

-- Clear group (call each frame or when entities change)
group:clear()
```

#### C++ Implementation Structure

**New File**: `src/systems/render/render_group.hpp`

```cpp
#pragma once
#include "raylib.h"
#include "entt/entt.hpp"
#include "systems/layer/layer_optimized.hpp"
#include <unordered_map>
#include <vector>

namespace render_group {

// Unique key for shader + texture combination
struct RenderKey {
    std::string shaderName;
    Texture2D* texture;
    layer::DrawCommandSpace space;
    int zOrder;

    bool operator==(const RenderKey& other) const;
    bool operator!=(const RenderKey& other) const;
};

// Hash function for RenderKey
struct RenderKeyHash {
    std::size_t operator()(const RenderKey& key) const;
};

// Group of entities sharing same shader/texture/z/space
struct RenderBucket {
    std::vector<entt::entity> entities;
    RenderKey key;

    void clear() { entities.clear(); }
    void add(entt::entity e) { entities.push_back(e); }
    size_t size() const { return entities.size(); }
};

// Main render group manager
class RenderGroup {
public:
    explicit RenderGroup(std::string_view name);

    // Entity management
    void add(entt::entity e);
    void add_many(const std::vector<entt::entity>& entities);
    void remove(entt::entity e);
    void clear();

    // Rendering
    void render(layer::Layer* layer, int zOffset = 0, layer::DrawCommandSpace space = layer::DrawCommandSpace::World);

    // Query
    size_t size() const { return allEntities.size(); }
    const std::vector<entt::entity>& get_all() const { return allEntities; }

private:
    std::string groupName;
    std::vector<entt::entity> allEntities;
    std::unordered_map<RenderKey, RenderBucket, RenderKeyHash> buckets;

    void rebuild_buckets(entt::registry& registry);
    RenderKey make_key(entt::registry& registry, entt::entity e) const;
};

// Lua bindings
void exposeToLua(sol::state& lua);

} // namespace render_group
```

#### Key Features
1. **Automatic Batching**: Groups entities by shader + texture + z + space
2. **Lazy Bucket Rebuild**: Only rebuilds when entities change, not every frame
3. **Z-Order Preservation**: Maintains exact entity Z-ordering
4. **Draw Space Support**: Handles both World and Screen space correctly
5. **Memory Efficiency**: Reuses entity vectors, minimizes allocations

---

### 2. Enhanced Shader + Texture Optimization

#### Current Limitation
`autoOptimize` in `DrawCommandBatch.optimize()` only groups by shader, ignoring texture atlas changes.

#### Improvement: Multi-Key Batching
Group entities by composite key: `(shaderName, textureID, zOrder, drawSpace)`

**Optimization Impact**:
- **Before**: 50 entities with 3 shaders = 3 shader switches
- **After**: 50 entities with 3 shaders + 4 atlases = 3 shader switches + 4 texture changes
- **Benefit**: Texture changes are 10x faster than shader changes on most GPUs

**New `DrawCommandBatch.optimize()` Implementation**:
```cpp
void DrawCommandBatch::optimizeEnhanced() {
    if (commands.empty()) return;

    std::vector<DrawCommand> optimized;
    optimized.reserve(commands.size());

    std::string currentShader;
    Texture2D* currentTexture = nullptr;
    layer::DrawCommandSpace currentSpace = layer::DrawCommandSpace::World;

    for (const auto& cmd : commands) {
        // Detect state changes
        bool shaderChanged = (cmd.type == DrawCommandType::BeginShader && cmd.shaderName != currentShader);
        bool textureChanged = (cmd.type == DrawCommandType::DrawTexture && cmd.texture.id != (currentTexture ? currentTexture->id : 0));

        // Insert state change commands only when needed
        if (shaderChanged) {
            DrawCommand endCmd;
            endCmd.type = DrawCommandType::EndShader;
            optimized.push_back(endCmd);
            optimized.push_back(cmd); // BeginShader
            currentShader = cmd.shaderName;
        } else if (cmd.type == DrawCommandType::BeginShader && cmd.shaderName == currentShader) {
            continue; // Skip redundant BeginShader
        }

        optimized.push_back(cmd);
    }

    // Ensure shader is ended
    if (!currentShader.empty()) {
        DrawCommand endCmd;
        endCmd.type = DrawCommandType::EndShader;
        optimized.push_back(endCmd);
    }

    commands.swap(optimized);
}
```

---

### 3. Simplified Lua API

#### Current API (Verbose)
```lua
-- gameplay.lua - 50 lines of boilerplate
local batchedCardBuckets = {}
for eid, cardScript in pairs(cards) do
    local zToUse = layer_order_system.getZIndex(eid)
    local bucket = batchedCardBuckets[zToUse] or {}
    bucket[#bucket + 1] = eid
    batchedCardBuckets[zToUse] = bucket
end

for _, z in ipairs(sortedZKeys) do
    local entityList = batchedCardBuckets[z]
    command_buffer.queueDrawBatchedEntities(layers.sprites, function(cmd)
        cmd.registry = registry
        cmd.entities = entityList
        cmd.autoOptimize = true
    end, z, layer.DrawCommandSpace.Screen)
end
```

#### New API (Declarative)
```lua
-- Reduced to 5 lines
local render_group = require("core.render_group")
local cardGroup = render_group.create("gameplay_cards")

for eid, cardScript in pairs(cards) do
    cardGroup:add(eid)
end

cardGroup:render(layers.sprites, 0, layer.DrawCommandSpace.Screen)
cardGroup:clear()
```

---

## Implementation Phases

### Phase 1: Core RenderGroup System (Week 1)

#### Files to Create
1. **`src/systems/render/render_group.hpp`** - RenderGroup class definition
2. **`src/systems/render/render_group.cpp`** - RenderGroup implementation
3. **`assets/scripts/core/render_group.lua`** - Lua module for RenderGroup Lua bindings

#### Implementation Steps

**Step 1.1: RenderGroup C++ Class**
- Implement `RenderKey` struct with hash function
- Implement `RenderBucket` for holding entity groups
- Implement `RenderGroup` with:
  - `add()`, `add_many()`, `remove()`, `clear()`
  - `render()` method that calls `command_buffer.queueDrawBatchedEntities()`
  - Lazy bucket rebuild with dirty flag

**Step 1.2: Lua Bindings**
- Expose `render_group.create(name)` → returns `RenderGroup` instance
- Expose `add(e)`, `add_many(entities)`, `remove(e)`, `clear()`
- Expose `render(layer, zOffset, space)`
- Document all functions with BindingRecorder

**Step 1.3: Basic Tests**
Create `tests/unit/test_render_group.cpp`:
```cpp
TEST(RenderGroupTest, CreateAndDestroy) { }
TEST(RenderGroupTest, AddSingleEntity) { }
TEST(RenderGroupTest, AddMultipleEntities) { }
TEST(RenderGroupTest, RemoveEntity) { }
TEST(RenderGroupTest, ClearGroup) { }
TEST(RenderGroupTest, RenderWithEmptyGroup) { }
```

#### Success Criteria
- [ ] All C++ unit tests pass
- [ ] Lua can create RenderGroup instance
- [ ] Lua can add/remove entities
- [ ] Lua can call `render()` without crash

---

### Phase 2: Enhanced Optimization (Week 1-2)

#### Files to Modify
1. **`src/systems/shaders/shader_draw_commands.hpp`** - Add `optimizeEnhanced()`
2. **`src/systems/shaders/shader_draw_commands.cpp`** - Implement enhanced optimization

#### Implementation Steps

**Step 2.1: Enhanced Optimize Algorithm**
- Add `optimizeEnhanced()` method to `DrawCommandBatch`
- Track current texture state alongside shader state
- Only insert `BeginShader` when shader actually changes
- Group consecutive `DrawTexture` commands with same texture

**Step 2.2: Add Configuration Flag**
```cpp
enum class OptimizationLevel {
    Basic,      // Current behavior (shader only)
    Enhanced,    // Shader + texture tracking
    Aggressive    // Experimental: reorder for max batching
};
```

**Step 2.3: Tests for Enhanced Optimization**
Create `tests/unit/test_shader_optimization.cpp`:
```cpp
TEST(ShaderOptimization, BasicOptimization) { }
TEST(ShaderOptimization, EnhancedTextureGrouping) { }
TEST(ShaderOptimization, MultipleTextureAtlases) { }
TEST(ShaderOptimization, PreservesDrawOrder) { }
```

#### Success Criteria
- [ ] Enhanced optimization reduces texture changes by 40%+
- [ ] All optimization tests pass
- [ ] Visual output identical to current system
- [ ] Performance improvement measurable with profiling

---

### Phase 3: API Simplification (Week 2)

#### Files to Modify
1. **`assets/scripts/core/render_group.lua`** - Add convenience functions
2. **`assets/scripts/core/gameplay.lua`** - Migrate to new API
3. **`assets/scripts/ui/player_inventory.lua`** - Migrate to new API

#### Implementation Steps

**Step 3.1: Convenience Functions in render_group.lua**
```lua
local render_group = {}

function render_group.from_registry(view, filter_fn)
    -- Create group from ECS view
    local group = render_group.create("auto_" .. tostring(view))
    for entity in view:each() do
        if not filter_fn or filter_fn(entity) then
            group:add(entity)
        end
    end
    return group
end

function render_group.from_table(entity_table)
    -- Create group from Lua table
    local group = render_group.create("table_group")
    for _, entity in ipairs(entity_table) do
        group:add(entity)
    end
    return group
end

return render_group
```

**Step 3.2: Migrate gameplay.lua**
```lua
-- BEFORE (50 lines of boilerplate):
local batchedCardBuckets = {}
for eid, cardScript in pairs(cards) do
    local zToUse = layer_order_system.getZIndex(eid)
    local bucket = batchedCardBuckets[zToUse] or {}
    bucket[#bucket + 1] = eid
    batchedCardBuckets[zToUse] = bucket
end
-- ... more Z-bucket logic

-- AFTER (5 lines):
local render_group = require("core.render_group")
local cardGroup = render_group.create("gameplay_cards")

for eid, cardScript in pairs(cards) do
    if registry:valid(eid) and registry:has(eid, AnimationQueueComponent) then
        cardGroup:add(eid)
    end
end

cardGroup:render(layers.sprites, 0, layer.DrawCommandSpace.Screen)
cardGroup:clear()
```

**Step 3.3: Migrate player_inventory.lua**
Same pattern as gameplay.lua migration.

#### Success Criteria
- [ ] gameplay.lua reduced by 45+ lines of boilerplate
- [ ] player_inventory.lua reduced by 60+ lines of boilerplate
- [ ] Both files use RenderGroup API
- [ ] All existing tests pass
- [ ] Visual rendering unchanged

---

### Phase 4: Comprehensive Testing (Week 3)

#### Files to Create
1. **`assets/scripts/test_render_group.lua`** - RenderGroup Lua tests
2. **`tests/integration/test_batch_rendering_integration.cpp`** - Integration tests

#### Test Categories

**4.1 Unit Tests (Lua)**
```lua
-- test_render_group.lua
local render_group = require("core.render_group")

function test_create_group()
    local group = render_group.create("test_group")
    assert(group ~= nil, "Failed to create group")
end

function test_add_entities()
    local group = render_group.create("test")
    local e1 = registry:create()
    local e2 = registry:create()

    group:add_many({e1, e2})
    assert(group:size() == 2, "Entity count mismatch")
end

function test_shader_grouping()
    -- Create entities with different shaders
    local e1 = create_entity_with_shader("3d_skew_holo")
    local e2 = create_entity_with_shader("3d_skew_foil")
    local e3 = create_entity_with_shader("3d_skew_holo")  -- Same as e1

    local group = render_group.create("shader_test")
    group:add_many({e1, e2, e3})

    -- Verify: e1 and e3 in same bucket, e2 in different bucket
    -- (access bucket internals for testing)
end
```

**4.2 Integration Tests (C++)**
```cpp
// test_batch_rendering_integration.cpp
TEST(BatchRenderingIntegration, MultiShaderEntities) {
    // Create 50 entities with 5 different shaders
    // Verify shader switch count is 5 (not 250)
}

TEST(BatchRenderingIntegration, ZOrderPreservation) {
    // Create entities at different Z levels
    // Verify render order matches Z order
}

TEST(BatchRenderingIntegration, WorldScreenSpaceMix) {
    // Mix World and Screen space entities
    // Verify correct camera behavior
}
```

**4.3 Performance Tests**
```lua
-- test_batch_performance.lua
function test_100_entities_5_shaders()
    local entities = create_test_entities(100, 5, shuffles)
    local group = render_group.create("perf_test")
    group:add_many(entities)

    local start_time = love.timer.getTime()
    group:render(layers.sprites, 0, layer.DrawCommandSpace.World)
    local render_time = love.timer.getTime() - start_time

    print(string.format("100 entities, 5 shaders: %.3f ms", render_time * 1000))
    assert(render_time < 0.005, "Performance regression detected")
end

function test_texture_atlases()
    -- Test with 4 different texture atlases
    local entities = create_entities_with_atlases(100, 4)
    local group = render_group.create("atlas_test")
    group:add_many(entities)

    local switches = measure_texture_switches()
    assert(switches <= 4, "Should only have 4 texture changes")
end
```

**4.4 Visual Verification Tests**
```lua
-- test_visual_rendering.lua
function test_shader_visual_correctness()
    -- Render entities with each shader variant
    -- Screenshot and compare to baseline
    local baseline = load_screenshot("baseline/" .. shader_name .. ".png")
    local current = capture_screenshot()
    local diff = compare_images(baseline, current)
    assert(diff < 0.01, "Visual difference detected for " .. shader_name)
end
```

#### Success Criteria
- [ ] All unit tests pass (Lua + C++)
- [ ] All integration tests pass
- [ ] Performance tests meet targets (<5ms for 100 entities, 5 shaders)
- [ ] Visual tests match baseline screenshots
- [ ] No regressions in existing gameplay

---

## Testing Strategy

### Unit Tests (Lua + C++)

**Coverage Targets**:
- RenderGroup CRUD operations
- Shader grouping logic
- Texture grouping logic
- Z-order preservation
- Draw space handling

**Automation**:
- Lua tests: Run with `lua test_render_group.lua`
- C++ tests: Run with `just test`

### Integration Tests

**Scenarios**:
1. **Multi-shader batch**: 100 entities with 10 shader variants
2. **Z-layer mixing**: Entities at -100, 0, 100, 200 Z levels
3. **Space mixing**: World space entities + Screen space UI
4. **Dynamic entities**: Add/remove entities during frame
5. **Shader pipeline changes**: Entities change shaders during runtime

**Test Execution**:
```bash
just test  # Runs all tests
just build-debug
./build/raylib-cpp-cmake-template --test-mode=rendering
```

### Performance/Stress Tests

**Test Suite**:
```lua
-- test_batch_performance.lua
local scenarios = {
    {name = "50 entities, 1 shader", n=50, shaders=1},
    {name = "50 entities, 5 shaders", n=50, shaders=5},
    {name = "100 entities, 10 shaders", n=100, shaders=10},
    {name = "500 entities, 20 shaders", n=500, shaders=20},
    {name = "1000 entities, mixed", n=1000, shaders=50},
}

for _, scenario in ipairs(scenarios) do
    run_performance_test(scenario)
end
```

**Metrics to Capture**:
- Frame time (ms)
- Shader switches per frame
- Texture changes per frame
- Draw calls per frame
- Memory usage (MB)

**Performance Targets**:
| Scenario | Target Frame Time | Target Shader Switches |
|----------|-------------------|----------------------|
| 50 entities, 1 shader | <2ms | 1 |
| 50 entities, 5 shaders | <3ms | 5 |
| 100 entities, 10 shaders | <5ms | 10 |
| 500 entities, 20 shaders | <12ms | 20 |
| 1000 entities, mixed | <25ms | ~50 |

### Visual Verification

**Approach**:
1. **Baseline Screenshots**: Capture expected output for each shader variant
2. **Automated Comparison**: Image diff tool (SSIM or similar)
3. **Manual Review**: Visual inspection of each shader's effects

**Test Cases**:
- All 3D skew shader variants (20+)
- Overlay blend modes
- Shadow rendering
- Local command rendering (text, stickers)

---

## Migration Guide

### Step-by-Step Migration from Current System

#### Step 1: Replace Z-Bucketing Loop
```lua
-- CURRENT CODE (gameplay.lua lines 2273-2282):
local batchedCardBuckets = {}
for eid, cardScript in pairs(cards) do
    local zToUse = layer_order_system.getZIndex(eid)
    local bucket = batchedCardBuckets[zToUse] or {}
    bucket[#bucket + 1] = eid
    batchedCardBuckets[zToUse] = bucket
end

-- MIGRATED CODE:
local render_group = require("core.render_group")
local cardGroup = render_group.create("gameplay_cards")

for eid, cardScript in pairs(cards) do
    -- RenderGroup automatically handles Z-ordering
    cardGroup:add(eid)
end
```

#### Step 2: Replace Queue Commands Loop
```lua
-- CURRENT CODE (gameplay.lua lines 2285-2294):
if next(batchedCardBuckets) then
    local zKeys = {}
    for z, entityList in pairs(batchedCardBuckets) do
        if #entityList > 0 then
            table.insert(zKeys, z)
        end
    end
    table.sort(zKeys)

    for _, z in ipairs(zKeys) do
        local entityList = batchedCardBuckets[z]
        command_buffer.queueDrawBatchedEntities(layers.sprites, function(cmd)
            cmd.registry = registry
            cmd.entities = entityList
            cmd.autoOptimize = true
        end, z, layer.DrawCommandSpace.Screen)
    end
end

-- MIGRATED CODE:
cardGroup:render(layers.sprites, 0, layer.DrawCommandSpace.Screen)
```

#### Step 3: Add Clear Call
```lua
-- Add at end of render frame:
cardGroup:clear()
```

### Complete Migration Example

**Before (gameplay.lua)**:
```lua
-- ~50 lines of Z-bucketing boilerplate
local batchedCardBuckets = {}
for eid, cardScript in pairs(cards) do
    -- ... Z-bucket logic
end

if next(batchedCardBuckets) then
    -- ... queue command logic
end
```

**After (gameplay.lua)**:
```lua
-- ~10 lines using RenderGroup
local render_group = require("core.render_group")
local cardGroup = render_group.create("gameplay_cards")

for eid, cardScript in pairs(cards) do
    if should_render_card(eid) then
        cardGroup:add(eid)
    end
end

cardGroup:render(layers.sprites, 0, layer.DrawCommandSpace.Screen)
cardGroup:clear()
```

**Benefits**:
- 80% reduction in boilerplate code
- Automatic shader + texture optimization
- No manual Z-bucketing needed
- Reusable pattern for any sprite type

---

## Documentation Requirements

### New Documentation Files

**1. `docs/RENDER_GROUP_GUIDE.md`**
- Overview of RenderGroup system
- API reference (all functions and parameters)
- Usage examples (basic, advanced, ECS views)
- Performance characteristics
- Common patterns and anti-patterns

**2. `docs/BATCH_RENDERING_OPTIMIZATIONS.md`**
- Explanation of shader + texture batching
- How `optimizeEnhanced()` works
- When to use Basic vs Enhanced vs Aggressive optimization
- Performance benchmarks

**3. `docs/MIGRATION_TO_RENDER_GROUP.md`**
- Step-by-step migration guide
- Before/after code examples
- Common migration issues and solutions

**4. Update `BATCHED_ENTITY_RENDERING.md`**
- Add RenderGroup section
- Update examples to use new API
- Deprecation notice for old Z-bucketing pattern

**5. Update `DRAW_COMMAND_OPTIMIZATION.md`**
- Document enhanced optimization levels
- Add performance comparison table
- Update code examples

### Inline Documentation

**C++ Code**:
- Add header comments for all public methods
- Document RenderKey hash algorithm
- Document bucket rebuild strategy
- Add performance notes

**Lua Code**:
- EmmyLua type annotations for all functions
- Inline examples for complex usage
- Document all parameters and return values

---

## Risk Assessment + Mitigations

### Risk 1: Performance Regression

**Description**: New bucket rebuilding logic might be slower than current Z-bucketing.

**Probability**: Medium

**Impact**: High

**Mitigation**:
1. Add dirty flag to only rebuild when entities change
2. Profile bucket rebuild vs old system
3. Add benchmark to catch regressions early
4. Consider static buckets for entity sets that don't change

### Risk 2: Visual Rendering Changes

**Description**: Enhanced optimization or new bucketing might change render order.

**Probability**: Low

**Impact**: High

**Mitigation**:
1. Implement visual verification tests (screenshot comparison)
2. Add debug mode to render bucket boundaries
3. Preserve exact Z-ordering within buckets
4. Add toggle to disable enhanced optimization for testing

### Risk 3: Breaking Existing Code

**Description**: Migration to new API might break third-party scripts.

**Probability**: Medium

**Impact**: High

**Mitigation**:
1. Keep old API deprecated but functional
2. Provide migration warnings when using old API
3. Comprehensive migration guide
4. Test migration on all existing usage sites

### Risk 4: Memory Overhead

**Description**: New buckets and RenderGroups might increase memory usage.

**Probability**: Low

**Impact**: Medium

**Mitigation**:
1. Profile memory usage with Valgrind/ASan
2. Reuse entity vectors where possible
3. Add max bucket size limits
4. Provide clear() method to free memory

### Risk 5: Shader State Corruption

**Description**: Enhanced optimization might miss shader state transitions.

**Probability**: Low

**Impact**: High

**Mitigation**:
1. Track both shader AND texture state
2. Always ensure shader is ended at batch completion
3. Add validation mode to check for state mismatches
4. Extensive unit tests for edge cases

---

## Success Criteria

### Phase Completion Criteria

**Phase 1**:
- [ ] RenderGroup C++ class implemented
- [ ] Lua bindings functional
- [ ] Basic unit tests passing

**Phase 2**:
- [ ] Enhanced optimization working
- [ ] Texture changes reduced by 40%+
- [ ] Performance tests passing

**Phase 3**:
- [ ] gameplay.lua migrated successfully
- [ ] player_inventory.lua migrated successfully
- [ ] Code reduced by 70%+ lines

**Phase 4**:
- [ ] All tests passing (unit + integration + performance)
- [ ] Visual tests match baseline
- [ ] No regressions detected

### Overall Success

**Functional**:
- [ ] RenderGroup system works for any sprite type
- [ ] Shader + texture optimization active
- [ ] Z-ordering correct
- [ ] Draw spaces handled properly
- [ ] All existing functionality preserved

**Performance**:
- [ ] Frame time within targets (see Performance Targets table)
- [ ] Shader switches minimized (1 per unique shader)
- [ ] Texture changes minimized (1 per unique atlas)
- [ ] Memory overhead <10% vs current system

**Code Quality**:
- [ ] Code duplication reduced by 70%+
- [ ] Boilerplate reduced by 80%+ lines
- [ ] API simplified (50% fewer function calls)
- [ ] Comprehensive test coverage (>90% of new code)
- [ ] Documentation complete

**Usability**:
- [ ] Easy to use from Lua (<10 lines of setup)
- [ ] Declarative API (no manual bucket management)
- [ ] Clear migration path from old system
- [ ] Well documented with examples

---

## Implementation Timeline (Estimated: 3-4 weeks)

| Week | Phase | Key Deliverables |
|-------|---------|-----------------|
| 1 | RenderGroup Core | C++ RenderGroup class, Lua bindings, basic tests |
| 1 | Enhanced Optimization | `optimizeEnhanced()` implementation, optimization tests |
| 2 | API Simplification | Migrate gameplay.lua & player_inventory.lua |
| 2 | Documentation | All new documentation files |
| 3 | Comprehensive Testing | Integration, performance, visual tests |
| 4 | Polish & Review | Performance tuning, code review, final testing |

---

## Appendix A: API Reference (Proposed)

### render_group.lua

**`render_group.create(name: string) -> RenderGroup`**
Creates a new render group with given name for debugging.

**`RenderGroup:add(entity: entt.entity) -> nil`**
Adds an entity to the group. Triggers lazy bucket rebuild.

**`RenderGroup:add_many(entities: table<entt.entity>) -> nil`**
Adds multiple entities to the group. More efficient than individual `add()` calls.

**`RenderGroup:remove(entity: entt.entity) -> nil`**
Removes an entity from the group.

**`RenderGroup:clear() -> nil`**
Clears all entities from the group. Call each frame or when entity list changes completely.

**`RenderGroup:render(layer: Layer, zOffset: number?, space: DrawCommandSpace?) -> nil`**
Queues all entities for rendering. Automatically batches by shader + texture.

**`RenderGroup:size() -> number`**
Returns number of entities in group.

**`RenderGroup:get_buckets() -> table`** (debug only)
Returns internal bucket structure for debugging. Use only for profiling.

---

## Appendix B: Performance Benchmarks (Expected)

### Test Setup
- Raylib 5.5
- C++20, Release build
- macOS / Windows / Linux
- GPU: Apple M2 / NVIDIA RTX 3080 / Intel Arc

### Baseline (Current System)

| Entities | Shaders | Frame Time | Shader Switches | Texture Changes |
|----------|----------|-------------|------------------|-----------------|
| 50 | 1 | 1.2ms | 1 | 50 |
| 50 | 5 | 2.8ms | 150 | 250 |
| 100 | 10 | 5.4ms | 1000 | 1000 |

### Expected (New System)

| Entities | Shaders | Frame Time | Shader Switches | Texture Changes |
|----------|----------|-------------|------------------|-----------------|
| 50 | 1 | 1.0ms | 1 | 4 |
| 50 | 5 | 2.2ms | 5 | 20 |
| 100 | 10 | 4.5ms | 10 | 40 |

**Expected Improvement**:
- 10-25% faster frame times
- 97%+ reduction in shader switches
- 96%+ reduction in texture changes
- 20-30% fewer draw calls

---

## Appendix C: Known Issues & Future Work

### Known Issues in Current System
1. **Z-order granularity**: All entities in batch share same Z-order, limiting fine-grained control
2. **No dynamic shader changing**: Entities must be removed/re-added when shaders change
3. **Memory leaks**: Buckets not cleared properly in error paths
4. **Thread safety**: Not thread-safe for multi-threaded rendering

### Future Enhancements
1. **GPU Command Buffers**: Move batching to GPU memory
2. **Multi-threaded bucketing**: Parallel entity processing
3. **Automatic group detection**: Detect entities that should batch together
4. **Hot-swappable shaders**: Change shaders without re-bucketing
5. **Instanced rendering**: Draw thousands of identical sprites in one call

---

**End of Implementation Plan**
