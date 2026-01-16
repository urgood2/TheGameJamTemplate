
local z_orders = {
  -- card scene
  background = 0,
  board      = 100,
  card       = 1001, -- bottom z order of cards, climbs with new cards in an area
  top_card   = 1002, -- when dragging a card, it goes to the top
  card_text  = 250, -- card text is above the card itself


  -- game scene
  projectiles = 10,
  player_vfx = 20,
  enemies    = 30,
  status_icons = 850, -- Above entities, below UI

  -- general
  particle_vfx = 0,
  player_char = 1,
  ui_transition = 1000,
  ui_tooltips   = 1100,
}

return z_orders