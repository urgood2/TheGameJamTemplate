-- assets/scripts/tests/bargain/run_bargain_tests.lua
-- Thin wrapper invoked by the C++ headless runner.

require("tests.run_bargain_tests")

return {
    run = _G.run_bargain_tests,
    passed = _G.BARGAIN_TESTS_PASSED,
    exit_code = _G.BARGAIN_EXIT_CODE,
}
