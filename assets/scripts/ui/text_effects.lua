-- Proxy file for ui.text_effects directory module
-- Lua package.path doesn't include ?/init.lua pattern, so this forwards to the init
return require("ui.text_effects.init")
