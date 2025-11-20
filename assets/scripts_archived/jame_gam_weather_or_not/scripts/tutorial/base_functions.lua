function wait(seconds)
    local startTime = os.time()
    while os.difftime(os.time(), startTime) < seconds do
        coroutine.yield() -- Yield to allow other operations to run
    end
end

-- The key parameter is the string version of raylib's KeyboardKey enum. Case does not matter.
function waitForKeyPress(key)
    while not isKeyPressed(key) do 
        coroutine.yield() -- Yield until the key is pressed
    end
end

-- This function waits for a specific event to occur in the game.
-- It will return true if there is no payload, or the payload (array-like table, access starting at index 1) if it exists.
function waitForEvent(event_name)
    -- Coroutine to check for the event in each frame
    while true do
        local event_occurred, payload = getEventOccurred(event_name)

        -- Check if the event has occurred
        if event_occurred then
            -- Event has occurred, clear the flag and return the payload or true
            setEventOccurred(event_name, false)
            print("Event occurred:", event_name)
            if payload then
                print("Payload:", payload)
            else 
                print ("Payload is nil")
            end
            return payload or true  -- Return the payload if it exists, otherwise return true
        end

        -- Yield to allow other operations to run in this frame, then check again in the next frame
        coroutine.yield()
    end
end

-- example usage: 
-- ```
-- waitForCondition(function()
--  return getPlayerPosition().x > 100 -- Assume getPlayerPosition() is implemented elsewhere
-- end)
-- ```
-- Note that when passing from C++, the argument cannot be a lambda function. If it is a lambda,
-- register it with the lua state separately first.
-- Example:
--
-- Instead of this 
-- ```
-- auto waitForConditionResult = waitForCondition([&condition_met]() {
--     return condition_met;  // Condition based on external state
-- });
-- ```
-- Do this
-- ```
-- lua.set_function("alwaysFalse", []() { return false; });
-- auto waitForConditionResult = waitForCondition(lua["alwaysFalse"]);
-- ```
function waitForCondition(condition) -- this can be a function for lambda that returns a boolean
    -- Coroutine to check the condition in each frame
    while not condition() do
        print("Condition not met, yielding...")
        coroutine.yield() -- Yield to allow other operations to run in this frame
    end
    -- Condition has been met, continue the coroutine execution
    print("Condition met, resuming...")
    return true
end