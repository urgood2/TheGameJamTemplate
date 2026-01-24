# Wand Cast Simulation HUD

## Overview

A real-time visual simulation that shows exactly how a wand's cast sequence will play out in combat. Unlike the static wand panel, this HUD animates the cast sequence with authentic timing, helping players understand their wand's rhythm before entering the arena.

---

## Goals
- Make timing, ordering, and triggers visually obvious without reading logs.
- Match combat cadence (cast + recharge) as closely as the evaluator allows.
- Stay lightweight: no audio, no DPS, no mana bar (visualization only).

## Non-Goals
- Damage math, proc chances, or joker effects.
- Replacing or duplicating the wand panel UI.
- Previewing multi-wand rotations.

---

## Core Behavior

### Simulation Authenticity
- **Real-time delays**: Combat timing drives mana and penalties; visual delays are capped for readability only
- **Overheat penalties**: When mana would go negative, delay scales with deficit (visual delay still capped; recharge shows text-only penalty)
- **Shuffle randomization**: Shuffle wands re-randomize card order each loop cycle using a local RNG seed (avoid `os.time()` reseed)
- **Continuous loop**: Cast sequence → recharge period → repeat

### What It Shows
- **Cast blocks**: Groups of modifier + action icons that fire together
- **Always-cast cards**: Included in every cast block
- **Sub-casts**: Appear sequentially after their parent action fires, with trigger label (e.g., "On Hit →" or "After 0.5s →")
- **Multicast**: Duplicate action icons (2 fireball icons for Double Cast)
- **Cooldown penalty text**: Shown during recharge if overheat applies

### What It Does NOT Show
- Joker triggers/effects (wand cards only)
- Mana consumption/bar (but mana is still simulated for overheat timing)
- Trigger card context (always simulates as "cast now")

---

## Visual Design

### Layout
- **Position**: Center of screen, horizontal strip
- **Style**: Borderless HUD, no window chrome
- **Icon size**: 48px (same as wand panel grid slots)
- **Visibility**: Planning phase only, when manually activated

### Cast Block Display
Each cast block appears as a **single horizontal row** of icons:
```
[Modifier1] [Modifier2] [Action]    →    [Modifier1] [Action] [Action]
         Block 1                    0.2s           Block 2 (multicast)
```

- Modifiers and actions are side-by-side, not stacked
- Small timer text between blocks shows time until the next block (capped)
- Sub-casts appear after their parent with trigger label

### Animation: Left-Anchored Scroll
1. Current block displays at **left edge** of HUD
2. As block "fires", it **scrolls off-screen to the left**
3. Next block slides in from the right to become current
4. When cast sequence completes, all icons scroll away
5. Recharge countdown displays in empty space
6. New cycle begins with icons entering from right

### Empty State
When no action cards are equipped:
- Display placeholder text: "No actions equipped"

---

## Controls

### Activation
- **Play button**: Located in the wand panel UI
- **Toggle behavior**: Click to start, click again to stop
- **Wand scope**: Simulates the currently active wand tab only

### Stopping
- Click play button again, OR
- Close wand panel
- **Behavior**: Immediate hide (no animation)

### No Sound
- Simulation is completely silent (visual-only preview)

---

## Timing Model

### Per-Block Timing
```
blockDelay = (block.total_cast_delay + wand.cast_delay) / 1000
interBlockDelay = (block.block_delay or 0) / 1000
maxMana = wand.mana_max or 100
castSpeed = playerStats and playerStats.get and (playerStats:get("cast_speed") or 0) or 0

// Apply player cast speed (if applicable)
if castSpeed > 0:
    blockDelay = blockDelay / (1.0 + castSpeed / 100)

// Apply overheat penalty
if currentMana < 0:
    deficit = abs(currentMana)
    overloadRatio = deficit / maxMana
    penaltyMultiplier = 1.0 + (overloadRatio * 5.0)
    blockDelay = blockDelay * penaltyMultiplier

simDelay = blockDelay + interBlockDelay

// Readability cap (visual only)
visualBlockDelay = min(blockDelay, 5.0)
displayDelay = visualBlockDelay + interBlockDelay
// Use displayDelay for animation timing and timer labels
// Use simDelay for mana regen and penalty calculations
```

### Recharge Period
After all blocks complete:
```
rechargeTime = wand.recharge_time / 1000
maxMana = wand.mana_max or 100
cooldownReduction = playerStats and playerStats.get and (playerStats:get("cooldown_reduction") or 0) or 0
if cooldownReduction > 0:
    rechargeTime = rechargeTime * (1.0 - cooldownReduction / 100)
cooldownPenaltyMult = 1.0
if currentMana < 0:
    deficit = abs(currentMana)
    overloadRatio = deficit / maxMana
    penaltyFactor = wand.overheat_penalty_factor or 5.0
    cooldownPenaltyMult = 1.0 + (overloadRatio * penaltyFactor)
// Display recharge countdown only; show penalty text (e.g., "Overheat +60% cooldown")
```

### Sub-Cast Timing
- **Timer-based**: Shows delay before sub-cast block appears (e.g., "After 0.5s →")
- **Collision-based**: Shows trigger label (e.g., "On Hit →"), appears immediately after parent in sequence
- **Death-based**: Shows trigger label (e.g., "On Death →"), appears immediately after parent in sequence
- **No cost**: Sub-casts do not consume mana or add cast delay; only the trigger delay is shown
- **No overlap**: Timer sub-casts are inserted sequentially for readability, even if they would overlap in combat

### Mana Simulation Model (mirrors `wand_executor.lua`)
- **Start mana**: Use live wand state if available (`WandExecutor.getWandState`); otherwise start at `wand.mana_max`.
- **Max mana**: `wand.mana_max` (fallback 100).
- **Regen rate**: `wand.mana_recharge_rate` per second (regen while casting and during recharge).
- **Per block costs**:
  - Aggregate modifiers from `block.applied_modifiers` via `WandModifiers.aggregate`.
  - Merge player stats (`WandModifiers.mergePlayerStats`) to update `manaCostMultiplier`.
  - `manaCostMultiplier = max(0, modifiers.manaCostMultiplier or 1.0)`.
  - `modifierCost = max(0, modifiers.manaCost or 0) * manaCostMultiplier` (once per block).
  - `actionCost = sum(max(0, card.mana_cost or 0) * manaCostMultiplier)` for action cards.
  - `currentMana = currentMana - (modifierCost + actionCost)` (allow negative).
- **Overheat timing**: Apply the per-block overheat penalty after costs (uses penalty factor 5.0 in `wand_executor.lua`).
- **Regen during delays**: After each block, regen during `simDelay`:
  - `currentMana = min(maxMana, currentMana + manaRegenRate * elapsedSeconds)`.
- **Recharge timing**:
  - Base: `rechargeTime = wand.recharge_time / 1000`.
  - Apply player cooldown reduction if available (`cooldown_reduction` stat).
  - If `currentMana < 0`, compute `cooldownPenaltyMult` using `wand.overheat_penalty_factor` (fallback 5.0).
  - HUD shows the base recharge countdown only; penalty is text-only.

---

## Data Requirements

### Input
- Active wand definition (from `wand_panel.lua` state)
- Equipped action cards (from `state.actionCards[wandIndex]`)
- Always-cast cards (from wand definition)
- Optional live wand state (from `WandExecutor.getWandState`) for current mana
- Player stats (cast speed, etc.) - optional, can assume defaults

### Processing
1. Run card evaluator to get cast blocks (same as `wand_executor.lua`)
2. For shuffle wands, pre-shuffle the card list with a local RNG seed and evaluate with `shuffle = false`
3. Simulate mana per block to determine overheat timing
4. Calculate timing for each block (including overheat simulation)
5. Flatten sub-casts into sequential display order with trigger labels (no mana/delay contribution)

### Output State
```lua
{
    blocks = {
        {
            icons = { card1, card2, ... },  -- ordered: modifiers then action(s)
            delay = 0.2,                     -- seconds until next block (displayDelay, capped)
            simDelay = 0.35,                 -- seconds until next block (uncapped, for mana/penalty)
            isSubCast = false,
            subCastTrigger = nil,            -- "On Hit", "After 0.5s", etc.
        },
        ...
    },
    totalCastTime = 1.5,      -- seconds for full displayed sequence (capped)
    totalSimTime = 2.2,       -- seconds for full simulated sequence (uncapped)
    rechargeTime = 0.8,       -- seconds between loops
    isOverheating = false,    -- true if any block has overheat penalty
    cooldownPenaltyMult = 1.0, -- for displaying "Overheat +X% cooldown"
}
```

---

## Implementation Notes

### Recommended Architecture
1. **Simulation Engine** (`wand_cast_simulator.lua`)
   - Reuses `core.card_eval_order_test.lua` (`simulate_wand`) for block generation
   - Calculates timing with overheat model
   - Returns structured block data

2. **HUD Renderer** (`cast_simulation_hud.lua`)
   - Manages icon entities and positions
   - Handles scroll animation via timers
   - Listens for play/stop signals

3. **Wand Panel Integration**
   - Add play button to existing panel
   - Emit signal when clicked: `Signal.emit("cast_simulation_toggle", wandIndex)`

### Key Dependencies
- `core.card_eval_order_test.lua` - Cast block generation
- `wand_modifiers.lua` - Modifier aggregation
- Timer system - Animation sequencing
- Card icon sprites - Visual assets

---

## Implementation Plan

### Phase 1: Data + Simulation
1. **Hook wand state**: Read active wand, cards, and player stats from `wand_panel.lua`.
2. **Shuffle handling**: Use a local RNG seed (incrementing per loop) to pre-shuffle the card list and set `shuffle = false` for evaluation.
3. **Evaluate blocks**: Reuse `core.card_eval_order_test.lua` (`simulate_wand`) to build the base blocks.
4. **Mana simulation**: Model mana spend and regen across blocks to compute `currentMana` per block.
5. **Timing model**: Apply cast delay, cast speed, and overheat penalty; cap only display delays.
6. **Sub-cast flattening**: Produce a linear list with trigger labels and optional sub-delay.

### Phase 2: HUD Layout + Entities
1. **Root container**: Spawn a screen-space UI root at center.
2. **Icon nodes**: Build entity list per block with 48px icons and consistent spacing.
3. **Timer labels**: Insert delay text nodes between blocks.
4. **Penalty text**: Show cooldown penalty label during recharge when `cooldownPenaltyMult > 1.0`.
5. **Empty state**: Show placeholder label if no actions or only triggers.

### Phase 3: Playback + Animation
1. **Play loop**: Start on toggle; stop and cleanup on toggle-off or panel close.
2. **Scroll animation**: Move current block left off-screen, slide next block in.
3. **Recharge state**: Clear icons, show countdown timer, then respawn new cycle.
4. **Shuffle re-roll**: Re-evaluate blocks after each recharge cycle.

### Phase 4: Integration + Signals
1. **UI button**: Add play/stop button to wand panel.
2. **Signals**: `Signal.emit("cast_simulation_toggle", wandIndex)` on click.
3. **Wand switch**: Stop active sim and restart if still toggled.

### Phase 5: Validation
1. **Timing sanity**: Compare block delays to `wand_executor.lua` logs.
2. **Edge cases**: Empty wand, only triggers, very long sequences, high overheat.
3. **Regression**: Ensure no UI leaks on repeated toggle.

---

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Empty wand (no actions) | Show "No actions equipped" placeholder |
| Only trigger card | Show placeholder (no actions to simulate) |
| Shuffle wand | Re-randomize order each loop cycle |
| Extreme overheat (5x+ penalty) | Cap visual delay at 5s per block; show penalty text during recharge |
| Very long cast sequence | Allow horizontal scroll, don't truncate |
| Sub-cast of sub-cast | Flatten into sequential order with nested trigger labels |
| Wand switch during simulation | Stop current simulation, can restart on new wand |

---

## Future Considerations (Out of Scope)

- Multi-wand rotation preview
- Joker effect visualization toggle
- DPS/damage calculation overlay
- Comparison mode (before/after card change)
- Playback speed control
