# Combat Components

Scope: ECS combat-related components extracted from C++ headers.

Key considerations:
- Most combat components are data-only and used by composable mechanics systems.
- Many types are intermediate structs for combat math and event dispatch; treat as read-only unless documented.
- Lua accessibility varies; verify before mutating from scripts.

## Tiered Documentation
- **Tier 0**: name + location + Lua access (extracted listing below).
- **Tier 1**: fields + writability + common patterns for high-frequency components.
- **Tier 2**: verified test id + gotchas.

## Combat System Notes
- Buff stacking uses `stackingKey` to group unique and replace policies in `BuffInstance`.
- `DamageBundle` carries per-type flat damage and a `DmgTag_*` bitmask for weapon and skill tagging.
- `Stats` uses base, add, mul arrays and caches `final` after recompute. When mutating base or modifiers, recompute final values.
- `Ability` cooldown fields are runtime and updated by `AbilitySystem.tickCooldowns`.

## High-Frequency Components (Tier 1)
- `Stats` — Detail Tier: 1. Layered stat storage with `base`, `add`, `mul`, and cached `final`.
  - Gotchas: Call `RecomputeFinal` after modifying base or modifiers.
- `BuffInstance` — Detail Tier: 1. Active buff state with duration, stacks, and stacking policy.
  - Gotchas: `add` and `mul` arrays exist in C++ but are complex types and omitted from Tier 0 extraction.
- `DamageBundle` — Detail Tier: 1. Damage package with `weaponScalar`, per-type flat array, and `tags`.
  - Gotchas: Flat array is per `DamageType`, not exposed in Tier 0 extraction.
- `Ability` — Detail Tier: 1. Ability definition with trigger predicate, target collection, and effect graph.
  - Gotchas: Function fields are C++ callbacks and are not expected to be mutated in Lua.

## Doc Divergences
- Card system components are not present in `src/systems/composable_mechanics` headers and are likely defined in other categories.

## Low Confidence Items
- AbilityDatabase (unordered_map and helper methods)
- CompiledEffectGraph (complex graph structure)

## Tests
- `combat.components.smoke` → `component:BuffInstance`, `component:Stats`, `component:DamageBundle`, `component:Ability`
- `combat.components.buffinstance.read_write` → `component:BuffInstance`
- `combat.components.stats.read_write` → `component:Stats`
- `combat.components.damagebundle.read_write` → `component:DamageBundle`
- `combat.components.ability.cooldowns` → `component:Ability`

## LuaContentLoader
**doc_id:** `component:LuaContentLoader`
**Location:** `src/systems/composable_mechanics/loader_lua.hpp:11`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## HitResult
**doc_id:** `component:HitResult`
**Location:** `src/systems/composable_mechanics/combat_math.hpp:7`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| pth | float | 0.f |  |
| damageScalar | float | 1.f |  |
| critChance | float | 0.f |  |
| critMultiplier | float | 1.f |  |

## Event
**doc_id:** `component:Event`
**Location:** `src/systems/composable_mechanics/events.hpp:24`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| type | EventType | None |  |
| source | entt::entity | entt::null |  |
| primaryTarget | entt::entity | entt::null |  |
| damage | DamageBundle* | nullptr |  |

## Context
**doc_id:** `component:Context`
**Location:** `src/systems/composable_mechanics/events.hpp:32`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## EventListener
**doc_id:** `component:EventListener`
**Location:** `src/systems/composable_mechanics/events.hpp:38`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| lane | int | 0 |  |
| priority | int | 0 |  |
| tieBreak | int | 0 |  |

## Ability
**doc_id:** `component:Ability`
**Location:** `src/systems/composable_mechanics/ability.hpp:13`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| name | Sid | 0 |  |
| triggerPredicate | TriggerPredicate | None |  |
| collectTargets | TargetFunc | None |  |
| effectGraph | CompiledEffectGraph | None |  |
| cooldownSec | float | 0.f |  |
| cooldownLeft | float | 0.f |  |
| internalCooldownSec | float | 0.f |  |
| internalCooldownLeft | float | 0.f |  |

## AbilityDatabase
**doc_id:** `component:AbilityDatabase`
**Location:** `src/systems/composable_mechanics/ability.hpp:26`
**Lua Access:** `TBD (verify in bindings)`
**Notes:** 1 complex types need manual review

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| byId | std::unordered_map<Sid, Ability> | None | complex |
| it | auto | byId.find(id) |  |
| it | return | = byId.end() ? nullptr : &it->second |  |

## EngineBootstrap
**doc_id:** `component:EngineBootstrap`
**Location:** `src/systems/composable_mechanics/bootstrap.hpp:7`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| abilityDb | AbilityDatabase | None |  |
| bus | auto | world.ctx().emplace<EventBus>() |  |

## Op_ModifyStats_Params
**doc_id:** `component:Op_ModifyStats_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:34`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## Op_DealDamage_Params
**doc_id:** `component:Op_DealDamage_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:40`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| weaponScalar | float | 1.0f |  |
| tags | uint32_t | DmgTag_IsSkill |  |

## Op_ApplyStatus_Params
**doc_id:** `component:Op_ApplyStatus_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:46`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## Op_ApplyRR_Params
**doc_id:** `component:Op_ApplyRR_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:48`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## EffectOp
**doc_id:** `component:EffectOp`
**Location:** `src/systems/composable_mechanics/effects.hpp:50`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| code | EffectOpCode | EffectOpCode::NoOp |  |
| firstChild | uint16_t | 0 |  |
| childCount | uint16_t | 0 |  |
| paramIndex | int | -1 |  |

## Op_Repeat_Params
**doc_id:** `component:Op_Repeat_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:61`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## Op_LimitPerTurn_Params
**doc_id:** `component:Op_LimitPerTurn_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:62`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## Op_PushUnit_Params
**doc_id:** `component:Op_PushUnit_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:64`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## Op_ShuffleAllies_Params
**doc_id:** `component:Op_ShuffleAllies_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:65`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## Op_TransformUnit_Params
**doc_id:** `component:Op_TransformUnit_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:67`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## Op_SummonUnit_Params
**doc_id:** `component:Op_SummonUnit_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:68`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## Op_CopyAbilityFrom_Params
**doc_id:** `component:Op_CopyAbilityFrom_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:70`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## Op_Item_Params
**doc_id:** `component:Op_Item_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:71`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## Op_ModifyPlayerResource_Params
**doc_id:** `component:Op_ModifyPlayerResource_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:73`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## Op_SetLevel_Params
**doc_id:** `component:Op_SetLevel_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:75`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## Op_GiveExperience_Params
**doc_id:** `component:Op_GiveExperience_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:76`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## Op_ShopAddItem_Params
**doc_id:** `component:Op_ShopAddItem_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:78`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## Op_ShopDiscountUnit_Params
**doc_id:** `component:Op_ShopDiscountUnit_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:79`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## Op_ShopDiscountItem_Params
**doc_id:** `component:Op_ShopDiscountItem_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:80`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## Op_ShopRoll_Params
**doc_id:** `component:Op_ShopRoll_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:81`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## Op_ShopReplaceItems_Params
**doc_id:** `component:Op_ShopReplaceItems_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:82`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## Op_StatSwapWithin_Params
**doc_id:** `component:Op_StatSwapWithin_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:84`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## Op_StatSwapBetween_Params
**doc_id:** `component:Op_StatSwapBetween_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:85`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## Op_StatCopyFrom_Params
**doc_id:** `component:Op_StatCopyFrom_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:86`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## Op_ClassifyAdd_Params
**doc_id:** `component:Op_ClassifyAdd_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:88`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## Op_TakeLessDamageOneShot_Params
**doc_id:** `component:Op_TakeLessDamageOneShot_Params`
**Location:** `src/systems/composable_mechanics/effects.hpp:90`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## CompiledEffectGraph
**doc_id:** `component:CompiledEffectGraph`
**Location:** `src/systems/composable_mechanics/effects.hpp:94`
**Lua Access:** `TBD (verify in bindings)`
**Notes:** 26 complex types need manual review

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| ops | std::vector<EffectOp> | None | complex |
| modParams | std::vector<Op_ModifyStats_Params> | None | complex |
| dmgParams | std::vector<Op_DealDamage_Params> | None | complex |
| statusParams | std::vector<Op_ApplyStatus_Params> | None | complex |
| rrParams | std::vector<Op_ApplyRR_Params> | None | complex |
| repParams | std::vector<Op_Repeat_Params> | None | complex |
| lptParams | std::vector<Op_LimitPerTurn_Params> | None | complex |
| pushParams | std::vector<Op_PushUnit_Params> | None | complex |
| shuffleParams | std::vector<Op_ShuffleAllies_Params> | None | complex |
| transformParams | std::vector<Op_TransformUnit_Params> | None | complex |
| summonParams | std::vector<Op_SummonUnit_Params> | None | complex |
| copyAbilityParams | std::vector<Op_CopyAbilityFrom_Params> | None | complex |
| itemParams | std::vector<Op_Item_Params> | None | complex |
| playerResParams | std::vector<Op_ModifyPlayerResource_Params> | None | complex |
| setLevelParams | std::vector<Op_SetLevel_Params> | None | complex |
| giveXpParams | std::vector<Op_GiveExperience_Params> | None | complex |
| shopAddItemParams | std::vector<Op_ShopAddItem_Params> | None | complex |
| shopDiscUnitParams | std::vector<Op_ShopDiscountUnit_Params> | None | complex |
| shopDiscItemParams | std::vector<Op_ShopDiscountItem_Params> | None | complex |
| shopRollParams | std::vector<Op_ShopRoll_Params> | None | complex |
| shopReplaceParams | std::vector<Op_ShopReplaceItems_Params> | None | complex |
| swapWithinParams | std::vector<Op_StatSwapWithin_Params> | None | complex |
| swapBetweenParams | std::vector<Op_StatSwapBetween_Params> | None | complex |
| statCopyParams | std::vector<Op_StatCopyFrom_Params> | None | complex |
| classAddParams | std::vector<Op_ClassifyAdd_Params> | None | complex |
| nhmParams | std::vector<Op_TakeLessDamageOneShot_Params> | None | complex |

## EngineServices
**doc_id:** `component:EngineServices`
**Location:** `src/systems/composable_mechanics/effects.hpp:149`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## DamageBundle
**doc_id:** `component:DamageBundle`
**Location:** `src/systems/composable_mechanics/stats.hpp:47`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| weaponScalar | float | 1.0f |  |
| tags | uint32_t | DmgTag_None |  |

## ResistPack
**doc_id:** `component:ResistPack`
**Location:** `src/systems/composable_mechanics/stats.hpp:56`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## ShieldStats
**doc_id:** `component:ShieldStats`
**Location:** `src/systems/composable_mechanics/stats.hpp:65`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| blockChance | float | 0.0f |  |
| blockAmount | float | 0.0f |  |
| recoveryTimeSec | float | 0.0f |  |
| recoveryLeftSec | float | 0.0f |  |

## Stats
**doc_id:** `component:Stats`
**Location:** `src/systems/composable_mechanics/stats.hpp:73`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## LifeEnergy
**doc_id:** `component:LifeEnergy`
**Location:** `src/systems/composable_mechanics/stats.hpp:95`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| hp | float | 0.f, maxHp = 0.f |  |
| energy | float | 0.f, maxEnergy = 0.f |  |

## Team
**doc_id:** `component:Team`
**Location:** `src/systems/composable_mechanics/stats.hpp:101`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| teamId | uint8_t | 0 |  |

## BoardPos
**doc_id:** `component:BoardPos`
**Location:** `src/systems/composable_mechanics/board.hpp:10`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| lane | int | 0 |  |
| index | int | -1 |  |

## BoardHelpers
**doc_id:** `component:BoardHelpers`
**Location:** `src/systems/composable_mechanics/board.hpp:19`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| pa | auto* | r.try_get<BoardPos>(e) |  |
| view | auto | r.view<BoardPos, Team>() |  |
| ta | auto* | r.try_get<Team>(e) |  |
| best | entt::entity | entt::null |  |
| best | return | None |  |
| pa | auto* | r.try_get<BoardPos>(e) |  |
| ta | auto* | r.try_get<Team>(e) |  |
| start | int | pa->index + 1 |  |
| view | auto | r.view<BoardPos, Team>() |  |
| want | int | start + k |  |
| pa | auto* | r.try_get<BoardPos>(e) |  |
| ta | auto* | r.try_get<Team>(e) |  |
| view | auto | r.view<BoardPos, Team>() |  |

## BuffInstance
**doc_id:** `component:BuffInstance`
**Location:** `src/systems/composable_mechanics/components.hpp:7`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| id | Sid | 0 |  |
| timeLeftSec | float | 0.f |  |
| stacks | uint8_t | 1 |  |
| stackingKey | Sid | 0 |  |

## ActiveBuffs
**doc_id:** `component:ActiveBuffs`
**Location:** `src/systems/composable_mechanics/components.hpp:18`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## AbilityRef
**doc_id:** `component:AbilityRef`
**Location:** `src/systems/composable_mechanics/components.hpp:21`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## KnownAbilities
**doc_id:** `component:KnownAbilities`
**Location:** `src/systems/composable_mechanics/components.hpp:22`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## StatusFlags
**doc_id:** `component:StatusFlags`
**Location:** `src/systems/composable_mechanics/components.hpp:25`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| isChilled | bool | false |  |
| isFrozen | bool | false |  |
| isStunned | bool | false |  |

## HeldItem
**doc_id:** `component:HeldItem`
**Location:** `src/systems/composable_mechanics/components.hpp:31`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## Level
**doc_id:** `component:Level`
**Location:** `src/systems/composable_mechanics/components.hpp:32`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## Experience
**doc_id:** `component:Experience`
**Location:** `src/systems/composable_mechanics/components.hpp:33`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## ClassTags
**doc_id:** `component:ClassTags`
**Location:** `src/systems/composable_mechanics/components.hpp:34`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## NextHitMitigation
**doc_id:** `component:NextHitMitigation`
**Location:** `src/systems/composable_mechanics/components.hpp:36`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

<!-- AUTOGEN:BEGIN component_list -->
- `AbilityDatabase` — `src/systems/composable_mechanics/ability.hpp:26` — fields: 3
- `AbilityRef` — `src/systems/composable_mechanics/components.hpp:21` — fields: 0
- `Ability` — `src/systems/composable_mechanics/ability.hpp:13` — fields: 8
- `ActiveBuffs` — `src/systems/composable_mechanics/components.hpp:18` — fields: 0
- `BoardHelpers` — `src/systems/composable_mechanics/board.hpp:19` — fields: 13
- `BoardPos` — `src/systems/composable_mechanics/board.hpp:10` — fields: 2
- `BuffInstance` — `src/systems/composable_mechanics/components.hpp:7` — fields: 4
- `ClassTags` — `src/systems/composable_mechanics/components.hpp:34` — fields: 0
- `CompiledEffectGraph` — `src/systems/composable_mechanics/effects.hpp:94` — fields: 26
- `Context` — `src/systems/composable_mechanics/events.hpp:32` — fields: 0
- `DamageBundle` — `src/systems/composable_mechanics/stats.hpp:47` — fields: 2
- `EffectOp` — `src/systems/composable_mechanics/effects.hpp:50` — fields: 4
- `EngineBootstrap` — `src/systems/composable_mechanics/bootstrap.hpp:7` — fields: 2
- `EngineServices` — `src/systems/composable_mechanics/effects.hpp:149` — fields: 0
- `EventListener` — `src/systems/composable_mechanics/events.hpp:38` — fields: 3
- `Event` — `src/systems/composable_mechanics/events.hpp:24` — fields: 4
- `Experience` — `src/systems/composable_mechanics/components.hpp:33` — fields: 0
- `HeldItem` — `src/systems/composable_mechanics/components.hpp:31` — fields: 0
- `HitResult` — `src/systems/composable_mechanics/combat_math.hpp:7` — fields: 4
- `KnownAbilities` — `src/systems/composable_mechanics/components.hpp:22` — fields: 0
- `Level` — `src/systems/composable_mechanics/components.hpp:32` — fields: 0
- `LifeEnergy` — `src/systems/composable_mechanics/stats.hpp:95` — fields: 2
- `LuaContentLoader` — `src/systems/composable_mechanics/loader_lua.hpp:11` — fields: 0
- `NextHitMitigation` — `src/systems/composable_mechanics/components.hpp:36` — fields: 0
- `Op_ApplyRR_Params` — `src/systems/composable_mechanics/effects.hpp:48` — fields: 0
- `Op_ApplyStatus_Params` — `src/systems/composable_mechanics/effects.hpp:46` — fields: 0
- `Op_ClassifyAdd_Params` — `src/systems/composable_mechanics/effects.hpp:88` — fields: 0
- `Op_CopyAbilityFrom_Params` — `src/systems/composable_mechanics/effects.hpp:70` — fields: 0
- `Op_DealDamage_Params` — `src/systems/composable_mechanics/effects.hpp:40` — fields: 2
- `Op_GiveExperience_Params` — `src/systems/composable_mechanics/effects.hpp:76` — fields: 0
- `Op_Item_Params` — `src/systems/composable_mechanics/effects.hpp:71` — fields: 0
- `Op_LimitPerTurn_Params` — `src/systems/composable_mechanics/effects.hpp:62` — fields: 0
- `Op_ModifyPlayerResource_Params` — `src/systems/composable_mechanics/effects.hpp:73` — fields: 0
- `Op_ModifyStats_Params` — `src/systems/composable_mechanics/effects.hpp:34` — fields: 0
- `Op_PushUnit_Params` — `src/systems/composable_mechanics/effects.hpp:64` — fields: 0
- `Op_Repeat_Params` — `src/systems/composable_mechanics/effects.hpp:61` — fields: 0
- `Op_SetLevel_Params` — `src/systems/composable_mechanics/effects.hpp:75` — fields: 0
- `Op_ShopAddItem_Params` — `src/systems/composable_mechanics/effects.hpp:78` — fields: 0
- `Op_ShopDiscountItem_Params` — `src/systems/composable_mechanics/effects.hpp:80` — fields: 0
- `Op_ShopDiscountUnit_Params` — `src/systems/composable_mechanics/effects.hpp:79` — fields: 0
- `Op_ShopReplaceItems_Params` — `src/systems/composable_mechanics/effects.hpp:82` — fields: 0
- `Op_ShopRoll_Params` — `src/systems/composable_mechanics/effects.hpp:81` — fields: 0
- `Op_ShuffleAllies_Params` — `src/systems/composable_mechanics/effects.hpp:65` — fields: 0
- `Op_StatCopyFrom_Params` — `src/systems/composable_mechanics/effects.hpp:86` — fields: 0
- `Op_StatSwapBetween_Params` — `src/systems/composable_mechanics/effects.hpp:85` — fields: 0
- `Op_StatSwapWithin_Params` — `src/systems/composable_mechanics/effects.hpp:84` — fields: 0
- `Op_SummonUnit_Params` — `src/systems/composable_mechanics/effects.hpp:68` — fields: 0
- `Op_TakeLessDamageOneShot_Params` — `src/systems/composable_mechanics/effects.hpp:90` — fields: 0
- `Op_TransformUnit_Params` — `src/systems/composable_mechanics/effects.hpp:67` — fields: 0
- `ResistPack` — `src/systems/composable_mechanics/stats.hpp:56` — fields: 0
- `ShieldStats` — `src/systems/composable_mechanics/stats.hpp:65` — fields: 4
- `Stats` — `src/systems/composable_mechanics/stats.hpp:73` — fields: 0
- `StatusFlags` — `src/systems/composable_mechanics/components.hpp:25` — fields: 3
- `Team` — `src/systems/composable_mechanics/stats.hpp:101` — fields: 1
<!-- AUTOGEN:END component_list -->
