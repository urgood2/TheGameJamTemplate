# Draw Command Batching - Testing Guide

## Quick Start Testing

### Method 1: Run Integration Tests (Recommended)

Add this to your Lua initialization code (e.g., in `main.lua` or a test script):

```lua
-- Load the integration test
local IntegrationTest = require("examples.integration_test")

-- Run quick test (no entities required)
IntegrationTest.quickTest()

-- OR run full test suite (requires layer, registry, entity)
-- IntegrationTest.runAll(layers.sprites, registry, someEntity)
```

### Method 2: Run from Lua Console (if available)

```lua
local test = require("examples.integration_test")
test.quickTest()
```

### Method 3: Manual Testing in Your Code

Add this test code to any active Lua file:

```lua
-- Test 1: Basic batch functionality
local function testBasicBatch()
    print("Testing basic draw command batch...")
    
    local batch = shader_draw_commands.DrawCommandBatch()
    batch:beginRecording()
    
    batch:addCustomCommand(function()
        print("  ✅ Custom command executed!")
    end)
    
    batch:endRecording()
    batch:execute()
    
    print("✅ Basic batch test passed!")
end

testBasicBatch()
```

---

## Detailed Testing Steps

### Test 1: Verify System Loads

**Goal:** Confirm the batching system is available in Lua.

```lua
-- Check if the system exists
if shader_draw_commands then
    print("✅ shader_draw_commands module loaded")
else
    print("❌ shader_draw_commands module NOT found")
    return
end

-- Check if DrawCommandBatch constructor exists
if shader_draw_commands.DrawCommandBatch then
    print("✅ DrawCommandBatch constructor available")
else
    print("❌ DrawCommandBatch constructor NOT available")
    return
end

-- Try to create a batch
local batch = shader_draw_commands.DrawCommandBatch()
if batch then
    print("✅ Successfully created DrawCommandBatch instance")
else
    print("❌ Failed to create DrawCommandBatch instance")
    return
end
```

**Expected Output:**
```
✅ shader_draw_commands module loaded
✅ DrawCommandBatch constructor available
✅ Successfully created DrawCommandBatch instance
```

---

### Test 2: Basic Recording & Execution

**Goal:** Verify commands can be recorded and executed.

```lua
local batch = shader_draw_commands.DrawCommandBatch()

-- Start recording
batch:beginRecording()
print("Recording:", batch:recording())  -- Should print: true

-- Add a test command
local executed = false
batch:addCustomCommand(function()
    executed = true
    print("  Custom command ran!")
end)

-- End recording
batch:endRecording()
print("Recording:", batch:recording())  -- Should print: false
print("Batch size:", batch:size())      -- Should print: 1

-- Execute
batch:execute()

if executed then
    print("✅ Test 2 passed: Commands execute correctly")
else
    print("❌ Test 2 failed: Command did not execute")
end
```

**Expected Output:**
```
Recording: true
Recording: false
Batch size: 1
  Custom command ran!
✅ Test 2 passed: Commands execute correctly
```

---

### Test 3: Global Batch Usage

**Goal:** Verify the global batch is accessible and reusable.

```lua
local globalBatch = shader_draw_commands.globalBatch

if not globalBatch then
    print("❌ Global batch not available")
    return
end

-- Clear it first
globalBatch:clear()
print("Global batch size after clear:", globalBatch:size())  -- Should be 0

-- Use it
globalBatch:beginRecording()
globalBatch:addCustomCommand(function()
    print("  Global batch command executed")
end)
globalBatch:endRecording()

print("Global batch size:", globalBatch:size())  -- Should be 1

globalBatch:execute()
print("✅ Test 3 passed: Global batch works")
```

**Expected Output:**
```
Global batch size after clear: 0
Global batch size: 1
  Global batch command executed
✅ Test 3 passed: Global batch works
```

---

### Test 4: Optimization

**Goal:** Test that optimization doesn't break execution.

```lua
local batch = shader_draw_commands.DrawCommandBatch()

batch:beginRecording()

-- Add multiple commands
for i = 1, 5 do
    batch:addCustomCommand(function()
        print(string.format("  Command %d executed", i))
    end)
end

batch:endRecording()

local sizeBeforeOptimize = batch:size()
print("Size before optimize:", sizeBeforeOptimize)

-- Optimize
batch:optimize()

local sizeAfterOptimize = batch:size()
print("Size after optimize:", sizeAfterOptimize)

-- Execute optimized batch
batch:execute()

print("✅ Test 4 passed: Optimization works")
```

**Expected Output:**
```
Size before optimize: 5
Size after optimize: 5
  Command 1 executed
  Command 2 executed
  Command 3 executed
  Command 4 executed
  Command 5 executed
✅ Test 4 passed: Optimization works
```

---

### Test 5: Entity Pipeline (if you have entities)

**Goal:** Test batching with actual game entities.

```lua
-- You need a valid entity with ShaderPipelineComponent
local testEntity = -- your entity here
local registry = -- your registry here

if testEntity and testEntity ~= entt.null then
    local batch = shader_draw_commands.DrawCommandBatch()
    
    batch:beginRecording()
    
    -- This will record all shader pipeline commands for the entity
    shader_draw_commands.executeEntityPipelineWithCommands(
        registry,
        testEntity,
        batch,
        true  -- autoOptimize
    )
    
    batch:endRecording()
    
    print("Entity pipeline generated", batch:size(), "commands")
    
    batch:execute()
    
    print("✅ Test 5 passed: Entity pipeline batching works")
else
    print("⚠️  Test 5 skipped: No valid entity available")
end
```

---

### Test 6: Performance Comparison

**Goal:** Measure performance improvement with batching.

```lua
local example = require("examples.draw_command_batch_example")

-- You need a list of entities with shader pipelines
local entities = {
    -- your entities here
}

if #entities > 0 then
    -- Compare traditional vs batched rendering
    example.comparePerformance(registry, entities, 100)  -- 100 iterations
else
    print("⚠️  Test 6 skipped: No entities available for performance test")
end
```

**Expected Output:**
```
=== Draw Command Batch Performance Test ===
Traditional: 0.8523 seconds
Batched:     0.5147 seconds
Improvement: 39.6%
```

---

## Integration with Your Game

### Where to Add Batching

**1. Card Rendering System** (Highest priority - from your gameplay.lua)

Replace this pattern:
```lua
-- OLD: Individual rendering
for _, cardEid in ipairs(board.cards) do
    layer.DrawTransformEntityWithAnimationWithPipeline(registry, cardEid)
end
```

With:
```lua
-- NEW: Batched rendering
local batch = shader_draw_commands.globalBatch
batch:clear()
batch:beginRecording()

for _, cardEid in ipairs(board.cards) do
    shader_draw_commands.executeEntityPipelineWithCommands(
        registry, cardEid, batch, false
    )
end

batch:endRecording()
batch:optimize()  -- Groups shader passes together
batch:execute()
```

**2. Particle Systems**

If you have many particles with shaders:
```lua
local batch = shader_draw_commands.DrawCommandBatch()
batch:beginRecording()

for _, particle in ipairs(activeParticles) do
    shader_draw_commands.executeEntityPipelineWithCommands(
        registry, particle, batch, false
    )
end

batch:endRecording()
batch:optimize()
batch:execute()
```

**3. Enemy Rendering**

Similar pattern for enemies with shader effects.

---

## Troubleshooting

### Issue: "shader_draw_commands is nil"

**Solution:** The C++ binding might not be registered. Check:
1. Is `shader_draw_commands.cpp` compiled in your build?
2. Is `RegisterDrawCommandBatchTypes()` called during Lua initialization?
3. Check CMakeLists.txt includes the file

### Issue: "Batch is empty after recording"

**Solution:** Commands might not be added correctly. Verify:
```lua
batch:beginRecording()
print("Recording:", batch:recording())  -- Should be true

batch:addCustomCommand(function() print("test") end)
print("Size:", batch:size())  -- Should be > 0

batch:endRecording()
```

### Issue: "Commands don't execute"

**Solution:** Make sure you call all three steps:
```lua
batch:beginRecording()
-- ... add commands ...
batch:endRecording()  -- IMPORTANT: Don't forget this!
batch:execute()
```

### Issue: "Visual glitches with entities"

**Solution:** Entity might need proper transform/animation components. Check:
- Entity has Transform component
- Entity has AnimationObject component (if using animations)
- Entity has ShaderPipelineComponent (if using shaders)

### Issue: "No performance improvement"

**Possible reasons:**
1. **Too few entities:** Batching helps most with 10+ entities
2. **No shared shaders:** Entities using different shaders won't batch well
3. **Not optimizing:** Call `batch:optimize()` before `execute()`
4. **Other bottlenecks:** GPU/CPU might be limited elsewhere

---

## Success Criteria

✅ **Minimum requirements to consider batching "working":**

1. Can create DrawCommandBatch instances
2. Can record and execute custom commands
3. Commands execute in correct order
4. Global batch is accessible
5. Optimization completes without errors
6. No crashes or Lua errors

✅ **Ideal state:**

7. Entity pipeline batching works
8. Measurable performance improvement (10%+)
9. Can batch 10+ entities without issues
10. Integrates smoothly with existing rendering code

---

## Next Steps After Testing

Once basic tests pass:

1. ✅ **Identify hotspots** in your rendering code
   - Look for loops rendering many similar entities
   - Focus on shader-heavy rendering (cards, particles, effects)

2. ✅ **Gradually migrate** one system at a time
   - Start with card rendering (you have ~50+ cards)
   - Then particle effects
   - Then enemy rendering

3. ✅ **Measure impact** with profiling
   - Before/after frame times
   - Shader state change counts
   - FPS improvements

4. ✅ **Tune optimization**
   - Experiment with `autoOptimize` true/false
   - Profile to find sweet spot

---

## Quick Reference

### Key Functions

```lua
-- Create batch
local batch = shader_draw_commands.DrawCommandBatch()

-- Recording
batch:beginRecording()
batch:endRecording()
batch:recording()  -- Returns true/false

-- Adding commands
batch:addCustomCommand(function() ... end)
batch:addBeginShader("shaderName")
batch:addEndShader()

-- Execution
batch:optimize()
batch:execute()
batch:clear()
batch:size()

-- Entity pipeline
shader_draw_commands.executeEntityPipelineWithCommands(
    registry, entity, batch, autoOptimize
)

-- Global batch
shader_draw_commands.globalBatch
```

### Common Patterns

```lua
-- Pattern 1: Single entity
local batch = shader_draw_commands.DrawCommandBatch()
batch:beginRecording()
shader_draw_commands.executeEntityPipelineWithCommands(
    registry, entity, batch, true
)
batch:endRecording()
batch:execute()

-- Pattern 2: Multiple entities (optimized)
local batch = shader_draw_commands.globalBatch
batch:clear()
batch:beginRecording()
for _, entity in ipairs(entities) do
    shader_draw_commands.executeEntityPipelineWithCommands(
        registry, entity, batch, false
    )
end
batch:endRecording()
batch:optimize()
batch:execute()

-- Pattern 3: Custom rendering
local batch = shader_draw_commands.DrawCommandBatch()
batch:beginRecording()
batch:addCustomCommand(function()
    -- Your custom drawing code
end)
batch:endRecording()
batch:execute()
```

---

## Contact & Support

If tests fail or you encounter issues:

1. Check console output for error messages
2. Review INTEGRATION_GUIDE.md for detailed examples
3. Verify C++ bindings are properly registered
4. Ensure all required components exist on entities

Good luck testing! 🚀
