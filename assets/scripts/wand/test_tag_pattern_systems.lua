-- Test Tag Pattern Matching Systems
-- Tests tag analysis, Jokers, and discovery tracking

print("=== TAG PATTERN MATCHING TEST ===\n")

-- Load systems
local SpellTypeEvaluator = require("wand.spell_type_evaluator")
local JokerSystem = require("wand.joker_system")
local TagDiscoverySystem = require("wand.tag_discovery_system")
local DiscoveryJournal = require("wand.discovery_journal")

-- Mock player
local player = {
    tag_counts = {},
    tag_discoveries = {}
}

-- Test 1: Tag Analysis
print("--- Test 1: Tag Analysis ---")

local test_actions_1 = {
    { tags = { "Fire", "Hazard" } },
    { tags = { "Fire" } },
    { tags = { "Fire", "Arcane" } }
}

local tagAnalysis1 = SpellTypeEvaluator.analyzeTags(test_actions_1)
print("Actions: 3 Fire cards (2 with extra tags)")
print(string.format("  Primary Tag: %s (count: %d)", tagAnalysis1.primary_tag or "none", tagAnalysis1.primary_count))
print(string.format("  Diversity: %d distinct tags", tagAnalysis1.diversity))
print(string.format("  Is Tag Heavy: %s", tostring(tagAnalysis1.is_tag_heavy)))
print(string.format("  Is Mono Tag: %s", tostring(tagAnalysis1.is_mono_tag)))
print(string.format("  Is Diverse: %s", tostring(tagAnalysis1.is_diverse)))
print("")

-- Test 2: Diverse Cast
print("--- Test 2: Diverse Cast ---")

local test_actions_2 = {
    { tags = { "Fire" } },
    { tags = { "Ice" } },
    { tags = { "Lightning" } },
    { tags = { "Arcane" } }
}

local tagAnalysis2 = SpellTypeEvaluator.analyzeTags(test_actions_2)
print("Actions: 4 different element tags")
print(string.format("  Diversity: %d distinct tags", tagAnalysis2.diversity))
print(string.format("  Is Diverse: %s", tostring(tagAnalysis2.is_diverse)))
print("")

-- Test 3: Multi-Tag Single Action
print("--- Test 3: Multi-Tag Single Action ---")

local test_actions_3 = {
    { tags = { "Ice", "Brute", "Defense" } }
}

local tagAnalysis3 = SpellTypeEvaluator.analyzeTags(test_actions_3)
print("Actions: 1 card with 3 tags")
print(string.format("  Diversity: %d", tagAnalysis3.diversity))
print(string.format("  Is Multi-Tag: %s", tostring(tagAnalysis3.is_multi_tag)))
print("")

-- Test 4: Joker Reactions
print("--- Test 4: Joker Reactions ---")

-- Add test Jokers
JokerSystem.clear_jokers()
JokerSystem.add_joker("tag_specialist")
JokerSystem.add_joker("rainbow_mage")
JokerSystem.add_joker("combo_catalyst")

-- Test Tag Specialist (should trigger on tag-heavy cast)
local context1 = {
    event = "on_spell_cast",
    tag_analysis = tagAnalysis1,
    spell_type = "Mono-Element"
}

print("Testing Tag Specialist with tag-heavy cast:")
local effects1 = JokerSystem.trigger_event("on_spell_cast", context1)
print(string.format("  Damage Mult: x%.2f", effects1.damage_mult))
if #effects1.messages > 0 then
    print(string.format("  Message: %s", effects1.messages[1].text))
end
print("")

-- Test Rainbow Mage (should trigger on diverse cast)
local context2 = {
    event = "on_spell_cast",
    tag_analysis = tagAnalysis2,
    spell_type = "Combo Chain"
}

print("Testing Rainbow Mage with diverse cast:")
local effects2 = JokerSystem.trigger_event("on_spell_cast", context2)
print(string.format("  Damage Mult: x%.2f", effects2.damage_mult))
if #effects2.messages > 0 then
    print(string.format("  Message: %s", effects2.messages[1].text))
end
print("")

-- Test Combo Catalyst (should trigger on multi-tag single action)
local context3 = {
    event = "on_spell_cast",
    tag_analysis = tagAnalysis3,
    spell_type = "Simple Cast"
}

print("Testing Combo Catalyst with multi-tag action:")
local effects3 = JokerSystem.trigger_event("on_spell_cast", context3)
print(string.format("  Repeat Cast: +%d", effects3.repeat_cast))
if #effects3.messages > 0 then
    print(string.format("  Message: %s", effects3.messages[1].text))
end
print("")

-- Test 5: Tag Threshold Discoveries
print("--- Test 5: Tag Threshold Discoveries ---")

local tag_counts_1 = { Fire = 3, Ice = 2 }
local discoveries1 = TagDiscoverySystem.checkTagThresholds(player, tag_counts_1)

print("First time reaching 3 Fire tags:")
for _, discovery in ipairs(discoveries1) do
    print(string.format("  DISCOVERED: %s tags at threshold %d", discovery.tag, discovery.threshold))
end
print("")

-- Try again (should not discover again)
local discoveries2 = TagDiscoverySystem.checkTagThresholds(player, tag_counts_1)
print("Checking same tag counts again:")
print(string.format("  New discoveries: %d (should be 0)", #discoveries2))
print("")

-- Increase Fire to 5
local tag_counts_2 = { Fire = 5, Ice = 3 }
local discoveries3 = TagDiscoverySystem.checkTagThresholds(player, tag_counts_2)

print("Increasing to 5 Fire and 3 Ice:")
for _, discovery in ipairs(discoveries3) do
    print(string.format("  DISCOVERED: %s tags at threshold %d", discovery.tag, discovery.threshold))
end
print("")

-- Test 6: Spell Type Discoveries
print("--- Test 6: Spell Type Discoveries ---")

local spellDiscovery1 = TagDiscoverySystem.checkSpellType(player, "Twin Cast")
if spellDiscovery1 then
    print(string.format("  DISCOVERED: %s", spellDiscovery1.spell_type))
end

local spellDiscovery2 = TagDiscoverySystem.checkSpellType(player, "Mono-Element")
if spellDiscovery2 then
    print(string.format("  DISCOVERED: %s", spellDiscovery2.spell_type))
end

-- Try again (should not discover)
local spellDiscovery3 = TagDiscoverySystem.checkSpellType(player, "Twin Cast")
if spellDiscovery3 then
    print("  ERROR: Should not rediscover Twin Cast")
else
    print("  Correctly did not rediscover Twin Cast")
end
print("")

-- Test 7: Discovery Journal
print("--- Test 7: Discovery Journal ---")

DiscoveryJournal.printJournal(player)
print("")

-- Test recent discoveries
local recent = DiscoveryJournal.getRecent(player, 5)
print("Recent Discoveries (last 5):")
for i, discovery in ipairs(recent) do
    if discovery.type == "tag_threshold" then
        print(string.format("  %d. %s x%d", i, discovery.tag, discovery.threshold))
    elseif discovery.type == "spell_type" then
        print(string.format("  %d. Spell: %s", i, discovery.spell_type))
    end
end
print("")

-- Test has discovered
local hasTwinCast = DiscoveryJournal.hasDiscovered(player, "spell_type", "Twin Cast")
local hasFire5 = DiscoveryJournal.hasDiscovered(player, "tag_threshold", "Fire", 5)
local hasFire9 = DiscoveryJournal.hasDiscovered(player, "tag_threshold", "Fire", 9)

print("Discovery Checks:")
print(string.format("  Has Twin Cast: %s", tostring(hasTwinCast)))
print(string.format("  Has Fire x5: %s", tostring(hasFire5)))
print(string.format("  Has Fire x9: %s", tostring(hasFire9)))
print("")

-- Test stats
local stats = TagDiscoverySystem.getStats(player)
print("Discovery Stats:")
print(string.format("  Total: %d", stats.total_discoveries))
print(string.format("  Tag Thresholds: %d", stats.tag_thresholds))
print(string.format("  Spell Types: %d", stats.spell_types))
print("")

print("=== ALL TESTS COMPLETE ===")
