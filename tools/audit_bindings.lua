#!/usr/bin/env lua
--[[
Audit script for chugget_code_definitions.lua
Identifies incomplete bindings that need documentation.

Usage: lua tools/audit_bindings.lua [path_to_definitions]

Output:
- Functions missing @param annotations
- Functions with plain-text signatures (not @param format)
- Functions missing @return annotations
- Functions missing descriptions
- Summary by module/class
]]

local definitions_path = arg[1] or "assets/scripts/chugget_code_definitions.lua"

-- Read the file
local file = io.open(definitions_path, "r")
if not file then
    print("ERROR: Could not open " .. definitions_path)
    os.exit(1)
end
local content = file:read("*all")
file:close()

-- Tracking
local issues = {
    missing_param = {},      -- Has (...) but no @param
    plain_text_sig = {},     -- Has plain text signature comment
    missing_return = {},     -- No @return annotation
    missing_desc = {},       -- No description
}

local stats = {
    total_functions = 0,
    complete = 0,
    incomplete = 0,
}

local by_module = {}

-- Parse function by function
-- Pattern: look for function definitions and their preceding comments
local current_class = "global"

for block in content:gmatch("(%-%-%-.-function%s+[%w_%.%:]+%s*%([^)]*%)%s*end)") do
    stats.total_functions = stats.total_functions + 1

    -- Extract function name - find the LAST "function name" pattern in the block
    -- (the actual function definition, not mentions in comments like "function called")
    local func_name = nil
    for fn in block:gmatch("function%s+([%w_%.%:]+)") do
        func_name = fn  -- Keep overwriting to get the last one
    end
    if not func_name then
        func_name = "unknown"
    end

    -- Determine module from function name
    local module = func_name:match("^([%w_]+)[%.%:]") or "global"
    by_module[module] = by_module[module] or { total = 0, incomplete = 0, issues = {} }
    by_module[module].total = by_module[module].total + 1

    local func_issues = {}

    -- Check for @param or @overload or @type annotations (all valid for documenting bindings)
    local has_param = block:match("%-%-%-@param")
    local has_overload = block:match("%-%-%-@overload")
    local has_type = block:match("%-%-%-@type%s+%w")  -- @type for properties (no params needed)
    local has_vararg = block:match("function[^(]*%(%.%.%.%)")

    -- Check for plain-text signature (like "---Registry, number value, number k")
    -- These patterns match old-style parameter docs that start with type names directly after ---
    -- We look for patterns like "---number value" or "---string key" (type followed by identifier)
    -- but NOT prose like "---Returns the number of..." (prose words before the type)
    local plain_sig = block:match("%-%-%-[Rr]egistry%s*,") or           -- "---Registry, ..."
                      block:match("%-%-%-[Rr]egistry%s+%w+") or         -- "---Registry foo"
                      block:match("%-%-%-number%s+%a%w*[,%s]") or        -- "---number value," or "---number value "
                      block:match("%-%-%-string%s+%a%w*[,%s]") or        -- "---string key," etc.
                      block:match("%-%-%-boolean%s+%a%w*[,%s]") or
                      block:match("%-%-%-table%s+%a%w*[,%s]") or
                      block:match("%-%-%-entity%s+%a%w*[,%s]") or
                      block:match("%-%-%-[eE]ntity%s*,") or              -- "---Entity, ..."
                      block:match("%-%-%-[Ee]ntity%s+%a%w*[,%s]")        -- "---Entity foo"

    -- Check for @return (either standalone, inside @overload with :returntype, or @type for properties)
    local has_return = block:match("%-%-%-@return") or
                       block:match("%-%-%-@overload%s+fun%([^)]*%)%s*:%s*%w") or
                       block:match("%-%-%-@type%s+%w")

    -- Check for description (non-annotation comment line)
    local has_desc = block:match("%-%-%-\n%-%-%-[^@]") or block:match("%-%-%-[^@\n][^@\n][^@\n]")

    -- Identify issues
    -- Only flag missing_param if:
    -- 1. Has vararg signature (...) AND
    -- 2. No @param AND no @overload annotations AND
    -- 3. Either has plain-text signature OR lacks @return (indicating incomplete docs)
    -- Functions with @return but no @param are likely legitimate parameterless functions
    -- Functions with @overload are properly documented (overload contains param types inline)
    local likely_parameterless = has_return and not plain_sig
    local has_param_docs = has_param or has_overload or has_type  -- @type means property (no params)

    if has_vararg and not has_param_docs and not likely_parameterless then
        table.insert(func_issues, "missing_param")
        table.insert(issues.missing_param, func_name)
    end

    if plain_sig and not has_param_docs then
        table.insert(func_issues, "plain_text_sig")
        table.insert(issues.plain_text_sig, func_name)
    end

    if not has_return then
        table.insert(func_issues, "missing_return")
        table.insert(issues.missing_return, func_name)
    end

    if not has_desc then
        table.insert(func_issues, "missing_desc")
        table.insert(issues.missing_desc, func_name)
    end

    if #func_issues > 0 then
        stats.incomplete = stats.incomplete + 1
        by_module[module].incomplete = by_module[module].incomplete + 1
        by_module[module].issues[func_name] = func_issues
    else
        stats.complete = stats.complete + 1
    end
end

-- Also catch class definitions
for class_block in content:gmatch("%-%-%-@class%s+([%w_%.]+)") do
    current_class = class_block
end

-- Output results
print("=" .. string.rep("=", 60))
print("BINDING AUDIT REPORT")
print("=" .. string.rep("=", 60))
print()
print(string.format("Total functions: %d", stats.total_functions))
print(string.format("Complete:        %d (%.1f%%)", stats.complete, stats.complete / stats.total_functions * 100))
print(string.format("Incomplete:      %d (%.1f%%)", stats.incomplete, stats.incomplete / stats.total_functions * 100))
print()

print("-" .. string.rep("-", 60))
print("ISSUES BY TYPE")
print("-" .. string.rep("-", 60))
print(string.format("Missing @param:      %d", #issues.missing_param))
print(string.format("Plain-text sig:      %d", #issues.plain_text_sig))
print(string.format("Missing @return:     %d", #issues.missing_return))
print(string.format("Missing description: %d", #issues.missing_desc))
print()

print("-" .. string.rep("-", 60))
print("ISSUES BY MODULE")
print("-" .. string.rep("-", 60))

-- Sort modules by incomplete count
local sorted_modules = {}
for name, data in pairs(by_module) do
    table.insert(sorted_modules, { name = name, data = data })
end
table.sort(sorted_modules, function(a, b) return a.data.incomplete > b.data.incomplete end)

for _, m in ipairs(sorted_modules) do
    if m.data.incomplete > 0 then
        print(string.format("\n[%s] %d/%d incomplete", m.name, m.data.incomplete, m.data.total))
        for func, issues_list in pairs(m.data.issues) do
            print(string.format("  - %s: %s", func, table.concat(issues_list, ", ")))
        end
    end
end

print()
print("-" .. string.rep("-", 60))
print("FUNCTIONS NEEDING WORK (for agent dispatch)")
print("-" .. string.rep("-", 60))

-- Group by module for agent dispatch
for _, m in ipairs(sorted_modules) do
    if m.data.incomplete > 0 then
        local funcs = {}
        for func, _ in pairs(m.data.issues) do
            table.insert(funcs, func)
        end
        table.sort(funcs)
        print(string.format("\n## Module: %s (%d functions)", m.name, #funcs))
        for _, func in ipairs(funcs) do
            print("  " .. func)
        end
    end
end

print()
print("=" .. string.rep("=", 60))
if stats.incomplete == 0 then
    print("SUCCESS: All bindings are complete!")
else
    print(string.format("ACTION NEEDED: %d bindings require documentation", stats.incomplete))
end
print("=" .. string.rep("=", 60))
