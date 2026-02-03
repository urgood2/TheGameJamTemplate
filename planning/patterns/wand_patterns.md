# Wand Patterns

## pattern:wand.registry.lazy_load
**doc_id:** `pattern:wand.registry.lazy_load`
**Source:** `assets/scripts/wand/card_registry.lua:10`
**Frequency:** Found in 1 file

**Pattern:**
```lua
local cards_cache = nil
local trigger_cards_cache = nil

local function load_data()
    if cards_cache then return end
    local data = require("data.cards")
    cards_cache = data.Cards or {}
    trigger_cards_cache = data.TriggerCards or {}
end
```

**Preconditions:**
- `data.cards` module defines `Cards` and `TriggerCards`.
- Registry accessors call `load_data()` before reading caches.

**Unverified:** No direct tests for registry cache behavior.

---

## pattern:wand.behavior_registry.register_execute
**doc_id:** `pattern:wand.behavior_registry.register_execute`
**Source:** `assets/scripts/wand/card_behavior_registry.lua:62`
**Frequency:** Found in 1 file

**Pattern:**
```lua
BehaviorRegistry.behaviors[behaviorId] = {
    func = behaviorFunc,
    description = description or ""
}

local success, result = pcall(behavior.func, context)
if not success then
    return false, nil
end
return true, result
```

**Preconditions:**
- `BehaviorRegistry.behaviors` is initialized.
- Callers handle `false, nil` when execution fails.

**Unverified:** No direct tests for behavior registry execution.

---

## pattern:wand.modifiers.joker_effect_schema
**doc_id:** `pattern:wand.modifiers.joker_effect_schema`
**Source:** `assets/scripts/wand/wand_modifiers.lua:166`
**Frequency:** Found in 1 file

**Pattern:**
```lua
WandModifiers.JOKER_EFFECT_SCHEMA = {
    extra_pierce = { mode = "add", target = "pierceCount" },
}

function WandModifiers.applyJokerEffects(modifiers, jokerEffects)
    for field, value in pairs(jokerEffects) do
        local schema = WandModifiers.JOKER_EFFECT_SCHEMA[field]
        if schema then
            -- mutate modifiers in place using schema.target/mode
        end
    end
end
```

**Preconditions:**
- `createAggregate()` initializes all target fields with defaults.
- `applyJokerEffects()` runs before `WandActions.execute()` reads modifiers.

**Unverified:** No isolated tests for joker effect pipeline.

---

## pattern:wand.executor.subcast_trace
**doc_id:** `pattern:wand.executor.subcast_trace`
**Source:** `assets/scripts/wand/wand_executor.lua:47`
**Frequency:** Found in 1 file

**Pattern:**
```lua
local function makeSubcastTraceId(context, parent, triggerType)
    local wandId = context and (context.wandId or context.wandDefinition and context.wandDefinition.id) or "wand"
    local blockIdx = parent and parent.blockIndex or "?"
    local cardIdx = parent and parent.cardIndex or "?"
    local trigger = triggerType or "sub"
    return string.format("%s-%s-%s-%s-%.3f", tostring(wandId), tostring(blockIdx), tostring(cardIdx), tostring(trigger), os.clock())
end

local function emitSubcastDebug(stage, payload)
    if not DEBUG_SUBCAST then return end
    payload.stage = stage
    payload.timestamp = os.clock()
    if okSignal and signal and signal.emit then
        signal.emit("debug_subcast", payload)
    end
end
```

**Preconditions:**
- `DEBUG_SUBCAST` global defaults to true or is set by caller.
- `external.hump.signal` is optional; debug emits only when available.

**Unverified:** No tests for debug tracing pipeline.

---

## pattern:wand.triggers.register_cleanup
**doc_id:** `pattern:wand.triggers.register_cleanup`
**Source:** `assets/scripts/wand/wand_triggers.lua:63`
**Frequency:** Found in 1 file

**Pattern:**
```lua
function WandTriggers.cleanup()
    for _, registration in pairs(WandTriggers.registrations) do
        if registration.timerTag then
            timer.cancel(registration.timerTag)
        end
    end
    for eventName, handler in pairs(WandTriggers.eventSubscriptions) do
        signal.remove(eventName, handler)
    end
end

function WandTriggers.register(wandId, triggerDef, executor, opts)
    WandTriggers.unregister(wandId)
    local registration = {
        wandId = wandId,
        triggerType = triggerDef.id or triggerDef.type,
        triggerDef = triggerDef,
        executor = executor,
        timerTag = nil,
    }
end
```

**Preconditions:**
- `core.timer` and `external.hump.signal` are available.
- `WandTriggers.unregister` cancels prior timers for the wand.

**Unverified:** No automated tests for trigger registration/cleanup.
