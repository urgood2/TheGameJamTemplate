local TestRunner = require("tests.test_runner")
local dsl = require("ui.ui_syntax_sugar")

TestRunner.describe("Sprite UI DSL Tests", function()

    TestRunner.it("dsl.spritePanel creates definition with sprite and borders", function()
        local def = dsl.spritePanel {
            sprite = "panel_bg.png",
            borders = { 8, 8, 8, 8 },
            children = { dsl.text("Hello") }
        }
        
        TestRunner.assert_not_nil(def, "spritePanel should return a definition")
        TestRunner.assert_equals("panel_bg.png", def.config._spriteName, "should store sprite name")
        TestRunner.assert_not_nil(def.config._borders, "should have borders config")
    end)

    TestRunner.it("dsl.spritePanel sizing mode fit_sprite", function()
        local def = dsl.spritePanel {
            sprite = "fixed_size_frame.png",
            sizing = "fit_sprite"
        }
        
        TestRunner.assert_equals("fit_sprite", def.config._sizing, "should have fit_sprite sizing mode")
    end)

    TestRunner.it("dsl.spritePanel sizing mode fit_content (default)", function()
        local def = dsl.spritePanel {
            sprite = "stretchy_panel.png",
            borders = { 8, 8, 8, 8 }
        }
        
        TestRunner.assert_equals("fit_content", def.config._sizing or "fit_content", "should default to fit_content")
    end)

    TestRunner.it("dsl.spritePanel with decorations", function()
        local def = dsl.spritePanel {
            sprite = "base_panel.png",
            decorations = {
                { sprite = "corner_flourish.png", position = "top_left" },
                { sprite = "corner_flourish.png", position = "top_right", flip = "horizontal" }
            }
        }
        
        TestRunner.assert_not_nil(def.config._decorations, "should have decorations")
        TestRunner.assert_equals(2, #def.config._decorations, "should have 2 decorations")
    end)

    TestRunner.it("dsl.spritePanel with region modes", function()
        local def = dsl.spritePanel {
            sprite = "ornate_frame.png",
            regions = {
                corners = { mode = "fixed" },
                edges = { mode = "tile" },
                center = { mode = "stretch" }
            }
        }
        
        TestRunner.assert_not_nil(def.config._regions, "should have region modes")
    end)

    TestRunner.it("dsl.spriteButton creates definition with states", function()
        local def = dsl.spriteButton {
            states = {
                normal = "btn_normal.png",
                hover = "btn_hover.png",
                pressed = "btn_pressed.png",
                disabled = "btn_disabled.png",
            },
            borders = { 4, 4, 4, 4 },
            onClick = function() end,
            children = { dsl.text("Click Me") }
        }
        
        TestRunner.assert_not_nil(def, "spriteButton should return a definition")
        TestRunner.assert_not_nil(def.config._states, "should have state sprites")
        TestRunner.assert_equals("btn_normal.png", def.config._states.normal, "should have normal state")
    end)

    TestRunner.it("dsl.spriteButton auto-suffix shorthand", function()
        local def = dsl.spriteButton {
            sprite = "btn_blue",
            onClick = function() end
        }
        
        TestRunner.assert_not_nil(def, "spriteButton with shorthand should work")
        TestRunner.assert_equals("btn_blue", def.config._baseSprite, "should store base sprite name")
    end)

    TestRunner.it("dsl.customPanel with onDraw hook", function()
        local drawCalled = false
        local def = dsl.customPanel {
            minWidth = 200,
            minHeight = 100,
            onDraw = function(bounds, layer, z)
                drawCalled = true
            end
        }
        
        TestRunner.assert_not_nil(def, "customPanel should return a definition")
        TestRunner.assert_not_nil(def.config._onDraw, "should have onDraw callback")
    end)

    TestRunner.it("decoration with all anchor positions", function()
        local anchors = {
            "top_left", "top_center", "top_right",
            "middle_left", "center", "middle_right",
            "bottom_left", "bottom_center", "bottom_right"
        }
        
        for _, anchor in ipairs(anchors) do
            local def = dsl.spritePanel {
                sprite = "base.png",
                decorations = {
                    { sprite = "decor.png", position = anchor }
                }
            }
            TestRunner.assert_not_nil(def.config._decorations, "should create decorations for anchor: " .. anchor)
        end
    end)

    TestRunner.it("decoration with offset and opacity", function()
        local def = dsl.spritePanel {
            sprite = "base.png",
            decorations = {
                { sprite = "watermark.png", position = "center", offset = {0, -8}, opacity = 0.3 }
            }
        }
        
        local decor = def.config._decorations[1]
        TestRunner.assert_not_nil(decor.offset, "should have offset")
        TestRunner.assert_equals(0.3, decor.opacity, "should have opacity")
    end)

end)

return TestRunner
