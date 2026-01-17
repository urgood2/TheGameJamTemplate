--[[
    Capture UI Baselines

    Captures layout baselines for all major UI screens.
    Run before refactoring to establish known-good state.

    Usage:
        require("tests.capture_ui_baselines").captureAll()

    Or via justfile:
        just ui-baseline-capture
]]

local UISnapshot = require("tests._framework.ui_snapshot")

local CaptureBaselines = {}

-- Directory for baseline files (relative to game working directory)
local BASELINE_DIR = "tests/baselines/ui/"

---Ensure baseline directory exists
---@return boolean success
local function ensureDir()
    local ok = os.execute("mkdir -p " .. BASELINE_DIR)
    return ok == 0 or ok == true
end

---Capture a single UI and save it
---@param name string Baseline name
---@param entity number Entity to capture
---@return boolean success
local function captureAndSave(name, entity)
    if not entity then
        print(string.format("[Baseline] Skip %s: no entity", name))
        return false
    end

    if not registry:valid(entity) then
        print(string.format("[Baseline] Skip %s: invalid entity", name))
        return false
    end

    local snapshot = UISnapshot.capture(entity)

    if snapshot.entityCount == 0 then
        print(string.format("[Baseline] Skip %s: empty snapshot", name))
        return false
    end

    local filename = BASELINE_DIR .. name .. "_baseline.json"
    local ok = UISnapshot.save(snapshot, filename)

    if ok then
        print(string.format("[Baseline] Captured %s: %d entities -> %s",
            name, snapshot.entityCount, filename))
    else
        print(string.format("[Baseline] FAILED to save %s", name))
    end

    return ok
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

---Capture all available UI baselines
---@return table results {name = success_bool}
function CaptureBaselines.captureAll()
    ensureDir()

    local results = {}
    local captured = 0
    local skipped = 0

    print("\n[Baseline] Starting baseline capture...")

    -- 1. Player Inventory
    local PlayerInventory = safeRequire("ui.player_inventory")
    if PlayerInventory and PlayerInventory.getPanelEntity then
        local entity = PlayerInventory.getPanelEntity()
        if captureAndSave("inventory", entity) then
            captured = captured + 1
            results.inventory = true
        else
            skipped = skipped + 1
            results.inventory = false
        end
    else
        skipped = skipped + 1
        results.inventory = false
    end

    -- 2. Stats Panel
    local gameplay_cfg = safeRequire("core.gameplay")
    if gameplay_cfg and gameplay_cfg.getStatsPanel then
        local StatsPanel = gameplay_cfg.getStatsPanel()
        if StatsPanel and StatsPanel.getPanelEntity then
            local entity = StatsPanel.getPanelEntity()
            if captureAndSave("stats_panel", entity) then
                captured = captured + 1
                results.stats_panel = true
            else
                skipped = skipped + 1
                results.stats_panel = false
            end
        else
            skipped = skipped + 1
            results.stats_panel = false
        end
    else
        skipped = skipped + 1
        results.stats_panel = false
    end

    -- 3. globals.ui entries
    if globals and globals.ui then
        -- Time display
        if globals.ui.timeTextUIBox then
            if captureAndSave("time_display", globals.ui.timeTextUIBox) then
                captured = captured + 1
                results.time_display = true
            else
                skipped = skipped + 1
            end
        end

        -- Day display
        if globals.ui.dayTextUIBox then
            if captureAndSave("day_display", globals.ui.dayTextUIBox) then
                captured = captured + 1
                results.day_display = true
            else
                skipped = skipped + 1
            end
        end

        -- New day message
        if globals.ui.newDayUIBox then
            if captureAndSave("new_day", globals.ui.newDayUIBox) then
                captured = captured + 1
                results.new_day = true
            else
                skipped = skipped + 1
            end
        end

        -- Tooltip
        if globals.ui.tooltipUIBox then
            if captureAndSave("tooltip", globals.ui.tooltipUIBox) then
                captured = captured + 1
                results.tooltip = true
            else
                skipped = skipped + 1
            end
        end

        -- Help window
        if globals.ui.helpTextUIBox then
            if captureAndSave("help", globals.ui.helpTextUIBox) then
                captured = captured + 1
                results.help = true
            else
                skipped = skipped + 1
            end
        end

        -- Prestige window
        if globals.ui.prestige_uibox then
            if captureAndSave("prestige", globals.ui.prestige_uibox) then
                captured = captured + 1
                results.prestige = true
            else
                skipped = skipped + 1
            end
        end

        -- Achievement notification
        if globals.ui.newAchievementUIBox then
            if captureAndSave("achievement", globals.ui.newAchievementUIBox) then
                captured = captured + 1
                results.achievement = true
            else
                skipped = skipped + 1
            end
        end
    end

    -- 4. Wand loadout UI
    local WandLoadoutUI = safeRequire("ui.wand_loadout_ui")
    if WandLoadoutUI and WandLoadoutUI.getPanelEntity then
        local entity = WandLoadoutUI.getPanelEntity()
        if captureAndSave("wand_loadout", entity) then
            captured = captured + 1
            results.wand_loadout = true
        else
            skipped = skipped + 1
            results.wand_loadout = false
        end
    end

    -- 5. Card inventory panel
    local CardInventoryPanel = safeRequire("ui.card_inventory_panel")
    if CardInventoryPanel and CardInventoryPanel.getPanelEntity then
        local entity = CardInventoryPanel.getPanelEntity()
        if captureAndSave("card_inventory", entity) then
            captured = captured + 1
            results.card_inventory = true
        else
            skipped = skipped + 1
            results.card_inventory = false
        end
    end

    print(string.format("\n[Baseline] Done: %d captured, %d skipped", captured, skipped))

    return results
end

---Capture a specific UI by name
---@param name string UI name (e.g., "inventory", "stats_panel")
---@param entity number Entity to capture
---@return boolean success
function CaptureBaselines.captureOne(name, entity)
    ensureDir()
    return captureAndSave(name, entity)
end

---List available baseline files
---@return string[] filenames
function CaptureBaselines.listBaselines()
    local files = {}
    local handle = io.popen("ls " .. BASELINE_DIR .. "*.json 2>/dev/null")
    if handle then
        for line in handle:lines() do
            table.insert(files, line)
        end
        handle:close()
    end
    return files
end

return CaptureBaselines
