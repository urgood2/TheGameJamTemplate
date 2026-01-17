---@meta
-- EmmyLua type definitions for C++ bindings and Lua modules
-- This file provides IDE autocomplete support

---------------------------------------------------------------------------
-- Core C++ Bindings
---------------------------------------------------------------------------

---@class Registry
---@field create fun(): number Create a new entity
---@field valid fun(entity: number): boolean Check if entity is valid
---@field destroy fun(entity: number) Destroy an entity
registry = {}

---@class ComponentCache
---@field get fun(entity: number, component_type: any): any Get component from cache
---@field invalidate fun(entity: number) Invalidate cached components for entity
---@field begin_frame fun() Begin batch mode (skip per-access frame checks)
---@field end_frame fun() End batch mode
component_cache = {}

---------------------------------------------------------------------------
-- Q.lua - Quick Transform Operations
---------------------------------------------------------------------------

---@class Q
---@field move fun(entity: number, x: number, y: number) Move entity to absolute position
---@field center fun(entity: number): number?, number? Get entity center (x, y or nil, nil)
---@field visualCenter fun(entity: number): number?, number? Get entity visual center
---@field offset fun(entity: number, dx: number, dy: number) Move relative to current position
---@field size fun(entity: number): number?, number? Get entity size
---@field bounds fun(entity: number): number?, number?, number?, number? Get entity bounds
---@field visualBounds fun(entity: number): number?, number?, number?, number? Get entity visual bounds
---@field rotation fun(entity: number): number? Get entity rotation
---@field setRotation fun(entity: number, radians: number): boolean Set entity rotation
---@field rotate fun(entity: number, deltaRadians: number): boolean Rotate entity by delta
---@field isValid fun(entity: number): boolean Check entity validity
---@field ensure fun(entity: number, context?: string): number? Ensure entity is valid
---@field distance fun(entity1: number, entity2: number): number? Distance between entities
---@field direction fun(entity1: number, entity2: number): number?, number? Direction vector between entities
---@field distanceToPoint fun(entity: number, x: number, y: number): number? Distance to point
---@field isInRange fun(entity1: number, entity2: number, range: number): boolean Check range between entities
---@field getTransform fun(entity: number): table? Get Transform component
---@field withTransform fun(entity: number, fn: fun(transform: table)): boolean Run callback with Transform
---@field getGameObject fun(entity: number): table? Get GameObject component
---@field withGameObject fun(entity: number, fn: fun(gameObject: table)): boolean Run callback with GameObject
---@field getAnimation fun(entity: number): table? Get AnimationQueueComponent
---@field withAnimation fun(entity: number, fn: fun(animation: table)): boolean Run callback with AnimationQueueComponent
---@field getUIConfig fun(entity: number): table? Get UIConfig component
---@field withUIConfig fun(entity: number, fn: fun(uiConfig: table)): boolean Run callback with UIConfig
---@field getCollision fun(entity: number): table? Get CollisionShape2D component
---@field withCollision fun(entity: number, fn: fun(collision: table)): boolean Run callback with CollisionShape2D
---@field components fun(entity: number, ...: string): table Get multiple components
---@field velocity fun(entity: number): number?, number? Get physics velocity
---@field setVelocity fun(entity: number, vx: number, vy: number): boolean Set physics velocity
---@field speed fun(entity: number): number? Get physics speed
---@field impulse fun(entity: number, ix: number, iy: number): boolean Apply impulse
---@field force fun(entity: number, fx: number, fy: number): boolean Apply force
---@field setSpin fun(entity: number, angularVel: number): boolean Set angular velocity
---@field spin fun(entity: number): number? Get angular velocity
---@field moveToward fun(entity: number, targetX: number, targetY: number, speed: number): boolean Move toward point
---@field chase fun(entity: number, target: number, speed: number): boolean Move toward entity
---@field flee fun(entity: number, threat: number, speed: number): boolean Move away from entity
Q = {}

---------------------------------------------------------------------------
-- EntityBuilder
---------------------------------------------------------------------------

---@class EntityBuilderOptions
---@field sprite? string Sprite name
---@field position? {x: number, y: number} Initial position
---@field size? number[] Width and height {w, h}
---@field shadow? boolean Add shadow component
---@field data? table Custom script data
---@field interactive? table Interactive options (hover, click, collision)
---@field state? any Initial state
---@field shaders? string[] Shader names to apply

---@class EntityBuilder
---@field create fun(opts: EntityBuilderOptions): number, table Create entity with full options
---@field simple fun(sprite: string, x: number, y: number, w: number, h: number): number Create simple entity
---@field validated fun(ScriptType: table, entity: number, data?: table): table Create script with validation
EntityBuilder = {}

---------------------------------------------------------------------------
-- PhysicsBuilder
---------------------------------------------------------------------------

---@class PhysicsBuilder
---@field for_entity fun(entity: number): PhysicsBuilder Start building physics for entity
---@field circle fun(): PhysicsBuilder Set shape to circle
---@field box fun(): PhysicsBuilder Set shape to box
---@field tag fun(tag: string): PhysicsBuilder Set collision tag
---@field bullet fun(): PhysicsBuilder Enable bullet mode (CCD)
---@field sensor fun(): PhysicsBuilder Make sensor (no physical collision)
---@field friction fun(f: number): PhysicsBuilder Set friction coefficient
---@field density fun(d: number): PhysicsBuilder Set density
---@field collideWith fun(tags: string[]): PhysicsBuilder Set collision targets
---@field apply fun() Apply physics configuration
PhysicsBuilder = {}

---------------------------------------------------------------------------
-- ShaderBuilder
---------------------------------------------------------------------------

---@class ShaderBuilder
---@field for_entity fun(entity: number): ShaderBuilder Start building shaders for entity
---@field add fun(shader_name: string, params?: table): ShaderBuilder Add shader with optional params
---@field remove fun(shader_name: string): ShaderBuilder Remove shader
---@field apply fun() Apply shader configuration
ShaderBuilder = {}

---------------------------------------------------------------------------
-- Timer API
---------------------------------------------------------------------------

---@class TimerOptions
---@field delay number Delay in seconds
---@field action fun() Callback function
---@field tag? string Optional tag for cancellation
---@field times? number Number of repetitions (for every_opts)
---@field immediate? boolean Run immediately then repeat (for every_opts)

---@class TimerSequence
---@field wait fun(seconds: number): TimerSequence Wait for duration
---@field do_now fun(action: fun()): TimerSequence Execute action immediately
---@field start fun() Start the sequence

---@class Timer
---@field after fun(delay: number, action: fun(), tag?: string) One-shot timer
---@field after_opts fun(opts: TimerOptions) One-shot timer with options
---@field every fun(delay: number, action: fun(), tag?: string) Repeating timer
---@field every_opts fun(opts: TimerOptions) Repeating timer with options
---@field cooldown fun(delay: number, condition: fun(): boolean, action: fun(), times?: number, after?: fun(), tag?: string, group?: string) Cooldown timer
---@field cooldown_opts fun(opts: table) Cooldown timer with options
---@field for_time fun(delay: number, action: fun(dt: number), after?: fun(), tag?: string, group?: string) For-time timer
---@field for_time_opts fun(opts: table) For-time timer with options
---@field tween_fields fun(delay: number, target: table, source: table, method?: fun(t:number): number, after?: fun(), tag?: string, group?: string) Tween table fields
---@field tween_opts fun(opts: table) Tween table fields with options
---@field delay fun(delay_or_opts: number|table, action?: fun(), opts?: table) One-shot delay helper
---@field physics_every_opts fun(opts: table) Physics-step repeating timer with options
---@field cancel fun(tag: string) Cancel timer by tag
---@field sequence fun(tag?: string): TimerSequence Create timer sequence
timer = {}

---------------------------------------------------------------------------
-- Signal/Event System (HUMP)
---------------------------------------------------------------------------

---@class Signal
---@field emit fun(event: string, ...: any) Emit event with arguments
---@field register fun(event: string, handler: fun(...: any)) Register event handler
---@field remove fun(handler: fun()) Remove specific handler
---@field clear fun(event: string) Clear all handlers for event
signal = {}

---------------------------------------------------------------------------
-- Logging
---------------------------------------------------------------------------

---@param ... any
log_debug = function(...) end

---@param ... any
log_info = function(...) end

---@param ... any
log_warn = function(...) end

---@param ... any
log_error = function(...) end

---------------------------------------------------------------------------
-- Entity Helpers
---------------------------------------------------------------------------

---@param entity number
---@return boolean
ensure_entity = function(entity) end

---@param entity number
---@return boolean
ensure_scripted_entity = function(entity) end

---@param entity number
---@return table?
safe_script_get = function(entity) end

---@param entity number
---@param field string
---@param default any
---@return any
script_field = function(entity, field, default) end

---@param entity number
---@return table?
getScriptTableFromEntityID = function(entity) end

---------------------------------------------------------------------------
-- Physics Functions
---------------------------------------------------------------------------

---@class Physics
---@field create_physics_for_transform fun(registry: Registry, physics_manager: any, entity: number, world_name: string, config: table)
---@field set_sync_mode fun(registry: Registry, entity: number, mode: number)
---@field enable_collision_between_many fun(world: any, tag: string, targets: string[])
---@field update_collision_masks_for fun(world: any, tag: string, targets: string[])
physics = {}

---@class PhysicsManager
---@field get_world fun(name: string): any Get physics world by name
PhysicsManager = {}

---------------------------------------------------------------------------
-- Draw Commands
---------------------------------------------------------------------------

---@class Draw
---@field textPro fun(layer: number, opts: table, z?: number, space?: string)
---@field local_command fun(entity: number, cmd_type: string, opts: table, meta?: table)
draw = {}

---------------------------------------------------------------------------
-- Misc Globals
---------------------------------------------------------------------------

---@type number
PLANNING_STATE = 0

---@param name string
---@param entity number
setEntityAlias = function(name, entity) end

---@param name string
---@return number?
getEntityByAlias = function(name) end
