---@meta
--[[
================================================================================
LUA MODULES - Return types for require() calls
================================================================================
These types describe what Lua modules return when you require() them.
This helps LuaLS understand module shapes for autocomplete.

Update this file when module APIs change.
]]

---------------------------------------------------------------------------
-- Timer API (core/timer.lua)
---------------------------------------------------------------------------

---@class TimerAfterOpts
---@field delay number|{[1]: number, [2]: number} Delay in seconds (or {min, max} for random)
---@field action fun() Callback function
---@field tag? string Timer tag for cancellation
---@field group? string Timer group

---@class TimerEveryOpts
---@field delay number|{[1]: number, [2]: number} Interval in seconds
---@field action fun():boolean? Callback (return false to stop)
---@field times? number Number of times to run (0 = infinite, default: 0)
---@field immediate? boolean Run once immediately (default: false)
---@field after? fun() Callback after all iterations complete
---@field tag? string Timer tag for cancellation
---@field group? string Timer group

---@class TimerCooldownOpts
---@field delay number|{[1]: number, [2]: number} Cooldown duration
---@field condition fun():boolean Condition to check
---@field action fun() Action when condition met after cooldown
---@field times? number Number of times (0 = infinite, default: 0)
---@field after? fun() Callback after all iterations
---@field tag? string Timer tag for cancellation
---@field group? string Timer group

---@class TimerForTimeOpts
---@field delay? number|{[1]: number, [2]: number} Duration to run action
---@field duration? number|{[1]: number, [2]: number} Alternate name for duration
---@field action fun(dt: number) Action called each frame with dt
---@field after? fun() Callback after duration completes
---@field tag? string Timer tag for cancellation
---@field group? string Timer group

---@class TimerTweenOpts
---@field delay number|{[1]: number, [2]: number} Duration of tween
---@field target table Target table to mutate
---@field source table Fields to tween {field = target_value}
---@field method? fun(t: number): number Easing function (default: linear)
---@field after? fun() Callback after tween completes
---@field tag? string Timer tag for cancellation
---@field group? string Timer group

---@class TimerSequence
---@field wait fun(self: TimerSequence, seconds: number): TimerSequence Wait for duration
---@field do_now fun(self: TimerSequence, action: fun()): TimerSequence Execute action immediately
---@field start fun(self: TimerSequence) Start the sequence

---@class Timer
---@field after fun(delay: number|TimerAfterOpts, action?: fun(), tag?: string, group?: string): string One-shot timer (dual signature)
---@field after_opts fun(opts: TimerAfterOpts): string One-shot timer with options
---@field every fun(delay: number|TimerEveryOpts, action?: fun(), times?: number, immediate?: boolean, after?: fun(), tag?: string, group?: string): string Repeating timer (dual signature)
---@field every_opts fun(opts: TimerEveryOpts): string Repeating timer with options
---@field cooldown fun(delay: number|TimerCooldownOpts, condition?: fun(): boolean, action?: fun(), times?: number, after?: fun(), tag?: string, group?: string): string Cooldown timer (dual signature)
---@field cooldown_opts fun(opts: TimerCooldownOpts): string Cooldown timer with options
---@field for_time fun(delay: number|TimerForTimeOpts, action?: fun(dt: number), after?: fun(), tag?: string, group?: string): string For-time timer (dual signature)
---@field for_time_opts fun(opts: TimerForTimeOpts): string For-time timer with options
---@field tween_fields fun(delay: number, target: table, source: table, method?: fun(t:number): number, after?: fun(), tag?: string, group?: string): string Tween table fields
---@field tween_opts fun(opts: TimerTweenOpts): string Tween table fields with options
---@field delay fun(delay_or_opts: number|TimerAfterOpts, action?: fun(), opts?: {tag?: string, group?: string}): string One-shot delay helper
---@field loop fun(opts: {delay: number, action: fun(), tag?: string, group?: string, immediate?: boolean}): string Infinite loop timer
---@field pulse fun(interval: number, action: fun(), tag?: string): string Simple infinite pulse
---@field during fun(duration: number, action: fun(dt: number), after?: fun(), tag?: string): string Run action every frame for duration
---@field cancel fun(tag: string) Cancel timer by tag
---@field sequence fun(group?: string): TimerSequence Create timer sequence
---@field pause fun(tag: string) Pause timer
---@field resume fun(tag: string) Resume timer
---@field kill_group fun(group: string) Kill all timers in group
---@field pause_group fun(group: string) Pause all timers in group
---@field resume_group fun(group: string) Resume all timers in group
timer = {}

---------------------------------------------------------------------------
-- Signal/Event System (external/hump/signal.lua)
---------------------------------------------------------------------------

---@class Signal
---@field emit fun(event: string, ...: any) Emit event with arguments
---@field register fun(event: string, handler: fun(...: any)): fun() Register handler, returns unregister function
---@field remove fun(handler: fun()) Remove specific handler
---@field clear fun(event: string) Clear all handlers for event
signal = {}

---------------------------------------------------------------------------
-- Q.lua - Quick Transform Operations (core/Q.lua)
---------------------------------------------------------------------------

---@class Q
---@field move fun(entity: number, x: number, y: number) Move entity to absolute position
---@field center fun(entity: number): number?, number? Get entity center (x, y or nil, nil)
---@field visualCenter fun(entity: number): number?, number? Get entity visual center
---@field offset fun(entity: number, dx: number, dy: number) Move relative to current position
---@field size fun(entity: number): number?, number? Get entity size
---@field bounds fun(entity: number): number?, number?, number?, number? Get entity bounds (x, y, w, h)
---@field visualBounds fun(entity: number): number?, number?, number?, number? Get entity visual bounds
---@field rotation fun(entity: number): number? Get entity rotation in radians
---@field setRotation fun(entity: number, radians: number): boolean Set entity rotation
---@field rotate fun(entity: number, deltaRadians: number): boolean Rotate entity by delta
---@field isValid fun(entity: number): boolean Check entity validity
---@field ensure fun(entity: number, context?: string): number? Ensure entity is valid, return entity or nil
---@field distance fun(entity1: number, entity2: number): number? Distance between entities
---@field direction fun(entity1: number, entity2: number): number?, number? Direction vector (normalized)
---@field distanceToPoint fun(entity: number, x: number, y: number): number? Distance to point
---@field isInRange fun(entity1: number, entity2: number, range: number): boolean Check if entities are within range
---@field getTransform fun(entity: number): Transform? Get Transform component
---@field withTransform fun(entity: number, fn: fun(transform: Transform)): boolean Run callback with Transform
---@field getGameObject fun(entity: number): GameObject? Get GameObject component
---@field withGameObject fun(entity: number, fn: fun(gameObject: GameObject)): boolean Run callback with GameObject
---@field getAnimation fun(entity: number): AnimationQueueComponent? Get AnimationQueueComponent
---@field withAnimation fun(entity: number, fn: fun(animation: AnimationQueueComponent)): boolean Run callback with animation
---@field getUIConfig fun(entity: number): UIConfig? Get UIConfig component
---@field withUIConfig fun(entity: number, fn: fun(uiConfig: UIConfig)): boolean Run callback with UIConfig
---@field getCollision fun(entity: number): CollisionShape2D? Get CollisionShape2D component
---@field withCollision fun(entity: number, fn: fun(collision: CollisionShape2D)): boolean Run callback with collision
---@field components fun(entity: number, ...: string): table Get multiple components by name
---@field velocity fun(entity: number): number?, number? Get physics velocity (vx, vy)
---@field setVelocity fun(entity: number, vx: number, vy: number): boolean Set physics velocity
---@field speed fun(entity: number): number? Get physics speed (magnitude)
---@field impulse fun(entity: number, ix: number, iy: number): boolean Apply impulse
---@field force fun(entity: number, fx: number, fy: number): boolean Apply force
---@field setSpin fun(entity: number, angularVel: number): boolean Set angular velocity
---@field spin fun(entity: number): number? Get angular velocity
---@field moveToward fun(entity: number, targetX: number, targetY: number, speed: number): boolean Move toward point
---@field chase fun(entity: number, target: number, speed: number): boolean Move toward entity
---@field flee fun(entity: number, threat: number, speed: number): boolean Move away from entity
Q = {}

---------------------------------------------------------------------------
-- Component Cache (core/component_cache.lua)
---------------------------------------------------------------------------

-- Note: component_cache is typically a C++ global, but this describes the module API
---@class ComponentCacheModule
---@field get fun(entity: number, component_type: any): any Get component (fast, no safety check)
---@field safe_get fun(entity: number, component_type: any): any, boolean Get with success flag
---@field invalidate fun(entity: number) Invalidate cache for entity
---@field begin_frame fun() Begin batch mode
---@field end_frame fun() End batch mode

---------------------------------------------------------------------------
-- Entity Cache (core/entity_cache.lua)
---------------------------------------------------------------------------

---@class EntityCache
---@field valid fun(entity: number): boolean Check if entity is valid
---@field active fun(entity: number): boolean Check if entity is active
