--[[
================================================================================
pool.lua - Generic Object Pooling
================================================================================
Reusable object pooling with acquire/release pattern for performance-critical
objects like projectiles, particles, and temporary entities.

Usage:
    local Pool = require("core.pool")

    local bulletPool = Pool.create({
        name = "bullets",
        factory = function() return createBulletEntity() end,
        reset = function(entity) resetBullet(entity) end,
        initial = 20,
        max = 100,
    })

    local bullet = bulletPool:acquire()
    bulletPool:release(bullet)

    bulletPool:acquireFor(1.5, function(bullet)
        -- bullet auto-releases after 1.5 seconds
    end)

Dependencies:
    - core.timer (for timed release)
]]

if _G.__POOL__ then return _G.__POOL__ end

local Pool = {}
Pool.__index = Pool

local timer = require("core.timer")

local pools = {}

function Pool.create(opts)
    local self = setmetatable({}, Pool)
    
    self._name = opts.name or ("pool_" .. tostring(os.time()))
    self._factory = opts.factory
    self._reset = opts.reset or function() end
    self._onAcquire = opts.onAcquire or function() end
    self._onRelease = opts.onRelease or function() end
    self._max = opts.max or 100
    
    self._available = {}
    self._active = {}
    self._activeCount = 0
    
    local initial = opts.initial or 0
    for _ = 1, initial do
        local obj = self._factory()
        table.insert(self._available, obj)
    end
    
    pools[self._name] = self
    return self
end

function Pool:acquire()
    local obj
    
    if #self._available > 0 then
        obj = table.remove(self._available)
    elseif self._activeCount < self._max then
        obj = self._factory()
    else
        return nil
    end
    
    self._active[obj] = true
    self._activeCount = self._activeCount + 1
    
    self._onAcquire(obj)
    
    return obj
end

function Pool:release(obj)
    if not self._active[obj] then
        return false
    end
    
    self._active[obj] = nil
    self._activeCount = self._activeCount - 1
    
    self._reset(obj)
    self._onRelease(obj)
    
    table.insert(self._available, obj)
    
    return true
end

function Pool:acquireFor(duration, callback)
    local obj = self:acquire()
    if not obj then return nil end
    
    if callback then
        callback(obj)
    end
    
    local tag = string.format("pool_%s_%s", self._name, tostring(obj))
    timer.after(duration, function()
        self:release(obj)
    end, tag)
    
    return obj
end

function Pool:clear()
    for obj, _ in pairs(self._active) do
        self._reset(obj)
    end
    self._active = {}
    self._available = {}
    self._activeCount = 0
end

function Pool:stats()
    return {
        name = self._name,
        available = #self._available,
        active = self._activeCount,
        max = self._max,
    }
end

function Pool.get(name)
    return pools[name]
end

function Pool.clearAll()
    for _, pool in pairs(pools) do
        pool:clear()
    end
end

function Pool.statsAll()
    local result = {}
    for name, pool in pairs(pools) do
        result[name] = pool:stats()
    end
    return result
end

_G.__POOL__ = Pool
return Pool
