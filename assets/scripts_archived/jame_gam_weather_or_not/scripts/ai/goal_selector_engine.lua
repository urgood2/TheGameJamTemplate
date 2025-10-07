-- scripts/ai/selector.lua
-- Minimal goal selector: desire + hysteresis (persist) + band arbitration
-- Uses your global blackboard helpers (getBlackboard*/setBlackboard*).

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

function M.select_and_apply(e)
  -- Pull this entity's ai-def (deep-copied table your C++ stored)
  local def = ai.get_entity_ai_def(e)
  if not def then return end

  local goals  = def.goals
  local policy = def.policy
  if not goals or not policy then return end

  local now = os.clock()
  local band_rank = policy.band_rank or { COMBAT=4, SURVIVAL=3, WORK=2, IDLE=1 }

  -- Current goal for hysteresis stickiness
  local current = getBlackboardString(e, "current_goal")
  dbg("Entity %s current_goal=%s", tostring(e), tostring(current))

  -- Build candidates
  local cand = {}
  for id, G in pairs(goals) do
    local desire = 0.0
    if G.desire then
      desire = G.desire(e, { time = now }) or 0.0
    end
    if desire > 0.0 then
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

  -- Apply only if goal changed
  if current ~= best.id then
    dbg("Switching goal: %s -> %s", tostring(current), best.id)
    setBlackboardString(e, "current_goal", best.id)
    local G = goals[best.id]
    if G and G.on_apply then
      dbg("Applying goal handler for %s", best.id)
      G.on_apply(e)
    end
  else
    dbg("Goal unchanged: %s", tostring(current))
  end
end

return M
