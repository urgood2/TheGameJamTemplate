-- assets/scripts/serpent/ui/synergy_ui.lua
--[[
    Synergy UI Module

    Provides view-model functionality for displaying synergy information
    from the synergy_state in the Serpent minigame UI.
]]

local Text = require("core.text")

-- Mock log functions for environments that don't have them
local log_debug = log_debug or function(msg) end
local log_warning = log_warning or function(msg) end

local synergy_ui = {}

-- Active text handles for cleanup
local activeHandles = {}

-- Track if synergy UI is visible
synergy_ui.isVisible = false

--- Initialize synergy UI
function synergy_ui.init()
    activeHandles = {}
    synergy_ui.isVisible = false
end

--- Show synergy display from synergy_state
--- @param synergy_state table Current synergy state with class counts and multipliers
--- @param snake_state table Current snake state (optional, for context)
function synergy_ui.show(synergy_state, snake_state)
    if synergy_ui.isVisible then return end
    synergy_ui.isVisible = true

    local screenW = globals.screenWidth()
    local screenH = globals.screenHeight()

    -- Clear any existing handles
    synergy_ui.hide()

    -- Render synergy information
    synergy_ui._renderSynergyTitle(screenW, screenH)
    synergy_ui._renderClassCounts(screenW, screenH, synergy_state)
    synergy_ui._renderActiveMultipliers(screenW, screenH, synergy_state)

    log_debug("[SynergyUI] Shown")
end

--- Hide synergy UI
function synergy_ui.hide()
    if not synergy_ui.isVisible then return end
    synergy_ui.isVisible = false

    -- Stop all active text handles
    for _, handle in ipairs(activeHandles) do
        if handle and handle.stop then
            handle:stop()
        end
    end
    activeHandles = {}

    log_debug("[SynergyUI] Hidden")
end

--- Render synergy title
function synergy_ui._renderSynergyTitle(screenW, screenH)
    local titleRecipe = Text.define()
        :content("[SYNERGIES](color=cyan)")
        :size(24)
        :anchor("topleft")
        :space("screen")
        :z(1000)

    local titleHandle = titleRecipe:spawn():at(20, 20)
    table.insert(activeHandles, titleHandle)
end

--- Render class counts from synergy state
function synergy_ui._renderClassCounts(screenW, screenH, synergy_state)
    if not synergy_state or not synergy_state.class_counts then
        return
    end

    local startY = 60
    local lineHeight = 25

    for class_name, count in pairs(synergy_state.class_counts) do
        if count > 0 then
            local classRecipe = Text.define()
                :content(string.format("[%s: %d](color=white)", class_name, count))
                :size(18)
                :anchor("topleft")
                :space("screen")
                :z(1000)

            local classHandle = classRecipe:spawn():at(20, startY)
            table.insert(activeHandles, classHandle)

            startY = startY + lineHeight
        end
    end
end

--- Render active synergy multipliers
function synergy_ui._renderActiveMultipliers(screenW, screenH, synergy_state)
    if not synergy_state or not synergy_state.class_multipliers then
        return
    end

    local startY = 60
    local lineHeight = 25
    local rightColumnX = 250

    for class_name, multipliers in pairs(synergy_state.class_multipliers) do
        local has_bonuses = false
        local bonus_text = class_name .. ": "
        local bonus_parts = {}

        -- Check for attack multiplier
        if multipliers.atk_multiplier and multipliers.atk_multiplier > 1.0 then
            table.insert(bonus_parts, string.format("%.0f%% ATK", (multipliers.atk_multiplier - 1.0) * 100))
            has_bonuses = true
        end

        -- Check for HP multiplier
        if multipliers.hp_multiplier and multipliers.hp_multiplier > 1.0 then
            table.insert(bonus_parts, string.format("%.0f%% HP", (multipliers.hp_multiplier - 1.0) * 100))
            has_bonuses = true
        end

        -- Check for attack speed multiplier
        if multipliers.atk_spd_multiplier and multipliers.atk_spd_multiplier > 1.0 then
            table.insert(bonus_parts, string.format("%.0f%% SPD", (multipliers.atk_spd_multiplier - 1.0) * 100))
            has_bonuses = true
        end

        -- Check for other multipliers
        if multipliers.range_multiplier and multipliers.range_multiplier > 1.0 then
            table.insert(bonus_parts, string.format("%.0f%% RNG", (multipliers.range_multiplier - 1.0) * 100))
            has_bonuses = true
        end

        if has_bonuses then
            bonus_text = bonus_text .. table.concat(bonus_parts, ", ")

            local multiplierRecipe = Text.define()
                :content(string.format("[%s](color=green)", bonus_text))
                :size(16)
                :anchor("topleft")
                :space("screen")
                :z(1000)

            local multiplierHandle = multiplierRecipe:spawn():at(rightColumnX, startY)
            table.insert(activeHandles, multiplierHandle)

            startY = startY + lineHeight
        end
    end
end

--- Get synergy view-model data for external use
--- @param synergy_state table Current synergy state
--- @param unit_defs table Unit definitions for class information
--- @return table View-model with synergy display data
function synergy_ui.get_view_model(synergy_state, unit_defs)
    local view_model = {
        class_counts = {},
        active_multipliers = {},
        synergy_threshold_info = {}
    }

    if not synergy_state then
        return view_model
    end

    -- Extract class counts
    if synergy_state.class_counts then
        for class_name, count in pairs(synergy_state.class_counts) do
            if count > 0 then
                view_model.class_counts[class_name] = count
            end
        end
    end

    -- Extract active multipliers
    if synergy_state.class_multipliers then
        for class_name, multipliers in pairs(synergy_state.class_multipliers) do
            local class_bonuses = {}

            if multipliers.atk_multiplier and multipliers.atk_multiplier > 1.0 then
                class_bonuses.attack_bonus = (multipliers.atk_multiplier - 1.0) * 100
            end

            if multipliers.hp_multiplier and multipliers.hp_multiplier > 1.0 then
                class_bonuses.hp_bonus = (multipliers.hp_multiplier - 1.0) * 100
            end

            if multipliers.atk_spd_multiplier and multipliers.atk_spd_multiplier > 1.0 then
                class_bonuses.speed_bonus = (multipliers.atk_spd_multiplier - 1.0) * 100
            end

            if multipliers.range_multiplier and multipliers.range_multiplier > 1.0 then
                class_bonuses.range_bonus = (multipliers.range_multiplier - 1.0) * 100
            end

            if next(class_bonuses) then -- Only include if has bonuses
                view_model.active_multipliers[class_name] = class_bonuses
            end
        end
    end

    -- Extract synergy threshold information
    if synergy_state.synergy_thresholds then
        for class_name, thresholds in pairs(synergy_state.synergy_thresholds) do
            local current_count = synergy_state.class_counts and synergy_state.class_counts[class_name] or 0
            local threshold_info = {
                current_count = current_count,
                next_threshold = nil,
                next_threshold_count = nil,
                progress_to_next = 0
            }

            -- Find next threshold
            for threshold_count, threshold_data in pairs(thresholds) do
                if current_count < threshold_count then
                    if not threshold_info.next_threshold_count or threshold_count < threshold_info.next_threshold_count then
                        threshold_info.next_threshold = threshold_data
                        threshold_info.next_threshold_count = threshold_count
                    end
                end
            end

            if threshold_info.next_threshold_count then
                threshold_info.progress_to_next = current_count / threshold_info.next_threshold_count
            end

            view_model.synergy_threshold_info[class_name] = threshold_info
        end
    end

    return view_model
end

--- Get compact synergy summary for HUD display
--- @param synergy_state table Current synergy state
--- @return table Compact synergy summary
function synergy_ui.get_compact_summary(synergy_state)
    local summary = {
        active_count = 0,
        total_bonuses = 0,
        strongest_class = nil,
        strongest_bonus = 0
    }

    if not synergy_state or not synergy_state.class_multipliers then
        return summary
    end

    -- Count active synergies and find strongest
    for class_name, multipliers in pairs(synergy_state.class_multipliers) do
        local has_bonus = false
        local total_bonus = 0

        if multipliers.atk_multiplier and multipliers.atk_multiplier > 1.0 then
            total_bonus = total_bonus + (multipliers.atk_multiplier - 1.0) * 100
            has_bonus = true
        end

        if multipliers.hp_multiplier and multipliers.hp_multiplier > 1.0 then
            total_bonus = total_bonus + (multipliers.hp_multiplier - 1.0) * 100
            has_bonus = true
        end

        if multipliers.atk_spd_multiplier and multipliers.atk_spd_multiplier > 1.0 then
            total_bonus = total_bonus + (multipliers.atk_spd_multiplier - 1.0) * 100
            has_bonus = true
        end

        if has_bonus then
            summary.active_count = summary.active_count + 1
            summary.total_bonuses = summary.total_bonuses + total_bonus

            if total_bonus > summary.strongest_bonus then
                summary.strongest_bonus = total_bonus
                summary.strongest_class = class_name
            end
        end
    end

    return summary
end

--- Check if synergy UI should be displayed
--- @param synergy_state table Current synergy state
--- @return boolean True if synergy UI should be shown
function synergy_ui.should_show_synergy_ui(synergy_state)
    if not synergy_state then
        return false
    end

    -- Show if any class has units
    if synergy_state.class_counts then
        for class_name, count in pairs(synergy_state.class_counts) do
            if count > 0 then
                return true
            end
        end
    end

    return false
end

--- Test synergy view-model generation
--- @return boolean True if view-model generation works correctly
function synergy_ui.test_view_model_generation()
    local test_synergy_state = {
        class_counts = {
            warrior = 3,
            ranger = 2,
            mage = 1
        },
        class_multipliers = {
            warrior = {
                atk_multiplier = 1.2,
                hp_multiplier = 1.4
            },
            ranger = {
                atk_spd_multiplier = 1.1
            }
        }
    }

    local view_model = synergy_ui.get_view_model(test_synergy_state)

    -- Check class counts
    if view_model.class_counts.warrior ~= 3 or view_model.class_counts.ranger ~= 2 then
        log_warning("Class counts test failed")
        return false
    end

    -- Check active multipliers
    if not view_model.active_multipliers.warrior or
       not view_model.active_multipliers.warrior.attack_bonus or
       not view_model.active_multipliers.warrior.hp_bonus then
        log_warning("Warrior multipliers test failed")
        return false
    end

    if math.abs(view_model.active_multipliers.warrior.attack_bonus - 20) > 0.1 then
        log_warning("Attack bonus calculation failed")
        return false
    end

    -- Check compact summary
    local summary = synergy_ui.get_compact_summary(test_synergy_state)
    if summary.active_count ~= 2 then
        log_warning("Active count test failed")
        return false
    end

    log_debug("[SynergyUI] View-model tests passed")
    return true
end

--- Run all synergy UI tests
--- @return boolean True if all tests pass
function synergy_ui.run_all_tests()
    local tests = {
        { "view_model_generation", synergy_ui.test_view_model_generation },
    }

    local passed = 0
    local total = #tests

    log_debug("[SynergyUI] Running " .. total .. " tests...")

    for _, test in ipairs(tests) do
        local test_name, test_func = test[1], test[2]
        local success = test_func()

        if success then
            log_debug("[SynergyUI] ✓ " .. test_name)
            passed = passed + 1
        else
            log_warning("[SynergyUI] ✗ " .. test_name)
        end
    end

    log_debug(string.format("[SynergyUI] Results: %d/%d tests passed", passed, total))
    return passed == total
end

return synergy_ui