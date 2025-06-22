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


globals.conversion_reqs = globals.conversion_reqs or {}
globals.conversion_reqs.dust_to_crystal = {
  cost = {
    whale_dust = 10, -- amount of whale dust required to convert
  },
  output = {
    crystal = 1 -- amount of crystal produced by the conversion
  }
}
globals.conversion_reqs.crystal_to_wafer = {
  cost = {
    crystal = 10, -- amount of crystal required to convert
  },
  output = {
    wafer = 1 -- amount of wafer produced by the conversion
  }
}
globals.conversion_reqs.wafer_to_chip = {
  cost = {
    wafer = 10, -- amount of wafer required to convert
  },
  output = {
    chip = 1 -- amount of chips produced by the conversion
  }
}

globals.whale_dust_amount      = 0
globals.whale_dust_target      = 0

globals.song_essence_amount   = 0
globals.song_essence_target   = 0

globals.currencies = globals.currencies or {}
globals.currencies.whale_dust = {
  amount = 0, -- current amount of whale dust
  target = 0, -- target amount of whale dust to reach
  anim = "whale_dust_anim", -- icon for the whale dust currency
  ui_icon_entity = {}, -- entity to use for the icon in the ui
  ui_text_title = "ui.whale_dust_name", -- text to display in the ui for this currency
  ui_text_body = "ui.whale_dust_description" -- text to display in the ui for this currency
}
globals.currencies.song_essence = {
  amount = 0, -- current amount of song essence
  target = 0, -- target amount of song essence to reach
  anim = "song_essence_anim", -- icon for the song essence currency
  ui_icon_entity = {}, -- entity to use for the icon in the ui
  ui_text_title = "ui.song_essence_name", -- text to display in the ui for this currency
  ui_text_body = "ui.song_essence_description" -- text to display in the ui for this currency
}
globals.currencies.crystal = {
  amount = 0, -- current amount of crystal
  target = 0, -- target amount of crystal to reach
  anim = "crystal_anim", -- icon for the crystal currency
  ui_icon_entity = {}, -- entity to use for the icon in the ui
  ui_text_title = "ui.crystal_name", -- text to display in the ui for this currency
  ui_text_body = "ui.crystal_description" -- text to display in the ui for this currency
}
globals.currencies.wafer = {
  amount = 0, -- current amount of wafer
  target = 0, -- target amount of wafer to reach
  anim = "wafer_anim", -- icon for the wafer currency
  ui_icon_entity = {}, -- entity to use for the icon in the ui
  ui_text_title = "ui.wafer_name", -- text to display in the ui for this currency
  ui_text_body = "ui.wafer_description" -- text to display in the ui for this currency
}
globals.currencies.chip = {
  amount = 0, -- current amount of chips
  target = 0, -- target amount of chips to reach
  anim = "chip_anim", -- icon for the chips currency
  ui_icon_entity = {}, -- entity to use for the icon in the ui
  ui_text_title = "ui.chip_name", -- text to display in the ui for this currency
  ui_text_body = "ui.chip_description" -- text to display in the ui for this currency
}


globals.crystal_amount        = 0
globals.crystal_target        = 0

globals.wafer_amount        = 0
globals.wafer_target        = 0

globals.chips_amount        = 0
globals.chips_target        = 0

globals.building_upgrade_defs = {
  {
    id = "basic_dust_collector", -- the id of the building
    required = {},
    cost = {
      whale_dust = 10  -- cost in whale dust
    },
    unlocked = true,
    anim = "resonance_beacon_anim",
    ui_text_title = "ui.dust_collector_name", -- the ui text for the building
    ui_text_body = "ui.dust_collector_desc", -- the ui text for the building
  
    animation_entity = nil -- 
  },
  {
    id = "MK2_dust_collector", -- the id of the building
    required = {"basic_dust_collector"},
    required_currencies = {
      whale_dust = 10 -- must hold this much whale dust to unlock
    },
    cost = {
      whale_dust = 100  -- cost in whale dust
    },
    unlocked = false,
    anim = "gathererMK2Anim", -- the animation for the building
      ui_text_title = "ui.MK2_dust_collector_name", -- the ui text for the building
      ui_text_body = "ui.MK2_dust_collector_desc", -- the ui text for the building
    animation_entity = nil -- 
    
  },
  {
    id = "krill_home", -- the id of the building
    required = {},
    cost = {
      whale_dust = 50  -- cost in whale dust
    },
    unlocked = true,
    anim = "krillHomeSmallAnim", -- the animation for the building
    ui_text_title = "ui.krill_home_name", -- the ui text for the building
    ui_text_body = "ui.krill_home_desc", -- the ui text for the building
    animation_entity = nil -- 
  },
  {
    id = "krill_farm", -- the id of the building
    required = {"krill_home"},
    cost = {
      whale_dust = 400  -- cost in whale dust
    },
    required_currencies = {
      whale_dust = 10 -- must hold this much whale dust to unlock
    },
    unlocked = false,
    anim = "krillHomeLargeAnim", -- the animation for the building
    ui_text_title = "ui.krill_farm_name", -- the ui text for the building
    ui_text_body = "ui.krill_farm_desc", -- the ui text for the building
    animation_entity = nil -- 
  },
  {
    id = "whale_song_gatherer", -- the id of the building
    required = {"krill_farm", "basic_dust_collector", "MK2_dust_collector"},
    cost = {
      whale_dust = 1000  -- cost in whale dust
    },
    required_currencies = {
      whale_dust = 10 -- must hold this much whale dust to unlock
    },
    unlocked = false,
    anim = "dream_weaver_antenna_anim", -- the animation for the building,
    ui_text_title = "ui.whale_song_gatherer_name", -- the ui text for the building
      ui_text_body = "ui.whale_song_gatherer_desc", -- the ui text for the building
    animation_entity = nil -- 
  }
}

globals.converter_defs = {
  { -- converts dust to crystal
    id = "dust_to_crystal", -- the id of the converter
    required_building = {"whale_song_gatherer"},
    required_converter = {},
    required_currencies = {
      whale_dust = 10 -- must hold this much whale dust to unlock
    },
    output = {
      crystal = 1 -- amount of crystal produced by the conversion
    },
    cost = {
      song_essence = 100  -- this is the buy cost
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
      whale_dust = 10 -- must hold this much whale dust to unlock
    },
    cost = {
      crystal = 100  -- the stuff gathered by dust_to_crystal converter
    },
    output = {
      wafer = 1 -- amount of wafer produced by the conversion
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
      whale_dust = 10 -- must hold this much whale dust to unlock
    },
    cost = {
      wafer = 100  -- the stuff gathered by  crystal_to_wafer converter
    },
    output = {
      chip = 1 -- amount of chips produced by the conversion
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