--[[
Crusenho UI Pack compatibility tests (in-engine Lua).

Run with:
  RUN_CRUSENHO_UI_PACK_TESTS=1 ./build-debug/raylib-cpp-cmake-template
]]

local t = require("tests.test_runner")

local M = {}

local PACK_NAME = "crusenho_flat"
local PACK_MANIFEST = "assets/ui_packs/crusenho_flat/pack.json"

local function ensure_pack()
    local existing = ui.use_pack(PACK_NAME)
    if existing then
        return existing
    end

    local ok = ui.register_pack(PACK_NAME, PACK_MANIFEST)
    t.expect(ok).to_be(true)

    local pack = ui.use_pack(PACK_NAME)
    t.expect(pack).to_be_truthy()
    return pack
end

t.describe("Crusenho UI pack registration", function()
    t.it("registers and returns a pack handle", function()
        local pack = ensure_pack()
        t.expect(pack).to_be_truthy()
    end)
end)

t.describe("Crusenho panel coverage", function()
    t.it("loads representative panel assets", function()
        local pack = ensure_pack()
        local keys = { "frame01", "frame02", "banner01", "frameslot01" }
        for _, key in ipairs(keys) do
            local cfg = pack:panel(key)
            t.expect(cfg).to_be_truthy()
            t.expect(cfg.stylingType).to_be(UIStylingType.NinePatchBorders)
        end
    end)
end)

t.describe("Crusenho button/state coverage", function()
    t.it("loads full primary button states", function()
        local pack = ensure_pack()
        local states = { "normal", "hover", "pressed", "disabled" }
        for _, state in ipairs(states) do
            local cfg = pack:button("primary", state)
            t.expect(cfg).to_be_truthy()
        end
    end)

    t.it("loads select + toggle states", function()
        local pack = ensure_pack()
        t.expect(pack:button("select_primary", "normal")).to_be_truthy()
        t.expect(pack:button("select_primary", "pressed")).to_be_truthy()
        t.expect(pack:button("toggle_round", "normal")).to_be_truthy()
        t.expect(pack:button("toggle_round", "pressed")).to_be_truthy()
        t.expect(pack:button("toggle_lr", "normal")).to_be_truthy()
        t.expect(pack:button("toggle_lr", "pressed")).to_be_truthy()
    end)
end)

t.describe("Crusenho bar/slider/input coverage", function()
    t.it("loads progress bar parts", function()
        local pack = ensure_pack()
        t.expect(pack:progress_bar("style_01", "background")).to_be_truthy()
        t.expect(pack:progress_bar("style_01", "fill")).to_be_truthy()
    end)

    t.it("loads slider and scrollbar parts", function()
        local pack = ensure_pack()
        t.expect(pack:slider("default", "track")).to_be_truthy()
        t.expect(pack:slider("default", "thumb")).to_be_truthy()
        t.expect(pack:scrollbar("default", "track")).to_be_truthy()
        t.expect(pack:scrollbar("default", "thumb")).to_be_truthy()
    end)

    t.it("loads input states", function()
        local pack = ensure_pack()
        local normal = pack:input("default", "normal")
        local focus = pack:input("default", "focus")
        t.expect(normal).to_be_truthy()
        t.expect(focus).to_be_truthy()
        t.expect(normal.stylingType).to_be(UIStylingType.NinePatchBorders)
        t.expect(focus.stylingType).to_be(UIStylingType.NinePatchBorders)
    end)
end)

t.describe("Crusenho icon coverage", function()
    t.it("loads all manifest icons as fixed sprites", function()
        local pack = ensure_pack()
        local json = require("external.json")
        local file = io.open(PACK_MANIFEST, "r")
        t.expect(file).to_be_truthy()
        local content = file and file:read("*a") or nil
        if file then
            file:close()
        end
        t.expect(content).to_be_truthy()

        local ok, manifest = pcall(json.decode, content)
        t.expect(ok).to_be(true)
        t.expect(type(manifest)).to_be("table")
        t.expect(type(manifest.icons)).to_be("table")

        local names = {}
        for name, _ in pairs(manifest.icons) do
            table.insert(names, name)
        end
        table.sort(names)
        t.expect(#names > 0).to_be(true)

        for _, name in ipairs(names) do
            local cfg = pack:icon(name)
            t.expect(cfg).to_be_truthy()
            t.expect(cfg.stylingType).to_be(UIStylingType.Sprite)
            t.expect(cfg.spriteScaleMode).to_be(SpriteScaleMode.Fixed)
        end
    end)
end)

t.describe("Crusenho manifest animation metadata", function()
    t.it("declares animation sequences derived from pack assets", function()
        local json = require("external.json")
        local file = io.open(PACK_MANIFEST, "r")
        t.expect(file).to_be_truthy()
        local content = file and file:read("*a") or nil
        if file then
            file:close()
        end
        t.expect(content).to_be_truthy()

        local ok, manifest = pcall(json.decode, content)
        t.expect(ok).to_be(true)
        t.expect(type(manifest)).to_be("table")
        t.expect(type(manifest.animations)).to_be("table")

        local count = 0
        for _, spec in pairs(manifest.animations) do
            count = count + 1
            t.expect(type(spec.kind)).to_be("string")
            local frames = spec.states or spec.frames or spec.styles
            t.expect(type(frames)).to_be("table")
            local frameCount = 0
            for _ in ipairs(frames) do
                frameCount = frameCount + 1
            end
            t.expect(frameCount >= 2).to_be(true)
        end

        t.expect(manifest.animations.progress_fill_cycle).to_be_truthy()
        t.expect(manifest.animations.progress_bg_cycle).to_be_truthy()
        t.expect(count >= 6).to_be(true)
    end)
end)

t.describe("Crusenho demo module", function()
    t.it("builds showcase tree without errors", function()
        local pack = ensure_pack()
        t.expect(pack).to_be_truthy()

        local demo = require("ui.crusenho_pack_demo")
        t.expect(demo).to_be_truthy()
        t.expect(type(demo.createShowcase)).to_be("function")

        local tree = demo.createShowcase()
        t.expect(tree).to_be_truthy()
        local treeType = type(tree)
        local isSupported = (treeType == "table") or (treeType == "userdata")
        t.expect(isSupported).to_be(true)
    end)
end)

function M.run()
    print("\n================================================================================")
    print("CRUSENHO UI PACK TESTS")
    print("================================================================================\n")

    local success = t.run()

    print("\n================================================================================")
    if success then
        print("ALL CRUSENHO UI PACK TESTS PASSED!")
    else
        print("SOME CRUSENHO UI PACK TESTS FAILED - see output above")
    end
    print("================================================================================\n")

    return success
end

return M
