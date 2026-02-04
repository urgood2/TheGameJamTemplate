-- assets/scripts/test/test_selftest.lua
-- Self-tests for the test harness. Tagged selftest to run first.

local TestRunner = require("test.test_runner")
local test_utils = require("test.test_utils")

TestRunner:register("selftest.assert_eq", "selftest", function()
    test_utils.assert_eq(1, 1, "assert_eq should pass for equal values")
end, {
    tags = {"selftest"},
    doc_ids = {"pattern:test.harness.assert_eq"},
    test_file = "assets/scripts/test/test_selftest.lua",
})

TestRunner:register("selftest.safe_filename", "selftest", function()
    local safe = test_utils.safe_filename("bad/name?*")
    test_utils.assert_contains(safe, "bad_name_", "safe_filename should sanitize")
end, {
    tags = {"selftest"},
    doc_ids = {"pattern:test.harness.safe_filename"},
    test_file = "assets/scripts/test/test_selftest.lua",
})

TestRunner:register("selftest.capture_screenshot", "selftest", function()
    local path = test_utils.capture_screenshot("selftest.capture_screenshot")
    local file = io.open(path, "rb")
    test_utils.assert_not_nil(file, "screenshot file should exist")
    if file then
        file:close()
    end
end, {
    tags = {"selftest"},
    doc_ids = {"pattern:test.harness.capture_screenshot"},
    test_file = "assets/scripts/test/test_selftest.lua",
})
