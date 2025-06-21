-- global variables used by the lua side of the game

globals = globals or {}

-- your defaults in one place
local defaults = {
  whale_dust_amount        = 0,
  whale_dust_target      = 0,
  timeUntilNextGravityWave = 30,
  gravityWaveSeconds       = 30,
  currencyIconForText      = {},



  krill_list              = {}, -- list of krill that are active in the current game

  ui = {
    prestige_uibox = nil,
    prestige_window_open = false,
    
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
    moreKrill = 0, -- just start with more at the beginning
    dustMultiplier = 1.0 -- multiplier for dust collected
  }
}

-- merge‐in any missing keys
for k, v in pairs(defaults) do
  if globals[k] == nil then
      globals[k] = v
  end
end