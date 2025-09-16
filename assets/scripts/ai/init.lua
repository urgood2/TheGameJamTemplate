
ai = ai or {}  -- preserve C++ bindings if they exist

ai.actions = ai.actions or {} -- Actions are named functions that can be executed by entities
ai.goal_selectors = ai.goal_selectors or {} -- Goal selectors are functions that set the goal state dynamically per entity
ai.blackboard_init = ai.blackboard_init or {} -- Blackboard initialization functions for each entity type
ai.entity_types = ai.entity_types or {} -- Entity types are presets for worldstate, e.g. kobold, goblin, etc.
ai.worldstate_updaters = ai.worldstate_updaters or {} -- Worldstate updaters are functions that update worldstate from blackboard/sensory data

local function load_directory(dir, outTable, assignByReturnName)
    local list_fn = ai.list_lua_files
    for _, name in ipairs(list_fn(dir)) do
        local mod = require(dir .. "." .. name)
        if assignByReturnName and mod.name then
            outTable[mod.name] = mod
        else
            outTable[name] = mod
        end
    end
end

load_directory("ai.actions", ai.actions, true)
load_directory("ai.goal_selectors", ai.goal_selectors, false)
load_directory("ai.blackboard_init", ai.blackboard_init, false)
load_directory("ai.entity_types", ai.entity_types, false)
ai.worldstate_updaters = require("ai.worldstate_updaters")


-- ---- Policy & Goals (shared defaults) ----
local selector = require("ai.goal_selector_engine")

ai.policy = ai.policy or {
  band_rank = { COMBAT=4, SURVIVAL=3, WORK=2, IDLE=1 }
}

ai.goals  = ai.goals  or {
  -- WORK: dig whenever worldstate says we can
  DIG_FOR_GOLD = {
    band    = "WORK",
    persist = 0.08, -- hysteresis to avoid immediate bounce back to wander
    desire  = function(e, S)
      return ai.get_worldstate(e, "candigforgold") and 1.0 or 0.0
    end,
    -- No veto: your worldstate_updater already sets candigforgold true/false
    on_apply = function(e)
      -- Target state: make candigforgold false (planner picks action with pre=true, post=false)
      ai.set_goal(e, { candigforgold = false })
    end
  },

  -- IDLE fallback
  WANDER = {
    band    = "IDLE",
    persist = 0.05,
    desire  = function(e, S) return 0.2 end,
    veto    = function(e, S)
      -- Optional guard; keep if your code sometimes latches wander=false
    --   local v = ai.get_worldstate(e, "wander")
    --   return v == false
    end,
    on_apply = function(e)
      ai.patch_worldstate(e, "wander", false) -- clear sticky toggle, optional
      ai.set_goal(e, { wander = true })
    end
  },
}

-- Default per-type selector → uses the generic selector and the shared goals/policy
ai.goal_selectors.Default = function(e)
  -- def is the per-entity deep-copied table your C++ side created
  local def = ai.get_entity_ai_def(e)
  def.policy = def.policy or ai.policy
  def.goals  = def.goals  or ai.goals
  selector.select_and_apply(e)
end
