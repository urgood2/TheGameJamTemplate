--[[
================================================================================
APPLY CARD RARITY AND TAGS
================================================================================
This script modifies card_eval_order_test.lua to add rarity and tags to all
card definitions.

Usage:
  This generates the modifications needed. Apply manually or via script.
================================================================================
]] --

local assignments = require("core.add_card_rarity_tags")

print("\n" .. string.rep("=", 60))
print("GENERATING CARD MODIFICATIONS")
print(string.rep("=", 60))

print("\nTo add rarity and tags to cards, add these lines after the 'id' field:")
print("\nExample modification for ACTION_BASIC_PROJECTILE:")
print("  CardTemplates.ACTION_BASIC_PROJECTILE = {")
print("      id = \"ACTION_BASIC_PROJECTILE\",")
print("      rarity = \"common\",  -- ADD THIS")
print("      tags = {\"brute\"},   -- ADD THIS")
print("      type = \"action\",")
print("      ...")

print("\n\nGenerated additions for all cards:")
print(string.rep("-", 60))

for cardId, assignment in pairs(assignments.cardAssignments) do
    local tagsStr = "{"
    for i, tag in ipairs(assignment.tags) do
        tagsStr = tagsStr .. "\"" .. tag .. "\""
        if i < #assignment.tags then
            tagsStr = tagsStr .. ", "
        end
    end
    tagsStr = tagsStr .. "}"

    print(string.format("-- %s", cardId))
    print(string.format("    rarity = \"%s\",", assignment.rarity))
    print(string.format("    tags = %s,", tagsStr))
    print("")
end

print("\nTrigger cards:")
print(string.rep("-", 60))

for cardId, assignment in pairs(assignments.triggerAssignments) do
    local tagsStr = "{"
    for i, tag in ipairs(assignment.tags) do
        tagsStr = tagsStr .. "\"" .. tag .. "\""
        if i < #assignment.tags then
            tagsStr = tagsStr .. ", "
        end
    end
    tagsStr = tagsStr .. "}"

    print(string.format("-- %s", cardId))
    print(string.format("    rarity = \"%s\",", assignment.rarity))
    print(string.format("    tags = %s,", tagsStr))
    print("")
end

print(string.rep("=", 60))
print("✓ Modifications generated")
print(string.rep("=", 60))
