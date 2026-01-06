# Path of Achra: Triggers & Events Reference

## Overview

Path of Achra's core mechanic is **event-driven abilities**. Unlike games with active abilities, almost everything is triggered by events. This document catalogs all triggers for implementation in a survivors-like game.

---

## Event System Architecture

### How Events Work

1. **Player takes action** (attack, step, pray, stand still)
2. **Game checks all abilities** for matching triggers
3. **Triggered abilities execute** in priority order
4. **Abilities can create more events**, causing chain reactions
5. **Chains continue** until no more triggers fire

**Key Design Insight**: "Infinite" loops are prevented by design. Chains eventually end when all enemies die or no more triggers match.

---

## Complete Trigger List

### Turn Action Triggers

| Trigger | When It Fires | Common Uses |
|---------|---------------|-------------|
| `on_attack` | Player performs any attack | Extra damage, bonus effects |
| `on_initial_attack` | Player takes attack turn action (not extra attacks) | First-strike bonuses |
| `on_adjacent_attack` | Attack against adjacent enemy | Melee bonuses |
| `on_non_adjacent_attack` | Attack against non-adjacent enemy | Ranged bonuses |
| `on_step` | Player moves to adjacent tile | Movement rewards |
| `on_pray` / `on_prayer` | Player uses a prayer | Prayer synergies |
| `on_stand_still` | Player does nothing | Meditation, charging |

### Attack Sequence Triggers

The attack sequence fires triggers in this specific order:

```
1. on_initial_attack / on_attack
2. target's on_being_attacked
3. DODGE CHECK → on_dodge (if dodged, sequence ends)
4. BLOCK CHECK → on_block (if blocked, sequence ends)
5. ARMOR CHECK → on_shrug_off (if negated, sequence ends)
6. on_hit (attack connected)
7. target's on_being_hit
8. DAMAGE → on_dealing_damage / on_being_dealt_damage
```

| Trigger | When It Fires | Notes |
|---------|---------------|-------|
| `on_being_attacked` | Enemy attacks this unit | Defensive prep, counter-attack setups |
| `on_dodge` | Attack dodged via Dodge stat | Evasion rewards |
| `on_block` | Attack blocked via Block stat | Shield-style builds |
| `on_shrug_off` | Attack negated by Armor | Tank builds |
| `on_hit` | Attack successfully connects | Damage bonuses, on-hit effects |
| `on_being_hit` | Unit successfully hit | Damage mitigation, revenge |
| `on_dealing_damage` | Damage dealt to any target | Generic damage triggers |
| `on_being_dealt_damage` | Damage received from any source | Damage-triggered abilities |

### Hit Triggers (Detailed)

| Trigger | When It Fires | Notes |
|---------|---------------|-------|
| `on_hit` | Any hit (attack or direct hit ability) | Universal hit trigger |
| `on_adjacent_hit` | Hit on adjacent target | Melee-specific |
| `on_non_adjacent_hit` | Hit on non-adjacent target | Ranged-specific |
| `on_being_hit` | Being hit by enemy | Defense trigger |
| `on_being_hit_by_adjacent` | Being hit by adjacent enemy | Melee defense |
| `on_ally_hitting` | Ally successfully hits | Summoner synergies |

### Damage Triggers

| Trigger | When It Fires | Notes |
|---------|---------------|-------|
| `on_dealing_damage` | Any damage dealt | Most common damage trigger |
| `on_dealing_<type>_damage` | Damage of specific type dealt | Element-specific builds |
| `on_dealing_damage_to_ally` | Friendly fire | Dark magic builds |
| `on_being_dealt_damage` | Any damage received | Universal defense |
| `on_being_dealt_damage_by_enemies` | Damage from enemies only | Excludes self-damage |
| `on_self_damage` / `on_dealing_self_damage` | Self-inflicted damage | Blood magic, berserker |

### Death Triggers

| Trigger | When It Fires | Notes |
|---------|---------------|-------|
| `on_kill` | Unit kills anything | Generic kill reward |
| `on_killing_enemy` | Unit kills an enemy | Combat rewards |
| `on_enemy_death` | Any enemy dies | AoE kill detection |
| `on_ally_death` | Ally unit dies | Summoner synergies, death magic |
| `on_death` | This unit dies | Last stand abilities |

### Defensive Triggers

| Trigger | When It Fires | Notes |
|---------|---------------|-------|
| `on_shrug_off` | Attack negated by Armor | Tank/heavy armor |
| `on_block` | Attack blocked | Shield builds |
| `on_dodge` | Attack dodged | Evasion builds |
| `on_adjacent_shrug_off` | Adjacent attack negated | Melee defense |
| `on_adjacent_block` | Adjacent attack blocked | Shield wall |
| `on_adjacent_dodge` | Adjacent attack dodged | Dancing fighter |

### Progression Triggers

| Trigger | When It Fires | Notes |
|---------|---------------|-------|
| `on_entrance` | Enter new level/room | Start-of-level buffs, summons |
| `on_glory_rising` | Glory (progression) increases | Permanent upgrades |
| `on_divine_intervention` | Religion-specific event | Ultimate abilities |
| `on_learn` | Gain/level up power | Skill acquisition |

### Status Effect Triggers

| Trigger | When It Fires | Notes |
|---------|---------------|-------|
| `on_apply_<effect>` | Specific effect applied | Effect synergies |
| `on_heal` | Unit healed | Healing amplification |
| `on_summon` | Summon created | Summoner builds |
| `on_teleport` | Unit teleports | Blink builds |
| `on_any_unit_teleport` | Any teleport on level | Teleport synergy |

### Item/Equipment Triggers

| Trigger | When It Fires | Notes |
|---------|---------------|-------|
| `on_picking_up_item` | Item acquired | Collectors |
| `on_picking_up_<type>_item` | Specific item type acquired | Build-specific |
| `on_sacrifice` | Item sacrificed | Goblin-style upgrades |
| `on_transforming_item` | Item transformed | Metamorphosis builds |

### Game Timing Triggers

| Trigger | When It Fires | Notes |
|---------|---------------|-------|
| `on_game_turn` | Game turn passes | Passive regeneration, auto-effects |

---

## Conditionals (Trigger Modifiers)

Many triggers have conditions that must be met:

### Equipment Conditionals

| Condition | Meaning |
|-----------|---------|
| `if Two-handing` | Only Main-hand weapon equipped |
| `if Single-handing` | Using one weapon or dual-wield |
| `per empty armor slot` | Effect scales with missing armor |
| `if chest armor empty` | No chest armor equipped |
| `if Bare Fist` | No weapon in hand (or fist weapon) |

### State Conditionals

| Condition | Meaning |
|-----------|---------|
| `if enemies live` | At least one enemy alive |
| `if Encumbered` | Encumbrance > Strength |
| `if Unencumbered` | Encumbrance <= Strength |
| `if Inflexible` | Inflexibility > 1 |
| `if Flexible` | Inflexibility == 1 |

### Effect Conditionals

| Condition | Meaning |
|-----------|---------|
| `if you have <effect>` | Must have effect active |
| `per fully charged prayer` | Per prayer at max charges |
| `per <effect> stack` | Scales with stack count |
| `per item in bag` | Scales with inventory |

---

## Trigger Frequency Analysis (From Classes/Cultures)

| Trigger | Class Uses | Culture Uses | Total |
|---------|------------|--------------|-------|
| `on_entrance` | 7 | 4 | 11 |
| `on_prayer` | 7 | 4 | 11 |
| `on_attack` | 6 | 3 | 9 |
| `on_stand_still` | 6 | 3 | 9 |
| `on_game_turn` | 3 | 3 | 6 |
| `on_step` | 3 | 2 | 5 |
| `on_hit` | 3 | 2 | 5 |
| `on_being_attacked` | 3 | 2 | 5 |
| `on_being_dealt_damage` | 0 | 4 | 4 |
| `on_kill` | 1 | 0 | 1 |
| `on_block/dodge` | 1 | 1 | 2 |
| `on_shrug_off` | 1 | 0 | 1 |
| `on_Glory_rising` | 1 | 0 | 1 |
| `on_ally_death` | 1 | 1 | 2 |
| `on_divine_intervention` | 1 | 1 | 2 |
| `on_teleport` | 0 | 1 | 1 |
| `on_sacrifice` | 0 | 1 | 1 |

---

## Survivors-like Trigger Recommendations

### Essential Triggers (Must Have)

These are the minimum triggers needed for a solid survivors-like game:

| Trigger | Priority | Implementation Complexity |
|---------|----------|--------------------------|
| `on_attack` | Critical | Low - fire on every attack |
| `on_hit` | Critical | Low - fire when damage connects |
| `on_kill` | Critical | Low - fire on enemy death |
| `on_step` / `on_move` | High | Low - fire on movement |
| `on_being_dealt_damage` | High | Low - fire when player takes damage |
| `on_game_turn` / `on_tick` | High | Low - periodic timer |

### Recommended Triggers (Should Have)

| Trigger | Priority | Implementation Complexity |
|---------|----------|--------------------------|
| `on_entrance` / `on_wave_start` | High | Low - fire at wave/level start |
| `on_dodge` / `on_block` | Medium | Medium - requires evasion system |
| `on_enemy_death` | Medium | Low - different from on_kill (any enemy) |
| `on_summon` | Medium | Medium - requires summon system |
| `on_heal` | Medium | Low - fire on heal events |
| `on_apply_<effect>` | Medium | Medium - per status effect |

### Advanced Triggers (Nice to Have)

| Trigger | Priority | Implementation Complexity |
|---------|----------|--------------------------|
| `on_crit` | Low | Medium - requires crit system |
| `on_chain_hit` | Low | Medium - requires chain mechanics |
| `on_projectile_hit` | Low | Low - projectile collision events |
| `on_teleport` | Low | Medium - requires teleport system |
| `on_mark_detonated` | Low | Medium - requires mark system |
| `on_combo` | Low | High - requires combo tracking |

---

## Your Current Codebase: Supported Triggers

Based on the codebase analysis, your game already supports:

### Combat Bus Events (EventBus)
```lua
'OnCast'           -- When spell/ability cast
'OnHitResolved'    -- Damage connected
'OnDeath'          -- Unit died
'OnStatusApplied'  -- Effect applied
'OnStatusRemoved'  -- Effect removed
'OnBuffApplied'    -- Buff applied
'OnResurrect'      -- Unit revived
'OnExtraTurnGranted' -- Bonus action
'OnRRApplied'      -- Resistance reduction
'OnMiss'           -- Attack missed
'OnDodge'          -- Attack dodged
'OnHealed'         -- Unit healed
'OnDotApplied'     -- DoT applied
'OnCounterAttack'  -- Counter triggered
'OnProvoke'        -- Taunt
'OnBasicAttack'    -- Standard attack
'OnStatusExpired'  -- Effect wore off
'OnDotExpired'     -- DoT ended
'OnTick'           -- Time tick
'OnExperienceGained' -- XP gained
'OnLevelUp'        -- Level up
```

### Signal Events (Global)
```lua
"enemy_spawned"
"enemy_killed"
"projectile_spawned"
"projectile_hit"
"projectile_exploded"
"stage_started"
"wave_started"
"wave_cleared"
"elite_spawned"
"stage_completed"
"show_rewards"
"run_complete"
"goto_shop"
"player_died"
"show_death_screen"
"stats_recomputed"
```

### Joker Events
```lua
"on_spell_cast"
"calculate_damage"
"on_player_damaged"
"on_chain_hit"
"on_mark_detonated"
"on_dot_tick"
```

---

## Triggers NOT Yet Supported (Gap Analysis)

These Path of Achra triggers would need implementation:

| Trigger | Difficulty | Notes |
|---------|------------|-------|
| `on_step` | Easy | Hook to player movement |
| `on_stand_still` | Easy | Detect no-action frames |
| `on_entrance` | Easy | Hook to level/wave start |
| `on_block` | Medium | Need block system |
| `on_shrug_off` | Medium | Need armor negation |
| `on_glory_rising` | Easy | Hook to progression |
| `on_divine_intervention` | Medium | Need religion system |
| `on_prayer` | Medium | Need prayer/ability system |
| `on_sacrifice` | Medium | Need item sacrifice |
| `on_teleport` | Medium | Need teleport system |
| `on_picking_up_item` | Easy | Hook to item pickup |

---

## Implementation Patterns

### Pattern 1: Simple Event Hook

```lua
-- In your event system
signal.register("player_step", function(entity, dx, dy)
    for _, joker in ipairs(player.jokers) do
        if joker.triggers.on_step then
            joker.triggers.on_step(entity, dx, dy)
        end
    end
end)
```

### Pattern 2: Priority-Based Processing

```lua
-- Combat bus with priorities
local EventBus = {}
EventBus.handlers = {}

function EventBus:on(event, priority, handler)
    self.handlers[event] = self.handlers[event] or {}
    table.insert(self.handlers[event], { priority = priority, fn = handler })
    table.sort(self.handlers[event], function(a, b) return a.priority > b.priority end)
end

function EventBus:emit(event, data)
    for _, handler in ipairs(self.handlers[event] or {}) do
        handler.fn(data)
    end
end
```

### Pattern 3: Conditional Triggers

```lua
-- Trigger with conditions
function evaluate_trigger(trigger, context)
    if trigger.condition then
        if trigger.condition == "two_handing" and not is_two_handing(context.caster) then
            return false
        end
        if trigger.condition == "enemies_live" and enemy_count() == 0 then
            return false
        end
        -- etc.
    end
    return true
end
```

### Pattern 4: Chain Reaction System

```lua
-- Allow triggered effects to trigger more effects
local processing_queue = {}
local max_chain_depth = 100

function process_event(event, data, depth)
    if depth > max_chain_depth then return end  -- Prevent infinite loops
    
    for _, ability in ipairs(get_abilities_for_event(event)) do
        local result = ability.execute(data)
        
        -- Results can queue more events
        if result.trigger_event then
            table.insert(processing_queue, {
                event = result.trigger_event,
                data = result.trigger_data,
                depth = depth + 1
            })
        end
    end
end

function process_all_events()
    while #processing_queue > 0 do
        local queued = table.remove(processing_queue, 1)
        process_event(queued.event, queued.data, queued.depth)
    end
end
```

---

## Design Recommendations for Survivors-like

### Start With These Triggers

1. **`on_kill`** - Most satisfying, rewards killing
2. **`on_step`/`on_move`** - Essential for movement builds
3. **`on_hit`** - Core combat trigger
4. **`on_tick`/`on_game_turn`** - Passive effects
5. **`on_wave_start`** - Wave-based buffs

### Add These For Depth

6. **`on_crit`** - Critical hit builds
7. **`on_dodge`** - Evasion builds
8. **`on_low_health`** - Berserker builds
9. **`on_projectile_hit`** - Projectile builds
10. **`on_chain`** - Chain lightning builds

### Trigger Scaling Patterns

- **Per kill**: +X damage per kill this wave
- **Per step**: +X speed after N steps
- **Per hit**: +X stacks, consumed for burst
- **Per tick**: Regeneration, DoT application
- **Per wave**: Permanent upgrades
