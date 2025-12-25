--[[
================================================================================
ECS DASHBOARD
================================================================================
Provides visibility into the Entity Component System state:
- Entity counts by component type
- Script table distribution
- Orphaned entity detection
- Component usage patterns

Usage:
    local ecs = require("tools.ecs_dashboard")
    ecs.report()           -- Full report
    ecs.entity_count()     -- Quick entity count
    ecs.find_orphans()     -- Find entities missing expected components
================================================================================
]]

local ECSDashboard = {}

-- Cache commonly checked components
local TRACKED_COMPONENTS = {
    "Transform",
    "GameObject",
    "AnimationObject",
    "Velocity",
    "PhysicsComponent",
    "AI_Component",
    "CombatStats",
    "PlayerInput",
    "Collider",
    "ScriptedEntity",
}

-- Get total entity count
function ECSDashboard.entity_count()
    -- registry.size() returns total capacity, we need to iterate for active
    local count = 0
    -- Use Transform as proxy (most entities have it)
    for entity in registry:view(Transform):each() do
        count = count + 1
    end
    return count
end

-- Get component counts
function ECSDashboard.component_counts()
    local counts = {}

    -- Check each tracked component type
    for _, comp_name in ipairs(TRACKED_COMPONENTS) do
        local comp_type = _G[comp_name]
        if comp_type then
            local count = 0
            pcall(function()
                for _ in registry:view(comp_type):each() do
                    count = count + 1
                end
            end)
            counts[comp_name] = count
        end
    end

    return counts
end

-- Find entities that might be orphaned (have Transform but no script)
function ECSDashboard.find_orphans()
    local orphans = {}
    local checked = 0

    for entity in registry:view(Transform):each() do
        checked = checked + 1
        local script = getScriptTableFromEntityID(entity)
        local has_anim = component_cache.get(entity, AnimationObject) ~= nil
        local has_physics = component_cache.get(entity, PhysicsComponent) ~= nil

        -- Orphan: has transform but no script and no animation
        if not script and not has_anim then
            table.insert(orphans, {
                entity = entity,
                has_physics = has_physics,
            })
        end
    end

    return orphans, checked
end

-- Find entities with script tables
function ECSDashboard.scripted_entity_count()
    local count = 0
    local with_data = 0

    for entity in registry:view(Transform):each() do
        local script = getScriptTableFromEntityID(entity)
        if script then
            count = count + 1
            -- Check if script has meaningful data
            local field_count = 0
            for _ in pairs(script) do
                field_count = field_count + 1
            end
            if field_count > 5 then  -- More than base fields
                with_data = with_data + 1
            end
        end
    end

    return count, with_data
end

-- Memory estimate for script tables
function ECSDashboard.estimate_script_memory()
    local total_fields = 0
    local table_count = 0

    -- Helper to count table fields with circular reference protection
    local function count_table(t, depth, seen)
        if depth > 5 then return 0 end  -- Prevent deep recursion
        seen = seen or {}
        if seen[t] then return 0 end    -- Circular reference detected
        seen[t] = true

        local count = 0
        for k, v in pairs(t) do
            count = count + 1
            if type(v) == "table" then
                count = count + count_table(v, depth + 1, seen)
            end
        end
        return count
    end

    for entity in registry:view(Transform):each() do
        local script = getScriptTableFromEntityID(entity)
        if script then
            table_count = table_count + 1
            total_fields = total_fields + count_table(script, 0)
        end
    end

    -- Rough estimate: ~40 bytes per field + ~80 bytes per table
    local estimated_kb = (total_fields * 40 + table_count * 80) / 1024

    return {
        table_count = table_count,
        total_fields = total_fields,
        estimated_kb = estimated_kb,
    }
end

-- Full report
function ECSDashboard.report()
    print("\n" .. string.rep("=", 60))
    print("ECS DASHBOARD")
    print(string.rep("=", 60))

    -- Entity count
    local entity_count = ECSDashboard.entity_count()
    print(string.format("\nTotal Entities: %d", entity_count))

    -- Component breakdown
    print("\n" .. string.rep("-", 60))
    print("COMPONENT DISTRIBUTION")
    print(string.rep("-", 60))

    local counts = ECSDashboard.component_counts()
    local sorted = {}
    for name, count in pairs(counts) do
        table.insert(sorted, { name = name, count = count })
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)

    for _, entry in ipairs(sorted) do
        local pct = entity_count > 0 and (entry.count / entity_count * 100) or 0
        print(string.format("  %-20s %5d (%5.1f%%)", entry.name, entry.count, pct))
    end

    -- Script tables
    print("\n" .. string.rep("-", 60))
    print("SCRIPT TABLES")
    print(string.rep("-", 60))

    local scripted, with_data = ECSDashboard.scripted_entity_count()
    print(string.format("  Scripted entities: %d", scripted))
    print(string.format("  With custom data:  %d", with_data))

    local mem = ECSDashboard.estimate_script_memory()
    print(string.format("  Estimated memory:  %.2f KB", mem.estimated_kb))

    -- Orphans
    print("\n" .. string.rep("-", 60))
    print("ORPHAN CHECK")
    print(string.rep("-", 60))

    local orphans, checked = ECSDashboard.find_orphans()
    if #orphans == 0 then
        print("  ✓ No orphaned entities found")
    else
        print(string.format("  ⚠ Found %d potential orphans:", #orphans))
        for i, o in ipairs(orphans) do
            if i <= 10 then  -- Limit output
                print(string.format("    Entity %s (physics: %s)",
                    tostring(o.entity), o.has_physics and "yes" or "no"))
            end
        end
        if #orphans > 10 then
            print(string.format("    ... and %d more", #orphans - 10))
        end
    end

    print("\n" .. string.rep("=", 60))

    return {
        entity_count = entity_count,
        component_counts = counts,
        scripted = scripted,
        orphan_count = #orphans,
    }
end

-- Quick summary (single line)
function ECSDashboard.summary()
    local count = ECSDashboard.entity_count()
    local scripted, _ = ECSDashboard.scripted_entity_count()
    local mem = collectgarbage("count")
    return string.format("Entities: %d | Scripted: %d | Lua Mem: %.1f MB",
        count, scripted, mem / 1024)
end

return ECSDashboard
