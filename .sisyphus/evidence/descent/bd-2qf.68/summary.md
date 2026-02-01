# bd-2qf.68: [Descent] S7 Death/victory seed logging

## Implementation Summary

Added terminal seed logging to endings.lua for run reproduction.

## Files Modified

### `assets/scripts/descent/ui/endings.lua`

**Changes:**
- Added `log_seed(ending_type, stats)` helper function
- Logs seed to terminal on victory, death, and error screens
- Shows replay command: `DESCENT_SEED=<seed>`

**Log Format:**
```
================================================================================
[Descent] VICTORY - Run ended
[Descent] Seed: 12345
[Descent] Floor: 5 | Turns: 423
[Descent] To replay: DESCENT_SEED=12345 (or pass seed in options)
================================================================================
```

**Functions Updated:**
- `show_victory()` - Now logs seed before setting state
- `show_death()` - Now logs seed before setting state
- `show_error()` - Now logs seed before setting state

## Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Seed logged to terminal | ✅ log_seed() function |
| Seed shown on screen | ✅ Already in get_render_data() |
| Enables reproduction | ✅ Shows DESCENT_SEED env var |

## Agent

- Agent: RedEagle (claude-code/opus-4.5)
- Date: 2026-02-01
