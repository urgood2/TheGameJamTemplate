-- assets/scripts/tests/test_text_builder.lua
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/tests/?.lua"

local TestRunner = require("test_runner")
local it, assert_equals, assert_not_nil, assert_true =
    TestRunner.it, TestRunner.assert_equals, TestRunner.assert_not_nil, TestRunner.assert_true

-- Mock CommandBufferText for unit tests
local MockCommandBufferText = {}
MockCommandBufferText.__index = MockCommandBufferText
function MockCommandBufferText:init(args)
    self.args = args
    self.updateCount = 0
end
function MockCommandBufferText:update(dt)
    self.updateCount = self.updateCount + 1
end
function MockCommandBufferText:set_text(t) self.args.text = t end
function MockCommandBufferText:rebuild() end

-- Inject mock before requiring Text module
_G._MockCommandBufferText = MockCommandBufferText

TestRunner.describe("Text.define()", function()
    it("returns a Recipe object", function()
        local Text = require("core.text")
        local recipe = Text.define()
        assert_not_nil(recipe, "define() should return a recipe")
        assert_not_nil(recipe._config, "recipe should have _config")
    end)
end)

-- Run tests
TestRunner.run_all()
