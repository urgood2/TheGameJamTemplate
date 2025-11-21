-- Batched Entity Rendering Example
-- This demonstrates how to use the layer queue system with shader batching
-- to avoid Lua execution during the render phase while still getting
-- optimal performance through shader state minimization.

local example = {}

-- Example 1: Basic usage - batch a list of entities
function example.basic_batch(layer, registry, entities)
    -- Queue a batched render command
    -- This captures the entity list NOW (during update phase)
    -- and executes the batching LATER (during render phase)
    layer.queueDrawBatchedEntities(
        layer,
        function(cmd)
            cmd.registry = registry
            cmd.entities = entities  -- std::vector<entt::entity>
            cmd.autoOptimize = true  -- Group by shader (default: true)
        end,
        0,  -- z-order
        layer.DrawCommandSpace.World
    )
end

-- Example 2: Render different entity groups at different z-orders
function example.layered_rendering(myLayer, registry, backgroundEntities, playerEntities, foregroundEntities)
    -- Background entities at z = -100
    layer.queueDrawBatchedEntities(
        myLayer,
        function(cmd)
            cmd.registry = registry
            cmd.entities = backgroundEntities
            cmd.autoOptimize = true
        end,
        -100,
        layer.DrawCommandSpace.World
    )

    -- Player and game entities at z = 0
    layer.queueDrawBatchedEntities(
        myLayer,
        function(cmd)
            cmd.registry = registry
            cmd.entities = playerEntities
            cmd.autoOptimize = true
        end,
        0,
        layer.DrawCommandSpace.World
    )

    -- Foreground/UI entities at z = 100
    layer.queueDrawBatchedEntities(
        myLayer,
        function(cmd)
            cmd.registry = registry
            cmd.entities = foregroundEntities
            cmd.autoOptimize = true
        end,
        100,
        layer.DrawCommandSpace.Screen  -- UI in screen space
    )
end

-- Example 3: Build entity list dynamically, then batch
function example.dynamic_batch(myLayer, registry)
    local entitiesToRender = {}

    -- Gather entities during update phase (Lua is OK here)
    local view = registry:view(AnimationQueueComponent, Transform)
    for entity in view:each() do
        local anim = registry:get(AnimationQueueComponent, entity)
        if not anim.noDraw then
            table.insert(entitiesToRender, entity)
        end
    end

    -- Queue the batch for render phase (no Lua execution during render)
    if #entitiesToRender > 0 then
        layer.queueDrawBatchedEntities(
            myLayer,
            function(cmd)
                cmd.registry = registry
                cmd.entities = entitiesToRender
                cmd.autoOptimize = true
            end,
            0,
            layer.DrawCommandSpace.World
        )
    end
end

-- Example 4: Disable auto-optimize for special cases
-- (e.g., when draw order must be preserved exactly)
function example.ordered_batch(myLayer, registry, entities)
    layer.queueDrawBatchedEntities(
        myLayer,
        function(cmd)
            cmd.registry = registry
            cmd.entities = entities
            cmd.autoOptimize = false  -- Preserve exact order
        end,
        0,
        layer.DrawCommandSpace.World
    )
end

-- Performance Comparison:
--
-- OLD WAY (Lua execution during render):
-- for i = 1, 50 do
--     layer.queueDrawTransformEntityAnimationPipeline(
--         myLayer,
--         function(cmd)
--             cmd.registry = registry
--             cmd.e = entities[i]
--         end,
--         0,
--         layer.DrawCommandSpace.World
--     )
-- end
-- Result: 50 separate render commands, NO shader batching,
--         Lua closure executed 50 times during render
--
-- NEW WAY (No Lua during render, with shader batching):
-- layer.queueDrawBatchedEntities(
--     myLayer,
--     function(cmd)
--         cmd.registry = registry
--         cmd.entities = entities  -- all 50 entities
--         cmd.autoOptimize = true
--     end,
--     0,
--     layer.DrawCommandSpace.World
-- )
-- Result: 1 render command, shader batching active,
--         Lua closure executed ONCE during update phase,
--         Entities batched by shader during render (e.g., 3 shader switches instead of 150)

return example
