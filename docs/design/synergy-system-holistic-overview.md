# Holistic System Architecture: Synergies + Cards + Jokers + Avatars

> Generated: 2026-01-05
> Purpose: Comprehensive overview of how the four core progression systems interact

## System Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DECK COMPOSITION                                   │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐           │
│  │ Fireball│  │ Burn Mod│  │ Fire Mod│  │Chain Lit│  │ Ice Bolt│           │
│  │ Fire x1 │  │ Fire x1 │  │ Fire x1 │  │Light x1 │  │ Ice x1  │           │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘  └─────────┘           │
└───────────────────────────────┬─────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         TAG EVALUATION                                       │
│                                                                              │
│   TagEvaluator.count_tags(deck) → { Fire: 3, Lightning: 1, Ice: 1 }        │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │ SYNERGY BREAKPOINTS ACTIVATED:                                      │   │
│   │  • Fire [3] ✓ → +10% burn_damage_pct                                │   │
│   │  • Fire [5] ○ → (need 2 more Fire cards)                            │   │
│   │  • Fire [7] ○ → (need 4 more for burn_explosion_on_kill)            │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │ AVATAR UNLOCK CHECK:                                                │   │
│   │  • Wildfire: Need 7 Fire tags OR 100 fire kills (currently 3/7)    │   │
│   │  • Stormlord: Need 7 Lightning tags (currently 1/7)                 │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
└───────────────────────────────┬─────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CAST EXECUTION                                       │
│                                                                              │
│  1. Trigger fires (timer/collision/dash/etc.)                               │
│  2. WandExecutor evaluates cast block                                        │
│  3. Modifier cards aggregate properties                                      │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ JOKER EVALUATION:                                                    │   │
│  │                                                                      │   │
│  │  Context passed to each joker:                                       │   │
│  │  {                                                                   │   │
│  │    event: "on_spell_cast",                                           │   │
│  │    spell_type: "Twin Cast",                                          │   │
│  │    tags: { Fire: true, Projectile: true },                           │   │
│  │    tag_analysis: { primary_tag: "Fire", is_mono_tag: true },         │   │
│  │    player: { tag_counts: { Fire: 3, ... } }                          │   │
│  │  }                                                                   │   │
│  │                                                                      │   │
│  │  Pyromaniac checks: is_mono_tag && tags.Fire? → +10 damage_mod      │   │
│  │  Tag Master checks: total tags → +3% damage_mult                    │   │
│  │                                                                      │   │
│  │  Aggregated: { damage_mod: 10, damage_mult: 1.03 }                  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ AVATAR RULE CHECK:                                                   │   │
│  │                                                                      │   │
│  │  if AvatarSystem.has_rule(player, "multicast_loops") then            │   │
│  │    -- Wildfire: Execute multicast sequentially instead of parallel   │   │
│  │  end                                                                 │   │
│  │                                                                      │   │
│  │  if AvatarSystem.has_rule(player, "missing_hp_dmg") then             │   │
│  │    -- Bloodgod: +1% damage per 1% missing HP                         │   │
│  │  end                                                                 │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  4. Final modifiers applied to projectile spawn                              │
│  5. Projectile deals: base_damage × synergy_buffs × joker_mults × avatar    │
└─────────────────────────────────────────────────────────────────────────────┘
```

## System Interaction Matrix

| System | Affects Cards | Affects Synergies | Affects Jokers | Affects Avatars |
|--------|--------------|-------------------|----------------|-----------------|
| **Cards** | — | Tags contribute to counts | Tags passed to context | Tags unlock avatars |
| **Synergies** | Stat buffs modify damage | — | player.tag_counts readable | Tag thresholds unlock |
| **Jokers** | Modify cast output | Read tag_analysis | — | No direct interaction |
| **Avatars** | Rule changes modify execution | Stat buffs stack with synergies | No direct interaction | — |

## Example Build Archetypes

### 1. The Pyromaniac (Fire Focus)
```
Cards:     7+ Fire-tagged (Fireball, Explosive Fire, Burn Trail, etc.)
Synergies: Fire [7] → burn_explosion_on_kill proc
Jokers:    Pyromaniac (+10 dmg), Elemental Master (+35% from 7 Fire)
Avatar:    Wildfire (2x hazard tick rate, multicast loops)

Playstyle: Sustained burn damage, chain explosions, area denial
Power Fantasy: "Everything burns, and the burns spread"
```

### 2. The Storm Lord (Lightning Chain)
```
Cards:     7+ Lightning-tagged (Chain Lightning, Static Charge, Arc, etc.)
Synergies: Arcane [5] → cooldown restore on chain hits
Jokers:    Lightning Rod (+15 dmg + extra chain), Conductor (marks)
Avatar:    Stormlord (crits chain, chains apply marks, +2 chain bonus)

Playstyle: Screen-clearing chains that bounce through entire rooms
Power Fantasy: "Lightning strikes twice, then five more times"
```

### 3. The Glass Cannon (Bloodgod)
```
Cards:     Mixed high-damage cards, self-damage modifiers
Synergies: Brute [7] → +15% melee crit
Jokers:    Survival Instinct (+20% dmg after damage), Thorns
Avatar:    Bloodgod (+1% dmg per 1% missing HP, heal on kill)

Playstyle: Stay at low HP for massive damage, heal through kills
Power Fantasy: "Pain is power, death feeds life"
```

### 4. The Summoner (Voidwalker)
```
Cards:     Summon-tagged cards, projectile actions
Synergies: Summon [7] → +30% minion damage, persist between waves
Jokers:    Echo Chamber (twin casts), Combo Catalyst
Avatar:    Voidwalker (summons copy player projectiles!)

Playstyle: Army of minions that all cast your spells
Power Fantasy: "Why cast once when my army can cast with me?"
```

## Key Files Reference

| System | Data Definition | Core Logic | UI |
|--------|----------------|------------|-----|
| **Cards** | `data/cards.lua` | `wand/wand_executor.lua` | `ui/trigger_strip_ui.lua` |
| **Synergies** | `wand/tag_evaluator.lua` (TAG_BREAKPOINTS) | `wand/tag_evaluator.lua` | `ui/tag_synergy_panel.lua` |
| **Jokers** | `data/jokers.lua` | `wand/joker_system.lua` | `ui/avatar_joker_strip.lua` |
| **Avatars** | `data/avatars.lua` | `wand/avatar_system.lua` | `ui/avatar_joker_strip.lua` |

## Implementation Status

| System | Data | Logic | UI | Integration |
|--------|------|-------|-----|-------------|
| **Cards** | ✅ Complete | ✅ Complete | ✅ Complete | Fully integrated |
| **Synergies** | ✅ 10 tags defined | ✅ Breakpoints work | ✅ Panel shows progress | Fully integrated |
| **Jokers** | ✅ ~15 jokers | ✅ Event system works | ✅ Strip displays | Fully integrated |
| **Avatars** | ✅ 7 avatars | ⚠️ Partial (stat buffs work, rules stubbed) | ✅ Strip displays | Rules need implementation |

### Remaining Avatar Rule Implementation
- `multicast_loops` rule (Wildfire) - stub exists, needs logic
- `crit_chains` rule (Stormlord) - stub exists, needs logic
- `missing_hp_dmg` rule (Bloodgod) - stub exists, needs logic
- `summon_cast_share` rule (Voidwalker) - stub exists, needs logic
