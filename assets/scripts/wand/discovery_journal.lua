--[[
================================================================================
DISCOVERY JOURNAL
================================================================================
UI-friendly interface for viewing and querying player discoveries.

PURPOSE:
  Provides organized access to all discoveries tracked by TagDiscoverySystem.
  Makes it easy to build discovery UI panels and check player progress.

FEATURES:
  - Organized Summary: Discoveries grouped by type
  - Recent Feed: Get last N discoveries for notification feed
  - Query Interface: Check if specific discoveries have been made
  - Statistics: Track total discoveries and completion percentage
  - Save/Load: Export/import for persistence

USAGE:
  local DiscoveryJournal = require("wand.discovery_journal")

  -- Get organized summary for UI
  local summary = DiscoveryJournal.getSummary(player)
  -- summary.stats.total_discoveries
  -- summary.tag_thresholds (array)
  -- summary.spell_types (array)

  -- Get recent discoveries
  local recent = DiscoveryJournal.getRecent(player, 10)

  -- Check specific discovery
  local hasTwinCast = DiscoveryJournal.hasDiscovered(player, "spell_type", "Twin Cast")

  -- Save/load
  local saveData = DiscoveryJournal.exportForSave(player)
  DiscoveryJournal.importFromSave(player, saveData)

SEE ALSO:
  - tag_discovery_system.lua (underlying tracking system)
  - docs/project-management/design/tag_pattern_implementation_walkthrough.md
================================================================================
]]

-- Discovery Journal
-- Provides a UI-friendly interface to view all player discoveries
-- Tracks tag thresholds, spell types, and tag patterns

local DiscoveryJournal = {}

local TagDiscoverySystem = require("wand.tag_discovery_system")

--- Get a formatted summary of all discoveries for UI display
--- @param player table Player entity
--- @return table Organized discovery data for UI
function DiscoveryJournal.getSummary(player)
    local stats = TagDiscoverySystem.getStats(player)
    local allDiscoveries = TagDiscoverySystem.getAllDiscoveries(player)

    -- Organize discoveries by type
    local organized = {
        stats = stats,
        tag_thresholds = {},
        spell_types = {},
        tag_patterns = {}
    }

    -- Group discoveries
    for key, discovery in pairs(allDiscoveries) do
        if discovery.type == "tag_threshold" then
            table.insert(organized.tag_thresholds, {
                tag = discovery.tag,
                threshold = discovery.threshold,
                timestamp = discovery.timestamp,
                display_name = string.format("%s x%d", discovery.tag, discovery.threshold)
            })
        elseif discovery.type == "spell_type" then
            table.insert(organized.spell_types, {
                spell_type = discovery.spell_type,
                timestamp = discovery.timestamp,
                display_name = discovery.spell_type
            })
        elseif discovery.type == "tag_pattern" then
            table.insert(organized.tag_patterns, {
                pattern_id = discovery.pattern_id,
                pattern_name = discovery.pattern_name,
                timestamp = discovery.timestamp,
                display_name = discovery.pattern_name or discovery.pattern_id
            })
        end
    end

    -- Sort by timestamp (most recent first)
    local function sortByTimestamp(a, b)
        return (a.timestamp or 0) > (b.timestamp or 0)
    end

    table.sort(organized.tag_thresholds, sortByTimestamp)
    table.sort(organized.spell_types, sortByTimestamp)
    table.sort(organized.tag_patterns, sortByTimestamp)

    return organized
end

--- Get recent discoveries (last N discoveries)
--- @param player table Player entity
--- @param count number Number of recent discoveries to return
--- @return table Array of recent discoveries
function DiscoveryJournal.getRecent(player, count)
    count = count or 10
    local allDiscoveries = TagDiscoverySystem.getAllDiscoveries(player)

    -- Convert to array
    local discoveryArray = {}
    for key, discovery in pairs(allDiscoveries) do
        table.insert(discoveryArray, discovery)
    end

    -- Sort by timestamp (most recent first)
    table.sort(discoveryArray, function(a, b)
        return (a.timestamp or 0) > (b.timestamp or 0)
    end)

    -- Take first N
    local recent = {}
    for i = 1, math.min(count, #discoveryArray) do
        table.insert(recent, discoveryArray[i])
    end

    return recent
end

--- Check if a specific discovery has been made
--- @param player table Player entity
--- @param discovery_type string "tag_threshold", "spell_type", or "tag_pattern"
--- @param identifier string Tag name (for thresholds), spell type, or pattern ID
--- @param threshold number Optional, for tag thresholds
--- @return boolean True if discovered
function DiscoveryJournal.hasDiscovered(player, discovery_type, identifier, threshold)
    local allDiscoveries = TagDiscoverySystem.getAllDiscoveries(player)

    if discovery_type == "tag_threshold" and threshold then
        local key = "tag_" .. identifier .. "_" .. threshold
        return allDiscoveries[key] ~= nil
    elseif discovery_type == "spell_type" then
        local key = "spell_type_" .. identifier
        return allDiscoveries[key] ~= nil
    elseif discovery_type == "tag_pattern" then
        local key = "pattern_" .. identifier
        return allDiscoveries[key] ~= nil
    end

    return false
end

--- Get completion percentage for a category
--- @param player table Player entity
--- @param category string "tag_thresholds", "spell_types", or "tag_patterns"
--- @param total_possible number Total number of possible discoveries in this category
--- @return number Percentage (0-100)
function DiscoveryJournal.getCompletionPercentage(player, category, total_possible)
    local discoveries = TagDiscoverySystem.getDiscoveriesByType(player, category)
    local discovered_count = #discoveries

    if total_possible == 0 then return 0 end

    return (discovered_count / total_possible) * 100
end

--- Export discoveries to a save-friendly format
--- @param player table Player entity
--- @return table Serializable discovery data
function DiscoveryJournal.exportForSave(player)
    return TagDiscoverySystem.getAllDiscoveries(player)
end

--- Import discoveries from save data
--- @param player table Player entity
--- @param save_data table Discovery data from save file
function DiscoveryJournal.importFromSave(player, save_data)
    player.tag_discoveries = save_data or {}
end

--- Print a formatted journal to console (for debugging)
--- @param player table Player entity
function DiscoveryJournal.printJournal(player)
    local summary = DiscoveryJournal.getSummary(player)

    print("=== DISCOVERY JOURNAL ===")
    print(string.format("Total Discoveries: %d", summary.stats.total_discoveries))
    print("")

    print("Tag Thresholds:")
    for _, discovery in ipairs(summary.tag_thresholds) do
        print(string.format("  - %s", discovery.display_name))
    end
    print("")

    print("Spell Types:")
    for _, discovery in ipairs(summary.spell_types) do
        print(string.format("  - %s", discovery.display_name))
    end
    print("")

    print("Tag Patterns:")
    for _, discovery in ipairs(summary.tag_patterns) do
        print(string.format("  - %s", discovery.display_name))
    end
    print("========================")
end

return DiscoveryJournal
