-- assets/scripts/serpent/hp_bar_view_model.lua
--[[
    HP Bar View-Model Module

    Provides HP percentage calculation for the Serpent UI using the formula:
    HP percentage = sum(hp) / sum(effective_hp_max) across all segments

    Effective HP max is computed with current synergy/passive bonuses.
]]

-- Mock log functions for environments that don't have them
local log_debug = log_debug or function(msg) end
local log_warning = log_warning or function(msg) end

local hp_bar_view_model = {}

--- Calculate effective HP max for a segment including synergy/passive bonuses
--- @param segment table Segment data with base hp_max
--- @param synergy_state table Current synergy state with multipliers
--- @param unit_def table Unit definition with base stats
--- @return number Effective HP max after applying bonuses
local function calculate_effective_hp_max(segment, synergy_state, unit_def)
    if not segment or not unit_def then
        return 0
    end

    local base_hp_max = unit_def.hp_max or segment.hp_max or 100
    local effective_hp_max = base_hp_max

    -- Apply synergy bonuses if synergy_state exists
    if synergy_state and synergy_state.class_multipliers then
        local unit_class = unit_def.class or "warrior" -- Default class
        local class_multiplier = synergy_state.class_multipliers[unit_class]

        if class_multiplier and class_multiplier.hp_multiplier then
            effective_hp_max = effective_hp_max * class_multiplier.hp_multiplier
        end
    end

    -- Apply level scaling: HP = base_hp * 2^(level-1)
    local level = segment.level or 1
    if level > 1 then
        local level_multiplier = math.pow(2, level - 1)
        effective_hp_max = effective_hp_max * level_multiplier
    end

    -- Apply global HP multiplier if present in synergy state
    if synergy_state and synergy_state.global_hp_multiplier then
        effective_hp_max = effective_hp_max * synergy_state.global_hp_multiplier
    end

    -- Round to integer (HP values are integers according to PLAN.md)
    return math.floor(effective_hp_max + 0.00001)
end

--- Calculate HP bar percentage from snake state
--- @param snake_state table Current snake state with segments
--- @param synergy_state table Current synergy state (optional)
--- @param unit_defs table Unit definitions keyed by def_id (optional)
--- @return number HP percentage (0.0 to 1.0), or 0 if no segments
function hp_bar_view_model.calculate_hp_percentage(snake_state, synergy_state, unit_defs)
    if not snake_state or not snake_state.segments or #snake_state.segments == 0 then
        return 0.0
    end

    local total_hp = 0
    local total_effective_hp_max = 0

    -- Sum HP and effective HP max across all segments
    for _, segment in ipairs(snake_state.segments) do
        if segment then
            -- Get current HP (should always be valid)
            local current_hp = segment.hp or 0
            total_hp = total_hp + current_hp

            -- Get unit definition for effective HP max calculation
            local unit_def = nil
            if unit_defs and segment.def_id then
                unit_def = unit_defs[segment.def_id]
            end

            -- Calculate effective HP max with bonuses
            local effective_hp_max = calculate_effective_hp_max(segment, synergy_state, unit_def)
            total_effective_hp_max = total_effective_hp_max + effective_hp_max
        end
    end

    -- Calculate percentage, avoiding division by zero
    if total_effective_hp_max <= 0 then
        return 0.0
    end

    local percentage = total_hp / total_effective_hp_max
    return math.max(0.0, math.min(1.0, percentage)) -- Clamp to [0, 1]
end

--- Get detailed HP information for debugging
--- @param snake_state table Current snake state with segments
--- @param synergy_state table Current synergy state (optional)
--- @param unit_defs table Unit definitions (optional)
--- @return table Detailed HP breakdown
function hp_bar_view_model.get_hp_breakdown(snake_state, synergy_state, unit_defs)
    local breakdown = {
        total_hp = 0,
        total_effective_hp_max = 0,
        percentage = 0.0,
        segment_count = 0,
        segments = {}
    }

    if not snake_state or not snake_state.segments then
        return breakdown
    end

    breakdown.segment_count = #snake_state.segments

    -- Analyze each segment
    for i, segment in ipairs(snake_state.segments) do
        if segment then
            local current_hp = segment.hp or 0

            local unit_def = nil
            if unit_defs and segment.def_id then
                unit_def = unit_defs[segment.def_id]
            end

            local effective_hp_max = calculate_effective_hp_max(segment, synergy_state, unit_def)

            breakdown.total_hp = breakdown.total_hp + current_hp
            breakdown.total_effective_hp_max = breakdown.total_effective_hp_max + effective_hp_max

            table.insert(breakdown.segments, {
                index = i,
                instance_id = segment.instance_id,
                def_id = segment.def_id,
                level = segment.level or 1,
                current_hp = current_hp,
                effective_hp_max = effective_hp_max,
                percentage = effective_hp_max > 0 and (current_hp / effective_hp_max) or 0.0
            })
        end
    end

    breakdown.percentage = hp_bar_view_model.calculate_hp_percentage(snake_state, synergy_state, unit_defs)

    return breakdown
end

--- Create HP bar view-model data for UI rendering
--- @param snake_state table Current snake state
--- @param synergy_state table Current synergy state (optional)
--- @param unit_defs table Unit definitions (optional)
--- @return table View-model data for HP bar
function hp_bar_view_model.create_hp_bar_data(snake_state, synergy_state, unit_defs)
    local hp_percentage = hp_bar_view_model.calculate_hp_percentage(snake_state, synergy_state, unit_defs)

    return {
        percentage = hp_percentage,
        percentage_display = string.format("%.1f%%", hp_percentage * 100),
        color = hp_bar_view_model.get_hp_bar_color(hp_percentage),
        is_critical = hp_percentage <= 0.25, -- Critical below 25%
        is_healthy = hp_percentage >= 0.75,  -- Healthy above 75%
        is_visible = hp_percentage > 0       -- Hide if no HP
    }
end

--- Get color for HP bar based on percentage
--- @param percentage number HP percentage (0.0 to 1.0)
--- @return table Color data with r, g, b values
function hp_bar_view_model.get_hp_bar_color(percentage)
    if percentage <= 0.25 then
        -- Critical: Red
        return { r = 1.0, g = 0.0, b = 0.0, name = "critical" }
    elseif percentage <= 0.5 then
        -- Low: Orange/Yellow
        return { r = 1.0, g = 0.5, b = 0.0, name = "low" }
    elseif percentage <= 0.75 then
        -- Medium: Yellow
        return { r = 1.0, g = 1.0, b = 0.0, name = "medium" }
    else
        -- Healthy: Green
        return { r = 0.0, g = 1.0, b = 0.0, name = "healthy" }
    end
end

--- Check if HP bar should be displayed (has segments with HP)
--- @param snake_state table Current snake state
--- @return boolean True if HP bar should be shown
function hp_bar_view_model.should_show_hp_bar(snake_state)
    if not snake_state or not snake_state.segments or #snake_state.segments == 0 then
        return false
    end

    -- Show if any segment has HP > 0
    for _, segment in ipairs(snake_state.segments) do
        if segment and (segment.hp or 0) > 0 then
            return true
        end
    end

    return false
end

--- Test HP percentage calculation
--- @return boolean True if HP calculation works correctly
function hp_bar_view_model.test_hp_calculation()
    -- Test case 1: Simple calculation without bonuses
    local snake_state = {
        segments = {
            { hp = 50, hp_max = 100, def_id = "warrior" },
            { hp = 75, hp_max = 100, def_id = "ranger" },
            { hp = 25, hp_max = 100, def_id = "mage" }
        }
    }

    local unit_defs = {
        warrior = { hp_max = 100, class = "warrior" },
        ranger = { hp_max = 100, class = "ranger" },
        mage = { hp_max = 100, class = "mage" }
    }

    local percentage = hp_bar_view_model.calculate_hp_percentage(snake_state, nil, unit_defs)
    local expected = (50 + 75 + 25) / (100 + 100 + 100) -- 150/300 = 0.5

    if math.abs(percentage - expected) > 0.001 then
        log_warning(string.format("HP calculation test failed: expected %.3f, got %.3f", expected, percentage))
        return false
    end

    -- Test case 2: With level scaling
    local snake_state_leveled = {
        segments = {
            { hp = 100, hp_max = 100, level = 1, def_id = "warrior" }, -- effective_max = 100
            { hp = 150, hp_max = 100, level = 2, def_id = "warrior" }, -- effective_max = 200
        }
    }

    percentage = hp_bar_view_model.calculate_hp_percentage(snake_state_leveled, nil, unit_defs)
    expected = (100 + 150) / (100 + 200) -- 250/300 = 0.833...

    if math.abs(percentage - expected) > 0.001 then
        log_warning(string.format("Level scaling test failed: expected %.3f, got %.3f", expected, percentage))
        return false
    end

    -- Test case 3: Empty snake state
    percentage = hp_bar_view_model.calculate_hp_percentage(nil, nil, nil)
    if percentage ~= 0.0 then
        log_warning("Empty state test failed")
        return false
    end

    log_debug("[HPBarViewModel] All HP calculation tests passed")
    return true
end

--- Test HP bar color calculation
--- @return boolean True if color calculation works correctly
function hp_bar_view_model.test_hp_bar_colors()
    local color_tests = {
        { percentage = 0.9, expected_name = "healthy" },
        { percentage = 0.6, expected_name = "medium" },
        { percentage = 0.4, expected_name = "low" },
        { percentage = 0.1, expected_name = "critical" }
    }

    for _, test in ipairs(color_tests) do
        local color = hp_bar_view_model.get_hp_bar_color(test.percentage)
        if color.name ~= test.expected_name then
            log_warning(string.format("Color test failed: %.1f%% expected %s, got %s",
                        test.percentage * 100, test.expected_name, color.name))
            return false
        end
    end

    log_debug("[HPBarViewModel] All color tests passed")
    return true
end

--- Run all HP bar view-model tests
--- @return boolean True if all tests pass
function hp_bar_view_model.run_all_tests()
    local tests = {
        { "hp_calculation", hp_bar_view_model.test_hp_calculation },
        { "hp_bar_colors", hp_bar_view_model.test_hp_bar_colors },
    }

    local passed = 0
    local total = #tests

    log_debug("[HPBarViewModel] Running " .. total .. " tests...")

    for _, test in ipairs(tests) do
        local test_name, test_func = test[1], test[2]
        local success = test_func()

        if success then
            log_debug("[HPBarViewModel] ✓ " .. test_name)
            passed = passed + 1
        else
            log_warning("[HPBarViewModel] ✗ " .. test_name)
        end
    end

    log_debug(string.format("[HPBarViewModel] Results: %d/%d tests passed", passed, total))
    return passed == total
end

return hp_bar_view_model