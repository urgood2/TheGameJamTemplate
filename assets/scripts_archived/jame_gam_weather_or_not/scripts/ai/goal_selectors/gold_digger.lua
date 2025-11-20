-- scripts/ai/goal_selectors/gold_digger.lua
-- Per-type hook: you can customize policy/goals here before selecting.
local selector = require("ai.goal_selector_engine")

return function(e)
  local def = ai.get_entity_ai_def(e)

  -- Use shared policy/goals by default
  def.policy = def.policy or ai.policy
  def.goals  = def.goals  or ai.goals

  -- (Optional) Per-type tweaks:
  -- def.policy.band_rank = { COMBAT=4, SURVIVAL=3, WORK=3, IDLE=1 }
  -- def.goals.DIG_FOR_GOLD.persist = 0.10
  
  log_debug("Gold Digger Goal Selector for entity " .. tostring(e))

  selector.select_and_apply(e)
end