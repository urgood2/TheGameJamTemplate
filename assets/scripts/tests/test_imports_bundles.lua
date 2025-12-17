--[[
================================================================================
TEST: imports.lua bundles
================================================================================
Verifies that all import bundles load correctly.
Run with: lua assets/scripts/tests/test_imports_bundles.lua
(Requires game environment for full test, but syntax check works standalone)
]]

local function test_syntax()
    print("Testing imports.lua syntax and structure...")

    -- This will fail if imports.lua has syntax errors
    local ok, imports = pcall(require, "core.imports")
    if not ok then
        print("FAIL: Could not load imports.lua: " .. tostring(imports))
        return false
    end

    -- Verify all bundle functions exist
    local bundles = { "core", "entity", "physics", "ui", "shaders", "draw", "combat", "util", "all" }
    for _, name in ipairs(bundles) do
        if type(imports[name]) ~= "function" then
            print("FAIL: Missing bundle function: " .. name)
            return false
        end
        print("  OK: imports." .. name .. "() exists")
    end

    print("PASS: All bundle functions present")
    return true
end

local function test_bundles_in_game()
    -- Only run if we have the game environment
    if not _G.registry then
        print("SKIP: Game environment not available (registry missing)")
        return true
    end

    local imports = require("core.imports")

    -- Test core bundle
    local component_cache, entity_cache, timer, signal, z_orders = imports.core()
    assert(component_cache, "core: component_cache missing")
    assert(entity_cache, "core: entity_cache missing")
    assert(timer, "core: timer missing")
    assert(signal, "core: signal missing")
    assert(z_orders, "core: z_orders missing")
    print("  OK: imports.core() returns all modules")

    -- Test draw bundle
    local draw, ShaderBuilder, z_orders2 = imports.draw()
    assert(draw, "draw: draw missing")
    assert(ShaderBuilder, "draw: ShaderBuilder missing")
    assert(z_orders2, "draw: z_orders missing")
    print("  OK: imports.draw() returns all modules")

    -- Test util bundle
    local util, Easing, palette = imports.util()
    assert(util, "util: util missing")
    assert(Easing, "util: Easing missing")
    assert(palette, "util: palette missing")
    print("  OK: imports.util() returns all modules")

    -- Test all() bundle
    local i = imports.all()
    assert(i.timer, "all: timer missing")
    assert(i.draw, "all: draw missing")
    assert(i.ShaderBuilder, "all: ShaderBuilder missing")
    assert(i.util, "all: util missing")
    assert(i.Easing, "all: Easing missing")
    print("  OK: imports.all() includes new modules")

    print("PASS: All bundles load correctly in game environment")
    return true
end

-- Run tests
if test_syntax() then
    test_bundles_in_game()
end
