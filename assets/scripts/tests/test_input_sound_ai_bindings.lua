--[[
================================================================================
INPUT / SOUND / AI BINDING TESTS
================================================================================
Smoke tests for core input, sound, and AI bindings exposed to Lua.

Run with:
    lua assets/scripts/tests/test_input_sound_ai_bindings.lua
================================================================================
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/tests/?.lua"

local standalone = not _G.registry
if standalone then
    pcall(require, "tests.mocks.engine_mock")
end

local t = require("tests.test_runner")

local caps = t.get_capabilities()
caps.input = type(_G.in) == "table"
caps.sound = type(_G.playSoundEffect) == "function"
caps.ai = type(_G.ai) == "table" and type(_G.create_ai_entity) == "function"

local function register(test_id, doc_id, requires, fn)
    t:register(test_id, "bindings", fn, {
        doc_ids = { doc_id },
        tags = { "bindings", "input_sound_ai" },
        requires = requires or {},
    })
end

local function assert_vector(value)
    if type(value) == "table" then
        t.expect(type(value.x)).to_be("number")
        t.expect(type(value.y)).to_be("number")
    else
        t.expect(value).to_be_truthy()
    end
end

--------------------------------------------------------------------------------
-- Input bindings
--------------------------------------------------------------------------------

register("input.is_key_pressed.basic", "sol2_function_in_iskeypressed", { "input" }, function()
    t.expect(type(_G.in)).to_be("table")
    t.expect(type(_G.in.isKeyPressed)).to_be("function")

    local key = (_G.KeyboardKey and _G.KeyboardKey.KEY_A) or 0
    local ok, result = pcall(_G.in.isKeyPressed, key)
    t.expect(ok).to_be(true)
    t.expect(type(result)).to_be("boolean")
end)

register("input.get_mouse_position.basic", "sol2_function_in_getmousepos", { "input" }, function()
    t.expect(type(_G.in)).to_be("table")
    t.expect(type(_G.in.getMousePos)).to_be("function")

    local ok, pos = pcall(_G.in.getMousePos)
    t.expect(ok).to_be(true)
    assert_vector(pos)
end)

--------------------------------------------------------------------------------
-- Sound bindings
--------------------------------------------------------------------------------

register("sound.play.basic", "sol2_function_playsoundeffect", { "sound" }, function()
    t.expect(type(_G.playSoundEffect)).to_be("function")

    local ok = pcall(_G.playSoundEffect, "ui", "click")
    t.expect(ok).to_be(true)
end)

register("sound.stop.basic", "sol2_function_stopallmusic", { "sound" }, function()
    t.expect(type(_G.stopAllMusic)).to_be("function")

    local ok = pcall(_G.stopAllMusic)
    t.expect(ok).to_be(true)
end)

--------------------------------------------------------------------------------
-- AI bindings
--------------------------------------------------------------------------------

register("ai.list_lua_files.basic", "sol2_function_ai_list_lua_files", { "ai" }, function()
    t.expect(type(_G.ai)).to_be("table")
    t.expect(type(_G.ai.list_lua_files)).to_be("function")

    local ok, list = pcall(_G.ai.list_lua_files, "ai.entity_types")
    t.expect(ok).to_be(true)
    t.expect(type(list)).to_be("table")
end)

register("ai.create_entity.basic", "sol2_function_create_ai_entity", { "ai" }, function()
    t.expect(type(_G.create_ai_entity)).to_be("function")

    local ok, list = pcall(_G.ai.list_lua_files, "ai.entity_types")
    t.expect(ok).to_be(true)

    local type_name = nil
    if type(list) == "table" and #list > 0 then
        type_name = list[1]
    else
        type_name = "kobold"
    end

    local ok_create, entity = pcall(_G.create_ai_entity, type_name)
    t.expect(ok_create).to_be(true)
    t.expect(type(entity)).to_be("number")
end)

--------------------------------------------------------------------------------
-- Run
--------------------------------------------------------------------------------

t.run()
