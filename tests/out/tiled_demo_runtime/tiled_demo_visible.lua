print('[tiled_demo_visible] start')
test_harness.wait_frames(2)

local tiled = assert(_G.tiled, 'tiled bindings missing')
local tiled_bridge = require('core.procgen.tiled_bridge')

local map_path = 'tests/out/tiled_demo_runtime/map/demo.tmj'
local map_id = tiled.load_map(map_path)
tiled.set_active_map(map_id)

print('[tiled_demo_visible] map_id=' .. tostring(map_id))

local draw_opts = {
  map_id = map_id,
  base_z = 0,
  layer_z_step = 1,
  z_per_row = 1,
  offset_x = 240,
  offset_y = 140,
  opacity = 1.0,
}

for i = 1, 600 do
  tiled_bridge.drawAllLayersYSorted('sprites', draw_opts)
  if i % 120 == 0 then
    print('[tiled_demo_visible] frame=' .. tostring(i))
  end
  test_harness.wait_frames(1)
end

print('[tiled_demo_visible] done')
test_harness.exit(0)
