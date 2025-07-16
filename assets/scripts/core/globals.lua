-- global variables used by the lua side of the game

globals = globals or {}

globals.currency = 5 -- the current amount of currency the player has

globals.gamePaused = false -- whether the game is currently paused

globals.main_menu_elapsed_time = 0 -- time spent in the main menu

globals.isShopOpen = false -- whether the shop is currently open

globals.ownedRelics = {
  {
    id = "basic_umbrella",
    animation_entity = nil -- the animation entity for the relic
  }
}

globals.relicDefs = {
  {
    id = "basic_umbrella",
    localizationKeyName = "ui.basic_umbrella_name",
    localizationKeyDesc = "ui.basic_umbrella_desc",
    spriteID = "4077-TheRoguelike_1_10_alpha_870.png"
  }
}

globals.game_time = {
  seconds = 0, -- seconds since the game started
  minutes = 0, -- minutes since the game started
  hours = 0,   -- hours since the game started
  days = 1    -- days since the game started
}

globals.colonists = globals.colonists or {} -- list of colonists in the game

globals.ui = {
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
