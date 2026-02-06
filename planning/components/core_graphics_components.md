# Core + Graphics Components

Scope: Core and graphics-related ECS components extracted from C++ headers.

Key considerations:
- Core components (TransformCustom, FrameData) are used per-frame; keep updates consistent with systems that read them.
- Graphics and particle components often drive rendering state; treat as data containers unless bindings confirm mutability.
- Lua accessibility varies; verify before reading or writing from scripts.
- Lua access entries below are based on `docs/lua_stubs/components.lua` bindings and should be validated with live scripts.

## FrameData
**doc_id:** `component:FrameData`
**Location:** `src/components/graphics.hpp:15`
**Lua Access:** `component_cache.get` (stub exposed; usage not yet validated)

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| frame | Rectangle | None |  |
| texture | Texture2D* | None |  |

**Common Patterns:**

```lua
local frame = component_cache.get(entity, FrameData)
local rect = frame.frame
```

## SpriteComponentASCII
**doc_id:** `component:SpriteComponentASCII`
**Location:** `src/components/graphics.hpp:31`
**Lua Access:** `component_cache.get` (stub exposed; usage not yet validated)

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| spriteFrame | std::shared_ptr<globals::SpriteFrameData> | None |  |
| spriteData | FrameData | None |  |
| spriteNumber | int | None |  |
| charCP437 | char | ' ' |  |
| codepoint_UTF16 | int | None |  |
| spriteUUID | std::string | None |  |
| noBackgroundColor | bool | false |  |
| noForegroundColor | bool | false |  |

**Common Patterns:**

```lua
local sprite = component_cache.get(entity, SpriteComponentASCII)
sprite.spriteNumber = 0
sprite.noBackgroundColor = false
```

## AnimationObject
**doc_id:** `component:AnimationObject`
**Location:** `src/components/graphics.hpp:51`
**Lua Access:** `component_cache.get` (stub exposed; usage not yet validated)

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| uuid | std::string | None |  |
| id | std::string | None |  |
| currentElapsedTime | double | 0 |  |
| flippedHorizontally | bool | false |  |
| flippedVertically | bool | false |  |
| intrinsincRenderScale | std::optional<float> | std::nullopt |  |
| uiRenderScale | std::optional<float> | std::nullopt |  |
| playbackDirection | PlaybackDirection | PlaybackDirection::Forward |  |
| pingpongReversing | bool | false |  |
| paused | bool | false |  |
| speedMultiplier | float | 1.0f |  |
| loopCount | int | -1 |  |
| currentLoopCount | int | 0 |  |

## AnimationQueueComponent
**doc_id:** `component:AnimationQueueComponent`
**Location:** `src/components/graphics.hpp:76`
**Lua Access:** `component_cache.get` (stub exposed; usage not yet validated)
**Notes:** 2 complex types need manual review

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| noDraw | bool | false |  |
| drawWithLegacyPipeline | bool | true |  |
| enabled | bool | true |  |
| defaultAnimation | AnimationObject | None |  |
| animationQueue | std::vector<AnimationObject> | None | complex |
| fgColorOverwriteMap | std::map<int, std::string> | None | complex |
| currentAnimationIndex | int | 0 |  |
| useCallbackOnAnimationQueueComplete | bool | false |  |

**Common Patterns:**

```lua
local anim = component_cache.get(entity, AnimationQueueComponent)
anim.enabled = true
anim.currentAnimationIndex = 0
```

## TweenedLocationComponent
**doc_id:** `component:TweenedLocationComponent`
**Location:** `src/components/graphics.hpp:90`
**Lua Access:** `component_cache.get` (tag component; stub exposed)

**Fields:** None

## ParticleComponent
**doc_id:** `component:ParticleComponent`
**Location:** `src/components/particle.hpp:6`
**Lua Access:** `component_cache.get` (stub exposed; usage not yet validated)
**Notes:** 1 complex types need manual review

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| sprites | std::vector<SpriteComponentASCII> | None | complex |
| animation_speed | float | None |  |
| lifetime | float | None |  |
| speed | float | None |  |
| direction | Vector2 | None |  |
| start_color | std::string | None |  |
| end_color | std::string | None |  |
| gravity | float | None |  |

## TransformCustom
**doc_id:** `component:TransformCustom`
**Location:** `src/components/components.hpp:36`
**Lua Access:** `component_cache.get` (stub exposed; usage not yet validated)

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| x | float | 0.0f |  |
| y | float | 0.0f |  |
| w | float | 1.0f |  |
| h | float | 1.0f |  |
| r | float | 0.0f |  |
| scale | float | 1.0f |  |

**Common Patterns:**

```lua
local transform = component_cache.get(entity, TransformCustom)
transform.x = 100
transform.y = 200
```

## Action
**doc_id:** `component:Action`
**Location:** `src/components/components.hpp:52`
**Lua Access:** `component_cache.get` (stub exposed; usage not yet validated)
**Notes:** 4 complex types need manual review

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| abort | sol::protected_function | None |  |
| name | std::string | None |  |
| watchMask | bfield_t | None |  |
| start | sol::function | None | complex |
| thread | sol::thread | None | complex |
| update | sol::coroutine | None | complex |
| finish | sol::function | None | complex |
| is_running | bool | false |  |

## GOAPComponent
**doc_id:** `component:GOAPComponent`
**Location:** `src/components/components.hpp:75`
**Lua Access:** `component_cache.get` (stub exposed; usage not yet validated)
**Notes:** 3 complex types need manual review

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| ap | actionplanner_t | None |  |
| cached_current_state | worldstate_t | None |  |
| current_state | worldstate_t | None |  |
| goal | worldstate_t | None |  |
| plan_start_state | worldstate_t | None |  |
| type | std::string | "NONE" |  |
| planSize | int | None |  |
| planCost | int | None |  |
| current_action | int | None |  |
| retries | int | None |  |
| max_retries | int | 3 |  |
| dirty | bool | true |  |
| actionset_version | uint32_t | 0 |  |
| atom_schema_version | uint32_t | 0 |  |
| trace_buffer | ai::AITraceBuffer | None |  |
| blackboard | Blackboard | None |  |
| actionQueue | std::queue<Action> | None | complex |
| def | sol::table | None | complex |
| currentUpdateCoroutine | sol::coroutine | None | complex |

## TileComponent
**doc_id:** `component:TileComponent`
**Location:** `src/components/components.hpp:132`
**Lua Access:** `component_cache.get` (stub exposed; usage not yet validated)
**Notes:** 3 complex types need manual review

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| tileID | std::string | None |  |
| isImpassable | bool | false |  |
| blocksLight | bool | false |  |
| entitiesOnTile | std::vector<entt::entity> | None | complex |
| liquidsOnTile | std::vector<entt::entity> | None | complex |
| taskDoingEntitiesOnTile | std::vector<entt::entity> | None | complex |
| replacementOnDestroy | std::string | None |  |
| isDestructible | bool | false |  |
| canBeMadeIntoMulch | bool | false |  |
| taskDoingEntityTransition | entt::entity | entt::null |  |
| taskDoingEntityDrawCycleTime | float | 3.0f |  |
| isDisplayingTaskDoingEntityTransition | bool | false |  |
| taskDoingEntityDrawCycleTimer | float | 0 |  |
| taskDoingEntityDrawIndex | int | 0 |  |
| itemOnTileDrawCycleTime | float | 2.0f |  |
| itemOnTileDrawCycleTimer | float | 0 |  |
| itemDrawIndex | int | 0 |  |
| liquidOnTileDrawCycleTime | float | 2.0f |  |
| liquidOnTileDrawCycleTimer | float | 0 |  |
| liquidDrawIndex | int | 0 |  |

## LocationComponent
**doc_id:** `component:LocationComponent`
**Location:** `src/components/components.hpp:161`
**Lua Access:** `component_cache.get` (stub exposed; usage not yet validated)

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| regionIdentifier | std::string | None |  |

## NinePatchComponent
**doc_id:** `component:NinePatchComponent`
**Location:** `src/components/components.hpp:168`
**Lua Access:** `component_cache.get` (stub exposed; usage not yet validated)

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| texture | Texture2D | None |  |
| nPatchInfo | NPatchInfo | None |  |
| alpha | float | 1.0f |  |
| fgColor | Color | None |  |
| bgColor | Color | None |  |
| destRect | Rectangle | None |  |
| timeToLive | float | 0 |  |
| timeAlive | float | 0 |  |
| blinkEnabled | bool | true |  |
| blinkInterval | float | 0.5f |  |
| blinkTimer | float | 0.0f |  |
| isVisible | bool | true |  |

**Common Patterns:**

```lua
local patch = component_cache.get(entity, NinePatchComponent)
patch.alpha = 0.8
patch.isVisible = true
```

## ContainerComponent
**doc_id:** `component:ContainerComponent`
**Location:** `src/components/components.hpp:187`
**Lua Access:** `component_cache.get` (stub exposed; usage not yet validated)
**Notes:** 1 complex types need manual review

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| items | std::vector<entt::entity> | None | complex |

## InfoComponent
**doc_id:** `component:InfoComponent`
**Location:** `src/components/components.hpp:193`
**Lua Access:** `component_cache.get` (tag component; stub exposed)

**Fields:** None

## VFXTag
**doc_id:** `component:VFXTag`
**Location:** `src/components/components.hpp:200`
**Lua Access:** `component_cache.get` (tag component; stub exposed)

**Fields:** None

## ParticleTag
**doc_id:** `component:ParticleTag`
**Location:** `src/systems/particles/particle.hpp:58`
**Lua Access:** `component_cache.get` (stub exposed; usage not yet validated)
**Notes:** source_category:particles

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| name | std::string | None |  |

## Particle
**doc_id:** `component:Particle`
**Location:** `src/systems/particles/particle.hpp:62`
**Lua Access:** `component_cache.get` (stub exposed; usage not yet validated)
**Notes:** source_category:particles

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| renderType | ParticleRenderType | ParticleRenderType::CIRCLE_FILLED |  |
| velocity | std::optional<Vector2> | None |  |
| rotation | std::optional<float> | None |  |
| rotationSpeed | std::optional<float> | None |  |
| scale | std::optional<float> | None |  |
| lifespan | std::optional<float> | None |  |
| age | std::optional<float> | 0.0f |  |
| color | std::optional<Color> | None |  |
| gravity | std::optional<float> | 0.0f |  |
| acceleration | std::optional<float> | 0.0f |  |
| startColor | std::optional<Color> | None |  |
| endColor | std::optional<Color> | None |  |
| autoAspect | std::optional<bool> | None |  |
| faceVelocity | std::optional<bool> | None |  |
| z | std::optional<int> | None |  |
| space | std::optional<RenderSpace> | None |  |

## ParticleEmitter
**doc_id:** `component:ParticleEmitter`
**Location:** `src/systems/particles/particle.hpp:89`
**Lua Access:** `component_cache.get` (stub exposed; usage not yet validated)
**Notes:** 1 complex types need manual review; source_category:particles

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| size | Vector2 | None |  |
| emissionRate | float | 0.1f |  |
| lastEmitTime | float | 0.0f |  |
| particleLifespan | float | 1.0f |  |
| particleSpeed | float | 1.0f |  |
| fillArea | bool | false |  |
| oneShot | bool | false |  |
| oneShotParticleCount | float | 10.f |  |
| prewarm | bool | false |  |
| prewarmParticleCount | float | 10.f |  |
| useGlobalCoords | bool | false |  |
| speedScale | float | 1.0f |  |
| explosiveness | float | 0.0f |  |
| randomness | float | 0.1f |  |
| emissionSpread | float | 0.0f |  |
| gravityStrength | float | 0.0f |  |
| emissionDirection | Vector2 | {0, -1} |  |
| acceleration | float | 0.0f |  |
| blendMode | BlendMode | BLEND_ALPHA |  |
| colors | std::vector<Color> | {WHITE, GRAY, LIGHTGRAY} | complex |
| defaultZ | std::optional<int> | None |  |
| defaultSpace | std::optional<RenderSpace> | None |  |

## ParticleAnimationConfig
**doc_id:** `component:ParticleAnimationConfig`
**Location:** `src/systems/particles/particle.hpp:116`
**Lua Access:** `component_cache.get` (stub exposed; usage not yet validated)
**Notes:** source_category:particles

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| useSpriteNotAnimation | bool | false |  |
| loop | bool | false |  |
| animationName | std::string | None |  |
| fg | std::optional<Color> | None |  |
| bg | std::optional<Color> | None |  |

## StencilMaskSource
**doc_id:** `component:StencilMaskSource`
**Location:** `src/systems/particles/particle.hpp:1024`
**Lua Access:** `component_cache.get` (stub exposed; usage not yet validated)
**Notes:** source_category:particles

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| paddingPx | float | 0.0f |  |

## StencilMaskedParticle
**doc_id:** `component:StencilMaskedParticle`
**Location:** `src/systems/particles/particle.hpp:1029`
**Lua Access:** `component_cache.get` (stub exposed; usage not yet validated)
**Notes:** source_category:particles

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| sourceEntity | entt::entity | entt::null |  |
| zBias | float | 0.0f |  |

## Tests
- `core.components.transformcustom.read_write` (doc_id: `component:TransformCustom`)
- `core.components.framedata.read` (doc_id: `component:FrameData`)
- `core.components.spritecomponentascii.read_write` (doc_id: `component:SpriteComponentASCII`)
- `core.components.animationqueuecomponent.read_write` (doc_id: `component:AnimationQueueComponent`)

<!-- AUTOGEN:BEGIN component_list -->
- `Action` — `src/components/components.hpp:52` — fields: 8
- `AnimationObject` — `src/components/graphics.hpp:51` — fields: 13
- `AnimationQueueComponent` — `src/components/graphics.hpp:76` — fields: 8
- `ContainerComponent` — `src/components/components.hpp:187` — fields: 1
- `FrameData` — `src/components/graphics.hpp:15` — fields: 2
- `GOAPComponent` — `src/components/components.hpp:75` — fields: 19
- `InfoComponent` — `src/components/components.hpp:193` — fields: 0
- `LocationComponent` — `src/components/components.hpp:161` — fields: 1
- `NinePatchComponent` — `src/components/components.hpp:168` — fields: 12
- `ParticleAnimationConfig` — `src/systems/particles/particle.hpp:116` — fields: 5
- `ParticleComponent` — `src/components/particle.hpp:6` — fields: 8
- `ParticleEmitter` — `src/systems/particles/particle.hpp:89` — fields: 22
- `ParticleTag` — `src/systems/particles/particle.hpp:58` — fields: 1
- `Particle` — `src/systems/particles/particle.hpp:62` — fields: 16
- `SpriteComponentASCII` — `src/components/graphics.hpp:31` — fields: 8
- `StencilMaskSource` — `src/systems/particles/particle.hpp:1024` — fields: 1
- `StencilMaskedParticle` — `src/systems/particles/particle.hpp:1029` — fields: 2
- `TileComponent` — `src/components/components.hpp:132` — fields: 20
- `TransformCustom` — `src/components/components.hpp:36` — fields: 6
- `TweenedLocationComponent` — `src/components/graphics.hpp:90` — fields: 0
- `VFXTag` — `src/components/components.hpp:200` — fields: 0
<!-- AUTOGEN:END component_list -->
