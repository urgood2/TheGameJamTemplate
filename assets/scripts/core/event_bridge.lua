--[[
================================================================================
EVENT BRIDGE - Connects Combat Bus to Signal System
================================================================================
Automatically forwards combat system events (ctx.bus) to hump.signal so that
both old gameplay code (using ctx.bus:on) and new systems (using signal.register)
can listen to the same events.

WHY THIS EXISTS:
  - Combat system uses its own EventBus (ctx.bus:emit)
  - Wave system and other modules use hump.signal (signal.emit)
  - Without a bridge, events only reach listeners of their own system
  - This caused the "wave 2 never spawns" bug (OnDeath never reached wave_director)

USAGE:
    local EventBridge = require("core.event_bridge")

    -- After creating combat_context:
    EventBridge.attach(combat_context)

    -- Now any bridged event will be forwarded:
    -- ctx.bus:emit("OnDeath", data)  →  signal.emit("OnDeath", data)

ADDING NEW BRIDGES:
    Add entries to BRIDGED_EVENTS table below. Each entry maps:
    - bus_event: The event name from ctx.bus
    - signal_event: The signal name to emit (defaults to bus_event if nil)
    - transform: Optional function to transform data before forwarding

DESIGN PRINCIPLES:
    - One-way bridge: bus → signal (not bidirectional, to avoid loops)
    - Transparent: Original bus listeners still work
    - Minimal overhead: Only bridges explicitly listed events
    - Debuggable: Optional logging for troubleshooting

Dependencies: external.hump.signal
]]

local signal = require("external.hump.signal")

local EventBridge = {}

--============================================
-- BRIDGED EVENTS CONFIGURATION
--============================================
-- Add events here that need to be forwarded from combat bus to signal system.
--
-- Format:
--   { bus_event = "EventName", signal_event = "signal_name", transform = fn }
--
-- If signal_event is nil, uses bus_event name (with "On" prefix stripped and
-- converted to snake_case for consistency with signal conventions).
--
-- transform(data, entity) can modify the data before forwarding.

local BRIDGED_EVENTS = {
    -- NOTE: OnDeath is NOT bridged here because it requires special handling.
    -- The combat bus's data.entity is a combat ACTOR, not an entity ID.
    -- gameplay.lua handles this correctly by looking up combatActorToEntity[actor]
    -- and emitting signal.emit("enemy_killed", entityId) manually.
    -- See gameplay.lua ~line 5234.

    -- Enemy lifecycle
    {
        bus_event = "OnEnemySpawned",
        signal_event = "enemy_spawned",
    },

    -- Combat events (useful for UI, audio, achievements)
    {
        bus_event = "OnHitResolved",
        signal_event = "combat_hit",
    },
    {
        bus_event = "OnDodge",
        signal_event = "combat_dodge",
    },
    {
        bus_event = "OnMiss",
        signal_event = "combat_miss",
    },
    {
        bus_event = "OnCrit",
        signal_event = "combat_crit",
    },
    {
        bus_event = "OnHealed",
        signal_event = "combat_healed",
    },

    -- Status effects
    {
        bus_event = "OnStatusApplied",
        signal_event = "status_applied",
    },
    {
        bus_event = "OnStatusRemoved",
        signal_event = "status_removed",
    },
    {
        bus_event = "OnStatusExpired",
        signal_event = "status_expired",
    },

    -- Progression
    {
        bus_event = "OnLevelUp",
        signal_event = "player_level_up",
    },
    {
        bus_event = "OnExperienceGained",
        signal_event = "experience_gained",
    },

    -- Wave/combat state (if using WaveManager class)
    {
        bus_event = "OnWaveStart",
        signal_event = "wave_started",
    },
    {
        bus_event = "OnWaveComplete",
        signal_event = "wave_complete",
    },
    {
        bus_event = "OnAllWavesComplete",
        signal_event = "all_waves_complete",
    },
    {
        bus_event = "OnCombatStart",
        signal_event = "combat_started",
    },
    {
        bus_event = "OnCombatEnd",
        signal_event = "combat_ended",
    },

    -- Loot
    {
        bus_event = "OnLootDropped",
        signal_event = "loot_dropped",
    },
    {
        bus_event = "OnLootCollected",
        signal_event = "loot_collected",
    },
}

--============================================
-- DEBUG LOGGING
--============================================

local debug_enabled = false

local function debug_log(message, ...)
    if debug_enabled then
        print("[EventBridge] " .. string.format(message, ...))
    end
end

function EventBridge.enable_debug()
    debug_enabled = true
    print("[EventBridge] Debug logging enabled")
end

function EventBridge.disable_debug()
    debug_enabled = false
end

--============================================
-- BRIDGE ATTACHMENT
--============================================

--- Attach the event bridge to a combat context.
-- This should be called once after creating the combat_context.
-- @param ctx The combat context with ctx.bus (EventBus)
function EventBridge.attach(ctx)
    if not ctx or not ctx.bus then
        print("[EventBridge] ERROR: Invalid combat context (missing bus)")
        return false
    end

    if ctx._event_bridge_attached then
        debug_log("Already attached to this context, skipping")
        return true
    end

    local bridged_count = 0

    for _, bridge in ipairs(BRIDGED_EVENTS) do
        local bus_event = bridge.bus_event
        local signal_event = bridge.signal_event or bus_event
        local transform = bridge.transform

        ctx.bus:on(bus_event, function(data)
            debug_log("%s → %s", bus_event, signal_event)

            if transform then
                local transformed = transform(data)
                signal.emit(signal_event, transformed, data)
            else
                signal.emit(signal_event, data)
            end
        end)

        bridged_count = bridged_count + 1
    end

    ctx._event_bridge_attached = true
    print("[EventBridge] Attached " .. bridged_count .. " event bridges")

    return true
end

--============================================
-- UTILITIES
--============================================

--- Get list of all bridged events (for debugging/documentation)
function EventBridge.get_bridged_events()
    local events = {}
    for _, bridge in ipairs(BRIDGED_EVENTS) do
        table.insert(events, {
            bus = bridge.bus_event,
            signal = bridge.signal_event or bridge.bus_event,
        })
    end
    return events
end

--- Print all bridged events to console
function EventBridge.print_bridges()
    print("=== Event Bridge Mappings ===")
    for _, bridge in ipairs(BRIDGED_EVENTS) do
        local signal_event = bridge.signal_event or bridge.bus_event
        print(string.format("  ctx.bus:%s → signal.emit('%s')", bridge.bus_event, signal_event))
    end
    print("=============================")
end

return EventBridge
