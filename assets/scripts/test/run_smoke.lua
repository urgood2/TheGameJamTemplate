-- assets/scripts/test/run_smoke.lua
-- Standalone runner for smoke + selftests.

package.path = "assets/scripts/?.lua;assets/scripts/?/init.lua;" .. package.path

local TestRunner = require("test.test_runner")

dofile("assets/scripts/test/test_selftest.lua")
dofile("assets/scripts/test/test_smoke.lua")

local success = TestRunner.run()
if not success then
    os.exit(1)
end
