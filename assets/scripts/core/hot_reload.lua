--[[
================================================================================
HOT RELOAD - Automatic Lua Module Reloading
================================================================================
Provides utilities for hot-reloading Lua modules during development.
Clears package.loaded cache for modified modules so require() loads fresh code.

IMPORTANT: This is for DEVELOPMENT only. Hot-reload can have side effects
if modules have initialization code or global state.

Usage:
    local hot_reload = require("core.hot_reload")

    -- Reload a single module
    hot_reload.reload("data.cards")

    -- Reload all data modules
    hot_reload.reload_data()

    -- Reload all watched modules (if using file watcher)
    hot_reload.reload_changed()

    -- Clear all module caches (nuclear option)
    hot_reload.clear_all()

    -- Mark a module as "don't reload"
    hot_reload.protect("core.main")
]]

local HotReload = {}

--===========================================================================
-- CONFIGURATION
--===========================================================================

-- Modules that should never be reloaded (core systems with state)
HotReload.protected = {
    ["core.hot_reload"] = true,
    ["core.main"] = true,
    ["core.component_cache"] = true,
    ["core.entity_cache"] = true,
    ["core.timer"] = true,  -- Has active timers
    ["monobehavior.behavior_script_v2"] = true,  -- Has attached scripts
}

-- Pattern matching for module categories
HotReload.patterns = {
    data = "^data%.",
    ui = "^ui%.",
    combat = "^combat%.",
    wand = "^wand%.",
    core = "^core%.",
}

--===========================================================================
-- STATE
--===========================================================================

-- Track reload counts for debugging
HotReload.reload_counts = {}

-- Track last modified times (for file watcher integration)
HotReload.last_modified = {}

--===========================================================================
-- CORE FUNCTIONS
--===========================================================================

--- Check if a module is protected from reloading
--- @param module_path string Module path (e.g., "data.cards")
--- @return boolean
function HotReload.is_protected(module_path)
    return HotReload.protected[module_path] == true
end

--- Protect a module from being reloaded
--- @param module_path string Module path
function HotReload.protect(module_path)
    HotReload.protected[module_path] = true
end

--- Unprotect a module (allow reloading)
--- @param module_path string Module path
function HotReload.unprotect(module_path)
    HotReload.protected[module_path] = nil
end

--- Clear a single module from the cache
--- @param module_path string Module path (e.g., "data.cards")
--- @return boolean success
--- @return string|nil error_message
function HotReload.clear(module_path)
    if HotReload.is_protected(module_path) then
        return false, "Module is protected: " .. module_path
    end

    package.loaded[module_path] = nil
    return true
end

--- Reload a single module (clear cache and require again)
--- @param module_path string Module path (e.g., "data.cards")
--- @return any|nil module The reloaded module or nil on error
--- @return string|nil error_message
function HotReload.reload(module_path)
    if HotReload.is_protected(module_path) then
        return nil, "Module is protected: " .. module_path
    end

    -- Clear from cache
    package.loaded[module_path] = nil

    -- Try to reload
    local ok, result = pcall(require, module_path)
    if ok then
        -- Track reload
        HotReload.reload_counts[module_path] = (HotReload.reload_counts[module_path] or 0) + 1
        -- Use log_info if available, fallback to print
        local log_fn = log_info or print
        log_fn(("[HotReload] Reloaded: %s (count: %d)"):format(
            module_path, HotReload.reload_counts[module_path]))
        return result
    else
        -- Use log_error if available, fallback to print
        local log_fn = log_error or print
        log_fn(("[HotReload] Failed to reload %s: %s"):format(module_path, tostring(result)))
        return nil, tostring(result)
    end
end

--- Clear all modules matching a pattern from cache
--- @param pattern string Lua pattern to match module paths
--- @return number count Number of modules cleared
function HotReload.clear_pattern(pattern)
    local count = 0
    local to_clear = {}

    -- Collect modules to clear (don't modify during iteration)
    for path, _ in pairs(package.loaded) do
        if path:match(pattern) and not HotReload.is_protected(path) then
            table.insert(to_clear, path)
        end
    end

    -- Clear them
    for _, path in ipairs(to_clear) do
        package.loaded[path] = nil
        count = count + 1
    end

    return count
end

--- Reload all modules matching a pattern
--- @param pattern string Lua pattern to match module paths
--- @return number success_count
--- @return number fail_count
function HotReload.reload_pattern(pattern)
    local success_count = 0
    local fail_count = 0
    local to_reload = {}

    -- Collect modules to reload
    for path, _ in pairs(package.loaded) do
        if path:match(pattern) and not HotReload.is_protected(path) then
            table.insert(to_reload, path)
        end
    end

    -- Reload them
    for _, path in ipairs(to_reload) do
        local result, err = HotReload.reload(path)
        if result then
            success_count = success_count + 1
        else
            fail_count = fail_count + 1
        end
    end

    return success_count, fail_count
end

--===========================================================================
-- CONVENIENCE FUNCTIONS
--===========================================================================

--- Reload all data modules (cards, jokers, projectiles, enemies, etc.)
--- @return number success_count
--- @return number fail_count
function HotReload.reload_data()
    log_info("[HotReload] Reloading all data modules...")
    return HotReload.reload_pattern(HotReload.patterns.data)
end

--- Reload all UI modules
--- @return number success_count
--- @return number fail_count
function HotReload.reload_ui()
    log_info("[HotReload] Reloading all UI modules...")
    return HotReload.reload_pattern(HotReload.patterns.ui)
end

--- Reload all combat modules
--- @return number success_count
--- @return number fail_count
function HotReload.reload_combat()
    log_info("[HotReload] Reloading all combat modules...")
    return HotReload.reload_pattern(HotReload.patterns.combat)
end

--- Reload all wand modules
--- @return number success_count
--- @return number fail_count
function HotReload.reload_wand()
    log_info("[HotReload] Reloading all wand modules...")
    return HotReload.reload_pattern(HotReload.patterns.wand)
end

--- Clear ALL module caches (nuclear option - use with caution)
--- Protected modules are still skipped.
--- @return number count Number of modules cleared
function HotReload.clear_all()
    local warn_fn = log_warn or print
    warn_fn("[HotReload] Clearing ALL module caches!")
    local count = 0
    local to_clear = {}

    for path, _ in pairs(package.loaded) do
        if not HotReload.is_protected(path) then
            table.insert(to_clear, path)
        end
    end

    for _, path in ipairs(to_clear) do
        package.loaded[path] = nil
        count = count + 1
    end

    local info_fn = log_info or print
    info_fn(("[HotReload] Cleared %d modules"):format(count))
    return count
end

--===========================================================================
-- DIAGNOSTIC FUNCTIONS
--===========================================================================

--- List all currently loaded modules
--- @param pattern string? Optional pattern to filter
--- @return string[] List of module paths
function HotReload.list_loaded(pattern)
    local modules = {}
    for path, _ in pairs(package.loaded) do
        if not pattern or path:match(pattern) then
            table.insert(modules, path)
        end
    end
    table.sort(modules)
    return modules
end

--- Print reload statistics
function HotReload.print_stats()
    print("=== Hot Reload Statistics ===")
    print("")

    local sorted = {}
    for path, count in pairs(HotReload.reload_counts) do
        table.insert(sorted, { path = path, count = count })
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)

    if #sorted == 0 then
        print("No modules have been reloaded this session.")
    else
        print("Module reload counts:")
        for _, entry in ipairs(sorted) do
            print(string.format("  %3d: %s", entry.count, entry.path))
        end
    end
    print("")

    print("Protected modules:")
    for path, _ in pairs(HotReload.protected) do
        print("  " .. path)
    end
end

--- Get count of loaded modules
--- @return number total
--- @return number protected
function HotReload.get_loaded_count()
    local total = 0
    local protected = 0
    for path, _ in pairs(package.loaded) do
        total = total + 1
        if HotReload.is_protected(path) then
            protected = protected + 1
        end
    end
    return total, protected
end

return HotReload
