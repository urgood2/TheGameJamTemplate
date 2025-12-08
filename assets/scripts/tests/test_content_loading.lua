local CardRegistry = require("wand.card_registry")
-- Mock JokerSystem if needed, or require the file that has definitions
-- The JokerSystem in wand/joker_system.lua might have dependencies.
-- Let's just check data/jokers.lua directly for now to be safe, 
-- or try to require joker_system if it's safe.
local JokerDefs = require("data.jokers")

print("--------------------------------------------------")
print("VERIFICATION START")
print("--------------------------------------------------")

print("Loading Cards from Registry...")
local cards = CardRegistry.get_all_cards()
local count = 0
for k, v in pairs(cards) do
    count = count + 1
end
print("Loaded " .. count .. " cards.")

if cards["TEST_PROJECTILE"] then
    print("[PASS] TEST_PROJECTILE found.")
else
    print("[FAIL] TEST_PROJECTILE not found.")
end

print("Loading Jokers from Data...")
local jokerCount = 0
for k, v in pairs(JokerDefs) do
    jokerCount = jokerCount + 1
end
print("Loaded " .. jokerCount .. " jokers.")

if JokerDefs["pyromaniac"] then
    print("[PASS] pyromaniac found.")
else
    print("[FAIL] pyromaniac not found.")
end

print("--------------------------------------------------")
print("VERIFICATION COMPLETE")
print("--------------------------------------------------")
