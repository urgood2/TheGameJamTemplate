--[[
================================================================================
DEMO BOT - AI Entity Type for GOAP AI System Demo
================================================================================
A demonstration entity that showcases the GOAP AI improvements:
- Multiple competing goals with different bands
- Goal selection with hysteresis (persist)
- Plan building and action execution
- Trace buffer logging visible in AI Inspector

Goals:
- PATROL (WORK band): Walk between waypoints
- IDLE (IDLE band): Stand in place with idle animation
- ALERT (COMBAT band): High priority when "threat" detected
- REST (SURVIVAL band): Triggered when "tired" is true
]]

return {
    initial = {
        -- Patrol state
        patrolling = false,
        patrol_complete = false,

        -- Alert state
        threat_detected = false,
        alert_complete = false,

        -- Rest state
        tired = false,
        rested = true,

        -- Idle state
        idle = false
    },
    goal = {
        -- Default goal: complete a patrol
        patrolling = true
    }
}
