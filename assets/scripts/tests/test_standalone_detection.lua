-- assets/scripts/tests/test_standalone_detection.lua
--[[
================================================================================
TEST: Standalone Test Detection for Game-Only Features
================================================================================
Verifies that tests receive clear error messages when accidentally using
features that require the game engine (raylib, audio, window, etc.).

Run standalone: lua assets/scripts/tests/test_standalone_detection.lua
]]

-- Setup package path for standalone execution
package.path = package.path .. ";./assets/scripts/?.lua"

-- Load engine mock first to set up game-only feature detection
local EngineMock = require("tests.mocks.engine_mock")
local t = require("tests.test_runner")

-- Reset any previous state
t.reset()
EngineMock.reset()

--------------------------------------------------------------------------------
-- Test Suite: Game-Only Feature Detection
--------------------------------------------------------------------------------

t.describe("Game-Only Feature Detection", function()
    t.it("should provide clear error for raylib access", function()
        t.expect(function()
            local _ = _G.raylib.InitWindow
        end).to_throw("GAME%-ONLY FEATURE")  -- Escape hyphen for pattern
    end)

    t.it("should provide clear error for window access", function()
        t.expect(function()
            local _ = _G.window.getWidth
        end).to_throw("GAME%-ONLY FEATURE")
    end)

    t.it("should provide clear error for audio access", function()
        t.expect(function()
            local _ = _G.audio.playSound
        end).to_throw("GAME%-ONLY FEATURE")
    end)

    t.it("should provide clear error for input_system access", function()
        t.expect(function()
            local _ = _G.input_system.isKeyPressed
        end).to_throw("GAME%-ONLY FEATURE")
    end)

    t.it("should provide clear error for quadtree access", function()
        t.expect(function()
            local _ = _G.quadtreeWorld.query
        end).to_throw("GAME%-ONLY FEATURE")
    end)

    t.it("error message includes feature name", function()
        local ok, err = pcall(function()
            local _ = _G.raylib.SomeFunction
        end)
        t.expect(ok).to_be(false)
        t.expect(tostring(err)).to_contain("raylib")
    end)

    t.it("error message explains it requires game engine", function()
        local ok, err = pcall(function()
            local _ = _G.window.foo
        end)
        t.expect(ok).to_be(false)
        t.expect(tostring(err)).to_contain("game engine")
    end)

    t.it("error message suggests mocking or skipping", function()
        local ok, err = pcall(function()
            local _ = _G.audio.bar
        end)
        t.expect(ok).to_be(false)
        local errStr = tostring(err)
        t.expect(errStr:find("mock") or errStr:find("skip")).to_be_truthy()
    end)
end)

--------------------------------------------------------------------------------
-- Test Suite: Mocked Features Work
--------------------------------------------------------------------------------

t.describe("Mocked Features Work", function()
    t.it("registry is mocked and usable", function()
        t.expect(_G.registry).to_be_truthy()
        local entity = _G.registry:create()
        t.expect(entity).to_be_type("number")
        t.expect(_G.registry:valid(entity)).to_be(true)
    end)

    t.it("component_cache is mocked and usable", function()
        t.expect(_G.component_cache).to_be_truthy()
        t.expect(_G.component_cache.get).to_be_type("function")
    end)

    t.it("log functions are mocked", function()
        t.expect(_G.log_debug).to_be_type("function")
        t.expect(_G.log_warn).to_be_type("function")
        t.expect(_G.log_error).to_be_type("function")

        -- Should not throw
        _G.log_debug("test message")
        _G.log_warn("test warning")
    end)

    t.it("globals are mocked with reasonable defaults", function()
        t.expect(_G.globals).to_be_truthy()
        t.expect(_G.globals.screenWidth).to_be_type("number")
        t.expect(_G.globals.screenHeight).to_be_type("number")
    end)

    t.it("ui system is mocked", function()
        t.expect(_G.ui).to_be_truthy()
        t.expect(_G.ui.definitions).to_be_truthy()
        t.expect(_G.ui.definitions.def).to_be_type("function")
    end)

    t.it("ensure_entity helper works", function()
        t.expect(_G.ensure_entity(1000)).to_be(true)
        t.expect(_G.ensure_entity(nil)).to_be(false)
        t.expect(_G.ensure_entity("invalid")).to_be(false)
    end)
end)

--------------------------------------------------------------------------------
-- Test Suite: Mock API
--------------------------------------------------------------------------------

t.describe("EngineMock API", function()
    t.it("can check if a global is mocked", function()
        t.expect(EngineMock.is_mocked("registry")).to_be(true)
        t.expect(EngineMock.is_mocked("component_cache")).to_be(true)
        t.expect(EngineMock.is_mocked("nonexistent")).to_be(false)
    end)

    t.it("can list all mocked globals", function()
        local list = EngineMock.list_mocked()
        t.expect(list).to_be_type("table")
        t.expect(#list > 0).to_be(true)
    end)

    t.it("can reset mock state", function()
        -- Create some entities
        local e1 = _G.registry:create()
        local e2 = _G.registry:create()

        -- Reset
        EngineMock.reset()

        -- Entity IDs should start fresh
        local e3 = _G.registry:create()
        -- After reset, should be back to 1001 (1000 + 1)
        t.expect(e3).to_be(1001)
    end)

    t.it("captures log messages", function()
        EngineMock.clear_logs()

        _G.log_debug("debug message")
        _G.log_warn("warning message")

        local logs = EngineMock.get_logs()
        t.expect(logs.debug).to_contain("debug message")
        t.expect(logs.warn).to_contain("warning message")
    end)
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

local success = t.run()
t.reset()
os.exit(success and 0 or 1)
