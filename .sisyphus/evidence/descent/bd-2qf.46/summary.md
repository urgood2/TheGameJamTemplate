# bd-2qf.46: [Descent] G2-UI Altar UI

## Implementation Summary

Created altar UI module for god worship interaction.

## Files Created

### `assets/scripts/descent/ui/altar.lua`

**Features:**
- Shows god info (name, title, description)
- Three modes: info, confirm, result
- Worship confirmation with warning about restrictions
- Cancel/back always available (Escape)

**UI Flow:**
1. Info mode: Shows altar details, options to worship or leave
2. Confirm mode: Warning about god restrictions, confirm/cancel
3. Result mode: Shows worship result message

**Bindings:**
- Up/Down (W/S/Arrows): Navigate options
- Enter/Space: Confirm selection
- Escape/Q: Cancel/close

**API:**
- `open(altar, player)` - Open UI with altar data
- `close()` - Close UI
- `is_open()` - Check if open
- `handle_input(key)` - Process key input
- `update(dt)` - Update (for animations)
- `draw()` - Render UI
- `get_state()` - Get state for testing

## Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Shows god info | ✅ Name, title, description |
| Worship confirmation | ✅ Confirm mode with warning |
| Cancel/back always available | ✅ Escape works in all modes |
| Altar UI functional | ✅ Full input handling |

## Agent

- Agent: RedEagle (claude-code/opus-4.5)
- Date: 2026-02-01
