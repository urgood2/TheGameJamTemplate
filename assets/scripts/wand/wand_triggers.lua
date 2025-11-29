--[[
================================================================================
WAND TRIGGER SYSTEM
================================================================================
Handles trigger registration, activation, and event subscriptions.

Trigger Types:
- Timer-based: every_N_seconds, on_cooldown
- Event-based: on_player_attack, on_bump_enemy, on_dash, on_distance_traveled
- Condition-based: on_low_health, on_pickup

Responsibilities:
- Register triggers for wands
- Update timer-based triggers
- Subscribe to game events
- Check trigger conditions
- Fire triggers when conditions met

Integration:
- Calls WandExecutor.execute() when trigger fires
- Uses timer system for periodic triggers
- Subscribes to game events for event-based triggers
================================================================================
]]--

local WandTriggers = {}

-- Dependencies
local timer = require("core.timer")
local signal = require("external.hump.signal")

-- Active trigger registrations
WandTriggers.registrations = {}

-- Event subscriptions (for cleanup)
WandTriggers.eventSubscriptions = {}

-- Distance tracking for on_distance_traveled triggers
WandTriggers.distanceTracking = {}

-- Deferred event executions (processed outside physics callbacks)
WandTriggers.pendingEvents = {}

--[[
================================================================================
INITIALIZATION
================================================================================
]]--

--- Initializes the trigger system
function WandTriggers.init()
    WandTriggers.registrations = {}
    WandTriggers.eventSubscriptions = {}
    WandTriggers.distanceTracking = {}
    WandTriggers.pendingEvents = {}

    -- Subscribe to game events
    WandTriggers.subscribeToEvents()

    log_debug("WandTriggers initialized")
end

--- Cleans up the trigger system
function WandTriggers.cleanup()
    -- Cancel all timer-based triggers
    for wandId, registration in pairs(WandTriggers.registrations) do
        if registration.timerTag then
            timer.cancel(registration.timerTag)
        end
    end

    -- Remove signal listeners
    for eventName, handler in pairs(WandTriggers.eventSubscriptions) do
        signal.remove(eventName, handler)
    end

    -- Clear all registrations
    WandTriggers.registrations = {}
    WandTriggers.eventSubscriptions = {}
    WandTriggers.distanceTracking = {}
    WandTriggers.pendingEvents = {}

    log_debug("WandTriggers cleaned up")
end

--[[
================================================================================
TRIGGER REGISTRATION
================================================================================
]]--

--- Registers a trigger for a wand
--- @param wandId string Wand identifier
--- @param triggerDef table Trigger definition
--- @param executor function Function to call when trigger fires (usually WandExecutor.execute)
--- @param opts table|nil Optional { canCast = function():boolean }
function WandTriggers.register(wandId, triggerDef, executor, opts)
    opts = opts or {}
    if not wandId or not triggerDef then
        log_error("WandTriggers.register: missing wandId or triggerDef")
        return
    end

    -- Unregister existing trigger for this wand
    WandTriggers.unregister(wandId)

    local registration = {
        wandId = wandId,
        triggerType = triggerDef.id or triggerDef.type,
        triggerDef = triggerDef,
        executor = executor,
        canCast = opts.canCast,
        timerTag = nil,
        enabled = true,
    }

    -- Setup trigger based on type
    local triggerType = registration.triggerType

    if triggerType == "every_N_seconds" then
        WandTriggers.setupTimerTrigger(registration, triggerDef.interval or 1.0)

    elseif triggerType == "on_cooldown" then
        WandTriggers.setupCooldownTrigger(registration)

    elseif triggerType == "on_distance_traveled" then
        WandTriggers.setupDistanceTrigger(registration, triggerDef.distance or 100)

    -- Event-based triggers are handled via global event subscriptions
    elseif triggerType == "on_player_attack" then
        registration.eventType = triggerType

    elseif triggerType == "on_bump_enemy" then
        registration.eventType = triggerType

    elseif triggerType == "on_dash" then
        registration.eventType = triggerType

    elseif triggerType == "on_pickup" then
        registration.eventType = triggerType

    elseif triggerType == "on_low_health" then
        registration.eventType = triggerType
        registration.healthThreshold = triggerDef.healthThreshold or 0.3  -- 30%

    else
        log_debug("WandTriggers.register: unknown trigger type", triggerType)
    end

    WandTriggers.registrations[wandId] = registration

    log_debug("WandTriggers: Registered trigger", triggerType, "for wand", wandId)
end

--- Unregisters a trigger for a wand
--- @param wandId string Wand identifier
function WandTriggers.unregister(wandId)
    local registration = WandTriggers.registrations[wandId]
    if not registration then return end

    -- Cancel timer if exists
    if registration.timerTag then
        timer.cancel(registration.timerTag)
    end

    WandTriggers.registrations[wandId] = nil

    log_debug("WandTriggers: Unregistered trigger for wand", wandId)
end

--[[
================================================================================
TIMER-BASED TRIGGERS
================================================================================
]]--

--- Sets up a periodic timer trigger
--- @param registration table Trigger registration
--- @param interval number Interval in seconds
function WandTriggers.setupTimerTrigger(registration, interval)
    local wandId = registration.wandId
    local timerTag = "wand_trigger_" .. wandId

    timer.every(interval, function()
        if registration.enabled and registration.executor then
            log_debug("WandTriggers: Timer trigger fired for wand", wandId)
            registration.executor(wandId, "timer_trigger")
        end
    end, -1, false, nil, timerTag)  -- infinite repetitions

    registration.timerTag = timerTag
end

--- Sets up a cooldown-based trigger (fires when wand is off cooldown)
--- @param registration table Trigger registration
function WandTriggers.setupCooldownTrigger(registration)
    local wandId = registration.wandId
    local timerTag = "wand_trigger_cooldown_" .. wandId

    -- Check every frame if wand is off cooldown
    timer.cooldown(0.1, function()
        -- Check if wand can cast
        if not registration.enabled then return false end
        if registration.canCast then
            return registration.canCast(wandId)
        end
        return registration.executor ~= nil
    end, function()
        if registration.enabled and registration.executor then
            log_debug("WandTriggers: Cooldown trigger fired for wand", wandId)
            registration.executor(wandId, "cooldown_trigger")
        end
    end, -1, nil, timerTag)  -- infinite repetitions

    registration.timerTag = timerTag
end

--- Sets up a distance-traveled trigger
--- @param registration table Trigger registration
--- @param distance number Distance threshold in pixels
function WandTriggers.setupDistanceTrigger(registration, distance)
    local wandId = registration.wandId

    -- Initialize distance tracking
    WandTriggers.distanceTracking[wandId] = {
        totalDistance = 0,
        lastPosition = nil,
        threshold = distance,
    }

    -- No timer needed - updated in update()
end

--[[
================================================================================
EVENT-BASED TRIGGERS
================================================================================
]]--

--- Subscribes to game events
function WandTriggers.subscribeToEvents()
    local eventNames = {
        "on_player_attack",
        "on_bump_enemy",
        "on_dash",
        "on_pickup",
        "on_low_health",
    }

    for _, eventName in ipairs(eventNames) do
        local handler = function(eventData)
            WandTriggers.handleEvent(eventName, eventData)
        end

        signal.register(eventName, handler)
        WandTriggers.eventSubscriptions[eventName] = handler
    end

    log_debug("WandTriggers: Subscribed to game events via hump.signal")
end

--- Handles a game event
--- @param eventType string Event type
--- @param eventData table Event data
function WandTriggers.handleEvent(eventType, eventData)
    -- Check all registered triggers for this event type
    for wandId, registration in pairs(WandTriggers.registrations) do
        if registration.enabled and registration.eventType == eventType then
            -- Check additional conditions (not implemented for all triggers)
            local shouldFire = WandTriggers.checkEventCondition(registration, eventData)

            if shouldFire and registration.executor then
                log_debug("WandTriggers: Event trigger fired", eventType, "for wand", wandId)
                -- Queue execution so we run outside physics callbacks (Chipmunk spaces are locked there)
                local payload = {}
                if eventData then
                    for k, v in pairs(eventData) do
                        payload[k] = v
                    end
                end
                payload._source_event_type = eventType
                WandTriggers.queueEvent(wandId, registration.triggerType, payload)
            end
        end
    end
end

--- Checks if event-specific conditions are met
--- @param registration table Trigger registration
--- @param eventData table Event data
--- @return boolean True if should fire
function WandTriggers.checkEventCondition(registration, eventData)
    local triggerType = registration.triggerType

    -- Health threshold check
    if triggerType == "on_low_health" then
        local currentHealth = eventData.currentHealth or 100
        local maxHealth = eventData.maxHealth or 100
        local healthPercent = currentHealth / maxHealth

        return healthPercent <= (registration.healthThreshold or 0.3)
    end

    -- Default: always fire
    return true
end

--- Queues a trigger execution to run on the next update tick
--- This avoids spawning physics objects while Chipmunk space is locked (collision callbacks).
--- @param wandId string
--- @param eventType string
--- @param eventData table|nil
function WandTriggers.queueEvent(wandId, eventType, eventData)
    WandTriggers.pendingEvents[#WandTriggers.pendingEvents + 1] = {
        wandId = wandId,
        eventType = eventType,
        eventData = eventData,
    }
end

--- Processes queued event triggers
function WandTriggers.processPendingEvents()
    if #WandTriggers.pendingEvents == 0 then return end

    local queued = WandTriggers.pendingEvents
    WandTriggers.pendingEvents = {}

    for _, evt in ipairs(queued) do
        local registration = WandTriggers.registrations[evt.wandId]
        if registration and registration.enabled and registration.executor then
            registration.executor(evt.wandId, evt.eventType, evt.eventData)
        end
    end
end

--[[
================================================================================
UPDATE LOOP
================================================================================
]]--

--- Updates trigger system (called every frame)
--- @param dt number Delta time in seconds
--- @param playerEntity number Player entity ID (for distance tracking)
function WandTriggers.update(dt, playerEntity)
    -- Run any event triggers that were queued during physics callbacks
    WandTriggers.processPendingEvents()

    -- Update distance-traveled triggers
    WandTriggers.updateDistanceTriggers(playerEntity)
end

--- Updates distance-traveled triggers
--- @param playerEntity number Player entity ID
function WandTriggers.updateDistanceTriggers(playerEntity)
    if not playerEntity or not component_cache then return end

    local transform = component_cache.get(playerEntity, Transform)
    if not transform then return end

    local currentPos = {x = transform.actualX, y = transform.actualY}

    for wandId, tracking in pairs(WandTriggers.distanceTracking) do
        if tracking.lastPosition then
            -- Calculate distance moved
            local dx = currentPos.x - tracking.lastPosition.x
            local dy = currentPos.y - tracking.lastPosition.y
            local distance = math.sqrt(dx * dx + dy * dy)

            tracking.totalDistance = tracking.totalDistance + distance

            -- Check if threshold reached
            if tracking.totalDistance >= tracking.threshold then
                local registration = WandTriggers.registrations[wandId]
                if registration and registration.enabled and registration.executor then
                    log_debug("WandTriggers: Distance trigger fired for wand", wandId, "distance", tracking.totalDistance)
                    registration.executor(wandId, "distance_trigger")

                    -- Reset distance
                    tracking.totalDistance = 0
                end
            end
        end

        -- Update last position
        tracking.lastPosition = {x = currentPos.x, y = currentPos.y}
    end
end

--[[
================================================================================
TRIGGER CONTROL
================================================================================
]]--

--- Enables a trigger
--- @param wandId string Wand identifier
function WandTriggers.enable(wandId)
    local registration = WandTriggers.registrations[wandId]
    if registration then
        registration.enabled = true
        log_debug("WandTriggers: Enabled trigger for wand", wandId)
    end
end

--- Disables a trigger
--- @param wandId string Wand identifier
function WandTriggers.disable(wandId)
    local registration = WandTriggers.registrations[wandId]
    if registration then
        registration.enabled = false
        log_debug("WandTriggers: Disabled trigger for wand", wandId)
    end
end

--- Checks if a trigger is enabled
--- @param wandId string Wand identifier
--- @return boolean True if enabled
function WandTriggers.isEnabled(wandId)
    local registration = WandTriggers.registrations[wandId]
    return registration and registration.enabled or false
end

--[[
================================================================================
UTILITY FUNCTIONS
================================================================================
]]--

--- Gets trigger registration for a wand
--- @param wandId string Wand identifier
--- @return table|nil Trigger registration
function WandTriggers.getRegistration(wandId)
    return WandTriggers.registrations[wandId]
end

--- Gets all active trigger registrations
--- @return table Map of wandId -> registration
function WandTriggers.getAllRegistrations()
    return WandTriggers.registrations
end

--- Gets trigger display name for debugging
--- @param triggerType string Trigger type identifier
--- @return string Display name
function WandTriggers.getTriggerDisplayName(triggerType)
    local names = {
        every_N_seconds = "Every N Seconds",
        on_cooldown = "On Cooldown",
        on_player_attack = "On Player Attack",
        on_bump_enemy = "On Bump Enemy",
        on_dash = "On Dash",
        on_distance_traveled = "On Distance Traveled",
        on_pickup = "On Pickup",
        on_low_health = "On Low Health",
    }

    return names[triggerType] or triggerType
end

return WandTriggers
