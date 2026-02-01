# bd-2qf.43: [Descent] G1-UI Shop UI

## Implementation Summary

### File Created

**`assets/scripts/descent/ui/shop.lua`** (8 KB)

#### Features
- **Stock Display**: Shows items with names and prices
- **Gold Display**: Player gold shown in header
- **Buy Button**: B key with confirmation dialog
- **Reroll Button**: R key with cost and confirmation
- **Cancel/Back**: Escape key to close

### API

| Function | Description |
|----------|-------------|
| `init(shop, player)` | Initialize with shop module and player |
| `open(on_close)` | Open shop with optional callback |
| `close()` | Close shop UI |
| `is_open()` | Check if shop is open |
| `update(dt)` | Update timers and state |
| `handle_input(key)` | Handle keyboard input |
| `get_render_data()` | Get data for ImGui integration |
| `draw()` | Placeholder for direct rendering |
| `get_selection()` | Get current selection |
| `set_player(player)` | Update player reference |
| `reset()` | Reset UI state |

### Render Data Structure

```lua
{
    visible = true,
    title = "SHOP",
    player_gold = 150,
    reroll_cost = 50,
    mode = "browse",  -- or "confirm_buy", "confirm_reroll"
    message = nil,    -- Status messages
    items = {
        { index = 1, name = "Short Sword", price = 30, sold = false, selected = true, affordable = true },
        ...
    },
    controls = {
        { key = "B", label = "Buy" },
        { key = "R", label = "Reroll (50g)" },
        { key = "Esc", label = "Close" },
    },
    confirm_prompt = nil,  -- Set for confirmation dialogs
}
```

### Usage

```lua
local shop_ui = require("descent.ui.shop")

shop_ui.init(nil, player)  -- Uses default shop module
shop_ui.open(function()
    print("Shop closed")
end)

-- In game loop:
shop_ui.update(dt)
if shop_ui.is_open() and shop_ui.handle_input(key) then
    -- Input consumed by shop
end
```

## Agent

- **Agent**: FuchsiaFalcon
- **Date**: 2026-02-01
