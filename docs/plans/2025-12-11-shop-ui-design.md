# Shop UI Design

## Overview

Implement visual shop UI for the between-round card shop. Backend logic exists in `shop_system.lua`; this design covers the missing frontend.

## Layout

```
┌─────────────────────────────────────────────────────────────┐
│                      SHOP BOARD (800x400)                   │
│                                                             │
│   ┌────┐   ┌────┐   ┌────┐   ┌────┐   ┌────┐              │
│   │Card│   │Card│   │Card│   │Card│   │Card│              │
│   │ 1  │   │ 2  │   │ 3  │   │ 4  │   │ 5  │              │
│   └────┘   └────┘   └────┘   └────┘   └────┘              │
│     │                                                       │
│   ┌─▼──┐  (buy button slides down on hover)                │
│   │ 3g │  (green if affordable, red if not)                │
│   └────┘                                                    │
│                                                             │
│   ┌──────────────────────────────────────────────────────┐ │
│   │  [Lock All]       [Reroll (5g)]        Gold: 42      │ │
│   └──────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

- 5 cards in horizontal row, evenly spaced
- Buy button slides down from hovered card
- Control bar at bottom: Lock, Reroll, gold display
- Cards show rarity border color (gray/blue/purple/gold)

## Card Interaction

### On Hover
1. Card scales up to 1.1x with easing
2. Tooltip appears (existing system)
3. Buy button slides down from card bottom (0.15s)
4. Button shows cost in green (affordable) or red (not affordable)

### On Buy Click
**If affordable:**
1. Play "shop-buy" sound
2. Card dissolves via `dissolve` shader uniform (0→1 over 0.3s)
3. Slot shows "SOLD" placeholder
4. New card spawns in inventory via `addPurchasedCardToInventory()`
5. Gold deducted, currency display pulses
6. `signal.emit("deck_changed")` fires

**If not affordable:**
1. Play "cannot-buy" sound
2. Text popup "Need more gold"
3. Button shakes briefly

### On Hover Exit
- Buy button slides up (hidden)
- Card returns to normal scale

## Control Bar

### Lock All Button
- Toggles `globals.shopUIState.locked`
- Text: "Lock All" ↔ "Unlock All"
- When locked: offerings preserved across rerolls
- Visual: gold tint when locked

### Reroll Button
- Shows cost: "Reroll (5g)"
- Calls `rerollActiveShop()` on click
- Cost escalates: 5g → 6g → 7g...
- If not affordable: "cannot-buy" sound + popup

### Gold Display
- Uses existing `CurrencyDisplay` module
- Right side of control bar
- Pulses on change

### Sold Slots
- Show "SOLD" text or grayed silhouette
- Not interactive
- Reroll does not regenerate sold slots

## Implementation

### Files to Modify

**`gameplay.lua`:**
- Add `populateShopBoard()` function:
  - Clear existing shop card entities
  - Create card entities from `active_shop_instance.offerings`
  - Position cards in horizontal row
  - Attach hover/buy button behavior

**`ui_defs.lua`:**
- Uncomment and fix `buildShopUI()`:
  - Create control bar
  - Lock/Reroll buttons
  - Currency display integration

### Reuse Existing
- `createNewCard()` for card entities
- `CurrencyDisplay` for gold display
- `tryPurchaseShopCard()` for purchase logic
- Dissolve shader from shader library
- Tooltip system for card info

### Estimated Scope
~200-300 lines of new/modified Lua code, primarily in `gameplay.lua`.
