-- global variables used by the lua side of the game

globals = globals or {}

globals.main_menu_elapsed_time = 0 -- time spent in the main menu
globals.gravity_wave_count = 0     -- number of gravity waves that have occurred

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


globals.conversion_reqs                  = globals.conversion_reqs or {}
globals.conversion_reqs.dust_to_crystal  = {
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
globals.conversion_reqs.wafer_to_chip    = {
  cost = {
    wafer = 10, -- amount of wafer required to convert
  },
  output = {
    chip = 1 -- amount of chips produced by the conversion
  }
}

globals.achievements                     = {
  -- list of achievements
  -- each achievement is a table with the following keys:
  -- id: the id of the achievement
  -- name: the name of the achievement
  -- description: the description of the achievement
  -- icon: the icon for the achievement
  -- unlocked: whether the achievement is unlocked or not

  {
    id = "first_whale",                      -- the id of the achievement
    name = "Void Spacing",                   -- the name of the achievement
    description = "Catch your first whale.", -- the description of the achievement
    anim = "blue_whale9_anim",                           -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.entities.whales and #globals.entities.whales > 0 -- check if there is at least one whale
    end,
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "first_whale").unlocked
      and localization.get("ui.first_whale_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.first_whale_tooltip_body")   -- body of the tooltip
      )
    end,
    rewardFunc = function(x, y)
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + 10                                                                               -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = 10, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "first_spark",                                                                 -- the id of the achievement
    name = "First Spark",                                                               -- the name of the achievement
    description = "Gathered your first whale dust.",                                    -- the description of the achievement
    anim = "3654_TheRoguelike_1_10_alpha_447_anim",  
    
    anim_entity = nil,-- the icon for the achievement
    unlocked = false,                                                                   -- whether the achievement is unlocked or not
    require_check = function()
      return globals.currencies.whale_dust and
      globals.currencies.whale_dust.amount > 0                                          -- check if there is at least one whale dust
    end,
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "first_spark").unlocked
      and localization.get("ui.first_spark_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.first_spark_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 10
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "first_krill",                       -- the id of the achievement
    name = "Thrill of the First Krill",       -- the name of the achievement
    description = "Summon your first krill.", -- the description of the achievement
    anim = "krill_2_anim",                            -- the icon for the achievement
    unlocked = false,
    anim_entity = nil,
    require_check = function()
      return globals.entities.krill and #globals.entities.krill > 0 -- check if there is at least one krill
    end,
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "first_krill").unlocked
        and localization.get("ui.first_krill_tooltip_title")
        or localization.get("ui.converter_locked_title"),
        localization.get("ui.first_krill_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 5
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end

  },
  {
    id = "first_dust_collector",                           -- the id of the achievement
    name = "Dustbin Joe",                                  -- the name of the achievement
    description = "Build your very first dust collector.", -- the description of the achievement
    anim = "3916_TheRoguelike_1_10_alpha_709_anim", 
    anim_entity = nil,                                        -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.buildings.basic_dust_collector and
      #globals.buildings.basic_dust_collector > 0                                                   -- check if there is at least one dust collector
    end,
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "first_dust_collector").unlocked
      and localization.get("ui.first_dust_collector_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.first_dust_collector_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount =15
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "first_converter",                           -- the id of the achievement
    name = "Gallop? Or...",                           -- the name of the achievement
    description = "Build your very first converter.", -- the description of the achievement
    anim = "3535_TheRoguelike_1_10_alpha_328_anim",           -- the icon for the achievement
    unlocked = false,
    anim_entity = nil,
    anim_entity = nil,
    require_check = function()
      return globals.converters.dust_to_crystal and
      #globals.converters.dust_to_crystal > 0                                               -- check if there is at least one converter
    end,

    -- first_converter
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "first_converter").unlocked
      and localization.get("ui.first_converter_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.first_converter_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 30
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "first_song_gatherer",                                 -- the id of the achievement
    name = "Whale Whisperer",                                   -- the name of the achievement
    description = "Build your very first whale song gatherer.", -- the description of the achievement
    anim = "4067_TheRoguelike_1_10_alpha_860_anim",                                              -- the icon for the achievement
    unlocked = false,
    anim_entity = nil,
    require_check = function()
      return globals.buildings.whale_song_gatherer and
      #globals.buildings.whale_song_gatherer > 0                                                  -- check if there is at least one whale song gatherer
    end,
    -- first_song_gatherer
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "first_song_gatherer").unlocked
      and localization.get("ui.first_song_gatherer_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.first_song_gatherer_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 100
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "main_menu",                                                -- the id of the achievement
    name = "Prestigious Bastard",                                    -- the name of the achievement
    description = "Spend more than three minutes in the main menu.", -- the description of the achievement
    anim = "3676_TheRoguelike_1_10_alpha_469_anim",   
    anim_entity = nil,                                                -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.main_menu_elapsed_time and
      globals.main_menu_elapsed_time > 180                                           -- check if the player has spent more than 3 minutes in the main menu
    end,



    -- main_menu
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "main_menu").unlocked
      and localization.get("ui.main_menu_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.main_menu_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 1000
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "first_song_essence",                       -- the id of the achievement
    name = "Essence of Song",                        -- the name of the achievement
    description = "Gather your first song essence.", -- the description of the achievement
    anim = "4069_TheRoguelike_1_10_alpha_862_anim",   
    anim_entity = nil,                               -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.currencies.song_essence and
      globals.currencies.song_essence.amount > 0                                            -- check if there is at least one song essence
    end,
    -- first_song_essence
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "first_song_essence").unlocked
      and localization.get("ui.first_song_essence_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.first_song_essence_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 50
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "first_crystal",                       -- the id of the achievement
    name = "Crystal Clear",                     -- the name of the achievement
    description = "Gather your first crystal.", -- the description of the achievement
    anim = "3881_TheRoguelike_1_10_alpha_674_anim",  
    anim_entity = nil,                            -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.currencies.crystal and
      globals.currencies.crystal.amount > 0                                       -- check if there is at least one crystal
    end,
    -- first_crystal
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "first_crystal").unlocked
      and localization.get("ui.first_crystal_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.first_crystal_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 60
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "first_wafer",                       -- the id of the achievement
    name = "Wafers of Wisdom",                -- the name of the achievement
    description = "Gather your first wafer.", -- the description of the achievement
    anim = "4160_TheRoguelike_1_10_alpha_953_anim",     
    anim_entity = nil,                       -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.currencies.wafer and globals.currencies.wafer.amount > 0 -- check if there is at least one wafer
    end,

    -- first_wafer
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "first_wafer").unlocked
      and localization.get("ui.first_wafer_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.first_wafer_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 80
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "first_chip",                                                                                             -- the id of the achievement
    name = "Chips Ahoy!",                                                                                          -- the name of the achievement
    description = "Gather your first chip \n(*whipser* They are only in the game because of the game jam theme).", -- the description of the achievement
    anim = "4071_TheRoguelike_1_10_alpha_864_anim",    
    anim_entity = nil,                                                                                             -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.currencies.chip and globals.currencies.chip.amount > 0 -- check if there is at least one chip
    end,
    -- first_chip
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "first_wafer_to_chip_converter").unlocked
      and localization.get("ui.first_wafer_to_chip_converter_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.first_chip_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 500
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "first_wafer_to_chip_converter",                      -- the id of the achievement
    name = "TSMC GOt it COmIN",                                -- the name of the achievement
    description = "Build your first wafer to chip converter.", -- the description of the achievement
    anim = "3635_TheRoguelike_1_10_alpha_428_anim",   
    anim_entity = nil,                                          -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.converters.wafer_to_chip and
      #globals.converters.wafer_to_chip > 0                                             -- check if there is at least one wafer to chip converter
    end,
    -- first_wafer_to_chip_converter
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "first_wafer_to_chip_converter").unlocked
      and localization.get("ui.first_wafer_to_chip_converter_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.first_wafer_to_chip_converter_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 100
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "first_crystal_to_wafer_converter",                      -- the id of the achievement
    name = "Wafer Maker",                                         -- the name of the achievement
    description = "Build your first crystal to wafer converter.", -- the description of the achievement
    anim = "3640_TheRoguelike_1_10_alpha_433_anim",   
    anim_entity = nil,                                             -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.converters.crystal_to_wafer and
      #globals.converters.crystal_to_wafer > 0                                                -- check if there is at least one crystal to wafer converter
    end,
    -- first_crystal_to_wafer_converter
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "first_crystal_to_wafer_converter").unlocked
      and localization.get("ui.first_crystal_to_wafer_converter_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.first_crystal_to_wafer_converter_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 200
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "grav_surfer",                                     -- the id of the achievement
    name = "Gravity Surfer",                                -- the name of the achievement
    description = "Experience 10 gravitational anomalies.", -- the description of the achievement
    anim = "3738_TheRoguelike_1_10_alpha_531_anim",  
    anim_entity = nil,                                        -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.gravity_wave_count and
      globals.gravity_wave_count >= 10                                       -- check if the player has experienced at least 10 gravitational anomalies
    end,

    -- grav_surfer
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "grav_surfer").unlocked
      and localization.get("ui.grav_surfer_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.grav_surfer_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 90
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "whale_dust_30",                  -- the id of the achievement
    name = "Grabber",                      -- the name of the achievement
    description = "Gather 30 whale dust.", -- the description of the achievement
    anim = "3761_TheRoguelike_1_10_alpha_554_anim", 
    anim_entity = nil,                        -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.currencies.whale_dust and
      globals.currencies.whale_dust.target >= 30                                          -- check if the player has gathered at least 30 whale dust
    end,
    -- whale_dust_30
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "whale_dust_30").unlocked
      and localization.get("ui.whale_dust_30_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.whale_dust_30_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 10
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "whale_dust_100",                  -- the id of the achievement
    name = "Dust Collector",                -- the name of the achievement
    description = "Gather 100 whale dust.", -- the description of the achievement
    anim = "3886_TheRoguelike_1_10_alpha_679_anim", 
    anim_entity = nil,                         -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.currencies.whale_dust and
      globals.currencies.whale_dust.target >= 100                                          -- check if the player has gathered at least 100 whale dust
    end,

    -- whale_dust_100
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "whale_dust_100").unlocked
      and localization.get("ui.whale_dust_100_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.whale_dust_100_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 100
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "whale_dust_500",                  -- the id of the achievement
    name = "Dust Storm",                    -- the name of the achievement
    description = "Gather 500 whale dust.", -- the description of the achievement
    anim = "3887_TheRoguelike_1_10_alpha_680_anim",   
    anim_entity = nil,                       -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.currencies.whale_dust and
      globals.currencies.whale_dust.target >= 500                                          -- check if the player has gathered at least 500 whale dust
    end,
    -- whale_dust_500
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "whale_dust_500").unlocked
      and localization.get("ui.whale_dust_500_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.whale_dust_500_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 500
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "whale_dust_1000",                                             -- the id of the achievement
    name = "Dust Snuffer",                                              -- the name of the achievement
    description = "Gather 1000 whale dust.\nAlso, what have you done?", -- the description of the achievement
    anim = "3888_TheRoguelike_1_10_alpha_681_anim",  
    anim_entity = nil,                                                    -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.currencies.whale_dust and
      globals.currencies.whale_dust.target >= 1000                                          -- check if the player has gathered at least 500 whale dust
    end,

    -- whale_dust_1000
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "whale_dust_1000").unlocked
      and localization.get("ui.whale_dust_1000_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.whale_dust_1000_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 10000
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "song_essence_30",                  -- the id of the achievement
    name = "Appreciator of Music",           -- the name of the achievement
    description = "Gather 30 song essence.", -- the description of the achievement
    anim = "4065_TheRoguelike_1_10_alpha_858_anim",
    anim_entity = nil,                           -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.currencies.song_essence and
      globals.currencies.song_essence.target >= 30                                            -- check if the player has gathered at least 30 song essence
    end,
    -- song_essence_30
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "song_essence_30").unlocked
      and localization.get("ui.song_essence_30_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.song_essence_30_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 100
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end

  },
  {
    id = "song_essence_100",                  -- the id of the achievement
    name = "Sponsor of the Arts",             -- the name of the achievement
    description = "Gather 100 song essence.", -- the description of the achievement
    anim = "3902_TheRoguelike_1_10_alpha_695_anim",
    anim_entity = nil,                            -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.currencies.song_essence and
      globals.currencies.song_essence.target >= 100                                            -- check if the player has gathered at least 100 song essence
    end,
    -- song_essence_100
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "song_essence_100").unlocked
      and localization.get("ui.song_essence_100_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.song_essence_100_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 1000
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "song_essence_500",                  -- the id of the achievement
    name = "Ear Bleeder",                     -- the name of the achievement
    description = "Gather 500 song essence.", -- the description of the achievement
    anim = "3849_TheRoguelike_1_10_alpha_642_anim",  
    anim_entity = nil,                          -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.currencies.song_essence and
      globals.currencies.song_essence.target >= 500                                            -- check if the player has gathered at least 500 song essence
    end,

    -- song_essence_500
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "song_essence_500").unlocked
      and localization.get("ui.song_essence_500_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.song_essence_500_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 2000
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end

  },
  {
    id = "crystal_30",                       -- the id of the achievement
    name = "Crystal Bug",                    -- the name of the achievement
    description = "Gather 30 shiny things.", -- the description of the achievement
    anim = "3847_TheRoguelike_1_10_alpha_640_anim",  
    anim_entity = nil,                         -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.currencies.crystal and
      globals.currencies.crystal.target >= 30                                       -- check if the player has gathered at least 30 crystal
    end,
    -- crystal_30
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "crystal_30").unlocked
        and localization.get("ui.crystal_30_tooltip_title")
        or localization.get("ui.converter_locked_title"),
        localization.get("ui.crystal_30_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 300
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "crystal_100",                         -- the id of the achievement
    name = "Crystal Madness",                   -- the name of the achievement
    description = "Gather 100 shiny crystals.", -- the description of the achievement
    anim = "3628_TheRoguelike_1_10_alpha_421_anim",  
    anim_entity = nil,                            -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.currencies.crystal and
      globals.currencies.crystal.target >= 100                                       -- check if the player has gathered at least 100 crystal
    end,
    -- crystal_100
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "crystal_100").unlocked
        and localization.get("ui.crystal_100_tooltip_title")
        or localization.get("ui.converter_locked_title"),
        localization.get("ui.crystal_100_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 500
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "crystal_500",                         -- the id of the achievement
    name = "I See Things In the Shiny",         -- the name of the achievement
    description = "Gather 500 shiny crystals.", -- the description of the achievement
    anim = "3631_TheRoguelike_1_10_alpha_424_anim", 
    anim_entity = nil,                             -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.currencies.crystal and
      globals.currencies.crystal.target >= 500                                       -- check if the player has gathered at least 500 crystal
    end,
    -- crystal_500
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "crystal_500").unlocked
      and localization.get("ui.crystal_500_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.crystal_500_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 1000
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "wafer_30",                   -- the id of the achievement
    name = "Wafer Tasting",            -- the name of the achievement
    description = "Gather 30 wafers.", -- the description of the achievement
    anim = "4092_TheRoguelike_1_10_alpha_885_anim",
    anim_entity = nil,                     -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.currencies.wafer and
      globals.currencies.wafer.target >= 30                                     -- check if the player has gathered at least 30 wafer
    end,
    -- wafer_30
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "wafer_30").unlocked
      and localization.get("ui.wafer_30_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.wafer_30_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 1000
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "wafer_100",                   -- the id of the achievement
    name = "Wafer Wizard",              -- the name of the achievement
    description = "Gather 100 wafers.", -- the description of the achievement
    anim = "3911_TheRoguelike_1_10_alpha_704_anim", 
    anim_entity = nil,                     -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.currencies.wafer and
      globals.currencies.wafer.target >= 100                                     -- check if the player has gathered at least 100 wafer
    end,
    -- wafer_100
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "wafer_100").unlocked
      and localization.get("ui.wafer_100_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.wafer_100_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 10000
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "wafer_500",                         -- the id of the achievement
    name = "Care for a Wafer? I've Got Many", -- the name of the achievement
    description = "Gather 500 wafers.",       -- the description of the achievement
    anim = "3850_TheRoguelike_1_10_alpha_643_anim",
    anim_entity = nil,
    -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.currencies.wafer and
      globals.currencies.wafer.target >= 500                                     -- check if the player has gathered at least 500 wafer
    end,
    -- wafer_500
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "wafer_500").unlocked
      and localization.get("ui.wafer_500_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.wafer_500_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 100000
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "chip_10",                                                                     -- the id of the achievement
    name = "You Did What?",                                                             -- the name of the achievement
    description = "Gather 10 circuitry chips.\nCongratulations. You've beat the game.", -- the description of the achievement
    anim = "3730_TheRoguelike_1_10_alpha_523_anim",
    anim_entity = nil,
    -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.currencies.chip and
      globals.currencies.chip.target >= 10                                    -- check if the player has gathered at least 100 chips
    end,
    -- chip_10
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "chip_10").unlocked
      and localization.get("ui.chip_10_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.chip_10_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 100000
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "chip_100",                                                   -- the id of the achievement
    name = "There's More?!",                                           -- the name of the achievement
    description = "Gather 100 circuitry chips.\nAnd no, there isn't.", -- the description of the achievement
    anim = "3741_TheRoguelike_1_10_alpha_534_anim",
    anim_entity = nil,
    -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.currencies.chip and
      globals.currencies.chip.target >= 100                                    -- check if the player has gathered at least 100 chips
    end,
    -- chip_100
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "chip_100").unlocked
      and localization.get("ui.chip_100_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.chip_100_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 500000
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end
  },
  {
    id = "chip_500",                                                                -- the id of the achievement
    name = "Ascended Supernatural Venerable Master of the Chip-Fu Universe",        -- the name of the achievement
    description = "Gather 500 circuitry chips.\nI trust nobody will get this far.", -- the description of the achievement
    anim = "3826_TheRoguelike_1_10_alpha_619_anim",
    anim_entity = nil,
    -- the icon for the achievement
    unlocked = false,
    require_check = function()
      return globals.currencies.chip and
      globals.currencies.chip.target >= 500                                    -- check if the player has gathered at least 500 chips
    end,
    -- chip_500
    tooltipFunc = function()
      showTooltip(
        findInTable(globals.achievements, "id", "chip_500").unlocked
      and localization.get("ui.chip_500_tooltip_title")
      or localization.get("ui.converter_locked_title"),
        localization.get("ui.chip_500_tooltip_body")
      )
    end,
    rewardFunc = function(x, y)
      local rewardAmount = 1000000
      globals.currencies.whale_dust.target = globals.currencies.whale_dust.target + rewardAmount  -- give the player 10 whale dust
      newTextPopup(
      localization.get("ui.currency_reward_postfix",
        { amount = rewardAmount, currencyName = localization.get("ui.tooltip_currency_whale_dust_title") }), x, y, 3)                                                          -- show a popup with the reward
    end

  }


}

globals.whale_dust_amount                = 0
globals.whale_dust_target                = 0

globals.song_essence_amount              = 0
globals.song_essence_target              = 0

globals.currencies                       = globals.currencies or {}
globals.currencies.whale_dust            = {
  human_readable_name = "Whale Dust",        -- name of the currency
  amount = 0,                                -- current amount of whale dust
  target = 0,                                -- target amount of whale dust to reach
  anim = "whale_dust_anim",                  -- icon for the whale dust currency
  ui_icon_entity = {},                       -- entity to use for the icon in the ui
  ui_text_title = "ui.whale_dust_name",      -- text to display in the ui for this currency
  ui_text_body = "ui.whale_dust_description" -- text to display in the ui for this currency
}
globals.currencies.song_essence          = {
  human_readable_name = "Song Essence",        -- name of the currency
  amount = 0,                                  -- current amount of song essence
  target = 0,                                  -- target amount of song essence to reach
  anim = "song_essence_anim",                  -- icon for the song essence currency
  ui_icon_entity = {},                         -- entity to use for the icon in the ui
  ui_text_title = "ui.song_essence_name",      -- text to display in the ui for this currency
  ui_text_body = "ui.song_essence_description" -- text to display in the ui for this currency
}
globals.currencies.crystal               = {
  human_readable_name = "Crystal",        -- name of the currency
  amount = 0,                             -- current amount of crystal
  target = 0,                             -- target amount of crystal to reach
  anim = "crystal_anim",                  -- icon for the crystal currency
  ui_icon_entity = {},                    -- entity to use for the icon in the ui
  ui_text_title = "ui.crystal_name",      -- text to display in the ui for this currency
  ui_text_body = "ui.crystal_description" -- text to display in the ui for this currency
}
globals.currencies.wafer                 = {
  human_readable_name = "Wafer",        -- name of the currency
  amount = 0,                           -- current amount of wafer
  target = 0,                           -- target amount of wafer to reach
  anim = "wafer_anim",                  -- icon for the wafer currency
  ui_icon_entity = {},                  -- entity to use for the icon in the ui
  ui_text_title = "ui.wafer_name",      -- text to display in the ui for this currency
  ui_text_body = "ui.wafer_description" -- text to display in the ui for this currency
}
globals.currencies.chip                  = {
  human_readable_name = "Chips",       -- name of the currency
  amount = 0,                          -- current amount of chips
  target = 0,                          -- target amount of chips to reach
  anim = "chip_anim",                  -- icon for the chips currency
  ui_icon_entity = {},                 -- entity to use for the icon in the ui
  ui_text_title = "ui.chip_name",      -- text to display in the ui for this currency
  ui_text_body = "ui.chip_description" -- text to display in the ui for this currency
}

globals.currencies_not_picked_up         = {
  whale_dust = {} -- only whale dust is not picked up by default
}


globals.crystal_amount        = 0
globals.crystal_target        = 0

globals.wafer_amount          = 0
globals.wafer_target          = 0

globals.chips_amount          = 0
globals.chips_target          = 0

globals.building_upgrade_defs = {
  {
    id = "basic_dust_collector", -- the id of the building
    required = {},
    cost = {
      whale_dust = 50 -- cost in whale dust
    },
    required_currencies = {
      whale_dust = 30 -- must hold this much whale dust to unlock
    },
    resource_collection_rate = {
      whale_dust = 1 -- amount of whale dust collected per tick
    },
    unlocked = true,
    anim = "resonance_beacon_anim",
    ui_text_title = "ui.dust_collector_name", -- the ui text for the building
    ui_text_body = "ui.dust_collector_desc",  -- the ui text for the building

    animation_entity = nil                    --
  },
  {
    id = "MK2_dust_collector", -- the id of the building
    required = { "basic_dust_collector" },
    required_currencies = {
      whale_dust = 100 -- must hold this much whale dust to unlock
    },
    cost = {
      whale_dust = 100 -- cost in whale dust
    },
    resource_collection_rate = {
      whale_dust = 2 -- amount of whale dust collected per tick
    },
    unlocked = false,
    anim = "gathererMK2Anim",                       -- the animation for the building
    ui_text_title = "ui.MK2_dust_collector_name",   -- the ui text for the building
    ui_text_body = "ui.MK2_dust_collector_desc",    -- the ui text for the building
    animation_entity = nil                          --

  },
  {
    id = "krill_home", -- the id of the building
    required = {},
    cost = {
      whale_dust = 50 -- cost in whale dust
    },
    required_building_or_converter = {
      MK2_dust_collector = 1,
      basic_dust_collector = 5
    },
    unlocked = true,
    anim = "krillHomeSmallAnim",          -- the animation for the building
    ui_text_title = "ui.krill_home_name", -- the ui text for the building
    ui_text_body = "ui.krill_home_desc",  -- the ui text for the building
    animation_entity = nil                --
  },
  {
    id = "krill_farm", -- the id of the building
    required = { "krill_home" },
    cost = {
      whale_dust = 150 -- cost in whale dust
    },
    required_currencies = {
      whale_dust = 10 -- must hold this much whale dust to unlock
    },
    required_building_or_converter = {
      MK2_dust_collector = 1,
      basic_dust_collector = 5,
      krill_home = 5
    },
    unlocked = false,
    anim = "krillHomeLargeAnim",          -- the animation for the building
    ui_text_title = "ui.krill_farm_name", -- the ui text for the building
    ui_text_body = "ui.krill_farm_desc",  -- the ui text for the building
    animation_entity = nil                --
  },
  {
    id = "whale_song_gatherer", -- the id of the building
    required = { "krill_farm", "basic_dust_collector", "MK2_dust_collector" },
    cost = {
      whale_dust = 1000 -- cost in whale dust
    },
    required_currencies = {
      whale_dust = 10 -- must hold this much whale dust to unlock
    },
    required_building_or_converter = {
      MK2_dust_collector = 1,
      basic_dust_collector = 5,
      krill_home = 5,
      krill_farm = 5
    },
    unlocked = false,
    anim = "dream_weaver_antenna_anim",             -- the animation for the building,
    ui_text_title = "ui.whale_song_gatherer_name",  -- the ui text for the building
    ui_text_body = "ui.whale_song_gatherer_desc",   -- the ui text for the building
    animation_entity = nil                          --
  }
}

globals.converter_defs        = {
  {                         -- converts dust to crystal
    id = "dust_to_crystal", -- the id of the converter
    required_building = { "whale_song_gatherer" },
    required_converter = {},
    required_currencies = {
      whale_dust = 100 -- input required to convert
    },
    required_building_or_converter = {
      krill_home = 5,
      krill_farm = 5
    },
    output = {
      crystal = 1 -- amount of crystal produced by the conversion
    },
    cost = {
      song_essence = 10 -- this is the buy cost
    },
    unlocked = false,
    anim = "dust_to_crystal_converterAnim",                   -- the animation for the converter
    ui_text_title = "ui.dust_to_crystal_converter_name",      -- the text to display in the ui for this converter
    ui_text_body = "ui.dust_to_crystal_converter_description" -- the text to display in the ui for this converter
  },
  {                                                           -- converts crystal to water
    id = "crystal_to_wafer",                                  -- the id of the converter
    required_building = { "whale_song_gatherer" },
    required_converter = { "dust_to_crystal" },
    required_currencies = {
      whale_dust = 50, -- input required to convert
      crystal = 50     -- input required to convert
    },
    required_building_or_converter = {
      krill_home = 5,
      krill_farm = 5,
      dust_to_crystal = 1
    },
    cost = {
      song_essence = 100,
      crystal = 100 -- the stuff gathered by dust_to_crystal converter
    },
    output = {
      wafer = 1 -- amount of wafer produced by the conversion
    },
    unlocked = false,
    anim = "crystal_to_wafer_converterAnim",                   -- the animation for the converter
    ui_text_title = "ui.crystal_to_wafer_converter_name",      -- the text to display in the ui for this converter
    ui_text_body = "ui.crystal_to_wafer_converter_description" -- the text to display in the ui for this converter
  },
  {                                                            -- converts water to krill
    id = "wafer_to_chip",                                      -- the id of the converter
    required_building = { "whale_song_gatherer" },
    required_converter = { "crystal_to_wafer" },
    required_currencies = {
      crystal = 100,
      wafer = 10,        -- input required to converting
      whale_dust = 1000, -- input required to convert
      song_essence = 100 -- input required to convert
    },
    required_building_or_converter = {
      krill_home = 5,
      krill_farm = 5,
      crystal_to_wafer = 1
    },
    cost = {
      song_essence = 100,
      crystal = 100, -- the stuff gathered by dust_to_crystal converter
      wafer = 100    -- the stuff gathered by  crystal_to_wafer converter
    },
    output = {
      chip = 1 -- amount of chips produced by the conversion
    },
    unlocked = false,
    anim = "wafer_to_chip_converterAnim",                   -- the animation for the converter
    ui_text_title = "ui.wafer_to_chip_converter_name",      -- the text to display in the ui for this converter
    ui_text_body = "ui.wafer_to_chip_converter_description" -- the text to display in the ui for this converter
  }
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
