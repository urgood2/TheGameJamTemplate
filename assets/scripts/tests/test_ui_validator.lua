local TestRunner = require("tests.test_runner")

TestRunner.describe("UIValidator Module", function()

    TestRunner.it("module loads without error", function()
        local UIValidator = require("core.ui_validator")
        TestRunner.assert_not_nil(UIValidator, "UIValidator module should load")
    end)

    TestRunner.it("has enable/disable API", function()
        local UIValidator = require("core.ui_validator")
        TestRunner.assert_not_nil(UIValidator.enable, "should have enable function")
        TestRunner.assert_not_nil(UIValidator.disable, "should have disable function")
        TestRunner.assert_not_nil(UIValidator.isEnabled, "should have isEnabled function")
    end)

    TestRunner.it("has validate API", function()
        local UIValidator = require("core.ui_validator")
        TestRunner.assert_not_nil(UIValidator.validate, "should have validate function")
    end)

end)
