# Draft: Serpent (Game #2) - SNKRX-Style Survivor Implementation

## Requirements (confirmed)

- **Game**: "Serpent" - SNKRX-style survivor roguelite
- **Theme**: Abstract/arcade (simple shapes, neon colors)
- **Timing**: Real-time (continuous action)
- **Party**: Snake of 3-8 units
- **Session**: 10-15 minutes
- **Win Condition**: Survive wave 20
- **Lose Condition**: All units die

## Design Axes (from master design doc)

| Axis | Value |
|------|-------|
| Scarcity | ABUNDANT |
| Reversibility | Sellable (50% value) |
| Information | Transparent |
| Negative Acquisition | None |
| Skill/Build Ratio | BUILD-dominant |
| Run Identity | EARLY-CRYSTALLIZING |

## Technical Decisions

### Engine Systems to Use
- **Physics**: Chipmunk2D via `physics.*` API for snake movement, collision
- **Combat**: Existing composable effects system for damage, healing, DoTs
- **Steering**: `steering.*` API for snake head movement (player-controlled)
- **Timers**: For cooldowns, wave spawning
- **UI**: Existing UI DSL for shop, HUD, synergy display
- **Particles**: For visual effects (attacks, deaths)

### Content Quotas (from master doc)
- **Classes**: 4 (Warrior, Mage, Ranger, Support)
- **Units**: 16 total (4 per class, across 4 tiers)
- **Synergy Thresholds**: 2 and 4 units per class
- **Enemies**: 11 types (9 regular + 2 bosses)
- **Waves**: 20 total
- **Max Snake Size**: 8 units

### Stat Formulas (from SNKRX research)
```lua
HP = Base_HP × 2^(Level - 1)
Attack = Base_Attack × 2^(Level - 1)
-- Level 2 = 2x stats, Level 3 = 4x stats (cap)
```

## Scope Boundaries

### INCLUDE
- Snake movement (player controls head, body follows)
- Auto-attack combat (units attack nearest enemy)
- 16 units across 4 classes, 4 tiers
- Shop system (buy, sell, reroll)
- Class synergy bonuses at 2/4 thresholds
- Unit leveling (3 copies → level up)
- 20 waves with scaling difficulty
- 2 boss fights (waves 10, 20)
- Gold economy with wave rewards
- Basic death/victory screens

### EXCLUDE (guardrails from master doc)
- No items in shop (units only)
- No interest mechanic
- No unit repositioning in snake
- No meta-progression
- No save/load mid-run
- No difficulty modes
- No sound design (placeholder only)
- No controller support

## Research Findings

### Existing Engine Capabilities
1. **Physics System**: Full Chipmunk2D integration with collision callbacks, steering behaviors
2. **Combat System**: EventBus, Effects, Targeters, Statuses, DoTs already implemented
3. **Leveling System**: XP curves and OnLevelUp events available
4. **UI System**: DSL for building complex UIs, layouts, buttons

### Files to Reference
- `docs/snkrx_research/Summary.md` - Complete SNKRX analysis
- `docs/snkrx_research/Units.md` - Unit abilities
- `docs/snkrx_research/Classes.md` - Synergy details
- `docs/api/physics_docs.md` - Physics/steering API
- `docs/systems/combat/README.md` - Combat system

## Open Questions

1. **Test Infrastructure**: Does the project have test setup for Lua game code?
2. **Folder Structure**: Where should Serpent-specific Lua files live? (e.g., `assets/scripts/serpent/`)
3. **Wave Timing**: How long should each wave last before timing out? (design doc says 30-60 seconds)

## Test Strategy Decision

- **Infrastructure exists**: YES (see `tests/` directory, GoogleTest for C++)
- **Lua tests**: To be determined - need to check if there's a Lua test framework
- **User wants tests**: TBD - needs confirmation
- **QA approach**: Likely TDD for core mechanics if framework exists, otherwise manual verification via Playwright/gameplay

## Implementation Order (recommended from master doc)

Master doc recommends building Serpent LAST (4th) because it's real-time and different paradigm.
However, since user is asking specifically for Serpent, we proceed with it.

## Wave-by-Wave Structure

| Wave | Enemies | Special |
|------|---------|---------|
| 1-5 | Slimes, Bats, Goblins | Tutorial-ish |
| 6-9 | Orcs, Skeletons, Wizards | Mixed |
| 10 | **BOSS: Swarm Queen** (500 HP) | Spawns 5 slimes every 10s |
| 11-15 | Trolls, Demons, Dragons | Hard |
| 16-19 | All enemy types, scaled | Very hard |
| 20 | **BOSS: Lich King** (800 HP) | Raises dead as skeletons |

## Gold Economy

```lua
Base_Gold = 10 + Wave × 2
Bonus_Gold = 1 per enemy killed above minimum
Reroll_Cost = 2g (increases by 1g each reroll that wave)
Sell_Value = 50% of purchase price
```
