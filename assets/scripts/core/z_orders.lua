
local z_orders = {
  -- card scene
  background = 0,
  board      = 100,
  card       = 101, -- bottom z order of cards, climbs with new cards in an area
  top_card   = 200, -- when dragging a card, it goes to the top
  card_text  = 250, -- card text is above the card itself
  
  
  -- game scene
  projectiles = 10,
  player_vfx = 20,
  enemies    = 30,
  
  -- general
  ui_transition = 1000,
}

return z_orders