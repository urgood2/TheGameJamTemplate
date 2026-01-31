# Draft: Expedition Master Plan (Game #3)

## Source Document Reference
The master design document at `roguelike-master-plan/.sisyphus/plans/roguelike-prototypes-design.md` provides:

## Requirements (from master plan)

### Core Specifications
- **Genre**: Event-driven exploration roguelike
- **Theme**: Abstract/procedural (minimal narrative, focus on mechanics)
- **Timing**: Turn-based (event resolution)
- **Party**: 3-person crew (fixed roles: Fighter, Medic, Engineer)
- **Session**: 15-20 minutes
- **Win Condition**: Reach destination node (15-20 jumps)
- **Lose Condition**: All crew dead OR run out of fuel

### Design Axes (Primary Focus)
- Reversibility (swappable) - Crew roles can be reassigned at cost
- Information (forecast) - See node types 2 jumps ahead
- Negative Acquisition (optional) - Some events offer risk/reward

### Content Quotas
- **Player Options**: 3 crew (fixed)
- **Roles**: 3 roles x 1 skill = 3
- **Enemies**: N/A (event-based)
- **Resources**: 4 types (Fuel, Supplies, Scrap, Credits)
- **Nodes**: 20 nodes
- **Events**: 30 events

### Crew Roles (from master plan)
| Role | Skill Rating | Specialization |
|------|--------------|----------------|
| Fighter | Combat: 3 | Violent encounters |
| Medic | Medical: 3 | Health/biological events |
| Engineer | Technical: 3 | Repair/puzzle events |

### Skill Check Formula
```
Success_Chance = Crew_Skill x 20% + 20%
(Skill 3 = 80% success, Skill 5 = 100% cap)
```

### Node Types (10 total)
- Empty (20%), Combat (15%), Hazard (15%), Distress (10%)
- Derelict (10%), Trade (10%), Mystery (10%), Repair (5%)
- Upgrade (3%), Boss (2%)

### Events (30 total, 3 per node type)
Already fully specified in master document.

### Guardrails
- No ship systems
- No real-time combat
- No crew recruitment
- Text-based event resolution

## Open Questions for Interview

### Core Loop Clarifications
1. How does crew incapacitation work exactly? (HP system, healing, recovery)
2. What's the exact "reassignment at cost" mechanic for swapping roles?
3. Should there be any visual representation beyond text (map, portraits)?

### Resource Economy
4. Fuel consumption - always 1 per jump, or variable?
5. How do resources interact (can you trade supplies for fuel, etc.)?
6. What's the typical resource progression? (should feel tight but not hopeless)

### Event System
7. Are events one-time or can they repeat?
8. Should events have "blue options" like FTL (special options if you have certain crew/resources)?
9. How much RNG vs player choice in event outcomes?

### Map/Navigation
10. Is the map linear, branching, or fully connected?
11. Can you backtrack?
12. How does "forecast 2 jumps ahead" work with branching paths?

### Victory/Loss States
13. What happens at destination? Automatic win or final challenge?
14. Crew incapacitation vs death - can you still win with all crew incapacitated?

### UI/UX Considerations
15. ASCII/CP437 style like Descent, or different visual approach?
16. Should we show success chances before choosing event options?

## Decisions Made (during interview)

### Visual Style
- **Using dungeon_mode tileset**: 256 8x8 pixel sprites from `roguelike-sim-incremental/assets/graphics/pre-packing-files_globbed/dungeon_mode/`
- Includes: hero portraits (knight, mage, rogue, archer), monsters, items, environment tiles, UI box-drawing characters
- Perfect for crew representation and map nodes

### Core Mechanics
- **No role swapping**: Fighter/Medic/Engineer are fixed identities. Skills can increase but roles don't change.
- **Blue options**: Skill-gated event options (e.g., "Engineer skill 4+ can bypass trap")
- **Show percentages**: Display exact success chances before player commits (e.g., "[Fight] (80% success)")
- **Final boss event**: Destination requires sequence of skill checks (Fight + Tech + Medical, pass 2 of 3)

### Map Structure
- **Linear with branches**: 2-3 paths that sometimes converge (FTL-style sectors)
- Player sees upcoming nodes on current path plus adjacent paths
- Simple graph structure, no backtracking

### Crew HP System
- **3 HP per crew** as per master plan
- Incapacitated (0 HP) = can't use skills but not dead
- Healing events restore 1 HP
- Clear visual indicators (heart icons from tileset)

### Asset Strategy
- **Copy sprites to roguelike-3**: Create `assets/graphics/expedition/` folder
- Copy only needed sprites (~50-60 of the 256)
- Self-contained project, no external dependencies

### Testing Strategy
- **Lua tests for game logic**: Test event outcomes, skill checks, resource math
- Located in `assets/scripts/expedition/tests/`
- Run via Lua test harness, no C++ changes needed

### Mapping Crew to Sprites
- **Fighter** (Combat) → `dm_144_hero_knight.png` (Red color theme)
- **Medic** (Medical) → `dm_145_hero_mage.png` (Green color theme - healer aesthetic)
- **Engineer** (Technical) → `dm_146_hero_rogue.png` (Blue color theme - technical/dexterous)

### Node Type to Sprite Mapping
| Node Type | Icon Sprite | Color |
|-----------|-------------|-------|
| Empty | `dm_192_floor_stone` | Gray |
| Combat | `dm_160_sword` | Red |
| Hazard | `dm_232_status_poison` | Yellow/Orange |
| Distress | `dm_033_exclaim` | Yellow |
| Derelict | `dm_143_chest_open` | Brown |
| Trade | `dm_190_coin_gold` | Gold |
| Mystery | `dm_063_question` | Purple |
| Repair | `dm_173_gloves` (tools) | Blue |
| Upgrade | `dm_226_magic_sparkle` | Cyan |
| Boss | `dm_159_dragon` | Red |
| Destination | `dm_141_throne` | Gold |
| Current Position | `dm_064_at_symbol` | White |

## Research Findings
- Engine has comprehensive UI helpers in `docs/api/ui_helper_reference.md`
- Node/map systems need to be built (no existing implementation)
- Text-based events map well to existing localization system

## Scope Boundaries
- INCLUDE: All 30 events, map generation, resource management, crew system
- EXCLUDE: Ship systems, real-time combat, crew recruitment, procedural events

---

*Draft started: Planning session for Expedition implementation*
