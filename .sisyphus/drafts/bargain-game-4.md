# Draft: Game #4 "Bargain" - Faustian Deal Roguelike

## Source Document
From `/roguelike-master-plan/.sisyphus/plans/roguelike-prototypes-design.md`

## High-Level Design (From Master Plan)

### Overview
| Attribute | Value |
|-----------|-------|
| **Genre** | Risk/reward deal roguelike |
| **Theme** | Dark fantasy / Seven Deadly Sins |
| **Timing** | Turn-based combat |
| **Party** | Solo character |
| **Session** | 10-15 minutes |
| **Win Condition** | Defeat the Sin Lord on Floor 7 |
| **Lose Condition** | HP reaches 0 |

### Design Axes
| Axis | Value | Rationale |
|------|-------|-----------|
| Negative Acquisition | FORCED/COUPLED | Every deal has a downside |
| Reversibility | PERMANENT | Deals cannot be undone |
| Run Identity | EMERGENT | Build emerges from deal choices |
| Skill/Build Ratio | BALANCED | Combat execution + deal strategy |

### Content Quotas (From Master Plan)
- 7 Sins (entities offering deals)
- 21 Deals total (3 per sin)
- 7 Floors
- 11 Enemy types (including Sin Lord boss)
- ~10-12 deal opportunities per run
- 10-15 minute session target

---

## Engine Research Findings

### Combat Systems Available
**Primary (Recommended):** `assets/scripts/combat/combat_system.lua`
- Event-driven framework (OnCast, OnHitResolved, OnStatusExpired, OnDeath)
- Effects system: `deal_damage`, `apply_dot`, `modify_stat`, `heal`, `grant_barrier`
- Combinators: `seq`, `chance`, `scale_by_stat`
- Status tracking with modes: replace, time_extend, count

**Legacy (Reference):** `todo_from_snkrx/done/`
- Has actual curse system with 6 curse types
- Damage multiplier cascading
- DoT and status effect implementation

### Dungeon/Floor Systems Available
- **DungeonBuilder:** BSP room generation in `assets/scripts/core/procgen/dungeon.lua`
- **Stage Providers:** Sequence/Endless/Hybrid in `assets/scripts/combat/stage_providers.lua`
- **Wave Director:** Floor orchestration in `assets/scripts/combat/wave_director.lua`
- **Enemy Factory:** Enemy creation in `assets/scripts/combat/enemy_factory.lua`

### UI Systems Available
- **Modal Dialogs:** `skill_confirmation_modal.lua` pattern - perfect for deal screens
- **Stat Displays:** `stats_panel.lua` with progress bars
- **DSL System:** `dsl.vbox`, `dsl.hbox`, `dsl.button`, `dsl.progressBar`

---

## Requirements (confirmed)

### Combat System
- **Grid-based with FOV** - Tactical positioning matters, line of sight
- **Basic 4 actions**: Move, Attack, Use Item, Wait
- Uses existing combat_system.lua event-driven framework

### Visual Style  
- **Dungeon Mode Sprite Set** from `/roguelike-sim-incremental/assets/graphics/pre-packing-files_globbed/dungeon_mode/`
- 256 sprites including: heroes, enemies, items, terrain, UI elements
- Perfect for roguelike visuals - dm_144-159 are character/enemy sprites
- Dark fantasy theme with sin-colored tinting (gold, red, green, purple, etc.)

### Deal Mechanics
- **Simple as designed**: 21 deals, each with fixed benefit + downside
- No synergies, additive stacking only
- Floor-start deals are forced, level-up deals can be refused

## Technical Decisions

### Combat Architecture
- Grid-based movement on tile grid (likely 10x10 to 15x15 per floor)
- Turn order: Speed-based (higher speed acts first)
- FOV/visibility system needed for tactical play
- Use combat_system.lua Effects + EventBus for damage/stat modifications

### Deal System Architecture  
- Deals as stat modifiers applied to player entity
- Track active deals in player state for UI display
- Benefits: `Effects.modify_stat` with permanent duration
- Downsides: Permanent stat penalties or gameplay constraints

### Floor Progression
- 7 floors with increasing size and difficulty
- Use DungeonBuilder for procedural room generation
- Stage-based progression (not wave-based)

## Open Questions
All questions resolved ✓

## Technical Decisions (continued)

### Deal Timing
- **Floor start**: Forced - player must accept 1 deal from random Sin
- **Level-up**: Choice - player sees 2 deals from random Sins, can skip both
- ~10-12 deal opportunities per run as per master plan

### Enemy AI
- **Simple chase + attack** behavior
- Move toward player using Manhattan distance
- Attack when adjacent (melee) or in range (ranged)
- Different speeds create tactical variety
- No complex pathfinding needed

### Test Strategy
- **TDD workflow**: RED-GREEN-REFACTOR
- Write failing tests first for core systems
- Test files alongside implementation
- Focus on: combat formulas, deal application, floor progression

## Scope Boundaries
- **INCLUDE**: 
  - Grid-based turn combat with FOV
  - 7 Sins offering 21 deals
  - 7 floors + Sin Lord boss
  - 11 enemy types
  - HP/stat bars, deal list UI
  - Deal selection modal
  - TDD test coverage
- **EXCLUDE**: (from master plan)
  - No achievements
  - No meta-progression  
  - No save/load mid-run
  - No difficulty modes
  - No multiplayer
  - No deal synergies (downsides don't compound)
  - No item drops (deals are only power source)
  - Cannot refuse floor-start deals
  - No complex enemy AI/pathfinding

---

## Interview Progress
- [x] Combat system depth clarified → Grid-based with FOV, 4 actions
- [x] Visual/aesthetic direction confirmed → Dungeon Mode sprites
- [x] Turn-based mechanics detailed → Speed-based turns, simple chase AI
- [x] Deal system mechanics confirmed → Floor-start forced, level-up optional
- [x] Enemy behavior expectations set → Simple chase + attack
- [x] Test strategy decided → TDD workflow
