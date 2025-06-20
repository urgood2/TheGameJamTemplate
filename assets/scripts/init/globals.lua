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
    prestige_window_open = false
  }
}

-- merge‐in any missing keys
for k, v in pairs(defaults) do
  if globals[k] == nil then
      globals[k] = v
  end
end