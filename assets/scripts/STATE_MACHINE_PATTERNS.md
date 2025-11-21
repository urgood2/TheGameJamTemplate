# Timer-Based State Machine Patterns

> **Extracted from**: emoji-merge repository analysis + SNKRX patterns
> **Purpose**: Lightweight state machines using timer primitives instead of explicit FSM enums
> **Benefits**: Code locality, less boilerplate, natural timeout handling

This document provides drop-in patterns for common gameplay state machines built entirely with the timer system. These patterns avoid explicit state enums and scattered callbacks by keeping all related logic in one place.

---

## Table of Contents

1. [Core Philosophy: Locality over Bureaucracy](#core-philosophy)
2. [Pattern 1: Cooldown with Telegraph](#pattern-1-cooldown-with-telegraph)
3. [Pattern 2: Charge-and-Release Attacks](#pattern-2-charge-and-release-attacks)
4. [Pattern 3: Push/Knockback State](#pattern-3-pushknockback-state)
5. [Pattern 4: Status Effects with Stacking](#pattern-4-status-effects-with-stacking)
6. [Pattern 5: Boss Phase Transitions](#pattern-5-boss-phase-transitions)
7. [Pattern 6: Multi-Stage Ability](#pattern-6-multi-stage-ability)
8. [Pattern 7: Timed Invulnerability](#pattern-7-timed-invulnerability)
9. [Pattern 8: Buff/Debuff Pipeline](#pattern-8-buffdebuff-pipeline)
10. [Pattern 9: Combo Window](#pattern-9-combo-window)
11. [Pattern 10: Conditional Loop (until dead)](#pattern-10-conditional-loop-until-dead)

---

## Core Philosophy

**Traditional FSM Approach** (explicit states):
```lua
-- Scattered across multiple functions
self.state = "IDLE"

function update()
  if self.state == "CHARGING" then
    -- charge logic
  elseif self.state == "ATTACKING" then
    -- attack logic
  end
end

function start_charge()
  self.state = "CHARGING"
  -- set timer elsewhere
end
```

**Timer-Based Approach** (locality):
```lua
-- Everything in one place
timer.every(ability_cooldown, function()
  -- Telegraph phase
  self.is_charging = true
  show_charge_vfx()

  timer.after(charge_time, function()
    -- Release phase
    self.is_charging = false
    execute_attack()

    -- Optional cleanup
    timer.after(recovery_time, function()
      self.is_vulnerable = true
    end)
  end)
end, nil, nil, nil, "ability_loop")
```

**Key Benefits**:
- All phases of behavior in single function body
- Natural timeout handling (no manual state cleanup)
- Easy to visualize timeline
- Closures preserve context without class fields

---

## Pattern 1: Cooldown with Telegraph

**Use Case**: Abilities that signal before execution (enemy attacks, player spells)

```lua
-- Simple cooldown with visual telegraph
function setup_ability(entity)
  timer.every(6.0, function()
    -- Skip if disabled
    if entity.stunned or entity.silenced then return end

    -- Telegraph phase (1.5s warning)
    entity.is_telegraphing = true
    entity.telegraph_color = {r=1, g=0, b=0}
    play_sound("charge_warning")

    timer.after(1.5, function()
      -- Release phase
      entity.is_telegraphing = false
      execute_attack(entity)

      -- Recovery phase
      timer.after(0.5, function()
        entity.telegraph_color = nil
      end)
    end)
  end, nil, nil, nil, "ability_cooldown_" .. entity.id)
end

-- Extract progress for UI
function get_telegraph_progress(entity)
  local t, c = timer.get_timer_and_delay("ability_cooldown_" .. entity.id)
  if not c or c == 0 then return 0 end
  return t / c  -- Returns 0-1 for progress bar
end
```

---

## Pattern 2: Charge-and-Release Attacks

**Use Case**: Held abilities, charged shots, dash attacks

```lua
-- Player holds button to charge, releases to attack
function start_charge_attack(player)
  player.charge_amount = 0
  player.is_charging = true
  player.charge_start_time = game_time

  -- Increment charge over time
  timer.for_time(3.0, function(dt)
    if not player.is_charging then return "break" end  -- Early exit

    player.charge_amount = math.min(player.charge_amount + dt/3.0, 1.0)

    -- Visual feedback per tick
    if player.charge_amount > 0.66 then
      player.color = {r=1, g=0, b=0}  -- Red = full charge
    elseif player.charge_amount > 0.33 then
      player.color = {r=1, g=1, b=0}  -- Yellow = mid
    end
  end, function()
    -- Max charge reached
    player.max_charged = true
    play_sound("charge_max")
  end, "player_charge")
end

function release_charge_attack(player)
  if not player.is_charging then return end

  player.is_charging = false
  timer.cancel("player_charge")

  -- Execute with charge multiplier
  local damage = base_damage * (1 + player.charge_amount * 2)
  perform_attack(player, damage)

  -- Reset
  player.charge_amount = 0
  player.color = player.default_color
  player.max_charged = false
end
```

---

## Pattern 3: Push/Knockback State

**Use Case**: Knockback effects that end when velocity dies down

```lua
-- Start push (apply impulse)
function start_push(entity, force, direction, options)
  options = options or {}

  entity.being_pushed = true
  entity.can_act = false
  entity.push_invulnerable = options.invulnerable or false

  -- Apply physics impulse
  local fx = force * math.cos(direction)
  local fy = force * math.sin(direction)
  physics.apply_impulse(entity, fx, fy)

  -- Spin for juice
  local spin = random_range(-12*math.pi, 12*math.pi)
  physics.apply_angular_impulse(entity, spin)

  -- Increase damping for quick stop
  physics.set_damping(entity, 1.5)

  -- Monitor velocity until stopped
  local push_tag = "push_" .. entity.id
  timer.every(0.05, function()
    local vx, vy = physics.get_velocity(entity)
    local speed = math.sqrt(vx*vx + vy*vy)

    if speed < (options.end_speed or 25) then
      -- Stopped, exit push state
      entity.being_pushed = false
      entity.can_act = true
      entity.push_invulnerable = false
      physics.set_damping(entity, 0)
      timer.cancel(push_tag)
    end
  end, nil, nil, nil, push_tag)
end
```

---

## Pattern 4: Status Effects with Stacking

**Use Case**: Buffs/debuffs that stack and refresh duration

```lua
-- Status effect system
StatusEffects = {}

function StatusEffects.apply(entity, effect_name, duration, on_start, on_end)
  local key = "status_" .. effect_name .. "_" .. entity.id

  -- Check if already active
  local was_active = entity[effect_name .. "_active"]

  if not was_active then
    -- First application
    entity[effect_name .. "_stacks"] = 1
    entity[effect_name .. "_active"] = true
    if on_start then on_start(entity) end
  else
    -- Stack increment
    entity[effect_name .. "_stacks"] = (entity[effect_name .. "_stacks"] or 1) + 1
  end

  -- Cancel existing timer and restart
  timer.cancel(key)
  timer.after(duration, function()
    -- Remove effect
    entity[effect_name .. "_active"] = false
    entity[effect_name .. "_stacks"] = 0
    if on_end then on_end(entity) end
  end, key)
end

-- Example: Poison stacking
function apply_poison(entity)
  StatusEffects.apply(entity, "poisoned", 5.0,
    function(e)  -- on_start
      e.poison_color = {r=0, g=1, b=0}
      -- Start DOT
      timer.every(0.5, function()
        local stacks = e.poisoned_stacks or 1
        deal_damage(e, 5 * stacks)
      end, nil, nil, nil, "poison_dot_" .. e.id)
    end,
    function(e)  -- on_end
      e.poison_color = nil
      timer.cancel("poison_dot_" .. e.id)
    end
  )
end
```

---

## Pattern 5: Boss Phase Transitions

**Use Case**: Multi-phase boss fights with health thresholds

```lua
function setup_boss(boss)
  boss.phase = 1
  boss.phase_changed = false

  -- Check health every frame
  timer.every(0.1, function()
    -- Phase 2 at 60% HP
    if boss.health_percent < 0.60 and boss.phase == 1 then
      transition_to_phase(boss, 2)
    end

    -- Phase 3 at 30% HP
    if boss.health_percent < 0.30 and boss.phase == 2 then
      transition_to_phase(boss, 3)
    end
  end, nil, nil, nil, "boss_phase_monitor_" .. boss.id)
end

function transition_to_phase(boss, new_phase)
  if boss.phase_changing then return end  -- Prevent double-trigger

  boss.phase_changing = true

  -- Cancel old attacks
  timer.cancel("boss_attack_pattern_" .. boss.id)

  -- Transition sequence
  boss.invulnerable = true
  play_cutscene("phase_transition")

  timer.after(2.0, function()
    -- Apply phase changes
    boss.phase = new_phase
    boss.speed = boss.speed * 1.3
    boss.damage = boss.damage * 1.5

    -- Start new attack pattern
    if new_phase == 2 then
      setup_phase2_attacks(boss)
    elseif new_phase == 3 then
      setup_phase3_attacks(boss)
    end

    boss.invulnerable = false
    boss.phase_changing = false
  end)
end

function setup_phase2_attacks(boss)
  -- New attack pattern for phase 2
  timer.every(4.0, function()
    if boss.stunned then return end

    -- More aggressive pattern
    timer.during(1.5,
      function(dt)  -- During (telegraph)
        boss.telegraph_radius = boss.telegraph_radius + dt * 100
      end,
      function()    -- After (release)
        spawn_projectile_ring(boss, 12)
        boss.telegraph_radius = 0
      end
    )
  end, nil, nil, nil, "boss_attack_pattern_" .. boss.id)
end
```

---

## Pattern 6: Multi-Stage Ability

**Use Case**: Abilities with distinct stages (wind-up, execute, recovery)

```lua
function execute_multi_stage_ability(caster)
  local stages = {
    {name = "wind_up",  duration = 0.8, color = {1,1,0}},
    {name = "execute",  duration = 0.2, color = {1,0,0}},
    {name = "recovery", duration = 1.0, color = {0.5,0.5,0.5}}
  }

  local stage_index = 1

  local function run_stage()
    if stage_index > #stages then
      caster.ability_active = false
      return
    end

    local stage = stages[stage_index]
    caster.current_stage = stage.name
    caster.color = stage.color

    if stage.name == "execute" then
      -- Critical moment
      perform_attack(caster)
      caster.vulnerable = true
    elseif stage.name == "recovery" then
      caster.vulnerable = false
    end

    timer.after(stage.duration, function()
      stage_index = stage_index + 1
      run_stage()
    end)
  end

  caster.ability_active = true
  run_stage()
end
```

---

## Pattern 7: Timed Invulnerability

**Use Case**: I-frames after taking damage, dodge rolls, parries

```lua
function grant_invulnerability(entity, duration, flash_effect)
  entity.invulnerable = true
  entity.invuln_start = game_time

  if flash_effect then
    -- Flashing effect
    timer.every(0.1, function()
      entity.visible = not entity.visible
    end, math.floor(duration / 0.1), nil, nil, "invuln_flash_" .. entity.id)
  end

  timer.after(duration, function()
    entity.invulnerable = false
    entity.visible = true
  end, "invuln_timer_" .. entity.id)
end

-- Extend invulnerability (e.g., picking up powerup during i-frames)
function extend_invulnerability(entity, extra_time)
  if not entity.invulnerable then return false end

  local tag = "invuln_timer_" .. entity.id
  local remaining = timer.get_remaining_time(tag)

  if remaining then
    timer.cancel(tag)
    grant_invulnerability(entity, remaining + extra_time, true)
    return true
  end
  return false
end
```

---

## Pattern 8: Buff/Debuff Pipeline

**Use Case**: Multiplicative stat modifiers with automatic cleanup

```lua
-- Modifier system
Modifiers = {
  active = {}  -- Track all active modifiers
}

function Modifiers.apply(entity, stat_name, multiplier, duration, tag)
  tag = tag or ("mod_" .. stat_name .. "_" .. math.random(1000000))

  -- Store modifier
  Modifiers.active[tag] = {
    entity = entity,
    stat = stat_name,
    mult = multiplier,
    expires = game_time + duration
  }

  -- Recalculate stats
  entity:recalculate_stats()

  -- Auto-remove after duration
  timer.after(duration, function()
    Modifiers.active[tag] = nil
    entity:recalculate_stats()
  end, tag)

  return tag
end

-- Example entity stat calculation
function Entity:recalculate_stats()
  self.final_speed = self.base_speed
  self.final_damage = self.base_damage
  self.final_defense = self.base_defense

  -- Apply all active modifiers
  for tag, mod in pairs(Modifiers.active) do
    if mod.entity == self then
      self["final_" .. mod.stat] = self["final_" .. mod.stat] * mod.mult
    end
  end
end

-- Usage examples
Modifiers.apply(player, "speed", 1.5, 5.0, "speed_boost_powerup")
Modifiers.apply(enemy, "defense", 0.5, 3.0, "armor_break_debuff")
```

---

## Pattern 9: Combo Window

**Use Case**: Timed input sequences, fighting game combos

```lua
function setup_combo_system(player)
  player.combo_count = 0
  player.combo_window_open = false

  return {
    start_combo = function()
      player.combo_count = 1
      player.combo_window_open = true

      -- First hit opens window
      timer.after(0.8, function()
        if player.combo_count == 1 then
          -- Missed follow-up
          reset_combo(player)
        end
      end, "combo_window")
    end,

    continue_combo = function()
      if not player.combo_window_open then
        return false  -- Too late
      end

      player.combo_count = player.combo_count + 1
      timer.cancel("combo_window")  -- Reset window

      -- Each hit extends window slightly
      local window_time = math.max(0.4, 0.8 - player.combo_count * 0.05)

      timer.after(window_time, function()
        -- Combo finished
        execute_finisher(player, player.combo_count)
        reset_combo(player)
      end, "combo_window")

      return true
    end
  }
end

function reset_combo(player)
  player.combo_count = 0
  player.combo_window_open = false
  timer.cancel("combo_window")
end
```

---

## Pattern 10: Conditional Loop (until dead)

**Use Case**: AI behaviors that repeat while entity is alive

```lua
function setup_enemy_ai(enemy)
  local ai_tag = "ai_loop_" .. enemy.id

  -- Patrol behavior
  timer.every(2.0, function()
    -- Exit condition: entity died
    if enemy.dead or enemy.health <= 0 then
      timer.cancel(ai_tag)
      return
    end

    -- Exit condition: player out of range
    local dist = distance_to_player(enemy)
    if dist > 500 then
      return  -- Skip this tick
    end

    -- Actual behavior
    if dist < 100 then
      -- Close range: melee attack
      perform_melee(enemy)
    elseif dist < 300 then
      -- Mid range: shoot
      timer.after(0.5, function()  -- Wind-up
        if not enemy.dead then
          shoot_projectile(enemy)
        end
      end)
    else
      -- Far range: move closer
      move_towards_player(enemy)
    end
  end, nil, nil, nil, ai_tag)
end
```

---

## Best Practices

### 1. Always Tag Your Timers
```lua
-- Bad: Hard to cancel or query
timer.after(5.0, function() attack() end)

-- Good: Can cancel, extend, or query
timer.after(5.0, function() attack() end, "boss_ultimate")
```

### 2. Use Groups for Batch Control
```lua
-- Create timers in groups
timer.every(1.0, fn, nil, nil, nil, "ai_" .. id, "enemy_ai")

-- Pause all enemy AI at once
timer.pause_group("enemy_ai")
```

### 3. Handle Early Exits
```lua
timer.for_time(5.0, function(dt)
  if entity.dead then
    return "break"  -- Early exit
  end
  -- Update logic
end)
```

### 4. Preserve Context with Closures
```lua
-- Good: Captures entity reference
function setup_ability(entity)
  timer.every(3.0, function()
    entity:cast_spell()  -- entity is captured
  end)
end

-- Avoid: Global lookup
function setup_ability(entity_id)
  timer.every(3.0, function()
    local e = find_entity(entity_id)  -- Slower
    if e then e:cast_spell() end
  end)
end
```

### 5. Visualize with Progress Extraction
```lua
-- Telegraph with progress bar
local t, c = timer.get_timer_and_delay("boss_charge")
if c and c > 0 then
  local progress = t / c
  draw_charge_bar(boss.x, boss.y, progress)
end
```

---

## When NOT to Use Timer-Based FSMs

**Use explicit state enums when**:
1. **Many transitions** between states (>5 states with complex edges)
2. **State persistence** required (save/load game state)
3. **External queries** frequent (UI needs to check "what state is X in?")
4. **Debugging complexity** (need state machine visualizer)

**Example where explicit FSM is better**:
```lua
-- Menu system with many states
MenuState = {
  MAIN_MENU = 1,
  OPTIONS = 2,
  GRAPHICS = 3,
  AUDIO = 4,
  CONTROLS = 5,
  GAMEPLAY = 6,
  PAUSED = 7
}
-- Too many states with arbitrary transitions
```

---

## References

- Core timer API: `timer_docs.md`
- SNKRX combat patterns: `SNKRX_code_snippets_and_techniques.md`
- emoji-merge analysis: `../EMOJI_MERGE_TECHNIQUES_ANALYSIS.md`

---

*Last updated: 2025-11-21*
