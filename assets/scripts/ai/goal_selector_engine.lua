-- scripts/ai/selector.lua
-- Minimal goal selector: desire + hysteresis (persist) + band arbitration
-- Uses ai.get_blackboard(e) to access the Blackboard usertype methods.

local M = {}

-- Toggle this to enable/disable selector logs globally
M.DEBUG = true

-- Wrapper: only prints if M.DEBUG is true
local function dbg(fmt, ...)
  if M.DEBUG then
    print(("[AI/Selector] " .. fmt):format(...))
  end
end

local function clamp01(x) return (x < 0 and 0) or (x > 1 and 1) or x end

local function is_goal_locked(e, goal_id)
  local locked_until = ai.bb.get(e, "goal.locked_until", 0)
  return GetTime() < locked_until
end

local function is_goal_on_cooldown(e, goal_id)
  local cd_key = "goal.cooldown." .. goal_id
  local cd_until = ai.bb.get(e, cd_key, 0)
  return GetTime() < cd_until
end

local function apply_goal_lock(e, goal)
  if goal.lock then
    ai.bb.set(e, "goal.locked_until", GetTime() + goal.lock)
  end
end

local function apply_goal_cooldown(e, old_goal_id, goals)
  if not old_goal_id then return end
  local goal = goals[old_goal_id]
  if goal and goal.cooldown then
    local cd_key = "goal.cooldown." .. old_goal_id
    ai.bb.set(e, cd_key, GetTime() + goal.cooldown)
  end
end

function M.select_and_apply(e)
  -- Pull this entity's ai-def (deep-copied table your C++ stored)
  local def = ai.get_entity_ai_def(e)
  if not def then return end

  local goals  = def.goals
  local policy = def.policy
  if not goals or not policy then return end

  local now = GetTime()
  local band_rank = policy.band_rank or { COMBAT=4, SURVIVAL=3, WORK=2, IDLE=1 }

  -- Current goal for hysteresis stickiness
  local current = ai.bb.get(e, "current_goal", nil)
  dbg("Entity %s current_goal=%s", tostring(e), tostring(current))

  -- Build candidates
  local cand = {}
  for id, G in pairs(goals) do
    local desire = 0.0
    if G.desire then
      desire = G.desire(e, { time = now }) or 0.0
    end
    if desire > 0.0 and not is_goal_on_cooldown(e, id) then
      local veto = (G.veto and G.veto(e, { time = now })) or false
      if not veto then
        local hyst = (current == id) and (G.persist or 0.0) or 0.0
        local pre  = clamp01(desire + hyst)
        if pre > 0.0 then
          table.insert(cand, { id = id, band = (G.band or "IDLE"), pre = pre })
          dbg("Candidate: %s desire=%.2f hyst=%.2f pre=%.2f band=%s",
            id, desire, hyst, pre, G.band or "IDLE")
        else
          dbg("Rejected %s (pre=%.2f <= 0)", id, pre)
        end
      else
        dbg("Vetoed %s", id)
      end
    else
      dbg("No desire for %s (%.2f)", id, desire)
    end
  end

  if #cand == 0 then
    dbg("No candidates for entity %s", tostring(e))
    return
  end

  -- Sort by pre-score
  table.sort(cand, function(a,b) return a.pre > b.pre end)

  -- Band arbitration: allow higher-tier band to override if it has decent score
  local best = cand[1]
  for i = 2, #cand do
    local c   = cand[i]
    local rb  = band_rank[c.band] or 0
    local rB  = band_rank[best.band] or 0
    if rb > rB and c.pre >= 0.4 then
      dbg("Band arbitration: %s (band=%s, pre=%.2f) overrides %s (band=%s, pre=%.2f)",
        c.id, c.band, c.pre, best.id, best.band, best.pre)
      best = c
    end
  end

  dbg("Best goal=%s (band=%s, pre=%.2f)", best.id, best.band, best.pre)

  -- Phase 1.2: Report goal selection to trace buffer for debugging
  -- Convert pre-score to integer percentage (0-100)
  local score = math.floor((best.pre or 0) * 100)
  ai.report_goal_selection(e, best.id, best.band, score, cand)

  -- Apply only if goal changed
  if current ~= best.id then
    if current and is_goal_locked(e, current) then
      dbg("Goal locked: %s", tostring(current))
      return
    end
    dbg("Switching goal: %s -> %s", tostring(current), best.id)
    apply_goal_cooldown(e, current, goals)
    ai.bb.set(e, "current_goal", best.id)
    local G = goals[best.id]
    if G and G.on_apply then
      dbg("Applying goal handler for %s", best.id)
      G.on_apply(e)
      apply_goal_lock(e, G)
    end
  else
    dbg("Goal unchanged: %s", tostring(current))
  end
end

return M
