---@class SaveManager
---@field private collectors table<string, Collector>
---@field private cache table
---@field private save_in_progress boolean
---@field private pending_save table|nil

local json = require("external.json")

local SaveManager = {
    SAVE_VERSION = 1,
    SAVE_PATH = "saves/profile.json",
    BACKUP_PATH = "saves/profile.json.bak",

    collectors = {},
    cache = {},
    save_in_progress = false,
    pending_save = nil,
}

---@class Collector
---@field collect fun(): table
---@field distribute fun(data: table): nil

--- Register a collector for a save data section
---@param key string The key in the save file
---@param collector Collector The collector with collect/distribute functions
function SaveManager.register(key, collector)
    if not collector.collect or not collector.distribute then
        error("SaveManager.register: collector must have 'collect' and 'distribute' functions")
    end
    SaveManager.collectors[key] = collector
    SPDLOG_DEBUG(string.format("SaveManager: registered collector '%s'", key))
end

--- Collect all data from registered collectors
---@return table
function SaveManager.collect_all()
    local data = {
        version = SaveManager.SAVE_VERSION,
        saved_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }

    for key, collector in pairs(SaveManager.collectors) do
        local success, result = pcall(collector.collect)
        if success then
            data[key] = result
        else
            SPDLOG_WARN(string.format("SaveManager: collector '%s' failed: %s", key, tostring(result)))
        end
    end

    return data
end

--- Distribute loaded data to all registered collectors
---@param data table
function SaveManager.distribute_all(data)
    for key, collector in pairs(SaveManager.collectors) do
        if data[key] then
            local success, err = pcall(collector.distribute, data[key])
            if not success then
                SPDLOG_WARN(string.format("SaveManager: distributor '%s' failed: %s", key, tostring(err)))
            end
        end
    end
    SaveManager.cache = data
end

return SaveManager
