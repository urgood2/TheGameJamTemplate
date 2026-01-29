# Feature Showcase Design

**Date:** 2026-01-20
**Purpose:** Comprehensive demo for all Phase 1-6 features added in the `urgood2/kyoto` branch

## Overview

A dedicated fullscreen showcase UI accessible from the main menu that displays all new gameplay systems with test badges verifying functionality.

## Entry Point

- **"Feature Showcase" button** in main menu (prominent placement near Start button)
- Opens fullscreen overlay covering main menu
- ESC or [X] button closes and returns to menu

## Structure

```
┌─────────────────────────────────────────────────┐
│  [X Close]           FEATURE SHOWCASE           │
├─────────────────────────────────────────────────┤
│  Gods & Classes: 7/7 ✓ | Skills: 10/10 ✓ | ...  │
├─────────────────────────────────────────────────┤
│  [Gods & Classes] [Skills] [Artifacts] [Wands] [Status Effects]  │
├─────────────────────────────────────────────────┤
│                                                 │
│   ┌─────────┐  ┌─────────┐  ┌─────────┐        │
│   │  Card   │  │  Card   │  │  Card   │        │
│   │  ✓      │  │  ✓      │  │  ✗      │        │
│   └─────────┘  └─────────┘  └─────────┘        │
│                                                 │
│   (scrollable content area)                     │
│                                                 │
└─────────────────────────────────────────────────┘
```

## Categories (5 tabs)

| Category | Items | Source Data |
|----------|-------|-------------|
| Gods & Classes | 4 gods + 3 classes = 7 | `Avatars` table (type="god" or "class") |
| Skills | 10 | `Skills` table |
| Artifacts | 10 | `Artifacts` table |
| Wands | 6 templates | Wand templates in wand system |
| Status Effects | 6 new effects | `StatusEffects` table |

## Card Designs

### Gods & Classes
```
┌────────────────────────────────┐
│ [Icon]  PYRA, GODDESS OF FIRE  │  ✓
│ Type: God                      │
│ ─────────────────────────────  │
│ Passive: +15% fire damage      │
│ Blessing: Inferno Burst        │
│   • Fire nova, 150 radius      │
│   • 50 damage, 3 burn stacks   │
│   • 30s cooldown               │
└────────────────────────────────┘
```

### Skills
```
┌────────────────────────────────┐
│ [Icon]  FLAME AFFINITY         │  ✓
│ Element: Fire                  │
│ ─────────────────────────────  │
│ +15% fire damage               │
└────────────────────────────────┘
```

### Artifacts
```
┌────────────────────────────────┐
│ [Icon]  EMBER HEART            │  ✓
│ Rarity: Rare | Element: Fire   │
│ ─────────────────────────────  │
│ +20% fire damage               │
│ On kill with fire: restore 5 HP│
└────────────────────────────────┘
```

### Wands
```
┌────────────────────────────────┐
│ [Icon]  STORM_WALKER           │  ✓
│ Trigger: On Bump Enemy         │
│ ─────────────────────────────  │
│ Mana: 35 (regen 12)            │
│ Cast Block: 2                  │
│ Always-Cast: Chain Lightning   │
└────────────────────────────────┘
```

### Status Effects
```
┌────────────────────────────────┐
│ [Icon]  FIREFORM               │  ✓
│ Type: Buff | Duration: 15s     │
│ ─────────────────────────────  │
│ Fire elemental form            │
│ +25% fire damage               │
│ +50 fire resistance            │
│ Burns nearby enemies           │
└────────────────────────────────┘
```

## Test Badge System

### Verification Logic

| System | Validation |
|--------|------------|
| Gods & Classes | Avatar exists, has type/passive/blessing fields |
| Skills | Skill exists, has id/name/element/buffs |
| Artifacts | Artifact exists, has calculate function, rarity |
| Wands | Template exists, has trigger_type/mana_max |
| Status Effects | Effect exists, has duration/effect_type |

### Display
- **✓ Green checkmark:** Item found and valid
- **✗ Red X:** Item missing or invalid

### Header Summary
Quick pass/fail counts per category at top of showcase.

## Navigation

- **Tab switching:** Click tabs or Left/Right arrow keys
- **Scrolling:** Mouse wheel for vertical scroll
- **Close:** [X] button or ESC key
- **Cards:** View-only, no click interactions

## Layout

- 2-3 cards per row (responsive to screen width)
- Consistent card height within category
- Gap/padding between cards
- Scroll position resets on tab switch

## Implementation

### New Files

| File | Purpose |
|------|---------|
| `assets/scripts/ui/showcase/feature_showcase.lua` | Main showcase UI module |
| `assets/scripts/ui/showcase/showcase_verifier.lua` | Test runner for badges |
| `assets/scripts/ui/showcase/showcase_cards.lua` | Card builders per system |

### Modified Files

| File | Change |
|------|--------|
| `assets/scripts/core/main.lua` | Add button, wire open/close |

### Module API

```lua
FeatureShowcase = {
    init(),           -- Initialize UI elements
    show(),           -- Open fullscreen overlay
    hide(),           -- Close and return to menu
    switchCategory(), -- Change active tab
    cleanup(),        -- Destroy all UI elements
}
```

### Data Flow

1. Button click → `FeatureShowcase.show()`
2. On show → `ShowcaseVerifier.runAll()` (cached)
3. Build cards from data modules
4. Attach badges from verification results
5. Render with `dsl.tabs()` for categories

## Features Showcased

### Phase 1: Status Effects
- arcane_charge, focused, fireform, iceform, stormform, voidform

### Phase 2: Wand Templates
- RAGE_FIST, STORM_WALKER, FROST_ANCHOR, SOUL_SIPHON, PAIN_ECHO, EMBER_PULSE

### Phase 3: Gods & Classes
- Gods: Pyra, Frost, Tempest, Nihil
- Classes: Warrior, Mage, Rogue

### Phase 4: Skills
- Fire: Flame Affinity, Pyromaniac
- Ice: Frost Affinity, Permafrost
- Lightning: Storm Affinity, Chain Mastery
- Void: Void Affinity, Void Conduit
- Universal: Battle Hardened, Swift Casting

### Phase 5: Artifacts
- Fire: Ember Heart, Inferno Lens
- Ice: Frost Core, Glacial Ward
- Lightning: Storm Core, Static Field
- Void: Void Heart, Entropy Shard
- Universal: Battle Trophy, Desperate Power

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
