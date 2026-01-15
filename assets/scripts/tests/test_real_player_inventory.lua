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
            print("[Test] Running UIValidator.validate()...")

            -- Run full validation
            local violations = UIValidator.validate(panelEntity)

            -- Also validate each grid tab
            local grids = PlayerInventory.getGrids()
            for tabId, gridEntity in pairs(grids or {}) do
                print("[Test] Validating grid: " .. tostring(tabId))
                local gridViolations = UIValidator.validate(gridEntity)
                for _, v in ipairs(gridViolations) do
                    table.insert(violations, v)
                end
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
