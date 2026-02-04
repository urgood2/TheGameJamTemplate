-- test_runner.lua
-- Test runner DSL and execution engine

local M = {}

local root_suite = {
  name = "<root>",
  parent = nil,
  suites = {},
  tests = {},
  hooks = {
    before_all = {},
    after_all = {},
    before_each = {},
    after_each = {},
  },
}

local current_suite = root_suite
local test_ids = {}
local results = {}
local config_overrides = {}
local current_test_context = nil

local function reset_results()
  results = {
    tests = {},
    passed = 0,
    failed = 0,
    skipped = 0,
    xfail = 0,
    xpass = 0,
    errors = {},
  }
end

local function normalize_segment(value)
  local out = tostring(value or "")
  out = out:gsub("[^%w_]", "_")
  out = out:gsub("_+", "_")
  out = out:gsub("^_+", "")
  out = out:gsub("_+$", "")
  if out == "" then
    out = "segment"
  end
  return out
end

local function is_valid_id(value)
  if type(value) ~= "string" then
    return false
  end
  if value == "" then
    return false
  end
  if value:sub(1, 1) == "." or value:sub(-1) == "." then
    return false
  end
  if value:find("%.%.") then
    return false
  end
  for segment in value:gmatch("[^.]+") do
    if not segment:match("^[A-Za-z0-9_]+$") then
      return false
    end
  end
  return true
end

local function normalize_tags(value)
  if type(value) == "string" then
    local list = {}
    for token in value:gmatch("[^,%s]+") do
      table.insert(list, token)
    end
    return list
  end
  if type(value) == "table" then
    local list = {}
    for _, tag in ipairs(value) do
      table.insert(list, tostring(tag))
    end
    return list
  end
  return {}
end

local function suite_chain(suite)
  local chain = {}
  local cursor = suite
  while cursor and cursor.parent do
    table.insert(chain, 1, cursor)
    cursor = cursor.parent
  end
  return chain
end

local function suite_path(suite)
  local parts = {}
  for _, node in ipairs(suite_chain(suite)) do
    table.insert(parts, normalize_segment(node.name))
  end
  return table.concat(parts, ".")
end

local function generate_test_id(test)
  if test.options.id ~= nil then
    if not is_valid_id(test.options.id) then
      error("invalid test id: " .. tostring(test.options.id))
    end
    return test.options.id
  end
  local path = suite_path(test.suite)
  local name = normalize_segment(test.name)
  if path == "" then
    return name
  end
  return path .. "." .. name
end

local function register_id(id)
  if test_ids[id] then
    error("duplicate test id: " .. id)
  end
  test_ids[id] = true
end

local function ensure_harness()
  local harness = rawget(_G, "test_harness")
  if type(harness) ~= "table" then
    harness = {}
    _G.test_harness = harness
  end
  return harness
end

local function set_skip(reason)
  if not current_test_context then
    error("skip called outside test")
  end
  current_test_context.skip_reason = reason or "skipped"
  error({ skip = true, reason = current_test_context.skip_reason }, 0)
end

local function set_xfail(reason)
  if not current_test_context then
    error("xfail called outside test")
  end
  current_test_context.xfail_reason = reason or "xfail"
  current_test_context.xfail_set = true
end

local function install_harness_hooks()
  local harness = ensure_harness()
  if harness._runner_installed then
    return
  end
  harness._runner_installed = true

  if harness.skip == nil then
    harness.skip = set_skip
  else
    local original = harness.skip
    harness.skip = function(reason)
      set_skip(reason)
      return original(reason)
    end
  end

  if harness.xfail == nil then
    harness.xfail = set_xfail
  else
    local original = harness.xfail
    harness.xfail = function(reason)
      set_xfail(reason)
      return original(reason)
    end
  end
end

local function merge_config()
  local cfg = {
    include_tags = {},
    exclude_tags = {},
    run_quarantined = false,
    fail_fast = false,
    max_failures = 0,
    shuffle_tests = false,
    shuffle_seed = nil,
    rng_scope = "run",
    seed = 0,
    default_timeout_frames = 1800,
  }

  local harness = rawget(_G, "test_harness")
  if type(harness) == "table" and type(harness.args) == "table" then
    local args = harness.args
    cfg.include_tags = normalize_tags(args.include_tags or args.include_tag)
    cfg.exclude_tags = normalize_tags(args.exclude_tags or args.exclude_tag)
    if args.run_quarantined ~= nil then
      cfg.run_quarantined = args.run_quarantined
    end
    if args.fail_fast ~= nil then
      cfg.fail_fast = args.fail_fast
    end
    if args.max_failures ~= nil then
      cfg.max_failures = tonumber(args.max_failures) or cfg.max_failures
    end
    if args.shuffle_tests ~= nil then
      cfg.shuffle_tests = args.shuffle_tests
    end
    if args.shuffle_seed ~= nil then
      cfg.shuffle_seed = tonumber(args.shuffle_seed) or cfg.shuffle_seed
    end
    if args.rng_scope ~= nil then
      cfg.rng_scope = tostring(args.rng_scope)
    end
    if args.seed ~= nil then
      cfg.seed = tonumber(args.seed) or cfg.seed
    end
    if args.default_test_timeout_frames ~= nil then
      cfg.default_timeout_frames = tonumber(args.default_test_timeout_frames) or cfg.default_timeout_frames
    end
  end

  for key, value in pairs(config_overrides) do
    if key == "include_tags" or key == "exclude_tags" then
      cfg[key] = normalize_tags(value)
    else
      cfg[key] = value
    end
  end

  return cfg
end

local function should_run_test(test, cfg)
  if test.options.skip then
    return false, test.options.skip_reason or "skipped"
  end

  local tags = test.tags
  for _, tag in ipairs(tags) do
    if tag == "quarantine" and not cfg.run_quarantined then
      return false, "quarantine"
    end
  end

  if #cfg.include_tags > 0 then
    local matches = false
    for _, include_tag in ipairs(cfg.include_tags) do
      for _, tag in ipairs(tags) do
        if tag == include_tag then
          matches = true
          break
        end
      end
      if matches then break end
    end
    if not matches then
      return false, "tag filtered"
    end
  end

  if #cfg.exclude_tags > 0 then
    for _, exclude_tag in ipairs(cfg.exclude_tags) do
      for _, tag in ipairs(tags) do
        if tag == exclude_tag then
          return false, "tag filtered"
        end
      end
    end
  end

  return true, nil
end

local function lcg(seed)
  local state = seed or 1
  if state < 0 then
    state = -state
  end
  return function()
    state = (1103515245 * state + 12345) % 2147483648
    return state
  end
end

local function shuffle(list, seed)
  local rand = lcg(seed or 1)
  for i = #list, 2, -1 do
    local j = (rand() % i) + 1
    list[i], list[j] = list[j], list[i]
  end
end

local function hash_string(value)
  local hash = 2166136261
  for i = 1, #value do
    hash = hash ~ value:byte(i)
    hash = (hash * 16777619) % 4294967296
  end
  return hash
end

local function isolate_before_test(test, cfg)
  local harness = rawget(_G, "test_harness")
  if type(harness) ~= "table" then
    return
  end

  if type(harness.clear_pending_inputs) == "function" then
    harness.clear_pending_inputs()
  elseif type(harness.clear_inputs) == "function" then
    harness.clear_inputs()
  end

  if type(harness.reset_input_state) == "function" then
    harness.reset_input_state()
  elseif type(harness.reset_input_down_state) == "function" then
    harness.reset_input_down_state()
  end

  if type(harness.log_mark) == "function" then
    harness.log_mark()
  end

  if type(harness.snapshot_restore) == "function" then
    harness.snapshot_restore()
  elseif type(harness.reset_to_known_state) == "function" then
    harness.reset_to_known_state()
  end

  if cfg.rng_scope == "test" then
    local seed_value = hash_string(tostring(cfg.seed) .. ":" .. test.id)
    if type(harness.set_rng_seed) == "function" then
      harness.set_rng_seed(seed_value)
    elseif type(math.randomseed) == "function" then
      math.randomseed(seed_value)
    end
  end
end

local function run_hook_list(hooks)
  for _, hook in ipairs(hooks) do
    local ok, err = xpcall(hook, debug.traceback)
    if not ok then
      return false, err
    end
  end
  return true, nil
end

local function record_result(test, status, err, skip_reason, xfail_reason)
  local entry = {
    id = test.id,
    name = test.name,
    suite_path = test.suite_path,
    status = status,
    error = err,
    skip_reason = skip_reason,
    xfail_reason = xfail_reason,
    tags = test.tags,
  }
  table.insert(results.tests, entry)
  if status == "pass" then
    results.passed = results.passed + 1
  elseif status == "fail" then
    results.failed = results.failed + 1
  elseif status == "skipped" then
    results.skipped = results.skipped + 1
  elseif status == "xfail" then
    results.xfail = results.xfail + 1
  elseif status == "xpass" then
    results.xpass = results.xpass + 1
  end
  if err then
    table.insert(results.errors, err)
  end
end

local function record_global_error(label, err)
  local message = tostring(err)
  if label and label ~= "" then
    message = label .. ": " .. message
  end
  table.insert(results.errors, message)
  results.failed = results.failed + 1
end

local function run_test(test, cfg, suite_state)
  local chain = suite_chain(test.suite)
  for _, suite in ipairs(chain) do
    if not suite_state[suite].before_all_ran then
      suite_state[suite].before_all_ran = true
      local ok, err = run_hook_list(suite.hooks.before_all)
      if not ok then
        record_result(test, "fail", err, nil, nil)
        return "fail"
      end
    end
  end

  isolate_before_test(test, cfg)

  local before_hooks = {}
  local after_hooks = {}
  for _, suite in ipairs(chain) do
    for _, hook in ipairs(suite.hooks.before_each) do
      table.insert(before_hooks, hook)
    end
  end
  for i = #chain, 1, -1 do
    local suite = chain[i]
    for _, hook in ipairs(suite.hooks.after_each) do
      table.insert(after_hooks, hook)
    end
  end

  local status = "pass"
  local err_message = nil
  local skip_reason = nil
  local xfail_reason = nil

  local ok, err = run_hook_list(before_hooks)
  if not ok then
    status = "fail"
    err_message = err
  else
    current_test_context = { skip_reason = nil, xfail_reason = nil, xfail_set = test.options.xfail or false }
    if test.options.xfail then
      current_test_context.xfail_reason = test.options.xfail_reason or "xfail"
    end
    local ok_test, err_test = xpcall(test.fn, function(e)
      return e
    end)
    if not ok_test then
      if type(err_test) == "table" and err_test.skip then
        status = "skipped"
        skip_reason = err_test.reason
      else
        status = "fail"
        err_message = err_test
      end
    end
    if current_test_context.xfail_set then
      xfail_reason = current_test_context.xfail_reason or "xfail"
      if status == "pass" then
        status = "xpass"
      elseif status == "fail" then
        status = "xfail"
        err_message = nil
      end
    end
    current_test_context = nil
  end

  local ok_after, err_after = run_hook_list(after_hooks)
  if not ok_after then
    status = "fail"
    err_message = err_after
  end

  record_result(test, status, err_message, skip_reason, xfail_reason)
  return status
end

local function collect_tests(suite, list)
  for _, test in ipairs(suite.tests) do
    table.insert(list, test)
  end
  for _, child in ipairs(suite.suites) do
    collect_tests(child, list)
  end
end

local function count_run_tests(suite)
  local count = 0
  for _, test in ipairs(suite.tests) do
    if test.should_run then
      count = count + 1
    end
  end
  for _, child in ipairs(suite.suites) do
    count = count + count_run_tests(child)
  end
  return count
end

local function init_suite_state(suite, state)
  state[suite] = {
    before_all_ran = false,
    remaining = 0,
    after_all_ran = false,
  }
  for _, child in ipairs(suite.suites) do
    init_suite_state(child, state)
  end
end

local function update_remaining_counts(suite, state)
  local total = count_run_tests(suite)
  state[suite].remaining = total
  for _, child in ipairs(suite.suites) do
    update_remaining_counts(child, state)
  end
end

local function finish_after_all(chain, state)
  for i = #chain, 1, -1 do
    local suite = chain[i]
    if state[suite].remaining == 0 and not state[suite].after_all_ran then
      state[suite].after_all_ran = true
      local ok, err = run_hook_list(suite.hooks.after_all)
      if not ok then
        record_global_error("afterAll failed", err)
      end
    end
  end
end

function M.reset()
  root_suite.suites = {}
  root_suite.tests = {}
  root_suite.hooks.before_all = {}
  root_suite.hooks.after_all = {}
  root_suite.hooks.before_each = {}
  root_suite.hooks.after_each = {}
  current_suite = root_suite
  test_ids = {}
  config_overrides = {}
  reset_results()
end

function M.configure(opts)
  if type(opts) ~= "table" then
    return
  end
  for key, value in pairs(opts) do
    config_overrides[key] = value
  end
end

function M.get_results()
  return results
end

function M.describe(name, fn)
  local suite = {
    name = tostring(name or ""),
    parent = current_suite,
    suites = {},
    tests = {},
    hooks = {
      before_all = {},
      after_all = {},
      before_each = {},
      after_each = {},
    },
  }
  table.insert(current_suite.suites, suite)
  local previous = current_suite
  current_suite = suite
  if type(fn) == "function" then
    fn()
  end
  current_suite = previous
end

function M.it(name, opts_or_fn, fn)
  local options = {}
  local body = fn
  if type(opts_or_fn) == "function" then
    body = opts_or_fn
  elseif type(opts_or_fn) == "table" then
    options = opts_or_fn
  end
  local test = {
    name = tostring(name or ""),
    suite = current_suite,
    fn = body or function() end,
    options = options,
  }
  test.tags = normalize_tags(options.tags)
  test.timeout_frames = tonumber(options.timeout_frames)
  if not test.timeout_frames then
    test.timeout_frames = nil
  end
  test.retry_count = tonumber(options.retry_count)
  if not test.retry_count then
    test.retry_count = 0
  end
  test.skip_reason = options.skip_reason
  test.xfail_reason = options.xfail_reason
  test.id = generate_test_id(test)
  test.suite_path = suite_path(current_suite)
  register_id(test.id)
  table.insert(current_suite.tests, test)
end

function M.beforeAll(fn)
  if type(fn) == "function" then
    table.insert(current_suite.hooks.before_all, fn)
  end
end

function M.afterAll(fn)
  if type(fn) == "function" then
    table.insert(current_suite.hooks.after_all, fn)
  end
end

function M.beforeEach(fn)
  if type(fn) == "function" then
    table.insert(current_suite.hooks.before_each, fn)
  end
end

function M.afterEach(fn)
  if type(fn) == "function" then
    table.insert(current_suite.hooks.after_each, fn)
  end
end

function M.before_each(fn)
  return M.beforeEach(fn)
end

function M.after_each(fn)
  return M.afterEach(fn)
end

function M.run(opts)
  if opts then
    M.configure(opts)
  end

  reset_results()
  install_harness_hooks()

  local cfg = merge_config()
  local tests = {}
  collect_tests(root_suite, tests)

  for _, test in ipairs(tests) do
    local run_ok, skip_reason = should_run_test(test, cfg)
    test.should_run = run_ok
    test.skip_reason = skip_reason
  end

  local suite_state = {}
  init_suite_state(root_suite, suite_state)
  update_remaining_counts(root_suite, suite_state)

  if cfg.shuffle_tests then
    local seed = cfg.shuffle_seed or cfg.seed or 1
    shuffle(tests, seed)
  end

  local failure_count = 0
  for _, test in ipairs(tests) do
    if test.should_run then
      local status = run_test(test, cfg, suite_state)
      local chain = suite_chain(test.suite)
      for _, suite in ipairs(chain) do
        suite_state[suite].remaining = suite_state[suite].remaining - 1
      end
      finish_after_all(chain, suite_state)

      if status == "fail" or status == "xpass" then
        failure_count = failure_count + 1
        if cfg.fail_fast then
          break
        end
        if cfg.max_failures and cfg.max_failures > 0 and failure_count >= cfg.max_failures then
          break
        end
      end
    else
      record_result(test, "skipped", nil, test.skip_reason or "skipped", nil)
    end
  end

  results.ok = (results.failed == 0 and results.xpass == 0)
  return results
end

M.reset()

return M
