print('[tiled_demo_invalid_map_test] start')
test_harness.wait_frames(2)

local demo = require('examples.tiled_capability_demo')
local ok, err = pcall(function()
    demo.run({
        mapPath = 'tests/out/tiled_demo_runtime/map/does_not_exist.tmj',
        mapLayerName = 'Ground',
        targetLayer = 'sprites',
        printSummary = false,
    })
end)

if ok then
    print('[tiled_demo_invalid_map_test] BUG: expected invalid map path to fail')
    test_harness.exit(1)
end

print('[tiled_demo_invalid_map_test] err=' .. tostring(err))
if not string.find(tostring(err), 'Failed') and not string.find(tostring(err), 'map') then
    print('[tiled_demo_invalid_map_test] BUG: expected useful error mentioning map load failure')
    test_harness.exit(1)
end

test_harness.exit(0)
