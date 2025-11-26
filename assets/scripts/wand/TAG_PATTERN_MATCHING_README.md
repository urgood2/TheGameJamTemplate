# Wand System - Tag Pattern Matching

## Overview

The tag pattern matching system adds "Balatro-style" pattern recognition to the wand system, providing satisfying discovery moments and reactive gameplay.

## Core Systems

### 1. **Per-Cast Tag Analysis** 
**File:** `spell_type_evaluator.lua`

Analyzes tag composition of individual spell casts (distinct from deck-wide TagEvaluator).

```lua
local tagAnalysis = SpellTypeEvaluator.analyzeTags(actions)
-- Returns: { primary_tag, diversity, is_tag_heavy, is_diverse, etc. }
```

### 2. **Tag-Reactive Jokers**
**File:** `joker_system.lua`

Jokers that react to per-cast tag metrics:
- **Tag Specialist**: +30% damage when 3+ actions share same tag
- **Rainbow Mage**: +10% damage per distinct tag type
- **Combo Catalyst**: Cast twice when single action has 2+ tags

### 3. **Discovery Tracking**
**File:** `tag_discovery_system.lua`

Tracks first-time discoveries:
- Tag thresholds (3/5/7/9 of any tag)
- Spell types (first time casting each type)
- Tag patterns (for future curated combos)

**Automatic Notifications:**
```lua
-- Emits via hump.signal
signal.emit("tag_threshold_discovered", { tag, threshold, count })
signal.emit("spell_type_discovered", { spell_type })
```

### 4. **Discovery Journal**
**File:** `discovery_journal.lua`

UI-friendly interface for viewing discoveries:
```lua
local summary = DiscoveryJournal.getSummary(player)
local recent = DiscoveryJournal.getRecent(player, 10)
local hasTwinCast = DiscoveryJournal.hasDiscovered(player, "spell_type", "Twin Cast")
```

## How Systems Work Together

### Deck-Wide Flow (TagEvaluator → Discovery)
```
Add card to deck
    ↓
TagEvaluator counts total tags
    ↓
TagDiscoverySystem checks thresholds
    ↓
New threshold? → Emit signal
    ↓
Apply passive bonuses
```

### Per-Cast Flow (Tag Analysis → Jokers)
```
Cast spell
    ↓
Analyze THIS cast's tags
    ↓
Pass metrics to Jokers
    ↓
Jokers react (damage boost, etc.)
    ↓
Check if spell type is new → Emit signal
```

## Signals (hump.signal)

All systems emit signals for UI integration:

```lua
local signal = require("external.hump.signal")

-- Tag threshold discovered (automatic)
signal.register("tag_threshold_discovered", function(data)
    showPopup(string.format("DISCOVERY: %d %s Tags!", data.threshold, data.tag))
end)

-- Spell type discovered (automatic)
signal.register("spell_type_discovered", function(data)
    showPopup("NEW SPELL TYPE: " .. data.spell_type)
end)

-- Joker trigger
signal.register("on_joker_trigger", function(data)
    showFloatingText(data.message)
end)

-- Spell cast (includes tag analysis)
signal.register("on_spell_cast", function(data)
    -- data.spell_type
    -- data.tag_analysis
    -- data.actions
end)
```

## Testing

Run the comprehensive test:
```bash
cd assets/scripts
lua wand/test_tag_pattern_systems.lua
```

All tests should pass:
- ✅ Tag analysis metrics
- ✅ Joker reactions
- ✅ Discovery tracking (no duplicates)
- ✅ Discovery journal queries

## Documentation

- **Full Walkthrough:** `docs/project-management/design/tag_pattern_implementation_walkthrough.md`
- **Quick Reference:** `docs/project-management/design/tag_pattern_quick_reference.md`

## Key Files

### New Files
- `tag_discovery_system.lua` - Discovery tracking
- `discovery_journal.lua` - UI interface
- `test_tag_pattern_systems.lua` - Tests

### Modified Files
- `spell_type_evaluator.lua` - Added `analyzeTags()`
- `wand_executor.lua` - Integrated tag analysis
- `joker_system.lua` - Added 3 new Jokers
- `tag_evaluator.lua` - Discovery tracking

## Extending the System

### Add a New Tag-Reactive Joker

```lua
-- In joker_system.lua definitions
my_joker = {
    id = "my_joker",
    name = "My Joker",
    description = "Reacts to tag patterns",
    rarity = "Rare",
    calculate = function(self, context)
        if context.event == "on_spell_cast" then
            if context.tag_analysis.is_tag_heavy then
                return { 
                    damage_mult = 1.5,
                    message = "Tag Heavy!"
                }
            end
        end
    end
}
```

### Check Discoveries in Code

```lua
local DiscoveryJournal = require("wand.discovery_journal")

-- Check if player has discovered something
if DiscoveryJournal.hasDiscovered(player, "tag_threshold", "Fire", 9) then
    -- Player has mastered Fire!
end

-- Get all discoveries for UI
local summary = DiscoveryJournal.getSummary(player)
for _, discovery in ipairs(summary.spell_types) do
    print("Discovered:", discovery.display_name)
end
```

## System Comparison

| System | Scope | When | Purpose | Notifications |
|:---|:---|:---|:---|:---|
| TagEvaluator | Deck-wide | Deck changes | Passive bonuses | Tag thresholds |
| Tag Analysis | Per-cast | During cast | Joker reactions | None |
| Jokers | Per-cast | During cast | Active effects | Joker triggers |
| Discovery | Both | Automatic | Track milestones | All discoveries |

## Next Steps

1. **Connect UI** - Add visual popups for discovery signals
2. **Test in gameplay** - Verify everything works in actual game
3. **Add more Jokers** - Create 5-10 more tag-reactive Jokers
4. **Discovery UI panel** - Visual browser for all discoveries
5. **Save/load integration** - Persist discoveries across sessions
