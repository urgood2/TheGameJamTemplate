-- Test Cast Feed UI with Discovery Notifications
print("=== CAST FEED UI DISCOVERY TEST ===\n")

local CastFeedUI = require("ui.cast_feed_ui")
local signal = require("external.hump.signal")

-- Initialize
CastFeedUI.init()

print("Testing signal emissions...\n")

-- Test 1: Spell Cast
print("1. Emitting spell cast signal...")
signal.emit("on_spell_cast", {
    spell_type = "Twin Cast"
})

-- Test 2: Joker Trigger
print("2. Emitting joker trigger signal...")
signal.emit("on_joker_trigger", {
    joker_name = "Tag Specialist",
    message = "Tag Focus! (Fire x3)"
})

-- Test 3: Tag Threshold Discovery
print("3. Emitting tag threshold discovery signal...")
signal.emit("tag_threshold_discovered", {
    tag = "Fire",
    threshold = 5,
    count = 5
})

-- Test 4: Spell Type Discovery
print("4. Emitting spell type discovery signal...")
signal.emit("spell_type_discovered", {
    spell_type = "Mono-Element"
})

-- Check items
print("\nCast Feed Items:")
for i, item in ipairs(CastFeedUI.items) do
    print(string.format("  %d. %s (isDiscovery: %s, lifetime: %.1fs)",
        i, item.text, tostring(item.isDiscovery),
        item.isDiscovery and 5.0 or 3.0))
end

print("\n=== TEST COMPLETE ===")
print("Expected 4 items:")
print("  1. TWIN CAST (3s)")
print("  2. Tag Specialist! (...) (3s)")
print("  3. 🔥 DISCOVERY: Fire x5! (5s)")
print("  4. ✨ NEW SPELL: MONO-ELEMENT! (5s)")
