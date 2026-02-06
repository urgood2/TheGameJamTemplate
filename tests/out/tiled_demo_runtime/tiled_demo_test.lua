print("[tiled_demo_test] start")
test_harness.wait_frames(2)

local demo = require("examples.tiled_capability_demo")

local ok, summary_or_err = pcall(function()
    return demo.run({
        mapPath = "tests/out/tiled_demo_runtime/map/demo.tmj",
        mapLayerName = "Ground",
        targetLayer = "sprites",
        printSummary = true,
    })
end)

if not ok then
    print("[tiled_demo_test] ERROR: " .. tostring(summary_or_err))
    test_harness.exit(1)
    return
end

local summary = summary_or_err
print("[tiled_demo_test] map_id=" .. tostring(summary.map_id))
print("[tiled_demo_test] draw_all=" .. tostring(summary.draw_all_count))
print("[tiled_demo_test] draw_all_ysorted=" .. tostring(summary.draw_all_ysorted_count))
print("[tiled_demo_test] draw_layer=" .. tostring(summary.draw_layer_count))
print("[tiled_demo_test] draw_layer_ysorted=" .. tostring(summary.draw_layer_ysorted_count))
print("[tiled_demo_test] object_count=" .. tostring(summary.object_count))
print("[tiled_demo_test] spawn_count=" .. tostring(summary.spawn_count))
print("[tiled_demo_test] ruleset_count=" .. tostring(summary.ruleset_count))
print("[tiled_demo_test] collider_count=" .. tostring(summary.procedural_collider_count))

if summary.ruleset_count ~= 2 then
    print("[tiled_demo_test] BUG: expected 2 rulesets")
    test_harness.exit(1)
    return
end

if summary.object_count < 2 then
    print("[tiled_demo_test] BUG: expected object_count >= 2")
    test_harness.exit(1)
    return
end

if summary.procedural_collider_count <= 0 then
    print("[tiled_demo_test] BUG: expected procedural colliders > 0")
    test_harness.exit(1)
    return
end

test_harness.exit(0)
