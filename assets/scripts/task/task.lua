local registry = require("registry")

-- This enables the monobehavior-like script to execute coroutine tasks


-- task.lua
local M = {}

local function get_script_component_from_self(self)
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
function M.run_task(self, fn)
    local co = fn
    local script = get_script_component_from_self(self)
    script:add_task(co)
    return co
end

-- Named task (prevents duplicates)
function M.run_named_task(self, name, fn)
    
    self._named_tasks = self._named_tasks or {}
    if self._named_tasks[name] then return end
    local co = function()
        fn()
        self._named_tasks[name] = nil
        print("coroutine Task '" .. name .. "' completed and removed.")
    end
    self._named_tasks[name] = co
    local script = get_script_component_from_self(self)
    script:add_task(co)
end

-- Cancel a named task
function M.cancel_named_task(self, name)
    self._named_tasks = self._named_tasks or {}
    self._named_tasks[name] = nil
end

-- Debug how many tasks are running
function M.count_tasks(self)
    local script = get_script_component_from_self(self)
    return script:count_tasks()
end

return M