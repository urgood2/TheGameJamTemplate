--[[
    Verify UI No Regressions

    Compares current UI layouts against saved baselines to detect regressions.
    Run after each refactoring phase to ensure no unintended changes.

    Usage:
        require("tests.verify_ui_no_regressions").runAll()

    Or via justfile:
        just ui-verify
]]

local UISnapshot = require("tests._framework.ui_snapshot")

local VerifyRegressions = {}

-- Directory for baseline files
local BASELINE_DIR = "tests/baselines/ui/"

---Verify a single UI against its baseline
---@param name string Baseline name
---@param entity number Current entity
---@param tolerance? number Optional tolerance (default 0.5)
---@return boolean passed, table diff
local function verifyOne(name, entity, tolerance)
    local baselineFile = BASELINE_DIR .. name .. "_baseline.json"

    -- Check if baseline exists
    local file = io.open(baselineFile, "r")
    if not file then
        print(string.format("[Verify] SKIP %s: no baseline file", name))
        return true, { skipped = true }
    end
    file:close()

    if not entity then
        print(string.format("[Verify] SKIP %s: no entity available", name))
        return true, { skipped = true }
    end

    if not registry:valid(entity) then
        print(string.format("[Verify] SKIP %s: invalid entity", name))
        return true, { skipped = true }
    end

    return UISnapshot.verify(entity, baselineFile, tolerance)
end

---Get UI module safely
---@param modulePath string
---@return table|nil
local function safeRequire(modulePath)
    local ok, result = pcall(function()
        return require(modulePath)
    end)
    if ok then
        return result
    end
    return nil
end

---Run verification for all available UIs
---@param tolerance? number Optional tolerance (default 0.5)
---@return boolean allPassed, table results
function VerifyRegressions.runAll(tolerance)
    tolerance = tolerance or 0.5

    local results = {}
    local passed = 0
    local failed = 0
    local skipped = 0

    print("\n[Verify] Starting regression verification...")
    print(string.format("[Verify] Tolerance: %.2f pixels", tolerance))

    -- 1. Player Inventory
    local PlayerInventory = safeRequire("ui.player_inventory")
    if PlayerInventory and PlayerInventory.getPanelEntity then
        local entity = PlayerInventory.getPanelEntity()
        local ok, diff = verifyOne("inventory", entity, tolerance)
        results.inventory = { passed = ok, diff = diff }
        if diff.skipped then
            skipped = skipped + 1
        elseif ok then
            passed = passed + 1
            print("[Verify] PASS inventory")
        else
            failed = failed + 1
            print("[Verify] FAIL inventory")
        end
    else
        skipped = skipped + 1
    end

    -- 2. Stats Panel
    local gameplay_cfg = safeRequire("core.gameplay")
    if gameplay_cfg and gameplay_cfg.getStatsPanel then
        local StatsPanel = gameplay_cfg.getStatsPanel()
        if StatsPanel and StatsPanel.getPanelEntity then
            local entity = StatsPanel.getPanelEntity()
            local ok, diff = verifyOne("stats_panel", entity, tolerance)
            results.stats_panel = { passed = ok, diff = diff }
            if diff.skipped then
                skipped = skipped + 1
            elseif ok then
                passed = passed + 1
                print("[Verify] PASS stats_panel")
            else
                failed = failed + 1
                print("[Verify] FAIL stats_panel")
            end
        end
    else
        skipped = skipped + 1
    end

    -- 3. globals.ui entries
    if globals and globals.ui then
        local globalsUIs = {
            { name = "time_display", entity = globals.ui.timeTextUIBox },
            { name = "day_display", entity = globals.ui.dayTextUIBox },
            { name = "new_day", entity = globals.ui.newDayUIBox },
            { name = "tooltip", entity = globals.ui.tooltipUIBox },
            { name = "help", entity = globals.ui.helpTextUIBox },
            { name = "prestige", entity = globals.ui.prestige_uibox },
            { name = "achievement", entity = globals.ui.newAchievementUIBox },
        }

        for _, item in ipairs(globalsUIs) do
            local ok, diff = verifyOne(item.name, item.entity, tolerance)
            results[item.name] = { passed = ok, diff = diff }
            if diff.skipped then
                skipped = skipped + 1
            elseif ok then
                passed = passed + 1
                print("[Verify] PASS " .. item.name)
            else
                failed = failed + 1
                print("[Verify] FAIL " .. item.name)
            end
        end
    end

    -- 4. Wand loadout UI
    local WandLoadoutUI = safeRequire("ui.wand_loadout_ui")
    if WandLoadoutUI and WandLoadoutUI.getPanelEntity then
        local entity = WandLoadoutUI.getPanelEntity()
        local ok, diff = verifyOne("wand_loadout", entity, tolerance)
        results.wand_loadout = { passed = ok, diff = diff }
        if diff.skipped then
            skipped = skipped + 1
        elseif ok then
            passed = passed + 1
            print("[Verify] PASS wand_loadout")
        else
            failed = failed + 1
            print("[Verify] FAIL wand_loadout")
        end
    end

    -- 5. Card inventory panel
    local CardInventoryPanel = safeRequire("ui.card_inventory_panel")
    if CardInventoryPanel and CardInventoryPanel.getPanelEntity then
        local entity = CardInventoryPanel.getPanelEntity()
        local ok, diff = verifyOne("card_inventory", entity, tolerance)
        results.card_inventory = { passed = ok, diff = diff }
        if diff.skipped then
            skipped = skipped + 1
        elseif ok then
            passed = passed + 1
            print("[Verify] PASS card_inventory")
        else
            failed = failed + 1
            print("[Verify] FAIL card_inventory")
        end
    end

    -- Summary
    print(string.format("\n[Verify] SUMMARY: %d passed, %d failed, %d skipped",
        passed, failed, skipped))

    local allPassed = failed == 0

    if not allPassed then
        print("\n[Verify] REGRESSIONS DETECTED - See details above")
    else
        print("\n[Verify] All checks passed!")
    end

    return allPassed, results
end

---Verify a specific UI by name
---@param name string UI name (e.g., "inventory", "stats_panel")
---@param entity number Entity to verify
---@param tolerance? number Optional tolerance (default 0.5)
---@return boolean passed, table diff
function VerifyRegressions.verify(name, entity, tolerance)
    print(string.format("\n[Verify] Checking %s...", name))
    local ok, diff = verifyOne(name, entity, tolerance)
    if diff.skipped then
        print("[Verify] SKIPPED")
    elseif ok then
        print("[Verify] PASS")
    else
        print("[Verify] FAIL")
        UISnapshot.printDiff(diff)
    end
    return ok, diff
end

---Show all available baselines
function VerifyRegressions.listBaselines()
    print("\n[Verify] Available baselines:")
    local handle = io.popen("ls " .. BASELINE_DIR .. "*.json 2>/dev/null")
    if handle then
        for line in handle:lines() do
            local name = line:match("([^/]+)_baseline%.json$")
            if name then
                print("  - " .. name)
            end
        end
        handle:close()
    else
        print("  (none found)")
    end
end

return VerifyRegressions
