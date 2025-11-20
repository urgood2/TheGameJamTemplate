--------------------------------------------------------------------------------
-- TaskBoard
-- A small, readable, lease-based task manager for Lua-driven agents.
--
-- Core lifecycle:
--   PENDING -> LEASED -> IN_PROGRESS -> DONE|FAILED|CANCELED
--
-- Invariants:
--   - Each task has an idempotency_key to prevent duplicates.
--   - Only one active lease per task (prevents multiple agents doing the same work).
--   - A periodic watchdog requeues expired leases (no dangling work).
--
-- You can:
--   - Filter by capability tags (requires) and optional spatial radius.
--   - Supply your own scoring function to prioritize tasks.
--   - Persist/restore by serializing 'tasks_by_id' (see "How to extend" below).
--------------------------------------------------------------------------------

local TaskBoard = {}
TaskBoard.__index = TaskBoard

--------------------------------------------------------------------------------
-- Internal helpers (intentionally verbose names for readability)
--------------------------------------------------------------------------------
local function current_time_seconds(self) return self._clock() end

local function next_task_id(self)
  self._id_counter = self._id_counter + 1
  return self._id_counter
end

local function ensure_event_bucket(self, event_name)
  local bucket = self._subscribers[event_name]
  if not bucket then bucket = {}; self._subscribers[event_name] = bucket end
  return bucket
end

local function agent_has_required_capabilities(agent_caps, requires)
  if not requires or #requires == 0 then return true end
  if not agent_caps then return false end
  local set = {}
  for _,cap in ipairs(agent_caps) do set[cap] = true end
  for _,need in ipairs(requires) do if not set[need] then return false end end
  return true
end

local function make_lease_token(agent_id, task_id, version)
  -- String token keeps it simple; version is included to strengthen CAS semantics.
  return string.format("%s:%d:%d:%0.6f", tostring(agent_id or "nil"), task_id, version, math.random())
end

--------------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------------
--- Create a new TaskBoard
-- @param opts table|nil { now=function()->sec } inject your own clock (e.g. GetTime)
-- @return board TaskBoard
function TaskBoard.new(opts)
  local self = setmetatable({}, TaskBoard)
  self._clock = (opts and opts.now) or function() return os.clock() end
  self._id_counter = 0

  -- Core indices
  self.tasks_by_id    = {}  -- id -> task table
  self.task_id_by_key = {}  -- idempotency_key -> id

  -- Pending queue is a simple array. Swap for a heap/priority-queue later if needed.
  self.pending_ids = {}

  -- Event subscribers: event_name -> {fn,...}
  self._subscribers = {}

  self.config = {
    default_lease_seconds = 8.0,
    default_renew_seconds = 2.0,  -- for agent heartbeats (advisory)
    max_retry_attempts    = 3,
  }
  return self
end

--------------------------------------------------------------------------------
-- Events (optional)
--------------------------------------------------------------------------------
--- Subscribe to board events (e.g., "task_created", "task_done", "task_expired")
function TaskBoard:on(event_name, callback_fn)
  table.insert(ensure_event_bucket(self, event_name), callback_fn)
end

function TaskBoard:_emit(event_name, payload)
  local listeners = self._subscribers[event_name]
  if not listeners then return end
  for _,fn in ipairs(listeners) do
    -- Wrap in pcall to avoid one bad listener breaking the board.
    local ok, err = pcall(fn, payload)
    if not ok then
      -- You can swap this for your logger
      -- print(("TaskBoard event error (%s): %s"):format(event_name, err))
    end
  end
end

--------------------------------------------------------------------------------
-- Task shape (for reference/documentation)
-- task = {
--   id,                                    -- numeric
--   idempotency_key,                       -- string, unique across active tasks
--   type = "generic",                      -- string
--   payload = {},                          -- free-form table describing the work
--   requires = {"haul","build"},           -- capability tags
--   priority = 0,                          -- higher processed first (tie breaks by score_fn)
--   position = {x=0,y=0}, radius = 0.0,    -- optional spatial matching
--   capacity = 1,                          -- concurrent slots desired; see "slots" extensibility
--   state = "PENDING",                     -- string state
--   version = 1,                           -- increments on every mutation
--   attempts = 0,                          -- retry counter
--   max_attempts = 3,                      -- per-task override of board default
--   lease = { owner, token, expires_at },  -- active lease data (if any)
--   result = nil,                          -- completion result
--   last_error = nil,                      -- captured error string
--   created_at, updated_at,                -- seconds
-- }
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Create / Upsert (deduplicate by idempotency_key)
--------------------------------------------------------------------------------
--- Create a new task (or return existing by idempotency_key).
-- @param def table { idempotency_key (string, required), type, payload, requires, priority,
--                    position={x,y}, radius, capacity, max_attempts }
-- @return task, status string|nil ("deduped" if existing)
function TaskBoard:create(def)
  assert(def and def.idempotency_key, "Task requires unique idempotency_key")
  local existing_id = self.task_id_by_key[def.idempotency_key]
  if existing_id then
    return self.tasks_by_id[existing_id], "deduped"
  end

  local id = next_task_id(self)
  local now = current_time_seconds(self)
  local t = {
    id = id,
    idempotency_key = def.idempotency_key,
    type = def.type or "generic",
    payload = def.payload or {},
    requires = def.requires or {},
    priority = def.priority or 0,
    position = def.position,
    radius = def.radius,
    capacity = def.capacity or 1,
    state = "PENDING",
    version = 1,
    attempts = 0,
    max_attempts = def.max_attempts or self.config.max_retry_attempts,
    created_at = now,
    updated_at = now,
  }

  self.tasks_by_id[id] = t
  self.task_id_by_key[t.idempotency_key] = id
  table.insert(self.pending_ids, id)
  self:_emit("task_created", t)
  return t
end

--------------------------------------------------------------------------------
-- Candidate selection (capability + optional spatial + custom scoring)
--------------------------------------------------------------------------------
--- Find candidate tasks the agent can do, sorted by priority then score_fn.
-- @param opts table {
--   agent_id = any,
--   capabilities = {"haul","build"},
--   max_results = 1,
--   within = {x, y, r},           -- optional spatial filter (requires task position+radius)
--   filter_fn = function(task)->bool (optional),
--   score_fn  = function(task)->number (optional),
-- }
-- @return tasks {task,...}
function TaskBoard:find_candidates(opts)
  local results = {}
  local want_max = opts.max_results or 1
  local score_fn = opts.score_fn or function(_) return 0 end
  local filter_fn = opts.filter_fn

  local cx, cy, cr = nil, nil, nil
  if opts.within then cx,cy,cr = opts.within[1], opts.within[2], opts.within[3] end

  for _,task_id in ipairs(self.pending_ids) do
    local t = self.tasks_by_id[task_id]
    if t and t.state == "PENDING" then
      if agent_has_required_capabilities(opts.capabilities, t.requires) then
        local pass = true
        if filter_fn then pass = filter_fn(t) end
        if pass and cx then
          -- Spatial filter requires task.position
          if t.position and t.radius then
            local dx, dy = t.position.x - cx, t.position.y - cy
            local rr = (cr + (t.radius or 0))
            if (dx*dx + dy*dy) > rr*rr then pass = false end
          else
            pass = false
          end
        end
        if pass then
          t.__score_tmp = score_fn(t) or 0
          table.insert(results, t)
        end
      end
    end
    if #results >= 256 then break end -- cheap cap to avoid huge sorts
  end

  table.sort(results, function(a,b)
    if a.priority ~= b.priority then return a.priority > b.priority end
    return (a.__score_tmp or 0) > (b.__score_tmp or 0)
  end)

  if #results > want_max then
    local out = {}
    for i=1,want_max do out[i] = results[i] end
    return out
  end
  return results
end

--------------------------------------------------------------------------------
-- Leasing / Claiming (prevents duplicates)
--------------------------------------------------------------------------------
--- Atomically claim the top candidate that matches the opts.
-- @return task|nil, token|string|nil
function TaskBoard:request_task(opts)
  local candidate = self:find_candidates{
    agent_id     = opts.agent_id,
    capabilities = opts.capabilities,
    max_results  = 1,
    within       = opts.within,
    filter_fn    = opts.filter_fn,
    score_fn     = opts.score_fn,
  }[1]
  if not candidate then return nil end
  return self:claim_task(candidate.id, { agent_id = opts.agent_id, lease_seconds = opts.lease_seconds })
end

--- Claim a specific task by id (only if PENDING).
-- @return task|nil, token|string|nil or error string
function TaskBoard:claim_task(task_id, opts)
  local t = self.tasks_by_id[task_id]; if not t then return nil, "no_such_task" end
  if t.state ~= "PENDING" then return nil, "not_pending" end

  t.version = t.version + 1
  t.state = "LEASED"
  local lease_seconds = (opts and opts.lease_seconds) or self.config.default_lease_seconds
  local token = make_lease_token(opts and opts.agent_id, t.id, t.version)
  t.lease = { owner = opts and opts.agent_id, token = token, expires_at = current_time_seconds(self) + lease_seconds }
  t.updated_at = current_time_seconds(self)

  self:_emit("task_leased", t)
  return t, token
end

--- Renew a lease before it expires (agent heartbeat).
-- @return boolean ok, string|nil err
function TaskBoard:renew_lease(task_id, token, opts)
  local t = self.tasks_by_id[task_id]; if not t then return false, "no_such_task" end
  if not t.lease or t.lease.token ~= token then return false, "bad_token" end
  local lease_seconds = (opts and opts.lease_seconds) or self.config.default_lease_seconds
  t.lease.expires_at = current_time_seconds(self) + lease_seconds
  t.updated_at = current_time_seconds(self)
  return true
end

--- Transition LEASED -> IN_PROGRESS
function TaskBoard:start_task(task_id, token)
  local t = self.tasks_by_id[task_id]; if not t then return false, "no_such_task" end
  if not t.lease or t.lease.token ~= token then return false, "bad_token" end
  if t.state ~= "LEASED" then return false, "bad_state" end
  t.version = t.version + 1
  t.state = "IN_PROGRESS"
  t.updated_at = current_time_seconds(self)
  self:_emit("task_started", t)
  return true
end

--- Complete task (terminal) -> DONE
function TaskBoard:complete_task(task_id, token, result_payload)
  local t = self.tasks_by_id[task_id]; if not t then return false, "no_such_task" end
  if not t.lease or t.lease.token ~= token then return false, "bad_token" end
  t.version = t.version + 1
  t.state = "DONE"
  t.result = result_payload
  t.updated_at = current_time_seconds(self)
  self.task_id_by_key[t.idempotency_key] = nil
  t.lease = nil
  self:_emit("task_done", t)
  return true
end

--- Fail task; optionally requeue if retryable and attempts remain.
function TaskBoard:fail_task(task_id, token, error_message, retryable)
  local t = self.tasks_by_id[task_id]; if not t then return false, "no_such_task" end
  if not t.lease or t.lease.token ~= token then return false, "bad_token" end

  t.last_error = error_message or "error"
  t.attempts = (t.attempts or 0) + 1
  t.version = t.version + 1
  t.updated_at = current_time_seconds(self)

  if retryable and t.attempts < (t.max_attempts or self.config.max_retry_attempts) then
    t.state = "PENDING"
    t.lease = nil
    table.insert(self.pending_ids, t.id)
    self:_emit("task_requeued", t)
  else
    t.state = "FAILED"
    t.lease = nil
    self.task_id_by_key[t.idempotency_key] = nil
    self:_emit("task_failed", t)
  end
  return true
end

--- Voluntarily release task back to queue (e.g., blocked by precondition).
function TaskBoard:release_task(task_id, token, reason)
  local t = self.tasks_by_id[task_id]; if not t then return false, "no_such_task" end
  if not t.lease or t.lease.token ~= token then return false, "bad_token" end
  t.version = t.version + 1
  t.state = "PENDING"
  t.lease = nil
  t.updated_at = current_time_seconds(self)
  table.insert(self.pending_ids, t.id)
  self:_emit("task_released", { task = t, reason = reason })
  return true
end

--------------------------------------------------------------------------------
-- Watchdog (reclaims expired leases back to PENDING)
--------------------------------------------------------------------------------
--- Requeue any task whose lease has expired. Run this periodically.
-- @return integer number_of_requeued_tasks
function TaskBoard:reap_expired_leases()
  local now = current_time_seconds(self)
  local requeued = 0
  for _,t in pairs(self.tasks_by_id) do
    if (t.state == "LEASED" or t.state == "IN_PROGRESS") and t.lease and t.lease.expires_at <= now then
      t.version = t.version + 1
      t.state = "PENDING"
      t.lease = nil
      t.updated_at = now
      table.insert(self.pending_ids, t.id)
      requeued = requeued + 1
      self:_emit("task_expired", t)
    end
  end
  return requeued
end

--------------------------------------------------------------------------------
-- Introspection / Metrics
--------------------------------------------------------------------------------
--- Quick stats snapshot.
function TaskBoard:stats()
  local s = { pending=0, leased=0, running=0, done=0, failed=0, total=0 }
  for _,t in pairs(self.tasks_by_id) do
    s.total = s.total + 1
    if     t.state == "PENDING"     then s.pending = s.pending + 1
    elseif t.state == "LEASED"      then s.leased  = s.leased  + 1
    elseif t.state == "IN_PROGRESS" then s.running = s.running + 1
    elseif t.state == "DONE"        then s.done    = s.done    + 1
    elseif t.state == "FAILED"      then s.failed  = s.failed  + 1
    end
  end
  return s
end

return TaskBoard
