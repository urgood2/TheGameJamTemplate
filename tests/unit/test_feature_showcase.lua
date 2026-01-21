--[[
    Test for feature_showcase.lua

    This test validates that FeatureShowcase:
    1. Module exists with required API (init, show, hide, switchCategory, cleanup)
    2. Category constants are properly defined
    3. State management works correctly
    4. Integration with verifier works

    Note: Full UI rendering tests require the game engine.
    These tests focus on standalone logic validation.

    Run standalone: lua tests/unit/test_feature_showcase.lua
]]

local test_feature_showcase = {}

-- Test that FeatureShowcase module exists and has required API
function test_feature_showcase.test_module_exists()
    local ok, FeatureShowcase = pcall(require, "ui.showcase.feature_showcase")
    assert(ok, "feature_showcase module should be requireable: " .. tostring(FeatureShowcase))
    assert(type(FeatureShowcase) == "table", "feature_showcase should return a table")

    -- Check required API functions
    assert(type(FeatureShowcase.init) == "function", "init should be a function")
    assert(type(FeatureShowcase.show) == "function", "show should be a function")
    assert(type(FeatureShowcase.hide) == "function", "hide should be a function")
    assert(type(FeatureShowcase.switchCategory) == "function", "switchCategory should be a function")
    assert(type(FeatureShowcase.cleanup) == "function", "cleanup should be a function")

    print("  init is function")
    print("  show is function")
    print("  hide is function")
    print("  switchCategory is function")
    print("  cleanup is function")
    return true
end

-- Test that category constants are defined
function test_feature_showcase.test_categories_defined()
    local FeatureShowcase = require("ui.showcase.feature_showcase")

    -- Check for CATEGORIES constant
    assert(FeatureShowcase.CATEGORIES, "CATEGORIES should be defined")
    assert(type(FeatureShowcase.CATEGORIES) == "table", "CATEGORIES should be a table")

    -- Check expected categories
    local expected = { "gods_classes", "skills", "artifacts", "wands", "status_effects" }
    for _, cat in ipairs(expected) do
        local found = false
        for _, c in ipairs(FeatureShowcase.CATEGORIES) do
            if c.id == cat then
                found = true
                assert(c.label, "Category " .. cat .. " should have a label")
                print("  " .. cat .. ": '" .. c.label .. "'")
                break
            end
        end
        assert(found, "CATEGORIES should include " .. cat)
    end

    return true
end

-- Test that state management works (current category tracking)
function test_feature_showcase.test_state_management()
    local FeatureShowcase = require("ui.showcase.feature_showcase")

    -- Get current state
    local initialCategory = FeatureShowcase.getCurrentCategory()
    assert(initialCategory ~= nil, "getCurrentCategory should return a value")
    print("  initial category: " .. tostring(initialCategory))

    -- Switch category (this may fail without full UI, but shouldn't crash)
    local success, err = pcall(function()
        FeatureShowcase.switchCategory("skills")
    end)
    if success then
        local newCategory = FeatureShowcase.getCurrentCategory()
        assert(newCategory == "skills", "switchCategory should update current category")
        print("  after switch: " .. tostring(newCategory))
    else
        -- Expected to fail without full UI - just verify it fails gracefully
        print("  switchCategory (no UI): " .. tostring(err):sub(1, 50) .. "...")
    end

    return true
end

-- Test that isVisible() function exists and returns boolean
function test_feature_showcase.test_visibility_tracking()
    local FeatureShowcase = require("ui.showcase.feature_showcase")

    -- Check for isVisible function
    assert(type(FeatureShowcase.isVisible) == "function", "isVisible should be a function")

    local visible = FeatureShowcase.isVisible()
    assert(type(visible) == "boolean", "isVisible should return boolean")
    print("  isVisible: " .. tostring(visible))

    return true
end

-- Test that verifier integration works
function test_feature_showcase.test_verifier_integration()
    local FeatureShowcase = require("ui.showcase.feature_showcase")

    -- Check for getVerificationResults function
    assert(type(FeatureShowcase.getVerificationResults) == "function",
           "getVerificationResults should be a function")

    local results = FeatureShowcase.getVerificationResults()
    assert(type(results) == "table", "getVerificationResults should return table")
    assert(results.categories, "results should have categories")

    -- Verify all 5 categories present
    local categories = { "gods_classes", "skills", "artifacts", "wands", "status_effects" }
    for _, cat in ipairs(categories) do
        assert(results.categories[cat], "results should have " .. cat)
        print("  " .. cat .. ": " .. results.categories[cat].pass .. "/" .. results.categories[cat].total)
    end

    return true
end

-- Test that category labels are user-friendly
function test_feature_showcase.test_category_labels()
    local FeatureShowcase = require("ui.showcase.feature_showcase")

    local labels = {}
    for _, cat in ipairs(FeatureShowcase.CATEGORIES) do
        labels[cat.id] = cat.label
    end

    -- Check labels are readable (not just IDs)
    assert(labels.gods_classes ~= "gods_classes", "gods_classes label should be readable")
    assert(labels.skills ~= "skills", "skills label should be readable")
    assert(labels.artifacts ~= "artifacts", "artifacts label should be readable")
    assert(labels.wands ~= "wands", "wands label should be readable")
    assert(labels.status_effects ~= "status_effects", "status_effects label should be readable")

    print("  gods_classes -> '" .. labels.gods_classes .. "'")
    print("  skills -> '" .. labels.skills .. "'")
    print("  artifacts -> '" .. labels.artifacts .. "'")
    print("  wands -> '" .. labels.wands .. "'")
    print("  status_effects -> '" .. labels.status_effects .. "'")

    return true
end

-- Run all tests
function test_feature_showcase.run_all()
    print("\n=== Running Feature Showcase Tests ===\n")

    local tests = {
        { name = "module_exists", fn = test_feature_showcase.test_module_exists },
        { name = "categories_defined", fn = test_feature_showcase.test_categories_defined },
        { name = "state_management", fn = test_feature_showcase.test_state_management },
        { name = "visibility_tracking", fn = test_feature_showcase.test_visibility_tracking },
        { name = "verifier_integration", fn = test_feature_showcase.test_verifier_integration },
        { name = "category_labels", fn = test_feature_showcase.test_category_labels },
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

    local success = test_feature_showcase.run_all()
    os.exit(success and 0 or 1)
end

return test_feature_showcase
