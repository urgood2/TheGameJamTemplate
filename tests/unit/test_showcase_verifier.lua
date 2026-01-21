--[[
    Test for showcase_verifier.lua

    This test validates that the ShowcaseVerifier:
    1. Validates all 5 categories (gods_classes, skills, artifacts, wands, status_effects)
    2. Returns proper pass/fail counts per category
    3. Returns item-level validation results
    4. Handles caching properly

    Run standalone: lua tests/unit/test_showcase_verifier.lua
]]

-- Mock globals that would be available in runtime
_G.localization = nil  -- Not needed for raw field tests

local test_showcase_verifier = {}

-- Expected items from design doc (ordered)
local EXPECTED_GODS_CLASSES = { "pyra", "frost", "storm", "void", "warrior", "mage", "rogue" }
local EXPECTED_SKILLS = { "flame_affinity", "pyromaniac", "frost_affinity", "permafrost", "storm_affinity", "chain_mastery", "void_affinity", "void_conduit", "battle_hardened", "swift_casting" }
local EXPECTED_ARTIFACTS = { "ember_heart", "inferno_lens", "frost_core", "glacial_ward", "storm_core", "static_field", "void_heart", "entropy_shard", "battle_trophy", "desperate_power" }
local EXPECTED_WANDS = { "RAGE_FIST", "STORM_WALKER", "FROST_ANCHOR", "SOUL_SIPHON", "PAIN_ECHO", "EMBER_PULSE" }
local EXPECTED_STATUS_EFFECTS = { "arcane_charge", "focused", "fireform", "iceform", "stormform", "voidform" }

-- Test that ShowcaseVerifier module exists and has required API
function test_showcase_verifier.test_module_exists()
    local ok, ShowcaseVerifier = pcall(require, "ui.showcase.showcase_verifier")
    assert(ok, "showcase_verifier module should be requireable: " .. tostring(ShowcaseVerifier))
    assert(type(ShowcaseVerifier) == "table", "showcase_verifier should return a table")
    assert(type(ShowcaseVerifier.runAll) == "function", "ShowcaseVerifier.runAll should be a function")
    assert(type(ShowcaseVerifier.invalidate) == "function", "ShowcaseVerifier.invalidate should be a function")

    print("  runAll is function")
    print("  invalidate is function")
    return true
end

-- Test that runAll returns expected structure
function test_showcase_verifier.test_runall_structure()
    local ShowcaseVerifier = require("ui.showcase.showcase_verifier")
    local results = ShowcaseVerifier.runAll()

    assert(type(results) == "table", "runAll should return a table")
    assert(type(results.categories) == "table", "results should have categories table")

    -- Check all 5 categories exist
    local expected_categories = { "gods_classes", "skills", "artifacts", "wands", "status_effects" }
    for _, cat in ipairs(expected_categories) do
        assert(results.categories[cat], "categories should have " .. cat)
        assert(type(results.categories[cat].pass) == "number", cat .. " should have pass count")
        assert(type(results.categories[cat].total) == "number", cat .. " should have total count")
        assert(type(results.categories[cat].items) == "table", cat .. " should have items table")
        print("  " .. cat .. " structure OK")
    end

    -- Check optional errors field
    if results.errors then
        assert(type(results.errors) == "table", "errors should be a table if present")
    end

    return true
end

-- Test gods & classes validation rules
function test_showcase_verifier.test_gods_classes_validation()
    local ShowcaseVerifier = require("ui.showcase.showcase_verifier")
    ShowcaseVerifier.invalidate()  -- Clear cache
    local results = ShowcaseVerifier.runAll()

    local cat = results.categories.gods_classes

    -- Check expected items exist
    for _, id in ipairs(EXPECTED_GODS_CLASSES) do
        assert(cat.items[id], "gods_classes should include " .. id)
        assert(type(cat.items[id].ok) == "boolean", id .. " should have ok boolean")
    end

    -- All expected items should pass (they exist with valid structure in data)
    assert(cat.pass == cat.total, "All gods/classes should pass validation")
    assert(cat.total >= #EXPECTED_GODS_CLASSES, "Should have at least " .. #EXPECTED_GODS_CLASSES .. " gods/classes")

    print("  gods_classes: " .. cat.pass .. "/" .. cat.total .. " passed")
    return true
end

-- Test skills validation rules
function test_showcase_verifier.test_skills_validation()
    local ShowcaseVerifier = require("ui.showcase.showcase_verifier")
    ShowcaseVerifier.invalidate()
    local results = ShowcaseVerifier.runAll()

    local cat = results.categories.skills

    -- Check expected items exist
    for _, id in ipairs(EXPECTED_SKILLS) do
        assert(cat.items[id], "skills should include " .. id)
        assert(type(cat.items[id].ok) == "boolean", id .. " should have ok boolean")
    end

    -- All expected items should pass
    assert(cat.pass == cat.total, "All skills should pass validation")
    assert(cat.total >= #EXPECTED_SKILLS, "Should have at least " .. #EXPECTED_SKILLS .. " skills")

    print("  skills: " .. cat.pass .. "/" .. cat.total .. " passed")
    return true
end

-- Test artifacts validation rules
function test_showcase_verifier.test_artifacts_validation()
    local ShowcaseVerifier = require("ui.showcase.showcase_verifier")
    ShowcaseVerifier.invalidate()
    local results = ShowcaseVerifier.runAll()

    local cat = results.categories.artifacts

    -- Check expected items exist
    for _, id in ipairs(EXPECTED_ARTIFACTS) do
        assert(cat.items[id], "artifacts should include " .. id)
        assert(type(cat.items[id].ok) == "boolean", id .. " should have ok boolean")
    end

    -- All expected items should pass
    assert(cat.pass == cat.total, "All artifacts should pass validation")
    assert(cat.total >= #EXPECTED_ARTIFACTS, "Should have at least " .. #EXPECTED_ARTIFACTS .. " artifacts")

    print("  artifacts: " .. cat.pass .. "/" .. cat.total .. " passed")
    return true
end

-- Test wands validation rules
function test_showcase_verifier.test_wands_validation()
    local ShowcaseVerifier = require("ui.showcase.showcase_verifier")
    ShowcaseVerifier.invalidate()
    local results = ShowcaseVerifier.runAll()

    local cat = results.categories.wands

    -- Check expected items exist
    for _, id in ipairs(EXPECTED_WANDS) do
        assert(cat.items[id], "wands should include " .. id)
        assert(type(cat.items[id].ok) == "boolean", id .. " should have ok boolean")
    end

    -- All expected items should pass
    assert(cat.pass == cat.total, "All wands should pass validation")
    assert(cat.total >= #EXPECTED_WANDS, "Should have at least " .. #EXPECTED_WANDS .. " wands")

    print("  wands: " .. cat.pass .. "/" .. cat.total .. " passed")
    return true
end

-- Test status effects validation rules
function test_showcase_verifier.test_status_effects_validation()
    local ShowcaseVerifier = require("ui.showcase.showcase_verifier")
    ShowcaseVerifier.invalidate()
    local results = ShowcaseVerifier.runAll()

    local cat = results.categories.status_effects

    -- Check expected items exist
    for _, id in ipairs(EXPECTED_STATUS_EFFECTS) do
        assert(cat.items[id], "status_effects should include " .. id)
        assert(type(cat.items[id].ok) == "boolean", id .. " should have ok boolean")
    end

    -- All expected items should pass
    assert(cat.pass == cat.total, "All status effects should pass validation")
    assert(cat.total >= #EXPECTED_STATUS_EFFECTS, "Should have at least " .. #EXPECTED_STATUS_EFFECTS .. " status effects")

    print("  status_effects: " .. cat.pass .. "/" .. cat.total .. " passed")
    return true
end

-- Test caching behavior
function test_showcase_verifier.test_caching()
    local ShowcaseVerifier = require("ui.showcase.showcase_verifier")
    ShowcaseVerifier.invalidate()

    local results1 = ShowcaseVerifier.runAll()
    local results2 = ShowcaseVerifier.runAll()

    -- Results should be identical (cached)
    assert(results1 == results2, "Cached results should return same reference")

    -- After invalidation, should get new results
    ShowcaseVerifier.invalidate()
    local results3 = ShowcaseVerifier.runAll()
    assert(results1 ~= results3, "After invalidate, should get new results reference")

    print("  caching works correctly")
    return true
end

-- Run all tests
function test_showcase_verifier.run_all()
    print("\n=== Running Showcase Verifier Tests ===\n")

    local tests = {
        { name = "module_exists", fn = test_showcase_verifier.test_module_exists },
        { name = "runall_structure", fn = test_showcase_verifier.test_runall_structure },
        { name = "gods_classes_validation", fn = test_showcase_verifier.test_gods_classes_validation },
        { name = "skills_validation", fn = test_showcase_verifier.test_skills_validation },
        { name = "artifacts_validation", fn = test_showcase_verifier.test_artifacts_validation },
        { name = "wands_validation", fn = test_showcase_verifier.test_wands_validation },
        { name = "status_effects_validation", fn = test_showcase_verifier.test_status_effects_validation },
        { name = "caching", fn = test_showcase_verifier.test_caching },
    }

    local passed = 0
    local failed = 0

    for _, test in ipairs(tests) do
        io.write("Running test_" .. test.name .. "... ")
        local ok, err = pcall(test.fn)
        if ok then
            passed = passed + 1
            print("PASSED")
        else
            failed = failed + 1
            print("FAILED")
            print("  Error: " .. tostring(err))
        end
    end

    print("\n=== Test Results ===")
    print(string.format("Passed: %d", passed))
    print(string.format("Failed: %d", failed))
    print(string.format("Total:  %d\n", passed + failed))

    return failed == 0
end

-- Auto-run if executed directly
if not pcall(debug.getlocal, 4, 1) then
    -- Set up package path to find modules
    local script_dir = debug.getinfo(1, "S").source:match("^@(.+/)")
    if script_dir then
        local base_dir = script_dir:gsub("tests/unit/$", "")
        package.path = base_dir .. "assets/scripts/?.lua;" ..
                       base_dir .. "assets/scripts/?/init.lua;" ..
                       package.path
    end

    local success = test_showcase_verifier.run_all()
    os.exit(success and 0 or 1)
end

return test_showcase_verifier
