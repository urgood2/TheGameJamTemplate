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
    tooltipBodyText = nil
  },
  
  building_upgrade_defs = {
    basic_dust_collector =  -- the dust collector building
    {
      required = {},
      cost = {
        whale_dust = 30  -- cost in whale dust
      },
      unlocked = false,
      anim = "resonance_beacon_anim"
    },
    MK2_dust_collector =  -- collects 2x dust
    {
      required = {"basic_dust_collector"},
      cost = {
        whale_dust = 100  -- cost in whale dust
      },
      unlocked = false,
      anim = "gathererMK2Anim" -- the animation for the building
      
    },
    krill_home = -- the krill home building (one for every krill)
    {
      required = {},
      cost = {
        whale_dust = 50  -- cost in whale dust
      },
      unlocked = false,
      anim = "krillHomeSmallAnim" -- the animation for the building
    },
    krill_farm = -- the krill farm building (one for 5 krill)
    {
      required = {"krill_home"},
      cost = {
        whale_dust = 400  -- cost in whale dust
      },
      unlocked = false,
      anim = "krillHomeLargeAnim" -- the animation for the building
    },
    whale_song_gatherer = -- the whale song gathering building
    {
      required = {"krill_farm", "basic_dust_collector", "MK2_dust_collector"},
      cost = {
        whale_dust = 1000  -- cost in whale dust
      },
      unlocked = false,
      anim = "dream_weaver_antenna_anim" -- the animation for the building
    }
  },
  
  converter_defs = {
    dust_to_crystal = { -- converts dust to crystal
      required_building = {"whale_song_gatherer"},
      required_converter = {},
      cost = {
        song_essence = 100  -- the stuff gathered by the whale song gatherer
      },
      unlocked = false,
      anim = "dust_to_crystal_converterAnim" -- the animation for the converter
    },
    crystal_to_wafer = { -- converts crystal to water
      required_building = {"whale_song_gatherer"},
      required_converter = {"dust_to_crystal"},
      cost = {
        crystal = 100  -- the stuff gathered by dust_to_crystal converter
      },
      unlocked = false,
      anim = "3972-TheRoguelike_1_10_alpha_765.png" -- the animation for the converter
    },
    wafer_to_chip = { -- converts water to krill
      required_building = {"whale_song_gatherer"},
      required_converter = {"crystal_to_wafer"},
      cost = {
        wafer = 100  -- the stuff gathered by  crystal_to_wafer converter
      },
      unlocked = false, 
      anim = "wafer_to_chip_converterAnim" -- the animation for the converter
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