-- global variables used by the lua side of the game

globals = globals or {}

globals.weather_event_active = false -- whether a weather event is currently active

globals.timeUntilNextWeatherEvent = 0 -- time until the next weather event occurs, in days
globals.current_weather_event = "snow"-- the current weather event, if any
globals.current_weather_event_base_damage = 1 -- the current damage from the weather event,

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

globals.ownedRelics = {
  {
    id = "basic_umbrella",
    animation_entity = nil -- the animation entity for the relic
  }
}

globals.creature_defs = {
  {
    id = "gold_digger",
    cost = 6,
    gold_produced_each_dig = 1, -- amount of gold produced each time the gold digger digs
    initial_hp = 2, -- initial health points for the gold digger
    spriteID = "3830-TheRoguelike_1_10_alpha_623.png", -- the sprite ID for the gold digger
  },
  {
    id = "healer",
    cost = 3,
    initial_hp = 5, -- initial health points for the healer
    spriteID = "3868-TheRoguelike_1_10_alpha_661.png" -- the sprite ID for the healer
  },
  {
    id = "damage_cushion",
    cost = 2,
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


globals.relicDefs = {
  {
    id = "basic_umbrella",
    localizationKeyName = "ui.basic_umbrella_name",
    localizationKeyDesc = "ui.basic_umbrella_desc",
    spriteID = "4077-TheRoguelike_1_10_alpha_870.png",
    costToBuy = 4
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
