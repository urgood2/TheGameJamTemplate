# Wand Build System - Integration Guide

## What We Built

You now have the foundation for the Wand Build System:

### Data Files
- [origins.lua](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/data/origins.lua) - 4 starter classes
- [wand_frames.lua](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/data/wand_frames.lua) - 5 wand templates
- [disciplines.lua](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/data/disciplines.lua) - 4 schools of magic
- [avatars.lua](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/data/avatars.lua) - 6 ascension forms
- [prayers.lua](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/data/prayers.lua) - 4 prayer abilities

### API Wrappers
- [effects_api.lua](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/combat/effects_api.lua) - Simplified combat system wrapper
- [prayer_system.lua](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/combat/prayer_system.lua) - Prayer management

### Core Systems
- [tag_evaluator.lua](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/wand/tag_evaluator.lua) - Tag breakpoint system (3/5/7/9)

---

## How to Integrate

### 1. Initialize at Game Start

```lua
-- In your main game initialization (e.g., main.lua or game_init.lua)

local PrayerSystem = require("combat.prayer_system")
local Prayers = require("data.prayers")

-- Register all prayers
PrayerSystem.register_all(Prayers)
```

### 2. Apply Origin at Character Creation

```lua
local Origins = require("data.origins")

function create_player(origin_id)
  local player = { 
    stats = Stats.new(),
    equipped = {},
    timers = {}
  }
  
  local origin = Origins[origin_id]
  
  -- Apply passive stats
  for stat, value in pairs(origin.passive_stats) do
    player.stats:add_add_pct(stat, value)
  end
  
  -- Assign prayer
  player.prayer = origin.prayer
  
  -- Store tag weights for shop
  player.tag_weights = origin.tag_weights
  
  return player
end
```

### 3. Equip Wand Frames

```lua
local WandFrames = require("data.wand_frames")

function equip_wand(player, wand_slot, frame_id)
  local frame = WandFrames[frame_id]
  
  player.wands = player.wands or {}
  player.wands[wand_slot] = {
    frame = frame,
    cards = {} -- Populated as player adds cards
  }
end
```

### 4. Evaluate Tags on Deck Change

```lua
local TagEvaluator = require("wand.tag_evaluator")

function on_deck_changed(player, ctx)
  -- Build deck snapshot from all wands
  local deck_snapshot = { cards = {} }
  
  for _, wand in pairs(player.wands or {}) do
    for _, card in ipairs(wand.cards) do
      table.insert(deck_snapshot.cards, card)
    end
  end
  
  -- Apply tag bonuses
  TagEvaluator.evaluate_and_apply(player, deck_snapshot, ctx)
end
```

### 5. Cast Prayers

```lua
local PrayerSystem = require("combat.prayer_system")

function on_prayer_button_pressed(player, ctx)
  if not player.prayer then return end
  
  local success, err = PrayerSystem.cast(ctx, player, player.prayer)
  
  if not success then
    print("Prayer failed:", err)
  end
end
```

---

## Answering Your Questions

### Q: "Would we be allowing only one wand? How would wand distribution work?"

**Answer**: The system supports **multiple wands** (e.g., 4 wand slots).

Each wand has:
- A **Frame** (defines trigger type and cast mechanics)
- A **deck of cards** (actions/modifiers)

**Example**:
```lua
player.wands = {
  [1] = { frame = "fanatic", cards = {...} },  -- Time-based
  [2] = { frame = "scatter", cards = {...} },  -- Movement-based
  [3] = { frame = "ritual", cards = {...} },   -- Kill-based
  [4] = { frame = "reactive", cards = {...} }  -- On-hit
}
```

This gives you **trigger variety** - different wands fire under different conditions.

---

### Q: "How could Disciplines be fun? Is it too limiting?"

**Answer**: Disciplines **gate the card pool** to prevent dilution, but you still get variety:

- **Discipline cards**: ~12 cards from your chosen school
- **Neutral cards**: ~10 universal cards available to everyone
- **Total pool**: ~22 cards to choose from per run

**Why this works**:
- Prevents "1000 random cards" problem
- Ensures thematic consistency
- Each run feels different based on Discipline choice
- You can still pivot within your school (e.g., Arcane has both offense and utility)

**If it feels too limiting**: Add a 2nd Discipline choice mid-run, or allow "cross-school" cards as rare drops.

---

### Q: "Can you tell me more about tag bias?"

**Answer**: Tag bias affects **shop RNG weights**.

**Example**:
```lua
-- Ember Nomad origin
tag_weights = { Fire = 1.3, Hazard = 1.2 }

-- In shop generation:
function generate_shop_cards(player)
  for _, card in ipairs(all_available_cards) do
    local weight = 1.0
    
    -- Apply tag bias
    for _, tag in ipairs(card.tags) do
      weight = weight * (player.tag_weights[tag] or 1.0)
    end
    
    -- Fire cards are 1.3x more likely to appear
    -- Hazard cards are 1.2x more likely
  end
end
```

**Result**: Fire/Hazard cards appear ~30% more often in your shop, nudging you toward your Origin's theme without forcing it.

---

### Q: "Should triggers be bound to specific wands? Swappable? What is more interesting?"

**Recommendation**: **Triggers are bound to Wand Frames** (not swappable mid-run).

**Why**:
- **Clarity**: Each wand has a clear identity ("this is my on-kill wand")
- **Build diversity**: Choosing 4 different frames = 4 different playstyles active simultaneously
- **Strategic depth**: You decide which cards go in which wand based on the trigger

**Example Decision**:
> "I have a powerful AoE spell. Should I put it in my Time-based wand (fires every 3s) or my Kill-based wand (fires after each kill)?"

**Alternative (if you want more flexibility)**: Allow "Trigger Gems" as equippable items that change a wand's trigger type. This adds a layer of customization.

---

### Q: "So these are the only cards that spawn in the shop?" (re: Disciplines)

**Answer**: Discipline cards + Neutral cards.

**Full Shop Pool**:
```lua
function get_shop_pool(player)
  local pool = {}
  
  -- Add Discipline cards
  local discipline = Disciplines[player.discipline]
  for _, card_id in ipairs(discipline.actions) do
    table.insert(pool, card_id)
  end
  for _, card_id in ipairs(discipline.modifiers) do
    table.insert(pool, card_id)
  end
  
  -- Add Neutral cards (always available)
  for _, card_id in ipairs(NEUTRAL_CARDS) do
    table.insert(pool, card_id)
  end
  
  return pool
end
```

**Neutral Cards** might include:
- Basic projectile
- Generic damage buff
- Cooldown reduction
- Movement speed

This ensures you're not completely locked in, but your Discipline defines your "flavor."

---

## Next Steps (Beyond Your Request)

These are **not** part of your requested scope, but are natural follow-ups:

1. **Implement Resonance Pairs** (Fire+Mobility, Poison+Summon, etc.)
2. **Wire Avatar Unlock Conditions** (track kills, distance moved, etc.)
3. **Create Card Definitions** (actual action/modifier cards with effects)
4. **Integrate with Shop System** (use tag_weights in card generation)
5. **Implement Proc Hooks** (burn_explosion_on_kill, chain_restores_cooldown, etc.)

---

## Testing the System

### Quick Test Script

```lua
-- test_wand_build.lua
local Origins = require("data.origins")
local TagEvaluator = require("wand.tag_evaluator")
local PrayerSystem = require("combat.prayer_system")
local Prayers = require("data.prayers")

-- Initialize
PrayerSystem.register_all(Prayers)

-- Create player
local player = {
  stats = Stats.new(),
  equipped = {},
  timers = {}
}

-- Apply Ember Nomad origin
local origin = Origins.ember_nomad
for stat, value in pairs(origin.passive_stats) do
  player.stats:add_add_pct(stat, value)
end
player.prayer = origin.prayer

-- Create a deck with Fire cards
local deck = {
  cards = {
    { name = "Fireball", tags = {"Fire", "Projectile"} },
    { name = "Flame Wave", tags = {"Fire", "Hazard"} },
    { name = "Ignite", tags = {"Fire"} },
    { name = "Burn Mod", tags = {"Fire"} },
    { name = "Explosion", tags = {"Fire", "Hazard"} }
  }
}

-- Evaluate tags (should unlock Fire 3 and Fire 5 bonuses)
TagEvaluator.evaluate_and_apply(player, deck, ctx)

-- Check active bonuses
local bonuses = TagEvaluator.get_active_bonuses(player)
for _, bonus in ipairs(bonuses) do
  print(string.format("[%s %d] %s", bonus.tag, bonus.threshold, bonus.description))
end

-- Cast prayer
local ctx = { time = { now = 0 }, bus = EventBus.new() }
PrayerSystem.cast(ctx, player, player.prayer)
```

---

## Summary

✅ **Completed**:
- Data definitions for Origins, Frames, Disciplines, Avatars
- Simplified APIs for Effects and Prayers
- Tag Evaluator with full breakpoint system

🔄 **Ready to integrate** into your existing wand/shop/combat systems

📋 **Design questions answered** in Q&A section above
