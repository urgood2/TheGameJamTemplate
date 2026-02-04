-- test_runner_spec.lua
-- Self test for framework test_runner

package.path = package.path .. ";./assets/scripts/?.lua"

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error(message or ("assert_eq failed: " .. tostring(actual) .. " vs " .. tostring(expected)))
  end
end

local function assert_true(value, message)
  if not value then
    error(message or "assert_true failed")
  end
end

local function assert_false(value, message)
  if value then
    error(message or "assert_false failed")
  end
end

local runner = require("tests.framework.test_runner")

local function make_harness()
  local harness = {
    args = {
      include_tags = {},
      exclude_tags = {},
      run_quarantined = false,
      fail_fast = false,
      max_failures = 0,
      shuffle_tests = false,
      shuffle_seed = 1234,
      rng_scope = "test",
      seed = 42,
      default_test_timeout_frames = 1800,
    },
    clear_inputs_count = 0,
    reset_input_count = 0,
    log_mark_count = 0,
    snapshot_restore_count = 0,
    rng_seed_values = {},
  }

  function harness.clear_inputs()
    harness.clear_inputs_count = harness.clear_inputs_count + 1
  end

  function harness.reset_input_state()
    harness.reset_input_count = harness.reset_input_count + 1
  end

  function harness.log_mark()
    harness.log_mark_count = harness.log_mark_count + 1
    return harness.log_mark_count
  end

  function harness.snapshot_restore()
    harness.snapshot_restore_count = harness.snapshot_restore_count + 1
  end

  function harness.set_rng_seed(value)
    table.insert(harness.rng_seed_values, value)
  end

  _G.test_harness = harness
  return harness
end

local function run_hook_order_test()
  local harness = make_harness()
  runner.reset()

  local order = {}
  runner.describe("outer", function()
    runner.beforeAll(function() table.insert(order, "beforeAll outer") end)
    runner.afterAll(function() table.insert(order, "afterAll outer") end)
    runner.beforeEach(function() table.insert(order, "beforeEach outer") end)
    runner.afterEach(function() table.insert(order, "afterEach outer") end)

    runner.it("first test", { id = "stable.first", tags = { "smoke" } }, function()
      table.insert(order, "test first")
    end)

    runner.describe("inner", function()
      runner.beforeEach(function() table.insert(order, "beforeEach inner") end)
      runner.afterEach(function() table.insert(order, "afterEach inner") end)
      runner.it("second test", { tags = { "smoke" } }, function()
        table.insert(order, "test second")
      end)
    end)
  end)

  local result = runner.run({ include_tags = { "smoke" } })
  assert_eq(result.passed, 2, "expected two passing tests")

  local expected = {
    "beforeAll outer",
    "beforeEach outer",
    "test first",
    "afterEach outer",
    "beforeEach outer",
    "beforeEach inner",
    "test second",
    "afterEach inner",
    "afterEach outer",
    "afterAll outer",
  }

  assert_eq(#order, #expected, "hook order length mismatch")
  for i = 1, #expected do
    assert_eq(order[i], expected[i], "hook order mismatch at index " .. tostring(i))
  end

  assert_eq(harness.clear_inputs_count, 2, "clear inputs count")
  assert_eq(harness.reset_input_count, 2, "reset input count")
  assert_eq(harness.log_mark_count, 2, "log mark count")
  assert_eq(harness.snapshot_restore_count, 2, "snapshot restore count")
  assert_eq(#harness.rng_seed_values, 2, "rng seed count")

  local test_two = result.tests[2]
  assert_eq(test_two.id, "outer.inner.second_test", "generated id mismatch")
end

local function run_skip_xfail_test()
  make_harness()
  runner.reset()

  runner.describe("skip and xfail", function()
    runner.it("skip test", function()
      test_harness.skip("skip reason")
    end)
    runner.it("xfail test", function()
      test_harness.xfail("xfail reason")
      error("fail")
    end)
    runner.it("xpass test", function()
      test_harness.xfail("xfail reason")
    end)
  end)

  local result = runner.run()
  assert_eq(result.skipped, 1, "skipped count")
  assert_eq(result.xfail, 1, "xfail count")
  assert_eq(result.xpass, 1, "xpass count")
end

local function run_tag_filter_test()
  local harness = make_harness()
  harness.args.include_tags = { "smoke" }
  harness.args.exclude_tags = { "slow" }
  harness.args.run_quarantined = false

  runner.reset()
  runner.describe("tags", function()
    runner.it("fast test", { tags = { "smoke" } }, function() end)
    runner.it("slow test", { tags = { "smoke", "slow" } }, function() end)
    runner.it("quarantine test", { tags = { "quarantine" } }, function() end)
  end)

  local result = runner.run()
  assert_eq(result.passed, 1, "tag filtered pass count")
  assert_eq(result.skipped, 2, "tag filtered skip count")
end

local function run_fail_fast_test()
  local harness = make_harness()
  harness.args.fail_fast = true

  runner.reset()
  local order = {}
  runner.describe("fail fast", function()
    runner.it("first fail", function()
      table.insert(order, "first")
      error("fail")
    end)
    runner.it("second test", function()
      table.insert(order, "second")
    end)
  end)

  local result = runner.run()
  assert_eq(result.failed, 1, "fail fast failure count")
  assert_eq(#order, 1, "fail fast should stop early")
end

local function run_shuffle_test()
  local harness = make_harness()
  harness.args.shuffle_tests = true
  harness.args.shuffle_seed = 99

  local function register_tests()
    runner.describe("shuffle", function()
      runner.it("alpha", function() end)
      runner.it("beta", function() end)
      runner.it("gamma", function() end)
      runner.it("delta", function() end)
    end)
  end

  runner.reset()
  register_tests()
  local first = runner.run()

  runner.reset()
  register_tests()
  local second = runner.run()

  local function ids(result)
    local list = {}
    for _, entry in ipairs(result.tests) do
      table.insert(list, entry.id)
    end
    return table.concat(list, ",")
  end

  assert_eq(ids(first), ids(second), "shuffle order should be deterministic")
end

run_hook_order_test()
run_skip_xfail_test()
run_tag_filter_test()
run_fail_fast_test()
run_shuffle_test()

print("test_runner_spec.lua passed")
