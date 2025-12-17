-- assets/scripts/tests/test_text_builder.lua
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/tests/?.lua"

local TestRunner = require("test_runner")
local it, assert_equals, assert_not_nil, assert_true =
    TestRunner.it, TestRunner.assert_equals, TestRunner.assert_not_nil, TestRunner.assert_true

-- Mock CommandBufferText for unit tests
local MockCommandBufferText = {}
MockCommandBufferText.__index = MockCommandBufferText

-- Constructor function
function MockCommandBufferText:new(args)
    local obj = {
        args = args,
        updateCount = 0,
        x = args.x,
        y = args.y
    }
    setmetatable(obj, MockCommandBufferText)
    return obj
end

function MockCommandBufferText:update(dt)
    self.updateCount = self.updateCount + 1
end

function MockCommandBufferText:set_text(t)
    self.args.text = t
end

function MockCommandBufferText:rebuild()
end

-- Make it callable
setmetatable(MockCommandBufferText, {
    __call = function(cls, args)
        return cls:new(args)
    end
})

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

TestRunner.describe("Recipe configuration", function()
    it(":content() stores template string", function()
        local Text = require("core.text")
        local recipe = Text.define():content("[%d](color=red)")
        assert_equals("[%d](color=red)", recipe._config.content)
    end)

    it(":content() stores callback function", function()
        local Text = require("core.text")
        local fn = function() return "test" end
        local recipe = Text.define():content(fn)
        assert_equals(fn, recipe._config.content)
    end)

    it(":size() stores font size", function()
        local Text = require("core.text")
        local recipe = Text.define():size(24)
        assert_equals(24, recipe._config.size)
    end)

    it(":color() stores base color", function()
        local Text = require("core.text")
        local recipe = Text.define():color("red")
        assert_equals("red", recipe._config.color)
    end)

    it(":effects() stores default effects", function()
        local Text = require("core.text")
        local recipe = Text.define():effects("shake=2;float")
        assert_equals("shake=2;float", recipe._config.effects)
    end)

    it(":fade() enables fade", function()
        local Text = require("core.text")
        local recipe = Text.define():fade()
        assert_true(recipe._config.fade)
    end)

    it(":lifespan() stores duration", function()
        local Text = require("core.text")
        local recipe = Text.define():lifespan(1.5)
        assert_equals(1.5, recipe._config.lifespanMin)
        assert_equals(1.5, recipe._config.lifespanMax)
    end)

    it(":lifespan() stores range", function()
        local Text = require("core.text")
        local recipe = Text.define():lifespan(0.5, 1.0)
        assert_equals(0.5, recipe._config.lifespanMin)
        assert_equals(1.0, recipe._config.lifespanMax)
    end)

    it(":width() stores wrap width", function()
        local Text = require("core.text")
        local recipe = Text.define():width(200)
        assert_equals(200, recipe._config.width)
    end)

    it(":anchor() stores anchor mode", function()
        local Text = require("core.text")
        local recipe = Text.define():anchor("topleft")
        assert_equals("topleft", recipe._config.anchor)
    end)

    it(":align() stores alignment", function()
        local Text = require("core.text")
        local recipe = Text.define():align("left")
        assert_equals("left", recipe._config.align)
    end)

    it(":layer() stores layer object", function()
        local Text = require("core.text")
        local layer = { name = "ui" }
        local recipe = Text.define():layer(layer)
        assert_equals(layer, recipe._config.layer)
    end)

    it(":z() stores z-index", function()
        local Text = require("core.text")
        local recipe = Text.define():z(10)
        assert_equals(10, recipe._config.z)
    end)

    it(":space() stores render space", function()
        local Text = require("core.text")
        local recipe = Text.define():space("world")
        assert_equals("world", recipe._config.space)
    end)

    it(":font() stores font object", function()
        local Text = require("core.text")
        local font = { name = "custom" }
        local recipe = Text.define():font(font)
        assert_equals(font, recipe._config.font)
    end)

    it(":fadeIn() stores fade-in percentage", function()
        local Text = require("core.text")
        local recipe = Text.define():fadeIn(0.3)
        assert_equals(0.3, recipe._config.fadeInPct)
    end)

    it("methods chain correctly", function()
        local Text = require("core.text")
        local recipe = Text.define()
            :content("test")
            :size(24)
            :color("red")
            :fade()
        assert_equals("test", recipe._config.content)
        assert_equals(24, recipe._config.size)
        assert_equals("red", recipe._config.color)
        assert_true(recipe._config.fade)
    end)
end)

TestRunner.describe("Spawner basics", function()
    it(":spawn() returns a Spawner", function()
        local Text = require("core.text")
        local recipe = Text.define():content("test")
        local spawner = recipe:spawn()
        assert_not_nil(spawner, "spawn() should return spawner")
        assert_not_nil(spawner._recipe, "spawner should reference recipe")
    end)

    it(":spawn(value) stores value for template", function()
        local Text = require("core.text")
        local recipe = Text.define():content("[%d](red)")
        local spawner = recipe:spawn(25)
        assert_equals(25, spawner._value)
    end)

    it(":at() triggers spawn and returns Handle", function()
        local Text = require("core.text")
        local recipe = Text.define():content("test"):width(100)
        local handle = recipe:spawn():at(100, 200)
        assert_not_nil(handle, "at() should return handle")
        assert_true(handle.isActive and handle:isActive(), "handle should be active")
    end)

    it(":at() registers handle in active list", function()
        local Text = require("core.text")
        Text._activeHandles = {}  -- Reset
        local recipe = Text.define():content("test"):width(100)
        recipe:spawn():at(100, 200)
        assert_equals(1, #Text._activeHandles)
    end)
end)

-- Run tests
TestRunner.run_all()
