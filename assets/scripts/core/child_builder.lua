--[[
================================================================================
child_builder.lua - Fluent Child Entity Attachment API
================================================================================
Simplifies attaching child entities to parents with transform inheritance.
Wraps the existing transform.AssignRole() C++ binding.

UIBox Support:
    When attaching entities that have UIBoxComponent (DSL-spawned UI elements),
    ChildBuilder automatically syncs the uiRoot transform and calls RenewAlignment.
    This ensures that children inside a UI container move correctly with the parent.

Usage:
    local ChildBuilder = require("core.child_builder")

    -- Attach weapon to player
    ChildBuilder.for_entity(weapon)
        :attachTo(player)
        :offset(20, 0)
        :rotateWith()
        :apply()

    -- Attach UI tab container to panel (auto-syncs UIBox children)
    ChildBuilder.for_entity(tabContainer)
        :attachTo(panel)
        :offset(-100, 50)
        :apply()

    -- Animate child offset (weapon swing)
    ChildBuilder.animateOffset(weapon, {
        to = { x = -20, y = 30 },
        duration = 0.2,
        ease = "outQuad"
    })

    -- Orbit animation (circular swing)
    ChildBuilder.orbit(weapon, {
        radius = 30,
        startAngle = 0,
        endAngle = math.pi/2,
        duration = 0.2
    })

Dependencies:
    - transform.AssignRole (C++ binding)
    - InheritedPropertiesType, InheritedPropertiesSync (enums)
    - core.tween (for animations)
    - core.component_cache
    - UIBoxComponent, ui.box.RenewAlignment (for UI elements)

See also:
    - docs/project-management/design/anchor-pattern-adoption.md
    - docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md
]]

if _G.__CHILD_BUILDER__ then return _G.__CHILD_BUILDER__ end

local ChildBuilder = {}
ChildBuilder.__index = ChildBuilder

local component_cache = require("core.component_cache")

-- Lazy-load tween to avoid circular dependencies
local _tween = nil
local function get_tween()
    if not _tween then
        _tween = require("core.tween")
    end
    return _tween
end

--------------------------------------------------------------------------------
-- UIBox Synchronization Helper
--------------------------------------------------------------------------------

--- Sync UIBoxComponent.uiRoot transform and trigger layout recalculation.
--- Called automatically by apply() and setOffset() when entity has UIBoxComponent.
--- @param entity number The entity to sync
local function syncUIBoxLayout(entity)
    if not registry or not registry.valid then return end
    if not registry:valid(entity) then return end

    local boxComp = component_cache.get(entity, UIBoxComponent)
    if not boxComp or not boxComp.uiRoot then return end
    if not registry:valid(boxComp.uiRoot) then return end

    -- Get the computed world position from the main entity
    local t = component_cache.get(entity, Transform)
    if not t then return end

    -- Sync uiRoot Transform to match entity Transform
    local rt = component_cache.get(boxComp.uiRoot, Transform)
    if rt then
        rt.actualX = t.actualX
        rt.actualY = t.actualY
    end

    -- Sync uiRoot InheritedProperties offset
    local rootIP = component_cache.get(boxComp.uiRoot, InheritedProperties)
    if rootIP and rootIP.offset then
        rootIP.offset.x = t.actualX
        rootIP.offset.y = t.actualY
    end

    -- Force layout recalculation so children reposition
    if ui and ui.box and ui.box.RenewAlignment then
        ui.box.RenewAlignment(registry, entity)
    end
end

--------------------------------------------------------------------------------
-- Builder Instance
--------------------------------------------------------------------------------

--- Create a new ChildBuilder for the given entity.
--- @param entity number The child entity to configure
--- @return table ChildBuilder instance
function ChildBuilder.for_entity(entity)
    return setmetatable({
        _entity = entity,
        _parent = nil,
        _offset = { x = 0, y = 0 },
        _locationBond = nil,
        _sizeBond = nil,
        _rotationBond = nil,
        _scaleBond = nil,
        _roleType = InheritedPropertiesType.RoleInheritor,
        _name = nil,
    }, ChildBuilder)
end

--- Set the parent entity to attach to.
--- @param parent number The parent entity
--- @return self
function ChildBuilder:attachTo(parent)
    self._parent = parent
    return self
end

--- Set the offset from parent center.
--- @param x number X offset in pixels
--- @param y number|nil Y offset in pixels (default: 0)
--- @return self
function ChildBuilder:offset(x, y)
    self._offset = { x = x, y = y or 0 }
    return self
end

--- Enable rotation inheritance (child rotates with parent).
--- @param enabled boolean|nil Enable rotation sync (default: true)
--- @return self
function ChildBuilder:rotateWith(enabled)
    if enabled == false then
        self._rotationBond = nil
    else
        self._rotationBond = InheritedPropertiesSync.Strong
    end
    return self
end

--- Enable scale inheritance (child scales with parent).
--- @param enabled boolean|nil Enable scale sync (default: true)
--- @return self
function ChildBuilder:scaleWith(enabled)
    if enabled == false then
        self._scaleBond = nil
    else
        self._scaleBond = InheritedPropertiesSync.Strong
    end
    return self
end

--- Use eased (smooth) position following instead of instant snap.
--- @return self
function ChildBuilder:eased()
    self._locationBond = InheritedPropertiesSync.Weak
    return self
end

--- Use instant position snap (default).
--- @return self
function ChildBuilder:instant()
    self._locationBond = InheritedPropertiesSync.Strong
    return self
end

--- Set a name for this child (for lookup via parent).
--- @param name string The child name
--- @return self
function ChildBuilder:named(name)
    self._name = name
    return self
end

--- Set role type to PermanentAttachment (persists after parent death).
--- @return self
function ChildBuilder:permanent()
    self._roleType = InheritedPropertiesType.PermanentAttachment
    return self
end

--- Set role type to CarbonCopy (exact position copy, no offset).
--- @return self
function ChildBuilder:carbonCopy()
    self._roleType = InheritedPropertiesType.RoleCarbonCopy
    return self
end

--- Apply the configuration and attach child to parent.
--- @return number The child entity
function ChildBuilder:apply()
    if not self._parent then
        error("ChildBuilder: must call :attachTo(parent) before :apply()")
    end
    
    if not registry:valid(self._parent) then
        error("ChildBuilder: parent entity is not valid")
    end
    
    if not registry:valid(self._entity) then
        error("ChildBuilder: child entity is not valid")
    end
    
    local existingParent = ChildBuilder.getParent(self._entity)
    if existingParent and existingParent ~= self._parent and registry:valid(existingParent) then
        ChildBuilder.detach(self._entity)
    end
    
    transform.AssignRole(
        registry,
        self._entity,
        self._roleType,
        self._parent,
        self._locationBond or InheritedPropertiesSync.Strong,
        self._sizeBond,
        self._rotationBond,
        self._scaleBond,
        Vector2 { x = self._offset.x, y = self._offset.y }
    )
    
    local ip = component_cache.get(self._entity, InheritedProperties)
    if ip then
        ip.offset = Vector2 { x = self._offset.x, y = self._offset.y }
        if self._rotationBond == nil then
            ip.rotation_bond = nil
        end
        if self._scaleBond == nil then
            ip.scale_bond = nil
        end
    end
    
    local parentGO = component_cache.get(self._parent, GameObject)
    if parentGO then
        local childKey = self._name or tostring(self._entity)
        parentGO.children[childKey] = self._entity

        local found = false
        for _, child in ipairs(parentGO.orderedChildren) do
            if child == self._entity then
                found = true
                break
            end
        end
        if not found then
            -- LuaJIT compatibility: Sol2 vectors are userdata, not tables
            -- Use index assignment instead of table.insert
            parentGO.orderedChildren[#parentGO.orderedChildren + 1] = self._entity
        end
    end

    -- Auto-sync UIBox layout if entity has UIBoxComponent
    syncUIBoxLayout(self._entity)

    return self._entity
end

--------------------------------------------------------------------------------
-- UIBox Synchronization Helper
--------------------------------------------------------------------------------

--- Sync UIBoxComponent.uiRoot transform and trigger layout recalculation.
--- Called automatically by apply() and setOffset() when entity has UIBoxComponent.
--- @param entity number The entity to sync
local function syncUIBoxLayout(entity)
    if not registry or not registry.valid then return end
    if not registry:valid(entity) then return end

    local boxComp = component_cache.get(entity, UIBoxComponent)
    if not boxComp or not boxComp.uiRoot then return end
    if not registry:valid(boxComp.uiRoot) then return end

    -- Get the computed world position from the main entity
    local t = component_cache.get(entity, Transform)
    if not t then return end

    -- Sync uiRoot Transform to match entity Transform
    local rt = component_cache.get(boxComp.uiRoot, Transform)
    if rt then
        rt.actualX = t.actualX
        rt.actualY = t.actualY
    end

    -- Sync uiRoot InheritedProperties offset
    local rootIP = component_cache.get(boxComp.uiRoot, InheritedProperties)
    if rootIP and rootIP.offset then
        rootIP.offset.x = t.actualX
        rootIP.offset.y = t.actualY
    end

    -- Force layout recalculation so children reposition
    if ui and ui.box and ui.box.RenewAlignment then
        ui.box.RenewAlignment(registry, entity)
    end
end

--------------------------------------------------------------------------------
-- Static Animation Helpers
--------------------------------------------------------------------------------

--- Animate a child entity's offset.
--- @param entity number The child entity
--- @param opts table Options: { from, to, duration, ease, onComplete }
--- @return number The entity
function ChildBuilder.animateOffset(entity, opts)
    local ip = component_cache.get(entity, InheritedProperties)
    if not ip then
        print("[ChildBuilder] Warning: entity has no InheritedProperties")
        return entity
    end
    
    if not ip.offset then
        ip.offset = Vector2 { x = 0, y = 0 }
    end
    
    local from = opts.from or { x = ip.offset.x, y = ip.offset.y }
    local to = opts.to or { x = 0, y = 0 }
    local duration = opts.duration or 0.2
    local ease = opts.ease or "linear"
    local onComplete = opts.onComplete
    
    local Tween = get_tween()
    
    Tween.value(0, 1, duration, function(t)
        if not registry:valid(entity) then return end
        local currentIP = component_cache.get(entity, InheritedProperties)
        if currentIP and currentIP.offset then
            currentIP.offset.x = from.x + (to.x - from.x) * t
            currentIP.offset.y = from.y + (to.y - from.y) * t
        end
        -- Keep UIBox children in sync during animation
        syncUIBoxLayout(entity)
    end)
        :ease(ease)
        :onComplete(function()
            if onComplete then onComplete() end
        end)
    
    return entity
end

--- Animate a child entity in an orbital/arc path.
--- @param entity number The child entity
--- @param opts table Options: { radius, startAngle, endAngle, duration, ease, baseOffset, onComplete }
--- @return number The entity
function ChildBuilder.orbit(entity, opts)
    local ip = component_cache.get(entity, InheritedProperties)
    if not ip then
        print("[ChildBuilder] Warning: entity has no InheritedProperties")
        return entity
    end
    
    if not ip.offset then
        ip.offset = Vector2 { x = 0, y = 0 }
    end
    
    local radius = opts.radius or 30
    local startAngle = opts.startAngle or 0
    local endAngle = opts.endAngle or math.pi * 2
    local duration = opts.duration or 0.5
    local ease = opts.ease or "linear"
    local baseOffset = opts.baseOffset or { x = 0, y = 0 }
    local onComplete = opts.onComplete
    
    local Tween = get_tween()
    
    Tween.value(startAngle, endAngle, duration, function(angle)
        if not registry:valid(entity) then return end
        local currentIP = component_cache.get(entity, InheritedProperties)
        if currentIP and currentIP.offset then
            currentIP.offset.x = baseOffset.x + math.cos(angle) * radius
            currentIP.offset.y = baseOffset.y + math.sin(angle) * radius
        end
        -- Keep UIBox children in sync during animation
        syncUIBoxLayout(entity)
    end)
        :ease(ease)
        :onComplete(function()
            if onComplete then onComplete() end
        end)
    
    return entity
end

--- Set a child entity's offset immediately (no animation).
--- Automatically syncs UIBoxComponent.uiRoot and calls RenewAlignment if applicable.
--- @param entity number The child entity
--- @param x number X offset
--- @param y number Y offset
--- @return number The entity
function ChildBuilder.setOffset(entity, x, y)
    local ip = component_cache.get(entity, InheritedProperties)
    if not ip then
        print("[ChildBuilder] Warning: entity has no InheritedProperties")
        return entity
    end

    if not ip.offset then
        ip.offset = Vector2 { x = 0, y = 0 }
    end

    ip.offset.x = x
    ip.offset.y = y

    -- Auto-sync UIBox layout if entity has UIBoxComponent
    syncUIBoxLayout(entity)

    return entity
end

--- Get a child entity's current offset.
--- @param entity number The child entity
--- @return table|nil { x, y } or nil if no InheritedProperties
function ChildBuilder.getOffset(entity)
    local ip = component_cache.get(entity, InheritedProperties)
    if not ip or not ip.offset then
        return nil
    end
    return { x = ip.offset.x, y = ip.offset.y }
end

--- Get a child entity's parent (master) entity.
--- @param entity number The child entity
--- @return number|nil Parent entity or nil
function ChildBuilder.getParent(entity)
    local ip = component_cache.get(entity, InheritedProperties)
    if not ip then
        return nil
    end
    return ip.master
end

--- Detach a child from its parent.
--- @param entity number The child entity
--- @return number The entity
function ChildBuilder.detach(entity)
    local ip = component_cache.get(entity, InheritedProperties)
    if not ip then
        return entity
    end
    
    local parent = ip.master
    if parent and parent ~= entt_null and registry:valid(parent) then
        local parentGO = component_cache.get(parent, GameObject)
        if parentGO then
            for name, child in pairs(parentGO.children) do
                if child == entity then
                    parentGO.children[name] = nil
                    break
                end
            end
            for i, child in ipairs(parentGO.orderedChildren) do
                if child == entity then
                    table.remove(parentGO.orderedChildren, i)
                    break
                end
            end
        end
    end
    
    transform.AssignRole(
        registry,
        entity,
        InheritedPropertiesType.RoleRoot,
        entt_null,
        nil,
        nil,
        nil,
        nil,
        nil
    )
    
    return entity
end

--------------------------------------------------------------------------------
-- Module Export
--------------------------------------------------------------------------------

_G.__CHILD_BUILDER__ = ChildBuilder
return ChildBuilder
