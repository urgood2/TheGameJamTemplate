-- assets/scripts/tests/bargain/determinism_static_spec.lua

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local iteration = require("bargain.sim.iteration")

local ROOTS = {
    "assets/scripts/bargain/sim",
}

local UI_ROOT = "assets/scripts/ui"
local UI_GLOB = "bargain_*.lua"

local BANNED_APIS = {
    { pattern = "math%.random", label = "math.random" },
    { pattern = "os%.time", label = "os.time" },
    { pattern = "os%.clock", label = "os.clock" },
    { pattern = "os%.date", label = "os.date" },
    { pattern = "os%.difftime", label = "os.difftime" },
    { pattern = "io%.popen", label = "io.popen" },
}

local ALLOWLIST_PAIRS = {
    ["assets/scripts/bargain/sim/iteration.lua"] = true,
}

local UI_SIM_ALLOWLIST = {
    ["bargain.sim.constants"] = true,
    ["bargain.sim.phase"] = true,
}

local function list_files(root)
    local files = {}
    local cmd = string.format("find %s -type f -name '*.lua'", root)
    local p = io.popen(cmd)
    if not p then return files end
    for line in p:lines() do
        files[#files + 1] = line
    end
    p:close()
    return files
end

local function list_files_with_pattern(root, pattern)
    local files = {}
    local cmd = string.format("find %s -type f -name '%s'", root, pattern)
    local p = io.popen(cmd)
    if not p then return files end
    for line in p:lines() do
        files[#files + 1] = line
    end
    p:close()
    return files
end

local function list_ui_files()
    return list_files_with_pattern(UI_ROOT, UI_GLOB)
end

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return "" end
    local data = f:read("*a")
    f:close()
    return data
end

local function strip_comments(content)
    -- Remove block comments
    content = content:gsub("%-%-%[%[.-%]%]", "")
    -- Remove line comments
    content = content:gsub("%-%-.-\n", "\n")
    return content
end

local function is_allowlisted(path)
    return ALLOWLIST_PAIRS[path] == true
end

local function is_ui_sim_allowlisted(module)
    return UI_SIM_ALLOWLIST[module] == true
end

t.describe("Bargain determinism static checks", function()
    t.it("bans nondeterministic APIs and pairs() in sim scope", function()
        local violations = {}

        for _, root in ipairs(ROOTS) do
            for _, path in ipairs(list_files(root)) do
                local content = strip_comments(read_file(path))
                for _, rule in ipairs(BANNED_APIS) do
                    if content:find(rule.pattern) then
                        violations[#violations + 1] = string.format("%s uses %s", path, rule.label)
                    end
                end

                if content:find("%f[%a]pairs%(") and not is_allowlisted(path) then
                    violations[#violations + 1] = string.format("%s uses pairs()", path)
                end
            end
        end

        t.expect(#violations).to_be(0)
    end)

    t.it("ui_boundary_test", function()
        local violations = {}

        for _, path in ipairs(list_ui_files()) do
            local content = strip_comments(read_file(path))

            for module in content:gmatch("[\"'](bargain%.sim%.[%w_%.]+)[\"']") do
                if not is_ui_sim_allowlisted(module) then
                    violations[#violations + 1] = string.format("%s uses %s", path, module)
                end
            end

            for module in content:gmatch("[\"'](bargain%.sim)[\"']") do
                violations[#violations + 1] = string.format("%s uses %s", path, module)
            end

            for line in content:gmatch("[^\n]+") do
                if line:find("world%.") then
                    local assign = line:find("world%.[%w_%.]+%s*=")
                    local compare = line:find("world%.[%w_%.]+%s*[~<>=]=")
                    if assign and not compare then
                        violations[#violations + 1] = string.format("%s mutates world", path)
                        break
                    end
                end
            end
        end

        t.expect(#violations).to_be(0)
    end)

    t.it("iteration helpers provide deterministic order", function()
        local list = { "a", "b", "c" }
        local collected = {}
        for _, value in iteration.ipairs_ordered(list) do
            collected[#collected + 1] = value
        end
        t.expect(table.concat(collected, ",")).to_be("a,b,c")

        local map = { b = 2, a = 1, c = 3 }
        local keys = {}
        for key, _ in iteration.sorted_pairs(map) do
            keys[#keys + 1] = key
        end
        t.expect(table.concat(keys, ",")).to_be("a,b,c")
    end)
end)
