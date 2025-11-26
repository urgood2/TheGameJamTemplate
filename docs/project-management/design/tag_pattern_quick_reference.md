# Tag Pattern Matching - Quick Reference

## 🎯 What Was Built

### Core Systems
1. **Per-Cast Tag Analysis** - Analyzes tag density/diversity in individual casts
2. **Tag-Reactive Jokers** - 3 new Jokers that respond to tag patterns
3. **Discovery Tracking** - Tracks first-time tag thresholds and spell types
4. **Discovery Journal** - UI-friendly interface for viewing discoveries

---

## 📁 New Files

| File | Purpose |
|:---|:---|
| [`tag_discovery_system.lua`](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/wand/tag_discovery_system.lua) | Tracks discoveries |
| [`discovery_journal.lua`](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/wand/discovery_journal.lua) | UI interface |
| [`test_tag_pattern_systems.lua`](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/wand/test_tag_pattern_systems.lua) | Tests |

---

## 🔧 Modified Files

| File | Changes |
|:---|:---|
| [`spell_type_evaluator.lua`](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/wand/spell_type_evaluator.lua#L136-L185) | Added `analyzeTags()` |
| [`wand_executor.lua`](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/wand/wand_executor.lua#L404-L480) | Integrated tag analysis |
| [`joker_system.lua`](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/wand/joker_system.lua#L121-L180) | Added 3 Jokers |
| [`tag_evaluator.lua`](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/wand/tag_evaluator.lua#L118-L135) | Discovery tracking |

---

## 🎮 New Jokers

### Tag Specialist (Uncommon)
- **Trigger:** 3+ actions with same tag
- **Effect:** +30% damage

### Rainbow Mage (Rare)
- **Trigger:** High tag diversity
- **Effect:** +10% damage per distinct tag

### Combo Catalyst (Epic)
- **Trigger:** Single action with 2+ tags
- **Effect:** Cast twice

---

## 📡 Signals (hump.signal)

### Automatic Notifications ✅

```lua
-- Spell cast (includes tag analysis)
signal.emit("on_spell_cast", {
    spell_type = "Twin Cast",
    tag_analysis = { primary_tag, diversity, is_tag_heavy, ... },
    actions = {...}
})

-- Tag threshold discovered (AUTOMATIC)
signal.emit("tag_threshold_discovered", {
    tag = "Fire",
    threshold = 5,
    count = 5
})

-- Spell type discovered (AUTOMATIC)
signal.emit("spell_type_discovered", {
    spell_type = "Mono-Element"
})

-- Joker trigger
signal.emit("on_joker_trigger", {
    joker_name = "Tag Specialist",
    message = "Tag Focus! (Fire x3)"
})
```

### Connect Your UI:

```lua
local signal = require("external.hump.signal")

-- Tag threshold popup
signal.register("tag_threshold_discovered", function(data)
    showPopup(string.format("🔥 DISCOVERY: %d %s Tags!", data.threshold, data.tag))
end)

-- Spell type popup
signal.register("spell_type_discovered", function(data)
    showPopup("✨ NEW SPELL TYPE: " .. data.spell_type)
end)
```

---

## 🔍 Tag Analysis Metrics

```lua
tag_analysis = {
    tag_counts = { Fire = 3, Arcane = 1 },
    primary_tag = "Fire",
    primary_count = 3,
    diversity = 2,
    total_tags = 4,
    
    -- Flags for Jokers
    is_tag_heavy = true,    -- 3+ of same tag
    is_mono_tag = false,    -- Only one tag type
    is_diverse = false,     -- 3+ different tags
    is_multi_tag = false    -- Single action with 2+ tags
}
```

---

## 🔄 System Flow

### Deck-Wide (TagEvaluator) → Discovery Tracking

```
Add Fire card to deck
    ↓
TagEvaluator counts: { Fire = 5 }
    ↓
TagDiscoverySystem checks thresholds
    ↓
"Fire x5" is NEW!
    ↓
signal.emit("tag_threshold_discovered") ← AUTOMATIC NOTIFICATION
    ↓
Apply passive bonuses
```

### Per-Cast (Tag Analysis) → Joker Reactions

```
Cast spell with 3 Fire actions
    ↓
SpellTypeEvaluator.analyzeTags()
    ↓
Returns: { is_tag_heavy = true }
    ↓
Tag Specialist Joker reacts
    ↓
+30% damage to THIS cast
    ↓
signal.emit("on_joker_trigger") ← NOTIFICATION
```

---

## 🛠️ How to Extend

### Add a New Tag-Reactive Joker

```lua
-- In joker_system.lua definitions
my_joker = {
    id = "my_joker",
    name = "My Joker",
    description = "Description",
    rarity = "Rare",
    calculate = function(self, context)
        if context.event == "on_spell_cast" then
            if context.tag_analysis.is_tag_heavy then
                return { damage_mult = 1.5, message = "Heavy!" }
            end
        end
    end
}
```

### Check Discoveries

```lua
local DiscoveryJournal = require("wand.discovery_journal")

-- Has player discovered Twin Cast?
local hasTwinCast = DiscoveryJournal.hasDiscovered(player, "spell_type", "Twin Cast")

-- Has player reached Fire x9?
local hasFire9 = DiscoveryJournal.hasDiscovered(player, "tag_threshold", "Fire", 9)
```

### Get Discovery Summary

```lua
local summary = DiscoveryJournal.getSummary(player)

print("Total discoveries:", summary.stats.total_discoveries)

for _, discovery in ipairs(summary.spell_types) do
    print("Spell:", discovery.display_name)
end
```

---

## 📊 System Comparison

| System | Scope | Notifications? | Purpose |
|:---|:---|:---|:---|
| **TagEvaluator** | Deck-wide | ✅ Tag thresholds | Passive bonuses |
| **Tag Analysis** | Per-cast | ❌ (used by Jokers) | Joker reactions |
| **Jokers** | Per-cast | ✅ Joker triggers | Active effects |
| **Discovery Tracking** | Both | ✅ All discoveries | Track milestones |

---

## ✅ Test Results

Run: `cd assets/scripts && lua wand/test_tag_pattern_systems.lua`

All tests passing:
- ✅ Tag analysis metrics
- ✅ Joker reactions
- ✅ Discovery tracking (no duplicates)
- ✅ Discovery journal

---

## 🚀 Next Steps

1. **Connect UI to signals** - Add visual popups for discoveries
2. **Test in gameplay** - Verify everything works in actual game
3. **Add more Jokers** - Create 5-10 more tag-reactive Jokers
4. **Discovery UI panel** - Visual browser for all discoveries
5. **Save/load** - Integrate with save system

---

## 📚 Full Documentation

See [`tag_pattern_implementation_walkthrough.md`](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/docs/project-management/design/tag_pattern_implementation_walkthrough.md) for complete details.
