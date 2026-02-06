# Physics Components

Scope: ECS physics-related components extracted from C++ headers.

Key considerations:
- PhysicsLayer and CollisionTag are string-tagged and hashed; keep tag names consistent with PhysicsWorld collision tags.
- ColliderComponent and BodyComponent tie physics bodies to TransformCustom; moving transforms without physics updates can desync.
- RaycastHit is a result struct; treat as read-only data from physics queries.

## ObjectLayerTag
**doc_id:** `component:ObjectLayerTag`
**Location:** `src/systems/physics/physics_components.hpp:15`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| name | std::string | None |  |
| hash | std::size_t | None |  |

## PhysicsLayer
**doc_id:** `component:PhysicsLayer`
**Location:** `src/systems/physics/physics_components.hpp:23`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| tag | std::string | None |  |
| tag_hash | std::size_t | None |  |

## PhysicsWorldRef
**doc_id:** `component:PhysicsWorldRef`
**Location:** `src/systems/physics/physics_components.hpp:31`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| name | std::string | None |  |
| hash | std::size_t | None |  |

## WorldStateBinding
**doc_id:** `component:WorldStateBinding`
**Location:** `src/systems/physics/physics_components.hpp:39`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| state_name | std::string | None |  |
| state_hash | std::size_t | None |  |

## CraneState
**doc_id:** `component:CraneState`
**Location:** `src/systems/physics/crane_system.hpp:6`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| dollyBody | cpBody* | nullptr |  |
| hookBody | cpBody* | nullptr |  |
| dollyServo | cpConstraint* | nullptr |  |
| winchServo | cpConstraint* | nullptr |  |
| hookJoint | cpConstraint* | nullptr |  |

## BodyComponent
**doc_id:** `component:BodyComponent`
**Location:** `src/systems/physics/steering.hpp:19`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| body | cpBody* | nullptr |  |

## SteerableComponent
**doc_id:** `component:SteerableComponent`
**Location:** `src/systems/physics/steering.hpp:26`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| enabled | bool | false |  |
| mass | float | 1.0f |  |
| maxSpeed | float | 4000.0f |  |
| maxForce | float | 4000.0f |  |
| maxTurnRate | float | 2.0f * float(M_PI) |  |
| turnMultiplier | float | 2.0f |  |
| steeringForce | cpVect | 0, 0 |  |
| timedForce | cpVect | 0, 0 |  |
| timedForceTimeLeft | float | 0.f, timedForceDuration = 0.f |  |
| timedImpulsePerSec | cpVect | 0, 0 |  |
| timedImpulseTimeLeft | float | 0.f, timedImpulseDuration = 0.f |  |
| isSeeking | bool | false, isFleeing = false, isPursuing = false,
       isEvading = false |  |
| isWandering | bool | false, isPathFollowing = false |  |
| isSeparating | bool | false, isAligning = false, isCohesing = false |  |
| wanderTarget | cpVect | 0, 0 |  |
| wanderRadius | float | 40.f, wanderDistance = 40.f, wanderJitter = 20.f |  |
| path | std::vector<cpVect> | None | complex |
| pathIndex | int | 0 |  |
| pathArriveRadius | float | 16.f |  |
| disableArrival | bool | false |  |
| arriveRadius | float | 0.0f |  |

## StickyConfig
**doc_id:** `component:StickyConfig`
**Location:** `src/systems/physics/physics_world.hpp:57`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| impulseThreshold | cpFloat | None |  |
| maxForce | cpFloat | None |  |

## TankController
**doc_id:** `component:TankController`
**Location:** `src/systems/physics/physics_world.hpp:281`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| body | cpBody* | nullptr |  |
| control | cpBody* | nullptr |  |
| pivot | cpConstraint* | nullptr |  |
| gear | cpConstraint* | nullptr |  |
| driveSpeed | float | 30.0f |  |
| stopRadius | float | 30.0f |  |
| gearMaxBias | float | 1.2f |  |
| gearMaxForce | float | 50000.0f |  |
| pivotMaxForce | float | 10000.0f |  |
| target | cpVect | cpvzero |  |
| hasTarget | bool | false |  |

## CollisionEvent
**doc_id:** `component:CollisionEvent`
**Location:** `src/systems/physics/physics_world.hpp:643`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| objectA | void* | None |  |
| objectB | void* | None |  |
| x1 | float | None |  |
| y1 | float | None |  |
| x2 | float | None |  |
| y2 | float | None |  |
| nx | float | None |  |
| ny | float | None |  |

## CollisionPair
**doc_id:** `component:CollisionPair`
**Location:** `src/systems/physics/physics_world.hpp:651`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| a | void* | None |  |
| b | void* | None |  |

## CollisionPairHash
**doc_id:** `component:CollisionPairHash`
**Location:** `src/systems/physics/physics_world.hpp:663`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## ColliderComponent
**doc_id:** `component:ColliderComponent`
**Location:** `src/systems/physics/physics_world.hpp:670`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| body | std::shared_ptr<cpBody> | None |  |
| shape | std::shared_ptr<cpShape> | None |  |
| isSensor | bool | false |  |
| isDynamic | bool | true |  |
| debugDraw | bool | true |  |
| shapeType | ColliderShapeType | None |  |
| tag | std::string | "default" |  |
| extraShapes | std::vector<SubShape> | None | SubShape has shape, type, tag, isSensor |
| prevPos | Vector2 | {} |  |
| bodyPos | Vector2 | {} |  |
| prevRot | float | 0.0f |  |
| bodyRot | float | 0.0f |  |

## CollisionTag
**doc_id:** `component:CollisionTag`
**Location:** `src/systems/physics/physics_world.hpp:703`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| category | int | None |  |
| masks | std::vector<int> | None | complex |
| triggers | std::vector<int> | None | complex |

## RaycastHit
**doc_id:** `component:RaycastHit`
**Location:** `src/systems/physics/physics_world.hpp:709`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| shape | cpShape* | None |  |
| fraction | float | None |  |
| normal | cpVect | None |  |
| point | cpVect | None |  |

## UFNode
**doc_id:** `component:UFNode`
**Location:** `src/systems/physics/physics_world.hpp:721`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| parent | cpBody* | None |  |
| size | int | 1 |  |

## GravityField
**doc_id:** `component:GravityField`
**Location:** `src/systems/physics/physics_world.hpp:1235`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| mode | Mode | Mode::None |  |
| GM | cpFloat | 0 |  |
| point | cpVect | 0,0 |  |
| centerBody | cpBody* | nullptr |  |
| softening | cpFloat | 25.0f |  |
| a_max | cpFloat | 10000000.0f |  |
| customDamping | cpFloat | 1.0f |  |

## PlatformerCtrl
**doc_id:** `component:PlatformerCtrl`
**Location:** `src/systems/physics/physics_world.hpp:1269`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| body | cpBody* | nullptr |  |
| feet | cpShape* | nullptr |  |
| maxVel | float | 500.0f |  |
| groundAccel | float | 500.0f / 0.1f |  |
| airAccel | float | 500.0f / 0.25f |  |
| jumpHeight | float | 50.0f |  |
| jumpBoostH | float | 55.0f |  |
| fallVel | float | 900.0f |  |
| gravityY | float | 2000.0f |  |
| remainingBoost | float | 0.f |  |
| grounded | bool | false |  |
| lastJumpHeld | bool | false |  |
| moveX | float | 0.f |  |
| jumpHeld | bool | false |  |

<!-- AUTOGEN:BEGIN component_list -->
- `BodyComponent` — `src/systems/physics/steering.hpp:19` — fields: 0
- `ColliderComponent` — `src/systems/physics/physics_world.hpp:670` — fields: 13
- `CollisionEvent` — `src/systems/physics/physics_world.hpp:643` — fields: 0
- `CollisionPairHash` — `src/systems/physics/physics_world.hpp:663` — fields: 0
- `CollisionPair` — `src/systems/physics/physics_world.hpp:651` — fields: 2
- `CollisionTag` — `src/systems/physics/physics_world.hpp:703` — fields: 3
- `CraneState` — `src/systems/physics/crane_system.hpp:6` — fields: 5
- `GravityField` — `src/systems/physics/physics_world.hpp:1235` — fields: 7
- `ObjectLayerTag` — `src/systems/physics/physics_components.hpp:15` — fields: 2
- `PhysicsLayer` — `src/systems/physics/physics_components.hpp:23` — fields: 2
- `PhysicsWorldRef` — `src/systems/physics/physics_components.hpp:31` — fields: 2
- `PlatformerCtrl` — `src/systems/physics/physics_world.hpp:1269` — fields: 14
- `RaycastHit` — `src/systems/physics/physics_world.hpp:709` — fields: 3
- `SteerableComponent` — `src/systems/physics/steering.hpp:26` — fields: 21
- `StickyConfig` — `src/systems/physics/physics_world.hpp:57` — fields: 2
- `TankController` — `src/systems/physics/physics_world.hpp:281` — fields: 11
- `UFNode` — `src/systems/physics/physics_world.hpp:721` — fields: 2
- `WorldStateBinding` — `src/systems/physics/physics_components.hpp:39` — fields: 2
<!-- AUTOGEN:END component_list -->
