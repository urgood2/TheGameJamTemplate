-- This enables the monobehavior-like script to execute coroutine tasks
-- Note: registry is a C++ global exposed via Sol2, not a Lua module


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
        -- print("[task] WAIT: dt = " .. dt .. ", elapsed = " .. elapsed)
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

    print("[run_named_task]", name, "called")
    if self._named_tasks[name] then
        print("[run_named_task]", name, "already exists, skipping")
        return
    end

    local script = get_script_component_from_self(self)

    local wrapped = function()
        print("[run_named_task]", name, "coroutine started")
        fn()
        self._named_tasks[name] = nil -- clean up after task finishes
        print("[run_named_task]", name, "coroutine finished")
    end

    self._named_tasks[name] = true -- use boolean as marker

    script:add_task(wrapped)
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