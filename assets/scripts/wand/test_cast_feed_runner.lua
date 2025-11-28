-- Runner for TestCastFeed
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

-- Mock global environment
_G.globals = {
    screenWidth = function() return 1920 end,
    screenHeight = function() return 1080 end,
    getScreenWidth = function() return 1920 end,
    getScreenHeight = function() return 1080 end
}
_G.layers = { ui = 1, sprites = 0 }
_G.z_orders = { ui = 100 }
_G.command_buffer = {
    queueDrawText = function() end
}
_G.layer = { DrawCommandSpace = { Screen = 1 } }
_G.log_debug = function(...) print("[DEBUG]", ...) end

-- Mock registry module
local mock_registry = {
    create = function() return 1 end,
    destroy = function() end,
    valid = function() return true end,
    add_script = function() end
}
package.loaded["registry"] = mock_registry
_G.registry = mock_registry

-- Mock task module (since it requires registry)
package.loaded["task/task"] = {
    run_named_task = function() end,
    wait = function() end
}

-- Mock WandTriggers to avoid component cache issues
package.loaded["wand.wand_triggers"] = {
    init = function() end,
    update = function() end,
    register_trigger = function() end,
    register = function() end,                 -- Mock register method
    check_trigger = function() return true end -- Always trigger for test
}

local TestCastFeed = require("wand.test_cast_feed")
TestCastFeed.run()
