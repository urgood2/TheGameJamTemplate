--[[
    Draw Command Batch Example

    This example demonstrates how to use the new draw command batching system
    to optimize shader rendering performance. Instead of switching shaders
    for each entity individually, we can batch draw commands and execute them
    in an optimized order.

    Benefits:
    - Reduces texture ping-pong when rendering many entities
    - Minimizes shader state changes
    - Allows Lua configuration of rendering pipeline
    - Maintains compatibility with existing rendering code
]]

-- Create a new draw command batch
local batch = shader_draw_commands.DrawCommandBatch()

-- Example 1: Manual command batching
function exampleManualBatch()
    batch:beginRecording()

    -- Add a sequence of draw commands
    batch:addBeginShader("blur")
    -- Your draw calls here would go through the batch
    batch:addEndShader()

    batch:addBeginShader("glow")
    -- More draw calls
    batch:addEndShader()

    batch:endRecording()

    -- Optionally optimize to reduce state changes
    batch:optimize()

    -- Execute all commands in batch
    batch:execute()

    print(string.format("Executed %d draw commands", batch:size()))
end

-- Example 2: Using with entity pipeline
function exampleEntityPipeline(registry, entity)
    -- Create a batch for this entity's shader pipeline
    local entityBatch = shader_draw_commands.DrawCommandBatch()

    -- Execute the entity's pipeline using command batching
    shader_draw_commands.executeEntityPipelineWithCommands(
        registry,
        entity,
        entityBatch,
        true  -- autoOptimize = true
    )

    -- Execute the optimized batch
    entityBatch:execute()
end

-- Example 3: Batching multiple entities to reduce shader switching
function exampleMultiEntityBatch(registry, entities)
    -- Use the global batch for convenience
    local globalBatch = shader_draw_commands.globalBatch

    globalBatch:clear()
    globalBatch:beginRecording()

    -- Process all entities and record their draw commands
    for _, entity in ipairs(entities) do
        -- Add each entity's rendering commands to the batch
        shader_draw_commands.executeEntityPipelineWithCommands(
            registry,
            entity,
            globalBatch,
            false  -- Don't optimize yet, we'll do it once at the end
        )
    end

    globalBatch:endRecording()

    -- Optimize once for all entities - this groups commands by shader
    globalBatch:optimize()

    -- Execute all commands efficiently
    globalBatch:execute()

    print(string.format("Batched rendering for %d entities with %d commands",
        #entities, globalBatch:size()))
end

-- Example 4: Custom draw commands with callbacks
function exampleCustomCommands()
    local batch = shader_draw_commands.DrawCommandBatch()

    batch:beginRecording()

    -- You can inject custom Lua functions into the command stream
    batch:addCustomCommand(function()
        print("Before shader pass")
    end)

    batch:addBeginShader("myShader")

    batch:addCustomCommand(function()
        print("During shader pass")
        -- Set custom uniforms, update state, etc.
    end)

    batch:addEndShader()

    batch:addCustomCommand(function()
        print("After shader pass")
    end)

    batch:endRecording()
    batch:execute()
end

-- Example 5: Performance comparison helper
function comparePerformance(registry, entities, iterations)
    print("\n=== Draw Command Batch Performance Test ===")

    -- Test traditional approach
    local traditionalStart = os.clock()
    for i = 1, iterations do
        for _, entity in ipairs(entities) do
            layer.DrawTransformEntityWithAnimationWithPipeline(registry, entity)
        end
    end
    local traditionalTime = os.clock() - traditionalStart

    -- Test batched approach
    local batchedStart = os.clock()
    for i = 1, iterations do
        exampleMultiEntityBatch(registry, entities)
    end
    local batchedTime = os.clock() - batchedStart

    print(string.format("Traditional: %.4f seconds", traditionalTime))
    print(string.format("Batched:     %.4f seconds", batchedTime))
    print(string.format("Improvement: %.1f%%",
        (traditionalTime - batchedTime) / traditionalTime * 100))
end

return {
    exampleManualBatch = exampleManualBatch,
    exampleEntityPipeline = exampleEntityPipeline,
    exampleMultiEntityBatch = exampleMultiEntityBatch,
    exampleCustomCommands = exampleCustomCommands,
    comparePerformance = comparePerformance
}
