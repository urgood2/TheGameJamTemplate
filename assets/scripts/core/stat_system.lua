--[[
================================================================================
STAT SYSTEM - Extensible Stat-to-Gameplay Mapping
================================================================================
Centralized system for managing core stats (physique, cunning, spirit) and
their derivations to gameplay stats.

Key Features:
- Extensible derivation registry (easy to add new stat impacts)
- Stat impact preview (shows what +1 stat gives you)
- Level-up handler with automatic recomputation
- Integration with combat_system.lua Stats

Usage Example:
  -- Register a new derivation
  StatSystem.registerDerivation("physique", "dash_distance", function(value)
    return value * 2  -- +2 dash distance per physique point
  end)

  -- Apply level-up
  StatSystem.applyLevelUp(player, "cunning", 1)

  -- Preview stat impact
  local impact = StatSystem.getStatImpact("spirit", currentValue, 1)
  -- Returns: { energy = 10, energy_regen = 0.5, ... }

================================================================================
]] --

local StatSystem = {}

-- ============================================================================
-- STAT DEFINITIONS
-- ============================================================================

StatSystem.stats = {
    physique = {
        name = "Physique",
        description = "Increases health and survivability",
        icon = "icon_physique", -- Placeholder for UI
        color = "#E74C3C"   -- Red
    },
    cunning = {
        name = "Cunning",
        description = "Increases damage and critical strikes",
        icon = "icon_cunning",
        color = "#F39C12" -- Orange
    },
    spirit = {
        name = "Spirit",
        description = "Increases energy and elemental power",
        icon = "icon_spirit",
        color = "#9B59B6" -- Purple
    }
}

-- ============================================================================
-- DERIVATION REGISTRY
-- ============================================================================

-- Derivation functions: statName -> { derivedStatName -> function(value, entity) }
-- This allows multiple derivations per stat and easy extension
StatSystem.derivations = {
    physique = {},
    cunning = {},
    spirit = {}
}

-- ============================================================================
-- CORE DERIVATION REGISTRATION
-- ============================================================================

--- Registers a derivation function for a stat
--- @param statName string Primary stat name (physique, cunning, spirit)
--- @param derivedStatName string Derived stat name (health, energy, etc.)
--- @param derivationFunc function(value, entity) -> number
function StatSystem.registerDerivation(statName, derivedStatName, derivationFunc)
    if not StatSystem.derivations[statName] then
        StatSystem.derivations[statName] = {}
    end

    StatSystem.derivations[statName][derivedStatName] = derivationFunc

    print(string.format("[StatSystem] Registered derivation: %s -> %s", statName, derivedStatName))
end

-- ============================================================================
-- DEFAULT DERIVATIONS (from combat_system.lua)
-- ============================================================================

--- Initialize default stat derivations
--- These match the existing combat_system.lua derivations
function StatSystem.initializeDefaultDerivations()
    -- PHYSIQUE derivations
    StatSystem.registerDerivation("physique", "health", function(value, entity)
        return 100 + value * 10
    end)

    StatSystem.registerDerivation("physique", "health_regen", function(value, entity)
        local extra = math.max(0, value - 10)
        return extra * 0.2
    end)

    -- CUNNING derivations
    StatSystem.registerDerivation("cunning", "offensive_ability", function(value, entity)
        return value * 1
    end)

    StatSystem.registerDerivation("cunning", "physical_modifier_pct", function(value, entity)
        return math.floor(value / 5) * 1
    end)

    StatSystem.registerDerivation("cunning", "pierce_modifier_pct", function(value, entity)
        return math.floor(value / 5) * 1
    end)

    StatSystem.registerDerivation("cunning", "bleed_duration_pct", function(value, entity)
        return math.floor(value / 5) * 1
    end)

    StatSystem.registerDerivation("cunning", "trauma_duration_pct", function(value, entity)
        return math.floor(value / 5) * 1
    end)

    -- SPIRIT derivations
    StatSystem.registerDerivation("spirit", "health", function(value, entity)
        return value * 2
    end)

    StatSystem.registerDerivation("spirit", "energy", function(value, entity)
        return value * 10
    end)

    StatSystem.registerDerivation("spirit", "energy_regen", function(value, entity)
        return value * 0.5
    end)

    -- Spirit elemental modifiers
    local elementalTypes = { 'fire', 'cold', 'lightning', 'acid', 'vitality', 'aether', 'chaos' }
    for _, elemType in ipairs(elementalTypes) do
        StatSystem.registerDerivation("spirit", elemType .. "_modifier_pct", function(value, entity)
            return math.floor(value / 5) * 1
        end)
    end

    -- Spirit DoT duration modifiers
    local dotTypes = { 'burn', 'frostburn', 'electrocute', 'poison', 'vitality_decay' }
    for _, dotType in ipairs(dotTypes) do
        StatSystem.registerDerivation("spirit", dotType .. "_duration_pct", function(value, entity)
            return math.floor(value / 5) * 1
        end)
    end

    print("[StatSystem] Initialized default derivations")
end

-- ============================================================================
-- STAT IMPACT PREVIEW
-- ============================================================================

--- Calculates the impact of changing a stat value
--- @param statName string Primary stat name
--- @param currentValue number Current stat value
--- @param delta number Change in stat value (usually +1)
--- @param entity table Optional entity for context-aware derivations
--- @return table Map of derivedStatName -> deltaValue
function StatSystem.getStatImpact(statName, currentValue, delta, entity)
    delta = delta or 1
    local impact = {}

    local derivationsForStat = StatSystem.derivations[statName]
    if not derivationsForStat then
        return impact
    end

    for derivedStatName, derivationFunc in pairs(derivationsForStat) do
        local currentDerived = derivationFunc(currentValue, entity)
        local newDerived = derivationFunc(currentValue + delta, entity)
        local change = newDerived - currentDerived

        if change ~= 0 then
            impact[derivedStatName] = change
        end
    end

    return impact
end

--- Formats stat impact for display
--- @param impact table Result from getStatImpact
--- @return string Formatted string
function StatSystem.formatStatImpact(impact)
    local lines = {}
    for statName, value in pairs(impact) do
        local sign = value >= 0 and "+" or ""
        table.insert(lines, string.format("  %s: %s%.2f", statName, sign, value))
    end
    table.sort(lines)
    return table.concat(lines, "\n")
end

-- ============================================================================
-- LEVEL-UP APPLICATION
-- ============================================================================

--- Applies a stat increase to an entity and triggers recomputation
--- @param entity table Entity with stats (must have entity.stats from combat_system)
--- @param statName string Stat to increase
--- @param amount number Amount to increase (default 1)
function StatSystem.applyLevelUp(entity, statName, amount)
    amount = amount or 1

    if not entity.stats then
        error("[StatSystem] Entity missing stats object")
    end

    if not StatSystem.stats[statName] then
        error(string.format("[StatSystem] Unknown stat: %s", statName))
    end

    -- Add to base stat
    entity.stats:add_base(statName, amount)

    print(string.format("[StatSystem] Applied +%d %s to %s", amount, statName, entity.name or "entity"))

    -- Stats will auto-recompute via on_recompute hooks
end

-- ============================================================================
-- INTEGRATION WITH COMBAT_SYSTEM.LUA
-- ============================================================================

--- Attaches stat derivations to a Stats instance
--- This replaces/extends Content.attach_attribute_derivations from combat_system.lua
--- @param statsInstance table Stats instance from combat_system.lua
function StatSystem.attachToStatsInstance(statsInstance)
    statsInstance:on_recompute(function(S)
        -- Get raw base values
        local physique = S:get_raw('physique').base
        local cunning = S:get_raw('cunning').base
        local spirit = S:get_raw('spirit').base

        -- Apply all registered derivations
        for statName, statValue in pairs({ physique = physique, cunning = cunning, spirit = spirit }) do
            local derivationsForStat = StatSystem.derivations[statName]
            if derivationsForStat then
                for derivedStatName, derivationFunc in pairs(derivationsForStat) do
                    local derivedValue = derivationFunc(statValue, nil) -- entity context not available here

                    -- Determine if this is additive or base
                    -- For now, assume all derivations are base additions
                    S:derived_add_base(derivedStatName, derivedValue)
                end
            end
        end
    end)

    print("[StatSystem] Attached derivations to Stats instance")
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Gets all derivations for a stat
--- @param statName string Primary stat name
--- @return table Map of derivedStatName -> derivationFunc
function StatSystem.getDerivations(statName)
    return StatSystem.derivations[statName] or {}
end

--- Lists all registered derivations (for debugging)
function StatSystem.listDerivations()
    print("\n[StatSystem] Registered Derivations:")
    for statName, derivations in pairs(StatSystem.derivations) do
        print(string.format("  %s:", statName))
        for derivedStatName, _ in pairs(derivations) do
            print(string.format("    -> %s", derivedStatName))
        end
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initializes the stat system with default derivations
function StatSystem.init()
    StatSystem.initializeDefaultDerivations()
    print("[StatSystem] Initialized")
end

return StatSystem
