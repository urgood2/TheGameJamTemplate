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
  selected_indices = {
    building_upgrade_defs = 1,
    converter_defs = 1
  },
  
  building_upgrade_defs = {
    {
      id = "basic_dust_collector", -- the id of the building
      required = {},
      cost = {
        whale_dust = 30  -- cost in whale dust
      },
      unlocked = false,
      anim = "resonance_beacon_anim",
      ui_text = "ui.dust_collector_name" -- the text to display in the ui for this building
    },
    {
      id = "MK2_dust_collector", -- the id of the building
      required = {"basic_dust_collector"},
      cost = {
        whale_dust = 100  -- cost in whale dust
      },
      unlocked = false,
      anim = "gathererMK2Anim", -- the animation for the building
      ui_text = "ui.dust_collector_mk2_name" -- the text to display in the ui for this building
      
    },
    {
      id = "krill_home", -- the id of the building
      required = {},
      cost = {
        whale_dust = 50  -- cost in whale dust
      },
      unlocked = false,
      anim = "krillHomeSmallAnim", -- the animation for the building
      ui_text = "ui.krill_home_name" -- the text to display in the ui for this building
    },
    {
      id = "krill_farm", -- the id of the building
      required = {"krill_home"},
      cost = {
        whale_dust = 400  -- cost in whale dust
      },
      unlocked = false,
      anim = "krillHomeLargeAnim", -- the animation for the building
      ui_text = "ui.krill_farm_name" -- the text to display in the ui for this building
    },
    {
      id = "whale_song_gatherer", -- the id of the building
      required = {"krill_farm", "basic_dust_collector", "MK2_dust_collector"},
      cost = {
        whale_dust = 1000  -- cost in whale dust
      },
      unlocked = false,
      anim = "dream_weaver_antenna_anim", -- the animation for the building,
      ui_text = "ui.whale_song_gatherer_name" -- the text to display in the ui for this building
    }
  },
  
  converter_defs = {
    { -- converts dust to crystal
      id = "dust_to_crystal", -- the id of the converter
      required_building = {"whale_song_gatherer"},
      required_converter = {},
      cost = {
        song_essence = 100  -- the stuff gathered by the whale song gatherer
      },
      unlocked = false,
      anim = "dust_to_crystal_converterAnim", -- the animation for the converter
      ui_text = "ui.dust_to_crystal_converter_name" -- the text to display in the ui for this converter
    },
    { -- converts crystal to water
      id = "crystal_to_wafer", -- the id of the converter
      required_building = {"whale_song_gatherer"},
      required_converter = {"dust_to_crystal"},
      cost = {
        crystal = 100  -- the stuff gathered by dust_to_crystal converter
      },
      unlocked = false,
      anim = "3972-TheRoguelike_1_10_alpha_765.png", -- the animation for the converter
      ui_text = "ui.crystal_to_wafer_converter_name" -- the text to display in the ui for this converter
    },
    { -- converts water to krill
      id = "wafer_to_chip", -- the id of the converter
      required_building = {"whale_song_gatherer"},
      required_converter = {"crystal_to_wafer"},
      cost = {
        wafer = 100  -- the stuff gathered by  crystal_to_wafer converter
      },
      unlocked = false, 
      anim = "wafer_to_chip_converterAnim", -- the animation for the converter
      ui_text = "ui.wafer_to_chip_converter_name" -- the text to display in the ui for this converter
    }
  },
  
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