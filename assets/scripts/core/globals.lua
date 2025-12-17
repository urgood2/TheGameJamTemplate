-- global variables used by the lua side of the game

-- Enable STRICT_MODE in debug builds for development warnings
-- Set via environment variable: LUA_STRICT_MODE=1
-- This enables warnings for nil script tables, missing components, etc.
if os.getenv("LUA_STRICT_MODE") == "1" or os.getenv("DEBUG") == "1" then
    _G.STRICT_MODE = true
end

local component_cache = require("core.component_cache")

globals = globals or {}

globals.end_of_day_gold_multiplier = 1.0 -- multiplier for gold at the end of the day

globals.weather_event_active = false -- whether a weather event is currently active

globals.timeUntilNextWeatherEvent = 0 -- time until the next weather event occurs, in days
globals.previous_weather_event = nil -- the previous weather event, if any
globals.current_weather_event = nil -- the current weather event, if any
globals.current_weather_event_base_damage = 1 -- the current damage from the weather event,

globals.currentShopSlots = { 
  { id = "basic_umbrella" },
  { id = "basic_umbrella" },
  { id = "basic_umbrella" } -- and so on. this will be randomized each day.
}

globals.weather_event_defs = {
  {
    id = "acid_rain",
    ui_text = "ui.acid_rain_text", -- the text to display in the UI for this weather event
    base_damage = 2
  },
  {
    id = "snow",
    ui_text = "ui.snow_text", -- the text to display in the UI for this weather eventually
    base_damage = 3
  }
}

globals.structures = globals.structures or {} -- table to hold all structures in the game

globals.structures.colonist_homes = globals.structures.colonist_homes or {} -- table to hold colonist home structures
globals.structures.duplicators = globals.structures.duplicators or {} -- table to hold

globals.tileSize = 64 -- Set the tile size for the game world

globals.defaultColonistMoveSpeed = 10 -- speed at which colonists move, in pixels per second

globals.currency = 30 -- the current amount of currency the player has to beign with, and running total

globals.gamePaused = false -- whether the game is currently paused

globals.main_menu_elapsed_time = 0 -- time spent in the main menu

globals.isShopOpen = false -- whether the shop is currently open

globals.shopUIState = globals.shopUIState or {
  rerollCost = 5,
  rerollCount = 0,
  locked = false
}

globals.shopState = globals.shopState or {
  playerLevel = 1,
  lastInterest = 0,
  instance = nil,
  cards = {}
}

globals.ownedRelics = {
  {
    id = "proto_umbrella"
  }
  -- {
  --   id = "ultimate_mark_of_the_cat_ninja"
  -- },
  -- {
  --   id = "karma_umbrella"
  -- },
  -- {
  --   id = "vampire_teeth"
  -- },
  -- {
  --   id = "gold_lover"
  -- },
  -- {
  --   id = "shoddy_pickaxe"
  -- }
}

globals.creature_defs = {
  {
    id = "gold_digger",
    cost = 6,
    gold_produced_each_dig = 1, -- amount of gold produced each time the gold digger digs
    dig_cooldown_seconds = 10, -- cooldown time in seconds before the gold digger can dig again
    initial_hp = 2, -- initial health points for the gold digger
    spriteID = "3830-TheRoguelike_1_10_alpha_623.png", -- the sprite ID for the gold digger
  },
  {
    id = "healer",
    cost = 3,
    maintenance_cost = 3, -- cost to maintain the healer each day
    heal_cooldown_seconds = 10, -- cooldown time in seconds before the healer can heal again
    heal_amount = 3, -- amount of health restored each time the healer heals
    initial_hp = 5, -- initial health points for the healer
    spriteID = "3868-TheRoguelike_1_10_alpha_661.png" -- the sprite ID for the healer
  },
  {
    id = "damage_cushion",
    cost = 2,
    maintenance_cost = 4, -- cost to maintain the damage cushion each day
    initial_hp = 20, -- initial health points for the damage cushion
    spriteID = "3846-TheRoguelike_1_10_alpha_639.png" -- the sprite ID for the damage cushion
  }
}

globals.structure_defs = {
  {
      id = "colonist_home",
      spriteID = "3490-TheRoguelike_1_10_alpha_283.png", -- the sprite ID for the colonist home
      animation_entity = "colonistHomeButtoAnimationEntity", -- the animation entity for the colonist home
      ui_tooltip_title = "ui.colonist_home_tooltip_title", -- the title for the colonist home tooltip
      ui_tooltip_body = "ui.colonist_home_tooltip_body", -- the body
      text_entity = "colonistHomeTextEntity", -- the text entity for the colonist home, under globals table
      text = "ui.colonist_home_text", -- the text for the colonist home
      cost = 5, -- the cost to buy the colonist home
      currency_per_day = 3
  },
  {
      id = "duplicator",
      spriteID = "3641-TheRoguelike_1_10_alpha_434.png", -- the sprite ID for the duplicator
      ui_tooltip_title = "ui.duplicator_tooltip_title", -- the title for the duplicator tooltip
      ui_tooltip_body = "ui.duplicator_tooltip_body", -- the body for
      animation_entity = "duplicatorButtonAnimationEntity", -- the animation entity for the duplicator
      text_entity = "duplicatorTextEntity", -- the text entity for the duplicator, under globals table
      text = "ui.duplicator_text", -- the text for the duplicator
      cost = 10 -- the cost to buy the duplicator
  }
  
}

    -- global resist acid damage by 1/3/5
    -- global resist cold damage by 1/3/5
    -- grant 10%/20%/30% dodge chance during weather event
    -- on a colonist being damaged, 50% chance to grant 2 hp to a random colonist
    -- on dodge, grant 2 hp to a random colonist
    -- damage taken X2, but all gold doubled at the end of the day
    -- gold diggers dig 2/4/6 more gold each time
    -- healers heal 2/4/6 times as much
    -- damage cushions gain 10/40/70 hp

globals.relicDefs = {
  { -- global damage reduction by 1 (all damage)
    id = "proto_umbrella",
    localizationKeyName = "ui.basic_umbrella_name",
    localizationKeyDesc = "ui.basic_umbrella_desc",
    spriteID = "4077-TheRoguelike_1_10_alpha_870.png",
    costToBuy = 4,
    onBuyCallback = function()
      -- add to ownedRelics
      --TODO: add the relic image to the uibox atop the screen
    end,
    globalDamageReductionCallback = function() -- function to call when the relic is active
      return 1 -- reduce all damage by 1
    end,
    acidDamageReductionCallback = function() -- function to call when the relic is active
      return 1 -- reduce acid damage by 1
    end,
    coldDamageReductionCallback = function() -- function to call when the relic is active
      return 1 -- reduce cold damage by 1
    end,
    dodgeChanceCallback = function() -- function to call when the relic is active
      return 0.1 -- grant 10% dodge chance
    end,
    onDodgeCallback = function() -- function to call when a dodge occurs
    end,
    damageTakenMultiplierCallback = function() -- function to call when the relic is active
      return 1.0 -- no multiplier, normal damage taken
    end,
  },
  --TODO: must do all ui strings from here on, as well as sprites
  -- global resist acid damage by 1/3/5
  {
    id = "basic_acid_umbrella",
    localizationKeyName = "ui.basic_acid_umbrella_name",
    localizationKeyDesc = "ui.basic_acid_umbrella_desc",
    spriteID = "3482-TheRoguelike_1_10_alpha_275.png",
    costToBuy = 4,
    onBuyCallback = function()
      -- add to ownedRelics
      --TODO: add the relic image to the uibox atop the screen
    end,
    globalDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce all damage by 1
    end,
    acidDamageReductionCallback = function() -- function to call when the relic is active
      return 1 -- reduce acid damage by 1
    end,
    coldDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce cold damage by 1
    end,
    dodgeChanceCallback = function() -- function to call when the relic is active
      return 0.0 -- grant 10% dodge chance
    end,
    onDodgeCallback = function() -- function to call when a dodge occurs
    end,
    damageTakenMultiplierCallback = function() -- function to call when the relic is active
      return 1.0 -- no multiplier, normal damage taken
    end,
  },
  -- global resist acid damage by 1/3/5
  {
    id = "middling_acid_umbrella",
    localizationKeyName = "ui.middling_acid_umbrella_name",
    localizationKeyDesc = "ui.middling_acid_umbrella_desc",
    spriteID = "3291-TheRoguelike_1_10_alpha_84.png",
    costToBuy = 7,
    onBuyCallback = function()
      -- add to ownedRelics
      --TODO: add the relic image to the uibox atop the screen
    end,
    globalDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce all damage by 1
    end,
    acidDamageReductionCallback = function() -- function to call when the relic is active
      return 3 -- reduce acid damage by 1
    end,
    coldDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce cold damage by 1
    end,
    dodgeChanceCallback = function() -- function to call when the relic is active
      return 0.0 -- grant 10% dodge chance
    end,
    onDodgeCallback = function() -- function to call when a dodge occurs
    end,
    damageTakenMultiplierCallback = function() -- function to call when the relic is active
      return 1.0 -- no multiplier, normal damage taken
    end,
  },
  {
    id = "advanced_acid_umbrella",
    localizationKeyName = "ui.advanced_acid_umbrella_name",
    localizationKeyDesc = "ui.advanced_acid_umbrella_desc",
    spriteID = "3486-TheRoguelike_1_10_alpha_279.png",
    costToBuy = 10,
    onBuyCallback = function()
      -- add to ownedRelics
      --TODO: add the relic image to the uibox atop the screen
    end,
    globalDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce all damage by 1
    end,
    acidDamageReductionCallback = function() -- function to call when the relic is active
      return 5 -- reduce acid damage by 1
    end,
    coldDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce cold damage by 1
    end,
    dodgeChanceCallback = function() -- function to call when the relic is active
      return 0.0 -- grant 10% dodge chance
    end,
    onDodgeCallback = function() -- function to call when a dodge occurs
    end,
    damageTakenMultiplierCallback = function() -- function to call when the relic is active
      return 1.0 -- no multiplier, normal damage taken
    end,
  },
  -- global resist cold damage by 1/3/5
  {
    id = "basic_radioactive_umbrella",
    localizationKeyName = "ui.basic_radioactive_umbrella_name",
    localizationKeyDesc = "ui.basic_radioactive_umbrella_desc",
    spriteID = "3480-TheRoguelike_1_10_alpha_273.png",
    costToBuy = 4,
    onBuyCallback = function()
      -- add to ownedRelics
      --TODO: add the relic image to the uibox atop the screen
    end,
    globalDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce all damage by 1
    end,
    acidDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce acid damage by 1
    end,
    coldDamageReductionCallback = function() -- function to call when the relic is active
      return 1 -- reduce cold damage by 1
    end,
    dodgeChanceCallback = function() -- function to call when the relic is active
      return 0.0 -- grant 10% dodge chance
    end,
    onDodgeCallback = function() -- function to call when a dodge occurs
    end,
    damageTakenMultiplierCallback = function() -- function to call when the relic is active
      return 1.0 -- no multiplier, normal damage taken
    end,
  },
  {
    id = "middling_radioactive_umbrella",
    localizationKeyName = "ui.middling_radioactive_umbrella_name",
    localizationKeyDesc = "ui.middling_radioactive_umbrella_desc",
    spriteID = "3483-TheRoguelike_1_10_alpha_276.png",
    costToBuy = 7,
    onBuyCallback = function()
      -- add to ownedRelics
      --TODO: add the relic image to the uibox atop the screen
    end,
    globalDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce all damage by 1
    end,
    acidDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce acid damage by 1
    end,
    coldDamageReductionCallback = function() -- function to call when the relic is active
      return 3 -- reduce cold damage by 1
    end,
    dodgeChanceCallback = function() -- function to call when the relic is active
      return 0.0 -- grant 10% dodge chance
    end,
    onDodgeCallback = function() -- function to call when a dodge occurs
    end,
    damageTakenMultiplierCallback = function() -- function to call when the relic is active
      return 1.0 -- no multiplier, normal damage taken
    end,
  },
  {
    id = "advanced_radioactive_umbrella",
    localizationKeyName = "ui.advanced_radioactive_umbrella_name",
    localizationKeyDesc = "ui.advanced_radioactive_umbrella_desc",
    spriteID = "3485-TheRoguelike_1_10_alpha_278.png",
    costToBuy = 10,
    onBuyCallback = function()
      -- add to ownedRelics
      --TODO: add the relic image to the uibox atop the screen
    end,
    globalDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce all damage by 1
    end,
    acidDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce acid damage by 1
    end,
    coldDamageReductionCallback = function() -- function to call when the relic is active
      return 5 -- reduce cold damage by 1
    end,
    dodgeChanceCallback = function() -- function to call when the relic is active
      return 0.0 -- grant 10% dodge chance
    end,
    onDodgeCallback = function() -- function to call when a dodge occurs
    end,
    damageTakenMultiplierCallback = function() -- function to call when the relic is active
      return 1.0 -- no multiplier, normal damage taken
    end,
  },
  {
    id = "cat_whiskers",
    localizationKeyName = "ui.cat_whiskers_name",
    localizationKeyDesc = "ui.cat_whiskers_desc",
    spriteID = "3346-TheRoguelike_1_10_alpha_139.png",
    costToBuy = 5,
    onBuyCallback = function()
      -- add to ownedRelics
      --TODO: add the relic image to the uibox atop the screen
    end,
    globalDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce all damage by 1
    end,
    acidDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce acid damage by 1
    end,
    coldDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce cold damage by 1
    end,
    dodgeChanceCallback = function() -- function to call when the relic is active
      return 0.1 -- grant 10% dodge chance
    end,
    onDodgeCallback = function() -- function to call when a dodge occurs
    end,
    damageTakenMultiplierCallback = function() -- function to call when the relic is active
      return 1.0 -- no multiplier, normal damage taken
    end,
  },
  {
    id = "cat_ninja_paw_holders",
    localizationKeyName = "ui.cat_ninja_paw_holders_name",
    localizationKeyDesc = "ui.cat_ninja_paw_holders_desc",
    spriteID = "3805-TheRoguelike_1_10_alpha_598.png",
    costToBuy = 8,
    onBuyCallback = function()
      -- add to ownedRelics
      --TODO: add the relic image to the uibox atop the screen
    end,
    globalDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce all damage by 1
    end,
    acidDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce acid damage by 1
    end,
    coldDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce cold damage by 1
    end,
    dodgeChanceCallback = function() -- function to call when the relic is active
      return 0.3 -- grant 10% dodge chance
    end,
    onDodgeCallback = function() -- function to call when a dodge occurs
    end,
    damageTakenMultiplierCallback = function() -- function to call when the relic is active
      return 1.0 -- no multiplier, normal damage taken
    end,
  },
  {
    id = "ultimate_mark_of_the_cat_ninja",
    localizationKeyName = "ui.ultimate_mark_of_the_cat_ninja_name",
    localizationKeyDesc = "ui.ultimate_mark_of_the_cat_ninja_desc",
    spriteID = "3858-TheRoguelike_1_10_alpha_651.png",
    costToBuy = 10,
    onBuyCallback = function()
      -- add to ownedRelics
      --TODO: add the relic image to the uibox atop the screen
    end,
    globalDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce all damage by 1
    end,
    acidDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce acid damage by 1
    end,
    coldDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce cold damage by 1
    end,
    dodgeChanceCallback = function() -- function to call when the relic is active
      return 0.5 -- grant 10% dodge chance
    end,
    onDodgeCallback = function() -- function to call when a dodge occurs
    end,
    damageTakenMultiplierCallback = function() -- function to call when the relic is active
      return 1.0 -- no multiplier, normal damage taken
    end,
  },
  { -- heal by 3 on dodge
    id = "karma_umbrella",
    localizationKeyName = "ui.karma_umbrella_name",
    localizationKeyDesc = "ui.karma_umbrella_desc",
    spriteID = "3933-TheRoguelike_1_10_alpha_726.png",
    costToBuy = 8,
    onBuyCallback = function()
      -- add to ownedRelics
      --TODO: add the relic image to the uibox atop the screen
    end,
    globalDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce all damage by 1
    end,
    acidDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce acid damage by 1
    end,
    coldDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce cold damage by 1
    end,
    dodgeChanceCallback = function() -- function to call when the relic is active
      return 0.0 -- grant 10% dodge chance
    end,
    onDodgeCallback = function() -- function to call when a dodge occurs
      local allColonists = {}
      lume.extend(allColonists, globals.colonists) -- get all colonists in the game
      lume.extend(allColonists, globals.healers) -- add healers to the list
      lume.extend(allColonists, globals.gold_diggers) -- add gold diggers to the
      lume.extend(allColonists, globals.damage_cushions) -- add damage cushions to the list
      
      if #allColonists > 0 then
        local randomColonist = allColonists[lume.random(1, #allColonists)] -- get a random colonist
        
        local healAmount = 3 -- amount to heal


        setBlackboardFloat(randomColonist, "health", math.min(getBlackboardFloat(randomColonist, "health") + healAmount, getBlackboardFloat(randomColonist, "max_health"))) -- heal the random colonist

        local transform = component_cache.get(randomColonist, Transform)
        
        newTextPopup(
          "+ "..healAmount,
          transform.visualX + transform.visualW / 2,
          transform.visualY + transform.visualH / 2,
          3.0, -- duration
          "color=pastel_pink" -- effect
      )
      end
    end,
    damageTakenMultiplierCallback = function() -- function to call when the relic is active
      return 1.0 -- no multiplier, normal damage taken
    end,
  },
  { -- heal by 10% of damage taken with 50% chance
    id = "vampire_teeth",
    localizationKeyName = "ui.vampire_teeth_name",
    localizationKeyDesc = "ui.vampire_teeth_desc",
    spriteID = "3777-TheRoguelike_1_10_alpha_570.png",
    costToBuy = 10,
    onBuyCallback = function()
      -- add to ownedRelics
      --TODO: add the relic image to the uibox atop the screen
    end,
    globalDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce all damage by 1
    end,
    acidDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce acid damage by 1
    end,
    coldDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce cold damage by 1
    end,
    dodgeChanceCallback = function() -- function to call when the relic is active
      return 0.0 -- grant 10% dodge chance
    end,
    onDodgeCallback = function() -- function to call when a dodge occurs
    end,
    damageTakenMultiplierCallback = function() -- function to call when the relic is active
      return 1.0 -- no multiplier, normal damage taken
    end,
    onHitCallback = function(entity, damage) -- function to call when the entity is hit
      if (lume.random() < 0.5) then -- 50% chance to heal
        local healAmount = math.floor(damage * 0.1) -- heal by 10% of damage taken


        setBlackboardFloat(entity, "health", math.min(getBlackboardFloat(entity, "health") + healAmount, getBlackboardFloat(entity, "max_health"))) -- heal the entity

        local transform = component_cache.get(entity, Transform)
        
        newTextPopup(
          "+ "..healAmount,
          transform.visualX + transform.visualW / 2,
          transform.visualY + transform.visualH / 2,
          3.0, -- duration
          "color=pastel_pink" -- effect
        )
      end
    end,
  },
  { -- heal by 10% of damage taken with 50% chance
    id = "gold_lover",
    localizationKeyName = "ui.gold_lover_name",
    localizationKeyDesc = "ui.gold_lover_desc",
    spriteID = "4014-TheRoguelike_1_10_alpha_807.png",
    costToBuy = 10,
    onBuyCallback = function()
      -- add to ownedRelics
      --TODO: add the relic image to the uibox atop the screen
      
      globals.end_of_day_gold_multiplier = globals.end_of_day_gold_multiplier * 2.0 -- double the gold at the end of the day
    end,
    globalDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce all damage by 1
    end,
    acidDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce acid damage by 1
    end,
    coldDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce cold damage by 1
    end,
    dodgeChanceCallback = function() -- function to call when the relic is active
      return 0.0 -- grant 10% dodge chance
    end,
    onDodgeCallback = function() -- function to call when a dodge occurs
    end,
    damageTakenMultiplierCallback = function() -- function to call when the relic is active
      return 1.0 -- no multiplier, normal damage taken
    end,
    onHitCallback = function(entity, damage) -- function to call when the entity is hit
    end,
  },
  { -- gold diggers dig more gold each time 1/2/4
    id = "shoddy_pickaxe",
    localizationKeyName = "ui.shoddy_pickaxe_name",
    localizationKeyDesc = "ui.shoddy_pickaxe_desc",
    spriteID = "4044-TheRoguelike_1_10_alpha_837.png",
    costToBuy = 4,
    onBuyCallback = function()
      -- add to ownedRelics
      --TODO: add the relic image to the uibox atop the screen
      
      findInTable(globals.creature_defs, "id", "gold_digger").gold_produced_each_dig = findInTable(globals.creature_defs, "id", "gold_digger").gold_produced_each_dig + 1 -- increase gold produced by gold diggers by 2
    end,
    globalDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce all damage by 1
    end,
    acidDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce acid damage by 1
    end,
    coldDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce cold damage by 1
    end,
    dodgeChanceCallback = function() -- function to call when the relic is active
      return 0.0 -- grant 10% dodge chance
    end,
    onDodgeCallback = function() -- function to call when a dodge occurs
    end,
    damageTakenMultiplierCallback = function() -- function to call when the relic is active
      return 1.0 -- no multiplier, normal damage taken
    end,
    onHitCallback = function(entity, damage) -- function to call when the entity is hit
    end,
  },
  { -- gold diggers dig more gold each time 1/2/4
    id = "useful_pickaxe",
    localizationKeyName = "ui.useful_pickaxe_name",
    localizationKeyDesc = "ui.useful_pickaxe_desc",
    spriteID = "3679-TheRoguelike_1_10_alpha_472.png",
    costToBuy = 8,
    onBuyCallback = function()
      -- add to ownedRelics
      --TODO: add the relic image to the uibox atop the screen
      
      findInTable(globals.creature_defs, "id", "gold_digger").gold_produced_each_dig = findInTable(globals.creature_defs, "id", "gold_digger").gold_produced_each_dig + 2 -- increase gold produced by gold diggers by 2
    end,
    globalDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce all damage by 1
    end,
    acidDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce acid damage by 1
    end,
    coldDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce cold damage by 1
    end,
    dodgeChanceCallback = function() -- function to call when the relic is active
      return 0.0 -- grant 10% dodge chance
    end,
    onDodgeCallback = function() -- function to call when a dodge occurs
    end,
    damageTakenMultiplierCallback = function() -- function to call when the relic is active
      return 1.0 -- no multiplier, normal damage taken
    end,
    onHitCallback = function(entity, damage) -- function to call when the entity is hit
    end,
  },
  { -- gold diggers dig more gold each time 1/2/4
    id = "golden_pickaxe",
    localizationKeyName = "ui.golden_pickaxe_name",
    localizationKeyDesc = "ui.golden_pickaxe_desc",
    spriteID = "4076-TheRoguelike_1_10_alpha_869.png",
    costToBuy = 10,
    onBuyCallback = function()
      -- add to ownedRelics
      --TODO: add the relic image to the uibox atop the screen
      
      findInTable(globals.creature_defs, "id", "gold_digger").gold_produced_each_dig = findInTable(globals.creature_defs, "id", "gold_digger").gold_produced_each_dig + 4 -- increase gold produced by gold diggers by 2
    end,
    globalDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce all damage by 1
    end,
    acidDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce acid damage by 1
    end,
    coldDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce cold damage by 1
    end,
    dodgeChanceCallback = function() -- function to call when the relic is active
      return 0.0 -- grant 10% dodge chance
    end,
    onDodgeCallback = function() -- function to call when a dodge occurs
    end,
    damageTakenMultiplierCallback = function() -- function to call when the relic is active
      return 1.0 -- no multiplier, normal damage taken
    end,
    onHitCallback = function(entity, damage) -- function to call when the entity is hit
    end,
  },
  { -- healers heal more each time 3/6/9
    id = "plastic_syringe",
    localizationKeyName = "ui.plastic_syringe_name",
    localizationKeyDesc = "ui.plastic_syringe_desc",
    spriteID = "4001-TheRoguelike_1_10_alpha_794.png",
    costToBuy = 5,
    onBuyCallback = function()
      -- add to ownedRelics
      --TODO: add the relic image to the uibox atop the screen
      
      findInTable(globals.creature_defs, "id", "healer").heal_amount = findInTable(globals.creature_defs, "id", "healer").heal_amount + 3 -- increase heal amount by 1
    end,
    globalDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce all damage by 1
    end,
    acidDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce acid damage by 1
    end,
    coldDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce cold damage by 1
    end,
    dodgeChanceCallback = function() -- function to call when the relic is active
      return 0.0 -- grant 10% dodge chance
    end,
    onDodgeCallback = function() -- function to call when a dodge occurs
    end,
    damageTakenMultiplierCallback = function() -- function to call when the relic is active
      return 1.0 -- no multiplier, normal damage taken
    end,
    onHitCallback = function(entity, damage) -- function to call when the entity is hit
    end,
  },
  { -- healers heal more each time 3/6/9
    id = "better_syringe",
    localizationKeyName = "ui.better_syringe_name",
    localizationKeyDesc = "ui.better_syringe_desc",
    spriteID = "4006-TheRoguelike_1_10_alpha_799.png",
    costToBuy = 8,
    onBuyCallback = function()
      -- add to ownedRelics
      --TODO: add the relic image to the uibox atop the screen
      
      findInTable(globals.creature_defs, "id", "healer").heal_amount = findInTable(globals.creature_defs, "id", "healer").heal_amount + 6 -- increase heal amount by 1
    end,
    globalDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce all damage by 1
    end,
    acidDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce acid damage by 1
    end,
    coldDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce cold damage by 1
    end,
    dodgeChanceCallback = function() -- function to call when the relic is active
      return 0.0 -- grant 10% dodge chance
    end,
    onDodgeCallback = function() -- function to call when a dodge occurs
    end,
    damageTakenMultiplierCallback = function() -- function to call when the relic is active
      return 1.0 -- no multiplier, normal damage taken
    end,
    onHitCallback = function(entity, damage) -- function to call when the entity is hit
    end,
  },
  { -- healers heal more each time 3/6/9
    id = "plutonium_syringe",
    localizationKeyName = "ui.plutonium_syringe_name",
    localizationKeyDesc = "ui.plutonium_syringe_desc",
    spriteID = "4010-TheRoguelike_1_10_alpha_803.png",
    costToBuy = 10,
    onBuyCallback = function()
      -- add to ownedRelics
      --TODO: add the relic image to the uibox atop the screen
      
      findInTable(globals.creature_defs, "id", "healer").heal_amount = findInTable(globals.creature_defs, "id", "healer").heal_amount + 9 -- increase heal amount by 1
    end,
    globalDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce all damage by 1
    end,
    acidDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce acid damage by 1
    end,
    coldDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce cold damage by 1
    end,
    dodgeChanceCallback = function() -- function to call when the relic is active
      return 0.0 -- grant 10% dodge chance
    end,
    onDodgeCallback = function() -- function to call when a dodge occurs
    end,
    damageTakenMultiplierCallback = function() -- function to call when the relic is active
      return 1.0 -- no multiplier, normal damage taken
    end,
    onHitCallback = function(entity, damage) -- function to call when the entity is hit
    end,
  },
  { -- new damage_cushions get more hp when bought 10/15/30
    id = "safety_umbrella",
    localizationKeyName = "ui.safety_umbrella_name",
    localizationKeyDesc = "ui.safety_umbrella_desc",
    spriteID = "4115-TheRoguelike_1_10_alpha_908.png",
    costToBuy = 7,
    onBuyCallback = function()
      -- add to ownedRelics
      --TODO: add the relic image to the uibox atop the screen
      
      findInTable(globals.creature_defs, "id", "damage_cushion").initial_hp = findInTable(globals.creature_defs, "id", "damage_cushion").initial_hp + 10 -- increase max health by 10
    end,
    globalDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce all damage by 1
    end,
    acidDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce acid damage by 1
    end,
    coldDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce cold damage by 1
    end,
    dodgeChanceCallback = function() -- function to call when the relic is active
      return 0.0 -- grant 10% dodge chance
    end,
    onDodgeCallback = function() -- function to call when a dodge occurs
    end,
    damageTakenMultiplierCallback = function() -- function to call when the relic is active
      return 1.0 -- no multiplier, normal damage taken
    end,
    onHitCallback = function(entity, damage) -- function to call when the entity is hit
    end,
  },
  { -- new damage_cushions get more hp when bought 10/15/30
    id = "steel_umbrella",
    localizationKeyName = "ui.steel_umbrella_name",
    localizationKeyDesc = "ui.steel_umbrella_desc",
    spriteID = "4129-TheRoguelike_1_10_alpha_922.png",
    costToBuy = 10,
    onBuyCallback = function()
      -- add to ownedRelics
      --TODO: add the relic image to the uibox atop the screen
      
      findInTable(globals.creature_defs, "id", "damage_cushion").initial_hp = findInTable(globals.creature_defs, "id", "damage_cushion").initial_hp + 15 -- increase max health by 10
    end,
    globalDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce all damage by 1
    end,
    acidDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce acid damage by 1
    end,
    coldDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce cold damage by 1
    end,
    dodgeChanceCallback = function() -- function to call when the relic is active
      return 0.0 -- grant 10% dodge chance
    end,
    onDodgeCallback = function() -- function to call when a dodge occurs
    end,
    damageTakenMultiplierCallback = function() -- function to call when the relic is active
      return 1.0 -- no multiplier, normal damage taken
    end,
    onHitCallback = function(entity, damage) -- function to call when the entity is hit
    end,
  },
  { -- new damage_cushions get more hp when bought 10/15/30
    id = "cushionista",
    localizationKeyName = "ui.cushionista_name",
    localizationKeyDesc = "ui.cushionista_desc",
    spriteID = "3982-TheRoguelike_1_10_alpha_775.png",
    costToBuy = 13,
    onBuyCallback = function()
      -- add to ownedRelics
      --TODO: add the relic image to the uibox atop the screen
      
      findInTable(globals.creature_defs, "id", "damage_cushion").initial_hp = findInTable(globals.creature_defs, "id", "damage_cushion").initial_hp + 30 -- increase max health by 10
    end,
    globalDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce all damage by 1
    end,
    acidDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce acid damage by 1
    end,
    coldDamageReductionCallback = function() -- function to call when the relic is active
      return 0 -- reduce cold damage by 1
    end,
    dodgeChanceCallback = function() -- function to call when the relic is active
      return 0.0 -- grant 10% dodge chance
    end,
    onDodgeCallback = function() -- function to call when a dodge occurs
    end,
    damageTakenMultiplierCallback = function() -- function to call when the relic is active
      return 1.0 -- no multiplier, normal damage taken
    end,
    onHitCallback = function(entity, damage) -- function to call when the entity is hit
    end,
  }
}

globals.game_time = {
  seconds = 0, -- seconds since the game started
  minutes = 0, -- minutes since the game started
  hours = 0,   -- hours since the game started
  days = 1    -- days since the game started
}

globals.gold_diggers = {}
globals.healers = {} -- list of healers in the game
globals.damage_cushions = {} -- list of damage cushions in the game
globals.colonists = globals.colonists or {} -- list of colonists in the game

globals.ui = {
  
  colonist_ui = {
    -- array with id: entity, hp_ui_text: entity, hp_ui_box: entity
  },
  
  timeTextUIBox = nil, -- the UI box that contains the time text
  timeTextEntity = nil, -- the text entity that displays the time
  
  dayTextEntity = nil, -- the text entity that displays the day
  dayTextUIBox = nil, -- the UI box that contains the day text
  
  newDayUIBox = nil -- the UI box that displays the new day message
}

-- your defaults in one place
local defaults = {

  timeUntilNextGravityWave = 0,
  gravityWaveSeconds       = 70, -- gravity wave will happen every 70 seconds
  currencyIconForText      = {},



  krill_list                     = {}, -- list of krill that are active in the current game

  ui                             = {
    prestige_uibox = nil,
    prestige_window_open = false,
    
    helpTextUIBox = nil,
    help_window_open = false,
    
    newAchievementUIBox = nil,
    achievementIconEntity = nil,
    achievementTitleTextEntity = nil,
    achievementBodyTextEntity = nil,

    --TODO: change the global tooltip text with settext, then call renewAlignment on the uibox.
    tooltipUIBox = nil,
    tooltipTitleText = nil,
    tooltipBodyText = nil,


  },

  -- keyed by upgrade table name
  upgrade_selector_text_entities = {
    building_upgrade_defs = nil,
    converter_defs = nil
  },

  -- indices to keep track of for combo boxes



  prestige_upgrade_defs = {
    moreWhale = 0,
    moreKrill = 0,       -- just start with more at the beginning
    dustMultiplier = 1.0 -- multiplier for dust collected
  }
}

-- merge‐in any missing keys
for k, v in pairs(defaults) do
  if globals[k] == nil then
    globals[k] = v
  end
end

-- ============================================================================
-- ENTITY TYPE HELPERS (stubs - can be overridden by gameplay.lua)
-- ============================================================================

--- Checks if an entity is an enemy. Default stub returns false.
--- Override in gameplay.lua with actual faction/enemy detection.
--- @param eid number Entity ID to check
--- @return boolean True if entity is an enemy
function globals.isEnemyEntity(eid)
    return false
end
