print('[tiled_demo_probe] start')
test_harness.wait_frames(2)

local tiled = assert(_G.tiled, 'tiled bindings missing')
local tiled_bridge = require('core.procgen.tiled_bridge')

local map_path = 'tests/out/tiled_demo_runtime/map/demo.tmj'
local map_id = tiled.load_map(map_path)
tiled.set_active_map(map_id)
print('[tiled_demo_probe] map_id=' .. tostring(map_id))

local draw_opts = {
  map_id = map_id,
  base_z = 0,
  layer_z_step = 1,
  z_per_row = 1,
  offset_x = 200,
  offset_y = 120,
  opacity = 1.0,
}

for i = 1, 180 do
  draw_opts.offset_x = 200 + math.floor(i / 3)
  tiled_bridge.drawAllLayersYSorted('sprites', draw_opts)
  if i == 90 and TakeScreenshot then
    TakeScreenshot('tests/out/tiled_demo_runtime/probe_frame90.png')
    print('[tiled_demo_probe] screenshot_taken frame=90')
  end
  test_harness.wait_frames(1)
end

print('[tiled_demo_probe] done')
test_harness.exit(0)
