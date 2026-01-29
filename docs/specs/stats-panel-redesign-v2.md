# Stats Panel Redesign v2

## Overview

Replace the current tabbed stats panel with a simpler, streamlined single-scroll design that:
- Shows all stats from both "Basic Stats" and "Detailed Stats" tooltips in one view
- Uses efficient caching with in-place element updates (no full rebuilds while visible)
- Provides clean, readable layout with full-width rows and section headers

## Design Decisions (Interview Summary)

| Aspect | Decision |
|--------|----------|
| Organization | Grouped by category with icon+label section headers |
| Rebuild trigger | Only on toggle open; in-place updates while visible |
| Zero handling | Show all categories; individual stats at 0 still visible |
| Update method | ID-based text swap via `ui.box.GetUIEByID` |
| Delta display | Inline: "50 (+10)" with colored delta |
| Viewport height | Dynamic: 70% of screen height |
| Row layout | Full-width rows (label left, value right-aligned) |
| Header style | Sprite icon + text label |
| Color coding | Green for positive, red for negative, white/gray for zero |
| Elemental stats | Keep as compact grid table |
| Position | Right sidebar slide-in (unchanged) |
| Tooltips | Detailed breakdown on hover (base + modifiers) |
| Category order | Combat → Resist → Mods → DoTs → Utility |
| Panel header | Title + Level/XP progress |
| Icons | Use existing sprite icons from atlas |
| Shortcuts | C toggle, Esc close (simplified) |
| Update timing | Event-driven via `stats_recomputed` signal |

---

## Visual Layout

```
┌─────────────────────────────────────┐
│ Character Stats          Lv.15     │ ← Header with level
│ ████████████░░░░░░░  2450/5000 XP  │ ← XP progress bar
├─────────────────────────────────────┤
│ ⚔️ COMBAT                           │ ← Section header (icon + label)
├─────────────────────────────────────┤
│ Offensive Ability      125 (+15)   │ ← Full-width row
│ All Damage             +12%        │
│ Weapon Damage          +8%         │
│ Crit Damage            +45%        │
│ Life Steal             +3%         │
│ Attack Speed           1.2/s       │
│ Cast Speed             1.0/s       │
│ Cooldown Reduction     15%         │
│ Melee Damage           +5%         │
│ Melee Crit             +2%         │
├─────────────────────────────────────┤
│ 🛡️ RESIST                           │
├─────────────────────────────────────┤
│ Defensive Ability      98          │
│ Armor                  45 (+20)    │
│ Dodge Chance           8%          │
│ Block Chance           5%          │
│ Block Amount           12          │
│ Damage Reduction       0%          │ ← Gray for zero
│ ... etc ...                        │
├─────────────────────────────────────┤
│ ⚡ ELEMENTS                          │ ← Special grid section
├─────────────────────────────────────┤
│          Resist  Damage  Duration  │
│ 🔥 Fire    +15%   +10%     0%      │
│ ❄️ Cold    +5%    +3%      0%      │
│ ⚡ Light   0%     +25%     +5%     │
│ ... etc ...                        │
├─────────────────────────────────────┤
│ 💀 DOTS                              │
├─────────────────────────────────────┤
│ ... etc ...                        │
├─────────────────────────────────────┤
│ ⚙️ UTILITY                           │
├─────────────────────────────────────┤
│ ... etc ...                        │
├─────────────────────────────────────┤
│         C: toggle   Esc: close     │ ← Footer
└─────────────────────────────────────┘
```

---

## Section Definitions

### Header Section
- **Title**: "Character Stats"
- **Level display**: "Lv.15" right-aligned
- **XP bar**: Small progress bar showing XP/XP_to_next

### Combat Section (⚔️)
Stats from `TAB_LAYOUTS.combat` + `TIER1_GROUPS.offense`:
- offensive_ability
- all_damage_pct
- weapon_damage_pct
- crit_damage_pct
- life_steal_pct
- attack_speed
- cast_speed
- cooldown_reduction
- melee_damage_pct
- melee_crit_chance_pct
- penetration_all_pct
- armor_penetration_pct

### Resist Section (🛡️)
Stats from `TAB_LAYOUTS.resist` + `TIER1_GROUPS.defense`:
- defensive_ability
- armor
- dodge_chance_pct
- block_chance_pct
- block_amount
- block_recovery_reduction_pct
- percent_absorb_pct
- flat_absorb
- armor_absorption_bonus_pct
- damage_taken_reduction_pct
- reflect_damage_pct
- max_resist_cap_pct
- min_resist_cap_pct
- barrier_refresh_rate_pct

### Elements Section (⚡)
Grid format from `buildElementalResistGrid`:

| Element | Resist | Damage | Duration |
|---------|--------|--------|----------|
| Fire | X% | X% | X% |
| Cold | X% | X% | X% |
| Lightning | X% | X% | X% |
| Acid | X% | X% | X% |
| Vitality | X% | X% | X% |
| Aether | X% | X% | X% |
| Chaos | X% | X% | X% |
| Physical | -- | X% | -- |
| Pierce | -- | X% | -- |

### DoTs Section (💀)
Stats from `TAB_LAYOUTS.dots`:
- burn_damage_pct
- burn_tick_rate_pct
- burn_duration_pct
- frostburn_duration_pct
- electrocute_duration_pct
- poison_duration_pct
- max_poison_stacks_pct
- vitality_decay_duration_pct
- bleed_duration_pct
- trauma_duration_pct
- damage_vs_frozen_pct

### Utility Section (⚙️)
Stats from `TAB_LAYOUTS.utility` + `TIER1_GROUPS`:
- run_speed
- move_speed_pct
- skill_energy_cost_reduction
- experience_gained_pct
- healing_received_pct
- health_pct
- health_regen
- buff_duration_pct
- buff_effect_pct
- summon_hp_pct
- summon_damage_pct
- summon_persistence
- hazard_radius_pct
- hazard_damage_pct
- hazard_duration
- chain_targets
- on_move_proc_frequency_pct

---

## Caching Strategy

### Element ID Schema

Every updateable element gets a unique ID for in-place updates:

```lua
-- Section headers (static, no ID needed)
-- Stat value elements:
"stat_value_{statKey}"        -- e.g., "stat_value_armor"
"stat_delta_{statKey}"        -- e.g., "stat_delta_armor"

-- Elemental grid cells:
"elem_{type}_{column}"        -- e.g., "elem_fire_resist", "elem_cold_damage"

-- Header elements:
"header_level"
"header_xp_bar"
"header_xp_text"
```

### Update Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      PANEL LIFECYCLE                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  User presses 'C'                                           │
│       │                                                     │
│       ▼                                                     │
│  ┌─────────────────┐                                        │
│  │ StatsPanel.show │                                        │
│  │  - collect snapshot                                      │
│  │  - build full UI tree                                    │
│  │  - spawn via dsl.spawn()                                 │
│  │  - register signal handler                               │
│  └─────────────────┘                                        │
│       │                                                     │
│       ▼                                                     │
│  Panel visible, slide-in animation                          │
│       │                                                     │
│       ▼                                                     │
│  ┌─────────────────────────────────────┐                    │
│  │ Signal: "stats_recomputed" fires    │ ◄── Event-driven  │
│  │  - collect new snapshot             │                    │
│  │  - diff against cached snapshot     │                    │
│  │  - for each changed stat:           │                    │
│  │      GetUIEByID("stat_value_X")     │                    │
│  │      update text/color in-place     │                    │
│  │  - update cached snapshot           │                    │
│  └─────────────────────────────────────┘                    │
│       │                                                     │
│       ▼                                                     │
│  User presses 'C' or 'Esc'                                  │
│       │                                                     │
│       ▼                                                     │
│  ┌─────────────────┐                                        │
│  │ StatsPanel.hide │                                        │
│  │  - unregister signal                                     │
│  │  - slide-out animation                                   │
│  │  - destroy panel entity                                  │
│  └─────────────────┘                                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### In-Place Update Implementation

```lua
-- Called when stats_recomputed signal fires
function StatsPanel._onStatsChanged()
    local newSnapshot = StatsPanel._collectSnapshot()
    local oldSnapshot = StatsPanel._state.snapshot

    -- Diff and update only changed stats
    for statKey, newValue in pairs(newSnapshot) do
        if statKey ~= "per_type" and oldSnapshot[statKey] ~= newValue then
            StatsPanel._updateStatValue(statKey, newValue, newSnapshot)
        end
    end

    -- Update elemental grid if per_type changed
    if newSnapshot.per_type then
        StatsPanel._updateElementalGrid(newSnapshot.per_type, oldSnapshot.per_type)
    end

    -- Update header (level/xp)
    StatsPanel._updateHeader(newSnapshot)

    StatsPanel._state.snapshot = newSnapshot
end

function StatsPanel._updateStatValue(statKey, value, snapshot)
    local state = StatsPanel._state
    if not state.panelEntity then return end

    -- Update value text
    local valueId = "stat_value_" .. statKey
    local valueEntity = ui.box.GetUIEByID(registry, state.panelEntity, valueId)
    if valueEntity and entity_cache.valid(valueEntity) then
        local formatted = formatStatValue(statKey, value, snapshot, false)
        local uiText = component_cache.get(valueEntity, UITextComponent)
        if uiText then
            uiText.text = formatted
            uiText.color = getValueColor(value)
        end
    end

    -- Update delta text if present
    local deltaId = "stat_delta_" .. statKey
    local deltaEntity = ui.box.GetUIEByID(registry, state.panelEntity, deltaId)
    if deltaEntity and entity_cache.valid(deltaEntity) then
        local baseValue = getStatBaseValue(statKey)
        local delta = baseValue and (value - baseValue) or nil
        local deltaStr = formatDelta(delta)
        local uiText = component_cache.get(deltaEntity, UITextComponent)
        if uiText then
            uiText.text = deltaStr or ""
            uiText.color = delta and (delta > 0 and util.getColor("mint_green") or util.getColor("fiery_red")) or nil
        end
    end
end
```

---

## Icon Mapping

Map section IDs to existing sprite assets:

```lua
local SECTION_ICONS = {
    combat = "icon_sword",       -- or existing combat icon
    resist = "icon_shield",      -- or existing defense icon
    elements = "icon_lightning", -- or existing element icon
    dots = "icon_skull",         -- or existing poison/status icon
    utility = "icon_gear",       -- or existing utility icon
}
```

**TODO**: Verify actual icon sprite names in atlas. Fallback to emoji if not found:
- ⚔️ Combat
- 🛡️ Resist
- ⚡ Elements
- 💀 DoTs
- ⚙️ Utility

---

## Implementation Plan

### Phase 1: Core Structure
1. Create new `stats_panel_v2.lua` (or modify existing)
2. Define `SECTIONS` table with all stats per section
3. Build scroll pane with dynamic height (70% screen)
4. Implement full-width row builder with ID assignment

### Phase 2: In-Place Updates
1. Register handler for `stats_recomputed` signal
2. Implement `_onStatsChanged()` diffing logic
3. Implement `_updateStatValue()` for in-place text changes
4. Implement `_updateElementalGrid()` for grid cells

### Phase 3: Visual Polish
1. Add section icons (sprites or emoji fallback)
2. Style header with level/XP
3. Color-code values (green/red/gray)
4. Add hover tooltips with breakdown

### Phase 4: Integration
1. Wire up 'C' key toggle
2. Ensure Esc closes panel
3. Test scroll behavior
4. Remove old tabbed panel code (or keep as legacy option)

---

## Files to Modify

| File | Changes |
|------|---------|
| `assets/scripts/ui/stats_panel.lua` | Major rewrite or replace |
| `assets/scripts/core/gameplay.lua` | Ensure `stats_recomputed` signal fires |
| `src/systems/input/input_lua_bindings.cpp` | May need `clearActiveScrollPane` if scroll issues persist |

---

## Success Criteria

1. **Single scroll view**: All stats visible without tabs
2. **No rebuild on stat change**: In-place updates only
3. **Clean layout**: Full-width rows, clear section headers
4. **Responsive**: Event-driven updates, no polling lag
5. **Readable**: Color-coded, deltas visible, tooltips on hover
6. **Performant**: No frame drops when stats change

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| GetUIEByID performance with many elements | Cache entity references after spawn |
| UITextComponent not exposed to Lua | Verify binding exists; add if needed |
| Scroll position lost on resize | Re-clamp offset after viewport change |
| Icon sprites missing | Use emoji fallback with feature flag |

---

## Open Questions

1. **Vitals section**: Should HP/Health/Health Regen have special treatment at top? (Currently in Utility per tab order)
2. **Attributes section**: Include Physique/Cunning/Spirit prominently or fold into relevant sections?
3. **Damage range**: Show "weapon_min - weapon_max" as range or omit?

---

## Appendix: All Stats Reference

### From BASIC_STATS (21 stats)
```lua
"level", "health", "health_regen", "xp",
"physique", "cunning", "spirit",
"offensive_ability", "defensive_ability",
"damage", "attack_speed", "cast_speed",
"cooldown_reduction", "skill_energy_cost_reduction",
"all_damage_pct", "life_steal_pct", "crit_damage_pct",
"dodge_chance_pct", "armor",
"run_speed", "move_speed_pct"
```

### From DETAILED_STATS (45+ stats)
```lua
"experience_gained_pct", "weapon_damage_pct",
"block_chance_pct", "block_amount", "block_recovery_reduction_pct",
"percent_absorb_pct", "flat_absorb", "armor_absorption_bonus_pct",
"healing_received_pct", "reflect_damage_pct",
"penetration_all_pct", "armor_penetration_pct",
"max_resist_cap_pct", "min_resist_cap_pct", "damage_taken_reduction_pct",
"burn_damage_pct", "burn_tick_rate_pct", "damage_vs_frozen_pct",
"buff_duration_pct", "buff_effect_pct",
"chain_targets", "on_move_proc_frequency_pct",
"hazard_radius_pct", "hazard_damage_pct", "hazard_duration",
"max_poison_stacks_pct",
"summon_hp_pct", "summon_damage_pct", "summon_persistence",
"barrier_refresh_rate_pct", "health_pct", "melee_damage_pct", "melee_crit_chance_pct",
-- Elemental modifiers
"fire_modifier_pct", "cold_modifier_pct", "lightning_modifier_pct",
"acid_modifier_pct", "vitality_modifier_pct", "aether_modifier_pct", "chaos_modifier_pct",
"physical_modifier_pct", "pierce_modifier_pct",
-- DoT durations
"burn_duration_pct", "frostburn_duration_pct", "electrocute_duration_pct",
"poison_duration_pct", "vitality_decay_duration_pct", "bleed_duration_pct", "trauma_duration_pct"
```

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
