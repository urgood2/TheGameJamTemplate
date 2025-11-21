# Refined Systems-Focused Task List

Based on codebase analysis completed 2025-11-20. This list focuses on underlying systems infrastructure rather than specific gameplay design details.

---

## Task Prioritization

**Critical Priority:** Tasks 1-3 (blocks core gameplay loop)
**High Priority:** Tasks 4-5 (enables full gameplay)
**Medium Priority:** Tasks 6-7 (polish and progression)
**Low Priority:** Tasks 8-9 (audio/visual enhancements)

---

## Task 1: Projectile Spawning & Management System 🎯

**Status:** Missing foundation
**Priority:** Critical (blocks spell system)
**Estimated Complexity:** High

### Objectives
- Design and implement projectile entity spawning system
- Create projectile behavior framework (movement patterns, lifetime, collision handling)
- Build projectile pool/recycling system for performance
- Implement projectile-physics integration (Chipmunk2D body management)
- Create projectile component architecture (speed, damage, modifiers, behaviors)
- Add projectile event hooks (OnSpawn, OnHit, OnDestroy)

### Dependencies
- Requires: Physics system (✅ exists), Entity factory (✅ exists)
- Blocks: Task 2 (Wand Execution Engine)

---

## Task 2: Wand Execution Engine ⚙️

**Status:** Evaluation exists, execution missing
**Priority:** Critical (core gameplay loop)
**Estimated Complexity:** High

### Objectives
- Complete wand evaluation-to-execution pipeline
- Implement trigger system (timer-based, event-based activation)
- Build action execution framework (spawn projectiles, apply effects)
- Create modifier application system (chain modifiers to actions)
- Implement multicast logic (parallel spell casting)
- Add wand state tracking (cooldowns, charges, current cast block)
- Build cast sequence iterator with proper timing

### Dependencies
- Requires: Task 1 (Projectile System), Combat system (✅ exists), Timer system (✅ exists)
- Blocks: Full gameplay loop

### Key Files to Modify
- `assets/scripts/gameplay.lua` (WandEngine)
- Card evaluation logic
- Combat system integration

---

## Task 3: Card-to-Gameplay Integration Bridge 🎴

**Status:** UI exists, gameplay connection weak
**Priority:** Critical
**Estimated Complexity:** Medium

### Objectives
- Connect card definitions to combat system effects
- Implement card → spell conversion system
- Build card upgrade infrastructure (not specific upgrades, just the system)
- Create card validation system (check wand limits, trigger conflicts)
- Add card state persistence across scenes
- Implement card synergy tag evaluation framework
- Build card cost/requirement evaluation system

### Dependencies
- Requires: Card UI (✅ exists), Combat system (✅ exists)
- Blocks: Card progression features

### Key Files to Modify
- Card definition files
- `assets/scripts/combat/combat_system.lua`
- `assets/scripts/gameplay.lua`

---

## Task 4: Entity Lifecycle & Combat Loop Framework ⚔️

**Status:** Stats exist, combat loop incomplete
**Priority:** High
**Estimated Complexity:** High

### Objectives
- Complete enemy spawning system (not specific enemies, just the spawner)
- Build wave management system (timer, spawn points, wave transitions)
- Implement combat state machine (battle start, victory, defeat, shop transitions)
- Create entity death/despawn cleanup system
- Add XP/currency drop system (generic drop framework)
- Build loot spawn and pickup system
- Implement autobattle timer/interest mechanics

### Dependencies
- Requires: Combat system (✅ exists), Entity factory (✅ exists), Physics (✅ exists)
- Blocks: Full game loop

### Key Files to Modify
- Enemy spawning system
- Wave manager
- State machine transitions
- `assets/scripts/combat/combat_system.lua`

---

## Task 5: Critical Bug Fixes 🐛

**Status:** Active issues blocking functionality
**Priority:** High
**Estimated Complexity:** Medium to High

### Physics/Transform Issues
- [ ] Fix physics-transform sync jerking (`transform.cpp`)
- [ ] Fix drag & drop unreliability with physics bodies
- [ ] Resolve collision shape position drift during drag
- [ ] Fix authoritative rotation sync when transform leads physics

### UI/Rendering Issues
- [ ] Fix z-order calculation for overlapping cards (first overlap bug)
- [ ] Fix card area shifting logic with many cards
- [ ] Fix UI text overlap in tooltips
- [ ] Fix background translucency issues
- [ ] Resolve player invisibility when 3d_skew shader used on cards

### Memory/Performance
- [ ] Fix WASM memory leak
- [ ] Fix entity filtering issues causing camera problems
- [ ] Resolve board update stopping on state change

### Shader Issues
- [ ] Fix starry_tunnel shader
- [ ] Fix item_glow blending with background

### Dependencies
- Independent fixes, can be parallelized
- Some fixes unblock Task 3 (card drag/drop) and Task 7 (controller)

### Key Files to Investigate
- `src/ecs/components/transform.cpp` (transform sync)
- `src/systems/physics/physics_world.cpp` (physics sync)
- Card area logic files
- Shader pipeline files
- Rendering layer system

---

## Task 6: Progression System Plumbing 📈

**Status:** Stats defined, progression hooks missing
**Priority:** Medium
**Estimated Complexity:** Medium

### Objectives
- Connect level-up events to UI
- Implement stat selection UI for level-ups
- Build upgrade resource tracking system (generic currency/material system)
- Create character class initialization system (not specific classes, just the framework)
- Add equipment slot management system
- Implement stat recalculation triggers (on equip, level-up, buff)

### Dependencies
- Requires: Stat system (✅ exists), UI system (✅ exists), Combat system (✅ exists)
- Blocks: Character progression features

### Key Files to Modify
- `assets/scripts/combat/combat_system.lua` (stat system)
- Level-up UI files
- Character initialization

---

## Task 7: Controller & Input System Polish 🎮

**Status:** Partial implementation, navigation incomplete
**Priority:** Medium
**Estimated Complexity:** Low to Medium

### Objectives
- Complete main menu controller navigation
- Fix controller cursor positioning accuracy
- Implement card teleport-to-selection for controller
- Add controller prompt system (trigger+direction display)
- Disable mouse input when controller active
- Fix trigger area single-card restriction

### Dependencies
- Requires: Controller navigation system (✅ exists), UI system (✅ exists)
- Partially blocked by: Task 5 (some controller bugs)

### Key Files to Modify
- Controller navigation code (`30,489 LOC` system)
- Input system files
- Card interaction logic
- Main menu

---

## Task 8: Shader Pipeline Extensions 🎨

**Status:** Pipeline exists, specific effects missing
**Priority:** Low
**Estimated Complexity:** Low to Medium

### Objectives
- Debug and fix existing shader issues (glow, starry_tunnel)
- Test shader uniforms for fireworks effect
- Implement shader switching on card interaction
- Add per-entity shader state management
- Create shader effect chaining system for items

### Dependencies
- Requires: Shader pipeline (✅ exists), Rendering system (✅ exists)
- Related to: Task 5 (shader bug fixes)

### Key Files to Modify
- Shader pipeline code (`22,542 LOC` system)
- Individual shader files
- Entity-shader binding system

---

## Task 9: Audio System Integration 🔊

**Status:** System exists, game integration incomplete
**Priority:** Low
**Estimated Complexity:** Low

### Objectives
- Add audio toggle system (tick sounds, etc.)
- Implement sound effect variation system (random pitch/volume)
- Create audio event hooks (OnCardPlay, OnLevelUp, OnItemDrop)
- Normalize existing sound effect volumes
- Add music track transition system

### Dependencies
- Requires: Audio system (✅ exists), Event system (✅ exists)
- Independent of other tasks

### Key Files to Modify
- `src/systems/sound_system.cpp` (`29,158 LOC`)
- Audio event integration points
- Settings/options system

---

## Already Implemented (Removed from TODO)

These systems are already complete and don't need work:

✅ **Core Engine Systems**
- Transform system with hierarchy
- UI box/element system (500k+ LOC)
- Controller navigation framework (30k+ LOC)
- Stat system architecture (composable mechanics)
- Physics integration (Chipmunk2D, 120k+ LOC)
- Timer system with chaining
- Board/card UI
- Tooltip system
- Camera effects (shake, zoom)
- Particle system (69k+ LOC)
- Spring physics (second-order dynamics)
- Shader pipeline (multi-pass support)
- Audio system (playback, volume, categories)
- ECS architecture (EnTT)
- Lua-C++ binding (Sol2)
- Event bus system

✅ **Combat/Stats Foundation**
- Damage type system (12 types)
- Resistance/reduction system (3-tier)
- Effect opcode system (18.5k LOC)
- Ability system with levels
- Targeter system (self, enemy, all, random, conditional)
- Status effect framework
- DoT tracking
- Combat event bus

---

## Excluded from List (Too Design-Specific)

These items from the original TODO are gameplay design details, not systems work:

❌ **Specific Content**
- Specific projectile types (bolt, orb, explosive, ricochet, etc.)
- Specific modifiers (homing, speed changes, damage, etc.)
- Specific multicasts (2-spell, 3-spell, circular)
- Specific utilities (teleport, healing area, shield, summon)
- Specific enemy designs and behaviors
- Specific character classes
- Specific card upgrades

❌ **Polish Phase Items**
- Juice effects (ambient movement, size boing, etc.)
- Specific shader additions (radial shine, fireworks variants, etc.)
- Music selection and licensing
- Sound effect tweaking
- Visual polish (glow, particles, screen effects)
- Release/testing preparations
- GitHub actions setup
- Itch.io deployment

---

## Parallelization Strategy

### Can Run in Parallel (Independent):
- **Group A:** Task 1 (Projectile System) + Task 4 (Entity Lifecycle) + Task 5 (Bug Fixes)
- **Group B:** Task 6 (Progression) + Task 7 (Controller) + Task 9 (Audio)
- **Group C:** Task 8 (Shaders) is independent

### Must Run Sequentially:
- Task 1 → Task 2 (Projectile system must exist before wand execution)
- Task 2 → Task 3 (Wand execution helps inform card integration)

### Recommended Parallel Launch:
1. **First Wave:** Tasks 1, 4, 5 (3 agents in parallel)
2. **Second Wave:** Tasks 2, 3, 6 (after Task 1 completes)
3. **Polish Wave:** Tasks 7, 8, 9 (lowest priority)

---

## Codebase Context

**Tech Stack:**
- **Language:** C++20 + Lua scripting
- **Engine:** Custom (Raylib + EnTT + Chipmunk2D)
- **Build:** CMake + Emscripten (web support)
- **Assets:** LDtk levels, 105+ shaders, BabelEdit localization

**Codebase Size:**
- ~371 C++ files
- ~1,342 header files
- ~500k LOC in UI systems alone
- ~324 TODO/FIXME comments across 38 files

**Current Completion:** ~60-70% complete game jam template with excellent infrastructure but incomplete gameplay integration.

---

## Notes

- This analysis was performed on 2025-11-20
- Based on comprehensive codebase exploration
- Focus is on **systems infrastructure**, not game design
- All tasks assume the robust existing foundation (UI, physics, rendering, etc.)
- Bug fixes should be addressed before or alongside new feature work
