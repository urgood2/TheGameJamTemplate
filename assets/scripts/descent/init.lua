local M = {
  _active = false,
  _seed = nil,
  _cleanup = nil,
}

local function log_info(message)
  if type(log_debug) == "function" then
    log_debug(message)
  else
    print(message)
  end
end

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

function M.start(opts)
  if M._active then
    return
  end

  M._active = true
  M._seed = resolve_seed(opts)

  local seed_info = (M._seed ~= nil) and tostring(M._seed) or "(none)"
  log_info("[Descent] start (seed=" .. seed_info .. ")")

  -- Placeholder for future Descent setup. Keep require-safe (no timers at require-time).
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
