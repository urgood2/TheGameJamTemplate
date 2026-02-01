# bd-2qf.41: [Descent] F4 Character creation UI

## Implementation Summary

Created character creation UI for Descent roguelike mode with species and background selection.

## Files Created

### `assets/scripts/descent/ui/char_create.lua`

**Available Choices (MVP):**
- Species: Human (versatile, no bonuses)
- Background: Gladiator (+2 STR, +1 DEX, -1 INT)

**Starting Gear (Gladiator):**
- Short Sword x1
- Leather Armor x1
- Health Potion x2
- 50 Gold

**Public API:**
- `init()` - Initialize module
- `open(on_confirm, on_cancel)` - Open character creation
- `close()` - Close screen
- `is_open()` - Check if open
- `handle_input(key)` - Process navigation
- `get_selection()` - Current selection state
- `get_preview()` - Character preview with stats
- `format()` - Console text output
- `create_with(species_id, background_id)` - Direct creation

**Navigation:**
- Up/Down: Switch field (species/background)
- Left/Right: Change selection
- Enter/Space: Confirm
- Escape/Q: Cancel (returns to menu)

**Extensibility:**
- `register_species(species)` - Add custom species
- `register_background(background)` - Add custom background

## Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Select species (Human) | ✅ Human available |
| Select background (Gladiator) | ✅ Gladiator available |
| Starting gear matches spec | ✅ Items defined in background |
| Cancel returns to menu cleanly | ✅ on_cancel callback |

## Usage

```lua
local char_create = require("descent.ui.char_create")
char_create.init()

char_create.open(
    function(character)
        -- character.species_id, background_id, stats, starting_items
        start_game(character)
    end,
    function()
        -- Return to main menu
    end
)

-- Format for display
print(char_create.format())
```

## Agent

- Agent: RedEagle (claude-code/opus-4.5)
- Date: 2026-02-01
