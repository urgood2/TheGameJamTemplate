-- assets/scripts/serpent/ui/synergy_display_ui.lua
--[[
    Synergy Display UI Module

    Provides view-model for displaying class counts and active synergy bonuses.
    Integrates with synergy_system to show unit type counts and their bonuses.
]]

local synergy_system = require("serpent.synergy_system")

local synergy_display_ui = {}

--- Get view model data for synergy display
--- @param segments table Array of current snake segments
--- @param unit_defs table Unit definitions for class lookup
--- @return table View model with class counts and active synergy descriptions
function synergy_display_ui.get_view_model(segments, unit_defs)
    -- Calculate synergy state
    local synergy_state = synergy_system.calculate(segments, unit_defs)
    local synergy_summary = synergy_system.get_synergy_summary(synergy_state)

    local view_model = {
        class_counts = synergy_summary.class_counts or {},
        active_synergies = {},
        has_synergies = false,
        total_units = 0,
        global_regen = synergy_system.get_global_regen_rate(synergy_state)
    }

    -- Calculate total units
    for class, count in pairs(view_model.class_counts) do
        view_model.total_units = view_model.total_units + count
    end

    -- Process active synergies for display
    for _, synergy_info in ipairs(synergy_summary.active_synergies or {}) do
        local class = synergy_info.class
        local count = synergy_info.count
        local description = synergy_info.description

        -- Create display entry for each active synergy
        table.insert(view_model.active_synergies, {
            class = class,
            count = count,
            threshold = synergy_display_ui._get_threshold_for_count(count),
            description = description,
            display_text = string.format("%d %s: %s", count, class, description)
        })

        view_model.has_synergies = true
    end

    -- Sort active synergies by class name for consistent display
    table.sort(view_model.active_synergies, function(a, b)
        return a.class < b.class
    end)

    return view_model
end

--- Get threshold level for a unit count
--- @param count number Number of units of a class
--- @return number Synergy threshold level (2 or 4)
function synergy_display_ui._get_threshold_for_count(count)
    if count >= 4 then
        return 4
    elseif count >= 2 then
        return 2
    else
        return 0
    end
end

--- Get display summary text for synergy state
--- @param segments table Array of current snake segments
--- @param unit_defs table Unit definitions for class lookup
--- @return string Formatted summary text for display
function synergy_display_ui.get_summary_text(segments, unit_defs)
    local view_model = synergy_display_ui.get_view_model(segments, unit_defs)

    if not view_model.has_synergies then
        return "No active synergies"
    end

    local parts = {}

    -- Add active synergy descriptions
    for _, synergy in ipairs(view_model.active_synergies) do
        table.insert(parts, synergy.display_text)
    end

    -- Add global regen info if present
    if view_model.global_regen > 0 then
        table.insert(parts, string.format("Global Regen: %.1f HP/sec", view_model.global_regen))
    end

    return table.concat(parts, "\n")
end

--- Get class count display for UI
--- @param segments table Array of current snake segments
--- @param unit_defs table Unit definitions for class lookup
--- @return table Array of class count entries for display
function synergy_display_ui.get_class_counts_display(segments, unit_defs)
    local view_model = synergy_display_ui.get_view_model(segments, unit_defs)
    local display_counts = {}

    -- Standard class order for consistent display
    local class_order = {"Warrior", "Mage", "Ranger", "Support"}

    for _, class in ipairs(class_order) do
        local count = view_model.class_counts[class] or 0
        local threshold = synergy_display_ui._get_threshold_for_count(count)

        -- Determine display status
        local status = "none"
        if threshold >= 4 then
            status = "max"
        elseif threshold >= 2 then
            status = "active"
        elseif count > 0 then
            status = "partial"
        end

        table.insert(display_counts, {
            class = class,
            count = count,
            threshold = threshold,
            status = status,
            next_threshold = count < 2 and 2 or (count < 4 and 4 or nil),
            progress_text = synergy_display_ui._get_progress_text(class, count)
        })
    end

    return display_counts
end

--- Get progress text for a class towards next threshold
--- @param class string Class name
--- @param count number Current count
--- @return string Progress text (e.g., "1/2", "4/4")
function synergy_display_ui._get_progress_text(class, count)
    if count >= 4 then
        return "4/4"
    elseif count >= 2 then
        return string.format("%d/4", count)
    else
        return string.format("%d/2", count)
    end
end

--- Get synergy requirements info for tooltips
--- @return table Synergy requirements by class
function synergy_display_ui.get_synergy_requirements()
    return {
        Warrior = {
            [2] = "2 Warriors: +20% attack damage to Warriors",
            [4] = "4 Warriors: +40% attack damage, +20% HP to Warriors"
        },
        Mage = {
            [2] = "2 Mages: +20% spell damage to Mages",
            [4] = "4 Mages: +40% spell damage, -20% cooldown to Mages"
        },
        Ranger = {
            [2] = "2 Rangers: +20% attack speed to Rangers",
            [4] = "4 Rangers: +40% attack speed, +20% range to Rangers"
        },
        Support = {
            [2] = "2 Support: Heal snake 5 HP/sec",
            [4] = "4 Support: Heal 10 HP/sec, +10% all stats"
        }
    }
end

--- Check if synergy display should be visible
--- @param segments table Array of current snake segments
--- @param unit_defs table Unit definitions
--- @return boolean True if there are units to show synergy info for
function synergy_display_ui.should_show(segments, unit_defs)
    if not segments or #segments == 0 then
        return false
    end

    local view_model = synergy_display_ui.get_view_model(segments, unit_defs)
    return view_model.total_units > 0
end

return synergy_display_ui