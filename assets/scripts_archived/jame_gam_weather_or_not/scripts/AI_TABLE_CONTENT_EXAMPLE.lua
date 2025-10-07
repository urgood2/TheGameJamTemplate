local ai = {
  entity_types = {
    kobold = {
      initial = {
        has_food    = true,
        enemyvisible = false,
        hungry      = true,
      },
      goal = {
        hungry = false,
      },
    },
  },

  actions = {
    eat = {
      name   = "eat",
      cost   = 1,
      pre    = {
        hungry = true,
      },
      post   = {
        hungry = false,
      },
      start  = function(entity) 
        -- …your eat.lua start handler…
      end,
      update = function(self, entity, dt)
        -- …your eat.lua update handler…
      end,
      finish = function(entity)
        -- …your eat.lua finish handler…
      end,
    },
  },

  blackboard_init = {
    kobold = function(entity)
      -- …your kobold.lua blackboard init…
    end,
  },

  goal_selectors = {
    kobold = function(entity)
      -- …your kobold.lua goal selector…
    end,
  },

  worldstate_updaters = {
    enemy_sight  = function(entity, dt)
      -- …your worldstate_updaters.lua enemy_sight…
    end,
    hunger_check = function(entity, dt)
      -- …your worldstate_updaters.lua hunger_check…
    end,
  },
}


-- This is an example of what the AI table might look like in a goap entity

-- ["actions"] = {
--   ["eat"] = {
--     ["pre"] = {
--       ["hungry"] = true
--     }
--     ["name"] = eat
--     ["post"] = {
--       ["hungry"] = false
--     }
--     ["finish"] = function: 000000000aef7e80
--     ["cost"] = 1
--     ["update"] = function: 000000000aef7e20
--     ["start"] = function: 000000000aef7dc0
--   }
-- }
-- ["force_interrupt"] = function: 000000000ae9e9d0
-- ["worldstate_updaters"] = {
--   ["enemy_sight"] = function: 000000000af0b9c0
--   ["hunger_check"] = function: 000000000af05010
-- }
-- ["patch_worldstate"] = function: 000000000ae916b0
-- ["list_lua_files"] = function: 000000000ae9eaa0
-- ["get_blackboard"] = function: 000000000ae98ee0
-- ["set_worldstate"] = function: 000000000ae91510
-- ["patch_goal"] = function: 000000000ae91810
-- ["set_goal"] = function: 000000000ae91580
-- ["goal_selectors"] = {
--   ["kobold"] = function: 000000000aef81e0
-- }
-- ["entity_types"] = {
--   ["kobold"] = {
--     ["initial"] = {
--       ["hungry"] = true
--       ["enemyvisible"] = false
--       ["has_food"] = true
--     }
--     ["goal"] = {
--       ["hungry"] = false
--     }
--   }
-- }
-- ["blackboard_init"] = {
--   ["kobold"] = function: 000000000af04650
-- }