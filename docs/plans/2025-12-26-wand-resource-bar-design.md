# Wand Resource Prediction Bar — Design

**Date:** 2025-12-26
**Status:** Approved

## Problem

Players can't predict whether their wand configuration will cause overuse (going over mana capacity) or how severe the penalty will be. The current card execution visualization (tick + bounce scale) doesn't communicate resource impact. The execution graph shows card order, but not mana consumption.

## Solution

A dedicated UI element in the planning phase showing mana consumption and overuse prediction. Updates live as cards are added or removed.

## Visual Design

### Layout

```
┌──────────────────────────────────────────────────┐
│  ████████████████████░░░░░░░|🔥🔥🔥🔥            │
│  85/100 mana   •   3 cast blocks   •   +1.8s Overuse Penalty │
└──────────────────────────────────────────────────┘
```

### Components

1. **Mana bar** — Horizontal fill showing total cost
   - Fill color: Normal mana consumption (blue/cyan)
   - Empty zone: Available headroom (dark gray)
   - Capacity marker: `|` line at max mana
   - Overflow zone: Red/orange extension past capacity marker

2. **Stats line:**
   - `85/100 mana` — Total cost vs capacity
   - `3 cast blocks` — Wand complexity indicator
   - `+1.8s Overuse Penalty` — Penalty duration (only when overusing)

## States

### State 1: Under Capacity (Safe)
```
████████████░░░░░░░░░░░░░░░|
65/100 mana   •   2 cast blocks
```
- Fill stays within capacity marker
- No penalty text shown
- Colors: Normal fill (blue/cyan), empty (dark gray)

### State 2: At Capacity (Edge)
```
██████████████████████████|
100/100 mana   •   4 cast blocks
```
- Fill reaches exactly to marker
- No penalty (no overflow)
- Subtle warning color (yellow tint)

### State 3: Over Capacity (Overuse)
```
██████████████████████████|🔥🔥🔥🔥🔥
135/100 mana   •   5 cast blocks   •   +2.4s Overuse Penalty
```
- Overflow extends past marker in red/orange
- Penalty text appears
- Fill color shifts to indicate danger

## Behavior

- **Live updates:** Bar changes instantly as cards are added/removed
- **Smooth animation:** Fill tweens over 0.15-0.2s
- **Color transitions:** Animate when crossing capacity threshold
- **Penalty text:** Fades in/out when entering/leaving overuse state

## Implementation Notes

### Data Source

Wand executor already calculates total mana cost and overuse multiplier (`wand_executor.lua:450-465`). Need to expose a "preview" calculation that runs without actually executing.

### Overuse Calculation

From existing system:
```lua
deficit = math.abs(currentMana)  -- when negative
ratio = deficit / maxMana
penalty_mult = 1.0 + (ratio * overheat_penalty_factor)
penalty_seconds = baseCooldown * (penalty_mult - 1.0)
```

### UI Location

- Fixed position in planning UI (exact placement TBD)
- Always visible when in planning phase
- Hidden during execution phase

## What This Does NOT Show

- Individual card costs (execution graph handles detail)
- Execution order (execution graph handles this)

The goal is resource prediction, not execution visualization.

## Terminology

- Use "Overuse Penalty" (not "overheat")
- Format: `+2.4s Overuse Penalty`

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
