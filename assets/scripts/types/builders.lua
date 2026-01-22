---@meta
--[[
================================================================================
BUILDER APIs - Fluent interfaces for entity/physics/shader setup
================================================================================
Builder patterns provide chainable APIs for complex configuration.
Each builder follows the pattern: Builder.for_X(target):option1():option2():apply()

Update this file when builder APIs change.
]]

---------------------------------------------------------------------------
-- EntityBuilder (core/entity_builder.lua)
---------------------------------------------------------------------------

---@class EntityBuilderOptions
---@field sprite? string Sprite name
---@field position? {x: number, y: number}|number[] Initial position {x, y} or [x, y]
---@field size? number[] Width and height {w, h}
---@field shadow? boolean Add shadow component
---@field data? table Custom script data
---@field interactive? EntityBuilderInteractiveOpts Interactive options
---@field state? any Initial state tag
---@field shaders? string[] Shader names to apply

---@class EntityBuilderInteractiveOpts
---@field hover? fun(entity: number) Hover callback
---@field unhover? fun(entity: number) Unhover callback
---@field click? fun(entity: number) Click callback
---@field drag? fun(entity: number, dx: number, dy: number) Drag callback
---@field collision? boolean Enable collision detection

---@class EntityBuilderFluent
---@field at fun(self: EntityBuilderFluent, x: number, y: number): EntityBuilderFluent Set position
---@field size fun(self: EntityBuilderFluent, w: number, h: number): EntityBuilderFluent Set size
---@field withData fun(self: EntityBuilderFluent, data: table): EntityBuilderFluent Set script data
---@field withState fun(self: EntityBuilderFluent, state: any): EntityBuilderFluent Set initial state
---@field withShadow fun(self: EntityBuilderFluent): EntityBuilderFluent Add shadow
---@field withShaders fun(self: EntityBuilderFluent, shaders: string[]): EntityBuilderFluent Add shaders
---@field interactive fun(self: EntityBuilderFluent, opts: EntityBuilderInteractiveOpts): EntityBuilderFluent Make interactive
---@field onClick fun(self: EntityBuilderFluent, fn: fun(entity: number)): EntityBuilderFluent Add click handler
---@field onHover fun(self: EntityBuilderFluent, fn: fun(entity: number)): EntityBuilderFluent Add hover handler
---@field getEntity fun(self: EntityBuilderFluent): number Get entity before build (escape hatch)
---@field getTransform fun(self: EntityBuilderFluent): Transform? Get transform (escape hatch)
---@field getGameObject fun(self: EntityBuilderFluent): GameObject? Get GameObject (escape hatch)
---@field getScript fun(self: EntityBuilderFluent): table? Get script table (escape hatch)
---@field build fun(self: EntityBuilderFluent): number, table? Build and return entity + script

---@class EntityBuilder
---@field create fun(opts: EntityBuilderOptions): number, table? Create entity with options
---@field simple fun(sprite: string, x: number, y: number, w: number, h: number): number Create simple entity
---@field interactive fun(opts: EntityBuilderOptions): number, table? Create interactive entity
---@field validated fun(ScriptType: table, entity: number, data?: table): table Create validated script
---@field new fun(sprite: string): EntityBuilderFluent Start fluent builder
EntityBuilder = {}

---------------------------------------------------------------------------
-- PhysicsBuilder (core/physics_builder.lua)
---------------------------------------------------------------------------

---@class PhysicsBuilderConfig
---@field shape? "circle"|"rectangle"|"polygon" Physics shape type
---@field tag? string Collision tag
---@field bullet? boolean Enable continuous collision detection
---@field sensor? boolean Make sensor (no physical response)
---@field friction? number Friction coefficient (0-1)
---@field restitution? number Bounciness (0-1)
---@field density? number Mass density
---@field fixed_rotation? boolean Prevent rotation
---@field collide_with? string[] Tags this body collides with
---@field sync_mode? "physics"|"transform" Which controls position

---@class PhysicsBuilderFluent
---@field circle fun(self: PhysicsBuilderFluent): PhysicsBuilderFluent Set shape to circle
---@field rectangle fun(self: PhysicsBuilderFluent): PhysicsBuilderFluent Set shape to rectangle
---@field box fun(self: PhysicsBuilderFluent): PhysicsBuilderFluent Alias for rectangle
---@field polygon fun(self: PhysicsBuilderFluent, vertices: number[][]): PhysicsBuilderFluent Set shape to polygon
---@field tag fun(self: PhysicsBuilderFluent, tag: string): PhysicsBuilderFluent Set collision tag
---@field bullet fun(self: PhysicsBuilderFluent): PhysicsBuilderFluent Enable CCD (fast-moving objects)
---@field sensor fun(self: PhysicsBuilderFluent): PhysicsBuilderFluent Make sensor (triggers but no physics)
---@field friction fun(self: PhysicsBuilderFluent, f: number): PhysicsBuilderFluent Set friction
---@field restitution fun(self: PhysicsBuilderFluent, r: number): PhysicsBuilderFluent Set bounciness
---@field density fun(self: PhysicsBuilderFluent, d: number): PhysicsBuilderFluent Set density
---@field fixedRotation fun(self: PhysicsBuilderFluent): PhysicsBuilderFluent Prevent rotation
---@field collideWith fun(self: PhysicsBuilderFluent, tags: string[]): PhysicsBuilderFluent Set collision targets
---@field syncMode fun(self: PhysicsBuilderFluent, mode: "physics"|"transform"): PhysicsBuilderFluent Set sync mode
---@field getEntity fun(self: PhysicsBuilderFluent): number Get entity (escape hatch)
---@field getWorld fun(self: PhysicsBuilderFluent): any Get physics world (escape hatch)
---@field getConfig fun(self: PhysicsBuilderFluent): PhysicsBuilderConfig Get config (escape hatch)
---@field apply fun(self: PhysicsBuilderFluent): boolean Apply physics configuration

---@class PhysicsBuilder
---@field for_entity fun(entity: number, world_name?: string): PhysicsBuilderFluent Start builder for entity
---@field quick fun(entity: number, config: PhysicsBuilderConfig): boolean Quick apply config
PhysicsBuilder = {}

---------------------------------------------------------------------------
-- ShaderBuilder (core/shader_builder.lua)
---------------------------------------------------------------------------

---@class ShaderParams
---@field [string] any Shader-specific parameters

---@class ShaderBuilderFluent
---@field add fun(self: ShaderBuilderFluent, shader_name: string, params?: ShaderParams): ShaderBuilderFluent Add shader
---@field remove fun(self: ShaderBuilderFluent, shader_name: string): ShaderBuilderFluent Remove shader
---@field holo fun(self: ShaderBuilderFluent, params?: ShaderParams): ShaderBuilderFluent Add holo shader
---@field prismatic fun(self: ShaderBuilderFluent, params?: ShaderParams): ShaderBuilderFluent Add prismatic shader
---@field polychrome fun(self: ShaderBuilderFluent, params?: ShaderParams): ShaderBuilderFluent Add polychrome shader
---@field foil fun(self: ShaderBuilderFluent, params?: ShaderParams): ShaderBuilderFluent Add foil shader
---@field dissolve fun(self: ShaderBuilderFluent, params?: ShaderParams): ShaderBuilderFluent Add dissolve shader
---@field flash fun(self: ShaderBuilderFluent, params?: ShaderParams): ShaderBuilderFluent Add flash shader
---@field outline fun(self: ShaderBuilderFluent, params?: ShaderParams): ShaderBuilderFluent Add outline shader
---@field getEntity fun(self: ShaderBuilderFluent): number Get entity (escape hatch)
---@field getShaders fun(self: ShaderBuilderFluent): string[] Get shader list (escape hatch)
---@field apply fun(self: ShaderBuilderFluent) Apply shader configuration

---@class ShaderBuilder
---@field for_entity fun(entity: number): ShaderBuilderFluent Start builder for entity
ShaderBuilder = {}

---------------------------------------------------------------------------
-- ChildBuilder (core/child_builder.lua)
---------------------------------------------------------------------------

---@class ChildBuilderOpts
---@field sprite? string Sprite name
---@field offset? {x: number, y: number} Offset from parent
---@field size? number[] Width and height
---@field inherit_rotation? boolean Inherit parent rotation
---@field inherit_scale? boolean Inherit parent scale

---@class ChildBuilderFluent
---@field sprite fun(self: ChildBuilderFluent, name: string): ChildBuilderFluent Set sprite
---@field offset fun(self: ChildBuilderFluent, x: number, y: number): ChildBuilderFluent Set offset from parent
---@field size fun(self: ChildBuilderFluent, w: number, h: number): ChildBuilderFluent Set size
---@field inheritRotation fun(self: ChildBuilderFluent): ChildBuilderFluent Inherit parent rotation
---@field inheritScale fun(self: ChildBuilderFluent): ChildBuilderFluent Inherit parent scale
---@field build fun(self: ChildBuilderFluent): number Create child entity

---@class ChildBuilder
---@field for_parent fun(parent: number): ChildBuilderFluent Start builder for parent
ChildBuilder = {}
