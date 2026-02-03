# Wand Patterns

## pattern:wand.registry.lazy_load
**doc_id:** `pattern:wand.registry.lazy_load`
**Source:** assets/scripts/wand/card_registry.lua:14
**Frequency:** Found in 1 file

**Pattern:**
```lua
local function load_data()
    if cards_cache then return end
    local data = require("data.cards")
    cards_cache = data.Cards or {}
    trigger_cards_cache = data.TriggerCards or {}
end
```

**Preconditions:**
- `data.cards` defines `Cards` and optional `TriggerCards`

**Unverified:** No dedicated pattern test (registry caching used by runtime).

---

## pattern:wand.behavior_registry.register_execute
**doc_id:** `pattern:wand.behavior_registry.register_execute`
**Source:** assets/scripts/wand/card_behavior_registry.lua:58; assets/scripts/wand/card_behavior_registry.lua:84
**Frequency:** Found in 1 file

**Pattern:**
```lua
function BehaviorRegistry.register(behaviorId, behaviorFunc, description)
    BehaviorRegistry.behaviors[behaviorId] = {
        func = behaviorFunc,
        description = description or ""
    }
end

function BehaviorRegistry.execute(behaviorId, context)
    local behavior = BehaviorRegistry.behaviors[behaviorId]
    if not behavior then return false, nil end
    local success, result = pcall(behavior.func, context)
    if not success then return false, nil end
    return true, result
end
```

**Preconditions:**
- Behavior ids are registered before execution
- Caller supplies a context table understood by the behavior

**Unverified:** No dedicated pattern test (behavior registry used by runtime).

---

## pattern:wand.modifiers.joker_effect_schema
**doc_id:** `pattern:wand.modifiers.joker_effect_schema`
**Source:** assets/scripts/wand/wand_modifiers.lua:166; assets/scripts/wand/wand_modifiers.lua:204
**Frequency:** Found in 1 file

**Pattern:**
```lua
WandModifiers.JOKER_EFFECT_SCHEMA = {
    extra_pierce = { mode = "add", target = "pierceCount" },
}

function WandModifiers.applyJokerEffects(modifiers, jokerEffects)
    local schema = WandModifiers.JOKER_EFFECT_SCHEMA[field]
    local target = schema and schema.target or field
    modifiers[target] = (modifiers[target] or 0) + value
end
```

**Preconditions:**
- Modifier aggregate has defaults for target fields
- Joker effects are numeric (non-numeric fields are ignored)

**Unverified:** No dedicated pattern test (joker pipeline exercised in runtime).

---

## pattern:wand.executor.subcast_trace
**doc_id:** `pattern:wand.executor.subcast_trace`
**Source:** assets/scripts/wand/wand_executor.lua:47; assets/scripts/wand/wand_executor.lua:57
**Frequency:** Found in 1 file

**Pattern:**
```lua
local function makeSubcastTraceId(context, parent, triggerType)
    return string.format("%s-%s-%s-%s-%.3f", wandId, blockIdx, cardIdx, trigger, os.clock())
end

local function emitSubcastDebug(stage, payload)
    payload.stage = stage
    payload.timestamp = os.clock()
    print(table.concat(parts, " "))
end
```

**Preconditions:**
- Debug logging enabled via `DEBUG_SUBCAST`
- Call sites supply parent/block metadata for trace correlation

**Unverified:** No dedicated pattern test (debug tracing used during runtime).

---

## pattern:wand.executor.subcast_queue
**doc_id:** `pattern:wand.executor.subcast_queue`
**Source:** assets/scripts/wand/wand_executor.lua:830; assets/scripts/wand/wand_executor.lua:977; assets/scripts/wand/wand_executor.lua:991
**Frequency:** Found in 1 file

**Pattern:**
```lua
if childInfo.delay and childInfo.delay > 0 then
    timer.after(delaySeconds, function()
        WandExecutor.enqueueSubCast({ block = childInfo.block, context = context })
    end, "wand_subcast_" .. context.wandId .. "_" .. os.clock())
end

function WandExecutor.enqueueSubCast(payload)
    WandExecutor.pendingSubCasts[#WandExecutor.pendingSubCasts + 1] = payload
end

function WandExecutor.processPendingSubCasts()
    local queue = WandExecutor.pendingSubCasts
    WandExecutor.pendingSubCasts = {}
    for _, payload in ipairs(queue) do
        WandExecutor.executeSubCast(payload.block, payload.context or {}, payload.inheritedModifiers, payload.meta)
    end
end
```

**Preconditions:**
- `WandExecutor.update()` is called to flush the pending queue
- `timer.after` is available for delayed sub-casts

**Unverified:** No dedicated pattern test (sub-cast scheduling validated in runtime).

---

## pattern:wand.triggers.register_cleanup
**doc_id:** `pattern:wand.triggers.register_cleanup`
**Source:** assets/scripts/wand/wand_triggers.lua:92; assets/scripts/wand/wand_triggers.lua:63
**Frequency:** Found in 1 file

**Pattern:**
```lua
function WandTriggers.register(wandId, triggerDef, executor, opts)
    WandTriggers.unregister(wandId)
    WandTriggers.registrations[wandId] = registration
end

function WandTriggers.cleanup()
    timer.cancel(registration.timerTag)
    signal.remove(eventName, handler)
end
```

**Preconditions:**
- Timer and signal systems are available
- Registration uses stable wand ids per trigger

**Unverified:** No dedicated pattern test (triggers validated in runtime).

---

## pattern:wand.joker_system.aggregate_effects
**doc_id:** `pattern:wand.joker_system.aggregate_effects`
**Source:** assets/scripts/wand/joker_system.lua:42
**Frequency:** Found in 1 file

**Pattern:**
```lua
function JokerSystem.trigger_event(event_name, context)
    local aggregate = { messages = {} }
    local schema = WandModifiers.JOKER_EFFECT_SCHEMA

    for _, joker in ipairs(JokerSystem.jokers) do
        local result = joker:calculate(context)
        for field, value in pairs(result or {}) do
            if field == "message" then
                table.insert(aggregate.messages, { joker = joker.name, text = value })
            elseif type(value) == "number" then
                local mode = (schema[field] and schema[field].mode) or "add"
                aggregate[field] = (aggregate[field] or 0) + value
            elseif type(value) == "table" then
                aggregate[field] = aggregate[field] or {}
                table.insert(aggregate[field], value)
            elseif type(value) == "boolean" and value then
                aggregate[field] = true
            end
        end
    end

    return aggregate
end
```

**Preconditions:**
- Joker definitions expose `calculate` and return effect payloads
- `WandModifiers.JOKER_EFFECT_SCHEMA` defines aggregation modes

**Unverified:** No dedicated pattern test (joker effects validated in runtime).

---

## pattern:wand.synergy.tag_set_thresholds
**doc_id:** `pattern:wand.synergy.tag_set_thresholds`
**Source:** assets/scripts/wand/card_synergy_system.lua:81; assets/scripts/wand/card_synergy_system.lua:306
**Frequency:** Found in 1 file

**Pattern:**
```lua
CardSynergy.setBonuses = {
    mobility = { [3] = { cast_speed = 10 }, [6] = { cast_speed = 25 } },
}

function CardSynergy.getActiveTier(tagName, count)
    local bonuses = CardSynergy.setBonuses[tagName]
    for threshold, _ in pairs(bonuses or {}) do
        if count >= threshold then activeTier = threshold end
    end
    return activeTier
end
```

**Preconditions:**
- Card tags use the same keys as `setBonuses`
- Tier thresholds are numeric and ascending

**Unverified:** No dedicated pattern test (tag sets validated in runtime/UI).

---

## pattern:wand.synergy.curated_combo_detection
**doc_id:** `pattern:wand.synergy.curated_combo_detection`
**Source:** assets/scripts/wand/card_synergy_system.lua:270
**Frequency:** Found in 1 file

**Pattern:**
```lua
function CardSynergy.detectCuratedCombos(cardList)
    local cardIds = {}
    for _, card in ipairs(cardList) do
        cardIds[card.id] = true
    end

    for comboId, comboDef in pairs(CardSynergy.curatedCombos) do
        local hasAllCards = true
        for _, requiredCardId in ipairs(comboDef.cards) do
            if not cardIds[requiredCardId] then hasAllCards = false end
        end
        if hasAllCards then table.insert(activeCombos, comboId) end
    end

    return activeCombos
end
```

**Preconditions:**
- Curated combo definitions list required card ids
- Cards supply `.id` fields

**Unverified:** No dedicated pattern test (combo detection validated in runtime/UI).

---

## pattern:wand.tag_evaluator.count_tags_normalized
**doc_id:** `pattern:wand.tag_evaluator.count_tags_normalized`
**Source:** assets/scripts/wand/tag_evaluator.lua:90; assets/scripts/wand/tag_evaluator.lua:106
**Frequency:** Found in 1 file

**Pattern:**
```lua
local function normalize_tag_name(tag)
    local trimmed = tag:match("^%s*(.-)%s*$")
    return trimmed:sub(1, 1):upper() .. trimmed:sub(2)
end

function TagEvaluator.count_tags(deck)
    for _, card in ipairs(deck.cards or {}) do
        for _, tag in ipairs(card.tags or {}) do
            local normalized = normalize_tag_name(tag)
            counts[normalized] = (counts[normalized] or 0) + 1
        end
    end
end
```

**Preconditions:**
- Cards expose `tags` as an array or map of tags
- Tags are strings (non-strings are ignored)

**Unverified:** No dedicated pattern test (tag counts validated in runtime).

---

## pattern:wand.tag_evaluator.apply_thresholds
**doc_id:** `pattern:wand.tag_evaluator.apply_thresholds`
**Source:** assets/scripts/wand/tag_evaluator.lua:142
**Frequency:** Found in 1 file

**Pattern:**
```lua
function TagEvaluator.evaluate_and_apply(player, deck_snapshot, ctx)
    local tag_counts = TagEvaluator.count_tags(deck_snapshot)
    local TagDiscoverySystem = require("wand.tag_discovery_system")
    TagDiscoverySystem.checkTagThresholds(player, tag_counts)

    for tag, breakpoints in pairs(TAG_BREAKPOINTS) do
        local count = tag_counts[tag] or 0
        for threshold, bonus in pairs(breakpoints) do
            if count >= threshold then
                TagEvaluator.apply_bonus(player, bonus, ctx)
            else
                TagEvaluator.remove_bonus(player, bonus, ctx)
            end
        end
    end
end
```

**Preconditions:**
- `TAG_BREAKPOINTS` defines stat/proc unlocks
- `TagDiscoverySystem` is available for threshold events

**Unverified:** No dedicated pattern test (tag bonuses validated in runtime).

---

## pattern:wand.spell_type.classification
**doc_id:** `pattern:wand.spell_type.classification`
**Source:** assets/scripts/wand/spell_type_evaluator.lua:20
**Frequency:** Found in 1 file

**Pattern:**
```lua
function SpellTypeEvaluator.evaluate(block)
    if #block.actions == 1 and (mods.multicastCount or 1) == 1 then
        return SpellTypeEvaluator.Types.SIMPLE
    elseif #block.actions >= 3 then
        return SpellTypeEvaluator.Types.MONO
    end
    return SpellTypeEvaluator.Types.CHAOS
end
```

**Preconditions:**
- Cast block includes `.actions` and `.modifiers`
- Modifiers include multicast/spread fields

**Unverified:** No dedicated pattern test (spell type logic validated in runtime/UI).

---

## pattern:wand.spell_type.tag_analysis
**doc_id:** `pattern:wand.spell_type.tag_analysis`
**Source:** assets/scripts/wand/spell_type_evaluator.lua:135
**Frequency:** Found in 1 file

**Pattern:**
```lua
function SpellTypeEvaluator.analyzeTags(actions)
    local tagCounts = {}
    for _, action in ipairs(actions) do
        for _, tag in ipairs(action.tags or {}) do
            tagCounts[tag] = (tagCounts[tag] or 0) + 1
        end
    end
    return {
        tag_counts = tagCounts,
        primary_tag = primaryTag,
        diversity = diversity,
    }
end
```

**Preconditions:**
- Action cards supply `tags` arrays

**Unverified:** No dedicated pattern test (tag analysis used by joker logic/tests).

---

## pattern:wand.upgrade.paths_and_custom_behaviors
**doc_id:** `pattern:wand.upgrade.paths_and_custom_behaviors`
**Source:** assets/scripts/wand/card_upgrade_system.lua:42; assets/scripts/wand/card_upgrade_system.lua:206; assets/scripts/wand/card_upgrade_system.lua:297
**Frequency:** Found in 1 file

**Pattern:**
```lua
CardUpgrade.upgradePaths = {
    ACTION_BASIC_PROJECTILE = { [1] = { damage = 10 }, [2] = { damage = 15 } }
}

CardUpgrade.customBehaviors = {
    ACTION_BASIC_PROJECTILE = { [3] = { on_hit_explosion = { enabled = true } } }
}

function CardUpgrade.upgradeCard(card)
    local newStats = CardUpgrade.upgradePaths[card.id][newLevel]
    for statName, value in pairs(newStats) do card[statName] = value end

    local customBehavior = CardUpgrade.customBehaviors[card.id]
    for behaviorId, params in pairs(customBehavior[newLevel] or {}) do
        card.custom_behaviors[behaviorId] = params
    end
end
```

**Preconditions:**
- Cards have `id`, `level`, and `custom_behaviors` storage
- Upgrade paths include a definition for each level

**Unverified:** No dedicated pattern test (upgrade behavior validated in runtime/UI).

---

## pattern:wand.discovery.tag_thresholds
**doc_id:** `pattern:wand.discovery.tag_thresholds`
**Source:** assets/scripts/wand/tag_discovery_system.lua:79
**Frequency:** Found in 1 file

**Pattern:**
```lua
function TagDiscoverySystem.checkTagThresholds(player, tag_counts)
    for tag, count in pairs(tag_counts or {}) do
        for _, threshold in ipairs(DISCOVERY_THRESHOLDS) do
            if count >= threshold and not discoveries[discoveryKey] then
                discoveries[discoveryKey] = { tag = tag, threshold = threshold }
                table.insert(newDiscoveries, { tag = tag, threshold = threshold, count = count })
            end
        end
    end
    return newDiscoveries
end
```

**Preconditions:**
- Player (or entity id) is resolvable for discovery storage
- Thresholds list matches TagEvaluator breakpoints

**Unverified:** No dedicated pattern test (discovery events validated in runtime/UI).

---

## pattern:wand.actions.execution_context
**doc_id:** `pattern:wand.actions.execution_context`
**Source:** assets/scripts/wand/wand_actions.lua:182
**Frequency:** Found in 1 file

**Pattern:**
```lua
function WandActions.buildExecutionContext(casterEntity, opts)
    local faction = opts.faction or "player"
    local position = opts.position or { x = 0, y = 0 }
    return {
        casterEntity = casterEntity,
        faction = faction,
        playerPosition = position,
        playerAngle = opts.angle or 0,
    }
end
```

**Preconditions:**
- `casterEntity` is a valid entity id
- `component_cache` is available if position is not provided

**Unverified:** No dedicated pattern test (buildExecutionContext has unit tests but not pattern-specific).

---

## pattern:wand.actions.upgrade_behaviors
**doc_id:** `pattern:wand.actions.upgrade_behaviors`
**Source:** assets/scripts/wand/wand_actions.lua:68; assets/scripts/wand/wand_actions.lua:140
**Frequency:** Found in 1 file

**Pattern:**
```lua
local function collectUpgradeBehaviors(card)
    local behaviors = CardUpgrade.getCustomBehaviors(card)
    for behaviorId, params in pairs(behaviors) do
        if params and params.enabled ~= false then
            active[behaviorId] = params
        end
    end
    return next(active) and active or nil
end

local function runUpgradeBehaviors(event, behaviors, payload)
    for behaviorId, params in pairs(behaviors or {}) do
        if params.behavior_id and BehaviorRegistry.has(params.behavior_id) then
            BehaviorRegistry.execute(params.behavior_id, payload)
        elseif behaviorId == "on_hit_explosion" then
            triggerExplosionFromBehavior(payload.projectile, params)
        end
    end
end
```

**Preconditions:**
- `CardUpgrade.getCustomBehaviors` returns behavior maps
- `BehaviorRegistry` registered for behavior_id-driven hooks

**Unverified:** No dedicated pattern test (upgrade behaviors validated in runtime/tests).
