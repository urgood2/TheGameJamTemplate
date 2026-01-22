---@meta
--[[
================================================================================
C++ GLOBALS - Sol2 bindings exposed to Lua
================================================================================
These globals are defined in C++ and bound via Sol2. They exist at runtime
but LuaLS can't infer them from source code alone.

Update this file when C++ bindings change.
]]

---------------------------------------------------------------------------
-- Core ECS
---------------------------------------------------------------------------

---@class Registry
---@field create fun(): number Create a new entity
---@field valid fun(self: Registry, entity: number): boolean Check if entity is valid
---@field destroy fun(self: Registry, entity: number) Destroy an entity
---@field has fun(self: Registry, entity: number, component: any): boolean Check if entity has component
---@field get fun(self: Registry, entity: number, component: any): any Get component from entity
---@field emplace fun(self: Registry, entity: number, component: any, value?: any): any Add component to entity
registry = {}

---@class ComponentCache
---@field get fun(entity: number, component_type: any): any Get component from cache
---@field safe_get fun(entity: number, component_type: any): any, boolean Get component with success flag
---@field invalidate fun(entity: number) Invalidate cached components for entity
---@field begin_frame fun() Begin batch mode (skip per-access frame checks)
---@field end_frame fun() End batch mode
component_cache = {}

---@type number Invalid entity sentinel value
entt_null = -1

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------

---@class CommandBuffer
---@field queueDraw fun(layer: any, fn: fun(), z?: number, space?: any) Queue a draw command
---@field queueDrawWithTransform fun(layer: any, entity: number, fn: fun(), z?: number, space?: any) Queue draw with entity transform
command_buffer = {}

---@class Layers
---@field sprites any Sprite layer
---@field ui any UI layer
---@field background any Background layer
---@field foreground any Foreground layer
---@field effects any Effects layer
layers = {}

---@class LayerOrderSystem
---@field get_z fun(layer_name: string): number Get z-order for layer
layer_order_system = {}

---@class ZOrders
---@field UI number UI z-order base
---@field GAME number Game z-order base
---@field BACKGROUND number Background z-order
z_orders = {}

---@class ShaderPipeline
---@field addShader fun(entity: number, shader_name: string, params?: table) Add shader to entity
---@field removeShader fun(entity: number, shader_name: string) Remove shader from entity
shader_pipeline = {}

---@class GlobalShaderUniforms
---@field set fun(name: string, value: any) Set a global shader uniform
---@field get fun(name: string): any Get a global shader uniform
globalShaderUniforms = {}

---------------------------------------------------------------------------
-- Physics
---------------------------------------------------------------------------

---@class Physics
---@field create_physics_for_transform fun(registry: Registry, physics_manager: any, entity: number, world_name: string, config: table)
---@field set_sync_mode fun(registry: Registry, entity: number, mode: number)
---@field enable_collision_between_many fun(world: any, tag: string, targets: string[])
---@field update_collision_masks_for fun(world: any, tag: string, targets: string[])
---@field ApplyImpulse fun(world: any, entity: number, ix: number, iy: number)
---@field SetVelocity fun(world: any, entity: number, vx: number, vy: number)
---@field GetVelocity fun(world: any, entity: number): number, number
---@field PhysicsSyncMode table Physics sync mode constants
physics = {}

---@class PhysicsManager
---@field get_world fun(name: string): any Get physics world by name
PhysicsManager = {}

---@type any Physics manager instance
physics_manager_instance = {}

---@type number Physics tick counter
physicsTickCounter = 0

---------------------------------------------------------------------------
-- Animation
---------------------------------------------------------------------------

---@class AnimationSystem
---@field USE_ANIMATION_BOOL boolean Whether to use animations
---@field createAnimatedObjectWithTransform fun(sprite: string, useAnim: boolean, x: number, y: number, shaderPass?: any, shadow?: boolean): number
---@field resizeAnimationObjectsInEntityToFit fun(entity: number, w: number, h: number)
animation_system = {}

---------------------------------------------------------------------------
-- Draw Commands (Module-style API)
---------------------------------------------------------------------------

---@class Draw
---@field textPro fun(layer: any, opts: table, z?: number, space?: any)
---@field local_command fun(entity: number, cmd_type: string, opts: table, meta?: table)
draw = {}

---------------------------------------------------------------------------
-- Localization
---------------------------------------------------------------------------

---@class Localization
---@field get fun(key: string): string Get localized string
---@field get_formatted fun(key: string, ...: any): string Get formatted localized string
localization = {}

---------------------------------------------------------------------------
-- Game State
---------------------------------------------------------------------------

---@class Globals
---@field screen_width number Screen width in pixels
---@field screen_height number Screen height in pixels
---@field dt number Delta time
---@field player_entity number? Player entity ID
globals = {}

---@type any Main game instance
main = {}

---@type number Planning state constant
PLANNING_STATE = 0

---------------------------------------------------------------------------
-- Logging Functions
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
-- Entity Helper Functions (C++ or early-loaded Lua)
---------------------------------------------------------------------------

---@param entity number
---@return boolean
ensure_entity = function(entity) end

---@param entity number
---@return boolean
ensure_scripted_entity = function(entity) end

---@param entity number
---@param warn? boolean
---@return table?
safe_script_get = function(entity, warn) end

---@param entity number
---@param field string
---@param default any
---@return any
script_field = function(entity, field, default) end

---@param entity number
---@return table?
getScriptTableFromEntityID = function(entity) end

---@param name string
---@param entity number
setEntityAlias = function(name, entity) end

---@param name string
---@return number?
getEntityByAlias = function(name) end

---@param entity number
enableShadowFor = function(entity) end

---@param entity number
disableShadowFor = function(entity) end

---@param entity number
---@param state string
add_state_tag = function(entity, state) end

---@param entity number
---@param state string
remove_state_tag = function(entity, state) end
