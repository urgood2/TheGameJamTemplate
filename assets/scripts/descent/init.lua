local M = {
  _active = false,
  _seed = nil,
  _cleanup = nil,
  _last_error = nil,
  _test_mode = false,
}

--------------------------------------------------------------------------------
-- Logging
--------------------------------------------------------------------------------

local function log_info(message)
  if type(log_debug) == "function" then
    log_debug(message)
  else
    print(message)
  end
end

local function log_error(message)
  if type(log_warn) == "function" then
    log_warn(message)
  else
    print("[ERROR] " .. message)
  end
end

--------------------------------------------------------------------------------
-- Seed Resolution
--------------------------------------------------------------------------------

local function resolve_seed(opts)
  if opts and opts.seed ~= nil then
    return opts.seed
  end
  if os.getenv then
    local raw = os.getenv("DESCENT_SEED")
    if raw and raw ~= "" then
      local as_number = tonumber(raw)
      return as_number ~= nil and as_number or raw
    end
  end
  return nil
end

--------------------------------------------------------------------------------
-- Error Handling
--------------------------------------------------------------------------------

--- Handle runtime errors gracefully
--- @param err string Error message
--- @param context string|nil Context where error occurred
function M.handle_error(err, context)
  local full_error = tostring(err)
  if context then
    full_error = "[" .. context .. "] " .. full_error
  end

  M._last_error = {
    message = full_error,
    seed = M._seed,
    timestamp = os.time(),
    traceback = debug and debug.traceback() or nil,
  }

  log_error("[Descent] Runtime error: " .. full_error)

  -- In test mode, exit with code 1
  if M._test_mode or os.getenv("RUN_DESCENT_TESTS") == "1" then
    log_error("[Descent] Test mode - exiting with error")
    log_error("Seed: " .. tostring(M._seed))
    log_error("Error: " .. full_error)
    if os.exit then
      os.exit(1)
    end
    return
  end

  -- In normal mode, route to error ending screen
  M.show_error_screen(full_error)
end

--- Protected call with error handling
--- @param fn function Function to call
--- @param context string|nil Context for error reporting
--- @return boolean, any Success flag and result or error
function M.pcall(fn, context)
  local ok, result = pcall(fn)
  if not ok then
    M.handle_error(result, context)
    return false, result
  end
  return true, result
end

--- Show error ending screen
--- @param error_message string Error to display
function M.show_error_screen(error_message)
  -- Try to load and show error UI
  local ok, endings = pcall(require, "descent.ui.endings")
  if ok and endings and endings.show_error then
    endings.show_error({
      message = error_message,
      seed = M._seed,
      can_retry = true,
    })
  else
    -- Fallback: just stop and return to menu
    log_error("[Descent] Error screen unavailable, returning to menu")
    M.stop("error: " .. error_message)
  end
end

--- Get last error info
--- @return table|nil Last error or nil
function M.get_last_error()
  return M._last_error
end

--- Clear last error
function M.clear_error()
  M._last_error = nil
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function M.start(opts)
  if M._active then
    return
  end

  M._active = true
  M._seed = resolve_seed(opts)
  M._test_mode = opts and opts.test_mode or os.getenv("RUN_DESCENT_TESTS") == "1"
  M._last_error = nil

  local seed_info = (M._seed ~= nil) and tostring(M._seed) or "(none)"
  log_info("[Descent] start (seed=" .. seed_info .. ")")

  -- Protected initialization
  local ok, err = M.pcall(function()
    -- Initialize state module
    local state_ok, state = pcall(require, "descent.state")
    if state_ok and state and state.init then
      state.init(M._seed)
    end

    -- Initialize RNG
    local rng_ok, rng = pcall(require, "descent.rng")
    if rng_ok and rng and rng.init then
      rng.init(M._seed)
    end
  end, "init")

  if not ok then
    log_error("[Descent] Initialization failed: " .. tostring(err))
  end
end

function M.stop(reason)
  if not M._active then
    return
  end

  M._active = false

  if type(timer) == "table" and type(timer.kill_group) == "function" then
    timer.kill_group("descent")
  end

  if type(M._cleanup) == "function" then
    local ok, err = pcall(M._cleanup)
    if not ok then
      log_info("[Descent] cleanup failed: " .. tostring(err))
    end
  end

  log_info("[Descent] stop" .. (reason and (" (" .. tostring(reason) .. ")") or ""))

  if type(changeGameState) == "function" and GAMESTATE and GAMESTATE.MAIN_MENU then
    changeGameState(GAMESTATE.MAIN_MENU)
  end
end

function M.is_active()
  return M._active
end

function M.seed()
  return M._seed
end

function M.set_cleanup(fn)
  M._cleanup = fn
end

return M
