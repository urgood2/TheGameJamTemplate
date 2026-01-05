local TestRunner = require("tests.test_runner")
local dsl = require("ui.ui_syntax_sugar")

TestRunner.describe("Tab UI DSL Tests", function()

    TestRunner.it("dsl.tabs creates valid definition with correct structure", function()
        local def = dsl.tabs{
            id = "test_tabs",
            tabs = {
                { id = "a", label = "Tab A", content = function() return dsl.text("A") end },
                { id = "b", label = "Tab B", content = function() return dsl.text("B") end }
            }
        }
        
        TestRunner.assert_not_nil(def, "tabs should return a definition")
        TestRunner.assert_equals("VERTICAL_CONTAINER", def.type, "root should be vertical container")
        TestRunner.assert_equals("test_tabs", def.config.id, "should have correct ID")
        TestRunner.assert_equals(2, #def.children, "should have tab bar and content area")
    end)

    TestRunner.it("dsl.tabs creates correct number of tab buttons", function()
        local def = dsl.tabs{
            tabs = {
                { id = "a", label = "A", content = function() return dsl.text("A") end },
                { id = "b", label = "B", content = function() return dsl.text("B") end },
                { id = "c", label = "C", content = function() return dsl.text("C") end },
            }
        }
        
        local tabBar = def.children[1]
        TestRunner.assert_equals(3, #tabBar.children, "should have 3 tab buttons")
    end)

    TestRunner.it("dsl.tabs first tab active by default", function()
        local def = dsl.tabs{
            id = "test_default",
            tabs = {
                { id = "first", label = "First", content = function() return dsl.text("F") end },
                { id = "second", label = "Second", content = function() return dsl.text("S") end }
            }
        }
        
        local tabBar = def.children[1]
        local firstBtn = tabBar.children[1]
        local secondBtn = tabBar.children[2]
        
        TestRunner.assert_true(firstBtn.config.chosen, "first button should be chosen")
        TestRunner.assert_true(not secondBtn.config.chosen, "second button should not be chosen")
    end)

    TestRunner.it("dsl.tabs respects activeTab option", function()
        local def = dsl.tabs{
            id = "test_active",
            activeTab = "second",
            tabs = {
                { id = "first", label = "First", content = function() return dsl.text("F") end },
                { id = "second", label = "Second", content = function() return dsl.text("S") end }
            }
        }
        
        local tabBar = def.children[1]
        local firstBtn = tabBar.children[1]
        local secondBtn = tabBar.children[2]
        
        TestRunner.assert_true(not firstBtn.config.chosen, "first button should not be chosen")
        TestRunner.assert_true(secondBtn.config.chosen, "second button should be chosen")
    end)

    TestRunner.it("dsl.tabs handles empty tabs gracefully", function()
        local def = dsl.tabs{ tabs = {} }
        TestRunner.assert_not_nil(def, "should handle empty tabs")
    end)

    TestRunner.it("dsl.tabs handles invalid activeTab by falling back to first", function()
        local def = dsl.tabs{
            activeTab = "nonexistent",
            tabs = {
                { id = "a", label = "A", content = function() return dsl.text("A") end }
            }
        }
        
        local tabBar = def.children[1]
        local firstBtn = tabBar.children[1]
        TestRunner.assert_true(firstBtn.config.chosen, "should fall back to first tab")
    end)

    TestRunner.it("dsl.getActiveTab returns correct tab for registered container", function()
        dsl.tabs{
            id = "active_test_container",
            activeTab = "second",
            tabs = {
                { id = "first", label = "First", content = function() return dsl.text("F") end },
                { id = "second", label = "Second", content = function() return dsl.text("S") end }
            }
        }
        
        local active = dsl.getActiveTab("active_test_container")
        TestRunner.assert_equals("second", active, "should return the active tab ID")
        
        dsl.cleanupTabs("active_test_container")
    end)

    TestRunner.it("dsl.getActiveTab returns nil for unknown container", function()
        local active = dsl.getActiveTab("nonexistent_container_12345")
        TestRunner.assert_nil(active, "should return nil for unknown container")
    end)

    TestRunner.it("dsl.getTabIds returns all tab IDs", function()
        dsl.tabs{
            id = "tabids_test",
            tabs = {
                { id = "x", label = "X", content = function() return dsl.text("X") end },
                { id = "y", label = "Y", content = function() return dsl.text("Y") end },
                { id = "z", label = "Z", content = function() return dsl.text("Z") end }
            }
        }
        
        local ids = dsl.getTabIds("tabids_test")
        TestRunner.assert_not_nil(ids, "should return tab IDs")
        TestRunner.assert_equals(3, #ids, "should have 3 tab IDs")
        TestRunner.assert_equals("x", ids[1], "first ID should be x")
        TestRunner.assert_equals("y", ids[2], "second ID should be y")
        TestRunner.assert_equals("z", ids[3], "third ID should be z")
        
        dsl.cleanupTabs("tabids_test")
    end)

    TestRunner.it("dsl.cleanupTabs removes container from registry", function()
        dsl.tabs{
            id = "cleanup_test",
            tabs = {
                { id = "a", label = "A", content = function() return dsl.text("A") end }
            }
        }
        
        TestRunner.assert_not_nil(dsl.getActiveTab("cleanup_test"), "should exist before cleanup")
        dsl.cleanupTabs("cleanup_test")
        TestRunner.assert_nil(dsl.getActiveTab("cleanup_test"), "should be nil after cleanup")
    end)

    TestRunner.it("dsl.switchTab returns false for unknown container", function()
        local result = dsl.switchTab("nonexistent_container_67890", "a")
        TestRunner.assert_true(not result, "should return false for unknown container")
    end)

end)

return function()
    TestRunner.run_all()
end
