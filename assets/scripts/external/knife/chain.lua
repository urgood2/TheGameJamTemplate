--[[
    Creates a flexible, chainable middleware system.

    This module allows you to define a sequence of functions ("links")
    that are executed in order. Each link receives a `continue` function
    that it must call to pass control to the next link.

    This pattern supports both synchronous and asynchronous operations,
    making it ideal for handling tasks like processing web requests,
    running a series of file operations, or managing game state transitions.

    @module createChain
    @return A function to start a new chain.
--]]

--[[
    The internal invoker that recursively calls each link in the chain.
    It handles passing the `continue` function and manages the asynchronous flow.
    @local
    @param links A table of all the function links in the chain.
    @param index The index of the current link to execute.
    @return A function that starts the execution of the link at `index`.
--]]
local function Invoker(links, index)
    return function(...)
        local link = links[index]
        -- If there are no more links, the chain ends.
        if not link then
            return
        end

        -- Create the `continue` function for the *next* link.
        local continue = Invoker(links, index + 1)

        -- Execute the current link, passing it the `continue` function
        -- and any other arguments.
        local returned = link(continue, ...)

        -- This block enables asynchronous behavior.
        -- If a link returns a function, we execute it and provide it with a
        -- callback that can resume the chain.
        if returned then
            -- The returned function is given a callback (a wrapped `continue`).
            -- When this callback is fired, the chain resumes.
            returned(function(_, ...) continue(...) end)
        end
    end
end

--[[
    The main factory function for creating a new chain.
    @param ... Initial functions (links) to add to the chain.
    @return The `chain` function, which can be used to add more links or to execute the chain.
--]]
return function(...)
    -- `links` stores all the functions in the chain.
    local links = { ... }

    -- The `chain` function is the main interface for interacting with the middleware chain.
    local function chain(...)
        -- If `chain` is called WITH arguments, it adds them as new links to the chain.
        if (...) then
            local offset = #links
            for index = 1, select('#', ...) do
                links[offset + index] = select(index, ...)
            end
            -- Return itself to allow for fluent chaining, e.g., chain(link1)(link2).
            return chain
        end

        -- If `chain` is called with NO arguments (`chain()`), it executes the entire chain.
        -- It returns the Invoker, which you can immediately call with initial data.
        -- e.g., `chain()(initialData)`
        return Invoker(links, 1)
    end

    return chain
end