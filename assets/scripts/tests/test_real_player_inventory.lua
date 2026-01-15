--[[
================================================================================
REAL PLAYER INVENTORY VALIDATION TEST
================================================================================
Tests the actual PlayerInventory UI with UIValidator.
Run with: RUN_REAL_INVENTORY_TEST=1 ./build/raylib-cpp-cmake-template

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

function M.run()
    local PlayerInventory = require("ui.player_inventory")

    print("\n================================================================================")
    print("REAL PLAYER INVENTORY VALIDATION")
    print("================================================================================\n")

    local results = { passed = 0, failed = 0, violations = {} }

    -- Open the inventory
    print("[Test] Opening PlayerInventory...")
    PlayerInventory.open()

    -- Wait for UI to settle, then validate
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

            -- Check card z-order if there are any cards in the inventory
            local cardRegistry = PlayerInventory.getCardRegistry and PlayerInventory.getCardRegistry()
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

            if #errors == 0 then
                print("\n[PASS] No validation errors in PlayerInventory!")
                results.passed = 1
            else
                print("\n[FAIL] Found " .. #errors .. " validation errors")
                results.failed = 1
            end

            results.violations = violations

            print("\n================================================================================")
        end,
        tag = "real_inventory_validation"
    })

    return results
end

return M
