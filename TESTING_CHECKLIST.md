# Complete Testing Checklist

**Purpose:** Track what needs to be tested before moving on to remaining tasks (Tasks 3, 6, 7, etc.)

---

## Related Docs
- docs/guides/SYSTEM_ARCHITECTURE.md (subsystem map, ownership, init order)
- docs/guides/ERROR_HANDLING_POLICY.md (fail-fast vs fallback rules)
- docs/guides/DOCUMENTATION_STANDARDS.md (comment templates and required coverage)

---

## ✅ Completed

- [x] Project compiles without errors
- [x] Bug Fix #7 applied (background translucency)
- [x] Bug Fix #10 applied (entity filtering)
- [x] Projectile system loads without errors
- [x] Projectile system initializes

---

## 🔄 In Progress

### Projectile System (Task 1)

- [ ] **Projectiles spawn successfully**
  - [ ] Console shows: `[✓] Basic projectile spawned successfully`
  - [ ] Console shows entity ID
  - [ ] Console shows transform data
  - [ ] Console shows active projectile count > 0

- [ ] **Projectiles are visible on screen**
  - [ ] Can see projectile sprites/shapes
  - [ ] Projectiles appear at spawn position (400, 300)
  - [ ] Projectiles have visual representation

- [ ] **Projectiles move correctly**
  - [ ] Straight projectiles move in a line
  - [ ] Position updates shown in console debug
  - [ ] Movement is smooth (no jittering)

- [ ] **Different movement types work**
  - [ ] Homing projectiles curve toward target
  - [ ] Arc projectiles follow parabolic path
  - [ ] Multiple projectiles spawn in fan pattern

- [ ] **Projectile lifecycle works**
  - [ ] Projectiles despawn after lifetime (3 seconds)
  - [ ] Active projectile count decreases
  - [ ] No memory leaks (check with profiler if available)

- [ ] **Physics integration works**
  - [ ] Projectiles have physics bodies
  - [ ] Collision detection works (if testable)
  - [ ] Physics sync is smooth (no teleporting)

---

## ⏳ Pending

### Wand Execution Engine (Task 2)

- [ ] **Module loads successfully**
  - [ ] WandExecutor module loads without errors
  - [ ] WandTests module loads without errors
  - [ ] Can initialize wand system

- [ ] **Example wands work**
  - [ ] Basic Fire Bolt loads and fires
  - [ ] Piercing Ice Shard loads and fires
  - [ ] Triple Shot loads and spawns 3 projectiles

- [ ] **Triggers activate correctly**
  - [ ] Timer triggers fire every N seconds
  - [ ] Event triggers respond to player actions
  - [ ] Manual wand execution works

- [ ] **Modifiers apply**
  - [ ] Pierce modifier allows piercing
  - [ ] Speed modifiers change projectile speed
  - [ ] Damage modifiers affect damage values

- [ ] **Wand + Projectile integration**
  - [ ] Wands spawn projectiles from Task 1
  - [ ] Projectiles inherit wand properties
  - [ ] Multiple wands can exist simultaneously

---

### Combat Loop Framework (Task 4)

- [ ] **Module loads successfully**
  - [ ] Combat loop test module loads
  - [ ] Can initialize test scenario

- [ ] **Enemy spawning works**
  - [ ] Enemies spawn in wave 1
  - [ ] Spawn positions are correct
  - [ ] Multiple enemies can exist

- [ ] **Wave progression**
  - [ ] Wave counter shows current wave
  - [ ] Wave transitions when enemies defeated
  - [ ] Wave 2 starts after wave 1

- [ ] **State machine**
  - [ ] States transition correctly (INIT → WAVE_START → COMBAT → VICTORY)
  - [ ] State changes are logged
  - [ ] No state machine crashes

- [ ] **Loot system**
  - [ ] Loot drops when enemies die
  - [ ] Loot is visible on screen
  - [ ] Loot can be collected
  - [ ] Currency/XP tracking works

- [ ] **Combat loop + Other systems**
  - [ ] Enemies can shoot projectiles (Task 1)
  - [ ] Player can use wands (Task 2)
  - [ ] Full gameplay loop functions

---

### Bug Fixes

- [ ] **Bug #7: Background translucency**
  - [ ] Background is opaque
  - [ ] No flickering or fading
  - [ ] Tested with shaders active

- [ ] **Bug #10: Entity filtering**
  - [ ] Entities without StateTag render
  - [ ] Camera follows player
  - [ ] Projectiles are visible

---

## 🎯 Integration Tests

After all individual systems work, test integration:

- [ ] **Projectiles + Wands**
  - [ ] Wand spawns projectile correctly
  - [ ] Projectile has wand's damage/speed
  - [ ] Modifiers from wand apply to projectile

- [ ] **Projectiles + Combat Loop**
  - [ ] Player projectiles hit enemies
  - [ ] Enemy projectiles hit player
  - [ ] Projectile collision works in combat

- [ ] **Wands + Combat Loop**
  - [ ] Can use wands during combat
  - [ ] Wand cooldowns work during waves
  - [ ] Multiple wands can be equipped

- [ ] **All Systems Together**
  - [ ] Start combat → spawn enemies → use wand → projectiles fly → hit enemies → enemies die → loot drops → next wave
  - [ ] No crashes during full gameplay loop
  - [ ] Frame rate is acceptable
  - [ ] Memory usage is stable

---

## 📝 Common Issues to Watch For

### Rendering Issues
- [ ] Projectiles spawn but are invisible (check layers, z-order, sprites)
- [ ] Projectiles render behind background
- [ ] Sprites not attached to entities

### Physics Issues
- [ ] Projectiles spawn but don't move
- [ ] Projectiles jitter or teleport
- [ ] Collision shapes drift from visual position

### Memory Issues
- [ ] Entities not cleaned up (use profiler)
- [ ] Timers not cancelled
- [ ] Projectiles leak memory

### Module Issues
- [ ] Module paths incorrect
- [ ] Missing dependencies
- [ ] Functions not exported properly

---

## ✅ Success Criteria

Before moving to Tasks 3, 6, 7, ALL of these must pass:

### Minimum Requirements
1. ✅ Projectile system spawns and updates projectiles
2. ✅ Projectiles are visible on screen
3. ✅ At least one movement type works (straight)
4. ✅ Wand system can trigger and spawn projectiles
5. ✅ Combat loop can spawn enemies and progress waves
6. ✅ No crashes during basic gameplay loop
7. ✅ Bug fixes #7 and #10 are working

### Nice to Have (Not Blockers)
- All movement types working perfectly
- All example wands functional
- Complete enemy AI
- Full loot system
- Perfect visual polish

---

## 🚦 Current Status

**Last Updated:** Fixed projectile data storage architecture

**Recently Fixed:**
1. ✅ Projectile system now uses correct `getScriptTableFromEntityID()` pattern
2. ✅ Replaced `publishLuaEvent()` with signal library (`signal.emit()`)
3. ✅ Removed incorrect GameObject component emplacement
4. ✅ Build compiles successfully

**Blocking Issues:**
1. Projectiles spawn successfully but are not visible on screen (may be resolved by architecture fix)

**Next Steps:**
1. Test projectile visibility with corrected architecture
2. Verify projectile lifecycle (spawn → update → destroy)
3. Test event system (signals emitted correctly)
4. Check if sprites are attached to entities

---

## 📊 Progress Summary

| System | Load | Init | Spawn | Visible | Move | Complete |
|--------|------|------|-------|---------|------|----------|
| Projectile | ✅ | ✅ | ✅ | ❓ | ❓ | 60% |
| Wand | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ | 0% |
| Combat Loop | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ | 0% |
| Bug Fixes | ✅ | ✅ | N/A | ❓ | N/A | 100% |

**Overall:** ~40% tested

---

Use this checklist to track progress. Check off items as you verify them working!


