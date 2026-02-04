-- assets/scripts/serpent/ui/victory_view_model.lua
--[[
    Victory View-Model Module

    Provides data structure for victory screen UI, including run statistics,
    final snake composition, and UI action buttons (retry/menu).
]]

local victory_view_model = {}

--- Build victory screen view-model from game state
--- @param final_game_state table Final game state when victory was achieved
--- @param run_time_sec number Total run time in seconds
--- @param seed number Run seed for display
--- @return table Victory view-model for UI rendering
function victory_view_model.build(final_game_state, run_time_sec, seed)
    local view_model = {
        -- UI title and headers
        title = "ui.serpent_victory_title",
        subtitle = "Victory Achieved!",

        -- Run statistics
        stats = {
            waves_completed = final_game_state.wave or 20,
            final_gold = final_game_state.gold or 0,
            run_time_sec = run_time_sec or 0,
            run_time_display = victory_view_model._format_time(run_time_sec or 0),
            seed = seed or 12345,
            seed_display = string.format("Seed: %d", seed or 12345)
        },

        -- Snake composition summary
        snake_summary = victory_view_model._build_snake_summary(final_game_state.snake_state),

        -- Action buttons
        buttons = {
            {
                id = "retry",
                label = "Play Again",
                action = "restart_run",
                style = "primary"
            },
            {
                id = "menu",
                label = "Main Menu",
                action = "return_to_menu",
                style = "secondary"
            }
        }
    }

    return view_model
end

--- Build snake composition summary for display
--- @param snake_state table Final snake state with segments
--- @return table Snake summary with counts and class breakdown
function victory_view_model._build_snake_summary(snake_state)
    local summary = {
        total_segments = 0,
        class_counts = {
            Warrior = 0,
            Mage = 0,
            Ranger = 0,
            Support = 0
        },
        level_counts = {
            [1] = 0,
            [2] = 0,
            [3] = 0
        },
        segments_display = {}
    }

    if not snake_state or not snake_state.segments then
        return summary
    end

    -- Count segments by class and level
    for _, segment in ipairs(snake_state.segments) do
        if segment and segment.def_id and segment.level then
            summary.total_segments = summary.total_segments + 1
            summary.level_counts[segment.level] = summary.level_counts[segment.level] + 1

            -- Get class from def_id (simplified mapping)
            local unit_class = victory_view_model._get_unit_class(segment.def_id)
            summary.class_counts[unit_class] = summary.class_counts[unit_class] + 1

            -- Add to display list
            table.insert(summary.segments_display, {
                def_id = segment.def_id,
                level = segment.level,
                class = unit_class,
                hp = segment.hp,
                hp_max = segment.hp_max_base or 100
            })
        end
    end

    return summary
end

--- Get unit class from def_id (simplified mapping)
--- @param def_id string Unit definition ID
--- @return string Class name
function victory_view_model._get_unit_class(def_id)
    -- Simplified class mapping based on unit names
    local class_mapping = {
        -- Warrior
        soldier = "Warrior",
        knight = "Warrior",
        berserker = "Warrior",
        champion = "Warrior",

        -- Mage
        apprentice = "Mage",
        pyromancer = "Mage",
        archmage = "Mage",
        lich = "Mage",

        -- Ranger
        scout = "Ranger",
        sniper = "Ranger",
        assassin = "Ranger",
        windrunner = "Ranger",

        -- Support
        healer = "Support",
        bard = "Support",
        paladin = "Support",
        angel = "Support"
    }

    return class_mapping[def_id] or "Unknown"
end

--- Format time in seconds to MM:SS display format
--- @param seconds number Time in seconds
--- @return string Formatted time string
function victory_view_model._format_time(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d", minutes, secs)
end

--- Get view-model for testing/preview
--- @return table Mock victory view-model
function victory_view_model.get_mock_view_model()
    local mock_game_state = {
        wave = 20,
        gold = 150,
        snake_state = {
            segments = {
                { def_id = "champion", level = 3, hp = 200, hp_max_base = 200 },
                { def_id = "lich", level = 2, hp = 160, hp_max_base = 160 },
                { def_id = "windrunner", level = 3, hp = 200, hp_max_base = 200 },
                { def_id = "angel", level = 2, hp = 180, hp_max_base = 180 }
            }
        }
    }

    return victory_view_model.build(mock_game_state, 847, 54321)
end

--- Generate run summary text for display
--- @param view_model table Victory view-model
--- @return table Array of formatted summary lines
function victory_view_model.get_summary_lines(view_model)
    if not view_model then
        return {}
    end

    local lines = {
        string.format("Waves Completed: %d/20", view_model.stats.waves_completed),
        string.format("Final Gold: %d", view_model.stats.final_gold),
        string.format("Run Time: %s", view_model.stats.run_time_display),
        view_model.stats.seed_display,
        "",
        string.format("Final Snake: %d segments", view_model.snake_summary.total_segments),
    }

    -- Add class breakdown
    local classes = {"Warrior", "Mage", "Ranger", "Support"}
    for _, class in ipairs(classes) do
        local count = view_model.snake_summary.class_counts[class]
        if count > 0 then
            table.insert(lines, string.format("  %s: %d", class, count))
        end
    end

    -- Add level breakdown
    table.insert(lines, "")
    table.insert(lines, "Level Distribution:")
    for level = 1, 3 do
        local count = view_model.snake_summary.level_counts[level]
        if count > 0 then
            table.insert(lines, string.format("  Level %d: %d units", level, count))
        end
    end

    return lines
end

--- Test the victory view-model functionality
--- @return boolean True if view-model generation works correctly
function victory_view_model.test_view_model_generation()
    local mock_view_model = victory_view_model.get_mock_view_model()

    -- Test basic structure
    if not mock_view_model.title or mock_view_model.title ~= "ui.serpent_victory_title" then
        return false
    end

    if not mock_view_model.stats or mock_view_model.stats.waves_completed ~= 20 then
        return false
    end

    if not mock_view_model.snake_summary or mock_view_model.snake_summary.total_segments ~= 4 then
        return false
    end

    if not mock_view_model.buttons or #mock_view_model.buttons ~= 2 then
        return false
    end

    -- Test button structure
    local retry_button = mock_view_model.buttons[1]
    if retry_button.id ~= "retry" or retry_button.action ~= "restart_run" then
        return false
    end

    local menu_button = mock_view_model.buttons[2]
    if menu_button.id ~= "menu" or menu_button.action ~= "return_to_menu" then
        return false
    end

    -- Test time formatting
    local formatted_time = victory_view_model._format_time(847)
    if formatted_time ~= "14:07" then
        return false
    end

    -- Test summary lines generation
    local summary_lines = victory_view_model.get_summary_lines(mock_view_model)
    if not summary_lines or #summary_lines < 5 then
        return false
    end

    return true
end

return victory_view_model