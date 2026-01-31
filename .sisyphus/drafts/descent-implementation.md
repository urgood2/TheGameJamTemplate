# Draft: Descent (Game #1) Implementation Plan

## Context
- **Source Document**: `/Users/joshuashin/.superset/worktrees/TheGameJamTemplate/urgood2/roguelike-master-plan/.sisyphus/plans/roguelike-prototypes-design.md`
- **Game**: "Descent" - DCSS-lite Traditional Roguelike
- **Target Session**: 15-20 minutes
- **Core Loop**: Turn-based dungeon crawler, 5 floors, defeat boss

## Requirements (from Master Design)

### Confirmed from Design Doc
- **Species**: 4 (Human, Minotaur, Deep Elf, Troll)
- **Backgrounds**: 4 (Gladiator, Monk, Ice Elementalist, Artificer)
- **Gods**: 5 in pool, 3 random per run (Trog, Vehumet, Makhleb, Gozag, Elyvilon)
- **Floors**: 5 (boss on floor 5)
- **Spells**: 12 total
- **Weapons**: 8 types
- **Armor**: 4 slots
- **Consumables**: 5 types (no hunger)
- **Enemies**: 15 types (including miniboss + boss)

### Design Axes
- **Scarcity**: SCARCE (every item matters)
- **Information**: LEARNABLE (item identification)
- **Skill/Build**: KNOWLEDGE-dominant (knowing interactions wins)
- **Run Identity**: EMERGENT (builds emerge from findings)

## Technical Decisions
- **Engine**: Uses existing C++20/Lua engine
- **Rendering**: ASCII/CP437 aesthetic (tileset exists: `cp437_20x20_sprites.json`)
- **Turn System**: Needs implementation (1 action per turn)
- **FOV System**: Needs implementation (see current room)

## Answered Questions

### Test Strategy
- **Decision**: TDD with engine-appropriate test framework
- **Action**: Set up test infrastructure as part of plan

### Tileset Source
- **Decision**: Use dedicated tileset from `/Users/joshuashin/Projects/roguelike-sim-incremental/assets/graphics/pre-packing-files_globbed/dungeon_mode`
- **Note**: This is DIFFERENT from the CP437 tileset - need to verify asset compatibility

### Dungeon Generation
- **Decision**: Template + Variation Hybrid
- **Rationale**: Hand-crafted room templates with procedural enemy/item placement. Best of both worlds.

### Item Identification
- **Decision**: Simple Identification (Scrolls Only)
- **Rationale**: Scrolls have random names until used/identified. Adds knowledge element without excessive complexity.

### Combat Visual Feedback
- **Decision**: Instant + Flash/Shake
- **Rationale**: State changes instantly, but brief screen shake and color flash on hits. Uses existing HitFX system.

### Session Persistence
- **Decision**: Truly Ephemeral
- **Rationale**: Close app = lose run. Simplest, forces commitment to 15-20 min session.

### Turn System Architecture
- **Decision**: State Machine
- **Rationale**: Game states: PLAYER_TURN, ENEMY_TURN, ANIMATING. Real-time loop checks state, processes accordingly.

### FOV System
- **Decision**: Shadowcasting
- **Rationale**: True roguelike FOV algorithm (recursive shadowcasting). More authentic, worth the complexity.

### Shop System
- **Decision**: Dynamic Stock + Reroll
- **Rationale**: Random stock, pay to reroll. More roguelike-y, adds strategic depth.

### Spell Selection UI
- **Decision**: Modal Card Selection
- **Rationale**: Pause game, show 3 spell cards with descriptions, pick one. Clean, standard roguelike.

### Content Scope Strategy
- **Decision**: Minimal First (MVP Approach)
- **Initial Scope**:
  - 1 species (Human - baseline)
  - 1 background (Gladiator - simple melee)
  - 1 god (Trog - straightforward rage mechanics)
  - 3 spells (basic attack, heal, utility)
  - 5 enemies (Rat, Goblin, Skeleton, Orc, Boss placeholder)
- **Expansion**: Add remaining content after core loop proven

### Tileset Integration (from Metis)
- **Decision**: Copy to This Project
- **Action**: Copy sprites from `/Users/joshuashin/Projects/roguelike-sim-incremental/assets/graphics/pre-packing-files_globbed/dungeon_mode/` to this worktree's `/assets/graphics/`

### FOV Integration (from Metis)
- **Decision**: Expose C++ FOV to Lua
- **Action**: Create Lua bindings for existing `MyVisibility::Compute()` in `/src/systems/line_of_sight/`

### Input Keys (from Metis)
- **Decision**: WASD + Numpad Only
- **Rationale**: Modern WASD plus numpad for diagonals. Simpler, more accessible.

### Room Templates (from Metis)
- **Decision**: Agent Generates Starter Templates
- **Action**: Implementation agent creates ~10 basic room templates (rectangular, L-shapes, corridors)

## Metis Findings - Existing Systems to Reuse

| System | Location | Status |
|--------|----------|--------|
| FOV/Shadowcasting | `/src/systems/line_of_sight/` | Needs Lua bindings |
| Grid/Tile System | `TileComponent`, `LocationComponent` | Available |
| Dungeon Generation | `/assets/scripts/core/procgen/dungeon.lua` | Use as foundation |
| Inventory System | `/assets/scripts/core/inventory_grid.lua` | Available |
| Equipment System | `/assets/scripts/data/equipment.lua` | Available |
| Input System | `/src/systems/input/` | Needs "roguelike" context |
| HitFX | `/assets/scripts/core/hitfx.lua` | Available |
| Pathfinding | `fudge_pathfinding` | Available |

## Metis Directives

### MUST DO
- Copy tileset BEFORE any rendering work
- Create new Lua module `descent/` - do NOT modify existing gameplay.lua
- Use existing FOV system - do NOT reimplement shadowcasting
- Create new input context `"roguelike"` - do NOT modify `"gameplay"` context
- Use existing `DungeonBuilder` as foundation

### MUST NOT DO
- Add animations (instant state changes + HitFX flash only)
- Implement save/load (ephemeral sessions)
- Add mouse support (keyboard only)
- Touch existing combat/wand system (create separate turn-based combat)
- Exceed MVP content scope

## Open Questions

### Remaining
- None - all key decisions made, ready for plan generation

## Research Findings

### Engine Capabilities (from exploration)
- Has existing turn-based concepts in AI system
- Has physics/collision system (Chipmunk)
- Has UI DSL for declarative UI
- Has timer system for sequences
- Has existing CP437 tileset (20x20 sprites)
- Has layer/z-ordering system

## Scope Boundaries

### INCLUDE (from design doc)
- Character creation (species + background)
- Turn-based movement and combat
- 5-floor dungeon
- God system (3 random per run)
- Item/equipment system
- Level-up system
- Boss fight
- Victory/death screens

### EXCLUDE (guardrails from design doc)
- No meta-progression
- No autoexplore
- No hunger system
- No dungeon branches
- No inventory tetris
- No animations (instant state changes)
- No mouse support (keyboard only)
- No save/load within runs
