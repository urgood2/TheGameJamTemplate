--[[
================================================================================
UI BINDING TESTS
================================================================================
Smoke + functional tests for UI bindings exposed to Lua.

Run with:
    lua assets/scripts/tests/test_ui_bindings.lua
================================================================================
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/tests/?.lua"

local standalone = not _G.registry
if standalone then
    pcall(require, "tests.mocks.engine_mock")
end

local t = require("tests.test_runner")

local caps = t.get_capabilities()

local function detect_ui_defs()
    if _G.ui and _G.ui.definitions and type(_G.ui.definitions.def) == "function" then
        return true
    end
    local ok = pcall(require, "ui.ui_definition_helper")
    return ok and _G.ui and _G.ui.definitions and type(_G.ui.definitions.def) == "function"
end

caps.ui = type(_G.ui) == "table"

caps.ui_box = caps.ui
    and type(_G.ui.box) == "table"
    and type(_G.ui.box.Initialize) == "function"
    and type(_G.ui.box.RenewAlignment) == "function"
    and type(_G.ui.box.AddStateTagToUIBox) == "function"
    and type(_G.ui.box.set_draw_layer) == "function"
    and type(_G.ui.box.ReplaceChildren) == "function"
    and type(_G.ui.box.GetUIEByID) == "function"

caps.ui_defs = caps.ui_box and detect_ui_defs()

caps.registry = _G.registry ~= nil

local function register(test_id, doc_id, requires, fn)
    t:register(test_id, "bindings", fn, {
        doc_ids = { doc_id },
        tags = { "bindings", "ui" },
        requires = requires or {},
    })
end

local function build_root_definition()
    if not caps.ui_defs then
        return nil
    end

    local ok, node = pcall(_G.ui.definitions.def, {
        type = "ROOT",
        config = {
            id = "root",
            width = 200,
            height = 100,
        },
        children = {
            {
                type = "TEXT",
                config = {
                    id = "label",
                    text = "UI Bindings",
                },
            },
        },
    })

    if ok then
        return node
    end

    return nil
end

local function assert_entity(value)
    t.expect(value ~= nil).to_be(true)
end

--------------------------------------------------------------------------------
-- Smoke tests
--------------------------------------------------------------------------------

register("ui.module.smoke", "sol2_usertype_ui", { "ui" }, function()
    t.expect(type(_G.ui)).to_be("table")
    t.expect(type(_G.ui.box)).to_be("table")
    t.expect(type(_G.ui.element)).to_be("table")
end)

--------------------------------------------------------------------------------
-- UIBox bindings (high-frequency)
--------------------------------------------------------------------------------

register("ui.box.initialize.basic", "sol2_function_ui_box_initialize", { "ui_box", "ui_defs" }, function()
    local def = build_root_definition()
    t.expect(def).to_be_truthy()

    local ok, box = pcall(_G.ui.box.Initialize, { x = 0, y = 0 }, def)
    t.expect(ok).to_be(true)
    assert_entity(box)
end)

register("ui.box.set_draw_layer.basic", "sol2_function_ui_box_set_draw_layer", { "ui_box", "ui_defs" }, function()
    local def = build_root_definition()
    t.expect(def).to_be_truthy()

    local ok_box, box = pcall(_G.ui.box.Initialize, { x = 0, y = 0 }, def)
    t.expect(ok_box).to_be(true)
    assert_entity(box)

    local ok = pcall(_G.ui.box.set_draw_layer, box, "ui")
    t.expect(ok).to_be(true)
end)

register("ui.box.add_state_tag.basic", "sol2_function_ui_box_addstatetagtouibox", { "ui_box", "ui_defs" }, function()
    local def = build_root_definition()
    t.expect(def).to_be_truthy()

    local ok_box, box = pcall(_G.ui.box.Initialize, { x = 0, y = 0 }, def)
    t.expect(ok_box).to_be(true)
    assert_entity(box)

    local ok = pcall(_G.ui.box.AddStateTagToUIBox, box, "test_state")
    t.expect(ok).to_be(true)
end)

register("ui.box.renew_alignment.basic", "sol2_function_ui_box_renewalignment", { "ui_box", "ui_defs", "registry" }, function()
    local def = build_root_definition()
    t.expect(def).to_be_truthy()

    local ok_box, box = pcall(_G.ui.box.Initialize, { x = 0, y = 0 }, def)
    t.expect(ok_box).to_be(true)
    assert_entity(box)

    local ok = pcall(_G.ui.box.RenewAlignment, _G.registry, box)
    t.expect(ok).to_be(true)
end)

register("ui.box.replace_children.basic", "sol2_function_ui_box_replacechildren", { "ui_box", "ui_defs" }, function()
    local def = build_root_definition()
    t.expect(def).to_be_truthy()

    local ok_box, box = pcall(_G.ui.box.Initialize, { x = 0, y = 0 }, def)
    t.expect(ok_box).to_be(true)
    assert_entity(box)

    local ok_new, new_def = pcall(_G.ui.definitions.def, {
        type = "ROOT",
        config = { id = "root" },
        children = {
            { type = "TEXT", config = { id = "replacement", text = "Updated" } },
        },
    })
    t.expect(ok_new).to_be(true)
    t.expect(new_def).to_be_truthy()

    local ok = pcall(_G.ui.box.ReplaceChildren, box, new_def)
    t.expect(ok).to_be(true)
end)

register("ui.box.get_uie_by_id.basic", "sol2_function_ui_box_getuiebyid", { "ui_box", "ui_defs", "registry" }, function()
    local def = build_root_definition()
    t.expect(def).to_be_truthy()

    local ok_box, box = pcall(_G.ui.box.Initialize, { x = 0, y = 0 }, def)
    t.expect(ok_box).to_be(true)
    assert_entity(box)

    local ok, entity = pcall(_G.ui.box.GetUIEByID, _G.registry, box, "label")
    t.expect(ok).to_be(true)
    if entity ~= nil then
        assert_entity(entity)
    end
end)

--------------------------------------------------------------------------------
-- Run
--------------------------------------------------------------------------------

t.run()
