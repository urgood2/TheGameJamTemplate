--[[
================================================================================
REAL PLAYER INVENTORY VALIDATION TEST
================================================================================
Tests the actual PlayerInventory UI with UIValidator.
Run with: AUTO_START_MAIN_GAME=1 RUN_REAL_INVENTORY_TEST=1 ./build/raylib-cpp-cmake-template

NOTE: Must use AUTO_START_MAIN_GAME=1 because PlayerInventory only exists
during the IN_GAME state (planning phase), not in MAIN_MENU.

This test validates:
- Panel containment (children stay within bounds)
- Window bounds (panel stays on screen)
- Z-order hierarchy (children above parent)
- Grid slot arrangement
================================================================================
]]

local M = {}

local UIValidator = require("core.ui_validator")
local timer = require("core.timer")
local signal = require("external.hump.signal")

-- Track if we've already scheduled the test
local testScheduled = false

function M.run()
    print("\n================================================================================")
    print("REAL PLAYER INVENTORY VALIDATION")
    print("================================================================================\n")

    -- Check if we're in the right game state
    local currentState = globals.currentGameState
    if currentState == GAMESTATE.IN_GAME then
        -- Already in game, run immediately
        print("[Test] Already in IN_GAME state, running validation...")
        M.runValidation()
    else
        -- Schedule to run when game enters IN_GAME state
        print("[Test] Not in IN_GAME yet (current: " .. tostring(currentState) .. ")")
        print("[Test] Scheduling validation after game state changes...")
        print("[Test] HINT: Use AUTO_START_MAIN_GAME=1 to auto-start the game")
        M.scheduleAfterGameStart()
    end
end

function M.scheduleAfterGameStart()
    if testScheduled then
        print("[Test] Test already scheduled, skipping...")
        return
    end
    testScheduled = true

    -- Wait for game to start, then run validation
    -- Check every 0.5 seconds for up to 10 seconds
    local checkCount = 0
    local maxChecks = 20
    local validationTriggered = false

    timer.every_opts({
        delay = 0.5,
        action = function()
            -- Skip if validation already triggered
            if validationTriggered then
                return false -- Stop the timer
            end

            checkCount = checkCount + 1

            if globals.currentGameState == GAMESTATE.IN_GAME then
                validationTriggered = true
                print("[Test] Game entered IN_GAME state! Running validation in 1.5s...")

                -- Wait for UI to fully initialize
                timer.after_opts({
                    delay = 1.5,
                    action = function()
                        M.runValidation()
                    end,
                    tag = "inventory_test_run"
                })
                return false -- Stop the repeating timer
            elseif checkCount >= maxChecks then
                print("[Test] Timeout waiting for IN_GAME state")
                print("[Test] Use AUTO_START_MAIN_GAME=1 to automatically start the game")
                return false -- Stop the timer
            end
        end,
        tag = "inventory_test_wait_for_game"
    })
end

-- Create a simple test card entity
local function createTestCard(x, y, cardData)
    if not animation_system or not animation_system.createAnimatedObjectWithTransform then
        print("[Test] WARNING: animation_system not available, cannot create test card")
        return nil
    end

    local entity = animation_system.createAnimatedObjectWithTransform(
        "card-new-test-action.png", true, x or 0, y or 0, nil, true
    )

    if not entity or not registry:valid(entity) then
        print("[Test] WARNING: Failed to create test card entity")
        return nil
    end

    animation_system.resizeAnimationObjectsInEntityToFit(entity, 60, 84)

    -- Set z-order (should be above grid at z=850)
    if layer_order_system and layer_order_system.assignZIndexToEntity then
        local z = (z_orders and z_orders.ui_tooltips or 900) + 100  -- 1000
        layer_order_system.assignZIndexToEntity(entity, z)
        print("[Test] Card z-order set to: " .. z)
    end

    -- Screen-space collision
    if transform and transform.set_space then
        transform.set_space(entity, "screen")
    end

    -- Add shader pipeline for rendering
    if shader_pipeline and shader_pipeline.ShaderPipelineComponent then
        local shaderComp = registry:emplace(entity, shader_pipeline.ShaderPipelineComponent)
        shaderComp:addPass("3d_skew")
    end

    return entity
end

function M.runValidation()
    local PlayerInventory = require("ui.player_inventory")
    local results = { passed = 0, failed = 0, violations = {} }
    local testCards = {}

    -- Open the inventory
    print("[Test] Opening PlayerInventory...")
    PlayerInventory.open()

    -- Wait for UI to settle, then add test cards and validate
    timer.after_opts({
        delay = 0.5,
        action = function()
            local panelEntity = PlayerInventory.getPanelEntity()

            if not panelEntity then
                print("[FAIL] Could not get panel entity")
                results.failed = results.failed + 1
                return
            end

            print("[Test] Panel entity: " .. tostring(panelEntity))

            -- Create and add test cards to verify z-order
            print("[Test] Creating test cards...")
            local testCard1 = createTestCard(100, 100, { id = "test_card_1" })
            local testCard2 = createTestCard(200, 100, { id = "test_card_2" })

            if testCard1 then
                local added = PlayerInventory.addCard(testCard1, "equipment", { id = "test_card_1" })
                print("[Test] Added test card 1 to equipment: " .. tostring(added))
                table.insert(testCards, testCard1)
            end
            if testCard2 then
                local added = PlayerInventory.addCard(testCard2, "equipment", { id = "test_card_2" })
                print("[Test] Added test card 2 to equipment: " .. tostring(added))
                table.insert(testCards, testCard2)
            end

            print("[Test] Running UIValidator.validate() with skipHidden=true...")

            -- Run full validation with skipHidden to ignore off-screen tabs
            local options = { skipHidden = true }
            local violations = UIValidator.validate(panelEntity, nil, options)

            -- Collect grid entities for cross-hierarchy check
            local grids = PlayerInventory.getGrids()
            local activeGridEntity = nil

            -- Validate each grid tab individually
            for tabId, gridEntity in pairs(grids or {}) do
                print("[Test] Validating grid: " .. tostring(tabId))
                local gridViolations = UIValidator.validate(gridEntity, nil, options)
                for _, v in ipairs(gridViolations) do
                    table.insert(violations, v)
                end

                -- Track active grid for cross-hierarchy check
                if tabId == "equipment" then -- Default active tab
                    activeGridEntity = gridEntity
                end
            end

            -- Check for cross-hierarchy overlaps between panel and active grid
            if activeGridEntity then
                print("[Test] Checking global overlap between panel and active grid...")
                local globalViolations = UIValidator.checkGlobalOverlap(
                    { panelEntity, activeGridEntity },
                    options
                )
                for _, v in ipairs(globalViolations) do
                    table.insert(violations, v)
                end
                print("[Test] Global overlap violations: " .. #globalViolations)
            end

            -- Check card z-order - cards should render ABOVE the grid
            local cardRegistry = PlayerInventory.getCardRegistry and PlayerInventory.getCardRegistry()
            local cardCount = 0
            if cardRegistry then
                for _ in pairs(cardRegistry) do cardCount = cardCount + 1 end
            end
            print("[Test] Cards in registry: " .. cardCount)

            if cardRegistry and next(cardRegistry) and activeGridEntity then
                print("[Test] Checking card z-order occlusion...")
                local cardPairs = {}
                for cardEntity, _ in pairs(cardRegistry) do
                    if cardEntity and registry:valid(cardEntity) then
                        -- Cards should render ABOVE the grid
                        table.insert(cardPairs, { front = cardEntity, behind = activeGridEntity })
                    end
                end
                local occlusionViolations = UIValidator.checkZOrderOcclusion(cardPairs, options)
                for _, v in ipairs(occlusionViolations) do
                    table.insert(violations, v)
                end
                print("[Test] Z-order occlusion violations: " .. #occlusionViolations)
            end

            -- Report results
            local errors = UIValidator.getErrors(violations)
            local warnings = UIValidator.getWarnings(violations)

            print("\n=== VALIDATION RESULTS ===")
            print("Total violations: " .. #violations)
            print("  Errors: " .. #errors)
            print("  Warnings: " .. #warnings)

            if #violations > 0 then
                print("\nViolations:")
                for i, v in ipairs(violations) do
                    print(string.format("  [%s] %s: %s",
                        v.severity or "?",
                        v.type or "unknown",
                        v.message or "no message"))
                    if i >= 20 then
                        print("  ... and " .. (#violations - 20) .. " more")
                        break
                    end
                end
            end

            -- STRICT: Fail on ANY violations (errors OR warnings)
            -- This ensures layout issues are caught, not just critical errors
            local hasViolations = #violations > 0

            if not hasViolations then
                print("\n[PASS] No validation violations in PlayerInventory!")
                results.passed = 1
            else
                print("\n[FAIL] Found " .. #violations .. " validation violations (" .. #errors .. " errors, " .. #warnings .. " warnings)")
                results.failed = 1
            end

            results.violations = violations

            -- Cleanup test cards
            for _, cardEntity in ipairs(testCards) do
                if cardEntity and registry:valid(cardEntity) then
                    PlayerInventory.removeCard(cardEntity)
                    registry:destroy(cardEntity)
                end
            end

            print("\n================================================================================")

            -- Auto-exit after test completion if AUTO_EXIT_AFTER_TEST is set
            local autoExit = os.getenv("AUTO_EXIT_AFTER_TEST") == "1"
            if autoExit then
                print("[Test] AUTO_EXIT_AFTER_TEST=1, exiting in 0.5s...")
                timer.after_opts({
                    delay = 0.5,
                    action = function()
                        print("[Test] Exiting with code: " .. (hasViolations and "1 (failure)" or "0 (success)"))
                        os.exit(hasViolations and 1 or 0)
                    end,
                    tag = "test_auto_exit"
                })
            end
        end,
        tag = "real_inventory_validation"
    })

    return results
end

return M
