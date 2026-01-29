# Stats Panel Redesign Spec

**Date**: 2025-12-31
**Status**: Approved
**Replaces**: Basic Stats Popup + Detailed Stats Popup

---

## Overview

Merge the current two-popup system (Basic + Detailed) into a single **docked sidebar panel** with:
- Slay the Spire-inspired compact info cards
- Tiered stat visibility with progressive disclosure
- Context-aware highlighting (buffs, warnings, deltas)
- Tabbed detailed stats organization
- Full animation polish

---

## Architecture

### Panel Behavior

| Property | Value |
|----------|-------|
| **Position** | Docked to right edge of screen |
| **Toggle** | Stats button click OR keyboard shortcut (`C`) |
| **Persistence** | Stays open until explicitly closed |
| **Animation** | Slide in/out from right (300ms ease-out) |

### Panel Structure

```
┌─────────────────────────────────────┐
│ ⚔️ CHARACTER STATS            [✕]  │  ← Header
├─────────────────────────────────────┤
│  VITALS (always visible)            │  ← Tier 1
│  ❤️ HP  ⚡ MP  ⭐ Level              │
├─────────────────────────────────────┤
│  ATTRIBUTES (always visible)        │
│  💪 PHY  🎯 CUN  ✨ SPI              │
├─────────────────────────────────────┤
│ ▼ Combat ─────────── (collapsible)  │  ← Expandable
│ ▼ Defense ────────── (collapsible)  │
├─────────────────────────────────────┤
│ [Combat][Resist][Mods][DoTs][Util]  │  ← Tabs
│  (tab content)                      │
└─────────────────────────────────────┘
```

---

## Tier 1 Stats (Always Visible)

These ~12 stats are always shown at the top of the panel:

### Vitals
- HP (current/max)
- MP/Energy (current/max)
- Level + XP progress

### Attributes
- Physique
- Cunning
- Spirit

### Combat (summary)
- Damage (range)
- Attack Speed
- Crit Chance %

### Defense (summary)
- Armor
- Dodge %

---

## Stat Pill Design

Each stat displays as: **Icon + Label + Value** in a rounded pill.

```
┌────────────────┐
│ ⚔️ Damage  45-60│
└────────────────┘
```

### Color Scheme (Hybrid)

**Base hue by category:**
| Category | Base Color |
|----------|------------|
| Vitals (HP) | Red |
| Vitals (MP) | Blue |
| Attributes | Purple |
| Combat | Orange |
| Defense | Steel Blue |
| Elements | Per-element (fire=red, cold=cyan, etc.) |

**Brightness/saturation by state:**
| State | Treatment |
|-------|-----------|
| Normal | Base color at 80% saturation |
| Buffed | Brighter (+20% lightness), green up arrow ▲ |
| Debuffed | Desaturated (-30%), red down arrow ▼ |
| Warning | Pulsing glow animation |
| Capped | Yellow border |

### Delta Display

Show modifier from base value:
```
│🛡️ Armor  120 (+35)│
```

---

## Collapsible Sections

Combat and Defense sections have expand/collapse arrows:

```
▶ Combat ─────────────  (collapsed)
▼ Combat ─────────────  (expanded)
   [additional combat stats shown]
```

### Expanded Combat Stats
- Weapon Damage (range)
- Offensive Ability
- Cast Speed
- Weapon Damage %
- All Damage %
- Life Steal %
- Cooldown Reduction
- Crit Damage %

### Expanded Defense Stats
- Defensive Ability
- Block Chance %
- Block Amount
- Damage Taken Reduction %
- Percent Absorb %
- Flat Absorb
- Reflect Damage %

---

## Tabbed Detailed Stats

Five tabs at the bottom of the panel:

| Tab | Contents |
|-----|----------|
| **Combat** | All offensive stats not in Tier 1 |
| **Resist** | Defensive stats + Elemental Grid |
| **Mods** | Per-element damage modifiers |
| **DoTs** | Duration modifiers (Burn, Poison, Bleed, etc.) |
| **Utility** | Move Speed, XP Gain, CDR, Energy Cost Reduction |

### Tab Styling
- **Active**: Filled background, bold text
- **Inactive**: Outlined, normal weight
- **Colors**: Match category (orange, blue, purple, green, gray)

### Elemental Grid (in Resist tab)

```
┌─────────────────────────────────────────────┐
│  Element    Resist    Damage    Duration    │
│  ─────────────────────────────────────────  │
│  🔥 Fire      25%      +15%      +10%       │
│  ❄️ Cold      30%      +5%       +0%        │
│  ⚡ Lightning  15%      +20%      +5%        │
│  ☠️ Poison     40%      +0%       +25%       │
│  🩸 Bleed      --       +10%      +15%       │
│  ✨ Aether     20%      +0%       +0%        │
│  🌀 Chaos      10%      +5%       +0%        │
│  💀 Vitality   35%      +0%       +20%       │
│  🗡️ Physical   --       +25%      --         │
└─────────────────────────────────────────────┘
```

---

## Animations

### Panel Transitions
| Animation | Duration | Easing |
|-----------|----------|--------|
| Slide in | 300ms | ease-out |
| Slide out | 250ms | ease-in |
| Tab switch | 150ms | crossfade |

### Value Change Animations
When stats update during gameplay:
- **Number tick**: Animate from old value to new (300-500ms)
- **Damage taken**: Pill pulses red briefly (200ms)
- **Heal/buff**: Pill pulses green briefly (200ms)

### Hover Effects
- Subtle glow around pill
- Slight scale (1.02x)
- Tooltip appears with breakdown:
  ```
  "Base: 30-40, Weapon: +10, Buff: +5-10"
  ```

### Warning States
- **Low HP (<25%)**: HP pill pulses red continuously
- **Low MP (<10%)**: MP pill pulses blue continuously
- **Capped stat**: Yellow border, no pulse

---

## Keyboard Controls

| Key | Action |
|-----|--------|
| `C` | Toggle stats panel |
| `Tab` (when open) | Cycle through tabs |
| `Esc` | Close panel |
| `1-5` (when open) | Jump to specific tab |

---

## Icons

Reuse existing game sprites for stat icons:
- ❤️ Heart sprite for HP
- ⚡ Lightning for MP/Energy
- ⚔️ Sword for damage
- 🛡️ Shield for armor
- Element icons from existing atlas

---

## Implementation Notes

### Files to Modify
- `assets/scripts/core/gameplay.lua` - Replace `stats_tooltip` and `makeDetailedStatsTooltip`
- `assets/scripts/ui/` - New `stats_panel.lua` module

### State Management
- Single state tag: `STATS_PANEL_STATE`
- Remove: `PLAYER_STATS_TOOLTIP_STATE`, `DETAILED_STATS_TOOLTIP_STATE`

### Data Flow
- Reuse existing `collectPlayerStatsSnapshot()` function
- Reuse `StatTooltipSystem.DEFS` for stat definitions
- Add new tab groupings to `StatTooltipSystem`

### Performance
- Keep hash-based lazy updates
- Only re-render changed sections
- Debounce value animations if multiple changes in quick succession

---

## Success Criteria

1. **Readability**: Stats scannable at a glance without squinting
2. **Organization**: Clear visual hierarchy and logical groupings
3. **Polish**: Smooth animations, satisfying hover feedback
4. **Usability**: Keyboard accessible, can stay open during combat
5. **Consistency**: Visual style matches game's existing UI aesthetic

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
