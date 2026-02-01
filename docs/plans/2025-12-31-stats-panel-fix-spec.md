# Stats Panel Fix Spec

**Date**: 2025-12-31
**Status**: Ready for Implementation
**Supersedes**: docs/plans/2025-12-31-stats-panel-redesign.md (original design)

---

## Overview

Fix the stats panel (activated with "C") to:
1. Display all stats from the old two-popup system
2. Update tab content in-place without recreating the entire panel
3. Implement all polish features from the original design spec

---

## Panel Structure

```
┌─────────────────────────────────────────┐
│ ⚔️ CHARACTER STATS               [✕]   │ ← Fixed header
├─────────────────────────────────────────┤
│ ┌─────────────────────────────────────┐ │
│ │ TIER 1 (always visible, 6 groups)  │ │
│ │  • Vitals: Lv+XP, HP, HP Regen     │ │
│ │  • Attributes: PHY, CUN, SPI       │ │
│ │  • Offense: OA, Dmg, AtkSpd...     │ │ ← Single scroll
│ │  • Defense: DA, Armor, Dodge       │ │   pane for all
│ │  • Utility: CDR, EnergyCost        │ │   content
│ │  • Movement: RunSpd, MoveSpd%      │ │
│ │─────────────────────────────────────│ │
│ │ TAB CONTENT (swapped in-place)     │ │
│ │  [current tab's sections]          │ │
│ └─────────────────────────────────────┘ │
├─────────────────────────────────────────┤
│ [Combat][Resist][Mods][DoTs][Utility]   │ ← Fixed tab bar
│ C: toggle  Tab: cycle  1-5: jump        │ ← Fixed footer
└─────────────────────────────────────────┘
```

### Key Architectural Change
**Hybrid rebuild strategy**: The panel entity, header, Tier 1 section, tab bar, and footer remain static. Only the tab content area is destroyed/recreated on tab switch, eliminating full-panel flicker.

---

## Tier 1 Stats (Always Visible)

All 21 BASIC_STATS organized in 6 always-expanded category groups:

### Vitals
| Stat | Format | Example |
|------|--------|---------|
| Level + XP | Combined | "Lv.5 (340/500)" |
| Health | Fraction | "HP: 85/100" |
| Health Regen | Float | "HP Regen: 2.5/s" |

### Attributes
| Stat | Format |
|------|--------|
| Physique | Integer |
| Cunning | Integer |
| Spirit | Integer |

### Offense
| Stat | Format |
|------|--------|
| Offensive Ability | Integer |
| Damage | Range ("45-60") |
| Attack Speed | Float ("/s") |
| Cast Speed | Float ("/s") |
| Crit Damage % | Percent |
| All Damage % | Percent |
| Life Steal % | Percent |

### Defense
| Stat | Format |
|------|--------|
| Defensive Ability | Integer |
| Armor | Integer |
| Dodge Chance % | Percent |

### Utility
| Stat | Format |
|------|--------|
| Cooldown Reduction | Percent |
| Skill Energy Cost | Percent |

### Movement
| Stat | Format |
|------|--------|
| Run Speed | Float |
| Move Speed % | Percent |

### Layout
- 2-column grid within each group
- Section headers (e.g., "VITALS") in muted color, always expanded
- All 21 stats visible without interaction

---

## Tab Content Layouts

### Combat Tab
| Section | Stats |
|---------|-------|
| **Offense** | all_damage_pct, weapon_damage_pct, life_steal_pct, cooldown_reduction, cast_speed, offensive_ability |
| **Melee** | melee_damage_pct, melee_crit_chance_pct |
| **Penetration** | penetration_all_pct, armor_penetration_pct |

### Resist Tab
| Section | Stats |
|---------|-------|
| **Defense** | defensive_ability, block_chance_pct, block_amount, block_recovery_reduction_pct, percent_absorb_pct, flat_absorb, armor_absorption_bonus_pct |
| **Damage Reduction** | damage_taken_reduction_pct, max_resist_cap_pct, min_resist_cap_pct |
| **Elemental Grid** | (see below) |

### Mods Tab
| Section | Stats |
|---------|-------|
| **Elemental Damage** | fire_modifier_pct, cold_modifier_pct, lightning_modifier_pct, acid_modifier_pct, vitality_modifier_pct, aether_modifier_pct, chaos_modifier_pct |
| **Physical Damage** | physical_modifier_pct, pierce_modifier_pct, penetration_all_pct, armor_penetration_pct |

### DoTs Tab
| Section | Stats |
|---------|-------|
| **Duration Modifiers** | burn_duration_pct, frostburn_duration_pct, electrocute_duration_pct, poison_duration_pct, vitality_decay_duration_pct, bleed_duration_pct, trauma_duration_pct |
| **Burn Effects** | burn_damage_pct, burn_tick_rate_pct |
| **Poison Effects** | max_poison_stacks_pct |

### Utility Tab
| Section | Stats |
|---------|-------|
| **Movement** | run_speed, move_speed_pct |
| **Resources** | skill_energy_cost_reduction, experience_gained_pct, healing_received_pct, health_pct |
| **Buffs** | buff_duration_pct, buff_effect_pct |
| **Summon** | summon_hp_pct, summon_damage_pct, summon_persistence |
| **Hazard** | hazard_radius_pct, hazard_damage_pct, hazard_duration |
| **Special** | chain_targets, on_move_proc_frequency_pct, damage_vs_frozen_pct, barrier_refresh_rate_pct, reflect_damage_pct |

---

## Elemental Grid (Resist Tab)

```
┌───────────────────────────────────────────────────┐
│  Element      Resist    Damage    Duration        │
│  ─────────────────────────────────────────────────│
│  🔥 Fire        25%      +15%      +10%           │
│  ❄️ Cold        30%      +5%       +0%            │
│  ⚡ Lightning   15%      +20%      +5%            │
│  ☠️ Poison      40%      +0%       +25%           │
│  🩸 Bleed       --       +10%      +15%           │
│  ✨ Aether      20%      +0%       +0%            │
│  🌀 Chaos       10%      +5%       +0%            │
│  💀 Vitality    35%      +0%       +20%           │
│  🗡️ Physical   --       +25%      --             │
└───────────────────────────────────────────────────┘
```

### Data Source
Uses existing `snapshot.per_type` array:
- `resist` → Resist column
- `mod` → Damage column
- `duration` → Duration column

### Visual Rules
- `--` for N/A values
- Positive values: green, Negative: red, Zero: gray
- Element icons use element-specific colors

### Collapsible
Section header "Elemental Resists" can expand/collapse.

---

## Scroll Pane

### Implementation
Use `UIElementTemplateNodeBuilder` with `UITypeEnum.SCROLL_PANE`:

```lua
local scrollContent = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.SCROLL_PANE)
    :addConfig(
        UIConfigBuilder.create()
            :addMaxHeight(400)  -- viewport height
            :addPadding(4)
            :addColor(getColors().bg)
            :build()
    )
    :addChild(tier1Section)
    :addChild(tabContentSection)
    :build()
```

### Behavior
- Single scroll pane for entire panel content (Tier 1 + tabs)
- Tab bar and footer remain outside scroll area (fixed)
- Mouse wheel scrolls when hovering over panel

---

## Polish Features

### 1. Delta Display
Show buff/debuff modifier from base value:
```
│🛡️ Armor  120 (+35)│
```

- Snapshot captures both `current` and `base` values
- `formatStatValue()` returns delta string
- Delta colored green (+) or red (-)

### 2. Value Change Animations
- **Number tick**: Tween old → new (300-500ms)
- **Damage taken**: HP pill pulses red (200ms)
- **Heal/buff**: Pill pulses green (200ms)

Uses `timer.sequence()` and Text Builder animation effects.

### 3. Hover Tooltips
```
"Base: 30, Weapon: +10, Buff: +5"
```

Uses `tooltip_registry` with breakdown data from stats modifier stack.

### 4. Warning Pulse States
- **Low HP (<25%)**: HP pill pulses red continuously
- **Low MP (<10%)**: MP pill pulses blue continuously

Timer-based color cycling in `createStatPill()`.

### 5. Keyboard Navigation
- `C` - Toggle panel
- `Tab` - Cycle tabs
- `1-5` - Jump to specific tab
- `Esc` - Close panel

---

## Hybrid Rebuild Architecture

### Static vs Dynamic Parts

```
┌─────────────────────────────────────────┐
│ STATIC (never destroyed)               │
│  - Panel root entity                    │
│  - Header                               │
│  - Tier 1 section                       │
│  - Tab bar                              │
│  - Footer                               │
├─────────────────────────────────────────┤
│ DYNAMIC (swapped on tab change)         │
│  - Tab content container                │
│  - Tab sections + stat pills            │
└─────────────────────────────────────────┘
```

### State Structure
```lua
StatsPanel._state = {
    -- Existing
    visible = true,
    slideProgress = 1,
    currentTab = 1,
    expandedSections = {},
    snapshot = {...},

    -- NEW: entity references for partial rebuild
    panelEntity = <root>,
    tier1Entity = <tier1 container>,
    tabContentEntity = <swappable area>,
    tabBarEntity = <tab bar>,
}
```

### Rebuild Functions
```lua
-- Full rebuild (show/hide or snapshot hash change)
function StatsPanel._createPanel()
    -- Creates everything, stores entity refs
end

-- Partial rebuild (tab switch or section collapse)
function StatsPanel._rebuildTabContent()
    -- Destroy only tabContentEntity children
    -- Recreate tab content
    -- Reattach to panel
end

-- Value update (stat changes during gameplay)
function StatsPanel._updateValues()
    -- Update text values in-place via ui.box API
    -- Trigger animations for changed values
end
```

---

## Implementation Notes

### Files to Modify
| File | Changes |
|------|---------|
| `assets/scripts/ui/stats_panel.lua` | Complete rewrite: panel structure, hybrid rebuild, scroll pane |
| `assets/scripts/core/gameplay.lua` | Update `collectPlayerStatsSnapshot()` for base values (deltas) |

### Key Implementation Steps
1. Refactor `_createPanel()` to store entity refs for static vs dynamic parts
2. Add `_rebuildTabContent()` for partial rebuilds
3. Expand TIER1_STATS to all 21 BASIC_STATS with 6 category groups
4. Add missing stats to TAB_LAYOUTS (block_recovery_reduction_pct, min_resist_cap_pct, health_pct)
5. Build elemental grid using hbox/vbox pattern
6. Wrap content in SCROLL_PANE via UIElementTemplateNodeBuilder
7. Implement delta display in `formatStatValue()`
8. Add value change detection + animation triggers
9. Add hover tooltips via tooltip_registry
10. Implement warning pulse for low HP/MP

---

## Success Criteria

1. **All 21 BASIC_STATS visible** in Tier 1 (6 always-expanded categories)
2. **All DETAILED_STATS accessible** via 5 tabs (including 3 missing stats)
3. **Tab switching is flicker-free** (hybrid rebuild only swaps tab content)
4. **Scroll pane works** for panel content overflow
5. **Elemental grid** displays Resist/Damage/Duration per element
6. **Polish features working**: delta display, value animations, hover tooltips, warning pulses, keyboard nav

### Testing Checklist
- [ ] Press C → panel slides in with all 21 Tier 1 stats
- [ ] Switch tabs → no flicker, content swaps smoothly
- [ ] Scroll → content scrolls within viewport
- [ ] Collapse section → only tab content rebuilds
- [ ] Take damage → HP pill pulses red, value animates
- [ ] Hover stat → tooltip shows breakdown
- [ ] Low HP (<25%) → HP pulses continuously
- [ ] All keyboard shortcuts work (C, Tab, 1-5, Esc)

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
