print('[tiled_demo_diag] start')
test_harness.wait_frames(2)

local tiled = assert(_G.tiled, 'tiled bindings missing')
local tiled_bridge = require('core.procgen.tiled_bridge')

local map_path = 'tests/out/tiled_demo_runtime/map/demo.tmj'
local map_id = tiled.load_map(map_path)
tiled.set_active_map(map_id)
print('[tiled_demo_diag] map_id=' .. tostring(map_id))

local draw_opts = {
  map_id = map_id,
  base_z = 0,
  layer_z_step = 1,
  z_per_row = 1,
  offset_x = 0,
  offset_y = 0,
  opacity = 1.0,
}

local cam_ok, cam = pcall(function()
  if camera and camera.Get then
    return camera.Get('world_camera')
  end
  return nil
end)

if cam_ok and cam then
  cam:SetActualTarget(256, 256)
  cam:SetActualOffset(640, 360)
  cam:SetActualZoom(1.0)
  print('[tiled_demo_diag] camera configured target=(256,256) zoom=1.0')
else
  print('[tiled_demo_diag] camera binding unavailable')
end

for i = 1, 360 do
  local count = tiled_bridge.drawAllLayersYSorted('sprites', draw_opts)
  if i % 60 == 0 then
    local cam_msg = ''
    if cam_ok and cam then
      local t = cam:GetActualTarget()
      local z = cam:GetActualZoom()
      cam_msg = string.format(' cam_target=(%.1f,%.1f) zoom=%.2f', t.x, t.y, z)
    end
    print('[tiled_demo_diag] frame=' .. tostring(i) .. ' draw_count=' .. tostring(count) .. cam_msg)
  end
  test_harness.wait_frames(1)
end

print('[tiled_demo_diag] done')
test_harness.exit(0)
