--[[
================================================================================
TEST: Primitive Showcases (US-012)
================================================================================
Validates that primitive UI component showcases meet acceptance criteria:
- [x] Showcase for text with various sizes, colors, alignments
- [x] Showcase for image with sizing and tinting
- [x] Showcase for anim with different frame rates
- [x] Showcase for spacer usage in layouts
- [x] Each showcase includes prop documentation comments

Run standalone: lua assets/scripts/tests/test_primitive_showcases.lua
================================================================================
]]

-- Setup package path for standalone execution
package.path = package.path .. ";./assets/scripts/?.lua"

-- Load mocks first if running standalone
local standalone = not _G.registry
if standalone then
    local ok, err = pcall(require, "tests.mocks.engine_mock")
    if not ok then
        print("Note: Running without engine mocks: " .. tostring(err))
    end
end

-- Mock engine globals
_G.AlignmentFlag = _G.AlignmentFlag or {
    HORIZONTAL_CENTER = 1,
    VERTICAL_CENTER = 2,
    HORIZONTAL_LEFT = 4,
    HORIZONTAL_RIGHT = 8,
    VERTICAL_TOP = 16,
    VERTICAL_BOTTOM = 32,
}
_G.bit = _G.bit or {
    bor = function(a, b) return (a or 0) + (b or 0) end,
    band = function(a, b) return math.min(a or 0, b or 0) end,
}
_G.Color = _G.Color or { new = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
_G.util = _G.util or { getColor = function(c) return c end }
_G.ui = _G.ui or {
    definitions = {
        def = function(t) return t end,
        wrapEntityInsideObjectElement = function(e) return e end,
        getNewDynamicTextEntry = function(fn, sz, eff) return { config = {} } end,
        getTextFromString = function(txt, opts) return { type = "TEXT", config = opts } end,
    },
    box = {}
}
_G.animation_system = _G.animation_system or {
    createAnimatedObjectWithTransform = function() return {} end,
    resizeAnimationObjectsInEntityToFit = function() end,
    setFGColorForAllAnimationObjects = function() end,
    setSpeed = function() end,
    play = function() end,
    pause = function() end,
    stop = function() end,
}

-- Load test runner
local t = require("tests.test_runner")

-- Load showcase registry
local registry_ok, ShowcaseRegistry = pcall(require, "ui.showcase.showcase_registry")
if not registry_ok then
    print("FATAL: Could not load ShowcaseRegistry: " .. tostring(ShowcaseRegistry))
    os.exit(1)
end

--------------------------------------------------------------------------------
-- Acceptance Criteria Tests
--------------------------------------------------------------------------------

t.describe("US-012: Primitive Showcases", function()
    local primitives = ShowcaseRegistry._showcases.primitives

    t.describe("Showcase for text with various sizes, colors, alignments", function()
        t.it("has text_sizes showcase", function()
            t.expect(primitives.text_sizes).to_be_truthy()
            t.expect(primitives.text_sizes.name).to_be("Text Sizes")
        end)

        t.it("text_sizes demonstrates multiple font sizes", function()
            local source = primitives.text_sizes.source
            t.expect(source:find("fontSize = 12")).to_be_truthy()
            t.expect(source:find("fontSize = 16")).to_be_truthy()
            t.expect(source:find("fontSize = 20")).to_be_truthy()
            t.expect(source:find("fontSize = 24")).to_be_truthy()
            t.expect(source:find("fontSize = 32")).to_be_truthy()
        end)

        t.it("has text_colors showcase", function()
            t.expect(primitives.text_colors).to_be_truthy()
            t.expect(primitives.text_colors.name).to_be("Text Colors")
        end)

        t.it("text_colors demonstrates named colors", function()
            local source = primitives.text_colors.source
            t.expect(source:find('color = "white"')).to_be_truthy()
            t.expect(source:find('color = "gold"')).to_be_truthy()
            t.expect(source:find('color = "red"')).to_be_truthy()
            t.expect(source:find('color = "green"')).to_be_truthy()
            t.expect(source:find('color = "cyan"')).to_be_truthy()
        end)

        t.it("has text_alignments showcase", function()
            t.expect(primitives.text_alignments).to_be_truthy()
            t.expect(primitives.text_alignments.name).to_be("Text Alignments")
        end)

        t.it("text_alignments demonstrates alignment options", function()
            local source = primitives.text_alignments.source
            t.expect(source:find("HORIZONTAL_LEFT")).to_be_truthy()
            t.expect(source:find("HORIZONTAL_CENTER")).to_be_truthy()
            t.expect(source:find("HORIZONTAL_RIGHT")).to_be_truthy()
        end)

        t.it("all text showcases have create functions", function()
            t.expect(type(primitives.text_basic.create)).to_be("function")
            t.expect(type(primitives.text_sizes.create)).to_be("function")
            t.expect(type(primitives.text_colors.create)).to_be("function")
            t.expect(type(primitives.text_alignments.create)).to_be("function")
            t.expect(type(primitives.text_styled.create)).to_be("function")
        end)
    end)

    t.describe("Showcase for image with sizing and tinting", function()
        t.it("has image_basic showcase", function()
            t.expect(primitives.image_basic).to_be_truthy()
            t.expect(primitives.image_basic.name).to_be("Image (Basic)")
        end)

        t.it("has image_sizing showcase", function()
            t.expect(primitives.image_sizing).to_be_truthy()
            t.expect(primitives.image_sizing.name).to_be("Image Sizing")
        end)

        t.it("image_sizing demonstrates different dimensions", function()
            local source = primitives.image_sizing.source
            t.expect(source:find("w = 24")).to_be_truthy()
            t.expect(source:find("w = 48")).to_be_truthy()
            t.expect(source:find("w = 72")).to_be_truthy()
        end)

        t.it("has image_tinting showcase", function()
            t.expect(primitives.image_tinting).to_be_truthy()
            t.expect(primitives.image_tinting.name).to_be("Image Tinting")
        end)

        t.it("image_tinting documents animation_system tinting API", function()
            local source = primitives.image_tinting.source
            t.expect(source:find("setFGColorForAllAnimationObjects")).to_be_truthy()
        end)

        t.it("all image showcases have create functions", function()
            t.expect(type(primitives.image_basic.create)).to_be("function")
            t.expect(type(primitives.image_sizing.create)).to_be("function")
            t.expect(type(primitives.image_tinting.create)).to_be("function")
        end)
    end)

    t.describe("Showcase for anim with different frame rates", function()
        t.it("has anim_basic showcase", function()
            t.expect(primitives.anim_basic).to_be_truthy()
            t.expect(primitives.anim_basic.name).to_be("Animation (Basic)")
        end)

        t.it("anim_basic explains isAnimation flag", function()
            local source = primitives.anim_basic.source
            t.expect(source:find("isAnimation")).to_be_truthy()
        end)

        t.it("has anim_speed showcase", function()
            t.expect(primitives.anim_speed).to_be_truthy()
            t.expect(primitives.anim_speed.name).to_be("Animation Speed")
        end)

        t.it("anim_speed documents animation_system speed API", function()
            local source = primitives.anim_speed.source
            t.expect(source:find("setSpeed")).to_be_truthy()
            t.expect(source:find("0.5")).to_be_truthy()  -- slow speed example
            t.expect(source:find("1.0")).to_be_truthy()  -- normal speed
            t.expect(source:find("2.0")).to_be_truthy()  -- fast speed
        end)

        t.it("anim_speed documents additional animation controls", function()
            local source = primitives.anim_speed.source
            t.expect(source:find("play")).to_be_truthy()
            t.expect(source:find("pause")).to_be_truthy()
            t.expect(source:find("stop")).to_be_truthy()
            t.expect(source:find("seekFrame")).to_be_truthy()
            t.expect(source:find("setDirection")).to_be_truthy()
        end)

        t.it("all anim showcases have create functions", function()
            t.expect(type(primitives.anim_basic.create)).to_be("function")
            t.expect(type(primitives.anim_speed.create)).to_be("function")
        end)
    end)

    t.describe("Showcase for spacer usage in layouts", function()
        t.it("has spacer_horizontal showcase", function()
            t.expect(primitives.spacer_horizontal).to_be_truthy()
            t.expect(primitives.spacer_horizontal.name).to_be("Spacer (Horizontal)")
        end)

        t.it("spacer_horizontal demonstrates horizontal gaps", function()
            local source = primitives.spacer_horizontal.source
            t.expect(source:find("hbox")).to_be_truthy()
            t.expect(source:find("spacer%(40%)")).to_be_truthy()
        end)

        t.it("has spacer_vertical showcase", function()
            t.expect(primitives.spacer_vertical).to_be_truthy()
            t.expect(primitives.spacer_vertical.name).to_be("Spacer (Vertical)")
        end)

        t.it("spacer_vertical demonstrates vertical gaps", function()
            local source = primitives.spacer_vertical.source
            t.expect(source:find("vbox")).to_be_truthy()
            t.expect(source:find("spacer%(10, 40%)")).to_be_truthy()
        end)

        t.it("has spacer_combined showcase for complex layouts", function()
            t.expect(primitives.spacer_combined).to_be_truthy()
            t.expect(primitives.spacer_combined.name).to_be("Spacer (Layout Control)")
        end)

        t.it("spacer_combined shows real-world usage patterns", function()
            local source = primitives.spacer_combined.source
            t.expect(source:find("Header")).to_be_truthy()
            t.expect(source:find("Footer")).to_be_truthy()
            -- Shows multiple spacer usages
            local count = 0
            for _ in source:gmatch("dsl%.spacer") do count = count + 1 end
            t.expect(count >= 3).to_be(true)
        end)

        t.it("all spacer showcases have create functions", function()
            t.expect(type(primitives.spacer_horizontal.create)).to_be("function")
            t.expect(type(primitives.spacer_vertical.create)).to_be("function")
            t.expect(type(primitives.spacer_combined.create)).to_be("function")
        end)
    end)

    t.describe("Each showcase includes prop documentation comments", function()
        t.it("primitives category has module-level prop documentation", function()
            -- Read the file and check for documentation header
            local f = io.open("assets/scripts/ui/showcase/showcase_registry.lua", "r")
            local content = f:read("*all")
            f:close()

            -- Check for TEXT PROPS documentation
            t.expect(content:find("TEXT PROPS:")).to_be_truthy()
            t.expect(content:find("fontSize%s+%- %(number%)")).to_be_truthy()
            t.expect(content:find("color%s+%- %(string|Color%)")).to_be_truthy()
            t.expect(content:find("align%s+%- %(number%)")).to_be_truthy()
            t.expect(content:find("shadow%s+%- %(bool%)")).to_be_truthy()

            -- Check for ANIM/IMAGE PROPS documentation
            t.expect(content:find("ANIM/IMAGE PROPS:")).to_be_truthy()
            t.expect(content:find("w, h%s+%- %(number%)")).to_be_truthy()
            t.expect(content:find("isAnimation")).to_be_truthy()

            -- Check for SPACER PROPS documentation
            t.expect(content:find("SPACER PROPS:")).to_be_truthy()

            -- Check for DIVIDER PROPS documentation
            t.expect(content:find("DIVIDER PROPS:")).to_be_truthy()
            t.expect(content:find("thickness")).to_be_truthy()
        end)

        t.it("individual showcases have inline PROPS comments", function()
            local f = io.open("assets/scripts/ui/showcase/showcase_registry.lua", "r")
            local content = f:read("*all")
            f:close()

            -- Check that showcases have inline PROPS comments
            local propsComments = 0
            for _ in content:gmatch("PROPS:") do
                propsComments = propsComments + 1
            end
            t.expect(propsComments >= 10).to_be(true)
        end)

        t.it("all showcases have description field", function()
            for id, showcase in pairs(primitives) do
                if type(showcase) == "table" and showcase.name then
                    t.expect(type(showcase.description)).to_be("string")
                    t.expect(#showcase.description > 10).to_be(true)
                end
            end
        end)

        t.it("all showcases have source code examples", function()
            for id, showcase in pairs(primitives) do
                if type(showcase) == "table" and showcase.name then
                    t.expect(type(showcase.source)).to_be("string")
                    t.expect(#showcase.source > 20).to_be(true)
                end
            end
        end)
    end)
end)

t.describe("Showcase completeness", function()
    t.it("primitives category has expected showcases in order", function()
        local primitives = ShowcaseRegistry._showcases.primitives
        local expectedOrder = {
            "text_basic",
            "text_sizes",
            "text_colors",
            "text_alignments",
            "text_styled",
            "image_basic",
            "image_sizing",
            "image_tinting",
            "anim_basic",
            "anim_speed",
            "spacer_horizontal",
            "spacer_vertical",
            "spacer_combined",
            "divider",
            "icon_label",
        }

        t.expect(#primitives.order).to_be(#expectedOrder)
        for i, id in ipairs(expectedOrder) do
            t.expect(primitives.order[i]).to_be(id)
        end
    end)

    t.it("all showcases in order exist", function()
        local primitives = ShowcaseRegistry._showcases.primitives
        for _, id in ipairs(primitives.order) do
            t.expect(primitives[id]).to_be_truthy()
            t.expect(primitives[id].create).to_be_truthy()
            t.expect(type(primitives[id].create)).to_be("function")
        end
    end)

    t.it("all showcase create functions execute without error", function()
        local primitives = ShowcaseRegistry._showcases.primitives
        for _, id in ipairs(primitives.order) do
            local success, err = pcall(primitives[id].create)
            t.expect(success).to_be(true)
        end
    end)
end)

-- Run tests
t.run()
