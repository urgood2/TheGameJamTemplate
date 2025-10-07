local TaskBoard = require("taskboard")
local board = TaskBoard.new({ now = function() return GetTime() end }) -- inject your engine clock if you want

-- 1) Create tasks (deduped by idempotency_key)
board:create{
  idempotency_key = "haul:log#A->stockpile",
  type = "haul",
  payload = { item_id = "logA", from = {x=10,y=5}, to = {x=30,y=5} },
  requires = {"haul"},
  priority = 5,
  position = {x=10, y=5}, radius = 2.0,
}

board:create{
  idempotency_key = "build:wall@12,9",
  type = "build",
  payload = { blueprint = "wall", at = {x=12,y=9} },
  requires = {"build"},
  priority = 10,
  position = {x=12, y=9}, radius = 1.5,
}

-- 2) Agent loop (pull -> start -> work -> complete/release/fail)
local agent = { id=101, capabilities={"haul","build"}, position={x=11,y=7}, seek_radius=20, active=nil }

-- Ask for work
local task, token = board:request_task{
  agent_id     = agent.id,
  capabilities = agent.capabilities,
  within       = {agent.position.x, agent.position.y, agent.seek_radius},
  score_fn     = function(t)
    -- prioritize closer & higher priority
    local s = t.priority
    if t.position then
      local dx = t.position.x - agent.position.x
      local dy = t.position.y - agent.position.y
      s = s - 0.02 * (dx*dx + dy*dy)
    end
    return s
  end,
  lease_seconds = 6.0,
}

if task then
  local ok = board:start_task(task.id, token)
  if ok then
    agent.active = { task_id = task.id, token = token }
  end
end

-- In your update loop:
--   - Renew lease while working
--   - Complete when finished
if agent.active then
  board:renew_lease(agent.active.task_id, agent.active.token)
  -- ... do movement/animation/logic ...
  local finished = true -- pretend we’re done
  if finished then
    board:complete_task(agent.active.task_id, agent.active.token, {note="success"})
    agent.active = nil
  end
end

-- Periodic watchdog (e.g., once per second)
local reclaimed = board:reap_expired_leases()
