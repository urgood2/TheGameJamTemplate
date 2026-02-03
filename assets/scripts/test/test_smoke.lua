-- test_smoke.lua
-- Minimal harness validation tests (runs without engine scene).

local TestRunner = require("test.test_runner")
local test_utils = require("test.test_utils")

TestRunner.register("harness.self.assertions", "selftest", function()
    test_utils.assert_eq(1, 1, "eq")
    test_utils.assert_neq(1, 2, "neq")
    test_utils.assert_true(true, "true")
    test_utils.assert_false(false, "false")
    test_utils.assert_nil(nil, "nil")
    test_utils.assert_not_nil({}, "not nil")
    test_utils.assert_contains("hello world", "world", "contains")
    test_utils.assert_throws(function() error("boom") end)
    test_utils.assert_error(function() error("boom") end, "boom")
end, {
    tags = {"selftest", "smoke"},
    self_test = true,
})

TestRunner.register("harness.self.safe_filename", "selftest", function()
    local safe = test_utils.safe_filename("ui.layout alignment")
    test_utils.assert_contains(safe, "ui.layout", "safe filename keeps prefix")
end, {
    tags = {"selftest", "smoke"},
    self_test = true,
})

TestRunner.register("harness.self.screenshot_placeholder", "selftest", function()
    local path = test_utils.capture_screenshot("harness.smoke.screenshot")
    local handle = io.open(path, "rb")
    test_utils.assert_not_nil(handle, "screenshot placeholder exists")
    if handle then
        handle:close()
    end
end, {
    tags = {"selftest", "smoke"},
    self_test = true,
})

return true
