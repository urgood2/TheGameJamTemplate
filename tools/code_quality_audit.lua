#!/usr/bin/env lua
--[[
================================================================================
CODE QUALITY AUDIT SCRIPT
================================================================================
This script identifies potential issues in the Lua codebase:
1. registry:get() usages that should use component_cache.get()
2. Timer leaks (infinite timers without cleanup)
3. Global pollution (_G. assignments)

Run with: lua tools/code_quality_audit.lua
================================================================================
]]

-- Fallback file scanning using io.popen
local function get_lua_files(dir)
    local files = {}
    local handle = io.popen('find "' .. dir .. '" -name "*.lua" -type f 2>/dev/null')
    if handle then
        for line in handle:lines() do
            files[#files + 1] = line
        end
        handle:close()
    end
    return files
end

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

local function audit_file(path, content)
    local issues = {
        registry_get = {},
        timer_leaks = {},
        global_assignments = {}
    }

    local lines = {}
    for line in content:gmatch("[^\n]+") do
        lines[#lines + 1] = line
    end

    for line_num, line in ipairs(lines) do
        -- Skip commented lines
        local is_comment = line:match("^%s*%-%-")

        -- Check for registry:get (should use component_cache.get)
        if not is_comment and line:match("registry:get%s*%(") then
            issues.registry_get[#issues.registry_get + 1] = {
                line = line_num,
                code = line:gsub("^%s+", ""):sub(1, 80)
            }
        end

        -- Check for _G. assignments (global pollution)
        if not is_comment and line:match("_G%.%w+%s*=") then
            issues.global_assignments[#issues.global_assignments + 1] = {
                line = line_num,
                code = line:gsub("^%s+", ""):sub(1, 80)
            }
        end
    end

    -- Check for infinite timers (potential leaks) - need context
    local in_timer_call = false
    local timer_start_line = 0
    local timer_code = ""

    for line_num, line in ipairs(lines) do
        if line:match("timer%.every%s*%(") then
            in_timer_call = true
            timer_start_line = line_num
            timer_code = line:gsub("^%s+", "")
        end

        if in_timer_call and line:match("0,%s*%-%-.*infinite") then
            issues.timer_leaks[#issues.timer_leaks + 1] = {
                line = timer_start_line,
                code = timer_code:sub(1, 60),
                type = "infinite_timer"
            }
            in_timer_call = false
        end

        -- Reset after a few lines (timer call finished)
        if in_timer_call and line_num - timer_start_line > 15 then
            in_timer_call = false
        end
    end

    return issues
end

local function shorten_path(path, base)
    return path:gsub(base .. "/", "")
end

local function print_report(all_issues, base_dir)
    print("=" .. string.rep("=", 79))
    print("CODE QUALITY AUDIT REPORT")
    print("=" .. string.rep("=", 79))
    print()

    -- Sort paths for consistent output
    local paths = {}
    for path in pairs(all_issues) do
        paths[#paths + 1] = path
    end
    table.sort(paths)

    -- Registry:get issues
    local registry_total = 0
    print("## 1. registry:get() → component_cache.get() MIGRATION NEEDED")
    print("-" .. string.rep("-", 79))
    print("These should use component_cache.get() for caching and validation:\n")

    for _, path in ipairs(paths) do
        local issues = all_issues[path]
        if #issues.registry_get > 0 then
            registry_total = registry_total + #issues.registry_get
            print(string.format("[%s] (%d)", shorten_path(path, base_dir), #issues.registry_get))
            for _, issue in ipairs(issues.registry_get) do
                print(string.format("  L%d: %s", issue.line, issue.code))
            end
            print()
        end
    end
    print(string.format("TOTAL: %d occurrences need migration", registry_total))
    print()

    -- Timer leaks
    local timer_total = 0
    print("## 2. POTENTIAL TIMER LEAKS (infinite timers)")
    print("-" .. string.rep("-", 79))
    print("Infinite timers (times=0) referencing entities need timer.cancel() on destroy:\n")

    for _, path in ipairs(paths) do
        local issues = all_issues[path]
        if #issues.timer_leaks > 0 then
            timer_total = timer_total + #issues.timer_leaks
            print(string.format("[%s] (%d)", shorten_path(path, base_dir), #issues.timer_leaks))
            for _, issue in ipairs(issues.timer_leaks) do
                print(string.format("  L%d: %s", issue.line, issue.code))
            end
            print()
        end
    end
    print(string.format("TOTAL: %d potential timer leaks", timer_total))
    print()

    -- Global assignments
    local global_total = 0
    print("## 3. GLOBAL ASSIGNMENTS (_G.)")
    print("-" .. string.rep("-", 79))
    print("Consider using module pattern instead of _G. assignments:\n")

    for _, path in ipairs(paths) do
        local issues = all_issues[path]
        if #issues.global_assignments > 0 then
            global_total = global_total + #issues.global_assignments
            print(string.format("[%s] (%d)", shorten_path(path, base_dir), #issues.global_assignments))
            for _, issue in ipairs(issues.global_assignments) do
                print(string.format("  L%d: %s", issue.line, issue.code))
            end
            print()
        end
    end
    print(string.format("TOTAL: %d global assignments", global_total))
    print()

    -- Summary
    print("=" .. string.rep("=", 79))
    print("SUMMARY & RECOMMENDED FIXES")
    print("=" .. string.rep("=", 79))
    print()
    print(string.format("  registry:get → component_cache.get:  %d occurrences", registry_total))
    print(string.format("  Timer leaks (infinite timers):       %d potential issues", timer_total))
    print(string.format("  Global assignments:                  %d occurrences", global_total))
    print()
    print("RECOMMENDED FIXES:")
    print()
    print("1. REGISTRY:GET MIGRATION:")
    print("   Replace: local t = registry:get(entity, Transform)")
    print("   With:    local t = component_cache.get(entity, Transform)")
    print()
    print("2. TIMER LEAKS:")
    print("   For entity-bound infinite timers, add cleanup:")
    print([[
   -- Option A: Use timer_scope (preferred)
   local TimerScope = require("core.timer_scope")
   local scope = TimerScope.for_entity(entity)
   scope:every(0.5, updateFunc)  -- Auto-cancelled on entity destroy

   -- Option B: Manual cleanup
   local tag = "entity_timer_" .. entity
   timer.every(0.5, updateFunc, 0, false, nil, tag)
   -- In destroy/cleanup function:
   timer.cancel(tag)
]])
    print()
    print("3. GLOBAL ASSIGNMENTS:")
    print("   Consider consolidating at end of file or using module pattern:")
    print([[
   -- Instead of scattered _G.foo = foo
   -- At file end:
   return {
       makeSimpleTooltip = makeSimpleTooltip,
       showSimpleTooltipAbove = showSimpleTooltipAbove,
       -- etc
   }
]])
    print()
end

-- Main
local script_path = arg[0] or "tools/code_quality_audit.lua"
local base_dir = script_path:match("(.*/)")
if base_dir then
    base_dir = base_dir .. "../assets/scripts"
else
    base_dir = "assets/scripts"
end

-- Try to normalize the path
local handle = io.popen('cd "' .. base_dir .. '" 2>/dev/null && pwd')
if handle then
    local resolved = handle:read("*l")
    handle:close()
    if resolved then
        base_dir = resolved
    end
end

print("Scanning: " .. base_dir)
local files = get_lua_files(base_dir)
print(string.format("Found %d Lua files\n", #files))

local all_issues = {}
local files_with_issues = 0

for _, path in ipairs(files) do
    local content = read_file(path)
    if content then
        local issues = audit_file(path, content)
        -- Only store if there are issues
        if #issues.registry_get > 0 or #issues.timer_leaks > 0 or #issues.global_assignments > 0 then
            all_issues[path] = issues
            files_with_issues = files_with_issues + 1
        end
    end
end

print_report(all_issues, base_dir)
print(string.format("\nFiles with issues: %d / %d", files_with_issues, #files))
