print('[tiled_demo_live] start')
test_harness.wait_frames(2)

local tiled = assert(_G.tiled, 'tiled bindings missing')
local tiled_bridge = require('core.procgen.tiled_bridge')

local map_path = 'tests/out/tiled_demo_runtime/map/demo.tmj'
local map_id = tiled.load_map(map_path)
tiled.set_active_map(map_id)

print('[tiled_demo_live] map_id=' .. tostring(map_id))

local cam_ok, cam = pcall(function()
  if camera and camera.Get then
    return camera.Get('world_camera')
  end
  return nil
end)

if cam_ok and cam then
  -- Deterministic framing so the demo is visible even when normal gameplay
  -- camera updates are bypassed by test mode.
  cam:SetActualTarget(256, 256)
  cam:SetActualOffset(640, 360)
  cam:SetActualZoom(1.0)
  print('[tiled_demo_live] camera target=(256,256) zoom=1.0')
else
  print('[tiled_demo_live] camera binding unavailable; using engine defaults')
end

local draw_opts = {
  map_id = map_id,
  base_z = 0,
  layer_z_step = 1,
  z_per_row = 1,
  offset_x = 0,
  offset_y = 0,
  opacity = 1.0,
}

for i = 1, 216000 do
  local draw_count = tiled_bridge.drawAllLayersYSorted('background', draw_opts)
  if draw_count <= 0 and i == 1 then
    print('[tiled_demo_live] BUG: draw_count=0 on first frame')
  end
  if i % 300 == 0 then
    print('[tiled_demo_live] frame=' .. tostring(i) .. ' draw_count=' .. tostring(draw_count))
  end
  test_harness.wait_frames(1)
end

print('[tiled_demo_live] timeout_exit')
test_harness.exit(0)
