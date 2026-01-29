# Wand Build Reference - Q&A and Clarifications

This document addresses your questions about the [wand_build_reference.md](file:///Users/joshuashin/.gemini/antigravity/brain/b44d73a3-d05d-49da-87e9-66944d1d4423/wand_build_reference.md) design.

---

## 1. Avatars as Masks

> **Your Note**: "could take the form of masks. I have attached one to the player right now, but I want to take it off for now. and don't make them move as heavily though with the mask on.. not sure why it does that- added mass?"

**Clarification**: 
- **Visual Form**: Avatars could use mask sprites/models as a cosmetic indicator of which "ascension" you've unlocked
- **Current Technical Issue**: You have a mask entity attached to the player that's causing movement issues
- **Likely Cause**: The mask physics body might have mass that's affecting the player's total mass calculation, making movement feel sluggish
- **Solution**: Either:
  - Make the mask purely visual (no physics body)
  - Set the mask's mass to 0 if using a physics body
  - Use a visual-only child entity/sprite instead of a full physics entity

**Question**: Would you like help removing/disabling the current mask implementation?

---

## 2. Wand Core as Equipment Slot

> **Your Comment**: "Not really clear on what this means."

**Clarification**:
Instead of treating the "wand core" as a completely separate system, treat it as just another equipment slot like `relic`, `charm`, or `tome`.

**Example**:
```lua
-- Current approach (separate system):
player.wand_core = { type = "ember_core", bonus = "+10% fire damage" }
player.equipped = { relic = {...}, charm = {...} }

-- Proposed approach (unified):
player.equipped = {
  wand_core = { type = "ember_core", bonus = "+10% fire damage" },
  relic = {...},
  charm = {...},
  tome = {...}
}
```

**Benefits**:
- Reuses existing equipment system logic
- No separate wand-core-specific code
- Can use same stat mod, proc, and resonance hooks as other gear

---

## 3. Tag-Scaling Procs & Spell Mutators - Examples

> **Your Comment**: "more examples of this would be nice."

### Tag-Scaling Proc Examples

**Relic Example - "Pyromancer's Pendant"**:
```lua
{
  name = "Pyromancer's Pendant",
  slot = "relic",
  
  -- (a) 1 stat mod
  stats = { spirit = 5 },
  
  -- (b) 1 tag-scaling proc
  tag_proc = {
    condition = function(deck)
      return deck.tag_counts.Fire or 0
    end,
    effect = function(fire_count)
      -- Every Fire tag adds 2% burn damage
      return { burn_damage_pct = fire_count * 2 }
    end
  },
  
  -- (c) resonance hook
  resonance = {
    condition = function(deck)
      return (deck.tag_counts.Fire or 0) >= 6
    end,
    effect = "burn_spreads_on_kill" -- spreads to 1 nearby enemy
  }
}
```

### Spell Mutator Examples

**Charm Example - "Echo Crystal"**:
```lua
{
  name = "Echo Crystal",
  slot = "charm",
  
  stats = { cast_speed = 0.15 },
  
  -- Mutator wraps spell effects
  spell_mutator = {
    target_spell = "any_projectile", -- or specific spell ID
    priority = 10,
    wrap = function(original_effect_fn)
      return function(ctx, src, tgt)
        -- Cast the original effect
        original_effect_fn(ctx, src, tgt)
        
        -- If you have 3+ Arcane tags, echo it after 0.5s
        if (src.deck.tag_counts.Arcane or 0) >= 3 then
          ctx.bus:emit("delayed_cast", {
            delay = 0.5,
            spell_fn = original_effect_fn,
            source = src,
            target = tgt,
            power = 0.5 -- 50% power on echo
          })
        end
      end
    end
  }
}
```

---

## 4. Combat System Readiness for Prayers

> **Your Comment**: "I want to understand how equipped we are to do this right now with combat_system.lua in a simple way. it's a bit hard to work with at the moment."

**Current State Analysis**:

Your [combat_system.lua](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/combat/combat_system.lua) has:

✅ **What You Have**:
- EventBus system (lines 1-100+) for emitting events
- Spell mutator pipeline (`apply_spell_mutators` around line 206)
- Status/buff system (`StatusEngine`)
- Effect application framework

❌ **What Needs Simplification**:
- The file is 5,811 lines - very complex
- Effects API is not clearly documented
- No simple "add a spell" template

**Recommended Approach for Prayers**:

Create a simpler prayer-specific wrapper:

```lua
-- In a new file: prayer_system.lua
local Prayers = {}

function Prayers.register(prayer_def)
  -- prayer_def = {
  --   id = "ember_psalm",
  --   cooldown = 30,
  --   effect = function(ctx, caster)
  --     -- Your simple effect code here
  --   end
  -- }
  Content.Prayers = Content.Prayers or {}
  Content.Prayers[prayer_def.id] = prayer_def
end

function Prayers.cast(ctx, caster, prayer_id)
  local prayer = Content.Prayers[prayer_id]
  if not prayer then return false end
  
  -- Check cooldown
  local ready_time = caster.timers and caster.timers[prayer_id] or 0
  if ctx.time.now < ready_time then
    return false -- on cooldown
  end
  
  -- Execute effect
  prayer.effect(ctx, caster)
  
  -- Set cooldown
  caster.timers = caster.timers or {}
  caster.timers[prayer_id] = ctx.time.now + prayer.cooldown
  
  return true
end

return Prayers
```

**Question**: Would you like me to create a simplified prayer system that sits on top of your combat_system.lua?

---

## 5. Ritual Triggers (Pay HP/Gold)

> **Your Comment**: "this sounds really nice. we should explore this. is this manually activated?"

**Clarification**:

**Ritual triggers are NOT manually activated** - they're still automatic triggers like the others, but they have a **resource cost** to fire.

### How It Works

From [TODO_design.md](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/docs/project-management/todos/TODO_design.md), your trigger types (lines 134-143) include:
- Time-based (every N seconds)
- Event-based (on kill, on hit, on movement)
- **Ritual**: Automatic but costs HP or gold to trigger

### Example Ritual Trigger

```lua
{
  type = "ritual",
  trigger_condition = "on_kill", -- Still triggers on kills
  cost = { hp_pct = 5 }, -- But costs 5% current HP each time
  
  -- The wand stack that fires
  cards = {
    { action = "blood_explosion", modifier = "increased_radius" }
  }
}
```

**Risk/Reward**:
- **Risk**: Lose HP every time it triggers (dangerous if you get many kills quickly)
- **Reward**: More powerful effects than normal triggers, or can trigger more frequently

**Alternative - Manual Activation**:
If you want manual prayers (like your "Ember Psalm"), those would be separate from wand triggers - they'd be bound to a button press, not automatic wand execution.

---

## 6. Tag Breakpoints (3/5/7/9)

> **Your Comment**: "Not really clear what this means."

**Clarification**:

"Breakpoints" = thresholds where you unlock bonuses based on **how many cards with a specific tag** you have in your deck.

### Example from TODO_design.md

If you have **Fire** tagged cards in your wand:

- **3 Fire tags**: Burn tick damage +10%
- **5 Fire tags**: Burn tick rate +15%  
- **7 Fire tags**: Burn explosions on kill (small AoE, 1s cooldown)
- **9 Fire tags**: Burn spreads to nearby target (50% strength)

### How It Works

```lua
-- During wand deck snapshot
function evaluate_tag_bonuses(deck)
  local tag_counts = {}
  
  -- Count tags across all cards
  for _, card in ipairs(deck.cards) do
    for _, tag in ipairs(card.tags) do
      tag_counts[tag] = (tag_counts[tag] or 0) + 1
    end
  end
  
  -- Check Fire breakpoints
  local fire_count = tag_counts.Fire or 0
  if fire_count >= 3 then
    player.stats:add("burn_damage_pct", 10)
  end
  if fire_count >= 5 then
    player.stats:add("burn_tick_rate_pct", 15)
  end
  if fire_count >= 7 then
    player:enable_proc("burn_explosion_on_kill")
  end
  if fire_count >= 9 then
    player:enable_proc("burn_spread")
  end
end
```

**Benefits**:
- Encourages specialization (stack Fire cards to unlock Fire bonuses)
- No complex skill tree needed
- Universal thresholds across all tag types

---

## 7. Resonance Pairs - Scope

> **Your Comment**: "so if a wand has this pair, then the effect applies to all wands, or only the wand in question?"

**Clarification**: Effects apply **player-wide, not per-wand**.

### Example

If you have:
- **3+ Fire tags** across your deck (any wand)
- **3+ Mobility tags** across your deck (any wand)

Then the **Fire+Mobility resonance** unlocks: "dashes ignite ground"

This affects **all your dashes**, regardless of which wand they came from.

### Why Player-Wide?

- Simpler to implement (one check, not per-wand checks)
- Encourages diverse card choices across multiple wands
- Avoids "which wand unlocked this?" confusion

### Data Structure

```lua
-- Check once per combat update
function check_resonances(player)
  local tags = player.deck_snapshot.tag_counts
  
  -- Fire+Mobility
  if (tags.Fire or 0) >= 3 and (tags.Mobility or 0) >= 3 then
    player:enable_global_effect("dash_ignites_ground")
  end
  
  -- Poison+Summon  
  if (tags.Poison or 0) >= 3 and (tags.Summon or 0) >= 3 then
    player:enable_global_effect("minion_hits_extend_poison")
  end
end
```

---

## 8. Avatar Unlocks in Swappable Systems

> **Your Comment**: "wondering how we'll make avatar unlocks natural. path of achra doesn't allow changing skills once you learn them, and avatars are based on that. but in my game, you could swap out every spell when you like."

**Great Question!** This is a key design challenge.

### Option A: Session-Based Unlocks (Recommended)

Avatars unlock **during a run** and persist **only for that run**:

```lua
-- During a run, once you meet conditions:
if player.kills >= 100 and player.deck.tag_counts.Fire >= 7 then
  unlock_avatar(player, "wildfire")
end

-- Avatar effects active until run ends
-- Next run starts fresh
```

**Pros**:
- Swapping cards doesn't break anything
- Each run builds toward an avatar unlock
- Feels like a progression milestone within the run

**Cons**:
- Lose avatar between runs

---

### Option B: Meta-Progression Unlocks

Avatars unlock **permanently** once conditions met across any run:

```lua
-- Unlock condition (meta):
if player.total_lifetime_kills_with_fire >= 500 then
  player.unlocked_avatars.wildfire = true
end

-- During run - avatar active if you CURRENTLY meet requirements
if player.unlocked_avatars.wildfire 
   and player.deck.tag_counts.Fire >= 7 then
  apply_avatar_effect(player, "wildfire")
end
```

**Pros**:
- Permanent progression feels rewarding
- Can swap cards, but lose avatar bonus if you drop below threshold
- Encourages maintaining tag counts even when swapping

**Cons**:
- More complex to track
- Can feel punishing if you swap cards and lose avatar

---

### Option C: Avatar Slots (Hybrid)

Unlock avatars permanently, but **equip one** at run start:

```lua
-- Run start:
player:equip_avatar("wildfire") -- Locked in for this run

-- Avatar modifies rules globally, regardless of current deck
-- Can't change mid-run
```

**Pros**:
- Commit to playstyle at run start
- Can swap cards freely without losing avatar
- Clear "build identity"

**Cons**:
- Less dynamic than Option A

---

**My Recommendation**: **Option A (Session-Based)** fits best with your swappable card system. Avatars become the "late-run power spike" you work toward, and swapping cards is a strategic choice (do I keep Fire cards to maintain my avatar bonus, or pivot to Ice?).

---

## 9. Ember Nomad Example Elaboration

> **Your Comment**: "Can you elaborate on this?"

### Full Build Breakdown

**Ember Nomad** = Origin choice (culture/race)
- Passive: +10% Fire damage, +5% Hazard duration
- Prayer: "Ember Psalm" (30s cooldown) - next 3 actions leave fire hazards
- Tag bias: Shop offers slightly more Fire/Hazard cards

**Fanatic Frame** = Wand template choice
- `cast_block_size = 2` (only casts 2 cards at a time)
- `shuffle = false` (predictable order)
- `overheat_cap = 50` (low threshold)
- `trigger_type = "time"` (casts every 3 seconds)

**Arcane Discipline** = School choice
- Locks you into ~6 Arcane actions + ~6 Arcane mods
- Example actions: Chain Lightning, Arcane Missile, Rift Bolt
- Example mods: +1 Chain, Echo, Repeat

**Avatar "Wildfire"** = Late-run unlock
- **Unlock condition**: Kill 100 enemies with fire damage, OR reach 7+ Fire tags
- **Effect 1**: "Multicast becomes loop" - if you have a multicast mod, it now loops the cast block once (so 2 cards become 4 casts)
- **Effect 2**: "Hazards tick faster" - all fire hazards tick 2x speed

### How It Plays

**Early Run**:
1. Every 3 seconds, wand fires 2 cards in order
2. Example cast: `Chain Lightning → Echo Mod` = lightning chains to 2 targets, then echoes
3. Use "Ember Psalm" prayer when surrounded (next 3 casts leave fire puddles)

**Late Run (Avatar Unlocked)**:
1. Same wand, but now multicast loops
2. Example cast: `Multicast Mod → Chain Lightning` = casts Chain Lightning 4 times (2x2 loop)
3. Fire hazards you leave now tick every 0.5s instead of 1s

---

## 10. Plague Scribe Example Clarification

> **Your Comment**: "not too clear on this either."

### Full Build Breakdown

**Plague Scribe** = Origin
- Passive: +15% Poison duration, +10 max poison stacks
- Prayer: "Contagion" (45s cooldown) - spreads all poison stacks to nearby enemies
- Tag bias: Poison + Arcane

**Scatter Frame** = Wand template
- `cast_block_size = 5` (casts 5 cards)
- `shuffle = true` (cards fire in random order)
- `spread = wide` (projectiles spread out like a shotgun)
- `trigger_type = "movement"` (fires every 10 meters moved)

**Mobility Discipline** = School
- Actions: Dash Strike, Teleport Bolt, Phase Step
- Mods: +Move Speed, Reduce Dash Cooldown, On-Move Burst

**Avatar "Miasma"** = Late-run unlock
- **Unlock condition**: Move 500 meters in a run, OR 5+ Mobility tags
- **Effect 1**: "Move-trigger casts also tick OnHit effects" - when wand fires from movement, it counts as if you hit enemies (procs poison spread, etc.)
- **Effect 2**: "Poison spreads on movement thresholds" - every 5 meters traveled, poison spreads to 1 nearby enemy

### How It Plays

**Early Run**:
1. Move around, every 10 meters wand fires 5 shuffled cards in a wide spread
2. Example: `Poison Spray → Dash Strike → Move Speed Buff → Poison Bolt → Teleport`
3. Dashin around applies poison, movement keeps wand firing

**Late Run (Avatar Unlocked)**:
1. Same movement-triggered wand
2. But now, moving also counts as "hitting" for OnHit procs
3. Every 5 meters = poison auto-spreads
4. You become a mobile poison cloud

---

## 11. Effect API Reference

> **Your Comment**: "what effect api is this?"

**Clarification**: There isn't a clearly documented "Effect API" in your codebase right now.

### What the Design Doc Assumes

The reference document assumes you'd create functions like:

```lua
-- Effect API examples
function Effects.damage(ctx, target, amount, damage_type)
  -- Apply damage with resistances, etc.
end

function Effects.apply_status(ctx, target, status_id, duration)
  -- Add buff/debuff
end

function Effects.create_hazard(ctx, position, hazard_type, duration)
  -- Spawn ground hazard
end

function Effects.apply_dot(ctx, target, dot_type, dps, duration)
  -- Apply damage over time
end
```

### Current State in combat_system.lua

Your [combat_system.lua](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/combat/combat_system.lua) has pieces of this:
- `StatusEngine` (for buffs/debuffs)
- Event bus for damage events
- DoT tracking (lines 574-589 in the dump_stats function reference DoTs)

**But**: It's scattered across 5,811 lines and not exposed as a simple API.

### Recommendation

Create a thin wrapper module:

```lua
-- effects_api.lua
local Effects = {}

function Effects.burn(ctx, target, dps, duration)
  -- Use your existing combat_system internals
  Combat.apply_dot(ctx, target, {
    type = "fire",
    dps = dps,
    duration = duration,
    tick_interval = 1.0
  })
end

function Effects.freeze(ctx, target, duration)
  StatusEngine.apply(ctx, target, "frozen", { duration = duration })
end

-- ... more helper functions ...

return Effects
```

**Question**: Would you like me to help create this simplified Effects API wrapper?

---

## 12. Natural Next Steps Example

> **Your Comment**: "What would be an example of this?"

Let me break down what "define 4 Origins + 4 Disciplines" etc. would look like.

### Example: Defining 4 Origins

```lua
-- In data/origins.lua
return {
  ember_nomad = {
    name = "Ember Nomad",
    tags = { "Fire", "Hazard" },
    passive_stats = {
      fire_modifier_pct = 10,
      hazard_duration_pct = 5
    },
    prayer = "ember_psalm", -- references data/prayers.lua
    tag_weights = { Fire = 1.3, Hazard = 1.2 } -- shop bias
  },
  
  tundra_sentinel = {
    name = "Tundra Sentinel",
    tags = { "Ice", "Defense" },
    passive_stats = {
      ice_modifier_pct = 10,
      block_chance_pct = 5
    },
    prayer = "glacier_litany",
    tag_weights = { Ice = 1.3, Defense = 1.2 }
  },
  
  plague_scribe = {
    name = "Plague Scribe",
    tags = { "Poison", "Arcane" },
    passive_stats = {
      poison_duration_pct = 15,
      max_poison_stacks = 10
    },
    prayer = "contagion",
    tag_weights = { Poison = 1.3, Arcane = 1.2 }
  },
  
  void_cultist = {
    name = "Void Cultist",
    tags = { "Arcane", "Summon" },
    passive_stats = {
      arcane_modifier_pct = 10,
      summon_hp_pct = 15
    },
    prayer = "void_rift",
    tag_weights = { Arcane = 1.3, Summon = 1.2 }
  }
}
```

### Example: Defining 5 Wand Frames

```lua
-- In data/wand_frames.lua
return {
  fanatic = {
    name = "Fanatic Frame",
    description = "Fast, small bursts - no shuffle",
    cast_block_size = 2,
    shuffle = false,
    cast_cooldown = 3.0,
    overheat_cap = 50,
    trigger_type = "time"
  },
  
  engine = {
    name = "Engine Frame",
    description = "Big casts, long reload",
    cast_block_size = 8,
    shuffle = false,
    cast_cooldown = 8.0,
    overheat_cap = 150,
    trigger_type = "time"
  },
  
  scatter = {
    name = "Scatter Frame",
    description = "Wide spread, shuffled chaos",
    cast_block_size = 5,
    shuffle = true,
    spread_angle = 45,
    cast_cooldown = 4.0,
    overheat_cap = 80,
    trigger_type = "movement",
    movement_threshold = 10 -- meters
  },
  
  ritual = {
    name = "Ritual Frame",
    description = "Costs HP to cast, powerful",
    cast_block_size = 3,
    shuffle = false,
    cast_cooldown = 5.0,
    hp_cost_pct = 5, -- 5% current HP per cast
    overheat_cap = 100,
    trigger_type = "kill"
  },
  
  reactive = {
    name = "Reactive Frame",
    description = "Fires when hit",
    cast_block_size = 4,
    shuffle = true,
    cast_cooldown = 2.0,
    overheat_cap = 60,
    trigger_type = "on_hit"
  }
}
```

### Example: Wire Tag Breakpoints

```lua
-- In wand/tag_evaluator.lua
local TAG_BREAKPOINTS = {
  Fire = {
    [3] = { stat = "burn_damage_pct", value = 10 },
    [5] = { stat = "burn_tick_rate_pct", value = 15 },
    [7] = { proc = "burn_explosion_on_kill" },
    [9] = { proc = "burn_spread" }
  },
  Ice = {
    [3] = { stat = "slow_potency_pct", value = 10 },
    [5] = { proc = "bonus_damage_on_chilled" },
    [7] = { proc = "shatter_on_kill" },
    [9] = { stat = "damage_vs_frozen_pct", value = 25 }
  },
  -- ... etc for all tags from TODO_design.md
}

function evaluate_tag_bonuses(player, deck_snapshot)
  local tag_counts = deck_snapshot.tag_counts
  
  for tag, breakpoints in pairs(TAG_BREAKPOINTS) do
    local count = tag_counts[tag] or 0
    
    for threshold, bonus in pairs(breakpoints) do
      if count >= threshold then
        if bonus.stat then
          player.stats:add(bonus.stat, bonus.value)
        elseif bonus.proc then
          player:enable_proc(bonus.proc)
        end
      end
    end
  end
end
```

### Example: Author a Prayer

```lua
-- In data/prayers.lua
return {
  ember_psalm = {
    id = "ember_psalm",
    name = "Ember Psalm",
    description = "Next 3 actions leave fire hazards",
    cooldown = 30,
    
    effect = function(ctx, caster)
      -- Apply temporary buff
      StatusEngine.apply(ctx, caster, "ember_psalm_buff", {
        duration = 10, -- expires after 10s if not used
        stacks = 3,
        on_action_cast = function(action_ctx, action)
          -- Consume 1 stack
          local buff = caster.statuses["ember_psalm_buff"]
          buff.stacks = buff.stacks - 1
          
          -- Leave hazard at action target location
          Effects.create_hazard(action_ctx, action.target_pos, {
            type = "fire",
            radius = 2,
            dps = 20,
            duration = 5
          })
          
          -- Remove buff if no stacks left
          if buff.stacks <= 0 then
            StatusEngine.remove(ctx, caster, "ember_psalm_buff")
          end
        end
      })
      
      -- VFX/SFX
      ctx.bus:emit("play_sound", { id = "prayer_cast_fire" })
      ctx.bus:emit("spawn_vfx", { 
        id = "ember_psalm_visual",
        position = caster.position,
        duration = 1.0
      })
    end
  }
}
```

---

## Summary & Next Steps

### Your Key Concerns

1. **Masks causing movement issues** - needs physics debugging
2. **Combat system complexity** - needs simplified wrapper APIs
3. **Unclear concepts** - now clarified with examples above

### Recommended Order to Implement

1. **Define data files** (Origins, Frames, Disciplines, Avatars) - pure data, easy to iterate
2. **Create simplified APIs** (Effects API, Prayer system) - thin wrappers over combat_system
3. **Wire tag evaluator** - reads deck, applies breakpoints
4. **Implement one prayer** - proves the system works
5. **Test and iterate** - play one build (e.g., Ember Nomad) end-to-end

### Questions for You

1. Should I help create the simplified Effects API wrapper?
2. Want me to investigate/fix the mask movement issue?
3. Which build example (Ember Nomad, Plague Scribe, etc.) interests you most for prototyping first?
4. Do you prefer session-based (Option A) or meta-progression (Option B) for avatar unlocks?

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
