-- assets/scripts/serpent/ui/game_over_screen.lua
--[[
    Game Over Screen Module

    Displays game over screen with run statistics and retry/menu options
    for the Serpent minigame when snake length reaches 0.
    Implements PLAN.md Task 20 requirements with localization support.
]]

local Text = require("core.text")
local signal = require("external.hump.signal")

-- Mock log functions for environments that don't have them
local log_debug = log_debug or function(msg) end
local log_warning = log_warning or function(msg) end

local game_over_screen = {}

-- Active text handles for cleanup
local activeHandles = {}
local buttonBounds = {}

-- Track if game over screen is visible
game_over_screen.isVisible = false

-- Cache run statistics for display
local cachedRunStats = nil

--- Show the game over screen
--- @param run_stats table Run statistics (waves cleared, gold earned, units purchased, final wave, etc.)
function game_over_screen.show(run_stats)
    if GameOverScreen.isVisible then return end
    GameOverScreen.isVisible = true

    -- Cache stats for display
    cachedStats = stats or {}

    local screenW = globals.screenWidth()
    local screenH = globals.screenHeight()
    local centerX = screenW / 2
    local centerY = screenH / 2

    -- Clear any existing handles
    GameOverScreen.hide()

    -- "GAME OVER" title - large, red, dramatic
    local titleRecipe = Text.define()
        :content("[GAME OVER](color=red)")
        :size(72)
        :anchor("center")
        :space("screen")
        :z(1000)
        :pop(0.8)

    local titleHandle = titleRecipe:spawn():at(centerX, centerY - 120)
    table.insert(activeHandles, titleHandle)

    -- Display final stats if provided
    GameOverScreen._renderStats(centerX, centerY - 40)

    -- "Restart" button
    local restartRecipe = Text.define()
        :content("[Restart](color=yellow)")
        :size(32)
        :anchor("center")
        :space("screen")
        :z(1000)

    local restartHandle = restartRecipe:spawn():at(centerX - 80, centerY + 80)
    table.insert(activeHandles, restartHandle)

    -- "Main Menu" button
    local menuRecipe = Text.define()
        :content("[Main Menu](color=white)")
        :size(32)
        :anchor("center")
        :space("screen")
        :z(1000)

    local menuHandle = menuRecipe:spawn():at(centerX + 80, centerY + 80)
    table.insert(activeHandles, menuHandle)

    -- Store button bounds for click detection
    buttonBounds["restart"] = {
        x = centerX - 140,
        y = centerY + 60,
        w = 120,
        h = 40
    }

    buttonBounds["menu"] = {
        x = centerX + 20,
        y = centerY + 60,
        w = 120,
        h = 40
    }

    log_debug("[GameOverScreen] Shown")
end

--- Hide the game over screen
function GameOverScreen.hide()
    if not GameOverScreen.isVisible then return end
    GameOverScreen.isVisible = false

    -- Stop all active text handles
    for _, handle in ipairs(activeHandles) do
        if handle and handle.stop then
            handle:stop()
        end
    end
    activeHandles = {}
    buttonBounds = {}
    cachedStats = nil

    log_debug("[GameOverScreen] Hidden")
end

--- Render game statistics
--- @param centerX number Center X position for stats
--- @param centerY number Center Y position for stats
function GameOverScreen._renderStats(centerX, centerY)
    if not cachedStats then return end

    local statsText = {}

    -- Wave reached
    if cachedStats.wave_reached then
        table.insert(statsText, string.format("Wave Reached: %d", cachedStats.wave_reached))
    end

    -- Enemies killed
    if cachedStats.enemies_killed then
        table.insert(statsText, string.format("Enemies Killed: %d", cachedStats.enemies_killed))
    end

    -- Time survived
    if cachedStats.time_survived then
        local minutes = math.floor(cachedStats.time_survived / 60)
        local seconds = math.floor(cachedStats.time_survived % 60)
        table.insert(statsText, string.format("Time Survived: %02d:%02d", minutes, seconds))
    end

    -- Gold earned
    if cachedStats.gold_earned then
        table.insert(statsText, string.format("Gold Earned: %d", cachedStats.gold_earned))
    end

    -- Render stats if we have any
    if #statsText > 0 then
        local statsContent = table.concat(statsText, "\n")
        local statsRecipe = Text.define()
            :content(string.format("[%s](color=gray)", statsContent))
            :size(20)
            :anchor("center")
            :space("screen")
            :z(1000)

        local statsHandle = statsRecipe:spawn():at(centerX, centerY)
        table.insert(activeHandles, statsHandle)
    end
end

--- Check for button clicks
--- @param mouseX number Mouse X position
--- @param mouseY number Mouse Y position
--- @param clicked boolean Whether mouse was clicked this frame
function GameOverScreen.checkClick(mouseX, mouseY, clicked)
    if not GameOverScreen.isVisible or not clicked then return end

    -- Check restart button
    local restartBounds = buttonBounds["restart"]
    if restartBounds and GameOverScreen._pointInBounds(mouseX, mouseY, restartBounds) then
        GameOverScreen._handleRestartClick()
        return
    end

    -- Check main menu button
    local menuBounds = buttonBounds["menu"]
    if menuBounds and GameOverScreen._pointInBounds(mouseX, mouseY, menuBounds) then
        GameOverScreen._handleMenuClick()
        return
    end
end

--- Handle restart button click
function GameOverScreen._handleRestartClick()
    log_debug("[GameOverScreen] Restart clicked")
    GameOverScreen.hide()
    signal.emit("game_restart")
end

--- Handle main menu button click
function GameOverScreen._handleMenuClick()
    log_debug("[GameOverScreen] Main menu clicked")
    GameOverScreen.hide()
    signal.emit("game_main_menu")
end

--- Check if point is within bounds
--- @param x number Point X coordinate
--- @param y number Point Y coordinate
--- @param bounds table Bounds with x, y, w, h
--- @return boolean True if point is within bounds
function GameOverScreen._pointInBounds(x, y, bounds)
    return x >= bounds.x and x <= bounds.x + bounds.w and
           y >= bounds.y and y <= bounds.y + bounds.h
end

--- Alternative: handle any click to restart (simpler UX)
function GameOverScreen.handleAnyClick()
    if not GameOverScreen.isVisible then return end
    log_debug("[GameOverScreen] Any click - restarting game")
    GameOverScreen.hide()
    signal.emit("game_restart")
end

--- Get view model for external rendering (PLAN.md Task 20 compliant)
--- @param run_stats table Run statistics with waves cleared, gold earned, units purchased
--- @return table View model with formatted stats and localization keys
function game_over_screen.get_view_model(run_stats)
    local stats = run_stats or {}

    local view_model = {
        isVisible = game_over_screen.isVisible,
        title = "GAME OVER",
        stats = {
            final_wave = stats.final_wave or stats.waves_cleared or 0,
            gold_earned = stats.gold_earned or 0,
            units_purchased = stats.units_purchased or 0,
            final_snake_length = stats.final_snake_length or 0,
            enemies_defeated = stats.enemies_defeated or 0,
            game_duration = stats.game_duration or 0
        },
        buttons = {
            retry = {
                enabled = true,
                label = "Retry",
                localization_key = "ui.serpent_retry"
            },
            main_menu = {
                enabled = true,
                label = "Main Menu",
                localization_key = "ui.serpent_main_menu"
            }
        },
        localization_keys = {
            title = "ui.serpent_game_over_title",
            retry = "ui.serpent_retry",
            main_menu = "ui.serpent_main_menu"
        }
    }

    return view_model
end

--- Check if the game should show game over (snake length 0)
--- @param snake_state table Current snake state
--- @return boolean True if game over conditions are met
function game_over_screen.should_show_game_over(snake_state)
    if not snake_state or not snake_state.segments then
        return true -- No snake state = game over
    end

    -- Game over when snake length reaches 0 (PLAN.md requirement)
    return #snake_state.segments == 0
end

--- Calculate final game statistics from game state
--- @param snake_state table Final snake state
--- @param wave_num number Final wave number reached
--- @param gold number Final gold amount
--- @param tracked_stats table Additional tracked statistics
--- @return table Complete run statistics for display
function game_over_screen.calculate_final_stats(snake_state, wave_num, gold, tracked_stats)
    local stats = tracked_stats or {}

    return {
        final_wave = wave_num,
        waves_cleared = math.max(0, wave_num - 1), -- Cleared = reached - 1
        gold_earned = stats.total_gold_earned or gold,
        units_purchased = stats.units_purchased or 0,
        final_snake_length = snake_state and #(snake_state.segments or {}) or 0,
        enemies_defeated = stats.enemies_defeated or 0,
        game_duration = stats.game_duration or 0,
        highest_synergy = stats.highest_synergy or "None",
        death_cause = stats.death_cause or "Combat"
    }
end

--- Create summary text for quick display
--- @param run_stats table Run statistics
--- @return string Formatted summary text
function game_over_screen.get_summary_text(run_stats)
    local stats = run_stats or {}
    local waves = stats.final_wave or stats.waves_cleared or 0
    local gold = stats.gold_earned or 0

    if waves > 0 then
        return string.format("Reached Wave %d • Earned %d Gold", waves, gold)
    else
        return "Try again to reach higher waves!"
    end
end

--- Test game over view-model generation (PLAN.md Task 20 test requirement)
--- @return boolean True if view-model generation works correctly
function game_over_screen.test_view_model_generation()
    local test_stats = {
        final_wave = 15,
        gold_earned = 450,
        units_purchased = 12,
        final_snake_length = 0,
        enemies_defeated = 89
    }

    local view_model = game_over_screen.get_view_model(test_stats)

    -- Check required labels present in view-model (PLAN.md requirement)
    if view_model.stats.final_wave ~= 15 or view_model.stats.gold_earned ~= 450 then
        log_warning("View-model basic stats test failed")
        return false
    end

    -- Check buttons: retry, main menu (PLAN.md requirement)
    if not view_model.buttons or not view_model.buttons.retry or not view_model.buttons.main_menu then
        log_warning("View-model buttons test failed")
        return false
    end

    -- Check localization keys (PLAN.md requirement)
    if not view_model.localization_keys or
       view_model.localization_keys.title ~= "ui.serpent_game_over_title" or
       view_model.localization_keys.retry ~= "ui.serpent_retry" or
       view_model.localization_keys.main_menu ~= "ui.serpent_main_menu" then
        log_warning("View-model localization test failed")
        return false
    end

    log_debug("[GameOverScreen] View-model tests passed")
    return true
end

--- Test game over condition detection
--- @return boolean True if game over detection works correctly
function game_over_screen.test_game_over_detection()
    -- Test with empty snake (game over at length 0)
    local empty_snake = { segments = {} }
    if not game_over_screen.should_show_game_over(empty_snake) then
        log_warning("Empty snake game over test failed")
        return false
    end

    -- Test with nil snake state
    if not game_over_screen.should_show_game_over(nil) then
        log_warning("Nil snake game over test failed")
        return false
    end

    -- Test with living snake
    local living_snake = { segments = { {instance_id = 1}, {instance_id = 2} } }
    if game_over_screen.should_show_game_over(living_snake) then
        log_warning("Living snake game over test failed")
        return false
    end

    log_debug("[GameOverScreen] Game over detection tests passed")
    return true
end

--- Run all game over screen tests
--- @return boolean True if all tests pass
function game_over_screen.run_all_tests()
    local tests = {
        { "view_model_generation", game_over_screen.test_view_model_generation },
        { "game_over_detection", game_over_screen.test_game_over_detection },
    }

    local passed = 0
    local total = #tests

    log_debug("[GameOverScreen] Running " .. total .. " tests...")

    for _, test in ipairs(tests) do
        local test_name, test_func = test[1], test[2]
        local success = test_func()

        if success then
            log_debug("[GameOverScreen] ✓ " .. test_name)
            passed = passed + 1
        else
            log_warning("[GameOverScreen] ✗ " .. test_name)
        end
    end

    log_debug(string.format("[GameOverScreen] Results: %d/%d tests passed", passed, total))
    return passed == total
end

return game_over_screen