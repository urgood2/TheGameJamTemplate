-- assets/scripts/core/procgen/vendor.lua
-- Normalizes Graph/Grid/Forma imports without relying on globals
-- This module ensures required dependencies exist and provides clean local references

local vendor = {}

-- Add forma alias to package.path so that internal forma requires work
-- Forma internally uses require("forma.xxx") but files are at external/forma/
-- We set up package.preload redirects for all forma submodules
local function setup_forma_aliases()
    local forma_modules = {
        "cell", "pattern", "primitives", "automata",
        "neighbourhood", "multipattern", "raycasting"
    }
    local forma_utils = {"bsp", "convex_hull", "noise", "random"}

    for _, mod in ipairs(forma_modules) do
        local key = "forma." .. mod
        if not package.preload[key] then
            package.preload[key] = function()
                return require("external.forma." .. mod)
            end
        end
    end
    for _, mod in ipairs(forma_utils) do
        local key = "forma.utils." .. mod
        if not package.preload[key] then
            package.preload[key] = function()
                return require("external.forma.utils." .. mod)
            end
        end
    end
end

setup_forma_aliases()

-- Lua 5.3/5.4 compatibility: unpack was moved to table.unpack
-- Grid.lua uses unpack(), so we need to provide the global
if not _G.unpack then
    _G.unpack = table.unpack
end

-- Ensure Object exists (required by Graph and Grid)
if not _G.Object then
    _G.Object = require("external.object")
end

-- Ensure table.any exists (required by Graph)
if type(table.any) ~= "function" then
    function table.any(t, pred)
        for _, v in ipairs(t) do
            if pred(v) then return true end
        end
        return false
    end
end

-- Ensure table.deep_copy exists (required by Grid:clone)
-- We provide our own implementation to avoid engine dependencies in util.util
if type(table.deep_copy) ~= "function" then
    local function deep_copy(orig, copies)
        copies = copies or {}
        if type(orig) ~= "table" then
            return orig
        end
        if copies[orig] then
            return copies[orig]
        end
        local copy = {}
        copies[orig] = copy
        for k, v in pairs(orig) do
            copy[deep_copy(k, copies)] = deep_copy(v, copies)
        end
        local mt = getmetatable(orig)
        if mt then
            setmetatable(copy, deep_copy(mt, copies))
        end
        return copy
    end
    table.deep_copy = deep_copy
end

-- Load libraries (they define globals Graph, Grid)
require("external.graph")
require("external.grid")

-- Capture references
vendor.Graph = _G.Graph
vendor.Grid = _G.Grid

-- Forma: require modules directly (avoid global-import init.lua)
-- Note: forma modules are under external/forma/
vendor.forma = {
    cell = require("external.forma.cell"),
    pattern = require("external.forma.pattern"),
    primitives = require("external.forma.primitives"),
    automata = require("external.forma.automata"),
    neighbourhood = require("external.forma.neighbourhood"),
    multipattern = require("external.forma.multipattern"),
    raycasting = require("external.forma.raycasting"),
}

return vendor
