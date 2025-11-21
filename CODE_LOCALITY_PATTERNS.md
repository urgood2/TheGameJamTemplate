# Code Locality: Best Practices & Anti-Patterns

> **Core Principle**: Related behavior should be defined in one location, not scattered across callbacks and class methods.
>
> **Inspiration**: emoji-merge architecture philosophy + functional programming principles
>
> **Goal**: Reduce cognitive load by keeping "what happens" close to "when it happens"

---

## Table of Contents

1. [What is Code Locality?](#what-is-code-locality)
2. [Locality vs Anti-Locality Examples](#locality-vs-anti-locality)
3. [Tools for Achieving Locality](#tools-for-achieving-locality)
4. [Pattern: Timer-Driven Sequences](#pattern-timer-driven-sequences)
5. [Pattern: Closure-Captured Context](#pattern-closure-captured-context)
6. [Pattern: Tag-Based Lifecycle Management](#pattern-tag-based-lifecycle-management)
7. [Pattern: Local Function Composition](#pattern-local-function-composition)
8. [Anti-Pattern: Scattered Callbacks](#anti-pattern-scattered-callbacks)
9. [Anti-Pattern: State Field Soup](#anti-pattern-state-field-soup)
10. [Anti-Pattern: Implicit Dependencies](#anti-pattern-implicit-dependencies)
11. [When to Break Locality](#when-to-break-locality)
12. [Refactoring Checklist](#refactoring-checklist)

---

## What is Code Locality?

**Code locality** means keeping related logic physically close in the source code. When reading a function, you should understand:
- What will happen
- When it will happen
- What context it needs
- How it will clean up

**Without locality**:
```lua
-- Scattered across 5 different methods
function Enemy:init()
  self.phase = 1
  self.attack_timer = 0
end

function Enemy:update(dt)
  self.attack_timer = self.attack_timer + dt
  if self.attack_timer > 5.0 then
    self:start_attack()
  end
end

function Enemy:start_attack()
  self.attacking = true
  self.attack_timer = 0
  self:play_animation("attack")
end

function Enemy:finish_attack()
  self.attacking = false
end

function Enemy:on_animation_complete()
  if self.attacking then
    self:finish_attack()
  end
end
```

**With locality**:
```lua
function Enemy:init()
  -- All attack logic in one place
  timer.every(5.0, function()
    self.attacking = true
    play_animation(self, "attack")

    timer.after(1.2, function()  -- Animation duration
      self.attacking = false
    end)
  end, nil, nil, nil, "enemy_attack_" .. self.id)
end
```

Reading the second version immediately tells you:
- Attacks happen every 5 seconds
- Attack animation lasts 1.2 seconds
- No cleanup needed (timer handles it)

---

## Locality vs Anti-Locality

### Example 1: Cooldown Ability

#### ❌ Anti-Locality (Scattered State)
```lua
-- In different files or class methods

-- Entity.lua
function Entity:init()
  self.ability_cooldown = 0
  self.ability_charging = false
  self.ability_charge_time = 0
  self.ability_ready = true
end

function Entity:update(dt)
  -- Cooldown tick
  if self.ability_cooldown > 0 then
    self.ability_cooldown = self.ability_cooldown - dt
    if self.ability_cooldown <= 0 then
      self.ability_ready = true
    end
  end

  -- Charge tick
  if self.ability_charging then
    self.ability_charge_time = self.ability_charge_time + dt
    if self.ability_charge_time >= 2.0 then
      self:execute_ability()
    end
  end
end

function Entity:try_use_ability()
  if not self.ability_ready then return false end
  self.ability_charging = true
  self.ability_charge_time = 0
  self.ability_ready = false
  return true
end

function Entity:execute_ability()
  self.ability_charging = false
  self.ability_charge_time = 0
  self.ability_cooldown = 6.0
  -- actual ability code
  do_damage(self, 50)
end
```

**Problems**:
- 4 state fields to track
- Logic split across 4 methods
- Easy to forget cleanup
- Hard to change timings

#### ✅ Locality (Self-Contained)
```lua
function Entity:setup_ability()
  timer.every(6.0, function()
    -- Charge phase
    self.ability_charging = true

    timer.after(2.0, function()
      -- Execute phase
      self.ability_charging = false
      do_damage(self, 50)
    end)
  end, nil, nil, nil, "ability_" .. self.id)
end
```

**Benefits**:
- All timings in one place
- Natural cleanup (timers auto-manage)
- 2 lines to change charge time
- Visual timeline of behavior

---

### Example 2: Status Effect

#### ❌ Anti-Locality
```lua
-- StatusManager.lua (global system)
StatusManager = {
  active_effects = {}
}

function StatusManager:apply(entity, effect_name, duration)
  table.insert(self.active_effects, {
    entity = entity,
    effect = effect_name,
    expires = game_time + duration
  })
  entity[effect_name] = true
end

function StatusManager:update(dt)
  for i = #self.active_effects, 1, -1 do
    local eff = self.active_effects[i]
    if game_time >= eff.expires then
      eff.entity[eff.effect] = false
      table.remove(self.active_effects, i)
    end
  end
end

-- Combat.lua
function apply_poison(target)
  StatusManager:apply(target, "poisoned", 5.0)
  -- DOT is elsewhere...
end

-- DOTSystem.lua
function DOTSystem:update(dt)
  for _, entity in ipairs(entities) do
    if entity.poisoned then
      entity:take_damage(5)
    end
  end
end
```

**Problems**:
- Effect application in one file
- DOT damage in another file
- Cleanup in a third location
- Can't see full behavior at a glance

#### ✅ Locality
```lua
function apply_poison(target)
  target.poisoned = true
  target.poison_color = {0, 1, 0}

  -- DOT ticks locally defined
  timer.every(0.5, function()
    target:take_damage(5)
  end, 10)  -- 10 ticks = 5 seconds

  -- Cleanup
  timer.after(5.0, function()
    target.poisoned = false
    target.poison_color = nil
  end)
end
```

**Benefits**:
- Entire poison behavior in one function
- Easy to see: 5 damage every 0.5s for 5s
- Cleanup right next to setup
- Trivial to modify duration

---

## Tools for Achieving Locality

### 1. Timer System (Temporal Locality)
```lua
-- Instead of manual frame counting
timer.after(delay, callback)
timer.every(interval, callback, count)
timer.for_time(duration, update_callback, finish_callback)
timer.during(duration, during_callback, after_callback)
```

### 2. Closures (Context Locality)
```lua
-- Captures variables from surrounding scope
function spawn_projectile(owner, target)
  local proj = create_entity()

  -- Closure captures owner and target
  timer.every(0.1, function()
    if target.dead then
      proj.dead = true
    else
      proj:move_towards(target)
    end
  end)
end
```

### 3. Event System (Declarative Locality)
```lua
-- Define handlers where they're relevant
function setup_powerup(powerup)
  powerup:on("player_collide", function(player)
    player.speed = player.speed * 1.5

    timer.after(10.0, function()
      player.speed = player.speed / 1.5
    end)

    powerup.dead = true
  end)
end
```

### 4. Tags (Lifecycle Locality)
```lua
-- Tag all related timers
function start_boss_fight(boss)
  local tag = "boss_fight_" .. boss.id

  timer.every(3.0, function()
    boss:attack()
  end, nil, nil, nil, tag)

  timer.every(10.0, function()
    boss:summon_adds()
  end, nil, nil, nil, tag)

  -- One line to clean up entire fight
  boss:on_death(function()
    timer.cancel(tag)
  end)
end
```

---

## Pattern: Timer-Driven Sequences

**Goal**: Define multi-step behavior in reading order (top-to-bottom timeline)

```lua
function execute_combo_attack(player)
  -- Step 1: Wind-up (0.3s)
  player.animation = "wind_up"
  play_sound("swoosh")

  timer.after(0.3, function()
    -- Step 2: First strike
    player.animation = "strike_1"
    deal_damage(player, 20)

    timer.after(0.2, function()
      -- Step 3: Second strike
      player.animation = "strike_2"
      deal_damage(player, 25)

      timer.after(0.2, function()
        -- Step 4: Finisher
        player.animation = "finisher"
        deal_damage(player, 50)
        screen_shake(10)

        timer.after(0.5, function()
          -- Step 5: Recovery
          player.animation = "idle"
          player.can_act = true
        end)
      end)
    end)
  end)
end
```

**Reading this code**:
- Immediately see 5-step sequence
- Timings are explicit (0.3 + 0.2 + 0.2 + 0.5 = 1.2s total)
- No separate state machine needed

---

## Pattern: Closure-Captured Context

**Goal**: Avoid class fields for temporary state

#### ❌ Class Field Pollution
```lua
function Enemy:start_dash()
  self.dash_start_x = self.x
  self.dash_start_y = self.y
  self.dash_target_x = player.x
  self.dash_target_y = player.y
  self.dash_progress = 0
  self.dash_duration = 0.5
  self.dashing = true
end

function Enemy:update(dt)
  if self.dashing then
    self.dash_progress = self.dash_progress + dt
    local t = self.dash_progress / self.dash_duration
    -- lerp logic...
  end
end
```

**Problems**:
- 7 fields added to enemy class
- Pollutes every enemy instance
- Fields persist after dash ends (memory waste)

#### ✅ Closure Capture
```lua
function Enemy:start_dash()
  local start_x, start_y = self.x, self.y
  local target_x, target_y = player.x, player.y
  local duration = 0.5

  self.dashing = true

  timer.for_time(duration, function(dt, progress)
    -- progress is 0-1 over duration
    self.x = lerp(start_x, target_x, progress)
    self.y = lerp(start_y, target_y, progress)
  end, function()
    self.dashing = false
    -- start_x etc. are garbage collected
  end)
end
```

**Benefits**:
- Only 1 persistent field (self.dashing)
- Temporary state in local variables
- Auto-cleanup via garbage collection
- Impossible to forget to reset fields

---

## Pattern: Tag-Based Lifecycle Management

**Goal**: Group related timers for batch control

```lua
function start_minigame(game)
  local tag = "minigame_" .. game.id

  -- Spawn enemies
  timer.every(2.0, function()
    spawn_enemy(game)
  end, nil, nil, nil, tag)

  -- Timer countdown
  timer.every(1.0, function()
    game.time_remaining = game.time_remaining - 1
    if game.time_remaining <= 0 then
      end_minigame(game)
    end
  end, nil, nil, nil, tag)

  -- Power-up spawns
  timer.every(5.0, function()
    spawn_powerup(game)
  end, nil, nil, nil, tag)
end

function end_minigame(game)
  -- Cancel all minigame timers at once
  timer.cancel(tag)
  -- No need to track individual timer handles
end
```

**Benefits**:
- One tag unifies related timers
- Batch cancellation in one line
- No array of timer handles to manage

---

## Pattern: Local Function Composition

**Goal**: Break complex sequences into named sub-functions within scope

```lua
function boss_ultimate_attack(boss)
  -- Local helpers (not visible outside this function)
  local function telegraph_phase()
    boss.color = {1, 0, 0}
    boss.telegraph_radius = 0

    timer.for_time(2.0, function(dt)
      boss.telegraph_radius = boss.telegraph_radius + dt * 100
    end, charge_phase)
  end

  local function charge_phase()
    boss.charging = true
    play_sound("charge_up")

    timer.after(1.0, release_phase)
  end

  local function release_phase()
    boss.charging = false
    spawn_projectile_ring(boss, 20)
    screen_shake(20)

    timer.after(0.5, recovery_phase)
  end

  local function recovery_phase()
    boss.color = boss.default_color
    boss.vulnerable = true

    timer.after(1.5, function()
      boss.vulnerable = false
    end)
  end

  -- Start the sequence
  telegraph_phase()
end
```

**Benefits**:
- Complex attack split into readable phases
- Each phase is a named function (self-documenting)
- All phases still in one location
- No class method pollution

---

## Anti-Pattern: Scattered Callbacks

**Problem**: Behavior split across multiple event handlers

#### ❌ Scattered
```lua
-- File: player.lua
function Player:on_button_press()
  if self.can_dash then
    self:start_dash()
  end
end

-- File: dash_system.lua
function Player:start_dash()
  self.dashing = true
  self.dash_timer = 0.3
  EventBus.emit("dash_start", self)
end

function DashSystem:update(dt)
  for _, player in ipairs(players) do
    if player.dashing then
      player.dash_timer = player.dash_timer - dt
      if player.dash_timer <= 0 then
        EventBus.emit("dash_end", player)
      end
    end
  end
end

-- File: dash_effects.lua
EventBus.on("dash_start", function(player)
  player.speed = player.speed * 3
end)

EventBus.on("dash_end", function(player)
  player.dashing = false
  player.speed = player.speed / 3
end)
```

**Problems**:
- 4 different locations to understand one mechanic
- Event system hides control flow
- Debugging requires stepping through multiple files

#### ✅ Localized
```lua
function Player:on_button_press()
  if not self.can_dash then return end

  -- Everything right here
  self.dashing = true
  self.speed = self.speed * 3

  timer.after(0.3, function()
    self.dashing = false
    self.speed = self.speed / 3
  end)
end
```

---

## Anti-Pattern: State Field Soup

**Problem**: Class has dozens of state fields that are only used in specific situations

#### ❌ Polluted Class
```lua
Enemy = {
  -- 20+ fields for various temporary states
  charging = false,
  charge_time = 0,
  charge_target_x = 0,
  charge_target_y = 0,

  stunned = false,
  stun_time = 0,

  channeling = false,
  channel_time = 0,
  channel_effect = nil,

  dodging = false,
  dodge_time = 0,
  dodge_dir = 0,

  -- etc...
}
```

**Problems**:
- Every enemy instance carries all these fields
- Memory waste (most are nil/false most of the time)
- Unclear which fields are related
- Easy to forget to reset

#### ✅ Closure State
```lua
function Enemy:charge_attack()
  -- State exists only during charge
  local target_x, target_y = self:get_target_pos()
  local charge_duration = 0.8

  self.charging = true  -- Only flag needed

  timer.for_time(charge_duration, function(dt, progress)
    -- Lerp towards target
    local new_x = lerp(self.x, target_x, progress)
    local new_y = lerp(self.y, target_y, progress)
    self:move_to(new_x, new_y)
  end, function()
    self.charging = false
    self:impact_damage()
    -- target_x, target_y garbage collected
  end)
end
```

---

## Anti-Pattern: Implicit Dependencies

**Problem**: Function requires specific setup that isn't obvious

#### ❌ Hidden Requirements
```lua
-- Somewhere in init
function Enemy:init()
  self.attack_state = "idle"
end

-- Somewhere in update
function Enemy:start_attack()
  if self.attack_state ~= "idle" then return end
  self.attack_state = "charging"
  -- More code...
end

-- Somewhere else
function Enemy:take_damage(dmg)
  -- Hidden requirement: must reset attack_state
  self.attack_state = "idle"
  -- More code...
end
```

**Problems**:
- `take_damage` must know about attack system
- Tight coupling between systems
- Refactoring attack breaks damage

#### ✅ Explicit Dependencies
```lua
function Enemy:start_attack()
  if self.busy then return end

  local attack_tag = "attack_" .. self.id
  self.busy = true

  timer.after(1.0, function()
    self:execute_attack()
    self.busy = false
  end, attack_tag)

  -- Explicit: "interrupting" cancels attack
  self:on_interrupt(function()
    timer.cancel(attack_tag)
    self.busy = false
  end)
end

function Enemy:take_damage(dmg)
  self:trigger_interrupt()  -- Explicit call
  -- Damage logic...
end
```

---

## When to Break Locality

Locality is not always the right choice. Break it when:

### 1. Performance-Critical Code
```lua
-- Acceptable: Hot loop optimization
function update_particles(dt)
  for i = 1, #particles do
    local p = particles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    -- Don't use closures/timers in 10,000-particle loop
  end
end
```

### 2. Shared Logic Across Many Objects
```lua
-- Acceptable: Reusable system
DamageNumbers = {}
function DamageNumbers.show(x, y, amount)
  -- Complex damage number animation
  -- Used by 50+ different damage sources
end
```

### 3. UI State Management
```lua
-- Acceptable: Centralized state
UI = {
  current_menu = "main",
  menu_stack = {},
  transitions = {}
}

-- Better than 20 different menu files with local state
```

### 4. Save/Load Systems
```lua
-- Acceptable: Centralized serialization
function SaveManager:save_game()
  return {
    player = player:serialize(),
    enemies = serialize_all(enemies),
    world = world:serialize()
  }
end
```

---

## Refactoring Checklist

When reviewing code for locality, ask:

### ✅ Good Locality
- [ ] Can I understand behavior by reading one function?
- [ ] Are timings explicit (not spread across update methods)?
- [ ] Does cleanup happen automatically (timers, closures)?
- [ ] Are related fields captured in closures (not class fields)?
- [ ] Can I change duration in one place?

### ❌ Poor Locality
- [ ] Do I need to jump between multiple files?
- [ ] Are there 5+ state fields for one behavior?
- [ ] Does cleanup require manual reset calls?
- [ ] Is control flow hidden behind event system?
- [ ] Would changing timing require editing 3+ places?

---

## Refactoring Example

### Before (Poor Locality)
```lua
-- enemy.lua
function Enemy:init()
  self.state = "idle"
  self.attack_cooldown = 0
end

function Enemy:update(dt)
  if self.state == "idle" then
    self.attack_cooldown = self.attack_cooldown - dt
    if self.attack_cooldown <= 0 and distance_to_player(self) < 200 then
      self.state = "attacking"
      self:play_animation("attack")
    end
  elseif self.state == "attacking" then
    if self.animation_finished then
      self.state = "idle"
      self.attack_cooldown = 3.0
    end
  end
end
```

### After (Good Locality)
```lua
-- enemy.lua
function Enemy:init()
  timer.every(3.0, function()
    if distance_to_player(self) < 200 then
      play_animation(self, "attack")

      timer.after(1.2, function()  -- Animation duration
        -- Attack completes, timer automatically repeats
      end)
    end
  end, nil, nil, nil, "enemy_attack_" .. self.id)
end
```

**Improvements**:
- 5 fewer fields
- No state enum
- Timings explicit
- Animation duration visible
- Auto-repeats every 3s

---

## Summary

**Code locality** means:
1. ✅ Use timers for temporal sequences
2. ✅ Use closures for temporary state
3. ✅ Use tags for lifecycle management
4. ✅ Keep related logic in one function
5. ❌ Avoid scattered callbacks
6. ❌ Avoid state field pollution
7. ❌ Avoid implicit dependencies

**The test**:
> Can a new team member understand this behavior by reading one function, without jumping to other files?

If yes, you have good locality. If no, refactor.

---

## References

- Timer API: `assets/scripts/timer_docs.md`
- State machine patterns: `assets/scripts/STATE_MACHINE_PATTERNS.md`
- emoji-merge analysis: `EMOJI_MERGE_TECHNIQUES_ANALYSIS.md`
- Event system: `assets/scripts/tutorial/list_of_defined_events.md`

---

*Last updated: 2025-11-21*
