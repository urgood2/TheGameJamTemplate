# Wand Patterns (Working Code)

Scope: Wand/card system patterns under assets/scripts/wand/.
Each pattern includes a doc_id, source_ref(s), and verification status.

## pattern:wand.registry.lazy_load
- Name: Card registry lazy-load caching
- Description: CardRegistry lazily requires data.cards on first access, caches cards and trigger cards, and provides helper getters by id and tag.
- Source refs:
  - assets/scripts/wand/card_registry.lua:8 (load_data + caches)
- Recommended: Yes
- Unverified: Reason: no direct tests for registry cache behavior

## pattern:wand.behavior_registry.register_execute
- Name: Behavior registry register/execute with pcall
- Description: BehaviorRegistry stores behavior functions keyed by id, and executes them with pcall while returning success and result.
- Source refs:
  - assets/scripts/wand/card_behavior_registry.lua:33 (register/execute)
- Recommended: Yes
- Unverified: Reason: no direct tests for behavior registry execution

## pattern:wand.modifiers.joker_effect_schema
- Name: Joker effects mutate modifier table in place
- Description: Joker effects are mapped via a schema to modifier fields; applyJokerEffects mutates the shared modifiers table before wand_actions reads it.
- Source refs:
  - assets/scripts/wand/wand_modifiers.lua:1 (JOKER_EFFECT_SCHEMA and flow comments)
- Recommended: Yes
- Unverified: Reason: no isolated tests for joker effect pipeline

## pattern:wand.executor.subcast_trace
- Name: Sub-cast tracing with stable ids
- Description: WandExecutor builds a trace id using wand id, block index, card index, trigger, and os.clock; emitSubcastDebug logs and optionally signals debug events.
- Source refs:
  - assets/scripts/wand/wand_executor.lua:24 (makeSubcastTraceId, emitSubcastDebug)
- Recommended: Yes
- Unverified: Reason: no tests for debug tracing pipeline

## pattern:wand.triggers.register_cleanup
- Name: Trigger registration with timer/signal cleanup
- Description: WandTriggers registers triggers per wand, sets timer tags or event types, and cleanup cancels timers and removes signal listeners.
- Source refs:
  - assets/scripts/wand/wand_triggers.lua:46 (register + cleanup)
- Recommended: Yes
- Unverified: Reason: no automated tests for trigger registration
