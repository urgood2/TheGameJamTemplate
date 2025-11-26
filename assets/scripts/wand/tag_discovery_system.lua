--[[
================================================================================
TAG DISCOVERY SYSTEM
================================================================================
Tracks first-time discoveries of tag milestones and spell patterns.

PURPOSE:
  Provides "Balatro-style" discovery moments when players hit tag thresholds
  or cast new spell types for the first time.

FEATURES:
  - Tag Threshold Tracking: Discovers when player hits 3/5/7/9 of any tag
  - Spell Type Tracking: Discovers when player casts each spell type
  - Tag Pattern Tracking: For future curated combo discoveries
  - No Duplicates: Never notifies twice for the same discovery
  - Persistent: Discoveries stored in player.tag_discoveries

INTEGRATION:
  - TagEvaluator: Checks tag thresholds when deck changes
  - WandExecutor: Checks spell types during cast
  - Emits hump.signal events for UI notifications

SIGNALS EMITTED:
  - "tag_threshold_discovered" { tag, threshold, count }
  - "spell_type_discovered" { spell_type }
  - (Future) "tag_pattern_discovered" { pattern_id, pattern_name }

USAGE:
  local TagDiscoverySystem = require("wand.tag_discovery_system")

  -- Check for new tag threshold discoveries
  local discoveries = TagDiscoverySystem.checkTagThresholds(player, tag_counts)

  -- Check for spell type discovery
  local discovery = TagDiscoverySystem.checkSpellType(player, "Twin Cast")

  -- Get statistics
  local stats = TagDiscoverySystem.getStats(player)

SEE ALSO:
  - docs/project-management/design/tag_pattern_implementation_walkthrough.md
  - docs/project-management/design/tag_pattern_quick_reference.md
================================================================================
]]

-- Tag Discovery System
-- Tracks first-time discoveries of tag thresholds and spell type patterns
-- Provides celebration moments when players hit milestones

local TagDiscoverySystem = {}

-- Thresholds to track (matches TagEvaluator breakpoints: 3, 5, 7, 9)
local DISCOVERY_THRESHOLDS = { 3, 5, 7, 9 }

--- Check for new tag threshold discoveries
--- @param player: Player entity with tag_counts
--- @param tag_counts: Table of tag -> count
--- @return table: Array of new threshold discoveries
function TagDiscoverySystem.checkTagThresholds(player, tag_counts)
    -- Initialize discovery tracking
    player.tag_discoveries = player.tag_discoveries or {}

    local newDiscoveries = {}

    for tag, count in pairs(tag_counts) do
        -- Check each threshold
        for _, threshold in ipairs(DISCOVERY_THRESHOLDS) do
            local discoveryKey = "tag_" .. tag .. "_" .. threshold

            -- New discovery if we hit threshold and haven't discovered it yet
            if count >= threshold and not player.tag_discoveries[discoveryKey] then
                player.tag_discoveries[discoveryKey] = {
                    type = "tag_threshold",
                    tag = tag,
                    threshold = threshold,
                    timestamp = os.time()
                }

                table.insert(newDiscoveries, {
                    type = "tag_threshold",
                    tag = tag,
                    threshold = threshold,
                    count = count
                })
            end
        end
    end

    return newDiscoveries
end

--- Check for new spell type discoveries
--- @param player: Player entity
--- @param spell_type: Spell type string (e.g., "Twin Cast", "Mono-Element")
--- @return table|nil: Discovery data if new, nil if already discovered
function TagDiscoverySystem.checkSpellType(player, spell_type)
    if not spell_type then return nil end

    -- Initialize discovery tracking
    player.tag_discoveries = player.tag_discoveries or {}

    local discoveryKey = "spell_type_" .. spell_type

    -- Check if this is a new discovery
    if not player.tag_discoveries[discoveryKey] then
        player.tag_discoveries[discoveryKey] = {
            type = "spell_type",
            spell_type = spell_type,
            timestamp = os.time()
        }

        return {
            type = "spell_type",
            spell_type = spell_type
        }
    end

    return nil
end

--- Check for new tag pattern discoveries (for future curated combos)
--- @param player: Player entity
--- @param pattern_id: Pattern identifier string
--- @param pattern_name: Human-readable pattern name
--- @return table|nil: Discovery data if new, nil if already discovered
function TagDiscoverySystem.checkTagPattern(player, pattern_id, pattern_name)
    if not pattern_id then return nil end

    -- Initialize discovery tracking
    player.tag_discoveries = player.tag_discoveries or {}

    local discoveryKey = "pattern_" .. pattern_id

    -- Check if this is a new discovery
    if not player.tag_discoveries[discoveryKey] then
        player.tag_discoveries[discoveryKey] = {
            type = "tag_pattern",
            pattern_id = pattern_id,
            pattern_name = pattern_name,
            timestamp = os.time()
        }

        return {
            type = "tag_pattern",
            pattern_id = pattern_id,
            pattern_name = pattern_name
        }
    end

    return nil
end

--- Get all discoveries for a player
--- @param player: Player entity
--- @return table: All discoveries
function TagDiscoverySystem.getAllDiscoveries(player)
    return player.tag_discoveries or {}
end

--- Get discovery statistics
--- @param player: Player entity
--- @return table: Stats about discoveries
function TagDiscoverySystem.getStats(player)
    local discoveries = player.tag_discoveries or {}

    local stats = {
        total_discoveries = 0,
        tag_thresholds = 0,
        spell_types = 0,
        tag_patterns = 0
    }

    for _, discovery in pairs(discoveries) do
        stats.total_discoveries = stats.total_discoveries + 1

        if discovery.type == "tag_threshold" then
            stats.tag_thresholds = stats.tag_thresholds + 1
        elseif discovery.type == "spell_type" then
            stats.spell_types = stats.spell_types + 1
        elseif discovery.type == "tag_pattern" then
            stats.tag_patterns = stats.tag_patterns + 1
        end
    end

    return stats
end

--- Get discoveries by type
--- @param player: Player entity
--- @param discovery_type: "tag_threshold", "spell_type", or "tag_pattern"
--- @return table: Array of discoveries of that type
function TagDiscoverySystem.getDiscoveriesByType(player, discovery_type)
    local discoveries = player.tag_discoveries or {}
    local filtered = {}

    for _, discovery in pairs(discoveries) do
        if discovery.type == discovery_type then
            table.insert(filtered, discovery)
        end
    end

    return filtered
end

--- Clear all discoveries (for testing/reset)
--- @param player: Player entity
function TagDiscoverySystem.clearDiscoveries(player)
    player.tag_discoveries = {}
end

return TagDiscoverySystem
