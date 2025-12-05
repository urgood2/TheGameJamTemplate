# shader_draw_commands Lua docs

Reference and examples for the batched shader draw command helpers exposed from `shader_draw_commands.cpp`. Use these APIs when you want to minimize shader state churn or render many entities through the shader pipeline from Lua without issuing dozens of individual layer commands.

## Quick start (manual batch)

```lua
local batch = shader_draw_commands.globalBatch
batch:clear()
batch:beginRecording()
batch:addBeginShader("crt")
batch:addDrawTexture(myTexture, { x = 0, y = 0, width = 128, height = 128 }, { x = 50, y = 50 })
batch:addEndShader()
batch:endRecording()
batch:optimize() -- optional when order is not critical
batch:execute()
```

Notes:
- Call `beginRecording`/`endRecording` around your additions; nothing is queued if you forget to start recording.
- `optimize` removes redundant shader switches but should be skipped if strict ordering matters.
- Reuse `shader_draw_commands.globalBatch` to avoid allocating a new batch every frame.

## Entity pipeline batching

`shader_draw_commands.executeEntityPipelineWithCommands(registry, entity, batch, autoOptimize?)` records the current sprite (with flips and colors), shader passes, overlays, and any `BatchedLocalCommands` into the batch. When `autoOptimize` is true, the batch is optimized after recording. This is the building block used by `layer.queueDrawBatchedEntities` (see `BATCHED_ENTITY_RENDERING.md`) and is the safest way to batch-render multiple entities through their shader pipelines from Lua.

Example: merge a few entities into one draw call without touching the render loop:

```lua
local entities = { e1, e2, e3 }
local batch = shader_draw_commands.globalBatch

batch:clear()
batch:beginRecording()
for _, e in ipairs(entities) do
  shader_draw_commands.executeEntityPipelineWithCommands(registry, e, batch, false)
end
batch:endRecording()
batch:optimize()
batch:execute()
```

## Local draw commands per-entity

`shader_draw_commands.add_local_command(registry, entity, type, initFn, z?, space?, forceTextPass?, forceUvPassthrough?)` attaches a layer command to the entity so it renders inside its shader pipeline. Common `type` values mirror layer command names such as `draw_rect`, `draw_text`, `begin_scissor`, `render_ui_slice`, `draw_sprite_centered`, `set_shader`, etc. The `z` field controls ordering relative to the sprite: negative values draw before the sprite, non-negative after. `forceTextPass` routes the command through the text pass, and `forceUvPassthrough` is useful for 3d_skew shaders that should not remap UVs.

```lua
shader_draw_commands.add_local_command(
  registry,
  entity,
  "draw_rect",
  function(cmd)
    cmd.x, cmd.y = 0, 0
    cmd.width, cmd.height = 40, 8
    cmd.color = { r = 0, g = 0, b = 0, a = 128 }
  end,
  -1, -- z: draw before sprite
  layer.DrawCommandSpace.World
)
```

## API summary

- `DrawCommandBatch` methods: `beginRecording`, `endRecording`, `recording`, `addBeginShader`, `addEndShader`, `addDrawTexture`, `addDrawText`, `addSetUniforms`, `addCustomCommand`, `execute`, `optimize`, `clear`, `size`.
- Module helpers: `shader_draw_commands.globalBatch`, `shader_draw_commands.add_local_command`, `shader_draw_commands.executeEntityPipelineWithCommands`.
- More batch optimization notes live in `DRAW_COMMAND_OPTIMIZATION.md`; batching inside the layer queue is covered in `BATCHED_ENTITY_RENDERING.md`.
