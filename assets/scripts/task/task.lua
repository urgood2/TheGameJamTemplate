local registry = require("registry")

-- This enables the monobehavior-like script to execute coroutine tasks


-- task.lua
local M = {}

local function get_script_component()
    if not self.__entity_id then
        error("Missing self.__entity_id")
    end
    return get_script_component(self.__entity_id)
end

-- Wait for a duration (deltaTime-aware)
function M.wait(seconds)
    local elapsed = 0
    while elapsed < seconds do
        local dt = coroutine.yield()
        elapsed = elapsed + dt
    end
end

-- Fire-and-forget coroutine task
function M.run_task(fn)
    local co = coroutine.create(fn)
    local script = get_script_component()
    script:add_task(co)
    return co
end

-- Named task (prevents duplicates)
function M.run_named_task(name, fn)
    self._named_tasks = self._named_tasks or {}
    if self._named_tasks[name] then return end
    local co = coroutine.create(function()
        fn()
        self._named_tasks[name] = nil
    end)
    self._named_tasks[name] = co
    local script = get_script_component()
    script:add_task(co)
end

-- Cancel a named task
function M.cancel_named_task(name)
    self._named_tasks = self._named_tasks or {}
    self._named_tasks[name] = nil
end

-- Debug how many tasks are running
function M.count_tasks()
    local script = get_script_component()
    return script:count_tasks()
end

return M