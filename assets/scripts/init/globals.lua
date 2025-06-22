-- global variables used by the lua side of the game

globals = globals or {}

globals.krill_tickle_distance = 50 -- distance at which whale can be tickled

globals.entities = globals.entities or {}
globals.entities.whales = {}
globals.entities.krill = {}

globals.buildings = globals.buildings or {}
globals.buildings.basic_dust_collector = {}
globals.buildings.MK2_dust_collector = {}
globals.buildings.krill_home = {}
globals.buildings.krill_farm = {}
globals.buildings.whale_song_gatherer = {}

globals.converters = globals.converters or {}
globals.converters.dust_to_crystal = {}
globals.converters.crystal_to_wafer = {}
globals.converters.wafer_to_chip = {}


globals.whale_dust_amount      = 0
globals.whale_dust_target      = 0

globals.song_essence_amount   = 0
globals.song_essence_target   = 0

globals.crystal_amount        = 0
globals.crystal_target        = 0

globals.wafer_amount        = 0
globals.wafer_target        = 0

globals.chips_amount        = 0
globals.chips_target        = 0

globals.converter_defs = {
  { -- converts dust to crystal
    id = "dust_to_crystal", -- the id of the converter
    required_building = {"whale_song_gatherer"},
    required_converter = {},
    required_currencies = {
      whale_dust_target = 10 -- must hold this much whale dust to unlock
    },
    cost = {
      song_essence = 100  -- the stuff gathered by the whale song gatherer
    },
    unlocked = false,
    anim = "dust_to_crystal_converterAnim", -- the animation for the converter
    ui_text_title = "ui.dust_to_crystal_converter_name", -- the text to display in the ui for this converter
    ui_text_body = "ui.dust_to_crystal_converter_description" -- the text to display in the ui for this converter
  },
  { -- converts crystal to water
    id = "crystal_to_wafer", -- the id of the converter
    required_building = {"whale_song_gatherer"},
    required_converter = {"dust_to_crystal"},
    required_currencies = {
      whale_dust_target = 10 -- must hold this much whale dust to unlock
    },
    cost = {
      crystal = 100  -- the stuff gathered by dust_to_crystal converter
    },
    unlocked = false,
    anim = "crystal_to_wafer_converterAnim", -- the animation for the converter
    ui_text_title = "ui.crystal_to_wafer_converter_name", -- the text to display in the ui for this converter
    ui_text_body = "ui.crystal_to_wafer_converter_description" -- the text to display in the ui for this converter
  },
  { -- converts water to krill
    id = "wafer_to_chip", -- the id of the converter
    required_building = {"whale_song_gatherer"},
    required_converter = {"crystal_to_wafer"},
    required_currencies = {
      whale_dust_target = 10 -- must hold this much whale dust to unlock
    },
    cost = {
      wafer = 100  -- the stuff gathered by  crystal_to_wafer converter
    },
    unlocked = false, 
    anim = "wafer_to_chip_converterAnim", -- the animation for the converter
    ui_text_title = "ui.wafer_to_chip_converter_name", -- the text to display in the ui for this converter
    ui_text_body = "ui.wafer_to_chip_converter_description" -- the text to display in the ui for this converter
  }
}



-- your defaults in one place
local defaults = {
  
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