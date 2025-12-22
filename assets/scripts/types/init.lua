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
---@field offset fun(entity: number, dx: number, dy: number) Move relative to current position
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
